param(
    [string]$CommonScript = (Join-Path $PSScriptRoot "role_godot_mcp_common.ps1")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. $CommonScript

$categories = [ordered]@{
    codec = [ordered]@{ passed = 0; total = 0 }
    json_roundtrip = [ordered]@{ passed = 0; total = 0 }
    cultures = [ordered]@{ passed = 0; total = 0 }
    source = [ordered]@{ passed = 0; total = 0 }
    process_identity_v3 = [ordered]@{ passed = 0; total = 0 }
}
$failures = [System.Collections.Generic.List[string]]::new()
$unhandled = 0
$engineEvidence = [ordered]@{}

function Invoke-WireCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Body
    )

    $categories[$Category].total = [int]$categories[$Category].total + 1
    try {
        if ([bool](& $Body)) {
            $categories[$Category].passed = [int]$categories[$Category].passed + 1
        } else {
            $failures.Add("$Category|$Name|assertion_failed")
        }
    } catch {
        $script:unhandled += 1
        $failures.Add("$Category|$Name|unhandled=$($_.Exception.GetType().FullName):$($_.Exception.Message)")
    }
}

function Copy-WireObject {
    param([Parameter(Mandatory = $true)][object]$Object)
    return $Object | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
}

function Get-ConnectionValueCounts {
    param([AllowNull()][object]$Value)

    $counts = [ordered]@{ datetime = 0; unsafe_integer = 0 }
    function Visit-ConnectionValue {
        param([AllowNull()][object]$Current)
        if ($null -eq $Current) { return }
        if ($Current -is [DateTime] -or $Current -is [DateTimeOffset]) {
            $counts.datetime += 1
            return
        }
        if ($Current -is [byte] -or $Current -is [sbyte] -or $Current -is [short] -or $Current -is [ushort] -or $Current -is [int] -or $Current -is [uint] -or $Current -is [long] -or $Current -is [ulong]) {
            try {
                if ([decimal]$Current -gt [decimal]9007199254740991 -or [decimal]$Current -lt [decimal]-9007199254740991) {
                    $counts.unsafe_integer += 1
                }
            } catch {
                $counts.unsafe_integer += 1
            }
            return
        }
        if ($Current -is [string] -or $Current.GetType().IsPrimitive) { return }
        if ($Current -is [System.Collections.IDictionary]) {
            foreach ($key in $Current.Keys) { Visit-ConnectionValue -Current $Current[$key] }
            return
        }
        if ($Current -is [System.Collections.IEnumerable]) {
            foreach ($item in $Current) { Visit-ConnectionValue -Current $item }
            return
        }
        foreach ($property in $Current.PSObject.Properties) {
            Visit-ConnectionValue -Current $property.Value
        }
    }
    Visit-ConnectionValue -Current $Value
    return $counts
}

function Invoke-EngineJsonProbe {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string]$ProbePath
    )

    $output = @(& $Executable -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $ProbePath 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "engine_probe_failed|executable=$Executable|exit_code=$LASTEXITCODE|output=$($output -join ' ')"
    }
    return ($output -join "`n") | ConvertFrom-Json
}

$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$roundtripStyles = [System.Globalization.DateTimeStyles]::RoundtripKind
$rawSevenFraction = [DateTime]::ParseExact("2026-08-03T10:55:34.9642428Z", "o", $invariant, $roundtripStyles)
$rawZeroFraction = [DateTime]::ParseExact("2026-08-03T10:55:34Z", "yyyy-MM-dd'T'HH:mm:ssK", $invariant, $roundtripStyles)
$expectedSevenFileTime = $rawSevenFraction.ToFileTimeUtc()
$encodedSeven = ConvertTo-RoleGodotCreationTimeToken -CreationTime $rawSevenFraction
$encodedZero = ConvertTo-RoleGodotCreationTimeToken -CreationTime $rawZeroFraction

