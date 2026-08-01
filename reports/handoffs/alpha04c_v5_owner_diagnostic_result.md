# Alpha 0.4-C V5 Owner Diagnostic Result

STATUS=BLOCKED_BY_V5_PRE_OWNER_REPOSITORY_HEAD_BINDING

V5 ran exactly once from clean, remotely checkpointed HEAD
`604264b0af9a10ca07db58851e8a2d00171dd2f3`. The exact-once quota moved
from `4` to `5` and is consumed at SHA-256
`b7e6c66852540c2b3066f86cd6e9c9d9454c185c4e8ed17d168c6b0dbf466742`.
It was non-official, non-formal, and wrote no Save.

## Result

Godot launched, but the real child bootstrap rejected the ledger before
scenario identity, Registry binding, or Owner Audit. Parent Exit observed
exit code `2`, no timeout, no parent termination, and zero remaining
task-owned processes. Child Completion was not written.

The first rejected field is `repository_head`:

- ledger value: the correct string
  `604264b0af9a10ca07db58851e8a2d00171dd2f3`
- actual safe fingerprint:
  `066a10f78e771c6f8a42a3f08260af5f90075b02bdc49ac2ccf7054128afb215`
- expected safe fingerprint:
  `74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b`
- typed reason: `repository_head_mismatch`

The actual fingerprint is the canonical JSON fingerprint of the quoted HEAD
string. The expected fingerprint is the canonical JSON fingerprint of
`null`. Therefore the ledger bytes are not wrong at this field; the expected
repository-head option was not populated in the real child-bootstrap path.

This is a pre-Owner architecture failure:

- `SCENARIO_IDENTITY_ATTESTED=false`
- `REGISTRY_BINDING_ATTESTED=false`
- `OWNER_AUDIT_STARTED=false`
- `OWNER_AUDIT_COMPLETED=false`
- `REGISTRY_OWNER_CAPTURE=0/19`
- `FAILING_SECTION_ID=NOT_ATTESTED`
- `FAILING_OWNER_ID=NOT_ATTESTED`
- `FAILING_REASON_CODE=NOT_ATTESTED`

No Save Owner failure is claimed.

## Gates Before V5

- PowerShell preflight matrix: `11/11`
- canonical binding contract: `21/21`
- retained V4 replay: `96/96`
- real top-level import chain: `3/3`
- non-consuming preflight: `3/3`
- targeted diagnostic schema: `193/193`
- targeted launch authorization: `43/43`
- Process A launch authorization: `55/55`
- production Registry transaction: `59/59`
- Registry Owner preflight: `19/19`
- V0.6 Registry: `12/12`
- heartbeat: `7/7`
- engine `--check-only`: PASS
- `git diff --check`: PASS

V4 remains immutable at ledger SHA-256
`154ceedf4032404d4c7d355fbd775991e20d29299f6e05e3a8c8e70c64be208c`.

## Hard Stop

Process A was not started because V5 did not reach `19/19`. Official Attempt
2 remains absent and its authorization remains unconsumed. Process B/C did
not start. No V6 authorization was created, and this task performed no Formal
FullRun or full Smoke.

NEXT_ALPHA04C_TASK=
`ALPHA_0_4_C_POST_CANONICAL_PRE_OWNER_FAILURE_ARCHITECTURE_REVIEW`
