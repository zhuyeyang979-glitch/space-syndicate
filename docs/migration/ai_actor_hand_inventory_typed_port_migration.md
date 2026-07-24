# AI Actor Hand Inventory Typed-Port Migration

## Status

`STATUS=AI_ACTOR_HAND_INVENTORY_TYPED_PORT_MIGRATION_VALIDATED_CANDIDATE`

This is one completed atomic domain inside the active `P0-AI-WORLD-TYPED-PORTS-CUTOVER`. It does not claim the parent P0, a complete match, full-run resume, or Alpha 0.3 completion.

## Production Contract

The production composition owns exactly one `AiActorHandInventoryQueryPort` and creates exactly one opaque `AiActorHandInventoryCapability` before child lifecycle callbacks. `AiRuntimeController.controller_ready` now requires actor state, actor economy, and actor hand boundaries.

The QueryPort returns one detached schema-v1 actor-private snapshot:

`schema_version, session_id, session_revision, source_revision, fingerprint, visibility_scope, actor_index, hand_limit, counted_hand_size, discardable_slot_indices, slots`

Each slot row has:

`slot_index, occupied, card_id, runtime_instance_id, family_id, rank, kind, counts_toward_hand_limit, persistent, queued_for_resolution, cooldown_left, lock_left, card`

The nested card is a deep copy of the authorized actor's existing pure-data card row. It is not a second inventory. Runtime-private card keys fail closed recursively before projection. Session identity plus the WorldSession restore epoch invalidate stale snapshots.

## Authority And Privacy

- Hand storage owner: `WorldSessionState.players[].slots`
- Hand-limit, explicit count metadata, and discard policy: `CardInventoryRuntimeService`
- Session owner: `GameSessionRuntimeController`
- AI identity authorization: `AiActorStatePort`
- Semantic consumer: `AiRuntimeController`
- New gameplay owner: none
- New Save section: none
- Save Registry section count: 19

Human, eliminated, out-of-range, forged-capability, stale-session, unconfigured-inventory, malformed-slot, negative timing, impure payload, forbidden private card fields, and counted overflow requests fail closed. Rival hands, human hands, player cash, city inference, AI memory, hidden ownership, queue internals, and save payload are not exposed.

## Consumer Result

All frozen AI own-hand reads for pressure, observation, route scoring, play, buy, counter generation, counter revalidation, and discard scoring use the typed snapshot. The old Main hand-count and family-slot calls are gone, as is the unused AI `PLAYER_HAND_LIMIT` Main proxy.

Purchase legality still belongs to the existing DistrictSupply and inventory owners. Play, buy, counter, discard, and card mutations were not moved into the QueryPort.

## Side Effects

- Query world mutation count: 0
- Query inventory mutation count: 0
- Query GameSession mutation count: 0
- Query RNG delta: 0
- Query save-dirty delta: 0
- Query diagnostic-counter delta: 0
- Rival private leak count: 0
- Duplicate state owner count: 0

## Main Budget

`scripts/main.gd` is unchanged by this atomic slice.

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Physical lines | 6440 | 6440 | 0 |
| Nonblank lines | 5421 | 5421 | 0 |
| Methods | 470 | 470 | 0 |
| Fields | 46 | 46 | 0 |
| Constants | 45 | 45 | 0 |
| Preloads | 7 | 7 | 0 |
| External caller files | 103 | 103 | 0 |

The budget tool still reports the inherited threshold `103 > 102`; this task adds no caller and no production Main reference.

## Verification

- Focused actor-hand migration: `92/92 PASS`
  - Run ID: `20260724-173540-931-ai_actor_hand_inventory_typed_port_migration_test-4034c9ae`
- Production scene Bench: `21/21 PASS`
  - Run ID: `20260724-173558-333-AiActorHandInventoryTypedPortMigrationBench-68aa92cc`
  - Evidence: `counted_hand=3|discardable=[0]`
- Actor economy: `81/81 PASS`
- Actor economy production Bench: `19/19 PASS`
- Public-player facts: `128/128 PASS`
- Actor-state facts: `93/93 PASS`
- Actor-state production Bench: `37/37 PASS`
- City inference: `48/48 PASS`
- Typed-world boundary: `83/83 PASS`
- AI business architecture: `37/37 PASS`
- AI typed cash: `72/72 PASS`
- Formal four-player `main.tscn`: `28/28 PASS`
- Setup transaction: `133/133 PASS`
- WorldSession: `44/44 PASS`
- Save Registry: `12/12 PASS`
- Envelope runtime: `60/60 PASS`
- Main architecture: `217/217 PASS`
- Main composition: `PASS`
- Smoke `--check-only`: `PASS`
- Godot MCP script validation and cold scene composition: `PASS`
- `git diff --check`: `PASS`

## Inherited Test Debt

Three extra non-Gate-0 checks remain red on the parent for unrelated stale fixtures:

- `CardInventoryRuntimeCharacterizationBench.tscn` calls retired `Main._new_game`.
- `PlayerHandInteractionRuntimeCharacterizationBench.tscn` calls retired `Main._new_game`.
- `session_envelope_save_owner_test.gd` has one stale Main source-string oracle.

The formal card-flow policy gate remains green. Retired Main wrappers were not restored, and these fixture families were not folded into this atomic production boundary.

## Deferred Boundary

The parent P0 remains active. The next recommended audit is `AI_PUBLIC_DISTRICT_FACTS_TYPED_PORT_MIGRATION_PREFLIGHT`, while the session-default mutation stays a separately named owner-migration candidate.
