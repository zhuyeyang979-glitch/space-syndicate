# Save, Replay, Privacy, and RNG Semantic Audit

## Audit identity

- Integration baseline: `39ec00854d7f0439aab6f053948e5a58088ba2d5`
- Observed `origin/main`: `59756a291f811a064726f59aed27efecc3590c9a`
- Baseline relation: `59756a291f811a064726f59aed27efecc3590c9a` is an ancestor of the integration baseline.
- Branch: `codex/semantic-program-wave1-save-replay-39ec008`
- Audit date: `2026-07-27`
- Scope: production save/cold-restore, card resolution history and replay-shaped records, semantic persistence boundaries, viewer privacy, RNG ownership/order, training/runtime execution parity, and v0.4 compatibility risk.
- Production changes: none. Test, catalog, rule, balance, RNG, and save changes: none.
- Owned artifacts: this report and `reports/semantic_program/save_replay_privacy_rng_audit.json` only.

The scan covered 530 production GDScript files under `scripts/**/*.gd`, excluding `scripts/tools/**`. Findings use source behavior as evidence; documentation is cited only where it describes the already implemented save contract.

## Executive verdict

The v3/v0.6 envelope has a sound fixed-order transaction shell: one registry declares exactly 19 sections, validates every section before mutation, captures every checkpoint before apply, applies in fixed order, and rolls back in reverse order. The envelope itself is strict, and v1/v2 inputs are inspect-only. Those boundaries should be kept.

The current build must **not** claim full-run resume. Seven of the 19 registry bindings are still explicitly unsupported. In addition, `RunRngService` exposes save/restore methods, but no production save owner calls them; the session payload saves only the original session seed. Product-market state also has `to_save_data()`/`apply_save_data()` but is absent from all 19 bindings. These are independent cold-continuation blockers.

The current semantic compiler, AI semantic projection, and player-face projection persist no state and consume no RNG. That is the correct boundary: compiled semantic specs and DTOs are derived cache/projection data and must not become a twentieth save section or a second owner. A future envelope should persist stable content identity/version bindings and dynamic instance state, then recompile/reproject after load.

Replay identity is not ready for a semantic cutover. Resolution history deliberately removes `v06_card_id` and instance identity, then the public query manufactures `public_card_id` from a localized skill name. In-flight execution saves raw transaction and skill dictionaries under schema versions 1-3. Replay compatibility therefore requires explicit versioned adapters and must fail closed when an identity cannot be resolved; the compiler must never guess from localized text.

Finally, the current execution of the semantic operations named `discard_random`, `steal_random`, and `lock_random` is not random: it takes the first ordered eligible slots and consumes zero RNG. This is a rule/RNG parity blocker. The semantic program may document that mismatch, but may not silently introduce a draw or change the live RNG sequence without product-rule authority and parity fixtures.

## Non-negotiable contract

```text
NEW_SEMANTIC_SAVE_SECTION_COUNT=0
SEMANTIC_COMPILER_RNG_DELTA=0
SEMANTIC_QUERY_RNG_DELTA=0
VIEWER_CLIPPING_BEFORE_AI_UI=true
REPLAY_COMPATIBILITY=VERSIONED_ADAPTERS_FAIL_CLOSED
TRAINING_PRODUCTION_EXECUTION_ENGINE=SAME
FULL_RUN_RESUME_CLAIM=false
```

Required interpretation:

1. `CardSemanticSpec`, the other domain SemanticSpecs, compiled execution plans, `PlayerPresentationDTO`, `AiObservationSnapshot`, and `AiActionCandidate` are immutable or ephemeral derived data. None becomes a save owner.
2. Stable semantic schema/catalog fingerprints belong in an existing ruleset/session compatibility handshake, not in a new section and not as duplicated full specs.
3. Dynamic card/unit/weather/victory state remains with existing business owners.
4. Viewer clipping must happen before either AI or UI projection. A projection validator is defense in depth; it is not a substitute for an authorized, clipped source query.
5. Replay adapters are versioned and deterministic. Missing or ambiguous legacy identity fails closed; localized display text is never treated as rule identity.
6. Training may consume projected observations and candidates, but execution must submit to the same production handler/transaction path.

## Deterministic counts

