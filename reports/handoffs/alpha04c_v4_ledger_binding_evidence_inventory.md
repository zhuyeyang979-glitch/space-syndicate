# Alpha 0.4-C V4 ledger binding evidence inventory

The original V4 ledger and all launch-bound evidence needed to reconstruct the
child-bootstrap decision are retained. The ledger is exactly 2517 bytes and its
SHA-256 remains
`154ceedf4032404d4c7d355fbd775991e20d29299f6e05e3a8c8e70c64be208c`.

The retained chain includes bootstrap admission, final prequota attestation,
launch attestation, stdout, stderr, Parent Exit, the authorization contract,
the role timeout policy, the immutable Attempt 1 claim fingerprint, the exact
V4 orchestrator Git blob, and the exact child-validator Git blob.

The original run did not publish a separate argv artifact. Its 12 ordered user
arguments are nevertheless exactly reconstructable from the retained ledger,
launch-attestation location, and the unchanged deterministic
`New-ColdRestoreTargetedDiagnosticUserArgumentList` implementation. The
companion argument inventory records only argument names and SHA-256 value
fingerprints, so local paths and nonces are not exposed.

## Characterization

The legacy child accepted the ledger path, raw SHA-256, exact field set, and
Windows absolute paths. It then parsed each JSON number as a Godot `float` and
failed its first strict runtime-type predicate:

```text
FIRST_LEDGER_BINDING_MISMATCH_FIELD=schema_version
FIRST_LEDGER_BINDING_MISMATCH_REASON=godot_json_integer_materialized_as_float
EXPECTED_RUNTIME_TYPE=int
ACTUAL_RUNTIME_TYPE=float
```

The same latent mismatch affected the four quota counters and
`orchestrator_process_id`. No field value, path, nonce, ticks, SHA-256, or
scenario fingerprint mismatch occurred before this type check.

## Replay boundary

Replay copies the exact retained ledger bytes into a temporary isolated
directory and calls the same pure GDScript binding validator used by the child.
It does not import `main.tscn`, create a Session, claim quota, capture an Owner,
write a Save, or alter diagnostic history. Launch-attestation process identities
are deliberately not replayed because those PIDs and creation ticks describe
the completed V4 process tree.
