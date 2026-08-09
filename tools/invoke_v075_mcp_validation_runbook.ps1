[CmdletBinding()]
param(
    [string]$RunbookPath = (Join-Path `
        (Split-Path -Parent $PSScriptRoot) `
        "docs\playtest\v075_mcp_validation_runbook.md"),

    [switch]$ValidateOnly,

    [string]$GeneratedUidAllowlistPath = `
        $env:V075_MCP_GENERATED_UID_ALLOWLIST_PATH,

    [string]$ExpectedGeneratedUidAllowlistSha256 = `
        $env:V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256
)

$ErrorActionPreference = "Stop"

function Invoke-RunnerGit {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $rows = @(& git -C $Root @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git -C <root> $($Arguments -join ' ')"
    }
    return @($rows)
}

function Get-RunbookVariableValue {
    param([Parameter(Mandatory = $true)][string]$Name)
    $variable = Get-Variable -Name $Name -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $variable) { return $null }
    return $variable.Value
}

function Get-RunnerFileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-RunnerCanonicalSha256Hex {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Assert-RunnerPathChainHasNoReparsePoint {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $fullPath = [IO.Path]::GetFullPath($Path)
    foreach ($segment in $fullPath.Split(
        @("\", "/"),
        [StringSplitOptions]::RemoveEmptyEntries
    )) {
        if ($segment -match '~[0-9]+') {
            throw "$Label must not use an 8.3 path alias: $fullPath"
        }
    }
    $cursor = $fullPath.TrimEnd("\", "/")
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 `
                -or -not [string]::IsNullOrWhiteSpace([string]$item.LinkType) `
                -or $null -ne $item.Target) {
                throw (
                    "$Label path chain contains a reparse point, junction, " +
                    "or symbolic link: $($item.FullName)"
                )
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ([string]::IsNullOrWhiteSpace($parent) `
            -or $parent.Equals(
                $cursor,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            break
        }
        $cursor = $parent.TrimEnd("\", "/")
    }
}

function Get-RunnerOrdinalUniqueSortedPaths {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Paths)
    $sorted = [string[]]@($Paths)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    for ($index = 1; $index -lt $sorted.Count; $index += 1) {
        if ($sorted[$index] -ceq $sorted[$index - 1]) {
            throw "Duplicate canonical path: $($sorted[$index])"
        }
    }
    return $sorted
}

function Get-RunnerCanonicalPathSetSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Paths)
    $sorted = @(Get-RunnerOrdinalUniqueSortedPaths -Paths $Paths)
    $bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes(
        [string]::Join("`n", [string[]]$sorted)
    )
    return Get-RunnerCanonicalSha256Hex -Bytes $bytes
}

function Get-RunnerCanonicalFileMapSha256 {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string[]]$Paths
    )
    $rows = [Collections.Generic.List[string]]::new()
    foreach ($relativePath in @(Get-RunnerOrdinalUniqueSortedPaths -Paths $Paths)) {
        if ([IO.Path]::IsPathRooted($relativePath) `
            -or $relativePath.Contains("\") `
            -or -not $relativePath.EndsWith(
                ".import",
                [StringComparison]::Ordinal
            )) {
            throw "Invalid canonical import path: $relativePath"
        }
        $absolutePath = Resolve-CleanupChildPath -Root $Root -RelativePath $relativePath
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            throw "Missing canonical import file: $relativePath"
        }
        $rows.Add(
            "$relativePath$([char]0)$(Get-RunnerFileSha256 -Path $absolutePath)"
        )
    }
    $bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes(
        [string]::Join("`n", [string[]]$rows.ToArray())
    )
    return Get-RunnerCanonicalSha256Hex -Bytes $bytes
}

function Get-RunnerCanonicalImportAuthority {
    $paths = [string[]]@(
        'assets/third_party/commercial/materials/ambientcg/MetalPlates013/MetalPlates013_1K-JPG_AmbientOcclusion.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/MetalPlates013/MetalPlates013_1K-JPG_Color.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/MetalPlates013/MetalPlates013_1K-JPG_Metalness.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/MetalPlates013/MetalPlates013_1K-JPG_NormalGL.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/MetalPlates013/MetalPlates013_1K-JPG_Roughness.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/NightSkyHDRI001/NightSkyHDRI001_2K_HDR.exr.import'
        'assets/third_party/commercial/materials/ambientcg/PaintedMetal007/PaintedMetal007_1K-JPG_AmbientOcclusion.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/PaintedMetal007/PaintedMetal007_1K-JPG_Color.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/PaintedMetal007/PaintedMetal007_1K-JPG_Metalness.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/PaintedMetal007/PaintedMetal007_1K-JPG_NormalGL.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/PaintedMetal007/PaintedMetal007_1K-JPG_Roughness.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/SheetMetal003/SheetMetal003_1K-JPG_Color.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/SheetMetal003/SheetMetal003_1K-JPG_Metalness.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/SheetMetal003/SheetMetal003_1K-JPG_NormalGL.jpg.import'
        'assets/third_party/commercial/materials/ambientcg/SheetMetal003/SheetMetal003_1K-JPG_Roughness.jpg.import'
        'assets/third_party/commercial/models/quaternius/animated_mech/gltf/George_George_Texture.png.import'
        'assets/third_party/commercial/models/quaternius/animated_mech/gltf/Leela_Leela_Texture.png.import'
        'assets/third_party/commercial/models/quaternius/animated_mech/gltf/Mike_Mike_Texture.png.import'
        'assets/third_party/commercial/models/quaternius/animated_mech/gltf/Stan_Stan_Texture.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Decals.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_PaddedWall_BaseColor.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_PaddedWall_Normal.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_PaddedWall_ORM.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Trim_01_BaseColor_Red.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Trim_01_Normal.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Trim_01_ORM.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Trim_02_BaseColor_Red.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Trim_02_Normal.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Trim_02_ORM.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Trim_03_BaseColor.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Trim_03_Normal.png.import'
        'assets/third_party/commercial/models/quaternius/modular_scifi_megakit/gltf/T_Trim_03_ORM.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Enemies_BaseColor_png.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Enemies_Normal.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Enemies_ORM.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Props_Crates_BaseColor.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Props_Crates_Normal.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Props_Crates_ORM.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_01_BaseColor_Red.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_01_Normal.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_01_ORM.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_02_BaseColor_Red.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_02_Normal.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_02_ORM.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_03_BaseColor.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_03_Cables.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_03_Normal.png.import'
        'assets/third_party/commercial/models/quaternius/scifi_essentials/gltf/T_Trim_03_ORM.png.import'
        'assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Armabee_Evolved_Atlas_Monsters.png.import'
        'assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Dragon_Evolved_Atlas_Monsters.png.import'
        'assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Ghost_Skull_Atlas_Monsters.png.import'
        'assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Monkroose_Atlas_Monsters.png.import'
        'assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Orc_Skull_Atlas_Monsters.png.import'
        'assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Squidle_Atlas_Monsters.png.import'
        'assets/third_party/commercial/models/quaternius/ultimate_spaceships/gltf/Omen_Omen_Orange.png.import'
        'assets/third_party/commercial/models/quaternius/ultimate_spaceships/gltf/Pancake_Pancake_Orange.png.import'
        'assets/third_party/commercial/models/quaternius/ultimate_spaceships/gltf/Striker_Striker_Orange.png.import'
    )
    return [pscustomobject][ordered]@{
        schema = "SpaceSyndicateCanonicalImportChurnV1"
        expected_count = 57
        path_set_sha256 = "07f42abff08810ffd90a52434907d2b534f9d251cb6f28f0d7ae6c71aa82e92e"
        baseline_map_sha256 = "5cab13bdea7341a8d90feec19c1b0d4a17d286ca5fb7ee7d43445855a8d6bd0f"
        generated_map_sha256 = "e06f20ca88d54b40f7350744814e8f9e2d7714585e2172aed317c51ebca5a315"
        paths = $paths
    }
}

function Test-RunnerJsonIntegralNumber {
    param([object]$Value)
    if ($null -eq $Value -or $Value -is [bool] -or $Value -is [string]) {
        return $false
    }
    return $Value -is [byte] -or $Value -is [sbyte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64] -or $Value -is [uint64]
}

function Get-RunnerRequiredProperty {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "$Context is missing required field '$Name'."
    }
    return $property.Value
}

function Get-RunnerRequiredArrayProperty {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "$Context is missing required field '$Name'."
    }
    if ($property.Value -isnot [System.Array]) {
        throw "$Context field '$Name' is not a JSON array."
    }
    return ,$property.Value
}

