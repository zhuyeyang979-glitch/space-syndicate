[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $projectRoot "scripts/tools/cold_restore_official_attempt2_contract.psm1"
$authorizationModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_authorization_contract_v1.psm1"
$null = Import-Module $authorizationModulePath -Force
$officialAuthorization = Get-ColdRestoreAuthorizationEntry "official_attempt_2"
$rehearsalAuthorization = Get-ColdRestoreAuthorizationEntry "process_a_save_completion_rehearsal_v1"
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$root = Join-Path ([IO.Path]::GetTempPath()) "alpha04c attempt2 claim $([Guid]::NewGuid().ToString('N'))"
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
$attempt1Sha = [string]$officialAuthorization.attempt_1_claim_sha256
$head = "a" * 40
$scenario = "b" * 64

function Assert-Attempt2Condition {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Get-ThrownReason {
    param([scriptblock]$Action)
    try { & $Action | Out-Null } catch { return [string]$_.Exception.Message }
    return ""
}

function Copy-Value {
    param($Value)
    return $Value | ConvertTo-Json -Depth 32 | ConvertFrom-Json -DateKind String
}

function New-Attempt2Claim {
    param(
        [string]$SourceHead = $head,
        [string]$RunId = "$([string]$officialAuthorization.run_id_prefix)-$($SourceHead.Substring(0, 12))"
    )
    return [pscustomobject][ordered]@{
        schema_version = 2
        claim_id = "OfficialAttemptClaimV2"
        attempt_number = 2
        authorization_id = [string]$officialAuthorization.authorization_id
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        run_id = $RunId
        source_head = $SourceHead
        rehearsal_green_head = $SourceHead
        scenario_fingerprint = $scenario
        challenge_depth = 1
        seed = [int64]900626424
        local_player_count = 1
        ai_player_count = 3
        timeout_policy_sha256 = "c" * 64
        prerequisite_evidence_fingerprint = "6" * 64
        preclaim_runtime_freeze_fingerprint = "7" * 64
        process_role_timeouts = [pscustomobject][ordered]@{
            process_a = [pscustomobject][ordered]@{ absolute_timeout_seconds = 180; no_progress_timeout_seconds = 60 }
            process_b = [pscustomobject][ordered]@{ absolute_timeout_seconds = 360; no_progress_timeout_seconds = 60 }
            process_c = [pscustomobject][ordered]@{ absolute_timeout_seconds = 180; no_progress_timeout_seconds = 30 }
        }
        rehearsal_run_id = "$([string]$rehearsalAuthorization.run_id_prefix)-$($SourceHead.Substring(0, 12))"
        rehearsal_evidence_fingerprint = "d" * 64
        rehearsal_outcome_sha256 = "e" * 64
        rehearsal_admission_sha256 = "f" * 64
        rehearsal_launch_sha256 = "1" * 64
        rehearsal_completion_sha256 = "2" * 64
        rehearsal_child_attestation_sha256 = "3" * 64
        rehearsal_parent_attestation_sha256 = "4" * 64
        attempt_1_claim_relative_path = ([string]$officialAuthorization.attempt_1_claim_relative_path).Substring("codex/cold_restore_v3/".Length)
        attempt_1_claim_sha256 = $attempt1Sha
        orchestrator_id = "alpha04c_cold_restore_vertical_slice_orchestrator_v4"
        orchestrator_schema_version = 4
        orchestrator_script_sha256 = "5" * 64
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = [DateTime]::UtcNow.Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
        claim_nonce = [Guid]::NewGuid().ToString("N")
        status = "consumed"
        authorized_official_count = 1
        official_count_before = 1
        official_count_after = 2
    }
}

try {
    [IO.Directory]::CreateDirectory($root) | Out-Null
    Import-Module $modulePath -Force
    Import-Module $authorizationModulePath -Force
    $source = [IO.File]::ReadAllText($orchestratorPath)
    $gitCommonRaw = [string](& git -C $projectRoot rev-parse --path-format=absolute --git-common-dir)
    $gitCommon = [IO.Path]::GetFullPath($gitCommonRaw.Trim())
    $realAttempt1 = Join-Path $gitCommon ([string]$officialAuthorization.attempt_1_claim_relative_path)
    $realAttempt2 = Join-Path $gitCommon ([string]$officialAuthorization.claim_path)
    $realAttempt1Before = (Get-FileHash -LiteralPath $realAttempt1 -Algorithm SHA256).Hash.ToLowerInvariant()
    $realAttempt2Before = [IO.File]::Exists($realAttempt2)

    $info = Get-ColdRestoreOfficialAttempt2ContractInfo
    Assert-Attempt2Condition ([string]$info.claim_id -ceq "OfficialAttemptClaimV2" -and [int]$info.schema_version -eq 2) "V2 claim identity is closed"
    Assert-Attempt2Condition (@($info.claim_fields).Count -eq 37) "V2 claim has the exact field count"
    $claim = New-Attempt2Claim
    Assert-Attempt2Condition ((Get-ThrownReason { Assert-ColdRestoreOfficialAttempt2Claim $claim }) -ceq "") "valid V2 claim passes strict validation"

    foreach ($case in @(
        [pscustomobject]@{ name = "head"; field = "source_head"; value = "9" * 40; reason = "official_attempt_2_claim_invalid" },
        [pscustomobject]@{ name = "scenario"; field = "scenario_fingerprint"; value = "bad"; reason = "official_attempt_2_claim_invalid" },
        [pscustomobject]@{ name = "policy"; field = "timeout_policy_sha256"; value = "bad"; reason = "official_attempt_2_claim_invalid" },
        [pscustomobject]@{ name = "prerequisite"; field = "prerequisite_evidence_fingerprint"; value = "bad"; reason = "official_attempt_2_claim_invalid" },
        [pscustomobject]@{ name = "runtime freeze"; field = "preclaim_runtime_freeze_fingerprint"; value = "bad"; reason = "official_attempt_2_claim_invalid" },
        [pscustomobject]@{ name = "rehearsal"; field = "rehearsal_evidence_fingerprint"; value = "bad"; reason = "official_attempt_2_claim_invalid" },
        [pscustomobject]@{ name = "attempt1"; field = "attempt_1_claim_sha256"; value = "0" * 64; reason = "official_attempt_2_claim_invalid" }
    )) {
        $mutated = Copy-Value $claim
        $mutated.($case.field) = $case.value
        Assert-Attempt2Condition ((Get-ThrownReason { Assert-ColdRestoreOfficialAttempt2Claim $mutated }) -ceq $case.reason) "wrong $($case.name) binding fails closed"
    }
    foreach ($timeoutCase in @(
        [pscustomobject]@{ role = "process_a"; field = "absolute_timeout_seconds"; value = 179 },
        [pscustomobject]@{ role = "process_a"; field = "no_progress_timeout_seconds"; value = 59 },
        [pscustomobject]@{ role = "process_b"; field = "absolute_timeout_seconds"; value = 359 },
        [pscustomobject]@{ role = "process_b"; field = "no_progress_timeout_seconds"; value = 59 },
        [pscustomobject]@{ role = "process_c"; field = "absolute_timeout_seconds"; value = 179 },
        [pscustomobject]@{ role = "process_c"; field = "no_progress_timeout_seconds"; value = 29 }
    )) {
        $wrongTimeout = Copy-Value $claim
        $wrongTimeout.process_role_timeouts.($timeoutCase.role).($timeoutCase.field) = $timeoutCase.value
        Assert-Attempt2Condition (
            (Get-ThrownReason { Assert-ColdRestoreOfficialAttempt2Claim $wrongTimeout }) `
                -ceq "official_attempt_2_role_timeout_invalid"
        ) "wrong $($timeoutCase.role) $($timeoutCase.field) fails closed"
    }

    $attempt1Fixture = Join-Path $root "official-alpha04c-depth1-seed900626424\official_claim_ledger.json"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $attempt1Fixture)) | Out-Null
    [IO.File]::WriteAllText($attempt1Fixture, "immutable-attempt-1", [Text.UTF8Encoding]::new($false))
    $attempt1FixtureBefore = (Get-FileHash -LiteralPath $attempt1Fixture -Algorithm SHA256).Hash.ToLowerInvariant()
    $claimPath = Join-Path $root "official-alpha04c-attempt-2-depth1-seed900626424\official_attempt_2_claim.json"
    $claimSha = Publish-ColdRestoreOfficialAttempt2Claim $claimPath $claim
    Assert-Attempt2Condition ([string]$claimSha -cmatch '^[0-9a-f]{64}$' -and [IO.File]::Exists($claimPath)) "Attempt 2 publishes to its independent path"
    Assert-Attempt2Condition ((Get-FileHash -LiteralPath $attempt1Fixture -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $attempt1FixtureBefore) "Attempt 1 fixture remains immutable"
    Assert-Attempt2Condition ((Get-ThrownReason { Publish-ColdRestoreOfficialAttempt2Claim $claimPath $claim }) -ceq "official_attempt_2_authorization_already_consumed") "duplicate Attempt 2 claim is rejected"
    Assert-Attempt2Condition (@(Get-ChildItem (Split-Path -Parent $claimPath) -Filter '*.tmp.*' -Force).Count -eq 0) "exclusive publication leaves no temporary sidecar"

    $racePath = Join-Path $root "race\official_attempt_2_claim.json"
    $startTicks = [DateTime]::UtcNow.AddMilliseconds(500).Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
    $jobs = foreach ($suffix in @("6", "7")) {
        Start-Job -ScriptBlock {
            param($ModulePath, $AuthorizationModulePath, $TargetPath, $StartTicks, $Suffix)
            Import-Module $AuthorizationModulePath -Force
            Import-Module $ModulePath -Force
            Import-Module $AuthorizationModulePath -Force
            $official = Get-ColdRestoreAuthorizationEntry "official_attempt_2"
            $rehearsal = Get-ColdRestoreAuthorizationEntry "process_a_save_completion_rehearsal_v1"
            $start = [DateTime]::new([int64]$StartTicks, [DateTimeKind]::Utc)
            while ([DateTime]::UtcNow -lt $start) { Start-Sleep -Milliseconds 5 }
            $head = $Suffix * 40
            $claim = [pscustomobject][ordered]@{
                schema_version = 2; claim_id = "OfficialAttemptClaimV2"; attempt_number = 2
                authorization_id = [string]$official.authorization_id
                created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
                run_id = "$([string]$official.run_id_prefix)-$($head.Substring(0, 12))"; source_head = $head; rehearsal_green_head = $head
                scenario_fingerprint = "b" * 64; challenge_depth = 1; seed = [int64]900626424
                local_player_count = 1; ai_player_count = 3; timeout_policy_sha256 = "c" * 64
                prerequisite_evidence_fingerprint = "8" * 64; preclaim_runtime_freeze_fingerprint = "9" * 64
                process_role_timeouts = [pscustomobject][ordered]@{
                    process_a = [pscustomobject][ordered]@{ absolute_timeout_seconds = 180; no_progress_timeout_seconds = 60 }
                    process_b = [pscustomobject][ordered]@{ absolute_timeout_seconds = 360; no_progress_timeout_seconds = 60 }
                    process_c = [pscustomobject][ordered]@{ absolute_timeout_seconds = 180; no_progress_timeout_seconds = 30 }
                }
                rehearsal_run_id = "$([string]$rehearsal.run_id_prefix)-$($head.Substring(0, 12))"
                rehearsal_evidence_fingerprint = "d" * 64; rehearsal_outcome_sha256 = "e" * 64
                rehearsal_admission_sha256 = "f" * 64; rehearsal_launch_sha256 = "1" * 64
                rehearsal_completion_sha256 = "2" * 64; rehearsal_child_attestation_sha256 = "3" * 64
                rehearsal_parent_attestation_sha256 = "4" * 64
                attempt_1_claim_relative_path = ([string]$official.attempt_1_claim_relative_path).Substring("codex/cold_restore_v3/".Length)
                attempt_1_claim_sha256 = [string]$official.attempt_1_claim_sha256
                orchestrator_id = "alpha04c_cold_restore_vertical_slice_orchestrator_v4"; orchestrator_schema_version = 4
                orchestrator_script_sha256 = "5" * 64; orchestrator_process_id = $PID
                orchestrator_creation_time_utc_ticks = [DateTime]::UtcNow.Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
                claim_nonce = [Guid]::NewGuid().ToString("N"); status = "consumed"
                authorized_official_count = 1; official_count_before = 1; official_count_after = 2
            }
            try { $null = Publish-ColdRestoreOfficialAttempt2Claim $TargetPath $claim; [pscustomobject]@{ won = $true; reason = "ok" } }
            catch { [pscustomobject]@{ won = $false; reason = [string]$_.Exception.Message } }
        } -ArgumentList $modulePath, $authorizationModulePath, $racePath, $startTicks, $suffix
    }
    $race = @($jobs | Wait-Job | Receive-Job)
    $jobs | Remove-Job -Force
    Assert-Attempt2Condition (@($race | Where-Object won).Count -eq 1 -and @($race | Where-Object { -not $_.won }).Count -eq 1) "concurrent Attempt 2 claim has one winner"
    Assert-Attempt2Condition (@($race | Where-Object { -not $_.won })[0].reason -ceq "official_attempt_2_authorization_already_consumed") "concurrent loser observes consumed authorization"

    $preflightFunctionStart = $source.IndexOf("function Assert-AndConsumeOfficialColdRestoreAuthorization", [StringComparison]::Ordinal)
    $preflightFunctionEnd = $source.IndexOf("function New-ColdRestoreOfficialAttempt2PreflightOutput", $preflightFunctionStart, [StringComparison]::Ordinal)
    $preflightFunction = $source.Substring($preflightFunctionStart, $preflightFunctionEnd - $preflightFunctionStart)
    Assert-Attempt2Condition ($preflightFunction.IndexOf('if ($PreflightOnly)', [StringComparison]::Ordinal) -ge 0 -and $preflightFunction.IndexOf('if ($PreflightOnly)', [StringComparison]::Ordinal) -lt $preflightFunction.IndexOf("Publish-ColdRestoreOfficialAttempt2Claim", [StringComparison]::Ordinal)) "preflight validates the same candidate before publication"
    Assert-Attempt2Condition ($source.Contains('[switch]$OfficialAttempt2PreflightOnly') -and $source.Contains('-not $OfficialAttempt2PreflightOnly) {') -and $source.Contains('godot_launch_attempted = $false')) "preflight skips Godot resolution and advertises no launch"
    Assert-Attempt2Condition ($source.IndexOf('if ($OfficialAttempt2PreflightOnly)', [StringComparison]::Ordinal) -lt $source.IndexOf('$authorization = Assert-AndConsumeOfficialColdRestoreAuthorization $resolvedProjectPath $headSha', [StringComparison]::Ordinal)) "preflight exits before the consuming dispatch"
    $boundaryFunctionStart = $source.IndexOf("function Get-ColdRestoreOfficialAttemptBoundaryObservation", [StringComparison]::Ordinal)
    $boundaryFunctionEnd = $source.IndexOf("function Assert-ColdRestoreOfficialAttemptBoundary", $boundaryFunctionStart, [StringComparison]::Ordinal)
    $boundaryFunction = $source.Substring($boundaryFunctionStart, $boundaryFunctionEnd - $boundaryFunctionStart)
    Assert-Attempt2Condition (
        -not $boundaryFunction.Contains("SilentlyContinue") `
            -and $boundaryFunction.Contains('-ErrorAction Stop') `
            -and $boundaryFunction.Contains('throw "official_claim_inventory_unavailable"')
    ) "official claim inventory enumeration fails closed"

    Assert-Attempt2Condition ((Get-FileHash -LiteralPath $realAttempt1 -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $realAttempt1Before -and $realAttempt1Before -ceq $attempt1Sha) "real Attempt 1 remains immutable"
    Assert-Attempt2Condition ([IO.File]::Exists($realAttempt2) -eq $realAttempt2Before) "test creates no real Attempt 2 claim"
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}
finally {
    $resolvedRoot = [IO.Path]::GetFullPath($root)
    if ($resolvedRoot.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) `
        -and [IO.Path]::GetFileName($resolvedRoot).StartsWith("alpha04c attempt2 claim ", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_OFFICIAL_ATTEMPT2_CONTRACT|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) { Write-Output "FAIL|$failure" }
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
