@tool
extends Node
class_name V076PrivateDirectActionInputOwnerV1

const AuthorityCommand := preload(
	"res://scripts/v076/simulation/v076_authority_command_v1.gd"
)
const StateCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
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
const COMMAND_TYPE := DomainReducer.COMMAND_TYPE_ARRIVE
const DOMAIN_PRIORITY := 40
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

var _kernel: Variant
var _source_authorization_port: Variant
var _card_catalog_owner: Variant
var _asset_quantity_owner: Variant
var _military_unit_state_owner: Variant
var _profile_authority: Variant
var _military_eta_owner: Variant
var _military_crosswalk: Variant
var _configured := false
var _submission_fingerprint_by_id: Dictionary = {}
var _submitted_result_by_id: Dictionary = {}
var _settlement_fingerprint_by_id: Dictionary = {}
var _rejection_count := 0
var _collision_count := 0


func configure_dependencies(
	kernel: Variant,
	source_authorization_port: Variant,
	card_catalog_owner: Variant,
	asset_quantity_owner: Variant,
	military_unit_state_owner: Variant,
	profile_authority: Variant,
	military_eta_owner: Variant
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
	):
		return _reject("private_direct_action_dependency_missing")
	if not profile_authority.has_method("profile_by_id") \
			or not profile_authority.has_method("record_validation_report") \
			or not military_eta_owner.has_method("calculate_eta") \
			or not military_eta_owner.has_method("debug_snapshot"):
		return _reject("private_direct_action_military_eta_dependency_invalid")
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
		eta_owner
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

	var asset_plan: Dictionary = request.get("asset_reservation_plan", {}) as Dictionary
	var asset_commit: Dictionary = _asset_quantity_owner.commit_reservation(asset_plan)
	if not bool(asset_commit.get("committed", false)) \
		or not bool(asset_commit.get("authorized", false)):
		return _reject("private_direct_action_asset_reservation_rejected")
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
		return _reject("private_direct_action_mission_lock_rejected")

	var payload: Dictionary = {
		"schema_version": DomainReducer.ROOT_PAYLOAD_SCHEMA_VERSION,
		"submission_id": submission_id,
		"authorization_bundle_fingerprint": str(revalidated.get(
			"bundle_fingerprint", ""
		)),
		"authorized_envelope_fingerprint": str((revalidated.get(
			"authorized_envelope_ref", {}
		) as Dictionary).get("envelope_fingerprint", "")),
		"actor_id": str(request.get("actor_id", "")),
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
		"submission_tick": submission_tick,
		"dispatch_delay_ticks": dispatch_delay_ticks,
		"asset_reservation_id": asset_reservation_id,
		"request_fingerprint": request_fingerprint,
		"payload_fingerprint": "",
	}
	payload["payload_fingerprint"] = StateCodec.fingerprint(
		_payload_without_fingerprint(payload)
	)
	var command_id: String = "v076.private-direct-action.%s.arrive" % submission_id
	var built: Dictionary = AuthorityCommand.build(
		command_id,
		DOMAIN_ID,
		COMMAND_TYPE,
		str(request.get("actor_id", "")),
		submission_tick + dispatch_delay_ticks,
		DOMAIN_PRIORITY,
		int(request.get("producer_sequence", 0)),
		payload
	)
	if not bool(built.get("accepted", false)):
		_asset_quantity_owner.release_reservation(
			asset_reservation_id,
			"private_direct_action_command_build_rejected"
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
		"scheduled_tick": submission_tick + dispatch_delay_ticks,
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
	}
	_submission_fingerprint_by_id[submission_id] = request_fingerprint
	_submitted_result_by_id[submission_id] = result.duplicate(true)
	return result


func settle_completed_submission(submission_id: String) -> Dictionary:
	if not _configured or not _submission_fingerprint_by_id.has(submission_id):
		return _reject("private_direct_action_submission_unknown")
	var state: Dictionary = _kernel.domain_state(DOMAIN_ID)
	var ledger: Dictionary = state.get("submission_ledger", {}) as Dictionary
	if not ledger.has(submission_id):
		return _reject("private_direct_action_mission_not_arrived")
	var entry: Dictionary = ledger[submission_id] as Dictionary
	if str(entry.get("phase", "")) != DomainReducer.PHASE_WITHDRAWAL_READY:
		return _reject("private_direct_action_mission_withdrawal_not_ready")
	var mission_receipt: Dictionary = entry.get("mission_receipt", {}) as Dictionary
	if not bool(MissionCore.receipt_validation_report(
		mission_receipt
	).get("valid", false)):
		return _reject("private_direct_action_mission_receipt_invalid")
	var settlement_fingerprint: String = StateCodec.fingerprint({
		"submission_id": submission_id,
		"receipt_fingerprint": str(mission_receipt.get(
			"receipt_fingerprint", ""
		)),
		"withdrawal_transition_fingerprint": str(entry.get(
			"last_transition_fingerprint", ""
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
		return _reject("private_direct_action_asset_settlement_rejected")
	if not _military_unit_state_owner.remove_unit(
		unit_index,
		"完成一次军事任务后撤离。"
	):
		return _reject("private_direct_action_military_withdrawal_rejected")
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
	}


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"owner_id": OWNER_ID,
		"domain_id": DOMAIN_ID,
		"configured": _configured,
		"authorized_input_envelope_owner": true,
		"own_hand_membership_revalidation_owner": true,
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
		"owns_card_catalog": false,
		"owns_military_profile": false,
		"owns_physical_eta": false,
		"military_profile_owner": ProfileCatalog.PROFILE_AUTHORITY_ID,
		"military_eta_owner": "V076MilitaryPhysicalEtaOwnerV1",
		"allowed_missions": ALLOWED_MISSIONS.duplicate(),
		"forbidden_missions": FORBIDDEN_MISSIONS.duplicate(),
		"movement_mode": "PHYSICAL_GEODESIC_ETA_NO_TELEPORT",
		"completion_mode": "EXECUTE_ONE_MISSION_THEN_WITHDRAW",
		"lifecycle_phases": [
			DomainReducer.PHASE_ARRIVED,
			DomainReducer.PHASE_EXECUTED_ONCE,
			DomainReducer.PHASE_WITHDRAWAL_READY,
		],
		"submission_count": _submission_fingerprint_by_id.size(),
		"settlement_count": _settlement_fingerprint_by_id.size(),
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


static func _payload_without_fingerprint(payload: Dictionary) -> Dictionary:
	var value: Dictionary = payload.duplicate(true)
	value.erase("payload_fingerprint")
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
