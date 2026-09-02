#!/usr/bin/env python3
"""Project exactly the 58 current paths from frozen Generation 10 Gate 002.

This is a non-authoritative metadata builder, not a scanner or waiver. It
reuses the existing component contract and append-only Registry splice. It
writes only a fresh external candidate; applying either target remains the
coordinator's separately reviewed operation. No product file is written.
"""
from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any

import v076_reuse_point_inertia_gate as gate
import v076_reuse_full_convergence_batch_builder as append
import v076_reuse_full_convergence_batch010_registry_projection_builder as projection

RAW_ARTIFACT_HEAD = "144f846f14e30fb1053d8905acd9a906db968589"
RAW_EVALUATED_HEAD = "86fc75eb4c1ab7272c4f88d9184f2e3c75d0c2a4"
RAW_PATH = "reports/reuse/full_convergence/generation10/required_gate_attempt_002/v076-reuse-point-inertia-raw.json"
RAW_SHA256 = "5a31da74d96b225cffa4c9f34c243115c3b2cec51de7b5dafd1869796430b199"
SOURCE_REGISTRY_SHA256 = "6ac0bfe1c3725c628eb2de63d336a78c7215a0430aa29a6406f5f3da3cbba679"
PATH_SET_SHA256 = "f2bac7a28f7507d2eb2963735d46db07c146fed7bd6d05882849a64683fb4a79"
TEXTURE_PATH_SET_SHA256 = "428a1e5b696616cc6ee5f4c7b1106f3a1357d2da3dd13199f33ad35e8bf2f716"
REGISTRY = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
LEDGER = "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
BRIDGE = "addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd"
TEXTURE_PREFIX = "assets/third_party/commercial/"
FOCUSED_TESTS = (
    "commercial_presentation_catalog_contract_test",
    "commercial_planet_production_presentation_test",
    "funplay_mcp_runtime_event_cursor_contract_test",
    "funplay_mcp_file_handle_lifecycle_test",
    "v076_generation10_step11_runner_selftest",
)
SCHEMA = "space_syndicate.v076.current_component_registration_58_candidate.v1"
AUDITED_DEPENDENCY_PATHS = (
    "assets/third_party/commercial",
    "scenes/tools/commercial_art/components/models",
    "scenes/runtime/CardIllustrationCatalog.tscn",
    "resources/presentation/alpha01_card_illustration_catalog.tres",
    "scripts/presentation/card_illustration_catalog.gd",
    "scripts/presentation/card_illustration_catalog_resource.gd",
    "scripts/runtime/card_codex_public_source_service.gd",
    "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.json",
    "project.godot", "export_presets.cfg",
    "tools/release/build_windows_alpha01.ps1",
    "tools/release/check_release_safety.py",
    BRIDGE,
)
EXECUTION_HELPERS = (gate, append, projection)

def canonical(value: Any) -> bytes:
    return append.canonical(value)

def sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()

def line_set(values: list[str]) -> str:
    return sha(("\n".join(sorted(values)) + "\n").encode())

def exact_paths(report: dict[str, Any]) -> list[str]:
    failures = report.get("failures")
    if report.get("head_sha") != RAW_EVALUATED_HEAD or not isinstance(failures, list):
        raise ValueError("FROZEN_RAW_IDENTITY_INVALID")
    if not all(isinstance(item, str) for item in failures) or len(failures) != len(set(failures)):
        raise ValueError("FROZEN_RAW_FAILURE_LIST_INVALID")
    values = [item.split(":", 1)[1] for item in failures if item.startswith("UNCLASSIFIED_NEW_COMPONENT:")]
    if len(values) != 58:
        raise ValueError("EXACT_CURRENT_MEMBER_COUNT_INVALID")
    textures = [value[:-7] for value in values if value.endswith(".import") and value.startswith(TEXTURE_PREFIX)]
    paths = sorted(textures + [value for value in values if value == BRIDGE])
    if len(textures) != 57 or len(paths) != 58 or len(set(paths)) != 58:
        raise ValueError("EXACT_CURRENT_MEMBER_TYPES_INVALID")
    if line_set(textures) != TEXTURE_PATH_SET_SHA256 or line_set(paths) != PATH_SET_SHA256:
        raise ValueError("EXACT_CURRENT_MEMBER_SET_INVALID")
    return paths

