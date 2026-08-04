extends SceneTree

const Adapter := preload("res://scripts/v074/player/v074_player_map_projection_adapter.gd")
const Bench := preload("res://scripts/v074/player/v074_player_map_projection_bench.gd")
const RAIL_SCENE := "res://scenes/ui/v074/V074VirtualizedTargetRail.tscn"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(900, 620)
	var packed := load(RAIL_SCENE) as PackedScene
	_expect(packed != null, "TargetRail scene loads")
	if packed == null:
		_finish()
		return
	var rail := packed.instantiate()
	root.add_child(rail)
	await process_frame
	var adapter := Adapter.new()
	var projection: Dictionary = adapter.adapt(
		"player.local",
		Bench.make_map_receipt(30),
		Bench.make_public_facilities(30),
		Bench.make_legal_actions(30)
	)
	_expect(bool(rail.call("bind_projection", projection)), "rail binds DTO without runtime owner")
	rail.call("set_collapsed", false)
	await process_frame
	var region_debug := rail.call("debug_snapshot") as Dictionary
	_expect(int(region_debug.get("filtered_entry_count", 0)) == 30, "30 region rows are searchable")
	_expect(int(region_debug.get("row_pool_size", 0)) == 10, "row pool is fixed at ten")
	_expect(int(region_debug.get("rendered_row_count", 99)) <= 10, "rendered rows stay virtualized")
	_expect(int(region_debug.get("runtime_owner_dependency_count", -1)) == 0, "rail has no runtime owner dependency")
	rail.call("set_selected_card", "card.instance.warehouse.shipping")
	rail.call("set_search_text", "region.029")
	await process_frame
	_expect(int(rail.call("filtered_entry_count")) == 1, "search narrows dynamic targets")
	var binding_count := [0]
	rail.connect("target_binding_requested", func(_binding: Dictionary) -> void:
		binding_count[0] += 1
	)
	rail.call("_activate_filtered_index", 0)
	_expect(binding_count[0] == 1, "keyboard rail emits typed warehouse binding")
	rail.call("set_collapsed", true)
	_expect(bool(rail.call("is_collapsed")), "rail is collapsible")
	rail.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("V074_TARGET_RAIL_VIRTUALIZATION_TEST|status=%s|passed=%d|total=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(), _checks, JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
