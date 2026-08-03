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
        if ($Object -is [System.Collections.IDictionary]) {
            if (-not $Object.Contains($Name)) {
                return [ordered]@{ found = $false; value = $null; error = "property_missing" }
            }
            return [ordered]@{ found = $true; value = $Object[$Name]; error = "" }
        }
        $property = $Object.PSObject.Properties[$Name]
        if ($null -eq $property) {
            return [ordered]@{ found = $false; value = $null; error = "property_missing" }
        }
        return [ordered]@{ found = $true; value = $property.Value; error = "" }
    } catch {
        return [ordered]@{ found = $true; value = $null; error = $_.Exception.Message }
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

function ConvertTo-RoleGodotCreationTimeToken {
    param(
        [Parameter(Mandatory = $true)]
        [object]$CreationTime,
        [string]$Source = "system_diagnostics_process_start_time"
    )

    if ($Source -ne "system_diagnostics_process_start_time") {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_source_invalid"; token = $null }
    }
    try {
        $dateTime = if ($CreationTime -is [DateTimeOffset]) {
            ([DateTimeOffset]$CreationTime).UtcDateTime
        } elseif ($CreationTime -is [DateTime]) {
            ([DateTime]$CreationTime).ToUniversalTime()
        } else {
            return [ordered]@{ valid = $false; failure_reason = "process_creation_time_value_invalid"; token = $null }
        }
        $fileTimeUtc = $dateTime.ToFileTimeUtc()
        if ($fileTimeUtc -lt 0) {
            return [ordered]@{ valid = $false; failure_reason = "process_creation_time_value_out_of_range"; token = $null }
        }
        $token = [ordered]@{
            codec = "windows_filetime_utc_decimal_v1"
            value = $fileTimeUtc.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            source = $Source
        }
        return [ordered]@{ valid = $true; failure_reason = "none"; token = $token }
    } catch {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_value_out_of_range"; token = $null }
    }
}

function ConvertFrom-RoleGodotCreationTimeToken {
    param(
        [AllowNull()]
        [object]$Token,
        [AllowEmptyString()]
        [string]$ExpectedSource = ""
    )

    if ($null -eq $Token) {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_tag_missing"; filetime_utc = [long]0; source = "" }
    }
    $codec = Get-McpSafeProperty -Object $Token -Name "codec"
    $value = Get-McpSafeProperty -Object $Token -Name "value"
    $source = Get-McpSafeProperty -Object $Token -Name "source"
    if (-not $codec.found -or -not $value.found -or -not $source.found) {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_tag_missing"; filetime_utc = [long]0; source = "" }
    }
    if ($codec.value -isnot [string] -or -not ([string]$codec.value).Equals("windows_filetime_utc_decimal_v1", [System.StringComparison]::Ordinal)) {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_codec_invalid"; filetime_utc = [long]0; source = [string]$source.value }
    }
    if ($source.value -isnot [string] -or -not ([string]$source.value).Equals("system_diagnostics_process_start_time", [System.StringComparison]::Ordinal)) {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_source_invalid"; filetime_utc = [long]0; source = [string]$source.value }
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedSource) -and [string]$source.value -ne $ExpectedSource) {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_source_changed"; filetime_utc = [long]0; source = [string]$source.value }
    }
    if ($value.value -isnot [string] -or -not ([string]$value.value -match '^(0|[1-9][0-9]*)$')) {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_value_invalid"; filetime_utc = [long]0; source = [string]$source.value }
    }
    $parsed = [long]0
    if (-not [long]::TryParse(
        [string]$value.value,
        [System.Globalization.NumberStyles]::None,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$parsed
    )) {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_value_out_of_range"; filetime_utc = [long]0; source = [string]$source.value }
    }
    try {
        [DateTime]::FromFileTimeUtc($parsed) | Out-Null
    } catch {
        return [ordered]@{ valid = $false; failure_reason = "process_creation_time_value_out_of_range"; filetime_utc = [long]0; source = [string]$source.value }
    }
    return [ordered]@{
        valid = $true
        failure_reason = "none"
        filetime_utc = $parsed
        value = [string]$value.value
        source = [string]$source.value
    }
}

