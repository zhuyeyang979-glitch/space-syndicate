Set-StrictMode -Version Latest

$script:V075ConfigurationIds = @(
    "3p_8r_simple",
    "4p_16r_standard",
    "4p_24r_complex",
    "6p_24r_standard",
    "8p_30r_complex"
)
$script:V075SimulationId = "v075.combat.deterministic.production_path.v1"
$script:V075RulesetId = "v0.7.5"
$script:V075BaseSeed = 900626424L

function Get-V075Sha256Text {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData(
            [Text.Encoding]::UTF8.GetBytes($Text)
        )
    ).ToLowerInvariant()
}

function Get-V075NormalizedRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $normalized = $Path.Replace('\', '/').Trim()
    while ($normalized.StartsWith("./", [StringComparison]::Ordinal)) {
        $normalized = $normalized.Substring(2)
    }
    if ([string]::IsNullOrWhiteSpace($normalized) `
        -or [IO.Path]::IsPathRooted($normalized) `
        -or @($normalized.Split('/') | Where-Object { $_ -eq '..' }).Count -ne 0) {
        throw "Path is not a safe repository-relative path: '$Path'."
    }
    return $normalized
}

function Get-V075OrdinalSortedStrings {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Values)

    $copy = [string[]]@($Values)
    [Array]::Sort($copy, [StringComparer]::Ordinal)
    return $copy
}

function Invoke-V075Git {
    param(
        [Parameter(Mandatory = $true)][string]$Worktree,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Arguments
    )

    $gitArguments = @('-c', 'core.quotePath=false', '-C', $Worktree) + $Arguments
    $output = @(& git @gitArguments 2>&1 | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output -join ' | ')"
    }
    return $output
}

function Get-V075FormalGitState {
    param([Parameter(Mandatory = $true)][string]$Worktree)

    $resolved = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\', '/')
    $headRows = @(Invoke-V075Git -Worktree $resolved -Arguments @('rev-parse', 'HEAD'))
    $treeRows = @(Invoke-V075Git -Worktree $resolved -Arguments @('rev-parse', 'HEAD^{tree}'))
    if ($headRows.Count -ne 1 -or $treeRows.Count -ne 1) {
        throw "Unable to resolve one exact HEAD/tree identity for '$resolved'."
    }

    $statusRows = @(
        Invoke-V075Git -Worktree $resolved -Arguments @(
            'status', '--porcelain=v1', '--untracked-files=all', '--ignore-submodules=none'
        )
    )
    $tracked = [Collections.Generic.List[string]]::new()
    $untracked = [Collections.Generic.List[string]]::new()
    foreach ($row in $statusRows) {
        if ($row.Length -lt 3) {
            throw "Malformed git status row: '$row'."
        }
        if ($row.StartsWith('?? ', [StringComparison]::Ordinal)) {
            $path = $row.Substring(3)
            if ($path.StartsWith('"', [StringComparison]::Ordinal)) {
                throw "Quoted/unparseable untracked path fails closed: $path"
            }
            $untracked.Add((Get-V075NormalizedRelativePath -Path $path))
        } else {
            $tracked.Add($row)
        }
    }

    return [pscustomobject][ordered]@{
        worktree = $resolved
        head = $headRows[0].Trim()
        tree = $treeRows[0].Trim()
        tracked_modification_count = $tracked.Count
        tracked_status_rows = @($tracked)
        untracked_count = $untracked.Count
        untracked_paths = @(
            Get-V075OrdinalSortedStrings -Values ([string[]]@($untracked))
        )
    }
}

function Write-V075AtomicJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $absolute = [IO.Path]::GetFullPath($Path)
    $parent = [IO.Path]::GetDirectoryName($absolute)
    if ([string]::IsNullOrWhiteSpace($parent)) {
        throw "Output path has no parent directory: '$Path'."
    }
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    if (Test-Path -LiteralPath $absolute) {
        throw "Refusing to overwrite frozen authority evidence: '$absolute'."
    }

    $json = ($Value | ConvertTo-Json -Depth 40) + "`n"
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $temporary = "$absolute.tmp-$([guid]::NewGuid().ToString('N'))"
    $stream = $null
    try {
        $stream = [IO.File]::Open(
            $temporary,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::Read
        )
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        [IO.File]::Move($temporary, $absolute)
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        }
    }
    return (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-V075JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $absolute = (Resolve-Path -LiteralPath $Path).Path
    return Get-Content -LiteralPath $absolute -Raw | ConvertFrom-Json
}

function Get-V075CanonicalJobPlanRows {
    param(
        [Parameter(Mandatory = $true)][ValidateRange(10, 1000000)][int]$MatchesPerConfiguration,
        [Parameter(Mandatory = $true)][ValidateRange(1, 1000000)][int]$StepLimit
    )

    $rows = [Collections.Generic.List[string]]::new()
    for ($configurationIndex = 0; $configurationIndex -lt $script:V075ConfigurationIds.Count; $configurationIndex += 1) {
        $configurationId = $script:V075ConfigurationIds[$configurationIndex]
        for ($matchIndex = 0; $matchIndex -lt $MatchesPerConfiguration; $matchIndex += 1) {
            $seed = $script:V075BaseSeed `
                + [int64]$configurationIndex * 1000000L `
                + [int64]$matchIndex * 7919L
            $rows.Add(("{0}|{1}|{2}|{3}|{4}" -f @(
                $configurationIndex,
                $configurationId,
                $matchIndex,
                $seed,
                $StepLimit
            )))
        }
    }
    return [string[]]@($rows)
}

