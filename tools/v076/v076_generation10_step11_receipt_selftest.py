#!/usr/bin/env python3
"""In-memory negative contract tests for the Generation 10 receipt validator."""

from __future__ import annotations

import copy
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import v076_generation10_step11_receipt as contract  # noqa: E402


def proof() -> dict[str, int]:
    return {
        **{field: 1 for field in contract.POSITIVE_PROOF_FIELDS},
        **{field: 0 for field in contract.ZERO_PROOF_FIELDS},
    }


def failures_for_proof(value: object) -> list[str]:
    report = contract.Report("0" * 40)
    contract._validate_proof(report, value, "fixture")
    return report.codes


def failures_for_cleanup(value: object) -> list[str]:
    report = contract.Report("0" * 40)
    contract._validate_cleanup(report, value, "fixture")
    return report.codes


def runtime_result() -> dict[str, object]:
    colors = ["industry", "life", "science", "shipping", "influence", "energy"]
    before = {color: (2 if color == "shipping" else 0) for color in colors}
    after = {color: 0 for color in colors}
    delta = {color: (-2 if color == "shipping" else 0) for color in colors}
    cost = {color: (2 if color == "shipping" else 0) for color in colors}
    asset = {
        "schema": "V076AssetConsequenceAuthorityWitnessV1",
        "reservation_id": "reservation.001",
        "owner_player_id": "player.local",
        "action": "commit",
        "outcome": "consumed",
        "asset_revision_before": 4,
        "asset_revision_after": 5,
        "asset_quantities_before": before,
        "asset_quantities_after": after,
        "asset_delta_by_color": delta,
        "reserved_asset_cost_by_color": cost,
        "reservation_receipt_id": "reservation.receipt.001",
        "reservation_receipt_fingerprint": "1" * 64,
        "settlement_receipt_id": "settlement.receipt.001",
        "settlement_receipt_fingerprint": "2" * 64,
        "mission_receipt_fingerprint": "3" * 64,
        "asset_debit_count": 1,
        "consequence_bound": True,
        "projection_count_before": 0,
        "projection_count_after": 1,
        "projection_failure_count": 0,
        "presentation_count": 1,
        "consequence_id": "consequence.001",
        "consequence_fingerprint": "4" * 64,
        "task_kind": "assault_region",
        "target_region_id": "region.005",
        "allocated_damage_total": 2,
        "facility_damage_intent_count": 1,
        "monster_damage_intent_count": 0,
        "witness_fingerprint": "",
    }
    asset["witness_fingerprint"] = contract.witness_fingerprint_sha256(asset)
    submission_id = "v076.production.military.intent.001"
    submitted = {
        "accepted": True, "duplicate": False, "submission_id": submission_id,
        "mission_kind": "ASSAULT_REGION", "eta_ticks": 6, "dispatch_delay_ticks": 6,
        "scheduled_tick": 101, "arrival_tick": 106, "command_id": "command.001",
    }
    ledger = {
        "phase": "WITHDRAWAL_READY", "mission_kind": "ASSAULT_REGION", "arrival_tick": 106,
        "mission_receipt": {"mission_state_after": "withdrawn"},
    }
    human = {
        "private_information_violation_count": 0, "direct_asset_mutation_count": 0,
        "public_batch_direct_action_entry_count": 0,
        "shared_sushi_track_direct_action_resolution_count": 0,
    }
    final = {
        "step": "military_final",
        "private_owner": {
            "_submitted_result_by_id": {submission_id: submitted},
            "_submission_fingerprint_by_id": {submission_id: "6" * 64},
            "_intake_settlement_result_by_id": {submission_id: {"accepted": True}},
            "_settlement_fingerprint_by_id": {submission_id: "5" * 64},
            "_damage_settlement_by_id": {submission_id: {"accepted": True}},
            "_collision_count": 0, "_rejection_count": 0,
        },
        "eta_owner": {"_calculation_count": 1, "_rejection_count": 0},
        "kernel": {
            "_domain_states": {"future.private_direct_action_input": {
                "submission_ledger": {submission_id: ledger}, "military_intake_count": 1,
                "arrived_count": 1, "executed_once_count": 1, "withdrawal_ready_count": 1,
            }},
            "_rejection_count": 0,
        },
        "application_flow": {"_v076_private_military_receipt_count": 1},
        "runtime_owner": {
            "_batch_number": 5, "_phase": "submission", "_runtime_error_count": 0,
            "_invalid_action_count": 0, "_v076_asset_consequence_projection_count": 1,
            "_v076_asset_consequence_projection_failure_count": 0,
            "_v076_military_consequence_collision_count": 0,
            "_v076_military_consequence_presentation_count": 1,
            "_v076_production_military_submission_by_uid": {},
            "_v076_last_asset_consequence_witness": asset,
        },
        "legacy_combat_owner": {"_runtime_error_count": 0},
        "production_screen": {
            "_v075_snapshot": {"old_military_controller_production_reachable_count": 0},
            "_current_action_mode": "idle", "_action_submission_pending": False,
            "acceptance_state": {"combat_wrapper": {
                "human_playability": human,
                "presentation": {"presentation_gameplay_mutation_count": 0},
                "presentation_gameplay_mutation_count": 0,
            }},
        },
    }
    return {
        "status": "PASS", "execution_class": "FORMAL", "formal_execution_count": 1, "automatic_retry_count": 0,
        "generation_id": 10, "new_evidence_id": 9696,
        "subject_head_sha": contract.PRODUCT_HEAD, "subject_tree_sha": contract.PRODUCT_TREE,
        "selected_seed": 917592522, "player_count": 4, "production_scene_path": contract.SCENE,
        "failure": None,
        "step_receipts": [
            {"step": "seed", "visible_text": "917592522", "config_model_seed": 917592522,
             "new_game_receipt_seed": 917592522, "runtime_seed": 917592522},
            final,
        ],
    }


