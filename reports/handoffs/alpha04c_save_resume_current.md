# Alpha 0.4-C Save/Resume current handoff

Status: `BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO`.

The audited code checkpoint is `4781593c3cc74354d6bcda2cbf530fc40d9f23cf`
on `codex/alpha04c-save-resume-cold-restore-5b8601b`, protected by Draft
PR #77. All tracked implementation changes are committed and pushed. The only
remaining worktree entries are 31 Godot-generated `.uid` sidecars, all retained
and excluded; ambiguous user-file count remains zero.

## Qualification result

Production exposes only challenge depth 1. The final bounded, non-official
qualification used seed `900626424` and scenario fingerprint
`0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf`.
It ended with `legal_factory_market_queue_target_missing`, queue count zero.

The two production queue effect families require unavailable Industry factory
or Shipping market targets on that active map. Facilities settle directly. A
real typed RegionSupply purchase and Player Card Dock submission additionally
proves every active rank-I military candidate is rejected by the production
route with `v06_card_effect_route_unavailable`, creates no bound action, and
does not consume the card. No direct mutation, queue injection, fixed card,
invented depth, or random-map fallback was used.

The official cold-restore count remains zero. Processes A, B, and C were not
started, no official save was written, and the driver's execution switch
remains false.

## Preserved green evidence

- Registry transaction: 14/14, with 19/19 preflight, 19/19 fault rollback,
  apply 19, commit 1, and rebind 1.
- v3 tagged Int64 envelope codec: 62/62; file fault matrix: 16/16; Save/Resume
  flow: 40/40; confirmation: 10/10; fork parity: 14/14.
- Cold restore schema-v3/exact-once contract: 107/107; natural terminal helper:
  75/75; terminal driver integration: 27/27. The manifest has 74 closed fields.
- Real three-pool Player Card Dock production regression: 30/30; Main runtime
  composition: pass.
- Godot 4.7 real `main.tscn` startup/stop: zero script errors and zero runtime
  errors (existing warnings only); correct engine `--check-only`: pass.

An earlier command placed `--check-only` after Godot's user-argument separator,
so the legacy full Smoke body began in isolated QA user data. It was terminated
after approximately 30 seconds and did not complete, write official evidence,
or change official/Formal counts. The corrected engine parse-only invocation
then passed. Therefore `FULL_SMOKE=false` remains accurate, with the aborted
start explicitly disclosed.

An optional Alpha01 manifest audit also exposed a pre-existing pinned
`mechanic_registry` SHA mismatch. Those manifest/registry paths are unchanged
from the effective base; this task does not repair that unrelated baseline
metadata drift.

## Delivery boundary

PR #77 must remain Draft and must not merge. The next exact action requires
explicit authorization for a production/content change that creates a lawful
queue-capable action on active depth 1. Only after a fresh non-official
qualification succeeds may the still-unconsumed official A-to-B-to-C run be
considered. No V0.7 work may begin from this blocked Alpha 0.4-C state.
