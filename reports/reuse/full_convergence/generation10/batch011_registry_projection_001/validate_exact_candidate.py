"""Closed candidate-002 audit; no Registry write or correction authority GO."""
from __future__ import annotations
import argparse
import base64
import copy
import hashlib
import json
from pathlib import Path
import sys

HEAD = "30002f6e691ad8a9c555f95abc29c9e71a638236"
CANDIDATE_SHA = "48ca76ef8063ede499e3e1cc775a2025eca0a0aaade7a7b7b7e0f26ccfa66f6a"
TARGET_SHA = "fa8486af2023a067df3af6e4e1eb5f4247e78f96f2b26e18a050d015c3a7667f"


def run(root: Path, candidate: Path, applied: bool) -> dict:
    sys.path.insert(0,str(root/"tools/v076"))
    import v076_reuse_full_convergence_batch011_registry_projection_builder as b
    raw = candidate.read_bytes()
    if b.io.sha(raw) != CANDIDATE_SHA:
        raise ValueError("EXACT_CANDIDATE_BYTES_REQUIRED")
    doc = b.membership.strict_json_bytes(raw,str(candidate))
    source = b.io.committed(root,HEAD,b.REGISTRY)
    target = base64.b64decode(doc["target_registry"]["target_bytes_base64"],validate=True)
    before = b.membership.strict_json_bytes(source,b.REGISTRY)
    after = b.membership.strict_json_bytes(target,b.REGISTRY)
    rows = doc["rows"]
    cases = []
    def check(name, value):
        cases.append({"name":name,"status":"PASS" if value else "FAIL"})
    check("candidate bound to exact committed Head",doc["binding_head_sha"] == HEAD)
    check("candidate tree matches commit",doc["binding_tree_sha"] == b.io.git(root,"rev-parse",HEAD+"^{tree}"))
    unsigned = dict(doc); unsigned.pop("payload_sha256")
    check("payload and canonical file match",b.io.sha(b.io.canonical(unsigned)) == doc["payload_sha256"] and b.io.canonical(doc) == raw)
    check("source and target hashes",b.io.sha(source) == b.REGISTRY_SHA == doc["target_registry"]["source_sha256"] and b.io.sha(target) == TARGET_SHA == doc["target_registry"]["target_sha256"])
    check("actual Registry exact expected epoch",(root/b.REGISTRY).read_bytes() == (target if applied else source))
    if not applied:
        check("fresh committed builder recomputation exact",b.build(root,HEAD) == doc)
    else:
        b.io.git(root,"merge-base","--is-ancestor",HEAD,"HEAD")
        check("applied candidate unchanged",b.io.sha(raw) == CANDIDATE_SHA)
    check("all 474 old rows unchanged",after["component_inventory"][:474] == before["component_inventory"] and len(before["component_inventory"]) == 474)
    check("only inventory appended",{k:v for k,v in before.items() if k != "component_inventory"} == {k:v for k,v in after.items() if k != "component_inventory"})
    additions = after["component_inventory"][474:]
    check("49 append exact original-byte splice",len(additions) == 49 and b.splice.append_inventory(source,before,additions) == target)
    frozen = b.frozen_members(root)
    check("exact 50 unique members",[r["failure_fingerprint"] for r in rows] == frozen["failure_fingerprints"] and len(rows) == 50)
    check("48 test 1 active 1 diagnostic",sum(r["recommended_disposition"] == "HISTORICAL_TEST_ONLY" for r in rows) == 48 and sum(r["recommended_disposition"] == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED" for r in rows) == 1 and sum(r["recommended_disposition"] == "HISTORICAL_DIAGNOSTIC_ONLY" for r in rows) == 1)
    check("one existing mechanic document reused",len([r for r in rows if r["component_row"]["path"] == b.MECHANIC]) == 1 and not any(r["path"] == b.MECHANIC for r in additions))
    check("no added ownership or writes",all(r["component_role"] in ("TEST_SUPPORT","PORT") and r["writes_authority"] is False and all(r[k] is False for k in ("owns_rng","owns_tick","owns_save","owns_replay","owns_identity","owns_presentation")) for r in additions))
    check("one passive production definition",[r["path"] for r in additions if r["production_reachable"]] == [b.ACTIVE])
    check("source citation not execution proof",all(r["citation"]["kind"] == "SOURCE_CITATION_NOT_EXECUTION_PROOF" for r in rows))
    check("no green claims or official writes",all(doc[k] is False for k in ("go_claim","required_gate_green","human_green","production_green")) and doc["official_write_count"] == 0)
    for item in doc["source_graph_bindings"]:
        check("source dependency:"+item["path"],item["binding_head_git_object"] == b.io.git(root,"rev-parse",HEAD+":"+item["path"]) == item["audited_head_git_object"])
    for item in doc["execution_helper_bindings"]:
        check("committed helper:"+item["path"],b.io.sha(b.io.committed(root,HEAD,item["path"])) == item["sha256"] == b.io.sha((root/item["path"]).read_bytes()))
    check("builder bytes bound",b.io.sha(Path(b.__file__).read_bytes()) == doc["builder_sha256"] == b.io.sha(b.io.committed(root,HEAD,"tools/v076/v076_reuse_full_convergence_batch011_registry_projection_builder.py")))
    _, paths = b.gate.discover_authorities(root)
    old_auth = b.gate.load_baseline_authorities(root,HEAD,paths)
    new_auth = copy.deepcopy(old_auth); new_auth["historical_reuse"] = after
    blobs = b.gate._component_class_source_bytes(root,HEAD,after["component_inventory"])
    snapshot = b.gate._authority_snapshot_contract_failures(new_auth,"batch011-exact",blobs)
    monotonic = b.gate._monotonic_transition_failures(old_auth,new_auth,"batch011-exact",[{"path":b.REGISTRY,"status":"M"}],blobs)
    check("original snapshot guards",not snapshot)
    check("original monotonic guards",not monotonic)
    for label, mutate, expected in (
        ("old alias rename",lambda d:d["component_inventory"].__setitem__(next(i for i,r in enumerate(d["component_inventory"]) if r["path"] == b.ALIAS_PATH),dict(next(r for r in d["component_inventory"] if r["path"] == b.ALIAS_PATH),class_name="ChangedAlias")),"COMPONENT_IDENTITY_SILENT_REPLACEMENT"),
        ("duplicate id",lambda d:d["component_inventory"][-1].update(component_id=d["component_inventory"][0]["component_id"]),"COMPONENT_ID_NOT_UNIQUE"),
        ("duplicate path",lambda d:d["component_inventory"][-1].update(path=d["component_inventory"][0]["path"]),"COMPONENT_PATH_NOT_UNIQUE"),
        ("duplicate class",lambda d:d["component_inventory"][-1].update(class_name=d["component_inventory"][0]["class_name"]),"COMPONENT_CLASS_NAME_NOT_UNIQUE"),
        ("unknown owner",lambda d:d["component_inventory"][-1].update(owner_component_id="UNKNOWN"),"OWNER"),
    ):
        changed = copy.deepcopy(new_auth); mutate(changed["historical_reuse"])
        failures = b.gate._monotonic_transition_failures(old_auth,changed,"negative",component_source_bytes=blobs)
        check("negative:"+label,any(expected in item for item in failures))
    check("negative:no typed source proof",any("COMPONENT_CLASS_NAME_NOT_UNIQUE" in f for f in b.gate._authority_snapshot_contract_failures(new_auth,"negative")))
    return {"schema_version":"space_syndicate.v076.batch011_exact_registry_audit.v1","status":"PASS" if all(c["status"] == "PASS" for c in cases) else "FAIL","passed":sum(c["status"] == "PASS" for c in cases),"total":len(cases),"checks":cases,"candidate_sha256":CANDIDATE_SHA,"binding_head_sha":HEAD,"target_sha256":TARGET_SHA,"mode":"APPLIED_VERIFICATION" if applied else "PRE_APPLY_AUDIT","snapshot_failures":snapshot,"monotonic_failures":monotonic,"script_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),"official_write_count":0,"required_gate_green":False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root",type=Path,required=True)
    parser.add_argument("--candidate",type=Path,required=True)
    parser.add_argument("--applied",action="store_true")
    args = parser.parse_args()
    report = run(args.root.resolve(),args.candidate,args.applied)
    print(json.dumps(report,ensure_ascii=False,indent=2))
    raise SystemExit(0 if report["status"] == "PASS" else 1)
