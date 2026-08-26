extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const FIXED_SEED := 900626424
const VIEWPORT := Vector2i(1600, 960)
const SAMPLE_COUNT := 30

var _checks := 0
var _failures: Array[String] = []
var _samples: Array[int] = []
var _interactive_samples: Array[int] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = VIEWPORT
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main scene loads")
	if packed == null:
		_finish()
		return
	var application := packed.instantiate()
	root.add_child(application)
	for _frame in range(4):
		await process_frame
	var screen := application.get_node_or_null("V075GameScreen") as Control
	var flow := application.get_node_or_null("V075RuntimeComposition") as Node
	_expect(screen != null and flow != null, "production V075 screen and flow compose")
	if screen == null or flow == null:
		_finish()
		return
	var player_option := screen.find_child("PlayerCountOption", true, false) as OptionButton
	var seed_input := screen.find_child("SeedInput", true, false) as LineEdit
	var start := screen.find_child("StartConfiguredButton", true, false) as Button
	for index in range(player_option.item_count):
		if int(player_option.get_item_metadata(index)) == 4:
			player_option.select(index)
			break
	seed_input.text = str(FIXED_SEED)
	start.pressed.emit()
	for _frame in range(30):
		await process_frame
		if bool((flow.call("local_snapshot") as Dictionary).get("match_started", false)):
			break
	var coach := screen.find_child("V073PlaytestCoachMarks", true, false) as Node
	var guide := screen.find_child("GuideButton", true, false) as Button
	var close := coach.find_child("CoachClose", true, false) as Button
	var coach_root := coach.find_child("CoachRoot", true, false) as Control
	_expect(coach != null and guide != null and close != null, "existing Coach controls are reachable")
	if coach == null or guide == null or close == null:
		_finish()
		return
	var skip := coach.find_child("CoachSkipAll", true, false) as Button
	if skip != null and bool((coach.call("debug_snapshot") as Dictionary).get("active", false)):
		skip.pressed.emit()
		await process_frame
		await process_frame
	for sample_index in range(SAMPLE_COUNT):
		guide.pressed.emit()
		for _frame in range(8):
			await process_frame
			if bool((coach.call("debug_snapshot") as Dictionary).get("active", false)):
				break
		var started_msec := Time.get_ticks_msec()
		var screen_instance := screen.get_instance_id()
		var map_instance := screen.find_child("PlanetStageViewport", true, false).get_instance_id()
		var track_instance := screen.find_child("TrackRail", true, false).get_instance_id()
		close.pressed.emit()
		var hidden_msec := -1
		var interactive_msec := -1
		for _frame in range(20):
			await process_frame
			var now := Time.get_ticks_msec() - started_msec
			var coach_debug := coach.call("debug_snapshot") as Dictionary
			if hidden_msec < 0 and not bool(coach_debug.get("active", true)) and (coach_root == null or not coach_root.visible):
				hidden_msec = now
			var pace := flow.call("pacing_snapshot") as Dictionary
			if hidden_msec >= 0 and int(pace.get("effective_multiplier", -1)) == 1:
				interactive_msec = now
				break
		_expect(hidden_msec >= 0, "Coach closes visibly on sample %d" % (sample_index + 1))
		_expect(interactive_msec >= 0, "world pace restores production 1x on sample %d" % (sample_index + 1))
		if hidden_msec >= 0:
			_samples.append(hidden_msec)
		if interactive_msec >= 0:
			_interactive_samples.append(interactive_msec)
		_expect(screen.get_instance_id() == screen_instance, "Coach close preserves GameScreen instance")
		_expect(screen.find_child("PlanetStageViewport", true, false).get_instance_id() == map_instance, "Coach close preserves map instance")
		_expect(screen.find_child("TrackRail", true, false).get_instance_id() == track_instance, "Coach close preserves track instance")
		await process_frame
	var coach_debug := coach.call("debug_snapshot") as Dictionary
	_expect(_samples.size() >= SAMPLE_COUNT, "30 close samples recorded")
	_expect(_interactive_samples.size() >= SAMPLE_COUNT, "30 interactive samples recorded")
	_expect(_p95(_samples) <= 100, "Coach visible close P95 <= 100ms")
	_expect(_p95(_interactive_samples) <= 250, "Coach interactive restore P95 <= 250ms")
	var interactive_max: int = int(_interactive_samples.max()) if not _interactive_samples.is_empty() else 999999
	_expect(interactive_max <= 500, "Coach interactive restore max <= 500ms")
	_expect(int(coach_debug.get("coachmark_close_white_frame_count", 0)) == 0, "Coach reports zero white-frame samples")
	_expect(int(coach_debug.get("coachmark_close_input_loss_count", 0)) == 0, "Coach reports zero input-loss samples")
	_expect(int(coach_debug.get("coachmark_close_duplicate_signal_count", 0)) == 0, "Coach reports zero duplicate close signals")
	print("V076_ALPHA07_COACHMARK_CLOSE_PERFORMANCE|status=%s|passed=%d|total=%d|samples=%s|interactive_samples=%s|debug=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
		JSON.stringify(_samples),
		JSON.stringify(_interactive_samples),
		JSON.stringify(coach_debug),
	])
	application.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)


func _p95(values: Array[int]) -> int:
	if values.is_empty():
		return 999999
	var sorted := values.duplicate()
	sorted.sort()
	return int(sorted[mini(sorted.size() - 1, ceili(float(sorted.size()) * 0.95) - 1)])


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	print("V076_ALPHA07_COACHMARK_CLOSE_PERFORMANCE|status=FAIL|passed=%d|total=%d|failures=%s" % [
		_checks - _failures.size(),
		_checks,
		JSON.stringify(_failures),
	])
	quit(1)
