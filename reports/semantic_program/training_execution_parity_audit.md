# AI Training Versus Production Execution Parity Audit

## Audit identity

- Audit baseline: `bd24b463660e55d83fc63deaab650c64c134be20`
- Observed `origin/main`: `59756a291f811a064726f59aed27efecc3590c9a`
- Baseline relation: the observed `origin/main` is an ancestor of the audit baseline.
- Branch: `codex/semantic-program-training-parity-bd24b46`
- Worktree: isolated under `%TEMP%/space-syndicate-codex/`.
- Scope: AI learning/planning, simulation, balance diagnostics, and production card, economy, monster, military, weather, and response execution paths.
- Write scope: this report and `reports/semantic_program/training_execution_parity_audit.json` only.
- Production code, tests, catalogs, rules, balance values, RNG behavior, save data, and prior reports were not modified.

## Executive verdict

There is no standalone offline trainer, self-play runner, rollout engine, or second simulation executable in the audited production tree. Current AI "training" is online learning inside `AiRuntimeController`: it records decisions made during the live game, waits for later live world deltas, derives reward values, and persists the resulting AI memory.

That is useful evidence against a separate training game, but it is not evidence of execution parity. Parity is currently **not established**:

1. No production `OperationHandlerRegistry` or `RuleExecutionPlan` implementation exists.
2. The public `build_turn_plan` and `build_response_plan` facade is not the production scheduler. It always chooses the top sorted candidate, while production uses shared RNG exploration and a separate probabilistic counter-response gate.
3. `AiCardSemanticProjectionService` is a detached, bench-only projection boundary. It is not composed into `GameRuntimeCoordinator`, and its outcome adjustments are supplied by its caller rather than derived from an authoritative execution plan or terminal receipt.
4. Production card execution still has v0.6 and legacy branches, raw `kind` / `effect_kind` handler inference, and a v0.4 runtime catalog plus special monster and finance sources.
5. AI card scoring and gameplay diagnostics independently reinterpret large raw field surfaces. The audited AI file contains 214 direct `skill`-family reads across 65 field names. The two gameplay diagnostics files contain 240 direct `skill` / `card` reads across 85 field names.
6. A concrete hidden-information defect exists: monster wager scoring reads the real monster `owner` even when `owner_revealed` is false, despite a public monster projection that removes owner data.
7. A concrete balance-model divergence exists: the developer environment model uses 60-180 second forecast and 75-180 second active ranges, while production weather uses 30-60 and 45-90 seconds.
8. Save and deterministic trace contracts do not bind a decision to semantic catalog, registry, handler, execution-plan, RNG-draw, owner-receipt, or terminal-receipt lineage.

The audit records **32 grouped findings**: **6 REMOVE**, **15 MOVE**, and **11 KEEP**. `KEEP` means the component is a legitimate production owner, shared formula, transaction boundary, deterministic reference, or read-only shell. It does not assert full training/execution parity.

## Deterministic scan inventory

| Measure | Result |
| --- | ---: |
| Production GDScript files scanned under `scripts/` | 730 |
| Standalone trainer/self-play/rollout filename matches | 0 |
| Standalone trainer/self-play/rollout content matches | 0 |
| `OperationHandlerRegistry` production classes/references | 0 |
| `RuleExecutionPlan` production classes/references | 0 |
| External production composition references to `AiCardSemanticProjectionService` | 0 |
| AI raw `skill` / `source_skill` / `counter_skill.get(...)` occurrences | 214 |
| Unique AI raw card fields | 65 |
| AI raw `.get("owner", ...)` occurrences | 54 |
| Diagnostics raw `skill` / `card.get(...)` occurrences | 240 |
| Unique diagnostics raw card fields | 85 |
| Grouped findings | 32 |
| REMOVE / MOVE / KEEP | 6 / 15 / 11 |

The AI raw-card field inventory is:

