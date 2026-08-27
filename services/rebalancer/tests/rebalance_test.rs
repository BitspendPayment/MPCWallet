//! What the rebalancer decides, and what it costs.
//!
//! The headline is `a_maintained_hedge_holds_the_dollar_value_across_a_price_path` — the property
//! the whole service exists to provide — paired with the tests that show the price of providing
//! it: funding bleeds the position, and an inverse short's margin falls exactly when the short is
//! losing.

use rebalancer::money::{btc_value_cents, Cents};
use rebalancer::rebalance::{decide, FundingAction, Policy, Portfolio};
use rebalancer::venue::{HedgeVenue, MarginHealth, PaperVenue, Position, VenueError};

const BTC: u64 = 100_000_000;
/// $65,000.00
const P0: u64 = 6_500_000;

fn flat_position() -> Position {
    Position {
        short_notional_cents: 0,
        margin_sats: 0,
        funding_paid_sats: 0,
    }
}

fn portfolio(vtxo_sats: u64, price: u64, pos: Position) -> Portfolio {
    Portfolio {
        vtxo_sats,
        boarding_sats: 0,
        price_cents_per_btc: price,
        position: pos,
        margin_health: MarginHealth::Healthy,
        unrealized_pnl_sats: 0,
    }
}

/// Snapshot the strategy as the loop would see it: VTXOs plus whatever the venue reports.
fn portfolio_from(vtxo_sats: u64, venue: &PaperVenue) -> Portfolio {
    Portfolio {
        vtxo_sats,
        boarding_sats: 0,
        price_cents_per_btc: venue.price(),
        position: venue.position(),
        margin_health: venue.margin_health(),
        unrealized_pnl_sats: venue.unrealized_pnl_sats(),
    }
}

fn hedged_policy() -> Policy {
    Policy {
        target_cents: 0, // funding logic disabled; these tests are about the hedge
        ..Policy::default()
    }
}

// ---------------------------------------------------------------------------
// The decision
// ---------------------------------------------------------------------------

#[test]
fn an_unhedged_balance_is_hedged_to_its_full_dollar_value() {
    let p = portfolio(BTC, P0, flat_position());
    let d = decide(&p, &hedged_policy());
    assert_eq!(d.hedge_delta_cents, Some(btc_value_cents(BTC, P0)));
}

#[test]
fn a_hedge_inside_the_deadband_is_left_alone() {
    // 0.5% off, deadband 1%.
    let target = btc_value_cents(BTC, P0);
    let pos = Position {
        short_notional_cents: target * 9_950 / 10_000,
        ..flat_position()
    };
    let d = decide(&portfolio(BTC, P0, pos), &hedged_policy());
    assert_eq!(d.hedge_delta_cents, None, "{}", d.reason);
    assert_eq!(d.reason, "within both deadbands — no action");
}

#[test]
fn a_hedge_outside_the_deadband_is_corrected() {
    // 5% off, deadband 1%.
    let target = btc_value_cents(BTC, P0);
    let pos = Position {
        short_notional_cents: target * 9_500 / 10_000,
        ..flat_position()
    };
    let d = decide(&portfolio(BTC, P0, pos), &hedged_policy());
    assert_eq!(d.hedge_delta_cents, Some(target - pos.short_notional_cents));
}

#[test]
fn a_correction_below_the_minimum_trade_is_not_worth_making() {
    let policy = Policy {
        min_trade_cents: 1_000_000, // $10k floor: nothing here clears it
        ..hedged_policy()
    };
    let target = btc_value_cents(BTC, P0);
    let pos = Position {
        short_notional_cents: target * 9_500 / 10_000,
        ..flat_position()
    };
    assert_eq!(decide(&portfolio(BTC, P0, pos), &policy).hedge_delta_cents, None);
}

#[test]
fn a_short_with_no_collateral_left_is_closed_without_a_deadband() {
    // Naked exposure is not a tracking error, so the deadband does not apply.
    let pos = Position {
        short_notional_cents: 500_000,
        ..flat_position()
    };
    let d = decide(&portfolio(0, P0, pos), &hedged_policy());
    assert_eq!(d.hedge_delta_cents, Some(-500_000));
}

