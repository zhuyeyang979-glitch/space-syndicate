# Alpha 0.4-C MCP initial-scan isolation result

Status: BLOCKED by an attested PR77 focused-bench error after MCP recovery.

## Isolation result

The frozen M0-M3 cells remain GREEN. The original B0 and P0 controls remain
preserved as signal-11 evidence: both crashed with MCP disabled, no endpoint,
and no wrapper request. Windows reported access violation `0xc0000005` at the
same fault offset during full-project texture post-import reconfiguration.
Neither the final HDR path nor any single imported texture is claimed as the
individual root cause.

The ten parse diagnostics were mapped to five root files and repaired under the
bootstrap exception. Their five failed loads were consequential, not five more
roots. A fresh PR77 recovery import then completed with zero parse errors, zero
failed loads, and zero signal 11. The nine pathless Unicode/NUL messages remain
reproducible without MCP; they are classified as Godot UTF log-rendering
diagnostics because they identify no path or failed load and do not prevent a
complete import.

## Lifecycle hardening

Fresh caches now use two processes. A plugin-disabled `--import
--recovery-mode` process completes the heavy import with endpoint count zero.
Only after exit code 0 does a distinct editor PID start the MCP addon and
endpoint. Initial scan and reload remain single-flight asynchronous operations,
all mutation requests require request IDs, and the wrapper independently owns
editor/endpoint liveness detection.

Final self-tests were GREEN:

- Minimal: recovery PID 30112, editor PID 33424, endpoint 8846, two reloads.
- origin/main: recovery PID 9508, editor PID 31064, endpoint 8847, two reloads.
- PR77 candidate: recovery PID 30548, editor PID 32416, endpoint 8848, two reloads.

All three stopped cleanly with zero remaining task process.

## PR77 retrospective acceptance

The PR77-derived candidate validated 15/15 target scripts and loaded 5/5 target
scenes. `main.tscn` instantiated, emitted nine distinct running heartbeats
(a conservative nine-frame lower bound), and exposed 929 runtime nodes. The
registry bench passed 48/48 checks and attested all 19 owner bindings.

Acceptance then stopped on the first focused-bench failure:
`CardInventoryRuntimeCharacterizationBench` line 927 calls `_new_game`, but the
same PR77 `main.gd` has no such method. Those two files are byte-identical from
PR77 through the tested candidate, so this is an existing PR77 bench/runtime
contract error, not an MCP, cache, parse-root, or bootstrap-repair regression.
The remaining focused benches were not run after the stop gate.

No Session, Save, gameplay, `main.gd`, `main.tscn`, V0.7.3, PR80, or PR82 code
was changed. V8, Process A, Formal, FullRun, Smoke, and `smoke_test.gd` were not
started.

Next task:

`ALPHA_0_4_C_PR77_MCP_ATTESTED_CARD_INVENTORY_RUNTIME_CHARACTERIZATION_BENCH_REPAIR`
