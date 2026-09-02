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
        'TOOLING_FAILURE_WINDOW_COORDINATE_MAPPING',
        'TOOLING_FAILURE_SCREENSHOT_WINDOW_RELATIVE_COORDINATE_OFFSET',
        'TOOLING_FAILURE_EXTERNAL_TO_RUNTIME_GUI_FOCUS_BINDING',
        'TOOLING_FAILURE_OTHER',
        'PRODUCT_FAILURE'
    )]
    [string]$Classification,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 4)]
    [int]$LaunchIndexAfterRequalification,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 3)]
    [int]$RemainingLaunchCount,

    [string]$NextProbeId = ''
)

$ErrorActionPreference = 'Stop'
$authorizationId = 'USER_AUTHORIZATION_V076_POST_RESTART_REQUALIFICATION_20260902'
$probeBudgetAuthorizationId = 'USER_SUPPLEMENTAL_AUTHORIZATION_V076_GENERATION9_PROBES_PLUS3_20260902'
$parentAuthorizationId = 'USER_AUTHORIZATION_V076_COMMIT_CAPACITY_AND_GENERATION9_20260902'
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
if ($RemainingLaunchCount -gt 0 -and $normalizedNextProbeId -notmatch '^probe-\d{3}$') {
    throw 'A next monotonic Probe ID is required while launch budget remains.'
}
if ($RemainingLaunchCount -eq 0 -and $normalizedNextProbeId -ne '') {
    throw 'Next Probe ID must be empty when the launch budget is exhausted.'
}
$qualificationPass = (
    $Classification -ceq 'QUALIFICATION_PASS' -and
    [string]$executionResult.status -ceq 'PASS'
)
if (($Classification -ceq 'QUALIFICATION_PASS') -ne ([string]$executionResult.status -ceq 'PASS')) {
    throw 'Classification and execution status disagree.'
}

[IO.Directory]::CreateDirectory($destinationRoot) | Out-Null
$manifestPath = Join-Path $destinationRoot 'raw_evidence_manifest.json'
$reportPath = Join-Path $destinationRoot 'platform_probe_report.json'
$manifest = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_platform_probe_raw_evidence_manifest.v1'
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
    schema_version = 'space_syndicate.v076.generation9_platform_probe_packaged_report.v1'
    authorization_id = $authorizationId
    probe_budget_authorization_id = $probeBudgetAuthorizationId
    parent_authorization_id = $parentAuthorizationId
    probe_id = $ProbeId
    generated_at_utc = $generatedAt
    status = [string]$executionResult.status
    classification = $Classification
    qualification_pass = $qualificationPass
    consecutive_pass_carry = $false
    launch_index_after_requalification = $LaunchIndexAfterRequalification
    remaining_launch_count = $RemainingLaunchCount
    next_probe_id = if ($normalizedNextProbeId -eq '') {$null} else {$normalizedNextProbeId}
    execution_result_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $executionResultPath).Hash.ToLowerInvariant()
    raw_evidence_manifest_file_count = $sourceFiles.Count
    failure = $executionResult.failure
    milestone_pass_count = $executionResult.milestone_pass_count
    milestone_required_count = $executionResult.milestone_required_count
    seed_four_layer_match = [bool]$executionResult.seed_binding.four_layer_match
    external_focus_witness_status = if ($null -ne $focusWitness) {[string]$focusWitness.status} else {$null}
    external_focus_failure_domain = if ($null -ne $focusWitness) {[string]$focusWitness.failure_domain} else {$null}
    minimum_available_commit_bytes = $executionResult.minimum_available_commit_bytes
    maximum_import_queue_length = $executionResult.maximum_import_queue_length
    import_event_growth = $executionResult.import_event_growth
    cleanup = $executionResult.cleanup
    formal_generation = $false
    generation9_formal_execution_count = 0
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
