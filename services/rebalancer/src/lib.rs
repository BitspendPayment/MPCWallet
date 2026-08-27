//! A rebalancer service: keeps a VTXO balance worth a fixed number of dollars by holding bitcoin
//! and shorting an equal notional of an inverse perpetual.
//!
//! The bitcoin never leaves the user's threshold key — the hedge is what makes the *balance*
//! dollar-denominated, not a custodian. That is the whole appeal, and also the whole cost: the
//! derivatives leg brings a counterparty, a funding rate, and liquidation risk that plain bitcoin
//! custody does not have. [`venue`] documents the arithmetic and the exposure; [`rebalance`] holds
//! the policy that decides when to act.
//!
//! # Shape
//!
//! - [`rebalance::decide`] is pure: portfolio in, intention out. All the policy lives there.
//! - [`venue::HedgeVenue`] abstracts the derivatives leg; [`venue::PaperVenue`] is an in-memory
//!   inverse perpetual with funding accrual and a maintenance-margin model.
//! - [`price::PriceSource`] abstracts the mark.
//! - [`funding::FundingSource`] is a seam, not an implementation — see its docs for what is
//!   missing underneath and why.

pub mod funding;
pub mod money;
pub mod price;
pub mod rebalance;
pub mod venue;

pub use rebalance::{decide, Decision, FundingAction, Policy, Portfolio};
