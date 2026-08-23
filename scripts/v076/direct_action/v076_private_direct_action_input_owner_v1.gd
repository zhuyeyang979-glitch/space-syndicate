@tool
extends Node
class_name V076PrivateDirectActionInputOwnerV1

const AuthorityCommand := preload(
	"res://scripts/v076/simulation/v076_authority_command_v1.gd"
)
const StateCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
)
const DeterministicKernel := preload(
	"res://scripts/v076/simulation/v076_deterministic_kernel.gd"
)
const GeodesicMetric := preload(
	"res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd"
)
const MilitaryCrosswalk := preload(
	"res://scripts/v076/military/v076_military_card_crosswalk_v1.gd"
)
const ProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)
const MissionCore := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)
const DomainReducer := preload(
	"res://scripts/v076/direct_action/v076_private_direct_action_reducer_v1.gd"
)

const SCHEMA_VERSION := 1
const DOMAIN_ID := "future.private_direct_action_input"
const OWNER_ID := "component.v076.private_direct_action_input"
const COMMAND_TYPE := DomainReducer.COMMAND_TYPE_INTAKE
const DOMAIN_PRIORITY := 40
const ACTION_KIND_MILITARY := DomainReducer.ACTION_KIND_MILITARY
const ACTION_KIND_MONSTER_SKILL := DomainReducer.ACTION_KIND_MONSTER_SKILL
const MISSION_ASSAULT_REGION := "ASSAULT_REGION"
const MISSION_ASSAULT_MONSTER := "ASSAULT_MONSTER"
const ALLOWED_MISSIONS := [MISSION_ASSAULT_REGION, MISSION_ASSAULT_MONSTER]
const FORBIDDEN_MISSIONS := ["GUARD", "PROTECT"]
const REQUEST_FIELDS := [
	"schema_version",
	"submission_id",
	"actor_id",
	"mission_kind",
	"military_unit_uid",
	"catalog_card_id",
	"card_instance_id",
	"action_slot_id",
	"asset_reservation_plan",
	"source_face_id",
	"target_face_id",
	"target_region_id",
	"target_monster_source_instance_id",
	"target_region_revision",
	"public_targets",
	"source_effect_id",
	"producer_sequence",
]
const MONSTER_SKILL_REQUEST_FIELDS := [
	"schema_version",
	"submission_id",
	"actor_id",
	"producer_sequence",
]

@export var deterministic_kernel_path := NodePath("../V076DeterministicKernel")
@export var source_authorization_port_path := NodePath(
	"../GameRuntimeCoordinator/CardSemanticSourceAuthorizationPort"
)
@export var card_catalog_owner_path := NodePath(
	"../GameRuntimeCoordinator/CardRuntimeCatalogService"
)
@export var asset_quantity_owner_path := NodePath(
	"../GameRuntimeCoordinator/PlayerManaRuntimeController"
)
@export var military_unit_state_owner_path := NodePath(
	"../GameRuntimeCoordinator/MilitaryRuntimeController"
)
@export var military_physical_eta_owner_path := NodePath(
	"../V076MilitaryPhysicalEtaOwnerV1"
)
@export var facility_damage_intent_owner_path := NodePath("../V075RuntimeOwner")
@export var monster_damage_command_pipeline_path := NodePath(
	"../GameRuntimeCoordinator/RuntimeCommandPipeline"
)

var _kernel: Variant
var _source_authorization_port: Variant
var _card_catalog_owner: Variant
var _asset_quantity_owner: Variant
var _military_unit_state_owner: Variant
var _profile_authority: Variant
var _military_eta_owner: Variant
var _military_crosswalk: Variant
var _facility_damage_intent_owner: Variant
var _monster_damage_command_pipeline: Variant
var _private_monster_skill_owner: Variant
var _configured := false
var _submission_fingerprint_by_id: Dictionary = {}
var _submitted_result_by_id: Dictionary = {}
var _settlement_fingerprint_by_id: Dictionary = {}
var _damage_settlement_by_id: Dictionary = {}
var _intake_settlement_fingerprint_by_id: Dictionary = {}
var _intake_settlement_result_by_id: Dictionary = {}
var _intake_settlement_order: Array[String] = []
var _rejection_count := 0
var _collision_count := 0


func configure_dependencies(
	kernel: Variant,
	source_authorization_port: Variant,
	card_catalog_owner: Variant,
	asset_quantity_owner: Variant,
	military_unit_state_owner: Variant,
	profile_authority: Variant,
	military_eta_owner: Variant,
	facility_damage_intent_owner: Variant,
	monster_damage_command_pipeline: Variant
) -> Dictionary:
	if _configured:
		return _reject("private_direct_action_owner_already_configured")
	if (
		kernel == null
		or source_authorization_port == null
		or card_catalog_owner == null
		or asset_quantity_owner == null
		or military_unit_state_owner == null
		or profile_authority == null
		or military_eta_owner == null
		or facility_damage_intent_owner == null
		or monster_damage_command_pipeline == null
	):
		return _reject("private_direct_action_dependency_missing")
	if not profile_authority.has_method("profile_by_id") \
			or not profile_authority.has_method("record_validation_report") \
			or not military_eta_owner.has_method("calculate_eta") \
			or not military_eta_owner.has_method("debug_snapshot"):
		return _reject("private_direct_action_military_eta_dependency_invalid")
	if not facility_damage_intent_owner.has_method(
		"consume_v076_military_facility_damage_intents"
	) or not facility_damage_intent_owner.has_method(
		"validate_v076_private_monster_skill_bundle"
	) or not facility_damage_intent_owner.has_method(
		"consume_v076_private_monster_skill_submission"
	) or not facility_damage_intent_owner.has_method(
		"consume_v076_military_consequence"
	) or not monster_damage_command_pipeline.has_method(
		"dispatch_military_monster_damage"
	):
		return _reject("private_direct_action_damage_sink_dependency_invalid")
	var eta_debug: Dictionary = military_eta_owner.debug_snapshot()
	if not bool(eta_debug.get("configured", false)) \
			or str(eta_debug.get("owner_id", "")) \
			!= "component.v076.military_physical_eta" \
			or str(eta_debug.get("speed_owner", "")) \
			!= ProfileCatalog.PROFILE_AUTHORITY_ID:
		return _reject("private_direct_action_military_eta_owner_invalid")
	var registration: Dictionary = kernel.register_domain(
		DOMAIN_ID,
		DomainReducer.initial_state(),
		DomainReducer
	)
	if not bool(registration.get("accepted", false)):
		return _reject(str(registration.get(
			"reason", "private_direct_action_domain_registration_failed"
		)))
	_kernel = kernel
	_source_authorization_port = source_authorization_port
	_card_catalog_owner = card_catalog_owner
	_asset_quantity_owner = asset_quantity_owner
	_military_unit_state_owner = military_unit_state_owner
	_profile_authority = profile_authority
	_military_eta_owner = military_eta_owner
	_military_crosswalk = MilitaryCrosswalk.new()
	_facility_damage_intent_owner = facility_damage_intent_owner
	_private_monster_skill_owner = facility_damage_intent_owner
	_monster_damage_command_pipeline = monster_damage_command_pipeline
	_configured = true
	return {
		"accepted": true,
		"reason": "",
		"owner_id": OWNER_ID,
		"domain_id": DOMAIN_ID,
	}


