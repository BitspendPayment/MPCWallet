//! The derivatives leg.
//!
//! # Why an inverse perpetual
//!
//! An inverse perpetual is USD-denominated but margined and settled in BTC, which is exactly the
//! shape needed to make a bitcoin balance behave like dollars. Holding `B` BTC and shorting `Q`
//! USD of notional entered at price `P0`, the position's BTC total at price `P` is
//!
//! ```text
//! B + Q·(1/P − 1/P0)                       (a short gains BTC as the price falls)
//! ```
//!
//! whose USD value is `B·P + Q − Q·P/P0`. That is flat in `P` exactly when `Q = B·P0` — short
//! notional equal to the collateral's dollar value at entry. The dollar value then stays pinned at
//! `B·P0` whatever the price does. This is the Stablesats construction.
//!
//! # What it costs
//!
//! Dollar stability is not free and this trait exposes the price rather than hiding it:
//!
//! - **Funding.** A perpetual pays or charges funding periodically. Holding a short costs (or
//!   earns) real money over time, and over a long enough horizon funding dominates.
//! - **Liquidation.** An inverse short is margined in BTC, whose value falls exactly when the
//!   short is losing. The margin currency and the losing direction are correlated, which is the
//!   worst arrangement available; maintenance margin is not a formality here.
//!
//! [`PaperVenue`] models both so those costs show up in tests instead of in production.

use crate::money::Cents;

/// A snapshot of the hedge position.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Position {
    /// Short notional in USD cents. Zero means unhedged.
    pub short_notional_cents: Cents,
    /// BTC posted as margin, in satoshis.
    pub margin_sats: u64,
    /// Cumulative funding paid (positive) or received (negative), in satoshis.
    pub funding_paid_sats: i64,
}

/// Health of the margin account. `Liquidated` is terminal for the position.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MarginHealth {
    Healthy,
    /// Below the maintenance threshold — the position must be reduced or margin added.
    AtRisk,
    Liquidated,
}

#[derive(Debug, thiserror::Error)]
pub enum VenueError {
    #[error("venue unavailable: {0}")]
    Unavailable(String),
    #[error("insufficient margin: need {needed_sats} more sats")]
    InsufficientMargin { needed_sats: u64 },
    #[error("position is liquidated")]
    Liquidated,
}

/// A venue that can hold an inverse perpetual short.
///
/// Deliberately narrow: the rebalancer only ever needs to read the position and move the notional.
/// A real adapter (an exchange, or a DLC against a price oracle) implements this without the
/// rebalancer learning anything about which it is.
pub trait HedgeVenue {
    fn position(&self) -> Position;

    /// Funding rate for the current period, in basis points of notional. Positive = the short pays.
    fn funding_rate_bps(&self) -> i64;

    fn margin_health(&self) -> MarginHealth;

    /// Mark-to-market PnL in satoshis. Part of the collateral the rebalancer hedges — see
    /// `Portfolio::collateral_sats`.
    fn unrealized_pnl_sats(&self) -> i64;

    /// Move the short notional by `delta_cents` (positive = short more).
    fn adjust(&mut self, delta_cents: Cents) -> Result<(), VenueError>;

    /// Post additional BTC margin.
    fn post_margin(&mut self, sats: u64) -> Result<(), VenueError>;
}

/// An in-memory inverse perpetual. Not a simulation of any particular exchange — enough of one to
/// make the rebalance loop testable against a scripted price path, including the two ways the
/// position actually hurts you: funding accrual and a margin call.
pub struct PaperVenue {
    price_cents_per_btc: u64,
    entry_price_cents: u64,
    short_notional_cents: Cents,
    margin_sats: u64,
    funding_paid_sats: i64,
    funding_rate_bps: i64,
    /// Maintenance margin as basis points of notional.
    maintenance_bps: i64,
    liquidated: bool,
}

impl PaperVenue {
    pub fn new(price_cents_per_btc: u64) -> Self {
        Self {
            price_cents_per_btc,
            entry_price_cents: price_cents_per_btc,
            short_notional_cents: 0,
            margin_sats: 0,
            funding_paid_sats: 0,
            funding_rate_bps: 0,
            maintenance_bps: 500, // 5%
            liquidated: false,
        }
    }

    pub fn with_funding_rate_bps(mut self, bps: i64) -> Self {
        self.funding_rate_bps = bps;
        self
    }

    pub fn with_maintenance_bps(mut self, bps: i64) -> Self {
        self.maintenance_bps = bps;
        self
    }

    /// Move the mark price. Drives unrealized PnL and margin health.
    pub fn set_price(&mut self, price_cents_per_btc: u64) {
        self.price_cents_per_btc = price_cents_per_btc;
    }

