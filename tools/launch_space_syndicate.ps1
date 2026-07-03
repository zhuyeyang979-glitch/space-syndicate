$ErrorActionPreference = "Continue"

$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$godotCandidates = @()

$logRoot = Join-Path $env:LOCALAPPDATA "SpaceSyndicate"
$logPath = Join-Path $logRoot "launcher.log"
function Write-LaunchLog {
  param([string]$Message)
  try {
    New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
    Add-Content -Path $logPath -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
  } catch {
    # Launching the game should never fail just because diagnostics cannot be written.
  }
}

$latestGodot = $env:GODOT_LATEST_EXE
if ($latestGodot) { $godotCandidates += $latestGodot }

$envGodot = $env:GODOT_EXE
if ($envGodot) { $godotCandidates += $envGodot }

$cmd = Get-Command godot -ErrorAction SilentlyContinue
if ($cmd) { $godotCandidates += $cmd.Source }

$cmd4 = Get-Command godot4 -ErrorAction SilentlyContinue
if ($cmd4) { $godotCandidates += $cmd4.Source }

$legacy47Override = $env:GODOT_47_EXE
if ($legacy47Override) { $godotCandidates += $legacy47Override }

$godotSearchRoots = @(
  "$workspaceRoot\tools\godot-latest",
  "$workspaceRoot\tools\godot-4.7",
  "$workspaceRoot\tools",
  "$projectRoot\tools\godot-latest",
  "$projectRoot\tools\godot-4.7",
  "$projectRoot\tools",
  "$env:LOCALAPPDATA\Programs\Godot",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
  "E:\New project\tools\godot-latest",
  "E:\New project\tools\godot-4.7",
  "E:\New project\tools"
)

foreach ($root in $godotSearchRoots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  $godotCandidates += Get-ChildItem -LiteralPath $root -Filter "Godot_v*_console.exe" -File -Recurse |
    Select-Object -ExpandProperty FullName
  $godotCandidates += Get-ChildItem -LiteralPath $root -Filter "Godot_v*_win64.exe" -File -Recurse |
    Where-Object { $_.Name -notmatch "_console\.exe$" } |
    Select-Object -ExpandProperty FullName
}

function Get-GodotVersion {
  param([string]$Path)
  try {
    $version = & $Path --version 2>$null
    return [string]$version
  } catch {
    return ""
  }
}

function Test-LatestGodotCandidate {
  param([string]$Path)
  $leaf = Split-Path -Leaf $Path
  if ($leaf -match "^Godot_v(?<major>\d+)\.(?<minor>\d+).+\.exe$") {
    $major = [int]$Matches.major
    $minor = [int]$Matches.minor
    if ($major -gt 4 -or ($major -eq 4 -and $minor -ge 7)) {
      return $true
    }
  }
  $version = (Get-GodotVersion $Path).Trim()
  if ($version -match "^(?<major>\d+)\.(?<minor>\d+)\.") {
    $major = [int]$Matches.major
    $minor = [int]$Matches.minor
    if ($major -gt 4 -or ($major -eq 4 -and $minor -ge 7)) {
      return $true
    }
  }
  return $false
}

function Get-GodotDisplayVersion {
  param([string]$Path)
  $version = (Get-GodotVersion $Path).Trim()
  if ($version) {
    return $version
  }
  $leaf = Split-Path -Leaf $Path
  if ($leaf -match "^Godot_v(?<version>\d+\.\d+[^_]*)") {
    return $Matches.version
  }
  return "latest"
}

function Sort-GodotCandidates {
  param([array]$Candidates)
  return $Candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique | Sort-Object -Descending {
    $leaf = Split-Path -Leaf $_
    if ($leaf -match "^Godot_v(?<major>\d+)\.(?<minor>\d+)") {
      return ([int]$Matches.major * 1000) + [int]$Matches.minor
    }
    $version = (Get-GodotVersion $_).Trim()
    if ($version -match "^(?<major>\d+)\.(?<minor>\d+)\.") {
      return ([int]$Matches.major * 1000) + [int]$Matches.minor
    }
    return 0
  }, {
    $leaf = Split-Path -Leaf $_
    if ($leaf -match "_console\.exe$") {
      return 2
    }
    if ($leaf -match "\.cmd$") {
      return 1
    }
    return 0
  }
}

$godot = $null
foreach ($candidate in (Sort-GodotCandidates $godotCandidates)) {
  if (Test-LatestGodotCandidate $candidate) {
    $godot = $candidate
    break
  }
}

if ($godot) {
  $godotVersion = Get-GodotDisplayVersion $godot
  Write-LaunchLog "Launching project '$projectRoot' with Godot $godotVersion '$godot'."
  Push-Location $projectRoot
  & $godot --path $projectRoot
  Pop-Location
} else {
  Write-LaunchLog "Godot 4.7+ executable was not found. Opened project folder instead: '$projectRoot'."
  Start-Process -FilePath explorer.exe -ArgumentList $projectRoot
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show("Godot 4.7 or newer was not found on this PC. The project folder has been opened instead.`n`nInstall the latest stable Godot or set GODOT_LATEST_EXE, then use this shortcut again.", "太空辛迪加")
}
