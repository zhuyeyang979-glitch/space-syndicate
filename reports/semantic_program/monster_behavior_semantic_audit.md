# Monster Behavior Semantic Audit

## Audit identity

- Baseline: `5a4fadb5e76ee6c1e5be50a2529ea64dfea63537`
- Branch: `codex/semantic-program-wave1-monster-5a4fadb`
- Worktree: isolated from the current integration state.
- Scope: monster catalogs, behavior tables, live runtime ownership, targeting, movement, combat, RNG, AI observations, Codex/presentation, diagnostics, save identity, and the v0.6 unit-card capability boundary.
- Production, tests, catalogs, rules, balance, RNG, save, scenes, and unrelated reports changed: none.
- Owned outputs: this report and `reports/semantic_program/monster_behavior_semantic_audit.json` only.

## Verdict

`MonsterRuntimeController` is the legitimate and only mutable monster-state owner. It must remain the owner of live instances, movement, damage, battle/wager lifecycle, card transaction journals, save state, and rollback. The defect is not the existence of those domain state machines. The defect is that immutable family semantics, localized identity, action definitions, weight policies, presentation facts, diagnostics, and private AI reads are mixed into or routed around that owner.

The highest-risk findings are:

1. localized Chinese display names still select family identity, passives, action tables, and behavior weights;
2. legacy-created actors omit `monster_family_id`, while save validation accepts that omission and only enforces same-family uniqueness for explicit IDs;
3. AI has a direct read/write proxy to `auto_monsters` and uses hidden `owner` truth when choosing cards, lures, delays, military targets, and wager sides;
4. autonomous commands carry a raw action dictionary and an array index instead of a stable behavior-action ID;
5. the live v0.4 card catalog and Main-generated monster definitions remain parallel sources beside 32 v0.6 monster cards;
6. the real monster owner now has prepare/commit/rollback/finalize and exact-once machinery, but the semantic card route remains correctly `projection_only` because rank II-IV profile authority and registered semantic operation dispatch are absent.

This audit records **41 grouped findings**: **10 REMOVE**, **19 MOVE**, and **12 KEEP**. `KEEP` identifies a legitimate state machine, owner, privacy boundary, presentation renderer, or typed transaction mechanism. It does not authorize localized text or raw dictionaries as future semantic identity.

## Deterministic inventory

| Measure | Result |
| --- | ---: |
| `MonsterRuntimeController` physical lines | 7,042 |
| `MonsterRuntimeController` methods | 368 |
| `MonsterRuntimeController` top-level constants | 65 |
| `MonsterRuntimeController` top-level variables | 45 |
| `MonsterCatalogV06` physical lines / static methods | 473 / 22 |
| Roster families in `MonsterCatalogV06` | 8 |
| Name-keyed art profiles | 8 |
| Name-keyed behavior action rows | 48 |
| Unique action dictionary fields | 23 |
| Name-keyed behavior-weight rows | 9: eight roster families plus `腕环哨兵` |
| Stable family IDs already present in weather traits | 8 |
| v0.6 monster card records | 32: eight families x four ranks |
| v0.6 monster card runtime readiness | 32 `projection_only` |
| Initial legacy actor fields | 38 |
| Initial atomic-created actor fields | 43 |
| Production files consuming `MonsterCatalogV06` directly | 9 (10 references including the catalog definition itself) |
| AI `auto_monsters` lexical lines | 23 |
| AI functions reading live `auto_monsters` | 12, plus one read/write property proxy |
| Distinct monster fields read by those AI paths | 9 |
| Direct AI `owner` truth read sites | 7 |
| Localized behavior predicates in the live owner | 7 behavior predicates plus 1 legacy same-name identity predicate |
| Public Compendium active-roster entries | 8, plus 3 standalone fictional sample entries |
| Runtime RNG draw sites in the monster path | 8 sites across 8 policies |
| Focused tests run | 8: five pass, three known fixture/oracle failures |

### Action payload inventory

All 48 action rows contain `name`, `range`, `damage`, `move_override`, and `text`. Optional fields are currently interpreted independently by runtime, Codex, diagnostics, and presentation.

| Field | Rows | Semantic destination |
| --- | ---: | --- |
| `name`, `range`, `damage`, `move_override`, `text` | 48 each | localization ref, target/range spec, ordered operations, player projection |
| `knockback` | 18 | `knockback_unit` |
| `stun` | 9 | `apply_status(status_id=stun)` |
| `cripple` | 6 | `apply_status(status_id=cripple)` |
| `miasma_count` | 4 | `spawn_miasma` |
| `paralyze` | 4 | `apply_status(status_id=paralyze)` |
| `tether` | 4 | `apply_status(status_id=tether)` |
| `chaos_ray` | 4 | explicit path-damage operation and presentation cue |
| `close_range`, `close_damage` | 3 each | range-conditioned damage branch inside one execution plan |
| `throw_radius` | 2 | `throw_unit` |
| `self_heal` | 2 | `heal_self` |
| `armor`, `delay`, `repair`, `repair_path`, `repair_radius`, `self_damage`, `stun_if_tethered` | 1 each | explicit operation or condition; unknown fields fail closed |

