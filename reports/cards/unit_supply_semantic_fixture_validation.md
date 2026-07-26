# Unit and Supply Semantic Fixture Validation

Status: merge-ready for the owned fixture scope, with the baseline runtime risks recorded below.

## Scope

This Wave 2 fixture slice is based on
`a96c34f9d1a9f79fc20c4689b8d2ff82e22c623e` and changes only:

- `data/cards/semantic_templates/unit_supply_capability_templates_v1.json`
- `tests/fixtures/card_semantic_phase1/unit_supply_golden.json`
- `reports/cards/unit_supply_semantic_fixture_validation.md`

No production script, scene, catalog entry, balance value, or executable route was
changed. The golden set contains 16 exact card rows, six rule-backed
capability-only rows, and four family templates.

## Exact Golden Coverage

| Family and card IDs | Exact acquisition values by rank I-IV | Exact activation values by rank I-IV | Semantic result | Readiness |
| --- | --- | --- | --- | --- |
| `unit.monster.spore_tide_emperor.rank_1` through `rank_4` | cash `6, 10, 15, 21` | life `2, 4, 6, 9` | Ordered ops are `deploy_unit`, `upgrade_same_family_unit`, `extend_presence`, `heal_unit`; same-family presence gains exactly 60 seconds without refreshing total duration, and authored upgrades heal to full | `projection_only` |
| `unit.military.planetary_defense_force.rank_1` through `rank_4` | cash `6, 10, 15, 21` | industry `2, 4, 6, 9` | Ordered ops are exactly `deploy_unit`, `upgrade_same_family_unit`; `region_damage_requires_explicit_unit_action=true`, so the card emits no automatic region-damage op | `projection_only` |
| `supply_demand.remote_sea_order.rank_1` through `rank_4` | cash `5, 8, 12, 17` | shipping `2, 3, 5, 8` | `global_order_budget` values `20, 40, 80, 160` map to `modify_demand` and capability `global_order` | `active` |
| `supply_demand.near_land_supply.rank_1` through `rank_4` | cash `5, 8, 12, 17` | industry `2, 3, 5, 8` | `global_supply_spawn` values `20, 40, 80, 160` map to `modify_supply` and capability `global_supply_spawn` | `active` |

Each row preserves the complete selected catalog payload and exact card/family/rank
identity. Array order is significant, including effect-op order. Unknown fields,
missing invariants, and unsupported readiness states use `reject_projection` or
remain `projection_only`; no fallback semantics are invented.

## Runtime Authority

- The MCP-inspected `CardRuntimeCatalogV06Builder` and catalog resource expose 348
  cards in 87 families and match the pinned source digest.
- `MonsterRuntimeController` exposes the transaction-shaped methods, but its live
  capability report has `atomic_mutation_ready=false` with reason
  `monster_cross_owner_atomicity_unavailable`. Cross-owner participant/fact
  readiness is incomplete, so the fixture does not claim an executable card route.
- `MilitaryRuntimeController` has no `unit_card_runtime_capabilities_v06` surface,
  no prepare/commit/rollback/finalize/checkpoint card lifecycle, and no military
  card route in `GameRuntimeCoordinator`. Military cards therefore remain
  projection-only. Unit actions such as movement, guarding, and striking are not
  promoted into card effects.
- `CoreEconomicCardRuntimeAdapterV06` instantiates the global supply/demand owner
  and adapter, binds the atomic commodity-flow sink, and registers both global
  effect kinds in the core economic router. The two global families therefore use
  the active route claim `core_economic_card_runtime`.

The standalone global bench deliberately uses an injected atomic sink and prints
the existing diagnostic `production_batch_sink=BLOCKED`; the integrated adapter
wiring above is the authority for the active route classification. The diagnostic
is retained as a Supervisor-visible wording/risk note rather than rewritten in
this fixture-only branch.

## Capability-Only And Privacy Guarantees

The rule-backed rows are `military_move`, `military_guard`, `military_strike`,
`upgrade_same_family_unit`, `extend_presence`, and `heal_unit`. Every row has
`source_card_id=null`, `source_kind=rule_capability_only`, and
`executable_card_route_claimed=false`. They validate vocabulary and exact values;
they do not authorize execution.

Recursive privacy checks cover expected public/AI semantics and capability rows.
They reject actor/player identity, owner truth, runtime unit IDs or bindings,
hidden hands or route plans, AI scores/weights, and executable method/script/node
references. Card semantics use `authorized_source_only`; no live owner identity or
hidden unit binding is embedded in the fixtures.

