Set-StrictMode -Version Latest

function Get-McpDiagnosticObjectValueV2 {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-McpByteSha256Hex {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash($Bytes)
        return ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }
}

function Get-McpFileSha256Hex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return Get-McpByteSha256Hex -Bytes ([System.IO.File]::ReadAllBytes($Path))
}

function Get-McpLogEventCategory {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ($Text -match '(?i)Unicode parsing error.*Unexpected NUL character') { return "unicode_nul_diagnostic" }
    if ($Text -match '(?i)(SCRIPT ERROR|Parse Error|Parser Error|compile error)') { return "script_parse_error" }
    if ($Text -match '(?i)(failed to load|cannot load|could not load|resource.*failed)') { return "resource_load_error" }
    if ($Text -match '(?i)(runtime error|invalid call|stack trace|crash|segmentation fault|signal 11)') { return "runtime_error" }
    if ($Text -match '^ERROR:') { return "engine_editor_error" }
    if ($Text -match '^\s+at:\s') { return "diagnostic_context" }
    if ($Text -match '^WARNING:') { return "warning" }
    if ($Text -match '(?i)(Godot Engine v[0-9])') { return "engine_banner" }
    if ($Text -match '(?i)(OpenGL API|Vulkan [0-9]|Using Device)') { return "renderer_banner" }
    if ($Text -match 'res://') { return "project_path_event" }
    if ($Text -match '(?i)status=PASS') { return "runtime_marker" }
    if ([string]::IsNullOrWhiteSpace($Text)) { return "empty" }
    return "other"
}

function Get-McpAssociatedProjectPath {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    $resourceMatch = [regex]::Match($Text, 'res://[^\s|"'']+')
    if ($resourceMatch.Success) {
        return ConvertTo-McpDiagnosticComparablePath -Path $resourceMatch.Value -KeepResPrefix
    }
    $windowsMatch = [regex]::Match($Text, '(?i)(?:"(?<quoted>[A-Z]:\\[^"]+)"|(?<plain>[A-Z]:\\[^\r\n|]+))')
    if ($windowsMatch.Success) {
        $value = if ($windowsMatch.Groups["quoted"].Success) {
            $windowsMatch.Groups["quoted"].Value
        } else {
            $windowsMatch.Groups["plain"].Value
        }
        return ConvertTo-McpDiagnosticComparablePath -Path $value -KeepResPrefix
    }
    return ""
}

