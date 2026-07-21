# Monster Battle Lifecycle Owner Cutover

Status: focused production cutover evidence recorded.

## Goal

Monster wagers now have two distinct player-visible time spans:

1. a 15-second mandatory wager decision window that freezes the table; and
2. a monster battle lifecycle, capped at 60 seconds of world-effective time,
   that resolves the wager only after the battle ends.

The purpose of this cutover is to prevent “last wager response = immediate
cash settlement” from remaining as a production assumption.

## Owner boundary

`MonsterRuntimeController` remains the sole owner of:

- active wager lifecycle phase;
- decision timer;
- battle timer;
- frozen opening-cash commitments;
- unresolved battle roster binding;
- opening battle command binding;
- terminal settlement journal;
- resolved public wager history;
- public wager pool carry.

`MonsterWagerSettlementPolicyV06` remains a pure calculator and never owns
runtime state. UI and overlays only display decision/battle snapshots.

## Runtime path

```text
Monster collision / action intent
→ MonsterRuntimeController opens decision
→ ForcedDecision/Overlay displays 15-second wager choice
→ responses close decision
→ MonsterRuntimeController advances 60-second battle lifecycle
→ opening strike dispatches through RuntimeCommandPipeline
→ MonsterActionCommandSink
→ SimulationMutationAuthority
→ MonsterRuntimeController records applied binding
→ terminal battle condition
→ MonsterWagerSettlementPolicyV06 computes cash/public-pool result
→ MonsterRuntimeController applies exact-once owner mutation
```

## Player-facing semantics

- The wager window is 15 seconds and globally blocking.
- All players must choose or receive the deterministic default.
- Confirmed stake commitments are reserved from opening cash, but not debited
  early.
- After the window closes, the battle continues for up to 60 seconds.
- During the battle phase, ordinary card play and table actions are no longer
  frozen by the wager decision.
- Settlement occurs when the battle times out, a combatant is down/expired/
  removed, or another explicit owner terminal condition is reached.
- Knockback and movement presentation do not settle the wager by themselves.

## Privacy

Public wager/battle snapshots must not expose:

- opening-cash maps;
- locked competitor UID internals;
- battle roster fingerprints;
- pending attack internals;
- opening command IDs;
- hidden/true owner;
- AI plan or scoring metadata.

Public receipts expose only allowlisted wager choices, public damage/payout
facts and public pool outcomes.

## Exact-once replay

The opening battle strike may be replayed idempotently only if all owner-bound
fields match:

- wager ID;
- settlement revision;
- command ID;
- actor UID;
- target UID;
- action index;
- action fingerprint.

A reused command ID with different actor/target/action binding fails closed.

## Evidence

Focused tests:

- `res://tests/monster_battle_lifecycle_owner_cutover_test.gd`
- `res://tests/monster_wager_reopen_cooldown_test.gd`
- `res://tests/monster_wager_settlement_owner_cutover_test.gd`
- `res://tests/monster_wager_cash_commitment_query_port_cutover_test.gd`
- `res://tests/monster_wager_response_cutover_test.gd`

Focused benches:

- `res://scenes/tools/MonsterBattleLifecycleOwnerBench.tscn`
- `res://scenes/tools/MonsterWagerSettlementOwnerBench.tscn`
- `res://scenes/tools/MonsterWagerCashCommitmentQueryPortBench.tscn`

Known unrelated baseline debts observed during this cutover:

- `typed_world_ports_boundary_test.gd` still expects excluded
  `RuntimeWorldPorts.*` lifecycle migrations.
- `MonsterRuntimeCharacterizationBench.tscn` still calls retired
  `main._new_game`.
- `layout_scene_smoke_test.gd` contains broad stale assertions across old UI,
  Codex, city-development and PublicTrack boundaries.

## Follow-up: manual settlement wrapper retirement

The old wager-ID settlement wrapper
`MonsterRuntimeController._settle_monster_wager(wager_id, reason)` is retired.
External tests and smoke cleanup now advance the authoritative lifecycle through
`tick_wager_decisions_realtime()` and `tick_battle_lifecycles()` instead of
calling a manual settlement entry.

The owner still keeps its internal index-scoped settlement helper because the
decision/battle lifecycle uses it after entering the `settling` phase. That
helper is not an external gameplay API.

## Follow-up: legacy wager fixture schema retirement

Focused tests and characterization benches must seed active monster wagers with
the formal battle-lifecycle schema instead of the retired one-shot fixture
shape. In particular, test data should use:

- `lifecycle_schema_version`
- `lifecycle_phase`
- `decision_remaining_seconds`
- `battle_limit_seconds`
- `battle_remaining_seconds`
- `locked_competitor_uids`
- `battle_roster_fingerprint`
- `opening_attack_applied`

Do not seed active wagers with retired fixture fields such as
`remaining_seconds`, `seconds_total`, `battle_resolved`, `pending_attack` or
private owner sentinels. Privacy tests may still mention these strings only as
negative leak sentinels.
