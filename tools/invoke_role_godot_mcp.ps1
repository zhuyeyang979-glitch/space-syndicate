param(
    [Parameter(Mandatory = $true)]
    [string]$ToolName,

    [string]$ArgumentsJson = "{}",

    [string]$Worktree = (Get-Location).Path,

    [int]$TimeoutSeconds = 60,

    [string]$OutputImage = "",

    [switch]$PassThroughToolErrors,

    [string]$RawResponsePath = "",

    [Parameter(Mandatory = $true)]
    [int]$ExpectedControlProcessId,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedControlProcessStartUtc,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedControlProcessSha256,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedLaunchSessionId,

    [Parameter(Mandatory = $true)]
    [int]$ExpectedPort,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedConnectionSha256,

    [Parameter(Mandatory = $true)]
    [string]$EndpointOwnershipAttestationPath,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedEndpointOwnershipAttestationSha256,

    [Parameter(Mandatory = $true)]
    [int]$ExpectedEndpointOwnerPid,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedEndpointOwnerPath,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedEndpointOwnerSha256,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedEndpointOwnerCreationFiletimeUtc,

    [Parameter(Mandatory = $true)]
    [int]$ExpectedEndpointOwnerSessionId,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedEndpointOwnerUserSid
)

$ErrorActionPreference = "Stop"

$processIdentityModule = Join-Path `
    $PSScriptRoot `
    "role_godot_mcp_process_identity.psm1"
Import-Module -Name $processIdentityModule -Force -ErrorAction Stop
$listenerIdentityModule = Join-Path `
    $PSScriptRoot `
    "pr90_listener_process_identity_reader_v1.psm1"
Import-Module -Name $listenerIdentityModule -Force -ErrorAction Stop
$attempt22ContractModule = Join-Path `
    $PSScriptRoot `
    "pr90_probe_b_attempt22_contract_v1.psm1"
