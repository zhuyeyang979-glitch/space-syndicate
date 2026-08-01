# Alpha 0.4-C V5 Repository-Head Evidence Inventory

STATUS=COMPLETE_WITH_RECONSTRUCTABLE_RUNTIME_CAPTURE_GAPS

This inventory was built read-only from the retained V5 evidence under the Git
common directory and tracked code at inspected HEAD
`d84739100905a7ef28f9e4859415bce6927509e9`. No diagnostic, Process A,
session, Save, smoke, or other runtime was started.

## Summary

- Required artifacts inventoried: `16/16`
- Retained files or Git-backed objects: `11/16`
- Standalone runtime capture gaps: `5`
- Critical gaps for reconstructing `repository_head` lineage: `0`
- V5 ledger bytes retained: `true`
- V5 child arguments semantically reconstructable: `true`
- V5 child options reconstructable: `true`
- Child stderr retained: `true`
- Parent Exit retained: `true`

The exact retained ledger is 2562 bytes at SHA-256
`b7e6c66852540c2b3066f86cd6e9c9d9454c185c4e8ed17d168c6b0dbf466742`.
All host paths below use `<git-common-dir>` or `<project-root>`. Nonces are not
copied into this report.

## Artifact Inventory

| # | Artifact | Exists | SHA-256 | Schema | Replay use |
|---:|---|:---:|---|---:|---|
| 1 | V5 quota ledger raw bytes | yes | `b7e6c668...466742` | 4 | Copy-only pure replay |
| 2 | V5 quota ledger SHA-256 claim | yes | `b7e6c668...466742` | 1 | Fingerprint check |
| 3 | Authorization contract | yes | `a7c4bf60...83d36` | 1 | Pure replay input |
| 4 | Bootstrap admission | yes | `55f3d379...b5a52` | 1 | Review only |
| 5 | Prequota attestation | yes | `6f5ebf66...95a576` | 1 | Review only |
| 6 | Launch attestation | yes | `f79cf007...fed1f` | 1 | Review only; process identity is stale |
| 7 | Original Orchestrator command line | no standalone artifact | n/a | n/a | Semantic reconstruction only |
| 8 | PowerShell runtime argument list | no standalone artifact | n/a | n/a | Deterministic reconstruction |
| 9 | Child raw argv snapshot | no standalone artifact | n/a | n/a | Deterministic reconstruction |
| 10 | Full GDScript parsed-options dictionary | no standalone artifact | n/a | n/a | Deterministic reconstruction |
| 11 | Full GDScript expected-binding dictionary | no standalone artifact | n/a | 1 | Deterministic reconstruction |
| 12 | Child stdout | yes | `bb3bcf71...2ed1d` | n/a | Review only |
| 13 | Child stderr | yes | `00239926...ec6fc` | n/a | Characterization evidence |
| 14 | Parent Exit | yes | `8841a385...644e7` | 2 | Review only |
| 15 | V5 run code HEAD | yes | `bbf7b6d5...d24df` | Git commit | Pure replay code identity |
| 16 | Validator code HEAD | yes | `2950afd2...a76bf` | 1 | Pure replay implementation |

The JSON companion contains the complete producer, consumer, schema,
immutability, safe-replay, and notes fields for every row.

## Safe Argument Reconstruction

The original top-level shell command string was not recorded. Its semantic
identity is nevertheless cross-attested: targeted mode, run ID, repository
HEAD, scenario fingerprint, authorization, clean remote checkpoint, launch,
and terminal exit all survive in hashed evidence.

The child argument vector is deterministically reconstructed from
`New-ColdRestoreTargetedDiagnosticUserArgumentList` and
`New-ColdRestoreGodotArgumentList`. The repository-head segment was:

```text
--cold-restore-head-sha=604264b0af9a10ca07db58851e8a2d00171dd2f3
```

The remaining sensitive segments are represented as:

```text
--path <project-root>
--cold-restore-targeted-diagnostic-ledger-path=<git-common-dir>/codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v5-canonical-binding/targeted_owner_capture_quota_ledger.json
--cold-restore-launch-attestation-path=<git-common-dir>/codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v5-canonical-binding/evidence/launch/orchestrator-<orchestrator-id>/producer.authorized.json
--cold-restore-launch-nonce=<redacted-lower-hex-32>
```

The full safely redacted ordered vector and reconstructed PowerShell/GDScript
contexts are in the JSON companion.

## Repository-Head Evidence

The retained artifacts establish these facts without another diagnostic:

1. Bootstrap admission, prequota attestation, and ledger contain the correct
   `repository_head` string.
2. Launch attestation contains the same value under `source_head_sha`.
3. The raw child CLI maps it to `--cold-restore-head-sha`.
4. `_parse_options` maps that argument to `head_sha`.
5. The child heartbeat and both phase timelines contain the correct HEAD,
   proving parsing succeeded before ledger binding.
6. The binding contract maps ledger `repository_head` to option `head_sha`.
7. `validate_options` does not include `head_sha` in its returned dictionary.
8. The validator calls `options.get("head_sha")` without a default and obtains
   `null`.
9. Retained stderr fingerprints the actual string as `066a10f7...afb215`
   and expected canonical JSON `null` as `74234e98...2b90b`.

This inventory records those facts but does not modify the lineage or
validator implementation.

## Exact Evidence Gaps

Five runtime values were not independently serialized:

1. The byte-exact top-level PowerShell command line, including original
   quoting and parameter order.
2. The in-memory PowerShell user-argument list object.
3. The child process's raw argv snapshot.
4. The complete GDScript parsed-options dictionary.
5. The complete GDScript canonical expected-binding dictionary.

These are non-blocking for the `repository_head` review because immutable
source deterministically reconstructs them and retained child evidence proves
the critical intermediate value. No nonce, private host path, or private game
state is reproduced in this inventory.