function ConvertTo-McpDiagnosticComparablePath {
    param(
        [AllowEmptyString()][string]$Path,
        [switch]$KeepResPrefix
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }
    $normalized = $Path.Trim().Trim('"', "'", ',', ';', ')', ']')
    $normalized = [regex]::Replace($normalized, ':\d+(?::\d+)?$', '')
    $normalized = $normalized.TrimEnd('"', "'", ':', ',', ';', ')', ']')
    $normalized = $normalized.Replace("\", "/")
    if (-not $KeepResPrefix -and $normalized.StartsWith("res://", [System.StringComparison]::OrdinalIgnoreCase)) {
        $normalized = $normalized.Substring(6)
    }
    return $normalized
}

function Test-McpPotentialDiagnosticText {
    param(
        [AllowEmptyString()]
        [string]$Text,
        [AllowEmptyString()]
        [string]$SourceStream
    )

    if ($Text -match '(?i)(^ERROR:|^SCRIPT ERROR:|parsing error|parse error|failed to load|exception|crash|unexpected|invalid call|signal 11)') {
        return $true
    }
    return $false
}

function Get-McpRawLogSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$SourceStream,
        [Parameter(Mandatory = $true)]
        [string]$Stage,
        [bool]$StageBeforeMarker = $true
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [ordered]@{
            schema = "McpRawLogSnapshotV1"
            source_path = $Path
            source_stream = $SourceStream
            stage = $Stage
            exists = $false
            file_length = 0
            file_sha256 = ""
            raw_nul_count = 0
            record_count = 0
            diagnostic_count = 0
            records = @()
            diagnostics = @()
        }
    }

    $file = Get-Item -LiteralPath $Path
    $snapshotLength = $file.Length
    $stream = [System.IO.FileStream]::new(
        $file.FullName,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
    )
    try {
        $bytes = [byte[]]::new($snapshotLength)
        $readTotal = 0
        while ($readTotal -lt $snapshotLength) {
            $read = $stream.Read($bytes, $readTotal, $snapshotLength - $readTotal)
            if ($read -eq 0) {
                throw "MCP_RAW_LOG_SHORT_READ|path=$Path|expected=$snapshotLength|actual=$readTotal"
            }
            $readTotal += $read
        }
    } finally {
        $stream.Dispose()
    }
    $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $replacementUtf8 = [System.Text.UTF8Encoding]::new($false, $false)
    $records = [System.Collections.Generic.List[object]]::new()
    $lineStart = 0
    for ($cursor = 0; $cursor -le $bytes.Length; $cursor += 1) {
        if ($cursor -lt $bytes.Length -and $bytes[$cursor] -ne 10) {
            continue
        }
        $framedEnd = if ($cursor -lt $bytes.Length) { $cursor + 1 } else { $cursor }
        $contentEnd = $cursor
        $lineEndingHex = if ($cursor -lt $bytes.Length -and $contentEnd -gt $lineStart -and $bytes[$contentEnd - 1] -eq 13) {
            "0d0a"
        } elseif ($cursor -lt $bytes.Length) {
            "0a"
        } else {
            ""
        }
        if ($contentEnd -gt $lineStart -and $bytes[$contentEnd - 1] -eq 13) {
            $contentEnd -= 1
        }
        $length = $contentEnd - $lineStart
        if ($length -gt 0) {
            $lineBytes = [byte[]]::new($length)
            [System.Array]::Copy($bytes, $lineStart, $lineBytes, 0, $length)
            $framedLength = $framedEnd - $lineStart
            $framedBytes = [byte[]]::new($framedLength)
            [System.Array]::Copy($bytes, $lineStart, $framedBytes, 0, $framedLength)
            $utf8Valid = $true
            $decoderInsertedReplacementCount = 0
            try {
                $text = $strictUtf8.GetString($lineBytes)
            } catch {
                $utf8Valid = $false
                $text = $replacementUtf8.GetString($lineBytes)
                $decoderInsertedReplacementCount = @($text.ToCharArray() | Where-Object { [int]$_ -eq 0xfffd }).Count
            }
            $associatedPath = Get-McpAssociatedProjectPath -Text $text
            $category = Get-McpLogEventCategory -Text $text
            $timestampMatch = [regex]::Match($text, '^(?<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2}))')
            $record = [ordered]@{
                record_index = $records.Count + 1
                raw_byte_start = $lineStart
                raw_byte_end = $framedEnd
                raw_byte_end_exclusive = $framedEnd
                message_byte_end = $contentEnd
                message_byte_end_exclusive = $contentEnd
                raw_length = $framedLength
                message_length = $length
                raw_bytes_sha256 = Get-McpByteSha256Hex -Bytes $framedBytes
                message_bytes_sha256 = Get-McpByteSha256Hex -Bytes $lineBytes
                raw_bytes_base64 = [System.Convert]::ToBase64String($framedBytes)
                line_ending_hex = $lineEndingHex
                decoded_text_utf8 = $text
                decoded_text_replacement_count = @($text.ToCharArray() | Where-Object { [int]$_ -eq 0xfffd }).Count
                literal_replacement_codepoint_count = if ($utf8Valid) { @($text.ToCharArray() | Where-Object { [int]$_ -eq 0xfffd }).Count } else { 0 }
                decoder_inserted_replacement_count = $decoderInsertedReplacementCount
                raw_utf8_valid = $utf8Valid
                contains_raw_nul_byte = $framedBytes.Contains([byte]0)
                raw_nul_byte_count = @($framedBytes | Where-Object { $_ -eq 0 }).Count
                source_stream = $SourceStream
                timestamp = if ($timestampMatch.Success) { $timestampMatch.Groups["timestamp"].Value } else { $null }
                timestamp_source = if ($timestampMatch.Success) { "record_text" } else { "unavailable" }
                stage = $Stage
                stage_before_marker = $StageBeforeMarker
                category = $category
                nearest_previous_log_record = "stream_start"
                nearest_next_log_record = "stream_end"
                previous_non_diagnostic_event = "stream_start"
                next_non_diagnostic_event = "stream_end"
                nearest_previous_associated_path = ""
                nearest_next_associated_path = ""
                associated_path = $associatedPath
                associated_resource = if ($associatedPath -match '(?i)\.(tscn|tres|res|import|png|jpg|jpeg|webp|svg|glb|gltf|bin|ogg|wav|mp3|exr)$') { $associatedPath } else { "" }
                associated_script = if ($associatedPath -match '(?i)\.(gd|cs)$') { $associatedPath } else { "" }
                failed_load_correlated = $text -match '(?i)(failed to load|cannot load|could not load|resource.*failed)'
                parse_failure_correlated = $text -match '(?i)(SCRIPT ERROR|Parse Error|Parser Error|compile error)'
                runtime_failure_correlated = $text -match '(?i)(runtime error|invalid call|stack trace|crash|segmentation fault|signal 11)'
                potential_diagnostic = (Test-McpPotentialDiagnosticText -Text $text -SourceStream $SourceStream) `
                    -or -not $utf8Valid `
                    -or $framedBytes.Contains([byte]0)
            }
            $records.Add($record)
        }
        $lineStart = $cursor + 1
    }

    for ($index = 0; $index -lt $records.Count; $index += 1) {
        if ($index -gt 0) {
            $records[$index].nearest_previous_log_record = [string]$records[$index - 1].category
        }
        if ($index + 1 -lt $records.Count) {
            $records[$index].nearest_next_log_record = [string]$records[$index + 1].category
        }
        $previousEventFound = $false
        $previousPathFound = $false
        for ($previous = $index - 1; $previous -ge 0; $previous -= 1) {
            if (-not $previousEventFound -and -not [bool]$records[$previous].potential_diagnostic) {
                $records[$index].previous_non_diagnostic_event = [string]$records[$previous].category
                $previousEventFound = $true
            }
            if (-not $previousPathFound -and -not [string]::IsNullOrWhiteSpace([string]$records[$previous].associated_path)) {
                $records[$index].nearest_previous_associated_path = [string]$records[$previous].associated_path
                $previousPathFound = $true
            }
            if ($previousEventFound -and $previousPathFound) {
                break
            }
        }
        $nextEventFound = $false
        $nextPathFound = $false
        for ($next = $index + 1; $next -lt $records.Count; $next += 1) {
            if (-not $nextEventFound -and -not [bool]$records[$next].potential_diagnostic) {
                $records[$index].next_non_diagnostic_event = [string]$records[$next].category
                $nextEventFound = $true
            }
            if (-not $nextPathFound -and -not [string]::IsNullOrWhiteSpace([string]$records[$next].associated_path)) {
                $records[$index].nearest_next_associated_path = [string]$records[$next].associated_path
                $nextPathFound = $true
            }
            if ($nextEventFound -and $nextPathFound) {
                break
            }
        }
    }

    $diagnostics = @($records | Where-Object { [bool]$_.potential_diagnostic })
    for ($index = 0; $index -lt $diagnostics.Count; $index += 1) {
        $diagnostics[$index]["diagnostic_index"] = $index + 1
    }
    return [ordered]@{
        schema = "McpRawLogSnapshotV1"
        source_path = $Path
        source_stream = $SourceStream
        stage = $Stage
        exists = $true
        file_length = $bytes.Length
        file_sha256 = Get-McpByteSha256Hex -Bytes $bytes
        snapshot_length = $snapshotLength
        last_write_time_utc = $file.LastWriteTimeUtc.ToString("o")
        capture_backend = "file_read_all_bytes_fixed_length_v1"
        raw_nul_count = @($bytes | Where-Object { $_ -eq 0 }).Count
        record_count = $records.Count
        diagnostic_count = $diagnostics.Count
        records = $records.ToArray()
        diagnostics = $diagnostics
    }
}