function Read-RunnerExactUidAllowlist {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$ExpectedSha256,
        [Parameter(Mandatory = $true)][string]$Worktree,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)][string]$TreeSha
    )
    $absolutePath = (Resolve-Path -LiteralPath $Path).Path
    $worktreePath = [IO.Path]::GetFullPath($Worktree).TrimEnd("\", "/")
    Assert-RunnerPathChainHasNoReparsePoint `
        -Path $worktreePath `
        -Label "Exact-SHA worktree"
    Assert-RunnerPathChainHasNoReparsePoint `
        -Path $absolutePath `
        -Label "Frozen UID allowlist"
    $worktreePrefix = $worktreePath + [IO.Path]::DirectorySeparatorChar
    if ($absolutePath.Equals($worktreePath, [StringComparison]::OrdinalIgnoreCase) `
        -or $absolutePath.StartsWith(
            $worktreePrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw "The frozen UID allowlist must be outside the exact-SHA worktree."
    }
    $bytes = [IO.File]::ReadAllBytes($absolutePath)
    $actualSha256 = Get-RunnerCanonicalSha256Hex -Bytes $bytes
    if ($actualSha256 -cne $ExpectedSha256) {
        throw "The frozen UID allowlist file hash does not match its authority."
    }
    try {
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        $allowlist = $text | ConvertFrom-Json -Depth 40
    } catch {
        throw "The frozen UID allowlist is not strict UTF-8 JSON: $($_.Exception.Message)"
    }
    $schema = Get-RunnerRequiredProperty $allowlist "schema" "UID allowlist"
    $capturedWorktree = [string](Get-RunnerRequiredProperty `
        $allowlist "worktree" "UID allowlist")
    $null = Get-RunnerRequiredProperty `
        $allowlist "captured_at_utc" "UID allowlist"
    $declaredHead = Get-RunnerRequiredProperty $allowlist "final_head_sha" "UID allowlist"
    $declaredTree = Get-RunnerRequiredProperty $allowlist "final_tree_sha" "UID allowlist"
    $baselineSha = Get-RunnerRequiredProperty `
        $allowlist "preimport_baseline_sha256" "UID allowlist"
    $baselineClean = Get-RunnerRequiredProperty `
        $allowlist "preimport_baseline_clean" "UID allowlist"
    $trackedCount = Get-RunnerRequiredProperty `
        $allowlist "tracked_modification_count_at_capture" "UID allowlist"
    $untrackedCount = Get-RunnerRequiredProperty `
        $allowlist "untracked_count_at_capture" "UID allowlist"
    $entryCount = Get-RunnerRequiredProperty `
        $allowlist "uid_entry_count" "UID allowlist"
    $extensions = Get-RunnerRequiredArrayProperty `
        $allowlist "allowed_source_extensions" "UID allowlist"
    $valuesUnique = Get-RunnerRequiredProperty `
        $allowlist "uid_values_unique" "UID allowlist"
    $declaredSetSha = Get-RunnerRequiredProperty `
        $allowlist "uid_entry_set_sha256" "UID allowlist"
    $entriesValue = Get-RunnerRequiredArrayProperty `
        $allowlist "entries" "UID allowlist"
    $capturedWorktreePath = if ([IO.Path]::IsPathFullyQualified($capturedWorktree)) {
        [IO.Path]::GetFullPath($capturedWorktree).TrimEnd("\", "/")
    } else {
        ""
    }
    $topContractIssues = [Collections.Generic.List[string]]::new()
    if ([string]$schema -cne "space_syndicate.v075.formal_generated_uid_allowlist.v1") {
        $topContractIssues.Add("schema")
    }
    if ([string]::IsNullOrWhiteSpace($capturedWorktreePath) `
        -or $capturedWorktreePath.Equals(
            $worktreePath,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        $topContractIssues.Add("controlled_preimport_worktree")
    } else {
        $capturedWorktreePrefix = $capturedWorktreePath + `
            [IO.Path]::DirectorySeparatorChar
        if ($absolutePath.Equals(
                $capturedWorktreePath,
                [StringComparison]::OrdinalIgnoreCase
            ) -or $absolutePath.StartsWith(
                $capturedWorktreePrefix,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            $topContractIssues.Add("allowlist_outside_controlled_preimport_worktree")
        }
    }
    if ([string]$declaredHead -cne $HeadSha) { $topContractIssues.Add("head") }
    if ([string]$declaredTree -cne $TreeSha) { $topContractIssues.Add("tree") }
    if (-not [regex]::IsMatch([string]$baselineSha, '\A[0-9a-f]{64}\z')) {
        $topContractIssues.Add("preimport_baseline_sha256")
    }
    if ($baselineClean -isnot [bool] -or -not [bool]$baselineClean) {
        $topContractIssues.Add("preimport_baseline_clean")
    }
    if (-not (Test-RunnerJsonIntegralNumber $trackedCount) `
        -or [int64]$trackedCount -ne 0) {
        $topContractIssues.Add("tracked_modification_count_at_capture")
    }
    if (-not (Test-RunnerJsonIntegralNumber $untrackedCount)) {
        $topContractIssues.Add("untracked_count_at_capture")
    }
    if (-not (Test-RunnerJsonIntegralNumber $entryCount)) {
        $topContractIssues.Add("uid_entry_count")
    }
    if ($valuesUnique -isnot [bool] -or -not [bool]$valuesUnique) {
        $topContractIssues.Add("uid_values_unique")
    }
    if (-not [regex]::IsMatch([string]$declaredSetSha, '\A[0-9a-f]{64}\z')) {
        $topContractIssues.Add("uid_entry_set_sha256")
    }
    if ($extensions -isnot [Array]) {
        $topContractIssues.Add("allowed_source_extensions")
    }
    if ($entriesValue -isnot [Array]) { $topContractIssues.Add("entries") }
    if ($topContractIssues.Count -ne 0) {
        throw (
            "The frozen UID allowlist top-level contract is invalid: " +
            ($topContractIssues -join ",")
        )
    }
    $extensionRows = [string[]]@($extensions | ForEach-Object { [string]$_ })
    [Array]::Sort($extensionRows, [StringComparer]::Ordinal)
    if ($extensionRows.Count -ne 2 `
        -or $extensionRows[0] -cne ".gd" `
        -or $extensionRows[1] -cne ".gdshader") {
        throw "The frozen UID allowlist source extension set is invalid."
    }
    $entries = @($entriesValue)
    if ([int64]$entryCount -le 0 `
        -or [int64]$entryCount -ne $entries.Count `
        -or [int64]$untrackedCount -ne $entries.Count) {
        throw "The frozen UID allowlist entry counts are inconsistent."
    }
    $pathSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $valueSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $canonicalRows = [Collections.Generic.List[string]]::new()
    $candidates = [Collections.Generic.List[object]]::new()
    $expectedEntryFields = [string[]]@(
        "source_exists", "source_extension", "source_relative_path",
        "source_tracked", "uid_byte_length", "uid_content_sha256",
        "uid_relative_path", "uid_value"
    )
    [Array]::Sort($expectedEntryFields, [StringComparer]::Ordinal)
    foreach ($entry in $entries) {
        $actualEntryFields = [string[]]@(
            $entry.PSObject.Properties.Name | ForEach-Object { [string]$_ }
        )
        [Array]::Sort($actualEntryFields, [StringComparer]::Ordinal)
        if ([string]::Join("`n", $actualEntryFields) `
            -cne [string]::Join("`n", $expectedEntryFields)) {
            throw "A frozen UID allowlist entry has an unexpected field set."
        }
        $uidPath = [string](Get-RunnerRequiredProperty `
            $entry "uid_relative_path" "UID allowlist entry")
        $sourcePath = [string](Get-RunnerRequiredProperty `
            $entry "source_relative_path" "UID allowlist entry")
        $sourceExtension = [string](Get-RunnerRequiredProperty `
            $entry "source_extension" "UID allowlist entry")
        $uidValue = [string](Get-RunnerRequiredProperty `
            $entry "uid_value" "UID allowlist entry")
        $uidSha = [string](Get-RunnerRequiredProperty `
            $entry "uid_content_sha256" "UID allowlist entry")
        $uidLength = Get-RunnerRequiredProperty `
            $entry "uid_byte_length" "UID allowlist entry"
        $sourceExists = Get-RunnerRequiredProperty `
            $entry "source_exists" "UID allowlist entry"
        $sourceTracked = Get-RunnerRequiredProperty `
            $entry "source_tracked" "UID allowlist entry"
        if ([IO.Path]::IsPathRooted($uidPath) -or $uidPath.Contains("\") `
            -or [IO.Path]::IsPathRooted($sourcePath) -or $sourcePath.Contains("\") `
            -or @($uidPath.Split('/') | Where-Object { $_ -eq '..' }).Count -ne 0 `
            -or @($sourcePath.Split('/') | Where-Object { $_ -eq '..' }).Count -ne 0 `
            -or $uidPath -cne "$sourcePath.uid" `
            -or @(".gd", ".gdshader") -cnotcontains $sourceExtension `
            -or [IO.Path]::GetExtension($sourcePath).ToLowerInvariant() `
                -cne $sourceExtension `
            -or -not [regex]::IsMatch($uidValue, '\Auid://[a-z0-9]+\z') `
            -or -not [regex]::IsMatch($uidSha, '\A[0-9a-f]{64}\z') `
            -or -not (Test-RunnerJsonIntegralNumber $uidLength) `
            -or [int64]$uidLength -le 0 `
            -or $sourceExists -isnot [bool] -or -not [bool]$sourceExists `
            -or $sourceTracked -isnot [bool] -or -not [bool]$sourceTracked `
            -or -not $pathSet.Add($uidPath) `
            -or -not $valueSet.Add($uidValue)) {
            throw "A frozen UID allowlist entry failed its exact identity contract."
        }
        $sourceAbsolutePath = Resolve-CleanupChildPath `
            -Root $Worktree `
            -RelativePath $sourcePath
        if (-not (Test-Path -LiteralPath $sourceAbsolutePath -PathType Leaf)) {
            throw "A frozen UID source is missing: $sourcePath"
        }
        $sourceBlobRows = @(Invoke-RunnerGit -Root $Worktree -Arguments @(
            "rev-parse", "--verify", "$HeadSha`:$sourcePath"
        ))
        if ($sourceBlobRows.Count -ne 1 `
            -or -not [regex]::IsMatch(
                $sourceBlobRows[0].Trim(),
                '\A[0-9a-f]{40,64}\z'
            )) {
            throw "A frozen UID source is not tracked at the frozen HEAD: $sourcePath"
        }
        $canonicalRows.Add(
            "$uidPath|$sourcePath|$uidValue|$uidSha|$([int64]$uidLength)"
        )
        $candidates.Add([pscustomobject][ordered]@{
            path = $uidPath
            source_path = $sourcePath
            source_exists = $true
            source_head_blob_sha = $sourceBlobRows[0].Trim()
            source_sha256 = Get-RunnerFileSha256 -Path $sourceAbsolutePath
            uid_value = $uidValue
            uid_content_sha256 = $uidSha
            uid_byte_length = [int64]$uidLength
        })
    }
    $sortedCanonicalRows = [string[]]@($canonicalRows.ToArray())
    [Array]::Sort($sortedCanonicalRows, [StringComparer]::Ordinal)
    $recomputedSetSha = Get-RunnerCanonicalSha256Hex -Bytes (
        [Text.Encoding]::UTF8.GetBytes([string]::Join("`n", $sortedCanonicalRows))
    )
    if ($recomputedSetSha -cne [string]$declaredSetSha) {
        throw "The frozen UID allowlist entry-set hash is invalid."
    }
    return [pscustomobject][ordered]@{
        source_path = $absolutePath
        actual_sha256 = $actualSha256
        bytes = $bytes
        authority = $allowlist
        uid_entry_set_sha256 = $recomputedSetSha
        candidates = @($candidates)
    }
}

function Resolve-CleanupChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    if ([string]::IsNullOrWhiteSpace($RelativePath) `
        -or [IO.Path]::IsPathRooted($RelativePath)) {
        throw "Cleanup path is not worktree-relative: $RelativePath"
    }
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd("\", "/")
    $rootPrefix = $rootPath + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath(
        (Join-Path $rootPath $RelativePath.Replace(
            "/",
            [IO.Path]::DirectorySeparatorChar
        ))
    )
    if (-not $candidate.StartsWith(
        $rootPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Cleanup path escaped the worktree: $RelativePath"
    }
    Assert-RunnerPathChainHasNoReparsePoint `
        -Path $Root `
        -Label "Cleanup worktree"
    Assert-RunnerPathChainHasNoReparsePoint `
        -Path $candidate `
        -Label "Cleanup target"
    return $candidate
}

function Get-RunnerUnexpectedIgnoredUidRows {
    param([Parameter(Mandatory = $true)][string]$Worktree)
    return @(
        Invoke-RunnerGit -Root $Worktree -Arguments @(
            "-c", "core.quotepath=false", "ls-files", "--others",
            "--ignored", "--exclude-standard", "--",
            "*.gd.uid", "*.gdshader.uid"
        ) |
            ForEach-Object { $_.Trim().Replace("\", "/") } |
            Where-Object {
                $_ -and -not $_.StartsWith(
                    ".godot/",
                    [StringComparison]::Ordinal
                ) -and -not $_.StartsWith(
                    ".codex-godot/",
                    [StringComparison]::Ordinal
                )
            }
    )
}

function Get-CleanupImportIdentity {
    param([Parameter(Mandatory = $true)][string]$Path)
    $text = [IO.File]::ReadAllText($Path)
    $values = [ordered]@{}
    foreach ($name in @("importer", "type", "uid", "source_file")) {
        $pattern = '(?m)^' + [regex]::Escape($name) + '="([^"]+)"\s*$'
        $match = [regex]::Match($text, $pattern)
        if (-not $match.Success) {
            throw "Tracked import metadata is missing $name`: $Path"
        }
        $values[$name] = $match.Groups[1].Value
    }
    return [pscustomobject]$values
}

function Write-ImmutableFailureJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )
    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite failure evidence: $Path"
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText(
            $temporaryPath,
            ($Value | ConvertTo-Json -Depth 40),
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::Move($temporaryPath, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Write-ImmutableFailureText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
    )
    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite failure evidence: $Path"
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText(
            $temporaryPath,
            $Value,
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::Move($temporaryPath, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Write-ImmutableFailureBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][byte[]]$Value
    )
    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite failure evidence: $Path"
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllBytes($temporaryPath, $Value)
        [IO.File]::Move($temporaryPath, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Test-IsTopLevelRunbookControlStatement {
    param(
        [Parameter(Mandatory = $true)]
        [Management.Automation.Language.Ast]$Node,
        [Parameter(Mandatory = $true)]
        [Management.Automation.Language.ScriptBlockAst]$Root
    )
    $parent = $Node.Parent
    while ($null -ne $parent -and $parent -ne $Root) {
        if ($parent -is [Management.Automation.Language.ScriptBlockAst]) {
            return $false
        }
        $parent = $parent.Parent
    }
    return $parent -eq $Root
}

function Get-RunbookAstFailures {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Label,
        [int]$BlockIndex = 0
    )
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput(
        $Source,
        [ref]$tokens,
        [ref]$parseErrors
    )
    $failures = [Collections.Generic.List[object]]::new()
    foreach ($parseError in @($parseErrors)) {
        $failures.Add([pscustomobject]@{
            validation_scope = $Label
            block_index = $BlockIndex
            line = $parseError.Extent.StartLineNumber
            kind = "parse_error"
            message = $parseError.Message
        })
    }
    $controlNodes = @($ast.FindAll({
        param($candidate)
        $candidate -is [Management.Automation.Language.ExitStatementAst] `
            -or $candidate -is [Management.Automation.Language.ReturnStatementAst]
    }, $true))
    foreach ($node in $controlNodes) {
        if (Test-IsTopLevelRunbookControlStatement -Node $node -Root $ast) {
            $failures.Add([pscustomobject]@{
                validation_scope = $Label
                block_index = $BlockIndex
                line = $node.Extent.StartLineNumber
                kind = if ($node -is [Management.Automation.Language.ExitStatementAst]) {
                    "top_level_exit"
                } else {
                    "top_level_return"
                }
                message = "Executable runbook blocks may not exit or return from the lifecycle host."
            })
        }
    }
    return [pscustomobject]@{
        ast = $ast
        failures = @($failures)
    }
}

function Get-StrictPowerShellRunbookBlocks {
    param([Parameter(Mandatory = $true)][string]$Path)
    $lines = [IO.File]::ReadAllLines($Path)
    $records = [Collections.Generic.List[object]]::new()
    for ($lineIndex = 0; $lineIndex -lt $lines.Length; $lineIndex += 1) {
        if ($lines[$lineIndex] -notmatch '^```powershell[ \t]*$') { continue }
        $startLine = $lineIndex + 2
        $body = [Collections.Generic.List[string]]::new()
        $lineIndex += 1
        while ($lineIndex -lt $lines.Length `
            -and $lines[$lineIndex] -notmatch '^```[ \t]*$') {
            if ($lines[$lineIndex] -match '^```powershell[ \t]*$') {
                throw "Nested executable PowerShell fence at line $($lineIndex + 1)."
            }
            $body.Add($lines[$lineIndex])
            $lineIndex += 1
        }
        if ($lineIndex -ge $lines.Length) {
            throw "Unterminated executable PowerShell fence beginning at line $startLine."
        }
        $source = ($body -join "`n") + "`n"
        $blockIndex = $records.Count + 1
        $validation = Get-RunbookAstFailures `
            -Source $source `
            -Label "block_$blockIndex" `
            -BlockIndex $blockIndex
        $scriptBlock = if (@($validation.failures).Count -eq 0) {
            [scriptblock]::Create($source)
        } else {
            $null
        }
        $records.Add([pscustomobject]@{
            block_index = $blockIndex
            start_line = $startLine
            end_line = $lineIndex
            source = $source
            ast_failures = @($validation.failures)
            script_block = $scriptBlock
        })
    }
    return @($records)
}

function Resolve-RunnerFailureEvidenceRoot {
    param([string]$Worktree)
    $candidate = Get-RunbookVariableValue "ValidationEvidenceRoot"
    if ($null -eq $candidate) {
        $candidate = Get-RunbookVariableValue "EvidenceRoot"
        if ($null -ne $candidate) {
            $candidate = Join-Path ([string]$candidate) "runbook-failures"
        }
    }
    if ($null -eq $candidate `
        -and -not [string]::IsNullOrWhiteSpace($env:V075_PR90_EVIDENCE_ROOT)) {
        $candidate = Join-Path $env:V075_PR90_EVIDENCE_ROOT "runbook-failures"
    }
    if ($null -eq $candidate) { return $null }
    $resolved = [IO.Path]::GetFullPath([string]$candidate)
    Assert-RunnerPathChainHasNoReparsePoint `
        -Path $resolved `
        -Label "Failure evidence root"
    if (-not [string]::IsNullOrWhiteSpace($Worktree)) {
        $worktreePath = [IO.Path]::GetFullPath($Worktree).TrimEnd("\", "/")
        $worktreePrefix = $worktreePath + [IO.Path]::DirectorySeparatorChar
        if ($resolved.Equals($worktreePath, [StringComparison]::OrdinalIgnoreCase) `
            -or $resolved.StartsWith(
                $worktreePrefix,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            throw "Failure evidence root must remain outside the worktree."
        }
    }
    [IO.Directory]::CreateDirectory($resolved) | Out-Null
    Assert-RunnerPathChainHasNoReparsePoint `
        -Path $resolved `
        -Label "Failure evidence root"
    return $resolved
}

function Get-RunnerOwnedRoleConnection {
    param(
        [Parameter(Mandatory = $true)][string]$Worktree,
        [Parameter(Mandatory = $true)][object]$Baseline,
        [Parameter(Mandatory = $true)][DateTimeOffset]$ExecutionStartedAt,
        [object]$LaunchResult
    )
    $connectionPath = Join-Path $Worktree ".codex-godot\connection.json"
    if (-not (Test-Path -LiteralPath $connectionPath -PathType Leaf)) {
        if ($null -ne $LaunchResult) {
            $lifecycleClosed = Get-RunbookVariableValue "RoleLifecycleClosed"
            $closedStopResult = Get-RunbookVariableValue "RoleLifecycleStopResult"
            if ($lifecycleClosed -is [bool] -and [bool]$lifecycleClosed `
                -and $null -ne $closedStopResult) {
                $requiredClosedBooleans = [ordered]@{
                    stopped = $true
                    already_exited = $false
                    identity_verified = $true
                    normal_close_requested = $true
                    forced_stop = $false
                }
                foreach ($field in $requiredClosedBooleans.Keys) {
                    $property = $closedStopResult.PSObject.Properties[$field]
                    if ($null -eq $property `
                        -or $property.Value -isnot [bool] `
                        -or [bool]$property.Value -ne [bool]$requiredClosedBooleans[$field]) {
                        throw "Closed role lifecycle proof is invalid: $field"
                    }
                }
                foreach ($field in @("process_count_after", "endpoint_count_after")) {
                    $property = $closedStopResult.PSObject.Properties[$field]
                    if ($null -eq $property `
                        -or -not (Test-RunnerJsonIntegralNumber $property.Value) `
                        -or [int64]$property.Value -ne 0) {
                        throw "Closed role lifecycle count is invalid: $field"
                    }
                }
                $launchPidProperty = $LaunchResult.PSObject.Properties["pid"]
                if ($null -eq $launchPidProperty `
                    -or -not (Test-RunnerJsonIntegralNumber $launchPidProperty.Value) `
                    -or [int64]$launchPidProperty.Value -le 0) {
                    throw "Closed role lifecycle launch PID is invalid."
                }
                $closedStopPidProperty = `
                    $closedStopResult.PSObject.Properties["pid"]
                if ($null -eq $closedStopPidProperty `
                    -or -not (Test-RunnerJsonIntegralNumber `
                        $closedStopPidProperty.Value) `
                    -or [int64]$closedStopPidProperty.Value `
                        -ne [int64]$launchPidProperty.Value) {
                    throw "Closed role lifecycle stop PID does not match launch."
                }
                $closedProcess = Get-Process `
                    -Id ([int]$launchPidProperty.Value) `
                    -ErrorAction SilentlyContinue
                if ($null -ne $closedProcess -and -not $closedProcess.HasExited) {
                    throw "Closed role lifecycle PID is still running or was reused."
                }
                $closedListeners = @(
                    Get-NetTCPConnection -State Listen -ErrorAction Stop |
                        Where-Object { [int]$_.LocalPort -eq 7576 }
                )
                if ($closedListeners.Count -ne 0) {
                    throw "Closed role lifecycle endpoint is still listening."
                }
                return $null
            }
            throw (
                "The runbook recorded a launched role, but its role-local " +
                "connection metadata is missing."
            )
        }
        return $null
    }
    $connectionSha256 = Get-RunnerFileSha256 $connectionPath
    $connection = [IO.File]::ReadAllText($connectionPath) | ConvertFrom-Json
    $reportedWorktree = [IO.Path]::GetFullPath(
        ([string]$connection.worktree).Replace("/", "\")
    ).TrimEnd("\", "/")
    $expectedWorktree = [IO.Path]::GetFullPath($Worktree).TrimEnd("\", "/")
    if (-not $reportedWorktree.Equals(
        $expectedWorktree,
        [StringComparison]::OrdinalIgnoreCase
    ) -or [string]$connection.role -cne "A" `
        -or [int]$connection.port -ne 7576 `
        -or [int]$connection.pid -le 0 `
        -or [int]$connection.endpoint_owner_pid -ne [int]$connection.pid) {
        throw "Role-local connection metadata is not the exact Role A lifecycle identity."
    }
    $ownershipSource = ""
    if ($null -ne $LaunchResult) {
        if ([int]$LaunchResult.pid -ne [int]$connection.pid `
            -or [int]$LaunchResult.endpoint_owner_pid -ne [int]$connection.pid `
            -or [string]$LaunchResult.role -cne [string]$connection.role `
            -or [int]$LaunchResult.port -ne [int]$connection.port `
            -or [string]$LaunchResult.process_start_time_utc `
                -cne [string]$connection.process_start_time_utc `
            -or -not ([IO.Path]::GetFullPath(
                [string]$LaunchResult.godot_path
            )).Equals(
                [IO.Path]::GetFullPath([string]$connection.godot_path),
                [StringComparison]::OrdinalIgnoreCase
            ) `
            -or -not ([IO.Path]::GetFullPath(
                ([string]$LaunchResult.worktree).Replace("/", "\")
            ).TrimEnd("\", "/")).Equals(
                $expectedWorktree,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            throw "Launch result and role-local connection metadata do not match."
        }
        $ownershipSource = "launch_result"
    } else {
        if ([bool]$Baseline.connection_exists `
            -and [string]$Baseline.connection_sha256 -ceq $connectionSha256) {
            return $null
        }
        $processStart = [DateTimeOffset]::Parse(
            [string]$connection.process_start_time_utc,
            [Globalization.CultureInfo]::InvariantCulture
        )
        if ($processStart -lt $ExecutionStartedAt.AddSeconds(-2)) {
            return $null
        }
        $ownershipSource = "new_connection_since_execution_start"
    }
    return [pscustomobject]@{
        ownership_source = $ownershipSource
        connection_path = $connectionPath
        connection_sha256 = $connectionSha256
        role = [string]$connection.role
        worktree = $expectedWorktree
        pid = [int]$connection.pid
        process_start_time_utc = [string]$connection.process_start_time_utc
        godot_path = [string]$connection.godot_path
        port = [int]$connection.port
        endpoint_owner_pid = [int]$connection.endpoint_owner_pid
    }
}

function Invoke-RunnerTransientFailureCleanup {
    param(
        [Parameter(Mandatory = $true)][string]$Worktree,
        [string]$EvidenceRoot,
        [Parameter(Mandatory = $true)][string]$FailureId,
        [string]$Context = "failure_finalizer",
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [Collections.Generic.List[string]]$Issues
    )
    $result = [ordered]@{
        observation_only = $true
        observation_only_reasons = @()
        authority_path = ""
        authority_sha256 = ""
        current_head = ""
        current_tree = ""
        import_state = "UNCLASSIFIED"
        uid_state = "UNCLASSIFIED"
        missing_uid_paths = @()
        unexpected_ignored_uid_paths = @()
        cached_drift = @()
        safe_import_cleanup = @()
        safe_uid_cleanup = @()
        unsafe_allowlisted = @()
        unknown_tracked_drift = @()
        unknown_untracked_drift = @()
        import_diff_evidence_path = ""
        observation_evidence_path = ""
        final_status = @()
        final_head = ""
        final_tree = ""
        final_tracked_drift = @()
        final_untracked_drift = @()
        final_unexpected_ignored_uid_paths = @()
        cleanup_green = $false
    }
    $observationOnlyReasons = [Collections.Generic.List[string]]::new()
    $unsafeAllowlisted = [Collections.Generic.List[object]]::new()
    $safeImportRows = [Collections.Generic.List[object]]::new()
    $safeUidRows = [Collections.Generic.List[object]]::new()
    $authorityImportMap = [Collections.Generic.Dictionary[string,object]]::new(
        [StringComparer]::Ordinal
    )
    $authorityUidMap = [Collections.Generic.Dictionary[string,object]]::new(
        [StringComparer]::Ordinal
    )
    $frozenHead = [string](Get-RunbookVariableValue "HeadSha")
    $frozenTree = [string](Get-RunbookVariableValue "TreeSha")
    $authorityPath = [string](
        Get-RunbookVariableValue "TransientArtifactAuthorityPath"
    )
    $expectedAuthoritySha = [string](
        Get-RunbookVariableValue "TransientArtifactAuthoritySha256"
    )
    $inMemoryImportMap = Get-RunbookVariableValue "ImportCandidateMap"
    $inMemoryUidMap = Get-RunbookVariableValue "UidCandidateMap"
    $result.authority_path = $authorityPath
    $result.authority_sha256 = $expectedAuthoritySha

    $currentHeadRows = @(Invoke-RunnerGit -Root $Worktree -Arguments @("rev-parse", "HEAD"))
    $currentTreeRows = @(Invoke-RunnerGit -Root $Worktree -Arguments @("rev-parse", "HEAD^{tree}"))
    if ($currentHeadRows.Count -eq 1) { $result.current_head = $currentHeadRows[0].Trim() }
    if ($currentTreeRows.Count -eq 1) { $result.current_tree = $currentTreeRows[0].Trim() }
    if ([string]::IsNullOrWhiteSpace($frozenHead) `
        -or [string]::IsNullOrWhiteSpace($frozenTree) `
        -or $result.current_head -cne $frozenHead `
        -or $result.current_tree -cne $frozenTree) {
        $observationOnlyReasons.Add("frozen_head_or_tree_changed_or_unavailable")
    }
    $cachedRows = @(
        Invoke-RunnerGit -Root $Worktree -Arguments @(
            "-c", "core.quotepath=false", "diff", "--cached", "--name-only"
        ) | ForEach-Object { $_.Trim().Replace("\", "/") } | Where-Object { $_ }
    )
    $result.cached_drift = @($cachedRows)
    if ($cachedRows.Count -ne 0) {
        $observationOnlyReasons.Add("git_index_changed")
    }
    $authority = $null
    if ([string]::IsNullOrWhiteSpace($authorityPath) `
        -or [string]::IsNullOrWhiteSpace($expectedAuthoritySha) `
        -or -not (Test-Path -LiteralPath $authorityPath -PathType Leaf)) {
        $observationOnlyReasons.Add("transient_authority_unavailable")
    } else {
        $actualAuthoritySha = Get-RunnerFileSha256 $authorityPath
        if ($actualAuthoritySha -cne $expectedAuthoritySha) {
            $observationOnlyReasons.Add("transient_authority_hash_changed")
        } else {
            $authority = [IO.File]::ReadAllText($authorityPath) | ConvertFrom-Json
            if ([string]$authority.schema `
                -cne "SpaceSyndicateExactShaTransientArtifactAuthorityV2" `
                -or [string]$authority.head_sha -cne $frozenHead `
                -or [string]$authority.tree_sha -cne $frozenTree `
                -or -not ([IO.Path]::GetFullPath(
                    ([string]$authority.worktree).Replace("/", "\")
                ).TrimEnd("\", "/")).Equals(
                    [IO.Path]::GetFullPath($Worktree).TrimEnd("\", "/"),
                    [StringComparison]::OrdinalIgnoreCase
                )) {
                $observationOnlyReasons.Add("transient_authority_identity_changed")
            } else {
                $canonicalImportAuthority = Get-RunnerCanonicalImportAuthority
                $canonicalImportPaths = [string[]]@(
                    $canonicalImportAuthority.paths
                )
                $canonicalPathSetSha = Get-RunnerCanonicalPathSetSha256 `
                    -Paths $canonicalImportPaths
                $uidEvidencePath = [string](
                    $authority.generated_uid_allowlist_evidence_path
                )
                if ([string]$authority.canonical_import_schema `
                        -cne [string]$canonicalImportAuthority.schema `
                    -or [int]$authority.import_candidate_count `
                        -ne [int]$canonicalImportAuthority.expected_count `
                    -or [string]$authority.canonical_import_path_set_sha256 `
                        -cne $canonicalPathSetSha `
                    -or [string]$authority.canonical_import_baseline_map_sha256 `
                        -cne [string]$canonicalImportAuthority.baseline_map_sha256 `
                    -or [string]$authority.canonical_import_generated_map_sha256 `
                        -cne [string]$canonicalImportAuthority.generated_map_sha256 `
                    -or [string]::IsNullOrWhiteSpace($uidEvidencePath) `
                    -or -not (Test-Path -LiteralPath $uidEvidencePath -PathType Leaf) `
                    -or (Get-RunnerFileSha256 $uidEvidencePath) `
                        -cne [string]$authority.generated_uid_allowlist_evidence_sha256 `
                    -or [string]$authority.generated_uid_allowlist_source_sha256 `
                        -cne [string]$authority.generated_uid_allowlist_evidence_sha256) {
                    $observationOnlyReasons.Add(
                        "transient_authority_closed_set_contract_changed"
                    )
                }
                foreach ($candidate in @($authority.import_candidates)) {
                    $authorityImportMap.Add([string]$candidate.path, $candidate)
                }
                foreach ($candidate in @($authority.uid_candidates)) {
                    $authorityUidMap.Add([string]$candidate.path, $candidate)
                }
                if ($null -eq $inMemoryImportMap `
                    -or $null -eq $inMemoryUidMap `
                    -or [int]$authority.import_candidate_count -ne $authorityImportMap.Count `
                    -or [int]$authority.uid_candidate_count -ne $authorityUidMap.Count `
                    -or $inMemoryImportMap.Count -ne $authorityImportMap.Count `
                    -or $inMemoryUidMap.Count -ne $authorityUidMap.Count) {
                    $observationOnlyReasons.Add("transient_authority_map_mismatch")
                } else {
                    foreach ($path in $authorityImportMap.Keys) {
                        if (-not $inMemoryImportMap.ContainsKey($path)) {
                            $observationOnlyReasons.Add("transient_authority_map_mismatch")
                            break
                        }
                    }
                    foreach ($path in $authorityUidMap.Keys) {
                        if (-not $inMemoryUidMap.ContainsKey($path)) {
                            $observationOnlyReasons.Add("transient_authority_map_mismatch")
                            break
                        }
                    }
                    $authorityImportRows = [string[]]@(
                        $authorityImportMap.Values | ForEach-Object {
                            "{0}|{1}|{2}" -f @(
                                [string]$_.path,
                                [string]$_.head_blob_sha,
                                [string]$_.baseline_content_sha256
                            )
                        }
                    )
                    $memoryImportRows = [string[]]@(
                        $inMemoryImportMap.Values | ForEach-Object {
                            "{0}|{1}|{2}" -f @(
                                [string]$_.path,
                                [string]$_.head_blob_sha,
                                [string]$_.baseline_content_sha256
                            )
                        }
                    )
                    [Array]::Sort($authorityImportRows, [StringComparer]::Ordinal)
                    [Array]::Sort($memoryImportRows, [StringComparer]::Ordinal)
                    $authorityUidRows = [string[]]@(
                        $authorityUidMap.Values | ForEach-Object {
                            "{0}|{1}|{2}|{3}|{4}|{5}|{6}" -f @(
                                [string]$_.path,
                                [string]$_.source_path,
                                [string]$_.source_head_blob_sha,
                                [string]$_.source_sha256,
                                [string]$_.uid_value,
                                [string]$_.uid_content_sha256,
                                [int64]$_.uid_byte_length
                            )
                        }
                    )
                    $memoryUidRows = [string[]]@(
                        $inMemoryUidMap.Values | ForEach-Object {
                            "{0}|{1}|{2}|{3}|{4}|{5}|{6}" -f @(
                                [string]$_.path,
                                [string]$_.source_path,
                                [string]$_.source_head_blob_sha,
                                [string]$_.source_sha256,
                                [string]$_.uid_value,
                                [string]$_.uid_content_sha256,
                                [int64]$_.uid_byte_length
                            )
                        }
                    )
                    [Array]::Sort($authorityUidRows, [StringComparer]::Ordinal)
                    [Array]::Sort($memoryUidRows, [StringComparer]::Ordinal)
                    if ([string]::Join("`n", $authorityImportRows) `
                            -cne [string]::Join("`n", $memoryImportRows) `
                        -or [string]::Join("`n", $authorityUidRows) `
                            -cne [string]::Join("`n", $memoryUidRows)) {
                        $observationOnlyReasons.Add(
                            "transient_authority_map_content_mismatch"
                        )
                    }
                }
            }
        }
    }

    if ($Issues.Count -ne 0) {
        $observationOnlyReasons.Add("prior_failure_finalizer_issue")
    }
    $trackedRows = @(
        Invoke-RunnerGit -Root $Worktree -Arguments @(
            "-c", "core.quotepath=false", "diff", "--no-renames",
            "--name-only", "HEAD", "--"
        ) | ForEach-Object { $_.Trim().Replace("\", "/") } | Where-Object { $_ }
    )
    $unknownTracked = @(
        $trackedRows | Where-Object { -not $authorityImportMap.ContainsKey($_) }
    )
    $result.unknown_tracked_drift = @($unknownTracked)
    $canonicalImportAuthority = Get-RunnerCanonicalImportAuthority
    $canonicalImportPaths = [string[]]@($canonicalImportAuthority.paths)
    $importState = "HEAD_CLEAN"
    if ($trackedRows.Count -eq 0) {
        try {
            $cleanMapSha = Get-RunnerCanonicalFileMapSha256 `
                -Root $Worktree `
                -Paths $canonicalImportPaths
            if ($cleanMapSha -cne [string]$canonicalImportAuthority.baseline_map_sha256) {
                throw "canonical baseline map changed without reported drift"
            }
        } catch {
            $importState = "INVALID_PARTIAL_UNKNOWN_OR_TAMPERED"
            $observationOnlyReasons.Add("canonical_import_baseline_invalid")
            $unsafeAllowlisted.Add([pscustomobject]@{
                path = "<canonical-import-set>"
                kind = "tracked_import"
                reason = $_.Exception.Message
            })
        }
    } else {
        try {
            if ($unknownTracked.Count -ne 0 `
                -or $trackedRows.Count -ne [int]$canonicalImportAuthority.expected_count `
                -or (Get-RunnerCanonicalPathSetSha256 -Paths $trackedRows) `
                    -cne [string]$canonicalImportAuthority.path_set_sha256) {
                throw "tracked drift is not the complete canonical 57-path set"
            }
            $generatedMapSha = Get-RunnerCanonicalFileMapSha256 `
                -Root $Worktree `
                -Paths $canonicalImportPaths
            if ($generatedMapSha `
                -cne [string]$canonicalImportAuthority.generated_map_sha256) {
                throw "tracked import bytes are not the canonical generated state"
            }
            foreach ($relativePath in $canonicalImportPaths) {
                $candidate = $authorityImportMap[$relativePath]
                $headBlobRows = @(Invoke-RunnerGit -Root $Worktree -Arguments @(
                    "rev-parse", "--verify", "$frozenHead`:$relativePath"
                ))
                $absolutePath = Resolve-CleanupChildPath `
                    -Root $Worktree `
                    -RelativePath $relativePath
                if ($null -eq $candidate `
                    -or $headBlobRows.Count -ne 1 `
                    -or $headBlobRows[0].Trim() `
                        -cne [string]$candidate.head_blob_sha) {
                    throw "canonical import HEAD identity changed: $relativePath"
                }
                $safeImportRows.Add([pscustomobject]@{
                    path = $relativePath
                    before_sha256 = [string]$candidate.baseline_content_sha256
                    observed_sha256 = Get-RunnerFileSha256 $absolutePath
                    candidate = $candidate
                })
            }
            $importState = "CANONICAL_GENERATED_57"
        } catch {
            $importState = "INVALID_PARTIAL_UNKNOWN_OR_TAMPERED"
            $observationOnlyReasons.Add("canonical_import_state_invalid")
            $unsafeAllowlisted.Add([pscustomobject]@{
                path = "<canonical-import-set>"
                kind = "tracked_import"
                reason = $_.Exception.Message
            })
            $safeImportRows.Clear()
        }
    }
    if ($unknownTracked.Count -ne 0) {
        $observationOnlyReasons.Add("unknown_tracked_drift")
    }

    $untrackedRows = @(
        Invoke-RunnerGit -Root $Worktree -Arguments @(
            "-c", "core.quotepath=false", "ls-files",
            "--others", "--exclude-standard"
        ) | ForEach-Object { $_.Trim().Replace("\", "/") } | Where-Object { $_ }
    )
    $unknownUntracked = @(
        $untrackedRows | Where-Object { -not $authorityUidMap.ContainsKey($_) }
    )
    $unexpectedIgnoredUidRows = @(
        Get-RunnerUnexpectedIgnoredUidRows -Worktree $Worktree
    )
    $result.unexpected_ignored_uid_paths = @($unexpectedIgnoredUidRows)
    $observedUidPaths = [string[]]@(
        $untrackedRows | Where-Object { $authorityUidMap.ContainsKey($_) }
    )
    $missingUidPaths = [string[]]@(
        $authorityUidMap.Keys | Where-Object { $untrackedRows -cnotcontains $_ }
    )
    $result.unknown_untracked_drift = @($unknownUntracked)
    $uidState = "ABSENT"
    if ($untrackedRows.Count -gt 0) {
        if ($unknownUntracked.Count -ne 0 `
            -or $observedUidPaths.Count -ne $authorityUidMap.Count `
            -or $missingUidPaths.Count -ne 0) {
            $uidState = "INVALID_PARTIAL_UNKNOWN_OR_TAMPERED"
            $observationOnlyReasons.Add("generated_uid_set_not_exact")
        } else {
            $validUidRows = [Collections.Generic.List[object]]::new()
            foreach ($relativePath in $observedUidPaths) {
                $candidate = $authorityUidMap[$relativePath]
                try {
                    $absoluteUidPath = Resolve-CleanupChildPath `
                        -Root $Worktree `
                        -RelativePath $relativePath
                    $absoluteSourcePath = Resolve-CleanupChildPath `
                        -Root $Worktree `
                        -RelativePath ([string]$candidate.source_path)
                    if (-not (Test-Path -LiteralPath $absoluteUidPath -PathType Leaf) `
                        -or -not (Test-Path -LiteralPath $absoluteSourcePath -PathType Leaf)) {
                        throw "UID or frozen source is missing"
                    }
                    $sourceBlobRows = @(Invoke-RunnerGit -Root $Worktree -Arguments @(
                        "rev-parse", "--verify",
                        "$frozenHead`:$([string]$candidate.source_path)"
                    ))
                    if ($sourceBlobRows.Count -ne 1 `
                        -or $sourceBlobRows[0].Trim() `
                            -cne [string]$candidate.source_head_blob_sha `
                        -or (Get-RunnerFileSha256 $absoluteSourcePath) `
                            -cne [string]$candidate.source_sha256) {
                        throw "generated UID source identity changed"
                    }
                    $uidBytes = [IO.File]::ReadAllBytes($absoluteUidPath)
                    $uidSha = Get-RunnerCanonicalSha256Hex -Bytes $uidBytes
                    try {
                        $uidText = [Text.UTF8Encoding]::new($false, $true).GetString(
                            $uidBytes
                        )
                    } catch {
                        throw "generated UID is not strict UTF-8"
                    }
                    if (-not [regex]::IsMatch(
                            $uidText,
                            '\Auid://[a-z0-9]+(?:\r?\n)?\z'
                        ) `
                        -or $uidText.TrimEnd([char[]]@("`r", "`n")) `
                            -cne [string]$candidate.uid_value `
                        -or $uidSha -cne [string]$candidate.uid_content_sha256 `
                        -or [int64]$uidBytes.Length `
                            -ne [int64]$candidate.uid_byte_length) {
                        throw "generated UID value/hash/length differs from authority"
                    }
                    $validUidRows.Add([pscustomobject]@{
                        path = $relativePath
                        source_path = [string]$candidate.source_path
                        uid_value = [string]$candidate.uid_value
                        uid_sha256 = $uidSha
                        uid_byte_length = [int64]$uidBytes.Length
                        absolute_path = $absoluteUidPath
                    })
                } catch {
                    $unsafeAllowlisted.Add([pscustomobject]@{
                        path = $relativePath
                        kind = "generated_uid"
                        reason = $_.Exception.Message
                    })
                }
            }
            if ($unsafeAllowlisted.Count -eq 0 `
                -and $validUidRows.Count -eq $authorityUidMap.Count) {
                foreach ($row in $validUidRows) { $safeUidRows.Add($row) }
                $uidState = "EXACT_EXTERNAL_ALLOWLIST"
            } else {
                $uidState = "INVALID_PARTIAL_UNKNOWN_OR_TAMPERED"
                $observationOnlyReasons.Add("generated_uid_content_invalid")
            }
        }
    }
    if ($unknownUntracked.Count -ne 0) {
        $observationOnlyReasons.Add("unknown_untracked_drift")
    }
    if ($unexpectedIgnoredUidRows.Count -ne 0) {
        $observationOnlyReasons.Add("unexpected_ignored_uid_drift")
    }
    if ($unsafeAllowlisted.Count -ne 0) {
        $observationOnlyReasons.Add("unsafe_allowlisted_drift")
    }
    $result.import_state = $importState
    $result.uid_state = $uidState
    $result.missing_uid_paths = @($missingUidPaths)

    $allowlistedImportDrift = @(
        $trackedRows | Where-Object { $authorityImportMap.ContainsKey($_) }
    )
    $importDiffText = ""
    if ($allowlistedImportDrift.Count -gt 0) {
        $diffArguments = @(
            "-C", $Worktree, "-c", "core.quotepath=false",
            "diff", "--binary", "--"
        ) + @($allowlistedImportDrift)
        $importDiffText = @(& git @diffArguments) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            $observationOnlyReasons.Add("allowlisted_import_diff_capture_failed")
        }
    }
    $importDiffPath = ""
    $observationPath = ""
    $uidEvidenceRows = [Collections.Generic.List[object]]::new()
    if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        $observationOnlyReasons.Add("failure_evidence_root_unavailable")
    } else {
        try {
            $importDiffPath = Join-Path `
                $EvidenceRoot `
                "$FailureId-transient-import-diff.patch"
            Write-ImmutableFailureText -Path $importDiffPath -Value $importDiffText
            $uidEvidenceRoot = Join-Path $EvidenceRoot "$FailureId-uid-evidence"
            foreach ($relativePath in @(
                $untrackedRows | Where-Object { $authorityUidMap.ContainsKey($_) }
            )) {
                $absoluteUidPath = Resolve-CleanupChildPath `
                    -Root $Worktree `
                    -RelativePath $relativePath
                if (-not (Test-Path -LiteralPath $absoluteUidPath -PathType Leaf)) {
                    continue
                }
                $bytes = [IO.File]::ReadAllBytes($absoluteUidPath)
                $pathHash = Get-RunnerCanonicalSha256Hex -Bytes (
                    [Text.UTF8Encoding]::new($false, $true).GetBytes($relativePath)
                )
                $copyPath = Join-Path $uidEvidenceRoot "$pathHash.uid.bin"
                Write-ImmutableFailureBytes -Path $copyPath -Value $bytes
                $uidEvidenceRows.Add([pscustomobject]@{
                    path = $relativePath
                    evidence_path = $copyPath
                    sha256 = Get-RunnerFileSha256 $copyPath
                    byte_count = $bytes.Length
                })
            }
            $observationPath = Join-Path `
                $EvidenceRoot `
                "$FailureId-transient-observation.json"
            Write-ImmutableFailureJson -Path $observationPath -Value ([ordered]@{
                schema = "SpaceSyndicateV075McpRunbookTransientObservationV2"
                context = $Context
                observed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
                frozen_head = $frozenHead
                frozen_tree = $frozenTree
                current_head = $result.current_head
                current_tree = $result.current_tree
                authority_path = $authorityPath
                authority_sha256 = $expectedAuthoritySha
                observation_only_reasons = @($observationOnlyReasons)
                cached_drift = @($cachedRows)
                canonical_import_state = $importState
                generated_uid_state = $uidState
                generated_uid_missing_count = $missingUidPaths.Count
                generated_uid_missing_paths = @($missingUidPaths)
                safe_import_candidates = @($safeImportRows)
                safe_uid_candidates = @($safeUidRows)
                unsafe_allowlisted = @($unsafeAllowlisted)
                unknown_tracked_drift = @($unknownTracked)
                unknown_untracked_drift = @($unknownUntracked)
                unexpected_ignored_uid_paths = @($unexpectedIgnoredUidRows)
                import_diff_path = $importDiffPath
                uid_evidence = @($uidEvidenceRows)
            })
        } catch {
            $observationOnlyReasons.Add("transient_observation_evidence_write_failed")
            $Issues.Add("Transient observation evidence write failed: $($_.Exception.Message)")
        }
    }

    $result.observation_only = $observationOnlyReasons.Count -ne 0
    $result.observation_only_reasons = @($observationOnlyReasons)
    $result.import_diff_evidence_path = $importDiffPath
    $result.observation_evidence_path = $observationPath
    $cleanupMutationFailed = $false
    if (-not $result.observation_only) {
        if ($safeImportRows.Count -gt 0) {
            try {
                $restoreArguments = @(
                    "-C", $Worktree, "restore", "--source=$frozenHead",
                    "--worktree", "--"
                ) + @($safeImportRows | ForEach-Object { [string]$_.path })
                & git @restoreArguments
                if ($LASTEXITCODE -ne 0) {
                    throw "git restore failed"
                }
                foreach ($row in $safeImportRows) {
                    $restoredPath = Resolve-CleanupChildPath `
                        -Root $Worktree `
                        -RelativePath ([string]$row.path)
                    if ((Get-RunnerFileSha256 $restoredPath) `
                        -cne [string]$row.before_sha256) {
                        throw "restored import hash differs: $($row.path)"
                    }
                }
                if ((Get-RunnerCanonicalFileMapSha256 `
                        -Root $Worktree `
                        -Paths ([string[]]@($canonicalImportAuthority.paths))) `
                    -cne [string]$canonicalImportAuthority.baseline_map_sha256) {
                    throw "restored canonical import map differs from HEAD baseline"
                }
                $result.safe_import_cleanup = @(
                    $safeImportRows | ForEach-Object { [string]$_.path }
                )
            } catch {
                $cleanupMutationFailed = $true
                $Issues.Add("Safe import cleanup failed: $($_.Exception.Message)")
            }
        }
        if (-not $cleanupMutationFailed) {
            foreach ($row in $safeUidRows) {
                try {
                    Remove-Item -LiteralPath ([string]$row.absolute_path) -Force
                    if (Test-Path -LiteralPath ([string]$row.absolute_path)) {
                        throw "exact UID path remains after removal"
                    }
                    $result.safe_uid_cleanup += [string]$row.path
                } catch {
                    $cleanupMutationFailed = $true
                    $Issues.Add(
                        "Safe UID cleanup failed ($($row.path)): $($_.Exception.Message)"
                    )
                    break
                }
            }
        }
        foreach ($uidPath in $authorityUidMap.Keys) {
            $uidAbsolutePath = Resolve-CleanupChildPath `
                -Root $Worktree `
                -RelativePath $uidPath
            if (Test-Path -LiteralPath $uidAbsolutePath) {
                $Issues.Add("Authorized UID remains after exact-set cleanup: $uidPath")
            }
        }
    }
    $result.unsafe_allowlisted = @($unsafeAllowlisted)
    if ($unsafeAllowlisted.Count -ne 0) {
        $Issues.Add("Unsafe allowlisted drift was preserved and remains acceptance-red.")
    }
    if ($unknownTracked.Count -ne 0) {
        $Issues.Add("Unknown tracked drift was preserved and remains acceptance-red.")
    }
    if ($unknownUntracked.Count -ne 0) {
        $Issues.Add("Unknown untracked drift was preserved and remains acceptance-red.")
    }
    if ($unexpectedIgnoredUidRows.Count -ne 0) {
        $Issues.Add("Unexpected ignored UID drift was preserved and remains acceptance-red.")
    }
    if ($result.observation_only) {
        $Issues.Add(
            "Transient cleanup was observation-only: $($observationOnlyReasons -join ',')"
        )
    }
    $result.final_status = @(
        Invoke-RunnerGit -Root $Worktree -Arguments @(
            "status", "--porcelain=v1", "--untracked-files=all"
        )
    )
    $finalHeadRows = @(
        Invoke-RunnerGit -Root $Worktree -Arguments @("rev-parse", "HEAD")
    )
    $finalTreeRows = @(
        Invoke-RunnerGit -Root $Worktree -Arguments @("rev-parse", "HEAD^{tree}")
    )
    $result.final_head = if ($finalHeadRows.Count -eq 1) {
        $finalHeadRows[0].Trim()
    } else { "" }
    $result.final_tree = if ($finalTreeRows.Count -eq 1) {
        $finalTreeRows[0].Trim()
    } else { "" }
    $result.final_tracked_drift = @(
        Invoke-RunnerGit -Root $Worktree -Arguments @(
            "-c", "core.quotepath=false", "diff", "--no-renames",
            "--name-only", "HEAD", "--"
        ) | ForEach-Object { $_.Trim().Replace("\", "/") } |
            Where-Object { $_ }
    )
    $result.final_untracked_drift = @(
        Invoke-RunnerGit -Root $Worktree -Arguments @(
            "-c", "core.quotepath=false", "ls-files", "--others",
            "--exclude-standard"
        ) | ForEach-Object { $_.Trim().Replace("\", "/") } |
            Where-Object { $_ }
    )
    $finalUnexpectedIgnoredUidRows = @(
        Get-RunnerUnexpectedIgnoredUidRows -Worktree $Worktree
    )
    $result.final_unexpected_ignored_uid_paths = @(
        $finalUnexpectedIgnoredUidRows
    )
    $expectedImportCleanupCount = if (
        $importState -ceq "CANONICAL_GENERATED_57"
    ) { [int]$canonicalImportAuthority.expected_count } else { 0 }
    $expectedUidCleanupCount = if (
        $uidState -ceq "EXACT_EXTERNAL_ALLOWLIST"
    ) { $authorityUidMap.Count } else { 0 }
    $postCleanupIdentityGreen = `
        $result.final_head -ceq $frozenHead `
        -and $result.final_tree -ceq $frozenTree `
        -and $result.final_tracked_drift.Count -eq 0 `
        -and $result.final_untracked_drift.Count -eq 0 `
        -and $result.final_status.Count -eq 0 `
        -and $finalUnexpectedIgnoredUidRows.Count -eq 0 `
        -and $result.safe_import_cleanup.Count -eq $expectedImportCleanupCount `
        -and $result.safe_uid_cleanup.Count -eq $expectedUidCleanupCount
    if (-not $result.observation_only `
        -and ($cleanupMutationFailed -or -not $postCleanupIdentityGreen)) {
        $Issues.Add("Transient cleanup did not restore an exact clean worktree.")
    }
    $result.cleanup_green = -not $result.observation_only `
        -and -not $cleanupMutationFailed `
        -and $postCleanupIdentityGreen
    return [pscustomobject]$result
}

$resolvedRunbook = (Resolve-Path -LiteralPath $RunbookPath).Path
$runbookDirectory = Split-Path -Parent $resolvedRunbook
$gitRootRows = @(& git -C $runbookDirectory rev-parse --show-toplevel)
if ($LASTEXITCODE -ne 0 -or $gitRootRows.Count -ne 1) {
    throw "Runbook is not inside one Git worktree."
}
$gitRoot = [IO.Path]::GetFullPath($gitRootRows[0].Trim()).TrimEnd("\", "/")
$gitRootPrefix = $gitRoot + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedRunbook.StartsWith(
    $gitRootPrefix,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Runbook path escaped the resolved Git worktree."
}
$runbookRelativePath = [IO.Path]::GetRelativePath(
    $gitRoot,
    $resolvedRunbook
).Replace("\", "/")
$trackedRows = @(
    Invoke-RunnerGit -Root $gitRoot -Arguments @(
        "ls-files", "--error-unmatch", "--", $runbookRelativePath
    )
)
if ($trackedRows.Count -ne 1 -or $trackedRows[0].Trim() -cne $runbookRelativePath) {
    throw "Runbook is not one exact tracked Git path: $runbookRelativePath"
}
$headBlobRows = @(
    Invoke-RunnerGit -Root $gitRoot -Arguments @(
        "rev-parse", "--verify", "HEAD:$runbookRelativePath"
    )
)
$workingBlobRows = @(
    Invoke-RunnerGit -Root $gitRoot -Arguments @(
        "hash-object", "--path=$runbookRelativePath", "--", $resolvedRunbook
    )
)
if ($headBlobRows.Count -ne 1 -or $workingBlobRows.Count -ne 1) {
    throw "Runbook HEAD/working blob identity was not unique."
}
$headRunbookBlob = $headBlobRows[0].Trim()
$workingRunbookBlob = $workingBlobRows[0].Trim()
$runbookExactHead = $headRunbookBlob -ceq $workingRunbookBlob
$runnerInitialStatus = @(
    Invoke-RunnerGit -Root $gitRoot -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    )
)
$runnerDirtyTree = $runnerInitialStatus.Count -ne 0

$runbookBlocks = @(Get-StrictPowerShellRunbookBlocks -Path $resolvedRunbook)
if ($runbookBlocks.Count -ne 12) {
    throw "Expected exactly 12 executable PowerShell blocks; actual=$($runbookBlocks.Count)."
}
$astFailures = [Collections.Generic.List[object]]::new()
foreach ($block in $runbookBlocks) {
    foreach ($failure in @($block.ast_failures)) {
        $astFailures.Add($failure)
    }
}
$combinedSource = @(
    foreach ($block in $runbookBlocks) {
        "# RUNBOOK_BLOCK_$($block.block_index)_BEGIN"
        $block.source
        "# RUNBOOK_BLOCK_$($block.block_index)_END"
    }
) -join "`n"
$combinedValidation = Get-RunbookAstFailures `
    -Source $combinedSource `
    -Label "combined_12_blocks"
foreach ($failure in @($combinedValidation.failures)) {
    $astFailures.Add($failure)
}
if ($astFailures.Count -ne 0) {
    throw ($astFailures | ConvertTo-Json -Depth 8 -Compress)
}
$postParseWorkingBlobRows = @(
    Invoke-RunnerGit -Root $gitRoot -Arguments @(
        "hash-object", "--path=$runbookRelativePath", "--", $resolvedRunbook
    )
)
if ($postParseWorkingBlobRows.Count -ne 1 `
    -or $postParseWorkingBlobRows[0].Trim() -cne $workingRunbookBlob) {
    throw "Runbook content changed while its executable blocks were being validated."
}

if ($ValidateOnly) {
    $forbiddenDoubleBackslashReplacement = '.Replace("\\", "/")'
    $requiredSingleBackslashReplacement = '.Replace("\", "/")'
    $singleBackslashReplacementCount = [regex]::Matches(
        $combinedSource,
        [regex]::Escape($requiredSingleBackslashReplacement)
    ).Count
    if ($combinedSource.Contains($forbiddenDoubleBackslashReplacement) `
        -or $singleBackslashReplacementCount -lt 2) {
        throw "Windows path separator normalization contract failed."
    }
    $cleanupCommand = Get-Command `
        -Name Invoke-RunnerTransientFailureCleanup `
        -CommandType Function
    $issuesParameter = $cleanupCommand.Parameters["Issues"]
    $allowEmptyCollectionCount = @(
        $issuesParameter.Attributes |
            Where-Object {
                $_ -is [System.Management.Automation.AllowEmptyCollectionAttribute]
            }
    ).Count
    if ($allowEmptyCollectionCount -ne 1) {
        throw "Transient cleanup must accept an empty issue collection."
    }
    $validationImportAuthority = Get-RunnerCanonicalImportAuthority
    $validationImportPaths = [string[]]@($validationImportAuthority.paths)
    $validationImportPathSetSha = Get-RunnerCanonicalPathSetSha256 `
        -Paths $validationImportPaths
    $validationImportBaselineSha = Get-RunnerCanonicalFileMapSha256 `
        -Root $gitRoot `
        -Paths $validationImportPaths
    if ($validationImportPaths.Count `
            -ne [int]$validationImportAuthority.expected_count `
        -or $validationImportPathSetSha `
            -cne [string]$validationImportAuthority.path_set_sha256 `
        -or $validationImportBaselineSha `
            -cne [string]$validationImportAuthority.baseline_map_sha256) {
        throw "Canonical import authority failed offline validation."
    }
    $validationUidPerformed = $false
    $validationUidEntryCount = 0
    $validationUidSetSha = ""
    $validationUidPathProvided = -not [string]::IsNullOrWhiteSpace(
        $GeneratedUidAllowlistPath
    )
    $validationUidShaProvided = -not [string]::IsNullOrWhiteSpace(
        $ExpectedGeneratedUidAllowlistSha256
    )
    if ($validationUidPathProvided -xor $validationUidShaProvided) {
        throw "ValidateOnly UID authority validation requires both path and SHA."
    }
    if ($validationUidPathProvided) {
        if (-not [regex]::IsMatch(
            $ExpectedGeneratedUidAllowlistSha256,
            '\A[0-9a-f]{64}\z'
        )) {
            throw "ValidateOnly UID authority SHA is not lowercase 64-hex."
        }
        $validationHeadRows = @(
            Invoke-RunnerGit -Root $gitRoot -Arguments @("rev-parse", "HEAD")
        )
        $validationTreeRows = @(
            Invoke-RunnerGit -Root $gitRoot -Arguments @("rev-parse", "HEAD^{tree}")
        )
        if ($validationHeadRows.Count -ne 1 -or $validationTreeRows.Count -ne 1) {
            throw "ValidateOnly could not resolve exact HEAD/tree."
        }
        $validationUidAuthority = Read-RunnerExactUidAllowlist `
            -Path $GeneratedUidAllowlistPath `
            -ExpectedSha256 $ExpectedGeneratedUidAllowlistSha256 `
            -Worktree $gitRoot `
            -HeadSha $validationHeadRows[0].Trim() `
            -TreeSha $validationTreeRows[0].Trim()
        $validationUidPerformed = $true
        $validationUidEntryCount = @($validationUidAuthority.candidates).Count
        $validationUidSetSha = [string]$validationUidAuthority.uid_entry_set_sha256
    }
    [ordered]@{
        schema = "SpaceSyndicateV075McpRunbookValidationV2"
        status = "PASS"
        runbook_path = $resolvedRunbook
        git_worktree = $gitRoot
        runbook_relative_path = $runbookRelativePath
        runbook_tracked = $true
        runbook_head_blob = $headRunbookBlob
        runbook_working_blob = $workingRunbookBlob
        runbook_exact_head = $runbookExactHead
        dirty_tree_validation = $runnerDirtyTree
        runbook_dirty_validation = -not $runbookExactHead
        executable_block_count = $runbookBlocks.Count
        per_block_parse_error_count = 0
        combined_parse_error_count = 0
        forbidden_top_level_control_count = 0
        execution_model = "same_scope_dot_sourced_scriptblocks"
        windows_path_separator_contract_green = $true
        windows_path_separator_replacement_count = $singleBackslashReplacementCount
        transient_cleanup_empty_issue_binding_green = $true
        canonical_import_authority_green = $true
        canonical_import_path_count = $validationImportPaths.Count
        canonical_import_path_set_sha256 = $validationImportPathSetSha
        canonical_import_baseline_map_sha256 = $validationImportBaselineSha
        uid_allowlist_validation_performed = $validationUidPerformed
        uid_allowlist_entry_count = $validationUidEntryCount
        uid_allowlist_entry_set_sha256 = $validationUidSetSha
        godot_started = $false
        mcp_started = $false
        formal_started = $false
    } | ConvertTo-Json -Depth 8
    return
}

if ($PSBoundParameters.ContainsKey("GeneratedUidAllowlistPath") `
    -and -not [string]::IsNullOrWhiteSpace(
        $env:V075_MCP_GENERATED_UID_ALLOWLIST_PATH
    ) `
    -and -not [IO.Path]::GetFullPath($GeneratedUidAllowlistPath).Equals(
        [IO.Path]::GetFullPath($env:V075_MCP_GENERATED_UID_ALLOWLIST_PATH),
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "UID allowlist parameter and environment path disagree."
}
if ($PSBoundParameters.ContainsKey("ExpectedGeneratedUidAllowlistSha256") `
    -and -not [string]::IsNullOrWhiteSpace(
        $env:V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256
    ) `
    -and $ExpectedGeneratedUidAllowlistSha256 `
        -cne $env:V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256) {
    throw "UID allowlist parameter and environment SHA disagree."
}
if ([string]::IsNullOrWhiteSpace($GeneratedUidAllowlistPath) `
    -or [string]::IsNullOrWhiteSpace($ExpectedGeneratedUidAllowlistSha256) `
    -or -not [regex]::IsMatch(
        $ExpectedGeneratedUidAllowlistSha256,
        '\A[0-9a-f]{64}\z'
    )) {
    throw (
        "Execution requires -GeneratedUidAllowlistPath and one independently " +
        "frozen lowercase -ExpectedGeneratedUidAllowlistSha256."
    )
}
$env:V075_MCP_GENERATED_UID_ALLOWLIST_PATH = `
    [IO.Path]::GetFullPath($GeneratedUidAllowlistPath)
$env:V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256 = `
    $ExpectedGeneratedUidAllowlistSha256

if (-not $runbookExactHead) {
    throw "Execution requires the runbook working blob to match exact HEAD."
}
if ($runnerDirtyTree) {
    throw "Execution requires an exact-HEAD clean worktree; use -ValidateOnly for dirty static validation."
}
$preExecutionIgnoredUidRows = @(
    Get-RunnerUnexpectedIgnoredUidRows -Worktree $gitRoot
)
if ($preExecutionIgnoredUidRows.Count -ne 0) {
    throw (
        "Execution requires zero ignored generated UID files outside trusted " +
        "cache roots."
    )
}
$preExecutionRunbookBlobRows = @(
    Invoke-RunnerGit -Root $gitRoot -Arguments @(
        "hash-object", "--path=$runbookRelativePath", "--", $resolvedRunbook
    )
)
$preExecutionStatus = @(
    Invoke-RunnerGit -Root $gitRoot -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    )
)
if ($preExecutionRunbookBlobRows.Count -ne 1 `
    -or $preExecutionRunbookBlobRows[0].Trim() -cne $headRunbookBlob `
    -or $preExecutionStatus.Count -ne 0) {
    throw "Exact-HEAD worktree identity changed after runbook validation."
}

$runnerExecutionStartedAt = [DateTimeOffset]::UtcNow
$runnerConnectionPath = Join-Path $gitRoot ".codex-godot\connection.json"
$runnerRoleBaseline = [pscustomobject]@{
    connection_exists = Test-Path -LiteralPath $runnerConnectionPath -PathType Leaf
    connection_sha256 = if (Test-Path -LiteralPath $runnerConnectionPath -PathType Leaf) {
        Get-RunnerFileSha256 $runnerConnectionPath
    } else {
        ""
    }
}
$primaryFailure = $null
$primaryFailureSnapshot = $null
$failedBlockIndex = 0
$cleanupErrors = [Collections.Generic.List[string]]::new()
$exitPlayRaw = @()
$exitPlayCode = $null
$stopRaw = @()
$stopCode = $null
$ownedRole = $null
$transientCleanup = $null
$failureEvidenceRoot = $null
$primaryFailurePath = ""
$rawManifestPath = ""
$finalFailurePath = ""
$exitRawPath = ""
$failureId = "runbook-failure-{0}-{1}" -f @(
    [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssfffZ"),
    [guid]::NewGuid().ToString("N").Substring(0, 8)
)

try {
    for ($runnerBlockIndex = 0; `
        $runnerBlockIndex -lt $runbookBlocks.Count; `
        $runnerBlockIndex += 1) {
        $failedBlockIndex = $runnerBlockIndex + 1
        $runnerScriptBlock = $runbookBlocks[$runnerBlockIndex].script_block
        . $runnerScriptBlock
    }
    $failedBlockIndex = 0
} catch {
    $primaryFailure = $_
    $primaryFailureSnapshot = [ordered]@{
        exception_type = $_.Exception.GetType().FullName
        message = $_.Exception.Message
        fully_qualified_error_id = $_.FullyQualifiedErrorId
        category = [string]$_.CategoryInfo
        script_stack_trace = $_.ScriptStackTrace
        position_message = $_.InvocationInfo.PositionMessage
        rendered = [string]$_
    }
} finally {
    if ($null -ne $primaryFailure) {
        $worktreeValue = Get-RunbookVariableValue "Worktree"
        if ($null -eq $worktreeValue) { $worktreeValue = $gitRoot }
        $worktreeValue = [IO.Path]::GetFullPath([string]$worktreeValue)
        try {
            $failureEvidenceRoot = Resolve-RunnerFailureEvidenceRoot `
                -Worktree $worktreeValue
            if ($null -eq $failureEvidenceRoot) {
                $cleanupErrors.Add("Failure evidence root is unavailable.")
            } else {
                $primaryFailurePath = Join-Path `
                    $failureEvidenceRoot `
                    "$failureId-primary.json"
                Write-ImmutableFailureJson -Path $primaryFailurePath -Value ([ordered]@{
                    schema = "SpaceSyndicateV075McpRunbookPrimaryFailureV1"
                    failed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
                    execution_started_at_utc = $runnerExecutionStartedAt.ToString("o")
                    runbook_path = $resolvedRunbook
                    runbook_head_blob = $headRunbookBlob
                    runbook_working_blob = $workingRunbookBlob
                    failed_block_index = $failedBlockIndex
                    primary_error = $primaryFailureSnapshot
                    acceptance_red = $true
                })
            }
        } catch {
            $cleanupErrors.Add("Primary failure evidence write failed: $($_.Exception.Message)")
        }

        $rawEvidenceValue = Get-RunbookVariableValue "McpRawEvidence"
        if ($null -ne $rawEvidenceValue -and $null -ne $failureEvidenceRoot) {
            try {
                $rawRows = @($rawEvidenceValue | ForEach-Object { $_ })
                $rawManifestPath = Join-Path `
                    $failureEvidenceRoot `
                    "$failureId-mcp-raw-manifest.json"
                Write-ImmutableFailureJson -Path $rawManifestPath -Value ([ordered]@{
                    schema = "SpaceSyndicateV075McpRunbookFailureRawManifestV1"
                    captured_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
                    failed_block_index = $failedBlockIndex
                    head_sha = [string](Get-RunbookVariableValue "HeadSha")
                    tree_sha = [string](Get-RunbookVariableValue "TreeSha")
                    response_count = $rawRows.Count
                    responses = $rawRows
                })
            } catch {
                $cleanupErrors.Add("Failure raw manifest write failed: $($_.Exception.Message)")
            }
        }

        try {
            $ownedRole = Get-RunnerOwnedRoleConnection `
                -Worktree $worktreeValue `
                -Baseline $runnerRoleBaseline `
                -ExecutionStartedAt $runnerExecutionStartedAt `
                -LaunchResult (Get-RunbookVariableValue "LaunchResult")
        } catch {
            $cleanupErrors.Add("Owned role identity resolution failed: $($_.Exception.Message)")
        }
        if ($null -ne $ownedRole) {
            $invokeValue = Get-RunbookVariableValue "Invoke"
            if ($null -eq $invokeValue) {
                $invokeValue = Join-Path $worktreeValue "tools\invoke_role_godot_mcp.ps1"
            }
            $stopValue = Get-RunbookVariableValue "Stop"
            if ($null -eq $stopValue) {
                $stopValue = Join-Path $worktreeValue "tools\stop_role_godot_mcp.ps1"
            }
            if (Test-Path -LiteralPath $invokeValue -PathType Leaf) {
                try {
                    $exitArguments = @(
                        "-NoLogo", "-NoProfile", "-File", [string]$invokeValue,
                        "-Worktree", $worktreeValue,
                        "-ToolName", "exit_play_mode",
                        "-ArgumentsJson", "{}",
                        "-TimeoutSeconds", "30",
                        "-PassThroughToolErrors"
                    )
                    if ($null -ne $failureEvidenceRoot) {
                        $exitRawPath = Join-Path `
                            $failureEvidenceRoot `
                            "$failureId-exit-play.jsonrpc.json"
                        $exitArguments += @("-RawResponsePath", $exitRawPath)
                    }
                    $exitPlayRaw = @(& pwsh @exitArguments 2>&1)
                    $exitPlayCode = $LASTEXITCODE
                    if ($exitPlayCode -ne 0) {
                        $cleanupErrors.Add("Scoped exit_play_mode failed: exit=$exitPlayCode")
                    }
                } catch {
                    $exitPlayCode = -1
                    $exitPlayRaw = @($_ | Out-String)
                    $cleanupErrors.Add("Scoped exit_play_mode threw: $($_.Exception.Message)")
                }
            } else {
                $cleanupErrors.Add("Owned role exists but the scoped invoke script is unavailable.")
            }
            if (Test-Path -LiteralPath $stopValue -PathType Leaf) {
                try {
                    $stopRaw = @(& pwsh -NoLogo -NoProfile -File $stopValue `
                        -Worktree $worktreeValue 2>&1)
                    $stopCode = $LASTEXITCODE
                    if ($stopCode -ne 0) {
                        $cleanupErrors.Add("Scoped role stop failed: exit=$stopCode")
                    }
                } catch {
                    $stopCode = -1
                    $stopRaw = @($_ | Out-String)
                    $cleanupErrors.Add("Scoped role stop threw: $($_.Exception.Message)")
                }
            } else {
                $cleanupErrors.Add("Owned role exists but the scoped stop script is unavailable.")
            }
            try {
                $ownedProcess = Get-Process `
                    -Id ([int]$ownedRole.pid) `
                    -ErrorAction SilentlyContinue
                if ($null -ne $ownedProcess -and -not $ownedProcess.HasExited) {
                    $cleanupErrors.Add("Owned Godot PID remains after scoped stop.")
                }
                $ownedListeners = @(
                    Get-NetTCPConnection -State Listen -ErrorAction Stop |
                        Where-Object {
                            [int]$_.LocalPort -eq [int]$ownedRole.port `
                                -and [int]$_.OwningProcess -eq [int]$ownedRole.pid
                        }
                )
                if ($ownedListeners.Count -ne 0) {
                    $cleanupErrors.Add("Owned MCP endpoint remains after scoped stop.")
                }
            } catch {
                $cleanupErrors.Add("Scoped stop verification failed: $($_.Exception.Message)")
            }
        }
        if ($null -ne $failureEvidenceRoot) {
            try {
                Write-ImmutableFailureText `
                    -Path (Join-Path $failureEvidenceRoot "$failureId-exit-play.stdout.txt") `
                    -Value (@($exitPlayRaw) -join [Environment]::NewLine)
                Write-ImmutableFailureText `
                    -Path (Join-Path $failureEvidenceRoot "$failureId-stop.stdout.txt") `
                    -Value (@($stopRaw) -join [Environment]::NewLine)
            } catch {
                $cleanupErrors.Add("Scoped stop evidence write failed: $($_.Exception.Message)")
            }
        }

        try {
            $transientCleanup = Invoke-RunnerTransientFailureCleanup `
                -Worktree $worktreeValue `
                -EvidenceRoot $failureEvidenceRoot `
                -FailureId $failureId `
                -Context "failure_finalizer" `
                -Issues $cleanupErrors
        } catch {
            $cleanupErrors.Add("Transient failure finalizer threw: $($_.Exception.Message)")
        }

        if ($null -ne $failureEvidenceRoot) {
            try {
                $finalFailurePath = Join-Path `
                    $failureEvidenceRoot `
                    "$failureId-final.json"
                Write-ImmutableFailureJson -Path $finalFailurePath -Value ([ordered]@{
                    schema = "SpaceSyndicateV075McpRunbookFailureFinalV2"
                    finalized_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
                    runbook_path = $resolvedRunbook
                    failed_block_index = $failedBlockIndex
                    primary_error = $primaryFailureSnapshot
                    primary_failure_evidence_path = $primaryFailurePath
                    raw_manifest_path = $rawManifestPath
                    finalizer_exit_raw_path = if (
                        -not [string]::IsNullOrWhiteSpace($exitRawPath) `
                        -and (Test-Path -LiteralPath $exitRawPath -PathType Leaf)
                    ) { $exitRawPath } else { $null }
                    finalizer_exit_raw_sha256 = if (
                        -not [string]::IsNullOrWhiteSpace($exitRawPath) `
                        -and (Test-Path -LiteralPath $exitRawPath -PathType Leaf)
                    ) { Get-RunnerFileSha256 $exitRawPath } else { $null }
                    owned_role = $ownedRole
                    exit_play_code = $exitPlayCode
                    exit_play_output = @($exitPlayRaw | ForEach-Object { [string]$_ })
                    stop_code = $stopCode
                    stop_output = @($stopRaw | ForEach-Object { [string]$_ })
                    transient_cleanup = $transientCleanup
                    finalizer_issues = @($cleanupErrors)
                    acceptance_red = $true
                })
            } catch {
                $cleanupErrors.Add("Final failure evidence write failed: $($_.Exception.Message)")
            }
        }
    }
}

if ($null -ne $primaryFailure) {
    $message = (
        "V0.7.5 exact-SHA MCP runbook failed in block {0}: {1}" -f
        $failedBlockIndex,
        $primaryFailureSnapshot.message
    )
    if ($cleanupErrors.Count -ne 0) {
        $message += " Finalizer issues: $($cleanupErrors -join ' | ')"
    }
    throw $message
}
