//! Phase 3c: delegate-settle SETUP chain in the guest — InstallPolicy (with the Ark cosigner
//! secret) → GenerateDelegate (gRPC GetInfo + `generate_delegate` → sighashes) → ApplyDelegateSigs
//! (`sign_with_frost` → ReadyToSettle). This runtime-verifies the setup half of delegate-settle
//! (the drive half needs a MuSig2 batch-coordinator mock and is tested separately). The Ark
//! cosigner secret + the delegate session live entirely in the guest.

use std::collections::BTreeMap;
use std::convert::Infallible;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use bitcoin::secp256k1::{Keypair, Secp256k1, SecretKey};
use http_body_util::{combinators::UnsyncBoxBody, BodyExt, Full, StreamBody};
use hyper::body::{Bytes, Frame};
use hyper_util::rt::{TokioExecutor, TokioIo};
use prost::Message as ProstMessage;
use rand::rngs::OsRng;

use cosigner_proto::{
    ApplyDelegateSigsWire, ArkTxEntryWire, GenerateDelegateWire, GuestCommand, GuestResponse,
    VtxoInputWire,
};
use cosigner_runtime::auth::message::{build_auth_message, OP_SETTLE_DELEGATE};
use cosigner_runtime::cosigner::guest_instance::{self, GuestInstance};

use threshold::auth::AuthSigner;
use threshold::dkg::{self, Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::random;
use threshold::scalar::scalar_to_bytes;

fn guest_wasm_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("cosigner/target/wasm32-wasip2/release/cosigner.wasm")
}

fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64
}

fn xonly_hex(seed: u8) -> String {
    let secp = Secp256k1::new();
    let sk = SecretKey::from_slice(&[seed; 32]).unwrap();
    let (xonly, _) = Keypair::from_secret_key(&secp, &sk).x_only_public_key();
    hex::encode(xonly.serialize())
}

fn regtest_addr(seed: u8) -> String {
    let secp = Secp256k1::new();
    let sk = SecretKey::from_slice(&[seed; 32]).unwrap();
    let (xonly, _) = Keypair::from_secret_key(&secp, &sk).x_only_public_key();
    bitcoin::Address::p2tr(&secp, xonly, None, bitcoin::Network::Regtest).to_string()
}

fn dkg_2of2() -> (Vec<KeyPackage>, PublicKeyPackage) {
    let mut rng = OsRng;
    let (min, max) = (2usize, 2usize);
    let mut r1_secrets = Vec::new();
    let mut r1_packages: BTreeMap<Identifier, Round1Package> = BTreeMap::new();
    for _ in 0..max {
        let secret = random::mod_n_random(&mut rng);
        let coefficients: Vec<_> = (0..min - 1).map(|_| random::mod_n_random(&mut rng)).collect();
        let (secret_pkg, pub_pkg) =
            dkg::dkg_part1(max, min, &secret, &coefficients, &mut rng).expect("dkg_part1");
        r1_packages.insert(secret_pkg.identifier.clone(), pub_pkg);
        r1_secrets.push(secret_pkg);
    }
    let mut r2_secrets = Vec::new();
    let mut all_r2: Vec<BTreeMap<Identifier, Round2Package>> = Vec::new();
    for secret_pkg in &r1_secrets {
        let others: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != secret_pkg.identifier)
            .map(|(id, p)| (id.clone(), p.clone()))
            .collect();
        let (r2_secret, r2_out) = dkg::dkg_part2(secret_pkg, &others, &[]).expect("dkg_part2");
        r2_secrets.push(r2_secret);
        all_r2.push(r2_out);
    }
    let mut key_packages = Vec::new();
    let mut pkp_out: Option<PublicKeyPackage> = None;
    for (i, r2_secret) in r2_secrets.iter().enumerate() {
        let others_r1: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != r2_secret.identifier)
            .map(|(id, p)| (id.clone(), p.clone()))
            .collect();
        let mut our_r2: BTreeMap<Identifier, Round2Package> = BTreeMap::new();
        for (j, r2_pkgs) in all_r2.iter().enumerate() {
            if j == i {
                continue;
            }
            if let Some(pkg) = r2_pkgs.get(&r2_secret.identifier) {
                our_r2.insert(r1_secrets[j].identifier.clone(), pkg.clone());
            }
        }
        let (kp, pkp) =
            dkg::dkg_part3(&r1_secrets[i], r2_secret, &others_r1, &our_r2, &[]).expect("dkg_part3");
        key_packages.push(kp.into_even_y());
        pkp_out = Some(pkp.into_even_y());
    }
    (key_packages, pkp_out.unwrap())
}