`bound_military_uid`, `bound_monster_uid`, `cash`, `catalog_index`, `consumption_delta`, `contract_income`, `control_block_seconds`, `control_gdp_penalty`, `cooldown`, `cooldown_left`, `cost`, `counter_refund`, `counter_strength`, `counter_trace`, `damage`, `demand_shift`, `draw_amount`, `fixed_skill_count`, `global_barrage_damage`, `global_barrage_route_damage`, `global_barrage_target_count`, `growth_multiplier`, `hand_discard_count`, `hand_lock_seconds`, `hand_steal_count`, `history_review_count`, `history_subscription_count`, `hp`, `kind`, `lock_left`, `lure_speedup`, `market_demand_pressure`, `market_supply_pressure`, `military_command`, `military_damage`, `military_duration_seconds`, `military_gdp_penalty`, `military_hp`, `military_move`, `military_range`, `military_strike_route_damage`, `military_type`, `monster_name`, `name`, `panic`, `play_product`, `play_requirement_district`, `price_delta`, `product_shift`, `production_delta`, `queued_for_resolution`, `range`, `repair_routes`, `reveal_city_count`, `revenue_amount`, `route_damage`, `route_flow_multiplier`, `starter_play_free`, `steal_fail_cash`, `target_cash_penalty`, `transport_delta`, `weather_duration_seconds`, `weather_forecast_lead_seconds`, `weather_type`, `weather_zone_count`.

The diagnostics raw-card field inventory is:

`armor`, `art_stats`, `authored_skill`, `bonus_card_product`, `card_id`, `card_name`, `cash`, `chip_texts`, `consumption_delta`, `contract_income`, `control_block_seconds`, `control_gdp_penalty`, `cost`, `counter_strength`, `counter_window_seconds`, `damage`, `delay`, `draw_amount`, `duration`, `family`, `fixed_skill_count`, `futures_terms`, `gdp_derivative_terms`, `global_barrage_damage`, `global_barrage_route_damage`, `global_barrage_target_count`, `growth_multiplier`, `guard`, `hand_discard_count`, `hand_lock_seconds`, `hand_steal_count`, `history_review_count`, `history_subscription_count`, `hp`, `kind`, `knockback`, `lure_speedup`, `market_demand_pressure`, `market_supply_pressure`, `military_damage`, `military_duration_seconds`, `military_gdp_penalty`, `military_hp`, `military_move`, `military_range`, `monster_cards_as_counter`, `move`, `name`, `panic`, `persistent`, `play_cash`, `play_product`, `play_region_gdp_share_required`, `price`, `production_delta`, `quick_effect`, `range`, `ranged_guard`, `rank`, `repair_routes`, `requirement`, `resolution_handler`, `reveal_city_count`, `revenue_amount`, `route_damage`, `route_flow_multiplier`, `route_label`, `skill`, `stabilize_amount`, `starter_play_free`, `starting_cash_bonus`, `starting_cash_delta`, `steal_fail_cash`, `summon_access`, `supply_product`, `tags`, `target`, `target_cash_penalty`, `target_monster_required`, `target_player_required`, `text`, `transport_delta`, `use_case`, `weather_duration_seconds`, `weather_zone_count`.

These are lexical occurrence counts, not 214 or 240 independently authoritative formulas. The grouped findings below distinguish legitimate live-state reads from card-semantic interpretation that must move.

## Entrypoint inventory

