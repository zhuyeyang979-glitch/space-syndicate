"""Exact historical identity-status repair; not a product or Gate waiver."""
from __future__ import annotations
import argparse
import base64
import copy
import json
from pathlib import Path
import sys
import textwrap

HEAD = "a026c0a8c6708a878e6e030e7702afb4607a1873"
SUBJECT = "ac5efcc5a5119b8022b573333f707b3a73bff590"
STAGE_ID = "V076_REUSE_GATE_CURRENT_PRODUCT_SUBJECT_REGISTRATION_AC5EFCC5"
OLD_TOKEN = "SUBJECT_REGISTERED_PENDING_GATE"
MANIFEST_PATH = "reports/reuse/full_convergence/candidate_subject_manifest_ac5efcc5.json"
MANIFEST_SHA = "446aa8d52b3936977e78776741e020d3cda0d10d310c20561dd47c243b0bef9f"
LEDGER = "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
LEDGER_SHA = "b8025b8a621ba5a2796c66a41645b47f7b2c34c03e66dff49decf1bc429ad406"
REPORT_ROOT = "reports/reuse/full_convergence/generation10/ac5_registration_status_forward_001"


def build(root: Path) -> dict[str, dict]:
    sys.path.insert(0, str(root / "tools/v076"))
    import v076_current_product_subject_manifest_builder as manifest_builder
    import v076_reuse_point_inertia_gate as gate
    import v076_reuse_full_convergence_batch_builder as append
    import v076_reuse_full_convergence_batch010_registry_projection_builder as io
    if io.git(root,"rev-parse","HEAD") != HEAD or io.git(root,"diff","--cached","--name-only"):
        raise ValueError("EXACT_CLEAN_SOURCE_HEAD_REQUIRED")
    source = io.committed(root,HEAD,LEDGER)
    if append.sha(source) != LEDGER_SHA or (root/LEDGER).read_bytes() != source:
        raise ValueError("LEDGER_SOURCE_DRIFT")
    manifest_bytes = io.committed(root,HEAD,MANIFEST_PATH)
    if append.sha(manifest_bytes) != MANIFEST_SHA:
        raise ValueError("FROZEN_MANIFEST_DRIFT")
    document = append.strict_json_bytes(manifest_bytes,MANIFEST_PATH)
    recomputed = manifest_builder.validate_manifest(root,document,MANIFEST_PATH)
    if recomputed["subject"]["head_sha"] != SUBJECT or recomputed["evaluated_governance_head"]["head_sha"] != SUBJECT:
        raise ValueError("HISTORICAL_SUBJECT_RECOMPUTE_DRIFT")
    claims = recomputed["claims"]
    if any(claims.get(key) is not False for key in ("production_green","human_green","production_cutover_authorized","current_subject_production_revalidation_complete")):
        raise ValueError("HISTORICAL_CLAIMS_NOT_CLOSED")
    helper_bindings = []
    for module in (manifest_builder,gate,append,io):
        path = Path(module.__file__).resolve()
        relative = path.relative_to(root).as_posix()
        content = io.committed(root,HEAD,relative)
        if path.read_bytes() != content:
            raise ValueError("EXECUTION_HELPER_DRIFT:"+relative)
        helper_bindings.append({"path":relative,"sha256":append.sha(content)})
    evidence = {
        "schema_version":"space_syndicate.v076.ac5_identity_status_recompute.v1",
        "result":"PASS_METADATA_IDENTITY_RECOMPUTE_ONLY",
        "observed_head_sha":HEAD,
        "historical_subject_head_sha":SUBJECT,
        "historical_subject_tree_sha":recomputed["subject"]["tree_sha"],
        "manifest_path":MANIFEST_PATH,"manifest_sha256":MANIFEST_SHA,
        "validator":"v076_current_product_subject_manifest_builder.validate_manifest",
        "exact_recomputation_pass":recomputed == document,
        "original_invalid_stage_token":OLD_TOKEN,
        "completion_scope":"Historical AC5 subject identity registration only, not runtime qualification, Required Gate, Golden capability or current product green.",
        "frozen_gate002_failure_path":"reports/reuse/full_convergence/generation10/required_gate_attempt_002/local-gate-outcome.json",
        "frozen_gate002_failure_sha256":append.sha(io.committed(root,HEAD,"reports/reuse/full_convergence/generation10/required_gate_attempt_002/local-gate-outcome.json")),
        "historical_manifest_claims_preserved":claims,
        "execution_helper_bindings":helper_bindings,
        "formal_step11_reexecution_count":0,"product_file_mutation_count":0,
        "required_gate_green":False,"human_green":False,"production_green":False,
    }
    evidence_bytes = append.canonical(evidence)
    before = append.strict_json_bytes(source,LEDGER)
    positions = [i for i,s in enumerate(before["stages"]) if s.get("stage_id") == STAGE_ID]
    if positions != [len(before["stages"])-1]:
        raise ValueError("EXACT_TERMINAL_STAGE_ID_REQUIRED")
    old = before["stages"][positions[0]]
    if old["ledger_status"] != OLD_TOKEN or old["head_sha"] != SUBJECT or old["stage_kind"] != "INFRASTRUCTURE":
        raise ValueError("EXACT_HISTORICAL_STAGE_REQUIRED")
    new = copy.deepcopy(old)
    new["ledger_status"] = "CURRENT_DELTA_GREEN"
    new["infrastructure_justification"] += (
        " This status corrects only the completed historical AC5 subject-registration metadata identity."
        " The frozen manifest was exactly recomputed at its recorded AC5 subject and evaluated HEAD;"
        " it does not attest the current descendant product, Required Gate, runtime revalidation,"
        " production cutover, or human playability."
    )
    new["evidence"].append({
        "evidence_id":"v076-ac5-historical-registration-status-identity-only-recompute",
        "result":"PASS_METADATA_IDENTITY_RECOMPUTE_ONLY",
        "receipt_path":REPORT_ROOT+"/manifest-recompute.json",
        "receipt_sha256":append.sha(evidence_bytes),
        "subject_head_sha":SUBJECT,"subject_tree_sha":old["tree_sha"],
        "original_invalid_stage_token":OLD_TOKEN,
        "completion_scope":"HISTORICAL_IDENTITY_REGISTRATION_ONLY",
        "required_gate_green":False,"production_green_claimed":False,"human_green_claimed":False,
    })
    def rendered(value):
        return textwrap.indent(json.dumps(value,ensure_ascii=False,indent=2),"    ").encode("utf-8")
    target = append._splice_once(source,rendered(old),rendered(new),"AC5_IDENTITY_STATUS_FORWARD_ONLY")
    after = append.strict_json_bytes(target,LEDGER)
    expected = copy.deepcopy(before)
    expected["stages"][positions[0]] = new
    paths = {"historical_reuse":["docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"],"supersession":["docs/architecture/V076_SUPERSESSION_MAP.json"],"inherited_green":[LEDGER],"golden":["docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"],"card_matrix":["reports/card_certification/v076_card_certification_matrix.json"]}
    old_authorities = gate.load_baseline_authorities(root,HEAD,paths)
    new_authorities = copy.deepcopy(old_authorities)
    new_authorities["inherited_green"] = after
    snapshot_failures = gate._authority_snapshot_contract_failures(new_authorities,"ac5-forward")
    monotonic_failures = gate._monotonic_transition_failures(old_authorities,new_authorities,"ac5-forward",[{"path":LEDGER,"status":"M"}])
    checks = {
        "exact_manifest_recomputed":recomputed == document,
        "exact_semantic_delta":after == expected,
        "same_stage_sequence":[s["stage_id"] for s in before["stages"]] == [s["stage_id"] for s in after["stages"]],
        "all_earlier_stages_unchanged":before["stages"][:-1] == after["stages"][:-1],
        "same_stage_head_tree":(old["head_sha"],old["tree_sha"]) == (new["head_sha"],new["tree_sha"]),
        "valid_identity_only_completion_token":new["ledger_status"] in gate.LEDGER_STATUS_VALUES and new["stage_kind"] == "INFRASTRUCTURE" and new["golden_step_ids"] == [],
        "prior_receipts_preserved":new["evidence"][:-1] == old["evidence"],
        "not_claimed_preserved":new["not_claimed"] == old["not_claimed"],
        "no_invented_regression":"regression" not in new,
        "canonical_unchanged":after["canonical_pr_status"] == before["canonical_pr_status"],
        "candidate_pointer_unchanged":after["candidate"] == before["candidate"],
        "golden_unchanged":new_authorities["golden"] == old_authorities["golden"],
        "original_snapshot_contract":not snapshot_failures,
        "original_monotonic_contract":not monotonic_failures,
    }
    if not all(checks.values()):
        raise ValueError("FOCUSED_CHECK_FAILED:"+json.dumps(checks))
    proposal = {
        "schema_version":"space_syndicate.v076.ac5_identity_status_forward_proposal.v1",
        "candidate_kind":"NON_AUTHORITATIVE_METADATA_STATUS_PROPOSAL",
        "source_head_sha":HEAD,"source_tree_sha":io.git(root,"rev-parse",HEAD+"^{tree}"),
        "target_path":LEDGER,"source_sha256":append.sha(source),"target_sha256":append.sha(target),
        "target_bytes_base64":base64.b64encode(target).decode(),
        "old_stage":old,"new_stage":new,"evidence_sha256":append.sha(evidence_bytes),
        "checks":checks,"passed":sum(checks.values()),"total":len(checks),
        "snapshot_failures":snapshot_failures,"monotonic_failures":monotonic_failures,
        "review_status":"PENDING_PRIMARY_AND_INDEPENDENT",
        "official_write_count":0,"product_file_mutation_count":0,"formal_step11_reexecution_count":0,
        "required_gate_green":False,"human_green":False,"production_green":False,
        "builder_sha256":append.sha(Path(__file__).read_bytes()),
    }
    proposal["payload_sha256"] = append.sha(append.canonical(proposal))
    return {"manifest-recompute.json":evidence,"status-proposal.json":proposal}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project",type=Path,required=True)
    parser.add_argument("--output-stage",type=Path,required=True)
    args = parser.parse_args()
    root = args.project.resolve()
    sys.path.insert(0,str(root/"tools/v076"))
    import v076_reuse_full_convergence_batch010_registry_projection_builder as io
    stage = io._stage(root,args.output_stage)
    documents = build(root)
    stage.mkdir(parents=True,exist_ok=False)
    for filename,document in documents.items():
        with (stage/filename).open("xb") as stream:
            stream.write(io.canonical(document))
    print(json.dumps({"status":"PASS_METADATA_PROPOSAL_ONLY","stage":str(stage),"proposal_sha256":io.sha((stage/"status-proposal.json").read_bytes()),"target_sha256":documents["status-proposal.json"]["target_sha256"],"passed":documents["status-proposal.json"]["passed"],"official_write_count":0}))
