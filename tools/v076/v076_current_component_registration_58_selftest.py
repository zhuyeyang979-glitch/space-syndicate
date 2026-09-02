#!/usr/bin/env python3
"""Focused positive and fail-closed tests; never applies the candidate."""
from __future__ import annotations

import argparse
import base64
import copy
import json
from pathlib import Path
import tempfile
from unittest.mock import patch

import v076_current_component_registration_58_builder as builder


def run(root: Path, candidate_path: Path) -> dict:
    checks: list[dict] = []

    def check(name: str, result: bool) -> None:
        checks.append({"name": name, "pass": bool(result)})

    def rejected(name: str, callback, expected: str) -> None:
        try:
            callback()
        except (ValueError, builder.append.BuilderError) as error:
            check(name, expected in str(error))
        else:
            check(name, False)

    candidate_bytes = candidate_path.read_bytes()
    candidate = builder.append.strict_json_bytes(candidate_bytes, str(candidate_path))
    unsigned = copy.deepcopy(candidate)
    digest = unsigned.pop("candidate_payload_sha256")
    check("candidate payload digest", digest == builder.sha(builder.canonical(unsigned)))
    check("candidate creator bytes", candidate["creator_sha256"] == builder.sha(Path(builder.__file__).read_bytes()))
    head = candidate["evaluated_head_sha"]
    rebuilt = builder.project(root, head)
    check("fresh independent reconstruction matches exact candidate", rebuilt == unsigned)
    check("no formal reexecution", candidate["formal_step11_reexecution_count"] == 0)
    check("no official writes", candidate["official_write_count"] == 0)
    check("no green claims", all(candidate[key] is False for key in ("required_gate_green", "human_green", "production_green")))
    check("review still required", candidate["review_status"] == "PENDING" and candidate["required_reviews"] == ["PRIMARY", "INDEPENDENT"])
    raw = builder.append.strict_json_bytes(builder.projection.committed(root, builder.RAW_ARTIFACT_HEAD, builder.RAW_PATH), "raw")
    paths = builder.exact_paths(raw)
    rows = candidate["rows"]
    source = builder.projection.committed(root, head, builder.REGISTRY)
    before = builder.append.strict_json_bytes(source, builder.REGISTRY)
    ledger_source = builder.projection.committed(root, head, builder.LEDGER)
    ledger_before = builder.append.strict_json_bytes(ledger_source, builder.LEDGER)
    targets = {entry["path"]: entry for entry in candidate["target_files"]}
    target = base64.b64decode(targets[builder.REGISTRY]["target_bytes_base64"], validate=True)
    after = builder.append.strict_json_bytes(target, builder.REGISTRY)
    ledger_target = base64.b64decode(targets[builder.LEDGER]["target_bytes_base64"], validate=True)
    ledger_after = builder.append.strict_json_bytes(ledger_target, builder.LEDGER)
    check("exact two metadata targets", set(targets) == {builder.REGISTRY, builder.LEDGER})
    for relative, old, new in ((builder.REGISTRY, source, target), (builder.LEDGER, ledger_source, ledger_target)):
        entry = targets[relative]
        check("source digest:" + relative, entry["source_sha256"] == builder.sha(old) and entry["source_bytes"] == len(old))
        check("target digest:" + relative, entry["target_sha256"] == builder.sha(new) and entry["target_bytes"] == len(new))
    check("all existing component rows retained in order", after["component_inventory"][:-58] == before["component_inventory"])
    check("only inventory modified", {k:v for k,v in before.items() if k != "component_inventory"} == {k:v for k,v in after.items() if k != "component_inventory"})
    anchor = b'"component_inventory":' + builder.append.compact_canonical(before["component_inventory"])
    point = source.index(anchor) + len(anchor) - 1
    insertion_size = len(target) - len(source)
    check("all original registry bytes retained", target[:point] == source[:point] and target[point+insertion_size:] == source[point:])
    expected_ledger = copy.deepcopy(ledger_before)
    expected_ledger["canonical_change_scope"]["focused_tests"].extend(builder.FOCUSED_TESTS)
    check("only five focused tests appended", ledger_after == expected_ledger)
    check("57 passive textures", sum(row["component_role"] == "PRESENTATION" for row in rows) == 57)
    check("one reachable debug adapter", sum(row["component_role"] == "ADAPTER" and row["production_reachable"] for row in rows) == 1)
    check("zero authority flags added", all(row[key] is False for row in rows for key in ("writes_authority", "owns_rng", "owns_tick", "owns_save", "owns_replay", "owns_identity", "owns_presentation")))
    check("exact dependency list", [row["path"] for row in candidate["audited_dependency_bindings"]] == list(builder.AUDITED_DEPENDENCY_PATHS))
    check("dependency object equality", all(row["raw_head_git_object"] == row["evaluated_head_git_object"] for row in candidate["audited_dependency_bindings"]))
    check("all three executed helpers bound", len(candidate["execution_helper_bindings"]) == 3)
    texture_proofs = [p for p in candidate["source_proofs"] if p["path"] != builder.BRIDGE]
    check("all 57 texture bytes retained", len(texture_proofs) == 57 and all(p["source_sha256"] == p["raw_head_source_sha256"] == p["before_source_sha256"] == p["after_source_sha256"] for p in texture_proofs))
    check("all 57 import transitions exact", all(p["before_import_sha256"] != p["after_import_sha256"] == p["import_sha256"] for p in texture_proofs))
    for name, mutate, expected in (
        ("raw head drift", lambda r:r.update(head_sha="0"*40), "FROZEN_RAW_IDENTITY_INVALID"),
        ("raw failure list type", lambda r:r.update(failures={}), "FROZEN_RAW_IDENTITY_INVALID"),
        ("raw duplicate failure", lambda r:r["failures"].append(r["failures"][0]), "FROZEN_RAW_FAILURE_LIST_INVALID"),
        ("raw nonstring failure", lambda r:r["failures"].append(None), "FROZEN_RAW_FAILURE_LIST_INVALID"),
        ("missing exact member", lambda r:r["failures"].remove(next(x for x in r["failures"] if x.startswith("UNCLASSIFIED_NEW_COMPONENT:"))), "EXACT_CURRENT_MEMBER_COUNT_INVALID"),
        ("extra member", lambda r:r["failures"].append("UNCLASSIFIED_NEW_COMPONENT:assets/third_party/commercial/other.png.import"), "EXACT_CURRENT_MEMBER_COUNT_INVALID"),
    ):
        bad = copy.deepcopy(raw)
        mutate(bad)
        rejected(name, lambda:builder.exact_paths(bad), expected)
    bad = copy.deepcopy(raw)
    key = next(i for i,x in enumerate(bad["failures"]) if x.startswith("UNCLASSIFIED_NEW_COMPONENT:assets/"))
    bad["failures"][key] = "UNCLASSIFIED_NEW_COMPONENT:assets/third_party/commercial/other.png.import"
    rejected("same count different member", lambda:builder.exact_paths(bad), "EXACT_CURRENT_MEMBER_SET_INVALID")
    rejected("rows omitted", lambda:builder.validate_rows(before, rows[:-1], paths), "ROW_MEMBER_SET_INVALID")
    rejected("rows reordered", lambda:builder.validate_rows(before, list(reversed(rows)), paths), "ROW_MEMBER_SET_INVALID")
    for field in ("writes_authority", "owns_rng", "owns_tick", "owns_save", "owns_replay", "owns_identity", "owns_presentation", "production_reachable", "reads_authority"):
        bad_rows = copy.deepcopy(rows)
        bad_rows[0][field] = not bad_rows[0][field]
        rejected("row flag drift:"+field, lambda:builder.validate_rows(before, bad_rows, paths), "EXACT_COMPONENT_ROW_DRIFT")
    for field in ("component_id", "class_name", "path"):
        collision = copy.deepcopy(before)
        extra = copy.deepcopy(rows[0])
        extra.update(component_id="collision-id", class_name="collision-class", path="collision-path")
        extra[field] = rows[0][field]
        collision["component_inventory"].append(extra)
        rejected("identity collision:"+field, lambda:builder.validate_rows(collision, rows, paths), "REGISTRY_IDENTITY_COLLISION:"+field)
    for field, value in (("component_role","ADAPTER"), ("writes_authority",False), ("production_reachable",False), ("path","wrong.gd")):
        bad_before = copy.deepcopy(before)
        owner = next(row for row in bad_before["component_inventory"] if row["component_id"] == rows[0]["owner_component_id"])
        owner[field] = value
        rejected("owner binding drift:"+field, lambda:builder.validate_rows(bad_before, rows, paths), "EXISTING_OWNER_DOMAIN_BINDING_INVALID")
    rejected("unknown component kind", lambda:builder.component_row("scripts/foreign.gd"), "COMPONENT_PATH_OUTSIDE_EXACT_KINDS")
    rejected("registry document mismatch", lambda:builder.append_inventory(source, {}, rows), "REGISTRY_SOURCE_DOCUMENT_MISMATCH")
    rejected("empty append", lambda:builder.append_inventory(source, before, []), "REGISTRY_APPEND_EMPTY")
    pretty_source = json.dumps(before, ensure_ascii=False, sort_keys=True, indent=2).encode("utf-8")
    rejected("unknown serialization rejected", lambda:builder.append_inventory(pretty_source, before, rows), "SPLICE_ANCHOR_CARDINALITY_INVALID")
    rejected("focused scope replay rejected", lambda:builder.append_scope_tests(ledger_target), "FOCUSED_SCOPE_ALREADY_REGISTERED")
    def mock_git(_root, *args):
        return "" if args[0] == "diff" else "a"*40
    with patch.object(builder.projection, "git", side_effect=mock_git):
        check("stable dependency binding accepted", len(builder.bind_audited_dependencies(root, head)) == len(builder.AUDITED_DEPENDENCY_PATHS))
    with patch.object(builder.projection, "git", return_value="scripts/runtime/card_codex_public_source_service.gd"):
        rejected("changed product graph rejected", lambda:builder.bind_audited_dependencies(root, head), "AUDITED_PRODUCT_SOURCE_DRIFT")
    for changed_path in builder.AUDITED_DEPENDENCY_PATHS:
        def changed_git(_root, *args):
            if args[0] == "diff":
                return ""
            return "b"*40 if args[1] == head+":"+changed_path else "a"*40
        with patch.object(builder.projection, "git", side_effect=changed_git):
            rejected("dependency drift:"+changed_path, lambda:builder.bind_audited_dependencies(root, head), "AUDITED_DEPENDENCY_DRIFT:"+changed_path)
    with patch.object(builder.projection, "committed", return_value=b"changed helper"):
        rejected("executed helper drift rejected", lambda:builder.bind_execution_helpers(root, head), "EXECUTION_HELPER_WORKTREE_DRIFT")
    with tempfile.TemporaryDirectory(prefix="v076-current58-selftest-") as temporary:
        existing = Path(temporary)
        rejected("existing output refused", lambda:builder.projection._stage(root, existing), "OUTPUT_STAGE_MUST_BE_FRESH_NONEXISTENT")
        rejected("relative output refused", lambda:builder.projection._stage(root, Path("stage")), "STAGE_PATH_NOT_ABSOLUTE")
        rejected("in-repo output refused", lambda:builder.projection._stage(root, root/"unused-current58-stage"), "OUTPUT_STAGE_MUST_BE_OUTSIDE_PROJECT")
        fresh = existing/"fresh"
        check("fresh external output accepted without creation", builder.projection._stage(root, fresh) == fresh and not fresh.exists())
    return {"schema_version":"space_syndicate.v076.current_component_registration_58_selftest.v1", "status":"PASS" if all(c["pass"] for c in checks) else "FAIL", "passed":sum(c["pass"] for c in checks), "total":len(checks), "candidate_path":str(candidate_path), "candidate_sha256":builder.sha(candidate_bytes), "builder_sha256":builder.sha(Path(builder.__file__).read_bytes()), "selftest_sha256":builder.sha(Path(__file__).read_bytes()), "evaluated_head_sha":head, "checks":checks, "official_write_count":0, "formal_step11_reexecution_count":0}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = run(args.project.resolve(), args.candidate.resolve())
    if args.output:
        with args.output.open("xb") as stream:
            stream.write(builder.canonical(result))
    print(json.dumps(result))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