| Surface | Exact entrypoint | Actual role | Parity status |
| --- | --- | --- | --- |
| Production AI cadence | `scripts/runtime/ai_runtime_controller.gd:249-252`; called in `scripts/runtime/runtime_simulation_phase_coordinator.gd:45-46` | Advances the live AI inside the authoritative simulation phase | Production authority |
| Formal turn planner | `scripts/runtime/ai_runtime_controller.gd:260-275` | Builds and top-selects a card play/buy plan | Not used by production scheduler |
| Formal response planner | `scripts/runtime/ai_runtime_controller.gd:279-302` | Builds and top-selects counter/wager response | Not used by production response scheduler |
| Formal rank/receipt/intent facade | `scripts/runtime/ai_runtime_controller.gd:305-340` | Sorts caller dictionaries, records receipt, forwards a generic intent | API-shape facade; no production action route beyond noop |
| Production card choice | `scripts/runtime/ai_runtime_controller.gd:8840-8853`, `:8911-8932` | Uses shared RNG exploration, then submits through production purchase/play entrypoints | Live production path |
| Production counter choice | `scripts/runtime/ai_runtime_controller.gd:9090-9120` | Adds a score threshold and shared-RNG probability gate | Live production path, differs from formal response planner |
| Online decision recording | `scripts/runtime/ai_runtime_controller.gd:4939-5034` | Stores observation, candidate metadata, and baseline outcome values | Live online learning input |
| Online reward finalization | `scripts/runtime/ai_runtime_controller.gd:5035-5070`; called at `scripts/main.gd:847-852` | Computes reward from later live cash/victory deltas | Live online learning update |
| AI memory save/restore | `scripts/runtime/ai_runtime_controller.gd:343-449` | Persists profiles and learned memory in the existing AI save section | Production save path |
| Developer world snapshot | `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:53-88` | Builds a sanitized developer snapshot, but sources raw skill and private helper facts | Diagnostic input, not execution |
| Gameplay diagnostics | `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:47-51`, `:815-858` | Caches snapshots and calls `RuntimeBalanceModel.statistics_hub_report` | Read-only diagnostic path |
| Runtime balance model | `scripts/balance/runtime_balance_model.gd:314-369`, `:648-772` | Shared production formulas plus independently reconstructed diagnostics | Mixed shared formula and duplicate interpretation |
| Legacy card balance analyzer | `scripts/balance/card_balance_analyzer.gd:13-55`; reporter at `scripts/balance/card_balance_reporter.gd:7-34` | Loads a vertical-slice dataset and applies a separate heuristic model | Alternate diagnostic model |
| Military balance report | `scripts/runtime/military_runtime_controller.gd:790-870` | Re-scores raw military card fields | Diagnostic reinterpretation inside a production owner |
| Weather balance bench | `scripts/tools/weather_balance_report_v1_bench.gd:55-60`, `:146-169` | Deterministic acceptance fixture using production definitions and resolver | Legitimate bounded reference, not live telemetry |
| Production simulation | `scripts/runtime/runtime_simulation_step.gd:86-112`; phase order at `scripts/runtime/runtime_simulation_phase_coordinator.gd:33-58` | Authoritative game-loop execution | Production authority, not a trainer |
| Determinism audit | `scripts/runtime/simulation_determinism_audit.gd:26-74`, `:149-169` | Records bounded fingerprints and development diagnostics | Passive reference, no state/save ownership |
| Semantic AI projection bench | `scripts/tools/ai_card_semantic_projection_bench.gd:14-18`, `:111-169` | Determinism, negative, readiness, and source checks for the isolated projector | Tool-only reference; no production composition |
| Balance runtime bridge bench | `scripts/tools/balance_runtime_bridge_bench.gd:112-163`, `:289-318` | Runs developer flow and diagnostics cases | Tool-only acceptance entrypoint |
| Balance parameter resource bench | `scripts/tools/balance_parameter_resource_bench.gd:27-51`, `:114-151` | Compares Resource and JSON parameter manifests | Tool-only reference; not production execution |
| Balance model sandbox bench | `scripts/tools/balance_model_resource_sandbox_bench.gd:24-66`, `:124-151` | Runs bounded model sample cases | Tool-only reference; alternate-model caveats apply |
| Parameter/model adapters | `scripts/balance/balance_parameter_model_adapter.gd:14-52`; `scripts/balance/balance_runtime_parameter_bridge.gd:17-96` | Compares runtime-model, Resource, and JSON values | Developer comparison path; not proof of live owner parity |
| Developer balance presentation | `scripts/presentation/developer_balance_application_host.gd:20-60`; `scripts/ui/developer_balance_panel.gd:39-46`; bench at `scripts/tools/developer_balance_application_host_bench.gd:16-27` | Mounts and refreshes the read-only diagnostic panel | Presentation/bench only |
| Interactive balance previews | `scripts/tools/balance_model_resource_sandbox.gd:27-29`; `scripts/tools/balance_runtime_bridge_mcp_preview.gd:27-29`; `scripts/tools/balance_parameter_resource_mcp_preview.gd:23-24` | UI entrypoints for the same developer comparison models | Tool-only; no execution authority |
| Simulation migration benches | `scripts/tools/simulation_runtime_authority_migration_bench.gd:9-13`; `scripts/tools/simulation_monster_action_command_migration_bench.gd:6-10`; `scripts/tools/simulation_autonomous_behavior_command_migration_bench.gd:6-10` | Bounded source/composition migration checks | Test/reference only |
| Simulation determinism benches | `scripts/tools/simulation_determinism_foundation_bench.gd:10-14`; `scripts/tools/simulation_determinism_consumption_layer_bench.gd:9-13` | Scene wrappers around focused determinism tests | Test/reference only |

