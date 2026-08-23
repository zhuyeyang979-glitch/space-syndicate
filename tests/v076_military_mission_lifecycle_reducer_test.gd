extends SceneTree

const AuthorityCommand := preload(
	"res://scripts/v076/simulation/v076_authority_command_v1.gd"
)
const StateCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
)
const Kernel := preload(
	"res://scripts/v076/simulation/v076_deterministic_kernel.gd"
)
const ReplayRunner := preload(
	"res://scripts/v076/simulation/v076_replay_runner.gd"
)
const Reducer := preload(
	"res://scripts/v076/direct_action/v076_private_direct_action_reducer_v1.gd"
)
const GeodesicMetric := preload(
	"res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd"
)
const EtaOwner := preload(
	"res://scripts/v076/military/v076_military_physical_eta_owner_v1.gd"
)
const ProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)
const MissionCore := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

const PROFILE_ID := "v075.military.air_superiority_fighter.rank_1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_zero_distance_arrive_execute_withdraw()
	_test_positive_eta_has_no_early_execution()
	_test_same_tick_order_and_replay()
	_test_tampered_authority_inputs_fail_closed()
	_test_derived_commands_cannot_be_root_inputs()
	print(
		"V076_MILITARY_MISSION_LIFECYCLE_REDUCER_TEST|status=%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_zero_distance_arrive_execute_withdraw() -> void:
	var fixture := _new_kernel(7601)
	var kernel: Variant = fixture.get("kernel")
	var built := _build_root("zero.distance", 0, 0, 1)
	var command := built.get("command", {}) as Dictionary
	_expect(
		int(built.get("eta_ticks", -1)) == 0
			and int(command.get("scheduled_tick", 0)) == 1,
		"zero physical distance keeps ETA zero while Kernel dispatch waits one tick"
	)
	_expect(
		bool(kernel.submit_command(command).get("accepted", false)),
		"one zero-distance arrival root enters the Kernel"
	)
	var arrived: Dictionary = kernel.advance_ticks(1)
	var arrived_entry := _entry(kernel, "zero.distance")
	_expect(
		bool(arrived.get("accepted", false))
			and str(arrived_entry.get("phase", "")) == Reducer.PHASE_ARRIVED
			and int(arrived_entry.get("arrival_tick", -1)) == 1
			and int(arrived_entry.get("execution_count", -1)) == 0
			and (arrived_entry.get("mission_receipt", {}) as Dictionary).is_empty(),
		"arrival tick records physical arrival without an attack"
	)
	var executed: Dictionary = kernel.advance_ticks(1)
	var executed_entry := _entry(kernel, "zero.distance")
	var mission_receipt := executed_entry.get("mission_receipt", {}) as Dictionary
	_expect(
		bool(executed.get("accepted", false))
			and str(executed_entry.get("phase", ""))
				== Reducer.PHASE_EXECUTED_ONCE
			and int(executed_entry.get("execution_tick", -1)) == 2
			and int(executed_entry.get("execution_count", 0)) == 1,
		"the next tick executes exactly one mission"
	)
	_expect(
		str(mission_receipt.get("outcome", "")) == "resolved"
			and int(mission_receipt.get("allocated_damage_total", 0))
				== int((_profile().get(
					"assault_region_profile", {}
				) as Dictionary).get("damage_budget", -1))
			and (mission_receipt.get("facility_damage_intents", []) as Array).size() == 1,
		"execution emits one Profile-authored typed attack result"
	)
	var withdrawn: Dictionary = kernel.advance_ticks(1)
	var withdrawn_entry := _entry(kernel, "zero.distance")
	_expect(
		bool(withdrawn.get("accepted", false))
			and str(withdrawn_entry.get("phase", ""))
				== Reducer.PHASE_WITHDRAWAL_READY
			and int(withdrawn_entry.get("withdrawal_ready_tick", -1)) == 3
			and int(withdrawn_entry.get("withdrawal_intent_count", 0)) == 1
			and withdrawn_entry.get("transition_order") == [
				"INTAKE_ACCEPTED",
				Reducer.PHASE_ARRIVED,
				Reducer.PHASE_EXECUTED_ONCE,
				Reducer.PHASE_WITHDRAWAL_READY,
			],
		"the third tick closes at one withdrawal-ready intent"
	)
	var execution_log: Array = kernel.execution_log()
	_expect(
		execution_log.size() == 3
			and str((execution_log[0] as Dictionary).get("command_source", "")) == "ROOT"
			and str((execution_log[1] as Dictionary).get("command_source", "")) == "DERIVED"
			and str((execution_log[2] as Dictionary).get("command_source", "")) == "DERIVED"
			and kernel.root_commands().size() == 1
			and kernel.derived_commands().size() == 2,
		"one intake root owns input while two Kernel-derived commands own phase continuation"
	)
	var domain_before_idle: Dictionary = kernel.domain_state(Reducer.DOMAIN_ID)
	var idle: Dictionary = kernel.advance_ticks(4)
	_expect(
		bool(idle.get("accepted", false))
			and kernel.domain_state(Reducer.DOMAIN_ID) == domain_before_idle
			and kernel.execution_log().size() == 3,
		"withdrawal is terminal: no repeat attack, retarget, or second withdrawal"
	)
	var replay_envelope: Dictionary = kernel.build_replay_recipe()
	var replay := ReplayRunner.new().verify(
		replay_envelope.get("recipe", {}) as Dictionary,
		str(replay_envelope.get("recipe_sha256", "")),
		{Reducer.DOMAIN_ID: Reducer}
	)
	_expect(
		str(replay.get("status", "")) == "PASS"
			and int(replay.get("root_command_count", -1)) == 1
			and int(replay.get("derived_command_count", -1)) == 2,
		"root-only replay regenerates all three lifecycle transitions"
	)
	kernel.free()


func _test_positive_eta_has_no_early_execution() -> void:
	var fixture := _new_kernel(7602)
	var kernel: Variant = fixture.get("kernel")
	var built := _build_root("positive.distance", 0, 137, 1)
	var command := built.get("command", {}) as Dictionary
	var eta_ticks := int(built.get("eta_ticks", 0))
	_expect(eta_ticks > 1, "positive geodesic route has a multi-tick ETA")
	kernel.submit_command(command)
	var early: Dictionary = kernel.advance_ticks(eta_ticks - 1)
	_expect(
		bool(early.get("accepted", false))
			and str(_entry(kernel, "positive.distance").get("phase", ""))
				== Reducer.PHASE_DISPATCHED
			and kernel.execution_log().size() == 1,
		"intake is ordered immediately while no arrival or attack occurs before ETA"
	)
	kernel.advance_ticks(1)
	var arrival_entry := _entry(kernel, "positive.distance")
	_expect(
		str(arrival_entry.get("phase", "")) == Reducer.PHASE_ARRIVED
			and int(arrival_entry.get("arrival_tick", -1)) == eta_ticks
			and (arrival_entry.get("mission_receipt", {}) as Dictionary).is_empty(),
		"positive-distance arrival is exact and still does not teleport into execution"
	)
	kernel.free()


func _test_same_tick_order_and_replay() -> void:
	var left := _run_pair(false)
	var right := _run_pair(true)
	_expect(
		str(left.get("state_sha256", "")) == str(right.get("state_sha256", ""))
			and left.get("execution_log") == right.get("execution_log"),
		"same-tick submission arrival order cannot change authority order or state"
	)
	var state := left.get("state", {}) as Dictionary
	_expect(
		state.get("submission_order") == ["order.beta", "order.alpha"]
			and int(state.get("arrived_count", 0)) == 2
			and int(state.get("executed_once_count", 0)) == 2
			and int(state.get("withdrawal_ready_count", 0)) == 2,
		"producer sequence yields stable arrival, execute, and withdrawal cardinality"
	)
	var replay_envelope := left.get("replay", {}) as Dictionary
	var replay := ReplayRunner.new().verify(
		replay_envelope.get("recipe", {}) as Dictionary,
		str(replay_envelope.get("recipe_sha256", "")),
		{Reducer.DOMAIN_ID: Reducer}
	)
	_expect(
		str(replay.get("status", "")) == "PASS"
			and int(replay.get("root_command_count", -1)) == 2
			and int(replay.get("derived_command_count", -1)) == 4,
		"same-tick pair replays from two roots into four derived transitions"
	)


func _test_tampered_authority_inputs_fail_closed() -> void:
	var valid := _build_root("tamper.route", 0, 0, 1).get(
		"command", {}
	) as Dictionary
	var route_payload := (valid.get("payload", {}) as Dictionary).duplicate(true)
	var route_action := (route_payload.get("action_payload", {}) as Dictionary).duplicate(true)
	var route := (route_action.get("route", {}) as Dictionary).duplicate(true)
	route["total_distance_mu"] = int(route.get("total_distance_mu", 0)) + 1
	route_action["route"] = route
	route_payload["action_payload"] = route_action
	_expect(
		_rejected_reason(_resign(valid, route_payload))
			== "private_direct_action_route_noncanonical",
		"re-signed route tamper fails closed"
	)

	valid = _build_root("tamper.eta", 0, 0, 1).get("command", {}) as Dictionary
	var eta_payload := (valid.get("payload", {}) as Dictionary).duplicate(true)
	var eta_action := (eta_payload.get("action_payload", {}) as Dictionary).duplicate(true)
	var eta_receipt := (eta_action.get("eta_receipt", {}) as Dictionary).duplicate(true)
	eta_receipt["eta_ticks"] = int(eta_receipt.get("eta_ticks", 0)) + 1
	eta_receipt["receipt_fingerprint"] = StateCodec.fingerprint(
		_without_field(eta_receipt, "receipt_fingerprint")
	)
	eta_action["eta_receipt"] = eta_receipt
	eta_payload["action_payload"] = eta_action
	_expect(
		_rejected_reason(_resign(valid, eta_payload))
			== "private_direct_action_eta_receipt_invalid",
		"re-signed ETA formula tamper fails closed"
	)

	valid = _build_root("tamper.profile", 0, 0, 1).get("command", {}) as Dictionary
	var profile_payload := (valid.get("payload", {}) as Dictionary).duplicate(true)
	var profile_action := (profile_payload.get("action_payload", {}) as Dictionary).duplicate(true)
	var profile_receipt := (profile_action.get("eta_receipt", {}) as Dictionary).duplicate(true)
	profile_receipt["profile_id"] = "forged.profile"
	profile_receipt["profile_fingerprint_sha256"] = "0".repeat(64)
	profile_receipt["receipt_fingerprint"] = StateCodec.fingerprint(
		_without_field(profile_receipt, "receipt_fingerprint")
	)
	profile_action["eta_receipt"] = profile_receipt
	profile_payload["action_payload"] = profile_action
	_expect(
		_rejected_reason(_resign(valid, profile_payload))
			== "private_direct_action_profile_receipt_binding_invalid",
		"re-signed Profile identity tamper fails against the unique Profile Authority"
	)

	valid = _build_root("tamper.mission", 0, 0, 1).get("command", {}) as Dictionary
	var mission_payload := (valid.get("payload", {}) as Dictionary).duplicate(true)
	var mission_action := (mission_payload.get("action_payload", {}) as Dictionary).duplicate(true)
	mission_action["mission_kind"] = "GUARD"
	mission_payload["action_payload"] = mission_action
	_expect(
		_rejected_reason(_resign(valid, mission_payload))
			== "private_direct_action_mission_forbidden",
		"GUARD cannot enter the lifecycle through a re-signed root"
	)


func _test_derived_commands_cannot_be_root_inputs() -> void:
	var fixture := _new_kernel(7605)
	var kernel: Variant = fixture.get("kernel")
	var forged := AuthorityCommand.build(
		"forged.execute.root",
		Reducer.DOMAIN_ID,
		Reducer.COMMAND_TYPE_EXECUTE,
		"player.1",
		1,
		40,
		1,
		{
			"schema_version": Reducer.PHASE_PAYLOAD_SCHEMA_VERSION,
			"submission_id": "forged.execute",
			"expected_prior_phase": Reducer.PHASE_ARRIVED,
			"expected_prior_transition_fingerprint": "0".repeat(64),
			"root_payload_fingerprint": "1".repeat(64),
		}
	)
	var rejected: Dictionary = kernel.submit_command(
		forged.get("command", {}) as Dictionary
	)
	_expect(
		not bool(rejected.get("accepted", true))
			and str(rejected.get("reason", ""))
				== "root_command_type_reserved_for_derived",
		"execute and withdraw phase commands cannot be injected as a second root source"
	)
	kernel.free()


func _new_kernel(seed: int) -> Dictionary:
	var kernel := Kernel.new()
	var configured := kernel.configure(seed)
	var registered := kernel.register_domain(
		Reducer.DOMAIN_ID,
		Reducer.initial_state(),
		Reducer
	)
	_expect(
		bool(configured.get("accepted", false))
			and bool(registered.get("accepted", false)),
		"lifecycle reducer registers under the existing private input Owner"
	)
	return {"kernel": kernel}


func _build_root(
	submission_id: String,
	source_face_id: int,
	target_face_id: int,
	producer_sequence: int
) -> Dictionary:
	var profile := _profile()
	var target_point := GeodesicMetric.canonical_target_point(target_face_id)
	var route_result := GeodesicMetric.build_route(
		source_face_id,
		target_face_id,
		target_point.get("target_point", {}) as Dictionary
	)
	var route := route_result.get("route", {}) as Dictionary
	var eta_owner := EtaOwner.new()
	eta_owner.configure(ProfileCatalog.new())
	var eta := eta_owner.calculate_eta({
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"expected_profile_fingerprint_sha256": str(profile.get(
			"canonical_fingerprint", ""
		)),
		"route": route.duplicate(true),
		"route_sha256": str(route_result.get("route_sha256", "")),
	})
	eta_owner.free()
	var request := MissionCore.build_region_request(
		"request.%s" % submission_id,
		"mission.%s" % submission_id,
		"player.1",
		"card.%s" % submission_id,
		"slot.%s" % submission_id,
		"reservation.%s" % submission_id,
		"region.007"
	)
	var card_authority := MissionCore.build_card_authority(
		"unit.military.air_superiority_fighter.rank_1",
		int(profile.get("rank", 0)),
		int((profile.get("assault_region_profile", {}) as Dictionary).get(
			"damage_budget", 0
		)),
		int((profile.get("assault_monster_profile", {}) as Dictionary).get(
			"damage", 0
		)),
		"effect.%s" % submission_id,
		1
	)
	var targets := [{
		"facility_id": "facility.%s" % submission_id,
		"facility_generation": 1,
		"owner_player_id": "player.2",
		"region_id": "region.007",
		"facility_type": "factory",
		"industry_id": "energy",
		"status": "active",
	}]
	var mission_lock := MissionCore.lock_region_assault(
		request, card_authority, 1, targets
	)
	var eta_ticks := int(eta.get("eta_ticks", -1))
	var dispatch_delay_ticks := maxi(1, eta_ticks)
	var payload := {
		"schema_version": Reducer.ROOT_PAYLOAD_SCHEMA_VERSION,
		"submission_id": submission_id,
		"action_kind": Reducer.ACTION_KIND_MILITARY,
		"actor_id": "player.1",
		"submission_tick": 0,
		"dispatch_delay_ticks": dispatch_delay_ticks,
		"request_fingerprint": StateCodec.fingerprint({
			"request": submission_id,
		}),
		"action_payload": {
		"authorization_bundle_fingerprint": StateCodec.fingerprint({
			"bundle": submission_id,
		}),
		"authorized_envelope_fingerprint": StateCodec.fingerprint({
			"envelope": submission_id,
		}),
		"card_id": "unit.military.air_superiority_fighter.rank_1",
		"card_instance_id": "card.%s" % submission_id,
		"mission_kind": "ASSAULT_REGION",
		"military_unit_uid": producer_sequence,
		"catalog_card_id": "制空战斗机1",
		"mission_lock": mission_lock,
		"current_public_targets": targets,
		"route": route.duplicate(true),
		"route_sha256": str(route_result.get("route_sha256", "")),
		"eta_receipt": (eta.get("receipt", {}) as Dictionary).duplicate(true),
		"asset_reservation_id": "reservation.%s" % submission_id,
		},
		"payload_fingerprint": "",
	}
	payload["payload_fingerprint"] = StateCodec.fingerprint(
		_without_field(payload, "payload_fingerprint")
	)
	var built := AuthorityCommand.build(
		"v076.private-direct-action.%s.intake" % submission_id,
		Reducer.DOMAIN_ID,
		Reducer.COMMAND_TYPE_INTAKE,
		"player.1",
		1,
		40,
		producer_sequence,
		payload
	)
	return {
		"command": (built.get("command", {}) as Dictionary).duplicate(true),
		"eta_ticks": eta_ticks,
	}


func _run_pair(reverse_submission: bool) -> Dictionary:
	var fixture := _new_kernel(7603)
	var kernel: Variant = fixture.get("kernel")
	var alpha := _build_root("order.alpha", 0, 0, 2).get(
		"command", {}
	) as Dictionary
	var beta := _build_root("order.beta", 0, 0, 1).get(
		"command", {}
	) as Dictionary
	var commands := [beta, alpha] if reverse_submission else [alpha, beta]
	for command_variant in commands:
		kernel.submit_command(command_variant as Dictionary)
	kernel.advance_ticks(3)
	var replay: Dictionary = kernel.build_replay_recipe()
	var result := {
		"state_sha256": kernel.state_fingerprint(),
		"state": kernel.domain_state(Reducer.DOMAIN_ID),
		"execution_log": kernel.execution_log(),
		"replay": replay,
	}
	kernel.free()
	return result


func _rejected_reason(command: Dictionary) -> String:
	var fixture := _new_kernel(7604)
	var kernel: Variant = fixture.get("kernel")
	var submitted: Dictionary = kernel.submit_command(command)
	if not bool(submitted.get("accepted", false)):
		kernel.free()
		return str(submitted.get("reason", ""))
	kernel.advance_ticks(int(command.get("scheduled_tick", 0)))
	var execution_log: Array = kernel.execution_log()
	var reason := ""
	if not execution_log.is_empty():
		reason = str((execution_log.back() as Dictionary).get(
			"fizzle_reason", ""
		))
	kernel.free()
	return reason


func _resign(command: Dictionary, payload: Dictionary) -> Dictionary:
	var resigned_payload := payload.duplicate(true)
	resigned_payload["payload_fingerprint"] = StateCodec.fingerprint(
		_without_field(resigned_payload, "payload_fingerprint")
	)
	var built := AuthorityCommand.build(
		str(command.get("command_id", "")),
		str(command.get("domain_id", "")),
		str(command.get("command_type", "")),
		str(command.get("actor_id", "")),
		int(command.get("scheduled_tick", 0)),
		int(command.get("domain_priority", 0)),
		int(command.get("producer_sequence", 0)),
		resigned_payload
	)
	return (built.get("command", {}) as Dictionary).duplicate(true)


func _entry(kernel: Variant, submission_id: String) -> Dictionary:
	var state: Dictionary = kernel.domain_state(Reducer.DOMAIN_ID)
	return ((state.get("submission_ledger", {}) as Dictionary).get(
		submission_id, {}
	) as Dictionary).duplicate(true)


func _profile() -> Dictionary:
	return ProfileCatalog.new().profile_by_id(PROFILE_ID)


func _without_field(value: Dictionary, field: String) -> Dictionary:
	var result := value.duplicate(true)
	result.erase(field)
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
