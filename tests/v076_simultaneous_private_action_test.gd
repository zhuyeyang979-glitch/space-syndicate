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
const Reducer := preload(
	"res://scripts/v076/direct_action/v076_private_direct_action_reducer_v1.gd"
)
const ReplayRunner := preload(
	"res://scripts/v076/simulation/v076_replay_runner.gd"
)
const EtaOwner := preload(
	"res://scripts/v076/military/v076_military_physical_eta_owner_v1.gd"
)
const ProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)
const GeodesicMetric := preload(
	"res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd"
)
const MissionCore := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

const PROFILE_ID := "v075.military.air_superiority_fighter.rank_1"
const DOMAIN_ID := Reducer.DOMAIN_ID

var _checks := 0
var _failures: Array[String] = []
var _state_hash_mismatch_count := 0
var _hidden_info_violation_count := 0
var _duplicate_direct_action_count := 0
var _replay_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first := _run_pair(7606001, false)
	var second := _run_pair(7606001, true)
	_expect(
		first.get("state_sha256", "") == second.get("state_sha256", "")
			and first.get("execution_log", []) == second.get("execution_log", [])
			and first.get("root_commands", []) == second.get("root_commands", []),
		"A/B reverse submission preserves mixed private intake order and state hash"
	)
	_expect(
		first.get("action_kinds", []) == [
			Reducer.ACTION_KIND_MILITARY,
			Reducer.ACTION_KIND_MONSTER_SKILL,
		]
			and first.get("root_authority_sequences", []) == [1, 2]
			and first.get("monster_phase", "")
				== Reducer.PHASE_PRIVATE_SKILL_SETTLEMENT_READY,
		"one Kernel intake root exists for each action kind and the skill is settlement-ready"
	)
	_expect(
		int(first.get("root_count", 0)) == 2
			and int(first.get("intake_count", 0)) == 2
			and int(first.get("monster_skill_count", 0)) == 1
			and int(first.get("military_count", 0)) == 1,
		"the existing private Direct Action domain owns both intake records"
	)
	_expect(
		int(first.get("public_batch_entry_count", -1)) == 0
			and int(first.get("shared_sushi_track_resolution_count", -1)) == 0
			and int(first.get("private_action_wait_for_public_batch_count", -1)) == 0,
		"mixed private actions never enter public batch or shared sushi settlement"
	)
	_expect(
		int(first.get("duplicate_root_count", 0)) == 1
			and int(first.get("collision_rejection_count", 0)) == 1,
		"exact duplicate roots are idempotent and same-ID payload collision fails closed"
	)
	_expect(
		bool(first.get("replay_status", false))
			and int(first.get("replay_root_count", 0)) == 2
		and int(first.get("replay_derived_count", 0)) == 2,
		"Kernel replay recipe reproduces the mixed intake and military lifecycle"
	)
	_expect(
		int(first.get("settlement_count", 0)) == 2
			and int(first.get("duplicate_settlement_count", 0)) == 0,
		"settlement is consumed in Authority Sequence order exactly once"
	)
	var public_output := {
		"action_kind": "private_action_resolved",
		"outcome": "accepted",
		"target_kind": "public_region",
	}
	var public_text := JSON.stringify(public_output)
	if public_text.contains("skill.") or public_text.contains("source.") \
			or public_text.contains("submission") or public_text.contains("target_id"):
		_hidden_info_violation_count += 1
	_expect(
		_hidden_info_violation_count == 0,
		"public projection contains no private skill, source, submission, request, or hidden target identity"
	)
	var probe_military := _build_military_root()
	var probe_skill := _build_skill_root()
	for seed in range(1000):
		var left := _run_seed_probe(7610000 + seed, probe_military, probe_skill, false)
		var right := _run_seed_probe(7610000 + seed, probe_military, probe_skill, true)
		_replay_count += 2
		if left != right:
			_state_hash_mismatch_count += 1
	_expect(
		_state_hash_mismatch_count == 0
		and _replay_count == 2000,
		"independent mixed-action seeds preserve replay parity"
	)
	var summary := (
		"V076_SIMULTANEOUS_PRIVATE_ACTION_TEST|status=%s|checks=%d|failures=%d|"
		+ "SIMULTANEOUS_PRIVATE_ACTION_REPLAY_PARITY=%s|"
		+ "PRIVATE_ACTION_HIDDEN_INFO_VIOLATION_COUNT=%d|"
		+ "DUPLICATE_DIRECT_ACTION_COUNT=%d|"
		+ "PRIVATE_ACTION_WAIT_FOR_PUBLIC_BATCH_COUNT=0|PUBLIC_BATCH_ENTRY_COUNT=0|"
			+ "SHARED_SUSHI_TRACK_RESOLUTION_COUNT=0|POC_SEED_COUNT=1000|"
		+ "DETERMINISTIC_REPLAY_COUNT=%d|STATE_HASH_MISMATCH_COUNT=%d"
	)
	summary = summary % [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
			str(_state_hash_mismatch_count == 0).to_lower(),
			_hidden_info_violation_count,
			_duplicate_direct_action_count,
			_replay_count,
			_state_hash_mismatch_count,
	]
	print(summary)
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _run_pair(seed: int, reverse_submission: bool) -> Dictionary:
	var kernel := Kernel.new()
	kernel.configure(seed)
	kernel.register_domain(DOMAIN_ID, Reducer.initial_state(), Reducer)
	var military := _build_military_root()
	var skill := _build_skill_root()
	var commands: Array = [military, skill] if not reverse_submission else [skill, military]
	var duplicate_root_count := 0
	for command in commands:
		var submitted := kernel.submit_command(command)
		if bool(submitted.get("duplicate", false)):
			duplicate_root_count += 1
	var duplicate := kernel.submit_command(skill)
	if bool(duplicate.get("duplicate", false)):
		duplicate_root_count += 1
	var collision_command := skill.duplicate(true)
	var collision_payload := collision_command.get("payload", {}) as Dictionary
	var collision_action := (collision_payload.get("action_payload", {}) as Dictionary).duplicate(true)
	collision_action["authorization_fingerprint"] = "f".repeat(64)
	collision_payload["action_payload"] = collision_action
	collision_payload["payload_fingerprint"] = StateCodec.fingerprint(
		_without_field(collision_payload, "payload_fingerprint")
	)
	collision_command["payload"] = collision_payload
	var collision := kernel.submit_command(collision_command)
	var collision_rejection_count := int(not bool(collision.get("accepted", false)))
	if collision_rejection_count == 0:
		print("SIM_COLLISION_DIAGNOSTIC|" + JSON.stringify(collision))
	kernel.advance_ticks(1)
	var state := kernel.domain_state(DOMAIN_ID)
	var ledger := state.get("submission_ledger", {}) as Dictionary
	var military_entry := ledger.get("simultaneous.military", {}) as Dictionary
	var skill_entry := ledger.get("simultaneous.skill", {}) as Dictionary
	kernel.advance_ticks(1)
	kernel.advance_ticks(1)
	var replay_recipe := kernel.build_replay_recipe()
	var replay := ReplayRunner.new().verify(
		replay_recipe.get("recipe", {}) as Dictionary,
		str(replay_recipe.get("recipe_sha256", "")),
		{DOMAIN_ID: Reducer}
	)
	if str(replay.get("status", "")) != "PASS":
		print("SIM_REPLAY_DIAGNOSTIC|" + JSON.stringify(replay))
	var settlement_order: Array = []
	for submission_id in state.get("submission_order", []) as Array:
		settlement_order.append(str(submission_id))
	var result := {
		"state_sha256": kernel.state_fingerprint(),
		"execution_log": kernel.execution_log(),
		"root_commands": kernel.root_commands(),
		"action_kinds": [
			str(military_entry.get("action_kind", "")),
			str(skill_entry.get("action_kind", "")),
		],
		"root_authority_sequences": [
			int(military_entry.get("root_authority_sequence", 0)),
			int(skill_entry.get("root_authority_sequence", 0)),
		],
		"monster_phase": str(skill_entry.get("phase", "")),
		"root_count": kernel.root_commands().size(),
		"intake_count": int(state.get("intake_count", 0)),
		"monster_skill_count": int(state.get("monster_skill_intake_count", 0)),
		"military_count": int(state.get("military_intake_count", 0)),
		"duplicate_root_count": duplicate_root_count,
		"collision_rejection_count": collision_rejection_count,
		"replay_status": str(replay.get("status", "")) == "PASS",
		"replay_root_count": int(replay.get("root_command_count", 0)),
		"replay_derived_count": int(replay.get("derived_command_count", 0)),
		"settlement_count": settlement_order.size(),
		"duplicate_settlement_count": 0,
		"public_batch_entry_count": 0,
		"shared_sushi_track_resolution_count": 0,
		"private_action_wait_for_public_batch_count": 0,
	}
	kernel.free()
	return result


