param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot "role_godot_mcp_process_identity.psm1"
Import-Module -Name $modulePath -Force -ErrorAction Stop

$checks = 0
$failures = [Collections.Generic.List[string]]::new()

function Assert-IdentityContract {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Assert-IdentityContractThrows {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $script:checks += 1
    try {
        & $Action
        $script:failures.Add($Message)
    } catch {
        # Expected fail-closed path.
    }
}

$canonical = "2026-08-09T01:02:03.1234567Z"
$expectedUtc = [DateTime]::ParseExact(
    $canonical,
    "o",
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::RoundtripKind
).ToUniversalTime()
$jsonToken = ('{"process_start_time_utc":"' + $canonical + '"}' |
    ConvertFrom-Json).process_start_time_utc

Assert-IdentityContract `
    -Condition ($jsonToken -is [DateTime]) `
    -Message "ConvertFrom-Json must exercise the DateTime materialization regression."
$jsonUtc = ConvertTo-RoleGodotProcessStartUtc -Token $jsonToken
Assert-IdentityContract `
    -Condition ($jsonUtc.Kind -eq [DateTimeKind]::Utc -and $jsonUtc.Ticks -eq $expectedUtc.Ticks) `
    -Message "JSON-materialized DateTime must preserve UTC ticks."

$dateTimeUtc = ConvertTo-RoleGodotProcessStartUtc -Token $expectedUtc
Assert-IdentityContract `
    -Condition ($dateTimeUtc.Ticks -eq $expectedUtc.Ticks) `
    -Message "UTC DateTime must preserve exact ticks."

$offsetToken = [DateTimeOffset]::ParseExact(
    "2026-08-09T10:02:03.1234567+09:00",
    "o",
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None
)
$offsetUtc = ConvertTo-RoleGodotProcessStartUtc -Token $offsetToken
Assert-IdentityContract `
    -Condition ($offsetUtc.Ticks -eq $expectedUtc.Ticks) `
    -Message "DateTimeOffset must normalize to the same UTC instant."

$stringUtc = ConvertTo-RoleGodotProcessStartUtc -Token $canonical
Assert-IdentityContract `
    -Condition ($stringUtc.Ticks -eq $expectedUtc.Ticks) `
    -Message "Canonical Z string must preserve exact UTC ticks."
$offsetStringUtc = ConvertTo-RoleGodotProcessStartUtc `
    -Token "2026-08-09T10:02:03.1234567+09:00"
Assert-IdentityContract `
    -Condition ($offsetStringUtc.Ticks -eq $expectedUtc.Ticks) `
    -Message "Canonical offset string must normalize to the same UTC instant."

Assert-IdentityContract `
    -Condition (Test-RoleGodotProcessStartIdentity `
        -ExpectedToken $jsonToken `
        -ActualStartTime $expectedUtc) `
    -Message "Exact creation-time identity must pass."
Assert-IdentityContract `
    -Condition (-not (Test-RoleGodotProcessStartIdentity `
        -ExpectedToken $jsonToken `
        -ActualStartTime $expectedUtc.AddTicks(1))) `
    -Message "One-tick PID-reuse mismatch must fail."

Assert-IdentityContractThrows `
    -Action { ConvertTo-RoleGodotProcessStartUtc -Token $null } `
    -Message "Null creation-time token must fail closed."
Assert-IdentityContractThrows `
    -Action { ConvertTo-RoleGodotProcessStartUtc -Token "   " } `
    -Message "Blank creation-time token must fail closed."
Assert-IdentityContractThrows `
    -Action { ConvertTo-RoleGodotProcessStartUtc -Token "not-a-time" } `
    -Message "Invalid creation-time token must fail closed."
Assert-IdentityContractThrows `
    -Action { ConvertTo-RoleGodotProcessStartUtc -Token "2026-08-09T01:02:03.1234567" } `
    -Message "Timezone-free creation-time string must fail closed."
Assert-IdentityContractThrows `
    -Action { ConvertTo-RoleGodotProcessStartUtc -Token ([pscustomobject]@{ value = $canonical }) } `
    -Message "Object-shaped creation-time token must fail closed."
Assert-IdentityContractThrows `
    -Action { ConvertTo-RoleGodotProcessStartUtc -Token ([DateTime]::SpecifyKind($expectedUtc, [DateTimeKind]::Unspecified)) } `
    -Message "Unspecified DateTime must fail closed."

foreach ($scriptName in @("invoke_role_godot_mcp.ps1", "stop_role_godot_mcp.ps1")) {
    $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot $scriptName) -Raw
    Assert-IdentityContract `
        -Condition ($source.Contains("role_godot_mcp_process_identity.psm1") -and
            $source.Contains("Test-RoleGodotProcessStartIdentity")) `
        -Message "$scriptName must use the shared process-start identity helper."
}

if ($failures.Count -ne 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    Write-Output (
        "ROLE_GODOT_MCP_PROCESS_IDENTITY_SELF_TEST|checks={0}|failures={1}|status=FAIL" -f
        $checks,
        $failures.Count
    )
    exit 1
}

Write-Output (
    "ROLE_GODOT_MCP_PROCESS_IDENTITY_SELF_TEST|checks={0}|failures=0|status=PASS" -f
    $checks
)