func configure_from_scene_paths() -> Dictionary:
	var profile_authority := ProfileCatalog.new()
	var eta_owner: Variant = get_node_or_null(military_physical_eta_owner_path)
	if eta_owner != null \
			and eta_owner.has_method("debug_snapshot") \
			and not bool(eta_owner.debug_snapshot().get("configured", false)):
		var eta_config: Dictionary = eta_owner.configure(profile_authority)
		if not bool(eta_config.get("accepted", false)):
			return _reject(str(eta_config.get(
				"reason", "private_direct_action_military_eta_configuration_failed"
			)))
	return configure_dependencies(
		get_node_or_null(deterministic_kernel_path),
		get_node_or_null(source_authorization_port_path),
		get_node_or_null(card_catalog_owner_path),
		get_node_or_null(asset_quantity_owner_path),
		get_node_or_null(military_unit_state_owner_path),
		profile_authority,
		eta_owner,
		get_node_or_null(facility_damage_intent_owner_path),
		get_node_or_null(monster_damage_command_pipeline_path)
	)


func submit_private_military_direct_action(
	authorized_bundle: Dictionary,
	request: Dictionary
) -> Dictionary:
	if not _configured:
		return _reject("private_direct_action_owner_not_configured")
	var request_report: Dictionary = request_validation_report(request)
	if not bool(request_report.get("valid", false)):
		return _reject(str(request_report.get(
			"reason", "private_direct_action_request_invalid"
		)))
	var revalidated: Dictionary = _source_authorization_port.validate_authorized_bundle(
		authorized_bundle
	)
	if not bool(revalidated.get("accepted", false)):
		return _reject("private_direct_action_own_hand_revalidation_failed")
	var binding_reason: String = _authorization_binding_reason(revalidated, request)
	if not binding_reason.is_empty():
		return _reject(binding_reason)
	var submission_id: String = str(request.get("submission_id", ""))
	var request_fingerprint: String = StateCodec.fingerprint({
		"action_kind": ACTION_KIND_MILITARY,
		"authorized_bundle_fingerprint": str(revalidated.get(
			"bundle_fingerprint", ""
		)),
		"request": request.duplicate(true),
	})
	if request_fingerprint.is_empty():
		return _reject("private_direct_action_request_fingerprint_empty")
	if _submission_fingerprint_by_id.has(submission_id):
		if str(_submission_fingerprint_by_id[submission_id]) != request_fingerprint:
			_collision_count += 1
			return _reject("private_direct_action_submission_collision")
		var replay: Dictionary = (_submitted_result_by_id.get(submission_id, {}) \
			as Dictionary).duplicate(true)
		replay["duplicate"] = true
		return replay

	var catalog_card_id: String = str(request.get("catalog_card_id", ""))
	var catalog_definition: Dictionary = _card_catalog_owner.exact_definition(catalog_card_id)
	if (
		catalog_definition.is_empty()
		or str(catalog_definition.get("kind", "")) != "military_force"
	):
		return _reject("private_direct_action_catalog_definition_not_military")
	var card_rank: int = int(_card_catalog_owner.rank(catalog_card_id))
	if card_rank < 1 or card_rank > 4:
		return _reject("private_direct_action_catalog_authority_invalid")
	var authorized_card_id := str((revalidated.get(
		"instance_decision_state", {}
	) as Dictionary).get("card_id", ""))
	var crosswalk_record: Dictionary = _military_crosswalk.record_for_card_id(
		authorized_card_id
	)
	if crosswalk_record.is_empty() \
			or str(crosswalk_record.get("mapping_status", "")) != "EXACT_MAPPED" \
			or str(crosswalk_record.get("source_card_id", "")) != authorized_card_id:
		return _reject("private_direct_action_crosswalk_binding_invalid")
	var profile_id := str(crosswalk_record.get("unit_profile_id", ""))
	var profile: Dictionary = _profile_authority.profile_by_id(profile_id)
	if profile.is_empty() \
			or not bool(_profile_authority.record_validation_report(
				profile
			).get("valid", false)) \
			or int(profile.get("rank", 0)) != card_rank:
		return _reject("private_direct_action_profile_binding_invalid")
	var mission_kind := str(request.get("mission_kind", ""))
	var target_kind := "REGION" \
		if mission_kind == MISSION_ASSAULT_REGION else "MONSTER"
	if mission_kind not in (crosswalk_record.get("allowed_missions", []) as Array) \
			or target_kind not in (crosswalk_record.get(
				"allowed_target_kinds", []
			) as Array) \
			or mission_kind not in (profile.get("allowed_missions", []) as Array) \
			or target_kind not in (profile.get("allowed_target_kinds", []) as Array):
		return _reject("private_direct_action_profile_mission_binding_invalid")
	var actor_index: int = int((
		(revalidated.get("instance_decision_state", {}) as Dictionary).get(
			"viewer_ref", {}
		) as Dictionary
	).get("actor_index", -1))
	var military_unit_uid: int = int(request.get("military_unit_uid", 0))
	var unit_index: int = int(_military_unit_state_owner.unit_index_by_uid(
		military_unit_uid
	))
	var roster: Array = _military_unit_state_owner.roster_snapshot(true)
	if (
		unit_index < 0
		or unit_index >= roster.size()
		or int((roster[unit_index] as Dictionary).get("owner", -1)) != actor_index
	):
		return _reject("private_direct_action_military_owner_binding_invalid")

	var target_face_id: int = int(request.get("target_face_id", -1))
	var target_point_result: Dictionary = GeodesicMetric.canonical_target_point(target_face_id)
	if not bool(target_point_result.get("accepted", false)):
		return _reject(str(target_point_result.get(
			"reason", "private_direct_action_target_point_invalid"
		)))
	var route_result: Dictionary = GeodesicMetric.build_route(
		int(request.get("source_face_id", -1)),
		target_face_id,
		target_point_result.get("target_point", {}) as Dictionary
	)
	if not bool(route_result.get("accepted", false)):
		return _reject(str(route_result.get(
			"reason", "private_direct_action_route_invalid"
		)))
	var route: Dictionary = route_result.get("route", {}) as Dictionary
	var total_distance_mu: int = int(route.get("total_distance_mu", 0))
	var eta_result: Dictionary = _military_eta_owner.calculate_eta({
		"schema_version": 1,
		"profile_id": profile_id,
		"expected_profile_fingerprint_sha256": str(profile.get(
			"canonical_fingerprint", ""
		)),
		"route": route.duplicate(true),
		"route_sha256": str(route_result.get("route_sha256", "")),
	})
	if not bool(eta_result.get("accepted", false)):
		return _reject(str(eta_result.get(
			"reason", "private_direct_action_military_eta_rejected"
		)))
	var eta_ticks := int(eta_result.get("eta_ticks", -1))
	var dispatch_delay_ticks := maxi(1, eta_ticks)
	var submission_tick := int(_kernel.current_tick())
	var source_claimed := false
	if _military_unit_state_owner.has_method("claim_submission"):
		var source_claim := _military_unit_state_owner.call(
			"claim_submission",
			military_unit_uid,
			submission_id,
			str(request.get("card_instance_id", "")),
			request_fingerprint
		) as Dictionary
		if not bool(source_claim.get("accepted", false)):
			return _reject(str(source_claim.get(
				"reason",
				"private_direct_action_source_claim_rejected"
			)))
		source_claimed = true

	var asset_plan: Dictionary = request.get("asset_reservation_plan", {}) as Dictionary
	var asset_commit: Dictionary = _asset_quantity_owner.commit_reservation(asset_plan)
	if not bool(asset_commit.get("committed", false)) \
		or not bool(asset_commit.get("authorized", false)):
		_release_unit_submission_claim(
			military_unit_uid,
			submission_id,
			"private_direct_action_asset_reservation_rejected",
			source_claimed
		)
		return _reject(str(asset_commit.get(
			"reason",
			"private_direct_action_asset_reservation_rejected"
		)))
	var asset_reservation_id: String = str(asset_commit.get("transaction_id", ""))
	var mission_request: Dictionary = _build_mission_request(
		request,
		str((revalidated.get("instance_decision_state", {}) as Dictionary).get(
			"instance_id", ""
		)),
		asset_reservation_id
	)
	var region_profile := profile.get("assault_region_profile", {}) as Dictionary
	var monster_profile := profile.get("assault_monster_profile", {}) as Dictionary
	var region_damage_budget := int(region_profile.get("damage_budget", 0))
	var monster_damage := int(monster_profile.get("damage", 0))
	if region_damage_budget < 1 or monster_damage < 1:
		_asset_quantity_owner.release_reservation(
			asset_reservation_id,
			"private_direct_action_profile_combat_invalid"
		)
		_release_unit_submission_claim(
			military_unit_uid,
			submission_id,
			"private_direct_action_profile_combat_invalid",
			source_claimed
		)
		return _reject("private_direct_action_profile_combat_invalid")
	var card_authority: Dictionary = MissionCore.build_card_authority(
		str((revalidated.get("instance_decision_state", {}) as Dictionary).get(
			"card_id", ""
		)),
		card_rank,
		region_damage_budget,
		monster_damage,
		str(request.get("source_effect_id", "")),
		int(asset_commit.get("revision", asset_plan.get("expected_revision", 0)))
	)
	var mission_lock: Dictionary = _build_mission_lock(
		str(request.get("mission_kind", "")),
		mission_request,
		card_authority,
		int(request.get("target_region_revision", -1)),
		request.get("public_targets", []) as Array
	)
	if not bool(MissionCore.mission_lock_validation_report(
		mission_lock
	).get("valid", false)):
		_asset_quantity_owner.release_reservation(
			asset_reservation_id,
			"private_direct_action_lock_rejected"
		)
		_release_unit_submission_claim(
			military_unit_uid,
			submission_id,
			"private_direct_action_lock_rejected",
			source_claimed
		)
		return _reject("private_direct_action_mission_lock_rejected")

	var action_payload: Dictionary = {
		"authorization_bundle_fingerprint": str(revalidated.get(
			"bundle_fingerprint", ""
		)),
		"authorized_envelope_fingerprint": str((revalidated.get(
			"authorized_envelope_ref", {}
		) as Dictionary).get("envelope_fingerprint", "")),
		"card_id": str((revalidated.get(
			"instance_decision_state", {}
		) as Dictionary).get("card_id", "")),
		"card_instance_id": str(request.get("card_instance_id", "")),
		"mission_kind": str(request.get("mission_kind", "")),
		"military_unit_uid": military_unit_uid,
		"catalog_card_id": catalog_card_id,
		"mission_lock": mission_lock,
		"current_public_targets": (
			request.get("public_targets", []) as Array
		).duplicate(true),
		"route": route.duplicate(true),
		"route_sha256": str(route_result.get("route_sha256", "")),
		"eta_receipt": (eta_result.get("receipt", {}) as Dictionary).duplicate(true),
		"asset_reservation_id": asset_reservation_id,
	}
	var payload: Dictionary = {
		"schema_version": DomainReducer.ROOT_PAYLOAD_SCHEMA_VERSION,
		"submission_id": submission_id,
		"action_kind": ACTION_KIND_MILITARY,
		"actor_id": str(request.get("actor_id", "")),
		"submission_tick": submission_tick,
		"dispatch_delay_ticks": dispatch_delay_ticks,
		"request_fingerprint": request_fingerprint,
		"action_payload": action_payload,
		"payload_fingerprint": "",
	}
	payload["payload_fingerprint"] = StateCodec.fingerprint(
		_payload_without_fingerprint(payload)
	)
	var command_id: String = "v076.private-direct-action.%s.intake" % submission_id
	var built: Dictionary = AuthorityCommand.build(
		command_id,
		DOMAIN_ID,
		COMMAND_TYPE,
		str(request.get("actor_id", "")),
		submission_tick + 1,
		DOMAIN_PRIORITY,
		int(request.get("producer_sequence", 0)),
		payload
	)
	if not bool(built.get("accepted", false)):
		_asset_quantity_owner.release_reservation(
			asset_reservation_id,
			"private_direct_action_command_build_rejected"
		)
		_release_unit_submission_claim(
			military_unit_uid,
			submission_id,
			"private_direct_action_command_build_rejected",
			source_claimed
		)
		return _reject(str(built.get(
			"reason", "private_direct_action_command_build_rejected"
		)))
	var submitted: Dictionary = _kernel.submit_command(built.get("command", {}) as Dictionary)
	if not bool(submitted.get("accepted", false)):
		_asset_quantity_owner.release_reservation(
			asset_reservation_id,
			"private_direct_action_kernel_submission_rejected"
		)
		_release_unit_submission_claim(
			military_unit_uid,
			submission_id,
			"private_direct_action_kernel_submission_rejected",
			source_claimed
		)
		return _reject(str(submitted.get(
			"reason", "private_direct_action_kernel_submission_rejected"
		)))
	var result: Dictionary = {
		"accepted": true,
		"reason": "",
		"duplicate": bool(submitted.get("duplicate", false)),
		"submission_id": submission_id,
		"command_id": command_id,
		"command_sha256": str(submitted.get("command_sha256", "")),
		"scheduled_tick": submission_tick + 1,
		"arrival_tick": submission_tick + dispatch_delay_ticks,
		"eta_ticks": eta_ticks,
		"dispatch_delay_ticks": dispatch_delay_ticks,
		"eta_receipt": (eta_result.get("receipt", {}) as Dictionary).duplicate(true),
		"eta_receipt_fingerprint": str(eta_result.get(
			"receipt_fingerprint", ""
		)),
		"profile_id": profile_id,
		"route_sha256": str(route_result.get("route_sha256", "")),
		"total_distance_mu": total_distance_mu,
		"asset_reservation_id": asset_reservation_id,
		"mission_kind": str(request.get("mission_kind", "")),
		"action_kind": ACTION_KIND_MILITARY,
	}
	_submission_fingerprint_by_id[submission_id] = request_fingerprint
	_submitted_result_by_id[submission_id] = result.duplicate(true)
	return result


