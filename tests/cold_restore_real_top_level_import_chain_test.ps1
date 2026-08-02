[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$pwshPath = (Get-Command pwsh -CommandType Application -ErrorAction Stop).Source
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "alpha04c real import chain 中文根 " + [Guid]::NewGuid().ToString("N")
)
$childScriptPath = Join-Path $tempRoot "fresh import child.ps1"
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()

function Assert-ImportChainCondition {
    param([bool]$Condition, [string]$Message)

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Get-ResultPropertyValue {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()]$Default = $null
    )

    if ($null -eq $Value -or $Value.PSObject.Properties.Name -cnotcontains $Name) {
        return $Default
    }
    return $Value.$Name
}

$childSource = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$ScratchRoot,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][int]$RunIndex
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$result = [ordered]@{
    schema_version = 1
    run_index = $RunIndex
    process_id = $PID
    status = "FAIL"
    failure_code = "fresh_process_unhandled_failure"
    failure_message = ""
    failure_line = 0
    failure_stack = ""
    strict_mode_latest = $true
    project_root = ""
    scratch_root = ""
    scratch_root_has_spaces = $false
    scratch_root_has_non_ascii = $false
    production_module_paths_green = $false
    production_authorization_binding_green = $false
    current_authorization_green = $false
    module_info_reference_preserved = $false
    module_file_identity_preserved = $false
    authorization_entry_name = ""
    authorization_id = ""
    authorization_contract_sha256 = ""
    authorization_binding_semantic_fingerprint = ""
    evidence_command_present_before_admission = $false
    evidence_command_present_after_admission = $false
    evidence_command_module_reference_preserved = $false
    evidence_command_identity_before_sha256 = ""
    evidence_command_identity_after_sha256 = ""
    evidence_fingerprint_before = ""
    evidence_fingerprint_after = ""
    evidence_fingerprint_result_parity = $false
    shared_command_set_before_sha256 = ""
    shared_command_set_after_sha256 = ""
    shared_command_set_preserved = $false
    final_command_set_sha256 = ""
    module_file_set_sha256 = ""
    prequota_context_green = $false
    command_argument_construction_green = $false
    command_argument_sha256 = ""
    quota_ledger_exists = $false
    official_claim_created = $false
    save_write_count = 0
    godot_launched = $false
}

function Get-ProbeSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function ConvertTo-ProbeStableJson {
    param([Parameter(Mandatory = $true)]$Value)

    return $Value | ConvertTo-Json -Depth 20 -Compress
}