No caller invokes `build_turn_plan` or `build_response_plan` as the live scheduler. `scripts/ai/ai_policy_resource_registry.gd:174-189` only inspects source text to verify that the API names exist.

## Production execution map

### Cards and responses

Production card submission begins at `CardPlaySubmissionRuntimeController`. It branches between v0.6 and legacy at `scripts/runtime/card_play_submission_runtime_controller.gd:60-109`. v0.6 cards can execute directly through coordinator transaction APIs at `:300-342` or enter a shared queue at `:345-477`; legacy cards enter the queue path.

Queued execution derives a handler from target kind, machine `effect_kind`, or raw `skill.kind` at `scripts/runtime/card_resolution_execution_runtime_service.gd:796-812`. `CardEffectRuntimeRouter` then dispatches raw handler IDs to economy, monster, military, weather, intel, or coordinator methods at `scripts/runtime/card_effect_runtime_router.gd:44-78`, `:91-101`, and `:113-165`.

The v0.6 core-economic path already has the useful beginning of a registry and transaction lifecycle: `CoreEconomicCardEffectRouterV06` validates a fixed effect-kind allowlist and routes prepare/commit/abort/finalize at `scripts/cards/v06/production/core_economic_card_effect_router_v06.gd:4-29`, `:33-75`. It is not yet a whole-game semantic operation registry.

Human forced decisions use typed, revision-bound, exact-once response paths in `scripts/runtime/forced_decision_response_port.gd:49-92`, `scripts/runtime/card_target_choice_response_sink.gd:30-155`, and `scripts/runtime/monster_wager_response_sink.gd:23-77`. AI monster wagers call the monster owner directly at `scripts/runtime/ai_runtime_controller.gd:1870-1872`; AI counter responses submit directly to card queueing at `:9025-9089`.

### Economy

Production product-market refresh uses `RuntimeBalanceModel.product_price_model` and a detached `RunRngService` cursor at `scripts/runtime/product_market_runtime_controller.gd:534-621`, then commits the cursor and live market state at `:520-531`. This is positive evidence of a shared numeric formula and single RNG authority.

### Monster, military, and weather

The production phase coordinator calls monster battle lifecycle, motion, actions, durations and revival in a fixed order at `scripts/runtime/runtime_simulation_phase_coordinator.gd:43-58`. The monster owner exposes typed autonomous movement commands at `scripts/runtime/monster_runtime_controller.gd:656-764` and retains the actual action state machine around `:4312-4338` and `:6018-6075`.

Military live execution remains in `MilitaryRuntimeController.tick`, `summon_from_card`, and `trigger_command` at `scripts/runtime/military_runtime_controller.gd:159-165`, `:594-651`, and `:665-788`. Weather live execution remains in `WeatherRuntimeController.tick` and `apply_weather_control_at` at `scripts/runtime/weather_runtime_controller.gd:220-250`, `:350-365`, backed by production lifecycle constants in `scripts/runtime/weather_system.gd:4-23`.

## REMOVE findings

