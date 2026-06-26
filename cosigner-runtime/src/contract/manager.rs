//! Contract creation: a single key-preserving REFRESH of the wallet's key `V` onto the
//! always-online `{service, cosigner}` pairing. NO reshare and NO new key — contracts reuse
//! `V` and are bound by the cosigner GATE at spend time. The single call registers the
//! contract + refreshes, then delivers the cosigner's half `b@service` to the service over
//! HTTP. The wallet sends its own `a@service` scalar directly to the service (only the point
//! `a@service·G` reaches the cosigner).
//!
//! Stateless — there are no multi-round sessions to track or evict anymore.

use std::sync::Arc;

use tonic::Status;

use crate::cosigner::command::CosignerCommand;
use crate::cosigner::registry::CosignerRegistry;
use crate::shared::SharedServices;
use crate::wallet_proto::{ContractContext, ContractCreateRequest, ContractCreateResponse};

use super::handler;

pub struct ContractManager {
    shared: Arc<SharedServices>,
    registry: Arc<CosignerRegistry>,
}

impl ContractManager {
    pub fn new(shared: Arc<SharedServices>, registry: Arc<CosignerRegistry>) -> Arc<Self> {
        Arc::new(Self { shared, registry })
    }

    /// Create a contract: REFRESH `V` onto the `{service, cosigner}` pairing INSIDE the wallet's
    /// guest (the host never reads `V`), register the eVTXO under the gate, then deliver the
    /// cosigner's `b@service` half + context to the always-online service. The wallet supplied its
    /// refresh slices (`a@cosigner` + `a@service·G`) in the request.
    pub async fn create_contract(
        self: &Arc<Self>,
        user_id: &str,
        req: ContractCreateRequest,
    ) -> Result<ContractCreateResponse, Status> {
        // Run the key-preserving refresh of V in the guest; the host gets only public material +
        // the receiver's half + an opaque pairing key package.
        let service_id = threshold::identifier::Identifier::derive(&req.service_vk)
            .map_err(|e| Status::internal(format!("derive service id: {e:?}")))?;
        let service_id_hex = hex::encode(service_id.serialize());
        let refresh = self
            .registry
            .dispatch(user_id, |reply| CosignerCommand::ContractRefresh {
                receiver_id_hex: service_id_hex.clone(),
                receiver_partial_point: req.a_at_service_point.clone(),
                wallet_id_hex: hex::encode(&req.identifier),
                a_at_cosigner: req.a_at_cosigner.clone(),
                min_signers: 2,
                reply,
            })
            .await?;
        // Captured before `handler::contract_create` consumes `refresh` — used to EAGER-seed the
        // pairing actor into its own guest below (so its key lives only in the sealed snapshot, no
        // plaintext-install fallback).
        let pairing_kp_json = refresh.my_key_package_json.clone();
        let pairing_pkp_json = refresh.pairing_public_key_package_json.clone();
        // Conditioning params captured from the request (Plan A 1C: seeded INTO the guest so the
        // guest rebuilds + binds the cooperative-leaf sighash itself; the host stores nothing).
        let to32 = |v: &[u8], what: &str| {
            <[u8; 32]>::try_from(v).map_err(|_| Status::invalid_argument(format!("{what} must be 32 bytes")))
        };
        let contract_id = to32(&req.contract_id, "contract_id")?;
        let server_pk = to32(&req.server_pk, "server_pk")?;
        let owner_pk = to32(&req.owner_pk, "owner_pk")?;
        let exit_delay = req.exit_delay;

        let resp = handler::contract_create(&self.shared, req, refresh)?;
        let spk_hex = hex::encode(&resp.contract_script_pubkey);
        let pairing = crate::policy::ContractPairing {
            evtxo_spk_hex: spk_hex.clone(),
            contract_id,
            server_pk,
            owner_pk,
            exit_delay,
        };

        // Eager-seed the {service, cosigner} pairing actor (keyed by the eVTXO spk) into its OWN
        // guest + seal it, INCLUDING the conditioning params — so the guest is authoritative about
        // what it co-signs across cold spawns, with nothing about the pairing persisted host-side.
        self.registry
            .dispatch(&spk_hex, |reply| CosignerCommand::SeedPolicy {
                key_package_json: pairing_kp_json,
                public_key_package_json: pairing_pkp_json,
                user_signing_identifier_hex: Some(service_id_hex),
                server_dkg_secret_hex: None,
                contract_pairing: Some(pairing),
                reply,
            })
            .await?;

        if let Some(context) = resp.context.clone() {
            // Correlation key for the service = the registered scriptPubKey (both the wallet
            // and the cosigner know it once ContractCreate returns).
            let corr_hex = hex::encode(&resp.contract_script_pubkey);
            self.deliver_to_service(&corr_hex, &resp.b_at_service, context)
                .await?;
        }
        Ok(resp)
    }

    /// POST the cosigner's `b@service` half + context to the always-online service.
    async fn deliver_to_service(
        &self,
        group_id_hex: &str,
        b_at_service: &[u8],
        context: ContractContext,
    ) -> Result<(), Status> {
        let base = self
            .shared
            .service_url
            .as_ref()
            .ok_or_else(|| Status::unavailable("contract-signer service not configured"))?;
        let url = format!("{}/assemble-contract-share", base.trim_end_matches('/'));
        // Hex JSON (shared schema with the wallet's delivery + the contract service);
        // prost's Vec<u8>-as-int-arrays default is avoided so the wire form is greppable.
        let body = serde_json::json!({
            "contract_group_id": group_id_hex,
            "half_scalar": hex::encode(b_at_service),
            "role": "cosigner",
            "context": {
                "contract_script_pubkey": hex::encode(&context.contract_script_pubkey),
                "contract_id": hex::encode(&context.contract_id),
                "exit_delay": context.exit_delay,
                "owner_pk": hex::encode(&context.owner_pk),
                "server_pk": hex::encode(&context.server_pk),
                "public_key_package_json": context.public_key_package_json,
                "service_vk": hex::encode(&context.service_vk),
                "cosigner_group_key": hex::encode(&context.cosigner_group_key),
            },
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .json(&body)
            .send()
            .await
            .map_err(|e| Status::unavailable(format!("service call failed: {e}")))?;
        if !resp.status().is_success() {
            return Err(Status::internal(format!(
                "service rejected share: HTTP {}",
                resp.status()
            )));
        }
        Ok(())
    }
}