function Get-EvidenceCommandProbe {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedModulePath,
        [Parameter(Mandatory = $true)][string]$Phase
    )

    $resolvedExpectedPath = [IO.Path]::GetFullPath($ExpectedModulePath)
    $commands = @(
        Get-Command -Name "Get-ColdRestoreEvidenceFingerprint" `
            -CommandType Function -All -ErrorAction SilentlyContinue |
            Where-Object {
                $null -ne $_.Module -and
                [IO.Path]::GetFullPath([string]$_.Module.Path) -ceq $resolvedExpectedPath
            }
    )
    if ($commands.Count -ne 1) {
        throw "evidence_fingerprint_command_count_invalid_$($Phase):$($commands.Count)"
    }
    $command = $commands[0]
    $modulePath = [IO.Path]::GetFullPath([string]$command.Module.Path)
    $identity = [pscustomobject][ordered]@{
        name = [string]$command.Name
        command_type = [string]$command.CommandType
        source = [string]$command.Source
        module_name = [string]$command.ModuleName
        module_path = $modulePath
        module_guid = [string]$command.Module.Guid
        module_version = [string]$command.Module.Version
        module_file_sha256 = (Get-FileHash -LiteralPath $modulePath -Algorithm SHA256).Hash.ToLowerInvariant()
        definition_sha256 = Get-ProbeSha256 ([string]$command.Definition)
    }
    return [pscustomobject]@{
        command = $command
        identity = $identity
        identity_sha256 = Get-ProbeSha256 (ConvertTo-ProbeStableJson $identity)
    }
}

function Get-VisibleProductionCommandRows {
    param([Parameter(Mandatory = $true)][string[]]$ModulePaths)

    $resolvedPaths = @(
        $ModulePaths |
            ForEach-Object { [IO.Path]::GetFullPath($_) } |
            Sort-Object -Unique
    )
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($modulePath in $resolvedPaths) {
        $moduleNames = @(
            Get-Module -All |
                Where-Object {
                    -not [string]::IsNullOrEmpty([string]$_.Path) -and
                    [IO.Path]::GetFullPath([string]$_.Path) -ceq $modulePath
                } |
                ForEach-Object { @($_.ExportedCommands.Keys) } |
                Sort-Object -Unique
        )
        foreach ($commandName in $moduleNames) {
            $visibleCommands = @(
                Get-Command -Name $commandName -All -ErrorAction SilentlyContinue |
                    Where-Object {
                        $null -ne $_.Module -and
                        [IO.Path]::GetFullPath([string]$_.Module.Path) -ceq $modulePath
                    }
            )
            foreach ($command in $visibleCommands) {
                $rows.Add([pscustomobject][ordered]@{
                    module_path = $modulePath
                    command_name = [string]$command.Name
                    command_type = [string]$command.CommandType
                    definition_sha256 = Get-ProbeSha256 ([string]$command.Definition)
                })
            }
        }
    }
    return @(
        $rows |
            Sort-Object module_path, command_name, command_type, definition_sha256 -Unique
    )
}

function Get-ModuleFileRows {
    param([Parameter(Mandatory = $true)][string[]]$ModulePaths)

    return @(
        foreach ($modulePath in @($ModulePaths | Sort-Object -Unique)) {
            $resolved = [IO.Path]::GetFullPath($modulePath)
            [pscustomobject][ordered]@{
                module_path = $resolved
                sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
    )
}

try {
    $resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $resolvedScratchRoot = [IO.Path]::GetFullPath($ScratchRoot)
    [IO.Directory]::CreateDirectory($resolvedScratchRoot) | Out-Null
    $result.project_root = $resolvedProjectRoot
    $result.scratch_root = $resolvedScratchRoot
    $result.scratch_root_has_spaces = $resolvedScratchRoot -cmatch '\s'
    $result.scratch_root_has_non_ascii = $resolvedScratchRoot -cmatch '[^\u0000-\u007f]'
    if (-not $result.scratch_root_has_spaces -or -not $result.scratch_root_has_non_ascii) {
        throw "scratch_root_encoding_contract_invalid"
    }
    if ($RepositoryHead -cnotmatch '^[0-9a-f]{40}$') {
        throw "repository_head_invalid"
    }

    $toolsRoot = Join-Path $resolvedProjectRoot "scripts/tools"
    $modulePaths = [ordered]@{
        module_loader = Join-Path $toolsRoot "cold_restore_module_loader.psm1"
        authorization = Join-Path $toolsRoot "cold_restore_authorization_contract_v1.psm1"
        attested_process = Join-Path $toolsRoot "cold_restore_attested_process.psm1"
        prequota_bootstrap = Join-Path $toolsRoot "cold_restore_prequota_bootstrap.psm1"
        official_attempt2 = Join-Path $toolsRoot "cold_restore_official_attempt2_contract.psm1"
        rehearsal_admission = Join-Path $toolsRoot "process_a_rehearsal_admission_contract.psm1"
    }
    foreach ($modulePath in $modulePaths.Values) {
        if (-not [IO.File]::Exists($modulePath)) {
            throw "production_module_missing:$modulePath"
        }
    }
    $result.production_module_paths_green = $true

    # Match the production top-level order through the single-load module API.
    # Fresh child processes provide isolation, so no import needs -Force.
    $loaderImports = @(
        Import-Module -Name $modulePaths.module_loader -Global -PassThru -ErrorAction Stop
    )
    if ($loaderImports.Count -ne 1) {
        throw "module_loader_import_identity_invalid:$($loaderImports.Count)"
    }
    $loaderModule = $loaderImports[0]
    $authorizationModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
        -Path $modulePaths.authorization `
        -RequiredCommands @(
            "Get-ColdRestoreAuthorizationContract",
            "Get-ColdRestoreAuthorizationContractPath",
            "Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName",
            "Get-ColdRestoreTargetedDiagnosticAuthorizationBinding"
        )
    $contractPath = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationContractPath
    $contract = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationContract
    $result.authorization_contract_sha256 = (
        Get-FileHash -LiteralPath $contractPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()

    $prequotaModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
        -Path $modulePaths.prequota_bootstrap `
        -RequiredCommands @(
            "New-ColdRestoreTargetedDiagnosticPreQuotaContext",
            "New-ColdRestoreTargetedDiagnosticUserArgumentList"
        )
    $attestedProcessModule = cold_restore_module_loader\Get-ColdRestoreLoadedModuleByPath `
        $modulePaths.attested_process
    $attestedProcessModule = cold_restore_module_loader\Assert-ColdRestoreModuleExports `
        -ModuleInfo $attestedProcessModule `
        -RequiredCommands @(
            "Get-ColdRestoreEvidenceFingerprint",
            "Test-ColdRestoreRoleTimeoutPolicy"
        )

    $loadedSharedModules = [ordered]@{
        authorization = $authorizationModule
        prequota_bootstrap = $prequotaModule
        attested_process = $attestedProcessModule
    }
    $sharedRequiredCommands = [ordered]@{
        authorization = @(
            "Get-ColdRestoreAuthorizationContract",
            "Get-ColdRestoreAuthorizationContractPath",
            "Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName",
            "Get-ColdRestoreTargetedDiagnosticAuthorizationBinding"
        )
        attested_process = @(
            "Get-ColdRestoreEvidenceFingerprint",
            "Test-ColdRestoreRoleTimeoutPolicy"
        )
        prequota_bootstrap = @(
            "New-ColdRestoreTargetedDiagnosticPreQuotaContext",
            "New-ColdRestoreTargetedDiagnosticUserArgumentList"
        )
    }

    $currentAuthorizationName = `
        cold_restore_authorization_contract_v1\Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName
    $binding = cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationBinding `
        -GitCommonDirectory $resolvedScratchRoot `
        -RepositoryHead $RepositoryHead `
        -AuthorizationName $currentAuthorizationName
    $entryMatches = @(
        foreach ($property in $contract.PSObject.Properties) {
            if ($null -ne $property.Value -and
                @($property.Value.PSObject.Properties | ForEach-Object {
                    [string]$_.Name
                }) -ccontains "authorization_id" -and
                [string]$property.Value.authorization_id -ceq [string]$binding.authorization_id) {
                [pscustomobject]@{ name = [string]$property.Name; value = $property.Value }
            }
        }
    )
    if ($entryMatches.Count -ne 1) {
        throw "production_targeted_authorization_binding_ambiguous:$($entryMatches.Count)"
    }
    $targetedEntry = $entryMatches[0].value
    $result.authorization_entry_name = [string]$entryMatches[0].name
    $result.authorization_id = [string]$binding.authorization_id
    $bindingProjection = [pscustomobject][ordered]@{
        authorization_id = [string]$binding.authorization_id
        task_id = [string]$binding.task_id
        run_id_prefix = [string]$targetedEntry.run_id_prefix
        quota_ledger_relative_path = [string]$targetedEntry.quota_ledger_relative_path
        evidence_root_relative_path = [string]$targetedEntry.evidence_root_relative_path
        bootstrap_root_relative_path = [string]$targetedEntry.bootstrap_root_relative_path
        transition_from = [int]$binding.transition_from
        transition_to = [int]$binding.transition_to
        authorized_increment = [int]$binding.authorized_increment
        maximum_invocation_count = [int]$binding.maximum_invocation_count
    }
    $result.authorization_binding_semantic_fingerprint = Get-ProbeSha256 (
        ConvertTo-ProbeStableJson $bindingProjection
    )
    $result.current_authorization_green = (
        [string]$entryMatches[0].name -ceq $currentAuthorizationName -and
        [int]$targetedEntry.permitted_transition_from -eq 6 -and
        [int]$targetedEntry.permitted_transition_to -eq 7 -and
        [int]$targetedEntry.authorized_increment -eq 1 -and
        [int]$targetedEntry.maximum_invocation_count -eq 7
    )
    $result.production_authorization_binding_green = (
        $result.current_authorization_green -and
        [string]$binding.authorization_name -ceq $currentAuthorizationName -and
        [string]$binding.authorization_id -ceq [string]$targetedEntry.authorization_id -and
        [string]$binding.run_id -ceq "$([string]$targetedEntry.run_id_prefix)-$($RepositoryHead.Substring(0, 12))" -and
        [int]$binding.transition_from -eq [int]$targetedEntry.permitted_transition_from -and
        [int]$binding.transition_to -eq [int]$targetedEntry.permitted_transition_to -and
        [int]$binding.authorized_increment -eq [int]$targetedEntry.authorized_increment -and
        [int]$binding.maximum_invocation_count -eq [int]$targetedEntry.maximum_invocation_count -and
        [IO.Path]::GetFullPath([string]$binding.quota_ledger_path) -ceq
            [IO.Path]::GetFullPath((Join-Path $resolvedScratchRoot ([string]$targetedEntry.quota_ledger_relative_path))) -and
        [IO.Path]::GetFullPath([string]$binding.evidence_root) -ceq
            [IO.Path]::GetFullPath((Join-Path $resolvedScratchRoot ([string]$targetedEntry.evidence_root_relative_path))) -and
        [IO.Path]::GetFullPath([string]$binding.bootstrap_root) -ceq
            [IO.Path]::GetFullPath((Join-Path $resolvedScratchRoot ([string]$targetedEntry.bootstrap_root_relative_path)))
    )
    if (-not $result.production_authorization_binding_green) {
        throw "production_targeted_authorization_binding_invalid"
    }

    $sharedModulePaths = @(
        $modulePaths.module_loader,
        $modulePaths.authorization,
        $modulePaths.attested_process,
        $modulePaths.prequota_bootstrap
    )
    $beforeCommandSet = @(Get-VisibleProductionCommandRows $sharedModulePaths)
    $result.shared_command_set_before_sha256 = Get-ProbeSha256 (
        ConvertTo-ProbeStableJson $beforeCommandSet
    )
    $beforeProbe = Get-EvidenceCommandProbe $modulePaths.attested_process "before_admission"
    $result.evidence_command_present_before_admission = $true
    $result.evidence_command_identity_before_sha256 = [string]$beforeProbe.identity_sha256

    $evidenceProbeValue = [pscustomobject][ordered]@{
        schema_version = 1
        authorization_id = [string]$binding.authorization_id
        run_id = [string]$binding.run_id
        repository_head = $RepositoryHead
        quota_ledger_relative_path = [string]$targetedEntry.quota_ledger_relative_path
        probe_id = "real_top_level_import_chain"
        evidence_fingerprint = ""
    }
    $result.evidence_fingerprint_before = & $beforeProbe.command `
        $evidenceProbeValue "evidence_fingerprint"

    $moduleFilesBeforeAdmission = Get-ProbeSha256 (
        ConvertTo-ProbeStableJson (Get-ModuleFileRows $sharedModulePaths)
    )
    $admissionModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
        -Path $modulePaths.rehearsal_admission `
        -RequiredCommands @("Get-ProcessARehearsalAdmissionContractInfo")
    $attestedAfterAdmission = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
        -Path $modulePaths.attested_process `
        -RequiredCommands @(
            "Get-ColdRestoreEvidenceFingerprint",
            "Test-ColdRestoreRoleTimeoutPolicy"
        )
    if (-not [Object]::ReferenceEquals($attestedProcessModule, $attestedAfterAdmission)) {
        throw "attested_process_explicit_reuse_identity_invalid"
    }
    $officialModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
        -Path $modulePaths.official_attempt2 `
        -RequiredCommands @("Get-ColdRestoreOfficialAttempt2ContractInfo")

    $sharedReferencesPreserved = $true
    foreach ($moduleKey in $loadedSharedModules.Keys) {
        $reloadedModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
            -Path $modulePaths[$moduleKey] `
            -RequiredCommands $sharedRequiredCommands[$moduleKey]
        if (-not [Object]::ReferenceEquals(
                $loadedSharedModules.$moduleKey,
                $reloadedModule
            )) {
            $sharedReferencesPreserved = $false
        }
    }
    $loaderAfterAdmission = Get-Module -All |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.Path) -and
            [IO.Path]::GetFullPath([string]$_.Path) -ceq
                [IO.Path]::GetFullPath($modulePaths.module_loader)
        }
    $result.module_info_reference_preserved = (
        $sharedReferencesPreserved -and
        @($loaderAfterAdmission).Count -eq 1 -and
        [Object]::ReferenceEquals($loaderModule, @($loaderAfterAdmission)[0])
    )
    $moduleFilesAfterAdmission = Get-ProbeSha256 (
        ConvertTo-ProbeStableJson (Get-ModuleFileRows $sharedModulePaths)
    )
    $result.module_file_identity_preserved = (
        $moduleFilesBeforeAdmission -ceq $moduleFilesAfterAdmission
    )

    $afterProbe = Get-EvidenceCommandProbe $modulePaths.attested_process "after_admission"
    $result.evidence_command_present_after_admission = $true
    $result.evidence_command_identity_after_sha256 = [string]$afterProbe.identity_sha256
    $result.evidence_command_module_reference_preserved = [Object]::ReferenceEquals(
        $beforeProbe.command.Module, $afterProbe.command.Module
    )
    $result.evidence_fingerprint_after = & $afterProbe.command `
        $evidenceProbeValue "evidence_fingerprint"
    $result.evidence_fingerprint_result_parity = (
        [string]$result.evidence_fingerprint_before -ceq [string]$result.evidence_fingerprint_after
    )

    $afterCommandSet = @(Get-VisibleProductionCommandRows $sharedModulePaths)
    $result.shared_command_set_after_sha256 = Get-ProbeSha256 (
        ConvertTo-ProbeStableJson $afterCommandSet
    )
    $result.shared_command_set_preserved = (
        [string]$result.shared_command_set_before_sha256 -ceq
            [string]$result.shared_command_set_after_sha256
    )
    if (-not $result.module_info_reference_preserved -or
        -not $result.module_file_identity_preserved -or
        -not $result.evidence_command_module_reference_preserved -or
        [string]$result.evidence_command_identity_before_sha256 -cne
            [string]$result.evidence_command_identity_after_sha256 -or
        -not $result.evidence_fingerprint_result_parity -or
        -not $result.shared_command_set_preserved) {
        throw "admission_import_changed_shared_command_identity"
    }

    $prequotaContext = New-ColdRestoreTargetedDiagnosticPreQuotaContext `
        -GitCommonDirectory $resolvedScratchRoot `
        -RepositoryHead $RepositoryHead `
        -Branch "codex/顶层 导入链 run-$RunIndex" `
        -AuthorizationName $currentAuthorizationName
    $result.prequota_context_green = (
        [IO.File]::Exists([string]$prequotaContext.admission_path) -and
        [IO.File]::Exists([string]$prequotaContext.attestation_path) -and
        [string]$prequotaContext.authorization_binding.authorization_id -ceq
            [string]$binding.authorization_id
    )
    if (-not $result.prequota_context_green) {
        throw "production_prequota_context_invalid"
    }

    $launchPath = Join-Path ([string]$binding.evidence_root) (
        "launch/orchestrator-$PID/producer.authorized.json"
    )
    [IO.Directory]::CreateDirectory((Split-Path -Parent ([string]$binding.quota_ledger_path))) |
        Out-Null
    $launchContextLedgerFixture = [pscustomobject][ordered]@{
        authorization_id = [string]$binding.authorization_id
        run_id = [string]$binding.run_id
        repository_head = $RepositoryHead
        scenario_fingerprint = "1" * 64
        claim_nonce = "5" * 32
        launch_nonce = "4" * 32
        orchestrator_process_id = 4242
        orchestrator_creation_time_utc_ticks = "638000000000000000"
        role_timeout_policy_sha256 = "2" * 64
        official_attempt_1_claim_sha256 = "6" * 64
    }
    [IO.File]::WriteAllText(
        [string]$binding.quota_ledger_path,
        ($launchContextLedgerFixture | ConvertTo-Json -Compress -Depth 8),
        [Text.UTF8Encoding]::new($false)
    )
    $launchContextLedgerFixtureSha256 = (
        Get-FileHash -LiteralPath ([string]$binding.quota_ledger_path) -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $arguments = @(
        New-ColdRestoreTargetedDiagnosticUserArgumentList `
            -GitCommonDirectory $resolvedScratchRoot `
            -RepositoryHead $RepositoryHead `
            -RunId ([string]$binding.run_id) `
            -ArtifactRoot "user://test_runs/alpha04c/$([string]$binding.run_id)/evidence" `
            -ScenarioFingerprint ("1" * 64) `
            -TimeoutPolicyFingerprint ("2" * 64) `
            -QuotaLedgerPath ([string]$binding.quota_ledger_path) `
            -QuotaLedgerFingerprint $launchContextLedgerFixtureSha256 `
            -LaunchAttestationPath $launchPath `
            -LaunchNonce ("4" * 32) `
            -AuthorizationName $currentAuthorizationName
    )
    $result.command_argument_construction_green = (
        @($arguments | Where-Object {
            $_ -ceq "--cold-restore-run-id=$([string]$binding.run_id)"
        }).Count -eq 1 -and
        @($arguments | Where-Object {
            $_ -ceq "--cold-restore-targeted-diagnostic-ledger-path=$([string]$binding.quota_ledger_path)"
        }).Count -eq 1 -and
        @($arguments | Where-Object {
            $_ -ceq "--cold-restore-launch-attestation-path=$launchPath"
        }).Count -eq 1
    )
    if (-not $result.command_argument_construction_green) {
        throw "production_command_argument_construction_invalid"
    }
    [IO.File]::Delete([string]$binding.quota_ledger_path)
    $result.command_argument_sha256 = Get-ProbeSha256 (
        ConvertTo-ProbeStableJson @($arguments | ForEach-Object {
            ([string]$_ -replace [regex]::Escape($resolvedScratchRoot), "<SCRATCH_ROOT>") `
                -replace 'orchestrator-\d+', 'orchestrator-<PID>'
        })
    )

    $result.quota_ledger_exists = [IO.File]::Exists([string]$binding.quota_ledger_path)
    $scratchFiles = @(
        Get-ChildItem -LiteralPath $resolvedScratchRoot -Recurse -File -ErrorAction SilentlyContinue
    )
    $result.official_claim_created = @(
        $scratchFiles | Where-Object { $_.Name -cmatch 'official.*claim|attempt[_-]?2.*claim' }
    ).Count -gt 0
    $result.save_write_count = @(
        $scratchFiles | Where-Object { $_.Extension -in @(".save", ".sav") }
    ).Count
    if ($result.quota_ledger_exists -or $result.official_claim_created -or
        [int]$result.save_write_count -ne 0) {
        throw "prequota_only_side_effect_boundary_violated"
    }

    $allModulePaths = @($modulePaths.Values)
    $finalCommandSet = @(Get-VisibleProductionCommandRows $allModulePaths)
    $result.final_command_set_sha256 = Get-ProbeSha256 (
        ConvertTo-ProbeStableJson $finalCommandSet
    )
    $result.module_file_set_sha256 = Get-ProbeSha256 (
        ConvertTo-ProbeStableJson (Get-ModuleFileRows $allModulePaths)
    )
    $result.status = "PASS"
    $result.failure_code = "ok"
}
catch {
    $result.failure_code = ([string]$_.Exception.Message -split ':', 2)[0]
    $result.failure_message = [string]$_.Exception.Message
    $result.failure_line = [int]$_.InvocationInfo.ScriptLineNumber
    $result.failure_stack = [string]$_.ScriptStackTrace
}

[Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 20 -Compress))
if ([string]$result.status -cne "PASS") { exit 1 }
exit 0
'@