function Get-McpDiagnosticEnvironmentFingerprintV2 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Environment
    )

    $canonical = [ordered]@{
        godot_executable_sha256 = [string]$Environment.godot_executable_sha256
        godot_version = [string]$Environment.godot_version
        tooling_runtime_build_sha256 = [string]$Environment.tooling_runtime_build_sha256
        mcp_addon_tree = [string]$Environment.mcp_addon_tree
        launch_arguments_sha256 = [string]$Environment.launch_arguments_sha256
        locale = [string]$Environment.locale
        ui_locale = [string]$Environment.ui_locale
        powershell_version = [string]$Environment.powershell_version
        powershell_edition = [string]$Environment.powershell_edition
        platform = [string]$Environment.platform
        capture_backend = [string]$Environment.capture_backend
        renderer = [string]$Environment.renderer
        rendering_method = [string]$Environment.rendering_method
        rendering_driver = [string]$Environment.rendering_driver
        startup_timeout_seconds = [int]$Environment.startup_timeout_seconds
        recovery_import_timeout_seconds = [int]$Environment.recovery_import_timeout_seconds
        http_timeout_seconds = [int]$Environment.http_timeout_seconds
        initial_ready_stability_seconds = [int]$Environment.initial_ready_stability_seconds
        cache_layout = [string]$Environment.cache_layout
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($canonical | ConvertTo-Json -Depth 6 -Compress))
    return Get-McpByteSha256Hex -Bytes $bytes
}

function Get-McpDiagnosticFingerprintV2 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Diagnostic,
        [Parameter(Mandatory = $true)]
        [object]$Environment
    )

    $canonical = [ordered]@{
        raw_bytes_sha256 = [string]$Diagnostic.raw_bytes_sha256
        message_bytes_sha256 = [string]$Diagnostic.message_bytes_sha256
        line_ending_hex = [string]$Diagnostic.line_ending_hex
        raw_utf8_valid = [bool]$Diagnostic.raw_utf8_valid
        raw_nul_byte_count = [int]$Diagnostic.raw_nul_byte_count
        source_stream = [string]$Diagnostic.source_stream
        stage = [string]$Diagnostic.stage
        nearest_previous_log_record = [string]$Diagnostic.nearest_previous_log_record
        nearest_next_log_record = [string]$Diagnostic.nearest_next_log_record
        previous_non_diagnostic_event = [string]$Diagnostic.previous_non_diagnostic_event
        next_non_diagnostic_event = [string]$Diagnostic.next_non_diagnostic_event
        associated_path = [string]$Diagnostic.associated_path
        nearest_previous_associated_path = ConvertTo-McpDiagnosticComparablePath -Path ([string]$Diagnostic.nearest_previous_associated_path) -KeepResPrefix
        nearest_next_associated_path = ConvertTo-McpDiagnosticComparablePath -Path ([string]$Diagnostic.nearest_next_associated_path) -KeepResPrefix
        failed_load_correlated = [bool]$Diagnostic.failed_load_correlated
        parse_failure_correlated = [bool]$Diagnostic.parse_failure_correlated
        runtime_failure_correlated = [bool]$Diagnostic.runtime_failure_correlated
        environment_fingerprint = Get-McpDiagnosticEnvironmentFingerprintV2 -Environment $Environment
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($canonical | ConvertTo-Json -Depth 6 -Compress))
    return Get-McpByteSha256Hex -Bytes $bytes
}

function Get-McpDiagnosticCoreFingerprintV2 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Diagnostic,
        [Parameter(Mandatory = $true)]
        [object]$Environment
    )

    $canonical = [ordered]@{
        raw_bytes_sha256 = [string]$Diagnostic.raw_bytes_sha256
        message_bytes_sha256 = [string]$Diagnostic.message_bytes_sha256
        line_ending_hex = [string]$Diagnostic.line_ending_hex
        raw_utf8_valid = [bool]$Diagnostic.raw_utf8_valid
        raw_nul_byte_count = [int]$Diagnostic.raw_nul_byte_count
        source_stream = [string]$Diagnostic.source_stream
        stage = [string]$Diagnostic.stage
        associated_path = [string]$Diagnostic.associated_path
        failed_load_correlated = [bool]$Diagnostic.failed_load_correlated
        parse_failure_correlated = [bool]$Diagnostic.parse_failure_correlated
        runtime_failure_correlated = [bool]$Diagnostic.runtime_failure_correlated
        environment_fingerprint = Get-McpDiagnosticEnvironmentFingerprintV2 -Environment $Environment
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($canonical | ConvertTo-Json -Depth 6 -Compress))
    return Get-McpByteSha256Hex -Bytes $bytes
}

function Get-McpDiagnosticCorrelationPathsV2 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Diagnostic
    )

    $paths = @(
        [string]$Diagnostic.associated_path,
        [string]$Diagnostic.nearest_previous_associated_path,
        [string]$Diagnostic.nearest_next_associated_path
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
    return @($paths)
}

function Get-McpDiagnosticMultiset {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Diagnostics,
        [Parameter(Mandatory = $true)]
        [object]$Environment
    )

    $counts = [ordered]@{}
    foreach ($diagnostic in $Diagnostics) {
        $fingerprint = Get-McpDiagnosticFingerprintV2 -Diagnostic $diagnostic -Environment $Environment
        if (-not $counts.Contains($fingerprint)) {
            $counts[$fingerprint] = 0
        }
        $counts[$fingerprint] = [int]$counts[$fingerprint] + 1
    }
    return $counts
}

function Get-McpDiagnosticCoreMultisetV2 {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Diagnostics,
        [Parameter(Mandatory = $true)]
        [object]$Environment
    )

    $counts = [ordered]@{}
    foreach ($diagnostic in $Diagnostics) {
        $fingerprint = Get-McpDiagnosticCoreFingerprintV2 -Diagnostic $diagnostic -Environment $Environment
        if (-not $counts.Contains($fingerprint)) {
            $counts[$fingerprint] = 0
        }
        $counts[$fingerprint] = [int]$counts[$fingerprint] + 1
    }
    return $counts
}

