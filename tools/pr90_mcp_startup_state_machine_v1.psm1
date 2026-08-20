Set-StrictMode -Version Latest

$contractPath = Join-Path $PSScriptRoot 'pr90_attempt21_mcp_startup_contract.psm1'
$stateMachinePath = Join-Path $PSScriptRoot 'pr90_mcp_startup_state_machine_v1.psm1'
Import-Module $contractPath -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_getnettcp_listener_adapter_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_netstat_listener_adapter_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_process_identity_reader_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_m5_passive_contract_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_mcp_endpoint_ownership_v2.psm1') -Force

function Test-StateCommandLineWorktreeBinding {
    param([string]$CommandLine, [string]$ExpectedRoot)
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    foreach ($rootForm in @($ExpectedRoot, $ExpectedRoot.Replace('\','/'))) {
        $escaped = [Regex]::Escape($rootForm.TrimEnd('\','/'))
        $pattern = '(?i)(?:^|\s)--path(?:\s+|=)(?:"' + $escaped + '"|' + $escaped + ')(?=\s|$)'
        if ([Regex]::IsMatch($CommandLine, $pattern)) { return $true }
    }
    return $false
}

function Write-StateAtomicText {
    param([string]$Path, [string]$Text, [switch]$Immutable)
    $full = [IO.Path]::GetFullPath($Path)
    if ($Immutable -and (Test-Path -LiteralPath $full)) { throw "Refusing overwrite: $full" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    $temporary = "$full.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, $Text, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $full, (-not $Immutable))
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function New-StateRpcEnvelope {
    param([int]$Id, [string]$ToolName, [hashtable]$Arguments)
    return [ordered]@{
        jsonrpc = '2.0'
        id = $Id
        method = 'tools/call'
        params = [ordered]@{ name=$ToolName; arguments=$Arguments }
    }
}

function Start-StateRpcTransaction {
    param(
        [Parameter(Mandatory = $true)][object]$Envelope,
        [Parameter(Mandatory = $true)][string]$Endpoint,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$LaunchSessionId,
        [ValidateRange(1,65535)][int]$Port,
        [ValidateRange(1,120)][int]$TimeoutSeconds = 15
    )
    $bodyText = $Envelope | ConvertTo-Json -Depth 50 -Compress
    $bodyBytes = [Text.UTF8Encoding]::new($false).GetBytes($bodyText)
    $headerText = @(
        'POST / HTTP/1.1'
        'Host: 127.0.0.1'
        'Content-Type: application/json'
        "Content-Length: $($bodyBytes.Length)"
        "X-Funplay-MCP-Token: $Token"
        'MCP-Protocol-Version: 2025-11-25'
        "X-PR90-Launch-Session: $LaunchSessionId"
        'Connection: close'
        ''
        ''
    ) -join "`r`n"
    $headerBytes = [Text.Encoding]::ASCII.GetBytes($headerText)
    $requestBytes = [byte[]]::new($headerBytes.Length + $bodyBytes.Length)
    [Buffer]::BlockCopy($headerBytes, 0, $requestBytes, 0, $headerBytes.Length)
    [Buffer]::BlockCopy($bodyBytes, 0, $requestBytes, $headerBytes.Length, $bodyBytes.Length)
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $connectTask = $client.ConnectAsync('127.0.0.1', $Port)
        if (-not $connectTask.Wait([TimeSpan]::FromSeconds($TimeoutSeconds))) {
            throw "TCP endpoint connect timed out after $TimeoutSeconds seconds."
        }
        [void]$connectTask.GetAwaiter().GetResult()
        $stream = $client.GetStream()
        $stream.WriteTimeout = $TimeoutSeconds * 1000
        $stream.Write($requestBytes, 0, $requestBytes.Length)
        $stream.Flush()
        return ,([pscustomobject]@{
            client=$client; stream=$stream; request_id=[int]$Envelope.id; request_text=$bodyText;
            request_bytes=$requestBytes; request_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bodyBytes)).ToLowerInvariant();
            sent_utc=[DateTimeOffset]::UtcNow.ToString('o'); received_bytes=[byte[]]@(); response=$null
        })
    } catch {
        try { $client.Dispose() } catch {}
        throw
    }
}

function Complete-StateRpcTransaction {
    param(
        [Parameter(Mandatory = $true)][object]$Transaction,
        [ValidateRange(1,120)][int]$TimeoutSeconds = 30
    )
    $stream = $Transaction.stream
    $stream.ReadTimeout = $TimeoutSeconds * 1000
    $bufferStream = [IO.MemoryStream]::new()
    $buffer = [byte[]]::new(8192)
    $headerLength = -1
    $contentLength = -1
    $statusCode = 0
    $headers = [ordered]@{}
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    try {
        while ($true) {
            if ([DateTimeOffset]::UtcNow -gt $deadline) { throw "JSON-RPC response timeout after $TimeoutSeconds seconds." }
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $bufferStream.Write($buffer, 0, $read)
            $Transaction.received_bytes = $bufferStream.ToArray()
            if ($headerLength -lt 0) {
                $asLatin1 = [Text.Encoding]::Latin1.GetString($Transaction.received_bytes)
                $separator = $asLatin1.IndexOf("`r`n`r`n", [StringComparison]::Ordinal)
                if ($separator -ge 0) {
                    $headerLength = $separator + 4
                    $headerLines = $asLatin1.Substring(0, $separator) -split "`r`n"
                    if ($headerLines.Count -eq 0 -or $headerLines[0] -notmatch '^HTTP/\d\.\d\s+(\d+)') {
                        throw 'MCP response did not contain an HTTP status line.'
                    }
                    $statusCode = [int]$Matches[1]
                    foreach ($line in @($headerLines | Select-Object -Skip 1)) {
                        $separatorIndex = $line.IndexOf(':')
                        if ($separatorIndex -gt 0) {
                            $headers[$line.Substring(0,$separatorIndex).Trim().ToLowerInvariant()] = $line.Substring($separatorIndex+1).Trim()
                        }
                    }
                    if (-not $headers.Contains('content-length')) { throw 'MCP response omitted Content-Length.' }
                    $contentLength = [int]$headers['content-length']
                }
            }
            if ($headerLength -ge 0 -and $Transaction.received_bytes.Length -ge ($headerLength + $contentLength)) { break }
        }
        if ($headerLength -lt 0) { throw 'MCP response closed before HTTP headers arrived.' }
        $allBytes = [byte[]]$Transaction.received_bytes
        if ($allBytes.Length -lt ($headerLength + $contentLength)) { throw 'MCP response closed before Content-Length bytes arrived.' }
        $bodyBytes = [byte[]]::new($contentLength)
        [Buffer]::BlockCopy($allBytes, $headerLength, $bodyBytes, 0, $contentLength)
        $Transaction.response = [pscustomobject]@{
            status_code=$statusCode; headers=$headers; body_bytes=$bodyBytes;
            body_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bodyBytes)).ToLowerInvariant();
            received_utc=[DateTimeOffset]::UtcNow.ToString('o')
        }
        return $Transaction.response
    } finally {
        try { $stream.Dispose() } catch {}
        try { $Transaction.client.Dispose() } catch {}
    }
}

function Dispose-StateRpcTransaction {
    param([object]$Transaction)
    if ($null -eq $Transaction) { return }
    try { $Transaction.stream.Dispose() } catch {}
    try { $Transaction.client.Dispose() } catch {}
}

function ConvertFrom-StateRpcResponse {
    param([Parameter(Mandatory = $true)][byte[]]$BodyBytes)
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($BodyBytes)
    return $text | ConvertFrom-Json -Depth 100
}

function Get-StatePropertyDescriptor {
    param([AllowNull()][object]$InputObject, [Parameter(Mandatory = $true)][string]$Name)
    if ($null -eq $InputObject) {
        return [pscustomobject]@{ exists=$false; value=$null }
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return [pscustomobject]@{ exists=$false; value=$null }
    }
    return [pscustomobject]@{ exists=$true; value=$property.Value }
}

function Assert-StateRpcToolResponse {
    param(
        [AllowNull()][object]$Json,
        [Parameter(Mandatory = $true)][string]$ToolName
    )
    if ($null -eq $Json) { throw "MCP tool $ToolName returned an empty JSON-RPC envelope." }
    $errorProperty = Get-StatePropertyDescriptor -InputObject $Json -Name 'error'
    if ([bool]$errorProperty.exists -and $null -ne $errorProperty.value) {
        throw "MCP tool $ToolName returned a JSON-RPC error."
    }
    $resultProperty = Get-StatePropertyDescriptor -InputObject $Json -Name 'result'
    if (-not [bool]$resultProperty.exists -or $null -eq $resultProperty.value) {
        throw "MCP tool $ToolName omitted its JSON-RPC result."
    }
    $isErrorProperty = Get-StatePropertyDescriptor -InputObject $resultProperty.value -Name 'isError'
    if ([bool]$isErrorProperty.exists -and [bool]$isErrorProperty.value) {
        throw "MCP tool $ToolName returned an MCP error result."
    }
    return $resultProperty.value
}

function Get-StateRpcStructuredContent {
    param(
        [Parameter(Mandatory = $true)][object]$Json,
        [Parameter(Mandatory = $true)][string]$ToolName
    )
    $toolResult = Assert-StateRpcToolResponse -Json $Json -ToolName $ToolName
    $structuredContentProperty = Get-StatePropertyDescriptor -InputObject $toolResult -Name 'structuredContent'
    if (-not [bool]$structuredContentProperty.exists -or $null -eq $structuredContentProperty.value) {
        throw "MCP tool $ToolName omitted structuredContent."
    }
    return $structuredContentProperty.value
}

function Get-StateRpcResult {
    param([Parameter(Mandatory = $true)][object]$Json)
    $structuredContent = Get-StateRpcStructuredContent -Json $Json -ToolName 'get_runtime_events'
    $resultProperty = Get-StatePropertyDescriptor -InputObject $structuredContent -Name 'result'
    if (-not [bool]$resultProperty.exists -or $null -eq $resultProperty.value) {
        throw 'MCP response omitted structuredContent.result.'
    }
    return $resultProperty.value
}

function Get-StateRuntimeBridgeStatusSummaryV1 {
    param(
        [AllowNull()][object]$Status,
        [ValidateRange(1,60000)][int]$MaxStateAgeMs = 3000
    )
    $installed = $false
    $scriptExists = $false
    $stateExists = $false
    $runtimeStatus = ''
    $stateAgeMs = -1
    $stateModifiedUnix = 0
    if ($null -ne $Status) {
        $installedProperty = Get-StatePropertyDescriptor -InputObject $Status -Name 'installed'
        $scriptProperty = Get-StatePropertyDescriptor -InputObject $Status -Name 'script_exists'
        $stateExistsProperty = Get-StatePropertyDescriptor -InputObject $Status -Name 'state_exists'
        $stateAgeProperty = Get-StatePropertyDescriptor -InputObject $Status -Name 'state_age_msec'
        $stateModifiedProperty = Get-StatePropertyDescriptor -InputObject $Status -Name 'state_modified_unix'
        $stateProperty = Get-StatePropertyDescriptor -InputObject $Status -Name 'state'
        if ([bool]$installedProperty.exists) { $installed = [bool]$installedProperty.value }
        if ([bool]$scriptProperty.exists) { $scriptExists = [bool]$scriptProperty.value }
        if ([bool]$stateExistsProperty.exists) { $stateExists = [bool]$stateExistsProperty.value }
        if ([bool]$stateAgeProperty.exists -and $null -ne $stateAgeProperty.value) { $stateAgeMs = [int]$stateAgeProperty.value }
        if ([bool]$stateModifiedProperty.exists -and $null -ne $stateModifiedProperty.value) { $stateModifiedUnix = [int64]$stateModifiedProperty.value }
        if ([bool]$stateProperty.exists -and $null -ne $stateProperty.value) {
            $runtimeStatusProperty = Get-StatePropertyDescriptor -InputObject $stateProperty.value -Name 'status'
            if ([bool]$runtimeStatusProperty.exists -and $null -ne $runtimeStatusProperty.value) { $runtimeStatus = [string]$runtimeStatusProperty.value }
        }
    }
    $ready = (
        $installed -and $scriptExists -and $stateExists -and $stateModifiedUnix -gt 0 -and
        $stateAgeMs -ge 0 -and $stateAgeMs -le $MaxStateAgeMs -and
        $runtimeStatus -cin @('ready','running','command')
    )
    return [pscustomobject][ordered]@{
        ready=$ready;installed=$installed;script_exists=$scriptExists;state_exists=$stateExists;
        runtime_status=$runtimeStatus;state_age_msec=$stateAgeMs;state_modified_unix=$stateModifiedUnix;
        max_state_age_msec=$MaxStateAgeMs
    }
}

function New-StateRuntimeBridgeBootstrapBudgetV1 {
    param(
        [ValidateRange(1,120000)][int]$TotalStageBudgetMs,
        [ValidateRange(100,30000)][int]$RequestedBootstrapTimeoutMs = 10000,
        [ValidateRange(100,30000)][int]$CompletionMarginMs = 2000,
        [ValidateRange(50,5000)][int]$StatusPollIntervalMs = 250
    )
    $usableBudgetMs = [Math]::Max(0, $TotalStageBudgetMs - $CompletionMarginMs)
    $bootstrapTimeoutMs = [Math]::Min($RequestedBootstrapTimeoutMs, [Math]::Max(0, $usableBudgetMs - 1000))
    $readyPollBudgetMs = [Math]::Max(0, $usableBudgetMs - $bootstrapTimeoutMs)
    $sufficient = ($bootstrapTimeoutMs -ge 100 -and $readyPollBudgetMs -ge 1000)
    return [pscustomobject][ordered]@{
        total_stage_budget_ms=$TotalStageBudgetMs;ready_poll_budget_ms=$readyPollBudgetMs;
        bootstrap_timeout_ms=$bootstrapTimeoutMs;completion_margin_ms=$CompletionMarginMs;
        status_poll_interval_ms=$StatusPollIntervalMs;sufficient=$sufficient
    }
}

function Get-StateDescendantDepthV1 {
    param([int]$Pid, [int]$AncestorPid, [hashtable]$IdentityByPid)
    $currentPid = $Pid
    $visited = [Collections.Generic.HashSet[int]]::new()
    $depth = 0
    while ($currentPid -gt 0 -and $visited.Add($currentPid)) {
        if ($currentPid -eq $AncestorPid) { return $depth }
        $key = $currentPid.ToString([Globalization.CultureInfo]::InvariantCulture)
        if (-not $IdentityByPid.ContainsKey($key)) { return -1 }
        $currentPid = [int]$IdentityByPid[$key].parent_pid
        $depth += 1
    }
    return -1
}

function New-StateGodotCleanupPlanV1 {
    param(
        [Parameter(Mandatory = $true)][object[]]$IdentityRows,
        [int]$ControlPid,
        [int]$EndpointOwnerPid,
        [Parameter(Mandatory = $true)][string]$ExpectedConsolePath,
        [Parameter(Mandatory = $true)][string]$ExpectedGuiPath,
        [Parameter(Mandatory = $true)][string]$ExpectedRoot,
        [Parameter(Mandatory = $true)][string]$ControlCreationUtc,
        [Parameter(Mandatory = $true)][string]$EndpointOwnerCreationFiletimeUtc,
        [int]$EndpointOwnerSessionId,
        [Parameter(Mandatory = $true)][string]$EndpointOwnerUserSid
    )
    $allIdentities = @($IdentityRows | Where-Object { $null -ne $_ -and [bool]$_.exists -and [bool]$_.identity_read_green })
    $taskIdentities = @($allIdentities | Where-Object {
        [string]$_.executable_path -iin @($ExpectedConsolePath,$ExpectedGuiPath) -and
        (Test-StateCommandLineWorktreeBinding -CommandLine ([string]$_.command_line) -ExpectedRoot $ExpectedRoot)
    })
    $identityByPid = @{}
    foreach ($identity in $taskIdentities) {
        $pidKey = ([int]$identity.pid).ToString([Globalization.CultureInfo]::InvariantCulture)
        $identityByPid[$pidKey] = $identity
    }
    $controlKey = $ControlPid.ToString([Globalization.CultureInfo]::InvariantCulture)
    $ownerKey = $EndpointOwnerPid.ToString([Globalization.CultureInfo]::InvariantCulture)
    if (-not $identityByPid.ContainsKey($controlKey) -or -not $identityByPid.ContainsKey($ownerKey)) {
        throw 'Cleanup identities do not contain the control process and endpoint owner.'
    }
    $control = $identityByPid[$controlKey]
    $owner = $identityByPid[$ownerKey]
    $expectedControlFiletime = [DateTimeOffset]::Parse($ControlCreationUtc,[Globalization.CultureInfo]::InvariantCulture).UtcDateTime.ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture)
    if ([string]$control.executable_path -ine $ExpectedConsolePath -or [string]$control.creation_time_filetime_utc -cne $expectedControlFiletime) {
        throw 'Cleanup control process identity changed.'
    }
    if (
        [string]$owner.executable_path -ine $ExpectedGuiPath -or
        [string]$owner.creation_time_filetime_utc -cne $EndpointOwnerCreationFiletimeUtc -or
        [int]$owner.windows_session_id -ne $EndpointOwnerSessionId -or
        [string]$owner.user_sid -cne $EndpointOwnerUserSid -or
        (Get-StateDescendantDepthV1 -Pid $EndpointOwnerPid -AncestorPid $ControlPid -IdentityByPid $identityByPid) -lt 1
    ) {
        throw 'Cleanup endpoint owner identity changed.'
    }
    $runtimeRows = [Collections.Generic.List[object]]::new()
    foreach ($identity in $taskIdentities) {
        $pidValue = [int]$identity.pid
        if ($pidValue -in @($ControlPid,$EndpointOwnerPid)) { continue }
        $depth = Get-StateDescendantDepthV1 -Pid $pidValue -AncestorPid $EndpointOwnerPid -IdentityByPid $identityByPid
        if (
            $depth -lt 1 -or
            [string]$identity.executable_path -ine $ExpectedGuiPath -or
            [int]$identity.windows_session_id -ne $EndpointOwnerSessionId -or
            [string]$identity.user_sid -cne $EndpointOwnerUserSid
        ) {
            throw "Cleanup runtime child identity is not authorized: PID $pidValue."
        }
        $runtimeRows.Add([pscustomobject]@{ role='RUNTIME_CHILD';pid=$pidValue;depth=$depth;creation_time_filetime_utc=[string]$identity.creation_time_filetime_utc })
    }
    $plan = [Collections.Generic.List[object]]::new()
    foreach ($runtime in @($runtimeRows | Sort-Object depth -Descending)) { $plan.Add($runtime) }
    $plan.Add([pscustomobject]@{role='GUI_ENDPOINT_OWNER';pid=$EndpointOwnerPid;depth=0;creation_time_filetime_utc=[string]$owner.creation_time_filetime_utc})
    $plan.Add([pscustomobject]@{role='CONSOLE_WRAPPER';pid=$ControlPid;depth=0;creation_time_filetime_utc=[string]$control.creation_time_filetime_utc})
    return @($plan)
}

