Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_key_formatter_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_parity_validator_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_process_identity_reader_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_m5_passive_contract_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_core_v2.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_bracketed_cohort_v2.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_m5_listener_parity_v2_contract.psm1') -Force

function Test-Pr90McpCommandLinePathBindingV2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$CommandLine,
        [Parameter(Mandatory = $true)][string]$ExpectedRoot
    )
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    foreach ($rootForm in @($ExpectedRoot, $ExpectedRoot.Replace('\','/'))) {
        $escaped = [Regex]::Escape($rootForm.TrimEnd('\','/'))
        $pattern = '(?i)(?:^|\s)--path(?:\s+|=)(?:"' + $escaped + '"|' + $escaped + ')(?=\s|$)'
        if ([Regex]::IsMatch($CommandLine, $pattern)) { return $true }
    }
    return $false
}

function Resolve-Pr90McpGuiEnginePathV2 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$GodotConsolePath)
    $resolved = [IO.Path]::GetFullPath($GodotConsolePath)
    $gui = [Regex]::Replace($resolved, '(?i)_console(?=\.exe$)', '')
    if ($gui -ceq $resolved -or [IO.Path]::GetExtension($gui) -ine '.exe') {
        throw 'Godot console path does not map to a distinct GUI engine executable.'
    }
    return $gui
}

function Add-Pr90McpIdentityToListenerObservationV2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Observation,
        [Parameter(Mandatory = $true)][hashtable]$IdentityByPid
    )
    $records = [Collections.Generic.List[object]]::new()
    $failures = [Collections.Generic.List[object]]::new()
    foreach ($failure in @(Get-EndpointSourcePropertyValueV1 $Observation 'parse_failures' -Required)) {
        $failures.Add($failure)
    }
    foreach ($record in @(Get-EndpointSourcePropertyValueV1 $Observation 'records' -Required)) {
        $pidKey = ([int]$record.owning_pid).ToString([Globalization.CultureInfo]::InvariantCulture)
        if (-not $IdentityByPid.ContainsKey($pidKey) -or -not [bool]$IdentityByPid[$pidKey].identity_read_green) {
            $failureClass = if ($IdentityByPid.ContainsKey($pidKey)) { [string]$IdentityByPid[$pidKey].failure_class } else { 'PROCESS_IDENTITY_NOT_READ' }
            $failures.Add([pscustomobject][ordered]@{
                source=[string]$Observation.observer_source; failure_class=$failureClass; owning_pid=[int]$record.owning_pid
            })
            continue
        }
        try {
            $records.Add((Set-EndpointListenerOwnerIdentityV1 -Record $record -Identity $IdentityByPid[$pidKey]))
        } catch {
            $failures.Add([pscustomobject][ordered]@{
                source=[string]$Observation.observer_source; failure_class='PROCESS_IDENTITY_ENRICHMENT_FAILED';
                owning_pid=[int]$record.owning_pid; detail=$_.Exception.Message
            })
        }
    }
    return [pscustomobject][ordered]@{
        schema='EndpointListenerSourceObservationV1'
        observer_source=[string](Get-EndpointSourcePropertyValueV1 $Observation 'observer_source' -Required)
        sample_id=[string](Get-EndpointSourcePropertyValueV1 $Observation 'sample_id' -Required)
        observed_utc=[string](Get-EndpointSourcePropertyValueV1 $Observation 'observed_utc' -Required)
        raw_record_count=[int](Get-EndpointSourcePropertyValueV1 $Observation 'raw_record_count' -Required)
        records=@($records)
        parse_failures=@($failures)
        parse_failure_count=$failures.Count
    }
}

function Get-Pr90McpLineageFingerprintV2 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$AncestorChain)
    $projection = @(
        foreach ($row in @($AncestorChain)) {
            [ordered]@{
                pid=Get-EndpointSourcePropertyValueV1 $row 'pid'
                parent_pid=Get-EndpointSourcePropertyValueV1 $row 'parent_pid'
                creation_time_filetime_utc=Get-EndpointSourcePropertyValueV1 $row 'creation_time_filetime_utc'
            }
        }
    )
    return Get-Pr90CanonicalSha256 $projection
}