| ID | Exact evidence | Finding | Required removal |
| --- | --- | --- | --- |
| TEP-001 | `scripts/runtime/ai_runtime_controller.gd:320-340`; `scripts/runtime/ai_runtime_world_bridge.gd:100-111`; `scripts/main.gd:876-881` | The generic formal intent route is disconnected from production actions and supports only `ai_runtime_noop`. | Remove the facade after typed action routes cover all callers; do not present it as execution parity. |
| TEP-002 | `scripts/runtime/ai_runtime_controller.gd:839-844`, `:9407-9425`; safe projection at `scripts/runtime/monster_runtime_controller.gd:781-789`, `:3187-3199` | Wager scoring reads true monster owner while `owner_revealed` can be false. | Remove private owner access and score only viewer-authorized monster facts. |
| TEP-003 | `scripts/runtime/ai_runtime_controller.gd:4385-4409`, `:4937-4989` | The training allowlist records unscoped fields such as `target_owner`, owner bias, exact candidate names, and derived internal scores. | Remove unauthorized or hidden-derived fields; persist stable action/receipt IDs and sanitized explanation tokens only. |
| TEP-004 | `scripts/runtime/ai_runtime_controller.gd:786-800`, `:839-922`, `:3695-3719`; `scripts/runtime/ai_runtime_world_bridge.gd:47-81`, `:93-97` | AI has generic world read/write/call capabilities and directly patches player runtime defaults. | Remove generic mutation/call authority from AI; mutations must use typed production commands and owner receipts. |
| TEP-005 | `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:306-316` | Production diagnostics hard-code a localized sample-card subset. | Remove the runtime sample oracle; use semantic tags or an explicit test fixture outside production authority. |
| TEP-006 | `scripts/balance/environment_balance_model.gd:13-18`, `:34-49`; `scripts/runtime/weather_system.gd:4-23`; weak comparison at `scripts/balance/balance_parameter_model_adapter.gd:168-181` | The developer weather model has different forecast/active ranges, while its adapter compares against model resources instead of live weather execution. | Remove it as a production-parity oracle; replace it with projection of the production weather definition/system contract. |

## MOVE findings

