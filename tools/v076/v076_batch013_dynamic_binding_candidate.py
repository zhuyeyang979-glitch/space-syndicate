"""Read-only source proof for exactly four frozen Batch013 dynamic failures.

This is a proposal builder, not correction authority. It emits no trusted map,
does not edit Registry or records, and cannot make the Required Gate green.
Monster's two manifest rows and Alpha01's five v4 bindings remain unchanged.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


SELF = "tools/v076/v076_batch013_dynamic_binding_candidate.py"
REGISTRY = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
EPOCH = "reports/reuse/correction_v2/epochs/full_convergence_20260827/"
AUTHORITY = {
    EPOCH + "baseline_raw_failure_report.json": "cfb84c08abacb294ea54ffc975f691869b33ac47a5d6a9f28377c54534f19166",
    EPOCH + "descendant_history_raw_da48a74b_003.json": "812bd75c2e81d21a1a13305d45bf1045b1518b964f83ae88c2dd4f29ecf8dfac",
    EPOCH + "descendant_history_supplement_da48a74b_003.json": "78129c68991c8cd975d46b4b9c6bb05fc3c752a6408e649bd65dac3b9ff6388e",
}
ANIMATION = "scripts/presentation/v076_presentation_animation_director.gd"
CARD = "scripts/card_art_view.gd"
SHOWCASE = "scripts/ui/showcase_director.gd"
REPAIR = "9f8659c8e3745c4f0c6bc398030c289e4291db31"
SOURCES = {
    ANIMATION: ("12a70d31e5c65704393bc211c3aae2594caaac900c441102b1fd0d205637183d", "component.current.v076_presentation_animation_director", "component.current.v075_runtime_owner"),
    CARD: ("529ec78292eedb25ebe80745d48bc9fef338589435340e027e6fc02df60e24e4", "component.current.card_art_view", "component.current.card_codex_public_source"),
    SHOWCASE: ("38bbceba56f7fd1ed2ed37ba6021db52a996fe5e9a6e62ff09a1099955e379c9", "component.current.showcase_director", "component.current.v075_runtime_owner"),
}
OWNERS = {
    "component.current.v075_runtime_owner": ("scripts/v075_runtime/v075_runtime_owner.gd", "current.v075_production_combat_candidate"),
    "component.current.card_codex_public_source": ("scripts/runtime/card_codex_public_source_service.gd", "current.card_codex_playerface_presentation"),
}
MEMBERSHIP_ROOT = "reports/reuse/full_convergence/generation10/dynamic_batch013_membership_001/"
MEMBERSHIP_HASHES = {
    "membership-candidate.json": "4448aef03026e9b7f4cef434d5ea243254836d2c24e5a5682910104e2710338a",
    "membership-review-independent.json": "fd347fcc520233ff32ec8a7bf442527f0719a1d6625146845b0577ef34b5b11c",
    "membership-review-primary.json": "276875b042301661724e24d65183396e822be642beb856bef3ff226a286159e4",
    "membership-seal.json": "82b6adec35a16b62321280dbf57900bc0798c92aeb03edb04c6cc43a9d3b5a3d",
}
CENSUS_ANCHOR = "a4223356bf790003c2ea3c12da757ee0019f3eac"
# This proposal is a cold snapshot, not a rule imposed on future Gate runs.
# A symbol scan alone cannot prove the absence of constructed reflective calls.
# Exact source-tree identity prevents new callers of *any* form in this proposal.
SOURCE_TREES = {
    "scripts": "1c8ad3ee4b4ec8b18e43ea2dfc643de7603a7fe3",
    "scenes": "9af41e1ff28189e5e728f4bc341845c0b30ee29c",
    "resources": "1a151f00b2f36e26170e456bf7f43ff876a05ccc",
}
RULE = "HISTORY_DYNAMIC_REFERENCE_UNRESOLVED"
RAW_BY_FP = {
    "V2F-484f80ea06603aa1d4f5bd09c2e4f76c042ab0cc93cb5b8d4d05597cce4c91b3": f"{RULE}:FileAccess.get_file_as_string:path:8208001e7be8->62ceba063d68:{ANIMATION}",
    "V2F-8400a56bb19a82b7c6fe8d8787f1105ff6a5e45d082d354ca0230a274f27f60c": f"{RULE}:ResourceLoader.exists:path:46b33bba77b3->e584cd4d8b0c:{CARD}",
    "V2F-901f12a032576f728531b5afd5dc79383236b14eb8406f456ec8b0a1cb13bccf": f"{RULE}:load:path:46b33bba77b3->e584cd4d8b0c:{CARD}",
    "V2F-8a2488ab99a870b530bc403762d2e9035a87313ca47af56b94a82a6ec6af27cc": f"{RULE}:FileAccess.get_file_as_string:path:8208001e7be8->62ceba063d68:{SHOWCASE}",
}
TESTS = (
    "tests/v076_presentation_animation_director_test.gd",
    "tests/art_identity_gate_test.gd",
    "tests/vertical_slice_showcase_test.gd",
)
WIRING = (
    "scenes/main.tscn",
    "scenes/ui/v075/V075SampleGameScreen.tscn",
    "scenes/ui/CardResolutionBanner.tscn",
    "scenes/ui/DistrictSupplyMarketCard.tscn",
    "scenes/ui/codex/CardCodexThumbnailCard.tscn",
)
SCHEMA = "space_syndicate.v076.batch013.dynamic_binding_candidate.v1"


class ProofError(ValueError):
    pass


def require(value: bool, code: str) -> None:
    if not value:
        raise ProofError(code)


def canonical(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def strict_json(value: bytes) -> dict[str, Any]:
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, item in items:
            require(key not in result, "DUPLICATE_JSON_KEY")
            result[key] = item
        return result
    result = json.loads(value.decode("utf-8"), object_pairs_hook=pairs)
    require(isinstance(result, dict), "JSON_OBJECT_REQUIRED")
    return result


def git(root: Path, *args: str) -> bytes:
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, check=False)
    require(result.returncode == 0, "GIT_READ_FAILED:" + ":".join(args))
    return result.stdout


def ref(root: Path, value: str) -> str:
    result = git(root, "rev-parse", "--verify", value).decode("ascii").strip()
    require(re.fullmatch(r"[0-9a-f]{40}", result) is not None, "INVALID_GIT_OBJECT")
    return result


def committed(root: Path, head: str, path: str, *, live: bool = False) -> bytes:
    require(not Path(path).is_absolute() and ".." not in Path(path).parts, "UNSAFE_REPO_PATH")
    payload = git(root, "show", f"{head}:{path}")
    if live:
        local = root / path
        require(local.resolve().is_relative_to(root.resolve()) and not local.is_symlink(), "REPO_PATH_ALIAS")
        require(local.is_file() and local.read_bytes() == payload, "DIRTY_AUTHORITY:" + path)
    return payload


def blob(root: Path, head: str, path: str, *, live: bool = False) -> dict[str, Any]:
    payload = committed(root, head, path, live=live)
    return {"path": path, "git_blob_oid": ref(root, f"{head}:{path}"), "sha256": sha(payload), "byte_count": len(payload)}


def function_text(source: str, name: str) -> str:
    match = re.search(r"^func " + re.escape(name) + r"\(.*?(?=^func |\Z)", source, re.M | re.S)
    require(match is not None, "FUNCTION_MISSING:" + name)
    return match.group(0)


def site(source: str, expression: str, function: str) -> dict[str, Any]:
    pattern = re.compile(r"(?<![\w.])" + re.escape(expression))
    locations = [(i + 1, match.start() + 1) for i, row in enumerate(source.splitlines()) for match in pattern.finditer(row)]
    require(len(locations) == 1, "CALLSITE_NOT_UNIQUE:" + expression)
    require(expression in function_text(source, function), "CALLSITE_FUNCTION_MISMATCH")
    return {"line": locations[0][0], "column": locations[0][1], "containing_function": function, "expression": expression}


def card_graph(source: str) -> dict[str, Any]:
    """Resolve only the already-reviewed constant calls and closed frame loop."""
    constants = dict(re.findall(r'^const ([A-Z0-9_]+) := "(res://[^"\n]+)"$', source, re.M))
    ready = function_text(source, "_ready")
    literal_calls = re.findall(r"_load_optional_texture\(([A-Z][A-Z0-9_]*)\)", ready)
    loop = '\tfor kind_variant in NIGHT_PATROL_FRAME_PATHS.keys():\n\t\tvar kind := String(kind_variant)\n\t\tnight_patrol_frame_textures[kind] = _load_optional_texture(String(NIGHT_PATROL_FRAME_PATHS[kind]))'
    require(ready.count(loop) == 1, "CARD_CLOSED_LOOP_MISMATCH")
    require(len(literal_calls) == 39 and len(set(literal_calls)) == 38, "CARD_LITERAL_CALL_CARDINALITY")
    require(ready.count("_load_optional_texture(") == 40, "CARD_STATIC_CALL_CARDINALITY")
    require(source.count("_load_optional_texture(") == 41, "CARD_EXTERNAL_HELPER_SITE")
    require(literal_calls.count("MOTH_KAIJUICE_KAIJU_PATH") == 2, "CARD_REPEATED_CALL_LOST")
    require(all(name in constants for name in literal_calls), "CARD_UNKNOWN_CONSTANT")
    dictionary = re.search(r"^const NIGHT_PATROL_FRAME_PATHS := \{\n(.*?)^\}", source, re.M | re.S)
    require(dictionary is not None, "CARD_DICTIONARY_MISSING")
    pairs = re.findall(r'^\t"([a-z_]+)": "(res://[^"\n]+)",$', dictionary.group(1), re.M)
    require(len(pairs) == 8 and len(dict(pairs)) == 8 and len({p[1] for p in pairs}) == 4, "CARD_DICTIONARY_CARDINALITY")
    require(len(dictionary.group(1).splitlines()) == 8, "CARD_DICTIONARY_UNKNOWN_EXPRESSION")
    expanded = [constants[name] for name in literal_calls] + [value for _, value in pairs]
    require(len(expanded) == 47 and len(set(expanded)) == 41, "CARD_EXPANDED_CARDINALITY")
    callsites = [{"line": i + 1, "text": line.strip()} for i, line in enumerate(source.splitlines()) if "_load_optional_texture(" in line and not line.startswith("func ")]
    return {
        "kind": "EXACT_FINITE_CONSTANTS_AND_DICTIONARY_LOOP",
        "static_callsite_count": 40, "literal_call_count": 39,
        "distinct_literal_constant_count": 38,
        "literal_calls_in_source_order": literal_calls,
        "constant_values": {key: constants[key] for key in sorted(set(literal_calls))},
        "dictionary_pairs_in_source_order": [list(pair) for pair in pairs],
        "loop_text": loop, "callsites": callsites,
        "expanded_invocation_count": 47, "unique_target_count": 41,
        "resolved_targets": sorted(set(expanded)),
        "exists_site": site(source, "ResourceLoader.exists(path)", "_load_optional_texture"),
        "load_site": site(source, "load(path)", "_load_optional_texture"),
        "image_fallback_site": site(source, "image.load(path)", "_load_optional_texture"),
    }


def animation_graph(source: str) -> dict[str, Any]:
    body = function_text(source, "load_cue_catalog")
    guard = '\tif path != CUE_CATALOG_PATH:\n\t\treturn false\n\tvar text := FileAccess.get_file_as_string(CUE_CATALOG_PATH)'
    require(guard in body and "FileAccess.get_file_as_string(path)" not in source, "ANIMATION_FIXED_PATH_GUARD")
    require('extends "res://scripts/ui/showcase_director.gd"' in source and "\tsuper._ready()" in function_text(source, "_ready"), "ANIMATION_SHOWCASE_INHERITANCE")
    require(source.count("FileAccess.get_file_as_string(") == 1, "ANIMATION_EXTRA_LOADER")
    return {
        "kind": "EXISTING_REPAIR_TO_FIXED_CONSTANT",
        "guard_text": guard,
        "current_site": site(source, "FileAccess.get_file_as_string(CUE_CATALOG_PATH)", "load_cue_catalog"),
        "ready_site": site(source, "load_cue_catalog(CUE_CATALOG_PATH)", "_ready"),
        "super_ready_site": site(source, "super._ready()", "_ready"),
        "resolved_targets": ["res://data/presentation/v076_animation_cue_catalog.json"],
    }


def showcase_graph(source: str) -> dict[str, Any]:
    require(source.count("load_sequence(") == 2 and source.count("FileAccess.get_file_as_string(") == 1, "SHOWCASE_EXTRA_CALL")
    require('const DEFAULT_SEQUENCE_PATH := "res://data/showcase/hearthstone_grade_sequence.json"' in source, "SHOWCASE_CONSTANT_CHANGED")
    return {
        "kind": "EXACT_SINGLE_CONSTANT_CALL",
        "current_site": site(source, "FileAccess.get_file_as_string(path)", "load_sequence"),
        "ready_site": site(source, "load_sequence(DEFAULT_SEQUENCE_PATH)", "_ready"),
        "resolved_targets": ["res://data/showcase/hearthstone_grade_sequence.json"],
    }


def bound_graph(path: str, source: bytes) -> dict[str, Any]:
    require(sha(source) == SOURCES[path][0], "CURRENT_SOURCE_DRIFT:" + path)
    return {CARD: card_graph, ANIMATION: animation_graph, SHOWCASE: showcase_graph}[path](source.decode("utf-8"))


def validate_owner_rows(registry: dict[str, Any], consumer: dict[str, Any], owner: str) -> dict[str, Any]:
    owner_path, domain = OWNERS[owner]
    require(consumer.get("owner_path") == owner_path and consumer.get("domain_id") == domain and consumer.get("reads_authority") is True, "REGISTRY_OWNER_PATH_DOMAIN_READS_MISMATCH")
    rows = [row for row in registry["component_inventory"] if row.get("component_id") == owner or row.get("path") == owner_path]
    require(len(rows) == 1, "REGISTRY_OWNER_NOT_UNIQUE")
    row = rows[0]
    expected = {"component_id": owner, "path": owner_path, "owner_component_id": owner, "owner_path": owner_path, "domain_id": domain, "component_role": "OWNER", "production_reachable": True, "reuse_disposition": "ADOPT_AS_OWNER", "reads_authority": True, "writes_authority": True}
    require(all(type(row.get(key)) is type(value) and row.get(key) == value for key, value in expected.items()), "REGISTRY_OWNER_IDENTITY_MISMATCH")
    return row


def validate_census(actual: list[str], expected: list[str]) -> None:
    require(actual == expected, "UNREVIEWED_SYMBOL_REFERENCE")


def validate_source_trees(actual: dict[str, str]) -> None:
    require(actual == SOURCE_TREES, "PROPOSAL_SOURCE_SNAPSHOT_DRIFT")


def derive(root: Path, head: str, *, require_committed_tool: bool = True) -> dict[str, Any]:
    head = ref(root, head)
    if require_committed_tool:
        committed(root, head, SELF, live=True)
    membership = {}
    for name, digest in MEMBERSHIP_HASHES.items():
        payload = committed(root, head, MEMBERSHIP_ROOT + name, live=True)
        require(sha(payload) == digest, "MEMBERSHIP_SEAL_INPUT_DRIFT:" + name)
        membership[name] = blob(root, head, MEMBERSHIP_ROOT + name)
    git(root, "merge-base", "--is-ancestor", CENSUS_ANCHOR, head)
    source_trees = {path: ref(root, head + ":" + path) for path in SOURCE_TREES}
    validate_source_trees(source_trees)
    require(not git(root, "diff", head, "--name-only", "--", *SOURCE_TREES).strip(), "DIRTY_PRODUCT_SOURCE_SNAPSHOT")
    untracked = git(root, "ls-files", "--others", "--exclude-standard", "--", *SOURCE_TREES).decode("utf-8").splitlines()
    require(all(path.endswith(".uid") for path in untracked), "UNTRACKED_PRODUCT_SOURCE")
    authority: dict[str, Any] = {}
    documents: dict[str, Any] = {}
    for path, expected in AUTHORITY.items():
        payload = committed(root, head, path, live=True)
        require(sha(payload) == expected, "FROZEN_AUTHORITY_DRIFT:" + path)
        documents[path] = strict_json(payload)
        authority[path] = blob(root, head, path)
    baseline = documents[EPOCH + "baseline_raw_failure_report.json"]
    raw_report = documents[EPOCH + "descendant_history_raw_da48a74b_003.json"]
    supplement = documents[EPOCH + "descendant_history_supplement_da48a74b_003.json"]
    registry = strict_json(committed(root, head, REGISTRY, live=True))
    graphs: dict[str, Any] = {}
    sources: dict[str, Any] = {}
    targets: dict[str, Any] = {}
    owner_proofs: dict[str, Any] = {}
    for path, (expected_sha, component, owner) in SOURCES.items():
        source = committed(root, head, path, live=True)
        require(sha(source) == expected_sha, "CURRENT_SOURCE_DRIFT:" + path)
        rows = [row for row in registry["component_inventory"] if row.get("component_id") == component or row.get("path") == path]
        require(len(rows) == 1, "REGISTRY_IDENTITY_NOT_UNIQUE:" + path)
        row = rows[0]
        require(row.get("component_id") == component and row.get("path") == path and row.get("owner_component_id") == owner, "REGISTRY_IDENTITY_MISMATCH")
        require(row.get("component_role") == "PRESENTATION" and row.get("reuse_disposition") == "ADAPT_AS_CONSUMER" and row.get("production_reachable") is True and row.get("writes_authority") is False, "REGISTRY_SEMANTIC_MISMATCH")
        require(all(row.get("owns_" + field) is False for field in ("identity", "presentation", "replay", "rng", "save", "tick")), "REGISTRY_NEW_OWNER_FORBIDDEN")
        owner_row = validate_owner_rows(registry, row, owner)
        owner_proofs[owner] = {"registry_row": owner_row, "registry_row_sha256": sha(canonical(owner_row)), "source_blob": blob(root, head, OWNERS[owner][0], live=True)}
        graph = bound_graph(path, source)
        graphs[path] = graph
        sources[path] = {**blob(root, head, path), "registry_row": row, "registry_row_sha256": sha(canonical(row))}
        for target in graph["resolved_targets"]:
            targets[target] = blob(root, head, target.removeprefix("res://"), live=True)
    identities: dict[str, Any] = {}
    for fingerprint, raw in RAW_BY_FP.items():
        require(fingerprint == "V2F-" + sha(f"V076_RAW_FAILURE_V2\nHISTORICAL\n{RULE}\n{raw}\n".encode()), "RAW_FINGERPRINT_MISMATCH")
        supplement_row = supplement.get("identity_binding_by_failure", {}).get(fingerprint, {})
        require(raw in baseline["failures"] or (raw in raw_report["failures"] and supplement_row.get("raw_failure") == raw), "FROZEN_RAW_IDENTITY_NOT_FOUND")
        _, loader, expression, transition, path = raw.split(":", 4)
        old_prefix, new_prefix = transition.split("->")
        old, new = ref(root, old_prefix), ref(root, new_prefix)
        require(ref(root, new + "^1") == old, "HISTORICAL_TRANSITION_NOT_DIRECT")
        historical_text = committed(root, new, path).decode("utf-8")
        function = "_load_optional_texture" if path == CARD else "load_cue_catalog" if path == ANIMATION else "load_sequence"
        identities[fingerprint] = {
            "raw_failure": raw, "rule_id": RULE,
            "source_transition_old_sha": old, "source_transition_new_sha": new,
            "historical_blob": blob(root, new, path),
            "historical_site": site(historical_text, loader + "(" + expression + ")", function),
            "component_id": SOURCES[path][1], "implementation_path": path,
            "recommended_disposition": "HISTORICAL_DYNAMIC_REFERENCE_RESOLVED",
            "legacy_dynamic_reference_ids": [], "legacy_dynamic_reference_rows": [],
        }
    repair_parent = ref(root, REPAIR + "^1")
    git(root, "merge-base", "--is-ancestor", REPAIR, head)
    before = committed(root, repair_parent, ANIMATION).decode("utf-8")
    after = committed(root, REPAIR, ANIMATION).decode("utf-8")
    require("FileAccess.get_file_as_string(path)" in before, "REPAIR_PARENT_SITE_MISSING")
    repair_guard = '\tif path != CUE_CATALOG_PATH:\n\t\treturn false\n\tvar text := FileAccess.get_file_as_string(CUE_CATALOG_PATH)'
    require(repair_guard in function_text(after, "load_cue_catalog"), "REPAIR_FIXED_PATH_GUARD_MISSING")
    require("FileAccess.get_file_as_string(path)" not in after, "REPAIR_DYNAMIC_SITE_REMAINS")
    def census(commit: str) -> list[str]:
        lines = git(root, "grep", "-n", "-E", "load_sequence|load_cue_catalog|_load_optional_texture", commit, "--", *SOURCE_TREES).decode("utf-8").splitlines()
        return [line.removeprefix(commit + ":") for line in lines]
    call_inventory = census(head)
    validate_census(call_inventory, census(CENSUS_ANCHOR))
    dependencies = {path: blob(root, head, path, live=True) for path in (*TESTS, *WIRING)}
    proof = {
        "schema_version": SCHEMA, "candidate_kind": "NON_AUTHORITATIVE_DYNAMIC_BINDING_REVIEW_INPUT",
        "authorization_id": "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827",
        "evaluated_head_sha": head, "evaluated_tree_sha": ref(root, head + "^{tree}"),
        "failure_count": 4, "failure_fingerprints": sorted(RAW_BY_FP),
        "failure_fingerprint_set_sha256": sha(("\n".join(sorted(RAW_BY_FP)) + "\n").encode()),
        "membership_authority": membership,
        "authority_inputs": authority, "registry_snapshot": blob(root, head, REGISTRY),
        "owner_proofs": owner_proofs,
        "current_sources": sources, "source_graphs": graphs, "target_blobs": targets,
        "failure_identity_by_fingerprint": identities,
        "animation_repair": {"commit": REPAIR, "parent_commit": repair_parent, "before": blob(root, repair_parent, ANIMATION), "after": blob(root, REPAIR, ANIMATION)},
        "production_symbol_inventory": call_inventory,
        "proposal_source_tree_snapshot": {"anchor_head": CENSUS_ANCHOR, "tree_oids": source_trees, "future_gate_wide_rule": False},
        "static_dependency_blobs": dependencies,
        "static_only": True, "runtime_tests_executed": False,
        "test_limitations": ["Art identity test uses retired Main interface; not current production evidence.", "Animation test checks catalog load and 31 cues, not direct alternate-path rejection.", "Symbol census alone is not a general proof about constructed reflection; this proposal additionally freezes the product source-tree snapshot."],
        "review_status": "PENDING", "go_claim": False, "trusted_fingerprint_count": 0,
        "official_write_count": 0, "product_write_count": 0,
        "registry_identity_substitution_allowed": False, "wildcard_membership_allowed": False,
        "future_auto_membership_allowed": False,
    }
    proof["candidate_payload_sha256"] = sha(canonical(proof))
    return proof


def validate_candidate(root: Path, candidate: Path) -> dict[str, Any]:
    payload = candidate.read_bytes()
    document = strict_json(payload)
    require(payload == canonical(document), "CANDIDATE_NOT_CANONICAL")
    expected = derive(root, str(document.get("evaluated_head_sha", "")))
    require(document == expected, "CANDIDATE_PROOF_MISMATCH")
    return {"status": "CANDIDATE_VALID", "go_claim": False, "trusted_fingerprint_count": 0, "candidate_file_sha256": sha(payload), "candidate_payload_sha256": document["candidate_payload_sha256"], "failure_count": 4}


def selftest(root: Path) -> dict[str, Any]:
    source = (root / CARD).read_text(encoding="utf-8")
    animation = (root / ANIMATION).read_text(encoding="utf-8")
    showcase = (root / SHOWCASE).read_text(encoding="utf-8")
    count = 0
    for parser, text in ((card_graph, source), (animation_graph, animation), (showcase_graph, showcase)):
        parser(text)
        count += 1
    cases = [
        (card_graph, source.replace('"moth_kaijuice_kaiju": _load_optional_texture(MOTH_KAIJUICE_KAIJU_PATH),', '"moth_kaijuice_kaiju": null,')),
        (card_graph, source.replace("String(NIGHT_PATROL_FRAME_PATHS[kind])", "unknown_path")),
        (card_graph, source.replace("NIGHT_PATROL_FRAME_PATHS.keys()", "runtime_keys()")),
        (card_graph, source.replace('"military_force": "res://assets/third_party/night_patrol/ui/card-frame-attack.png",\n', "")),
        (card_graph, source + "\nfunc bad():\n\t_load_optional_texture(extra)\n"),
        (card_graph, source.replace("_load_optional_texture(NIGHT_PATROL_SIGIL_PATH)", "_load_optional_texture(UNKNOWN_PATH)")),
        (animation_graph, animation.replace("FileAccess.get_file_as_string(CUE_CATALOG_PATH)", "FileAccess.get_file_as_string(path)")),
        (animation_graph, animation.replace("if path != CUE_CATALOG_PATH:", "if false:")),
        (animation_graph, animation.replace("\tsuper._ready()", "\tpass")),
        (showcase_graph, showcase + "\nfunc bad():\n\tload_sequence(extra)\n"),
        (showcase_graph, showcase.replace("hearthstone_grade_sequence.json", "unknown.json")),
    ]
    false_green = 0
    for parser, text in cases:
        try:
            parser(text)
        except ProofError:
            count += 1
        else:
            false_green += 1
    for path in SOURCES:
        payload = (root / path).read_bytes()
        bound_graph(path, payload)
        count += 1
        try:
            bound_graph(path, payload + b"\n# unreviewed source drift\n")
        except ProofError:
            count += 1
        else:
            false_green += 1
    extra_negative_count = 0
    approved_census = ["approved.gd:1:load_sequence(DEFAULT_SEQUENCE_PATH)"]
    for extra in (
        'caller.gd:2:director.call("load_sequence", arbitrary)',
        'caller.gd:2:director.callv("load_cue_catalog", arguments)',
        'caller.gd:2:Callable(director, "load_sequence").call(arbitrary)',
        'caller.gd:2:card.call("_load_optional_texture", arbitrary)',
    ):
        extra_negative_count += 1
        try:
            validate_census(approved_census + [extra], approved_census)
        except ProofError:
            count += 1
        else:
            false_green += 1
    for changed in ({**SOURCE_TREES, "scripts": "0" * 40}, {key: value for key, value in SOURCE_TREES.items() if key != "scenes"}):
        extra_negative_count += 1
        try:
            validate_source_trees(changed)
        except ProofError:
            count += 1
        else:
            false_green += 1
    registry = strict_json((root / REGISTRY).read_bytes())
    consumer = next(row for row in registry["component_inventory"] if row.get("path") == CARD)
    owner = SOURCES[CARD][2]
    validate_owner_rows(registry, consumer, owner)
    count += 1
    invalid_owners = []
    for key, value in (("owner_path", "scripts/other.gd"), ("domain_id", "other.domain"), ("reads_authority", False)):
        changed = dict(consumer)
        changed[key] = value
        invalid_owners.append((registry, changed))
    duplicate = copy.deepcopy(registry)
    duplicate["component_inventory"].append(copy.deepcopy(validate_owner_rows(registry, consumer, owner)))
    invalid_owners.append((duplicate, consumer))
    wrong_role = copy.deepcopy(registry)
    next(row for row in wrong_role["component_inventory"] if row.get("component_id") == owner)["component_role"] = "PRESENTATION"
    invalid_owners.append((wrong_role, consumer))
    for registry_case, consumer_case in invalid_owners:
        extra_negative_count += 1
        try:
            validate_owner_rows(registry_case, consumer_case, owner)
        except ProofError:
            count += 1
        else:
            false_green += 1
    require(false_green == 0, "NEGATIVE_FALSE_GREEN")
    return {"status": "PASS", "case_count": count, "negative_count": len(cases) + 3 + extra_negative_count, "false_green_count": false_green, "runtime_started": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path("."))
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("build-candidate")
    create.add_argument("--output", type=Path, required=True)
    check = sub.add_parser("validate-candidate")
    check.add_argument("--candidate", type=Path, required=True)
    sub.add_parser("self-test")
    args = parser.parse_args()
    root = args.project.resolve()
    try:
        if args.command == "self-test":
            result = selftest(root)
        elif args.command == "validate-candidate":
            result = validate_candidate(root, args.candidate)
        else:
            output = args.output.resolve()
            require(not output.is_relative_to(root), "EXTERNAL_REVIEW_STAGE_REQUIRED")
            require(not output.exists() and not output.parent.is_symlink(), "APPEND_ONLY_OUTPUT_REQUIRED")
            document = derive(root, "HEAD")
            output.parent.mkdir(parents=True, exist_ok=True)
            with output.open("xb") as stream:
                stream.write(canonical(document))
            result = validate_candidate(root, output)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, UnicodeError) as exc:
        print(json.dumps({"status": "FAIL", "failure": str(exc), "go_claim": False, "trusted_fingerprint_count": 0}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
