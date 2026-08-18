Set-StrictMode -Version Latest

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function ConvertTo-CanonicalJson {
    param([Parameter(Mandatory = $true)][object]$Value)
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

function Copy-JsonObject {
    param([Parameter(Mandatory = $true)][object]$Value)
    return (ConvertTo-CanonicalJson $Value | ConvertFrom-Json -Depth 100)
}

function Get-CanonicalObjectSha256 {
    param([Parameter(Mandatory = $true)][object]$Value)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-CanonicalJson $Value))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-CanonicalRowsSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Rows)
    $sorted = [string[]]@($Rows)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes([string]::Join("`n", $sorted))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-CanonicalPayloadSha256 {
    param([Parameter(Mandatory = $true)][object]$Value, [string]$FieldName = 'canonical_payload_sha256')
    $copy = Copy-JsonObject $Value
    if (-not ($copy.PSObject.Properties.Name -contains $FieldName)) {
        $copy | Add-Member -NotePropertyName $FieldName -NotePropertyValue ''
    } else { $copy.$FieldName = '' }
    return Get-CanonicalObjectSha256 $copy
}

function Write-ImmutableJson {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][object]$Value)
    if (Test-Path -LiteralPath $Path) { throw "Refusing to overwrite immutable evidence: $Path" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))) | Out-Null
    $temp = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temp, $Path, $false)
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}

function Write-ImmutableSha256Sidecar {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$TargetPath)
    if (Test-Path -LiteralPath $Path) { throw "Refusing to overwrite immutable evidence: $Path" }
    $target = (Resolve-Path -LiteralPath $TargetPath).Path
    $text = "$(Get-Sha256 $target)  $([IO.Path]::GetFileName($target))`n"
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($Path), $text, [Text.UTF8Encoding]::new($false))
}

function Read-Sha256Sidecar {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing SHA sidecar: $Path" }
    $match = [regex]::Match([IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path).Trim(), '^([0-9a-f]{64})\s{2}(.+)$')
    if (-not $match.Success) { throw "Invalid SHA sidecar: $Path" }
    return [pscustomobject]@{ sha256 = $match.Groups[1].Value; file_name = $match.Groups[2].Value }
}

function Assert-ExactSha256 {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing evidence: $Path" }
    $actual = Get-Sha256 $Path
    if ($actual -cne $Expected.ToLowerInvariant()) { throw "SHA mismatch for ${Path}: expected=$Expected actual=$actual" }
    return $actual
}

function Assert-ProductIdentity {
    param([Parameter(Mandatory = $true)][object]$Value, [Parameter(Mandatory = $true)][string]$Head, [Parameter(Mandatory = $true)][string]$Tree)
    if ([string]$Value.head_sha -cne $Head -or [string]$Value.tree_sha -cne $Tree) { throw 'Product identity mismatch.' }
}

function Test-PathWithinRoot {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Root)
    $p = [IO.Path]::GetFullPath($Path).TrimEnd('\'); $r = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $p.Equals($r, [StringComparison]::OrdinalIgnoreCase) -or $p.StartsWith($r + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Get-RequiredManifestFields {
    return @(
        'authorization_schema_version','authorization_id','authorization_status','created_at_utc','authorized_run_count',
        'automatic_retry_allowed','formal_run_id','formal_evidence_root','product_head_sha','product_tree_sha',
        'import_tooling_branch','import_tooling_head_sha','import_tooling_tree_sha','import_tooling_worktree_path',
        'import_runner_path','import_runner_sha256','authorization_builder_path','authorization_builder_sha256',
        'authorization_validator_path','authorization_validator_sha256','authorized_tooling_file_count','authorized_tooling_files',
        'sealed_baseline_path','sealed_baseline_sha256','import_pass1_manifest_path','import_pass1_manifest_sha256',
        'import_pass2_manifest_path','import_pass2_manifest_sha256','warmup_log_path','warmup_log_sha256',
        'class_cache_path','class_cache_sha256','class_cache_bytes','class_cache_product_head_sha',
        'class_cache_product_tree_sha','class_cache_godot_version','class_cache_godot_executable_sha256',
        'class_cache_source_baseline_path','class_cache_source_baseline_sha256','formal_gate_1_79_receipt_path','formal_gate_1_79_receipt_sha256',
        'formal_gate_1_79_receipt_schema_version','formal_gate_1_79_receipt_head_sha','formal_gate_1_79_receipt_tree_sha',
        'formal_gate_1_79_receipt_gate_count','formal_gate_1_79_receipt_pass_count','formal_gate_1_79_receipt_fail_count',
        'formal_gate_1_79_receipt_duplicate_gate_count','formal_gate_1_79_receipt_missing_gate_count',
        'import_finalizer_dry_run_path','import_finalizer_dry_run_evidence_sha256','import_finalizer_dry_run_schema_version',
        'import_finalizer_dry_run_product_head_sha','import_finalizer_dry_run_product_tree_sha',
        'import_finalizer_dry_run_tooling_head_sha','import_finalizer_dry_run_tooling_tree_sha',
        'import_finalizer_dry_run_import_runner_sha256','import_finalizer_dry_run_baseline_sha256',
        'import_finalizer_dry_run_status','godot_path','godot_version','godot_executable_sha256','project_godot_path',
        'project_godot_sha256','cursor_runbook_path','cursor_runbook_sha256','import_controller_path',
        'import_controller_sha256','import_controller_receipt_path','import_controller_receipt_sha256',
        'bound_import_engine_path','bound_import_engine_sha256','import_finalizer_path','import_finalizer_sha256','selftest_manifest_path',
        'selftest_manifest_sha256','formal_dry_run_path','formal_dry_run_sha256','tooling_seal_path',
        'tooling_seal_sha256','old_attempt18_manifest_path','old_attempt18_manifest_sha256','old_import_runner_sha256',
        'formal_mcp_execution_count','authorized_run_count_consumed','conditional_next_stages','canonical_payload_sha256'
    )
}

