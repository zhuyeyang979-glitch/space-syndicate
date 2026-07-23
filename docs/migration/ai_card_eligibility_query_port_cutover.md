# AI Card Eligibility Query Port Cutover

## Boundary

This atomic boundary removes AI card eligibility, requirement, rejection-log,
and best-GDP-share decisions from the generic Main method-name bridge. It does
not claim the parent P0 AI world typed-port program is complete.

Base commit: `91d7d3f12f5a93ee06a263ce24aab420a3feb3a9`.

## Query contract

`AiCardEligibilityQueryPort` is a scene-owned, stateless actor-private query.
It composes the existing `CardPlayEligibilityWorldBridge`, authoritative
`CardPlayEligibilityRuntimeService`, `CommodityFlowRuntimeController`, and the
read-only `PlayerManaRuntimeController` projection. The Port owns no card,
world, Mana, wager, session, RNG, journal, or save state.

Every request requires an opaque `AiCardEligibilityCapability` issued for one
current AI seat. Human, rival, forged, stale-roster, and stale-session tokens
fail before world facts or eligibility rules are read. A `GameSession` identity
change causes the composition root to reissue all actor capabilities. This
covers the formal new-session and session-envelope order where World state is
applied before the final GameSession commit, and rollback reissues capabilities
for the restored identity.

The capability binding includes only stable session identity fields, not save
operation sequence, pause state, or outcome state. Ordinary save operations
therefore cannot accidentally invalidate an otherwise current AI capability.

## Privacy and mutation

The Port returns detached actor-scoped receipts only. Raw players, districts,
queue entries, owner facts, share tables, Nodes, Objects, and Callables are not
returned. Explicit `selected_district` is always passed to the shared fact
provider, including `-1`; AI never falls back to human `TableSelectionState`.

Card spending uses `MonsterWagerCashCommitmentQueryPort` through the existing
eligibility fact provider. An AI with sufficient total cash but insufficient
cash after an unresolved wager is rejected. The query leaves WorldSession,
GameSession, card queues, CommodityFlow, PlayerMana, Monster wager state,
TableSelection, and RunRng checkpoints unchanged.

## Behavior parity

The retired Main best-share helper selected by:

1. highest player GDP share;
2. highest public region GDP/min when shares tie;
3. earliest district index when both values tie.

The typed query preserves all three levels. Card eligibility remains decided by
the shared runtime service and uses the same wager-aware cash authority as human
card play.

## Removed AI routes

- `_call_world("_best_player_gdp_share_district")`
- `_call_world("_card_play_requirement_snapshot")`
- `_call_world("_card_play_eligibility_snapshot")`
- `_call_world("_log_card_play_rejection")`
- `Main._best_player_gdp_share_district`

Shared Main card eligibility helpers used by human presentation remain outside
this atomic boundary.

## Evidence

- Godot 4.7 MCP found exactly one `AiCardEligibilityQueryPort` instance in the
  real `GameRuntimeCoordinator.tscn` and opened the real `main.tscn`.
- Focused query test: 31 checks PASS, zero runtime errors.
- AI phase/counter, hand, queue, execution, stable target, counter window,
  composition, and Main architecture gates: PASS.
- Session-start transaction: PASS.
- Session envelope cold restore: 93/93 PASS.
- Main budget: PASS, 6,373 physical lines, 468 methods, 102 external
  caller files. No field, constant, or preload was added to Main.
- `CardPlayEligibilityRuntimeBench`: 41/44, exactly the inherited
  `city_development_invalid`, `city_development_valid`, and
  `ai_ui_coach_execution_parity` fixtures.
- `git diff --check`: PASS.

## Remaining P0 scope

Generic card phase properties, product-flow and card-price helpers, Monster and
Military calls, weather/victory boundaries, presentation helpers, Main-to-AI
dispatch, and the generic `AiRuntimeWorldBridge` remain. The full P0 status and
full-run resume claim remain false.
