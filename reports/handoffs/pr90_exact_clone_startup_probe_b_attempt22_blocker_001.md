# PR #90 Exact Clone Probe B / Attempt 22 blocker handoff

Status: **BLOCKED**

Probe 004 proved the repaired endpoint contract on its controlled fixture, but it was not sufficient authority for the full PR #90 clone. The newly authorized Probe B reached M5 on the exact product clone and failed closed because the two independent listener observers produced no parity sample. No JSON-RPC request was sent, so the failure is still entirely inside endpoint startup characterization.

## Tooling repair and sealed identity

All eight previously missing capabilities were added in one commit: the top-level Probe B controller, Result and Attestation builders, import-finalizer binding, zero-process Preformal V2, and Attempt 22 Manifest/Validator/Seal builders with negative tests.

- Base Tooling: `7eda5b355759dbad952beeebd16e3b2d3b20b4f0`, tree `41c9cd45e57e987036102dcf10cd1c34385f864b`
- New Tooling: `c9508c47f0aec647151dfb4ae58a720014ab3702`, tree `59e25856a0f1e4508789ca3fb278d26104621602`
- Parent: `7eda5b355759dbad952beeebd16e3b2d3b20b4f0`
- Remote branch: `codex/pr90-probe-b-attempt22-tooling-7eda5b35`
- Tooling Manifest SHA-256: `d884dddb3aa47bafcfbad90685913cc4153143428b9ea1231df33e69ff21248e`
- Tooling Seal SHA-256: `35f71a043bd3db3f0aa80bedfc3f45ec2bea9adfe178240e9c639fac2d078387`
- Self-tests: base 104/104 plus new 66/66, total 170/170; negative tests 25/25; parse and parameter-binding failures 0
- Tooling commits: exactly 1; Tooling remained clean after seal and push
- Product code/test changes: 0/0; PR #90 product HEAD changes: 0

The historic preflight blocker (`eb2c61ca977e428a6f0c96ff55d2bb529ee32dad79cd7a8edc285ce25bc9f3f4`), Probe 004, all older attempts, and the 313-change legacy worktree remain untouched.

## Unique Probe B result

- Probe ID: `pr90-exact-clone-startup-probe-b-001`
- Execution count: 1; retry allowed: false
- Product: `770d741f05964facda4afcbddcdeb3e7f40571d5`, tree `f5bb584ceea065b13c9b5621b1976af7907c62ad`
- Milestones: 5/12 PASS; M5 receipt failed
- Failure: `STARTUP_M5_ENDPOINT_OWNERSHIP_V2_FAILED`
- Detail: `STARTUP_M5_ENDPOINT_LISTENER_OBSERVER_DISAGREEMENT`
- Listener samples: 23 total, 0 dual-source parity, 0 ms stable window
- Endpoint owner proved as GUI engine: false
- First JSON-RPC request/response: false/false
- Raw MCP evidence, runtime bootstrap, ready witness, Phase 0: false/false/false/false
- `play_main_scene`, `main.tscn`, product match, product frame, formal product result: all 0
- State-machine Result SHA-256: `1f070063c72d00e844a8a3c81d96845aef9567d5ed3c9192a0ba63336014c2ae`
- Probe B Result SHA-256: `07e482e9f70ae92ceb5c1167d3221d5f816bfb078306828d7e733743b6452ca0`
- Probe B Attestation: not created because Result was BLOCKED

The M5 failure path omitted `connection.json` and left the verified Probe GUI process holding the controller output pipe. A single identity-checked Windows normal-close request completed cleanup; no force-stop was used. The state-machine's `stopped_cleanly` field therefore remains false, while the later terminal manifest proves zero Godot/MCP processes and zero listeners on 7576/7586. Cleanup recovery receipt SHA-256: `dcb2947329df86c5a4b157e14cbe5b38402ef5f4d1161c8c3f0e063183e6a590`.

Canonical import and the same formal Finalizer completed successfully:

- Post-import baseline SHA-256: `3869ee22f79e1429ef81024e22d651234699a94205d4a04cce2fcb8d88849fd2`
- Finalizer status: PASS; SHA-256 `870936260b7a32642c6a648afe3c9037e4bec962389ad518ef53b4079b37d5c1`
- Terminal manifest status: PASS; SHA-256 `68b8e213e51b0dac95b9014014cf86edfa245cb522d5edc4ac5799ce707d13b9`
- Godot/MCP/7576/7586 after cleanup: 0/0/0/0
- Unrelated process termination count: 0

## Authorized downstream stages not run

Preformal V2 was prohibited after Probe B failed and therefore has execution count 0. Attempt 22 Manifest/Validator/Seal, the Exact-SHA MCP authorization request, and the fast-release-chain prompt were not generated. Formal MCP execution and authorized-run consumption remain 0; Exact-SHA MCP remains `NOT_STARTED`.

Next task: `PR90_PROBE_B_ENDPOINT_STARTUP_M5_ENDPOINT_LISTENER_OBSERVER_DISAGREEMENT`
