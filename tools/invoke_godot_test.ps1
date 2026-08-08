<#
.SYNOPSIS
Runs one Godot 4.7 script or scene gate as a blocking, timeout-bounded process.

.DESCRIPTION
Uses the GUI Godot executable directly, captures the actual process exit code,
writes stdout/stderr/Godot logs to an isolated directory outside the repository,
redirects APPDATA/LOCALAPPDATA so user:// never touches the player's profile, and
removes only the verified process tree started by this invocation.

Runner exit codes are the Godot exit code for a completed test, 124 for timeout,
125 when a completed process leaves a scoped runtime process (even if cleanup
succeeds), 126 when an import bootstrap fails without a more specific exit code,
127 when Godot reports an error despite exiting zero, 128 when an explicitly
required completion marker is absent, 129 for incomplete/invalid/NUL raw capture,
    130 for an unclassified warning, and 131 when a required headed client-window
    handshake or exact client-size probe fails. The console wrapper is deliberately rejected
because it can return before the real process.

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -TestScript res://tests/smoke_test.gd `
    -TestArgument --check-only `
    -TimeoutSeconds 180

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -Scene res://scenes/tools/ProductMarketRuntimeCharacterizationBench.tscn `
    -TimeoutSeconds 300

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -TestScript res://tests/main_runtime_composition_test.gd `
    -EnsureImported `
    -ImportTimeoutSeconds 300 `
    -TimeoutSeconds 180

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -TestScript res://tests/main_runtime_composition_test.gd `
    -RefreshImport `
    -ImportTimeoutSeconds 300 `
    -TimeoutSeconds 180

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -TestScript res://tests/smoke_test.gd `
    -ExpectedCompletionMarker "SMOKE_TEST_COMPLETE" `
    -TimeoutSeconds 600
#>
[CmdletBinding(DefaultParameterSetName = "Script")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Script")]
    [ValidatePattern('^res://.+\.gd$')]
    [string]$TestScript,

    [Parameter(Mandatory = $true, ParameterSetName = "Scene")]
    [ValidatePattern('^res://.+\.tscn$')]
    [string]$Scene,

    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot),

    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe",

    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 180,

    [switch]$EnsureImported,

    [Alias("ForceImport")]
    [switch]$RefreshImport,

    [ValidateRange(1, 86400)]
    [int]$ImportTimeoutSeconds = 300,

    [string[]]$TestArgument = @(),

    [string]$TestArgumentJson = "",

    [switch]$HeadedClientProbe,

    [ValidatePattern('^[1-9][0-9]{2,4}x[1-9][0-9]{2,4}$')]
    [string]$ExpectedClientSize = "",

    [ValidateRange(1, 120)]
    [int]$WindowProbeTimeoutSeconds = 20,

    [string]$LogRoot = (Join-Path $env:LOCALAPPDATA "SpaceSyndicate\godot_test_runs"),

    [string]$ExpectedCompletionMarker = "",

    [string]$IsolatedUserDataRoot = ""
)

$ErrorActionPreference = "Stop"

if (-not [string]::IsNullOrWhiteSpace($TestArgumentJson)) {
    if ($PSBoundParameters.ContainsKey("TestArgument")) {
        throw "Use either -TestArgument or -TestArgumentJson, not both."
    }
    $parsedTestArguments = ConvertFrom-Json `
        -InputObject $TestArgumentJson `
        -NoEnumerate
    if ($parsedTestArguments -isnot [Array]) {
        throw "TestArgumentJson must be a JSON array of strings."
    }
    $normalizedTestArguments = [Collections.Generic.List[string]]::new()
    foreach ($parsedTestArgument in $parsedTestArguments) {
        if ($parsedTestArgument -isnot [string]) {
            throw "Every TestArgumentJson item must be a string."
        }
        $normalizedTestArguments.Add([string]$parsedTestArgument)
    }
    $TestArgument = @($normalizedTestArguments)
}

if ($HeadedClientProbe) {
    if ($PSCmdlet.ParameterSetName -ne "Script") {
        throw "-HeadedClientProbe is supported only for a script driver."
    }
    if ([string]::IsNullOrWhiteSpace($ExpectedClientSize)) {
        throw "-ExpectedClientSize is required with -HeadedClientProbe."
    }
} elseif (-not [string]::IsNullOrWhiteSpace($ExpectedClientSize)) {
    throw "-ExpectedClientSize requires -HeadedClientProbe."
}

foreach ($argument in @($TestArgument)) {
    if (
        $argument.StartsWith("--window-probe-ready=", [StringComparison]::Ordinal) -or
        $argument.StartsWith("--window-probe-ack=", [StringComparison]::Ordinal)
    ) {
        throw "Window probe handshake paths are owned by the runner."
    }
}

function Test-CommandLineContains {
    param(
        [AllowNull()]
        [string]$CommandLine,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($CommandLine)) {
        return $false
    }
    return $CommandLine.IndexOf($Value, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-ProjectRuntimeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedGodotPath
    )

    $forwardProjectPath = $ResolvedProjectPath.Replace('\', '/')
    return @(
        Get-CimInstance Win32_Process |
            Where-Object {
                if ($_.Name -notlike "Godot*.exe") {
                    return $false
                }

                $sameExecutable = -not [string]::IsNullOrEmpty($_.ExecutablePath) -and
                    [string]::Equals(
                        [IO.Path]::GetFullPath($_.ExecutablePath),
                        $ResolvedGodotPath,
                        [StringComparison]::OrdinalIgnoreCase
                    )
                if (-not $sameExecutable) {
                    return $false
                }

                $hasProjectPath = (Test-CommandLineContains -CommandLine $_.CommandLine -Value $ResolvedProjectPath) -or
                    (Test-CommandLineContains -CommandLine $_.CommandLine -Value $forwardProjectPath)
                if (-not $hasProjectPath) {
                    return $false
                }

                $isHeadless = Test-CommandLineContains -CommandLine $_.CommandLine -Value "--headless"
                $isEditor = Test-CommandLineContains -CommandLine $_.CommandLine -Value "--editor"
                return $isHeadless -or -not $isEditor
            }
    )
}

function Get-OwnedProjectRuntimeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [int]$RootProcessId,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedGodotPath
    )

    $processes = @(Get-CimInstance Win32_Process)
    $descendantIds = [Collections.Generic.HashSet[int]]::new()
    $descendantIds.Add($RootProcessId) | Out-Null
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($candidate in $processes) {
            $candidateId = [int]$candidate.ProcessId
            $parentId = [int]$candidate.ParentProcessId
            if (-not $descendantIds.Contains($candidateId) -and $descendantIds.Contains($parentId)) {
                $descendantIds.Add($candidateId) | Out-Null
                $changed = $true
            }
        }
    }

    $forwardProjectPath = $ResolvedProjectPath.Replace('\', '/')
    return @(
        $processes |
            Where-Object {
                if ([int]$_.ProcessId -eq $RootProcessId -or -not $descendantIds.Contains([int]$_.ProcessId)) {
                    return $false
                }
                if ($_.Name -notlike "Godot*.exe") {
                    return $false
                }
                $sameExecutable = -not [string]::IsNullOrEmpty($_.ExecutablePath) -and
                    [string]::Equals(
                        [IO.Path]::GetFullPath($_.ExecutablePath),
                        $ResolvedGodotPath,
                        [StringComparison]::OrdinalIgnoreCase
                    )
                if (-not $sameExecutable) {
                    return $false
                }
                return (Test-CommandLineContains -CommandLine $_.CommandLine -Value $ResolvedProjectPath) -or
                    (Test-CommandLineContains -CommandLine $_.CommandLine -Value $forwardProjectPath)
            }
    )
}

function Stop-ScopedProcessTree {
    param(
        [Parameter(Mandatory = $true)]
        [Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedGodotPath
    )

    $configuredExecutable = [IO.Path]::GetFullPath($Process.StartInfo.FileName)
    $hasExpectedExecutable = [string]::Equals(
        $configuredExecutable,
        $ResolvedGodotPath,
        [StringComparison]::OrdinalIgnoreCase
    )
    $configuredArguments = @($Process.StartInfo.ArgumentList | ForEach-Object { [string]$_ })
    $hasExpectedProject = @(
        $configuredArguments |
            Where-Object {
                [string]::Equals($_, $ResolvedProjectPath, [StringComparison]::OrdinalIgnoreCase) -or
                    [string]::Equals(
                        $_,
                        $ResolvedProjectPath.Replace('\', '/'),
                        [StringComparison]::OrdinalIgnoreCase
                    )
            }
    ).Count -gt 0
    if (-not $hasExpectedExecutable -or -not $hasExpectedProject) {
        throw "Refusing to stop an unverified process tree. executable='$configuredExecutable' project='$ResolvedProjectPath'"
    }

    try {
        $Process.Kill($true)
    } catch {
        try {
            $Process.Kill()
        } catch {
            return $false
        }
    }

    try {
        $Process.WaitForExit(10000) | Out-Null
    } catch {
        # The process may disappear between Kill and WaitForExit.
    }
    return $Process.HasExited
}

function Stop-VerifiedOwnedRuntimeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ProcessRecord,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedGodotPath
    )

    $forwardProjectPath = $ResolvedProjectPath.Replace('\', '/')
    $sameExecutable = -not [string]::IsNullOrEmpty($ProcessRecord.ExecutablePath) -and
        [string]::Equals(
            [IO.Path]::GetFullPath($ProcessRecord.ExecutablePath),
            $ResolvedGodotPath,
            [StringComparison]::OrdinalIgnoreCase
        )
    $hasExpectedProject = (Test-CommandLineContains -CommandLine $ProcessRecord.CommandLine -Value $ResolvedProjectPath) -or
        (Test-CommandLineContains -CommandLine $ProcessRecord.CommandLine -Value $forwardProjectPath)
    if (-not $sameExecutable -or -not $hasExpectedProject) {
        return $false
    }

    try {
        $target = [Diagnostics.Process]::GetProcessById([int]$ProcessRecord.ProcessId)
        try {
            $target.Kill($true)
            $target.WaitForExit(10000) | Out-Null
        } finally {
            $target.Dispose()
        }
        return $true
    } catch {
        return $false
    }
}

function New-GodotProcessStartInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath,
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory = $true)]
        [Collections.IDictionary]$EnvironmentVariables
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ExecutablePath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $ArgumentList) {
        $startInfo.ArgumentList.Add($argument)
    }
    foreach ($entry in $EnvironmentVariables.GetEnumerator()) {
        $startInfo.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    return $startInfo
}

function Initialize-GodotWindowProbeNative {
    if ($null -ne ("SpaceSyndicate.GodotWindowProbeNative" -as [type])) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace SpaceSyndicate {
    public static class GodotWindowProbeNative {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct POINT {
            public int X;
            public int Y;
        }

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsIconic(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern uint GetDpiForWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    }
}
'@
}

function Get-ProcessVisibleWindow {
    param(
        [Parameter(Mandatory = $true)]
        [Diagnostics.Process]$Process
    )

    $candidates = [Collections.Generic.List[object]]::new()
    try {
        $Process.Refresh()
        $mainWindow = $Process.MainWindowHandle
        if ($mainWindow -ne [IntPtr]::Zero) {
            [uint32]$ownerProcessId = 0
            [void][SpaceSyndicate.GodotWindowProbeNative]::GetWindowThreadProcessId(
                $mainWindow,
                [ref]$ownerProcessId
            )
            if (
                [int]$ownerProcessId -eq $Process.Id -and
                [SpaceSyndicate.GodotWindowProbeNative]::IsWindowVisible($mainWindow) -and
                -not [SpaceSyndicate.GodotWindowProbeNative]::IsIconic($mainWindow)
            ) {
                $candidates.Add([pscustomobject][ordered]@{
                    handle = $mainWindow
                    source = "MainWindowHandle"
                    area = [int64]::MaxValue
                })
            }
        }
    } catch {
        # EnumWindows below is the authoritative fallback.
    }

    $enumHandles = [Collections.Generic.List[int64]]::new()
    $callback = [SpaceSyndicate.GodotWindowProbeNative+EnumWindowsProc]{
        param([IntPtr]$windowHandle, [IntPtr]$unused)
        [uint32]$ownerProcessId = 0
        [void][SpaceSyndicate.GodotWindowProbeNative]::GetWindowThreadProcessId(
            $windowHandle,
            [ref]$ownerProcessId
        )
        if (
            [int]$ownerProcessId -eq $Process.Id -and
            [SpaceSyndicate.GodotWindowProbeNative]::IsWindowVisible($windowHandle) -and
            -not [SpaceSyndicate.GodotWindowProbeNative]::IsIconic($windowHandle)
        ) {
            $enumHandles.Add($windowHandle.ToInt64())
        }
        return $true
    }
    [void][SpaceSyndicate.GodotWindowProbeNative]::EnumWindows(
        $callback,
        [IntPtr]::Zero
    )
    foreach ($handleValue in $enumHandles) {
        $handle = [IntPtr]::new($handleValue)
        $rect = [SpaceSyndicate.GodotWindowProbeNative+RECT]::new()
        if (-not [SpaceSyndicate.GodotWindowProbeNative]::GetClientRect(
            $handle,
            [ref]$rect
        )) {
            continue
        }
        $width = [Math]::Max(0, $rect.Right - $rect.Left)
        $height = [Math]::Max(0, $rect.Bottom - $rect.Top)
        $candidates.Add([pscustomobject][ordered]@{
            handle = $handle
            source = "EnumWindows"
            area = [int64]$width * [int64]$height
        })
    }

    if ($candidates.Count -eq 0) {
        return $null
    }
    return @($candidates | Sort-Object -Property area -Descending)[0]
}

function Write-AtomicUtf8Json {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $encoding = [Text.UTF8Encoding]::new($false)
    $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    $json = $Value | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText($temporaryPath, $json, $encoding)
    [IO.File]::Move($temporaryPath, $Path, $true)
}

function Save-WindowClientPng {
    param(
        [Parameter(Mandatory = $true)]
        [IntPtr]$WindowHandle,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 32768)]
        [int]$Width,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 32768)]
        [int]$Height,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $parent = [IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    [void][SpaceSyndicate.GodotWindowProbeNative]::SetForegroundWindow($WindowHandle)
    Start-Sleep -Milliseconds 250
    $preCaptureRect = [SpaceSyndicate.GodotWindowProbeNative+RECT]::new()
    if (-not [SpaceSyndicate.GodotWindowProbeNative]::GetClientRect(
        $WindowHandle,
        [ref]$preCaptureRect
    )) {
        throw "GetClientRect failed immediately before client capture."
    }
    $preCaptureWidth = $preCaptureRect.Right - $preCaptureRect.Left
    $preCaptureHeight = $preCaptureRect.Bottom - $preCaptureRect.Top
    if ($preCaptureWidth -ne $Width -or $preCaptureHeight -ne $Height) {
        throw (
            "Client size changed before capture: expected={0}x{1} actual={2}x{3}" -f
            $Width,
            $Height,
            $preCaptureWidth,
            $preCaptureHeight
        )
    }
    $point = [SpaceSyndicate.GodotWindowProbeNative+POINT]::new()
    $point.X = 0
    $point.Y = 0
    if (-not [SpaceSyndicate.GodotWindowProbeNative]::ClientToScreen(
        $WindowHandle,
        [ref]$point
    )) {
        throw "ClientToScreen failed for the headed Godot window."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $Width,
        $Height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = $null
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen(
            $point.X,
            $point.Y,
            0,
            0,
            $bitmap.Size,
            [Drawing.CopyPixelOperation]::SourceCopy
        )
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        if ($null -ne $graphics) {
            $graphics.Dispose()
        }
        $bitmap.Dispose()
    }
    $postCaptureSamples = [Collections.Generic.List[object]]::new()
    for ($sampleIndex = 0; $sampleIndex -lt 3; $sampleIndex += 1) {
        if (
            -not [SpaceSyndicate.GodotWindowProbeNative]::IsWindowVisible($WindowHandle) -or
            [SpaceSyndicate.GodotWindowProbeNative]::IsIconic($WindowHandle)
        ) {
            throw "Headed Godot window stopped being visible after capture."
        }
        $postCaptureRect = [SpaceSyndicate.GodotWindowProbeNative+RECT]::new()
        if (-not [SpaceSyndicate.GodotWindowProbeNative]::GetClientRect(
            $WindowHandle,
            [ref]$postCaptureRect
        )) {
            throw "GetClientRect failed after client capture."
        }
        $postCaptureWidth = $postCaptureRect.Right - $postCaptureRect.Left
        $postCaptureHeight = $postCaptureRect.Bottom - $postCaptureRect.Top
        $postCaptureSamples.Add([pscustomobject][ordered]@{
            sampled_at_utc = [DateTime]::UtcNow.ToString("o")
            width = $postCaptureWidth
            height = $postCaptureHeight
        })
        if ($postCaptureWidth -ne $Width -or $postCaptureHeight -ne $Height) {
            throw (
                "Client size changed during capture: expected={0}x{1} actual={2}x{3}" -f
                $Width,
                $Height,
                $postCaptureWidth,
                $postCaptureHeight
            )
        }
        if ($sampleIndex -lt 2) {
            Start-Sleep -Milliseconds 100
        }
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Client PNG was not created: $Path"
    }
    return [pscustomobject][ordered]@{
        path = $Path
        width = $Width
        height = $Height
        byte_length = [int64](Get-Item -LiteralPath $Path).Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        capture_method = "win32_client_copy_from_screen"
        pre_capture_client_width = $preCaptureWidth
        pre_capture_client_height = $preCaptureHeight
        post_capture_client_width = $postCaptureWidth
        post_capture_client_height = $postCaptureHeight
        post_capture_exact_sample_count = $postCaptureSamples.Count
        post_capture_samples = @($postCaptureSamples)
        capture_source_client_origin = [ordered]@{ x = $point.X; y = $point.Y }
        capture_source_client_rect = [ordered]@{
            width = $preCaptureWidth
            height = $preCaptureHeight
        }
    }
}

function Invoke-HeadedClientWindowProbe {
    param(
        [Parameter(Mandatory = $true)]
        [Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedSize,
        [Parameter(Mandatory = $true)]
        [string]$ReadyPath,
        [Parameter(Mandatory = $true)]
        [string]$AckPath,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 120)]
        [int]$ProbeTimeoutSeconds
    )

    Initialize-GodotWindowProbeNative
    $match = [regex]::Match($ExpectedSize, '^(?<width>\d+)x(?<height>\d+)$')
    $expectedWidth = [int]$match.Groups['width'].Value
    $expectedHeight = [int]$match.Groups['height'].Value
    $samples = [Collections.Generic.List[object]]::new()
    $readyRecord = $null
    $readySha256 = ""
    $windowRecord = $null
    $clientCapture = $null
    $stableExactSampleCount = 0
    $failureReason = "probe_timeout"
    $deadline = [DateTime]::UtcNow.AddSeconds($ProbeTimeoutSeconds)
    $previousDpiContext = [SpaceSyndicate.GodotWindowProbeNative]::SetThreadDpiAwarenessContext(
        [IntPtr]::new(-4)
    )

    try {
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($Process.HasExited) {
                $failureReason = "process_exited_before_probe_ack"
                break
            }

            if ($null -eq $readyRecord -and (Test-Path -LiteralPath $ReadyPath -PathType Leaf)) {
                try {
                    $readyBytes = [IO.File]::ReadAllBytes($ReadyPath)
                    $readyText = [Text.UTF8Encoding]::new($false, $true).GetString($readyBytes)
                    $candidateReady = ConvertFrom-Json -InputObject $readyText -AsHashtable
                    if ($candidateReady -isnot [Collections.IDictionary]) {
                        throw "ready payload is not a JSON object"
                    }
                    if ([int]$candidateReady.process_id -ne $Process.Id) {
                        throw "ready process_id does not match the launched Godot process"
                    }
                    if ([string]$candidateReady.expected_client_size -ne $ExpectedSize) {
                        throw "ready expected_client_size does not match the runner request"
                    }
                    $readyRecord = $candidateReady
                    $readySha256 = [Convert]::ToHexString(
                        [Security.Cryptography.SHA256]::HashData($readyBytes)
                    ).ToLowerInvariant()
                } catch {
                    $failureReason = "ready_invalid: $($_.Exception.Message)"
                    Start-Sleep -Milliseconds 50
                    continue
                }
            }

            if ($null -eq $readyRecord) {
                Start-Sleep -Milliseconds 50
                continue
            }

            $candidateWindow = Get-ProcessVisibleWindow -Process $Process
            if ($null -eq $candidateWindow) {
                $failureReason = "visible_window_not_found"
                Start-Sleep -Milliseconds 50
                continue
            }
            $windowRecord = $candidateWindow
            $windowHandle = [IntPtr]$candidateWindow.handle
            $readyHandle = [int64]$readyRecord.native_hwnd_decimal
            if ($readyHandle -ne 0 -and $readyHandle -ne $windowHandle.ToInt64()) {
                $failureReason = "driver_and_external_window_handle_mismatch"
                $stableExactSampleCount = 0
                Start-Sleep -Milliseconds 50
                continue
            }

            $rect = [SpaceSyndicate.GodotWindowProbeNative+RECT]::new()
            if (-not [SpaceSyndicate.GodotWindowProbeNative]::GetClientRect(
                $windowHandle,
                [ref]$rect
            )) {
                $failureReason = "get_client_rect_failed"
                $stableExactSampleCount = 0
                Start-Sleep -Milliseconds 50
                continue
            }
            $width = $rect.Right - $rect.Left
            $height = $rect.Bottom - $rect.Top
            $sample = [pscustomobject][ordered]@{
                sampled_at_utc = [DateTime]::UtcNow.ToString("o")
                left = $rect.Left
                top = $rect.Top
                right = $rect.Right
                bottom = $rect.Bottom
                width = $width
                height = $height
            }
            if ($samples.Count -lt 50) {
                $samples.Add($sample)
            }
            if ($width -eq $expectedWidth -and $height -eq $expectedHeight) {
                $stableExactSampleCount += 1
            } else {
                $stableExactSampleCount = 0
                $failureReason = "client_size_mismatch_${width}x${height}"
            }
            if ($stableExactSampleCount -ge 3) {
                $capturePath = [string]$readyRecord.capture_path
                if (
                    [string]::IsNullOrWhiteSpace($capturePath) -or
                    -not [IO.Path]::IsPathFullyQualified($capturePath)
                ) {
                    $failureReason = "ready_capture_path_is_not_absolute"
                    break
                }
                try {
                    $clientCapture = Save-WindowClientPng `
                        -WindowHandle $windowHandle `
                        -Width $width `
                        -Height $height `
                        -Path $capturePath
                } catch {
                    $failureReason = "client_capture_failed: $($_.Exception.Message)"
                    break
                }
                $ack = [ordered]@{
                    schema = "space_syndicate.godot_headed_client_probe_ack.v1"
                    status = "PASS"
                    process_id = $Process.Id
                    expected_client_size = $ExpectedSize
                    client_width = $width
                    client_height = $height
                    hwnd_decimal = $windowHandle.ToInt64().ToString()
                    hwnd_hex = "0x{0:X}" -f $windowHandle.ToInt64()
                    hwnd_source = [string]$candidateWindow.source
                    dpi = [int][SpaceSyndicate.GodotWindowProbeNative]::GetDpiForWindow($windowHandle)
                    ready_sha256 = $readySha256
                    probe_nonce = [string]$readyRecord.probe_nonce
                    stable_exact_sample_count = $stableExactSampleCount
                    client_capture_path = $clientCapture.path
                    client_capture_width = $clientCapture.width
                    client_capture_height = $clientCapture.height
                    client_capture_bytes = $clientCapture.byte_length
                    client_capture_sha256 = $clientCapture.sha256
                    client_capture_method = $clientCapture.capture_method
                    pre_capture_client_width = $clientCapture.pre_capture_client_width
                    pre_capture_client_height = $clientCapture.pre_capture_client_height
                    post_capture_client_width = $clientCapture.post_capture_client_width
                    post_capture_client_height = $clientCapture.post_capture_client_height
                    post_capture_exact_sample_count = $clientCapture.post_capture_exact_sample_count
                    post_capture_samples = @($clientCapture.post_capture_samples)
                    capture_source_client_origin = $clientCapture.capture_source_client_origin
                    capture_source_client_rect = $clientCapture.capture_source_client_rect
                }
                Write-AtomicUtf8Json -Path $AckPath -Value $ack
                return [pscustomobject][ordered]@{
                    required = $true
                    status = "passed"
                    failure_reason = $null
                    expected_client_size = $ExpectedSize
                    ready_path = $ReadyPath
                    ready_sha256 = $readySha256
                    probe_nonce = [string]$readyRecord.probe_nonce
                    ack_path = $AckPath
                    process_id = $Process.Id
                    hwnd_decimal = $windowHandle.ToInt64().ToString()
                    hwnd_hex = "0x{0:X}" -f $windowHandle.ToInt64()
                    hwnd_source = [string]$candidateWindow.source
                    dpi = [int]$ack.dpi
                    stable_exact_sample_count = $stableExactSampleCount
                    exact_match = $true
                    client_capture = $clientCapture
                    samples = @($samples)
                }
            }
            Start-Sleep -Milliseconds 100
        }
    } finally {
        if ($previousDpiContext -ne [IntPtr]::Zero) {
            [void][SpaceSyndicate.GodotWindowProbeNative]::SetThreadDpiAwarenessContext(
                $previousDpiContext
            )
        }
    }

    $failureAck = [ordered]@{
        schema = "space_syndicate.godot_headed_client_probe_ack.v1"
        status = "FAIL"
        process_id = $Process.Id
        expected_client_size = $ExpectedSize
        ready_sha256 = $readySha256
        probe_nonce = if ($null -ne $readyRecord) {
            [string]$readyRecord.probe_nonce
        } else { "" }
        failure_reason = $failureReason
        stable_exact_sample_count = $stableExactSampleCount
    }
    try {
        Write-AtomicUtf8Json -Path $AckPath -Value $failureAck
    } catch {
        $failureReason = "$failureReason;ack_write_failed:$($_.Exception.Message)"
    }
    return [pscustomobject][ordered]@{
        required = $true
        status = "failed"
        failure_reason = $failureReason
        expected_client_size = $ExpectedSize
        ready_path = $ReadyPath
        ready_sha256 = $readySha256
        probe_nonce = if ($null -ne $readyRecord) {
            [string]$readyRecord.probe_nonce
        } else { "" }
        ack_path = $AckPath
        process_id = $Process.Id
        hwnd_decimal = if ($null -ne $windowRecord) {
            ([IntPtr]$windowRecord.handle).ToInt64().ToString()
        } else { "" }
        hwnd_hex = if ($null -ne $windowRecord) {
            "0x{0:X}" -f ([IntPtr]$windowRecord.handle).ToInt64()
        } else { "" }
        hwnd_source = if ($null -ne $windowRecord) {
            [string]$windowRecord.source
        } else { "" }
        dpi = 0
        stable_exact_sample_count = $stableExactSampleCount
        exact_match = $false
        client_capture = $clientCapture
        samples = @($samples)
    }
}

function Get-GodotDiagnosticAudit {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$LogPaths,
        [string]$ExpectedMarker = ""
    )

    $errorPattern = [regex]::new(
        "(?im)^(?:\s*SCRIPT ERROR:.*|\s*(?:PARSE|PARSER|RUNTIME) ERROR:.*|\s*ERROR:\s*(?:Failed to load script|Failed to parse script|Could not parse script).*)$"
    )
    $markerRequired = -not [string]::IsNullOrEmpty($ExpectedMarker)
    $markerFound = $false
    $scriptErrors = [Collections.Generic.List[object]]::new()
    $diagnosticKeys = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $diagnostics = [Collections.Generic.List[object]]::new()

    foreach ($path in $LogPaths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            continue
        }
        $content = [IO.File]::ReadAllText($path)
        if ($markerRequired -and $content.IndexOf($ExpectedMarker, [StringComparison]::Ordinal) -ge 0) {
            $markerFound = $true
        }
        foreach ($match in $errorPattern.Matches($content)) {
            $scriptErrors.Add([pscustomobject][ordered]@{
                source = [IO.Path]::GetFileName($path)
                message = $match.Value.Trim()
            })
        }
        foreach ($line in ($content -split "`r?`n")) {
            $diagnosticMatch = [regex]::Match(
                $line,
                '^\s*(WARNING|ERROR):\s*(.+)$',
                [Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
            if (-not $diagnosticMatch.Success) {
                continue
            }
            $severity = $diagnosticMatch.Groups[1].Value.ToUpperInvariant()
            $message = $diagnosticMatch.Groups[2].Value.Trim()
            $key = "$severity|$message"
            if ($diagnosticKeys.Add($key)) {
                $diagnostics.Add([pscustomobject][ordered]@{
                    severity = $severity
                    message = $message
                    invalid_uid = $message.IndexOf(
                        "invalid UID:",
                        [StringComparison]::OrdinalIgnoreCase
                    ) -ge 0
                })
            }
        }
    }

    $taskErrors = @($diagnostics | Where-Object { $_.severity -eq "ERROR" })
    $unclassified = @($diagnostics | Where-Object { $_.severity -eq "WARNING" })
    $invalidUids = @($diagnostics | Where-Object { $_.invalid_uid })

    return [pscustomobject][ordered]@{
        script_error_count = $scriptErrors.Count
        first_script_error = if ($scriptErrors.Count -gt 0) { $scriptErrors[0].message } else { "" }
        script_errors = @($scriptErrors)
        marker_required = $markerRequired
        expected_completion_marker = if ($markerRequired) { $ExpectedMarker } else { $null }
        marker_found = if ($markerRequired) { $markerFound } else { $null }
        diagnostic_count = $diagnostics.Count
        task_introduced_error_count = $taskErrors.Count
        unclassified_diagnostic_count = $unclassified.Count
        invalid_uid_unclassified_count = $invalidUids.Count
        diagnostics = @($diagnostics)
    }
}

function Get-ClassCacheAudit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.PSIsContainer) {
        return [pscustomobject][ordered]@{
            present = $false
            valid = $false
            invalid_reason = "missing"
            size = [int64]0
            mtime_utc = $null
            sha256 = $null
        }
    }

    $size = [int64]$item.Length
    $mtimeUtc = $item.LastWriteTimeUtc.ToString("o")
    $sha256 = $null
    $valid = $false
    $invalidReason = $null
    try {
        $sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        if ($size -le 0) {
            $invalidReason = "empty"
        } else {
            $content = [IO.File]::ReadAllText($Path)
            if ($content.TrimStart().StartsWith("list=", [StringComparison]::Ordinal)) {
                $valid = $true
            } else {
                $invalidReason = "invalid_format"
            }
        }
    } catch {
        $invalidReason = "unreadable"
    }

    return [pscustomobject][ordered]@{
        present = $true
        valid = $valid
        invalid_reason = $invalidReason
        size = $size
        mtime_utc = $mtimeUtc
        sha256 = $sha256
    }
}

function Convert-RawLogToNormalizedText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RawPath,
        [Parameter(Mandatory = $true)]
        [string]$TextPath,
        [Parameter(Mandatory = $true)]
        [bool]$CaptureComplete
    )

    [byte[]]$bytes = [byte[]]::new(0)
    if (Test-Path -LiteralPath $RawPath -PathType Leaf) {
        $bytes = [IO.File]::ReadAllBytes($RawPath)
    }
    $encodingName = "utf-8"
    $strictDecode = $true
    $offset = 0
    $count = $bytes.Length
    $encoding = [Text.UTF8Encoding]::new($false, $true)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encodingName = "utf-16le-bom"
        $encoding = [Text.UnicodeEncoding]::new($false, $true, $true)
        $offset = 2
        $count -= 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encodingName = "utf-16be-bom"
        $encoding = [Text.UnicodeEncoding]::new($true, $true, $true)
        $offset = 2
        $count -= 2
    } elseif (
        $bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF
    ) {
        $encodingName = "utf-8-bom"
        $offset = 3
        $count -= 3
    }

    try {
        $text = $encoding.GetString($bytes, $offset, $count)
    } catch {
        $strictDecode = $false
        $encodingName = "$encodingName-invalid"
        $text = [Text.UTF8Encoding]::new($false, $false).GetString($bytes)
    }
    [IO.File]::WriteAllText($TextPath, $text, [Text.UTF8Encoding]::new($false))
    $rawNulCount = @($bytes | Where-Object { $_ -eq 0 }).Count
    $decodedNulCharacterCount = @(
        $text.ToCharArray() | Where-Object { [int]$_ -eq 0 }
    ).Count
    $replacementCharacterCount = @(
        $text.ToCharArray() | Where-Object { [int]$_ -eq 0xFFFD }
    ).Count
    $rawSha256 = if (Test-Path -LiteralPath $RawPath -PathType Leaf) {
        (Get-FileHash -LiteralPath $RawPath -Algorithm SHA256).Hash.ToLowerInvariant()
    } else {
        $null
    }
    return [pscustomobject][ordered]@{
        raw_path = $RawPath
        text_path = $TextPath
        byte_length = [int64]$bytes.Length
        sha256 = $rawSha256
        encoding = $encodingName
        strict_decode = $strictDecode
        raw_nul_count = $rawNulCount
        decoded_nul_character_count = $decodedNulCharacterCount
        replacement_character_count = $replacementCharacterCount
        capture_complete = $CaptureComplete
    }
}

function Invoke-GodotBlockingProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedGodotPath,
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 86400)]
        [int]$ProcessTimeoutSeconds,
        [Parameter(Mandatory = $true)]
        [string]$StdoutPath,
        [Parameter(Mandatory = $true)]
        [string]$StderrPath,
        [Parameter(Mandatory = $true)]
        [string]$GodotLogPath,
        [Parameter(Mandatory = $true)]
        [string]$AppDataPath,
        [Parameter(Mandatory = $true)]
        [string]$LocalAppDataPath,
        [string]$ExpectedMarker = "",
        [AllowNull()]
        [Collections.IDictionary]$HeadedProbe = $null
    )

    $startedAt = [DateTime]::UtcNow
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $environmentVariables = [ordered]@{
        APPDATA = $AppDataPath
        LOCALAPPDATA = $LocalAppDataPath
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = New-GodotProcessStartInfo `
        -ExecutablePath $ResolvedGodotPath `
        -WorkingDirectory $ResolvedProjectPath `
        -ArgumentList $ArgumentList `
        -EnvironmentVariables $environmentVariables
    $timedOut = $false
    $processExited = $false
    $processId = $null
    $processExitCode = $null
    $cleanupProcessIds = @()
    $stdoutRawPath = [IO.Path]::ChangeExtension($StdoutPath, "raw.bin")
    $stderrRawPath = [IO.Path]::ChangeExtension($StderrPath, "raw.bin")
    $stdoutRawStream = $null
    $stderrRawStream = $null
    $stdoutTask = $null
    $stderrTask = $null
    $stdoutCaptureComplete = $false
    $stderrCaptureComplete = $false
    $windowProbe = [pscustomobject][ordered]@{
        required = $false
        status = "not_requested"
        failure_reason = $null
        expected_client_size = $null
        ready_path = $null
        ready_sha256 = ""
        ack_path = $null
        process_id = $null
        hwnd_decimal = ""
        hwnd_hex = ""
        hwnd_source = ""
        dpi = 0
        stable_exact_sample_count = 0
        exact_match = $false
        client_capture = $null
        samples = @()
    }

    try {
        if (-not $process.Start()) {
            throw "Godot process did not start."
        }
        $processId = $process.Id
        $stdoutRawStream = [IO.File]::Open(
            $stdoutRawPath,
            [IO.FileMode]::Create,
            [IO.FileAccess]::Write,
            [IO.FileShare]::Read
        )
        $stderrRawStream = [IO.File]::Open(
            $stderrRawPath,
            [IO.FileMode]::Create,
            [IO.FileAccess]::Write,
            [IO.FileShare]::Read
        )
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdoutRawStream)
        $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderrRawStream)

        if ($null -ne $HeadedProbe) {
            $windowProbe = Invoke-HeadedClientWindowProbe `
                -Process $process `
                -ExpectedSize ([string]$HeadedProbe.expected_client_size) `
                -ReadyPath ([string]$HeadedProbe.ready_path) `
                -AckPath ([string]$HeadedProbe.ack_path) `
                -ProbeTimeoutSeconds ([int]$HeadedProbe.timeout_seconds)
            if ($windowProbe.status -ne "passed") {
                $processExited = $process.WaitForExit(5000)
                if (-not $processExited) {
                    [void](Stop-ScopedProcessTree `
                        -Process $process `
                        -ResolvedProjectPath $ResolvedProjectPath `
                        -ResolvedGodotPath $ResolvedGodotPath)
                    try {
                        $processExited = $process.WaitForExit(10000)
                    } catch {
                        $processExited = $false
                    }
                }
            }
        }

        $processDeadline = $startedAt.AddSeconds($ProcessTimeoutSeconds)
        while (
            -not $processExited -and
            [DateTime]::UtcNow -lt $processDeadline
        ) {
            try {
                $processExited = $process.WaitForExit(250)
            } catch {
                $processExited = $true
            }
        }
        if (-not $processExited) {
            $timedOut = $true
            $stopRequested = Stop-ScopedProcessTree `
                -Process $process `
                -ResolvedProjectPath $ResolvedProjectPath `
                -ResolvedGodotPath $ResolvedGodotPath
            if ($stopRequested) {
                try {
                    $processExited = $process.WaitForExit(10000)
                } catch {
                    $processExited = $false
                }
            }
        }

        if ($processExited) {
            try {
                $process.Refresh()
                $processExitCode = $process.ExitCode
            } catch {
                $processExitCode = $null
            }
        }

        $postExitRuntime = @(
            Get-OwnedProjectRuntimeProcess `
                -RootProcessId $processId `
                -ResolvedProjectPath $ResolvedProjectPath `
                -ResolvedGodotPath $ResolvedGodotPath
        )
        foreach ($leftover in $postExitRuntime) {
            if (Stop-VerifiedOwnedRuntimeProcess `
                -ProcessRecord $leftover `
                -ResolvedProjectPath $ResolvedProjectPath `
                -ResolvedGodotPath $ResolvedGodotPath) {
                $cleanupProcessIds += [int]$leftover.ProcessId
            }
        }

        $stdoutCaptureComplete = $stdoutTask.Wait(5000)
        if ($stdoutCaptureComplete) {
            $stdoutTask.GetAwaiter().GetResult() | Out-Null
        }
        $stderrCaptureComplete = $stderrTask.Wait(5000)
        if ($stderrCaptureComplete) {
            $stderrTask.GetAwaiter().GetResult() | Out-Null
        }
    } finally {
        $stopwatch.Stop()
        if ($null -ne $stdoutRawStream) {
            $stdoutRawStream.Dispose()
        }
        if ($null -ne $stderrRawStream) {
            $stderrRawStream.Dispose()
        }
        $process.Dispose()
    }

    $stdoutCapture = Convert-RawLogToNormalizedText `
        -RawPath $stdoutRawPath `
        -TextPath $StdoutPath `
        -CaptureComplete $stdoutCaptureComplete
    $stderrCapture = Convert-RawLogToNormalizedText `
        -RawPath $stderrRawPath `
        -TextPath $StderrPath `
        -CaptureComplete $stderrCaptureComplete
    $rawCaptureFailure = (
        -not $stdoutCapture.capture_complete -or
        -not $stderrCapture.capture_complete -or
        -not $stdoutCapture.strict_decode -or
        -not $stderrCapture.strict_decode -or
        $stdoutCapture.decoded_nul_character_count -gt 0 -or
        $stderrCapture.decoded_nul_character_count -gt 0 -or
        $stdoutCapture.replacement_character_count -gt 0 -or
        $stderrCapture.replacement_character_count -gt 0
    )

    if (-not (Test-Path -LiteralPath $GodotLogPath -PathType Leaf)) {
        New-Item -ItemType File -Path $GodotLogPath | Out-Null
    }

    $remainingRuntime = @(
        Get-OwnedProjectRuntimeProcess `
            -RootProcessId $processId `
            -ResolvedProjectPath $ResolvedProjectPath `
            -ResolvedGodotPath $ResolvedGodotPath
    )
    $diagnosticAudit = Get-GodotDiagnosticAudit `
        -LogPaths @($StdoutPath, $StderrPath, $GodotLogPath) `
        -ExpectedMarker $ExpectedMarker
    $runnerExitCode = if ($timedOut) {
        124
    } elseif ($cleanupProcessIds.Count -gt 0 -or $remainingRuntime.Count -gt 0) {
        125
    } elseif ($null -eq $processExitCode) {
        126
    } elseif ($windowProbe.required -and $windowProbe.status -ne "passed") {
        131
    } elseif ($rawCaptureFailure) {
        129
    } elseif ($processExitCode -ne 0) {
        [int]$processExitCode
    } elseif ($diagnosticAudit.script_error_count -gt 0) {
        127
    } elseif ($diagnosticAudit.task_introduced_error_count -gt 0) {
        127
    } elseif ($diagnosticAudit.unclassified_diagnostic_count -gt 0) {
        130
    } elseif ($diagnosticAudit.marker_required -and -not $diagnosticAudit.marker_found) {
        128
    } else {
        [int]$processExitCode
    }
    $status = if ($timedOut) {
        "timed_out"
    } elseif ($remainingRuntime.Count -gt 0) {
        "orphaned"
    } elseif ($cleanupProcessIds.Count -gt 0) {
        "orphan_cleaned"
    } elseif ($windowProbe.required -and $windowProbe.status -ne "passed") {
        "headed_window_probe_failed"
    } elseif ($rawCaptureFailure) {
        "raw_capture_error"
    } elseif ($processExitCode -ne 0) {
        "failed"
    } elseif ($diagnosticAudit.script_error_count -gt 0) {
        "script_error"
    } elseif ($diagnosticAudit.task_introduced_error_count -gt 0) {
        "project_error"
    } elseif ($diagnosticAudit.unclassified_diagnostic_count -gt 0) {
        "unclassified_diagnostic"
    } elseif ($diagnosticAudit.marker_required -and -not $diagnosticAudit.marker_found) {
        "marker_missing"
    } else {
        "passed"
    }

    return [pscustomobject][ordered]@{
        status = $status
        process_id = $processId
        timeout_seconds = $ProcessTimeoutSeconds
        timed_out = $timedOut
        process_exit_code = $processExitCode
        runner_exit_code = $runnerExitCode
        exit_code = $runnerExitCode
        started_at_utc = $startedAt.ToString("o")
        duration_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        duration = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        command_arguments = @($ArgumentList)
        stdout_log = $StdoutPath
        stderr_log = $StderrPath
        stdout_raw_log = $stdoutRawPath
        stderr_raw_log = $stderrRawPath
        stdout_capture = $stdoutCapture
        stderr_capture = $stderrCapture
        raw_capture_failure = $rawCaptureFailure
        window_probe = $windowProbe
        godot_log = $GodotLogPath
        appdata = $AppDataPath
        localappdata = $LocalAppDataPath
        script_error_count = $diagnosticAudit.script_error_count
        first_script_error = $diagnosticAudit.first_script_error
        script_errors = $diagnosticAudit.script_errors
        marker_required = $diagnosticAudit.marker_required
        expected_completion_marker = $diagnosticAudit.expected_completion_marker
        marker_found = $diagnosticAudit.marker_found
        diagnostic_count = $diagnosticAudit.diagnostic_count
        task_introduced_error_count = $diagnosticAudit.task_introduced_error_count
        unclassified_diagnostic_count = $diagnosticAudit.unclassified_diagnostic_count
        invalid_uid_unclassified_count = $diagnosticAudit.invalid_uid_unclassified_count
        diagnostics = $diagnosticAudit.diagnostics
        cleanup_process_ids = @($cleanupProcessIds)
        remaining_project_runtime_process_ids = @($remainingRuntime | ForEach-Object { [int]$_.ProcessId })
    }
}

$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path.TrimEnd('\', '/')
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$LogRoot = [IO.Path]::GetFullPath($LogRoot)

if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath "project.godot") -PathType Leaf)) {
    throw "project.godot was not found under $ProjectPath"
}
if ([IO.Path]::GetFileName($GodotPath) -match '(?i)_console\.exe$') {
    throw "The console wrapper is not accepted because it can return before the Godot test process: $GodotPath"
}

$godotVersion = (Get-Item -LiteralPath $GodotPath).VersionInfo.ProductVersion
if ($godotVersion -notmatch '^4\.7(?:\.|$)') {
    throw "Godot 4.7 is required, but $GodotPath reports ProductVersion '$godotVersion'."
}

$targetType = if ($PSCmdlet.ParameterSetName -eq "Scene") { "scene" } else { "script" }
$targetPath = if ($targetType -eq "scene") { $Scene } else { $TestScript }
$relativeTargetPath = $targetPath.Substring("res://".Length).Replace('/', [IO.Path]::DirectorySeparatorChar)
$absoluteTargetPath = [IO.Path]::GetFullPath((Join-Path $ProjectPath $relativeTargetPath))
$projectPrefix = $ProjectPath + [IO.Path]::DirectorySeparatorChar
if (-not $absoluteTargetPath.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Godot target must stay inside the project: $targetPath"
}
if (-not (Test-Path -LiteralPath $absoluteTargetPath -PathType Leaf)) {
    throw "Godot target was not found: $absoluteTargetPath"
}

$preexistingRuntime = @(Get-ProjectRuntimeProcess -ResolvedProjectPath $ProjectPath -ResolvedGodotPath $GodotPath)
if ($preexistingRuntime.Count -gt 0) {
    $ids = ($preexistingRuntime | ForEach-Object { $_.ProcessId }) -join ", "
    throw "Refusing to overlap an existing Godot headless/game process for this project. PIDs: $ids"
}

$testName = [IO.Path]::GetFileNameWithoutExtension($absoluteTargetPath)
$safeTestName = [regex]::Replace($testName, '[^A-Za-z0-9_.-]', '_')
$runId = "{0}-{1}-{2}" -f [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff"), $safeTestName, ([guid]::NewGuid().ToString("N").Substring(0, 8))
$runDirectory = Join-Path $LogRoot $runId
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null

$isolatedProfileRoot = if ([string]::IsNullOrWhiteSpace($IsolatedUserDataRoot)) {
    Join-Path $runDirectory "isolated-user-data"
} else {
    [IO.Path]::GetFullPath($IsolatedUserDataRoot)
}
$isolatedAppDataPath = Join-Path $isolatedProfileRoot "appdata-roaming"
$isolatedLocalAppDataPath = Join-Path $isolatedProfileRoot "appdata-local"
[IO.Directory]::CreateDirectory($isolatedAppDataPath) | Out-Null
[IO.Directory]::CreateDirectory($isolatedLocalAppDataPath) | Out-Null

$stdoutPath = Join-Path $runDirectory "stdout.log"
$stderrPath = Join-Path $runDirectory "stderr.log"
$godotLogPath = Join-Path $runDirectory "godot.log"
$importStdoutPath = Join-Path $runDirectory "import.stdout.log"
$importStderrPath = Join-Path $runDirectory "import.stderr.log"
$importGodotLogPath = Join-Path $runDirectory "import.godot.log"
$resultPath = Join-Path $runDirectory "result.json"
$windowReadyPath = Join-Path $runDirectory "window-ready.json"
$windowAckPath = Join-Path $runDirectory "window-ack.json"
$arguments = @()
if ($HeadedClientProbe) {
    $arguments += @("--windowed", "--resolution", $ExpectedClientSize)
} else {
    $arguments += "--headless"
}
$arguments += @("--path", $ProjectPath, "--log-file", $godotLogPath)
if ($targetType -eq "scene") {
    $arguments += @("--scene", $Scene)
} else {
    $arguments += @("--script", $TestScript)
}
$arguments += @($TestArgument)
if ($HeadedClientProbe) {
    $arguments += @(
        "--window-probe-ready=$windowReadyPath",
        "--window-probe-ack=$windowAckPath",
        "--expected-client-size=$ExpectedClientSize"
    )
}
$headedProbeConfig = if ($HeadedClientProbe) {
    [ordered]@{
        expected_client_size = $ExpectedClientSize
        ready_path = $windowReadyPath
        ack_path = $windowAckPath
        timeout_seconds = $WindowProbeTimeoutSeconds
    }
} else {
    $null
}

$classCachePath = Join-Path $ProjectPath ".godot\global_script_class_cache.cfg"
$cacheBefore = Get-ClassCacheAudit -Path $classCachePath
$importMode = if ($RefreshImport) {
    "refresh"
} elseif ($EnsureImported) {
    "ensure"
} else {
    "none"
}
$importRequested = $importMode -ne "none"
$importReason = if ($RefreshImport) {
    "refresh_requested"
} elseif (-not $EnsureImported) {
    "not_requested"
} elseif (-not $cacheBefore.present) {
    "cache_missing"
} elseif (-not $cacheBefore.valid) {
    "cache_invalid"
} else {
    "cache_valid"
}
$importRecord = [ordered]@{
    requested = $importRequested
    mode = $importMode
    reason = $importReason
    cache_path = $classCachePath
    cache_present_before = [bool]$cacheBefore.present
    cache_valid_before = [bool]$cacheBefore.valid
    cache_invalid_reason_before = $cacheBefore.invalid_reason
    cache_size_before = [int64]$cacheBefore.size
    cache_mtime_utc_before = $cacheBefore.mtime_utc
    cache_sha256_before = $cacheBefore.sha256
    attempted = $false
    status = if ($importRequested) { "pending" } else { "not_requested" }
    process_status = $null
    succeeded = $null
    process_id = $null
    timeout_seconds = $ImportTimeoutSeconds
    timed_out = $false
    process_exit_code = $null
    runner_exit_code = $null
    started_at_utc = $null
    duration_seconds = 0.0
    command_arguments = @()
    stdout_log = $null
    stderr_log = $null
    godot_log = $null
    stdout_raw_log = $null
    stderr_raw_log = $null
    stdout_capture = $null
    stderr_capture = $null
    raw_capture_failure = $null
    diagnostic_count = 0
    task_introduced_error_count = 0
    unclassified_diagnostic_count = 0
    invalid_uid_unclassified_count = 0
    diagnostics = @()
    cleanup_process_ids = @()
    remaining_project_runtime_process_ids = @()
    cache_present_after = [bool]$cacheBefore.present
    cache_valid_after = [bool]$cacheBefore.valid
    cache_invalid_reason_after = $cacheBefore.invalid_reason
    cache_size_after = [int64]$cacheBefore.size
    cache_mtime_utc_after = $cacheBefore.mtime_utc
    cache_sha256_after = $cacheBefore.sha256
    cache_changed = $false
    cache_size_delta = [int64]0
}

$importReady = $true
$importFailureStatus = $null
$importFailureExitCode = $null
if ($importMode -eq "ensure" -and $cacheBefore.valid) {
    $importRecord.status = "cache_valid"
    $importRecord.succeeded = $true
} elseif ($importRequested) {
    $importArguments = @(
        "--headless",
        "--path", $ProjectPath,
        "--log-file", $importGodotLogPath,
        "--import"
    )
    $importRecord.attempted = $true
    $importProcess = Invoke-GodotBlockingProcess `
        -ResolvedProjectPath $ProjectPath `
        -ResolvedGodotPath $GodotPath `
        -ArgumentList $importArguments `
        -ProcessTimeoutSeconds $ImportTimeoutSeconds `
        -StdoutPath $importStdoutPath `
        -StderrPath $importStderrPath `
        -GodotLogPath $importGodotLogPath `
        -AppDataPath $isolatedAppDataPath `
        -LocalAppDataPath $isolatedLocalAppDataPath
    $importRecord.process_status = $importProcess.status
    foreach ($property in $importProcess.PSObject.Properties) {
        if ($property.Name -ne "status") {
            $importRecord[$property.Name] = $property.Value
        }
    }
    $cacheAfter = Get-ClassCacheAudit -Path $classCachePath
    $importRecord.cache_present_after = [bool]$cacheAfter.present
    $importRecord.cache_valid_after = [bool]$cacheAfter.valid
    $importRecord.cache_invalid_reason_after = $cacheAfter.invalid_reason
    $importRecord.cache_size_after = [int64]$cacheAfter.size
    $importRecord.cache_mtime_utc_after = $cacheAfter.mtime_utc
    $importRecord.cache_sha256_after = $cacheAfter.sha256
    $importRecord.cache_changed = $cacheBefore.sha256 -ne $cacheAfter.sha256
    $importRecord.cache_size_delta = [int64]$cacheAfter.size - [int64]$cacheBefore.size
    $importReady = $importProcess.status -eq "passed" -and [bool]$cacheAfter.valid
    $importRecord.succeeded = $importReady
    if ($importReady) {
        $importRecord.status = if ($importMode -eq "refresh") { "refreshed" } else { "bootstrapped" }
    } elseif ($importProcess.status -eq "passed") {
        if (-not $cacheAfter.present) {
            $importRecord.status = "cache_missing_after_import"
            $importFailureStatus = "import_cache_missing"
        } else {
            $importRecord.status = "cache_invalid_after_import"
            $importFailureStatus = "import_cache_invalid"
        }
        $importFailureExitCode = 126
    } else {
        $importRecord.status = $importProcess.status
        $importFailureStatus = "import_$($importProcess.status)"
        $importFailureExitCode = [int]$importProcess.runner_exit_code
        if ($importFailureExitCode -eq 0) {
            $importFailureExitCode = 126
        }
    }
}

