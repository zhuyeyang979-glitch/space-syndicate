# AI Direct Card Field Read Migration Audit

## Verdict

- Audit: Space Syndicate Card Semantic Phase 1, Wave 1, Subagent E.
- Baseline: `59756a291f811a064726f59aed27efecc3590c9a`.
- Scope: production AI card candidate, scoring, counter, discard, and their directly invoked definition/diagnostic boundaries. Tests, tools, catalogs, scenes, rules, and balance were read-only.
- Production changes: none.
- Status: `AUDIT_COMPLETE`; the report commit is merge-ready, but semantic cutover is blocked by the hidden-owner findings below.

The primary deterministic inventory in `AiRuntimeController` contains **225 card-payload value reads** across **33 functions** and **71 field keys**, plus **5 field-presence checks**. Of the value reads, **214 are static card/role semantics or identity** and **11 are legitimate live instance/evaluation state**. The count expands the four-field dynamic loop at lines 5577-5579 into four value reads and four presence checks.

| Count class | Count | Rule |
| --- | ---: | --- |
| Literal value reads | 221 | Literal `.get("field")`: 213 `skill`/`source_skill`/`counter_skill`, 1 `evaluated_skill`, 7 public role-card reads |
| Expanded dynamic value reads | 4 | `weather_type`, `direct_interaction_role`, `futures_direction`, `strategic_role` at 5577-5579 |
| Value reads total | 225 | Literal plus expanded dynamic reads |
| Presence checks | 5 | Four dynamic `skill.has(field_name)` checks plus `evaluated_skill.has("play_requirement_district")` |
| Static semantics/identity value reads | 214 | Catalog or public role definition facts |
| Live instance/evaluation value reads | 11 | Queue/cooldown/lock/bound UID and temporary requirement district |

Dependencies that currently materialize or interpret definitions are listed under Boundary Findings. Their internal catalog reads are not added to the 225 direct-AI-consumer count, avoiding double-counting the same definition as it crosses the current compatibility boundary.

## Target Semantic Contract

The migration target is one immutable, catalog-revision-keyed `CardSemanticProfile` per card ID. Candidate scoring combines that profile with separately authorized live world/instance facts. Static semantics must never be reconstructed from names, localized text, tooltips, colors, or repeated definition dictionaries.

| Target op | Dimensions / current raw fields |
| --- | --- |
| `identity()` | `name`, `kind`, `catalog_index`, `monster_name`, family ID, rank |
| `economy_vector()` | `cost`, `cash`, `revenue_amount`, `contract_income`, `production_delta`, `transport_delta`, `consumption_delta`, `growth_multiplier` |
| `market_vector()` | `play_product`, `product_shift`, `demand_shift`, `price_delta`, `market_demand_pressure`, `market_supply_pressure` |
| `route_vector()` | `repair_routes`, `route_damage`, `route_flow_multiplier` |
| `interaction_vector()` | `steal_fail_cash`, `target_cash_penalty`, `hand_discard_count`, `hand_steal_count`, `hand_lock_seconds`, `control_gdp_penalty`, `control_block_seconds`, barrage fields |
| `combat_vector()` | `damage`, `hp`, `fixed_skill_count`, `range`, `lure_speedup`, `panic` |
| `counter_profile()` | `counter_strength`, `counter_refund`, `counter_trace` |
| `intel_vector()` | `draw_amount`, `history_review_count`, `history_subscription_count`, `reveal_city_count` |
| `weather_profile()` | `weather_type`, `weather_zone_count`, `weather_duration_seconds`, `weather_forecast_lead_seconds` |
| `military_profile()` | `military_type`, `military_hp`, `military_damage`, `military_move`, `military_range`, `military_duration_seconds`, `military_gdp_penalty`, `military_strike_route_damage`, `military_command` |
| `play_requirements()` | `starter_play_free`, cooldown baseline, authored requirements; the selected requirement district remains live evaluation state |
| `strategy_tags()` | development route, pressure/defense, policy family, product affinity; never inferred from localized labels |
| `role_semantics()` | `resource_cash_product`, `resource_cash_amount`, `bonus_card_product` from the public role authority |
| `instance_state()` | `queued_for_resolution`, `cooldown_left`, `lock_left`, `bound_monster_uid`, `bound_military_uid`, temporary requirement district |

Current authority codes used below:

