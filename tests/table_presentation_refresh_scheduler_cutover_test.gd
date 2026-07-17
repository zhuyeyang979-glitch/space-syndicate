extends SceneTree

const SchedulerScript = preload("res://scripts/runtime/table_presentation_refresh_scheduler.gd")
const CoordinatorScene = preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_test_deterministic_cadence()
	_test_developer_visibility_and_resets()
	_test_production_composition_and_negative_dependencies()
	if _failures.is_empty():
		print("Table presentation refresh scheduler cutover passed (%d checks)." % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_deterministic_cadence() -> void:
	var scheduler := SchedulerScript.new()
	root.add_child(scheduler)
	scheduler.configure_intervals(0.18, 0.16, 1.8, 1.8)
	scheduler.request_immediate(SchedulerScript.LIVE_KIND)
	scheduler.request_immediate(SchedulerScript.MAP_KIND)
	scheduler.request_immediate(SchedulerScript.FULL_KIND)
	var initial := scheduler.advance(0.0, false)
	_expect(initial.get("due", []) == [&"live", &"map", &"full"], "initial table refresh order must be live/map/full")
	_expect(not (initial.get("due", []) as Array).has(&"developer"), "hidden developer surface must not advance or refresh")
	var first_fragment := scheduler.advance(0.08, false)
	_expect((first_fragment.get("due", []) as Array).is_empty(), "partial cadence must not refresh early")
	var second_fragment := scheduler.advance(0.08, false)
	_expect(second_fragment.get("due", []) == [&"map"], "fragmented real delta must trigger map at 0.16 seconds")
	var third_fragment := scheduler.advance(0.02, false)
	_expect(third_fragment.get("due", []) == [&"live"], "fragmented real delta must trigger live at 0.18 seconds")
	var large_step := scheduler.advance(9.0, false)
	_expect(large_step.get("due", []) == [&"live", &"map", &"full"], "large delta must emit each cadence at most once in deterministic order")
	_expect(float(large_step.get("real_delta", -1.0)) == 9.0, "receipt must preserve real delta")
	scheduler.queue_free()


func _test_developer_visibility_and_resets() -> void:
	var scheduler := SchedulerScript.new()
	root.add_child(scheduler)
	scheduler.configure_intervals(0.18, 0.16, 1.8, 1.8)
	scheduler.request_immediate(SchedulerScript.DEVELOPER_KIND)
	var hidden := scheduler.advance(5.0, false)
	_expect(not (hidden.get("due", []) as Array).has(&"developer"), "developer cadence must freeze while its surface is hidden")
	var visible := scheduler.advance(0.0, true)
	_expect((visible.get("due", []) as Array).has(&"developer"), "developer cadence must resume when its surface is visible")
	scheduler.reset_table_cadence()
	var after_reset := scheduler.advance(0.0, false)
	_expect((after_reset.get("due", []) as Array).is_empty(), "manual full refresh must re-arm table cadence")
	var immediate := scheduler.request_immediate(SchedulerScript.LIVE_KIND)
	_expect(bool(immediate.get("accepted", false)), "explicit immediate live request must be accepted")
	_expect(scheduler.advance(0.0, false).get("due", []) == [&"live"], "immediate live request must not redraw heavier surfaces")
	_expect(not bool(scheduler.request_immediate(&"unknown").get("accepted", true)), "unknown refresh kinds must fail closed")
	scheduler.queue_free()


func _test_production_composition_and_negative_dependencies() -> void:
	var coordinator := CoordinatorScene.instantiate()
	root.add_child(coordinator)
	var schedulers := coordinator.find_children("TablePresentationRefreshScheduler", "TablePresentationRefreshScheduler", true, false)
	_expect(schedulers.size() == 1, "production coordinator must compose exactly one presentation cadence owner")
	var due: Dictionary = coordinator.call("advance_presentation_refresh_cadence", 0.0, false)
	_expect(due.get("due", []) == [&"live", &"map", &"full"], "production cadence must start with the established refresh order")
	var scheduler_source := FileAccess.get_file_as_string("res://scripts/runtime/table_presentation_refresh_scheduler.gd")
	for forbidden in ["current_scene", "Callable", "_refresh_ui", "_refresh_board", "_refresh_live_ui"]:
		_expect(not scheduler_source.contains(forbidden), "cadence owner must not callback or discover presentation target: %s" % forbidden)
	_expect(bool((coordinator.call("presentation_refresh_cadence_debug_snapshot") as Dictionary).get("gameplay_authority", true)) == false, "cadence owner must declare no gameplay authority")
	coordinator.queue_free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
