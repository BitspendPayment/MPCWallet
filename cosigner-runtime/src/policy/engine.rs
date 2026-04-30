use super::state::{PolicyState, ProtectedPolicy};
use std::time::{SystemTime, UNIX_EPOCH};

/// Policy evaluation engine.
/// Determines which spending policy applies to a transaction based on
/// cumulative spending within the current time window.
pub struct PolicyEngine;

impl PolicyEngine {
    /// Evaluate which policy should be used for a transaction of the given amount.
    /// Returns `Some(policy_id)` if a protected policy applies, `None` for normal policy.
    pub fn evaluate_policy(
        policy_state: &PolicyState,
        spending_amount_sats: i64,
    ) -> Option<String> {
        let now_ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;

        for (id, policy) in &policy_state.protected_policies {
            let cumulative = Self::cumulative_spending_in_window(
                policy,
                &policy_state.spending_history,
                now_ms,
            );

            if cumulative + spending_amount_sats > policy.threshold_sats {
                return Some(id.clone());
            }
        }

        None
    }

    /// Calculate cumulative spending within the current time window for a policy.
    fn cumulative_spending_in_window(
        policy: &ProtectedPolicy,
        history: &[super::state::SpendingEntry],
        now_ms: i64,
    ) -> i64 {
        if policy.interval_seconds <= 0 {
            return 0;
        }

        let interval_ms = policy.interval_seconds * 1000;
        let elapsed_ms = now_ms - policy.start_time_ms;
        if elapsed_ms < 0 {
            return 0;
        }

        let intervals_passed = elapsed_ms / interval_ms;
        let window_start_ms = policy.start_time_ms + (intervals_passed * interval_ms);

        history
            .iter()
            .filter(|entry| entry.timestamp_ms >= window_start_ms)
            .map(|entry| entry.amount_sats)
            .sum()
    }
}
