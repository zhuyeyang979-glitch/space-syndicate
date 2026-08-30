#!/usr/bin/env python3
"""Independent, primary-validator-free audit for subject successor-v3."""
from __future__ import annotations
import argparse, hashlib, json, re, subprocess
from pathlib import Path
from typing import Any

AUTHORIZATION_ID="USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD="d701a81dce693b584d52fbfca3e0e78b521ad775"
SCHEMA_PATH="docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v3_20260830.json"
MANIFEST_KIND="SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V3_MANIFEST"
RECORD_KIND="SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V3_RECORD"
ROOT="docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v3/"
PRIOR_PATH="docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/batch-007/transition_46b33bba77b3_e584cd4d8b0c_test-only.json"
PRIOR_SHA="b4a26dfbbd28195606b9839b8dff9eb3032cfa7401570592805c53e44c25b947"
PRIOR_PAYLOAD="4fb8feda0747d7b082e8aa127c2edb595b08ff6b754c9436e2f904ffd2ea4a4e"
PRIOR_CORRECTION="V2-FC-batch-007-01-46b33bba77b3-e584cd4d8b0c-test_only"
PRIOR_BATCH="docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827/batch-007/batch-007-manifest.json"
PRIOR_BATCH_SHA="2f3e33d8933cead2254e6dde73485486dcc33fd3df4fd76ba65d51b06dc3c476"
PRIOR_SET="c58db2b8e7bae5f1eef0e37ebf1dd807e9c188e23109ae769ef6dc0f61ae2511"
PREDECESSOR="docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v2/manifest.json"
PREDECESSOR_SHA="3c5a6171a4faa6f297569470b4a5bccd52a7e07cdd72241579ef01123cc89db4"
PREDECESSOR_CHAIN="ab5ec81bf2ca6c4a4a061fa31e104f682d678e15499e88359e40b9dddacca80e"
REGISTRY="docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
SUPERSESSION="docs/architecture/V076_SUPERSESSION_MAP.json"

def cb(v: Any)->bytes: return (json.dumps(v,ensure_ascii=False,sort_keys=True,separators=(",",":"))+"\n").encode()
def sha(b: bytes)->str: return hashlib.sha256(b).hexdigest()
def setsha(v)->str: return sha(("\n".join(sorted(v))+"\n").encode())
def strict(raw: bytes)->Any: return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=_pairs, parse_constant=lambda _: (_ for _ in ()).throw(ValueError("NONFINITE_JSON")))
def _pairs(pairs):
 d={}
 for k,v in pairs:
  if k in d: raise ValueError("DUPLICATE_JSON_KEY")
  d[k]=v
 return d
def git(root:Path,*args,binary=False):
 p=subprocess.run(["git",*args],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False)
 if p.returncode: raise ValueError("GIT_FAILURE")
 return p.stdout if binary else p.stdout.decode().strip()
def blob(root:Path,ref:str,path:str)->bytes:
 return git(root,"show",f"{ref}:{path}",binary=True)
def projection(root:Path,ref:str,selector:dict[str,Any])->dict[str,Any]:
 reg=json.loads(blob(root,ref,REGISTRY)); sup=json.loads(blob(root,ref,SUPERSESSION)); dyn=json.loads(blob(root,ref,"docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json")); owner=blob(root,ref,"docs/architecture/V076_OWNER_REUSE_MAP.md").decode("utf-8-sig","replace")
 comps=set(selector["component_ids"]); paths=set(selector["paths"]); rows=[]
 for kind in ("component_inventory","historical_identity_backfill"):
  for row in reg.get(kind,[]):
   if isinstance(row,dict) and (row.get("component_id") in comps or row.get("path") in paths):
    x=dict(row); x["authority_source_kind"]=kind; rows.append(x)
 needles=sorted({str(x) for vals in selector.values() for x in vals if x})
 lines=sorted({line.rstrip() for line in owner.splitlines() if any(n in line for n in needles)})
 return {"dynamic_reference_rows":[],"owner_map_lines":lines,"registry_rows":sorted(rows,key=cb),"supersession_rows":[]}