Invoke-WireCase codec "seven_fraction_digits" {
    $encodedSeven.valid -and $encodedSeven.token.value -eq $expectedSevenFileTime.ToString($invariant)
}
Invoke-WireCase codec "zero_fraction_digits" {
    $encodedZero.valid -and (ConvertFrom-RoleGodotCreationTimeToken -Token $encodedZero.token).filetime_utc -eq $rawZeroFraction.ToFileTimeUtc()
}
Invoke-WireCase codec "utc_datetime" {
    $utc = [DateTime]::SpecifyKind($rawSevenFraction, [DateTimeKind]::Utc)
    (ConvertFrom-RoleGodotCreationTimeToken -Token (ConvertTo-RoleGodotCreationTimeToken -CreationTime $utc).token).filetime_utc -eq $utc.ToFileTimeUtc()
}
Invoke-WireCase codec "local_datetime" {
    $local = $rawSevenFraction.ToLocalTime()
    (ConvertFrom-RoleGodotCreationTimeToken -Token (ConvertTo-RoleGodotCreationTimeToken -CreationTime $local).token).filetime_utc -eq $local.ToFileTimeUtc()
}
Invoke-WireCase codec "unspecified_datetime" {
    $unspecified = [DateTime]::SpecifyKind($rawSevenFraction, [DateTimeKind]::Unspecified)
    (ConvertFrom-RoleGodotCreationTimeToken -Token (ConvertTo-RoleGodotCreationTimeToken -CreationTime $unspecified).token).filetime_utc -eq $unspecified.ToUniversalTime().ToFileTimeUtc()
}
Invoke-WireCase codec "dst_boundary_values" {
    $before = [DateTime]::ParseExact("2026-03-08T06:59:59.9999999Z", "o", $invariant, $roundtripStyles)
    $after = $before.AddTicks(1)
    $beforeDecoded = ConvertFrom-RoleGodotCreationTimeToken -Token (ConvertTo-RoleGodotCreationTimeToken -CreationTime $before).token
    $afterDecoded = ConvertFrom-RoleGodotCreationTimeToken -Token (ConvertTo-RoleGodotCreationTimeToken -CreationTime $after).token
    $beforeDecoded.filetime_utc + 1 -eq $afterDecoded.filetime_utc
}
Invoke-WireCase codec "malformed_codec" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "unknown"; value = "0"; source = "system_diagnostics_process_start_time" })).failure_reason -eq "process_creation_time_codec_invalid"
}
Invoke-WireCase codec "codec_array_rejected" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = @("windows_filetime_utc_decimal_v1"); value = "0"; source = "system_diagnostics_process_start_time" })).failure_reason -eq "process_creation_time_codec_invalid"
}
Invoke-WireCase codec "malformed_decimal" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "12x"; source = "system_diagnostics_process_start_time" })).failure_reason -eq "process_creation_time_value_invalid"
}
Invoke-WireCase codec "leading_zero" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "01"; source = "system_diagnostics_process_start_time" })).failure_reason -eq "process_creation_time_value_invalid"
}
Invoke-WireCase codec "negative_value" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "-1"; source = "system_diagnostics_process_start_time" })).failure_reason -eq "process_creation_time_value_invalid"
}
Invoke-WireCase codec "exponent_notation" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "1e3"; source = "system_diagnostics_process_start_time" })).failure_reason -eq "process_creation_time_value_invalid"
}
Invoke-WireCase codec "json_number_rejected" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = [long]$expectedSevenFileTime; source = "system_diagnostics_process_start_time" })).failure_reason -eq "process_creation_time_value_invalid"
}
Invoke-WireCase codec "int64_overflow" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "9223372036854775808"; source = "system_diagnostics_process_start_time" })).failure_reason -eq "process_creation_time_value_out_of_range"
}
Invoke-WireCase codec "datetime_range_overflow" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "9223372036854775807"; source = "system_diagnostics_process_start_time" })).failure_reason -eq "process_creation_time_value_out_of_range"
}
Invoke-WireCase codec "filetime_epoch" {
    $decoded = ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "0"; source = "system_diagnostics_process_start_time" })
    $decoded.valid -and $decoded.filetime_utc -eq 0
}