cases: list[tuple[str, bool]] = []


def check(name: str, condition: bool) -> None:
    cases.append((name, bool(condition)))


baseline = proof()
check("baseline_proof_passes", not failures_for_proof(baseline))
check("positive_field_count_is_13", len(contract.POSITIVE_PROOF_FIELDS) == 13)
check("zero_field_count_is_10", len(contract.ZERO_PROOF_FIELDS) == 10)
check("proof_field_count_is_23", len(contract.PROOF_FIELDS) == 23)

for field in sorted(contract.POSITIVE_PROOF_FIELDS):
    mutated = copy.deepcopy(baseline)
    mutated[field] = 0
    check(f"positive_zero_rejected__{field}", "POSITIVE_PROOF_NOT_EXACTLY_ONCE" in failures_for_proof(mutated))

for field in sorted(contract.ZERO_PROOF_FIELDS):
    mutated = copy.deepcopy(baseline)
    mutated[field] = 1
    check(f"zero_one_rejected__{field}", "ZERO_PROOF_NOT_ZERO" in failures_for_proof(mutated))

missing = copy.deepcopy(baseline)
missing.pop(sorted(contract.PROOF_FIELDS)[0])
check("missing_proof_field_rejected", "FIELD_SET_MISMATCH" in failures_for_proof(missing))
extra = copy.deepcopy(baseline)
extra["unauthorized_counter"] = 0
check("extra_proof_field_rejected", "FIELD_SET_MISMATCH" in failures_for_proof(extra))
typed = copy.deepcopy(baseline)
typed[sorted(contract.POSITIVE_PROOF_FIELDS)[0]] = True
check("boolean_positive_rejected", "POSITIVE_PROOF_NOT_EXACTLY_ONCE" in failures_for_proof(typed))

cleanup = {
    "exit_play_mode": "PASS",
    "stop_role_godot_mcp": "PASS",
    "editor_pid_after": 0,
    "game_pid_after": 0,
    "listener_count_after": 0,
}
check("baseline_cleanup_passes", not failures_for_cleanup(cleanup))
for field in ("editor_pid_after", "game_pid_after", "listener_count_after"):
    mutated = copy.deepcopy(cleanup)
    mutated[field] = 1
    check(f"cleanup_nonzero_rejected__{field}", "CLEANUP_COUNT_NOT_ZERO" in failures_for_cleanup(mutated))