#[test]
fn a_missing_price_produces_no_action_rather_than_a_guess() {
    let d = decide(&portfolio(BTC, 0, flat_position()), &hedged_policy());
    assert_eq!(d.hedge_delta_cents, None);
    assert_eq!(d.post_margin_sats, 0);
    assert_eq!(d.funding, None);
    assert!(d.reason.contains("stale mark"));
}

#[test]
fn an_at_risk_margin_is_topped_up_before_the_notional_is_touched() {
    let target = btc_value_cents(BTC, P0);
    let mut p = portfolio(BTC, P0, Position {
        short_notional_cents: target / 2, // badly off, but that is not the priority
        ..flat_position()
    });
    p.margin_health = MarginHealth::AtRisk;

    let d = decide(&p, &hedged_policy());
    assert_eq!(d.hedge_delta_cents, None, "must not trade into a margin call");
    assert!(d.post_margin_sats > 0);
    assert!(d.reason.contains("margin at risk"));
}

#[test]
fn a_liquidated_position_is_reported_not_traded() {
    let mut p = portfolio(BTC, P0, flat_position());
    p.margin_health = MarginHealth::Liquidated;
    let d = decide(&p, &hedged_policy());
    assert_eq!(d.hedge_delta_cents, None);
    assert_eq!(d.post_margin_sats, 0);
    assert!(d.reason.contains("liquidated"));
}

// ---------------------------------------------------------------------------
// Funding level
// ---------------------------------------------------------------------------

#[test]
fn a_surplus_is_taken_away() {
    let policy = Policy {
        target_cents: 500_000, // $5,000.00 in cents
        ..Policy::default()
    };
    // 1 BTC at $65k = $65,000 — far above target.
    let d = decide(&portfolio(BTC, P0, flat_position()), &policy);
    match d.funding {
        Some(FundingAction::TakeAwaySats { sats }) => assert!(sats > 0 && sats <= BTC),
        other => panic!("expected a take-away, got {other:?}"),
    }
}

#[test]
fn a_shortfall_with_boardable_funds_boards_them() {
    let policy = Policy {
        target_cents: 6_500_000, // $65,000.00 in cents
        ..Policy::default()
    };
    let mut p = portfolio(BTC / 2, P0, flat_position());
    p.boarding_sats = BTC / 4;

    match decide(&p, &policy).funding {
        Some(FundingAction::BoardSats { sats }) => assert_eq!(sats, BTC / 4, "capped by what exists"),
        other => panic!("expected boarding, got {other:?}"),
    }
}

#[test]
fn a_shortfall_with_nothing_to_board_is_reported_as_underfunded() {
    let policy = Policy {
        target_cents: 6_500_000, // $65,000.00 in cents
        ..Policy::default()
    };
    match decide(&portfolio(BTC / 2, P0, flat_position()), &policy).funding {
        Some(FundingAction::Underfunded { shortfall_cents }) => assert!(shortfall_cents > 0),
        other => panic!("expected underfunded, got {other:?}"),
    }
}

#[test]
fn a_balance_inside_the_funding_band_is_left_alone() {
    let on_target = btc_value_cents(BTC, P0);
    let policy = Policy {
        target_cents: on_target,
        ..Policy::default()
    };
    assert_eq!(decide(&portfolio(BTC, P0, flat_position()), &policy).funding, None);
}

// ---------------------------------------------------------------------------
// The property the service exists for
// ---------------------------------------------------------------------------

/// Hold bitcoin, short an equal dollar notional, rebalance on the deadband — and the dollar value
/// of the position stays put while the price moves a long way in both directions.
#[test]
fn a_maintained_hedge_holds_the_dollar_value_across_a_price_path() {
    let vtxo_sats = BTC;
    let mut venue = PaperVenue::new(P0);
    venue.post_margin(BTC / 5).unwrap();

    let policy = hedged_policy();

    // Baseline is EVERYTHING the strategy controls — VTXOs plus posted margin.
    let baseline: Cents = btc_value_cents(vtxo_sats + venue.position().margin_sats, P0);

    // Establish the hedge.
    let d = decide(&portfolio_from(vtxo_sats, &venue), &policy);
    venue.adjust(d.hedge_delta_cents.expect("initial hedge")).unwrap();

    // -40% to +55%.
    let mut trades = 0usize;
    for step in [-40i64, -30, -20, -10, -5, 0, 10, 25, 40, 55] {
        let price = ((P0 as i64) + (P0 as i64) * step / 100) as u64;
        venue.set_price(price);

        let p = portfolio_from(vtxo_sats, &venue);
        let d = decide(&p, &policy);
        if let Some(delta) = d.hedge_delta_cents {
            if venue.adjust(delta).is_ok() {
                trades += 1;
            }
        }

        let total = portfolio_from(vtxo_sats, &venue).collateral_cents();
        let drift_bps = ((total - baseline) * 10_000 / baseline).abs();
        assert!(
            drift_bps <= 100,
            "at {step}% the value drifted {drift_bps} bps (was {baseline}, now {total})"
        );
    }

    // A correctly sized inverse short is SELF-maintaining under pure price moves: the notional it
    // needs is the collateral's dollar value, and that is exactly what the hedge holds constant.
    // So the deadband should barely fire. Churn here would mean paying fees to chase noise.
    assert!(
        trades <= 2,
        "a hedge that needs {trades} trades across a pure price path is chasing noise"
    );
}