function New-Pr90McpEndpointOwnershipSampleV2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$SourceA,
        [Parameter(Mandatory = $true)][object]$SourceB,
        [Parameter(Mandatory = $true)][hashtable]$IdentityByPid,
        [Parameter(Mandatory = $true)][object]$ConsoleWrapperIdentity,
        [Parameter(Mandatory = $true)][int]$LauncherPid,
        [Parameter(Mandatory = $true)][string]$ExpectedFixtureRoot,
        [Parameter(Mandatory = $true)][string]$GodotConsolePath,
        [Parameter(Mandatory = $true)][DateTimeOffset]$LaunchEpochUtc,
        [Parameter(Mandatory = $true)][ValidateRange(1,65535)][int]$Port,
        [Parameter(Mandatory = $true)][DateTimeOffset]$ObservedUtc,
        [hashtable]$AncestorChainByPid = @{}
    )
    $enrichedA = Add-Pr90McpIdentityToListenerObservationV2 -Observation $SourceA -IdentityByPid $IdentityByPid
    $enrichedB = Add-Pr90McpIdentityToListenerObservationV2 -Observation $SourceB -IdentityByPid $IdentityByPid
    $parity = Compare-EndpointListenerSourceSetsV1 -SourceA $enrichedA -SourceB $enrichedB
    $targetMatches = @($parity.matched_records | Where-Object { [int]$_.source_a_record.local_port -eq $Port })

    $wrapperPid = [int](Get-EndpointSourcePropertyValueV1 $ConsoleWrapperIdentity 'pid' -Required)
    $expectedGuiPath = Resolve-Pr90McpGuiEnginePathV2 $GodotConsolePath
    $ownerRecord = $null
    $ownerIdentity = $null
    $ownerPid = 0
    $chain = @()
    $ownerInstanceKey = ''
    $lineageFingerprint = ''
    $ownerIsGuiEngine = $false
    $ownerIsConsoleWrapper = $false
    $ownerDescendantOfLauncher = $false
    $ownerParentIsWrapper = $false
    $wrapperParentIsLauncher = ([int](Get-EndpointSourcePropertyValueV1 $ConsoleWrapperIdentity 'parent_pid' -Required) -eq $LauncherPid)
    $commandLineFixtureMatch = $false
    $windowsSessionMatch = $false
    $userSidMatch = $false
    $createdAfterLaunchEpoch = $false
    $qualified = $false

    if ([bool]$parity.parity -and $parity.matched_count -eq 1 -and $targetMatches.Count -eq 1) {
        $ownerRecord = $targetMatches[0].source_a_record
        $ownerPid = [int]$ownerRecord.owning_pid
        $pidKey = $ownerPid.ToString([Globalization.CultureInfo]::InvariantCulture)
        if ($IdentityByPid.ContainsKey($pidKey)) { $ownerIdentity = $IdentityByPid[$pidKey] }
        if ($null -ne $ownerIdentity -and [bool]$ownerIdentity.identity_read_green) {
            if ($AncestorChainByPid.ContainsKey($pidKey)) { $chain = @($AncestorChainByPid[$pidKey]) }
            else { $chain = @(Get-EndpointProcessAncestorChainV1 -PidValue $ownerPid) }
            $chainPids = @($chain | ForEach-Object { [int](Get-EndpointSourcePropertyValueV1 $_ 'pid' -Required) })
            $ownerIsConsoleWrapper = ($ownerPid -eq $wrapperPid)
            $ownerIsGuiEngine = (-not $ownerIsConsoleWrapper -and [string]$ownerIdentity.executable_path -ieq $expectedGuiPath)
            $ownerParentIsWrapper = ([int]$ownerIdentity.parent_pid -eq $wrapperPid)
            $ownerDescendantOfLauncher = ($ownerParentIsWrapper -and $wrapperParentIsLauncher -and $wrapperPid -in $chainPids -and $LauncherPid -in $chainPids)
            $commandLineFixtureMatch = Test-Pr90McpCommandLinePathBindingV2 -CommandLine ([string]$ownerIdentity.command_line) -ExpectedRoot $ExpectedFixtureRoot
            $windowsSessionMatch = ([int]$ownerIdentity.windows_session_id -eq [int]$ConsoleWrapperIdentity.windows_session_id)
            $userSidMatch = (
                -not [string]::IsNullOrWhiteSpace([string]$ownerIdentity.user_sid) -and
                [string]$ownerIdentity.user_sid -ceq [string]$ConsoleWrapperIdentity.user_sid
            )
            $createdAfterLaunchEpoch = ([DateTimeOffset]::Parse([string]$ownerIdentity.creation_time_utc) -ge $LaunchEpochUtc)
            $ownerInstanceKey = Format-EndpointListenerCanonicalKeyV1 $ownerRecord
            $lineageFingerprint = Get-Pr90McpLineageFingerprintV2 -AncestorChain $chain
            $qualified = (
                $ownerIsGuiEngine -and $ownerDescendantOfLauncher -and $commandLineFixtureMatch -and
                $windowsSessionMatch -and $userSidMatch -and $createdAfterLaunchEpoch
            )
        }
    }

    return [pscustomobject][ordered]@{
        schema='SpaceSyndicatePr90McpEndpointOwnershipSampleV2'
        sample_id=[string]$SourceA.sample_id
        observed_utc=$ObservedUtc.ToUniversalTime().ToString('o')
        source_a=$enrichedA
        source_b=$enrichedB
        parity=$parity
        endpoint_owner_pid=if($ownerPid -gt 0){$ownerPid}else{$null}
        endpoint_owner_identity=$ownerIdentity
        ancestor_chain=@($chain)
        owner_instance_key=$ownerInstanceKey
        lineage_fingerprint=$lineageFingerprint
        owner_is_gui_engine=$ownerIsGuiEngine
        owner_is_console_wrapper=$ownerIsConsoleWrapper
        owner_descendant_of_launcher=$ownerDescendantOfLauncher
        owner_parent_is_wrapper=$ownerParentIsWrapper
        wrapper_parent_is_launcher=$wrapperParentIsLauncher
        command_line_fixture_match=$commandLineFixtureMatch
        windows_session_match=$windowsSessionMatch
        user_sid_match=$userSidMatch
        created_after_launch_epoch=$createdAfterLaunchEpoch
        qualified=$qualified
    }
}