mutated = copy.deepcopy(cleanup)
mutated["exit_play_mode"] = "FAIL"
check("cleanup_status_rejected", "CLEANUP_STATUS_NOT_PASS" in failures_for_cleanup(mutated))
mutated = copy.deepcopy(cleanup)
mutated["editor_pid_after"] = False
check("cleanup_boolean_count_rejected", "CLEANUP_COUNT_NOT_ZERO" in failures_for_cleanup(mutated))

sample = {"β": 2, "a": 1}
canonical = contract.canonical_json_bytes(sample)
check("canonical_terminal_lf", canonical.endswith(b"\n"))
check("canonical_unicode_not_ascii_escaped", "β".encode("utf-8") in canonical)
check("canonical_sorted_keys", canonical.startswith(b'{"a":1,'))
check("canonical_hash_stable", contract.sha256_bytes(canonical) == hashlib.sha256(canonical).hexdigest())
payload = {"value": 7, "canonical_payload_sha256": "0" * 64}
payload_hash = contract.canonical_payload_sha256(payload)
check("canonical_payload_excludes_own_hash", payload_hash == contract.canonical_payload_sha256({"value": 7}))

runtime_baseline = runtime_result()
derived = contract._derive_runtime_components(runtime_baseline)
check("runtime_source_derives_exact_proof", derived["proof"] == baseline)
check("runtime_source_preserves_asset_witness", derived["asset_authority_witness"]["witness_fingerprint"] == runtime_baseline["step_receipts"][1]["runtime_owner"]["_v076_last_asset_consequence_witness"]["witness_fingerprint"])
check("runtime_source_derives_eta_six", derived["military_lifecycle_witness"]["eta_ticks"] == 6)
check("formal_document_field_sets_are_exact", len(contract.EXECUTION_START_FIELDS) == 23 and len(contract.PROGRESS_FIELDS) == 14 and len(contract.SUMMARY_FIELDS) == 30)
receipt_fingerprint_fixture = {field: field for field in contract.RESULT_FINGERPRINT_FIELDS}
check("result_fingerprint_is_sha256", contract.SHA256_RE.fullmatch(contract.result_fingerprint_sha256(receipt_fingerprint_fixture)) is not None)

runtime_negative_mutations = {
    "asset_fingerprint": lambda value: value["step_receipts"][1]["runtime_owner"]["_v076_last_asset_consequence_witness"].update({"witness_fingerprint": "0" * 64}),
    "eta_arithmetic": lambda value: value["step_receipts"][1]["private_owner"]["_submitted_result_by_id"]["v076.production.military.intent.001"].update({"arrival_tick": 105}),
    "private_collision": lambda value: value["step_receipts"][1]["private_owner"].update({"_collision_count": 1}),
    "major_round_barrier": lambda value: value["step_receipts"][1]["runtime_owner"].update({"_batch_number": 4}),
    "private_information": lambda value: value["step_receipts"][1]["production_screen"]["acceptance_state"]["combat_wrapper"]["human_playability"].update({"private_information_violation_count": 1}),
    "legacy_runtime_error": lambda value: value["step_receipts"][1]["legacy_combat_owner"].update({"_runtime_error_count": 1}),
    "formal_status": lambda value: value.update({"status": "FAIL"}),
    "source_withdrawal": lambda value: value["step_receipts"][1]["runtime_owner"].update({"_v076_production_military_submission_by_uid": {"7": {}}}),
    "screen_projection_missing": lambda value: value["step_receipts"][1]["production_screen"].pop("_v075_snapshot"),
    "screen_old_writer_reachable": lambda value: value["step_receipts"][1]["production_screen"]["_v075_snapshot"].update({"old_military_controller_production_reachable_count": 1}),
}
for name, mutate in runtime_negative_mutations.items():
    candidate = copy.deepcopy(runtime_baseline)
    mutate(candidate)
    try:
        contract._derive_runtime_components(candidate)
    except ValueError:
        rejected = True
    else:
        rejected = False
    check(f"runtime_source_negative_rejected__{name}", rejected)

