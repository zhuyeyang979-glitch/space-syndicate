[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$admissionModulePath = Join-Path $projectRoot "scripts/tools/process_a_rehearsal_admission_contract.psm1"
$expectedOutcomeRelativePath = "codex\cold_restore_v3\non-official-alpha04c-process-a-rehearsal-v1\process_a_rehearsal_outcome_ledger.json"
$expectedOutcomeId = "ProcessARehearsalOutcomeLedgerV1"
$shaA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
$shaB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

$outcomeFields = @(
    "schema_version", "outcome_id", "created_at_utc", "authorization_id",
    "run_id", "repository_head", "scenario_fingerprint",
    "official", "formal", "official_attempt_2_claim_present",
    "official_attempt_2_authorization_consumed", "rehearsal_admission_consumed",
    "admission_ledger_sha256",
    "rehearsal_green_head", "rehearsal_green_tree_clean",
    "rehearsal_green_git_diff_check_green", "rehearsal_green_freeze_fingerprint",
    "launch_attestation_present", "launch_attestation_sha256",
    "child_attestation_present", "child_attestation_sha256",
    "parent_attestation_present", "parent_attestation_sha256",
    "stdout_present", "stdout_sha256",
    "stderr_present", "stderr_sha256",
    "manifest_present", "manifest_sha256",
    "phase_timeline_present", "phase_timeline_sha256",
    "completion_present", "completion_sha256",
    "wrapper_result_present", "observed_exit", "exit_code_observed", "exit_code",
    "timed_out", "terminated_by_parent", "task_owned_process_count_after",
    "terminal_stage", "success", "terminal_code", "evidence_fingerprint"
)
$optionalEvidence = [ordered]@{
    launch_attestation = "launch_attestation_sha256"
    child_attestation = "child_attestation_sha256"
    parent_attestation = "parent_attestation_sha256"
    stdout = "stdout_sha256"
    stderr = "stderr_sha256"
    manifest = "manifest_sha256"
    phase_timeline = "phase_timeline_sha256"
    completion = "completion_sha256"
}
$forbiddenRawPayloadTokens = @(
    "owner_state", "owner_payload", "section_payload", "section_payloads",
    "save_envelope", "private_hand", "ai_memory", "commodity_inventory",
    "hidden_owner", "future_sequence"
)

$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "alpha04c-process-a-outcome-$([Guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($testRoot) | Out-Null

function Assert-ContractCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Assert-ContractThrows {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$ReasonCode,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $actual = ""
    try {
        & $Action
    }
    catch {
        $actual = [string]$_.Exception.Message
    }
    Assert-ContractCondition ($actual -ceq $ReasonCode) "$Message (actual=$actual)"
}

function Get-FunctionAst {
    param(
        [Parameter(Mandatory = $true)]$Ast,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $matches = @($Ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | Where-Object { [string]$_.Name -ceq $Name })
    if ($matches.Count -ne 1) {
        return $null
    }
    return $matches[0]
}

function Get-CommandAsts {
    param([Parameter(Mandatory = $true)]$Ast)

    return @($Ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst]
    }, $true))
}

function Test-ContainsAll {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Source,
        [Parameter(Mandatory = $true)][string[]]$Markers
    )

    foreach ($marker in $Markers) {
        if ($Source.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            return $false
        }
    }
    return $true
}

function Test-ExactFieldSet {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedFields
    )

    $actual = @($Value.PSObject.Properties.Name | Sort-Object)
    $expected = @($ExpectedFields | Sort-Object)
    return $actual.Count -eq $expected.Count -and (($actual -join "`n") -ceq ($expected -join "`n"))
}

function ConvertTo-SyntheticCanonicalJson {
    param([Parameter(Mandatory = $true)]$Value)

    return ($Value | ConvertTo-Json -Depth 20 -Compress)
}

