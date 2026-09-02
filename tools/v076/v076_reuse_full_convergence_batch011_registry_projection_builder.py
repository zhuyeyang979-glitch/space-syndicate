"""Closed Batch011 Registry proposal, external only and never an authority GO.

Reuses the frozen membership and source-identity readers. Every existing row
is preserved. The exact resource/script typed identity is validated against
snapshot source bytes; no alias migration or old correction rewrite is made.
"""
from __future__ import annotations
import argparse
import base64
import copy
import json
from pathlib import Path

import v076_reuse_point_inertia_gate as gate
import v076_reuse_full_convergence_batch_builder as membership
import v076_reuse_full_convergence_batch010_materializer as identities
import v076_reuse_full_convergence_batch010_registry_projection_builder as io
import v076_current_component_registration_58_builder as splice

MEMBERSHIP_HEAD = "86fc75eb4c1ab7272c4f88d9184f2e3c75d0c2a4"
ARTIFACT_HEAD = "a026c0a8c6708a878e6e030e7702afb4607a1873"
MEMBERSHIP_PATH = "reports/reuse/full_convergence/generation10/historical_identity_batch011_membership_001/membership-candidate.json"
MEMBERSHIP_SHA = "77266d2081eac8510e307e49c6ebe969c45bd5f766828db0b54b8dacbedbe064"
MEMBERSHIP_PAYLOAD_SHA = "75983cbe52244abebd2415564cbbb8fef96319d9eaaa23660a88ddb478f8a965"
FINGERPRINT_SET_SHA = "6d9d0dcb974b7c72175f87888a1d7a4bcbcfe44dda45cd91c56297ea1b34daa1"
SOURCE = "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3"
PARENT = "46b33bba77b356b100ab68bc7c3676d503049a2c"
REGISTRY = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
REGISTRY_SHA = "84cc99166b3515d6ae33dc1e025042fb5344a6fb29fda4cfb403ac7c80a6fdf8"
MECHANIC = "docs/rules/v06_mechanic_status_registry.json"
ACTIVE = "scripts/content/product_industry_definition_resource.gd"
ALIAS_PATH = "resources/ai/ai_policy_profile_v1.tres"
OWNER_ID = "component.current.v075_runtime_owner"
OWNER_PATH = "scripts/v075_runtime/v075_runtime_owner.gd"
DOMAIN = "current.v075_production_combat_candidate"
RESOURCE_LABELS = {
    "resources/ai/personalities/intelligence_ai_policy.tres": ("intelligence_ai_policy_resource_instance", "IntelligenceAiPolicyResourceInstance", "AiPersonalityPolicyResource", "scripts/ai/ai_personality_policy_resource.gd"),
    "resources/ai/personalities/contract_ai_policy.tres": ("contract_ai_policy_resource_instance", "ContractAiPolicyResourceInstance", "AiPersonalityPolicyResource", "scripts/ai/ai_personality_policy_resource.gd"),
    "resources/weather/solar_flare.tres": ("solar_flare_resource_instance", "SolarFlareWeatherDefinitionResourceInstance", "WeatherDefinition", "scripts/runtime/weather_definition.gd"),
}
# Exact audited source citations, keyed by unique frozen member filename stem.
# A citation is not by itself an instantiated runtime or authority edge.
REFERENCES = {
    "movement_balance_model": ("scripts/balance/balance_parameter_model_adapter.gd",25),
    "district_supply_action_receipt": ("scripts/runtime/district_supply_action_port.gd",5),
    "runtime_command_envelope": ("scripts/runtime/military_monster_damage_command_sink.gd",30),
    "optional_route_public_snapshot": ("scripts/runtime/game_table_viewmodel_runtime_service.gd",7),
    "table_snapshot": ("scripts/runtime/game_table_viewmodel_runtime_service.gd",5),
    "monster_family_weather_traits": ("resources/monsters/monster_family_weather_traits_v1.tres",3),
    "monster_battle_lifecycle_policy_v06": ("scripts/runtime/monster_runtime_controller.gd",9),
    "table_presentation_apply_receipt": ("scripts/presentation/table_presentation_refresh_port.gd",32),
    "card_resolution_presentation_port": ("scenes/runtime/CardResolutionPresentationPort.tscn",3),
    "player_inspection_popup": ("scripts/ui/game_screen.gd",43),
    "product_industry_definition_resource": ("resources/content/alpha01/alpha01_content_manifest.gd",6),
    "runtime_state_commit_coordinator": ("scenes/runtime/RuntimePhaseCoordinator.tscn",8),
    "ai_policy_profile_resource": (ALIAS_PATH,3),
    "card_resolution_frame_driver": ("scenes/runtime/CardResolutionFrameDriver.tscn",3),
    "region_supply_runtime_controller": ("resources/content/alpha01/alpha01_content_manifest.gd",748),
    "region_supply_popup_projection_v1": ("scripts/presentation/table_presentation_viewmodel_query.gd",13),
    "intelligence_ai_policy": (ALIAS_PATH,9),
    "solar_flare": ("resources/weather/weather_definition_catalog_v1.tres",9),
    "forced_decision_runtime_scheduler": ("scenes/runtime/ForcedDecisionRuntimeScheduler.tscn",3),
    "card_resolution_transition_sink": ("scenes/runtime/CardResolutionFrameDriver.tscn",7),
    "v06_mechanic_status_registry": ("resources/content/alpha01/alpha01_content_manifest.gd",10),
    "contract_ai_policy": (ALIAS_PATH,8),
    "forced_decision_response_port": ("scenes/runtime/ForcedDecisionResponsePort.tscn",3),
    "card_resolution_execution_runtime_service": ("scenes/runtime/CardResolutionExecutionRuntimeService.tscn",3),
    "developer_balance_panel": ("scenes/ui/DeveloperBalancePanel.tscn",4),
    "table_full_presentation_snapshot": ("scripts/presentation/table_presentation_source_owner.gd",57),
    "monster_runtime_controller": ("resources/content/alpha01/alpha01_content_manifest.gd",32),
    "alpha01_content_manifest_loader": ("scripts/runtime/game_runtime_coordinator.gd",18),
    "public_product_selection_catalog_snapshot": ("scripts/presentation/table_selection_catalog_query_port.gd",6),
    "card_history_restore_dependency_contract": ("scripts/runtime/card_resolution_history_runtime_service.gd",6),
    "route_network_world_bridge": ("scenes/runtime/CityTradeNetworkWorldBridge.tscn",7),
    "district_supply_ai_query_capability": ("scripts/runtime/ai_runtime_controller.gd",51),
    "focus_tools": ("scripts/ui/overlay_layer.gd",4),
    "card_history_public_query_port": ("scenes/runtime/presentation/CardHistoryPublicQueryPort.tscn",3),
    "action_dock": ("scripts/ui/table/compact_current_action_surface.gd",18),
    "runtime_economy_port": ("scenes/runtime/RuntimeWorldPorts.tscn",6),
    "commodity_flow_post_commit_receipt_consumer": ("scenes/runtime/CommodityFlowPostCommitReceiptConsumer.tscn",3),
    "monster_move_command_sink": ("scenes/runtime/MonsterMoveCommandSink.tscn",3),
    "player_identity_authorization_receipt": ("scripts/runtime/player_identity_authorization_boundary.gd",5),
    "ai_card_interaction_observation_v1": ("scripts/runtime/ai_card_interaction_observation_service.gd",6),
    "region_infrastructure_runtime_controller": ("scenes/runtime/GameRuntimeCoordinator.tscn",58),
    "card_play_eligibility_world_bridge": ("scenes/runtime/CardPlayEligibilityWorldBridge.tscn",3),
    "player_card_dock_projection_service": ("scripts/presentation/player_card_dock_viewer_query_port.gd",8),
    "card_target_choice_runtime_controller": ("scenes/runtime/CardTargetChoiceRuntimeController.tscn",3),
    "district_supply_preview_card": ("scenes/ui/DistrictSupplyPreviewCard.tscn",4),
    "public_log_presentation_owner": ("scenes/runtime/presentation/TablePresentationQueryPorts.tscn",8),
    "simulation_trace_contract": ("scripts/runtime/simulation_determinism_audit.gd",39),
    "player_inspection_projection_v1": ("scripts/presentation/public_player_roster_projection_service.gd",8),
    "runtime_phase_frame_context": ("scripts/runtime/runtime_lifecycle_phase_coordinator.gd",15),
    "forced_decision_response_receipt": ("scripts/runtime/forced_decision_response_port.gd",6),
}