$wireRoundTrip = Copy-WireObject -Object ([ordered]@{ process_creation_time = $encodedSeven.token })
Invoke-WireCase json_roundtrip "tag_value_stays_string" {
    $wireRoundTrip.process_creation_time.value -is [string]
}
Invoke-WireCase json_roundtrip "tag_value_exact" {
    $wireRoundTrip.process_creation_time.value -eq $expectedSevenFileTime.ToString($invariant)
}
Invoke-WireCase json_roundtrip "tag_decodes_exact" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token $wireRoundTrip.process_creation_time).filetime_utc -eq $expectedSevenFileTime
}
Invoke-WireCase json_roundtrip "default_string_changes_but_ticks_survive_pwsh" {
    $dateAfter = (@{ value = $rawSevenFraction } | ConvertTo-Json -Compress | ConvertFrom-Json).value
    $dateAfter -is [DateTime] -and $dateAfter.Ticks -eq $rawSevenFraction.Ticks -and [string]$dateAfter -ne $dateAfter.ToString("o")
}
Invoke-WireCase json_roundtrip "actual_tick_change_detected" {
    $oneTickLater = ConvertTo-RoleGodotCreationTimeToken -CreationTime $rawSevenFraction.AddTicks(1)
    $encodedSeven.token.value -ne $oneTickLater.token.value
}

$probeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("role-godot-time-wire-{0}" -f [guid]::NewGuid().ToString("N"))
[System.IO.Directory]::CreateDirectory($probeRoot) | Out-Null
$probePath = Join-Path $probeRoot "json-probe.ps1"
$probeSource = @'
$ErrorActionPreference = "Stop"
$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$styles = [System.Globalization.DateTimeStyles]::RoundtripKind
$raw = [DateTime]::ParseExact("2026-08-03T10:55:34.9642428Z", "o", $invariant, $styles)
$fileTime = $raw.ToFileTimeUtc()
$token = [ordered]@{
    codec = "windows_filetime_utc_decimal_v1"
    value = $fileTime.ToString($invariant)
    source = "system_diagnostics_process_start_time"
}
$wireJson = @{ process_creation_time = $token } | ConvertTo-Json -Depth 6 -Compress
$wireAfter = $wireJson | ConvertFrom-Json
$dateJson = @{ value = $raw } | ConvertTo-Json -Compress
$dateAfter = ($dateJson | ConvertFrom-Json).value
[ordered]@{
    version = $PSVersionTable.PSVersion.ToString()
    wire_json = $wireJson
    wire_value_type = $wireAfter.process_creation_time.value.GetType().FullName
    wire_value = [string]$wireAfter.process_creation_time.value
    raw_before_ticks = $raw.Ticks.ToString($invariant)
    raw_after_ticks = if ($dateAfter -is [DateTime]) { $dateAfter.Ticks.ToString($invariant) } else { "not_datetime" }
    raw_before_filetime_utc = $fileTime.ToString($invariant)
    raw_after_filetime_utc = if ($dateAfter -is [DateTime]) { $dateAfter.ToFileTimeUtc().ToString($invariant) } else { "not_datetime" }
    date_json = $dateJson
} | ConvertTo-Json -Depth 6 -Compress
'@
[System.IO.File]::WriteAllText($probePath, $probeSource, [System.Text.UTF8Encoding]::new($false))
try {
    $pwshCommand = Get-Command pwsh.exe -ErrorAction Stop
    $windowsPowerShellCommand = Get-Command powershell.exe -ErrorAction Stop
    $pwshEvidence = Invoke-EngineJsonProbe -Executable $pwshCommand.Source -ProbePath $probePath
    $windowsPowerShellEvidence = Invoke-EngineJsonProbe -Executable $windowsPowerShellCommand.Source -ProbePath $probePath
    $engineEvidence.pwsh = $pwshEvidence
    $engineEvidence.windows_powershell = $windowsPowerShellEvidence

    Invoke-WireCase json_roundtrip "pwsh_tag_roundtrip" {
        $pwshEvidence.wire_value_type -eq "System.String" -and $pwshEvidence.wire_value -eq $expectedSevenFileTime.ToString($invariant)
    }
    Invoke-WireCase json_roundtrip "windows_powershell_tag_roundtrip" {
        $windowsPowerShellEvidence.wire_value_type -eq "System.String" -and $windowsPowerShellEvidence.wire_value -eq $expectedSevenFileTime.ToString($invariant)
    }
    Invoke-WireCase json_roundtrip "pwsh_datetime_ticks_characterized" {
        $pwshEvidence.raw_before_ticks -eq $pwshEvidence.raw_after_ticks -and $pwshEvidence.raw_before_filetime_utc -eq $pwshEvidence.raw_after_filetime_utc
    }
    Invoke-WireCase json_roundtrip "windows_powershell_datetime_loss_characterized" {
        $windowsPowerShellEvidence.raw_after_ticks -ne "not_datetime" `
            -and [long]$windowsPowerShellEvidence.raw_before_filetime_utc -ne [long]$windowsPowerShellEvidence.raw_after_filetime_utc `
            -and ([long]$windowsPowerShellEvidence.raw_before_filetime_utc - [long]$windowsPowerShellEvidence.raw_after_filetime_utc) -eq 2428
    }
} finally {
    if ([System.IO.Directory]::Exists($probeRoot)) {
        [System.IO.Directory]::Delete($probeRoot, $true)
    }
}

