param(
    [string]$Runner = (Join-Path $PSScriptRoot 'v076_generation9_platform_probe.ps1')
)

$ErrorActionPreference = 'Stop'
$tokens = $null
$parseErrors = $null
$runnerPath = (Resolve-Path -LiteralPath $Runner).Path
$runnerText = Get-Content -LiteralPath $runnerPath -Raw
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $runnerPath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) {
    throw "Runner parse failed: $($parseErrors | Out-String)"
}

$functionNames = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst]
}, $true) | ForEach-Object {$_.Name} | Sort-Object -Unique)
$commandNames = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst]
}, $true) | ForEach-Object {$_.GetCommandName()} | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_)
} | Sort-Object -Unique)
$unknownCommands = @($commandNames | Where-Object {
    $_ -notin $functionNames -and $null -eq (Get-Command -Name $_ -ErrorAction SilentlyContinue)
})
if ($unknownCommands.Count -ne 0) {
    throw "Runner contains unknown commands: $($unknownCommands -join ', ')"
}

foreach ($name in @(
    'Get-RequestedProperties',
    'Get-Center',
    'Get-FlattenedRuntimeTree',
    'Find-LiveRuntimeButtonByText'
)) {
    $functionAst = $ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -ceq $name
    }, $true) | Select-Object -First 1
    if ($null -eq $functionAst) {
        throw "Runner function is missing: $name"
    }
    . ([ScriptBlock]::Create($functionAst.Extent.Text))
}

function Query-RuntimeNode {
    param(
        [string]$EvidenceName,
        [string]$NodePath,
        [string[]]$Properties,
        [switch]$IncludeChildren,
        [int]$MaxDepth = 2,
        [int]$MaxNodes = 80
    )
    if ($NodePath -ceq '/root/Main') {
        return [pscustomobject]@{
            tree = [pscustomobject]@{
                name = 'Main'
                path = '/root/Main'
                type = 'Control'
                properties = [pscustomobject]@{}
                children = @([pscustomobject]@{
                    name = 'CommercialShellSurfaceLayer'
                    path = '/root/Main/CommercialShellSurfaceLayer'
                    type = 'Control'
                    properties = [pscustomobject]@{visible = $true}
                    children = @()
                    children_truncated = $true
                })
            }
        }
    }
    if ($NodePath -ceq '/root/Main/CommercialShellSurfaceLayer') {
        return [pscustomobject]@{
            tree = [pscustomobject]@{
                name = 'CommercialShellSurfaceLayer'
                path = $NodePath
                type = 'Control'
                properties = [pscustomobject]@{visible = $true}
                children = @([pscustomobject]@{
                    name = 'MenuPreviewBox'
                    path = "$NodePath/MenuPreviewBox"
                    type = 'VBoxContainer'
                    properties = [pscustomobject]@{visible = $true}
                    children = @()
                    children_truncated = $true
                })
            }
        }
    }
    if ($NodePath -ceq '/root/Main/CommercialShellSurfaceLayer/MenuPreviewBox') {
        return [pscustomobject]@{
            tree = [pscustomobject]@{
                name = 'MenuPreviewBox'
                path = $NodePath
                type = 'VBoxContainer'
                properties = [pscustomobject]@{visible = $true}
                children = @([pscustomobject]@{
                    name = 'MainMenuCommandButton'
                    path = "$NodePath/MainMenuCommandButton"
                    type = 'Button'
                    properties = [pscustomobject]@{
                        text = '开始新局'
                        visible = $true
                        global_position = [pscustomobject]@{x = 100; y = 200}
                        size = [pscustomobject]@{x = 300; y = 80}
                    }
                })
            }
        }
    }
    if ($NodePath -ceq '/root/Main/CommercialShellSurfaceLayer/MenuPreviewBox/MainMenuCommandButton') {
        return [pscustomobject]@{
            name = 'MainMenuCommandButton'
            path = $NodePath
            type = 'Button'
            requested_properties = [pscustomobject]@{
                text = '开始新局'
                visible = $true
                disabled = $false
                global_position = [pscustomobject]@{x = 100; y = 200}
                size = [pscustomobject]@{x = 300; y = 80}
            }
        }
    }
    throw "Unexpected synthetic runtime query path: $NodePath"
}

$button = Find-LiveRuntimeButtonByText `
    -Text '开始新局' `
    -EvidencePrefix 'synthetic-discovery'
$center = Get-Center $button
if (
    [string]$button.path -cne '/root/Main/CommercialShellSurfaceLayer/MenuPreviewBox/MainMenuCommandButton' -or
    [double]$center.x -ne 250 -or
    [double]$center.y -ne 240
) {
    throw 'Recursive live-button discovery did not return the synthetic enabled visible button.'
}

