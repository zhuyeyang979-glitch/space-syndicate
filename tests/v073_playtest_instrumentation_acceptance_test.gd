extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const RUNTIME_SCENE := "res://scenes/runtime/V073RuntimeComposition.tscn"
const PROFILE := preload("res://scripts/playtest/v073_human_baseline_profile.gd")
const EVENT := preload("res://scripts/playtest/v073_playtest_event_v1.gd")
const FIXED_SEED := 900626424
const PLAYER_COUNT := 4
const MAX_STEPS := 2000

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_baseline_profile()
	_test_event_schema_and_privacy()
	var control := await _run_control_match()
	var instrumented := await _run_instrumented_match()
	_expect(
		bool(control.get("completed", false)),
		"control 1 Human + 3 AI match completes"
	)
	_expect(
		bool(instrumented.get("completed", false)),
		"instrumented 1 Human + 3 AI match completes"
	)
	if bool(control.get("completed", false)) and bool(
		instrumented.get("completed", false)
	):
		_expect(
			control.get("snapshot", {}) == instrumented.get("snapshot", {}),
			"telemetry leaves the deterministic gameplay snapshot unchanged"
		)
		_expect(
			control.get("settlement", {}) == instrumented.get("settlement", {}),
			"telemetry leaves FinalSettlement unchanged"
		)
	_finish()


func _test_baseline_profile() -> void:
	var snapshot := PROFILE.snapshot()
	_expect(
		str(snapshot.get("ruleset_id", "")) == "v0.7.3",
		"baseline ruleset is V0.7.3"
	)
	_expect(
		str(snapshot.get("profile_id", "")) == "v073_human_baseline_01",
		"baseline profile identity is frozen"
	)
	_expect(
		PROFILE.PROFILE_FINGERPRINT_INPUT.sha256_text().to_lower()
			== PROFILE.PROFILE_FINGERPRINT,
		"baseline fingerprint matches its exact canonical input"
	)
	_expect(
		int(snapshot.get("production_balance_value_change_count", -1)) == 0,
		"playtest task changes no production balance value"
	)
	var values := snapshot.get("values", {}) as Dictionary
	for row in [
		["initial_assets_per_color", 0],
		["asset_cap_per_color", 6],
		["starter_asset_cost", 0],
		["standard_l1_asset_cost", 1],
		["normal_card_ratio_bps", 6000],
		["commodity_card_ratio_bps", 4000],
		["normal_hand_limit", 5],
		["commodity_inventory_limit", 5],
		["submission_window_seconds", 30],
	]:
		_expect(
			int(values.get(str(row[0]), -1)) == int(row[1]),
			"baseline value %s remains %s" % row
		)
	_expect(
		is_equal_approx(float(values.get("sunlit_multiplier", 0.0)), 2.0),
		"sunlit multiplier remains 2.0"
	)
	_expect(
		is_equal_approx(float(values.get("dark_multiplier", 0.0)), 1.0),
		"dark multiplier remains 1.0"
	)
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://docs/playtest/v073_human_baseline_01.json"
		)
	)
	_expect(parsed is Dictionary, "baseline JSON parses")
	if parsed is Dictionary:
		_expect(
			str((parsed as Dictionary).get("profile_fingerprint", ""))
				== PROFILE.PROFILE_FINGERPRINT,
			"baseline JSON and runtime profile share one fingerprint"
		)


