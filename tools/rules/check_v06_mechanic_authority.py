#!/usr/bin/env python3
"""Fail when retired v0.6 contract-response mechanics return to active sources."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
REGISTRY = ROOT / "docs/rules/v06_mechanic_status_registry.json"

PRODUCTION_ROOTS = ("scripts", "scenes", "resources", "data", "addons")
FORMAL_RULE_FILES = {
    "AGENTS.md", "README.md", "docs/tabletop_rulebook_v06.md",
    "docs/rules_v06_runtime_directive.md", "docs/rules_summary.md",
    "docs/commercial_playability_gate.md", "docs/transient_gameplay_surface_v06.md",
	"docs/prototype_scope.md", "docs/ai_runtime_ownership_contract.md",
	"docs/card_economy_product_route_effect_runtime_contract.md",
	"docs/card_resolution_execution_runtime_contract.md",
	"docs/contract_runtime_ownership_contract.md",
	"docs/anonymous_interaction_counter_runtime_v06_contract.md",
	"docs/full_run_quality_driver_contract.md",
	"docs/reference_ui_notes.md",
	"docs/playtest_skeleton_contract.md",
}
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".res", ".json", ".md", ".cfg", ".godot"}
RETIRED_IDENTIFIERS = (
    "contract_response", "ContractResponse", "contract_accept", "accept_contract",
    "contract_reject", "reject_contract", "contract_timeout", "contract_penalty",
    "contract_signature", "area_trade_contract", "awaiting_contract_response",
    "contract_response_deadline", "contract_response_state", "contract_responder",
	"contract_offer_v06",
	"intel_contract_trace", "trace_contract_count", "密约回溯1", "密约回溯2",
    "区域供需合约1", "区域供需合约2", "组合供需合约1", "自动撮合合约1",
    "环晶电池专供1", "双边对冲合约1", "惩罚性拒签条款1",
    "合同接受", "合同拒绝", "合同超时", "合同回应", "合约罚金", "签署合同",
	"合约端点无效", "合约选择", '"contract_invalid":',
)
RETIRED_FIELD_IDENTIFIERS = (
    "known_contract_parties", "district_pair", "is_contract",
    "contract_source_district", "contract_target_district",
    "contract_source_region_id", "contract_target_region_id",
	"contract_selection_revision", "contract_product",
	"trace_contract_count",
)

# Every exception is deliberate and categorized. Prefix entries end with '/'.
ALLOWLIST = {
    "docs/rules/v06_mechanic_status_registry.json": "MIGRATION_ONLY",
    "docs/rules/v06_mechanic_status_registry.md": "MIGRATION_ONLY",
    "docs/migration/": "MIGRATION_ONLY",
    "docs/history/": "HISTORICAL",
    "docs/development_log.md": "HISTORICAL",
    "resources/migrations/": "MIGRATION_ONLY",
    "resources/rules/space_syndicate_ruleset_v04.tres": "HISTORICAL",
    "resources/rules/space_syndicate_ruleset_v05.tres": "HISTORICAL",
    "resources/rules/clock_domain_registry_v05.tres": "HISTORICAL",
	"scripts/tools/ruleset_v04_conformance_bench.gd": "HISTORICAL",
	"scripts/tools/ruleset_v05_foundation_bench.gd": "HISTORICAL",
	"scripts/runtime/legacy_contract_payload_guard_v06.gd": "MIGRATION_ONLY",
	"tests/anonymous_interaction_schema_v06_test.gd": "NEGATIVE_TEST",
	"tests/anonymous_interaction_router_v06_test.gd": "NEGATIVE_TEST",
	"tests/compendium_v06_public_semantics_test.gd": "NEGATIVE_TEST",
    "tests/v06_mechanic_authority_gate_test.gd": "NEGATIVE_TEST",
    "tests/v06_contract_response_retirement_test.gd": "NEGATIVE_TEST",
    "scripts/tools/v06_contract_response_retirement_bench.gd": "NEGATIVE_TEST",
    "scenes/tools/V06ContractResponseRetirementBench.tscn": "NEGATIVE_TEST",
}
ALLOWED_CATEGORIES = {"HISTORICAL", "NEGATIVE_TEST", "MIGRATION_ONLY"}

STRING_LITERAL = r"(?:&)?(?:\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*')"
JOIN_GAP = r"(?:\s|\#[^\n]*(?:\n|$)|//[^\n]*(?:\n|$))*"
CONCATENATED_LITERAL_CHAIN = re.compile(
    rf"{STRING_LITERAL}(?:{JOIN_GAP}\+{JOIN_GAP}{STRING_LITERAL})+",
    re.MULTILINE,
)
STRING_LITERAL_CAPTURE = re.compile(
    r"(?:&)?(?P<quote>[\"'])(?P<body>(?:\\.|(?!\1).)*)(?P=quote)",
    re.DOTALL,
)
STRUCTURAL_SPLIT_PATTERNS = (
    re.compile(r"[\"']?interaction_domain[\"']?\s*[:=]\s*(?:&)?[\"']contract[\"']", re.I | re.DOTALL),
    re.compile(r"\bDOMAINS\b.{0,800}?(?:&)?[\"']contract[\"']", re.I | re.DOTALL),
)

EXPECTED_MECHANIC_STATUS = {
    "card_counter_response": "ACTIVE",
    "monster_wager_response": "ACTIVE",
    "card_target_choice": "ACTIVE",
    "forced_decision": "ACTIVE",
    "conditional_order_auto_settlement": "ACTIVE",
    "legacy_project_contract": "RETIRED",
    "contract_response": "RETIRED",
    "contract_accept": "RETIRED",
    "contract_reject": "RETIRED",
    "contract_timeout": "RETIRED",
    "contract_penalty": "RETIRED",
    "contract_signature": "RETIRED",
    "area_trade_contract": "RETIRED",
    "legacy_contract_trace_intel_card": "RETIRED",
    "contract_offer_v06": "RETIRED",
    "target_player_contract_consent": "RETIRED",
    "legacy_contract_save_reader": "MIGRATION_ONLY",
    "legacy_contract_card_alias": "MIGRATION_ONLY",
}
VALID_MECHANIC_STATUS = {"ACTIVE", "RETIRED", "MIGRATION_ONLY", "LORE_ONLY"}


def category_for(path: str) -> str:
    for allowed, category in ALLOWLIST.items():
        if path == allowed or (allowed.endswith("/") and path.startswith(allowed)):
            return category
    return ""


def candidates() -> list[Path]:
    result: set[Path] = set()
    for root_name in PRODUCTION_ROOTS:
        root = ROOT / root_name
        if root.exists():
            result.update(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in TEXT_SUFFIXES)
    for rel in FORMAL_RULE_FILES | {"project.godot", "export_presets.cfg"}:
        path = ROOT / rel
        if path.exists():
            result.add(path)
    tests = ROOT / "tests"
    if tests.exists():
        result.update(p for p in tests.rglob("*.gd") if p.is_file())
    return sorted(result)


def _line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _registry_retired_identifiers(mechanics: list[dict[str, object]]) -> tuple[str, ...]:
    identifiers = list(RETIRED_IDENTIFIERS)
    for item in mechanics:
        if str(item.get("status", "")) != "RETIRED":
            continue
        for identifier in item.get("retired_identifiers", []):
            value = str(identifier)
            if value and value not in identifiers:
                identifiers.append(value)
    return tuple(identifiers)


def _concatenated_literal_hits(text: str, retired_identifiers: tuple[str, ...]) -> list[dict[str, object]]:
    hits: list[dict[str, object]] = []
    folded_identifiers = [(identifier, identifier.casefold()) for identifier in retired_identifiers]
    for match in CONCATENATED_LITERAL_CHAIN.finditer(text):
        fragments = [fragment.group("body") for fragment in STRING_LITERAL_CAPTURE.finditer(match.group(0))]
        if len(fragments) < 2:
            continue
        combined = "".join(fragments).casefold()
        folded_fragments = [fragment.casefold() for fragment in fragments]
        for identifier, folded in folded_identifiers:
            if folded and folded in combined and not any(folded in fragment for fragment in folded_fragments):
                hits.append({"line": _line_number(text, match.start()), "identifier": identifier, "pattern": "concatenated_string_literals"})
    return hits


def _source_splitting_hits(text: str, retired_identifiers: tuple[str, ...]) -> list[dict[str, object]]:
    hits = _concatenated_literal_hits(text, retired_identifiers)
    for pattern in STRUCTURAL_SPLIT_PATTERNS:
        for match in pattern.finditer(text):
            hits.append({"line": _line_number(text, match.start()), "pattern": pattern.pattern})
    return hits


def _self_test() -> int:
    retired = ("contract_response", "合同回应", "area_trade_contract")
    evasions = [
        '"contract_" + "response"',
        '"contract_" +\n "response"',
        '"con" + "tract_res" + "ponse"',
        '"合同" +\n "回应"',
        '"area" + "_trade" + "_contract"',
        '"interaction_domain":\n "contract"',
        'DOMAINS = {\n "counter": 1,\n "contract": 2\n}',
    ]
    controls = [
        '"counter_response"',
        '"monster_wager"',
        '"card_target_choice"',
        '"global_order_budget"',
    ]
    failures = [sample for sample in evasions if not _source_splitting_hits(sample, retired)]
    failures += [sample for sample in controls if _source_splitting_hits(sample, retired)]
    report = {"status": "PASS" if not failures else "FAIL", "case_count": len(evasions) + len(controls), "failures": failures}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not failures else 1


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        return _self_test()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    mechanics = registry.get("mechanics", [])
    mechanic_ids = [str(item.get("mechanic_id", "")) for item in mechanics]
    by_id = {str(item.get("mechanic_id", "")): item for item in mechanics}
    registry_errors = [f"duplicate mechanic_id: {mechanic_id}" for mechanic_id in sorted(set(mechanic_ids)) if mechanic_ids.count(mechanic_id) > 1]
    registry_errors += [f"{key}: expected {value}" for key, value in EXPECTED_MECHANIC_STATUS.items()
                       if by_id.get(key, {}).get("status") != value]
    registry_errors += [f"{mechanic_id}: invalid status {item.get('status', '')}" for mechanic_id, item in by_id.items()
                        if str(item.get("status", "")) not in VALID_MECHANIC_STATUS]
    registry_errors += [f"invalid allowlist category: {path}={category}"
                        for path, category in ALLOWLIST.items() if category not in ALLOWED_CATEGORIES]
    unreferenced = [item.get("mechanic_id", "") for item in mechanics
                    if not item.get("authoritative_sources")]
    for item in mechanics:
        for source in item.get("authoritative_sources", []):
            source_path = ROOT / str(source.get("path", ""))
            section = str(source.get("section", ""))
            if not source_path.is_file():
                registry_errors.append(f"{item.get('mechanic_id', '')}: authority source missing: {source_path.relative_to(ROOT).as_posix()}")
            elif section and section not in source_path.read_text(encoding="utf-8", errors="replace"):
                registry_errors.append(f"{item.get('mechanic_id', '')}: authority section missing: {section}")

    retired_identifiers = _registry_retired_identifiers(mechanics)

    production_hits: list[dict[str, object]] = []
    split_hits: list[dict[str, object]] = []
    allowed_hits: list[dict[str, object]] = []
    for path in candidates():
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        category = category_for(rel)
        for line_number, line in enumerate(text.splitlines(), 1):
            folded_line = line.casefold()
            for identifier in retired_identifiers:
                if identifier.casefold() in folded_line:
                    hit = {"path": rel, "line": line_number, "identifier": identifier}
                    if category:
                        hit["category"] = category
                        allowed_hits.append(hit)
                    else:
                        production_hits.append(hit)
            for identifier in RETIRED_FIELD_IDENTIFIERS:
                if re.search(rf"(?<![A-Za-z0-9_]){re.escape(identifier)}(?![A-Za-z0-9_])", line):
                    hit = {"path": rel, "line": line_number, "identifier": identifier}
                    if category:
                        hit["category"] = category
                        allowed_hits.append(hit)
                    else:
                        production_hits.append(hit)
        for split_hit in _source_splitting_hits(text, retired_identifiers):
            hit = {"path": rel, **split_hit}
            if category:
                hit["category"] = category
                allowed_hits.append(hit)
            else:
                split_hits.append(hit)

    report = {
        "status": "PASS" if not (registry_errors or unreferenced or production_hits or split_hits) else "FAIL",
        "retired_production_identifier_count": len(production_hits),
        "source_splitting_evasion_count": len(split_hits),
        "rule_authority_unreferenced_mechanic_count": len(unreferenced),
        "allowlisted_hit_count": len(allowed_hits),
        "registry_errors": registry_errors,
        "unreferenced_mechanics": unreferenced,
        "production_hits": production_hits,
        "source_splitting_hits": split_hits,
        "allowlisted_hits": allowed_hits,
    }
    if "--summary" in sys.argv[1:]:
        report["allowlisted_hits"] = []
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
