# P0 AI business-action transaction boundary handoff

Date: 2026-07-22
Base: `ff8fd4008cef25110d42237b0078afe057ccb052`
Branch: `codex/p0-ai-business-action-transaction-ff8fd40`

## Result

The existing AI `price_pump` effect now has a narrow prepare/commit/rollback/finalize participant on the authoritative `ProductMarketRuntimeController`. It plans the existing action roll and complete market refresh with detached `RunRngService` cursors, binds the plan to market plus supply/demand/disruption/weather facts, restores market and RNG on cash rejection, and defers telemetry/public projection until a token-bound, non-reentrant finalization.

This is a prerequisite only. It deliberately does not wire AI, cash, Coordinator or Main. `P0-AI-BUSINESS-COST-TYPED-CASH-CUTOVER` must consume these APIs and remove the old Main path in its own atomic change.

## Public APIs

- `ai_business_market_pressure_authority_snapshot()`
- `prepare_ai_business_market_pressure(request)`
- `commit_ai_business_market_pressure(prepared)`
- `rollback_ai_business_market_pressure(receipt)`
- `finalize_ai_business_market_pressure(receipt)`
- `ai_business_market_pressure_save_preflight()`
- `ai_business_market_pressure_debug_snapshot()` (developer-only)

## Ownership and boundaries

- Market owner: unchanged, `ProductMarketRuntimeController`.
- RNG owner: unchanged, `RunRngService`.
- Cash/commitment owner: not added or modified.
- Save owner/schema: not added or modified.
- Main/Coordinator/AI/UI: zero modifications.
- `route_sabotage`: fail closed as `ai_business_route_sabotage_not_owned`.
- Journal: bounded to 256, session-scoped, non-persistent.
- Terminal journal records are compacted and retain no market preimage, RNG cursor or telemetry batch.
- The lifecycle is synchronous and publishes no observer signal before cash success.
- Participant save/checkpoint restore fails closed while rollback is open; global save-coordinator integration remains a later boundary.
- Public receipt: strict pure-data allowlist; privacy scan passed.

## Evidence

- Focused boundary test: `68/68 PASS`.
- Product-market owner fixture: `15/15 PASS`.
- Player cash mutation port: `39/39 PASS`.
- Run RNG service cutover: `21 checks PASS`.
- Weather telemetry unit service: `90/90 PASS`.
- Main runtime composition: `PASS`.
- Main architecture gate: `209 checks PASS`.
- Smoke `--check-only`: exit `0`.
- Godot 4.7 MCP production-composition Bench: `68/68 PASS`; no new script warning or runtime error from changed files.

The existing `WeatherEconomyV1Bench` remains red before a useful ordinary-refresh comparison: its real weather controller is not ready/forecast is not scheduled, cascading to 32 failures and an inherited empty-array access. The focused weather telemetry service remains 90/90 and the product-market owner fixture remains 15/15. This change does not restore the retired Main formula bridge merely to satisfy that stale Bench.

## Integration sequence

1. AI cash cutover freezes the action target, source revision, authorized public region and expected market fingerprint.
2. Prepare the market participant.
3. Commit the participant; telemetry is still buffered.
4. Submit the typed, commitment-aware cash debit.
5. Cash failure: rollback the participant, then return one rejected action receipt.
6. Cash success: finalize the participant, then publish existing AI decision/public feedback exactly once.

Steps 2–6 must run in the same call stack with no `await` or `call_deferred`. The participant journal is not a crash-recovery or replay-save system.

The integration must not call the existing direct `apply_external_pressure` path in addition to this participant.