func _test_event_schema_and_privacy() -> void:
	_expect(EVENT.EVENT_TYPES.size() >= 40, "event schema exposes the full playtest vocabulary")
	var common := {
		"session_id": "v073-test-session",
		"build_sha": "0123456789abcdef",
		"ruleset_id": "v0.7.3",
		"balance_profile_id": PROFILE.PROFILE_ID,
		"balance_profile_fingerprint": PROFILE.PROFILE_FINGERPRINT,
		"seed": FIXED_SEED,
		"player_count": PLAYER_COUNT,
		"local_player_index": 0,
		"screen_resolution": "1600x960",
		"locale": "zh_CN",
		"event_sequence": 1,
		"monotonic_elapsed_ms": 1250,
		"batch_id": "batch.0001",
	}
	var planning := EVENT.build(
		common,
		"batch_locked",
		{
			"queue_count": 1,
			"zero_action_batch": false,
			"planning_duration_ms": 1250,
		}
	)
	_expect(not planning.is_empty(), "planning duration is accepted by the privacy schema")
	_expect(not EVENT.has_hidden_info(planning), "valid planning event has no hidden data")
	_expect(
		EVENT.build(
			common,
			"card_selected",
			{"card_instance_id": "private.instance.1"}
		).is_empty(),
		"private card instance identifiers fail closed"
	)
	_expect(
		EVENT.build(
			common,
			"card_selected",
			{"ai_plan": "future-opponent-action"}
		).is_empty(),
		"AI private plans fail closed"
	)
	_expect(
		EVENT.build(
			common,
			"playtest_marker_recorded",
			{"note": "C:/Users/example/private-project"}
		).is_empty(),
		"absolute paths fail closed"
	)


func _run_control_match() -> Dictionary:
	var packed := load(RUNTIME_SCENE) as PackedScene
	_expect(packed != null, "control runtime composition loads")
	if packed == null:
		return {}
	var flow := packed.instantiate()
	var detached := flow.get_node_or_null("V073PlaytestTelemetryService")
	_expect(detached != null, "control can detach the observation-only service")
	if detached != null:
		flow.remove_child(detached)
		detached.free()
	root.add_child(flow)
	await process_frame
	await process_frame
	var started := _start_match(flow)
	_expect(bool(started.get("accepted", false)), "control fixed-seed match starts")
	if not bool(started.get("accepted", false)):
		flow.queue_free()
		await process_frame
		return {}
	var completed := _accelerate_match(flow)
	_expect(bool(completed.get("accepted", false)), "control fixed-seed match settles")
	var snapshot := flow.call("local_snapshot") as Dictionary
	var debug := flow.call("debug_snapshot") as Dictionary
	var runtime_debug := debug.get("runtime", {}) as Dictionary
	var result := {
		"completed": bool(completed.get("accepted", false))
			and str(runtime_debug.get("phase", "")) == "settled",
		"snapshot": snapshot.duplicate(true),
		"settlement": (
			completed.get("final_settlement", {}) as Dictionary
		).duplicate(true),
	}
	_assert_runtime_completion(runtime_debug, "control")
	flow.queue_free()
	await process_frame
	return result


