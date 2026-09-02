from __future__ import annotations
import base64
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(r"D:\ss-v076-generation9-platform-qualification-7a2e10c7-001")
STAGE = Path(__file__).parent
sys.path.insert(0, str(ROOT / "tools/v076"))
import v076_current_component_registration_58_builder as builder

candidate_bytes = (STAGE / "current58_registration_candidate.json").read_bytes()
candidate = json.loads(candidate_bytes)
checks = []
def check(name, result):
    checks.append({"name":name, "pass":bool(result)})
def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()
check("exact reviewed candidate", builder.sha(candidate_bytes) == "d02fca72dbde48fdf31f5c5422ba60455a318911ee54274d9298cb769ad1a19d")
check("exact source Head", git("rev-parse","HEAD") == candidate["evaluated_head_sha"])
check("exact source tree", git("rev-parse","HEAD^{tree}") == candidate["evaluated_tree_sha"])
check("unchanged index", not git("diff","--cached","--name-only"))
target_paths = [row["path"] for row in candidate["target_files"]]
check("exact tracked delta", sorted(git("diff","--name-only").splitlines()) == sorted(target_paths))
for row in candidate["target_files"]:
    check("original committed digest:"+row["path"], builder.sha(builder.projection.committed(ROOT,candidate["evaluated_head_sha"],row["path"])) == row["source_sha256"])
    target = (ROOT/row["path"]).read_bytes()
    check("applied exact bytes:"+row["path"], target == base64.b64decode(row["target_bytes_base64"],validate=True) and builder.sha(target) == row["target_sha256"])
after = json.loads((ROOT/builder.REGISTRY).read_bytes())
paths = {row["path"] for row in after["component_inventory"]}
raw = json.loads(builder.projection.committed(ROOT,builder.RAW_ARTIFACT_HEAD,builder.RAW_PATH))
unclassified = [failure.split(":",1)[1] for failure in raw["failures"] if failure.startswith("UNCLASSIFIED_NEW_COMPONENT:")]
check("58 formerly unclassified current paths now bound", len(unclassified) == 58 and all(builder.gate._component_binding_path(path) in paths for path in unclassified))
check("no product delta", not any(builder.gate._is_product_component_path(path) for path in target_paths))
authorities = {
    "historical_reuse":[builder.REGISTRY], "inherited_green":[builder.LEDGER],
    "supersession":["docs/architecture/V076_SUPERSESSION_MAP.json"],
    "golden":["docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"],
    "card_matrix":["reports/card_certification/v076_card_certification_matrix.json"],
}
old = builder.gate.load_baseline_authorities(ROOT,candidate["evaluated_head_sha"],authorities)
new = copy.deepcopy(old)
new["historical_reuse"] = after
new["inherited_green"] = json.loads((ROOT/builder.LEDGER).read_bytes())
failures = builder.gate._monotonic_transition_failures(old,new,"exact-current58-applied",[{"path":path,"status":"M"} for path in target_paths])
check("original monotonic transition guard", not failures)
check("all stages unchanged", old["inherited_green"]["stages"] == new["inherited_green"]["stages"])
check("canonical status unchanged", old["inherited_green"]["canonical_pr_status"] == new["inherited_green"]["canonical_pr_status"])
check("golden unchanged", old["golden"] == new["golden"])
uid_lines = [line for line in git("status","--porcelain=v1","--untracked-files=all").splitlines() if line.startswith("?? ") and line.endswith(".uid")]
check("296 historical uid files retained", len(uid_lines) == 296)
report = {"status":"PASS_METADATA_APPLICATION_ONLY" if all(row["pass"] for row in checks) else "FAIL", "evaluated_head_sha":candidate["evaluated_head_sha"], "candidate_sha256":builder.sha(candidate_bytes), "passed":sum(row["pass"] for row in checks), "total":len(checks), "checks":checks, "original_monotonic_guard_failures":failures, "product_file_mutation_count":0, "formal_step11_reexecution_count":0, "required_gate_green":False, "human_green":False, "production_green":False, "historical_failure_reclassification_count":0}
with (STAGE/"applied-metadata-validation.json").open("xb") as stream:
    stream.write(builder.canonical(report))
print(json.dumps(report))
raise SystemExit(0 if report["status"] == "PASS_METADATA_APPLICATION_ONLY" else 1)
