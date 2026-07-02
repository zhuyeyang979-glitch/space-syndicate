$ErrorActionPreference = "SilentlyContinue"

$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$godotCandidates = @()

$envGodot = $env:GODOT_EXE
if ($envGodot) { $godotCandidates += $envGodot }

$cmd = Get-Command godot -ErrorAction SilentlyContinue
if ($cmd) { $godotCandidates += $cmd.Source }

$cmd4 = Get-Command godot4 -ErrorAction SilentlyContinue
if ($cmd4) { $godotCandidates += $cmd4.Source }

$localGodotRoots = @(
  "$workspaceRoot\tools\godot-4.6.2",
  "$workspaceRoot\tools",
  "$projectRoot\tools\godot-4.6.2",
  "$projectRoot\tools",
  "$env:LOCALAPPDATA\Programs\Godot",
  "E:\New project\tools\godot-4.6.2",
  "E:\New project\tools"
)

foreach ($root in $localGodotRoots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  $godotCandidates += Get-ChildItem -LiteralPath $root -Filter "Godot*_console.exe" -File -Recurse |
    Select-Object -ExpandProperty FullName
  $godotCandidates += Get-ChildItem -LiteralPath $root -Filter "Godot*_win64.exe" -File -Recurse |
    Where-Object { $_.Name -notmatch "_console\.exe$" } |
    Select-Object -ExpandProperty FullName
}

$godotCandidates += @(
  "C:\Program Files\Godot\Godot.exe",
  "C:\Program Files\Godot\Godot_v4.exe",
  "C:\Program Files (x86)\Godot\Godot.exe",
  "$env:LOCALAPPDATA\Programs\Godot\Godot.exe"
)

$godot = $godotCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique | Select-Object -First 1

if ($godot) {
  if ((Split-Path -Leaf $godot) -match "_console\.exe$") {
    Push-Location $projectRoot
    & $godot --path $projectRoot
    Pop-Location
  } else {
    Start-Process -FilePath $godot -ArgumentList @("--path", $projectRoot) -WorkingDirectory $projectRoot
  }
} else {
  Start-Process -FilePath explorer.exe -ArgumentList $projectRoot
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show("Godot was not found on this PC. The project folder has been opened instead.`n`nInstall Godot 4.x or set GODOT_EXE, then use this shortcut again.", "太空辛迪加")
}
