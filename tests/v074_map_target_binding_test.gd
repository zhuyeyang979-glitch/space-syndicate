extends SceneTree

const Adapter := preload("res://scripts/v074/player/v074_player_map_projection_adapter.gd")
const Binding := preload("res://scripts/v074/player/v074_map_target_binding_v1.gd")
const Bench := preload("res://scripts/v074/player/v074_player_map_projection_bench.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var adapter := Adapter.new()
	adapter.adapt("player.local", Bench.make_map_receipt(30), Bench.make_public_facilities(30), Bench.make_legal_actions(30))
	var cases := [
		["card.instance.factory.life", "region.000", "factory", "life", "UPGRADE_OWN"],
		["card.instance.market.energy", "region.000", "market", "energy", "BUILD_NEW"],
		["card.instance.warehouse.shipping", "region.000", "warehouse", "shipping", "BUILD_NEW"],
		["card.instance.warehouse.shipping", "region.001", "warehouse", "shipping", "REPAIR_OWN"],
		["card.instance.warehouse.shipping", "region.002", "warehouse", "shipping", "UPGRADE_OWN"],
	]
	for values in cases:
		var result: Dictionary = adapter.resolve_target(values[0], values[1], values[2], values[3], values[4])
		var binding := result.get("binding", {}) as Dictionary
		_expect(bool(result.get("accepted", false)), "%s target resolves" % values[2])
		_expect(bool(Binding.validation_report(binding).get("valid", false)), "%s binding validates" % values[2])
		_expect(str(binding.get("facility_type", "")) == values[2], "facility type remains exact")
		_expect(str(binding.get("industry_id", "")) == values[3], "industry remains exact")
		_expect(str(binding.get("facility_action_mode", "")) == values[4], "mode remains exact")
	var mismatch: Dictionary = adapter.resolve_target(
		"card.instance.warehouse.shipping", "region.000", "factory", "shipping", "BUILD_NEW"
	)
	_expect(not bool(mismatch.get("accepted", true)), "warehouse cannot route to factory slot")
	_expect(str(mismatch.get("reason_code", "")) == "target_slot_identity_mismatch", "misroute returns typed reason")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("V074_MAP_TARGET_BINDING_TEST|status=%s|passed=%d|total=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(), _checks, JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
