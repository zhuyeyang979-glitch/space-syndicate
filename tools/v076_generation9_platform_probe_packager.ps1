param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^probe-\d{3}$')]
    [string]$ProbeId,

    [Parameter(Mandatory = $true)]
    [string]$SourceProbeRoot,

    [Parameter(Mandatory = $true)]
    [string]$DestinationProbeRoot,

    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'QUALIFICATION_PASS',
        'TOOLING_FAILURE_FULL_WINDOW_DPI_COORDINATE_MISCLICK',
        'TOOLING_FAILURE_WINDOW_COORDINATE_MAPPING',
        'TOOLING_FAILURE_SCREENSHOT_WINDOW_RELATIVE_COORDINATE_OFFSET',
        'TOOLING_FAILURE_EXTERNAL_TO_RUNTIME_GUI_FOCUS_BINDING',
        'TOOLING_FAILURE_OTHER',
        'PRODUCT_FAILURE'
    )]
    [string]$Classification,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 100000)]
    [int]$NewLaunchIndex,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 1)]
    [int]$ConsecutivePassCountBefore,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 2)]
    [int]$ConsecutivePassCountAfter,

    [string]$NextProbeId = ''
)

$ErrorActionPreference = 'Stop'
$authorizationId = 'USER_AUTHORIZATION_V076_MCP_SEED_FOCUS_REPAIR_AND_PASS_PAIR_20260902'
$probeBudgetAuthorizationId = $authorizationId
$parentAuthorizationId = 'USER_AUTHORIZATION_V076_POST_RESTART_REQUALIFICATION_20260902'
$productCandidateHeadSha = 'b33e460610776564dac3616bd341fa829316b1e2'
$productCandidateTreeSha = '449018413600b57b9d503b9610c9ae79e3c8eee1'
$sourceRoot = (Resolve-Path -LiteralPath $SourceProbeRoot).Path.TrimEnd('\')
$destinationRoot = [IO.Path]::GetFullPath($DestinationProbeRoot).TrimEnd('\')

if (Test-Path -LiteralPath $destinationRoot) {
    throw "Refusing to overwrite packaged probe evidence: $destinationRoot"
}

$executionResultPath = Join-Path $sourceRoot 'probe_execution_result.json'
$focusWitnessPath = Join-Path $sourceRoot 'external-seed-focus-complete.json'
if (-not (Test-Path -LiteralPath $executionResultPath)) {
    throw "Probe execution result is missing: $executionResultPath"
}

$executionResult = Get-Content -LiteralPath $executionResultPath -Raw | ConvertFrom-Json
$executionProbeId = [string]$executionResult.probe_id
if ($executionProbeId -cne $ProbeId) {
    throw "Execution result Probe ID mismatch: expected $ProbeId, found $executionProbeId"
}
if ([string]$executionResult.authorization_id -cne $authorizationId) {
    throw 'Execution result authorization does not match the active Seed focus repair authority.'
}
if ([string]$executionResult.probe_budget_authorization_id -cne $probeBudgetAuthorizationId) {
    throw 'Execution result probe budget authorization is invalid.'
}
if ([string]$executionResult.parent_authorization_id -cne $parentAuthorizationId) {
    throw 'Execution result parent authorization is invalid.'
}
if ([bool]$executionResult.formal_generation -or [int]$executionResult.generation9_formal_execution_count -ne 0) {
    throw 'A formal Generation 9 execution cannot be packaged as a nonformal platform Probe.'
}
$focusWitness = if (Test-Path -LiteralPath $focusWitnessPath) {
    Get-Content -LiteralPath $focusWitnessPath -Raw | ConvertFrom-Json
} else {
    $null
}
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Sort-Object FullName)
if ($sourceFiles.Count -lt 1) {
    throw 'Source probe evidence is empty.'
}

$manifestFiles = @($sourceFiles | ForEach-Object {
    [ordered]@{
        relative_path = $_.FullName.Substring($sourceRoot.Length).TrimStart('\').Replace('\', '/')
        size_bytes = [int64]$_.Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
})
$generatedAt = [DateTime]::UtcNow.ToString('o')
$normalizedNextProbeId = $NextProbeId.Trim()
$qualificationPass = (
    $Classification -ceq 'QUALIFICATION_PASS' -and
    [string]$executionResult.status -ceq 'PASS'
)
if (($Classification -ceq 'QUALIFICATION_PASS') -ne ([string]$executionResult.status -ceq 'PASS')) {
    throw 'Classification and execution status disagree.'
}
if ($qualificationPass) {
    if ($ConsecutivePassCountAfter -ne ($ConsecutivePassCountBefore + 1)) {
        throw 'A PASS must increment the consecutive complete PASS count exactly once.'
    }
} elseif ($ConsecutivePassCountAfter -ne 0) {
    throw 'A failed Probe must reset the consecutive complete PASS count to zero.'
}
if ($ConsecutivePassCountAfter -eq 2) {
    if ($normalizedNextProbeId -ne '') {
        throw 'Next Probe ID must be empty after the first consecutive complete PASS pair.'
    }
} else {
    if ($normalizedNextProbeId -notmatch '^probe-\d{3}$') {
        throw 'A next monotonic Probe ID is required until the first consecutive complete PASS pair.'
    }
    $currentProbeNumber = [int]$ProbeId.Substring(6)
    $nextProbeNumber = [int]$normalizedNextProbeId.Substring(6)
    if ($nextProbeNumber -ne ($currentProbeNumber + 1)) {
        throw 'Next Probe ID must be the exact monotonic successor.'
    }
}

[IO.Directory]::CreateDirectory($destinationRoot) | Out-Null
$manifestPath = Join-Path $destinationRoot 'raw_evidence_manifest.json'
$reportPath = Join-Path $destinationRoot 'platform_probe_report.json'
$manifest = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_platform_probe_raw_evidence_manifest.v2'
    authorization_id = $authorizationId
    probe_budget_authorization_id = $probeBudgetAuthorizationId
    parent_authorization_id = $parentAuthorizationId
    probe_id = $ProbeId
    generated_at_utc = $generatedAt
    source_storage = 'EXTERNAL_APPEND_ONLY_TASK_OUTPUT'
    source_path_redacted = $true
    source_file_count = $sourceFiles.Count
    source_total_size_bytes = [int64](($sourceFiles | Measure-Object -Property Length -Sum).Sum)
    files = $manifestFiles
}
$report = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_platform_probe_packaged_report.v2'
    authorization_id = $authorizationId
    probe_budget_authorization_id = $probeBudgetAuthorizationId
    parent_authorization_id = $parentAuthorizationId
    probe_id = $ProbeId
    generated_at_utc = $generatedAt
    status = [string]$executionResult.status
    classification = $Classification
    qualification_pass = $qualificationPass
    new_probe_budget_kind = 'UNTIL_FIRST_CONSECUTIVE_COMPLETE_PASS_PAIR'
    minimum_new_nonformal_probe_count = 2
    new_launch_index = $NewLaunchIndex
    consecutive_complete_pass_count_before = $ConsecutivePassCountBefore
    consecutive_complete_pass_count_after = $ConsecutivePassCountAfter
    next_probe_id = if ($normalizedNextProbeId -eq '') {$null} else {$normalizedNextProbeId}
    execution_result_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $executionResultPath).Hash.ToLowerInvariant()
    raw_evidence_manifest_file_count = $sourceFiles.Count
    failure = $executionResult.failure
    milestone_pass_count = $executionResult.milestone_pass_count
    milestone_required_count = $executionResult.milestone_required_count
    seed_four_layer_match = [bool]$executionResult.seed_binding.four_layer_match
    external_focus_witness_status = if ($null -ne $focusWitness) {[string]$focusWitness.status} else {$null}
    external_focus_failure_domain = if ($null -ne $focusWitness) {[string]$focusWitness.failure_domain} else {$null}
    external_focus_failure_code = if ($null -ne $focusWitness) {[string]$focusWitness.failure_code} else {$null}
    external_focus_observed_result = if ($null -ne $focusWitness) {[string]$focusWitness.observed_result} else {$null}
    minimum_available_commit_bytes = $executionResult.minimum_available_commit_bytes
    maximum_import_queue_length = $executionResult.maximum_import_queue_length
    import_event_growth = $executionResult.import_event_growth
    cleanup = $executionResult.cleanup
    formal_generation = $false
    generation9_formal_execution_count = 0
    product_candidate_head_sha = $productCandidateHeadSha
    product_candidate_tree_sha = $productCandidateTreeSha
    product_file_mutation_count = 0
    frozen_probe_rewrite_count = 0
}
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 100) + "`n"), $utf8)
[IO.File]::WriteAllText($reportPath, (($report | ConvertTo-Json -Depth 100) + "`n"), $utf8)
foreach ($path in @($manifestPath, $reportPath)) {
    $sidecarPath = "$path.sha256"
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($sidecarPath, "$hash  $([IO.Path]::GetFileName($path))`n", $utf8)
}

$report | ConvertTo-Json -Depth 100