function New-V075GlobalMatrixAuthority {
    param(
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$FinalHeadSha,
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$FinalTreeSha,
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{64}$')][string]$HarnessFingerprint,
        [Parameter(Mandatory = $true)][ValidateRange(10, 1000000)][int]$MatchesPerConfiguration,
        [ValidateRange(1, 1000000)][int]$StepLimit = 512,
        [ValidateRange(10, 20)][int]$MinimumMatchesPerShard = 10,
        [ValidateRange(10, 20)][int]$MaximumMatchesPerShard = 20
    )

    if ($MinimumMatchesPerShard -gt $MaximumMatchesPerShard) {
        throw "MinimumMatchesPerShard exceeds MaximumMatchesPerShard."
    }
    $configurationPlan = [Collections.Generic.List[object]]::new()
    for ($configurationIndex = 0; $configurationIndex -lt $script:V075ConfigurationIds.Count; $configurationIndex += 1) {
        $configurationPlan.Add([pscustomobject][ordered]@{
            configuration_index = $configurationIndex
            configuration_id = $script:V075ConfigurationIds[$configurationIndex]
            match_index_start = 0
            match_count = $MatchesPerConfiguration
            seed_base = $script:V075BaseSeed + [int64]$configurationIndex * 1000000L
            seed_match_stride = 7919L
            step_limit = $StepLimit
        })
    }
    $canonicalJobRows = Get-V075CanonicalJobPlanRows `
        -MatchesPerConfiguration $MatchesPerConfiguration `
        -StepLimit $StepLimit
    return [pscustomobject][ordered]@{
        schema = "space_syndicate.v075.global_matrix_authority.v1"
        authority_scope = "global_matrix"
        authority_manifest_semantics = "sha256_of_deterministic_global_matrix_authority_file"
        final_head_sha = $FinalHeadSha
        final_tree_sha = $FinalTreeSha
        harness_fingerprint = $HarnessFingerprint
        simulation_id = $script:V075SimulationId
        ruleset_id = $script:V075RulesetId
        configuration_ids = [string[]]@($script:V075ConfigurationIds)
        configuration_count = $script:V075ConfigurationIds.Count
        matches_per_configuration = $MatchesPerConfiguration
        total_match_count = $MatchesPerConfiguration * $script:V075ConfigurationIds.Count
        step_limit = $StepLimit
        base_seed = $script:V075BaseSeed
        seed_configuration_stride = 1000000L
        seed_match_stride = 7919L
        minimum_matches_per_shard = $MinimumMatchesPerShard
        maximum_matches_per_shard = $MaximumMatchesPerShard
        canonical_job_descriptor_fields = @(
            'configuration_index', 'configuration_id', 'match_index', 'seed', 'step_limit'
        )
        canonical_job_count = $canonicalJobRows.Count
        canonical_job_plan_sha256 = Get-V075Sha256Text -Text ($canonicalJobRows -join "`n")
        configuration_plan = @($configurationPlan)
        job_identity_binding_fields = @(
            'final_head_sha', 'final_tree_sha', 'authority_manifest_sha256',
            'harness_fingerprint', 'simulation_id', 'ruleset_id',
            'configuration_index', 'configuration_id', 'match_index', 'seed', 'step_limit'
        )
        job_identity_excluded_execution_fields = @(
            'worker_id', 'launch_session_id', 'process_id', 'shard_id',
            'worktree', 'local_uid_attestation_sha256'
        )
    }
}

function Get-V075ForbiddenLocalAuthorityFieldPaths {
    param(
        [AllowNull()][object]$Value,
        [string]$Prefix = ""
    )

    if ($null -eq $Value -or $Value -is [string] -or $Value.GetType().IsValueType) {
        return
    }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            $name = [string]$key
            $path = if ($Prefix) { "$Prefix.$name" } else { $name }
            if ($name -match '(?i)(worktree|path|utc|baseline|uid|local|capture|recorded|attested)') {
                $path
            }
            Get-V075ForbiddenLocalAuthorityFieldPaths -Value $Value[$key] -Prefix $path
        }
        return
    }
    if ($Value -is [Collections.IEnumerable]) {
        $index = 0
        foreach ($item in $Value) {
            Get-V075ForbiddenLocalAuthorityFieldPaths `
                -Value $item `
                -Prefix ("{0}[{1}]" -f $Prefix, $index)
            $index += 1
        }
        return
    }
    foreach ($property in $Value.PSObject.Properties) {
        $name = [string]$property.Name
        $path = if ($Prefix) { "$Prefix.$name" } else { $name }
        if ($name -match '(?i)(worktree|path|utc|baseline|uid|local|capture|recorded|attested)') {
            $path
        }
        Get-V075ForbiddenLocalAuthorityFieldPaths -Value $property.Value -Prefix $path
    }
}

