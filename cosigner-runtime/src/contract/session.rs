//! Per-user contract-create ceremony state. Owned by the `ContractManager`, evicted on
//! TTL or after step4 finalizes. Reuses the shared [`CeremonyRounds`] FROST core; adds
//! the reshare context (the old key being reshared + the contract/ASP/service params).
//!
//! No rendezvous pool: the ceremony is a strict 2-of-2 {user, cosigner} where the
//! cosigner is the server and self-deals, so every step completes on its single call.

use std::time::Instant;

use threshold::keys::{KeyPackage, PublicKeyPackage};

use crate::ceremony::CeremonyRounds;

pub struct ContractSession {
    pub rounds: CeremonyRounds,

    // Reshare context: captured at step1, consumed at step3/step4 finalize.
    pub contract_id: Vec<u8>,
    pub contract_wasm: Vec<u8>,
    /// The existing key being reshared (the cosigner's master share + group PKP).
    pub old_kp: Option<KeyPackage>,
    pub old_pkp: Option<PublicKeyPackage>,
    pub server_pk: Vec<u8>,
    pub exit_delay: u32,
    /// User-supplied unilateral-exit x-only key for the contract (exit leaf).
    pub owner_pk: Vec<u8>,
    /// The always-online service's verifying key — the contract's service pairing.
    pub service_vk: Vec<u8>,

    pub last_touch: Instant,
}

impl ContractSession {
    pub fn new() -> Self {
        Self {
            rounds: CeremonyRounds::default(),
            contract_id: Vec::new(),
            contract_wasm: Vec::new(),
            old_kp: None,
            old_pkp: None,
            server_pk: Vec::new(),
            exit_delay: 0,
            owner_pk: Vec::new(),
            service_vk: Vec::new(),
            last_touch: Instant::now(),
        }
    }
}
