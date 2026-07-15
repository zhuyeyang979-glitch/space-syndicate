# FullRunQualityDriver Contract

## Purpose

`FullRunQualityDriver` is an honest full-match harness boundary. Its first version proves whether a real match can be saved and resumed without inventing state. It does not claim that twenty matches have completed.

## Current gate

Before setup or simulation, the driver loads `res://scenes/main.tscn`, locates the scene-owned `GameRuntimeCoordinator`, and reads the production `V06SaveOwnerRegistry` capability snapshot. Execution requires all of the following:

- the registry is valid and exactly 18 of 18 required sections are transactional;
- the registry is resume-ready and its capture probe succeeds;
- the Coordinator explicitly declares one transactional RNG continuation authority;
- the Coordinator explicitly declares complete transactional player-state continuation;
- the Coordinator explicitly declares exact resume support.

Missing declarations fail closed. On the current local integration, the registry reports 6 transactional and 12 unsupported sections, so the driver emits `failure_code=restore_capability_incomplete`, marks downstream stages `blocked_by_capability`, and exits nonzero before starting a match.

## Invocation

```powershell
& tools/invoke_godot_test.ps1 `
  -TestScript res://scripts/tools/full_run_quality_driver.gd `
  -TestArgument @('--', '--preflight-only', '--seed-index', '0', '--max-wall-seconds', '30') `
  -TimeoutSeconds 60
```

The fixed seed list contains 20 entries under algorithm label `space-syndicate-full-run-quality-v1:sha256-positive31`.

## Output

The process writes newline-delimited JSON only. Heartbeats and the final summary contain public or aggregate fields. They never include save envelopes, section payloads, card inventories, discard contents, exact participant balances, identity bindings, AI learning data, plans, or private fingerprints.

QA save scope is `user://test_runs/full_run_quality/<head>/<seed>/`. Preflight installs this isolated path before Main enters the tree, but does not create a save file.

## Forbidden shortcuts

The driver may not use retired Main save snapshots, directly force terminal outcomes, directly tick child runtime owners, mutate timers or economic balances, or call settlement presentation. A future executable match state machine must use production setup, Coordinator APIs, normal Main ticking, strict v3 save transport, a fresh-world restore, public victory state, and production settlement callbacks.

## Validation evidence

Validated with Godot `4.7.stable.official` on 2026-07-15:

- contract run `20260715-075716-524-full_run_quality_driver_contract_test-3b596ee9`: ExitCode 0, 33/33 checks, no timeout, no script error, no residual runtime process;
- production preflight run `20260715-080855-341-full_run_quality_driver-2b5172c0`: expected ExitCode 3, `failure_code=restore_capability_incomplete`, no timeout, no script error, no residual runtime process;
- production capability evidence: 18 required, 6 transactional, 12 unsupported, capture rejected without an envelope;
- PlayerMana transaction run `20260715-080847-400-player_mana_save_owner_transaction_test-ad8acee7`: ExitCode 0, exact revision/reservation/terminal-receipt restore, detached preflight normalization, failed apply mutation count zero;
- registry run `20260715-080851-300-v06_save_owner_registry_test-c531ae6b`: ExitCode 0, production boundary 6/12 and full resume still fail-closed;
- the player default save was unchanged and the scoped QA directory was not created;
- `git diff --check` passed.