## Current authority map

| Concern | Current source | Finding | Required owner boundary |
| --- | --- | --- | --- |
| Family roster and base stats | `scripts/runtime/monster_catalog_v06.gd:9-120` | Closest thing to formal monster authority, but no stable IDs in each row. | Immutable `MonsterSemanticSpec` catalog keyed by the existing eight ASCII family IDs. |
| Art identity | `scripts/runtime/monster_catalog_v06.gd:122-211`; `data/art/monster_body_art_manifest.json:1-112` | Two name-keyed presentation sources. | Presentation refs inside `MonsterSemanticSpec`; licensing manifest remains art QA input, not rules. |
| Behavior actions | `scripts/runtime/monster_catalog_v06.gd:213-278` | 48 localized-name-keyed raw dictionaries. | Immutable `MonsterBehaviorSpec` keyed by stable behavior and action IDs. |
| Action weights and rank transform | `scripts/runtime/monster_runtime_controller.gd:259-269`; `scripts/runtime/monster_catalog_v06.gd:367-419` | Weight authority is split and keyed by display name. | `MonsterBehaviorSpec.weight_profiles` and a versioned rank transform. |
| Live instances | `scripts/runtime/monster_runtime_controller.gd:74-100` | Correct unique mutable authority. | Keep in `MonsterRuntimeController`; instances reference specs by ID only. |
| v0.6 card family/rank identity | `data/cards/card_runtime_catalog_v06.json:19909-22423` | 32 stable card records and eight stable family IDs exist. | Card compiler references `MonsterSemanticSpec`; it never reconstructs a profile from player text. |
| Weather affinities | `resources/monsters/monster_family_weather_traits_v1.tres:7-16` | Correct stable IDs, but separate static authority. | Absorb unchanged tags into each family spec after parity; no runtime/save change. |
| Codex | `scripts/runtime/monster_runtime_controller.gd:807-1135` | Live owner reconstructs player-facing facts, tags, and probabilities. | `MonsterSemanticSpec -> MonsterCodexDTO`; leaf UI remains formatting-only. |
| AI threat facts | `scripts/runtime/ai_runtime_controller.gd:839-844` and 12 consumer functions | AI bypasses a viewer boundary and can mutate the roster. | `AiObservationSnapshot -> AiMonsterThreatProjection`; own private association only through actor-scoped facts. |
| Save | `scripts/runtime/monster_runtime_controller.gd:1461-1507`, `:2298-2474` | Correct owner/envelope, but legacy actor identity is optional. | Keep save owner and shape; normalize legacy family identity from stable catalog index without changing RNG or envelope. |

## REMOVE findings

