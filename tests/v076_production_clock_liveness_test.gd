extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const FIXED_SEED := 900626424
const TEST_VIEWPORT := Vector2i(1600, 960)

var _checks := 0
var _failures: Array[String] = []
var _application: Node
var _screen: Control
var _flow: Node
var _runtime: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = TEST_VIEWPORT
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main scene loads for clock liveness")
	if packed == null:
		await _finish()
		return
	_application = packed.instantiate()
	root.add_child(_application)
	for _frame in range(8):
		await process_frame
	_screen = _application.get_node_or_null("V075GameScreen") as Control
	_flow = _application.get_node_or_null("V075RuntimeComposition") as Node
	_expect(_screen != null, "production V075 screen is composed")
	_expect(_flow != null, "production runtime composition is composed")
	if _screen == null or _flow == null:
		await _finish()
		return
	_runtime = _flow.get("_runtime_owner") as Node
	_expect(_runtime != null, "liveness probe uses the existing RuntimeOwner")
	if _runtime == null:
		await _finish()
		return

	_configure_new_game()
	var start := _screen.find_child("StartConfiguredButton", true, false) as Button
	_expect(start != null, "production new-game action is present")
	if start == null:
		await _finish()
		return
	start.pressed.emit()
	for _frame in range(60):
		await process_frame
		if bool((_flow.call("local_snapshot") as Dictionary).get("match_started", false)):
			break
	var initial := _flow.call("local_snapshot") as Dictionary
	_expect(bool(initial.get("match_started", false)), "new game starts in the production path")

	var coach := _screen.get_node_or_null("V073PlaytestCoachMarks") as Node
	var skip := coach.find_child("CoachSkipAll", true, false) as Button if coach != null else null
	_expect(skip != null, "coach exposes the real skip control")
	for _frame in range(30):
		await process_frame
		if coach != null and bool((coach.call("debug_snapshot") as Dictionary).get("active", false)):
			break
	var paused_before := _runtime.call("debug_snapshot") as Dictionary
	var paused_clock := int(paused_before.get("authoritative_clock_msec", -1))
	var paused_pace := int(paused_before.get("playtest_pace_multiplier", -1))
	_expect(paused_pace == 0, "coach pause is visible as zero effective runtime pace")
	await create_timer(1.0).timeout
	var paused_after := _runtime.call("debug_snapshot") as Dictionary
	_expect(
		int(paused_after.get("authoritative_clock_msec", -2)) == paused_clock,
		"coach pause does not advance the authoritative submission clock"
	)

	if skip != null and bool((coach.call("debug_snapshot") as Dictionary).get("active", false)):
		skip.pressed.emit()
	for _frame in range(120):
		await process_frame
		var coach_closed := coach == null or not bool((coach.call("debug_snapshot") as Dictionary).get("active", false))
		var pace_restored := int((_flow.call("pacing_snapshot") as Dictionary).get("effective_multiplier", 0)) > 0
		if coach_closed and pace_restored:
			break
	var resumed_before := _runtime.call("debug_snapshot") as Dictionary
	var resumed_clock := int(resumed_before.get("authoritative_clock_msec", -1))
	var resumed_remaining := float(resumed_before.get("submission_seconds_remaining", -1.0))
	_expect(int(resumed_before.get("playtest_pace_multiplier", 0)) > 0, "closing coach restores a running pace")

	var countdown := _screen.find_child("BottomCountdownOverlay", true, false) as Control
	_expect(countdown != null, "production screen contains the reused BottomCountdownBar")
	if countdown != null:
		_expect(countdown.mouse_filter == Control.MOUSE_FILTER_IGNORE, "countdown bar does not intercept input")
		var label := countdown.find_child("CardResolutionRevealTimerLabel", true, false) as Label
		var bar := countdown.find_child("CardResolutionRevealTimerBar", true, false) as ProgressBar
		_expect(label != null and bar != null, "countdown bar exposes its existing label and progress controls")
		_expect(countdown.visible, "countdown is visible during the submission phase")
		if label != null:
			_expect(not label.text.strip_edges().is_empty(), "countdown label is populated from the submission view model")
		if bar != null:
			_expect(bar.value >= 0.0 and bar.value <= 100.0, "countdown ratio is bounded")

	await create_timer(1.0).timeout
	var resumed_after := _runtime.call("debug_snapshot") as Dictionary
	_expect(
		int(resumed_after.get("authoritative_clock_msec", -1)) > resumed_clock,
		"authoritative clock advances after coach close"
	)
	_expect(
		float(resumed_after.get("submission_seconds_remaining", -1.0)) < resumed_remaining,
		"submission remaining decreases after coach close"
	)

	# The production composition is intentionally rendered in this probe. On a
	# headless machine its full presentation tree can run below real-time, so
	# use the existing user-facing 4x pacing control for the expiry leg after
	# proving the default Candidate 2 pace is live. This remains an ordinary
	# pacing intent and never injects a clock value or locks the submission.
	var fast_pace_result := _flow.submit_intent(
		_flow.issue_intent("ui.pacing.set", {"multiplier": 4})
	) as Dictionary
	_expect(bool(fast_pace_result.get("accepted", false)), "4x pacing intent is accepted for the expiry leg")
	_expect(
		int((_flow.call("pacing_snapshot") as Dictionary).get("effective_multiplier", 0)) == 4,
		"4x pacing is effective for the natural expiry leg"
	)

	var resolving_seen := false
	var wait_until := Time.get_ticks_msec() + 60_000
	while Time.get_ticks_msec() < wait_until:
		await process_frame
		var snapshot := _flow.call("local_snapshot") as Dictionary
		var phase := str(snapshot.get("phase", ""))
		if phase == "resolving":
			resolving_seen = true
			break
	_expect(resolving_seen, "natural submission expiry reaches resolving without a lock injection")
	# Resolution-to-maintenance is covered by the existing settlement/readiness
	# probes. This production liveness probe stops at the first authoritative
	# resolving edge so a slow headless presentation tree cannot turn a proven
	# clock expiry into a timeout.
	await _finish()


func _configure_new_game() -> void:
	var player_option := _screen.find_child("PlayerCountOption", true, false) as OptionButton
	var seed_input := _screen.find_child("SeedInput", true, false) as LineEdit
	if player_option != null:
		for index in range(player_option.item_count):
			if int(player_option.get_item_metadata(index)) == 4:
				player_option.select(index)
				break
	if seed_input != null:
		seed_input.text = str(FIXED_SEED)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _application != null and is_instance_valid(_application):
		_application.queue_free()
		await process_frame
		await process_frame
	print(
		"V076_PRODUCTION_CLOCK_LIVENESS|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
