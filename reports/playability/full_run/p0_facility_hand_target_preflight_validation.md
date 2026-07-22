# P0 Facility Hand Target Preflight Validation

Branch: `codex/p0-alpha01-facility-hand-presentation-ff8f168`

Rule authority: `docs/tabletop_rulebook_v06.md` §2.3. An empty unique slot builds the
played rank, a higher-rank card upgrades the viewer's matching facility, and a same/lower-rank
card repairs it. A facility owned by another player or neutral owner is not a legal upgrade or
repair target.

## Production boundary

- `CoreEconomicCardRuntimeAdapterV06` resolves the authoritative actor, hand slot, card instance,
  player revision, payload, unique facility target, and the same binding shape used by
  `CardFlowTransactionServiceV06.play_card`.
- Facility hand preflight goes through the existing `CoreEconomicCardEffectRouterV06` and final
  `FacilityCardEffectAdapterV06.prepare_effect`, then immediately aborts the prepared effect.
- `abort_prepared_effect` is a hard capability gate. A router without abort support is rejected
  before `prepare_effect` can run, and a void/unverified abort receipt never counts as cleanup.
  Readiness requires a typed receipt for the same transaction, `verified = true`, and no pending
  router association.
- Formal facility play and eligibility preflight share the Core adapter's facility target builder.
  Neither path samples or reflects `Main` and no second facility, flow, player, or journal owner
  was introduced.
- The public coordinator action keeps the requested `region_id` exactly. It never substitutes an
  economic-source recommendation, supports build/upgrade/repair ranks, and delegates to the same
  `CardPlaySubmissionRuntimeController` gate used by hand submission. The old index-based public
  facility entry is explicitly retired and cannot mutate infrastructure.
- Submission re-reads the authoritative card, requires the exact requested slot and runtime
  instance, then re-runs final facility eligibility immediately before the single formal CardFlow
  mutation. Game-over, forced-decision, player/card cooldown, asset-cost, target, and preflight
  failures therefore fail closed even for stale or manually constructed requests.
- `CardPlayEligibilityWorldBridge` supplies only `applicable`, `ready`, and an allow-listed public
  reason to `CardPlayEligibilityRuntimeService`. Machine envelopes, runtime instance IDs, actor IDs,
  and facility owner fields do not enter presentation facts.
- An invalid current map selection is disabled in place. Even when another region has an empty
  matching slot, the preflight does not silently replace the selected region.
- Every v0.6 card must expose the complete authoritative asset-cost key set. A missing key disables
  the action as `asset_cost_unavailable` with no internal key disclosure and a safe player message
  confirming that neither card nor assets will be deducted.

## Player-facing reasons

The hand surface distinguishes unavailable region, occupied slot, incompatible slot, missing
local-product conditions, changed card binding, and temporarily unavailable preflight. Every case
is non-actionable and directs the player to change the selection manually where appropriate.

## Focused verification

- `facility_card_production_unlock_v06_test.gd`: PASS, `170/170`.
  - empty slot ready;
  - other-player and neutral occupied slots rejected;
  - own Rank-II upgrade and same-rank repair are actionable and formally executed against the
    specified region while a second region remains unchanged;
  - facility, flow, player/hand, and full inventory journal byte-stable before/after repeated
    preflight;
  - router pending transaction count returns to zero;
  - missing abort capability fails before prepare, while void/unverified abort fails after prepare
    without being accepted as cleanup proof;
  - presentation actionability matches immediate formal execution for ready and rejected targets;
  - eligibility/presentation payload contains no machine, runtime-instance, actor, or owner truth;
  - current invalid selection remains selected while another empty region exists.
- `district_supply_purchase_projection_receipt_test.gd`: PASS, `60/60`, including three consecutive
  final runs.
  - missing v0.6 asset-cost key disables the real hand action with the safe public reason and no
    internal key leak;
  - the retired legacy facility entry and a stale manual cooldown submission change no card,
    journal, PlayerMana, flow, or facility state;
  - an occupied requested region is rejected while another legal region exists, proving there is
    no target substitution;
  - real enabled GameScreen actions traverse GameScreen -> Main public action -> the shared
    submission gate -> formal CardFlow for own Rank-II upgrade and repair; the specified region
    changes and the comparison region remains unchanged.
- `core_economic_card_effect_router_v06_test.gd`: PASS, `76/76`.
- `card_execution_typed_ports_cutover_test.gd`: PASS, `42/42`.
- `card_flow_transaction_service_v06_test.gd`: PASS, `81/81`.
- `region_infrastructure_atomic_lifecycle_v06_test.gd`: PASS, `70/70`.
- `card_flow_policy_v06_test.gd`: PASS, `37/37`.
- `RuntimeCardCatalogResourceBench`: PASS, `80/80`.
  - non-`public_facility` callers retain the existing
    `legacy_city_development_retired` precedence contract;
  - `public_facility` callers receive `legacy_public_facility_entry_retired` and cannot reach a
    facility mutation owner.
- `PlayerManaCardWindowRuntimeBench`: PASS, `32/32`.
  - the production seven-key v0.6 asset-cost gate remains fail-closed because the authoritative
    catalog validator requires all seven keys on every catalog card and the catalog builder emits
    a complete zero map for free cards;
  - the three stale commodity/intel eligibility fixtures now match that existing catalog schema
    while preserving their free, payable, and insufficient-asset expectations.
- `main_runtime_composition_test.gd`: PASS.
- `table_presentation_source_target_cutover_test.gd`: PASS, `20/20`.
- `table_presentation_viewmodel_parity_test.gd`: PASS, `100/100`.
- `ui_text_smoke_test.gd`: PASS.
- `visual_snapshot.gd`: PASS.
- `smoke_test.gd --check-only`: PASS (exit code 0).
- Godot 4.7 MCP formal production launch: `res://scenes/main.tscn` loaded and remained running
  without a script/runtime error; debug output and stop output contained only the repository's
  pre-existing warning/NUL-decoding baseline. The coordinator stopped the project after inspection.

## Known unrelated baseline failures

The stale `action_result_v1_facility_play_adopter_test.gd` still calls removed
`Main._start_scenario_from_menu` and cannot reach its assertions. Earlier full-smoke and legacy
presentation fixtures likewise reference retired Main helpers. None of those files or retired
Main/AI paths were changed for this boundary; the stronger production-session test above now covers
the public facility action path directly.

Godot MCP/editor acceptance is intentionally deferred to the active coordinator, per task split.
That coordinator acceptance is now complete as recorded above.
