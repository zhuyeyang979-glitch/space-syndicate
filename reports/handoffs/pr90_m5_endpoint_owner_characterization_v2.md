# PR90 M5 endpoint-owner characterization V2

Status: BLOCKED. The one authorized probe `pr90-m5-endpoint-owner-characterization-v2-001` was consumed exactly once and was not retried.

The external formatter/tooling repair itself is sealed at tooling HEAD `c1653efd87a3fa89debe942389e866805ce807fa` / TREE `83bf913000657e7df551302014d044a63e0fe0e4`. Its pure observer self-test is PASS, 43/43. The frozen formatter defect is the PowerShell command-invocation argument collapse; the frozen evidence did not persist raw TypeNames, so the report keeps the historical input type as `NOT_PERSISTED_IN_FROZEN_EVIDENCE` and records the reconstructed post-adapter shape separately.

The characterization controller persisted M0 but left its canonical payload field empty, then failed before M1 execution-start persistence with a `Count` property exception. No Godot process was created, no 7576/7586 listener remained, no endpoint request or JSON-RPC was sent, and no M6–M11 activity occurred. The new root contains append-only failure, terminal, result, and blocked-attestation evidence; it does not contain fabricated MCP raw or phase evidence.

Owner identity, dual-source parity, stable-window evidence, and root cause D are therefore `NOT_RUN` / not formally attested. The next task requires a new authorization for the controller receipt/cardi­nality fix; this sealed tooling, this probe authorization, and the old characterization root must not be reused.
