# Player Organization Runtime v0.6 Handoff

## Status

Focused implementation is complete and frozen within the assigned exclusive files. It is not yet production-wired.

## Added files

- `scripts/runtime/player_organization_runtime_controller.gd`
- `scenes/runtime/PlayerOrganizationRuntimeController.tscn`
- `scripts/cards/v06/organization/organization_card_effect_adapter_v06.gd`
- `tests/player_organization_runtime_controller_v06_test.gd`
- `tests/organization_card_runtime_v06_test.gd`
- `tests/organization_card_privacy_v06_test.gd`
- `docs/player_organization_runtime_v06.md`
- `reports/coordination/player_organization_runtime_handoff.md`

No existing production file was modified by this task.

## Delivered behavior

- Single owner for three private organization slots per actor.
- Strict consumption of the final 20-card organization catalog payloads.
- Same-family higher-rank replacement; equal/lower rank and fourth family reject during prepare.
- Next-window activation for every installed organization.
- Persistent asset conversion, action bandwidth, hand capacity, monster binding, and military command terms.
- CardFlow-compatible prepare/commit/rollback/finalize/abort lifecycle.
- Exact transaction replay and binding-collision rejection.
- Complete preimage/postimage state swap with compensation.
- Monotonic owner revision after rollback, preventing stale private capability resurrection.
- Save/load of terminal and inflight transaction lifecycle.
- Checkpoint gate for prepared and rollback-open commits.
- Signed actor/window/revision-bound shared-window capabilities; modified limits fail validation.
- Private read APIs for all five consumer domains.
- Public snapshot with no actor, exact multiplier, hand, unit-cap, or AI fields.

## Focused Godot 4.7 evidence

All runs used an isolated `APPDATA`, headless Godot 4.7, and did not access the default player save location.

| Test | Result |
|---|---|
| `tests/player_organization_runtime_controller_v06_test.gd` | PASS 43/43 |
| `tests/organization_card_runtime_v06_test.gd` | PASS 89/89 |
| `tests/organization_card_privacy_v06_test.gd` | PASS 8/8 |

Combined focused evidence: **140/140 checks passed**, exit code 0, with no leak warning after explicit test cleanup.

Owned-scope diff check: **PASS**, eight authorized files present, zero trailing-whitespace findings, and zero unexpected generated UID files.

An isolated editor parse also registered both new global classes and the controller scene. The editor-wide parse reported pre-existing errors in unrelated military/commodity bench scripts; neither is in this task's write boundary and the three direct focused tests load cleanly.

## Integration boundary

The next central integration should make only these minimal connections:

1. Coordinator mounts/configures the single scene and adds it to coordinated save/load.
2. Existing v0.6 card dispatch routes `install_organization_upgrade` to `OrganizationCardEffectAdapterV06` through the current Inventory/CardFlow transaction.
3. PlayerMana consumes `asset_recovery_terms` but remains the only six-color asset owner.
4. Inventory/CardFlow consumes `hand_limit_terms` but remains the only hand/card owner.
5. Shared-window Queue receives a validated `card_window_submission_capability` as authoritative facts, never from the request.
6. MonsterRuntime consumes `monster_binding_caps` and remains the only monster roster/legality owner.
7. MilitaryRuntime consumes `military_command_caps` and remains the only military roster/command owner.

The owner deliberately does not implement response-card counting, public anonymous-track association, GDP gates, catalog purchase flow, cash/asset debit, or unit mutations.

## Known integration risks

- The current queue work-in-progress can still read an extra-submission capability from request data. Production integration must validate the controller's signed capability and project only the validated result into queue facts.
- Existing v0.6 CardFlow and production player-state code currently hard-code hand limit five. They must consume the authoritative organization hand-limit snapshot without giving request data authority.
- Monster and military owners currently derive some limits from role/world calls. Organization terms must be additive inputs inside those owners, not competing roster owners.
- PlayerMana needs its own integer bonus remainder when applying basis-point recovery. Organization Runtime intentionally does not mutate or round assets.
- GDP requirements and positive-color requirements are catalog terms. Their production economic preflight remains a CardFlow/Coordinator concern and was not duplicated here.

## Reusable lessons

1. A persistent self-upgrade should own only its modifier and expose narrow terms to business owners.
2. "Next window" must bind to an integer window sequence, not wall-clock time.
3. Caller-supplied maximums are intentions, never capabilities.
4. Rollback should restore content but keep revisions monotonic to invalidate stale authorization.
5. Rank replacement and slot capacity must reject before the outer transaction consumes a card.
6. Inflight save support does not mean the state is checkpoint-safe; both facts must be represented.
7. Anonymous public presentation and private owner state require separate snapshots.
8. Foreign monster reinforcement asks the target owner's capacity owner, while MonsterRuntime remains the final executor.

## Explicitly not run

- full smoke
- MCP runtime bench
- headed test or screenshot
- default `user://` tests
- commit, push, or merge