function Compare-McpDiagnosticMirrorCoverageV2 {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$AuthoritativeDiagnostics,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$MirrorDiagnostics
    )

    $authoritative = [ordered]@{}
    foreach ($diagnostic in $AuthoritativeDiagnostics) {
        $key = [string]$diagnostic.message_bytes_sha256
        if (-not $authoritative.Contains($key)) { $authoritative[$key] = 0 }
        $authoritative[$key] = [int]$authoritative[$key] + 1
    }
    $mirror = [ordered]@{}
    foreach ($diagnostic in $MirrorDiagnostics) {
        $key = [string]$diagnostic.message_bytes_sha256
        if (-not $mirror.Contains($key)) { $mirror[$key] = 0 }
        $mirror[$key] = [int]$mirror[$key] + 1
    }
    $unmirrored = 0
    foreach ($key in $mirror.Keys) {
        $authoritativeCount = if ($authoritative.Contains($key)) { [int]$authoritative[$key] } else { 0 }
        if ([int]$mirror[$key] -gt $authoritativeCount) {
            $unmirrored += [int]$mirror[$key] - $authoritativeCount
        }
    }
    return [ordered]@{
        schema = "McpDiagnosticMirrorCoverageV2"
        green = $unmirrored -eq 0
        authoritative_diagnostic_count = $AuthoritativeDiagnostics.Count
        mirror_diagnostic_count = $MirrorDiagnostics.Count
        unmirrored_godot_diagnostic_count = $unmirrored
    }
}