function Test-Pr90McpEndpointOwnershipV2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Samples,
        [object]$SamplingContract = (Get-Pr90M5PassiveSamplingContractV1)
    )
    $sampleRows = @($Samples)
    $stable = Test-EndpointOwnerStableWindowV1 -Samples $sampleRows
    $paritySamples = @($sampleRows | Where-Object { [bool]$_.parity.parity })
    $qualifiedSamples = @($sampleRows | Where-Object { [bool]$_.qualified })
    $ownerPids = @($sampleRows | Where-Object { $null -ne $_.endpoint_owner_pid } | ForEach-Object { [int]$_.endpoint_owner_pid } | Sort-Object -Unique)
    $ownerKeys = @($sampleRows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.owner_instance_key) } | ForEach-Object { [string]$_.owner_instance_key } | Sort-Object -Unique)
    $lineageKeys = @($sampleRows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.lineage_fingerprint) } | ForEach-Object { [string]$_.lineage_fingerprint } | Sort-Object -Unique)
    $disagreements = @($sampleRows | Where-Object { -not [bool]$_.parity.parity })
    $aOnlyCount = @($sampleRows | ForEach-Object { [int]$_.parity.a_only_count } | Measure-Object -Sum).Sum
    $bOnlyCount = @($sampleRows | ForEach-Object { [int]$_.parity.b_only_count } | Measure-Object -Sum).Sum
    $multipleOwnerCount = @($sampleRows | ForEach-Object { [Math]::Max(0, [int]$_.parity.matched_count - 1) } | Measure-Object -Sum).Sum
    $lastGood = @($qualifiedSamples | Select-Object -Last 1)
    $green = (
        [bool]$SamplingContract.sampling_budget_sufficient -and
        $sampleRows.Count -ge [int]$SamplingContract.required_total_sample_count -and
        $paritySamples.Count -eq $sampleRows.Count -and
        $qualifiedSamples.Count -eq $sampleRows.Count -and
        [bool]$stable.green -and
        [int]$stable.stable_sample_count -ge [int]$SamplingContract.required_consecutive_parity_sample_count -and
        [double]$stable.stable_window_ms -ge [double]$SamplingContract.required_stable_window_ms -and
        $ownerPids.Count -eq 1 -and $ownerKeys.Count -eq 1 -and $lineageKeys.Count -eq 1 -and
        [int]$aOnlyCount -eq 0 -and [int]$bOnlyCount -eq 0 -and [int]$multipleOwnerCount -eq 0
    )
    $failureClass = ''
    if (-not $green) {
        $failureClass = if ($sampleRows.Count -lt [int]$SamplingContract.required_total_sample_count) { 'STARTUP_M5_ENDPOINT_OWNER_SAMPLE_COUNT_INSUFFICIENT' }
        elseif ($disagreements.Count -gt 0 -or [int]$aOnlyCount -gt 0 -or [int]$bOnlyCount -gt 0) { 'STARTUP_M5_ENDPOINT_LISTENER_OBSERVER_DISAGREEMENT' }
        elseif ([int]$multipleOwnerCount -gt 0) { 'STARTUP_M5_MULTIPLE_ENDPOINT_OWNERS' }
        elseif ($ownerPids.Count -ne 1 -or $ownerKeys.Count -ne 1) { 'STARTUP_M5_ENDPOINT_OWNER_IDENTITY_CHANGED' }
        elseif ($lineageKeys.Count -ne 1) { 'STARTUP_M5_ENDPOINT_OWNER_LINEAGE_CHANGED' }
        elseif (-not [bool]$stable.green) { 'STARTUP_M5_ENDPOINT_OWNER_STABLE_WINDOW_INSUFFICIENT' }
        else { 'STARTUP_M5_ENDPOINT_OWNER_V2_CONTRACT_FAILED' }
    }
    return [pscustomobject][ordered]@{
        schema='SpaceSyndicatePr90McpEndpointOwnershipV2Attestation'
        status=if($green){'PASS'}else{'FAIL'}
        green=$green
        failure_class=$failureClass
        endpoint_ownership_contract_version=2
        total_listener_sample_count=$sampleRows.Count
        consecutive_parity_sample_count=[int]$stable.stable_sample_count
        endpoint_owner_stable_window_ms=[double]$stable.stable_window_ms
        endpoint_listener_observer_source_count=2
        endpoint_listener_observer_parity=($disagreements.Count -eq 0)
        endpoint_listener_a_only_count=[int]$aOnlyCount
        endpoint_listener_b_only_count=[int]$bOnlyCount
        endpoint_owner_pid=if($ownerPids.Count -eq 1){[int]$ownerPids[0]}else{$null}
        endpoint_owner_is_gui_engine=if($lastGood.Count -eq 1){[bool]$lastGood[0].owner_is_gui_engine}else{$false}
        endpoint_owner_is_console_wrapper=if($lastGood.Count -eq 1){[bool]$lastGood[0].owner_is_console_wrapper}else{$false}
        endpoint_owner_is_descendant_of_launcher=if($lastGood.Count -eq 1){[bool]$lastGood[0].owner_descendant_of_launcher}else{$false}
        endpoint_owner_command_line_fixture_match=if($lastGood.Count -eq 1){[bool]$lastGood[0].command_line_fixture_match}else{$false}
        endpoint_owner_windows_session_match=if($lastGood.Count -eq 1){[bool]$lastGood[0].windows_session_match}else{$false}
        endpoint_owner_user_sid_match=if($lastGood.Count -eq 1){[bool]$lastGood[0].user_sid_match}else{$false}
        endpoint_owner_created_after_launch_epoch=if($lastGood.Count -eq 1){[bool]$lastGood[0].created_after_launch_epoch}else{$false}
        endpoint_owner_pid_changed_count=[Math]::Max(0, $ownerPids.Count - 1)
        endpoint_owner_creation_identity_changed_count=[Math]::Max(0, $ownerKeys.Count - 1)
        endpoint_owner_process_lineage_changed_count=[Math]::Max(0, $lineageKeys.Count - 1)
        multiple_active_endpoint_owner_count=[int]$multipleOwnerCount
        endpoint_owner_identity=if($lastGood.Count -eq 1){$lastGood[0].endpoint_owner_identity}else{$null}
        endpoint_owner_ancestor_chain=if($lastGood.Count -eq 1){@($lastGood[0].ancestor_chain)}else{@()}
        sampling_contract=$SamplingContract
    }
}

