//! Exact money arithmetic.
//!
//! Everything is integer. BTC amounts are satoshis; USD amounts are cents; prices are cents per
//! whole BTC. Floating point is deliberately absent — a rebalancer that drifts by a cent per tick
//! accumulates a real position error over a day of Ark rounds, and "roughly the right hedge" is
//! indistinguishable from a slow leak.

pub const SATS_PER_BTC: u128 = 100_000_000;

/// USD cents. Signed because a hedge adjustment has a direction.
pub type Cents = i128;

/// The USD value of `sats` at `price_cents_per_btc`, truncated toward zero.
pub fn btc_value_cents(sats: u64, price_cents_per_btc: u64) -> Cents {
    (sats as u128 * price_cents_per_btc as u128 / SATS_PER_BTC) as Cents
}

/// The satoshis that `cents` buys at `price_cents_per_btc`, truncated toward zero.
///
/// Returns 0 for a non-positive amount or a zero price rather than panicking: a missing price is a
/// reason to do nothing this tick, not to crash the service.
pub fn cents_to_sats(cents: Cents, price_cents_per_btc: u64) -> u64 {
    if cents <= 0 || price_cents_per_btc == 0 {
        return 0;
    }
    (cents as u128 * SATS_PER_BTC / price_cents_per_btc as u128)
        .try_into()
        .unwrap_or(u64::MAX)
}

/// `value` as a fraction of `reference`, in basis points. Zero reference ⇒ zero drift, so an empty
/// portfolio reads as "on target" rather than "infinitely off".
pub fn bps_of(value: Cents, reference: Cents) -> i128 {
    if reference == 0 {
        return 0;
    }
    value.saturating_mul(10_000) / reference.abs()
}