    pub fn price(&self) -> u64 {
        self.price_cents_per_btc
    }

    /// Unrealized PnL in satoshis: `Q·(1/P − 1/P0)` for a short, expressed in sats.
    pub fn pnl_sats(&self) -> i64 {
        if self.short_notional_cents == 0 || self.price_cents_per_btc == 0 {
            return 0;
        }
        let q = self.short_notional_cents;
        let at_mark = crate::money::cents_to_sats(q, self.price_cents_per_btc) as i128;
        let at_entry = crate::money::cents_to_sats(q, self.entry_price_cents) as i128;
        (at_mark - at_entry).try_into().unwrap_or(i64::MAX)
    }

    /// Accrue one funding period. Positive rate ⇒ the short pays.
    pub fn accrue_funding(&mut self) {
        if self.short_notional_cents == 0 {
            return;
        }
        let owed_cents = self.short_notional_cents * self.funding_rate_bps as i128 / 10_000;
        let owed_sats = crate::money::cents_to_sats(owed_cents.abs(), self.price_cents_per_btc);
        let signed = if owed_cents >= 0 {
            owed_sats as i64
        } else {
            -(owed_sats as i64)
        };
        self.funding_paid_sats += signed;
        self.margin_sats = self.margin_sats.saturating_sub(signed.max(0) as u64);
        if signed < 0 {
            self.margin_sats = self.margin_sats.saturating_add((-signed) as u64);
        }
        self.check_liquidation();
    }

    fn maintenance_sats(&self) -> u64 {
        let req_cents = self.short_notional_cents * self.maintenance_bps as i128 / 10_000;
        crate::money::cents_to_sats(req_cents, self.price_cents_per_btc)
    }

    /// Equity in sats: posted margin plus unrealized PnL.
    fn equity_sats(&self) -> i64 {
        self.margin_sats as i64 + self.pnl_sats()
    }

    fn check_liquidation(&mut self) {
        if self.short_notional_cents != 0 && self.equity_sats() <= 0 {
            self.liquidated = true;
        }
    }
}

impl HedgeVenue for PaperVenue {
    fn position(&self) -> Position {
        Position {
            short_notional_cents: self.short_notional_cents,
            margin_sats: self.margin_sats,
            funding_paid_sats: self.funding_paid_sats,
        }
    }

    fn funding_rate_bps(&self) -> i64 {
        self.funding_rate_bps
    }

    fn unrealized_pnl_sats(&self) -> i64 {
        self.pnl_sats()
    }

    fn margin_health(&self) -> MarginHealth {
        if self.liquidated {
            return MarginHealth::Liquidated;
        }
        if self.short_notional_cents == 0 {
            return MarginHealth::Healthy;
        }
        let equity = self.equity_sats();
        if equity <= 0 {
            MarginHealth::Liquidated
        } else if (equity as u64) < self.maintenance_sats() {
            MarginHealth::AtRisk
        } else {
            MarginHealth::Healthy
        }
    }

    fn adjust(&mut self, delta_cents: Cents) -> Result<(), VenueError> {
        if self.liquidated {
            return Err(VenueError::Liquidated);
        }
        let new_notional = (self.short_notional_cents + delta_cents).max(0);

        // Changing the position REALIZES the PnL accrued so far into margin, then re-marks the
        // entry to the current price. Resetting the entry without banking the PnL first would
        // silently erase it — which reads in a backtest as a hedge that quietly stops working
        // every time it is adjusted.
        if new_notional != self.short_notional_cents {
            let realized = self.pnl_sats();
            if realized >= 0 {
                self.margin_sats = self.margin_sats.saturating_add(realized as u64);
            } else {
                let loss = realized.unsigned_abs();
                if loss >= self.margin_sats {
                    self.margin_sats = 0;
                    self.liquidated = true;
                    return Err(VenueError::Liquidated);
                }
                self.margin_sats -= loss;
            }
            self.entry_price_cents = self.price_cents_per_btc;
        }

        let required = {
            let req_cents = new_notional * self.maintenance_bps as i128 / 10_000;
            crate::money::cents_to_sats(req_cents, self.price_cents_per_btc)
        };
        if self.margin_sats < required {
            return Err(VenueError::InsufficientMargin {
                needed_sats: required - self.margin_sats,
            });
        }
        self.short_notional_cents = new_notional;
        Ok(())
    }

    fn post_margin(&mut self, sats: u64) -> Result<(), VenueError> {
        if self.liquidated {
            return Err(VenueError::Liquidated);
        }
        self.margin_sats = self.margin_sats.saturating_add(sats);
        Ok(())
    }
}