- `CAT`: `CardRuntimeCatalogService` through `CardRuntimeDefinitionWorldBridge`, with Product Futures and City GDP terms enriched by their domain controllers.
- `ROLE`: `RoleCatalogRuntimeService` projected by `AiActorStatePort.public_role_definition()`.
- `INST`: authorized actor-private hand/instance owners (`AiActorHandInventoryQueryPort`, inventory/cooldown, Monster, Military).
- `AI`: `AiRuntimeController` owns heuristic weights, but is not card-definition authority.

## Per-Read Migration Table

Each row accounts for its listed value-read occurrences; the 33 rows sum to 225. `immediate-safe` means the read can be replaced by an equivalent compiled dimension without changing candidate order, RNG, privacy, or live state. `compatibility-allowlist` is an existing live-state/authority exception only. `blocked` requires an authority or privacy correction first.

| ID | File:line / function | Field reads (occurrences) | Target | Authority / privacy | Disposition | Deletion plan |
| --- | --- | --- | --- | --- | --- | --- |
| R01 | `scripts/runtime/ai_runtime_controller.gd:1484` `_make_skill` | `cooldown` (1) | `play_requirements.cooldown_baseline` | CAT; catalog-public | compatibility-allowlist | Move instance initialization to the card instance factory, then delete raw read from AI. |
| R02 | `:1666` `_counter_skill_for_ai_candidate` | `name` (1); concrete `相位否决%d` at 1667 | `identity.rank` + typed counter-conversion op | CAT/INST; actor-private source card | blocked | Role/counter owner must return a typed converted-counter profile; delete synthesized card name. |
| R03 | `:3902` `_ai_actor_private_receive_pressure` | `steal_fail_cash` (1) | `interaction_vector.steal_failure_cash` | CAT semantics bound to own hand | immediate-safe | Read compiled interaction dimension. |
| R04 | `:3909-3916` `_ai_direct_player_interaction_plan` | `kind`, discard, steal, lock, target cash (5) | `identity.kind`, `interaction_vector` | CAT; catalog-public semantics | immediate-safe | Replace field formula inputs with compiled interaction dimensions. |
| R05 | `:3980-3998` `_ai_direct_city_target_score` | `kind`, control penalty/block, barrage target/damage/route damage (6) | `interaction_vector` | CAT; catalog-public semantics | immediate-safe | Preserve AI weights over typed dimensions; remove dictionary reads. |
| R06 | `:4006-4046` `_ai_direct_city_interaction_plan` | `kind`, barrage target/damage (4) | `identity.kind`, `interaction_vector` | CAT; catalog-public semantics | immediate-safe | Consume the same compiled profile passed to R05. |
| R07 | `:4061-4066` `_ai_pressure_kind` | weather type and three economy deltas (4) | `strategy_tags.pressure` | CAT + Weather definition authority | immediate-safe | Compile pressure tag once; delete sign/name probing. |
| R08 | `:4072-4077` `_ai_defense_kind` | weather type and three economy deltas (4) | `strategy_tags.defense` | CAT + Weather definition authority | immediate-safe | Compile defense tag once; delete sign/name probing. |
| R09 | `:5251-5260` `_ai_product_focus_score` | role resource product/amount and bonus product (5) | `role_semantics.product_affinity` | ROLE; public role | compatibility-allowlist | Migrate through a typed public role-semantic projection, not the ordinary-card compiler. |
| R10 | `:5577-5579` `_ai_policy_family_for_kind` | four dynamic fields (4 reads, 4 presence checks) | `strategy_tags.policy_family` | Mixed CAT/candidate metadata | blocked | Produce policy family from compiled tags; forbid dynamic card dictionary probes. |
| R11 | `:6040-6041` `_ai_play_requirement_metadata` | `play_requirement_district` (1 read, 1 presence check) | `instance_state.requirement_district` | Live evaluation copy; actor-private | compatibility-allowlist | Move the override into typed eligibility context, outside card payload. |
| R12 | `:6087-6089` `_ai_route_hand_inventory` | queued, lock, name (3) | `instance_state` + `identity.card_id` | INST; own actor-private hand | compatibility-allowlist | Use typed slot state and semantic profile keyed by slot `card_id`. |
| R13 | `:6184-6258` `_ai_route_gap_adjustment` | 25 economy/market/route/interaction reads | corresponding vectors + `strategy_tags` | CAT; source-bound visibility | immediate-safe | Pass one compiled profile; keep only live route-plan/world inputs in AI. |
| R14 | `:6318-6336` `_ai_product_for_skill` | product, kind, price and market pressure (5) | `market_vector.product_affinity` | CAT; catalog-public semantics | immediate-safe | Replace fallback inference with compiled affinity and direction. |
| R15 | `:6447` `_ai_monster_card_landing_score` | `catalog_index` (1) | `identity.monster_profile_id` | CAT/Monster catalog | immediate-safe | Resolve stable monster profile ID during compilation. |
| R16 | `:6464` `_ai_best_monster_card_district` | `monster_name` (1) | `identity.monster_profile_id` | CAT/Monster catalog | immediate-safe | Stop joining by localized monster name. |
| R17 | `:6478-6483` `_ai_monster_target_for_skill` | bound monster UID, kind (2) | `instance_state.bound_monster_uid`, `identity.kind` | INST + CAT; actor-private binding | compatibility-allowlist | Keep UID in typed instance state; use compiled kind/tag. |
| R18 | `:6716-6800` `_ai_counter_target_threat` | 29 effect/identity reads | threat dimensions over compiled vectors | CAT; active card public semantics, owner remains hidden | immediate-safe | Compile target threat inputs; do not carry raw active-entry skill. |
| R19 | `:6816-6822` `_ai_counter_opportunity_cost` | 10 identity/counter/cost/monster reads | `counter_profile`, `combat_vector`, identity/rank | CAT; own actor-private hand | immediate-safe | Score typed source and counter profiles. |
| R20 | `:6843-6869` `_ai_counter_response_candidate` | 6 counter/name/kind reads; concrete defaults at 6854-6855 | `counter_profile`, stable IDs | CAT/INST; actor-private source | blocked | Remove concrete-name defaults after typed counter conversion and profile IDs exist. |
| R21 | `:6981-7095` `_ai_weather_control_plan` | kind, weather type/zones, product (4) | `weather_profile`, product affinity | CAT + Weather authority | immediate-safe | Compile static weather parameters; retain live weather map facts. |
| R22 | `:7196` `_ai_product_futures_product_score` | market supply/demand pressure (2) | `market_vector` | CAT/Product Futures | immediate-safe | Read typed pressure dimensions. |
| R23 | `:7308` `_ai_product_futures_plan` | `kind` (1) | `identity.kind` / futures tag | CAT/Product Futures | immediate-safe | Gate on compiled futures tag. |
| R24 | `:7398-7496` `_ai_generic_card_effect_score` | 44 reads across economy, interaction, counter, intel, route, weather, military | compiled utility vectors | CAT plus typed terms | immediate-safe | First-batch replacement: preserve constants over typed dimensions, then delete generic raw probe block. |
| R25 | `:7508-7542` `_ai_military_deploy_plan_for_district` | 11 military reads | `military_profile` | CAT/Military definition authority | immediate-safe | Pass typed force profile; retain live district/unit facts. |
| R26 | `:7611` `_ai_military_deploy_plan` | `kind` (1) | military-force tag | CAT | immediate-safe | Gate on compiled tag. |
| R27 | `:7630` `_ai_military_unit_for_command` | bound military UID (1) | `instance_state.bound_military_uid` | INST; actor-private | compatibility-allowlist | Move binding to typed command-card instance state. |
| R28 | `:7815-7821` `_ai_military_command_plan` | kind, command, range (3) | `military_profile.command` | CAT/Military authority | immediate-safe | Read typed command profile; live unit range remains unit state. |
| R29 | `:7841-8184` `_ai_card_play_context` | 27 reads across identity, effect, requirement, route, weather | compiled profile + typed eligibility | CAT/INST; own actor-private possession | immediate-safe | Pass profile beside slot state; remove all static reads, retain no payload mutation. |
| R30 | `:8416` `_ai_card_play_candidates` | queued, cooldown, lock (3) | `instance_state.playability` | INST; own actor-private hand | compatibility-allowlist | Query typed slot decision state; never compile these live values. |
| R31 | `:8537-8546,8722` `_ai_card_buy_candidates` | kind/cost plus two role bonus-product reads (4) | compiled identity/economy + typed role semantics | CAT/ROLE; rack public, role public | blocked | Cache semantic profile by card ID/revision before loops; remove per-listing `_make_skill` and role dictionary reads. |
| R32 | `:9019` `_ai_counter_response_candidates` | queued, cooldown, lock (3) | `instance_state.playability` | INST; own actor-private hand | compatibility-allowlist | Same typed slot state as R30. |
| R33 | `:9336-9355` `_ai_discard_keep_value` | cost, name, kind (3) | identity/rank + economy cost + monster tag | CAT; own actor-private possession | immediate-safe | Score semantic profile keyed by slot `card_id`. |