| Measure | Count | Reproduction/evidence |
| --- | ---: | --- |
| Production `.gd` files scanned | 530 | `rg --files scripts -g '*.gd' -g '!scripts/tools/**'` |
| Fixed v3/v0.6 save sections | 19 | `scripts/runtime/v06_save_owner_registry.gd:28-48` |
| Transactional bindings | 12 | `scenes/runtime/V06SaveOwnerRegistry.tscn:14-184` |
| Unsupported bindings | 7 | Same scene; list below |
| History forbidden private key classes | 17 | `scripts/runtime/card_history_restore_dependency_contract.gd:13-31` |
| Semantic compiler/projection save APIs | 0 | Targeted scan of compiler, catalog, AI projection, and player-face projection |
| Semantic compiler/projection forbidden RNG calls | 0 | Targeted call scan of the same four files |
| Semantic production composition references | 0 | `GameRuntimeCoordinator.tscn` plus `game_runtime_coordinator.gd` scan |
| Direct live RNG call sites outside `RunRngService` | 15 | Two Main, four AI, three monster, three market, three weather call sites |
| Detached RNG call sites | 23 | Six product-market, two session-plan, twelve world-plan, three weather-plan calls |
| `RunRngService` save API production consumers | 0 | Cross-file call scan |
| Product-market save registry bindings | 0 | `V06SaveOwnerRegistry.tscn` scan |
| Separate trainer/self-play execution engine files | 0 | Production filename and symbol scan |
| Findings | 33 | 11 KEEP, 18 MOVE, 4 REMOVE |
| Hard blockers | 5 | Listed below |
| Staged migration phases | 8 | Stage 0 through Stage 7 |

The live RNG count excludes the `RunRngService` method bodies and detached cursor calls. It includes `scripts/main.gd:4918`, `scripts/main.gd:4933`; `scripts/runtime/ai_runtime_controller.gd:2045`, `:2422`, `:8846`, `:9111`; `scripts/runtime/monster_runtime_controller.gd:3792`, `:5511`, `:6182`; `scripts/runtime/product_market_runtime_controller.gd:498`, `:1853`; `scripts/runtime/product_market_runtime_world_bridge.gd:180`; and `scripts/runtime/weather_system.gd:56`, `:72`, `:101`.

## Fixed 19-section envelope

The exact order is authoritative in `scripts/runtime/v06_save_owner_registry.gd:28-48`. The scene binds one entry per section in `scenes/runtime/V06SaveOwnerRegistry.tscn:6-189`.

| Order | Section | Owner ID | Current restore mode | Evidence/status |
| ---: | --- | --- | --- | --- |
| 1 | `ruleset` | `ruleset_runtime` | unsupported | `ruleset_apply_api_missing`, scene lines 8-10 |
| 2 | `region_infrastructure` | `public_facility_region` | transactional | scene lines 14-21 |
| 3 | `region_supply` | `region_supply` | transactional | scene lines 25-32 |
| 4 | `commodity_flow` | `commodity_flow` | transactional | schema 2, scene lines 36-45 |
| 5 | `routes` | `route_network` | unsupported | `strict_preflight_and_exact_rollback_missing`, lines 49-51 |
| 6 | `player_mana` | `player_mana` | transactional | lines 55-62 |
| 7 | `commodity_belt_visibility` | `commodity_belt_visibility` | unsupported | `apply_api_missing`, lines 66-68 |
| 8 | `card_inventory` | `card_inventory` | unsupported | `apply_api_missing`, lines 72-74 |
| 9 | `player_organization` | `player_organization` | transactional | lines 78-85 |
| 10 | `monsters` | `monster_runtime` | transactional | lines 89-96 |
| 11 | `military` | `military_runtime` | unsupported | `strict_preflight_missing`, lines 100-102 |
| 12 | `weather` | `weather_runtime` | transactional | lines 106-113 |
| 13 | `card_resolution_queue` | `card_resolution_queue` | unsupported | `apply_api_missing`, lines 117-119 |
| 14 | `card_resolution_execution` | `card_resolution_execution` | transactional | lines 123-131 |
| 15 | `card_resolution_history` | `card_resolution_history` | transactional | lines 135-143 |
| 16 | `ai` | `ai_runtime` | unsupported | `strict_preflight_missing`, lines 147-149 |
| 17 | `bankruptcy_neutral_estate` | `bankruptcy_neutral_estate` | transactional | lines 153-160 |
| 18 | `victory_control` | `victory_control` | transactional | lines 164-171 |
| 19 | `session` | `game_session` | transactional | composite schema 2, lines 175-184 |

`V06SaveOwnerRegistry.apply_envelope()` completes global preflight, then captures all 19 checkpoints, then applies fixed order (`scripts/runtime/v06_save_owner_registry.gd:115-175`). `_rollback_sections()` reverses the applied list and verifies exact restored state (`scripts/runtime/v06_save_owner_registry.gd:410-430`). Cross-section preflight validates public history/private annotations and commodity post-commit dependencies before apply (`scripts/runtime/v06_save_owner_registry.gd:356-389`).

The top-level handshake requires the exact envelope keys and exact manifest (`scripts/runtime/ruleset_save_handshake_service.gd:38-108`). It composes `session` with the other sections at `:121-135`. Legacy v1/v2 is inspect-only and cannot resume (`scripts/runtime/ruleset_save_handshake_service.gd:141-172`; `docs/v06_save_envelope_runtime_contract.md:11-46`).

