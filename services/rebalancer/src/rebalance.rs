//! The rebalance decision — deliberately a pure function.
//!
//! Everything that decides whether to trade lives here, takes a snapshot, and returns an
//! intention. Nothing in this module touches a venue, a cosigner, or a clock, so the policy can be
//! driven across a scripted price path in a test rather than inferred from production behaviour.

use crate::money::{bps_of, btc_value_cents, cents_to_sats, Cents};
use crate::venue::{MarginHealth, Position};

/// Everything the decision needs to see.
#[derive(Debug, Clone, Copy)]
pub struct Portfolio {
    /// Spendable off-chain balance backing the synthetic dollar.
    pub vtxo_sats: u64,
    /// Confirmed on-chain funds that could be boarded if more collateral is needed.
    pub boarding_sats: u64,
    pub price_cents_per_btc: u64,
    pub position: Position,
    pub margin_health: MarginHealth,
    /// Mark-to-market PnL on the hedge, in satoshis. Part of the collateral: an inverse short
    /// gains BTC as the price falls, and that gain is what offsets the collateral's lost value.
    pub unrealized_pnl_sats: i64,
}

impl Portfolio {
    /// Every satoshi the strategy controls: VTXOs, posted margin, and the hedge's mark-to-market.
    ///
    /// All three must be counted. Hedging only the VTXO balance would leave the margin and the
    /// PnL unhedged, and — worse — would make the target notional *fall* as the price falls, so
    /// the rebalancer would sell off exactly the protection that was working.
    pub fn collateral_sats(&self) -> u64 {
        let total = self.vtxo_sats as i128
            + self.position.margin_sats as i128
            + self.unrealized_pnl_sats as i128;
        total.max(0).try_into().unwrap_or(u64::MAX)
    }

    /// USD value of the collateral at the current mark.
    pub fn collateral_cents(&self) -> Cents {
        btc_value_cents(self.collateral_sats(), self.price_cents_per_btc)
    }
}

/// How tightly to hold the peg, and what it may do about it.
#[derive(Debug, Clone, Copy)]
pub struct Policy {
    /// The dollar balance to maintain, in cents.
    pub target_cents: Cents,
    /// Do not touch the hedge while it is within this many basis points of fully hedged.
    ///
    /// This is the single most important knob. Ark produces rounds constantly, and a rebalancer
    /// that trades on every one of them pays fees and funding to chase noise. Evaluating each
    /// round is right; ACTING each round is not.
    pub hedge_deadband_bps: i64,
    /// Do not move funds while the collateral is within this many basis points of the target.
    pub funding_deadband_bps: i64,
    /// Never emit a hedge adjustment smaller than this — below it, fees dominate the correction.
    pub min_trade_cents: Cents,
    /// Margin to keep posted, as basis points of notional. Above the venue's maintenance
    /// requirement, so a normal price move does not immediately become a margin call.
    pub margin_buffer_bps: i64,
}

impl Default for Policy {
    fn default() -> Self {
        Self {
            target_cents: 0,
            hedge_deadband_bps: 100, // 1%
            funding_deadband_bps: 200, // 2%
            min_trade_cents: 100,    // $1
            margin_buffer_bps: 1_000, // 10%
        }
    }
}

/// Moving value in or out of the hedged balance.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FundingAction {
    /// The balance is short of target: board this much from on-chain funds.
    BoardSats { sats: u64 },
    /// The balance is short of target and there are no on-chain funds to board.
    Underfunded { shortfall_cents: Cents },
    /// The balance exceeds target: collaboratively exit this much.
    TakeAwaySats { sats: u64 },
}

/// What the rebalancer intends to do this tick.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Decision {
    /// Change in short notional, in USD cents. `None` = inside the deadband, leave it alone.
    pub hedge_delta_cents: Option<Cents>,
    /// Extra margin to post before adjusting.
    pub post_margin_sats: u64,
    pub funding: Option<FundingAction>,
    /// Why this tick did what it did — logged, and asserted on in tests.
    pub reason: &'static str,
}

/// Decide what to do with the portfolio.
///
/// Order matters. A liquidated or at-risk position is dealt with before the peg, because a hedge
/// that is about to be closed out by the venue is not a hedge, and trading into it makes things
/// worse rather than better.
pub fn decide(p: &Portfolio, policy: &Policy) -> Decision {
    if p.price_cents_per_btc == 0 {
        return Decision {
            reason: "no price this tick — a stale mark is a reason to do nothing, not to guess",
            ..Default::default()
        };
    }

    if p.margin_health == MarginHealth::Liquidated {
        return Decision {
            reason: "position liquidated — the hedge is gone and cannot be adjusted",
            ..Default::default()
        };
    }

    // A fully hedged position shorts notional equal to the collateral's dollar value.
    let target_notional = p.collateral_cents();
    let drift = target_notional - p.position.short_notional_cents;

    // Margin needed to carry the target notional, with the policy buffer on top.
    let want_margin_sats = cents_to_sats(
        target_notional * policy.margin_buffer_bps as i128 / 10_000,
        p.price_cents_per_btc,
    );
    let post_margin_sats = want_margin_sats.saturating_sub(p.position.margin_sats);

    if p.margin_health == MarginHealth::AtRisk {
        return Decision {
            hedge_delta_cents: None,
            post_margin_sats,
            funding: None,
            reason: "margin at risk — top up before touching the notional",
        };
    }

    // --- the peg ---
    let drift_bps = bps_of(drift, target_notional).abs();
    let hedge_delta = if target_notional == 0 && p.position.short_notional_cents != 0 {
        // No collateral left but still short: close out. There is no deadband on this, because
        // an unbacked short is naked exposure, not a small tracking error.
        Some(-p.position.short_notional_cents)
    } else if drift_bps > policy.hedge_deadband_bps as i128 && drift.abs() >= policy.min_trade_cents {
        Some(drift)
    } else {
        None
    };

    // --- the funding level ---
    let collateral = p.collateral_cents();
    let gap = policy.target_cents - collateral;
    let gap_bps = bps_of(gap, policy.target_cents).abs();
    let funding = if policy.target_cents == 0 || gap_bps <= policy.funding_deadband_bps as i128 {
        None
    } else if gap > 0 {
        let needed = cents_to_sats(gap, p.price_cents_per_btc);
        if p.boarding_sats == 0 {
            Some(FundingAction::Underfunded {
                shortfall_cents: gap,
            })
        } else {
            Some(FundingAction::BoardSats {
                sats: needed.min(p.boarding_sats),
            })
        }
    } else {
        // Only VTXOs can actually be taken away; margin is committed to the hedge.
        Some(FundingAction::TakeAwaySats {
            sats: cents_to_sats(-gap, p.price_cents_per_btc).min(p.vtxo_sats),
        })
    };

    let reason = match (&hedge_delta, &funding) {
        (None, None) => "within both deadbands — no action",
        (Some(_), None) => "hedge drifted outside the deadband",
        (None, Some(_)) => "collateral outside the target band",
        (Some(_), Some(_)) => "hedge and collateral both outside their bands",
    };

    Decision {
        hedge_delta_cents: hedge_delta,
        post_margin_sats,
        funding,
        reason,
    }
}
