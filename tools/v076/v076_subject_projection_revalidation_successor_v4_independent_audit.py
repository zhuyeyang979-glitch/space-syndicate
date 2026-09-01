#!/usr/bin/env python3
"""Independent primary-free audit for the exact SPR successor-v4."""
from __future__ import annotations
import argparse, hashlib, json, subprocess
from pathlib import Path
from typing import Any

AUTH="USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"; BASE="d701a81dce693b584d52fbfca3e0e78b521ad775"
KIND="SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V4_MANIFEST"; RKIND="SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V4_RECORD"
ROOT="docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v4/"; PRE="docs/architecture/reuse_corrections/v2/subject_projection_revalidation/manifest.json"
PRE_SHA="dff148179980c4e49f277a516bf7f1d0670f4d8b02a40e0f95b077ed92e0967e"; PRE_HEAD="e73e033f915ad420d8d15d78c5bf5dab68b2e5cc"
PARENT="9926d3955da7c14a292259e270f2ac2ff7559dcd"; CHANGE="6209465da4a9ca0c1cb6f0db0cd8a088bd63e793"
REG="docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"; SUP="docs/architecture/V076_SUPERSESSION_MAP.json"; DYN="docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json"; OWNER="docs/architecture/V076_OWNER_REUSE_MAP.md"
SCHEMA="docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v4_20260830.json"

def cb(v:Any)->bytes:return (json.dumps(v,ensure_ascii=False,sort_keys=True,separators=(",",":"))+"\n").encode()
def sha(v:bytes)->str:return hashlib.sha256(v).hexdigest()
def setsha(v:list[str])->str:return sha(("\n".join(sorted(v))+"\n").encode())
def pairs(rows):
 d={}
 for k,v in rows:
  if k in d: raise ValueError("DUPLICATE_JSON_KEY")
  d[k]=v
 return d
