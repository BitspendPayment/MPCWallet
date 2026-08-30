# Solving Ark's Liveness Problem with Threshold Cosigning

## What I'm Working On

I've been building out an MPC wallet specifically designed to address what I
see as the biggest UX blocker in the Ark protocol — the **interactivity
requirement during Batch Swap rounds**.

This is still a work in progress, but the core primitives are in place and I
wanted to share where things stand and get your feedback on the direction.

## The Problem

Ark scales Bitcoin by batching user payments into **Batch Outputs** — single
on-chain UTXOs partitioned into multiple **Virtual Transaction Outputs
(VTXOs)**. Each Batch Output is an n-of-n multisig between all VTXO owners
and the **Ark Operator (ASP)**, with two spend paths:

- **Collaborative path**: VTXO owner + Operator co-signature
- **Unilateral exit path**: owner-only withdrawal after a CSV timelock

The problem is that every Batch Output has an **expiry timestamp**. Before it
expires, each VTXO owner must either:

1. Participate in a new **Batch Swap** round — atomically rolling their VTXO
   into a fresh Batch Output, or
2. Perform a **unilateral on-chain withdrawal**

**If the user does neither, the Ark Operator reclaims the Batch Output to
recover their fronted liquidity.** The user's VTXO gets swept.

This means users **must be online and interactive** at regular intervals. For
a consumer wallet — where someone might not open the app for weeks — that's a
fundamental problem. It effectively limits Ark to power users who are
actively managing their VTXOs.

## The Approach

The idea behind this wallet is straightforward: **what if a cosigner could
handle the Batch Swap on the user's behalf while they're offline?**

I'm building a **FROST (Flexible Round-Optimized Schnorr Threshold
Signatures)** based wallet with a 2-of-2 threshold split between the user's
device and a **cosigner running inside a secure enclave**. Both shares are
required to produce a valid BIP-340 Schnorr signature — neither party can sign
alone.

When a VTXO approaches expiry, the cosigner — which is always online — would:

1. Detect the approaching expiry window
2. Enter the Batch Swap round with the ASP on behalf of the user
3. Co-sign the **forfeit transaction** releasing the old VTXO using its FROST
   share
4. Receive the refreshed VTXO in the new Batch Output

The user's funds roll forward. No app open. No interaction. No swept VTXOs.

## Why This Isn't Custodial

This is the thing I keep coming back to — the cosigner **cannot unilaterally
move funds**. It holds one share of a 2-of-2 threshold key. Spending requires
both shares. The security model breaks down like this:

| Scenario | Outcome |
|---|---|
| User online, cosigner online | Normal collaborative signing — payments, batch swaps |
| User offline, cosigner online | Cosigner refreshes VTXOs autonomously — funds safe |
| User online, cosigner **temporarily** offline | On-chain layer keeps working (wallet-alone, offline mode); Ark operations wait |
| Cosigner **permanently** gone | ⚠️ Ark balances are stranded today — see below |

**The honest caveat.** Ark's unilateral exit does not currently rescue this
wallet. The stock VTXO taptree keys *both* the cooperative leaf and the exit
leaf to the same owner — here the 2-of-2 group key — so the CSV timelock
governs *when* you may exit, not *who* may exit. With the cosigner gone the
phone holds one of two required shares and cannot sign either path. The
on-chain single-key layer is unaffected and remains fully self-custodial.

The fix is a third taptree leaf spendable by a recovery key the phone already
holds, after a long delay. It is designed, not yet implemented, and the
mechanism plus its costs are written up in
[README.md → Emergency exit](README.md#emergency-exit). We would rather state
this plainly than let a reviewer discover it.

The cosigner runs as a **native per-user actor** — each user gets a dedicated
task owning its own keys and state, with serial command processing and no
shared mutable state.

## Where Things Stand

The cryptographic foundation is working. Here's what's built so far:

**Done:**
- FROST 2-of-2 DKG (3-round key generation) and threshold signing
- Native per-user actor isolation in the cosigner runtime
- Authenticated gRPC transport with Schnorr-signed requests and replay
  protection
- Taproot key tweaking and BIP-340 signature support

**Still working on:**
- Ark taproot primitives — BIP-341 compliant VTXO taptree construction with
  forfeit leaf + CSV exit leaf
- Forfeit and exit spend info derivation (scripts + control blocks)
- P2TR script pubkey derivation using NUMS internal key
- Cosigner Ark bindings — exposing VTXO operations through the WIT interface
- Batch Swap protocol handler — the service that monitors VTXO expiry
  timelines and initiates refresh rounds with the ASP
- Cosigner policy scoping — constraining autonomous signing to VTXO refresh
  only, never outbound transfers without the client
- ASP integration layer — communication with the Ark Operator for round
  participation and VTXO state sync
- Client-side notifications when a refresh is performed on the user's behalf

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   User's Device                       │
│                                                       │
│  ┌─────────────┐    ┌──────────────────────────────┐ │
│  │ Client App  │    │  FROST Key Share (client)     │ │
│  │ (Dart)      │───►│  Signs when user is active    │ │
│  └─────────────┘    └──────────────────────────────┘ │
└──────────────────────────┬───────────────────────────┘
                           │ gRPC (authenticated)
                           ▼
┌──────────────────────────────────────────────────────┐
│              Server (Secure Enclave)                  │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │      Native actor (per-user instance)           │  │
│  │                                                  │  │
│  │  ┌──────────────────────────────────────────┐   │  │
│  │  │  Cosigner (FROST Key Share)               │   │  │
│  │  │  - Produces signature shares              │   │  │
│  │  │  - Derives VTXO script pubkeys            │   │  │
│  │  │  - Computes forfeit/exit spend info       │   │  │
│  │  │  - Participates in Batch Swap rounds      │   │  │
│  │  └──────────────────────────────────────────┘   │  │
│  └────────────────────────────────────────────────┘  │
│                         │                             │
│                         ▼                             │
│              ┌─────────────────────┐                 │
│              │   Ark Operator /    │                 │
│              │   ASP Interface     │                 │
│              └─────────────────────┘                 │
└──────────────────────────────────────────────────────┘
```

## What I'd Like Feedback On

1. **Trust model** — Are we comfortable with the cosigner having scoped
   authority to refresh VTXOs autonomously? The policy engine would strictly
   limit it to refresh-only signing, but I want to make sure the trust
   assumptions sit right.

2. **Priority** — The Ark liveness problem is well-known but no one seems to
   be solving it at the wallet layer. As far as I can tell, every existing
   approach either accepts the interactivity burden or falls back to full
   custody. Is this worth prioritizing?

3. **Scope** — The remaining work (ASP integration, policy scoping, batch
   swap handler) is non-trivial but bounded. Happy to put together a more
   detailed roadmap if this direction makes sense.

Would love your thoughts.
