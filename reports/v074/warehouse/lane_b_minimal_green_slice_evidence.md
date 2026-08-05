# Lane B Minimal Green Slice Evidence

Lane B is green as a detached facility and warehouse policy slice on base
`05c2415014187e902592bf3a8d1291222f738694`.

## Proven contracts

- Complete facility registry: factory, market, warehouse.
- Starter subset: factory and market only; twelve starter definitions.
- Standard normal track: eighteen L1 facility definitions, including six
  industry-colored warehouse definitions.
- Dynamic facility slots: eighteen per region and 108-540 slots for the tested
  6, 8, 12, 16, 20, 24, and 30 region counts.
- Warehouse BUILD, UPGRADE, REPAIR, contention fizzle, capacity, throughput,
  damage, ownership, rank, generation, public projection, DBG draw contract,
  purchase-to-discard, and explicit merge contracts.
- Sunlit/dark throughput multipliers are 2.0/1.0. Capacity is unchanged.
- Atomic geometry solar refresh reseals authoritative state and updates both the
  current public projection and the next batch without changing empty,
  factory, or market slots.
- Private stock and logistics fields are absent. No stock economy was added.

## Verification

- MCP script validation: 9/9, zero diagnostics.
- MCP scene load: 1/1.
- `V074_FACILITY_REGISTRY_TEST|PASS`.
- `V074_WAREHOUSE_RUNTIME_TEST|PASS`.
- `V074_WAREHOUSE_RUNTIME_BENCH|PASS` with 16 regions, 288 slots, one built
  rank-I warehouse, dark ingress 50, sunlit ingress/egress 100, and zero hidden
  projection fields.

## Integration hooks

The main agent must point shared DBG and Unified Track definition preloads at
`v074_card_definition_registry.gd`, derive DBG `CARD_TYPES` from that registry,
point the runtime owner at `V074FacilityRuntimeCore`, and pass source card rank
to its action builders. Map Genesis must supply dynamic region IDs to
`V074FacilitySlotRegistry.build_slot_registry` and geometry-derived solar facts
to `refresh_warehouse_solar_states`.

Production owner, DBG/track, map, AI, UI, and full-match cutover files are not
Lane B-owned and remain integration work. Existing Commodity Flow stock is
external or deferred; this slice intentionally exposes no stock payload.

Fresh Godot import churn in unrelated `.import` files and every generated
`.uid` file is excluded from the Lane B commit.