function Test-CanonicalGateSources {
    param(
        [Parameter(Mandatory = $true)][string]$GateManifestPath,
        [Parameter(Mandatory = $true)][string]$SourceGateManifestPath,
        [Parameter(Mandatory = $true)][string]$ManifestParityPath,
        [Parameter(Mandatory = $true)][string]$ReuseAttestationPath,
        [Parameter(Mandatory = $true)][string]$AggregatePath,
        [Parameter(Mandatory = $true)][string]$FrozenEvidenceRoot,
        [Parameter(Mandatory = $true)][string]$ExpectedGateManifestSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedSourceGateManifestSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedManifestParitySha256,
        [Parameter(Mandatory = $true)][string]$ExpectedReuseAttestationSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedAggregateSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedHead,
        [Parameter(Mandatory = $true)][string]$ExpectedTree
    )
    Assert-ExactSha256 $GateManifestPath $ExpectedGateManifestSha256 | Out-Null
    Assert-ExactSha256 $SourceGateManifestPath $ExpectedSourceGateManifestSha256 | Out-Null
    Assert-ExactSha256 $ManifestParityPath $ExpectedManifestParitySha256 | Out-Null
    Assert-ExactSha256 $ReuseAttestationPath $ExpectedReuseAttestationSha256 | Out-Null
    Assert-ExactSha256 $AggregatePath $ExpectedAggregateSha256 | Out-Null
    $gateManifest = Get-Content -Raw -LiteralPath $GateManifestPath | ConvertFrom-Json -Depth 100
    $sourceGateManifest = Get-Content -Raw -LiteralPath $SourceGateManifestPath | ConvertFrom-Json -Depth 100
    $manifestParity = Get-Content -Raw -LiteralPath $ManifestParityPath | ConvertFrom-Json -Depth 100
    $reuse = Get-Content -Raw -LiteralPath $ReuseAttestationPath | ConvertFrom-Json -Depth 100
    $aggregate = Get-Content -Raw -LiteralPath $AggregatePath | ConvertFrom-Json -Depth 100
    Assert-ProductIdentity $gateManifest $ExpectedHead $ExpectedTree; Assert-ProductIdentity $sourceGateManifest $ExpectedHead $ExpectedTree; Assert-ProductIdentity $reuse $ExpectedHead $ExpectedTree
    if ([string]$aggregate.aggregate_head_sha -cne $ExpectedHead -or [string]$aggregate.aggregate_tree_sha -cne $ExpectedTree) { throw 'Candidate aggregate identity mismatch.' }
    if ([string]$gateManifest.schema -cne 'SpaceSyndicatePr92CursorFormalGateManifestV2' -or [int]$gateManifest.gate_count -ne 79) { throw 'Canonical repaired gate manifest schema/count is invalid.' }
    if ([string]$gateManifest.source_manifest_sha256 -cne $ExpectedSourceGateManifestSha256 -or [string]$sourceGateManifest.schema -cne 'SpaceSyndicatePr90CursorInstrumentationFormalGateManifestV1') { throw 'Repaired gate manifest does not bind the frozen source manifest.' }
    if ([string]$manifestParity.schema -cne 'SpaceSyndicateOldNewGateManifestEntryParityV2' -or
        [string]$manifestParity.old_manifest_sha256 -cne $ExpectedSourceGateManifestSha256 -or [string]$manifestParity.new_manifest_sha256 -cne $ExpectedGateManifestSha256 -or
        [int]$manifestParity.changed_gate_entry_count -ne 1 -or (@($manifestParity.changed_gate_ids) -join ',') -cne '78' -or
        -not [bool]$manifestParity.gate_1_to_77_entry_parity -or -not [bool]$manifestParity.gate79_entry_parity -or
        -not [bool]$manifestParity.gate_order_parity -or -not [bool]$manifestParity.gate_path_parity -or -not [bool]$manifestParity.gate_argument_parity -or
        -not [bool]$manifestParity.gate_timeout_parity -or -not [bool]$manifestParity.gate_error_policy_parity) { throw 'Gate manifest repair parity receipt is invalid.' }
    foreach ($gateId in 1..79) {
        $old = @($sourceGateManifest.gates | Where-Object { [int]$_.id -eq $gateId })[0]
        $new = @($gateManifest.gates | Where-Object { [int]$_.id -eq $gateId })[0]
        if ($gateId -eq 78) {
            $oldCopy=Copy-JsonObject $old;$newCopy=Copy-JsonObject $new;$oldCopy.marker='';$newCopy.marker=''
            if ((Get-CanonicalObjectSha256 $oldCopy) -cne (Get-CanonicalObjectSha256 $newCopy)) { throw 'Gate 78 repair changed fields other than marker.' }
        } elseif ((Get-CanonicalObjectSha256 $old) -cne (Get-CanonicalObjectSha256 $new)) { throw "Repaired gate manifest unexpectedly changed gate $gateId." }
    }
    Assert-ExactSha256 ([string]$gateManifest.gate_marker_contract_path) ([string]$gateManifest.gate_marker_contract_sha256) | Out-Null
    $markerContract = Get-Content -Raw -LiteralPath $gateManifest.gate_marker_contract_path | ConvertFrom-Json -Depth 100
    Assert-ProductIdentity $markerContract $ExpectedHead $ExpectedTree
    if ([string]$markerContract.schema -cne 'GateMarkerContractV2' -or [string]$markerContract.authorization_status -cne 'AUTHORIZED_EXECUTABLE_OPTION_A' -or
        [string]$markerContract.authority_option -cne 'A_MARKER_ONLY_KEEP_F004_GATE78_TEST_IDENTITY' -or [int]$markerContract.gate_id -ne 78 -or
        [string]$markerContract.test_path -cne 'res://tests/v075_runtime_owner_no_residual_bindings_test.gd' -or [int]$markerContract.expected_checks -ne 33) {
        throw 'Gate 78 marker-repair authority contract is invalid.'
    }
    $manifestIds = @($gateManifest.gates | ForEach-Object { [int]$_.id })
    if (@($manifestIds | Sort-Object -Unique).Count -ne 79 -or @(Compare-Object ($manifestIds | Sort-Object) (1..79)).Count -ne 0) { throw 'Gate manifest IDs are not exactly 1..79.' }
    if ([string]$reuse.schema -cne 'SpaceSyndicateGate1To77ReuseAttestationV2' -or [string]$reuse.status -cne 'PASS' -or
        [int]$reuse.inventory_count -ne 77 -or [int]$reuse.eligible_count -ne 77 -or [int]$reuse.hash_mismatch_count -ne 0 -or
        [int]$reuse.identity_mismatch_count -ne 0 -or [int]$reuse.manifest_contract_mismatch_count -ne 0) { throw 'Reuse attestation is not an exact passing 77-gate authority.' }
    $reuseRows = @($reuse.rows | Sort-Object gate_id)
    if ($reuseRows.Count -ne 77 -or (@($reuseRows.gate_id) -join ',') -cne ((1..77) -join ',')) { throw 'Reuse rows are not exactly gates 1..77.' }
    $verifiedRows = [Collections.Generic.List[object]]::new()
    foreach ($row in $reuseRows) {
        $gateId = [int]$row.gate_id
        if (-not [bool]$row.eligible) { throw "Gate $gateId is not eligible." }
        foreach ($check in @($row.checks.PSObject.Properties)) { if (-not [bool]$check.Value) { throw "Gate $gateId check failed: $($check.Name)" } }
        $gateDirectory = Join-Path $FrozenEvidenceRoot ('gate-{0:D2}' -f $gateId)
        $receiptPath = Join-Path $gateDirectory 'gate-receipt.json'
        $resultFiles = @(Get-ChildItem -LiteralPath $gateDirectory -Recurse -Filter 'result.json' -File)
        if ($resultFiles.Count -ne 1) { throw "Gate $gateId does not have exactly one raw result.json." }
        Assert-ExactSha256 $receiptPath ([string]$row.receipt_sha256) | Out-Null
        Assert-ExactSha256 $resultFiles[0].FullName ([string]$row.result_sha256) | Out-Null
        $receipt = Get-Content -Raw -LiteralPath $receiptPath | ConvertFrom-Json -Depth 100
        $raw = Get-Content -Raw -LiteralPath $resultFiles[0].FullName | ConvertFrom-Json -Depth 100
        $spec = @($gateManifest.gates | Where-Object { [int]$_.id -eq $gateId })[0]
        $specArguments = @($spec.arguments); $rawArguments = @($raw.test_arguments)
        $markerRequired = -not [string]::IsNullOrWhiteSpace([string]$spec.marker)
        $markerGreen = if ($markerRequired) {
            [bool]$raw.marker_required -and [bool]$raw.marker_found -and [string]$raw.expected_completion_marker -ceq [string]$spec.marker -and
            (Test-Path -LiteralPath ([string]$raw.stdout_log) -PathType Leaf) -and
            ([IO.File]::ReadAllText([string]$raw.stdout_log).Contains([string]$spec.marker, [StringComparison]::Ordinal))
        } else { -not [bool]$raw.marker_required }
        if ([int]$receipt.gate_id -ne $gateId -or [string]$receipt.test_path -cne [string]$spec.script -or [string]$receipt.result -cne 'PASS' -or
            [int]$receipt.exit_code -ne 0 -or [bool]$receipt.timed_out -or [string]$receipt.result_sha256 -cne [string]$row.result_sha256 -or
            [int]$receipt.script_error_count -ne 0 -or [int]$receipt.resource_error_count -ne 0 -or [int]$receipt.runtime_error_count -ne 0 -or
            [int]$receipt.task_error_count -ne 0 -or [int]$receipt.uid_error_count -ne 0 -or [bool]$receipt.raw_capture_failure -or
            -not [bool]$receipt.stdout_capture_complete -or -not [bool]$receipt.stderr_capture_complete -or
            @($receipt.project_process_convergence.remaining_process_ids).Count -ne 0 -or [int]$receipt.clone_tracked_change_count_after -ne 0 -or
            [int]$receipt.clone_index_change_count_after -ne 0 -or [string]$raw.status -cne 'passed' -or [string]$raw.target_path -cne [string]$spec.script -or
            [string]$raw.test_script -cne [string]$spec.script -or @($specArguments).Count -ne @($rawArguments).Count -or
            (@(Compare-Object $specArguments $rawArguments -SyncWindow 0).Count -ne 0) -or [int]$raw.process_exit_code -ne 0 -or
            [int]$raw.runner_exit_code -ne 0 -or [bool]$raw.timed_out -or [bool]$raw.raw_capture_failure -or
            -not [bool]$raw.stdout_capture.capture_complete -or -not [bool]$raw.stderr_capture.capture_complete -or
            [string]$raw.stdout_capture.sha256 -cne [string]$receipt.stdout_sha256 -or [string]$raw.stderr_capture.sha256 -cne [string]$receipt.stderr_sha256 -or
            [int]$raw.script_error_count -ne 0 -or [int]$raw.task_introduced_error_count -ne 0 -or @($raw.remaining_project_runtime_process_ids).Count -ne 0 -or
            -not $markerGreen) { throw "Gate $gateId raw result/receipt/manifest contract failed." }
        $verifiedRows.Add([pscustomobject]@{ source=$row; result_path=$resultFiles[0].FullName; receipt_path=$receiptPath; raw=$raw; receipt=$receipt; spec=$spec })
    }
    if ([string]$aggregate.schema -cne 'SpaceSyndicatePr92CandidateAggregate79V2' -or [string]$aggregate.status -cne 'PASS' -or
        [int]$aggregate.aggregated_gate_count -ne 79 -or [int]$aggregate.aggregated_pass_count -ne 79 -or [int]$aggregate.aggregated_fail_count -ne 0) { throw 'Candidate aggregate is not a passing 79-gate source.' }
    if ([string]$aggregate.reuse_source.attestation_sha256 -cne $ExpectedReuseAttestationSha256) { throw 'Candidate aggregate does not bind the exact reuse attestation.' }
    Assert-ExactSha256 ([string]$aggregate.continuation_source.summary_path) ([string]$aggregate.continuation_source.summary_sha256) | Out-Null
    $summary = Get-Content -Raw -LiteralPath $aggregate.continuation_source.summary_path | ConvertFrom-Json -Depth 100
    Assert-ProductIdentity $summary $ExpectedHead $ExpectedTree
    if ([string]$summary.schema -cne 'SpaceSyndicatePr92Gate78To79ContinuationSummaryV2' -or [string]$summary.status -cne 'PASS' -or
        [int]$summary.gate_78_to_79_started_count -ne 2 -or [int]$summary.gate_78_to_79_completed_count -ne 2 -or
        [int]$summary.gate_78_to_79_pass_count -ne 2 -or [int]$summary.gate_78_to_79_fail_count -ne 0 -or
        [int]$summary.godot_process_count_after -ne 0 -or [int]$summary.clone_tracked_status_count_after -ne 0 -or
        [int]$summary.clone_index_status_count_after -ne 0 -or [int]$summary.clone_unknown_untracked_count_after -ne 0) {
        throw 'Continuation summary contract failed.'
    }
    $continuation = @($aggregate.gate_78, $aggregate.gate_79)
    foreach ($row in $continuation) {
        Assert-ProductIdentity $row $ExpectedHead $ExpectedTree
        if ([int]$row.gate_id -notin @(78,79) -or [string]$row.result -cne 'PASS' -or [int]$row.runner_exit_code -ne 0 -or
            [int]$row.product_process_exit_code -ne 0 -or [string]$row.marker_validation_status -cne 'PASS') { throw "Continuation gate $($row.gate_id) is not a passing receipt." }
        Assert-ExactSha256 ([string]$row.result_path) ([string]$row.result_sha256) | Out-Null
        if (-not (Test-Path -LiteralPath ([string]$row.marker_validation_path) -PathType Leaf)) { throw "Continuation gate $($row.gate_id) marker evidence is missing." }
        $spec = @($gateManifest.gates | Where-Object { [int]$_.id -eq [int]$row.gate_id })[0]
        $raw = Get-Content -Raw -LiteralPath $row.result_path | ConvertFrom-Json -Depth 100
        $summaryRow = @($summary.rows | Where-Object { [int]$_.gate_id -eq [int]$row.gate_id })
        $markerEvidence = Get-Content -Raw -LiteralPath $row.marker_validation_path | ConvertFrom-Json -Depth 100
        $stdoutText = if (Test-Path -LiteralPath ([string]$raw.stdout_log) -PathType Leaf) { [IO.File]::ReadAllText([string]$raw.stdout_log) } else { '' }
        if ($summaryRow.Count -ne 1 -or (Get-CanonicalObjectSha256 $summaryRow[0]) -cne (Get-CanonicalObjectSha256 $row) -or
            [string]$row.test_script -cne [string]$spec.script -or [string]$row.expected_marker -cne [string]$spec.marker -or
            [string]$raw.status -cne 'passed' -or [string]$raw.target_path -cne [string]$spec.script -or [string]$raw.test_script -cne [string]$spec.script -or
            [int]$raw.process_exit_code -ne 0 -or [int]$raw.runner_exit_code -ne 0 -or [bool]$raw.timed_out -or [bool]$raw.raw_capture_failure -or
            -not [bool]$raw.stdout_capture.capture_complete -or -not [bool]$raw.stderr_capture.capture_complete -or [int]$raw.script_error_count -ne 0 -or
            [int]$raw.task_introduced_error_count -ne 0 -or @($raw.remaining_project_runtime_process_ids).Count -ne 0 -or
            -not [bool]$raw.marker_required -or -not [bool]$raw.marker_found -or [string]$raw.expected_completion_marker -cne [string]$spec.marker -or
            -not $stdoutText.Contains([string]$spec.marker, [StringComparison]::Ordinal) -or [string]$markerEvidence.status -cne 'PASS' -or
            @($markerEvidence.reasons).Count -ne 0) { throw "Continuation gate $($row.gate_id) raw/summary/marker contract failed." }
        if ([int]$row.gate_id -eq 78 -and ([string]$markerEvidence.contract_sha256 -cne [string]$gateManifest.gate_marker_contract_sha256 -or
            [string]$markerEvidence.result_path -cne [string]$row.result_path -or @($markerEvidence.marker_candidates).Count -ne 1 -or
            [string]$markerEvidence.marker_candidates[0] -cne [string]$spec.marker)) { throw 'Gate 78 marker repair evidence is not bound to the repaired manifest.' }
    }
    return [pscustomobject]@{ gate_manifest=$gateManifest; source_gate_manifest=$sourceGateManifest; manifest_parity=$manifestParity; marker_contract=$markerContract; reuse=$reuse; aggregate=$aggregate; continuation_summary=$summary; reuse_rows=@($verifiedRows); continuation_rows=$continuation }
}

