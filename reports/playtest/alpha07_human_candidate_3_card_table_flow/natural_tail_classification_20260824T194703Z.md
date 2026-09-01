# Candidate 3 natural-tail classification

This append-only note keeps the production match result separate from the
inherited track-authority proof.

The real production seed `900626424` was accepted and naturally reached
`settled` at batch 4 (`progress=43`, `target=8`, `ai_public=3`,
`scroll=3`, `capacity=40`). That is a normal Victory termination, so the
same production match did not expose a further post-Victory tail.

The inherited `V074_UNIFIED_TRACK_VISIBLE_CAPACITY_10_TEST` passed `32/32` and
continues to prove the tail semantics: buying creates a vacancy, does not
immediately refill or slide a card in, the vacancy moves with the authoritative
track, the capacity is restored at the natural tail, and purchase does not
advance the supply cursor or RNG. The two evidence classes are intentionally
not conflated.
