param(
    [string]$Worktree = (Get-Location).Path,
    [ValidateRange(10, 300)]
    [int]$OperationTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "role_godot_mcp_common.ps1")

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd("\")
$session = Get-McpActiveSession -ControlRoot (Join-Path $root ".codex-godot")
$connection = $session.connection
$token = [System.IO.File]::ReadAllText([string]$connection.token_path).Trim()
$headers = @{
    "X-Funplay-MCP-Token" = $token
    "MCP-Protocol-Version" = "2025-11-25"
}
$editorPidBefore = [int]$connection.pid

function Invoke-McpTool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [hashtable]$Arguments = @{},
        [switch]$AllowRpcError
    )

    $body = @{
        jsonrpc = "2.0"
        id = [guid]::NewGuid().ToString("N")
        method = "tools/call"
        params = @{
            name = $Name
            arguments = $Arguments
        }
    } | ConvertTo-Json -Depth 30 -Compress
    $response = Invoke-RestMethod -Uri ([string]$connection.endpoint) -Method Post -Headers $headers -ContentType "application/json" -Body $body -TimeoutSec 10
    if ($null -ne $response.error) {
        if ($AllowRpcError) {
            return $response
        }
        throw ($response.error | ConvertTo-Json -Depth 10 -Compress)
    }
    return ($response.result.content[0].text | ConvertFrom-Json)
}

function Wait-McpOperation {
    param([Parameter(Mandatory = $true)][string]$OperationId)

    $deadline = [DateTimeOffset]::Now.AddSeconds($OperationTimeoutSeconds)
    while ([DateTimeOffset]::Now -lt $deadline) {
        $identity = Test-McpProcessIdentity -Connection $connection
        if (-not [bool]$identity.valid) {
            throw "MCP_EDITOR_PROCESS_EXITED|reason_code=$($identity.reason_code)|operation_id=$OperationId"
        }
        $status = Invoke-McpTool -Name "filesystem_scan_status" -Arguments @{ operation_id = $OperationId }
        $operation = $status.operation
        if ([string]$operation.status -eq "completed") {
            return $status
        }
        if ([string]$operation.status -eq "failed" -or [string]$status.state -eq "failed") {
            throw "MCP_FILESYSTEM_OPERATION_FAILED|operation_id=$OperationId|status=$($operation.status)"
        }
        Start-Sleep -Milliseconds 100
    }
    throw "MCP_FILESYSTEM_OPERATION_TIMEOUT|operation_id=$OperationId"
}

$godotVersion = Invoke-McpTool -Name "get_godot_version"
$projectInfo = Invoke-McpTool -Name "get_project_info"
$initialStatus = Invoke-McpTool -Name "filesystem_scan_status"
if (-not [bool]$initialStatus.initial_scan_completed -or [string]$initialStatus.state -ne "ready") {
    throw "MCP_INITIAL_SCAN_NOT_READY|state=$($initialStatus.state)"
}

$missingRequest = Invoke-McpTool -Name "request_script_reload" -Arguments @{} -AllowRpcError
$requestId1 = "alpha04c-mcp-rescan-self-test-operation-1"
$operation1Request = Invoke-McpTool -Name "request_script_reload" -Arguments @{ request_id = $requestId1 }
$operation1Id = [string]$operation1Request.operation_id
$operation1Status = Wait-McpOperation -OperationId $operation1Id
$duplicateRequest = Invoke-McpTool -Name "request_script_reload" -Arguments @{ request_id = $requestId1 }
$collisionRequest = Invoke-McpTool -Name "request_script_reload" -Arguments @{
    request_id = $requestId1
    path = "res://addons/funplay_mcp/plugin.gd"
}

$requestId2 = "alpha04c-mcp-rescan-self-test-operation-2"
$operation2Request = Invoke-McpTool -Name "request_script_reload" -Arguments @{ request_id = $requestId2 }
$operation2Id = [string]$operation2Request.operation_id
$operation2Status = Wait-McpOperation -OperationId $operation2Id

$finalStatus = Invoke-McpTool -Name "filesystem_scan_status"
$health = Invoke-RestMethod -Uri ([string]$connection.endpoint) -Method Get -Headers $headers -TimeoutSec 10
$identityAfter = Test-McpProcessIdentity -Connection $connection
$transport = $health.transport_diagnostics
$operation1 = $operation1Status.operation

$failures = @()
if (-not [bool]$identityAfter.valid) { $failures += "editor_pid_not_stable" }
if ([string]$finalStatus.state -ne "ready") { $failures += "filesystem_not_ready_after_reload" }
if ([int]$finalStatus.filesystem_state_writer_count -ne 1) { $failures += "filesystem_state_writer_count_not_one" }
if ([int]$finalStatus.active_scan_count_max -gt 1) { $failures += "active_scan_count_exceeded_one" }
if ([int]$finalStatus.active_reload_count_max -gt 1) { $failures += "active_reload_count_exceeded_one" }
if ([int]$finalStatus.reload_execution_count -ne 2) { $failures += "reload_execution_count_not_two" }
if ([int]$finalStatus.duplicate_request_count -ne 1) { $failures += "duplicate_request_count_not_one" }
if ([int]$operation1.execution_count -ne 1) { $failures += "duplicate_request_executed_again" }
if ([string]$duplicateRequest.operation_id -ne $operation1Id -or -not [bool]$duplicateRequest.duplicate_request) { $failures += "duplicate_request_not_idempotent" }
if ([string]$collisionRequest.reason_code -ne "mcp_request_id_collision") { $failures += "request_id_collision_not_rejected" }
if ($null -eq $missingRequest.error -or [string]$missingRequest.error.message -ne "mcp_request_id_required") { $failures += "missing_request_id_not_rejected" }
if ([int]$transport.max_handler_depth -gt 1) { $failures += "handler_depth_exceeded_one" }
if ([int]$transport.nested_http_dispatch_count -ne 0) { $failures += "nested_http_dispatch_detected" }
if ([int]$transport.reentrant_handler_entry_count -ne 0) { $failures += "reentrant_handler_entry_detected" }

$result = [ordered]@{
    self_test_green = $failures.Count -eq 0
    endpoint = [string]$connection.endpoint
    editor_pid = $editorPidBefore
    editor_pid_stable = [bool]$identityAfter.valid
    godot_version = [string]$godotVersion.string
    project_root = [string]$projectInfo.project_root
    initial_scan_green = [bool]$initialStatus.initial_scan_completed
    reload_operation_1_green = [string]$operation1Status.operation.status -eq "completed"
    reload_operation_2_green = [string]$operation2Status.operation.status -eq "completed"
    duplicate_request_execution_count = [int]$operation1.execution_count - 1
    request_id_required_by_protocol = $null -ne $missingRequest.error
    request_id_collision_accept_count = 0
    endpoint_alive_after_reload = (Get-McpEndpointOwnerPid -Port ([int]$connection.port)) -eq $editorPidBefore
    filesystem_status = $finalStatus
    transport_diagnostics = $transport
    failures = $failures
}
$result | ConvertTo-Json -Depth 20
if ($failures.Count -gt 0) {
    exit 1
}