func _run_instrumented_match() -> Dictionary:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "instrumented production main scene loads")
	if packed == null:
		return {}
	var application := packed.instantiate()
	root.add_child(application)
	for _frame in range(3):
		await process_frame
	var flow := application.get_node_or_null("V073RuntimeComposition")
	var screen := application.get_node_or_null("V073SampleGameScreen")
	var telemetry := application.get_node_or_null(
		"V073RuntimeComposition/V073PlaytestTelemetryService"
	)
	_expect(flow != null, "instrumented runtime composition is reachable")
	_expect(screen != null, "instrumented player screen is reachable")
	_expect(telemetry != null, "instrumented telemetry service is reachable")
	if flow == null or screen == null or telemetry == null:
		application.queue_free()
		await process_frame
		return {}
	var export_root := "user://playtests/v073_test/run_%d_%d" % [
		OS.get_process_id(),
		Time.get_ticks_msec(),
	]
	_expect(
		bool(telemetry.call("set_export_root_for_test", export_root)),
		"test export remains inside isolated user data"
	)
	var started := _start_match(flow)
	_expect(bool(started.get("accepted", false)), "instrumented fixed-seed match starts")
	if not bool(started.get("accepted", false)):
		application.queue_free()
		await process_frame
		return {}
	for _frame in range(3):
		await process_frame
	var coach := screen.get_node_or_null("V073PlaytestCoachMarks")
	var marker := screen.find_child("V073PlaytestMarkerPanel", true, false)
	var questionnaire := screen.get_node_or_null("V073PlaytestQuestionnaire")
	_expect(coach != null, "Coach Marks are composed")
	_expect(marker != null, "Playtest Marker is composed")
	_expect(questionnaire != null, "Final questionnaire is composed")
	if coach != null:
		var coach_debug := coach.call("debug_snapshot") as Dictionary
		_expect(int(coach_debug.get("mark_count", 0)) == 14, "Coach Marks stay within fourteen prompts")
		_expect(bool(coach_debug.get("active", false)), "Coach Marks start after accepted New Game")
	if marker != null:
		var note := marker.find_child("MarkerNote", true, false) as LineEdit
		var button := marker.find_child("ConfusedButton", true, false) as Button
		_expect(note != null and button != null, "Marker note and quick actions are interactive")
		if note != null and button != null:
			note.text = "first-turn marker"
			button.pressed.emit()
			await process_frame
	var completed := _accelerate_match(flow)
	_expect(bool(completed.get("accepted", false)), "instrumented fixed-seed match settles")
	for _frame in range(3):
		await process_frame
	var snapshot := flow.call("local_snapshot") as Dictionary
	var debug := flow.call("debug_snapshot") as Dictionary
	var runtime_debug := debug.get("runtime", {}) as Dictionary
	_assert_runtime_completion(runtime_debug, "instrumented")
	var acceptance := screen.get("acceptance_state") as Dictionary
	_expect(
		int(acceptance.get("final_settlement_count", 0)) == 1,
		"player screen observes exactly one FinalSettlement"
	)
	_expect(
		int(acceptance.get("duplicate_settlement_count", -1)) == 0,
		"player screen observes no duplicate settlement"
	)
	var close_button := screen.find_child("SettlementClose", true, false) as Button
	_expect(close_button != null, "FinalSettlement has a close action")
	if close_button != null:
		close_button.pressed.emit()
		await process_frame
	_expect(
		questionnaire != null and bool(questionnaire.call("is_presented")),
		"questionnaire appears after FinalSettlement"
	)
	if questionnaire != null:
		var submit := questionnaire.find_child(
			"QuestionnaireSubmit", true, false
		) as Button
		_expect(submit != null, "questionnaire can submit")
		if submit != null:
			submit.pressed.emit()
			await process_frame
	var telemetry_debug := telemetry.call("debug_snapshot") as Dictionary
	_assert_telemetry_debug(telemetry_debug)
	var paths := telemetry.call("latest_export_paths") as Dictionary
	_assert_export(paths)
	var result := {
		"completed": bool(completed.get("accepted", false))
			and str(runtime_debug.get("phase", "")) == "settled",
		"snapshot": snapshot.duplicate(true),
		"settlement": (
			completed.get("final_settlement", {}) as Dictionary
		).duplicate(true),
	}
	application.queue_free()
	await process_frame
	return result


func _start_match(flow: Node) -> Dictionary:
	var intent := flow.call(
		"issue_intent",
		"new_game.start",
		{"player_count": PLAYER_COUNT, "seed": FIXED_SEED}
	) as Dictionary
	return flow.call("submit_intent", intent) as Dictionary


func _accelerate_match(flow: Node) -> Dictionary:
	var intent := flow.call(
		"issue_intent",
		"sample.accelerate",
		{"max_steps": MAX_STEPS}
	) as Dictionary
	return flow.call("submit_intent", intent) as Dictionary


func _assert_runtime_completion(debug: Dictionary, label: String) -> void:
	_expect(str(debug.get("phase", "")) == "settled", "%s reaches settled" % label)
	_expect(int(debug.get("player_count", 0)) == 4, "%s has four players" % label)
	_expect(int(debug.get("local_human_count", 0)) == 1, "%s has one human slot" % label)
	_expect(int(debug.get("ai_player_count", 0)) == 3, "%s has three AI" % label)
	for field in [
		"invalid_action_count",
		"nonfinite_count",
		"hidden_info_violation_count",
		"dual_authority_count",
		"runtime_error_count",
		"adapter_failure_count",
		"save_write_count",
	]:
		_expect(int(debug.get(field, -1)) == 0, "%s %s is zero" % [label, field])
	_expect(int(debug.get("final_settlement_count", 0)) == 1, "%s settles once" % label)
	_expect(
		int(debug.get("final_settlement_presentation_count", 0)) == 1,
		"%s presents settlement once" % label
	)
	_expect(
		int(debug.get("final_settlement_public_log_count", 0)) == 1,
		"%s logs settlement once" % label
	)