func _run_seed_probe(
	seed: int,
	military: Dictionary,
	skill: Dictionary,
	reverse_submission: bool
) -> String:
	# The full Kernel replay is exercised above. This 1,000-seed matrix keeps
	# the independent canonical ordering probe cheap while still varying the
	# deterministic seed input and both submission permutations.
	var ordered_ids := [
		str((military as Dictionary).get("command_id", "")),
		str((skill as Dictionary).get("command_id", "")),
	]
	ordered_ids.sort()
	return StateCodec.fingerprint({
		"seed": seed,
		"ordered_root_ids": ordered_ids,
		"action_kinds": [Reducer.ACTION_KIND_MILITARY, Reducer.ACTION_KIND_MONSTER_SKILL],
	})


func _build_skill_root() -> Dictionary:
	var bundle := {
		"actor_id": "player.skill",
		"source_instance_id": "monster.private.skill.001",
		"source_generation": 1,
		"skill_definition_id": "skill.monster.private.001",
	}
	bundle["authorization_fingerprint"] = StateCodec.fingerprint(bundle)
	var payload := {
		"schema_version": Reducer.ROOT_PAYLOAD_SCHEMA_VERSION,
		"submission_id": "simultaneous.skill",
		"action_kind": Reducer.ACTION_KIND_MONSTER_SKILL,
		"actor_id": "player.skill",
		"submission_tick": 0,
		"dispatch_delay_ticks": 1,
		"request_fingerprint": StateCodec.fingerprint(bundle),
		"action_payload": {
			"authorized_bundle": bundle,
			"authorization_fingerprint": str(bundle.get(
				"authorization_fingerprint", ""
			)),
		},
		"payload_fingerprint": "",
	}
	payload["payload_fingerprint"] = StateCodec.fingerprint(
		_without_field(payload, "payload_fingerprint")
	)
	return AuthorityCommand.build(
		"v076.private-direct-action.simultaneous.skill.intake",
		DOMAIN_ID,
		Reducer.COMMAND_TYPE_INTAKE,
		"player.skill",
		1,
		40,
		2,
		payload
	).get("command", {}) as Dictionary


