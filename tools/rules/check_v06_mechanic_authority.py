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
}
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".res", ".json", ".md", ".cfg", ".godot"}
RETIRED_IDENTIFIERS = (
    "contract_response", "ContractResponse", "contract_accept", "accept_contract",
    "contract_reject", "reject_contract", "contract_timeout", "contract_penalty",
    "contract_signature", "area_trade_contract", "awaiting_contract_response",
    "contract_response_deadline", "contract_response_state", "contract_responder",
	"contract_offer_v06",
    "合同接受", "合同拒绝", "合同超时", "合同回应", "合约罚金", "签署合同",
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
	"tests/anonymous_interaction_schema_v06_test.gd": "NEGATIVE_TEST",
	"tests/anonymous_interaction_router_v06_test.gd": "NEGATIVE_TEST",
    "tests/v06_mechanic_authority_gate_test.gd": "NEGATIVE_TEST",
    "tests/v06_contract_response_retirement_test.gd": "NEGATIVE_TEST",
    "scripts/tools/v06_contract_response_retirement_bench.gd": "NEGATIVE_TEST",
    "scenes/tools/V06ContractResponseRetirementBench.tscn": "NEGATIVE_TEST",
}
ALLOWED_CATEGORIES = {"HISTORICAL", "NEGATIVE_TEST", "MIGRATION_ONLY"}

SPLIT_PATTERNS = (
    re.compile(r"['\"]contract_?['\"]\s*\+\s*['\"]response['\"]", re.I),
    re.compile(r"['\"]contract['\"]\s*\+\s*['\"]_response['\"]", re.I),
    re.compile(r"['\"]area_trade['\"]\s*\+\s*['\"]_contract['\"]", re.I),
	re.compile(r"interaction_domain[^\n]*['\"]contract['\"]", re.I),
	re.compile(r"DOMAINS[^\n]*['\"]contract['\"]", re.I),
    re.compile(r"['\"]合同['\"]\s*\+\s*['\"](?:回应|接受|拒绝|超时)['\"]"),
)


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


def main() -> int:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    mechanics = registry.get("mechanics", [])
    by_id = {str(item.get("mechanic_id", "")): item for item in mechanics}
    required = {
        "contract_response": "RETIRED",
		"contract_offer_v06": "RETIRED",
        "card_counter_response": "ACTIVE",
        "monster_wager_response": "ACTIVE",
        "card_target_choice": "ACTIVE",
        "conditional_order_auto_settlement": "ACTIVE",
    }
    registry_errors = [f"{key}: expected {value}" for key, value in required.items()
                       if by_id.get(key, {}).get("status") != value]
    registry_errors += [f"invalid allowlist category: {path}={category}"
                        for path, category in ALLOWLIST.items() if category not in ALLOWED_CATEGORIES]
    unreferenced = [item.get("mechanic_id", "") for item in mechanics
                    if not item.get("authoritative_sources")]

    production_hits: list[dict[str, object]] = []
    split_hits: list[dict[str, object]] = []
    allowed_hits: list[dict[str, object]] = []
    for path in candidates():
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        category = category_for(rel)
        for line_number, line in enumerate(text.splitlines(), 1):
            for identifier in RETIRED_IDENTIFIERS:
                if identifier in line:
                    hit = {"path": rel, "line": line_number, "identifier": identifier}
                    if category:
                        hit["category"] = category
                        allowed_hits.append(hit)
                    else:
                        production_hits.append(hit)
            for pattern in SPLIT_PATTERNS:
                if pattern.search(line):
                    hit = {"path": rel, "line": line_number, "pattern": pattern.pattern}
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
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
