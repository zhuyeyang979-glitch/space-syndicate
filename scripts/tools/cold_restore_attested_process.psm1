Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ChildCompletionFields = @(
    "schema_version",
    "run_id",
    "role",
    "repository_head",
    "scenario_fingerprint",
    "official",
    "formal",
    "qualification_completed",
    "qualification_green",
    "product_blocker",
    "queue_count",
    "queue_revision",
    "queue_trigger_actor",
    "queue_trigger_semantic_action_id",
    "queue_trigger_card_semantic_id",
    "queue_trigger_target_fingerprint",
    "save_written",
    "official_count_consumed",
    "product_mutation_count",
    "direct_authority_mutation_count",
    "queue_injection_count",
    "final_reason_code",
    "evidence_fingerprint",
    "child_ready_to_exit"
)

$script:ParentExitFields = @(
    "schema_version",
    "run_id",
    "role",
    "child_pid",
    "observed_exit",
    "exit_code",
    "timed_out",
    "terminated_by_parent",
    "stdout_sha256",
    "stderr_sha256",
    "child_attestation_found",
    "child_attestation_fingerprint",
    "child_attestation_valid",
    "task_owned_process_count_after",
    "unrelated_preexisting_process_count",
    "wrapper_exit_green",
    "wrapper_reason_code"
)

function ConvertTo-ColdRestoreCanonicalJson {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return "null"
    }
    if ($Value -is [bool]) {
        return $(if ($Value) { "true" } else { "false" })
    }
    if ($Value -is [string] -or $Value -is [char]) {
        return ([string]$Value | ConvertTo-Json -Compress)
    }
    if ($Value -is [byte] -or $Value -is [sbyte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64] -or $Value -is [uint64]) {
        return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [float] -or $Value -is [double] -or $Value -is [decimal]) {
        return ([IFormattable]$Value).ToString("R", [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [Collections.IDictionary]) {
        $members = foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) {
            "$(ConvertTo-ColdRestoreCanonicalJson $key):$(ConvertTo-ColdRestoreCanonicalJson $Value[$key])"
        }
        return "{$($members -join ',')}"
    }
    if ($Value -is [Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = foreach ($item in $Value) {
            ConvertTo-ColdRestoreCanonicalJson $item
        }
        return "[$($items -join ',')]"
    }
    $properties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -in @("NoteProperty", "Property") })
    if ($properties.Count -gt 0) {
        $members = foreach ($property in @($properties | Sort-Object Name -CaseSensitive)) {
            "$(ConvertTo-ColdRestoreCanonicalJson $property.Name):$(ConvertTo-ColdRestoreCanonicalJson $property.Value)"
        }
        return "{$($members -join ',')}"
    }
    throw "canonical_json_type_invalid"
}

function Get-ColdRestoreTextSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return ([Convert]::ToHexString($hash)).ToLowerInvariant()
}

function Get-ColdRestoreEvidenceFingerprint {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [string]$OmittedField = ""
    )

    $copy = [ordered]@{}
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ([string]$key -ne $OmittedField) {
                $copy[[string]$key] = $Value[$key]
            }
        }
    }
    else {
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name -ne $OmittedField) {
                $copy[$property.Name] = $property.Value
            }
        }
    }
    return Get-ColdRestoreTextSha256 (ConvertTo-ColdRestoreCanonicalJson $copy)
}

function Test-ColdRestoreExactFieldSet {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedFields
    )

    $actual = @($Value.PSObject.Properties.Name | Sort-Object -CaseSensitive)
    $expected = @($ExpectedFields | Sort-Object -CaseSensitive)
    return @(Compare-Object -ReferenceObject $expected -DifferenceObject $actual -CaseSensitive).Count -eq 0
}

function Write-ColdRestoreAtomicJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $parent = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    if ([IO.File]::Exists($Path)) {
        throw "evidence_collision"
    }
    $tempPath = "$Path.tmp.$PID.$([Guid]::NewGuid().ToString('N'))"
    $json = ConvertTo-ColdRestoreCanonicalJson $Value
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    try {
        $stream = [IO.FileStream]::new(
            $tempPath,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None,
            4096,
            [IO.FileOptions]::WriteThrough
        )
        try {
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush($true)
        }
        finally {
            $stream.Dispose()
        }
        $readback = [IO.File]::ReadAllText($tempPath, [Text.UTF8Encoding]::new($false))
        if ($readback -cne $json) {
            throw "evidence_readback_failed"
        }
        $null = $readback | ConvertFrom-Json
        [IO.File]::Move($tempPath, $Path)
        $finalReadback = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false))
        if ($finalReadback -cne $json) {
            throw "evidence_final_readback_failed"
        }
    }
    finally {
        if ([IO.File]::Exists($tempPath)) {
            [IO.File]::Delete($tempPath)
        }
    }
    return Get-ColdRestoreTextSha256 $json
}