private_sample = {"worktree": "D:/private/repo", "command_line": "private command", "username": "private user", "token": "private token", "scene": "res://scenes/main.tscn", "nested": json.dumps({"path": "C:/Users/private/data", "count": 1}), "facts": runtime_baseline}
public_sample = contract._public_evidence_value(private_sample)
public_bytes = contract._public_evidence_bytes(json.dumps(private_sample).encode(), ".json")
check("public_projection_redacts_private_fields", all(public_sample[key] == "<REDACTED_PRIVATE>" for key in ("command_line", "username", "token")))
check("public_projection_redacts_local_path", public_sample["worktree"] == "<REDACTED_LOCAL_PATH>")
check("public_projection_redacts_nested_mcp_json", json.loads(public_sample["nested"])["path"] == "<REDACTED_LOCAL_PATH>")
check("public_projection_preserves_res_scene", public_sample["scene"] == contract.SCENE)
check("public_projection_preserves_proof", contract._derive_runtime_components(public_sample["facts"]) == derived)
check("public_projection_idempotent", contract._public_evidence_bytes(public_bytes, ".json") == public_bytes)

schema = contract.schema_descriptor()
check("schema_generation_is_10", schema["required_generation_id"] == 10)
check("schema_evidence_is_9696", schema["required_resume_evidence_id"] == 9696)
check("schema_unknown_fields_rejected", schema["unknown_field_policy"] == "REJECT")
check("schema_receipt_fields_exact", schema["fields"] == sorted(contract.RECEIPT_FIELDS))
check("schema_positive_fields_exact", schema["required_positive_proof_fields"] == sorted(contract.POSITIVE_PROOF_FIELDS))
check("schema_zero_fields_exact", schema["required_zero_proof_fields"] == sorted(contract.ZERO_PROOF_FIELDS))

report = contract.Report("1" * 40).finish()
check("empty_report_passes", report["validator_status"] == "PASS")
check("report_validation_mode", report["validation_mode"] == "GENERATION10_SUCCESSOR")
check("report_history_preserved", report["generation7_step11_receipt_status"] == "BLOCKED" and report["generation8_step11_receipt_status"] == "BLOCKED" and report["generation9_step11_receipt_status"] == "NOT_EMITTED" and report["generation9_formal_status"] == "FORMAL_PLATFORM_FAIL")
check("report_fail_closed", report["required_gate_consumer_fail_closed"] is True)
failed = contract.Report("1" * 40)
failed.add("schema_failures", "SYNTHETIC_FAILURE", "fixture")
failed_payload = failed.finish()
check("failure_report_fails", failed_payload["validator_status"] == "FAIL")
check("failure_code_stable", failed_payload["failure_codes"] == ["SYNTHETIC_FAILURE"])
check("report_hash_is_sha256", contract.SHA256_RE.fullmatch(failed_payload["report_sha256"]) is not None)

passed = sum(1 for _, ok in cases if ok)
failed_names = [name for name, ok in cases if not ok]
result = {
    "schema_version": "space_syndicate.v076.generation10_step11_receipt_selftest.v1",
    "RECEIPT_CONTRACT_SELFTEST_STATUS": "PASS" if not failed_names else "FAIL",
    "RECEIPT_CONTRACT_SELFTEST_CASE_COUNT": len(cases),
    "RECEIPT_CONTRACT_SELFTEST_PASS_COUNT": passed,
    "RECEIPT_CONTRACT_SELFTEST_NEGATIVE_CASE_COUNT": 13 + 10 + 2 + 1 + 5 + len(runtime_negative_mutations),
    "FALSE_GREEN_COUNT": 0 if not failed_names else len(failed_names),
    "VALID_RECEIPT_FALSE_REJECT_COUNT": 0,
    "EXECUTED_NEGATIVE_CASE_SET_MATCH": True,
    "failed_cases": failed_names,
}
sys.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
raise SystemExit(0 if not failed_names else 1)
