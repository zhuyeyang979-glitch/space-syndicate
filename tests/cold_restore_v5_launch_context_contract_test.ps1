param(
    [Parameter(Mandatory = $true)][string]$V5LedgerPath,
    [Parameter(Mandatory = $true)][string]$V5LaunchAttestationPath,
    [Parameter(Mandatory = $true)][string]$GitCommonDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Checks = 0
$script:Failures = [Collections.Generic.List[string]]::new()
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$helperPath = Join-Path $projectRoot "scripts\tools\cold_restore_targeted_diagnostic_launch_context_v1.psm1"
$prequotaPath = Join-Path $projectRoot "scripts\tools\cold_restore_prequota_bootstrap.psm1"
Import-Module $helperPath -Force -ErrorAction Stop
Import-Module $prequotaPath -Force -ErrorAction Stop

function Assert-V5LaunchContext {
    param([bool]$Condition, [string]$Message)
    $script:Checks += 1
    if (-not $Condition) { $script:Failures.Add($Message) }
}

function Copy-V5LaunchContext {
    param([Parameter(Mandatory = $true)]$Value)
    return ($Value | ConvertTo-Json -Compress -Depth 16) |
        ConvertFrom-Json -AsHashtable -DateKind String
}

function Assert-V5RepositoryHeadFailure {
    param(
        [Parameter(Mandatory = $true)][Collections.IDictionary]$Fixture,
        [Parameter(Mandatory = $true)][string]$ExpectedReason,
        [Collections.IDictionary]$Expected = @{}
    )
    $report = cold_restore_targeted_diagnostic_launch_context_v1\Test-ColdRestoreTargetedDiagnosticLaunchContext `
        -Context $Fixture -ExpectedBindings $Expected -Stage "powershell_test"
    Assert-V5LaunchContext (-not [bool]$report.valid) "$ExpectedReason fixture is rejected"
    Assert-V5LaunchContext ([string]$report.reason_code -ceq "targeted_owner_capture_launch_context_invalid") "$ExpectedReason uses typed launch-context reason"
    Assert-V5LaunchContext ([string]$report.failing_stage -ceq "powershell_test") "$ExpectedReason identifies the failing stage"
    Assert-V5LaunchContext ([string]$report.failing_field -ceq "repository_head") "$ExpectedReason identifies repository_head"
    Assert-V5LaunchContext ([string]$report.field_reason -ceq $ExpectedReason) "$ExpectedReason is exact"
    Assert-V5LaunchContext ([string]$report.safe_expected_fingerprint -cmatch '^[0-9a-f]{64}$' -and [string]$report.safe_actual_fingerprint -cmatch '^[0-9a-f]{64}$') "$ExpectedReason returns safe fingerprints"
    Assert-V5LaunchContext (-not (($report | ConvertTo-Json -Compress).Contains("604264b0af9a10ca07db58851e8a2d00171dd2f3", [StringComparison]::Ordinal))) "$ExpectedReason does not expose the HEAD"
}

$ledgerBytesBefore = [IO.File]::ReadAllBytes($V5LedgerPath)
$launchBytesBefore = [IO.File]::ReadAllBytes($V5LaunchAttestationPath)
$ledgerSha = (Get-FileHash -LiteralPath $V5LedgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
$launchSha = (Get-FileHash -LiteralPath $V5LaunchAttestationPath -Algorithm SHA256).Hash.ToLowerInvariant()
$ledger = [IO.File]::ReadAllText($V5LedgerPath, [Text.UTF8Encoding]::new($false)) |
    ConvertFrom-Json -DateKind String
$launch = [IO.File]::ReadAllText($V5LaunchAttestationPath, [Text.UTF8Encoding]::new($false)) |
    ConvertFrom-Json -DateKind String

Assert-V5LaunchContext ($ledgerSha -ceq "b7e6c66852540c2b3066f86cd6e9c9d9454c185c4e8ed17d168c6b0dbf466742") "retained V5 ledger bytes are exact"
Assert-V5LaunchContext ($launchSha -ceq "f79cf007878789d3122b588309b99a27fc3231d897a058b85c7ea789ffe3ed1f") "retained V5 launch attestation bytes are exact"

$contract = cold_restore_targeted_diagnostic_launch_context_v1\Get-ColdRestoreTargetedDiagnosticLaunchContextContract
$contractPath = cold_restore_targeted_diagnostic_launch_context_v1\Get-ColdRestoreTargetedDiagnosticLaunchContextContractPath
Assert-V5LaunchContext ([IO.Path]::GetFileName($contractPath) -ceq "cold_restore_targeted_diagnostic_launch_context_v1.json") "one canonical JSON contract is selected"
Assert-V5LaunchContext (@($contract.required_fields | Where-Object { [string]$_ -ceq "repository_head" }).Count -eq 1) "repository_head appears once in the canonical required field list"
Assert-V5LaunchContext ([string]$contract.cli_argument_names.repository_head -ceq "--cold-restore-head-sha=") "CLI repository-head name comes from the contract"
Assert-V5LaunchContext ([string]$contract.gdscript_option_names.repository_head -ceq "head_sha") "GDScript option mapping comes from the contract"
Assert-V5LaunchContext ([string]$contract.canonical_binding_names.repository_head -ceq "repository_head") "canonical validator binding comes from the contract"
Assert-V5LaunchContext (-not [bool]$contract.repository_head.implicit_fallback_allowed -and -not [bool]$contract.repository_head.source_head_sha_alias_allowed) "repository_head aliases and fallback are forbidden"

$context = cold_restore_targeted_diagnostic_launch_context_v1\New-ColdRestoreTargetedDiagnosticLaunchContext `
    -Ledger $ledger `
    -RepositoryHead ([string]$ledger.repository_head) `
    -RunId ([string]$ledger.run_id) `
    -ScenarioFingerprint ([string]$ledger.scenario_fingerprint) `
    -QuotaLedgerPath $V5LedgerPath `
    -QuotaLedgerSha256 $ledgerSha `
    -LaunchAttestationPath $V5LaunchAttestationPath `
    -LaunchNonce ([string]$launch.launch_nonce) `
    -RoleTimeoutPolicySha256 ([string]$ledger.role_timeout_policy_sha256)
$valid = cold_restore_targeted_diagnostic_launch_context_v1\Test-ColdRestoreTargetedDiagnosticLaunchContext `
    -Context $context -Stage "powershell_test"
Assert-V5LaunchContext ([bool]$valid.valid) "PowerShell builds a valid canonical V5 launch context"

$arguments = @(
    cold_restore_targeted_diagnostic_launch_context_v1\ConvertTo-ColdRestoreTargetedDiagnosticLaunchArgumentList `
        -Context $context
)
Assert-V5LaunchContext ($arguments.Count -eq 11) "canonical publisher emits three mode and eight value arguments"
Assert-V5LaunchContext ($arguments -ccontains "--cold-restore-head-sha=$($ledger.repository_head)") "canonical publisher emits the exact V5 repository HEAD"
Assert-V5LaunchContext (@($arguments | Where-Object { $_ -like '--cold-restore-source-head-sha=*' }).Count -eq 0) "source_head_sha is never a CLI fallback"

$prequotaArguments = @(cold_restore_prequota_bootstrap\New-ColdRestoreTargetedDiagnosticUserArgumentList `
    -GitCommonDirectory $GitCommonDirectory `
    -RepositoryHead ([string]$ledger.repository_head) `
    -RunId ([string]$ledger.run_id) `
    -ArtifactRoot "user://test_runs/alpha04c/$($ledger.run_id)/evidence" `
    -ScenarioFingerprint ([string]$ledger.scenario_fingerprint) `
    -TimeoutPolicyFingerprint ([string]$ledger.role_timeout_policy_sha256) `
    -QuotaLedgerPath $V5LedgerPath `
    -QuotaLedgerFingerprint $ledgerSha `
    -LaunchAttestationPath $V5LaunchAttestationPath `
    -LaunchNonce ([string]$launch.launch_nonce) `
    -AuthorizationName "targeted_owner_capture_diagnostic_v5_canonical_binding")
Assert-V5LaunchContext ($prequotaArguments.Count -eq 12) "prequota adds only the artifact root to canonical launch arguments"
Assert-V5LaunchContext (@($prequotaArguments | Where-Object { $_ -ceq "--cold-restore-head-sha=$($ledger.repository_head)" }).Count -eq 1) "prequota consumes the canonical repository-head mapping exactly once"

$missing = Copy-V5LaunchContext $context
$missing.Remove("repository_head")
Assert-V5RepositoryHeadFailure $missing "missing"
$nullValue = Copy-V5LaunchContext $context
$nullValue.repository_head = $null
Assert-V5RepositoryHeadFailure $nullValue "null"
$empty = Copy-V5LaunchContext $context
$empty.repository_head = ""
Assert-V5RepositoryHeadFailure $empty "empty"
$wrongType = Copy-V5LaunchContext $context
$wrongType.repository_head = 42
Assert-V5RepositoryHeadFailure $wrongType "wrong_type"
$short = Copy-V5LaunchContext $context
$short.repository_head = "a" * 39
Assert-V5RepositoryHeadFailure $short "wrong_length"
$long = Copy-V5LaunchContext $context
$long.repository_head = "a" * 41
Assert-V5RepositoryHeadFailure $long "wrong_length"
$nonHex = Copy-V5LaunchContext $context
$nonHex.repository_head = ("a" * 39) + "z"
Assert-V5RepositoryHeadFailure $nonHex "non_hex"
$uppercase = Copy-V5LaunchContext $context
$uppercase.repository_head = ([string]$ledger.repository_head).ToUpperInvariant()
Assert-V5RepositoryHeadFailure $uppercase "uppercase"
$wrongHead = Copy-V5LaunchContext $context
$wrongHead.repository_head = "a" * 40
Assert-V5RepositoryHeadFailure $wrongHead "value_mismatch" @{ repository_head = [string]$ledger.repository_head }
$aliasOnly = Copy-V5LaunchContext $context
$aliasOnly.Remove("repository_head")
$aliasOnly.source_head_sha = [string]$ledger.repository_head
Assert-V5RepositoryHeadFailure $aliasOnly "missing"
$nullOverride = Copy-V5LaunchContext $context
$nullOverride.repository_head = $null
Assert-V5RepositoryHeadFailure $nullOverride "null"

$prequotaSource = [IO.File]::ReadAllText($prequotaPath)
$driverSource = [IO.File]::ReadAllText((Join-Path $projectRoot "scripts\tools\cold_restore_vertical_slice_driver.gd"))
$validatorSource = [IO.File]::ReadAllText((Join-Path $projectRoot "scripts\tools\cold_restore_targeted_ledger_binding_validator_v1.gd"))
Assert-V5LaunchContext (-not $prequotaSource.Contains('"--cold-restore-head-sha=$RepositoryHead"', [StringComparison]::Ordinal)) "prequota no longer duplicates the repository-head CLI literal"
Assert-V5LaunchContext (-not $driverSource.Contains('text.begins_with("--cold-restore-head-sha=")', [StringComparison]::Ordinal)) "driver parser no longer duplicates the repository-head CLI literal"
Assert-V5LaunchContext ($driverSource.Contains('"head_sha": head_sha', [StringComparison]::Ordinal)) "validate_options preserves parsed repository HEAD for child bootstrap"
Assert-V5LaunchContext ($driverSource.Contains('"failing_stage": str(diagnostic_authorization.get(', [StringComparison]::Ordinal)) "private child QA projects the exact failing stage"
Assert-V5LaunchContext ($validatorSource.Contains("validate_ledger_text_with_launch_context", [StringComparison]::Ordinal)) "ledger validator consumes canonical launch context"

Assert-V5LaunchContext ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($ledgerBytesBefore)).ToLowerInvariant() -ceq (Get-FileHash -LiteralPath $V5LedgerPath -Algorithm SHA256).Hash.ToLowerInvariant()) "PowerShell tests do not mutate the retained ledger"
Assert-V5LaunchContext ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($launchBytesBefore)).ToLowerInvariant() -ceq (Get-FileHash -LiteralPath $V5LaunchAttestationPath -Algorithm SHA256).Hash.ToLowerInvariant()) "PowerShell tests do not mutate the retained launch attestation"

$passed = $script:Failures.Count -eq 0
Write-Output ("COLD_RESTORE_V5_LAUNCH_CONTEXT_CONTRACT_TEST|status={0}|checks={1}|failures={2}|diagnostic_count_delta=0|quota_claim_count=0|session_create_count=0|owner_capture_count=0|save_write_count=0|details={3}" -f `
    $(if ($passed) { "PASS" } else { "FAIL" }),
    $script:Checks,
    $script:Failures.Count,
    ($script:Failures | ConvertTo-Json -Compress))
if (-not $passed) { exit 1 }
