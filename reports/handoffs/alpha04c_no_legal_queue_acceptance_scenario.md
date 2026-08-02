# Alpha 0.4-C legal queue acceptance scenario audit

## Trusted Wrapper Confirmation

Harness head `4a42f81c7cec9565bdd50810289ee77106a86759` reran the
frozen depth-1/seed-`900626424` qualification exactly once through
`ChildCompletionAttestationV1` and `ParentExitAttestationV1`. The child exited
zero, the parent observed and validated that exit, and zero task-owned
processes remained. The trusted product result still had Queue count zero and
blocker `BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO`.

The official ledger was not created, the conditional authorization was not
consumed, and Processes A/B/C were not started. The next task is
`ALPHA_0_4_C_P0_QUEUEABLE_FACILITY_ACTION_BRIDGE_AND_COLD_RESTORE_CLOSURE`.

Status: `BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO`.

The official cold-restore count remains zero. Process A, B, and C were not
started, no official save was written, and no Formal FullRun or completed full
Smoke was run.

During final verification, one command placed `--check-only` after Godot's
user-argument separator. Godot therefore began the legacy full Smoke body in
an isolated QA user-data directory instead of performing an engine parse-only
check. That unintended attempt was terminated after approximately 30 seconds;
it did not complete, write official evidence, or change any Formal/official
count. The corrected Godot `--check-only` invocation passed with exit code 0.

## Bounded configuration

The production content manifest exposes exactly one playable challenge depth:
depth 1. The runtime selection rejects any different depth, the session-plan
builder requires that selected depth, and the production setup UI exposes only
that active value. Therefore `VALID_CHALLENGE_DEPTHS=[1]`; depths 2-6 are not
legal Alpha 0.4 production configurations even though older world-generation
helpers can describe them.

The final bounded non-official qualification used:

- run id: `alpha04c-qualification-decoupled-economy-02`;
- challenge depth: `1`;
- fixed seed: `900626424`;
- scenario fingerprint:
  `0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf`;
- `qualification_probe=true`;
- `official_cold_restore_vertical_slice=false`;
- `formal_full_run=false`;
- `save_written=false`.

It ended with `legal_factory_market_queue_target_missing` and queue count zero.

Earlier QA-driver development left repeated depth-1 debug/probe directories
(`alpha04c-legal-a-debug-01` through `-15`, a default probe, and the preceding
dynamic-pair probe) plus rejected setup attempts for depths 2-4. Those runs are
disclosed as harness development, not represented as compliant per-depth
qualification results. None wrote official evidence, ran Formal, or consumed
the one official cold-restore authorization. The final decoupled-economy log is
the decisive bounded evidence used for this blocker.

## Why no lawful queue action exists

The production card submission owner sends only the two active V0.6 shared
effect families, `global_supply_spawn` and `global_order_budget`, to
`CardResolutionQueue`. Facility cards settle as direct transactions. The active
monster and military V0.6 families are explicitly `projection_only`, so they
cannot legally deploy a unit and create a legacy bound action for this
acceptance path.

The repository also contains a direct production negative witness:
`tests/player_card_dock_real_three_pool_production_test.gd` buys an active
rank-I military card through the typed RegionSupply quote/purchase path, reads
its real sealed Player Card Dock offer, and submits it through the real game
screen. The action is safely rejected with
`v06_card_effect_route_unavailable`; `bound_actions` remains empty and the card
is not consumed. The active military candidates all hit that unsupported V0.6
route, so changing the seed or choosing another military family cannot repair
the queue path. Directly calling the legacy `summon_from_card()` helper would
bypass the required production spine and is not an allowed fallback.

The depth-1 qualification dynamically inspected every industry, rather than
selecting a named card or route. It found two factory targets for `energy`, zero
factory targets for the other five industries, and zero market targets for all
six industries. The active shared supply action needs an `industry` asset and a
legal factory route; the active shared order action needs a `shipping` asset
and a legal market route. Both had zero asset-producing factory targets and no
legal endpoint pair.

Consequently, no available local or AI `GameActionOffer` can lawfully traverse

`GameActionOffer -> GameActionIntent -> TablePlayerActionApplicationFlowController -> CardResolutionQueue`

on the only supported challenge depth. Creating a pending entry by direct
queue injection, hidden authority mutation, forced card inventory, or an
invented map depth would violate the task contract.

## Delivery boundary

All completed registry, codec, save-flow, exact-once comparator, dynamic-offer
driver, and natural-terminal evidence work must still be committed and pushed.
Draft PR #77 must remain Draft and must not merge. The official A-to-B-to-C
authorization remains unconsumed; a future attempt requires an explicitly
authorized production/content change that creates a lawful queue-capable action
on the active map, followed by a fresh non-official qualification.
