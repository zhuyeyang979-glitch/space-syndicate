# AI Public Player Facts Typed-Port Migration

## Status

`STATUS=AI_PUBLIC_PLAYER_FACTS_TYPED_PORT_MIGRATION_COMMITTED_CANDIDATE`

This evidence is frozen as the commit-ready record for the next local commit. Its declared delivery state is `committed=true`, `pushed=false`, and `merged=false`, which is the intended truth immediately after that commit. The parent `P0-AI-WORLD-TYPED-PORTS-CUTOVER` remains active. This document does not claim a complete match, parent-P0 completion, Alpha 0.3 completion, full-run resume, push, or merge.

## Rule Authority

- `RULE_AUTHORITY_GATE=GREEN`
- Parent mechanic: `ai_runtime_world_interaction`, status `ACTIVE`.
- Mechanic: `ai_public_player_facts_typed_port_migration`, status `MIGRATION_ONLY`.
- Semantic owner: `AiRuntimeController`.
- Public identity owner: `WorldSessionState`.
- Session identity owner: `GameSessionRuntimeController`.
- Role definition owner: `RoleCatalogRuntimeService`.
- New gameplay owner: none.
- New query port: none; the existing `AiActorStatePort` is reused.
- Persistence: none; no Save field, section, or Registry change.

## Public Row Schema 1

Every accepted row contains exactly:

1. `schema_version`
2. `session_id`
3. `session_revision`
4. `source_revision`
5. `fingerprint`
6. `visibility_scope`
7. `player_index`
8. `public_seat_order`
9. `public_player_name`
10. `seat_type`
11. `is_ai`
12. `role_index`
13. `role_name`
14. `eliminated`

`visibility_scope` is always `public`. The row excludes raw `id`, mutable source dictionaries, cash, cash cents, slots, discard, warehouse, futures, AI profile, AI memory, decision samples, city inference, hidden Owner fields, `eliminated_at`, `elimination_reason`, Nodes, Objects, and Callables. WorldSession and actor-private fixtures may retain elimination timing and reason, but the public projection authorizes only the `eliminated` flag.

The entire roster fails closed when any source row is non-Dictionary, has an index mismatch or duplicate identity, has a missing or invalid public name, has inconsistent `seat_type/is_ai`, has an invalid role index, disagrees with the role catalog, or has a malformed `eliminated` flag. Partial public rosters are never returned.

The fingerprint binds the canonical public roster and current session identity. The source revision additionally binds the WorldSession restore generation. Therefore identical authoritative public state produces the same fingerprint, a new session changes the fingerprint, and an exact restore rotates source revision so a pre-restore row is stale.

## Query APIs

`AiActorStatePort` now provides:

- `public_player_count()`
- `human_player_count(include_eliminated)`
- `ai_player_count(include_eliminated)`
- `public_players_snapshot()`
- `public_player_snapshot(player_index)`
- `is_current_public_player_snapshot(snapshot)`
- `public_player_name(player_index)`
- `public_target_label(player_index)`
- `public_role_definition(player_index)`
- `public_active_target_rows(actor_index)`
- `active_target_player_indices(actor_index)`

Public query methods do not increment counters or mutate the port, WorldSession, RNG, logs, or save-dirty state. Results are detached pure data in stable seat order.

The private actor capability is one-shot. `GameRuntimeCoordinator._enter_tree()` creates and prebinds the single production capability before any child `_enter_tree()` or `_ready()` callback can run. Normal `_wire_ai_world_typed_ports()` wiring only reuses that instance idempotently. Binding the same object again succeeds without changing capability revision; a null, early hostile, or different capability is rejected and cannot replace the production capability.

## Consumer Cutover

AI public count and bounds checks now use the typed public-player count. Human and total/active AI count semantics are unchanged. The build order still starts from all AI seats, including eliminated seats, and performs one `randi_range` draw per seat.

Public role lookup now uses the validated role index and `RoleCatalogRuntimeService.public_definition_at()`. Public labels use the typed roster but preserve the exact `玩家N/未知玩家` display behavior; public custom names remain a separate fact.

Direct-player target enumeration now uses `public_active_target_rows()`, preserving seat order while excluding self and eliminated players. Immediately before `AiRuntimeController` calls `CardPlaySubmissionRuntimeController.submit_card_play()`, any nonnegative `target_player` is re-read from the current typed public row and rejected when absent, self, or eliminated. A plan whose target is eliminated after planning produces zero CardPlay submissions; CardResolutionExecution and CardTargetChoice remain unchanged and still own later rule validation. Own hand receive pressure remains an explicitly deferred actor-private helper.

The old direct-player score read rival Victory-private candidates, hidden city owners, and hidden monster owners. The migrated score reads an existing public Victory audit row only when formally present. Unknown rival Victory values and hidden city/monster pressure contribute zero. This is a required privacy correction, not a personality or difficulty redesign.

