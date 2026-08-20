Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_key_formatter_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_parity_validator_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_process_identity_reader_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_m5_passive_contract_v1.psm1') -Force

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

Export-ModuleMember -Function @(
    'Test-Pr90McpCommandLinePathBindingV2', 'Resolve-Pr90McpGuiEnginePathV2',
    'Add-Pr90McpIdentityToListenerObservationV2', 'Get-Pr90McpLineageFingerprintV2',
    'New-Pr90McpEndpointOwnershipSampleV2', 'Test-Pr90McpEndpointOwnershipV2'
)
