# AI Public District Facts Consumer Inventory

## Status

- Task: `AI_PUBLIC_DISTRICT_FACTS_TYPED_PORT_MIGRATION`
- Parent: `P0-AI-WORLD-TYPED-PORTS-CUTOVER` remains `ACTIVE`.
- Existing query port reused: `AiRegionKnowledgeQueryPort`.
- New query port, capability, state owner, or save section: none.
- Rule and privacy authority: `GREEN` for the seven leaf consumers listed below.

## Authority

| Fact | Authority and disposition |
| --- | --- |
| Region identity, public name, terrain, product and demand labels, neighbors | `WorldSessionState`, narrowed by `AiRegionKnowledgeQueryPort.public_district_facts_snapshot()` |
| Public city presence, active state, product names, demand names | `WorldSessionState`, narrowed to four city keys by the same port |
| Public infrastructure damage and lifecycle | `RegionInfrastructureRuntimeController`; deferred from this schema |
| Region panic or heat | Retired by the v0.6 region contract; excluded |
| City owner truth | Private authority; excluded from the public schema |
| AI scoring and candidate order | `AiRuntimeController`; unchanged |

The port is a stateless projection boundary. It is not a second district owner and is not persisted.

## Schema 1

Every public district row contains exactly:

`schema_version`, `source_revision`, `fingerprint`, `visibility_scope`,
`district_index`, `region_index`, `region_id`, `name`, `destroyed`, `terrain`,
`products`, `demands`, `neighbors`, and `city`.

A present city contains exactly:

`present`, `active`, `product_names`, and `demand_names`.

The projection deliberately excludes owner truth, guesses, confidence, reason, damage,
panic, route state, warehouse state, GDP, market positions, future supply, monster and
military state, AI plans, Nodes, Objects, and Callables. Rows remain in source order;
destroyed and inactive-city rows are not filtered or sorted. Missing legacy region IDs
retain the established deterministic `region.%03d` fallback, and missing terrain retains
the established `land` fallback.

## Migrated Consumers

| Consumer | Typed facts | Result |
| --- | --- | --- |
| `_district_or_city_has_product` | district/city product and demand names | No raw district or city bridge |
| `_alive_district_indices` | `destroyed`, stable source order | Main callback deleted |
| `_district_ocean_neighbor_count` | `neighbors`, `terrain` | One bulk snapshot per call |
| `_ai_business_public_region_id` | identity, lifecycle, public city active state | No raw city fallback |
| `_ai_district_touches_product` | district/city product and demand names | No raw district or city bridge |
| `_ai_first_alive_district` | typed alive order | First-match behavior preserved |
| `_ai_counter_entry_target_city` | public city active state | Invalid and inactive targets fail closed |

These consumers neither sort candidates nor consume RNG. The focused gate freezes invalid
indices, destroyed rows, inactive cities, ocean-neighbor counting, product/demand lookup,
legacy region-ID fallback, and missing-port behavior.

## Deferred Consumers

The remaining direct district reads are not claimed migrated. They include:

- actor-scoped city owner and own-versus-rival decisions;
- route ownership, route income, and network pressure;
- market, GDP, warehouse, futures, and District Supply;
- monster placement, lure, delay, risk, and target audit;
- weather targeting and zone effects;
- military deploy, guard, strike, monster target, and movement;
- Victory posture and mixed card-effect scoring.

`AiRuntimeController._district_city()` still reaches raw city truth through the legacy
Monster/Main bridge. The audit found 63 calls across 49 functions, including 43 owner reads.
That is the highest-priority next authorization boundary; it is not hidden by this slice.

The audit also found `_district_event_weight()` calling a missing Main method. It remains a
separately named monster-targeting defect and was not revived or assigned a new formula here.

## Main And Bridge Result

- `Main._alive_district_indices` is physically deleted.
- AI `_call_world` tokens decrease from 40 to 39.
- AI `districts` tokens decrease from 95 to 80.
- The generic district bridge remains for explicitly deferred mixed-domain consumers.
- Production Main reference files remain 3; external caller files remain the inherited 103.

## Evidence

- Focused migration: `104/104 PASS`.
- Production `main.tscn` Bench: `22/22 PASS`.
- Godot MCP script validation, scene cold-load, and live play-mode Bench: `PASS`.
- Actor hand: `92/92 PASS`.
- Public player facts: `128/128 PASS`.
- City inference: `48/48 PASS`.
- Typed world boundary: `83/83 PASS`.
- Actor economy: `81/81 PASS`; production Bench `19/19 PASS`.
- AI business transaction: `68/68 PASS`.
- Weather AI: `49/49 PASS`.
- Formal four-player `main.tscn`: `28/28 PASS`.
- Main architecture: `217/217 PASS`; Main composition: `PASS`.
- Smoke `--check-only`: `PASS`.
