extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_VIEWPORT := Vector2i(1600, 960)

var _application: Node
var _screen: Control
var _flow: Node
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = TEST_VIEWPORT
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main scene loads")
	if packed == null:
		await _finish()
		return
	_application = packed.instantiate()
	root.add_child(_application)
	for _frame in range(12):
		await process_frame
	_screen = _application.get_node_or_null("V075GameScreen") as Control
	_flow = _application.get_node_or_null("V075RuntimeComposition") as Node
	_expect(_screen != null and _flow != null, "production screen and flow are composed")
	if _screen == null or _flow == null:
		await _finish()
		return
	var start := _screen.find_child("StartConfiguredButton", true, false) as Button
	_expect(start != null, "production start control exists")
	if start == null:
		await _finish()
		return
	start.pressed.emit()
	var countdown: Control
	var phase := ""
	for _frame in range(360):
		await process_frame
		var snapshot := _flow.call("local_snapshot") as Dictionary
		phase = str(snapshot.get("phase", ""))
		countdown = _screen.find_child("BottomCountdownOverlay", true, false) as Control
		if phase == "submission" and countdown != null and countdown.visible:
			break
	_expect(phase == "submission", "countdown probe reaches submission")
	_expect(countdown != null, "production has one reused BottomCountdownBar instance")
	if countdown == null:
		await _finish()
		return
	var instances := _screen.find_children("BottomCountdownOverlay", "Control", true, false)
	_expect(instances.size() == 1, "production has exactly one visible countdown surface")
	_expect(countdown.mouse_filter == Control.MOUSE_FILTER_IGNORE, "countdown ignores pointer input")
	_expect(countdown.visible, "countdown is visible during submission")
	var label := countdown.find_child("CardResolutionRevealTimerLabel", true, false) as Label
	var bar := countdown.find_child("CardResolutionRevealTimerBar", true, false) as ProgressBar
	var panel := countdown.find_child("BottomCountdownPanel", true, false) as PanelContainer
	_expect(label != null and bar != null, "reused countdown exposes label and progress bar")
	_expect(panel != null, "reused countdown exposes its authored panel")
	if label != null:
		_expect(label.text.contains("s"), "countdown label exposes remaining seconds")
		_expect(label.custom_minimum_size.x >= 132.0, "countdown label reserves room for localized text and seconds")
		_expect(not label.text.contains("…") and not label.text.contains("..."), "countdown label is not ellipsized")
		_expect(label.get_minimum_size().x <= label.size.x + 1.0, "countdown label text fits its visible width")
	if bar != null:
		_expect(bar.value >= 0.0 and bar.value <= 100.0, "countdown ratio is bounded")
	var authority_snapshot := _flow.call("local_snapshot") as Dictionary
	var authority_total := float(authority_snapshot.get("submission_seconds_total", 0.0))
	var authority_remaining := float(authority_snapshot.get(
		"submission_seconds_remaining",
		-1.0
	))
	_expect(authority_total > 0.0, "RuntimeOwner projects the authoritative window total")
	if bar != null and authority_total > 0.0:
		_expect(
			is_equal_approx(
				bar.value,
				clampf(authority_remaining / authority_total, 0.0, 1.0) * 100.0
			),
			"countdown ratio matches the authoritative remaining/total projection"
		)
	var frozen_label := label.text if label != null else ""
	var frozen_ratio := bar.value if bar != null else -1.0
	await create_timer(1.0).timeout
	var paused_snapshot := _flow.call("local_snapshot") as Dictionary
	_expect(
		is_equal_approx(
			float(paused_snapshot.get("submission_seconds_remaining", -2.0)),
			authority_remaining
		),
		"coach pause keeps authoritative countdown remaining frozen"
	)
	_expect(
		(label == null or label.text == frozen_label)
		and (bar == null or is_equal_approx(bar.value, frozen_ratio)),
		"coach pause keeps the countdown presentation frozen"
	)
	var header := _screen.get_node_or_null("RootMargin/Shell/Header") as Control
	var track := _screen.get_node_or_null("RootMargin/Shell/TrackPanel") as Control
	var table := _screen.get_node_or_null("RootMargin/Shell/TableArea") as Control
	var countdown_rect := countdown.get_global_rect()
	var panel_rect := panel.get_global_rect() if panel != null else Rect2()
	var label_rect := label.get_global_rect() if label != null else Rect2()
	var bar_rect := bar.get_global_rect() if bar != null else Rect2()
	var header_rect := header.get_global_rect() if header != null else Rect2()
	var track_rect := track.get_global_rect() if track != null else Rect2()
	var table_rect := table.get_global_rect() if table != null else Rect2()
	var hand := _screen.find_child("DockPanel", true, false) as Control
	var hand_rect := hand.get_global_rect() if hand != null else Rect2()
	var confirm := _screen.find_child("CurrentActionConfirmButton", true, false) as Control
	var confirm_rect := confirm.get_global_rect() if confirm != null else Rect2()
	var speed_controls := _screen.find_child("V075PacingControls", true, false) as Control
	var speed_rect := speed_controls.get_global_rect() if speed_controls != null else Rect2()
	var legacy_timer := _screen.find_child("TimerProgress", true, false) as Control
	var legacy_label := _screen.find_child("TimerLabel", true, false) as Control
	_expect(not countdown_rect.intersects(hand_rect), "countdown does not overlap hand dock")
	_expect(not countdown_rect.intersects(table_rect), "countdown does not overlap map/table area")
	_expect(not countdown_rect.intersects(track_rect), "countdown does not overlap commodity track")
	_expect(not countdown_rect.intersects(confirm_rect), "countdown does not overlap confirm action")
	_expect(not countdown_rect.intersects(speed_rect), "countdown does not overlap pacing controls")
	_expect(
		legacy_timer != null and legacy_label != null
		and not legacy_timer.visible and not legacy_label.visible,
		"legacy header timer surfaces stay hidden"
	)
	_expect(
		countdown_rect.encloses(panel_rect),
		"countdown host contains the authored panel instead of clipping it"
	)
	_expect(
		countdown_rect.encloses(label_rect) and countdown_rect.encloses(bar_rect),
		"countdown host contains the visible label and progress geometry"
	)
	print("V076_BOTTOM_COUNTDOWN_BINDING|phase=%s|label=%s|ratio=%s|rect=%s|panel=%s|label_rect=%s|bar_rect=%s|header=%s|track=%s|table=%s|hand=%s" % [
		phase,
		label.text if label != null else "",
		bar.value if bar != null else -1.0,
		countdown_rect,
		panel_rect,
		label_rect,
		bar_rect,
		header_rect,
		track_rect,
		table_rect,
		hand_rect,
	])
	await _finish()


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
		"V076_BOTTOM_COUNTDOWN_PRODUCTION_BINDING|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