function New-ColdRestoreChildCompletionFixture {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [bool]$QualificationGreen = $true,
        [string]$ProductBlocker = "",
        [int]$QueueCount = 1
    )

    $value = [ordered]@{
        schema_version = 1
        run_id = $RunId
        role = $Role
        repository_head = $RepositoryHead
        scenario_fingerprint = ("a" * 64)
        official = $false
        formal = $false
        qualification_completed = $true
        qualification_green = $QualificationGreen
        product_blocker = $ProductBlocker
        queue_count = $QueueCount
        queue_revision = $QueueCount
        queue_trigger_actor = $(if ($QueueCount -gt 0) { "local" } else { "none" })
        queue_trigger_semantic_action_id = $(if ($QueueCount -gt 0) { "card.play" } else { "" })
        queue_trigger_card_semantic_id = $(if ($QueueCount -gt 0) { "fixture.card" } else { "" })
        queue_trigger_target_fingerprint = $(if ($QueueCount -gt 0) { "b" * 64 } else { "" })
        save_written = $false
        official_count_consumed = $false
        product_mutation_count = 0
        direct_authority_mutation_count = 0
        queue_injection_count = 0
        final_reason_code = $(if ($QualificationGreen) { "qualification_green" } else { $ProductBlocker })
        evidence_fingerprint = ""
        child_ready_to_exit = $true
    }
    $value.evidence_fingerprint = Get-ColdRestoreEvidenceFingerprint $value "evidence_fingerprint"
    return [pscustomobject]$value
}

function Test-ColdRestoreChildCompletionAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId,
        [Parameter(Mandatory = $true)][string]$ExpectedRole,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        [Parameter(Mandatory = $true)][datetime]$ProcessStartedAtUtc
    )

    if (-not [IO.File]::Exists($Path)) {
        return [pscustomobject]@{ valid = $false; found = $false; reason_code = "child_attestation_missing"; fingerprint = ""; value = $null }
    }
    if ([IO.File]::GetLastWriteTimeUtc($Path) -lt $ProcessStartedAtUtc.AddSeconds(-1)) {
        return [pscustomobject]@{ valid = $false; found = $true; reason_code = "child_attestation_stale"; fingerprint = ""; value = $null }
    }
    try {
        $value = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{ valid = $false; found = $true; reason_code = "child_attestation_json_invalid"; fingerprint = ""; value = $null }
    }
    if (-not (Test-ColdRestoreExactFieldSet $value $script:ChildCompletionFields)) {
        return [pscustomobject]@{ valid = $false; found = $true; reason_code = "child_attestation_field_set_invalid"; fingerprint = ""; value = $value }
    }
    $reason = ""
    if ([int]$value.schema_version -ne 1) { $reason = "child_attestation_schema_invalid" }
    elseif ([string]$value.run_id -cne $ExpectedRunId) { $reason = "child_attestation_run_id_mismatch" }
    elseif ([string]$value.role -cne $ExpectedRole) { $reason = "child_attestation_role_mismatch" }
    elseif ([string]$value.repository_head -cne $ExpectedRepositoryHead) { $reason = "child_attestation_repository_head_mismatch" }
    elseif ($value.child_ready_to_exit -isnot [bool] -or -not [bool]$value.child_ready_to_exit) { $reason = "child_attestation_not_ready_to_exit" }
    elseif ($value.qualification_completed -isnot [bool] -or -not [bool]$value.qualification_completed) { $reason = "child_attestation_qualification_incomplete" }
    elseif ([string]$value.queue_trigger_actor -notin @("local", "ai", "none")) { $reason = "child_attestation_actor_invalid" }
    elseif ([int64]$value.queue_count -lt 0 -or [int64]$value.queue_revision -lt 0) { $reason = "child_attestation_count_invalid" }
    elseif ([bool]$value.qualification_green -and -not [string]::IsNullOrEmpty([string]$value.product_blocker)) { $reason = "child_attestation_green_blocker_conflict" }
    elseif (-not [bool]$value.qualification_green -and [string]::IsNullOrEmpty([string]$value.product_blocker)) { $reason = "child_attestation_blocker_missing" }
    $fingerprint = Get-ColdRestoreEvidenceFingerprint $value "evidence_fingerprint"
    if ([string]::IsNullOrEmpty($reason) -and [string]$value.evidence_fingerprint -cne $fingerprint) {
        $reason = "child_attestation_fingerprint_invalid"
    }
    return [pscustomobject]@{
        valid = [string]::IsNullOrEmpty($reason)
        found = $true
        reason_code = $(if ([string]::IsNullOrEmpty($reason)) { "ok" } else { $reason })
        fingerprint = $(if ([string]::IsNullOrEmpty($reason)) { $fingerprint } else { "" })
        value = $value
    }
}

