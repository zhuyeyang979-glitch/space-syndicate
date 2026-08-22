@tool
extends RefCounted
class_name V076PrivateDirectActionReducerV1

const AuthorityCommand := preload(
	"res://scripts/v076/simulation/v076_authority_command_v1.gd"
)
const StateCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
)
const GeodesicMetric := preload(
	"res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd"
)
const MilitaryEtaOwner := preload(
	"res://scripts/v076/military/v076_military_physical_eta_owner_v1.gd"
)
const ProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)
const MissionCore := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

const STATE_SCHEMA_VERSION := 2
const ROOT_PAYLOAD_SCHEMA_VERSION := 2
const PHASE_PAYLOAD_SCHEMA_VERSION := 1
const DOMAIN_ID := "future.private_direct_action_input"
const COMMAND_TYPE_ARRIVE := "arrive_private_military_direct_action"
const COMMAND_TYPE_EXECUTE := "execute_private_military_direct_action"
const COMMAND_TYPE_WITHDRAW := "withdraw_private_military_direct_action"
const DERIVED_COMMAND_TYPES := [COMMAND_TYPE_EXECUTE, COMMAND_TYPE_WITHDRAW]
const PHASE_ARRIVED := "ARRIVED"
const PHASE_EXECUTED_ONCE := "EXECUTED_ONCE"
const PHASE_WITHDRAWAL_READY := "WITHDRAWAL_READY"
const ROOT_PAYLOAD_FIELDS := [
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
const PHASE_PAYLOAD_FIELDS := [
	"schema_version",
	"submission_id",
	"expected_prior_phase",
	"expected_prior_transition_fingerprint",
	"root_payload_fingerprint",
]


static func initial_state() -> Dictionary:
	return {
		"schema_version": STATE_SCHEMA_VERSION,
		"owner_id": "component.v076.private_direct_action_input",
		"submission_ledger": {},
		"submission_order": [],
		"arrived_count": 0,
		"executed_once_count": 0,
		"withdrawal_ready_count": 0,
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
		"derived_only_command_types": DERIVED_COMMAND_TYPES.duplicate(),
	}


func v076_apply_command(
	state: Dictionary,
	command: Dictionary,
	_rng: Variant
) -> Dictionary:
	if str(command.get("domain_id", "")) != DOMAIN_ID:
		return _reject(state, "private_direct_action_command_domain_invalid")
	match str(command.get("command_type", "")):
		COMMAND_TYPE_ARRIVE:
			return _apply_arrival(state, command)
		COMMAND_TYPE_EXECUTE:
			return _apply_execution(state, command)
		COMMAND_TYPE_WITHDRAW:
			return _apply_withdrawal(state, command)
		_:
			return _reject(state, "private_direct_action_command_type_invalid")


static func _apply_arrival(state: Dictionary, command: Dictionary) -> Dictionary:
	var payload := command.get("payload", {}) as Dictionary
	var payload_reason := _root_payload_validation_reason(payload, command)
	if not payload_reason.is_empty():
		return _reject(state, payload_reason)
	var submission_id := str(payload.get("submission_id", ""))
	var ledger := state.get("submission_ledger", {}) as Dictionary
	if ledger.has(submission_id):
		return _reject(state, "private_direct_action_reducer_submission_collision")
	var authority_tick := int(command.get("scheduled_tick", 0))
	var arrival_transition_fingerprint := _transition_fingerprint(
		submission_id,
		PHASE_ARRIVED,
		authority_tick,
		str(command.get("command_id", "")),
		"",
		str(payload.get("payload_fingerprint", ""))
	)
	if arrival_transition_fingerprint.is_empty():
		return _reject(state, "private_direct_action_arrival_identity_empty")
	ledger[submission_id] = {
		"submission_id": submission_id,
		"phase": PHASE_ARRIVED,
		"request_fingerprint": str(payload.get("request_fingerprint", "")),
		"root_payload_fingerprint": str(payload.get("payload_fingerprint", "")),
		"root_command_id": str(command.get("command_id", "")),
		"military_unit_uid": int(payload.get("military_unit_uid", 0)),
		"asset_reservation_id": str(payload.get("asset_reservation_id", "")),
		"route_sha256": str(payload.get("route_sha256", "")),
		"total_distance_mu": int((payload.get("route", {}) as Dictionary).get(
			"total_distance_mu", 0
		)),
		"eta_ticks": int((payload.get("eta_receipt", {}) as Dictionary).get(
			"eta_ticks", 0
		)),
		"dispatch_delay_ticks": int(payload.get("dispatch_delay_ticks", 0)),
		"eta_receipt_fingerprint": str((payload.get(
			"eta_receipt", {}
		) as Dictionary).get("receipt_fingerprint", "")),
		"profile_id": str((payload.get("eta_receipt", {}) as Dictionary).get(
			"profile_id", ""
		)),
		"mission_kind": str(payload.get("mission_kind", "")),
		"root_payload": payload.duplicate(true),
		"mission_receipt": {},
		"arrival_tick": authority_tick,
		"execution_tick": -1,
		"withdrawal_ready_tick": -1,
		"execution_count": 0,
		"withdrawal_intent_count": 0,
		"transition_order": [PHASE_ARRIVED],
		"transition_fingerprints": {
			PHASE_ARRIVED: arrival_transition_fingerprint,
		},
		"last_transition_fingerprint": arrival_transition_fingerprint,
	}
	state["submission_ledger"] = ledger
	var order := state.get("submission_order", []) as Array
	order.append(submission_id)
	state["submission_order"] = order
	state["arrived_count"] = int(state.get("arrived_count", 0)) + 1
	var derived := _build_phase_command(
		command,
		COMMAND_TYPE_EXECUTE,
		PHASE_ARRIVED,
		arrival_transition_fingerprint,
		str(payload.get("payload_fingerprint", ""))
	)
	if derived.is_empty():
		return _reject(state, "private_direct_action_execute_command_build_failed")
	return _commit(
		state,
		{
			"submission_id": submission_id,
			"phase": PHASE_ARRIVED,
			"arrival_tick": authority_tick,
			"mission_execution_count": 0,
			"withdrawal_intent_count": 0,
			"transition_fingerprint": arrival_transition_fingerprint,
		},
		[derived]
	)


static func _apply_execution(state: Dictionary, command: Dictionary) -> Dictionary:
	var payload := command.get("payload", {}) as Dictionary
	var phase_reason := _phase_payload_validation_reason(
		payload, PHASE_ARRIVED
	)
	if not phase_reason.is_empty():
		return _reject(state, phase_reason)
	var submission_id := str(payload.get("submission_id", ""))
	var ledger := state.get("submission_ledger", {}) as Dictionary
	if not ledger.has(submission_id):
		return _reject(state, "private_direct_action_execution_submission_unknown")
	var entry := ledger[submission_id] as Dictionary
	var binding_reason := _phase_binding_reason(entry, payload, PHASE_ARRIVED)
	if not binding_reason.is_empty():
		return _reject(state, binding_reason)
	var root_payload := entry.get("root_payload", {}) as Dictionary
	var mission_lock := root_payload.get("mission_lock", {}) as Dictionary
	if not bool(MissionCore.mission_lock_validation_report(
		mission_lock
	).get("valid", false)):
		return _reject(state, "private_direct_action_mission_lock_invalid")
	var mission_kind := str(entry.get("mission_kind", ""))
	var mission_receipt: Dictionary = {}
	if mission_kind == "ASSAULT_REGION":
		mission_receipt = MissionCore.resolve_region_assault(
			mission_lock,
			root_payload.get("current_public_targets", []) as Array
		)
	elif mission_kind == "ASSAULT_MONSTER":
		mission_receipt = MissionCore.resolve_monster_assault(
			mission_lock,
			root_payload.get("current_public_targets", []) as Array
		)
	else:
		return _reject(state, "private_direct_action_mission_forbidden")
	if not bool(MissionCore.receipt_validation_report(
		mission_receipt
	).get("valid", false)) \
			or str(mission_receipt.get("mission_state_after", "")) != "withdrawn" \
			or int(mission_receipt.get("retarget_count", -1)) != 0 \
			or int(mission_receipt.get("persistent_source_count", -1)) != 0 \
			or int(mission_receipt.get("bound_action_count", -1)) != 0:
		return _reject(state, "private_direct_action_mission_receipt_invalid")
	var authority_tick := int(command.get("scheduled_tick", 0))
	var execution_transition_fingerprint := _transition_fingerprint(
		submission_id,
		PHASE_EXECUTED_ONCE,
		authority_tick,
		str(command.get("command_id", "")),
		str(entry.get("last_transition_fingerprint", "")),
		str(mission_receipt.get("receipt_fingerprint", ""))
	)
	if execution_transition_fingerprint.is_empty():
		return _reject(state, "private_direct_action_execution_identity_empty")
	entry["phase"] = PHASE_EXECUTED_ONCE
	entry["mission_receipt"] = mission_receipt.duplicate(true)
	entry["execution_tick"] = authority_tick
	entry["execution_count"] = int(entry.get("execution_count", 0)) + 1
	var transition_order := entry.get("transition_order", []) as Array
	transition_order.append(PHASE_EXECUTED_ONCE)
	entry["transition_order"] = transition_order
	var transition_fingerprints := entry.get(
		"transition_fingerprints", {}
	) as Dictionary
	transition_fingerprints[PHASE_EXECUTED_ONCE] = execution_transition_fingerprint
	entry["transition_fingerprints"] = transition_fingerprints
	entry["last_transition_fingerprint"] = execution_transition_fingerprint
	ledger[submission_id] = entry
	state["submission_ledger"] = ledger
	state["executed_once_count"] = int(state.get("executed_once_count", 0)) + 1
	var derived := _build_phase_command(
		command,
		COMMAND_TYPE_WITHDRAW,
		PHASE_EXECUTED_ONCE,
		execution_transition_fingerprint,
		str(entry.get("root_payload_fingerprint", ""))
	)
	if derived.is_empty():
		return _reject(state, "private_direct_action_withdraw_command_build_failed")
	return _commit(
		state,
		{
			"submission_id": submission_id,
			"phase": PHASE_EXECUTED_ONCE,
			"execution_tick": authority_tick,
			"mission_execution_count": int(entry.get("execution_count", 0)),
			"mission_receipt_fingerprint": str(mission_receipt.get(
				"receipt_fingerprint", ""
			)),
			"transition_fingerprint": execution_transition_fingerprint,
		},
		[derived]
	)


static func _apply_withdrawal(state: Dictionary, command: Dictionary) -> Dictionary:
	var payload := command.get("payload", {}) as Dictionary
	var phase_reason := _phase_payload_validation_reason(
		payload, PHASE_EXECUTED_ONCE
	)
	if not phase_reason.is_empty():
		return _reject(state, phase_reason)
	var submission_id := str(payload.get("submission_id", ""))
	var ledger := state.get("submission_ledger", {}) as Dictionary
	if not ledger.has(submission_id):
		return _reject(state, "private_direct_action_withdrawal_submission_unknown")
	var entry := ledger[submission_id] as Dictionary
	var binding_reason := _phase_binding_reason(
		entry, payload, PHASE_EXECUTED_ONCE
	)
	if not binding_reason.is_empty():
		return _reject(state, binding_reason)
	var mission_receipt := entry.get("mission_receipt", {}) as Dictionary
	if not bool(MissionCore.receipt_validation_report(
		mission_receipt
	).get("valid", false)) \
			or not bool(MissionCore.lifecycle_intents_validation_report(
				mission_receipt
			).get("valid", false)):
		return _reject(state, "private_direct_action_withdrawal_intent_invalid")
	var withdrawal_intent := mission_receipt.get(
		"military_withdrawal_intent", {}
	) as Dictionary
	if str(withdrawal_intent.get("state_after", "")) != "withdrawn" \
			or bool(withdrawal_intent.get("persistent_source_created", true)) \
			or bool(withdrawal_intent.get("bound_action_created", true)):
		return _reject(state, "private_direct_action_withdrawal_contract_invalid")
	var authority_tick := int(command.get("scheduled_tick", 0))
	var withdrawal_transition_fingerprint := _transition_fingerprint(
		submission_id,
		PHASE_WITHDRAWAL_READY,
		authority_tick,
		str(command.get("command_id", "")),
		str(entry.get("last_transition_fingerprint", "")),
		StateCodec.fingerprint(withdrawal_intent)
	)
	if withdrawal_transition_fingerprint.is_empty():
		return _reject(state, "private_direct_action_withdrawal_identity_empty")
	entry["phase"] = PHASE_WITHDRAWAL_READY
	entry["withdrawal_ready_tick"] = authority_tick
	entry["withdrawal_intent_count"] = int(entry.get(
		"withdrawal_intent_count", 0
	)) + 1
	var transition_order := entry.get("transition_order", []) as Array
	transition_order.append(PHASE_WITHDRAWAL_READY)
	entry["transition_order"] = transition_order
	var transition_fingerprints := entry.get(
		"transition_fingerprints", {}
	) as Dictionary
	transition_fingerprints[PHASE_WITHDRAWAL_READY] = (
		withdrawal_transition_fingerprint
	)
	entry["transition_fingerprints"] = transition_fingerprints
	entry["last_transition_fingerprint"] = withdrawal_transition_fingerprint
	ledger[submission_id] = entry
	state["submission_ledger"] = ledger
	state["withdrawal_ready_count"] = int(state.get(
		"withdrawal_ready_count", 0
	)) + 1
	return _commit(
		state,
		{
			"submission_id": submission_id,
			"phase": PHASE_WITHDRAWAL_READY,
			"withdrawal_ready_tick": authority_tick,
			"mission_execution_count": int(entry.get("execution_count", 0)),
			"withdrawal_intent_count": int(entry.get(
				"withdrawal_intent_count", 0
			)),
			"mission_receipt_fingerprint": str(mission_receipt.get(
				"receipt_fingerprint", ""
			)),
			"transition_fingerprint": withdrawal_transition_fingerprint,
		},
		[]
	)


static func _root_payload_validation_reason(
	payload: Dictionary,
	command: Dictionary
) -> String:
	if not _has_exact_fields(payload, ROOT_PAYLOAD_FIELDS) \
			or int(payload.get("schema_version", 0)) != ROOT_PAYLOAD_SCHEMA_VERSION:
		return "private_direct_action_payload_shape_invalid"
	var payload_without_fingerprint := payload.duplicate(true)
	payload_without_fingerprint.erase("payload_fingerprint")
	if str(payload.get("payload_fingerprint", "")) \
			!= StateCodec.fingerprint(payload_without_fingerprint):
		return "private_direct_action_payload_fingerprint_invalid"
	var route := payload.get("route", {}) as Dictionary
	if not bool(GeodesicMetric.validate_route(
		route,
		str(payload.get("route_sha256", ""))
	).get("accepted", false)):
		return "private_direct_action_route_noncanonical"
	var eta_receipt := payload.get("eta_receipt", {}) as Dictionary
	if not bool(MilitaryEtaOwner.receipt_validation_report(
		eta_receipt, route
	).get("valid", false)):
		return "private_direct_action_eta_receipt_invalid"
	var profile_authority := ProfileCatalog.new()
	var profile := profile_authority.profile_by_id(str(eta_receipt.get(
		"profile_id", ""
	)))
	if profile.is_empty() \
			or not bool(profile_authority.record_validation_report(
				profile
			).get("valid", false)) \
			or str(profile.get("canonical_fingerprint", "")) \
				!= str(eta_receipt.get("profile_fingerprint_sha256", "")) \
			or int(profile.get("speed_distance_mu_per_tick", 0)) \
				!= int(eta_receipt.get("authored_speed_distance_mu_per_tick", -1)):
		return "private_direct_action_profile_receipt_binding_invalid"
	var eta_ticks := int(eta_receipt.get("eta_ticks", -1))
	var dispatch_delay_ticks := int(payload.get("dispatch_delay_ticks", 0))
	var submission_tick := int(payload.get("submission_tick", -1))
	if eta_ticks < 0 \
			or dispatch_delay_ticks != maxi(1, eta_ticks) \
			or submission_tick < 0 \
			or int(command.get("scheduled_tick", 0)) \
				!= submission_tick + dispatch_delay_ticks:
		return "private_direct_action_eta_invalid"
	var mission_lock := payload.get("mission_lock", {}) as Dictionary
	if not bool(MissionCore.mission_lock_validation_report(
		mission_lock
	).get("valid", false)):
		return "private_direct_action_mission_lock_invalid"
	var mission_kind := str(payload.get("mission_kind", ""))
	var expected_task_kind := (
		MissionCore.TASK_ASSAULT_REGION
		if mission_kind == "ASSAULT_REGION"
		else MissionCore.TASK_ASSAULT_MONSTER
		if mission_kind == "ASSAULT_MONSTER"
		else ""
	)
	if expected_task_kind.is_empty() \
			or str(mission_lock.get("task_kind", "")) != expected_task_kind \
			or mission_kind not in (profile.get("allowed_missions", []) as Array):
		return "private_direct_action_mission_forbidden"
	var region_profile := profile.get("assault_region_profile", {}) as Dictionary
	var monster_profile := profile.get("assault_monster_profile", {}) as Dictionary
	if mission_kind == "ASSAULT_REGION":
		if int(mission_lock.get("region_strike_damage_budget", -1)) \
				!= int(region_profile.get("damage_budget", -2)) \
				or int(mission_lock.get("monster_damage", -1)) != 0:
			return "private_direct_action_profile_combat_binding_invalid"
	elif int(mission_lock.get("monster_damage", -1)) \
			!= int(monster_profile.get("damage", -2)) \
			or int(mission_lock.get("region_strike_damage_budget", -1)) != 0:
		return "private_direct_action_profile_combat_binding_invalid"
	return ""


static func _phase_payload_validation_reason(
	payload: Dictionary,
	expected_prior_phase: String
) -> String:
	if not _has_exact_fields(payload, PHASE_PAYLOAD_FIELDS) \
			or int(payload.get("schema_version", 0)) \
				!= PHASE_PAYLOAD_SCHEMA_VERSION:
		return "private_direct_action_phase_payload_shape_invalid"
	if not _stable_id(payload.get("submission_id")) \
			or str(payload.get("expected_prior_phase", "")) \
				!= expected_prior_phase \
			or str(payload.get("expected_prior_transition_fingerprint", "")).length() \
				!= 64 \
			or str(payload.get("root_payload_fingerprint", "")).length() != 64:
		return "private_direct_action_phase_payload_binding_invalid"
	return ""


static func _phase_binding_reason(
	entry: Dictionary,
	payload: Dictionary,
	expected_phase: String
) -> String:
	if str(entry.get("phase", "")) != expected_phase:
		return "private_direct_action_phase_transition_invalid"
	if str(entry.get("last_transition_fingerprint", "")) \
			!= str(payload.get("expected_prior_transition_fingerprint", "")) \
			or str(entry.get("root_payload_fingerprint", "")) \
			!= str(payload.get("root_payload_fingerprint", "")):
		return "private_direct_action_phase_lineage_invalid"
	return ""


static func _build_phase_command(
	source_command: Dictionary,
	command_type: String,
	expected_prior_phase: String,
	expected_prior_transition_fingerprint: String,
	root_payload_fingerprint: String
) -> Dictionary:
	var submission_id := str((source_command.get("payload", {}) as Dictionary).get(
		"submission_id", ""
	))
	var payload := {
		"schema_version": PHASE_PAYLOAD_SCHEMA_VERSION,
		"submission_id": submission_id,
		"expected_prior_phase": expected_prior_phase,
		"expected_prior_transition_fingerprint": (
			expected_prior_transition_fingerprint
		),
		"root_payload_fingerprint": root_payload_fingerprint,
	}
	var command_suffix := (
		"execute" if command_type == COMMAND_TYPE_EXECUTE else "withdraw"
	)
	var built := AuthorityCommand.build(
		"v076.private-direct-action.%s.%s" % [submission_id, command_suffix],
		DOMAIN_ID,
		command_type,
		str(source_command.get("actor_id", "")),
		int(source_command.get("scheduled_tick", 0)) + 1,
		int(source_command.get("domain_priority", 0)),
		int(source_command.get("authority_sequence", 0)),
		payload
	)
	return (built.get("command", {}) as Dictionary).duplicate(true) \
		if bool(built.get("accepted", false)) else {}


static func _transition_fingerprint(
	submission_id: String,
	phase: String,
	authority_tick: int,
	command_id: String,
	previous_transition_fingerprint: String,
	evidence_fingerprint: String
) -> String:
	return StateCodec.fingerprint({
		"submission_id": submission_id,
		"phase": phase,
		"authority_tick": authority_tick,
		"command_id": command_id,
		"previous_transition_fingerprint": previous_transition_fingerprint,
		"evidence_fingerprint": evidence_fingerprint,
	})


static func _commit(
	state: Dictionary,
	receipt: Dictionary,
	derived_commands: Array
) -> Dictionary:
	return {
		"accepted": true,
		"reason": "",
		"outcome": "COMMIT",
		"state": state,
		"receipt": receipt,
		"derived_commands": derived_commands,
	}


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


static func _reject(state: Dictionary, reason: String) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"outcome": "REJECT",
		"state": state,
		"receipt": {},
		"derived_commands": [],
	}