func submit_private_monster_skill_direct_action(
	authorized_bundle: Dictionary,
	request: Dictionary
) -> Dictionary:
	if not _configured:
		return _reject("private_direct_action_owner_not_configured")
	var request_report := monster_skill_request_validation_report(request)
	if not bool(request_report.get("valid", false)):
		return _reject(str(request_report.get(
			"reason", "private_monster_skill_request_invalid"
		)))
	var revalidated: Dictionary = _private_monster_skill_owner.call(
		"validate_v076_private_monster_skill_bundle",
		authorized_bundle
	) as Dictionary
	if not bool(revalidated.get("accepted", false)):
		return _reject(str(revalidated.get(
			"reason_code", "private_monster_skill_revalidation_failed"
		)))
	var bundle := revalidated.get("bundle", {}) as Dictionary
	if str(bundle.get("actor_id", "")) != str(request.get("actor_id", "")):
		return _reject("private_monster_skill_actor_binding_mismatch")
	var submission_id := str(request.get("submission_id", ""))
	var request_fingerprint := StateCodec.fingerprint({
		"action_kind": ACTION_KIND_MONSTER_SKILL,
		"authorization_fingerprint": str(bundle.get(
			"authorization_fingerprint", ""
		)),
		"request": request.duplicate(true),
	})
	if request_fingerprint.is_empty():
		return _reject("private_monster_skill_request_fingerprint_empty")
	if _submission_fingerprint_by_id.has(submission_id):
		if str(_submission_fingerprint_by_id[submission_id]) \
				!= request_fingerprint:
			_collision_count += 1
			return _reject("private_direct_action_submission_collision")
		var replay := (_submitted_result_by_id.get(submission_id, {}) \
			as Dictionary).duplicate(true)
		replay["duplicate"] = true
		return replay
	var submission_tick := int(_kernel.current_tick())
	var action_payload := {
		"authorized_bundle": bundle.duplicate(true),
		"authorization_fingerprint": str(bundle.get(
			"authorization_fingerprint", ""
		)),
	}
	var payload := {
		"schema_version": DomainReducer.ROOT_PAYLOAD_SCHEMA_VERSION,
		"submission_id": submission_id,
		"action_kind": ACTION_KIND_MONSTER_SKILL,
		"actor_id": str(request.get("actor_id", "")),
		"submission_tick": submission_tick,
		"dispatch_delay_ticks": 1,
		"request_fingerprint": request_fingerprint,
		"action_payload": action_payload,
		"payload_fingerprint": "",
	}
	payload["payload_fingerprint"] = StateCodec.fingerprint(
		_payload_without_fingerprint(payload)
	)
	var command_id := "v076.private-direct-action.%s.intake" % submission_id
	var built := AuthorityCommand.build(
		command_id,
		DOMAIN_ID,
		COMMAND_TYPE,
		str(request.get("actor_id", "")),
		submission_tick + 1,
		DOMAIN_PRIORITY,
		int(request.get("producer_sequence", 0)),
		payload
	)
	if not bool(built.get("accepted", false)):
		return _reject(str(built.get(
			"reason", "private_monster_skill_command_build_rejected"
		)))
	var submitted: Dictionary = _kernel.submit_command(
		built.get("command", {}) as Dictionary
	)
	if not bool(submitted.get("accepted", false)):
		return _reject(str(submitted.get(
			"reason", "private_monster_skill_kernel_submission_rejected"
		)))
	var result := {
		"accepted": true,
		"reason": "",
		"duplicate": bool(submitted.get("duplicate", false)),
		"submission_id": submission_id,
		"action_kind": ACTION_KIND_MONSTER_SKILL,
		"command_id": command_id,
		"command_sha256": str(submitted.get("command_sha256", "")),
		"scheduled_tick": submission_tick + 1,
	}
	_submission_fingerprint_by_id[submission_id] = request_fingerprint
	_submitted_result_by_id[submission_id] = result.duplicate(true)
	return result


