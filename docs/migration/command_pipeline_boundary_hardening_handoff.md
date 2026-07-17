# Command pipeline boundary hardening handoff

`STATUS=COMMAND_PIPELINE_BOUNDARY_HARDENING_GREEN`

- Branch: `codex/scene-first-remove-main-gd`
- Starting SHA: `2c4ea4a1f68a37659e01a9e8be91eaf6aeafcba0`
- Existing dirty working tree preserved: yes
- Commit created: no
- Push performed: no

## Outcome

The production card-resolution transition batch now crosses an explicit,
scene-owned command boundary during the existing command phase. The command
pipeline validates deterministic pure-data envelopes, preserves producer order,
and forwards the original payloads to the existing transition sink. It owns no
world state, gameplay rules, cadence, save schema or presentation state.

The cutover intentionally does not defer synchronous card-play submission.
Human target selection, AI submission and role-counter conversion currently
depend on immediate acceptance/failure receipts and rollback behavior. Deferring
that path without a dedicated domain contract would be a gameplay regression,
not boundary hardening.

## Architecture

Before:

```text
RuntimeCommandPhaseCoordinator
  -> RuntimeCardPort
    -> CardResolutionFrameDriver
      -> CardResolutionTransitionSink
        -> typed domain owners
```

After:

```text
RuntimeLoop (unchanged unique frame owner)
  -> RuntimePhaseCoordinator
    -> RuntimeCommandPhaseCoordinator
      -> RuntimeCardPort
        -> CardResolutionFrameDriver (authors ordered intent batch)
          -> RuntimeCommandPipeline (validate/trace/dispatch only)
            -> CardResolutionTransitionSink (exact-once transition executor)
              -> existing typed mutation ports and domain owners
```

No global command bus, event bus, Autoload manager, service locator, replay
engine or network layer was introduced.

## Command ownership table

| Concern | Owner |
|---|---|
| Transition intent authoring | `CardResolutionRuntimeController` |
| Stable envelope schema/type/fingerprint | `RuntimeCommandEnvelope` |
| Order and pure-data boundary validation | `RuntimeCommandPipeline` |
| Phase placement | `RuntimeCommandPhaseCoordinator` through `RuntimeCardPort` |
| Exact-once transition execution | `CardResolutionTransitionSink` |
| Persisted applied-command lineage | existing `CardResolutionRuntimeController` save checkpoint |
| Gameplay mutation | existing card execution, queue, commitment, effect and domain owners |
| Presentation receipts | existing card presentation owner |

## Stable command contract

Current supported command type:

- `card_resolution_transition`

Envelope fields:

- `schema_version`
- `command_type`
- `command_id`
- `producer_revision`
- `order_index`
- `payload_fingerprint`
- `payload`
- `envelope_fingerprint`

Commands reject `Object`, `Node` and `Callable` data. Canonical key ordering and
SHA-256 make the envelope fingerprint independent of input source. The pipeline
does not store UI, player input, AI source or scene references in commands.

## Migrated and remaining paths

- Migrated command families this cutover: 1
- Production command types added: 1
- Remaining recorded direct/transactional player-intent families: 7
- Autonomous phase-driven families left outside input commands: 3
- Presentation-only families intentionally untouched: 2

Remaining player-intent families are card submission, region-supply purchase,
facility purchase/install, monster deploy/upgrade, contract offer/response,
monster wager choice and military player commands. They must be migrated as
small domain-specific contracts; none should be routed through a generic
Dictionary command bus.

## Determinism and mutation ownership

- Producer revision and order must be uniform and contiguous per batch.
- Duplicate command IDs inside a batch fail closed.
- Payload identity must match envelope identity.
- Rebuilding an identical command sequence yields identical envelope traces.
- Dispatch is delta independent.
- RuntimeCommandPipeline performs no gameplay mutation.
- The existing sink remains the only transition mutation executor.
- The existing applied-command lineage remains authoritative across save/load.

## Metrics

| Component | Before | After |
|---|---:|---:|
| Scene-owned command pipeline families | 0 | 1 |
| Supported production command types | 0 | 1 |
| RuntimeLoop physical lines | 57 | 57 |
| RuntimeLoop methods | 7 | 7 |
| RuntimePhaseCoordinator physical lines | 69 | 69 |
| RuntimeCommandPhaseCoordinator physical lines | 30 | 30 |
| GameRuntimeCoordinator physical lines | 6,005 | 6,017 |
| GameRuntimeCoordinator methods | 559 | 561 |
| Global command/event buses | 0 | 0 |
| Command Autoloads | 0 | 0 |
| Main gameplay command additions | 0 | 0 |

The new pipeline is 103 physical lines with five methods. The envelope is 103
physical lines and contains only static pure-data helpers. GameRuntimeCoordinator
gained one typed node accessor and one explicit binding method; it did not gain
dispatch, command switching or gameplay rules.

## Validation

Focused green evidence:

- command boundary architecture/order/ownership/replay readiness: PASS 31/31
- command pipeline production Bench: PASS 5/5
- card frame driver: PASS 104 checks
- card transition sink exact-once: PASS 70/70
- card gameplay fault injection: PASS 61 checks
- runtime phase decomposition: PASS 50/50
- RuntimeLoop: PASS 28/28
- typed world ports: PASS 80/80
- runtime phase Bench: PASS 7/7
- RuntimeLoop Bench: PASS 8/8
- typed world ports Bench: PASS 8/8
- table presentation Source/Target: PASS 20/20
- presentation ViewModel parity: PASS 106/106
- presentation query ports: PASS 65/65
- presentation scheduler trace: PASS 8/8
- victory public privacy: PASS 47/47
- Main architecture gate: PASS 76 checks
- Main runtime composition: PASS
- UI text smoke: PASS
- visual contract: PASS
- smoke `--check-only`: PASS

Godot 4.7 MCP launched the real `res://scenes/main.tscn`. No new parse,
missing-access or runtime exception was observed. Existing source warnings were
unchanged; a naming warning introduced during the first envelope draft was
removed before final validation. The command Bench also ran under Godot 4.7.

The bounded full smoke used isolated APPDATA and reached the established broad
debts: legacy AI military assertions, retired Main test hooks, historical
role/intel fixtures, and missing `_auto_monster_color` routing. No command
pipeline, ordering, duplicate-execution or new parse failure appeared. Full
smoke is not reported as green.

## Source changes

Added:

- `res://scripts/runtime/runtime_command_envelope.gd`
- `res://scripts/runtime/runtime_command_pipeline.gd`
- `res://scenes/runtime/RuntimeCommandPipeline.tscn`
- `res://tests/command_pipeline_boundary_hardening_test.gd`
- `res://scripts/tools/command_pipeline_boundary_hardening_bench.gd`
- `res://scenes/tools/CommandPipelineBoundaryHardeningBench.tscn`
- command audit Markdown/JSON and this handoff

Changed:

- `CardResolutionFrameDriver` to dispatch through the typed pipeline
- `GameRuntimeCoordinator.tscn` and its explicit wiring
- frame-driver characterization test
- migration ledger and development log

## Final declaration

RuntimeLoop remains the sole frame authority, phase order remains explicit,
commands have a deterministic serializable boundary, domain systems retain all
mutation authority, and no universal manager or compatibility route was added.

`COMMAND_PIPELINE_BOUNDARY_HARDENING_GREEN`
