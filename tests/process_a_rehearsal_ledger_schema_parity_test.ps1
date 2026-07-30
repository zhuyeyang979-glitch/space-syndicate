[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $root "scripts/tools/process_a_rehearsal_admission_contract.psm1"
$driverPath = Join-Path $root "scripts/tools/cold_restore_vertical_slice_driver.gd"
$module = Import-Module $modulePath -Force -PassThru
$contract = & $module { Get-ProcessARehearsalAdmissionContractInfo }
$source = [IO.File]::ReadAllText($driverPath)
$match = [regex]::Match(
    $source,
    '(?s)const REHEARSAL_LEDGER_FIELDS := \[(?<body>.*?)\]\s*var ',
    [Text.RegularExpressions.RegexOptions]::CultureInvariant
)
$driverFields = @()
if ($match.Success) {
    $driverFields = @([regex]::Matches($match.Groups['body'].Value, '"(?<field>[a-z0-9_]+)"') |
        ForEach-Object { [string]$_.Groups['field'].Value })
}
$expectedFields = @($contract.admission_ledger_fields)
$sameFields = $driverFields.Count -eq $expectedFields.Count -and
    (($driverFields | Sort-Object) -join "`n") -ceq (($expectedFields | Sort-Object) -join "`n")
$requiredDiagnosticFields = @(
    "diagnostic_launch_attestation_sha256",
    "diagnostic_manifest_sha256",
    "diagnostic_engine_process_id",
    "diagnostic_engine_creation_time_utc_ticks"
)
$authorizationStart = $source.IndexOf("func _authorize_process_a_rehearsal(", [StringComparison]::Ordinal)
$authorizationEnd = $source.IndexOf("`nfunc ", $authorizationStart + 1, [StringComparison]::Ordinal)
$authorizationSource = if ($authorizationStart -ge 0 -and $authorizationEnd -gt $authorizationStart) {
    $source.Substring($authorizationStart, $authorizationEnd - $authorizationStart)
}
else {
    ""
}
$missingChecks = @($requiredDiagnosticFields | Where-Object {
    $authorizationSource.IndexOf(('ledger.get("{0}"' -f $_), [StringComparison]::Ordinal) -lt 0
})

$status = if ($match.Success -and $sameFields -and $missingChecks.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "PROCESS_A_REHEARSAL_LEDGER_SCHEMA_PARITY_TEST|status=$status|module_fields=$($expectedFields.Count)|driver_fields=$($driverFields.Count)|missing_checks=$($missingChecks.Count)"
if ($status -eq "FAIL") {
    if (-not $match.Success) { Write-Output "FAIL|driver ledger allowlist not found" }
    if (-not $sameFields) { Write-Output "FAIL|PowerShell and GDScript admission ledger fields differ" }
    foreach ($field in $missingChecks) { Write-Output "FAIL|driver does not validate $field" }
    exit 1
}
exit 0
