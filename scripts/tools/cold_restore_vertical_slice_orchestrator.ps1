[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,
    [string]$GodotPath = "godot",
    [string]$RunId = "alpha04c-cold-restore",
    [switch]$EnableColdRestoreExecution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$FORMAL_FULL_RUN = $false
$DriverExecutionReady = $false
$DriverScript = "res://scripts/tools/cold_restore_vertical_slice_driver.gd"
$ArtifactRoot = "user://test_runs/alpha04c/$RunId/evidence"

if (-not $EnableColdRestoreExecution) {
    [pscustomobject]@{
        driver = "alpha04c_cold_restore_vertical_slice_v1"
        formal_full_run = $FORMAL_FULL_RUN
        execution_ready = $DriverExecutionReady
        process_sequence = @("producer_exit", "consumer_start", "orchestrator_compare")
        artifact_root = $ArtifactRoot
    } | ConvertTo-Json -Compress
    exit 0
}

if (-not $DriverExecutionReady) {
    throw "Cold restore execution is fail-closed until the production high-level gateway and 19-owner restore barrier are integrated."
}

function Invoke-ColdRestoreRole {
    param([Parameter(Mandatory = $true)][ValidateSet("producer", "consumer")][string]$Role)
    $arguments = @(
        "--headless",
        "--path", $ProjectPath,
        "--script", $DriverScript,
        "--",
        "--cold-restore-role=$Role",
        "--cold-restore-run-id=$RunId",
        "--cold-restore-artifact-root=$ArtifactRoot"
    )
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden
    if ($process.ExitCode -ne 0) {
        throw "Cold restore $Role process failed with exit code $($process.ExitCode)."
    }
    return $process.Id
}

$producerProcessId = Invoke-ColdRestoreRole -Role "producer"
# Process B is started only after Start-Process -Wait proves Process A exited.
$consumerProcessId = Invoke-ColdRestoreRole -Role "consumer"
if ($producerProcessId -eq $consumerProcessId) {
    throw "Producer and consumer must be distinct operating-system processes."
}

# Process C is this orchestrator: compare only allowlisted producer/consumer
# manifests after both gameplay processes exit. Raw save envelopes are forbidden.
[pscustomobject]@{
    formal_full_run = $FORMAL_FULL_RUN
    producer_process_id = $producerProcessId
    consumer_process_id = $consumerProcessId
    comparison_scope = "qa_allowlisted_manifests_only"
} | ConvertTo-Json -Compress