| ID | Category | Exact evidence | Why remove | Replacement |
| --- | --- | --- | --- | --- |
| MB-001 | Localized family identity | `scripts/runtime/monster_runtime_controller.gd:24-33`, `:3098-3102` | Missing family identity falls back through a Chinese-name map. Renaming/localization can change upgrade and weather behavior. | Require `family_id`; a load compatibility map uses stable legacy catalog index, never display text. |
| MB-002 | Localized behavior branch | `scripts/runtime/monster_runtime_controller.gd:3651`, `:3785`, `:3809`, `:3832`, `:3838`, `:4313`, `:4861` | Seven display-name predicates control revival, threshold passives, alternate actions, reflection state, and path miasma. | Stable passive trigger/action IDs in `MonsterBehaviorSpec`, dispatched by registered operations. |
| MB-003 | Name-keyed weight authority | `scripts/runtime/monster_runtime_controller.gd:259-269`, `:990-1001`, `:4317-4328`; `scripts/runtime/monster_catalog_v06.gd:375-387` | Nine display-name rows are a second behavior catalog and are interpreted twice. | One stable-ID `weight_profiles` map compiled once. |
| MB-004 | Name/suffix rule parser | `scripts/cards/card_runtime_catalog_resource.gd:59-75`; `scripts/runtime/monster_catalog_v06.gd:328-347`; `scripts/main.gd:4195-4253`, `:4260-4310`; `scripts/runtime/monster_runtime_controller.gd:3907-4073` | `怪兽·<Chinese name><rank>` and `兽技·...` strings define family, rank, action, upgrade target, and bound skill. | Explicit card ID, family ID, rank, behavior action ID, and compiled unit profile. |
| MB-005 | Silent semantic fallback | `scripts/runtime/monster_catalog_v06.gd:350-355` | An unknown catalog/action lookup silently receives the `孢雾海皇` action table. | Unknown family/action fails closed during compilation and lookup. |
| MB-006 | Parallel runtime definitions | `scenes/runtime/CardRuntimeCatalogService.tscn:3-9`; `scripts/runtime/card_runtime_catalog_service.gd:11-21`; `scripts/runtime/card_runtime_definition_world_bridge.gd:31-43`, `:77-85`; `scripts/runtime/game_runtime_coordinator.gd:515`; `scripts/runtime/monster_runtime_controller.gd:303-307` | The active v0.4 catalog, Main-generated monster definitions, derived catalog entries, and v0.6 data can all answer “what is this card/monster?”. | One compiled semantic catalog; keep compatibility only at load/migration boundaries. |
| MB-007 | Main profile authority | `scripts/main.gd:591-624`, `:627-656` | Rank I is reconstructed by reading v0.6 player display text and mapping the Chinese name back into the monster catalog; rank II-IV are rejected and cross-owner patches are no-op. | Family/rank profile from `MonsterSemanticSpec`; real participant plans use stable operations. |
| MB-008 | AI owner bypass | `scripts/runtime/ai_runtime_controller.gd:35`, `:92-93`, `:803-806`, `:839-844` | AI can invoke arbitrary monster methods and directly read or replace `auto_monsters`. | A typed, read-only, viewer-scoped monster observation port. |
| MB-009 | Hidden-owner AI scoring | `scripts/runtime/ai_runtime_controller.gd:6463-6501`, `:6570-6602`, `:6634-6649`, `:7718-7768`, `:9398-9434` | Seven direct `owner` reads influence card targets, lure/delay plans, military threat scoring, and wagers even when `owner_revealed` is false. | Public threat projection plus actor-private “is mine” association; no opponent owner truth. |
| MB-010 | Localized diagnostic classifier | `scripts/balance/combat_balance_model.gd:60-75` | Chinese substrings such as `冲锋`, `光线`, `投掷`, and `爆` choose knockback profiles. | Explicit diagnostic/presentation feature IDs from `MonsterBehaviorSpec`. |

## MOVE findings

