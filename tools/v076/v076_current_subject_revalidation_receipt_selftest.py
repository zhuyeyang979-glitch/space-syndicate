#!/usr/bin/env python3
"""Independent fixture matrix for the V076 fail-closed receipt contract."""

from __future__ import annotations

import copy
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
sys.path.insert(0, str(SCRIPT_DIR))

import v076_current_subject_revalidation_receipt as contract  # noqa: E402


def _h(char: str) -> str:
    return char * 64


def _g(char: str) -> str:
    return char * 40


def _finalize_receipt(value: dict[str, Any]) -> dict[str, Any]:
    value["result_fingerprint_sha256"] = contract.result_fingerprint_sha256(value)
    value["canonical_payload_sha256"] = contract.canonical_payload_sha256(value)
    return value


def _base_receipt(step_id: str = "STEP09") -> dict[str, Any]:
    short = step_id.lower()
    value: dict[str, Any] = {
        "schema_version": contract.SCHEMA_VERSION,
        "receipt_id": f"v076-current-subject-{short}-fixture-00000001",
        "receipt_kind": contract.RECEIPT_KIND,
        "authorization_id": contract.AUTHORIZATION_ID,
        "step_id": step_id,
        "generation_id": 7,
        "resume_evidence_id": 9631,
        "subject_head_sha": contract.CURRENT_SUBJECT_HEAD_SHA,
        "subject_tree_sha": contract.CURRENT_SUBJECT_TREE_SHA,
        "live_pr_head_sha": _g("b"),
        "live_pr_tree_sha": _g("c"),
        "required_check_context": contract.REQUIRED_CHECK_CONTEXT,
        "producer_tooling_head_sha": _g("d"),
        "producer_tooling_tree_sha": _g("e"),
        "producer_script_path": contract.PRODUCER_SCRIPT_PATH,
        "producer_script_sha256": _h("1"),
        "schema_authority_path": contract.SCHEMA_AUTHORITY_PATH,
        "schema_authority_sha256": _h("1"),
        "validator_path": contract.VALIDATOR_PATH,
        "validator_sha256": _h("1"),
        "workflow_path": contract.WORKFLOW_PATH,
        "workflow_sha256": _h("2"),
        "product_path_manifest_path": contract.CURRENT_SUBJECT_MANIFEST_PATH,
        "product_path_manifest_sha256": contract.CURRENT_SUBJECT_MANIFEST_SHA256,
        "tooling_seal_path": contract.TOOLING_SEAL_PATH,
        "tooling_seal_sha256": _h("4"),
        "resume_authorization_manifest_path": (
            contract.RESUME_AUTHORIZATION_MANIFEST_PATH
        ),
        "resume_authorization_manifest_sha256": _h("5"),
        "hard_stop_record_sha256": contract.AUTHORIZED_HARD_STOP_SHA256,
        "existing_generation7_evidence_inventory_sha256": (
            contract.FROZEN_EVIDENCE_INVENTORY_SHA256
        ),
        "evidence_manifest_path": (
            f"{contract.RECEIPT_ROOT}/{short}_evidence_manifest.json"
        ),
        "evidence_manifest_sha256": _h("6"),
        "contains_godot_product_delta": False,
        "requires_mcp_runtime_evidence": True,
        "mcp_landing_manifest_path": None,
        "mcp_landing_manifest_sha256": None,
        "mcp_runtime_evidence_path": (
            f"{contract.RECEIPT_ROOT}/evidence/{short}/runtime.json"
        ),
        "mcp_runtime_evidence_sha256": _h("7"),
        "status": "PASS",
        "check_count": contract.EXPECTED_CHECK_COUNT_BY_STEP[step_id],
        "pass_count": contract.EXPECTED_CHECK_COUNT_BY_STEP[step_id],
        "failure_count": 0,
        "failure_codes": [],
        "process_cleanup": {
            "exit_play_mode": "PASS",
            "stop_role_godot_mcp": "PASS",
            "editor_pid_after": 0,
            "game_pid_after": 0,
            "listener_count_after": 0,
        },
        "result_fingerprint_sha256": _h("8"),
        "created_at_utc": "2026-08-31T06:02:00Z",
        "previous_receipt_sha256": None,
        "canonical_payload_sha256": _h("9"),
        "extensions": {},
    }
    return _finalize_receipt(value)


def _schema_accepts(value: Any) -> bool:
    report = contract.ValidationReport()
    typed = contract._validate_receipt_schema(report, value, "fixture.receipt")
    payload = report.finish()
    return typed is not None and payload["validator_status"] == "PASS"


def _consumer_accepts(value: Any) -> bool:
    return _schema_accepts(value) and isinstance(value, dict) and value.get("status") == "PASS"


def _mutated(
    mutate: Callable[[dict[str, Any]], None], *, finalize: bool = True
) -> dict[str, Any]:
    value = copy.deepcopy(_base_receipt())
    mutate(value)
    if finalize:
        _finalize_receipt(value)
    return value


