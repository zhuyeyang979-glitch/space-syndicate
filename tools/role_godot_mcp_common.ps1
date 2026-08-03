Set-StrictMode -Version Latest

function Write-McpUtf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $temporaryPath = "$Path.$PID.$([guid]::NewGuid().ToString('N')).tmp"
    [System.IO.File]::WriteAllText($temporaryPath, $Text, [System.Text.UTF8Encoding]::new($false))
    if ([System.IO.File]::Exists($Path)) {
        [System.IO.File]::Replace($temporaryPath, $Path, $null)
    } else {
        [System.IO.File]::Move($temporaryPath, $Path)
    }
}

function ConvertTo-McpNormalizedPath {
    param(
        [AllowEmptyString()]
        [string]$Path,
        [AllowEmptyString()]
        [string]$BasePath = ""
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }
    try {
        $expanded = [Environment]::ExpandEnvironmentVariables($Path).Replace("/", "\")
        if (-not [System.IO.Path]::IsPathRooted($expanded) -and -not [string]::IsNullOrWhiteSpace($BasePath)) {
            $expanded = Join-Path $BasePath $expanded
        }
        return [System.IO.Path]::GetFullPath($expanded).TrimEnd("\")
    } catch {
        return ""
    }
}

function Get-McpSha256Hex {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [System.Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-McpSafeProperty {
    param(
        [AllowNull()]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return [ordered]@{ found = $false; value = $null; error = "object_is_null" }
    }
    try {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -eq $property) {
            return [ordered]@{ found = $false; value = $null; error = "property_missing" }
        }
        return [ordered]@{ found = $true; value = $property.Value; error = "" }
    } catch {
        return [ordered]@{ found = $true; value = $null; error = $_.Exception.Message }
    }
}

function ConvertTo-McpUtcTimestamp {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ""
    }
    try {
        if ($Value -is [DateTimeOffset]) {
            return ([DateTimeOffset]$Value).ToUniversalTime().ToString("o")
        }
        if ($Value -is [DateTime]) {
            return ([DateTime]$Value).ToUniversalTime().ToString("o")
        }
        return [DateTimeOffset]::Parse(
            [string]$Value,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        ).ToUniversalTime().ToString("o")
    } catch {
        return ""
    }
}

function Get-McpUtcMicrosecondValue {
    param(
        [AllowNull()]
        [object]$Value
    )

    $timestamp = ConvertTo-McpUtcTimestamp -Value $Value
    if ($timestamp -eq "") {
        return [ordered]@{ valid = $false; value = [long]0 }
    }
    try {
        $ticks = [DateTimeOffset]::Parse($timestamp).UtcDateTime.Ticks
        return [ordered]@{ valid = $true; value = [long]($ticks - ($ticks % 10)) }
    } catch {
        return [ordered]@{ valid = $false; value = [long]0 }
    }
}

function ConvertTo-McpInt32Value {
    param(
        [AllowNull()]
        [object]$Value
    )

    $parsed = 0
    if ($null -eq $Value -or -not [int]::TryParse([string]$Value, [ref]$parsed)) {
        return [ordered]@{ valid = $false; value = 0 }
    }
    return [ordered]@{ valid = $true; value = $parsed }
}

function Get-McpCimProcessRecord {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ProcessId,
        [AllowNull()]
        [object]$ProvidedCimProcess = $null,
        [switch]$UseProvidedCimProcess
    )

    try {
        $records = @(
            if ($UseProvidedCimProcess) {
                if ($null -ne $ProvidedCimProcess) {
                    $ProvidedCimProcess
                }
            } else {
                Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction Stop
            }
        )
    } catch {
        return [ordered]@{ found = $false; reason = "cim_query_failed"; record = $null }
    }
    if ($records.Count -eq 0) {
        return [ordered]@{ found = $false; reason = "cim_process_missing"; record = $null }
    }
    if ($records.Count -ne 1) {
        return [ordered]@{ found = $false; reason = "cim_process_ambiguous"; record = $null }
    }
    return [ordered]@{ found = $true; reason = "none"; record = $records[0] }
}

function Test-McpCommandLineBinding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandLine,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$SessionId
    )

    $projectPathNormalized = ConvertTo-McpNormalizedPath -Path $ProjectPath
    if ($projectPathNormalized -eq "" -or [string]::IsNullOrWhiteSpace($SessionId)) {
        return [ordered]@{ verified = $false; failure_reason = "process_identity_incomplete"; observed_project_path = "" }
    }
    $pathMatches = [regex]::Matches($CommandLine, '(?i)(?:^|\s)--path(?:\s+|=)(?:"([^"]+)"|(\S+))')
    if ($pathMatches.Count -ne 1) {
        return [ordered]@{ verified = $false; failure_reason = "process_command_line_mismatch"; observed_project_path = "" }
    }
    $observedProjectPath = if ($pathMatches[0].Groups[1].Success) {
        [string]$pathMatches[0].Groups[1].Value
    } else {
        [string]$pathMatches[0].Groups[2].Value
    }
    $observedProjectPathNormalized = ConvertTo-McpNormalizedPath -Path $observedProjectPath
    if (-not $observedProjectPathNormalized.Equals($projectPathNormalized, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [ordered]@{ verified = $false; failure_reason = "process_command_line_mismatch"; observed_project_path = $observedProjectPathNormalized }
    }
    $sessionPattern = '(?:^|\s)' + [regex]::Escape("--role-godot-mcp-session-id=$SessionId") + '(?=\s|$)'
    if (-not [regex]::IsMatch($CommandLine, $sessionPattern, [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)) {
        return [ordered]@{ verified = $false; failure_reason = "process_command_line_mismatch"; observed_project_path = $observedProjectPathNormalized }
    }
    return [ordered]@{ verified = $true; failure_reason = "none"; observed_project_path = $observedProjectPathNormalized }
}

function Resolve-RoleGodotExecutableIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Process,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedExecutablePath,
        [AllowNull()]
        [object]$CimProcess = $null
    )

    $expectedPath = ConvertTo-McpNormalizedPath -Path $ExpectedExecutablePath
    $observedPath = ""
    $source = "none"

    if ($null -ne $CimProcess) {
        $cimPath = Get-McpSafeProperty -Object $CimProcess -Name "ExecutablePath"
        if ($cimPath.found -and [string]::IsNullOrWhiteSpace([string]$cimPath.error)) {
            $observedPath = ConvertTo-McpNormalizedPath -Path ([string]$cimPath.value)
            if ($observedPath -ne "") {
                $source = "win32_process_executable_path"
            }
        }
    }

    if ($observedPath -eq "") {
        $pathProperty = Get-McpSafeProperty -Object $Process -Name "Path"
        if ($pathProperty.found -and [string]::IsNullOrWhiteSpace([string]$pathProperty.error)) {
            $observedPath = ConvertTo-McpNormalizedPath -Path ([string]$pathProperty.value)
            if ($observedPath -ne "") {
                $source = "system_diagnostics_process_path"
            }
        }
    }

    if ($observedPath -eq "") {
        $mainModuleProperty = Get-McpSafeProperty -Object $Process -Name "MainModule"
        if ($mainModuleProperty.found -and [string]::IsNullOrWhiteSpace([string]$mainModuleProperty.error) -and $null -ne $mainModuleProperty.value) {
            $fileNameProperty = Get-McpSafeProperty -Object $mainModuleProperty.value -Name "FileName"
            if ($fileNameProperty.found -and [string]::IsNullOrWhiteSpace([string]$fileNameProperty.error)) {
                $observedPath = ConvertTo-McpNormalizedPath -Path ([string]$fileNameProperty.value)
                if ($observedPath -ne "") {
                    $source = "process_main_module_filename"
                }
            }
        }
    }

    $startInfoFileName = ""
    $startInfoProperty = Get-McpSafeProperty -Object $Process -Name "StartInfo"
    if ($startInfoProperty.found -and [string]::IsNullOrWhiteSpace([string]$startInfoProperty.error) -and $null -ne $startInfoProperty.value) {
        $fileNameProperty = Get-McpSafeProperty -Object $startInfoProperty.value -Name "FileName"
        if ($fileNameProperty.found -and [string]::IsNullOrWhiteSpace([string]$fileNameProperty.error)) {
            $startInfoFileName = ConvertTo-McpNormalizedPath -Path ([string]$fileNameProperty.value)
        }
    }

    if ($observedPath -eq "") {
        return [ordered]@{
            verified = $false
            failure_reason = "process_executable_path_unavailable"
            expected_path = $expectedPath
            observed_path = ""
            source = "none"
            start_info_path = $startInfoFileName
        }
    }
    if ($expectedPath -eq "") {
        return [ordered]@{
            verified = $false
            failure_reason = "process_identity_incomplete"
            expected_path = ""
            observed_path = $observedPath
            source = $source
            start_info_path = $startInfoFileName
        }
    }
    if (-not $observedPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [ordered]@{
            verified = $false
            failure_reason = "process_executable_path_mismatch"
            expected_path = $expectedPath
            observed_path = $observedPath
            source = $source
            start_info_path = $startInfoFileName
        }
    }
    return [ordered]@{
        verified = $true
        failure_reason = "none"
        expected_path = $expectedPath
        observed_path = $observedPath
        source = $source
        start_info_path = $startInfoFileName
    }
}