The `session` section is itself a schema-2 composite of exactly `game_session_runtime`, `world_session_state`, and `card_history_private_annotations` (`scripts/runtime/session_envelope_save_owner.gd:5-11`, `:31-64`). Restore applies world state, then private annotations, then game-session lifecycle last (`scripts/runtime/session_envelope_save_owner.gd:107-165`). Its debug contract explicitly says `full_run_resume_claimed=false` (`scripts/runtime/session_envelope_save_owner.gd:179-193`).

## Domain identity and persistence matrix

| Domain | Current identity entering save/replay | Save location/current owner | Cold-restore condition | Classification and requirement |
| --- | --- | --- | --- | --- |
| Card | `card_id`, `family_id`; live slots also carry raw skill/card dictionaries | `region_supply` saves full `cards_by_id`, order, racks, bags, per-region RNG (`scripts/runtime/region_supply_runtime_controller.gd:353-371`); session player `slots` remain required (`scripts/runtime/world_session_envelope_codec.gd:26-91`); queue/execution/history have separate records | Supply is transactional; `card_inventory` and queue are unsupported. History drops stable IDs | KEEP stable IDs. MOVE dynamic instance state to its existing card owner, bind catalog fingerprint, and use versioned replay adapters. Do not save compiled specs |
| Role | Array `role_index` plus localized `role_card.name`; full flat `role_card` copied into player | Existing `session/world_session_state` | Codec requires index/name parity against current ordered names and otherwise accepts the role dictionary (`scripts/runtime/world_session_envelope_codec.gd:448-508`) | MOVE to stable `role_id` in `RoleSemanticSpec`; keep an explicit index/name adapter for old payloads until fixtures prove parity |
| Monster | Runtime `uid`; newer actors include `monster_family_id` and `formal_card_id_v06` | `monsters` saves complete roster and lifecycle journals (`scripts/runtime/monster_runtime_controller.gd:1461-1482`) | Transactional, but validation permits missing family ID (`:2298-2324`) and lookup falls back to localized name (`:3098-3103`) | MOVE every persisted actor to stable family/spec identity. REMOVE name fallback only after a deterministic adapter converts all supported payloads |
| Product | `product_id` is currently localized content identity, e.g. `星露莓` | Product IDs occur in world districts and commodity flow; ProductMarket separately owns save methods (`scripts/runtime/product_market_runtime_controller.gd:1627-1649`) but has no registry binding | Commodity flow is transactional; product-market state is outside the envelope | MOVE to stable `ProductSemanticSpec` identity with an explicit localized-ID compatibility map. Add product-market state through an existing section/composite adapter, not a twentieth section |
| Facility | Generated `facility_id`, ASCII `facility_type`, `industry_id`, `region_id` | `region_infrastructure` (`scripts/runtime/region_infrastructure_runtime_controller.gd:927-962`) | Transactional; intent fingerprint binds region/type/industry/rank (`:1185-1195`) | KEEP identity and owner. Static `FacilitySemanticSpec` stays outside save; persist only identity/version binding and dynamic facility state |
| Military | Runtime `uid`, `military_type`, localized `name`, and `source_card` | `military` raw roster (`scripts/runtime/military_runtime_controller.gd:901-908`) | Registry says strict preflight missing | MOVE to a versioned strict unit-state schema with stable unit-family/spec identity and exact rollback. Localized `name` remains display only |
| Weather | Stable catalog `definition_id`; event also duplicates `type`; regions duplicate `region_indices` and `districts` | `weather` | Transactional and validates `definition_id` against known definitions (`scripts/runtime/weather_runtime_state.gd:106-200`) | KEEP `definition_id`. MOVE readers to canonical fields, then REMOVE duplicate aliases after replay migration (`scripts/runtime/weather_runtime_controller.gd:712-729`) |
| Victory | Dynamic lifecycle state, qualification timers, audit roster, outcome receipt, `ruleset_id` | `victory_control` (`scripts/runtime/victory_control_runtime_controller.gd:368-434`) | Transactional; live world facts are deliberately re-queried after restore | KEEP dynamic owner. MOVE static victory rule identity/fingerprint into existing ruleset compatibility binding; never save a second `VictorySemanticSpec` copy |

`resources/content/product_industry_catalog_v05.tres:55-69` demonstrates that `product_id` and display name are currently the same localized string. `scripts/content/product_industry_catalog_resource.gd:17-43` uses that value as lookup identity. A migration must preserve those values as explicit legacy aliases; inventing transliterations during restore would be nondeterministic.

The facility path is the strongest current model: `facility_id` is generated from stable slot identity plus generation (`scripts/runtime/region_infrastructure_runtime_controller.gd:231-234`, `:263-311`) and the transactional owner saves dynamic records. Military is the opposite: `to_save_data()` returns an unversioned raw array and `apply_save_data()` assigns it without strict validation (`scripts/runtime/military_runtime_controller.gd:901-908`).

## Semantic persistence boundary

