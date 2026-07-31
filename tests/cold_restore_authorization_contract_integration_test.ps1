[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$authorizationModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_authorization_contract_v1.psm1"
$preQuotaModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_prequota_bootstrap.psm1"
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$contractPath = Join-Path $projectRoot "scripts/tools/cold_restore_authorization_contract_v1.json"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "alpha04c V3 authorization 集成 " + [Guid]::NewGuid().ToString("N")
)
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()

function Assert-AuthorizationCondition {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Get-AuthorizationThrownReason {
    param([scriptblock]$Action)
    try { & $Action | Out-Null } catch { return [string]$_.Exception.Message }
    return ""
}

function New-AuthorizationQuotaLedger {
    param(
        [Parameter(Mandatory = $true)]$Binding,
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$RepositoryHead
    )

    $official = Get-ColdRestoreAuthorizationEntry "official_attempt_2"
    $claimNonce = [Guid]::NewGuid().ToString("N")
    do { $launchNonce = [Guid]::NewGuid().ToString("N") } while ($launchNonce -ceq $claimNonce)
    return [pscustomobject][ordered]@{
        schema_version = 3
        ledger_id = [string]$Binding.ledger_id
        authorization_id = [string]$Binding.authorization_id
        task_id = [string]$Binding.task_id
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        run_id = [string]$Binding.run_id
        repository_head = $RepositoryHead
        scenario_fingerprint = "a" * 64
        authorized_new_diagnostic_count = [int]$Binding.authorized_increment
        diagnostic_count_before = [int]$Binding.transition_from
        diagnostic_count_after = [int]$Binding.transition_to
        diagnostic_count_maximum = [int]$Binding.maximum_invocation_count
        previous_ledger_sha256 = "b" * 64
        historical_invocation_commit = "c" * 40
        historical_invocation_blob_sha1 = "d" * 40
        historical_invocation_file_sha256 = "e" * 64
        bootstrap_admission_path = [IO.Path]::GetFullPath([string]$Context.admission_path)
        bootstrap_admission_sha256 = [string]$Context.admission_sha256
        bootstrap_admission_fingerprint = [string]$Context.admission_fingerprint
        prequota_attestation_path = [IO.Path]::GetFullPath([string]$Context.attestation_path)
        role_timeout_policy_sha256 = "f" * 64
        official_attempt_1_claim_sha256 = [string]$official.attempt_1_claim_sha256
        official_attempt_2_claim_absent = $true
        official = $false
        formal = $false
        official_authorization_consumed = $false
        orchestrator_script_sha256 = "1" * 64
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = [DateTime]::UtcNow.Ticks.ToString(
            [Globalization.CultureInfo]::InvariantCulture
        )
        claim_nonce = $claimNonce
        launch_nonce = $launchNonce
        status = "consumed"
    }
}

try {
    [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    Import-Module $authorizationModulePath -Force
    Import-Module $preQuotaModulePath -Force

    $contract = Get-ColdRestoreAuthorizationContract
    $targeted = $contract.targeted_owner_capture_diagnostic_v3
    $head = "a" * 40
    $binding = Get-ColdRestoreTargetedDiagnosticAuthorizationBinding $tempRoot $head
    Assert-AuthorizationCondition (
        [string]$binding.authorization_id -ceq [string]$targeted.authorization_id -and
        [string]$binding.run_id -ceq "$([string]$targeted.run_id_prefix)-$($head.Substring(0, 12))" -and
        [int]$binding.transition_from -eq 2 -and [int]$binding.transition_to -eq 3
    ) "production contract resolves the exact V3 ID, run ID, and 2-to-3 transition"
    Assert-AuthorizationCondition (
        [IO.Path]::GetFullPath([string]$binding.quota_ledger_path) -ceq
            [IO.Path]::GetFullPath((Join-Path $tempRoot ([string]$targeted.quota_ledger_relative_path))) -and
        [IO.Path]::GetFullPath([string]$binding.evidence_root) -ceq
            [IO.Path]::GetFullPath((Join-Path $tempRoot ([string]$targeted.evidence_root_relative_path)))
    ) "production binding uses the exact contract ledger and evidence paths"

    $context = New-ColdRestoreTargetedDiagnosticPreQuotaContext `
        -GitCommonDirectory $tempRoot `
        -RepositoryHead $head `
        -Branch "codex/authorization integration"
    Assert-AuthorizationCondition (
        [IO.File]::Exists([string]$context.admission_path) -and
        [IO.File]::Exists([string]$context.attestation_path) -and
        [string]$context.authorization_binding.authorization_id -ceq [string]$targeted.authorization_id
    ) "real production binding passes the real PreQuota Bootstrap"

    $launchPath = Join-Path $binding.evidence_root "launch/orchestrator-1/producer.authorized.json"
    $arguments = New-ColdRestoreTargetedDiagnosticUserArgumentList `
        -GitCommonDirectory $tempRoot `
        -RepositoryHead $head `
        -RunId $binding.run_id `
        -ArtifactRoot "user://test_runs/alpha04c/$($binding.run_id)/evidence" `
        -ScenarioFingerprint ("2" * 64) `
        -TimeoutPolicyFingerprint ("3" * 64) `
        -QuotaLedgerPath $binding.quota_ledger_path `
        -QuotaLedgerFingerprint ("4" * 64) `
        -LaunchAttestationPath $launchPath `
        -LaunchNonce ("5" * 32)
    Assert-AuthorizationCondition (
        @($arguments | Where-Object { $_ -ceq "--cold-restore-run-id=$($binding.run_id)" }).Count -eq 1 -and
        @($arguments | Where-Object { $_ -ceq "--cold-restore-targeted-diagnostic-ledger-path=$($binding.quota_ledger_path)" }).Count -eq 1
    ) "real command fixture uses the same run ID and ledger path as Bootstrap"

    $variants = @(
        ([string]$targeted.authorization_id).Replace("-", "_"),
        ([string]$targeted.authorization_id).Replace("v3", "v2"),
        ([string]$targeted.authorization_id).Replace("v3", "v4"),
        "x$([string]$targeted.authorization_id)",
        "$([string]$targeted.authorization_id)-x",
        ([string]$targeted.authorization_id).ToUpperInvariant()
    )
    foreach ($variant in $variants) {
        $reason = Get-AuthorizationThrownReason {
            New-ColdRestorePreQuotaContext `
                -GitCommonDirectory $tempRoot `
                -BootstrapRoot $binding.bootstrap_root `
                -RunId $binding.run_id `
                -RepositoryHead $head `
                -Branch "codex/negative" `
                -AuthorizationId $variant `
                -QuotaLedgerPath $binding.quota_ledger_path
        }
        Assert-AuthorizationCondition ($reason -ceq "authorization_id_invalid") "unauthorized ID variant is rejected exactly: $variant"
    }

    $wrongPathReason = Get-AuthorizationThrownReason {
        New-ColdRestorePreQuotaContext `
            -GitCommonDirectory $tempRoot `
            -BootstrapRoot $binding.bootstrap_root `
            -RunId $binding.run_id `
            -RepositoryHead $head `
            -Branch "codex/wrong-path" `
            -AuthorizationId $binding.authorization_id `
            -QuotaLedgerPath (Join-Path $tempRoot "wrong/targeted_owner_capture_quota_ledger.json")
    }
    Assert-AuthorizationCondition ($wrongPathReason -ceq "quota_ledger_path_invalid") "wrong ledger path is rejected before claim"

    $ledger = New-AuthorizationQuotaLedger $binding $context $head
    $invalidTransition = $ledger.PSObject.Copy()
    $invalidTransition.diagnostic_count_after = 4
    $invalidTransitionPath = Join-Path $tempRoot "invalid-transition.json"
    $transitionReason = Get-AuthorizationThrownReason {
        Publish-ColdRestoreTargetedQuotaLedgerV3 $invalidTransitionPath $invalidTransition
    }
    Assert-AuthorizationCondition (
        $transitionReason -ceq "quota_transition_invalid" -and
        -not [IO.File]::Exists($invalidTransitionPath)
    ) "wrong transition is rejected without writing a ledger"

    $quotaSha = Publish-ColdRestoreTargetedQuotaLedgerV3 $binding.quota_ledger_path $ledger
    Assert-AuthorizationCondition (
        $quotaSha -cmatch '^[0-9a-f]{64}$' -and [IO.File]::Exists($binding.quota_ledger_path)
    ) "temporary production-path quota closes exactly from two to three"
    $quotaBeforeDuplicate = (Get-FileHash -LiteralPath $binding.quota_ledger_path -Algorithm SHA256).Hash.ToLowerInvariant()
    $duplicateReason = Get-AuthorizationThrownReason {
        Publish-ColdRestoreTargetedQuotaLedgerV3 $binding.quota_ledger_path $ledger
    }
    Assert-AuthorizationCondition (
        $duplicateReason -ceq "quota_already_consumed" -and
        (Get-FileHash -LiteralPath $binding.quota_ledger_path -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $quotaBeforeDuplicate
    ) "duplicate claim is rejected without changing the consumed bytes"

    $raceRoot = Join-Path $tempRoot "concurrent claim"
    [IO.Directory]::CreateDirectory($raceRoot) | Out-Null
    $raceHead = "b" * 40
    $raceBinding = Get-ColdRestoreTargetedDiagnosticAuthorizationBinding $raceRoot $raceHead
    $raceContext = New-ColdRestoreTargetedDiagnosticPreQuotaContext $raceRoot $raceHead "codex/race"
    $raceLedger = New-AuthorizationQuotaLedger $raceBinding $raceContext $raceHead
    $raceLedgerPath = Join-Path $raceRoot "race-ledger-source.json"
    [IO.File]::WriteAllText(
        $raceLedgerPath,
        ($raceLedger | ConvertTo-Json -Depth 20 -Compress),
        [Text.UTF8Encoding]::new($false)
    )
    $startTicks = [DateTime]::UtcNow.AddMilliseconds(500).Ticks
    $jobs = foreach ($index in 1..2) {
        Start-Job -ScriptBlock {
            param($ModulePath, $LedgerSource, $TargetPath, $Ticks)
            Import-Module $ModulePath -Force
            $start = [DateTime]::new([int64]$Ticks, [DateTimeKind]::Utc)
            while ([DateTime]::UtcNow -lt $start) { Start-Sleep -Milliseconds 5 }
            $value = [IO.File]::ReadAllText($LedgerSource, [Text.UTF8Encoding]::new($false)) |
                ConvertFrom-Json -DateKind String
            try {
                $sha = Publish-ColdRestoreTargetedQuotaLedgerV3 $TargetPath $value
                [pscustomobject]@{ won = $true; reason = "ok"; sha256 = $sha }
            }
            catch {
                [pscustomobject]@{ won = $false; reason = [string]$_.Exception.Message; sha256 = "" }
            }
        } -ArgumentList $preQuotaModulePath, $raceLedgerPath, $raceBinding.quota_ledger_path, $startTicks
    }
    $raceResults = @($jobs | Wait-Job | Receive-Job)
    $jobs | Remove-Job -Force
    Assert-AuthorizationCondition (
        @($raceResults | Where-Object { [bool]$_.won }).Count -eq 1 -and
        @($raceResults | Where-Object { -not [bool]$_.won -and [string]$_.reason -ceq "quota_already_consumed" }).Count -eq 1
    ) "concurrent claim has exactly one winner and one consumed loser"

    $orchestratorSource = [IO.File]::ReadAllText($orchestratorPath)
    $tokens = $null
    $parseErrors = $null
    $orchestratorAst = [Management.Automation.Language.Parser]::ParseFile(
        $orchestratorPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    $guardFunctions = @($orchestratorAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            [string]$node.Name -ceq "Invoke-ColdRestoreTargetedOwnerCaptureGuarded"
    }, $true))
    $postClaimFunctions = @($orchestratorAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            [string]$node.Name -ceq "Assert-ColdRestoreTargetedDiagnosticPostClaimBoundary"
    }, $true))
    Assert-AuthorizationCondition (
        @($parseErrors).Count -eq 0 -and
        $orchestratorSource.Contains("New-ColdRestoreTargetedDiagnosticPreQuotaContext") -and
        $orchestratorSource.Contains("New-ColdRestoreTargetedDiagnosticUserArgumentList") -and
        $orchestratorSource.IndexOf("Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint", [StringComparison]::Ordinal) -lt
            $orchestratorSource.IndexOf("New-ColdRestoreTargetedDiagnosticPreQuotaContext", [StringComparison]::Ordinal)
    ) "Orchestrator uses the production Bootstrap and command builders"
    $guardSource = if ($guardFunctions.Count -eq 1) { [string]$guardFunctions[0].Extent.Text } else { "" }
    Assert-AuthorizationCondition (
        $guardFunctions.Count -eq 1 -and
        $guardSource.IndexOf("Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint", [StringComparison]::Ordinal) -ge 0 -and
        $guardSource.IndexOf("Get-ColdRestoreRuntimeFreezeObservation", [StringComparison]::Ordinal) -gt
            $guardSource.IndexOf("Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint", [StringComparison]::Ordinal) -and
        $guardSource.IndexOf("New-ColdRestoreTargetedDiagnosticPreQuotaContext", [StringComparison]::Ordinal) -gt
            $guardSource.IndexOf("Get-ColdRestoreRuntimeFreezeObservation", [StringComparison]::Ordinal)
    ) "remote checkpoint and clean runtime freeze precede all PreQuota side effects"
    $postClaimSource = if ($postClaimFunctions.Count -eq 1) {
        [string]$postClaimFunctions[0].Extent.Text
    }
    else {
        ""
    }
    Assert-AuthorizationCondition (
        $postClaimFunctions.Count -eq 1 -and
        $postClaimSource.Contains("Get-ColdRestoreRuntimeFreezeObservation") -and
        $postClaimSource.Contains("AuthorizationContractSha256") -and
        $postClaimSource.Contains("Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint")
    ) "post-claim boundary revalidates clean code, contract bytes, and the pushed HEAD"
    if ($guardFunctions.Count -eq 1) {
        . ([scriptblock]::Create($guardFunctions[0].Extent.Text))
    }
    $script:orchestratorBootstrapCalls = 0
    function Assert-ColdRestoreCondition {
        param([bool]$Condition, [string]$FailureCode)
        if (-not $Condition) { throw $FailureCode }
    }
    function Resolve-ColdRestoreGitCommonDirectory {
        param([string]$ResolvedProjectPath)
        return $tempRoot
    }
    function Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint {
        param([string]$ResolvedProjectPath, [string]$ExpectedHead)
        return [pscustomobject]@{ remote_head_matches_local = $true }
    }
    function Get-ColdRestoreRuntimeFreezeObservation {
        param([string]$ResolvedProjectPath, [string]$ExpectedHead)
        return [pscustomobject]@{ repository_head = $ExpectedHead; tree_clean = $true }
    }
    function Assert-ColdRestoreRuntimeFreezeGreen {
        param($Observation, [string]$FailureCode)
        return $true
    }
    function Assert-ColdRestoreTargetedOwnerCapturePostconditions {
        param([string]$ResolvedProjectPath)
    }
    function Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic {
        param(
            [string]$ResolvedProjectPath,
            [string]$HeadSha,
            $PreQuotaContext,
            $FailureState
        )
        $script:orchestratorBootstrapCalls += 1
        if (-not [IO.File]::Exists([string]$PreQuotaContext.admission_path) -or
            -not [IO.File]::Exists([string]$PreQuotaContext.attestation_path) -or
            [string]$PreQuotaContext.authorization_binding.authorization_id -cne
                [string]$targeted.authorization_id) {
            throw "orchestrator_bootstrap_fixture_invalid"
        }
        return [pscustomobject]@{ fixture = "orchestrator-bootstrap-green" }
    }
    $script:RunId = [string]$binding.run_id
    $script:AuthorizationContractPath = $contractPath
    $script:AuthorizationContractSha256 = (
        Get-FileHash -LiteralPath $contractPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $guardedResult = Invoke-ColdRestoreTargetedOwnerCaptureGuarded $projectRoot $head
    Assert-AuthorizationCondition (
        $script:orchestratorBootstrapCalls -eq 1 -and
        [string]$guardedResult.fixture -ceq "orchestrator-bootstrap-green" -and
        [IO.File]::Exists([string]$guardedResult.prequota.path) -and
        [string]$guardedResult.prequota.sha256 -cmatch '^[0-9a-f]{64}$'
    ) "real Orchestrator guarded admission passes its production binding through PreQuota Bootstrap"
    $sourceFiles = @(
        Get-ChildItem (Join-Path $projectRoot "scripts") -Recurse -File |
            Where-Object { $_.Extension -in @(".gd", ".ps1", ".psm1", ".json") }
        Get-ChildItem (Join-Path $projectRoot "tests") -Recurse -File |
            Where-Object { $_.Extension -in @(".gd", ".ps1", ".psm1", ".json") }
    )
    $singleSourceValues = @(
        [pscustomobject]@{ name = "targeted authorization ID"; value = [string]$targeted.authorization_id },
        [pscustomobject]@{ name = "targeted quota path"; value = [string]$targeted.quota_ledger_relative_path },
        [pscustomobject]@{ name = "targeted evidence path"; value = [string]$targeted.evidence_root_relative_path },
        [pscustomobject]@{ name = "targeted bootstrap path"; value = [string]$targeted.bootstrap_root_relative_path },
        [pscustomobject]@{ name = "rehearsal authorization ID"; value = [string]$contract.process_a_save_completion_rehearsal_v1.authorization_id },
        [pscustomobject]@{ name = "rehearsal quota path"; value = [string]$contract.process_a_save_completion_rehearsal_v1.quota_ledger_relative_path },
        [pscustomobject]@{ name = "rehearsal launch path"; value = [string]$contract.process_a_save_completion_rehearsal_v1.launch_ledger_relative_path },
        [pscustomobject]@{ name = "rehearsal outcome path"; value = [string]$contract.process_a_save_completion_rehearsal_v1.outcome_ledger_relative_path },
        [pscustomobject]@{ name = "official authorization ID"; value = [string]$contract.official_attempt_2.authorization_id },
        [pscustomobject]@{ name = "official claim path"; value = [string]$contract.official_attempt_2.claim_path }
    )
    foreach ($singleSource in $singleSourceValues) {
        $sourceCount = 0
        foreach ($file in $sourceFiles) {
            $text = [IO.File]::ReadAllText($file.FullName)
            $sourceCount += ([regex]::Matches(
                $text, [regex]::Escape([string]$singleSource.value)
            )).Count
        }
        Assert-AuthorizationCondition ($sourceCount -eq 1) "$($singleSource.name) has one source"
    }
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}
finally {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved).StartsWith("alpha04c V3 authorization 集成 ", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_AUTHORIZATION_CONTRACT_INTEGRATION|status=$status|checks=$script:checks|failures=$($script:failures.Count)|godot_launched=false|official_claim_created=false"
foreach ($failure in $script:failures) { Write-Output "FAIL|$failure" }
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
