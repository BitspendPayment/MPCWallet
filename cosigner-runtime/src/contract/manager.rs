//! Contract creation (PEER model): a single key-preserving REFRESH of the wallet's key `V`
//! onto a `{receiver, cosigner}` pairing. NO reshare and NO new key — contracts reuse `V` and
//! are bound by the cosigner GATE at spend time. The single call registers the contract +
//! refreshes, then drops BOTH ECIES halves of the receiver's share into the receiver's pickup
//! inbox: the wallet's `a@receiver` (supplied encrypted in the request) and the cosigner's
//! `b@receiver` (the refresh `receiver_half`, encrypted here to the receiver's verifying key).
//! No external service, no URL.
//!
//! Stateless — there are no multi-round sessions to track or evict anymore.

use std::sync::Arc;

use rand::rngs::OsRng;
use tonic::Status;

use crate::cosigner::command::CosignerCommand;
use crate::cosigner::handlers::contract::{write_pending_share, PendingShareRecord};
use crate::cosigner::registry::CosignerRegistry;
use crate::shared::SharedServices;
use crate::wallet_proto::{ContractCreateRequest, ContractCreateResponse};

use super::handler;

pub struct ContractManager {
    shared: Arc<SharedServices>,
    registry: Arc<CosignerRegistry>,
}

impl ContractManager {
    pub fn new(shared: Arc<SharedServices>, registry: Arc<CosignerRegistry>) -> Arc<Self> {
        Arc::new(Self { shared, registry })
    }

    /// Shared services (persistence + contract host) — used by the directory browse/publish
    /// handlers, which need read/write access without going through an actor.
    pub fn shared(&self) -> &Arc<SharedServices> {
        &self.shared
    }