def frozen_members(root: Path) -> dict:
    raw = io.committed(root,ARTIFACT_HEAD,MEMBERSHIP_PATH)
    if io.sha(raw) != MEMBERSHIP_SHA:
        raise ValueError("FROZEN_MEMBERSHIP_BYTES_CHANGED")
    document = membership.strict_json_bytes(raw,MEMBERSHIP_PATH)
    unsigned = dict(document)
    digest = unsigned.pop("candidate_payload_sha256",None)
    fps = document.get("failure_fingerprints",[])
    rows = document.get("rows",{})
    if not (digest == MEMBERSHIP_PAYLOAD_SHA == io.sha(io.canonical(unsigned)) and document.get("evaluated_head_sha") == MEMBERSHIP_HEAD and document.get("batch_id") == "batch-011" and len(fps) == len(set(fps)) == 50 and fps == sorted(fps) and io.line_set(fps) == FINGERPRINT_SET_SHA and set(rows) == set(fps)):
        raise ValueError("FROZEN_MEMBERSHIP_IDENTITY_INVALID")
    if io.git(root,"rev-parse",SOURCE+"^1") != PARENT:
        raise ValueError("FROZEN_TRANSITION_PARENT_INVALID")
    stems = []
    for fp in fps:
        row = rows[fp]
        path = row["subject_value"]
        expected_raw = "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:46b33bba77b3->e584cd4d8b0c:"+path
        if row["failure_fingerprint"] != fp or row["raw_failure"] != expected_raw or row["transition_old_prefix"] != PARENT[:12] or row["transition_new_prefix"] != SOURCE[:12] or row["subject_kind"] != "path":
            raise ValueError("FROZEN_MEMBER_DRIFT:"+fp)
        stems.append(Path(path).stem)
    if len(set(stems)) != 50 or set(stems) != set(REFERENCES):
        raise ValueError("CLOSED_REFERENCE_MEMBER_SET_INVALID")
    return document


