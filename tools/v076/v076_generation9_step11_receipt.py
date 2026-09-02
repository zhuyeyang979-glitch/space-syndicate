#!/usr/bin/env python3
"""Fail-closed Generation 9 STEP11 receipt schema and committed-chain validator."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence


SCHEMA_VERSION = "space_syndicate.v076.generation9_step11_receipt.v1"
RUNTIME_SCHEMA_VERSION = "space_syndicate.v076.generation9_step11_mcp_runtime_evidence.v1"
EVIDENCE_MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.generation9_step11_evidence_manifest.v1"
AUTHORIZATION_SCHEMA_VERSION = "space_syndicate.v076.generation9_authorization_manifest.v1"
ENVIRONMENT_SEAL_SCHEMA_VERSION = "space_syndicate.v076.generation9_environment_seal.v1"
TOOLING_SEAL_SCHEMA_VERSION = "space_syndicate.v076.generation9_receipt_tooling_seal.v1"
EXECUTION_START_SCHEMA_VERSION = "space_syndicate.v076.generation9_execution_start.v1"
PROGRESS_SCHEMA_VERSION = "space_syndicate.v076.generation9_progress.v1"
SUMMARY_SCHEMA_VERSION = "space_syndicate.v076.generation9_summary.v1"

AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_COMMIT_CAPACITY_AND_GENERATION9_20260902"
SUPPLEMENTAL_AUTHORIZATION_ID = "USER_SUPPLEMENTAL_AUTHORIZATION_V076_GENERATION9_PROBES_PLUS3_20260902"
GENERATION_ID = 9
PARENT_GENERATION_ID = 8
PARENT_EVIDENCE_ID = 9694
EVIDENCE_ID = 9695
SEED = 917592522
PLAYER_COUNT = 4
PROFILE = "PRODUCTION_MAIN_TSCN_ONE_MCP_SEAT_THREE_AI"
SCENE = "res://scenes/main.tscn"
PROJECT_FILE_PATH = "project.godot"
MAIN_SCENE_PATH = "scenes/main.tscn"
RUNTIME_COMPOSITION_PATH = "scenes/runtime/V075RuntimeComposition.tscn"
PRODUCTION_SCREEN_PATH = "scenes/ui/v075/V075SampleGameScreen.tscn"
CHECK_CONTEXT = "V076 Reuse and Point-Inertia Gate"
VALIDATION_MODE = "GENERATION9_SUCCESSOR"
PRODUCT_HEAD = "b33e460610776564dac3616bd341fa829316b1e2"
PRODUCT_TREE = "449018413600b57b9d503b9610c9ae79e3c8eee1"

VALIDATOR_PATH = "tools/v076/v076_generation9_step11_receipt.py"
SELFTEST_PATH = "tools/v076/v076_generation9_step11_receipt_selftest.py"
WORKFLOW_PATH = ".github/workflows/v076-reuse-point-inertia-gate.yml"
RUNNER_PATH = "tools/v076_generation9_step11_formal.ps1"
RUNNER_SELFTEST_PATH = "tools/v076/v076_generation9_step11_runner_selftest.py"
TOOLING_SEAL_PATH = "reports/reuse/full_convergence/generation9/generation9_receipt_tooling_seal.json"
AUTHORIZATION_PATH = "reports/reuse/full_convergence/generation9/generation9_authorization_manifest.json"
AUTHORIZATION_SIDECAR_PATH = AUTHORIZATION_PATH + ".sha256"
ENVIRONMENT_SEAL_PATH = "reports/reuse/full_convergence/generation9/generation9_environment_seal.json"
ENVIRONMENT_SIDECAR_PATH = ENVIRONMENT_SEAL_PATH + ".sha256"
QUALIFICATION_SEAL_PATH = "reports/reuse/generation9_platform_qualification/generation9_platform_qualification_seal_001.json"
PASS_PAIR_PATH = "reports/reuse/generation9_platform_qualification/platform_qualification_pass_pair_001.json"
POST_RESTART_SEAL_PATH = "reports/reuse/generation9_platform_qualification/post_restart_requalification/post_restart_requalification_seal.json"
MCP_CONFIG_PATH = "reports/reuse/generation9_platform_qualification/post_restart_requalification/mcp_probe_config.json"
CANONICAL_IMPORT_PATH = "reports/reuse/generation9_platform_qualification/canonical_import/pass-002/imported_manifest.json"
CLASS_CACHE_PATH = ".godot/global_script_class_cache.cfg"
PARENT_RECEIPT_PATH = "reports/reuse/full_convergence/generation-008/formal-attempt-001/receipts/step11_receipt.json"
FORMAL_ROOT = "reports/reuse/full_convergence/generation-009/formal-attempt-001"
RECEIPT_PATH = f"{FORMAL_ROOT}/receipts/step11_receipt.json"
EVIDENCE_MANIFEST_PATH = f"{FORMAL_ROOT}/evidence/step11_evidence_manifest.json"
RUNTIME_EVIDENCE_PATH = f"{FORMAL_ROOT}/evidence/mcp_runtime_evidence.json"
RUNTIME_SOURCE_PATH = f"{FORMAL_ROOT}/evidence/source-formal-execution-result.json"
EXECUTION_START_PATH = f"{FORMAL_ROOT}/execution-start.json"
PROGRESS_PATH = f"{FORMAL_ROOT}/progress.json"
SUMMARY_PATH = f"{FORMAL_ROOT}/summary.json"

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
GIT_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
RFC3339_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z$")

POSITIVE_PROOF_FIELDS = frozenset(
    {
        "asset_authority_receipt_count",
        "before_after_quantity_receipt_count",
        "committed_revision_receipt_count",
        "asset_delta_projection_count",
        "asset_consequence_binding_count",
        "exact_once_binding_count",
        "assault_region_root_command_count",
        "military_direct_action_accepted_count",
        "military_eta_created_count",
        "military_eta_positive_count",
        "military_arrival_count",
        "assault_region_resolution_count",
        "military_withdrawal_count",
    }
)
ZERO_PROOF_FIELDS = frozenset(
    {
        "duplicate_binding_count",
        "duplicate_asset_debit_count",
        "asset_negative_value_count",
        "ui_gameplay_mutation_count",
        "presentation_gameplay_mutation_count",
        "opponent_private_asset_disclosure_count",
        "private_information_leak_count",
        "asset_projection_failure_count",
        "old_military_writer_count",
        "terminal_before_assault_region_count",
    }
)
PROOF_FIELDS = POSITIVE_PROOF_FIELDS | ZERO_PROOF_FIELDS

PROCESS_CLEANUP_FIELDS = frozenset(
    {"exit_play_mode", "stop_role_godot_mcp", "editor_pid_after", "game_pid_after", "listener_count_after"}
)
INJECTION_FIELDS = frozenset(
    {
        "fixture_card_injection_count",
        "fixture_asset_injection_count",
        "fixture_target_injection_count",
        "fixture_action_injection_count",
        "fixture_eta_injection_count",
        "runtime_seed_injection_count",
        "direct_action_internal_method_as_ui_proof_count",
    }
)
SEED_WITNESS_FIELDS = frozenset(
    {"visible_text", "config_model_seed", "new_game_receipt_seed", "runtime_seed", "four_layer_parity"}
)
ASSET_WITNESS_FIELDS = frozenset(
    {
        "schema", "reservation_id", "owner_player_id", "action", "outcome",
        "asset_revision_before", "asset_revision_after", "asset_quantities_before",
        "asset_quantities_after", "asset_delta_by_color", "reserved_asset_cost_by_color",
        "reservation_receipt_id", "reservation_receipt_fingerprint", "settlement_receipt_id",
        "settlement_receipt_fingerprint", "mission_receipt_fingerprint", "asset_debit_count",
        "consequence_bound", "projection_count_before", "projection_count_after",
        "projection_failure_count", "presentation_count", "consequence_id",
        "consequence_fingerprint", "task_kind", "target_region_id", "allocated_damage_total",
        "facility_damage_intent_count", "monster_damage_intent_count", "witness_fingerprint",
    }
)
MILITARY_WITNESS_FIELDS = frozenset(
    {
        "submission_id", "command_id", "mission_kind", "target_region_id", "eta_ticks",
        "scheduled_tick", "arrival_tick", "submission_count", "intake_settlement_count",
        "resolution_count", "withdrawal_count", "collision_count", "public_batch_entry_count",
        "shared_sushi_track_resolution_count", "consequence_presentation_count",
        "complete_major_round_barrier_observed",
    }
)
SETTLEMENT_WITNESS_FIELDS = frozenset(
    {"major_round_before", "major_round_after", "settlement_count_delta", "complete_major_round_barrier_observed"}
)

RECEIPT_FIELDS = frozenset(
    {
        "schema_version", "receipt_id", "receipt_kind", "authorization_id", "step_id",
        "generation_id", "resume_evidence_id", "subject_head_sha", "subject_tree_sha",
        "live_pr_head_sha", "live_pr_tree_sha", "required_check_context",
        "producer_tooling_head_sha", "producer_tooling_tree_sha", "producer_script_path",
        "producer_script_sha256", "schema_authority_path", "schema_authority_sha256",
        "validator_path", "validator_sha256", "workflow_path", "workflow_sha256",
        "tooling_seal_path", "tooling_seal_sha256", "resume_authorization_manifest_path",
        "resume_authorization_manifest_sha256", "environment_seal_path",
        "environment_seal_sha256", "previous_receipt_path", "previous_receipt_sha256",
        "previous_receipt_status", "evidence_manifest_path", "evidence_manifest_sha256",
        "mcp_runtime_evidence_path", "mcp_runtime_evidence_sha256", "status", "check_count",
        "pass_count", "failure_count", "failure_codes", "formal_execution_count",
        "automatic_retry_count", "proof", "process_cleanup", "result_fingerprint_sha256",
        "created_at_utc", "canonical_payload_sha256", "extensions",
    }
)
AUTHORIZATION_FIELDS = frozenset(
    {
        "schema_version", "status", "authorization_id", "supplemental_authorization_id",
        "generation_id", "parent_generation_id", "parent_evidence_id", "new_evidence_id",
        "evidence_id_derivation", "created_at_utc", "base_head_sha", "base_tree_sha",
        "current_boot_id", "product_subject_head_sha", "product_subject_tree_sha",
        "selected_seed", "player_count", "new_game_profile", "production_scene_path",
        "post_restart_requalification_seal_path", "post_restart_requalification_seal_sha256",
        "platform_pass_pair_path", "platform_pass_pair_sha256", "platform_qualification_seal_path",
        "platform_qualification_seal_sha256", "qualification_probe_ids", "godot_binary_path",
        "godot_binary_sha256", "mcp_config_path", "mcp_config_sha256", "canonical_import_manifest_path",
        "canonical_import_manifest_sha256", "class_cache_path", "class_cache_sha256",
        "receipt_schema_path", "receipt_schema_sha256", "receipt_validator_path",
        "receipt_validator_sha256", "receipt_selftest_path", "receipt_selftest_sha256",
        "required_workflow_path", "required_workflow_sha256", "formal_runner_path",
        "formal_runner_sha256", "formal_runner_selftest_path", "formal_runner_selftest_sha256",
        "tooling_seal_path", "tooling_seal_sha256", "environment_seal_path",
        "formal_execution_count_before", "authorized_formal_execution_count", "automatic_retry",
        "canonical_payload_sha256",
    }
)
ENVIRONMENT_FIELDS = frozenset(
    {
        "schema_version", "status", "authorization_id", "generation_id", "new_evidence_id",
        "sealed_at_utc", "authorization_head_sha", "authorization_tree_sha",
        "authorization_manifest_path", "authorization_manifest_sha256", "current_boot_id",
        "boot_time_utc", "new_stability_event_count", "available_commit_bytes",
        "minimum_required_available_commit_bytes", "product_subject_head_sha",
        "product_subject_tree_sha", "selected_seed", "player_count", "production_scene_path",
        "post_restart_requalification_seal_sha256", "platform_pass_pair_sha256",
        "platform_qualification_seal_sha256", "godot_binary_sha256", "mcp_config_sha256",
        "canonical_import_manifest_sha256", "class_cache_sha256", "receipt_schema_sha256",
        "receipt_validator_sha256", "receipt_selftest_sha256", "required_workflow_sha256",
        "formal_runner_sha256", "formal_runner_selftest_sha256", "tooling_seal_sha256",
        "import_pending_count", "godot_process_count", "mcp_process_count", "listener_count",
        "formal_execution_count_before", "authorized_formal_execution_count", "automatic_retry",
        "post_seal_input_mutation_count", "canonical_payload_sha256",
    }
)
TOOLING_FIELDS = frozenset(
    {
        "schema_version", "status", "authorization_id", "generation_id", "base_head_sha",
        "base_tree_sha", "receipt_schema_path", "receipt_schema_sha256", "receipt_validator_path",
        "receipt_validator_sha256", "receipt_selftest_path", "receipt_selftest_sha256",
        "required_workflow_path", "required_workflow_sha256", "formal_runner_path",
        "formal_runner_sha256", "formal_runner_selftest_path", "formal_runner_selftest_sha256",
        "post_seal_input_mutation_count", "canonical_payload_sha256",
    }
)
RUNTIME_FIELDS = frozenset(
    {
        "schema_version", "step_id", "generation_id", "resume_evidence_id",
        "authorization_manifest_sha256", "environment_seal_sha256", "subject_head_sha",
        "subject_tree_sha", "execution_head_sha", "execution_tree_sha", "production_scene_path",
        "execution_mode", "diagnostic_only", "fixture_only", "mcp_tool_identity",
        "mcp_protocol_version", "mcp_session_id", "godot_binary_sha256", "project_godot_sha256",
        "main_tscn_sha256", "runtime_composition_sha256", "production_screen_sha256",
        "session_started_at_utc", "session_ended_at_utc", "scene_started_via_mcp",
        "mcp_real_runtime_observed", "selected_seed", "player_count", "new_game_profile",
        "acquired_card_definition_id", "mission_kind", "target_region_id", "seed_witness",
        "asset_authority_witness", "military_lifecycle_witness", "settlement_witness",
        "injection_counters", "runtime_error_count", "invalid_action_count", "proof",
        "canonical_payload_sha256",
    }
)
MANIFEST_FIELDS = frozenset(
    {"schema_version", "manifest_id", "generation_id", "resume_evidence_id", "receipt_id", "evidence_root", "artifact_count", "artifacts", "canonical_payload_sha256"}
)
ARTIFACT_FIELDS = frozenset({"path", "sha256", "size_bytes"})

EXECUTION_START_FIELDS = frozenset(
    {
        "schema_version", "status", "authorization_id", "authorization_manifest_sha256",
        "generation_id", "parent_generation_id", "parent_evidence_id", "new_evidence_id",
        "formal_attempt_id", "formal_execution_count", "automatic_retry_count",
        "execution_head_sha", "execution_tree_sha", "product_subject_head_sha",
        "product_subject_tree_sha", "selected_seed", "player_count", "new_game_profile",
        "production_scene_path", "execution_mode", "injection_counters", "started_at_utc",
        "canonical_payload_sha256",
    }
)
PROGRESS_FIELDS = frozenset(
    {
        "schema_version", "status", "generation_id", "new_evidence_id", "formal_attempt_id",
        "formal_execution_count", "automatic_retry_count", "current_step", "step11_status",
        "accepted_action_drain_status", "process_cleanup_status", "started_at_utc",
        "completed_at_utc", "canonical_payload_sha256",
    }
)
SUMMARY_FIELDS = frozenset(
    {
        "schema_version", "status", "generation_id", "parent_generation_id",
        "parent_evidence_id", "new_evidence_id", "authorization_manifest_sha256",
        "formal_attempt_id", "formal_execution_count", "automatic_retry_count",
        "step11_receipt_path", "step11_receipt_sha256", "step11_receipt_status",
        "step11_required_positive_field_count", "step11_required_positive_field_pass_count",
        "step11_required_zero_field_count", "step11_required_zero_field_pass_count",
        "generation7_step11_receipt_status", "generation8_step11_receipt_status",
        "generation7_modification_count", "generation8_modification_count",
        "generation7_rerun_count", "generation8_rerun_count", "process_cleanup_status",
        "completed_at_utc", "canonical_payload_sha256",
    }
)

RESULT_FINGERPRINT_FIELDS = (
    "authorization_id", "step_id", "generation_id", "resume_evidence_id", "subject_head_sha",
    "subject_tree_sha", "live_pr_head_sha", "live_pr_tree_sha", "producer_tooling_head_sha",
    "producer_tooling_tree_sha", "producer_script_sha256", "evidence_manifest_sha256",
    "mcp_runtime_evidence_sha256", "status", "check_count", "pass_count", "failure_count",
    "failure_codes", "formal_execution_count", "automatic_retry_count", "proof",
    "process_cleanup",
)


def canonical_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def canonical_payload_sha256(value: Mapping[str, Any]) -> str:
    payload = dict(value)
    payload.pop("canonical_payload_sha256", None)
    return hashlib.sha256(canonical_json_bytes(payload)).hexdigest()


def witness_fingerprint_sha256(value: Mapping[str, Any]) -> str:
    payload = dict(value)
    payload.pop("witness_fingerprint", None)
    return hashlib.sha256(canonical_json_bytes(payload)).hexdigest()


def result_fingerprint_sha256(value: Mapping[str, Any]) -> str:
    return hashlib.sha256(
        canonical_json_bytes({field: value.get(field) for field in RESULT_FINGERPRINT_FIELDS})
    ).hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _exact_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _timestamp(value: Any) -> bool:
    if not isinstance(value, str) or RFC3339_RE.fullmatch(value) is None:
        return False
    try:
        datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        return False
    return True


class Report:
    def __init__(self, expected_head: str = "") -> None:
        self.expected_head = expected_head
        self.failures: dict[str, list[str]] = {
            "field_mismatches": [], "identity_mismatches": [], "hash_mismatches": [],
            "path_failures": [], "schema_failures": [],
        }
        self.codes: list[str] = []
        self.receipt_count = 0
        self.validated_receipt_count = 0
        self.receipt_bindings: list[dict[str, Any]] = []
        self.artifact_head_sha: str | None = None
        self.execution_head_sha: str | None = None
        self.execution_tree_sha: str | None = None

    def add(self, category: str, code: str, detail: Any) -> None:
        self.codes.append(code)
        self.failures[category].append(f"{code}:{detail}")

    def finish(self) -> dict[str, Any]:
        codes = sorted(set(self.codes))
        payload: dict[str, Any] = {
            "validator_status": "PASS" if not codes else "FAIL",
            "failure_codes": codes,
            **{name: sorted(set(rows)) for name, rows in self.failures.items()},
            "receipt_count": self.receipt_count,
            "validated_receipt_count": self.validated_receipt_count,
            "receipt_bindings": self.receipt_bindings,
            "expected_consumer_head_sha": self.expected_head,
            "artifact_head_sha": self.artifact_head_sha,
            "execution_head_sha": self.execution_head_sha,
            "execution_tree_sha": self.execution_tree_sha,
            "generation_id": GENERATION_ID,
            "resume_evidence_id": EVIDENCE_ID,
            "validation_mode": VALIDATION_MODE,
            "generation7_step11_receipt_status": "BLOCKED",
            "generation8_step11_receipt_status": "BLOCKED",
            "step11_required_positive_field_count": len(POSITIVE_PROOF_FIELDS),
            "step11_required_positive_field_pass_count": 0 if codes else len(POSITIVE_PROOF_FIELDS),
            "required_check_context": CHECK_CONTEXT,
            "required_gate_consumer_fail_closed": True,
        }
        payload["report_sha256"] = sha256_bytes(canonical_json_bytes(payload))
        return payload


class GitProject:
    def __init__(self, root: Path) -> None:
        self.root = root.resolve()
        self._git("rev-parse", "--show-toplevel")

    def _git(self, *args: str, text: bool = True) -> str | bytes:
        completed = subprocess.run(["git", *args], cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        if completed.returncode != 0:
            raise ValueError(f"git {' '.join(args)} failed:{completed.stderr.decode('utf-8', 'replace').strip()}")
        return completed.stdout.decode("utf-8").strip() if text else completed.stdout

    def commit(self, ref: str) -> str:
        value = str(self._git("rev-parse", "--verify", f"{ref}^{{commit}}"))
        if GIT_SHA_RE.fullmatch(value) is None:
            raise ValueError(f"invalid commit:{value}")
        return value

    def tree(self, ref: str) -> str:
        return str(self._git("rev-parse", f"{ref}^{{tree}}"))

    def parent(self, ref: str) -> str:
        rows = str(self._git("rev-list", "--parents", "-n", "1", ref)).split()
        if len(rows) != 2:
            raise ValueError(f"{ref} must have exactly one parent")
        return rows[1]

    def ancestor(self, older: str, newer: str) -> bool:
        return subprocess.run(["git", "merge-base", "--is-ancestor", older, newer], cwd=self.root).returncode == 0

    def read(self, ref: str, path: str) -> bytes:
        if PurePosixPath(path).is_absolute() or ".." in PurePosixPath(path).parts or "\\" in path:
            raise ValueError(f"unsafe path:{path}")
        return bytes(self._git("show", f"{ref}:{path}", text=False))

    def paths(self, ref: str, prefix: str) -> list[str]:
        raw = bytes(self._git("ls-tree", "-r", "-z", "--name-only", ref, "--", prefix, text=False))
        return sorted(p.decode("utf-8") for p in raw.split(b"\0") if p)

    def additions(self, ref: str, path: str) -> list[str]:
        raw = str(self._git("log", "--diff-filter=A", "--format=%H", ref, "--", path))
        return [row for row in raw.splitlines() if row]

    def changed(self, older: str, newer: str) -> list[tuple[str, str]]:
        raw = bytes(self._git("diff", "--name-status", "-z", older, newer, "--", text=False))
        parts = raw.split(b"\0")
        rows: list[tuple[str, str]] = []
        index = 0
        while index < len(parts) - 1 and parts[index]:
            status = parts[index].decode("ascii")
            path = parts[index + 1].decode("utf-8")
            rows.append((status, path))
            index += 2
        return rows


def _exact_keys(report: Report, value: Any, fields: frozenset[str], label: str) -> bool:
    if not isinstance(value, dict):
        report.add("schema_failures", "OBJECT_REQUIRED", label)
        return False
    actual = frozenset(value)
    if actual != fields:
        report.add("schema_failures", "FIELD_SET_MISMATCH", f"{label}:missing={sorted(fields-actual)}:extra={sorted(actual-fields)}")
        return False
    return True


def _json(project: GitProject, ref: str, path: str, report: Report, *, canonical: bool = True) -> tuple[dict[str, Any] | None, bytes | None]:
    try:
        raw = project.read(ref, path)
        value = json.loads(raw.decode("utf-8"))
    except Exception as exc:
        report.add("path_failures", "JSON_UNAVAILABLE", f"{path}:{exc}")
        return None, None
    if not isinstance(value, dict):
        report.add("schema_failures", "JSON_OBJECT_REQUIRED", path)
        return None, raw
    if canonical and raw != canonical_json_bytes(value):
        report.add("schema_failures", "NONCANONICAL_JSON", path)
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add("hash_mismatches", "CANONICAL_PAYLOAD_SHA256_MISMATCH", path)
    return value, raw


def _bind(project: GitProject, ref: str, path: Any, claimed: Any, report: Report, label: str) -> bytes | None:
    if not isinstance(path, str) or not isinstance(claimed, str) or SHA256_RE.fullmatch(claimed) is None:
        report.add("schema_failures", "BINDING_INVALID", label)
        return None
    try:
        raw = project.read(ref, path)
    except Exception as exc:
        report.add("path_failures", "BOUND_FILE_UNAVAILABLE", f"{label}:{path}:{exc}")
        return None
    if sha256_bytes(raw) != claimed:
        report.add("hash_mismatches", "BOUND_FILE_SHA256_MISMATCH", f"{label}:{path}")
    return raw


def _validate_proof(report: Report, proof: Any, label: str) -> None:
    if not _exact_keys(report, proof, PROOF_FIELDS, label):
        return
    assert isinstance(proof, dict)
    for field in sorted(POSITIVE_PROOF_FIELDS):
        if not _exact_int(proof[field]) or proof[field] != 1:
            report.add("field_mismatches", "POSITIVE_PROOF_NOT_EXACTLY_ONCE", f"{label}.{field}={proof[field]!r}")
    for field in sorted(ZERO_PROOF_FIELDS):
        if not _exact_int(proof[field]) or proof[field] != 0:
            report.add("field_mismatches", "ZERO_PROOF_NOT_ZERO", f"{label}.{field}={proof[field]!r}")


def _validate_cleanup(report: Report, value: Any, label: str) -> None:
    if not _exact_keys(report, value, PROCESS_CLEANUP_FIELDS, label):
        return
    assert isinstance(value, dict)
    if value.get("exit_play_mode") != "PASS" or value.get("stop_role_godot_mcp") != "PASS":
        report.add("field_mismatches", "CLEANUP_STATUS_NOT_PASS", label)
    for field in ("editor_pid_after", "game_pid_after", "listener_count_after"):
        if not _exact_int(value.get(field)) or value[field] != 0:
            report.add("field_mismatches", "CLEANUP_COUNT_NOT_ZERO", f"{label}.{field}")


def _only_mapping(value: Any, label: str) -> tuple[str, dict[str, Any]]:
    if not isinstance(value, dict) or len(value) != 1:
        raise ValueError(f"{label}_COUNT_NOT_ONE")
    key = next(iter(value))
    row = value[key]
    if not isinstance(key, str) or not key or not isinstance(row, dict):
        raise ValueError(f"{label}_ROW_INVALID")
    return key, row


def _step_receipt(result: Mapping[str, Any], step: str) -> dict[str, Any]:
    rows = [row for row in result.get("step_receipts", []) if isinstance(row, dict) and row.get("step") == step]
    if len(rows) != 1:
        raise ValueError(f"STEP_RECEIPT_{step}_COUNT_NOT_ONE")
    return rows[0]


def _derive_runtime_components(result: Mapping[str, Any]) -> dict[str, Any]:
    if result.get("status") != "PASS" or result.get("formal_execution_count") != 1 or result.get("automatic_retry_count") != 0:
        raise ValueError("FORMAL_RESULT_NOT_SINGLE_PASS")
    if result.get("generation_id") != GENERATION_ID or result.get("new_evidence_id") != EVIDENCE_ID:
        raise ValueError("FORMAL_RESULT_IDENTITY_MISMATCH")
    if result.get("subject_head_sha") != PRODUCT_HEAD or result.get("subject_tree_sha") != PRODUCT_TREE:
        raise ValueError("FORMAL_RESULT_PRODUCT_MISMATCH")
    if result.get("selected_seed") != SEED or result.get("player_count") != PLAYER_COUNT or result.get("production_scene_path") != SCENE:
        raise ValueError("FORMAL_RESULT_PROFILE_MISMATCH")
    if result.get("failure") is not None:
        raise ValueError("FORMAL_RESULT_FAILURE_PRESENT")

    seed_row = _step_receipt(result, "seed")
    seed_witness = {
        "visible_text": int(seed_row.get("visible_text", -1)),
        "config_model_seed": seed_row.get("config_model_seed"),
        "new_game_receipt_seed": seed_row.get("new_game_receipt_seed"),
        "runtime_seed": seed_row.get("runtime_seed"),
        "four_layer_parity": True,
    }
    if any(seed_witness[field] != SEED for field in ("visible_text", "config_model_seed", "new_game_receipt_seed", "runtime_seed")):
        raise ValueError("FORMAL_RESULT_SEED_PARITY_MISMATCH")

    final = _step_receipt(result, "military_final")
    private = final.get("private_owner")
    eta = final.get("eta_owner")
    kernel = final.get("kernel")
    application = final.get("application_flow")
    runtime = final.get("runtime_owner")
    legacy = final.get("legacy_combat_owner")
    screen = final.get("production_screen")
    if not all(isinstance(row, dict) for row in (private, eta, kernel, application, runtime, legacy, screen)):
        raise ValueError("FORMAL_RESULT_RUNTIME_COMPONENT_MISSING")
    assert isinstance(private, dict) and isinstance(eta, dict) and isinstance(kernel, dict)
    assert isinstance(application, dict) and isinstance(runtime, dict) and isinstance(legacy, dict) and isinstance(screen, dict)

    submission_id, submitted = _only_mapping(private.get("_submitted_result_by_id"), "SUBMITTED_RESULT")
    if submitted.get("accepted") is not True or submitted.get("duplicate") is not False:
        raise ValueError("FORMAL_RESULT_DIRECT_ACTION_NOT_ACCEPTED_ONCE")
    if submitted.get("submission_id") != submission_id or submitted.get("mission_kind") != "ASSAULT_REGION":
        raise ValueError("FORMAL_RESULT_SUBMISSION_IDENTITY_MISMATCH")
    if submitted.get("eta_ticks") != 6 or submitted.get("dispatch_delay_ticks") != 6:
        raise ValueError("FORMAL_RESULT_PHYSICAL_ETA_MISMATCH")
    scheduled_tick = submitted.get("scheduled_tick")
    arrival_tick = submitted.get("arrival_tick")
    if not _exact_int(scheduled_tick) or not _exact_int(arrival_tick) or arrival_tick - scheduled_tick + 1 != 6:
        raise ValueError("FORMAL_RESULT_ETA_ARITHMETIC_MISMATCH")

    domain_states = kernel.get("_domain_states")
    if not isinstance(domain_states, dict):
        raise ValueError("FORMAL_RESULT_KERNEL_DOMAIN_STATES_INVALID")
    domain = domain_states.get("future.private_direct_action_input")
    if not isinstance(domain, dict):
        raise ValueError("FORMAL_RESULT_DIRECT_ACTION_DOMAIN_MISSING")
    ledger_id, ledger = _only_mapping(domain.get("submission_ledger"), "KERNEL_SUBMISSION_LEDGER")
    if ledger_id != submission_id or ledger.get("phase") != "WITHDRAWAL_READY":
        raise ValueError("FORMAL_RESULT_WITHDRAWAL_PHASE_MISMATCH")
    if ledger.get("mission_kind") != "ASSAULT_REGION" or ledger.get("arrival_tick") != arrival_tick:
        raise ValueError("FORMAL_RESULT_KERNEL_MISSION_MISMATCH")
    mission_receipt = ledger.get("mission_receipt")
    if not isinstance(mission_receipt, dict) or mission_receipt.get("mission_state_after") != "withdrawn":
        raise ValueError("FORMAL_RESULT_MISSION_RECEIPT_INVALID")

    asset = runtime.get("_v076_last_asset_consequence_witness")
    if not isinstance(asset, dict) or frozenset(asset) != ASSET_WITNESS_FIELDS:
        raise ValueError("FORMAL_RESULT_ASSET_WITNESS_FIELD_SET_MISMATCH")
    if asset.get("schema") != "V076AssetConsequenceAuthorityWitnessV1" or asset.get("owner_player_id") != "player.local":
        raise ValueError("FORMAL_RESULT_ASSET_OWNER_MISMATCH")
    if asset.get("action") != "commit" or asset.get("outcome") != "consumed" or asset.get("task_kind") != "assault_region" or asset.get("target_region_id") != "region.005":
        raise ValueError("FORMAL_RESULT_ASSET_ACTION_MISMATCH")
    if asset.get("asset_revision_after") != asset.get("asset_revision_before", -2) + 1:
        raise ValueError("FORMAL_RESULT_ASSET_REVISION_MISMATCH")
    if asset.get("asset_debit_count") != 1 or asset.get("consequence_bound") is not True:
        raise ValueError("FORMAL_RESULT_ASSET_DEBIT_MISMATCH")
    if asset.get("projection_count_after") != asset.get("projection_count_before", -2) + 1 or asset.get("projection_failure_count") != 0 or asset.get("presentation_count") != 1:
        raise ValueError("FORMAL_RESULT_ASSET_PROJECTION_MISMATCH")
    if asset.get("witness_fingerprint") != witness_fingerprint_sha256(asset):
        raise ValueError("FORMAL_RESULT_ASSET_FINGERPRINT_MISMATCH")
    for field in ("reservation_receipt_fingerprint", "settlement_receipt_fingerprint", "mission_receipt_fingerprint", "consequence_fingerprint"):
        if not isinstance(asset.get(field), str) or SHA256_RE.fullmatch(asset[field]) is None:
            raise ValueError(f"FORMAL_RESULT_{field.upper()}_INVALID")
    before = asset.get("asset_quantities_before")
    after = asset.get("asset_quantities_after")
    delta = asset.get("asset_delta_by_color")
    cost = asset.get("reserved_asset_cost_by_color")
    if not all(isinstance(row, dict) for row in (before, after, delta, cost)):
        raise ValueError("FORMAL_RESULT_ASSET_QUANTITY_MAP_INVALID")
    assert isinstance(before, dict) and isinstance(after, dict) and isinstance(delta, dict) and isinstance(cost, dict)
    colors = set(before) | set(after) | set(delta) | set(cost)
    if any(not _exact_int(before.get(color, 0)) or not _exact_int(after.get(color, 0)) or before.get(color, 0) < 0 or after.get(color, 0) < 0 for color in colors):
        raise ValueError("FORMAL_RESULT_ASSET_QUANTITY_INVALID")
    if before.get("shipping") != 2 or after.get("shipping") != 0 or delta.get("shipping") != -2 or cost.get("shipping") != 2:
        raise ValueError("FORMAL_RESULT_SHIPPING_DEBIT_MISMATCH")
    if any(delta.get(color, 0) != after.get(color, 0) - before.get(color, 0) or delta.get(color, 0) != -cost.get(color, 0) for color in colors):
        raise ValueError("FORMAL_RESULT_ASSET_DELTA_PARITY_MISMATCH")

    submission_fingerprints = private.get("_submission_fingerprint_by_id")
    settlement_fingerprints = private.get("_settlement_fingerprint_by_id")
    if not isinstance(submission_fingerprints, dict) or set(submission_fingerprints) != {submission_id} or not isinstance(submission_fingerprints[submission_id], str) or SHA256_RE.fullmatch(submission_fingerprints[submission_id]) is None:
        raise ValueError("FORMAL_RESULT_SUBMISSION_FINGERPRINT_INVALID")
    if not isinstance(settlement_fingerprints, dict) or set(settlement_fingerprints) != {submission_id} or not isinstance(settlement_fingerprints[submission_id], str) or SHA256_RE.fullmatch(settlement_fingerprints[submission_id]) is None:
        raise ValueError("FORMAL_RESULT_SETTLEMENT_FINGERPRINT_INVALID")
    intake_id, intake = _only_mapping(private.get("_intake_settlement_result_by_id"), "INTAKE_SETTLEMENT")
    damage_id, damage = _only_mapping(private.get("_damage_settlement_by_id"), "DAMAGE_SETTLEMENT")
    if intake_id != submission_id or damage_id != submission_id:
        raise ValueError("FORMAL_RESULT_SETTLEMENT_ID_MISMATCH")
    if intake.get("accepted") is not True or damage.get("accepted") is not True:
        raise ValueError("FORMAL_RESULT_SETTLEMENT_NOT_ACCEPTED")
    if private.get("_collision_count") != 0 or private.get("_rejection_count") != 0:
        raise ValueError("FORMAL_RESULT_PRIVATE_OWNER_ERROR")
    if eta.get("_calculation_count") != 1 or eta.get("_rejection_count") != 0:
        raise ValueError("FORMAL_RESULT_ETA_OWNER_COUNT_MISMATCH")
    if domain.get("military_intake_count") != 1 or domain.get("arrived_count") != 1 or domain.get("executed_once_count") != 1 or domain.get("withdrawal_ready_count") != 1:
        raise ValueError("FORMAL_RESULT_KERNEL_LIFECYCLE_COUNT_MISMATCH")
    if kernel.get("_rejection_count") != 0 or application.get("_v076_private_military_receipt_count") != 1:
        raise ValueError("FORMAL_RESULT_KERNEL_OR_FLOW_COUNT_MISMATCH")
    if runtime.get("_batch_number") != 5 or runtime.get("_phase") != "submission":
        raise ValueError("FORMAL_RESULT_MAJOR_ROUND_BARRIER_MISSING")
    if runtime.get("_runtime_error_count") != 0 or runtime.get("_invalid_action_count") != 0:
        raise ValueError("FORMAL_RESULT_RUNTIME_ERROR_COUNT_NONZERO")
    if runtime.get("_v076_asset_consequence_projection_count") != 1 or runtime.get("_v076_asset_consequence_projection_failure_count") != 0 or runtime.get("_v076_military_consequence_collision_count") != 0 or runtime.get("_v076_military_consequence_presentation_count") != 1:
        raise ValueError("FORMAL_RESULT_RUNTIME_CONSEQUENCE_COUNT_MISMATCH")
    if runtime.get("_v076_production_military_submission_by_uid") != {}:
        raise ValueError("FORMAL_RESULT_MILITARY_SOURCE_NOT_WITHDRAWN")
    snapshot = runtime.get("_v075_snapshot")
    if not isinstance(snapshot, dict) or snapshot.get("old_military_controller_production_reachable_count") != 0:
        raise ValueError("FORMAL_RESULT_OLD_MILITARY_WRITER_REACHABLE")
    if legacy.get("_runtime_error_count") != 0:
        raise ValueError("FORMAL_RESULT_LEGACY_PRESENTATION_RUNTIME_ERROR")
    acceptance = screen.get("acceptance_state")
    if not isinstance(acceptance, dict):
        raise ValueError("FORMAL_RESULT_SCREEN_ACCEPTANCE_MISSING")
    combat_wrapper = acceptance.get("combat_wrapper")
    if not isinstance(combat_wrapper, dict):
        raise ValueError("FORMAL_RESULT_SCREEN_DEBUG_MISSING")
    human = combat_wrapper.get("human_playability")
    presentation = combat_wrapper.get("presentation")
    if not isinstance(human, dict) or not isinstance(presentation, dict):
        raise ValueError("FORMAL_RESULT_SCREEN_GUARD_MISSING")
    if human.get("private_information_violation_count") != 0 or human.get("direct_asset_mutation_count") != 0 or human.get("public_batch_direct_action_entry_count") != 0 or human.get("shared_sushi_track_direct_action_resolution_count") != 0:
        raise ValueError("FORMAL_RESULT_SCREEN_AUTHORITY_GUARD_NONZERO")
    if combat_wrapper.get("presentation_gameplay_mutation_count") != 0 or presentation.get("presentation_gameplay_mutation_count") != 0:
        raise ValueError("FORMAL_RESULT_PRESENTATION_MUTATION_NONZERO")
    if screen.get("_current_action_mode") != "idle" or screen.get("_action_submission_pending") is not False:
        raise ValueError("FORMAL_RESULT_HUMAN_ACTION_NOT_QUIESCENT")

    military = {
        "submission_id": submission_id,
        "command_id": submitted.get("command_id"),
        "mission_kind": "ASSAULT_REGION",
        "target_region_id": "region.005",
        "eta_ticks": 6,
        "scheduled_tick": scheduled_tick,
        "arrival_tick": arrival_tick,
        "submission_count": 1,
        "intake_settlement_count": 1,
        "resolution_count": 1,
        "withdrawal_count": 1,
        "collision_count": 0,
        "public_batch_entry_count": 0,
        "shared_sushi_track_resolution_count": 0,
        "consequence_presentation_count": 1,
        "complete_major_round_barrier_observed": True,
    }
    if not isinstance(military["command_id"], str) or not military["command_id"]:
        raise ValueError("FORMAL_RESULT_COMMAND_ID_MISSING")
    settlement = {
        "major_round_before": 1,
        "major_round_after": 2,
        "settlement_count_delta": 1,
        "complete_major_round_barrier_observed": True,
    }
    proof = {**{field: 1 for field in POSITIVE_PROOF_FIELDS}, **{field: 0 for field in ZERO_PROOF_FIELDS}}
    return {
        "seed_witness": seed_witness,
        "asset_authority_witness": asset,
        "military_lifecycle_witness": military,
        "settlement_witness": settlement,
        "proof": proof,
    }


def _validate_tooling(project: GitProject, tooling_head: str, authorization: Mapping[str, Any], report: Report) -> None:
    seal, raw = _json(project, tooling_head, TOOLING_SEAL_PATH, report)
    if seal is None or raw is None or not _exact_keys(report, seal, TOOLING_FIELDS, "tooling_seal"):
        return
    try:
        tooling_parent = project.parent(tooling_head)
        tooling_parent_tree = project.tree(tooling_parent)
    except Exception as exc:
        report.add("identity_mismatches", "TOOLING_SEAL_PARENT_INVALID", str(exc))
        return
    expected_changes = [
        ("M", WORKFLOW_PATH),
        ("A", TOOLING_SEAL_PATH),
        ("A", VALIDATOR_PATH),
        ("A", SELFTEST_PATH),
        ("A", RUNNER_SELFTEST_PATH),
        ("A", RUNNER_PATH),
    ]
    if project.changed(tooling_parent, tooling_head) != expected_changes:
        report.add("path_failures", "TOOLING_COMMIT_NOT_EXACT", repr(project.changed(tooling_parent, tooling_head)))
    exact = {
        "schema_version": TOOLING_SEAL_SCHEMA_VERSION, "status": "SEALED", "authorization_id": AUTHORIZATION_ID,
        "generation_id": GENERATION_ID, "base_head_sha": tooling_parent, "base_tree_sha": tooling_parent_tree,
        "receipt_schema_path": VALIDATOR_PATH, "receipt_validator_path": VALIDATOR_PATH,
        "receipt_selftest_path": SELFTEST_PATH, "required_workflow_path": WORKFLOW_PATH,
        "formal_runner_path": RUNNER_PATH, "formal_runner_selftest_path": RUNNER_SELFTEST_PATH,
        "post_seal_input_mutation_count": 0,
    }
    for field, expected in exact.items():
        if seal.get(field) != expected:
            report.add("identity_mismatches", "TOOLING_SEAL_IDENTITY_MISMATCH", f"{field}:{seal.get(field)!r}!={expected!r}")
    for path_field, hash_field in (
        ("receipt_schema_path", "receipt_schema_sha256"), ("receipt_validator_path", "receipt_validator_sha256"),
        ("receipt_selftest_path", "receipt_selftest_sha256"), ("required_workflow_path", "required_workflow_sha256"),
        ("formal_runner_path", "formal_runner_sha256"), ("formal_runner_selftest_path", "formal_runner_selftest_sha256"),
    ):
        _bind(project, tooling_head, seal.get(path_field), seal.get(hash_field), report, f"tooling.{hash_field}")
        if authorization.get(hash_field) != seal.get(hash_field):
            report.add("hash_mismatches", "AUTHORIZATION_TOOLING_BINDING_MISMATCH", hash_field)
    if sha256_bytes(raw) != authorization.get("tooling_seal_sha256"):
        report.add("hash_mismatches", "AUTHORIZATION_TOOLING_SEAL_SHA256_MISMATCH", TOOLING_SEAL_PATH)


def _validate_authorization(project: GitProject, authorization_head: str, tooling_head: str, report: Report) -> tuple[dict[str, Any] | None, bytes | None]:
    value, raw = _json(project, authorization_head, AUTHORIZATION_PATH, report)
    if value is None or raw is None or not _exact_keys(report, value, AUTHORIZATION_FIELDS, "authorization"):
        return None, raw
    expected = {
        "schema_version": AUTHORIZATION_SCHEMA_VERSION, "status": "SEALED", "authorization_id": AUTHORIZATION_ID,
        "supplemental_authorization_id": SUPPLEMENTAL_AUTHORIZATION_ID, "generation_id": GENERATION_ID,
        "parent_generation_id": PARENT_GENERATION_ID, "parent_evidence_id": PARENT_EVIDENCE_ID,
        "new_evidence_id": EVIDENCE_ID, "evidence_id_derivation": "MAX_REGISTERED_EVIDENCE_ID_PLUS_ONE_V1",
        "base_head_sha": tooling_head, "base_tree_sha": project.tree(tooling_head), "product_subject_head_sha": PRODUCT_HEAD,
        "product_subject_tree_sha": PRODUCT_TREE, "selected_seed": SEED, "player_count": PLAYER_COUNT,
        "new_game_profile": PROFILE, "production_scene_path": SCENE,
        "post_restart_requalification_seal_path": POST_RESTART_SEAL_PATH, "platform_pass_pair_path": PASS_PAIR_PATH,
        "platform_qualification_seal_path": QUALIFICATION_SEAL_PATH, "qualification_probe_ids": ["probe-016", "probe-017"],
        "mcp_config_path": MCP_CONFIG_PATH, "canonical_import_manifest_path": CANONICAL_IMPORT_PATH,
        "class_cache_path": CLASS_CACHE_PATH, "receipt_schema_path": VALIDATOR_PATH,
        "receipt_validator_path": VALIDATOR_PATH, "receipt_selftest_path": SELFTEST_PATH,
        "required_workflow_path": WORKFLOW_PATH, "formal_runner_path": RUNNER_PATH,
        "formal_runner_selftest_path": RUNNER_SELFTEST_PATH, "tooling_seal_path": TOOLING_SEAL_PATH,
        "environment_seal_path": ENVIRONMENT_SEAL_PATH, "formal_execution_count_before": 0,
        "authorized_formal_execution_count": 1, "automatic_retry": False,
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            report.add("identity_mismatches", "AUTHORIZATION_IDENTITY_MISMATCH", f"{field}:{value.get(field)!r}!={expected_value!r}")
    if not _exact_int(value.get("current_boot_id")) or value["current_boot_id"] <= 0 or not _timestamp(value.get("created_at_utc")):
        report.add("schema_failures", "AUTHORIZATION_DYNAMIC_FIELD_INVALID", "boot/timestamp")
    for path_field, hash_field in (
        ("post_restart_requalification_seal_path", "post_restart_requalification_seal_sha256"),
        ("platform_pass_pair_path", "platform_pass_pair_sha256"),
        ("platform_qualification_seal_path", "platform_qualification_seal_sha256"),
        ("mcp_config_path", "mcp_config_sha256"), ("canonical_import_manifest_path", "canonical_import_manifest_sha256"),
        ("receipt_schema_path", "receipt_schema_sha256"),
        ("receipt_validator_path", "receipt_validator_sha256"), ("receipt_selftest_path", "receipt_selftest_sha256"),
        ("required_workflow_path", "required_workflow_sha256"), ("formal_runner_path", "formal_runner_sha256"),
        ("formal_runner_selftest_path", "formal_runner_selftest_sha256"), ("tooling_seal_path", "tooling_seal_sha256"),
    ):
        _bind(project, tooling_head, value.get(path_field), value.get(hash_field), report, f"authorization.{hash_field}")
    if value.get("class_cache_path") != CLASS_CACHE_PATH or not isinstance(value.get("class_cache_sha256"), str) or SHA256_RE.fullmatch(value["class_cache_sha256"]) is None:
        report.add("schema_failures", "CLASS_CACHE_BINDING_INVALID", "authorization")
    if not isinstance(value.get("godot_binary_path"), str) or not isinstance(value.get("godot_binary_sha256"), str) or SHA256_RE.fullmatch(str(value.get("godot_binary_sha256"))) is None:
        report.add("schema_failures", "GODOT_BINARY_BINDING_INVALID", "authorization")
    try:
        sidecar = project.read(authorization_head, AUTHORIZATION_SIDECAR_PATH).decode("ascii").strip().lower()
        if sidecar != sha256_bytes(raw):
            report.add("hash_mismatches", "AUTHORIZATION_SIDECAR_MISMATCH", AUTHORIZATION_SIDECAR_PATH)
    except Exception as exc:
        report.add("path_failures", "AUTHORIZATION_SIDECAR_UNAVAILABLE", str(exc))
    _validate_tooling(project, tooling_head, value, report)
    return value, raw


def _validate_environment(project: GitProject, environment_head: str, authorization_head: str, authorization: Mapping[str, Any], authorization_raw: bytes, report: Report) -> tuple[dict[str, Any] | None, bytes | None]:
    value, raw = _json(project, environment_head, ENVIRONMENT_SEAL_PATH, report)
    if value is None or raw is None or not _exact_keys(report, value, ENVIRONMENT_FIELDS, "environment_seal"):
        return None, raw
    expected = {
        "schema_version": ENVIRONMENT_SEAL_SCHEMA_VERSION, "status": "SEALED_PRE_EXECUTION",
        "authorization_id": AUTHORIZATION_ID, "generation_id": GENERATION_ID, "new_evidence_id": EVIDENCE_ID,
        "authorization_head_sha": authorization_head, "authorization_tree_sha": project.tree(authorization_head),
        "authorization_manifest_path": AUTHORIZATION_PATH, "authorization_manifest_sha256": sha256_bytes(authorization_raw),
        "current_boot_id": authorization.get("current_boot_id"), "new_stability_event_count": 0,
        "minimum_required_available_commit_bytes": 8 * 1024**3, "product_subject_head_sha": PRODUCT_HEAD,
        "product_subject_tree_sha": PRODUCT_TREE, "selected_seed": SEED, "player_count": PLAYER_COUNT,
        "production_scene_path": SCENE, "import_pending_count": 0, "godot_process_count": 0,
        "mcp_process_count": 0, "listener_count": 0, "formal_execution_count_before": 0,
        "authorized_formal_execution_count": 1, "automatic_retry": False, "post_seal_input_mutation_count": 0,
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            report.add("identity_mismatches", "ENVIRONMENT_SEAL_IDENTITY_MISMATCH", f"{field}:{value.get(field)!r}!={expected_value!r}")
    for hash_field in (
        "post_restart_requalification_seal_sha256", "platform_pass_pair_sha256", "platform_qualification_seal_sha256",
        "godot_binary_sha256", "mcp_config_sha256", "canonical_import_manifest_sha256", "class_cache_sha256",
        "receipt_schema_sha256", "receipt_validator_sha256", "receipt_selftest_sha256", "required_workflow_sha256",
        "formal_runner_sha256", "formal_runner_selftest_sha256", "tooling_seal_sha256",
    ):
        if value.get(hash_field) != authorization.get(hash_field):
            report.add("hash_mismatches", "ENVIRONMENT_AUTHORIZATION_BINDING_MISMATCH", hash_field)
    if not _timestamp(value.get("sealed_at_utc")) or not _timestamp(value.get("boot_time_utc")):
        report.add("schema_failures", "ENVIRONMENT_TIMESTAMP_INVALID", "seal/boot")
    if not _exact_int(value.get("available_commit_bytes")) or value["available_commit_bytes"] < 8 * 1024**3:
        report.add("field_mismatches", "AVAILABLE_COMMIT_BELOW_8_GIB", value.get("available_commit_bytes"))
    try:
        sidecar = project.read(environment_head, ENVIRONMENT_SIDECAR_PATH).decode("ascii").strip().lower()
        if sidecar != sha256_bytes(raw):
            report.add("hash_mismatches", "ENVIRONMENT_SIDECAR_MISMATCH", ENVIRONMENT_SIDECAR_PATH)
    except Exception as exc:
        report.add("path_failures", "ENVIRONMENT_SIDECAR_UNAVAILABLE", str(exc))
    return value, raw


def _validate_runtime(project: GitProject, artifact_head: str, authorization: Mapping[str, Any], authorization_raw: bytes, environment_raw: bytes, execution_head: str, execution_tree: str, report: Report) -> tuple[dict[str, Any] | None, bytes | None]:
    value, raw = _json(project, artifact_head, RUNTIME_EVIDENCE_PATH, report)
    if value is None or raw is None or not _exact_keys(report, value, RUNTIME_FIELDS, "runtime_evidence"):
        return None, raw
    expected = {
        "schema_version": RUNTIME_SCHEMA_VERSION, "step_id": "STEP11", "generation_id": GENERATION_ID,
        "resume_evidence_id": EVIDENCE_ID, "authorization_manifest_sha256": sha256_bytes(authorization_raw),
        "environment_seal_sha256": sha256_bytes(environment_raw), "subject_head_sha": PRODUCT_HEAD,
        "subject_tree_sha": PRODUCT_TREE, "execution_head_sha": execution_head, "execution_tree_sha": execution_tree,
        "production_scene_path": SCENE, "execution_mode": "MCP_REAL_MAIN_TSCN_NATURAL_UI",
        "diagnostic_only": False, "fixture_only": False, "scene_started_via_mcp": True,
        "mcp_real_runtime_observed": True, "selected_seed": SEED, "player_count": PLAYER_COUNT,
        "new_game_profile": PROFILE, "acquired_card_definition_id": "military.air_superiority_fighter.shipping.rank_1",
        "mission_kind": "ASSAULT_REGION", "target_region_id": "region.005", "runtime_error_count": 0,
        "invalid_action_count": 0,
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            report.add("field_mismatches", "RUNTIME_IDENTITY_MISMATCH", f"{field}:{value.get(field)!r}!={expected_value!r}")
    for field in ("mcp_tool_identity", "mcp_protocol_version", "mcp_session_id"):
        if not isinstance(value.get(field), str) or not value[field]:
            report.add("schema_failures", "RUNTIME_STRING_INVALID", field)
    for field in ("godot_binary_sha256", "project_godot_sha256", "main_tscn_sha256", "runtime_composition_sha256", "production_screen_sha256"):
        if not isinstance(value.get(field), str) or SHA256_RE.fullmatch(value[field]) is None:
            report.add("schema_failures", "RUNTIME_SHA256_INVALID", field)
    for path, field in (
        (PROJECT_FILE_PATH, "project_godot_sha256"),
        (MAIN_SCENE_PATH, "main_tscn_sha256"),
        (RUNTIME_COMPOSITION_PATH, "runtime_composition_sha256"),
        (PRODUCTION_SCREEN_PATH, "production_screen_sha256"),
    ):
        try:
            if value.get(field) != sha256_bytes(project.read(execution_head, path)):
                report.add("hash_mismatches", "RUNTIME_PRODUCT_FILE_BINDING_MISMATCH", f"{field}:{path}")
        except Exception as exc:
            report.add("path_failures", "RUNTIME_PRODUCT_FILE_UNAVAILABLE", f"{path}:{exc}")
    if value.get("godot_binary_sha256") != authorization.get("godot_binary_sha256"):
        report.add("hash_mismatches", "RUNTIME_GODOT_BINARY_BINDING_MISMATCH", "godot_binary_sha256")
    if not _timestamp(value.get("session_started_at_utc")) or not _timestamp(value.get("session_ended_at_utc")):
        report.add("schema_failures", "RUNTIME_TIMESTAMP_INVALID", "session")
    seed = value.get("seed_witness")
    if _exact_keys(report, seed, SEED_WITNESS_FIELDS, "seed_witness"):
        assert isinstance(seed, dict)
        for field in ("visible_text", "config_model_seed", "new_game_receipt_seed", "runtime_seed"):
            if seed.get(field) != SEED:
                report.add("field_mismatches", "SEED_LAYER_MISMATCH", f"{field}:{seed.get(field)!r}")
        if seed.get("four_layer_parity") is not True:
            report.add("field_mismatches", "SEED_FOUR_LAYER_PARITY_FALSE", "seed_witness")
    injections = value.get("injection_counters")
    if _exact_keys(report, injections, INJECTION_FIELDS, "injection_counters"):
        assert isinstance(injections, dict)
        for field, count in injections.items():
            if not _exact_int(count) or count != 0:
                report.add("field_mismatches", "INJECTION_COUNTER_NONZERO", f"{field}:{count!r}")
    asset = value.get("asset_authority_witness")
    if _exact_keys(report, asset, ASSET_WITNESS_FIELDS, "asset_authority_witness"):
        assert isinstance(asset, dict)
        if asset.get("schema") != "V076AssetConsequenceAuthorityWitnessV1" or asset.get("owner_player_id") != "player.local" or asset.get("action") != "commit" or asset.get("outcome") != "consumed":
            report.add("field_mismatches", "ASSET_WITNESS_OUTCOME_INVALID", repr(asset))
        if asset.get("task_kind") != "assault_region" or asset.get("target_region_id") != "region.005":
            report.add("field_mismatches", "ASSET_WITNESS_TARGET_INVALID", repr(asset))
        if not _exact_int(asset.get("asset_revision_before")) or not _exact_int(asset.get("asset_revision_after")) or asset["asset_revision_after"] != asset["asset_revision_before"] + 1:
            report.add("field_mismatches", "ASSET_REVISION_DELTA_INVALID", repr(asset))
        if asset.get("asset_debit_count") != 1 or asset.get("consequence_bound") is not True or asset.get("projection_failure_count") != 0 or asset.get("presentation_count") != 1:
            report.add("field_mismatches", "ASSET_EXACT_ONCE_INVALID", repr(asset))
        if asset.get("projection_count_after") != asset.get("projection_count_before", -2) + 1:
            report.add("field_mismatches", "ASSET_PROJECTION_DELTA_INVALID", repr(asset))
        for field in ("reservation_receipt_fingerprint", "settlement_receipt_fingerprint", "mission_receipt_fingerprint", "consequence_fingerprint", "witness_fingerprint"):
            if not isinstance(asset.get(field), str) or SHA256_RE.fullmatch(asset[field]) is None:
                report.add("schema_failures", "ASSET_SHA256_INVALID", field)
        if asset.get("witness_fingerprint") != witness_fingerprint_sha256(asset):
            report.add("hash_mismatches", "ASSET_WITNESS_FINGERPRINT_MISMATCH", "asset_authority_witness")
        before = asset.get("asset_quantities_before")
        after = asset.get("asset_quantities_after")
        delta = asset.get("asset_delta_by_color")
        cost = asset.get("reserved_asset_cost_by_color")
        if not all(isinstance(row, dict) for row in (before, after, delta, cost)) or before.get("shipping") != 2 or after.get("shipping") != 0 or delta.get("shipping") != -2 or cost.get("shipping") != 2:
            report.add("field_mismatches", "ASSET_SHIPPING_DEBIT_INVALID", repr(asset))
    military = value.get("military_lifecycle_witness")
    if _exact_keys(report, military, MILITARY_WITNESS_FIELDS, "military_lifecycle_witness"):
        assert isinstance(military, dict)
        expected_counts = {"submission_count": 1, "intake_settlement_count": 1, "resolution_count": 1, "withdrawal_count": 1, "collision_count": 0, "public_batch_entry_count": 0, "shared_sushi_track_resolution_count": 0, "consequence_presentation_count": 1}
        for field, expected_count in expected_counts.items():
            if military.get(field) != expected_count:
                report.add("field_mismatches", "MILITARY_LIFECYCLE_COUNT_INVALID", f"{field}:{military.get(field)!r}")
        if military.get("mission_kind") != "ASSAULT_REGION" or military.get("target_region_id") != "region.005" or military.get("eta_ticks") != 6 or military.get("complete_major_round_barrier_observed") is not True:
            report.add("field_mismatches", "MILITARY_LIFECYCLE_IDENTITY_INVALID", repr(military))
        if not _exact_int(military.get("scheduled_tick")) or not _exact_int(military.get("arrival_tick")) or military["arrival_tick"] - military["scheduled_tick"] + 1 != military["eta_ticks"]:
            report.add("field_mismatches", "MILITARY_ETA_ARITHMETIC_INVALID", repr(military))
    settlement = value.get("settlement_witness")
    if _exact_keys(report, settlement, SETTLEMENT_WITNESS_FIELDS, "settlement_witness"):
        assert isinstance(settlement, dict)
        if not _exact_int(settlement.get("major_round_before")) or not _exact_int(settlement.get("major_round_after")) or settlement["major_round_after"] != settlement["major_round_before"] + 1 or settlement.get("settlement_count_delta") != 1 or settlement.get("complete_major_round_barrier_observed") is not True:
            report.add("field_mismatches", "COMPLETE_MAJOR_ROUND_SETTLEMENT_INVALID", repr(settlement))
    _validate_proof(report, value.get("proof"), "runtime.proof")
    try:
        source_raw = project.read(artifact_head, RUNTIME_SOURCE_PATH)
        source_result = json.loads(source_raw.decode("utf-8"))
        if not isinstance(source_result, dict):
            raise ValueError("source result must be an object")
        derived = _derive_runtime_components(source_result)
        for field in ("seed_witness", "asset_authority_witness", "military_lifecycle_witness", "settlement_witness", "proof"):
            if value.get(field) != derived[field]:
                report.add("field_mismatches", "RUNTIME_SOURCE_DERIVATION_MISMATCH", field)
    except Exception as exc:
        report.add("schema_failures", "RUNTIME_SOURCE_DERIVATION_FAILED", str(exc))
    return value, raw


def _validate_evidence_manifest(project: GitProject, artifact_head: str, receipt: Mapping[str, Any], report: Report) -> set[str]:
    value, raw = _json(project, artifact_head, EVIDENCE_MANIFEST_PATH, report)
    if value is None or raw is None or not _exact_keys(report, value, MANIFEST_FIELDS, "evidence_manifest"):
        return set()
    expected = {
        "schema_version": EVIDENCE_MANIFEST_SCHEMA_VERSION, "manifest_id": "v076-generation9-step11-evidence-manifest-001",
        "generation_id": GENERATION_ID, "resume_evidence_id": EVIDENCE_ID,
        "receipt_id": receipt.get("receipt_id"), "evidence_root": f"{FORMAL_ROOT}/evidence",
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            report.add("identity_mismatches", "EVIDENCE_MANIFEST_IDENTITY_MISMATCH", field)
    artifacts = value.get("artifacts")
    if not isinstance(artifacts, list) or not _exact_int(value.get("artifact_count")) or value["artifact_count"] != len(artifacts) or not artifacts:
        report.add("schema_failures", "EVIDENCE_ARTIFACT_LIST_INVALID", repr(value.get("artifact_count")))
        return set()
    paths: list[str] = []
    for index, artifact in enumerate(artifacts):
        label = f"evidence.artifacts[{index}]"
        if not _exact_keys(report, artifact, ARTIFACT_FIELDS, label):
            continue
        assert isinstance(artifact, dict)
        path = artifact.get("path")
        if not isinstance(path, str) or not path.startswith(f"{FORMAL_ROOT}/evidence/") or path == EVIDENCE_MANIFEST_PATH:
            report.add("path_failures", "EVIDENCE_ARTIFACT_PATH_INVALID", repr(path))
            continue
        try:
            data = project.read(artifact_head, path)
        except Exception as exc:
            report.add("path_failures", "EVIDENCE_ARTIFACT_UNAVAILABLE", f"{path}:{exc}")
            continue
        if artifact.get("sha256") != sha256_bytes(data) or artifact.get("size_bytes") != len(data):
            report.add("hash_mismatches", "EVIDENCE_ARTIFACT_BINDING_MISMATCH", path)
        paths.append(path)
    if paths != sorted(set(paths)):
        report.add("schema_failures", "EVIDENCE_ARTIFACT_PATHS_NOT_UNIQUE_SORTED", repr(paths))
    expected_evidence_paths = set(project.paths(artifact_head, f"{FORMAL_ROOT}/evidence")) - {EVIDENCE_MANIFEST_PATH}
    if set(paths) != expected_evidence_paths:
        report.add("path_failures", "EVIDENCE_MANIFEST_PATH_SET_MISMATCH", f"expected={sorted(expected_evidence_paths)}:actual={paths}")
    if receipt.get("evidence_manifest_sha256") != sha256_bytes(raw):
        report.add("hash_mismatches", "RECEIPT_EVIDENCE_MANIFEST_SHA256_MISMATCH", EVIDENCE_MANIFEST_PATH)
    return set(paths)


def _validate_receipt(project: GitProject, artifact_head: str, execution_head: str, execution_tree: str, tooling_head: str, tooling_tree: str, authorization: Mapping[str, Any], authorization_raw: bytes, environment_raw: bytes, report: Report) -> tuple[dict[str, Any] | None, bytes | None]:
    value, raw = _json(project, artifact_head, RECEIPT_PATH, report)
    report.receipt_count = 1 if raw is not None else 0
    if value is None or raw is None or not _exact_keys(report, value, RECEIPT_FIELDS, "receipt"):
        return None, raw
    report.validated_receipt_count = 1
    expected = {
        "schema_version": SCHEMA_VERSION, "receipt_id": "v076-current-subject-step11-generation9-formal-attempt-001",
        "receipt_kind": "CURRENT_SUBJECT_PRODUCTION_REVALIDATION", "authorization_id": AUTHORIZATION_ID,
        "step_id": "STEP11", "generation_id": GENERATION_ID, "resume_evidence_id": EVIDENCE_ID,
        "subject_head_sha": PRODUCT_HEAD, "subject_tree_sha": PRODUCT_TREE,
        "live_pr_head_sha": execution_head, "live_pr_tree_sha": execution_tree,
        "required_check_context": CHECK_CONTEXT, "producer_tooling_head_sha": tooling_head,
        "producer_tooling_tree_sha": tooling_tree, "producer_script_path": VALIDATOR_PATH,
        "schema_authority_path": VALIDATOR_PATH, "validator_path": VALIDATOR_PATH,
        "workflow_path": WORKFLOW_PATH, "tooling_seal_path": TOOLING_SEAL_PATH,
        "resume_authorization_manifest_path": AUTHORIZATION_PATH, "environment_seal_path": ENVIRONMENT_SEAL_PATH,
        "previous_receipt_path": PARENT_RECEIPT_PATH, "previous_receipt_status": "BLOCKED",
        "evidence_manifest_path": EVIDENCE_MANIFEST_PATH, "mcp_runtime_evidence_path": RUNTIME_EVIDENCE_PATH,
        "status": "PASS", "check_count": len(PROOF_FIELDS), "pass_count": len(PROOF_FIELDS),
        "failure_count": 0, "failure_codes": [], "formal_execution_count": 1,
        "automatic_retry_count": 0, "extensions": {},
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            report.add("field_mismatches", "RECEIPT_FIELD_MISMATCH", f"{field}:{value.get(field)!r}!={expected_value!r}")
    hash_bindings = (
        (VALIDATOR_PATH, "producer_script_sha256"), (VALIDATOR_PATH, "schema_authority_sha256"),
        (VALIDATOR_PATH, "validator_sha256"), (WORKFLOW_PATH, "workflow_sha256"),
        (TOOLING_SEAL_PATH, "tooling_seal_sha256"), (AUTHORIZATION_PATH, "resume_authorization_manifest_sha256"),
        (ENVIRONMENT_SEAL_PATH, "environment_seal_sha256"), (PARENT_RECEIPT_PATH, "previous_receipt_sha256"),
        (RUNTIME_EVIDENCE_PATH, "mcp_runtime_evidence_sha256"),
    )
    for path, field in hash_bindings:
        _bind(project, artifact_head, path, value.get(field), report, f"receipt.{field}")
    if value.get("resume_authorization_manifest_sha256") != sha256_bytes(authorization_raw) or value.get("environment_seal_sha256") != sha256_bytes(environment_raw):
        report.add("hash_mismatches", "RECEIPT_PREEXECUTION_BINDING_MISMATCH", "authorization/environment")
    for field in ("producer_script_sha256", "schema_authority_sha256", "validator_sha256", "workflow_sha256", "tooling_seal_sha256"):
        auth_field = "receipt_validator_sha256" if field == "producer_script_sha256" else ("receipt_schema_sha256" if field == "schema_authority_sha256" else field)
        if value.get(field) != authorization.get(auth_field):
            report.add("hash_mismatches", "RECEIPT_AUTHORIZATION_TOOL_BINDING_MISMATCH", field)
    if not _timestamp(value.get("created_at_utc")) or not isinstance(value.get("result_fingerprint_sha256"), str) or SHA256_RE.fullmatch(value["result_fingerprint_sha256"]) is None:
        report.add("schema_failures", "RECEIPT_DYNAMIC_FIELD_INVALID", "timestamp/fingerprint")
    if value.get("result_fingerprint_sha256") != result_fingerprint_sha256(value):
        report.add("hash_mismatches", "RECEIPT_RESULT_FINGERPRINT_MISMATCH", RECEIPT_PATH)
    _validate_proof(report, value.get("proof"), "receipt.proof")
    _validate_cleanup(report, value.get("process_cleanup"), "receipt.process_cleanup")
    return value, raw


def _validate_formal_documents(project: GitProject, artifact_head: str, execution_head: str, execution_tree: str, authorization_raw: bytes, receipt_raw: bytes, report: Report) -> set[str]:
    allowed = {EXECUTION_START_PATH, PROGRESS_PATH, SUMMARY_PATH}
    documents = []
    for path in (EXECUTION_START_PATH, PROGRESS_PATH, SUMMARY_PATH):
        value, raw = _json(project, artifact_head, path, report)
        documents.append((path, value, raw))
    start = documents[0][1]
    progress = documents[1][1]
    summary = documents[2][1]
    common = {"generation_id": GENERATION_ID, "new_evidence_id": EVIDENCE_ID, "formal_attempt_id": "formal-attempt-001", "formal_execution_count": 1, "automatic_retry_count": 0}
    if _exact_keys(report, start, EXECUTION_START_FIELDS, "execution_start"):
        assert isinstance(start, dict)
        for field, expected in {"schema_version": EXECUTION_START_SCHEMA_VERSION, "status": "STARTED", "authorization_id": AUTHORIZATION_ID, "authorization_manifest_sha256": sha256_bytes(authorization_raw), "parent_generation_id": PARENT_GENERATION_ID, "parent_evidence_id": PARENT_EVIDENCE_ID, **common, "execution_head_sha": execution_head, "execution_tree_sha": execution_tree, "product_subject_head_sha": PRODUCT_HEAD, "product_subject_tree_sha": PRODUCT_TREE, "selected_seed": SEED, "player_count": PLAYER_COUNT, "new_game_profile": PROFILE, "production_scene_path": SCENE, "execution_mode": "MCP_REAL_MAIN_TSCN_NATURAL_UI"}.items():
            if start.get(field) != expected:
                report.add("field_mismatches", "EXECUTION_START_FIELD_MISMATCH", field)
        injections = start.get("injection_counters")
        if _exact_keys(report, injections, INJECTION_FIELDS, "execution_start.injection_counters"):
            assert isinstance(injections, dict)
            for field, count in injections.items():
                if count != 0 or not _exact_int(count):
                    report.add("field_mismatches", "EXECUTION_START_INJECTION_NONZERO", f"{field}:{count!r}")
        if not _timestamp(start.get("started_at_utc")):
            report.add("schema_failures", "EXECUTION_START_TIMESTAMP_INVALID", start.get("started_at_utc"))
    if _exact_keys(report, progress, PROGRESS_FIELDS, "progress"):
        assert isinstance(progress, dict)
        for field, expected in {"schema_version": PROGRESS_SCHEMA_VERSION, "status": "COMPLETED", **common, "current_step": "STEP11_ASSAULT_REGION_COMPLETE_MAJOR_ROUND", "step11_status": "PASS", "accepted_action_drain_status": "QUIESCENT", "process_cleanup_status": "PASS"}.items():
            if progress.get(field) != expected:
                report.add("field_mismatches", "PROGRESS_FIELD_MISMATCH", field)
        if not _timestamp(progress.get("started_at_utc")) or not _timestamp(progress.get("completed_at_utc")) or str(progress.get("started_at_utc")) >= str(progress.get("completed_at_utc")):
            report.add("schema_failures", "PROGRESS_TIMESTAMP_INVALID", "start/complete")
    if _exact_keys(report, summary, SUMMARY_FIELDS, "summary"):
        assert isinstance(summary, dict)
        for field, expected in {"schema_version": SUMMARY_SCHEMA_VERSION, "status": "PASS", "generation_id": GENERATION_ID, "parent_generation_id": PARENT_GENERATION_ID, "parent_evidence_id": PARENT_EVIDENCE_ID, "new_evidence_id": EVIDENCE_ID, "authorization_manifest_sha256": sha256_bytes(authorization_raw), **{k: v for k, v in common.items() if k not in {"generation_id", "new_evidence_id"}}, "step11_receipt_path": RECEIPT_PATH, "step11_receipt_sha256": sha256_bytes(receipt_raw), "step11_receipt_status": "PASS", "step11_required_positive_field_count": len(POSITIVE_PROOF_FIELDS), "step11_required_positive_field_pass_count": len(POSITIVE_PROOF_FIELDS), "step11_required_zero_field_count": len(ZERO_PROOF_FIELDS), "step11_required_zero_field_pass_count": len(ZERO_PROOF_FIELDS), "generation7_step11_receipt_status": "BLOCKED", "generation8_step11_receipt_status": "BLOCKED", "generation7_modification_count": 0, "generation8_modification_count": 0, "generation7_rerun_count": 0, "generation8_rerun_count": 0, "process_cleanup_status": "PASS"}.items():
            if summary.get(field) != expected:
                report.add("field_mismatches", "SUMMARY_FIELD_MISMATCH", field)
        if not _timestamp(summary.get("completed_at_utc")):
            report.add("schema_failures", "SUMMARY_TIMESTAMP_INVALID", summary.get("completed_at_utc"))
    return allowed


def validate_repository(project_root: Path, expected_consumer_head: str) -> dict[str, Any]:
    report = Report()
    try:
        project = GitProject(project_root)
        evaluated_head = project.commit(expected_consumer_head)
        report.expected_head = evaluated_head
    except Exception as exc:
        report.add("identity_mismatches", "VALIDATION_CONTEXT_INVALID", str(exc))
        return report.finish()
    authorization_additions = project.additions(evaluated_head, AUTHORIZATION_PATH)
    environment_additions = project.additions(evaluated_head, ENVIRONMENT_SEAL_PATH)
    receipt_additions = project.additions(evaluated_head, RECEIPT_PATH)
    if len(authorization_additions) != 1 or len(environment_additions) != 1 or len(receipt_additions) != 1:
        report.add("identity_mismatches", "GENERATION9_CHAIN_ADDITION_NOT_UNIQUE", f"auth={authorization_additions}:env={environment_additions}:receipt={receipt_additions}")
        return report.finish()
    authorization_head, environment_head, artifact_head = authorization_additions[0], environment_additions[0], receipt_additions[0]
    report.artifact_head_sha = artifact_head
    try:
        tooling_head = project.parent(authorization_head)
        if project.parent(environment_head) != authorization_head or project.parent(artifact_head) != environment_head:
            raise ValueError("chain must be tooling -> authorization -> environment -> formal artifact")
        if not project.ancestor(artifact_head, evaluated_head):
            raise ValueError("formal artifact is not an ancestor of evaluated head")
        execution_head = environment_head
        execution_tree = project.tree(execution_head)
        tooling_tree = project.tree(tooling_head)
        report.execution_head_sha = execution_head
        report.execution_tree_sha = execution_tree
    except Exception as exc:
        report.add("identity_mismatches", "GENERATION9_COMMIT_CHAIN_INVALID", str(exc))
        return report.finish()
    expected_auth_changes = [("A", AUTHORIZATION_PATH), ("A", AUTHORIZATION_SIDECAR_PATH)]
    expected_env_changes = [("A", ENVIRONMENT_SEAL_PATH), ("A", ENVIRONMENT_SIDECAR_PATH)]
    if project.changed(tooling_head, authorization_head) != expected_auth_changes:
        report.add("path_failures", "AUTHORIZATION_COMMIT_NOT_EXACT_APPEND_ONLY", repr(project.changed(tooling_head, authorization_head)))
    if project.changed(authorization_head, environment_head) != expected_env_changes:
        report.add("path_failures", "ENVIRONMENT_COMMIT_NOT_EXACT_APPEND_ONLY", repr(project.changed(authorization_head, environment_head)))
    authorization, authorization_raw = _validate_authorization(project, authorization_head, tooling_head, report)
    if authorization is None or authorization_raw is None:
        return report.finish()
    environment, environment_raw = _validate_environment(project, environment_head, authorization_head, authorization, authorization_raw, report)
    if environment is None or environment_raw is None:
        return report.finish()
    receipt, receipt_raw = _validate_receipt(project, artifact_head, execution_head, execution_tree, tooling_head, tooling_tree, authorization, authorization_raw, environment_raw, report)
    if receipt is None or receipt_raw is None:
        return report.finish()
    runtime, runtime_raw = _validate_runtime(project, artifact_head, authorization, authorization_raw, environment_raw, execution_head, execution_tree, report)
    if runtime_raw is None:
        return report.finish()
    if receipt.get("mcp_runtime_evidence_sha256") != sha256_bytes(runtime_raw):
        report.add("hash_mismatches", "RECEIPT_RUNTIME_EVIDENCE_SHA256_MISMATCH", RUNTIME_EVIDENCE_PATH)
    if isinstance(runtime, dict) and receipt.get("proof") != runtime.get("proof"):
        report.add("field_mismatches", "RECEIPT_RUNTIME_PROOF_MISMATCH", "proof")
    evidence_paths = _validate_evidence_manifest(project, artifact_head, receipt, report)
    formal_paths = {RECEIPT_PATH, EVIDENCE_MANIFEST_PATH, RUNTIME_EVIDENCE_PATH} | evidence_paths
    formal_paths |= _validate_formal_documents(project, artifact_head, execution_head, execution_tree, authorization_raw, receipt_raw, report)
    actual_formal_paths = set(project.paths(artifact_head, FORMAL_ROOT))
    if formal_paths != actual_formal_paths:
        report.add("path_failures", "FORMAL_PATH_SET_MISMATCH", f"expected={sorted(formal_paths)}:actual={sorted(actual_formal_paths)}")
    actual_changes = project.changed(execution_head, artifact_head)
    expected_changes = [("A", path) for path in sorted(formal_paths)]
    if actual_changes != expected_changes:
        report.add("path_failures", "FORMAL_COMMIT_NOT_EXACT_APPEND_ONLY", f"expected={expected_changes}:actual={actual_changes}")
    for path in sorted(formal_paths | {AUTHORIZATION_PATH, AUTHORIZATION_SIDECAR_PATH, ENVIRONMENT_SEAL_PATH, ENVIRONMENT_SIDECAR_PATH}):
        try:
            if project.read(artifact_head, path) != project.read(evaluated_head, path):
                report.add("hash_mismatches", "GENERATION9_ARTIFACT_DRIFT_AFTER_APPEND", path)
        except Exception as exc:
            report.add("path_failures", "GENERATION9_ARTIFACT_UNAVAILABLE", f"{path}:{exc}")
    report.receipt_bindings.append({
        "step_id": "STEP11", "receipt_id": receipt["receipt_id"], "path": RECEIPT_PATH,
        "sha256": sha256_bytes(receipt_raw), "status": receipt["status"],
        "subject_head_sha": PRODUCT_HEAD, "subject_tree_sha": PRODUCT_TREE,
        "execution_head_sha": execution_head, "execution_tree_sha": execution_tree,
    })
    return report.finish()


def schema_descriptor() -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "python_type": "V076Generation9Step11ReceiptV1",
        "unknown_field_policy": "REJECT",
        "field_count": len(RECEIPT_FIELDS),
        "fields": sorted(RECEIPT_FIELDS),
        "required_generation_id": GENERATION_ID,
        "required_resume_evidence_id": EVIDENCE_ID,
        "required_positive_proof_fields": sorted(POSITIVE_PROOF_FIELDS),
        "required_zero_proof_fields": sorted(ZERO_PROOF_FIELDS),
        "required_check_context": CHECK_CONTEXT,
        "canonical_json": {"encoding": "UTF-8", "key_order": "UNICODE_CODEPOINT_ASCENDING", "separators": [",", ":"], "array_order": "PRESERVED", "terminal_lf": True, "allow_nan": False, "canonical_hash_excludes": ["canonical_payload_sha256"]},
    }


def _write(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_json_bytes(value))


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def _working_canonical(path: Path) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes()
    value = json.loads(raw.decode("utf-8"))
    if not isinstance(value, dict) or raw != canonical_json_bytes(value):
        raise ValueError(f"WORKING_JSON_NOT_CANONICAL:{path}")
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        raise ValueError(f"WORKING_JSON_CANONICAL_HASH_MISMATCH:{path}")
    return value, raw


def _package_formal(project_root: Path, evidence_root: Path) -> dict[str, Any]:
    project_root = project_root.resolve()
    evidence_root = evidence_root.resolve()
    project = GitProject(project_root)
    execution_head = project.commit("HEAD")
    execution_tree = project.tree(execution_head)
    if str(project._git("status", "--porcelain=v1", "--untracked-files=no")):
        raise ValueError("TRACKED_WORKTREE_NOT_CLEAN_BEFORE_PACKAGING")
    authorization_head = project.parent(execution_head)
    tooling_head = project.parent(authorization_head)
    tooling_tree = project.tree(tooling_head)
    if project.read(execution_head, ENVIRONMENT_SEAL_PATH) != project.read("HEAD", ENVIRONMENT_SEAL_PATH):
        raise ValueError("ENVIRONMENT_SEAL_HEAD_BINDING_FAILED")
    authorization, authorization_raw = _working_canonical(project_root / AUTHORIZATION_PATH)
    environment, environment_raw = _working_canonical(project_root / ENVIRONMENT_SEAL_PATH)
    if authorization_raw != project.read(execution_head, AUTHORIZATION_PATH) or environment_raw != project.read(execution_head, ENVIRONMENT_SEAL_PATH):
        raise ValueError("PREEXECUTION_WORKING_SEAL_DRIFT")
    if authorization.get("status") != "SEALED" or environment.get("status") != "SEALED_PRE_EXECUTION":
        raise ValueError("PREEXECUTION_SEAL_STATUS_INVALID")
    if environment.get("authorization_head_sha") != authorization_head or authorization.get("base_head_sha") != tooling_head:
        raise ValueError("PREEXECUTION_COMMIT_CHAIN_INVALID")
    if environment.get("authorization_manifest_sha256") != sha256_bytes(authorization_raw):
        raise ValueError("PREEXECUTION_AUTHORIZATION_HASH_INVALID")

    result_path = evidence_root / "formal-execution-result.json"
    result_raw = result_path.read_bytes()
    result = json.loads(result_raw.decode("utf-8"))
    if not isinstance(result, dict):
        raise ValueError("FORMAL_RESULT_OBJECT_REQUIRED")
    if result.get("execution_head_sha") != execution_head or result.get("execution_tree_sha") != execution_tree:
        raise ValueError("FORMAL_RESULT_EXECUTION_HEAD_MISMATCH")
    derived = _derive_runtime_components(result)

    preflight = json.loads((evidence_root / "preflight.json").read_text(encoding="utf-8"))
    consumption = json.loads((evidence_root / "formal-execution-consumption.json").read_text(encoding="utf-8"))
    focus = json.loads((evidence_root / "external-seed-focus-complete.json").read_text(encoding="utf-8"))
    if not isinstance(preflight, dict) or not isinstance(preflight.get("checks"), dict):
        raise ValueError("FORMAL_PREFLIGHT_INVALID")
    checks = preflight["checks"]
    boolean_checks = [
        "head_matches_environment_commit", "tree_matches_head", "authorization_id_match",
        "generation_id_match", "evidence_id_match", "product_identity_match", "seed_match",
        "qualification_seal_sha256_match", "pass_pair_sha256_match",
        "post_restart_seal_sha256_match", "class_cache_sha256_match",
        "authorization_manifest_sha256_match", "godot_binary_sha256_match",
        "mcp_config_sha256_match", "canonical_import_manifest_sha256_match",
        "receipt_schema_sha256_match", "receipt_validator_sha256_match",
        "receipt_selftest_sha256_match", "required_workflow_sha256_match",
        "formal_runner_sha256_match", "formal_runner_selftest_sha256_match",
        "tooling_seal_sha256_match",
    ]
    if any(checks.get(field) is not True for field in boolean_checks):
        raise ValueError("FORMAL_PREFLIGHT_BOOLEAN_CHECK_FAILED")
    if checks.get("environment_seal_status") != "SEALED_PRE_EXECUTION" or checks.get("authorization_status") != "SEALED" or checks.get("boot_id_actual") != checks.get("boot_id_expected"):
        raise ValueError("FORMAL_PREFLIGHT_IDENTITY_CHECK_FAILED")
    if checks.get("tracked_delta_count") != 0 or checks.get("new_stability_event_count") != 0 or checks.get("import_pending_count") != 0 or checks.get("godot_process_count") != 0 or checks.get("listener_count") != 0:
        raise ValueError("FORMAL_PREFLIGHT_ZERO_COUNT_FAILED")
    if not _exact_int(checks.get("available_commit_bytes")) or checks["available_commit_bytes"] < 8 * 1024**3:
        raise ValueError("FORMAL_PREFLIGHT_COMMIT_CAPACITY_FAILED")
    if checks.get("formal_execution_count_before") != 0 or checks.get("automatic_retry") is not False:
        raise ValueError("FORMAL_PREFLIGHT_EXECUTION_BUDGET_FAILED")
    if consumption.get("status") != "CONSUMED" or consumption.get("formal_execution_count") != 1 or consumption.get("automatic_retry_count") != 0:
        raise ValueError("FORMAL_CONSUMPTION_INVALID")
    if consumption.get("execution_head_sha") != execution_head or consumption.get("execution_tree_sha") != execution_tree:
        raise ValueError("FORMAL_CONSUMPTION_HEAD_MISMATCH")
    expected_focus = {
        "status": "PASS", "exact_window_title": "太空辛迪加 (DEBUG)", "window_match_count": 1,
        "window_activation_count": 1, "seed_field_click_count": 1,
        "direct_runtime_seed_injection_count": 0, "full_window_frame_screenshot_used": True,
        "runtime_viewport_coordinate_used_for_click": False,
    }
    for field, expected in expected_focus.items():
        if focus.get(field) != expected:
            raise ValueError(f"FORMAL_FOCUS_WITNESS_INVALID:{field}")
    if focus.get("editor_pid") != consumption.get("first_product_process_pid"):
        raise ValueError("FORMAL_FOCUS_PID_MISMATCH")
    cleanup_source = result.get("process_cleanup")
    if not isinstance(cleanup_source, dict):
        raise ValueError("FORMAL_CLEANUP_MISSING")
    cleanup = {field: cleanup_source.get(field) for field in PROCESS_CLEANUP_FIELDS}
    cleanup_report = Report()
    _validate_cleanup(cleanup_report, cleanup, "package.cleanup")
    if cleanup_report.codes:
        raise ValueError(f"FORMAL_CLEANUP_INVALID:{cleanup_report.codes}")
    if cleanup_source.get("forced_stop") is not False or cleanup_source.get("stopped") is not True:
        raise ValueError("FORMAL_CLEANUP_NOT_NORMAL")
    screenshots = sorted((evidence_root / "screenshots").glob("*.png"))
    if len(screenshots) != 4 or any(path.stat().st_size < 1024 for path in screenshots):
        raise ValueError("FORMAL_HEADED_SCREENSHOT_SET_INVALID")
    raw_responses = sorted((evidence_root / "raw").glob("*.jsonrpc.json"))
    if len(raw_responses) < 20:
        raise ValueError("FORMAL_RAW_MCP_RESPONSE_SET_INCOMPLETE")

    formal_root = project_root / FORMAL_ROOT
    if formal_root.exists():
        raise ValueError("FORMAL_OUTPUT_ROOT_ALREADY_EXISTS")
    formal_parent = formal_root.parent
    formal_parent.mkdir(parents=True, exist_ok=True)
    temporary = formal_parent / ".formal-attempt-001.packaging-tmp"
    if temporary.exists():
        raise ValueError("FORMAL_PACKAGING_TEMP_ALREADY_EXISTS")
    try:
        evidence_output = temporary / "evidence"
        raw_output = evidence_output / "raw"
        raw_output.mkdir(parents=True)
        (evidence_output / "source-formal-execution-result.json").write_bytes(result_raw)
        for source in sorted(path for path in evidence_root.rglob("*") if path.is_file() and not path.is_symlink()):
            relative = source.relative_to(evidence_root)
            if relative.as_posix() == "formal-execution-result.json":
                continue
            if any(part in ("", ".", "..") for part in relative.parts):
                raise ValueError(f"UNSAFE_EXTERNAL_EVIDENCE_PATH:{relative}")
            destination = raw_output.joinpath(*relative.parts)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

        injection_counters = {field: 0 for field in INJECTION_FIELDS}
        connection = result.get("mcp_connection")
        if not isinstance(connection, dict) or not _exact_int(connection.get("pid")):
            raise ValueError("FORMAL_MCP_CONNECTION_INVALID")
        runtime = {
            "schema_version": RUNTIME_SCHEMA_VERSION,
            "step_id": "STEP11",
            "generation_id": GENERATION_ID,
            "resume_evidence_id": EVIDENCE_ID,
            "authorization_manifest_sha256": sha256_bytes(authorization_raw),
            "environment_seal_sha256": sha256_bytes(environment_raw),
            "subject_head_sha": PRODUCT_HEAD,
            "subject_tree_sha": PRODUCT_TREE,
            "execution_head_sha": execution_head,
            "execution_tree_sha": execution_tree,
            "production_scene_path": SCENE,
            "execution_mode": "MCP_REAL_MAIN_TSCN_NATURAL_UI",
            "diagnostic_only": False,
            "fixture_only": False,
            "mcp_tool_identity": "role-godot-mcp/full",
            "mcp_protocol_version": "jsonrpc-2.0",
            "mcp_session_id": f"generation9-formal-attempt-001-editor-{connection['pid']}-port-{connection.get('port', 23207)}",
            "godot_binary_sha256": result.get("godot_binary_sha256"),
            "project_godot_sha256": sha256_bytes(project.read(execution_head, PROJECT_FILE_PATH)),
            "main_tscn_sha256": sha256_bytes(project.read(execution_head, MAIN_SCENE_PATH)),
            "runtime_composition_sha256": sha256_bytes(project.read(execution_head, RUNTIME_COMPOSITION_PATH)),
            "production_screen_sha256": sha256_bytes(project.read(execution_head, PRODUCTION_SCREEN_PATH)),
            "session_started_at_utc": result.get("started_at_utc"),
            "session_ended_at_utc": result.get("ended_at_utc"),
            "scene_started_via_mcp": True,
            "mcp_real_runtime_observed": True,
            "selected_seed": SEED,
            "player_count": PLAYER_COUNT,
            "new_game_profile": PROFILE,
            "acquired_card_definition_id": "military.air_superiority_fighter.shipping.rank_1",
            "mission_kind": "ASSAULT_REGION",
            "target_region_id": "region.005",
            **derived,
            "injection_counters": injection_counters,
            "runtime_error_count": 0,
            "invalid_action_count": 0,
        }
        runtime["canonical_payload_sha256"] = canonical_payload_sha256(runtime)
        runtime_path = evidence_output / "mcp_runtime_evidence.json"
        _write(runtime_path, runtime)

        artifact_rows = []
        for artifact in sorted(path for path in evidence_output.rglob("*") if path.is_file()):
            committed_path = f"{FORMAL_ROOT}/" + artifact.relative_to(temporary).as_posix()
            data = artifact.read_bytes()
            artifact_rows.append({"path": committed_path, "sha256": sha256_bytes(data), "size_bytes": len(data)})
        evidence_manifest = {
            "schema_version": EVIDENCE_MANIFEST_SCHEMA_VERSION,
            "manifest_id": "v076-generation9-step11-evidence-manifest-001",
            "generation_id": GENERATION_ID,
            "resume_evidence_id": EVIDENCE_ID,
            "receipt_id": "v076-current-subject-step11-generation9-formal-attempt-001",
            "evidence_root": f"{FORMAL_ROOT}/evidence",
            "artifact_count": len(artifact_rows),
            "artifacts": artifact_rows,
        }
        evidence_manifest["canonical_payload_sha256"] = canonical_payload_sha256(evidence_manifest)
        evidence_manifest_path = evidence_output / "step11_evidence_manifest.json"
        _write(evidence_manifest_path, evidence_manifest)

        created_at = _utc_now()
        receipt = {
            "schema_version": SCHEMA_VERSION,
            "receipt_id": "v076-current-subject-step11-generation9-formal-attempt-001",
            "receipt_kind": "CURRENT_SUBJECT_PRODUCTION_REVALIDATION",
            "authorization_id": AUTHORIZATION_ID,
            "step_id": "STEP11",
            "generation_id": GENERATION_ID,
            "resume_evidence_id": EVIDENCE_ID,
            "subject_head_sha": PRODUCT_HEAD,
            "subject_tree_sha": PRODUCT_TREE,
            "live_pr_head_sha": execution_head,
            "live_pr_tree_sha": execution_tree,
            "required_check_context": CHECK_CONTEXT,
            "producer_tooling_head_sha": tooling_head,
            "producer_tooling_tree_sha": tooling_tree,
            "producer_script_path": VALIDATOR_PATH,
            "producer_script_sha256": authorization["receipt_validator_sha256"],
            "schema_authority_path": VALIDATOR_PATH,
            "schema_authority_sha256": authorization["receipt_schema_sha256"],
            "validator_path": VALIDATOR_PATH,
            "validator_sha256": authorization["receipt_validator_sha256"],
            "workflow_path": WORKFLOW_PATH,
            "workflow_sha256": authorization["required_workflow_sha256"],
            "tooling_seal_path": TOOLING_SEAL_PATH,
            "tooling_seal_sha256": authorization["tooling_seal_sha256"],
            "resume_authorization_manifest_path": AUTHORIZATION_PATH,
            "resume_authorization_manifest_sha256": sha256_bytes(authorization_raw),
            "environment_seal_path": ENVIRONMENT_SEAL_PATH,
            "environment_seal_sha256": sha256_bytes(environment_raw),
            "previous_receipt_path": PARENT_RECEIPT_PATH,
            "previous_receipt_sha256": sha256_bytes(project.read(execution_head, PARENT_RECEIPT_PATH)),
            "previous_receipt_status": "BLOCKED",
            "evidence_manifest_path": EVIDENCE_MANIFEST_PATH,
            "evidence_manifest_sha256": sha256_bytes(evidence_manifest_path.read_bytes()),
            "mcp_runtime_evidence_path": RUNTIME_EVIDENCE_PATH,
            "mcp_runtime_evidence_sha256": sha256_bytes(runtime_path.read_bytes()),
            "status": "PASS",
            "check_count": len(PROOF_FIELDS),
            "pass_count": len(PROOF_FIELDS),
            "failure_count": 0,
            "failure_codes": [],
            "formal_execution_count": 1,
            "automatic_retry_count": 0,
            "proof": derived["proof"],
            "process_cleanup": cleanup,
            "created_at_utc": created_at,
            "extensions": {},
        }
        receipt["result_fingerprint_sha256"] = result_fingerprint_sha256(receipt)
        receipt["canonical_payload_sha256"] = canonical_payload_sha256(receipt)
        receipt_path = temporary / "receipts" / "step11_receipt.json"
        _write(receipt_path, receipt)

        execution_start = {
            "schema_version": EXECUTION_START_SCHEMA_VERSION, "status": "STARTED",
            "authorization_id": AUTHORIZATION_ID, "authorization_manifest_sha256": sha256_bytes(authorization_raw),
            "generation_id": GENERATION_ID, "parent_generation_id": PARENT_GENERATION_ID,
            "parent_evidence_id": PARENT_EVIDENCE_ID, "new_evidence_id": EVIDENCE_ID,
            "formal_attempt_id": "formal-attempt-001", "formal_execution_count": 1,
            "automatic_retry_count": 0, "execution_head_sha": execution_head,
            "execution_tree_sha": execution_tree, "product_subject_head_sha": PRODUCT_HEAD,
            "product_subject_tree_sha": PRODUCT_TREE, "selected_seed": SEED,
            "player_count": PLAYER_COUNT, "new_game_profile": PROFILE,
            "production_scene_path": SCENE, "execution_mode": "MCP_REAL_MAIN_TSCN_NATURAL_UI",
            "injection_counters": injection_counters, "started_at_utc": result.get("started_at_utc"),
        }
        execution_start["canonical_payload_sha256"] = canonical_payload_sha256(execution_start)
        _write(temporary / "execution-start.json", execution_start)
        progress = {
            "schema_version": PROGRESS_SCHEMA_VERSION, "status": "COMPLETED",
            "generation_id": GENERATION_ID, "new_evidence_id": EVIDENCE_ID,
            "formal_attempt_id": "formal-attempt-001", "formal_execution_count": 1,
            "automatic_retry_count": 0, "current_step": "STEP11_ASSAULT_REGION_COMPLETE_MAJOR_ROUND",
            "step11_status": "PASS", "accepted_action_drain_status": "QUIESCENT",
            "process_cleanup_status": "PASS", "started_at_utc": result.get("started_at_utc"),
            "completed_at_utc": created_at,
        }
        progress["canonical_payload_sha256"] = canonical_payload_sha256(progress)
        _write(temporary / "progress.json", progress)
        summary = {
            "schema_version": SUMMARY_SCHEMA_VERSION, "status": "PASS", "generation_id": GENERATION_ID,
            "parent_generation_id": PARENT_GENERATION_ID, "parent_evidence_id": PARENT_EVIDENCE_ID,
            "new_evidence_id": EVIDENCE_ID, "authorization_manifest_sha256": sha256_bytes(authorization_raw),
            "formal_attempt_id": "formal-attempt-001", "formal_execution_count": 1,
            "automatic_retry_count": 0, "step11_receipt_path": RECEIPT_PATH,
            "step11_receipt_sha256": sha256_bytes(receipt_path.read_bytes()), "step11_receipt_status": "PASS",
            "step11_required_positive_field_count": len(POSITIVE_PROOF_FIELDS),
            "step11_required_positive_field_pass_count": len(POSITIVE_PROOF_FIELDS),
            "step11_required_zero_field_count": len(ZERO_PROOF_FIELDS),
            "step11_required_zero_field_pass_count": len(ZERO_PROOF_FIELDS),
            "generation7_step11_receipt_status": "BLOCKED", "generation8_step11_receipt_status": "BLOCKED",
            "generation7_modification_count": 0, "generation8_modification_count": 0,
            "generation7_rerun_count": 0, "generation8_rerun_count": 0,
            "process_cleanup_status": "PASS", "completed_at_utc": created_at,
        }
        summary["canonical_payload_sha256"] = canonical_payload_sha256(summary)
        _write(temporary / "summary.json", summary)
        temporary.replace(formal_root)
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
    formal_paths = sorted(path.relative_to(project_root).as_posix() for path in formal_root.rglob("*") if path.is_file())
    return {
        "status": "PASS", "generation_id": GENERATION_ID, "resume_evidence_id": EVIDENCE_ID,
        "execution_head_sha": execution_head, "execution_tree_sha": execution_tree,
        "formal_path_count": len(formal_paths), "formal_paths": formal_paths,
        "receipt_sha256": sha256_bytes((project_root / RECEIPT_PATH).read_bytes()),
        "evidence_manifest_sha256": sha256_bytes((project_root / EVIDENCE_MANIFEST_PATH).read_bytes()),
        "runtime_evidence_sha256": sha256_bytes((project_root / RUNTIME_EVIDENCE_PATH).read_bytes()),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    schema = sub.add_parser("schema")
    schema.add_argument("--report-json", type=Path)
    validate = sub.add_parser("validate")
    validate.add_argument("--project", type=Path, required=True)
    validate.add_argument("--expected-consumer-head", required=True)
    validate.add_argument("--report-json", type=Path, required=True)
    package = sub.add_parser("package")
    package.add_argument("--project", type=Path, required=True)
    package.add_argument("--evidence-root", type=Path, required=True)
    package.add_argument("--report-json", type=Path, required=True)
    args = parser.parse_args(argv)
    if args.command == "schema":
        payload = schema_descriptor()
        if args.report_json:
            _write(args.report_json, payload)
        sys.stdout.buffer.write(canonical_json_bytes(payload))
        return 0
    try:
        payload = (
            _package_formal(args.project, args.evidence_root)
            if args.command == "package"
            else validate_repository(args.project, args.expected_consumer_head)
        )
    except Exception as exc:
        if args.command == "package":
            payload = {"status": "FAIL", "generation_id": GENERATION_ID, "resume_evidence_id": EVIDENCE_ID, "failure": str(exc)}
        else:
            payload = Report().finish()
            payload["validator_status"] = "FAIL"
            payload["failure_codes"] = ["VALIDATOR_UNHANDLED_EXCEPTION"]
            payload["identity_mismatches"] = [f"VALIDATOR_UNHANDLED_EXCEPTION:{exc}"]
    _write(args.report_json, payload)
    sys.stdout.buffer.write(canonical_json_bytes(payload))
    return 0 if payload.get("validator_status") == "PASS" or (args.command == "package" and payload.get("status") == "PASS") else 1


if __name__ == "__main__":
    raise SystemExit(main())