| ID | Exact evidence | Finding | Stable destination |
| --- | --- | --- | --- |
| TEP-007 | `scripts/runtime/ai_runtime_controller.gd:260-302`, `:8840-8853`, `:8911-8928`, `:9090-9120` | Formal planners top-select deterministically; production uses exploration and an extra counter-response probability gate. | One candidate contract and scheduler. Observation/scoring may differ, but selected action must enter the same plan/registry path. |
| TEP-008 | Representative reads at `scripts/runtime/ai_runtime_controller.gd:3971-4002`, `:6770-6783`, `:7519-7530`; audited total 214 reads / 65 fields | AI directly interprets card-specific raw fields. | `CardSemanticSpec + AiObservationSnapshot -> AiActionCandidate`; no raw payload reads for migrated operations. |
| TEP-009 | AI bypass at `scripts/runtime/ai_runtime_controller.gd:1870-1872`, `:9025-9089`; typed production boundaries at `scripts/runtime/forced_decision_response_port.gd:49-92`, `scripts/runtime/monster_wager_response_sink.gd:23-77` | AI responses bypass the typed identity, revision, replay, and receipt path used by player responses. | AI and human responses submit the same typed request to the same response sinks. |
| TEP-010 | Queue acceptance and immediate recording at `scripts/runtime/ai_runtime_controller.gd:8864-8907`, `:9025-9089`; live reward finalization at `:5035-5070` | Training samples bind to queue acceptance, not the terminal effect/rollback receipt that proves what occurred. | Record plan ID at selection, then attach learning only to sanitized terminal execution receipts and state deltas. |
| TEP-011 | `scripts/runtime/ai_card_semantic_projection_service.gd:35-78`, `:115-160`; caller adjustments at `scripts/runtime/ai_outcome_vector_v1.gd:37-55`; no coordinator scene composition | The semantic projector is isolated and accepts caller-authored legality/outcome adjustments. | Compose it behind an authoritative rules projection; legality and neutral outcomes derive from `RuleExecutionPlan` and receipts. |
| TEP-012 | `scenes/runtime/CardRuntimeCatalogService.tscn:3-8`; `scripts/runtime/card_runtime_catalog_service.gd:11-21`; special sources at `scripts/runtime/card_runtime_definition_world_bridge.gd:31-43`, `:77-102`; uncomposed v0.6 cache at `scenes/runtime/CardSemanticCatalogService.tscn:3-8` | Production still uses the v0.4 catalog plus monster/finance enrichment while semantic compilation reads v0.6. | One compiled semantic catalog, with explicit adapters and fingerprints for preserved compatibility sources. |
| TEP-013 | `scripts/runtime/card_play_submission_runtime_controller.gd:60-109`, `:300-477` | v0.6 direct/queued paths and legacy queue execution are separate runtime authorities. | One `RuleExecutionPlan` submission lifecycle; retain existing owners and transaction semantics behind adapters. |
| TEP-014 | `scripts/runtime/card_resolution_execution_runtime_service.gd:796-812`; `scripts/runtime/card_effect_runtime_router.gd:44-101`, `:129-165` | Execution infers handlers from target, machine effect kind, or raw card kind, then dispatches through another kind table. | Resolve only stable `operation_id + handler_version` through `OperationHandlerRegistry`; unknown operations fail closed. |
| TEP-015 | `scripts/cards/v06/production/core_economic_card_effect_router_v06.gd:4-29`, `:33-75` | A narrow registry-like prepare/commit/abort/finalize lifecycle already exists but is keyed to legacy effect kinds. | Promote this machinery into the shared registry without creating a second economic engine. |
| TEP-016 | `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:106-148`, `:181-223`, `:274-316` | Diagnostics reconstruct raw cards and monsters through Main/private helpers and a localized subset. | A standard read-only semantic diagnostic projection plus public owner facts. |
| TEP-017 | `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:6-12`, `:889-1023`; audited total 240 reads / 85 fields | Diagnostics independently map names/kinds/routes and re-score raw payload fields. | Consume `SemanticSpec`, `RuleExecutionPlan`, and terminal receipt projections; never reinterpret raw card meaning. |
| TEP-018 | `scripts/balance/card_balance_analyzer.gd:6-55`, `:75-102`, `:166-194` | The vertical-slice analyzer uses a separate catalog subset, heuristic effect values, and rank strings. | Keep only as a standard semantic diagnostic consumer or retire; it must not be a balance/training authority. |
| TEP-019 | `scripts/runtime/military_runtime_controller.gd:790-870` | Military diagnostics independently score raw military fields inside the live owner. | Project production military semantic specs and execution receipts to diagnostics; keep live state/commands in the owner. |
| TEP-020 | `scripts/balance/runtime_balance_model.gd:709-727`; production action authority at `scripts/runtime/monster_runtime_controller.gd:4312-4338`, `:6018-6075` | Monster statistics rebuild attack-pressure values from raw actions instead of consuming production semantic/receipt facts. | Standard monster diagnostic projection sharing handler and formula lineage with production. |
| TEP-021 | `scripts/runtime/v06_save_owner_registry.gd:28-47`; `scripts/runtime/simulation_trace_contract.gd:5-40`; `scripts/runtime/card_resolution_history_runtime_service.gd:228-249` | Save/trace/history omit semantic catalog, registry, handler, plan, RNG-draw, and owner-receipt lineage. | Extend versioned section/trace payloads without changing the existing root envelope; preflight fingerprints on replay/restore. |

## KEEP findings

