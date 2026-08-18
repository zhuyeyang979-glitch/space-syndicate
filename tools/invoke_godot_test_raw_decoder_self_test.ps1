<#
.SYNOPSIS
Exercises the runner's exact raw-log decoder without launching Godot.

.DESCRIPTION
Loads the Convert-RawLogToNormalizedText function directly from
invoke_godot_test.ps1, then proves empty, UTF-8, UTF-16LE/BE, embedded-NUL, and
invalid-UTF-8 behavior against repository-external byte fixtures.
#>
[CmdletBinding()]
param(
    [string]$RunnerPath = (Join-Path $PSScriptRoot "invoke_godot_test.ps1"),
    [string]$EvidenceRoot = (Join-Path $env:LOCALAPPDATA ("SpaceSyndicate\raw_decoder_self_test\{0}-{1}" -f [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff"), ([guid]::NewGuid().ToString("N").Substring(0, 8))))
)

$ErrorActionPreference = "Stop"

function Assert-Condition {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

$RunnerPath = (Resolve-Path -LiteralPath $RunnerPath).Path
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($RunnerPath, [ref]$tokens, [ref]$parseErrors)
Assert-Condition (@($parseErrors).Count -eq 0) "Runner has PowerShell parse errors."
$functionAst = @(
    $ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq "Convert-RawLogToNormalizedText"
    }, $true)
)
Assert-Condition ($functionAst.Count -eq 1) "Runner raw decoder function was not found exactly once."
. ([scriptblock]::Create($functionAst[0].Extent.Text))

function Invoke-DecoderCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )
    $rawPath = Join-Path $EvidenceRoot "$Name.raw.bin"
    $textPath = Join-Path $EvidenceRoot "$Name.txt"
    [IO.File]::WriteAllBytes($rawPath, $Bytes)
    $result = Convert-RawLogToNormalizedText -RawPath $rawPath -TextPath $textPath -CaptureComplete $true
    return [pscustomobject][ordered]@{
        name = $Name
        result = $result
        text = [IO.File]::ReadAllText($textPath)
    }
}

$empty = Invoke-DecoderCase -Name "empty" -Bytes ([byte[]]::new(0))
$utf8Text = "RUNNER_UTF8|太空辛迪加|星舰"
$utf8 = Invoke-DecoderCase -Name "utf8" -Bytes ([Text.UTF8Encoding]::new($false, $true).GetBytes($utf8Text))
$utf16LeText = "RUNNER_UTF16LE|太空辛迪加"
$utf16LePayload = [Text.UnicodeEncoding]::new($false, $false, $true).GetBytes($utf16LeText)
$utf16Le = Invoke-DecoderCase -Name "utf16le" -Bytes ([byte[]](@(0xFF, 0xFE) + @($utf16LePayload)))
$utf16BeText = "RUNNER_UTF16BE|星舰"
$utf16BePayload = [Text.UnicodeEncoding]::new($true, $false, $true).GetBytes($utf16BeText)
$utf16Be = Invoke-DecoderCase -Name "utf16be" -Bytes ([byte[]](@(0xFE, 0xFF) + @($utf16BePayload)))
$nul = Invoke-DecoderCase -Name "decoded_nul" -Bytes ([byte[]](0x41, 0x00, 0x42))
$invalid = Invoke-DecoderCase -Name "invalid_utf8" -Bytes ([byte[]](0xC3, 0x28))

Assert-Condition ($empty.result.byte_length -eq 0 -and $empty.result.strict_decode) "Empty stream did not decode as valid zero-byte UTF-8."
Assert-Condition ($empty.result.sha256 -eq "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") "Empty stream SHA-256 mismatch."
Assert-Condition ($utf8.result.encoding -eq "utf-8" -and $utf8.result.strict_decode -and $utf8.text -ceq $utf8Text) "UTF-8 text was not preserved exactly."
Assert-Condition ($utf8.result.raw_nul_count -eq 0 -and $utf8.result.decoded_nul_character_count -eq 0 -and $utf8.result.replacement_character_count -eq 0) "UTF-8 clean counters are not zero."
Assert-Condition ($utf16Le.result.encoding -eq "utf-16le-bom" -and $utf16Le.result.strict_decode -and $utf16Le.text -ceq $utf16LeText) "UTF-16LE BOM text was not decoded exactly."
Assert-Condition ($utf16Le.result.raw_nul_count -gt 0 -and $utf16Le.result.decoded_nul_character_count -eq 0) "UTF-16LE structural zero bytes were misclassified as decoded NUL."
Assert-Condition ($utf16Be.result.encoding -eq "utf-16be-bom" -and $utf16Be.result.strict_decode -and $utf16Be.text -ceq $utf16BeText) "UTF-16BE BOM text was not decoded exactly."
Assert-Condition ($utf16Be.result.raw_nul_count -gt 0 -and $utf16Be.result.decoded_nul_character_count -eq 0) "UTF-16BE structural zero bytes were misclassified as decoded NUL."
Assert-Condition ($nul.result.strict_decode -and $nul.result.decoded_nul_character_count -eq 1 -and $nul.result.raw_nul_count -eq 1) "Embedded NUL was not counted in raw and decoded forms."
Assert-Condition (-not $invalid.result.strict_decode -and $invalid.result.replacement_character_count -gt 0) "Invalid UTF-8 did not fail strict decoding."

$summary = [ordered]@{
    status = "passed"
    evidence_root = $EvidenceRoot
    cases = @($empty, $utf8, $utf16Le, $utf16Be, $nul, $invalid)
}
$summaryPath = Join-Path $EvidenceRoot "summary.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$summary["summary_json"] = $summaryPath
$summary | ConvertTo-Json -Depth 5 -Compress | Write-Output