def new_row(path: str, identity: dict) -> dict:
    active = path == ACTIVE
    name = identity["declared_class_name"]
    suffix = Path(path).stem
    if path in RESOURCE_LABELS:
        suffix,name,script_class,script_path = RESOURCE_LABELS[path]
        if identity["identity_kind"] != "GODOT_RESOURCE" or identity["resource_script_class"] != script_class or identity["script_path"] != script_path:
            raise ValueError("RESOURCE_SCRIPT_IDENTITY_DRIFT:"+path)
    elif identity["identity_kind"] != "GDSCRIPT" or not name:
        raise ValueError("EXACT_GDSCRIPT_IDENTITY_REQUIRED:"+path)
    return {
        "component_id":"component.current."+suffix,"class_name":name,"path":path,
        "domain_id":DOMAIN,"component_role":"PORT" if active else "TEST_SUPPORT",
        "production_reachable":active,"writes_authority":False,"reads_authority":True,
        "owns_rng":False,"owns_tick":False,"owns_save":False,"owns_replay":False,"owns_identity":False,"owns_presentation":False,
        "owner_component_id":OWNER_ID,"owner_path":OWNER_PATH,
        "reuse_disposition":"ADAPT_AS_CONSUMER" if active else "REUSE_AS_TEST",
        "reuse_source_ids":["reuse.v075.combat_candidate"],"reuse_candidates_considered":["reuse.v075.combat_candidate"],
        "new_component_justification":(
            "Batch011 exact historical identity registration; the existing ProductIndustryDefinitionResource is a passive definition input to the current Alpha01 catalog consumed by V075RuntimeOwner, not a gameplay or catalog Owner."
            if active else
            "Batch011 exact historical identity registration; this existing legacy component remains test/reference support outside the active V075 scene execution. Alpha01 source-text diagnostic references do not instantiate it. No runtime, state, tick, RNG, identity, replay, save or presentation ownership is introduced."
        ),
        "supersedes":[],"superseded_by":[],"change_class":"PRODUCTION_COMPOSITION" if active else "TEST_ORACLE_ONLY",
        "focused_test_ids":["v076_reuse_point_inertia_gate_selftest"],"golden_scenario_steps":[],
    }


