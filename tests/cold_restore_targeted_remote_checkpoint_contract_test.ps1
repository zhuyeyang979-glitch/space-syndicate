[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$attestedModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_attested_process.psm1"
$authorizationModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_authorization_contract_v1.psm1"
$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "alpha04c-targeted-remote-checkpoint-" + [Guid]::NewGuid().ToString("N")
)
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()

function Assert-CheckpointTestCondition {
    param([bool]$Condition, [string]$Message)

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Assert-ColdRestoreCondition {
    param([bool]$Condition, [string]$FailureCode)

    if (-not $Condition) {
        throw $FailureCode
    }
}

function Get-ColdRestoreSafeCollectionCount {
    param([AllowNull()]$Value)

    return @($Value).Count
}

function Get-CheckpointThrownReason {
    param([scriptblock]$Action)

    try {
        & $Action | Out-Null
    }
    catch {
        return [string]$_.Exception.Message
    }
    return ""
}

try {
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null
    Import-Module $attestedModulePath -ErrorAction Stop
    Import-Module $authorizationModulePath -ErrorAction Stop
    $currentAuthorizationName = Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName
    $currentAuthorization = Get-ColdRestoreAuthorizationEntry $currentAuthorizationName
    $checkpointBranchPrefix = "codex/alpha04c-v$([int]$currentAuthorization.permitted_transition_to)-owner-diagnostic-"
    $TargetedOwnerCaptureCheckpointBranchPattern = '^' + `
        [regex]::Escape($checkpointBranchPrefix) + '[0-9a-f]{7,12}$'
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
        $orchestratorPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    Assert-CheckpointTestCondition (@($parseErrors).Count -eq 0) "orchestrator parses"
    $functions = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            [string]$node.Name -ceq "Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint"
    }, $true))
    Assert-CheckpointTestCondition ($functions.Count -eq 1) "remote checkpoint function exists exactly once"
    if ($functions.Count -eq 1) {
        . ([scriptblock]::Create($functions[0].Extent.Text))
    }

    $remotePath = Join-Path $testRoot "origin.git"
    $repoPath = Join-Path $testRoot "working tree"
    & git init --bare $remotePath | Out-Null
    & git init $repoPath | Out-Null
    & git -C $repoPath config user.name "Cold Restore Contract"
    & git -C $repoPath config user.email "cold-restore-contract@example.invalid"
    $branch = "${checkpointBranchPrefix}abcdef1"
    & git -C $repoPath checkout -b $branch | Out-Null
    [IO.File]::WriteAllText(
        (Join-Path $repoPath "checkpoint.txt"),
        "pushed`n",
        [Text.UTF8Encoding]::new($false)
    )
    & git -C $repoPath add checkpoint.txt
    & git -C $repoPath commit -m "test: create pushed checkpoint" | Out-Null
    & git -C $repoPath remote add origin $remotePath
    & git -C $repoPath push -u origin $branch | Out-Null
    $pushedHead = ([string](& git -C $repoPath rev-parse HEAD)).Trim()
    $accepted = Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint $repoPath $pushedHead
    Assert-CheckpointTestCondition (
        [bool]$accepted.remote_head_matches_local -and
        [string]$accepted.local_head -ceq $pushedHead -and
        [string]$accepted.remote_head -ceq $pushedHead
    ) "pushed task branch at the exact HEAD is accepted"

    [IO.File]::WriteAllText(
        (Join-Path $repoPath "checkpoint.txt"),
        "local ahead`n",
        [Text.UTF8Encoding]::new($false)
    )
    & git -C $repoPath add checkpoint.txt
    & git -C $repoPath commit -m "test: create unpushed checkpoint" | Out-Null
    $localHead = ([string](& git -C $repoPath rev-parse HEAD)).Trim()
    $unpushedReason = Get-CheckpointThrownReason {
        Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint $repoPath $localHead
    }
    Assert-CheckpointTestCondition (
        $unpushedReason -ceq "targeted_diagnostic_remote_checkpoint_mismatch"
    ) "an unpushed local HEAD is rejected before quota claim"

    $staleExpectedReason = Get-CheckpointThrownReason {
        Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint $repoPath $pushedHead
    }
    Assert-CheckpointTestCondition (
        $staleExpectedReason -ceq "targeted_diagnostic_local_checkpoint_invalid"
    ) "a stale expected HEAD is rejected before the remote lookup"

    & git -C $repoPath checkout -b "feature/not-authorized" | Out-Null
    $wrongBranchReason = Get-CheckpointThrownReason {
        Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint $repoPath $localHead
    }
    Assert-CheckpointTestCondition (
        $wrongBranchReason -ceq "targeted_diagnostic_local_checkpoint_invalid"
    ) "a non-task branch is rejected before quota claim"
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved).StartsWith(
            "alpha04c-targeted-remote-checkpoint-",
            [StringComparison]::Ordinal
        )) {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_TARGETED_REMOTE_CHECKPOINT_CONTRACT|status=$status|checks=$script:checks|failures=$($script:failures.Count)|godot_launched=false|quota_claimed=false"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) {
    exit 1
}
exit 0