def component_row(path: str) -> dict[str, Any]:
    bridge = path == BRIDGE
    if not bridge and not path.startswith(TEXTURE_PREFIX):
        raise ValueError("COMPONENT_PATH_OUTSIDE_EXACT_KINDS")
    suffix = re.sub(r"[^a-z0-9]+", "_", path[len(TEXTURE_PREFIX):].lower()).strip("_")
    return {
        "component_id": "component.current.funplay_mcp_runtime_bridge" if bridge else "component.current.commercial_asset_" + suffix,
        "class_name": "ANONYMOUS_PATH_BOUND:" + path,
        "path": path,
        "domain_id": "current.v075_production_combat_candidate" if bridge else "current.card_codex_playerface_presentation",
        "component_role": "ADAPTER" if bridge else "PRESENTATION",
        "production_reachable": True,
        "writes_authority": False,
        "reads_authority": bridge,
        "owns_rng": False, "owns_tick": False, "owns_save": False,
        "owns_replay": False, "owns_identity": False, "owns_presentation": False,
        "owner_component_id": "component.current.v075_runtime_owner" if bridge else "component.current.card_codex_public_source",
        "owner_path": "scripts/v075_runtime/v075_runtime_owner.gd" if bridge else "scripts/runtime/card_codex_public_source_service.gd",
        "reuse_disposition": "ADAPT_AS_CONSUMER",
        "reuse_source_ids": ["reuse.v075.combat_candidate"] if bridge else ["reuse.pr66.codex_playerface"],
        "reuse_candidates_considered": ["reuse.v075.combat_candidate"] if bridge else ["reuse.pr66.codex_playerface", "reuse.pr63.passive_projections"],
        "new_component_justification": (
            "Existing project autoload diagnostic adapter observes runtime state and forwards normal Godot input events to existing UI and V075 Runtime consumers; it does not directly mutate gameplay authority. Its request/event cursor and wall-clock polling are diagnostic state, not gameplay identity or Kernel tick/RNG/replay state. It remains reachable in the development production scene and disabled by the existing space_syndicate_release feature guard."
            if bridge else
            "Existing committed texture " + path + " is a passive presentation input in the existing CardIllustrationCatalog resource dependency closure under CardCodexPublicSourceService. This registration creates no gameplay, asset-quantity, card-definition, map, tick, RNG, save, replay, identity, or presentation Owner. External asset provenance and license remain with the existing Asset Reference Registry."
        ),
        "supersedes": [], "superseded_by": [],
        "change_class": "TOOLING_ONLY" if bridge else "PRODUCTION_COMPOSITION",
        "focused_test_ids": list(FOCUSED_TESTS[2:] if bridge else FOCUSED_TESTS[:2]),
        "golden_scenario_steps": [],
    }

def validate_rows(before: dict[str, Any], rows: list[dict[str, Any]], paths: list[str]) -> None:
    if len(rows) != 58 or [row.get("path") for row in rows] != paths:
        raise ValueError("ROW_MEMBER_SET_INVALID")
    reuse_ids = {row["reuse_id"] for row in before["reuse_entries"]}
    current = {row["component_id"]: row for row in before["component_inventory"]}
    domains = {row["domain_id"]: row for row in before["domain_inventory"]}
    for row, path in zip(rows, paths, strict=True):
        if row != component_row(path):
            raise ValueError("EXACT_COMPONENT_ROW_DRIFT:" + path)
        errors = gate._component_row_contract_failures(row, reuse_ids, path)
        if errors:
            raise ValueError("COMPONENT_CONTRACT:" + "|".join(errors))
        owner = current.get(row["owner_component_id"], {})
        domain = domains.get(row["domain_id"], {})
        if not (
            owner.get("component_role") == "OWNER"
            and owner.get("production_reachable") is True
            and owner.get("writes_authority") is True
            and owner.get("path") == row["owner_path"]
            and domain.get("owner_component_id") == row["owner_component_id"]
            and domain.get("lifecycle") == "ACTIVE_CURRENT_DOMAIN"
        ):
            raise ValueError("EXISTING_OWNER_DOMAIN_BINDING_INVALID:" + path)
    for field in ("component_id", "class_name", "path"):
        values = [row[field] for row in before["component_inventory"]] + [row[field] for row in rows]
        if len(values) != len(set(values)):
            raise ValueError("REGISTRY_IDENTITY_COLLISION:" + field)

