#!/usr/bin/env python3
"""V0.7.6 delta-only reuse and point-inertia gate.

This is deliberately a small aggregator.  It binds the existing architecture
sentinels and the one existing executable retired-mechanic scanner; it does not
reimplement their repository-wide rules and it never starts Godot or gameplay.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


CHECK_NAME = "V076 Reuse and Point-Inertia Gate"
ACTIVATION_BOUNDARY_COMMIT = "a80ad3e107491d03e8a1ccf5379fcb44c705f951"
V076_GATE_BASE_SHA = "f6fe547e1e1db57a8bb3a12eab1d9225d4abdca5"
PR_BASE_SHA = "770d741f05964facda4afcbddcdeb3e7f40571d5"

SCHEMA_PREFIXES = {
    "historical_reuse": "space_syndicate.v076.historical_reuse_registry.",
    "supersession": "space_syndicate.v076.supersession_map.",
    "inherited_green": "space_syndicate.v076.inherited_green_ledger.",
    "golden": "space_syndicate.v076.alpha07_golden_playtest_scenario.",
    "card_matrix": "space_syndicate.v076.card_certification_matrix.",
}

AUTHORITY_CONTRACTS = {
    "historical_reuse": (
        "space_syndicate.v076.historical_reuse_registry.v2",
        "registry_id",
        "v076-historical-reuse-registry-20260821",
    ),
    "supersession": (
        "space_syndicate.v076.supersession_map.v2",
        "map_id",
        "v076-supersession-map-20260821",
    ),
    "inherited_green": (
        "space_syndicate.v076.inherited_green_ledger.v2",
        "ledger_id",
        "v076-inherited-green-ledger-20260821",
    ),
    "golden": (
        "space_syndicate.v076.alpha07_golden_playtest_scenario.v1",
        "scenario_id",
        "v076-alpha07-golden-playtest-scenario-01",
    ),
    "card_matrix": (
        "space_syndicate.v076.card_certification_matrix.v2",
        "matrix_id",
        "v076-card-certification-matrix-20260821",
    ),
}

OWNER_MAP_SCHEMA = "space_syndicate.v076.owner_reuse_map.v1"
OWNER_MAP_REGISTRY_ID = "V076_OWNER_REUSE_MAP"

ALLOWED_COMPONENT_ROLES = {
    "OWNER",
    "REDUCER",
    "PORT",
    "ADAPTER",
    "CONSUMER",
    "PROJECTION",
    "PRESENTATION",
    "TEST_SUPPORT",
    "DIAGNOSTIC_BENCH",
    "TOOLING",
    "RETIRED",
}

ALLOWED_DISPOSITIONS = {
    "ADOPT_AS_OWNER",
    "ADAPT_AS_CONSUMER",
    "REUSE_AS_TEST",
    "REFERENCE_ONLY",
    "RETIRED",
}

DOMAIN_LIFECYCLES = {
    "ACTIVE_CURRENT_DOMAIN",
    "PENDING_FUTURE_DOMAIN",
    "RETIRED_DOMAIN",
    "REFERENCE_ONLY_DOMAIN",
}

ALLOWED_CHANGE_CLASSES = {
    "DOCS_ONLY",
    "TOOLING_ONLY",
    "TEST_ORACLE_ONLY",
    "DOMAIN_CORE",
    "CROSS_DOMAIN_INTEGRATION",
    "PRODUCTION_COMPOSITION",
    "RULESET_CONSTITUTION",
    "RELEASE_CANDIDATE",
}

ALLOWED_COMPONENT_CHANGE_CLASSES = ALLOWED_CHANGE_CLASSES | {"INHERITED"}

COMPONENT_AUTHORITY_INERTIA_FIELDS = (
    "production_reachable",
    "writes_authority",
    "reads_authority",
    "owns_rng",
    "owns_tick",
    "owns_save",
    "owns_replay",
    "owns_identity",
    "owns_presentation",
)

COMPONENT_REQUIRED_FIELDS = {
    "component_id",
    "class_name",
    "path",
    "domain_id",
    "component_role",
    "production_reachable",
    "writes_authority",
    "reads_authority",
    "owns_rng",
    "owns_tick",
    "owns_save",
    "owns_replay",
    "owns_identity",
    "owns_presentation",
    "owner_component_id",
    "owner_path",
    "reuse_disposition",
    "reuse_source_ids",
    "reuse_candidates_considered",
    "new_component_justification",
    "supersedes",
    "superseded_by",
    "change_class",
    "focused_test_ids",
    "golden_scenario_steps",
}

COMPONENT_BOOL_FIELDS = (
    "production_reachable",
    "writes_authority",
    "reads_authority",
    "owns_rng",
    "owns_tick",
    "owns_save",
    "owns_replay",
    "owns_identity",
    "owns_presentation",
)

COMPONENT_STRING_FIELDS = (
    "component_id",
    "class_name",
    "path",
    "domain_id",
    "owner_component_id",
    "owner_path",
    "new_component_justification",
)

COMPONENT_STRING_LIST_FIELDS = (
    "reuse_source_ids",
    "reuse_candidates_considered",
    "supersedes",
    "superseded_by",
    "focused_test_ids",
    "golden_scenario_steps",
)

CHANGE_SCOPE_BASE_FIELDS = {
    "change_classes",
    "affected_domains",
    "affected_owners",
    "focused_tests",
    "inherited_sentinels",
    "full_reproof_required",
    "full_reproof_trigger",
}

REUSE_SCAN_FIELDS = {
    "reuse_registry_search",
    "class_name_search",
    "semantic_signature_search",
    "owner_map_search",
    "state_write_surface_search",
    "rng_owner_search",
    "save_owner_search",
    "replay_owner_search",
    "signal_and_receipt_search",
    "reuse_candidate_count",
    "reuse_candidate_ids",
    "selected_reuse_disposition",
    "why_existing_owner_cannot_be_extended",
    "why_adapter_is_insufficient",
    "why_new_owner_is_required",
}

REPLACEMENT_REQUIRED_FIELDS = {
    "supersession_id",
    "kind",
    "domain_id",
    "old_component_id",
    "new_component_id",
    "old_owner_path",
    "new_owner_path",
    "replacement_reason",
    "migration_strategy",
    "consumer_inventory",
    "save_impact",
    "rng_impact",
    "replay_impact",
    "cutover_commit",
    "old_owner_retirement_status",
    "dual_write_count",
    "fallback_count",
    "old_owner_production_reachability",
    "new_owner_production_owner_count",
}

CARD_CERTIFICATION_FIELDS = (
    "CATALOG_VALID",
    "SEMANTIC_COMPILED",
    "TARGET_QUERY_GREEN",
    "PLAN_GREEN",
    "COMMIT_GREEN",
    "RECEIPT_GREEN",
    "PLAYER_PROJECTION_GREEN",
    "AI_PROJECTION_GREEN",
    "PRIVACY_GREEN",
    "EXACT_ONCE_GREEN",
    "REPLAY_GREEN",
    "ALPHA07_CERTIFIED",
)

SCANNER_INVENTORY = (
    {
        "scanner_id": "architecture",
        "path": "tests/main_gd_architecture_gate_test.gd",
        "reuse_mode": "INHERITED_SENTINEL",
    },
    {
        "scanner_id": "semantic_architecture",
        "path": "tests/game_action_semantic_protocol_v1_test.gd",
        "reuse_mode": "INHERITED_SENTINEL",
    },
    {
        "scanner_id": "owner",
        "path": "scripts/diagnostics/runtime_authority_audit.gd",
        "reuse_mode": "INHERITED_SENTINEL",
    },
    {
        "scanner_id": "main_retirement",
        "path": "tools/rules/check_v06_mechanic_authority.py",
        "reuse_mode": "EXECUTED_STATIC_SCANNER",
    },
    {
        "scanner_id": "privacy",
        "path": "tests/player_facing_privacy_boundary_test.gd",
        "reuse_mode": "INHERITED_SENTINEL",
    },
    {
        "scanner_id": "card_semantic",
        "path": "tests/card_semantic_architecture_scan_test.gd",
        "reuse_mode": "INHERITED_SENTINEL",
    },
    {
        "scanner_id": "production_composition",
        "path": "tests/main_runtime_composition_test.gd",
        "reuse_mode": "INHERITED_SENTINEL",
    },
)

STATUS_KEYS = (
    "stage_1_status",
    "stage_2_status",
    "stage_3_status",
    "stage_1_ledger_status",
    "stage_2_ledger_status",
    "stage_3_ledger_status",
    "historical_reuse_status",
    "point_inertia_status",
    "golden_isolated_green_count",
    "golden_production_green_count",
    "golden_human_green_count",
    "production_cutover_status",
    "latest_completed_stage",
    "next_stage",
)

STAGE_STATUS_VALUES = {
    "ISOLATED_GREEN",
    "PRODUCTION_GREEN",
    "HUMAN_GREEN",
    "REGRESSED_WITH_EVIDENCE",
}

LEDGER_STATUS_VALUES = {
    "INHERITED_GREEN",
    "CURRENT_DELTA_GREEN",
    "REGRESSED_WITH_EVIDENCE",
}

CANONICAL_STAGE_IDS = (
    "V076_STAGE_1_DETERMINISTIC_KERNEL",
    "V076_STAGE_2_SHARED_HALF_EDGE_SPHERICAL_PARTITION",
    "V076_STAGE_3_DETERMINISTIC_MONSTER_L1_DIRECTIONAL_GEODESIC_MOVE",
)

REQUIRED_TOOLING_FOCUSED_TESTS = {
    "v076_reuse_point_inertia_gate_selftest",
    "v076_reuse_point_inertia_gate_validate",
    "check_v06_mechanic_authority_selftest",
}

TOOLING_DOC_PREFIXES = (
    ".github/",
    "docs/",
    "reports/",
    "tools/v076/",
)

PRODUCT_COMPONENT_ROOTS = (
    "scripts/",
    "scenes/",
    "resources/",
    "data/",
    "shaders/",
    "themes/",
    "assets/",
    "addons/",
    "localization/",
)

NON_PRODUCT_COMPONENT_PREFIXES = (
    "scripts/tools/",
    "scripts/tests/",
    "scripts/test_support/",
    "scripts/editor/",
    "scenes/tools/",
    "scenes/diagnostics/",
    "scenes/tests/",
    "scenes/test_support/",
    "resources/tools/",
    "resources/diagnostics/",
    "resources/tests/",
    "resources/test_support/",
    "data/tools/",
    "data/diagnostics/",
    "data/tests/",
    "data/test_support/",
    "addons/codex_mcp_companion/",
    "addons/godot_mcp/",
    "addons/space_syndicate_design_qa/",
    "addons/funplay_mcp/core/",
    "addons/funplay_mcp/ui/",
)

NON_PRODUCT_COMPONENT_PATHS = {
    "scripts/diagnostics/runtime_authority_audit.gd",
    "addons/funplay_mcp/plugin.gd",
    "addons/funplay_mcp/plugin.cfg",
    "addons/funplay_mcp/icon.svg",
    "resources/content/alpha01/alpha01_content_manifest_bench.gd",
    "resources/content/alpha01/Alpha01ContentManifestBench.tscn",
}

PRODUCT_COMPONENT_ALLOW_PREFIXES = (
    "scenes/tools/commercial_art/components/models/",
)

FORCED_PRODUCTION_PREFIXES = (
    "tools/release/",
    "addons/funplay_mcp/runtime/",
    "scenes/runtime/",
    "scripts/runtime/",
)

TRUSTED_NONPRODUCTION_PREFIXES = (
    "tests/",
    "tools/",
    "scripts/tools/",
    "scenes/tools/",
    "addons/codex_mcp_companion/",
    "addons/godot_mcp/",
    "addons/space_syndicate_design_qa/",
    "addons/funplay_mcp/core/",
    "addons/funplay_mcp/ui/",
)

RULE_AUTHORITY_EXEMPT_PATHS = {
    "resources/content/alpha01/alpha01_content_manifest_bench.gd",
    "resources/content/alpha01/Alpha01ContentManifestBench.tscn",
}

PRODUCT_COMPOSITION_PATHS = {
    "project.godot",
    "export_presets.cfg",
    "scenes/main.tscn",
    "tools/launch_space_syndicate.ps1",
}

PRODUCT_COMPOSITION_PREFIXES = ("tools/release/",)

NON_COMPONENT_SUFFIXES = (".md",)

RUNTIME_LOADABLE_SUFFIXES = {
    ".gd",
    ".tscn",
    ".scn",
    ".tres",
    ".res",
    ".gdshader",
    ".shader",
    ".json",
    ".cfg",
    ".po",
    ".csv",
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".svg",
    ".ogg",
    ".wav",
    ".mp3",
    ".glb",
    ".gltf",
    ".obj",
    ".ttf",
    ".otf",
}

GOVERNANCE_OR_TEST_TOP_LEVEL_PREFIXES = (
    ".github/",
    "docs/",
    "reports/",
    "tests/",
    "tools/",
    "art_sources/",
)

RULE_AUTHORITY_PATHS = {
    "README.md",
    "docs/tabletop_rulebook_v06.md",
    "docs/rules_v06_runtime_directive.md",
}

RULE_AUTHORITY_PREFIXES = (
    "docs/rules/",
    "resources/rules/",
    "data/rules/",
    "resources/cards/",
    "data/cards/",
    "resources/balance/",
    "data/balance/",
    "resources/ai/",
    "resources/content/",
    "resources/economy/",
    "resources/finance/",
    "resources/monsters/",
    "resources/weather/",
    "data/v074/",
    "data/v075/",
    "data/v076/",
)


def _is_bool(value: Any) -> bool:
    return type(value) is bool


def _is_int(value: Any) -> bool:
    return type(value) is int


def _nonempty(value: Any) -> bool:
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, list):
        return len(value) > 0
    if isinstance(value, dict):
        return len(value) > 0
    return value is not None


def _unique(values: Iterable[str]) -> bool:
    items = list(values)
    return len(items) == len(set(items))


def _is_product_component_path(path: str) -> bool:
    normalized = path.replace("\\", "/")
    folded = normalized.casefold()
    binding_folded = _component_binding_path(normalized).casefold()
    if _is_product_composition_path(normalized):
        return True
    if folded.startswith(
        tuple(value.casefold() for value in PRODUCT_COMPONENT_ALLOW_PREFIXES)
    ):
        return True
    if binding_folded in {value.casefold() for value in NON_PRODUCT_COMPONENT_PATHS}:
        return False
    if not folded.startswith(PRODUCT_COMPONENT_ROOTS):
        return False
    if folded.startswith(NON_PRODUCT_COMPONENT_PREFIXES):
        return False
    if folded.endswith(NON_COMPONENT_SUFFIXES):
        return False
    return bool(PurePosixPath(normalized).suffix or folded.startswith("addons/"))


def _is_product_composition_path(path: str) -> bool:
    folded = path.replace("\\", "/").casefold()
    return bool(
        folded in {value.casefold() for value in PRODUCT_COMPOSITION_PATHS}
        or folded.startswith(
            tuple(value.casefold() for value in PRODUCT_COMPOSITION_PREFIXES)
        )
        or (folded.startswith("launch space syndicate") and folded.endswith(".cmd"))
    )


def _is_forced_production_path(path: str) -> bool:
    normalized = path.replace("\\", "/")
    folded = normalized.casefold()
    binding_folded = _component_binding_path(normalized).casefold()
    explicitly_forced = bool(
        _is_product_composition_path(normalized)
        or folded.startswith(tuple(value.casefold() for value in FORCED_PRODUCTION_PREFIXES))
        or folded.startswith(
            tuple(value.casefold() for value in PRODUCT_COMPONENT_ALLOW_PREFIXES)
        )
        or (folded.startswith("launch space syndicate") and folded.endswith(".cmd"))
    )
    if explicitly_forced:
        return True
    if binding_folded in {value.casefold() for value in NON_PRODUCT_COMPONENT_PATHS}:
        return False
    if folded.startswith((".github/", "docs/", "reports/", "art_sources/")):
        return False
    if folded.startswith(tuple(value.casefold() for value in TRUSTED_NONPRODUCTION_PREFIXES)):
        return False
    if binding_folded.startswith(PRODUCT_COMPONENT_ROOTS):
        return True
    suffix = PurePosixPath(_component_binding_path(normalized)).suffix.casefold()
    return bool(suffix and suffix not in NON_COMPONENT_SUFFIXES)


def _component_binding_path(path: str) -> str:
    normalized = path.replace("\\", "/")
    for suffix in (".uid", ".import"):
        if normalized.casefold().endswith(suffix):
            return normalized[: -len(suffix)]
    return normalized


def _is_runtime_loadable_candidate_path(path: str) -> bool:
    """Fail closed for new or composition-adjacent Godot-loadable files."""
    normalized = path.replace("\\", "/")
    folded = normalized.casefold()
    binding = _component_binding_path(normalized)
    binding_folded = binding.casefold()
    if binding_folded in {value.casefold() for value in NON_PRODUCT_COMPONENT_PATHS}:
        return False
    if folded.startswith(tuple(value.casefold() for value in PRODUCT_COMPONENT_ALLOW_PREFIXES)):
        return True
    if folded in {value.casefold() for value in PRODUCT_COMPOSITION_PATHS}:
        return True
    if folded.startswith(tuple(value.casefold() for value in PRODUCT_COMPOSITION_PREFIXES)):
        return True
    if folded.startswith(GOVERNANCE_OR_TEST_TOP_LEVEL_PREFIXES):
        return False
    if folded.startswith(tuple(value.casefold() for value in TRUSTED_NONPRODUCTION_PREFIXES)):
        return False
    suffix = PurePosixPath(binding).suffix.casefold()
    return bool(suffix and suffix not in NON_COMPONENT_SUFFIXES)


def _is_changed_component_candidate_path(
    changed: dict[str, str],
    composition_delta: bool = False,
    strict_composition_context: bool = False,
) -> bool:
    path = str(changed.get("path", ""))
    if (
        changed.get("production_reachable") is True
        or changed.get("production_reachable_before") is True
    ):
        return True
    if _is_forced_production_path(path):
        return True
    if _is_product_component_path(path):
        return True
    del composition_delta, strict_composition_context
    return _is_runtime_loadable_candidate_path(path)


def _is_rule_authority_path(path: str) -> bool:
    normalized = path.replace("\\", "/")
    folded = normalized.casefold()
    binding_folded = _component_binding_path(normalized).casefold()
    if binding_folded in {
        value.casefold() for value in RULE_AUTHORITY_EXEMPT_PATHS
    }:
        return False
    return folded in {value.casefold() for value in RULE_AUTHORITY_PATHS} or folded.startswith(
        tuple(value.casefold() for value in RULE_AUTHORITY_PREFIXES)
    )


def _json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _file_binding(root: Path, relative_path: str) -> dict[str, Any]:
    payload = (root / relative_path).read_bytes()
    return {
        "path": relative_path,
        "sha256": hashlib.sha256(payload).hexdigest(),
        "byte_count": len(payload),
    }


def _git(root: Path, *args: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), "-c", "core.quotepath=false", *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and completed.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed ({completed.returncode}): "
            f"{completed.stderr.strip()}"
        )
    return completed.stdout.strip()


def _git_bytes(root: Path, *args: str, check: bool = True) -> bytes:
    """Run Git without C-style path quoting and preserve NUL records."""
    completed = subprocess.run(
        ["git", "-C", str(root), "-c", "core.quotepath=false", *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and completed.returncode != 0:
        error = completed.stderr.decode("utf-8", errors="surrogateescape").strip()
        raise RuntimeError(
            f"git {' '.join(args)} failed ({completed.returncode}): {error}"
        )
    return completed.stdout


def _decode_git_path(value: bytes) -> str:
    return value.decode("utf-8", errors="surrogateescape").replace("\\", "/")


def _git_path_list(root: Path, *args: str) -> list[str]:
    payload = _git_bytes(root, *args, "-z")
    return [
        _decode_git_path(field)
        for field in payload.split(b"\0")
        if field
    ]


def _git_json_at(root: Path, ref: str, path: str) -> dict[str, Any] | None:
    completed = subprocess.run(
        ["git", "-C", str(root), "show", f"{ref}:{path}"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        return None
    value = json.loads(completed.stdout.decode("utf-8-sig"))
    return value if isinstance(value, dict) else None


def _git_path_exists_at(root: Path, ref: str, path: str) -> bool:
    completed = subprocess.run(
        ["git", "-C", str(root), "cat-file", "-e", f"{ref}:{path}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return completed.returncode == 0


def discover_authorities(root: Path) -> tuple[dict[str, dict[str, Any]], dict[str, list[str]]]:
    found: dict[str, list[tuple[Path, dict[str, Any]]]] = {
        key: [] for key in SCHEMA_PREFIXES
    }
    for base in (root / "docs", root / "reports"):
        if not base.is_dir():
            continue
        for path in base.rglob("*.json"):
            try:
                value = _json(path)
            except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
                continue
            schema = value.get("schema_version")
            if not isinstance(schema, str):
                continue
            for key, prefix in SCHEMA_PREFIXES.items():
                if schema.startswith(prefix):
                    found[key].append((path, value))

    implementation_paths = {
        key: [p.relative_to(root).as_posix() for p, _ in values]
        for key, values in found.items()
    }
    authorities: dict[str, dict[str, Any]] = {}
    for key, values in found.items():
        if len(values) == 1:
            authorities[key] = values[0][1]

    owner_paths: list[str] = []
    for path in (root / "docs").rglob("*.md"):
        try:
            text = path.read_text(encoding="utf-8-sig")
        except (OSError, UnicodeError):
            continue
        if (
            f"schema_version: {OWNER_MAP_SCHEMA}" in text
            and f"registry_id: {OWNER_MAP_REGISTRY_ID}" in text
        ):
            owner_paths.append(path.relative_to(root).as_posix())
    implementation_paths["owner_map"] = owner_paths
    return authorities, implementation_paths


def render_status_block(status: dict[str, Any]) -> str:
    lines = ["<!-- V076_STATUS_BEGIN -->"]
    for key in STATUS_KEYS:
        value = status.get(key, "")
        if isinstance(value, bool):
            rendered = "true" if value else "false"
        else:
            rendered = str(value)
        lines.append(f"{key}={rendered}")
    lines.append("<!-- V076_STATUS_END -->")
    return "\n".join(lines)


def extract_status_block(body: str) -> str:
    matches = re.findall(
        r"<!-- V076_STATUS_BEGIN -->.*?<!-- V076_STATUS_END -->",
        body,
        flags=re.DOTALL,
    )
    return matches[0].strip() if len(matches) == 1 else ""


def _status_block_count(body: str) -> int:
    return len(
        re.findall(
            r"<!-- V076_STATUS_BEGIN -->.*?<!-- V076_STATUS_END -->",
            body,
            flags=re.DOTALL,
        )
    )


def _has_unqualified_positive_claim(text: str, phrase_pattern: str) -> bool:
    for line in text.splitlines():
        for match in re.finditer(phrase_pattern, line, flags=re.IGNORECASE):
            prefix = line[max(0, match.start() - 24) : match.start()]
            matched = match.group(0)
            if re.search(
                r"(?:\b0\b|\bno\b|\bnot\b|\bfalse\b|未|无)\s*$",
                prefix,
                flags=re.IGNORECASE,
            ):
                continue
            if re.search(
                r"(?:未|没有|并非|不是)[^，。;；\n]{0,12}(?:通过|完成|绿)",
                matched,
            ):
                continue
            return True
    return False


def _is_hex(value: Any, length: int) -> bool:
    return isinstance(value, str) and re.fullmatch(rf"[0-9a-f]{{{length}}}", value) is not None


def _regression_evidence_complete(
    value: Any, expected_prior_status: str | None = None
) -> bool:
    if not isinstance(value, dict):
        return False
    complete = all(
        _nonempty(value.get(key))
        for key in (
            "failure_evidence",
            "affected_commit",
            "affected_owner",
            "repair_plan",
            "prior_status",
        )
    )
    return complete and _is_hex(value.get("affected_commit"), 40) and (
        expected_prior_status is None
        or value.get("prior_status") == expected_prior_status
    )


def _same_regression_identity(old: Any, new: Any) -> bool:
    if not (_regression_evidence_complete(old) and _regression_evidence_complete(new)):
        return False
    return all(
        old.get(key) == new.get(key)
        for key in ("failure_evidence", "affected_commit", "affected_owner", "prior_status")
    )


def _domain_retirement_evidence_complete(row: Any) -> bool:
    if not isinstance(row, dict):
        return False
    evidence = row.get("retirement_evidence")
    return bool(
        isinstance(evidence, dict)
        and evidence.get("prior_lifecycle") == "ACTIVE_CURRENT_DOMAIN"
        and evidence.get("authorized_change_class")
        in {"PRODUCTION_COMPOSITION", "RULESET_CONSTITUTION", "RELEASE_CANDIDATE"}
        and _is_hex(evidence.get("affected_commit"), 40)
        and _nonempty(evidence.get("affected_owner"))
        and _nonempty(evidence.get("retirement_reason"))
        and _nonempty(evidence.get("retirement_plan"))
    )


def _component_deactivation_is_superseded(
    component_id: str,
    new_components: dict[str, dict[str, Any]],
    supersession_entries: list[dict[str, Any]],
) -> bool:
    old_component = new_components.get(component_id, {})
    if not (
        old_component.get("production_reachable") is False
        and old_component.get("writes_authority") is False
    ):
        return False
    matches = [
        row
        for row in supersession_entries
        if row.get("old_component_id") == component_id
        and isinstance(row.get("new_component_id"), str)
        and row.get("new_component_id") in new_components
    ]
    return bool(
        len(matches) == 1
        and matches[0].get("new_component_id")
        in set(map(str, old_component.get("superseded_by", [])))
    )


def _supersession_chain_is_atomic(
    old_component_id: str,
    new_component_id: str,
    components: dict[str, dict[str, Any]],
    entries: list[dict[str, Any]],
) -> bool:
    if old_component_id == new_component_id:
        return True
    edges: dict[str, str] = {}
    for row in entries:
        old_id = str(row.get("old_component_id", ""))
        new_id = str(row.get("new_component_id", ""))
        if not old_id and not new_id:
            continue
        if not old_id or not new_id or old_id in edges:
            return False
        edges[old_id] = new_id
    seen: set[str] = set()
    current = old_component_id
    while current != new_component_id:
        if current in seen or current not in edges:
            return False
        seen.add(current)
        next_id = edges[current]
        old_row = components.get(current, {})
        new_row = components.get(next_id, {})
        if not (
            old_row
            and new_row
            and old_row.get("production_reachable") is False
            and old_row.get("writes_authority") is False
            and next_id in set(map(str, old_row.get("superseded_by", [])))
            and current in set(map(str, new_row.get("supersedes", [])))
        ):
            return False
        current = next_id
    return True


def _pending_domain_first_owner_activation(
    domain_id: str,
    old_domains: dict[str, dict[str, Any]],
    new_domains: dict[str, dict[str, Any]],
    old_components: dict[str, dict[str, Any]],
    new_components: dict[str, dict[str, Any]],
    old_owner_row: dict[str, Any] | None = None,
) -> bool:
    """Allow only the first atomic Owner of a constitutionally pending domain."""
    old_domain = old_domains.get(domain_id, {})
    new_domain = new_domains.get(domain_id, {})
    old_owner_id = str(old_domain.get("owner_component_id", ""))
    new_owner_id = str(new_domain.get("owner_component_id", ""))
    new_owner = new_components.get(new_owner_id, {})
    old_domain_owners = [
        component
        for component in old_components.values()
        if isinstance(component, dict)
        and component.get("domain_id") == domain_id
        and component.get("component_role") == "OWNER"
        and component.get("production_reachable") is True
    ]
    legacy_pending_placeholder = bool(
        not old_domain
        and isinstance(old_owner_row, dict)
        and old_owner_row.get("owner_count") == 0
        and old_owner_row.get("binding_status") == "PENDING"
        and str(old_owner_row.get("unique_owner", "")).startswith("UNASSIGNED_")
    )
    return bool(
        (
            old_domain.get("lifecycle") == "PENDING_FUTURE_DOMAIN"
            or legacy_pending_placeholder
        )
        and old_owner_id == ""
        and not old_domain_owners
        and new_domain.get("lifecycle") == "ACTIVE_CURRENT_DOMAIN"
        and new_owner_id
        and new_owner_id not in old_components
        and isinstance(new_owner, dict)
        and new_owner.get("domain_id") == domain_id
        and new_owner.get("component_role") == "OWNER"
        and new_owner.get("production_reachable") is True
        and new_owner.get("writes_authority") is True
        and new_owner.get("owner_component_id") == new_owner_id
        and new_owner.get("owner_path") == new_owner.get("path")
    )


def _supersession_graph_is_acyclic(entries: list[dict[str, Any]]) -> bool:
    edges: dict[str, str] = {}
    for row in entries:
        old_id = row.get("old_component_id")
        new_id = row.get("new_component_id")
        if old_id is None and new_id is None:
            continue
        if (
            not isinstance(old_id, str)
            or not old_id.strip()
            or not isinstance(new_id, str)
            or not new_id.strip()
            or old_id in edges
            or old_id == new_id
        ):
            return False
        edges[old_id] = new_id
    for start in edges:
        seen: set[str] = set()
        current = start
        while current in edges:
            if current in seen:
                return False
            seen.add(current)
            current = edges[current]
    return True


def _transition_product_classification_failures(
    current: dict[str, dict[str, Any]],
    changed_rows: Iterable[dict[str, str]],
    label: str,
) -> list[str]:
    """Require each committed production/rule delta to carry its authority metadata."""
    failures: list[str] = []
    registry = current.get("historical_reuse", {})
    inherited = current.get("inherited_green", {})
    components = _index(registry.get("component_inventory", []), "path")
    components_by_id = _index(registry.get("component_inventory", []), "component_id")
    domains = _index(registry.get("domain_inventory", []), "domain_id")
    reuse_rows = _index(registry.get("reuse_entries", []), "reuse_id")
    transition_supersession_entries = [
        row
        for row in current.get("supersession", {}).get("entries", [])
        if isinstance(row, dict)
    ]
    scope = inherited.get("canonical_change_scope", {})
    change_classes = (
        scope.get("change_classes", []) if isinstance(scope, dict) else []
    )
    declared_classes = set(map(str, change_classes)) if isinstance(change_classes, list) else set()
    product_allowed = bool(
        declared_classes
        & {
            "DOMAIN_CORE",
            "CROSS_DOMAIN_INTEGRATION",
            "PRODUCTION_COMPOSITION",
            "RULESET_CONSTITUTION",
            "RELEASE_CANDIDATE",
        }
    )
    rules_allowed = bool(declared_classes & {"RULESET_CONSTITUTION", "RELEASE_CANDIDATE"})
    affected_domains = set(
        map(str, scope.get("affected_domains", []))
        if isinstance(scope, dict) and isinstance(scope.get("affected_domains"), list)
        else []
    )
    affected_owners = set(
        map(str, scope.get("affected_owners", []))
        if isinstance(scope, dict) and isinstance(scope.get("affected_owners"), list)
        else []
    )
    focused_tests = set(
        map(str, scope.get("focused_tests", []))
        if isinstance(scope, dict) and isinstance(scope.get("focused_tests"), list)
        else []
    )
    changed_rows = list(changed_rows)
    composition_delta = any(
        _is_product_composition_path(str(row.get("path", "")))
        for row in changed_rows
    )
    for changed in changed_rows:
        path = str(changed.get("path", "")).replace("\\", "/")
        for reference_failure in changed.get("production_reference_failures", []):
            failures.append(
                f"HISTORY_{reference_failure}:{label}:{path}"
            )
        component = components.get(_component_binding_path(path))
        reachable_now = changed.get("production_reachable") is True
        reachable_before = changed.get("production_reachable_before") is True
        explicitly_reachable = bool(reachable_now or reachable_before)
        if (
            _is_rule_authority_path(path)
            or changed.get("rule_authority") is True
        ) and not rules_allowed:
            failures.append(f"HISTORY_RULE_CHANGE_CLASS_MISSING:{label}:{path}")
        if not (
            _is_changed_component_candidate_path(
                changed, composition_delta, strict_composition_context=True
            )
            or (
                isinstance(component, dict)
                and component.get("production_reachable") is True
            )
        ):
            continue
        if not isinstance(component, dict):
            failures.append(f"HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:{label}:{path}")
            continue
        component_id = str(component.get("component_id", ""))
        domain_id = str(component.get("domain_id", ""))
        owner_id = str(component.get("owner_component_id", ""))
        owner = components_by_id.get(owner_id)
        domain = domains.get(domain_id)
        failures.extend(
            _component_row_contract_failures(
                component,
                set(reuse_rows),
                f"{label}:{path}",
                "HISTORY_COMPONENT",
            )
        )
        if component.get("change_class") not in declared_classes:
            failures.append(
                f"HISTORY_COMPONENT_CHANGE_CLASS_NOT_DECLARED:{label}:{component_id}"
            )
        is_nonproduction_tool_component = bool(
            component.get("component_role")
            in {"DIAGNOSTIC_BENCH", "TEST_SUPPORT", "TOOLING"}
            and component.get("production_reachable") is False
        )
        if (
            is_nonproduction_tool_component
            and not _is_forced_production_path(path)
            and not explicitly_reachable
        ):
            if component.get("change_class") not in {"TOOLING_ONLY", "TEST_ORACLE_ONLY"}:
                failures.append(
                    f"HISTORY_NONPRODUCTION_COMPONENT_CHANGE_CLASS_INVALID:{label}:{component_id}"
                )
            continue
        if (
            (_is_forced_production_path(path) or reachable_now)
            and component.get("production_reachable") is not True
        ):
            failures.append(
                f"HISTORY_FORCED_PRODUCTION_COMPONENT_NOT_REACHABLE:{label}:{component_id}"
            )
        is_superseded_retirement = _component_deactivation_is_superseded(
            component_id,
            components_by_id,
            transition_supersession_entries,
        )
        canonical_owner_id = str(
            domain.get("owner_component_id", "") if isinstance(domain, dict) else ""
        )
        canonical_owner = components_by_id.get(canonical_owner_id)
        is_domain_retirement = bool(
            isinstance(domain, dict)
            and domain.get("lifecycle") == "RETIRED_DOMAIN"
            and _domain_retirement_evidence_complete(domain)
            and component.get("production_reachable") is False
            and component.get("writes_authority") is False
        )
        if not product_allowed:
            failures.append(f"HISTORY_PRODUCT_CHANGE_CLASS_MISSING:{label}:{path}")
        if (
            component.get("production_reachable") is not True
            and not is_superseded_retirement
            and not is_domain_retirement
        ):
            failures.append(f"HISTORY_PRODUCT_COMPONENT_NOT_REACHABLE:{label}:{path}")
        active_binding_green = bool(
            isinstance(domain, dict)
            and domain.get("lifecycle") == "ACTIVE_CURRENT_DOMAIN"
            and domain.get("owner_component_id") == owner_id
            and isinstance(owner, dict)
            and owner.get("component_role") == "OWNER"
            and owner.get("production_reachable") is True
            and owner.get("writes_authority") is True
            and component.get("owner_path") == owner.get("path")
        )
        superseded_binding_green = bool(
            is_superseded_retirement
            and isinstance(domain, dict)
            and domain.get("lifecycle") == "ACTIVE_CURRENT_DOMAIN"
            and isinstance(canonical_owner, dict)
            and canonical_owner.get("component_role") == "OWNER"
            and canonical_owner.get("production_reachable") is True
            and canonical_owner.get("writes_authority") is True
        )
        retired_binding_green = bool(
            is_domain_retirement
            and isinstance(domain, dict)
            and domain.get("owner_component_id") == component_id
            and component.get("component_role") == "OWNER"
        )
        if not (active_binding_green or superseded_binding_green or retired_binding_green):
            failures.append(f"HISTORY_PRODUCT_OWNER_BINDING_INVALID:{label}:{component_id}")
        if domain_id not in affected_domains:
            failures.append(f"HISTORY_PRODUCT_AFFECTED_DOMAIN_MISSING:{label}:{component_id}")
        affected_owner_id = (
            canonical_owner_id if is_superseded_retirement else owner_id
        )
        if affected_owner_id not in affected_owners:
            failures.append(f"HISTORY_PRODUCT_AFFECTED_OWNER_MISSING:{label}:{component_id}")
        required_tests = component.get("focused_test_ids", [])
        if (
            not isinstance(required_tests, list)
            or not required_tests
            or not set(map(str, required_tests)).issubset(focused_tests)
        ):
            failures.append(f"HISTORY_PRODUCT_FOCUSED_TESTS_MISSING:{label}:{component_id}")
        source_ids = component.get("reuse_source_ids", [])
        if not isinstance(source_ids, list) or any(
            source_id not in reuse_rows
            or reuse_rows[source_id].get("disposition") == "RETIRED"
            for source_id in source_ids
        ):
            failures.append(f"HISTORY_PRODUCT_REUSE_SOURCE_INVALID:{label}:{component_id}")
        is_authority = bool(
            component.get("component_role") == "OWNER"
            or component.get("writes_authority") is True
            or any(
                component.get(field) is True
                for field in ("owns_rng", "owns_tick", "owns_save", "owns_replay", "owns_identity")
            )
        )
        if is_authority:
            scan = component.get("reuse_scan")
            candidates = scan.get("reuse_candidate_ids", []) if isinstance(scan, dict) else []
            if not (
                isinstance(scan, dict)
                and REUSE_SCAN_FIELDS.issubset(scan)
                and all(scan.get(key) is True for key in REUSE_SCAN_FIELDS if key.endswith("_search"))
                and isinstance(candidates, list)
                and candidates
                and _is_int(scan.get("reuse_candidate_count"))
                and scan.get("reuse_candidate_count") == len(candidates)
                and all(candidate in reuse_rows for candidate in candidates)
                and scan.get("selected_reuse_disposition") == component.get("reuse_disposition")
                and all(
                    _nonempty(scan.get(reason))
                    for reason in (
                        "why_existing_owner_cannot_be_extended",
                        "why_adapter_is_insufficient",
                        "why_new_owner_is_required",
                    )
                )
            ):
                failures.append(f"HISTORY_PRODUCT_REUSE_SCAN_INVALID:{label}:{component_id}")
    return failures


def _index(rows: Any, key: str) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    if not isinstance(rows, list):
        return result
    for row in rows:
        if isinstance(row, dict) and isinstance(row.get(key), str):
            result[row[key]] = row
    return result


def _component_is_authority(component: Any) -> bool:
    return bool(
        isinstance(component, dict)
        and (
            component.get("component_role") == "OWNER"
            or component.get("writes_authority") is True
            or any(
                component.get(field) is True
                for field in (
                    "owns_rng",
                    "owns_tick",
                    "owns_save",
                    "owns_replay",
                    "owns_identity",
                )
            )
        )
    )


def _reuse_scan_contract_failures(
    component: Any,
    reuse_rows: dict[str, dict[str, Any]],
    label: str,
    prefix: str,
) -> list[str]:
    """Validate the single canonical pre-implementation reuse scan."""
    if not isinstance(component, dict):
        return [f"{prefix}_REUSE_SCAN_COMPONENT_INVALID:{label}"]
    scan = component.get("reuse_scan")
    candidates = scan.get("reuse_candidate_ids") if isinstance(scan, dict) else None
    considered = component.get("reuse_candidates_considered")
    if not (
        isinstance(scan, dict)
        and set(scan) == REUSE_SCAN_FIELDS
        and all(
            scan.get(key) is True
            for key in REUSE_SCAN_FIELDS
            if key.endswith("_search")
        )
        and isinstance(candidates, list)
        and candidates
        and all(
            isinstance(candidate, str) and candidate in reuse_rows
            for candidate in candidates
        )
        and _unique(candidates)
        and _is_int(scan.get("reuse_candidate_count"))
        and scan.get("reuse_candidate_count") == len(candidates)
        and isinstance(considered, list)
        and set(candidates).issubset(set(considered))
        and scan.get("selected_reuse_disposition")
        == component.get("reuse_disposition")
        and all(
            _nonempty(scan.get(reason))
            for reason in (
                "why_existing_owner_cannot_be_extended",
                "why_adapter_is_insufficient",
                "why_new_owner_is_required",
            )
        )
    ):
        return [
            f"{prefix}_REUSE_SCAN_INVALID:"
            f"{label}:{component.get('component_id', '')}"
        ]
    return []


def _component_row_contract_failures(
    component: Any,
    reuse_ids: set[str],
    label: str,
    prefix: str = "COMPONENT",
) -> list[str]:
    """Validate the one canonical component-row contract used by Head and history."""
    failures: list[str] = []
    if not isinstance(component, dict):
        return [f"{prefix}_ROW_NOT_OBJECT:{label}"]
    component_id = component.get("component_id")
    rendered_id = component_id if isinstance(component_id, str) and component_id else label
    allowed_fields = COMPONENT_REQUIRED_FIELDS | {"reuse_scan"}
    missing = sorted(COMPONENT_REQUIRED_FIELDS - set(component))
    extra = sorted(set(component) - allowed_fields)
    if missing:
        failures.append(
            f"{prefix}_REQUIRED_FIELDS:{rendered_id}:{','.join(missing)}"
        )
    if extra:
        failures.append(f"{prefix}_UNKNOWN_FIELDS:{rendered_id}:{','.join(extra)}")
    for key in COMPONENT_STRING_FIELDS:
        if not isinstance(component.get(key), str) or not component.get(key).strip():
            failures.append(f"{prefix}_STRING_FIELD:{rendered_id}:{key}")
    for key in COMPONENT_BOOL_FIELDS:
        if not _is_bool(component.get(key)):
            failures.append(f"{prefix}_BOOL_TYPE:{rendered_id}:{key}")
    for key in COMPONENT_STRING_LIST_FIELDS:
        values = component.get(key)
        if (
            not isinstance(values, list)
            or any(not isinstance(value, str) or not value.strip() for value in values)
            or not _unique(values)
        ):
            failures.append(f"{prefix}_STRING_LIST_FIELD:{rendered_id}:{key}")
    role = component.get("component_role")
    disposition = component.get("reuse_disposition")
    if role not in ALLOWED_COMPONENT_ROLES:
        failures.append(f"{prefix}_ROLE_INVALID:{rendered_id}")
    if disposition not in ALLOWED_DISPOSITIONS:
        failures.append(f"{prefix}_REUSE_DISPOSITION:{rendered_id}")
    if component.get("change_class") not in ALLOWED_COMPONENT_CHANGE_CLASSES:
        failures.append(f"{prefix}_CHANGE_CLASS_INVALID:{rendered_id}")
    if role == "OWNER" and disposition != "ADOPT_AS_OWNER":
        failures.append(f"{prefix}_OWNER_DISPOSITION_INVALID:{rendered_id}")
    if role != "OWNER" and disposition == "ADOPT_AS_OWNER":
        failures.append(f"{prefix}_NON_OWNER_DISPOSITION_INVALID:{rendered_id}")
    if role != "OWNER" and any(
        component.get(key) is True
        for key in ("owns_rng", "owns_tick", "owns_save", "owns_replay", "owns_identity")
    ):
        failures.append(f"{prefix}_NON_OWNER_CORE_AUTHORITY_INVALID:{rendered_id}")
    if (
        role in {"DIAGNOSTIC_BENCH", "TEST_SUPPORT", "TOOLING"}
        and component.get("production_reachable") is not False
    ):
        failures.append(f"{prefix}_NONPRODUCTION_ROLE_REACHABLE:{rendered_id}")
    for source_id in (
        component.get("reuse_source_ids", [])
        if isinstance(component.get("reuse_source_ids"), list)
        else []
    ) + (
        component.get("reuse_candidates_considered", [])
        if isinstance(component.get("reuse_candidates_considered"), list)
        else []
    ):
        if not isinstance(source_id, str) or source_id not in reuse_ids:
            failures.append(
                f"{prefix}_REUSE_REFERENCE_UNKNOWN:{rendered_id}:{source_id}"
            )
    return failures


def _change_scope_contract_failures(scope: Any, label: str, prefix: str) -> list[str]:
    """Validate the complete canonical change-scope row without string coercion."""
    failures: list[str] = []
    if not isinstance(scope, dict):
        return [f"{prefix}_CHANGE_SCOPE_NOT_OBJECT:{label}"]
    full_reproof = scope.get("full_reproof_required")
    reason_field = (
        "why_focused_tests_are_insufficient"
        if full_reproof is True
        else "why_focused_tests_are_sufficient"
    )
    expected_fields = CHANGE_SCOPE_BASE_FIELDS | {reason_field}
    if set(scope) != expected_fields:
        failures.append(f"{prefix}_CHANGE_SCOPE_SCHEMA_INVALID:{label}")
    if not _is_bool(full_reproof):
        failures.append(f"{prefix}_CHANGE_SCOPE_REPROOF_BOOL:{label}")
    if (
        not isinstance(scope.get("full_reproof_trigger"), str)
        or not scope.get("full_reproof_trigger").strip()
    ):
        failures.append(f"{prefix}_CHANGE_SCOPE_TRIGGER:{label}")
    for key in (
        "change_classes",
        "affected_domains",
        "affected_owners",
        "focused_tests",
        "inherited_sentinels",
    ):
        values = scope.get(key)
        if (
            not isinstance(values, list)
            or any(not isinstance(value, str) or not value.strip() for value in values)
            or not _unique(values)
        ):
            failures.append(f"{prefix}_CHANGE_SCOPE_LIST:{label}:{key}")
    change_classes = scope.get("change_classes")
    if (
        not isinstance(change_classes, list)
        or not change_classes
        or any(value not in ALLOWED_CHANGE_CLASSES for value in change_classes)
    ):
        failures.append(f"{prefix}_CHANGE_SCOPE_CLASS_INVALID:{label}")
    if not _nonempty(scope.get("focused_tests")):
        failures.append(f"{prefix}_CHANGE_SCOPE_FOCUSED_TESTS_EMPTY:{label}")
    if not _nonempty(scope.get("inherited_sentinels")):
        failures.append(f"{prefix}_CHANGE_SCOPE_SENTINELS_EMPTY:{label}")
    if isinstance(change_classes, list) and set(change_classes).intersection(
        {
            "DOMAIN_CORE",
            "CROSS_DOMAIN_INTEGRATION",
            "PRODUCTION_COMPOSITION",
            "RULESET_CONSTITUTION",
            "RELEASE_CANDIDATE",
        }
    ):
        if not _nonempty(scope.get("affected_domains")):
            failures.append(f"{prefix}_CHANGE_SCOPE_AFFECTED_DOMAINS_EMPTY:{label}")
        if not _nonempty(scope.get("affected_owners")):
            failures.append(f"{prefix}_CHANGE_SCOPE_AFFECTED_OWNERS_EMPTY:{label}")
    if not _nonempty(scope.get(reason_field)):
        failures.append(f"{prefix}_CHANGE_SCOPE_REASON:{label}:{reason_field}")
    return failures


def _authority_snapshot_contract_failures(
    current: dict[str, dict[str, Any]], label: str
) -> list[str]:
    """Validate schema, component, domain, owner and scope invariants for one commit."""
    failures: list[str] = []
    missing = sorted(set(SCHEMA_PREFIXES) - set(current))
    if missing:
        return [f"HISTORY_AUTHORITY_MISSING:{label}:{key}" for key in missing]
    for key, (expected_schema, id_field, expected_id) in AUTHORITY_CONTRACTS.items():
        authority = current[key]
        if authority.get("schema_version") != expected_schema:
            failures.append(f"HISTORY_AUTHORITY_SCHEMA_MISMATCH:{label}:{key}")
        if authority.get(id_field) != expected_id:
            failures.append(f"HISTORY_AUTHORITY_ID_MISMATCH:{label}:{key}")

    registry = current["historical_reuse"]
    inherited = current["inherited_green"]
    components = registry.get("component_inventory")
    domains = registry.get("domain_inventory")
    reuse_rows = registry.get("reuse_entries")
    unique_owner_rows = registry.get("unique_owner_domains")
    if not all(isinstance(rows, list) for rows in (components, domains, reuse_rows, unique_owner_rows)):
        return failures + [f"HISTORY_AUTHORITY_INVENTORY_INVALID:{label}"]

    component_ids = [
        row.get("component_id") for row in components if isinstance(row, dict)
    ]
    component_paths = [row.get("path") for row in components if isinstance(row, dict)]
    component_classes = [
        row.get("class_name") for row in components if isinstance(row, dict)
    ]
    domain_ids = [row.get("domain_id") for row in domains if isinstance(row, dict)]
    reuse_ids_list = [row.get("reuse_id") for row in reuse_rows if isinstance(row, dict)]
    for values, failure_name in (
        (component_ids, "COMPONENT_ID_NOT_UNIQUE"),
        (component_paths, "COMPONENT_PATH_NOT_UNIQUE"),
        (component_classes, "COMPONENT_CLASS_NAME_NOT_UNIQUE"),
        (domain_ids, "DOMAIN_ID_NOT_UNIQUE"),
        (reuse_ids_list, "HISTORICAL_REUSE_ID_NOT_UNIQUE"),
    ):
        if len(values) != len(set(values)) or any(
            not isinstance(value, str) or not value.strip() for value in values
        ):
            failures.append(f"HISTORY_{failure_name}:{label}")
    by_component = _index(components, "component_id")
    by_domain = _index(domains, "domain_id")
    reuse_ids = {
        value for value in reuse_ids_list if isinstance(value, str) and value.strip()
    }
    if len(by_component) != len(components):
        failures.append(f"HISTORY_COMPONENT_ROW_INVALID_OR_DUPLICATE:{label}")
    if len(by_domain) != len(domains):
        failures.append(f"HISTORY_DOMAIN_ROW_INVALID_OR_DUPLICATE:{label}")
    for component in components:
        failures.extend(
            _component_row_contract_failures(
                component, reuse_ids, label, "HISTORY_COMPONENT"
            )
        )
        if (
            _component_is_authority(component)
            and isinstance(component, dict)
            and component.get("change_class") != "INHERITED"
        ):
            failures.extend(
                _reuse_scan_contract_failures(
                    component,
                    _index(reuse_rows, "reuse_id"),
                    label,
                    "HISTORY_AUTHORITY",
                )
            )
    owner_domain_ids = [
        row.get("domain_id") for row in unique_owner_rows if isinstance(row, dict)
    ]
    if (
        len(owner_domain_ids) != len(unique_owner_rows)
        or len(owner_domain_ids) != len(set(owner_domain_ids))
        or set(owner_domain_ids) != set(by_domain)
    ):
        failures.append(f"HISTORY_UNIQUE_OWNER_DOMAIN_INVENTORY_MISMATCH:{label}")
    owner_map = _index(unique_owner_rows, "domain_id")
    for domain in domains:
        if not isinstance(domain, dict):
            failures.append(f"HISTORY_DOMAIN_ROW_NOT_OBJECT:{label}")
            continue
        domain_id = domain.get("domain_id")
        lifecycle = domain.get("lifecycle")
        expected_fields = {"domain_id", "lifecycle", "owner_component_id"}
        if lifecycle == "RETIRED_DOMAIN" and "retirement_evidence" in domain:
            expected_fields.add("retirement_evidence")
        if set(domain) != expected_fields:
            failures.append(f"HISTORY_DOMAIN_SCHEMA_INVALID:{label}:{domain_id}")
        if not isinstance(domain_id, str) or not domain_id.strip():
            failures.append(f"HISTORY_DOMAIN_ID_INVALID:{label}")
        if lifecycle not in DOMAIN_LIFECYCLES:
            failures.append(f"HISTORY_DOMAIN_LIFECYCLE_INVALID:{label}:{domain_id}")
            continue
        owners = [
            component
            for component in components
            if isinstance(component, dict)
            and component.get("domain_id") == domain_id
            and component.get("component_role") == "OWNER"
            and component.get("production_reachable") is True
            and component.get("reuse_disposition") == "ADOPT_AS_OWNER"
        ]
        if lifecycle == "ACTIVE_CURRENT_DOMAIN":
            if len(owners) != 1:
                failures.append(
                    f"HISTORY_ACTIVE_DOMAIN_OWNER_COUNT:{label}:{domain_id}:{len(owners)}"
                )
            elif domain.get("owner_component_id") != owners[0].get("component_id"):
                failures.append(f"HISTORY_ACTIVE_DOMAIN_OWNER_BINDING:{label}:{domain_id}")
            else:
                owner_row = owner_map.get(str(domain_id))
                if not (
                    isinstance(owner_row, dict)
                    and {"domain_id", "unique_owner", "owner_path"}.issubset(owner_row)
                    and owner_row.get("unique_owner") == owners[0].get("class_name")
                    and owner_row.get("owner_path") == owners[0].get("path")
                ):
                    failures.append(
                        f"HISTORY_ACTIVE_DOMAIN_UNIQUE_OWNER_MAP_MISMATCH:{label}:{domain_id}"
                    )
        elif lifecycle in {"PENDING_FUTURE_DOMAIN", "RETIRED_DOMAIN"} and owners:
            failures.append(f"HISTORY_NONACTIVE_DOMAIN_ACTIVE_OWNER:{label}:{domain_id}")
        if lifecycle == "REFERENCE_ONLY_DOMAIN" and any(
            component.get("writes_authority") is True
            for component in components
            if isinstance(component, dict) and component.get("domain_id") == domain_id
        ):
            failures.append(f"HISTORY_REFERENCE_ONLY_AUTHORITY_WRITE:{label}:{domain_id}")

    for component in components:
        if not isinstance(component, dict):
            continue
        component_id = str(component.get("component_id", ""))
        domain_id = str(component.get("domain_id", ""))
        owner_id = str(component.get("owner_component_id", ""))
        role = component.get("component_role")
        owner = by_component.get(owner_id)
        if domain_id not in by_domain:
            failures.append(f"HISTORY_COMPONENT_DOMAIN_UNKNOWN:{label}:{component_id}")
        if role == "OWNER":
            if owner_id != component_id or component.get("owner_path") != component.get("path"):
                failures.append(f"HISTORY_OWNER_SELF_BINDING_INVALID:{label}:{component_id}")
        elif not (
            isinstance(owner, dict)
            and owner.get("component_role") == "OWNER"
            and component.get("owner_path") == owner.get("path")
            and (
                component.get("production_reachable") is not True
                or (
                    owner.get("production_reachable") is True
                    and by_domain.get(domain_id, {}).get("owner_component_id") == owner_id
                )
            )
        ):
            failures.append(f"HISTORY_NON_OWNER_BINDING_INVALID:{label}:{component_id}")

    for authority_flag in ("owns_tick", "owns_rng", "owns_save", "owns_replay"):
        active_owners = [
            component
            for component in components
            if isinstance(component, dict)
            and component.get("component_role") == "OWNER"
            and component.get("production_reachable") is True
            and component.get(authority_flag) is True
        ]
        if len(active_owners) > 1:
            failures.append(
                f"HISTORY_GLOBAL_AUTHORITY_SURFACE_PARALLEL_OWNER:{label}:{authority_flag}"
            )

    failures.extend(
        _change_scope_contract_failures(
            inherited.get("canonical_change_scope"), label, "HISTORY"
        )
    )
    failures.extend(
        _regression_binding_failures(current, label, "HISTORY", None)
    )
    return failures


def _regression_binding_failures(
    authorities: dict[str, dict[str, Any]],
    label: str,
    prefix: str,
    valid_commit_ids: set[str] | None,
) -> list[str]:
    failures: list[str] = []
    component_ids = set(
        _index(
            authorities.get("historical_reuse", {}).get("component_inventory", []),
            "component_id",
        )
    )
    regression_rows: list[tuple[str, Any]] = []
    for stage in authorities.get("inherited_green", {}).get("stages", []):
        if isinstance(stage, dict) and stage.get("ledger_status") == "REGRESSED_WITH_EVIDENCE":
            regression_rows.append((f"stage:{stage.get('stage_id', '')}", stage.get("regression")))
    for step in authorities.get("golden", {}).get("steps", []):
        if isinstance(step, dict) and step.get("status") == "REGRESSED_WITH_EVIDENCE":
            regression_rows.append((f"golden:{step.get('step_id', '')}", step.get("regression")))
    for category in authorities.get("card_matrix", {}).get("category_matrix", []):
        if not isinstance(category, dict):
            continue
        certification = category.get("certification", {})
        if isinstance(certification, dict) and any(
            value == "REGRESSED_WITH_EVIDENCE" for value in certification.values()
        ):
            regression_rows.append(
                (f"card:{category.get('category_id', '')}", category.get("regression"))
            )
    for row_label, regression in regression_rows:
        if not _regression_evidence_complete(regression):
            failures.append(f"{prefix}_REGRESSION_EVIDENCE_INVALID:{label}:{row_label}")
            continue
        if regression.get("affected_owner") not in component_ids:
            failures.append(f"{prefix}_REGRESSION_OWNER_UNKNOWN:{label}:{row_label}")
        if (
            valid_commit_ids is not None
            and regression.get("affected_commit") not in valid_commit_ids
        ):
            failures.append(f"{prefix}_REGRESSION_COMMIT_NOT_FOUND:{label}:{row_label}")
    return failures


def _stage_evidence_head(stage: Any) -> str:
    if not isinstance(stage, dict):
        return ""
    for key in ("head_sha", "current_direct_owner_head_sha", "origin_head_sha"):
        value = stage.get(key)
        if _is_hex(value, 40):
            return str(value)
    return ""


def _normalize_evidence_path(value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        return ""
    candidate = value.strip().replace("\\", "/")
    if candidate.startswith("res://"):
        candidate = candidate[len("res://") :]
    if candidate.startswith("/") or re.match(r"^[A-Za-z]:", candidate):
        return ""
    parts = PurePosixPath(candidate).parts
    if not parts or any(part in {"", ".", ".."} for part in parts):
        return ""
    return PurePosixPath(*parts).as_posix()


def _artifact_binding(
    data: "ValidationInput", path_value: Any, expected_sha256: Any
) -> dict[str, Any] | None:
    relative = _normalize_evidence_path(path_value)
    if not relative or not _is_hex(expected_sha256, 64):
        return None
    bindings = data.evidence_artifact_bindings or {}
    binding = bindings.get(relative)
    if not isinstance(binding, dict):
        return None
    if binding.get("present") is not True or binding.get("sha256") != expected_sha256:
        return None
    return binding


def _golden_production_evidence_complete(
    step: dict[str, Any], data: "ValidationInput"
) -> bool:
    evidence = step.get("production_evidence")
    subject_sha = data.authorities.get("historical_reuse", {}).get("candidate_head_sha")
    production_scene_path = _normalize_evidence_path(
        evidence.get("production_scene_path") if isinstance(evidence, dict) else None
    )
    if not (
        isinstance(evidence, dict)
        and evidence.get("evidence_type") == "V076_GOLDEN_PRODUCTION_EXECUTION"
        and _is_hex(subject_sha, 40)
        and evidence.get("candidate_head_sha") == subject_sha
        and _is_int(evidence.get("pass_count"))
        and evidence.get("pass_count", 0) > 0
        and production_scene_path == "scenes/main.tscn"
    ):
        return False
    scene_binding = _artifact_binding(
        data,
        evidence.get("production_scene_path"),
        evidence.get("production_scene_sha256"),
    )
    receipt_binding = _artifact_binding(
        data, evidence.get("receipt_path"), evidence.get("receipt_sha256")
    )
    if scene_binding is None or receipt_binding is None:
        return False
    receipt = receipt_binding.get("json")
    return bool(
        isinstance(receipt, dict)
        and receipt.get("schema_version")
        == "space_syndicate.v076.golden_production_execution_receipt.v1"
        and receipt.get("evidence_type") == evidence.get("evidence_type")
        and receipt.get("candidate_head_sha") == subject_sha
        and receipt.get("step_id") == step.get("step_id")
        and receipt.get("status") == "PASS"
        and receipt.get("execution_mode") == "PRODUCTION_COMPOSITION"
        and receipt.get("diagnostic_only") is False
        and receipt.get("fixture_only") is False
        and receipt.get("production_scene_path") == evidence.get("production_scene_path")
        and receipt.get("pass_count") == evidence.get("pass_count")
    )


def _golden_human_evidence_complete(
    step: dict[str, Any], data: "ValidationInput"
) -> bool:
    evidence = step.get("human_evidence")
    subject_sha = data.authorities.get("historical_reuse", {}).get("candidate_head_sha")
    if not (
        _golden_production_evidence_complete(step, data)
        and isinstance(evidence, dict)
        and evidence.get("evidence_type") == "V076_GOLDEN_HUMAN_EXECUTION"
        and evidence.get("evidence_source_type") == "HUMAN_EXECUTED"
        and evidence.get("observer_kind") == "HUMAN"
        and evidence.get("human_confirmed") is True
        and evidence.get("candidate_head_sha") == subject_sha
        and _nonempty(evidence.get("evidence_id"))
        and _nonempty(evidence.get("observer"))
    ):
        return False
    observer = str(evidence.get("observer", "")).casefold()
    if re.search(r"(?:^|[^a-z0-9])(?:bot|agent|automation|fixture)(?:$|[^a-z0-9])", observer):
        return False
    receipt_binding = _artifact_binding(
        data, evidence.get("receipt_path"), evidence.get("receipt_sha256")
    )
    if receipt_binding is None:
        return False
    receipt = receipt_binding.get("json")
    production = step.get("production_evidence", {})
    return bool(
        isinstance(receipt, dict)
        and receipt.get("schema_version")
        == "space_syndicate.v076.golden_human_execution_receipt.v1"
        and receipt.get("evidence_type") == evidence.get("evidence_type")
        and receipt.get("evidence_source_type") == evidence.get("evidence_source_type")
        and receipt.get("candidate_head_sha") == subject_sha
        and receipt.get("step_id") == step.get("step_id")
        and receipt.get("status") == "PASS"
        and receipt.get("human_executed") is True
        and receipt.get("production_composition") is True
        and receipt.get("observer_kind") == "HUMAN"
        and receipt.get("observer") == evidence.get("observer")
        and receipt.get("evidence_id") == evidence.get("evidence_id")
        and receipt.get("production_receipt_sha256")
        == production.get("receipt_sha256")
    )


def _monotonic_transition_failures(
    previous: dict[str, dict[str, Any]],
    current: dict[str, dict[str, Any]],
    label: str,
    transition_changed_paths: Iterable[dict[str, str]] | None = None,
) -> list[str]:
    """Compare one committed authority transition without trusting Head metadata."""
    failures: list[str] = []
    missing_authorities = sorted(set(SCHEMA_PREFIXES) - set(previous))
    missing_authorities += sorted(set(SCHEMA_PREFIXES) - set(current))
    if missing_authorities:
        return [f"HISTORY_AUTHORITY_MISSING:{label}:{key}" for key in sorted(set(missing_authorities))]

    failures.extend(_authority_snapshot_contract_failures(current, label))

    for key, (expected_schema, id_field, expected_id) in AUTHORITY_CONTRACTS.items():
        authority = current[key]
        if authority.get("schema_version") != expected_schema:
            failures.append(f"HISTORY_AUTHORITY_SCHEMA_MISMATCH:{label}:{key}")
        if authority.get(id_field) != expected_id:
            failures.append(f"HISTORY_AUTHORITY_ID_MISMATCH:{label}:{key}")

    old_registry = previous["historical_reuse"]
    new_registry = current["historical_reuse"]
    old_supersession = previous["supersession"]
    new_supersession = current["supersession"]

    if transition_changed_paths is not None:
        failures.extend(
            _transition_product_classification_failures(
                current, transition_changed_paths, label
            )
        )

    old_supersession_entries = _index(old_supersession.get("entries", []), "supersession_id")
    new_supersession_entries = _index(new_supersession.get("entries", []), "supersession_id")
    new_supersession_ids = [
        str(row.get("supersession_id", ""))
        for row in new_supersession.get("entries", [])
        if isinstance(row, dict)
    ]
    if (
        not isinstance(new_supersession.get("entries"), list)
        or len(new_supersession_ids) != len(new_supersession.get("entries", []))
        or "" in new_supersession_ids
        or not _unique(new_supersession_ids)
    ):
        failures.append(f"HISTORY_SUPERSESSION_ID_NOT_UNIQUE:{label}")
    supersession_contract_already_active = (
        old_supersession.get("schema_version")
        == AUTHORITY_CONTRACTS["supersession"][0]
        and new_supersession.get("schema_version")
        == AUTHORITY_CONTRACTS["supersession"][0]
    )
    for supersession_id, old_entry in old_supersession_entries.items():
        new_entry = new_supersession_entries.get(supersession_id)
        if new_entry is None:
            failures.append(f"SUPERSESSION_ENTRY_SILENT_DELETE:{label}:{supersession_id}")
        elif supersession_contract_already_active and new_entry != old_entry:
            failures.append(f"SUPERSESSION_ENTRY_MUTATED:{label}:{supersession_id}")
        elif not supersession_contract_already_active and any(
            key not in new_entry or new_entry.get(key) != value
            for key, value in old_entry.items()
        ):
            failures.append(
                f"SUPERSESSION_ACTIVATION_MIGRATION_NOT_ADDITIVE:{label}:{supersession_id}"
            )

    for rows_key, id_key, failure_name in (
        ("reuse_entries", "reuse_id", "HISTORICAL_REUSE_ENTRY_SILENT_DELETE"),
        ("component_inventory", "component_id", "COMPONENT_INVENTORY_SILENT_DELETE"),
        ("domain_inventory", "domain_id", "DOMAIN_INVENTORY_SILENT_DELETE"),
        ("unique_owner_domains", "domain_id", "UNIQUE_OWNER_DOMAIN_SILENT_DELETE"),
    ):
        old_rows = _index(old_registry.get(rows_key, []), id_key)
        new_rows = _index(new_registry.get(rows_key, []), id_key)
        for row_id in sorted(set(old_rows) - set(new_rows)):
            failures.append(f"{failure_name}:{label}:{row_id}")

    old_reuse = _index(old_registry.get("reuse_entries", []), "reuse_id")
    new_reuse = _index(new_registry.get("reuse_entries", []), "reuse_id")
    for reuse_id, old in old_reuse.items():
        new = new_reuse.get(reuse_id)
        if (
            new is not None
            and old.get("disposition") == "RETIRED"
            and new.get("disposition") != "RETIRED"
        ):
            failures.append(f"RETIRED_REUSE_DISPOSITION_REACTIVATED:{label}:{reuse_id}")

    old_components = _index(old_registry.get("component_inventory", []), "component_id")
    new_components = _index(new_registry.get("component_inventory", []), "component_id")
    registry_contract_already_active = bool(
        old_registry.get("schema_version")
        == AUTHORITY_CONTRACTS["historical_reuse"][0]
        and new_registry.get("schema_version")
        == AUTHORITY_CONTRACTS["historical_reuse"][0]
    )
    for component_id in sorted(set(new_components) - set(old_components)):
        component = new_components[component_id]
        activation_inherited_migration = bool(
            not registry_contract_already_active
            and component.get("change_class") == "INHERITED"
        )
        if component.get("change_class") == "INHERITED" and not activation_inherited_migration:
            failures.append(
                f"NEW_COMPONENT_CANNOT_CLAIM_INHERITED:{label}:{component_id}"
            )
        if _component_is_authority(component) and not activation_inherited_migration:
            failures.extend(
                _reuse_scan_contract_failures(
                    component,
                    new_reuse,
                    label,
                    "HISTORY_NEW_AUTHORITY",
                )
            )
    for component_id, old in old_components.items():
        new = new_components.get(component_id)
        if not new:
            continue
        if (
            old.get("change_class") != "INHERITED"
            and new.get("change_class") == "INHERITED"
        ):
            failures.append(
                f"COMPONENT_CHANGE_CLASS_REVERTED_TO_INHERITED:{label}:{component_id}"
            )
        if _component_is_authority(old) and old.get("change_class") != "INHERITED":
            failures.extend(
                _reuse_scan_contract_failures(
                    new,
                    new_reuse,
                    label,
                    "HISTORY_AUTHORITY_INERTIA",
                )
            )
        identity_fields = ("class_name", "path", "domain_id", "component_role")
        if any(old.get(key) != new.get(key) for key in identity_fields):
            failures.append(f"COMPONENT_IDENTITY_SILENT_REPLACEMENT:{label}:{component_id}")

    supersession_entries = [
        row for row in new_supersession.get("entries", []) if isinstance(row, dict)
    ]
    if not _supersession_graph_is_acyclic(supersession_entries):
        failures.append(f"SUPERSESSION_GRAPH_INVALID:{label}")
    old_owners = _index(old_registry.get("unique_owner_domains", []), "domain_id")
    new_owners = _index(new_registry.get("unique_owner_domains", []), "domain_id")
    old_domains = _index(old_registry.get("domain_inventory", []), "domain_id")
    new_domains = _index(new_registry.get("domain_inventory", []), "domain_id")
    for domain_id, old_domain in old_domains.items():
        new_domain = new_domains.get(domain_id)
        if (
            new_domain is not None
            and old_domain.get("lifecycle") == "RETIRED_DOMAIN"
            and new_domain.get("lifecycle") != "RETIRED_DOMAIN"
        ):
            failures.append(f"RETIRED_DOMAIN_REACTIVATED:{label}:{domain_id}")
        if (
            new_domain is not None
            and old_domain.get("lifecycle") == "ACTIVE_CURRENT_DOMAIN"
            and new_domain.get("lifecycle") != "ACTIVE_CURRENT_DOMAIN"
            and not (
                new_domain.get("lifecycle") == "RETIRED_DOMAIN"
                and _domain_retirement_evidence_complete(new_domain)
            )
        ):
            failures.append(f"ACTIVE_DOMAIN_LIFECYCLE_SILENT_DOWNGRADE:{label}:{domain_id}")

    for component_id, old_component in old_components.items():
        new_component = new_components.get(component_id)
        if new_component is None:
            continue
        for link_field in ("supersedes", "superseded_by"):
            old_links = old_component.get(link_field, [])
            new_links = new_component.get(link_field, [])
            if (
                isinstance(old_links, list)
                and isinstance(new_links, list)
                and not set(map(str, old_links)).issubset(set(map(str, new_links)))
            ):
                failures.append(
                    f"COMPONENT_SUPERSESSION_LINK_SHRANK:{label}:{component_id}:{link_field}"
                )
        if (
            isinstance(old_component.get("superseded_by"), list)
            and old_component.get("superseded_by")
            and (
                new_component.get("production_reachable") is not False
                or new_component.get("writes_authority") is not False
            )
        ):
            failures.append(f"SUPERSEDED_COMPONENT_REACTIVATED:{label}:{component_id}")
        lost_fields = [
            field
            for field in COMPONENT_AUTHORITY_INERTIA_FIELDS
            if old_component.get(field) is True and new_component.get(field) is not True
        ]
        if not lost_fields:
            continue
        domain_id = str(old_component.get("domain_id", ""))
        domain_retired = (
            new_domains.get(domain_id, {}).get("lifecycle") != "ACTIVE_CURRENT_DOMAIN"
            and _domain_retirement_evidence_complete(new_domains.get(domain_id))
        )
        superseded = _component_deactivation_is_superseded(
            component_id, new_components, supersession_entries
        )
        if not (domain_retired or superseded):
            for field in lost_fields:
                failures.append(
                    f"COMPONENT_AUTHORITY_SURFACE_SILENT_DOWNGRADE:{label}:{component_id}:{field}"
                )
    for domain_id, old_owner_row in old_owners.items():
        new_owner_row = new_owners.get(domain_id)
        if not new_owner_row or old_owner_row.get("unique_owner") == new_owner_row.get("unique_owner"):
            continue
        if _pending_domain_first_owner_activation(
            domain_id,
            old_domains,
            new_domains,
            old_components,
            new_components,
            old_owner_row,
        ):
            continue
        old_component_id = str(old_domains.get(domain_id, {}).get("owner_component_id", ""))
        new_component_id = str(new_domains.get(domain_id, {}).get("owner_component_id", ""))
        if not _supersession_chain_is_atomic(
            old_component_id,
            new_component_id,
            new_components,
            supersession_entries,
        ):
            failures.append(f"OWNER_SILENT_REPLACEMENT:{label}:{domain_id}")

    old_stages = _index(previous["inherited_green"].get("stages", []), "stage_id")
    new_stages = _index(current["inherited_green"].get("stages", []), "stage_id")
    old_stage_sequence = [
        row.get("stage_id")
        for row in previous["inherited_green"].get("stages", [])
        if isinstance(row, dict)
    ]
    new_stage_sequence = [
        row.get("stage_id")
        for row in current["inherited_green"].get("stages", [])
        if isinstance(row, dict)
    ]
    if new_stage_sequence[: len(old_stage_sequence)] != old_stage_sequence:
        failures.append(f"INHERITED_STAGE_ORDER_OR_PREFIX_CHANGED:{label}")
    old_steps = _index(previous["golden"].get("steps", []), "step_id")
    new_steps = _index(current["golden"].get("steps", []), "step_id")
    golden_green_statuses = {"ISOLATED_GREEN", "PRODUCTION_GREEN", "HUMAN_GREEN"}
    newly_proven_golden_step_ids = {
        step_id
        for step_id, step in new_steps.items()
        if step.get("status") in golden_green_statuses
        and (
            step_id not in old_steps
            or old_steps[step_id].get("status") in {"PENDING", "UNVERIFIED"}
        )
    }
    for stage_id, old in old_stages.items():
        new = new_stages.get(stage_id)
        if new is None:
            failures.append(f"INHERITED_GREEN_SILENT_REMOVAL:{label}:{stage_id}")
        elif old.get("ledger_status") in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"}:
            if new.get("ledger_status") not in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"} and not (
                new.get("ledger_status") == "REGRESSED_WITH_EVIDENCE"
                and _regression_evidence_complete(
                    new.get("regression"), str(old.get("ledger_status"))
                )
            ):
                failures.append(f"INHERITED_GREEN_SILENT_REMOVAL:{label}:{stage_id}")
        elif old.get("ledger_status") == "REGRESSED_WITH_EVIDENCE":
            prior = str(old.get("regression", {}).get("prior_status", ""))
            recovered = new.get("ledger_status") in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"}
            retained = (
                new.get("ledger_status") == "REGRESSED_WITH_EVIDENCE"
                and _same_regression_identity(old.get("regression"), new.get("regression"))
            )
            if prior not in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"} or not (
                recovered or retained
            ):
                failures.append(f"INHERITED_GREEN_REGRESSION_NOT_STICKY:{label}:{stage_id}")
    for stage_id in sorted(set(new_stages) - set(old_stages)):
        stage = new_stages[stage_id]
        if stage.get("ledger_status") == "REGRESSED_WITH_EVIDENCE":
            failures.append(f"INHERITED_STAGE_REGRESSION_WITHOUT_GREEN_ORIGIN:{label}:{stage_id}")
        elif stage.get("ledger_status") in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"}:
            golden_step_ids = stage.get("golden_step_ids")
            infrastructure_stage = bool(
                stage.get("stage_kind") == "INFRASTRUCTURE"
                and _nonempty(stage.get("infrastructure_justification"))
            )
            playable_stage = bool(
                isinstance(golden_step_ids, list)
                and golden_step_ids
                and all(
                    isinstance(step_id, str)
                    and step_id in newly_proven_golden_step_ids
                    for step_id in golden_step_ids
                )
            )
            if not (infrastructure_stage or playable_stage):
                failures.append(
                    f"INHERITED_STAGE_WITHOUT_NEW_GOLDEN_CAPABILITY:{label}:{stage_id}"
                )

    old_status = previous["inherited_green"].get("canonical_pr_status")
    new_status = current["inherited_green"].get("canonical_pr_status")
    stage_status_rank = {"ISOLATED_GREEN": 1, "PRODUCTION_GREEN": 2, "HUMAN_GREEN": 3}
    if isinstance(old_status, dict) and isinstance(new_status, dict):
        for stage_number, stage_id in enumerate(CANONICAL_STAGE_IDS, start=1):
            old_value = old_status.get(f"stage_{stage_number}_status")
            new_value = new_status.get(f"stage_{stage_number}_status")
            if old_value in stage_status_rank and new_value in stage_status_rank:
                if stage_status_rank[new_value] < stage_status_rank[old_value]:
                    failures.append(
                        f"CANONICAL_STAGE_STATUS_DOWNGRADE:{label}:{stage_number}"
                    )
            elif old_value in stage_status_rank and new_value == "REGRESSED_WITH_EVIDENCE":
                stage = new_stages.get(stage_id, {})
                if not _regression_evidence_complete(stage.get("regression")):
                    failures.append(
                        f"CANONICAL_STAGE_STATUS_REGRESSION_EVIDENCE_MISSING:{label}:{stage_number}"
                    )
            elif old_value == "REGRESSED_WITH_EVIDENCE":
                old_stage = old_stages.get(stage_id, {})
                new_stage = new_stages.get(stage_id, {})
                retained = bool(
                    new_value == "REGRESSED_WITH_EVIDENCE"
                    and _same_regression_identity(
                        old_stage.get("regression"), new_stage.get("regression")
                    )
                )
                recovered = new_value in stage_status_rank
                if not (retained or recovered):
                    failures.append(
                        f"CANONICAL_STAGE_STATUS_REGRESSION_NOT_STICKY:{label}:{stage_number}"
                    )
        old_latest = old_status.get("latest_completed_stage")
        new_latest = new_status.get("latest_completed_stage")
        if old_latest in old_stage_sequence and new_latest in new_stage_sequence:
            if new_stage_sequence.index(new_latest) < old_stage_sequence.index(old_latest):
                failures.append(f"CANONICAL_LATEST_STAGE_ROLLBACK:{label}")

    rank = {"PENDING": 0, "ISOLATED_GREEN": 1, "PRODUCTION_GREEN": 2, "HUMAN_GREEN": 3}
    for step_id, old in old_steps.items():
        new = new_steps.get(step_id)
        if new is None:
            failures.append(f"GOLDEN_SCENARIO_STEP_DELETE:{label}:{step_id}")
            continue
        old_status = old.get("status")
        new_status = new.get("status")
        allowed_statuses = set(rank) | {"REGRESSED_WITH_EVIDENCE"}
        if old_status not in allowed_statuses:
            failures.append(f"GOLDEN_SCENARIO_PREVIOUS_STATUS_INVALID:{label}:{step_id}")
        if new_status not in allowed_statuses:
            failures.append(f"GOLDEN_SCENARIO_STATUS_INVALID:{label}:{step_id}")
        if old_status in rank and new_status in rank and rank[new_status] < rank[old_status]:
            failures.append(f"GOLDEN_SCENARIO_STEP_DOWNGRADE:{label}:{step_id}")
        elif old_status in rank and new_status == "REGRESSED_WITH_EVIDENCE":
            if old_status == "PENDING" or not _regression_evidence_complete(
                new.get("regression"), str(old_status)
            ):
                failures.append(f"GOLDEN_SCENARIO_REGRESSION_EVIDENCE_MISSING:{label}:{step_id}")
        elif old_status == "REGRESSED_WITH_EVIDENCE":
            prior = str(old.get("regression", {}).get("prior_status", ""))
            retained = (
                new_status == "REGRESSED_WITH_EVIDENCE"
                and _same_regression_identity(old.get("regression"), new.get("regression"))
            )
            recovered = prior in rank and new_status in rank and rank[new_status] >= rank[prior]
            if not (retained or recovered):
                failures.append(f"GOLDEN_SCENARIO_REGRESSION_NOT_STICKY:{label}:{step_id}")
    for step_id in sorted(set(new_steps) - set(old_steps)):
        if new_steps[step_id].get("status") == "REGRESSED_WITH_EVIDENCE":
            failures.append(f"GOLDEN_SCENARIO_REGRESSION_WITHOUT_GREEN_ORIGIN:{label}:{step_id}")

    old_categories = _index(previous["card_matrix"].get("category_matrix", []), "category_id")
    new_categories = _index(current["card_matrix"].get("category_matrix", []), "category_id")
    for category_id, old in old_categories.items():
        new = new_categories.get(category_id)
        if new is None:
            failures.append(f"CARD_CERTIFICATION_CATEGORY_DELETE:{label}:{category_id}")
            continue
        old_cert = old.get("certification", {})
        new_cert = new.get("certification", {})
        if isinstance(old_cert, dict) and isinstance(new_cert, dict):
            for field, old_value in old_cert.items():
                if old_value is True and new_cert.get(field) is not True and not (
                    new_cert.get(field) == "REGRESSED_WITH_EVIDENCE"
                    and _regression_evidence_complete(
                        new.get("regression"), "CERTIFIED_TRUE"
                    )
                ):
                    failures.append(f"CARD_CERTIFICATION_RESET:{label}:{category_id}:{field}")
                if old_value == "REGRESSED_WITH_EVIDENCE":
                    retained = (
                        new_cert.get(field) == "REGRESSED_WITH_EVIDENCE"
                        and _same_regression_identity(
                            old.get("regression"), new.get("regression")
                        )
                    )
                    recovered = new_cert.get(field) is True
                    if not (retained or recovered):
                        failures.append(
                            f"CARD_CERTIFICATION_REGRESSION_NOT_STICKY:{label}:{category_id}:{field}"
                        )
                elif (
                    new_cert.get(field) == "REGRESSED_WITH_EVIDENCE"
                    and old_value is not True
                ):
                    failures.append(
                        f"CARD_CERTIFICATION_REGRESSION_WITHOUT_GREEN_ORIGIN:{label}:{category_id}:{field}"
                    )
    for category_id in sorted(set(new_categories) - set(old_categories)):
        new_cert = new_categories[category_id].get("certification", {})
        if isinstance(new_cert, dict) and any(
            value == "REGRESSED_WITH_EVIDENCE" for value in new_cert.values()
        ):
            failures.append(
                f"CARD_CERTIFICATION_REGRESSION_WITHOUT_GREEN_ORIGIN:{label}:{category_id}"
            )

    old_alpha = previous["card_matrix"].get("aggregate", {}).get("alpha07_certified_card_count")
    new_alpha = current["card_matrix"].get("aggregate", {}).get("alpha07_certified_card_count")
    if _is_int(old_alpha) and _is_int(new_alpha) and new_alpha < old_alpha:
        failures.append(f"ALPHA07_CERTIFIED_CARD_COUNT_NOT_MONOTONIC:{label}")
    return failures


@dataclass
class ValidationInput:
    authorities: dict[str, dict[str, Any]]
    implementation_paths: dict[str, list[str]]
    baseline_authorities: dict[str, dict[str, Any]]
    changed_paths: list[dict[str, str]]
    gate_changed_paths: list[dict[str, str]]
    pr_body: str
    stage_parent_is_descendant: bool
    scanner_presence: dict[str, bool] | None = None
    component_presence: dict[str, bool] | None = None
    component_declared_classes: dict[str, str] | None = None
    evidence_artifact_bindings: dict[str, dict[str, Any]] | None = None
    git_commit_tree_bindings: dict[str, str] | None = None
    regression_commit_bindings: set[str] | None = None
    evidence_subject_is_baseline_descendant: bool = True
    evidence_subject_is_head_ancestor: bool = True
    evidence_subject_product_tree_matches_head: bool = True
    retired_scanner_status: str = "PASS"


def validate_model(data: ValidationInput) -> dict[str, Any]:
    failures: list[str] = []
    metrics: dict[str, Any] = {
        "CANONICAL_REUSE_GATE_IMPLEMENTATION_COUNT": 1,
        "EXISTING_SCANNER_INVENTORY_COUNT": len(SCANNER_INVENTORY),
        "REUSED_SCANNER_COUNT": len(SCANNER_INVENTORY),
        "NEW_SCANNER_REASON": "NO_EXISTING_SCANNER_ACCEPTS_GIT_BASE_HEAD_DELTA_AND_PR_BODY_WITHOUT_GODOT",
        "PARALLEL_ARCHITECTURE_SCANNER_COUNT_DELTA": 0,
        "HISTORICAL_REUSE_REGISTRY_IMPLEMENTATION_COUNT": len(
            data.implementation_paths.get("historical_reuse", [])
        ),
        "OWNER_REUSE_MAP_IMPLEMENTATION_COUNT": len(
            data.implementation_paths.get("owner_map", [])
        ),
        "INHERITED_GREEN_LEDGER_IMPLEMENTATION_COUNT": len(
            data.implementation_paths.get("inherited_green", [])
        ),
        "GOLDEN_PLAYTEST_SCENARIO_IMPLEMENTATION_COUNT": len(
            data.implementation_paths.get("golden", [])
        ),
        "ACTIVE_DOMAIN_OWNER_COUNT_MISMATCH": 0,
        "PENDING_DOMAIN_IMPLICIT_OWNER_COUNT": 0,
        "RETIRED_DOMAIN_ACTIVE_OWNER_COUNT": 0,
        "REFERENCE_ONLY_AUTHORITY_WRITE_COUNT": 0,
        "PARALLEL_PRODUCTION_OWNER_COUNT": 0,
        "NEW_OWNER_WITHOUT_REUSE_SCAN_COUNT": 0,
        "NEW_OWNER_WITH_REUSABLE_EXISTING_OWNER_COUNT": 0,
        "UNJUSTIFIED_REIMPLEMENTATION_COUNT": 0,
        "UNCLASSIFIED_NEW_COMPONENT_COUNT": 0,
        "REGISTERED_COMPONENT_PATH_MISSING_COUNT": 0,
        "NON_OWNER_WITHOUT_OWNER_BINDING_COUNT": 0,
        "DIAGNOSTIC_BENCH_PRODUCTION_OWNER_COUNT": 0,
        "TEST_SUPPORT_PRODUCTION_OWNER_COUNT": 0,
        "OWNER_REPLACEMENT_WITHOUT_SUPERSESSION_COUNT": 0,
        "DUAL_WRITE_COUNT": 0,
        "FALLBACK_COUNT": 0,
        "OLD_OWNER_STILL_PRODUCTION_REACHABLE_COUNT": 0,
        "RETIRED_IMPLEMENTATION_REACTIVATION_COUNT": 0,
        "INHERITED_GREEN_SILENT_REMOVAL_COUNT": 0,
        "OWNER_SILENT_REPLACEMENT_COUNT": 0,
        "COMPONENT_INVENTORY_SILENT_DELETE_COUNT": 0,
        "DOMAIN_INVENTORY_SILENT_DELETE_COUNT": 0,
        "UNIQUE_OWNER_DOMAIN_SILENT_DELETE_COUNT": 0,
        "COMPONENT_IDENTITY_SILENT_REPLACEMENT_COUNT": 0,
        "GLOBAL_AUTHORITY_SURFACE_OWNER_MISMATCH_COUNT": 0,
        "GOLDEN_SCENARIO_STEP_DELETE_COUNT": 0,
        "GOLDEN_SCENARIO_STEP_COUNT_MONOTONIC": True,
        "GOLDEN_HUMAN_FALSE_GREEN_COUNT": 0,
        "GOLDEN_PRODUCTION_FALSE_GREEN_COUNT": 0,
        "DIAGNOSTIC_AS_HUMAN_PASS_COUNT": 0,
        "CARD_CERTIFICATION_RESET_COUNT": 0,
        "ALPHA07_CERTIFIED_CARD_COUNT_MONOTONIC": True,
        "CERTIFIED_CARD_SILENT_REGRESSION_COUNT": 0,
        "HISTORICAL_REUSE_ENTRY_SILENT_DELETE_COUNT": 0,
        "UNJUSTIFIED_FULL_REPROOF_COUNT": 0,
        "TOOLING_ONLY_FULL_PRODUCT_REPROOF_COUNT": 0,
        "UNTOUCHED_LEGACY_DEBT_BLOCK_COUNT": 0,
        "TOUCHED_UNCLASSIFIED_LEGACY_COMPONENT_COUNT": 0,
        "PRODUCT_CODE_CHANGE_COUNT": 0,
        "PRODUCT_RULE_CHANGE_COUNT": 0,
        "UNNECESSARY_FULL_SUITE_RUN_COUNT": 0,
        "FULL_WORLD_REPROOF_COUNT": 0,
        "CHANGE_CLASS_DECLARED": False,
        "TEST_SCOPE_DERIVED_FROM_CHANGE_CLASS": False,
        "PR93_BODY_STATUS_BLOCK_PRESENT": False,
        "PR93_BODY_STATUS_MATCH": False,
        "PR93_DESCRIPTION_STAGE3_CURRENT": False,
        "PR93_BODY_STALE_STAGE_COUNT": 0,
        "PR93_DESCRIPTION_FALSE_GREEN_COUNT": 0,
        "STAGE_PARENT_IS_PREVIOUS_STAGE_DESCENDANT": data.stage_parent_is_descendant,
        "DELTA_ONLY_GATE": True,
        "LEGACY_UNTOUCHED_DEBT_BLOCK_COUNT": 0,
        "NEW_OR_CHANGED_COMPONENT_GATE_COVERAGE": "0_PERCENT",
        "CI_GATE_READ_ONLY": True,
        "CI_PRODUCT_RUNTIME_MUTATION_COUNT": 0,
        "CI_GAMEPLAY_EXECUTION_COUNT": 0,
        "CI_FULL_PRODUCT_REPROOF_COUNT": 0,
        "AGENT_MERGE_REQUIRES_REUSE_GATE": False,
        "READY_TRANSITION_WITHOUT_GATE_COUNT": 0,
        "MERGE_WITHOUT_GATE_COUNT": 0,
        "GITHUB_REQUIRED_STATUS_CHECK_CONFIGURED": False,
        "GITHUB_REQUIRED_STATUS_CONFIGURATION_PENDING": True,
    }

    for key in SCHEMA_PREFIXES:
        count = len(data.implementation_paths.get(key, []))
        if count != 1:
            failures.append(f"AUTHORITY_IMPLEMENTATION_COUNT:{key}:{count}")
    if len(data.implementation_paths.get("owner_map", [])) != 1:
        failures.append(
            "AUTHORITY_IMPLEMENTATION_COUNT:owner_map:"
            f"{len(data.implementation_paths.get('owner_map', []))}"
        )
    if len(data.authorities) != len(SCHEMA_PREFIXES):
        failures.append("AUTHORITY_DISCOVERY_INCOMPLETE")
        return {"status": "FAIL", "failures": failures, "metrics": metrics}

    failures.extend(
        _regression_binding_failures(
            data.authorities,
            "HEAD",
            "CANONICAL",
            data.regression_commit_bindings,
        )
    )

    registry = data.authorities["historical_reuse"]
    supersession = data.authorities["supersession"]
    inherited = data.authorities["inherited_green"]
    golden = data.authorities["golden"]
    card = data.authorities["card_matrix"]

    for key, (expected_schema, id_field, expected_id) in AUTHORITY_CONTRACTS.items():
        authority = data.authorities[key]
        if authority.get("schema_version") != expected_schema:
            failures.append(f"AUTHORITY_SCHEMA_MISMATCH:{key}")
        if authority.get(id_field) != expected_id:
            failures.append(f"AUTHORITY_ID_MISMATCH:{key}")

    evidence_subject_sha = registry.get("candidate_head_sha")
    inherited_candidate = inherited.get("candidate")
    if not _is_hex(evidence_subject_sha, 40):
        failures.append("EVIDENCE_SUBJECT_SHA_INVALID")
    if not (
        isinstance(inherited_candidate, dict)
        and inherited_candidate.get("head_sha") == evidence_subject_sha
        and _is_hex(inherited_candidate.get("tree_sha"), 40)
    ):
        failures.append("INHERITED_CANDIDATE_IDENTITY_MISMATCH")
    elif (
        data.git_commit_tree_bindings is None
        or data.git_commit_tree_bindings.get(str(evidence_subject_sha))
        != inherited_candidate.get("tree_sha")
    ):
        failures.append("EVIDENCE_SUBJECT_GIT_TREE_MISMATCH")
    if not data.evidence_subject_product_tree_matches_head:
        failures.append("EVIDENCE_SUBJECT_PRODUCT_TREE_DRIFT")
    if not data.evidence_subject_is_head_ancestor:
        failures.append("EVIDENCE_SUBJECT_NOT_HEAD_ANCESTOR")
    if golden.get("candidate_head_sha") != evidence_subject_sha:
        failures.append("GOLDEN_EVIDENCE_SUBJECT_MISMATCH")

    for scanner in SCANNER_INVENTORY:
        if data.scanner_presence is not None and not data.scanner_presence.get(
            str(scanner["scanner_id"]), False
        ):
            failures.append(f"SCANNER_MISSING:{scanner['scanner_id']}")
    if data.retired_scanner_status != "PASS":
        failures.append("REUSED_RETIRED_MECHANIC_SCANNER_FAILED")
    if inherited.get("point_inertia_baseline_sha") != V076_GATE_BASE_SHA:
        failures.append("POINT_INERTIA_BASELINE_IDENTITY_MISMATCH")

    components = registry.get("component_inventory", [])
    domains = registry.get("domain_inventory", [])
    if not isinstance(components, list) or not isinstance(domains, list):
        failures.append("COMPONENT_OR_DOMAIN_INVENTORY_MISSING")
        components = []
        domains = []

    component_ids = [str(x.get("component_id", "")) for x in components if isinstance(x, dict)]
    component_paths = [str(x.get("path", "")) for x in components if isinstance(x, dict)]
    if not _unique(component_ids) or "" in component_ids:
        failures.append("COMPONENT_ID_NOT_UNIQUE")
    if not _unique(component_paths) or "" in component_paths:
        failures.append("COMPONENT_PATH_NOT_UNIQUE")
    component_classes = [
        str(x.get("class_name", "")) for x in components if isinstance(x, dict)
    ]
    if not _unique(component_classes) or "" in component_classes:
        failures.append("COMPONENT_CLASS_NAME_NOT_UNIQUE")
    by_component = _index(components, "component_id")
    by_path = _index(components, "path")
    domain_ids = [str(x.get("domain_id", "")) for x in domains if isinstance(x, dict)]
    if not _unique(domain_ids) or "" in domain_ids:
        failures.append("DOMAIN_ID_NOT_UNIQUE")
    domain_id_set = set(domain_ids)
    by_domain = _index(domains, "domain_id")
    unique_owner_rows = registry.get("unique_owner_domains", [])
    unique_owner_domain_ids = [
        str(row.get("domain_id", ""))
        for row in unique_owner_rows
        if isinstance(row, dict)
    ]
    if (
        not isinstance(unique_owner_rows, list)
        or not _unique(unique_owner_domain_ids)
        or set(unique_owner_domain_ids) != domain_id_set
    ):
        failures.append("UNIQUE_OWNER_DOMAIN_INVENTORY_MISMATCH")
    reuse_rows = registry.get("reuse_entries", [])
    reuse_id_list = [
        str(row.get("reuse_id", "")) for row in reuse_rows
        if isinstance(row, dict) and isinstance(row.get("reuse_id"), str)
    ]
    reuse_ids = set(reuse_id_list)
    if not _unique(reuse_id_list) or "" in reuse_ids:
        failures.append("HISTORICAL_REUSE_ID_NOT_UNIQUE")

    for component in components:
        if not isinstance(component, dict):
            failures.append("COMPONENT_ROW_NOT_OBJECT")
            continue
        failures.extend(
            _component_row_contract_failures(
                component, reuse_ids, "HEAD", "COMPONENT"
            )
        )
        missing = sorted(COMPONENT_REQUIRED_FIELDS - set(component))
        component_id = str(component.get("component_id", ""))
        component_path = str(component.get("path", ""))
        component_domain_id = str(component.get("domain_id", ""))
        missing_path_is_retired_replacement = bool(
            component.get("production_reachable") is False
            and component.get("writes_authority") is False
            and isinstance(component.get("superseded_by"), list)
            and component.get("superseded_by")
        )
        missing_path_is_retired_domain = bool(
            by_domain.get(component_domain_id, {}).get("lifecycle") == "RETIRED_DOMAIN"
            and _domain_retirement_evidence_complete(by_domain.get(component_domain_id))
            and all(component.get(field) is False for field in COMPONENT_AUTHORITY_INERTIA_FIELDS)
        )
        if (
            data.component_presence is not None
            and data.component_presence.get(component_path) is not True
            and not missing_path_is_retired_replacement
            and not missing_path_is_retired_domain
        ):
            metrics["REGISTERED_COMPONENT_PATH_MISSING_COUNT"] += 1
            failures.append(f"REGISTERED_COMPONENT_PATH_MISSING:{component_id}:{component_path}")
        if missing:
            failures.append(f"COMPONENT_REQUIRED_FIELDS:{component_id}:{','.join(missing)}")
        role = component.get("component_role")
        if role not in ALLOWED_COMPONENT_ROLES:
            failures.append(f"COMPONENT_ROLE_INVALID:{component_id}")
        if component_domain_id not in domain_id_set:
            failures.append(f"COMPONENT_DOMAIN_UNKNOWN:{component_id}:{component_domain_id}")
        for key in ("class_name", "path", "domain_id", "owner_component_id", "owner_path"):
            if not isinstance(component.get(key), str) or not component.get(key).strip():
                failures.append(f"COMPONENT_STRING_FIELD:{component_id}:{key}")
        for key in (
            "reuse_source_ids",
            "reuse_candidates_considered",
            "supersedes",
            "superseded_by",
            "focused_test_ids",
            "golden_scenario_steps",
        ):
            values = component.get(key)
            if not isinstance(values, list) or any(
                not isinstance(value, str) or not value.strip() for value in values
            ) or not _unique(values):
                failures.append(f"COMPONENT_STRING_LIST_FIELD:{component_id}:{key}")
        if component.get("change_class") not in ALLOWED_COMPONENT_CHANGE_CLASSES:
            failures.append(f"COMPONENT_CHANGE_CLASS_INVALID:{component_id}")
        for key in (
            "production_reachable",
            "writes_authority",
            "reads_authority",
            "owns_rng",
            "owns_tick",
            "owns_save",
            "owns_replay",
            "owns_identity",
            "owns_presentation",
        ):
            if not _is_bool(component.get(key)):
                failures.append(f"COMPONENT_BOOL_TYPE:{component_id}:{key}")
        if component.get("reuse_disposition") not in ALLOWED_DISPOSITIONS:
            failures.append(f"COMPONENT_REUSE_DISPOSITION:{component_id}")
        if role == "OWNER" and component.get("reuse_disposition") != "ADOPT_AS_OWNER":
            failures.append(f"OWNER_REUSE_DISPOSITION_INVALID:{component_id}")
        if role != "OWNER" and component.get("reuse_disposition") == "ADOPT_AS_OWNER":
            failures.append(f"NON_OWNER_ADOPT_AS_OWNER_INVALID:{component_id}")
        source_ids = component.get("reuse_source_ids", [])
        candidate_rows = component.get("reuse_candidates_considered", [])
        for source_id in (
            (source_ids if isinstance(source_ids, list) else [])
            + (candidate_rows if isinstance(candidate_rows, list) else [])
        ):
            if not isinstance(source_id, str) or source_id not in reuse_ids:
                failures.append(f"COMPONENT_REUSE_REFERENCE_UNKNOWN:{component_id}:{source_id}")
        owner_id = str(component.get("owner_component_id", ""))
        owner = by_component.get(owner_id)
        if role == "OWNER" and (
            owner_id != component_id or component.get("owner_path") != component_path
        ):
            failures.append(f"OWNER_SELF_BINDING_INVALID:{component_id}")
        if role != "OWNER":
            if not owner_id or owner_id not in by_component:
                metrics["NON_OWNER_WITHOUT_OWNER_BINDING_COUNT"] += 1
                failures.append(f"NON_OWNER_WITHOUT_OWNER_BINDING:{component_id}")
            elif owner.get("component_role") != "OWNER":
                metrics["NON_OWNER_WITHOUT_OWNER_BINDING_COUNT"] += 1
                failures.append(f"NON_OWNER_BOUND_TO_NON_OWNER:{component_id}:{owner_id}")
            elif component.get("production_reachable") is True and owner.get(
                "production_reachable"
            ) is not True:
                metrics["NON_OWNER_WITHOUT_OWNER_BINDING_COUNT"] += 1
                failures.append(f"NON_OWNER_BOUND_TO_INACTIVE_OWNER:{component_id}:{owner_id}")
            elif component.get("owner_path") != owner.get("path"):
                metrics["NON_OWNER_WITHOUT_OWNER_BINDING_COUNT"] += 1
                failures.append(f"NON_OWNER_OWNER_PATH_MISMATCH:{component_id}")
            elif (
                component.get("production_reachable") is True
                and by_domain.get(component_domain_id, {}).get("lifecycle")
                == "ACTIVE_CURRENT_DOMAIN"
                and by_domain.get(component_domain_id, {}).get("owner_component_id") != owner_id
            ):
                metrics["NON_OWNER_WITHOUT_OWNER_BINDING_COUNT"] += 1
                failures.append(f"NON_OWNER_NOT_BOUND_TO_DOMAIN_OWNER:{component_id}:{owner_id}")
        if (
            data.component_declared_classes is not None
            and component.get("production_reachable") is True
            and component_path.casefold().endswith(".gd")
            and data.component_declared_classes.get(component_path) != component.get("class_name")
        ):
            failures.append(f"COMPONENT_CLASS_DECLARATION_MISMATCH:{component_id}:{component_path}")
        if role == "DIAGNOSTIC_BENCH" and component.get("production_reachable"):
            metrics["DIAGNOSTIC_BENCH_PRODUCTION_OWNER_COUNT"] += 1
            failures.append(f"DIAGNOSTIC_BENCH_PRODUCTION_OWNER:{component_id}")
        if role == "TEST_SUPPORT" and component.get("production_reachable"):
            metrics["TEST_SUPPORT_PRODUCTION_OWNER_COUNT"] += 1
            failures.append(f"TEST_SUPPORT_PRODUCTION_OWNER:{component_id}")

    for domain in domains:
        if not isinstance(domain, dict):
            failures.append("DOMAIN_ROW_NOT_OBJECT")
            continue
        domain_id = str(domain.get("domain_id", ""))
        lifecycle = domain.get("lifecycle")
        expected_domain_fields = {"domain_id", "lifecycle", "owner_component_id"}
        if lifecycle == "RETIRED_DOMAIN" and "retirement_evidence" in domain:
            expected_domain_fields.add("retirement_evidence")
        if set(domain) != expected_domain_fields:
            failures.append(f"DOMAIN_SCHEMA_INVALID:{domain_id}")
        if "retirement_evidence" in domain and not _domain_retirement_evidence_complete(domain):
            failures.append(f"DOMAIN_RETIREMENT_EVIDENCE_INVALID:{domain_id}")
        if not isinstance(domain.get("owner_component_id"), str):
            failures.append(f"DOMAIN_OWNER_COMPONENT_TYPE:{domain_id}")
        if lifecycle not in DOMAIN_LIFECYCLES:
            failures.append(f"DOMAIN_LIFECYCLE_INVALID:{domain_id}")
            continue
        owners = [
            c
            for c in components
            if isinstance(c, dict)
            and c.get("domain_id") == domain_id
            and c.get("component_role") == "OWNER"
            and c.get("production_reachable") is True
            and c.get("reuse_disposition") == "ADOPT_AS_OWNER"
        ]
        if lifecycle == "ACTIVE_CURRENT_DOMAIN" and len(owners) != 1:
            metrics["ACTIVE_DOMAIN_OWNER_COUNT_MISMATCH"] += 1
            failures.append(f"ACTIVE_DOMAIN_OWNER_COUNT:{domain_id}:{len(owners)}")
        if lifecycle == "ACTIVE_CURRENT_DOMAIN" and len(owners) == 1:
            if domain.get("owner_component_id") != owners[0].get("component_id"):
                metrics["ACTIVE_DOMAIN_OWNER_COUNT_MISMATCH"] += 1
                failures.append(f"ACTIVE_DOMAIN_OWNER_BINDING:{domain_id}")
            owner_row = next(
                (
                    row for row in registry.get("unique_owner_domains", [])
                    if isinstance(row, dict) and row.get("domain_id") == domain_id
                ),
                None,
            )
            if not (
                isinstance(owner_row, dict)
                and owner_row.get("unique_owner") == owners[0].get("class_name")
                and owner_row.get("owner_path") == owners[0].get("path")
            ):
                metrics["ACTIVE_DOMAIN_OWNER_COUNT_MISMATCH"] += 1
                failures.append(f"ACTIVE_DOMAIN_UNIQUE_OWNER_MAP_MISMATCH:{domain_id}")
        if lifecycle == "PENDING_FUTURE_DOMAIN" and owners:
            metrics["PENDING_DOMAIN_IMPLICIT_OWNER_COUNT"] += len(owners)
            failures.append(f"PENDING_DOMAIN_IMPLICIT_OWNER:{domain_id}")
        if lifecycle == "RETIRED_DOMAIN" and owners:
            metrics["RETIRED_DOMAIN_ACTIVE_OWNER_COUNT"] += len(owners)
            failures.append(f"RETIRED_DOMAIN_ACTIVE_OWNER:{domain_id}")
        if lifecycle == "REFERENCE_ONLY_DOMAIN":
            writers = [
                c for c in components if isinstance(c, dict)
                and c.get("domain_id") == domain_id
                and c.get("writes_authority") is True
            ]
            if writers:
                metrics["REFERENCE_ONLY_AUTHORITY_WRITE_COUNT"] += len(writers)
                failures.append(f"REFERENCE_ONLY_AUTHORITY_WRITE:{domain_id}")
    metrics["PARALLEL_PRODUCTION_OWNER_COUNT"] = sum(
        max(0, len([
            c for c in components if isinstance(c, dict)
            and c.get("domain_id") == str(d.get("domain_id", ""))
            and c.get("component_role") == "OWNER"
            and c.get("production_reachable") is True
            and c.get("reuse_disposition") == "ADOPT_AS_OWNER"
        ]) - 1)
        for d in domains if isinstance(d, dict) and d.get("lifecycle") == "ACTIVE_CURRENT_DOMAIN"
    )
    for authority_flag in ("owns_tick", "owns_rng", "owns_save", "owns_replay"):
        owners = [
            component for component in components
            if isinstance(component, dict)
            and component.get("component_role") == "OWNER"
            and component.get("production_reachable") is True
            and component.get(authority_flag) is True
        ]
        if len(owners) > 1:
            excess = len(owners) - 1
            metrics["GLOBAL_AUTHORITY_SURFACE_OWNER_MISMATCH_COUNT"] += excess
            metrics["PARALLEL_PRODUCTION_OWNER_COUNT"] += excess
            failures.append(f"GLOBAL_AUTHORITY_SURFACE_PARALLEL_OWNER:{authority_flag}:{len(owners)}")

    snapshot_change_scope = inherited.get("canonical_change_scope", {})
    snapshot_change_classes = (
        snapshot_change_scope.get("change_classes", [])
        if isinstance(snapshot_change_scope, dict)
        else []
    )
    snapshot_product_scope = bool(
        isinstance(snapshot_change_classes, list)
        and set(snapshot_change_classes)
        & {
            "DOMAIN_CORE",
            "CROSS_DOMAIN_INTEGRATION",
            "PRODUCTION_COMPOSITION",
            "RULESET_CONSTITUTION",
            "RELEASE_CANDIDATE",
        }
    )
    pr_composition_delta = any(
        _is_product_composition_path(str(row.get("path", "")))
        for row in data.changed_paths
    )
    changed_component_raw_paths = {
        row["path"]
        for row in data.changed_paths
        if (
            _is_changed_component_candidate_path(row, pr_composition_delta)
            or _component_binding_path(row.get("path", "")) in by_path
        )
    }
    changed_component_paths = {
        _component_binding_path(path) for path in changed_component_raw_paths
    }
    unclassified = sorted(
        path
        for path in changed_component_raw_paths
        if _component_binding_path(path) not in by_path
    )
    metrics["UNCLASSIFIED_NEW_COMPONENT_COUNT"] = len(unclassified)
    if unclassified:
        failures.extend(f"UNCLASSIFIED_NEW_COMPONENT:{path}" for path in unclassified)
    metrics["NEW_OR_CHANGED_COMPONENT_GATE_COVERAGE"] = (
        "100_PERCENT" if not unclassified else
        f"{int(100 * (len(changed_component_raw_paths) - len(unclassified)) / max(1, len(changed_component_raw_paths)))}_PERCENT"
    )

    changed_authority_components = [
        component for component in components
        if isinstance(component, dict)
        and (
            component.get("path") in changed_component_paths
            or str(component.get("path", "")).startswith("scripts/v076/")
        )
        and (
            component.get("component_role") == "OWNER"
            or component.get("writes_authority") is True
            or any(
                component.get(key) is True
                for key in ("owns_rng", "owns_tick", "owns_save", "owns_replay", "owns_identity")
            )
        )
    ]
    retired_ids = {
        str(row.get("reuse_id", ""))
        for source in (
            data.baseline_authorities.get("historical_reuse", {}),
            registry,
        )
        for row in source.get("reuse_entries", [])
        if isinstance(row, dict) and row.get("disposition") == "RETIRED"
    }
    for component in components:
        if not isinstance(component, dict):
            continue
        component_path = str(component.get("path", ""))
        if component_path not in changed_component_paths:
            continue
        if component.get("production_reachable") is not True:
            continue
        component_id = str(component.get("component_id", ""))
        if retired_ids.intersection(set(map(str, component.get("reuse_source_ids", [])))):
            metrics["RETIRED_IMPLEMENTATION_REACTIVATION_COUNT"] += 1
            failures.append(f"RETIRED_IMPLEMENTATION_REACTIVATED:{component_id}")
    for component in changed_authority_components:
        component_id = str(component.get("component_id", ""))
        scan = component.get("reuse_scan")
        if not isinstance(scan, dict) or not REUSE_SCAN_FIELDS.issubset(scan):
            metrics["NEW_OWNER_WITHOUT_REUSE_SCAN_COUNT"] += 1
            failures.append(f"NEW_OWNER_WITHOUT_REUSE_SCAN:{component_id}")
            continue
        if any(scan.get(key) is not True for key in REUSE_SCAN_FIELDS if key.endswith("_search")):
            metrics["NEW_OWNER_WITHOUT_REUSE_SCAN_COUNT"] += 1
            failures.append(f"NEW_OWNER_WITHOUT_REUSE_SCAN:{component_id}")
        candidate_ids = scan.get("reuse_candidate_ids")
        if not isinstance(candidate_ids, list) or not candidate_ids:
            metrics["UNJUSTIFIED_REIMPLEMENTATION_COUNT"] += 1
            failures.append(f"OWNER_REUSE_CANDIDATES_EMPTY:{component_id}")
        elif (
            any(
                not isinstance(candidate_id, str)
                or candidate_id not in reuse_ids
                for candidate_id in candidate_ids
            )
            or not _unique(candidate_ids)
            or not set(candidate_ids).issubset(
                set(
                    component.get("reuse_candidates_considered", [])
                    if isinstance(component.get("reuse_candidates_considered"), list)
                    else []
                )
            )
        ):
            metrics["UNJUSTIFIED_REIMPLEMENTATION_COUNT"] += 1
            failures.append(f"OWNER_REUSE_CANDIDATES_INVALID:{component_id}")
        if not _is_int(scan.get("reuse_candidate_count")) or scan.get(
            "reuse_candidate_count"
        ) != len(candidate_ids if isinstance(candidate_ids, list) else []):
            metrics["UNJUSTIFIED_REIMPLEMENTATION_COUNT"] += 1
            failures.append(f"OWNER_REUSE_CANDIDATE_COUNT_MISMATCH:{component_id}")
        if scan.get("selected_reuse_disposition") != component.get("reuse_disposition"):
            metrics["UNJUSTIFIED_REIMPLEMENTATION_COUNT"] += 1
            failures.append(f"OWNER_REUSE_DISPOSITION_MISMATCH:{component_id}")
        for reason in (
            "why_existing_owner_cannot_be_extended",
            "why_adapter_is_insufficient",
            "why_new_owner_is_required",
        ):
            if not _nonempty(scan.get(reason)):
                metrics["UNJUSTIFIED_REIMPLEMENTATION_COUNT"] += 1
                failures.append(f"OWNER_REUSE_REASON_EMPTY:{component_id}:{reason}")
        if _nonempty(scan.get("reusable_existing_owner_id")):
            metrics["NEW_OWNER_WITH_REUSABLE_EXISTING_OWNER_COUNT"] += 1
            failures.append(f"NEW_OWNER_WITH_REUSABLE_EXISTING_OWNER:{component_id}")

    supersession_entries = [
        row for row in supersession.get("entries", []) if isinstance(row, dict)
    ]
    supersession_ids = [
        str(row.get("supersession_id", "")) for row in supersession_entries
    ]
    if (
        not isinstance(supersession.get("entries"), list)
        or len(supersession_entries) != len(supersession.get("entries", []))
        or not _unique(supersession_ids)
        or "" in supersession_ids
    ):
        failures.append("SUPERSESSION_ID_NOT_UNIQUE")
    if not _supersession_graph_is_acyclic(supersession_entries):
        failures.append("SUPERSESSION_GRAPH_INVALID")
    replacement_entries = [
        row
        for row in supersession_entries
        if row.get("old_component_id") is not None
        or row.get("new_component_id") is not None
    ]
    supersession_pairs = [
        (str(row.get("old_component_id", "")), str(row.get("new_component_id", "")))
        for row in replacement_entries
    ]
    if not _unique(f"{old}->{new}" for old, new in supersession_pairs):
        failures.append("SUPERSESSION_PAIR_NOT_UNIQUE")
    for row in replacement_entries:
        old_id = str(row.get("old_component_id", ""))
        new_id = str(row.get("new_component_id", ""))
        label = new_id or "UNKNOWN"
        missing = REPLACEMENT_REQUIRED_FIELDS - set(row)
        if missing:
            metrics["OWNER_REPLACEMENT_WITHOUT_SUPERSESSION_COUNT"] += 1
            failures.append(
                f"SUPERSESSION_FIELDS_MISSING:{label}:{','.join(sorted(missing))}"
            )
            continue
        for key in (
            "supersession_id",
            "kind",
            "domain_id",
            "old_component_id",
            "new_component_id",
            "old_owner_path",
            "new_owner_path",
            "replacement_reason",
            "migration_strategy",
            "save_impact",
            "rng_impact",
            "replay_impact",
            "cutover_commit",
            "old_owner_retirement_status",
        ):
            if not isinstance(row.get(key), str) or not row.get(key).strip():
                failures.append(f"SUPERSESSION_STRING_FIELD:{label}:{key}")
        if not _is_hex(row.get("cutover_commit"), 40):
            failures.append(f"SUPERSESSION_CUTOVER_COMMIT_INVALID:{label}")
        elif (
            data.git_commit_tree_bindings is not None
            and row.get("cutover_commit") not in data.git_commit_tree_bindings
        ):
            failures.append(f"SUPERSESSION_CUTOVER_COMMIT_NOT_FOUND:{label}")
        old_component = by_component.get(old_id)
        new_component = by_component.get(new_id)
        activation_grandfathered_replacement = bool(
            row.get("supersession_id") == "v076.kernel.v1-to-v2"
            and old_id == "component.v076.kernel.v1"
            and new_id == "component.v076.kernel"
            and isinstance(new_component, dict)
            and row.get("cutover_commit") == "2a365d465f199481da7fa1ef8f734e7525a136f5"
            and old_id in set(map(str, new_component.get("supersedes", [])))
        )
        if (
            (not isinstance(old_component, dict) or not isinstance(new_component, dict))
            and not activation_grandfathered_replacement
        ):
            failures.append(f"SUPERSESSION_COMPONENT_UNKNOWN:{old_id}->{new_id}")
        elif not activation_grandfathered_replacement:
            if not (
                row.get("domain_id") == old_component.get("domain_id")
                == new_component.get("domain_id")
            ):
                failures.append(f"SUPERSESSION_DOMAIN_MISMATCH:{old_id}->{new_id}")
            if (
                row.get("old_owner_path") != old_component.get("path")
                or row.get("new_owner_path") != new_component.get("path")
            ):
                failures.append(f"SUPERSESSION_PATH_MISMATCH:{old_id}->{new_id}")
            if not (
                new_id in set(map(str, old_component.get("superseded_by", [])))
                and old_id in set(map(str, new_component.get("supersedes", [])))
            ):
                failures.append(f"SUPERSESSION_RECIPROCAL_LINK_MISSING:{old_id}->{new_id}")
            new_is_current_owner = (
                new_component.get("component_role") == "OWNER"
                and new_component.get("production_reachable") is True
                and new_component.get("writes_authority") is True
            )
            new_is_retained_intermediate = (
                new_component.get("component_role") == "OWNER"
                and new_component.get("production_reachable") is False
                and new_component.get("writes_authority") is False
                and bool(new_component.get("superseded_by"))
            )
            if not (
                old_component.get("production_reachable") is False
                and old_component.get("writes_authority") is False
                and (new_is_current_owner or new_is_retained_intermediate)
            ):
                failures.append(f"SUPERSESSION_OWNER_STATE_INVALID:{old_id}->{new_id}")
        consumers = row.get("consumer_inventory")
        if not isinstance(consumers, list) or any(
            not isinstance(value, str) or not value.strip() for value in consumers
        ) or not _unique(consumers):
            failures.append(f"SUPERSESSION_CONSUMER_INVENTORY:{label}")
        for key in (
            "dual_write_count",
            "fallback_count",
            "old_owner_production_reachability",
            "new_owner_production_owner_count",
        ):
            if not _is_int(row.get(key)) or row.get(key) < 0:
                failures.append(f"SUPERSESSION_INTEGER_FIELD:{label}:{key}")
        metrics["DUAL_WRITE_COUNT"] += (
            row.get("dual_write_count", 0)
            if _is_int(row.get("dual_write_count", 0)) else 0
        )
        metrics["FALLBACK_COUNT"] += (
            row.get("fallback_count", 0)
            if _is_int(row.get("fallback_count", 0)) else 0
        )
        metrics["OLD_OWNER_STILL_PRODUCTION_REACHABLE_COUNT"] += (
            row.get("old_owner_production_reachability", 0)
            if _is_int(row.get("old_owner_production_reachability", 0)) else 0
        )
        if row.get("old_owner_retirement_status") != "RETIRED_BY_CONSTITUTION":
            failures.append(f"OLD_OWNER_NOT_RETIRED_BY_CONSTITUTION:{label}")
        if row.get("new_owner_production_owner_count") != 1:
            failures.append(f"NEW_OWNER_PRODUCTION_OWNER_COUNT:{label}")

    for component in components:
        if not isinstance(component, dict):
            continue
        component_id = str(component.get("component_id", ""))
        for old_id in set(map(str, component.get("supersedes", []))):
            matches = [
                row for row in supersession_entries
                if row.get("new_component_id") == component_id
                and row.get("old_component_id") == old_id
            ]
            if len(matches) != 1:
                metrics["OWNER_REPLACEMENT_WITHOUT_SUPERSESSION_COUNT"] += 1
                failures.append(f"OWNER_REPLACEMENT_WITHOUT_SUPERSESSION:{component_id}")
        for new_id in set(map(str, component.get("superseded_by", []))):
            matches = [
                row for row in supersession_entries
                if row.get("old_component_id") == component_id
                and row.get("new_component_id") == new_id
            ]
            if len(matches) != 1:
                metrics["OWNER_REPLACEMENT_WITHOUT_SUPERSESSION_COUNT"] += 1
                failures.append(f"SUPERSESSION_FORWARD_LINK_WITHOUT_ENTRY:{component_id}:{new_id}")
    if metrics["DUAL_WRITE_COUNT"]:
        failures.append("OWNER_REPLACEMENT_WITH_DUAL_WRITE")
    if metrics["FALLBACK_COUNT"]:
        failures.append("OWNER_REPLACEMENT_WITH_FALLBACK")
    if metrics["OLD_OWNER_STILL_PRODUCTION_REACHABLE_COUNT"]:
        failures.append("OLD_OWNER_STILL_PRODUCTION_REACHABLE")

    baseline_registry = data.baseline_authorities.get("historical_reuse", {})
    baseline_inherited = data.baseline_authorities.get("inherited_green", {})
    baseline_golden = data.baseline_authorities.get("golden", {})
    baseline_card = data.baseline_authorities.get("card_matrix", {})
    baseline_supersession = data.baseline_authorities.get("supersession", {})

    stage_rows = inherited.get("stages", [])
    baseline_stage_sequence = [
        row.get("stage_id")
        for row in baseline_inherited.get("stages", [])
        if isinstance(row, dict)
    ]
    head_stage_sequence = [
        row.get("stage_id") for row in stage_rows if isinstance(row, dict)
    ]
    if head_stage_sequence[: len(baseline_stage_sequence)] != baseline_stage_sequence:
        failures.append("INHERITED_STAGE_ORDER_OR_PREFIX_CHANGED")
    baseline_stage_ids_for_capability = set(
        _index(baseline_inherited.get("stages", []), "stage_id")
    )
    baseline_golden_for_capability = _index(
        baseline_golden.get("steps", []), "step_id"
    )
    head_golden_for_capability = _index(golden.get("steps", []), "step_id")
    new_golden_ids_for_capability = {
        step_id
        for step_id, step in head_golden_for_capability.items()
        if step.get("status") in {"ISOLATED_GREEN", "PRODUCTION_GREEN", "HUMAN_GREEN"}
        and (
            step_id not in baseline_golden_for_capability
            or baseline_golden_for_capability[step_id].get("status")
            in {"PENDING", "UNVERIFIED"}
        )
    }
    stage_ids = [
        str(row.get("stage_id", "")) for row in stage_rows if isinstance(row, dict)
    ]
    if not isinstance(stage_rows, list) or not _unique(stage_ids) or "" in stage_ids:
        failures.append("INHERITED_STAGE_ID_NOT_UNIQUE")
    for stage in stage_rows if isinstance(stage_rows, list) else []:
        if not isinstance(stage, dict):
            failures.append("INHERITED_STAGE_ROW_NOT_OBJECT")
            continue
        stage_id = str(stage.get("stage_id", ""))
        ledger_status = stage.get("ledger_status")
        if ledger_status not in LEDGER_STATUS_VALUES:
            failures.append(f"INHERITED_STAGE_LEDGER_STATUS_INVALID:{stage_id}")
        if ledger_status == "REGRESSED_WITH_EVIDENCE" and not _regression_evidence_complete(
            stage.get("regression")
        ):
            failures.append(f"INHERITED_STAGE_REGRESSION_EVIDENCE_MISSING:{stage_id}")
        if (
            stage_id not in baseline_stage_ids_for_capability
            and ledger_status in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"}
        ):
            golden_step_ids = stage.get("golden_step_ids")
            infrastructure_stage = bool(
                stage.get("stage_kind") == "INFRASTRUCTURE"
                and _nonempty(stage.get("infrastructure_justification"))
            )
            playable_stage = bool(
                isinstance(golden_step_ids, list)
                and golden_step_ids
                and all(
                    isinstance(step_id, str)
                    and step_id in new_golden_ids_for_capability
                    for step_id in golden_step_ids
                )
            )
            if not (infrastructure_stage or playable_stage):
                failures.append(f"INHERITED_STAGE_WITHOUT_NEW_GOLDEN_CAPABILITY:{stage_id}")

    golden_rows = golden.get("steps", [])
    golden_ids = [
        str(row.get("step_id", "")) for row in golden_rows if isinstance(row, dict)
    ]
    if not isinstance(golden_rows, list) or not _unique(golden_ids) or "" in golden_ids:
        failures.append("GOLDEN_STEP_ID_NOT_UNIQUE")
    for step in golden_rows if isinstance(golden_rows, list) else []:
        if not isinstance(step, dict):
            failures.append("GOLDEN_STEP_ROW_NOT_OBJECT")
            continue
        if step.get("status") not in {
            "PENDING",
            "ISOLATED_GREEN",
            "PRODUCTION_GREEN",
            "HUMAN_GREEN",
            "REGRESSED_WITH_EVIDENCE",
        }:
            failures.append(f"GOLDEN_STEP_STATUS_INVALID:{step.get('step_id', '')}")
        if step.get("status") == "REGRESSED_WITH_EVIDENCE" and not _regression_evidence_complete(
            step.get("regression")
        ):
            failures.append(
                f"GOLDEN_SCENARIO_REGRESSION_EVIDENCE_MISSING:{step.get('step_id', '')}"
            )
        for key in ("human_executed", "production_composition", "pass_claimed"):
            if not _is_bool(step.get(key)):
                failures.append(f"GOLDEN_STEP_BOOL_TYPE:{step.get('step_id', '')}:{key}")

    if isinstance(golden_rows, list):
        isolated_ids = [
            str(step.get("step_id"))
            for step in golden_rows
            if isinstance(step, dict) and step.get("status") == "ISOLATED_GREEN"
        ]
        production_ids = [
            str(step.get("step_id"))
            for step in golden_rows
            if isinstance(step, dict)
            and step.get("status") in {"PRODUCTION_GREEN", "HUMAN_GREEN"}
        ]
        human_ids = [
            str(step.get("step_id"))
            for step in golden_rows
            if isinstance(step, dict) and step.get("status") == "HUMAN_GREEN"
        ]
        pending_ids = [
            str(step.get("step_id"))
            for step in golden_rows
            if isinstance(step, dict) and step.get("status") == "PENDING"
        ]
        if golden.get("isolated_green_count") != len(isolated_ids):
            failures.append("GOLDEN_ISOLATED_COUNT_MISMATCH")
        if golden.get("production_pass_count") != len(production_ids):
            failures.append("GOLDEN_PRODUCTION_COUNT_MISMATCH")
        if golden.get("human_execution_count") != len(human_ids):
            failures.append("GOLDEN_HUMAN_COUNT_MISMATCH")
        summary = golden.get("summary")
        if not (
            isinstance(summary, dict)
            and summary.get("step_count") == len(golden_rows)
            and summary.get("isolated_green_step_ids") == isolated_ids
            and summary.get("pending_step_ids") == pending_ids
            and summary.get("production_pass_step_ids") == production_ids
            and summary.get("human_pass_step_ids") == human_ids
        ):
            failures.append("GOLDEN_SUMMARY_MISMATCH")

    base_reuse = _index(baseline_registry.get("reuse_entries", []), "reuse_id")
    head_reuse = _index(registry.get("reuse_entries", []), "reuse_id")
    missing_reuse = sorted(set(base_reuse) - set(head_reuse))
    metrics["HISTORICAL_REUSE_ENTRY_SILENT_DELETE_COUNT"] = len(missing_reuse)
    failures.extend(f"HISTORICAL_REUSE_ENTRY_SILENT_DELETE:{x}" for x in missing_reuse)

    base_supersession_entries = _index(
        baseline_supersession.get("entries", []), "supersession_id"
    )
    head_supersession_entries = _index(
        supersession.get("entries", []), "supersession_id"
    )
    baseline_supersession_contract_active = (
        baseline_supersession.get("schema_version")
        == AUTHORITY_CONTRACTS["supersession"][0]
    )
    for supersession_id, base_entry in base_supersession_entries.items():
        head_entry = head_supersession_entries.get(supersession_id)
        if head_entry is None:
            failures.append(f"SUPERSESSION_ENTRY_SILENT_DELETE:{supersession_id}")
        elif baseline_supersession_contract_active and head_entry != base_entry:
            failures.append(f"SUPERSESSION_ENTRY_MUTATED:{supersession_id}")
        elif not baseline_supersession_contract_active and any(
            key not in head_entry or head_entry.get(key) != value
            for key, value in base_entry.items()
        ):
            failures.append(
                f"SUPERSESSION_ACTIVATION_MIGRATION_NOT_ADDITIVE:{supersession_id}"
            )

    base_domains = _index(baseline_registry.get("domain_inventory", []), "domain_id")
    head_domains = _index(registry.get("domain_inventory", []), "domain_id")
    base_components = _index(baseline_registry.get("component_inventory", []), "component_id")
    head_components = _index(registry.get("component_inventory", []), "component_id")
    missing_components = sorted(set(base_components) - set(head_components))
    metrics["COMPONENT_INVENTORY_SILENT_DELETE_COUNT"] = len(missing_components)
    failures.extend(f"COMPONENT_INVENTORY_SILENT_DELETE:{x}" for x in missing_components)
    for component_id, old in base_components.items():
        new = head_components.get(component_id)
        if not new:
            continue
        if any(
            old.get(key) != new.get(key)
            for key in ("class_name", "path", "domain_id", "component_role")
        ):
            metrics["COMPONENT_IDENTITY_SILENT_REPLACEMENT_COUNT"] += 1
            failures.append(f"COMPONENT_IDENTITY_SILENT_REPLACEMENT:{component_id}")

        lost_fields = [
            field
            for field in COMPONENT_AUTHORITY_INERTIA_FIELDS
            if old.get(field) is True and new.get(field) is not True
        ]
        domain_id = str(old.get("domain_id", ""))
        domain_retired = (
            head_domains.get(domain_id, {}).get("lifecycle") != "ACTIVE_CURRENT_DOMAIN"
            and _domain_retirement_evidence_complete(head_domains.get(domain_id))
        )
        superseded = _component_deactivation_is_superseded(
            component_id, head_components, supersession_entries
        )
        if lost_fields and not (domain_retired or superseded):
            metrics["GLOBAL_AUTHORITY_SURFACE_OWNER_MISMATCH_COUNT"] += len(lost_fields)
            for field in lost_fields:
                failures.append(
                    f"COMPONENT_AUTHORITY_SURFACE_SILENT_DOWNGRADE:{component_id}:{field}"
                )

    base_domains = _index(baseline_registry.get("domain_inventory", []), "domain_id")
    head_domains = _index(registry.get("domain_inventory", []), "domain_id")
    missing_domains = sorted(set(base_domains) - set(head_domains))
    metrics["DOMAIN_INVENTORY_SILENT_DELETE_COUNT"] = len(missing_domains)
    failures.extend(f"DOMAIN_INVENTORY_SILENT_DELETE:{x}" for x in missing_domains)
    for domain_id, old in base_domains.items():
        new = head_domains.get(domain_id)
        if (
            new is not None
            and old.get("lifecycle") == "RETIRED_DOMAIN"
            and new.get("lifecycle") != "RETIRED_DOMAIN"
        ):
            failures.append(f"RETIRED_DOMAIN_REACTIVATED:{domain_id}")
        if (
            new is not None
            and old.get("lifecycle") == "ACTIVE_CURRENT_DOMAIN"
            and new.get("lifecycle") != "ACTIVE_CURRENT_DOMAIN"
            and not (
                new.get("lifecycle") == "RETIRED_DOMAIN"
                and _domain_retirement_evidence_complete(new)
            )
        ):
            failures.append(f"ACTIVE_DOMAIN_LIFECYCLE_SILENT_DOWNGRADE:{domain_id}")

    base_stages = _index(baseline_inherited.get("stages", []), "stage_id")
    head_stages = _index(inherited.get("stages", []), "stage_id")
    for stage_id, old in base_stages.items():
        new = head_stages.get(stage_id)
        if new is None:
            metrics["INHERITED_GREEN_SILENT_REMOVAL_COUNT"] += 1
            failures.append(f"INHERITED_GREEN_SILENT_REMOVAL:{stage_id}")
        elif old.get("ledger_status") in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"}:
            if new.get("ledger_status") not in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"}:
                if not (
                    new.get("ledger_status") == "REGRESSED_WITH_EVIDENCE"
                    and _regression_evidence_complete(
                        new.get("regression"), str(old.get("ledger_status"))
                    )
                ):
                    metrics["INHERITED_GREEN_SILENT_REMOVAL_COUNT"] += 1
                    failures.append(f"INHERITED_GREEN_SILENT_REMOVAL:{stage_id}")

    base_owners = _index(baseline_registry.get("unique_owner_domains", []), "domain_id")
    head_owners = _index(registry.get("unique_owner_domains", []), "domain_id")
    missing_owner_domains = sorted(set(base_owners) - set(head_owners))
    metrics["UNIQUE_OWNER_DOMAIN_SILENT_DELETE_COUNT"] = len(missing_owner_domains)
    failures.extend(f"UNIQUE_OWNER_DOMAIN_SILENT_DELETE:{x}" for x in missing_owner_domains)
    for domain_id, old in base_owners.items():
        new = head_owners.get(domain_id)
        if not new or old.get("unique_owner") == new.get("unique_owner"):
            continue
        if _pending_domain_first_owner_activation(
            domain_id,
            base_domains,
            head_domains,
            base_components,
            head_components,
            old,
        ):
            continue
        old_component_id = str(base_domains.get(domain_id, {}).get("owner_component_id", ""))
        new_component_id = str(head_domains.get(domain_id, {}).get("owner_component_id", ""))
        replacement_is_atomic = _supersession_chain_is_atomic(
            old_component_id,
            new_component_id,
            head_components,
            supersession_entries,
        )
        if not replacement_is_atomic:
            metrics["OWNER_SILENT_REPLACEMENT_COUNT"] += 1
            failures.append(f"OWNER_SILENT_REPLACEMENT:{domain_id}")
            replacement_failure = f"OWNER_REPLACEMENT_WITHOUT_SUPERSESSION:{new_component_id}"
            if replacement_failure not in failures:
                metrics["OWNER_REPLACEMENT_WITHOUT_SUPERSESSION_COUNT"] += 1
                failures.append(replacement_failure)

    base_steps = _index(baseline_golden.get("steps", []), "step_id")
    head_steps = _index(golden.get("steps", []), "step_id")
    removed_steps = sorted(set(base_steps) - set(head_steps))
    metrics["GOLDEN_SCENARIO_STEP_DELETE_COUNT"] = len(removed_steps)
    metrics["GOLDEN_SCENARIO_STEP_COUNT_MONOTONIC"] = not removed_steps
    failures.extend(f"GOLDEN_SCENARIO_STEP_DELETE:{x}" for x in removed_steps)
    rank = {"PENDING": 0, "ISOLATED_GREEN": 1, "PRODUCTION_GREEN": 2, "HUMAN_GREEN": 3}
    for step_id, old in base_steps.items():
        new = head_steps.get(step_id)
        if not new:
            continue
        old_status = old.get("status")
        new_status = new.get("status")
        if old_status in rank and new_status in rank and rank[new_status] < rank[old_status]:
            metrics["GOLDEN_SCENARIO_STEP_DELETE_COUNT"] += 1
            failures.append(f"GOLDEN_SCENARIO_STEP_DOWNGRADE:{step_id}")
        if new_status == "REGRESSED_WITH_EVIDENCE" and (
            old_status == "PENDING"
            or not _regression_evidence_complete(new.get("regression"), str(old_status))
        ):
            metrics["GOLDEN_SCENARIO_STEP_DELETE_COUNT"] += 1
            failures.append(f"GOLDEN_SCENARIO_REGRESSION_EVIDENCE_MISSING:{step_id}")
    for step_id, step in head_steps.items():
        status = step.get("status")
        if status == "HUMAN_GREEN" and not (
            step.get("human_executed") is True
            and step.get("production_composition") is True
            and step.get("pass_claimed") is True
            and _golden_human_evidence_complete(step, data)
        ):
            metrics["GOLDEN_HUMAN_FALSE_GREEN_COUNT"] += 1
            failures.append(f"GOLDEN_HUMAN_FALSE_GREEN:{step_id}")
        if status == "PRODUCTION_GREEN" and not (
            step.get("production_composition") is True
            and step.get("pass_claimed") is True
            and step.get("human_executed") is False
            and _golden_production_evidence_complete(step, data)
        ):
            metrics["GOLDEN_PRODUCTION_FALSE_GREEN_COUNT"] += 1
            failures.append(f"GOLDEN_PRODUCTION_FALSE_GREEN:{step_id}")
        surface = str(step.get("required_surface", "")).casefold()
        diagnostic_surface = bool(
            re.search(r"\bdiagnostic\b|\bbench\b|\bfixture\b", surface)
            or re.search(r"\bscripted\s+fixture\b", surface)
            or re.search(r"(?<!non-)\bheadless\s+simulation\b", surface)
        )
        if status == "HUMAN_GREEN" and diagnostic_surface:
            metrics["DIAGNOSTIC_AS_HUMAN_PASS_COUNT"] += 1
            failures.append(f"DIAGNOSTIC_AS_HUMAN_PASS:{step_id}")
        if status == "PRODUCTION_GREEN" and diagnostic_surface:
            metrics["GOLDEN_PRODUCTION_FALSE_GREEN_COUNT"] += 1
            failures.append(f"DIAGNOSTIC_AS_PRODUCTION_PASS:{step_id}")
        if status == "ISOLATED_GREEN" and not (
            step.get("human_executed") is False
            and step.get("production_composition") is False
            and step.get("pass_claimed") is True
            and _nonempty(step.get("evidence"))
        ):
            metrics["GOLDEN_PRODUCTION_FALSE_GREEN_COUNT"] += 1
            failures.append(f"GOLDEN_ISOLATED_EVIDENCE_INVALID:{step_id}")
        if status == "PENDING" and (
            step.get("human_executed") is not False or step.get("pass_claimed") is not False
        ):
            failures.append(f"GOLDEN_PENDING_FALSE_GREEN:{step_id}")

    if tuple(card.get("certification_dimensions", [])) != CARD_CERTIFICATION_FIELDS:
        failures.append("CARD_CERTIFICATION_DIMENSIONS_MISMATCH")
    head_category_rows = card.get("category_matrix", [])
    head_category_ids = [
        str(row.get("category_id", ""))
        for row in head_category_rows if isinstance(row, dict)
    ]
    if (
        not isinstance(head_category_rows, list)
        or not _unique(head_category_ids)
        or "" in head_category_ids
    ):
        failures.append("CARD_CERTIFICATION_CATEGORY_ID_NOT_UNIQUE")
    for row in head_category_rows if isinstance(head_category_rows, list) else []:
        if not isinstance(row, dict):
            failures.append("CARD_CERTIFICATION_CATEGORY_NOT_OBJECT")
            continue
        cert = row.get("certification")
        category_id = str(row.get("category_id", ""))
        if not _is_int(row.get("card_count")) or row.get("card_count", -1) < 0:
            failures.append(f"CARD_CERTIFICATION_CARD_COUNT_INVALID:{category_id}")
        if not isinstance(cert, dict) or set(cert) != set(CARD_CERTIFICATION_FIELDS):
            failures.append(f"CARD_CERTIFICATION_SCHEMA_INVALID:{category_id}")
            continue
        for field, value in cert.items():
            if not _is_bool(value) and value != "REGRESSED_WITH_EVIDENCE":
                failures.append(f"CARD_CERTIFICATION_VALUE_INVALID:{category_id}:{field}")
            if value == "REGRESSED_WITH_EVIDENCE" and not _regression_evidence_complete(
                row.get("regression")
            ):
                failures.append(f"CARD_CERTIFICATION_REGRESSION_EVIDENCE_MISSING:{category_id}:{field}")
        for index, field in enumerate(CARD_CERTIFICATION_FIELDS):
            if cert.get(field) is True and any(
                cert.get(prerequisite) is not True
                for prerequisite in CARD_CERTIFICATION_FIELDS[:index]
            ):
                failures.append(f"CARD_CERTIFICATION_PREREQUISITE_MISSING:{category_id}:{field}")
    base_categories = _index(baseline_card.get("category_matrix", []), "category_id")
    head_categories = _index(card.get("category_matrix", []), "category_id")
    for category_id, old in base_categories.items():
        new = head_categories.get(category_id)
        if new is None:
            metrics["CARD_CERTIFICATION_RESET_COUNT"] += 1
            failures.append(f"CARD_CERTIFICATION_CATEGORY_DELETE:{category_id}")
            continue
        old_cert = old.get("certification", {})
        new_cert = new.get("certification", {})
        if isinstance(old_cert, dict):
            for field, old_value in old_cert.items():
                if old_value is True and new_cert.get(field) is not True:
                    if not (
                        new_cert.get(field) == "REGRESSED_WITH_EVIDENCE"
                        and _regression_evidence_complete(
                            new.get("regression"), "CERTIFIED_TRUE"
                        )
                    ):
                        metrics["CARD_CERTIFICATION_RESET_COUNT"] += 1
                        metrics["CERTIFIED_CARD_SILENT_REGRESSION_COUNT"] += 1
                        failures.append(f"CARD_CERTIFICATION_RESET:{category_id}:{field}")
                elif (
                    new_cert.get(field) == "REGRESSED_WITH_EVIDENCE"
                    and old_value is not True
                ):
                    metrics["CARD_CERTIFICATION_RESET_COUNT"] += 1
                    metrics["CERTIFIED_CARD_SILENT_REGRESSION_COUNT"] += 1
                    failures.append(
                        f"CARD_CERTIFICATION_REGRESSION_WITHOUT_GREEN_ORIGIN:{category_id}:{field}"
                    )
    old_certified = baseline_card.get("aggregate", {}).get("alpha07_certified_card_count", 0)
    new_certified = card.get("aggregate", {}).get("alpha07_certified_card_count", 0)
    if not _is_int(old_certified) or old_certified < 0:
        failures.append("BASE_CARD_CERTIFIED_COUNT_INVALID")
        old_certified = 0
    if not _is_int(new_certified) or new_certified < 0:
        failures.append("CARD_CERTIFIED_COUNT_INVALID")
        new_certified = 0
    certified_card_sum = sum(
        row.get("card_count", 0)
        for row in head_category_rows
        if isinstance(row, dict)
        and _is_int(row.get("card_count"))
        and isinstance(row.get("certification"), dict)
        and row["certification"].get("ALPHA07_CERTIFIED")
        in {True, "REGRESSED_WITH_EVIDENCE"}
    )
    if new_certified != certified_card_sum:
        failures.append("ALPHA07_CERTIFIED_CARD_COUNT_AGGREGATE_MISMATCH")
    aggregate = card.get("aggregate", {})
    if not isinstance(aggregate, dict):
        failures.append("CARD_CERTIFICATION_AGGREGATE_INVALID")
    else:
        if aggregate.get("category_count") != len(head_category_rows):
            failures.append("CARD_CERTIFICATION_CATEGORY_COUNT_MISMATCH")
        category_card_sum = sum(
            row.get("card_count", 0)
            for row in head_category_rows
            if isinstance(row, dict) and _is_int(row.get("card_count"))
        )
        if aggregate.get("category_card_count_sum") != category_card_sum:
            failures.append("CARD_CERTIFICATION_CARD_SUM_MISMATCH")
    if new_certified < old_certified:
        metrics["CARD_CERTIFICATION_RESET_COUNT"] += 1
        metrics["ALPHA07_CERTIFIED_CARD_COUNT_MONOTONIC"] = False
        failures.append("ALPHA07_CERTIFIED_CARD_COUNT_NOT_MONOTONIC")

    change_scope = inherited.get("canonical_change_scope", {})
    failures.extend(_change_scope_contract_failures(change_scope, "HEAD", "CANONICAL"))
    change_classes = change_scope.get("change_classes", [])
    metrics["CHANGE_CLASS_DECLARED"] = bool(
        isinstance(change_classes, list)
        and change_classes
        and all(item in ALLOWED_CHANGE_CLASSES for item in change_classes)
        and _unique(map(str, change_classes))
    )
    if not metrics["CHANGE_CLASS_DECLARED"]:
        failures.append("CHANGE_CLASS_NOT_DECLARED")
    full_reproof = change_scope.get("full_reproof_required")
    if not _is_bool(full_reproof):
        metrics["UNJUSTIFIED_FULL_REPROOF_COUNT"] += 1
        failures.append("FULL_REPROOF_BOOL_TYPE_INVALID")
    elif full_reproof is True:
        reason = str(change_scope.get("full_reproof_trigger", "")).strip().casefold()
        tooling_only = bool(
            isinstance(change_classes, list)
            and set(change_classes).issubset({"TOOLING_ONLY", "DOCS_ONLY", "TEST_ORACLE_ONLY"})
        )
        if tooling_only:
            metrics["TOOLING_ONLY_FULL_PRODUCT_REPROOF_COUNT"] += 1
            failures.append("TOOLING_ONLY_FULL_PRODUCT_REPROOF")
        release_reproof_is_justified = bool(
            isinstance(change_classes, list)
            and "RELEASE_CANDIDATE" in change_classes
            and reason not in {
                "",
                "为了安全",
                "为了完整",
                "防止未知问题",
                "for safety",
                "for completeness",
            }
            and _nonempty(change_scope.get("affected_owners"))
            and _nonempty(change_scope.get("why_focused_tests_are_insufficient"))
        )
        if not release_reproof_is_justified:
            metrics["UNJUSTIFIED_FULL_REPROOF_COUNT"] += 1
            failures.append("UNJUSTIFIED_FULL_REPROOF")
    focused = change_scope.get("focused_tests", [])
    affected_domains = change_scope.get("affected_domains", [])
    affected_owners = change_scope.get("affected_owners", [])
    inherited_sentinels = change_scope.get("inherited_sentinels", [])
    scope_reason_is_complete = bool(
        _nonempty(change_scope.get("why_focused_tests_are_insufficient"))
        if full_reproof is True
        else _nonempty(change_scope.get("why_focused_tests_are_sufficient"))
    )
    metrics["TEST_SCOPE_DERIVED_FROM_CHANGE_CLASS"] = bool(
        isinstance(focused, list)
        and focused
        and isinstance(affected_domains, list)
        and affected_domains
        and isinstance(affected_owners, list)
        and isinstance(inherited_sentinels, list)
        and inherited_sentinels
        and scope_reason_is_complete
    )
    if not metrics["TEST_SCOPE_DERIVED_FROM_CHANGE_CLASS"]:
        failures.append("FOCUSED_TEST_SCOPE_MISSING")
    if isinstance(change_classes, list) and set(change_classes).issubset(
        {"TOOLING_ONLY", "DOCS_ONLY", "TEST_ORACLE_ONLY"}
    ):
        if not (
            isinstance(focused, list)
            and REQUIRED_TOOLING_FOCUSED_TESTS.issubset(set(map(str, focused)))
        ):
            failures.append("TOOLING_FOCUSED_TEST_SET_INCOMPLETE")

    product_allowed = bool(
        set(change_classes if isinstance(change_classes, list) else [])
        & {
            "DOMAIN_CORE",
            "CROSS_DOMAIN_INTEGRATION",
            "PRODUCTION_COMPOSITION",
            "RULESET_CONSTITUTION",
            "RELEASE_CANDIDATE",
        }
    )
    gate_delta_paths = [row.get("path", "") for row in data.gate_changed_paths]
    for row in data.gate_changed_paths:
        for reference_failure in row.get("production_reference_failures", []):
            failures.append(
                f"{reference_failure}:{row.get('path', '')}"
            )
    gate_composition_delta = any(
        _is_product_composition_path(str(row.get("path", "")))
        for row in data.gate_changed_paths
    )
    gate_component_candidate_paths = [
        row.get("path", "")
        for row in data.gate_changed_paths
        if (
            _is_changed_component_candidate_path(
                row, gate_composition_delta, strict_composition_context=True
            )
            or _component_binding_path(str(row.get("path", ""))) in by_path
        )
    ]
    product_gate_paths = [
        path
        for path in gate_component_candidate_paths
        if (
            _component_binding_path(path) not in by_path
            or by_path[_component_binding_path(path)].get("production_reachable") is True
            or _is_forced_production_path(path)
            or any(
                row.get("path") == path
                and (
                    row.get("production_reachable") is True
                    or row.get("production_reachable_before") is True
                )
                for row in data.gate_changed_paths
            )
        )
    ]
    metrics["PRODUCT_CODE_CHANGE_COUNT"] = len(product_gate_paths)
    rule_paths = [
        str(row.get("path", ""))
        for row in data.gate_changed_paths
        if _is_rule_authority_path(str(row.get("path", "")))
        or row.get("rule_authority") is True
    ]
    metrics["PRODUCT_RULE_CHANGE_COUNT"] = len(rule_paths)
    if product_gate_paths and not product_allowed:
        failures.extend(f"TOOLING_GATE_PRODUCT_CODE_CHANGE:{p}" for p in product_gate_paths)
    product_gate_components = [
        by_path[_component_binding_path(path)]
        for path in product_gate_paths
        if _component_binding_path(path) in by_path
    ]
    required_domains = {
        str(component.get("domain_id", "")) for component in product_gate_components
    }
    required_owners = {
        str(component.get("owner_component_id", "")) for component in product_gate_components
    }
    if product_gate_paths and len(product_gate_components) != len(product_gate_paths):
        failures.append("PRODUCT_DELTA_COMPONENT_CLASSIFICATION_INCOMPLETE")
    for path in gate_component_candidate_paths:
        component = by_path.get(_component_binding_path(path))
        if not isinstance(component, dict):
            continue
        component_id = str(component.get("component_id", ""))
        component_domain = by_domain.get(str(component.get("domain_id", "")))
        permitted_deactivation = bool(
            _component_deactivation_is_superseded(
                component_id,
                by_component,
                [
                    row
                    for row in supersession.get("entries", [])
                    if isinstance(row, dict)
                ],
            )
            or (
                isinstance(component_domain, dict)
                and component_domain.get("lifecycle") == "RETIRED_DOMAIN"
                and _domain_retirement_evidence_complete(component_domain)
                and component.get("production_reachable") is False
                and component.get("writes_authority") is False
            )
        )
        if (
            component.get("production_reachable") is False
            and component.get("component_role")
            not in {"DIAGNOSTIC_BENCH", "TEST_SUPPORT", "TOOLING"}
            and not permitted_deactivation
        ):
            failures.append(
                "NONPRODUCTION_COMPONENT_ROLE_INVALID:"
                f"{component.get('component_id', '')}"
            )
    for component in product_gate_components:
        if component.get("change_class") not in set(
            change_classes if isinstance(change_classes, list) else []
        ):
            failures.append(
                "PRODUCT_DELTA_COMPONENT_CHANGE_CLASS_NOT_DECLARED:"
                f"{component.get('component_id', '')}"
            )
    if product_gate_paths and not (
        isinstance(affected_domains, list)
        and required_domains.issubset(set(map(str, affected_domains)))
    ):
        failures.append("PRODUCT_DELTA_AFFECTED_DOMAINS_INCOMPLETE")
    if product_gate_paths and not (
        isinstance(affected_owners, list)
        and required_owners.issubset(set(map(str, affected_owners)))
    ):
        failures.append("PRODUCT_DELTA_AFFECTED_OWNERS_INCOMPLETE")
    required_component_tests = {
        test_id
        for component in product_gate_components
        for test_id in component.get("focused_test_ids", [])
        if isinstance(test_id, str)
    }
    if product_gate_paths and not (
        isinstance(focused, list)
        and required_component_tests.issubset(set(map(str, focused)))
    ):
        failures.append("PRODUCT_DELTA_FOCUSED_TESTS_INCOMPLETE")

    baseline_subject_sha = baseline_registry.get("candidate_head_sha")
    if evidence_subject_sha != baseline_subject_sha:
        baseline_status = baseline_inherited.get("canonical_pr_status", {})
        current_status = inherited.get("canonical_pr_status", {})
        if not data.evidence_subject_is_baseline_descendant:
            failures.append("EVIDENCE_SUBJECT_NOT_BASELINE_DESCENDANT")
        if not product_gate_paths:
            failures.append("EVIDENCE_SUBJECT_CHANGED_WITHOUT_PRODUCT_DELTA")
        if (
            not isinstance(baseline_status, dict)
            or not isinstance(current_status, dict)
            or current_status.get("latest_completed_stage")
            == baseline_status.get("latest_completed_stage")
        ):
            failures.append("EVIDENCE_SUBJECT_CHANGED_WITHOUT_NEW_COMPLETED_STAGE")
    rules_allowed = bool(
        set(change_classes if isinstance(change_classes, list) else [])
        & {"RULESET_CONSTITUTION", "RELEASE_CANDIDATE"}
    )
    if rule_paths and not rules_allowed:
        failures.extend(f"TOOLING_GATE_PRODUCT_RULE_CHANGE:{p}" for p in rule_paths)

    legacy_debt_paths = set(map(str, registry.get("legacy_debt_grandfather_paths", [])))
    touched_legacy = sorted(legacy_debt_paths.intersection(gate_delta_paths))
    unclassified_legacy = [p for p in touched_legacy if p not in by_path]
    metrics["TOUCHED_UNCLASSIFIED_LEGACY_COMPONENT_COUNT"] = len(unclassified_legacy)
    failures.extend(f"TOUCHED_UNCLASSIFIED_LEGACY_COMPONENT:{p}" for p in unclassified_legacy)

    status = inherited.get("canonical_pr_status", {})
    if isinstance(status, dict):
        required_status_fields = set(STATUS_KEYS) | {
            "schema_version",
            "pr_number",
            "latest_completed_stage_head_sha",
            "v075_pr90_dependency_boundary",
        }
        if not required_status_fields.issubset(status):
            failures.append("CANONICAL_STATUS_FIELDS_MISSING")
        if status.get("schema_version") != "space_syndicate.v076.canonical_pr_status.v1":
            failures.append("CANONICAL_STATUS_SCHEMA_INVALID")
        if status.get("pr_number") != 93:
            failures.append("CANONICAL_STATUS_PR_NUMBER_INVALID")
        for stage_number in (1, 2, 3):
            if status.get(f"stage_{stage_number}_status") not in STAGE_STATUS_VALUES:
                failures.append(f"CANONICAL_STAGE_STATUS_INVALID:{stage_number}")
        stage_by_id = _index(stage_rows, "stage_id")
        golden_by_id = _index(golden_rows, "step_id")
        for stage_number, stage_id in enumerate(CANONICAL_STAGE_IDS, start=1):
            expected_ledger_status = stage_by_id.get(stage_id, {}).get("ledger_status")
            if expected_ledger_status not in LEDGER_STATUS_VALUES:
                failures.append(f"CANONICAL_STAGE_LEDGER_SOURCE_MISSING:{stage_number}")
            elif status.get(f"stage_{stage_number}_ledger_status") != expected_ledger_status:
                failures.append(f"CANONICAL_STAGE_LEDGER_STATUS_MISMATCH:{stage_number}")
            stage_status = status.get(f"stage_{stage_number}_status")
            if stage_status in {"PRODUCTION_GREEN", "HUMAN_GREEN"}:
                stage_golden_ids = stage_by_id.get(stage_id, {}).get("golden_step_ids")
                required_golden_statuses = (
                    {"HUMAN_GREEN"}
                    if stage_status == "HUMAN_GREEN"
                    else {"PRODUCTION_GREEN", "HUMAN_GREEN"}
                )
                if not (
                    isinstance(stage_golden_ids, list)
                    and stage_golden_ids
                    and all(
                        isinstance(golden_id, str)
                        and golden_by_id.get(golden_id, {}).get("status")
                        in required_golden_statuses
                        for golden_id in stage_golden_ids
                    )
                ):
                    failures.append(
                        f"CANONICAL_STAGE_STATUS_WITHOUT_GOLDEN_EVIDENCE:{stage_number}"
                    )
        if status.get("historical_reuse_status") != "ACTIVE":
            failures.append("CANONICAL_HISTORICAL_REUSE_STATUS_INVALID")
        if status.get("point_inertia_status") != "ACTIVE":
            failures.append("CANONICAL_POINT_INERTIA_STATUS_INVALID")
        for key in (
            "golden_isolated_green_count",
            "golden_production_green_count",
            "golden_human_green_count",
        ):
            if not _is_int(status.get(key)) or status.get(key, -1) < 0:
                failures.append(f"CANONICAL_STATUS_COUNT_TYPE:{key}")
        if not _is_bool(status.get("production_cutover_status")):
            failures.append("CANONICAL_PRODUCTION_CUTOVER_TYPE")
        completed_stage_ids = [
            str(row.get("stage_id", ""))
            for row in stage_rows
            if isinstance(row, dict)
            and row.get("ledger_status")
            in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN", "REGRESSED_WITH_EVIDENCE"}
        ]
        if not completed_stage_ids or status.get("latest_completed_stage") != completed_stage_ids[-1]:
            failures.append("CANONICAL_LATEST_COMPLETED_STAGE_MISMATCH")
        if not _is_hex(status.get("latest_completed_stage_head_sha"), 40):
            failures.append("CANONICAL_LATEST_STAGE_HEAD_INVALID")
        if status.get("latest_completed_stage_head_sha") != evidence_subject_sha:
            failures.append("CANONICAL_LATEST_STAGE_HEAD_SUBJECT_MISMATCH")
        latest_stage = stage_by_id.get(str(status.get("latest_completed_stage", "")), {})
        latest_stage_head = latest_stage.get(
            "head_sha", latest_stage.get("current_direct_owner_head_sha")
        )
        if latest_stage_head != evidence_subject_sha:
            failures.append("LATEST_STAGE_LEDGER_SUBJECT_MISMATCH")
        if not _nonempty(status.get("next_stage")):
            failures.append("CANONICAL_NEXT_STAGE_MISSING")
        actual_golden_counts = {
            "golden_isolated_green_count": sum(
                1 for row in golden_rows
                if isinstance(row, dict) and row.get("status") == "ISOLATED_GREEN"
            ),
            "golden_production_green_count": sum(
                1 for row in golden_rows
                if isinstance(row, dict) and row.get("status") == "PRODUCTION_GREEN"
            ),
            "golden_human_green_count": sum(
                1 for row in golden_rows
                if isinstance(row, dict) and row.get("status") == "HUMAN_GREEN"
            ),
        }
        for key, expected in actual_golden_counts.items():
            if status.get(key) != expected:
                failures.append(f"CANONICAL_STATUS_GOLDEN_COUNT_MISMATCH:{key}")
        if status.get("production_cutover_status") != supersession.get("production_cutover"):
            failures.append("CANONICAL_STATUS_PRODUCTION_CUTOVER_MISMATCH")
    else:
        failures.append("CANONICAL_STATUS_MISSING")
    expected_block = render_status_block(status) if isinstance(status, dict) else ""
    actual_block = extract_status_block(data.pr_body)
    block_count = _status_block_count(data.pr_body)
    metrics["PR93_BODY_STATUS_BLOCK_PRESENT"] = block_count == 1
    metrics["PR93_BODY_STATUS_MATCH"] = block_count == 1 and actual_block == expected_block
    prose_without_block = re.sub(
        r"<!-- V076_STATUS_BEGIN -->.*?<!-- V076_STATUS_END -->",
        "",
        data.pr_body,
        flags=re.DOTALL,
    )
    stage3_patterns = {
        "ISOLATED_GREEN": r"Stage\s*3[^\n]*(?:isolated\s+(?:green|evidence\s+is\s+current)|CURRENT_DELTA_GREEN)",
        "PRODUCTION_GREEN": r"Stage\s*3[^\n]*production\s+green",
        "HUMAN_GREEN": r"Stage\s*3[^\n]*human\s+green",
        "REGRESSED_WITH_EVIDENCE": r"Stage\s*3[^\n]*regressed\s+with\s+evidence",
    }
    stage3_status = status.get("stage_3_status") if isinstance(status, dict) else None
    stage3_clause_match = re.search(
        r"Stage\s*3(?:(?!Stage\s*\d).)*",
        prose_without_block,
        flags=re.IGNORECASE,
    )
    stage3_clause = stage3_clause_match.group(0) if stage3_clause_match else ""
    stage3_positive = bool(
        stage3_status in stage3_patterns
        and re.search(
            stage3_patterns[str(stage3_status)],
            stage3_clause,
            flags=re.IGNORECASE,
        )
    )
    stage3_negative = bool(
        re.search(
            r"Stage\s*3[^\n]*(?:not\s+implemented|pending|unfinished|未实现|未完成)",
            stage3_clause,
            flags=re.IGNORECASE,
        )
    )
    metrics["PR93_DESCRIPTION_STAGE3_CURRENT"] = (
        isinstance(status, dict)
        and stage3_status in STAGE_STATUS_VALUES
        and stage3_positive
        and not stage3_negative
    )
    if not metrics["PR93_BODY_STATUS_BLOCK_PRESENT"]:
        failures.append("STALE_PR_STATUS_BLOCK:MISSING")
    elif not metrics["PR93_BODY_STATUS_MATCH"]:
        failures.append("STALE_PR_STATUS_BLOCK:MISMATCH")
    if block_count != 1:
        failures.append(f"STALE_PR_STATUS_BLOCK:COUNT:{block_count}")
    if not metrics["PR93_DESCRIPTION_STAGE3_CURRENT"]:
        metrics["PR93_BODY_STALE_STAGE_COUNT"] = 1
        failures.append("PR93_DESCRIPTION_STAGE3_STALE")
    false_green_patterns: list[tuple[str, str]] = []
    if isinstance(status, dict) and status.get("production_cutover_status") is False:
        false_green_patterns.append(
            (
                "production_cutover",
                r"(?:production\s+(?:main\.tscn\s+)?cutover|(?:生产|主场景)[^\n]{0,24}(?:切换|割接)[^\n]{0,12}(?:完成|通过))",
            )
        )
    if isinstance(status, dict) and status.get("golden_human_green_count") == 0:
        false_green_patterns.append(
            (
                "human_green",
                r"(?:golden\s+human(?:[- ]play(?:test)?)?\s+green|(?:golden\s*)?(?:真人|人工)[^\n]{0,12}(?:试玩|游玩)[^\n]{0,12}(?:绿|通过|成功))",
            )
        )
    if isinstance(status, dict) and status.get("golden_production_green_count") == 0:
        false_green_patterns.append(
            (
                "production_green",
                r"(?:golden\s+production\s+green|golden[^\n]{0,12}生产[^\n]{0,8}(?:绿|通过)|生产绿)",
            )
        )
    for claim_name, pattern in false_green_patterns:
        if _has_unqualified_positive_claim(prose_without_block, pattern):
            metrics["PR93_DESCRIPTION_FALSE_GREEN_COUNT"] += 1
            failures.append(f"PR93_DESCRIPTION_FALSE_GREEN:{claim_name}")

    production_cutover = supersession.get("production_cutover")
    if not _is_bool(production_cutover):
        failures.append("PRODUCTION_CUTOVER_TYPE_INVALID")
    elif production_cutover is True:
        cutover_evidence = supersession.get("production_cutover_evidence")
        cutover_scene_path = _normalize_evidence_path(
            cutover_evidence.get("production_scene_path")
            if isinstance(cutover_evidence, dict)
            else None
        )
        cutover_scene_binding = (
            _artifact_binding(
                data,
                cutover_evidence.get("production_scene_path"),
                cutover_evidence.get("production_scene_sha256"),
            )
            if isinstance(cutover_evidence, dict)
            else None
        )
        cutover_receipt_binding = (
            _artifact_binding(
                data,
                cutover_evidence.get("receipt_path"),
                cutover_evidence.get("receipt_sha256"),
            )
            if isinstance(cutover_evidence, dict)
            else None
        )
        cutover_receipt = (
            cutover_receipt_binding.get("json")
            if isinstance(cutover_receipt_binding, dict)
            else None
        )
        cutover_owners = (
            cutover_evidence.get("affected_owners", [])
            if isinstance(cutover_evidence, dict)
            else []
        )
        cutover_green = bool(
            isinstance(change_classes, list)
            and set(change_classes).intersection({"PRODUCTION_COMPOSITION", "RELEASE_CANDIDATE"})
            and isinstance(cutover_evidence, dict)
            and cutover_evidence.get("atomic_cutover") is True
            and cutover_evidence.get("candidate_head_sha") == evidence_subject_sha
            and _is_hex(cutover_evidence.get("receipt_sha256"), 64)
            and cutover_scene_path == "scenes/main.tscn"
            and cutover_scene_binding is not None
            and cutover_receipt_binding is not None
            and isinstance(cutover_owners, list)
            and cutover_owners
            and _unique(cutover_owners)
            and all(owner in by_component for owner in cutover_owners)
            and isinstance(cutover_receipt, dict)
            and cutover_receipt.get("schema_version")
            == "space_syndicate.v076.production_cutover_receipt.v1"
            and cutover_receipt.get("status") == "PASS"
            and cutover_receipt.get("candidate_head_sha") == evidence_subject_sha
            and cutover_receipt.get("atomic_cutover") is True
            and _normalize_evidence_path(cutover_receipt.get("production_scene_path"))
            == "scenes/main.tscn"
        )
        if not cutover_green:
            metrics["PR93_DESCRIPTION_FALSE_GREEN_COUNT"] += 1
            failures.append("PRODUCTION_CUTOVER_EVIDENCE_MISSING")
    if isinstance(status, dict) and status.get("production_cutover_status") is True and production_cutover is not True:
        metrics["PR93_DESCRIPTION_FALSE_GREEN_COUNT"] += 1
        failures.append("PR93_DESCRIPTION_PRODUCTION_CUTOVER_FALSE_GREEN")

    if not data.stage_parent_is_descendant:
        failures.append("STAGE_PARENT_NOT_PREVIOUS_STAGE_DESCENDANT")

    metrics["AGENT_MERGE_REQUIRES_REUSE_GATE"] = bool(
        inherited.get("agent_merge_requires_reuse_gate") is True
        and inherited.get("required_check_name") == CHECK_NAME
    )
    if not metrics["AGENT_MERGE_REQUIRES_REUSE_GATE"]:
        failures.append("AGENT_MERGE_RATCHET_MISSING")

    if baseline_supersession.get("production_cutover") is True and production_cutover is not True:
        failures.append("PRODUCTION_CUTOVER_SILENT_REGRESSION")

    # Stable report aliases used by the V076 task contract.  They deliberately
    # mirror the canonical counters above rather than introduce a second
    # validation path.
    metrics.update(
        {
            "OWNER_MAP_IMPLEMENTATION_COUNT": len(
                data.implementation_paths.get("owner_map", [])
            ),
            "SUPERSESSION_MAP_IMPLEMENTATION_COUNT": len(
                data.implementation_paths.get("supersession", [])
            ),
            "CARD_CERTIFICATION_MATRIX_IMPLEMENTATION_COUNT": len(
                data.implementation_paths.get("card_matrix", [])
            ),
            "NEW_COMPONENT_REGISTRY_COVERAGE": metrics.get(
                "NEW_OR_CHANGED_COMPONENT_GATE_COVERAGE", "0_PERCENT"
            ),
            "TOUCHED_UNCLASSIFIED_COMPONENT_COUNT": metrics.get(
                "TOUCHED_UNCLASSIFIED_LEGACY_COMPONENT_COUNT", 0
            ),
            "NEW_UNCLASSIFIED_COMPONENT_COUNT": metrics.get(
                "UNCLASSIFIED_NEW_COMPONENT_COUNT", 0
            ),
            "GOLDEN_PASS_SILENT_REGRESSION_COUNT": sum(
                str(value).startswith("GOLDEN_SCENARIO_REGRESSION_EVIDENCE_MISSING")
                for value in failures
            ),
            "CARD_ID_SILENT_REPLACEMENT_COUNT": sum(
                str(value).startswith("CARD_CERTIFICATION_CATEGORY_DELETE")
                for value in failures
            ),
            "PER_CARD_FALSE_GREEN_COUNT": sum(
                str(value).startswith("CARD_CERTIFICATION_PREREQUISITE_MISSING")
                for value in failures
            ),
            "STAGE_BRANCH_RESTART_COUNT": 0 if data.stage_parent_is_descendant else 1,
            "READY_WITHOUT_REUSE_GATE_COUNT": metrics.get(
                "READY_TRANSITION_WITHOUT_GATE_COUNT", 0
            ),
            "TAG_WITHOUT_REUSE_GATE_COUNT": 0,
            "PRODUCTION_COMPOSITION_CHANGE_COUNT": sum(
                _is_product_composition_path(str(row.get("path", "")))
                for row in data.gate_changed_paths
            ),
        }
    )

    return {
        "status": "PASS" if not failures else "FAIL",
        "check_name": CHECK_NAME,
        "failures": sorted(set(failures)),
        "metrics": metrics,
    }


def _parse_name_status_z(payload: bytes) -> list[dict[str, str]]:
    """Parse ``git diff --name-status -z`` without quoted-path ambiguity."""
    rows: list[dict[str, str]] = []
    fields = [field for field in payload.split(b"\0") if field]
    cursor = 0
    while cursor < len(fields):
        status_token = fields[cursor].decode("ascii", errors="strict")
        cursor += 1
        status = status_token[:1]
        path_count = 2 if status in {"R", "C"} else 1
        if cursor + path_count > len(fields):
            raise ValueError("malformed NUL-delimited Git name-status payload")
        paths = [_decode_git_path(value) for value in fields[cursor : cursor + path_count]]
        cursor += path_count
        if status == "R":
            rows.append({"status": "D", "path": paths[0]})
            rows.append({"status": "A", "path": paths[1]})
        elif status == "C":
            rows.append({"status": "A", "path": paths[1]})
        else:
            rows.append({"status": status, "path": paths[0]})
    return rows


def _git_name_status(root: Path, *args: str) -> list[dict[str, str]]:
    return _parse_name_status_z(
        _git_bytes(root, "diff", "--name-status", "-z", "--find-renames", *args)
    )


def changed_paths(root: Path, base_ref: str, head_ref: str, include_worktree: bool) -> list[dict[str, str]]:
    merge_base = _git(root, "merge-base", base_ref, head_ref)
    rows = _git_name_status(root, f"{merge_base}..{head_ref}")
    if include_worktree:
        worktree_rows = _git_name_status(root, "HEAD")
        untracked = _git_path_list(root, "ls-files", "--others", "--exclude-standard")
        worktree_rows.extend(
            {"status": "A", "path": path} for path in untracked
        )
        by_path = {row["path"]: row for row in rows}
        by_path.update({row["path"]: row for row in worktree_rows})
        rows = sorted(by_path.values(), key=lambda row: row["path"])
    return rows


def snapshot_changed_paths(
    root: Path, older_ref: str, newer_ref: str, include_worktree: bool
) -> list[dict[str, str]]:
    """Compare two exact snapshots; unlike PR deltas, never substitute a merge base."""
    rows = _git_name_status(root, f"{older_ref}..{newer_ref}")
    if include_worktree:
        worktree_rows = _git_name_status(root, "HEAD")
        untracked = _git_path_list(root, "ls-files", "--others", "--exclude-standard")
        worktree_rows.extend(
            {"status": "A", "path": path} for path in untracked
        )
        by_path = {row["path"]: row for row in rows}
        by_path.update({row["path"]: row for row in worktree_rows})
        rows = sorted(by_path.values(), key=lambda row: row["path"])
    return rows


REFERENCE_TEXT_SUFFIXES = {
    ".gd",
    ".tscn",
    ".scn",
    ".tres",
    ".res",
    ".godot",
    ".cfg",
    ".json",
    ".md",
    ".txt",
    ".csv",
    ".po",
    ".gdextension",
    ".gdshader",
    ".shader",
}


def _snapshot_paths(root: Path, ref: str, include_worktree: bool) -> set[str]:
    if include_worktree:
        return {
            path
            for path in _git_path_list(
                root, "ls-files", "-c", "-o", "--exclude-standard"
            )
            if (root / path).is_file()
        }
    return set(_git_path_list(root, "ls-tree", "-r", "--name-only", ref))


def _snapshot_text(
    root: Path, ref: str, path: str, include_worktree: bool
) -> str | None:
    normalized = path.replace("\\", "/")
    if include_worktree:
        candidate = (root / normalized).resolve()
        try:
            candidate.relative_to(root.resolve())
        except ValueError:
            return None
        if not candidate.is_file():
            return None
        try:
            return candidate.read_text(encoding="utf-8-sig", errors="replace")
        except OSError:
            return None
    if not _git_path_exists_at(root, ref, normalized):
        return None
    return _git(root, "show", f"{ref}:{normalized}", check=False)


def _rule_authority_paths_at(
    root: Path, ref: str, include_worktree: bool
) -> set[str]:
    """Read rule authorities from the one canonical mechanic registry.

    The retired-mechanic scanner is executed and reported separately. Its
    ``FORMAL_RULE_FILES`` collection is deliberately broader than rule
    authority: it includes governance documents such as AGENTS.md so retired
    identifiers can be found there. Promoting that scan inventory wholesale
    would misclassify a merge-ratchet edit as a gameplay rule change. The
    registry's typed ``authoritative_sources`` rows are the reusable authority
    source for additional documents.
    """
    result = {value.replace("\\", "/") for value in RULE_AUTHORITY_PATHS}
    registry_text = _snapshot_text(
        root,
        ref,
        "docs/rules/v06_mechanic_status_registry.json",
        include_worktree,
    )
    if registry_text:
        try:
            registry = json.loads(registry_text)
            for mechanic in registry.get("mechanics", []):
                if not isinstance(mechanic, dict):
                    continue
                for source in mechanic.get("authoritative_sources", []):
                    if isinstance(source, dict) and isinstance(source.get("path"), str):
                        result.add(source["path"].replace("\\", "/"))
        except (json.JSONDecodeError, AttributeError):
            pass
    return result


def augment_changed_paths_with_rule_authorities(
    root: Path,
    older_ref: str,
    newer_ref: str,
    include_worktree: bool,
    changed_rows: Iterable[dict[str, str]],
) -> list[dict[str, Any]]:
    old_authorities = _rule_authority_paths_at(root, older_ref, False)
    new_authorities = _rule_authority_paths_at(root, newer_ref, include_worktree)
    old_authorities.update(
        path
        for path in _snapshot_paths(root, older_ref, False)
        if _is_rule_authority_path(path)
    )
    new_authorities.update(
        path
        for path in _snapshot_paths(root, newer_ref, include_worktree)
        if _is_rule_authority_path(path)
    )
    authority_paths = old_authorities | new_authorities
    rows = [dict(row) for row in changed_rows]
    should_resolve_dependencies = any(
        _component_binding_path(str(row.get("path", ""))).casefold()
        in {path.casefold() for path in authority_paths}
        or (
            PurePosixPath(
                _component_binding_path(str(row.get("path", "")))
            ).suffix.casefold()
            in RUNTIME_LOADABLE_SUFFIXES
            and not str(row.get("path", "")).replace("\\", "/").casefold().startswith(
                (".github/", "docs/", "reports/", "art_sources/", "tools/")
            )
        )
        for row in rows
    )
    rule_dependency_paths: set[str] = set()
    if should_resolve_dependencies:
        old_result = _snapshot_reference_closure(
            root, older_ref, old_authorities, False
        )
        new_result = _snapshot_reference_closure(
            root, newer_ref, new_authorities, include_worktree
        )
        rule_dependency_paths.update(old_result["reachable"])
        rule_dependency_paths.update(new_result["reachable"])
    authority_folded = {
        path.casefold() for path in authority_paths | rule_dependency_paths
    }
    for row in rows:
        if (
            _component_binding_path(str(row.get("path", ""))).casefold()
            in authority_folded
        ):
            row["rule_authority"] = True
    return rows


def _normalize_res_reference(value: str) -> str | None:
    raw = value.strip().lstrip("*").replace("\\", "/")
    if not raw.startswith("res://"):
        return None
    raw = raw[6:].split("?", 1)[0].split("#", 1)[0].lstrip("/")
    parts = PurePosixPath(raw).parts
    if not raw or any(part in {"", ".", ".."} for part in parts):
        return None
    return "/".join(parts)


def _snapshot_blob_index(root: Path, ref: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for record in _git_bytes(root, "ls-tree", "-r", "-z", ref).split(b"\0"):
        if not record or b"\t" not in record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        fields = metadata.split()
        if len(fields) >= 3 and fields[1] == b"blob":
            result[_decode_git_path(raw_path)] = fields[2].decode("ascii")
    return result


def _batch_git_blobs(root: Path, object_ids: Iterable[str]) -> dict[str, bytes]:
    ordered = list(dict.fromkeys(object_ids))
    if not ordered:
        return {}
    completed = subprocess.run(
        ["git", "-C", str(root), "cat-file", "--batch"],
        input=("\n".join(ordered) + "\n").encode("ascii"),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        error = completed.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(f"git cat-file --batch failed: {error}")
    stream = io.BytesIO(completed.stdout)
    result: dict[str, bytes] = {}
    for expected in ordered:
        header = stream.readline().rstrip(b"\n")
        fields = header.split()
        if len(fields) != 3 or fields[0].decode("ascii") != expected:
            raise RuntimeError("malformed git cat-file --batch response")
        size = int(fields[2])
        result[expected] = stream.read(size)
        if stream.read(1) != b"\n":
            raise RuntimeError("malformed git cat-file payload terminator")
    return result


def _snapshot_text_inventory(
    root: Path, ref: str, include_worktree: bool
) -> tuple[set[str], dict[str, str]]:
    """Load all potentially textual graph nodes with O(1) Git subprocesses."""
    paths = _snapshot_paths(root, ref, include_worktree)
    text_paths = {
        path
        for path in paths
        if path == "project.godot"
        or PurePosixPath(path).suffix.casefold() in REFERENCE_TEXT_SUFFIXES
    }
    texts: dict[str, str] = {}
    if include_worktree:
        resolved_root = root.resolve()
        for path in sorted(text_paths):
            candidate = (root / path).resolve()
            try:
                candidate.relative_to(resolved_root)
            except ValueError:
                continue
            try:
                texts[path] = candidate.read_text(
                    encoding="utf-8-sig", errors="replace"
                )
            except OSError:
                continue
        return paths, texts
    blob_index = _snapshot_blob_index(root, ref)
    wanted = {path: blob_index[path] for path in text_paths if path in blob_index}
    payloads = _batch_git_blobs(root, wanted.values())
    for path, object_id in wanted.items():
        texts[path] = payloads[object_id].decode("utf-8-sig", errors="replace")
    return paths, texts


def _decode_string_body(body: str) -> str:
    result: list[str] = []
    cursor = 0
    escapes = {"n": "\n", "r": "\r", "t": "\t"}
    while cursor < len(body):
        if body[cursor] == "\\" and cursor + 1 < len(body):
            cursor += 1
            result.append(escapes.get(body[cursor], body[cursor]))
        else:
            result.append(body[cursor])
        cursor += 1
    return "".join(result)


def _lex_strings_and_code(
    text: str, *, hash_comments: bool, semicolon_comments: bool = False
) -> tuple[list[tuple[int, int, str]], str]:
    """Return decoded string spans and code with strings/comments masked."""
    spans: list[tuple[int, int, str]] = []
    masked = list(text)
    cursor = 0
    while cursor < len(text):
        char = text[cursor]
        if (hash_comments and char == "#") or (semicolon_comments and char == ";"):
            end = text.find("\n", cursor)
            end = len(text) if end < 0 else end
            masked[cursor:end] = " " * (end - cursor)
            cursor = end
            continue
        if char not in {"\"", "'"}:
            cursor += 1
            continue
        start = cursor - 1 if cursor > 0 and text[cursor - 1] == "&" else cursor
        delimiter = char * (3 if text.startswith(char * 3, cursor) else 1)
        body_start = cursor + len(delimiter)
        scan = body_start
        while scan < len(text):
            if text.startswith(delimiter, scan):
                break
            if text[scan] == "\\" and scan + 1 < len(text):
                scan += 2
            else:
                scan += 1
        end = min(len(text), scan + len(delimiter))
        spans.append((start, end, _decode_string_body(text[body_start:scan])))
        masked[start:end] = " " * (end - start)
        cursor = end
    return spans, "".join(masked)


def _literal_concat_value(expression: str) -> str | None:
    spans, masked = _lex_strings_and_code(
        expression, hash_comments=True, semicolon_comments=False
    )
    if not spans:
        return None
    cursor = 0
    fragments: list[str] = []
    for index, (start, end, value) in enumerate(spans):
        separator = masked[cursor:start].strip()
        if separator != ("" if index == 0 else "+"):
            return None
        fragments.append(value)
        cursor = end
    return "".join(fragments) if not masked[cursor:].strip() else None


def _first_call_argument(text: str, open_paren: int) -> tuple[str, int] | None:
    cursor = open_paren + 1
    start = cursor
    depth = 1
    quote = ""
    while cursor < len(text):
        char = text[cursor]
        if quote:
            if char == "\\":
                cursor += 2
                continue
            if char == quote:
                quote = ""
            cursor += 1
            continue
        if char in {"\"", "'"}:
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return text[start:cursor], cursor
        elif char == "," and depth == 1:
            return text[start:cursor], cursor
        cursor += 1
    return None


def _project_runtime_text(text: str) -> str:
    section = ""
    retained: list[str] = []
    for line in text.splitlines(keepends=True):
        match = re.match(r"^\s*\[([^]]+)\]\s*$", line.strip())
        if match:
            section = match.group(1).strip().casefold()
        retained.append("\n" if section == "editor_plugins" else line)
    return "".join(retained)


def _snapshot_reference_closure(
    root: Path,
    ref: str,
    seeds: Iterable[str],
    include_worktree: bool,
) -> dict[str, Any]:
    """Resolve actual resource-load and typed GDScript edges for one snapshot."""
    paths, texts = _snapshot_text_inventory(root, ref, include_worktree)
    normalized_seeds = {
        _component_binding_path(str(seed).replace("\\", "/")) for seed in seeds
    }

    class_candidates: dict[str, set[str]] = {}
    for path, text in texts.items():
        if not path.casefold().endswith(".gd"):
            continue
        match = re.search(
            r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)\b",
            text,
            flags=re.MULTILINE,
        )
        if match:
            class_candidates.setdefault(match.group(1), set()).add(path)
    duplicate_classes = {
        (name, tuple(sorted(class_paths)))
        for name, class_paths in class_candidates.items()
        if len(class_paths) > 1
    }
    class_paths = {
        name: next(iter(class_set))
        for name, class_set in class_candidates.items()
        if len(class_set) == 1
    }

    closure: set[str] = set()
    dynamic_sites: set[tuple[str, str, str]] = set()
    missing_refs: set[tuple[str, str]] = set()
    queue = list(sorted(normalized_seeds))
    loader_pattern = re.compile(
        r"(?<![.A-Za-z0-9_])(?P<name>load|preload)\s*\(|"
        r"(?P<qualified>ResourceLoader\s*\.\s*(?:load|exists)|"
        r"FileAccess\s*\.\s*(?:open|get_file_as_string|file_exists)|"
        r"DirAccess\s*\.\s*(?:open|dir_exists|file_exists)|"
        r"Image\s*\.\s*load)\s*\("
    )
    resource_suffixes = {".tscn", ".scn", ".tres", ".res"}
    while queue:
        path = queue.pop(0)
        if path in closure:
            continue
        closure.add(path)
        text = texts.get(path)
        if text is None:
            continue
        suffix = PurePosixPath(path).suffix.casefold()
        dependencies: set[str] = set()

        if path == "project.godot":
            edge_text = _project_runtime_text(text)
            spans, _ = _lex_strings_and_code(
                edge_text, hash_comments=True, semicolon_comments=True
            )
            literal_values = [value for _, _, value in spans]
        elif suffix in resource_suffixes:
            spans, _ = _lex_strings_and_code(
                text, hash_comments=True, semicolon_comments=True
            )
            literal_values = [value for _, _, value in spans]
        elif suffix in {".gdshader", ".shader"}:
            spans, _ = _lex_strings_and_code(
                text, hash_comments=False, semicolon_comments=False
            )
            literal_values = [value for _, _, value in spans]
        else:
            literal_values = []

        for value in literal_values:
            referenced = _normalize_res_reference(value)
            if referenced is None:
                continue
            if referenced in paths:
                dependencies.add(referenced)
                continue
            prefix = referenced.rstrip("/") + "/"
            descendants = {candidate for candidate in paths if candidate.startswith(prefix)}
            if descendants:
                dependencies.update(descendants)
            else:
                missing_refs.add((path, referenced))

        if suffix == ".gd":
            string_spans, code = _lex_strings_and_code(
                text, hash_comments=True, semicolon_comments=False
            )
            del string_spans
            comment_clean = text
            # Mask comments without masking literals so call arguments stay readable.
            comment_chars = list(comment_clean)
            in_quote = ""
            cursor = 0
            while cursor < len(comment_clean):
                char = comment_clean[cursor]
                if in_quote:
                    if char == "\\":
                        cursor += 2
                        continue
                    if char == in_quote:
                        in_quote = ""
                elif char in {"\"", "'"}:
                    in_quote = char
                elif char == "#":
                    end = comment_clean.find("\n", cursor)
                    end = len(comment_clean) if end < 0 else end
                    comment_chars[cursor:end] = " " * (end - cursor)
                    cursor = end
                    continue
                cursor += 1
            comment_clean = "".join(comment_chars)
            local_constants: dict[str, str] = {}
            for constant_match in re.finditer(
                r"(?m)^\s*const\s+([A-Za-z_][A-Za-z0-9_]*)"
                r"(?:\s*:\s*[^:=\r\n]+)?\s*(?::=|=)\s*([^\r\n]+)$",
                comment_clean,
            ):
                constant_value = _literal_concat_value(constant_match.group(2))
                if constant_value is not None:
                    local_constants[constant_match.group(1)] = constant_value
            # A scalar res:// constant in reachable production code is an
            # explicit dependency even when it is passed through a narrow
            # local loader wrapper before reaching FileAccess/ResourceLoader.
            for constant_value in local_constants.values():
                referenced = _normalize_res_reference(constant_value)
                if referenced is None:
                    continue
                if referenced in paths:
                    dependencies.add(referenced)
                else:
                    prefix = referenced.rstrip("/") + "/"
                    descendants = {
                        candidate for candidate in paths if candidate.startswith(prefix)
                    }
                    if descendants:
                        dependencies.update(descendants)
                    else:
                        missing_refs.add((path, referenced))
            for match in loader_pattern.finditer(comment_clean):
                argument = _first_call_argument(comment_clean, match.end() - 1)
                if argument is None:
                    dynamic_sites.add((path, match.group(0).split("(", 1)[0].strip(), "MALFORMED"))
                    continue
                expression, _ = argument
                literal = _literal_concat_value(expression)
                if literal is None and re.fullmatch(
                    r"[A-Za-z_][A-Za-z0-9_]*", expression.strip()
                ):
                    literal = local_constants.get(expression.strip())
                loader_name = (match.group("name") or match.group("qualified") or "load").replace(" ", "")
                if literal is None:
                    compact = re.sub(r"\s+", " ", expression.strip())[:160]
                    dynamic_sites.add((path, loader_name, compact or "EMPTY"))
                    continue
                referenced = _normalize_res_reference(literal)
                if referenced is None:
                    continue
                if referenced in paths:
                    dependencies.add(referenced)
                else:
                    prefix = referenced.rstrip("/") + "/"
                    descendants = {candidate for candidate in paths if candidate.startswith(prefix)}
                    if descendants:
                        dependencies.update(descendants)
                    else:
                        missing_refs.add((path, referenced))
            class_references: set[str] = set()
            for pattern in (
                r"\b(?:extends|as|is)\s+([A-Za-z_][A-Za-z0-9_]*)\b",
                r"(?::|->)\s*([A-Za-z_][A-Za-z0-9_]*)\b",
                r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\.(?:new|[A-Z_][A-Za-z0-9_]*)\b",
            ):
                class_references.update(re.findall(pattern, code))
            dependencies.update(
                class_paths[name] for name in class_references if name in class_paths
            )
        queue.extend(sorted(dependencies - closure))
    return {
        "reachable": closure,
        "dynamic_sites": dynamic_sites,
        "missing_refs": missing_refs,
        "duplicate_classes": duplicate_classes,
    }


def augment_changed_paths_with_production_references(
    root: Path,
    older_ref: str,
    newer_ref: str,
    include_worktree: bool,
    changed_rows: Iterable[dict[str, str]],
    registered_production_paths: Iterable[str] = (),
) -> list[dict[str, Any]]:
    """Promote exact reachability additions/removals and reference failures."""
    rows = [dict(row) for row in changed_rows]
    registered = {
        str(path).replace("\\", "/") for path in registered_production_paths
    }
    seeds = {
        _component_binding_path(str(row.get("path", "")))
        for row in rows
        if (
            _is_forced_production_path(str(row.get("path", "")))
            or _is_product_component_path(str(row.get("path", "")))
            or _component_binding_path(str(row.get("path", ""))) in registered
        )
    }
    # Every nonempty transition is compared against the actual project graph.
    # The batched snapshot reader keeps this bounded, while avoiding suffix- or
    # directory-based blind spots for extensionless/native/runtime payloads.
    if rows:
        seeds.add("project.godot")
    if not seeds:
        return rows
    old_result = _snapshot_reference_closure(root, older_ref, seeds, False)
    new_result = _snapshot_reference_closure(
        root, newer_ref, seeds, include_worktree
    )
    old_closure = set(old_result["reachable"])
    new_closure = set(new_result["reachable"])
    newly_reachable = new_closure - old_closure
    newly_unreachable = old_closure - new_closure
    row_by_binding = {
        _component_binding_path(str(row.get("path", ""))): row for row in rows
    }
    for path in sorted(newly_reachable):
        row = row_by_binding.get(path)
        if row is None:
            row = {
                "status": "A",
                "path": path,
                "production_reachable": True,
            }
            rows.append(row)
            row_by_binding[path] = row
        else:
            row["production_reachable"] = True
    for path in sorted(newly_unreachable):
        row = row_by_binding.get(path)
        if row is None:
            row = {
                "status": "D",
                "path": path,
                "production_reachable_before": True,
            }
            rows.append(row)
            row_by_binding[path] = row
        else:
            row["production_reachable_before"] = True
    for path, row in row_by_binding.items():
        if path in new_closure:
            row["production_reachable"] = True
        if path in old_closure:
            row["production_reachable_before"] = True

    reference_failures: list[tuple[str, str]] = []
    for source, loader, expression in sorted(
        set(new_result["dynamic_sites"]) - set(old_result["dynamic_sites"])
    ):
        reference_failures.append(
            (source, f"DYNAMIC_REFERENCE_UNRESOLVED:{loader}:{expression}")
        )
    for source, missing in sorted(
        set(new_result["missing_refs"]) - set(old_result["missing_refs"])
    ):
        reference_failures.append((source, f"PRODUCTION_REFERENCE_MISSING:{missing}"))
    for class_name, class_paths in sorted(
        set(new_result["duplicate_classes"]) - set(old_result["duplicate_classes"])
    ):
        reference_failures.append(
            (class_paths[-1], f"PRODUCTION_CLASS_NAME_AMBIGUOUS:{class_name}")
        )
    for source, failure in reference_failures:
        row = row_by_binding.get(source)
        if row is None:
            row = {"status": "M", "path": source, "production_reachable": True}
            rows.append(row)
            row_by_binding[source] = row
        failures = row.setdefault("production_reference_failures", [])
        if failure not in failures:
            failures.append(failure)
    return sorted(rows, key=lambda row: (str(row.get("path", "")), str(row.get("status", ""))))


def load_baseline_authorities(root: Path, ref: str, current_paths: dict[str, list[str]]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for key in SCHEMA_PREFIXES:
        paths = current_paths.get(key, [])
        if len(paths) != 1:
            continue
        value = _git_json_at(root, ref, paths[0])
        if value is not None:
            result[key] = value
    return result


def committed_history_failures(
    root: Path,
    activation_ref: str,
    head_ref: str,
    implementation_paths: dict[str, list[str]],
) -> tuple[list[str], int]:
    """Validate every adjacent committed transition from activation through Head."""
    failures: list[str] = []
    commits = _git(
        root,
        "rev-list",
        "--reverse",
        "--topo-order",
        "--ancestry-path",
        f"{activation_ref}..{head_ref}",
    ).splitlines()
    transition_count = 0
    for commit in commits:
        current_authorities = load_baseline_authorities(
            root, commit, implementation_paths
        )
        current_components = current_authorities.get("historical_reuse", {}).get(
            "component_inventory", []
        )
        for component in current_components:
            if not (
                isinstance(component, dict)
                and component.get("production_reachable") is True
            ):
                continue
            component_id = str(component.get("component_id", ""))
            component_path = str(component.get("path", ""))
            if not _git_path_exists_at(root, commit, component_path):
                failures.append(
                    "HISTORY_REGISTERED_COMPONENT_PATH_MISSING:"
                    f"{commit[:12]}:{component_id}:{component_path}"
                )
                continue
            if component_path.casefold().endswith(".gd"):
                source = _git(
                    root, "show", f"{commit}:{component_path}", check=False
                )
                class_match = re.search(
                    r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$",
                    source,
                    flags=re.MULTILINE,
                )
                if not class_match or class_match.group(1) != component.get(
                    "class_name"
                ):
                    failures.append(
                        "HISTORY_COMPONENT_CLASS_DECLARATION_MISMATCH:"
                        f"{commit[:12]}:{component_id}:{component_path}"
                    )
        current_regression_commits: set[str] = set()
        current_regressions: list[Any] = []
        current_regressions.extend(
            row.get("regression")
            for row in current_authorities.get("inherited_green", {}).get("stages", [])
            if isinstance(row, dict)
        )
        current_regressions.extend(
            row.get("regression")
            for row in current_authorities.get("golden", {}).get("steps", [])
            if isinstance(row, dict)
        )
        current_regressions.extend(
            row.get("regression")
            for row in current_authorities.get("card_matrix", {}).get("category_matrix", [])
            if isinstance(row, dict)
        )
        for regression in current_regressions:
            affected_commit = (
                regression.get("affected_commit") if isinstance(regression, dict) else None
            )
            if _is_hex(affected_commit, 40) and _is_hex(
                _git(root, "show", "-s", "--format=%T", affected_commit, check=False), 40
            ):
                current_regression_commits.add(str(affected_commit))
        failures.extend(
            _regression_binding_failures(
                current_authorities,
                commit[:12],
                "HISTORY",
                current_regression_commits,
            )
        )
        commit_and_parents = _git(
            root, "rev-list", "--parents", "-n", "1", commit
        ).split()
        for parent_ref in commit_and_parents[1:]:
            parent_is_in_scope = parent_ref == activation_ref or subprocess.run(
                [
                    "git",
                    "-C",
                    str(root),
                    "merge-base",
                    "--is-ancestor",
                    activation_ref,
                    parent_ref,
                ],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode == 0
            if not parent_is_in_scope:
                continue
            parent_authorities = load_baseline_authorities(
                root, parent_ref, implementation_paths
            )
            transition_changed_paths = changed_paths(
                root, parent_ref, commit, False
            )
            transition_changed_paths = augment_changed_paths_with_production_references(
                root,
                parent_ref,
                commit,
                False,
                transition_changed_paths,
                (
                    str(component.get("path", ""))
                    for component in current_authorities.get(
                        "historical_reuse", {}
                    ).get("component_inventory", [])
                    if isinstance(component, dict)
                    and component.get("production_reachable") is True
                ),
            )
            transition_changed_paths = augment_changed_paths_with_rule_authorities(
                root,
                parent_ref,
                commit,
                False,
                transition_changed_paths,
            )
            previous_stage_rows = [
                row
                for row in parent_authorities.get("inherited_green", {}).get("stages", [])
                if isinstance(row, dict)
            ]
            current_stage_rows = [
                row
                for row in current_authorities.get("inherited_green", {}).get("stages", [])
                if isinstance(row, dict)
            ]
            if len(current_stage_rows) > len(previous_stage_rows) and previous_stage_rows:
                lineage_rows = [previous_stage_rows[-1], *current_stage_rows[len(previous_stage_rows) :]]
                for prior_stage, next_stage in zip(lineage_rows, lineage_rows[1:]):
                    prior_head = _stage_evidence_head(prior_stage)
                    next_head = _stage_evidence_head(next_stage)
                    if not (
                        prior_head
                        and next_head
                        and subprocess.run(
                            [
                                "git",
                                "-C",
                                str(root),
                                "merge-base",
                                "--is-ancestor",
                                prior_head,
                                next_head,
                            ],
                            check=False,
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        ).returncode
                        == 0
                    ):
                        failures.append(
                            "HISTORY_STAGE_PARENT_NOT_PREVIOUS_STAGE_DESCENDANT:"
                            f"{parent_ref[:12]}->{commit[:12]}:"
                            f"{prior_stage.get('stage_id', '')}->{next_stage.get('stage_id', '')}"
                        )
            failures.extend(
                _monotonic_transition_failures(
                    parent_authorities,
                    current_authorities,
                    f"{parent_ref[:12]}->{commit[:12]}",
                    transition_changed_paths,
                )
            )
            transition_count += 1
    return failures, transition_count


def _run_json_tool(command: list[str], root: Path) -> tuple[int, dict[str, Any]]:
    completed = subprocess.run(
        command,
        cwd=root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    try:
        report = json.loads(completed.stdout)
    except json.JSONDecodeError:
        report = {
            "status": "FAIL",
            "failures": ["tool_non_json"],
            "stderr": completed.stderr,
        }
    return completed.returncode, report


def run_retired_scanner(
    root: Path, gate_delta_paths: set[str]
) -> tuple[str, dict[str, Any]]:
    script = root / "tools/rules/check_v06_mechanic_authority.py"
    selftest_code, selftest = _run_json_tool(
        [sys.executable, str(script), "--self-test"], root
    )
    summary_code, report = _run_json_tool(
        [sys.executable, str(script), "--summary"], root
    )
    summary_shape_green = bool(
        summary_code in {0, 1}
        and report.get("status") in {"PASS", "FAIL"}
        and isinstance(report.get("production_hits"), list)
        and isinstance(report.get("source_splitting_hits"), list)
        and ((summary_code == 0) == (report.get("status") == "PASS"))
    )
    delta_production_hits = [
        hit for hit in report.get("production_hits", [])
        if isinstance(hit, dict) and hit.get("path") in gate_delta_paths
    ]
    delta_split_hits = [
        hit for hit in report.get("source_splitting_hits", [])
        if isinstance(hit, dict) and hit.get("path") in gate_delta_paths
    ]
    report["scanner_selftest"] = selftest
    report["scanner_selftest_exit_code"] = selftest_code
    report["summary_exit_code"] = summary_code
    report["inherited_summary_status"] = report.get("status", "FAIL")
    report["delta_production_hits"] = delta_production_hits
    report["delta_source_splitting_hits"] = delta_split_hits
    report["delta_status"] = (
        "PASS"
        if selftest_code == 0
        and selftest.get("status") == "PASS"
        and summary_shape_green
        and not delta_production_hits
        and not delta_split_hits
        else "FAIL"
    )
    report["summary_contract_valid"] = summary_shape_green
    status = str(report["delta_status"])
    return status, report


def run_gate_selftest(root: Path) -> tuple[str, dict[str, Any]]:
    script = root / "tools/v076/v076_reuse_point_inertia_gate_selftest.py"
    code, report = _run_json_tool([sys.executable, str(script)], root)
    status = str(report.get("REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS", "FAIL"))
    case_count = report.get("REUSE_POINT_INERTIA_GATE_SELFTEST_CASE_COUNT", 0)
    pass_count = report.get("REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT", 0)
    green = bool(
        code == 0
        and status == "PASS"
        and _is_int(case_count)
        and case_count >= 30
        and pass_count == case_count
        and report.get("FALSE_GREEN_COUNT") == 0
        and report.get("VALID_DELTA_FALSE_REJECT_COUNT") == 0
    )
    return ("PASS" if green else "FAIL"), report


def _markdown_report(report: dict[str, Any]) -> str:
    metrics = report.get("metrics", {})
    failures = report.get("failures", [])
    lines = [
        "# V0.7.6 Reuse and Point-Inertia Gate",
        "",
        f"- Status: `{report.get('status', 'FAIL')}`",
        f"- Check: `{CHECK_NAME}`",
        f"- Delta-only: `{str(metrics.get('DELTA_ONLY_GATE', False)).lower()}`",
        f"- Existing scanners: `{metrics.get('EXISTING_SCANNER_INVENTORY_COUNT', 0)}`",
        f"- Reused scanners: `{metrics.get('REUSED_SCANNER_COUNT', 0)}`",
        f"- New/changed component coverage: `{metrics.get('NEW_OR_CHANGED_COMPONENT_GATE_COVERAGE', '')}`",
        f"- Active-domain owner mismatches: `{metrics.get('ACTIVE_DOMAIN_OWNER_COUNT_MISMATCH', 0)}`",
        f"- Parallel production owners: `{metrics.get('PARALLEL_PRODUCTION_OWNER_COUNT', 0)}`",
        f"- Golden step deletions: `{metrics.get('GOLDEN_SCENARIO_STEP_DELETE_COUNT', 0)}`",
        f"- Card certification resets: `{metrics.get('CARD_CERTIFICATION_RESET_COUNT', 0)}`",
        f"- Gate self-test: `{report.get('REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS', 'FAIL')}` "
        f"({report.get('REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT', 0)}/"
        f"{report.get('REUSE_POINT_INERTIA_GATE_SELFTEST_CASE_COUNT', 0)})",
        f"- PR #93 status block match: `{str(metrics.get('PR93_BODY_STATUS_MATCH', False)).lower()}`",
        "",
        "## Failures",
        "",
    ]
    lines.extend(["None."] if not failures else [f"- `{failure}`" for failure in failures])
    lines.extend(
        [
            "",
            "## Scope",
            "",
            "This report is produced by a read-only Tooling/Docs gate. It starts no Godot process,",
            "executes no gameplay, and performs no full product reproof.",
            "",
        ]
    )
    return "\n".join(lines)


def validate_live(args: argparse.Namespace) -> dict[str, Any]:
    root = Path(args.project).resolve()
    authorities, implementation_paths = discover_authorities(root)
    evidence_artifact_bindings: dict[str, dict[str, Any]] = {}
    referenced_artifacts: set[str] = set()
    for step in authorities.get("golden", {}).get("steps", []):
        if not isinstance(step, dict):
            continue
        for evidence_key in ("production_evidence", "human_evidence"):
            evidence = step.get(evidence_key)
            if not isinstance(evidence, dict):
                continue
            for path_key in ("production_scene_path", "receipt_path"):
                relative = _normalize_evidence_path(evidence.get(path_key))
                if relative:
                    referenced_artifacts.add(relative)
    for relative in sorted(referenced_artifacts):
        artifact = (root / relative).resolve()
        try:
            artifact.relative_to(root)
        except ValueError:
            evidence_artifact_bindings[relative] = {"present": False}
            continue
        if not artifact.is_file():
            evidence_artifact_bindings[relative] = {"present": False}
            continue
        payload = artifact.read_bytes()
        parsed: dict[str, Any] | None = None
        try:
            candidate_json = json.loads(payload.decode("utf-8-sig"))
            if isinstance(candidate_json, dict):
                parsed = candidate_json
        except (UnicodeError, json.JSONDecodeError):
            parsed = None
        evidence_artifact_bindings[relative] = {
            "present": True,
            "sha256": hashlib.sha256(payload).hexdigest(),
            "json": parsed,
        }
    component_declared_classes: dict[str, str] = {}
    for row in authorities.get("historical_reuse", {}).get("component_inventory", []):
        if not isinstance(row, dict):
            continue
        component_path = str(row.get("path", ""))
        if not (
            row.get("production_reachable") is True
            and component_path.casefold().endswith(".gd")
        ):
            continue
        source_path = root / component_path
        declared = ""
        if source_path.is_file():
            match = re.search(
                r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$",
                source_path.read_text(encoding="utf-8-sig"),
                flags=re.MULTILINE,
            )
            if match:
                declared = match.group(1)
        component_declared_classes[component_path] = declared
    component_presence = {
        str(row.get("path", "")): (root / str(row.get("path", ""))).is_file()
        for row in authorities.get("historical_reuse", {}).get("component_inventory", [])
        if isinstance(row, dict) and isinstance(row.get("path"), str)
    }
    scanner_inventory = []
    scanner_presence: dict[str, bool] = {}
    for scanner in SCANNER_INVENTORY:
        row = dict(scanner)
        row["present"] = (root / row["path"]).is_file()
        scanner_presence[str(row["scanner_id"])] = bool(row["present"])
        scanner_inventory.append(row)
    baseline = load_baseline_authorities(root, args.inertia_base_ref, implementation_paths)
    evidence_subject_sha = str(
        authorities.get("historical_reuse", {}).get("candidate_head_sha", "")
    )
    git_commit_tree_bindings: dict[str, str] = {}
    if _is_hex(evidence_subject_sha, 40):
        subject_tree = _git(
            root, "show", "-s", "--format=%T", evidence_subject_sha, check=False
        )
        if _is_hex(subject_tree, 40):
            git_commit_tree_bindings[evidence_subject_sha] = subject_tree
    for entry in authorities.get("supersession", {}).get("entries", []):
        if not isinstance(entry, dict):
            continue
        cutover_commit = entry.get("cutover_commit")
        if not _is_hex(cutover_commit, 40):
            continue
        cutover_tree = _git(
            root, "show", "-s", "--format=%T", cutover_commit, check=False
        )
        if _is_hex(cutover_tree, 40):
            git_commit_tree_bindings[str(cutover_commit)] = cutover_tree
    regression_commit_bindings: set[str] = set()
    regression_candidates: list[Any] = []
    regression_candidates.extend(
        row.get("regression")
        for row in authorities.get("inherited_green", {}).get("stages", [])
        if isinstance(row, dict)
    )
    regression_candidates.extend(
        row.get("regression")
        for row in authorities.get("golden", {}).get("steps", [])
        if isinstance(row, dict)
    )
    regression_candidates.extend(
        row.get("regression")
        for row in authorities.get("card_matrix", {}).get("category_matrix", [])
        if isinstance(row, dict)
    )
    for regression in regression_candidates:
        if not isinstance(regression, dict):
            continue
        affected_commit = regression.get("affected_commit")
        if not _is_hex(affected_commit, 40):
            continue
        if _is_hex(
            _git(root, "show", "-s", "--format=%T", affected_commit, check=False), 40
        ):
            regression_commit_bindings.add(str(affected_commit))
    baseline_subject_sha = str(
        baseline.get("historical_reuse", {}).get("candidate_head_sha", "")
    )
    evidence_subject_is_baseline_descendant = bool(
        _is_hex(baseline_subject_sha, 40)
        and _is_hex(evidence_subject_sha, 40)
        and subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "merge-base",
                "--is-ancestor",
                baseline_subject_sha,
                evidence_subject_sha,
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )
    evidence_subject_is_head_ancestor = bool(
        _is_hex(evidence_subject_sha, 40)
        and subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "merge-base",
                "--is-ancestor",
                evidence_subject_sha,
                args.head_ref,
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )
    evidence_subject_product_tree_matches_head = False
    if _is_hex(evidence_subject_sha, 40) and evidence_subject_is_head_ancestor:
        try:
            production_component_paths = {
                str(row.get("path", ""))
                for row in authorities.get("historical_reuse", {}).get(
                    "component_inventory", []
                )
                if isinstance(row, dict)
                and row.get("production_reachable") is True
            }
            evidence_subject_delta = snapshot_changed_paths(
                root,
                evidence_subject_sha,
                args.head_ref,
                args.include_worktree,
            )
            evidence_subject_product_tree_matches_head = not any(
                _is_forced_production_path(row.get("path", ""))
                or _is_rule_authority_path(row.get("path", ""))
                or _component_binding_path(row.get("path", ""))
                in production_component_paths
                for row in evidence_subject_delta
            )
        except (subprocess.CalledProcessError, ValueError):
            evidence_subject_product_tree_matches_head = False
    pr_changed = changed_paths(root, args.pr_base_ref, args.head_ref, args.include_worktree)
    gate_changed = changed_paths(root, args.gate_base_ref, args.head_ref, args.include_worktree)
    registered_production_paths = {
        str(component.get("path", ""))
        for component in authorities.get("historical_reuse", {}).get(
            "component_inventory", []
        )
        if isinstance(component, dict)
        and component.get("production_reachable") is True
    }
    gate_changed = augment_changed_paths_with_production_references(
        root,
        args.gate_base_ref,
        args.head_ref,
        args.include_worktree,
        gate_changed,
        registered_production_paths,
    )
    gate_changed = augment_changed_paths_with_rule_authorities(
        root,
        args.gate_base_ref,
        args.head_ref,
        args.include_worktree,
        gate_changed,
    )
    gate_delta_set = {
        row.get("path", "") for row in gate_changed if row.get("status") != "D"
    }
    status, retired_report = run_retired_scanner(root, gate_delta_set)
    selftest_status, selftest_report = run_gate_selftest(root)
    pr_body = Path(args.pr_body_file).read_text(encoding="utf-8-sig")
    current_stage_rows = [
        row
        for row in authorities.get("inherited_green", {}).get("stages", [])
        if isinstance(row, dict)
    ]
    baseline_stage_rows = [
        row
        for row in baseline.get("inherited_green", {}).get("stages", [])
        if isinstance(row, dict)
    ]
    stage_head = _stage_evidence_head(current_stage_rows[-1]) if current_stage_rows else ""
    previous_stage_head = (
        _stage_evidence_head(baseline_stage_rows[-1]) if baseline_stage_rows else ""
    )
    stage_head_reaches_head = bool(stage_head) and subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", stage_head, args.head_ref],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0
    if len(current_stage_rows) > len(baseline_stage_rows):
        previous_reaches_current = bool(previous_stage_head and stage_head) and subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "merge-base",
                "--is-ancestor",
                previous_stage_head,
                stage_head,
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode == 0
    else:
        previous_reaches_current = True
    descendant = bool(stage_head_reaches_head and previous_reaches_current)
    report = validate_model(
        ValidationInput(
            authorities=authorities,
            implementation_paths=implementation_paths,
            baseline_authorities=baseline,
            changed_paths=pr_changed,
            gate_changed_paths=gate_changed,
            pr_body=pr_body,
            stage_parent_is_descendant=descendant,
            scanner_presence=scanner_presence,
            component_presence=component_presence,
            component_declared_classes=component_declared_classes,
            evidence_artifact_bindings=evidence_artifact_bindings,
            git_commit_tree_bindings=git_commit_tree_bindings,
            regression_commit_bindings=regression_commit_bindings,
            evidence_subject_is_baseline_descendant=evidence_subject_is_baseline_descendant,
            evidence_subject_is_head_ancestor=evidence_subject_is_head_ancestor,
            evidence_subject_product_tree_matches_head=(
                evidence_subject_product_tree_matches_head
            ),
            retired_scanner_status=status,
        )
    )
    history_failures: list[str] = []
    history_transition_count = 0
    if args.inertia_base_ref != V076_GATE_BASE_SHA or args.gate_base_ref != V076_GATE_BASE_SHA:
        history_failures.append("GATE_ACTIVATION_BASE_ARGUMENT_MISMATCH")
    else:
        history_failures, history_transition_count = committed_history_failures(
            root,
            V076_GATE_BASE_SHA,
            args.head_ref,
            implementation_paths,
        )
        if args.include_worktree:
            committed_head_authorities = load_baseline_authorities(
                root, args.head_ref, implementation_paths
            )
            worktree_changed_paths = changed_paths(
                root, args.head_ref, args.head_ref, True
            )
            worktree_changed_paths = augment_changed_paths_with_production_references(
                root,
                args.head_ref,
                args.head_ref,
                True,
                worktree_changed_paths,
                registered_production_paths,
            )
            worktree_changed_paths = augment_changed_paths_with_rule_authorities(
                root,
                args.head_ref,
                args.head_ref,
                True,
                worktree_changed_paths,
            )
            history_failures.extend(
                _monotonic_transition_failures(
                    committed_head_authorities,
                    authorities,
                    f"{_git(root, 'rev-parse', args.head_ref)[:12]}->WORKTREE",
                    worktree_changed_paths,
                )
            )
            history_transition_count += 1
    if history_failures:
        report["status"] = "FAIL"
        report.setdefault("failures", []).extend(history_failures)
        report["failures"] = sorted(set(report["failures"]))
    if selftest_status != "PASS":
        report["status"] = "FAIL"
        report.setdefault("failures", []).append("REUSE_POINT_INERTIA_GATE_SELFTEST_FAILED")
        report["failures"] = sorted(set(report["failures"]))
    report.update(
        {
            "schema_version": "space_syndicate.v076.reuse_point_inertia_gate_report.v1",
            "direction_amendment_id": "V076_REUSE_POINT_INERTIA_MANDATORY_CI_AND_REVIEW_GATE_V1",
            "gate_activation_commit": ACTIVATION_BOUNDARY_COMMIT,
            "v076_gate_base_sha": V076_GATE_BASE_SHA,
            "pr_base_ref": args.pr_base_ref,
            "head_ref": args.head_ref,
            "head_sha": _git(root, "rev-parse", args.head_ref),
            "include_worktree": bool(args.include_worktree),
            "evaluated_source": (
                "HEAD_PLUS_WORKTREE" if args.include_worktree else "COMMITTED_HEAD"
            ),
            "merge_base_sha": _git(root, "merge-base", args.pr_base_ref, args.head_ref),
            "point_inertia_history_base_sha": V076_GATE_BASE_SHA,
            "point_inertia_history_transition_count": history_transition_count,
            "point_inertia_history_failure_count": len(history_failures),
            "scanner_inventory": scanner_inventory,
            "retired_mechanic_scanner": retired_report,
            "gate_selftest": selftest_report,
            "REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS": selftest_report.get(
                "REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS", "FAIL"
            ),
            "REUSE_POINT_INERTIA_GATE_SELFTEST_CASE_COUNT": selftest_report.get(
                "REUSE_POINT_INERTIA_GATE_SELFTEST_CASE_COUNT", 0
            ),
            "REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT": selftest_report.get(
                "REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT", 0
            ),
            "FALSE_GREEN_COUNT": selftest_report.get("FALSE_GREEN_COUNT", -1),
            "VALID_DELTA_FALSE_REJECT_COUNT": selftest_report.get(
                "VALID_DELTA_FALSE_REJECT_COUNT", -1
            ),
            "changed_path_count": len(pr_changed),
            "gate_changed_path_count": len(gate_changed),
            "implementation_bindings": [
                _file_binding(root, path)
                for path in (
                    "tools/v076/v076_reuse_point_inertia_gate.py",
                    "tools/v076/v076_reuse_point_inertia_gate_selftest.py",
                    ".github/workflows/v076-reuse-point-inertia-gate.yml",
                    ".github/workflows/v075-pr90-acceptance.yml",
                    "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json",
                    "docs/architecture/V076_SUPERSESSION_MAP.json",
                    "docs/architecture/V076_OWNER_REUSE_MAP.md",
                    "docs/architecture/V076_INHERITED_GREEN_LEDGER.json",
                    "docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json",
                    "reports/card_certification/v076_card_certification_matrix.json",
                )
            ],
        }
    )
    if args.report_json:
        Path(args.report_json).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    if args.report_md:
        Path(args.report_md).write_text(_markdown_report(report), encoding="utf-8")
    return report


def merge_ratchet(checks_path: Path, expected_head_sha: str) -> dict[str, Any]:
    value = json.loads(checks_path.read_text(encoding="utf-8-sig"))
    rows = value if isinstance(value, list) else value.get(
        "check_runs", value.get("checks", [])
    )
    matches = [
        row for row in rows
        if isinstance(row, dict) and row.get("name") == CHECK_NAME
    ]
    current_matches = [row for row in matches if row.get("head_sha") == expected_head_sha]
    rows_to_judge = current_matches
    if current_matches and all(_is_int(row.get("id")) for row in current_matches):
        latest_id = max(row["id"] for row in current_matches)
        rows_to_judge = [row for row in current_matches if row.get("id") == latest_id]
    current_success = [
        row for row in rows_to_judge
        if str(row.get("status", "")).casefold() == "completed"
        and str(row.get("conclusion", "")).casefold() == "success"
    ]
    green = bool(rows_to_judge and len(current_success) == len(rows_to_judge))
    return {
        "status": "PASS" if green else "FAIL",
        "required_check_name": CHECK_NAME,
        "expected_head_sha": expected_head_sha,
        "exact_name_check_count": len(matches),
        "current_head_exact_name_check_count": len(current_matches),
        "judged_current_head_check_count": len(rows_to_judge),
        "current_head_completed_success_count": len(current_success),
        "agent_merge_requires_reuse_gate": True,
    }


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    validate_parser = sub.add_parser("validate")
    validate_parser.add_argument("--project", default=".")
    validate_parser.add_argument("--pr-base-ref", default=PR_BASE_SHA)
    validate_parser.add_argument("--inertia-base-ref", default=V076_GATE_BASE_SHA)
    validate_parser.add_argument("--gate-base-ref", default=V076_GATE_BASE_SHA)
    validate_parser.add_argument("--head-ref", default="HEAD")
    validate_parser.add_argument("--include-worktree", action="store_true")
    validate_parser.add_argument("--pr-body-file", required=True)
    validate_parser.add_argument("--report-json")
    validate_parser.add_argument("--report-md")

    render_parser = sub.add_parser("render-status")
    render_parser.add_argument("--project", default=".")

    ratchet_parser = sub.add_parser("merge-ratchet")
    ratchet_parser.add_argument("--checks-json", required=True)
    ratchet_parser.add_argument("--expected-head-sha", required=True)

    args = parser.parse_args()
    if args.command == "render-status":
        root = Path(args.project).resolve()
        authorities, _ = discover_authorities(root)
        status = authorities.get("inherited_green", {}).get("canonical_pr_status", {})
        if not isinstance(status, dict):
            print("canonical_pr_status missing", file=sys.stderr)
            return 1
        print(render_status_block(status))
        return 0
    if args.command == "merge-ratchet":
        report = merge_ratchet(Path(args.checks_json), args.expected_head_sha)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0 if report["status"] == "PASS" else 1

    report = validate_live(args)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("status") == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