## Main Reduction

Removed only the frozen public-player set:

- `MIN_PLAYER_COUNT`
- `MAX_PLAYER_COUNT`
- their AI constant snapshot entries
- `_player_is_ai`
- `_human_player_count`
- `_interaction_target_label`

`_player_name`, `_player_is_eliminated`, and deferred generic bridge paths remain because other production domains still use them.

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Physical lines | 6461 | 6440 | -21 |
| Nonblank lines | 5436 | 5421 | -15 |
| Methods | 473 | 470 | -3 |
| Constants | 47 | 45 | -2 |
| Fields | 46 | 46 | 0 |
| Preloads | 7 | 7 | 0 |
| External caller files | 103 | 103 | 0 |

The architecture budget still reports the inherited absolute threshold `103 > 102`; this slice adds no caller. Production reference files remain unchanged.

## Independent QA Evidence

- Focused public-player migration: `128/128 PASS`.
  - Run ID: `20260724-131156-800-ai_public_player_facts_typed_port_migration_test-4b01d587`.
  - Marker: `AI_PUBLIC_PLAYER_FACTS_TYPED_PORT_MIGRATION_COMPLETE`.
- Production MCP Bench: `31/31 PASS`.
  - Marker: `AI_PUBLIC_PLAYER_FACTS_TYPED_PORT_MIGRATION_BENCH|status=PASS|checks=31|privacy_leaks=0|main_routes=0|hostile_early_bind_accepts=0|elimination_detail_leaks=0|invalid_target_submission_delta=0|pre_submit_rejections=1`.
- Hostile early-bind accepts: `0`.
- Public elimination-detail leaks: `0`.
- Invalid-target CardPlay submission delta: `0`.
- Actor-state focused regression: `93/93 PASS`.
  - Run ID: `20260724-131325-192-ai_actor_state_typed_port_migration_test-3273722d`.
- Actor-state production Bench: `37/37 PASS`.
- City-inference focused regression: `48/48 PASS`.
  - Run ID: `20260724-131336-073-ai_city_inference_typed_ports_cutover_test-9489354d`.
- City-inference production Bench: `14/14 PASS`.
- Typed-world focused boundary: `83/83 PASS`.
  - Run ID: `20260724-131416-947-typed_world_ports_boundary_test-2bddc8ee`.
- AI business architecture: `37/37 PASS`.
- AI typed-cash: `72/72 PASS`.
- Formal AI cash product path: `28/28 PASS`, fixed seed `20260722`.
- Setup session-start transaction: `133/133 PASS`.
- WorldSession: `44/44 PASS`.
- Save Registry: `12/12 PASS`.
- Envelope runtime: `60/60 PASS`.
- Main architecture: `217/217 PASS`.
- Main composition: `PASS`.
- Smoke `--check-only`: `PASS`.
- `git diff --check`: `PASS`.
- MCP script diagnostics: `0`; test script errors: `0`; residual runtime processes: `0`.
- The headed MCP editor may still report environment-only shader-cache directory errors and pre-existing NUL decoding notices. They are outside the migrated product path and do not change the zero product-console-error evidence below.

## Formal Main Scene Product Path

The independent product run entered `res://scenes/main.tscn` rather than a synthetic fixture.

- The setup page showed 4 seats: 1 human and 3 AI.
- Challenge depth displayed `I`, and all four displayed roles were unique.
- Start succeeded with `session_state=running`.
- The setup menu closed and the live table became visible.
- World generation produced 8 districts.
- `game_time` advanced after start.
- The RuntimeLoop path was active and emitted the full expected phase trace.
- The typed actor capability remained at revision `1`.
- The runtime hostile-bind rejection counter remained `0`; this product run injected no hostile probe.
- Product-console error count was `0`.
- Play mode stopped cleanly after validation.

The interactive setup UI has no seed control, so this run does not claim a fixed interactive seed. Deterministic RNG behavior is covered separately by focused seed `98765` and formal AI cash seed `20260722`.

## Inherited Debt

- `TypedWorldPortsBoundaryBench` is `7/8` on both this candidate and exact `origin/main`. Its only red item is the stale "six coordinators" oracle, so it is inherited test debt rather than a task regression. The focused typed-world boundary remains `83/83 PASS`.
- The Main budget checker still reports inherited `103 > 102`. This task added no production caller, so task delta is `0`.

## Remaining Parent Work

The AI controller still has 42 `_call_world` references, 27 `players` tokens, and 95 `districts` tokens. Actor-private economy and hand, public market and routes, card command and post-submission rule ownership, monster, military, weather, and the complete Victory boundary remain separate atomic migrations. This slice claims only the AI-side current-target pre-submit guard. Save Registry and formal full-run resume were not changed.