## Fingerprints And Data Validation

Canonicalization recursively sorts dictionary keys, preserves array order, encodes
UTF-8 JSON, and emits lowercase SHA-256. Source-definition fingerprints cover
`source_catalog_id` plus the complete catalog `machine` object. Semantic
fingerprints cover the full semantic object while omitting only its own
`semantic_fingerprint` field.

| Check | Result |
| --- | --- |
| Catalog JSON SHA-256 | `b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40` |
| Template JSON SHA-256 | `47333916a9209eb9842eb61e0566e739a9c5bb51206f7682baf8e82746e29f91` |
| Golden JSON SHA-256 | `2b2a73e71112f3b1f905feb6cad700309b50d7b86ad98e9fd406c97acc2f99ad` |
| JSON parse | PASS, both owned JSON files |
| Catalog exact-subset comparison | PASS, 16/16 rows |
| Source-definition fingerprints | PASS, 16/16 rows |
| Semantic fingerprints | PASS, 16/16 rows |
| Shape/count gates | PASS, 16 cards / 6 capabilities / 4 templates |
| Recursive privacy scan | PASS |

## Godot MCP Evidence

The real isolated Role Supervisor endpoint was `127.0.0.1:8925`, running Godot
`4.7-stable (official)` against this exact worktree. No token or private endpoint
metadata is recorded.

| MCP target | Runtime or inspection result | Errors inspected | Stop result |
| --- | --- | --- | --- |
| `CardRuntimeCatalogV06Builder` plus `card_runtime_catalog_v06.tres` | Builder/catalog inspected; 348 cards, 87 families; selected rows matched the source JSON | No catalog/script error observed | Inspection only |
| `res://scenes/runtime/MonsterRuntimeController.tscn` | Live root `/root/MonsterRuntimeController`; capability report remained fail-closed for cross-owner atomicity | 0 scene/script runtime errors | `Stopped the running scene.`; final `is_playing_scene=false` |
| `res://scenes/runtime/MilitaryRuntimeController.tscn` | Live root `/root/MilitaryRuntimeController`; no card capability or atomic lifecycle surface was exposed | 0 scene/script runtime errors | `Stopped the running scene.`; final `is_playing_scene=false` |
| `res://scenes/tools/CardGlobalSupplyDemandV06Bench.tscn` | Live root `/root/CardGlobalSupplyDemandV06Bench`; `status=PASS`, 10 checks, 0 failures, two atomic batches | 0 bench/script failures; 3 environment-only `user://shader_cache` directory errors from the Vulkan renderer | `Stopped the running scene.`; final `is_playing_scene=false` |

The role editor then stopped normally: PID 16116 exited and port 8925 was closed.

## Focused Tests

| Test | Result |
| --- | --- |
| `CARD_RUNTIME_CATALOG_V06_TEST` | PASS, 2894/2894 |
| `MONSTER_CARD_RUNTIME_V06_TEST` | PASS, 56/56 |
| `MILITARY_CARD_RUNTIME_V06_TEST` | PASS, 49/49 |
| `CARD_GLOBAL_SUPPLY_DEMAND_V06_TEST` | PASS, 129/129 |
| `MONSTER_CROSS_OWNER_UPGRADE_V06_PASS` | PASS, 24/24 |
| `UNIT_CARD_OWNER_CAPABILITY_V06_TEST` | Baseline FAIL, 7 failures in 28 checks |
| `MONSTER_CARD_REAL_OWNER_INTEGRATION_V06_TEST` | Baseline FAIL, 9 failures in 31 checks |

The two failing tests exercise unchanged production ownership. Their expectations
are stale against the evolved monster capability/reason surface and current
cross-owner forwarding-port behavior. The two failing runs, and the passing
cross-owner run, each also emit six existing `Unexpected NUL character` parser
diagnostics. These failures support, rather than weaken, the fixture decision to
keep monster card semantics projection-only; this branch does not modify unowned
runtime code or tests.

## Risks And Merge Readiness

The three owned files are merge-ready as a fixture-only candidate. Consumers must
honor each row's readiness instead of promoting every catalog-available card to an
active route. In particular, monster and military remain projection-only, while
the two integrated global supply/demand families are active.

Residual risks are limited to the unchanged baseline owner tests, the standalone
bench's `production_batch_sink=BLOCKED` diagnostic wording, and the isolated
renderer shader-cache errors. Supervisor integration should retain those as
explicit follow-up evidence. No production behavior, balance, private authority,
or hidden unit binding is changed or claimed here.
