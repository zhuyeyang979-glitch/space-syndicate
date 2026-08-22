@tool
extends RefCounted
class_name V076PrivateDirectActionReducerV1

const StateCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
)
const GeodesicMetric := preload(
	"res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd"
)
const MilitaryEtaOwner := preload(
	"res://scripts/v076/military/v076_military_physical_eta_owner_v1.gd"
)
const MissionCore := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

const SCHEMA_VERSION := 1
const DOMAIN_ID := "future.private_direct_action_input"
const COMMAND_TYPE := "execute_private_military_direct_action"
const PAYLOAD_FIELDS := [
	"schema_version",
	"submission_id",
	"authorization_bundle_fingerprint",
	"authorized_envelope_fingerprint",
	"actor_id",
	"card_id",
	"card_instance_id",
	"mission_kind",
	"military_unit_uid",
	"catalog_card_id",
	"mission_lock",
	"current_public_targets",
	"route",
	"route_sha256",
	"eta_receipt",
	"submission_tick",
	"dispatch_delay_ticks",
	"asset_reservation_id",
	"request_fingerprint",
	"payload_fingerprint",
]


static func initial_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"owner_id": "component.v076.private_direct_action_input",
		"submission_ledger": {},
		"submission_order": [],
		"accepted_submission_count": 0,
		"withdrawal_intent_count": 0,
	}


func v076_domain_contract(domain_id: String) -> Dictionary:
	return {
		"schema_version": 1,
		"domain_id": domain_id,
		"stateless_handler": true,
		"deterministic": true,
		"replay_safe": true,
		"external_side_effects_allowed": false,
		"owns_presentation": false,
		"derived_only_command_types": [],
	}


func v076_apply_command(
	state: Dictionary,
	command: Dictionary,
	_rng: Variant
) -> Dictionary:
	if str(command.get("domain_id", "")) != DOMAIN_ID \
		or str(command.get("command_type", "")) != COMMAND_TYPE:
		return _reject(state, "private_direct_action_command_type_invalid")
	var payload := command.get("payload", {}) as Dictionary
	if not _has_exact_fields(payload, PAYLOAD_FIELDS) \
		or int(payload.get("schema_version", 0)) != SCHEMA_VERSION:
		return _reject(state, "private_direct_action_payload_shape_invalid")
	var payload_without_fingerprint := payload.duplicate(true)
	payload_without_fingerprint.erase("payload_fingerprint")
	if str(payload.get("payload_fingerprint", "")) \
			!= StateCodec.fingerprint(payload_without_fingerprint):
		return _reject(state, "private_direct_action_payload_fingerprint_invalid")
	var route := payload.get("route", {}) as Dictionary
	if not bool(GeodesicMetric.validate_route(
		route,
		str(payload.get("route_sha256", ""))
	).get("accepted", false)):
		return _reject(state, "private_direct_action_route_noncanonical")
	var eta_receipt := payload.get("eta_receipt", {}) as Dictionary
	if not bool(MilitaryEtaOwner.receipt_validation_report(
		eta_receipt, route
	).get("valid", false)):
		return _reject(state, "private_direct_action_eta_receipt_invalid")
	var eta_ticks := int(eta_receipt.get("eta_ticks", -1))
	var dispatch_delay_ticks := int(payload.get("dispatch_delay_ticks", 0))
	var submission_tick := int(payload.get("submission_tick", -1))
	if eta_ticks < 0 \
			or dispatch_delay_ticks != maxi(1, eta_ticks) \
			or submission_tick < 0 \
			or int(command.get("scheduled_tick", 0)) \
			!= submission_tick + dispatch_delay_ticks \
			or int(command.get(
				"authority_tick", command.get("scheduled_tick", 0)
			)) != int(command.get("scheduled_tick", 0)):
		return _reject(state, "private_direct_action_eta_invalid")
	var mission_lock := payload.get("mission_lock", {}) as Dictionary
	if not bool(MissionCore.mission_lock_validation_report(
		mission_lock
	).get("valid", false)):
		return _reject(state, "private_direct_action_mission_lock_invalid")
	var mission_kind := str(payload.get("mission_kind", ""))
	var mission_receipt := {}
	if mission_kind == "ASSAULT_REGION":
		mission_receipt = MissionCore.resolve_region_assault(
			mission_lock,
			payload.get("current_public_targets", []) as Array
		)
	elif mission_kind == "ASSAULT_MONSTER":
		mission_receipt = MissionCore.resolve_monster_assault(
			mission_lock,
			payload.get("current_public_targets", []) as Array
		)
	else:
		return _reject(state, "private_direct_action_mission_forbidden")
	if not bool(MissionCore.receipt_validation_report(
		mission_receipt
	).get("valid", false)) \
		or str(mission_receipt.get("mission_state_after", "")) != "withdrawn" \
		or int(mission_receipt.get("retarget_count", -1)) != 0:
		return _reject(state, "private_direct_action_mission_receipt_invalid")
	var submission_id := str(payload.get("submission_id", ""))
	var ledger := state.get("submission_ledger", {}) as Dictionary
	if ledger.has(submission_id):
		return _reject(state, "private_direct_action_reducer_submission_collision")
	ledger[submission_id] = {
		"submission_id": submission_id,
		"request_fingerprint": str(payload.get("request_fingerprint", "")),
		"payload_fingerprint": str(payload.get("payload_fingerprint", "")),
		"command_id": str(command.get("command_id", "")),
		"military_unit_uid": int(payload.get("military_unit_uid", 0)),
		"asset_reservation_id": str(payload.get("asset_reservation_id", "")),
		"route_sha256": str(payload.get("route_sha256", "")),
		"total_distance_mu": int(route.get("total_distance_mu", 0)),
		"eta_ticks": eta_ticks,
		"dispatch_delay_ticks": dispatch_delay_ticks,
		"eta_receipt_fingerprint": str(eta_receipt.get(
			"receipt_fingerprint", ""
		)),
		"mission_kind": mission_kind,
		"mission_receipt": mission_receipt.duplicate(true),
	}
	state["submission_ledger"] = ledger
	var order := state.get("submission_order", []) as Array
	order.append(submission_id)
	state["submission_order"] = order
	state["accepted_submission_count"] = int(state.get(
		"accepted_submission_count", 0
	)) + 1
	state["withdrawal_intent_count"] = int(state.get(
		"withdrawal_intent_count", 0
	)) + 1
	return {
		"accepted": true,
		"reason": "",
		"outcome": "COMMIT",
		"state": state,
		"receipt": {
			"submission_id": submission_id,
			"mission_kind": mission_kind,
			"mission_outcome": str(mission_receipt.get("outcome", "")),
			"mission_state_after": "withdrawn",
			"retarget_count": 0,
			"route_sha256": str(payload.get("route_sha256", "")),
			"total_distance_mu": int(route.get("total_distance_mu", 0)),
			"eta_ticks": eta_ticks,
			"dispatch_delay_ticks": dispatch_delay_ticks,
			"eta_receipt_fingerprint": str(eta_receipt.get(
				"receipt_fingerprint", ""
			)),
			"mission_receipt_fingerprint": str(mission_receipt.get(
				"receipt_fingerprint", ""
			)),
		},
		"derived_commands": [],
	}


static func _has_exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _reject(state: Dictionary, reason: String) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"outcome": "REJECT",
		"state": state,
		"receipt": {},
		"derived_commands": [],
	}
