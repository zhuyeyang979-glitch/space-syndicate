param(
    [Parameter(Mandatory = $true)]
    [string]$ToolName,

    [string]$ArgumentsJson = "{}",

    [string]$Worktree = (Get-Location).Path,

    [int]$TimeoutSeconds = 60,

    [string]$OutputImage = ""
)

$ErrorActionPreference = "Stop"

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
if ([string]::IsNullOrWhiteSpace([string]$connection.process_start_time_utc)) {
    throw "Role-local Godot metadata has no process creation-time token."
}
try {
    $expectedStart = [DateTime]::Parse(
        [string]$connection.process_start_time_utc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind
    ).ToUniversalTime()
} catch {
    throw "Role-local Godot process creation-time token is invalid."
}
if ($roleProcess.StartTime.ToUniversalTime() -ne $expectedStart) {
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

$response = Invoke-RestMethod `
    -Uri ([string]$connection.endpoint) `
    -Method Post `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $body `
    -TimeoutSec $TimeoutSeconds

if ($response.error -ne $null) {
    throw ($response.error | ConvertTo-Json -Depth 10 -Compress)
}
if ($null -eq $response.result) {
    throw "Tool $ToolName returned no JSON-RPC result."
}
if ([bool]$response.result.isError) {
    $toolError = @($response.result.content | ForEach-Object {
        if ($_.type -eq "text") { [string]$_.text }
    }) -join "`n"
    throw "Tool $ToolName returned isError=true: $toolError"
}

if ($OutputImage -ne "") {
    $imageContent = $response.result.content | Where-Object { $_.type -eq "image" } | Select-Object -First 1
    if ($null -eq $imageContent) {
        throw "Tool $ToolName returned no image content."
    }
    $imagePath = [System.IO.Path]::GetFullPath((Join-Path $root $OutputImage))
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

$response | ConvertTo-Json -Depth 30