func settle_ready_private_actions() -> Dictionary:
	if not _configured:
		return _reject("private_direct_action_owner_not_configured")
	var state: Dictionary = _kernel.domain_state(DOMAIN_ID)
	var ledger := state.get("submission_ledger", {}) as Dictionary
	var order := state.get("submission_order", []) as Array
	var settled_receipts: Array = []
	for submission_variant in order:
		var submission_id := str(submission_variant)
		if _intake_settlement_fingerprint_by_id.has(submission_id):
			continue
		var entry := ledger.get(submission_id, {}) as Dictionary
		if entry.is_empty():
			return _reject("private_direct_action_intake_ledger_gap")
		var action_kind := str(entry.get("action_kind", ""))
		var sink_receipt: Dictionary
		if action_kind == ACTION_KIND_MILITARY:
			sink_receipt = {
				"accepted": true,
				"reason_code": "military_dispatch_ordered",
				"receipt_scope": "owner_private",
			}
		elif action_kind == ACTION_KIND_MONSTER_SKILL:
			if str(entry.get("phase", "")) \
					!= DomainReducer.PHASE_PRIVATE_SKILL_SETTLEMENT_READY:
				return _reject("private_monster_skill_settlement_not_ready")
			var root_payload := entry.get("root_payload", {}) as Dictionary
			var action_payload := root_payload.get(
				"action_payload", {}
			) as Dictionary
			sink_receipt = _private_monster_skill_owner.call(
				"consume_v076_private_monster_skill_submission",
				submission_id,
				action_payload.get("authorized_bundle", {}) as Dictionary
			) as Dictionary
			if not bool(sink_receipt.get("accepted", false)):
				return _reject(str(sink_receipt.get(
					"reason_code", "private_monster_skill_sink_rejected"
				)))
		else:
			return _reject("private_direct_action_action_kind_invalid")
		var settlement_fingerprint := StateCodec.fingerprint({
			"submission_id": submission_id,
			"action_kind": action_kind,
			"root_authority_sequence": int(entry.get(
				"root_authority_sequence", 0
			)),
			"root_payload_fingerprint": str(entry.get(
				"root_payload_fingerprint", ""
			)),
			"sink_receipt": sink_receipt.duplicate(true),
		})
		if settlement_fingerprint.is_empty():
			return _reject("private_direct_action_intake_settlement_identity_empty")
		var settlement_result := {
			"accepted": true,
			"duplicate": false,
			"submission_id": submission_id,
			"action_kind": action_kind,
			"root_authority_sequence": int(entry.get(
				"root_authority_sequence", 0
			)),
			"settlement_fingerprint": settlement_fingerprint,
			"sink_receipt": sink_receipt.duplicate(true),
		}
		_intake_settlement_fingerprint_by_id[submission_id] = (
			settlement_fingerprint
		)
		_intake_settlement_result_by_id[submission_id] = (
			settlement_result.duplicate(true)
		)
		_intake_settlement_order.append(submission_id)
		settled_receipts.append(settlement_result)
	return {
		"accepted": true,
		"reason": "",
		"settled_count": settled_receipts.size(),
		"settlement_order": _intake_settlement_order.duplicate(),
		"receipts": settled_receipts,
	}