## Boundary Findings

### Hidden information

| Severity | Evidence | Risk and required deletion |
| --- | --- | --- |
| **BLOCKER** | `AiRuntimeController` has 54 lexical `get("owner")` reads across mixed city/monster/military/inference rows. Clear raw hidden-truth uses include city targeting at 3977, monster targeting at 6491 and 7738, and wager scoring at 9410-9423. At 9413 the code explicitly branches on `owner_revealed == false` after already reading the owner. | Hidden city/monster owner truth changes scores. Replace with actor-authorized own-binding facts or public revealed/anonymous projections; unknown rival owner must score as unknown. Delete raw owner reads from AI candidate/scoring paths. |
| **BLOCKER** | Raw city access remains `_district_city()` through Monster/Main; the existing district migration inventory records 63 calls / 43 owner reads. The semantic rows R05/R06/R13/R29/R31 combine static card meaning with this private live state. | A semantic compiler cannot launder private world truth. City-owner and mixed city facts need typed public/actor-private ports before those combined callers can be fully cut over. |
| **MAJOR** | `AiRuntimeWorldBridge.read_world_value/write_world_value` exposes whole `WorldSessionState.players` at bridge lines 49-70; AI property lines 888-892 and `_ensure_player_runtime_defaults` 3695-3719 traverse and rewrite the array. | The current function does not score cash/hand, but the capability includes every private player field and rewrites the whole aggregate. Move defaults to the owning session/economy services and delete the generic players bridge. |
| **MAJOR** | The singleton hand capability can query any AI seat, although every observed play/buy/counter/discard call supplies the planning actor index. | No observed rival-hand score read, but actor isolation is call-discipline rather than actor-bound capability. Preserve the current compatibility path only with cross-actor negative tests; future planners should receive an actor-bound snapshot. |

