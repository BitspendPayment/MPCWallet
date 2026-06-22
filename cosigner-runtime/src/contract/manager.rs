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

use crate::shared::SharedServices;
use crate::wallet_proto::{
    AssembleContractShareRequest, ContractContext, ContractCreateRequest, ContractCreateResponse,
};

use super::handler;

pub struct ContractManager {
    shared: Arc<SharedServices>,
}

impl ContractManager {
    pub fn new(shared: Arc<SharedServices>) -> Arc<Self> {
        Arc::new(Self { shared })
    }

    /// Create a contract in a single round: register it under the gate + REFRESH `V` onto the
    /// `{service, cosigner}` pairing, then deliver the cosigner's `b@service` half + context to
    /// the always-online service. Stateless — the wallet has already computed its refresh
    /// slices locally and supplied `a@cosigner` + `a@service·G` in the request.
    pub async fn create_contract(
        self: &Arc<Self>,
        _user_id: &str,
        req: ContractCreateRequest,
    ) -> Result<ContractCreateResponse, Status> {
        let resp = handler::contract_create(&self.shared, req)?;
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
        let body = AssembleContractShareRequest {
            contract_group_id: hex::decode(group_id_hex).unwrap_or_default(),
            half_scalar: b_at_service.to_vec(),
            role: "cosigner".to_string(),
            context: Some(context),
        };
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
