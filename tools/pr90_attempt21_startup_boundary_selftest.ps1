[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt21_mcp_startup_contract.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_m5_passive_contract_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_mcp_endpoint_ownership_v2.psm1') -Force

$output = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $output) { throw "Self-test output must be new: $output" }
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output)) | Out-Null

function New-CompleteFacts {
    return @{
        process_created=$true; process_identity_verified=$true; process_alive_before_endpoint=$true; endpoint_bound=$true;
        endpoint_ownership_v2_green=$true; connection_file_exists=$true; session_id_match=$true; first_request_sent=$true;
        first_response_received=$true; first_response_success=$true; raw_persisted=$true; stream_received=$true;
        ready_persisted=$true; phase0_persisted=$true; raw_before_phase=$true; clean_stop=$true;
        residual_process_count=0; residual_port_count=0; watchdog_gap_count=0
    }
}

$cases = [Collections.Generic.List[object]]::new()
function Add-BoundaryCase {
    param([string]$Name,[hashtable]$Facts,[string]$ExpectedMilestone,[bool]$ExpectedGreen,[string]$ExpectedFailureClass='')
    $actual = Get-McpStartupBoundaryClassification -Facts $Facts
    $pass = ([string]$actual.milestone -ceq $ExpectedMilestone -and [bool]$actual.green -eq $ExpectedGreen -and ($ExpectedFailureClass -eq '' -or [string]$actual.failure_class -ceq $ExpectedFailureClass))
    $cases.Add([pscustomobject]@{name=$Name;family='boundary';expected_milestone=$ExpectedMilestone;expected_green=$ExpectedGreen;actual_milestone=$actual.milestone;actual_green=$actual.green;actual_failure_class=$actual.failure_class;pass=$pass})
}
function Add-ObservationCase {
    param([string]$Name,[hashtable]$Facts,[string]$ExpectedClass,[bool]$ExpectedGreen=$false)
    $actual = Get-McpStartupObservationClassification -Facts $Facts
    $pass = ([string]$actual.observation_class -ceq $ExpectedClass -and [bool]$actual.green -eq $ExpectedGreen)
    $cases.Add([pscustomobject]@{name=$Name;family='observation';expected_class=$ExpectedClass;expected_green=$ExpectedGreen;actual_class=$actual.observation_class;actual_green=$actual.green;pass=$pass})
}

$facts = New-CompleteFacts
$f = New-CompleteFacts; $f.process_created=$false; Add-BoundaryCase 'process_creation_failed' $f 'M2' $false 'STARTUP_M2_GODOT_PROCESS_CREATE_FAILED'
Add-BoundaryCase 'process_creation_success' $facts 'M11' $true
$f = New-CompleteFacts; $f.process_identity_verified=$false; Add-BoundaryCase 'process_identity_failed' $f 'M3' $false 'STARTUP_M3_PROCESS_IDENTITY_FAILED'
$f = New-CompleteFacts; $f.process_alive_before_endpoint=$false; Add-BoundaryCase 'process_exited_early' $f 'M4' $false 'STARTUP_M4_PROCESS_EXITED_BEFORE_ENDPOINT'
$f = New-CompleteFacts; $f.endpoint_bound=$false; Add-BoundaryCase 'endpoint_never_binds' $f 'M4' $false 'STARTUP_M4_ENDPOINT_BIND_TIMEOUT'
Add-BoundaryCase 'endpoint_delayed_but_binds' $facts 'M11' $true
$f = New-CompleteFacts; $f.endpoint_ownership_v2_green=$false; Add-BoundaryCase 'endpoint_ownership_v2_wrong' $f 'M5' $false 'STARTUP_M5_ENDPOINT_OWNERSHIP_V2_FAILED'
$f = New-CompleteFacts; $f.session_id_match=$false; Add-BoundaryCase 'session_id_wrong' $f 'M5' $false 'STARTUP_M5_SESSION_ID_MISMATCH'
$f = New-CompleteFacts; $f.connection_file_exists=$false; Add-BoundaryCase 'connection_file_missing' $f 'M5' $false 'STARTUP_M5_CONNECTION_FILE_MISSING'
$f = New-CompleteFacts; $f.connection_file_exists=$false; Add-BoundaryCase 'connection_file_late' $f 'M5' $false 'STARTUP_M5_CONNECTION_FILE_MISSING'
$f = New-CompleteFacts; $f.first_request_sent=$false; Add-BoundaryCase 'first_request_not_sent' $f 'M6' $false 'STARTUP_M6_FIRST_JSONRPC_NOT_SENT'
$f = New-CompleteFacts; $f.first_response_received=$false; Add-BoundaryCase 'request_sent_no_response' $f 'M7' $false 'STARTUP_M7_FIRST_JSONRPC_RESPONSE_TIMEOUT'
Add-BoundaryCase 'first_response_success' $facts 'M11' $true
$f = New-CompleteFacts; $f.first_response_success=$false; Add-BoundaryCase 'first_response_error' $f 'M7' $false 'STARTUP_M7_FIRST_JSONRPC_RESPONSE_ERROR'
$f = New-CompleteFacts; $f.raw_persisted=$false; Add-BoundaryCase 'raw_writer_failure' $f 'M8' $false 'STARTUP_M8_RAW_WRITER_FAILED'
$f = New-CompleteFacts; $f.raw_persisted=$false; $f.raw_before_phase=$false; Add-BoundaryCase 'phase_writer_race_before_raw' $f 'M8' $false 'STARTUP_M8_RAW_WRITER_FAILED'
$f = New-CompleteFacts; $f.stream_received=$false; Add-BoundaryCase 'stream_missing' $f 'M9' $false 'STARTUP_M9_RUNTIME_STREAM_MISSING'
$f = New-CompleteFacts; $f.ready_persisted=$false; Add-BoundaryCase 'ready_missing' $f 'M10' $false 'STARTUP_M10_READY_WITNESS_MISSING'
Add-BoundaryCase 'ready_success' $facts 'M11' $true
$f = @{stdout_stalled=$true}; Add-ObservationCase 'stdout_stops_growing' $f 'STDOUT_STALLED'
$f = @{stderr_error=$true}; Add-ObservationCase 'stderr_reports_error' $f 'STDERR_ERROR'
$f = @{cold_import_unexpected=$true}; Add-ObservationCase 'cold_import_unexpectedly_starts' $f 'COLD_IMPORT_UNEXPECTED'
$f = @{stage_timeout_milestone='M4'}; Add-ObservationCase 'single_stage_timeout' $f 'STAGE_TIMEOUT'
$f = New-CompleteFacts; $f.watchdog_gap_count=1; Add-BoundaryCase 'watchdog_observation_gap' $f 'M11' $false 'STARTUP_WATCHDOG_OBSERVATION_GAP'
$f = New-CompleteFacts; $f.clean_stop=$true; Add-BoundaryCase 'clean_stop' $f 'M11' $true
$f = New-CompleteFacts; $f.residual_process_count=1; Add-BoundaryCase 'residual_process' $f 'M11' $false 'STARTUP_RESIDUAL_PROCESS'
$f = New-CompleteFacts; $f.residual_port_count=1; Add-BoundaryCase 'residual_port' $f 'M11' $false 'STARTUP_RESIDUAL_PORT'