function Get-RoleGodotProcessIdentityFingerprintV3 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Identity
    )

    $creationTime = Get-McpOptionalProperty -Object $Identity -Name "process_creation_time"
    $stringFields = @(
        "schema", "role", "session_id", "expected_executable_path", "observed_executable_path",
        "executable_path_source", "command_line_sha256", "project_path", "project_head_sha",
        "endpoint", "failure_reason"
    )
    foreach ($field in $stringFields) {
        if ((Get-McpOptionalProperty -Object $Identity -Name $field) -isnot [string]) {
            return ""
        }
    }
    foreach ($field in @("codec", "value", "source")) {
        if ((Get-McpOptionalProperty -Object $creationTime -Name $field) -isnot [string]) {
            return ""
        }
    }
    $schemaVersion = Get-McpOptionalProperty -Object $Identity -Name "schema_version"
    $processId = Get-McpOptionalProperty -Object $Identity -Name "process_id"
    $endpointOwnerPid = Get-McpOptionalProperty -Object $Identity -Name "endpoint_owner_pid"
    if (-not ($schemaVersion -is [int] -or $schemaVersion -is [long]) `
        -or -not ($processId -is [int] -or $processId -is [long]) `
        -or -not ($endpointOwnerPid -is [int] -or $endpointOwnerPid -is [long]) `
        -or (Get-McpOptionalProperty -Object $Identity -Name "identity_verified") -isnot [bool]) {
        return ""
    }
    $canonical = [ordered]@{
        schema = [string](Get-McpOptionalProperty -Object $Identity -Name "schema")
        schema_version = [int](Get-McpOptionalProperty -Object $Identity -Name "schema_version")
        role = [string](Get-McpOptionalProperty -Object $Identity -Name "role")
        session_id = [string](Get-McpOptionalProperty -Object $Identity -Name "session_id")
        process_id = [int](Get-McpOptionalProperty -Object $Identity -Name "process_id")
        process_creation_time = [ordered]@{
            codec = [string](Get-McpOptionalProperty -Object $creationTime -Name "codec")
            value = [string](Get-McpOptionalProperty -Object $creationTime -Name "value")
            source = [string](Get-McpOptionalProperty -Object $creationTime -Name "source")
        }
        expected_executable_path = [string](Get-McpOptionalProperty -Object $Identity -Name "expected_executable_path")
        observed_executable_path = [string](Get-McpOptionalProperty -Object $Identity -Name "observed_executable_path")
        executable_path_source = [string](Get-McpOptionalProperty -Object $Identity -Name "executable_path_source")
        command_line_sha256 = [string](Get-McpOptionalProperty -Object $Identity -Name "command_line_sha256")
        project_path = [string](Get-McpOptionalProperty -Object $Identity -Name "project_path")
        project_head_sha = [string](Get-McpOptionalProperty -Object $Identity -Name "project_head_sha")
        endpoint = [string](Get-McpOptionalProperty -Object $Identity -Name "endpoint")
        endpoint_owner_pid = [int](Get-McpOptionalProperty -Object $Identity -Name "endpoint_owner_pid")
        identity_verified = [bool](Get-McpOptionalProperty -Object $Identity -Name "identity_verified")
        failure_reason = [string](Get-McpOptionalProperty -Object $Identity -Name "failure_reason")
    }
    return Get-McpSha256Hex -Text ($canonical | ConvertTo-Json -Depth 8 -Compress)
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
        [AllowNull()]
        [object]$ExpectedCreationTimeToken = $null,
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
    $creationTimeToken = $null
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
        if (-not $startTimeProperty.found -or -not [string]::IsNullOrWhiteSpace([string]$startTimeProperty.error) -or $null -eq $startTimeProperty.value) {
            $failureReason = "process_creation_time_source_unavailable"
        } else {
            $encodedCreationTime = ConvertTo-RoleGodotCreationTimeToken -CreationTime $startTimeProperty.value
            if (-not $encodedCreationTime.valid) {
                $failureReason = [string]$encodedCreationTime.failure_reason
            } else {
                $creationTimeToken = $encodedCreationTime.token
            }
        }
    }

    if ($failureReason -eq "none" -and $null -ne $ExpectedCreationTimeToken) {
        $actualCreation = ConvertFrom-RoleGodotCreationTimeToken -Token $creationTimeToken
        $expectedSourceProperty = Get-McpSafeProperty -Object $ExpectedCreationTimeToken -Name "source"
        $expectedSource = if ($expectedSourceProperty.found) { [string]$expectedSourceProperty.value } else { "" }
        $expectedCreation = ConvertFrom-RoleGodotCreationTimeToken -Token $ExpectedCreationTimeToken -ExpectedSource $actualCreation.source
        if (-not $actualCreation.valid) {
            $failureReason = [string]$actualCreation.failure_reason
        } elseif (-not $expectedCreation.valid) {
            $failureReason = [string]$expectedCreation.failure_reason
        } elseif ($expectedSource -ne [string]$actualCreation.source) {
            $failureReason = "process_creation_time_source_changed"
        } elseif ([long]$actualCreation.filetime_utc -ne [long]$expectedCreation.filetime_utc) {
            $failureReason = "process_creation_time_mismatch"
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
        } elseif (-not $finalStartTime.found -or -not [string]::IsNullOrWhiteSpace([string]$finalStartTime.error) -or $null -eq $finalStartTime.value) {
            if ($failureReason -eq "none") {
                $failureReason = "process_creation_time_source_unavailable"
            }
        } elseif ($failureReason -eq "none") {
            $finalCreationTime = ConvertTo-RoleGodotCreationTimeToken -CreationTime $finalStartTime.value
            $initialCreationTime = ConvertFrom-RoleGodotCreationTimeToken -Token $creationTimeToken
            $finalCreationDecoded = if ($finalCreationTime.valid) {
                ConvertFrom-RoleGodotCreationTimeToken -Token $finalCreationTime.token -ExpectedSource $initialCreationTime.source
            } else {
                [ordered]@{ valid = $false; failure_reason = [string]$finalCreationTime.failure_reason; filetime_utc = [long]0 }
            }
            if (-not $initialCreationTime.valid) {
                $failureReason = [string]$initialCreationTime.failure_reason
            } elseif (-not $finalCreationDecoded.valid) {
                $failureReason = [string]$finalCreationDecoded.failure_reason
            } elseif ([long]$initialCreationTime.filetime_utc -ne [long]$finalCreationDecoded.filetime_utc) {
                $failureReason = "process_creation_time_mismatch"
            }
        }
    }

    $identity = [ordered]@{
        schema = "RoleGodotProcessIdentityV3"
        schema_version = 3
        role = $Role
        session_id = $SessionId
        process_id = $processId
        process_creation_time = $creationTimeToken
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
        executable_path = $observedExecutablePath
    }
    $identity["identity_fingerprint_sha256"] = Get-RoleGodotProcessIdentityFingerprintV3 -Identity $identity
    return $identity
}

function New-RoleGodotProcessIdentityV3 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Process,
        [Parameter(Mandatory = $true)]
        [string]$Role,
        [Parameter(Mandatory = $true)]
        [string]$SessionId,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedExecutablePath,
        [AllowNull()]
        [object]$ExpectedCreationTimeToken = $null,
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
        [AllowNull()]
        [object]$ExpectedCreationTimeToken = $null
    )

    return New-RoleGodotProcessIdentityV3 @PSBoundParameters
}

function Test-McpProcessIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection
    )

    $storedIdentity = Get-McpOptionalProperty -Object $Connection -Name "process_identity"
    if ($null -eq $storedIdentity) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_incomplete"; process = $null; identity = $null }
    }
    $storedSchemaValue = Get-McpOptionalProperty -Object $storedIdentity -Name "schema"
    $storedSchema = if ($storedSchemaValue -is [string]) { [string]$storedSchemaValue } else { "" }
    $connectionSchemaValue = Get-McpOptionalProperty -Object $Connection -Name "schema"
    $storedSchemaVersionValue = Get-McpOptionalProperty -Object $storedIdentity -Name "schema_version"
    $storedFailureReasonValue = Get-McpOptionalProperty -Object $storedIdentity -Name "failure_reason"
    $storedSchemaVersionTypeValid = $storedSchemaVersionValue -is [int] -or $storedSchemaVersionValue -is [long]
    $storedSchemaTypeValid = $storedSchemaValue -is [string]
    $connectionSchemaTypeValid = $connectionSchemaValue -is [string]
    if ($storedSchemaValue -is [string] -and $storedSchema.Equals("RoleGodotProcessIdentityV2", [System.StringComparison]::Ordinal)) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_schema_v2_not_supported"; process = $null; identity = $null }
    }
    if (-not $connectionSchemaTypeValid `
        -or -not ([string]$connectionSchemaValue).Equals("RoleGodotMcpConnectionV4", [System.StringComparison]::Ordinal) `
        -or -not $storedSchemaTypeValid `
        -or -not $storedSchema.Equals("RoleGodotProcessIdentityV3", [System.StringComparison]::Ordinal) `
        -or -not $storedSchemaVersionTypeValid `
        -or [long]$storedSchemaVersionValue -ne 3 `
        -or (Get-McpOptionalProperty -Object $storedIdentity -Name "identity_verified") -isnot [bool] `
        -or -not [bool](Get-McpOptionalProperty -Object $storedIdentity -Name "identity_verified") `
        -or $storedFailureReasonValue -isnot [string] `
        -or -not ([string]$storedFailureReasonValue).Equals("none", [System.StringComparison]::Ordinal)) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_incomplete"; process = $null; identity = $null }
    }

    $storedCreationTime = Get-McpOptionalProperty -Object $storedIdentity -Name "process_creation_time"
    $storedCreationDecoded = ConvertFrom-RoleGodotCreationTimeToken -Token $storedCreationTime
    if (-not $storedCreationDecoded.valid) {
        return [ordered]@{ valid = $false; reason_code = [string]$storedCreationDecoded.failure_reason; process = $null; identity = $null }
    }
    $connectionCreationTime = Get-McpOptionalProperty -Object $Connection -Name "process_creation_time"
    $connectionCreationDecoded = ConvertFrom-RoleGodotCreationTimeToken -Token $connectionCreationTime -ExpectedSource ([string]$storedCreationDecoded.source)
    if (-not $connectionCreationDecoded.valid) {
        return [ordered]@{ valid = $false; reason_code = [string]$connectionCreationDecoded.failure_reason; process = $null; identity = $null }
    }
    if ([long]$connectionCreationDecoded.filetime_utc -ne [long]$storedCreationDecoded.filetime_utc) {
        return [ordered]@{ valid = $false; reason_code = "process_creation_time_mismatch"; process = $null; identity = $null }
    }

    $storedProcessIdValue = Get-McpOptionalProperty -Object $storedIdentity -Name "process_id"
    $connectionProcessIdValue = Get-McpOptionalProperty -Object $Connection -Name "pid"
    $connectionEndpointOwnerPidValue = Get-McpOptionalProperty -Object $Connection -Name "endpoint_owner_pid"
    $connectionPortValue = Get-McpOptionalProperty -Object $Connection -Name "port"
    $storedEndpointOwnerPidValue = Get-McpOptionalProperty -Object $storedIdentity -Name "endpoint_owner_pid"
    $integerTypesValid = ($storedProcessIdValue -is [int] -or $storedProcessIdValue -is [long]) `
        -and ($connectionProcessIdValue -is [int] -or $connectionProcessIdValue -is [long]) `
        -and ($connectionEndpointOwnerPidValue -is [int] -or $connectionEndpointOwnerPidValue -is [long]) `
        -and ($connectionPortValue -is [int] -or $connectionPortValue -is [long]) `
        -and ($storedEndpointOwnerPidValue -is [int] -or $storedEndpointOwnerPidValue -is [long])
    $storedProcessId = ConvertTo-McpInt32Value -Value $storedProcessIdValue
    $connectionProcessId = ConvertTo-McpInt32Value -Value $connectionProcessIdValue
    $connectionEndpointOwnerPid = ConvertTo-McpInt32Value -Value $connectionEndpointOwnerPidValue
    $connectionPort = ConvertTo-McpInt32Value -Value $connectionPortValue
    $storedEndpointOwnerPid = ConvertTo-McpInt32Value -Value $storedEndpointOwnerPidValue
    if (-not $integerTypesValid `
        -or -not $storedProcessId.valid `
        -or -not $connectionProcessId.valid `
        -or -not $connectionEndpointOwnerPid.valid `
        -or -not $connectionPort.valid `
        -or -not $storedEndpointOwnerPid.valid) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_incomplete"; process = $null; identity = $null }
    }
    $processId = [int]$storedProcessId.value
    $storedSessionIdValue = Get-McpOptionalProperty -Object $storedIdentity -Name "session_id"
    $storedRoleValue = Get-McpOptionalProperty -Object $storedIdentity -Name "role"
    $storedObservedPathValue = Get-McpOptionalProperty -Object $storedIdentity -Name "observed_executable_path"
    $storedExpectedPathValue = Get-McpOptionalProperty -Object $storedIdentity -Name "expected_executable_path"
    $storedExecutablePathSourceValue = Get-McpOptionalProperty -Object $storedIdentity -Name "executable_path_source"
    $storedCommandLineSha256Value = Get-McpOptionalProperty -Object $storedIdentity -Name "command_line_sha256"
    $storedProjectPathValue = Get-McpOptionalProperty -Object $storedIdentity -Name "project_path"
    $storedProjectHeadValue = Get-McpOptionalProperty -Object $storedIdentity -Name "project_head_sha"
    $storedEndpointValue = Get-McpOptionalProperty -Object $storedIdentity -Name "endpoint"
    $storedFingerprintValue = Get-McpOptionalProperty -Object $storedIdentity -Name "identity_fingerprint_sha256"
    $connectionStringFields = @("session_id", "role", "godot_path", "worktree", "project_head_sha", "endpoint")
    $identityStringFields = @(
        "session_id", "role", "observed_executable_path", "expected_executable_path",
        "executable_path_source", "command_line_sha256", "project_path", "project_head_sha",
        "endpoint", "identity_fingerprint_sha256"
    )
    $identityStringsValid = @($identityStringFields | Where-Object { (Get-McpOptionalProperty -Object $storedIdentity -Name $_) -isnot [string] })
    $connectionStringsValid = @($connectionStringFields | Where-Object { (Get-McpOptionalProperty -Object $Connection -Name $_) -isnot [string] })
    if ($identityStringsValid.Count -ne 0 -or $connectionStringsValid.Count -ne 0) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_incomplete"; process = $null; identity = $null }
    }
    $storedSessionId = [string]$storedSessionIdValue
    $storedRole = [string]$storedRoleValue
    $storedObservedPath = [string]$storedObservedPathValue
    $storedExpectedPath = [string]$storedExpectedPathValue
    $storedExecutablePathSource = [string]$storedExecutablePathSourceValue
    $storedCommandLineSha256 = [string]$storedCommandLineSha256Value
    $storedProjectPath = [string]$storedProjectPathValue
    $storedProjectHead = [string]$storedProjectHeadValue
    $storedEndpoint = [string]$storedEndpointValue
    $storedEndpointPort = try { ([Uri]$storedEndpoint).Port } catch { 0 }
    if ([string]::IsNullOrWhiteSpace($storedSessionId) `
        -or [string]::IsNullOrWhiteSpace($storedRole) `
        -or [string]::IsNullOrWhiteSpace($storedExpectedPath) `
        -or [string]::IsNullOrWhiteSpace($storedObservedPath) `
        -or $storedExecutablePathSource -notin @("win32_process_executable_path", "system_diagnostics_process_path", "process_main_module_filename") `
        -or $storedCommandLineSha256 -notmatch '^[0-9a-f]{64}$' `
        -or [string]::IsNullOrWhiteSpace($storedProjectPath) `
        -or [string]::IsNullOrWhiteSpace($storedProjectHead) `
        -or $storedEndpointPort -le 0 `
        -or [int]$connectionProcessId.value -ne $processId `
        -or [int]$connectionEndpointOwnerPid.value -ne [int]$storedEndpointOwnerPid.value `
        -or [int]$storedEndpointOwnerPid.value -ne $processId `
        -or [int]$connectionPort.value -ne $storedEndpointPort `
        -or -not ([string](Get-McpOptionalProperty -Object $Connection -Name "session_id")).Equals($storedSessionId, [System.StringComparison]::Ordinal) `
        -or -not ([string](Get-McpOptionalProperty -Object $Connection -Name "role")).Equals($storedRole, [System.StringComparison]::Ordinal) `
        -or -not (ConvertTo-McpNormalizedPath -Path ([string](Get-McpOptionalProperty -Object $Connection -Name "godot_path"))).Equals($storedObservedPath, [System.StringComparison]::OrdinalIgnoreCase) `
        -or -not (ConvertTo-McpNormalizedPath -Path ([string](Get-McpOptionalProperty -Object $Connection -Name "worktree"))).Equals($storedProjectPath, [System.StringComparison]::OrdinalIgnoreCase) `
        -or -not ([string](Get-McpOptionalProperty -Object $Connection -Name "project_head_sha")).Equals($storedProjectHead, [System.StringComparison]::Ordinal) `
        -or -not ([string](Get-McpOptionalProperty -Object $Connection -Name "endpoint")).Equals($storedEndpoint, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_incomplete"; process = $null; identity = $null }
    }

    $storedFingerprint = [string]$storedFingerprintValue
    $expectedStoredFingerprint = Get-RoleGodotProcessIdentityFingerprintV3 -Identity $storedIdentity
    if ($storedFingerprint -notmatch '^[0-9a-f]{64}$' -or -not $storedFingerprint.Equals($expectedStoredFingerprint, [System.StringComparison]::Ordinal)) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_fingerprint_mismatch"; process = $null; identity = $null }
    }
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        return [ordered]@{ valid = $false; reason_code = "process_exited_before_identity"; process = $null; identity = $null }
    }

    $identity = New-RoleGodotProcessIdentityV3 `
        -Process $process `
        -Role ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "role")) `
        -SessionId ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "session_id")) `
        -ExpectedExecutablePath ([string](Get-McpOptionalProperty -Object $storedIdentity -Name "expected_executable_path")) `
        -ExpectedCreationTimeToken $storedCreationTime `
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
    if (-not ([string]$identity.identity_fingerprint_sha256).Equals($storedFingerprint, [System.StringComparison]::Ordinal)) {
        return [ordered]@{ valid = $false; reason_code = "process_identity_fingerprint_mismatch"; process = $process; identity = $identity }
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
        if ($Object -is [System.Collections.IDictionary]) {
            if (-not $Object.Contains($Name)) {
                return $null
            }
            $dictionaryValue = $Object[$Name]
            if ($dictionaryValue -is [System.Array]) {
                Write-Output -NoEnumerate $dictionaryValue
                return
            }
            return $dictionaryValue
        }
        $property = $Object.PSObject.Properties[$Name]
        if ($null -eq $property) {
            return $null
        }
        $propertyValue = $property.Value
        if ($propertyValue -is [System.Array]) {
            Write-Output -NoEnumerate $propertyValue
            return
        }
        return $propertyValue
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
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$ExpectedCreationTimeToken,
        [switch]$AllowForcedCleanup
    )

    if ($null -eq $ExpectedCreationTimeToken) {
        return [ordered]@{
            stopped = $false
            clean_stop = $false
            forced = $false
            close_accepted = $false
            failure_reason = "cleanup_target_identity_unavailable"
        }
    }
    if ($null -ne $ExpectedCreationTimeToken) {
        $expectedCreationTime = ConvertFrom-RoleGodotCreationTimeToken -Token $ExpectedCreationTimeToken
        if (-not $expectedCreationTime.valid) {
            return [ordered]@{
                stopped = $false
                clean_stop = $false
                forced = $false
                close_accepted = $false
                failure_reason = [string]$expectedCreationTime.failure_reason
            }
        }
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
        $liveCreationEncoded = ConvertTo-RoleGodotCreationTimeToken -CreationTime $liveCreationTime.value -Source ([string]$expectedCreationTime.source)
        $liveCreationDecoded = if ($liveCreationEncoded.valid) {
            ConvertFrom-RoleGodotCreationTimeToken -Token $liveCreationEncoded.token -ExpectedSource ([string]$expectedCreationTime.source)
        } else {
            [ordered]@{ valid = $false; failure_reason = [string]$liveCreationEncoded.failure_reason; filetime_utc = [long]0 }
        }
        if (-not $liveCreationDecoded.valid -or [long]$liveCreationDecoded.filetime_utc -ne [long]$expectedCreationTime.filetime_utc) {
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
        if ($null -ne $ExpectedCreationTimeToken) {
            $liveCreationTime = Get-McpSafeProperty -Object $Process -Name "StartTime"
            $liveCreationEncoded = if ($liveCreationTime.found -and [string]::IsNullOrWhiteSpace([string]$liveCreationTime.error)) {
                ConvertTo-RoleGodotCreationTimeToken -CreationTime $liveCreationTime.value -Source ([string]$expectedCreationTime.source)
            } else {
                [ordered]@{ valid = $false; failure_reason = "process_creation_time_source_unavailable"; token = $null }
            }
            $liveCreationDecoded = if ($liveCreationEncoded.valid) {
                ConvertFrom-RoleGodotCreationTimeToken -Token $liveCreationEncoded.token -ExpectedSource ([string]$expectedCreationTime.source)
            } else {
                [ordered]@{ valid = $false; failure_reason = [string]$liveCreationEncoded.failure_reason; filetime_utc = [long]0 }
            }
            if (-not $liveCreationDecoded.valid -or [long]$liveCreationDecoded.filetime_utc -ne [long]$expectedCreationTime.filetime_utc) {
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