/// The counterpart: leave the hedge alone and the "dollar" balance simply tracks bitcoin. This is
/// what the service is preventing, and it is worth being able to see.
#[test]
fn an_unhedged_balance_tracks_the_price_instead() {
    let baseline = btc_value_cents(BTC, P0);
    let halved = btc_value_cents(BTC, P0 / 2);
    assert!(
        (halved * 10_000 / baseline - 10_000).abs() > 4_000,
        "unhedged, a 50% price move is a 50% balance move"
    );
}

// ---------------------------------------------------------------------------
// What the hedge costs
// ---------------------------------------------------------------------------

#[test]
fn funding_is_a_real_cost_and_accrues_against_the_position() {
    let mut venue = PaperVenue::new(P0).with_funding_rate_bps(10); // 0.1% per period
    venue.post_margin(BTC / 2).unwrap();
    venue.adjust(btc_value_cents(BTC, P0)).unwrap();

    let before = venue.position().margin_sats;
    for _ in 0..10 {
        venue.accrue_funding();
    }
    let after = venue.position();

    assert!(after.funding_paid_sats > 0, "a short paid funding");
    assert!(after.margin_sats < before, "funding comes out of margin");
}

#[test]
fn a_negative_funding_rate_pays_the_short() {
    let mut venue = PaperVenue::new(P0).with_funding_rate_bps(-10);
    venue.post_margin(BTC / 2).unwrap();
    venue.adjust(btc_value_cents(BTC, P0)).unwrap();

    let before = venue.position().margin_sats;
    venue.accrue_funding();
    assert!(venue.position().funding_paid_sats < 0);
    assert!(venue.position().margin_sats > before);
}

/// The structural hazard of an inverse short: margin is denominated in the asset whose fall the
/// short is betting on, so the requirement rises exactly when the collateral is worth less.
#[test]
fn a_rising_price_can_push_an_inverse_short_into_a_margin_call() {
    let mut venue = PaperVenue::new(P0).with_maintenance_bps(2_000); // 20%
    venue.post_margin(BTC / 40).unwrap();
    venue.adjust(btc_value_cents(BTC / 8, P0)).unwrap();
    assert_eq!(venue.margin_health(), MarginHealth::Healthy);

    venue.set_price(P0 * 4); // price runs away from the short
    assert_ne!(
        venue.margin_health(),
        MarginHealth::Healthy,
        "a 4x move against an inverse short must not read as healthy"
    );
}

#[test]
fn a_position_cannot_be_opened_without_the_margin_to_carry_it() {
    let mut venue = PaperVenue::new(P0);
    match venue.adjust(btc_value_cents(BTC, P0)) {
        Err(VenueError::InsufficientMargin { needed_sats }) => assert!(needed_sats > 0),
        other => panic!("expected an insufficient-margin refusal, got {other:?}"),
    }
}

#[test]
fn a_liquidated_venue_refuses_further_trading() {
    let mut venue = PaperVenue::new(P0).with_maintenance_bps(1);
    venue.post_margin(20_000).unwrap();
    venue.adjust(btc_value_cents(BTC, P0)).unwrap();
    venue.set_price(P0 * 100); // catastrophic move against the short
    assert_eq!(venue.margin_health(), MarginHealth::Liquidated);
    assert!(matches!(venue.adjust(-1), Err(VenueError::Liquidated)));
}