Exact cash and hand result:

- Opponent exact cash reads in candidate/scoring paths: **0 found**. Actor affordability and training cash use `AiActorEconomyFactsQueryPort`; public audit cash remains explicitly visibility-gated.
- Opponent hand/card-content reads in candidate/scoring paths: **0 found**. The observed card payload comes from the planning actor's `AiActorHandInventoryQueryPort` snapshot.
- Own private hand/cash reads are legitimate live state and must not be compiled into catalog semantics.

### Names, family IDs, localized text, tooltip, and color

- Family ID reads: two direct bridge calls in `_actor_highest_family_card_slot` at 585 and 597. They are stable identity lookups, but should become slot/profile IDs instead of repeated parsing.
- Concrete card/family coupling: `相位否决%d` is synthesized in AI at 1667 and Main at 4094; AI also uses concrete fallback names at 6854-6855. `GameplayBalanceDiagnosticsRuntimeService.INTERACTION_FAMILIES` hard-codes four family IDs (`星链拆解`, `影仓牵引`, `产权冻结`, `轨道齐射`). These must become semantic tags/role conversion IDs, not scoring branches.
- Source scan found **66** `.contains(...)` expressions across `AiRuntimeController` and `AiRegionKnowledgeQueryPort`: 26 localized clue/card-signal classifiers, 39 mixed ID/localized route-policy classifiers, and 1 test-only hidden-leak text scan.
- The same Chinese clue classifier is duplicated in AI lines 1553-1566 and query-port lines 345/422-428. Scoring also treats clue text containing `卡` or `牌` as a signal at 9213.
- Tooltip-derived semantic/scoring reads: **0 found**.
- Color-derived semantic/scoring reads: **0 found**. Color values in these paths are output-only callout presentation.

All localized-text classifiers are `blocked`: the producer must emit stable clue/event/tag IDs and structured product IDs before the string parsing can be deleted.

### Repeated definition/catalog work

