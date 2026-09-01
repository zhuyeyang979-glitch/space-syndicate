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
    "exact_window_title = '太空辛迪加 (DEBUG)'",
    '[int]$externalFocus.window_match_count -ne 1',
    '[int]$externalFocus.window_activation_count -ne 1',
    '[int]$externalFocus.seed_field_click_count -ne 1',
    '[int]$externalFocus.direct_runtime_seed_injection_count -ne 0',
    'commercial_menu_overlay_visible = $false'
)) {
    if ($runnerText.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
        throw "Runner witness contract is missing: $requiredText"
    }
}

[ordered]@{
    status = 'PASS'
    powershell_parse_error_count = $parseErrors.Count
    synthetic_recursive_button_discovery = 'PASS'
    discovered_button_path = [string]$button.path
    discovered_button_center = $center
    commercial_navigation_before_seed_entry = 'PASS'
    unoccluded_start_overlay_gate = 'PASS'
    external_windows_focus_contract = 'PASS'
    direct_runtime_seed_injection_allowed = $false
    godot_launch_count = 0
} | ConvertTo-Json -Depth 10
