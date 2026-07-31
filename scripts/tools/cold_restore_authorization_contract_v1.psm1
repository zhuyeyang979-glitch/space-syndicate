Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:AuthorizationContractPath = Join-Path $PSScriptRoot "cold_restore_authorization_contract_v1.json"
$script:AuthorizationContractFields = @(
    "schema_version", "contract_id", "targeted_owner_capture_diagnostic_v3",
    "targeted_owner_capture_diagnostic_v4_importchain",
    "process_a_save_completion_rehearsal_v1", "official_attempt_2"
)
$script:TargetedDiagnosticFields = @(
    "authorization_id", "task_id", "ledger_id", "quota_ledger_relative_path",
    "evidence_root_relative_path", "bootstrap_root_relative_path", "run_id_prefix",
    "permitted_transition_from",
    "permitted_transition_to", "authorized_increment", "maximum_invocation_count"
)
$script:ProcessARehearsalFields = @(
    "authorization_id", "quota_ledger_relative_path", "launch_ledger_relative_path",
    "outcome_ledger_relative_path", "run_id_prefix", "maximum_invocation_count"
)
$script:OfficialAttempt2Fields = @(
    "authorization_id", "claim_path", "run_id_prefix", "maximum_attempt_number",
    "attempt_1_claim_relative_path", "attempt_1_claim_sha256"
)

function Test-ColdRestoreAuthorizationExactFieldSet {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedFields
    )

    if ($null -eq $Value -or @($Value.PSObject.Properties).Count -ne $ExpectedFields.Count) {
        return $false
    }
    foreach ($field in $ExpectedFields) {
        if ($Value.PSObject.Properties.Name -cnotcontains $field) {
            return $false
        }
    }
    return $true
}

function Test-ColdRestoreAuthorizationRelativePath {
    param([AllowNull()]$Value)

    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$Value) `
        -or [IO.Path]::IsPathFullyQualified([string]$Value)) {
        return $false
    }
    $normalized = ([string]$Value).Replace("\", "/")
    return $normalized -ceq [string]$Value `
        -and -not $normalized.StartsWith("/", [StringComparison]::Ordinal) `
        -and -not $normalized.Contains("../", [StringComparison]::Ordinal) `
        -and -not $normalized.Contains("/..", [StringComparison]::Ordinal)
}

