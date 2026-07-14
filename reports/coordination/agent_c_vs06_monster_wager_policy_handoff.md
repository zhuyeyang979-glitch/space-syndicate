# Agent C VS06-C13 — Monster Wager Pure Policy Handoff

## Outcome

Frozen at focused evidence. Added a standalone schema-v1 settlement policy without modifying MonsterRuntimeController, its bridge, the current wager/cash/public-pool owners, Coordinator, AI, UI, or rules resources.

## Files and API

- `scripts/runtime/monster_wager_settlement_policy_v06.gd`
- `tests/monster_wager_settlement_policy_v06_test.gd`
- `docs/monster_wager_settlement_v06_contract.md`
- `reports/coordination/agent_c_vs06_monster_wager_policy_handoff.md`

Stable calls:

- `fingerprint_for_snapshot(snapshot) -> String`
- `settle(snapshot) -> {ok, reason_code, schema_version, wager_id, revision, fingerprint, private_delta_receipt, public_receipt}`

Future production connection must use `settle(authoritative_snapshot)` as the single policy boundary. The existing owner supplies exact cash, public-pool state, damage and responses, then atomically applies returned cash/public-pool deltas and journals `wager_id + revision + fingerprint`. This module must not receive its own journal, pool, queue, or save owner.

## Focused evidence

- Godot `4.7.stable.official.5b4e0cb0f`, isolated headless profile.
- `MONSTER_WAGER_SETTLEMENT_POLICY_TEST|status=PASS|checks=77|failures=0`.
- Covered: single/multiple/all winners, different stakes with equal remaining bonus, tied maximum sides, zero damage refund, positive damage with no winner, historical pool counted once, integer remainder, 500/1000bp bases, 100bp increments, 2000bp cap, forged rates, small/zero/large cash, overflow fail-closed, least-stake auto-choice, stable side tie-break, canonical replay/fingerprint, schema failure, and nested public privacy.
- Public leak scan includes exact cash/balance, true/hidden owner truth, and AI private score/plan keys plus exact-cash sentinels: 0 leaks.

No full smoke, MCP, headed run, default `user://`, commit, push, or merge was performed.

## Remaining risk

This is not production evidence. The current owner still needs atomic debit/payout/public-pool application, exact-once journal binding, save/load, checkpoint behavior, window lifecycle, and production public-snapshot routing. In particular, owners must not expose the top-level private fingerprint as player-facing data; only `public_receipt` is sanitized.

## Lessons for other agents

- **Invariant:** history enters once; current stakes enter twice; each winner gets self-stake doubled before an equal per-winner remainder share.
- **Failed approach:** pure equal-split pooling penalized larger winning stakes, while stake-proportional remainder would violate the final rule.
- **Stable API:** `settle(snapshot)` is the sole production calculation boundary; `fingerprint_for_snapshot` only prepares its immutable private binding.
- **Test oracle:** different winning stakes must receive the same `remaining_bonus_share`, with payouts differing only by each stake's self-double; payouts plus public remainder equal the settlement pool.
- **Integration trap:** cash may already be escrowed by the existing owner; it must interpret `stake_cash_delta`, `payout_cash_delta`, and `net_cash_delta` consistently and atomically rather than debit twice.
- **Reusable pattern:** strict allowlisted snapshot, canonical SHA-256 binding, overflow-safe quotient/remainder math, private delta receipt, independently constructed public receipt.
- **Stale evidence:** odds, cancelled raises, pure pool equal-split, stake-proportional remainder, and “no winner” without a rollover branch are superseded.
- **Next dependency:** the existing wager owner must expose one revisioned atomic apply/journal/checkpoint boundary consuming the policy receipt; Agent C will not edit B's Monster files.
