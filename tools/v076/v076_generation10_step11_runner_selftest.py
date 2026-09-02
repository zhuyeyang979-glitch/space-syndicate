#!/usr/bin/env python3
"""Static fail-closed audit for the dual-mode Generation 10 STEP11 runner."""

from __future__ import annotations

import json
import copy
import re
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[2]
runner_path = root / "tools" / "v076_generation10_step11_runner.ps1"
text = runner_path.read_text(encoding="utf-8")

before_launch = text[: text.index("$launchRaw = & $launchTool")]
after_launch = text[text.index("$launchRaw = & $launchTool") :]

checks = {
    "authorization_id": "USER_AUTHORIZATION_V076_GENERATION10_REPAIRED_RUNNER_FORMAL_20260902" in text,
    "generation_id": "$generationId = 10" in text,
    "evidence_id": "$evidenceId = 9696" in text,
    "seed": "917592522" in text,
    "main_scene": "play_main_scene" in text and "res://scenes/main.tscn" in text,
    "one_mcp_three_ai_profile": "player_count=4" in text,
    "mode_allowlist": "[ValidateSet('NONFORMAL_CONFIRMATION','FORMAL')]" in text,
    "nonformal_forbids_confirmation_input": "NONFORMAL_CONFIRMATION_RECEIPT_INPUT_FORBIDDEN" in text,
    "formal_requires_confirmation": "FORMAL_CONFIRMATION_RECEIPT_REQUIRED" in before_launch,
    "formal_confirmation_before_launch": before_launch.count("confirmationChecks") >= 12,
    "confirmation_head_tree_binding": all(token in before_launch for token in ("confirmation.execution_head_sha", "confirmation.execution_tree_sha", "$head", "$tree")),
    "confirmation_runner_binding": "confirmation.runner_sha256" in before_launch and "Get-Sha256 $runnerPath" in before_launch,
    "confirmation_environment_binding": "confirmation.environment_seal_sha256" in before_launch and "Get-Sha256 $environmentSealPath" in before_launch,
    "confirmation_result_binding": "confirmation.execution_result_sha256" in before_launch and "Get-Sha256 $confirmationResultPath" in before_launch,
    "confirmation_canonical_binding": "canonical_payload_sha256_match" in before_launch and "Get-ObjectPayloadSha256" in before_launch,
    "confirmation_cleanup_binding": "result_cleanup_pass" in before_launch and "forced_stop" in before_launch,
    "nonformal_budget_zero": "execution_class='NONFORMAL_CONFIRMATION'" in text and "formal_execution_count=0" in text,
    "formal_consumption_guarded": "if ($ExecutionClass -eq 'FORMAL')" in after_launch,
    "consumption_after_launch": text.index("$formalConsumed = $true") > text.index("$launchRaw = & $launchTool"),
    "automatic_retry_zero": "automatic_retry_count=0" in text and "automatic_retry" in text,
    "empty_evidence_root_required": "EVIDENCE_ROOT_NOT_EMPTY" in before_launch,
    "preflight_before_launch": text.index("$preflightPass =") < text.index("$launchRaw = & $launchTool"),
    "boot_guard": "boot_id_actual" in text and "boot_id_expected" in text,
    "stability_guard": "new_stability_event_count" in text,
    "stability_guard_utc_to_local_boundary": "StartTime=$stabilityStart.ToLocalTime()" in text and "TimeCreated.ToUniversalTime() -ge $stabilityStart" in text,
    "stability_guard_invariant_rfc3339_parse": "[DateTimeOffset]::Parse(" in text and ").UtcDateTime" in text,
    "stability_guard_json_timestamp_kept_as_string": text.count("ConvertFrom-Json -Depth 100 -DateKind String") >= 4,
    "commit_guard": "available_commit_bytes" in text and "8589934592" in text,
    "head_tree_guard": "head_matches_environment_commit" in text and "tree_matches_head" in text,
    "import_guard": "import_pending_count" in text,
    "process_guard": "godot_process_count" in text and "listener_count" in text,
    "seal_guards": all(token in text for token in ("qualification_seal_sha256_match", "pass_pair_sha256_match", "post_restart_seal_sha256_match")),
    "pre_execution_blocked": "PRE_EXECUTION_BLOCKED" in text and "generation10_formal_execution_count=0" in text,
    "seed_external_focus": "external-seed-focus-request.json" in text and "external-seed-focus-complete.json" in text,
    "seed_characters_mcp_only": "seed-entry.jsonrpc.json" in text and "direct_runtime_seed_injection_count" in text,
    "cua_focus_not_overwritten_by_mcp_mouse": "seed-runtime-focus-confirmation.jsonrpc.json" not in text,
    "commercial_menu_navigation": "开始新局" in text and "START_OVERLAY_OCCLUDED" in text,
    "button_discovery_unique_names": all(token in text for token in ('"{0}-branch-{1:d3}.jsonrpc.json"', '"{0}-candidate-{1:d3}.jsonrpc.json"')),
    "runtime_ready_unique_names": "runtime-ready-poll-{0:d3}.jsonrpc.json" in text,
    "overlay_unique_names": "start-overlay-{0:d3}.jsonrpc.json" in text and "commercial-overlay-{0:d3}.jsonrpc.json" in text,
    "track_idle_unique_names": "track-acquire-idle-{0:d3}.jsonrpc.json" in text,
    "card_submission_idle_unique_names": "batch{0}-card{1}-idle-{2:d3}.jsonrpc.json" in text and '"batch$Batch-card$Card-idle.jsonrpc.json"' not in text,
    "monotonic_nonformal_identity_parameter": "[ValidatePattern('^nonformal-confirmation-[0-9]{3}$')]" in text and "nonformal_confirmation_id=$NonformalConfirmationId" in text,
    "resolution_unique_names": "military-private-owner-resolution-poll-{0:d3}.jsonrpc.json" in text,
    "no_known_poll_collision_names": all(token not in text for token in ("'runtime-ready-poll.jsonrpc.json'", "'start-overlay.jsonrpc.json'", "'commercial-overlay.jsonrpc.json'", "'track-acquire-idle.jsonrpc.json'", "'military-private-owner-resolution-poll.jsonrpc.json'")),
    "button_discovery_truncated_tree_fallback": "$rootQuery.tree_truncated" in text and "children_truncated" in text and "CommercialShellSurfaceLayer" in text,
    "button_discovery_bounded_recursive_reuse": "[Collections.Generic.Queue[string]]" in text and "$branchIndex -ge 24" in text,
    "track_card_acquisition": "military.air_superiority_fighter.shipping.rank_1" in text and "confirm-military-track-acquire" in text,
    "natural_normal_batches": "Complete-NormalBatch -Batch 1" in text and "Complete-NormalBatch -Batch 2" in text,
    "natural_default_pace": "Set-Speed -Multiplier" not in text and "V075PacingControls/Speed" not in text,
    "assault_region_ui": "选择地区" in text and "FIRST_ENABLED_NON_ORIGIN_LOCAL_CARD_ASSAULT_REGION_BY_OPTION_ID" in text and "batch3-confirm-military-action" in text,
    "natural_eta_wait": "MILITARY_NATURAL_RESOLUTION_TIMEOUT" in text and "_damage_settlement_by_id" in text,
    "major_round_barrier": "Wait-And-Finish-EmptyBatch -Batch 3" in text and "Wait-And-Finish-EmptyBatch -Batch 4" in text,
    "runtime_witnesses": all(token in text for token in ("final-private-owner", "final-eta-owner", "final-kernel", "final-runtime-owner", "final-legacy-combat-writer")),
    "headed_screenshots": text.count("Capture-View -Name") >= 4,
    "normal_cleanup": "exit_play_mode" in text and "stop_role_godot_mcp" in text,
    "normal_cleanup_rejects_forced_stop": "-not $cleanup.forced_stop" in text and "$cleanup.game_pid_after -eq 0" in text,
    "no_fixture_path": "tests/fixtures" not in text and "fixture_card" not in text,
    "no_direct_internal_method": "call_runtime_method" not in text and "execute_runtime_method" not in text,
    "no_action_injection": "fixture_action_injection" not in text and "root_command_injection" not in text,
    "no_pagefile_change": "pagefile" not in text.lower() and "wmic pagefileset" not in text.lower(),
    "no_reboot": not re.search(r"\b(Restart-Computer|shutdown\.exe|shutdown /r)\b", text, re.IGNORECASE),
    "no_probe_launch": "platform_probe" not in text,
    "generation9_history_not_mutated": "generation-009" not in text and "generation9_formal" not in text,
    "external_output_required": "[Parameter(Mandatory = $true)][string]$EvidenceRoot" in text,
    "fail_closed_exit": "if ($status -ne 'PASS') { exit 1 }" in text,
}

