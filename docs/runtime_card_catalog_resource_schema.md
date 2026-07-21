# Runtime Card Catalog Resource Schema Lock

## Decision

Sprint 58 should use family files with embedded rank Resources, grouped by
ordered category packs. It should not create 230 independent rank files and it
should not store the entire catalog in one untyped Dictionary.

Recommended production asset count:

- 113 `CardRuntimeFamilyResource` `.tres` files
- 230 embedded `CardRuntimeRankResource` subresources
- 10 ordered `CardRuntimePackResource` `.tres` files
- 1 `CardRuntimeCatalogResource` `.tres` file

The expected 124 tracked `.tres` files keep one human-editable file per family
without producing a separate file for every rank.

## Resource types

### CardRuntimeRankResource

Typed Inspector fields:

- `rank: int`
- `kind: StringName`
- `purchase_cost: int`
- `rules_text: String`
- `tags: PackedStringArray`
- `move`, `range`, `damage`
- `persistent`, `consumed_on_queue`
- optional target/requirement declaration Resource references
- `effect_parameters: Dictionary`

`effect_parameters` is intentionally heterogeneous, but must contain only
Dictionary, Array, String, Number, Bool, and null values. Each `kind` receives
a validator listing its permitted and required effect fields.

### CardRuntimeFamilyResource

- `family_id`
- category/pack id
- ordered authored ranks
- `derivation_enabled`
- derivation policy id
- public-pool eligibility
- upgradeable-family membership

The family Resource owns the nearest-lower-rank lookup. Sprint 58 must preserve
the existing source-rank search and 35% derivation policy exactly.

### CardRuntimePackResource

Recommended ordered packs:

1. city economy
2. product and logistics
3. finance
4. contracts
5. intel and counter
6. player interaction
7. military
8. weather and news
9. monster actions
10. special cross-system cards

Each family appears in exactly one pack. Pack order is explicit and is not
derived from filesystem enumeration.

### CardRuntimeCatalogResource

- ordered pack references
- exact `COMMON_CARD_POOL` card-id order
- exact `UPGRADEABLE_SKILL_FAMILIES` order
- lookup by card id and family/rank
- `definition(card_id) -> Dictionary`
- `has_card(card_id) -> bool`
- `family_id(card_id) -> String`
- `rank(card_id) -> int`
- `public_pool() -> Array`
- `validation_report() -> Dictionary`

All returned values are deep-copied pure data. A Resource, Node, Callable, or
Object must never appear in gameplay, UI, debug, save, manifest, or report
snapshots.

## Typed versus extensible fields

Typed core fields cover stable identity, purchase, presentation-neutral rules
text, ordering, queue-consumption, and common geometry/damage inputs.

Typed declaration groups cover:

- GDP/local-share/product prerequisites
- target kind and required target state
- duration/cooldown/lock declarations that belong to the card
- contract, weather, military, and response-window descriptors

The extension Dictionary is reserved for effect-family parameters such as
market pressure, military stats, route damage, contract deltas, hand counts,
or weather zone counts. It never stores runtime state.

## External references

Financial cards use card id to request their independent Terms Catalog entry.
The card snapshot can carry the resulting nested pure-data terms at runtime,
but the terms are not serialized into Card Runtime Resources.

Compendium entries may reference the card id for public display. They remain
presentation-only and cannot override runtime definitions.

## Validation requirements for Sprint 58

- 230 explicit definitions reproduce the current Dictionary shape.
- 113 families and all I-IV derived results match byte-for-byte after canonical
  key sorting.
- 70 upgradeable families and 116 public-pool ids preserve exact order.
- all 48 effect kinds pass a kind-specific field validator.
- all consumers receive the same pure-data snapshot.
- save card names and privacy boundaries remain unchanged.
- Resource load failure is explicit; there is no `main.gd` fallback.

## Inspector authoring contract

Sprint 59 adds a custom `EditorInspectorPlugin` for
`CardRuntimeCatalogResource`, `CardRuntimePackResource`,
`CardRuntimeFamilyResource`, and `CardRuntimeRankResource`. The Inspector panel
can validate the selected target, capture a user-scoped working baseline,
build a change review, run authoring QA, open the root catalog, and open the QA
output directory.

The authoring validator treats `authored_keys` as the exact serialized shape.
New effect parameters must be present in the selected kind's `allowed` schema;
new mandatory parameters must also be listed in `required`. Financial term
fields stay in their dedicated terms catalogs. Runtime state and Object values
are rejected.

The full workflow and review policy are documented in
`docs/runtime_card_authoring_workflow.md`.
