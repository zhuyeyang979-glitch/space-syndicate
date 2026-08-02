param(
    [Parameter(Mandatory = $true)]
    [string]$ToolName,

    [string]$ArgumentsJson = "{}",

    [string]$Worktree = (Get-Location).Path,

    [ValidateRange(1, 900)]
    [int]$TimeoutSeconds = 60,

    [string]$OutputImage = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "role_godot_mcp_common.ps1")

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd("\")
$controlRoot = Join-Path $root ".codex-godot"
$session = Get-McpActiveSession -ControlRoot $controlRoot
$connection = $session.connection
$identity = Test-McpProcessIdentity -Connection $connection
if (-not [bool]$identity.valid) {
    throw "MCP_EDITOR_PROCESS_EXITED|reason_code=$($identity.reason_code)|pid=$($connection.pid)|endpoint=$($connection.endpoint)|log=$($connection.log_path)"
}

$endpointOwnerPid = Get-McpEndpointOwnerPid -Port ([int]$connection.port)
if ($endpointOwnerPid -eq 0) {
    throw "MCP_ENDPOINT_UNAVAILABLE|pid=$($connection.pid)|endpoint=$($connection.endpoint)"
}
if ($endpointOwnerPid -ne [int]$connection.pid) {
    throw "MCP_ENDPOINT_PROCESS_MISMATCH|expected_pid=$($connection.pid)|actual_pid=$endpointOwnerPid"
}

$token = [System.IO.File]::ReadAllText([string]$connection.token_path).Trim()
$arguments = $ArgumentsJson | ConvertFrom-Json -AsHashtable
if ($null -eq $arguments) {
    $arguments = @{}
}
$requestIdRequiredTools = @(
    "request_script_reload",
    "request_project_reload",
    "request_filesystem_scan",
    "stop_editor"
)
if ($ToolName -in $requestIdRequiredTools) {
    if (-not $arguments.ContainsKey("request_id") -or [string]::IsNullOrWhiteSpace([string]$arguments["request_id"])) {
        throw "MCP_REQUEST_ID_REQUIRED|tool=$ToolName"
    }
}

$jsonRpcRequestId = [guid]::NewGuid().ToString("N")
$headers = @{
    "X-Funplay-MCP-Token" = $token
    "MCP-Protocol-Version" = "2025-11-25"
}
$body = @{
    jsonrpc = "2.0"
    id = $jsonRpcRequestId
    method = "tools/call"
    params = @{
        name = $ToolName
        arguments = $arguments
    }
} | ConvertTo-Json -Depth 30 -Compress

try {
    $response = Invoke-RestMethod -Uri ([string]$connection.endpoint) -Method Post -Headers $headers -ContentType "application/json" -Body $body -TimeoutSec $TimeoutSeconds
} catch {
    $identityAfter = Test-McpProcessIdentity -Connection $connection
    if (-not [bool]$identityAfter.valid) {
        throw "MCP_EDITOR_PROCESS_EXITED|reason_code=$($identityAfter.reason_code)|pid=$($connection.pid)|endpoint=$($connection.endpoint)|log=$($connection.log_path)"
    }
    if ((Get-McpEndpointOwnerPid -Port ([int]$connection.port)) -eq 0) {
        throw "MCP_ENDPOINT_UNAVAILABLE|pid=$($connection.pid)|endpoint=$($connection.endpoint)"
    }
    throw
}

$responseError = Get-McpOptionalProperty -Object $response -Name "error"
if ($null -ne $responseError) {
    throw ($responseError | ConvertTo-Json -Depth 10 -Compress)
}

if ($OutputImage -ne "") {
    $imageContent = $response.result.content | Where-Object { $_.type -eq "image" } | Select-Object -First 1
    if ($null -eq $imageContent) {
        throw "Tool $ToolName returned no image content."
    }
    $imagePath = [System.IO.Path]::GetFullPath((Join-Path $root $OutputImage))
    if (-not $imagePath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Image output must stay inside the role worktree: $imagePath"
    }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($imagePath)) | Out-Null
    [System.IO.File]::WriteAllBytes($imagePath, [System.Convert]::FromBase64String([string]$imageContent.data))
}

$response | ConvertTo-Json -Depth 30
