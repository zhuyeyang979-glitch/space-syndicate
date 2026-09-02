"""Exact non-production Resource/script identity characterization; no runtime or writes."""
from __future__ import annotations
import copy
import hashlib
import json
import subprocess
from pathlib import Path
from unittest.mock import patch

import v076_reuse_point_inertia_gate as gate
import v076_reuse_full_convergence_batch011_registry_projection_builder as builder
import v076_reuse_point_inertia_gate_selftest as legacy


def run(root: Path) -> dict:
    head = builder.io.git(root,"rev-parse","HEAD")
    _, paths = gate.discover_authorities(root)
    before = gate.load_baseline_authorities(root,head,paths)
    script_path = "scripts/ai/ai_policy_profile_resource.gd"
    resource_path = "resources/ai/ai_policy_profile_v1.tres"
    script = builder.new_row(script_path,builder.identities.source_identity(root,head,script_path))
    applied_script = [row for row in before["historical_reuse"]["component_inventory"] if row.get("path") == script_path]
    if applied_script and applied_script != [script]:
        raise ValueError("APPLIED_SCRIPT_IDENTITY_DRIFT")
    # In-memory pre-append fixture only: keep this characterization runnable
    # after the exact Registry append, without deleting any actual row.
    before["historical_reuse"]["component_inventory"] = [row for row in before["historical_reuse"]["component_inventory"] if row.get("path") != script_path]
    original = copy.deepcopy(before["historical_reuse"]["component_inventory"])
    inventory = original + [script]
    source = {path:builder.io.committed(root,head,path) for path in (resource_path,script_path)}
    reference = json.loads(builder.io.committed(root,builder.ARTIFACT_HEAD,builder.REGISTRY))
    resource = next(row for row in reference["component_inventory"] if row["path"] == resource_path)
    cases = []

    def check(name: str, passed: bool):
        cases.append({"name":name,"status":"PASS" if passed else "FAIL"})

    def unique(rows, blobs):
        keys = gate._component_class_identity_keys(rows,blobs)
        return len(keys) == len(set(keys))

    def independent(rows, blobs):
        # Independent source interpretation; does not invoke the primary helper,
        # its expected hashes, or its path/key constants.
        group = [r for r in rows if r.get("class_name") == "AiPolicyProfileResource"]
        if len(group) != 2 or sorted(r.get("path","") for r in group) != sorted(source):
            return False
        res = next(r for r in group if r["path"] == resource_path)
        gd = next(r for r in group if r["path"] == script_path)
        if res != resource or type(res) is not dict or gd != script:
            return False
        if not isinstance(blobs,dict) or any(type(blobs.get(p)) is not bytes or blobs[p] != source[p] for p in source):
            return False
        text = blobs[resource_path].decode("utf-8-sig").splitlines()
        declaration = blobs[script_path].decode("utf-8-sig").splitlines()
        return (
            text[0] == '[gd_resource type="Resource" script_class="AiPolicyProfileResource" load_steps=9 format=3]'
            and '[ext_resource type="Script" path="res://scripts/ai/ai_policy_profile_resource.gd" id="1_profile"]' in text
            and 'script = ExtResource("1_profile")' in text
            and declaration.count("class_name AiPolicyProfileResource") == 1
            and declaration.count("extends Resource") == 1
        )

    check("legacy inventory keys unchanged",gate._component_class_identity_keys(original) == [r["class_name"] for r in original])
    check("exact pair primary",unique(inventory,source))
    check("exact pair independent",independent(inventory,source))
    check("old row byte semantic identity",next(r for r in original if r["path"] == resource_path) == resource)
    check("inputs unmodified",before["historical_reuse"]["component_inventory"] == original and inventory[-1] == script)
    for label,blobs in (("missing",None),("empty",{}),("script absent",{resource_path:source[resource_path]}),("resource absent",{script_path:source[script_path]})):
        check(label,not unique(inventory,blobs) and not independent(inventory,blobs))
    for path in source:
        for label,payload in (("truncated",source[path][:-1]),("appended",source[path]+b"\n"),("wrong type",source[path].decode()),("empty",b"")):
            blobs = dict(source); blobs[path] = payload
            check(path+":"+label,not unique(inventory,blobs) and not independent(inventory,blobs))
    for field,value in {
        "component_id":"component.other.ai", "component_role":"OWNER",
        "domain_id":"other", "production_reachable":True, "writes_authority":True,
        "reads_authority":False,"owner_component_id":"other","owner_path":"scripts/other.gd",
        "reuse_disposition":"ADOPT_AS_OWNER","change_class":"DOMAIN_CORE",
        "owns_rng":True,"owns_tick":True,"owns_save":True,"owns_replay":True,"owns_identity":True,"owns_presentation":True,
    }.items():
        rows = copy.deepcopy(inventory); rows[-1][field] = value
        check("script field:"+field,not unique(rows,source) and not independent(rows,source))
    for field in ("production_reachable","writes_authority","owns_tick"):
        rows = copy.deepcopy(inventory); rows[-1][field] = 0
        check("integer false rejected:"+field,not unique(rows,source))
    for field in ("new_component_justification","focused_test_ids","path","owner_path"):
        rows = copy.deepcopy(inventory)
        res = next(r for r in rows if r["path"] == resource_path)
        res[field] = [] if field == "focused_test_ids" else "changed"
        check("old resource unchanged:"+field,not unique(rows,source) and not independent(rows,source))
    third = copy.deepcopy(script); third["component_id"] += ".third"; third["path"] = "scripts/ai/third.gd"
    check("third same class fails",not unique(inventory+[third],source) and not independent(inventory+[third],source))
    renamed = copy.deepcopy(script); renamed["path"] = "scripts/ai/renamed.gd"
    check("different script path fails",not unique(original+[renamed],source))
    check("source mismatch cannot broaden to two scripts",not unique([script,third],source))
    check("source provider committed snapshot",gate._component_class_source_bytes(root,head,inventory) == source)
    check("source provider no pair no reads",gate._component_class_source_bytes(root,"nonexistent-ref",original) == {})
    check("source provider wrong ref failclosed",not unique(inventory,gate._component_class_source_bytes(root,"nonexistent-ref",inventory)))
    with patch.object(gate,"_git_bytes",side_effect=lambda _root,*args,**kw: source[args[1].split(":",1)[1]] if args[1].startswith(head+":") else b"") as git_read:
        result = gate._component_class_source_bytes(root,head,inventory)
        check("provider binds explicit ref",result == source and len(git_read.call_args_list) == 2)
    with patch.object(Path,"read_bytes",return_value=b"wrong worktree bytes"):
        result = gate._component_class_source_bytes(root,head,inventory,True)
        check("worktree cannot inherit committed proof",not unique(inventory,result))
    resolutions = []
    def mutable_ref_git(argv,**kwargs):
        if "rev-parse" in argv:
            oid = ("a" if not resolutions else "b") * 40
            resolutions.append(oid)
            return subprocess.CompletedProcess(argv,0,(oid+"\n").encode(),b"")
        spec = argv[argv.index("show")+1]
        oid,path = spec.split(":",1)
        payload = source[path] if oid == "a"*40 else b"bad intermediate blob"
        return subprocess.CompletedProcess(argv,0,payload,b"")
    with patch.object(gate.subprocess,"run",side_effect=mutable_ref_git):
        fixture_root = root / "__typed_moving_ref_in_memory_fixture__"
        first = gate._component_class_source_bytes(fixture_root,"moving-ref",inventory)
        second = gate._component_class_source_bytes(fixture_root,"moving-ref",inventory)
        check("moving ref is resolved afresh",resolutions == ["a"*40,"b"*40])
        check("cached good blob cannot mask changed ref",unique(inventory,first) and not unique(inventory,second))
    after = copy.deepcopy(before); after["historical_reuse"]["component_inventory"] = inventory
    snapshot = gate._authority_snapshot_contract_failures(after,"typed-test",source)
    transition = gate._monotonic_transition_failures(before,after,"typed-test",[{"path":builder.REGISTRY,"status":"M"}],source)
    check("original snapshot accepts exact typed append",not snapshot)
    check("original monotonic accepts exact typed append",not transition)
    check("original snapshot without proof still rejects",any("COMPONENT_CLASS_NAME_NOT_UNIQUE" in x for x in gate._authority_snapshot_contract_failures(after,"typed-test")))
    check("original monotonic without proof still rejects",any("COMPONENT_CLASS_NAME_NOT_UNIQUE" in x for x in gate._monotonic_transition_failures(before,after,"typed-test")))
    old_alias = copy.deepcopy(after)
    next(r for r in old_alias["historical_reuse"]["component_inventory"] if r["path"] == resource_path)["class_name"] = "AiPolicyProfileV1ResourceInstance"
    check("alias rename remains silent replacement",any("COMPONENT_IDENTITY_SILENT_REPLACEMENT" in x for x in gate._monotonic_transition_failures(before,old_alias,"typed-test",component_source_bytes=source)))
    fixture = legacy._valid_input()
    fixture.authorities["historical_reuse"]["component_inventory"].extend([resource,script])
    fixture.component_source_bytes = source
    check("model uses source proof", "COMPONENT_CLASS_NAME_NOT_UNIQUE" not in gate.validate_model(fixture)["failures"])
    fixture.component_source_bytes = None
    check("model absent proof fails", "COMPONENT_CLASS_NAME_NOT_UNIQUE" in gate.validate_model(fixture)["failures"])
    fixture = legacy._valid_input(); legacy._duplicate_kernel_class(fixture)
    fixture.component_source_bytes = source
    check("second Kernel class and Owner still rejected", "COMPONENT_CLASS_NAME_NOT_UNIQUE" in gate.validate_model(fixture)["failures"])
    return {
        "schema_version":"space_syndicate.v076.resource_script_typed_identity_selftest.v1",
        "status":"PASS" if all(c["status"] == "PASS" for c in cases) else "FAIL",
        "case_count":len(cases),"pass_count":sum(c["status"] == "PASS" for c in cases),"cases":cases,
        "head_sha":head,"gate_sha256":hashlib.sha256(Path(gate.__file__).read_bytes()).hexdigest(),
        "selftest_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "source_sha256":{p:hashlib.sha256(b).hexdigest() for p,b in source.items()},
        "original_snapshot_failures":snapshot,"original_monotonic_failures":transition,
        "repository_mutation_count":0,"godot_execution_count":0,"required_gate_green":False,
        "fixture_scope":"IN_MEMORY_EXACT_TYPED_APPEND_NOT_AN_AUTHORITY_CANDIDATE",
    }


if __name__ == "__main__":
    report = run(Path(__file__).resolve().parents[2])
    print(json.dumps(report,ensure_ascii=False,indent=2))
    raise SystemExit(0 if report["status"] == "PASS" else 1)
