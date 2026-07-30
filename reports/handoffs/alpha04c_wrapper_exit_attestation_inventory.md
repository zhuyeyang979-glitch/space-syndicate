# Alpha 0.4-C Wrapper Exit Attestation Inventory

```text
TASK_ID=ALPHA_0_4_C_OFFICIAL_PREFLIGHT_WRAPPER_EXIT_ATTESTATION_REPAIR_AND_REAUTHORIZED_COLD_CHAIN
AUDITED_HEAD=092ee75d95a4e47030e03dfc007dd80f40829577
INVENTORY_STATUS=COMPLETE_BEFORE_HARNESS_MODIFICATION
WRAPPER_CURRENTLY_WAITS_FOR_CHILD_EXIT=true
WRAPPER_CURRENTLY_PROPAGATES_EXIT_CODE=false
CHILD_FLUSHES_ATTESTATION_BEFORE_QUIT=false
PARENT_VERIFIES_ATTESTATION_AFTER_EXIT=false
PARENT_VERIFIES_PROCESS_TREE_CLEAN=false
BLOCKED_QUALIFICATION_DISTINGUISHED_FROM_HARNESS_FAILURE=false
```

## Scope

This is a read-only pre-change inventory of the Alpha 0.4-C QA Harness. It does
not authorize or modify CardResolutionQueue, facility action routing, gameplay
legality, content, Save sections, RNG, V0.7 rules, or any production scene.

## Owner Map

| # | Owner / role | Current path | Current contract | Required repair |
|---|---|---|---|---|
| 1 | Official chain Orchestrator | `scripts/tools/cold_restore_vertical_slice_orchestrator.ps1` | Sequential direct-child `Start-Process -Wait`; generic nonzero failure | Preserve exact child result and produce parent attestation |
| 2 | Non-official qualification Wrapper | Not implemented as a dedicated mode | Qualification is launched directly | Route qualification through the shared attested process helper |
| 3 | Qualification child | Driver `_run_qualification_probe()` | stdout marker; product false exits one | Atomic child attestation; product false exits zero |
| 4 | Process A child | Driver `_run_producer()` | Direct public-manifest write | Child completion proof before quit |
| 5 | Process B child | Driver `_run_consumer()` | Direct public-manifest write | Child completion proof before quit |
| 6 | Process C child | Driver `_run_validator()` | Direct public-manifest write | Child completion proof before quit |
| 7 | stdout/stderr capture | Orchestrator `Invoke-ColdRestoreRole()` | Redirected files with no digest | SHA-256 and closed-handle evidence |
| 8 | Child completion artifact | Driver `_write_public_manifest()` | Role-only direct final-path write | temp, flush, close, readback, fingerprint, atomic replace |
| 9 | Parent exit attestation | Missing | No durable parent proof | `ParentExitAttestationV1` after observed exit |
| 10 | PID/process-tree cleanup | Missing for this chain | Direct child only | Task-owned descendant inventory and zero-residue gate |
| 11 | Official run count | Gate cache and handoff declarations | Report-only count zero | Atomic exact-once ledger before an authorized official launch |
| 12 | Evidence directory | Split between child `user://` and parent `.godot` roots | No single completion binding | Bind paths, run id, role, HEAD, and fingerprints |

The machine-readable inventory records the required input arguments, output
artifacts, exit, timeout and cleanup contracts, current failure mode, test
coverage, and modification decision for every row.

## Root Cause

The existing parent does wait for the direct child and then reads its exit code,
but it collapses every nonzero result into `<role>_process_failed` and trusts a
stdout marker as the manifest source. The child role path flushes and closes a
direct final-file write without readback or atomic replacement; the qualification
path writes no artifact at all. Qualification then maps `success=false` to exit
code one, so a lawful `queue_count=0` product blocker is indistinguishable from a
Harness crash or incomplete evidence write.

## Repair Boundary

The repair must remain inside the QA Driver, Orchestrator, attestation helpers,
focused tests, and handoff evidence. The required end state is:

```text
HARNESS_COMPLETE + PRODUCT_QUEUE_BLOCKED => EXIT_CODE=0
WRAPPER_EXIT_ATTESTATION_GREEN=true
PRODUCT_QUEUE_QUALIFICATION_GREEN=false

HARNESS_INCOMPLETE => EXIT_CODE!=0
WRAPPER_EXIT_ATTESTATION_GREEN=false
PRODUCT_QUEUE_QUALIFICATION_STATUS=UNTRUSTED
```

No official A/B/C authorization may be consumed until the shared Wrapper,
short gates, and one non-official qualification result are all trusted and the
product queue count is at least one.