| Severity | Evidence | Disposition |
| --- | --- | --- |
| **MAJOR** | Buy loop `district -> public card IDs` calls `_make_skill(card_name)` at 8536 for each eligible listing. `resolve_definition()` calls catalog `exact_definition()`/`derived_definition()` and enriches external terms; duplicate card IDs across racks are rematerialized. | Compile/cache `CardSemanticProfile` by `(catalog_revision, card_id)` before candidate loops. Keep only live listing price/availability in-loop. |
| **MAJOR** | `_card_development_route_id()` is called from hand inventory, play, buy, and audit paths. `GameplayBalanceDiagnosticsRuntimeService.route_for_card()` can trigger `_snapshot(false)`, whose world bridge rebuilds the card fact catalog and presentation strings, then `_card_fact()` linearly scans it. Per-frame cache reduces rebuilds but still deep-duplicates snapshots and performs repeated lookups. | Development route/policy tags belong in the compiled profile. Diagnostic full-catalog snapshots must not sit on the action-candidate path. |
| **MAJOR** | Current route fallback reads `strategy_route_label`/presentation-derived route labels before falling back to `kind`. | Author semantic route IDs directly; presentation labels are output only. |

## First Safe Batch

The first replacement batch is **75 static value reads** with no live-state or privacy change:

1. R03-R08: 24 direct-interaction, pressure, and defense reads -> `interaction_vector` plus pressure/defense tags.
2. R14 and R22: 7 product/market-affinity reads -> `market_vector`.
3. R24: 44 generic effect reads -> typed utility dimensions while preserving every current AI coefficient.

Acceptance for that batch: identical candidate membership, score components, stable sort order, RNG draw order, and actor-private/public projection use on fixed fixtures. Do not include R02/R10/R20/R31 or any hidden-owner path in this first batch.

## Proposed Forbidden-Field Scan Contract

Do not implement this contract in Wave 1; it is the Phase-2 ratchet proposal.

1. Scan production AI sources and reachable candidate/scoring helpers with a parser/token-aware scanner. A receiver becomes card-tainted from `entry.get("card")`, definition/catalog return values, `skill` parameters, or copies of those values.
2. For new or changed code, reject card-tainted `.get`, `.has`, `[]`, property access, or dynamic keys for every static field in this report. Candidate metadata dictionaries are not card-tainted.
3. Reject concrete card names/family IDs, localized text/tooltip/color parsing, and presentation label -> semantic ID conversion in AI paths.
4. Reject `resolve_definition`, `_make_skill`, `exact_definition`, `derived_definition`, catalog iteration, or diagnostic world-snapshot construction from a candidate loop.
5. Reject direct `players`, raw `_district_city`, raw `auto_monsters`, exact rival cash/hand/discard, and unrevealed `owner` access in candidate/scoring code.
6. Ratchet baseline: value reads may only decrease from 225; presence checks may only decrease from 5; new violations are zero.

Temporary exact compatibility allowlist:

| Function | Allowed field(s) | Reason | Expiry |
| --- | --- | --- | --- |
| `_ai_play_requirement_metadata` | `play_requirement_district` | Temporary evaluation override | Typed eligibility context |
| `_ai_route_hand_inventory` | `queued_for_resolution`, `lock_left` | Own live slot state | Typed `CardInstanceDecisionState` |
| `_ai_monster_target_for_skill` | `bound_monster_uid` | Own live binding | Typed monster-card instance state |
| `_ai_military_unit_for_command` | `bound_military_uid` | Own live binding | Typed command-card instance state |
| `_ai_card_play_candidates` | queued/cooldown/lock | Own live slot state | Typed `CardInstanceDecisionState` |
| `_ai_counter_response_candidates` | queued/cooldown/lock | Own live slot state | Typed `CardInstanceDecisionState` |
| `_make_skill` | `cooldown` baseline | Existing instance construction only; no new callers | Card instance factory cutover |

Allowlist entries must pin path, function, receiver provenance, owner, privacy, reason, and an expiry issue. They authorize no new occurrences and never authorize static scoring fields.

## Validation And Readiness

- JSON companion is the machine-readable mirror of this audit.
- No Godot runtime/test execution is required or claimed because no production, test, catalog, scene, rule, or balance file changed.
- Required closeout: JSON parse, deterministic count assertions, `git diff --check`, owned-file-only diff, and commit.
- Merge readiness: **YES for the two report files**. Production semantic migration readiness: **NO until hidden city/monster owner blockers are assigned to typed authorities**.