function Get-StringSha256 {
    param([Parameter(Mandatory = $true)][string]$Value)

    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Value)
        return [Convert]::ToHexString($algorithm.ComputeHash($bytes)).ToLowerInvariant()
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-SyntheticOutcomeFingerprint {
    param([Parameter(Mandatory = $true)]$Value)

    $copy = [ordered]@{}
    foreach ($property in $Value.PSObject.Properties) {
        $copy[[string]$property.Name] = if ([string]$property.Name -ceq "evidence_fingerprint") {
            ""
        }
        else {
            $property.Value
        }
    }
    return Get-StringSha256 (ConvertTo-SyntheticCanonicalJson ([pscustomobject]$copy))
}

function New-SyntheticOutcome {
    param(
        [Parameter(Mandatory = $true)][string]$TerminalStage,
        [Parameter(Mandatory = $true)][string]$TerminalCode,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$PresentEvidence,
        [bool]$WrapperResultPresent = $false,
        [bool]$ObservedExit = $false,
        [bool]$ExitCodeObserved = $false,
        [int]$ExitCode = -1,
        [bool]$TimedOut = $false,
        [bool]$TerminatedByParent = $false,
        [int]$TaskOwnedProcessCountAfter = -1,
        [bool]$Success = $false
    )

    $presence = @{}
    foreach ($name in $optionalEvidence.Keys) {
        $presence[$name] = $PresentEvidence -ccontains $name
    }
    $value = [pscustomobject][ordered]@{
        schema_version = 1
        outcome_id = $expectedOutcomeId
        created_at_utc = "2026-07-31T00:00:00.0000000Z"
        authorization_id = "alpha04c-process-a-save-completion-rehearsal-v1"
        run_id = "alpha04c-process-a-rehearsal-0123456789ab"
        repository_head = "0123456789abcdef0123456789abcdef01234567"
        scenario_fingerprint = $shaA
        official = $false
        formal = $false
        official_attempt_2_claim_present = $false
        official_attempt_2_authorization_consumed = $false
        rehearsal_admission_consumed = $true
        admission_ledger_sha256 = $shaA
        rehearsal_green_head = $(if ($Success) { "0123456789abcdef0123456789abcdef01234567" } else { "" })
        rehearsal_green_tree_clean = $Success
        rehearsal_green_git_diff_check_green = $Success
        rehearsal_green_freeze_fingerprint = $(if ($Success) { $shaB } else { "" })
        launch_attestation_present = [bool]$presence.launch_attestation
        launch_attestation_sha256 = $(if ($presence.launch_attestation) { $shaB } else { "" })
        child_attestation_present = [bool]$presence.child_attestation
        child_attestation_sha256 = $(if ($presence.child_attestation) { $shaA } else { "" })
        parent_attestation_present = [bool]$presence.parent_attestation
        parent_attestation_sha256 = $(if ($presence.parent_attestation) { $shaB } else { "" })
        stdout_present = [bool]$presence.stdout
        stdout_sha256 = $(if ($presence.stdout) { $shaA } else { "" })
        stderr_present = [bool]$presence.stderr
        stderr_sha256 = $(if ($presence.stderr) { $shaB } else { "" })
        manifest_present = [bool]$presence.manifest
        manifest_sha256 = $(if ($presence.manifest) { $shaA } else { "" })
        phase_timeline_present = [bool]$presence.phase_timeline
        phase_timeline_sha256 = $(if ($presence.phase_timeline) { $shaB } else { "" })
        completion_present = [bool]$presence.completion
        completion_sha256 = $(if ($presence.completion) { $shaA } else { "" })
        wrapper_result_present = $WrapperResultPresent
        observed_exit = $ObservedExit
        exit_code_observed = $ExitCodeObserved
        exit_code = $ExitCode
        timed_out = $TimedOut
        terminated_by_parent = $TerminatedByParent
        task_owned_process_count_after = $TaskOwnedProcessCountAfter
        terminal_stage = $TerminalStage
        success = $Success
        terminal_code = $TerminalCode
        evidence_fingerprint = ""
    }
    $value.evidence_fingerprint = Get-SyntheticOutcomeFingerprint $value
    return $value
}