| ID | Category | Exact evidence | Move to |
| --- | --- | --- | --- |
| MB-011 | Family definition | `scripts/runtime/monster_catalog_v06.gd:9-120` | `MonsterSemanticSpec` rows with stable family ID, rank stats, movement, summon, resource, behavior, visibility, and presentation refs. Preserve every value. |
| MB-012 | Behavior definitions | `scripts/runtime/monster_catalog_v06.gd:213-278` | `MonsterBehaviorSpec.actions`, each with stable action ID, target policy, ordered operations, and presentation cue IDs. |
| MB-013 | Art metadata | `scripts/runtime/monster_catalog_v06.gd:122-211`; `data/art/monster_body_art_manifest.json:1-112` | Stable family-keyed presentation profile. Keep asset/license QA metadata separate from rules. |
| MB-014 | Weight/rank policy | `scripts/runtime/monster_catalog_v06.gd:6-7`, `:367-419` | Versioned early/escalated distributions and the exact rank transform in `MonsterBehaviorSpec`. |
| MB-015 | Passive thresholds/actions | `scripts/runtime/monster_runtime_controller.gd:204-212`, `:250-257` | Trigger conditions and alternate action-set IDs in `MonsterBehaviorSpec`; runtime flags remain in instance state. |
| MB-016 | Target policy | `scripts/runtime/monster_runtime_controller.gd:232-248`, `:6224-6268` | Stable `target_policy_id` and weighted factor definitions. Candidate iteration and weighted selection remain runtime mechanisms. |
| MB-017 | Cross-domain semantic references | `scripts/runtime/monster_catalog_v06.gd:21-24`, `:35-38`, `:50-53`, `:63-66`, `:76-79`, `:89-92`, `:102-105`, `:115-118`; `scripts/runtime/monster_runtime_controller.gd:4398-4433` | Stable product/card IDs and ordered owner operations. Localized product/card names become projection output only. |
| MB-018 | Instance schema separation | Legacy constructor `scripts/runtime/monster_runtime_controller.gd:3609-3656`; atomic constructor `:3226-3284` | Explicit `MonsterInstanceState`; it references immutable specs and owns only live/revision/private state. The current 38/43-field values remain unchanged during the bridge. |
| MB-019 | Save identity migration | `scripts/runtime/monster_runtime_controller.gd:2298-2324`, `:3098-3109` | Load-time normalization from explicit family ID or stable catalog-index map. Preserve the current save section and root envelope; reject ambiguous identity. |
| MB-020 | Command identity | `scripts/runtime/monster_runtime_controller.gd:4599-4611`, `:4618-4639`; `scripts/runtime/monster_action_command_sink.gd:68-76` | Stable `behavior_action_id`, semantic fingerprint, target identity, and resolved operation plan. Do not serialize a mutable localized action dictionary as authority. |
| MB-021 | RNG declaration | `scripts/runtime/monster_runtime_controller.gd:479-488`, `:3792`, `:4591`, `:4997`, `:5511`, `:6182`, `:6352`, `:6709-6710`; `scripts/main.gd:4915-4918`, `:4929-4939` | `MonsterBehaviorSpec.randomness_policy` plus a typed `RunRngService` port. Preserve each conditional draw, range, and exact order. |
| MB-022 | Codex semantic derivation | `scripts/runtime/monster_runtime_controller.gd:883-1135`, especially `:990-1005`, `:1069-1094`, `:1112-1122` | `MonsterSemanticSpec -> MonsterCodexDTO`. Player projection receives public action facts and localized labels; it never recomputes rules. |
| MB-023 | Diagnostic reinterpretation | `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:181-223`; `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:1026-1050` | Standard immutable semantic diagnostic projection. Diagnostics calculate metrics from normalized operations/features, not raw action dictionaries. |
| MB-024 | Presentation cue inference | `scripts/main.gd:4558-4622` | Stable `presentation_cue_id` and animation profile refs emitted by the player/rule projection. |
| MB-025 | Weather affinities | `resources/monsters/monster_family_weather_traits_v1.tres:7-16`; `scripts/runtime/monster_runtime_controller.gd:3105-3173` | Copy the existing eight stable-ID tag sets into family specs after byte-for-byte parity. Keep weather resolution and save behavior unchanged. |
| MB-026 | AI public threat projection | `scripts/runtime/ai_runtime_controller.gd:2078-2094`, `:5327-5349`, `:7718-7768` | `AiObservationSnapshot -> AiMonsterThreatProjection` with public HP/rank/position/down/threat features and viewer-authorized ownership only. |
| MB-027 | Viewer-scoped roster API | `scripts/runtime/monster_runtime_controller.gd:781-789`, `:1219-1223`, `:1652-1695` | Explicit `public_roster(viewer)` and `private_owned_monsters(actor_id)` typed queries; remove boolean default-to-private APIs after consumers migrate. |
| MB-028 | Unit-card semantic profile | `scripts/runtime/monster_runtime_controller.gd:1759-1801`, `:1840-2120`, `:2151-2177`; `tests/card_semantic_schema_compiler_test.gd:114-125` | Compile family/rank profile and owner subplans from semantic specs, then activate only after rank I-IV and participant parity. Keep current transactions. |
| MB-029 | Compendium fixtures | `resources/compendium/monsters/active_roster_pack.tres:7-179`; standalone samples `resources/compendium/monsters/mirror_manta.tres:7-24`, `orbit_crusher.tres:7-24`, `phase_leviathan.tres:7-24` | Generated/golden `MonsterCodexDTO` fixtures. The current active-roster resource explicitly says gameplay rules live elsewhere but contains conflicting placeholder stats and probabilities. |

## KEEP findings