func settle_completed_submission(submission_id: String) -> Dictionary:
	if not _configured or not _submission_fingerprint_by_id.has(submission_id):
		return _reject("private_direct_action_submission_unknown")
	var state: Dictionary = _kernel.domain_state(DOMAIN_ID)
	var ledger: Dictionary = state.get("submission_ledger", {}) as Dictionary
	if not ledger.has(submission_id):
		return _reject("private_direct_action_mission_not_arrived")
	var entry: Dictionary = ledger[submission_id] as Dictionary
	if str(entry.get("action_kind", "")) != ACTION_KIND_MILITARY:
		return _reject("private_direct_action_completed_settlement_not_military")
	if not _intake_settlement_fingerprint_by_id.has(submission_id):
		return _reject("private_direct_action_intake_not_settled")
	if str(entry.get("phase", "")) != DomainReducer.PHASE_WITHDRAWAL_READY:
		return _reject("private_direct_action_mission_withdrawal_not_ready")
	var mission_receipt: Dictionary = entry.get("mission_receipt", {}) as Dictionary
	if not bool(MissionCore.receipt_validation_report(
		mission_receipt
	).get("valid", false)):
		return _reject("private_direct_action_mission_receipt_invalid")
	var damage_input_fingerprint := StateCodec.fingerprint({
		"submission_id": submission_id,
		"mission_receipt_fingerprint": str(mission_receipt.get(
			"receipt_fingerprint", ""
		)),
		"facility_damage_intents": (
			mission_receipt.get("facility_damage_intents", []) as Array
		).duplicate(true),
		"monster_damage_intents": (
			mission_receipt.get("monster_damage_intents", []) as Array
		).duplicate(true),
	})
	var damage_settlement: Dictionary
	if _damage_settlement_by_id.has(submission_id):
		damage_settlement = (
			_damage_settlement_by_id.get(submission_id, {}) as Dictionary
		).duplicate(true)
		if str(damage_settlement.get("input_fingerprint", "")) \
				!= damage_input_fingerprint:
			_collision_count += 1
			return _reject("private_direct_action_damage_settlement_collision")
	else:
		damage_settlement = _consume_mission_damage_intents(
			entry,
			mission_receipt,
			damage_input_fingerprint
		)
		if not bool(damage_settlement.get("accepted", false)):
			return _reject(str(damage_settlement.get(
				"reason",
				"private_direct_action_damage_settlement_rejected"
			)))
		_damage_settlement_by_id[submission_id] = damage_settlement.duplicate(true)
	var settlement_fingerprint: String = StateCodec.fingerprint({
		"submission_id": submission_id,
		"receipt_fingerprint": str(mission_receipt.get(
			"receipt_fingerprint", ""
		)),
		"withdrawal_transition_fingerprint": str(entry.get(
			"last_transition_fingerprint", ""
		)),
		"damage_settlement_fingerprint": str(damage_settlement.get(
			"settlement_fingerprint", ""
		)),
	})
	if _settlement_fingerprint_by_id.has(submission_id):
		if str(_settlement_fingerprint_by_id[submission_id]) \
				!= settlement_fingerprint:
			_collision_count += 1
			return _reject("private_direct_action_settlement_collision")
		return {
			"accepted": true,
			"reason": "",
			"duplicate": true,
			"submission_id": submission_id,
			"withdrawn": true,
			"receipt_fingerprint": str(mission_receipt.get(
				"receipt_fingerprint", ""
			)),
			"damage_settlement": damage_settlement.duplicate(true),
		}
	var unit_index: int = int(_military_unit_state_owner.unit_index_by_uid(
		int(entry.get("military_unit_uid", 0))
	))
	if unit_index < 0:
		return _reject("private_direct_action_military_unit_missing_at_withdrawal")
	var asset_receipt: Dictionary = _asset_quantity_owner.consume_reservation(
		str(entry.get("asset_reservation_id", "")),
		{
			"resolved": true,
			"mission_outcome": str(mission_receipt.get("outcome", "")),
			"mission_receipt_fingerprint": str(mission_receipt.get(
				"receipt_fingerprint", ""
			)),
		}
	)
	if str(asset_receipt.get("outcome", "")) != "consumed":
		return _reject(str(asset_receipt.get(
			"reason",
			"private_direct_action_asset_settlement_rejected"
		)))
	if not _military_unit_state_owner.remove_unit(
		unit_index,
		"完成一次军事任务后撤离。"
	):
		return _reject("private_direct_action_military_withdrawal_rejected")
	var consequence_envelope := _military_consequence_envelope(
		entry,
		mission_receipt
	)
	if consequence_envelope.is_empty():
		return _reject("private_direct_action_consequence_envelope_invalid")
	var consequence_result := _facility_damage_intent_owner.call(
		"consume_v076_military_consequence",
		consequence_envelope
	) as Dictionary
	if not bool(consequence_result.get("accepted", false)):
		return _reject(str(consequence_result.get(
			"reason_code",
			"private_direct_action_consequence_consumer_rejected"
		)))
	_settlement_fingerprint_by_id[submission_id] = settlement_fingerprint
	return {
		"accepted": true,
		"reason": "",
		"duplicate": false,
		"submission_id": submission_id,
		"withdrawn": true,
		"receipt_fingerprint": str(mission_receipt.get(
			"receipt_fingerprint", ""
		)),
		"asset_outcome": str(asset_receipt.get("outcome", "")),
		"consequence_presented": not bool(consequence_result.get(
			"duplicate", false
		)),
		"damage_settlement": damage_settlement.duplicate(true),
	}