def _run(command: list[str], cwd: Path, input_bytes: bytes | None = None) -> bytes:
    completed = subprocess.run(
        command,
        cwd=cwd,
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        raise AssertionError(
            f"COMMAND_FAILED:{command}:{completed.stderr.decode('utf-8', errors='replace')}"
        )
    return completed.stdout


def _write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def _git(repo: Path, *args: str, input_bytes: bytes | None = None) -> bytes:
    return _run(["git", *args], repo, input_bytes=input_bytes)


def _valid_step_proof(step_id: str) -> dict[str, Any]:
    if step_id == "STEP09":
        return {
            "natural_monster_event_count": 1,
            "monster_move_authority_receipt_count": 1,
            "terminal_move_step_receipt_count": 1,
            "geodesic_route_receipt_count": 1,
            "consequence_ledger_receipt_count": 1,
            "presentation_cue_start_count": 1,
            "presentation_cue_finish_count": 1,
            "exact_once_binding_count": 1,
            "duplicate_binding_count": 0,
            "old_movement_writer_count": 0,
            "old_trample_receipt_count": 0,
        }
    if step_id == "STEP11":
        return {
            "asset_authority_receipt_count": 1,
            "before_after_quantity_receipt_count": 1,
            "committed_revision_receipt_count": 1,
            "asset_delta_projection_count": 1,
            "asset_consequence_binding_count": 1,
            "exact_once_binding_count": 1,
            "duplicate_binding_count": 0,
            "ui_gameplay_mutation_count": 0,
            "opponent_private_asset_disclosure_count": 0,
            "asset_projection_failure_count": 0,
        }
    return {
        "persisted_ai_observation_envelope_count": 1,
        "allowed_field_manifest_count": 1,
        "observation_source_receipt_binding_count": 1,
        "ai_public_action_receipt_count": 1,
        "sanitized_projection_binding_count": 1,
        "hidden_info_violation_count": 0,
        "private_information_violation_count": 0,
        "opponent_private_asset_disclosure_count": 0,
        "actor_id_disclosed": False,
        "private_queue_disclosed": False,
        "hidden_order_disclosed": False,
    }


def _build_repository_fixture(root: Path) -> tuple[str, str]:
    root.parent.mkdir(parents=True, exist_ok=True)
    _run(
        [
            "git",
            "clone",
            "--shared",
            "--no-checkout",
            str(REPO_ROOT),
            str(root),
        ],
        root.parent,
    )
    _git(root, "config", "user.name", "V076 Receipt Selftest")
    _git(root, "config", "user.email", "v076-receipt-selftest@example.invalid")
    _git(root, "sparse-checkout", "init", "--no-cone")
    _git(
        root,
        "sparse-checkout",
        "set",
        "--no-cone",
        f"/{contract.SCHEMA_AUTHORITY_PATH}",
        "/tools/v076/v076_current_subject_revalidation_receipt_selftest.py",
        f"/{contract.WORKFLOW_PATH}",
        f"/{contract.CURRENT_SUBJECT_MANIFEST_PATH}",
        f"/{contract.TOOLING_SEAL_PATH}",
        f"/{contract.RESUME_AUTHORIZATION_MANIFEST_PATH}",
        f"/{contract.SUCCESSOR_TOOLING_ROOT}/",
        "/reports/reuse/generation7_receipt_contract/",
        f"/{contract.RECEIPT_ROOT}/",
    )
    _git(root, "checkout", "--detach", contract.PREDECESSOR_RESUME_HEAD_SHA)
    _git(root, "checkout", "-b", "fixture-receipt-contract")

    (root / contract.SCHEMA_AUTHORITY_PATH).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(
        SCRIPT_DIR / "v076_current_subject_revalidation_receipt.py",
        root / contract.SCHEMA_AUTHORITY_PATH,
    )
    (root / contract.WORKFLOW_PATH).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(REPO_ROOT / contract.WORKFLOW_PATH, root / contract.WORKFLOW_PATH)
    (root / contract.PRODUCER_SCRIPT_PATH).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(
        SCRIPT_DIR / "v076_current_subject_revalidation_receipt_selftest.py",
        root / "tools/v076/v076_current_subject_revalidation_receipt_selftest.py",
    )
    frozen_paths = (
        contract.HARD_STOP_ATTESTATION_PATH,
        contract.EVIDENCE_9631_ATTESTATION_PATH,
        contract.FROZEN_INPUT_INVENTORY_PATH,
        contract.FROZEN_INPUT_SIDECAR_PATH,
    )
    for frozen_path in frozen_paths:
        (root / frozen_path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO_ROOT / frozen_path, root / frozen_path)
    copied_selftest_bytes = (
        root / "tools/v076/v076_current_subject_revalidation_receipt_selftest.py"
    ).read_bytes()
    negative_case_ids = contract._negative_case_ids_from_selftest_bytes(
        copied_selftest_bytes
    )
    catalog: dict[str, Any] = {
        "schema_version": contract.NEGATIVE_FIXTURE_CATALOG_SCHEMA_VERSION,
        "status": "PASS",
        "case_ids": negative_case_ids,
        "case_count": len(negative_case_ids),
        "pass_count": len(negative_case_ids),
        "false_green_count": 0,
        "case_id_set_sha256": contract._negative_case_id_set_sha256(
            negative_case_ids
        ),
        "canonical_payload_sha256": "",
    }
    catalog["canonical_payload_sha256"] = contract.canonical_payload_sha256(
        catalog
    )
    catalog_bytes = contract.canonical_json_bytes(catalog)
    dependency_inventory: dict[str, Any] = {
        "schema_version": contract.TOOL_DEPENDENCY_INVENTORY_SCHEMA_VERSION,
        "status": "PASS",
        "python_dependency_policy": "STDLIB_ONLY",
        "python_external_dependency_count": 0,
        "python_external_dependencies": [],
        "required_executable_count": 3,
        "required_executables": ["git", "pwsh", "python"],
        "canonical_payload_sha256": "",
    }
    dependency_inventory["canonical_payload_sha256"] = (
        contract.canonical_payload_sha256(dependency_inventory)
    )
    dependency_bytes = contract.canonical_json_bytes(dependency_inventory)
    _write(root / contract.NEGATIVE_FIXTURE_CATALOG_PATH, catalog_bytes)
    _write(root / contract.TOOL_DEPENDENCY_INVENTORY_PATH, dependency_bytes)
    _git(
        root,
        "add",
        "--",
        contract.SCHEMA_AUTHORITY_PATH,
        contract.WORKFLOW_PATH,
        "tools/v076/v076_current_subject_revalidation_receipt_selftest.py",
        contract.NEGATIVE_FIXTURE_CATALOG_PATH,
        contract.TOOL_DEPENDENCY_INVENTORY_PATH,
        *frozen_paths,
    )
    _git(root, "commit", "-m", "fixture tooling authority")

    module_bytes = (root / contract.SCHEMA_AUTHORITY_PATH).read_bytes()
    workflow_bytes = (root / contract.WORKFLOW_PATH).read_bytes()
    selftest_bytes = (
        root / "tools/v076/v076_current_subject_revalidation_receipt_selftest.py"
    ).read_bytes()
    seal: dict[str, Any] = {
        "schema_version": contract.TOOLING_SEAL_SCHEMA_VERSION,
        "status": "SEALED",
        "authorization_id": contract.AUTHORIZATION_ID,
        "base_head_sha": contract.AUTHORIZED_BASE_HEAD_SHA,
        "base_tree_sha": _git(
            root, "rev-parse", f"{contract.AUTHORIZED_BASE_HEAD_SHA}^{{tree}}"
        ).decode().strip(),
        "hard_stop_record_sha256": contract.AUTHORIZED_HARD_STOP_SHA256,
        "resume_generation_id": 7,
        "resume_evidence_id": 9631,
        "schema_sha256": contract.sha256_bytes(module_bytes),
        "validator_sha256": contract.sha256_bytes(module_bytes),
        "workflow_sha256": contract.sha256_bytes(workflow_bytes),
        "selftest_sha256": contract.sha256_bytes(selftest_bytes),
        "negative_fixture_catalog_sha256": contract.sha256_bytes(catalog_bytes),
        "tool_dependency_inventory_sha256": contract.sha256_bytes(dependency_bytes),
        "hard_stop_identity_attestation_sha256": contract.HARD_STOP_ATTESTATION_SHA256,
        "evidence_9631_identity_attestation_sha256": contract.EVIDENCE_9631_ATTESTATION_SHA256,
        "frozen_input_inventory_sha256": contract.FROZEN_INPUT_INVENTORY_SHA256,
        "frozen_input_sidecar_sha256": contract.FROZEN_INPUT_SIDECAR_SHA256,
        "required_check_context": contract.REQUIRED_CHECK_CONTEXT,
        "post_seal_input_mutation_count": 0,
        "canonical_payload_sha256": "",
    }
    seal["canonical_payload_sha256"] = contract.canonical_payload_sha256(seal)
    seal_bytes = contract.canonical_json_bytes(seal)
    _write(root / contract.TOOLING_SEAL_PATH, seal_bytes)
    _git(root, "add", "--", contract.TOOLING_SEAL_PATH)
    _git(root, "commit", "-m", "fixture tooling seal")
    def audit_bytes(audit_id: str, audit_scope: str) -> bytes:
        audit: dict[str, Any] = {
            "schema_version": contract.INDEPENDENT_AUDIT_SCHEMA_VERSION,
            "audit_id": audit_id,
            "audit_scope": audit_scope,
            "status": "GO",
            "p0_count": 0,
            "p1_count": 0,
            "schema_authority_sha256": contract.sha256_bytes(module_bytes),
            "validator_sha256": contract.sha256_bytes(module_bytes),
            "workflow_sha256": contract.sha256_bytes(workflow_bytes),
            "selftest_sha256": contract.sha256_bytes(selftest_bytes),
            "auditor_mode": "INDEPENDENT_READ_ONLY",
            "finding_count": 0,
            "findings": [],
            "canonical_payload_sha256": "",
        }
        audit["canonical_payload_sha256"] = contract.canonical_payload_sha256(
            audit
        )
        return contract.canonical_json_bytes(audit)

    audit_a_bytes = audit_bytes(
        "AUDIT_A", "RECEIPT_SCHEMA_AND_VALIDATOR_SAFETY"
    )
    audit_b_bytes = audit_bytes(
        "AUDIT_B", "REQUIRED_WORKFLOW_ENFORCEMENT"
    )
    _write(root / contract.AUDIT_A_PATH, audit_a_bytes)
    _write(root / contract.AUDIT_B_PATH, audit_b_bytes)
    _git(root, "add", "--", contract.AUDIT_A_PATH, contract.AUDIT_B_PATH)
    _git(root, "commit", "-m", "fixture independent audits")
    producer_tooling_head = _git(root, "rev-parse", "HEAD").decode().strip()
    producer_tooling_tree = _git(root, "rev-parse", "HEAD^{tree}").decode().strip()

    manifest_bytes = (root / contract.CURRENT_SUBJECT_MANIFEST_PATH).read_bytes()
    resume: dict[str, Any] = {
        "schema_version": contract.RESUME_AUTHORIZATION_SCHEMA_VERSION,
        "status": "SEALED",
        "authorization_id": contract.AUTHORIZATION_ID,
        "authorized_base_head": contract.AUTHORIZED_BASE_HEAD_SHA,
        "current_tooling_head": producer_tooling_head,
        "current_tooling_tree": producer_tooling_tree,
        "hard_stop_record_sha256": contract.AUTHORIZED_HARD_STOP_SHA256,
        "resume_generation_id": 7,
        "resume_evidence_id": 9631,
        "schema_sha256": contract.sha256_bytes(module_bytes),
        "validator_sha256": contract.sha256_bytes(module_bytes),
        "workflow_sha256": contract.sha256_bytes(workflow_bytes),
        "tooling_seal_sha256": contract.sha256_bytes(seal_bytes),
        "selftest_sha256": contract.sha256_bytes(selftest_bytes),
        "audit_a_sha256": contract.sha256_bytes(audit_a_bytes),
        "audit_b_sha256": contract.sha256_bytes(audit_b_bytes),
        "current_product_subject_head": contract.CURRENT_SUBJECT_HEAD_SHA,
        "current_product_subject_tree": contract.CURRENT_SUBJECT_TREE_SHA,
        "product_path_manifest_sha256": contract.sha256_bytes(manifest_bytes),
        "existing_generation7_evidence_inventory_sha256": (
            contract.FROZEN_EVIDENCE_INVENTORY_SHA256
        ),
        "resume_start_checkpoint": contract.RESUME_START_CHECKPOINT,
        "first_unexecuted_step": contract.RESUME_START_CHECKPOINT,
        "formal_resume_count": 1,
        "automatic_retry": False,
        "canonical_payload_sha256": "",
    }
    resume["canonical_payload_sha256"] = contract.canonical_payload_sha256(resume)
    resume_bytes = contract.canonical_json_bytes(resume)
    _write(root / contract.RESUME_AUTHORIZATION_MANIFEST_PATH, resume_bytes)
    _git(root, "add", "--", contract.RESUME_AUTHORIZATION_MANIFEST_PATH)
    _git(root, "commit", "-m", "fixture execution authorization")
    execution_head = _git(root, "rev-parse", "HEAD").decode().strip()
    execution_tree = _git(root, "rev-parse", "HEAD^{tree}").decode().strip()

    manifest = contract.load_json_strict_bytes(manifest_bytes)
    assert isinstance(manifest, dict)
    runtime_sha = {
        row["path"]: row["sha256"]
        for row in manifest["runtime_boundary_bindings"]
    }
    previous_receipt_bytes: bytes | None = None
    for ordinal, (step_id, receipt_path) in enumerate(
        contract.REQUIRED_RECEIPT_SPECS, start=1
    ):
        short = step_id.lower()
        evidence_root = f"{contract.RECEIPT_ROOT}/evidence/{short}"
        result_path = f"{evidence_root}/result.json"
        runtime_path = f"{evidence_root}/runtime.json"
        result_bytes = contract.canonical_json_bytes(
            {"step_id": step_id, "status": "PASS", "fixture": True}
        )
        runtime: dict[str, Any] = {
            "schema_version": contract.RUNTIME_EVIDENCE_SCHEMA_VERSION,
            "step_id": step_id,
            "generation_id": 7,
            "resume_evidence_id": 9631,
            "subject_head_sha": contract.CURRENT_SUBJECT_HEAD_SHA,
            "subject_tree_sha": contract.CURRENT_SUBJECT_TREE_SHA,
            "execution_head_sha": execution_head,
            "execution_tree_sha": execution_tree,
            "production_scene_path": "res://scenes/main.tscn",
            "execution_mode": "PRODUCTION_COMPOSITION",
            "diagnostic_only": False,
            "fixture_only": False,
            "mcp_tool_identity": "Funplay MCP 0.9.6",
            "mcp_protocol_version": "2025-11-25",
            "mcp_session_id": f"fixture-{short}",
            "godot_binary_sha256": contract.REQUIRED_GODOT_BINARY_SHA256,
            "project_godot_sha256": runtime_sha["project.godot"],
            "main_tscn_sha256": runtime_sha["scenes/main.tscn"],
            "runtime_composition_sha256": runtime_sha[
                "scenes/runtime/V075RuntimeComposition.tscn"
            ],
            "production_screen_sha256": runtime_sha[
                "scenes/ui/v075/V075SampleGameScreen.tscn"
            ],
            "session_started_at_utc": "2026-08-31T06:00:00Z",
            "session_ended_at_utc": "2026-08-31T06:01:00Z",
            "scene_started_via_mcp": True,
            "mcp_real_runtime_observed": True,
            "proof": _valid_step_proof(step_id),
            "canonical_payload_sha256": "",
        }
        runtime["canonical_payload_sha256"] = contract.canonical_payload_sha256(
            runtime
        )
        runtime_bytes = contract.canonical_json_bytes(runtime)
        _write(root / result_path, result_bytes)
        _write(root / runtime_path, runtime_bytes)
        receipt_id = f"v076-current-subject-{short}-fixture-{ordinal:08d}"
        artifacts = sorted(
            [
                {
                    "path": result_path,
                    "sha256": contract.sha256_bytes(result_bytes),
                    "size_bytes": len(result_bytes),
                },
                {
                    "path": runtime_path,
                    "sha256": contract.sha256_bytes(runtime_bytes),
                    "size_bytes": len(runtime_bytes),
                },
            ],
            key=lambda row: row["path"],
        )
        evidence_manifest = {
            "schema_version": contract.EVIDENCE_MANIFEST_SCHEMA_VERSION,
            "manifest_id": f"v076-{short}-fixture-evidence",
            "generation_id": 7,
            "resume_evidence_id": 9631,
            "receipt_id": receipt_id,
            "evidence_root": evidence_root,
            "artifact_count": len(artifacts),
            "artifacts": artifacts,
            "canonical_payload_sha256": "",
        }
        evidence_manifest["canonical_payload_sha256"] = (
            contract.canonical_payload_sha256(evidence_manifest)
        )
        evidence_manifest_bytes = contract.canonical_json_bytes(evidence_manifest)
        evidence_manifest_path = (
            f"{contract.RECEIPT_ROOT}/{short}_evidence_manifest.json"
        )
        _write(root / evidence_manifest_path, evidence_manifest_bytes)
        receipt = _base_receipt(step_id)
        receipt.update(
            {
                "receipt_id": receipt_id,
                "live_pr_head_sha": execution_head,
                "live_pr_tree_sha": execution_tree,
                "producer_tooling_head_sha": producer_tooling_head,
                "producer_tooling_tree_sha": producer_tooling_tree,
                "producer_script_sha256": contract.sha256_bytes(module_bytes),
                "schema_authority_sha256": contract.sha256_bytes(module_bytes),
                "validator_sha256": contract.sha256_bytes(module_bytes),
                "workflow_sha256": contract.sha256_bytes(workflow_bytes),
                "product_path_manifest_sha256": contract.sha256_bytes(manifest_bytes),
                "tooling_seal_sha256": contract.sha256_bytes(seal_bytes),
                "resume_authorization_manifest_sha256": contract.sha256_bytes(
                    resume_bytes
                ),
                "evidence_manifest_path": evidence_manifest_path,
                "evidence_manifest_sha256": contract.sha256_bytes(
                    evidence_manifest_bytes
                ),
                "mcp_runtime_evidence_path": runtime_path,
                "mcp_runtime_evidence_sha256": contract.sha256_bytes(runtime_bytes),
                "previous_receipt_sha256": (
                    None
                    if previous_receipt_bytes is None
                    else contract.sha256_bytes(previous_receipt_bytes)
                ),
            }
        )
        _finalize_receipt(receipt)
        receipt_bytes = contract.canonical_json_bytes(receipt)
        _write(root / receipt_path, receipt_bytes)
        previous_receipt_bytes = receipt_bytes
    _git(root, "add", "--", contract.RECEIPT_ROOT)
    _git(root, "commit", "-m", "fixture receipt successor")
    consumer_head = _git(root, "rev-parse", "HEAD").decode().strip()
    return execution_head, consumer_head


def _amend(repo: Path) -> str:
    _git(repo, "add", "-A", "--", contract.RECEIPT_ROOT, contract.SCHEMA_AUTHORITY_PATH)
    _git(repo, "commit", "--amend", "--no-edit")
    return _git(repo, "rev-parse", "HEAD").decode().strip()


def _repository_passes(repo: Path) -> bool:
    head = _git(repo, "rev-parse", "HEAD").decode().strip()
    report = contract.validate_repository(repo, head)
    return report.get("validator_status") == "PASS"


def _modify_receipt(
    repo: Path,
    step_id: str,
    mutate: Callable[[dict[str, Any]], None],
    *,
    update_chain: bool = False,
) -> None:
    path = repo / contract.REQUIRED_RECEIPT_PATH_BY_STEP[step_id]
    value = contract.load_json_strict_bytes(path.read_bytes())
    assert isinstance(value, dict)
    mutate(value)
    _finalize_receipt(value)
    path.write_bytes(contract.canonical_json_bytes(value))
    if update_chain:
        ordered = list(contract.REQUIRED_RECEIPT_SPECS)
        start = [step for step, _path in ordered].index(step_id)
        previous = path.read_bytes()
        for next_step, next_path in ordered[start + 1 :]:
            next_file = repo / next_path
            next_value = contract.load_json_strict_bytes(next_file.read_bytes())
            assert isinstance(next_value, dict)
            next_value["previous_receipt_sha256"] = contract.sha256_bytes(previous)
            _finalize_receipt(next_value)
            previous = contract.canonical_json_bytes(next_value)
            next_file.write_bytes(previous)


def _mutate_runtime_evidence(
    repo: Path,
    step_id: str,
    mutate: Callable[[dict[str, Any]], None],
    *,
    noncanonical_runtime: bool = False,
    noncanonical_manifest: bool = False,
) -> None:
    receipt_path = repo / contract.REQUIRED_RECEIPT_PATH_BY_STEP[step_id]
    receipt = contract.load_json_strict_bytes(receipt_path.read_bytes())
    assert isinstance(receipt, dict)
    runtime_path = repo / receipt["mcp_runtime_evidence_path"]
    runtime = contract.load_json_strict_bytes(runtime_path.read_bytes())
    assert isinstance(runtime, dict)
    mutate(runtime)
    runtime["canonical_payload_sha256"] = contract.canonical_payload_sha256(runtime)
    runtime_bytes = (
        (json.dumps(runtime, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        if noncanonical_runtime
        else contract.canonical_json_bytes(runtime)
    )
    runtime_path.write_bytes(runtime_bytes)

    manifest_path = repo / receipt["evidence_manifest_path"]
    manifest = contract.load_json_strict_bytes(manifest_path.read_bytes())
    assert isinstance(manifest, dict)
    for artifact in manifest["artifacts"]:
        if artifact["path"] == receipt["mcp_runtime_evidence_path"]:
            artifact["sha256"] = contract.sha256_bytes(runtime_bytes)
            artifact["size_bytes"] = len(runtime_bytes)
    manifest["canonical_payload_sha256"] = contract.canonical_payload_sha256(manifest)
    manifest_bytes = (
        (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        if noncanonical_manifest
        else contract.canonical_json_bytes(manifest)
    )
    manifest_path.write_bytes(manifest_bytes)

    _modify_receipt(
        repo,
        step_id,
        lambda value: value.update(
            mcp_runtime_evidence_sha256=contract.sha256_bytes(runtime_bytes),
            evidence_manifest_sha256=contract.sha256_bytes(manifest_bytes),
        ),
        update_chain=True,
    )


def _make_receipt_noncanonical(repo: Path, step_id: str) -> None:
    path = repo / contract.REQUIRED_RECEIPT_PATH_BY_STEP[step_id]
    value = contract.load_json_strict_bytes(path.read_bytes())
    assert isinstance(value, dict)
    raw = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    path.write_bytes(raw)
    ordered = list(contract.REQUIRED_RECEIPT_SPECS)
    start = [step for step, _path in ordered].index(step_id)
    previous = raw
    for _next_step, next_path in ordered[start + 1 :]:
        next_file = repo / next_path
        next_value = contract.load_json_strict_bytes(next_file.read_bytes())
        assert isinstance(next_value, dict)
        next_value["previous_receipt_sha256"] = contract.sha256_bytes(previous)
        _finalize_receipt(next_value)
        previous = contract.canonical_json_bytes(next_value)
        next_file.write_bytes(previous)


def _set_index_symlink(repo: Path, path: str) -> None:
    blob = _git(repo, "hash-object", "-w", "--stdin", input_bytes=b"outside-target\n").decode().strip()
    _git(repo, "update-index", "--add", "--cacheinfo", "120000", blob, path)
    _git(repo, "commit", "--amend", "--no-edit")


class _FakeProject:
    def __init__(self, data: bytes, before: bytes = b"before\n", after: bytes = b"after\n"):
        self.data = data
        self.before = before
        self.after = after

    def read_regular_file(self, head: str, path: str) -> bytes:
        if path.endswith("fixture.json"):
            return self.data
        return self.before if head == contract.CURRENT_SUBJECT_HEAD_SHA else self.after

    def changed_entries(self, _before: str, _after: str) -> list[tuple[str, str]]:
        return [("M", "scripts/v076/fixture_product.gd")]


def _mcp_landing_case(direct_count: int, expected_pass: bool) -> bool:
    before = b"before\n"
    after = b"after\n"
    landing_value: dict[str, Any] = {
        "schema_version": "space_syndicate.v076.mcp_product_landing_attestation.v1",
        "generation_id": 7,
        "resume_evidence_id": 9631,
        "subject_head_sha": contract.CURRENT_SUBJECT_HEAD_SHA,
        "subject_tree_sha": contract.CURRENT_SUBJECT_TREE_SHA,
        "execution_head_sha": _g("b"),
        "execution_tree_sha": _g("c"),
        "mcp_tool_identity": contract.REQUIRED_MCP_TOOL_IDENTITY,
        "mcp_protocol_version": contract.REQUIRED_MCP_PROTOCOL_VERSION,
        "production_scene_path": "res://scenes/main.tscn",
        "real_main_tscn_validation": "PASS_RUNTIME_OBSERVED",
        "direct_filesystem_product_edit_count": direct_count,
        "product_file_change_count": 1,
        "mcp_product_file_mutation_count": 1,
        "mcp_product_file_mutation_coverage_percent": 100,
        "mcp_post_edit_validation_count": 1,
        "mcp_post_edit_validation_coverage_percent": 100,
        "product_file_mutations": [
            {
                "path": "scripts/v076/fixture_product.gd",
                "change_type": "M",
                "before_sha256": contract.sha256_bytes(before),
                "after_sha256": contract.sha256_bytes(after),
                "mcp_operation_id": "fixture-operation-1",
                "validation_status": "PASS",
            }
        ],
        "canonical_payload_sha256": "",
    }
    landing_value["canonical_payload_sha256"] = contract.canonical_payload_sha256(
        landing_value
    )
    landing = contract.canonical_json_bytes(landing_value)
    value = _base_receipt()
    value["contains_godot_product_delta"] = True
    value["mcp_landing_manifest_path"] = (
        "reports/development/mcp_landing/fixture.json"
    )
    value["mcp_landing_manifest_sha256"] = contract.sha256_bytes(landing)
    _finalize_receipt(value)
    report = contract.ValidationReport()
    typed = contract._validate_receipt_schema(report, value, "fixture.receipt")
    if typed is None:
        return False
    contract._validate_mcp_landing(
        _FakeProject(landing, before, after),  # type: ignore[arg-type]
        _g("a"),
        typed,
        {value["mcp_landing_manifest_path"]},
        report,
    )
    passed = report.finish()["validator_status"] == "PASS"
    return passed is expected_pass


def _fake_catalog_count_rejected() -> bool:
    selftest_bytes = Path(__file__).read_bytes()
    case_ids = contract._negative_case_ids_from_selftest_bytes(selftest_bytes)
    value: dict[str, Any] = {
        "schema_version": contract.NEGATIVE_FIXTURE_CATALOG_SCHEMA_VERSION,
        "status": "PASS",
        "case_ids": case_ids,
        "case_count": len(case_ids) - 1,
        "pass_count": len(case_ids) - 1,
        "false_green_count": 0,
        "case_id_set_sha256": contract._negative_case_id_set_sha256(case_ids),
        "canonical_payload_sha256": "",
    }
    value["canonical_payload_sha256"] = contract.canonical_payload_sha256(value)
    report = contract.ValidationReport()
    contract._validate_negative_fixture_catalog(
        value, selftest_bytes, report, "fixture.catalog"
    )
    return report.finish()["validator_status"] == "FAIL"


def _malformed_dependency_inventory_rejected() -> bool:
    value: dict[str, Any] = {
        "schema_version": contract.TOOL_DEPENDENCY_INVENTORY_SCHEMA_VERSION,
        "status": "PASS",
        "python_dependency_policy": "ALLOW_UNDECLARED",
        "python_external_dependency_count": 0,
        "python_external_dependencies": [],
        "required_executable_count": 1,
        "required_executables": ["python"],
        "canonical_payload_sha256": "",
    }
    value["canonical_payload_sha256"] = contract.canonical_payload_sha256(value)
    report = contract.ValidationReport()
    contract._validate_tool_dependency_inventory(
        value, report, "fixture.dependency_inventory"
    )
    return report.finish()["validator_status"] == "FAIL"


def _missing_pwsh_dependency_rejected() -> bool:
    value: dict[str, Any] = {
        "schema_version": contract.TOOL_DEPENDENCY_INVENTORY_SCHEMA_VERSION,
        "status": "PASS",
        "python_dependency_policy": "STDLIB_ONLY",
        "python_external_dependency_count": 0,
        "python_external_dependencies": [],
        "required_executable_count": 2,
        "required_executables": ["git", "python"],
        "canonical_payload_sha256": "",
    }
    value["canonical_payload_sha256"] = contract.canonical_payload_sha256(value)
    report = contract.ValidationReport()
    contract._validate_tool_dependency_inventory(
        value, report, "fixture.dependency_inventory_missing_pwsh"
    )
    return report.finish()["validator_status"] == "FAIL"


def _audit_p1_no_go_rejected() -> bool:
    receipt_report = contract.ValidationReport()
    receipt = contract._validate_receipt_schema(
        receipt_report, _base_receipt(), "fixture.receipt"
    )
    if receipt is None:
        return False
    selftest_sha = _h("3")
    value: dict[str, Any] = {
        "schema_version": contract.INDEPENDENT_AUDIT_SCHEMA_VERSION,
        "audit_id": "AUDIT_A",
        "audit_scope": "RECEIPT_SCHEMA_AND_VALIDATOR_SAFETY",
        "status": "NO_GO",
        "p0_count": 0,
        "p1_count": 1,
        "schema_authority_sha256": receipt.schema_authority_sha256,
        "validator_sha256": receipt.validator_sha256,
        "workflow_sha256": receipt.workflow_sha256,
        "selftest_sha256": selftest_sha,
        "auditor_mode": "INDEPENDENT_READ_ONLY",
        "finding_count": 1,
        "findings": ["P1_FAIL_CLOSED_GAP"],
        "canonical_payload_sha256": "",
    }
    value["canonical_payload_sha256"] = contract.canonical_payload_sha256(value)
    report = contract.ValidationReport()
    contract._validate_independent_audit(
        value,
        "AUDIT_A",
        "RECEIPT_SCHEMA_AND_VALIDATOR_SAFETY",
        receipt,
        selftest_sha,
        report,
        "fixture.audit_a",
    )
    return report.finish()["validator_status"] == "FAIL"


def _unauthorized_resume_checkpoint_rejected() -> bool:
    report = contract.ValidationReport()
    contract._validate_resume_checkpoint(
        {
            "resume_start_checkpoint": "COMPLETE",
            "first_unexecuted_step": "COMPLETE",
        },
        report,
        "fixture.resume",
    )
    return report.finish()["validator_status"] == "FAIL"


def _dead_code_negative_declaration_rejected() -> bool:
    selftest_bytes = Path(__file__).read_bytes()
    declared = contract._negative_case_ids_from_selftest_bytes(selftest_bytes)
    return not contract._executed_negative_case_ids_match(
        declared[1:], selftest_bytes
    )


def _powershell_type_confusion_rejected() -> bool:
    script = r'''
$ErrorActionPreference = "Stop"
$receipt = '{"generation_id":"7","resume_evidence_id":"9631","receipt_count":"3","validated_receipt_count":"3","required_gate_consumer_fail_closed":"true","failure_codes":[],"receipt_bindings":[]}' | ConvertFrom-Json
$receiptInts = @("generation_id", "resume_evidence_id", "receipt_count", "validated_receipt_count")
$invalidReceiptInts = @($receiptInts | Where-Object {
  $property = $receipt.PSObject.Properties[[string]$_]
  $null -eq $property -or $property.Value -isnot [long]
})
$receiptBools = @("required_gate_consumer_fail_closed")
$invalidReceiptBools = @($receiptBools | Where-Object {
  $property = $receipt.PSObject.Properties[[string]$_]
  $null -eq $property -or $property.Value -isnot [bool]
})
$spr = '{"trust_set_parity":"true","identity_parity":"true","effective_authority_exposed":"true"}' | ConvertFrom-Json
$sprBools = @("trust_set_parity", "identity_parity", "effective_authority_exposed")
$invalidSprBools = @($sprBools | Where-Object {
  $property = $spr.PSObject.Properties[[string]$_]
  $null -eq $property -or $property.Value -isnot [bool]
})
$fingerprints = @(("a" * 64), ("a" * 64))
$uniqueFingerprints = @($fingerprints | Sort-Object -Unique)
$malformedFingerprints = @($fingerprints | Where-Object {
  $_ -isnot [string] -or $_ -cnotmatch '^[0-9a-f]{64}$'
})
if ($invalidReceiptInts.Count -eq 4 -and
    $invalidReceiptBools.Count -eq 1 -and
    $invalidSprBools.Count -eq 3 -and
    $fingerprints.Count -eq 2 -and
    $uniqueFingerprints.Count -eq 1 -and
    $malformedFingerprints.Count -eq 0) {
  exit 0
}
exit 1
'''
    try:
        _run(
            ["pwsh", "-NoProfile", "-NonInteractive", "-Command", script],
            REPO_ROOT,
        )
    except AssertionError:
        return False
    return True


def main() -> int:
    cases: list[tuple[str, str, Callable[[], bool]]] = []

    def positive(case_id: str, check: Callable[[], bool]) -> None:
        cases.append((case_id, "POSITIVE", check))

    def negative(case_id: str, rejected: Callable[[], bool]) -> None:
        cases.append((case_id, "NEGATIVE", rejected))

    positive("P01_TYPED_PASS_RECEIPT", lambda: _schema_accepts(_base_receipt()))
    positive(
        "P02_PROPERTY_ORDER_INDEPENDENT",
        lambda: contract.canonical_payload_sha256(_base_receipt())
        == contract.canonical_payload_sha256(
            dict(reversed(list(_base_receipt().items())))
        ),
    )
    positive("P03_EMPTY_FAILURE_CODES_ARRAY", lambda: _base_receipt()["failure_codes"] == [])
    positive(
        "P04_LEGAL_PREVIOUS_CHAIN_HASH",
        lambda: _schema_accepts(
            _mutated(lambda value: value.__setitem__("previous_receipt_sha256", _h("a")))
        ),
    )
    positive(
        "P05_REPO_RELATIVE_EVIDENCE_PATH",
        lambda: contract.normalize_repo_relative_path(
            _base_receipt()["evidence_manifest_path"]
        )
        == _base_receipt()["evidence_manifest_path"],
    )
    positive("P06_VALID_CURRENT_HEAD_FORMAT", lambda: contract._is_git_sha(_g("a")))
    positive("P07_GENERATION_7", lambda: _base_receipt()["generation_id"] == 7)
    positive("P08_EVIDENCE_ID_9631", lambda: _base_receipt()["resume_evidence_id"] == 9631)
    positive(
        "P09_TOOLING_NO_PRODUCT_LANDING_REQUIRED",
        lambda: _schema_accepts(_base_receipt())
        and _base_receipt()["mcp_landing_manifest_path"] is None,
    )
    positive(
        "P10_VERSIONED_EXTENSION_CONTAINER",
        lambda: _schema_accepts(
            _mutated(
                lambda value: value.__setitem__(
                    "extensions", {"space_syndicate.test.v1": {"value": 1}}
                )
            )
        ),
    )
    positive("P11_MCP_LANDING_ZERO_DIRECT_EDIT", lambda: _mcp_landing_case(0, True))
    positive(
        "P12_CANONICAL_ROUNDTRIP",
        lambda: contract.load_json_strict_bytes(
            contract.canonical_json_bytes(_base_receipt())
        )
        == _base_receipt(),
    )
    negative(
        "N92_AUDIT_P1_NO_GO_REJECTED",
        _audit_p1_no_go_rejected,
    )
    negative(
        "N93_NEGATIVE_FIXTURE_FAKE_COUNT_REJECTED",
        _fake_catalog_count_rejected,
    )
    negative(
        "N94_DEPENDENCY_INVENTORY_MALFORMED_REJECTED",
        _malformed_dependency_inventory_rejected,
    )
    negative(
        "N95_RESUME_CHECKPOINT_COMPLETE_REJECTED",
        _unauthorized_resume_checkpoint_rejected,
    )

    negative(
        "N01_SCHEMA_FIELD_MISSING",
        lambda: not _schema_accepts(_mutated(lambda value: value.pop("schema_version"))),
    )
    negative(
        "N02_UNKNOWN_SCHEMA_VERSION",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("schema_version", "unknown.v9"))
        ),
    )
    negative(
        "N03_RECEIPT_ID_MISSING",
        lambda: not _schema_accepts(_mutated(lambda value: value.pop("receipt_id"))),
    )
    negative(
        "N04_RECEIPT_ID_EMPTY",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("receipt_id", ""))
        ),
    )
    negative(
        "N05_GENERATION_MISSING",
        lambda: not _schema_accepts(_mutated(lambda value: value.pop("generation_id"))),
    )
    negative(
        "N06_GENERATION_STRING",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("generation_id", "7"))
        ),
    )
    negative(
        "N07_GENERATION_6",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("generation_id", 6))
        ),
    )
    negative(
        "N08_GENERATION_8",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("generation_id", 8))
        ),
    )
    negative(
        "N09_EVIDENCE_ID_MISSING",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.pop("resume_evidence_id"))
        ),
    )
    negative(
        "N10_EVIDENCE_ID_STRING",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("resume_evidence_id", "9631"))
        ),
    )
    negative(
        "N11_EVIDENCE_ID_WRONG",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("resume_evidence_id", 9630))
        ),
    )
    negative(
        "N12_SUBJECT_HEAD_MISSING",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.pop("subject_head_sha"))
        ),
    )
    negative(
        "N13_SUBJECT_HEAD_FORMAT",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("subject_head_sha", "bad"))
        ),
    )
    negative(
        "N14_SUBJECT_HEAD_STALE",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("subject_head_sha", _g("a")))
        ),
    )
    negative(
        "N15_SUBJECT_TREE_WRONG",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("subject_tree_sha", _g("a")))
        ),
    )
    negative(
        "N16_LIVE_HEAD_FORMAT",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("live_pr_head_sha", "bad"))
        ),
    )
    negative(
        "N17_REQUIRED_CONTEXT_WRONG",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__("required_check_context", "Optional Gate")
            )
        ),
    )
    negative(
        "N18_PRODUCER_SCRIPT_SHA256_FORMAT",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__("producer_script_sha256", "0" * 63)
            )
        ),
    )
    negative(
        "N19_VALIDATOR_SHA256_FORMAT",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("validator_sha256", "0" * 63))
        ),
    )
    negative(
        "N20_WORKFLOW_SHA256_FORMAT",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("workflow_sha256", "0" * 63))
        ),
    )
    negative(
        "N21_SCHEMA_AUTHORITY_SHA256_FORMAT",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__("schema_authority_sha256", "0" * 63)
            )
        ),
    )
    negative(
        "N22_PRODUCT_PATH_MANIFEST_SHA256_FORMAT",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__(
                    "product_path_manifest_sha256", "0" * 63
                )
            )
        ),
    )
    negative(
        "N23_TOOLING_SEAL_SHA256_FORMAT",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__("tooling_seal_sha256", "0" * 63)
            )
        ),
    )
    negative(
        "N24_RESUME_AUTHORIZATION_MANIFEST_SHA256_FORMAT",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__(
                    "resume_authorization_manifest_sha256", "0" * 63
                )
            )
        ),
    )
    negative(
        "N25_EVIDENCE_MANIFEST_SHA256_FORMAT",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__("evidence_manifest_sha256", "0" * 63)
            )
        ),
    )
    negative(
        "N26_EVIDENCE_MANIFEST_PATH_TRAVERSAL",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__(
                    "evidence_manifest_path", "../outside.json"
                )
            )
        ),
    )
    negative(
        "N27_EVIDENCE_MANIFEST_ABSOLUTE_PATH",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__(
                    "evidence_manifest_path", "C:/outside.json"
                )
            )
        ),
    )
    negative(
        "N28_PASS_FAILURE_COUNT_NONZERO",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.update(
                    failure_count=1,
                    pass_count=contract.EXPECTED_CHECK_COUNT_BY_STEP["STEP09"] - 1,
                    failure_codes=["FORGED_FAILURE"],
                )
            )
        ),
    )
    negative(
        "N29_PASS_FAILURE_CODES_NONEMPTY",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.update(
                    failure_count=1,
                    pass_count=contract.EXPECTED_CHECK_COUNT_BY_STEP["STEP09"] - 1,
                    failure_codes=["FORGED_FAILURE"],
                )
            )
        ),
    )
    negative(
        "N30_PASS_COUNT_MISMATCH",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__(
                    "pass_count", contract.EXPECTED_CHECK_COUNT_BY_STEP["STEP09"] - 1
                )
            )
        ),
    )
    negative(
        "N31_FAIL_NOT_CONSUMER_GREEN",
        lambda: not _consumer_accepts(
            _mutated(
                lambda value: value.update(
                    status="FAIL",
                    pass_count=contract.EXPECTED_CHECK_COUNT_BY_STEP["STEP09"] - 1,
                    failure_count=1,
                    failure_codes=["PRODUCT_FAILURE"],
                )
            )
        ),
    )
    negative(
        "N32_BLOCKED_NOT_CONSUMER_GREEN",
        lambda: not _consumer_accepts(
            _mutated(
                lambda value: value.update(
                    status="BLOCKED",
                    pass_count=contract.EXPECTED_CHECK_COUNT_BY_STEP["STEP09"] - 1,
                    failure_count=1,
                    failure_codes=["PRODUCT_BLOCKED"],
                )
            )
        ),
    )
    negative(
        "N33_FAILURE_CODES_STRING",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("failure_codes", "FAIL"))
        ),
    )
    negative(
        "N34_FAILURE_CODES_OBJECT",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("failure_codes", {"code": "FAIL"}))
        ),
    )
    negative(
        "N35_UNKNOWN_SECURITY_FIELD",
        lambda: not _schema_accepts(
            _mutated(lambda value: value.__setitem__("waive_hash_validation", True))
        ),
    )
    negative(
        "N36_TYPO_SUBJECT_HEAD",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: (
                    value.pop("subject_head_sha"),
                    value.__setitem__("subject_head_shaa", contract.CURRENT_SUBJECT_HEAD_SHA),
                )
            )
        ),
    )
    negative(
        "N37_CANONICAL_HASH_WRONG",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__("canonical_payload_sha256", _h("0")),
                finalize=False,
            )
        ),
    )
    negative(
        "N38_RESULT_FINGERPRINT_WRONG",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__("result_fingerprint_sha256", _h("0")),
                finalize=False,
            )
        ),
    )
    negative(
        "N39_PREVIOUS_CHAIN_FORMAT",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__("previous_receipt_sha256", "bad")
            )
        ),
    )
    negative(
        "N40_PRODUCT_DELTA_MISSING_MCP_LANDING",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__("contains_godot_product_delta", True)
            )
        ),
    )
    negative("N41_MCP_DIRECT_FILESYSTEM_EDIT", lambda: _mcp_landing_case(1, False))
    negative(
        "N42_PASS_UNCLEAN_PROCESS",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value["process_cleanup"].__setitem__("game_pid_after", 42)
            )
        ),
    )
    negative(
        "N43_NON_RFC3339_TIMESTAMP",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__(
                    "created_at_utc", "08/31/2026 06:00:00"
                )
            )
        ),
    )
    negative(
        "N44_JSON_DUPLICATE_KEY",
        lambda: _strict_rejected(b'{"status":"PASS","status":"FAIL"}'),
    )
    negative("N45_JSON_NONFINITE", lambda: _strict_rejected(b'{"value":NaN}'))
    negative("N46_JSON_TRUNCATED", lambda: _strict_rejected(b'{"value":'))
    negative("N47_JSON_NON_UTF8", lambda: _strict_rejected(b'{"value":"\xff"}'))
    negative(
        "N48_JSON_ARRAY_NOT_RECEIPT",
        lambda: not _schema_accepts(contract.load_json_strict_bytes(b"[]")),
    )
    negative(
        "N49_BACKSLASH_PATH",
        lambda: _path_rejected("reports\\outside.json"),
    )
    negative("N50_DOT_SEGMENT_PATH", lambda: _path_rejected("reports/../outside.json"))
    negative(
        "N68_RUNTIME_REQUIREMENT_FALSE",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.update(
                    requires_mcp_runtime_evidence=False,
                    mcp_runtime_evidence_path=None,
                    mcp_runtime_evidence_sha256=None,
                )
            )
        ),
    )
    negative(
        "N69_INVALID_CALENDAR_TIMESTAMP",
        lambda: not _schema_accepts(
            _mutated(
                lambda value: value.__setitem__(
                    "created_at_utc", "2026-99-99T25:00:00Z"
                )
            )
        ),
    )

    temp_context = tempfile.TemporaryDirectory(prefix="v076-receipt-selftest-")
    temp = temp_context.name
    if True:
        temp_root = Path(temp)
        base_repo = temp_root / "base"
        _build_repository_fixture(base_repo)
        positive("P13_FULL_REPOSITORY_VALID", lambda: _repository_passes(base_repo))

        def variant(name: str) -> Path:
            destination = temp_root / name
            shutil.copytree(base_repo, destination)
            return destination

        missing_receipt = variant("missing-receipt")
        (missing_receipt / contract.REQUIRED_RECEIPT_PATH_BY_STEP["STEP09"]).unlink()
        _amend(missing_receipt)
        negative("N51_RECEIPT_FILE_MISSING", lambda: not _repository_passes(missing_receipt))

        missing_evidence = variant("missing-evidence")
        missing_path = (
            missing_evidence
            / contract.RECEIPT_ROOT
            / "evidence"
            / "step09"
            / "result.json"
        )
        missing_path.unlink()
        _amend(missing_evidence)
        negative("N52_EVIDENCE_FILE_MISSING", lambda: not _repository_passes(missing_evidence))

        changed_evidence = variant("changed-evidence")
        changed_path = (
            changed_evidence
            / contract.RECEIPT_ROOT
            / "evidence"
            / "step09"
            / "result.json"
        )
        changed_path.write_bytes(b'{}\n')
        _amend(changed_evidence)
        negative("N53_EVIDENCE_FILE_HASH_WRONG", lambda: not _repository_passes(changed_evidence))

        duplicate_id = variant("duplicate-id")
        step09 = contract.load_json_strict_bytes(
            (duplicate_id / contract.REQUIRED_RECEIPT_PATH_BY_STEP["STEP09"]).read_bytes()
        )
        assert isinstance(step09, dict)
        _modify_receipt(
            duplicate_id,
            "STEP11",
            lambda value: value.__setitem__("receipt_id", step09["receipt_id"]),
            update_chain=True,
        )
        _amend(duplicate_id)
        negative("N54_DUPLICATE_RECEIPT_ID", lambda: not _repository_passes(duplicate_id))

        extra_receipt = variant("extra-receipt")
        extra_path = extra_receipt / contract.RECEIPT_ROOT / "extra_receipt.json"
        extra_path.write_bytes(contract.canonical_json_bytes(_base_receipt()))
        _amend(extra_receipt)
        negative("N55_EXTRA_RECEIPT_PATH", lambda: not _repository_passes(extra_receipt))

        stale_head = variant("stale-head")
        for step, _path in contract.REQUIRED_RECEIPT_SPECS:
            _modify_receipt(
                stale_head,
                step,
                lambda value: value.__setitem__("live_pr_head_sha", _g("a")),
                update_chain=True,
            )
        _amend(stale_head)
        negative("N56_STALE_EXECUTION_HEAD", lambda: not _repository_passes(stale_head))

        extra_delta = variant("extra-delta")
        (extra_delta / "unexpected.txt").write_text("not allowlisted\n", encoding="utf-8")
        _git(extra_delta, "add", "--sparse", "--", "unexpected.txt")
        _git(extra_delta, "commit", "--amend", "--no-edit")
        negative("N57_SUCCESSOR_EXTRA_DELTA", lambda: not _repository_passes(extra_delta))

        receipt_symlink = variant("receipt-symlink")
        _set_index_symlink(
            receipt_symlink, contract.REQUIRED_RECEIPT_PATH_BY_STEP["STEP09"]
        )
        negative("N58_RECEIPT_SYMLINK_REJECTED", lambda: not _repository_passes(receipt_symlink))

        evidence_symlink = variant("evidence-symlink")
        _set_index_symlink(
            evidence_symlink,
            f"{contract.RECEIPT_ROOT}/evidence/step09/result.json",
        )
        negative("N59_EVIDENCE_SYMLINK_REJECTED", lambda: not _repository_passes(evidence_symlink))

        schema_missing = variant("schema-missing")
        (schema_missing / contract.SCHEMA_AUTHORITY_PATH).unlink()
        _amend(schema_missing)
        negative("N60_SCHEMA_FILE_MISSING", lambda: not _repository_passes(schema_missing))

        runtime_missing_field = variant("runtime-missing-field")
        _mutate_runtime_evidence(
            runtime_missing_field, "STEP09", lambda value: value.pop("mcp_tool_identity")
        )
        _amend(runtime_missing_field)
        negative(
            "N70_RUNTIME_EXACT_FIELD_MISSING",
            lambda: not _repository_passes(runtime_missing_field),
        )

        runtime_noncanonical = variant("runtime-noncanonical")
        _mutate_runtime_evidence(
            runtime_noncanonical,
            "STEP09",
            lambda _value: None,
            noncanonical_runtime=True,
        )
        _amend(runtime_noncanonical)
        negative(
            "N71_RUNTIME_NONCANONICAL_BYTES",
            lambda: not _repository_passes(runtime_noncanonical),
        )

        step09_zero = variant("step09-zero")
        _mutate_runtime_evidence(
            step09_zero,
            "STEP09",
            lambda value: value["proof"].__setitem__(
                "monster_move_authority_receipt_count", 0
            ),
        )
        _amend(step09_zero)
        negative(
            "N72_STEP09_MONSTER_AUTHORITY_MISSING",
            lambda: not _repository_passes(step09_zero),
        )

        step09_parity = variant("step09-parity")
        _mutate_runtime_evidence(
            step09_parity,
            "STEP09",
            lambda value: value["proof"].__setitem__(
                "presentation_cue_finish_count", 2
            ),
        )
        _amend(step09_parity)
        negative(
            "N73_STEP09_EXACT_ONCE_PARITY",
            lambda: not _repository_passes(step09_parity),
        )

        step11_zero = variant("step11-zero")
        _mutate_runtime_evidence(
            step11_zero,
            "STEP11",
            lambda value: value["proof"].__setitem__(
                "before_after_quantity_receipt_count", 0
            ),
        )
        _amend(step11_zero)
        negative(
            "N74_STEP11_ASSET_BEFORE_AFTER_MISSING",
            lambda: not _repository_passes(step11_zero),
        )

        step11_parity = variant("step11-parity")
        _mutate_runtime_evidence(
            step11_parity,
            "STEP11",
            lambda value: value["proof"].__setitem__(
                "asset_delta_projection_count", 3
            ),
        )
        _amend(step11_parity)
        negative(
            "N75_STEP11_ASSET_EXACT_ONCE_PARITY",
            lambda: not _repository_passes(step11_parity),
        )

        step12_zero = variant("step12-zero")
        _mutate_runtime_evidence(
            step12_zero,
            "STEP12",
            lambda value: value["proof"].__setitem__(
                "allowed_field_manifest_count", 0
            ),
        )
        _amend(step12_zero)
        negative(
            "N76_STEP12_OBSERVATION_ALLOWLIST_MISSING",
            lambda: not _repository_passes(step12_zero),
        )

        step12_leak = variant("step12-leak")
        _mutate_runtime_evidence(
            step12_leak,
            "STEP12",
            lambda value: value["proof"].__setitem__("private_queue_disclosed", True),
        )
        _amend(step12_leak)
        negative(
            "N77_STEP12_PRIVATE_QUEUE_LEAK",
            lambda: not _repository_passes(step12_leak),
        )

        wrong_tool = variant("wrong-tool")
        _mutate_runtime_evidence(
            wrong_tool,
            "STEP09",
            lambda value: value.__setitem__("mcp_tool_identity", "Unknown MCP"),
        )
        _amend(wrong_tool)
        negative(
            "N78_MCP_TOOL_IDENTITY_MISMATCH",
            lambda: not _repository_passes(wrong_tool),
        )

        wrong_godot = variant("wrong-godot")
        _mutate_runtime_evidence(
            wrong_godot,
            "STEP09",
            lambda value: value.__setitem__("godot_binary_sha256", _h("0")),
        )
        _amend(wrong_godot)
        negative(
            "N79_GODOT_BINARY_IDENTITY_MISMATCH",
            lambda: not _repository_passes(wrong_godot),
        )

        runtime_after_receipt = variant("runtime-after-receipt")
        _mutate_runtime_evidence(
            runtime_after_receipt,
            "STEP09",
            lambda value: value.__setitem__(
                "session_ended_at_utc", "2026-08-31T07:00:00Z"
            ),
        )
        _amend(runtime_after_receipt)
        negative(
            "N80_RECEIPT_CREATED_BEFORE_RUNTIME_END",
            lambda: not _repository_passes(runtime_after_receipt),
        )

        receipt_noncanonical = variant("receipt-noncanonical")
        _make_receipt_noncanonical(receipt_noncanonical, "STEP09")
        _amend(receipt_noncanonical)
        negative(
            "N81_RECEIPT_NONCANONICAL_BYTES",
            lambda: not _repository_passes(receipt_noncanonical),
        )

        manifest_noncanonical = variant("manifest-noncanonical")
        _mutate_runtime_evidence(
            manifest_noncanonical,
            "STEP09",
            lambda _value: None,
            noncanonical_manifest=True,
        )
        _amend(manifest_noncanonical)
        negative(
            "N82_EVIDENCE_MANIFEST_NONCANONICAL_BYTES",
            lambda: not _repository_passes(manifest_noncanonical),
        )

        evidence_root_wrong = variant("evidence-root-wrong")
        evidence_receipt_path = (
            evidence_root_wrong
            / contract.REQUIRED_RECEIPT_PATH_BY_STEP["STEP09"]
        )
        evidence_receipt = contract.load_json_strict_bytes(
            evidence_receipt_path.read_bytes()
        )
        assert isinstance(evidence_receipt, dict)
        evidence_manifest_path = evidence_root_wrong / evidence_receipt[
            "evidence_manifest_path"
        ]
        evidence_manifest = contract.load_json_strict_bytes(
            evidence_manifest_path.read_bytes()
        )
        assert isinstance(evidence_manifest, dict)
        evidence_manifest["evidence_root"] = (
            f"{contract.RECEIPT_ROOT}/evidence/step11"
        )
        evidence_manifest["canonical_payload_sha256"] = (
            contract.canonical_payload_sha256(evidence_manifest)
        )
        evidence_manifest_bytes = contract.canonical_json_bytes(evidence_manifest)
        evidence_manifest_path.write_bytes(evidence_manifest_bytes)
        _modify_receipt(
            evidence_root_wrong,
            "STEP09",
            lambda value: value.__setitem__(
                "evidence_manifest_sha256",
                contract.sha256_bytes(evidence_manifest_bytes),
            ),
            update_chain=True,
        )
        _amend(evidence_root_wrong)
        negative(
            "N83_EVIDENCE_ROOT_WRONG_STEP",
            lambda: not _repository_passes(evidence_root_wrong),
        )

        seal_missing_field = variant("seal-missing-field")
        seal_path = seal_missing_field / contract.TOOLING_SEAL_PATH
        seal_value = contract.load_json_strict_bytes(seal_path.read_bytes())
        assert isinstance(seal_value, dict)
        seal_value.pop("required_check_context")
        seal_value["canonical_payload_sha256"] = contract.canonical_payload_sha256(
            seal_value
        )
        seal_path.write_bytes(contract.canonical_json_bytes(seal_value))
        _git(seal_missing_field, "add", "--", contract.TOOLING_SEAL_PATH)
        _git(seal_missing_field, "commit", "--amend", "--no-edit")
        negative(
            "N84_TOOLING_SEAL_REQUIRED_FIELD_MISSING",
            lambda: not _repository_passes(seal_missing_field),
        )

        resume_missing_field = variant("resume-missing-field")
        resume_path = (
            resume_missing_field / contract.RESUME_AUTHORIZATION_MANIFEST_PATH
        )
        resume_value = contract.load_json_strict_bytes(resume_path.read_bytes())
        assert isinstance(resume_value, dict)
        resume_value.pop("audit_b_sha256")
        resume_value["canonical_payload_sha256"] = contract.canonical_payload_sha256(
            resume_value
        )
        resume_path.write_bytes(contract.canonical_json_bytes(resume_value))
        _git(
            resume_missing_field,
            "add",
            "--",
            contract.RESUME_AUTHORIZATION_MANIFEST_PATH,
        )
        _git(resume_missing_field, "commit", "--amend", "--no-edit")
        negative(
            "N85_RESUME_MANIFEST_REQUIRED_FIELD_MISSING",
            lambda: not _repository_passes(resume_missing_field),
        )

        governance_descendant = variant("governance-descendant")
        governance_path = (
            governance_descendant
            / "reports/reuse/generation7_receipt_contract/descendant_note.json"
        )
        governance_path.write_bytes(contract.canonical_json_bytes({"note": "later"}))
        _git(
            governance_descendant,
            "add",
            "--sparse",
            "--",
            "reports/reuse/generation7_receipt_contract/descendant_note.json",
        )
        _git(governance_descendant, "commit", "-m", "fixture later governance")
        positive(
            "P19_LATER_GOVERNANCE_DESCENDANT_VALID",
            lambda: _repository_passes(governance_descendant),
        )

        artifact_drift = variant("artifact-drift")
        drift_path = artifact_drift / contract.REQUIRED_RECEIPT_PATH_BY_STEP["STEP09"]
        drift_path.write_bytes(drift_path.read_bytes() + b" ")
        _git(
            artifact_drift,
            "add",
            "--",
            contract.REQUIRED_RECEIPT_PATH_BY_STEP["STEP09"],
        )
        _git(artifact_drift, "commit", "-m", "fixture forbidden receipt drift")
        negative(
            "N86_ARTIFACT_BYTES_DRIFT_AFTER_APPEND",
            lambda: not _repository_passes(artifact_drift),
        )

        product_drift = variant("product-drift")
        project_bytes = _git(product_drift, "show", "HEAD:project.godot")
        _write(product_drift / "project.godot", project_bytes + b"\n; drift\n")
        _git(product_drift, "add", "--sparse", "--", "project.godot")
        _git(product_drift, "commit", "-m", "fixture forbidden product drift")
        negative(
            "N87_PRODUCT_PATH_DRIFT_AFTER_EXECUTION",
            lambda: not _repository_passes(product_drift),
        )

        unknown_product = variant("unknown-product")
        unknown_product_path = "scripts/v076/fixture_unregistered_owner.gd"
        _write(unknown_product / unknown_product_path, b"extends Node\n")
        _git(unknown_product, "add", "--sparse", "--", unknown_product_path)
        _git(unknown_product, "commit", "-m", "fixture unknown product")
        negative(
            "N88_UNKNOWN_PRODUCT_PATH_DRIFT",
            lambda: not _repository_passes(unknown_product),
        )

        replace_ref = variant("replace-ref")
        replace_head = _git(replace_ref, "rev-parse", "HEAD").decode().strip()
        replace_parent = _git(replace_ref, "rev-parse", "HEAD^").decode().strip()
        _git(
            replace_ref,
            "update-ref",
            f"refs/replace/{replace_head}",
            replace_parent,
        )
        negative(
            "N89_GIT_REPLACE_REF_REJECTED",
            lambda: not _repository_passes(replace_ref),
        )

        graft_repo = variant("graft")
        graft_head = _git(graft_repo, "rev-parse", "HEAD").decode().strip()
        graft_parent = _git(graft_repo, "rev-parse", "HEAD^").decode().strip()
        graft_path = graft_repo / ".git" / "info" / "grafts"
        graft_path.parent.mkdir(parents=True, exist_ok=True)
        graft_path.write_text(f"{graft_head} {graft_parent}\n", encoding="ascii")
        negative(
            "N90_GIT_GRAFT_REJECTED",
            lambda: not _repository_passes(graft_repo),
        )

        producer_mismatch = variant("producer-mismatch")
        producer_tree = _git(
            producer_mismatch,
            "rev-parse",
            f"{contract.AUTHORIZED_BASE_HEAD_SHA}^{{tree}}",
        ).decode().strip()
        for step, _path in contract.REQUIRED_RECEIPT_SPECS:
            _modify_receipt(
                producer_mismatch,
                step,
                lambda value, producer_tree=producer_tree: value.update(
                    producer_tooling_head_sha=contract.AUTHORIZED_BASE_HEAD_SHA,
                    producer_tooling_tree_sha=producer_tree,
                ),
                update_chain=True,
            )
        _amend(producer_mismatch)
        negative(
            "N91_PRODUCER_TOOLING_BYTES_MISMATCH",
            lambda: not _repository_passes(producer_mismatch),
        )

        frozen_attestation_tamper = variant("frozen-attestation-tamper")
        frozen_attestation_path = (
            frozen_attestation_tamper / contract.EVIDENCE_9631_ATTESTATION_PATH
        )
        frozen_attestation = contract.load_json_strict_bytes(
            frozen_attestation_path.read_bytes()
        )
        assert isinstance(frozen_attestation, dict)
        frozen_attestation["reserved_slot_consumed"] = True
        frozen_attestation_path.write_bytes(
            contract.canonical_json_bytes(frozen_attestation)
        )
        _git(
            frozen_attestation_tamper,
            "add",
            "--sparse",
            "--",
            contract.EVIDENCE_9631_ATTESTATION_PATH,
        )
        _git(
            frozen_attestation_tamper,
            "commit",
            "-m",
            "fixture forbidden frozen attestation tamper",
        )
        negative(
            "N96_FROZEN_ATTESTATION_TAMPER_REJECTED",
            lambda: not _repository_passes(frozen_attestation_tamper),
        )

        post_seal_selftest_drift = variant("post-seal-selftest-drift")
        selftest_drift_path = post_seal_selftest_drift / contract.SELFTEST_PATH
        selftest_drift_path.write_bytes(
            selftest_drift_path.read_bytes() + b"\n# forbidden post-seal drift\n"
        )
        _git(
            post_seal_selftest_drift,
            "add",
            "--sparse",
            "--",
            contract.SELFTEST_PATH,
        )
        _git(
            post_seal_selftest_drift,
            "commit",
            "-m",
            "fixture forbidden post-seal selftest drift",
        )
        negative(
            "N97_POST_SEAL_SELFTEST_BYTES_DRIFT_REJECTED",
            lambda: not _repository_passes(post_seal_selftest_drift),
        )

        post_seal_audit_drift = variant("post-seal-audit-drift")
        audit_drift_path = post_seal_audit_drift / contract.AUDIT_A_PATH
        audit_drift_path.write_bytes(audit_drift_path.read_bytes() + b" ")
        _git(
            post_seal_audit_drift,
            "add",
            "--sparse",
            "--",
            contract.AUDIT_A_PATH,
        )
        _git(
            post_seal_audit_drift,
            "commit",
            "-m",
            "fixture forbidden post-seal audit drift",
        )
        negative(
            "N98_POST_SEAL_AUDIT_BYTES_DRIFT_REJECTED",
            lambda: not _repository_passes(post_seal_audit_drift),
        )

        def predecessor_binding_rejected(repo: Path, expected_label: str) -> bool:
            head = _git(repo, "rev-parse", "HEAD").decode().strip()
            receipt_value = contract.load_json_strict_bytes(
                (repo / contract.REQUIRED_RECEIPT_PATH_BY_STEP["STEP09"]).read_bytes()
            )
            assert isinstance(receipt_value, dict)
            typed = contract.V076CurrentSubjectProductionRevalidationReceiptV1.from_mapping(
                receipt_value
            )
            report = contract.ValidationReport()
            contract._validate_seal_documents(
                contract.GitCommittedProject(repo),
                head,
                typed,
                report,
            )
            result = report.finish()
            return (
                "BOUND_FILE_SHA256_MISMATCH" in result["failure_codes"]
                and any(
                    expected_label in detail
                    for detail in result["hash_mismatches"]
                )
            )

        predecessor_seal_tamper = variant("predecessor-seal-tamper")
        predecessor_seal_path = (
            predecessor_seal_tamper / contract.PREDECESSOR_TOOLING_SEAL_PATH
        )
        predecessor_seal_path.write_bytes(
            predecessor_seal_path.read_bytes() + b" "
        )
        _git(
            predecessor_seal_tamper,
            "add",
            "--sparse",
            "--",
            contract.PREDECESSOR_TOOLING_SEAL_PATH,
        )
        _git(predecessor_seal_tamper, "commit", "--amend", "--no-edit")
        negative(
            "N107_PREDECESSOR_TOOLING_SEAL_TAMPER_REJECTED",
            lambda: predecessor_binding_rejected(
                predecessor_seal_tamper, "predecessor_tooling_seal"
            ),
        )

        predecessor_resume_tamper = variant("predecessor-resume-tamper")
        predecessor_resume_path = (
            predecessor_resume_tamper
            / contract.PREDECESSOR_RESUME_AUTHORIZATION_MANIFEST_PATH
        )
        predecessor_resume_path.write_bytes(
            predecessor_resume_path.read_bytes() + b" "
        )
        _git(
            predecessor_resume_tamper,
            "add",
            "--sparse",
            "--",
            contract.PREDECESSOR_RESUME_AUTHORIZATION_MANIFEST_PATH,
        )
        _git(predecessor_resume_tamper, "commit", "--amend", "--no-edit")
        negative(
            "N108_PREDECESSOR_RESUME_TAMPER_REJECTED",
            lambda: predecessor_binding_rejected(
                predecessor_resume_tamper, "predecessor_resume_authorization"
            ),
        )

    workflow_text = (REPO_ROOT / contract.WORKFLOW_PATH).read_text(encoding="utf-8")
    consumer_block = workflow_text.split(
        "      - name: Consume Generation 7 current-subject receipts (fail closed)", 1
    )[-1].split("\n      - name:", 1)[0]
    effective_gate_block = workflow_text.split(
        "      - name: Enforce Effective Gate", 1
    )[-1].split("\n      - name:", 1)[0]
    positive(
        "P14_REQUIRED_CHECK_NAME_UNCHANGED",
        lambda: workflow_text.startswith("name: V076 Reuse and Point-Inertia Gate\n")
        and workflow_text.count("    name: V076 Reuse and Point-Inertia Gate") == 1,
    )
    positive(
        "P15_SINGLE_REQUIRED_CONSUMER",
        lambda: workflow_text.count(
            "v076_current_subject_revalidation_receipt.py validate"
        )
        == 1,
    )
    positive(
        "P16_EXPLICIT_MANIFEST_INPUT",
        lambda: workflow_text.count(
            'current_subject_manifest = "reports/reuse/full_convergence/candidate_subject_manifest_ac5efcc5.json"'
        )
        == 1
        and workflow_text.count(
            '"current_subject_manifest_relative=$relative"'
        )
        == 1
        and consumer_block.count(
            "steps.full_convergence_inputs.outputs.current_subject_manifest_relative"
        )
        == 1
        and "steps.full_convergence_inputs.outputs.current_subject_manifest }}"
        not in consumer_block,
    )
    positive(
        "P17_VALIDATION_REPORT_ARTIFACT",
        lambda: "${{ runner.temp }}/v076-current-subject-receipt-validation.json"
        in workflow_text,
    )
    negative(
        "N61_CONSUMER_CONTINUE_ON_ERROR_ABSENT",
        lambda: "continue-on-error" not in consumer_block,
    )
    negative("N62_CONSUMER_OR_TRUE_ABSENT", lambda: "|| true" not in consumer_block)
    negative(
        "N63_CONSUMER_PATH_ONLY_ACCEPTANCE_ABSENT",
        lambda: "validated_receipt_count -ne 3" in effective_gate_block
        and "validator_status -cne $expectedReceiptStatus" in effective_gate_block,
    )
    negative(
        "N64_BYPASS_CHECK_ABSENT",
        lambda: workflow_text.count("jobs:") == 1
        and workflow_text.count("reuse-point-inertia-gate:") == 1,
    )
    negative(
        "N65_MANIFEST_ONLY_ACCEPTANCE_ABSENT",
        lambda: "required_gate_consumer_fail_closed -ne $true"
        in effective_gate_block,
    )
    negative(
        "N66_FAILURE_REPORT_ENFORCED",
        lambda: "CURRENT_SUBJECT_RECEIPT_VALIDATION_FAILED" in effective_gate_block,
    )
    negative(
        "N67_OLD_TOP_LEVEL_RECEIPT_NOT_DISCOVERED",
        lambda: "current_subject_step09_receipt.json" not in consumer_block,
    )
    positive(
        "P18_SINGLE_EFFECTIVE_GATE",
        lambda: workflow_text.count("      - name: Enforce Effective Gate") == 1,
    )
    positive(
        "P20_SPR_V6_SUCCESSOR_WIRED",
        lambda: workflow_text.count("subject_projection_revalidation_successor_v6")
        >= 4
        and "V076_SUBJECT_PROJECTION_SUCCESSOR_V6_TRUSTED_FINGERPRINT_COUNT"
        in effective_gate_block,
    )
    negative(
        "N99_RECEIPT_REPORT_FINAL_GATE_ENFORCED",
        lambda: all(
            token in effective_gate_block
            for token in (
                "steps.current_subject_receipt_consumer.outcome",
                "steps.current_subject_receipt_consumer.outputs.exit_code",
                "v076-current-subject-receipt-validation.json",
                "expected_consumer_head_sha",
                "validator_status",
                "required_gate_consumer_fail_closed",
                "$receiptExactIntegerFields",
                "$receiptExactBooleanFields",
                "$receiptFailureCodesProperty.Value -isnot [System.Array]",
                "$receiptBindingsProperty.Value -isnot [System.Array]",
                "CURRENT_SUBJECT_RECEIPT_VALIDATION_FAILED",
            )
        ),
    )
    negative(
        "N100_RECEIPT_FAILURE_BLOCKS_REUSE_ENFORCEMENT",
        lambda: workflow_text.count(
            "if: ${{ steps.current_subject_receipt_consumer.outputs.exit_code == '0' }}"
        )
        == 3,
    )
    negative(
        "N101_SPR_V6_ZERO_FIELD_OMISSION_REJECTED",
        lambda: all(
            token in effective_gate_block
            for token in (
                "$sprV6.PSObject.Properties",
                "$sprV6ExactBooleanFields",
                "cross_authority_overlap_count",
                "wildcard_count",
                "future_failure_auto_correction_count",
                "raw_historical_failure_count",
                "corrected_historical_failure_count",
                "subject_projection_successor_v6_corrected_historical_failure_count",
                "$verifiedSprV6Property.Value -isnot [System.Array]",
                "$verifiedSprV6UniqueFingerprints.Count -ne 2",
                "^[0-9a-f]{64}$",
            )
        ),
    )
    negative(
        "N102_RECEIPT_SEMANTIC_FAIL_REPORT_PRESERVED",
        lambda: "exit_code=$validatorExit" in consumer_block
        and "expectedValidatorStatus" in consumer_block
        and "CURRENT_SUBJECT_RECEIPT_VALIDATION_FAILED" not in consumer_block,
    )
    negative(
        "N103_CLASSIFIED_FALSE_GREEN_COUNTERS_ENFORCED",
        lambda: all(
            token in workflow_text
            for token in (
                "FROZEN_ATTESTATION_TAMPER_FALSE_GREEN_COUNT",
                "AUDIT_P1_NO_GO_FALSE_GREEN_COUNT",
                "NEGATIVE_FIXTURE_CATALOG_FALSE_GREEN_COUNT",
                "TOOL_DEPENDENCY_INVENTORY_FALSE_GREEN_COUNT",
                "RESUME_CHECKPOINT_FALSE_GREEN_COUNT",
                "POST_SEAL_INPUT_DRIFT_FALSE_GREEN_COUNT",
                "invalidClassifiedFalseGreenFields",
            )
        ),
    )
    negative(
        "N104_EXECUTED_NEGATIVE_SET_PARITY_REJECTS_DEAD_CODE",
        _dead_code_negative_declaration_rejected,
    )
    negative(
        "N105_WORKFLOW_TYPE_CONFUSION_RUNTIME_REJECTED",
        _powershell_type_confusion_rejected,
    )
    negative(
        "N106_DEPENDENCY_INVENTORY_PWSH_REQUIRED",
        _missing_pwsh_dependency_rejected,
    )

    results: list[dict[str, Any]] = []
    false_green_count = 0
    valid_false_reject_count = 0
    for case_id, kind, check in cases:
        detail = ""
        try:
            passed = bool(check())
        except Exception as exc:
            passed = False
            detail = f"{type(exc).__name__}:{exc}"
        if not passed:
            if kind == "NEGATIVE":
                false_green_count += 1
            else:
                valid_false_reject_count += 1
        results.append(
            {"case_id": case_id, "kind": kind, "status": "PASS" if passed else "FAIL", "detail": detail}
        )

    case_ids = [row["case_id"] for row in results]
    negative_ids = [row["case_id"] for row in results if row["kind"] == "NEGATIVE"]
    pass_count = sum(row["status"] == "PASS" for row in results)
    executed_negative_case_ids = sorted(negative_ids)
    executed_negative_set_matches = contract._executed_negative_case_ids_match(
        executed_negative_case_ids, Path(__file__).read_bytes()
    )
    executed_negative_set_sha256 = contract._negative_case_id_set_sha256(
        executed_negative_case_ids
    )

    def failed_count(*selected_case_ids: str) -> int:
        return sum(
            results[case_ids.index(case_id)]["status"] != "PASS"
            for case_id in selected_case_ids
        )

    temp_context.cleanup()
    payload = {
        "RECEIPT_CONTRACT_SELFTEST_STATUS": (
            "PASS"
            if pass_count == len(results)
            and len(results) == contract.REQUIRED_SELFTEST_CASE_COUNT
            and false_green_count == 0
            and valid_false_reject_count == 0
            and executed_negative_set_matches
            else "FAIL"
        ),
        "RECEIPT_CONTRACT_SELFTEST_CASE_COUNT": len(results),
        "RECEIPT_CONTRACT_SELFTEST_PASS_COUNT": pass_count,
        "FALSE_GREEN_COUNT": false_green_count,
        "VALID_RECEIPT_FALSE_REJECT_COUNT": valid_false_reject_count,
        "RECEIPT_CONTRACT_SELFTEST_NEGATIVE_CASE_COUNT": len(negative_ids),
        "EXECUTED_NEGATIVE_CASE_SET_MATCH": executed_negative_set_matches,
        "MISSING_RECEIPT_FALSE_GREEN_COUNT": int(
            results[case_ids.index("N51_RECEIPT_FILE_MISSING")]["status"] != "PASS"
        ),
        "MALFORMED_RECEIPT_FALSE_GREEN_COUNT": sum(
            row["status"] != "PASS"
            for row in results
            if row["case_id"] in {"N44_JSON_DUPLICATE_KEY", "N46_JSON_TRUNCATED", "N47_JSON_NON_UTF8"}
        ),
        "STALE_RECEIPT_FALSE_GREEN_COUNT": int(
            results[case_ids.index("N56_STALE_EXECUTION_HEAD")]["status"] != "PASS"
        ),
        "MISMATCHED_SUBJECT_FALSE_GREEN_COUNT": int(
            results[case_ids.index("N14_SUBJECT_HEAD_STALE")]["status"] != "PASS"
        ),
        "FAIL_RECEIPT_FALSE_GREEN_COUNT": int(
            results[case_ids.index("N31_FAIL_NOT_CONSUMER_GREEN")]["status"] != "PASS"
        ),
        "FROZEN_ATTESTATION_TAMPER_FALSE_GREEN_COUNT": failed_count(
            "N96_FROZEN_ATTESTATION_TAMPER_REJECTED"
        ),
        "AUDIT_P1_NO_GO_FALSE_GREEN_COUNT": failed_count(
            "N92_AUDIT_P1_NO_GO_REJECTED"
        ),
        "NEGATIVE_FIXTURE_CATALOG_FALSE_GREEN_COUNT": failed_count(
            "N93_NEGATIVE_FIXTURE_FAKE_COUNT_REJECTED"
        ),
        "TOOL_DEPENDENCY_INVENTORY_FALSE_GREEN_COUNT": failed_count(
            "N94_DEPENDENCY_INVENTORY_MALFORMED_REJECTED"
        ),
        "RESUME_CHECKPOINT_FALSE_GREEN_COUNT": failed_count(
            "N95_RESUME_CHECKPOINT_COMPLETE_REJECTED"
        ),
        "POST_SEAL_INPUT_DRIFT_FALSE_GREEN_COUNT": failed_count(
            "N97_POST_SEAL_SELFTEST_BYTES_DRIFT_REJECTED",
            "N98_POST_SEAL_AUDIT_BYTES_DRIFT_REJECTED",
        ),
        "CANONICAL_ROUNDTRIP_PARITY": results[
            case_ids.index("P12_CANONICAL_ROUNDTRIP")
        ]["status"]
        == "PASS",
        "CANONICAL_PROPERTY_ORDER_INDEPENDENT": results[
            case_ids.index("P02_PROPERTY_ORDER_INDEPENDENT")
        ]["status"]
        == "PASS",
        "SECURITY_FIELD_OMISSION_FALSE_ACCEPT_COUNT": int(
            results[case_ids.index("N01_SCHEMA_FIELD_MISSING")]["status"] != "PASS"
        ),
        "NEGATIVE_FIXTURE_CATALOG_SHA256": executed_negative_set_sha256,
        "case_failures": [row for row in results if row["status"] != "PASS"],
    }
    sys.stdout.buffer.write(contract.canonical_json_bytes(payload))
    return 0 if payload["RECEIPT_CONTRACT_SELFTEST_STATUS"] == "PASS" else 1


def _strict_rejected(data: bytes) -> bool:
    try:
        contract.load_json_strict_bytes(data)
    except contract.StrictJsonError:
        return True
    return False


def _path_rejected(path: str) -> bool:
    try:
        contract.normalize_repo_relative_path(path)
    except ValueError:
        return True
    return False


if __name__ == "__main__":
    raise SystemExit(main())