function Invoke-RoleGodotProcessIdentityProbe {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Process,
        [Parameter(Mandatory = $true)]
        [string]$Role,
        [Parameter(Mandatory = $true)]
        [string]$SessionId,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedExecutablePath,
        [AllowEmptyString()]
        [string]$ExpectedCreationTimeUtc = "",
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ProjectHeadSha,
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        [switch]$RequireEndpointOwner,
        [AllowNull()]
        [object]$ProvidedCimProcess = $null,
        [switch]$UseProvidedCimProcess,
        [int]$EndpointOwnerPidOverride = [int]::MinValue,
        [int]$EndpointOwnerPidBeforeOverride = [int]::MinValue,
        [int]$EndpointOwnerPidAfterOverride = [int]::MinValue
    )

    $failureReason = "none"
    $processId = 0
    $creationTimeUtc = ""
    $observedExecutablePath = ""
    $executablePathSource = "none"
    $commandLine = ""
    $commandLineSha256 = ""
    $endpointOwnerPid = 0
    $endpointOwnerPidBefore = 0
    $identityReadStarted = $false
    $projectPathNormalized = ConvertTo-McpNormalizedPath -Path $ProjectPath
    $expectedExecutablePathNormalized = ConvertTo-McpNormalizedPath -Path $ExpectedExecutablePath

    $idProperty = Get-McpSafeProperty -Object $Process -Name "Id"
    if (-not $idProperty.found -or -not [string]::IsNullOrWhiteSpace([string]$idProperty.error)) {
        $failureReason = "process_identity_incomplete"
    } else {
        $parsedProcessId = ConvertTo-McpInt32Value -Value $idProperty.value
        if (-not $parsedProcessId.valid -or [int]$parsedProcessId.value -le 0) {
            $failureReason = "process_identity_incomplete"
        } else {
            $processId = [int]$parsedProcessId.value
        }
    }

    if ($failureReason -eq "none") {
        try {
            $refreshMethod = $Process.PSObject.Methods["Refresh"]
            if ($null -ne $refreshMethod) {
                $Process.Refresh()
            }
        } catch {
            $failureReason = "process_exited_before_identity"
        }
    }

    if ($RequireEndpointOwner -and $failureReason -eq "none") {
        if ($EndpointOwnerPidBeforeOverride -ne [int]::MinValue) {
            $endpointOwnerPidBefore = $EndpointOwnerPidBeforeOverride
        } elseif ($EndpointOwnerPidOverride -ne [int]::MinValue) {
            $endpointOwnerPidBefore = $EndpointOwnerPidOverride
        } else {
            try {
                $endpointOwnerPidBefore = Get-McpEndpointOwnerPid -Port ([Uri]$Endpoint).Port
            } catch {
                $endpointOwnerPidBefore = 0
            }
        }
    }

    if ($failureReason -eq "none") {
        $hasExitedProperty = Get-McpSafeProperty -Object $Process -Name "HasExited"
        if (-not $hasExitedProperty.found -or -not [string]::IsNullOrWhiteSpace([string]$hasExitedProperty.error)) {
            $failureReason = "process_exited_before_identity"
        } elseif ([bool]$hasExitedProperty.value) {
            $failureReason = "process_exited_before_identity"
        } else {
            $identityReadStarted = $true
        }
    }

    if ($failureReason -eq "none") {
        $startTimeProperty = Get-McpSafeProperty -Object $Process -Name "StartTime"
        if (-not $startTimeProperty.found -or -not [string]::IsNullOrWhiteSpace([string]$startTimeProperty.error)) {
            $failureReason = "process_identity_incomplete"
        } else {
            $creationTimeUtc = ConvertTo-McpUtcTimestamp -Value $startTimeProperty.value
            if ($creationTimeUtc -eq "") {
                $failureReason = "process_identity_incomplete"
            }
        }
    }

    if ($failureReason -eq "none" -and -not [string]::IsNullOrWhiteSpace($ExpectedCreationTimeUtc)) {
        $expectedCreation = ConvertTo-McpUtcTimestamp -Value $ExpectedCreationTimeUtc
        if ($expectedCreation -eq "") {
            $failureReason = "process_identity_incomplete"
        } else {
            $actualTicks = ([DateTimeOffset]::Parse($creationTimeUtc)).UtcDateTime.Ticks
            $expectedTicks = ([DateTimeOffset]::Parse($expectedCreation)).UtcDateTime.Ticks
            if ($actualTicks -ne $expectedTicks) {
                $failureReason = "process_creation_time_mismatch"
            }
        }
    }

    $cimResult = if ($failureReason -eq "none") {
        Get-McpCimProcessRecord -ProcessId $processId -ProvidedCimProcess $ProvidedCimProcess -UseProvidedCimProcess:$UseProvidedCimProcess
    } else {
        [ordered]@{ found = $false; reason = "not_queried"; record = $null }
    }

    if ($failureReason -eq "none" -and -not $cimResult.found) {
        $failureReason = if ($cimResult.reason -eq "cim_process_missing") { "process_exited_during_identity" } else { "process_identity_incomplete" }
    }

    if ($failureReason -eq "none") {
        $cimProcessIdProperty = Get-McpSafeProperty -Object $cimResult.record -Name "ProcessId"
        if (-not $cimProcessIdProperty.found -or -not [string]::IsNullOrWhiteSpace([string]$cimProcessIdProperty.error)) {
            $failureReason = "process_identity_incomplete"
        } else {
            $parsedCimProcessId = ConvertTo-McpInt32Value -Value $cimProcessIdProperty.value
            if (-not $parsedCimProcessId.valid -or [int]$parsedCimProcessId.value -ne $processId) {
                $failureReason = "process_identity_incomplete"
            }
        }
    }

    if ($failureReason -eq "none") {
        $processCreationMicroseconds = Get-McpUtcMicrosecondValue -Value $creationTimeUtc
        if (-not $processCreationMicroseconds.valid) {
            $failureReason = "process_identity_incomplete"
        }
    }

    if ($failureReason -eq "none") {
        $cimCreationProperty = Get-McpSafeProperty -Object $cimResult.record -Name "CreationDate"
        if ($cimCreationProperty.found -and [string]::IsNullOrWhiteSpace([string]$cimCreationProperty.error) -and $null -ne $cimCreationProperty.value) {
            $cimCreation = ConvertTo-McpUtcTimestamp -Value $cimCreationProperty.value
            if ($cimCreation -eq "") {
                $failureReason = "process_identity_incomplete"
            } else {
                $actualMicroseconds = Get-McpUtcMicrosecondValue -Value $creationTimeUtc
                $cimMicroseconds = Get-McpUtcMicrosecondValue -Value $cimCreation
                if (-not $actualMicroseconds.valid -or -not $cimMicroseconds.valid) {
                    $failureReason = "process_identity_incomplete"
                } elseif ([long]$actualMicroseconds.value -ne [long]$cimMicroseconds.value) {
                    $failureReason = "process_creation_time_mismatch"
                }
            }
        } else {
            $failureReason = "process_identity_incomplete"
        }
    }

    if ($failureReason -eq "none") {
        $resolvedExecutable = Resolve-RoleGodotExecutableIdentity -Process $Process -ExpectedExecutablePath $ExpectedExecutablePath -CimProcess $cimResult.record
        $observedExecutablePath = [string]$resolvedExecutable.observed_path
        $executablePathSource = [string]$resolvedExecutable.source
        if (-not $resolvedExecutable.verified) {
            $failureReason = [string]$resolvedExecutable.failure_reason
        }
    }

    if ($failureReason -eq "none") {
        $commandLineProperty = Get-McpSafeProperty -Object $cimResult.record -Name "CommandLine"
        if (-not $commandLineProperty.found -or -not [string]::IsNullOrWhiteSpace([string]$commandLineProperty.error) -or [string]::IsNullOrWhiteSpace([string]$commandLineProperty.value)) {
            $failureReason = "process_command_line_unavailable"
        } else {
            $commandLine = [string]$commandLineProperty.value
            $commandLineSha256 = Get-McpSha256Hex -Text $commandLine
            $commandLineBinding = Test-McpCommandLineBinding -CommandLine $commandLine -ProjectPath $projectPathNormalized -SessionId $SessionId
            if (-not $commandLineBinding.verified) {
                $failureReason = [string]$commandLineBinding.failure_reason
            }
        }
    }

    if ($failureReason -eq "none" -and ([string]::IsNullOrWhiteSpace($Role) -or [string]::IsNullOrWhiteSpace($SessionId) -or [string]::IsNullOrWhiteSpace($ProjectHeadSha))) {
        $failureReason = "process_identity_incomplete"
    }

    if ($RequireEndpointOwner) {
        if ($EndpointOwnerPidAfterOverride -ne [int]::MinValue) {
            $endpointOwnerPid = $EndpointOwnerPidAfterOverride
        } elseif ($EndpointOwnerPidOverride -ne [int]::MinValue) {
            $endpointOwnerPid = $EndpointOwnerPidOverride
        } else {
            try {
                $endpointOwnerPid = Get-McpEndpointOwnerPid -Port ([Uri]$Endpoint).Port
            } catch {
                $endpointOwnerPid = 0
            }
        }
        if ($failureReason -eq "none" -and ($endpointOwnerPidBefore -eq 0 -or $endpointOwnerPid -eq 0)) {
            $failureReason = "endpoint_owner_pid_missing"
        } elseif ($failureReason -eq "none" -and ($endpointOwnerPidBefore -ne $endpointOwnerPid -or $endpointOwnerPid -ne $processId)) {
            $failureReason = "endpoint_owner_pid_mismatch"
        }
    }


    if ($identityReadStarted) {
        $finalHasExited = Get-McpSafeProperty -Object $Process -Name "HasExited"
        $finalStartTime = Get-McpSafeProperty -Object $Process -Name "StartTime"
        if (-not $finalHasExited.found -or -not [string]::IsNullOrWhiteSpace([string]$finalHasExited.error) -or [bool]$finalHasExited.value) {
            $failureReason = "process_exited_during_identity"
        } elseif (-not $finalStartTime.found -or -not [string]::IsNullOrWhiteSpace([string]$finalStartTime.error)) {
            $failureReason = "process_exited_during_identity"
        } elseif ($creationTimeUtc -ne "" -and (ConvertTo-McpUtcTimestamp -Value $finalStartTime.value) -ne $creationTimeUtc) {
            $failureReason = "process_creation_time_mismatch"
        }
    }

    return [ordered]@{
        schema = "RoleGodotProcessIdentityV2"
        schema_version = 2
        role = $Role
        session_id = $SessionId
        process_id = $processId
        process_creation_time_utc = $creationTimeUtc
        expected_executable_path = $expectedExecutablePathNormalized
        observed_executable_path = $observedExecutablePath
        executable_path_source = $executablePathSource
        command_line_sha256 = $commandLineSha256
        project_path = $projectPathNormalized
        project_head_sha = $ProjectHeadSha
        endpoint = $Endpoint
        endpoint_owner_pid = $endpointOwnerPid
        identity_verified = $failureReason -eq "none"
        failure_reason = $failureReason
        pid = $processId
        start_time_utc = $creationTimeUtc
        executable_path = $observedExecutablePath
    }
}

