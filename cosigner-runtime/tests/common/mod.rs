//! Shared setup for the integration tests. Builds `SharedServices` against the local dev stack.
//!
//! Redis is required (persistence backend); the ASP channel is created lazily, so a reachable
//! arkd is NOT needed for paths that never issue an ASP RPC (FROST signing, policy seal, DKG
//! onboarding bookkeeping). `try_shared` returns `None` — with a skip notice — only when Redis
//! is unreachable, so these tests skip cleanly when run off-stack.

use std::sync::Arc;

use cosigner_runtime::auth::session::SessionAuthority;
use cosigner_runtime::resp_store::RespStore;
use cosigner_runtime::shared::SharedServices;

pub async fn try_shared() -> Option<Arc<SharedServices>> {
    // Default matches the dev stack in `docker-compose.ark.yml` (`--requirepass testpass`; the
    // username is ignored — connect as the `default` user). Override with `REDIS_URL`.
    let redis_url = std::env::var("REDIS_URL")
        .unwrap_or_else(|_| "redis://:testpass@127.0.0.1:6379".to_string());
    let asp_url = std::env::var("ASP_URL").unwrap_or_else(|_| "http://127.0.0.1:7070".to_string());

    let store = match RespStore::connect(&redis_url).await {
        Ok(s) => Arc::new(s),
        Err(e) => {
            eprintln!("skip: Redis unreachable at {redis_url}: {e:?}");
            return None;
        }
    };
    let asp = match ark::client::AspClient::connect_lazy(&asp_url) {
        Ok(a) => a,
        Err(e) => {
            eprintln!("skip: invalid ASP url {asp_url}: {e:?}");
            return None;
        }
    };
    Some(Arc::new(SharedServices::new(
        store,
        asp,
        None, // fcm
        1800, // auto_settle_safety_margin_secs
        1800, // actor_idle_threshold_secs
        Arc::new(SessionAuthority::from_secret_hex("")),
    )))
}
