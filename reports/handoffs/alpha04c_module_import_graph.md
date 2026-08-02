# Alpha 0.4-C PowerShell module import graph (before repair)

## Audit boundary

This is a read-only Lane A audit at
`413a08458369fbda8b304a50d607525ad297353d`. It covers exactly these six
runtime files:

1. `scripts/tools/cold_restore_vertical_slice_orchestrator.ps1`
2. `scripts/tools/cold_restore_prequota_bootstrap.psm1`
3. `scripts/tools/process_a_rehearsal_admission_contract.psm1`
4. `scripts/tools/cold_restore_attested_process.psm1`
5. `scripts/tools/cold_restore_authorization_contract_v1.psm1`
6. `scripts/tools/cold_restore_official_attempt2_contract.psm1`

The worktree was clean when the source bytes and hashes were captured. Later
concurrent implementation changes in the same worktree are intentionally
excluded; all `BEFORE` facts in this report refer to the clean `413a084`
snapshot.

No production diagnostic, quota claim, Godot launch, Process A rehearsal, or
official cold-restore attempt was run. The only dynamic check imported the five
modules in a disposable PowerShell process and observed command/module identity;
it did not execute the orchestrator.

```text
RUNTIME_IMPORT_FORCE_COUNT_BEFORE=8
RUNTIME_LOCAL_FORCE_IMPORT_COUNT_BEFORE=1
RUNTIME_EFFECTIVE_MODULE_LOCAL_FORCE_IMPORT_COUNT_BEFORE=2
AMBIENT_SCRIPT_SCOPE_COMMAND_DEPENDENCY_COUNT_BEFORE=33
AMBIENT_SCRIPT_SCOPE_COMMAND_CALL_SITE_COUNT_BEFORE=91
ALL_AUDITED_UNQUALIFIED_CROSS_MODULE_DEPENDENCY_COUNT_BEFORE=53
ALL_AUDITED_UNQUALIFIED_CROSS_MODULE_CALL_SITE_COUNT_BEFORE=134
```

`RUNTIME_LOCAL_FORCE_IMPORT_COUNT_BEFORE` counts the one import with both an
explicit `-Force` and an explicit `-Scope Local`. The effective count is two
because the admission module's authorization import also uses `-Force` from
module scope with the default local scope.

`AMBIENT_SCRIPT_SCOPE_COMMAND_DEPENDENCY_COUNT_BEFORE` counts distinct
`(orchestrator, external command)` dependencies resolved by unqualified command
lookup in the orchestrator script scope. The 33 dependencies have 91 call sites.
Across all six callers there are 53 distinct unqualified caller/command pairs
and 134 call sites. The admission module has one additional, non-ambient
cross-module dependency: it obtains `Test-ColdRestoreRoleTimeoutPolicy` from a
captured `ModuleInfo.ExportedCommands` table and invokes its `CommandInfo`.

## File identities

| File | Runtime identity | SHA-256 |
|---|---|---|
| `cold_restore_vertical_slice_orchestrator.ps1` | PowerShell script, not a module | `af986493e0450511543136cbf419ab3ed716820358c617aa65e2d9b80621054a` |
| `cold_restore_prequota_bootstrap.psm1` | Script module `cold_restore_prequota_bootstrap`; no manifest; GUID `00000000-0000-0000-0000-000000000000`; version `0.0` | `6befb6913252c6b46159b9286ae9e62928b63ff557b9311403b868e1e971fe66` |
| `process_a_rehearsal_admission_contract.psm1` | Script module `process_a_rehearsal_admission_contract`; no manifest; GUID `00000000-0000-0000-0000-000000000000`; version `0.0` | `995fa2970f841340c171954382b3f6dba334aab99a9b2b10ebfc6034d72881c1` |
| `cold_restore_attested_process.psm1` | Script module `cold_restore_attested_process`; no manifest; GUID `00000000-0000-0000-0000-000000000000`; version `0.0` | `5506587d1d0e81d47ecef4fb1c3c08f5323efdc910591070fb4364d8d99f59ca` |
| `cold_restore_authorization_contract_v1.psm1` | Script module `cold_restore_authorization_contract_v1`; no manifest; GUID `00000000-0000-0000-0000-000000000000`; version `0.0` | `6989755b894c159ff24db7f4a359e8e481d07a5c470e9fb12e4606e2fae5acef` |
| `cold_restore_official_attempt2_contract.psm1` | Script module `cold_restore_official_attempt2_contract`; no manifest; GUID `00000000-0000-0000-0000-000000000000`; version `0.0` | `b197bbce64f7ad47a1f35e7379b83a771f87cf710c14bf6506852f557e831697` |