function Test-V075GlobalMatrixAuthorityObject {
    param([Parameter(Mandatory = $true)][object]$Authority)

    $schemaMatches = $false
    $deterministicContractMatches = $false
    $forbiddenLocalFieldCount = 0
    $forbiddenLocalFieldPaths = @()
    $validationErrorCount = 0
    $expectedAuthority = $null
    try {
        $schemaMatches = [string]$Authority.schema -ceq `
            "space_syndicate.v075.global_matrix_authority.v1"
        $forbiddenLocalFieldPaths = @(
            Get-V075ForbiddenLocalAuthorityFieldPaths -Value $Authority
        )
        $forbiddenLocalFieldCount = $forbiddenLocalFieldPaths.Count
        $expectedAuthority = New-V075GlobalMatrixAuthority `
            -FinalHeadSha ([string]$Authority.final_head_sha) `
            -FinalTreeSha ([string]$Authority.final_tree_sha) `
            -HarnessFingerprint ([string]$Authority.harness_fingerprint) `
            -MatchesPerConfiguration ([int]$Authority.matches_per_configuration) `
            -StepLimit ([int]$Authority.step_limit) `
            -MinimumMatchesPerShard ([int]$Authority.minimum_matches_per_shard) `
            -MaximumMatchesPerShard ([int]$Authority.maximum_matches_per_shard)
        $actualCanonical = $Authority | ConvertTo-Json -Depth 40 -Compress
        $expectedCanonical = $expectedAuthority | ConvertTo-Json -Depth 40 -Compress
        $deterministicContractMatches = $actualCanonical -ceq $expectedCanonical
        if (-not $schemaMatches `
            -or $forbiddenLocalFieldCount -ne 0 `
            -or -not $deterministicContractMatches) {
            $validationErrorCount += 1
        }
    } catch {
        $validationErrorCount += 1
    }
    return [pscustomobject][ordered]@{
        schema_matches = $schemaMatches
        deterministic_contract_matches = $deterministicContractMatches
        forbidden_local_field_count = $forbiddenLocalFieldCount
        forbidden_local_field_paths = $forbiddenLocalFieldPaths
        validation_error_count = $validationErrorCount
        valid = $schemaMatches `
            -and $deterministicContractMatches `
            -and $forbiddenLocalFieldCount -eq 0 `
            -and $validationErrorCount -eq 0
        expected_authority = $expectedAuthority
    }
}

function Test-V075GlobalMatrixAuthorityFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$ExpectedSha256
    )

    $absolute = (Resolve-Path -LiteralPath $Path).Path
    $actualSha = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash.ToLowerInvariant()
    $authority = Read-V075JsonFile -Path $absolute
    $objectValidation = Test-V075GlobalMatrixAuthorityObject -Authority $authority
    $hashMatches = $actualSha -ceq $ExpectedSha256
    return [pscustomobject][ordered]@{
        path = $absolute
        actual_sha256 = $actualSha
        expected_sha256 = $ExpectedSha256
        hash_matches = $hashMatches
        schema_matches = [bool]$objectValidation.schema_matches
        deterministic_contract_matches = [bool]$objectValidation.deterministic_contract_matches
        forbidden_local_field_count = [int]$objectValidation.forbidden_local_field_count
        forbidden_local_field_paths = @($objectValidation.forbidden_local_field_paths)
        validation_error_count = [int]$objectValidation.validation_error_count
        authority = $authority
        valid = $hashMatches -and [bool]$objectValidation.valid
    }
}

function New-V075FormalPreimportBaseline {
    param(
        [Parameter(Mandatory = $true)][string]$Worktree,
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedHeadSha,
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedTreeSha
    )

    $state = Get-V075FormalGitState -Worktree $Worktree
    if ($state.head -cne $ExpectedHeadSha -or $state.tree -cne $ExpectedTreeSha) {
        throw "Pre-import baseline HEAD/tree does not match the frozen identity."
    }
    if ($state.tracked_modification_count -ne 0 -or $state.untracked_count -ne 0) {
        throw "Pre-import baseline must be completely clean before controlled import."
    }

    return [pscustomobject][ordered]@{
        schema = "space_syndicate.v075.formal_preimport_baseline.v1"
        recorded_at_utc = [DateTime]::UtcNow.ToString('o')
        worktree = $state.worktree
        final_head_sha = $state.head
        final_tree_sha = $state.tree
        tracked_modification_count = 0
        untracked_count = 0
        controlled_preimport_completed = $false
        next_required_action = "run controlled Godot import, clean-stop it, then capture the closed UID allowlist"
    }
}

function Get-V075TrackedPathSet {
    param([Parameter(Mandatory = $true)][string]$Worktree)

    $set = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($row in @(Invoke-V075Git -Worktree $Worktree -Arguments @('ls-files', '--cached'))) {
        if (-not [string]::IsNullOrWhiteSpace($row)) {
            $set.Add((Get-V075NormalizedRelativePath -Path $row)) | Out-Null
        }
    }
    return $set
}

function Get-V075UidFileValue {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    try {
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    } catch {
        throw "UID file is not strict UTF-8: '$Path'."
    }
    if (-not [regex]::IsMatch($text, '\Auid://[a-z0-9]+(?:\r?\n)?\z')) {
        throw "UID file has an invalid closed content format: '$Path'."
    }
    return [pscustomobject][ordered]@{
        value = $text.TrimEnd([char[]]@("`r", "`n"))
        byte_length = [int64]$bytes.Length
    }
}

function New-V075UidAllowlist {
    param(
        [Parameter(Mandatory = $true)][string]$Worktree,
        [Parameter(Mandatory = $true)][object]$PreimportBaseline,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$PreimportBaselineSha256
    )

    if ([string]$PreimportBaseline.schema -cne "space_syndicate.v075.formal_preimport_baseline.v1" `
        -or [int]$PreimportBaseline.tracked_modification_count -ne 0 `
        -or [int]$PreimportBaseline.untracked_count -ne 0) {
        throw "Pre-import baseline schema or clean-state contract is invalid."
    }
    $state = Get-V075FormalGitState -Worktree $Worktree
    if (-not [IO.Path]::GetFullPath($state.worktree).Equals(
        [IO.Path]::GetFullPath([string]$PreimportBaseline.worktree),
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "UID allowlist capture worktree differs from its pre-import baseline."
    }
    if ($state.head -cne [string]$PreimportBaseline.final_head_sha `
        -or $state.tree -cne [string]$PreimportBaseline.final_tree_sha) {
        throw "UID allowlist capture HEAD/tree differs from its pre-import baseline."
    }
    if ($state.tracked_modification_count -ne 0) {
        throw "Controlled import modified tracked files; UID allowlist capture fails closed."
    }
    if ($state.untracked_count -eq 0) {
        throw "Controlled import produced no UID files; empty allowlists require manual attribution."
    }

    $trackedPaths = Get-V075TrackedPathSet -Worktree $state.worktree
    $entries = [Collections.Generic.List[object]]::new()
    $uidValues = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($uidRelativePath in $state.untracked_paths) {
        if ($uidRelativePath -notmatch '(?i)\.(gd|gdshader)\.uid$') {
            throw "Controlled import produced a non-UID untracked file: '$uidRelativePath'."
        }
        $sourceRelativePath = $uidRelativePath.Substring(0, $uidRelativePath.Length - 4)
        if (-not $trackedPaths.Contains($sourceRelativePath)) {
            throw "Generated UID source is not a tracked source file: '$sourceRelativePath'."
        }
        $uidAbsolutePath = [IO.Path]::GetFullPath((Join-Path $state.worktree $uidRelativePath))
        $sourceAbsolutePath = [IO.Path]::GetFullPath((Join-Path $state.worktree $sourceRelativePath))
        $worktreePrefix = $state.worktree.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if (-not $uidAbsolutePath.StartsWith($worktreePrefix, [StringComparison]::OrdinalIgnoreCase) `
            -or -not $sourceAbsolutePath.StartsWith($worktreePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "UID/source path escaped the formal worktree."
        }
        if (-not (Test-Path -LiteralPath $uidAbsolutePath -PathType Leaf) `
            -or -not (Test-Path -LiteralPath $sourceAbsolutePath -PathType Leaf)) {
            throw "UID or source file is missing during allowlist capture: '$uidRelativePath'."
        }
        $uidRecord = Get-V075UidFileValue -Path $uidAbsolutePath
        if (-not $uidValues.Add([string]$uidRecord.value)) {
            throw "Duplicate generated UID value fails closed: '$($uidRecord.value)'."
        }
        $entries.Add([pscustomobject][ordered]@{
            uid_relative_path = $uidRelativePath
            source_relative_path = $sourceRelativePath
            source_extension = [IO.Path]::GetExtension($sourceRelativePath).ToLowerInvariant()
            uid_value = [string]$uidRecord.value
            uid_content_sha256 = (Get-FileHash -LiteralPath $uidAbsolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
            uid_byte_length = [int64]$uidRecord.byte_length
            source_exists = $true
            source_tracked = $true
        })
    }

    $canonicalRows = Get-V075OrdinalSortedStrings -Values ([string[]]@($entries | ForEach-Object {
        "{0}|{1}|{2}|{3}|{4}" -f @(
            $_.uid_relative_path,
            $_.source_relative_path,
            $_.uid_value,
            $_.uid_content_sha256,
            $_.uid_byte_length
        )
    }))
    return [pscustomobject][ordered]@{
        schema = "space_syndicate.v075.formal_generated_uid_allowlist.v1"
        captured_at_utc = [DateTime]::UtcNow.ToString('o')
        worktree = $state.worktree
        final_head_sha = $state.head
        final_tree_sha = $state.tree
        preimport_baseline_sha256 = $PreimportBaselineSha256
        preimport_baseline_clean = $true
        tracked_modification_count_at_capture = 0
        untracked_count_at_capture = $state.untracked_count
        uid_entry_count = $entries.Count
        allowed_source_extensions = @('.gd', '.gdshader')
        uid_values_unique = $true
        uid_entry_set_sha256 = Get-V075Sha256Text -Text ($canonicalRows -join "`n")
        entries = @($entries)
    }
}

function Test-V075UidEvidenceSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$Worktree,
        [Parameter(Mandatory = $true)][string]$PreimportBaselinePath,
        [Parameter(Mandatory = $true)][string]$UidAllowlistPath
    )

    $preimportBaselineAbsolute = (Resolve-Path -LiteralPath $PreimportBaselinePath).Path
    $uidAllowlistAbsolute = (Resolve-Path -LiteralPath $UidAllowlistPath).Path
    $preimportBaseline = Read-V075JsonFile -Path $preimportBaselineAbsolute
    $UidAllowlist = Read-V075JsonFile -Path $uidAllowlistAbsolute
    $actualPreimportBaselineSha256 = (
        Get-FileHash -LiteralPath $preimportBaselineAbsolute -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $actualUidAllowlistSha256 = (
        Get-FileHash -LiteralPath $uidAllowlistAbsolute -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $state = Get-V075FormalGitState -Worktree $Worktree
    $expected = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $uidValues = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $canonicalRows = [Collections.Generic.List[string]]::new()
    $manifestErrorCount = 0
    $duplicateAllowlistPathCount = 0
    $duplicateUidValueCount = 0
    $schemaMatches = $false
    $declaredEntryCountMatches = $false
    $uidEntrySetHashMatches = $false
    $allowedSourceExtensionsMatch = $false
    $preimportBaselineHashValid = $false
    $uidValuesUniqueDeclared = $false
    $expectedHead = ""
    $expectedTree = ""
    $expectedWorktree = ""
    $declaredEntryCount = -1
    $declaredEntrySetSha = ""
    $rawEntries = @()
    $captureMetadataMatches = $false
    $baselineSchemaMatches = $false
    $baselineMetadataMatches = $false
    $baselineWorktreeMatches = $false
    $baselineHeadMatches = $false
    $baselineTreeMatches = $false
    $baselineHashMatchesAllowlist = $false
    $baselineManifestErrorCount = 0

    try {
        $schemaMatches = [string]$UidAllowlist.schema -ceq "space_syndicate.v075.formal_generated_uid_allowlist.v1"
        $expectedHead = [string]$UidAllowlist.final_head_sha
        $expectedTree = [string]$UidAllowlist.final_tree_sha
        $expectedWorktree = [string]$UidAllowlist.worktree
        $declaredEntryCount = [int]$UidAllowlist.uid_entry_count
        $declaredEntrySetSha = [string]$UidAllowlist.uid_entry_set_sha256
        $preimportBaselineHashValid = [string]$UidAllowlist.preimport_baseline_sha256 -cmatch '^[0-9a-f]{64}$'
        $uidValuesUniqueDeclared = $UidAllowlist.uid_values_unique -is [bool] `
            -and [bool]$UidAllowlist.uid_values_unique
        $declaredExtensions = Get-V075OrdinalSortedStrings -Values ([string[]]@(
            $UidAllowlist.allowed_source_extensions | ForEach-Object { [string]$_ }
        ))
        $allowedSourceExtensionsMatch = ($declaredExtensions -join '|') -ceq '.gd|.gdshader'
        $rawEntries = @($UidAllowlist.entries)
        $captureMetadataMatches = $UidAllowlist.preimport_baseline_clean -is [bool] `
            -and [bool]$UidAllowlist.preimport_baseline_clean `
            -and [int]$UidAllowlist.tracked_modification_count_at_capture -eq 0 `
            -and [int]$UidAllowlist.untracked_count_at_capture -eq $declaredEntryCount
        if (-not $schemaMatches `
            -or $expectedHead -notmatch '^[0-9a-f]{40}$' `
            -or $expectedTree -notmatch '^[0-9a-f]{40}$' `
            -or [string]::IsNullOrWhiteSpace($expectedWorktree) `
            -or $declaredEntryCount -lt 1 `
            -or $declaredEntrySetSha -notmatch '^[0-9a-f]{64}$' `
            -or -not $preimportBaselineHashValid `
            -or -not $uidValuesUniqueDeclared `
            -or -not $allowedSourceExtensionsMatch `
            -or -not $captureMetadataMatches) {
            $manifestErrorCount += 1
        }
    } catch {
        $manifestErrorCount += 1
        $rawEntries = @()
    }

    try {
        $baselineSchemaMatches = [string]$preimportBaseline.schema -ceq `
            "space_syndicate.v075.formal_preimport_baseline.v1"
        $baselineMetadataMatches = [int]$preimportBaseline.tracked_modification_count -eq 0 `
            -and [int]$preimportBaseline.untracked_count -eq 0 `
            -and $preimportBaseline.controlled_preimport_completed -is [bool] `
            -and -not [bool]$preimportBaseline.controlled_preimport_completed
        $baselineWorktreeMatches = [IO.Path]::GetFullPath($state.worktree).Equals(
            [IO.Path]::GetFullPath([string]$preimportBaseline.worktree),
            [StringComparison]::OrdinalIgnoreCase
        )
        $baselineHeadMatches = [string]$preimportBaseline.final_head_sha -ceq $state.head
        $baselineTreeMatches = [string]$preimportBaseline.final_tree_sha -ceq $state.tree
        $baselineHashMatchesAllowlist = $actualPreimportBaselineSha256 -ceq `
            [string]$UidAllowlist.preimport_baseline_sha256
        if (-not $baselineSchemaMatches `
            -or -not $baselineMetadataMatches `
            -or -not $baselineWorktreeMatches `
            -or -not $baselineHeadMatches `
            -or -not $baselineTreeMatches `
            -or -not $baselineHashMatchesAllowlist) {
            $baselineManifestErrorCount += 1
        }
    } catch {
        $baselineManifestErrorCount += 1
    }

    foreach ($entry in $rawEntries) {
        try {
            $path = Get-V075NormalizedRelativePath -Path ([string]$entry.uid_relative_path)
            if ($path -notmatch '(?i)\.(gd|gdshader)\.uid$') {
                throw "Allowlist entry is not a supported UID sidecar path."
            }
            $sourcePath = Get-V075NormalizedRelativePath -Path ([string]$entry.source_relative_path)
            $derivedSource = $path.Substring(0, $path.Length - 4)
            if ($sourcePath -cne $derivedSource) {
                throw "Allowlist source path does not exactly match its UID sidecar."
            }
            $sourceExtension = [string]$entry.source_extension
            if ($sourceExtension -cne [IO.Path]::GetExtension($sourcePath).ToLowerInvariant()) {
                throw "Allowlist source extension does not match its source path."
            }
            $uidValue = [string]$entry.uid_value
            $uidHash = [string]$entry.uid_content_sha256
            $uidByteLength = [int64]$entry.uid_byte_length
            if ($uidValue -notmatch '\Auid://[a-z0-9]+\z' `
                -or $uidHash -cnotmatch '^[0-9a-f]{64}$' `
                -or $uidByteLength -lt 1 `
                -or -not ($entry.source_exists -is [bool]) `
                -or -not [bool]$entry.source_exists `
                -or -not ($entry.source_tracked -is [bool]) `
                -or -not [bool]$entry.source_tracked) {
                throw "Allowlist entry metadata is invalid."
            }
            if ($expected.ContainsKey($path)) {
                $duplicateAllowlistPathCount += 1
                continue
            }
            if (-not $uidValues.Add($uidValue)) {
                $duplicateUidValueCount += 1
            }
            $validatedEntry = [pscustomobject][ordered]@{
                uid_relative_path = $path
                source_relative_path = $sourcePath
                source_extension = $sourceExtension
                uid_value = $uidValue
                uid_content_sha256 = $uidHash
                uid_byte_length = $uidByteLength
            }
            $expected.Add($path, $validatedEntry)
            $canonicalRows.Add(("{0}|{1}|{2}|{3}|{4}" -f @(
                $path, $sourcePath, $uidValue, $uidHash, $uidByteLength
            )))
        } catch {
            $manifestErrorCount += 1
        }
    }
    $sortedCanonicalRows = Get-V075OrdinalSortedStrings -Values ([string[]]@($canonicalRows))
    $recomputedEntrySetSha = Get-V075Sha256Text -Text ($sortedCanonicalRows -join "`n")
    $declaredEntryCountMatches = $declaredEntryCount -eq $rawEntries.Count `
        -and $declaredEntryCount -eq $expected.Count
    $uidEntrySetHashMatches = $declaredEntrySetSha -ceq $recomputedEntrySetSha

    $actualUntracked = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($path in $state.untracked_paths) { $actualUntracked.Add($path) | Out-Null }
    $untrackedNonAllowlist = @($state.untracked_paths | Where-Object { -not $expected.ContainsKey($_) })
    $allowlistMissing = @($expected.Keys | Where-Object { -not $actualUntracked.Contains($_) })
    $uidHashMismatchCount = 0
    $uidValueMismatchCount = 0
    $uidContentInvalidCount = 0
    $uidByteLengthMismatchCount = 0
    $sourceMissingCount = 0
    $sourcePathMismatchCount = 0
    $sourceUntrackedCount = 0
    $trackedPaths = Get-V075TrackedPathSet -Worktree $state.worktree

    foreach ($uidRelativePath in $expected.Keys) {
        $entry = $expected[$uidRelativePath]
        $derivedSource = [string]$entry.source_relative_path
        $sourceAbsolute = [IO.Path]::GetFullPath((Join-Path $state.worktree $derivedSource))
        if (-not (Test-Path -LiteralPath $sourceAbsolute -PathType Leaf)) {
            $sourceMissingCount += 1
        }
        if (-not $trackedPaths.Contains($derivedSource)) {
            $sourceUntrackedCount += 1
        }
        if (-not $actualUntracked.Contains($uidRelativePath)) { continue }
        $uidAbsolute = [IO.Path]::GetFullPath((Join-Path $state.worktree $uidRelativePath))
        try {
            if ((Get-FileHash -LiteralPath $uidAbsolute -Algorithm SHA256).Hash.ToLowerInvariant() `
                -cne [string]$entry.uid_content_sha256) {
                $uidHashMismatchCount += 1
            }
            $actualUid = Get-V075UidFileValue -Path $uidAbsolute
            if ([string]$actualUid.value -cne [string]$entry.uid_value) {
                $uidValueMismatchCount += 1
            }
            if ([int64]$actualUid.byte_length -ne [int64]$entry.uid_byte_length) {
                $uidByteLengthMismatchCount += 1
            }
        } catch {
            $uidContentInvalidCount += 1
        }
    }

    $headMatches = $state.head -ceq $expectedHead
    $treeMatches = $state.tree -ceq $expectedTree
    $worktreeMatches = $false
    try {
        $worktreeMatches = [IO.Path]::GetFullPath($state.worktree).Equals(
            [IO.Path]::GetFullPath($expectedWorktree),
            [StringComparison]::OrdinalIgnoreCase
        )
    } catch {
        $manifestErrorCount += 1
    }
    $allowlistMatch = $schemaMatches `
        -and $declaredEntryCountMatches `
        -and $uidEntrySetHashMatches `
        -and $allowedSourceExtensionsMatch `
        -and $preimportBaselineHashValid `
        -and $uidValuesUniqueDeclared `
        -and $manifestErrorCount -eq 0 `
        -and $duplicateAllowlistPathCount -eq 0 `
        -and $duplicateUidValueCount -eq 0 `
        -and $untrackedNonAllowlist.Count -eq 0 `
        -and $allowlistMissing.Count -eq 0 `
        -and $uidHashMismatchCount -eq 0 `
        -and $uidValueMismatchCount -eq 0 `
        -and $uidContentInvalidCount -eq 0 `
        -and $uidByteLengthMismatchCount -eq 0 `
        -and $sourceMissingCount -eq 0 `
        -and $sourcePathMismatchCount -eq 0 `
        -and $sourceUntrackedCount -eq 0
    $green = $headMatches -and $treeMatches -and $worktreeMatches `
        -and $state.tracked_modification_count -eq 0 `
        -and $allowlistMatch `
        -and $baselineManifestErrorCount -eq 0

    return [pscustomobject][ordered]@{
        schema = "space_syndicate.v075.local_uid_evidence_snapshot.v1"
        verified_at_utc = [DateTime]::UtcNow.ToString('o')
        worktree = $state.worktree
        actual_head_sha = $state.head
        expected_head_sha = $expectedHead
        actual_tree_sha = $state.tree
        expected_tree_sha = $expectedTree
        head_matches = $headMatches
        tree_matches = $treeMatches
        worktree_matches = $worktreeMatches
        tracked_modification_count = $state.tracked_modification_count
        tracked_status_rows = $state.tracked_status_rows
        untracked_count = $state.untracked_count
        allowlist_entry_count = $expected.Count
        untracked_non_allowlist_count = $untrackedNonAllowlist.Count
        untracked_non_allowlist_paths = $untrackedNonAllowlist
        allowlist_missing_count = $allowlistMissing.Count
        allowlist_missing_paths = $allowlistMissing
        uid_hash_mismatch_count = $uidHashMismatchCount
        uid_value_mismatch_count = $uidValueMismatchCount
        uid_content_invalid_count = $uidContentInvalidCount
        uid_byte_length_mismatch_count = $uidByteLengthMismatchCount
        source_missing_count = $sourceMissingCount
        source_path_mismatch_count = $sourcePathMismatchCount
        source_untracked_count = $sourceUntrackedCount
        duplicate_allowlist_path_count = $duplicateAllowlistPathCount
        duplicate_uid_value_count = $duplicateUidValueCount
        schema_matches = $schemaMatches
        declared_entry_count_matches = $declaredEntryCountMatches
        uid_entry_set_hash_matches = $uidEntrySetHashMatches
        declared_uid_entry_set_sha256 = $declaredEntrySetSha
        recomputed_uid_entry_set_sha256 = $recomputedEntrySetSha
        allowed_source_extensions_match = $allowedSourceExtensionsMatch
        preimport_baseline_hash_valid = $preimportBaselineHashValid
        capture_metadata_matches = $captureMetadataMatches
        uid_values_unique_declared = $uidValuesUniqueDeclared
        manifest_error_count = $manifestErrorCount
        preimport_baseline_path = $preimportBaselineAbsolute
        actual_preimport_baseline_sha256 = $actualPreimportBaselineSha256
        baseline_schema_matches = $baselineSchemaMatches
        baseline_metadata_matches = $baselineMetadataMatches
        baseline_worktree_matches = $baselineWorktreeMatches
        baseline_head_matches = $baselineHeadMatches
        baseline_tree_matches = $baselineTreeMatches
        baseline_hash_matches_allowlist = $baselineHashMatchesAllowlist
        baseline_manifest_error_count = $baselineManifestErrorCount
        uid_allowlist_path = $uidAllowlistAbsolute
        actual_uid_allowlist_sha256 = $actualUidAllowlistSha256
        generated_uid_allowlist_match = $allowlistMatch
        green = $green
    }
}

function New-V075LocalUidAttestationRecord {
    param(
        [Parameter(Mandatory = $true)][string]$AttestedAtUtc,
        [Parameter(Mandatory = $true)][object]$UidSnapshot,
        [Parameter(Mandatory = $true)][object]$GlobalAuthorityValidation
    )

    return [pscustomobject][ordered]@{
        schema = "space_syndicate.v075.local_uid_attestation.v1"
        attestation_scope = "per_worktree_uid_execution_identity"
        attested_at_utc = $AttestedAtUtc
        worktree = [string]$UidSnapshot.worktree
        final_head_sha = [string]$UidSnapshot.actual_head_sha
        final_tree_sha = [string]$UidSnapshot.actual_tree_sha
        global_matrix_authority_path = [string]$GlobalAuthorityValidation.path
        global_matrix_authority_sha256 = [string]$GlobalAuthorityValidation.actual_sha256
        preimport_baseline_path = [string]$UidSnapshot.preimport_baseline_path
        preimport_baseline_sha256 = [string]$UidSnapshot.actual_preimport_baseline_sha256
        generated_uid_allowlist_path = [string]$UidSnapshot.uid_allowlist_path
        generated_uid_allowlist_sha256 = [string]$UidSnapshot.actual_uid_allowlist_sha256
        uid_entry_set_sha256 = [string]$UidSnapshot.recomputed_uid_entry_set_sha256
        uid_entry_count = [int]$UidSnapshot.allowlist_entry_count
        tracked_modification_count_at_attestation = [int]$UidSnapshot.tracked_modification_count
        untracked_count_at_attestation = [int]$UidSnapshot.untracked_count
        generated_uid_allowlist_match = [bool]$UidSnapshot.generated_uid_allowlist_match
        purpose = "local_execution_gate_before_and_after_each_shard"
        excluded_from_job_identity = $true
    }
}

function New-V075LocalUidAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$Worktree,
        [Parameter(Mandatory = $true)][string]$PreimportBaselinePath,
        [Parameter(Mandatory = $true)][string]$UidAllowlistPath,
        [Parameter(Mandatory = $true)][string]$GlobalMatrixAuthorityPath,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$ExpectedGlobalMatrixAuthoritySha256
    )

    $globalValidation = Test-V075GlobalMatrixAuthorityFile `
        -Path $GlobalMatrixAuthorityPath `
        -ExpectedSha256 $ExpectedGlobalMatrixAuthoritySha256
    if (-not [bool]$globalValidation.valid) {
        throw "Global matrix authority is not exact and deterministic."
    }
    $uidSnapshot = Test-V075UidEvidenceSnapshot `
        -Worktree $Worktree `
        -PreimportBaselinePath $PreimportBaselinePath `
        -UidAllowlistPath $UidAllowlistPath
    if (-not [bool]$uidSnapshot.green) {
        throw "Local UID evidence is not closed and exact."
    }
    $globalAuthority = $globalValidation.authority
    if ([string]$globalAuthority.final_head_sha -cne [string]$uidSnapshot.actual_head_sha `
        -or [string]$globalAuthority.final_tree_sha -cne [string]$uidSnapshot.actual_tree_sha) {
        throw "Local UID evidence HEAD/tree differs from the global matrix authority."
    }
    return New-V075LocalUidAttestationRecord `
        -AttestedAtUtc ([DateTime]::UtcNow.ToString('o')) `
        -UidSnapshot $uidSnapshot `
        -GlobalAuthorityValidation $globalValidation
}

function Test-V075FormalWorktreeIdentity {
    param(
        [Parameter(Mandatory = $true)][string]$Worktree,
        [Parameter(Mandatory = $true)][string]$PreimportBaselinePath,
        [Parameter(Mandatory = $true)][string]$UidAllowlistPath,
        [Parameter(Mandatory = $true)][string]$GlobalMatrixAuthorityPath,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$ExpectedGlobalMatrixAuthoritySha256,
        [Parameter(Mandatory = $true)][string]$LocalUidAttestationPath,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$ExpectedLocalUidAttestationSha256
    )

    $globalValidation = Test-V075GlobalMatrixAuthorityFile `
        -Path $GlobalMatrixAuthorityPath `
        -ExpectedSha256 $ExpectedGlobalMatrixAuthoritySha256
    $uidSnapshot = Test-V075UidEvidenceSnapshot `
        -Worktree $Worktree `
        -PreimportBaselinePath $PreimportBaselinePath `
        -UidAllowlistPath $UidAllowlistPath
    $localAbsolute = (Resolve-Path -LiteralPath $LocalUidAttestationPath).Path
    $localActualSha = (
        Get-FileHash -LiteralPath $localAbsolute -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $localAttestation = Read-V075JsonFile -Path $localAbsolute
    $localHashMatches = $localActualSha -ceq $ExpectedLocalUidAttestationSha256
    $localSchemaMatches = $false
    $localTimestampValid = $false
    $localContractMatches = $false
    $localAttestationErrorCount = 0
    try {
        $localSchemaMatches = [string]$localAttestation.schema -ceq `
            "space_syndicate.v075.local_uid_attestation.v1"
        $timestamp = [DateTimeOffset]::MinValue
        $localTimestampValid = [DateTimeOffset]::TryParse(
            [string]$localAttestation.attested_at_utc,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$timestamp
        )
        $expectedLocal = New-V075LocalUidAttestationRecord `
            -AttestedAtUtc ([string]$localAttestation.attested_at_utc) `
            -UidSnapshot $uidSnapshot `
            -GlobalAuthorityValidation $globalValidation
        $expectedLocal.attested_at_utc = $localAttestation.attested_at_utc
        $actualCanonical = $localAttestation | ConvertTo-Json -Depth 40 -Compress
        $expectedCanonical = $expectedLocal | ConvertTo-Json -Depth 40 -Compress
        $localContractMatches = $actualCanonical -ceq $expectedCanonical
        if (-not $localSchemaMatches `
            -or -not $localTimestampValid `
            -or -not $localContractMatches `
            -or -not $localHashMatches) {
            $localAttestationErrorCount += 1
        }
    } catch {
        $localAttestationErrorCount += 1
    }

    $globalAuthority = $globalValidation.authority
    $globalHeadMatchesWorktree = $false
    $globalTreeMatchesWorktree = $false
    try {
        $globalHeadMatchesWorktree = [string]$globalAuthority.final_head_sha -ceq `
            [string]$uidSnapshot.actual_head_sha
        $globalTreeMatchesWorktree = [string]$globalAuthority.final_tree_sha -ceq `
            [string]$uidSnapshot.actual_tree_sha
    } catch {
        $globalHeadMatchesWorktree = $false
        $globalTreeMatchesWorktree = $false
    }
    $localGlobalHashMatches = $false
    $localBaselineHashMatches = $false
    $localAllowlistHashMatches = $false
    $localExcludedFromJobIdentity = $false
    try {
        $localGlobalHashMatches = [string]$localAttestation.global_matrix_authority_sha256 -ceq `
            [string]$globalValidation.actual_sha256
        $localBaselineHashMatches = [string]$localAttestation.preimport_baseline_sha256 -ceq `
            [string]$uidSnapshot.actual_preimport_baseline_sha256
        $localAllowlistHashMatches = [string]$localAttestation.generated_uid_allowlist_sha256 -ceq `
            [string]$uidSnapshot.actual_uid_allowlist_sha256
        $localExcludedFromJobIdentity = $localAttestation.excluded_from_job_identity -is [bool] `
            -and [bool]$localAttestation.excluded_from_job_identity
    } catch {
        $localAttestationErrorCount += 1
    }
    $localWorktreeMatches = $false
    try {
        $localWorktreeMatches = [IO.Path]::GetFullPath([string]$localAttestation.worktree).Equals(
            [IO.Path]::GetFullPath([string]$uidSnapshot.worktree),
            [StringComparison]::OrdinalIgnoreCase
        )
    } catch {
        $localWorktreeMatches = $false
    }
    $green = [bool]$uidSnapshot.green `
        -and [bool]$globalValidation.valid `
        -and $globalHeadMatchesWorktree `
        -and $globalTreeMatchesWorktree `
        -and $localHashMatches `
        -and $localSchemaMatches `
        -and $localTimestampValid `
        -and $localContractMatches `
        -and $localGlobalHashMatches `
        -and $localBaselineHashMatches `
        -and $localAllowlistHashMatches `
        -and $localWorktreeMatches `
        -and $localExcludedFromJobIdentity `
        -and $localAttestationErrorCount -eq 0

    $result = [ordered]@{
        schema = "space_syndicate.v075.formal_worktree_identity_verification.v2"
        verified_at_utc = [DateTime]::UtcNow.ToString('o')
        authority_manifest_scope = "global_matrix"
        authority_manifest_sha256 = [string]$globalValidation.actual_sha256
        global_matrix_authority_path = [string]$globalValidation.path
        actual_global_matrix_authority_sha256 = [string]$globalValidation.actual_sha256
        expected_global_matrix_authority_sha256 = $ExpectedGlobalMatrixAuthoritySha256
        global_matrix_authority_hash_matches = [bool]$globalValidation.hash_matches
        global_matrix_authority_schema_matches = [bool]$globalValidation.schema_matches
        global_matrix_authority_deterministic_contract_matches = `
            [bool]$globalValidation.deterministic_contract_matches
        global_matrix_authority_forbidden_local_field_count = `
            [int]$globalValidation.forbidden_local_field_count
        global_matrix_authority_valid = [bool]$globalValidation.valid
        global_authority_head_matches_worktree = $globalHeadMatchesWorktree
        global_authority_tree_matches_worktree = $globalTreeMatchesWorktree
        local_uid_attestation_path = $localAbsolute
        actual_local_uid_attestation_sha256 = $localActualSha
        expected_local_uid_attestation_sha256 = $ExpectedLocalUidAttestationSha256
        local_uid_attestation_hash_matches = $localHashMatches
        local_uid_attestation_schema_matches = $localSchemaMatches
        local_uid_attestation_timestamp_valid = $localTimestampValid
        local_uid_attestation_contract_matches = $localContractMatches
        local_uid_attestation_error_count = $localAttestationErrorCount
        local_attestation_global_authority_hash_matches = $localGlobalHashMatches
        local_attestation_baseline_hash_matches = $localBaselineHashMatches
        local_attestation_allowlist_hash_matches = $localAllowlistHashMatches
        local_attestation_worktree_matches = $localWorktreeMatches
        local_uid_attestation_excluded_from_job_identity = $localExcludedFromJobIdentity
    }
    foreach ($property in $uidSnapshot.PSObject.Properties) {
        if (-not $result.Contains($property.Name)) {
            $result[$property.Name] = $property.Value
        }
    }
    $result['green'] = $green
    return [pscustomobject]$result
}

function New-V075FormalShardPlan {
    param(
        [Parameter(Mandatory = $true)][object]$GlobalMatrixAuthority,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$GlobalMatrixAuthoritySha256,
        [ValidateRange(1, 5)][int]$WorkerCount = 5
    )

    $authorityValidation = Test-V075GlobalMatrixAuthorityObject `
        -Authority $GlobalMatrixAuthority
    if (-not [bool]$authorityValidation.valid) {
        throw "Shard planning requires a valid deterministic global matrix authority."
    }
    $FinalHeadSha = [string]$GlobalMatrixAuthority.final_head_sha
    $FinalTreeSha = [string]$GlobalMatrixAuthority.final_tree_sha
    $HarnessFingerprint = [string]$GlobalMatrixAuthority.harness_fingerprint
    $MatchesPerConfiguration = [int]$GlobalMatrixAuthority.matches_per_configuration
    $StepLimit = [int]$GlobalMatrixAuthority.step_limit
    $MinimumMatchesPerShard = [int]$GlobalMatrixAuthority.minimum_matches_per_shard
    $MaximumMatchesPerShard = [int]$GlobalMatrixAuthority.maximum_matches_per_shard
    $shards = [Collections.Generic.List[object]]::new()
    $jobIdentityHashes = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $seeds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $globalShardId = 0

    for ($configurationIndex = 0; $configurationIndex -lt $script:V075ConfigurationIds.Count; $configurationIndex++) {
        $configurationId = $script:V075ConfigurationIds[$configurationIndex]
        $configurationShardCount = [int][Math]::Ceiling(
            [double]$MatchesPerConfiguration / [double]$MaximumMatchesPerShard
        )
        $baseSize = [int][Math]::Floor(
            [double]$MatchesPerConfiguration / [double]$configurationShardCount
        )
        $remainder = $MatchesPerConfiguration % $configurationShardCount
        if ($baseSize -lt $MinimumMatchesPerShard) {
            throw "Unable to partition configuration into closed 10-20 match shards."
        }
        $nextMatchIndex = 0
        for ($configurationShardIndex = 0; $configurationShardIndex -lt $configurationShardCount; $configurationShardIndex++) {
            $shardSize = $baseSize + $(if ($configurationShardIndex -lt $remainder) { 1 } else { 0 })
            if ($shardSize -lt $MinimumMatchesPerShard -or $shardSize -gt $MaximumMatchesPerShard) {
                throw "Planner produced a shard outside the closed size range."
            }
            $jobs = [Collections.Generic.List[object]]::new()
            $matchIndexStart = $nextMatchIndex
            for ($offset = 0; $offset -lt $shardSize; $offset++) {
                $matchIndex = $nextMatchIndex
                $seed = $script:V075BaseSeed + [int64]$configurationIndex * 1000000L + [int64]$matchIndex * 7919L
                $identity = [ordered]@{
                    final_head_sha = $FinalHeadSha
                    final_tree_sha = $FinalTreeSha
                    authority_manifest_sha256 = $GlobalMatrixAuthoritySha256
                    harness_fingerprint = $HarnessFingerprint
                    simulation_id = $script:V075SimulationId
                    ruleset_id = $script:V075RulesetId
                    configuration_index = $configurationIndex
                    configuration_id = $configurationId
                    match_index = $matchIndex
                    seed = $seed
                    step_limit = $StepLimit
                }
                $canonicalIdentity = $identity | ConvertTo-Json -Depth 4 -Compress
                $identitySha = Get-V075Sha256Text -Text $canonicalIdentity
                if (-not $jobIdentityHashes.Add($identitySha)) {
                    throw "Planner produced a duplicate exact job identity."
                }
                if (-not $seeds.Add([string]$seed)) {
                    throw "Planner produced a duplicate seed."
                }
                $jobs.Add([pscustomobject][ordered]@{
                    configuration_index = $configurationIndex
                    configuration_id = $configurationId
                    match_index = $matchIndex
                    seed = $seed
                    step_limit = $StepLimit
                    job_identity = [pscustomobject]$identity
                    job_identity_canonical_json = $canonicalIdentity
                    job_identity_sha256 = $identitySha
                })
                $nextMatchIndex += 1
            }
            $shards.Add([pscustomobject][ordered]@{
                shard_id = $globalShardId
                assigned_worker_id = $configurationIndex % $WorkerCount
                configuration_index = $configurationIndex
                configuration_id = $configurationId
                configuration_shard_index = $configurationShardIndex
                match_index_start = $matchIndexStart
                match_index_end_exclusive = $nextMatchIndex
                expected_match_count = $jobs.Count
                jobs = @($jobs)
            })
            $globalShardId += 1
        }
        if ($nextMatchIndex -ne $MatchesPerConfiguration) {
            throw "Planner did not cover the complete configuration range."
        }
    }

    $totalMatchCount = $MatchesPerConfiguration * $script:V075ConfigurationIds.Count
    if ($jobIdentityHashes.Count -ne $totalMatchCount -or $seeds.Count -ne $totalMatchCount) {
        throw "Planner exact-once invariant failed."
    }
    $canonicalJobRows = Get-V075CanonicalJobPlanRows `
        -MatchesPerConfiguration $MatchesPerConfiguration `
        -StepLimit $StepLimit
    $canonicalJobPlanSha = Get-V075Sha256Text -Text ($canonicalJobRows -join "`n")
    if ($canonicalJobPlanSha -cne [string]$GlobalMatrixAuthority.canonical_job_plan_sha256) {
        throw "Planner job descriptors differ from the global matrix authority."
    }
    return [pscustomobject][ordered]@{
        schema = "space_syndicate.v075.formal_shard_plan.v1"
        created_at_utc = [DateTime]::UtcNow.ToString('o')
        final_head_sha = $FinalHeadSha
        final_tree_sha = $FinalTreeSha
        authority_manifest_scope = "global_matrix"
        authority_manifest_sha256 = $GlobalMatrixAuthoritySha256
        global_matrix_authority_sha256 = $GlobalMatrixAuthoritySha256
        harness_fingerprint = $HarnessFingerprint
        simulation_id = $script:V075SimulationId
        ruleset_id = $script:V075RulesetId
        configuration_ids = $script:V075ConfigurationIds
        configuration_count = $script:V075ConfigurationIds.Count
        matches_per_configuration = $MatchesPerConfiguration
        total_match_count = $totalMatchCount
        minimum_matches_per_shard = $MinimumMatchesPerShard
        maximum_matches_per_shard = $MaximumMatchesPerShard
        shard_count = $shards.Count
        worker_count = $WorkerCount
        unique_job_identity_count = $jobIdentityHashes.Count
        unique_seed_count = $seeds.Count
        canonical_job_plan_sha256 = $canonicalJobPlanSha
        job_identity_binding_fields = @(
            'final_head_sha', 'final_tree_sha', 'authority_manifest_sha256',
            'harness_fingerprint', 'simulation_id', 'ruleset_id',
            'configuration_index', 'configuration_id', 'match_index', 'seed', 'step_limit'
        )
        job_identity_excluded_execution_fields = @(
            'worker_id', 'launch_session_id', 'process_id', 'shard_id',
            'worktree', 'local_uid_attestation_sha256'
        )
        shards = @($shards)
    }
}

Export-ModuleMember -Function @(
    'Get-V075FormalGitState',
    'New-V075GlobalMatrixAuthority',
    'Test-V075GlobalMatrixAuthorityFile',
    'New-V075FormalPreimportBaseline',
    'New-V075UidAllowlist',
    'New-V075LocalUidAttestation',
    'Test-V075FormalWorktreeIdentity',
    'New-V075FormalShardPlan',
    'Write-V075AtomicJson',
    'Read-V075JsonFile'
)
