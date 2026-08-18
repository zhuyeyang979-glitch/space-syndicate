# V0.7.5 Lane E Handoff

Status: **GREEN**

Branch: `codex/v075-lane-e-military-missions-bd0af5c`

Base: `bd0af5c99c5267cdbe7d66c01034f80db4d704fd`

## Delivered Contracts

Lane E adds a pure `V075MilitaryMissionCore` with exactly two one-shot mission kinds: `assault_region` and `assault_monster`. Player requests select only a region or a monster source ID. Card rank, damage values, escrow revision, target generations, target revisions, and the enemy facility set are injected and frozen by the authority lock.

`assault_region` locks enemy factory, market, and warehouse identities in stable facility-ID order. Resolution skips invalid locked identities without adding targets, then distributes one fixed total damage budget one point per target per pass. The budget is never copied to every facility. If all locked facilities are invalid, the mission fizzles without reselection.

`assault_monster` locks source instance, generation, revision, and public region. A moved monster remains the target only when instance and generation still match; damage is emitted against its current public region. Destroyed, withdrawn, replaced, generation-changed, or absent targets fizzle, and another monster is never selected.

The public snapshot adapter accepts Lane B's authoritative `damage_revision` field (and the test-only `source_revision`/`revision` aliases) without reading private monster state.

Every outcome emits ordered typed intents for military withdrawal and return of the same normal DBG card instance to `personal_discard`. The card remains reshuffle-eligible. Asset settlement is delegated to the existing normal-action owner, action slots are not refunded on fizzle, and this core never mutates Facility, DBG, Asset, or Monster authority state.

`FacilityCombatDamageIntentV1` carries the required source effect, facility ID, expected generation, damage amount, damage kind, and combat receipt ID. `V075CombatDamageCore` emits validated intents only. Warehouse stock, inventory, and private logistics fields are ignored and never appear in locks, receipts, or damage intents.

## Hard Gates

- `MILITARY_TASK_KINDS=[assault_region, assault_monster]`
- `MILITARY_GUARD_TASK_COUNT=0`
- `MILITARY_BOUND_ACTION_COUNT=0`
- `MILITARY_PERSISTENT_SOURCE_COUNT=0`
- `MILITARY_REGION_FULL_DAMAGE_REPLICATION_COUNT=0`
- `MILITARY_REGION_ASSAULT_RETARGET_COUNT=0`
- `MILITARY_MONSTER_ASSAULT_RETARGET_COUNT=0`
- `COMBAT_DIRECT_FACILITY_WRITE_COUNT=0`
- `COMBAT_DIRECT_DBG_WRITE_COUNT=0`
- `WAREHOUSE_PRIVATE_STOCK_COMBAT_DISCLOSURE_COUNT=0`
- `OLD_MILITARY_CONTROLLER_PRODUCTION_REFERENCE_COUNT=0`

## Validation

- MCP changed-script validation: `15/15`, diagnostics `0`.
- MCP scene load: `1/1`, real `V075MilitaryMissionBench.tscn` scene tree loaded.
- MCP Bench: `PASS`, `12` checks, `0` failures, play state stopped normally.
- Fresh Role C editor log: `0` error lines and `0` Lane E error lines.
- Focused Godot tests: `11/11` passed, all exit `0`, all completion markers present, script errors `0`.
- The isolated runtime profile retained one shader-cache header diagnostic unrelated to Lane E; task-introduced runtime errors are `0`.
- No full Smoke, V8, Process A/B/C, Formal FullRun, or frozen reliability-track command was run.

## Integration Ports

The coordinator should connect these pure outputs through the unique `V075CombatRuntimeOwner`: authoritative card facts into lock, public Facility/Monster snapshots into resolution, `FacilityCombatDamageIntentV1` into Region Infrastructure, withdrawal then discard intents into the DBG owner, and asset settlement policy into the existing Asset owner. Exact-once journaling remains the runtime owner's responsibility and should key on `combat_receipt_id`.

No runtime composition, UI, AI, catalog, Facility core, DBG owner, `main.tscn`, or legacy controller file was modified.