function New-FinalizerStateFromBaseline {
    param([Parameter(Mandatory = $true)][object]$Baseline)
    return [pscustomobject][ordered]@{
        head_sha=[string]$Baseline.head_sha; tree_sha=[string]$Baseline.tree_sha
        tracked_import_path_set_sha256=Get-CanonicalRowsSha256 @($Baseline.tracked_import_metadata | ForEach-Object { [string]$_.path })
        tracked_import_byte_map_sha256=Get-CanonicalRowsSha256 @($Baseline.tracked_import_metadata | ForEach-Object { "$($_.path)|$($_.post_import_sha256)" })
        tracked_non_generated_delta_count=[int]$Baseline.post_import_non_generated_tracked_delta
        untracked_uid_path_set_sha256=[string]$Baseline.untracked_uid_path_set_sha256
        untracked_uid_byte_map_sha256=[string]$Baseline.untracked_uid_byte_map_sha256
        ignored_sidecar_path_set_sha256=[string]$Baseline.ignored_sidecar_path_set_sha256
        unknown_untracked_count=[int]$Baseline.post_import_unknown_untracked_count
        unknown_ignored_count=[int]$Baseline.post_import_unknown_ignored_count
        class_cache_sha256=[string]$Baseline.class_cache_sha256
    }
}