function Assert-SyntheticOutcome {
    param([Parameter(Mandatory = $true)]$Value)

    $probe = ConvertTo-SyntheticCanonicalJson $Value
    foreach ($token in $forbiddenRawPayloadTokens) {
        if ($probe.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "process_a_rehearsal_outcome_raw_payload_forbidden"
        }
    }
    if (-not (Test-ExactFieldSet $Value $outcomeFields)) {
        throw "process_a_rehearsal_outcome_field_set_invalid"
    }
    if ($Value.schema_version -isnot [int] -or [int]$Value.schema_version -ne 1 -or
        [string]$Value.outcome_id -cne $expectedOutcomeId) {
        throw "process_a_rehearsal_outcome_schema_invalid"
    }
    if ($Value.official -isnot [bool] -or [bool]$Value.official -or
        $Value.formal -isnot [bool] -or [bool]$Value.formal -or
        $Value.official_attempt_2_claim_present -isnot [bool] -or [bool]$Value.official_attempt_2_claim_present -or
        $Value.official_attempt_2_authorization_consumed -isnot [bool] -or [bool]$Value.official_attempt_2_authorization_consumed -or
        $Value.rehearsal_admission_consumed -isnot [bool] -or -not [bool]$Value.rehearsal_admission_consumed) {
        throw "process_a_rehearsal_outcome_official_boundary_invalid"
    }
    if ([string]$Value.admission_ledger_sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw "process_a_rehearsal_outcome_admission_sha256_invalid"
    }
    foreach ($name in $optionalEvidence.Keys) {
        $presentField = "${name}_present"
        $shaField = [string]$optionalEvidence[$name]
        if ($Value.$presentField -isnot [bool]) {
            throw "process_a_rehearsal_outcome_evidence_presence_invalid"
        }
        $expectedShaPattern = if ([bool]$Value.$presentField) { '^[0-9a-f]{64}$' } else { '^$' }
        if ([string]$Value.$shaField -cnotmatch $expectedShaPattern) {
            throw "process_a_rehearsal_outcome_evidence_sha256_invalid"
        }
    }
    foreach ($field in @("rehearsal_green_tree_clean", "rehearsal_green_git_diff_check_green", "wrapper_result_present", "observed_exit", "exit_code_observed", "timed_out", "terminated_by_parent", "success")) {
        if ($Value.$field -isnot [bool]) {
            throw "process_a_rehearsal_outcome_boolean_invalid"
        }
    }
    if ($Value.exit_code -isnot [int] -or $Value.task_owned_process_count_after -isnot [int]) {
        throw "process_a_rehearsal_outcome_integer_invalid"
    }
    if ([string]$Value.terminal_stage -cnotmatch '^[a-z0-9_]{1,64}$' -or
        [string]$Value.terminal_code -cnotmatch '^[a-z0-9_]{1,128}$') {
        throw "process_a_rehearsal_outcome_terminal_code_invalid"
    }
    if ([bool]$Value.success) {
        if ([string]$Value.terminal_stage -cne "success" -or [string]$Value.terminal_code -cne "ok" -or
            [string]$Value.rehearsal_green_head -cne [string]$Value.repository_head -or
            -not [bool]$Value.rehearsal_green_tree_clean -or
            -not [bool]$Value.rehearsal_green_git_diff_check_green -or
            [string]$Value.rehearsal_green_freeze_fingerprint -cnotmatch '^[0-9a-f]{64}$' -or
            -not [bool]$Value.wrapper_result_present -or -not [bool]$Value.observed_exit -or
            -not [bool]$Value.exit_code_observed -or [int]$Value.exit_code -ne 0 -or
            [bool]$Value.timed_out -or [bool]$Value.terminated_by_parent -or
            [int]$Value.task_owned_process_count_after -ne 0) {
            throw "process_a_rehearsal_outcome_success_binding_invalid"
        }
        foreach ($name in $optionalEvidence.Keys) {
            if (-not [bool]$Value."${name}_present") {
                throw "process_a_rehearsal_outcome_success_evidence_incomplete"
            }
        }
    }
    elseif ([string]$Value.terminal_code -ceq "ok" -or
        [string]$Value.rehearsal_green_head -cne "" -or
        [bool]$Value.rehearsal_green_tree_clean -or
        [bool]$Value.rehearsal_green_git_diff_check_green -or
        [string]$Value.rehearsal_green_freeze_fingerprint -cne "") {
        throw "process_a_rehearsal_outcome_failure_binding_invalid"
    }
    if ([string]$Value.evidence_fingerprint -cne (Get-SyntheticOutcomeFingerprint $Value)) {
        throw "process_a_rehearsal_outcome_fingerprint_invalid"
    }
}

