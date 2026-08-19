# PR90 Attempt 20 startup forensics

Attempt 20 remains permanently frozen. Its only formal authorization was consumed, and no file under `C:\pr90-a20b\future-formal-evidence-001` was changed or backfilled.

The evidence proves that Godot was created, but it does not prove the historical state of the endpoint, endpoint owner, first request, or first response. Empty `mcp-raw` and `phases` directories therefore do not establish that no request was sent.

The confirmed tooling root cause is `J=RUNBOOK_WAIT_LOOP_OR_TIMEOUT_STATE_MACHINE_DEFECT`. The old runbook synchronously waited for a launcher that combined M4 through M7 in one loop, swallowed the individual errors, and had neither a wrapper timeout nor intermediate receipts. A controlled three-process reproduction did not reproduce the proposed K-class inherited stdout/stderr handle stall, so K is not claimed as proven.

Exact frozen witness:

- Path: `C:\pr90-a20b\future-formal-evidence-001\exact-sha-mcp-failure.json`
- SHA-256: `2bd4270a3c0645451e143aa4e0bdfa2c3879a915e9f261fdab62bee8515c0324`
- Bytes: `1173`
- JSON parse: green

The strict ordered history is M0 proven, M1 missing, M2 independently supported by the failure witness and Godot log, and M3-M7 historically unresolvable. M8-M11 were not persisted. `play_main_scene` was not reached.