guard_lines = [line.strip() for line in text.splitlines() if "@($checks.confirmation.GetEnumerator()" in line]
checks["confirmation_guard_enumerates_entries_not_properties"] = len(guard_lines) == 1 and "$checks.confirmation.PSObject.Properties" not in text
pwsh = shutil.which("pwsh")
guard = guard_lines[0].removesuffix(" -and") if len(guard_lines) == 1 else "$false"
for name, required, present, status, expected in (
    ("nonformal_valid", False, True, True, True),
    ("formal_valid", True, True, True, True),
    ("formal_missing_receipt", True, False, True, False),
    ("formal_failed_receipt", True, True, False, False),
):
    values = ["$true" if value else "$false" for value in (required, present, status)]
    script = "$checks=[ordered]@{confirmation=[ordered]@{required=" + values[0] + ";receipt_present=" + values[1] + ";status_pass=" + values[2] + "}}; [bool](" + guard + ")"
    completed = subprocess.run([pwsh, "-NoProfile", "-NonInteractive", "-Command", script], capture_output=True, text=True, timeout=15) if pwsh else None
    checks[f"confirmation_guard_executes__{name}"] = completed is not None and completed.returncode == 0 and completed.stdout.strip() == str(expected)

checks["terminal_branch_explicit"] = "[switch]$Terminal" in text and "Wait-And-Finish-EmptyBatch -Batch 4 -Terminal" in text
checks["terminal_before_authority_captured"] = "step='terminal_before'" in text and "terminal-before-runtime.jsonrpc.json" in text
checks["terminal_waits_for_settled_fourth_batch"] = "[int]$p._batch_number -eq 4 -and [string]$p._phase -eq 'settled'" in text
checks["terminal_no_fifth_batch_oracle"] = "[int]$p._batch_number -eq 5" not in text
checks["terminal_final_authority_captured"] = any("'final-runtime-owner.jsonrpc.json'" in line and "'_solar_state'" in line for line in text.splitlines())
checks["screen_projection_owner_binding"] = all("'_v075_snapshot'" not in line for line in text.splitlines() if "-Path $runtimePath -Properties" in line)
track_filter = next(line for line in text.splitlines() if "$trackCards =" in line)
checks["track_geometry_uses_production_track_script"] = "res://scripts/ui/v074/v074_track_card_button.gd" in track_filter and "v075_interactive_card_face" not in track_filter
checks["card_filter_scripts_exist"] = all((root / path.removeprefix("res://")).is_file() for path in re.findall(r"script_path -eq '(res://[^']+)'", text))
checks["military_target_no_fixed_region"] = "region.005" not in text and "$selectedTargetRegion" in text
checks["military_target_witness_captured"] = "step='military_target'" in text and "eligible_options=$options" in text and "bound_option=$bound._pending_confirm_binding" in text
checks["military_target_local_card_and_enabled"] = "[bool]$_.enabled" in text and "[string]$_.owner_player_id -ceq 'player.local'" in text and "[string]$_.card_instance_id -ceq $militaryInstanceId" in text
checks["military_default_selection_readback"] = "MILITARY_DEFAULT_MENU_SELECTION_MISMATCH" in text and "'selected','item_count','text'" in text and "menu_selected_index=[int]$menuSelection.selected" in text
bridge_source = (root / "addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd").read_text(encoding="utf-8")
key_names = set(re.findall(r'"([a-z]+)": KEY_', bridge_source))
checks["all_literal_runtime_keys_supported"] = set(re.findall(r"key='([^']+)'", text)).issubset(key_names)
checks["screen_projection_wait_used"] = "Wait-ScreenProjection -Name 'initial-track-snapshot'" in text and "Wait-ScreenProjection -Name 'batch3-hand'" in text and "SCREEN_PROJECTION_PROPERTY_MISSING" in text
checks["runtime_source_does_not_fake_screen_fields"] = "$finalRuntime._v075_snapshot" not in text and "'final-production-screen.jsonrpc.json' -Path $screenPath" in text
exit_function = text[text.index("function Test-ExitPlayModeResponse {"):text.index("function Stop-Normally {")]
for name, response, expected in (
    ("plain_text_success", {"result": {"isError": False, "content": [{"type": "text", "text": "Stopped the running scene."}]}}, True),
    ("error_envelope", {"error": {"message": "failure"}, "result": {"isError": False, "content": [{"type": "text", "text": "Stopped the running scene."}]}}, False),
    ("is_error", {"result": {"isError": True, "content": [{"type": "text", "text": "Stopped the running scene."}]}}, False),
    ("unknown_text", {"result": {"isError": False, "content": [{"type": "text", "text": "Unknown command"}]}}, False),
    ("missing_error_flag", {"result": {"content": [{"type": "text", "text": "Stopped the running scene."}]}}, False),
    ("empty_result", {}, False),
):
    encoded = json.dumps(response).replace("'", "''")
    script = exit_function + "\nTest-ExitPlayModeResponse ('" + encoded + "' | ConvertFrom-Json -Depth 20)"
    completed = subprocess.run([pwsh, "-NoProfile", "-NonInteractive", "-Command", script], capture_output=True, text=True, timeout=15) if pwsh else None
    checks[f"exit_response_executes__{name}"] = completed is not None and completed.returncode == 0 and completed.stdout.strip() == str(expected)