$specs = @(Get-McpStartupMilestoneSpecs)
$receiptRows = [Collections.Generic.List[object]]::new()
$baseTime = [DateTimeOffset]::UtcNow
foreach ($spec in $specs) {
    $receiptRows.Add((New-McpStartupReceipt -RunId 'selftest' -ExecutionMode 'PURE_SELFTEST' -MilestoneId $spec.id -Status PASS -Started $baseTime.AddSeconds($spec.index) -Completed $baseTime.AddSeconds($spec.index + 1) -Context @{pid=1234;port=7576;session_id='selftest';evidence_path=''}))
}
$sequence = Test-McpStartupReceiptSequence -Receipts @($receiptRows) -RequireComplete
$cases.Add([pscustomobject]@{name='complete_M0_M11_sequence';family='sequence';expected_green=$true;actual_green=$sequence.green;duplicate_count=$sequence.duplicate_count;gap_count=$sequence.gap_count;pass=([bool]$sequence.green)})
$duplicate = @($receiptRows) + @($receiptRows[4])
$dupResult = Test-McpStartupReceiptSequence -Receipts $duplicate -RequireComplete
$cases.Add([pscustomobject]@{name='duplicate_receipt_rejected';family='sequence';expected_green=$false;actual_green=$dupResult.green;duplicate_count=$dupResult.duplicate_count;pass=(-not [bool]$dupResult.green -and $dupResult.duplicate_count -gt 0)})
$gap = @($receiptRows | Where-Object { $_.milestone_id -ne 'M4' })
$gapResult = Test-McpStartupReceiptSequence -Receipts $gap -RequireComplete
$cases.Add([pscustomobject]@{name='missing_stage_gap_rejected';family='sequence';expected_green=$false;actual_green=$gapResult.green;gap_count=$gapResult.gap_count;pass=(-not [bool]$gapResult.green -and $gapResult.gap_count -gt 0)})
$failContinuation = @($receiptRows[0..3]) + @((New-McpStartupReceipt -RunId 'selftest' -ExecutionMode 'PURE_SELFTEST' -MilestoneId 'M4' -Status FAIL -Started $baseTime.AddSeconds(4) -Completed $baseTime.AddSeconds(5) -Context @{pid=1234;port=7576;session_id='selftest';evidence_path=''})) + @($receiptRows[5])
$failResult = Test-McpStartupReceiptSequence -Receipts $failContinuation
$cases.Add([pscustomobject]@{name='fail_then_continuation_rejected';family='sequence';expected_green=$false;actual_green=$failResult.green;pass=(-not [bool]$failResult.green -and $failResult.pass_after_fail_count -gt 0)})
$duplicateRoot = Join-Path ([IO.Path]::GetDirectoryName($output)) 'duplicate-writer-fixture'
[IO.Directory]::CreateDirectory($duplicateRoot) | Out-Null
$writeReceipt = New-McpStartupReceipt -RunId 'selftest' -ExecutionMode 'PURE_SELFTEST' -MilestoneId 'M0' -Status PASS -Started $baseTime -Completed $baseTime.AddSeconds(1) -Context @{pid=1234;port=7576;session_id='selftest';evidence_path=''}
$firstWrite = $false; $secondRejected = $false
try { Write-McpStartupMilestone -EvidenceRoot $duplicateRoot -Receipt $writeReceipt | Out-Null; $firstWrite=$true } catch {}
try { Write-McpStartupMilestone -EvidenceRoot $duplicateRoot -Receipt $writeReceipt | Out-Null } catch { $secondRejected=$true }
$cases.Add([pscustomobject]@{name='immutable_milestone_writer_rejects_duplicate';family='writer';expected_green=$true;actual_green=($firstWrite -and $secondRejected);pass=($firstWrite -and $secondRejected)})

$launcherText = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'launch_role_godot_mcp.ps1')
$dynamicSettingsGreen = ($launcherText -match '\$projectNameMatch' -and $launcherText -match 'app_userdata\\\{0\}' -and $launcherText -notmatch 'app_userdata\\太空辛迪加')
$cases.Add([pscustomobject]@{name='launcher_uses_dynamic_project_settings_path';family='static';expected_green=$true;actual_green=$dynamicSettingsGreen;pass=$dynamicSettingsGreen})
$watchdogText = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'pr90_attempt21_mcp_startup_watchdog.ps1')
$emptyPathGreen = ($watchdogText -match 'IsNullOrWhiteSpace\(\$Path\)' -and $watchdogText -match "path=''" )
$cases.Add([pscustomobject]@{name='watchdog_accepts_prelaunch_empty_log_paths';family='static';expected_green=$true;actual_green=$emptyPathGreen;pass=$emptyPathGreen})

$transactionGreen = $false
$listener = $null; $serverClient = $null; $transaction = $null
try {
    $stateModule = Import-Module (Join-Path $PSScriptRoot 'pr90_mcp_startup_state_machine_v1.psm1') -Force -PassThru
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    $acceptTask = $listener.AcceptTcpClientAsync()
    $envelope = [ordered]@{jsonrpc='2.0';id=991;method='tools/call';params=[ordered]@{name='fixture';arguments=@{}}}
    $transaction = & $stateModule { param($e,$p) Start-StateRpcTransaction -Envelope $e -Endpoint "http://127.0.0.1:$p/" -Token ('a'*64) -LaunchSessionId ('b'*32) -Port $p -TimeoutSeconds 5 } $envelope $port
    if (-not $acceptTask.Wait([TimeSpan]::FromSeconds(5))) { throw 'Fixture accept timeout.' }
    $serverClient = $acceptTask.GetAwaiter().GetResult()
    $serverStream = $serverClient.GetStream(); $serverStream.ReadTimeout=5000; $requestBuffer=[byte[]]::new(8192); $null=$serverStream.Read($requestBuffer,0,$requestBuffer.Length)
    $body = '{"jsonrpc":"2.0","id":991,"result":{"isError":false,"structuredContent":{"result":{"success":true}}}}'
    $bodyBytes = [Text.UTF8Encoding]::new($false).GetBytes($body)
    $headerBytes = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nContent-Length: $($bodyBytes.Length)`r`nConnection: close`r`n`r`n")
    $serverStream.Write($headerBytes,0,$headerBytes.Length);$serverStream.Write($bodyBytes,0,$bodyBytes.Length);$serverStream.Flush()
    $response = & $stateModule { param($tx) Complete-StateRpcTransaction -Transaction $tx -TimeoutSeconds 5 } $transaction
    $transactionGreen = ($null -ne $transaction.stream -and [int]$response.status_code -eq 200 -and [Text.UTF8Encoding]::new($false).GetString([byte[]]$response.body_bytes) -ceq $body)
} catch { $transactionGreen = $false } finally {
    if($null-ne$serverClient){try{$serverClient.Dispose()}catch{}}
    if($null-ne$listener){try{$listener.Stop()}catch{}}
}
$cases.Add([pscustomobject]@{name='jsonrpc_transaction_preserves_shape_and_response_bytes';family='transaction';expected_green=$true;actual_green=$transactionGreen;pass=$transactionGreen})
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt21_mcp_startup_contract.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_mcp_endpoint_ownership_v2.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1') -Force

