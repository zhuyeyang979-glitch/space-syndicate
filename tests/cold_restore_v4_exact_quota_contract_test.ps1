[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$toolsRoot = Join-Path $projectRoot "scripts/tools"
$loaderPath = Join-Path $toolsRoot "cold_restore_module_loader.psm1"
$authorizationPath = Join-Path $toolsRoot "cold_restore_authorization_contract_v1.psm1"
$prequotaPath = Join-Path $toolsRoot "cold_restore_prequota_bootstrap.psm1"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "alpha04c V4 quota 中文 空格 " + [Guid]::NewGuid().ToString("N")
)
$raceChildPath = Join-Path $tempRoot "concurrent claim child.ps1"
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()

function Assert-V4QuotaCondition {
    param([bool]$Condition, [string]$Message)

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Get-V4QuotaThrownReason {
    param([Parameter(Mandatory = $true)][scriptblock]$Action)

    try {
        & $Action | Out-Null
    }
    catch {
        return [string]$_.Exception.Message
    }
    return ""
}

function New-V4QuotaLedger {
    param(
        [Parameter(Mandatory = $true)]$Authorization,
        [Parameter(Mandatory = $true)]$Binding,
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$RepositoryHead
    )

    $official = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
        "official_attempt_2"
    $claimNonce = [Guid]::NewGuid().ToString("N")
    do {
        $launchNonce = [Guid]::NewGuid().ToString("N")
    } while ($launchNonce -ceq $claimNonce)
    return [pscustomobject][ordered]@{
        schema_version = 4
        ledger_id = [string]$Authorization.ledger_id
        authorization_id = [string]$Authorization.authorization_id
        task_id = [string]$Authorization.task_id
        created_at_utc = [DateTime]::UtcNow.ToString(
            "O", [Globalization.CultureInfo]::InvariantCulture
        )
        run_id = [string]$Binding.run_id
        repository_head = $RepositoryHead
        scenario_fingerprint = "1" * 64
        authorized_new_diagnostic_count = [int]$Authorization.authorized_increment
        diagnostic_count_before = [int]$Authorization.permitted_transition_from
        diagnostic_count_after = [int]$Authorization.permitted_transition_to
        diagnostic_count_maximum = [int]$Authorization.maximum_invocation_count
        previous_ledger_sha256 = "2" * 64
        historical_invocation_commit = "3" * 40
        historical_invocation_blob_sha1 = "4" * 40
        historical_invocation_file_sha256 = "5" * 64
        bootstrap_admission_path = [IO.Path]::GetFullPath([string]$Context.admission_path)
        bootstrap_admission_sha256 = [string]$Context.admission_sha256
        bootstrap_admission_fingerprint = [string]$Context.admission_fingerprint
        prequota_attestation_path = [IO.Path]::GetFullPath([string]$Context.attestation_path)
        role_timeout_policy_sha256 = "6" * 64
        official_attempt_1_claim_sha256 = [string]$official.attempt_1_claim_sha256
        official_attempt_2_claim_absent = $true
        official = $false
        formal = $false
        official_authorization_consumed = $false
        orchestrator_script_sha256 = "7" * 64
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = (
            [Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks
        ).ToString([Globalization.CultureInfo]::InvariantCulture)
        claim_nonce = $claimNonce
        launch_nonce = $launchNonce
        status = "consumed"
    }
}

$raceChildSource = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LoaderPath,
    [Parameter(Mandatory = $true)][string]$PreQuotaPath,
    [Parameter(Mandatory = $true)][string]$LedgerSourcePath,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][int64]$StartUtcTicks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    Import-Module -Name $LoaderPath -Global -ErrorAction Stop
    $null = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
        -Path $PreQuotaPath `
        -RequiredCommands @("Publish-ColdRestoreTargetedQuotaLedgerV4")
    $start = [DateTime]::new($StartUtcTicks, [DateTimeKind]::Utc)
    while ([DateTime]::UtcNow -lt $start) {
        Start-Sleep -Milliseconds 2
    }
    $ledger = [IO.File]::ReadAllText(
        $LedgerSourcePath,
        [Text.UTF8Encoding]::new($false)
    ) | ConvertFrom-Json -DateKind String
    $sha = cold_restore_prequota_bootstrap\Publish-ColdRestoreTargetedQuotaLedgerV4 `
        $TargetPath $ledger
    [Console]::Out.WriteLine(([pscustomobject]@{
        success = $true
        reason = "ok"
        sha256 = [string]$sha
    } | ConvertTo-Json -Compress))
    exit 0
}
catch {
    [Console]::Out.WriteLine(([pscustomobject]@{
        success = $false
        reason = [string]$_.Exception.Message
        sha256 = ""
    } | ConvertTo-Json -Compress))
    exit 1
}
'@

