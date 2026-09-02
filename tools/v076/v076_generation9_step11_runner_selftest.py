#!/usr/bin/env python3
"""Static launch-safety audit for the one-shot Generation 9 formal runner."""

from __future__ import annotations

import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
runner_path = root / "tools" / "v076_generation9_step11_formal.ps1"
text = runner_path.read_text(encoding="utf-8")

checks = {
    "authorization_id": "USER_AUTHORIZATION_V076_COMMIT_CAPACITY_AND_GENERATION9_20260902" in text,
    "generation_id": "$generationId = 9" in text,
    "evidence_id": "$evidenceId = 9695" in text,
    "seed": "917592522" in text,
    "main_scene": "play_main_scene" in text and "res://scenes/main.tscn" in text,
    "one_mcp_three_ai_profile": "player_count=4" in text,
    "preflight_before_launch": text.index("$preflightPass =") < text.index("$launchRaw = & $launchTool"),
    "boot_guard": "boot_id_actual" in text and "boot_id_expected" in text,
    "stability_guard": "new_stability_event_count" in text,
    "stability_guard_utc_to_local_boundary": "StartTime=$stabilityStart.ToLocalTime()" in text and "TimeCreated.ToUniversalTime() -ge $stabilityStart" in text,
    "stability_guard_invariant_rfc3339_parse": "[DateTimeOffset]::Parse(" in text and "[Globalization.CultureInfo]::InvariantCulture" in text and "[Globalization.DateTimeStyles]::AssumeUniversal" in text and ").UtcDateTime" in text,
    "stability_guard_json_timestamp_kept_as_string": text.count("ConvertFrom-Json -Depth 100 -DateKind String") >= 2,
    "commit_guard": "available_commit_bytes" in text and "8589934592" in text,
    "head_tree_guard": "head_matches_environment_commit" in text and "tree_matches_head" in text,
    "import_guard": "import_pending_count" in text,
    "process_guard": "godot_process_count" in text and "listener_count" in text,
    "seal_guards": all(token in text for token in ("qualification_seal_sha256_match", "pass_pair_sha256_match", "post_restart_seal_sha256_match")),
    "pre_execution_blocked": "PRE_EXECUTION_BLOCKED" in text and "generation9_formal_execution_count=0" in text,
    "consumption_after_launch": text.index("$formalConsumed = $true") > text.index("$launchRaw = & $launchTool"),
    "formal_exact_once": "formal_execution_count=1" in text and "automatic_retry_count=0" in text,
    "seed_external_focus": "external-seed-focus-request.json" in text and "external-seed-focus-complete.json" in text,
    "seed_characters_mcp_only": "seed-entry.jsonrpc.json" in text and "direct_runtime_seed_injection_count" in text,
    "cua_focus_not_overwritten_by_mcp_mouse": "seed-runtime-focus-confirmation.jsonrpc.json" not in text,
    "commercial_menu_navigation": "开始新局" in text and "START_OVERLAY_OCCLUDED" in text,
    "button_discovery_no_poll_evidence_collision": "$Name-tree.jsonrpc.json" not in text and '"{0}-branch-{1:d3}.jsonrpc.json"' in text and '"{0}-candidate-{1:d3}.jsonrpc.json"' in text,
    "button_discovery_truncated_tree_fallback": "$rootQuery.tree_truncated" in text and "children_truncated" in text and "CommercialShellSurfaceLayer" in text,
    "button_discovery_bounded_recursive_reuse": "[Collections.Generic.Queue[string]]" in text and "$branchIndex -ge 24" in text and "BUTTON_DISCOVERY_BRANCH_BUDGET_EXCEEDED" in text,
    "track_card_acquisition": "military.air_superiority_fighter.shipping.rank_1" in text and "confirm-military-track-acquire" in text,
    "natural_normal_batches": "Complete-NormalBatch -Batch 1" in text and "Complete-NormalBatch -Batch 2" in text,
    "natural_default_pace": "Set-Speed -Multiplier" not in text and "V075PacingControls/Speed" not in text,
    "no_hidden_pacing_control_click": "$speed1Path" not in text and "$speed4Path" not in text,
    "assault_region_ui": "选择地区" in text and "region.005" in text and "batch3-confirm-military-action" in text,
    "natural_eta_wait": "MILITARY_NATURAL_RESOLUTION_TIMEOUT" in text and "_damage_settlement_by_id" in text,
    "major_round_barrier": "Wait-And-Finish-EmptyBatch -Batch 3" in text and "Wait-And-Finish-EmptyBatch -Batch 4" in text and "_batch_number -eq 5" in text,
    "runtime_witnesses": all(token in text for token in ("final-private-owner", "final-eta-owner", "final-kernel", "final-runtime-owner", "final-legacy-combat-writer")),
    "screen_authority_witness": "final-production-screen" in text and "acceptance_state" in text,
    "headed_screenshots": text.count("Capture-View -Name") >= 4,
    "normal_cleanup": "exit_play_mode" in text and "stop_role_godot_mcp" in text,
    "normal_cleanup_rejects_forced_stop": "-not $cleanup.forced_stop" in text and "$cleanup.game_pid_after -eq 0" in text,
    "no_fixture_path": "tests/fixtures" not in text and "fixture_card" not in text,
    "no_direct_internal_method": "call_runtime_method" not in text and "execute_runtime_method" not in text,
    "no_action_injection": "fixture_action_injection" not in text and "root_command_injection" not in text,
    "no_pagefile_change": "pagefile" not in text.lower() and "wmic pagefileset" not in text.lower(),
    "no_reboot": not re.search(r"\b(Restart-Computer|shutdown\.exe|shutdown /r)\b", text, re.IGNORECASE),
    "no_probe_launch": "platform_probe" not in text,
    "no_generation10": "generation10" not in text.lower(),
    "external_output_required": "[Parameter(Mandatory = $true)][string]$EvidenceRoot" in text,
    "fail_closed_exit": "if ($status -ne 'PASS') { exit 1 }" in text,
}

failed = sorted(name for name, ok in checks.items() if not ok)
result = {
    "schema_version": "space_syndicate.v076.generation9_step11_runner_selftest.v1",
    "status": "PASS" if not failed else "FAIL",
    "case_count": len(checks),
    "pass_count": len(checks) - len(failed),
    "false_green_count": 0 if not failed else len(failed),
    "failed_cases": failed,
    "runner_path": "tools/v076_generation9_step11_formal.ps1",
}
print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
raise SystemExit(0 if not failed else 1)
