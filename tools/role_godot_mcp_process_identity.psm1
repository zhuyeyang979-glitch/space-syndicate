Set-StrictMode -Version Latest


function ConvertTo-RoleGodotProcessStartUtc {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Token
    )

    if ($null -eq $Token) {
        throw "Process creation-time token is null."
    }

    if ($Token -is [DateTime]) {
        $dateTime = [DateTime]$Token
        if ($dateTime.Kind -eq [DateTimeKind]::Unspecified) {
            throw "Process creation-time DateTime has no timezone identity."
        }
        return $dateTime.ToUniversalTime()
    }

    if ($Token -is [DateTimeOffset]) {
        return ([DateTimeOffset]$Token).UtcDateTime
    }

    if ($Token -isnot [string]) {
        throw "Unsupported process creation-time token type: $($Token.GetType().FullName)"
    }

    $text = ([string]$Token).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "Process creation-time token is blank."
    }
    if ($text -notmatch '(?:Z|[+-][0-9]{2}:[0-9]{2})$') {
        throw "Process creation-time token has no explicit timezone."
    }

    $parsed = [DateTimeOffset]::MinValue
    $parsedOk = [DateTimeOffset]::TryParseExact(
        $text,
        "o",
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,
        [ref]$parsed
    )
    if (-not $parsedOk) {
        throw "Process creation-time token is not a canonical round-trip timestamp."
    }
    return $parsed.UtcDateTime
}


function Test-RoleGodotProcessStartIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$ExpectedToken,

        [Parameter(Mandatory = $true)]
        [DateTime]$ActualStartTime
    )

    $expectedUtc = ConvertTo-RoleGodotProcessStartUtc -Token $ExpectedToken
    $actualUtc = $ActualStartTime.ToUniversalTime()
    return $actualUtc.Ticks -eq $expectedUtc.Ticks
}


Export-ModuleMember -Function @(
    "ConvertTo-RoleGodotProcessStartUtc",
    "Test-RoleGodotProcessStartIdentity"
)
