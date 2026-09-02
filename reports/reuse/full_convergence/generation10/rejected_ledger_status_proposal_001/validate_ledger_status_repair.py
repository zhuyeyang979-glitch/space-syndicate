from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

repo = Path(r"D:\ss-v076-generation9-platform-qualification-7a2e10c7-001")
sys.path.insert(0, str(repo / "tools/v076"))
import v076_reuse_point_inertia_gate as gate

ledger_path = "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
head = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
before_bytes = subprocess.check_output(["git", "-C", str(repo), "show", head + ":" + ledger_path])
after_bytes = (repo / ledger_path).read_bytes()
before = json.loads(before_bytes)
after = json.loads(after_bytes)
cases = []
def check(name, condition):
    cases.append({"name": name, "status": "PASS" if condition else "FAIL"})
check("exact_base_head", head == "86fc75eb4c1ab7272c4f88d9184f2e3c75d0c2a4")
check("preserve_stage_count", len(before["stages"]) == len(after["stages"]))
check("preserve_all_earlier_stages", before["stages"][:-1] == after["stages"][:-1])
old, new = before["stages"][-1], after["stages"][-1]
check("prior_status_really_invalid", old["ledger_status"] not in gate.LEDGER_STATUS_VALUES)
check("new_status_valid_not_green", new["ledger_status"] == "REGRESSED_WITH_EVIDENCE")
check("exact_prior_status_recorded", new["regression"]["prior_status"] == old["ledger_status"])
check("existing_regression_contract_pass", gate._regression_evidence_complete(new["regression"]))
check("affected_commit_exists", subprocess.run(["git", "-C", str(repo), "cat-file", "-e", new["regression"]["affected_commit"] + "^{commit}"], capture_output=True).returncode == 0)
check("failure_evidence_exists", (repo / new["regression"]["failure_evidence"]).is_file())
expected_stage = copy.deepcopy(old)
expected_stage["ledger_status"] = new["ledger_status"]
expected_stage["regression"] = new["regression"]
check("stage_changes_exactly_status_and_regression", expected_stage == new)
check("no_green_stage_added", sum(x["ledger_status"] in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"} for x in before["stages"]) == sum(x["ledger_status"] in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"} for x in after["stages"]))
status = after["canonical_pr_status"]
last_green = [x for x in after["stages"] if x["ledger_status"] in {"INHERITED_GREEN", "CURRENT_DELTA_GREEN"}][-1]
check("canonical_latest_completed_exact", status["latest_completed_stage"] == last_green["stage_id"])
check("canonical_latest_head_exact", status["latest_completed_stage_head_sha"] == last_green["head_sha"])
check("canonical_latest_tree_exact", status["latest_completed_stage_tree_sha"] == last_green["tree_sha"])
body = Path(r"D:\ss-v076-generation10-required-gate-002-20260902\v076-pr-body.md").read_text(encoding="utf-8-sig")
check("frozen_live_pr_block_unique", gate._status_block_count(body) == 1)
check("canonical_matches_unchanged_pr_block", gate.render_status_block(status) == gate.extract_status_block(body))
expected = copy.deepcopy(before)
expected["stages"][-1] = expected_stage
for key in ("latest_completed_stage", "latest_completed_stage_head_sha", "latest_completed_stage_tree_sha", "next_stage"):
    expected["canonical_pr_status"][key] = status[key]
check("whole_ledger_no_other_semantic_edits", expected == after)
paths = {
    "historical_reuse": ["docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"],
    "supersession": ["docs/architecture/V076_SUPERSESSION_MAP.json"],
    "inherited_green": [ledger_path],
    "golden": ["docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"],
    "card_matrix": ["reports/card_certification/v076_card_certification_matrix.json"],
}
old_authorities = gate.load_baseline_authorities(repo, head, paths)
new_authorities = copy.deepcopy(old_authorities)
new_authorities["inherited_green"] = after
changed_rows = [row for row in gate.changed_paths(repo, head, head, True) if row.get("path") == ledger_path]
check("existing_git_delta_observer_exact_path", len(changed_rows) == 1)
transition_failures = gate._monotonic_transition_failures(old_authorities, new_authorities, "exact-ledger-status-repair", changed_rows)
check("existing_monotonic_transition_guard", not transition_failures)
report = {
    "schema": "SpaceSyndicateV076LedgerStatusRepairFocusedValidationV1",
    "status": "PASS" if all(x["status"] == "PASS" for x in cases) else "FAIL",
    "scope": "EXACT_PENDING_REGISTRATION_METADATA_REPAIR_NOT_FULL_GATE",
    "head": head, "case_count": len(cases), "pass_count": sum(x["status"] == "PASS" for x in cases),
    "before_sha256": hashlib.sha256(before_bytes).hexdigest(),
    "after_sha256": hashlib.sha256(after_bytes).hexdigest(),
    "transition_failures": transition_failures, "cases": cases,
    "formal_step11_reexecution_count": 0, "product_file_mutation_count": 0,
    "human_green": False, "full_product_production_green": False,
}
output = Path(r"D:\ss-v076-generation10-ledger-status-repair-001-20260902\focused-validation.json")
with output.open("x", encoding="utf-8", newline="\n") as stream:
    stream.write(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(report, ensure_ascii=False))
raise SystemExit(0 if report["status"] == "PASS" else 1)
