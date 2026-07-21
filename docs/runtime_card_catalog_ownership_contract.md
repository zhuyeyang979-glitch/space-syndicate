# Runtime Card Catalog Ownership Contract - Sprint 58

## Status

The v0.4 runtime card catalog is fully Resource-backed. The authoritative owner
is `CardRuntimeCatalogService`, which references
`res://resources/cards/runtime/card_runtime_catalog_v04.tres`.

The catalog contains exactly:

- 232 authored card definitions
- 114 family Resources
- 232 embedded rank subresources
- 70 upgradeable families
- 118 ordered public-pool card ids
- 10 editorial pack Resources
- 49 validated effect kinds

`main.gd` is not a catalog owner and has no catalog fallback.

## Asset graph

- `resources/cards/runtime/families/`: one `.tres` per family
- `resources/cards/runtime/packs/`: ten ordered editorial packs
- `resources/cards/runtime/card_runtime_catalog_v04.tres`: catalog root
- `CardRuntimeCatalogService.tscn`: authoritative runtime API
- `CardRuntimeDefinitionWorldBridge.tscn`: source-precedence composition

Packs organize Inspector editing only. They do not sort card ids, alter the
public pool, or consume RNG. Every family belongs to exactly one pack.

## Definition order

`CardRuntimeDefinitionWorldBridge.resolve_definition()` applies this order:

1. City-development runtime cards.
2. Exact Runtime Catalog definitions.
3. Product Futures or City GDP terms from their dedicated catalogs.
4. Monster cards and bound techniques from the Monster definition owner.
5. Runtime Catalog derived-rank lookup.

`CardPlayRequirementPolicy` runs after definition resolution. It is not stored
inside card Resources.

## Derivation contract

- An exact id always wins.
- A missing I-IV rank searches downward for the nearest authored rank.
- Derived ranks retain the established 35% growth policy.
- Integer, signed integer, float, multiplier, and turn fields retain their
  distinct rounding/growth behavior.
- Derived definitions are transient pure data and are never saved as extra
  `.tres` files.

## Sparse shape and validation

Each authored rank stores `authored_keys`. `to_dictionary()` emits only keys
that existed in the legacy definition, including the original int/float shape
for `move` and `range`. `effect_parameters` may contain only pure data.

The kind schema rejects missing required fields, unexpected fields, runtime
state, non-data values, and duplicated financial terms. Catalog, definition,
validation, and debug APIs return deep-copied pure data.

## External owners

The Runtime Card Catalog deliberately does not own:

- Product Futures terms
- City GDP Derivative terms
- city-development generated cards
- Monster cards or bound techniques
- CardPlayRequirementPolicy
- card instances, cooldowns, locks, queue state, targets, ownership, or saves

Compendium/CardCodex Resources remain presentation assets and are never a
gameplay fallback.

## Consumer contract

| Consumer | Catalog route |
| --- | --- |
| `main.gd` | `GameRuntimeCoordinator.card_definition()` |
| Eligibility / Queue / Execution | Pure definition supplied by the caller |
| Presentation / CardCodex | Sanitized pure definition plus external terms |
| AI | Injected `CardRuntimeDefinitionWorldBridge` |
| Military | Injected `CardRuntimeCatalogService` |
| Monster / Weather / Contract | Static definition input; domain state remains local |
| First Table / Scenario | Stable card-id existence lookup |
| District Supply | Ordered `public_pool()`; existing shared RNG order |

## Deleted legacy ownership

Sprint 58 removed from `main.gd`:

- `SKILL_CATALOG`
- `UPGRADEABLE_SKILL_FAMILIES`
- `COMMON_CARD_POOL`
- `_skill_exists()`
- `_skill_definition()`
- `_derived_rank_skill_definition()`
- `_skill_rank()`
- `_skill_family()`

`_make_skill()` remains only as a short card-instance assembler: it resolves a
definition through the Coordinator, applies requirement policy, and initializes
cooldown/lock state.

## Integrity gate

`RuntimeCardCatalogResourceBench` retains the forty Sprint 57 historical cases
and adds forty live-cutover cases. It verifies all 232 active canonical hashes, all
counts, three ordered hashes, derived growth, external sources, consumer
composition, privacy, save ids, deterministic pool order, and legacy deletion.
The required gate is 80/80.

## Sprint 59 authoring workflow

Card creation and modification now use the custom Godot Inspector panel and
`RuntimeCardAuthoringWorkspace.tscn`. `CardRuntimeAuthoringValidator` validates
Catalog, Pack, Family, and Rank Resources without mutation. The change-review
service compares current canonical hashes with the Sprint 58 integrity fixture
and can add field-level diffs from a working baseline stored only under
`user://`.

These tools are editor-only. They are not composed into `main.tscn` or
`GameRuntimeCoordinator.tscn`, and they do not become a second catalog source.
The runtime owner remains `CardRuntimeCatalogService`. The Sprint 59 workflow
gate is 36/36 and must be followed by this contract's 80/80 runtime gate.