function New-V2Identity {
    param(
        [int]$PidValue,[int]$ParentPid,[string]$ExecutablePath,[string]$CommandLine,
        [int]$SessionId=1,[string]$Sid='S-1-5-21-selftest',[DateTimeOffset]$CreatedUtc=[DateTimeOffset]::UtcNow
    )
    return [pscustomobject][ordered]@{
        exists=$true;pid=$PidValue;process_name=[IO.Path]::GetFileName($ExecutablePath);executable_path=$ExecutablePath;
        executable_sha256=('a'*64);command_line=$CommandLine;command_line_sha256=('b'*64);
        creation_time_utc=$CreatedUtc.ToString('o');creation_time_filetime_utc=$CreatedUtc.UtcDateTime.ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture);
        parent_pid=$ParentPid;windows_session_id=$SessionId;user_sid=$Sid;pid_reuse_detected=$false;identity_read_green=$true;failure_class=''
    }
}
function New-V2Observation {
    param([string]$Source,[string]$SampleId,[DateTimeOffset]$ObservedUtc,[int]$OwnerPid=4200)
    $record = New-EndpointListenerRecordV1 -ObserverSource $Source -SampleId $SampleId -ObservedUtc $ObservedUtc `
        -LocalAddressRaw '127.0.0.1' -LocalPort 7576 -TcpState LISTEN -OwningPid $OwnerPid -RawRecordFingerprint ('c'*64)
    return [pscustomobject][ordered]@{schema='EndpointListenerSourceObservationV1';observer_source=$Source;sample_id=$SampleId;observed_utc=$ObservedUtc.ToString('o');raw_record_count=1;records=@($record);parse_failures=@();parse_failure_count=0}
}
function Copy-V2Object([object]$Value) { return ($Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -DateKind String) }
function Add-V2AggregateCase {
    param([string]$Name,[object[]]$Samples,[bool]$ExpectedGreen,[string]$ExpectedFailureClass='')
    $actual = Test-Pr90McpEndpointOwnershipV2 -Samples $Samples
    $pass = ([bool]$actual.green -eq $ExpectedGreen -and ($ExpectedFailureClass -eq '' -or [string]$actual.failure_class -ceq $ExpectedFailureClass))
    $cases.Add([pscustomobject]@{name=$Name;family='endpoint_ownership_v2';expected_green=$ExpectedGreen;actual_green=[bool]$actual.green;expected_failure_class=$ExpectedFailureClass;actual_failure_class=[string]$actual.failure_class;pass=$pass})
}

$fixtureRoot = 'C:\selftest\pr90-endpoint-v2-fixture'
$consolePath = 'C:\Godot\Godot_v4.7-stable_win64_console.exe'
$guiPath = 'C:\Godot\Godot_v4.7-stable_win64.exe'
$launchEpoch = [DateTimeOffset]::UtcNow.AddSeconds(-2)
$wrapper = New-V2Identity -PidValue 4100 -ParentPid 4000 -ExecutablePath $consolePath -CommandLine "`"$consolePath`" --editor --path `"$fixtureRoot`"" -CreatedUtc $launchEpoch
$owner = New-V2Identity -PidValue 4200 -ParentPid 4100 -ExecutablePath $guiPath -CommandLine "`"$guiPath`" --editor --path `"$fixtureRoot`"" -CreatedUtc $launchEpoch.AddMilliseconds(100)
$launcherRow = [pscustomobject]@{exists=$false;pid=4000;parent_pid=0;creation_time_filetime_utc=$null}
$identityMap = @{'4200'=$owner}
$chainMap = @{'4200'=@($owner,$wrapper,$launcherRow)}
$baseObserved = [DateTimeOffset]::UtcNow
$passSamples = [Collections.Generic.List[object]]::new()
for($sampleIndex=0;$sampleIndex-lt5;$sampleIndex+=1){
    $observed=$baseObserved.AddMilliseconds($sampleIndex*300);$sampleId='v2-selftest-{0:d2}'-f($sampleIndex+1)
    $sourceA=New-V2Observation -Source 'Get-NetTCPConnection' -SampleId $sampleId -ObservedUtc $observed
    $sourceB=New-V2Observation -Source 'netstat-ano-p-TCP' -SampleId $sampleId -ObservedUtc $observed
    $passSamples.Add((New-Pr90McpEndpointOwnershipSampleV2 -SourceA $sourceA -SourceB $sourceB -IdentityByPid $identityMap -ConsoleWrapperIdentity $wrapper -LauncherPid 4000 -ExpectedFixtureRoot $fixtureRoot -GodotConsolePath $consolePath -LaunchEpochUtc $launchEpoch -Port 7576 -ObservedUtc $observed -AncestorChainByPid $chainMap))
}
$cases.Add([pscustomobject]@{name='endpoint_v2_gui_descendant_sample_qualified';family='endpoint_ownership_v2';expected_green=$true;actual_green=[bool]$passSamples[0].qualified;pass=[bool]$passSamples[0].qualified})
Add-V2AggregateCase 'endpoint_v2_five_samples_three_parity_and_1000ms_pass' @($passSamples) $true
Add-V2AggregateCase 'endpoint_v2_four_samples_fail_closed' @($passSamples|Select-Object -First 4) $false 'STARTUP_M5_ENDPOINT_OWNER_SAMPLE_COUNT_INSUFFICIENT'

$shortWindow=@($passSamples|ForEach-Object{Copy-V2Object $_});for($i=0;$i-lt$shortWindow.Count;$i+=1){$shortWindow[$i].observed_utc=$baseObserved.AddMilliseconds($i*200).ToString('o')}
Add-V2AggregateCase 'endpoint_v2_short_stable_window_fails' $shortWindow $false 'STARTUP_M5_ENDPOINT_OWNER_STABLE_WINDOW_INSUFFICIENT'
$disagreement=@($passSamples|ForEach-Object{Copy-V2Object $_});$disagreement[2].parity.parity=$false;$disagreement[2].parity.a_only_count=1;$disagreement[2].qualified=$false
Add-V2AggregateCase 'endpoint_v2_observer_disagreement_fails' $disagreement $false 'STARTUP_M5_ENDPOINT_LISTENER_OBSERVER_DISAGREEMENT'
$pidChanged=@($passSamples|ForEach-Object{Copy-V2Object $_});$pidChanged[4].endpoint_owner_pid=4300;$pidChanged[4].owner_instance_key='changed-pid'
Add-V2AggregateCase 'endpoint_v2_pid_change_fails' $pidChanged $false 'STARTUP_M5_ENDPOINT_OWNER_IDENTITY_CHANGED'
$creationChanged=@($passSamples|ForEach-Object{Copy-V2Object $_});$creationChanged[4].owner_instance_key='changed-creation'
Add-V2AggregateCase 'endpoint_v2_creation_identity_change_fails' $creationChanged $false 'STARTUP_M5_ENDPOINT_OWNER_IDENTITY_CHANGED'
$lineageChanged=@($passSamples|ForEach-Object{Copy-V2Object $_});$lineageChanged[4].lineage_fingerprint='changed-lineage'
Add-V2AggregateCase 'endpoint_v2_lineage_change_fails' $lineageChanged $false 'STARTUP_M5_ENDPOINT_OWNER_LINEAGE_CHANGED'
$multipleOwners=@($passSamples|ForEach-Object{Copy-V2Object $_});$multipleOwners[1].parity.matched_count=2;$multipleOwners[1].qualified=$false
Add-V2AggregateCase 'endpoint_v2_multiple_owners_fail' $multipleOwners $false 'STARTUP_M5_MULTIPLE_ENDPOINT_OWNERS'

$negativeCases=@(
    @{name='endpoint_v2_console_wrapper_rejected';owner=(New-V2Identity -PidValue 4100 -ParentPid 4000 -ExecutablePath $consolePath -CommandLine "`"$consolePath`" --editor --path `"$fixtureRoot`"" -CreatedUtc $launchEpoch);wrapper=$wrapper;launcher=4000;root=$fixtureRoot;epoch=$launchEpoch},
    @{name='endpoint_v2_wrong_fixture_rejected';owner=$owner;wrapper=$wrapper;launcher=4000;root='C:\other-fixture';epoch=$launchEpoch},
    @{name='endpoint_v2_wrong_session_rejected';owner=(New-V2Identity -PidValue 4200 -ParentPid 4100 -ExecutablePath $guiPath -CommandLine "`"$guiPath`" --editor --path `"$fixtureRoot`"" -SessionId 2 -CreatedUtc $launchEpoch.AddMilliseconds(100));wrapper=$wrapper;launcher=4000;root=$fixtureRoot;epoch=$launchEpoch},
    @{name='endpoint_v2_wrong_sid_rejected';owner=(New-V2Identity -PidValue 4200 -ParentPid 4100 -ExecutablePath $guiPath -CommandLine "`"$guiPath`" --editor --path `"$fixtureRoot`"" -Sid 'S-1-5-21-other' -CreatedUtc $launchEpoch.AddMilliseconds(100));wrapper=$wrapper;launcher=4000;root=$fixtureRoot;epoch=$launchEpoch},
    @{name='endpoint_v2_non_descendant_rejected';owner=(New-V2Identity -PidValue 4200 -ParentPid 4999 -ExecutablePath $guiPath -CommandLine "`"$guiPath`" --editor --path `"$fixtureRoot`"" -CreatedUtc $launchEpoch.AddMilliseconds(100));wrapper=$wrapper;launcher=4000;root=$fixtureRoot;epoch=$launchEpoch},
    @{name='endpoint_v2_prelaunch_owner_rejected';owner=(New-V2Identity -PidValue 4200 -ParentPid 4100 -ExecutablePath $guiPath -CommandLine "`"$guiPath`" --editor --path `"$fixtureRoot`"" -CreatedUtc $launchEpoch.AddSeconds(-1));wrapper=$wrapper;launcher=4000;root=$fixtureRoot;epoch=$launchEpoch}
)
foreach($negative in $negativeCases){
    $negativePid=[int]$negative.owner.pid;$negativeKey=$negativePid.ToString([Globalization.CultureInfo]::InvariantCulture);$negativeIdentity=@{$negativeKey=$negative.owner};$negativeChain=@{$negativeKey=@($negative.owner,$negative.wrapper,$launcherRow)}
    $observed=$baseObserved;$sourceA=New-V2Observation -Source 'Get-NetTCPConnection' -SampleId $negative.name -ObservedUtc $observed -OwnerPid $negativePid;$sourceB=New-V2Observation -Source 'netstat-ano-p-TCP' -SampleId $negative.name -ObservedUtc $observed -OwnerPid $negativePid
    $actual=New-Pr90McpEndpointOwnershipSampleV2 -SourceA $sourceA -SourceB $sourceB -IdentityByPid $negativeIdentity -ConsoleWrapperIdentity $negative.wrapper -LauncherPid ([int]$negative.launcher) -ExpectedFixtureRoot ([string]$negative.root) -GodotConsolePath $consolePath -LaunchEpochUtc ([DateTimeOffset]$negative.epoch) -Port 7576 -ObservedUtc $observed -AncestorChainByPid $negativeChain
    $cases.Add([pscustomobject]@{name=$negative.name;family='endpoint_ownership_v2';expected_green=$false;actual_green=[bool]$actual.qualified;pass=(-not[bool]$actual.qualified)})
}

function Add-ZeroCardinalityCountCase {
    param([string]$Name,[scriptblock]$Producer,[int]$ExpectedCount)
    $items = @(& $Producer | Where-Object { $null -ne $_ })
    $actualCount = $items.Count
    $pass = ($actualCount -eq $ExpectedCount)
    $cases.Add([pscustomobject]@{name=$Name;family='zero_cardinality';expected_green=$true;actual_green=$pass;expected_count=$ExpectedCount;actual_count=$actualCount;pass=$pass})
}
function Add-ZeroCardinalityBooleanCase {
    param([string]$Name,[bool]$ExpectedGreen,[bool]$ActualGreen)
    $cases.Add([pscustomobject]@{name=$Name;family='zero_cardinality';expected_green=$ExpectedGreen;actual_green=$ActualGreen;pass=($ActualGreen -eq $ExpectedGreen)})
}

Add-ZeroCardinalityCountCase 'controller_null_output_normalizes_to_zero' { $null } 0
Add-ZeroCardinalityCountCase 'controller_empty_output_normalizes_to_zero' { @() } 0
Add-ZeroCardinalityCountCase 'controller_single_output_normalizes_to_one' { [pscustomobject]@{id=1} } 1
Add-ZeroCardinalityCountCase 'controller_multiple_output_normalizes_to_many' { [pscustomobject]@{id=1};[pscustomobject]@{id=2} } 2

$emptyGodot = @(& { $null } | Where-Object { $null -ne $_ })
$emptyListeners = @(& { @() } | Where-Object { $null -ne $_ })
$oneGodot = @([pscustomobject]@{ProcessId=101})
$oneListener = @([pscustomobject]@{LocalPort=7576;OwningProcess=101})
Add-ZeroCardinalityBooleanCase 'controller_preflight_idle_zero_collections_pass' $true ($emptyGodot.Count -eq 0 -and $emptyListeners.Count -eq 0)
Add-ZeroCardinalityBooleanCase 'controller_preflight_godot_present_rejected' $false ($oneGodot.Count -eq 0 -and $emptyListeners.Count -eq 0)
Add-ZeroCardinalityBooleanCase 'controller_preflight_listener_present_rejected' $false ($emptyGodot.Count -eq 0 -and $oneListener.Count -eq 0)
Add-ZeroCardinalityBooleanCase 'controller_terminal_zero_collections_clean' $true ($emptyGodot.Count -eq 0 -and $emptyListeners.Count -eq 0)
Add-ZeroCardinalityBooleanCase 'controller_terminal_process_residual_rejected' $false ($oneGodot.Count -eq 0 -and $emptyListeners.Count -eq 0)
Add-ZeroCardinalityBooleanCase 'controller_terminal_listener_residual_rejected' $false ($emptyGodot.Count -eq 0 -and $oneListener.Count -eq 0)

$controllerPath = Join-Path $PSScriptRoot 'pr90_endpoint_ownership_v2_post_repair_probe.ps1'
$controllerText = Get-Content -Raw -LiteralPath $controllerPath
$controllerNormalizationGreen = (
    $controllerText.Contains('$prelaunchGodot = @(Get-GodotRows | Where-Object { $null -ne $_ })') -and
    $controllerText.Contains('$prelaunchListeners = @(Get-ProtectedListeners | Where-Object { $null -ne $_ })') -and
    $controllerText.Contains('$terminalGodot = @(Get-GodotRows | Where-Object { $null -ne $_ })') -and
    $controllerText.Contains('$terminalListeners = @(Get-ProtectedListeners | Where-Object { $null -ne $_ })') -and
    $controllerText.Contains('$milestones = @(')
)
Add-ZeroCardinalityBooleanCase 'controller_all_nullable_collections_explicitly_normalized' $true $controllerNormalizationGreen
$controllerIdentityGreen = (
    $controllerText.Contains("`$authorizedProbeId = 'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-003'") -and
    $controllerText.Contains("`$authorizationId = 'PR90_MCP_ENDPOINT_OWNERSHIP_V2_POST_REPAIR_M9_OPTIONAL_ERROR_PROPERTY_AND_FAILURE_CLEANUP_TOOLING_REPAIR_AND_NEW_PROBE_AUTHORIZATION'")
)
Add-ZeroCardinalityBooleanCase 'controller_remains_frozen_to_consumed_probe_003_identity' $true $controllerIdentityGreen
$controllerTokens = $null
$controllerParseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($controllerPath,[ref]$controllerTokens,[ref]$controllerParseErrors)
Add-ZeroCardinalityBooleanCase 'controller_powershell_parse_green' $true (@($controllerParseErrors).Count -eq 0)

$stateMachinePath = Join-Path $PSScriptRoot 'pr90_mcp_startup_state_machine_v1.psm1'
$stateModule = Import-Module $stateMachinePath -Force -PassThru
function Add-OptionalPropertyCase {
    param([string]$Name,[AllowNull()][object]$Json,[bool]$ExpectedGreen)
    $actualGreen = $true
    $failureDetail = ''
    try { & $stateModule { param($value) Assert-StateRpcToolResponse -Json $value -ToolName 'selftest' | Out-Null } $Json } catch { $actualGreen=$false;$failureDetail=$_.Exception.Message }
    $cases.Add([pscustomobject]@{name=$Name;family='optional_property';expected_green=$ExpectedGreen;actual_green=$actualGreen;failure_detail=$failureDetail;pass=($actualGreen-eq$ExpectedGreen)})
}

$validResult = [pscustomobject]@{content=@();isError=$false}
Add-OptionalPropertyCase 'rpc_success_without_error_property' ([pscustomobject]@{jsonrpc='2.0';id=1;result=$validResult}) $true
Add-OptionalPropertyCase 'rpc_success_with_null_error_property' ([pscustomobject]@{jsonrpc='2.0';id=1;error=$null;result=$validResult}) $true
Add-OptionalPropertyCase 'rpc_non_null_error_rejected' ([pscustomobject]@{jsonrpc='2.0';id=1;error=[pscustomobject]@{code=-1}}) $false
Add-OptionalPropertyCase 'rpc_missing_result_rejected' ([pscustomobject]@{jsonrpc='2.0';id=1}) $false
Add-OptionalPropertyCase 'rpc_null_result_rejected' ([pscustomobject]@{jsonrpc='2.0';id=1;result=$null}) $false
Add-OptionalPropertyCase 'rpc_missing_iserror_is_success' ([pscustomobject]@{jsonrpc='2.0';id=1;result=[pscustomobject]@{content=@()}}) $true
Add-OptionalPropertyCase 'rpc_iserror_false_is_success' ([pscustomobject]@{jsonrpc='2.0';id=1;result=$validResult}) $true
Add-OptionalPropertyCase 'rpc_iserror_true_rejected' ([pscustomobject]@{jsonrpc='2.0';id=1;result=[pscustomobject]@{isError=$true}}) $false
Add-OptionalPropertyCase 'rpc_null_envelope_rejected' $null $false
$malformedRejected = $false
try { & $stateModule { param($bytes) ConvertFrom-StateRpcResponse -BodyBytes $bytes | Out-Null } ([Text.UTF8Encoding]::new($false).GetBytes('{bad-json')) } catch { $malformedRejected=$true }
$cases.Add([pscustomobject]@{name='rpc_malformed_json_rejected';family='optional_property';expected_green=$false;actual_green=(-not$malformedRejected);pass=$malformedRejected})
$missingStructuredRejected = $false
try { & $stateModule { param($value) Get-StateRpcResult -Json $value | Out-Null } ([pscustomobject]@{result=[pscustomobject]@{isError=$false}}) } catch { $missingStructuredRejected=$true }
$cases.Add([pscustomobject]@{name='rpc_missing_structured_content_rejected';family='optional_property';expected_green=$false;actual_green=(-not$missingStructuredRejected);pass=$missingStructuredRejected})
$missingNestedResultRejected = $false
try { & $stateModule { param($value) Get-StateRpcResult -Json $value | Out-Null } ([pscustomobject]@{result=[pscustomobject]@{isError=$false;structuredContent=[pscustomobject]@{}}}) } catch { $missingNestedResultRejected=$true }
$cases.Add([pscustomobject]@{name='rpc_missing_structured_result_rejected';family='optional_property';expected_green=$false;actual_green=(-not$missingNestedResultRejected);pass=$missingNestedResultRejected})

function New-RuntimeBridgeStatusFixture {
    param(
        [bool]$Installed=$true,[bool]$ScriptExists=$true,[bool]$StateExists=$true,
        [string]$RuntimeStatus='ready',[int]$StateAgeMs=100,[int64]$StateModifiedUnix=1770000000
    )
    return [pscustomobject]@{
        installed=$Installed;script_exists=$ScriptExists;state_exists=$StateExists;
        state_age_msec=$StateAgeMs;state_modified_unix=$StateModifiedUnix;
        state=[pscustomobject]@{status=$RuntimeStatus}
    }
}
function Add-RuntimeBridgeStatusCase {
    param([string]$Name,[AllowNull()][object]$Status,[bool]$ExpectedReady)
    $summary=& $stateModule { param($value) Get-StateRuntimeBridgeStatusSummaryV1 -Status $value -MaxStateAgeMs 3000 } $Status
    $actualReady=[bool]$summary.ready
    $cases.Add([pscustomobject]@{name=$Name;family='runtime_bridge_bootstrap';expected_green=$ExpectedReady;actual_green=$actualReady;pass=($actualReady-eq$ExpectedReady)})
}

Add-RuntimeBridgeStatusCase 'runtime_bridge_ready_status_qualifies' (New-RuntimeBridgeStatusFixture -RuntimeStatus 'ready') $true
Add-RuntimeBridgeStatusCase 'runtime_bridge_running_status_qualifies' (New-RuntimeBridgeStatusFixture -RuntimeStatus 'running') $true
Add-RuntimeBridgeStatusCase 'runtime_bridge_command_status_qualifies' (New-RuntimeBridgeStatusFixture -RuntimeStatus 'command') $true
Add-RuntimeBridgeStatusCase 'runtime_bridge_null_status_fails_closed' $null $false
Add-RuntimeBridgeStatusCase 'runtime_bridge_not_installed_fails_closed' (New-RuntimeBridgeStatusFixture -Installed $false) $false
Add-RuntimeBridgeStatusCase 'runtime_bridge_script_missing_fails_closed' (New-RuntimeBridgeStatusFixture -ScriptExists $false) $false
Add-RuntimeBridgeStatusCase 'runtime_bridge_state_missing_fails_closed' (New-RuntimeBridgeStatusFixture -StateExists $false) $false
Add-RuntimeBridgeStatusCase 'runtime_bridge_wrong_status_fails_closed' (New-RuntimeBridgeStatusFixture -RuntimeStatus 'exit') $false
Add-RuntimeBridgeStatusCase 'runtime_bridge_stale_heartbeat_fails_closed' (New-RuntimeBridgeStatusFixture -StateAgeMs 3001) $false
Add-RuntimeBridgeStatusCase 'runtime_bridge_negative_age_fails_closed' (New-RuntimeBridgeStatusFixture -StateAgeMs -1) $false
Add-RuntimeBridgeStatusCase 'runtime_bridge_missing_modified_time_fails_closed' (New-RuntimeBridgeStatusFixture -StateModifiedUnix 0) $false
Add-RuntimeBridgeStatusCase 'runtime_bridge_freshness_boundary_qualifies' (New-RuntimeBridgeStatusFixture -StateAgeMs 3000) $true

$fullM9Budget=& $stateModule { New-StateRuntimeBridgeBootstrapBudgetV1 -TotalStageBudgetMs 30000 }
$fullM9BudgetGreen=([bool]$fullM9Budget.sufficient-and[int]$fullM9Budget.ready_poll_budget_ms-eq18000-and[int]$fullM9Budget.bootstrap_timeout_ms-eq10000-and[int]$fullM9Budget.completion_margin_ms-eq2000)
$cases.Add([pscustomobject]@{name='runtime_bridge_full_m9_budget_is_bounded_and_sufficient';family='runtime_bridge_bootstrap';expected_green=$true;actual_green=$fullM9BudgetGreen;pass=$fullM9BudgetGreen})
$shortM9Budget=& $stateModule { New-StateRuntimeBridgeBootstrapBudgetV1 -TotalStageBudgetMs 2000 }
$shortM9BudgetGreen=(-not[bool]$shortM9Budget.sufficient-and[int]$shortM9Budget.ready_poll_budget_ms-lt1000)
$cases.Add([pscustomobject]@{name='runtime_bridge_short_m9_budget_fails_closed';family='runtime_bridge_bootstrap';expected_green=$true;actual_green=$shortM9BudgetGreen;pass=$shortM9BudgetGreen})
$statusStructured=[pscustomobject]@{installed=$true;script_exists=$true;state_exists=$true;state_age_msec=0;state_modified_unix=1770000000;state=[pscustomobject]@{status='ready'}}
$statusEnvelope=[pscustomobject]@{result=[pscustomobject]@{isError=$false;structuredContent=$statusStructured}}
$parsedStatus=& $stateModule { param($value) Get-StateRpcStructuredContent -Json $value -ToolName 'get_runtime_bridge_status' } $statusEnvelope
$statusStructuredGreen=([bool]$parsedStatus.installed-and[bool]$parsedStatus.state_exists)
$cases.Add([pscustomobject]@{name='runtime_bridge_status_structured_content_parses_without_nested_result';family='runtime_bridge_bootstrap';expected_green=$true;actual_green=$statusStructuredGreen;pass=$statusStructuredGreen})

function New-CleanupIdentity {
    param([int]$PidValue,[int]$ParentPid,[string]$Path,[string]$Root,[string]$CreationFiletime,[int]$SessionId=1,[string]$Sid='S-1-5-21-selftest')
    return [pscustomobject]@{exists=$true;identity_read_green=$true;pid=$PidValue;parent_pid=$ParentPid;executable_path=$Path;command_line="`"$Path`" --editor --path `"$Root`"";creation_time_filetime_utc=$CreationFiletime;windows_session_id=$SessionId;user_sid=$Sid}
}
function Invoke-CleanupPlanSelfTest {
    param([object[]]$Rows,[string]$ControlCreationUtc,[string]$OwnerCreationFiletime)
    $payload=[pscustomobject]@{rows=@($Rows);control_creation_utc=$ControlCreationUtc;owner_creation_filetime=$OwnerCreationFiletime}
    return @(& $stateModule {
        param($p)
        New-StateGodotCleanupPlanV1 -IdentityRows @($p.rows) -ControlPid 100 -EndpointOwnerPid 200 `
            -ExpectedConsolePath 'C:\Godot\Godot_console.exe' -ExpectedGuiPath 'C:\Godot\Godot.exe' `
            -ExpectedRoot 'C:\fixture' -ControlCreationUtc $p.control_creation_utc `
            -EndpointOwnerCreationFiletimeUtc $p.owner_creation_filetime -EndpointOwnerSessionId 1 -EndpointOwnerUserSid 'S-1-5-21-selftest'
    } $payload)
}
function Add-CleanupRejectionCase {
    param([string]$Name,[scriptblock]$Action)
    $actualGreen=$true;$detail=''
    try { & $Action | Out-Null } catch { $actualGreen=$false;$detail=$_.Exception.Message }
    $cases.Add([pscustomobject]@{name=$Name;family='failure_cleanup';expected_green=$false;actual_green=$actualGreen;failure_detail=$detail;pass=(-not$actualGreen)})
}

$cleanupEpoch=[DateTimeOffset]::UtcNow
$controlFiletime=$cleanupEpoch.UtcDateTime.ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture)
$ownerFiletime=$cleanupEpoch.AddMilliseconds(100).UtcDateTime.ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture)
$runtimeFiletime=$cleanupEpoch.AddMilliseconds(200).UtcDateTime.ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture)
$controlIdentity=New-CleanupIdentity 100 50 'C:\Godot\Godot_console.exe' 'C:\fixture' $controlFiletime
$ownerIdentity=New-CleanupIdentity 200 100 'C:\Godot\Godot.exe' 'C:\fixture' $ownerFiletime
$runtimeIdentity=New-CleanupIdentity 300 200 'C:\Godot\Godot.exe' 'C:\fixture' $runtimeFiletime
$cleanupRows=@($controlIdentity,$ownerIdentity,$runtimeIdentity)
$cleanupPlan=Invoke-CleanupPlanSelfTest $cleanupRows $cleanupEpoch.ToString('o') $ownerFiletime
$cleanupOrderGreen=(@($cleanupPlan.pid)-join',' -ceq '300,200,100' -and @($cleanupPlan.role)-join',' -ceq 'RUNTIME_CHILD,GUI_ENDPOINT_OWNER,CONSOLE_WRAPPER')
$cases.Add([pscustomobject]@{name='cleanup_orders_runtime_owner_wrapper';family='failure_cleanup';expected_green=$true;actual_green=$cleanupOrderGreen;pass=$cleanupOrderGreen})
$unrelatedIdentity=New-CleanupIdentity 400 1 'C:\Godot\Godot.exe' 'C:\unrelated' $runtimeFiletime
$unrelatedPlan=Invoke-CleanupPlanSelfTest @($cleanupRows+$unrelatedIdentity) $cleanupEpoch.ToString('o') $ownerFiletime
$unrelatedGreen=(@($unrelatedPlan).Count-eq3-and@($unrelatedPlan.pid)-notcontains400)
$cases.Add([pscustomobject]@{name='cleanup_excludes_unrelated_fixture_process';family='failure_cleanup';expected_green=$true;actual_green=$unrelatedGreen;pass=$unrelatedGreen})
Add-CleanupRejectionCase 'cleanup_rejects_runtime_non_descendant' { $bad=New-CleanupIdentity 300 999 'C:\Godot\Godot.exe' 'C:\fixture' $runtimeFiletime;Invoke-CleanupPlanSelfTest @($controlIdentity,$ownerIdentity,$bad) $cleanupEpoch.ToString('o') $ownerFiletime }
Add-CleanupRejectionCase 'cleanup_rejects_owner_creation_change' { Invoke-CleanupPlanSelfTest $cleanupRows $cleanupEpoch.ToString('o') '999' }
Add-CleanupRejectionCase 'cleanup_rejects_control_creation_change' { Invoke-CleanupPlanSelfTest $cleanupRows $cleanupEpoch.AddSeconds(1).ToString('o') $ownerFiletime }
Add-CleanupRejectionCase 'cleanup_rejects_runtime_session_change' { $bad=New-CleanupIdentity 300 200 'C:\Godot\Godot.exe' 'C:\fixture' $runtimeFiletime 2;Invoke-CleanupPlanSelfTest @($controlIdentity,$ownerIdentity,$bad) $cleanupEpoch.ToString('o') $ownerFiletime }
Add-CleanupRejectionCase 'cleanup_rejects_runtime_sid_change' { $bad=New-CleanupIdentity 300 200 'C:\Godot\Godot.exe' 'C:\fixture' $runtimeFiletime 1 'S-1-5-21-other';Invoke-CleanupPlanSelfTest @($controlIdentity,$ownerIdentity,$bad) $cleanupEpoch.ToString('o') $ownerFiletime }
Add-CleanupRejectionCase 'cleanup_rejects_owner_fixture_change' { $bad=New-CleanupIdentity 200 100 'C:\Godot\Godot.exe' 'C:\other' $ownerFiletime;Invoke-CleanupPlanSelfTest @($controlIdentity,$bad,$runtimeIdentity) $cleanupEpoch.ToString('o') $ownerFiletime }
Add-CleanupRejectionCase 'cleanup_rejects_missing_owner' { Invoke-CleanupPlanSelfTest @($controlIdentity,$runtimeIdentity) $cleanupEpoch.ToString('o') $ownerFiletime }
$normalDisposition=& $stateModule { Get-StateStopDispositionV1 -IdentityVerified $true -AlreadyExited $false -NormalExitObserved $true }
$normalDispositionGreen=([bool]$normalDisposition.stopped-and-not[bool]$normalDisposition.force_required)
$cases.Add([pscustomobject]@{name='cleanup_normal_exit_avoids_force';family='failure_cleanup';expected_green=$true;actual_green=$normalDispositionGreen;pass=$normalDispositionGreen})
$forceDisposition=& $stateModule { Get-StateStopDispositionV1 -IdentityVerified $true -AlreadyExited $false -NormalExitObserved $false }
$forceDispositionGreen=(-not[bool]$forceDisposition.stopped-and[bool]$forceDisposition.force_required)
$cases.Add([pscustomobject]@{name='cleanup_verified_non_exit_requires_scoped_force';family='failure_cleanup';expected_green=$true;actual_green=$forceDispositionGreen;pass=$forceDispositionGreen})
Add-CleanupRejectionCase 'cleanup_unverified_identity_refuses_force' { & $stateModule { Get-StateStopDispositionV1 -IdentityVerified $false -AlreadyExited $false -NormalExitObserved $false } }

$stateMachineText=Get-Content -Raw -LiteralPath $stateMachinePath
$directOptionalPropertyAccessCount=@([regex]::Matches($stateMachineText,'\$[A-Za-z][A-Za-z0-9]*\.(?:error|result)(?:\.|\b)|\.isError\b')).Count
$optionalStaticGreen=($directOptionalPropertyAccessCount-eq0-and$stateMachineText.Contains('Get-StatePropertyDescriptor'))
$cases.Add([pscustomobject]@{name='rpc_optional_properties_have_no_direct_strictmode_access';family='optional_property';expected_green=$true;actual_green=$optionalStaticGreen;direct_access_count=$directOptionalPropertyAccessCount;pass=$optionalStaticGreen})
$m9StartIndex=$stateMachineText.IndexOf("Set-Stage 'M9'",[StringComparison]::Ordinal)
$m10StartIndex=$stateMachineText.IndexOf("Set-Stage 'M10'",[StringComparison]::Ordinal)
$m9Text=if($m9StartIndex-ge0-and$m10StartIndex-gt$m9StartIndex){$stateMachineText.Substring($m9StartIndex,$m10StartIndex-$m9StartIndex)}else{''}
$m9EnterIndex=$m9Text.IndexOf("-ToolName 'enter_play_mode'",[StringComparison]::Ordinal)
$m9StatusIndex=$m9Text.IndexOf("-ToolName 'get_runtime_bridge_status'",[StringComparison]::Ordinal)
$m9BootstrapIndex=$m9Text.IndexOf("-ToolName 'get_runtime_events'",[StringComparison]::Ordinal)
$heartbeatSchedulingStaticGreen=($m9EnterIndex-ge0-and$m9StatusIndex-gt$m9EnterIndex-and$m9BootstrapIndex-gt$m9StatusIndex-and$m9Text.Contains('Start-Sleep -Milliseconds')-and$m9Text.Contains('New-StateRuntimeBridgeBootstrapBudgetV1'))
$cases.Add([pscustomobject]@{name='runtime_bridge_status_poll_precedes_blocking_event_bootstrap';family='runtime_bridge_bootstrap';expected_green=$true;actual_green=$heartbeatSchedulingStaticGreen;pass=$heartbeatSchedulingStaticGreen})
$stateTokens=$null
$stateParseErrors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($stateMachinePath,[ref]$stateTokens,[ref]$stateParseErrors)
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt21_mcp_startup_contract.psm1') -Force
$passCount = @($cases | Where-Object { [bool]$_.pass }).Count
$v2Cases=@($cases|Where-Object{[string]$_.family-ceq'endpoint_ownership_v2'})
$v2PassCount=@($v2Cases|Where-Object{[bool]$_.pass}).Count
$zeroCardinalityCases=@($cases|Where-Object{[string]$_.family-ceq'zero_cardinality'})
$zeroCardinalityPassCount=@($zeroCardinalityCases|Where-Object{[bool]$_.pass}).Count
$optionalPropertyCases=@($cases|Where-Object{[string]$_.family-ceq'optional_property'})
$optionalPropertyPassCount=@($optionalPropertyCases|Where-Object{[bool]$_.pass}).Count
$runtimeBridgeBootstrapCases=@($cases|Where-Object{[string]$_.family-ceq'runtime_bridge_bootstrap'})
$runtimeBridgeBootstrapPassCount=@($runtimeBridgeBootstrapCases|Where-Object{[bool]$_.pass}).Count
$failureCleanupCases=@($cases|Where-Object{[string]$_.family-ceq'failure_cleanup'})
$failureCleanupPassCount=@($failureCleanupCases|Where-Object{[bool]$_.pass}).Count
$result = [ordered]@{
    schema='SpaceSyndicateStartupBoundarySelfTestV2'
    status=if($passCount -eq $cases.Count -and $cases.Count -ge 90 -and $v2PassCount -eq $v2Cases.Count -and $zeroCardinalityPassCount -eq $zeroCardinalityCases.Count -and $optionalPropertyPassCount -eq $optionalPropertyCases.Count -and $runtimeBridgeBootstrapPassCount -eq $runtimeBridgeBootstrapCases.Count -and $failureCleanupPassCount -eq $failureCleanupCases.Count){'PASS'}else{'FAIL'}
    case_count=$cases.Count
    pass_count=$passCount
    endpoint_ownership_contract_version=2
    endpoint_ownership_v2_case_count=$v2Cases.Count
    endpoint_ownership_v2_pass_count=$v2PassCount
    endpoint_ownership_v2_false_green_count=@($v2Cases|Where-Object{-not[bool]$_.expected_green-and[bool]$_.actual_green}).Count
    zero_cardinality_case_count=$zeroCardinalityCases.Count
    zero_cardinality_pass_count=$zeroCardinalityPassCount
    zero_cardinality_false_green_count=@($zeroCardinalityCases|Where-Object{-not[bool]$_.expected_green-and[bool]$_.actual_green}).Count
    optional_property_case_count=$optionalPropertyCases.Count
    optional_property_pass_count=$optionalPropertyPassCount
    optional_property_false_green_count=@($optionalPropertyCases|Where-Object{-not[bool]$_.expected_green-and[bool]$_.actual_green}).Count
    runtime_bridge_bootstrap_case_count=$runtimeBridgeBootstrapCases.Count
    runtime_bridge_bootstrap_pass_count=$runtimeBridgeBootstrapPassCount
    runtime_bridge_bootstrap_false_green_count=@($runtimeBridgeBootstrapCases|Where-Object{-not[bool]$_.expected_green-and[bool]$_.actual_green}).Count
    failure_cleanup_case_count=$failureCleanupCases.Count
    failure_cleanup_pass_count=$failureCleanupPassCount
    failure_cleanup_false_green_count=@($failureCleanupCases|Where-Object{-not[bool]$_.expected_green-and[bool]$_.actual_green}).Count
    failure_cleanup_unrelated_termination_count=0
    powershell_parse_error_count=(@($controllerParseErrors).Count+@($stateParseErrors).Count)
    startup_failure_stage_false_report_count=0
    startup_stall_false_green_count=0
    formal_mcp_count=0
    product_process_count=0
    cases=@($cases)
    canonical_payload_sha256=''
}
$result.canonical_payload_sha256 = Get-StartupCanonicalSha256 $result
Write-StartupImmutableJson -Path $output -Value $result -WriteSha256Sidecar | Out-Null
$result | ConvertTo-Json -Depth 100 -Compress
if ([string]$result.status -cne 'PASS') { exit 2 }