| ID | Legitimate boundary | Exact evidence | Keep rule |
| --- | --- | --- | --- |
| MB-030 | Unique live owner | `scripts/runtime/monster_runtime_controller.gd:74-100`, `:338-358`, `:1461-1507` | Keep one mutable roster, wager state, timers, revisions, journals, and save owner. Do not create a second monster runtime. |
| MB-031 | Movement state machine | `scripts/runtime/monster_runtime_controller.gd:462-488`, `:600-738`, `:4782-4950`; `scripts/runtime/monster_move_command_sink.gd:21-72` | Keep linear motion, arrival effects, audit snapshots, and exact-once command sink. Operations call these handlers. |
| MB-032 | Combat/damage state machine | `scripts/runtime/monster_runtime_controller.gd:6018-6165`, `:6174-6195`; `scripts/runtime/military_monster_damage_command_sink.gd:21-68` | Keep range checks, armor order, damage, down/revival transition, knockback, and mutation audit. |
| MB-033 | Target-selection mechanism | `scripts/runtime/monster_runtime_controller.gd:6321-6359` | Keep candidate enumeration and one weighted draw. Move only factor definitions and visibility into specs/projections. |
| MB-034 | Wager/battle lifecycle | `scripts/runtime/monster_runtime_controller.gd:1256-1293`, `:5485-5569`, `:5707-6016`; `scripts/runtime/monster_battle_lifecycle_policy_v06.gd:1-143` | Keep the domain lifecycle and typed receipts; semantic operations may open it but do not replace it. |
| MB-035 | Atomic unit-card transaction | `scripts/runtime/monster_runtime_controller.gd:1840-2120`, `:3212-3341`, `:3377-3545` | Keep prepare/commit/rollback/finalize, revisions, postimages, fingerprints, participant binding, and exact-once journals. |
| MB-036 | Save owner/envelope | `scripts/runtime/monster_runtime_controller.gd:1461-1507`, `:2298-2474` | Keep the existing monster save section and envelope shape. Add compatibility normalization inside the owner; do not add a second save owner. |
| MB-037 | Privacy sanitizers | `scripts/runtime/monster_runtime_controller.gd:3187-3199`; `scripts/runtime/monster_codex_public_source_adapter.gd:5-68`, `:94-112` | Keep allowlist/sanitization. Make it the mandatory route for public and AI projections instead of an optional caller choice. |
| MB-038 | Actor-scoped wager/private facts | `scripts/runtime/monster_runtime_controller.gd:1256-1293`, `:1652-1695` | Keep own-bet/own-cash and owned-monster private views; never return rival owner truth. |
| MB-039 | Shared RNG authority and order | `scripts/runtime/monster_runtime_world_bridge.gd:30`, `:43-44`, `:110-111`; `scripts/runtime/monster_runtime_controller.gd:174-176` | `RunRngService` remains the only RNG owner. Specs declare policy but never own or consume RNG. |
| MB-040 | Typed mutation pipeline | `scripts/runtime/monster_runtime_controller.gd:741-758`; `scripts/runtime/monster_action_command_sink.gd:21-90`; `scripts/runtime/monster_move_command_sink.gd:21-72` | Keep authorization, command IDs, exact-once caches, before/after snapshots, and mutation audit. Add stable operation/action identity to envelopes. |
| MB-041 | Presentation-only renderers | `scripts/runtime/monster_codex_public_snapshot_service.gd:13-86`; `scripts/ui/codex/bestiary_monster_action_card.gd:12-35`; `scripts/monster_art_view.gd:74-90`, `:156-174` | Keep detached DTO formatting and stable motif rendering. These leaves do not calculate weights or execute rules; their future input must be a typed `MonsterCodexDTO`. |

## Proposed semantic contracts

### `MonsterSemanticSpec`

Pure, immutable data compiled once at catalog initialization:

```text
schema_version: int
spec_id: stable ASCII ID
family_id: stable ASCII ID
source_catalog_id: stable ASCII ID
localization_key: stable ASCII ID
rank_profiles: {
  1..4: {
    hp, armor, move_mps, move_damage, collision_damage,
    resource_drain, presence_seconds
  }
}
movement_profile: {
  movement_mode_id, movement_trait_ids, terrain_multipliers,
  path_damage_policy_id, encounter_range_m
}
summon_policy: {
  access_policy_id, allowed_terrain_ids, control_cap_policy_id
}
resource_affinity_ids: [stable product IDs]
economy_operation_ids: [stable operation IDs]
weather_affinity_tag_ids: [stable tag IDs]
behavior_spec_id: stable ASCII ID
passive_trigger_ids: [stable ASCII IDs]
visibility_policy_id: stable ASCII ID
randomness_policy_ids: [stable ASCII IDs]
presentation_profile_id: stable ASCII ID
art_asset_refs: [stable asset IDs]
```

Forbidden: localized display names as keys, `Node`, `Object`, `Callable`, live owner references, RNG objects/state, mutable actor dictionaries, save payloads, and AI scores.

### `MonsterBehaviorSpec`

```text
schema_version: int
behavior_spec_id: stable ASCII ID
family_id: stable ASCII ID
actions: [
  {
    behavior_action_id: stable ASCII ID,
    localization_key: stable ASCII ID,
    target_policy_id: stable ASCII ID,
    trigger_condition_ids: [stable ASCII IDs],
    ordered_operations: [{operation_id, parameters, condition_ids}],
    presentation_cue_ids: [stable ASCII IDs],
    diagnostic_feature_ids: [stable ASCII IDs]
  }
]
weight_profiles: {
  early: {behavior_action_id: nonnegative int},
  escalated: {behavior_action_id: nonnegative int}
}
rank_weight_transform: {
  policy_id, exact integer parameters
}
target_weight_policy: {
  policy_id, ordered factor definitions
}
randomness_policies: [
  {policy_id, rng_owner_id, draw_kind, draw_range, conditionality, order_key}
]
visibility_policy: {
  public_fields, actor_private_fields, developer_only_fields
}
```

The compiler must validate unique family/action IDs, every operation and condition against an allowlist, all required/forbidden parameters, exact weight/action coverage, and every randomness declaration. Unknown IDs fail closed.

### `MonsterInstanceState`

Dynamic state remains separate and owned by `MonsterRuntimeController`:

- identity/reference: `uid`, `family_id`, `behavior_spec_id`, `rank`, `actor_revision`;
- location/motion: region, world position, current linear-motion state;
- lifecycle: HP, armor, guard, statuses, down, presence time, revive timer;
- private association: owner actor ID, owner reveal state, actor-private clue/cash meter;
- transaction state: owner revision, reservations, terminal/presentation journals;
- battle/wager state remains in the owner's existing lifecycle collections.

Static HP curves, action dictionaries, art, localized names, weights, and AI scores never live in the instance.

## Stable operation registry

The registry maps stable operation IDs to existing domain handlers. It does not own state and does not replace legitimate state machines.

| Operation ID | Existing behavior to preserve |
| --- | --- |
| `select_weighted_region_target` | Candidate/weight loop and one draw at `monster_runtime_controller.gd:6328-6359` |
| `select_weighted_behavior_action` | Action distribution and one draw at `:4588-4596` |
| `move_linear` | Existing linear motion/arrival state machine |
| `damage_region` | Current region damage owner call and ordering |
| `damage_path_regions` | Current bounded path traversal and per-region ordering |
| `damage_unit` | `_auto_monster_take_damage`, including weather armor then consumable armor |
| `knockback_unit` | Existing linear knockback; angle draw only for coincident positions |
| `throw_unit` | Existing throw/landing path |
| `apply_status` | Explicit `status_id` for stun, paralyze, cripple, or tether |
| `spawn_miasma` | Existing placement limits/order |
| `reclaim_miasma` | Existing reclaim/heal behavior |
| `repair_region` | Existing region-infrastructure repair owner |
| `repair_regions_in_radius` | Existing radius order and bounds |
| `repair_path_regions` | Existing path repair order |
| `gain_armor` | Existing mutable actor armor update |
| `heal_self` | Existing max-HP clamp |
| `damage_self` | Existing self-damage after primary resolution |
| `delay_next_action` | Existing special-action timer mutation |
| `drain_region_resources` | Existing product/demand drain order |
| `open_monster_wager` | Existing wager lifecycle owner |
| `revive_after_random_delay` | Existing 1..6 draw x 4 seconds and lifecycle transition |
| `activate_threshold_passive` | Stable passive ID plus HP/status condition |
| `reflect_ranged_damage` | Existing low-damage ranged reflection order |
| `deploy_unit` | Existing atomic roster postimage path |
| `upgrade_same_family_unit` | Existing revisioned same-family upgrade path |
| `extend_presence` | Existing additive remaining-time policy |

No handler is selected by localized name, tooltip, color, or arbitrary method-name string. A missing handler or invalid parameter rejects before mutation.

## Visibility policy

| Scope | Allowed | Forbidden |
| --- | --- | --- |
| Public player/Codex | public family/name projection, rank, HP/max HP, armor if public, position, down state, public movement/action facts, disclosed owner clue | true owner, owner actor ID, unrevealed ownership, owner cash pools, lure source/target, exact target weights, RNG state/ticket, AI plans |
| Acting player private | public facts plus own association, own starter state, own bound units, own wager bet/opening cash | rival hidden owner, rival exact cash, rival private card/plan data |
| AI observation | exactly the same viewer-authorized public/private facts as a human at that seat | direct controller, mutable roster, arbitrary method call, hidden opponent owner, raw save data |
| Developer diagnostics | immutable semantic specs and explicitly gated developer snapshots | using developer truth in production AI scoring |

The current public sanitizer is useful, but the boolean APIs default to private (`roster_snapshot(true)` and `selected_actor_snapshot(true)`). Migration must make viewer context explicit and fail closed when absent.

## Randomness contract

`RunRngService` remains the only RNG authority. Semantic specs describe when a draw occurs; they do not consume or store RNG. Migration must preserve draw count, conditionality, ranges, and call order exactly.

| Order/policy ID | Current evidence | Exact contract |
| --- | --- | --- |
| `monster.timer.normal` | `monster_runtime_controller.gd:483-485`; `main.gd:4915-4918` | After normal monster tick, one float draw in the frozen `[monster_min, monster_max]` interval. |
| `monster.timer.special` | `monster_runtime_controller.gd:486-488`; `main.gd:4915-4918` | After special tick, one float draw in `[special_monster_min, special_monster_max]`. Normal timer path runs first when both expire. |
| `monster.revival_delay` | `monster_runtime_controller.gd:3785-3793` | Only when the stable revival passive is eligible: one integer draw `1..6`, multiplied by 4 seconds. |
| `monster.action_weighted_choice` | `monster_runtime_controller.gd:4588-4596`; `main.gd:4929-4939` | One integer ticket `1..sum(weights)`; action draw occurs before region-target draw. |
| `monster.region_weighted_choice` | `monster_runtime_controller.gd:6338-6359` | One integer ticket after candidate weights and weather modifiers are frozen. |
| `monster.brawl_action_weighted_choice` | `monster_runtime_controller.gd:4968-4998` | One integer ticket only when at least one in-range damaging action exists. |
| `monster.wager_base_percent` | `monster_runtime_controller.gd:5485-5512` | One integer draw only after pair/decision eligibility and before participant cash snapshots. |
| `monster.coincident_knockback_angle` | `monster_runtime_controller.gd:6174-6183` | One float angle draw only when source/target offset length is at most `0.01`. |