try {
    [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    Assert-V4QuotaCondition (
        $tempRoot -cmatch '\s' -and $tempRoot -cmatch '[^\u0000-\u007f]'
    ) "temporary quota root contains spaces and non-ASCII characters"

    Import-Module -Name $loaderPath -Global -ErrorAction Stop
    $null = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
        -Path $authorizationPath `
        -RequiredCommands @(
            "Get-ColdRestoreAuthorizationContract",
            "Get-ColdRestoreAuthorizationEntry",
            "Get-ColdRestoreTargetedDiagnosticAuthorizationBinding"
        )
    $null = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
        -Path $prequotaPath `
        -RequiredCommands @(
            "Assert-ColdRestorePreQuotaContextParameters",
            "Assert-ColdRestoreTargetedQuotaLedgerV4",
            "New-ColdRestoreTargetedDiagnosticPreQuotaContext",
            "Publish-ColdRestoreTargetedQuotaLedgerV4"
        )

    $authorizationName = "targeted_owner_capture_diagnostic_v4_importchain"
    $contract = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationContract
    $authorization = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
        $authorizationName
    $repositoryHead = "a" * 40
    $binding = cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationBinding `
        -GitCommonDirectory $tempRoot `
        -RepositoryHead $repositoryHead `
        -AuthorizationName $authorizationName
    Assert-V4QuotaCondition (
        [string]$authorization.authorization_id -ceq
            "alpha04c-targeted-owner-capture-diagnostic-v4-importchain" -and
        [int]$authorization.permitted_transition_from -eq 3 -and
        [int]$authorization.permitted_transition_to -eq 4 -and
        [int]$authorization.maximum_invocation_count -eq 4 -and
        [string]$binding.authorization_name -ceq $authorizationName
    ) "production authorization is exactly V4 with the 3-to-4 transition"

    $context = cold_restore_prequota_bootstrap\New-ColdRestoreTargetedDiagnosticPreQuotaContext `
        -GitCommonDirectory $tempRoot `
        -RepositoryHead $repositoryHead `
        -Branch "codex/V4 quota 中文" `
        -AuthorizationName $authorizationName
    $ledger = New-V4QuotaLedger $authorization $binding $context $repositoryHead
    $validReason = Get-V4QuotaThrownReason {
        cold_restore_prequota_bootstrap\Assert-ColdRestoreTargetedQuotaLedgerV4 $ledger
    }
    Assert-V4QuotaCondition ($validReason -ceq "") "correct V4 authorization ID is accepted"

    $invalidIds = [ordered]@{
        v3 = [string]$contract.targeted_owner_capture_diagnostic_v3.authorization_id
        v5 = ([string]$authorization.authorization_id).Replace("v4", "v5")
        underscore = ([string]$authorization.authorization_id).Replace("-", "_")
        case = ([string]$authorization.authorization_id).ToUpperInvariant()
    }
    foreach ($caseName in $invalidIds.Keys) {
        $candidate = $ledger.PSObject.Copy()
        $candidate.authorization_id = [string]$invalidIds[$caseName]
        $reason = Get-V4QuotaThrownReason {
            cold_restore_prequota_bootstrap\Assert-ColdRestoreTargetedQuotaLedgerV4 `
                $candidate
        }
        Assert-V4QuotaCondition (
            $reason -ceq "authorization_id_invalid"
        ) "$caseName authorization ID variant is rejected exactly"
    }

    $wrongPath = Join-Path $tempRoot "wrong ledger/targeted_owner_capture_quota_ledger.json"
    $wrongPathReason = Get-V4QuotaThrownReason {
        cold_restore_prequota_bootstrap\Assert-ColdRestorePreQuotaContextParameters `
            -GitCommonDirectory $tempRoot `
            -BootstrapRoot ([string]$binding.bootstrap_root) `
            -RunId ([string]$binding.run_id) `
            -RepositoryHead $repositoryHead `
            -Branch "codex/wrong-ledger" `
            -AuthorizationId ([string]$authorization.authorization_id) `
            -QuotaLedgerPath $wrongPath
    }
    Assert-V4QuotaCondition (
        $wrongPathReason -ceq "quota_ledger_path_invalid" -and
        -not [IO.File]::Exists($wrongPath)
    ) "wrong ledger path is rejected without a write"

    $invalidTransition = $ledger.PSObject.Copy()
    $invalidTransition.diagnostic_count_after = 5
    $transitionReason = Get-V4QuotaThrownReason {
        cold_restore_prequota_bootstrap\Assert-ColdRestoreTargetedQuotaLedgerV4 `
            $invalidTransition
    }
    Assert-V4QuotaCondition (
        $transitionReason -ceq "quota_transition_invalid"
    ) "3-to-5 transition is rejected"

    $ledgerSha = cold_restore_prequota_bootstrap\Publish-ColdRestoreTargetedQuotaLedgerV4 `
        ([string]$binding.quota_ledger_path) $ledger
    Assert-V4QuotaCondition (
        $ledgerSha -cmatch '^[0-9a-f]{64}$' -and
        [IO.File]::Exists([string]$binding.quota_ledger_path)
    ) "valid V4 ledger is exclusively published in the temporary root"
    $bytesBeforeDuplicate = [IO.File]::ReadAllBytes([string]$binding.quota_ledger_path)
    $duplicateReason = Get-V4QuotaThrownReason {
        cold_restore_prequota_bootstrap\Publish-ColdRestoreTargetedQuotaLedgerV4 `
            ([string]$binding.quota_ledger_path) $ledger
    }
    $bytesAfterDuplicate = [IO.File]::ReadAllBytes([string]$binding.quota_ledger_path)
    Assert-V4QuotaCondition (
        $duplicateReason -ceq "quota_already_consumed" -and
        [Convert]::ToBase64String($bytesBeforeDuplicate) -ceq
            [Convert]::ToBase64String($bytesAfterDuplicate)
    ) "duplicate claim is rejected without changing consumed bytes"

    $raceRoot = Join-Path $tempRoot "parallel claim 竞争"
    [IO.Directory]::CreateDirectory($raceRoot) | Out-Null
    $raceHead = "b" * 40
    $raceBinding = cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationBinding `
        -GitCommonDirectory $raceRoot `
        -RepositoryHead $raceHead `
        -AuthorizationName $authorizationName
    $raceContext = cold_restore_prequota_bootstrap\New-ColdRestoreTargetedDiagnosticPreQuotaContext `
        -GitCommonDirectory $raceRoot `
        -RepositoryHead $raceHead `
        -Branch "codex/V4 race" `
        -AuthorizationName $authorizationName
    $raceLedger = New-V4QuotaLedger $authorization $raceBinding $raceContext $raceHead
    $raceLedgerSource = Join-Path $raceRoot "ledger source.json"
    [IO.File]::WriteAllText(
        $raceLedgerSource,
        ($raceLedger | ConvertTo-Json -Depth 20 -Compress),
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $raceChildPath,
        $raceChildSource,
        [Text.UTF8Encoding]::new($false)
    )
    $startTicks = [DateTime]::UtcNow.AddMilliseconds(750).Ticks
    $processes = [Collections.Generic.List[Diagnostics.Process]]::new()
    foreach ($index in 1..2) {
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = (Get-Command pwsh -CommandType Application).Source
        $startInfo.WorkingDirectory = $projectRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in @(
                "-NoProfile", "-NonInteractive", "-File", $raceChildPath,
                "-LoaderPath", $loaderPath,
                "-PreQuotaPath", $prequotaPath,
                "-LedgerSourcePath", $raceLedgerSource,
                "-TargetPath", [string]$raceBinding.quota_ledger_path,
                "-StartUtcTicks", [string]$startTicks
            )) {
            $startInfo.ArgumentList.Add($argument)
        }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            throw "V4 concurrent claim child start failed: $index"
        }
        $processes.Add($process)
    }
    $raceResults = [Collections.Generic.List[object]]::new()
    foreach ($process in $processes) {
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) {
            $process.Kill($true)
            throw "V4 concurrent claim child timed out"
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult().Trim()
        $stderr = $stderrTask.GetAwaiter().GetResult().Trim()
        if ([string]::IsNullOrEmpty($stdout)) {
            throw "V4 concurrent claim child returned no result: $stderr"
        }
        $raceResults.Add(($stdout | ConvertFrom-Json -DateKind String))
    }
    Assert-V4QuotaCondition (
        @($raceResults | Where-Object { [bool]$_.success }).Count -eq 1 -and
        @($raceResults | Where-Object {
            -not [bool]$_.success -and [string]$_.reason -ceq "quota_already_consumed"
        }).Count -eq 1
    ) "concurrent V4 claim has exactly one winner and one consumed loser"
    Assert-V4QuotaCondition (
        [IO.File]::Exists([string]$raceBinding.quota_ledger_path) -and
        (Get-FileHash -LiteralPath ([string]$raceBinding.quota_ledger_path) `
            -Algorithm SHA256).Hash.ToLowerInvariant() -ceq
                [string]($raceResults | Where-Object { [bool]$_.success } |
                    Select-Object -First 1).sha256
    ) "concurrent winner fingerprint matches the single temporary ledger"
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}
finally {
    $resolvedRoot = [IO.Path]::GetFullPath($tempRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedRoot).StartsWith(
            "alpha04c V4 quota 中文 空格 ",
            [StringComparison]::Ordinal
        )) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_V4_EXACT_QUOTA_CONTRACT|status=$status|checks=$script:checks|failures=$($script:failures.Count)|temporary_root_only=true|official_quota_claimed=false|godot_launched=false"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