`CardSemanticCatalogService` compiles the source catalog once during `_ready()` and retains a fingerprinted cache (`scripts/runtime/card_semantic_catalog_service.gd:32-75`). The compiler keys its cache by schema version and source-definition fingerprint (`scripts/cards/semantic/card_semantic_compiler_v1.gd:52-89`). Neither exposes `to_save_data()` nor `apply_save_data()`.

The AI projection validates an active semantic spec and a closed, authorized observation before creating candidates (`scripts/runtime/ai_card_semantic_projection_service.gd:35-78`). Its input contract rejects hidden owner, rival hand/cash, route plan, RNG state, private plans, Nodes, resources, and methods (`scripts/runtime/ai_card_semantic_projection_input_v1.gd:19-37`, `:76-177`, `:229-241`). The player-face projection reports `owns_save_state=false` and `uses_rng=false` (`scripts/runtime/card_player_face_projection_service.gd:268-283`).

At this baseline, there are zero `CardSemantic*`, `AiCardSemantic*`, or `PlayerFace*` composition references in `scenes/runtime/GameRuntimeCoordinator.tscn` and `scripts/runtime/game_runtime_coordinator.gd`. Therefore the current semantic layer has zero save and RNG delta, but it is not yet a production cutover. Production composition must supply already-clipped input; merely retaining the projection validator is insufficient.

Persistence rules for all future domain specs:

- Persist stable identity, authored schema version, catalog/ruleset fingerprint, and dynamic instance state in existing owners.
- Recompile immutable specs after catalog initialization and verify the persisted compatibility fingerprint before applying dynamic state.
- Never serialize compiled `SemanticSpec`, `RuleExecutionPlan`, player DTO, AI observation, AI candidate, handler object, Node, Callable, or cache.
- Never add a semantic save registry entry or save-owned semantic singleton.

## Card history, replay, and legacy bridges

### Public history privacy is strong, identity is weak

The history restore contract accepts pure-data entries, rejects 17 private key classes, and requires canonical `resolution_id` lineage (`scripts/runtime/card_history_restore_dependency_contract.gd:13-31`, `:44-114`). The history service creates a public projection and recursively removes private fields (`scripts/runtime/card_resolution_history_runtime_service.gd:228-276`). Private annotations are stored in per-viewer buckets and, during restore, are rebuilt only after their referenced public history exists (`scripts/runtime/card_history_private_annotation_service.gd:325-441`).

However, `_history_receipt()` erases `v06_card_id`, `v06_card_instance_id`, effect identity, asset reservation, and other private execution fields before append (`scripts/runtime/card_resolution_execution_world_bridge.gd:297-318`). The public query then sets `public_card_id` from `skill.name`/`card_name`, a localized display value (`scripts/presentation/card_history_public_query_port.gd:74-100`). This is not a stable replay identity.

Required migration:

1. Define a public-safe, stable semantic identity carried by new history schema entries: semantic domain, spec ID, authored schema version, and public revision/fingerprint as applicable.
2. Keep private instance identity and hidden actor binding out of public history.
3. Add explicit adapters for each supported old history schema. An adapter may map only through a frozen legacy manifest; no name guessing against the current catalog.
4. If one old display name maps to zero or multiple stable IDs, fail closed and preserve the record as non-executable historical display data.
5. Do not rewrite old user files in place before backup/authorization.

### Queue and execution records are replay-shaped mutable dictionaries

The queue stores a duplicated raw `skill` inside each entry (`scripts/runtime/card_resolution_queue_runtime_service.gd:128-160`) and still exposes `apply_legacy_save_snapshot()` (`:539-555`). Its public entry uses skill `name` and `kind` (`:693-707`). The queue registry binding is currently unsupported.

The execution owner saves schema version 3 with completed IDs, raw in-flight execution transactions, pending settlements, and a transition checkpoint (`scripts/runtime/card_resolution_execution_runtime_service.gd:419-426`). It accepts save schemas 1, 2, and 3 and upgrades them to the current shape (`:476-581`). Transaction validation checks lineage and intent ordering but retains the authored raw transaction/skill payload (`:643-750`).

Required migration:

- New queue/execution records carry a versioned semantic execution-plan identity and immutable operation IDs plus the minimum dynamic operands needed to resume.
- Legacy schemas stay behind explicit version adapters and are covered by golden restore/replay fixtures.
- The stable target envelope becomes the canonical target identity. Legacy mirrors such as `selected_district`, `selected_trade_product`, `target_player`, and `target_slot` remain adapter inputs only during the compatibility window.
- Unknown operation, target, condition, identity, or schema fails closed before owner mutation.
- History is an audit projection, not a source from which to re-execute a card.

### v0.4 compatibility risk

