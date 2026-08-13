//! Plan A foundation: `SeedPolicy` installs freshly-computed key material into the per-user
//! actor and seals it into the actor snapshot — with NO plaintext policy in persistence. Proves
//! the actor owns the keys via the seed path alone (a `sealed_state` blob appears; nothing is
//! written to a plaintext `policies` tree), which is what lets later cold spawns restore keys
//! without the host keeping a plaintext signing key.
//!
//! Integration test: persistence is in-process SQLite. The ASP channel is lazy and never used here.

mod common;

use cosigner_runtime::cosigner::command::CosignerCommand;
use cosigner_runtime::cosigner::registry::CosignerRegistry;

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn seed_policy_installs_and_seals_without_plaintext() {
    let Some(shared) = common::try_shared().await else {
        return;
    };

    let (kps, pkp) = common::dkg_2of2();
    let kp_user = &kps[0];
    let kp_cosigner = &kps[1];
    let group_key = hex::encode(pkp.verifying_key.serialize());

    let registry = CosignerRegistry::new(shared.clone()).unwrap();

    // Seed via the actor command — note we never write the `policies` tree.
    let res: Result<(), _> = registry
        .dispatch(&group_key, |reply| CosignerCommand::SeedPolicy {
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(hex::encode(kp_user.identifier.serialize())),
            server_dkg_secret_hex: None,
            contract_pairing: None,
            reply,
        })
        .await;
    assert!(res.is_ok(), "SeedPolicy failed: {res:?}");

    // The actor sealed its state ⇒ a sealed_state blob exists for the group key.
    let blob = shared.persistence.get("sealed_state", &group_key).unwrap();
    assert!(blob.is_some(), "expected a sealed_state blob after SeedPolicy");

    // …and no plaintext policy was written/needed — the actor owns the keys.
    let plaintext = shared.persistence.get("policies", &group_key).unwrap();
    assert!(
        plaintext.is_none(),
        "SeedPolicy must not require a plaintext policy in the `policies` tree"
    );

    // Drop the key this test wrote (the in-memory store dies with the test anyway).
    let _ = shared.persistence.delete("sealed_state", &group_key);
}