$savedCulture = [System.Globalization.CultureInfo]::CurrentCulture
$savedUiCulture = [System.Globalization.CultureInfo]::CurrentUICulture
try {
    $expectedFingerprint = $null
    foreach ($cultureName in @("en-US", "zh-CN", "ja-JP")) {
        $culture = [System.Globalization.CultureInfo]::GetCultureInfo($cultureName)
        [System.Globalization.CultureInfo]::CurrentCulture = $culture
        [System.Globalization.CultureInfo]::CurrentUICulture = $culture
        $cultureToken = ConvertTo-RoleGodotCreationTimeToken -CreationTime $rawSevenFraction
        Invoke-WireCase cultures "$cultureName-token" {
            $cultureToken.token.value -eq $expectedSevenFileTime.ToString($invariant)
        }
        $cultureIdentity = [ordered]@{
            schema = "RoleGodotProcessIdentityV3"; schema_version = 3; role = "Supervisor"; session_id = "culture"
            process_id = 4242; process_creation_time = $cultureToken.token
            expected_executable_path = "C:\Godot.exe"; observed_executable_path = "C:\Godot.exe"
            executable_path_source = "win32_process_executable_path"; command_line_sha256 = ("a" * 64)
            project_path = "C:\Project"; project_head_sha = ("b" * 40); endpoint = "http://127.0.0.1:1/"
            endpoint_owner_pid = 4242; identity_verified = $true; failure_reason = "none"
        }
        $fingerprint = Get-RoleGodotProcessIdentityFingerprintV3 -Identity $cultureIdentity
        if ($null -eq $expectedFingerprint) { $expectedFingerprint = $fingerprint }
        Invoke-WireCase cultures "$cultureName-fingerprint" {
            $fingerprint -eq $expectedFingerprint
        }
    }
} finally {
    [System.Globalization.CultureInfo]::CurrentCulture = $savedCulture
    [System.Globalization.CultureInfo]::CurrentUICulture = $savedUiCulture
}

Invoke-WireCase source "missing_tag" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token $null).failure_reason -eq "process_creation_time_tag_missing"
}
Invoke-WireCase source "missing_source" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "0" })).failure_reason -eq "process_creation_time_tag_missing"
}
Invoke-WireCase source "unknown_source" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "0"; source = "unknown" })).failure_reason -eq "process_creation_time_source_invalid"
}
Invoke-WireCase source "source_array_rejected" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token ([ordered]@{ codec = "windows_filetime_utc_decimal_v1"; value = "0"; source = @("system_diagnostics_process_start_time") })).failure_reason -eq "process_creation_time_source_invalid"
}
Invoke-WireCase source "source_changed" {
    (ConvertFrom-RoleGodotCreationTimeToken -Token $encodedSeven.token -ExpectedSource "win32_process_creation_date").failure_reason -eq "process_creation_time_source_changed"
}
Invoke-WireCase source "fixed_source_exact" {
    $decoded = ConvertFrom-RoleGodotCreationTimeToken -Token $encodedSeven.token -ExpectedSource "system_diagnostics_process_start_time"
    $decoded.valid -and $decoded.source -eq "system_diagnostics_process_start_time"
}
Invoke-WireCase source "single_encoder_source" {
    ([regex]::Matches([System.IO.File]::ReadAllText($CommonScript), '(?m)^function ConvertTo-RoleGodotCreationTimeToken\s*\{')).Count -eq 1
}
Invoke-WireCase source "single_decoder_source" {
    ([regex]::Matches([System.IO.File]::ReadAllText($CommonScript), '(?m)^function ConvertFrom-RoleGodotCreationTimeToken\s*\{')).Count -eq 1
}