function New-RoleGodotProcessIdentityV2 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Process,
        [Parameter(Mandatory = $true)]
        [string]$Role,
        [Parameter(Mandatory = $true)]
        [string]$SessionId,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedExecutablePath,
        [AllowEmptyString()]
        [string]$ExpectedCreationTimeUtc = "",
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ProjectHeadSha,
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        [switch]$RequireEndpointOwner,
        [ValidateRange(0, 10000)]
        [int]$IdentityReadTimeoutMilliseconds = 2000,
        [AllowNull()]
        [object]$ProvidedCimProcess = $null,
        [switch]$UseProvidedCimProcess,
        [int]$EndpointOwnerPidOverride = [int]::MinValue,
        [int]$EndpointOwnerPidBeforeOverride = [int]::MinValue,
        [int]$EndpointOwnerPidAfterOverride = [int]::MinValue
    )

    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($IdentityReadTimeoutMilliseconds)
    $probeParameters = @{} + $PSBoundParameters
    $probeParameters.Remove("IdentityReadTimeoutMilliseconds")
    do {
        $identity = Invoke-RoleGodotProcessIdentityProbe @probeParameters
        if ($identity.identity_verified) {
            return $identity
        }
        if (-not @(
            "process_identity_incomplete",
            "process_executable_path_unavailable",
            "process_command_line_unavailable"
        ).Contains([string]$identity.failure_reason)) {
            return $identity
        }
        if ([DateTimeOffset]::UtcNow -ge $deadline) {
            return $identity
        }
        Start-Sleep -Milliseconds 50
    } while ($true)
}