function Write-SyntheticOutcomeExclusive {
    param(
        [Parameter(Mandatory = $true)][string]$LedgerPath,
        [Parameter(Mandatory = $true)]$Value
    )

    Assert-SyntheticOutcome $Value
    $json = ConvertTo-SyntheticCanonicalJson $Value
    $directory = Split-Path -Parent $LedgerPath
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    if ([IO.File]::Exists($LedgerPath)) {
        $existing = [IO.File]::ReadAllText($LedgerPath, [Text.UTF8Encoding]::new($false))
        if ($existing -ceq $json) {
            throw "process_a_rehearsal_outcome_already_written"
        }
        throw "process_a_rehearsal_outcome_collision"
    }

    $temporaryPath = "$LedgerPath.tmp.$PID.$([Guid]::NewGuid().ToString('N'))"
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
        $stream = [IO.File]::Open($temporaryPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush($true)
        }
        finally {
            $stream.Dispose()
        }
        try {
            [IO.File]::Move($temporaryPath, $LedgerPath)
        }
        catch [IO.IOException] {
            if ([IO.File]::Exists($LedgerPath)) {
                $existing = [IO.File]::ReadAllText($LedgerPath, [Text.UTF8Encoding]::new($false))
                if ($existing -ceq $json) {
                    throw "process_a_rehearsal_outcome_already_written"
                }
                throw "process_a_rehearsal_outcome_collision"
            }
            throw "process_a_rehearsal_outcome_atomic_write_failed"
        }
    }
    finally {
        if ([IO.File]::Exists($temporaryPath)) {
            [IO.File]::Delete($temporaryPath)
        }
    }

    $readback = [IO.File]::ReadAllText($LedgerPath, [Text.UTF8Encoding]::new($false))
    if ($readback -cne $json) {
        throw "process_a_rehearsal_outcome_readback_mismatch"
    }
    return Get-StringSha256 $readback
}

