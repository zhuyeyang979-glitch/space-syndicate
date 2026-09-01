#!/usr/bin/env python3
"""Fail-closed authority for V076 current-subject revalidation receipts.

This module is deliberately the only schema and validator authority for
``V076CurrentSubjectProductionRevalidationReceiptV1``.  The Required Gate calls
the CLI in this file once.  Subject identity and the three allowed receipt
paths remain owned by the frozen candidate-subject manifest.

Validation reads committed Git objects, never mutable worktree bytes.  A
receipt binds the execution Head/Tree; the validating Head must be its single
direct append-only successor and that successor may contain only the exact
receipt/evidence files declared by the frozen manifest and evidence manifests.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, fields
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = (
    "space_syndicate.v076.current_subject_production_revalidation_receipt.v1"
)
RECEIPT_KIND = "CURRENT_SUBJECT_PRODUCTION_REVALIDATION"
EVIDENCE_MANIFEST_SCHEMA_VERSION = (
    "space_syndicate.v076.current_subject_receipt_evidence_manifest.v1"
)
RUNTIME_EVIDENCE_SCHEMA_VERSION = (
    "space_syndicate.v076.current_subject_mcp_runtime_evidence.v1"
)
TOOLING_SEAL_SCHEMA_VERSION = (
    "space_syndicate.v076.current_subject_receipt_tooling_seal.v1"
)
NEGATIVE_FIXTURE_CATALOG_SCHEMA_VERSION = (
    "space_syndicate.v076.current_subject_receipt_negative_fixture_catalog.v1"
)
TOOL_DEPENDENCY_INVENTORY_SCHEMA_VERSION = (
    "space_syndicate.v076.current_subject_receipt_tool_dependency_inventory.v1"
)
INDEPENDENT_AUDIT_SCHEMA_VERSION = (
    "space_syndicate.v076.current_subject_receipt_independent_audit.v1"
)
RESUME_AUTHORIZATION_SCHEMA_VERSION = (
    "space_syndicate.v076.generation7_resume_authorization_manifest.v1"
)
AUTHORIZATION_ID = (
    "USER_AUTHORIZATION_V076_RECEIPT_CONTRACT_AND_GENERATION7_RESUME_20260831"
)
REQUIRED_CHECK_CONTEXT = "V076 Reuse and Point-Inertia Gate"
AUTHORIZED_GENERATION_ID = 7
AUTHORIZED_RESUME_EVIDENCE_ID = 9631
AUTHORIZED_BASE_HEAD_SHA = "5373e0b01742d35330d6dc57391b1420bc217035"
AUTHORIZED_HARD_STOP_SHA256 = (
    "3309a0cba6ff34d82f0575ecdfe50d22abeed5a0b7619bb0fe61cb44b1ff7c0c"
)
FROZEN_EVIDENCE_INVENTORY_SHA256 = (
    "ded0c0e54c9c8560342bbdd07c210ac4a922638ada655547e84978015872a1a9"
)
REQUIRED_MCP_TOOL_IDENTITY = "Funplay MCP 0.9.6"
REQUIRED_MCP_PROTOCOL_VERSION = "2025-11-25"
REQUIRED_GODOT_BINARY_SHA256 = (
    "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"
)
RESUME_START_CHECKPOINT = "STEP09_CONTINUE_FROM_EVIDENCE_9631"
HARD_STOP_ATTESTATION_PATH = (
    "reports/reuse/generation7_receipt_contract/hard_stop_identity_attestation.json"
)
HARD_STOP_ATTESTATION_SHA256 = (
    "e9d356dd887cc0dd44aa260360d48fd61951a7895a35d3608ef9e9495fbb81bd"
)
EVIDENCE_9631_ATTESTATION_PATH = (
    "reports/reuse/generation7_receipt_contract/evidence_9631_identity_attestation.json"
)
EVIDENCE_9631_ATTESTATION_SHA256 = (
    "b18b225f9a188bc0f12743aa633044c87f6062a9ea26cbf4df85402efc57970b"
)
FROZEN_INPUT_INVENTORY_PATH = (
    "reports/reuse/generation7_receipt_contract/frozen_input_inventory.json"
)
FROZEN_INPUT_INVENTORY_SHA256 = (
    "b32df15ff045207d5bc69a2d54a2b03adad364f4512077de36eeee00c7555f4e"
)
FROZEN_INPUT_SIDECAR_PATH = (
    "reports/reuse/generation7_receipt_contract/frozen_input_inventory.sha256"
)
FROZEN_INPUT_SIDECAR_SHA256 = (
    "d13afc68780e15a5b028d5ba8c8d2bdd4419047dd85da82a7b7129bbbe4854c8"
)
CURRENT_SUBJECT_HEAD_SHA = "ac5efcc5a5119b8022b573333f707b3a73bff590"
CURRENT_SUBJECT_TREE_SHA = "9757eef0e73118f89356b0c09833a44c2c76f8ee"
CURRENT_SUBJECT_MANIFEST_PATH = (
    "reports/reuse/full_convergence/candidate_subject_manifest_ac5efcc5.json"
)
CURRENT_SUBJECT_MANIFEST_SHA256 = (
    "446aa8d52b3936977e78776741e020d3cda0d10d310c20561dd47c243b0bef9f"
)
SCHEMA_AUTHORITY_PATH = "tools/v076/v076_current_subject_revalidation_receipt.py"
VALIDATOR_PATH = SCHEMA_AUTHORITY_PATH
PRODUCER_SCRIPT_PATH = SCHEMA_AUTHORITY_PATH
SELFTEST_PATH = "tools/v076/v076_current_subject_revalidation_receipt_selftest.py"
WORKFLOW_PATH = ".github/workflows/v076-reuse-point-inertia-gate.yml"
PREDECESSOR_TOOLING_HEAD_SHA = "a8df7ca77a4dffcdfb0c6c1c999f24de20b5eaa6"
PREDECESSOR_TOOLING_TREE_SHA = "e5c1c33f33cc3a9377fe7cc491da9baa51ebd82e"
PREDECESSOR_TOOLING_SEAL_PATH = (
    "reports/reuse/generation7_receipt_contract/tooling_seal.json"
)
PREDECESSOR_TOOLING_SEAL_SHA256 = (
    "0bd8d92528a76eb81a76b17024b662dd4f470d085b927b0f7ae4f9d576f85af0"
)
PREDECESSOR_RESUME_AUTHORIZATION_MANIFEST_PATH = (
    "reports/reuse/generation7_receipt_contract/"
    "generation7_resume_authorization_manifest.json"
)
PREDECESSOR_RESUME_AUTHORIZATION_MANIFEST_SHA256 = (
    "512864ca2d57d35789a8fc70d89bb4e8552ad1b9f89844dcbf4bf6ede5e0da95"
)
PREDECESSOR_RESUME_HEAD_SHA = "9f6d8339c3f212cb6de87fed7e0fe62e4fcf70c8"
PREDECESSOR_RESUME_TREE_SHA = "5c7b0346bca664a5af0bb25b62bdd77239d81e52"
PREDECESSOR_SUCCESSOR_V2_TOOLING_HEAD_SHA = (
    "f2a69c15f3f2e932217c80456b264f48303d9b61"
)
PREDECESSOR_SUCCESSOR_V2_TOOLING_TREE_SHA = (
    "93d09ffeb3a4d6231a374bbd125ae4aba9a98486"
)
PREDECESSOR_SUCCESSOR_V2_TOOLING_SEAL_PATH = (
    "reports/reuse/generation7_receipt_contract_successor_v2/tooling_seal.json"
)
PREDECESSOR_SUCCESSOR_V2_TOOLING_SEAL_SHA256 = (
    "622207d99f0ec82b5dee0c655a27c29527863acdb641b95d59aa1f4dcb942fcc"
)
PREDECESSOR_SUCCESSOR_V2_RESUME_AUTHORIZATION_MANIFEST_PATH = (
    "reports/reuse/generation7_receipt_contract_successor_v2/"
    "generation7_resume_authorization_manifest.json"
)
PREDECESSOR_SUCCESSOR_V2_RESUME_AUTHORIZATION_MANIFEST_SHA256 = (
    "5eed4ea6d9c87feb74902cfd873446cca0ec6fd64756ab405f6ab86485e9cb27"
)
PREDECESSOR_SUCCESSOR_V2_RESUME_HEAD_SHA = (
    "235cbb1fc143d11a269c21ceeff4c2e7efc884de"
)
PREDECESSOR_SUCCESSOR_V2_RESUME_TREE_SHA = (
    "bd1c342de57a5bd2c0dc0cbde7a564e75436d359"
)
PREDECESSOR_SUCCESSOR_V3_TOOLING_HEAD_SHA = (
    "7fb4a10c246ecc3355fd3fdb1d131477a663a3e0"
)
PREDECESSOR_SUCCESSOR_V3_TOOLING_TREE_SHA = (
    "969730f41577860d649edfd52fd3c966e6623fba"
)
PREDECESSOR_SUCCESSOR_V3_TOOLING_SEAL_PATH = (
    "reports/reuse/generation7_receipt_contract_successor_v3/tooling_seal.json"
)
PREDECESSOR_SUCCESSOR_V3_TOOLING_SEAL_SHA256 = (
    "eb65c427ee9e32badf3d92d6da472b6ad2ea3bc26d695f52d97cd310f3cf60c7"
)
PREDECESSOR_SUCCESSOR_V3_RESUME_AUTHORIZATION_MANIFEST_PATH = (
    "reports/reuse/generation7_receipt_contract_successor_v3/"
    "generation7_resume_authorization_manifest.json"
)
PREDECESSOR_SUCCESSOR_V3_RESUME_AUTHORIZATION_MANIFEST_SHA256 = (
    "e0a582f0a8af61badf30dcf5fd9816990a860cd1122a1b25c742114c2c79fa33"
)
PREDECESSOR_SUCCESSOR_V3_RESUME_HEAD_SHA = (
    "726c86e7d35a12191e9c3d927042bf9c99cb9fc5"
)
PREDECESSOR_SUCCESSOR_V3_RESUME_TREE_SHA = (
    "7a668eea4e6c49c5da41a0727c12fba7395d376f"
)
SUCCESSOR_TOOLING_ROOT = (
    "reports/reuse/generation7_receipt_contract_successor_v4"
)
TOOLING_SEAL_PATH = f"{SUCCESSOR_TOOLING_ROOT}/tooling_seal.json"
NEGATIVE_FIXTURE_CATALOG_PATH = (
    f"{SUCCESSOR_TOOLING_ROOT}/negative_fixture_catalog.json"
)
TOOL_DEPENDENCY_INVENTORY_PATH = (
    "reports/reuse/generation7_receipt_contract/tool_dependency_inventory.json"
)
AUDIT_A_PATH = f"{SUCCESSOR_TOOLING_ROOT}/audit_a.json"
AUDIT_B_PATH = f"{SUCCESSOR_TOOLING_ROOT}/audit_b.json"
RESUME_AUTHORIZATION_MANIFEST_PATH = (
    f"{SUCCESSOR_TOOLING_ROOT}/generation7_resume_authorization_manifest.json"
)
REQUIRED_RECEIPT_SPECS: tuple[tuple[str, str], ...] = (
    (
        "STEP09",
        "reports/reuse/full_convergence/current_subject/ac5efcc5/"
        "step09_receipt.json",
    ),
    (
        "STEP11",
        "reports/reuse/full_convergence/current_subject/ac5efcc5/"
        "step11_receipt.json",
    ),
    (
        "STEP12",
        "reports/reuse/full_convergence/current_subject/ac5efcc5/"
        "step12_receipt.json",
    ),
)
REQUIRED_RECEIPT_PATH_BY_STEP = dict(REQUIRED_RECEIPT_SPECS)
RECEIPT_ROOT = "reports/reuse/full_convergence/current_subject/ac5efcc5"

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
GIT_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
RECEIPT_ID_RE = re.compile(r"^v076-current-subject-(step09|step11|step12)-[a-z0-9][a-z0-9._-]{7,119}$")
RFC3339_UTC_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z$"
)
FAILURE_CODE_RE = re.compile(r"^[A-Z][A-Z0-9_]{2,127}$")
NEGATIVE_CASE_ID_RE = re.compile(
    rb'\bnegative\(\s*"([A-Z][A-Z0-9_]{2,127})"'
)
GENERATION8_NEGATIVE_CASE_ID_RE = re.compile(
    rb'\b(?:negative|generation8_negative)\(\s*"([A-Z][A-Z0-9_]{2,127})"'
)
REQUIRED_NEGATIVE_CASE_COUNT = 112
REQUIRED_NEGATIVE_CASE_ID_SET_SHA256 = (
    "3f2152db36028a12ed79e22b49d2291f84cff0e291075f954b3840ebd2b55a2a"
)
REQUIRED_SELFTEST_CASE_COUNT = 132

GENERATION8_AUTHORIZATION_ID = (
    "USER_AUTHORIZATION_V076_STEP11_REACHABILITY_AND_GENERATION8_20260831"
)
GENERATION8_ID = 8
GENERATION8_PARENT_ID = 7
GENERATION8_PARENT_EVIDENCE_ID = 9631
GENERATION7_ARTIFACT_HEAD_SHA = (
    "aecb487d34e34c8a9580e27771c70ecd261d413e"
)
GENERATION7_FROZEN_RECEIPT_SHA256_BY_STEP = {
    "STEP09": "f3e5c3434606fea5c16543b6ff0778a74330c217c7bf7d697f2103461c339ea9",
    "STEP11": "bccce99c1954bed877fd81a4046c7ddc06c3f983a1707e9bba330b230cde3233",
    "STEP12": "d8092c41d347aa3480d1117dbdc5899bdd023dee06fa150713415cf84773aba0",
}
GENERATION7_FROZEN_RECEIPT_STATUS_BY_STEP = {
    "STEP09": "PASS",
    "STEP11": "BLOCKED",
    "STEP12": "PASS",
}
GENERATION7_SUMMARY_DERIVATION = "CANONICAL_RECEIPT_CHAIN_V1"
GENERATION8_EVIDENCE_ID_DERIVATION = "MAX_REGISTERED_EVIDENCE_ID_PLUS_ONE_V1"
GENERATION8_AUTHORIZATION_SCHEMA_VERSION = (
    "space_syndicate.v076.generation8_authorization_manifest.v1"
)
GENERATION8_TOOLING_SEAL_SCHEMA_VERSION = (
    "space_syndicate.v076.generation8_receipt_tooling_seal.v1"
)
GENERATION8_RUNTIME_EVIDENCE_SCHEMA_VERSION = (
    "space_syndicate.v076.generation8_step11_mcp_runtime_evidence.v1"
)
GENERATION8_EXECUTION_START_SCHEMA_VERSION = (
    "space_syndicate.v076.generation8_execution_start.v1"
)
GENERATION8_PROGRESS_SCHEMA_VERSION = (
    "space_syndicate.v076.generation8_progress.v1"
)
GENERATION8_SUMMARY_SCHEMA_VERSION = (
    "space_syndicate.v076.generation8_summary.v1"
)
GENERATION8_EVIDENCE_MANIFEST_SCHEMA_VERSION = (
    "space_syndicate.v076.generation8_step11_evidence_manifest.v1"
)
GENERATION8_AUTHORIZATION_ROOT = (
    "reports/reuse/full_convergence/generation8"
)
GENERATION8_AUTHORIZATION_MANIFEST_PATH = (
    f"{GENERATION8_AUTHORIZATION_ROOT}/generation8_authorization_manifest.json"
)
GENERATION8_AUTHORIZATION_SIDECAR_PATH = (
    f"{GENERATION8_AUTHORIZATION_ROOT}/generation8_authorization_manifest.sha256"
)
GENERATION8_TOOLING_SEAL_PATH = (
    f"{GENERATION8_AUTHORIZATION_ROOT}/generation8_tooling_seal.json"
)
GENERATION8_CHARACTERIZATION_PATH = (
    f"{GENERATION8_AUTHORIZATION_ROOT}/step11_natural_assault_region_characterization.json"
)
GENERATION8_FOCUSED_TEST_REPORT_PATH = (
    f"{GENERATION8_AUTHORIZATION_ROOT}/generation8_focused_test_report.json"
)
GENERATION8_NEGATIVE_FIXTURE_CATALOG_PATH = (
    f"{GENERATION8_AUTHORIZATION_ROOT}/generation8_negative_fixture_catalog.json"
)
GENERATION8_MAJOR_ROUND_CONTRACT_PATH = (
    f"{GENERATION8_AUTHORIZATION_ROOT}/major_round_contract.json"
)
GENERATION8_PRODUCT_PATH_MANIFEST_PATH = (
    f"{GENERATION8_AUTHORIZATION_ROOT}/generation8_product_path_manifest.json"
)
GENERATION8_MCP_LANDING_MANIFEST_PATH = (
    "reports/development/mcp_landing/step11_reachability_repair.json"
)
GENERATION8_FORMAL_ROOT = (
    "reports/reuse/full_convergence/generation-008/formal-attempt-001"
)
GENERATION8_EXECUTION_START_PATH = f"{GENERATION8_FORMAL_ROOT}/execution-start.json"
GENERATION8_PROGRESS_PATH = f"{GENERATION8_FORMAL_ROOT}/progress.json"
GENERATION8_STEP11_RECEIPT_PATH = (
    f"{GENERATION8_FORMAL_ROOT}/receipts/step11_receipt.json"
)
GENERATION8_STEP11_EVIDENCE_MANIFEST_PATH = (
    f"{GENERATION8_FORMAL_ROOT}/evidence/step11_evidence_manifest.json"
)
GENERATION8_RUNTIME_EVIDENCE_PATH = (
    f"{GENERATION8_FORMAL_ROOT}/evidence/mcp_runtime_evidence.json"
)
GENERATION8_SOURCE_EVIDENCE_INDEX_PATH = (
    f"{GENERATION8_FORMAL_ROOT}/evidence/source_evidence_index.json"
)
GENERATION8_SUMMARY_PATH = f"{GENERATION8_FORMAL_ROOT}/summary.json"
GENERATION8_REGISTRY_INDEX_PATHS = tuple(
    f"{RECEIPT_ROOT}/evidence/{step}/source_evidence_index.json"
    for step in ("step09", "step11", "step12")
)
GENERATION8_REQUIRED_NEGATIVE_CASE_COUNT = 118
GENERATION8_REQUIRED_SELFTEST_CASE_COUNT = 140
# Filled from the complete 118-case append-only declaration set.  The focused
# self-test and workflow pin this value; the Generation 7 catalog constants
# above intentionally remain frozen at 112 cases.
GENERATION8_REQUIRED_NEGATIVE_CASE_ID_SET_SHA256 = (
    "26129c2720bf6c252bc219127ba47c420a7672912135082da0c28c3c8a02797a"
)


class StrictJsonError(ValueError):
    """Raised for duplicate keys, invalid UTF-8, or non-finite JSON values."""


class CommittedPathError(ValueError):
    """Raised when a committed path is absent, unsafe, or not a regular file."""


def _reject_duplicate_pairs(pairs: Sequence[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise StrictJsonError(f"DUPLICATE_JSON_KEY:{key}")
        result[key] = value
    return result


def _reject_nonfinite(value: str) -> None:
    raise StrictJsonError(f"NONFINITE_JSON_NUMBER:{value}")


def load_json_strict_bytes(data: bytes) -> Any:
    if data.startswith(b"\xef\xbb\xbf"):
        raise StrictJsonError("UTF8_BOM_NOT_ALLOWED")
    try:
        text = data.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise StrictJsonError(f"INVALID_UTF8:{exc.start}") from exc
    try:
        return json.loads(
            text,
            object_pairs_hook=_reject_duplicate_pairs,
            parse_constant=_reject_nonfinite,
        )
    except StrictJsonError:
        raise
    except (json.JSONDecodeError, RecursionError) as exc:
        raise StrictJsonError(f"MALFORMED_JSON:{exc}") from exc


def canonical_json_bytes(value: Any) -> bytes:
    """Return UTF-8, sorted-key, compact JSON with one terminal LF.

    Arrays retain their supplied order.  JSON null, booleans, integers, and
    strings retain their native JSON representation.  NaN and infinities are
    rejected.  Repository paths are separately required to use forward slashes.
    """

    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        ).encode("utf-8")
        + b"\n"
    )


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_payload_sha256(value: Mapping[str, Any]) -> str:
    payload = dict(value)
    payload.pop("canonical_payload_sha256", None)
    return sha256_bytes(canonical_json_bytes(payload))


RESULT_FINGERPRINT_FIELDS = (
    "receipt_kind",
    "generation_id",
    "resume_evidence_id",
    "subject_head_sha",
    "subject_tree_sha",
    "live_pr_head_sha",
    "live_pr_tree_sha",
    "step_id",
    "status",
    "check_count",
    "pass_count",
    "failure_count",
    "failure_codes",
    "evidence_manifest_sha256",
    "mcp_landing_manifest_sha256",
    "mcp_runtime_evidence_sha256",
    "process_cleanup",
)


def result_fingerprint_sha256(value: Mapping[str, Any]) -> str:
    return sha256_bytes(
        canonical_json_bytes({key: value.get(key) for key in RESULT_FINGERPRINT_FIELDS})
    )


def normalize_repo_relative_path(value: Any) -> str:
    if not isinstance(value, str) or not value:
        raise ValueError("PATH_NOT_NONEMPTY_STRING")
    if "\\" in value:
        raise ValueError("PATH_BACKSLASH_FORBIDDEN")
    if value.startswith("/") or value.startswith("//"):
        raise ValueError("PATH_ABSOLUTE_FORBIDDEN")
    if re.match(r"^[A-Za-z]:", value):
        raise ValueError("PATH_DRIVE_PREFIX_FORBIDDEN")
    if any(ord(char) < 32 for char in value):
        raise ValueError("PATH_CONTROL_CHARACTER_FORBIDDEN")
    path = PurePosixPath(value)
    if any(part in ("", ".", "..") for part in path.parts):
        raise ValueError("PATH_TRAVERSAL_OR_DOT_SEGMENT")
    normalized = path.as_posix()
    if normalized != value:
        raise ValueError("PATH_NOT_CANONICAL_POSIX")
    return normalized


def _is_exact_int(value: Any) -> bool:
    return type(value) is int


def _is_exact_bool(value: Any) -> bool:
    return type(value) is bool


def _is_sha256(value: Any) -> bool:
    return isinstance(value, str) and SHA256_RE.fullmatch(value) is not None


def _is_git_sha(value: Any) -> bool:
    return isinstance(value, str) and GIT_SHA_RE.fullmatch(value) is not None


def parse_rfc3339_utc(value: Any) -> datetime:
    if not isinstance(value, str) or RFC3339_UTC_RE.fullmatch(value) is None:
        raise ValueError("INVALID_RFC3339_UTC_FORMAT")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise ValueError("INVALID_RFC3339_UTC_VALUE") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != timezone.utc.utcoffset(parsed):
        raise ValueError("RFC3339_TIMESTAMP_NOT_UTC")
    return parsed


@dataclass(frozen=True)
class V076CurrentSubjectProductionRevalidationReceiptV1:
    schema_version: str
    receipt_id: str
    receipt_kind: str
    authorization_id: str
    step_id: str
    generation_id: int
    resume_evidence_id: int
    subject_head_sha: str
    subject_tree_sha: str
    live_pr_head_sha: str
    live_pr_tree_sha: str
    required_check_context: str
    producer_tooling_head_sha: str
    producer_tooling_tree_sha: str
    producer_script_path: str
    producer_script_sha256: str
    schema_authority_path: str
    schema_authority_sha256: str
    validator_path: str
    validator_sha256: str
    workflow_path: str
    workflow_sha256: str
    product_path_manifest_path: str
    product_path_manifest_sha256: str
    tooling_seal_path: str
    tooling_seal_sha256: str
    resume_authorization_manifest_path: str
    resume_authorization_manifest_sha256: str
    hard_stop_record_sha256: str
    existing_generation7_evidence_inventory_sha256: str
    evidence_manifest_path: str
    evidence_manifest_sha256: str
    contains_godot_product_delta: bool
    requires_mcp_runtime_evidence: bool
    mcp_landing_manifest_path: str | None
    mcp_landing_manifest_sha256: str | None
    mcp_runtime_evidence_path: str | None
    mcp_runtime_evidence_sha256: str | None
    status: str
    check_count: int
    pass_count: int
    failure_count: int
    failure_codes: list[str]
    process_cleanup: dict[str, Any]
    result_fingerprint_sha256: str
    created_at_utc: str
    previous_receipt_sha256: str | None
    canonical_payload_sha256: str
    extensions: dict[str, Any]

    @classmethod
    def from_mapping(
        cls, value: Mapping[str, Any]
    ) -> "V076CurrentSubjectProductionRevalidationReceiptV1":
        return cls(**{field.name: value[field.name] for field in fields(cls)})


RECEIPT_FIELDS = frozenset(
    field.name for field in fields(V076CurrentSubjectProductionRevalidationReceiptV1)
)
PROCESS_CLEANUP_FIELDS = frozenset(
    {
        "exit_play_mode",
        "stop_role_godot_mcp",
        "editor_pid_after",
        "game_pid_after",
        "listener_count_after",
    }
)
EVIDENCE_MANIFEST_FIELDS = frozenset(
    {
        "schema_version",
        "manifest_id",
        "generation_id",
        "resume_evidence_id",
        "receipt_id",
        "evidence_root",
        "artifact_count",
        "artifacts",
        "canonical_payload_sha256",
    }
)
EVIDENCE_ARTIFACT_FIELDS = frozenset({"path", "sha256", "size_bytes"})
RUNTIME_EVIDENCE_FIELDS = frozenset(
    {
        "schema_version",
        "step_id",
        "generation_id",
        "resume_evidence_id",
        "subject_head_sha",
        "subject_tree_sha",
        "execution_head_sha",
        "execution_tree_sha",
        "production_scene_path",
        "execution_mode",
        "diagnostic_only",
        "fixture_only",
        "mcp_tool_identity",
        "mcp_protocol_version",
        "mcp_session_id",
        "godot_binary_sha256",
        "project_godot_sha256",
        "main_tscn_sha256",
        "runtime_composition_sha256",
        "production_screen_sha256",
        "session_started_at_utc",
        "session_ended_at_utc",
        "scene_started_via_mcp",
        "mcp_real_runtime_observed",
        "proof",
        "canonical_payload_sha256",
    }
)
STEP09_PROOF_FIELDS = frozenset(
    {
        "natural_monster_event_count",
        "monster_move_authority_receipt_count",
        "terminal_move_step_receipt_count",
        "geodesic_route_receipt_count",
        "consequence_ledger_receipt_count",
        "presentation_cue_start_count",
        "presentation_cue_finish_count",
        "exact_once_binding_count",
        "duplicate_binding_count",
        "old_movement_writer_count",
        "old_trample_receipt_count",
    }
)
STEP11_PROOF_FIELDS = frozenset(
    {
        "asset_authority_receipt_count",
        "before_after_quantity_receipt_count",
        "committed_revision_receipt_count",
        "asset_delta_projection_count",
        "asset_consequence_binding_count",
        "exact_once_binding_count",
        "duplicate_binding_count",
        "ui_gameplay_mutation_count",
        "opponent_private_asset_disclosure_count",
        "asset_projection_failure_count",
    }
)
GENERATION8_STEP11_POSITIVE_PROOF_FIELDS = frozenset(
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
GENERATION8_STEP11_ZERO_PROOF_FIELDS = frozenset(
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
GENERATION8_STEP11_PROOF_FIELDS = (
    GENERATION8_STEP11_POSITIVE_PROOF_FIELDS
    | GENERATION8_STEP11_ZERO_PROOF_FIELDS
)
STEP12_PROOF_FIELDS = frozenset(
    {
        "persisted_ai_observation_envelope_count",
        "allowed_field_manifest_count",
        "observation_source_receipt_binding_count",
        "ai_public_action_receipt_count",
        "sanitized_projection_binding_count",
        "hidden_info_violation_count",
        "private_information_violation_count",
        "opponent_private_asset_disclosure_count",
        "actor_id_disclosed",
        "private_queue_disclosed",
        "hidden_order_disclosed",
    }
)
STEP_PROOF_FIELDS = {
    "STEP09": STEP09_PROOF_FIELDS,
    "STEP11": STEP11_PROOF_FIELDS,
    "STEP12": STEP12_PROOF_FIELDS,
}
EXPECTED_CHECK_COUNT_BY_STEP = {
    step_id: len(proof_fields) for step_id, proof_fields in STEP_PROOF_FIELDS.items()
}
TOOLING_SEAL_FIELDS = frozenset(
    {
        "schema_version",
        "status",
        "authorization_id",
        "base_head_sha",
        "base_tree_sha",
        "hard_stop_record_sha256",
        "resume_generation_id",
        "resume_evidence_id",
        "schema_sha256",
        "validator_sha256",
        "workflow_sha256",
        "selftest_sha256",
        "negative_fixture_catalog_sha256",
        "tool_dependency_inventory_sha256",
        "hard_stop_identity_attestation_sha256",
        "evidence_9631_identity_attestation_sha256",
        "frozen_input_inventory_sha256",
        "frozen_input_sidecar_sha256",
        "required_check_context",
        "post_seal_input_mutation_count",
        "canonical_payload_sha256",
    }
)
NEGATIVE_FIXTURE_CATALOG_FIELDS = frozenset(
    {
        "schema_version",
        "status",
        "case_ids",
        "case_count",
        "pass_count",
        "false_green_count",
        "case_id_set_sha256",
        "canonical_payload_sha256",
    }
)
TOOL_DEPENDENCY_INVENTORY_FIELDS = frozenset(
    {
        "schema_version",
        "status",
        "python_dependency_policy",
        "python_external_dependency_count",
        "python_external_dependencies",
        "required_executable_count",
        "required_executables",
        "canonical_payload_sha256",
    }
)
INDEPENDENT_AUDIT_FIELDS = frozenset(
    {
        "schema_version",
        "audit_id",
        "audit_scope",
        "status",
        "p0_count",
        "p1_count",
        "schema_authority_sha256",
        "validator_sha256",
        "workflow_sha256",
        "selftest_sha256",
        "auditor_mode",
        "finding_count",
        "findings",
        "canonical_payload_sha256",
    }
)
HARD_STOP_ATTESTATION_FIELDS = frozenset(
    {
        "schema_version",
        "authorization_id",
        "status",
        "attested_at_utc",
        "authorized_hash_prefix",
        "authorized_hash_suffix",
        "matching_record_count",
        "record",
        "identity_mismatch_count",
        "identity_ambiguous",
    }
)
HARD_STOP_ATTESTATION_RECORD_FIELDS = frozenset(
    {
        "external_path",
        "byte_count",
        "sha256",
        "schema_version",
        "hard_stop_condition",
        "first_failure_class",
        "generation_id",
        "last_consumed_evidence_id",
        "resume_evidence_id",
        "generation_7_started",
        "receipt_schema_code_definition_count",
        "receipt_validator_authority_count",
        "required_workflow_consumer_count",
    }
)
EVIDENCE_9631_ATTESTATION_FIELDS = frozenset(
    {
        "schema_version",
        "authorization_id",
        "status",
        "attested_at_utc",
        "parent_generation_id",
        "resume_evidence_id",
        "identity_kind",
        "reservation_authority_sha256",
        "generation_7_started",
        "last_consumed_evidence_id",
        "preexisting_evidence_9631_file_count",
        "preexisting_evidence_9631_files",
        "reserved_slot_exists",
        "reserved_slot_consumed",
        "overwrite_allowed",
        "evidence_root_logical_path",
        "evidence_root_file_count",
        "evidence_root_inventory_payload",
        "evidence_root_inventory_sha256",
        "first_evidence_file",
        "last_evidence_file",
        "identity_mismatch_count",
    }
)
FROZEN_INPUT_INVENTORY_FIELDS = frozenset(
    {
        "schema_version",
        "authorization_id",
        "status",
        "frozen_at_utc",
        "base_identity",
        "source_worktree_preservation",
        "repair_worktree",
        "frozen_authorities",
        "frozen_external_evidence",
        "frozen_generation7_files",
        "frozen_previous_audits",
        "preservation_assertions",
    }
)
FROZEN_BASE_IDENTITY_FIELDS = frozenset(
    {
        "local_head_sha",
        "local_tree_sha",
        "remote_pr93_head_sha",
        "remote_pr93_tree_sha",
        "remote_pr93_state",
        "remote_pr93_is_draft",
        "current_product_subject_head_sha",
        "current_product_subject_tree_sha",
    }
)
FROZEN_AUTHORITIES_FIELDS = frozenset(
    {
        "hard_stop_record_path",
        "hard_stop_record_sha256",
        "hard_stop_identity_attestation_path",
        "evidence_9631_identity_attestation_path",
        "required_check_context",
        "resume_generation_id",
        "resume_evidence_id",
    }
)
FROZEN_EXTERNAL_EVIDENCE_FIELDS = frozenset(
    {
        "logical_root",
        "file_count",
        "inventory_payload",
        "inventory_sha256",
        "last_consumed_evidence_id",
        "next_reserved_evidence_id",
        "preexisting_9631_file_count",
    }
)
FROZEN_GENERATION7_FILES_FIELDS = frozenset(
    {"preexisting_named_file_count", "preexisting_named_files", "modification_allowed"}
)
FROZEN_PREVIOUS_AUDITS_FIELDS = frozenset(
    {"audit_count", "audit_identity_binding", "modification_allowed"}
)
FROZEN_PRESERVATION_ASSERTIONS_FIELDS = frozenset(
    {
        "frozen_hard_stop_modification_count",
        "frozen_evidence_9631_modification_count",
        "frozen_generation7_file_modification_count",
        "frozen_audit_modification_count",
        "user_dirty_file_mutation_count",
        "user_dirty_file_stage_count",
        "user_dirty_file_delete_count",
    }
)
RESUME_AUTHORIZATION_FIELDS = frozenset(
    {
        "schema_version",
        "status",
        "authorization_id",
        "authorized_base_head",
        "current_tooling_head",
        "current_tooling_tree",
        "hard_stop_record_sha256",
        "resume_generation_id",
        "resume_evidence_id",
        "schema_sha256",
        "validator_sha256",
        "workflow_sha256",
        "tooling_seal_sha256",
        "selftest_sha256",
        "audit_a_sha256",
        "audit_b_sha256",
        "current_product_subject_head",
        "current_product_subject_tree",
        "product_path_manifest_sha256",
        "existing_generation7_evidence_inventory_sha256",
        "resume_start_checkpoint",
        "first_unexecuted_step",
        "formal_resume_count",
        "automatic_retry",
        "canonical_payload_sha256",
    }
)
MCP_LANDING_FIELDS = frozenset(
    {
        "schema_version",
        "generation_id",
        "resume_evidence_id",
        "subject_head_sha",
        "subject_tree_sha",
        "execution_head_sha",
        "execution_tree_sha",
        "mcp_tool_identity",
        "mcp_protocol_version",
        "production_scene_path",
        "real_main_tscn_validation",
        "direct_filesystem_product_edit_count",
        "product_file_change_count",
        "mcp_product_file_mutation_count",
        "mcp_product_file_mutation_coverage_percent",
        "mcp_post_edit_validation_count",
        "mcp_post_edit_validation_coverage_percent",
        "product_file_mutations",
        "canonical_payload_sha256",
    }
)
MCP_LANDING_MUTATION_FIELDS = frozenset(
    {
        "path",
        "change_type",
        "before_sha256",
        "after_sha256",
        "mcp_operation_id",
        "validation_status",
    }
)
GENERATION8_AUTHORIZATION_FIELDS = frozenset(
    {
        "schema_version",
        "status",
        "authorization_id",
        "generation_id",
        "parent_generation_id",
        "parent_generation7_summary_sha256",
        "parent_generation7_summary_derivation",
        "parent_step09_receipt_sha256",
        "parent_step11_blocked_receipt_sha256",
        "parent_step12_receipt_sha256",
        "parent_evidence_id",
        "evidence_registry_index_paths",
        "evidence_registry_index_sha256s",
        "evidence_registry_max_evidence_id",
        "new_evidence_id",
        "evidence_id_derivation",
        "product_subject_head_sha",
        "product_subject_tree_sha",
        "live_pr_head_sha",
        "live_pr_tree_sha",
        "selected_seed",
        "player_count",
        "new_game_profile",
        "major_round_contract_path",
        "major_round_contract_sha256",
        "product_path_manifest_path",
        "product_path_manifest_sha256",
        "mcp_landing_manifest_sha256",
        "receipt_schema_path",
        "receipt_schema_sha256",
        "receipt_validator_path",
        "receipt_validator_sha256",
        "required_workflow_path",
        "required_workflow_sha256",
        "receipt_selftest_path",
        "receipt_selftest_sha256",
        "focused_test_report_path",
        "focused_test_report_sha256",
        "characterization_report_path",
        "characterization_report_sha256",
        "generation8_tooling_seal_path",
        "generation8_tooling_seal_sha256",
        "formal_execution_count",
        "automatic_retry",
        "created_at_utc",
        "canonical_payload_sha256",
    }
)
GENERATION8_TOOLING_SEAL_FIELDS = frozenset(
    {
        "schema_version",
        "status",
        "authorization_id",
        "generation_id",
        "base_head_sha",
        "base_tree_sha",
        "receipt_schema_path",
        "receipt_schema_sha256",
        "receipt_validator_path",
        "receipt_validator_sha256",
        "receipt_selftest_path",
        "receipt_selftest_sha256",
        "required_workflow_path",
        "required_workflow_sha256",
        "negative_fixture_catalog_path",
        "negative_fixture_catalog_sha256",
        "focused_test_report_path",
        "focused_test_report_sha256",
        "characterization_report_path",
        "characterization_report_sha256",
        "major_round_contract_path",
        "major_round_contract_sha256",
        "product_file_change_count",
        "direct_filesystem_product_edit_count",
        "post_seal_input_mutation_count",
        "canonical_payload_sha256",
    }
)
GENERATION8_RUNTIME_EVIDENCE_FIELDS = frozenset(
    {
        "schema_version",
        "step_id",
        "generation_id",
        "resume_evidence_id",
        "authorization_manifest_sha256",
        "subject_head_sha",
        "subject_tree_sha",
        "execution_head_sha",
        "execution_tree_sha",
        "production_scene_path",
        "execution_mode",
        "diagnostic_only",
        "fixture_only",
        "mcp_tool_identity",
        "mcp_protocol_version",
        "mcp_session_id",
        "godot_binary_sha256",
        "project_godot_sha256",
        "main_tscn_sha256",
        "runtime_composition_sha256",
        "production_screen_sha256",
        "session_started_at_utc",
        "session_ended_at_utc",
        "scene_started_via_mcp",
        "mcp_real_runtime_observed",
        "selected_seed",
        "player_count",
        "new_game_profile",
        "mission_kind",
        "target_region_id",
        "asset_authority_witness",
        "military_lifecycle_witness",
        "injection_counters",
        "proof",
        "canonical_payload_sha256",
    }
)
GENERATION8_ASSET_WITNESS_FIELDS = frozenset(
    {
        "schema",
        "reservation_id",
        "owner_player_id",
        "action",
        "outcome",
        "asset_revision_before",
        "asset_revision_after",
        "asset_quantities_before",
        "asset_quantities_after",
        "asset_delta_by_color",
        "reserved_asset_cost_by_color",
        "reservation_receipt_id",
        "reservation_receipt_fingerprint",
        "settlement_receipt_id",
        "settlement_receipt_fingerprint",
        "mission_receipt_fingerprint",
        "asset_debit_count",
        "consequence_bound",
        "projection_count_before",
        "projection_count_after",
        "projection_failure_count",
        "presentation_count",
        "witness_fingerprint",
    }
)
GENERATION8_MILITARY_WITNESS_FIELDS = frozenset(
    {
        "submission_id",
        "command_id",
        "mission_kind",
        "target_region_id",
        "eta_ticks",
        "arrival_tick",
        "submission_count",
        "intake_settlement_count",
        "resolution_count",
        "withdrawal_count",
        "collision_count",
        "public_batch_entry_count",
        "shared_sushi_track_resolution_count",
        "consequence_presentation_count",
        "complete_major_round_barrier_observed",
    }
)
GENERATION8_INJECTION_COUNTER_FIELDS = frozenset(
    {
        "fixture_card_injection_count",
        "fixture_asset_injection_count",
        "fixture_target_injection_count",
        "fixture_action_injection_count",
        "fixture_eta_injection_count",
        "direct_action_internal_method_as_ui_proof_count",
    }
)
GENERATION8_EXECUTION_START_FIELDS = frozenset(
    {
        "schema_version",
        "status",
        "authorization_id",
        "authorization_manifest_sha256",
        "generation_id",
        "parent_generation_id",
        "parent_evidence_id",
        "new_evidence_id",
        "formal_attempt_id",
        "formal_execution_count",
        "automatic_retry_count",
        "execution_head_sha",
        "execution_tree_sha",
        "product_subject_head_sha",
        "product_subject_tree_sha",
        "selected_seed",
        "player_count",
        "new_game_profile",
        "production_scene_path",
        "execution_mode",
        "injection_counters",
        "started_at_utc",
        "canonical_payload_sha256",
    }
)
GENERATION8_PROGRESS_FIELDS = frozenset(
    {
        "schema_version",
        "status",
        "generation_id",
        "new_evidence_id",
        "formal_attempt_id",
        "formal_execution_count",
        "automatic_retry_count",
        "current_step",
        "step11_status",
        "accepted_action_drain_status",
        "process_cleanup_status",
        "started_at_utc",
        "completed_at_utc",
        "canonical_payload_sha256",
    }
)
GENERATION8_SUMMARY_FIELDS = frozenset(
    {
        "schema_version",
        "status",
        "generation_id",
        "parent_generation_id",
        "parent_evidence_id",
        "new_evidence_id",
        "authorization_manifest_sha256",
        "formal_attempt_id",
        "formal_execution_count",
        "automatic_retry_count",
        "step11_receipt_path",
        "step11_receipt_sha256",
        "step11_receipt_status",
        "step11_required_positive_field_count",
        "step11_required_positive_field_pass_count",
        "step11_required_zero_field_count",
        "step11_required_zero_field_pass_count",
        "generation7_step11_receipt_status",
        "generation7_modification_count",
        "generation7_rerun_count",
        "process_cleanup_status",
        "completed_at_utc",
        "canonical_payload_sha256",
    }
)
GENERATION8_SOURCE_EVIDENCE_INDEX_FIELDS = frozenset(
    {
        "schema_version",
        "append_only",
        "generation_id",
        "new_evidence_id",
        "formal_attempt_id",
        "formal_execution_count",
        "automatic_retry_count",
        "source_artifact_count",
        "source_artifacts",
        "canonical_payload_sha256",
    }
)
GENERATION8_SOURCE_EVIDENCE_ARTIFACT_FIELDS = frozenset(
    {"path", "sha256", "size_bytes"}
)
PRODUCT_SUFFIXES = (
    ".gd",
    ".tscn",
    ".tres",
    ".res",
    ".gdshader",
    ".gdshaderinc",
    ".shader",
    ".theme",
)
NON_PRODUCT_PREFIXES = (
    ".github/",
    "docs/",
    "reports/",
    "tests/",
    "tools/",
    "scripts/tools/",
)


def is_product_path(path: str) -> bool:
    lowered = path.lower()
    if lowered == "project.godot":
        return True
    if any(lowered.startswith(prefix) for prefix in NON_PRODUCT_PREFIXES):
        return False
    if lowered.endswith(PRODUCT_SUFFIXES):
        return True
    return lowered.endswith(".json") and (
        lowered.startswith("data/") or lowered.startswith("resources/")
    )


def is_generation8_mcp_mutation_path(path: str) -> bool:
    """Generation 8 binds every changed Godot source, including focused tests."""
    lowered = path.lower()
    return is_product_path(path) or (
        lowered.startswith("tests/") and lowered.endswith(".gd")
    )


class GitCommittedProject:
    def __init__(self, root: Path):
        self.root = root.resolve(strict=True)
        if not (self.root / ".git").exists():
            raise ValueError(f"PROJECT_IS_NOT_GIT_WORKTREE:{self.root}")
        replacements = subprocess.run(
            ["git", "for-each-ref", "--format=%(refname)", "refs/replace/"],
            cwd=self.root,
            env={**os.environ, "GIT_NO_REPLACE_OBJECTS": "1"},
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if replacements.returncode != 0 or replacements.stdout.strip():
            raise ValueError("GIT_REPLACE_REFS_FORBIDDEN")
        for selector in ("--git-dir", "--git-common-dir"):
            git_dir = subprocess.check_output(
                ["git", "rev-parse", selector], cwd=self.root, text=True
            ).strip()
            git_dir_path = Path(git_dir)
            if not git_dir_path.is_absolute():
                git_dir_path = self.root / git_dir_path
            grafts = git_dir_path.resolve() / "info" / "grafts"
            if grafts.exists() and grafts.stat().st_size:
                raise ValueError("GIT_GRAFTS_FORBIDDEN")

    def git(self, *args: str, text: bool = True) -> str | bytes:
        completed = subprocess.run(
            ["git", *args],
            cwd=self.root,
            env={**os.environ, "GIT_NO_REPLACE_OBJECTS": "1"},
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if completed.returncode != 0:
            detail = completed.stderr.decode("utf-8", errors="replace").strip()
            raise ValueError(f"GIT_COMMAND_FAILED:{' '.join(args)}:{detail}")
        if text:
            return completed.stdout.decode("utf-8", errors="strict")
        return completed.stdout

    def resolve_commit(self, ref: str) -> str:
        value = str(self.git("rev-parse", "--verify", f"{ref}^{{commit}}")).strip()
        if not _is_git_sha(value):
            raise ValueError(f"INVALID_RESOLVED_COMMIT:{value}")
        return value

    def tree(self, head: str) -> str:
        value = str(self.git("rev-parse", f"{head}^{{tree}}")).strip()
        if not _is_git_sha(value):
            raise ValueError(f"INVALID_RESOLVED_TREE:{value}")
        return value

    def single_parent(self, head: str) -> str:
        parts = str(self.git("rev-list", "--parents", "-n", "1", head)).split()
        if len(parts) != 2:
            raise ValueError(f"CONSUMER_HEAD_NOT_SINGLE_PARENT:{len(parts) - 1}")
        return parts[1]

    def is_ancestor(self, ancestor: str, descendant: str) -> bool:
        return (
            subprocess.run(
                ["git", "merge-base", "--is-ancestor", ancestor, descendant],
                cwd=self.root,
                env={**os.environ, "GIT_NO_REPLACE_OBJECTS": "1"},
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            ).returncode
            == 0
        )

    def _tree_entry(self, head: str, path: str) -> tuple[str, str, str]:
        normalized = normalize_repo_relative_path(path)
        raw = self.git("ls-tree", "-z", head, "--", normalized, text=False)
        assert isinstance(raw, bytes)
        rows = [row for row in raw.split(b"\0") if row]
        if len(rows) != 1:
            raise CommittedPathError(
                f"COMMITTED_PATH_CARDINALITY:{normalized}:{len(rows)}"
            )
        try:
            metadata, encoded_path = rows[0].split(b"\t", 1)
            mode, object_type, object_id = metadata.decode("ascii").split()
            actual_path = encoded_path.decode("utf-8", errors="strict")
        except (ValueError, UnicodeDecodeError) as exc:
            raise CommittedPathError(f"MALFORMED_TREE_ENTRY:{normalized}") from exc
        if actual_path != normalized:
            raise CommittedPathError(
                f"TREE_ENTRY_PATH_MISMATCH:{normalized}:{actual_path}"
            )
        return mode, object_type, object_id

    def read_regular_file(self, head: str, path: str) -> bytes:
        normalized = normalize_repo_relative_path(path)
        mode, object_type, _object_id = self._tree_entry(head, normalized)
        if mode not in {"100644", "100755"} or object_type != "blob":
            raise CommittedPathError(
                f"COMMITTED_PATH_NOT_REGULAR_FILE:{normalized}:{mode}:{object_type}"
            )
        data = self.git("show", f"{head}:{normalized}", text=False)
        assert isinstance(data, bytes)
        return data

    def regular_file_exists(self, head: str, path: str) -> bool:
        try:
            self.read_regular_file(head, path)
        except (ValueError, CommittedPathError):
            return False
        return True

    def list_paths(self, head: str, prefix: str) -> list[str]:
        normalized = normalize_repo_relative_path(prefix)
        raw = self.git(
            "ls-tree", "-r", "-z", "--name-only", head, "--", normalized, text=False
        )
        assert isinstance(raw, bytes)
        return sorted(
            row.decode("utf-8", errors="strict")
            for row in raw.split(b"\0")
            if row
        )

    def changed_paths(self, parent: str, head: str) -> list[str]:
        raw = self.git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            "-z",
            parent,
            head,
            text=False,
        )
        assert isinstance(raw, bytes)
        return sorted(
            row.decode("utf-8", errors="strict")
            for row in raw.split(b"\0")
            if row
        )

    def changed_entries(self, parent: str, head: str) -> list[tuple[str, str]]:
        raw = self.git(
            "diff-tree",
            "--no-commit-id",
            "--name-status",
            "--no-renames",
            "-r",
            "-z",
            parent,
            head,
            text=False,
        )
        assert isinstance(raw, bytes)
        tokens = [token for token in raw.split(b"\0") if token]
        if len(tokens) % 2:
            raise ValueError("MALFORMED_DIFF_NAME_STATUS")
        entries: list[tuple[str, str]] = []
        for index in range(0, len(tokens), 2):
            status = tokens[index].decode("ascii", errors="strict")
            path = tokens[index + 1].decode("utf-8", errors="strict")
            entries.append((status, path))
        return sorted(entries, key=lambda row: row[1])

    def addition_commits(self, head: str, path: str) -> list[str]:
        normalized = normalize_repo_relative_path(path)
        value = str(
            self.git(
                "log",
                "--format=%H",
                "--diff-filter=A",
                head,
                "--",
                normalized,
            )
        )
        return [line for line in value.splitlines() if line]

    def recursive_blob_entries(
        self, head: str
    ) -> dict[str, tuple[str, str, int]]:
        raw = self.git("ls-tree", "-r", "-z", "-l", head, text=False)
        assert isinstance(raw, bytes)
        result: dict[str, tuple[str, str, int]] = {}
        for row in (item for item in raw.split(b"\0") if item):
            metadata, encoded_path = row.split(b"\t", 1)
            parts = metadata.decode("ascii", errors="strict").split()
            if len(parts) != 4:
                raise ValueError("MALFORMED_RECURSIVE_TREE_ENTRY")
            mode, object_type, object_id, size_text = parts
            if object_type != "blob" or size_text == "-":
                continue
            path = encoded_path.decode("utf-8", errors="strict")
            result[path] = (mode, object_id, int(size_text))
        return result

    def read_blobs(self, object_ids: Iterable[str]) -> dict[str, bytes]:
        ordered = sorted(set(object_ids))
        if not ordered:
            return {}
        completed = subprocess.run(
            ["git", "cat-file", "--batch"],
            cwd=self.root,
            env={**os.environ, "GIT_NO_REPLACE_OBJECTS": "1"},
            input=("".join(f"{object_id}\n" for object_id in ordered)).encode("ascii"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if completed.returncode != 0:
            raise ValueError(
                "GIT_CAT_FILE_BATCH_FAILED:"
                + completed.stderr.decode("utf-8", errors="replace").strip()
            )
        data = completed.stdout
        offset = 0
        result: dict[str, bytes] = {}
        for requested in ordered:
            line_end = data.find(b"\n", offset)
            if line_end < 0:
                raise ValueError("GIT_CAT_FILE_BATCH_HEADER_TRUNCATED")
            header = data[offset:line_end].decode("ascii", errors="strict").split()
            if len(header) != 3 or header[0] != requested or header[1] != "blob":
                raise ValueError(f"GIT_CAT_FILE_BATCH_HEADER_INVALID:{header}")
            size = int(header[2])
            start = line_end + 1
            end = start + size
            if end >= len(data) or data[end : end + 1] != b"\n":
                raise ValueError("GIT_CAT_FILE_BATCH_BODY_TRUNCATED")
            result[requested] = data[start:end]
            offset = end + 1
        if offset != len(data):
            raise ValueError("GIT_CAT_FILE_BATCH_TRAILING_BYTES")
        return result


@dataclass
class ValidationReport:
    validator_status: str = "FAIL"
    failure_codes: list[str] | None = None
    field_mismatches: list[str] | None = None
    identity_mismatches: list[str] | None = None
    hash_mismatches: list[str] | None = None
    path_failures: list[str] | None = None
    schema_failures: list[str] | None = None
    receipt_count: int = 0
    validated_receipt_count: int = 0
    receipt_bindings: list[dict[str, Any]] | None = None
    expected_consumer_head_sha: str | None = None
    artifact_head_sha: str | None = None
    execution_head_sha: str | None = None
    execution_tree_sha: str | None = None
    generation_id: int = AUTHORIZED_GENERATION_ID
    resume_evidence_id: int = AUTHORIZED_RESUME_EVIDENCE_ID
    validation_mode: str = "GENERATION7_LEGACY"
    generation7_step11_receipt_status: str | None = None

    def __post_init__(self) -> None:
        for name in (
            "failure_codes",
            "field_mismatches",
            "identity_mismatches",
            "hash_mismatches",
            "path_failures",
            "schema_failures",
            "receipt_bindings",
        ):
            if getattr(self, name) is None:
                setattr(self, name, [])

    def add(self, category: str, code: str, detail: str) -> None:
        assert self.failure_codes is not None
        target = getattr(self, category)
        assert isinstance(target, list)
        self.failure_codes.append(code)
        target.append(f"{code}:{detail}")

    def finish(self) -> dict[str, Any]:
        assert self.failure_codes is not None
        self.failure_codes = sorted(set(self.failure_codes))
        for name in (
            "field_mismatches",
            "identity_mismatches",
            "hash_mismatches",
            "path_failures",
            "schema_failures",
        ):
            value = getattr(self, name)
            assert isinstance(value, list)
            setattr(self, name, sorted(set(value)))
        self.validator_status = "PASS" if not self.failure_codes else "FAIL"
        payload = {
            "validator_status": self.validator_status,
            "failure_codes": self.failure_codes,
            "field_mismatches": self.field_mismatches,
            "identity_mismatches": self.identity_mismatches,
            "hash_mismatches": self.hash_mismatches,
            "path_failures": self.path_failures,
            "schema_failures": self.schema_failures,
            "receipt_count": self.receipt_count,
            "validated_receipt_count": self.validated_receipt_count,
            "receipt_bindings": self.receipt_bindings,
            "expected_consumer_head_sha": self.expected_consumer_head_sha,
            "artifact_head_sha": self.artifact_head_sha,
            "execution_head_sha": self.execution_head_sha,
            "execution_tree_sha": self.execution_tree_sha,
            "generation_id": self.generation_id,
            "resume_evidence_id": self.resume_evidence_id,
            "validation_mode": self.validation_mode,
            "generation7_step11_receipt_status": (
                self.generation7_step11_receipt_status
            ),
            "required_check_context": REQUIRED_CHECK_CONTEXT,
            "required_gate_consumer_fail_closed": True,
        }
        payload["report_sha256"] = sha256_bytes(canonical_json_bytes(payload))
        return payload


def _compare_exact_keys(
    report: ValidationReport,
    category: str,
    code: str,
    label: str,
    value: Any,
    expected: frozenset[str],
) -> bool:
    if not isinstance(value, dict):
        report.add(category, code, f"{label}:NOT_OBJECT")
        return False
    actual = frozenset(value)
    if actual != expected:
        report.add(
            category,
            code,
            f"{label}:missing={sorted(expected - actual)}:extra={sorted(actual - expected)}",
        )
        return False
    return True


def _validate_receipt_schema(
    report: ValidationReport,
    value: Any,
    label: str,
    *,
    expected_authorization_id: str = AUTHORIZATION_ID,
    expected_generation_id: int = AUTHORIZED_GENERATION_ID,
    expected_evidence_id: int = AUTHORIZED_RESUME_EVIDENCE_ID,
    expected_subject_head_sha: str = CURRENT_SUBJECT_HEAD_SHA,
    expected_subject_tree_sha: str = CURRENT_SUBJECT_TREE_SHA,
    expected_product_manifest_path: str = CURRENT_SUBJECT_MANIFEST_PATH,
    expected_product_manifest_sha256: str = CURRENT_SUBJECT_MANIFEST_SHA256,
    expected_tooling_seal_path: str = TOOLING_SEAL_PATH,
    expected_authorization_manifest_path: str = RESUME_AUTHORIZATION_MANIFEST_PATH,
    expected_proof_fields: frozenset[str] | None = None,
) -> V076CurrentSubjectProductionRevalidationReceiptV1 | None:
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "RECEIPT_SCHEMA_FIELD_SET_MISMATCH",
        label,
        value,
        RECEIPT_FIELDS,
    ):
        return None
    assert isinstance(value, dict)

    def field_failure(field: str, detail: str) -> None:
        report.add(
            "schema_failures", "RECEIPT_FIELD_INVALID", f"{label}.{field}:{detail}"
        )

    exact_strings = {
        "schema_version": SCHEMA_VERSION,
        "receipt_kind": RECEIPT_KIND,
        "authorization_id": expected_authorization_id,
        "required_check_context": REQUIRED_CHECK_CONTEXT,
        "schema_authority_path": SCHEMA_AUTHORITY_PATH,
        "validator_path": VALIDATOR_PATH,
        "producer_script_path": PRODUCER_SCRIPT_PATH,
        "workflow_path": WORKFLOW_PATH,
        "product_path_manifest_path": expected_product_manifest_path,
        "product_path_manifest_sha256": expected_product_manifest_sha256,
        "tooling_seal_path": expected_tooling_seal_path,
        "resume_authorization_manifest_path": expected_authorization_manifest_path,
        "hard_stop_record_sha256": AUTHORIZED_HARD_STOP_SHA256,
        "existing_generation7_evidence_inventory_sha256": (
            FROZEN_EVIDENCE_INVENTORY_SHA256
        ),
        "subject_head_sha": expected_subject_head_sha,
        "subject_tree_sha": expected_subject_tree_sha,
    }
    for field, expected in exact_strings.items():
        if value.get(field) != expected:
            field_failure(field, f"EXPECTED:{expected}:ACTUAL:{value.get(field)!r}")

    if value.get("generation_id") != expected_generation_id or not _is_exact_int(
        value.get("generation_id")
    ):
        field_failure("generation_id", f"MUST_BE_INTEGER_{expected_generation_id}")
    if value.get("resume_evidence_id") != expected_evidence_id or not _is_exact_int(
        value.get("resume_evidence_id")
    ):
        field_failure("resume_evidence_id", f"MUST_BE_INTEGER_{expected_evidence_id}")

    step_id = value.get("step_id")
    if step_id not in REQUIRED_RECEIPT_PATH_BY_STEP:
        field_failure("step_id", "NOT_AUTHORIZED")
    receipt_id = value.get("receipt_id")
    if not isinstance(receipt_id, str) or RECEIPT_ID_RE.fullmatch(receipt_id) is None:
        field_failure("receipt_id", "INVALID_FORMAT")

    for field in (
        "live_pr_head_sha",
        "live_pr_tree_sha",
        "producer_tooling_head_sha",
        "producer_tooling_tree_sha",
    ):
        if not _is_git_sha(value.get(field)):
            field_failure(field, "INVALID_GIT_SHA")
    for field in (
        "producer_script_sha256",
        "schema_authority_sha256",
        "validator_sha256",
        "workflow_sha256",
        "product_path_manifest_sha256",
        "tooling_seal_sha256",
        "resume_authorization_manifest_sha256",
        "evidence_manifest_sha256",
        "result_fingerprint_sha256",
        "canonical_payload_sha256",
    ):
        if not _is_sha256(value.get(field)):
            field_failure(field, "INVALID_SHA256")

    for field in (
        "evidence_manifest_path",
        "mcp_landing_manifest_path",
        "mcp_runtime_evidence_path",
    ):
        path_value = value.get(field)
        if path_value is None and field != "evidence_manifest_path":
            continue
        try:
            normalize_repo_relative_path(path_value)
        except ValueError as exc:
            field_failure(field, str(exc))

    for field in ("contains_godot_product_delta", "requires_mcp_runtime_evidence"):
        if not _is_exact_bool(value.get(field)):
            field_failure(field, "MUST_BE_BOOLEAN")
    contains_delta = value.get("contains_godot_product_delta") is True
    requires_runtime = value.get("requires_mcp_runtime_evidence") is True
    if not requires_runtime:
        field_failure(
            "requires_mcp_runtime_evidence",
            "CURRENT_SUBJECT_STEP_REQUIRES_REAL_MCP_RUNTIME",
        )
    if contains_delta and not requires_runtime:
        field_failure(
            "requires_mcp_runtime_evidence", "PRODUCT_DELTA_REQUIRES_RUNTIME_EVIDENCE"
        )
    landing_pair = (
        value.get("mcp_landing_manifest_path"),
        value.get("mcp_landing_manifest_sha256"),
    )
    runtime_pair = (
        value.get("mcp_runtime_evidence_path"),
        value.get("mcp_runtime_evidence_sha256"),
    )
    if contains_delta:
        if not isinstance(landing_pair[0], str) or not _is_sha256(landing_pair[1]):
            field_failure("mcp_landing_manifest_path", "PRODUCT_DELTA_REQUIRES_MCP_LANDING")
    elif landing_pair != (None, None):
        field_failure("mcp_landing_manifest_path", "TOOLING_OR_RUNTIME_ONLY_MUST_BE_NULL")
    if requires_runtime:
        if not isinstance(runtime_pair[0], str) or not _is_sha256(runtime_pair[1]):
            field_failure("mcp_runtime_evidence_path", "RUNTIME_EVIDENCE_REQUIRED")
    elif runtime_pair != (None, None):
        field_failure("mcp_runtime_evidence_path", "RUNTIME_EVIDENCE_NOT_DECLARED_MUST_BE_NULL")

    status = value.get("status")
    if status not in {"PASS", "FAIL", "BLOCKED"}:
        field_failure("status", "UNSUPPORTED_STATUS")
    for field in ("check_count", "pass_count", "failure_count"):
        if not _is_exact_int(value.get(field)) or value[field] < 0:
            field_failure(field, "MUST_BE_NONNEGATIVE_INTEGER")
    codes = value.get("failure_codes")
    if not isinstance(codes, list):
        field_failure("failure_codes", "MUST_BE_ARRAY")
    elif any(
        not isinstance(code, str) or FAILURE_CODE_RE.fullmatch(code) is None
        for code in codes
    ):
        field_failure("failure_codes", "INVALID_FAILURE_CODE")
    elif len(set(codes)) != len(codes):
        field_failure("failure_codes", "DUPLICATE_FAILURE_CODE")
    if all(_is_exact_int(value.get(name)) for name in ("check_count", "pass_count", "failure_count")):
        check_count = value["check_count"]
        pass_count = value["pass_count"]
        failure_count = value["failure_count"]
        if check_count <= 0:
            field_failure("check_count", "MUST_BE_POSITIVE")
        expected_check_count = (
            len(expected_proof_fields)
            if expected_proof_fields is not None
            else EXPECTED_CHECK_COUNT_BY_STEP.get(step_id)
        )
        if expected_check_count is not None and check_count != expected_check_count:
            field_failure(
                "check_count", f"STEP_EXACT_COUNT:{expected_check_count}"
            )
        if pass_count + failure_count != check_count:
            field_failure("check_count", "PASS_PLUS_FAILURE_MUST_EQUAL_CHECK_COUNT")
        if isinstance(codes, list) and len(codes) != failure_count:
            field_failure("failure_codes", "LENGTH_MUST_EQUAL_FAILURE_COUNT")
        if status == "PASS" and (
            failure_count != 0 or codes != [] or pass_count != check_count
        ):
            field_failure("status", "PASS_COUNTER_CONTRADICTION")
        if status in {"FAIL", "BLOCKED"} and failure_count <= 0:
            field_failure("status", "NONPASS_REQUIRES_FAILURE")

    created = value.get("created_at_utc")
    try:
        parse_rfc3339_utc(created)
    except ValueError:
        field_failure("created_at_utc", "INVALID_RFC3339_UTC")
    previous = value.get("previous_receipt_sha256")
    if previous is not None and not _is_sha256(previous):
        field_failure("previous_receipt_sha256", "MUST_BE_NULL_OR_SHA256")
    if not isinstance(value.get("extensions"), dict):
        field_failure("extensions", "MUST_BE_OBJECT")

    cleanup = value.get("process_cleanup")
    if _compare_exact_keys(
        report,
        "schema_failures",
        "PROCESS_CLEANUP_FIELD_SET_MISMATCH",
        f"{label}.process_cleanup",
        cleanup,
        PROCESS_CLEANUP_FIELDS,
    ):
        assert isinstance(cleanup, dict)
        for field in ("exit_play_mode", "stop_role_godot_mcp"):
            if cleanup.get(field) not in {"PASS", "NOT_STARTED"}:
                field_failure(f"process_cleanup.{field}", "INVALID_STATUS")
        for field in ("editor_pid_after", "game_pid_after", "listener_count_after"):
            if not _is_exact_int(cleanup.get(field)) or cleanup[field] < 0:
                field_failure(f"process_cleanup.{field}", "MUST_BE_NONNEGATIVE_INTEGER")
        if status == "PASS" and cleanup != {
            "exit_play_mode": "PASS",
            "stop_role_godot_mcp": "PASS",
            "editor_pid_after": 0,
            "game_pid_after": 0,
            "listener_count_after": 0,
        }:
            field_failure("process_cleanup", "PASS_REQUIRES_CLEAN_STOP")

    expected_payload_hash = canonical_payload_sha256(value)
    if value.get("canonical_payload_sha256") != expected_payload_hash:
        report.add(
            "hash_mismatches",
            "CANONICAL_PAYLOAD_SHA256_MISMATCH",
            f"{label}:expected={expected_payload_hash}:actual={value.get('canonical_payload_sha256')}",
        )
    expected_result_hash = result_fingerprint_sha256(value)
    if value.get("result_fingerprint_sha256") != expected_result_hash:
        report.add(
            "hash_mismatches",
            "RESULT_FINGERPRINT_SHA256_MISMATCH",
            f"{label}:expected={expected_result_hash}:actual={value.get('result_fingerprint_sha256')}",
        )

    if any(item.startswith(f"RECEIPT_FIELD_INVALID:{label}.") for item in report.schema_failures or []):
        return None
    try:
        return V076CurrentSubjectProductionRevalidationReceiptV1.from_mapping(value)
    except (KeyError, TypeError) as exc:
        report.add(
            "schema_failures", "RECEIPT_TYPED_INSTANTIATION_FAILED", f"{label}:{exc}"
        )
        return None


def _load_committed_json(
    project: GitCommittedProject,
    head: str,
    path: str,
    report: ValidationReport,
    label: str,
    require_canonical_bytes: bool = False,
) -> tuple[Any | None, bytes | None]:
    try:
        data = project.read_regular_file(head, path)
    except (ValueError, CommittedPathError) as exc:
        report.add("path_failures", "COMMITTED_FILE_UNAVAILABLE", f"{label}:{exc}")
        return None, None
    try:
        value = load_json_strict_bytes(data)
    except StrictJsonError as exc:
        report.add("schema_failures", "STRICT_JSON_REJECTED", f"{label}:{exc}")
        return None, data
    if require_canonical_bytes:
        try:
            expected = canonical_json_bytes(value)
        except (TypeError, ValueError) as exc:
            report.add(
                "schema_failures", "CANONICAL_JSON_REJECTED", f"{label}:{exc}"
            )
            return None, data
        if data != expected:
            report.add(
                "schema_failures", "RAW_BYTES_NOT_CANONICAL_JSON", label
            )
    return value, data


def _validate_supporting_binding(
    project: GitCommittedProject,
    head: str,
    path: str,
    claimed_sha: str,
    report: ValidationReport,
    label: str,
) -> bytes | None:
    try:
        data = project.read_regular_file(head, path)
    except (ValueError, CommittedPathError) as exc:
        report.add("path_failures", "BOUND_FILE_UNAVAILABLE", f"{label}:{exc}")
        return None
    actual = sha256_bytes(data)
    if actual != claimed_sha:
        report.add(
            "hash_mismatches",
            "BOUND_FILE_SHA256_MISMATCH",
            f"{label}:path={path}:expected={claimed_sha}:actual={actual}",
        )
        return None
    return data


def _validate_evidence_manifest(
    project: GitCommittedProject,
    head: str,
    receipt: V076CurrentSubjectProductionRevalidationReceiptV1,
    report: ValidationReport,
) -> set[str]:
    allowlist: set[str] = {receipt.evidence_manifest_path}
    manifest, raw = _load_committed_json(
        project,
        head,
        receipt.evidence_manifest_path,
        report,
        f"{receipt.step_id}.evidence_manifest",
        require_canonical_bytes=True,
    )
    if raw is None:
        return allowlist
    actual_sha = sha256_bytes(raw)
    if actual_sha != receipt.evidence_manifest_sha256:
        report.add(
            "hash_mismatches",
            "EVIDENCE_MANIFEST_SHA256_MISMATCH",
            f"{receipt.step_id}:expected={receipt.evidence_manifest_sha256}:actual={actual_sha}",
        )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "EVIDENCE_MANIFEST_FIELD_SET_MISMATCH",
        f"{receipt.step_id}.evidence_manifest",
        manifest,
        EVIDENCE_MANIFEST_FIELDS,
    ):
        return allowlist
    assert isinstance(manifest, dict)
    exact_values = {
        "schema_version": EVIDENCE_MANIFEST_SCHEMA_VERSION,
        "generation_id": AUTHORIZED_GENERATION_ID,
        "resume_evidence_id": AUTHORIZED_RESUME_EVIDENCE_ID,
        "receipt_id": receipt.receipt_id,
    }
    for field, expected in exact_values.items():
        if manifest.get(field) != expected or (
            field in {"generation_id", "resume_evidence_id"}
            and not _is_exact_int(manifest.get(field))
        ):
            report.add(
                "identity_mismatches",
                "EVIDENCE_MANIFEST_IDENTITY_MISMATCH",
                f"{receipt.step_id}.{field}:expected={expected}:actual={manifest.get(field)!r}",
            )
    if not isinstance(manifest.get("manifest_id"), str) or not manifest["manifest_id"]:
        report.add(
            "schema_failures",
            "EVIDENCE_MANIFEST_ID_INVALID",
            receipt.step_id,
        )
    try:
        evidence_root = normalize_repo_relative_path(manifest.get("evidence_root"))
    except ValueError as exc:
        report.add(
            "path_failures", "EVIDENCE_ROOT_PATH_INVALID", f"{receipt.step_id}:{exc}"
        )
        evidence_root = ""
    expected_evidence_root = (
        f"{RECEIPT_ROOT}/evidence/{receipt.step_id.lower()}"
    )
    if evidence_root != expected_evidence_root:
        report.add(
            "path_failures",
            "EVIDENCE_ROOT_NOT_AUTHORIZED_FOR_STEP",
            f"{receipt.step_id}:expected={expected_evidence_root}:actual={evidence_root}",
        )
    expected_manifest_path = (
        f"{RECEIPT_ROOT}/{receipt.step_id.lower()}_evidence_manifest.json"
    )
    if receipt.evidence_manifest_path != expected_manifest_path:
        report.add(
            "path_failures",
            "EVIDENCE_MANIFEST_PATH_NOT_AUTHORIZED_FOR_STEP",
            f"{receipt.step_id}:expected={expected_manifest_path}:actual={receipt.evidence_manifest_path}",
        )
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list):
        report.add(
            "schema_failures", "EVIDENCE_ARTIFACTS_NOT_ARRAY", receipt.step_id
        )
        artifacts = []
    if not _is_exact_int(manifest.get("artifact_count")) or manifest.get(
        "artifact_count"
    ) != len(artifacts):
        report.add(
            "field_mismatches",
            "EVIDENCE_ARTIFACT_COUNT_MISMATCH",
            f"{receipt.step_id}:declared={manifest.get('artifact_count')}:actual={len(artifacts)}",
        )
    if len(artifacts) == 0:
        report.add(
            "schema_failures", "EVIDENCE_ARTIFACT_SET_EMPTY", receipt.step_id
        )
    paths: list[str] = []
    for index, artifact in enumerate(artifacts):
        label = f"{receipt.step_id}.artifacts[{index}]"
        if not _compare_exact_keys(
            report,
            "schema_failures",
            "EVIDENCE_ARTIFACT_FIELD_SET_MISMATCH",
            label,
            artifact,
            EVIDENCE_ARTIFACT_FIELDS,
        ):
            continue
        assert isinstance(artifact, dict)
        try:
            path = normalize_repo_relative_path(artifact.get("path"))
        except ValueError as exc:
            report.add("path_failures", "EVIDENCE_PATH_INVALID", f"{label}:{exc}")
            continue
        if not evidence_root or not path.startswith(evidence_root + "/"):
            report.add(
                "path_failures",
                "EVIDENCE_PATH_OUTSIDE_DECLARED_ROOT",
                f"{label}:root={evidence_root}:path={path}",
            )
            continue
        if not _is_sha256(artifact.get("sha256")):
            report.add("schema_failures", "EVIDENCE_SHA256_INVALID", label)
            continue
        if not _is_exact_int(artifact.get("size_bytes")) or artifact["size_bytes"] < 0:
            report.add("schema_failures", "EVIDENCE_SIZE_INVALID", label)
            continue
        paths.append(path)
        allowlist.add(path)
        try:
            data = project.read_regular_file(head, path)
        except (ValueError, CommittedPathError) as exc:
            report.add("path_failures", "EVIDENCE_FILE_UNAVAILABLE", f"{label}:{exc}")
            continue
        actual_sha = sha256_bytes(data)
        if actual_sha != artifact["sha256"]:
            report.add(
                "hash_mismatches",
                "EVIDENCE_FILE_SHA256_MISMATCH",
                f"{label}:expected={artifact['sha256']}:actual={actual_sha}",
            )
        if len(data) != artifact["size_bytes"]:
            report.add(
                "field_mismatches",
                "EVIDENCE_FILE_SIZE_MISMATCH",
                f"{label}:expected={artifact['size_bytes']}:actual={len(data)}",
            )
    if paths != sorted(paths) or len(paths) != len(set(paths)):
        report.add(
            "schema_failures",
            "EVIDENCE_PATH_SET_NOT_SORTED_UNIQUE",
            receipt.step_id,
        )
    claimed_manifest_payload = manifest.get("canonical_payload_sha256")
    if not _is_sha256(claimed_manifest_payload) or claimed_manifest_payload != canonical_payload_sha256(manifest):
        report.add(
            "hash_mismatches",
            "EVIDENCE_MANIFEST_CANONICAL_SHA256_MISMATCH",
            receipt.step_id,
        )
    return allowlist


def _validate_mcp_landing(
    project: GitCommittedProject,
    head: str,
    receipt: V076CurrentSubjectProductionRevalidationReceiptV1,
    evidence_allowlist: set[str],
    report: ValidationReport,
) -> set[str]:
    if not receipt.contains_godot_product_delta:
        return set()
    assert receipt.mcp_landing_manifest_path is not None
    assert receipt.mcp_landing_manifest_sha256 is not None
    if receipt.mcp_landing_manifest_path not in evidence_allowlist:
        report.add(
            "path_failures",
            "MCP_LANDING_NOT_IN_EVIDENCE_MANIFEST",
            receipt.step_id,
        )
    landing, data = _load_committed_json(
        project,
        head,
        receipt.mcp_landing_manifest_path,
        report,
        f"{receipt.step_id}.mcp_landing_manifest",
        require_canonical_bytes=True,
    )
    if data is None:
        return set()
    if sha256_bytes(data) != receipt.mcp_landing_manifest_sha256:
        report.add(
            "hash_mismatches", "MCP_LANDING_SHA256_MISMATCH", receipt.step_id
        )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "MCP_LANDING_FIELD_SET_MISMATCH",
        f"{receipt.step_id}.mcp_landing_manifest",
        landing,
        MCP_LANDING_FIELDS,
    ):
        return set()
    assert isinstance(landing, dict)
    expected = {
        "schema_version": "space_syndicate.v076.mcp_product_landing_attestation.v1",
        "generation_id": AUTHORIZED_GENERATION_ID,
        "resume_evidence_id": AUTHORIZED_RESUME_EVIDENCE_ID,
        "subject_head_sha": receipt.subject_head_sha,
        "subject_tree_sha": receipt.subject_tree_sha,
        "execution_head_sha": receipt.live_pr_head_sha,
        "execution_tree_sha": receipt.live_pr_tree_sha,
        "mcp_tool_identity": REQUIRED_MCP_TOOL_IDENTITY,
        "mcp_protocol_version": REQUIRED_MCP_PROTOCOL_VERSION,
        "production_scene_path": "res://scenes/main.tscn",
        "real_main_tscn_validation": "PASS_RUNTIME_OBSERVED",
        "direct_filesystem_product_edit_count": 0,
        "mcp_product_file_mutation_coverage_percent": 100,
        "mcp_post_edit_validation_coverage_percent": 100,
    }
    for field, expected_value in expected.items():
        if landing.get(field) != expected_value or (
            field
            in {
                "generation_id",
                "resume_evidence_id",
                "direct_filesystem_product_edit_count",
                "mcp_product_file_mutation_coverage_percent",
                "mcp_post_edit_validation_coverage_percent",
            }
            and not _is_exact_int(landing.get(field))
        ):
            report.add(
                "identity_mismatches",
                "MCP_LANDING_IDENTITY_MISMATCH",
                f"{field}:expected={expected_value!r}:actual={landing.get(field)!r}",
            )
    mutations = landing.get("product_file_mutations")
    if not isinstance(mutations, list):
        report.add(
            "schema_failures", "MCP_LANDING_MUTATIONS_NOT_ARRAY", receipt.step_id
        )
        return set()
    for field in (
        "product_file_change_count",
        "mcp_product_file_mutation_count",
        "mcp_post_edit_validation_count",
    ):
        if not _is_exact_int(landing.get(field)) or landing[field] != len(mutations):
            report.add(
                "field_mismatches",
                "MCP_LANDING_COUNT_MISMATCH",
                f"{field}:{landing.get(field)!r}:{len(mutations)}",
            )
    if len(mutations) == 0:
        report.add(
            "field_mismatches", "MCP_LANDING_EMPTY_PRODUCT_DELTA", receipt.step_id
        )
    changed_status = {
        path: status
        for status, path in project.changed_entries(
            receipt.subject_head_sha, receipt.live_pr_head_sha
        )
        if is_product_path(path)
    }
    mutation_paths: list[str] = []
    for index, mutation in enumerate(mutations):
        label = f"{receipt.step_id}.product_file_mutations[{index}]"
        if not _compare_exact_keys(
            report,
            "schema_failures",
            "MCP_LANDING_MUTATION_FIELD_SET_MISMATCH",
            label,
            mutation,
            MCP_LANDING_MUTATION_FIELDS,
        ):
            continue
        assert isinstance(mutation, dict)
        try:
            path = normalize_repo_relative_path(mutation.get("path"))
        except ValueError as exc:
            report.add("path_failures", "MCP_LANDING_PRODUCT_PATH_INVALID", f"{label}:{exc}")
            continue
        if not is_product_path(path):
            report.add("path_failures", "MCP_LANDING_NONPRODUCT_PATH", path)
            continue
        mutation_paths.append(path)
        change_type = mutation.get("change_type")
        if change_type not in {"A", "M", "D"} or changed_status.get(path) != change_type:
            report.add(
                "identity_mismatches",
                "MCP_LANDING_CHANGE_TYPE_MISMATCH",
                f"{path}:declared={change_type}:actual={changed_status.get(path)}",
            )
        before = mutation.get("before_sha256")
        after = mutation.get("after_sha256")
        if change_type == "A":
            if before is not None or not _is_sha256(after):
                report.add("schema_failures", "MCP_LANDING_ADD_HASH_INVALID", path)
        elif change_type == "D":
            if not _is_sha256(before) or after is not None:
                report.add("schema_failures", "MCP_LANDING_DELETE_HASH_INVALID", path)
        elif not _is_sha256(before) or not _is_sha256(after):
            report.add("schema_failures", "MCP_LANDING_MODIFY_HASH_INVALID", path)
        if change_type in {"M", "D"} and _is_sha256(before):
            try:
                if sha256_bytes(project.read_regular_file(receipt.subject_head_sha, path)) != before:
                    report.add("hash_mismatches", "MCP_LANDING_BEFORE_HASH_MISMATCH", path)
            except (ValueError, CommittedPathError) as exc:
                report.add("path_failures", "MCP_LANDING_BEFORE_FILE_UNAVAILABLE", f"{path}:{exc}")
        if change_type in {"A", "M"} and _is_sha256(after):
            try:
                if sha256_bytes(project.read_regular_file(receipt.live_pr_head_sha, path)) != after:
                    report.add("hash_mismatches", "MCP_LANDING_AFTER_HASH_MISMATCH", path)
            except (ValueError, CommittedPathError) as exc:
                report.add("path_failures", "MCP_LANDING_AFTER_FILE_UNAVAILABLE", f"{path}:{exc}")
        if not isinstance(mutation.get("mcp_operation_id"), str) or not mutation[
            "mcp_operation_id"
        ].strip():
            report.add("schema_failures", "MCP_LANDING_OPERATION_ID_MISSING", path)
        if mutation.get("validation_status") != "PASS":
            report.add("field_mismatches", "MCP_LANDING_VALIDATION_NOT_PASS", path)
    if mutation_paths != sorted(mutation_paths) or len(mutation_paths) != len(set(mutation_paths)):
        report.add(
            "schema_failures", "MCP_LANDING_PATH_SET_NOT_SORTED_UNIQUE", receipt.step_id
        )
    if mutation_paths != sorted(changed_status):
        report.add(
            "identity_mismatches",
            "MCP_LANDING_PRODUCT_DELTA_MISMATCH",
            f"declared={mutation_paths}:actual={sorted(changed_status)}",
        )
    if landing.get("canonical_payload_sha256") != canonical_payload_sha256(landing):
        report.add("hash_mismatches", "MCP_LANDING_CANONICAL_SHA256_MISMATCH", receipt.step_id)
    return set(mutation_paths)


def _validate_runtime_evidence(
    project: GitCommittedProject,
    head: str,
    receipt: V076CurrentSubjectProductionRevalidationReceiptV1,
    runtime_binding_sha256: Mapping[str, str],
    evidence_allowlist: set[str],
    report: ValidationReport,
) -> None:
    if receipt.mcp_runtime_evidence_path is None or receipt.mcp_runtime_evidence_sha256 is None:
        report.add(
            "schema_failures", "MCP_RUNTIME_EVIDENCE_REQUIRED", receipt.step_id
        )
        return
    if receipt.mcp_runtime_evidence_path not in evidence_allowlist:
        report.add(
            "path_failures",
            "MCP_RUNTIME_EVIDENCE_NOT_IN_EVIDENCE_MANIFEST",
            receipt.step_id,
        )
    runtime, raw = _load_committed_json(
        project,
        head,
        receipt.mcp_runtime_evidence_path,
        report,
        f"{receipt.step_id}.mcp_runtime_evidence",
        require_canonical_bytes=True,
    )
    if raw is None:
        return
    actual_sha = sha256_bytes(raw)
    if actual_sha != receipt.mcp_runtime_evidence_sha256:
        report.add(
            "hash_mismatches",
            "MCP_RUNTIME_EVIDENCE_SHA256_MISMATCH",
            f"{receipt.step_id}:expected={receipt.mcp_runtime_evidence_sha256}:actual={actual_sha}",
        )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "MCP_RUNTIME_EVIDENCE_FIELD_SET_MISMATCH",
        f"{receipt.step_id}.mcp_runtime_evidence",
        runtime,
        RUNTIME_EVIDENCE_FIELDS,
    ):
        return
    assert isinstance(runtime, dict)
    expected_values = {
        "schema_version": RUNTIME_EVIDENCE_SCHEMA_VERSION,
        "step_id": receipt.step_id,
        "generation_id": AUTHORIZED_GENERATION_ID,
        "resume_evidence_id": AUTHORIZED_RESUME_EVIDENCE_ID,
        "subject_head_sha": receipt.subject_head_sha,
        "subject_tree_sha": receipt.subject_tree_sha,
        "execution_head_sha": receipt.live_pr_head_sha,
        "execution_tree_sha": receipt.live_pr_tree_sha,
        "production_scene_path": "res://scenes/main.tscn",
        "execution_mode": "PRODUCTION_COMPOSITION",
        "diagnostic_only": False,
        "fixture_only": False,
        "scene_started_via_mcp": True,
        "mcp_real_runtime_observed": True,
    }
    for field, expected in expected_values.items():
        if runtime.get(field) != expected or (
            field in {"generation_id", "resume_evidence_id"}
            and not _is_exact_int(runtime.get(field))
        ) or (
            field
            in {
                "diagnostic_only",
                "fixture_only",
                "scene_started_via_mcp",
                "mcp_real_runtime_observed",
            }
            and not _is_exact_bool(runtime.get(field))
        ):
            report.add(
                "identity_mismatches",
                "MCP_RUNTIME_IDENTITY_MISMATCH",
                f"{receipt.step_id}.{field}:expected={expected!r}:actual={runtime.get(field)!r}",
            )
    for field in ("mcp_tool_identity", "mcp_protocol_version", "mcp_session_id"):
        if not isinstance(runtime.get(field), str) or not runtime[field].strip():
            report.add(
                "schema_failures",
                "MCP_RUNTIME_SESSION_IDENTITY_MISSING",
                f"{receipt.step_id}.{field}",
            )
    if runtime.get("mcp_tool_identity") != REQUIRED_MCP_TOOL_IDENTITY:
        report.add(
            "identity_mismatches",
            "MCP_TOOL_IDENTITY_MISMATCH",
            f"{receipt.step_id}:{runtime.get('mcp_tool_identity')!r}",
        )
    if runtime.get("mcp_protocol_version") != REQUIRED_MCP_PROTOCOL_VERSION:
        report.add(
            "identity_mismatches",
            "MCP_PROTOCOL_VERSION_MISMATCH",
            f"{receipt.step_id}:{runtime.get('mcp_protocol_version')!r}",
        )
    if runtime.get("godot_binary_sha256") != REQUIRED_GODOT_BINARY_SHA256:
        report.add(
            "hash_mismatches",
            "GODOT_BINARY_SHA256_MISMATCH",
            f"{receipt.step_id}:{runtime.get('godot_binary_sha256')!r}",
        )
    for field in (
        "godot_binary_sha256",
        "project_godot_sha256",
        "main_tscn_sha256",
        "runtime_composition_sha256",
        "production_screen_sha256",
        "canonical_payload_sha256",
    ):
        if not _is_sha256(runtime.get(field)):
            report.add(
                "schema_failures",
                "MCP_RUNTIME_SHA256_INVALID",
                f"{receipt.step_id}.{field}",
            )
    expected_runtime_hashes = {
        "project_godot_sha256": runtime_binding_sha256.get("project.godot"),
        "main_tscn_sha256": runtime_binding_sha256.get("scenes/main.tscn"),
        "runtime_composition_sha256": runtime_binding_sha256.get(
            "scenes/runtime/V075RuntimeComposition.tscn"
        ),
        "production_screen_sha256": runtime_binding_sha256.get(
            "scenes/ui/v075/V075SampleGameScreen.tscn"
        ),
    }
    for field, expected in expected_runtime_hashes.items():
        if expected is None or runtime.get(field) != expected:
            report.add(
                "hash_mismatches",
                "MCP_RUNTIME_PRODUCT_BINDING_MISMATCH",
                f"{receipt.step_id}.{field}:expected={expected}:actual={runtime.get(field)!r}",
            )
    parsed_times: dict[str, datetime] = {}
    for field in ("session_started_at_utc", "session_ended_at_utc"):
        try:
            parsed_times[field] = parse_rfc3339_utc(runtime.get(field))
        except ValueError:
            report.add(
                "schema_failures",
                "MCP_RUNTIME_TIMESTAMP_INVALID",
                f"{receipt.step_id}.{field}",
            )
    if (
        "session_started_at_utc" in parsed_times
        and "session_ended_at_utc" in parsed_times
        and parsed_times["session_started_at_utc"]
        >= parsed_times["session_ended_at_utc"]
    ):
        report.add(
            "identity_mismatches",
            "MCP_RUNTIME_SESSION_ORDER_INVALID",
            receipt.step_id,
        )
    try:
        receipt_created = parse_rfc3339_utc(receipt.created_at_utc)
    except ValueError:
        receipt_created = None
    if (
        receipt_created is not None
        and "session_ended_at_utc" in parsed_times
        and parsed_times["session_ended_at_utc"] > receipt_created
    ):
        report.add(
            "identity_mismatches",
            "RECEIPT_CREATED_BEFORE_RUNTIME_END",
            receipt.step_id,
        )
    if runtime.get("canonical_payload_sha256") != canonical_payload_sha256(runtime):
        report.add(
            "hash_mismatches",
            "MCP_RUNTIME_CANONICAL_SHA256_MISMATCH",
            receipt.step_id,
        )

    proof = runtime.get("proof")
    expected_fields = STEP_PROOF_FIELDS.get(receipt.step_id, frozenset())
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "STEP_PROOF_FIELD_SET_MISMATCH",
        f"{receipt.step_id}.proof",
        proof,
        expected_fields,
    ):
        return
    assert isinstance(proof, dict)

    def require_positive(field: str) -> None:
        if not _is_exact_int(proof.get(field)) or proof[field] < 1:
            report.add(
                "field_mismatches",
                "STEP_PROOF_POSITIVE_COUNT_MISSING",
                f"{receipt.step_id}.{field}:{proof.get(field)!r}",
            )

    def require_zero(field: str) -> None:
        if not _is_exact_int(proof.get(field)) or proof[field] != 0:
            report.add(
                "field_mismatches",
                "STEP_PROOF_ZERO_COUNT_VIOLATION",
                f"{receipt.step_id}.{field}:{proof.get(field)!r}",
            )

    if receipt.step_id == "STEP09":
        for field in (
            "natural_monster_event_count",
            "monster_move_authority_receipt_count",
            "terminal_move_step_receipt_count",
            "geodesic_route_receipt_count",
            "consequence_ledger_receipt_count",
            "presentation_cue_start_count",
            "presentation_cue_finish_count",
            "exact_once_binding_count",
        ):
            require_positive(field)
        for field in (
            "duplicate_binding_count",
            "old_movement_writer_count",
            "old_trample_receipt_count",
        ):
            require_zero(field)
        authority_count = proof.get("monster_move_authority_receipt_count")
        positive_counts = {
            proof.get(field)
            for field in (
                "natural_monster_event_count",
                "monster_move_authority_receipt_count",
                "terminal_move_step_receipt_count",
                "geodesic_route_receipt_count",
                "consequence_ledger_receipt_count",
                "presentation_cue_start_count",
                "presentation_cue_finish_count",
                "exact_once_binding_count",
            )
        }
        if len(positive_counts) != 1 or proof.get("exact_once_binding_count") != authority_count:
            report.add(
                "field_mismatches",
                "STEP09_EXACT_ONCE_PARITY_MISMATCH",
                repr(proof),
            )
    elif receipt.step_id == "STEP11":
        for field in (
            "asset_authority_receipt_count",
            "before_after_quantity_receipt_count",
            "committed_revision_receipt_count",
            "asset_delta_projection_count",
            "asset_consequence_binding_count",
            "exact_once_binding_count",
        ):
            require_positive(field)
        for field in (
            "duplicate_binding_count",
            "ui_gameplay_mutation_count",
            "opponent_private_asset_disclosure_count",
            "asset_projection_failure_count",
        ):
            require_zero(field)
        authority_count = proof.get("asset_authority_receipt_count")
        positive_counts = {
            proof.get(field)
            for field in (
                "asset_authority_receipt_count",
                "before_after_quantity_receipt_count",
                "committed_revision_receipt_count",
                "asset_delta_projection_count",
                "asset_consequence_binding_count",
                "exact_once_binding_count",
            )
        }
        if len(positive_counts) != 1 or proof.get("exact_once_binding_count") != authority_count:
            report.add(
                "field_mismatches",
                "STEP11_EXACT_ONCE_PARITY_MISMATCH",
                repr(proof),
            )
    elif receipt.step_id == "STEP12":
        for field in (
            "persisted_ai_observation_envelope_count",
            "allowed_field_manifest_count",
            "observation_source_receipt_binding_count",
            "ai_public_action_receipt_count",
            "sanitized_projection_binding_count",
        ):
            require_positive(field)
        for field in (
            "hidden_info_violation_count",
            "private_information_violation_count",
            "opponent_private_asset_disclosure_count",
        ):
            require_zero(field)
        for field in (
            "actor_id_disclosed",
            "private_queue_disclosed",
            "hidden_order_disclosed",
        ):
            if not _is_exact_bool(proof.get(field)) or proof[field] is not False:
                report.add(
                    "field_mismatches",
                    "STEP12_PRIVATE_DISCLOSURE_DETECTED",
                    f"{field}:{proof.get(field)!r}",
                )
        positive_counts = {
            proof.get(field)
            for field in (
                "persisted_ai_observation_envelope_count",
                "allowed_field_manifest_count",
                "observation_source_receipt_binding_count",
                "ai_public_action_receipt_count",
                "sanitized_projection_binding_count",
            )
        }
        if len(positive_counts) != 1:
            report.add(
                "field_mismatches",
                "STEP12_OBSERVATION_ACTION_PARITY_MISMATCH",
                repr(proof),
            )


def _validate_manifest_product_bindings(
    project: GitCommittedProject,
    manifest: Mapping[str, Any],
    heads: Sequence[str],
    report: ValidationReport,
) -> dict[str, str]:
    runtime_sha: dict[str, str] = {}
    tree_entries: dict[str, dict[str, tuple[str, str, int]]] = {}
    try:
        tree_entries = {
            head: project.recursive_blob_entries(head) for head in heads
        }
    except ValueError as exc:
        report.add(
            "path_failures", "PRODUCT_BINDING_TREE_ENUMERATION_FAILED", str(exc)
        )
        return runtime_sha
    required_object_ids: set[str] = set()
    binding_rows: list[tuple[str, str, str, int, str]] = []
    for collection_name in ("runtime_boundary_bindings", "product_path_bindings"):
        rows = manifest.get(collection_name)
        if not isinstance(rows, list) or not rows:
            report.add(
                "schema_failures",
                "PRODUCT_BINDING_COLLECTION_INVALID",
                collection_name,
            )
            continue
        seen: set[str] = set()
        for index, row in enumerate(rows):
            label = f"{collection_name}[{index}]"
            if not isinstance(row, dict):
                report.add("schema_failures", "PRODUCT_BINDING_NOT_OBJECT", label)
                continue
            path = row.get("path")
            claimed_sha = row.get("sha256")
            claimed_size = row.get("size_bytes")
            try:
                normalized = normalize_repo_relative_path(path)
            except ValueError as exc:
                report.add("path_failures", "PRODUCT_BINDING_PATH_INVALID", f"{label}:{exc}")
                continue
            if normalized in seen:
                report.add("schema_failures", "PRODUCT_BINDING_PATH_DUPLICATE", normalized)
            seen.add(normalized)
            if not _is_sha256(claimed_sha) or not _is_exact_int(claimed_size) or claimed_size < 0:
                report.add("schema_failures", "PRODUCT_BINDING_METADATA_INVALID", label)
                continue
            if collection_name == "runtime_boundary_bindings":
                runtime_sha[normalized] = claimed_sha
            for head in heads:
                entry = tree_entries[head].get(normalized)
                if entry is None:
                    report.add(
                        "path_failures",
                        "PRODUCT_BINDING_FILE_UNAVAILABLE",
                        f"{label}:{head}",
                    )
                    continue
                mode, object_id, actual_size = entry
                claimed_blob = row.get("git_blob_sha1")
                if (
                    mode not in {"100644", "100755"}
                    or actual_size != claimed_size
                    or not isinstance(claimed_blob, str)
                    or object_id != claimed_blob
                ):
                    report.add(
                        "hash_mismatches",
                        "PRODUCT_BINDING_DRIFT",
                        f"{label}:{head}",
                    )
                    continue
                required_object_ids.add(object_id)
                binding_rows.append(
                    (label, head, object_id, claimed_size, claimed_sha)
                )
    try:
        blobs = project.read_blobs(required_object_ids)
    except ValueError as exc:
        report.add("hash_mismatches", "PRODUCT_BLOB_BATCH_READ_FAILED", str(exc))
        return runtime_sha
    for label, head, object_id, claimed_size, claimed_sha in binding_rows:
        data = blobs.get(object_id)
        if data is None or len(data) != claimed_size or sha256_bytes(data) != claimed_sha:
            report.add(
                "hash_mismatches",
                "PRODUCT_BINDING_SHA256_DRIFT",
                f"{label}:{head}",
            )
    return runtime_sha


def _negative_case_ids_from_selftest_bytes(data: bytes) -> list[str]:
    try:
        data.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise ValueError(f"SELFTEST_SOURCE_INVALID_UTF8:{exc.start}") from exc
    case_ids = [match.decode("ascii") for match in NEGATIVE_CASE_ID_RE.findall(data)]
    if len(case_ids) != len(set(case_ids)):
        raise ValueError("SELFTEST_NEGATIVE_CASE_ID_DUPLICATE")
    ordered = sorted(case_ids)
    actual_set_hash = sha256_bytes(
        "".join(f"{case_id}\n" for case_id in ordered).encode("utf-8")
    )
    if len(ordered) != REQUIRED_NEGATIVE_CASE_COUNT:
        raise ValueError(
            "SELFTEST_NEGATIVE_CASE_COUNT_MISMATCH:"
            f"expected={REQUIRED_NEGATIVE_CASE_COUNT}:actual={len(ordered)}"
        )
    if actual_set_hash != REQUIRED_NEGATIVE_CASE_ID_SET_SHA256:
        raise ValueError(
            "SELFTEST_NEGATIVE_CASE_SET_MISMATCH:"
            f"expected={REQUIRED_NEGATIVE_CASE_ID_SET_SHA256}:actual={actual_set_hash}"
        )
    return ordered


def _negative_case_id_set_sha256(case_ids: Sequence[str]) -> str:
    payload = "".join(f"{case_id}\n" for case_id in case_ids).encode("utf-8")
    return sha256_bytes(payload)


def _generation8_negative_case_ids_from_selftest_bytes(data: bytes) -> list[str]:
    try:
        data.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise ValueError(f"SELFTEST_SOURCE_INVALID_UTF8:{exc.start}") from exc
    case_ids = [
        match.decode("ascii") for match in GENERATION8_NEGATIVE_CASE_ID_RE.findall(data)
    ]
    if len(case_ids) != len(set(case_ids)):
        raise ValueError("GENERATION8_SELFTEST_NEGATIVE_CASE_ID_DUPLICATE")
    ordered = sorted(case_ids)
    actual_set_hash = _negative_case_id_set_sha256(ordered)
    if len(ordered) != GENERATION8_REQUIRED_NEGATIVE_CASE_COUNT:
        raise ValueError(
            "GENERATION8_SELFTEST_NEGATIVE_CASE_COUNT_MISMATCH:"
            f"expected={GENERATION8_REQUIRED_NEGATIVE_CASE_COUNT}:actual={len(ordered)}"
        )
    if actual_set_hash != GENERATION8_REQUIRED_NEGATIVE_CASE_ID_SET_SHA256:
        raise ValueError(
            "GENERATION8_SELFTEST_NEGATIVE_CASE_SET_MISMATCH:"
            f"expected={GENERATION8_REQUIRED_NEGATIVE_CASE_ID_SET_SHA256}:"
            f"actual={actual_set_hash}"
        )
    return ordered


def _generation8_executed_negative_case_ids_match(
    executed_case_ids: Sequence[str], selftest_bytes: bytes
) -> bool:
    if (
        len(executed_case_ids) != GENERATION8_REQUIRED_NEGATIVE_CASE_COUNT
        or any(not isinstance(case_id, str) for case_id in executed_case_ids)
        or len(executed_case_ids) != len(set(executed_case_ids))
    ):
        return False
    try:
        declared = _generation8_negative_case_ids_from_selftest_bytes(selftest_bytes)
    except ValueError:
        return False
    ordered = sorted(executed_case_ids)
    return (
        ordered == declared
        and _negative_case_id_set_sha256(ordered)
        == GENERATION8_REQUIRED_NEGATIVE_CASE_ID_SET_SHA256
    )


def _validate_generation8_negative_fixture_catalog(
    value: Any,
    selftest_bytes: bytes,
    report: ValidationReport,
    label: str,
) -> None:
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_NEGATIVE_FIXTURE_CATALOG_FIELD_SET_MISMATCH",
        label,
        value,
        NEGATIVE_FIXTURE_CATALOG_FIELDS,
    ):
        return
    assert isinstance(value, dict)
    try:
        expected_case_ids = _generation8_negative_case_ids_from_selftest_bytes(
            selftest_bytes
        )
    except ValueError as exc:
        report.add(
            "schema_failures", "GENERATION8_SELFTEST_NEGATIVE_CASE_SCAN_FAILED", str(exc)
        )
        return
    expected = {
        "schema_version": "space_syndicate.v076.generation8_negative_fixture_catalog.v1",
        "status": "PASS",
        "case_ids": expected_case_ids,
        "case_count": len(expected_case_ids),
        "pass_count": len(expected_case_ids),
        "false_green_count": 0,
        "case_id_set_sha256": _negative_case_id_set_sha256(expected_case_ids),
    }
    for field, expected_value in expected.items():
        actual = value.get(field)
        if actual != expected_value:
            report.add(
                "identity_mismatches",
                "GENERATION8_NEGATIVE_FIXTURE_CATALOG_IDENTITY_MISMATCH",
                f"{label}.{field}:expected={expected_value!r}:actual={actual!r}",
            )
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add(
            "hash_mismatches",
            "GENERATION8_NEGATIVE_FIXTURE_CATALOG_CANONICAL_SHA256_MISMATCH",
            label,
        )


def _executed_negative_case_ids_match(
    executed_case_ids: Sequence[str], selftest_bytes: bytes
) -> bool:
    if (
        len(executed_case_ids) != REQUIRED_NEGATIVE_CASE_COUNT
        or any(not isinstance(case_id, str) for case_id in executed_case_ids)
        or len(executed_case_ids) != len(set(executed_case_ids))
    ):
        return False
    try:
        declared_case_ids = _negative_case_ids_from_selftest_bytes(selftest_bytes)
    except ValueError:
        return False
    ordered = sorted(executed_case_ids)
    return (
        ordered == declared_case_ids
        and _negative_case_id_set_sha256(ordered)
        == REQUIRED_NEGATIVE_CASE_ID_SET_SHA256
    )


def _validate_negative_fixture_catalog(
    value: Any,
    selftest_bytes: bytes,
    report: ValidationReport,
    label: str,
) -> None:
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "NEGATIVE_FIXTURE_CATALOG_FIELD_SET_MISMATCH",
        label,
        value,
        NEGATIVE_FIXTURE_CATALOG_FIELDS,
    ):
        return
    assert isinstance(value, dict)
    try:
        expected_case_ids = _negative_case_ids_from_selftest_bytes(selftest_bytes)
    except ValueError as exc:
        report.add("schema_failures", "SELFTEST_NEGATIVE_CASE_SCAN_FAILED", str(exc))
        return
    case_ids = value.get("case_ids")
    if (
        not isinstance(case_ids, list)
        or any(not isinstance(case_id, str) for case_id in case_ids)
        or case_ids != expected_case_ids
    ):
        report.add(
            "identity_mismatches",
            "NEGATIVE_FIXTURE_CASE_IDS_MISMATCH",
            f"{label}:expected={expected_case_ids!r}:actual={case_ids!r}",
        )
    expected = {
        "schema_version": NEGATIVE_FIXTURE_CATALOG_SCHEMA_VERSION,
        "status": "PASS",
        "case_count": len(expected_case_ids),
        "pass_count": len(expected_case_ids),
        "false_green_count": 0,
        "case_id_set_sha256": _negative_case_id_set_sha256(expected_case_ids),
    }
    for field, expected_value in expected.items():
        actual = value.get(field)
        invalid_int = field in {
            "case_count",
            "pass_count",
            "false_green_count",
        } and not _is_exact_int(actual)
        if invalid_int or actual != expected_value:
            report.add(
                "identity_mismatches",
                "NEGATIVE_FIXTURE_CATALOG_IDENTITY_MISMATCH",
                f"{label}.{field}:expected={expected_value!r}:actual={actual!r}",
            )
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add(
            "hash_mismatches",
            "NEGATIVE_FIXTURE_CATALOG_CANONICAL_SHA256_MISMATCH",
            label,
        )


def _validate_tool_dependency_inventory(
    value: Any, report: ValidationReport, label: str
) -> None:
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "TOOL_DEPENDENCY_INVENTORY_FIELD_SET_MISMATCH",
        label,
        value,
        TOOL_DEPENDENCY_INVENTORY_FIELDS,
    ):
        return
    assert isinstance(value, dict)
    expected = {
        "schema_version": TOOL_DEPENDENCY_INVENTORY_SCHEMA_VERSION,
        "status": "PASS",
        "python_dependency_policy": "STDLIB_ONLY",
        "python_external_dependency_count": 0,
        "python_external_dependencies": [],
        "required_executable_count": 3,
        "required_executables": ["git", "pwsh", "python"],
    }
    for field, expected_value in expected.items():
        actual = value.get(field)
        invalid_int = field in {
            "python_external_dependency_count",
            "required_executable_count",
        } and not _is_exact_int(actual)
        if invalid_int or actual != expected_value:
            report.add(
                "identity_mismatches",
                "TOOL_DEPENDENCY_INVENTORY_IDENTITY_MISMATCH",
                f"{label}.{field}:expected={expected_value!r}:actual={actual!r}",
            )
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add(
            "hash_mismatches",
            "TOOL_DEPENDENCY_INVENTORY_CANONICAL_SHA256_MISMATCH",
            label,
        )


def _validate_independent_audit(
    value: Any,
    audit_id: str,
    audit_scope: str,
    receipt: V076CurrentSubjectProductionRevalidationReceiptV1,
    selftest_sha256: Any,
    report: ValidationReport,
    label: str,
) -> None:
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "INDEPENDENT_AUDIT_FIELD_SET_MISMATCH",
        label,
        value,
        INDEPENDENT_AUDIT_FIELDS,
    ):
        return
    assert isinstance(value, dict)
    expected = {
        "schema_version": INDEPENDENT_AUDIT_SCHEMA_VERSION,
        "audit_id": audit_id,
        "audit_scope": audit_scope,
        "status": "GO",
        "p0_count": 0,
        "p1_count": 0,
        "schema_authority_sha256": receipt.schema_authority_sha256,
        "validator_sha256": receipt.validator_sha256,
        "workflow_sha256": receipt.workflow_sha256,
        "selftest_sha256": selftest_sha256,
        "auditor_mode": "INDEPENDENT_READ_ONLY",
        "finding_count": 0,
        "findings": [],
    }
    for field, expected_value in expected.items():
        actual = value.get(field)
        invalid_int = field in {
            "p0_count",
            "p1_count",
            "finding_count",
        } and not _is_exact_int(actual)
        if invalid_int or actual != expected_value:
            report.add(
                "identity_mismatches",
                "INDEPENDENT_AUDIT_IDENTITY_MISMATCH",
                f"{label}.{field}:expected={expected_value!r}:actual={actual!r}",
            )
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add(
            "hash_mismatches",
            "INDEPENDENT_AUDIT_CANONICAL_SHA256_MISMATCH",
            label,
        )


def _validate_resume_checkpoint(
    resume: Mapping[str, Any], report: ValidationReport, label: str
) -> None:
    for field in ("resume_start_checkpoint", "first_unexecuted_step"):
        if resume.get(field) != RESUME_START_CHECKPOINT:
            report.add(
                "identity_mismatches",
                "RESUME_AUTHORIZATION_CHECKPOINT_NOT_AUTHORIZED",
                f"{label}.{field}:expected={RESUME_START_CHECKPOINT!r}:actual={resume.get(field)!r}",
            )
    if resume.get("resume_start_checkpoint") != resume.get("first_unexecuted_step"):
        report.add(
            "identity_mismatches",
            "RESUME_AUTHORIZATION_CHECKPOINT_MISMATCH",
            f"{label}:{(resume.get('resume_start_checkpoint'), resume.get('first_unexecuted_step'))!r}",
        )


def _validate_frozen_identity_documents(
    project: GitCommittedProject,
    head: str,
    receipt: V076CurrentSubjectProductionRevalidationReceiptV1,
    seal: Mapping[str, Any],
    report: ValidationReport,
) -> None:
    binding_specs = (
        (
            HARD_STOP_ATTESTATION_PATH,
            "hard_stop_identity_attestation_sha256",
            HARD_STOP_ATTESTATION_SHA256,
        ),
        (
            EVIDENCE_9631_ATTESTATION_PATH,
            "evidence_9631_identity_attestation_sha256",
            EVIDENCE_9631_ATTESTATION_SHA256,
        ),
        (
            FROZEN_INPUT_INVENTORY_PATH,
            "frozen_input_inventory_sha256",
            FROZEN_INPUT_INVENTORY_SHA256,
        ),
        (
            FROZEN_INPUT_SIDECAR_PATH,
            "frozen_input_sidecar_sha256",
            FROZEN_INPUT_SIDECAR_SHA256,
        ),
    )
    for path, field, expected_sha in binding_specs:
        claimed = seal.get(field)
        if claimed != expected_sha:
            report.add(
                "identity_mismatches",
                "FROZEN_INPUT_SEAL_HASH_MISMATCH",
                f"{field}:expected={expected_sha}:actual={claimed}",
            )
            continue
        for binding_head, binding_label in (
            (receipt.producer_tooling_head_sha, "producer_tooling_head"),
            (head, "evaluated_head"),
        ):
            _validate_supporting_binding(
                project,
                binding_head,
                path,
                expected_sha,
                report,
                f"{receipt.step_id}.{binding_label}.{field}",
            )

    hard_stop, hard_stop_bytes = _load_committed_json(
        project,
        head,
        HARD_STOP_ATTESTATION_PATH,
        report,
        f"{receipt.step_id}.hard_stop_identity_attestation",
    )
    if (
        hard_stop_bytes is not None
        and sha256_bytes(hard_stop_bytes) != HARD_STOP_ATTESTATION_SHA256
    ):
        report.add(
            "hash_mismatches", "FROZEN_HARD_STOP_ATTESTATION_DRIFT", receipt.step_id
        )
    if _compare_exact_keys(
        report,
        "schema_failures",
        "HARD_STOP_ATTESTATION_FIELD_SET_MISMATCH",
        f"{receipt.step_id}.hard_stop_identity_attestation",
        hard_stop,
        HARD_STOP_ATTESTATION_FIELDS,
    ):
        assert isinstance(hard_stop, dict)
        hard_expected = {
            "schema_version": "space_syndicate.v076.generation7_hard_stop_identity_attestation.v1",
            "authorization_id": AUTHORIZATION_ID,
            "status": "PASS",
            "authorized_hash_prefix": "3309a0cb",
            "authorized_hash_suffix": "7c0c",
            "matching_record_count": 1,
            "identity_mismatch_count": 0,
            "identity_ambiguous": False,
        }
        for field, expected in hard_expected.items():
            if hard_stop.get(field) != expected:
                report.add(
                    "identity_mismatches",
                    "HARD_STOP_ATTESTATION_IDENTITY_MISMATCH",
                    field,
                )
        try:
            parse_rfc3339_utc(hard_stop.get("attested_at_utc"))
        except ValueError:
            report.add(
                "schema_failures",
                "HARD_STOP_ATTESTATION_TIMESTAMP_INVALID",
                receipt.step_id,
            )
        record = hard_stop.get("record")
        if _compare_exact_keys(
            report,
            "schema_failures",
            "HARD_STOP_ATTESTATION_RECORD_FIELD_SET_MISMATCH",
            f"{receipt.step_id}.hard_stop_identity_attestation.record",
            record,
            HARD_STOP_ATTESTATION_RECORD_FIELDS,
        ):
            assert isinstance(record, dict)
            record_expected = {
                "external_path": "outputs/V076_CURRENT_SUBJECT_CONVERGENCE_HARD_STOP_20260831T044438Z.json",
                "sha256": AUTHORIZED_HARD_STOP_SHA256,
                "schema_version": "space_syndicate.v076.current_subject_convergence_hard_stop.v1",
                "hard_stop_condition": "INDEPENDENT_AUDIT_P1",
                "first_failure_class": "CURRENT_SUBJECT_STEP_RECEIPTS_HAVE_NO_FAIL_CLOSED_SCHEMA_VALIDATOR_OR_REQUIRED_GATE_CONSUMER",
                "generation_id": 7,
                "last_consumed_evidence_id": 9630,
                "resume_evidence_id": 9631,
                "generation_7_started": False,
                "receipt_schema_code_definition_count": 0,
                "receipt_validator_authority_count": 0,
                "required_workflow_consumer_count": 0,
            }
            for field, expected in record_expected.items():
                if record.get(field) != expected:
                    report.add(
                        "identity_mismatches",
                        "HARD_STOP_RECORD_IDENTITY_MISMATCH",
                        field,
                    )
            if not _is_exact_int(record.get("byte_count")) or record["byte_count"] <= 0:
                report.add(
                    "schema_failures",
                    "HARD_STOP_RECORD_BYTE_COUNT_INVALID",
                    receipt.step_id,
                )

    evidence, evidence_bytes = _load_committed_json(
        project,
        head,
        EVIDENCE_9631_ATTESTATION_PATH,
        report,
        f"{receipt.step_id}.evidence_9631_identity_attestation",
    )
    if (
        evidence_bytes is not None
        and sha256_bytes(evidence_bytes) != EVIDENCE_9631_ATTESTATION_SHA256
    ):
        report.add(
            "hash_mismatches",
            "FROZEN_EVIDENCE_9631_ATTESTATION_DRIFT",
            receipt.step_id,
        )
    if _compare_exact_keys(
        report,
        "schema_failures",
        "EVIDENCE_9631_ATTESTATION_FIELD_SET_MISMATCH",
        f"{receipt.step_id}.evidence_9631_identity_attestation",
        evidence,
        EVIDENCE_9631_ATTESTATION_FIELDS,
    ):
        assert isinstance(evidence, dict)
        evidence_expected = {
            "schema_version": "space_syndicate.v076.generation7_resume_evidence_identity_attestation.v1",
            "authorization_id": AUTHORIZATION_ID,
            "status": "PASS",
            "parent_generation_id": 7,
            "resume_evidence_id": 9631,
            "identity_kind": "RESERVED_NEXT_APPEND_ONLY_EVIDENCE_SLOT",
            "reservation_authority_sha256": AUTHORIZED_HARD_STOP_SHA256,
            "generation_7_started": False,
            "last_consumed_evidence_id": 9630,
            "preexisting_evidence_9631_file_count": 0,
            "preexisting_evidence_9631_files": [],
            "reserved_slot_exists": True,
            "reserved_slot_consumed": False,
            "overwrite_allowed": False,
            "evidence_root_logical_path": "outputs/mcp_exact_subject_ac5efcc5_20260830T235123Z",
            "evidence_root_file_count": 2351,
            "evidence_root_inventory_payload": "relative_path|lowercase_sha256|byte_count+LF",
            "evidence_root_inventory_sha256": FROZEN_EVIDENCE_INVENTORY_SHA256,
            "first_evidence_file": "0001-get-project-info.jsonrpc.json",
            "last_evidence_file": "9630-query-pacing-after-pause-retry-generation6-current.jsonrpc.json",
            "identity_mismatch_count": 0,
        }
        for field, expected in evidence_expected.items():
            actual = evidence.get(field)
            invalid_int = field in {
                "parent_generation_id",
                "resume_evidence_id",
                "last_consumed_evidence_id",
                "preexisting_evidence_9631_file_count",
                "evidence_root_file_count",
                "identity_mismatch_count",
            } and not _is_exact_int(actual)
            invalid_bool = field in {
                "generation_7_started",
                "reserved_slot_exists",
                "reserved_slot_consumed",
                "overwrite_allowed",
            } and not _is_exact_bool(actual)
            if invalid_int or invalid_bool or actual != expected:
                report.add(
                    "identity_mismatches", "EVIDENCE_9631_IDENTITY_MISMATCH", field
                )
        try:
            parse_rfc3339_utc(evidence.get("attested_at_utc"))
        except ValueError:
            report.add(
                "schema_failures",
                "EVIDENCE_9631_ATTESTATION_TIMESTAMP_INVALID",
                receipt.step_id,
            )

    inventory, inventory_bytes = _load_committed_json(
        project,
        head,
        FROZEN_INPUT_INVENTORY_PATH,
        report,
        f"{receipt.step_id}.frozen_input_inventory",
    )
    if (
        inventory_bytes is not None
        and sha256_bytes(inventory_bytes) != FROZEN_INPUT_INVENTORY_SHA256
    ):
        report.add(
            "hash_mismatches", "FROZEN_INPUT_INVENTORY_DRIFT", receipt.step_id
        )
    if _compare_exact_keys(
        report,
        "schema_failures",
        "FROZEN_INPUT_INVENTORY_FIELD_SET_MISMATCH",
        f"{receipt.step_id}.frozen_input_inventory",
        inventory,
        FROZEN_INPUT_INVENTORY_FIELDS,
    ):
        assert isinstance(inventory, dict)
        inventory_expected = {
            "schema_version": "space_syndicate.v076.generation7_receipt_contract_frozen_input_inventory.v1",
            "authorization_id": AUTHORIZATION_ID,
            "status": "FROZEN",
        }
        for field, expected in inventory_expected.items():
            if inventory.get(field) != expected:
                report.add(
                    "identity_mismatches",
                    "FROZEN_INPUT_INVENTORY_IDENTITY_MISMATCH",
                    field,
                )
        try:
            parse_rfc3339_utc(inventory.get("frozen_at_utc"))
        except ValueError:
            report.add(
                "schema_failures",
                "FROZEN_INPUT_INVENTORY_TIMESTAMP_INVALID",
                receipt.step_id,
            )
        nested_specs = (
            ("base_identity", FROZEN_BASE_IDENTITY_FIELDS),
            ("frozen_authorities", FROZEN_AUTHORITIES_FIELDS),
            ("frozen_external_evidence", FROZEN_EXTERNAL_EVIDENCE_FIELDS),
            ("frozen_generation7_files", FROZEN_GENERATION7_FILES_FIELDS),
            ("frozen_previous_audits", FROZEN_PREVIOUS_AUDITS_FIELDS),
            ("preservation_assertions", FROZEN_PRESERVATION_ASSERTIONS_FIELDS),
        )
        for field, expected_fields in nested_specs:
            _compare_exact_keys(
                report,
                "schema_failures",
                "FROZEN_INPUT_NESTED_FIELD_SET_MISMATCH",
                f"{receipt.step_id}.frozen_input_inventory.{field}",
                inventory.get(field),
                expected_fields,
            )
        base_identity = inventory.get("base_identity")
        frozen_authorities = inventory.get("frozen_authorities")
        frozen_evidence = inventory.get("frozen_external_evidence")
        frozen_files = inventory.get("frozen_generation7_files")
        frozen_audits = inventory.get("frozen_previous_audits")
        preservation = inventory.get("preservation_assertions")
        base_tree = project.tree(AUTHORIZED_BASE_HEAD_SHA)
        semantic_checks = (
            (
                isinstance(base_identity, dict)
                and base_identity.get("local_head_sha") == AUTHORIZED_BASE_HEAD_SHA
                and base_identity.get("local_tree_sha") == base_tree,
                "BASE_IDENTITY",
            ),
            (
                isinstance(base_identity, dict)
                and base_identity.get("remote_pr93_head_sha") == AUTHORIZED_BASE_HEAD_SHA
                and base_identity.get("remote_pr93_tree_sha") == base_tree
                and base_identity.get("remote_pr93_state") == "OPEN"
                and base_identity.get("remote_pr93_is_draft") is True,
                "REMOTE_PR93_IDENTITY",
            ),
            (
                isinstance(base_identity, dict)
                and base_identity.get("current_product_subject_head_sha") == CURRENT_SUBJECT_HEAD_SHA
                and base_identity.get("current_product_subject_tree_sha") == CURRENT_SUBJECT_TREE_SHA,
                "PRODUCT_SUBJECT_IDENTITY",
            ),
            (
                isinstance(frozen_authorities, dict)
                and frozen_authorities.get("hard_stop_record_sha256") == AUTHORIZED_HARD_STOP_SHA256
                and frozen_authorities.get("required_check_context") == REQUIRED_CHECK_CONTEXT
                and frozen_authorities.get("resume_generation_id") == 7
                and frozen_authorities.get("resume_evidence_id") == 9631,
                "FROZEN_AUTHORITIES",
            ),
            (
                isinstance(frozen_evidence, dict)
                and frozen_evidence.get("inventory_sha256") == FROZEN_EVIDENCE_INVENTORY_SHA256
                and frozen_evidence.get("file_count") == 2351
                and frozen_evidence.get("last_consumed_evidence_id") == 9630
                and frozen_evidence.get("next_reserved_evidence_id") == 9631
                and frozen_evidence.get("preexisting_9631_file_count") == 0,
                "FROZEN_EXTERNAL_EVIDENCE",
            ),
            (
                isinstance(frozen_files, dict)
                and frozen_files.get("preexisting_named_file_count") == 0
                and frozen_files.get("preexisting_named_files") == []
                and frozen_files.get("modification_allowed") is False,
                "FROZEN_GENERATION7_FILES",
            ),
            (
                isinstance(frozen_audits, dict)
                and frozen_audits.get("audit_count") == 2
                and frozen_audits.get("modification_allowed") is False,
                "FROZEN_PREVIOUS_AUDITS",
            ),
            (
                isinstance(preservation, dict)
                and all(
                    _is_exact_int(item) and item == 0
                    for item in preservation.values()
                ),
                "PRESERVATION_ASSERTIONS",
            ),
        )
        for passed, field in semantic_checks:
            if not passed:
                report.add(
                    "identity_mismatches", "FROZEN_INPUT_SEMANTIC_MISMATCH", field
                )

    try:
        sidecar_bytes = project.read_regular_file(head, FROZEN_INPUT_SIDECAR_PATH)
    except (ValueError, CommittedPathError) as exc:
        report.add("path_failures", "FROZEN_INPUT_SIDECAR_UNAVAILABLE", str(exc))
    else:
        expected_sidecar = (
            f"{FROZEN_INPUT_INVENTORY_SHA256}  frozen_input_inventory.json\n"
        ).encode("ascii")
        if sidecar_bytes != expected_sidecar:
            report.add(
                "hash_mismatches", "FROZEN_INPUT_SIDECAR_MISMATCH", receipt.step_id
            )


def _validate_seal_documents(
    project: GitCommittedProject,
    head: str,
    receipt: V076CurrentSubjectProductionRevalidationReceiptV1,
    report: ValidationReport,
) -> None:
    predecessor_bindings = (
        (
            PREDECESSOR_TOOLING_SEAL_PATH,
            PREDECESSOR_TOOLING_SEAL_SHA256,
            "predecessor_tooling_seal",
        ),
        (
            PREDECESSOR_RESUME_AUTHORIZATION_MANIFEST_PATH,
            PREDECESSOR_RESUME_AUTHORIZATION_MANIFEST_SHA256,
            "predecessor_resume_authorization",
        ),
        (
            PREDECESSOR_SUCCESSOR_V2_TOOLING_SEAL_PATH,
            PREDECESSOR_SUCCESSOR_V2_TOOLING_SEAL_SHA256,
            "predecessor_successor_v2_tooling_seal",
        ),
        (
            PREDECESSOR_SUCCESSOR_V2_RESUME_AUTHORIZATION_MANIFEST_PATH,
            PREDECESSOR_SUCCESSOR_V2_RESUME_AUTHORIZATION_MANIFEST_SHA256,
            "predecessor_successor_v2_resume_authorization",
        ),
        (
            PREDECESSOR_SUCCESSOR_V3_TOOLING_SEAL_PATH,
            PREDECESSOR_SUCCESSOR_V3_TOOLING_SEAL_SHA256,
            "predecessor_successor_v3_tooling_seal",
        ),
        (
            PREDECESSOR_SUCCESSOR_V3_RESUME_AUTHORIZATION_MANIFEST_PATH,
            PREDECESSOR_SUCCESSOR_V3_RESUME_AUTHORIZATION_MANIFEST_SHA256,
            "predecessor_successor_v3_resume_authorization",
        ),
    )
    for predecessor_path, predecessor_sha256, predecessor_kind in predecessor_bindings:
        _validate_supporting_binding(
            project,
            head,
            predecessor_path,
            predecessor_sha256,
            report,
            f"{receipt.step_id}.{predecessor_kind}",
        )
    try:
        predecessor_tree = project.tree(PREDECESSOR_TOOLING_HEAD_SHA)
    except ValueError as exc:
        report.add(
            "identity_mismatches",
            "PREDECESSOR_TOOLING_IDENTITY_INVALID",
            str(exc),
        )
    else:
        if predecessor_tree != PREDECESSOR_TOOLING_TREE_SHA:
            report.add(
                "identity_mismatches",
                "PREDECESSOR_TOOLING_TREE_MISMATCH",
                f"expected={PREDECESSOR_TOOLING_TREE_SHA}:actual={predecessor_tree}",
            )
        if not project.is_ancestor(
            PREDECESSOR_TOOLING_HEAD_SHA,
            receipt.producer_tooling_head_sha,
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_TOOLING_NOT_ANCESTOR",
                receipt.producer_tooling_head_sha,
            )
    try:
        predecessor_resume_tree = project.tree(PREDECESSOR_RESUME_HEAD_SHA)
    except ValueError as exc:
        report.add(
            "identity_mismatches",
            "PREDECESSOR_RESUME_IDENTITY_INVALID",
            str(exc),
        )
    else:
        if predecessor_resume_tree != PREDECESSOR_RESUME_TREE_SHA:
            report.add(
                "identity_mismatches",
                "PREDECESSOR_RESUME_TREE_MISMATCH",
                f"expected={PREDECESSOR_RESUME_TREE_SHA}:actual={predecessor_resume_tree}",
            )
        if not project.is_ancestor(
            PREDECESSOR_RESUME_HEAD_SHA,
            receipt.producer_tooling_head_sha,
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_RESUME_NOT_ANCESTOR",
                receipt.producer_tooling_head_sha,
            )
    try:
        predecessor_successor_v2_tooling_tree = project.tree(
            PREDECESSOR_SUCCESSOR_V2_TOOLING_HEAD_SHA
        )
    except ValueError as exc:
        report.add(
            "identity_mismatches",
            "PREDECESSOR_SUCCESSOR_V2_TOOLING_IDENTITY_INVALID",
            str(exc),
        )
    else:
        if (
            predecessor_successor_v2_tooling_tree
            != PREDECESSOR_SUCCESSOR_V2_TOOLING_TREE_SHA
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_SUCCESSOR_V2_TOOLING_TREE_MISMATCH",
                "expected="
                f"{PREDECESSOR_SUCCESSOR_V2_TOOLING_TREE_SHA}:"
                f"actual={predecessor_successor_v2_tooling_tree}",
            )
        if not project.is_ancestor(
            PREDECESSOR_SUCCESSOR_V2_TOOLING_HEAD_SHA,
            receipt.producer_tooling_head_sha,
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_SUCCESSOR_V2_TOOLING_NOT_ANCESTOR",
                receipt.producer_tooling_head_sha,
            )
    try:
        predecessor_successor_v2_resume_tree = project.tree(
            PREDECESSOR_SUCCESSOR_V2_RESUME_HEAD_SHA
        )
    except ValueError as exc:
        report.add(
            "identity_mismatches",
            "PREDECESSOR_SUCCESSOR_V2_RESUME_IDENTITY_INVALID",
            str(exc),
        )
    else:
        if (
            predecessor_successor_v2_resume_tree
            != PREDECESSOR_SUCCESSOR_V2_RESUME_TREE_SHA
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_SUCCESSOR_V2_RESUME_TREE_MISMATCH",
                "expected="
                f"{PREDECESSOR_SUCCESSOR_V2_RESUME_TREE_SHA}:"
                f"actual={predecessor_successor_v2_resume_tree}",
            )
        if not project.is_ancestor(
            PREDECESSOR_SUCCESSOR_V2_RESUME_HEAD_SHA,
            receipt.producer_tooling_head_sha,
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_SUCCESSOR_V2_RESUME_NOT_ANCESTOR",
                receipt.producer_tooling_head_sha,
            )
    try:
        predecessor_successor_v3_tooling_tree = project.tree(
            PREDECESSOR_SUCCESSOR_V3_TOOLING_HEAD_SHA
        )
    except ValueError as exc:
        report.add(
            "identity_mismatches",
            "PREDECESSOR_SUCCESSOR_V3_TOOLING_IDENTITY_INVALID",
            str(exc),
        )
    else:
        if (
            predecessor_successor_v3_tooling_tree
            != PREDECESSOR_SUCCESSOR_V3_TOOLING_TREE_SHA
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_SUCCESSOR_V3_TOOLING_TREE_MISMATCH",
                "expected="
                f"{PREDECESSOR_SUCCESSOR_V3_TOOLING_TREE_SHA}:"
                f"actual={predecessor_successor_v3_tooling_tree}",
            )
        if not project.is_ancestor(
            PREDECESSOR_SUCCESSOR_V3_TOOLING_HEAD_SHA,
            receipt.producer_tooling_head_sha,
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_SUCCESSOR_V3_TOOLING_NOT_ANCESTOR",
                receipt.producer_tooling_head_sha,
            )
    try:
        predecessor_successor_v3_resume_tree = project.tree(
            PREDECESSOR_SUCCESSOR_V3_RESUME_HEAD_SHA
        )
    except ValueError as exc:
        report.add(
            "identity_mismatches",
            "PREDECESSOR_SUCCESSOR_V3_RESUME_IDENTITY_INVALID",
            str(exc),
        )
    else:
        if (
            predecessor_successor_v3_resume_tree
            != PREDECESSOR_SUCCESSOR_V3_RESUME_TREE_SHA
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_SUCCESSOR_V3_RESUME_TREE_MISMATCH",
                "expected="
                f"{PREDECESSOR_SUCCESSOR_V3_RESUME_TREE_SHA}:"
                f"actual={predecessor_successor_v3_resume_tree}",
            )
        if not project.is_ancestor(
            PREDECESSOR_SUCCESSOR_V3_RESUME_HEAD_SHA,
            receipt.producer_tooling_head_sha,
        ):
            report.add(
                "identity_mismatches",
                "PREDECESSOR_SUCCESSOR_V3_RESUME_NOT_ANCESTOR",
                receipt.producer_tooling_head_sha,
            )

    seal, seal_bytes = _load_committed_json(
        project,
        head,
        receipt.tooling_seal_path,
        report,
        f"{receipt.step_id}.tooling_seal",
        require_canonical_bytes=True,
    )
    if seal_bytes is None:
        return
    if sha256_bytes(seal_bytes) != receipt.tooling_seal_sha256:
        report.add(
            "hash_mismatches", "TOOLING_SEAL_SHA256_MISMATCH", receipt.step_id
        )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "TOOLING_SEAL_FIELD_SET_MISMATCH",
        f"{receipt.step_id}.tooling_seal",
        seal,
        TOOLING_SEAL_FIELDS,
    ):
        return
    assert isinstance(seal, dict)
    expected_seal = {
        "schema_version": TOOLING_SEAL_SCHEMA_VERSION,
        "status": "SEALED",
        "authorization_id": AUTHORIZATION_ID,
        "base_head_sha": AUTHORIZED_BASE_HEAD_SHA,
        "base_tree_sha": project.tree(AUTHORIZED_BASE_HEAD_SHA),
        "hard_stop_record_sha256": AUTHORIZED_HARD_STOP_SHA256,
        "resume_generation_id": AUTHORIZED_GENERATION_ID,
        "resume_evidence_id": AUTHORIZED_RESUME_EVIDENCE_ID,
        "schema_sha256": receipt.schema_authority_sha256,
        "validator_sha256": receipt.validator_sha256,
        "workflow_sha256": receipt.workflow_sha256,
        "hard_stop_identity_attestation_sha256": HARD_STOP_ATTESTATION_SHA256,
        "evidence_9631_identity_attestation_sha256": EVIDENCE_9631_ATTESTATION_SHA256,
        "frozen_input_inventory_sha256": FROZEN_INPUT_INVENTORY_SHA256,
        "frozen_input_sidecar_sha256": FROZEN_INPUT_SIDECAR_SHA256,
        "required_check_context": REQUIRED_CHECK_CONTEXT,
        "post_seal_input_mutation_count": 0,
    }
    for field, expected in expected_seal.items():
        if seal.get(field) != expected or (
            field in {"resume_generation_id", "resume_evidence_id", "post_seal_input_mutation_count"}
            and not _is_exact_int(seal.get(field))
        ):
            report.add(
                "identity_mismatches",
                "TOOLING_SEAL_IDENTITY_MISMATCH",
                f"{field}:expected={expected!r}:actual={seal.get(field)!r}",
            )
    for field in (
        "selftest_sha256",
        "negative_fixture_catalog_sha256",
        "tool_dependency_inventory_sha256",
        "hard_stop_identity_attestation_sha256",
        "evidence_9631_identity_attestation_sha256",
        "frozen_input_inventory_sha256",
        "frozen_input_sidecar_sha256",
    ):
        if not _is_sha256(seal.get(field)):
            report.add("schema_failures", "TOOLING_SEAL_SHA_FIELD_INVALID", field)
    for path, field in (
        (SELFTEST_PATH, "selftest_sha256"),
        (NEGATIVE_FIXTURE_CATALOG_PATH, "negative_fixture_catalog_sha256"),
        (TOOL_DEPENDENCY_INVENTORY_PATH, "tool_dependency_inventory_sha256"),
    ):
        claimed = seal.get(field)
        if _is_sha256(claimed):
            _validate_supporting_binding(
                project,
                receipt.producer_tooling_head_sha,
                path,
                claimed,
                report,
                f"{receipt.step_id}.producer_tooling_head.{field}",
            )
            _validate_supporting_binding(
                project,
                head,
                path,
                claimed,
                report,
                f"{receipt.step_id}.evaluated_head.{field}",
            )
    selftest_bytes = _validate_supporting_binding(
        project,
        head,
        SELFTEST_PATH,
        seal.get("selftest_sha256"),
        report,
        f"{receipt.step_id}.selftest_semantic_source",
    ) if _is_sha256(seal.get("selftest_sha256")) else None
    catalog, _catalog_bytes = _load_committed_json(
        project,
        head,
        NEGATIVE_FIXTURE_CATALOG_PATH,
        report,
        f"{receipt.step_id}.negative_fixture_catalog",
        require_canonical_bytes=True,
    )
    if selftest_bytes is not None:
        _validate_negative_fixture_catalog(
            catalog,
            selftest_bytes,
            report,
            f"{receipt.step_id}.negative_fixture_catalog",
        )
    dependency_inventory, _dependency_bytes = _load_committed_json(
        project,
        head,
        TOOL_DEPENDENCY_INVENTORY_PATH,
        report,
        f"{receipt.step_id}.tool_dependency_inventory",
        require_canonical_bytes=True,
    )
    _validate_tool_dependency_inventory(
        dependency_inventory,
        report,
        f"{receipt.step_id}.tool_dependency_inventory",
    )
    _validate_frozen_identity_documents(project, head, receipt, seal, report)
    if seal.get("canonical_payload_sha256") != canonical_payload_sha256(seal):
        report.add(
            "hash_mismatches", "TOOLING_SEAL_CANONICAL_SHA256_MISMATCH", receipt.step_id
        )

    resume, resume_bytes = _load_committed_json(
        project,
        head,
        receipt.resume_authorization_manifest_path,
        report,
        f"{receipt.step_id}.resume_authorization",
        require_canonical_bytes=True,
    )
    if resume_bytes is None:
        return
    if sha256_bytes(resume_bytes) != receipt.resume_authorization_manifest_sha256:
        report.add(
            "hash_mismatches",
            "RESUME_AUTHORIZATION_SHA256_MISMATCH",
            receipt.step_id,
        )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "RESUME_AUTHORIZATION_FIELD_SET_MISMATCH",
        f"{receipt.step_id}.resume_authorization",
        resume,
        RESUME_AUTHORIZATION_FIELDS,
    ):
        return
    assert isinstance(resume, dict)
    expected_resume = {
        "schema_version": RESUME_AUTHORIZATION_SCHEMA_VERSION,
        "status": "SEALED",
        "authorization_id": AUTHORIZATION_ID,
        "authorized_base_head": AUTHORIZED_BASE_HEAD_SHA,
        "current_tooling_head": receipt.producer_tooling_head_sha,
        "current_tooling_tree": receipt.producer_tooling_tree_sha,
        "hard_stop_record_sha256": AUTHORIZED_HARD_STOP_SHA256,
        "resume_generation_id": AUTHORIZED_GENERATION_ID,
        "resume_evidence_id": AUTHORIZED_RESUME_EVIDENCE_ID,
        "schema_sha256": receipt.schema_authority_sha256,
        "validator_sha256": receipt.validator_sha256,
        "workflow_sha256": receipt.workflow_sha256,
        "tooling_seal_sha256": receipt.tooling_seal_sha256,
        "selftest_sha256": seal.get("selftest_sha256"),
        "current_product_subject_head": CURRENT_SUBJECT_HEAD_SHA,
        "current_product_subject_tree": CURRENT_SUBJECT_TREE_SHA,
        "product_path_manifest_sha256": CURRENT_SUBJECT_MANIFEST_SHA256,
        "existing_generation7_evidence_inventory_sha256": FROZEN_EVIDENCE_INVENTORY_SHA256,
        "formal_resume_count": 1,
        "automatic_retry": False,
    }
    for field, expected in expected_resume.items():
        if resume.get(field) != expected or (
            field in {"resume_generation_id", "resume_evidence_id", "formal_resume_count"}
            and not _is_exact_int(resume.get(field))
        ) or (field == "automatic_retry" and not _is_exact_bool(resume.get(field))):
            report.add(
                "identity_mismatches",
                "RESUME_AUTHORIZATION_IDENTITY_MISMATCH",
                f"{field}:expected={expected!r}:actual={resume.get(field)!r}",
            )
    for field in ("audit_a_sha256", "audit_b_sha256"):
        if not _is_sha256(resume.get(field)):
            report.add(
                "schema_failures", "RESUME_AUTHORIZATION_AUDIT_SHA_INVALID", field
            )
    audit_specs = (
        (
            AUDIT_A_PATH,
            "audit_a_sha256",
            "AUDIT_A",
            "RECEIPT_SCHEMA_AND_VALIDATOR_SAFETY",
        ),
        (
            AUDIT_B_PATH,
            "audit_b_sha256",
            "AUDIT_B",
            "REQUIRED_WORKFLOW_ENFORCEMENT",
        ),
    )
    for path, field, audit_id, audit_scope in audit_specs:
        claimed = resume.get(field)
        if _is_sha256(claimed):
            _validate_supporting_binding(
                project,
                receipt.producer_tooling_head_sha,
                path,
                claimed,
                report,
                f"{receipt.step_id}.producer_tooling_head.{field}",
            )
            _validate_supporting_binding(
                project,
                head,
                path,
                claimed,
                report,
                f"{receipt.step_id}.evaluated_head.{field}",
            )
            audit, _audit_bytes = _load_committed_json(
                project,
                head,
                path,
                report,
                f"{receipt.step_id}.{audit_id.lower()}",
                require_canonical_bytes=True,
            )
            _validate_independent_audit(
                audit,
                audit_id,
                audit_scope,
                receipt,
                seal.get("selftest_sha256"),
                report,
                f"{receipt.step_id}.{audit_id.lower()}",
            )
    _validate_resume_checkpoint(
        resume, report, f"{receipt.step_id}.resume_authorization"
    )
    if resume.get("canonical_payload_sha256") != canonical_payload_sha256(resume):
        report.add(
            "hash_mismatches",
            "RESUME_AUTHORIZATION_CANONICAL_SHA256_MISMATCH",
            receipt.step_id,
        )


def _generation7_receipt_chain_projection(
    receipt_rows: Sequence[tuple[str, str, str, str]],
) -> dict[str, Any]:
    return {
        "derivation": GENERATION7_SUMMARY_DERIVATION,
        "generation_id": AUTHORIZED_GENERATION_ID,
        "resume_evidence_id": AUTHORIZED_RESUME_EVIDENCE_ID,
        "receipts": [
            {"step_id": step_id, "path": path, "sha256": digest, "status": status}
            for step_id, path, digest, status in receipt_rows
        ],
    }


def _validate_generation7_frozen_receipt_chain(
    project: GitCommittedProject,
    head: str,
    report: ValidationReport,
) -> tuple[str | None, list[tuple[str, str, str, str]]]:
    rows: list[tuple[str, str, str, str]] = []
    previous_raw: bytes | None = None
    for step_id, path in REQUIRED_RECEIPT_SPECS:
        value, raw = _load_committed_json(
            project,
            head,
            path,
            report,
            f"generation7_frozen.{step_id}.receipt",
            require_canonical_bytes=True,
        )
        if not isinstance(value, dict) or raw is None:
            continue
        actual_sha = sha256_bytes(raw)
        expected_sha = GENERATION7_FROZEN_RECEIPT_SHA256_BY_STEP[step_id]
        if actual_sha != expected_sha:
            report.add(
                "hash_mismatches",
                "GENERATION7_FROZEN_RECEIPT_SHA256_MISMATCH",
                f"{step_id}:expected={expected_sha}:actual={actual_sha}",
            )
        expected_status = GENERATION7_FROZEN_RECEIPT_STATUS_BY_STEP[step_id]
        if value.get("status") != expected_status:
            report.add(
                "identity_mismatches",
                "GENERATION7_FROZEN_RECEIPT_STATUS_MISMATCH",
                f"{step_id}:expected={expected_status}:actual={value.get('status')!r}",
            )
        if value.get("generation_id") != AUTHORIZED_GENERATION_ID:
            report.add(
                "identity_mismatches",
                "GENERATION7_FROZEN_RECEIPT_GENERATION_MISMATCH",
                step_id,
            )
        if value.get("resume_evidence_id") != AUTHORIZED_RESUME_EVIDENCE_ID:
            report.add(
                "identity_mismatches",
                "GENERATION7_FROZEN_RECEIPT_EVIDENCE_ID_MISMATCH",
                step_id,
            )
        expected_previous = None if previous_raw is None else sha256_bytes(previous_raw)
        if value.get("previous_receipt_sha256") != expected_previous:
            report.add(
                "hash_mismatches",
                "GENERATION7_FROZEN_RECEIPT_CHAIN_MISMATCH",
                f"{step_id}:expected={expected_previous}:actual={value.get('previous_receipt_sha256')}",
            )
        previous_raw = raw
        rows.append((step_id, path, actual_sha, str(value.get("status"))))
    if len(rows) != len(REQUIRED_RECEIPT_SPECS):
        report.add(
            "field_mismatches",
            "GENERATION7_FROZEN_RECEIPT_COUNT_MISMATCH",
            f"expected={len(REQUIRED_RECEIPT_SPECS)}:actual={len(rows)}",
        )
        return None, rows
    projection = _generation7_receipt_chain_projection(rows)
    report.generation7_step11_receipt_status = rows[1][3]
    return sha256_bytes(canonical_json_bytes(projection)), rows


def _load_generation8_registry_state(
    project: GitCommittedProject,
    head: str,
    report: ValidationReport,
) -> tuple[list[str], int | None]:
    index_sha256s: list[str] = []
    evidence_ids: list[int] = []
    for path in GENERATION8_REGISTRY_INDEX_PATHS:
        value, raw = _load_committed_json(
            project,
            head,
            path,
            report,
            f"generation8.registry.{path}",
            require_canonical_bytes=True,
        )
        if not isinstance(value, dict) or raw is None:
            continue
        index_sha256s.append(sha256_bytes(raw))
        if value.get("generation_id") != GENERATION8_PARENT_ID:
            report.add(
                "identity_mismatches",
                "GENERATION8_REGISTRY_PARENT_GENERATION_MISMATCH",
                path,
            )
        if value.get("resume_evidence_id") != GENERATION8_PARENT_EVIDENCE_ID:
            report.add(
                "identity_mismatches",
                "GENERATION8_REGISTRY_PARENT_EVIDENCE_ID_MISMATCH",
                path,
            )
        if value.get("append_only") is not True or not _is_exact_bool(
            value.get("append_only")
        ):
            report.add(
                "identity_mismatches", "GENERATION8_REGISTRY_NOT_APPEND_ONLY", path
            )
        if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
            report.add(
                "hash_mismatches", "GENERATION8_REGISTRY_CANONICAL_SHA_MISMATCH", path
            )
        artifacts = value.get("source_artifacts")
        if not isinstance(artifacts, list) or not artifacts:
            report.add(
                "schema_failures", "GENERATION8_REGISTRY_ARTIFACTS_INVALID", path
            )
            continue
        if value.get("source_artifact_count") != len(artifacts) or not _is_exact_int(
            value.get("source_artifact_count")
        ):
            report.add(
                "field_mismatches", "GENERATION8_REGISTRY_COUNT_MISMATCH", path
            )
        for artifact in artifacts:
            if not isinstance(artifact, dict) or not _is_exact_int(
                artifact.get("evidence_id")
            ):
                report.add(
                    "schema_failures", "GENERATION8_REGISTRY_EVIDENCE_ID_INVALID", path
                )
                continue
            evidence_ids.append(artifact["evidence_id"])
    if len(index_sha256s) != len(GENERATION8_REGISTRY_INDEX_PATHS) or not evidence_ids:
        return index_sha256s, None
    return index_sha256s, max(evidence_ids)


def _validate_generation8_authorization_value(
    value: Any,
    report: ValidationReport,
    *,
    parent_summary_sha256: str,
    registry_sha256s: Sequence[str],
    registry_max_evidence_id: int,
    tooling_head_sha: str,
    tooling_tree_sha: str,
    product_subject_head_sha: str,
    product_subject_tree_sha: str,
) -> dict[str, Any] | None:
    label = "generation8.authorization_manifest"
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_AUTHORIZATION_FIELD_SET_MISMATCH",
        label,
        value,
        GENERATION8_AUTHORIZATION_FIELDS,
    ):
        return None
    assert isinstance(value, dict)
    expected = {
        "schema_version": GENERATION8_AUTHORIZATION_SCHEMA_VERSION,
        "status": "SEALED",
        "authorization_id": GENERATION8_AUTHORIZATION_ID,
        "generation_id": GENERATION8_ID,
        "parent_generation_id": GENERATION8_PARENT_ID,
        "parent_generation7_summary_sha256": parent_summary_sha256,
        "parent_generation7_summary_derivation": GENERATION7_SUMMARY_DERIVATION,
        "parent_step09_receipt_sha256": GENERATION7_FROZEN_RECEIPT_SHA256_BY_STEP["STEP09"],
        "parent_step11_blocked_receipt_sha256": GENERATION7_FROZEN_RECEIPT_SHA256_BY_STEP["STEP11"],
        "parent_step12_receipt_sha256": GENERATION7_FROZEN_RECEIPT_SHA256_BY_STEP["STEP12"],
        "parent_evidence_id": GENERATION8_PARENT_EVIDENCE_ID,
        "evidence_registry_index_paths": list(GENERATION8_REGISTRY_INDEX_PATHS),
        "evidence_registry_index_sha256s": list(registry_sha256s),
        "evidence_registry_max_evidence_id": registry_max_evidence_id,
        "new_evidence_id": registry_max_evidence_id + 1,
        "evidence_id_derivation": GENERATION8_EVIDENCE_ID_DERIVATION,
        # Commit P owns only the MCP-landed Godot product/test delta. Commit A
        # owns tooling and pre-formal evidence, and is the exact parent of the
        # authorization-only Commit B. Keep those identities independent so
        # neither an authorization manifest nor an MCP landing attestation has
        # to claim the SHA of the commit that contains itself.
        "product_subject_head_sha": product_subject_head_sha,
        "product_subject_tree_sha": product_subject_tree_sha,
        "live_pr_head_sha": tooling_head_sha,
        "live_pr_tree_sha": tooling_tree_sha,
        "player_count": 4,
        "new_game_profile": {
            "geography_complexity": "STANDARD",
            "land_ocean_profile": "BALANCED",
            "region_count": 16,
        },
        "major_round_contract_path": GENERATION8_MAJOR_ROUND_CONTRACT_PATH,
        "product_path_manifest_path": GENERATION8_PRODUCT_PATH_MANIFEST_PATH,
        "receipt_schema_path": SCHEMA_AUTHORITY_PATH,
        "receipt_validator_path": VALIDATOR_PATH,
        "required_workflow_path": WORKFLOW_PATH,
        "receipt_selftest_path": SELFTEST_PATH,
        "focused_test_report_path": GENERATION8_FOCUSED_TEST_REPORT_PATH,
        "characterization_report_path": GENERATION8_CHARACTERIZATION_PATH,
        "generation8_tooling_seal_path": GENERATION8_TOOLING_SEAL_PATH,
        "formal_execution_count": 1,
        "automatic_retry": False,
    }
    for field, expected_value in expected.items():
        actual = value.get(field)
        if actual != expected_value:
            report.add(
                "identity_mismatches",
                "GENERATION8_AUTHORIZATION_IDENTITY_MISMATCH",
                f"{field}:expected={expected_value!r}:actual={actual!r}",
            )
    for field in (
        "generation_id",
        "parent_generation_id",
        "parent_evidence_id",
        "evidence_registry_max_evidence_id",
        "new_evidence_id",
        "selected_seed",
        "player_count",
        "formal_execution_count",
    ):
        if not _is_exact_int(value.get(field)):
            report.add(
                "schema_failures", "GENERATION8_AUTHORIZATION_INTEGER_INVALID", field
            )
    if not _is_exact_bool(value.get("automatic_retry")):
        report.add(
            "schema_failures",
            "GENERATION8_AUTHORIZATION_BOOLEAN_INVALID",
            "automatic_retry",
        )
    if not _is_exact_int(value.get("selected_seed")) or value.get("selected_seed", 0) <= 0:
        report.add(
            "field_mismatches", "GENERATION8_AUTHORIZATION_SEED_INVALID", repr(value.get("selected_seed"))
        )
    for field in (
        "parent_generation7_summary_sha256",
        "parent_step09_receipt_sha256",
        "parent_step11_blocked_receipt_sha256",
        "parent_step12_receipt_sha256",
        "product_path_manifest_sha256",
        "mcp_landing_manifest_sha256",
        "major_round_contract_sha256",
        "receipt_schema_sha256",
        "receipt_validator_sha256",
        "required_workflow_sha256",
        "receipt_selftest_sha256",
        "focused_test_report_sha256",
        "characterization_report_sha256",
        "generation8_tooling_seal_sha256",
        "canonical_payload_sha256",
    ):
        if not _is_sha256(value.get(field)):
            report.add(
                "schema_failures", "GENERATION8_AUTHORIZATION_SHA256_INVALID", field
            )
    if value.get("receipt_schema_sha256") != value.get("receipt_validator_sha256"):
        report.add(
            "identity_mismatches",
            "GENERATION8_SCHEMA_VALIDATOR_AUTHORITY_SPLIT",
            "receipt schema and validator hashes differ",
        )
    try:
        parse_rfc3339_utc(value.get("created_at_utc"))
    except ValueError:
        report.add(
            "schema_failures",
            "GENERATION8_AUTHORIZATION_TIMESTAMP_INVALID",
            repr(value.get("created_at_utc")),
        )
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add(
            "hash_mismatches",
            "GENERATION8_AUTHORIZATION_CANONICAL_SHA256_MISMATCH",
            label,
        )
    return value


def _validate_generation8_tooling_seal(
    project: GitCommittedProject,
    tooling_head: str,
    product_subject_head: str,
    manifest: Mapping[str, Any],
    report: ValidationReport,
) -> None:
    value, raw = _load_committed_json(
        project,
        tooling_head,
        GENERATION8_TOOLING_SEAL_PATH,
        report,
        "generation8.tooling_seal",
        require_canonical_bytes=True,
    )
    if raw is None:
        return
    if sha256_bytes(raw) != manifest.get("generation8_tooling_seal_sha256"):
        report.add(
            "hash_mismatches",
            "GENERATION8_TOOLING_SEAL_SHA256_MISMATCH",
            GENERATION8_TOOLING_SEAL_PATH,
        )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_TOOLING_SEAL_FIELD_SET_MISMATCH",
        "generation8.tooling_seal",
        value,
        GENERATION8_TOOLING_SEAL_FIELDS,
    ):
        return
    assert isinstance(value, dict)
    generation8_mcp_delta = [
        path
        for _status, path in project.changed_entries(
            GENERATION7_ARTIFACT_HEAD_SHA, product_subject_head
        )
        if is_generation8_mcp_mutation_path(path)
    ]
    expected = {
        "schema_version": GENERATION8_TOOLING_SEAL_SCHEMA_VERSION,
        "status": "SEALED",
        "authorization_id": GENERATION8_AUTHORIZATION_ID,
        "generation_id": GENERATION8_ID,
        "base_head_sha": GENERATION7_ARTIFACT_HEAD_SHA,
        "base_tree_sha": project.tree(GENERATION7_ARTIFACT_HEAD_SHA),
        "receipt_schema_path": SCHEMA_AUTHORITY_PATH,
        "receipt_schema_sha256": manifest.get("receipt_schema_sha256"),
        "receipt_validator_path": VALIDATOR_PATH,
        "receipt_validator_sha256": manifest.get("receipt_validator_sha256"),
        "receipt_selftest_path": SELFTEST_PATH,
        "receipt_selftest_sha256": manifest.get("receipt_selftest_sha256"),
        "required_workflow_path": WORKFLOW_PATH,
        "required_workflow_sha256": manifest.get("required_workflow_sha256"),
        "negative_fixture_catalog_path": GENERATION8_NEGATIVE_FIXTURE_CATALOG_PATH,
        "focused_test_report_path": GENERATION8_FOCUSED_TEST_REPORT_PATH,
        "focused_test_report_sha256": manifest.get("focused_test_report_sha256"),
        "characterization_report_path": GENERATION8_CHARACTERIZATION_PATH,
        "characterization_report_sha256": manifest.get("characterization_report_sha256"),
        "major_round_contract_path": GENERATION8_MAJOR_ROUND_CONTRACT_PATH,
        "major_round_contract_sha256": manifest.get("major_round_contract_sha256"),
        "product_file_change_count": len(generation8_mcp_delta),
        "direct_filesystem_product_edit_count": 0,
        "post_seal_input_mutation_count": 0,
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            report.add(
                "identity_mismatches",
                "GENERATION8_TOOLING_SEAL_IDENTITY_MISMATCH",
                f"{field}:expected={expected_value!r}:actual={value.get(field)!r}",
            )
    for path_field, sha_field in (
        ("receipt_schema_path", "receipt_schema_sha256"),
        ("receipt_validator_path", "receipt_validator_sha256"),
        ("receipt_selftest_path", "receipt_selftest_sha256"),
        ("required_workflow_path", "required_workflow_sha256"),
        ("negative_fixture_catalog_path", "negative_fixture_catalog_sha256"),
        ("focused_test_report_path", "focused_test_report_sha256"),
        ("characterization_report_path", "characterization_report_sha256"),
        ("major_round_contract_path", "major_round_contract_sha256"),
    ):
        path = value.get(path_field)
        claimed = value.get(sha_field)
        if isinstance(path, str) and _is_sha256(claimed):
            _validate_supporting_binding(
                project,
                tooling_head,
                path,
                claimed,
                report,
                f"generation8.tooling_seal.{sha_field}",
            )
        else:
            report.add(
                "schema_failures",
                "GENERATION8_TOOLING_SEAL_BINDING_INVALID",
                f"{path_field}/{sha_field}",
            )
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add(
            "hash_mismatches",
            "GENERATION8_TOOLING_SEAL_CANONICAL_SHA256_MISMATCH",
            GENERATION8_TOOLING_SEAL_PATH,
        )


def _validate_generation8_mcp_landing(
    project: GitCommittedProject,
    tooling_head: str,
    product_subject_head: str,
    manifest: Mapping[str, Any],
    report: ValidationReport,
) -> set[str]:
    landing, raw = _load_committed_json(
        project,
        tooling_head,
        GENERATION8_MCP_LANDING_MANIFEST_PATH,
        report,
        "generation8.mcp_landing_manifest",
        require_canonical_bytes=True,
    )
    if not isinstance(landing, dict) or raw is None:
        return set()
    if sha256_bytes(raw) != manifest.get("mcp_landing_manifest_sha256"):
        report.add(
            "hash_mismatches",
            "GENERATION8_MCP_LANDING_SHA256_MISMATCH",
            GENERATION8_MCP_LANDING_MANIFEST_PATH,
        )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_MCP_LANDING_FIELD_SET_MISMATCH",
        "generation8.mcp_landing_manifest",
        landing,
        MCP_LANDING_FIELDS,
    ):
        return set()
    expected = {
        "schema_version": "space_syndicate.v076.mcp_product_landing_attestation.v1",
        "generation_id": GENERATION8_ID,
        "resume_evidence_id": manifest.get("new_evidence_id"),
        "subject_head_sha": GENERATION7_ARTIFACT_HEAD_SHA,
        "subject_tree_sha": project.tree(GENERATION7_ARTIFACT_HEAD_SHA),
        "execution_head_sha": product_subject_head,
        "execution_tree_sha": project.tree(product_subject_head),
        "mcp_tool_identity": REQUIRED_MCP_TOOL_IDENTITY,
        "mcp_protocol_version": REQUIRED_MCP_PROTOCOL_VERSION,
        "production_scene_path": "res://scenes/main.tscn",
        "real_main_tscn_validation": "PASS_RUNTIME_OBSERVED",
        "direct_filesystem_product_edit_count": 0,
        "mcp_product_file_mutation_coverage_percent": 100,
        "mcp_post_edit_validation_coverage_percent": 100,
    }
    for field, expected_value in expected.items():
        if landing.get(field) != expected_value:
            report.add(
                "identity_mismatches",
                "GENERATION8_MCP_LANDING_IDENTITY_MISMATCH",
                f"{field}:expected={expected_value!r}:actual={landing.get(field)!r}",
            )
    mutations = landing.get("product_file_mutations")
    if not isinstance(mutations, list):
        report.add(
            "schema_failures",
            "GENERATION8_MCP_LANDING_MUTATIONS_NOT_ARRAY",
            GENERATION8_MCP_LANDING_MANIFEST_PATH,
        )
        return set()
    for field in (
        "product_file_change_count",
        "mcp_product_file_mutation_count",
        "mcp_post_edit_validation_count",
    ):
        if not _is_exact_int(landing.get(field)) or landing[field] != len(mutations):
            report.add(
                "field_mismatches",
                "GENERATION8_MCP_LANDING_COUNT_MISMATCH",
                f"{field}:{landing.get(field)!r}:{len(mutations)}",
            )
    changed_status = {
        path: status
        for status, path in project.changed_entries(
            GENERATION7_ARTIFACT_HEAD_SHA, product_subject_head
        )
        if is_generation8_mcp_mutation_path(path)
    }
    mutation_paths: list[str] = []
    for index, mutation in enumerate(mutations):
        label = f"generation8.mcp_landing.product_file_mutations[{index}]"
        if not _compare_exact_keys(
            report,
            "schema_failures",
            "GENERATION8_MCP_LANDING_MUTATION_FIELD_SET_MISMATCH",
            label,
            mutation,
            MCP_LANDING_MUTATION_FIELDS,
        ):
            continue
        assert isinstance(mutation, dict)
        try:
            path = normalize_repo_relative_path(mutation.get("path"))
        except ValueError as exc:
            report.add(
                "path_failures",
                "GENERATION8_MCP_LANDING_PATH_INVALID",
                f"{label}:{exc}",
            )
            continue
        if not is_generation8_mcp_mutation_path(path):
            report.add(
                "path_failures", "GENERATION8_MCP_LANDING_NON_GODOT_PATH", path
            )
            continue
        mutation_paths.append(path)
        change_type = mutation.get("change_type")
        if change_type not in {"A", "M", "D"} or changed_status.get(path) != change_type:
            report.add(
                "identity_mismatches",
                "GENERATION8_MCP_LANDING_CHANGE_TYPE_MISMATCH",
                f"{path}:declared={change_type}:actual={changed_status.get(path)}",
            )
        before = mutation.get("before_sha256")
        after = mutation.get("after_sha256")
        if change_type == "A":
            hashes_valid = before is None and _is_sha256(after)
        elif change_type == "D":
            hashes_valid = _is_sha256(before) and after is None
        else:
            hashes_valid = _is_sha256(before) and _is_sha256(after)
        if not hashes_valid:
            report.add(
                "schema_failures", "GENERATION8_MCP_LANDING_HASH_INVALID", path
            )
        if change_type in {"M", "D"} and _is_sha256(before):
            try:
                if sha256_bytes(project.read_regular_file(
                    GENERATION7_ARTIFACT_HEAD_SHA, path
                )) != before:
                    report.add(
                        "hash_mismatches",
                        "GENERATION8_MCP_LANDING_BEFORE_HASH_MISMATCH",
                        path,
                    )
            except (ValueError, CommittedPathError) as exc:
                report.add(
                    "path_failures",
                    "GENERATION8_MCP_LANDING_BEFORE_FILE_UNAVAILABLE",
                    f"{path}:{exc}",
                )
        if change_type in {"A", "M"} and _is_sha256(after):
            try:
                if sha256_bytes(
                    project.read_regular_file(product_subject_head, path)
                ) != after:
                    report.add(
                        "hash_mismatches",
                        "GENERATION8_MCP_LANDING_AFTER_HASH_MISMATCH",
                        path,
                    )
            except (ValueError, CommittedPathError) as exc:
                report.add(
                    "path_failures",
                    "GENERATION8_MCP_LANDING_AFTER_FILE_UNAVAILABLE",
                    f"{path}:{exc}",
                )
        if not isinstance(mutation.get("mcp_operation_id"), str) or not str(
            mutation.get("mcp_operation_id", "")
        ).strip():
            report.add(
                "schema_failures",
                "GENERATION8_MCP_LANDING_OPERATION_ID_MISSING",
                path,
            )
        if mutation.get("validation_status") != "PASS":
            report.add(
                "field_mismatches",
                "GENERATION8_MCP_LANDING_VALIDATION_NOT_PASS",
                path,
            )
    if mutation_paths != sorted(mutation_paths) or len(mutation_paths) != len(
        set(mutation_paths)
    ):
        report.add(
            "schema_failures",
            "GENERATION8_MCP_LANDING_PATH_SET_NOT_SORTED_UNIQUE",
            repr(mutation_paths),
        )
    if mutation_paths != sorted(changed_status):
        report.add(
            "identity_mismatches",
            "GENERATION8_MCP_LANDING_PRODUCT_DELTA_MISMATCH",
            f"declared={mutation_paths}:actual={sorted(changed_status)}",
        )
    if landing.get("canonical_payload_sha256") != canonical_payload_sha256(landing):
        report.add(
            "hash_mismatches",
            "GENERATION8_MCP_LANDING_CANONICAL_SHA256_MISMATCH",
            GENERATION8_MCP_LANDING_MANIFEST_PATH,
        )
    return set(mutation_paths)


def _validate_generation8_receipt_schema(
    report: ValidationReport,
    value: Any,
    label: str,
    manifest: Mapping[str, Any],
) -> V076CurrentSubjectProductionRevalidationReceiptV1 | None:
    return _validate_receipt_schema(
        report,
        value,
        label,
        expected_authorization_id=GENERATION8_AUTHORIZATION_ID,
        expected_generation_id=GENERATION8_ID,
        expected_evidence_id=(
            manifest.get("new_evidence_id")
            if _is_exact_int(manifest.get("new_evidence_id"))
            else -1
        ),
        expected_subject_head_sha=str(manifest.get("product_subject_head_sha", "")),
        expected_subject_tree_sha=str(manifest.get("product_subject_tree_sha", "")),
        expected_product_manifest_path=str(
            manifest.get("product_path_manifest_path", "")
        ),
        expected_product_manifest_sha256=str(
            manifest.get("product_path_manifest_sha256", "")
        ),
        expected_tooling_seal_path=GENERATION8_TOOLING_SEAL_PATH,
        expected_authorization_manifest_path=GENERATION8_AUTHORIZATION_MANIFEST_PATH,
        expected_proof_fields=GENERATION8_STEP11_PROOF_FIELDS,
    )


def _validate_generation8_parent_receipt_binding(
    receipt: V076CurrentSubjectProductionRevalidationReceiptV1,
    report: ValidationReport,
) -> None:
    expected = GENERATION7_FROZEN_RECEIPT_SHA256_BY_STEP["STEP11"]
    if receipt.previous_receipt_sha256 != expected:
        report.add(
            "hash_mismatches",
            "GENERATION8_PARENT_RECEIPT_CHAIN_MISMATCH",
            f"expected={expected}:actual={receipt.previous_receipt_sha256}",
        )


def _validate_generation8_evidence_manifest(
    project: GitCommittedProject,
    head: str,
    receipt: V076CurrentSubjectProductionRevalidationReceiptV1,
    manifest: Mapping[str, Any],
    report: ValidationReport,
) -> set[str]:
    allowlist = {GENERATION8_STEP11_EVIDENCE_MANIFEST_PATH}
    value, raw = _load_committed_json(
        project,
        head,
        GENERATION8_STEP11_EVIDENCE_MANIFEST_PATH,
        report,
        "generation8.step11.evidence_manifest",
        require_canonical_bytes=True,
    )
    if raw is None or not isinstance(value, dict):
        return allowlist
    if receipt.evidence_manifest_path != GENERATION8_STEP11_EVIDENCE_MANIFEST_PATH:
        report.add(
            "path_failures",
            "GENERATION8_EVIDENCE_MANIFEST_PATH_MISMATCH",
            receipt.evidence_manifest_path,
        )
    if receipt.evidence_manifest_sha256 != sha256_bytes(raw):
        report.add(
            "hash_mismatches",
            "GENERATION8_EVIDENCE_MANIFEST_SHA256_MISMATCH",
            GENERATION8_STEP11_EVIDENCE_MANIFEST_PATH,
        )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_EVIDENCE_MANIFEST_FIELD_SET_MISMATCH",
        "generation8.step11.evidence_manifest",
        value,
        EVIDENCE_MANIFEST_FIELDS,
    ):
        return allowlist
    expected = {
        "schema_version": GENERATION8_EVIDENCE_MANIFEST_SCHEMA_VERSION,
        "generation_id": GENERATION8_ID,
        "resume_evidence_id": manifest.get("new_evidence_id"),
        "receipt_id": receipt.receipt_id,
        "evidence_root": f"{GENERATION8_FORMAL_ROOT}/evidence",
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            report.add(
                "identity_mismatches",
                "GENERATION8_EVIDENCE_MANIFEST_IDENTITY_MISMATCH",
                f"{field}:expected={expected_value!r}:actual={value.get(field)!r}",
            )
    artifacts = value.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        report.add(
            "schema_failures",
            "GENERATION8_EVIDENCE_ARTIFACT_SET_EMPTY",
            GENERATION8_STEP11_EVIDENCE_MANIFEST_PATH,
        )
        artifacts = []
    if value.get("artifact_count") != len(artifacts) or not _is_exact_int(
        value.get("artifact_count")
    ):
        report.add(
            "field_mismatches",
            "GENERATION8_EVIDENCE_ARTIFACT_COUNT_MISMATCH",
            repr(value.get("artifact_count")),
        )
    paths: list[str] = []
    evidence_root = f"{GENERATION8_FORMAL_ROOT}/evidence"
    for index, artifact in enumerate(artifacts):
        label = f"generation8.step11.evidence_manifest.artifacts[{index}]"
        if not _compare_exact_keys(
            report,
            "schema_failures",
            "GENERATION8_EVIDENCE_ARTIFACT_FIELD_SET_MISMATCH",
            label,
            artifact,
            EVIDENCE_ARTIFACT_FIELDS,
        ):
            continue
        assert isinstance(artifact, dict)
        try:
            path = normalize_repo_relative_path(artifact.get("path"))
        except ValueError as exc:
            report.add("path_failures", "GENERATION8_EVIDENCE_PATH_INVALID", f"{label}:{exc}")
            continue
        if not path.startswith(evidence_root + "/"):
            report.add(
                "path_failures",
                "GENERATION8_EVIDENCE_PATH_OUTSIDE_ROOT",
                path,
            )
            continue
        paths.append(path)
        allowlist.add(path)
        if not _is_sha256(artifact.get("sha256")) or not _is_exact_int(
            artifact.get("size_bytes")
        ) or artifact.get("size_bytes", -1) < 0:
            report.add(
                "schema_failures", "GENERATION8_EVIDENCE_ARTIFACT_BINDING_INVALID", label
            )
            continue
        try:
            data = project.read_regular_file(head, path)
        except (ValueError, CommittedPathError) as exc:
            report.add("path_failures", "GENERATION8_EVIDENCE_FILE_UNAVAILABLE", f"{label}:{exc}")
            continue
        if sha256_bytes(data) != artifact["sha256"]:
            report.add("hash_mismatches", "GENERATION8_EVIDENCE_FILE_SHA256_MISMATCH", path)
        if len(data) != artifact["size_bytes"]:
            report.add("field_mismatches", "GENERATION8_EVIDENCE_FILE_SIZE_MISMATCH", path)
    if paths != sorted(paths) or len(paths) != len(set(paths)):
        report.add(
            "schema_failures",
            "GENERATION8_EVIDENCE_PATH_SET_NOT_SORTED_UNIQUE",
            repr(paths),
        )
    for required_path in (
        GENERATION8_RUNTIME_EVIDENCE_PATH,
        GENERATION8_SOURCE_EVIDENCE_INDEX_PATH,
    ):
        if required_path not in allowlist:
            report.add(
                "path_failures", "GENERATION8_REQUIRED_EVIDENCE_NOT_MANIFESTED", required_path
            )
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add(
            "hash_mismatches",
            "GENERATION8_EVIDENCE_MANIFEST_CANONICAL_SHA256_MISMATCH",
            GENERATION8_STEP11_EVIDENCE_MANIFEST_PATH,
        )
    return allowlist


def _validate_generation8_source_evidence_index(
    project: GitCommittedProject,
    head: str,
    manifest: Mapping[str, Any],
    evidence_allowlist: set[str],
    report: ValidationReport,
) -> None:
    value, _raw = _load_committed_json(
        project,
        head,
        GENERATION8_SOURCE_EVIDENCE_INDEX_PATH,
        report,
        "generation8.source_evidence_index",
        require_canonical_bytes=True,
    )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_SOURCE_INDEX_FIELD_SET_MISMATCH",
        "generation8.source_evidence_index",
        value,
        GENERATION8_SOURCE_EVIDENCE_INDEX_FIELDS,
    ):
        return
    assert isinstance(value, dict)
    expected = {
        "schema_version": "space_syndicate.v076.generation8_source_evidence_index.v1",
        "append_only": True,
        "generation_id": GENERATION8_ID,
        "new_evidence_id": manifest.get("new_evidence_id"),
        "formal_attempt_id": "formal-attempt-001",
        "formal_execution_count": 1,
        "automatic_retry_count": 0,
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            report.add(
                "identity_mismatches",
                "GENERATION8_SOURCE_INDEX_IDENTITY_MISMATCH",
                f"{field}:expected={expected_value!r}:actual={value.get(field)!r}",
            )
    artifacts = value.get("source_artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        report.add("schema_failures", "GENERATION8_SOURCE_ARTIFACT_SET_EMPTY", repr(artifacts))
        artifacts = []
    if value.get("source_artifact_count") != len(artifacts) or not _is_exact_int(
        value.get("source_artifact_count")
    ):
        report.add("field_mismatches", "GENERATION8_SOURCE_ARTIFACT_COUNT_MISMATCH", repr(value.get("source_artifact_count")))
    paths: list[str] = []
    for index, artifact in enumerate(artifacts):
        label = f"generation8.source_artifacts[{index}]"
        if not _compare_exact_keys(
            report,
            "schema_failures",
            "GENERATION8_SOURCE_ARTIFACT_FIELD_SET_MISMATCH",
            label,
            artifact,
            GENERATION8_SOURCE_EVIDENCE_ARTIFACT_FIELDS,
        ):
            continue
        assert isinstance(artifact, dict)
        path = artifact.get("path")
        if not isinstance(path, str) or path not in evidence_allowlist:
            report.add("path_failures", "GENERATION8_SOURCE_ARTIFACT_NOT_MANIFESTED", repr(path))
            continue
        if path in {GENERATION8_RUNTIME_EVIDENCE_PATH, GENERATION8_SOURCE_EVIDENCE_INDEX_PATH}:
            report.add("path_failures", "GENERATION8_SOURCE_ARTIFACT_NOT_RAW", path)
        paths.append(path)
        if not _is_sha256(artifact.get("sha256")) or not _is_exact_int(artifact.get("size_bytes")):
            report.add("schema_failures", "GENERATION8_SOURCE_ARTIFACT_BINDING_INVALID", label)
            continue
        data = _validate_supporting_binding(
            project,
            head,
            path,
            artifact["sha256"],
            report,
            label,
        )
        if data is not None and len(data) != artifact["size_bytes"]:
            report.add("field_mismatches", "GENERATION8_SOURCE_ARTIFACT_SIZE_MISMATCH", path)
    if paths != sorted(paths) or len(paths) != len(set(paths)):
        report.add("schema_failures", "GENERATION8_SOURCE_ARTIFACT_PATHS_NOT_SORTED_UNIQUE", repr(paths))
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add("hash_mismatches", "GENERATION8_SOURCE_INDEX_CANONICAL_SHA256_MISMATCH", GENERATION8_SOURCE_EVIDENCE_INDEX_PATH)


def _generation8_witness_fingerprint(value: Mapping[str, Any]) -> str:
    payload = dict(value)
    payload.pop("witness_fingerprint", None)
    return sha256_bytes(canonical_json_bytes(payload))


def _validate_generation8_runtime_evidence(
    project: GitCommittedProject,
    head: str,
    receipt: V076CurrentSubjectProductionRevalidationReceiptV1,
    manifest: Mapping[str, Any],
    authorization_sha256: str,
    runtime_binding_sha256: Mapping[str, str],
    evidence_allowlist: set[str],
    report: ValidationReport,
) -> None:
    if receipt.mcp_runtime_evidence_path != GENERATION8_RUNTIME_EVIDENCE_PATH:
        report.add(
            "path_failures",
            "GENERATION8_RUNTIME_EVIDENCE_PATH_MISMATCH",
            repr(receipt.mcp_runtime_evidence_path),
        )
    if GENERATION8_RUNTIME_EVIDENCE_PATH not in evidence_allowlist:
        report.add(
            "path_failures",
            "GENERATION8_RUNTIME_EVIDENCE_NOT_MANIFESTED",
            GENERATION8_RUNTIME_EVIDENCE_PATH,
        )
    value, raw = _load_committed_json(
        project,
        head,
        GENERATION8_RUNTIME_EVIDENCE_PATH,
        report,
        "generation8.step11.runtime_evidence",
        require_canonical_bytes=True,
    )
    if not isinstance(value, dict) or raw is None:
        return
    if receipt.mcp_runtime_evidence_sha256 != sha256_bytes(raw):
        report.add(
            "hash_mismatches",
            "GENERATION8_RUNTIME_EVIDENCE_SHA256_MISMATCH",
            GENERATION8_RUNTIME_EVIDENCE_PATH,
        )
    if not _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_RUNTIME_EVIDENCE_FIELD_SET_MISMATCH",
        "generation8.step11.runtime_evidence",
        value,
        GENERATION8_RUNTIME_EVIDENCE_FIELDS,
    ):
        return
    expected = {
        "schema_version": GENERATION8_RUNTIME_EVIDENCE_SCHEMA_VERSION,
        "step_id": "STEP11",
        "generation_id": GENERATION8_ID,
        "resume_evidence_id": manifest.get("new_evidence_id"),
        "authorization_manifest_sha256": authorization_sha256,
        "subject_head_sha": manifest.get("product_subject_head_sha"),
        "subject_tree_sha": manifest.get("product_subject_tree_sha"),
        "execution_head_sha": receipt.live_pr_head_sha,
        "execution_tree_sha": receipt.live_pr_tree_sha,
        "production_scene_path": "res://scenes/main.tscn",
        "execution_mode": "PRODUCTION_COMPOSITION_UI_DRIVEN",
        "diagnostic_only": False,
        "fixture_only": False,
        "scene_started_via_mcp": True,
        "mcp_real_runtime_observed": True,
        "selected_seed": manifest.get("selected_seed"),
        "player_count": 4,
        "new_game_profile": manifest.get("new_game_profile"),
        "mission_kind": "ASSAULT_REGION",
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            report.add(
                "identity_mismatches",
                "GENERATION8_RUNTIME_IDENTITY_MISMATCH",
                f"{field}:expected={expected_value!r}:actual={value.get(field)!r}",
            )
    if value.get("mcp_tool_identity") != REQUIRED_MCP_TOOL_IDENTITY:
        report.add("identity_mismatches", "GENERATION8_MCP_TOOL_IDENTITY_MISMATCH", repr(value.get("mcp_tool_identity")))
    if value.get("mcp_protocol_version") != REQUIRED_MCP_PROTOCOL_VERSION:
        report.add("identity_mismatches", "GENERATION8_MCP_PROTOCOL_VERSION_MISMATCH", repr(value.get("mcp_protocol_version")))
    if value.get("godot_binary_sha256") != REQUIRED_GODOT_BINARY_SHA256:
        report.add("hash_mismatches", "GENERATION8_GODOT_BINARY_SHA256_MISMATCH", repr(value.get("godot_binary_sha256")))
    for field in (
        "godot_binary_sha256",
        "project_godot_sha256",
        "main_tscn_sha256",
        "runtime_composition_sha256",
        "production_screen_sha256",
        "canonical_payload_sha256",
    ):
        if not _is_sha256(value.get(field)):
            report.add("schema_failures", "GENERATION8_RUNTIME_SHA256_INVALID", field)
    expected_hashes = {
        "project_godot_sha256": runtime_binding_sha256.get("project.godot"),
        "main_tscn_sha256": runtime_binding_sha256.get("scenes/main.tscn"),
        "runtime_composition_sha256": runtime_binding_sha256.get(
            "scenes/runtime/V075RuntimeComposition.tscn"
        ),
        "production_screen_sha256": runtime_binding_sha256.get(
            "scenes/ui/v075/V075SampleGameScreen.tscn"
        ),
    }
    for field, expected_value in expected_hashes.items():
        if expected_value is None or value.get(field) != expected_value:
            report.add(
                "hash_mismatches",
                "GENERATION8_RUNTIME_PRODUCT_BINDING_MISMATCH",
                f"{field}:expected={expected_value}:actual={value.get(field)!r}",
            )
    times: dict[str, datetime] = {}
    for field in ("session_started_at_utc", "session_ended_at_utc"):
        try:
            times[field] = parse_rfc3339_utc(value.get(field))
        except ValueError:
            report.add("schema_failures", "GENERATION8_RUNTIME_TIMESTAMP_INVALID", field)
    if (
        "session_started_at_utc" in times
        and "session_ended_at_utc" in times
        and times["session_started_at_utc"] >= times["session_ended_at_utc"]
    ):
        report.add("identity_mismatches", "GENERATION8_RUNTIME_SESSION_ORDER_INVALID", "start>=end")
    try:
        receipt_created = parse_rfc3339_utc(receipt.created_at_utc)
    except ValueError:
        receipt_created = None
    if receipt_created is not None and times.get("session_ended_at_utc", receipt_created) > receipt_created:
        report.add("identity_mismatches", "GENERATION8_RECEIPT_CREATED_BEFORE_RUNTIME_END", receipt.created_at_utc)
    target_region_id = value.get("target_region_id")
    if not isinstance(target_region_id, str) or re.fullmatch(r"region\.\d{3}", target_region_id) is None:
        report.add("schema_failures", "GENERATION8_TARGET_REGION_ID_INVALID", repr(target_region_id))

    injection = value.get("injection_counters")
    if _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_INJECTION_COUNTER_FIELD_SET_MISMATCH",
        "generation8.runtime.injection_counters",
        injection,
        GENERATION8_INJECTION_COUNTER_FIELDS,
    ):
        assert isinstance(injection, dict)
        for field in sorted(GENERATION8_INJECTION_COUNTER_FIELDS):
            if not _is_exact_int(injection.get(field)) or injection[field] != 0:
                report.add("field_mismatches", "GENERATION8_INJECTION_COUNT_NONZERO", f"{field}:{injection.get(field)!r}")

    asset = value.get("asset_authority_witness")
    if _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_ASSET_WITNESS_FIELD_SET_MISMATCH",
        "generation8.runtime.asset_authority_witness",
        asset,
        GENERATION8_ASSET_WITNESS_FIELDS,
    ):
        assert isinstance(asset, dict)
        expected_asset = {
            "schema": "space_syndicate.v076.asset_consequence_witness.v1",
            "action": "ASSAULT_REGION",
            "outcome": "SETTLED",
            "asset_debit_count": 1,
            "consequence_bound": True,
            "projection_failure_count": 0,
            "presentation_count": 1,
        }
        for field, expected_value in expected_asset.items():
            if asset.get(field) != expected_value:
                report.add("field_mismatches", "GENERATION8_ASSET_WITNESS_IDENTITY_MISMATCH", f"{field}:{asset.get(field)!r}")
        for field in (
            "reservation_id",
            "owner_player_id",
            "reservation_receipt_id",
            "reservation_receipt_fingerprint",
            "settlement_receipt_id",
            "settlement_receipt_fingerprint",
            "mission_receipt_fingerprint",
        ):
            if not isinstance(asset.get(field), str) or not asset[field]:
                report.add("schema_failures", "GENERATION8_ASSET_WITNESS_STRING_MISSING", field)
        for field in (
            "reservation_receipt_fingerprint",
            "settlement_receipt_fingerprint",
            "mission_receipt_fingerprint",
            "witness_fingerprint",
        ):
            if not _is_sha256(asset.get(field)):
                report.add("schema_failures", "GENERATION8_ASSET_WITNESS_SHA256_INVALID", field)
        if asset.get("witness_fingerprint") != _generation8_witness_fingerprint(asset):
            report.add("hash_mismatches", "GENERATION8_ASSET_WITNESS_FINGERPRINT_MISMATCH", "asset_authority_witness")
        for field in (
            "asset_revision_before",
            "asset_revision_after",
            "asset_debit_count",
            "projection_count_before",
            "projection_count_after",
            "projection_failure_count",
            "presentation_count",
        ):
            if not _is_exact_int(asset.get(field)) or asset[field] < 0:
                report.add("schema_failures", "GENERATION8_ASSET_WITNESS_INTEGER_INVALID", field)
        if _is_exact_int(asset.get("asset_revision_before")) and asset.get("asset_revision_after") != asset["asset_revision_before"] + 1:
            report.add("field_mismatches", "GENERATION8_ASSET_REVISION_NOT_EXACT_ONCE", repr(asset))
        if _is_exact_int(asset.get("projection_count_before")) and asset.get("projection_count_after") != asset["projection_count_before"] + 1:
            report.add("field_mismatches", "GENERATION8_ASSET_PROJECTION_NOT_EXACT_ONCE", repr(asset))
        quantity_fields = (
            "asset_quantities_before",
            "asset_quantities_after",
            "asset_delta_by_color",
            "reserved_asset_cost_by_color",
        )
        quantities: dict[str, dict[str, int]] = {}
        for field in quantity_fields:
            row = asset.get(field)
            if not isinstance(row, dict) or not row:
                report.add("schema_failures", "GENERATION8_ASSET_QUANTITY_MAP_INVALID", field)
                continue
            if any(not isinstance(color, str) or not _is_exact_int(amount) for color, amount in row.items()):
                report.add("schema_failures", "GENERATION8_ASSET_QUANTITY_ENTRY_INVALID", field)
                continue
            quantities[field] = row
        before = quantities.get("asset_quantities_before", {})
        after = quantities.get("asset_quantities_after", {})
        delta = quantities.get("asset_delta_by_color", {})
        cost = quantities.get("reserved_asset_cost_by_color", {})
        if before and after and delta and cost:
            colors = set(before) | set(after) | set(delta) | set(cost)
            if any(before.get(color, 0) < 0 or after.get(color, 0) < 0 for color in colors):
                report.add("field_mismatches", "GENERATION8_ASSET_NEGATIVE_VALUE", repr(asset))
            if not any(amount > 0 for amount in cost.values()):
                report.add("field_mismatches", "GENERATION8_ASSET_COST_NOT_POSITIVE", repr(cost))
            for color in colors:
                expected_delta = after.get(color, 0) - before.get(color, 0)
                if delta.get(color, 0) != expected_delta or expected_delta != -cost.get(color, 0):
                    report.add("field_mismatches", "GENERATION8_ASSET_DELTA_PARITY_MISMATCH", color)

    military = value.get("military_lifecycle_witness")
    if _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_MILITARY_WITNESS_FIELD_SET_MISMATCH",
        "generation8.runtime.military_lifecycle_witness",
        military,
        GENERATION8_MILITARY_WITNESS_FIELDS,
    ):
        assert isinstance(military, dict)
        expected_military = {
            "mission_kind": "ASSAULT_REGION",
            "target_region_id": target_region_id,
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
        for field, expected_value in expected_military.items():
            if military.get(field) != expected_value:
                report.add("field_mismatches", "GENERATION8_MILITARY_WITNESS_IDENTITY_MISMATCH", f"{field}:{military.get(field)!r}")
        for field in ("submission_id", "command_id"):
            if not isinstance(military.get(field), str) or not military[field]:
                report.add("schema_failures", "GENERATION8_MILITARY_WITNESS_STRING_MISSING", field)
        for field in (
            "eta_ticks",
            "arrival_tick",
            "submission_count",
            "intake_settlement_count",
            "resolution_count",
            "withdrawal_count",
            "collision_count",
            "public_batch_entry_count",
            "shared_sushi_track_resolution_count",
            "consequence_presentation_count",
        ):
            if not _is_exact_int(military.get(field)) or military[field] < 0:
                report.add("schema_failures", "GENERATION8_MILITARY_WITNESS_INTEGER_INVALID", field)
        if not _is_exact_int(military.get("eta_ticks")) or military.get("eta_ticks", 0) <= 0:
            report.add("field_mismatches", "GENERATION8_MILITARY_ETA_NOT_POSITIVE", repr(military.get("eta_ticks")))

    proof = value.get("proof")
    if _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_STEP11_PROOF_FIELD_SET_MISMATCH",
        "generation8.runtime.proof",
        proof,
        GENERATION8_STEP11_PROOF_FIELDS,
    ):
        assert isinstance(proof, dict)
        for field in sorted(GENERATION8_STEP11_POSITIVE_PROOF_FIELDS):
            if not _is_exact_int(proof.get(field)) or proof[field] < 1:
                report.add("field_mismatches", "STEP_PROOF_POSITIVE_COUNT_MISSING", f"STEP11.{field}:{proof.get(field)!r}")
        for field in sorted(GENERATION8_STEP11_ZERO_PROOF_FIELDS):
            if not _is_exact_int(proof.get(field)) or proof[field] != 0:
                report.add("field_mismatches", "STEP_PROOF_ZERO_COUNT_VIOLATION", f"STEP11.{field}:{proof.get(field)!r}")
        for field in (
            "asset_authority_receipt_count",
            "before_after_quantity_receipt_count",
            "committed_revision_receipt_count",
            "asset_delta_projection_count",
            "asset_consequence_binding_count",
            "exact_once_binding_count",
        ):
            if proof.get(field) != 1:
                report.add("field_mismatches", "GENERATION8_ASSET_PROOF_NOT_EXACT_ONCE", f"{field}:{proof.get(field)!r}")
        for field in (
            "assault_region_root_command_count",
            "military_direct_action_accepted_count",
            "military_eta_created_count",
            "military_eta_positive_count",
            "military_arrival_count",
            "assault_region_resolution_count",
            "military_withdrawal_count",
        ):
            if proof.get(field) != 1:
                report.add("field_mismatches", "GENERATION8_MILITARY_PROOF_NOT_EXACT_ONCE", f"{field}:{proof.get(field)!r}")
    if value.get("canonical_payload_sha256") != canonical_payload_sha256(value):
        report.add("hash_mismatches", "GENERATION8_RUNTIME_CANONICAL_SHA256_MISMATCH", GENERATION8_RUNTIME_EVIDENCE_PATH)


def _validate_generation8_formal_documents(
    project: GitCommittedProject,
    head: str,
    execution_head: str,
    execution_tree: str,
    manifest: Mapping[str, Any],
    authorization_sha256: str,
    receipt_raw: bytes,
    report: ValidationReport,
) -> set[str]:
    allowlist = {
        GENERATION8_EXECUTION_START_PATH,
        GENERATION8_PROGRESS_PATH,
        GENERATION8_SUMMARY_PATH,
    }
    execution, _execution_raw = _load_committed_json(
        project,
        head,
        GENERATION8_EXECUTION_START_PATH,
        report,
        "generation8.execution_start",
        require_canonical_bytes=True,
    )
    if _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_EXECUTION_START_FIELD_SET_MISMATCH",
        "generation8.execution_start",
        execution,
        GENERATION8_EXECUTION_START_FIELDS,
    ):
        assert isinstance(execution, dict)
        expected_execution = {
            "schema_version": GENERATION8_EXECUTION_START_SCHEMA_VERSION,
            "status": "STARTED",
            "authorization_id": GENERATION8_AUTHORIZATION_ID,
            "authorization_manifest_sha256": authorization_sha256,
            "generation_id": GENERATION8_ID,
            "parent_generation_id": GENERATION8_PARENT_ID,
            "parent_evidence_id": GENERATION8_PARENT_EVIDENCE_ID,
            "new_evidence_id": manifest.get("new_evidence_id"),
            "formal_attempt_id": "formal-attempt-001",
            "formal_execution_count": 1,
            "automatic_retry_count": 0,
            "execution_head_sha": execution_head,
            "execution_tree_sha": execution_tree,
            "product_subject_head_sha": manifest.get("product_subject_head_sha"),
            "product_subject_tree_sha": manifest.get("product_subject_tree_sha"),
            "selected_seed": manifest.get("selected_seed"),
            "player_count": 4,
            "new_game_profile": manifest.get("new_game_profile"),
            "production_scene_path": "res://scenes/main.tscn",
            "execution_mode": "PRODUCTION_COMPOSITION_UI_DRIVEN",
        }
        for field, expected_value in expected_execution.items():
            if execution.get(field) != expected_value:
                report.add("identity_mismatches", "GENERATION8_EXECUTION_START_IDENTITY_MISMATCH", f"{field}:{execution.get(field)!r}")
        injection = execution.get("injection_counters")
        if _compare_exact_keys(
            report,
            "schema_failures",
            "GENERATION8_EXECUTION_INJECTION_FIELD_SET_MISMATCH",
            "generation8.execution_start.injection_counters",
            injection,
            GENERATION8_INJECTION_COUNTER_FIELDS,
        ):
            assert isinstance(injection, dict)
            for field in GENERATION8_INJECTION_COUNTER_FIELDS:
                if not _is_exact_int(injection.get(field)) or injection[field] != 0:
                    report.add("field_mismatches", "GENERATION8_EXECUTION_INJECTION_NONZERO", field)
        try:
            parse_rfc3339_utc(execution.get("started_at_utc"))
        except ValueError:
            report.add("schema_failures", "GENERATION8_EXECUTION_START_TIMESTAMP_INVALID", repr(execution.get("started_at_utc")))
        if execution.get("canonical_payload_sha256") != canonical_payload_sha256(execution):
            report.add("hash_mismatches", "GENERATION8_EXECUTION_START_CANONICAL_SHA256_MISMATCH", GENERATION8_EXECUTION_START_PATH)

    progress, _progress_raw = _load_committed_json(
        project,
        head,
        GENERATION8_PROGRESS_PATH,
        report,
        "generation8.progress",
        require_canonical_bytes=True,
    )
    if _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_PROGRESS_FIELD_SET_MISMATCH",
        "generation8.progress",
        progress,
        GENERATION8_PROGRESS_FIELDS,
    ):
        assert isinstance(progress, dict)
        expected_progress = {
            "schema_version": GENERATION8_PROGRESS_SCHEMA_VERSION,
            "status": "COMPLETED",
            "generation_id": GENERATION8_ID,
            "new_evidence_id": manifest.get("new_evidence_id"),
            "formal_attempt_id": "formal-attempt-001",
            "formal_execution_count": 1,
            "automatic_retry_count": 0,
            "current_step": "STEP11_ASSAULT_REGION",
            "step11_status": "PASS",
            "accepted_action_drain_status": "PASS",
            "process_cleanup_status": "PASS",
        }
        for field, expected_value in expected_progress.items():
            if progress.get(field) != expected_value:
                report.add("identity_mismatches", "GENERATION8_PROGRESS_IDENTITY_MISMATCH", f"{field}:{progress.get(field)!r}")
        parsed: list[datetime] = []
        for field in ("started_at_utc", "completed_at_utc"):
            try:
                parsed.append(parse_rfc3339_utc(progress.get(field)))
            except ValueError:
                report.add("schema_failures", "GENERATION8_PROGRESS_TIMESTAMP_INVALID", field)
        if len(parsed) == 2 and parsed[0] >= parsed[1]:
            report.add("identity_mismatches", "GENERATION8_PROGRESS_TIMESTAMP_ORDER_INVALID", "start>=complete")
        if progress.get("canonical_payload_sha256") != canonical_payload_sha256(progress):
            report.add("hash_mismatches", "GENERATION8_PROGRESS_CANONICAL_SHA256_MISMATCH", GENERATION8_PROGRESS_PATH)

    summary, _summary_raw = _load_committed_json(
        project,
        head,
        GENERATION8_SUMMARY_PATH,
        report,
        "generation8.summary",
        require_canonical_bytes=True,
    )
    if _compare_exact_keys(
        report,
        "schema_failures",
        "GENERATION8_SUMMARY_FIELD_SET_MISMATCH",
        "generation8.summary",
        summary,
        GENERATION8_SUMMARY_FIELDS,
    ):
        assert isinstance(summary, dict)
        expected_summary = {
            "schema_version": GENERATION8_SUMMARY_SCHEMA_VERSION,
            "status": "PASS",
            "generation_id": GENERATION8_ID,
            "parent_generation_id": GENERATION8_PARENT_ID,
            "parent_evidence_id": GENERATION8_PARENT_EVIDENCE_ID,
            "new_evidence_id": manifest.get("new_evidence_id"),
            "authorization_manifest_sha256": authorization_sha256,
            "formal_attempt_id": "formal-attempt-001",
            "formal_execution_count": 1,
            "automatic_retry_count": 0,
            "step11_receipt_path": GENERATION8_STEP11_RECEIPT_PATH,
            "step11_receipt_sha256": sha256_bytes(receipt_raw),
            "step11_receipt_status": "PASS",
            "step11_required_positive_field_count": len(GENERATION8_STEP11_POSITIVE_PROOF_FIELDS),
            "step11_required_positive_field_pass_count": len(GENERATION8_STEP11_POSITIVE_PROOF_FIELDS),
            "step11_required_zero_field_count": len(GENERATION8_STEP11_ZERO_PROOF_FIELDS),
            "step11_required_zero_field_pass_count": len(GENERATION8_STEP11_ZERO_PROOF_FIELDS),
            "generation7_step11_receipt_status": "BLOCKED",
            "generation7_modification_count": 0,
            "generation7_rerun_count": 0,
            "process_cleanup_status": "PASS",
        }
        for field, expected_value in expected_summary.items():
            if summary.get(field) != expected_value:
                report.add("identity_mismatches", "GENERATION8_SUMMARY_IDENTITY_MISMATCH", f"{field}:{summary.get(field)!r}")
        try:
            parse_rfc3339_utc(summary.get("completed_at_utc"))
        except ValueError:
            report.add("schema_failures", "GENERATION8_SUMMARY_TIMESTAMP_INVALID", repr(summary.get("completed_at_utc")))
        if summary.get("canonical_payload_sha256") != canonical_payload_sha256(summary):
            report.add("hash_mismatches", "GENERATION8_SUMMARY_CANONICAL_SHA256_MISMATCH", GENERATION8_SUMMARY_PATH)
    return allowlist


def _validate_generation8_preformal_reports(
    project: GitCommittedProject,
    tooling_head: str,
    product_subject_head: str,
    manifest: Mapping[str, Any],
    report: ValidationReport,
) -> None:
    product_file_change_count = sum(
        1
        for _status, path in project.changed_entries(
            GENERATION7_ARTIFACT_HEAD_SHA, product_subject_head
        )
        if is_generation8_mcp_mutation_path(path)
    )
    characterization, _raw = _load_committed_json(
        project,
        tooling_head,
        GENERATION8_CHARACTERIZATION_PATH,
        report,
        "generation8.characterization",
        require_canonical_bytes=True,
    )
    if isinstance(characterization, dict):
        expected = {
            "generation_id": GENERATION8_ID,
            "formal_execution": False,
            "player_count": 4,
            "product_repair_required": product_file_change_count > 0,
            "godot_product_file_change_count": product_file_change_count,
        }
        for field, expected_value in expected.items():
            if characterization.get(field) != expected_value:
                report.add(
                    "identity_mismatches",
                    "GENERATION8_CHARACTERIZATION_IDENTITY_MISMATCH",
                    f"{field}:{characterization.get(field)!r}",
                )
        for field, minimum in (
            ("characterization_seed_count", 256),
            ("natural_assault_region_reachable_seed_count", 3),
            ("normally_settled_natural_assault_region_reachable_seed_count", 3),
            ("real_main_tscn_reachability_probe_count", 3),
        ):
            if not _is_exact_int(characterization.get(field)) or characterization[field] < minimum:
                report.add(
                    "field_mismatches",
                    "GENERATION8_CHARACTERIZATION_COUNT_INSUFFICIENT",
                    f"{field}:{characterization.get(field)!r}:minimum={minimum}",
                )
        if characterization.get("root_cause_class") not in {"I", "J", "I/J"}:
            report.add(
                "identity_mismatches",
                "GENERATION8_CHARACTERIZATION_ROOT_CAUSE_INVALID",
                repr(characterization.get("root_cause_class")),
            )
        probes = characterization.get("real_main_tscn_reachability_probes")
        if not isinstance(probes, list) or len(probes) < 3:
            report.add(
                "schema_failures", "GENERATION8_CHARACTERIZATION_PROBES_MISSING", repr(probes)
            )
            probes = []
        probe_seeds: list[int] = []
        for probe in probes:
            if not isinstance(probe, dict) or probe.get("status") != "PASS" or not _is_exact_int(probe.get("seed")):
                report.add(
                    "schema_failures", "GENERATION8_CHARACTERIZATION_PROBE_INVALID", repr(probe)
                )
                continue
            probe_seeds.append(probe["seed"])
            for field in (
                "fixture_card_injection_count",
                "fixture_asset_injection_count",
                "fixture_target_injection_count",
                "fixture_action_injection_count",
                "fixture_eta_injection_count",
                "direct_action_internal_method_as_ui_proof_count",
            ):
                if probe.get(field) != 0 or not _is_exact_int(probe.get(field)):
                    report.add(
                        "field_mismatches",
                        "GENERATION8_CHARACTERIZATION_PROBE_INJECTION_NONZERO",
                        f"{probe.get('seed')}:{field}:{probe.get(field)!r}",
                    )
        if manifest.get("selected_seed") not in probe_seeds:
            report.add(
                "identity_mismatches",
                "GENERATION8_SELECTED_SEED_NOT_UI_PROVEN",
                repr(manifest.get("selected_seed")),
            )
        for field in (
            "fixture_card_injection_count",
            "fixture_asset_injection_count",
            "fixture_target_injection_count",
            "fixture_action_injection_count",
            "fixture_eta_injection_count",
            "direct_action_internal_method_as_ui_proof_count",
        ):
            if characterization.get(field) != 0 or not _is_exact_int(characterization.get(field)):
                report.add(
                    "field_mismatches",
                    "GENERATION8_CHARACTERIZATION_INJECTION_NONZERO",
                    f"{field}:{characterization.get(field)!r}",
                )
    focused, _focused_raw = _load_committed_json(
        project,
        tooling_head,
        GENERATION8_FOCUSED_TEST_REPORT_PATH,
        report,
        "generation8.focused_test_report",
        require_canonical_bytes=True,
    )
    if isinstance(focused, dict):
        expected_focused = {
            "status": "PASS",
            "generation_id": GENERATION8_ID,
            "focused_test_count": 26,
            "focused_test_pass_count": 26,
            "focused_test_failure_count": 0,
            "full_world_reproof_count": 0,
            "unnecessary_full_suite_run_count": 0,
            "step09_inherited_regression_count": 0,
            "step12_inherited_regression_count": 0,
            "godot_product_file_change_count": product_file_change_count,
        }
        for field, expected_value in expected_focused.items():
            if focused.get(field) != expected_value:
                report.add(
                    "identity_mismatches",
                    "GENERATION8_FOCUSED_TEST_REPORT_MISMATCH",
                    f"{field}:{focused.get(field)!r}",
                )
        if focused.get("canonical_payload_sha256") != canonical_payload_sha256(focused):
            report.add(
                "hash_mismatches",
                "GENERATION8_FOCUSED_TEST_REPORT_CANONICAL_SHA256_MISMATCH",
                GENERATION8_FOCUSED_TEST_REPORT_PATH,
            )
    contract_value, _contract_raw = _load_committed_json(
        project,
        tooling_head,
        GENERATION8_MAJOR_ROUND_CONTRACT_PATH,
        report,
        "generation8.major_round_contract",
        require_canonical_bytes=True,
    )
    if isinstance(contract_value, dict):
        expected_contract = {
            "status": "PASS_REPAIRED_PRODUCT_CONTRACT",
            "contract_id": "V076_COMPLETE_MAJOR_ROUND_BEFORE_FINAL_SETTLEMENT_V1",
            "complete_major_round_before_settlement": True,
            "explicit_mid_round_qualification_latch_present": True,
            "bounded_terminal_drain_deadlock_guard_present": True,
            "accepted_action_loss_at_terminal_count": 0,
            "final_settlement_count": 1,
            "duplicate_final_settlement_count": 0,
            "winner_fact_delta_count": 0,
            "terminal_drain_deadlock_count": 0,
            "victory_threshold_change_count": 0,
            "winner_fact_change_count": 0,
        }
        for field, expected_value in expected_contract.items():
            if contract_value.get(field) != expected_value:
                report.add(
                    "identity_mismatches",
                    "GENERATION8_MAJOR_ROUND_CONTRACT_MISMATCH",
                    f"{field}:{contract_value.get(field)!r}",
                )
        if contract_value.get("canonical_payload_sha256") != canonical_payload_sha256(contract_value):
            report.add(
                "hash_mismatches",
                "GENERATION8_MAJOR_ROUND_CONTRACT_CANONICAL_SHA256_MISMATCH",
                GENERATION8_MAJOR_ROUND_CONTRACT_PATH,
            )


def validate_generation8_repository(
    project_root: Path,
    expected_consumer_head: str,
) -> dict[str, Any]:
    report = ValidationReport(
        generation_id=GENERATION8_ID,
        resume_evidence_id=-1,
        validation_mode="GENERATION8_SUCCESSOR",
    )
    try:
        project = GitCommittedProject(project_root)
        evaluated_head = project.resolve_commit(expected_consumer_head)
        report.expected_consumer_head_sha = evaluated_head
    except Exception as exc:
        report.add("identity_mismatches", "VALIDATION_CONTEXT_INVALID", str(exc))
        return report.finish()
    if not project.is_ancestor(GENERATION7_ARTIFACT_HEAD_SHA, evaluated_head):
        report.add(
            "identity_mismatches",
            "GENERATION7_ARTIFACT_NOT_GENERATION8_ANCESTOR",
            evaluated_head,
        )
        return report.finish()

    parent_summary_sha, _g7_rows = _validate_generation7_frozen_receipt_chain(
        project, evaluated_head, report
    )
    if parent_summary_sha is None:
        return report.finish()

    authorization_additions = project.addition_commits(
        evaluated_head, GENERATION8_AUTHORIZATION_MANIFEST_PATH
    )
    if len(authorization_additions) != 1:
        report.add(
            "identity_mismatches",
            "GENERATION8_AUTHORIZATION_COMMIT_NOT_UNIQUE",
            repr(authorization_additions),
        )
        return report.finish()
    authorization_head = authorization_additions[0]
    try:
        tooling_head = project.single_parent(authorization_head)
        tooling_tree = project.tree(tooling_head)
        product_subject_head = project.single_parent(tooling_head)
        product_subject_tree = project.tree(product_subject_head)
        authorization_tree = project.tree(authorization_head)
    except ValueError as exc:
        report.add(
            "identity_mismatches", "GENERATION8_AUTHORIZATION_PARENT_INVALID", str(exc)
        )
        return report.finish()
    if not project.is_ancestor(GENERATION7_ARTIFACT_HEAD_SHA, tooling_head):
        report.add(
            "identity_mismatches",
            "GENERATION8_TOOLING_NOT_GENERATION7_SUCCESSOR",
            tooling_head,
        )
    if not project.is_ancestor(GENERATION7_ARTIFACT_HEAD_SHA, product_subject_head):
        report.add(
            "identity_mismatches",
            "GENERATION8_PRODUCT_SUBJECT_NOT_GENERATION7_SUCCESSOR",
            product_subject_head,
        )
    authorization_entries = project.changed_entries(tooling_head, authorization_head)
    expected_authorization_entries = [
        ("A", GENERATION8_AUTHORIZATION_MANIFEST_PATH),
        ("A", GENERATION8_AUTHORIZATION_SIDECAR_PATH),
    ]
    if authorization_entries != expected_authorization_entries:
        report.add(
            "path_failures",
            "GENERATION8_AUTHORIZATION_COMMIT_NOT_EXACT_ALLOWLIST",
            f"expected={expected_authorization_entries}:actual={authorization_entries}",
        )
    registry_sha256s, registry_max = _load_generation8_registry_state(
        project, tooling_head, report
    )
    if registry_max is None:
        return report.finish()
    authorization, authorization_raw = _load_committed_json(
        project,
        authorization_head,
        GENERATION8_AUTHORIZATION_MANIFEST_PATH,
        report,
        "generation8.authorization_manifest",
        require_canonical_bytes=True,
    )
    if authorization_raw is None:
        return report.finish()
    authorization_sha256 = sha256_bytes(authorization_raw)
    sidecar = None
    try:
        sidecar = project.read_regular_file(
            authorization_head, GENERATION8_AUTHORIZATION_SIDECAR_PATH
        )
    except (ValueError, CommittedPathError) as exc:
        report.add(
            "path_failures", "GENERATION8_AUTHORIZATION_SIDECAR_UNAVAILABLE", str(exc)
        )
    expected_sidecar = (
        f"{authorization_sha256}  {GENERATION8_AUTHORIZATION_MANIFEST_PATH}\n".encode(
            "utf-8"
        )
    )
    if sidecar is not None and sidecar != expected_sidecar:
        report.add(
            "hash_mismatches",
            "GENERATION8_AUTHORIZATION_SIDECAR_MISMATCH",
            GENERATION8_AUTHORIZATION_SIDECAR_PATH,
        )
    authorization = _validate_generation8_authorization_value(
        authorization,
        report,
        parent_summary_sha256=parent_summary_sha,
        registry_sha256s=registry_sha256s,
        registry_max_evidence_id=registry_max,
        tooling_head_sha=tooling_head,
        tooling_tree_sha=tooling_tree,
        product_subject_head_sha=product_subject_head,
        product_subject_tree_sha=product_subject_tree,
    )
    if authorization is None:
        return report.finish()
    report.resume_evidence_id = (
        authorization["new_evidence_id"]
        if _is_exact_int(authorization.get("new_evidence_id"))
        else -1
    )
    binding_specs = (
        (SCHEMA_AUTHORITY_PATH, "receipt_schema_sha256"),
        (VALIDATOR_PATH, "receipt_validator_sha256"),
        (WORKFLOW_PATH, "required_workflow_sha256"),
        (SELFTEST_PATH, "receipt_selftest_sha256"),
        (GENERATION8_PRODUCT_PATH_MANIFEST_PATH, "product_path_manifest_sha256"),
        (GENERATION8_MCP_LANDING_MANIFEST_PATH, "mcp_landing_manifest_sha256"),
        (GENERATION8_FOCUSED_TEST_REPORT_PATH, "focused_test_report_sha256"),
        (GENERATION8_CHARACTERIZATION_PATH, "characterization_report_sha256"),
        (GENERATION8_MAJOR_ROUND_CONTRACT_PATH, "major_round_contract_sha256"),
        (GENERATION8_TOOLING_SEAL_PATH, "generation8_tooling_seal_sha256"),
    )
    for path, field in binding_specs:
        claimed = authorization.get(field)
        if _is_sha256(claimed):
            _validate_supporting_binding(
                project,
                tooling_head,
                path,
                claimed,
                report,
                f"generation8.authorization.{field}",
            )
        else:
            report.add(
                "schema_failures",
                "GENERATION8_AUTHORIZATION_BINDING_INVALID",
                field,
            )
    selftest_bytes = (
        _validate_supporting_binding(
            project,
            tooling_head,
            SELFTEST_PATH,
            str(authorization.get("receipt_selftest_sha256")),
            report,
            "generation8.selftest",
        )
        if _is_sha256(authorization.get("receipt_selftest_sha256"))
        else None
    )
    catalog, _catalog_raw = _load_committed_json(
        project,
        tooling_head,
        GENERATION8_NEGATIVE_FIXTURE_CATALOG_PATH,
        report,
        "generation8.negative_fixture_catalog",
        require_canonical_bytes=True,
    )
    if selftest_bytes is not None:
        _validate_generation8_negative_fixture_catalog(
            catalog,
            selftest_bytes,
            report,
            "generation8.negative_fixture_catalog",
        )
    _validate_generation8_tooling_seal(
        project, tooling_head, product_subject_head, authorization, report
    )
    _validate_generation8_mcp_landing(
        project, tooling_head, product_subject_head, authorization, report
    )
    _validate_generation8_preformal_reports(
        project, tooling_head, product_subject_head, authorization, report
    )

    authorized_product_subject_head = str(
        authorization.get("product_subject_head_sha", "")
    )
    authorized_product_subject_tree = str(
        authorization.get("product_subject_tree_sha", "")
    )
    product_manifest_path = str(authorization.get("product_path_manifest_path", ""))
    subject_manifest, subject_manifest_raw = _load_committed_json(
        project,
        tooling_head,
        product_manifest_path,
        report,
        "generation8.product_subject_manifest",
        require_canonical_bytes=True,
    )
    runtime_binding_sha256: dict[str, str] = {}
    generation8_changed_paths: list[str] = []
    if isinstance(subject_manifest, dict) and subject_manifest_raw is not None:
        if sha256_bytes(subject_manifest_raw) != authorization.get(
            "product_path_manifest_sha256"
        ):
            report.add(
                "hash_mismatches",
                "GENERATION8_PRODUCT_SUBJECT_MANIFEST_SHA256_MISMATCH",
                product_manifest_path,
            )
        runtime_binding_sha256 = _validate_manifest_product_bindings(
            project,
            subject_manifest,
            (authorized_product_subject_head, authorization_head),
            report,
        )
        generation8_changed_paths = sorted(
            path
            for _status, path in project.changed_entries(
                GENERATION7_ARTIFACT_HEAD_SHA, authorized_product_subject_head
            )
            if is_generation8_mcp_mutation_path(path)
        )
        expected_manifest_identity = {
            "schema_version": (
                "space_syndicate.v076.generation8_product_path_manifest.v1"
            ),
            "authorization_id": GENERATION8_AUTHORIZATION_ID,
            "generation_id": GENERATION8_ID,
            "base_head_sha": GENERATION7_ARTIFACT_HEAD_SHA,
            "base_tree_sha": project.tree(GENERATION7_ARTIFACT_HEAD_SHA),
            "product_file_change_count": len(generation8_changed_paths),
            "product_file_change_paths": generation8_changed_paths,
            "direct_filesystem_product_edit_count": 0,
        }
        for field, expected_value in expected_manifest_identity.items():
            if subject_manifest.get(field) != expected_value:
                report.add(
                    "identity_mismatches",
                    "GENERATION8_PRODUCT_PATH_MANIFEST_IDENTITY_MISMATCH",
                    f"{field}:expected={expected_value!r}:actual={subject_manifest.get(field)!r}",
                )
        if subject_manifest.get("canonical_payload_sha256") != canonical_payload_sha256(
            subject_manifest
        ):
            report.add(
                "hash_mismatches",
                "GENERATION8_PRODUCT_PATH_MANIFEST_CANONICAL_SHA256_MISMATCH",
                product_manifest_path,
            )
        required_runtime_paths = {
            "project.godot",
            "scenes/main.tscn",
            "scenes/runtime/V075RuntimeComposition.tscn",
            "scenes/ui/v075/V075SampleGameScreen.tscn",
        }
        if not required_runtime_paths.issubset(runtime_binding_sha256):
            report.add(
                "path_failures",
                "GENERATION8_PRODUCT_PATH_MANIFEST_RUNTIME_BOUNDARY_INCOMPLETE",
                repr(sorted(runtime_binding_sha256)),
            )

    receipt_additions = project.addition_commits(
        evaluated_head, GENERATION8_STEP11_RECEIPT_PATH
    )
    if len(receipt_additions) != 1:
        report.add(
            "identity_mismatches",
            "GENERATION8_RECEIPT_ARTIFACT_COMMIT_NOT_UNIQUE",
            repr(receipt_additions),
        )
        return report.finish()
    artifact_head = receipt_additions[0]
    report.artifact_head_sha = artifact_head
    try:
        execution_head = project.single_parent(artifact_head)
        execution_tree = project.tree(execution_head)
    except ValueError as exc:
        report.add(
            "identity_mismatches", "GENERATION8_ARTIFACT_PARENT_INVALID", str(exc)
        )
        return report.finish()
    report.execution_head_sha = execution_head
    report.execution_tree_sha = execution_tree
    if execution_head != authorization_head or execution_tree != authorization_tree:
        report.add(
            "identity_mismatches",
            "GENERATION8_EXECUTION_HEAD_NOT_AUTHORIZATION_COMMIT",
            f"expected={authorization_head}/{authorization_tree}:actual={execution_head}/{execution_tree}",
        )
    if not project.is_ancestor(artifact_head, evaluated_head):
        report.add(
            "identity_mismatches",
            "GENERATION8_ARTIFACT_NOT_EVALUATED_ANCESTOR",
            f"artifact={artifact_head}:evaluated={evaluated_head}",
        )

    receipt_value, receipt_raw = _load_committed_json(
        project,
        artifact_head,
        GENERATION8_STEP11_RECEIPT_PATH,
        report,
        "generation8.step11.receipt",
        require_canonical_bytes=True,
    )
    if receipt_raw is None:
        return report.finish()
    report.receipt_count = 1
    receipt = _validate_generation8_receipt_schema(
        report, receipt_value, "generation8.step11.receipt", authorization
    )
    if receipt is None:
        return report.finish()
    report.validated_receipt_count = 1
    if receipt.step_id != "STEP11" or receipt.status != "PASS":
        report.add(
            "field_mismatches",
            "GENERATION8_STEP11_RECEIPT_NOT_PASS",
            f"step={receipt.step_id}:status={receipt.status}",
        )
    _validate_generation8_parent_receipt_binding(receipt, report)
    if receipt.live_pr_head_sha != execution_head or receipt.live_pr_tree_sha != execution_tree:
        report.add(
            "identity_mismatches",
            "GENERATION8_RECEIPT_EXECUTION_IDENTITY_MISMATCH",
            f"expected={execution_head}/{execution_tree}:actual={receipt.live_pr_head_sha}/{receipt.live_pr_tree_sha}",
        )
    if receipt.producer_tooling_head_sha != tooling_head or receipt.producer_tooling_tree_sha != tooling_tree:
        report.add(
            "identity_mismatches",
            "GENERATION8_RECEIPT_TOOLING_IDENTITY_MISMATCH",
            f"expected={tooling_head}/{tooling_tree}:actual={receipt.producer_tooling_head_sha}/{receipt.producer_tooling_tree_sha}",
        )
    if receipt.resume_authorization_manifest_sha256 != authorization_sha256:
        report.add(
            "hash_mismatches",
            "GENERATION8_RECEIPT_AUTHORIZATION_SHA256_MISMATCH",
            repr(receipt.resume_authorization_manifest_sha256),
        )
    expected_contains_product_delta = bool(generation8_changed_paths)
    expected_mcp_landing_path = (
        GENERATION8_MCP_LANDING_MANIFEST_PATH
        if expected_contains_product_delta
        else None
    )
    expected_mcp_landing_sha256 = (
        authorization.get("mcp_landing_manifest_sha256")
        if expected_contains_product_delta
        else None
    )
    if (
        receipt.contains_godot_product_delta is not expected_contains_product_delta
        or receipt.mcp_landing_manifest_path != expected_mcp_landing_path
        or receipt.mcp_landing_manifest_sha256 != expected_mcp_landing_sha256
    ):
        report.add(
            "identity_mismatches",
            "GENERATION8_RECEIPT_PRODUCT_DELTA_DECLARATION_INVALID",
            (
                f"expected={expected_contains_product_delta}/"
                f"{expected_mcp_landing_path}/{expected_mcp_landing_sha256}:"
                f"actual={receipt.contains_godot_product_delta}/"
                f"{receipt.mcp_landing_manifest_path}/"
                f"{receipt.mcp_landing_manifest_sha256}"
            ),
        )
    for path, claimed, label in (
        (receipt.producer_script_path, receipt.producer_script_sha256, "producer_script"),
        (receipt.schema_authority_path, receipt.schema_authority_sha256, "schema_authority"),
        (receipt.validator_path, receipt.validator_sha256, "validator"),
        (receipt.workflow_path, receipt.workflow_sha256, "workflow"),
        (receipt.product_path_manifest_path, receipt.product_path_manifest_sha256, "product_manifest"),
        (receipt.tooling_seal_path, receipt.tooling_seal_sha256, "tooling_seal"),
        (receipt.resume_authorization_manifest_path, receipt.resume_authorization_manifest_sha256, "authorization_manifest"),
    ):
        _validate_supporting_binding(
            project,
            artifact_head,
            path,
            claimed,
            report,
            f"generation8.receipt.{label}",
        )
    assert report.receipt_bindings is not None
    report.receipt_bindings.append(
        {
            "step_id": "STEP11",
            "receipt_id": receipt.receipt_id,
            "path": GENERATION8_STEP11_RECEIPT_PATH,
            "sha256": sha256_bytes(receipt_raw),
            "status": receipt.status,
            "subject_head_sha": receipt.subject_head_sha,
            "subject_tree_sha": receipt.subject_tree_sha,
            "execution_head_sha": receipt.live_pr_head_sha,
            "execution_tree_sha": receipt.live_pr_tree_sha,
        }
    )
    allowlist = {GENERATION8_STEP11_RECEIPT_PATH}
    allowlist.update(
        _validate_generation8_evidence_manifest(
            project, artifact_head, receipt, authorization, report
        )
    )
    _validate_generation8_source_evidence_index(
        project, artifact_head, authorization, allowlist, report
    )
    _validate_generation8_runtime_evidence(
        project,
        artifact_head,
        receipt,
        authorization,
        authorization_sha256,
        runtime_binding_sha256,
        allowlist,
        report,
    )
    allowlist.update(
        _validate_generation8_formal_documents(
            project,
            artifact_head,
            execution_head,
            execution_tree,
            authorization,
            authorization_sha256,
            receipt_raw,
            report,
        )
    )
    formal_paths = project.list_paths(artifact_head, GENERATION8_FORMAL_ROOT)
    if formal_paths != sorted(allowlist):
        report.add(
            "path_failures",
            "GENERATION8_FORMAL_PATH_SET_MISMATCH",
            f"expected={sorted(allowlist)}:actual={formal_paths}",
        )
    generation8_paths = project.list_paths(
        artifact_head, "reports/reuse/full_convergence/generation-008"
    )
    if any(
        not path.startswith(GENERATION8_FORMAL_ROOT + "/")
        for path in generation8_paths
    ):
        report.add(
            "path_failures",
            "GENERATION8_MULTIPLE_FORMAL_ATTEMPTS_DETECTED",
            repr(generation8_paths),
        )
    actual_entries = project.changed_entries(execution_head, artifact_head)
    expected_entries = [("A", path) for path in sorted(allowlist)]
    if actual_entries != expected_entries:
        report.add(
            "path_failures",
            "GENERATION8_ARTIFACT_COMMIT_NOT_EXACT_APPEND_ONLY_ALLOWLIST",
            f"expected={expected_entries}:actual={actual_entries}",
        )
    for path in sorted(allowlist):
        try:
            artifact_bytes = project.read_regular_file(artifact_head, path)
            evaluated_bytes = project.read_regular_file(evaluated_head, path)
        except (ValueError, CommittedPathError) as exc:
            report.add("path_failures", "GENERATION8_ARTIFACT_FILE_UNAVAILABLE", f"{path}:{exc}")
            continue
        if artifact_bytes != evaluated_bytes:
            report.add(
                "hash_mismatches", "GENERATION8_ARTIFACT_BYTES_DRIFT_AFTER_APPEND", path
            )
    return report.finish()


def validate_repository(
    project_root: Path,
    expected_consumer_head: str,
    subject_manifest_path: str = CURRENT_SUBJECT_MANIFEST_PATH,
) -> dict[str, Any]:
    report = ValidationReport()
    try:
        project = GitCommittedProject(project_root)
        evaluated_head = project.resolve_commit(expected_consumer_head)
        report.expected_consumer_head_sha = evaluated_head
    except Exception as exc:  # stable fail-closed envelope for Git/bootstrap errors
        report.add("identity_mismatches", "VALIDATION_CONTEXT_INVALID", str(exc))
        return report.finish()

    if subject_manifest_path != CURRENT_SUBJECT_MANIFEST_PATH:
        report.add(
            "path_failures",
            "SUBJECT_MANIFEST_PATH_NOT_AUTHORIZED",
            subject_manifest_path,
        )
        return report.finish()
    manifest, manifest_bytes = _load_committed_json(
        project,
        evaluated_head,
        subject_manifest_path,
        report,
        "candidate_subject_manifest",
    )
    if not isinstance(manifest, dict) or manifest_bytes is None:
        return report.finish()
    actual_manifest_hash = sha256_bytes(manifest_bytes)
    if actual_manifest_hash != CURRENT_SUBJECT_MANIFEST_SHA256:
        report.add(
            "hash_mismatches",
            "FROZEN_SUBJECT_MANIFEST_SHA256_MISMATCH",
            f"expected={CURRENT_SUBJECT_MANIFEST_SHA256}:actual={actual_manifest_hash}",
        )
    if manifest.get("schema_version") != "space_syndicate.v076.candidate_subject_manifest.v3":
        report.add(
            "identity_mismatches",
            "SUBJECT_MANIFEST_SCHEMA_MISMATCH",
            repr(manifest.get("schema_version")),
        )
    subject = manifest.get("subject")
    if not isinstance(subject, dict) or subject.get("head_sha") != CURRENT_SUBJECT_HEAD_SHA or subject.get("tree_sha") != CURRENT_SUBJECT_TREE_SHA:
        report.add(
            "identity_mismatches", "CURRENT_SUBJECT_IDENTITY_MISMATCH", repr(subject)
        )
    declared = manifest.get("required_current_subject_receipts")
    expected_declared = [
        {"path": path, "status": "PENDING"} for _step, path in REQUIRED_RECEIPT_SPECS
    ]
    if declared != expected_declared:
        report.add(
            "identity_mismatches",
            "RECEIPT_MANIFEST_DECLARATION_MISMATCH",
            repr(declared),
        )
        return report.finish()

    expected_receipt_paths = sorted(path for _step, path in REQUIRED_RECEIPT_SPECS)
    artifact_candidates: set[str] = set()
    addition_sets: list[list[str]] = []
    for path in expected_receipt_paths:
        additions = project.addition_commits(evaluated_head, path)
        addition_sets.append(additions)
        if len(additions) == 1:
            artifact_candidates.add(additions[0])
    if any(len(additions) != 1 for additions in addition_sets) or len(artifact_candidates) != 1:
        report.add(
            "identity_mismatches",
            "RECEIPT_ARTIFACT_COMMIT_NOT_UNIQUE",
            repr(dict(zip(expected_receipt_paths, addition_sets))),
        )
        return report.finish()
    artifact_head = next(iter(artifact_candidates))
    report.artifact_head_sha = artifact_head
    try:
        execution_head = project.single_parent(artifact_head)
        execution_tree = project.tree(execution_head)
        report.execution_head_sha = execution_head
        report.execution_tree_sha = execution_tree
    except ValueError as exc:
        report.add(
            "identity_mismatches", "RECEIPT_ARTIFACT_PARENT_INVALID", str(exc)
        )
        return report.finish()
    if not project.is_ancestor(artifact_head, evaluated_head):
        report.add(
            "identity_mismatches",
            "RECEIPT_ARTIFACT_NOT_EVALUATED_ANCESTOR",
            f"artifact={artifact_head}:evaluated={evaluated_head}",
        )
    for ancestor, descendant, code in (
        (AUTHORIZED_BASE_HEAD_SHA, execution_head, "AUTHORIZED_BASE_NOT_EXECUTION_ANCESTOR"),
        (CURRENT_SUBJECT_HEAD_SHA, execution_head, "CURRENT_SUBJECT_NOT_EXECUTION_ANCESTOR"),
        (execution_head, artifact_head, "EXECUTION_NOT_ARTIFACT_ANCESTOR"),
        (artifact_head, evaluated_head, "ARTIFACT_NOT_EVALUATED_ANCESTOR"),
    ):
        if not project.is_ancestor(ancestor, descendant):
            report.add(
                "identity_mismatches", code, f"{ancestor}:{descendant}"
            )

    runtime_binding_sha256 = _validate_manifest_product_bindings(
        project, manifest, (CURRENT_SUBJECT_HEAD_SHA,), report
    )
    subject_to_execution_product_delta = sorted(
        path
        for path in project.changed_paths(CURRENT_SUBJECT_HEAD_SHA, execution_head)
        if is_product_path(path)
    )
    post_execution_product_delta = sorted(
        path
        for path in project.changed_paths(execution_head, evaluated_head)
        if is_product_path(path)
    )
    if post_execution_product_delta:
        report.add(
            "identity_mismatches",
            "PRODUCT_PATH_CHANGED_AFTER_RECEIPT_EXECUTION",
            repr(post_execution_product_delta),
        )

    actual_receipt_tree_paths = [
        path
        for path in project.list_paths(evaluated_head, RECEIPT_ROOT)
        if path.endswith("_receipt.json")
    ]
    if actual_receipt_tree_paths != expected_receipt_paths:
        report.add(
            "path_failures",
            "RECEIPT_PATH_SET_MISMATCH",
            f"expected={expected_receipt_paths}:actual={actual_receipt_tree_paths}",
        )

    receipt_values: list[
        tuple[str, str, V076CurrentSubjectProductionRevalidationReceiptV1, bytes]
    ] = []
    allowlist: set[str] = set(expected_receipt_paths)
    for step_id, receipt_path in REQUIRED_RECEIPT_SPECS:
        value, raw = _load_committed_json(
            project,
            evaluated_head,
            receipt_path,
            report,
            f"{step_id}.receipt",
            require_canonical_bytes=True,
        )
        if value is None or raw is None:
            continue
        report.receipt_count += 1
        typed = _validate_receipt_schema(report, value, f"{step_id}.receipt")
        if typed is None:
            continue
        if typed.step_id != step_id:
            report.add(
                "identity_mismatches",
                "RECEIPT_STEP_PATH_MISMATCH",
                f"path={receipt_path}:declared={step_id}:actual={typed.step_id}",
            )
        if REQUIRED_RECEIPT_PATH_BY_STEP.get(typed.step_id) != receipt_path:
            report.add(
                "identity_mismatches",
                "RECEIPT_PATH_NOT_AUTHORIZED_FOR_STEP",
                f"step={typed.step_id}:path={receipt_path}",
            )
        if typed.status != "PASS":
            report.add(
                "field_mismatches",
                "RECEIPT_STATUS_NOT_PASS",
                f"{step_id}:{typed.status}",
            )
        expected_contains_delta = bool(subject_to_execution_product_delta)
        if typed.contains_godot_product_delta is not expected_contains_delta:
            report.add(
                "identity_mismatches",
                "RECEIPT_PRODUCT_DELTA_FLAG_MISMATCH",
                f"{step_id}:expected={expected_contains_delta}:actual={typed.contains_godot_product_delta}",
            )
        if typed.status == "PASS" and typed.contains_godot_product_delta:
            report.add(
                "identity_mismatches",
                "CURRENT_SUBJECT_PRODUCT_DELTA_REQUIRES_NEW_SUBJECT_MANIFEST",
                f"{step_id}:{subject_to_execution_product_delta}",
            )
        expected_id_prefix = f"v076-current-subject-{step_id.lower()}-"
        if not typed.receipt_id.startswith(expected_id_prefix):
            report.add(
                "identity_mismatches",
                "RECEIPT_ID_STEP_MISMATCH",
                f"{step_id}:{typed.receipt_id}",
            )
        if typed.live_pr_head_sha != execution_head or typed.live_pr_tree_sha != execution_tree:
            report.add(
                "identity_mismatches",
                "RECEIPT_EXECUTION_IDENTITY_MISMATCH",
                f"{step_id}:expected={execution_head}/{execution_tree}:actual={typed.live_pr_head_sha}/{typed.live_pr_tree_sha}",
            )
        try:
            producer_tree = project.tree(typed.producer_tooling_head_sha)
            if producer_tree != typed.producer_tooling_tree_sha:
                report.add(
                    "identity_mismatches",
                    "PRODUCER_TOOLING_TREE_MISMATCH",
                    f"{step_id}:expected={producer_tree}:actual={typed.producer_tooling_tree_sha}",
                )
            if not project.is_ancestor(typed.producer_tooling_head_sha, execution_head):
                report.add(
                    "identity_mismatches",
                    "PRODUCER_TOOLING_NOT_EXECUTION_ANCESTOR",
                    step_id,
                )
        except ValueError as exc:
            report.add(
                "identity_mismatches", "PRODUCER_TOOLING_IDENTITY_INVALID", f"{step_id}:{exc}"
            )
        expected_bindings = (
            (typed.producer_script_path, typed.producer_script_sha256, "producer_script"),
            (typed.schema_authority_path, typed.schema_authority_sha256, "schema_authority"),
            (typed.validator_path, typed.validator_sha256, "validator"),
            (typed.workflow_path, typed.workflow_sha256, "workflow"),
            (
                typed.product_path_manifest_path,
                typed.product_path_manifest_sha256,
                "product_path_manifest",
            ),
        )
        for path, claimed, kind in expected_bindings:
            _validate_supporting_binding(
                project,
                evaluated_head,
                path,
                claimed,
                report,
                f"{step_id}.{kind}",
            )
        for path, claimed, kind in expected_bindings[:4]:
            _validate_supporting_binding(
                project,
                typed.producer_tooling_head_sha,
                path,
                claimed,
                report,
                f"{step_id}.producer_tooling_head.{kind}",
            )
        if typed.product_path_manifest_sha256 != actual_manifest_hash:
            report.add(
                "hash_mismatches",
                "PRODUCT_PATH_MANIFEST_SHA256_MISMATCH",
                f"{step_id}:expected={actual_manifest_hash}:actual={typed.product_path_manifest_sha256}",
            )
        allowlist.update(
            _validate_evidence_manifest(project, evaluated_head, typed, report)
        )
        if typed.mcp_landing_manifest_path is not None:
            allowlist.add(typed.mcp_landing_manifest_path)
            _validate_supporting_binding(
                project,
                evaluated_head,
                typed.mcp_landing_manifest_path,
                str(typed.mcp_landing_manifest_sha256),
                report,
                f"{step_id}.mcp_landing_manifest",
            )
        if typed.mcp_runtime_evidence_path is not None:
            allowlist.add(typed.mcp_runtime_evidence_path)
        _validate_mcp_landing(
            project, evaluated_head, typed, allowlist, report
        )
        _validate_runtime_evidence(
            project,
            evaluated_head,
            typed,
            runtime_binding_sha256,
            allowlist,
            report,
        )
        _validate_seal_documents(project, evaluated_head, typed, report)
        receipt_values.append((step_id, receipt_path, typed, raw))
        report.validated_receipt_count += 1
        assert report.receipt_bindings is not None
        report.receipt_bindings.append(
            {
                "step_id": step_id,
                "receipt_id": typed.receipt_id,
                "path": receipt_path,
                "sha256": sha256_bytes(raw),
                "status": typed.status,
                "subject_head_sha": typed.subject_head_sha,
                "subject_tree_sha": typed.subject_tree_sha,
                "execution_head_sha": typed.live_pr_head_sha,
                "execution_tree_sha": typed.live_pr_tree_sha,
            }
        )

    ids = [typed.receipt_id for _step, _path, typed, _raw in receipt_values]
    if len(ids) != len(set(ids)):
        report.add("identity_mismatches", "DUPLICATE_RECEIPT_ID", repr(ids))
    previous_raw: bytes | None = None
    previous_created: datetime | None = None
    for step_id, _path, typed, raw in receipt_values:
        expected_previous = None if previous_raw is None else sha256_bytes(previous_raw)
        if typed.previous_receipt_sha256 != expected_previous:
            report.add(
                "hash_mismatches",
                "PREVIOUS_RECEIPT_CHAIN_MISMATCH",
                f"{step_id}:expected={expected_previous}:actual={typed.previous_receipt_sha256}",
            )
        previous_raw = raw
        try:
            created = parse_rfc3339_utc(typed.created_at_utc)
        except ValueError:
            created = None
        if created is not None and previous_created is not None and created < previous_created:
            report.add(
                "identity_mismatches",
                "RECEIPT_CHAIN_TIMESTAMP_REGRESSION",
                f"{step_id}:{typed.created_at_utc}",
            )
        if created is not None:
            previous_created = created

    actual_entries = project.changed_entries(execution_head, artifact_head)
    expected_entries = [("A", path) for path in sorted(allowlist)]
    if actual_entries != expected_entries:
        report.add(
            "path_failures",
            "RECEIPT_SUCCESSOR_NOT_EXACT_A_ONLY_ALLOWLIST",
            f"expected={expected_entries}:actual={actual_entries}",
        )
    for path in sorted(allowlist):
        try:
            artifact_bytes = project.read_regular_file(artifact_head, path)
            evaluated_bytes = project.read_regular_file(evaluated_head, path)
        except (ValueError, CommittedPathError) as exc:
            report.add(
                "path_failures", "ARTIFACT_FILE_UNAVAILABLE", f"{path}:{exc}"
            )
            continue
        if artifact_bytes != evaluated_bytes:
            report.add(
                "hash_mismatches", "ARTIFACT_BYTES_DRIFT_AFTER_APPEND", path
            )
    if report.receipt_count != len(REQUIRED_RECEIPT_SPECS):
        report.add(
            "field_mismatches",
            "RECEIPT_COUNT_MISMATCH",
            f"expected={len(REQUIRED_RECEIPT_SPECS)}:actual={report.receipt_count}",
        )
    if report.validated_receipt_count != len(REQUIRED_RECEIPT_SPECS):
        report.add(
            "field_mismatches",
            "VALIDATED_RECEIPT_COUNT_MISMATCH",
            f"expected={len(REQUIRED_RECEIPT_SPECS)}:actual={report.validated_receipt_count}",
        )
    return report.finish()


def schema_descriptor() -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "python_type": "V076CurrentSubjectProductionRevalidationReceiptV1",
        "unknown_field_policy": "REJECT",
        "extension_field": "extensions",
        "field_count": len(RECEIPT_FIELDS),
        "fields": sorted(RECEIPT_FIELDS),
        "required_generation_id": AUTHORIZED_GENERATION_ID,
        "required_resume_evidence_id": AUTHORIZED_RESUME_EVIDENCE_ID,
        "required_check_context": REQUIRED_CHECK_CONTEXT,
        "canonical_json": {
            "encoding": "UTF-8",
            "key_order": "UNICODE_CODEPOINT_ASCENDING",
            "separators": [",", ":"],
            "array_order": "PRESERVED",
            "terminal_lf": True,
            "allow_nan": False,
            "canonical_hash_excludes": ["canonical_payload_sha256"],
        },
    }


def _write_report(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_json_bytes(payload))


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    schema_parser = subparsers.add_parser("schema")
    schema_parser.add_argument("--report-json", type=Path)
    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("--project", type=Path, required=True)
    validate_parser.add_argument(
        "--subject-manifest", default=CURRENT_SUBJECT_MANIFEST_PATH
    )
    validate_parser.add_argument("--expected-consumer-head", required=True)
    validate_parser.add_argument("--report-json", type=Path, required=True)
    validate_generation8_parser = subparsers.add_parser("validate-generation8")
    validate_generation8_parser.add_argument("--project", type=Path, required=True)
    validate_generation8_parser.add_argument(
        "--expected-consumer-head", required=True
    )
    validate_generation8_parser.add_argument(
        "--report-json", type=Path, required=True
    )
    args = parser.parse_args(argv)

    if args.command == "schema":
        payload = schema_descriptor()
        if args.report_json:
            _write_report(args.report_json, payload)
        sys.stdout.buffer.write(canonical_json_bytes(payload))
        return 0

    try:
        if args.command == "validate-generation8":
            payload = validate_generation8_repository(
                args.project,
                args.expected_consumer_head,
            )
        else:
            payload = validate_repository(
                args.project,
                args.expected_consumer_head,
                args.subject_manifest,
            )
    except Exception as exc:  # final CLI boundary is always fail-closed
        payload = {
            "validator_status": "FAIL",
            "failure_codes": ["VALIDATOR_UNHANDLED_EXCEPTION"],
            "field_mismatches": [],
            "identity_mismatches": [f"VALIDATOR_UNHANDLED_EXCEPTION:{exc}"],
            "hash_mismatches": [],
            "path_failures": [],
            "schema_failures": [],
            "receipt_count": 0,
            "validated_receipt_count": 0,
            "required_gate_consumer_fail_closed": True,
        }
    _write_report(args.report_json, payload)
    sys.stdout.buffer.write(canonical_json_bytes(payload))
    return 0 if payload.get("validator_status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