$orderedMarkers = @(
    "schema_version -cne 'space_syndicate.v076.generation9_probe_budget_ledger.v1'",
    "schema_version -cne 'space_syndicate.v076.post_restart_requalification_seal.v1'",
    'throw "Refusing to overwrite probe evidence: $probeRoot"',
    "schema_version = 'space_syndicate.v076.generation9_platform_probe_execution_start.v1'",
    "foreach (`$required in @(`$MonitorScript, `$GodotPath, `$invokeTool, `$launchTool, `$stopTool))",
    "-EvidenceName 'commercial-new-game-button-click.jsonrpc.json'",
    '-EvidenceName ("start-overlay-visible-poll-{0:d3}.jsonrpc.json"',
    '-EvidenceName ("commercial-menu-closed-poll-{0:d3}.jsonrpc.json"',
    "-EvidenceName 'seed-input-before-entry.jsonrpc.json'",
    "schema_version = 'space_syndicate.v076.external_seed_focus_request.v2'",
    "-EvidenceName 'seed-entry.jsonrpc.json'",
    "-EvidenceName 'start-configured-game-click.jsonrpc.json'"
)
$previousIndex = -1
foreach ($marker in $orderedMarkers) {
    $index = $runnerText.IndexOf($marker, [StringComparison]::Ordinal)
    if ($index -le $previousIndex) {
        throw "Runner workflow marker is absent or out of order: $marker"
    }
    $previousIndex = $index
}
foreach ($requiredText in @(
    "`$authorizationId = 'USER_AUTHORIZATION_V076_POST_RESTART_REQUALIFICATION_20260902'",
    "`$probeBudgetAuthorizationId = 'USER_SUPPLEMENTAL_AUTHORIZATION_V076_GENERATION9_PROBES_PLUS3_20260902'",
    "[string]`$budgetLedger.next_probe_id -cne `$ProbeId",
    '[int]$budgetLedger.remaining_launch_count -lt 1',
    '[int]$budgetLedger.remaining_launch_count -gt 4',
    '[int]$budgetLedger.launch_count_after_requalification -gt 3',
    '-not [bool]$requalificationSeal.existing_probe_budget_reactivated',
    "exact_window_title = '太空辛迪加 (DEBUG)'",
    'runtime_viewport_coordinate_advisory_only = $true',
    "computer_use_coordinate_space = 'WINDOW_RELATIVE_INCLUDING_WINDOW_CHROME'",
    "computer_use_required_screenshot_frame = 'FULL_WINDOW_FRAME'",
    "computer_use_click_instruction = 'USE_THE_FULL_WINDOW_FRAME_SCREENSHOT_AND_CLICK_THE_VISIBLE_SEED_INPUT_CENTER_ONCE_IN_WINDOW_RELATIVE_COORDINATES'",
    '[int]$externalFocus.window_match_count -ne 1',
    '[int]$externalFocus.window_activation_count -ne 1',
    '[int]$externalFocus.seed_field_click_count -ne 1',
    '[int]$externalFocus.direct_runtime_seed_injection_count -ne 0',
    "[string]`$externalFocus.computer_use_coordinate_space -cne 'WINDOW_RELATIVE_INCLUDING_WINDOW_CHROME'",
    '-not [bool]$externalFocus.full_window_frame_screenshot_used',
    '[bool]$externalFocus.runtime_viewport_coordinate_used_for_click',
    'commercial_menu_overlay_visible = $false'
)) {
    if ($runnerText.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
        throw "Runner witness contract is missing: $requiredText"
    }
}

foreach ($requiredText in @(
    '[DateTime]::UtcNow.AddSeconds($RuntimeReadyTimeoutSeconds)',
    '[DateTime]::UtcNow.AddSeconds($CommercialMenuReadyTimeoutSeconds)',
    '[DateTime]::UtcNow.AddSeconds($NewGameReadyTimeoutSeconds)',
    '[DateTime]::UtcNow.AddSeconds($ExternalSeedFocusTimeoutSeconds)',
    "throw 'Commercial New Game navigation did not reveal an unoccluded StartOverlay before timeout.'",
    "throw 'New Game seed owners did not become queryable before timeout.'",
    "throw 'External Windows focus witness was not supplied before timeout.'"
)) {
    if ($runnerText.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
        throw "Runner timeout state machine is missing: $requiredText"
    }
}

foreach ($requiredText in @(
    '} finally {',
    'Stop-RoleNormally',
    '[IO.File]::WriteAllText($monitorStop, "stop`n"',
    '[void]$monitorProcess.WaitForExit(60000)',
    '[bool]$cleanup.stopped',
    '-not [bool]$cleanup.forced_stop',
    '[int]$cleanup.process_count_after -eq 0',
    '[int]$cleanup.endpoint_count_after -eq 0'
)) {
    if ($runnerText.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
        throw "Runner cleanup state machine is missing: $requiredText"
    }
}

$resultBuildIndex = $runnerText.IndexOf('$result = [ordered]@{', [StringComparison]::Ordinal)
$resultWriteIndex = $runnerText.IndexOf('Write-Utf8Json -Path $resultPath -Value $result', [StringComparison]::Ordinal)
$failureExitIndex = $runnerText.IndexOf("if (`$status -ne 'PASS') {", [StringComparison]::Ordinal)
if (
    $resultBuildIndex -lt 0 -or
    $resultWriteIndex -le $resultBuildIndex -or
    $failureExitIndex -le $resultWriteIndex
) {
    throw 'Runner evidence finalization order is incomplete.'
}

foreach ($forbiddenText in @(
    'SendKeys',
    'type_text',
    'set_value',
    'direct_runtime_seed_injection_count = 1',
    'formal_generation = $true',
    'generation9_formal_execution_count = 1'
)) {
    if ($runnerText.IndexOf($forbiddenText, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "Runner contains a forbidden ownership or formal-execution marker: $forbiddenText"
    }
}

[ordered]@{
    status = 'PASS'
    powershell_parse_error_count = $parseErrors.Count
    discovered_command_count = $commandNames.Count
    unknown_command_count = $unknownCommands.Count
    control_flow_token_audit = 'PASS'
    synthetic_recursive_button_discovery = 'PASS'
    discovered_button_path = [string]$button.path
    discovered_button_center = $center
    commercial_navigation_before_seed_entry = 'PASS'
    unoccluded_start_overlay_gate = 'PASS'
    external_windows_focus_contract = 'PASS'
    timeout_state_machine = 'PASS'
    cleanup_state_machine = 'PASS'
    evidence_finalization = 'PASS'
    budget_ledger_guard = 'PASS'
    screenshot_coordinate_space_contract = 'PASS'
    direct_runtime_seed_injection_allowed = $false
    godot_launch_count = 0
} | ConvertTo-Json -Depth 10