def build(root: Path, head: str) -> dict:
    head = io.git(root,"rev-parse",head+"^{commit}")
    io.git(root,"merge-base","--is-ancestor",ARTIFACT_HEAD,head)
    builder_path = Path(__file__).resolve()
    builder_relative = builder_path.relative_to(root).as_posix()
    if io.committed(root,head,builder_relative) != builder_path.read_bytes():
        raise ValueError("EXECUTION_BUILDER_DRIFT")
    document = frozen_members(root)
    source = io.committed(root,head,REGISTRY)
    if io.sha(source) != REGISTRY_SHA or (root/REGISTRY).read_bytes() != source:
        raise ValueError("EXACT_REGISTRY_SOURCE_REQUIRED")
    before = membership.strict_json_bytes(source,REGISTRY)
    by_path = {row["path"]:row for row in before["component_inventory"]}
    owner = by_path[OWNER_PATH]
    domain = next(row for row in before["domain_inventory"] if row["domain_id"] == DOMAIN)
    if owner["component_id"] != OWNER_ID or owner["component_role"] != "OWNER" or not owner["production_reachable"] or not owner["writes_authority"] or domain["owner_component_id"] != OWNER_ID:
        raise ValueError("EXISTING_OWNER_BINDING_INVALID")
    dependency_bindings = []
    for path in ("scripts","resources","scenes","addons","assets","project.godot",MECHANIC):
        old = io.git(root,"rev-parse",ARTIFACT_HEAD+":"+path)
        new = io.git(root,"rev-parse",head+":"+path)
        if old != new:
            raise ValueError("AUDITED_SOURCE_GRAPH_DRIFT:"+path)
        dependency_bindings.append({"path":path,"audited_head_git_object":old,"binding_head_git_object":new})
    old_alias = by_path[ALIAS_PATH]
    if old_alias["component_id"] != "component.current.ai_policy_profile_v1_resource" or old_alias["class_name"] != "AiPolicyProfileResource":
        raise ValueError("EXACT_OLD_RESOURCE_INSTANCE_LABEL_REQUIRED")
    alias_identity = identities.source_identity(root,head,ALIAS_PATH)
    if alias_identity["resource_script_class"] != "AiPolicyProfileResource" or alias_identity["script_path"] != "scripts/ai/ai_policy_profile_resource.gd":
        raise ValueError("RESOURCE_INSTANCE_SCRIPT_BINDING_DRIFT")
    additions, proof_rows = [],[]
    for fp in document["failure_fingerprints"]:
        frozen = document["rows"][fp]
        path = frozen["subject_value"]
        historical = identities.source_identity(root,SOURCE,path)
        current = identities.source_identity(root,head,path)
        if path == MECHANIC:
            row = by_path[path]
            if row["component_role"] != "TOOLING" or row["production_reachable"] or row["writes_authority"]:
                raise ValueError("EXACT_EXISTING_MECHANIC_TOOLING_ROLE_REQUIRED")
            if historical["source_blob_sha256"] != "a86b90f1c00bc14e6e3137d3779486e2bf0939d0148658b7eaaaa2ae67d965cd" or current["source_blob_sha256"] != "b4036ba9cc8e64f9ae6e078ff10d4d9ffb73e320446d3386005a12d6110403d2":
                raise ValueError("EXACT_MECHANIC_HISTORICAL_CURRENT_HASH_PAIR_REQUIRED")
            disposition,reach = "HISTORICAL_DIAGNOSTIC_ONLY","DIAGNOSTIC_ONLY"
        else:
            if historical != current or path in by_path:
                raise ValueError("NEW_HISTORICAL_ROW_SOURCE_OR_PATH_DRIFT:"+path)
            row = new_row(path,historical)
            errors = gate._component_row_contract_failures(row,{r["reuse_id"] for r in before["reuse_entries"]},fp)
            if errors:
                raise ValueError("ORIGINAL_ROW_CONTRACT:"+"|".join(errors))
            additions.append(row)
            disposition,reach = ("HISTORICAL_ACTIVE_LINEAGE_REGISTERED","PRODUCTION_REACHABLE") if path == ACTIVE else ("HISTORICAL_TEST_ONLY","TEST_ONLY")
        ref,line = REFERENCES[Path(path).stem]
        ref_bytes = io.committed(root,head,ref)
        text = ref_bytes.decode("utf-8-sig").splitlines()[line-1]
        if path not in text and not (historical["declared_class_name"] and historical["declared_class_name"] in text):
            raise ValueError("EXACT_SOURCE_CITATION_DRIFT:"+path)
        proof_rows.append({"failure_fingerprint":fp,"raw_failure":frozen["raw_failure"],"source_commit":SOURCE,"historical_source_identity":historical,"current_source_identity":current,"component_row":row,"recommended_disposition":disposition,"current_production_reachability":reach,"citation":{"path":ref,"line":line,"source_sha256":io.sha(ref_bytes),"line_text":text,"kind":"SOURCE_CITATION_NOT_EXECUTION_PROOF"}})
    if len(additions) != 49 or len(proof_rows) != 50:
        raise ValueError("EXACT_ROW_CARDINALITY_REQUIRED")
    target = splice.append_inventory(source,before,additions)
    after = membership.strict_json_bytes(target,REGISTRY)
    expected = copy.deepcopy(before)
    expected["component_inventory"] += additions
    if after != expected:
        raise ValueError("UNEXPECTED_AUTHORITY_MUTATION")
    for key in ("component_id","path"):
        values = [row[key] for row in after["component_inventory"]]
        if len(values) != len(set(values)):
            raise ValueError("REGISTRY_IDENTITY_COLLISION:"+key)
    class_sources = gate._component_class_source_bytes(root,head,after["component_inventory"])
    class_keys = gate._component_class_identity_keys(after["component_inventory"],class_sources)
    if len(class_keys) != len(set(class_keys)):
        raise ValueError("REGISTRY_TYPED_CLASS_IDENTITY_COLLISION")
    _, authority_paths = gate.discover_authorities(root)
    old_authorities = gate.load_baseline_authorities(root,head,authority_paths)
    new_authorities = copy.deepcopy(old_authorities)
    new_authorities["historical_reuse"] = after
    snapshot_failures = gate._authority_snapshot_contract_failures(new_authorities,"batch011-proposal",class_sources)
    monotonic_failures = gate._monotonic_transition_failures(old_authorities,new_authorities,"batch011-proposal",[{"path":REGISTRY,"status":"M"}],class_sources)
    if snapshot_failures or monotonic_failures:
        raise ValueError("ORIGINAL_AUTHORITY_GUARD:"+"|".join(snapshot_failures+monotonic_failures))
    helper_bindings = []
    for module in (gate,membership,identities,io,splice):
        path = Path(module.__file__).resolve()
        relative = path.relative_to(root).as_posix()
        content = io.committed(root,head,relative)
        if path.read_bytes() != content:
            raise ValueError("EXECUTION_HELPER_DRIFT:"+relative)
        helper_bindings.append({"path":relative,"sha256":io.sha(content)})
    result = {
        "schema_version":"space_syndicate.v076.batch011_registry_projection_candidate.v1",
        "candidate_kind":"NON_AUTHORITATIVE_EXACT_BATCH011_METADATA_PROJECTION",
        "batch_id":"batch-011","binding_head_sha":head,"binding_tree_sha":io.git(root,"rev-parse",head+"^{tree}"),
        "frozen_membership_head_sha":MEMBERSHIP_HEAD,"frozen_membership_sha256":MEMBERSHIP_SHA,"failure_fingerprint_set_sha256":FINGERPRINT_SET_SHA,
        "failure_count":50,"registry_rows_before":len(before["component_inventory"]),"registry_rows_after":len(after["component_inventory"]),"appended_path_row_count":49,"unchanged_reused_member_count":1,
        "classification_counts":{"HISTORICAL_TEST_ONLY":48,"HISTORICAL_ACTIVE_LINEAGE_REGISTERED":1,"HISTORICAL_DIAGNOSTIC_ONLY":1},
        "source_current_blob_equal_count":49,"historical_current_blob_difference_count":1,
        "old_component_row_mutation_count":0,"original_snapshot_guard_failures":snapshot_failures,"original_monotonic_guard_failures":monotonic_failures,
        "resource_instance_binding":{"path":ALIAS_PATH,"allowed_changed_fields":[],"unchanged_row":old_alias,"unchanged_row_sha256":io.sha(io.canonical(old_alias)),"source_identity":alias_identity,"class_key":"RESOURCE_INSTANCE_PATH_BOUND:"+ALIAS_PATH,"snapshot_source_sha256":{path:io.sha(payload) for path,payload in class_sources.items()},"identity_replacement_count":0},
        "source_graph_bindings":dependency_bindings,"execution_helper_bindings":helper_bindings,"rows":proof_rows,
        "target_registry":{"path":REGISTRY,"source_sha256":io.sha(source),"target_sha256":io.sha(target),"target_bytes_base64":base64.b64encode(target).decode()},
        "review_status":"PENDING_PRIMARY_AND_INDEPENDENT","go_claim":False,"official_write_count":0,"new_owner_count":0,"product_file_mutation_count":0,"formal_step11_reexecution_count":0,"required_gate_green":False,"human_green":False,"production_green":False,"builder_sha256":io.sha(Path(__file__).read_bytes()),
    }
    result["payload_sha256"] = io.sha(io.canonical(result))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project",type=Path,default=Path.cwd())
    parser.add_argument("--head-ref",default="HEAD")
    parser.add_argument("--output-stage",type=Path,required=True)
    args = parser.parse_args()
    root = args.project.resolve()
    stage = io._stage(root,args.output_stage)
    result = build(root,args.head_ref)
    stage.mkdir(parents=True,exist_ok=False)
    output = stage/"batch011_registry_projection_candidate.json"
    with output.open("xb") as stream:
        stream.write(io.canonical(result))
    print(json.dumps({"status":"PASS_PROPOSAL_ONLY","candidate":str(output),"candidate_sha256":io.sha(output.read_bytes()),"official_write_count":0}))