function Get-StateStopDispositionV1 {
    param([bool]$IdentityVerified, [bool]$AlreadyExited, [bool]$NormalExitObserved)
    if (-not $IdentityVerified) { throw 'Refusing process stop because cleanup identity was not verified.' }
    if ($AlreadyExited -or $NormalExitObserved) {
        return [pscustomobject]@{ stopped=$true;force_required=$false }
    }
    return [pscustomobject]@{ stopped=$false;force_required=$true }
}

function Stop-StateGodot {
    param(
        [int]$Pid,
        [string]$ProcessStartUtc,
        [string]$GodotPath,
        [string]$Worktree,
        [int]$Port,
        [string]$StopScriptPath,
        [int]$EndpointOwnerPid = 0,
        [string]$EndpointOwnerCreationFiletimeUtc = '',
        [int]$EndpointOwnerSessionId = 0,
        [string]$EndpointOwnerUserSid = ''
    )
    $expectedConsolePath = (Resolve-Path -LiteralPath $GodotPath).Path
    $expectedGuiPath = Resolve-Pr90McpGuiEnginePathV2 $expectedConsolePath
    $candidateRows = @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object { [string]$_.ExecutablePath -iin @($expectedConsolePath,$expectedGuiPath) }
    )
    $identities = @(foreach ($candidate in $candidateRows) { Read-EndpointListenerOwnerIdentityV1 -PidValue ([int]$candidate.ProcessId) })
    $plan = @(New-StateGodotCleanupPlanV1 -IdentityRows $identities -ControlPid $Pid -EndpointOwnerPid $EndpointOwnerPid `
        -ExpectedConsolePath $expectedConsolePath -ExpectedGuiPath $expectedGuiPath -ExpectedRoot $Worktree `
        -ControlCreationUtc $ProcessStartUtc -EndpointOwnerCreationFiletimeUtc $EndpointOwnerCreationFiletimeUtc `
        -EndpointOwnerSessionId $EndpointOwnerSessionId -EndpointOwnerUserSid $EndpointOwnerUserSid)
    $listenersBefore = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($listenersBefore.Count -gt 1 -or ($listenersBefore.Count -eq 1 -and [int]$listenersBefore[0].OwningProcess -ne $EndpointOwnerPid)) {
        throw 'Refusing cleanup because endpoint listener ownership changed.'
    }
    $normalCloseRequests = [Collections.Generic.List[object]]::new()
    $forcedStopPids = [Collections.Generic.List[int]]::new()
    foreach ($entry in $plan) {
        $process = Get-Process -Id ([int]$entry.pid) -ErrorAction SilentlyContinue
        if ($null -eq $process -or $process.HasExited) { continue }
        $currentIdentity = Read-EndpointListenerOwnerIdentityV1 -PidValue ([int]$entry.pid)
        $identityVerified = (
            [bool]$currentIdentity.exists -and [bool]$currentIdentity.identity_read_green -and
            [string]$currentIdentity.creation_time_filetime_utc -ceq [string]$entry.creation_time_filetime_utc -and
            (Test-StateCommandLineWorktreeBinding -CommandLine ([string]$currentIdentity.command_line) -ExpectedRoot $Worktree)
        )
        if (-not $identityVerified) { throw "Cleanup identity changed immediately before stop: PID $($entry.pid)." }
        $normalRequested = $false
        try { $normalRequested = [bool]$process.CloseMainWindow() } catch {}
        $normalCloseRequests.Add([pscustomobject]@{role=[string]$entry.role;pid=[int]$entry.pid;requested=$normalRequested})
        $normalTimeoutMs = if ([string]$entry.role -ceq 'GUI_ENDPOINT_OWNER') { 20000 } else { 5000 }
        $normalExited = $false
        try { $normalExited = $process.WaitForExit($normalTimeoutMs) } catch { $normalExited = $true }
        $disposition = Get-StateStopDispositionV1 -IdentityVerified $identityVerified -AlreadyExited $false -NormalExitObserved $normalExited
        if ([bool]$disposition.force_required) {
            $latestIdentity = Read-EndpointListenerOwnerIdentityV1 -PidValue ([int]$entry.pid)
            if (-not [bool]$latestIdentity.exists) { continue }
            if ([string]$latestIdentity.creation_time_filetime_utc -cne [string]$entry.creation_time_filetime_utc) {
                throw "Cleanup PID was reused before scoped force-stop: PID $($entry.pid)."
            }
            Stop-Process -Id ([int]$entry.pid) -Force -ErrorAction Stop
            $forcedStopPids.Add([int]$entry.pid)
            if (-not $process.WaitForExit(10000)) { throw "Verified task process did not exit: PID $($entry.pid)." }
        }
    }
    $remainingProcess = @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                [string]$_.ExecutablePath -iin @($expectedConsolePath,$expectedGuiPath) -and
                (Test-StateCommandLineWorktreeBinding -CommandLine ([string]$_.CommandLine) -ExpectedRoot $Worktree)
            }
    )
    $remainingListeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    $stopped = ($remainingProcess.Count -eq 0 -and $remainingListeners.Count -eq 0)
    if ($stopped) {
        Remove-Item -LiteralPath (Join-Path $Worktree '.codex-godot/godot.pid') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $Worktree '.codex-godot/endpoint.txt') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $Worktree '.codex-godot/connection.json') -Force -ErrorAction SilentlyContinue
    }
    return [pscustomobject]@{
        stopped=$stopped;forced_stop=($forcedStopPids.Count -gt 0);forced_stop_process_ids=@($forcedStopPids);
        normal_close_requests=@($normalCloseRequests);runtime_child_count=@($plan|Where-Object{[string]$_.role-ceq'RUNTIME_CHILD'}).Count;
        process_count_after=$remainingProcess.Count;endpoint_count_after=$remainingListeners.Count;unrelated_process_termination_count=0
    }
}

function Invoke-Pr90McpStartupStateMachine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('PRE_FORMAL_STARTUP_PROBE','PRE_FORMAL_EXACT_MCP_DRY_RUN','FORMAL_EXACT_SHA_MCP')][string]$ExecutionMode,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$ProbeIdentity,
        [Parameter(Mandatory = $true)][string]$Worktree,
        [Parameter(Mandatory = $true)][string]$EvidenceRoot,
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$ExpectedHeadSha,
        [Parameter(Mandatory = $true)][string]$ExpectedTreeSha,
        [Parameter(Mandatory = $true)][string]$LaunchScriptPath,
        [Parameter(Mandatory = $true)][string]$ExpectedLaunchScriptSha256,
        [Parameter(Mandatory = $true)][string]$StopScriptPath,
        [Parameter(Mandatory = $true)][string]$ExpectedStopScriptSha256,
        [Parameter(Mandatory = $true)][string]$WatchdogScriptPath,
        [Parameter(Mandatory = $true)][string]$ExpectedWatchdogScriptSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedStateMachineSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedContractSha256,
        [string]$ProbeScenePath = 'res://scenes/runtime/ActionResultPresentationService.tscn',
        [string]$SealedBaselinePath = '',
        [string]$ExpectedSealedBaselineSha256 = '',
        [string]$StartupToolingManifestPath = '',
        [string]$ExpectedStartupToolingManifestSha256 = '',
        [string]$StartupToolingSealPath = '',
        [string]$ExpectedStartupToolingSealSha256 = '',
        [string]$FormalAuthorizationValidationReceiptPath = '',
        [string]$ExpectedFormalAuthorizationValidationReceiptSha256 = '',
        [ValidateRange(1,65535)][int]$Port = 7576,
        [switch]$KeepRunningAfterM11
    )

    $ErrorActionPreference = 'Stop'
    $root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
    $evidence = [IO.Path]::GetFullPath($EvidenceRoot)
    if (Test-Path -LiteralPath $evidence) { throw 'Startup state-machine evidence root must be new.' }
    foreach ($directory in @('milestones','mcp-raw','phases','requests','responses','witnesses','diagnostics','watchdog','launcher')) {
        [IO.Directory]::CreateDirectory((Join-Path $evidence $directory)) | Out-Null
    }
    $sessionId = [Guid]::NewGuid().ToString('N')
    $receipts = [Collections.Generic.List[object]]::new()
    $currentMilestone = 'M0'
    $stageStarted = [DateTimeOffset]::UtcNow
    $primaryFailure = $null
    $failureWritten = $false
    $godotPid = 0
    $processStartUtc = ''
    $godotStdoutPath = ''
    $godotStderrPath = ''
    $connectionPath = Join-Path $root '.codex-godot/connection.json'
    $watchdogChild = $null
    $watchdogStopped = $false
    $cleanStop = $false
    $cleanupResult = [pscustomobject]@{stopped=$false;forced_stop=$false;forced_stop_process_ids=@();normal_close_requests=@();runtime_child_count=0;process_count_after=-1;endpoint_count_after=-1;unrelated_process_termination_count=0}
    $enteredPlayMode = $false
    $enterPlayModeAttempted = $false
    $streamId = ''
    $cursor = [int64]0
    $mcpCallId = 0
    $m8RawPath = ''
    $m8RawSha = ''
    $m9RawPath = ''
    $m9RawSha = ''
    $m10ReadyPath = ''
    $m10ReadySha = ''
    $endpointOwnerPid = 0
    $endpointOwnerIdentity = $null
    $endpointOwnershipV2 = $null
    $prelaunchProtectedPortListenerCount = 0
    $contextBase = @{
        port=$Port; session_id=$sessionId; session_id_source='tooling_generated'; pid=$null; parent_pid=$null;
        process_creation_identity=$null; stdout_path=''; stderr_path=''; endpoint_owner_pid=$null;
        endpoint_ownership_contract_version=2; endpoint_owner_process_role=$null
    }
    $runtime = @{
        currentMilestone='M0'; stageStarted=$stageStarted; failureWritten=$false; godotPid=0;
        godotStdoutPath=''; godotStderrPath=''; mcpCallId=0
    }

    function Set-Stage {
        param([string]$MilestoneId)
        $runtime.currentMilestone = $MilestoneId
        $runtime.stageStarted = [DateTimeOffset]::UtcNow
    }
    function Get-StageContext {
        param([hashtable]$Extra = @{})
        $snapshot = Get-McpStartupProcessSnapshot -Pid $runtime.godotPid -StdoutPath $runtime.godotStdoutPath `
            -StderrPath $runtime.godotStderrPath -Port $Port -EvidenceRoot $evidence -ConnectionPath $connectionPath
        $row = @{}
        foreach ($key in $contextBase.Keys) { $row[$key] = $contextBase[$key] }
        foreach ($property in $snapshot.PSObject.Properties) { $row[$property.Name] = $property.Value }
        foreach ($key in $Extra.Keys) { $row[$key] = $Extra[$key] }
        return $row
    }
    function Save-Pass {
        param([string]$MilestoneId, [DateTimeOffset]$Started, [hashtable]$Extra = @{})
        $actualStarted = $runtime.stageStarted
        Test-StartupStageElapsed -MilestoneId $MilestoneId -Started $actualStarted
        $receipt = New-McpStartupReceipt -RunId $RunId -ExecutionMode $ExecutionMode -MilestoneId $MilestoneId `
            -Status PASS -Started $actualStarted -Completed ([DateTimeOffset]::UtcNow) -Context (Get-StageContext $Extra)
        $path = Write-McpStartupMilestone -EvidenceRoot $evidence -Receipt $receipt
        $receipts.Add($receipt)
        return $path
    }
    function Save-Failure {
        param([string]$MilestoneId, [DateTimeOffset]$Started, [string]$Detail, [string]$FailureClass = '')
        if ($runtime.failureWritten) { return }
        $snapshotContext = Get-StageContext @{}
        $diagnosticPath = Join-Path $evidence ("diagnostics/{0}-failure.json" -f $MilestoneId)
        $diagnostic = [ordered]@{
            schema='McpStartupFailureDiagnosticV1'; run_id=$RunId; execution_mode=$ExecutionMode; milestone_id=$MilestoneId;
            failure_detail=$Detail; observed_utc=[DateTimeOffset]::UtcNow.ToString('o'); context=$snapshotContext
        }
        Write-StartupImmutableJson -Path $diagnosticPath -Value $diagnostic -WriteSha256Sidecar | Out-Null
        $snapshotContext.evidence_path = $diagnosticPath
        $snapshotContext.evidence_sha256 = Get-StartupSha256 -Path $diagnosticPath
        $receipt = New-McpStartupReceipt -RunId $RunId -ExecutionMode $ExecutionMode -MilestoneId $MilestoneId `
            -Status FAIL -Started $Started -Completed ([DateTimeOffset]::UtcNow) -Context $snapshotContext `
            -FailureClass $FailureClass -FailureDetail $Detail
        try { Write-McpStartupMilestone -EvidenceRoot $evidence -Receipt $receipt | Out-Null } catch {}
        $receipts.Add($receipt)
        $runtime.failureWritten = $true
    }
    function Invoke-RecordedRpc {
        param([string]$ToolName, [hashtable]$Arguments = @{}, [int]$TimeoutSeconds = 30)
        $runtime.mcpCallId += 1
        $id = $runtime.mcpCallId
        $envelope = New-StateRpcEnvelope -Id $id -ToolName $ToolName -Arguments $Arguments
        $rawPath = Join-Path $evidence ('mcp-raw/{0:D4}-{1}.jsonrpc.json' -f $id,$ToolName)
        $requestPath = Join-Path $evidence ('requests/{0:D4}-{1}.json' -f $id,$ToolName)
        Write-StartupImmutableJson -Path $requestPath -Value $envelope | Out-Null
        $transaction = $null
        try {
            $transaction = Start-StateRpcTransaction -Envelope $envelope -Endpoint "http://127.0.0.1:$Port/" -Token ([IO.File]::ReadAllText((Join-Path $root '.codex-godot/auth.token')).Trim()) -LaunchSessionId $sessionId -Port $Port -TimeoutSeconds ([Math]::Min(15,$TimeoutSeconds))
            $response = Complete-StateRpcTransaction -Transaction $transaction -TimeoutSeconds $TimeoutSeconds
            Write-StartupImmutableBytes -Path $rawPath -Bytes $response.body_bytes | Out-Null
            $json = ConvertFrom-StateRpcResponse -BodyBytes $response.body_bytes
            Assert-StateRpcToolResponse -Json $json -ToolName $ToolName | Out-Null
            return [pscustomobject]@{ id=$id; tool=$ToolName; request=$requestPath; raw=$rawPath; raw_sha256=(Get-StartupSha256 $rawPath); response=$response; json=$json }
        } catch {
            if ($null -ne $transaction -and $transaction.received_bytes.Length -gt 0 -and -not (Test-Path -LiteralPath $rawPath)) {
                try { Write-StartupImmutableBytes -Path $rawPath -Bytes ([byte[]]$transaction.received_bytes) | Out-Null } catch {}
            }
            throw
        } finally {
            Dispose-StateRpcTransaction -Transaction $transaction
        }
    }

    try {
        Set-Stage 'M0'
        $head = (& git -C $root rev-parse HEAD).Trim()
        $tree = (& git -C $root rev-parse 'HEAD^{tree}').Trim()
        if ($head -cne $ExpectedHeadSha -or $tree -cne $ExpectedTreeSha) { throw 'Product HEAD/tree identity mismatch.' }
        foreach ($pair in @(
            @($LaunchScriptPath,$ExpectedLaunchScriptSha256),
            @($StopScriptPath,$ExpectedStopScriptSha256),
            @($WatchdogScriptPath,$ExpectedWatchdogScriptSha256),
            @($contractPath,$ExpectedContractSha256),
            @($stateMachinePath,$ExpectedStateMachineSha256)
        )) {
            if ((Get-StartupSha256 -Path $pair[0]) -cne ([string]$pair[1]).ToLowerInvariant()) {
                throw "Tooling hash mismatch: $($pair[0])"
            }
        }
        if ($SealedBaselinePath) {
            if ((Get-StartupSha256 -Path $SealedBaselinePath) -cne $ExpectedSealedBaselineSha256.ToLowerInvariant()) { throw 'Sealed baseline hash mismatch.' }
            $baseline = Get-Content -Raw -LiteralPath $SealedBaselinePath | ConvertFrom-Json -Depth 100
            if ([string]$baseline.head_sha -cne $head -or [string]$baseline.tree_sha -cne $tree -or -not [bool]$baseline.post_import_baseline_sealed) { throw 'Sealed baseline identity mismatch.' }
        }
        if ($StartupToolingManifestPath) {
            if ((Get-StartupSha256 -Path $StartupToolingManifestPath) -cne $ExpectedStartupToolingManifestSha256.ToLowerInvariant()) { throw 'Startup tooling manifest hash mismatch.' }
            $toolManifest = Get-Content -Raw -LiteralPath $StartupToolingManifestPath | ConvertFrom-Json -Depth 100
            if ([string]$toolManifest.product_head_sha -cne $head -or [string]$toolManifest.product_tree_sha -cne $tree -or [string]$toolManifest.status -cne 'READY') { throw 'Startup tooling manifest identity/status mismatch.' }
        }
        if ($StartupToolingSealPath) {
            if ((Get-StartupSha256 -Path $StartupToolingSealPath) -cne $ExpectedStartupToolingSealSha256.ToLowerInvariant()) { throw 'Startup tooling seal hash mismatch.' }
            $toolSeal = Get-Content -Raw -LiteralPath $StartupToolingSealPath | ConvertFrom-Json -Depth 100
            if ([string]$toolSeal.product_head_sha -cne $head -or [string]$toolSeal.product_tree_sha -cne $tree -or [string]$toolSeal.status -cne 'SEALED') { throw 'Startup tooling seal identity/status mismatch.' }
        }
        if ($ExecutionMode -ceq 'FORMAL_EXACT_SHA_MCP') {
            if ([string]::IsNullOrWhiteSpace($FormalAuthorizationValidationReceiptPath)) { throw 'Formal authorization validation receipt is required.' }
            if ((Get-StartupSha256 -Path $FormalAuthorizationValidationReceiptPath) -cne $ExpectedFormalAuthorizationValidationReceiptSha256.ToLowerInvariant()) { throw 'Formal authorization validation receipt hash mismatch.' }
            $auth = Get-Content -Raw -LiteralPath $FormalAuthorizationValidationReceiptPath | ConvertFrom-Json -Depth 100
            if ([string]$auth.status -cne 'PASS' -or [string]$auth.product_head_sha -cne $head -or [string]$auth.product_tree_sha -cne $tree -or [bool]$auth.authorization_consumed) { throw 'Formal authorization validation receipt is not an unconsumed exact identity PASS.' }
        }
        $protectedPorts = @($Port,7586) | Sort-Object -Unique
        $prelaunchProtectedListeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { [int]$_.LocalPort -in $protectedPorts })
        $prelaunchProtectedPortListenerCount = $prelaunchProtectedListeners.Count
        if ($prelaunchProtectedPortListenerCount -ne 0) { throw 'A protected startup probe port is already bound.' }
        $m0Path = Join-Path $evidence 'authorization-validation.json'
        $m0 = [ordered]@{
            schema='McpStartupAuthorizationValidationV1'; status='PASS'; execution_mode=$ExecutionMode; probe_identity=$ProbeIdentity;
            formal_authorization_consumed=$false; head_sha=$head; tree_sha=$tree; session_id=$sessionId; session_id_source='tooling_generated';
            endpoint_ownership_contract_version=2; protected_ports=$protectedPorts; prelaunch_protected_port_listener_count=$prelaunchProtectedPortListenerCount;
            startup_tooling_manifest_sha256=if($StartupToolingManifestPath){Get-StartupSha256 $StartupToolingManifestPath}else{''};
            startup_tooling_seal_sha256=if($StartupToolingSealPath){Get-StartupSha256 $StartupToolingSealPath}else{''}
        }
        Write-StartupImmutableJson -Path $m0Path -Value $m0 -WriteSha256Sidecar | Out-Null
        Save-Pass -MilestoneId 'M0' -Started $stageStarted -Extra @{evidence_path=$m0Path;evidence_sha256=(Get-StartupSha256 $m0Path)} | Out-Null

        Set-Stage 'M1'
        $watchdogRoot = Join-Path $evidence 'watchdog'
        $watchdogStop = Join-Path $watchdogRoot 'stop.signal'
        $watchdogReady = Join-Path $watchdogRoot 'ready.signal'
        $watchdogOut = Join-Path $watchdogRoot 'wrapper.stdout.log'
        $watchdogErr = Join-Path $watchdogRoot 'wrapper.stderr.log'
        $watchdogArgs = @('-NoProfile','-File',$WatchdogScriptPath,'-ObservationRoot',$watchdogRoot,'-EvidenceRoot',$evidence,'-Worktree',$root,'-GodotPath',$GodotPath,'-LaunchReceiptPath',(Join-Path $evidence 'launcher/process-start.json'),'-StopSignalPath',$watchdogStop,'-ReadySignalPath',$watchdogReady,'-PortsCsv',"$Port,7586",'-IntervalMilliseconds','1000')
        $watchdogChild = Start-StartupChildProcess -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList $watchdogArgs -WorkingDirectory $root -StdoutPath $watchdogOut -StderrPath $watchdogErr
        $readyDeadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
        while (-not (Test-Path -LiteralPath $watchdogReady) -and [DateTimeOffset]::UtcNow -lt $readyDeadline) { Start-Sleep -Milliseconds 100 }
        if (-not (Test-Path -LiteralPath $watchdogReady)) { throw 'Startup watchdog did not become ready.' }
        $executionPath = Join-Path $evidence 'execution-start.json'
        $execution = [ordered]@{
            schema='McpStartupExecutionStartV1'; run_id=$RunId; execution_mode=$ExecutionMode; started_utc=$stageStarted.ToString('o');
            session_id=$sessionId; session_id_source='tooling_generated'; worktree=$root; working_directory=(Get-Location).Path;
            userprofile=$env:USERPROFILE; appdata_policy='role_local'; localappdata_policy='role_local'; port=$Port; watchdog_pid=$watchdogChild.process.Id;
            formal_authorization_consumed=$false; play_main_scene_count=0; product_match_count=0
        }
        Write-StartupImmutableJson -Path $executionPath -Value $execution -WriteSha256Sidecar | Out-Null
        Save-Pass -MilestoneId 'M1' -Started $stageStarted -Extra @{evidence_path=$executionPath;evidence_sha256=(Get-StartupSha256 $executionPath)} | Out-Null

        Set-Stage 'M2'
        $launchReceiptPath = Join-Path $evidence 'launcher/process-start.json'
        $launcherOut = Join-Path $evidence 'launcher/wrapper.stdout.log'
        $launcherErr = Join-Path $evidence 'launcher/wrapper.stderr.log'
        $launchSession = $sessionId
        $launcherArgs = @('-NoProfile','-File',$LaunchScriptPath,'-Role','A','-Port',[string]$Port,'-Worktree',$root,'-GodotPath',$GodotPath,'-Renderer','compatibility','-StartupTimeoutSeconds','90','-StartOnly','-LaunchReceiptPath',$launchReceiptPath,'-LaunchSessionId',$launchSession)
        $launcherChild = Start-StartupChildProcess -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList $launcherArgs -WorkingDirectory $root -StdoutPath $launcherOut -StderrPath $launcherErr
        $launchCompleted = Complete-StartupChildProcess -Child $launcherChild -TimeoutSeconds 15 -KillOnTimeout
        if (-not $launchCompleted.exited -or $launchCompleted.exit_code -ne 0 -or -not (Test-Path -LiteralPath $launchReceiptPath)) { throw "Create-only launcher failed (exit=$($launchCompleted.exit_code))." }
        $launch = Get-Content -Raw -LiteralPath $launchReceiptPath | ConvertFrom-Json -Depth 40 -DateKind String
        $godotPid = [int]$launch.pid; $processStartUtc = [string]$launch.process_start_time_utc; $godotStdoutPath = [string]$launch.stdout_path; $godotStderrPath = [string]$launch.stderr_path
        $contextBase.pid = $godotPid; $contextBase.parent_pid = [int]$launch.parent_pid; $contextBase.process_creation_identity = $processStartUtc; $contextBase.stdout_path = $godotStdoutPath; $contextBase.stderr_path = $godotStderrPath
        $runtime.godotPid = $godotPid; $runtime.godotStdoutPath = $godotStdoutPath; $runtime.godotStderrPath = $godotStderrPath
        Save-Pass -MilestoneId 'M2' -Started $stageStarted -Extra @{evidence_path=$launchReceiptPath;evidence_sha256=(Get-StartupSha256 $launchReceiptPath)} | Out-Null

        Set-Stage 'M3'
        $process = Get-Process -Id $godotPid -ErrorAction Stop
        $processRow = Get-CimInstance Win32_Process -Filter "ProcessId=$godotPid" -ErrorAction Stop
        if ([string]$process.Path -ine (Resolve-Path -LiteralPath $GodotPath).Path -or -not (Test-StateCommandLineWorktreeBinding -CommandLine ([string]$processRow.CommandLine) -ExpectedRoot $root)) { throw 'Godot process executable or --path identity mismatch.' }
        $identityPath = Join-Path $evidence 'process-identity.json'
        $identity = [ordered]@{schema='McpProcessIdentityV1';pid=$godotPid;parent_pid=[int]$processRow.ParentProcessId;process_creation_identity=$processStartUtc;executable_path=[string]$process.Path;command_line=[string]$processRow.CommandLine;command_line_sha256=(Get-StartupCanonicalSha256 ([pscustomobject]@{command_line=[string]$processRow.CommandLine;canonical_payload_sha256=''}));worktree=$root}
        Write-StartupImmutableJson -Path $identityPath -Value $identity -WriteSha256Sidecar | Out-Null
        Save-Pass -MilestoneId 'M3' -Started $stageStarted -Extra @{evidence_path=$identityPath;evidence_sha256=(Get-StartupSha256 $identityPath)} | Out-Null

        Set-Stage 'M4'
        $endpointPath = Join-Path $evidence 'endpoint-bound.json'
        $deadline = [DateTimeOffset]::UtcNow.AddSeconds((Get-McpStartupSpec 'M4').timeout_seconds)
        $listeners = @()
        while ([DateTimeOffset]::UtcNow -lt $deadline) {
            if ($null -eq (Get-Process -Id $godotPid -ErrorAction SilentlyContinue)) { throw 'Godot exited before endpoint bind.' }
            $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
            if ($listeners.Count -gt 0) { break }
            Start-Sleep -Milliseconds 250
        }
        if ($listeners.Count -eq 0) { throw 'MCP endpoint did not bind before M4 timeout.' }
        $endpointEvidence = [ordered]@{schema='McpStartupEndpointBoundV1';run_id=$RunId;port=$Port;observed_utc=[DateTimeOffset]::UtcNow.ToString('o');listeners=@($listeners|ForEach-Object{[ordered]@{local_address=[string]$_.LocalAddress;local_port=[int]$_.LocalPort;owner_pid=[int]$_.OwningProcess}});godot_pid=$godotPid}
        Write-StartupImmutableJson -Path $endpointPath -Value $endpointEvidence -WriteSha256Sidecar | Out-Null
        Save-Pass -MilestoneId 'M4' -Started $stageStarted -Extra @{endpoint_owner_pid=if($listeners.Count -eq 1){[int]$listeners[0].OwningProcess}else{$null};port_bound=$true;evidence_path=$endpointPath;evidence_sha256=(Get-StartupSha256 $endpointPath)} | Out-Null

        Set-Stage 'M5'
        $samplingContract = Get-Pr90M5PassiveSamplingContractV1
        if (-not [bool]$samplingContract.sampling_budget_sufficient -or -not [bool]$samplingContract.short_time_bounded) {
            throw 'Endpoint Ownership V2 sampling budget is not sufficient and bounded.'
        }
        $wrapperIdentity = Read-EndpointListenerOwnerIdentityV1 -PidValue $godotPid
        if (-not [bool]$wrapperIdentity.identity_read_green) { throw 'Console wrapper identity could not be read for Endpoint Ownership V2.' }
        $samples = [Collections.Generic.List[object]]::new()
        $samplingStartedUtc = [DateTimeOffset]::UtcNow
        $samplingDeadline = $samplingStartedUtc.AddMilliseconds([int]$samplingContract.sampling_budget_ms)
        $sampleIndex = 0
        do {
            $sampleIndex += 1
            $sampleObservedUtc = [DateTimeOffset]::UtcNow
            $sampleId = 'm5-v2-{0:d2}' -f $sampleIndex
            $sourceA = Invoke-GetNetTcpListenerObservationV1 -Ports @($Port) -SampleId $sampleId
            $sourceB = Invoke-NetstatTcpListenerObservationV1 -Ports @($Port) -SampleId $sampleId
            $pids = @(@($sourceA.records) + @($sourceB.records) | ForEach-Object { [int]$_.owning_pid } | Sort-Object -Unique)
            $identityByPid = @{}
            foreach ($pidValue in $pids) {
                $identityByPid[$pidValue.ToString([Globalization.CultureInfo]::InvariantCulture)] = Read-EndpointListenerOwnerIdentityV1 -PidValue $pidValue
            }
            $sample = New-Pr90McpEndpointOwnershipSampleV2 `
                -SourceA $sourceA -SourceB $sourceB -IdentityByPid $identityByPid `
                -ConsoleWrapperIdentity $wrapperIdentity -LauncherPid ([int]$launch.launcher_pid) `
                -ExpectedFixtureRoot $root -GodotConsolePath $GodotPath `
                -LaunchEpochUtc ([DateTimeOffset]::Parse($processStartUtc)) -Port $Port -ObservedUtc $sampleObservedUtc
            $samples.Add($sample)
            if ($samples.Count -ge [int]$samplingContract.required_total_sample_count) {
                $endpointOwnershipV2 = Test-Pr90McpEndpointOwnershipV2 -Samples @($samples) -SamplingContract $samplingContract
                if ([bool]$endpointOwnershipV2.green) { break }
            }
            Start-Sleep -Milliseconds ([int]$samplingContract.sample_interval_ms)
        } while ([DateTimeOffset]::UtcNow -lt $samplingDeadline)

        $endpointOwnershipV2 = Test-Pr90McpEndpointOwnershipV2 -Samples @($samples) -SamplingContract $samplingContract
        $samplesPath = Join-Path $evidence 'endpoint-ownership-v2-samples.json'
        $samplesEvidence = [ordered]@{
            schema='SpaceSyndicatePr90McpEndpointOwnershipSamplesV2'; run_id=$RunId; probe_identity=$ProbeIdentity;
            sampling_started_utc=$samplingStartedUtc.ToString('o'); sampling_deadline_utc=$samplingDeadline.ToString('o');
            sampling_contract=$samplingContract; sample_count=$samples.Count; samples=@($samples)
        }
        Write-StartupImmutableJson -Path $samplesPath -Value $samplesEvidence -WriteSha256Sidecar | Out-Null
        $ownerAttestationPath = Join-Path $evidence 'endpoint-ownership-v2-attestation.json'
        Write-StartupImmutableJson -Path $ownerAttestationPath -Value $endpointOwnershipV2 -WriteSha256Sidecar | Out-Null
        if ($null -ne $endpointOwnershipV2.endpoint_owner_pid) {
            $endpointOwnerPid = [int]$endpointOwnershipV2.endpoint_owner_pid
            $endpointOwnerIdentity = $endpointOwnershipV2.endpoint_owner_identity
        }
        if (-not [bool]$endpointOwnershipV2.green) {
            throw "Endpoint Ownership V2 failed: $([string]$endpointOwnershipV2.failure_class)"
        }
        $contextBase.endpoint_owner_pid = $endpointOwnerPid
        $contextBase.endpoint_owner_process_role = 'GUI_ENGINE'
        if (Test-Path -LiteralPath $connectionPath) { throw 'Connection metadata unexpectedly pre-existed before M5.' }
        $connection = [ordered]@{
            schema='McpStartupConnectionV2'; role='A'; endpoint="http://127.0.0.1:$Port/"; port=$Port; pid=$godotPid; control_process_pid=$godotPid; worktree=$root; godot_path=(Resolve-Path -LiteralPath $GodotPath).Path;
            process_start_time_utc=$processStartUtc; command_line=[string]$processRow.CommandLine; endpoint_ownership_contract_version=2; endpoint_owner_pid=$endpointOwnerPid;
            endpoint_owner_process_role='GUI_ENGINE'; endpoint_owner_executable_path=[string]$endpointOwnerIdentity.executable_path; endpoint_owner_command_line=[string]$endpointOwnerIdentity.command_line;
            endpoint_owner_creation_time_utc=[string]$endpointOwnerIdentity.creation_time_utc; endpoint_owner_creation_time_filetime_utc=[string]$endpointOwnerIdentity.creation_time_filetime_utc;
            endpoint_owner_parent_pid=[int]$endpointOwnerIdentity.parent_pid; endpoint_owner_windows_session_id=[int]$endpointOwnerIdentity.windows_session_id; endpoint_owner_user_sid=[string]$endpointOwnerIdentity.user_sid;
            launch_session_id=$sessionId; launch_session_id_source='tooling_generated';
            token_path=(Join-Path $root '.codex-godot/auth.token'); log_path=[string]$launch.log_path; stdout_path=$godotStdoutPath; stderr_path=$godotStderrPath;
            tool_profile='core'; renderer='compatibility'; resolution='1600x960'; created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
        }
        Write-StartupImmutableJson -Path $connectionPath -Value $connection | Out-Null
        Save-Pass -MilestoneId 'M5' -Started $stageStarted -Extra @{
            evidence_path=$ownerAttestationPath; evidence_sha256=(Get-StartupSha256 $ownerAttestationPath); endpoint_owner_pid=$endpointOwnerPid;
            endpoint_owner_process_role='GUI_ENGINE'; endpoint_ownership_contract_version=2; connection_exists=$true;
            connection_path=$connectionPath; connection_sha256=(Get-StartupSha256 $connectionPath);
            total_listener_sample_count=[int]$endpointOwnershipV2.total_listener_sample_count;
            consecutive_parity_sample_count=[int]$endpointOwnershipV2.consecutive_parity_sample_count;
            endpoint_owner_stable_window_ms=[double]$endpointOwnershipV2.endpoint_owner_stable_window_ms
        } | Out-Null

        Set-Stage 'M6'
        $firstEnvelope = New-StateRpcEnvelope -Id 1 -ToolName 'get_project_info' -Arguments @{}
        $firstRequestPath = Join-Path $evidence 'requests/0001-get_project_info.json'
        Write-StartupImmutableJson -Path $firstRequestPath -Value $firstEnvelope -WriteSha256Sidecar | Out-Null
        $firstTx = Start-StateRpcTransaction -Envelope $firstEnvelope -Endpoint "http://127.0.0.1:$Port/" -Token ([IO.File]::ReadAllText((Join-Path $root '.codex-godot/auth.token')).Trim()) -LaunchSessionId $sessionId -Port $Port -TimeoutSeconds 15
        Save-Pass -MilestoneId 'M6' -Started $stageStarted -Extra @{request_id=1;evidence_path=$firstRequestPath;evidence_sha256=(Get-StartupSha256 $firstRequestPath)} | Out-Null

        Set-Stage 'M7'
        $firstResponse = $null
        try { $firstResponse = Complete-StateRpcTransaction -Transaction $firstTx -TimeoutSeconds 30 } catch { throw }
        $responseMetaPath = Join-Path $evidence 'responses/0001-get_project_info.response.json'
        $responseMeta = [ordered]@{schema='McpStartupResponseReceiptV1';request_id=1;status_code=$firstResponse.status_code;body_bytes=$firstResponse.body_bytes.Length;body_sha256=$firstResponse.body_sha256;received_utc=$firstResponse.received_utc}
        Write-StartupImmutableJson -Path $responseMetaPath -Value $responseMeta -WriteSha256Sidecar | Out-Null
        $firstJson = ConvertFrom-StateRpcResponse -BodyBytes $firstResponse.body_bytes
        $firstIdProperty = Get-StatePropertyDescriptor -InputObject $firstJson -Name 'id'
        if (-not [bool]$firstIdProperty.exists -or [int]$firstIdProperty.value -ne 1) { throw 'First JSON-RPC response ID mismatch.' }
        Save-Pass -MilestoneId 'M7' -Started $stageStarted -Extra @{response_id=1;evidence_path=$responseMetaPath;evidence_sha256=(Get-StartupSha256 $responseMetaPath)} | Out-Null

        Set-Stage 'M8'
        $m8RawPath = Join-Path $evidence 'mcp-raw/0001-get_project_info.jsonrpc.json'
        Write-StartupImmutableBytes -Path $m8RawPath -Bytes $firstResponse.body_bytes -WriteSha256Sidecar | Out-Null
        $m8RawSha = Get-StartupSha256 -Path $m8RawPath
        Save-Pass -MilestoneId 'M8' -Started $stageStarted -Extra @{request_id=1;response_id=1;evidence_path=$m8RawPath;evidence_sha256=$m8RawSha} | Out-Null
        Assert-StateRpcToolResponse -Json $firstJson -ToolName 'get_project_info' | Out-Null

        Set-Stage 'M9'
        $m9Deadline = [DateTimeOffset]::UtcNow.AddSeconds((Get-McpStartupSpec 'M9').timeout_seconds)
        $enterPlayModeAttempted = $true
        $enter = Invoke-RecordedRpc -ToolName 'enter_play_mode' -Arguments @{mode='custom';scene_path=$ProbeScenePath} -TimeoutSeconds ([Math]::Max(1,[int]($m9Deadline - [DateTimeOffset]::UtcNow).TotalSeconds))
        $enteredPlayMode = $true
        $m9RemainingBudgetMs = [int][Math]::Floor(($m9Deadline - [DateTimeOffset]::UtcNow).TotalMilliseconds)
        $m9BootstrapBudget = New-StateRuntimeBridgeBootstrapBudgetV1 -TotalStageBudgetMs ([Math]::Max(1,$m9RemainingBudgetMs))
        if (-not [bool]$m9BootstrapBudget.sufficient) { throw 'M9 budget is insufficient for bounded heartbeat polling and runtime stream bootstrap.' }
        $runtimeBridgeReadyDeadline = [DateTimeOffset]::UtcNow.AddMilliseconds([int]$m9BootstrapBudget.ready_poll_budget_ms)
        $runtimeBridgeStatusCall = $null
        $runtimeBridgeStatus = $null
        $runtimeBridgeStatusSummary = Get-StateRuntimeBridgeStatusSummaryV1 -Status $null
        $runtimeBridgeStatusAttemptCount = 0
        while ([DateTimeOffset]::UtcNow -lt $runtimeBridgeReadyDeadline) {
            $statusRpcTimeoutSeconds = [Math]::Min(5,[Math]::Max(1,[int][Math]::Ceiling(($runtimeBridgeReadyDeadline - [DateTimeOffset]::UtcNow).TotalSeconds)))
            $runtimeBridgeStatusCall = Invoke-RecordedRpc -ToolName 'get_runtime_bridge_status' -Arguments @{} -TimeoutSeconds $statusRpcTimeoutSeconds
            $runtimeBridgeStatus = Get-StateRpcStructuredContent -Json $runtimeBridgeStatusCall.json -ToolName 'get_runtime_bridge_status'
            $runtimeBridgeStatusSummary = Get-StateRuntimeBridgeStatusSummaryV1 -Status $runtimeBridgeStatus
            $runtimeBridgeStatusAttemptCount += 1
            if ([bool]$runtimeBridgeStatusSummary.ready) { break }
            $sleepMs = [Math]::Min([int]$m9BootstrapBudget.status_poll_interval_ms,[Math]::Max(0,[int][Math]::Floor(($runtimeBridgeReadyDeadline - [DateTimeOffset]::UtcNow).TotalMilliseconds)))
            if ($sleepMs -gt 0) { Start-Sleep -Milliseconds $sleepMs }
        }
        if (-not [bool]$runtimeBridgeStatusSummary.ready) { throw 'Runtime bridge did not publish a fresh heartbeat before the bounded M9 readiness deadline.' }
        $runtimeBridgeStatusPath = Join-Path $evidence 'witnesses/runtime-bridge-ready-status.json'
        $runtimeBridgeStatusWitness = [ordered]@{
            schema='McpStartupRuntimeBridgeReadyStatusWitnessV1';run_id=$RunId;attempt_count=$runtimeBridgeStatusAttemptCount;
            ready_status=$runtimeBridgeStatusSummary;status_raw_path=$runtimeBridgeStatusCall.raw;status_raw_sha256=$runtimeBridgeStatusCall.raw_sha256;
            budget=$m9BootstrapBudget;observed_utc=[DateTimeOffset]::UtcNow.ToString('o')
        }
        Write-StartupImmutableJson -Path $runtimeBridgeStatusPath -Value $runtimeBridgeStatusWitness -WriteSha256Sidecar | Out-Null
        $bootstrapAvailableMs = [int][Math]::Floor(($m9Deadline - [DateTimeOffset]::UtcNow).TotalMilliseconds) - [int]$m9BootstrapBudget.completion_margin_ms
        $bootstrapTimeoutMs = [Math]::Min([int]$m9BootstrapBudget.bootstrap_timeout_ms,[Math]::Max(100,$bootstrapAvailableMs))
        if ($bootstrapAvailableMs -lt 100) { throw 'M9 timeout expired before runtime stream bootstrap request.' }
        $bootstrapRpcTimeoutSeconds = [Math]::Max(1,[int][Math]::Ceiling(($bootstrapTimeoutMs + 1000) / 1000.0))
        $bootstrap = Invoke-RecordedRpc -ToolName 'get_runtime_events' -Arguments @{max_events=100;timeout_msec=$bootstrapTimeoutMs} -TimeoutSeconds $bootstrapRpcTimeoutSeconds
        $bootstrapResult = Get-StateRpcResult -Json $bootstrap.json
        if ([string]::IsNullOrWhiteSpace([string]$bootstrapResult.stream_id) -or [string]$bootstrapResult.event_sequence_mode -cne 'snapshot_only') { throw 'Runtime stream bootstrap contract failed.' }
        $streamId = [string]$bootstrapResult.stream_id
        $m9RawPath = $bootstrap.raw; $m9RawSha = $bootstrap.raw_sha256
        $streamPath = Join-Path $evidence 'witnesses/runtime-stream-bootstrap.json'
        $streamWitness = [ordered]@{schema='McpStartupRuntimeStreamWitnessV1';run_id=$RunId;stream_id=$streamId;event_sequence_mode=[string]$bootstrapResult.event_sequence_mode;runtime_bridge_ready_status_path=$runtimeBridgeStatusPath;runtime_bridge_ready_status_sha256=(Get-StartupSha256 $runtimeBridgeStatusPath);bootstrap_raw_path=$bootstrap.raw;bootstrap_raw_sha256=$bootstrap.raw_sha256}
        Write-StartupImmutableJson -Path $streamPath -Value $streamWitness -WriteSha256Sidecar | Out-Null
        Save-Pass -MilestoneId 'M9' -Started $stageStarted -Extra @{request_id=$bootstrap.id;response_id=$bootstrap.id;stream_id=$streamId;evidence_path=$streamPath;evidence_sha256=(Get-StartupSha256 $streamPath)} | Out-Null

        Set-Stage 'M10'
        $m10Deadline = [DateTimeOffset]::UtcNow.AddSeconds((Get-McpStartupSpec 'M10').timeout_seconds)
        $readyEvents = @(); $strictResult = $null; $strict = $null
        while ([DateTimeOffset]::UtcNow -lt $m10Deadline) {
            $strict = Invoke-RecordedRpc -ToolName 'get_runtime_events' -Arguments @{max_events=100;timeout_msec=10000;stream_id=$streamId;since_sequence=0} -TimeoutSeconds ([Math]::Min(10,[Math]::Max(1,[int]($m10Deadline - [DateTimeOffset]::UtcNow).TotalSeconds)))
        $strictResult = Get-StateRpcResult -Json $strict.json
            $readyEvents = @($strictResult.events | Where-Object { [string]$_.kind -ceq 'ready' -and [string]$_.message -ceq 'Runtime bridge ready.' })
            if ($readyEvents.Count -gt 0 -and [bool]$strictResult.event_sequence_complete -and [string]$strictResult.continuity_status -ceq 'CONTIGUOUS') { break }
            Start-Sleep -Milliseconds 250
        }
        if ($readyEvents.Count -lt 1) { throw 'Runtime ready witness did not arrive before M10 timeout.' }
        if (@($strictResult.events).Count -gt 0) { $cursor = [int64]$strictResult.events[-1].event_sequence }
        $m10ReadyPath = Join-Path $evidence 'witnesses/ready-witness.json'
        $readyWitness = [ordered]@{schema='McpStartupReadyWitnessV1';run_id=$RunId;stream_id=$streamId;request_id=$strict.id;response_id=$strict.id;ready_witness_count=$readyEvents.Count;event_sequence_complete=[bool]$strictResult.event_sequence_complete;continuity_status=[string]$strictResult.continuity_status;events=$readyEvents;raw_path=$strict.raw;raw_sha256=$strict.raw_sha256}
        Write-StartupImmutableJson -Path $m10ReadyPath -Value $readyWitness -WriteSha256Sidecar | Out-Null
        $m10ReadySha = Get-StartupSha256 -Path $m10ReadyPath
        Save-Pass -MilestoneId 'M10' -Started $stageStarted -Extra @{request_id=$strict.id;response_id=$strict.id;stream_id=$streamId;evidence_path=$m10ReadyPath;evidence_sha256=$m10ReadySha} | Out-Null

        Set-Stage 'M11'
        $phasePath = Join-Path $evidence 'phases/000-phase-0-ready.json'
        $phase = [ordered]@{schema='SpaceSyndicateCursorPhaseWitnessV4';run_id=$RunId;phase='phase-0-ready';stream_id=$streamId;event_count=@($strictResult.events).Count;event_sequence_complete=[bool]$strictResult.event_sequence_complete;continuity_status=[string]$strictResult.continuity_status;events=@($strictResult.events);m8_raw_path=$m8RawPath;m8_raw_sha256=$m8RawSha;m9_stream_raw_path=$m9RawPath;m9_stream_raw_sha256=$m9RawSha;m10_ready_path=$m10ReadyPath;m10_ready_sha256=$m10ReadySha}
        Write-StartupImmutableJson -Path $phasePath -Value $phase -WriteSha256Sidecar | Out-Null
        Save-Pass -MilestoneId 'M11' -Started $stageStarted -Extra @{stream_id=$streamId;evidence_path=$phasePath;evidence_sha256=(Get-StartupSha256 $phasePath)} | Out-Null
    } catch {
        $primaryFailure = $_
        try { Save-Failure -MilestoneId $runtime.currentMilestone -Started $runtime.stageStarted -Detail $_.Exception.Message } catch {}
    } finally {
        if (-not $KeepRunningAfterM11 -and $enterPlayModeAttempted -and $godotPid -gt 0) {
            try { Invoke-RecordedRpc -ToolName 'exit_play_mode' -Arguments @{} -TimeoutSeconds 30 | Out-Null } catch {}
            $enteredPlayMode = $false
        }
        if (-not $KeepRunningAfterM11 -and $godotPid -gt 0) {
            $ownerCreationFiletime = if ($null -ne $endpointOwnerIdentity) { [string]$endpointOwnerIdentity.creation_time_filetime_utc } else { '' }
            $ownerSessionId = if ($null -ne $endpointOwnerIdentity) { [int]$endpointOwnerIdentity.windows_session_id } else { 0 }
            $ownerUserSid = if ($null -ne $endpointOwnerIdentity) { [string]$endpointOwnerIdentity.user_sid } else { '' }
            try {
                $cleanupResult = Stop-StateGodot -Pid $godotPid -ProcessStartUtc $processStartUtc -GodotPath $GodotPath -Worktree $root -Port $Port `
                    -StopScriptPath $StopScriptPath -EndpointOwnerPid $endpointOwnerPid -EndpointOwnerCreationFiletimeUtc $ownerCreationFiletime `
                    -EndpointOwnerSessionId $ownerSessionId -EndpointOwnerUserSid $ownerUserSid
                $cleanStop = [bool]$cleanupResult.stopped
            } catch { $cleanStop = $false }
        }
        if (-not $KeepRunningAfterM11 -and $null -ne $watchdogChild) {
            try {
                if (-not (Test-Path -LiteralPath (Join-Path $evidence 'watchdog/stop.signal'))) {
                    Write-StateAtomicText -Path (Join-Path $evidence 'watchdog/stop.signal') -Text 'stop' -Immutable
                }
                $watchdogSummary = Complete-StartupChildProcess -Child $watchdogChild -TimeoutSeconds 15 -KillOnTimeout
                $watchdogStopped = $watchdogSummary.exited
            } catch { $watchdogStopped = $false }
        }
    }
    $allReceipts = @(Read-McpStartupMilestones -EvidenceRoot $evidence)
    $failureReceipts = @($allReceipts | Where-Object { [string]$_.status -ceq 'FAIL' })
    $firstFailureClass = if ($failureReceipts.Count -gt 0) { [string]$failureReceipts[-1].failure_class } else { '' }
    $sequence = Test-McpStartupReceiptSequence -Receipts $allReceipts -RequireComplete
    $watchdogSummaryPath = Join-Path $evidence 'watchdog/watchdog-summary.json'
    $watchdogSummary = if (Test-Path -LiteralPath $watchdogSummaryPath) { Get-Content -Raw -LiteralPath $watchdogSummaryPath | ConvertFrom-Json -Depth 50 } else { $null }
    $rawFiles = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'mcp-raw') -File -ErrorAction SilentlyContinue)
    $phaseFiles = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'phases') -File -ErrorAction SilentlyContinue)
    $m6ToM11Receipts = @($allReceipts | Where-Object { [string]$_.milestone_id -match '^M(?:6|7|8|9|10|11)$' -and [string]$_.status -ceq 'PASS' })
    $result = [pscustomobject][ordered]@{
        schema='McpStartupStateMachineResultV1';run_id=$RunId;probe_identity=$ProbeIdentity;execution_mode=$ExecutionMode;status=if($null -eq $primaryFailure -and $sequence.complete -and ($KeepRunningAfterM11 -or ($cleanStop -and -not[bool]$cleanupResult.forced_stop)) -and ($KeepRunningAfterM11 -or $null -ne $watchdogSummary)){'PASS'}else{'BLOCKED'};
        product_head_sha=$ExpectedHeadSha;product_tree_sha=$ExpectedTreeSha;launch_session_id=$sessionId;launch_session_id_source='tooling_generated';stream_id=$streamId;cursor_after=$cursor;
        milestone_count=$sequence.receipt_count;milestone_expected_count=12;startup_milestone_order_green=[bool]$sequence.green;startup_milestone_complete=[bool]$sequence.complete;startup_milestone_duplicate_count=[int]$sequence.duplicate_count;startup_milestone_gap_count=[int]$sequence.gap_count;
        mcp_raw_evidence_count=$rawFiles.Count;phase0_evidence_count=$phaseFiles.Count;ready_witness_count=@(Get-ChildItem -LiteralPath (Join-Path $evidence 'witnesses') -Filter '*ready*' -File -ErrorAction SilentlyContinue).Count;mcp_raw_evidence_before_phase_evidence=[bool]$sequence.mcp_raw_before_phase_evidence;
        endpoint_ownership_contract_version=2;prelaunch_protected_port_listener_count=$prelaunchProtectedPortListenerCount;endpoint_owner_pid=if($endpointOwnerPid-gt0){$endpointOwnerPid}else{$null};endpoint_owner_process_role=if($null-ne$endpointOwnershipV2-and[bool]$endpointOwnershipV2.green){'GUI_ENGINE'}else{'UNKNOWN'};
        total_listener_sample_count=if($null-ne$endpointOwnershipV2){[int]$endpointOwnershipV2.total_listener_sample_count}else{0};consecutive_parity_sample_count=if($null-ne$endpointOwnershipV2){[int]$endpointOwnershipV2.consecutive_parity_sample_count}else{0};endpoint_owner_stable_window_ms=if($null-ne$endpointOwnershipV2){[double]$endpointOwnershipV2.endpoint_owner_stable_window_ms}else{0};
        endpoint_listener_observer_source_count=2;endpoint_listener_observer_parity=if($null-ne$endpointOwnershipV2){[bool]$endpointOwnershipV2.endpoint_listener_observer_parity}else{$false};endpoint_listener_a_only_count=if($null-ne$endpointOwnershipV2){[int]$endpointOwnershipV2.endpoint_listener_a_only_count}else{0};endpoint_listener_b_only_count=if($null-ne$endpointOwnershipV2){[int]$endpointOwnershipV2.endpoint_listener_b_only_count}else{0};
        endpoint_owner_is_gui_engine=if($null-ne$endpointOwnershipV2){[bool]$endpointOwnershipV2.endpoint_owner_is_gui_engine}else{$false};endpoint_owner_is_console_wrapper=if($null-ne$endpointOwnershipV2){[bool]$endpointOwnershipV2.endpoint_owner_is_console_wrapper}else{$false};endpoint_owner_is_descendant_of_launcher=if($null-ne$endpointOwnershipV2){[bool]$endpointOwnershipV2.endpoint_owner_is_descendant_of_launcher}else{$false};endpoint_owner_command_line_fixture_match=if($null-ne$endpointOwnershipV2){[bool]$endpointOwnershipV2.endpoint_owner_command_line_fixture_match}else{$false};endpoint_owner_windows_session_match=if($null-ne$endpointOwnershipV2){[bool]$endpointOwnershipV2.endpoint_owner_windows_session_match}else{$false};endpoint_owner_user_sid_match=if($null-ne$endpointOwnershipV2){[bool]$endpointOwnershipV2.endpoint_owner_user_sid_match}else{$false};
        endpoint_owner_pid_changed_count=if($null-ne$endpointOwnershipV2){[int]$endpointOwnershipV2.endpoint_owner_pid_changed_count}else{0};endpoint_owner_creation_identity_changed_count=if($null-ne$endpointOwnershipV2){[int]$endpointOwnershipV2.endpoint_owner_creation_identity_changed_count}else{0};endpoint_owner_process_lineage_changed_count=if($null-ne$endpointOwnershipV2){[int]$endpointOwnershipV2.endpoint_owner_process_lineage_changed_count}else{0};multiple_active_endpoint_owner_count=if($null-ne$endpointOwnershipV2){[int]$endpointOwnershipV2.multiple_active_endpoint_owner_count}else{0};
        first_jsonrpc_request_sent=@($allReceipts|Where-Object{[string]$_.milestone_id-ceq'M6'-and[string]$_.status-ceq'PASS'}).Count-eq1;first_jsonrpc_response_received=@($allReceipts|Where-Object{[string]$_.milestone_id-ceq'M7'-and[string]$_.status-ceq'PASS'}).Count-eq1;m6_to_m11_execution_count=$m6ToM11Receipts.Count;
        play_main_scene_count=0;product_match_count=0;formal_authorization_consumed=$false;formal_mcp_execution_count=0;authorized_run_count_consumed=0;
        watchdog_started_before_godot_process=if($null-ne$watchdogSummary){[bool]$watchdogSummary.started_before_godot_process}else{$false};watchdog_observation_gap_count=if($null-ne$watchdogSummary){[int]$watchdogSummary.observation_gap_count}else{-1};watchdog_open_handle_count_after=if($null-ne$watchdogSummary){[int]$watchdogSummary.open_handle_count_after}else{-1};watchdog_status=if($null-ne$watchdogSummary){[string]$watchdogSummary.status}else{if($KeepRunningAfterM11){'RUNNING'}else{'MISSING'}};
        stops_cleanly=$cleanStop;forced_stop=[bool]$cleanupResult.forced_stop;forced_stop_process_ids=@($cleanupResult.forced_stop_process_ids);cleanup_normal_close_requests=@($cleanupResult.normal_close_requests);cleanup_runtime_child_count=[int]$cleanupResult.runtime_child_count;cleanup_process_count_after=[int]$cleanupResult.process_count_after;cleanup_endpoint_count_after=[int]$cleanupResult.endpoint_count_after;unrelated_process_termination_count=[int]$cleanupResult.unrelated_process_termination_count;stop_pending=[bool]$KeepRunningAfterM11;opaque_startup_wait_count=0;startup_timeout_exact_stage_reported=$true;first_failure_class=$firstFailureClass;failure_detail=if($null-ne$primaryFailure){$primaryFailure.Exception.Message}else{''};evidence_root=$evidence;canonical_payload_sha256=''
    }
    $result.canonical_payload_sha256 = Get-StartupCanonicalSha256 -Value $result
    $summaryPath = Join-Path $evidence 'startup-state-machine-result.json'
    if (-not (Test-Path -LiteralPath $summaryPath)) { Write-StartupImmutableJson -Path $summaryPath -Value $result -WriteSha256Sidecar | Out-Null }
    return [pscustomobject]@{summary=$result;godot_pid=$godotPid;endpoint_owner_pid=$endpointOwnerPid;process_start_utc=$processStartUtc;launch_session_id=$sessionId;stream_id=$streamId;cursor_after=$cursor;watchdog_child=$watchdogChild;watchdog_stop_path=(Join-Path $evidence 'watchdog/stop.signal');entered_play_mode=$enteredPlayMode;clean_stop=$cleanStop;cleanup_result=$cleanupResult;primary_failure=$primaryFailure}
}

function Stop-Pr90McpStartupWatchdog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [ValidateRange(1,120)][int]$TimeoutSeconds = 15
    )
    if ($null -eq $State.watchdog_child) { return $false }
    try {
        if (-not (Test-Path -LiteralPath $State.watchdog_stop_path)) {
            Write-StateAtomicText -Path $State.watchdog_stop_path -Text 'stop' -Immutable
        }
        $summary = Complete-StartupChildProcess -Child $State.watchdog_child -TimeoutSeconds $TimeoutSeconds -KillOnTimeout
        return [bool]$summary.exited
    } catch { return $false }
}

Export-ModuleMember -Function @('Invoke-Pr90McpStartupStateMachine','Stop-Pr90McpStartupWatchdog')