function Test-ColdRestoreAuthorizationIdShape {
    param([AllowNull()]$Value)

    return $Value -is [string] `
        -and ([string]$Value).Length -ge 1 `
        -and ([string]$Value).Length -le 128 `
        -and [string]$Value -cmatch '^[a-z0-9][a-z0-9-]*$'
}

function Assert-ColdRestoreAuthorizationContract {
    param([Parameter(Mandatory = $true)]$Value)

    if (-not (Test-ColdRestoreAuthorizationExactFieldSet $Value $script:AuthorizationContractFields) `
        -or $Value.schema_version -isnot [long] -and $Value.schema_version -isnot [int] `
        -or [int]$Value.schema_version -ne 1 `
        -or [string]$Value.contract_id -cne "ColdRestoreAuthorizationContractV1") {
        throw "cold_restore_authorization_contract_invalid"
    }

    $targeted = $Value.targeted_owner_capture_diagnostic_v3
    if (-not (Test-ColdRestoreAuthorizationExactFieldSet $targeted $script:TargetedDiagnosticFields) `
        -or -not (Test-ColdRestoreAuthorizationIdShape $targeted.authorization_id) `
        -or [string]$targeted.task_id -cnotmatch '^[A-Z0-9_]{1,160}$' `
        -or [string]$targeted.ledger_id -cne "Alpha04C.TargetedOwnerCaptureDiagnosticQuotaLedgerV3" `
        -or -not (Test-ColdRestoreAuthorizationRelativePath $targeted.quota_ledger_relative_path) `
        -or -not (Test-ColdRestoreAuthorizationRelativePath $targeted.evidence_root_relative_path) `
        -or -not (Test-ColdRestoreAuthorizationRelativePath $targeted.bootstrap_root_relative_path) `
        -or [string]$targeted.run_id_prefix -cnotmatch '^[a-z0-9][a-z0-9-]{1,95}$' `
        -or [int]$targeted.permitted_transition_from -ne 2 `
        -or [int]$targeted.permitted_transition_to -ne 3 `
        -or [int]$targeted.authorized_increment -ne 1 `
        -or [int]$targeted.maximum_invocation_count -ne 3) {
        throw "cold_restore_targeted_authorization_contract_invalid"
    }

    $targetedV4 = $Value.targeted_owner_capture_diagnostic_v4_importchain
    if (-not (Test-ColdRestoreAuthorizationExactFieldSet $targetedV4 $script:TargetedDiagnosticFields) `
        -or -not (Test-ColdRestoreAuthorizationIdShape $targetedV4.authorization_id) `
        -or [string]$targetedV4.authorization_id -cne "alpha04c-targeted-owner-capture-diagnostic-v4-importchain" `
        -or [string]$targetedV4.task_id -cne "ALPHA04C_IMPORT_CHAIN_REPAIR_AND_V07_THREE_WING_KERNEL_PARALLEL_ADVANCE" `
        -or [string]$targetedV4.ledger_id -cne "Alpha04C.TargetedOwnerCaptureDiagnosticQuotaLedgerV4" `
        -or [string]$targetedV4.quota_ledger_relative_path -cne "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v4-importchain/targeted_owner_capture_quota_ledger.json" `
        -or [string]$targetedV4.evidence_root_relative_path -cne "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v4-importchain/evidence" `
        -or [string]$targetedV4.bootstrap_root_relative_path -cne "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v4-importchain/prequota" `
        -or [string]$targetedV4.run_id_prefix -cne "alpha04c-owner-capture-diagnostic-v4-importchain" `
        -or [int]$targetedV4.permitted_transition_from -ne 3 `
        -or [int]$targetedV4.permitted_transition_to -ne 4 `
        -or [int]$targetedV4.authorized_increment -ne 1 `
        -or [int]$targetedV4.maximum_invocation_count -ne 4) {
        throw "cold_restore_targeted_v4_authorization_contract_invalid"
    }

    $rehearsal = $Value.process_a_save_completion_rehearsal_v1
    if (-not (Test-ColdRestoreAuthorizationExactFieldSet $rehearsal $script:ProcessARehearsalFields) `
        -or -not (Test-ColdRestoreAuthorizationIdShape $rehearsal.authorization_id) `
        -or -not (Test-ColdRestoreAuthorizationRelativePath $rehearsal.quota_ledger_relative_path) `
        -or -not (Test-ColdRestoreAuthorizationRelativePath $rehearsal.launch_ledger_relative_path) `
        -or -not (Test-ColdRestoreAuthorizationRelativePath $rehearsal.outcome_ledger_relative_path) `
        -or [string]$rehearsal.run_id_prefix -cnotmatch '^[a-z0-9][a-z0-9-]{1,95}$' `
        -or [int]$rehearsal.maximum_invocation_count -ne 1) {
        throw "cold_restore_rehearsal_authorization_contract_invalid"
    }

    $official = $Value.official_attempt_2
    if (-not (Test-ColdRestoreAuthorizationExactFieldSet $official $script:OfficialAttempt2Fields) `
        -or -not (Test-ColdRestoreAuthorizationIdShape $official.authorization_id) `
        -or -not (Test-ColdRestoreAuthorizationRelativePath $official.claim_path) `
        -or [string]$official.run_id_prefix -cnotmatch '^[a-z0-9][a-z0-9-]{1,95}$' `
        -or [int]$official.maximum_attempt_number -ne 2 `
        -or -not (Test-ColdRestoreAuthorizationRelativePath $official.attempt_1_claim_relative_path) `
        -or [string]$official.attempt_1_claim_sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw "cold_restore_official_authorization_contract_invalid"
    }

    return $Value
}

function Get-ColdRestoreAuthorizationContract {
    param([string]$Path = $script:AuthorizationContractPath)

    if (-not [IO.File]::Exists($Path)) {
        throw "cold_restore_authorization_contract_missing"
    }
    try {
        $value = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false)) |
            ConvertFrom-Json -DateKind String
    }
    catch {
        throw "cold_restore_authorization_contract_json_invalid"
    }
    return Assert-ColdRestoreAuthorizationContract $value
}

function Get-ColdRestoreAuthorizationEntry {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "targeted_owner_capture_diagnostic_v3",
            "targeted_owner_capture_diagnostic_v4_importchain",
            "process_a_save_completion_rehearsal_v1",
            "official_attempt_2"
        )]
        [string]$Name,
        [string]$Path = $script:AuthorizationContractPath
    )

    $contract = Get-ColdRestoreAuthorizationContract $Path
    return $contract.$Name
}

function Test-ColdRestoreExactAuthorizationId {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()]$AuthorizationId,
        [string]$Path = $script:AuthorizationContractPath
    )

    $entry = Get-ColdRestoreAuthorizationEntry $Name $Path
    return $AuthorizationId -is [string] `
        -and [string]$AuthorizationId -ceq [string]$entry.authorization_id
}

