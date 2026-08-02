# Alpha 0.4-C MCP hardening and PR77 acceptance

Status: BLOCKED by one attested PR77 focused-bench error.

## Outcome

The MCP toolchain recovery is successful. Fresh-cache startup now uses a
plugin-disabled recovery import followed by a distinct MCP editor process.
Minimal, origin/main, and PR77 initial scans completed with no signal 11; both
reload operations completed in every self-test, duplicate request execution
remained zero, handler depth remained one, and all sessions stopped cleanly.

The original ten parse errors map one-to-one onto five root files. All ten are
gone after the authorized repairs, and the five failed script loads disappeared
with them. The nine pathless Unicode/NUL messages still reproduce in the
plugin-disabled recovery import, but identify no script or failed resource and
do not prevent scan completion; they are classified as Godot UTF log-rendering
diagnostics rather than MCP or interrupted-scan artifacts.

## Acceptance evidence

The PR77-derived candidate validated all 15 requested scripts and loaded all 5
requested scenes. `main.tscn` instantiated successfully and produced nine
distinct running MCP heartbeats at 119-121 FPS, establishing a conservative
nine-frame lower bound. The runtime bridge reported 929 nodes. The registry
bench passed 48/48 checks and attested all 19 Save Owner bindings.

The next focused step failed:

`scripts/tools/card_inventory_runtime_characterization_bench.gd:927` calls
`_new_game`, but `scripts/main.gd` has no such method. Both files are unchanged
between effective PR77 SHA `78c7770` and tested candidate `5aeb7960`, so the
failure is an existing PR77 bench/runtime contract mismatch. It is not caused
by MCP, a stale cache, the five parse-root repairs, or Session work.

The stop gate was honored: Monster, Execution, AI, and Victory focused benches
were not started after this error. Session v4, V8, Process A, Official Attempt
2, Formal, FullRun, Smoke, and `smoke_test.gd` were not run.

## Scope and cleanup

No gameplay, Save schema, Save Owner, `main.gd`, `main.tscn`, V0.7.3, PR80, or
PR82 code changed. The fresh scan produced 285 status entries; all 285 were
explicitly manifested before cleanup. Fifty-seven tracked importer changes
were restored and 228 generated UID files were removed individually. No user
file or unmanifested file was deleted. The acceptance worktree is clean, and
the editor PID and port both returned to zero.

Next task:

`ALPHA_0_4_C_PR77_MCP_ATTESTED_CARD_INVENTORY_RUNTIME_CHARACTERIZATION_BENCH_REPAIR`
