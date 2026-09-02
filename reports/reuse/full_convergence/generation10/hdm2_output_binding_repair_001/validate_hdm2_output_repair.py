from __future__ import annotations
import hashlib
import json
from pathlib import Path
import sys

repo = Path(r"D:\ss-v076-generation9-platform-qualification-7a2e10c7-001")
output = Path(r"D:\ss-v076-generation10-hdm2-output-repair-validation-001-20260902")
sys.path.insert(0, str(repo / "tools/v076"))
import v076_historical_delta_metadata_successor_v2_builder as builder
import v076_historical_delta_metadata_successor_v2 as primary
import v076_historical_delta_metadata_successor_v2_independent_audit as independent

def save(name, value):
    with (output / name).open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n")
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
head = "86fc75eb4c1ab7272c4f88d9184f2e3c75d0c2a4"
legacy_source = repo / builder.SUCCESSOR_ROOT
legacy_manifest = builder.strict_json((legacy_source / "manifest.json").read_bytes())
input_hashes = {name:digest(repo / "tools/v076" / name) for name in (
    "v076_historical_delta_metadata_successor_v2_builder.py",
    "v076_historical_delta_metadata_successor_v2_selftest.py",
    "v076_historical_delta_metadata_successor_v2.py",
    "v076_historical_delta_metadata_successor_v2_independent_audit.py",
)}
save("input-manifest.json", {"head":head, "tool_sha256":input_hashes, "scope":"TOOLING_STAGING_VALIDATION_NOT_REQUIRED_GATE"})
legacy_result = builder.build(repo, output / "legacy-generated", created_at=legacy_manifest["created_at"])
legacy_matches = []
for name in ["manifest.json"] + ["records/" + Path(row["path"]).name for row in legacy_manifest["record_bindings"]]:
    expected, actual = legacy_source / name, output / "legacy-generated" / name
    legacy_matches.append({"path":name, "expected_sha256":digest(expected), "actual_sha256":digest(actual), "equal":expected.read_bytes() == actual.read_bytes()})
save("legacy-byte-parity.json", {"status":"PASS" if all(x["equal"] for x in legacy_matches) else "FAIL", "file_count":len(legacy_matches), "files":legacy_matches, "stdout_byte_identity_claimed":False})
epoch_root = builder.SUCCESSOR_ROOT + "epochs/" + head + "/"
epoch_id = "V076-HDM-SUCCESSOR-V2-CHEAD-" + head.upper()
fresh_result = builder.build(repo, output / "fresh-generated", binding_head=head, created_at="2026-09-02T15:10:00Z", repository_output_root=epoch_root, manifest_id=epoch_id)
save("fresh-builder-result.json", fresh_result)
fresh_manifest = output / "fresh-generated/manifest.json"
primary_result = primary.validate_manifest(repo, fresh_manifest, evaluated_head=head)
save("fresh-primary-result.json", primary_result)
independent_result = independent.audit(repo, fresh_manifest)
save("fresh-independent-result.json", independent_result)
all_paths_correct = all(row["path"].startswith(epoch_root + "records/") for row in builder.strict_json(fresh_manifest.read_bytes())["record_bindings"])
parity = bool(primary_result.get("authority_projection_sha256")) and primary_result.get("authority_projection_sha256") == independent_result.get("authority_projection_sha256")
report = {
    "status":"PASS" if all(x["equal"] for x in legacy_matches) and primary_result.get("status") == "PASS" and independent_result.get("status") == "PASS" and parity and all_paths_correct else "FAIL",
    "scope":"EXACT_HEAD_HDM2_OUTPUT_REPAIR_STAGING_ONLY",
    "head":head,
    "legacy_artifact_count":len(legacy_matches),
    "legacy_artifact_mismatch_count":sum(not x["equal"] for x in legacy_matches),
    "fresh_identity_count":fresh_result["identity_count"],
    "fresh_record_count":fresh_result["record_count"],
    "rebound_count":fresh_result["rebound_count"],
    "preserved_count":fresh_result["preserved_count"],
    "primary_status":primary_result.get("status"),
    "independent_status":independent_result.get("status"),
    "authority_projection_sha256":primary_result.get("authority_projection_sha256"),
    "dual_projection_parity":parity,
    "all_record_paths_match_explicit_epoch":all_paths_correct,
    "old_artifact_write_count":0,
    "formal_step11_reexecution_count":0,
    "required_gate_green":False,
    "human_green":False,
    "production_green":False,
}
save("summary.json", report)
print(json.dumps(report, ensure_ascii=False))
raise SystemExit(0 if report["status"] == "PASS" else 1)
