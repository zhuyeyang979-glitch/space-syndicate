param(
    [string]$Worktree = (Get-Location).Path,
    [int]$ShutdownTimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd("\")
$localRoot = Join-Path $root ".codex-godot"
$connectionPath = Join-Path $localRoot "connection.json"
$pidPath = Join-Path $localRoot "godot.pid"

if (-not (Test-Path -LiteralPath $pidPath)) {
    throw "No role-local Godot PID file exists at: $pidPath"
}

$pidText = [System.IO.File]::ReadAllText($pidPath).Trim()
if ($pidText -notmatch "^\d+$") {
    throw "Invalid Godot PID file: $pidPath"
}

$process = Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue
if ($process -eq $null -or $process.HasExited) {
    Remove-Item -LiteralPath $pidPath -Force
    [pscustomobject]@{ stopped = $true; already_exited = $true; pid = [int]$pidText } | ConvertTo-Json
    exit 0
}

if (-not $process.CloseMainWindow()) {
    throw "Godot did not accept a normal window-close request (PID $pidText)."
}
if (-not $process.WaitForExit($ShutdownTimeoutSeconds * 1000)) {
    throw "Godot did not exit cleanly within $ShutdownTimeoutSeconds seconds (PID $pidText)."
}

Remove-Item -LiteralPath $pidPath -Force
$connection = if (Test-Path -LiteralPath $connectionPath) {
    Get-Content -LiteralPath $connectionPath -Raw | ConvertFrom-Json
} else {
    $null
}
$portOpen = $false
if ($connection -ne $null) {
    $portOpen = [bool](Get-NetTCPConnection -State Listen -LocalPort ([int]$connection.port) -ErrorAction SilentlyContinue)
}

[pscustomobject]@{
    stopped = -not $portOpen
    already_exited = $false
    pid = [int]$pidText
    port_open = $portOpen
} | ConvertTo-Json
