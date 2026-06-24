$ErrorActionPreference = "SilentlyContinue"

$projectRoot = Split-Path -Parent $PSScriptRoot
$godotCandidates = @()

$cmd = Get-Command godot -ErrorAction SilentlyContinue
if ($cmd) { $godotCandidates += $cmd.Source }

$cmd4 = Get-Command godot4 -ErrorAction SilentlyContinue
if ($cmd4) { $godotCandidates += $cmd4.Source }

$godotCandidates += @(
  "C:\Program Files\Godot\Godot.exe",
  "C:\Program Files\Godot\Godot_v4.exe",
  "C:\Program Files (x86)\Godot\Godot.exe",
  "$env:LOCALAPPDATA\Programs\Godot\Godot.exe"
)

$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if ($godot) {
  Start-Process -FilePath $godot -ArgumentList @("--path", $projectRoot)
} else {
  Start-Process -FilePath explorer.exe -ArgumentList $projectRoot
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show("Godot was not found on this PC. The project folder has been opened instead.`n`nInstall Godot 4.x, then use this shortcut again.", "Space Syndicate Prototype")
}