The top-level save handshake correctly forbids legacy resume (`scripts/runtime/ruleset_save_handshake_service.gd:141-172`), but internal runtime/save payloads still contain v0.4 identifiers and bridges. Examples include `source_v04_card_id` in authored card ranks (`scripts/cards/card_runtime_rank_v05_resource.gd:8-30`), queue legacy snapshot import (`scripts/runtime/card_resolution_queue_runtime_service.gd:539-555`), execution schemas 1/2 (`scripts/runtime/card_resolution_execution_runtime_service.gd:476-581`), and runtime components configured by `ruleset_id == "v0.4"`.

These internal adapters must not be confused with permission to resume a top-level v0.4 file. Preserve them only where a current v3 section explicitly embeds an older child schema. Each bridge needs a named source schema, deterministic mapping, destination schema, ambiguity rule, fixture, and removal gate.

## Privacy boundary

Current protections to keep:

- Local presentation authorizes exactly one human viewer and permits private access only to the same subject (`scripts/presentation/local_viewer_authorization.gd:42-59`; `scripts/presentation/table_presentation_viewer_context.gd:23-32`).
- Table query ports route private projections through that authorization (`scripts/presentation/table_presentation_query_ports.gd:57-100`).
- AI hand and cash queries require bound capabilities and actor-private identity (`scripts/runtime/ai_actor_hand_inventory_query_port.gd:89-145`, `:178-208`; `scripts/runtime/ai_actor_economy_facts_query_port.gd:89-192`).
- Public card history strips private fields, while private annotations remain viewer-bucketed and are persisted through the existing composite session owner.

Required ordering for every semantic projection:

```text
authoritative owner
  -> viewer/actor authorization
  -> clipped detached snapshot
  -> SemanticSpec + clipped snapshot
  -> PlayerPresentationDTO or AiActionCandidate
```

The AI/UI projector must never receive rival exact cash, rival hand/card identities, hidden monster owner, private route plan, private target plan, RNG state, save payload, or AI memory unless the specific viewer is authorized. Public aggregate facts may be separately projected by an existing public owner. Candidate explanations and training samples inherit the same clipped scope; they cannot reintroduce hidden source fields.

## RNG ownership and ordering

`Main._ready()` randomizes the unique run RNG once (`scripts/main.gd:176-181`). `GameRuntimeCoordinator` wires that same service into AI, monster, weather, and product-market bridges (`scripts/runtime/game_runtime_coordinator.gd:1374-1390`). `RunRngService` counts live draws and supplies detached cursor draw/commit/rollback APIs (`scripts/runtime/run_rng_service.gd:24-61`, `:97-164`). No second RNG owner is needed.

The frame order matters for exact continuation. Card resolution/cooldowns execute in the command phase first (`scripts/runtime/runtime_command_phase_coordinator.gd:17-24`). The active simulation phase then advances derivative/futures timers, weather, economic boons, monster wager lifecycle, AI, monster motion, military, monster actions/durations, visual cues, and monster revival in that order (`scripts/runtime/runtime_simulation_phase_coordinator.gd:33-58`). RNG persistence and replay tests must preserve this ordering.

| RNG boundary | Current behavior | Audit result |
| --- | --- | --- |
| Catalog load | No RNG call in semantic catalog service | delta 0; KEEP |
| Semantic compilation | Deterministic fingerprint/cache; no RNG call | `SEMANTIC_COMPILER_RNG_DELTA=0`; KEEP |
| Player/AI semantic query | Closed pure-data projection; no RNG call | `SEMANTIC_QUERY_RNG_DELTA=0`; KEEP |
| Session planning | 14 detached calls across session/world plan builders; commit after transaction | deterministic cursor pattern; KEEP |
| Product-market planning | Six detached calls plus reversible commit paths | retain transaction cursor pattern |
| Weather planning | Three detached calls; legacy live WeatherSystem also has three live draws | MOVE live paths behind one declared policy/handler |
| AI execution | Four live draws | Preserve ordering until each operation has an explicit randomness policy |
| Monster behavior | Three live draws | Preserve ordering and bind behavior spec version |
| Product-market live paths | Three live calls including world bridge | MOVE into explicit transactional/randomness policies |
| Main helpers | Two live calls | MOVE to owning registered domain handlers; do not duplicate RNG |

### Cold continuation blocker

`RunRngService.to_save_data()` and `apply_save_data()` exist (`scripts/runtime/run_rng_service.gd:167-187`), but the production consumer count is zero. The API saves only `rng_state`, not `_draw_count`. `GameSessionRuntimeController.to_save_data()` persists only the initial session `seed` (`scripts/runtime/game_session_runtime_controller.gd:197-211`). Restoring that seed cannot recreate the current shared cursor after an arbitrary number of draws.

Required change in a later implementation PR: extend the **existing `session` composite** with a versioned child RNG checkpoint owned and applied by the existing `RunRngService`. Persist both state and draw count needed by stale-check/transaction semantics. Capture it atomically with the other section checkpoints, restore it before any resumed runtime tick, and rollback it exactly on failure. Do not add a section, autoload, RNG owner, or semantic owner.

### Random interaction parity blocker

