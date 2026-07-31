[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $projectRoot "scripts/tools/cold_restore_prequota_bootstrap.psm1"
$authorizationModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_authorization_contract_v1.psm1"
$attestedModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_attested_process.psm1"
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$root = Join-Path ([IO.Path]::GetTempPath()) ("alpha04c prequota 路径 " + [Guid]::NewGuid().ToString("N"))
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
Import-Module $authorizationModulePath -Force
$script:TargetedAuthorization = Get-ColdRestoreAuthorizationEntry "targeted_owner_capture_diagnostic_v3"
$script:OfficialAuthorization = Get-ColdRestoreAuthorizationEntry "official_attempt_2"

function Assert-PreQuotaCondition {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Get-ThrownReason {
    param([scriptblock]$Action)
    try { & $Action } catch { return [string]$_.Exception.Message }
    return ""
}

function New-FixtureQuotaLedger {
    param(
        [string]$RunId = "",
        [string]$RepositoryHead = ("a" * 40),
        [int]$ProcessId = $PID
    )
    if ([string]::IsNullOrEmpty($RunId)) {
        $RunId = Get-ColdRestoreAuthorizationRunId `
            "targeted_owner_capture_diagnostic_v3" $RepositoryHead
    }
    return [pscustomobject][ordered]@{
        schema_version = 3
        ledger_id = [string]$script:TargetedAuthorization.ledger_id
        authorization_id = [string]$script:TargetedAuthorization.authorization_id
        task_id = [string]$script:TargetedAuthorization.task_id
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        run_id = $RunId
        repository_head = $RepositoryHead
        scenario_fingerprint = "b" * 64
        authorized_new_diagnostic_count = [int]$script:TargetedAuthorization.authorized_increment
        diagnostic_count_before = [int]$script:TargetedAuthorization.permitted_transition_from
        diagnostic_count_after = [int]$script:TargetedAuthorization.permitted_transition_to
        diagnostic_count_maximum = [int]$script:TargetedAuthorization.maximum_invocation_count
        previous_ledger_sha256 = "c" * 64
        historical_invocation_commit = "d" * 40
        historical_invocation_blob_sha1 = "e" * 40
        historical_invocation_file_sha256 = "f" * 64
        bootstrap_admission_path = Join-Path $root "bootstrap/admission.json"
        bootstrap_admission_sha256 = "1" * 64
        bootstrap_admission_fingerprint = "2" * 64
        prequota_attestation_path = Join-Path $root "bootstrap/prequota.json"
        role_timeout_policy_sha256 = "3" * 64
        official_attempt_1_claim_sha256 = [string]$script:OfficialAuthorization.attempt_1_claim_sha256
        official_attempt_2_claim_absent = $true
        official = $false
        formal = $false
        official_authorization_consumed = $false
        orchestrator_script_sha256 = "5" * 64
        orchestrator_process_id = $ProcessId
        orchestrator_creation_time_utc_ticks = [DateTime]::UtcNow.Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
        claim_nonce = [Guid]::NewGuid().ToString("N")
        launch_nonce = [Guid]::NewGuid().ToString("N")
        status = "consumed"
    }
}

try {
    Import-Module $attestedModulePath -Force
    Import-Module $modulePath -Force

    Assert-PreQuotaCondition ((Get-ColdRestoreSafeCollectionCount $null) -eq 0) "null counts as zero"
    Assert-PreQuotaCondition ((Get-ColdRestoreSafeCollectionCount @()) -eq 0) "empty array counts as zero"
    $emptyPipeline = Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | Where-Object { $false }
    Assert-PreQuotaCondition ((Get-ColdRestoreSafeCollectionCount $emptyPipeline) -eq 0) "empty pipeline counts as zero"
    Assert-PreQuotaCondition ((Get-ColdRestoreSafeCollectionCount "one") -eq 1) "one scalar counts as one"
    Assert-PreQuotaCondition ((Get-ColdRestoreSafeCollectionCount ([pscustomobject]@{ id = 1 })) -eq 1) "one object counts as one"
    Assert-PreQuotaCondition ((Get-ColdRestoreSafeCollectionCount @(1, 2, 3)) -eq 3) "multiple objects retain count"
    $nested = ,@(1, 2)
    Assert-PreQuotaCondition ((Get-ColdRestoreSafeCollectionCount $nested) -eq 1) "nested collection remains one outer item"

    $failureState = New-ColdRestorePrimaryFailureState
    $first = Add-ColdRestoreFailureRecord $failureState "quota_claim" "diagnostic_quota_unavailable" "quota_failure" "quota"
    $second = Add-ColdRestoreFailureRecord $failureState "postcondition_validation" "postcondition_collection_normalization_failed" "postcondition_failure" "postcondition"
    $third = Add-ColdRestoreFailureRecord $failureState "cleanup" "cleanup_fixture_failed" "cleanup_failure" "cleanup"
    $fourth = Add-ColdRestoreFailureRecord $failureState "evidence_write" "evidence_write_fixture_failed" "evidence_write_failure" "evidence_write"
    $projection = Get-ColdRestoreFailureProjection $failureState
    Assert-PreQuotaCondition ([string]$projection.primary_failure_code -ceq "diagnostic_quota_unavailable") "first typed failure is primary"
    Assert-PreQuotaCondition ([string]$projection.primary_failure.phase -ceq "quota_claim") "primary phase remains exact"
    Assert-PreQuotaCondition (@($projection.primary_failure.PSObject.Properties.Name).Count -eq 4) "PrimaryFailureRecordV1 has four fields"
    Assert-PreQuotaCondition ([int]$projection.primary_failure.safe_details.observation_sequence -eq 1) "primary observation starts at one"
    Assert-PreQuotaCondition ((@($projection.secondary_failure_codes) -join ',') -ceq "postcondition_collection_normalization_failed,cleanup_fixture_failed,evidence_write_fixture_failed") "secondary order is deterministic"
    Assert-PreQuotaCondition ([int]$projection.primary_failure_overwrite_count -eq 0) "primary is never overwritten"
    Assert-PreQuotaCondition ([int]$second.safe_details.observation_sequence -eq 2 -and [int]$third.safe_details.observation_sequence -eq 3 -and [int]$fourth.safe_details.observation_sequence -eq 4) "observation sequence is monotonic"
    $failureException = New-ColdRestoreFailureException $failureState
    $roundTripProjection = Get-ColdRestoreFailureProjectionFromError ([Management.Automation.ErrorRecord]::new(
        $failureException, "fixture", [Management.Automation.ErrorCategory]::InvalidOperation, $null
    ))
    Assert-PreQuotaCondition ([string]$roundTripProjection.primary_failure_code -ceq "diagnostic_quota_unavailable") "exception retains private failure projection"

    [IO.Directory]::CreateDirectory($root) | Out-Null
    $head = "a" * 40
    $binding = Get-ColdRestoreTargetedDiagnosticAuthorizationBinding $root $head
    $bootstrapRoot = [string]$binding.bootstrap_root
    $quotaPath = [string]$binding.quota_ledger_path
    $runId = [string]$binding.run_id
    $context = New-ColdRestorePreQuotaContext `
        -GitCommonDirectory $root `
        -BootstrapRoot $bootstrapRoot `
        -RunId $runId `
        -RepositoryHead $head `
        -Branch "codex/fixture branch" `
        -AuthorizationId $binding.authorization_id `
        -QuotaLedgerPath $quotaPath
    Assert-PreQuotaCondition ([IO.File]::Exists($context.admission_path)) "bootstrap admission is written"
    Assert-PreQuotaCondition ([IO.File]::Exists($context.attestation_path)) "prequota attestation is written"
    $green = Update-ColdRestorePreQuotaAttestation `
        -Context $context `
        -Updates ([ordered]@{
            authorization_checked = $true
            quota_claim_attempted = $true
            quota_claimed = $true
            evidence_root_creation_attempted = $true
            evidence_root_created = $true
            godot_launch_attempted = $true
            godot_launched = $true
            task_owned_process_count_after = 0
        })
    Assert-PreQuotaCondition ([string]$green.fingerprint -cmatch '^[0-9a-f]{64}$') "prequota attestation has a semantic fingerprint"
    Assert-PreQuotaCondition ([string]$green.sha256 -ceq (Get-FileHash -LiteralPath $green.path -Algorithm SHA256).Hash.ToLowerInvariant()) "prequota attestation readback SHA matches"
    Assert-PreQuotaCondition ([bool]$green.value.quota_claimed -and [bool]$green.value.godot_launched) "green lifecycle flags survive readback"

    $replacePath = Join-Path $root "replace atomic/evidence.json"
    $originalReplacementValue = [pscustomobject][ordered]@{ schema_version = 1; value = "original" }
    $originalReplacementSha = Write-ColdRestoreAtomicJson $replacePath $originalReplacementValue
    $beforePublishReason = Get-ThrownReason {
        Write-ColdRestoreReplacingAtomicJson `
            -Path $replacePath `
            -Value ([pscustomobject][ordered]@{ schema_version = 1; value = "before" }) `
            -FailureInjectionPhase before_publish | Out-Null
    }
    Assert-PreQuotaCondition ($beforePublishReason -ceq "replacing_evidence_injected_before_publish" `
        -and (Get-FileHash -LiteralPath $replacePath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $originalReplacementSha) "prepublication failure preserves the previous evidence"
    $afterPublishReason = Get-ThrownReason {
        Write-ColdRestoreReplacingAtomicJson `
            -Path $replacePath `
            -Value ([pscustomobject][ordered]@{ schema_version = 1; value = "after" }) `
            -FailureInjectionPhase after_publish | Out-Null
    }
    Assert-PreQuotaCondition ($afterPublishReason -ceq "replacing_evidence_injected_after_publish" `
        -and (Get-FileHash -LiteralPath $replacePath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $originalReplacementSha) "postpublication verification failure restores the previous evidence"
    $newReplacementPath = Join-Path $root "replace atomic/new-evidence.json"
    $newPublishReason = Get-ThrownReason {
        Write-ColdRestoreReplacingAtomicJson `
            -Path $newReplacementPath `
            -Value ([pscustomobject][ordered]@{ schema_version = 1; value = "new" }) `
            -FailureInjectionPhase after_publish | Out-Null
    }
    Assert-PreQuotaCondition ($newPublishReason -ceq "replacing_evidence_injected_after_publish" `
        -and -not [IO.File]::Exists($newReplacementPath)) "failed first publication restores target absence"

    $contextBefore = ConvertTo-ColdRestoreCanonicalJson $context.value
    $contextShaBefore = [string]$context.attestation_sha256
    $diskShaBefore = (Get-FileHash -LiteralPath $context.attestation_path -Algorithm SHA256).Hash.ToLowerInvariant()
    $lock = [IO.FileStream]::new(
        $context.attestation_path,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::Read
    )
    try {
        $lockedUpdateReason = Get-ThrownReason {
            Update-ColdRestorePreQuotaAttestation `
                -Context $context `
                -Updates ([ordered]@{ task_owned_process_count_after = 1 }) | Out-Null
        }
    }
    finally {
        $lock.Dispose()
    }
    Assert-PreQuotaCondition ($lockedUpdateReason -ceq "replacing_evidence_publish_failed") "locked replacement fails with a typed publication reason"
    Assert-PreQuotaCondition ((ConvertTo-ColdRestoreCanonicalJson $context.value) -ceq $contextBefore `
        -and [string]$context.attestation_sha256 -ceq $contextShaBefore) "failed update does not advance the live PreQuota context"
    Assert-PreQuotaCondition ((Get-FileHash -LiteralPath $context.attestation_path -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $diskShaBefore) "failed update preserves the durable PreQuota attestation"
    Assert-PreQuotaCondition (@(Get-ChildItem -LiteralPath (Split-Path -Parent $replacePath) -File `
        | Where-Object { $_.Name -match '\.(tmp|swap|rollback)\.' }).Count -eq 0) "successful rollback leaves no replacement sidecars"

    $cleanupReason = Get-ThrownReason {
        Write-ColdRestoreReplacingAtomicJson `
            -Path $replacePath `
            -Value ([pscustomobject][ordered]@{ schema_version = 1; value = "cleanup" }) `
            -FailureInjectionPhase cleanup | Out-Null
    }
    Assert-PreQuotaCondition ($cleanupReason -ceq "replacing_evidence_cleanup_failed" `
        -and (Get-FileHash -LiteralPath $replacePath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $originalReplacementSha) "standalone cleanup failure rolls back and fails closed"

    $rollbackFailurePath = Join-Path $root "rollback retained/evidence.json"
    $rollbackOriginalSha = Write-ColdRestoreAtomicJson $rollbackFailurePath $originalReplacementValue
    $rollbackError = $null
    try {
        Write-ColdRestoreReplacingAtomicJson `
            -Path $rollbackFailurePath `
            -Value ([pscustomobject][ordered]@{ schema_version = 1; value = "rollback failure" }) `
            -FailureInjectionPhase after_publish_rollback_failure | Out-Null
    }
    catch {
        $rollbackError = $_
    }
    $rollbackSecondaries = @(Get-ColdRestoreSecondaryFailureCodesFromError $rollbackError)
    Assert-PreQuotaCondition ($null -ne $rollbackError `
        -and [string]$rollbackError.Exception.Message -ceq "replacing_evidence_injected_after_publish" `
        -and $rollbackSecondaries -contains "replacing_evidence_rollback_failed") "rollback failure preserves the original primary and attaches a typed secondary"
    $retainedBackups = @(Get-ChildItem -LiteralPath (Split-Path -Parent $rollbackFailurePath) -File `
        | Where-Object { $_.Name -like 'evidence.json.swap.*' })
    Assert-PreQuotaCondition ($retainedBackups.Count -eq 1 `
        -and (Get-FileHash -LiteralPath $retainedBackups[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $rollbackOriginalSha) "failed rollback retains the previous valid evidence backup"

    $rollbackVerificationPath = Join-Path $root "rollback verification retained/evidence.json"
    $rollbackVerificationSha = Write-ColdRestoreAtomicJson $rollbackVerificationPath $originalReplacementValue
    $rollbackVerificationError = $null
    try {
        Write-ColdRestoreReplacingAtomicJson `
            -Path $rollbackVerificationPath `
            -Value ([pscustomobject][ordered]@{ schema_version = 1; value = "rollback verification failure" }) `
            -FailureInjectionPhase after_publish_rollback_verification_failure | Out-Null
    }
    catch {
        $rollbackVerificationError = $_
    }
    $rollbackVerificationSecondaries = @(Get-ColdRestoreSecondaryFailureCodesFromError $rollbackVerificationError)
    $rollbackKnownGood = @(Get-ChildItem -LiteralPath (Split-Path -Parent $rollbackVerificationPath) -File `
        | Where-Object { $_.Name -like 'evidence.json.known-good.*' })
    Assert-PreQuotaCondition ($null -ne $rollbackVerificationError `
        -and [string]$rollbackVerificationError.Exception.Message -ceq "replacing_evidence_injected_after_publish" `
        -and $rollbackVerificationSecondaries -contains "replacing_evidence_rollback_failed" `
        -and $rollbackKnownGood.Count -eq 1 `
        -and (Get-FileHash -LiteralPath $rollbackKnownGood[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $rollbackVerificationSha) "post-replace rollback verification failure retains an immutable known-good copy"

    $cleanupVerificationPath = Join-Path $root "cleanup rollback verification retained/evidence.json"
    $cleanupVerificationSha = Write-ColdRestoreAtomicJson $cleanupVerificationPath $originalReplacementValue
    $cleanupVerificationError = $null
    try {
        Write-ColdRestoreReplacingAtomicJson `
            -Path $cleanupVerificationPath `
            -Value ([pscustomobject][ordered]@{ schema_version = 1; value = "cleanup rollback verification failure" }) `
            -FailureInjectionPhase cleanup_rollback_verification_failure | Out-Null
    }
    catch {
        $cleanupVerificationError = $_
    }
    $cleanupVerificationSecondaries = @(Get-ColdRestoreSecondaryFailureCodesFromError $cleanupVerificationError)
    $cleanupKnownGood = @(Get-ChildItem -LiteralPath (Split-Path -Parent $cleanupVerificationPath) -File `
        | Where-Object { $_.Name -like 'evidence.json.known-good.*' })
    Assert-PreQuotaCondition ($null -ne $cleanupVerificationError `
        -and [string]$cleanupVerificationError.Exception.Message -ceq "replacing_evidence_cleanup_failed" `
        -and $cleanupVerificationSecondaries -contains "replacing_evidence_rollback_failed" `
        -and $cleanupKnownGood.Count -eq 1 `
        -and (Get-FileHash -LiteralPath $cleanupKnownGood[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $cleanupVerificationSha) "cleanup compensation verification failure retains an immutable known-good copy"
    $propagatedState = New-ColdRestorePrimaryFailureState
    $null = Add-ColdRestoreFailureRecord $propagatedState "evidence_write" $rollbackError.Exception.Message "evidence_write_failure" "evidence_write"
    foreach ($secondaryCode in $rollbackSecondaries) {
        $null = Add-ColdRestoreFailureRecord $propagatedState "evidence_write" $secondaryCode "evidence_write_secondary" "evidence_write"
    }
    $propagatedProjection = Get-ColdRestoreFailureProjection $propagatedState
    Assert-PreQuotaCondition ([string]$propagatedProjection.primary_failure_code -ceq "replacing_evidence_injected_after_publish" `
        -and @($propagatedProjection.secondary_failure_codes) -contains "replacing_evidence_rollback_failed") "writer secondary codes propagate into the shared immutable failure state"
    $orchestratorSourceAfterRepair = [IO.File]::ReadAllText($orchestratorPath)
    Assert-PreQuotaCondition ($orchestratorSourceAfterRepair.Contains("Get-ColdRestoreSecondaryFailureCodesFromError") `
        -and $orchestratorSourceAfterRepair.Contains('FallbackReasonCode "prequota_attestation_secondary_failure"')) "targeted PreQuota catches attest writer secondary failures"

    $failedHead = "b" * 40
    $failedBinding = Get-ColdRestoreTargetedDiagnosticAuthorizationBinding $root $failedHead
    $failedContext = New-ColdRestorePreQuotaContext `
        -GitCommonDirectory $root `
        -BootstrapRoot $failedBinding.bootstrap_root `
        -RunId $failedBinding.run_id `
        -RepositoryHead $failedHead `
        -Branch "codex/fixture" `
        -AuthorizationId $failedBinding.authorization_id `
        -QuotaLedgerPath $failedBinding.quota_ledger_path
    $failedState = New-ColdRestorePrimaryFailureState
    $null = Add-ColdRestoreFailureRecord $failedState "authorization_check" "expected_scenario_fingerprint_invalid" "parameter_failure" "parameter"
    $null = Add-ColdRestoreFailureRecord $failedState "postcondition_validation" "path_fixture_failed" "path_failure" "postcondition"
    $failedEvidence = Update-ColdRestorePreQuotaAttestation $failedContext ([ordered]@{ authorization_checked = $true }) $failedState
    Assert-PreQuotaCondition ([string]$failedEvidence.value.primary_failure_code -ceq "expected_scenario_fingerprint_invalid") "parameter failure produces durable prequota evidence"
    Assert-PreQuotaCondition ((@($failedEvidence.value.secondary_failure_codes) -join ',') -ceq "path_fixture_failed") "secondary path failure is attested"
    Assert-PreQuotaCondition (-not [bool]$failedEvidence.value.quota_claimed -and -not [bool]$failedEvidence.value.godot_launched) "preclaim failure consumes neither quota nor launch"

    $currentSource = [IO.File]::ReadAllText($orchestratorPath)
    $historicalSource = @(& git -C $projectRoot show "3b3061508541d0e5f6f4c2d6560b134b7d4ee5f8:scripts/tools/cold_restore_vertical_slice_orchestrator.ps1" 2>$null) -join "`n"
    $unsafePattern = '\$(cleanupRows|quitRows)\.Count'
    Assert-PreQuotaCondition ([regex]::Matches($historicalSource, $unsafePattern).Count -eq 2) "historical unsafe StrictMode count is measured as two"
    Assert-PreQuotaCondition ([regex]::Matches($currentSource, $unsafePattern).Count -eq 0) "unsafe StrictMode count is eliminated"
    Assert-PreQuotaCondition ($currentSource.Contains('Get-ColdRestoreSafeCollectionCount $cleanupRows') -and $currentSource.Contains('Get-ColdRestoreSafeCollectionCount $quitRows')) "timeline collections use the shared safe counter"

    $quotaFixturePath = Join-Path $root "quota fixtures/targeted_owner_capture_quota_ledger.json"
    $quotaLedger = New-FixtureQuotaLedger
    $quotaSha = Publish-ColdRestoreTargetedQuotaLedgerV3 $quotaFixturePath $quotaLedger
    Assert-PreQuotaCondition ([string]$quotaSha -cmatch '^[0-9a-f]{64}$' -and [IO.File]::Exists($quotaFixturePath)) "V3 third claim publishes atomically"
    $duplicateReason = Get-ThrownReason { Publish-ColdRestoreTargetedQuotaLedgerV3 $quotaFixturePath $quotaLedger | Out-Null }
    Assert-PreQuotaCondition ($duplicateReason -ceq "quota_already_consumed") "duplicate and fourth claim are rejected"

    $invalidPath = Join-Path $root "quota fixtures/invalid-ledger.json"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $invalidPath)) | Out-Null
    [IO.File]::WriteAllText($invalidPath, "{}", [Text.UTF8Encoding]::new($false))
    $staleReason = Get-ThrownReason { Publish-ColdRestoreTargetedQuotaLedgerV3 $invalidPath $quotaLedger | Out-Null }
    Assert-PreQuotaCondition ($staleReason -ceq "targeted_owner_capture_diagnostic_stale_ledger") "stale ledger is distinguished without overwrite"

    $preclaimPath = Join-Path $root "quota fixtures/preclaim-invalid.json"
    $invalidLedger = New-FixtureQuotaLedger
    $invalidLedger.diagnostic_count_before = 1
    $preclaimReason = Get-ThrownReason { Publish-ColdRestoreTargetedQuotaLedgerV3 $preclaimPath $invalidLedger | Out-Null }
    Assert-PreQuotaCondition ($preclaimReason -ceq "quota_transition_invalid" -and -not [IO.File]::Exists($preclaimPath)) "preclaim failure leaves the count at two"
    $postclaimPreserved = $false
    try {
        $postclaimPath = Join-Path $root "quota fixtures/postclaim.json"
        $null = Publish-ColdRestoreTargetedQuotaLedgerV3 $postclaimPath (New-FixtureQuotaLedger -RepositoryHead ("c" * 40))
        throw "synthetic_postclaim_failure"
    }
    catch {
        $postclaimPreserved = [string]$_.Exception.Message -ceq "synthetic_postclaim_failure" -and [IO.File]::Exists($postclaimPath)
    }
    Assert-PreQuotaCondition $postclaimPreserved "postclaim failure leaves the count permanently at three"

    $racePath = Join-Path $root "quota race/targeted_owner_capture_quota_ledger.json"
    $raceStartTicks = [DateTime]::UtcNow.AddMilliseconds(500).Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
    $raceJobs = foreach ($suffix in @("dddddddddddd", "eeeeeeeeeeee")) {
        Start-Job -ScriptBlock {
            param($ModulePath, $TargetPath, $RootPath, $Suffix, $StartTicks)
            Import-Module $ModulePath -Force
            Import-Module (Join-Path (Split-Path -Parent $ModulePath) "cold_restore_authorization_contract_v1.psm1") -Force
            $targeted = Get-ColdRestoreAuthorizationEntry "targeted_owner_capture_diagnostic_v3"
            $official = Get-ColdRestoreAuthorizationEntry "official_attempt_2"
            $start = [DateTime]::new([int64]$StartTicks, [DateTimeKind]::Utc)
            while ([DateTime]::UtcNow -lt $start) { Start-Sleep -Milliseconds 5 }
            $repositoryHead = $Suffix.Substring(0, 1) * 40
            $ledger = [pscustomobject][ordered]@{
                schema_version = 3; ledger_id = [string]$targeted.ledger_id
                authorization_id = [string]$targeted.authorization_id
                task_id = [string]$targeted.task_id
                created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
                run_id = Get-ColdRestoreAuthorizationRunId "targeted_owner_capture_diagnostic_v3" $repositoryHead
                repository_head = $repositoryHead
                scenario_fingerprint = "b" * 64
                authorized_new_diagnostic_count = [int]$targeted.authorized_increment
                diagnostic_count_before = [int]$targeted.permitted_transition_from
                diagnostic_count_after = [int]$targeted.permitted_transition_to
                diagnostic_count_maximum = [int]$targeted.maximum_invocation_count
                previous_ledger_sha256 = "c" * 64; historical_invocation_commit = "d" * 40
                historical_invocation_blob_sha1 = "e" * 40; historical_invocation_file_sha256 = "f" * 64
                bootstrap_admission_path = Join-Path $RootPath "admission.json"; bootstrap_admission_sha256 = "1" * 64
                bootstrap_admission_fingerprint = "2" * 64; prequota_attestation_path = Join-Path $RootPath "prequota.json"
                role_timeout_policy_sha256 = "3" * 64
                official_attempt_1_claim_sha256 = [string]$official.attempt_1_claim_sha256
                official_attempt_2_claim_absent = $true; official = $false; formal = $false
                official_authorization_consumed = $false; orchestrator_script_sha256 = "5" * 64
                orchestrator_process_id = $PID
                orchestrator_creation_time_utc_ticks = [DateTime]::UtcNow.Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
                claim_nonce = [Guid]::NewGuid().ToString("N"); launch_nonce = [Guid]::NewGuid().ToString("N"); status = "consumed"
            }
            try {
                $null = Publish-ColdRestoreTargetedQuotaLedgerV3 $TargetPath $ledger
                [pscustomobject]@{ won = $true; reason = "ok" }
            }
            catch {
                [pscustomobject]@{ won = $false; reason = [string]$_.Exception.Message }
            }
        } -ArgumentList $modulePath, $racePath, $root, $suffix, $raceStartTicks
    }
    $raceResults = @($raceJobs | Wait-Job | Receive-Job)
    $raceJobs | Remove-Job -Force
    Assert-PreQuotaCondition (@($raceResults | Where-Object { [bool]$_.won }).Count -eq 1 -and @($raceResults | Where-Object { -not [bool]$_.won }).Count -eq 1) "concurrent V3 claim has exactly one winner"
    Assert-PreQuotaCondition (@($raceResults | Where-Object { -not [bool]$_.won })[0].reason -ceq "quota_already_consumed") "concurrent loser observes consumed authorization"
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}
finally {
    $resolvedRoot = [IO.Path]::GetFullPath($root)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) `
        -and [IO.Path]::GetFileName($resolvedRoot).StartsWith("alpha04c prequota 路径 ", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_PREQUOTA_HARNESS_CONTRACT|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) { Write-Output "FAIL|$failure" }
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
