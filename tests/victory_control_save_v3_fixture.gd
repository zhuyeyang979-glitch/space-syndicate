extends RefCounted
class_name VictoryControlSaveV3Fixture

const CONTROLLER_SCENE := preload("res://scenes/runtime/VictoryControlRuntimeController.tscn")
const STRICT_STATE := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")
const POST_SETTLEMENT_CHECKPOINT := "post_world_settlement"


class FreshWorldBridgeStub:
	extends Node

	var capture_count := 0
	var issued: Dictionary = {}

	func issue(snapshot: Dictionary) -> Dictionary:
		capture_count += 1
		var result := snapshot.duplicate(true)
		var ordering: Dictionary = result.get("ordering_receipt", {}) \
				if result.get("ordering_receipt", {}) is Dictionary else {}
		ordering["capture_sequence"] = capture_count
		ordering.erase("capture_fingerprint")
		result["ordering_receipt"] = ordering
		var fingerprint := _fingerprint(result)
		ordering["capture_fingerprint"] = fingerprint
		result["ordering_receipt"] = ordering
		issued[capture_count] = fingerprint
		return result

	func debug_snapshot() -> Dictionary:
		return {"capture_count": capture_count}

	func is_fresh_snapshot_after_restore(snapshot: Dictionary, capture_floor: int) -> bool:
		var ordering: Dictionary = snapshot.get("ordering_receipt", {}) \
				if snapshot.get("ordering_receipt", {}) is Dictionary else {}
		if not (ordering.get("capture_sequence") is int) \
				or not (ordering.get("capture_fingerprint") is String):
			return false
		var sequence := int(ordering.get("capture_sequence", 0))
		var fingerprint := str(ordering.get("capture_fingerprint", ""))
		return sequence > capture_floor \
				and str(issued.get(sequence, "")) == fingerprint \
				and fingerprint == _fingerprint(snapshot)

	func _fingerprint(snapshot: Dictionary) -> String:
		var source := snapshot.duplicate(true)
		var ordering: Dictionary = source.get("ordering_receipt", {}) \
				if source.get("ordering_receipt", {}) is Dictionary else {}
		ordering.erase("capture_fingerprint")
		source["ordering_receipt"] = ordering
		return STRICT_STATE.fingerprint(source)


static func controller(tree: SceneTree) -> Node:
	var owner: Node = CONTROLLER_SCENE.instantiate()
	if owner == null:
		return null
	tree.root.add_child(owner)
	var bridge := FreshWorldBridgeStub.new()
	owner.add_child(bridge)
	owner.set_meta("victory_fixture_world_bridge", bridge)
	owner.call("set_world_bridge", bridge)
	var configured: Dictionary = owner.call("configure")
	if not bool(configured.get("configured", false)):
		owner.free()
		return null
	return owner


static func issue_world(owner: Node, snapshot: Dictionary) -> Dictionary:
	var bridge_variant: Variant = owner.get_meta("victory_fixture_world_bridge", null)
	return bridge_variant.issue(snapshot) if bridge_variant is FreshWorldBridgeStub else {}


static func qualification(owner: Node) -> Dictionary:
	owner.call("advance_world_effective", 2.125, world([36, 36], [], 5))
	owner.call("advance_world_effective", 3.25, world([36, 36], [36, 36], 5))
	return owner.call("to_save_data") as Dictionary


static func audit(owner: Node, remaining_delta := 17.125) -> Dictionary:
	owner.call("advance_world_effective", 10.0, world([36, 36], [], 5))
	owner.call("advance_world_effective", remaining_delta, world([36, 36], [], 5))
	return owner.call("to_save_data") as Dictionary


static func audit_zero(owner: Node) -> Dictionary:
	owner.call("advance_world_effective", 10.0, world([36, 36], [], 5))
	owner.call(
		"advance_world_effective",
		119.9999995,
		world([36, 36], [], 5, [10000, 9000], "read_only")
	)
	return owner.call("to_save_data") as Dictionary


