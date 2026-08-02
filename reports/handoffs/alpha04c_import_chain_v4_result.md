# Alpha 0.4-C import-chain V4 result

## Verdict

Lane A repaired the PowerShell module lifetime defect and proved the real
top-level import chain in three fresh processes. The exact non-consuming
preflight also passed three fresh processes with zero quota, diagnostic, Godot,
Save, or formal-root side effects.

The one authorized V4 diagnostic then consumed the exact 3-to-4 quota and
launched Godot at the clean remote checkpoint
407cbb4501cf6480cd8752dc52d06e2fccceda0e.

The diagnostic did not reach Owner capture. Godot rejected the launch during
child_bootstrap with:

~~~text
targeted_owner_capture_ledger_binding_invalid
~~~

The wrapper observed exit code 2. It did not time out and was not terminated by
the parent. No Save or Child Completion Attestation was produced, and the
task-owned process count returned to zero.

## Exact boundary

~~~text
TARGETED_OWNER_CAPTURE_DIAGNOSTIC_COUNT_BEFORE=3
TARGETED_OWNER_CAPTURE_DIAGNOSTIC_COUNT_AFTER=4
DIAGNOSTIC_V4_QUOTA_CLAIMED=true
GODOT_LAUNCHED=true
SCENARIO_IDENTITY_ATTESTED=false
REGISTRY_BINDING_ATTESTED=false
OWNER_AUDIT_STARTED=false
OWNER_AUDIT_COMPLETED=false
REGISTRY_OWNER_CAPTURE=0/19
FAILING_SECTION_ID=NOT_ATTESTED
FAILING_OWNER_ID=NOT_ATTESTED
FAILING_REASON_CODE=NOT_ATTESTED
PRIMARY_FAILURE_PHASE=child_exit_observation
PRIMARY_FAILURE_CODE=child_process_exit_nonzero
CHILD_STDERR_REASON_CODE=targeted_owner_capture_ledger_binding_invalid
PROCESS_A_SAVE_COMPLETION_REHEARSAL_COUNT=0
NO_AUTOMATIC_V5_DIAGNOSTIC=true
~~~

The V4 ledger SHA-256 is
154ceedf4032404d4c7d355fbd775991e20d29299f6e05e3a8c8e70c64be208c.
The Parent Exit Attestation SHA-256 is
bd225239252f9682958cc87d1a27024f6043d6863a766881df678836a99b5e3d.

Attempt 1 remains immutable at
80979cf3089e46ebff6025253126b57c1dd4e522cc5f858be8d4f5915ed17458.
Attempt 2 was not created, and its authorization remains unconsumed. Process B,
Process C, a third Formal run, FullRun, and full Smoke were not started.

## Next task

The authorized next Alpha 0.4-C task is:

~~~text
ALPHA_0_4_C_HARNESS_MODULE_ARCHITECTURE_EVIDENCE_REVIEW
~~~

It must inspect the PowerShell-to-Godot V4 quota-ledger wire binding from the
retained evidence. This task does not authorize a V5 diagnostic or a retry.