$pwshPath = ConvertTo-McpNormalizedPath -Path ([string](Get-Process -Id $PID).Path)
$fakeStart = $rawSevenFraction
$fakeProcess = [pscustomobject]@{
    Id = 4242; HasExited = $false; StartTime = $fakeStart; Path = $pwshPath; MainModule = $null
    StartInfo = [pscustomobject]@{ FileName = $pwshPath }
}
$fakeCommandLine = '"C:\pwsh.exe" --path "C:\测试 Project" --role-godot-mcp-session-id=synthetic-session'
$fakeCim = [pscustomobject]@{
    ProcessId = 4242; CreationDate = $fakeStart; ExecutablePath = $pwshPath; CommandLine = $fakeCommandLine
}
$completeIdentity = New-RoleGodotProcessIdentityV3 `
    -Process $fakeProcess -Role Supervisor -SessionId synthetic-session -ExpectedExecutablePath $pwshPath `
    -ProjectPath "C:\测试 Project" -ProjectHeadSha ("c" * 40) -Endpoint "http://127.0.0.1:12345/" `
    -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -RequireEndpointOwner `
    -EndpointOwnerPidOverride 4242 -IdentityReadTimeoutMilliseconds 0
$completeConnection = [ordered]@{
    schema = "RoleGodotMcpConnectionV4"; process_identity = $completeIdentity
    process_creation_time = $completeIdentity.process_creation_time
    pid = 4242; endpoint_owner_pid = 4242; port = 12345
    session_id = "synthetic-session"; role = "Supervisor"
    godot_path = $completeIdentity.observed_executable_path
    worktree = $completeIdentity.project_path
    project_head_sha = $completeIdentity.project_head_sha
    endpoint = $completeIdentity.endpoint
}

