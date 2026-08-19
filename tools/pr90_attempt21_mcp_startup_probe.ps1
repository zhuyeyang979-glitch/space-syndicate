[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('PRE_FORMAL_STARTUP_PROBE','PRE_FORMAL_EXACT_MCP_DRY_RUN')][string]$ExecutionMode,
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$ProbeIdentity,
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ExpectedHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedTreeSha,
    [Parameter(Mandatory = $true)][string]$LaunchScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedLaunchScriptSha256,
    [Parameter(Mandatory = $true)][string]$StopScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedStopScriptSha256,
    [Parameter(Mandatory = $true)][string]$WatchdogScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedWatchdogScriptSha256,
    [Parameter(Mandatory = $true)][string]$StateMachineScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedStateMachineSha256,
    [Parameter(Mandatory = $true)][string]$ContractScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedContractSha256,
    [string]$ProbeScenePath = 'res://scenes/runtime/ActionResultPresentationService.tscn',
    [string]$SealedBaselinePath = '',
    [string]$ExpectedSealedBaselineSha256 = '',
    [string]$StartupToolingManifestPath = '',
    [string]$ExpectedStartupToolingManifestSha256 = '',
    [string]$StartupToolingSealPath = '',
    [string]$ExpectedStartupToolingSealSha256 = '',
    [ValidateRange(1,65535)][int]$Port = 7576
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$statePath = (Resolve-Path -LiteralPath $StateMachineScriptPath).Path
Import-Module $statePath -Force

if ((Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash.ToLowerInvariant() -eq '') {
    throw 'Probe script hash calculation unexpectedly returned empty.'
}

$state = Invoke-Pr90McpStartupStateMachine `
    -ExecutionMode $ExecutionMode `
    -RunId $RunId `
    -ProbeIdentity $ProbeIdentity `
    -Worktree $Worktree `
    -EvidenceRoot $EvidenceRoot `
    -GodotPath $GodotPath `
    -ExpectedHeadSha $ExpectedHeadSha `
    -ExpectedTreeSha $ExpectedTreeSha `
    -LaunchScriptPath $LaunchScriptPath `
    -ExpectedLaunchScriptSha256 $ExpectedLaunchScriptSha256 `
    -StopScriptPath $StopScriptPath `
    -ExpectedStopScriptSha256 $ExpectedStopScriptSha256 `
    -WatchdogScriptPath $WatchdogScriptPath `
    -ExpectedWatchdogScriptSha256 $ExpectedWatchdogScriptSha256 `
    -ExpectedStateMachineSha256 $ExpectedStateMachineSha256 `
    -ExpectedContractSha256 $ExpectedContractSha256 `
    -ProbeScenePath $ProbeScenePath `
    -SealedBaselinePath $SealedBaselinePath `
    -ExpectedSealedBaselineSha256 $ExpectedSealedBaselineSha256 `
    -StartupToolingManifestPath $StartupToolingManifestPath `
    -ExpectedStartupToolingManifestSha256 $ExpectedStartupToolingManifestSha256 `
    -StartupToolingSealPath $StartupToolingSealPath `
    -ExpectedStartupToolingSealSha256 $ExpectedStartupToolingSealSha256 `
    -Port $Port

$state.summary | ConvertTo-Json -Depth 100 -Compress
if ([string]$state.summary.status -cne 'PASS') { exit 2 }