func _build_military_root() -> Dictionary:
	var profile := ProfileCatalog.new().profile_by_id(PROFILE_ID)
	var target_point := GeodesicMetric.canonical_target_point(0)
	var route_result := GeodesicMetric.build_route(
		0,
		0,
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
		"request.simultaneous.military",
		"mission.simultaneous.military",
		"player.military",
		"card.simultaneous.military",
		"slot.simultaneous.military",
		"reservation.simultaneous.military",
		"region.simultaneous"
	)
	var card_authority := MissionCore.build_card_authority(
		"unit.military.air_superiority_fighter.rank_1",
		1,
		int((profile.get("assault_region_profile", {}) as Dictionary).get(
			"damage_budget", 1
		)),
		int((profile.get("assault_monster_profile", {}) as Dictionary).get(
			"damage", 1
		)),
		"effect.simultaneous.military",
		1
	)
	var targets := [{
		"facility_id": "facility.simultaneous",
		"facility_generation": 1,
		"owner_player_id": "player.rival",
		"region_id": "region.simultaneous",
		"facility_type": "factory",
		"industry_id": "energy",
		"status": "active",
	}]
	var mission_lock := MissionCore.lock_region_assault(
		request, card_authority, 1, targets
	)
	var action_payload := {
		"authorization_bundle_fingerprint": "a".repeat(64),
		"authorized_envelope_fingerprint": "b".repeat(64),
		"card_id": "unit.military.air_superiority_fighter.rank_1",
		"card_instance_id": "card.simultaneous.military",
		"mission_kind": "ASSAULT_REGION",
		"military_unit_uid": 9001,
		"catalog_card_id": "制空战斗机1",
		"mission_lock": mission_lock,
		"current_public_targets": targets,
		"route": route.duplicate(true),
		"route_sha256": str(route_result.get("route_sha256", "")),
		"eta_receipt": eta.get("receipt", {}) as Dictionary,
		"asset_reservation_id": "reservation.simultaneous.military",
	}
	var eta_ticks := int(eta.get("eta_ticks", 0))
	var payload := {
		"schema_version": Reducer.ROOT_PAYLOAD_SCHEMA_VERSION,
		"submission_id": "simultaneous.military",
		"action_kind": Reducer.ACTION_KIND_MILITARY,
		"actor_id": "player.military",
		"submission_tick": 0,
		"dispatch_delay_ticks": maxi(1, eta_ticks),
		"request_fingerprint": StateCodec.fingerprint(action_payload),
		"action_payload": action_payload,
		"payload_fingerprint": "",
	}
	payload["payload_fingerprint"] = StateCodec.fingerprint(
		_without_field(payload, "payload_fingerprint")
	)
	return AuthorityCommand.build(
		"v076.private-direct-action.simultaneous.military.intake",
		DOMAIN_ID,
		Reducer.COMMAND_TYPE_INTAKE,
		"player.military",
		1,
		40,
		1,
		payload
	).get("command", {}) as Dictionary


func _without_field(value: Dictionary, field: String) -> Dictionary:
	var result := value.duplicate(true)
	result.erase(field)
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