function Test-McpPathInChangedFiles {
    param(
        [AllowEmptyString()]
        [string]$AssociatedPath,
        [string[]]$ChangedFiles = @()
    )

    if ([string]::IsNullOrWhiteSpace($AssociatedPath)) {
        return $false
    }
    $normalized = ConvertTo-McpDiagnosticComparablePath -Path $AssociatedPath
    foreach ($changedFile in $ChangedFiles) {
        $normalizedChangedFile = ConvertTo-McpDiagnosticComparablePath -Path $changedFile
        if ($normalized.Equals($normalizedChangedFile, [System.StringComparison]::OrdinalIgnoreCase) `
            -or $normalized.EndsWith("/$normalizedChangedFile", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-McpBaselineManifestPayloadV2 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Manifest
    )

    $multiplicity = [ordered]@{}
    $multiplicitySource = $Manifest.allowed_multiplicity
    $multiplicityKeys = if ($multiplicitySource -is [System.Collections.IDictionary]) {
        @($multiplicitySource.Keys)
    } else {
        @($multiplicitySource.PSObject.Properties.Name)
    }
    foreach ($key in @($multiplicityKeys | Sort-Object)) {
        $value = if ($multiplicitySource -is [System.Collections.IDictionary]) {
            $multiplicitySource[$key]
        } else {
            $multiplicitySource.PSObject.Properties[[string]$key].Value
        }
        $multiplicity[[string]$key] = [int]$value
    }
    return [ordered]@{
        schema = [string]$Manifest.schema
        task_id = [string]$Manifest.task_id
        attested = [bool]$Manifest.attested
        forensic_partial = [bool]$Manifest.forensic_partial
        attestation_scope = [string]$Manifest.attestation_scope
        comparison_green = [bool]$Manifest.comparison_green
        baseline_scope = [string]$Manifest.baseline_scope
        target_head = [string]$Manifest.target_head
        target_tree = [string]$Manifest.target_tree
        environment_fingerprint = [string]$Manifest.environment_fingerprint
        c0_head = [string]$Manifest.c0_head
        c1_head = [string]$Manifest.c1_head
        c2_head = [string]$Manifest.c2_head
        c0_source_is_ancestor = [bool]$Manifest.c0_source_is_ancestor
        c1_source_is_ancestor = [bool]$Manifest.c1_source_is_ancestor
        target_additional_diagnostic_count = [int]$Manifest.target_additional_diagnostic_count
        target_changed_file_diagnostic_count = [int]$Manifest.target_changed_file_diagnostic_count
        target_non_equivalent_diagnostic_count = [int]$Manifest.target_non_equivalent_diagnostic_count
        matrix_real_project_error_count = [int]$Manifest.matrix_real_project_error_count
        matrix_unmirrored_godot_diagnostic_count = [int]$Manifest.matrix_unmirrored_godot_diagnostic_count
        allowed_fingerprints = @($Manifest.allowed_fingerprints | ForEach-Object { [string]$_ } | Sort-Object)
        allowed_multiplicity = $multiplicity
        baseline_core_fingerprints = @($Manifest.baseline_core_fingerprints | ForEach-Object { [string]$_ } | Sort-Object)
    }
}

function Get-McpBaselineManifestSha256V2 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Manifest
    )

    $payload = Get-McpBaselineManifestPayloadV2 -Manifest $Manifest
    return Get-McpByteSha256Hex -Bytes ([System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 8 -Compress)))
}

function Test-McpBaselineManifestV2 {
    param(
        [AllowNull()]
        [object]$Manifest,
        [Parameter(Mandatory = $true)]
        [object]$Environment,
        [switch]$AllowForensicPartial,
        [AllowEmptyString()][string]$ExpectedTargetHead = "",
        [AllowEmptyString()][string]$ExpectedTargetTree = ""
    )

    if ($null -eq $Manifest) {
        return [ordered]@{ valid = $false; reason_code = "baseline_fingerprint_missing" }
    }
    if ([string]$Manifest.schema -ne "McpBaselineDiagnosticManifestV2") {
        return [ordered]@{ valid = $false; reason_code = "baseline_fingerprint_file_corrupt" }
    }
    try {
        $expectedSha = Get-McpBaselineManifestSha256V2 -Manifest $Manifest
    } catch {
        return [ordered]@{ valid = $false; reason_code = "baseline_fingerprint_file_corrupt" }
    }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.manifest_sha256) -or [string]$Manifest.manifest_sha256 -ne $expectedSha) {
        return [ordered]@{ valid = $false; reason_code = "baseline_fingerprint_file_corrupt" }
    }
    if (-not [bool]$Manifest.c0_source_is_ancestor -or -not [bool]$Manifest.c1_source_is_ancestor) {
        return [ordered]@{ valid = $false; reason_code = "baseline_commit_not_ancestor" }
    }
    $environmentFingerprint = Get-McpDiagnosticEnvironmentFingerprintV2 -Environment $Environment
    if ([string]$Manifest.environment_fingerprint -ne $environmentFingerprint) {
        return [ordered]@{ valid = $false; reason_code = "diagnostic_environment_mismatch" }
    }
    if ([string]$Manifest.target_head -ne [string]$Manifest.c2_head `
        -or [string]::IsNullOrWhiteSpace([string]$Manifest.target_tree)) {
        return [ordered]@{ valid = $false; reason_code = "baseline_target_binding_invalid" }
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedTargetHead) `
        -and [string]$Manifest.target_head -ne $ExpectedTargetHead) {
        return [ordered]@{ valid = $false; reason_code = "baseline_target_head_mismatch" }
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedTargetTree) `
        -and [string]$Manifest.target_tree -ne $ExpectedTargetTree) {
        return [ordered]@{ valid = $false; reason_code = "baseline_target_tree_mismatch" }
    }
    $acceptanceValid = [bool]$Manifest.attested `
        -and [bool]$Manifest.comparison_green `
        -and [string]$Manifest.attestation_scope -eq "acceptance" `
        -and [int]$Manifest.target_additional_diagnostic_count -eq 0 `
        -and [int]$Manifest.target_changed_file_diagnostic_count -eq 0 `
        -and [int]$Manifest.target_non_equivalent_diagnostic_count -eq 0 `
        -and [int]$Manifest.matrix_real_project_error_count -eq 0 `
        -and [int]$Manifest.matrix_unmirrored_godot_diagnostic_count -eq 0
    if (-not $acceptanceValid) {
        if (-not $AllowForensicPartial `
            -or -not [bool]$Manifest.forensic_partial `
            -or [string]$Manifest.attestation_scope -ne "forensic_partial") {
            return [ordered]@{ valid = $false; acceptance_valid = $false; reason_code = "baseline_not_acceptance_attested" }
        }
    }
    return [ordered]@{
        valid = $true
        acceptance_valid = $acceptanceValid
        forensic_partial = -not $acceptanceValid
        reason_code = "none"
    }
}

function Get-McpDiagnosticClassificationV2 {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Diagnostic,
        [Parameter(Mandatory = $true)]
        [object]$Environment,
        [AllowNull()]
        [object]$BaselineManifest = $null,
        [string[]]$ChangedFiles = @(),
        [bool]$CurrentAttemptIsTarget = $true,
        [bool]$GodotHasCorrespondingDiagnostic = $true,
        [bool]$WrapperDecodeEvidence = $false,
        [AllowEmptyString()][string]$CurrentProjectHead = "",
        [AllowEmptyString()][string]$CurrentProjectTree = ""
    )

    $associatedPath = [string]$Diagnostic.associated_path
    $correlationPaths = @(Get-McpDiagnosticCorrelationPathsV2 -Diagnostic $Diagnostic)
    $changedFilePaths = @($correlationPaths | Where-Object {
        Test-McpPathInChangedFiles -AssociatedPath $_ -ChangedFiles $ChangedFiles
    })
    $changedFile = $changedFilePaths.Count -gt 0
    $classification = "unclassified"
    $reason = "insufficient_attribution_evidence"
    if ($changedFile) {
        $classification = "changed_file_error"
        $reason = "diagnostic_associated_with_target_changed_file"
    } elseif ([bool]$Diagnostic.parse_failure_correlated) {
        $classification = "project_script_parse_error"
        $reason = "parse_failure_correlation"
    } elseif ([bool]$Diagnostic.failed_load_correlated) {
        $classification = "project_resource_load_error"
        $reason = "failed_load_correlation"
    } elseif ([bool]$Diagnostic.runtime_failure_correlated) {
        $classification = "project_runtime_error"
        $reason = "runtime_failure_correlation"
    } elseif ([int]$Diagnostic.raw_nul_byte_count -gt 0) {
        $classification = "unclassified"
        $reason = "raw_nul_requires_explicit_attribution"
    } elseif (-not [bool]$Diagnostic.raw_utf8_valid) {
        if (-not $GodotHasCorrespondingDiagnostic -and $WrapperDecodeEvidence) {
            $classification = "wrapper_decode_artifact"
            $reason = "invalid_utf8_raw_stream_and_wrapper_decode_proof"
        } else {
            $classification = "unclassified"
            $reason = "invalid_utf8_without_wrapper_artifact_proof"
        }
    } elseif (-not [bool]$Diagnostic.potential_diagnostic) {
        $classification = "informational"
        $reason = "record_is_not_a_diagnostic"
    } else {
        $fingerprint = Get-McpDiagnosticFingerprintV2 -Diagnostic $Diagnostic -Environment $Environment
        $coreFingerprint = Get-McpDiagnosticCoreFingerprintV2 -Diagnostic $Diagnostic -Environment $Environment
        $manifestValidation = Test-McpBaselineManifestV2 `
            -Manifest $BaselineManifest `
            -Environment $Environment `
            -AllowForensicPartial `
            -ExpectedTargetHead $CurrentProjectHead `
            -ExpectedTargetTree $CurrentProjectTree
        $baselineFingerprints = if ([bool]$manifestValidation.valid) { @($BaselineManifest.allowed_fingerprints) } else { @() }
        if ([bool]$manifestValidation.valid `
            -and $baselineFingerprints -contains $fingerprint `
            -and [string]::IsNullOrWhiteSpace($associatedPath) `
            -and $correlationPaths.Count -eq 0 `
            -and -not [bool]$Diagnostic.failed_load_correlated `
            -and -not [bool]$Diagnostic.parse_failure_correlated `
            -and -not [bool]$Diagnostic.runtime_failure_correlated) {
            $classification = "baseline_engine_import_diagnostic"
            $reason = "exact_environment_bound_baseline_fingerprint"
        } elseif ([bool]$manifestValidation.valid -and $CurrentAttemptIsTarget) {
            if (@($BaselineManifest.baseline_core_fingerprints) -contains $coreFingerprint) {
                $classification = "unclassified"
                $reason = "baseline_neighbor_context_mismatch"
            } else {
                $classification = "task_introduced_error"
                $reason = "target_diagnostic_missing_from_attested_baseline"
            }
        } elseif (-not [bool]$manifestValidation.valid) {
            $reason = [string]$manifestValidation.reason_code
        }
    }
    return [ordered]@{
        schema = "McpDiagnosticClassificationV2"
        classification = $classification
        reason_code = $reason
        raw_bytes_sha256 = [string]$Diagnostic.raw_bytes_sha256
        diagnostic_fingerprint = Get-McpDiagnosticFingerprintV2 -Diagnostic $Diagnostic -Environment $Environment
        diagnostic_core_fingerprint = Get-McpDiagnosticCoreFingerprintV2 -Diagnostic $Diagnostic -Environment $Environment
        associated_path = $associatedPath
        changed_file_correlated = $changedFile
        changed_file_correlation_paths = $changedFilePaths
        correlation_paths = $correlationPaths
    }
}