function Get-ColdRestoreAuthorizationRunId {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [string]$Path = $script:AuthorizationContractPath
    )

    if ($RepositoryHead -cnotmatch '^[0-9a-f]{40}$') {
        throw "cold_restore_authorization_repository_head_invalid"
    }
    $entry = Get-ColdRestoreAuthorizationEntry $Name $Path
    return "$([string]$entry.run_id_prefix)-$($RepositoryHead.Substring(0, 12))"
}

function Get-ColdRestoreTargetedDiagnosticAuthorizationBinding {
    param(
        [Parameter(Mandatory = $true)][string]$GitCommonDirectory,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [string]$Path = $script:AuthorizationContractPath,
        [ValidateSet(
            "targeted_owner_capture_diagnostic_v3",
            "targeted_owner_capture_diagnostic_v4_importchain"
        )]
        [string]$AuthorizationName = "targeted_owner_capture_diagnostic_v3"
    )

    if (-not [IO.Path]::IsPathFullyQualified($GitCommonDirectory)) {
        throw "cold_restore_authorization_git_common_invalid"
    }
    $contract = Get-ColdRestoreAuthorizationContract $Path
    $entry = $contract.$AuthorizationName
    $gitCommon = [IO.Path]::GetFullPath($GitCommonDirectory)
    $quotaPath = [IO.Path]::GetFullPath((Join-Path $gitCommon ([string]$entry.quota_ledger_relative_path)))
    $evidenceRoot = [IO.Path]::GetFullPath((Join-Path $gitCommon ([string]$entry.evidence_root_relative_path)))
    $bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $gitCommon ([string]$entry.bootstrap_root_relative_path)))
    $prefix = $gitCommon.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) +
        [IO.Path]::DirectorySeparatorChar
    foreach ($resolvedPath in @($quotaPath, $evidenceRoot, $bootstrapRoot)) {
        if (-not $resolvedPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "cold_restore_authorization_path_escape"
        }
    }
    return [pscustomobject][ordered]@{
        contract_path = [IO.Path]::GetFullPath($Path)
        contract_sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        authorization_id = [string]$entry.authorization_id
        task_id = [string]$entry.task_id
        ledger_id = [string]$entry.ledger_id
        authorization_name = $AuthorizationName
        run_id = Get-ColdRestoreAuthorizationRunId $AuthorizationName $RepositoryHead $Path
        quota_ledger_path = $quotaPath
        evidence_root = $evidenceRoot
        bootstrap_root = $bootstrapRoot
        transition_from = [int]$entry.permitted_transition_from
        transition_to = [int]$entry.permitted_transition_to
        authorized_increment = [int]$entry.authorized_increment
        maximum_invocation_count = [int]$entry.maximum_invocation_count
    }
}

function Get-ColdRestoreAuthorizationContractPath {
    return $script:AuthorizationContractPath
}

Export-ModuleMember -Function @(
    "Assert-ColdRestoreAuthorizationContract",
    "Get-ColdRestoreAuthorizationContract",
    "Get-ColdRestoreAuthorizationEntry",
    "Test-ColdRestoreExactAuthorizationId",
    "Get-ColdRestoreAuthorizationRunId",
    "Get-ColdRestoreTargetedDiagnosticAuthorizationBinding",
    "Get-ColdRestoreAuthorizationContractPath"
)