def strict(raw:bytes)->Any:return json.loads(raw.decode("utf-8-sig"),object_pairs_hook=pairs,parse_constant=lambda _:(_ for _ in ()).throw(ValueError("NONFINITE_JSON")))
def git(root:Path,*args,binary=False):
 p=subprocess.run(["git","--no-replace-objects","-C",str(root),*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False)
 if p.returncode: raise ValueError("GIT_FAILURE")
 return p.stdout if binary else p.stdout.decode().strip()
def blob(root:Path,ref:str,path:str)->bytes:return git(root,"cat-file","blob",f"{ref}:{path}",binary=True)
def doc(root:Path,ref:str,path:str)->tuple[dict[str,Any],bytes]:
 raw=blob(root,ref,path); val=strict(raw)
 if not isinstance(val,dict):raise ValueError("NOT_OBJECT")
 return val,raw
def projection(root:Path,ref:str,sel:dict[str,Any])->dict[str,Any]:
 reg=strict(blob(root,ref,REG));sup=strict(blob(root,ref,SUP));dyn=strict(blob(root,ref,DYN));owner=blob(root,ref,OWNER).decode("utf-8-sig","replace")
 comps=set(sel["component_ids"]);paths=set(sel["paths"]);rr=[]
 for kind in ("component_inventory","historical_identity_backfill"):
  for row in reg.get(kind,[]):
   if isinstance(row,dict) and (row.get("component_id") in comps or row.get("path") in paths):x=dict(row);x["authority_source_kind"]=kind;rr.append(x)
 sr=[]
 for kind in ("entries","retirement_entries"):
  for row in sup.get(kind,[]):
   if isinstance(row,dict) and (row.get("supersession_id") in set(sel["supersession_ids"]) or row.get("retirement_id") in set(sel["retirement_ids"])):sr.append(row)
 dr=[row for row in dyn.get("entries",[]) if isinstance(row,dict) and row.get("dynamic_reference_id") in set(sel["dynamic_reference_ids"])]
 needles=sorted({str(x) for vals in sel.values() for x in vals if x});lines=sorted({line.rstrip() for line in owner.splitlines() if any(x in line for x in needles)})
 return {"dynamic_reference_rows":sorted(dr,key=cb),"owner_map_lines":lines,"registry_rows":sorted(rr,key=cb),"supersession_rows":sorted(sr,key=cb)}
def path(fp:str)->str:return ROOT+"records/spr4-"+fp[4:]+".json"

def audit(root:Path,manifest_path:Path,evaluated_head:str,stage_dir:Path|None=None,artifact_head:str|None=None)->dict[str,Any]:
 fail=[];trusted={};mode="COMMITTED" if stage_dir is None else "STAGE_REVIEW";artifact_ref=""
 try:
  evaluated_ref=git(root,"rev-parse",f"{evaluated_head}^{{commit}}")
  if stage_dir is None:
   artifact_ref=git(root,"rev-parse",f"{artifact_head or 'HEAD'}^{{commit}}")
   manifest_relative=str(manifest_path.resolve().relative_to(root.resolve())).replace("\\","/")
   if manifest_relative!=ROOT+"manifest.json":raise ValueError("SPR4I_MANIFEST_PATH_INVALID")
   m,mraw=doc(root,artifact_ref,ROOT+"manifest.json");schema_raw=blob(root,artifact_ref,SCHEMA)
  else:mraw=manifest_path.read_bytes();m=strict(mraw);schema_raw=(root/SCHEMA).read_bytes()
  if not isinstance(m,dict):raise ValueError("SPR4I_MANIFEST_NOT_OBJECT")
 except Exception as e:return {"status":"FAIL","mode":mode,"failures":[str(e)],"trusted_by_fingerprint":{},"review_trusted_by_fingerprint":{},"record_count":0,"independent":True,"artifact_head_sha":artifact_ref,"evaluated_head_sha":""}
 if m.get("revalidation_binding_head_sha")!=evaluated_ref or m.get("revalidation_binding_tree_sha")!=git(root,"rev-parse",f"{evaluated_ref}^{{tree}}"):
  return {"status":"FAIL","mode":mode,"failures":["SPR4I_BINDING_INVALID"],"trusted_by_fingerprint":{},"review_trusted_by_fingerprint":{},"record_count":0,"independent":True,"artifact_head_sha":artifact_ref,"evaluated_head_sha":evaluated_ref}
 try:pre,pre_raw=doc(root,evaluated_ref,PRE)
 except Exception as e:return {"status":"FAIL","mode":mode,"failures":[str(e)],"trusted_by_fingerprint":{},"review_trusted_by_fingerprint":{},"record_count":0,"independent":True,"artifact_head_sha":artifact_ref,"evaluated_head_sha":evaluated_ref}
 if sha(pre_raw)!=PRE_SHA or m.get("predecessor_manifest_sha256")!=PRE_SHA:fail.append("SPR4I_PREDECESSOR_SEAL_INVALID")
 if m.get("manifest_kind")!=KIND or m.get("authorization_id")!=AUTH or m.get("authorization_base_head_sha")!=BASE:fail.append("SPR4I_MANIFEST_IDENTITY_INVALID")
 if m.get("schema_sha256")!=sha(schema_raw):fail.append("SPR4I_SCHEMA_SEAL_INVALID")
 if git(root,"rev-parse",f"{CHANGE}^1")!=PARENT or git(root,"diff","--name-only",PARENT,CHANGE).splitlines()!=sorted([REG,SUP]):fail.append("SPR4I_TRANSITION_INVALID")
 bindings=pre.get("record_bindings",[]); source={}; drift=[];preserved=[]
 for b in bindings:
  fp=b.get("failure_fingerprints",[None])[0]
  if not isinstance(fp,str):continue
  r,raw=doc(root,evaluated_ref,b["path"])
  if sha(raw)!=b.get("record_sha256") or r.get("record_payload_sha256")!=b.get("record_payload_sha256"):fail.append("SPR4I_SOURCE_RECORD_SEAL:"+fp)
  source[fp]=(r,b); a=projection(root,PARENT,r["authority_selectors"]); z=projection(root,CHANGE,r["authority_selectors"]); live=projection(root,evaluated_ref,r["authority_selectors"])
  if z!=live:fail.append("SPR4I_LIVE_DRIFT:"+fp)
  (drift if a!=z else preserved).append(fp)
 drift.sort();preserved.sort()
 if len(drift)!=48 or len(preserved)!=34 or set(drift)&set(preserved) or set(drift)|set(preserved)!=set(source):fail.append("SPR4I_PARTITION_INVALID")
 if m.get("failure_fingerprints")!=drift or m.get("preserved_failure_fingerprints")!=preserved or m.get("failure_fingerprint_set_sha256")!=setsha(drift) or m.get("preserved_failure_fingerprint_set_sha256")!=setsha(preserved):fail.append("SPR4I_MANIFEST_PARTITION_INVALID")
 mb=m.get("record_bindings",[]);previous=pre.get("record_chain_terminal_sha256","")
 if not isinstance(mb,list) or len(mb)!=48:fail.append("SPR4I_BINDING_COUNT_INVALID");mb=[]
 for i,fp in enumerate(drift):
  try:
   if stage_dir is None:r,raw=doc(root,artifact_ref,path(fp))
   else:raw=(stage_dir/"records"/Path(path(fp)).name).read_bytes();r=strict(raw)
   src,sb=source[fp]
  except Exception:fail.append("SPR4I_RECORD_UNREADABLE:"+fp);continue
  local=[];payload=dict(r);expected=payload.pop("record_payload_sha256",None)
  if expected!=sha(cb(payload)):local.append("PAYLOAD")
  if r.get("record_kind")!=RKIND or r.get("failure_fingerprints")!=[fp] or r.get("previous_revalidation_chain_sha256")!=previous:local.append("IDENTITY_CHAIN")
  if r.get("predecessor_revalidation_record_path")!=sb.get("path") or r.get("predecessor_revalidation_record_sha256")!=sb.get("record_sha256") or r.get("predecessor_revalidation_record_payload_sha256")!=sb.get("record_payload_sha256"):local.append("PREDECESSOR_RECORD")
  sel=src["authority_selectors"];preproj=projection(root,PARENT,sel);reb=projection(root,CHANGE,sel);live=projection(root,evaluated_ref,sel)
  if r.get("authority_selectors")!=sel or r.get("pre_change_subject_projection")!=preproj or r.get("rebound_subject_projection")!=reb or r.get("live_subject_projection")!=live or r.get("changed_projection_sections")!=["registry_rows"] or r.get("changed_projection_component_ids")!=["component.current.v075_runtime_owner"]:local.append("PROJECTION")
  if i>=len(mb) or mb[i].get("path")!=path(fp) or mb[i].get("record_sha256")!=sha(raw) or mb[i].get("previous_revalidation_chain_sha256")!=previous:local.append("BINDING")
  if local:fail.extend("SPR4I_"+x+":"+fp for x in local)
  else:trusted[fp]={"allowed_invalidations":["SUBJECT_PROJECTION_CHANGED_INVALID"],"prior_record_path":r.get("prior_record_path", ""),"revalidation_id":r.get("revalidation_id", ""),"record_path":path(fp),"revalidation_binding_head_sha":evaluated_ref}
  previous=str(r.get("record_payload_sha256",previous))
 for fp in preserved:
  src,_=source[fp]
  if projection(root,PARENT,src["authority_selectors"])!=projection(root,evaluated_ref,src["authority_selectors"]):fail.append("SPR4I_PRESERVED_DRIFT:"+fp)
  else:trusted[fp]={"allowed_invalidations":["SUBJECT_PROJECTION_CHANGED_INVALID"],"prior_record_path":src.get("prior_record_path", ""),"revalidation_id":src.get("revalidation_id", ""),"record_path":"","revalidation_binding_head_sha":evaluated_ref}
 if previous!=m.get("record_chain_terminal_sha256"):fail.append("SPR4I_CHAIN_TERMINAL_INVALID")
 if fail:trusted={}
 committed=trusted if stage_dir is None else {};review=trusted if stage_dir is not None else {}
 return {"status":"PASS" if not fail else "FAIL","mode":mode,"failures":sorted(set(fail)),"trusted_by_fingerprint":committed,"review_trusted_by_fingerprint":review,"record_count":len(trusted),"drift_record_count":48,"preserved_record_count":34,"independent":True,"artifact_head_sha":artifact_ref,"evaluated_head_sha":evaluated_ref}
def main(argv=None)->int:
 p=argparse.ArgumentParser();p.add_argument("--project",type=Path,default=Path.cwd());p.add_argument("--manifest",type=Path,required=True);p.add_argument("--evaluated-head",required=True);p.add_argument("--artifact-head",default="HEAD");p.add_argument("--stage-dir",type=Path);a=p.parse_args(argv);r=audit(a.project.resolve(),a.manifest.resolve(),a.evaluated_head,a.stage_dir.resolve() if a.stage_dir else None,a.artifact_head);print(json.dumps(r,sort_keys=True,indent=2));return 0 if r["status"]=="PASS" else 1
if __name__=="__main__":raise SystemExit(main())