func _military_consequence_envelope(
	entry: Dictionary,
	mission_receipt: Dictionary
) -> Dictionary:
	var consequence_id := str(mission_receipt.get("combat_receipt_id", ""))
	var source_fingerprint := str(mission_receipt.get("receipt_fingerprint", ""))
	if consequence_id.is_empty() or source_fingerprint.length() != 64:
		return {}
	var envelope := {
		"schema_version": 1,
		"contract_id": "V076MilitaryProductionConsequenceEnvelopeV1",
		"consequence_id": consequence_id,
		"source_authority_sequence": int(entry.get(
			"root_authority_sequence", 0
		)),
		"execution_tick": int(entry.get("execution_tick", -1)),
		"route_sha256": str(entry.get("route_sha256", "")),
		"total_distance_mu": int(entry.get("total_distance_mu", -1)),
		"eta_ticks": int(entry.get("eta_ticks", -1)),
		"mission_receipt": mission_receipt.duplicate(true),
		"consequence_fingerprint": "",
	}
	envelope["consequence_fingerprint"] = StateCodec.fingerprint(
		_payload_without_fingerprint(envelope, "consequence_fingerprint")
	)
	return envelope


func withdrawal_ready_submission_ids() -> Array[String]:
	## Read-only bridge for the Application Flow. The Kernel remains the sole
	## tick/sequence authority; this Owner only exposes which already-executed
	## military submissions are ready for their one completion/withdrawal step.
	if not _configured:
		return []
	var state: Dictionary = _kernel.domain_state(DOMAIN_ID)
	var ledger := state.get("submission_ledger", {}) as Dictionary
	var order := state.get("submission_order", []) as Array
	var ready_ids: Array[String] = []
	for submission_variant in order:
		var submission_id := str(submission_variant)
		if _settlement_fingerprint_by_id.has(submission_id):
			continue
		var entry := ledger.get(submission_id, {}) as Dictionary
		if str(entry.get("action_kind", "")) == ACTION_KIND_MILITARY \
				and str(entry.get("phase", "")) \
				== DomainReducer.PHASE_WITHDRAWAL_READY:
			ready_ids.append(submission_id)
	return ready_ids


