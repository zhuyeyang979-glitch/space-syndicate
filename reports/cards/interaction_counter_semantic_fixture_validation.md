# Interaction And Counter Semantic Fixture Validation

## Scope

- Worktree: `C:/Users/zhuye/AppData/Local/Temp/space-syndicate-codex/card-semantic-wave2-h-a96c34f`
- Branch: `codex/card-semantic-wave2-h-interaction-fixtures-a96c34f`
- Baseline: `a96c34f9d1a9f79fc20c4689b8d2ff82e22c623e`
- Owned fixture: `tests/fixtures/card_semantic_phase1/interaction_counter_golden.json`
- Production changes: none

The fixture is a read-only expected projection for the three v0.6 interaction
families. It does not add a compiler, executor, legality owner, AI scorer,
response window, save section, or gameplay mutation.

## Authority

The expected records follow `docs/cards/card_semantic_phase1_frozen_contract.md`.
Exact card identity, acquisition cost, seven-key activation cost, effect kind,
target kind, and payload values come from the `machine` blocks in
`data/cards/card_runtime_catalog_v06.json`. No localized player text or card
name was parsed to recover a rule.

The source catalog identity is
`space_syndicate.card_runtime_catalog.v06`; its baseline SHA-256 is
`b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40`.
The twelve source records begin at catalog lines 24582-25399.

## Golden Matrix

| Family | Rank values locked by the fixture | Ordered normalized ops | Timing and response |
| --- | --- | --- | --- |
| `interaction.starlink_dismantle` | purchase `5/8/12/17`; technology activation `2/3/5/8`; discard `1/1/1/2`; lock `0/10/18/20s`; target cash penalty `0/0/80/120` | `discard_random`; append `lock_random` only for ranks II-IV | `main_action`; direct `player.opponent`; `counterable`, 5 seconds, maximum depth 1 |
| `interaction.shadow_warehouse_traction` | purchase `5/8/12/17`; technology activation `2/3/5/8`; steal `1/1/1/2`; lock `0/8/15/18s`; failure cash `60/90/140/220` | `steal_random`; append `lock_random` only for ranks II-IV | `main_action`; direct `player.opponent`; `counterable`, 5 seconds, maximum depth 1 |
| `interaction.phase_veto` | purchase `5/8/12/17`; technology activation `2/3/5/8`; strength `1/2/3/4`; refund `0/40/90/160`; private trace `0/0/1/2`; authored depth `1`; window `5.0s` | exactly one `counter_action` | `response_window`; `response.incoming_direct_interaction`; response kind `counter`; opens no additional response window |

Array order is semantic. Rank-I disrupt and steal records intentionally omit a
`lock_random` op because the authored lock duration is zero. Positive lock
durations always produce the second op after discard or steal. The counter
records retain every authored numeric payload value while asserting that a
counter cannot itself be countered. A fixture-level response timing contract
locks the one authorized layer to five seconds and depth one while keeping the
closed `CardResponseSpec` itself to its schema-owned `response_id`.

Each expected semantic keeps acquisition and activation cost separate. The
fixture stores source-facing `catalog_values` beside each normalized
`expected_semantic` so a future compiler gate can distinguish catalog drift
from normalization drift. Fingerprint literals are intentionally not guessed:
the schema/compiler gate must compute and check the two canonical SHA-256
fields after its final closed shape is available.

## Privacy Fixture

Two adversarial cases inject unique sentinels for an affected secret card
name, a hidden hand, and an owner identity. Their expected public result and
AI target projection contain only aggregate operation counts and one stable
public target reference:

- direct interaction: `player.public.seat_2` plus removed, transferred, and
  locked counts;
- counter: `card_resolution.public.42` plus the countered count.

Both cases list recursive forbidden keys and forbidden sentinel values. A
validator must scan both the public result and the entire assembled AI
candidate and prove that none survive. The expected target-state projection
enumerates the only authorized target-derived values: aggregate counts and a
stable public target ref. The source card ID and actor-owned source slot remain
separate authorized candidate fields under the frozen contract; no affected
rival card identity, rival hand, or hidden owner is authorized.