try {
    Import-Module $admissionModulePath -Force
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($orchestratorPath, [ref]$tokens, [ref]$parseErrors)
    Assert-ContractCondition ($parseErrors.Count -eq 0) "Orchestrator parses before outcome integration"
    $admissionTokens = $null
    $admissionParseErrors = $null
    $admissionAst = [Management.Automation.Language.Parser]::ParseFile($admissionModulePath, [ref]$admissionTokens, [ref]$admissionParseErrors)
    Assert-ContractCondition ($admissionParseErrors.Count -eq 0) "Admission module parses before commit-boundary inspection"
    $orchestratorSource = [IO.File]::ReadAllText($orchestratorPath)

    Assert-ContractCondition ($orchestratorSource.IndexOf('$ProcessARehearsalOutcomeLedgerRelativePath = "' + $expectedOutcomeRelativePath + '"', [StringComparison]::Ordinal) -ge 0) "Outcome ledger uses the fixed git-common relative path"

    $outcomeWriters = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            [string]$node.Name -ceq "Write-ColdRestoreProcessARehearsalOutcome"
    }, $true))
    Assert-ContractCondition ($outcomeWriters.Count -eq 1) "Exactly one ProcessARehearsalOutcomeLedgerV1 writer exists"
    $outcomeWriter = if ($outcomeWriters.Count -eq 1) { $outcomeWriters[0] } else { $null }
    $outcomeWriterSource = if ($null -ne $outcomeWriter) { [string]$outcomeWriter.Extent.Text } else { "" }

    Assert-ContractCondition (Test-ContainsAll $outcomeWriterSource @(
        "Resolve-ColdRestoreGitCommonDirectory",
        "ProcessARehearsalOutcomeLedgerRelativePath",
        "Write-ProcessARehearsalExclusiveAtomicJson",
        "process_a_rehearsal_outcome_already_written",
        "process_a_rehearsal_outcome_collision",
        "^[a-z0-9_]{1,128}$",
        "Get-ColdRestoreOfficialAttemptBoundaryObservation"
    )) "Outcome writer is fixed-path, exclusive, hashed, collision-aware, safe-coded, and official-boundary checked"
    $outcomePublishOffset = $outcomeWriterSource.IndexOf("Write-ProcessARehearsalExclusiveAtomicJson", [StringComparison]::Ordinal)
    $outcomePostPublishSource = if ($outcomePublishOffset -ge 0) { $outcomeWriterSource.Substring($outcomePublishOffset) } else { "" }
    Assert-ContractCondition ($outcomePublishOffset -ge 0 -and
        $outcomePostPublishSource.IndexOf('Get-FileHash -LiteralPath $outcomePath', [StringComparison]::Ordinal) -lt 0 -and
        $outcomePostPublishSource.IndexOf("outcome_readback_mismatch", [StringComparison]::Ordinal) -lt 0) "Outcome success performs no fallible final-path I/O after exclusive atomic publication"

    foreach ($field in $outcomeFields) {
        Assert-ContractCondition ($outcomeWriterSource.IndexOf($field, [StringComparison]::Ordinal) -ge 0) "Outcome writer binds field $field"
    }
    foreach ($token in $forbiddenRawPayloadTokens) {
        Assert-ContractCondition ($outcomeWriterSource.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) "Outcome writer excludes raw payload token $token"
    }

    $invokeRehearsal = Get-FunctionAst $ast "Invoke-ColdRestoreNonOfficialProcessA"
    Assert-ContractCondition ($null -ne $invokeRehearsal) "Non-official Process A function exists exactly once"
    $invokeSource = if ($null -ne $invokeRehearsal) { [string]$invokeRehearsal.Extent.Text } else { "" }
    $invokeCommands = if ($null -ne $invokeRehearsal) { Get-CommandAsts $invokeRehearsal.Body } else { @() }
    $consumeCommands = @($invokeCommands | Where-Object { [string]$_.GetCommandName() -ceq "Consume-ColdRestoreProcessARehearsalQuota" })
    Assert-ContractCondition ($consumeCommands.Count -eq 1) "Rehearsal consumes admission exactly once"

    $protectedTries = if ($null -ne $invokeRehearsal) {
        @($invokeRehearsal.Body.FindAll({
            param($node)
            $node -is [Management.Automation.Language.TryStatementAst] -and $null -ne $node.Finally
        }, $true))
    }
    else {
        @()
    }
    $terminalTry = $null
    foreach ($candidate in $protectedTries) {
        $candidateSource = [string]$candidate.Extent.Text
        if (Test-ContainsAll $candidateSource @(
            "Invoke-ColdRestoreAttestedProcess",
            "Read-ColdRestoreJsonArtifact",
            "Assert-ColdRestoreProcessARehearsalCompletion"
        )) {
            $terminalTry = $candidate
            break
        }
    }
    Assert-ContractCondition ($null -ne $terminalTry) "A try/finally protects wrapper launch through completion validation"
    $terminalTrySource = if ($null -ne $terminalTry) { [string]$terminalTry.Extent.Text } else { "" }
    $terminalFinallySource = if ($null -ne $terminalTry) { [string]$terminalTry.Finally.Extent.Text } else { "" }
    Assert-ContractCondition (Test-ContainsAll $terminalTrySource @(
        "Assert-ProcessARehearsalAdmissionSourcesUnchanged",
        "Invoke-ColdRestoreAttestedProcess",
        "wrapper_exit_green",
        '$paths.child_result',
        '$run.phase_timeline',
        '$paths.rehearsal_completion'
    )) "Protected region covers wrapper, manifest, timeline, and completion terminal paths"
    Assert-ContractCondition ($terminalFinallySource.IndexOf("Outcome", [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
        $terminalFinallySource.IndexOf("Write", [StringComparison]::OrdinalIgnoreCase) -ge 0) "Finally writes the terminal outcome on success and failure"

    if ($null -ne $terminalTry -and $consumeCommands.Count -eq 1) {
        $consumeOffset = $consumeCommands[0].Extent.StartOffset
        $tryStart = $terminalTry.Extent.StartOffset
        $tryEnd = $terminalTry.Extent.EndOffset
        $consumeProtected = $consumeOffset -ge $tryStart -and $consumeOffset -lt $tryEnd
        Assert-ContractCondition $consumeProtected "No fallible post-admission setup escapes terminal outcome protection"
    }
    else {
        Assert-ContractCondition $false "No fallible post-admission setup escapes terminal outcome protection"
    }

    Assert-ContractCondition (Test-ContainsAll $terminalFinallySource @(
        'if ($admissionConsumed)',
        "admission_ledger_sha256",
        "launch_attestation_sha256",
        "child_attestation_sha256",
        "parent_attestation_sha256",
        "stdout_sha256",
        "stderr_sha256",
        "manifest_sha256",
        "phase_timeline_sha256",
        "completion_sha256",
        "exit_code",
        "timed_out",
        "terminated_by_parent",
        "task_owned_process_count_after",
        "terminal_code"
    )) "Finally supplies every available artifact SHA and process terminal fact"

    $postCommitValidator = Get-FunctionAst $admissionAst "Assert-ProcessARehearsalAdmissionSourcesUnchanged"
    $postCommitValidatorSource = if ($null -ne $postCommitValidator) { [string]$postCommitValidator.Extent.Text } else { "" }
    Assert-ContractCondition ($null -ne $postCommitValidator -and (Test-ContainsAll $postCommitValidatorSource @(
        "Read-ProcessARehearsalAdmissionLedger",
        "admission_source_changed_after_commit",
        "official_claim_state_changed_after_admission",
        "diagnostic_launch_attestation_sha256",
        "diagnostic_manifest_sha256",
        "timeout_policy_fingerprint"
    ))) "Post-commit source validation is explicit and runs after the caller owns the admission"

    $newAdmissionFunction = Get-FunctionAst $admissionAst "New-ProcessARehearsalAdmission"
    $newAdmissionSource = if ($null -ne $newAdmissionFunction) { [string]$newAdmissionFunction.Extent.Text } else { "" }
    $publishOffset = $newAdmissionSource.IndexOf("Write-ProcessARehearsalExclusiveAtomicJson", [StringComparison]::Ordinal)
    $postPublishSource = if ($publishOffset -ge 0) { $newAdmissionSource.Substring($publishOffset) } else { "" }
    Assert-ContractCondition ($publishOffset -ge 0 -and
        $postPublishSource.IndexOf("Get-FileHash", [StringComparison]::Ordinal) -lt 0 -and
        $postPublishSource.IndexOf("Get-ProcessARehearsalOfficialClaimState", [StringComparison]::Ordinal) -lt 0) "Admission creation performs no fallible source or claim I/O after atomic publication"

    $atomicWriterFunction = Get-FunctionAst $admissionAst "Write-ProcessARehearsalExclusiveAtomicJson"
    $atomicWriterSource = if ($null -ne $atomicWriterFunction) { [string]$atomicWriterFunction.Extent.Text } else { "" }
    Assert-ContractCondition ($null -ne $atomicWriterFunction -and (Test-ContainsAll $atomicWriterSource @(
        '$sha256 = Get-ProcessARehearsalTextSha256 $json',
        '[IO.File]::Move($tempPath, $fullPath)',
        '$published = $true',
        'if (-not $published',
        'return $sha256'
    )) -and
        $atomicWriterSource.IndexOf("atomic_final_readback_failed", [StringComparison]::Ordinal) -lt 0 -and
        $atomicWriterSource.IndexOf('$finalReadback', [StringComparison]::Ordinal) -lt 0) "Exclusive-atomic writer treats Move as the commit point and performs no fallible final-file readback afterward"

    Assert-ContractCondition (Test-ContainsAll $invokeSource @(
        '$primaryFailure = $_',
        '$outcomeFailure = $_',
        'if ($null -ne $primaryFailure)',
        'throw $primaryFailure',
        'if ($null -ne $outcomeFailure)',
        'throw $outcomeFailure'
    )) "Primary rehearsal failure retains precedence over a secondary outcome-write failure"

    $atomicProductionPath = Join-Path $testRoot "production-atomic.json"
    $atomicProductionValue = [pscustomobject][ordered]@{ schema_version = 1; value = "complete" }
    $atomicProductionSha = Write-ProcessARehearsalExclusiveAtomicJson $atomicProductionPath $atomicProductionValue
    $atomicProductionRaw = [IO.File]::ReadAllText($atomicProductionPath, [Text.UTF8Encoding]::new($false))
    Assert-ContractCondition ($atomicProductionSha -cmatch '^[0-9a-f]{64}$' -and ($atomicProductionRaw | ConvertFrom-Json).value -ceq "complete") "Production exclusive-atomic writer publishes one complete parseable file"
    Assert-ContractThrows { $null = Write-ProcessARehearsalExclusiveAtomicJson $atomicProductionPath $atomicProductionValue } "process_a_rehearsal_atomic_target_exists" "Production exclusive-atomic writer rejects target reuse"
    Assert-ContractCondition (@(Get-ChildItem -LiteralPath $testRoot -File -Filter ".production-atomic.json.tmp.*").Count -eq 0) "Production exclusive-atomic writer leaves no temporary sidecar"

    Assert-ContractCondition (Test-ContainsAll $terminalFinallySource @(
        'official = $false',
        'official_attempt_2_claim_present = $false',
        'official_attempt_2_authorization_consumed = $false'
    )) "Finally records the non-official and Attempt 2 absent boundary"

    $allEvidence = @("launch_attestation", "child_attestation", "parent_attestation", "stdout", "stderr", "manifest", "phase_timeline", "completion")
    $cases = @(
        [pscustomobject]@{ name = "pre_wrapper_failure"; evidence = @(); wrapper = $false; observed = $false; exitObserved = $false; exit = -1; count = -1; success = $false },
        [pscustomobject]@{ name = "wrapper_failure"; evidence = @("launch_attestation", "parent_attestation", "stdout", "stderr"); wrapper = $true; observed = $true; exitObserved = $true; exit = 1; count = 0; success = $false },
        [pscustomobject]@{ name = "manifest_failure"; evidence = @("launch_attestation", "child_attestation", "parent_attestation", "stdout", "stderr", "manifest"); wrapper = $true; observed = $true; exitObserved = $true; exit = 0; count = 0; success = $false },
        [pscustomobject]@{ name = "timeline_failure"; evidence = @("launch_attestation", "child_attestation", "parent_attestation", "stdout", "stderr", "manifest", "phase_timeline"); wrapper = $true; observed = $true; exitObserved = $true; exit = 0; count = 0; success = $false },
        [pscustomobject]@{ name = "completion_failure"; evidence = $allEvidence; wrapper = $true; observed = $true; exitObserved = $true; exit = 0; count = 0; success = $false },
        [pscustomobject]@{ name = "success"; evidence = $allEvidence; wrapper = $true; observed = $true; exitObserved = $true; exit = 0; count = 0; success = $true }
    )
    foreach ($case in $cases) {
        $terminalCode = if ($case.success) { "ok" } else { "process_a_rehearsal_$($case.name)" }
        $value = New-SyntheticOutcome `
            -TerminalStage $case.name `
            -TerminalCode $terminalCode `
            -PresentEvidence $case.evidence `
            -WrapperResultPresent $case.wrapper `
            -ObservedExit $case.observed `
            -ExitCodeObserved $case.exitObserved `
            -ExitCode $case.exit `
            -TaskOwnedProcessCountAfter $case.count `
            -Success $case.success
        $path = Join-Path $testRoot "$($case.name).json"
        $writtenSha = Write-SyntheticOutcomeExclusive $path $value
        $readback = [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json -DateKind String
        Assert-ContractCondition ([IO.File]::Exists($path) -and $writtenSha -cmatch '^[0-9a-f]{64}$') "Synthetic $($case.name) outcome writes atomically"
        Assert-ContractCondition (Test-ExactFieldSet $readback $outcomeFields) "Synthetic $($case.name) outcome has the exact allowlisted shape"
        Assert-ContractCondition ([string]$readback.admission_ledger_sha256 -ceq $shaA -and
            -not [bool]$readback.official -and -not [bool]$readback.official_attempt_2_claim_present) "Synthetic $($case.name) outcome preserves admission and official boundaries"
    }

    $duplicatePath = Join-Path $testRoot "duplicate.json"
    $duplicate = New-SyntheticOutcome -TerminalStage "pre_wrapper_failure" -TerminalCode "process_a_rehearsal_pre_wrapper_failure" -PresentEvidence @()
    Write-SyntheticOutcomeExclusive $duplicatePath $duplicate | Out-Null
    Assert-ContractThrows { Write-SyntheticOutcomeExclusive $duplicatePath $duplicate | Out-Null } "process_a_rehearsal_outcome_already_written" "Identical terminal outcome cannot be replayed"
    $collision = New-SyntheticOutcome -TerminalStage "wrapper_failure" -TerminalCode "process_a_rehearsal_wrapper_failure" -PresentEvidence @("launch_attestation")
    Assert-ContractThrows { Write-SyntheticOutcomeExclusive $duplicatePath $collision | Out-Null } "process_a_rehearsal_outcome_collision" "Different terminal outcome cannot collide with the consumed path"

    $rawPayload = New-SyntheticOutcome -TerminalStage "pre_wrapper_failure" -TerminalCode "process_a_rehearsal_pre_wrapper_failure" -PresentEvidence @()
    $rawPayload | Add-Member -NotePropertyName owner_state -NotePropertyValue ([pscustomobject]@{ private_hand = @("secret") })
    Assert-ContractThrows { Write-SyntheticOutcomeExclusive (Join-Path $testRoot "raw.json") $rawPayload | Out-Null } "process_a_rehearsal_outcome_raw_payload_forbidden" "Raw Owner payload is rejected before serialization"
    Assert-ContractCondition (@(Get-ChildItem -LiteralPath $testRoot -File -Filter "*.tmp.*").Count -eq 0) "Synthetic atomic writer leaves no temporary files"
}
finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTestRoot.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTestRoot).StartsWith("alpha04c-process-a-outcome-", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "PROCESS_A_REHEARSAL_TERMINAL_OUTCOME_CONTRACT_TEST|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) {
    exit 1
}
exit 0
