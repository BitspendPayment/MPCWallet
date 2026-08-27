//! Moving value into and out of the hedged balance.
//!
//! # Status: seams, not implementations
//!
//! Both operations the rebalancer needs here are **not built**, and both are larger than they look:
//!
//! - **Collaborative exit.** The cosigner's `RedeemVtxo` returns `unimplemented`, and the ASP
//!   offboard field that a redeem would populate (`onchain_output_indexes`) is hardcoded empty in
//!   the Ark client. The machinery exists in the vendored `ark-core`; nothing calls it.
//! - **Spending boarding inputs.** A service cannot see the chain. Today the wallet is the only
//!   chain-viewer and owns broadcast; the cosigner's esplora watcher exists to fire a "tap to
//!   board" notification and nothing more. Giving a service this capability moves a trust
//!   boundary and deserves its own design.
//!
//! So this trait exists to keep the rebalance loop honest: it decides what it WOULD do, the
//! decision is testable, and the unimplemented path returns a typed error naming the gap rather
//! than silently doing nothing.

#[derive(Debug, thiserror::Error)]
pub enum FundingError {
    #[error("{operation} is not implemented: {why}")]
    NotImplemented {
        operation: &'static str,
        why: &'static str,
    },
    #[error("funding failed: {0}")]
    Failed(String),
}

/// Moves value between the on-chain and off-chain sides of the balance.
pub trait FundingSource {
    /// Promote confirmed on-chain funds into VTXOs.
    fn spend_boarding_input(&mut self, sats: u64) -> Result<(), FundingError>;

    /// Take value off the Ark layer cooperatively, to an on-chain address.
    fn collaborative_exit(&mut self, sats: u64, to_address: &str) -> Result<(), FundingError>;
}

/// The current state of the world: the decision is made, the action is refused.
///
/// Deliberately loud. A no-op stub would let the loop look healthy while the balance drifted, and
/// "the rebalancer ran fine" is a much worse failure report than "the rebalancer cannot take
/// funds away yet".
pub struct UnimplementedFunding;

impl FundingSource for UnimplementedFunding {
    fn spend_boarding_input(&mut self, _sats: u64) -> Result<(), FundingError> {
        Err(FundingError::NotImplemented {
            operation: "spend_boarding_input",
            why: "a service has no chain view; boarding is wallet-driven and the wallet owns broadcast",
        })
    }

    fn collaborative_exit(&mut self, _sats: u64, _to_address: &str) -> Result<(), FundingError> {
        Err(FundingError::NotImplemented {
            operation: "collaborative_exit",
            why: "the cosigner's RedeemVtxo is unimplemented and the ASP offboard path is unwired",
        })
    }
}