The hand-interaction planner labels a `selection_draw_count` based on discard/steal/lock counts (`scripts/runtime/player_hand_interaction_runtime_service.gd:264-305`). The inventory returns eligible slots in their existing order (`scripts/runtime/card_inventory_runtime_service.gd:136-154`). The execution router then sets `selected_slots = candidates.slice(0, draw_count)` (`scripts/runtime/card_effect_runtime_router.gd:179-202`). No RNG draw occurs.

Meanwhile, semantic schema/compiler operations are named `discard_random`, `steal_random`, and `lock_random` (`scripts/cards/semantic/card_semantic_schema_v1.gd:58-60`; `scripts/cards/semantic/card_semantic_compiler_v1.gd:545-552`), and the current spec has no explicit top-level randomness policy. Until product authority resolves whether the established behavior or the wording is correct, the compiler must preserve the existing deterministic outcome and mark the operation projection-only/fail-closed for execution. Introducing a random draw would change both rules and every subsequent shared RNG result.

## Training and production execution parity

No separate trainer, self-play rules engine, or simplified execution engine was found. Current "training" code projects allowlisted candidate metadata (`scripts/runtime/ai_runtime_controller.gd:4385-4410`) and appends decision samples to AI memory (`:4939-5015`). A chosen AI card uses `_queue_skill_resolution()`, which submits to `CardPlaySubmissionRuntimeController` with `submission_source="ai"` (`scripts/runtime/ai_runtime_controller.gd:1825-1838`), and the normal card turn calls that path (`:8911-8991`).

KEEP this single-execution-engine property. Future offline training may replay `AiObservationSnapshot`/`AiActionCandidate`, but any authoritative transition must invoke the same registered `operation_id -> domain handler` and transaction implementation used in production. A simulator may estimate outcomes but cannot become a second rules authority or write save-owned state.

The current training samples contain raw candidate metadata, AI memory, and exact own cash (`scripts/runtime/ai_runtime_controller.gd:4385-4410`, `:4980-5015`). MOVE their source to clipped, versioned AI projections before exporting or replaying samples. Do not persist `AiActionCandidate` as authoritative game state.

## Findings

`KEEP` means retain the boundary. `MOVE` means preserve behavior while moving identity or responsibility into the stated existing owner/spec/adapter. `REMOVE` is allowed only after the corresponding versioned migration and parity gates are green.