func _assert_telemetry_debug(debug: Dictionary) -> void:
	_expect(bool(debug.get("ready", false)), "telemetry is bound and ready")
	_expect(bool(debug.get("export_succeeded", false)), "telemetry local export succeeds")
	_expect(int(debug.get("event_type_count", 0)) == EVENT.EVENT_TYPES.size(), "telemetry reports exact schema vocabulary")
	for field in [
		"gameplay_owner_count",
		"save_owner_count",
		"rng_owner_count",
		"world_mutation_count",
		"player_mutation_count",
		"rng_draw_delta",
		"world_time_delta",
		"public_log_delta",
		"private_feedback_delta",
		"hidden_info_field_count",
		"network_dependency_count",
	]:
		_expect(int(debug.get(field, -1)) == 0, "telemetry %s is zero" % field)


func _assert_export(paths: Dictionary) -> void:
	var expected_files := [
		"events.jsonl",
		"summary.json",
		"feedback.json",
		"report.md",
		"manifest.json",
	]
	_expect(paths.size() == expected_files.size(), "export contains exactly five files")
	for file_name in expected_files:
		var path := str(paths.get(file_name, ""))
		_expect(not path.is_empty() and FileAccess.file_exists(path), "%s exists" % file_name)
	if not FileAccess.file_exists(str(paths.get("events.jsonl", ""))):
		return
	var event_types := {}
	var last_sequence := 0
	for line in FileAccess.get_file_as_string(
		str(paths.get("events.jsonl", ""))
	).split("
", false):
		var parsed: Variant = JSON.parse_string(line)
		_expect(parsed is Dictionary, "each JSONL event parses")
		if parsed is Dictionary:
			var event := parsed as Dictionary
			var sequence := int(event.get("event_sequence", 0))
			_expect(sequence == last_sequence + 1, "event sequence is contiguous")
			last_sequence = sequence
			_expect(not EVENT.has_hidden_info(event), "exported event contains no hidden information")
			event_types[str(event.get("event_type", ""))] = true
	for required_type in [
		"session_started",
		"new_game_started",
		"coach_mark_shown",
		"playtest_marker_recorded",
		"asset_refresh",
		"victory_resolved",
		"final_settlement_presented",
		"questionnaire_presented",
		"questionnaire_submitted",
		"session_ended",
	]:
		_expect(event_types.has(required_type), "export records %s" % required_type)
	var summary: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(str(paths.get("summary.json", "")))
	)
	_expect(summary is Dictionary, "summary JSON parses")
	if summary is Dictionary:
		_expect(
			int((summary as Dictionary).get("FINAL_SETTLEMENT_COUNT", 0)) == 1,
			"summary records one FinalSettlement"
		)
		_expect(
			str((summary as Dictionary).get("balance_profile_id", ""))
				== PROFILE.PROFILE_ID,
			"summary binds the frozen baseline profile"
		)
	var feedback: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(str(paths.get("feedback.json", "")))
	)
	_expect(feedback is Dictionary, "feedback JSON parses")
	if feedback is Dictionary:
		_expect(bool((feedback as Dictionary).get("submitted", false)), "questionnaire is submitted")
	var manifest: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(str(paths.get("manifest.json", "")))
	)
	_expect(manifest is Dictionary, "manifest JSON parses")
	if manifest is Dictionary:
		var hashes := (manifest as Dictionary).get(
			"file_hashes_sha256", {}
		) as Dictionary
		for file_name in ["events.jsonl", "summary.json", "feedback.json", "report.md"]:
			var content := FileAccess.get_file_as_string(str(paths.get(file_name, "")))
			_expect(
				str(hashes.get(file_name, "")) == content.sha256_text().to_lower(),
				"manifest hash matches %s" % file_name
			)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print(
		"V073_PLAYTEST_INSTRUMENTATION_ACCEPTANCE|status=%s|passed=%d|total=%d|details=%s"
		% [
			"PASS" if passed else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if passed else 1)
