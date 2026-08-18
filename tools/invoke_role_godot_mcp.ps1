param(
    [Parameter(Mandatory = $true)]
    [string]$ToolName,

    [string]$ArgumentsJson = "{}",

    [string]$Worktree = (Get-Location).Path,

    [int]$TimeoutSeconds = 60,

    [string]$OutputImage = "",

    [switch]$PassThroughToolErrors,

    [string]$RawResponsePath = ""
)

$ErrorActionPreference = "Stop"

$processIdentityModule = Join-Path `
    $PSScriptRoot `
    "role_godot_mcp_process_identity.psm1"
Import-Module -Name $processIdentityModule -Force -ErrorAction Stop

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd("\")
$localRoot = Join-Path $root ".codex-godot"
$connectionPath = Join-Path $localRoot "connection.json"
$tokenPath = Join-Path $localRoot "auth.token"

function Test-CommandLineWorktreeBinding {
    param(
        [Parameter(Mandatory = $true)][string]$CommandLine,
        [Parameter(Mandatory = $true)][string]$ExpectedRoot
    )
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    foreach ($rootForm in @($ExpectedRoot, $ExpectedRoot.Replace("\", "/"))) {
        $escapedRoot = [Regex]::Escape($rootForm.TrimEnd("\", "/"))
        $pattern = '(?i)(?:^|\s)--path(?:\s+|=)(?:"' +
            $escapedRoot + '"|' + $escapedRoot + ')(?=\s|$)'
        if ([Regex]::IsMatch($CommandLine, $pattern)) { return $true }
    }
    return $false
}

function Assert-RolePathChainHasNoReparsePoint {
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
                throw "$Label path chain contains a reparse point: $($item.FullName)"
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

Assert-RolePathChainHasNoReparsePoint -Path $root -Label "Role worktree"

if (-not (Test-Path -LiteralPath $connectionPath)) {
    throw "Missing role-local MCP connection metadata: $connectionPath"
}
if (-not (Test-Path -LiteralPath $tokenPath)) {
    throw "Missing role-local MCP token: $tokenPath"
}

$connection = Get-Content -Raw -LiteralPath $connectionPath | ConvertFrom-Json
$reportedWorktree = ([string]$connection.worktree).TrimEnd("\")
if (-not $reportedWorktree.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Role-local MCP metadata belongs to another worktree: $reportedWorktree"
}
$rolePid = [int]$connection.pid
$roleProcess = Get-Process -Id $rolePid -ErrorAction SilentlyContinue
if ($null -eq $roleProcess -or $roleProcess.HasExited) {
    throw "Role-local Godot process is not running: PID $($connection.pid)"
}
try {
    $startIdentityMatches = Test-RoleGodotProcessStartIdentity `
        -ExpectedToken $connection.process_start_time_utc `
        -ActualStartTime $roleProcess.StartTime
} catch {
    throw "Role-local Godot process creation-time token is invalid."
}
if (-not $startIdentityMatches) {
    throw "Role-local Godot PID was reused by another process."
}
$expectedGodotPath = (Resolve-Path -LiteralPath ([string]$connection.godot_path)).Path
if (-not ([string]$roleProcess.Path).Equals(
    $expectedGodotPath,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Role-local Godot executable identity does not match the stored role."
}
$processRow = Get-CimInstance `
    Win32_Process `
    -Filter "ProcessId = $rolePid" `
    -ErrorAction Stop
if ($null -eq $processRow) {
    throw "Role-local Godot process identity could not be enumerated."
}
$commandLine = [string]$processRow.CommandLine
if (-not (Test-CommandLineWorktreeBinding -CommandLine $commandLine -ExpectedRoot $root)) {
    throw "Role-local Godot command line is not bound to this worktree."
}
$port = [int]$connection.port
$endpointUri = [Uri]([string]$connection.endpoint)
if (
    $endpointUri.Scheme -cne "http" -or
    $endpointUri.Host -notin @("127.0.0.1", "localhost") -or
    $endpointUri.Port -ne $port
) {
    throw "Role-local MCP endpoint metadata is not the expected local role endpoint."
}
$listeners = @(
    Get-NetTCPConnection -State Listen -ErrorAction Stop |
        Where-Object { [int]$_.LocalPort -eq $port }
)
if (
    $listeners.Count -ne 1 -or
    [int]$listeners[0].OwningProcess -ne $rolePid -or
    [int]$connection.endpoint_owner_pid -ne $rolePid
) {
    throw "Role-local MCP endpoint is not exclusively owned by the stored Godot process."
}
$token = [System.IO.File]::ReadAllText($tokenPath).Trim()
$arguments = $ArgumentsJson | ConvertFrom-Json -AsHashtable
$headers = @{
    "X-Funplay-MCP-Token" = $token
    "MCP-Protocol-Version" = "2025-11-25"
}
$body = @{
    jsonrpc = "2.0"
    id = 1
    method = "tools/call"
    params = @{
        name = $ToolName
        arguments = $arguments
    }
} | ConvertTo-Json -Depth 30 -Compress

$httpResponse = Invoke-WebRequest `
    -Uri ([string]$connection.endpoint) `
    -Method Post `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $body `
    -TimeoutSec $TimeoutSeconds `
    -SkipHttpErrorCheck

$rawResponseBytes = if ($null -ne $httpResponse.RawContentStream) {
    $httpResponse.RawContentStream.ToArray()
} else {
    [Text.UTF8Encoding]::new($false).GetBytes([string]$httpResponse.Content)
}
if (-not [string]::IsNullOrWhiteSpace($RawResponsePath)) {
    $rawPath = [IO.Path]::GetFullPath($RawResponsePath)
    Assert-RolePathChainHasNoReparsePoint `
        -Path $rawPath `
        -Label "Raw MCP wire evidence"
    $rootPrefix = $root.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    if ($rawPath.Equals($root, [StringComparison]::OrdinalIgnoreCase) `
        -or $rawPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Raw MCP wire evidence must stay outside the role worktree."
    }
    if (Test-Path -LiteralPath $rawPath) {
        throw "Refusing to overwrite raw MCP wire evidence: $rawPath"
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($rawPath)) | Out-Null
    Assert-RolePathChainHasNoReparsePoint `
        -Path ([IO.Path]::GetDirectoryName($rawPath)) `
        -Label "Raw MCP wire evidence parent"
    $temporaryRawPath = "$rawPath.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllBytes($temporaryRawPath, $rawResponseBytes)
        [IO.File]::Move($temporaryRawPath, $rawPath, $false)
    } finally {
        if (Test-Path -LiteralPath $temporaryRawPath) {
            Remove-Item -LiteralPath $temporaryRawPath -Force
        }
    }
}
$rawResponseText = [Text.UTF8Encoding]::new($false, $true).GetString(
    $rawResponseBytes
)

try {
    $response = $rawResponseText | ConvertFrom-Json
} catch {
    throw "MCP endpoint returned non-JSON content (HTTP $([int]$httpResponse.StatusCode))."
}
if ([int]$httpResponse.StatusCode -lt 200 -or [int]$httpResponse.StatusCode -ge 300) {
    $toolFailure = "MCP endpoint returned HTTP $([int]$httpResponse.StatusCode)."
} else {
    $toolFailure = $null
}

if ($response.error -ne $null) {
    $toolFailure = $response.error | ConvertTo-Json -Depth 10 -Compress
} elseif ($null -eq $response.result) {
    $toolFailure = "Tool $ToolName returned no JSON-RPC result."
} elseif ($null -eq $response.result.PSObject.Properties["isError"] `
    -or $response.result.isError -isnot [bool]) {
    $toolFailure = "Tool $ToolName returned an invalid isError field."
} elseif ($response.result.isError) {
    $toolError = @($response.result.content | ForEach-Object {
        if ($_.type -eq "text") { [string]$_.text }
    }) -join "`n"
    $toolFailure = "Tool $ToolName returned isError=true: $toolError"
}
if ($null -ne $toolFailure) {
    if ($PassThroughToolErrors) {
        Write-Output $rawResponseText
        exit 65
    }
    throw $toolFailure
}

if ($OutputImage -ne "") {
    $imageContent = $response.result.content | Where-Object { $_.type -eq "image" } | Select-Object -First 1
    if ($null -eq $imageContent) {
        throw "Tool $ToolName returned no image content."
    }
    $imagePath = [System.IO.Path]::GetFullPath((Join-Path $root $OutputImage))
    Assert-RolePathChainHasNoReparsePoint `
        -Path $imagePath `
        -Label "MCP image output"
    $rootPrefix = $root.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    if (-not $imagePath.StartsWith(
        $rootPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Image output must stay inside the role worktree: $imagePath"
    }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($imagePath)) | Out-Null
    [System.IO.File]::WriteAllBytes($imagePath, [System.Convert]::FromBase64String([string]$imageContent.data))
}

Write-Output $rawResponseText
