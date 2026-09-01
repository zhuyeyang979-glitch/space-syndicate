extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const FIXED_SEED := 900626424
const MAX_WAIT_FRAMES := 20

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main.tscn loads")
	if packed == null:
		_finish()
		return
	var application := packed.instantiate()
	root.add_child(application)
	for _frame in range(4):
		await process_frame
	var screen := application.get_node_or_null("V075GameScreen") as Control
	var flow := application.get_node_or_null("V075RuntimeComposition") as Node
	var overlay := application.get_node_or_null(
		"V075NewGameLoadingOverlay"
	) as Control
	_expect(screen != null, "production screen exists")
	_expect(flow != null, "production ApplicationFlow exists")
	_expect(overlay != null, "presentation-only loading overlay exists")
	if screen == null or flow == null or overlay == null:
		application.queue_free()
		await process_frame
		_finish()
		return
	var player_option := screen.find_child(
		"PlayerCountOption",
		true,
		false
	) as OptionButton
	var seed_input := screen.find_child("SeedInput", true, false) as LineEdit
	var start_button := screen.find_child(
		"StartConfiguredButton",
		true,
		false
	) as Button
	_expect(
		player_option != null and seed_input != null and start_button != null,
		"real New Game controls exist"
	)
	for index in range(player_option.item_count):
		if int(player_option.get_item_metadata(index)) == 4:
			player_option.select(index)
			break
	seed_input.text = str(FIXED_SEED)
	var before := overlay.call("debug_snapshot") as Dictionary
	_expect(
		not bool(before.get("active", true))
		and not bool(before.get("visible", true)),
		"loading overlay starts hidden and idle"
	)
	start_button.pressed.emit()
	var immediate := overlay.call("debug_snapshot") as Dictionary
	_expect(
		bool(immediate.get("active", false))
		and bool(immediate.get("visible", false)),
		"New Game click immediately exposes blocking loading feedback"
	)
	_expect(
		str(immediate.get("stage_id", "")) == "request_received"
		and int(immediate.get("stage_index", 0)) == 1,
		"first loading stage names request receipt"
	)
	_expect(
		not bool((flow.call("local_snapshot") as Dictionary).get(
			"match_started",
			false
		)),
		"feedback renders before synchronous authority initialization begins"
	)
	var staged: Dictionary = {}
	for _frame in range(3):
		await process_frame
		staged = overlay.call("debug_snapshot") as Dictionary
		if str(staged.get("stage_id", "")) == "authority_initialization":
			break
	_expect(
		bool(staged.get("active", false))
		and str(staged.get("stage_id", ""))
			== "authority_initialization",
		"second rendered frame explains world, track and AI initialization"
	)
	for _frame in range(MAX_WAIT_FRAMES):
		await process_frame
		if int((overlay.call("debug_snapshot") as Dictionary).get(
			"first_playable_count",
			0
		)) == 1:
			break
	var after := overlay.call("debug_snapshot") as Dictionary
	var snapshot := flow.call("local_snapshot") as Dictionary
	_expect(
		bool(snapshot.get("match_started", false))
		and str(snapshot.get("phase", "")) == "submission",
		"existing synchronous authority opens the real submission phase"
	)
	_expect(
		int(after.get("begin_count", 0)) == 1
		and int(after.get("first_playable_count", 0)) == 1
		and int(after.get("failure_count", -1)) == 0,
		"one click reaches first-playable exactly once"
	)
	_expect(
		not bool(after.get("active", true))
		and not bool(after.get("visible", true))
		and str(after.get("stage_id", "")) == "first_playable",
		"overlay closes only after one presented playable frame"
	)
	_expect(
		(after.get("stage_history", []) as Array) == [
			"request_received",
			"authority_initialization",
			"projection_received",
			"first_playable",
		],
		"loading stages advance monotonically without invented domain progress"
	)
	var latency_msec := int(after.get(
		"click_to_first_playable_msec",
		0
	))
	_expect(
		latency_msec > 0 and latency_msec < 60000,
		"click-to-first-playable uses a bounded monotonic duration"
	)
	_expect(
		str(after.get("measurement_clock", ""))
			== "Time.get_ticks_msec.presentation_only"
		and int(after.get("gameplay_owner_count", -1)) == 0
		and int(after.get("tick_owner_count", -1)) == 0
		and int(after.get("rng_owner_count", -1)) == 0
		and int(after.get("world_mutation_count", -1)) == 0
		and int(after.get(
			"authority_initialization_async_split_count",
			-1
		)) == 0,
		"loading measurement owns no gameplay, tick, RNG or world state"
	)
	var telemetry := application.get_node(
		"V075RuntimeComposition/V073PlaytestTelemetryService"
	) as Node
	var timing_events: Array = []
	for event_variant in telemetry.call("events_snapshot") as Array:
		var event := event_variant as Dictionary
		var payload := event.get("payload", {}) as Dictionary
		if (
			str(event.get("event_type", ""))
				== "playtest_marker_recorded"
			and str(payload.get("marker_type", ""))
				== "new_game_first_playable"
		):
			timing_events.append(event.duplicate(true))
	_expect(
		timing_events.size() == 1
		and bool(after.get("telemetry_recorded", false)),
		"local observation telemetry records first-playable exactly once"
	)
	if timing_events.size() == 1:
		var payload := (
			(timing_events[0] as Dictionary).get("payload", {}) as Dictionary
		)
		_expect(
			int(payload.get("latency_ms", -1)) == latency_msec
			and str(payload.get("phase", "")) == "submission"
			and str(payload.get("source_surface", ""))
				== "new_game_loading_overlay",
			"telemetry carries the exact public startup duration and phase"
		)
	var flow_debug := flow.call("debug_snapshot") as Dictionary
	_expect(
		int(flow_debug.get("v076_kernel_owner_count", 0)) == 1
		and int(flow_debug.get("gameplay_owner_count", 0)) == 1
		and int(flow_debug.get("v076_public_batch_entry_count", -1)) == 0
		and int(flow_debug.get(
			"v076_shared_sushi_track_resolution_count",
			-1
		)) == 0,
		"existing Kernel and Runtime owners remain the only authorities"
	)
	application.queue_free()
	await process_frame
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print((
		"V076_NEW_GAME_LOADING_FEEDBACK_TEST|status=%s|passed=%d|total=%d|"
		+ "failures=%s"
	) % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