Because the layered v0.6 interaction route is unavailable, both privacy
candidate examples are explicitly illegal with
`v06_card_effect_route_unavailable`. The fixture does not turn semantic
recognition into executable AI legality.

## Runtime Readiness

All twelve records use `runtime_readiness_id=projection_only`.

This is deliberate. The catalog says
`catalog_ready_runtime_wiring_pending` for all twelve records. The current
state audit records `player_hand_disrupt`, `player_hand_steal`, and
`card_counter` as v0.6 production fallthroughs, and
`GameRuntimeCoordinator.v06_runtime_card_route()` returns
`unsupported_v06_card_runtime` / `v06_card_effect_route_unavailable` for these
kinds. The direct-interaction families also remain
`legacy_effect_review_pending`; phase veto is `rule_confirmed`, but its catalog
route is still unwired. Existing v0.4 services and benches are evidence for
ordering, privacy, and response boundaries, not evidence that these v0.6
definitions are executable.

## Godot MCP Evidence

- Role/endpoint: Role A, `127.0.0.1:8915`
- Godot: `4.7-stable (official)`
- Endpoint identity: exact assigned worktree above
- Edited scene inspected: `res://scenes/tools/AnonymousInteractionRuntimeV06Bench.tscn`
- Real owner scenes inspected: `res://scenes/runtime/PlayerHandInteractionRuntimeService.tscn` and `res://scenes/runtime/CardCounterSettlementRuntimeService.tscn`
- Catalog inspected through Godot: the v0.6 Resource declaration and its JSON source; an MCP `execute_code` query parsed 348 records and returned the exact 12 interaction machine blocks
- Runtime result: `PASS`, metadata exit code `0`; runtime log reports `checks=8`, `failures=0`, `public_leaks=0`, and zero runtime script-error lines
- Play stop: successful; `is_playing_scene=false`
- Editor stop: clean normal close; PID 11512 exited and port 8915 was no longer listening

The editor-wide import log also contained pre-existing parse/load errors in
three unrelated test files and three placeholder-instance errors from an
initial attempt to invoke the non-`@tool` catalog Resource in editor context.
Catalog inspection was repeated successfully with Godot `FileAccess` and
`JSON`; the target play-mode runtime log was clean. No source file was changed
to hide either condition.

## Validation Gates

The owned-file checks require:

1. PowerShell `ConvertFrom-Json` parses the fixture and finds exactly 12 unique
   card IDs, three complete rank ladders, and two privacy cases.
2. Every `catalog_values` identity, cost, effect kind, target kind, payload,
   availability flag, and developer status matches the baseline catalog.
3. Disrupt/steal op zero contains the matching random operation; a lock op is
   absent at zero seconds and present exactly once after it at positive seconds.
4. Direct interactions are five-second, depth-one `counterable` records;
   phase veto is a response-window `counter` with no further layer.
5. Public result and AI target projection recursively exclude all forbidden
   keys and sentinel values.
6. Git diff contains only the two assigned files; no Godot-generated UID is
   committed.

Result: `PASS`. Structured PowerShell validation parsed the JSON, found 12
unique cards, three complete I-IV ladders, two privacy cases, the expected
catalog SHA-256, and zero catalog/semantic/privacy parity errors. `git diff
--cached --check` passed with exactly the two owned files staged. The Godot
4.7 scan produced the known 19 unrelated untracked UIDs; the reviewed dry-run
confirmed that every one belonged to a tracked pre-existing script, all 19
were removed, and the remaining untracked UID count was zero.

## Residual Risks

- This wave owns fixture data only. Executable comparison against the final
  GDScript schema/compiler belongs to the integration wave.
- The fixture is aligned with the concurrent Wave-2 closed GDScript field
  tables. Integration must still compute canonical fingerprint literals and
  verify that the compiler emits `projection_only`, not `active`, for these
  currently unwired v0.6 routes.
- `private_trace_count` is preserved as authored counter data but remains an
  unconsumed field in the current-state audit. Projection must not be mistaken
  for a live private-intel grant.