def append_scope_tests(source: bytes) -> tuple[bytes, list[str]]:
    before = append.strict_json_bytes(source, LEDGER)
    focused = before["canonical_change_scope"]["focused_tests"]
    additions = [name for name in FOCUSED_TESTS if name not in focused]
    if not additions:
        raise ValueError("FOCUSED_SCOPE_ALREADY_REGISTERED")
    if not focused:
        raise ValueError("FOCUSED_SCOPE_EMPTY")
    anchor = ("      " + json.dumps(focused[-1]) + "\n    ],").encode()
    inserted = b",\n".join(("      " + json.dumps(name)).encode() for name in additions)
    replacement = ("      " + json.dumps(focused[-1]) + ",\n").encode() + inserted + b"\n    ],"
    target = append._splice_once(source, anchor, replacement, "EXACT_CURRENT58_FOCUSED_TEST_APPEND")
    after = append.strict_json_bytes(target, LEDGER)
    expected = copy.deepcopy(before)
    expected["canonical_change_scope"]["focused_tests"].extend(additions)
    if after != expected:
        raise ValueError("UNEXPECTED_LEDGER_MUTATION")
    if gate._change_scope_contract_failures(after["canonical_change_scope"], "current58", "FOCUSED"):
        raise ValueError("FOCUSED_SCOPE_CONTRACT_INVALID")
    return target, additions

def append_inventory(source: bytes, before: dict[str, Any], rows: list[dict[str, Any]]) -> bytes:
    """Append to the exact compact current inventory, preserving every old byte.

    Historical pretty-format builders retain their original splice contract.
    This candidate supports only the already committed compact serialization;
    unknown formatting, duplicate keys and unexpected surrounding edits fail.
    """
    if append.strict_json_bytes(source, REGISTRY) != before:
        raise ValueError("REGISTRY_SOURCE_DOCUMENT_MISMATCH")
    if not rows or not before.get("component_inventory"):
        raise ValueError("REGISTRY_APPEND_EMPTY")
    inventory = append.compact_canonical(before["component_inventory"])
    anchor = b'"component_inventory":' + inventory
    insertion = b"," + b",".join(append.compact_canonical(row) for row in rows)
    replacement = anchor[:-1] + insertion + b"]"
    target = append._splice_once(source, anchor, replacement, "EXACT_CURRENT58_COMPACT_INVENTORY_APPEND")
    expected = copy.deepcopy(before)
    expected["component_inventory"].extend(rows)
    if append.strict_json_bytes(target, REGISTRY) != expected:
        raise ValueError("UNEXPECTED_REGISTRY_MUTATION")
    return target

def bind_audited_dependencies(root: Path, head: str) -> list[dict[str, str]]:
    """Keep source claims tied to the independently audited frozen Raw inputs.

    A changed source graph requires new review, not automatic inheritance from
    unchanged leaf textures. The whole commercial asset tree binds GLTF JSON,
    buffers, materials, sky resources and every embedded-image source byte.
    """
    changed = projection.git(root, "diff", "--name-only", RAW_EVALUATED_HEAD, head).splitlines()
    product_changes = [path for path in changed if gate._is_product_component_path(path)]
    if product_changes:
        raise ValueError("AUDITED_PRODUCT_SOURCE_DRIFT:" + "|".join(product_changes))
    bindings = []
    for path in AUDITED_DEPENDENCY_PATHS:
        old_oid = projection.git(root, "rev-parse", RAW_EVALUATED_HEAD + ":" + path)
        new_oid = projection.git(root, "rev-parse", head + ":" + path)
        if old_oid != new_oid:
            raise ValueError("AUDITED_DEPENDENCY_DRIFT:" + path)
        bindings.append({"path":path, "raw_head_git_object":old_oid, "evaluated_head_git_object":new_oid})
    return bindings