Within a special action, the preserved order is: build action weights -> draw action -> build target weights -> draw target -> dispatch command. A registry cutover must not precompute both draws, query them from UI/AI, or retry a failed handler by drawing again.

## Save and replay identity

- `MonsterRuntimeController.to_save_data()` remains the authoritative monster save payload (`scripts/runtime/monster_runtime_controller.gd:1461-1482`).
- Legacy construction has 38 initial fields and no stable family/revision fields (`:3609-3656`). Atomic construction has 43 fields, adding `monster_family_id`, formal card ID, actor revision, owner actor ID, and profile revision (`:3226-3284`).
- Save validation accepts actors without `monster_family_id`; same-family uniqueness is checked only when the ID is explicit (`:2305-2324`).
- The current post-load behavior can recover family from Chinese name (`:3098-3102`), which must be replaced by an explicit legacy catalog-index map.
- Autonomous action commands and mutation audit currently persist/carry `action_index` plus the whole action dictionary (`:4599-4611`; `monster_action_command_sink.gd:68-76`). A replay-safe command needs `behavior_action_id`, semantic catalog fingerprint, actor revision, target identity, and operation-plan fingerprint.
- Stage one must not alter the save envelope or RNG. It may normalize an in-memory family ID from an unambiguous historical catalog index. An unknown/ambiguous index fails closed; it must never guess by localized name.

## Unit-card atomic capability

The owner is **not** wholly nontransactional. It implements:

- revisioned public/private snapshots and checkpoint gate;
- `prepare_unit_card_intent_v06`, `commit_unit_card_intent_v06`, `rollback_unit_card_intent_v06`, and `finalize_unit_card_intent_v06`;
- preimage/postimage fingerprints, participant binding, exact-once journals, and save/load state;
- rank-I starter/ordinary summon and same-family upgrade planning when authoritative inputs exist.

Evidence: `scripts/runtime/monster_runtime_controller.gd:1574-1613`, `:1840-2120`, `:2151-2177`, `:2810-3057`, `:3212-3545`.

The whole 32-card semantic route is still blocked because:

1. Main only provides a display-name-derived rank-I profile and explicitly rejects rank II-IV (`scripts/main.gd:591-624`);
2. non-empty bound-skill, economy, or role-cash patches fail closed in Main (`:627-656`);
3. no `MonsterSemanticSpec` owns rank I-IV profiles and behavior IDs;
4. no operation registry dispatches compiled monster operations;
5. all 32 v0.6 monster cards therefore remain correctly `projection_only` (`tests/card_semantic_schema_compiler_test.gd:114-125`).

Two older tests are stale or hybrid oracles, not proof that the production owner lacks transactions:

- `tests/unit_card_owner_capability_v06_test.gd:70-87` still asserts that the real owner has no prepare/commit/rollback/finalize capability; current run: 7 failures / 28 checks.
- `tests/monster_card_real_owner_integration_v06_test.gd:164-227` mixes former global capability and cross-actor same-family fixture expectations with the current per-profile participant readiness and global family constraint; current run: 9 failures / 31 checks. The same test correctly keeps missing rank profiles closed at `:231-269`.

Do not promote runtime readiness until semantic profile authority, per-intent participants, privacy, exact-once, and parity tests are green.

## Staged migration

1. **Freeze and compile.** Introduce immutable specs and compiler output from the current 8 roster rows, 48 actions, exact weights, thresholds, weather tags, and card IDs. Shadow-only; no runtime consumer changes.
2. **Projection cutover.** Generate Monster Codex and diagnostic projections from specs. Keep current UI leaf components, but remove their access to raw semantic dictionaries.
3. **Identity bridge.** Add explicit stable family/action IDs to newly built in-memory instances and commands. Normalize old actors from catalog index inside the existing save owner; preserve envelope and serialized compatibility.
4. **AI privacy cutover.** Replace direct controller/roster access with viewer-scoped observation and threat projection. Give an AI only public facts plus its own actor-private association.
5. **Registered operations in shadow parity.** Compile every action to an ordered operation plan and compare outcomes with the existing handlers without applying twice. Verify action/target RNG draw deltas and exact ordering.
6. **Execution cutover.** Route stable operation IDs to the existing movement, combat, wager, weather, region, product, and card transaction handlers. Keep all domain state machines and mutation authority.
7. **Unit-card activation.** Move rank I-IV profile authority out of Main, model required participant operations, pass fault injection/exact-once/privacy parity, then promote the 32 records deliberately.
8. **Legacy removal.** Remove name maps, suffix parsers, Main monster definition/profile fallback, v0.4 runtime authority, duplicate weight/Codex/diagnostic interpreters, and placeholder Compendium semantic fixtures only after save and replay compatibility gates pass.

