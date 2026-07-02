//! Phase 3c-rest (state migration, slice 1): the guest owns the VTXO set. The host pushes
//! it via `SetVtxos`; `ListVtxos` reads it back. Later slices have SendVtxo/GenerateDelegate
//! read from this store and self-update it on send (collapsing the host-side shims).

use std::path::PathBuf;

use cosigner_proto::{ArkTxEntryWire, GuestCommand, GuestResponse, VtxoInputWire};
use cosigner_runtime::cosigner::guest_instance::{self, GuestInstance};

fn guest_wasm_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("cosigner/target/wasm32-wasip2/release/cosigner.wasm")
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn guest_owns_vtxo_set() {
    let wasm = guest_wasm_path();
    if !wasm.exists() {
        eprintln!("cosigner-guest not built; skipping.");
        return;
    }

    let engine = guest_instance::build_engine().unwrap();
    let component = wasmtime::component::Component::from_file(&engine, &wasm).unwrap();
    let linker = guest_instance::build_linker(&engine).unwrap();
    let mut guest = GuestInstance::spawn(&engine, &component, &linker, None)
        .await
        .unwrap();

    // Empty to start.
    match guest.command(GuestCommand::ListVtxos).await.unwrap() {
        GuestResponse::Vtxos { vtxos } => assert!(vtxos.is_empty(), "fresh guest has no VTXOs"),
        other => panic!("ListVtxos: {other:?}"),
    }

    let set = vec![
        VtxoInputWire {
            txid: hex::encode([1u8; 32]),
            vout: 0,
            amount_sats: 10_000,
            exit_delay: 144,
        },
        VtxoInputWire {
            txid: hex::encode([2u8; 32]),
            vout: 1,
            amount_sats: 5_000,
            exit_delay: 144,
        },
    ];
    match guest
        .command(GuestCommand::SetVtxos { vtxos: set.clone() })
        .await
        .unwrap()
    {
        GuestResponse::VtxosSet => {}
        other => panic!("SetVtxos: {other:?}"),
    }

    match guest.command(GuestCommand::ListVtxos).await.unwrap() {
        GuestResponse::Vtxos { vtxos } => {
            assert_eq!(vtxos.len(), 2);
            assert_eq!(vtxos[0].txid, set[0].txid);
            assert_eq!(vtxos[1].amount_sats, 5_000);
        }
        other => panic!("ListVtxos: {other:?}"),
    }
    println!("guest owns its VTXO set (SetVtxos → ListVtxos round-trip) ✓");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn guest_owns_history() {
    let wasm = guest_wasm_path();
    if !wasm.exists() {
        eprintln!("cosigner-guest not built; skipping.");
        return;
    }

    let engine = guest_instance::build_engine().unwrap();
    let component = wasmtime::component::Component::from_file(&engine, &wasm).unwrap();
    let linker = guest_instance::build_linker(&engine).unwrap();
    let mut guest = GuestInstance::spawn(&engine, &component, &linker, None)
        .await
        .unwrap();

    // Restore an initial log, then append one entry (as a send would).
    let initial = vec![ArkTxEntryWire {
        tx_type: "receive".to_string(),
        amount_sats: 10_000,
        txid: "tx_recv".to_string(),
        timestamp: 100,
    }];
    match guest
        .command(GuestCommand::SetHistory { entries: initial })
        .await
        .unwrap()
    {
        GuestResponse::HistoryUpdated => {}
        other => panic!("SetHistory: {other:?}"),
    }
    guest
        .command(GuestCommand::AppendHistory {
            entry: ArkTxEntryWire {
                tx_type: "send".to_string(),
                amount_sats: -5_000,
                txid: "tx_send".to_string(),
                timestamp: 200,
            },
        })
        .await
        .unwrap();

    match guest
        .command(GuestCommand::ListArkTransactions)
        .await
        .unwrap()
    {
        GuestResponse::ArkTransactions { entries } => {
            assert_eq!(entries.len(), 2);
            assert_eq!(entries[0].tx_type, "receive");
            assert_eq!(entries[1].tx_type, "send");
            assert_eq!(entries[1].amount_sats, -5_000);
        }
        other => panic!("ListArkTransactions: {other:?}"),
    }
    println!("guest owns its transaction history (Set/Append/List round-trip) ✓");
}