function Get-McpDiagnosticGateV2 {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Classifications,
        [AllowNull()][object]$BaselineManifest = $null,
        [AllowNull()][object]$Environment = $null,
        [AllowEmptyString()][string]$CurrentProjectHead = "",
        [AllowEmptyString()][string]$CurrentProjectTree = ""
    )

    $counts = [ordered]@{
        total = $Classifications.Count
        baseline_engine_import_diagnostic = 0
        wrapper_decode_artifact = 0
        project_script_parse_error = 0
        project_resource_load_error = 0
        project_runtime_error = 0
        changed_file_error = 0
        task_introduced_error = 0
        informational = 0
        unclassified = 0
    }
    foreach ($classification in $Classifications) {
        $name = [string]$classification.classification
        if ($counts.Contains($name)) {
            $counts[$name] = [int]$counts[$name] + 1
        } else {
            $counts.unclassified = [int]$counts.unclassified + 1
        }
    }
    $baselineMultiplicityMismatchCount = 0
    $baselineManifestAcceptanceValid = $true
    $baselineClasses = @($Classifications | Where-Object {
        [string]$_.classification -eq "baseline_engine_import_diagnostic"
    })
    if ($null -ne $BaselineManifest) {
        if ($null -eq $Environment) {
            $baselineManifestAcceptanceValid = $false
        } else {
            $manifestValidation = Test-McpBaselineManifestV2 `
                -Manifest $BaselineManifest `
                -Environment $Environment `
                -ExpectedTargetHead $CurrentProjectHead `
                -ExpectedTargetTree $CurrentProjectTree
            $baselineManifestAcceptanceValid = [bool]$manifestValidation.valid
        }
        $expectedMultiplicity = [ordered]@{}
        try {
            $source = $BaselineManifest.allowed_multiplicity
            $keys = if ($source -is [System.Collections.IDictionary]) {
                @($source.Keys)
            } else {
                @($source.PSObject.Properties.Name)
            }
            foreach ($key in $keys) {
                $value = if ($source -is [System.Collections.IDictionary]) {
                    $source[$key]
                } else {
                    $source.PSObject.Properties[[string]$key].Value
                }
                $expectedMultiplicity[[string]$key] = [int]$value
            }
        } catch {
            $baselineManifestAcceptanceValid = $false
        }
        $observedMultiplicity = [ordered]@{}
        foreach ($classification in $baselineClasses) {
            $fingerprint = [string]$classification.diagnostic_fingerprint
            if (-not $observedMultiplicity.Contains($fingerprint)) {
                $observedMultiplicity[$fingerprint] = 0
            }
            $observedMultiplicity[$fingerprint] = [int]$observedMultiplicity[$fingerprint] + 1
        }
        $multiplicityKeys = @($expectedMultiplicity.Keys + $observedMultiplicity.Keys | Sort-Object -Unique)
        foreach ($key in $multiplicityKeys) {
            $expected = if ($expectedMultiplicity.Contains($key)) { [int]$expectedMultiplicity[$key] } else { 0 }
            $observed = if ($observedMultiplicity.Contains($key)) { [int]$observedMultiplicity[$key] } else { 0 }
            $baselineMultiplicityMismatchCount += [Math]::Abs($expected - $observed)
        }
    } elseif ($baselineClasses.Count -gt 0) {
        $baselineManifestAcceptanceValid = $false
        $baselineMultiplicityMismatchCount = $baselineClasses.Count
    }
    $realProjectErrors = [int]$counts.project_script_parse_error + [int]$counts.project_resource_load_error + [int]$counts.project_runtime_error
    $green = $realProjectErrors -eq 0 `
        -and [int]$counts.changed_file_error -eq 0 `
        -and [int]$counts.task_introduced_error -eq 0 `
        -and [int]$counts.unclassified -eq 0 `
        -and $baselineManifestAcceptanceValid `
        -and $baselineMultiplicityMismatchCount -eq 0
    return [ordered]@{
        schema = "McpDiagnosticGateV2"
        green = $green
        counts = $counts
        real_project_error_count = $realProjectErrors
        baseline_engine_diagnostic_count = [int]$counts.baseline_engine_import_diagnostic
        wrapper_artifact_count = [int]$counts.wrapper_decode_artifact
        changed_file_error_count = [int]$counts.changed_file_error
        task_introduced_error_count = [int]$counts.task_introduced_error
        runtime_error_count = [int]$counts.project_runtime_error
        unclassified_diagnostic_count = [int]$counts.unclassified
        baseline_manifest_acceptance_valid = $baselineManifestAcceptanceValid
        baseline_multiplicity_mismatch_count = $baselineMultiplicityMismatchCount
        baseline_diagnostic_allowlist_scope = "exact_fingerprint_and_environment_only"
    }
}

function Compare-McpColdImportDiagnosticAttemptsV2 {
    param(
        [Parameter(Mandatory = $true)][object]$C0,
        [Parameter(Mandatory = $true)][object]$C1,
        [Parameter(Mandatory = $true)][object]$C2,
        [string[]]$ChangedFiles = @()
    )

    $requiredSchema = "McpColdImportDiagnosticAttemptV1"
    $matrixUnmirroredGodotDiagnosticCount = 0
    foreach ($attempt in @($C0, $C1, $C2)) {
        if ([string]$attempt.schema -ne $requiredSchema) {
            return [ordered]@{ valid = $false; reason_code = "baseline_fingerprint_file_corrupt" }
        }
        if (-not [bool]$attempt.cache_was_fresh) {
            return [ordered]@{ valid = $false; reason_code = "cache_reused_attempt" }
        }
        if (-not [bool]$attempt.project_head_match) {
            return [ordered]@{ valid = $false; reason_code = "project_head_mismatch" }
        }
        if (-not [bool]$attempt.project_reload_green) {
            return [ordered]@{ valid = $false; reason_code = "project_reload_not_green" }
        }
        if (-not [bool]$attempt.script_discovery_green) {
            return [ordered]@{ valid = $false; reason_code = "script_discovery_not_green" }
        }
        $mirrorCoverage = Get-McpDiagnosticObjectValueV2 -Object $attempt -Name "diagnostic_mirror_coverage"
        if ($null -eq $mirrorCoverage -or [string]$mirrorCoverage.schema -ne "McpDiagnosticMirrorCoverageV2") {
            return [ordered]@{ valid = $false; reason_code = "diagnostic_mirror_coverage_missing" }
        }
        $matrixUnmirroredGodotDiagnosticCount += [int]$mirrorCoverage.unmirrored_godot_diagnostic_count
    }
    if (-not [bool]$C0.source_commit_is_ancestor_of_target -or -not [bool]$C1.source_commit_is_ancestor_of_target) {
        return [ordered]@{ valid = $false; reason_code = "baseline_commit_not_ancestor" }
    }
    $environment0 = Get-McpDiagnosticEnvironmentFingerprintV2 -Environment $C0.environment
    $environment1 = Get-McpDiagnosticEnvironmentFingerprintV2 -Environment $C1.environment
    $environment2 = Get-McpDiagnosticEnvironmentFingerprintV2 -Environment $C2.environment
    if ($environment0 -ne $environment1 -or $environment1 -ne $environment2) {
        return [ordered]@{ valid = $false; reason_code = "diagnostic_environment_mismatch" }
    }

    $c0Recovery = Get-McpDiagnosticObjectValueV2 -Object $C0 -Name "recovery_import_stderr"
    $c1Recovery = Get-McpDiagnosticObjectValueV2 -Object $C1 -Name "recovery_import_stderr"
    $c2Recovery = Get-McpDiagnosticObjectValueV2 -Object $C2 -Name "recovery_import_stderr"
    $c0EditorDiagnostics = @($C0.editor_stderr.diagnostics)
    $c1EditorDiagnostics = @($C1.editor_stderr.diagnostics)
    $c2EditorDiagnostics = @($C2.editor_stderr.diagnostics)
    $c0RecoveryDiagnostics = if ($null -ne $c0Recovery) { @($c0Recovery.diagnostics) } else { @() }
    $c1RecoveryDiagnostics = if ($null -ne $c1Recovery) { @($c1Recovery.diagnostics) } else { @() }
    $c2RecoveryDiagnostics = if ($null -ne $c2Recovery) { @($c2Recovery.diagnostics) } else { @() }
    $c0Diagnostics = @($c0EditorDiagnostics + $c0RecoveryDiagnostics)
    $c1Diagnostics = @($c1EditorDiagnostics + $c1RecoveryDiagnostics)
    $c2Diagnostics = @($c2EditorDiagnostics + $c2RecoveryDiagnostics)
    $c0Set = Get-McpDiagnosticMultiset -Diagnostics $c0Diagnostics -Environment $C0.environment
    $c1Set = Get-McpDiagnosticMultiset -Diagnostics $c1Diagnostics -Environment $C1.environment
    $c2Set = Get-McpDiagnosticMultiset -Diagnostics $c2Diagnostics -Environment $C2.environment
    $c0CoreSet = Get-McpDiagnosticCoreMultisetV2 -Diagnostics $c0Diagnostics -Environment $C0.environment
    $c1CoreSet = Get-McpDiagnosticCoreMultisetV2 -Diagnostics $c1Diagnostics -Environment $C1.environment
    $c2CoreSet = Get-McpDiagnosticCoreMultisetV2 -Diagnostics $c2Diagnostics -Environment $C2.environment
    $allKeys = @($c0Set.Keys + $c1Set.Keys + $c2Set.Keys | Sort-Object -Unique)
    $baselineEquivalent = $true
    $allowed = [System.Collections.Generic.List[string]]::new()
    $allowedMultiplicity = [ordered]@{}
    $nonEquivalentTargetDiagnosticCount = 0
    $baselineScope = "global_main_parent"
    foreach ($key in $allKeys) {
        $count0 = if ($c0Set.Contains($key)) { [int]$c0Set[$key] } else { 0 }
        $count1 = if ($c1Set.Contains($key)) { [int]$c1Set[$key] } else { 0 }
        $count2 = if ($c2Set.Contains($key)) { [int]$c2Set[$key] } else { 0 }
        if ($count0 -ne $count1 -or $count1 -ne $count2) {
            $baselineEquivalent = $false
        }
        $strictGlobalMatch = $count2 -gt 0 -and $count0 -eq $count1 -and $count1 -eq $count2
        $parentChainMatch = $count2 -gt 0 -and $count0 -eq 0 -and $count1 -eq $count2
        if ($strictGlobalMatch -or $parentChainMatch) {
            $allowed.Add([string]$key)
            $allowedMultiplicity[[string]$key] = $count2
            if ($parentChainMatch) {
                $baselineScope = "parent_chain_only"
            }
        } elseif ($count2 -gt 0) {
            $nonEquivalentTargetDiagnosticCount += $count2
        }
    }
    $targetAdditional = 0
    $baselineCoreFingerprints = [System.Collections.Generic.List[string]]::new()
    $allCoreKeys = @($c0CoreSet.Keys + $c1CoreSet.Keys + $c2CoreSet.Keys | Sort-Object -Unique)
    foreach ($key in $allCoreKeys) {
        $count0 = if ($c0CoreSet.Contains($key)) { [int]$c0CoreSet[$key] } else { 0 }
        $count1 = if ($c1CoreSet.Contains($key)) { [int]$c1CoreSet[$key] } else { 0 }
        $count2 = if ($c2CoreSet.Contains($key)) { [int]$c2CoreSet[$key] } else { 0 }
        $baselineMaximum = [Math]::Max($count0, $count1)
        if ($baselineMaximum -gt 0) {
            $baselineCoreFingerprints.Add([string]$key)
        }
        if ($count2 -gt $baselineMaximum) {
            $targetAdditional += $count2 - $baselineMaximum
        }
    }
    $changedFileDiagnosticCount = @($c2Diagnostics | Where-Object {
        $candidate = $_
        @((Get-McpDiagnosticCorrelationPathsV2 -Diagnostic $candidate) | Where-Object {
            Test-McpPathInChangedFiles -AssociatedPath $_ -ChangedFiles $ChangedFiles
        }).Count -gt 0
    }).Count
    $matrixRealProjectErrorCount = @(@($c0Diagnostics + $c1Diagnostics + $c2Diagnostics) | Where-Object {
        [bool]$_.parse_failure_correlated `
            -or [bool]$_.failed_load_correlated `
            -or [bool]$_.runtime_failure_correlated
    }).Count
    $comparisonGreen = $targetAdditional -eq 0 `
        -and $changedFileDiagnosticCount -eq 0 `
        -and $nonEquivalentTargetDiagnosticCount -eq 0 `
        -and $matrixRealProjectErrorCount -eq 0 `
        -and $matrixUnmirroredGodotDiagnosticCount -eq 0
    $manifest = [ordered]@{
        schema = "McpBaselineDiagnosticManifestV2"
        task_id = "ALPHA_0_4_C_MCP_COLD_IMPORT_UNICODE_NUL_BASELINE_ATTRIBUTION_GATE_REPAIR_AND_EXACT_SHA_ACCEPTANCE"
        attested = $comparisonGreen
        forensic_partial = -not $comparisonGreen
        attestation_scope = if ($comparisonGreen) { "acceptance" } else { "forensic_partial" }
        comparison_green = $comparisonGreen
        baseline_scope = $baselineScope
        target_head = [string]$C2.project_head
        target_tree = [string](Get-McpDiagnosticObjectValueV2 -Object $C2 -Name "project_tree" -Default "unknown")
        environment_fingerprint = $environment0
        c0_head = [string]$C0.project_head
        c1_head = [string]$C1.project_head
        c2_head = [string]$C2.project_head
        c0_source_is_ancestor = [bool]$C0.source_commit_is_ancestor_of_target
        c1_source_is_ancestor = [bool]$C1.source_commit_is_ancestor_of_target
        target_additional_diagnostic_count = $targetAdditional
        target_changed_file_diagnostic_count = $changedFileDiagnosticCount
        target_non_equivalent_diagnostic_count = $nonEquivalentTargetDiagnosticCount
        matrix_real_project_error_count = $matrixRealProjectErrorCount
        matrix_unmirrored_godot_diagnostic_count = $matrixUnmirroredGodotDiagnosticCount
        allowed_fingerprints = $allowed.ToArray()
        allowed_multiplicity = $allowedMultiplicity
        baseline_core_fingerprints = $baselineCoreFingerprints.ToArray()
    }
    $manifest["manifest_sha256"] = Get-McpBaselineManifestSha256V2 -Manifest $manifest
    return [ordered]@{
        schema = "McpColdImportDiagnosticComparisonV2"
        valid = $true
        reason_code = if ($matrixRealProjectErrorCount -gt 0) { "matrix_project_errors_present" } elseif ($matrixUnmirroredGodotDiagnosticCount -gt 0) { "unmirrored_godot_diagnostic_present" } elseif (-not $comparisonGreen) { "diagnostic_comparison_not_green" } else { "none" }
        baseline_diagnostic_equivalent = $baselineEquivalent
        target_additional_diagnostic_count = $targetAdditional
        target_changed_file_diagnostic_count = $changedFileDiagnosticCount
        target_non_equivalent_diagnostic_count = $nonEquivalentTargetDiagnosticCount
        c0_diagnostic_count = @($c0Diagnostics).Count
        c1_diagnostic_count = @($c1Diagnostics).Count
        c2_diagnostic_count = @($c2Diagnostics).Count
        c0_editor_diagnostic_count = @($c0EditorDiagnostics).Count
        c1_editor_diagnostic_count = @($c1EditorDiagnostics).Count
        c2_editor_diagnostic_count = @($c2EditorDiagnostics).Count
        c0_recovery_diagnostic_count = @($c0RecoveryDiagnostics).Count
        c1_recovery_diagnostic_count = @($c1RecoveryDiagnostics).Count
        c2_recovery_diagnostic_count = @($c2RecoveryDiagnostics).Count
        matrix_real_project_error_count = $matrixRealProjectErrorCount
        matrix_unmirrored_godot_diagnostic_count = $matrixUnmirroredGodotDiagnosticCount
        environment_fingerprint = $environment0
        allowed_fingerprints = $allowed.ToArray()
        allowed_multiplicity = $allowedMultiplicity
        baseline_core_fingerprints = $baselineCoreFingerprints.ToArray()
        baseline_manifest = $manifest
        green = $comparisonGreen
    }
}
