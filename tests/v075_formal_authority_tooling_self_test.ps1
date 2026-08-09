$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\v075_formal_authority.psm1'
Import-Module $modulePath -Force

$checks = 0
$failures = [Collections.Generic.List[string]]::new()

function Check {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Write-TestUtf8 {
    param([string]$Path, [string]$Content)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Invoke-TestGit {
    param([string]$Root, [string[]]$Arguments)
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 surfaces native stderr as an ErrorRecord. Git
        # warnings are non-fatal here; the process exit code remains authoritative.
        $ErrorActionPreference = 'Continue'
        $output = @(& git -C $Root @Arguments 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) { throw "git failed: $($output -join ' | ')" }
    return $output
}

function Assert-Plan {
    param([int]$Matches, [int]$ExpectedShardCount, [int[]]$ExpectedSizes)
    $authority = New-V075GlobalMatrixAuthority `
        -FinalHeadSha ('1' * 40) `
        -FinalTreeSha ('2' * 40) `
        -HarnessFingerprint ('4' * 64) `
        -MatchesPerConfiguration $Matches `
        -StepLimit 512
    $plan = New-V075FormalShardPlan `
        -GlobalMatrixAuthority $authority `
        -GlobalMatrixAuthoritySha256 ('3' * 64)
    Check ($plan.configuration_count -eq 5) "$Matches planner keeps five configurations"
    Check ($plan.shard_count -eq $ExpectedShardCount) "$Matches planner shard count"
    Check ($plan.total_match_count -eq 5 * $Matches) "$Matches planner total jobs"
    Check ($plan.unique_job_identity_count -eq $plan.total_match_count) "$Matches planner job identities unique"
    Check ($plan.unique_seed_count -eq $plan.total_match_count) "$Matches planner seeds unique"
    $sizes = @($plan.shards | ForEach-Object { [int]$_.expected_match_count } | Sort-Object -Unique)
    Check (($sizes -join ',') -eq (($ExpectedSizes | Sort-Object -Unique) -join ',')) "$Matches planner exact shard sizes"
    Check (@($plan.shards | Where-Object { $_.expected_match_count -lt 10 -or $_.expected_match_count -gt 20 }).Count -eq 0) "$Matches planner keeps 10-20 bound"
    Check (@($plan.shards | Where-Object { @($_.jobs.configuration_id | Sort-Object -Unique).Count -ne 1 }).Count -eq 0) "$Matches planner keeps one configuration per shard"
    $firstIdentity = $plan.shards[0].jobs[0].job_identity
    $identityNames = @($firstIdentity.PSObject.Properties.Name)
    Check (-not ($identityNames -contains 'worker_id')) "$Matches job identity excludes worker"
    Check (-not ($identityNames -contains 'launch_session_id')) "$Matches job identity excludes session"
    Check (-not ($identityNames -contains 'shard_id')) "$Matches job identity excludes shard"
    Check ($identityNames -contains 'authority_manifest_sha256') "$Matches job identity binds authority"
    Check ($plan.authority_manifest_scope -eq 'global_matrix') "$Matches authority hash is explicitly global"
    Check ($plan.canonical_job_plan_sha256 -eq $authority.canonical_job_plan_sha256) "$Matches planner matches global canonical job plan"
    Check (-not ($identityNames -contains 'local_uid_attestation_sha256')) "$Matches job identity excludes local UID attestation"
    return $plan
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$root = Join-Path $tempBase ("ss-v075-formal-authority-" + [guid]::NewGuid().ToString('N'))
$evidenceRoot = "$root-evidence"
$rootB = "$root-worker-b"
$evidenceRootB = "$rootB-evidence"
try {
    [IO.Directory]::CreateDirectory($root) | Out-Null
    [IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
    Invoke-TestGit -Root $root -Arguments @('init', '--quiet') | Out-Null
    Invoke-TestGit -Root $root -Arguments @('config', 'user.name', 'V075 Self Test') | Out-Null
    Invoke-TestGit -Root $root -Arguments @('config', 'user.email', 'v075-self-test@example.invalid') | Out-Null
    $sourceA = Join-Path $root 'scripts\a.gd'
    $sourceB = Join-Path $root 'scripts\b.gd'
    $uidA = "$sourceA.uid"
    $uidB = "$sourceB.uid"
    Write-TestUtf8 -Path (Join-Path $root 'project.godot') -Content "[application]`nconfig/name=\"formal-test\"`n"
    Write-TestUtf8 -Path $sourceA -Content "extends RefCounted`n"
    Write-TestUtf8 -Path $sourceB -Content "extends RefCounted`n"
    Invoke-TestGit -Root $root -Arguments @('add', '--all') | Out-Null
    Invoke-TestGit -Root $root -Arguments @('commit', '--quiet', '-m', 'fixture') | Out-Null
    $head = (@(Invoke-TestGit -Root $root -Arguments @('rev-parse', 'HEAD'))[0]).Trim()
    $tree = (@(Invoke-TestGit -Root $root -Arguments @('rev-parse', 'HEAD^{tree}'))[0]).Trim()

    $baseline = New-V075FormalPreimportBaseline -Worktree $root -ExpectedHeadSha $head -ExpectedTreeSha $tree
    Check ($baseline.tracked_modification_count -eq 0 -and $baseline.untracked_count -eq 0) 'baseline requires exact clean state'
    $baselinePath = Join-Path $evidenceRoot 'preimport-baseline.json'
    $baselineSha = Write-V075AtomicJson -Path $baselinePath -Value $baseline
    Write-TestUtf8 -Path $uidA -Content "uid://formalfixturea`n"
    $allowlist = New-V075UidAllowlist `
        -Worktree $root `
        -PreimportBaseline $baseline `
        -PreimportBaselineSha256 $baselineSha
    Check ($allowlist.uid_entry_count -eq 1) 'allowlist captures one generated UID'
    Check ($allowlist.entries[0].uid_relative_path -eq 'scripts/a.gd.uid') 'allowlist records relative UID path'
    Check ($allowlist.entries[0].source_relative_path -eq 'scripts/a.gd') 'allowlist records source path'
    Check ($allowlist.entries[0].uid_value -eq 'uid://formalfixturea') 'allowlist records UID value'
    Check ($allowlist.entries[0].uid_content_sha256 -match '^[0-9a-f]{64}$') 'allowlist records content hash'
    Check ([bool]$allowlist.entries[0].source_exists) 'allowlist records source exists'
    Check ($allowlist.preimport_baseline_sha256 -eq $baselineSha) 'allowlist binds the pre-import baseline hash'

    $allowlistPath = Join-Path $evidenceRoot 'generated-uid-allowlist.json'
    $allowlistSha = Write-V075AtomicJson -Path $allowlistPath -Value $allowlist
    $globalAuthority = New-V075GlobalMatrixAuthority `
        -FinalHeadSha $head `
        -FinalTreeSha $tree `
        -HarnessFingerprint ('4' * 64) `
        -MatchesPerConfiguration 20 `
        -StepLimit 512
    $globalAuthorityPath = Join-Path $evidenceRoot 'global-matrix-authority.json'
    $globalAuthoritySha = Write-V075AtomicJson `
        -Path $globalAuthorityPath `
        -Value $globalAuthority
    $globalAuthorityCopyPath = Join-Path $evidenceRoot 'global-matrix-authority-copy.json'
    $globalAuthorityCopySha = Write-V075AtomicJson `
        -Path $globalAuthorityCopyPath `
        -Value $globalAuthority
    $globalValidation = Test-V075GlobalMatrixAuthorityFile `
        -Path $globalAuthorityPath `
        -ExpectedSha256 $globalAuthoritySha
    Check ($globalAuthoritySha -eq $globalAuthorityCopySha) 'global authority file hash is deterministic across output paths'
    Check ([bool]$globalValidation.valid) 'global authority validates as an exact deterministic contract'
    Check ($globalValidation.forbidden_local_field_count -eq 0) 'global authority contains no local path/time/UID fields'
    Check ($globalAuthority.canonical_job_count -eq 100) 'global authority binds the complete five-configuration job count'
    Check ($globalAuthority.configuration_count -eq 5) 'global authority binds exactly five configurations'

    $localAttestation = New-V075LocalUidAttestation `
        -Worktree $root `
        -PreimportBaselinePath $baselinePath `
        -UidAllowlistPath $allowlistPath `
        -GlobalMatrixAuthorityPath $globalAuthorityPath `
        -ExpectedGlobalMatrixAuthoritySha256 $globalAuthoritySha
    $localAttestationPath = Join-Path $evidenceRoot 'local-uid-attestation.json'
    $localAttestationSha = Write-V075AtomicJson `
        -Path $localAttestationPath `
        -Value $localAttestation
    Check ([bool]$localAttestation.excluded_from_job_identity) 'local UID attestation declares exclusion from job identity'
    Check ($localAttestation.global_matrix_authority_sha256 -eq $globalAuthoritySha) 'local UID attestation binds global authority hash'
    Check ($localAttestation.preimport_baseline_sha256 -eq $baselineSha) 'local UID attestation binds baseline file hash'
    Check ($localAttestation.generated_uid_allowlist_sha256 -eq $allowlistSha) 'local UID attestation binds allowlist file hash'
    $verifyArguments = @{
        Worktree = $root
        PreimportBaselinePath = $baselinePath
        UidAllowlistPath = $allowlistPath
        GlobalMatrixAuthorityPath = $globalAuthorityPath
        ExpectedGlobalMatrixAuthoritySha256 = $globalAuthoritySha
        LocalUidAttestationPath = $localAttestationPath
        ExpectedLocalUidAttestationSha256 = $localAttestationSha
    }

    $exact = Test-V075FormalWorktreeIdentity @verifyArguments
    if (-not [bool]$exact.green) {
        [Console]::Error.WriteLine(($exact | ConvertTo-Json -Depth 20 -Compress))
    }
    Check ([bool]$exact.green) 'exact allowlist verification is green'
    Check ($exact.tracked_modification_count -eq 0 -and $exact.untracked_non_allowlist_count -eq 0) 'exact verification has no drift'
    Check ([bool]$exact.uid_entry_set_hash_matches -and [bool]$exact.declared_entry_count_matches) 'exact verification authenticates closed manifest metadata'
    Check ([bool]$exact.global_matrix_authority_hash_matches -and [bool]$exact.local_uid_attestation_hash_matches) 'exact verification binds both external expected SHA chains'
    Check ([bool]$exact.local_attestation_allowlist_hash_matches -and [bool]$exact.local_attestation_baseline_hash_matches) 'exact verification binds local baseline and allowlist hashes'
    Check ([bool]$exact.capture_metadata_matches) 'exact verification binds baseline and allowlist capture metadata'
    $invokePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\invoke_v075_formal_authority.ps1'
    $cliGlobalPath = Join-Path $evidenceRoot 'cli-global-matrix-authority.json'
    $cliGlobalOutput = @(& pwsh -NoProfile -File $invokePath `
        -Operation create-global-matrix-authority `
        -ExpectedHeadSha $head `
        -ExpectedTreeSha $tree `
        -HarnessFingerprint ('4' * 64) `
        -MatchesPerConfiguration 20 `
        -StepLimit 512 `
        -OutputPath $cliGlobalPath)
    $cliGlobalExit = $LASTEXITCODE
    $cliGlobalResult = $cliGlobalOutput[-1] | ConvertFrom-Json
    Check ($cliGlobalExit -eq 0) 'global-authority CLI creates deterministic authority without launching runtime'
    Check ($cliGlobalResult.output_sha256 -eq $globalAuthoritySha) 'global-authority CLI produces the same path-independent file hash'

    $cliLocalPath = Join-Path $evidenceRoot 'cli-local-uid-attestation.json'
    $cliLocalOutput = @(& pwsh -NoProfile -File $invokePath `
        -Operation create-local-uid-attestation `
        -Worktree $root `
        -PreimportBaselinePath $baselinePath `
        -UidAllowlistPath $allowlistPath `
        -GlobalMatrixAuthorityPath $globalAuthorityPath `
        -ExpectedGlobalMatrixAuthoritySha256 $globalAuthoritySha `
        -OutputPath $cliLocalPath)
    $cliLocalExit = $LASTEXITCODE
    $cliLocalResult = $cliLocalOutput[-1] | ConvertFrom-Json
    Check ($cliLocalExit -eq 0) 'local-attestation CLI captures the per-worktree evidence layer'
    Check ([bool]$cliLocalResult.result.excluded_from_job_identity) 'local-attestation CLI marks local evidence outside job identity'

    $cliPlanPath = Join-Path $evidenceRoot 'cli-formal-shard-plan.json'
    $cliPlanOutput = @(& pwsh -NoProfile -File $invokePath `
        -Operation plan-shards `
        -GlobalMatrixAuthorityPath $globalAuthorityPath `
        -ExpectedGlobalMatrixAuthoritySha256 $globalAuthoritySha `
        -WorkerCount 3 `
        -OutputPath $cliPlanPath)
    $cliPlanExit = $LASTEXITCODE
    $cliPlanResult = $cliPlanOutput[-1] | ConvertFrom-Json
    Check ($cliPlanExit -eq 0) 'planner CLI accepts only the externally frozen global authority file'
    Check ($cliPlanResult.result.authority_manifest_scope -eq 'global_matrix' -and $cliPlanResult.result.total_match_count -eq 100) 'planner CLI preserves global authority semantics and exact jobs'

    $cliOutput = @(& pwsh -NoProfile -File $invokePath `
        -Operation verify-worktree `
        -Worktree $root `
        -PreimportBaselinePath $baselinePath `
        -UidAllowlistPath $allowlistPath `
        -GlobalMatrixAuthorityPath $globalAuthorityPath `
        -ExpectedGlobalMatrixAuthoritySha256 $globalAuthoritySha `
        -LocalUidAttestationPath $localAttestationPath `
        -ExpectedLocalUidAttestationSha256 $localAttestationSha)
    $cliExit = $LASTEXITCODE
    $cliResult = $cliOutput[-1] | ConvertFrom-Json
    Check ($cliExit -eq 0) 'verify-worktree CLI accepts the complete frozen authority chain'
    Check ([bool]$cliResult.green -and [bool]$cliResult.global_matrix_authority_hash_matches) 'verify-worktree CLI returns the bound green result'

    $countTampered = $allowlist | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $countTampered.uid_entry_count = 0
    $countTamperedPath = Join-Path $evidenceRoot 'count-tampered.json'
    $null = Write-V075AtomicJson -Path $countTamperedPath -Value $countTampered
    $countTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -UidAllowlistPath $countTamperedPath
    Check (-not [bool]$countTamperedResult.green -and -not [bool]$countTamperedResult.declared_entry_count_matches) 'tampered allowlist count fails closed'

    $sourcePathTampered = $allowlist | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $sourcePathTampered.entries[0].source_relative_path = 'scripts/b.gd'
    $sourcePathTamperedPath = Join-Path $evidenceRoot 'source-path-tampered.json'
    $null = Write-V075AtomicJson -Path $sourcePathTamperedPath -Value $sourcePathTampered
    $sourcePathTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -UidAllowlistPath $sourcePathTamperedPath
    Check (-not [bool]$sourcePathTamperedResult.green -and $sourcePathTamperedResult.manifest_error_count -gt 0) 'tampered source mapping fails closed'

    $nonUidManifest = $allowlist | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $nonUidManifest.entries[0].uid_relative_path = 'scripts/a.txt'
    $nonUidManifestPath = Join-Path $evidenceRoot 'non-uid-manifest.json'
    $null = Write-V075AtomicJson -Path $nonUidManifestPath -Value $nonUidManifest
    $nonUidManifestResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -UidAllowlistPath $nonUidManifestPath
    Check (-not [bool]$nonUidManifestResult.green -and $nonUidManifestResult.manifest_error_count -gt 0) 'non-UID allowlist entry fails closed'

    $baselineHashTampered = $allowlist | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $baselineHashTampered.preimport_baseline_sha256 = ('6' * 64)
    $baselineHashTamperedPath = Join-Path $evidenceRoot 'baseline-hash-tampered.json'
    $baselineHashTamperedSha = Write-V075AtomicJson `
        -Path $baselineHashTamperedPath `
        -Value $baselineHashTampered
    $baselineHashLocal = $localAttestation | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $baselineHashLocal.generated_uid_allowlist_path = (
        Resolve-Path -LiteralPath $baselineHashTamperedPath
    ).Path
    $baselineHashLocal.generated_uid_allowlist_sha256 = $baselineHashTamperedSha
    $baselineHashLocalPath = Join-Path $evidenceRoot 'baseline-hash-local-attestation.json'
    $baselineHashLocalSha = Write-V075AtomicJson `
        -Path $baselineHashLocalPath `
        -Value $baselineHashLocal
    $baselineHashTamperedResult = Test-V075FormalWorktreeIdentity `
        -Worktree $root `
        -PreimportBaselinePath $baselinePath `
        -UidAllowlistPath $baselineHashTamperedPath `
        -GlobalMatrixAuthorityPath $globalAuthorityPath `
        -ExpectedGlobalMatrixAuthoritySha256 $globalAuthoritySha `
        -LocalUidAttestationPath $baselineHashLocalPath `
        -ExpectedLocalUidAttestationSha256 $baselineHashLocalSha
    Check (-not [bool]$baselineHashTamperedResult.green -and -not [bool]$baselineHashTamperedResult.baseline_hash_matches_allowlist) 'tampered baseline hash fails closed even when local attestation is re-frozen'

    $baselineFileTampered = $baseline | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $baselineFileTampered.recorded_at_utc = '2000-01-01T00:00:00.0000000Z'
    $baselineFileTamperedPath = Join-Path $evidenceRoot 'baseline-file-tampered.json'
    $null = Write-V075AtomicJson -Path $baselineFileTamperedPath -Value $baselineFileTampered
    $baselineFileTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -PreimportBaselinePath $baselineFileTamperedPath
    Check (-not [bool]$baselineFileTamperedResult.green -and -not [bool]$baselineFileTamperedResult.baseline_hash_matches_allowlist) 'actual baseline file hash drift fails closed'

    $baselineMetadataTampered = $baseline | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $baselineMetadataTampered.tracked_modification_count = 1
    $baselineMetadataTamperedPath = Join-Path $evidenceRoot 'baseline-metadata-tampered.json'
    $null = Write-V075AtomicJson -Path $baselineMetadataTamperedPath -Value $baselineMetadataTampered
    $baselineMetadataTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -PreimportBaselinePath $baselineMetadataTamperedPath
    Check (-not [bool]$baselineMetadataTamperedResult.green -and -not [bool]$baselineMetadataTamperedResult.baseline_metadata_matches) 'tampered baseline clean-state metadata fails closed'

    $cleanFlagTampered = $allowlist | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $cleanFlagTampered.preimport_baseline_clean = $false
    $cleanFlagTamperedPath = Join-Path $evidenceRoot 'clean-flag-tampered.json'
    $null = Write-V075AtomicJson -Path $cleanFlagTamperedPath -Value $cleanFlagTampered
    $cleanFlagTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -UidAllowlistPath $cleanFlagTamperedPath
    Check (-not [bool]$cleanFlagTamperedResult.green -and -not [bool]$cleanFlagTamperedResult.capture_metadata_matches) 'tampered baseline clean flag fails closed'

    $captureCountTampered = $allowlist | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $captureCountTampered.untracked_count_at_capture = 2
    $captureCountTamperedPath = Join-Path $evidenceRoot 'capture-count-tampered.json'
    $null = Write-V075AtomicJson -Path $captureCountTamperedPath -Value $captureCountTampered
    $captureCountTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -UidAllowlistPath $captureCountTamperedPath
    Check (-not [bool]$captureCountTamperedResult.green -and -not [bool]$captureCountTamperedResult.capture_metadata_matches) 'tampered capture count fails closed'

    $trackedCaptureCountTampered = $allowlist | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $trackedCaptureCountTampered.tracked_modification_count_at_capture = 1
    $trackedCaptureCountTamperedPath = Join-Path $evidenceRoot 'tracked-capture-count-tampered.json'
    $null = Write-V075AtomicJson -Path $trackedCaptureCountTamperedPath -Value $trackedCaptureCountTampered
    $trackedCaptureCountTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -UidAllowlistPath $trackedCaptureCountTamperedPath
    Check (-not [bool]$trackedCaptureCountTamperedResult.green -and -not [bool]$trackedCaptureCountTamperedResult.capture_metadata_matches) 'tampered tracked capture count fails closed'

    $allowlistHashTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -UidAllowlistPath $countTamperedPath
    Check (-not [bool]$allowlistHashTamperedResult.green -and -not [bool]$allowlistHashTamperedResult.local_attestation_allowlist_hash_matches) 'allowlist file hash drift fails closed'

    $globalHashTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -ExpectedGlobalMatrixAuthoritySha256 ('7' * 64)
    Check (-not [bool]$globalHashTamperedResult.green -and -not [bool]$globalHashTamperedResult.global_matrix_authority_hash_matches) 'global authority external hash drift fails closed'

    $globalHeadTampered = New-V075GlobalMatrixAuthority `
        -FinalHeadSha ('8' * 40) `
        -FinalTreeSha $tree `
        -HarnessFingerprint ('4' * 64) `
        -MatchesPerConfiguration 20 `
        -StepLimit 512
    $globalHeadTamperedPath = Join-Path $evidenceRoot 'global-head-tampered.json'
    $globalHeadTamperedSha = Write-V075AtomicJson `
        -Path $globalHeadTamperedPath `
        -Value $globalHeadTampered
    $globalHeadLocal = $localAttestation | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $globalHeadLocal.global_matrix_authority_path = (
        Resolve-Path -LiteralPath $globalHeadTamperedPath
    ).Path
    $globalHeadLocal.global_matrix_authority_sha256 = $globalHeadTamperedSha
    $globalHeadLocalPath = Join-Path $evidenceRoot 'global-head-local-attestation.json'
    $globalHeadLocalSha = Write-V075AtomicJson `
        -Path $globalHeadLocalPath `
        -Value $globalHeadLocal
    $globalHeadTamperedResult = Test-V075FormalWorktreeIdentity `
        -Worktree $root `
        -PreimportBaselinePath $baselinePath `
        -UidAllowlistPath $allowlistPath `
        -GlobalMatrixAuthorityPath $globalHeadTamperedPath `
        -ExpectedGlobalMatrixAuthoritySha256 $globalHeadTamperedSha `
        -LocalUidAttestationPath $globalHeadLocalPath `
        -ExpectedLocalUidAttestationSha256 $globalHeadLocalSha
    Check (-not [bool]$globalHeadTamperedResult.green -and -not [bool]$globalHeadTamperedResult.global_authority_head_matches_worktree) 're-frozen global HEAD drift fails closed against the local worktree'

    $localHashTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -ExpectedLocalUidAttestationSha256 ('9' * 64)
    Check (-not [bool]$localHashTamperedResult.green -and -not [bool]$localHashTamperedResult.local_uid_attestation_hash_matches) 'local attestation external hash drift fails closed'

    $localGlobalBindingTampered = $localAttestation | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $localGlobalBindingTampered.global_matrix_authority_sha256 = ('a' * 64)
    $localGlobalBindingTamperedPath = Join-Path $evidenceRoot 'local-global-binding-tampered.json'
    $localGlobalBindingTamperedSha = Write-V075AtomicJson `
        -Path $localGlobalBindingTamperedPath `
        -Value $localGlobalBindingTampered
    $localGlobalBindingTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -LocalUidAttestationPath $localGlobalBindingTamperedPath `
        -ExpectedLocalUidAttestationSha256 $localGlobalBindingTamperedSha
    Check (-not [bool]$localGlobalBindingTamperedResult.green -and -not [bool]$localGlobalBindingTamperedResult.local_attestation_global_authority_hash_matches) 're-frozen local attestation cannot substitute a different global authority hash'

    $localExcludedTampered = $localAttestation | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $localExcludedTampered.excluded_from_job_identity = $false
    $localExcludedTamperedPath = Join-Path $evidenceRoot 'local-excluded-tampered.json'
    $localExcludedTamperedSha = Write-V075AtomicJson `
        -Path $localExcludedTamperedPath `
        -Value $localExcludedTampered
    $localExcludedTamperedResult = Test-V075FormalWorktreeIdentity @verifyArguments `
        -LocalUidAttestationPath $localExcludedTamperedPath `
        -ExpectedLocalUidAttestationSha256 $localExcludedTamperedSha
    Check (-not [bool]$localExcludedTamperedResult.green -and -not [bool]$localExcludedTamperedResult.local_uid_attestation_excluded_from_job_identity) 'local attestation cannot opt into semantic job identity'

    $globalLocalFieldTampered = $globalAuthority | ConvertTo-Json -Depth 40 | ConvertFrom-Json
    $globalLocalFieldTampered | Add-Member -NotePropertyName worktree -NotePropertyValue $root
    $globalLocalFieldTamperedPath = Join-Path $evidenceRoot 'global-local-field-tampered.json'
    $globalLocalFieldTamperedSha = Write-V075AtomicJson `
        -Path $globalLocalFieldTamperedPath `
        -Value $globalLocalFieldTampered
    $globalLocalFieldValidation = Test-V075GlobalMatrixAuthorityFile `
        -Path $globalLocalFieldTamperedPath `
        -ExpectedSha256 $globalLocalFieldTamperedSha
    Check (-not [bool]$globalLocalFieldValidation.valid -and $globalLocalFieldValidation.forbidden_local_field_count -eq 1) 'global authority rejects local worktree fields even when externally re-frozen'

    $globalNestedLocalTampered = $globalAuthority | ConvertTo-Json -Depth 40 | ConvertFrom-Json
    $globalNestedLocalTampered.configuration_plan[0] | Add-Member `
        -NotePropertyName captured_at_utc `
        -NotePropertyValue '2026-08-09T00:00:00.0000000Z'
    $globalNestedLocalTamperedPath = Join-Path $evidenceRoot 'global-nested-local-tampered.json'
    $globalNestedLocalTamperedSha = Write-V075AtomicJson `
        -Path $globalNestedLocalTamperedPath `
        -Value $globalNestedLocalTampered
    $globalNestedLocalValidation = Test-V075GlobalMatrixAuthorityFile `
        -Path $globalNestedLocalTamperedPath `
        -ExpectedSha256 $globalNestedLocalTamperedSha
    Check (-not [bool]$globalNestedLocalValidation.valid -and $globalNestedLocalValidation.forbidden_local_field_count -eq 1) 'global authority rejects nested capture-time fields when externally re-frozen'

    Remove-Item -LiteralPath $uidA -Force
    $missing = Test-V075FormalWorktreeIdentity @verifyArguments
    Check (-not [bool]$missing.green -and $missing.allowlist_missing_count -eq 1) 'missing allowlisted UID fails closed'
    Write-TestUtf8 -Path $uidA -Content "uid://formalfixturea`n"

    Write-TestUtf8 -Path $uidB -Content "uid://formalfixtureb`n"
    $extra = Test-V075FormalWorktreeIdentity @verifyArguments
    Check (-not [bool]$extra.green -and $extra.untracked_non_allowlist_count -eq 1) 'extra UID fails closed'
    Remove-Item -LiteralPath $uidB -Force

    Write-TestUtf8 -Path $uidA -Content "uid://tamperedfixture`n"
    $hashMismatch = Test-V075FormalWorktreeIdentity @verifyArguments
    Check (-not [bool]$hashMismatch.green -and $hashMismatch.uid_hash_mismatch_count -eq 1) 'UID hash drift fails closed'
    Check ($hashMismatch.uid_value_mismatch_count -eq 1) 'UID value drift fails closed'
    Write-TestUtf8 -Path $uidA -Content "uid://formalfixturea`n"

    Remove-Item -LiteralPath $sourceA -Force
    $sourceMissing = Test-V075FormalWorktreeIdentity @verifyArguments
    Check (-not [bool]$sourceMissing.green -and $sourceMissing.source_missing_count -eq 1) 'missing source fails closed'
    Write-TestUtf8 -Path $sourceA -Content "extends RefCounted`n"

    Write-TestUtf8 -Path $sourceA -Content "extends Resource`n"
    $trackedDrift = Test-V075FormalWorktreeIdentity @verifyArguments
    Check (-not [bool]$trackedDrift.green -and $trackedDrift.tracked_modification_count -eq 1) 'tracked drift fails closed'
    Write-TestUtf8 -Path $sourceA -Content "extends RefCounted`n"

    $nonUid = Join-Path $root 'unexpected.txt'
    Write-TestUtf8 -Path $nonUid -Content 'unexpected'
    $nonUidResult = Test-V075FormalWorktreeIdentity @verifyArguments
    Check (-not [bool]$nonUidResult.green -and $nonUidResult.untracked_non_allowlist_count -eq 1) 'non-UID untracked file fails closed'
    $captureRejected = $false
    try {
        $null = New-V075UidAllowlist `
            -Worktree $root `
            -PreimportBaseline $baseline `
            -PreimportBaselineSha256 ('5' * 64)
    } catch {
        $captureRejected = $true
    }
    Check $captureRejected 'allowlist capture refuses non-UID untracked files'
    Remove-Item -LiteralPath $nonUid -Force

    $null = Invoke-TestGit -Root $tempBase -Arguments @('clone', '--quiet', $root, $rootB)
    [IO.Directory]::CreateDirectory($evidenceRootB) | Out-Null
    $headB = (@(Invoke-TestGit -Root $rootB -Arguments @('rev-parse', 'HEAD'))[0]).Trim()
    $treeB = (@(Invoke-TestGit -Root $rootB -Arguments @('rev-parse', 'HEAD^{tree}'))[0]).Trim()
    Check ($headB -eq $head -and $treeB -eq $tree) 'second absolute worktree has the same immutable HEAD/tree'
    $baselineB = New-V075FormalPreimportBaseline `
        -Worktree $rootB `
        -ExpectedHeadSha $head `
        -ExpectedTreeSha $tree
    $baselinePathB = Join-Path $evidenceRootB 'preimport-baseline.json'
    $baselineShaB = Write-V075AtomicJson -Path $baselinePathB -Value $baselineB
    $uidAB = Join-Path $rootB 'scripts\a.gd.uid'
    Write-TestUtf8 -Path $uidAB -Content "uid://formalfixturea`n"
    $allowlistB = New-V075UidAllowlist `
        -Worktree $rootB `
        -PreimportBaseline $baselineB `
        -PreimportBaselineSha256 $baselineShaB
    $allowlistPathB = Join-Path $evidenceRootB 'generated-uid-allowlist.json'
    $allowlistShaB = Write-V075AtomicJson -Path $allowlistPathB -Value $allowlistB
    $localAttestationB = New-V075LocalUidAttestation `
        -Worktree $rootB `
        -PreimportBaselinePath $baselinePathB `
        -UidAllowlistPath $allowlistPathB `
        -GlobalMatrixAuthorityPath $globalAuthorityPath `
        -ExpectedGlobalMatrixAuthoritySha256 $globalAuthoritySha
    $localAttestationPathB = Join-Path $evidenceRootB 'local-uid-attestation.json'
    $localAttestationShaB = Write-V075AtomicJson `
        -Path $localAttestationPathB `
        -Value $localAttestationB
    $verifyArgumentsB = @{
        Worktree = $rootB
        PreimportBaselinePath = $baselinePathB
        UidAllowlistPath = $allowlistPathB
        GlobalMatrixAuthorityPath = $globalAuthorityPath
        ExpectedGlobalMatrixAuthoritySha256 = $globalAuthoritySha
        LocalUidAttestationPath = $localAttestationPathB
        ExpectedLocalUidAttestationSha256 = $localAttestationShaB
    }
    $exactB = Test-V075FormalWorktreeIdentity @verifyArgumentsB
    if (-not [bool]$exactB.green) {
        [Console]::Error.WriteLine(($exactB | ConvertTo-Json -Depth 20 -Compress))
    }
    Check ([bool]$exactB.green) 'second absolute worktree verifies against the same global authority'
    Check ($baseline.worktree -ne $baselineB.worktree) 'local baselines retain different absolute worktree paths'
    Check ($baseline.recorded_at_utc -ne $baselineB.recorded_at_utc) 'local baselines retain different capture times'
    Check ($allowlist.captured_at_utc -ne $allowlistB.captured_at_utc) 'local allowlists retain different capture times'
    Check ($localAttestation.attested_at_utc -ne $localAttestationB.attested_at_utc) 'local attestations retain different capture times'
    Check ($baselineSha -ne $baselineShaB) 'per-worktree baseline hashes may differ'
    Check ($allowlistSha -ne $allowlistShaB) 'per-worktree allowlist hashes may differ'
    Check ($localAttestationSha -ne $localAttestationShaB) 'per-worktree local attestation hashes may differ'
    Check ($localAttestation.global_matrix_authority_sha256 -eq $localAttestationB.global_matrix_authority_sha256) 'different local attestations bind one global authority hash'

    $plan20 = Assert-Plan -Matches 20 -ExpectedShardCount 5 -ExpectedSizes @(20)
    $plan50 = Assert-Plan -Matches 50 -ExpectedShardCount 15 -ExpectedSizes @(16, 17)
    $plan400 = Assert-Plan -Matches 400 -ExpectedShardCount 100 -ExpectedSizes @(20)
    Check ($plan20.shards[0].jobs[0].seed -eq 900626424L) 'seed formula begins at frozen base seed'
    Check ($plan50.shards[3].configuration_id -eq '4p_16r_standard') 'worker assignment does not alter configuration identity'
    Check ($plan400.shards[-1].match_index_end_exclusive -eq 400) '400 planner reaches exact terminal index'
    $plan20Global = New-V075GlobalMatrixAuthority `
        -FinalHeadSha ('1' * 40) `
        -FinalTreeSha ('2' * 40) `
        -HarnessFingerprint ('4' * 64) `
        -MatchesPerConfiguration 20 `
        -StepLimit 512
    $plan20WorkerOne = New-V075FormalShardPlan `
        -GlobalMatrixAuthority $plan20Global `
        -GlobalMatrixAuthoritySha256 ('3' * 64) `
        -WorkerCount 1
    $fiveWorkerHashes = @($plan20.shards.jobs.job_identity_sha256)
    $oneWorkerHashes = @($plan20WorkerOne.shards.jobs.job_identity_sha256)
    Check (($fiveWorkerHashes -join '|') -eq ($oneWorkerHashes -join '|')) 'resume job identity is invariant across worker reassignment'
    $realPlanWorkerFive = New-V075FormalShardPlan `
        -GlobalMatrixAuthority $globalAuthority `
        -GlobalMatrixAuthoritySha256 $globalAuthoritySha `
        -WorkerCount 5
    $realPlanWorkerOne = New-V075FormalShardPlan `
        -GlobalMatrixAuthority $globalAuthority `
        -GlobalMatrixAuthoritySha256 $globalAuthoritySha `
        -WorkerCount 1
    Check ((@($realPlanWorkerFive.shards.jobs.job_identity_sha256) -join '|') -eq (@($realPlanWorkerOne.shards.jobs.job_identity_sha256) -join '|')) 'different local worktrees and worker assignments produce identical exact job identities'
    $realPlanJson = $realPlanWorkerFive | ConvertTo-Json -Depth 20 -Compress
    Check (-not $realPlanJson.Contains($localAttestationSha) -and -not $realPlanJson.Contains($localAttestationShaB)) 'local attestation hashes never enter the plan or job identity'
} finally {
    $resolvedRoot = [IO.Path]::GetFullPath($root)
    $safePrefix = $tempBase + [IO.Path]::DirectorySeparatorChar
    if ($resolvedRoot.StartsWith($safePrefix, [StringComparison]::OrdinalIgnoreCase) `
        -and [IO.Path]::GetFileName($resolvedRoot).StartsWith('ss-v075-formal-authority-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $evidenceRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $rootB -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $evidenceRootB -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -ne 0) {
    $failures | ForEach-Object { [Console]::Error.WriteLine("FAIL: $_") }
    "V075_FORMAL_AUTHORITY_TOOLING_SELF_TEST|status=FAIL|checks=$checks|failures=$($failures.Count)"
    exit 1
}
"V075_FORMAL_AUTHORITY_TOOLING_SELF_TEST|status=PASS|checks=$checks|failures=0"
exit 0