Because none of the five modules has a manifest or nonzero GUID, the stable
identity available to this harness is the resolved absolute path plus file
SHA-256. A name alone is not a sufficient identity.

## Real import order

The order below is the depth-first runtime order reached from the orchestrator.
No import supplies `-RequiredVersion`; no import supplies `-NoClobber`.
Consequently every edge can write commands into its effective target command
table, while the eight `-Force` edges can additionally reload/remove an existing
module instance.

| Order | Caller:line | Imported module | Force | Effective scope | PassThru | Commands required by caller |
|---|---|---|---:|---|---:|---|
| `1` | orchestrator:21 | authorization | yes | orchestrator script | no | `Get-ColdRestoreAuthorizationContract`, `Get-ColdRestoreAuthorizationContractPath`, `Get-ColdRestoreAuthorizationRunId`, `Get-ColdRestoreTargetedDiagnosticAuthorizationBinding` |
| `2` | orchestrator:22 | attested process | yes | orchestrator script | no | 13 commands, including fingerprint, process wrapper, canonical JSON, timeline, and child-attestation APIs |
| `3` | orchestrator:23 | prequota bootstrap | yes | orchestrator script | no | `New-ColdRestoreTargetedDiagnosticPreQuotaContext`, `New-ColdRestoreTargetedDiagnosticUserArgumentList`, `Publish-ColdRestoreTargetedQuotaLedgerV3`, `Update-ColdRestorePreQuotaAttestation` |
| `3.1` | prequota:4 | attested process | no | prequota module | no | canonical JSON, fingerprint, failure projection, strict field/reason checks, and three atomic JSON writers |
| `3.2` | prequota:5 | authorization | no | prequota module | no | authorization entry, run ID, exact ID, and diagnostic binding |
| `4` | orchestrator:24 | official Attempt 2 | yes | orchestrator script | no | six claim/preflight/snapshot commands |
| `4.1` | official:4 | attested process | no | official module | no | canonical JSON, collection count, text SHA, exact fields, exclusive JSON writer |
| `4.2` | official:5 | authorization | no | official module | no | authorization entry and run ID |
| `5` | orchestrator:25 | Process A admission | yes | orchestrator script | no | six admission, launch, ledger, and exclusive-write commands |
| `5.1` | admission:4 | authorization | yes | admission module (default local) | no | `Get-ColdRestoreAuthorizationContract` |
| `5.2` | admission:15 | attested process | yes | admission module (`-Scope Local`) | yes | `Test-ColdRestoreRoleTimeoutPolicy`, obtained from `ModuleInfo.ExportedCommands` |
| `6` | orchestrator:27 | authorization | yes | orchestrator script | no | repeats the four authorization requirements to restore commands removed by `5.1` |

The complete machine-readable edge list, including resolved absolute paths,
full export lists, exact SHA identities, and replacement flags, is in
`alpha04c_module_import_graph.json`.

## Export surfaces

- `cold_restore_authorization_contract_v1` exports 7 functions.
- `cold_restore_attested_process` exports 26 functions. This closed list
  explicitly includes `Get-ColdRestoreEvidenceFingerprint` and
  `Test-ColdRestoreRoleTimeoutPolicy`.
- `cold_restore_prequota_bootstrap` exports 15 functions. Seven are re-exports
  originating in `cold_restore_attested_process`: collection count and the six
  primary/secondary failure-state helpers.
- `cold_restore_official_attempt2_contract` exports 7 functions.
- `process_a_rehearsal_admission_contract` exports 9 functions.

The orchestrator's 33 semantic command requirements split without overlap as:

| Defining module | Distinct required commands |
|---|---:|
| authorization | 4 |
| attested process | 13 |
| prequota bootstrap | 4 |
| official Attempt 2 | 6 |
| Process A admission | 6 |
| **Total** | **33** |

## `Get-ColdRestoreEvidenceFingerprint` chain

The function is defined at
`scripts/tools/cold_restore_attested_process.psm1:389` and exported in that
module's closed `Export-ModuleMember` list at line 2538. Its defining module
identity is:

```text
module_name=cold_restore_attested_process
resolved_path=C:\Users\zhuye\Documents\New project\space-syndicate-alpha04c-import-chain-v4-413a084\scripts\tools\cold_restore_attested_process.psm1
file_sha256=5506587d1d0e81d47ecef4fb1c3c08f5323efdc910591070fb4364d8d99f59ca
```

It hashes the canonical JSON representation after omitting the named
fingerprint field. Call sites are:

- `cold_restore_attested_process.psm1`: lines 669, 1293, 1439, and 1581;
  these are lexical calls inside the defining module.
- `cold_restore_prequota_bootstrap.psm1`: lines 88, 120, 198, 233, and 271;
  these are unqualified calls backed by prequota's module-local import.
- `cold_restore_vertical_slice_orchestrator.ps1`: lines 892, 974, 1094, 3054,
  and 3231; these are unqualified calls that depend on the command remaining in
  the orchestrator script command table.

The admission module neither calls nor re-exports the fingerprint command. It
force-loads the same attested-process path only to capture
`Test-ColdRestoreRoleTimeoutPolicy` as a `CommandInfo`.

## Observed command lifetime

A disposable PowerShell process reproduced the exact top-level import order
without running the orchestrator body:

| Observation | Fingerprint command present in outer scope | Source identity |
|---|---:|---|
| after authorization import `1` | no | n/a |
| after attested import `2` | yes | `cold_restore_attested_process` / `5506587d...f59ca` |
| after prequota import `3` | yes | same module and SHA |
| after official import `4` | yes | same module and SHA |
| after admission import `5` | **no** | outer attested module count became 0 |
| after authorization restore import `6` | **no** | authorization only; attested remains absent |

After import `5`, the prequota, official, and admission module-private scopes
could still resolve their attested-process dependency, but the orchestrator
scope could not. This distinction explains why local module fixtures passed
while the real top-level harness failed.

Of the orchestrator's 33 external command dependencies, the final authorization
re-import restores the authorization commands but leaves these six commands
unresolved:

1. `ConvertTo-ColdRestoreCanonicalJson`
2. `Get-ColdRestoreEvidenceFingerprint`
3. `Invoke-ColdRestoreAttestedProcess`
4. `New-ColdRestoreGodotArgumentList`
5. `Test-ColdRestoreChildCompletionAttestation`
6. `Test-ColdRestoreProcessAPhaseTimeline`

The first reached missing command in the V3 run was
`Get-ColdRestoreEvidenceFingerprint` while constructing the runtime-freeze
observation. Save Owner audit and Godot launch therefore never started.

## Before-repair finding

`Import-Module -Force -PassThru -Scope Local` at admission lines 15-20 reloads
the already active `cold_restore_attested_process` module into admission's local
scope. PowerShell removes the prior outer module instance and its exported
command table, while the admission module retains the locally captured
`CommandInfo`. The orchestrator repairs only the similarly removed authorization
module at line 27; it does not repair attested process exports.

The preceding sections preserve the pre-repair `413a084` graph. The following
sections audit the later, uncommitted working-tree implementation as a separate
AFTER snapshot. They do not claim that V4 diagnostic or Process A rehearsal was
run.

## After-repair working-tree snapshot

The AFTER source hashes were stable for an eight-second observation window.
`HEAD` remains `413a08458369fbda8b304a50d607525ad297353d`; therefore these are
working-tree identities, not committed-result identities.

```text
RUNTIME_IMPORT_STATEMENT_COUNT_AFTER=5
RUNTIME_IMPORT_FORCE_COUNT_AFTER=0
RUNTIME_LOCAL_FORCE_IMPORT_COUNT_AFTER=0
RUNTIME_EFFECTIVE_MODULE_LOCAL_FORCE_IMPORT_COUNT_AFTER=0
RUNTIME_REMOVE_MODULE_COUNT_AFTER=0
RUNTIME_PASS_THRU_IMPORT_STATEMENT_COUNT_AFTER=5
RUNTIME_EXPLICIT_GLOBAL_IMPORT_STATEMENT_COUNT_AFTER=1
AMBIENT_SCRIPT_SCOPE_COMMAND_DEPENDENCY_COUNT_AFTER=0
AMBIENT_SCRIPT_SCOPE_COMMAND_CALL_SITE_COUNT_AFTER=0
ALL_AUDITED_UNQUALIFIED_CROSS_MODULE_DEPENDENCY_COUNT_AFTER=0
ALL_AUDITED_UNQUALIFIED_CROSS_MODULE_CALL_SITE_COUNT_AFTER=0
MODULE_QUALIFIED_CALLER_COMMAND_DEPENDENCY_COUNT_AFTER=60
MODULE_QUALIFIED_CALL_SITE_COUNT_AFTER=166
TOP_LEVEL_MODULE_QUALIFIED_DEPENDENCY_COUNT_AFTER=37
TOP_LEVEL_MODULE_QUALIFIED_CALL_SITE_COUNT_AFTER=109
```