    /// Create a contract WITH a receiver: REFRESH `V` onto the `{receiver, cosigner}` pairing
    /// INSIDE the wallet's guest (the host never reads `V`), register the eVTXO under the gate,
    /// seed the cosigner counter-share into the pairing actor, then drop BOTH ECIES halves of the
    /// receiver's share into the receiver's inbox. The wallet supplied its refresh slices
    /// (`a@cosigner` + `a@receiver·G`) and the ECIES of its own half `a@receiver` in the request.
    pub async fn create_contract(
        self: &Arc<Self>,
        user_id: &str,
        req: ContractCreateRequest,
    ) -> Result<ContractCreateResponse, Status> {
        if req.receiver_vk.len() != 33 {
            return Err(Status::invalid_argument("receiver_vk must be 33 bytes"));
        }
        let receiver_vk_hex = hex::encode(&req.receiver_vk);
        let ecies_a_at_receiver_hex = hex::encode(&req.ecies_a_at_receiver);

        // Run the key-preserving refresh of V in the guest; the host gets only public material +
        // the receiver's half (b@receiver) + an opaque pairing key package.
        let receiver_id = threshold::identifier::Identifier::derive(&req.receiver_vk)
            .map_err(|e| Status::internal(format!("derive receiver id: {e:?}")))?;
        let receiver_id_hex = hex::encode(receiver_id.serialize());
        let refresh = self
            .registry
            .dispatch(user_id, |reply| CosignerCommand::ContractRefresh {
                receiver_id_hex: receiver_id_hex.clone(),
                receiver_partial_point: req.a_at_receiver_point.clone(),
                wallet_id_hex: hex::encode(&req.identifier),
                a_at_cosigner: req.a_at_cosigner.clone(),
                min_signers: 2,
                reply,
            })
            .await?;
        // Captured before `handler::contract_create` consumes `req` — the pairing actor seed +
        // the receiver's inbox record need these.
        let pairing_kp_json = refresh.my_key_package_json.clone();
        let pairing_pkp_json = refresh.pairing_public_key_package_json.clone();
        let receiver_half = refresh.receiver_half.clone(); // b@receiver scalar (32B)
        let to32 = |v: &[u8], what: &str| {
            <[u8; 32]>::try_from(v)
                .map_err(|_| Status::invalid_argument(format!("{what} must be 32 bytes")))
        };
        let server_pk = to32(&req.server_pk, "server_pk")?;
        let owner_pk = to32(&req.owner_pk, "owner_pk")?;
        let exit_delay = req.exit_delay;

        let resp = handler::contract_create(&self.shared, req)?;
        let spk_hex = hex::encode(&resp.contract_script_pubkey);
        // The BOUND contract id (the composed sha256 in template mode) — used for the gate policy,
        // the pairing conditioning, and the receiver's inbox record.
        let contract_id = to32(&resp.contract_id, "contract_id")?;

        // Plan A: add the gate's ContractPolicy to the WALLET actor's sealed state (no `policies`
        // tree). The receiver's vk goes on the authorized-signer allowlist so it can co-sign.
        let contract_policy = crate::cosigner::state::ContractPolicy {
            contract_id,
            wallet_vk: user_id.to_string(),
            exit_delay,
            owner_pk,
            authorized_service_vks: vec![receiver_vk_hex.clone()],
        };
        let contract_policy_json = serde_json::to_string(&contract_policy)
            .map_err(|e| Status::internal(format!("serialize contract policy: {e}")))?;
        self.registry
            .dispatch(user_id, |reply| CosignerCommand::AddContract {
                spk_hex: spk_hex.clone(),
                contract_policy_json,
                reply,
            })
            .await?;
        let pairing = crate::cosigner::state::ContractPairing {
            evtxo_spk_hex: spk_hex.clone(),
            contract_id,
            server_pk,
            owner_pk,
            exit_delay,
        };

        // Eager-seed the {receiver, cosigner} pairing actor (keyed by the eVTXO spk) into its OWN
        // guest + seal it, INCLUDING the conditioning params — so the guest is authoritative about
        // what it co-signs across cold spawns, with nothing about the pairing persisted host-side.
        self.registry
            .dispatch(&spk_hex, |reply| CosignerCommand::SeedPolicy {
                key_package_json: pairing_kp_json,
                public_key_package_json: pairing_pkp_json.clone(),
                user_signing_identifier_hex: Some(receiver_id_hex),
                server_dkg_secret_hex: None,
                contract_pairing: Some(pairing),
                reply,
            })
            .await?;

        // ECIES the cosigner's half b@receiver to the receiver; hold both halves (the wallet's
        // a@receiver from the request + the cosigner's b@receiver) in the receiver's pickup inbox.
        let mut recipient_pk = [0u8; 33];
        recipient_pk.copy_from_slice(&hex::decode(&receiver_vk_hex).unwrap_or_default());
        let half: [u8; 32] = receiver_half
            .as_slice()
            .try_into()
            .map_err(|_| Status::internal("receiver_half must be 32 bytes"))?;
        let ecies_cosigner = threshold::ecies::encrypt(&half, &recipient_pk, &mut OsRng)
            .map_err(|e| Status::internal(format!("ecies encrypt b@receiver: {e:?}")))?;

        let contract_id_hex = hex::encode(contract_id);
        write_pending_share(
            self.shared.persistence.as_ref(),
            &receiver_vk_hex,
            PendingShareRecord {
                spk_hex: spk_hex.clone(),
                contract_id_hex: contract_id_hex.clone(),
                ecies_author_hex: ecies_a_at_receiver_hex,
                ecies_cosigner_hex: hex::encode(ecies_cosigner),
                pkp_json: pairing_pkp_json,
                exit_delay,
                server_pk_xonly_hex: hex::encode(server_pk),
                owner_pk_xonly_hex: hex::encode(owner_pk),
            },
        )?;

        // Phase 3: notify the receiver that a contract share is waiting — one event, two channels:
        // (a) the live SSE stream (a BACKEND user holding /u/{vk}/events open), (b) an FCM push (a
        // mobile app). Both are best-effort nudges; the inbox is the durable record.
        self.shared.events.publish(
            &receiver_vk_hex,
            crate::events::CosignerEvent::ContractShare {
                spk_hex: spk_hex.clone(),
                contract_id_hex,
            },
        );
        if let Some(fcm) = self.shared.fcm.clone() {
            // Fire-and-forget: a notification must NEVER block (or fail) contract creation — the
            // share is already durably in the inbox. Mirrors the boarding push (background task).
            let persistence = self.shared.persistence.clone();
            let vk = receiver_vk_hex.clone();
            let spk = spk_hex.clone();
            tokio::spawn(async move {
                let tokens = crate::cosigner::handlers::helpers::load_user_device_tokens(
                    persistence.as_ref(),
                    &vk,
                );
                crate::cosigner::registry::push_contract_share(&fcm, &vk, &tokens, &spk).await;
            });
        }

        Ok(resp)
    }
}