fn grpc_frame<M: ProstMessage>(m: &M) -> Vec<u8> {
    let mut buf = Vec::new();
    m.encode(&mut buf).unwrap();
    let mut framed = vec![0u8];
    framed.extend_from_slice(&(buf.len() as u32).to_be_bytes());
    framed.extend_from_slice(&buf);
    framed
}

/// Mock arkd: answers only GetInfo (the setup chain needs no other ASP call).
async fn run_mock_arkd(listener: tokio::net::TcpListener) {
    loop {
        let Ok((tcp, _)) = listener.accept().await else { continue };
        tokio::spawn(async move {
            let svc = hyper::service::service_fn(handle);
            let _ = hyper::server::conn::http2::Builder::new(TokioExecutor::new())
                .serve_connection(TokioIo::new(tcp), svc)
                .await;
        });
    }
}

async fn handle(
    req: hyper::Request<hyper::body::Incoming>,
) -> Result<hyper::Response<Full<Bytes>>, Infallible> {
    use ark::client::proto::GetInfoResponse;
    let _ = req.into_body().collect().await;
    let resp = grpc_frame(&GetInfoResponse {
        signer_pubkey: xonly_hex(2),
        forfeit_pubkey: xonly_hex(4),
        forfeit_address: regtest_addr(4),
        network: "regtest".to_string(),
        unilateral_exit_delay: 144,
        boarding_exit_delay: 144,
        dust: 330,
        ..Default::default()
    });
    Ok(hyper::Response::builder()
        .status(200)
        .header("content-type", "application/grpc")
        .body(Full::new(Bytes::from(resp)))
        .unwrap())
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn guest_delegate_setup_chain() {
    let wasm = guest_wasm_path();
    if !wasm.exists() {
        eprintln!("cosigner-guest not built at {wasm:?} (needs `cargo +stable build`); skipping.");
        return;
    }

    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    tokio::spawn(run_mock_arkd(listener));
    let asp_url = format!("http://127.0.0.1:{port}");

    let (kps, pkp) = dkg_2of2();
    let kp_user = kps[0].clone();
    let kp_cosigner = kps[1].clone();
    let auth = AuthSigner::from_secret_bytes(&scalar_to_bytes(&kp_user.secret_share)).unwrap();
    let user_id = auth.public_key_compressed().to_vec();
    let user_id_hex = hex::encode(&user_id);

    let engine = guest_instance::build_engine().unwrap();
    let component = wasmtime::component::Component::from_file(&engine, &wasm).unwrap();
    let linker = guest_instance::build_linker(&engine).unwrap();
    let mut guest = GuestInstance::spawn(&engine, &component, &linker, None)
        .await
        .unwrap();

    // Install policy WITH the Ark cosigner secret (a valid 32-byte secp scalar).
    let r = guest
        .command(GuestCommand::InstallPolicy {
            group_key: hex::encode(pkp.verifying_key.serialize()),
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(hex::encode(kp_user.identifier.serialize())),
            server_dkg_secret_hex: Some(hex::encode([5u8; 32])),
        })
        .await
        .unwrap();
    assert!(matches!(r, GuestResponse::PolicyInstalled), "got {r:?}");

    // The guest owns the VTXO set — push it before generating the delegate.
    guest
        .command(GuestCommand::SetVtxos {
            vtxos: vec![VtxoInputWire {
                txid: hex::encode([9u8; 32]),
                vout: 0,
                amount_sats: 10_000,
                exit_delay: 144,
            }],
        })
        .await
        .unwrap();

    // Phase 1: GenerateDelegate → sighashes (reads VTXOs from the guest store; the settle
    // output is a self-refresh the guest computes internally).
    let ts1 = now_ms();
    let resp1 = guest
        .command(GuestCommand::GenerateDelegate(GenerateDelegateWire {
            user_id: user_id.clone(),
            signature: auth
                .sign(&build_auth_message(OP_SETTLE_DELEGATE, ts1, &user_id_hex))
                .to_vec(),
            timestamp_ms: ts1,
            asp_url,
            intent_valid_at: None,
        }))
        .await
        .unwrap();
    let sighashes = match resp1 {
        GuestResponse::DelegateSighashes { messages_to_sign } => messages_to_sign,
        other => panic!("GenerateDelegate expected sighashes, got {other:?}"),
    };
    assert!(!sighashes.is_empty(), "no delegate sighashes produced");

    // Phase 2: ApplyDelegateSigs (opaque 64-byte sigs — sign_with_frost only checks length).
    let signed_messages: Vec<Vec<u8>> = sighashes.iter().map(|_| vec![1u8; 64]).collect();
    let ts2 = now_ms();
    let resp2 = guest
        .command(GuestCommand::ApplyDelegateSigs(ApplyDelegateSigsWire {
            user_id: user_id.clone(),
            signature: auth
                .sign(&build_auth_message(OP_SETTLE_DELEGATE, ts2, &user_id_hex))
                .to_vec(),
            timestamp_ms: ts2,
            signed_messages,
        }))
        .await
        .unwrap();
    assert!(
        matches!(resp2, GuestResponse::DelegateReady),
        "ApplyDelegateSigs expected DelegateReady, got {resp2:?}"
    );
    println!("guest delegate setup chain (GenerateDelegate → sign → ReadyToSettle) ✓");
}

// =============================================================================
// Drive SKELETON: register → stream → confirm → finalize (NO MuSig2 tree events).
// Proves the settle_delegate orchestrator wiring + the non-MuSig2 step methods at
// runtime. The tree-signing arms (on_tree_signing_started / on_tree_nonces) need a
// real batch coordinator and are exercised against real arkd, not this mock.
// =============================================================================

fn boxed(bytes: Vec<u8>) -> UnsyncBoxBody<Bytes, Infallible> {
    Full::new(Bytes::from(bytes)).boxed_unsync()
}

async fn run_mock_arkd_drive(listener: tokio::net::TcpListener) {
    loop {
        let Ok((tcp, _)) = listener.accept().await else { continue };
        tokio::spawn(async move {
            let svc = hyper::service::service_fn(handle_drive);
            let _ = hyper::server::conn::http2::Builder::new(TokioExecutor::new())
                .serve_connection(TokioIo::new(tcp), svc)
                .await;
        });
    }
}

async fn handle_drive(
    req: hyper::Request<hyper::body::Incoming>,
) -> Result<hyper::Response<UnsyncBoxBody<Bytes, Infallible>>, Infallible> {
    use ark::client::proto::{
        get_event_stream_response::Event, BatchFinalizationEvent, BatchFinalizedEvent,
        BatchStartedEvent, ConfirmRegistrationResponse, GetInfoResponse, GetEventStreamResponse,
        RegisterIntentResponse,
    };
    let path = req.uri().path().to_string();
    let _ = req.into_body().collect().await;

    let mk = |event| Bytes::from(grpc_frame(&GetEventStreamResponse { event: Some(event) }));
    let body = match path.as_str() {
        "/ark.v1.ArkService/GetInfo" => boxed(grpc_frame(&GetInfoResponse {
            signer_pubkey: xonly_hex(2),
            forfeit_pubkey: xonly_hex(4),
            forfeit_address: regtest_addr(4),
            network: "regtest".to_string(),
            unilateral_exit_delay: 144,
            boarding_exit_delay: 144,
            dust: 330,
            ..Default::default()
        })),
        "/ark.v1.ArkService/RegisterIntent" => boxed(grpc_frame(&RegisterIntentResponse {
            intent_id: "intent1".to_string(),
            ..Default::default()
        })),
        "/ark.v1.ArkService/ConfirmRegistration" => {
            boxed(grpc_frame(&ConfirmRegistrationResponse::default()))
        }
        "/ark.v1.ArkService/GetEventStream" => {
            let frames = vec![
                Ok::<_, Infallible>(Frame::data(mk(Event::BatchStarted(BatchStartedEvent {
                    id: "batch1".to_string(),
                    batch_expiry: 0,
                    ..Default::default()
                })))),
                Ok(Frame::data(mk(Event::BatchFinalization(BatchFinalizationEvent {
                    id: "batch1".to_string(),
                    ..Default::default()
                })))),
                Ok(Frame::data(mk(Event::BatchFinalized(BatchFinalizedEvent {
                    id: "batch1".to_string(),
                    commitment_txid: "commit_abc".to_string(),
                })))),
            ];
            StreamBody::new(futures::stream::iter(frames)).boxed_unsync()
        }
        _ => boxed(grpc_frame(&ConfirmRegistrationResponse::default())),
    };
    Ok(hyper::Response::builder()
        .status(200)
        .header("content-type", "application/grpc")
        .body(body)
        .unwrap())
}

/// Install a policy + run the setup chain so the guest holds a `ReadyToSettle` session.
async fn setup_ready_delegate(guest: &mut GuestInstance, asp_url: &str) {
    let (kps, pkp) = dkg_2of2();
    let kp_user = kps[0].clone();
    let kp_cosigner = kps[1].clone();
    let auth = AuthSigner::from_secret_bytes(&scalar_to_bytes(&kp_user.secret_share)).unwrap();
    let user_id = auth.public_key_compressed().to_vec();
    let user_id_hex = hex::encode(&user_id);

    guest
        .command(GuestCommand::InstallPolicy {
            group_key: hex::encode(pkp.verifying_key.serialize()),
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(hex::encode(kp_user.identifier.serialize())),
            server_dkg_secret_hex: Some(hex::encode([5u8; 32])),
        })
        .await
        .unwrap();

    guest
        .command(GuestCommand::SetVtxos {
            vtxos: vec![VtxoInputWire {
                txid: hex::encode([9u8; 32]),
                vout: 0,
                amount_sats: 10_000,
                exit_delay: 144,
            }],
        })
        .await
        .unwrap();
    let ts1 = now_ms();
    let resp1 = guest
        .command(GuestCommand::GenerateDelegate(GenerateDelegateWire {
            user_id: user_id.clone(),
            signature: auth
                .sign(&build_auth_message(OP_SETTLE_DELEGATE, ts1, &user_id_hex))
                .to_vec(),
            timestamp_ms: ts1,
            asp_url: asp_url.to_string(),
            intent_valid_at: None,
        }))
        .await
        .unwrap();
    let sighashes = match resp1 {
        GuestResponse::DelegateSighashes { messages_to_sign } => messages_to_sign,
        other => panic!("GenerateDelegate: {other:?}"),
    };
    let signed_messages: Vec<Vec<u8>> = sighashes.iter().map(|_| vec![1u8; 64]).collect();
    let ts2 = now_ms();
    let r = guest
        .command(GuestCommand::ApplyDelegateSigs(ApplyDelegateSigsWire {
            user_id,
            signature: auth
                .sign(&build_auth_message(OP_SETTLE_DELEGATE, ts2, &user_id_hex))
                .to_vec(),
            timestamp_ms: ts2,
            signed_messages,
        }))
        .await
        .unwrap();
    assert!(matches!(r, GuestResponse::DelegateReady), "ApplyDelegateSigs: {r:?}");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn guest_settle_delegate_drive_skeleton() {
    let wasm = guest_wasm_path();
    if !wasm.exists() {
        eprintln!("cosigner-guest not built; skipping.");
        return;
    }

    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    tokio::spawn(run_mock_arkd_drive(listener));
    let asp_url = format!("http://127.0.0.1:{port}");

    let engine = guest_instance::build_engine().unwrap();
    let component = wasmtime::component::Component::from_file(&engine, &wasm).unwrap();
    let linker = guest_instance::build_linker(&engine).unwrap();
    let mut guest = GuestInstance::spawn(&engine, &component, &linker, None)
        .await
        .unwrap();

    setup_ready_delegate(&mut guest, &asp_url).await;

    // Drive: register → BatchStarted(confirm) → BatchFinalization(no connectors) → BatchFinalized.
    let resp = guest
        .command(GuestCommand::SettleDelegate { asp_url })
        .await
        .unwrap();
    match resp {
        GuestResponse::SettleSubmitted {
            commitment_txid,
            vtxo_outpoint,
        } => {
            assert_eq!(commitment_txid, "commit_abc");
            assert!(vtxo_outpoint.is_none(), "no tree → no vtxo outpoint");
        }
        other => panic!("SettleDelegate expected SettleSubmitted, got {other:?}"),
    }
    println!("guest settle_delegate drive skeleton (register→stream→confirm→finalize) ✓");
}

// =============================================================================
// Phase 4: sealed-snapshot round-trip — install state in one guest, snapshot it,
// then restore into a FRESH guest and confirm the durable state survived
// (the property that makes actor eviction / reseat safe).
// =============================================================================

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn guest_snapshot_restore_roundtrip() {
    let wasm = guest_wasm_path();
    if !wasm.exists() {
        eprintln!("cosigner-guest not built; skipping.");
        return;
    }

    let engine = guest_instance::build_engine().unwrap();
    let component = wasmtime::component::Component::from_file(&engine, &wasm).unwrap();
    let linker = guest_instance::build_linker(&engine).unwrap();

    let (kps, pkp) = dkg_2of2();
    let kp_user = kps[0].clone();
    let kp_cosigner = kps[1].clone();

    // Guest A: install policy (+ Ark secret), set VTXOs + history, then snapshot.
    let mut guest_a = GuestInstance::spawn(&engine, &component, &linker, None)
        .await
        .unwrap();
    guest_a
        .command(GuestCommand::InstallPolicy {
            group_key: hex::encode(pkp.verifying_key.serialize()),
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(hex::encode(kp_user.identifier.serialize())),
            server_dkg_secret_hex: Some(hex::encode([5u8; 32])),
        })
        .await
        .unwrap();
    guest_a
        .command(GuestCommand::SetVtxos {
            vtxos: vec![VtxoInputWire {
                txid: hex::encode([7u8; 32]),
                vout: 2,
                amount_sats: 12_345,
                exit_delay: 144,
            }],
        })
        .await
        .unwrap();
    guest_a
        .command(GuestCommand::AppendHistory {
            entry: ArkTxEntryWire {
                tx_type: "send".to_string(),
                amount_sats: -1_000,
                txid: "hist1".to_string(),
                timestamp: 42,
            },
        })
        .await
        .unwrap();

    let blob = match guest_a.command(GuestCommand::Snapshot).await.unwrap() {
        GuestResponse::Snapshot { blob } => blob,
        other => panic!("Snapshot: {other:?}"),
    };
    assert!(!blob.is_empty(), "snapshot blob is empty");

    // Guest B: fresh instance, restore from the blob, confirm state survived.
    let mut guest_b = GuestInstance::spawn(&engine, &component, &linker, None)
        .await
        .unwrap();
    // Fresh guest has no VTXOs.
    match guest_b.command(GuestCommand::ListVtxos).await.unwrap() {
        GuestResponse::Vtxos { vtxos } => assert!(vtxos.is_empty()),
        other => panic!("ListVtxos: {other:?}"),
    }
    match guest_b
        .command(GuestCommand::RestoreSnapshot { blob })
        .await
        .unwrap()
    {
        GuestResponse::Restored => {}
        other => panic!("RestoreSnapshot: {other:?}"),
    }

    match guest_b.command(GuestCommand::ListVtxos).await.unwrap() {
        GuestResponse::Vtxos { vtxos } => {
            assert_eq!(vtxos.len(), 1);
            assert_eq!(vtxos[0].amount_sats, 12_345);
            assert_eq!(vtxos[0].vout, 2);
        }
        other => panic!("ListVtxos after restore: {other:?}"),
    }
    match guest_b.command(GuestCommand::ListArkTransactions).await.unwrap() {
        GuestResponse::ArkTransactions { entries } => {
            assert_eq!(entries.len(), 1);
            assert_eq!(entries[0].txid, "hist1");
        }
        other => panic!("ListArkTransactions after restore: {other:?}"),
    }
    println!("guest sealed-snapshot restore round-trip (state survives reseat) ✓");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn guest_delegate_survives_snapshot_and_drives() {
    let wasm = guest_wasm_path();
    if !wasm.exists() {
        eprintln!("cosigner-guest not built; skipping.");
        return;
    }

    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    tokio::spawn(run_mock_arkd_drive(listener));
    let asp_url = format!("http://127.0.0.1:{port}");

    let engine = guest_instance::build_engine().unwrap();
    let component = wasmtime::component::Component::from_file(&engine, &wasm).unwrap();
    let linker = guest_instance::build_linker(&engine).unwrap();

    // Guest A: build a ReadyToSettle delegate, then snapshot.
    let mut guest_a = GuestInstance::spawn(&engine, &component, &linker, None)
        .await
        .unwrap();
    setup_ready_delegate(&mut guest_a, &asp_url).await;
    let blob = match guest_a.command(GuestCommand::Snapshot).await.unwrap() {
        GuestResponse::Snapshot { blob } => blob,
        other => panic!("Snapshot: {other:?}"),
    };

    // Guest B: fresh, restore, then DRIVE the restored delegate to completion.
    let mut guest_b = GuestInstance::spawn(&engine, &component, &linker, None)
        .await
        .unwrap();
    match guest_b
        .command(GuestCommand::RestoreSnapshot { blob })
        .await
        .unwrap()
    {
        GuestResponse::Restored => {}
        other => panic!("RestoreSnapshot: {other:?}"),
    }
    let resp = guest_b
        .command(GuestCommand::SettleDelegate { asp_url })
        .await
        .unwrap();
    match resp {
        GuestResponse::SettleSubmitted { commitment_txid, .. } => {
            assert_eq!(commitment_txid, "commit_abc")
        }
        other => panic!("SettleDelegate after restore: {other:?}"),
    }
    println!("ReadyToSettle delegate survived snapshot→restore and drove to completion ✓");
}
