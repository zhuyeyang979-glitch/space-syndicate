# Alpha 0.4-C V5 Repository HEAD Lineage Matrix

STATUS=ROOT_CAUSE_ATTESTED

REPOSITORY_HEAD_LINEAGE_STAGE_COUNT=10

FIRST_REPOSITORY_HEAD_LOSS_STAGE=gdscript_validate_options_success_projection

FIRST_REPOSITORY_HEAD_LOSS_REASON=validated_options_projection_omits_head_sha

TYPED_ROOT_CAUSE=GDSCRIPT_VALIDATE_OPTIONS_SUCCESS_PROJECTION_OMITS_HEAD_SHA_THEN_OPTION_BINDING_GET_MATERIALIZES_NULL

## Finding

The V5 repository HEAD does not disappear in Git, the PowerShell runtime
freeze, authorization/admission, the quota ledger, Launch Attestation, the
child command line, or the GDScript argument parser. All of those boundaries
carry the correct string:

`604264b0af9a10ca07db58851e8a2d00171dd2f3`

The first loss is the success return built by `validate_options()` in
`cold_restore_vertical_slice_driver.gd`. The function reads and validates
`options.head_sha`, including the run-ID/HEAD binding, but constructs a fresh
Dictionary at lines 848-872 without copying `head_sha`.

The child then calls `_authorize_targeted_owner_capture_diagnostic()` with:

- `validation`, the projected Dictionary that lacks `head_sha`; and
- a separate, correct `parsed.head_sha` string.

The separate string is used for later Launch Attestation checks. It is not
inserted into the Dictionary passed to the canonical ledger validator. The
binding contract correctly maps `ledger.repository_head` to
`options.head_sha`; `options.get("head_sha")` therefore resolves the absent key
to `null`.

This produces the retained V5 fingerprints:

- actual quoted HEAD string:
  `066a10f78e771c6f8a42a3f08260af5f90075b02bdc49ac2ccf7054128afb215`
- expected canonical JSON `null`:
  `74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b`

The typed failure is field omission followed by a wrong-context read. It is
not an alias substitution, empty-value overwrite, JSON canonicalization
error, or ledger corruption.

## Lineage

| # | Stage | Wire name | Value | Result |
|---:|---|---|---|---|
| 1 | `git_head_resolution` | `HEAD` -> `$headSha` | correct 40-char lowercase hex string | PASS |
| 2 | `orchestrator_runtime_freeze` | `$ExpectedHead` / `observed_head` | correct and equal | PASS |
| 3 | `authorization_and_prequota_admission` | `$RepositoryHead` / `repository_head` | correct string | PASS |
| 4 | `quota_ledger_publication` | `repository_head` | correct JSON string | PASS |
| 5 | `launch_authorization_and_attestation` | `source_head_sha` | correct JSON string | PASS |
| 6 | `child_cli_argument` | `--cold-restore-head-sha=` | correct CLI string | PASS |
| 7 | `gdscript_option_parser` | `head_sha` | correct GDScript String | PASS |
| 8 | `gdscript_validate_options_success_projection` | `head_sha` | omitted; absent key becomes `null` | **FIRST LOSS** |
| 9 | `canonical_expected_binding_resolution` | `repository_head` -> `head_sha` | expected value resolves to `null` | FAIL |
| 10 | `ledger_validator_comparison` | ledger string vs option `null` | `repository_head_mismatch` | FAIL |

## Alias Audit

The aliases are internally consistent before the loss:

- PowerShell and evidence use `repository_head`.
- Launch authorization and Launch Attestation use `source_head_sha`.
- The child wire argument is `--cold-restore-head-sha`.
- The parser and binding option use `head_sha`.
- The ledger binding contract maps `repository_head` to `head_sha`.

`source_head_sha` is not the root cause. The retained Launch Attestation
contains the correct value, and the driver later compares it with the
separately supplied correct `head_sha`. However, ledger validation runs before
the Launch Attestation is read, so that alias cannot populate the missing
expected context. An implicit fallback from `source_head_sha` or a fresh Git
HEAD read would also violate fail-closed launch binding.

## Direct Evidence

- V5 ledger SHA-256:
  `b7e6c66852540c2b3066f86cd6e9c9d9454c185c4e8ed17d168c6b0dbf466742`
- Bootstrap admission SHA-256:
  `55f3d379723f157927d578ff48a916f71c78a61d30010024aa138d90039b5a52`
- Launch Attestation SHA-256:
  `f79cf007878789d3122b588309b99a27fc3231d897a058b85c7ea789ffe3ed1f`
- Child bootstrap heartbeat SHA-256:
  `72584bad8ac1213f44e6d16a5f0bb7cfd0997afcd7eb715e5dcbeaee5adb8503`
- Child phase timeline SHA-256:
  `55ed184bf930df7ef9b758c50208eac35b2328b1dbc61b57fc16d27c35e85e0c`
- Child stderr SHA-256:
  `00239926e319bb74605786764b6ea06479913b88ce13a1d91a0673200e0ec6fc`
- Parent Exit SHA-256:
  `8841a3859a0f849bff7b5f07751c9a89568c3a7648ce20b1dd377f1d344644e7`

The retained heartbeat and phase timeline both contain the correct
`repository_head` while reporting `child_bootstrap`. They are written from
`parsed.head_sha` before ledger authorization, independently proving that the
real child command line and parser did not lose the value.

## Why Existing Tests Missed It

The canonical validator tests and retained-ledger replay built an options
Dictionary directly from the ledger:

```gdscript
"head_sha": str(ledger.get("repository_head", ""))
```

That correctly tests the ledger contract, but bypasses the real
`parse_options -> validate_options -> authorization` projection. As a result,
those tests always supplied `head_sha` and could not detect its omission from
the successful `validate_options()` return value.

## Root-Cause Verdict

```text
LEDGER_REPOSITORY_HEAD_CORRECT=true
LAUNCH_SOURCE_HEAD_SHA_CORRECT=true
CHILD_CLI_HEAD_CORRECT=true
GDSCRIPT_PARSED_HEAD_CORRECT=true
FIELD_OMISSION=true
ALIAS_MISMATCH=false
DICTIONARY_NULL_OVERWRITE=false
WRONG_CONTEXT_READ=true
EXPECTED_VALUE_KIND=canonical_json_null
OWNER_FAILURE_CLAIMED=false
```

No replay, quota claim, diagnostic, Process A rehearsal, Session creation,
Owner Capture, or Save write was performed while producing this matrix.
