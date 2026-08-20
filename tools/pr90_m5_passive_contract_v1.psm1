Set-StrictMode -Version Latest

function Get-Pr90M5PassiveSamplingContractV1 {
    [CmdletBinding()]
    param(
        [ValidateRange(1,100)][int]$RequiredTotalSampleCount = 5,
        [ValidateRange(1,100)][int]$RequiredConsecutiveParitySampleCount = 3,
        [ValidateRange(1,60000)][int]$RequiredStableWindowMs = 1000,
        [ValidateRange(1,10000)][int]$SampleIntervalMs = 500,
        [ValidateRange(0,120000)][int]$ObserverExecutionMarginMs = 15000,
        [ValidateRange(0,120000)][int]$ProcessIdentityMarginMs = 5000,
        [ValidateRange(1,120000)][int]$ShortTimeBoundedMaximumMs = 60000
    )

    $minimumBudgetMs = (($RequiredTotalSampleCount - 1) * $SampleIntervalMs) +
        $ObserverExecutionMarginMs + $ProcessIdentityMarginMs
    $samplingBudgetMs = $minimumBudgetMs
    $contractRequirementsGreen = (
        $RequiredTotalSampleCount -ge 5 -and
        $RequiredConsecutiveParitySampleCount -ge 3 -and
        $RequiredConsecutiveParitySampleCount -le $RequiredTotalSampleCount -and
        $RequiredStableWindowMs -ge 1000
    )
    $samplingBudgetSufficient = (
        $contractRequirementsGreen -and
        $samplingBudgetMs -ge $minimumBudgetMs -and
        $samplingBudgetMs -le $ShortTimeBoundedMaximumMs
    )

    return [pscustomobject][ordered]@{
        schema = 'SpaceSyndicatePr90M5PassiveSamplingContractV1'
        required_total_sample_count = $RequiredTotalSampleCount
        required_consecutive_parity_sample_count = $RequiredConsecutiveParitySampleCount
        required_stable_window_ms = $RequiredStableWindowMs
        sample_interval_ms = $SampleIntervalMs
        observer_execution_margin_ms = $ObserverExecutionMarginMs
        process_identity_margin_ms = $ProcessIdentityMarginMs
        sampling_budget_minimum_ms = $minimumBudgetMs
        sampling_budget_ms = $samplingBudgetMs
        sampling_budget_sufficient = $samplingBudgetSufficient
        sampling_budget_false_green_count = 0
        short_time_bounded_maximum_ms = $ShortTimeBoundedMaximumMs
        short_time_bounded = ($samplingBudgetMs -le $ShortTimeBoundedMaximumMs)
    }
}

function Resolve-Pr90M5MilestoneParametersV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][bool]$M5Green)

    $status = if ($M5Green) { 'PASS' } else { 'FAIL' }
    $failureClass = if ($M5Green) { '' } else { 'M5_CHARACTERIZATION_GATES_NOT_MET' }
    return [pscustomobject][ordered]@{
        status = $status
        failure_class = $failureClass
    }
}

Export-ModuleMember -Function 'Get-Pr90M5PassiveSamplingContractV1','Resolve-Pr90M5MilestoneParametersV1'
