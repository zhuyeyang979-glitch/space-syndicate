Set-StrictMode -Version Latest

function Get-Pr90M5ListenerParityV2Contract {
    [CmdletBinding()]
    param([int]$RequiredCohortCount=5,[int]$RequiredConsecutiveStableParityCohortCount=5,[int]$RequiredStableWindowMs=1000,[int]$CohortIntervalMs=300,[int]$SourceObserverTimeoutMs=1000,[int]$ProcessIdentityMarginMs=5000,[int]$MaximumBudgetMs=30000)
    $observerInvocationCountPerCohort=3
    $minimumBudget=($RequiredCohortCount*$observerInvocationCountPerCohort*$SourceObserverTimeoutMs)+(($RequiredCohortCount-1)*$CohortIntervalMs)+$ProcessIdentityMarginMs
    $green=($RequiredCohortCount-ge5-and$RequiredConsecutiveStableParityCohortCount-ge5-and$RequiredConsecutiveStableParityCohortCount-le$RequiredCohortCount-and$RequiredStableWindowMs-ge1000-and$minimumBudget-le$MaximumBudgetMs)
    return [pscustomobject][ordered]@{schema='Pr90M5ListenerParityV2SamplingContract';required_total_cohort_attempt_count=$RequiredCohortCount;required_consecutive_stable_parity_cohort_count=$RequiredConsecutiveStableParityCohortCount;required_stable_parity_window_ms=$RequiredStableWindowMs;cohort_interval_ms=$CohortIntervalMs;source_observer_timeout_ms=$SourceObserverTimeoutMs;observer_invocation_count_per_cohort=$observerInvocationCountPerCohort;process_identity_margin_ms=$ProcessIdentityMarginMs;sampling_budget_minimum_ms=$minimumBudget;sampling_budget_ms=$minimumBudget;sampling_budget_sufficient=$green;short_time_bounded_maximum_ms=$MaximumBudgetMs;short_time_bounded=($minimumBudget-le$MaximumBudgetMs)}
}

Export-ModuleMember -Function 'Get-Pr90M5ListenerParityV2Contract'