| ID | Class | Finding | Evidence / requirement |
| --- | --- | --- | --- |
| SRPR-001 | KEEP | Single fixed 19-section registry with all-preflight/all-checkpoint/fixed-apply/reverse-rollback transaction | `scripts/runtime/v06_save_owner_registry.gd:28-48`, `scripts/runtime/v06_save_owner_registry.gd:115-175`, `scripts/runtime/v06_save_owner_registry.gd:356-430` |
| SRPR-002 | KEEP | Strict v3/v0.6 envelope; legacy v1/v2 inspect-only | `scripts/runtime/ruleset_save_handshake_service.gd:38-108`, `scripts/runtime/ruleset_save_handshake_service.gd:141-172` |
| SRPR-003 | KEEP | Session composite restores world, annotations, then lifecycle; explicitly makes no full-resume claim | `scripts/runtime/session_envelope_save_owner.gd:5-11`, `scripts/runtime/session_envelope_save_owner.gd:107-193` |
| SRPR-004 | KEEP | Stable card `card_id`/`family_id` already exists in region supply | `scripts/runtime/region_supply_runtime_controller.gd:469-510` |
| SRPR-005 | KEEP | Facility uses stable IDs and a transactional dynamic owner | `scripts/runtime/region_infrastructure_runtime_controller.gd:231-311`, `scripts/runtime/region_infrastructure_runtime_controller.gd:927-975` |
| SRPR-006 | KEEP | Weather validates stable `definition_id` against the catalog | `scripts/runtime/weather_runtime_state.gd:106-200` |
| SRPR-007 | KEEP | Public history rejects/sanitizes private data; annotations are viewer-scoped and dependency-checked | `scripts/runtime/card_history_restore_dependency_contract.gd:13-114`; `scripts/runtime/card_history_private_annotation_service.gd:325-441` |
| SRPR-008 | KEEP | Local UI and AI private queries require viewer/actor authorization | `scripts/presentation/local_viewer_authorization.gd:42-59`; AI hand/economy query ports cited above |
| SRPR-009 | KEEP | One shared `RunRngService` plus detached cursor APIs | `scripts/runtime/game_runtime_coordinator.gd:1374-1390`; `scripts/runtime/run_rng_service.gd:97-164` |
| SRPR-010 | KEEP | Semantic compiler/query/player DTO own no save state and consume no RNG | Targeted counts 0; compiler/cache and projection evidence above |
| SRPR-011 | KEEP | AI training currently records production decisions and selected actions use production submission | `scripts/runtime/ai_runtime_controller.gd:1825-1838`, `scripts/runtime/ai_runtime_controller.gd:4385-4410`, `scripts/runtime/ai_runtime_controller.gd:8911-8991` |
| SRPR-012 | MOVE | Add narrow transactional preflight/apply/rollback to the seven unsupported existing section owners | `scenes/runtime/V06SaveOwnerRegistry.tscn:8-149` |
| SRPR-013 | MOVE | Persist shared RNG state/draw count through the existing session composite | `scripts/runtime/run_rng_service.gd:167-187`; zero consumers; `scripts/runtime/game_session_runtime_controller.gd:197-211` |
| SRPR-014 | MOVE | Include ProductMarket dynamic state through an existing section/composite adapter | `scripts/runtime/product_market_runtime_controller.gd:1627-1649`; registry reference count 0 |
| SRPR-015 | MOVE | Bind semantic schema/source/catalog fingerprints to the existing ruleset compatibility handshake | `scripts/runtime/card_semantic_catalog_service.gd:50-63`; no current envelope binding |
| SRPR-016 | MOVE | Replace full static card-definition persistence in region supply with stable IDs plus catalog binding | `scripts/runtime/region_supply_runtime_controller.gd:353-371` |
| SRPR-017 | MOVE | Remove duplicated card slots and AI profile/memory from WorldSession only after their existing owners become transactional | `scripts/runtime/world_session_envelope_codec.gd:26-91`; card/AI bindings unsupported |
| SRPR-018 | MOVE | Migrate role index/localized-name save identity to stable `role_id` with an explicit adapter | `scripts/runtime/world_session_envelope_codec.gd:448-508` |
| SRPR-019 | MOVE | Normalize every monster actor to stable family/formal card identity | `scripts/runtime/monster_runtime_controller.gd:2298-2324`, `scripts/runtime/monster_runtime_controller.gd:3230-3249`, `scripts/runtime/monster_runtime_controller.gd:3609-3656` |
| SRPR-020 | MOVE | Version and strictly validate military unit identity/state before registry support | `scripts/runtime/military_runtime_controller.gd:901-908`, `scripts/runtime/military_runtime_controller.gd:918-925` |
| SRPR-021 | MOVE | Migrate localized product identity to stable `ProductSemanticSpec` ID with frozen aliases | `product_industry_catalog_v05.tres:55-69`; catalog API `:17-43` |
| SRPR-022 | MOVE | Carry a public-safe stable card semantic identity in new history schema entries | history receipt strips IDs at `scripts/runtime/card_resolution_execution_world_bridge.gd:297-318` |
| SRPR-023 | MOVE | Replace raw queue/in-flight skill persistence with versioned semantic execution-plan identity and operands | `scripts/runtime/card_resolution_queue_runtime_service.gd:128-160`; `scripts/runtime/card_resolution_execution_runtime_service.gd:419-581` |
| SRPR-024 | MOVE | Make stable target envelope canonical; retain index/string mirrors only in version adapters | queue `:128`; execution bridge `:243-265`, `:383-384` |
| SRPR-025 | MOVE | Canonicalize weather event fields to `definition_id` and `region_indices` | `scripts/runtime/weather_runtime_state.gd:22-45`, `scripts/runtime/weather_runtime_state.gd:95-113`; producer `scripts/runtime/weather_runtime_controller.gd:712-729` |
| SRPR-026 | MOVE | Bind static victory semantic version through ruleset; keep only dynamic lifecycle in owner | `scripts/runtime/victory_control_runtime_controller.gd:368-434` |
| SRPR-027 | MOVE | Source training samples from clipped `AiObservationSnapshot`/`AiActionCandidate`, never raw rival/private payload | `scripts/runtime/ai_runtime_controller.gd:4385-4410`, `scripts/runtime/ai_runtime_controller.gd:4980-5015` |
| SRPR-028 | MOVE | Compose semantic projections in production only behind owner authorization and pre-projection clipping | production composition references 0; projection input validator `scripts/runtime/ai_card_semantic_projection_input_v1.gd:19-37` |
| SRPR-029 | MOVE | Add explicit randomness policy and preserve current draw order until rule authority resolves random hand interactions | semantic ops `scripts/cards/semantic/card_semantic_schema_v1.gd:58-60`; deterministic slice `scripts/runtime/card_effect_runtime_router.gd:179-202` |
| SRPR-030 | REMOVE | Stop manufacturing `public_card_id` from localized card name after history adapter cutover | `scripts/presentation/card_history_public_query_port.gd:74-100` |
| SRPR-031 | REMOVE | Delete localized monster-name-to-family fallback after all supported payloads are normalized | `scripts/runtime/monster_runtime_controller.gd:3098-3103` |
| SRPR-032 | REMOVE | Delete weather `type`/`districts` aliases after versioned replay migration | `scripts/runtime/weather_runtime_controller.gd:712-729` |
| SRPR-033 | REMOVE | Delete duplicate static card/catalog payloads from dynamic save after stable-ID/fingerprint restore is proven | `scripts/runtime/region_supply_runtime_controller.gd:353-371` |