func _consume_mission_damage_intents(
	entry: Dictionary,
	mission_receipt: Dictionary,
	input_fingerprint: String
) -> Dictionary:
	var facility_intents := (
		mission_receipt.get("facility_damage_intents", []) as Array
	).duplicate(true)
	var monster_intents := (
		mission_receipt.get("monster_damage_intents", []) as Array
	).duplicate(true)
	if not facility_intents.is_empty() and not monster_intents.is_empty():
		return _damage_reject("private_direct_action_mixed_damage_intents")
	if monster_intents.size() > 1:
		return _damage_reject("private_direct_action_monster_damage_intent_count_invalid")
	var facility_receipts: Array = []
	var monster_receipts: Array = []
	if not facility_intents.is_empty():
		var facility_result: Dictionary = _facility_damage_intent_owner.call(
			"consume_v076_military_facility_damage_intents",
			facility_intents
		) as Dictionary
		if not bool(facility_result.get("accepted", false)):
			return _damage_reject(str(facility_result.get(
				"reason_code",
				"private_direct_action_facility_damage_sink_rejected"
			)))
		facility_receipts = (
			facility_result.get("receipts", []) as Array
		).duplicate(true)
		if facility_receipts.size() != facility_intents.size():
			return _damage_reject(
				"private_direct_action_facility_damage_receipt_count_mismatch"
			)
	for intent_index in range(monster_intents.size()):
		var intent := monster_intents[intent_index] as Dictionary
		var target_uid := _runtime_monster_uid_for_intent(entry, intent)
		if target_uid <= 0:
			return _damage_reject(
				"private_direct_action_monster_runtime_target_binding_missing"
			)
		var command := {
			"command_id": "v076.military-monster-damage.%s.%d" % [
				str(entry.get("submission_id", "")),
				intent_index,
			],
			"source": "V076 private military Direct Action",
			"source_kind": "v076_private_direct_action",
			"source_entity_id": str(intent.get("combat_receipt_id", "")),
			"unit_uid": int(entry.get("military_unit_uid", 0)),
			"target_monster_uid": target_uid,
			"damage": int(intent.get("damage_amount", 0)),
			"occurred_at_world_us": maxi(
				1,
				int(entry.get("execution_tick", 0))
					* DeterministicKernel.TICK_DURATION_US
			),
			"authority_tick": int(entry.get("execution_tick", -1)),
			"source_intent_fingerprint": str(intent.get(
				"intent_fingerprint", ""
			)),
		}
		var dispatched: Dictionary = _monster_damage_command_pipeline.call(
			"dispatch_military_monster_damage",
			command
		) as Dictionary
		if not bool(dispatched.get("handled", false)):
			return _damage_reject(str(dispatched.get(
				"reason",
				"private_direct_action_monster_damage_sink_rejected"
			)))
		var sink_receipt := dispatched.get("sink_receipt", {}) as Dictionary
		if not bool(sink_receipt.get("accepted", false)):
			return _damage_reject(
				"private_direct_action_monster_damage_receipt_invalid"
			)
		monster_receipts.append(sink_receipt.duplicate(true))
	var result := {
		"accepted": true,
		"reason": "",
		"input_fingerprint": input_fingerprint,
		"facility_intent_count": facility_intents.size(),
		"facility_receipts": facility_receipts,
		"monster_intent_count": monster_intents.size(),
		"monster_receipts": monster_receipts,
		"direct_reducer_mutation_count": 0,
		"settlement_fingerprint": "",
	}
	result["settlement_fingerprint"] = StateCodec.fingerprint(
		_payload_without_fingerprint(result, "settlement_fingerprint")
	)
	return result


func _runtime_monster_uid_for_intent(
	entry: Dictionary,
	intent: Dictionary
) -> int:
	var root_payload := entry.get("root_payload", {}) as Dictionary
	var action_payload := root_payload.get("action_payload", {}) as Dictionary
	var target_id := str(intent.get("target_monster_source_instance_id", ""))
	var expected_generation := int(intent.get("expected_source_generation", 0))
	var expected_revision := int(intent.get("observed_source_revision", -1))
	var matched_uid := 0
	for target_variant in action_payload.get("current_public_targets", []) as Array:
		if not (target_variant is Dictionary):
			continue
		var target := target_variant as Dictionary
		if str(target.get("source_instance_id", "")) != target_id \
				or int(target.get("source_generation", 0)) != expected_generation \
				or int(target.get("source_revision", -1)) != expected_revision:
			continue
		var candidate_uid := int(target.get("runtime_monster_uid", 0))
		if candidate_uid <= 0 or (matched_uid > 0 and matched_uid != candidate_uid):
			return 0
		matched_uid = candidate_uid
	return matched_uid


func _release_unit_submission_claim(
	unit_uid: int,
	submission_id: String,
	reason: String,
	claim_was_created: bool
) -> void:
	if not claim_was_created \
			or not _military_unit_state_owner.has_method(
				"release_submission_claim"
			):
		return
	_military_unit_state_owner.call(
		"release_submission_claim",
		unit_uid,
		submission_id,
		reason
	)


static func _damage_reject(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"owner_id": OWNER_ID,
		"domain_id": DOMAIN_ID,
		"configured": _configured,
		"authorized_input_envelope_owner": true,
		"own_hand_membership_revalidation_owner": true,
		"monster_source_membership_revalidation_owner": false,
		"exact_once_submission_ledger_owner": true,
		"source_collision_rejection_owner": true,
		"root_command_submission_owner": true,
		"owns_tick": false,
		"owns_authority_sequence": false,
		"owns_rng": false,
		"owns_military_unit_state": false,
		"owns_asset_quantity": false,
		"owns_map_topology": false,
		"owns_presentation": false,
		"military_consequence_owner": "V075RuntimeOwner",
		"owns_card_catalog": false,
		"owns_military_profile": false,
		"owns_physical_eta": false,
		"owns_facility_damage": false,
		"owns_monster_damage": false,
		"owns_monster_skill_state": false,
		"owns_monster_skill_catalog": false,
		"owns_monster_skill_safe_boundary": false,
		"military_profile_owner": ProfileCatalog.PROFILE_AUTHORITY_ID,
		"military_eta_owner": "V076MilitaryPhysicalEtaOwnerV1",
		"facility_damage_owner": "V075RuntimeOwner",
		"monster_damage_owner": "MonsterRuntimeController",
		"monster_skill_owner": "V075RuntimeOwner",
		"action_kinds": [ACTION_KIND_MILITARY, ACTION_KIND_MONSTER_SKILL],
		"allowed_missions": ALLOWED_MISSIONS.duplicate(),
		"forbidden_missions": FORBIDDEN_MISSIONS.duplicate(),
		"movement_mode": "PHYSICAL_GEODESIC_ETA_NO_TELEPORT",
		"completion_mode": "EXECUTE_ONE_MISSION_THEN_WITHDRAW",
		"lifecycle_phases": [
			DomainReducer.PHASE_DISPATCHED,
			DomainReducer.PHASE_PRIVATE_SKILL_SETTLEMENT_READY,
			DomainReducer.PHASE_ARRIVED,
			DomainReducer.PHASE_EXECUTED_ONCE,
			DomainReducer.PHASE_WITHDRAWAL_READY,
		],
		"submission_count": _submission_fingerprint_by_id.size(),
		"settlement_count": _settlement_fingerprint_by_id.size(),
		"damage_settlement_count": _damage_settlement_by_id.size(),
		"intake_settlement_count": _intake_settlement_fingerprint_by_id.size(),
		"intake_settlement_order": _intake_settlement_order.duplicate(),
		"collision_count": _collision_count,
		"rejection_count": _rejection_count,
		"public_batch_entry_count": 0,
		"shared_sushi_track_resolution_count": 0,
	}


