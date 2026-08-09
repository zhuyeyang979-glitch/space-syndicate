param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'create-global-matrix-authority',
        'capture-preimport-baseline',
        'capture-uid-allowlist',
        'create-local-uid-attestation',
        'verify-worktree',
        'plan-shards'
    )]
    [string]$Operation,
    [string]$Worktree = "",
    [string]$ExpectedHeadSha = "",
    [string]$ExpectedTreeSha = "",
    [string]$PreimportBaselinePath = "",
    [string]$UidAllowlistPath = "",
    [string]$GlobalMatrixAuthorityPath = "",
    [string]$ExpectedGlobalMatrixAuthoritySha256 = "",
    [string]$LocalUidAttestationPath = "",
    [string]$ExpectedLocalUidAttestationSha256 = "",
    [string]$HarnessFingerprint = "",
    [int]$MatchesPerConfiguration = 0,
    [int]$StepLimit = 512,
    [ValidateRange(1, 5)]
    [int]$WorkerCount = 5,
    [string]$OutputPath = ""
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'v075_formal_authority.psm1'
Import-Module $modulePath -Force

function Assert-Argument {
    param([string]$Name, [string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name is required for operation '$Operation'."
    }
}

try {
    $result = switch ($Operation) {
        'create-global-matrix-authority' {
            Assert-Argument 'ExpectedHeadSha' $ExpectedHeadSha
            Assert-Argument 'ExpectedTreeSha' $ExpectedTreeSha
            Assert-Argument 'HarnessFingerprint' $HarnessFingerprint
            Assert-Argument 'OutputPath' $OutputPath
            if ($MatchesPerConfiguration -lt 10) {
                throw 'MatchesPerConfiguration must be at least 10.'
            }
            New-V075GlobalMatrixAuthority `
                -FinalHeadSha $ExpectedHeadSha `
                -FinalTreeSha $ExpectedTreeSha `
                -HarnessFingerprint $HarnessFingerprint `
                -MatchesPerConfiguration $MatchesPerConfiguration `
                -StepLimit $StepLimit
        }
        'capture-preimport-baseline' {
            Assert-Argument 'Worktree' $Worktree
            Assert-Argument 'ExpectedHeadSha' $ExpectedHeadSha
            Assert-Argument 'ExpectedTreeSha' $ExpectedTreeSha
            Assert-Argument 'OutputPath' $OutputPath
            New-V075FormalPreimportBaseline `
                -Worktree $Worktree `
                -ExpectedHeadSha $ExpectedHeadSha `
                -ExpectedTreeSha $ExpectedTreeSha
        }
        'capture-uid-allowlist' {
            Assert-Argument 'Worktree' $Worktree
            Assert-Argument 'PreimportBaselinePath' $PreimportBaselinePath
            Assert-Argument 'OutputPath' $OutputPath
            $baseline = Read-V075JsonFile -Path $PreimportBaselinePath
            $baselineSha = (Get-FileHash -LiteralPath $PreimportBaselinePath -Algorithm SHA256).Hash.ToLowerInvariant()
            New-V075UidAllowlist `
                -Worktree $Worktree `
                -PreimportBaseline $baseline `
                -PreimportBaselineSha256 $baselineSha
        }
        'create-local-uid-attestation' {
            Assert-Argument 'Worktree' $Worktree
            Assert-Argument 'PreimportBaselinePath' $PreimportBaselinePath
            Assert-Argument 'UidAllowlistPath' $UidAllowlistPath
            Assert-Argument 'GlobalMatrixAuthorityPath' $GlobalMatrixAuthorityPath
            Assert-Argument 'ExpectedGlobalMatrixAuthoritySha256' `
                $ExpectedGlobalMatrixAuthoritySha256
            Assert-Argument 'OutputPath' $OutputPath
            New-V075LocalUidAttestation `
                -Worktree $Worktree `
                -PreimportBaselinePath $PreimportBaselinePath `
                -UidAllowlistPath $UidAllowlistPath `
                -GlobalMatrixAuthorityPath $GlobalMatrixAuthorityPath `
                -ExpectedGlobalMatrixAuthoritySha256 `
                $ExpectedGlobalMatrixAuthoritySha256
        }
        'verify-worktree' {
            Assert-Argument 'Worktree' $Worktree
            Assert-Argument 'PreimportBaselinePath' $PreimportBaselinePath
            Assert-Argument 'UidAllowlistPath' $UidAllowlistPath
            Assert-Argument 'GlobalMatrixAuthorityPath' $GlobalMatrixAuthorityPath
            Assert-Argument 'ExpectedGlobalMatrixAuthoritySha256' `
                $ExpectedGlobalMatrixAuthoritySha256
            Assert-Argument 'LocalUidAttestationPath' $LocalUidAttestationPath
            Assert-Argument 'ExpectedLocalUidAttestationSha256' `
                $ExpectedLocalUidAttestationSha256
            Test-V075FormalWorktreeIdentity `
                -Worktree $Worktree `
                -PreimportBaselinePath $PreimportBaselinePath `
                -UidAllowlistPath $UidAllowlistPath `
                -GlobalMatrixAuthorityPath $GlobalMatrixAuthorityPath `
                -ExpectedGlobalMatrixAuthoritySha256 `
                $ExpectedGlobalMatrixAuthoritySha256 `
                -LocalUidAttestationPath $LocalUidAttestationPath `
                -ExpectedLocalUidAttestationSha256 `
                $ExpectedLocalUidAttestationSha256
        }
        'plan-shards' {
            Assert-Argument 'GlobalMatrixAuthorityPath' $GlobalMatrixAuthorityPath
            Assert-Argument 'ExpectedGlobalMatrixAuthoritySha256' `
                $ExpectedGlobalMatrixAuthoritySha256
            Assert-Argument 'OutputPath' $OutputPath
            $globalValidation = Test-V075GlobalMatrixAuthorityFile `
                -Path $GlobalMatrixAuthorityPath `
                -ExpectedSha256 $ExpectedGlobalMatrixAuthoritySha256
            if (-not [bool]$globalValidation.valid) {
                throw 'Global matrix authority failed deterministic/hash validation.'
            }
            New-V075FormalShardPlan `
                -GlobalMatrixAuthority $globalValidation.authority `
                -GlobalMatrixAuthoritySha256 $globalValidation.actual_sha256 `
                -WorkerCount $WorkerCount
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $outputSha = Write-V075AtomicJson -Path $OutputPath -Value $result
        [ordered]@{
            operation = $Operation
            status = if ($Operation -eq 'verify-worktree' -and -not [bool]$result.green) { 'BLOCKED' } else { 'PASS' }
            output_path = [IO.Path]::GetFullPath($OutputPath)
            output_sha256 = $outputSha
            result = $result
        } | ConvertTo-Json -Depth 40 -Compress | Write-Output
    } else {
        $result | ConvertTo-Json -Depth 40 -Compress | Write-Output
    }
    if ($Operation -eq 'verify-worktree' -and -not [bool]$result.green) { exit 1 }
    exit 0
} catch {
    [ordered]@{
        operation = $Operation
        status = 'BLOCKED'
        error = [string]$_.Exception.Message
    } | ConvertTo-Json -Compress | Write-Output
    exit 2
}
