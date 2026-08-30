//! Where the BTC/USD mark comes from.

use crate::money::Cents;

#[derive(Debug, thiserror::Error)]
pub enum PriceError {
    #[error("no price available: {0}")]
    Unavailable(String),
}

/// A BTC/USD mark, in cents per whole BTC.
///
/// The oracle is an attack surface, not a utility: a rebalancer that believes a manipulated price
/// will hedge to the wrong notional and can be made to trade against itself. A production
/// implementation should aggregate independent sources and reject marks that move further than a
/// sanity bound between ticks.
pub trait PriceSource {
    fn price_cents_per_btc(&self) -> Result<u64, PriceError>;
}

/// A fixed, scriptable price. For tests and dry runs.
#[derive(Debug, Clone)]
pub struct MockPriceSource {
    price: u64,
}

impl MockPriceSource {
    pub fn new(price_cents_per_btc: u64) -> Self {
        Self {
            price: price_cents_per_btc,
        }
    }
    pub fn set(&mut self, price_cents_per_btc: u64) {
        self.price = price_cents_per_btc;
    }
}

impl PriceSource for MockPriceSource {
    fn price_cents_per_btc(&self) -> Result<u64, PriceError> {
        if self.price == 0 {
            return Err(PriceError::Unavailable("mock price is unset".into()));
        }
        Ok(self.price)
    }
}

/// Dollars, formatted from cents, for logs.
pub fn fmt_cents(c: Cents) -> String {
    let sign = if c < 0 { "-" } else { "" };
    let a = c.unsigned_abs();
    format!("{sign}${}.{:02}", a / 100, a % 100)
}