def audit(root:Path,manifest_path:Path,evaluated_head:str)->dict[str,Any]:
 fail=[]
 try: m=strict(manifest_path.read_bytes()); prior=strict((root/Prior_path if False else root/PRIOR_PATH).read_bytes())
 except Exception as e: return {"status":"FAIL","failures":[str(e)],"trusted_by_fingerprint":{}}
 if not isinstance(m,dict): return {"status":"FAIL","failures":["SPR3_MANIFEST_NOT_OBJECT"],"trusted_by_fingerprint":{}}
 if m.get("manifest_kind")!=MANIFEST_KIND or m.get("schema_path")!=SCHEMA_PATH or m.get("artifact_root_kind") not in ("EXTERNAL_STAGE_REVIEW","COMMITTED_SUCCESSOR_ROOT"): fail.append("MANIFEST_SHAPE")
 schema_raw=(root/SCHEMA_PATH).read_bytes()
 if m.get("schema_sha256")!=sha(schema_raw): fail.append("SCHEMA_SHA")
 if sha((root/PRIOR_PATH).read_bytes())!=PRIOR_SHA or prior.get("record_payload_sha256")!=PRIOR_PAYLOAD or prior.get("correction_id")!=PRIOR_CORRECTION: fail.append("FROZEN_PRIOR_DRIFT")
 fps=sorted(prior.get("identity_binding_by_failure",{}))
 if len(fps)!=25 or setsha(fps)!=PRIOR_SET: fail.append("TARGET_SET")
 if m.get("failure_fingerprints")!=fps or m.get("failure_fingerprint_set_sha256")!=PRIOR_SET or m.get("record_count")!=25: fail.append("MANIFEST_TARGET")
 if sha((root/PREDECESSOR).read_bytes())!=PREDECESSOR_SHA or m.get("predecessor_manifest_sha256")!=PREDECESSOR_SHA or m.get("predecessor_record_chain_terminal_sha256")!=PREDECESSOR_CHAIN: fail.append("PREDECESSOR")
 parent=m.get("authority_transition_parent_sha"); change=m.get("authority_transition_commit_sha")
 try:
  if git(root,"rev-parse",f"{change}^1")!=parent or git(root,"diff","--name-only",parent,change).splitlines()!=sorted([REGISTRY,SUPERSESSION]): fail.append("TRANSITION")
 except Exception: fail.append("TRANSITION_GIT")
 trusted={}; previous=PREDECESSOR_CHAIN
 bindings=m.get("record_bindings",[])
 for i,fp in enumerate(fps):
  path=root/"docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v3/records"/("spr3-"+fp[4:]+".json")
  try: r=strict(path.read_bytes())
  except Exception as e: fail.append("RECORD_JSON:"+fp); continue
  local=[]
  if r.get("record_kind")!=RECORD_KIND or r.get("revalidation_id")!="V076-SPR3-"+fp[4:20].upper(): local.append("RECORD_KIND")
  if r.get("failure_fingerprints")!=[fp] or r.get("prior_record_path")!=PRIOR_PATH or r.get("prior_record_sha256")!=PRIOR_SHA or r.get("prior_record_payload_sha256")!=PRIOR_PAYLOAD or r.get("prior_correction_id")!=PRIOR_CORRECTION: local.append("RECORD_PRIOR")
  if r.get("previous_revalidation_chain_sha256")!=previous or r.get("changed_projection_sections")!=["registry_rows"] or r.get("wildcard_count")!=0: local.append("RECORD_CHAIN_POLICY")
  payload=dict(r); expected=payload.pop("record_payload_sha256",None)
  if expected!=sha(cb(payload)): local.append("RECORD_PAYLOAD")
  sel=r.get("authority_selectors",{}); ident=prior.get("identity_binding_by_failure",{}).get(fp,{})
  if r.get("component_id")!=ident.get("current_component_id") or sel.get("paths")!=[ident.get("current_path")]: local.append("RECORD_SELECTOR")
  if isinstance(bindings,list) and len(bindings)==25:
   b=bindings[i]
   if b.get("record_sha256")!=sha(path.read_bytes()) or b.get("record_payload_sha256")!=r.get("record_payload_sha256") or b.get("previous_revalidation_chain_sha256")!=previous: local.append("MANIFEST_BINDING")
  if local: fail.extend([x+":"+fp for x in local])
  else: trusted[fp]={"revalidation_id":r.get("revalidation_id"),"record_payload_sha256":r.get("record_payload_sha256"),"prior_record_path":PRIOR_PATH}
  previous=r.get("record_payload_sha256",previous)
 return {"status":"PASS" if not fail else "FAIL","failures":sorted(set(fail)),"trusted_by_fingerprint":trusted if not fail else {},"independent":True,"record_count":len(trusted)}

def main(argv=None)->int:
 p=argparse.ArgumentParser(); p.add_argument("--project",type=Path,default=Path.cwd()); p.add_argument("--manifest",type=Path,required=True); p.add_argument("--evaluated-head",default="HEAD"); a=p.parse_args(argv); r=audit(a.project.resolve(),a.manifest.resolve(),a.evaluated_head); print(json.dumps(r,ensure_ascii=False,sort_keys=True,indent=2)); return 0 if r["status"]=="PASS" else 1
if __name__=="__main__": raise SystemExit(main())