ready_function = text[text.index("function Test-FreshRuntimeReady {"):text.index("function Query-Node {")]
ready_base = {"installed": True, "script_exists": True, "state_exists": True, "state_age_msec": 500, "state_modified_unix": 1788349500, "state": {"status": "running", "timestamp": "2026-09-02 11:45:00", "current_scene": {"path": "/root/Main", "scene_file_path": "res://scenes/main.tscn"}, "runtime_event_cursor": {"stream_id": "new-run"}}}
ready_cases = [("fresh_new_run", ready_base, True)]
for name, mutate in {
    "old_heartbeat": lambda v: v.update(state_age_msec=167783, state_modified_unix=1788349165),
    "missing_age": lambda v: v.pop("state_age_msec"),
    "negative_age": lambda v: v.update(state_age_msec=-1),
    "boolean_age": lambda v: v.update(state_age_msec=False),
    "string_age": lambda v: v.update(state_age_msec="500"),
    "excess_age": lambda v: v.update(state_age_msec=2001),
    "missing_mtime": lambda v: v.pop("state_modified_unix"),
    "future_mtime": lambda v: v.update(state_modified_unix=1788349502),
    "pre_play_mtime": lambda v: v.update(state_modified_unix=1788349498),
    "missing_timestamp": lambda v: v["state"].pop("timestamp"),
    "pre_play_timestamp": lambda v: v["state"].update(timestamp="2026-09-02 11:39:25"),
    "wrong_scene": lambda v: v["state"]["current_scene"].update(scene_file_path="res://tests/fixture.tscn"),
    "wrong_root": lambda v: v["state"]["current_scene"].update(path="/root/Other"),
    "stopped": lambda v: v["state"].update(status="stopped"),
    "missing_state": lambda v: v.pop("state"),
    "missing_stream": lambda v: v["state"].pop("runtime_event_cursor"),
    "same_previous_stream": lambda v: v["state"]["runtime_event_cursor"].update(stream_id="prior-run"),
    "not_installed": lambda v: v.update(installed=False),
    "state_exists_string": lambda v: v.update(state_exists="true"),
}.items():
    candidate = copy.deepcopy(ready_base)
    mutate(candidate)
    ready_cases.append((name, candidate, False))
