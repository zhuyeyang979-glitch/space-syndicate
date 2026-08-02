param(
    [string]$Worktree = (Get-Location).Path,
    [int]$OperationTimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd("\")
$localRoot = Join-Path $root ".codex-godot"
$connectionPath = Join-Path $localRoot "connection.json"
$tokenPath = Join-Path $localRoot "auth.token"
if (-not (Test-Path -LiteralPath $connectionPath)) {
    throw "Missing role-local MCP connection metadata: $connectionPath"
}
if (-not (Test-Path -LiteralPath $tokenPath)) {
    throw "Missing role-local MCP token: $tokenPath"
}

$connection = Get-Content -Raw -LiteralPath $connectionPath | ConvertFrom-Json
$token = [System.IO.File]::ReadAllText($tokenPath).Trim()
$headers = @{
    "X-Funplay-MCP-Token" = $token
    "MCP-Protocol-Version" = "2025-11-25"
}
$editorPidBefore = [int]$connection.pid

function Invoke-McpTool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [hashtable]$Arguments = @{}
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
    $requestParameters = @{
        Uri = [string]$connection.endpoint
        Method = "Post"
        Headers = $headers
        ContentType = "application/json"
        Body = $body
        TimeoutSec = 10
    }
    try {
        $response = Invoke-RestMethod @requestParameters
    } catch {
        $editorProcess = Get-Process -Id $editorPidBefore -ErrorAction SilentlyContinue
        if ($editorProcess -eq $null -or $editorProcess.HasExited) {
            throw "MCP_EDITOR_PROCESS_EXITED|pid=$editorPidBefore|endpoint=$($connection.endpoint)"
        }
        throw
    }
    if ($response.error -ne $null) {
        throw ($response.error | ConvertTo-Json -Depth 10 -Compress)
    }
    if ($response.result.structuredContent -ne $null) {
        return $response.result.structuredContent
    }
    return ($response.result.content[0].text | ConvertFrom-Json)
}

function Wait-McpOperation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationId
    )
    $deadline = (Get-Date).AddSeconds($OperationTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $status = Invoke-McpTool -Name "filesystem_scan_status" -Arguments @{
            operation_id = $OperationId
        }
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

$requestId1 = "alpha04c-mcp-rescan-self-test-operation-1"
$operation1Request = Invoke-McpTool -Name "request_script_reload" -Arguments @{
    request_id = $requestId1
}
$operation1Id = [string]$operation1Request.operation_id
$operation1Status = Wait-McpOperation -OperationId $operation1Id

$duplicateRequest = Invoke-McpTool -Name "request_script_reload" -Arguments @{
    request_id = $requestId1
}
if ([string]$duplicateRequest.operation_id -ne $operation1Id) {
    throw "MCP_DUPLICATE_REQUEST_OPERATION_MISMATCH"
}
if (-not [bool]$duplicateRequest.duplicate_request) {
    throw "MCP_DUPLICATE_REQUEST_NOT_ATTESTED"
}

$requestId2 = "alpha04c-mcp-rescan-self-test-operation-2"
$operation2Request = Invoke-McpTool -Name "request_script_reload" -Arguments @{
    request_id = $requestId2
}
$operation2Id = [string]$operation2Request.operation_id
$operation2Status = Wait-McpOperation -OperationId $operation2Id

$finalStatus = Invoke-McpTool -Name "filesystem_scan_status"
$healthParameters = @{
    Uri = [string]$connection.endpoint
    Method = "Get"
    Headers = $headers
    TimeoutSec = 10
}
$health = Invoke-RestMethod @healthParameters
$editorProcessAfter = Get-Process -Id $editorPidBefore -ErrorAction SilentlyContinue
$transport = $health.transport_diagnostics

$failures = @()
if ($editorProcessAfter -eq $null -or $editorProcessAfter.HasExited) {
    $failures += "editor_pid_not_stable"
}
if ([string]$finalStatus.state -ne "ready") {
    $failures += "filesystem_not_ready_after_reload"
}
if ([int]$finalStatus.active_scan_count_max -gt 1) {
    $failures += "active_scan_count_exceeded_one"
}
if ([int]$finalStatus.active_reload_count_max -gt 1) {
    $failures += "active_reload_count_exceeded_one"
}
if ([int]$finalStatus.reload_execution_count -ne 2) {
    $failures += "reload_execution_count_not_two"
}
if ([int]$finalStatus.duplicate_request_count -ne 1) {
    $failures += "duplicate_request_count_not_one"
}
if ([int]$transport.max_handler_depth -gt 1) {
    $failures += "handler_depth_exceeded_one"
}
if ([int]$transport.nested_http_dispatch_count -ne 0) {
    $failures += "nested_http_dispatch_detected"
}
if ([int]$transport.reentrant_handler_entry_count -ne 0) {
    $failures += "reentrant_handler_entry_detected"
}

$result = [ordered]@{
    self_test_green = $failures.Count -eq 0
    endpoint = [string]$connection.endpoint
    editor_pid = $editorPidBefore
    editor_pid_stable = $editorProcessAfter -ne $null -and -not $editorProcessAfter.HasExited
    godot_version = [string]$godotVersion.string
    project_root = [string]$projectInfo.project_root
    initial_scan_green = [bool]$initialStatus.initial_scan_completed
    reload_operation_1_green = [string]$operation1Status.operation.status -eq "completed"
    reload_operation_2_green = [string]$operation2Status.operation.status -eq "completed"
    duplicate_request_execution_count = 0
    duplicate_request_operation_id = [string]$duplicateRequest.operation_id
    filesystem_status = $finalStatus
    transport_diagnostics = $transport
    failures = $failures
}
$result | ConvertTo-Json -Depth 20
if ($failures.Count -gt 0) {
    exit 1
}
