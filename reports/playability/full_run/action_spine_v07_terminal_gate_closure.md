# Action Spine V0.7 Terminal Gate Closure

```text
STATUS=ACTION_SPINE_V07_TERMINAL_GATE_CLOSURE_GREEN

BASE_SHA=f377746584ac70d706418d399b813f3ad456763e
RESULT_HEAD_SHA=THIS_COMMIT
BRANCH=codex/pr69-terminal-gate-closure-f377746
PULL_REQUEST=69
PULL_REQUEST_CAN_FAST_FORWARD_GREEN=true
PUSH_PERFORMED=false

CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
TARGET_DEVELOPMENT_CONSTITUTION=V0.7
FULL_V0_7_RUNTIME_CUTOVER=false

THREE_FACILITY_RULE_AUTHORITY=false
THREE_FACILITY_CLASSIFICATION=historical_fullrun_acceptance_oracle
PEAK_PRODUCTION_INSTALLATION_COUNT_ROLE=diagnostic_only

FORMAL_FULL_RUN_COUNT=1
FORMAL_FULL_RUN_RERUN_COUNT=0
FORMAL_FULL_RUN_STATUS=settled
FORMAL_FULL_RUN_COMPLETED=true
```

## Authority ruling

The V0.6 rulebook, Victory runtime contract, typed Ruleset profile, and
`VictoryControlRuntimeController` define dynamic Top-K region control, Top-K
commodity GDP, 10 seconds of qualification, and a 120-second audit. None of
them defines a minimum production-facility count. The older three-facility
condition was a FullRun harness heuristic, not gameplay authority.

The old gate was internally impossible for a legitimate two-facility Victory:
the Driver correctly stopped all growth as soon as eligibility appeared, while
terminal acceptance still demanded a third installation. The versioned
contract at `docs/contracts/v06_full_run_terminal_acceptance_v1.json` now fixes
`THREE_FACILITY_RULE_AUTHORITY=false`.

## Narrow repair

- Removed the Driver's fixed three-installation constant and the Planner's
  `production_floor` parameter and branch.
- The scripted economy now establishes a viewer-safe matched production/demand
  chain, waits for a typed Sale Receipt, and uses the public Victory GDP gap
  plus the existing maturation window to decide whether more legal growth is
  needed.
- Terminal acceptance requires a settled matched chain and public Sale, then
  trusts the authoritative Victory lifecycle and exact-once terminal owners.
- Peak facility count remains diagnostic-only.
- The post-eligibility installation delta starts at the first `eligible=true`
  observation and is monotonic, so later facility destruction cannot erase a
  violation.

No gameplay value, Victory threshold, timer, RuntimeLoop, clock formula, RNG
owner/draw point, Save owner/schema, Main path, AI production behavior, or
production formula changed. No state was injected.

## Single formal FullRun

The only formal allocation was used once:

```text
RUN_ID=20260728-153746-194-full_run_quality_driver-652209fd
ARGS=--seed-index 0 --observation-seconds 150 --max-wall-seconds 180
SEED=900626424
RUNNER_DURATION_SECONDS=176.626
DRIVER_WALL_MILLISECONDS=172635
SCRIPT_ERROR_COUNT=0
PROJECT_SCOPED_GODOT_PROCESS_COUNT_AFTER=0
```

The run established two production installations and one real settled matched
chain: energy commodity `磁核榴莲`, production `10`, demand `10`, settled units
`4`, transported units `4`, and waste `0`. It emitted 23 typed public Sale
Receipts, reached Top-K GDP `1368/108`, controlled regions `5/3`, attempted 102
actions, progressed 99, and recorded zero invalid actions and zero nonfinite
facts.

Victory traversed `idle -> qualification -> audit -> resolved`. Authorized
timer evidence verified exactly 10 seconds of qualification and the complete
120-second audit. Outcome `victory.v06.1` settled with reason
`public_audit_complete`.

FinalSettlement applied once, terminal presentation applied once, and the
outcome-bound final public log appeared once. Eight consecutive terminal frames
were quiet. World delta was `0`, RNG draw delta was `0` (`1268 -> 1268`), and
post-eligibility production-installation delta was `0`.

## Verification

FullRun-focused gates passed: observation `27/27`, planner `36/36`, facility
policy `62/62`, Driver contract `197/197`, progress budget `11/11`, checkpoint
privacy `8/8`, observation boundary `8/8`, argument transport `13/13`, and
authoritative stepper `17/17`.

Action Spine gates passed: semantic protocol `117/117`, application flow
`57/57`, purchase projection `66/66`, supply surface `42/42`, district action
port, and card-presentation runtime.

Terminal regressions passed: CommodityFlow postcommit `115/115`, Victory split
delta `57/57`, terminal presentation `81/81`, FinalSettlement composition
`24/24`, and Main architecture `219/219`. Main runtime composition, UI text,
visual contract, smoke `--check-only`, and `git diff --check` also pass.

Godot MCP 4.7 loaded the real `res://scenes/main.tscn` and stopped it cleanly.
Only the repository's pre-existing warnings and NUL diagnostics appeared; no
new script or runtime error was introduced.

## Evidence hashes

```text
stdout.log=950AB2763DBC41B34687B78C0776536296CC5AAB7A443CE9ACA369BA89D05EB6
stderr.log=7202AC2EFE624BC7149B2AAA3CBA600143B71CA36523DBA04EB798E826DEB21F
godot.log=558F8CCF8EF7847B13D0D1E7BDFC5E7361F93F4F21F2020506E522050A1DEE75
result.json=281DFBC310C6A4C2630D65BB21A343B1E725FFA742792E311EC9AA912A8C489D
```

## PR #69 decision

Remote PR #69 is currently a clean Draft whose head is exactly this task's
base `f377746`. The local closure commit is a direct descendant and can
fast-forward the PR branch to a green terminal gate. This task does not push or
change the remote Draft state.
