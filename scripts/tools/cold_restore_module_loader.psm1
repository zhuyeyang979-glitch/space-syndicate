Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ModuleIdentityByPath = @{}

function Resolve-ColdRestoreModulePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "cold_restore_module_path_invalid"
    }
    try {
        $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    }
    catch {
        throw "cold_restore_module_path_missing"
    }
    if (-not [IO.File]::Exists($resolved) `
        -or [IO.Path]::GetExtension($resolved) -cnotin @(".psm1", ".psd1")) {
        throw "cold_restore_module_path_invalid"
    }
    return [IO.Path]::GetFullPath($resolved)
}

function Get-ColdRestoreModuleFileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = Resolve-ColdRestoreModulePath $Path
    return (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ColdRestoreLoadedModuleByPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = Resolve-ColdRestoreModulePath $Path
    $matches = @(
        Get-Module -All | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.Path) `
                -and [IO.Path]::GetFullPath([string]$_.Path).Equals(
                    $resolved,
                    [StringComparison]::OrdinalIgnoreCase
                )
        }
    )
    if ($matches.Count -gt 1) {
        throw "cold_restore_module_duplicate_instance"
    }
    if ($matches.Count -eq 0) {
        return $null
    }
    return $matches[0]
}

function Assert-ColdRestoreModuleExports {
    param(
        [Parameter(Mandatory = $true)]
        [Management.Automation.PSModuleInfo]$ModuleInfo,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$RequiredCommands
    )

    foreach ($commandName in $RequiredCommands) {
        if ([string]::IsNullOrWhiteSpace($commandName) `
            -or -not $ModuleInfo.ExportedCommands.ContainsKey($commandName)) {
            throw "cold_restore_module_required_export_missing"
        }
        $command = $ModuleInfo.ExportedCommands[$commandName]
        if ($null -eq $command `
            -or [string]$command.ModuleName -cne [string]$ModuleInfo.Name) {
            throw "cold_restore_module_export_identity_invalid"
        }
    }
    return $ModuleInfo
}

function Get-ColdRestoreModuleIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [Management.Automation.PSModuleInfo]$ModuleInfo
    )

    $resolved = Resolve-ColdRestoreModulePath ([string]$ModuleInfo.Path)
    $sha256 = Get-ColdRestoreModuleFileSha256 $resolved
    return [pscustomobject][ordered]@{
        module_name = [string]$ModuleInfo.Name
        module_path = $resolved
        module_guid = [string]$ModuleInfo.Guid
        module_version = [string]$ModuleInfo.Version
        file_sha256 = $sha256
    }
}

function Import-ColdRestoreModuleOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowEmptyCollection()][string[]]$RequiredCommands = @(),
        [AllowEmptyString()][string]$ExpectedFileSha256 = "",
        [AllowNull()][version]$RequiredVersion = $null
    )

    $resolved = Resolve-ColdRestoreModulePath $Path
    $moduleName = [IO.Path]::GetFileNameWithoutExtension($resolved)
    $currentSha256 = Get-ColdRestoreModuleFileSha256 $resolved
    if (-not [string]::IsNullOrEmpty($ExpectedFileSha256) `
        -and ($ExpectedFileSha256 -cnotmatch '^[0-9a-f]{64}$' `
            -or $currentSha256 -cne $ExpectedFileSha256)) {
        throw "cold_restore_module_file_identity_mismatch"
    }

    $sameNameDifferentPath = @(
        Get-Module -All -Name $moduleName | Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.Path) `
                -or -not [IO.Path]::GetFullPath([string]$_.Path).Equals(
                    $resolved,
                    [StringComparison]::OrdinalIgnoreCase
                )
        }
    )
    if ($sameNameDifferentPath.Count -gt 0) {
        throw "cold_restore_module_name_collision"
    }

    $module = Get-ColdRestoreLoadedModuleByPath $resolved
    if ($null -eq $module) {
        try {
            $imported = @(
                Import-Module -Name $resolved -Global -PassThru -ErrorAction Stop
            )
        }
        catch {
            throw "cold_restore_module_import_failed"
        }
        $exactImports = @(
            $imported | Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_.Path) `
                    -and [IO.Path]::GetFullPath([string]$_.Path).Equals(
                        $resolved,
                        [StringComparison]::OrdinalIgnoreCase
                    )
            }
        )
        if ($exactImports.Count -ne 1) {
            throw "cold_restore_module_import_identity_invalid"
        }
        $module = $exactImports[0]
    }

    if ($null -ne $RequiredVersion -and [version]$module.Version -ne $RequiredVersion) {
        throw "cold_restore_module_version_mismatch"
    }
    if (-not [IO.Path]::GetFullPath([string]$module.Path).Equals(
            $resolved,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw "cold_restore_module_path_identity_mismatch"
    }

    $identityKey = $resolved.ToLowerInvariant()
    if ($script:ModuleIdentityByPath.ContainsKey($identityKey)) {
        $loadedIdentity = $script:ModuleIdentityByPath[$identityKey]
        if ([string]$loadedIdentity.file_sha256 -cne $currentSha256 `
            -or [string]$loadedIdentity.module_name -cne [string]$module.Name) {
            throw "cold_restore_module_loaded_identity_changed"
        }
    }
    else {
        $script:ModuleIdentityByPath[$identityKey] = [pscustomobject][ordered]@{
            module_name = [string]$module.Name
            module_path = $resolved
            module_guid = [string]$module.Guid
            module_version = [string]$module.Version
            file_sha256 = $currentSha256
        }
    }

    return Assert-ColdRestoreModuleExports $module $RequiredCommands
}

Export-ModuleMember -Function @(
    "Resolve-ColdRestoreModulePath",
    "Get-ColdRestoreModuleFileSha256",
    "Get-ColdRestoreLoadedModuleByPath",
    "Assert-ColdRestoreModuleExports",
    "Get-ColdRestoreModuleIdentity",
    "Import-ColdRestoreModuleOnce"
)
