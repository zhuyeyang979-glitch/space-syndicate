extends SceneTree

const Adapter := preload("res://scripts/v074/player/v074_player_map_projection_adapter.gd")
const Bench := preload("res://scripts/v074/player/v074_player_map_projection_bench.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for region_count in [6, 16, 30]:
		var adapter := Adapter.new()
		var projection: Dictionary = adapter.adapt(
			"player.local",
			Bench.make_map_receipt(region_count),
			Bench.make_public_facilities(region_count),
			Bench.make_legal_actions(region_count)
		)
		_expect(not projection.is_empty(), "%d-region projection adapts" % region_count)
		_expect(bool(Adapter.validation_report(projection).get("valid", false)), "%d-region projection validates" % region_count)
		_expect(int(projection.get("region_count", 0)) == region_count, "%d-region count remains dynamic" % region_count)
		_expect((projection.get("public_facility_slots", []) as Array).size() == region_count * 18, "%d-region projection carries 18 slots per region" % region_count)
		_expect((projection.get("region_popup_by_id", {}) as Dictionary).size() == region_count, "%d-region popup index is complete" % region_count)
		_expect(bool(projection.get("planet_primary_target_selection_surface", false)), "globe remains primary")
		_expect(not bool(projection.get("target_rail_primary_surface", true)), "rail remains secondary")
	var source := FileAccess.get_file_as_string("res://scripts/v074/player/v074_player_map_projection_adapter.gd")
	_expect(not source.contains("region.alpha") and not source.contains("region.zeta"), "adapter has no alpha-zeta production assumption")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("V074_PLAYER_MAP_PROJECTION_TEST|status=%s|passed=%d|total=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(), _checks, JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