$results = [Collections.Generic.List[object]]::new()
$freshProcessRuns = 0

try {
    [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    [IO.File]::WriteAllText(
        $childScriptPath,
        $childSource,
        [Text.UTF8Encoding]::new($false)
    )
    $repositoryHead = (& git -C $projectRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $repositoryHead -cnotmatch '^[0-9a-f]{40}$') {
        throw "repository_head_resolution_failed"
    }

    foreach ($runIndex in 1..3) {
        $scratchRoot = Join-Path $tempRoot "运行 $runIndex 空格 中文"
        [IO.Directory]::CreateDirectory($scratchRoot) | Out-Null
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $pwshPath
        $startInfo.WorkingDirectory = $projectRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.ArgumentList.Add("-NoProfile")
        $startInfo.ArgumentList.Add("-NonInteractive")
        $startInfo.ArgumentList.Add("-File")
        $startInfo.ArgumentList.Add($childScriptPath)
        $startInfo.ArgumentList.Add("-ProjectRoot")
        $startInfo.ArgumentList.Add($projectRoot)
        $startInfo.ArgumentList.Add("-ScratchRoot")
        $startInfo.ArgumentList.Add($scratchRoot)
        $startInfo.ArgumentList.Add("-RepositoryHead")
        $startInfo.ArgumentList.Add($repositoryHead)
        $startInfo.ArgumentList.Add("-RunIndex")
        $startInfo.ArgumentList.Add([string]$runIndex)

        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            throw "fresh_pwsh_process_start_failed:$runIndex"
        }
        $freshProcessRuns += 1
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill($true)
            $process.WaitForExit()
            $results.Add([pscustomobject]@{
                run_index = $runIndex
                process_id = $process.Id
                parent_exit_code = -1
                status = "FAIL"
                failure_code = "fresh_pwsh_process_timeout"
                failure_message = "fresh process exceeded 30 seconds"
                stderr = $stderrTask.GetAwaiter().GetResult()
            })
            continue
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $jsonLines = @(
            $stdout -split "`r?`n" |
                Where-Object { $_.TrimStart().StartsWith("{", [StringComparison]::Ordinal) }
        )
        if ($jsonLines.Count -ne 1) {
            $results.Add([pscustomobject]@{
                run_index = $runIndex
                process_id = $process.Id
                parent_exit_code = $process.ExitCode
                status = "FAIL"
                failure_code = "fresh_pwsh_result_contract_invalid"
                failure_message = "expected one JSON result, observed $($jsonLines.Count)"
                stderr = $stderr
            })
            continue
        }
        try {
            $childResult = $jsonLines[0] | ConvertFrom-Json -DateKind String
            $childResult | Add-Member -NotePropertyName parent_exit_code `
                -NotePropertyValue $process.ExitCode
            $childResult | Add-Member -NotePropertyName stderr `
                -NotePropertyValue $stderr
            $results.Add($childResult)
        }
        catch {
            $results.Add([pscustomobject]@{
                run_index = $runIndex
                process_id = $process.Id
                parent_exit_code = $process.ExitCode
                status = "FAIL"
                failure_code = "fresh_pwsh_result_json_invalid"
                failure_message = [string]$_.Exception.Message
                stderr = $stderr
            })
        }
    }

    Assert-ImportChainCondition ($freshProcessRuns -eq 3) "exactly three fresh pwsh processes were started"
    Assert-ImportChainCondition ($results.Count -eq 3) "exactly three child results were collected"
    Assert-ImportChainCondition (
        @($results | ForEach-Object { [int](Get-ResultPropertyValue $_ "process_id" -1) } |
            Sort-Object -Unique).Count -eq 3
    ) "each import-chain run used a distinct process"

    foreach ($result in $results) {
        $runIndex = [int](Get-ResultPropertyValue $result "run_index" 0)
        Assert-ImportChainCondition (
            [int](Get-ResultPropertyValue $result "parent_exit_code" -1) -eq 0
        ) "fresh process $runIndex exited zero"
        Assert-ImportChainCondition (
            [string](Get-ResultPropertyValue $result "status" "FAIL") -ceq "PASS"
        ) "fresh process $runIndex passed: $(Get-ResultPropertyValue $result 'failure_message' 'missing result')"
        Assert-ImportChainCondition (
            [bool](Get-ResultPropertyValue $result "strict_mode_latest" $false) -and
            [bool](Get-ResultPropertyValue $result "scratch_root_has_spaces" $false) -and
            [bool](Get-ResultPropertyValue $result "scratch_root_has_non_ascii" $false)
        ) "fresh process $runIndex used StrictMode and a Chinese-space root"
        Assert-ImportChainCondition (
            [bool](Get-ResultPropertyValue $result "production_module_paths_green" $false) -and
            [bool](Get-ResultPropertyValue $result "production_authorization_binding_green" $false) -and
            [bool](Get-ResultPropertyValue $result "current_authorization_green" $false)
        ) "fresh process $runIndex used real modules and the current 6-to-7 production authorization"
        Assert-ImportChainCondition (
            [bool](Get-ResultPropertyValue $result "module_info_reference_preserved" $false) -and
            [bool](Get-ResultPropertyValue $result "module_file_identity_preserved" $false)
        ) "fresh process $runIndex preserved ModuleInfo references and module file identities"
        Assert-ImportChainCondition (
            [bool](Get-ResultPropertyValue $result "evidence_command_present_before_admission" $false) -and
            [bool](Get-ResultPropertyValue $result "evidence_command_present_after_admission" $false) -and
            [bool](Get-ResultPropertyValue $result "evidence_command_module_reference_preserved" $false)
        ) "fresh process $runIndex preserved EvidenceFingerprint command identity"
        Assert-ImportChainCondition (
            [string](Get-ResultPropertyValue $result "evidence_command_identity_before_sha256" "") -cmatch '^[0-9a-f]{64}$' -and
            [string](Get-ResultPropertyValue $result "evidence_command_identity_before_sha256" "") -ceq
                [string](Get-ResultPropertyValue $result "evidence_command_identity_after_sha256" "") -and
            [bool](Get-ResultPropertyValue $result "evidence_fingerprint_result_parity" $false)
        ) "fresh process $runIndex preserved EvidenceFingerprint identity and result"
        Assert-ImportChainCondition (
            [bool](Get-ResultPropertyValue $result "shared_command_set_preserved" $false)
        ) "fresh process $runIndex preserved the shared production command set"
        Assert-ImportChainCondition (
            [bool](Get-ResultPropertyValue $result "prequota_context_green" $false) -and
            [bool](Get-ResultPropertyValue $result "command_argument_construction_green" $false)
        ) "fresh process $runIndex built real PreQuota context and command arguments"
        Assert-ImportChainCondition (
            -not [bool](Get-ResultPropertyValue $result "quota_ledger_exists" $true) -and
            -not [bool](Get-ResultPropertyValue $result "official_claim_created" $true) -and
            [int](Get-ResultPropertyValue $result "save_write_count" -1) -eq 0 -and
            -not [bool](Get-ResultPropertyValue $result "godot_launched" $true)
        ) "fresh process $runIndex stopped before quota, Save, official claim, and Godot"
    }

    $stableFields = @(
        "authorization_contract_sha256",
        "authorization_binding_semantic_fingerprint",
        "evidence_command_identity_after_sha256",
        "evidence_fingerprint_after",
        "shared_command_set_after_sha256",
        "final_command_set_sha256",
        "module_file_set_sha256",
        "command_argument_sha256"
    )
    foreach ($field in $stableFields) {
        $values = @(
            $results |
                ForEach-Object { [string](Get-ResultPropertyValue $_ $field "") } |
                Sort-Object -Unique
        )
        Assert-ImportChainCondition (
            $values.Count -eq 1 -and $values[0] -cmatch '^[0-9a-f]{64}$'
        ) "fresh-process $field is stable"
    }
}
catch {
    $script:failures.Add("unexpected parent exception: $($_.Exception.Message)")
}
finally {
    $resolvedRoot = [IO.Path]::GetFullPath($tempRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedRoot).StartsWith(
            "alpha04c real import chain 中文根 ",
            [StringComparison]::Ordinal
        )) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$passedRuns = @(
    $results | Where-Object {
        [int](Get-ResultPropertyValue $_ "parent_exit_code" -1) -eq 0 -and
        [string](Get-ResultPropertyValue $_ "status" "FAIL") -ceq "PASS"
    }
).Count
$hashStable = $script:failures.Count -eq 0
$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_REAL_TOP_LEVEL_IMPORT_CHAIN|status=$status|checks=$script:checks|failures=$($script:failures.Count)|fresh_process_runs=$freshProcessRuns|passed_runs=$passedRuns/3|hash_stable=$($hashStable.ToString().ToLowerInvariant())|quota_claimed=false|godot_launched=false"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
foreach ($result in $results) {
    if ([string](Get-ResultPropertyValue $result "status" "FAIL") -cne "PASS") {
        Write-Output "CHILD_FAIL|run=$(Get-ResultPropertyValue $result 'run_index' 0)|code=$(Get-ResultPropertyValue $result 'failure_code' 'unknown')|line=$(Get-ResultPropertyValue $result 'failure_line' 0)|message=$(Get-ResultPropertyValue $result 'failure_message' 'missing')|stack=$(Get-ResultPropertyValue $result 'failure_stack' 'missing')"
    }
}
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
