[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath,
    [string]$TempDirectory = "",
    [int]$QuitAfterFrames = 1800,
    [int]$CaptureDelaySeconds = 8,
    [int]$WindowTimeoutSeconds = 20,
    [int]$ExitTimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"
$ExePath = [IO.Path]::GetFullPath($ExePath)
if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
    throw "Exported executable is missing: $ExePath"
}
if ([string]::IsNullOrWhiteSpace($TempDirectory)) {
    $TempDirectory = Join-Path $env:TEMP "space-syndicate-codex\headed-alpha01"
}
$TempDirectory = [IO.Path]::GetFullPath($TempDirectory)
$requiredTempBase = [IO.Path]::GetFullPath((Join-Path $env:TEMP "space-syndicate-codex"))
if (-not ($TempDirectory -eq $requiredTempBase -or $TempDirectory.StartsWith($requiredTempBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
    throw "TempDirectory must stay under $requiredTempBase"
}
[IO.Directory]::CreateDirectory($TempDirectory) | Out-Null
$roaming = Join-Path $TempDirectory "appdata-roaming"
$local = Join-Path $TempDirectory "appdata-local"
[IO.Directory]::CreateDirectory($roaming) | Out-Null
[IO.Directory]::CreateDirectory($local) | Out-Null
$logPath = Join-Path $TempDirectory "exported_headed.log"
$screenshotPath = Join-Path $TempDirectory "main_menu.png"

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SpaceSyndicateWindowBounds {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr handle, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr handle, int command);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr handle);
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr handle, IntPtr insertAfter, int x, int y, int width, int height, uint flags);
}
"@

$process = Start-Process -FilePath $ExePath `
    -ArgumentList @("--windowed", "--resolution", "1600x960", "--position", "40,40", "--quit-after", "$QuitAfterFrames", "--log-file", ('"' + $logPath + '"')) `
    -Environment @{ APPDATA = $roaming; LOCALAPPDATA = $local } `
    -PassThru

$deadline = [DateTime]::UtcNow.AddSeconds($WindowTimeoutSeconds)
while (-not $process.HasExited -and $process.MainWindowHandle -eq [IntPtr]::Zero -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 250
    $process.Refresh()
}
if ($process.HasExited) {
    throw "Exported executable exited before a visible window appeared (exit=$($process.ExitCode))."
}
if ($process.MainWindowHandle -eq [IntPtr]::Zero) {
    $process.Kill($true)
    throw "Exported executable did not expose a visible main window within $WindowTimeoutSeconds seconds."
}

[SpaceSyndicateWindowBounds]::ShowWindow($process.MainWindowHandle, 9) | Out-Null
[SpaceSyndicateWindowBounds]::SetWindowPos($process.MainWindowHandle, [IntPtr](-1), 40, 40, 1600, 960, 0x0040) | Out-Null
[SpaceSyndicateWindowBounds]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
Start-Sleep -Seconds $CaptureDelaySeconds
$process.Refresh()
$rect = New-Object SpaceSyndicateWindowBounds+RECT
if (-not [SpaceSyndicateWindowBounds]::GetWindowRect($process.MainWindowHandle, [ref]$rect)) {
    $process.Kill($true)
    throw "Could not read the exported executable window bounds."
}
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -lt 320 -or $height -lt 240) {
    $process.Kill($true)
    throw "Exported window bounds are invalid: ${width}x${height}"
}
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
    $bitmap.Save($screenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

if (-not $process.WaitForExit($ExitTimeoutSeconds * 1000)) {
    $process.Kill($true)
    throw "Exported executable did not exit after --quit-after $QuitAfterFrames."
}
$fatalLines = @()
if (Test-Path -LiteralPath $logPath) {
    $fatalLines = @(
        Select-String -LiteralPath $logPath -Pattern "SCRIPT ERROR|Parser Error|Parse Error|ERROR:|Failed loading resource|Cannot open file" |
            ForEach-Object { $_.Line.Trim() } |
            Where-Object { $_ -ne "" }
    )
}
$bridgeFiles = @(
    Get-ChildItem -LiteralPath $TempDirectory -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "funplay_mcp_runtime_*" } |
        ForEach-Object { $_.FullName.Substring($TempDirectory.Length + 1).Replace("\", "/") }
)
if ($process.ExitCode -ne 0 -or $fatalLines.Count -gt 0 -or $bridgeFiles.Count -gt 0) {
    throw "Headed verification failed: exit=$($process.ExitCode), fatal_lines=$($fatalLines.Count), bridge_files=$($bridgeFiles.Count)"
}

[ordered]@{
    status = "PASS_PENDING_VISUAL_REVIEW"
    direct_executable_launch = $true
    exit_code = $process.ExitCode
    visible_window = $true
    window_size = "${width}x${height}"
    screenshot = $screenshotPath
    screenshot_sha256 = (Get-FileHash -LiteralPath $screenshotPath -Algorithm SHA256).Hash.ToLowerInvariant()
    fatal_lines = $fatalLines
    bridge_files = $bridgeFiles
    log = $logPath
} | ConvertTo-Json -Depth 6