$testStarted = $false
$testProcess = $null
if ($importReady) {
    $testStarted = $true
    $testProcess = Invoke-GodotBlockingProcess `
        -ResolvedProjectPath $ProjectPath `
        -ResolvedGodotPath $GodotPath `
        -ArgumentList $arguments `
        -ProcessTimeoutSeconds $TimeoutSeconds `
        -StdoutPath $stdoutPath `
        -StderrPath $stderrPath `
        -GodotLogPath $godotLogPath `
        -AppDataPath $isolatedAppDataPath `
        -LocalAppDataPath $isolatedLocalAppDataPath `
        -ExpectedMarker $ExpectedCompletionMarker `
        -HeadedProbe $headedProbeConfig
}

$status = if ($testStarted) { $testProcess.status } else { $importFailureStatus }
$runnerExitCode = if ($testStarted) { [int]$testProcess.runner_exit_code } else { [int]$importFailureExitCode }
$remainingRuntimeIds = [Collections.Generic.HashSet[int]]::new()
foreach ($processId in @($importRecord.remaining_project_runtime_process_ids)) {
    if ($null -ne $processId) {
        $remainingRuntimeIds.Add([int]$processId) | Out-Null
    }
}
if ($testStarted) {
    foreach ($processId in @($testProcess.remaining_project_runtime_process_ids)) {
        if ($null -ne $processId) {
            $remainingRuntimeIds.Add([int]$processId) | Out-Null
        }
    }
}
$reportedCommandArguments = [Collections.Generic.List[string]]::new()
$reportedCleanupProcessIds = [Collections.Generic.List[int]]::new()
if ($testStarted) {
    foreach ($argument in $arguments) {
        $reportedCommandArguments.Add([string]$argument)
    }
    foreach ($cleanupProcessId in @($testProcess.cleanup_process_ids)) {
        if ($null -ne $cleanupProcessId) {
            $reportedCleanupProcessIds.Add([int]$cleanupProcessId)
        }
    }
} else {
    foreach ($cleanupProcessId in @($importRecord.cleanup_process_ids)) {
        if ($null -ne $cleanupProcessId) {
            $reportedCleanupProcessIds.Add([int]$cleanupProcessId)
        }
    }
}

$result = [ordered]@{
    run_id = $runId
    status = $status
    target_type = $targetType
    target_path = $targetPath
    test_script = if ($targetType -eq "script") { $TestScript } else { $null }
    scene = if ($targetType -eq "scene") { $Scene } else { $null }
    test_arguments = @($TestArgument)
    headed_client_probe = [bool]$HeadedClientProbe
    expected_client_size = if ($HeadedClientProbe) { $ExpectedClientSize } else { $null }
    window_probe_timeout_seconds = $WindowProbeTimeoutSeconds
    project_path = $ProjectPath
    godot_path = $GodotPath
    godot_product_version = $godotVersion
    ensure_imported = [bool]$EnsureImported
    refresh_import = [bool]$RefreshImport
    import_mode = $importMode
    import_status = $importRecord.status
    import = $importRecord
    test_started = $testStarted
    process_id = if ($testStarted) { $testProcess.process_id } else { $null }
    timeout_seconds = $TimeoutSeconds
    timed_out = if ($testStarted) { $testProcess.timed_out } else { $importRecord.timed_out }
    process_exit_code = if ($testStarted) { $testProcess.process_exit_code } else { $null }
    runner_exit_code = $runnerExitCode
    exit_code = $runnerExitCode
    started_at_utc = if ($testStarted) { $testProcess.started_at_utc } else { $importRecord.started_at_utc }
    duration_seconds = if ($testStarted) { $testProcess.duration_seconds } else { $importRecord.duration_seconds }
    duration = if ($testStarted) { $testProcess.duration } else { $importRecord.duration_seconds }
    command_arguments = $reportedCommandArguments
    stdout_log = if ($testStarted) { $stdoutPath } else { $null }
    stderr_log = if ($testStarted) { $stderrPath } else { $null }
    stdout_raw_log = if ($testStarted) { $testProcess.stdout_raw_log } else { $null }
    stderr_raw_log = if ($testStarted) { $testProcess.stderr_raw_log } else { $null }
    stdout_capture = if ($testStarted) { $testProcess.stdout_capture } else { $null }
    stderr_capture = if ($testStarted) { $testProcess.stderr_capture } else { $null }
    raw_capture_failure = if ($testStarted) { $testProcess.raw_capture_failure } else { $null }
    window_probe = if ($testStarted) { $testProcess.window_probe } else { $null }
    godot_log = if ($testStarted) { $godotLogPath } else { $null }
    isolated_user_data_root = $isolatedProfileRoot
    appdata = $isolatedAppDataPath
    localappdata = $isolatedLocalAppDataPath
    script_error_count = if ($testStarted) { $testProcess.script_error_count } else { $importRecord.script_error_count }
    first_script_error = if ($testStarted) { $testProcess.first_script_error } else { $importRecord.first_script_error }
    diagnostic_count = if ($testStarted) { $testProcess.diagnostic_count } else { $importRecord.diagnostic_count }
    task_introduced_error_count = if ($testStarted) { $testProcess.task_introduced_error_count } else { $importRecord.task_introduced_error_count }
    unclassified_diagnostic_count = if ($testStarted) { $testProcess.unclassified_diagnostic_count } else { $importRecord.unclassified_diagnostic_count }
    invalid_uid_unclassified_count = if ($testStarted) { $testProcess.invalid_uid_unclassified_count } else { $importRecord.invalid_uid_unclassified_count }
    diagnostics = if ($testStarted) { $testProcess.diagnostics } else { $importRecord.diagnostics }
    marker_required = if ($testStarted) { $testProcess.marker_required } else { -not [string]::IsNullOrEmpty($ExpectedCompletionMarker) }
    expected_completion_marker = if ([string]::IsNullOrEmpty($ExpectedCompletionMarker)) { $null } else { $ExpectedCompletionMarker }
    marker_found = if ($testStarted) { $testProcess.marker_found } else { $null }
    cleanup_process_ids = $reportedCleanupProcessIds
    remaining_project_runtime_process_ids = @($remainingRuntimeIds)
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding utf8
$result["result_json"] = $resultPath
$result | ConvertTo-Json -Depth 10 -Compress | Write-Output
exit $runnerExitCode