## Hard blockers

| Blocker | Why it blocks a claim/cutover | Required resolution |
| --- | --- | --- |
| `SAVE_REGISTRY_INCOMPLETE` | Seven fixed sections cannot participate in exact transactional restore | Implement narrow owner APIs and fault-injection tests without adding sections |
| `RUN_RNG_CURSOR_NOT_PERSISTED` | Current seed cannot reproduce the cursor after live draws; stale transaction draw count is also lost | Versioned RNG checkpoint inside existing session composite; restore before runtime tick |
| `PRODUCT_MARKET_OUTSIDE_ENVELOPE` | Prices, cycle, timers, and futures positions are save-owned but absent from the 19 bindings | Existing-section composite adapter, with exact checkpoint/apply/rollback |
| `REPLAY_CARD_IDENTITY_UNSTABLE` | Public history loses stable card identity; in-flight records remain raw/version-bridged | New schema plus deterministic adapters and ambiguity rejection |
| `RANDOM_OPERATION_PARITY_UNRESOLVED` | Semantic op names promise randomness while execution selects the first slots and consumes no RNG | Product-rule decision plus golden outcome/RNG-order fixtures; no compiler guess |

These blockers do not invalidate the existing transactional shell or privacy guards. They require `FULL_RUN_RESUME_CLAIM=false` and prohibit executing new semantic operations as if parity were already established.

## Staged migration requirements

### Stage 0: freeze invariants and fixtures

- Freeze representative v3 envelopes for all 19 wrappers, current execution schemas 1/2/3, history schema 1, role index/name payloads, legacy monster actors, localized product IDs, military units, weather aliases, and victory lifecycle states.
- Record shared RNG state/draw count immediately before save and expected first post-load draws for each live consumer in runtime phase order.
- Add privacy fixtures proving rival hand, exact cash, hidden monster owner, route plan, AI memory, and private annotations never cross public/viewer boundaries.

### Stage 1: compatibility identity binding

- Add semantic kernel/domain schema versions and catalog fingerprints to the existing ruleset/session handshake.
- Reject unknown or mismatched fingerprints before applying any owner.
- Do not persist compiled specs and do not add a registry section.

### Stage 2: stable domain identities and replay adapters

- Add stable `role_id`, product ID, military family ID, and mandatory monster family ID to new saves.
- Add public-safe card semantic identity to new history and execution records.
- Implement one adapter per supported child schema. Each adapter is pure, deterministic, version-addressed, and fail-closed.
- Keep top-level v1/v2 save inputs inspect-only.

### Stage 3: complete existing owner transactions

- Implement preflight/checkpoint/apply/rollback for the seven unsupported bindings.
- Move duplicated `slots`, `ai_profile`, and `ai_memory` out of session only after the card and AI owners are restore-capable and cross-section dependencies are explicit.
- Capture product-market state under an existing composite section without changing business ownership.

### Stage 4: exact RNG continuation

- Version `RunRngService` checkpoint to include state and draw count.
- Capture/apply through the existing session composite and include it in rollback verification.
- Restore before command/simulation phases can run.
- Keep compiler, catalog load, viewer queries, player DTO, AI observation, and AI candidate projection at RNG delta zero.

### Stage 5: production semantic projection cutover

- Compose semantic services once at runtime initialization.
- Authorize and clip at the owner/query port before projection.
- Use the same registered operation handlers for human play, AI play, replay resume, and training-authoritative execution.
- Do not compile per frame or per candidate.

### Stage 6: remove compatibility bridges

- Remove localized public card IDs, monster-name family fallback, duplicate weather aliases, duplicated static card payload, and legacy queue/child adapters only after fixture coverage proves every supported source version has migrated or is explicitly rejected.
- Preserve byte-identical backup/authorization rules for user files.

### Stage 7: claim gate

Only after all 19 owners are transactional, product-market and RNG continuation are present, cross-owner identities are stable, privacy/RNG/replay fixtures pass, and a real cold load continues deterministic execution may a later task reconsider full-run resume. This audit makes no such claim.

## Final audit assertions

```text
NEW_SEMANTIC_SAVE_SECTION_COUNT=0
SEMANTIC_COMPILER_RNG_DELTA=0
SEMANTIC_QUERY_RNG_DELTA=0
VIEWER_CLIPPING_BEFORE_AI_UI=REQUIRED_NOT_YET_PRODUCTION_COMPOSED
REPLAY_COMPATIBILITY=REQUIRES_VERSIONED_ADAPTERS
TRAINING_PRODUCTION_EXECUTION_ENGINE=SAME_CURRENT_PATH_AND_REQUIRED_FUTURE_PATH
FULL_RUN_RESUME_CLAIM=false
```