The five literal `Import-Module` statements are four loader bootstrap imports
and the loader's one generic target import. None uses `-Force`, `-Scope Local`,
or `Remove-Module`. The generic target import uses `-Global -PassThru`; the four
bootstrap imports use `-PassThru` in their current scopes. No caller supplies a
required module version.

The loader receives 11 managed dependency requests on a cold top-level chain.
Five requests load a new target module and six reuse a path-identical existing
module. Together with the loader itself, the observed unique module-instance
count is six. Four direct loader bootstrap invocations plus five first-target
imports yield nine cold-start `Import-Module` command executions without any
reload.

## After module identities

| File | AFTER runtime identity | AFTER SHA-256 |
|---|---|---|
| `cold_restore_vertical_slice_orchestrator.ps1` | PowerShell script, not a module | `1e2939f0f1a3ea080c76b0838a36a3a09014c915c5fb488860b7a8092e982c44` |
| `cold_restore_module_loader.psm1` | Script module `cold_restore_module_loader`; no manifest; GUID zero; version `0.0` | `6d9503e63bd8150fc2b4198e49742933d81d3f41aadc675f07910c5585b87d91` |
| `cold_restore_prequota_bootstrap.psm1` | Script module `cold_restore_prequota_bootstrap`; no manifest; GUID zero; version `0.0` | `35fde05c7ada4dfd331d2916b5ae3e7b92a38c6d59e841a0ca97ad85e166f667` |
| `process_a_rehearsal_admission_contract.psm1` | Script module `process_a_rehearsal_admission_contract`; no manifest; GUID zero; version `0.0` | `5ca70305b0e857a1c426c8fff44f1ebdbf3e82388759c1c81d3aa82c5b0ae29c` |
| `cold_restore_attested_process.psm1` | Script module `cold_restore_attested_process`; no manifest; GUID zero; version `0.0` | `5506587d1d0e81d47ecef4fb1c3c08f5323efdc910591070fb4364d8d99f59ca` |
| `cold_restore_authorization_contract_v1.psm1` | Script module `cold_restore_authorization_contract_v1`; no manifest; GUID zero; version `0.0` | `b4001268ddb591a43c54ce3d812511056d517135924962c531fa96d8489e59c8` |
| `cold_restore_official_attempt2_contract.psm1` | Script module `cold_restore_official_attempt2_contract`; no manifest; GUID zero; version `0.0` | `98b18a0aa303769551e00078c089e2d78b291e6dd5584f2d2c6ea735767ee00b` |
| `cold_restore_authorization_contract_v1.json` | Authorization data contract | `7bda46d172edbafe2dfc529b92f06dd833450a0b8cc19984d5f3c62f148a261e` |

The attested-process bytes and SHA are unchanged from BEFORE. For every script
module, the loader identity is resolved absolute path, module name, GUID,
version, and current file SHA. It rejects same-name/different-path modules,
duplicate path instances, a changed file identity, a missing required export,
or an optional version mismatch.

## After dependency order