for name, response, expected in ready_cases:
    encoded = json.dumps(response).replace("'", "''")
    script = ready_function + "\nTest-FreshRuntimeReady -Status ('" + encoded + "' | ConvertFrom-Json -Depth 20) -PlayRequestedUnix 1788349499 -PreviousStreamId 'prior-run' -ObservedUnix 1788349501"
    completed = subprocess.run([pwsh, "-NoProfile", "-NonInteractive", "-Command", script], capture_output=True, text=True, timeout=15) if pwsh else None
    checks[f"fresh_runtime_guard_executes__{name}"] = completed is not None and completed.returncode == 0 and completed.stdout.strip() == str(expected)
checks["fresh_runtime_guard_controls_poll_exit"] = "$runtimeReady = Test-FreshRuntimeReady" in after_launch and "if ($runtimeReady) { break }" in after_launch and "if (-not $runtimeReady) { throw 'FRESH_RUNTIME_READY_TIMEOUT' }" in after_launch
checks["new_play_clock_captured_before_play"] = text.index("$playRequestedUnix =") < text.index("Invoke-RoleTool -ToolName 'play_main_scene'")
checks["fresh_runtime_identity_witness_recorded"] = "step='runtime_ready'" in text and "previous_stream_id=$previousRuntimeStreamId" in text
checks["non_origin_target_uses_local_public_facilities"] = "MIN_OWNED_PUBLIC_FACILITY_REGION" in text and "map_player_projection.public_facility_slots" in text and "owner_public_id -ceq 'player.local'" in text and "target_region_id -cne $sourceRegionId" in text
checks["non_origin_target_menu_readback"] = "MILITARY_NON_ORIGIN_MENU_SELECTION_MISMATCH" in text and "batch3-selected-region-readback.jsonrpc.json" in text
checks["popup_initial_keyboard_focus_accounted_for"] = "for ($i = 0; $i -le $regionIndex; $i++)" in text
checks["positive_eta_required_before_wait"] = "POSITIVE_PHYSICAL_ETA_NOT_ESTABLISHED" in text and text.index("POSITIVE_PHYSICAL_ETA_NOT_ESTABLISHED") < text.index("$resolutionDeadline =")
checks["runtime_fault_fails_fast"] = "RUNTIME_FAULT_OBSERVED:$Name" in text
checks["runtime_fault_diagnostics_before_cleanup"] = all(token in text for token in ("failure-action-status.jsonrpc.json", "failure-runtime-owner.jsonrpc.json", "failure-private-owner.jsonrpc.json", "failure-main-table"))
checks["source_contract_checked_before_result_and_confirmation"] = text.index("inspect-source") < text.index("Write-Json -Path $resultPath") < text.index("Write-Json -Path $confirmationOutputPath")
checks["source_contract_failure_finalizes_failed_result"] = "SOURCE_CONTRACT_VALIDATION_FAILED" in text and "$result.status = 'FAIL'" in text

failed = sorted(name for name, ok in checks.items() if not ok)
result = {
    "schema_version": "space_syndicate.v076.generation10_step11_runner_selftest.v1",
    "status": "PASS" if not failed else "FAIL",
    "case_count": len(checks),
    "pass_count": len(checks) - len(failed),
    "false_green_count": 0 if not failed else len(failed),
    "failed_cases": failed,
    "runner_path": "tools/v076_generation10_step11_runner.ps1",
}
print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
raise SystemExit(0 if not failed else 1)