Import-Module -Name $attempt22ContractModule -Force -ErrorAction Stop

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd("\")
$localRoot = Join-Path $root ".codex-godot"
$connectionPath = Join-Path $localRoot "connection.json"
$tokenPath = Join-Path $localRoot "auth.token"

function Test-CommandLineWorktreeBinding {
    param(
        [Parameter(Mandatory = $true)][string]$CommandLine,
        [Parameter(Mandatory = $true)][string]$ExpectedRoot
    )
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    foreach ($rootForm in @($ExpectedRoot, $ExpectedRoot.Replace("\", "/"))) {
        $escapedRoot = [Regex]::Escape($rootForm.TrimEnd("\", "/"))
        $pattern = '(?i)(?:^|\s)--path(?:\s+|=)(?:"' +
            $escapedRoot + '"|' + $escapedRoot + ')(?=\s|$)'
        if ([Regex]::IsMatch($CommandLine, $pattern)) { return $true }
    }
    return $false
}

function Assert-RolePathChainHasNoReparsePoint {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $fullPath = [IO.Path]::GetFullPath($Path)
    foreach ($segment in $fullPath.Split(
        @("\", "/"),
        [StringSplitOptions]::RemoveEmptyEntries
    )) {
        if ($segment -match '~[0-9]+') {
            throw "$Label must not use an 8.3 path alias: $fullPath"
        }
    }
    $cursor = $fullPath.TrimEnd("\", "/")
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 `
                -or -not [string]::IsNullOrWhiteSpace([string]$item.LinkType) `
                -or $null -ne $item.Target) {
                throw "$Label path chain contains a reparse point: $($item.FullName)"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ([string]::IsNullOrWhiteSpace($parent) `
            -or $parent.Equals(
                $cursor,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            break
        }
        $cursor = $parent.TrimEnd("\", "/")
    }
}

Assert-RolePathChainHasNoReparsePoint -Path $root -Label "Role worktree"

if (-not (Test-Path -LiteralPath $connectionPath)) {
    throw "Missing role-local MCP connection metadata: $connectionPath"
}
if (-not (Test-Path -LiteralPath $tokenPath)) {
    throw "Missing role-local MCP token: $tokenPath"
}

$connection = Get-Content -Raw -LiteralPath $connectionPath | ConvertFrom-Json
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $connectionPath).Hash.ToLowerInvariant() -cne $ExpectedConnectionSha256.ToLowerInvariant()) {
    throw "Role-local MCP connection bytes no longer match the M5 receipt."
}
$attestationFullPath = [IO.Path]::GetFullPath($EndpointOwnershipAttestationPath)
if (-not (Test-Path -LiteralPath $attestationFullPath -PathType Leaf) `
    -or (Get-FileHash -Algorithm SHA256 -LiteralPath $attestationFullPath).Hash.ToLowerInvariant() -cne $ExpectedEndpointOwnershipAttestationSha256.ToLowerInvariant()) {
    throw "Role-local MCP endpoint ownership attestation bytes no longer match M5."
}
$endpointOwnershipAttestation = Get-Content -Raw -LiteralPath $attestationFullPath | ConvertFrom-Json -Depth 100
$connectionFields = @($connection.PSObject.Properties.Name)
$requiredConnectionFields = @(
    'schema', 'endpoint', 'port', 'pid', 'control_process_pid', 'worktree',
    'godot_path', 'process_start_time_utc', 'command_line',
    'endpoint_ownership_contract_version', 'endpoint_owner_pid',
    'endpoint_owner_process_role', 'endpoint_owner_executable_path',
    'endpoint_owner_command_line', 'endpoint_owner_creation_time_filetime_utc',
    'endpoint_owner_parent_pid', 'endpoint_owner_windows_session_id',
    'endpoint_owner_user_sid', 'launch_session_id'
)
if (@($requiredConnectionFields | Where-Object { $connectionFields -cnotcontains $_ }).Count -ne 0 `
    -or [string]$connection.schema -cne 'McpStartupConnectionV2' `
    -or [int]$connection.endpoint_ownership_contract_version -ne 2 `
    -or [string]$connection.endpoint_owner_process_role -cne 'GUI_ENGINE' `
    -or [int]$connection.port -ne $ExpectedPort) {
    throw "Role-local MCP connection metadata is not the sealed V2 identity contract."
}
$reportedWorktree = ([string]$connection.worktree).TrimEnd("\")
if (-not $reportedWorktree.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Role-local MCP metadata belongs to another worktree: $reportedWorktree"
}
$rolePid = [int]$connection.pid
if ($ExpectedControlProcessId -le 0 `
    -or $rolePid -ne $ExpectedControlProcessId `
    -or [int]$connection.control_process_pid -ne $ExpectedControlProcessId `
    -or [string]$connection.process_start_time_utc -cne $ExpectedControlProcessStartUtc `
    -or [string]$connection.launch_session_id -cne $ExpectedLaunchSessionId) {
    throw "Role-local MCP control-process identity is not the authorized startup identity."
}
$roleProcess = Get-Process -Id $rolePid -ErrorAction SilentlyContinue
if ($null -eq $roleProcess -or $roleProcess.HasExited) {
    throw "Role-local Godot process is not running: PID $($connection.pid)"
}
try {
    $startIdentityMatches = Test-RoleGodotProcessStartIdentity `
        -ExpectedToken $connection.process_start_time_utc `
        -ActualStartTime $roleProcess.StartTime
} catch {
    throw "Role-local Godot process creation-time token is invalid."
}
if (-not $startIdentityMatches) {
    throw "Role-local Godot PID was reused by another process."
}
$expectedGodotPath = (Resolve-Path -LiteralPath ([string]$connection.godot_path)).Path
if (-not ([string]$roleProcess.Path).Equals(
    $expectedGodotPath,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Role-local Godot executable identity does not match the stored role."
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $expectedGodotPath).Hash.ToLowerInvariant() -cne $ExpectedControlProcessSha256.ToLowerInvariant()) {
    throw "Role-local Godot control executable bytes changed after authorization."
}
$processRow = Get-CimInstance `
    Win32_Process `
    -Filter "ProcessId = $rolePid" `
    -ErrorAction Stop
if ($null -eq $processRow) {
    throw "Role-local Godot process identity could not be enumerated."
}
$commandLine = [string]$processRow.CommandLine
if ($commandLine -cne [string]$connection.command_line `
    -or -not (Test-CommandLineWorktreeBinding -CommandLine $commandLine -ExpectedRoot $root)) {
    throw "Role-local Godot command line is not bound to this worktree."
}
$port = [int]$connection.port
$endpointUri = [Uri]([string]$connection.endpoint)
if (
    $endpointUri.Scheme -cne "http" -or
    $endpointUri.Host -notin @("127.0.0.1", "localhost") -or
    $endpointUri.Port -ne $port
) {
    throw "Role-local MCP endpoint metadata is not the expected local role endpoint."
}
$alternateProtectedPort = if ($ExpectedPort -eq 7576) { 7586 } else { 7576 }
$alternateListeners = @(Get-NetTCPConnection -State Listen -LocalPort $alternateProtectedPort -ErrorAction SilentlyContinue)
if ($alternateListeners.Count -ne 0) {
    throw "The alternate protected MCP port is unexpectedly occupied."
}
$listeners = @(
    Get-NetTCPConnection -State Listen -ErrorAction Stop |
        Where-Object { [int]$_.LocalPort -eq $port }
)
if ($ExpectedEndpointOwnerPid -le 0 `
    -or $ExpectedEndpointOwnerPid -eq $ExpectedControlProcessId `
    -or [int]$connection.endpoint_owner_pid -ne $ExpectedEndpointOwnerPid `
    -or $listeners.Count -ne 1 `
    -or [int]$listeners[0].OwningProcess -ne $ExpectedEndpointOwnerPid) {
    throw "Role-local MCP endpoint is not exclusively owned by the authorized GUI engine."
}
$expectedOwnerPath = (Resolve-Path -LiteralPath $ExpectedEndpointOwnerPath).Path
$ownerIdentity = Read-EndpointListenerOwnerIdentityV1 -PidValue $ExpectedEndpointOwnerPid
if (-not [bool]$ownerIdentity.exists `
    -or -not [bool]$ownerIdentity.identity_read_green `
    -or [int]$ownerIdentity.pid -ne $ExpectedEndpointOwnerPid `
    -or -not ([string]$ownerIdentity.executable_path).Equals($expectedOwnerPath, [StringComparison]::OrdinalIgnoreCase) `
    -or [string]$ownerIdentity.executable_sha256 -cne $ExpectedEndpointOwnerSha256 `
    -or -not ([string]$connection.endpoint_owner_executable_path).Equals($expectedOwnerPath, [StringComparison]::OrdinalIgnoreCase) `
    -or [string]$ownerIdentity.creation_time_filetime_utc -cne $ExpectedEndpointOwnerCreationFiletimeUtc `
    -or [string]$connection.endpoint_owner_creation_time_filetime_utc -cne $ExpectedEndpointOwnerCreationFiletimeUtc `
    -or [int]$ownerIdentity.parent_pid -ne $ExpectedControlProcessId `
    -or [int]$connection.endpoint_owner_parent_pid -ne $ExpectedControlProcessId `
    -or [int]$ownerIdentity.windows_session_id -ne $ExpectedEndpointOwnerSessionId `
    -or [int]$connection.endpoint_owner_windows_session_id -ne $ExpectedEndpointOwnerSessionId `
    -or [string]$ownerIdentity.user_sid -cne $ExpectedEndpointOwnerUserSid `
    -or [string]$connection.endpoint_owner_user_sid -cne $ExpectedEndpointOwnerUserSid `
    -or [string]$ownerIdentity.command_line -cne [string]$connection.endpoint_owner_command_line `
    -or -not (Test-CommandLineWorktreeBinding -CommandLine ([string]$ownerIdentity.command_line) -ExpectedRoot $root)) {
    throw "Role-local MCP GUI owner identity no longer matches the authorized V2 process proof."
}
if ([string]$endpointOwnershipAttestation.schema -cne 'SpaceSyndicatePr90McpEndpointOwnershipBracketedV2Attestation' `
    -or [string]$endpointOwnershipAttestation.status -cne 'PASS' `
    -or -not [bool]$endpointOwnershipAttestation.green `
    -or [int]$endpointOwnershipAttestation.endpoint_ownership_contract_version -ne 2 `
    -or [int]$endpointOwnershipAttestation.endpoint_owner_pid -ne $ExpectedEndpointOwnerPid `
    -or [int]$endpointOwnershipAttestation.endpoint_owner_identity.pid -ne $ExpectedEndpointOwnerPid `
    -or [string]$endpointOwnershipAttestation.endpoint_owner_identity.creation_time_filetime_utc -cne $ExpectedEndpointOwnerCreationFiletimeUtc `
    -or [string]$endpointOwnershipAttestation.endpoint_owner_identity.executable_sha256 -cne $ExpectedEndpointOwnerSha256 `
    -or -not [bool]$endpointOwnershipAttestation.endpoint_owner_is_gui_engine `
    -or [bool]$endpointOwnershipAttestation.endpoint_owner_is_console_wrapper `
    -or -not [bool]$endpointOwnershipAttestation.endpoint_owner_is_descendant_of_launcher `
    -or -not [bool]$endpointOwnershipAttestation.endpoint_owner_project_match `
    -or -not [bool]$endpointOwnershipAttestation.endpoint_owner_mcp_session_match `
    -or -not [bool]$endpointOwnershipAttestation.endpoint_owner_windows_session_match `
    -or -not [bool]$endpointOwnershipAttestation.endpoint_owner_user_sid_match `
    -or -not [bool]$endpointOwnershipAttestation.endpoint_owner_creation_identity_match `
    -or [int]$endpointOwnershipAttestation.foreign_listener_count -ne 0 `
    -or [int]$endpointOwnershipAttestation.multiple_active_endpoint_owner_count -ne 0 `
    -or [int]$endpointOwnershipAttestation.protected_port_multiple_owner_count -ne 0) {
    throw "Role-local MCP endpoint ownership attestation is not the exact V2 PASS identity."
}
$v2IdentityGreen = Test-Pr90McpV2BoundInvocationIdentityV1 `
    -Connection $connection `
    -EndpointOwnerIdentity $ownerIdentity `
    -EndpointOwnershipAttestation $endpointOwnershipAttestation `
    -ListenerOwnerPids @($listeners | ForEach-Object { [int]$_.OwningProcess }) `
    -AlternateProtectedListenerCount $alternateListeners.Count `
    -ExpectedWorktree $root `
    -ExpectedPort $ExpectedPort `
    -ExpectedControlProcessId $ExpectedControlProcessId `
    -ExpectedControlProcessStartUtc $ExpectedControlProcessStartUtc `
    -ExpectedLaunchSessionId $ExpectedLaunchSessionId `
    -ExpectedEndpointOwnerPid $ExpectedEndpointOwnerPid `
    -ExpectedEndpointOwnerPath $expectedOwnerPath `
    -ExpectedEndpointOwnerSha256 $ExpectedEndpointOwnerSha256 `
    -ExpectedEndpointOwnerCreationFiletimeUtc $ExpectedEndpointOwnerCreationFiletimeUtc `
    -ExpectedEndpointOwnerSessionId $ExpectedEndpointOwnerSessionId `
    -ExpectedEndpointOwnerUserSid $ExpectedEndpointOwnerUserSid
if (-not $v2IdentityGreen) {
    throw "Role-local MCP V2 invocation identity contract rejected the live endpoint."
}
$token = [System.IO.File]::ReadAllText($tokenPath).Trim()
$arguments = $ArgumentsJson | ConvertFrom-Json -AsHashtable
$headers = @{
    "X-Funplay-MCP-Token" = $token
    "MCP-Protocol-Version" = "2025-11-25"
}
$body = @{
    jsonrpc = "2.0"
    id = 1
    method = "tools/call"
    params = @{
        name = $ToolName
        arguments = $arguments
    }
} | ConvertTo-Json -Depth 30 -Compress

$httpResponse = Invoke-WebRequest `
    -Uri ([string]$connection.endpoint) `
    -Method Post `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $body `
    -TimeoutSec $TimeoutSeconds `
    -SkipHttpErrorCheck

$rawResponseBytes = if ($null -ne $httpResponse.RawContentStream) {
    $httpResponse.RawContentStream.ToArray()
} else {
    [Text.UTF8Encoding]::new($false).GetBytes([string]$httpResponse.Content)
}
if (-not [string]::IsNullOrWhiteSpace($RawResponsePath)) {
    $rawPath = [IO.Path]::GetFullPath($RawResponsePath)
    Assert-RolePathChainHasNoReparsePoint `
        -Path $rawPath `
        -Label "Raw MCP wire evidence"
    $rootPrefix = $root.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    if ($rawPath.Equals($root, [StringComparison]::OrdinalIgnoreCase) `
        -or $rawPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Raw MCP wire evidence must stay outside the role worktree."
    }
    if (Test-Path -LiteralPath $rawPath) {
        throw "Refusing to overwrite raw MCP wire evidence: $rawPath"
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($rawPath)) | Out-Null
    Assert-RolePathChainHasNoReparsePoint `
        -Path ([IO.Path]::GetDirectoryName($rawPath)) `
        -Label "Raw MCP wire evidence parent"
    $temporaryRawPath = "$rawPath.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllBytes($temporaryRawPath, $rawResponseBytes)
        [IO.File]::Move($temporaryRawPath, $rawPath, $false)
    } finally {
        if (Test-Path -LiteralPath $temporaryRawPath) {
            Remove-Item -LiteralPath $temporaryRawPath -Force
        }
    }
}
$rawResponseText = [Text.UTF8Encoding]::new($false, $true).GetString(
    $rawResponseBytes
)

try {
    $response = $rawResponseText | ConvertFrom-Json
} catch {
    throw "MCP endpoint returned non-JSON content (HTTP $([int]$httpResponse.StatusCode))."
}
if ([int]$httpResponse.StatusCode -lt 200 -or [int]$httpResponse.StatusCode -ge 300) {
    $toolFailure = "MCP endpoint returned HTTP $([int]$httpResponse.StatusCode)."
} else {
    $toolFailure = $null
}

if ($response.error -ne $null) {
    $toolFailure = $response.error | ConvertTo-Json -Depth 10 -Compress
} elseif ($null -eq $response.result) {
    $toolFailure = "Tool $ToolName returned no JSON-RPC result."
} elseif ($null -eq $response.result.PSObject.Properties["isError"] `
    -or $response.result.isError -isnot [bool]) {
    $toolFailure = "Tool $ToolName returned an invalid isError field."
} elseif ($response.result.isError) {
    $toolError = @($response.result.content | ForEach-Object {
        if ($_.type -eq "text") { [string]$_.text }
    }) -join "`n"
    $toolFailure = "Tool $ToolName returned isError=true: $toolError"
}
if ($null -ne $toolFailure) {
    if ($PassThroughToolErrors) {
        Write-Output $rawResponseText
        exit 65
    }
    throw $toolFailure
}

if ($OutputImage -ne "") {
    $imageContent = $response.result.content | Where-Object { $_.type -eq "image" } | Select-Object -First 1
    if ($null -eq $imageContent) {
        throw "Tool $ToolName returned no image content."
    }
    $imagePath = [System.IO.Path]::GetFullPath((Join-Path $root $OutputImage))
    Assert-RolePathChainHasNoReparsePoint `
        -Path $imagePath `
        -Label "MCP image output"
    $rootPrefix = $root.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    if (-not $imagePath.StartsWith(
        $rootPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Image output must stay inside the role worktree: $imagePath"
    }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($imagePath)) | Out-Null
    [System.IO.File]::WriteAllBytes($imagePath, [System.Convert]::FromBase64String([string]$imageContent.data))
}

Write-Output $rawResponseText