function Get-McpProcessIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Process,
        [Parameter(Mandatory = $true)]
        [string]$Role,
        [Parameter(Mandatory = $true)]
        [string]$SessionId,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedExecutablePath,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ProjectHeadSha,
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        [switch]$RequireEndpointOwner,
        [AllowEmptyString()]
        [string]$ExpectedCreationTimeUtc = ""
    )

    return New-RoleGodotProcessIdentityV2 @PSBoundParameters
}

function Test-McpProcessIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection
    )

    $storedIdentity = Get-McpOptionalProperty -Object $Connection -Name "process_identity"
    if ($null -eq $storedIdentity -or [string](Get-McpOptionalProperty -Object $storedIdentity -Name "schema") -ne "RoleGodotProcessIdentityV2") {
        return [ordered]@{ valid = $false; reason_code = "process_identity_incomplete"; process = $null; identity = $null }
    }
    if ([int](Get-McpOptionalProperty -Object $storedIdentity -Name "schema_version") -ne 2) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_incomplete"; process = $null; identity = $null }
    }

    $storedProcessId = ConvertTo-McpInt32Value -Value (Get-McpOptionalProperty -Object $storedIdentity -Name "process_id")
    $connectionProcessId = ConvertTo-McpInt32Value -Value (Get-McpOptionalProperty -Object $Connection -Name "pid")
    $connectionEndpointOwnerPid = ConvertTo-McpInt32Value -Value (Get-McpOptionalProperty -Object $Connection -Name "endpoint_owner_pid")
    $connectionPort = ConvertTo-McpInt32Value -Value (Get-McpOptionalProperty -Object $Connection -Name "port")
    if (-not $storedProcessId.valid -or -not $connectionProcessId.valid -or -not $connectionEndpointOwnerPid.valid -or -not $connectionPort.valid) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_incomplete"; process = $null; identity = $null }
    }
    $processId = [int]$storedProcessId.value
    $storedSessionId = [string](Get-McpOptionalProperty -Object $storedIdentity -Name "session_id")
    $storedRole = [string](Get-McpOptionalProperty -Object $storedIdentity -Name "role")
    $storedCreationTime = [string](Get-McpOptionalProperty -Object $storedIdentity -Name "process_creation_time_utc")
    $storedObservedPath = [string](Get-McpOptionalProperty -Object $storedIdentity -Name "observed_executable_path")
    $storedProjectPath = [string](Get-McpOptionalProperty -Object $storedIdentity -Name "project_path")
    $storedProjectHead = [string](Get-McpOptionalProperty -Object $storedIdentity -Name "project_head_sha")
    $storedEndpoint = [string](Get-McpOptionalProperty -Object $storedIdentity -Name "endpoint")
    $storedEndpointOwnerPid = ConvertTo-McpInt32Value -Value (Get-McpOptionalProperty -Object $storedIdentity -Name "endpoint_owner_pid")
    $storedEndpointPort = try { ([Uri]$storedEndpoint).Port } catch { 0 }
    if (-not $storedEndpointOwnerPid.valid `
        -or [int]$connectionProcessId.value -ne $processId `
        -or [int]$connectionEndpointOwnerPid.value -ne [int]$storedEndpointOwnerPid.value `
        -or [int]$storedEndpointOwnerPid.value -ne $processId `
        -or [int]$connectionPort.value -ne $storedEndpointPort `
        -or -not ([string](Get-McpOptionalProperty -Object $Connection -Name "session_id")).Equals($storedSessionId, [System.StringComparison]::Ordinal) `
        -or -not ([string](Get-McpOptionalProperty -Object $Connection -Name "role")).Equals($storedRole, [System.StringComparison]::Ordinal) `
        -or -not ([string](Get-McpOptionalProperty -Object $Connection -Name "process_start_time_utc")).Equals($storedCreationTime, [System.StringComparison]::Ordinal) `
        -or -not (ConvertTo-McpNormalizedPath -Path ([string](Get-McpOptionalProperty -Object $Connection -Name "godot_path"))).Equals($storedObservedPath, [System.StringComparison]::OrdinalIgnoreCase) `
        -or -not (ConvertTo-McpNormalizedPath -Path ([string](Get-McpOptionalProperty -Object $Connection -Name "worktree"))).Equals($storedProjectPath, [System.StringComparison]::OrdinalIgnoreCase) `
        -or -not ([string](Get-McpOptionalProperty -Object $Connection -Name "project_head_sha")).Equals($storedProjectHead, [System.StringComparison]::Ordinal) `
        -or -not ([string](Get-McpOptionalProperty -Object $Connection -Name "endpoint")).Equals($storedEndpoint, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_incomplete"; process = $null; identity = $null }
    }
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        return [ordered]@{ valid = $false; reason_code = "process_exited_before_identity"; process = $null; identity = $null }
    }

    $identity = New-RoleGodotProcessIdentityV2 `
        -Process $process `
        -Role ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "role")) `
        -SessionId ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "session_id")) `
        -ExpectedExecutablePath ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "expected_executable_path")) `
        -ExpectedCreationTimeUtc ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "process_creation_time_utc")) `
        -ProjectPath ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "project_path")) `
        -ProjectHeadSha ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "project_head_sha")) `
        -Endpoint ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "endpoint")) `
        -RequireEndpointOwner `
        -IdentityReadTimeoutMilliseconds 0

    if (-not $identity.identity_verified) {
        return [ordered]@{ valid = $false; reason_code = [string]$identity.failure_reason; process = $process; identity = $identity }
    }
    if (-not ([string]$identity.command_line_sha256).Equals([string](Get-McpOptionalProperty -Object $storedIdentity -Name "command_line_sha256"), [System.StringComparison]::Ordinal)) {
        return [ordered]@{ valid = $false; reason_code = "process_command_line_mismatch"; process = $process; identity = $identity }
    }
    if ([int]$identity.endpoint_owner_pid -ne $processId) {
        return [ordered]@{ valid = $false; reason_code = "endpoint_owner_pid_mismatch"; process = $process; identity = $identity }
    }
    return [ordered]@{ valid = $true; reason_code = "none"; process = $process; identity = $identity }
}

function Get-McpOptionalProperty {
    param(
        [AllowNull()]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }
    try {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -eq $property) {
            return $null
        }
        return $property.Value
    } catch {
        return $null
    }
}

function Get-McpEndpointOwnerPid {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($listeners.Count -eq 0) {
        return 0
    }
    $ownerPids = @($listeners | Select-Object -ExpandProperty OwningProcess -Unique)
    if ($ownerPids.Count -ne 1) {
        return -1
    }
    return [int]$ownerPids[0]
}

function Get-McpNativeExitEvidence {
    param(
        [string]$LogPath,
        [int]$ExitCode
    )

    $logText = ""
    $logReadError = ""
    if ($LogPath -ne "" -and (Test-Path -LiteralPath $LogPath)) {
        $stream = $null
        $reader = $null
        try {
            $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
            $stream = [System.IO.File]::Open(
                $LogPath,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                $share
            )
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $true)
            $logText = $reader.ReadToEnd()
        } catch {
            $logReadError = $_.Exception.Message
        } finally {
            if ($null -ne $reader) {
                $reader.Dispose()
            } elseif ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    }
    $signalMatch = [regex]::Match($logText, 'Program crashed with signal\s+(\d+)')
    $signal = if ($signalMatch.Success) {
        [int]$signalMatch.Groups[1].Value
    } elseif ($ExitCode -eq -1073741819) {
        11
    } else {
        0
    }
    return [ordered]@{
        exit_code = $ExitCode
        signal = $signal
        log_path = $LogPath
        log_read_error = $logReadError
        evidence_source = if ($signalMatch.Success) { "log" } elseif ($signal -ne 0) { "exit_code" } else { "none" }
    }
}

function Get-McpActiveSession {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ControlRoot
    )

    $activePath = Join-Path $ControlRoot "active-session.json"
    if (-not (Test-Path -LiteralPath $activePath)) {
        throw "Missing active MCP session metadata: $activePath"
    }
    $active = Get-Content -Raw -LiteralPath $activePath | ConvertFrom-Json
    $sessionId = [string](Get-McpOptionalProperty -Object $active -Name "session_id")
    $connectionPath = ConvertTo-McpNormalizedPath -Path ([string](Get-McpOptionalProperty -Object $active -Name "connection_path"))
    if ([string]::IsNullOrWhiteSpace($sessionId) -or $connectionPath -eq "") {
        throw "MCP_ACTIVE_SESSION_METADATA_INVALID|reason_code=active_session_field_missing"
    }
    $expectedSessionRoot = ConvertTo-McpNormalizedPath -Path (Join-Path (Join-Path $ControlRoot "sessions") $sessionId)
    $expectedConnectionPath = ConvertTo-McpNormalizedPath -Path (Join-Path $expectedSessionRoot "connection.json")
    if (-not $connectionPath.Equals($expectedConnectionPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "MCP_ACTIVE_SESSION_METADATA_INVALID|reason_code=connection_path_outside_session_root"
    }
    if (-not (Test-Path -LiteralPath $connectionPath)) {
        throw "Missing active MCP connection metadata: $connectionPath"
    }
    $connection = Get-Content -Raw -LiteralPath $connectionPath | ConvertFrom-Json
    $connectionSessionId = [string](Get-McpOptionalProperty -Object $connection -Name "session_id")
    $connectionSessionRoot = ConvertTo-McpNormalizedPath -Path ([string](Get-McpOptionalProperty -Object $connection -Name "session_root"))
    $tokenPath = ConvertTo-McpNormalizedPath -Path ([string](Get-McpOptionalProperty -Object $connection -Name "token_path"))
    if (-not $connectionSessionId.Equals($sessionId, [System.StringComparison]::Ordinal) `
        -or -not $connectionSessionRoot.Equals($expectedSessionRoot, [System.StringComparison]::OrdinalIgnoreCase) `
        -or $tokenPath -eq "" `
        -or -not $tokenPath.StartsWith($expectedSessionRoot + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "MCP_ACTIVE_SESSION_METADATA_INVALID|reason_code=active_session_connection_mismatch"
    }
    return [ordered]@{
        active_path = $activePath
        active = $active
        connection = $connection
    }
}

