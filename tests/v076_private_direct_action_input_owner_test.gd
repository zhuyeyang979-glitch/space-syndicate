extends SceneTree

const Owner := preload(
	"res://scripts/v076/direct_action/v076_private_direct_action_input_owner_v1.gd"
)
const Reducer := preload(
	"res://scripts/v076/direct_action/v076_private_direct_action_reducer_v1.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := Owner.new()
	var debug := owner.debug_snapshot()
	_expect(debug.get("allowed_missions") == ["ASSAULT_REGION", "ASSAULT_MONSTER"],
		"the Owner exposes exactly the two authorized missions")
	_expect(debug.get("forbidden_missions") == ["GUARD", "PROTECT"],
		"guard and protect are explicit negative capabilities")
	_expect(
		not bool(debug.get("owns_tick", true))
			and not bool(debug.get("owns_authority_sequence", true))
			and not bool(debug.get("owns_rng", true))
			and not bool(debug.get("owns_military_unit_state", true))
			and not bool(debug.get("owns_asset_quantity", true))
			and not bool(debug.get("owns_map_topology", true))
			and not bool(debug.get("owns_presentation", true))
			and not bool(debug.get("owns_card_catalog", true)),
		"the private Owner does not claim an inherited authority surface"
	)
	_expect(
		int(debug.get("public_batch_entry_count", -1)) == 0
			and int(debug.get("shared_sushi_track_resolution_count", -1)) == 0,
		"the private Owner has no public batch or sushi-track entry")
	var reducer := Reducer.new()
	var contract := reducer.v076_domain_contract(Owner.DOMAIN_ID)
	_expect(
		bool(contract.get("stateless_handler", false))
			and bool(contract.get("deterministic", false))
			and bool(contract.get("replay_safe", false))
			and not bool(contract.get("external_side_effects_allowed", true))
			and not bool(contract.get("owns_presentation", true)),
		"the Kernel reducer remains pure and presentation-free"
	)
	var invalid := _valid_request()
	invalid["mission_kind"] = "GUARD"
	_expect(
		not bool(Owner.request_validation_report(invalid).get("valid", true)),
		"GUARD fails before authorization or root submission"
	)
	invalid["mission_kind"] = "PROTECT"
	_expect(
		not bool(Owner.request_validation_report(invalid).get("valid", true)),
		"PROTECT fails before authorization or root submission"
	)
	owner.free()
	print("V076_PRIVATE_DIRECT_ACTION_INPUT_OWNER_TEST|checks=%d|failures=%d" % [
		_checks, _failures.size()
	])
	for failure in _failures:
		push_error(str(failure))
	quit(0 if _failures.is_empty() else 1)


func _valid_request() -> Dictionary:
	return {
		"schema_version": 1,
		"submission_id": "test.private.action.001",
		"actor_id": "player.1",
		"mission_kind": "ASSAULT_REGION",
		"military_unit_uid": 1,
		"catalog_card_id": "制空战斗机1",
		"card_instance_id": "fixture:test:military:01",
		"action_slot_id": "action.slot.test.001",
		"asset_reservation_plan": {},
		"source_face_id": 0,
		"target_face_id": 1,
		"speed_mu_per_tick": 50_000,
		"target_region_id": "region.001",
		"target_monster_source_instance_id": "",
		"target_region_revision": 1,
		"public_targets": [],
		"source_effect_id": "effect.test.001",
		"producer_sequence": 1,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