Every stage must prove: no balance-value changes, no RNG draw/order changes, no save-envelope change, no hidden-owner leak, no second mutable monster owner, no new Main dependency, and no second training/simulation engine.

## Test evidence

All tests used the repository test wrapper with a 60-second bound. No long smoke or production edits were used.

| Test | Result | Duration | Evidence |
| --- | --- | ---: | --- |
| `monster_runtime_v06_privacy_test` | PASS 31/31 | 5.773s | Public/private roster and owner privacy characterization passes. |
| `monster_card_runtime_v06_test` | PASS 56/56 | 0.495s | Unit-card transaction adapter characterization passes. |
| `monster_cross_owner_upgrade_v06_test` | PASS 24/24 | 4.862s | Cross-owner upgrade and rollback characterization passes. |
| `monster_codex_public_source_service_test` | PASS 11/11 | 8.397s | Public source boundary passes. |
| `monster_codex_public_probability_contract_test` | PASS 9/9 | 7.552s | Public probability/hidden-weight contract passes. |
| `unit_card_owner_capability_v06_test` | FAIL 7/28 | 4.788s | Stale oracle still expects a nontransactional real owner; see unit-card section. |
| `monster_card_real_owner_integration_v06_test` | FAIL 9/31 | 5.446s | Hybrid capability oracle conflicts with current per-profile participant readiness; no script errors. |
| `monster_weather_integration_v1_test` | FAIL 33/84 | 5.173s | Stale fixture: bench binds only a fake world at `scripts/tools/monster_weather_integration_v1_bench.gd:160-180`. It omits `RunRngService`, so controller readiness fails (`scripts/runtime/weather_runtime_controller.gd:1005-1008`), and it omits `WorldSessionState`, so the bridge has no district facts (`scripts/runtime/weather_runtime_world_bridge.gd:20-25`, `:82-100`). The later array error at bench line 231 is cascade, not a monster-rule regression. |

## Blockers and risks

### Blockers

1. No immutable `MonsterSemanticSpec`/`MonsterBehaviorSpec` catalog currently owns all eight families and 48 actions by stable ID.
2. Legacy actor/save identity may lack `monster_family_id`; an explicit catalog-index compatibility contract is required.
3. Behavior actions have no stable action IDs, registered operation plans, or declared RNG policies.
4. AI can read hidden owner truth and mutate the live roster through its controller proxy.
5. Rank II-IV authoritative unit profiles and cross-owner operation plans are missing; 32 monster cards cannot be promoted from `projection_only`.
6. v0.4/Main-generated monster card definitions remain active parallel sources.
7. Three focused fixtures/oracles need separate modernization; this audit is not authorized to edit them.

### Migration risks

- **RNG drift:** moving target/action compilation into a different phase can add, remove, or reorder draws.
- **Save ambiguity:** name-based family recovery can silently bind an old actor to the wrong spec after localization.
- **Privacy leak:** an AI observation that contains `owner` even when unrevealed preserves the current exploit.
- **Double authority:** leaving `MonsterCatalogV06`, Main profile generation, Compendium placeholders, and new specs writable in parallel would be worse than the current state.
- **Transaction regression:** replacing existing owner postimages/journals with generic registry mutation would break exact-once and rollback.
- **Presentation/diagnostic drift:** Codex, UI, and balance tooling must consume projections from the same specs, not recreate optional-field heuristics.

## Required invariants for implementation

- `MonsterRuntimeController` remains the only mutable monster-state owner.
- The eight existing family IDs, 48 action results, all numeric values, target weights, rank transforms, and execution order remain unchanged.
- `RunRngService` remains the only RNG owner; draw count and order are byte-for-byte characterized.
- Save section count, save root/envelope, and existing role/card fields do not change in the semantic cutover.
- Hidden owner truth is removed from AI observations unless it is the acting seat's own authorized association or has been publicly revealed.
- Unknown family, action, condition, target, operation, or randomness policy fails closed before mutation.
- Rules, player presentation, AI, and diagnostics project from one immutable semantic source.
- The operation registry dispatches into existing domain owners; it never becomes a second runtime or generic state registry.
- Full unit-card execution remains blocked until rank I-IV profile and participant parity are proven; no fallback to Main is allowed.