| Order | Caller | Dependency | Mechanism | Cold-start action |
|---|---|---|---|---|
| `1` | orchestrator | loader | direct `Import-Module -PassThru` | load loader |
| `2` | orchestrator | authorization | `Import-ColdRestoreModuleOnce` | new |
| `3` | orchestrator | prequota | `Import-ColdRestoreModuleOnce` | new |
| `3.1` | prequota | loader | direct `Import-Module -PassThru` | reuse |
| `3.2` | prequota | attested process | `Import-ColdRestoreModuleOnce` | new |
| `3.3` | prequota | authorization | `Import-ColdRestoreModuleOnce` | reuse |
| `4` | orchestrator | attested identity before admission | `Get-ColdRestoreLoadedModuleByPath` | observe |
| `5` | orchestrator | Process A admission | `Import-ColdRestoreModuleOnce` | new |
| `5.1` | admission | loader | direct `Import-Module -PassThru` | reuse |
| `5.2` | admission | authorization | `Import-ColdRestoreModuleOnce` | reuse |
| `5.3` | admission | attested process | `Import-ColdRestoreModuleOnce` | reuse |
| `6` | orchestrator | attested process | `Import-ColdRestoreModuleOnce` | reuse same object |
| `7` | orchestrator | official Attempt 2 | `Import-ColdRestoreModuleOnce` | new |
| `7.1` | official | loader | direct `Import-Module -PassThru` | reuse |
| `7.2` | official | attested process | `Import-ColdRestoreModuleOnce` | reuse |
| `7.3` | official | authorization | `Import-ColdRestoreModuleOnce` | reuse |

All runtime cross-module command calls are now module-qualified or obtained as
a verified `CommandInfo`. The two distinct `CommandInfo` dependencies have
three call sites: the fingerprint probe before and after admission, and the
admission timeout-policy validator.

## After fingerprint lifetime

`Get-ColdRestoreEvidenceFingerprint` remains defined and exported by the
unchanged attested-process module at SHA `5506587d...f59ca`. The orchestrator
obtains the module before admission, captures the exported command, computes a
probe fingerprint, imports admission, resolves the module again, and recomputes
the fingerprint. It then requires reference equality across all three module
lookups.

A disposable import-only process observed:

```text
ATTESTED_REFERENCE_STABLE=true
FINGERPRINT_COMMAND_PRESENT_BEFORE_ADMISSION=true
FINGERPRINT_COMMAND_PRESENT_AFTER_ADMISSION=true
FINGERPRINT_RESULT_PARITY=true
LOADED_ATTESTED_MODULE_COUNT=1
LOADED_AUTHORIZATION_MODULE_COUNT=1
LOADED_LOADER_MODULE_COUNT=1
LOADED_TARGET_MODULE_COUNT=5
```

The remaining orchestrator fingerprint calls and all prequota fingerprint calls
are module-qualified. There are no ambient or unqualified cross-module call
sites in any of the seven audited PowerShell files.

## V3 preservation and V4 separation

The current V3 JSON entry has 11 fields and is byte-for-byte equal to the
normalized V3 subtree at `HEAD`:

```text
V3_ENTRY_RAW_NORMALIZED_UNCHANGED=true
V3_ENTRY_RAW_NORMALIZED_SHA256=f9727e13aac85315877944e256f6072519c7a89cf0c9201d31e9fcfa3c7aac72
V3_ENTRY_CANONICAL_SHA256=ea6807c6103993e5a30714ce982e042fb92c9dfac67cb0e0b053c8a706ae8a36
V3_TRANSITION=2_TO_3
```

V3 retains its exact authorization ID, ledger ID, quota path, evidence root,
bootstrap root, run prefix, and `2_TO_3` transition. Its V3 ledger assertion and
publisher remain separately exported by prequota, and generic prequota APIs
retain V3 as their compatibility default.

V4 is a new 11-field sibling entry with canonical SHA
`779be5602498552515feacc61366d2cf9b0f4b200df58cd7c6f97628bed49630`:

```text
V4_AUTHORIZATION_ID=alpha04c-targeted-owner-capture-diagnostic-v4-importchain
V4_LEDGER_ID=Alpha04C.TargetedOwnerCaptureDiagnosticQuotaLedgerV4
V4_TRANSITION=3_TO_4
V4_RUN_PREFIX=alpha04c-owner-capture-diagnostic-v4-importchain
V3_V4_AUTHORIZATION_ID_DISTINCT=true
V3_V4_LEDGER_ID_DISTINCT=true
V3_V4_RUN_PREFIX_DISTINCT=true
V3_V4_PATH_COLLISION_COUNT=0
```

Its quota ledger, evidence root, and prequota root all use the independent
`non-official-alpha04c-owner-capture-diagnostic-v4-importchain` directory. The
orchestrator explicitly selects the V4 entry and V4 publisher. This audit did
not create either ledger, evidence root, or any diagnostic process.