| ID | Exact evidence | Why it stays | Constraint |
| --- | --- | --- | --- |
| TEP-022 | `scripts/balance/runtime_balance_model.gd:129-179`; production use at `scripts/runtime/product_market_runtime_controller.gd:534-618` | Product price and flow formulas are genuinely shared with production. | Register/reference the same formula owner; do not copy the equations into training. |
| TEP-023 | `scripts/runtime/ai_runtime_controller.gd:1794-1797`, `:1825-1838` | AI purchase and normal card play already enter typed production controllers. | Keep these entrypoints and make candidates reference authoritative plans/receipts. |
| TEP-024 | `scripts/runtime/ai_runtime_controller.gd:2254-2358` | AI business pressure uses request identity, owner prepare/commit/rollback/finalize, and a typed cash port. | Use it as the lifecycle model; do not fork a training implementation. |
| TEP-025 | `scripts/runtime/ai_runtime_controller.gd:4939-5070`; cycle hook at `scripts/main.gd:847-852` | Online learning derives reward from actual later live cash and victory deltas. | Keep online observation/scoring, but sanitize features and bind updates to terminal receipts. |
| TEP-026 | `scripts/runtime/runtime_simulation_step.gd:86-112`; `scripts/runtime/runtime_simulation_phase_coordinator.gd:33-58` | This is the authoritative production game loop with fixed phase order. | Training execution must invoke the same operation handlers, never emulate this loop with alternate rules. |
| TEP-027 | `scripts/runtime/simulation_determinism_audit.gd:26-74`, `:149-169` | The audit records deterministic fingerprints and explicitly owns no world/save/presentation state. | Extend trace lineage, but keep it passive and development-only. |
| TEP-028 | `scripts/runtime/run_rng_service.gd:97-164` | One service provides checkpoints, detached draws, commit, and restore. | Training uses detached cursors from this service; RNG state and draw count must match production plans. |
| TEP-029 | `scripts/runtime/forced_decision_response_port.gd:49-92`; `scripts/runtime/card_target_choice_response_sink.gd:30-155`; `scripts/runtime/monster_wager_response_sink.gd:23-77` | Typed response boundaries already provide identity, revision, exact-once, and receipts. | Route AI responses through the same contracts; no direct-owner response mutation. |
| TEP-030 | `tests/core_economic_card_effect_router_v06_test.gd:148-204`; `tests/simulation_determinism_foundation_test.gd:157-259`; `tests/simulation_determinism_consumption_layer_test.gd:155-303` | Bounded deterministic fixtures exercise production classes and lifecycle invariants. | Test fakes remain test-only; parity claims still require production owner/handler fingerprints. |
| TEP-031 | `scripts/tools/weather_balance_report_v1_bench.gd:55-60`, `:146-169` | The bounded bench explicitly uses production weather definitions and `WeatherEffectResolver`, and does not claim live telemetry. | Keep as a reference acceptance model; add live execution parity gates separately. |
| TEP-032 | `scenes/runtime/GameplayBalanceDiagnosticsRuntimeService.tscn:6-9`; `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:47-51` | A read-only, cached developer diagnostics owner is legitimate. | Keep the shell after raw rule interpretation moves to standard semantic/receipt projections. |

## Required shared execution protocol

Observation and scoring may remain AI-specific. Legality, costs, targets, operation order, RNG policy, owner calls, mutation, rollback, and receipts may not.

1. **Viewer-scoped observation**: `AiObservationSnapshot` is built from public facts plus the acting player's authorized private facts. It cannot contain hidden owner, opponent hand, owner objects, raw save payloads, RNG state, or unfiltered world dictionaries.
2. **Compile once**: the authoritative catalog compiles immutable semantic specs at initialization and caches them by semantic/catalog fingerprint. Candidate generation receives specs, never raw payloads, and cannot compile per frame or per candidate.
3. **Authoritative plan**: a rules projection validates actor, instance, target, costs, conditions, information scope, and randomness policy, then emits one immutable `RuleExecutionPlan` with ordered operations and expected owner revisions.
4. **Stable registry resolution**: `OperationHandlerRegistry` resolves each `operation_id + handler_version` to one production domain handler. Unknown IDs, versions, conditions, and targets fail closed before mutation.
5. **One lifecycle**: production and training both submit the same plan to the same handler lifecycle: all preflights, all checkpoints, ordered apply, reverse rollback, finalize, and terminal receipt. A handler cannot branch on `training_mode` to use alternate formulas.
6. **Isolated training state**: a training/what-if run uses isolated owner checkpoints or owner-provided deterministic sandboxes and a detached `RunRngService` cursor. It never mutates the live world and never substitutes fake production handlers.
7. **Separate scoring**: AI personality, strategy, uncertainty, and outcome weighting consume sanitized projected facts and terminal receipts after execution. They remain outside `SemanticSpec` and handlers.
8. **Receipt projection**: training sees an allowlisted receipt projection and viewer-authorized state delta. Hidden card names, private owner identity, private hands, internal owner state, and unrevealed RNG results remain trimmed.
9. **Replay lineage**: save/replay/trace binds semantic catalog fingerprint, semantic spec fingerprint, registry fingerprint, handler versions, plan fingerprint, ordered owner receipt fingerprints, RNG checkpoint/terminal state/draw count, and terminal receipt fingerprint.

