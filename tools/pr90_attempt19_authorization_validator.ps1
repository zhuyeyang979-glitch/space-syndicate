[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$ManifestShaPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProductHead,
    [Parameter(Mandatory = $true)][string]$ExpectedProductTree,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingHead,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingTree
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$result = Get-AuthorizationValidation `
    -ManifestPath $ManifestPath `
    -ManifestShaPath $ManifestShaPath `
    -ExpectedProductHead $ExpectedProductHead `
    -ExpectedProductTree $ExpectedProductTree `
    -ExpectedToolingHead $ExpectedToolingHead `
    -ExpectedToolingTree $ExpectedToolingTree
$result | ConvertTo-Json -Depth 100 -Compress
if ([string]$result.status -cne 'PASS') { exit 2 }
