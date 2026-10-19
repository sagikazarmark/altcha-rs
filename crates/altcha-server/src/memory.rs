//! A [`ReplayStore`] in memory: for one process, a demo, or tests.

use std::{
    collections::HashMap,
    convert::Infallible,
    future::{self, Future},
    sync::{Mutex, MutexGuard, PoisonError},
};

use crate::ReplayStore;

/// Redeemed nonces in a map, until they expire. Only for one process: with
/// more than one server, use a shared store (a database table).
#[derive(Debug, Default)]
pub struct MemoryStore {
    used: Mutex<HashMap<String, i64>>,
}

impl MemoryStore {
    /// How many nonces it holds.
    #[must_use]
    pub fn len(&self) -> usize {
        self.used().len()
    }

    /// Whether it holds no nonces.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// The map. Every change is a single map operation, so a panic elsewhere
    /// can't leave it inconsistent: a poisoned lock is still usable.
    fn used(&self) -> MutexGuard<'_, HashMap<String, i64>> {
        self.used.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

impl ReplayStore for MemoryStore {
    type Error = Infallible;

    fn redeem(
        &self,
        nonce: &str,
        expires_at: i64,
    ) -> impl Future<Output = Result<bool, Infallible>> {
        let mut used = self.used();
        let fresh = !used.contains_key(nonce);
        if fresh {
            used.insert(nonce.to_owned(), expires_at);
        }

        future::ready(Ok(fresh))
    }

    fn forget_expired(&self, now: i64) -> impl Future<Output = Result<(), Infallible>> {
        self.used().retain(|_, expires_at| *expires_at >= now);

        future::ready(Ok(()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn once_until_forgotten() {
        let store = MemoryStore::default();
        assert!(store.redeem("a", 10).await.unwrap());
        assert!(!store.redeem("a", 10).await.unwrap());
        assert!(store.redeem("b", 20).await.unwrap());
        store.forget_expired(11).await.unwrap();
        assert_eq!(store.len(), 1, "a expired before 11");
        assert!(!store.redeem("b", 20).await.unwrap());
    }
}
