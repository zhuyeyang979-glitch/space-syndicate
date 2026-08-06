# Lane C Handoff: Monster Autonomy and Trample

Status: GREEN

Base: bd0af5c99c5267cdbe7d66c01034f80db4d704fd

Branch: codex/v075-lane-c-autonomy-trample-bd0af5c

## Delivered

Lane C adds two pure V0.7.5 cores:

- V075MonsterAutonomyCore freezes public topology and facility facts, chooses targets by deterministic BFS, expands detection range, enters hungry fallback, and emits fixed-point movement receipts.
- V075MonsterTrampleCore aggregates repeated path segments by region, applies the rank balance formula and per-region cap, and emits typed FacilityCombatDamageIntentV1 records without writing facility state.

The only map fields consumed are dynamic region IDs, adjacency, optional integer edge distances, and region centers for one-time edge quantization. Camera state, pixels, polygon boundaries, vertex counts, and microcell counts do not participate in targeting, movement identity, or damage.

Facility inputs use an explicit public-field allowlist: identity, owner, region, type, industry, generation, status, and public damage state. Asset pools, warehouse stock, private logistics, skills, and future plans are not read. Tests alter private sentinels without changing the frozen snapshot or result.

## Determinism

Shortest paths use BFS over sorted adjacency. Equal-distance targets resolve in this order:

1. Monster facility_type_preference.
2. Higher authored target priority.
3. Higher public damage points, then damage revision.
4. Stable facility_id lexical order.

No matching target increases search radius by one hop for the next batch. At graph-wide range, the monster enters hungry state and selects the nearest eligible enemy facility of any color. A matching-color target restores preferred targeting and resets the next range to the authored base.

All monsters are planned from one fingerprinted frozen snapshot. Presentation order is emitted separately and cannot alter target inputs. The Bench proves two monsters select from the same pre-movement state with target-order bias count zero.

## Fixed-Point Movement

An upstream integer edge_distance_milli_arc map is authoritative when present. For the current V0.7.4 Map Genesis Receipt, each adjacent pair of unit-sphere region centers is independently converted to an integer at 1,000,000 units per radian. Path totals then use integer addition only; floats never accumulate into receipt or damage identity.

Movement receipts include stable identity, source generation, ordered region path, integer region segments, atomic destination region, profile, and forced-movement flags. The deterministic BFS path contains no loops.

## Trample

Only ground_trample produces damage. Flying, teleport, and default forced movement produce zero trample.

The formula is:

    steps = max(1, floor(distance_milli_arc / distance_step))
    raw = steps * damage_per_step_by_rank
    region_budget = min(raw, cap_per_region_by_rank)

Repeated segments are summed before one receipt is emitted per region. Damage is allocated without replication: preferred-color enemy facilities precede other enemy facilities, IDs are stable within each group, and quotient/remainder allocation is equivalent to one-unit round-robin over that order. Factory, market, and warehouse intents are supported; friendly and destroyed facilities are excluded.

The movement_id is the exact-once journal key. A processed ID is rejected before any second intent is emitted.

## Evidence

- Role C Funplay MCP: port 7573, Godot 4.7-stable, forward_plus, correct isolated project identity.
- Changed scripts: 14/14 parsed with zero final diagnostics.
- Bench scene loaded through MCP with the expected editable scene tree.
- MCP Bench: 11/11 cases and 78/78 checks passed.
- Real V0.7.4 topology fixture: seed 900626424, 16 regions, Standard/Balanced, connected sample path of 3 hops, all edge distances positive integers.
- Final MCP runtime log error count: 0.
- Play mode ended and explicit stop succeeded; editor then closed normally and port 7573 was released.
- Focused Headless tests: 11/11, all exit code 0.
- Full Smoke, V8, Process A/B/C, Formal FullRun, and reliability suites were not run.

The isolated editor's first commercial-asset import emitted unrelated project-wide baseline diagnostics. Lane C therefore does not claim the full-project error gate; final changed-file validation and the final runtime log are clean. The main Agent owns the coherent integration-SHA project gate.

## Integration

The Combat Runtime Owner should:

1. Freeze one public world snapshot for all active monsters.
2. Call plan_batch once and persist each plan's next_detection_range_hops.
3. Commit authority position by destination region, then present movement without replanning.
4. Pass each movement receipt and the combat journal's processed IDs into resolve_movement.
5. Send returned FacilityCombatDamageIntentV1 records to the Region Infrastructure Owner.

No runtime owner, application flow, AI, Player UI, main.tscn, catalog, balance file, old controller, or legacy main path was changed.