Invoke-WireCase process_identity_v3 "complete_identity_match" {
    $completeIdentity.identity_verified -and $completeIdentity.failure_reason -eq "none"
}
Invoke-WireCase process_identity_v3 "v3_schema" {
    $completeIdentity.schema -eq "RoleGodotProcessIdentityV3" -and [int]$completeIdentity.schema_version -eq 3
}
Invoke-WireCase process_identity_v3 "canonical_fingerprint" {
    $completeIdentity.identity_fingerprint_sha256 -match '^[0-9a-f]{64}$' `
        -and $completeIdentity.identity_fingerprint_sha256 -eq (Get-RoleGodotProcessIdentityFingerprintV3 -Identity $completeIdentity)
}
Invoke-WireCase process_identity_v3 "fingerprint_property_order_stable" {
    $reordered = [ordered]@{}
    foreach ($name in @($completeIdentity.Keys | Sort-Object -Descending)) { $reordered[$name] = $completeIdentity[$name] }
    (Get-RoleGodotProcessIdentityFingerprintV3 -Identity $reordered) -eq $completeIdentity.identity_fingerprint_sha256
}
Invoke-WireCase process_identity_v3 "same_pid_different_creation_rejected" {
    $oldToken = (ConvertTo-RoleGodotCreationTimeToken -CreationTime $fakeStart.AddTicks(-1)).token
    $tested = New-RoleGodotProcessIdentityV3 `
        -Process $fakeProcess -Role Supervisor -SessionId synthetic-session -ExpectedExecutablePath $pwshPath `
        -ExpectedCreationTimeToken $oldToken -ProjectPath "C:\测试 Project" -ProjectHeadSha ("c" * 40) `
        -Endpoint "http://127.0.0.1:12345/" -ProvidedCimProcess $fakeCim -UseProvidedCimProcess `
        -EndpointOwnerPidOverride 4242 -IdentityReadTimeoutMilliseconds 0
    -not $tested.identity_verified -and $tested.failure_reason -eq "process_creation_time_mismatch"
}
Invoke-WireCase process_identity_v3 "restarted_same_pid_rejected" {
    $priorToken = (ConvertTo-RoleGodotCreationTimeToken -CreationTime $fakeStart.AddSeconds(-10)).token
    $tested = New-RoleGodotProcessIdentityV3 `
        -Process $fakeProcess -Role Supervisor -SessionId synthetic-session -ExpectedExecutablePath $pwshPath `
        -ExpectedCreationTimeToken $priorToken -ProjectPath "C:\测试 Project" -ProjectHeadSha ("c" * 40) `
        -Endpoint "http://127.0.0.1:12345/" -ProvidedCimProcess $fakeCim -UseProvidedCimProcess `
        -EndpointOwnerPidOverride 4242 -IdentityReadTimeoutMilliseconds 0
    -not $tested.identity_verified -and $tested.failure_reason -eq "process_creation_time_mismatch"
}
Invoke-WireCase process_identity_v3 "same_pid_time_different_command_line_rejected" {
    $badCim = $fakeCim.PSObject.Copy()
    $badCim.CommandLine = '"C:\pwsh.exe" --path "C:\other" --role-godot-mcp-session-id=synthetic-session'
    $tested = New-RoleGodotProcessIdentityV3 `
        -Process $fakeProcess -Role Supervisor -SessionId synthetic-session -ExpectedExecutablePath $pwshPath `
        -ExpectedCreationTimeToken $completeIdentity.process_creation_time -ProjectPath "C:\测试 Project" -ProjectHeadSha ("c" * 40) `
        -Endpoint "http://127.0.0.1:12345/" -ProvidedCimProcess $badCim -UseProvidedCimProcess `
        -EndpointOwnerPidOverride 4242 -IdentityReadTimeoutMilliseconds 0
    -not $tested.identity_verified -and $tested.failure_reason -eq "process_command_line_mismatch"
}
Invoke-WireCase process_identity_v3 "legacy_v2_rejected" {
    $v2Connection = [pscustomobject]@{
        schema = "RoleGodotMcpConnectionV4"
        process_identity = [pscustomobject]@{ schema = "RoleGodotProcessIdentityV2"; schema_version = 2 }
    }
    (Test-McpProcessIdentity -Connection $v2Connection).reason_code -eq "process_identity_schema_v2_not_supported"
}
Invoke-WireCase process_identity_v3 "schema_version_string_rejected" {
    $connection = Copy-WireObject -Object $completeConnection
    $connection.process_identity.schema_version = "3"
    (Test-McpProcessIdentity -Connection $connection).reason_code -eq "process_identity_incomplete"
}
Invoke-WireCase process_identity_v3 "oversized_schema_version_rejected_without_throw" {
    $connection = Copy-WireObject -Object $completeConnection
    $connection.process_identity.schema_version = [long]999999999999
    (Test-McpProcessIdentity -Connection $connection).reason_code -eq "process_identity_incomplete"
}
Invoke-WireCase process_identity_v3 "connection_schema_mismatch_rejected" {
    $connection = Copy-WireObject -Object $completeConnection
    $connection.schema = "RoleGodotMcpConnectionV3"
    (Test-McpProcessIdentity -Connection $connection).reason_code -eq "process_identity_incomplete"
}
Invoke-WireCase process_identity_v3 "identity_schema_array_rejected" {
    $json = $completeConnection | ConvertTo-Json -Depth 20 -Compress
    $connection = $json.Replace('"schema":"RoleGodotProcessIdentityV3"', '"schema":["RoleGodotProcessIdentityV3"]') | ConvertFrom-Json
    (Test-McpProcessIdentity -Connection $connection).reason_code -eq "process_identity_incomplete"
}
Invoke-WireCase process_identity_v3 "connection_schema_array_rejected" {
    $json = $completeConnection | ConvertTo-Json -Depth 20 -Compress
    $connection = $json.Replace('"schema":"RoleGodotMcpConnectionV4"', '"schema":["RoleGodotMcpConnectionV4"]') | ConvertFrom-Json
    (Test-McpProcessIdentity -Connection $connection).reason_code -eq "process_identity_incomplete"
}
Invoke-WireCase process_identity_v3 "normative_string_array_rejected" {
    $json = $completeConnection | ConvertTo-Json -Depth 20 -Compress
    $connection = $json.Replace('"role":"Supervisor"', '"role":["Supervisor"]') | ConvertFrom-Json
    (Test-McpProcessIdentity -Connection $connection).reason_code -eq "process_identity_incomplete"
}
Invoke-WireCase process_identity_v3 "stored_unverified_identity_rejected" {
    $connection = Copy-WireObject -Object $completeConnection
    $connection.process_identity.identity_verified = $false
    (Test-McpProcessIdentity -Connection $connection).reason_code -eq "process_identity_incomplete"
}
Invoke-WireCase process_identity_v3 "outer_creation_time_mismatch_rejected" {
    $connection = Copy-WireObject -Object $completeConnection
    $connection.process_creation_time = (ConvertTo-RoleGodotCreationTimeToken -CreationTime $fakeStart.AddTicks(1)).token
    (Test-McpProcessIdentity -Connection $connection).reason_code -eq "process_creation_time_mismatch"
}
Invoke-WireCase process_identity_v3 "fingerprint_tamper_rejected" {
    $tamperedIdentity = Copy-WireObject -Object $completeIdentity
    $tamperedIdentity.identity_fingerprint_sha256 = "0" * 64
    $connection = Copy-WireObject -Object $completeConnection
    $connection.process_identity = $tamperedIdentity
    (Test-McpProcessIdentity -Connection $connection).reason_code -eq "process_identity_fingerprint_mismatch"
}
Invoke-WireCase process_identity_v3 "connection_has_no_datetime_or_unsafe_integer" {
    $connection = [ordered]@{
        schema = "RoleGodotMcpConnectionV4"
        process_creation_time = $completeIdentity.process_creation_time
        process_identity = $completeIdentity
        launched_at = "display_utc:2026-08-03T10:55:34.9642428Z"
    }
    $roundTripConnection = Copy-WireObject -Object $connection
    $counts = Get-ConnectionValueCounts -Value $roundTripConnection
    $counts.datetime -eq 0 -and $counts.unsafe_integer -eq 0
}
Invoke-WireCase process_identity_v3 "cleanup_missing_token_rejected" {
    $currentProcess = Get-Process -Id $PID
    $cleanup = Stop-McpBoundProcess -Process $currentProcess -TimeoutSeconds 1 -ExpectedCreationTimeToken $null -AllowForcedCleanup
    -not $cleanup.stopped -and $cleanup.failure_reason -eq "cleanup_target_identity_unavailable" -and -not $currentProcess.HasExited
}

$totalPassed = 0
$totalCases = 0
foreach ($category in $categories.Values) {
    $totalPassed += [int]$category.passed
    $totalCases += [int]$category.total
}
$result = [ordered]@{
    schema = "RoleGodotCreationTimeWireTestV1"
    status = if ($failures.Count -eq 0 -and $unhandled -eq 0) { "PASS" } else { "FAIL" }
    process_creation_time_codec_tests = "{0}/{1}" -f $categories.codec.passed, $categories.codec.total
    process_creation_time_json_roundtrip_tests = "{0}/{1}" -f $categories.json_roundtrip.passed, $categories.json_roundtrip.total
    process_creation_time_culture_tests = "{0}/{1}" -f $categories.cultures.passed, $categories.cultures.total
    process_creation_time_source_tests = "{0}/{1}" -f $categories.source.passed, $categories.source.total
    process_identity_v3_tests = "{0}/{1}" -f $categories.process_identity_v3.passed, $categories.process_identity_v3.total
    total = "{0}/{1}" -f $totalPassed, $totalCases
    unhandled_powershell_exception_count = $unhandled
    engines = $engineEvidence
    failures = $failures.ToArray()
}
$result | ConvertTo-Json -Depth 12
if ($result.status -ne "PASS") {
    exit 1
}
