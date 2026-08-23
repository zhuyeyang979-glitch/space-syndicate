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
			"resolution_receipts": [],
		}


class RuntimeHarness extends RuntimeOwner:
	var fixture_source := {
		"source_instance_id": "monster.v076.bundle",
		"source_generation": 1,
		"owner_player_id": "player.owner",
		"status": "active",
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
		return {
			"skill_definition_id": skill_id,
			"target_contract": {"target_kind": "self_source"},
		}

	func _public_occupied_facilities() -> Array:
		return []

	func _sync_asset_balances() -> void:
		pass

	func _sync_facility_slots() -> void:
		pass

	func _emit_local_state() -> void:
		pass


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var combat := AcceptingCombatOwner.new()
	var runtime := RuntimeHarness.new()
	root.add_child(combat)
	root.add_child(runtime)
	runtime.configure(combat)
	var parameters := {
		"source_instance_id": "monster.v076.bundle",
		"source_generation": 1,
		"skill_definition_id": "skill.monster.v076.bundle",
		"target_binding": {
			"target_kind": "monster",
			"target_id": "monster.v076.bundle",
			"target_source_generation": 1,
		},
	}
	var authorized := runtime.authorize_v076_private_monster_skill_bundle(
		"player.owner",
		parameters
	)
	_expect(bool(authorized.get("accepted", false)),
		"V075 authorizes one current source-bound private skill bundle")
	var bundle := authorized.get("bundle", {}) as Dictionary
	var validated := runtime.validate_v076_private_monster_skill_bundle(bundle)
	_expect(bool(validated.get("accepted", false)),
		"V075 revalidates the sealed bundle at the V076 consumer boundary")
	var consumed := runtime.consume_v076_private_monster_skill_submission(
		"simultaneous.bundle.001",
		bundle
	)
	_expect(bool(consumed.get("accepted", false)),
		"V075 consumes the V076-derived stable request identity")
	_expect(
		str(consumed.get("receipt_scope", "")) == "owner_private"
			and str(consumed.get("skill_definition_id", ""))
				== "skill.monster.v076.bundle",
		"the V075 acknowledgement is owner-private and typed")
	var stale := bundle.duplicate(true)
	stale["source_generation"] = 2
	var stale_result := runtime.validate_v076_private_monster_skill_bundle(stale)
	_expect(not bool(stale_result.get("accepted", true)),
		"stale source generation is rejected before the V075 safe boundary")
	var text := JSON.stringify(consumed)
	_expect(
		not text.contains("target_binding")
			and not text.contains("asset_state")
			and not text.contains("request.skill.v076"),
		"the V075 owner-private receipt does not expose target, asset, or request identity")
	print("V076_PRIVATE_MONSTER_SKILL_BUNDLE_CONTRACT_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	for failure in _failures:
		push_error(failure)
	combat.free()
	runtime.free()
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
