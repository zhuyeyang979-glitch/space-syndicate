# PR90 Probe B V2 Result Builder blocker

Status: **BLOCKED**. The one authorized Probe B V2 was consumed exactly once. It completed the M0-M11 runtime chain, normal shutdown, terminal verification, and Import Finalizer, but the sealed Result Builder then failed under PowerShell StrictMode before it could write the immutable Probe B V2 Result and Attestation. The Probe was not retried, the Tooling Seal was not changed, and Preformal/Attempt22 were not started.

## Frozen 23-sample finding

The two observers actually saw the same listener in all 23 frozen samples. Their five-field Listener Core was identical: address family, normalized address, protected port, canonical LISTEN state, and PID. There was no real address, port, state, or PID difference, and the old six-field canonical keys were also equal in all 23 samples.

The old validator reported 0/23 parity because Source B read all `netstat` rows on the protected port and sent two `TIME_WAIT` rows per sample to a listener-only normalizer. Source A had already selected LISTEN rows. Source B therefore accumulated 46 parse failures, and the old validator treated any parse failure as a parity failure. The first failing path was `source_b.parse_failure_count`. Root cause is `J`, combining `F_SOURCE_FILTER_SCOPE_MISMATCH` and `I_LOCALIZED_NETSTAT_OR_SOURCE_PARSER_DRIFT`.

`owner_creation_time_filetime_utc` was an inappropriate process-enrichment field in the old cross-source key, but it did not differ in these samples and was not the cause of 0/23. Observer source, timestamps, sample IDs, raw fingerprints, command line, and parent-chain fields were not admitted to the new Core key.

The frozen field-diff matrix is at `C:\pr90-probe-b-listener-parity-v2-forensics-001`. Its JSON SHA-256 is `9d95f7af6d4784b7ee218a570e2a668567e7d6ac58e7194b5863f5fdd6610f3f`. Existing evidence was sufficient, so no characterization Probe was run.

## Listener Parity V2 and Tooling identity

The repair compares an exact five-field Listener Core first, then performs one shared Process Identity enrichment only after Core equality. It uses A-before/B/A-after bracketed cohorts, preserves all source-specific raw evidence, classifies protected-port known non-listener rows without treating them as listener parse failures, fails closed on unknown states, and gives each observer a hard bounded timeout.

The single new Tooling commit is `2ebb2df9a1c649e8527b045939e9d6e47b98f17c`, tree `c8c8df008ca8af433b95e6fe092e02fb03d2cda0`, parent `c9508c47f0aec647151dfb4ae58a720014ab3702`. It was pushed without force to `codex/pr90-probe-b-listener-parity-v2-2ebb2df9`. The Tooling manifest SHA-256 is `5996135ef5828c6a6878368171e48c29dca29b64a14fa722f000be5f249d3624`; the Seal SHA-256 is `627a48738db394face2dd3291c56c574c96f8dd47210ccb592b82b9474aab049`. The frozen 170 tests plus 60 new tests passed, for 230/230 with zero failures.

## Unique Probe B V2 runtime result

Probe `pr90-exact-clone-startup-probe-b-v2-001` ran once at `C:\pr90-exact-clone-startup-probe-b-v2-001`.

- Startup state machine: PASS, M0-M11 = 12/12, ordered with zero gaps and duplicates. Result SHA-256: `2244d86e971488aff3b6631aef28edee04109fa25e7f62c9671599a10d9fcb2f`.
- Listener cohorts: 5 attempted, 5 consecutive stable parity cohorts, 4109.559 ms stable window, zero unstable cohorts, timeouts, parse failures, or unknown protected-port states. Cohort evidence SHA-256: `29a7d2dcfb1dec4dbd4f5a384eef044f61b4d265dc06e2d1537708b16b22ef9c`.
- Endpoint owner: GUI Engine=true, Console Wrapper=false, launcher descendant=true, project/session/Windows session/SID/creation identity all match; no PID, identity, lineage, multiple-owner, or foreign-listener drift. Endpoint attestation SHA-256: `9b38550dbaaff543a7cbde2a6ee7dfdc8d0b9818d90bd77c8d4bf8e4d0e2653b`.
- M6-M11: first JSON-RPC request and response, raw evidence, runtime bootstrap, ready witness, and Phase 0 evidence all persisted.
- Main scene/product: `play_main_scene=0`, `main.tscn` instances=0, product matches/frames/formal product results=0. The only play request used `res://scenes/runtime/ActionResultPresentationService.tscn` in custom mode.
- Shutdown: normal close succeeded; forced stop=false; no manual cleanup and no unrelated process termination.
- Import Finalizer: PASS, SHA-256 `80e7ddd4aa959f69b5108c22f42cf4cc25c7ed0ae8b744620f225978ddac26d6`; all post-run product/import/unknown-delta counts are zero.
- Terminal manifest: PASS, SHA-256 `f6bc95bdec66c50e372ad761fbfa45b1b22a7f7746730e8f6a7281bb75174477`; Godot/MCP/worker processes and ports 7576/7586 are all zero.

## Blocking defect and stop point

The sealed `tools/pr90_exact_clone_probe_b_result_builder_v1.ps1` (SHA-256 `5a31120f378f9663cdfbbe4f37192283d19b5993200cc1371908d24637ace60f`) evaluates every request at line 52 with direct optional-property access:

```powershell
[string]$_.params.arguments.scene_path
```

Requests such as `get_project_info` do not have `scene_path`. Under StrictMode this raised `PropertyNotFoundStrict`, and the controller exited with code 1. Consequently, `pr90_exact_clone_startup_probe_b_v2_result.json` and `pr90_exact_clone_startup_probe_b_v2_attestation.json` do not exist. Runtime evidence cannot be promoted to contractual GREEN without those artifacts.

Per the authorization, the sealed Tooling was not modified after this discovery, no second Probe was created, Preformal execution count remains 0, no Attempt22 manifest/seal exists, and formal Exact-SHA MCP remains NOT_STARTED with authorization consumption 0.

## Next task

`PR90_PROBE_B_V2_RESULT_BUILDER_OPTIONAL_SCENE_PATH_STRICTMODE_TOOLING_REPAIR_AND_APPEND_ONLY_RESULT_ATTESTATION_RECOVERY_AUTHORIZATION`

That authorization should create a new Tooling identity for safe optional-property handling and explicitly permit append-only construction and validation of Result/Attestation from the already frozen Probe B V2 evidence. It must not authorize a Probe rerun or mutation of the existing Tooling Seal.