A minimal immutable plan envelope should include:

```text
RuleExecutionPlan
  schema_version
  plan_id
  plan_fingerprint
  semantic_catalog_fingerprint
  semantic_spec_fingerprint
  registry_fingerprint
  source_instance_identity
  actor_identity
  target_bindings
  expected_owner_revisions
  ordered_operations[]
    sequence
    operation_id
    handler_version
    owner_id
    condition_result_fingerprint
    arguments
    visibility_policy_id
    randomness_policy_id
  expected_rng_checkpoint
```

## Mandatory parity gates

| Gate | Required assertion |
| --- | --- |
| Catalog/spec identity | Production and training use identical catalog and semantic-spec fingerprints. |
| Plan identity | Same request and baseline produce the same plan fingerprint and ordered operation list. |
| Registry identity | Registry fingerprint, `operation_id`, and handler version are identical; no fake production handler is imported. |
| Owner calls | Owner ID, method capability, normalized arguments, and call count match exactly. |
| Operation ordering | Preflight/checkpoint/apply/finalize sequence matches, including cross-owner operation order. |
| Failure lifecycle | Same injected failure yields the same reason code, mutation count, reverse rollback order, and terminal state fingerprint. |
| RNG | Initial checkpoint, draw labels/order, draw count, terminal cursor, and commit/restore result match. Failed or discarded training plans cannot advance live RNG. |
| Receipts | Prepare, apply, rollback/finalize, and terminal receipt fingerprints match after viewer-safe projection. Queue acceptance alone is insufficient. |
| Hidden information | Candidate, training sample, receipt, and replay projections contain only viewer-authorized facts; unrevealed owner and private hand probes fail. |
| Save/restore | Restored semantic/registry/handler lineage matches before replay; mismatch fails closed without partial owner apply. |
| Replay | Replaying the same plan yields the same owner-call order, RNG delta, terminal receipt, and state fingerprint or an explicit idempotent receipt. |
| Compilation performance | Catalog compilation occurs during initialization/cache miss only; candidate loops report zero compile calls. |
| Raw-field ban | Migrated operations produce zero AI/diagnostic raw payload reads outside an explicit shrinking allowlist. |
| Production composition | `AiCardSemanticProjectionService`, rules projection, registry, and receipt projector are composed once in the production scene graph. |

## Blockers to a parity claim

1. `OperationHandlerRegistry` does not exist in production.
2. `RuleExecutionPlan` does not exist in production.
3. The semantic AI projector is not composed into the production runtime.
4. The formal planner is not the live scheduler and has different selection semantics.
5. AI monster wager scoring consumes unrevealed owner identity.
6. AI forced responses bypass typed response ports.
7. Card submission and execution still have v0.6/legacy dual paths and raw handler inference.
8. Production catalog authority is v0.4 plus special sources, while semantic compilation uses v0.6.
9. Diagnostics and AI still reinterpret raw payload fields at scale.
10. Weather diagnostics are demonstrably numerically divergent from production.
11. Training samples are not bound to terminal effect receipts.
12. Save/replay/trace do not carry semantic, registry, handler, RNG, and owner-receipt lineage.

## Non-claims

- This audit does not claim current training/production execution parity.
- It does not claim that every raw AI field read is invalid; live world-state features can remain after they are projected through an authorized observation contract.
- It does not claim that test doubles are second production engines. The cited deterministic fixtures are legitimate when they remain test-only and exercise production classes.
- It does not propose changing rules, balance values, RNG order, save root shape, or state ownership.
- It does not authorize a second simulation engine. Training must reuse production plans, handlers, owner protocols, and RNG semantics while keeping observation and scoring separate.