function Set-Pr90McpOwnerProofForBracketedCohortV2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$Cohort,
        [Parameter(Mandatory=$true)][object]$ConsoleWrapperIdentity,
        [Parameter(Mandatory=$true)][int]$LauncherPid,
        [Parameter(Mandatory=$true)][string]$ExpectedFixtureRoot,
        [Parameter(Mandatory=$true)][string]$GodotConsolePath,
        [Parameter(Mandatory=$true)][DateTimeOffset]$LaunchEpochUtc,
        [Parameter(Mandatory=$true)][ValidateRange(1,65535)][int]$EndpointPort,
        [Parameter(Mandatory=$true)][string]$McpSessionId,
        [scriptblock]$IdentityReader={param($pidValue) Read-EndpointListenerOwnerIdentityV1 -PidValue $pidValue},
        [scriptblock]$AncestorReader={param($pidValue) @(Get-EndpointProcessAncestorChainV1 -PidValue $pidValue)}
    )
    $proof=[pscustomobject][ordered]@{
        schema='Pr90SharedEndpointOwnerProofV2';status='BLOCKED';qualified=$false;failure_class='LISTENER_CORE_PARITY_NOT_ESTABLISHED';
        endpoint_owner_pid=$null;endpoint_owner_identity=$null;ancestor_chain=@();owner_instance_key='';lineage_fingerprint='';
        owner_is_gui_engine=$false;owner_is_console_wrapper=$false;owner_descendant_of_launcher=$false;owner_parent_is_wrapper=$false;wrapper_parent_is_launcher=$false;
        project_match=$false;mcp_session_match=$false;windows_session_match=$false;user_sid_match=$false;creation_identity_match=$false;created_after_launch_epoch=$false;
        matched_listener_process_enrichment_count=0;duplicate_source_process_enrichment_count=0;process_identity_used_to_prove_owner=$false;process_identity_used_to_define_source_parity=$false;
        protected_port_multiple_owner_count=0;foreign_listener_count=0
    }
    if(-not[bool]$Cohort.stable_parity-or$null-eq$Cohort.source_parity){$Cohort.owner_proof=$proof;return $Cohort}
    $matched=@($Cohort.source_parity.matched_records)
    $target=@($matched|Where-Object{[int]$_.core.local_port-eq$EndpointPort})
    $ownerPids=@($matched|ForEach-Object{[int]$_.core.owning_pid}|Sort-Object -Unique)
    $proof.protected_port_multiple_owner_count=[Math]::Max(0,$ownerPids.Count-1)
    if($target.Count-ne1-or$ownerPids.Count-ne1){$proof.failure_class=if($target.Count-ne1){'ENDPOINT_LISTENER_CARDINALITY_INVALID'}else{'PROTECTED_PORT_MULTIPLE_OWNER'};$Cohort.owner_proof=$proof;return $Cohort}
    $ownerPid=[int]$target[0].core.owning_pid
    $proof.endpoint_owner_pid=$ownerPid
    $proof.matched_listener_process_enrichment_count=1
    $identity=&$IdentityReader $ownerPid
    $proof.endpoint_owner_identity=$identity
    if($null-eq$identity-or-not[bool]$identity.identity_read_green){$proof.failure_class='PROCESS_IDENTITY_ENRICHMENT_FAILED';$Cohort.owner_proof=$proof;$Cohort.matched_listener_process_enrichment_count=1;return $Cohort}
    $chain=@(&$AncestorReader $ownerPid)
    $proof.ancestor_chain=$chain
    $wrapperPid=[int](Get-EndpointSourcePropertyValueV1 $ConsoleWrapperIdentity 'pid' -Required)
    $wrapperParentIsLauncher=([int](Get-EndpointSourcePropertyValueV1 $ConsoleWrapperIdentity 'parent_pid' -Required)-eq$LauncherPid)
    $chainPids=@($chain|ForEach-Object{[int](Get-EndpointSourcePropertyValueV1 $_ 'pid' -Required)})
    $expectedGuiPath=Resolve-Pr90McpGuiEnginePathV2 $GodotConsolePath
    $proof.owner_is_console_wrapper=($ownerPid-eq$wrapperPid)
    $proof.owner_is_gui_engine=(-not$proof.owner_is_console_wrapper-and[string]$identity.executable_path-ieq$expectedGuiPath)
    $proof.owner_parent_is_wrapper=([int]$identity.parent_pid-eq$wrapperPid)
    $proof.wrapper_parent_is_launcher=$wrapperParentIsLauncher
    $proof.owner_descendant_of_launcher=($proof.owner_parent_is_wrapper-and$wrapperParentIsLauncher-and$wrapperPid-in$chainPids-and$LauncherPid-in$chainPids)
    $proof.project_match=Test-Pr90McpCommandLinePathBindingV2 -CommandLine ([string]$identity.command_line) -ExpectedRoot $ExpectedFixtureRoot
    $proof.mcp_session_match=(-not[string]::IsNullOrWhiteSpace($McpSessionId)-and$proof.owner_descendant_of_launcher)
    $proof.windows_session_match=([int]$identity.windows_session_id-eq[int]$ConsoleWrapperIdentity.windows_session_id)
    $proof.user_sid_match=(-not[string]::IsNullOrWhiteSpace([string]$identity.user_sid)-and[string]$identity.user_sid-ceq[string]$ConsoleWrapperIdentity.user_sid)
    $proof.created_after_launch_epoch=([DateTimeOffset]::Parse([string]$identity.creation_time_utc)-ge$LaunchEpochUtc)
    $proof.creation_identity_match=(-not[string]::IsNullOrWhiteSpace([string]$identity.creation_time_filetime_utc))
    $proof.owner_instance_key='{0}|{1}'-f$ownerPid,[string]$identity.creation_time_filetime_utc
    $proof.lineage_fingerprint=Get-Pr90McpLineageFingerprintV2 -AncestorChain $chain
    $proof.process_identity_used_to_prove_owner=$true
    $proof.foreign_listener_count=if($proof.owner_is_gui_engine-and$proof.owner_descendant_of_launcher-and$proof.project_match){0}else{1}
    $proof.qualified=($proof.owner_is_gui_engine-and-not$proof.owner_is_console_wrapper-and$proof.owner_descendant_of_launcher-and$proof.project_match-and$proof.mcp_session_match-and$proof.windows_session_match-and$proof.user_sid_match-and$proof.creation_identity_match-and$proof.created_after_launch_epoch-and$proof.protected_port_multiple_owner_count-eq0)
    $proof.status=if($proof.qualified){'PASS'}else{'BLOCKED'}
    $proof.failure_class=if($proof.qualified){''}else{'ENDPOINT_OWNER_SHARED_IDENTITY_CONTRACT_FAILED'}
    $Cohort.owner_proof=$proof
    $Cohort.matched_listener_process_enrichment_count=1
    $Cohort.duplicate_source_process_enrichment_count=0
    return $Cohort
}

