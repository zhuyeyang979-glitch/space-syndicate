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
if (-not (Test-Path -LiteralPath $connectionPath)) {
    throw "Missing role-local MCP connection metadata: $connectionPath"
}
if (-not (Test-Path -LiteralPath $tokenPath)) {
    throw "Missing role-local MCP token: $tokenPath"
}

$connection = Get-Content -Raw -LiteralPath $connectionPath | ConvertFrom-Json
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