static func request_validation_report(request: Dictionary) -> Dictionary:
	if not _has_exact_fields(request, REQUEST_FIELDS):
		return {"valid": false, "reason": "private_direct_action_request_shape_invalid"}
	var validation: Dictionary = StateCodec.validate(request)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get(
			"reason", "private_direct_action_request_not_closed"
		))}
	if int(request.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"valid": false, "reason": "private_direct_action_request_schema_invalid"}
	for field in [
		"submission_id", "actor_id", "catalog_card_id", "card_instance_id",
		"action_slot_id", "source_effect_id",
	]:
		if not _stable_id(request.get(field)):
			return {"valid": false, "reason": "private_direct_action_%s_invalid" % field}
	var mission_kind: String = str(request.get("mission_kind", ""))
	if mission_kind not in ALLOWED_MISSIONS or mission_kind in FORBIDDEN_MISSIONS:
		return {"valid": false, "reason": "private_direct_action_mission_forbidden"}
	for field in ["military_unit_uid"]:
		if typeof(request.get(field)) != TYPE_INT or int(request.get(field, 0)) <= 0:
			return {"valid": false, "reason": "private_direct_action_%s_invalid" % field}
	for field in [
		"source_face_id", "target_face_id", "target_region_revision",
		"producer_sequence",
	]:
		if typeof(request.get(field)) != TYPE_INT or int(request.get(field, -1)) < 0:
			return {"valid": false, "reason": "private_direct_action_%s_invalid" % field}
	if not (request.get("asset_reservation_plan") is Dictionary) \
		or not (request.get("public_targets") is Array):
		return {"valid": false, "reason": "private_direct_action_nested_contract_invalid"}
	var region_id: String = str(request.get("target_region_id", ""))
	var monster_id: String = str(request.get("target_monster_source_instance_id", ""))
	if mission_kind == MISSION_ASSAULT_REGION:
		if not _stable_id(region_id) or not monster_id.is_empty():
			return {"valid": false, "reason": "private_direct_action_region_target_invalid"}
	elif not region_id.is_empty() or not _stable_id(monster_id):
		return {"valid": false, "reason": "private_direct_action_monster_target_invalid"}
	return {"valid": true, "reason": ""}


static func monster_skill_request_validation_report(
	request: Dictionary
) -> Dictionary:
	if not _has_exact_fields(request, MONSTER_SKILL_REQUEST_FIELDS):
		return {
			"valid": false,
			"reason": "private_monster_skill_request_shape_invalid",
		}
	var validation := StateCodec.validate(request)
	if not bool(validation.get("valid", false)):
		return {
			"valid": false,
			"reason": str(validation.get(
				"reason", "private_monster_skill_request_not_closed"
			)),
		}
	if int(request.get("schema_version", 0)) != SCHEMA_VERSION:
		return {
			"valid": false,
			"reason": "private_monster_skill_request_schema_invalid",
		}
	for field in ["submission_id", "actor_id"]:
		if not _stable_id(request.get(field)):
			return {
				"valid": false,
				"reason": "private_monster_skill_%s_invalid" % field,
			}
	if typeof(request.get("producer_sequence")) != TYPE_INT \
			or int(request.get("producer_sequence", -1)) < 0:
		return {
			"valid": false,
			"reason": "private_monster_skill_producer_sequence_invalid",
		}
	return {"valid": true, "reason": ""}


func _authorization_binding_reason(bundle: Dictionary, request: Dictionary) -> String:
	var state: Dictionary = bundle.get("instance_decision_state", {}) as Dictionary
	var viewer: Dictionary = state.get("viewer_ref", {}) as Dictionary
	if str(state.get("source_kind", "")) != "own_hand" \
		or str(state.get("visibility_scope_id", "")) != "actor_private":
		return "private_direct_action_source_not_actor_private_own_hand"
	if str(viewer.get("actor_ref_id", "")) != str(request.get("actor_id", "")):
		return "private_direct_action_actor_binding_mismatch"
	if str(state.get("instance_id", "")) != str(request.get("card_instance_id", "")):
		return "private_direct_action_card_instance_binding_mismatch"
	if bool(state.get("queued", true)) or bool(state.get("locked", true)) \
		or int(state.get("cooldown_remaining_microseconds", -1)) != 0:
		return "private_direct_action_card_instance_unavailable"
	return ""


func _build_mission_request(
	request: Dictionary,
	card_instance_id: String,
	asset_reservation_id: String
) -> Dictionary:
	if str(request.get("mission_kind", "")) == MISSION_ASSAULT_REGION:
		return MissionCore.build_region_request(
			str(request.get("submission_id", "")),
			"mission.%s" % str(request.get("submission_id", "")),
			str(request.get("actor_id", "")),
			card_instance_id,
			str(request.get("action_slot_id", "")),
			asset_reservation_id,
			str(request.get("target_region_id", ""))
		)
	return MissionCore.build_monster_request(
		str(request.get("submission_id", "")),
		"mission.%s" % str(request.get("submission_id", "")),
		str(request.get("actor_id", "")),
		card_instance_id,
		str(request.get("action_slot_id", "")),
		asset_reservation_id,
		str(request.get("target_monster_source_instance_id", ""))
	)


func _build_mission_lock(
	mission_kind: String,
	mission_request: Dictionary,
	card_authority: Dictionary,
	target_region_revision: int,
	public_targets: Array
) -> Dictionary:
	if mission_kind == MISSION_ASSAULT_REGION:
		return MissionCore.lock_region_assault(
			mission_request,
			card_authority,
			target_region_revision,
			public_targets
		)
	return MissionCore.lock_monster_assault(
		mission_request,
		card_authority,
		public_targets
	)


static func _payload_without_fingerprint(
	payload: Dictionary,
	fingerprint_field: String = "payload_fingerprint"
) -> Dictionary:
	var value: Dictionary = payload.duplicate(true)
	value.erase(fingerprint_field)
	return value


static func _has_exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _stable_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING \
		and not str(value).is_empty() \
		and str(value) == str(value).strip_edges() \
		and str(value).length() <= 160


func _reject(reason: String) -> Dictionary:
	_rejection_count += 1
	return {"accepted": false, "reason": reason, "duplicate": false}