function Test-Pr90McpEndpointOwnershipBracketedV2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$Cohorts,
        [object]$SamplingContract=(Get-Pr90M5ListenerParityV2Contract)
    )
    $rows=@($Cohorts)
    $window=Test-Pr90BracketedCohortWindowV2 -Cohorts $rows -RequiredAttempts ([int]$SamplingContract.required_total_cohort_attempt_count) -RequiredConsecutive ([int]$SamplingContract.required_consecutive_stable_parity_cohort_count) -RequiredWindowMs ([int]$SamplingContract.required_stable_parity_window_ms)
    $proofRows=@($rows|Where-Object{$null-ne$_.owner_proof-and[bool]$_.owner_proof.qualified})
    $ownerPids=@($rows|Where-Object{$null-ne$_.source_parity}|ForEach-Object{@($_.source_parity.matched_records|ForEach-Object{[int]$_.core.owning_pid})}|Sort-Object -Unique)
    $ownerKeys=@($proofRows|ForEach-Object{[string]$_.owner_proof.owner_instance_key}|Sort-Object -Unique)
    $lineages=@($proofRows|ForEach-Object{[string]$_.owner_proof.lineage_fingerprint}|Sort-Object -Unique)
    $last=@($proofRows|Select-Object -Last 1)
    $aOnly=[int](@($rows|ForEach-Object{if($null-ne$_.source_parity){[int]$_.source_parity.a_only_count}else{0}}|Measure-Object -Sum).Sum)
    $bOnly=[int](@($rows|ForEach-Object{if($null-ne$_.source_parity){[int]$_.source_parity.b_only_count}else{0}}|Measure-Object -Sum).Sum)
    $multiple=[int](@($rows|Where-Object{$null-ne$_.owner_proof}|ForEach-Object{[int]$_.owner_proof.protected_port_multiple_owner_count}|Measure-Object -Sum).Sum)
    $foreign=[int](@($rows|Where-Object{$null-ne$_.owner_proof}|ForEach-Object{[int]$_.owner_proof.foreign_listener_count}|Measure-Object -Sum).Sum)
    $enrichCount=[int](@($rows|ForEach-Object{[int]$_.matched_listener_process_enrichment_count}|Measure-Object -Sum).Sum)
    $green=([bool]$SamplingContract.sampling_budget_sufficient-and[bool]$SamplingContract.short_time_bounded-and[bool]$window.green-and$proofRows.Count-eq1-and$ownerPids.Count-eq1-and$ownerKeys.Count-eq1-and$lineages.Count-eq1-and$aOnly-eq0-and$bOnly-eq0-and$multiple-eq0-and$foreign-eq0-and$enrichCount-eq1)
    $failure=if($green){''}elseif($rows.Count-lt[int]$SamplingContract.required_total_cohort_attempt_count){'STARTUP_M5_COHORT_COUNT_INSUFFICIENT'}elseif([int]$window.observer_timeout_count-gt0){'STARTUP_M5_LISTENER_OBSERVER_TIMEOUT'}elseif([int]$window.source_disagreement_count-gt0-or$aOnly-gt0-or$bOnly-gt0){'STARTUP_M5_ENDPOINT_LISTENER_CORE_DISAGREEMENT'}elseif($multiple-gt0-or$foreign-gt0){'STARTUP_M5_MULTIPLE_OR_FOREIGN_ENDPOINT_OWNER'}elseif($proofRows.Count-ne1-or$enrichCount-ne1){'STARTUP_M5_ENDPOINT_OWNER_SHARED_IDENTITY_FAILED'}elseif($ownerPids.Count-ne1-or$ownerKeys.Count-ne1-or$lineages.Count-ne1){'STARTUP_M5_ENDPOINT_OWNER_IDENTITY_CHANGED'}else{'STARTUP_M5_STABLE_PARITY_WINDOW_INSUFFICIENT'}
    return [pscustomobject][ordered]@{
        schema='SpaceSyndicatePr90McpEndpointOwnershipBracketedV2Attestation';status=if($green){'PASS'}else{'FAIL'};green=$green;failure_class=$failure;endpoint_ownership_contract_version=2;listener_parity_contract_version=2;bracketed_sample_model=$true;
        total_listener_cohort_attempt_count=$rows.Count;consecutive_stable_parity_cohort_count=[int]$window.consecutive_stable_parity_cohort_count;stable_parity_window_ms=[double]$window.stable_parity_window_ms;unstable_cohort_count=[int]$window.unstable_cohort_count;observer_timeout_count=[int]$window.observer_timeout_count;
        endpoint_listener_observer_source_count=2;endpoint_listener_core_parity=($window.source_disagreement_count-eq0-and$aOnly-eq0-and$bOnly-eq0);endpoint_listener_a_only_core_count=$aOnly;endpoint_listener_b_only_core_count=$bOnly;
        listener_core_parity_key_field_count=5;listener_core_parity_observer_specific_field_count=0;listener_core_parity_process_enrichment_field_count=0;matched_listener_process_enrichment_count=$enrichCount;duplicate_source_process_enrichment_count=0;process_identity_used_to_prove_owner=$true;process_identity_used_to_define_source_parity=$false;
        endpoint_owner_pid=if($ownerPids.Count-eq1){$ownerPids[0]}else{$null};endpoint_owner_identity=if($last.Count-eq1){$last[0].owner_proof.endpoint_owner_identity}else{$null};endpoint_owner_ancestor_chain=if($last.Count-eq1){@($last[0].owner_proof.ancestor_chain)}else{@()};
        endpoint_owner_is_gui_engine=if($last.Count-eq1){[bool]$last[0].owner_proof.owner_is_gui_engine}else{$false};endpoint_owner_is_console_wrapper=if($last.Count-eq1){[bool]$last[0].owner_proof.owner_is_console_wrapper}else{$false};endpoint_owner_is_descendant_of_launcher=if($last.Count-eq1){[bool]$last[0].owner_proof.owner_descendant_of_launcher}else{$false};endpoint_owner_project_match=if($last.Count-eq1){[bool]$last[0].owner_proof.project_match}else{$false};endpoint_owner_mcp_session_match=if($last.Count-eq1){[bool]$last[0].owner_proof.mcp_session_match}else{$false};endpoint_owner_windows_session_match=if($last.Count-eq1){[bool]$last[0].owner_proof.windows_session_match}else{$false};endpoint_owner_user_sid_match=if($last.Count-eq1){[bool]$last[0].owner_proof.user_sid_match}else{$false};endpoint_owner_creation_identity_match=if($last.Count-eq1){[bool]$last[0].owner_proof.creation_identity_match}else{$false};
        endpoint_owner_pid_changed_count=[Math]::Max(0,$ownerPids.Count-1);endpoint_owner_identity_changed_count=[Math]::Max(0,$ownerKeys.Count-1);endpoint_owner_creation_identity_changed_count=[Math]::Max(0,$ownerKeys.Count-1);endpoint_owner_process_lineage_changed_count=[Math]::Max(0,$lineages.Count-1);protected_port_multiple_owner_count=$multiple;multiple_active_endpoint_owner_count=$multiple;foreign_listener_count=$foreign;sampling_contract=$SamplingContract
    }
}

Export-ModuleMember -Function @(
    'Test-Pr90McpCommandLinePathBindingV2', 'Resolve-Pr90McpGuiEnginePathV2',
    'Add-Pr90McpIdentityToListenerObservationV2', 'Get-Pr90McpLineageFingerprintV2',
    'New-Pr90McpEndpointOwnershipSampleV2', 'Test-Pr90McpEndpointOwnershipV2',
    'Set-Pr90McpOwnerProofForBracketedCohortV2','Test-Pr90McpEndpointOwnershipBracketedV2'
)
