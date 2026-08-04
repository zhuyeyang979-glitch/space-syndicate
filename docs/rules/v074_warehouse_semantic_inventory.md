# V0.7.4 Warehouse Semantic Inventory

This inventory freezes the Lane B source audit. It does not make Lane B a
second world, Save, stock, or RNG owner.

## Authority result

Warehouse was omitted from the V0.7.2/V0.7.3 starter-oriented card definition
registry because that registry used the starter subset as its complete
`CARD_TYPES` list. The older production sources did not retire warehouse:
Region Infrastructure already recognized six colored warehouse slots, the card
catalog contained a four-rank generic warehouse family, Commodity Flow owned
private warehouse inventory, and the Commercial Art Catalog contained
`model.facility.warehouse.base`.

V0.7.4 separates these concepts:

- Complete registry: `factory`, `market`, `warehouse`.
- Starter subset: `factory`, `market`.
- Standard normal-track subset: `factory`, `market`, `warehouse`.
- Warehouse starter count: zero.

## Reused values

The capacity and base throughput values come from the existing rulebook,
Ruleset profile, and card authoring:

| Rank | Capacity | Ingress/min | Egress/min | Repair points | Asset cost |
| --- | ---: | ---: | ---: | ---: | ---: |
| I | 200 | 50 | 50 | 100 | 1 |
| II | 400 | 100 | 100 | 200 | 2 |
| III | 700 | 175 | 175 | 300 | 3 |
| IV | 1100 | 275 | 275 | 400 | 4 |

The first four columns are existing authoring values. The colored asset cost
1-4 and six industry-specific card identities are the current V0.7.4 user
decision. Historical V0.6 cash prices, storage rent, and automatic merge are
not restored.

## Runtime boundary

`V074FacilityRuntimeCore` is a detached, pure transition policy compatible
with the V0.7.3 contention call surface. It has no durable world state. The
shared Region Infrastructure/Facility Owner remains the required writer.

Warehouse state includes facility/slot generation, owner, rank, damage,
capacity, base throughput, effective throughput, and solar state. Sunlit
multiplies ingress and egress by 2.0; dark uses 1.0. Capacity, rank, damage,
card cost, and track supply are unchanged by sunlight.

`V074FacilityRuntimeCore.refresh_warehouse_solar_states` is the sole Lane B
batch transition for applying authoritative geometry-derived solar facts to an
existing facility state. It updates occupied warehouse throughput, advances the
state revision and solar refresh counter, and reseals the state fingerprint.
It does not advance slot, facility, or region generations and leaves empty,
factory, and market slots unchanged.

The existing Commodity Flow implementation proves that a private stock system
has existed, but Lane B does not copy or fabricate it. Its phase is recorded as
`existing_external_owner_or_deferred`. Public projection includes only
identity, ownership, capacity, throughput, rank, damage, generation, occupancy,
solar state, and the stable art key. Stock contents, private logistics, future
transport plans, private sources, future actions, and AI plans are absent.

## Card and DBG boundary

The V0.7.4 card registry preserves the V072 definition API and exact
13-field card definition shape. Starter output remains twelve cards. Normal
track supply becomes eighteen L1 definitions, including six warehouses.
Warehouse purchase contracts enter the personal discard first; normal DBG
reshuffle later permits draw. Merge requires two same-color, same-rank warehouse
definitions and an explicit player decision.

The shared DBG and Unified Track cores are intentionally not copied. Integration
must change their definition preload to the V0.7.4 registry and derive the DBG
`CARD_TYPES` constant from that registry.

## Source ledger

- `docs/rules/v07_game_constitution.md:342-361`
- `docs/tabletop_rulebook_v06.md:23-80`
- `scripts/rules/space_syndicate_ruleset_profile_v06.gd:13-15`
- `data/cards/card_runtime_catalog_v06.json:18924-19258`
- `scripts/runtime/region_infrastructure_runtime_controller.gd`
- `scripts/runtime/commodity_flow_runtime_controller.gd`
- `scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd`
- `resources/presentation/alpha01_card_illustration_catalog.tres`

Save/Continue remains disabled for V0.7.4. No V0.6 Save file or owner is
modified by this lane.
