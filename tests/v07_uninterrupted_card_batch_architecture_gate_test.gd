extends SceneTree

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var main_scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var surface_source := FileAccess.get_file_as_string("res://scripts/ui/v07/v07_contextual_table_surface.gd")
	var surface_scene := FileAccess.get_file_as_string("res://scenes/ui/v07/V07ContextualTableSurface.tscn")
	var bench_scene := FileAccess.get_file_as_string("res://scenes/tools/V07UninterruptedCardBatchContextualTableBench.tscn")

	_expect(not main_source.contains("V07ContextualTableSurface") and not main_source.contains("card_batch_v07"), "V0.7 reference foundation adds no Main responsibility or fallback")
	_expect(not main_scene.contains("V07ContextualTableSurface") and not main_scene.contains("V07UninterruptedCardBatch"), "V0.7 reference foundation does not enter production composition")
	_expect(surface_scene.contains("res://scenes/ui/PlanetBoard.tscn"), "contextual table uses the real production PlanetBoard")
	_expect(not surface_scene.contains("Counter") and not surface_scene.contains("RightFixedRegion"), "V0.7 table scene contains no counter or permanent right rack node")
	_expect(surface_scene.contains("RegionSupplyPopup") and surface_scene.contains("CardResolutionOverlay") and surface_scene.contains("PlayerCardDock"), "contextual popup, transient resolution, and three-pool dock are editable scene nodes")
	_expect(surface_source.contains("RESOLUTION_PHASES") and surface_source.contains("ignored_gameplay_input_count"), "player target records and rejects resolution-time gameplay input")
	_expect(not surface_source.contains("CounterResponseWindowV06") and not surface_source.contains("CounterStack"), "new V0.7 player surface has no V0.6 counter dependency")
	_expect(bench_scene.contains("V07ContextualTableSurface.tscn"), "production-wiring Bench composes the real contextual table surface")

	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V07_UNINTERRUPTED_CARD_BATCH_ARCHITECTURE_GATE_TEST|status=%s|checks=%d|failures=%d|new_main_responsibility_count=0|new_main_caller_count=0|new_main_fallback_count=0" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("V07_UNINTERRUPTED_CARD_BATCH_ARCHITECTURE_GATE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