static func resolved(owner: Node) -> Dictionary:
	var joint := world([36, 36], [36, 36], 5, [10000, 10000])
	owner.call("advance_world_effective", 10.0, joint)
	owner.call("advance_world_effective", 120.0, joint)
	return owner.call("to_save_data") as Dictionary


static func special(owner: Node) -> Dictionary:
	var survivor_world := world([36, 36], [], 5)
	var players := survivor_world.get("players", []) as Array
	var eliminated := (players[1] as Dictionary).duplicate(true)
	eliminated["eliminated"] = true
	players[1] = eliminated
	survivor_world["players"] = players
	owner.call("resolve_special_outcome", "last_survivor", survivor_world)
	return owner.call("to_save_data") as Dictionary


static func world(
	player_zero_regions: Array,
	player_one_regions: Array,
	total_region_count: int,
	cash_values: Array = [10000, 9000],
	settlement_checkpoint := POST_SETTLEMENT_CHECKPOINT,
	capture_sequence := 0
) -> Dictionary:
	var regions: Array = []
	var district_index := 0
	for amount_variant in player_zero_regions:
		var amount := maxi(1, int(amount_variant))
		regions.append(_region(district_index, amount * 200, {"0": amount * 100}))
		district_index += 1
	for amount_variant in player_one_regions:
		var amount := maxi(1, int(amount_variant))
		regions.append(_region(district_index, amount * 200, {"1": amount * 100}))
		district_index += 1
	while regions.size() < total_region_count:
		regions.append(_region(district_index, 0, {}))
		district_index += 1
	return {
		"schema_version": "v0.6.victory-world.2",
		"players": [_player(0, int(cash_values[0])), _player(1, int(cash_values[1]))],
		"regions": regions,
		"clock_pause": {},
		"settlement_checkpoint": settlement_checkpoint,
		"ordering_receipt": {
			"checkpoint": settlement_checkpoint,
			"capture_sequence": capture_sequence,
			"region_revision": 1,
			"flow_revision": 1,
			"captured_at_game_time": 0.0,
			"victory_reads_after": [],
		},
		"visibility_scope": "controller_private",
	}


static func payload(save_wire: Dictionary) -> Dictionary:
	return (save_wire.get("victory_control_runtime", {}) as Dictionary).duplicate(true) \
			if save_wire.get("victory_control_runtime", {}) is Dictionary else {}


static func contains_key_recursive(value: Variant, target: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == target or contains_key_recursive((value as Dictionary).get(key_variant), target):
				return true
	elif value is Array:
		for child in value as Array:
			if contains_key_recursive(child, target):
				return true
	return false


static func contains_value_recursive(value: Variant, target: Variant) -> bool:
	if typeof(value) == typeof(target) and value == target:
		return true
	if value is Dictionary:
		for child in (value as Dictionary).values():
			if contains_value_recursive(child, target):
				return true
	elif value is Array:
		for child in value as Array:
			if contains_value_recursive(child, target):
				return true
	return false


static func _player(player_index: int, cash_cents: int) -> Dictionary:
	return {
		"player_index": player_index,
		"eliminated": false,
		"cash_ledger_cents": cash_cents,
		"audit_assets": {
			"available_cents": cash_cents,
			"escrow_cents": 0,
			"cash_ledger_cents": cash_cents,
			"ordinary_hand": [],
			"facilities": [],
			"installations": [],
			"commodity_inventory": [],
			"color_gdp": {},
			"units": [],
			"financial_positions": [],
		},
	}


static func _region(index: int, total_cents: int, by_player: Dictionary) -> Dictionary:
	return {
		"region_id": "region.%04d" % index,
		"district_index": index,
		"lifecycle_state": "active",
		"destroyed": false,
		"region_gdp_per_minute_cents": total_cents,
		"player_gdp_by_index": by_player.duplicate(true),
	}
