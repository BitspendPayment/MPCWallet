//! Runs the rebalancer against a cosigner.
//!
//! This wires the pieces together and drives them on a tick. The interesting logic is in
//! `rebalance::decide`, which is pure and unit-tested; this file is the part that talks to the
//! world. It ships with a paper venue and a mock price by default — a real deployment supplies a
//! `HedgeVenue` adapter and a `PriceSource` and does not change anything here.

use std::sync::Arc;
use std::time::Duration;

use rebalancer::funding::{FundingSource, UnimplementedFunding};
use rebalancer::price::{fmt_cents, MockPriceSource, PriceSource};
use rebalancer::rebalance::{decide, FundingAction, Policy, Portfolio};
use rebalancer::venue::{HedgeVenue, PaperVenue};
use service_sdk::service::{Service, ServiceCtx};
use service_sdk::{
    enrollment_router, CosignerClient, EnrollmentInbox, EnrollmentState, FileShareStore,
    ServiceIdentity,
};

struct Rebalancer<V: HedgeVenue, P: PriceSource, F: FundingSource> {
    venue: V,
    price: P,
    funding: F,
    policy: Policy,
}

impl<V, P, F> Service for Rebalancer<V, P, F>
where
    V: HedgeVenue + Send,
    P: PriceSource + Send,
    F: FundingSource + Send,
{
    fn name(&self) -> &str {
        "rebalancer"
    }

    async fn on_tick(&mut self, ctx: &ServiceCtx) -> service_sdk::Result<()> {
        // Evaluating every tick is the point; ACTING every tick is not. `decide` applies the
        // deadbands that keep an Ark round cadence from turning into a trading cadence.
        let Ok(price_cents_per_btc) = self.price.price_cents_per_btc() else {
            tracing::warn!("no price this tick; holding");
            return Ok(());
        };

        // TODO: read the real balances through the SDK's Ark wrappers. Until a service has a
        // chain view (see `funding`), boarding_sats is necessarily zero here.
        let vtxo_sats = 0;
        let boarding_sats = 0;

        let portfolio = Portfolio {
            vtxo_sats,
            boarding_sats,
            price_cents_per_btc,
            position: self.venue.position(),
            margin_health: self.venue.margin_health(),
            unrealized_pnl_sats: self.venue.unrealized_pnl_sats(),
        };

        let decision = decide(&portfolio, &self.policy);
        tracing::info!(
            reason = decision.reason,
            collateral = %fmt_cents(portfolio.collateral_cents()),
            "rebalance tick"
        );

        if decision.post_margin_sats > 0 {
            self.venue.post_margin(decision.post_margin_sats).map_err(
                |e| service_sdk::Error::Config(format!("post margin: {e}")),
            )?;
        }
        if let Some(delta) = decision.hedge_delta_cents {
            match self.venue.adjust(delta) {
                Ok(()) => tracing::info!(delta = %fmt_cents(delta), "hedge adjusted"),
                Err(e) => tracing::warn!(error = %e, "hedge adjustment refused"),
            }
        }
        match decision.funding {
            Some(FundingAction::BoardSats { sats }) => {
                if let Err(e) = self.funding.spend_boarding_input(sats) {
                    tracing::warn!(error = %e, sats, "cannot add collateral");
                }
            }
            Some(FundingAction::TakeAwaySats { sats }) => {
                if let Err(e) = self.funding.collaborative_exit(sats, "") {
                    tracing::warn!(error = %e, sats, "cannot take value away");
                }
            }
            Some(FundingAction::Underfunded { shortfall_cents }) => {
                tracing::warn!(shortfall = %fmt_cents(shortfall_cents), "underfunded, nothing to board");
            }
            None => {}
        }

        let _ = ctx;
        Ok(())
    }
}

fn env(key: &str) -> Option<String> {
    std::env::var(key).ok().filter(|v| !v.is_empty())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .init();

    let cosigner_url = env("COSIGNER_URL").unwrap_or_else(|| "http://127.0.0.1:7074".into());
    let identity = match env("SERVICE_ID_SECRET_HEX") {
        Some(h) => ServiceIdentity::from_secret_hex(&h)?,
        None => {
            let id = ServiceIdentity::generate()?;
            tracing::warn!(
                service_id = %id.id_hex(),
                "SERVICE_ID_SECRET_HEX unset — generated an ephemeral identity; \
                 any share enrolled against it is lost on restart"
            );
            id
        }
    };
    let store_path =
        env("SHARE_STORE").unwrap_or_else(|| "/tmp/rebalancer-shares.json".to_string());

    let client = CosignerClient::new(&cosigner_url);
    if env("ALLOW_INSECURE_COSIGNER").is_none() {
        client.require_secure_transport()?;
    } else {
        tracing::warn!(%cosigner_url, "insecure cosigner transport explicitly allowed");
    }

    let target_cents: i128 = env("TARGET_USD_CENTS")
        .and_then(|v| v.parse().ok())
        .unwrap_or(0);
    let price_cents = env("MOCK_PRICE_CENTS")
        .and_then(|v| v.parse().ok())
        .unwrap_or(6_500_000);

    tracing::info!(
        service_id = %identity.id_hex(),
        %cosigner_url,
        target = %fmt_cents(target_cents),
        "rebalancer starting with a PAPER venue — no real hedge is placed"
    );

    let service = Rebalancer {
        venue: PaperVenue::new(price_cents),
        price: MockPriceSource::new(price_cents),
        funding: UnimplementedFunding,
        policy: Policy {
            target_cents,
            ..Policy::default()
        },
    };

    let identity = Arc::new(identity);
    let store: Arc<dyn service_sdk::ShareStore> = Arc::new(FileShareStore::new(store_path));

    // The enrolment endpoint the two dealers push to. The allowlist is the one check that carries
    // weight here: a half is believed because the pair sums to the published verifying share, not
    // because of who sent it, so without naming the wallets this service is willing to hold shares
    // for, a stranger could push a self-consistent pairing for a key of their choosing.
    let allowed: Vec<String> = env("ALLOWED_WALLETS")
        .map(|v| {
            v.split([',', ' '])
                .filter(|w| !w.is_empty())
                .map(|w| w.trim().to_ascii_lowercase())
                .collect()
        })
        .unwrap_or_default();
    if allowed.is_empty() {
        tracing::warn!(
            "ALLOWED_WALLETS is unset — the enrolment endpoint will refuse every half. \
             Set it to the wallet group key(s) this service holds shares for."
        );
    }

    let inbox = Arc::new(EnrollmentInbox::new(allowed));
    let router = enrollment_router(EnrollmentState {
        identity: identity.clone(),
        store: store.clone(),
        inbox: inbox.clone(),
    });

    let bind = env("ENROLL_BIND").unwrap_or_else(|| "127.0.0.1:7075".to_string());
    let listener = tokio::net::TcpListener::bind(&bind).await?;
    tracing::info!(%bind, "enrolment endpoint listening on POST /enroll/half");
    tokio::spawn(async move {
        if let Err(e) = axum::serve(listener, router).await {
            tracing::error!(error = %e, "the enrolment endpoint stopped");
        }
    });

    let ctx = ServiceCtx {
        identity,
        client: Arc::new(client),
        store,
    };

    service_sdk::run(service, ctx, Duration::from_secs(60)).await
}
