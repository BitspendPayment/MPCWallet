//! Request-to-pay: the contact allowlist gate and its sealed persistence.
//!
//! Scope is deliberately narrow — only what can be proven WITHOUT the Ark stack. Creating an
//! intent derives the payee address from the ASP, so those paths (creation, inbox, fulfilment)
//! are exercised by the regtest CLI against a live stack, not faked here.
//!
//! What this does prove is the security-critical half: `verify_auth` deliberately does not bind a
//! signer to the actor it addresses, so the payer's allowlist is the ONLY thing standing between a
//! stranger and their inbox — and it must survive a cold spawn.
//!
//! Drives the registry directly, so it covers AUTHORIZATION (in the actor), not AUTHENTICATION
//! (the Schnorr check at the REST boundary). Needs Redis.

mod common;

use cosigner_runtime::cosigner::command::CosignerCommand;
use cosigner_runtime::cosigner::registry::CosignerRegistry;
use cosigner_runtime::wallet_proto::{
    ContactAddRequest, ContactListRequest, ContactRemoveRequest, PaymentRequestCreateRequest,
};

fn create_req(receiver_vk: &[u8]) -> PaymentRequestCreateRequest {
    PaymentRequestCreateRequest {
        user_id: receiver_vk.to_vec(),
        amount_sats: 1_000,
        memo: "coffee".to_string(),
        expires_in_secs: 0,
        signature: vec![],
        timestamp_ms: 0,
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn allowlist_gates_requests_and_survives_cold_spawn() {
    let Some(shared) = common::try_shared().await else {
        return;
    };

    // The payer, and the party asking to be paid (who receives the money).
    let (payer_kps, payer_pkp) = common::dkg_2of2();
    let payer_group = hex::encode(payer_pkp.verifying_key.serialize());
    let (_receiver_kps, receiver_pkp) = common::dkg_2of2();
    let receiver_vk = receiver_pkp.verifying_key.serialize().to_vec();

    let registry = CosignerRegistry::new(shared.clone()).unwrap();
    common::seed_policy(
        &registry,
        &payer_group,
        &payer_kps[1],
        &payer_kps[0],
        &payer_pkp,
        Some(hex::encode([7u8; 32])),
    )
    .await;

    // A stranger is refused — and refused BEFORE any state is touched or the ASP is consulted,
    // which is why this assertion is meaningful with or without a live stack.
    let err = registry
        .dispatch(&payer_group, |reply| {
            CosignerCommand::PaymentRequestCreate {
                req: create_req(&receiver_vk),
                reply,
            }
        })
        .await
        .expect_err("a non-contact must not be able to create a request");
    assert_eq!(
        err.code(),
        tonic::Code::PermissionDenied,
        "expected PermissionDenied, got: {err:?}"
    );

    // Authorize them.
    registry
        .dispatch(&payer_group, |reply| CosignerCommand::ContactAdd {
            req: ContactAddRequest {
                user_id: vec![],
                contact_verifying_key: receiver_vk.clone(),
                label: "Bob".to_string(),
                signature: vec![],
                timestamp_ms: 0,
            },
            reply,
        })
        .await
        .expect("add contact");

    // The allowlist is sealed: drop the registry so no live actor survives, then read it back from
    // a cold spawn (restored from the snapshot, not from memory).
    drop(registry);
    let registry = CosignerRegistry::new(shared.clone()).unwrap();
    let list = registry
        .dispatch(&payer_group, |reply| CosignerCommand::ContactList {
            req: ContactListRequest {
                user_id: vec![],
                signature: vec![],
                timestamp_ms: 0,
            },
            reply,
        })
        .await
        .expect("list contacts");
    assert_eq!(list.contacts.len(), 1, "contact must survive a cold spawn");
    assert_eq!(list.contacts[0].verifying_key, receiver_vk);
    assert_eq!(list.contacts[0].label, "Bob");

    // Revoking re-closes the gate.
    registry
        .dispatch(&payer_group, |reply| CosignerCommand::ContactRemove {
            req: ContactRemoveRequest {
                user_id: vec![],
                contact_verifying_key: receiver_vk.clone(),
                signature: vec![],
                timestamp_ms: 0,
            },
            reply,
        })
        .await
        .expect("remove contact");

    let err = registry
        .dispatch(&payer_group, |reply| {
            CosignerCommand::PaymentRequestCreate {
                req: create_req(&receiver_vk),
                reply,
            }
        })
        .await
        .expect_err("a revoked contact must not be able to create a request");
    assert_eq!(err.code(), tonic::Code::PermissionDenied);

    let _ = shared.persistence.delete("sealed_state", &payer_group);
}
