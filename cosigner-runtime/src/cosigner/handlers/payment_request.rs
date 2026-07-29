//! Request-to-pay: the contact allowlist + the payer's payment-request inbox.
//!
//! A wallet allowlists a contact (one-way); that contact may then bill it. The payer's cosigner
//! checks the allowlist, DERIVES the requester's Ark address from the allowlisted key, and records
//! the intent. The payer then signs the payment or declines.
//!
//! Not a pre-signed transaction: FROST is 2-round interactive and Ark checkpoints need an ASP
//! counter-signature, so nothing can be signed ahead of approval.
//!
//! Read paths live here; mutating paths are `route_*` fns in [`crate::cosigner::registry`], since
//! every change re-seals the snapshot.

use tonic::Status;

use crate::cosigner::actor::CosignerActor;
use crate::cosigner::handlers::helpers::now_secs;
use crate::cosigner::types::{Contact, IntentStatus, PaymentIntent};
use crate::wallet_proto::{
    ContactListRequest, ContactListResponse, PaymentRequestListRequest, PaymentRequestListResponse,
};

/// Domain → wire.
pub fn contact_to_proto(c: &Contact) -> crate::wallet_proto::Contact {
    crate::wallet_proto::Contact {
        verifying_key: hex::decode(&c.vk_hex).unwrap_or_default(),
        label: c.label.clone(),
        added_at: c.added_at,
    }
}

/// Domain → wire. `now` lets a still-`Pending` but elapsed intent report as `expired` without
/// mutating (and therefore re-sealing) state on a read.
pub fn intent_to_proto(i: &PaymentIntent, now: i64) -> crate::wallet_proto::PaymentIntent {
    let status = if i.status == IntentStatus::Pending && now >= i.expires_at {
        IntentStatus::Expired
    } else {
        i.status
    };
    crate::wallet_proto::PaymentIntent {
        id: i.id.clone(),
        from_verifying_key: hex::decode(&i.from_vk_hex).unwrap_or_default(),
        to_ark_address: i.to_ark_address.clone(),
        amount_sats: i.amount_sats,
        memo: i.memo.clone(),
        created_at: i.created_at,
        expires_at: i.expires_at,
        status: status.as_str().to_string(),
        ark_txid: i.ark_txid.clone(),
    }
}

impl CosignerActor {
    /// The parties this wallet has authorized to bill it.
    /// Auth (`OP_CONTACT_LIST`) ran at the REST boundary.
    pub async fn contact_list(
        &mut self,
        _req: ContactListRequest,
    ) -> Result<ContactListResponse, Status> {
        Ok(ContactListResponse {
            contacts: self.contacts().iter().map(contact_to_proto).collect(),
        })
    }

    /// The payer's request inbox, newest first.
    /// Auth (`OP_PAYREQ_LIST`) ran at the REST boundary.
    pub async fn payment_request_list(
        &mut self,
        _req: PaymentRequestListRequest,
    ) -> Result<PaymentRequestListResponse, Status> {
        let now = now_secs();
        // Prune here too: otherwise it only runs when a NEW request arrives, so a payer who just
        // reads their inbox keeps seeing long-lapsed ones. Re-seal only if something changed.
        if self.prune_intents(now) {
            let group_key = self.state.lock().cosigner_id.clone();
            crate::cosigner::registry::persist_actor_snapshot_for(self, &group_key).await;
        }
        let mut intents: Vec<_> = self
            .payment_intents()
            .iter()
            .map(|i| intent_to_proto(i, now))
            .collect();
        intents.sort_by(|a, b| b.created_at.cmp(&a.created_at));
        Ok(PaymentRequestListResponse { intents })
    }
}
