extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)


class AcceptingCombatOwner extends Node:
	func capture_checkpoint(checkpoint_id: String) -> Dictionary:
		return {"checkpoint_id": checkpoint_id, "revision": 1}

	func request_private_skill(
		_request: Dictionary,
		asset_state: Dictionary,
		_public_facilities: Array
	) -> Dictionary:
		return {
			"accepted": true,
			"reason_code": "private_skill_safe_boundary_drained",
			"asset_state": asset_state.duplicate(true),
			"facility_damage_intents": [],
			"public_results": [],
			"resolution_receipts": [{
				"skill_definition_id": "skill.must.not.reach.telemetry",
				"future_target": "facility.must.not.reach.telemetry",
				"cooldown_remaining_batches": 3,
			}],
		}


class RuntimeHarness extends V075RuntimeOwner:
	var fixture_source := {
		"source_instance_id": "monster.owner.telemetry",
		"source_generation": 1,
		"owner_player_id": "player.owner",
		"status": "active",
		"rank": 2,
	}

	func configure(combat_owner: Node) -> void:
		_combat_owner = combat_owner
		_combat_initialized = true
		_player_ids = ["player.owner", "player.rival"]
		_asset_state = {}
		_facility_state = {}

	func _public_monster_by_id(source_id: String) -> Dictionary:
		if source_id == str(fixture_source.get("source_instance_id", "")):
			return fixture_source.duplicate(true)
		return {}

	func _owner_skill_by_id(
		_actor_id: String,
		_source_id: String,
		skill_id: String
	) -> Dictionary:
		return {"skill_definition_id": skill_id}

	func _private_skill_target_request(
		_actor_id: String,
		_source: Dictionary,
		_skill: Dictionary,
		_parameters: Dictionary
	) -> Dictionary:
		return {
			"target_kind": "self_source",
			"target_id": "monster.owner.telemetry",
			"target_source_generation": 1,
		}

	func _public_occupied_facilities() -> Array:
		return []

	func _sync_asset_balances() -> void:
		pass

	func _sync_facility_slots() -> void:
		pass

	func _emit_local_state() -> void:
		pass

	func telemetry_events() -> Array:
		return _combat_telemetry_bridge.call("recent_events", 10) as Array

	func telemetry_debug() -> Dictionary:
		return _combat_telemetry_bridge.call("debug_snapshot") as Dictionary


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var combat := AcceptingCombatOwner.new()
	var runtime := RuntimeHarness.new()
	runtime.configure(combat)
	var public_presentations: Array[Dictionary] = []
	runtime.resolution_presented.connect(func(receipt: Dictionary) -> void:
		public_presentations.append(receipt.duplicate(true))
	)
	var result := runtime.request_private_monster_skill(
		"player.owner",
		{
			"source_instance_id": "monster.owner.telemetry",
			"skill_definition_id": "skill.owner.telemetry",
			"target_facility_id": "facility.rival.future",
		}
	)
	_expect(
		bool(result.get("accepted", false))
		and str(result.get("receipt_scope", "")) == "owner_private",
		"the real runtime accepts the owner-private request"
	)
	var events := runtime.telemetry_events()
	var event := events[0] as Dictionary if events.size() == 1 else {}
	var payload := event.get("payload", {}) as Dictionary
	var payload_keys: Array[String] = []
	for key_variant in payload.keys():
		payload_keys.append(str(key_variant))
	payload_keys.sort()
	_expect(
		events.size() == 1
		and str(event.get("event_type", ""))
			== "monster_private_skill_requested"
		and payload_keys == [
			"public_reason_code",
			"request_result",
			"source_rank",
		]
		and int(payload.get("source_rank", 0)) == 2
		and str(payload.get("request_result", "")) == "accepted",
		"telemetry stores one exact allowlisted request audit"
	)
	var event_text := JSON.stringify(event)
	_expect(
		not event_text.contains("player.owner")
		and not event_text.contains("monster.owner.telemetry")
		and not event_text.contains("skill.owner.telemetry")
		and not event_text.contains("facility.rival.future")
		and not event_text.contains("cooldown")
		and not event_text.contains("future_target"),
		"telemetry stores no owner, source, skill, target, or cooldown detail"
	)
	var debug := runtime.telemetry_debug()
	_expect(
		public_presentations.is_empty()
		and int(debug.get("hidden_input_field_count", -1)) == 0
		and int(debug.get("stored_hidden_field_count", -1)) == 0
		and int(debug.get("gameplay_owner_count", -1)) == 0
		and int(debug.get("world_mutation_count", -1)) == 0,
		"request telemetry bypasses public presentation and owns no gameplay"
	)
	runtime.free()
	combat.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("V075_PRIVATE_SKILL_REQUEST_TELEMETRY_INTEGRATION_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