def bind_execution_helpers(root: Path, head: str) -> list[dict[str, str]]:
    bindings = []
    for module in EXECUTION_HELPERS:
        path = Path(module.__file__).resolve()
        relative = path.relative_to(root).as_posix()
        committed = projection.committed(root, head, relative)
        if path.read_bytes() != committed:
            raise ValueError("EXECUTION_HELPER_WORKTREE_DRIFT:" + relative)
        bindings.append({"path":relative, "sha256":sha(committed)})
    return bindings

def project(root: Path, head: str) -> dict[str, Any]:
    head = projection.git(root, "rev-parse", head + "^{commit}")
    projection.git(root, "merge-base", "--is-ancestor", RAW_ARTIFACT_HEAD, head)
    helpers = bind_execution_helpers(root, head)
    raw_bytes = projection.committed(root, RAW_ARTIFACT_HEAD, RAW_PATH)
    if sha(raw_bytes) != RAW_SHA256:
        raise ValueError("FROZEN_RAW_BYTES_CHANGED")
    report = append.strict_json_bytes(raw_bytes, RAW_PATH)
    paths = exact_paths(report)
    source = projection.committed(root, head, REGISTRY)
    if sha(source) != SOURCE_REGISTRY_SHA256 or (root / REGISTRY).read_bytes() != source:
        raise ValueError("SOURCE_REGISTRY_BYTES_CHANGED")
    before = append.strict_json_bytes(source, REGISTRY)
    rows = [component_row(path) for path in paths]
    validate_rows(before, rows, paths)
    dependencies = bind_audited_dependencies(root, head)
    proofs = []
    import_before = projection.git(root, "rev-parse", "01d0818ddfe9^{commit}")
    import_after = projection.git(root, "rev-parse", "a79be8e622ed^{commit}")
    failures = set(report["failures"])
    for path in paths:
        current = projection.committed(root, head, path)
        at_raw = projection.committed(root, RAW_EVALUATED_HEAD, path)
        if current != at_raw:
            raise ValueError("CURRENT_SOURCE_DRIFT:" + path)
        proof = {"path":path, "source_sha256":sha(current), "raw_head_source_sha256":sha(at_raw)}
        if path != BRIDGE:
            sidecar = path + ".import"
            history = "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:01d0818ddfe9->a79be8e622ed:" + sidecar
            if history not in failures:
                raise ValueError("EXACT_IMPORT_TRANSITION_MISSING:" + path)
            old_source = projection.committed(root, import_before, path)
            new_source = projection.committed(root, import_after, path)
            if current != old_source or current != new_source:
                raise ValueError("TEXTURE_SOURCE_CHANGED:" + path)
            sidecar_now = projection.committed(root, head, sidecar)
            if sidecar_now != projection.committed(root, RAW_EVALUATED_HEAD, sidecar):
                raise ValueError("IMPORT_PARAMETER_DRIFT_AFTER_RAW:" + path)
            old_sidecar = projection.committed(root, import_before, sidecar)
            new_sidecar = projection.committed(root, import_after, sidecar)
            if sidecar_now != new_sidecar or old_sidecar == new_sidecar:
                raise ValueError("EXACT_IMPORT_METADATA_TRANSITION_INVALID:" + path)
            proof.update({"history_failure":history, "import_sha256":sha(sidecar_now), "before_import_sha256":sha(old_sidecar), "after_import_sha256":sha(new_sidecar), "before_source_sha256":sha(old_source), "after_source_sha256":sha(new_source)})
        proofs.append(proof)
    target = append_inventory(source, before, rows)
    after = append.strict_json_bytes(target, REGISTRY)
    expected = copy.deepcopy(before)
    expected["component_inventory"].extend(rows)
    if after != expected:
        raise ValueError("UNEXPECTED_REGISTRY_MUTATION")
    ledger_source = projection.committed(root, head, LEDGER)
    if (root / LEDGER).read_bytes() != ledger_source:
        raise ValueError("SOURCE_LEDGER_WORKTREE_DRIFT")
    ledger_target, added_tests = append_scope_tests(ledger_source)
    authority_paths = {
        "historical_reuse":[REGISTRY], "supersession":["docs/architecture/V076_SUPERSESSION_MAP.json"],
        "inherited_green":[LEDGER], "golden":["docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"],
        "card_matrix":["reports/card_certification/v076_card_certification_matrix.json"],
    }
    old_authorities = gate.load_baseline_authorities(root, head, authority_paths)
    new_authorities = copy.deepcopy(old_authorities)
    new_authorities["historical_reuse"] = after
    new_authorities["inherited_green"] = append.strict_json_bytes(ledger_target, LEDGER)
    monotonic_failures = gate._monotonic_transition_failures(old_authorities, new_authorities, "exact-current58-registration", [{"path":REGISTRY,"status":"M"},{"path":LEDGER,"status":"M"}])
    if monotonic_failures:
        raise ValueError("ORIGINAL_MONOTONIC_GUARD:" + "|".join(monotonic_failures))
    targets = []
    for relative, old, new in ((REGISTRY, source, target), (LEDGER, ledger_source, ledger_target)):
        targets.append({"path":relative, "source_sha256":sha(old), "target_sha256":sha(new), "source_bytes":len(old), "target_bytes":len(new), "target_bytes_base64":base64.b64encode(new).decode()})
    return {
        "schema_version":SCHEMA, "candidate_kind":"NON_AUTHORITATIVE_EXACT_CURRENT58_REGISTRATION",
        "evaluated_head_sha":head, "evaluated_tree_sha":projection.git(root,"rev-parse",head+"^{tree}"),
        "raw_report_path":RAW_PATH, "raw_report_sha256":RAW_SHA256, "raw_report_artifact_head":RAW_ARTIFACT_HEAD,
        "path_count":58, "texture_count":57, "debug_adapter_count":1, "path_set_sha256":PATH_SET_SHA256,
        "new_owner_count":0, "authority_flag_increase_count":0, "old_component_row_mutation_count":0,
        "old_stage_mutation_count":0, "canonical_status_mutation_count":0,
        "focused_tests_added":added_tests, "original_monotonic_guard_failures":monotonic_failures,
        "rows":rows, "source_proofs":proofs, "target_files":targets,
        "audited_dependency_source_head":RAW_EVALUATED_HEAD,
        "audited_dependency_bindings":dependencies,
        "execution_helper_bindings":helpers,
        "required_reviews":["PRIMARY","INDEPENDENT"], "review_status":"PENDING",
        "official_write_count":0, "formal_step11_reexecution_count":0,
        "required_gate_green":False, "human_green":False, "production_green":False,
        "creator_sha256":sha(Path(__file__).read_bytes()),
    }

def main(argv: list[str] | None = None) -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project",type=Path,default=Path.cwd())
    parser.add_argument("--head-ref",default="HEAD")
    parser.add_argument("--output-stage",type=Path,required=True)
    args=parser.parse_args(argv)
    try:
        root=args.project.resolve()
        stage=projection._stage(root,args.output_stage)
        document=project(root,args.head_ref)
        document["candidate_payload_sha256"]=sha(canonical(document))
        stage.mkdir(parents=True,exist_ok=False)
        output=stage/"current58_registration_candidate.json"
        with output.open("xb") as stream:
            stream.write(canonical(document))
        print(json.dumps({"status":"PASS","candidate":str(output),"candidate_sha256":sha(output.read_bytes()),"head":document["evaluated_head_sha"],"rows":len(document["rows"]),"official_write_count":0}))
        return 0
    except Exception as error:
        print(json.dumps({"status":"FAIL","failure":str(error)}))
        return 1

if __name__=="__main__":
    sys.exit(main())