function New-ColdRestoreGodotArgumentList {
    param(
        [Parameter(Mandatory = $true)][string[]]$EngineArgumentList,
        [Parameter(Mandatory = $true)][string[]]$UserArgumentList
    )

    $engineOnly = @("--check-only", "--headless", "--path", "--script", "--editor", "--import")
    if ($EngineArgumentList -contains "--" -or $UserArgumentList -contains "--") {
        throw "godot_argument_separator_duplicated"
    }
    foreach ($argument in $UserArgumentList) {
        $name = ([string]$argument).Split("=", 2)[0]
        if ($name -in $engineOnly) {
            throw "godot_engine_argument_after_separator"
        }
    }
    return @($EngineArgumentList) + @("--") + @($UserArgumentList)
}

function Get-ColdRestoreProcessSnapshot {
    try {
        return @(Get-CimInstance Win32_Process -ErrorAction Stop | Select-Object ProcessId, ParentProcessId, Name, CommandLine)
    }
    catch {
        return @()
    }
}

function Add-ColdRestoreOwnedProcesses {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][Collections.Generic.HashSet[int]]$OwnedIds,
        [Parameter(Mandatory = $true)][array]$Snapshot,
        [Parameter(Mandatory = $true)][string]$RunId
    )

    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($record in $Snapshot) {
            $pidValue = [int]$record.ProcessId
            $parentValue = [int]$record.ParentProcessId
            if ($OwnedIds.Contains($parentValue) -and $OwnedIds.Add($pidValue)) {
                $changed = $true
            }
        }
    }
}