function Get-CurrentFinalizerState {
    param([Parameter(Mandatory = $true)][string]$Worktree)
    $root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
    function Invoke-StateGit([string[]]$Arguments) {
        $output = @(& git -C $root @Arguments)
        if ($LASTEXITCODE -ne 0) { throw "git failed while capturing finalizer state: $($Arguments -join ' ')" }
        return @($output)
    }
    $head = @(Invoke-StateGit @('rev-parse','HEAD'))[0].Trim()
    $tree = @(Invoke-StateGit @('rev-parse','HEAD^{tree}'))[0].Trim()
    $tracked = @(Invoke-StateGit @('-c','core.quotePath=false','diff','--name-only','HEAD','--') | ForEach-Object { $_.Replace('\','/') })
    $imports = @($tracked | Where-Object { $_.EndsWith('.import',[StringComparison]::Ordinal) })
    $nonGenerated = @($tracked | Where-Object { -not $_.EndsWith('.import',[StringComparison]::Ordinal) })
    $importByteRows = [Collections.Generic.List[string]]::new()
    foreach ($path in $imports) {
        $absolute = Join-Path $root $path
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) { $importByteRows.Add("$path|MISSING") }
        else { $importByteRows.Add("$path|$(Get-Sha256 $absolute)") }
    }
    $untracked = @(Invoke-StateGit @('-c','core.quotePath=false','ls-files','-o','--exclude-standard') | ForEach-Object { $_.Replace('\','/') })
    $uids = @($untracked | Where-Object { $_ -match '\.(gd|gdshader)\.uid$' })
    $uidByteRows = [Collections.Generic.List[string]]::new()
    foreach ($path in $uids) {
        $absolute = Join-Path $root $path
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) { $uidByteRows.Add("$path|MISSING") }
        else { $uidByteRows.Add("$path|$(Get-Sha256 $absolute)") }
    }
    $unknownUntracked = @($untracked | Where-Object { $_ -notmatch '\.(gd|gdshader)\.uid$' })
    $ignored = @(Invoke-StateGit @('-c','core.quotePath=false','ls-files','-o','-i','--exclude-standard') | ForEach-Object { $_.Replace('\','/') })
    $unknownIgnored = @($ignored | Where-Object {
        -not $_.StartsWith('.godot/',[StringComparison]::Ordinal) -and
        -not $_.StartsWith('.codex-godot/',[StringComparison]::Ordinal) -and
        -not $_.EndsWith('.import',[StringComparison]::Ordinal)
    })
    $cache = Join-Path $root '.godot/global_script_class_cache.cfg'
    return [pscustomobject][ordered]@{
        head_sha = $head
        tree_sha = $tree
        tracked_import_path_set_sha256 = Get-CanonicalRowsSha256 $imports
        tracked_import_byte_map_sha256 = Get-CanonicalRowsSha256 @($importByteRows)
        tracked_non_generated_delta_count = $nonGenerated.Count
        untracked_uid_path_set_sha256 = Get-CanonicalRowsSha256 $uids
        untracked_uid_byte_map_sha256 = Get-CanonicalRowsSha256 @($uidByteRows)
        ignored_sidecar_path_set_sha256 = Get-CanonicalRowsSha256 $ignored
        unknown_untracked_count = $unknownUntracked.Count
        unknown_ignored_count = $unknownIgnored.Count
        class_cache_sha256 = if (Test-Path -LiteralPath $cache -PathType Leaf) { Get-Sha256 $cache } else { '' }
        tracked_import_count = $imports.Count
        untracked_uid_count = $uids.Count
        ignored_sidecar_count = $ignored.Count
        non_generated_tracked_paths = $nonGenerated
        unknown_untracked_paths = $unknownUntracked
        unknown_ignored_paths = $unknownIgnored
    }
}

function Get-ImportFinalizerDecision {
    param(
        [Parameter(Mandatory = $true)][object]$BaselineState,
        [Parameter(Mandatory = $true)][object]$PostState,
        [Parameter(Mandatory = $true)][string]$DisposableRoot,
        [Parameter(Mandatory = $true)][string]$DispositionTarget,
        [bool]$ForceForensics = $false
    )
    $reasons = [Collections.Generic.List[string]]::new()
    if ([string]$PostState.head_sha -cne [string]$BaselineState.head_sha -or [string]$PostState.tree_sha -cne [string]$BaselineState.tree_sha) { $reasons.Add('PRODUCT_IDENTITY_CHANGED') }
    if ([int]$PostState.tracked_non_generated_delta_count -ne 0) { $reasons.Add('NON_GENERATED_TRACKED_DELTA') }
    if ([string]$PostState.tracked_import_path_set_sha256 -cne [string]$BaselineState.tracked_import_path_set_sha256) { $reasons.Add('TRACKED_IMPORT_PATH_SET_DELTA') }
    if ([string]$PostState.tracked_import_byte_map_sha256 -cne [string]$BaselineState.tracked_import_byte_map_sha256) { $reasons.Add('TRACKED_IMPORT_BYTE_DELTA') }
    if ([string]$PostState.untracked_uid_path_set_sha256 -cne [string]$BaselineState.untracked_uid_path_set_sha256) { $reasons.Add('UID_PATH_SET_DELTA') }
    if ([string]$PostState.untracked_uid_byte_map_sha256 -cne [string]$BaselineState.untracked_uid_byte_map_sha256) { $reasons.Add('UID_BYTE_DELTA') }
    if ([string]$PostState.ignored_sidecar_path_set_sha256 -cne [string]$BaselineState.ignored_sidecar_path_set_sha256) { $reasons.Add('IGNORED_PATH_SET_DELTA') }
    if ([int]$PostState.unknown_untracked_count -ne 0) { $reasons.Add('UNKNOWN_UNTRACKED') }
    if ([int]$PostState.unknown_ignored_count -ne 0) { $reasons.Add('UNKNOWN_IGNORED') }
    if ([string]$PostState.class_cache_sha256 -cne [string]$BaselineState.class_cache_sha256) { $reasons.Add('CLASS_CACHE_DELTA') }
    $root=[IO.Path]::GetFullPath($DisposableRoot).TrimEnd('\'); $target=[IO.Path]::GetFullPath($DispositionTarget).TrimEnd('\')
    $rootOnly=$target.Equals($root,[StringComparison]::OrdinalIgnoreCase)
    if (-not $rootOnly) { $reasons.Add('DISPOSITION_TARGET_OUTSIDE_EXACT_DISPOSABLE_ROOT') }
    if ($ForceForensics) { $reasons.Add('FORENSICS_REQUESTED') }
    $green=$reasons.Count -eq 0
    return [pscustomobject][ordered]@{
        status=if($green){'PASS'}else{'BLOCKED'}; post_run_non_generated_tracked_delta=[int]$PostState.tracked_non_generated_delta_count
        post_run_tracked_import_metadata_delta_from_baseline=if([string]$PostState.tracked_import_path_set_sha256 -ceq [string]$BaselineState.tracked_import_path_set_sha256 -and [string]$PostState.tracked_import_byte_map_sha256 -ceq [string]$BaselineState.tracked_import_byte_map_sha256){0}else{1}
        post_run_uid_delta_from_baseline=if([string]$PostState.untracked_uid_path_set_sha256 -ceq [string]$BaselineState.untracked_uid_path_set_sha256 -and [string]$PostState.untracked_uid_byte_map_sha256 -ceq [string]$BaselineState.untracked_uid_byte_map_sha256){0}else{1}
        post_run_unknown_untracked_count=[int]$PostState.unknown_untracked_count; post_run_unknown_ignored_count=[int]$PostState.unknown_ignored_count
        class_cache_match=[string]$PostState.class_cache_sha256 -ceq [string]$BaselineState.class_cache_sha256; disposable_root_only=$rootOnly
        unknown_file_delete_count=0; user_file_delete_count=0; outside_root_delete_count=0; deletion_performed=$false
        disposition=if($green){'DISCARDED_AFTER_SEALED_EVIDENCE'}else{'PRESERVED_FOR_FORENSICS'}; failure_reasons=@($reasons)
    }
}

function Test-FinalizerScenario {
    param([Parameter(Mandatory = $true)][string]$Scenario,[Parameter(Mandatory = $true)][object]$BaselineState,[Parameter(Mandatory = $true)][string]$DisposableRoot)
    $post=Copy-JsonObject $BaselineState; $target=$DisposableRoot; $force=$false; $expectedStatus='PASS'; $expectedDisposition='DISCARDED_AFTER_SEALED_EVIDENCE'
    switch($Scenario){
        'no_changes'{} 'allowed_evidence_change'{}
        'tracked_non_generated'{$post.tracked_non_generated_delta_count=1;$expectedStatus='BLOCKED';$expectedDisposition='PRESERVED_FOR_FORENSICS'}
        'tracked_import_metadata'{$post.tracked_import_byte_map_sha256=('1'*64);$expectedStatus='BLOCKED';$expectedDisposition='PRESERVED_FOR_FORENSICS'}
        'unknown_untracked'{$post.unknown_untracked_count=1;$expectedStatus='BLOCKED';$expectedDisposition='PRESERVED_FOR_FORENSICS'}
        'unknown_ignored'{$post.unknown_ignored_count=1;$expectedStatus='BLOCKED';$expectedDisposition='PRESERVED_FOR_FORENSICS'}
        'user_directory'{$target=[Environment]::GetFolderPath('UserProfile');$expectedStatus='BLOCKED';$expectedDisposition='PRESERVED_FOR_FORENSICS'}
        'outside_root'{$target=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($DisposableRoot));$expectedStatus='BLOCKED';$expectedDisposition='PRESERVED_FOR_FORENSICS'}
        'forensics_preserve'{$force=$true;$expectedStatus='BLOCKED';$expectedDisposition='PRESERVED_FOR_FORENSICS'}
        'safe_discard'{} default{throw "Unknown finalizer scenario: $Scenario"}
    }
    $decision=Get-ImportFinalizerDecision -BaselineState $BaselineState -PostState $post -DisposableRoot $DisposableRoot -DispositionTarget $target -ForceForensics $force
    return [pscustomobject][ordered]@{scenario=$Scenario;expected_status=$expectedStatus;actual_status=[string]$decision.status;expected_disposition=$expectedDisposition;actual_disposition=[string]$decision.disposition;pass=([string]$decision.status -ceq $expectedStatus -and [string]$decision.disposition -ceq $expectedDisposition -and [int]$decision.unknown_file_delete_count -eq 0 -and [int]$decision.user_file_delete_count -eq 0 -and [int]$decision.outside_root_delete_count -eq 0 -and -not [bool]$decision.deletion_performed);decision=$decision}
}

function Get-AuthorizationValidation {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,[Parameter(Mandatory = $true)][string]$ManifestShaPath,
        [Parameter(Mandatory = $true)][string]$ExpectedProductHead,[Parameter(Mandatory = $true)][string]$ExpectedProductTree,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingHead,[Parameter(Mandatory = $true)][string]$ExpectedToolingTree
    )
    $errors=[Collections.Generic.List[string]]::new();$manifest=$null;$sidecar=$null
    try{$manifest=Get-Content -Raw -LiteralPath $ManifestPath|ConvertFrom-Json -Depth 100}catch{$errors.Add("MANIFEST_READ:$($_.Exception.Message)")}
    try{$sidecar=Read-Sha256Sidecar $ManifestShaPath}catch{$errors.Add("SIDECAR_READ:$($_.Exception.Message)")}
    if($null -eq $manifest){return [pscustomobject][ordered]@{status='BLOCKED';declared_field_count=0;validated_field_count=0;field_mismatch_count=$errors.Count;missing_required_field_count=0;unknown_required_field_count=0;type_mismatch_count=0;hash_mismatch_count=0;path_mismatch_count=0;errors=@($errors)}}
    $required=@(Get-RequiredManifestFields);$names=@($manifest.PSObject.Properties.Name);$missing=@($required|Where-Object{$names -cnotcontains $_});$unknown=@($names|Where-Object{$required -cnotcontains $_})
    foreach($n in $missing){$errors.Add("MISSING_FIELD:$n")};foreach($n in $unknown){$errors.Add("UNKNOWN_FIELD:$n")}
    $typeErrors=[Collections.Generic.List[string]]::new()
    foreach($n in @('authorized_run_count','authorized_tooling_file_count','class_cache_bytes','formal_gate_1_79_receipt_gate_count','formal_gate_1_79_receipt_pass_count','formal_gate_1_79_receipt_fail_count','formal_gate_1_79_receipt_duplicate_gate_count','formal_gate_1_79_receipt_missing_gate_count','formal_mcp_execution_count','authorized_run_count_consumed')){if($names -ccontains $n -and $manifest.$n -isnot [int] -and $manifest.$n -isnot [long]){$typeErrors.Add($n)}}
    if($names -ccontains 'automatic_retry_allowed' -and $manifest.automatic_retry_allowed -isnot [bool]){$typeErrors.Add('automatic_retry_allowed')}
    foreach($n in @('authorized_tooling_files','conditional_next_stages')){if($names -ccontains $n -and $manifest.$n -isnot [Array]){$typeErrors.Add($n)}}
    foreach($n in $typeErrors){$errors.Add("TYPE_MISMATCH:$n")}
    $hashErrors=[Collections.Generic.List[string]]::new();$pathErrors=[Collections.Generic.List[string]]::new()
    if($null -ne $sidecar -and ([string]$sidecar.file_name -cne [IO.Path]::GetFileName($ManifestPath) -or [string]$sidecar.sha256 -cne (Get-Sha256 $ManifestPath))){$hashErrors.Add('manifest_sha_sidecar');$errors.Add('HASH_MISMATCH:manifest_sha_sidecar')}
    if($missing.Count -eq 0){
        if([string]$manifest.authorization_schema_version -cne 'SpaceSyndicatePr90CanonicalImportAuthorityV3' -or [string]$manifest.authorization_status -cne 'AUTHORIZED_FOR_ONE_EXACT_SHA_MCP_AFTER_PREREQUISITES' -or [int]$manifest.authorized_run_count -ne 1 -or [bool]$manifest.automatic_retry_allowed -or [int]$manifest.formal_mcp_execution_count -ne 0 -or [int]$manifest.authorized_run_count_consumed -ne 0 -or @($manifest.conditional_next_stages).Count -ne 0){$errors.Add('AUTHORIZATION_POLICY_MISMATCH')}
        if([string]$manifest.product_head_sha -cne $ExpectedProductHead -or [string]$manifest.product_tree_sha -cne $ExpectedProductTree){$errors.Add('PRODUCT_IDENTITY_MISMATCH')}
        if([string]$manifest.import_tooling_head_sha -cne $ExpectedToolingHead -or [string]$manifest.import_tooling_tree_sha -cne $ExpectedToolingTree){$errors.Add('TOOLING_IDENTITY_MISMATCH')}
        if([string]$manifest.import_runner_sha256 -ceq [string]$manifest.old_import_runner_sha256){$errors.Add('STALE_IMPORT_RUNNER_SHA')}
        if([string]$manifest.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $manifest)){$hashErrors.Add('canonical_payload_sha256');$errors.Add('HASH_MISMATCH:canonical_payload_sha256')}
        $pairs=@(@('import_runner_path','import_runner_sha256'),@('authorization_builder_path','authorization_builder_sha256'),@('authorization_validator_path','authorization_validator_sha256'),@('sealed_baseline_path','sealed_baseline_sha256'),@('import_pass1_manifest_path','import_pass1_manifest_sha256'),@('import_pass2_manifest_path','import_pass2_manifest_sha256'),@('warmup_log_path','warmup_log_sha256'),@('class_cache_path','class_cache_sha256'),@('class_cache_source_baseline_path','class_cache_source_baseline_sha256'),@('formal_gate_1_79_receipt_path','formal_gate_1_79_receipt_sha256'),@('import_finalizer_dry_run_path','import_finalizer_dry_run_evidence_sha256'),@('godot_path','godot_executable_sha256'),@('project_godot_path','project_godot_sha256'),@('cursor_runbook_path','cursor_runbook_sha256'),@('import_controller_path','import_controller_sha256'),@('import_controller_receipt_path','import_controller_receipt_sha256'),@('bound_import_engine_path','bound_import_engine_sha256'),@('import_finalizer_path','import_finalizer_sha256'),@('selftest_manifest_path','selftest_manifest_sha256'),@('formal_dry_run_path','formal_dry_run_sha256'),@('tooling_seal_path','tooling_seal_sha256'),@('old_attempt18_manifest_path','old_attempt18_manifest_sha256'))
        foreach($pair in $pairs){$path=[string]$manifest.($pair[0]);if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$pathErrors.Add($pair[0]);$errors.Add("PATH_MISMATCH:$($pair[0])")}elseif((Get-Sha256 $path)-cne[string]$manifest.($pair[1])){$hashErrors.Add($pair[1]);$errors.Add("HASH_MISMATCH:$($pair[1])")}}
        foreach($tool in @($manifest.authorized_tooling_files)){if(-not(Test-Path -LiteralPath ([string]$tool.path) -PathType Leaf)){$pathErrors.Add("authorized_tooling:$($tool.relative_path)");$errors.Add("PATH_MISMATCH:authorized_tooling:$($tool.relative_path)")}elseif((Get-Sha256 ([string]$tool.path))-cne[string]$tool.sha256){$hashErrors.Add("authorized_tooling:$($tool.relative_path)");$errors.Add("HASH_MISMATCH:authorized_tooling:$($tool.relative_path)")}}
        if(@($manifest.authorized_tooling_files).Count -ne [int]$manifest.authorized_tooling_file_count){$errors.Add('AUTHORIZED_TOOLING_COUNT_MISMATCH')}
        $baseline=$null;try{$baseline=Get-Content -Raw -LiteralPath $manifest.sealed_baseline_path|ConvertFrom-Json -Depth 100}catch{}
        if($null -eq $baseline -or [string]$baseline.schema -cne 'SpaceSyndicatePostImportAuthorityBaselineV2' -or -not[bool]$baseline.post_import_baseline_sealed -or [string]$baseline.head_sha -cne $ExpectedProductHead -or [string]$baseline.tree_sha -cne $ExpectedProductTree -or [string]$baseline.godot_sha256 -cne [string]$manifest.godot_executable_sha256 -or [string]$baseline.project_godot_sha256 -cne [string]$manifest.project_godot_sha256 -or [string]$baseline.class_cache_sha256 -cne [string]$manifest.class_cache_sha256 -or [string]$baseline.import_pass_1_manifest_sha256 -cne [string]$manifest.import_pass1_manifest_sha256 -or [string]$baseline.import_pass_2_manifest_sha256 -cne [string]$manifest.import_pass2_manifest_sha256){$errors.Add('SEALED_BASELINE_CONTRACT_MISMATCH')}
        $cache=Get-Item -LiteralPath $manifest.class_cache_path -ErrorAction SilentlyContinue
        $sourceBaseline=$null;try{$sourceBaseline=Get-Content -Raw -LiteralPath $manifest.class_cache_source_baseline_path|ConvertFrom-Json -Depth 100}catch{}
        $oldAttempt=$null;try{$oldAttempt=Get-Content -Raw -LiteralPath $manifest.old_attempt18_manifest_path|ConvertFrom-Json -Depth 100}catch{}
        if($null -eq $cache -or $cache.Length -ne [long]$manifest.class_cache_bytes -or [string]$manifest.class_cache_product_head_sha -cne $ExpectedProductHead -or [string]$manifest.class_cache_product_tree_sha -cne $ExpectedProductTree -or [string]$manifest.class_cache_godot_version -cne [string]$manifest.godot_version -or [string]$manifest.class_cache_godot_executable_sha256 -cne [string]$manifest.godot_executable_sha256 -or $null -eq $sourceBaseline -or -not[bool]$sourceBaseline.post_import_baseline_sealed -or [string]$sourceBaseline.head_sha -cne $ExpectedProductHead -or [string]$sourceBaseline.tree_sha -cne $ExpectedProductTree -or [string]$sourceBaseline.class_cache_sha256 -cne [string]$manifest.class_cache_sha256 -or $null -eq $oldAttempt -or [string]$oldAttempt.import_authority.post_import_baseline.sha256 -cne [string]$manifest.class_cache_source_baseline_sha256){$errors.Add('CLASS_CACHE_CONTRACT_MISMATCH')}
        $controllerReceipt=$null;try{$controllerReceipt=Get-Content -Raw -LiteralPath $manifest.import_controller_receipt_path|ConvertFrom-Json -Depth 100}catch{}
        if($null -eq $controllerReceipt -or [string]$controllerReceipt.status -cne 'PASS' -or [string]$controllerReceipt.product_head_sha -cne $ExpectedProductHead -or [string]$controllerReceipt.product_tree_sha -cne $ExpectedProductTree -or [string]$controllerReceipt.import_controller_sha256 -cne [string]$manifest.import_controller_sha256 -or [string]$controllerReceipt.bound_import_engine_sha256 -cne [string]$manifest.bound_import_engine_sha256 -or [string]$controllerReceipt.sealed_baseline_sha256 -cne [string]$manifest.sealed_baseline_sha256 -or [string]$controllerReceipt.import_pass1_manifest_sha256 -cne [string]$manifest.import_pass1_manifest_sha256 -or [string]$controllerReceipt.import_pass2_manifest_sha256 -cne [string]$manifest.import_pass2_manifest_sha256 -or [string]$controllerReceipt.warmup_log_sha256 -cne [string]$manifest.warmup_log_sha256 -or [string]$controllerReceipt.class_cache_sha256 -cne [string]$manifest.class_cache_sha256 -or -not[bool]$controllerReceipt.class_cache_byte_identical_to_attempt18 -or [string]$controllerReceipt.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $controllerReceipt)){$errors.Add('IMPORT_CONTROLLER_RECEIPT_MISMATCH')}
        $receipt=$null;try{$receipt=Get-Content -Raw -LiteralPath $manifest.formal_gate_1_79_receipt_path|ConvertFrom-Json -Depth 100}catch{}
        if($null -eq $receipt -or [string]$receipt.schema -cne [string]$manifest.formal_gate_1_79_receipt_schema_version -or [string]$receipt.head_sha -cne $ExpectedProductHead -or [string]$receipt.tree_sha -cne $ExpectedProductTree -or [string]$manifest.formal_gate_1_79_receipt_head_sha -cne $ExpectedProductHead -or [string]$manifest.formal_gate_1_79_receipt_tree_sha -cne $ExpectedProductTree -or [int]$receipt.gate_count -ne 79 -or [int]$receipt.pass_count -ne 79 -or [int]$receipt.fail_count -ne 0 -or [int]$receipt.duplicate_gate_count -ne 0 -or [int]$receipt.missing_gate_count -ne 0 -or @($receipt.gate_rows).Count -ne 79 -or @($receipt.gate_rows.gate_id|Sort-Object -Unique).Count -ne 79 -or [int]$manifest.formal_gate_1_79_receipt_gate_count -ne 79 -or [int]$manifest.formal_gate_1_79_receipt_pass_count -ne 79 -or [int]$manifest.formal_gate_1_79_receipt_fail_count -ne 0 -or [int]$manifest.formal_gate_1_79_receipt_duplicate_gate_count -ne 0 -or [int]$manifest.formal_gate_1_79_receipt_missing_gate_count -ne 0 -or [string]$receipt.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $receipt)){$errors.Add('FORMAL_RECEIPT_CONTRACT_MISMATCH')}
        $finalizer=$null;try{$finalizer=Get-Content -Raw -LiteralPath $manifest.import_finalizer_dry_run_path|ConvertFrom-Json -Depth 100}catch{}
        if($null -eq $finalizer -or [string]$finalizer.schema -cne [string]$manifest.import_finalizer_dry_run_schema_version -or [string]$finalizer.status -cne 'PASS' -or [string]$finalizer.product_head_sha -cne $ExpectedProductHead -or [string]$finalizer.product_tree_sha -cne $ExpectedProductTree -or [string]$manifest.import_finalizer_dry_run_product_head_sha -cne $ExpectedProductHead -or [string]$manifest.import_finalizer_dry_run_product_tree_sha -cne $ExpectedProductTree -or [string]$finalizer.tooling_head_sha -cne $ExpectedToolingHead -or [string]$finalizer.tooling_tree_sha -cne $ExpectedToolingTree -or [string]$manifest.import_finalizer_dry_run_tooling_head_sha -cne $ExpectedToolingHead -or [string]$manifest.import_finalizer_dry_run_tooling_tree_sha -cne $ExpectedToolingTree -or [string]$finalizer.import_runner_sha256 -cne [string]$manifest.import_runner_sha256 -or [string]$manifest.import_finalizer_dry_run_import_runner_sha256 -cne [string]$manifest.import_runner_sha256 -or [string]$finalizer.baseline_sha256 -cne [string]$manifest.sealed_baseline_sha256 -or [string]$manifest.import_finalizer_dry_run_baseline_sha256 -cne [string]$manifest.sealed_baseline_sha256 -or [int]$finalizer.formal_mcp_count -ne 0 -or [int]$finalizer.product_game_count -ne 0 -or [int]$finalizer.unknown_file_delete_count -ne 0 -or [int]$finalizer.user_file_delete_count -ne 0 -or [int]$finalizer.outside_root_delete_count -ne 0 -or -not[bool]$finalizer.forensics_preservation_green -or -not[bool]$finalizer.safe_discard_green -or [string]$finalizer.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $finalizer)){$errors.Add('FINALIZER_DRY_RUN_CONTRACT_MISMATCH')}
        $selftest=$null;try{$selftest=Get-Content -Raw -LiteralPath $manifest.selftest_manifest_path|ConvertFrom-Json -Depth 100}catch{}
        if($null -eq $selftest -or [string]$selftest.status -cne 'PASS' -or [int]$selftest.case_count -lt 15 -or [int]$selftest.case_count -ne [int]$selftest.pass_count -or [int]$selftest.missing_prerequisite_false_accept_count -ne 0 -or [int]$selftest.stale_tooling_false_accept_count -ne 0 -or [string]$selftest.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $selftest)){$errors.Add('SELFTEST_CONTRACT_MISMATCH')}
        $seal=$null;try{$seal=Get-Content -Raw -LiteralPath $manifest.tooling_seal_path|ConvertFrom-Json -Depth 100}catch{}
        if($null -eq $seal -or [string]$seal.status -cne 'SEALED' -or [string]$seal.product_head_sha -cne $ExpectedProductHead -or [string]$seal.product_tree_sha -cne $ExpectedProductTree -or [string]$seal.tooling_head_sha -cne $ExpectedToolingHead -or [string]$seal.tooling_tree_sha -cne $ExpectedToolingTree -or [string]$seal.import_runner_sha256 -cne [string]$manifest.import_runner_sha256 -or [string]$seal.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $seal)){$errors.Add('TOOLING_SEAL_CONTRACT_MISMATCH')}
    }
    return [pscustomobject][ordered]@{status=if($errors.Count -eq 0){'PASS'}else{'BLOCKED'};declared_field_count=$names.Count;validated_field_count=if($errors.Count -eq 0){$required.Count}else{[Math]::Max(0,$required.Count-$missing.Count-$typeErrors.Count)};field_mismatch_count=$errors.Count;missing_required_field_count=$missing.Count;unknown_required_field_count=$unknown.Count;type_mismatch_count=$typeErrors.Count;hash_mismatch_count=$hashErrors.Count;path_mismatch_count=$pathErrors.Count;product_identity_match=-not($errors -contains 'PRODUCT_IDENTITY_MISMATCH');tooling_identity_match=-not($errors -contains 'TOOLING_IDENTITY_MISMATCH');godot_identity_match=-not($errors -contains 'SEALED_BASELINE_CONTRACT_MISMATCH');baseline_match=-not($errors -contains 'SEALED_BASELINE_CONTRACT_MISMATCH');class_cache_match=-not($errors -contains 'CLASS_CACHE_CONTRACT_MISMATCH');formal_gate_receipt_match=-not($errors -contains 'FORMAL_RECEIPT_CONTRACT_MISMATCH');finalizer_dry_run_match=-not($errors -contains 'FINALIZER_DRY_RUN_CONTRACT_MISMATCH');errors=@($errors)}
}

Export-ModuleMember -Function *
