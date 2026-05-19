# Bugs

Known issues, gaps in test coverage, and edge cases that aren't fully addressed
by the current implementation. Each entry describes the failure mode, why it's
hard to exercise from existing test surfaces, and what would be needed for
proper coverage.

For *fixes that haven't shipped yet*, see [TODO.md](TODO.md). This file is for
issues that are either fixed-but-incompletely-tested, or accepted-as-known
without an immediate plan to address.

---

## 1. E2E test for receive history doesn't exercise active-session race

**Location:** [`e2e/test/ark_e2e_test.dart`](e2e/test/ark_e2e_test.dart) — the
"Full flow - fund boarding, settle, send Alice→Bob" test.

**Related fix:** TODO #2 in [TODO.md](TODO.md) (server-side `ark_tx_history`
drops receives during any active session) — fixed in
[`cosigner-runtime/src/cosigner/handlers/vtxo_stream.rs`](cosigner-runtime/src/cosigner/handlers/vtxo_stream.rs).

**Status:** the test asserts the *symptom* (history is missing receives) under
the most common code path. Catches the common-case regression but doesn't
exercise the original failure window directly.

### What's not covered

The new assertions verify Bob's `listArkTransactions` includes a `"receive"`
entry after each send from Alice. But in the test, Alice's send paths run
back-to-back and Bob is a passive receiver with no in-flight session of his
own — so Bob never has `state.settle_session = Some(...)` at the moment a
receive arrives.

The original failure mode of the gate was specifically:

> Third party sends a VTXO to Bob *while* Bob has an active session
> (`settle_session`, `delegate_session`, or `send_session`) — including a
> stale one left over from an aborted boarding attempt. The receive is
> silently dropped from history.

The current test would not detect a regression that re-introduces the gate
only for that specific path.

### Why it's hard to test from outside

Two ways to reproduce the active-session window:

1. **Set up a stale session in Bob's actor** before the receive arrives.
   Requires either a deliberately-aborted boarding attempt (which itself
   depends on TODO #1's deadlock not being fully fixed) or an internal RPC
   to install a session state directly. No such hook exists.

2. **Have Bob actively in `settle()` while a third party sends to him.**
   Inherently racy — the test would need to time the third-party send to
   land between Phase 1 of Bob's settle (which sets `settle_session`) and
   Phase 2 (which clears it). That window is hundreds of milliseconds in
   the happy path, but flaky in CI.

Neither is easy to exercise reliably from the existing black-box test
surfaces.

### What proper coverage would require

A test-only hook in the runtime — e.g., a debug RPC that lets the harness
write `state.settle_session = Some(dummy)` directly, or a feature-flag that
lets the test pause an in-flight settle between Phase 1 and the stream
notification.

Both are non-trivial: they widen the public API of the runtime for testing,
and any such hook needs to be gated so it can't be called in production.

### Acceptable for now

The current assertions catch the common case. Anyone re-introducing the gate
to "fix" a perceived double-counting issue would break the standard send-flow
test. The narrower active-session path remains an unexercised slice of the
state machine.