function Stop-McpBoundProcess {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds,
        [AllowEmptyString()]
        [string]$ExpectedCreationTimeUtc = "",
        [switch]$AllowForcedCleanup
    )

    if (-not [string]::IsNullOrWhiteSpace($ExpectedCreationTimeUtc)) {
        $liveCreationTime = Get-McpSafeProperty -Object $Process -Name "StartTime"
        if (-not $liveCreationTime.found -or -not [string]::IsNullOrWhiteSpace([string]$liveCreationTime.error)) {
            return [ordered]@{
                stopped = $false
                clean_stop = $false
                forced = $false
                close_accepted = $false
                failure_reason = "cleanup_target_identity_unavailable"
            }
        }
        if ((ConvertTo-McpUtcTimestamp -Value $liveCreationTime.value) -ne (ConvertTo-McpUtcTimestamp -Value $ExpectedCreationTimeUtc)) {
            return [ordered]@{
                stopped = $false
                clean_stop = $false
                forced = $false
                close_accepted = $false
                failure_reason = "cleanup_pid_reused"
            }
        }
    }

    $acceptedClose = $Process.CloseMainWindow()
    $cleanStop = $acceptedClose -and $Process.WaitForExit($TimeoutSeconds * 1000)
    $forced = $false
    if (-not $cleanStop -and $AllowForcedCleanup -and -not $Process.HasExited) {
        if (-not [string]::IsNullOrWhiteSpace($ExpectedCreationTimeUtc)) {
            $liveCreationTime = Get-McpSafeProperty -Object $Process -Name "StartTime"
            if (-not $liveCreationTime.found `
                -or -not [string]::IsNullOrWhiteSpace([string]$liveCreationTime.error) `
                -or (ConvertTo-McpUtcTimestamp -Value $liveCreationTime.value) -ne (ConvertTo-McpUtcTimestamp -Value $ExpectedCreationTimeUtc)) {
                return [ordered]@{
                    stopped = $false
                    clean_stop = $false
                    forced = $false
                    close_accepted = $acceptedClose
                    failure_reason = "cleanup_pid_reused"
                }
            }
        }
        try {
            $Process.Kill($true)
            $Process.WaitForExit(5000) | Out-Null
            $forced = $true
        } catch {
        }
    }
    return [ordered]@{
        stopped = $Process.HasExited
        clean_stop = $cleanStop
        forced = $forced
        close_accepted = $acceptedClose
        failure_reason = if ($Process.HasExited) { "none" } else { "cleanup_failed" }
    }
}
