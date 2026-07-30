# V0.7 Rule Authority And Version Precedence

```text
PRECEDENCE_ID=space_syndicate.v07.rule_precedence.v1
HIGHEST_TARGET_RULE_AUTHORITY=V0.7_COMPLETE_CONSTITUTION
CURRENT_PLAYER_RUNTIME_RULE_AUTHORITY=V0.6_RULEBOOK
TARGET_RULES_DO_NOT_PRETEND_TO_BE_RUNTIME=true
CURRENT_RUNTIME_DOES_NOT_OVERRIDE_TARGET_CONSTITUTION=true
```

## Authority Order

When two sources disagree about a target rule, use this order:

1. The user's latest explicit rule decision.
2. [`v07_game_constitution.json`](v07_game_constitution.json).
3. [`v07_game_constitution.md`](v07_game_constitution.md).
4. The V0.7 summary in [`AGENTS.md`](../../AGENTS.md).
5. [`tabletop_rulebook_v06.md`](../tabletop_rulebook_v06.md), for the current-production V0.6 player runtime only.
6. Older rule and design documents.
7. Older test oracles.
8. Older code behavior.

The JSON constitution is the closed machine-readable authority. The Markdown
constitution explains the same rule IDs for humans. A contradiction between
the two is a contract failure; it is not permission to choose whichever source
is convenient.

## Two Simultaneous Truths

V0.7 is the highest development constitution. New Core, AI, player projection,
privacy, Save/replay, and RNG designs must target it.

V0.6 remains the only current player runtime until an explicit atomic cutover
task passes its production gates. The V0.6 rulebook therefore remains the
authority for what a player can do in the currently shipped prototype.

An old V0.6 test cannot veto a V0.7 target rule. Conversely, this constitution
does not authorize an implementation task to silently change V0.6 production.
The future player rulebook changes to V0.7 only after the production cutover.

## Historical V0.7 Records

The following pre-constitution records remain useful migration evidence but are
not normative when they conflict with `space_syndicate.v07.complete`:

- `docs/rules/shared_partial_visibility_commodity_track_direction.md`
- `docs/rules/shared_partial_visibility_commodity_track_contract.md`
- `docs/rules/shared_partial_visibility_commodity_track_contract.json`
- `docs/rules/shared_partial_visibility_commodity_track_test_vectors.json`
- `docs/migration/shared_partial_visibility_commodity_track_gap_audit.md`
- `docs/migration/shared_partial_visibility_commodity_track_gap_audit.json`
- `docs/migration/shared_partial_visibility_commodity_track_implementation_plan.md`
- `docs/migration/shared_partial_visibility_commodity_track_implementation_plan.json`
- `docs/migration/shared_partial_visibility_commodity_track_three_layer_handoff.md`
- `tests/shared_partial_visibility_commodity_track_three_layer_semantics_test.gd`
- `tests/support/shared_commodity_track_core_semantics_reference.gd`
- `tests/support/shared_commodity_track_semantic_query_source_reference.gd`
- `tests/support/shared_commodity_track_ai_semantics_reference.gd`
- `tests/support/shared_commodity_track_player_semantics_reference.gd`
- `scenes/tools/SharedCommodityTrackThreeLayerSemanticsBench.tscn`
- `docs/migration/v07_global_semantic_action_spine_cutover.md`
- `docs/migration/v07_global_semantic_action_spine_cutover.json`
- `README.md`, where it links the earlier partial V0.7 authority.
- `docs/rules_v06_runtime_directive.md`, which remains V0.6 runtime guidance.
- `docs/semantic/global_three_layer_semantic_registry.json`, where current
  registry entries still reference pre-constitution contracts.

In particular, their GDP-driven commodity supply, separate commodity-only
track, level-IV commodity merge, or unresolved-rule clauses are superseded as
V0.7 targets. They may still describe historical prototypes or current V0.6
facts when clearly version-qualified.

## Conflict Scan Boundary

`AGENTS.md` encloses current runtime guidance between
`CURRENT_PRODUCTION_V06_ONLY_BEGIN` and
`CURRENT_PRODUCTION_V06_ONLY_END`. Rules inside that scope are deliberately
qualified V0.6 facts. Versioned V0.6 rulebooks, V0.6 tests, and the historical
records listed above are also qualified sources.

The constitution contract scans the unqualified target-authority surface for
these retired target claims:

- region-bound ordinary-card racks;
- sunlight-based card supply, purchase legality, or price;
- monster-position ordinary-card price modifiers;
- GDP-driven track color or card-kind supply;
- separate normal and commodity tracks;
- continuous mana recovery or a 100-point mana cap;
- purchased normal cards entering the hand;
- automatic normal or commodity merge;
- level-IV commodity cards;
- interactive counter windows or stacks;
- whole-player contiguous queue resolution;
- immediate final settlement before a complete macro round.

Qualified V0.6 occurrences do not count as target conflicts. An occurrence in
the V0.7 authority surface does. The required result is:

```text
CONFLICTING_UNQUALIFIED_V06_TARGET_RULE_COUNT=0
```

## Change Discipline

A future V0.7 implementation must name the affected constitution rule IDs and
migration entries. It must preserve one authoritative writer per domain,
version Save and replay state, separate RNG streams, project privacy by viewer,
and delete the conflicting legacy writer in the same atomic domain cutover.

This docs-only freeze performs no runtime cutover, creates no reference runtime,
and grants no permission to dual-write V0.6 and V0.7 state.