function Invoke-ColdRestoreAttestedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$ExecutablePath,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][string]$ChildAttestationPath,
        [Parameter(Mandatory = $true)][string]$ParentAttestationPath,
        [Parameter(Mandatory = $true)][string]$StdoutPath,
        [Parameter(Mandatory = $true)][string]$StderrPath,
        [Parameter(Mandatory = $true)][ValidateRange(1, 3600)][int]$TimeoutSeconds,
        [hashtable]$EnvironmentVariables = @{}
    )

    foreach ($path in @($ChildAttestationPath, $ParentAttestationPath, $StdoutPath, $StderrPath)) {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    }
    $preexistingGodotCount = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "godot*" }).Count
    $startedAt = [DateTime]::UtcNow
    $childPid = 0
    $observedExit = $false
    $exitCode = -1
    $timedOut = $false
    $terminatedByParent = $false
    $stdout = ""
    $stderr = ""
    $captureComplete = $false
    $ownedIds = [Collections.Generic.HashSet[int]]::new()
    $launchCollision = @(
        @($ChildAttestationPath, $ParentAttestationPath, $StdoutPath, $StderrPath) |
            Where-Object { [IO.File]::Exists($_) }
    )

    if ($launchCollision.Count -eq 0) {
        $process = [Diagnostics.Process]::new()
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $ExecutablePath
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in $ArgumentList) {
            $startInfo.ArgumentList.Add([string]$argument)
        }
        foreach ($entry in $EnvironmentVariables.GetEnumerator()) {
            $startInfo.Environment[[string]$entry.Key] = [string]$entry.Value
        }
        $process.StartInfo = $startInfo
        try {
            if (-not $process.Start()) {
                throw "child_process_start_failed"
            }
            $childPid = $process.Id
            $null = $ownedIds.Add($childPid)
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
            while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
                Add-ColdRestoreOwnedProcesses $ownedIds (Get-ColdRestoreProcessSnapshot) $RunId
                Start-Sleep -Milliseconds 100
            }
            if (-not $process.HasExited) {
                $timedOut = $true
                $terminatedByParent = $true
                $process.Kill($true)
            }
            if ($process.WaitForExit(5000)) {
                $observedExit = $true
                $exitCode = $process.ExitCode
            }
            Add-ColdRestoreOwnedProcesses $ownedIds (Get-ColdRestoreProcessSnapshot) $RunId
            $stdoutReady = $stdoutTask.Wait(2000)
            $stderrReady = $stderrTask.Wait(2000)
            if ($stdoutReady) { $stdout = $stdoutTask.GetAwaiter().GetResult() }
            if ($stderrReady) { $stderr = $stderrTask.GetAwaiter().GetResult() }
            $captureComplete = $stdoutReady -and $stderrReady
        }
        catch {
            $stderr = "$stderr`n$($_.Exception.Message)".Trim()
            if ($childPid -gt 0 -and -not $process.HasExited) {
                $terminatedByParent = $true
                $process.Kill($true)
                $null = $process.WaitForExit(5000)
                $observedExit = $process.HasExited
                if ($observedExit) { $exitCode = $process.ExitCode }
            }
        }
        finally {
            $process.Dispose()
        }
    }

    [IO.File]::WriteAllText($StdoutPath, $stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($StderrPath, $stderr, [Text.UTF8Encoding]::new($false))

    $postExitSnapshot = Get-ColdRestoreProcessSnapshot
    Add-ColdRestoreOwnedProcesses $ownedIds $postExitSnapshot $RunId
    $aliveOwned = @($postExitSnapshot | Where-Object {
        $ownedIds.Contains([int]$_.ProcessId) -and [int]$_.ProcessId -ne $childPid
    })
    if ($aliveOwned.Count -gt 0) {
        $terminatedByParent = $true
        foreach ($record in $aliveOwned) {
            Stop-Process -Id ([int]$record.ProcessId) -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 250
    }
    $finalSnapshot = Get-ColdRestoreProcessSnapshot
    Add-ColdRestoreOwnedProcesses $ownedIds $finalSnapshot $RunId
    $remainingOwned = @($finalSnapshot | Where-Object {
        $ownedIds.Contains([int]$_.ProcessId) -and [int]$_.ProcessId -ne $childPid
    })

    $childValidation = if ($launchCollision.Count -gt 0) {
        [pscustomobject]@{ valid = $false; found = $true; reason_code = "evidence_collision"; fingerprint = ""; value = $null }
    }
    else {
        Test-ColdRestoreChildCompletionAttestation `
            -Path $ChildAttestationPath `
            -ExpectedRunId $RunId `
            -ExpectedRole $Role `
            -ExpectedRepositoryHead $RepositoryHead `
            -ProcessStartedAtUtc $startedAt
    }

    $wrapperReason = if ($launchCollision.Count -gt 0) {
        "evidence_collision"
    } elseif ($timedOut) {
        "child_process_timeout"
    } elseif (-not $observedExit) {
        "child_exit_not_observed"
    } elseif ($exitCode -ne 0) {
        "child_process_exit_nonzero"
    } elseif (-not $captureComplete) {
        "child_stream_capture_incomplete"
    } elseif (-not [bool]$childValidation.valid) {
        [string]$childValidation.reason_code
    } elseif ($terminatedByParent) {
        "child_process_tree_cleanup_required"
    } elseif ($remainingOwned.Count -gt 0) {
        "child_process_tree_not_clean"
    } else {
        "ok"
    }
    $wrapperGreen = $wrapperReason -eq "ok"
    $parent = [ordered]@{
        schema_version = 1
        run_id = $RunId
        role = $Role
        child_pid = $childPid
        observed_exit = $observedExit
        exit_code = $exitCode
        timed_out = $timedOut
        terminated_by_parent = $terminatedByParent
        stdout_sha256 = (Get-ColdRestoreTextSha256 $stdout)
        stderr_sha256 = (Get-ColdRestoreTextSha256 $stderr)
        child_attestation_found = [bool]$childValidation.found
        child_attestation_fingerprint = [string]$childValidation.fingerprint
        child_attestation_valid = [bool]$childValidation.valid
        task_owned_process_count_after = $remainingOwned.Count
        unrelated_preexisting_process_count = $preexistingGodotCount
        wrapper_exit_green = $wrapperGreen
        wrapper_reason_code = $wrapperReason
    }
    if (-not (Test-ColdRestoreExactFieldSet ([pscustomobject]$parent) $script:ParentExitFields)) {
        throw "parent_attestation_field_set_invalid"
    }
    Write-ColdRestoreAtomicJson $ParentAttestationPath ([pscustomobject]$parent) | Out-Null
    return [pscustomobject]@{
        wrapper_exit_green = $wrapperGreen
        wrapper_reason_code = $wrapperReason
        child = $childValidation.value
        child_validation = $childValidation
        parent = [pscustomobject]$parent
        observed_task_process_ids = @($ownedIds | Sort-Object)
        stdout = $stdout
        stderr = $stderr
    }
}

Export-ModuleMember -Function @(
    "ConvertTo-ColdRestoreCanonicalJson",
    "Get-ColdRestoreTextSha256",
    "Get-ColdRestoreEvidenceFingerprint",
    "Test-ColdRestoreExactFieldSet",
    "Write-ColdRestoreAtomicJson",
    "New-ColdRestoreChildCompletionFixture",
    "Test-ColdRestoreChildCompletionAttestation",
    "New-ColdRestoreGodotArgumentList",
    "Invoke-ColdRestoreAttestedProcess"
)
