extends Node
class_name V073PlaytestTelemetryService
# MCP_FINALIZE

signal event_recorded(event: Dictionary)
signal export_status_changed(success: bool, message: String)

const EventV1 := preload("res://scripts/playtest/v073_playtest_event_v1.gd")
const Baseline := preload("res://scripts/playtest/v073_human_baseline_profile.gd")
const RULESET_ID := "v0.7.3"
const EXPORT_ROOT := "user://playtests/v073"
const DEFAULT_SESSION_PREFIX := "v073"
const DEFAULT_REPORT_TITLE := "V0.7.3 Playtest Report"
const COLORS := [
	"life", "energy", "industry", "technology", "commerce", "shipping",
]
const FEEDBACK_SCALE_IDS := [
	"rules_easy_to_understand",
	"first_round_direction_clear",
	"six_color_assets_clear",
	"unified_track_clear",
	"target_selection_clear",
	"action_order_strategic",
	"fizzle_fair",
	"hidden_lead_fair",
	"submission_window_sufficient",
	"resolution_wait_acceptable",
	"ai_behavior_reasonable",
	"ui_readable",
	"match_fun",
	"would_play_again",
]
const FEEDBACK_TEXT_IDS := [
	"most_fun_moment",
	"most_confusing_part",
	"most_frustrating_part",
	"one_rule_to_change",
	"expected_match_length",
]

var _flow: Node
var _screen: Node
var _events: Array[Dictionary] = []
var _latest_snapshot: Dictionary = {}
var _previous_projection: Dictionary = {}
var _feedback: Dictionary = {}
var _session_id := ""
var _source_session_id := ""
var _source_ruleset_id := ""
var _build_sha := "unknown-local"
var _seed := 0
var _player_count := 0
var _event_sequence := 0
var _session_started_ticks := 0
var _session_started_at := ""
var _session_ended_at := ""
var _last_phase := "idle"
var _batch_started_elapsed_ms := 0
var _planning_started_elapsed_ms := 0
var _victory_pending_recorded := false
var _final_settlement_recorded := false
var _export_attempted := false
var _export_succeeded := false
var _export_root := EXPORT_ROOT
var _export_paths: Dictionary = {}
var _last_export_error := ""
var _candidate_profile: Dictionary = {}


func _ready() -> void:
	_build_sha = OS.get_environment("SPACE_SYNDICATE_BUILD_SHA").strip_edges()
	if _build_sha.is_empty():
		_build_sha = "unknown-local"


func _exit_tree() -> void:
	if not _session_id.is_empty() and not _export_attempted:
		finalize_session({"skipped": true, "reason": "application_closed"})


func configure_candidate_profile(profile: Dictionary) -> bool:
	if not _session_id.is_empty() or not _candidate_profile.is_empty():
		return false
	if not _candidate_profile_valid(profile):
		return false
	_candidate_profile = profile.duplicate(true)
	_export_root = str(_candidate_profile.get("export_root", EXPORT_ROOT))
	return true


func candidate_identity_snapshot() -> Dictionary:
	var identity := _effective_candidate_profile()
	identity["configured"] = not _candidate_profile.is_empty()
	identity["build_sha"] = _build_sha
	identity["source_ruleset_id"] = _source_ruleset_id
	identity["observation_owner_class"] = "V073PlaytestTelemetryService"
	identity["gameplay_owner_count"] = 0
	identity["save_owner_count"] = 0
	identity["rng_owner_count"] = 0
	identity["tick_owner_count"] = 0
	return identity


func bind_sources(flow: Node, screen: Node) -> void:
	if _flow != null or _screen != null:
		return
	_flow = flow
	_screen = screen
	if _flow != null:
		_flow.receipt_ready.connect(_on_receipt_ready)
		_flow.projection_changed.connect(_on_projection_changed)
		_flow.final_settlement_presented.connect(_on_final_settlement_presented)
		if _flow.has_signal("public_resolution_ready"):
			_flow.connect("public_resolution_ready", _on_public_resolution_ready)
		if _flow.has_signal("playtest_observation_ready"):
			_flow.connect("playtest_observation_ready", _on_playtest_observation_ready)
	if _screen != null:
		if _screen.has_signal("playtest_presentation_event"):
			_screen.connect(
				"playtest_presentation_event",
				_on_playtest_presentation_event
			)
		if _screen.has_signal("playtest_feedback_submitted"):
			_screen.connect(
				"playtest_feedback_submitted",
				_on_playtest_feedback_submitted
			)
		if _screen.has_signal("playtest_feedback_skipped"):
			_screen.connect(
				"playtest_feedback_skipped",
				_on_playtest_feedback_skipped
			)


func record_presentation_event(event_type: String, payload: Dictionary = {}) -> bool:
	return _record(event_type, payload)


func finalize_session(feedback: Dictionary = {}) -> bool:
	if _session_id.is_empty() or _export_attempted:
		return _export_succeeded
	_feedback = _sanitize_feedback(feedback)
	_record("session_ended", {"phase": str(_latest_snapshot.get("phase", "unknown"))})
	_session_ended_at = Time.get_datetime_string_from_system(true)
	_export_attempted = true
	var directory := "%s/%s" % [_export_root, _safe_session_id(_session_id)]
	var absolute_directory := ProjectSettings.globalize_path(directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return _export_failed("playtest_export_directory_failed_%d" % directory_error)

	var events_text := ""
	for event in _events:
		events_text += JSON.stringify(event, "", false) + "\n"
	var summary := _build_summary()
	var feedback_document := {
		"schema_version": 1,
		"session_id": _session_id,
		"submitted": not bool(_feedback.get("skipped", false)),
		"values": _feedback.duplicate(true),
	}
	var report_text := _build_report(summary, feedback_document)
	var contents := {
		"events.jsonl": events_text,
		"summary.json": JSON.stringify(summary, "  ", false) + "\n",
		"feedback.json": JSON.stringify(feedback_document, "  ", false) + "\n",
		"report.md": report_text,
	}
	_export_paths = {}
	var hashes := {}
	for file_name in ["events.jsonl", "summary.json", "feedback.json", "report.md"]:
		var path := "%s/%s" % [directory, file_name]
		if not _atomic_write(path, str(contents.get(file_name, ""))):
			return _export_failed("playtest_export_write_failed_%s" % file_name)
		_export_paths[file_name] = path
		hashes[file_name] = str(contents.get(file_name, "")).sha256_text().to_lower()
	var manifest := {
		"schema_version": 1,
		"event_schema_version": EventV1.SCHEMA_VERSION,
		"session_id": _session_id,
		"build_sha": _build_sha,
		"ruleset_id": _product_version(),
		"runtime_ruleset_id": _runtime_ruleset_id(),
		"balance_profile_id": _profile_id(),
		"balance_profile_fingerprint": _profile_fingerprint(),
		"golden_scenario_id": str(
			_effective_candidate_profile().get("golden_scenario_id", "")
		),
		"production_scene_path": str(
			_effective_candidate_profile().get("production_scene_path", "")
		),
		"evidence_source_type": "OBSERVATION_ONLY",
		"human_executed": false,
		"human_confirmed": false,
		"human_evidence_claim_allowed": false,
		"production_green": false,
		"human_green": false,
		"observer_attestation_required": true,
		"seed": _seed,
		"player_count": _player_count,
		"start_time": _session_started_at,
		"end_time": _session_ended_at,
		"file_hashes_sha256": hashes,
		"network_dependency_count": 0,
		"save_owner_count": 0,
	}
	var manifest_path := "%s/manifest.json" % directory
	if not _atomic_write(
		manifest_path,
		JSON.stringify(manifest, "  ", false) + "\n"
	):
		return _export_failed("playtest_export_manifest_failed")
	_export_paths["manifest.json"] = manifest_path
	_export_succeeded = true
	export_status_changed.emit(true, directory)
	return true


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V073PlaytestTelemetryDebugV1",
		"ready": _flow != null and _screen != null,
		"source_ruleset_id": _source_ruleset_id,
		"source_session_id": _source_session_id,
		"source_flow_instance_id": (
			_flow.get_instance_id() if is_instance_valid(_flow) else 0
		),
		"source_screen_instance_id": (
			_screen.get_instance_id() if is_instance_valid(_screen) else 0
		),
		"event_schema_version": EventV1.SCHEMA_VERSION,
		"event_type_count": EventV1.EVENT_TYPES.size(),
		"event_count": _events.size(),
		"session_id": _session_id,
		"build_sha": _build_sha,
		"balance_profile_id": _profile_id(),
		"balance_profile_fingerprint": _profile_fingerprint(),
		"candidate_identity": candidate_identity_snapshot(),
		"gameplay_owner_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
		"world_mutation_count": 0,
		"player_mutation_count": 0,
		"rng_draw_delta": 0,
		"world_time_delta": 0,
		"public_log_delta": 0,
		"private_feedback_delta": 0,
		"hidden_info_field_count": _hidden_info_field_count(),
		"network_dependency_count": 0,
		"export_attempted": _export_attempted,
		"export_succeeded": _export_succeeded,
		"export_paths": _export_paths.duplicate(true),
		"last_export_error": _last_export_error,
	}


func events_snapshot() -> Array:
	return _events.duplicate(true)


func latest_export_paths() -> Dictionary:
	return _export_paths.duplicate(true)


func set_export_root_for_test(path: String) -> bool:
	if not path.begins_with("user://") or ".." in path:
		return false
	_export_root = path.trim_suffix("/")
	return true


func _on_receipt_ready(receipt: Dictionary) -> void:
	var intent_kind := str(receipt.get("intent_kind", ""))
	var accepted := bool(receipt.get("accepted", false))
	if intent_kind == "new_game.start" and accepted:
		_start_session(receipt)
		return
	if _session_id.is_empty():
		return
	var reason := str(receipt.get("reason_code", "unknown"))
	match intent_kind:
		"card.queue":
			if accepted:
				_record("action_submitted", {
					"accepted": true,
					"queue_count": int(receipt.get("queue_size", 0)),
					"public_reason_code": reason,
				})
			else:
				_record_rejection(reason)
		"queue.reorder":
			if accepted:
				_record("action_order_changed", {
					"from_index": int(receipt.get("from_index", -1)),
					"to_index": int(receipt.get("to_index", -1)),
				})
		"queue.remove":
			if accepted:
				_record("target_cancelled", {"public_reason_code": reason})
		"submission.lock":
			if not accepted:
				_record_rejection(reason)
		"merge.normal":
			_record(
				"optional_merge_completed" if accepted else "optional_merge_cancelled",
				{"accepted": accepted, "public_reason_code": reason}
			)
		"track.acquire":
			if not accepted:
				_record_rejection(reason)


func _on_projection_changed(snapshot: Dictionary) -> void:
	_latest_snapshot = snapshot.duplicate(true)
	if _session_id.is_empty():
		return
	var phase := str(snapshot.get("phase", "idle"))
	var elapsed := _elapsed_ms()
	if phase != _last_phase:
		if phase == "resolving":
			var queue_count := (snapshot.get("queued_actions", []) as Array).size()
			_batch_started_elapsed_ms = elapsed
			_record("batch_locked", {
				"queue_count": queue_count,
				"zero_action_batch": queue_count == 0,
				"planning_duration_ms": maxi(
					0,
					elapsed - _planning_started_elapsed_ms
				),
			})
			_record("batch_resolution_started", {})
		elif _last_phase == "resolving" and phase == "maintenance":
			_record("batch_resolution_completed", {
				"batch_duration_ms": maxi(0, elapsed - _batch_started_elapsed_ms),
			})
		elif phase == "submission":
			_planning_started_elapsed_ms = elapsed
		_last_phase = phase
	_observe_deck_counts(snapshot)
	_observe_solar(snapshot)
	var progress := int(snapshot.get("public_progress_points", 0))
	var target := int(snapshot.get("public_progress_target", 0))
	if not _victory_pending_recorded and target > 0 and progress >= target:
		_victory_pending_recorded = true
		_record("victory_pending", {"value": progress})
	_previous_projection = _projection_counts(snapshot)


func _on_public_resolution_ready(receipt: Dictionary) -> void:
	var outcome := str(receipt.get("outcome_id", ""))
	var reason := str(receipt.get("reason_code", ""))
	if outcome == "facility_action_fizzled":
		_record("facility_contention", {"public_reason_code": reason})
		_record("action_fizzled", {"public_reason_code": reason})


func _on_playtest_observation_ready(receipt: Dictionary) -> void:
	if str(receipt.get("schema", "")) != "V073PlaytestObservationReceiptV1":
		return
	var event_type := str(receipt.get("event_type", ""))
	var payload := receipt.get("payload", {}) as Dictionary
	_record(event_type, payload)


func _on_playtest_presentation_event(event_type: String, payload: Dictionary) -> void:
	_record(event_type, payload)


func _on_playtest_feedback_submitted(feedback: Dictionary) -> void:
	_record("questionnaire_submitted", {"count": feedback.size()})
	finalize_session(feedback)


func _on_playtest_feedback_skipped() -> void:
	_record("questionnaire_skipped", {})
	finalize_session({"skipped": true})


func _on_final_settlement_presented(settlement: Dictionary) -> void:
	if _session_id.is_empty() or _final_settlement_recorded:
		return
	_final_settlement_recorded = true
	var settlement_id := str(settlement.get("settlement_id", "settlement"))
	_record("victory_resolved", {"settlement_id": settlement_id})
	_record("final_settlement_presented", {"settlement_id": settlement_id})


func _start_session(receipt: Dictionary) -> void:
	if not _session_id.is_empty() and not _export_attempted:
		finalize_session({"skipped": true, "reason": "new_game_replaced_session"})
	_events = []
	_previous_projection = {}
	_feedback = {}
	_event_sequence = 0
	_seed = int(receipt.get("seed", 0))
	_player_count = int(receipt.get("player_count", 0))
	_session_started_ticks = Time.get_ticks_msec()
	_session_started_at = Time.get_datetime_string_from_system(true)
	_session_ended_at = ""
	_source_session_id = str(receipt.get("session_id", "")).strip_edges()
	_source_ruleset_id = str(receipt.get("ruleset_id", "")).strip_edges()
	if _source_ruleset_id != _runtime_ruleset_id():
		_last_export_error = "playtest_source_ruleset_mismatch"
		return
	_session_id = "%s-%d-%s" % [
		_session_prefix(),
		int(Time.get_unix_time_from_system()),
		_source_session_id.sha256_text().left(10),
	]
	_last_phase = str(_latest_snapshot.get("phase", "submission"))
	_planning_started_elapsed_ms = 0
	_victory_pending_recorded = false
	_final_settlement_recorded = false
	_export_attempted = false
	_export_succeeded = false
	_export_paths = {}
	_last_export_error = ""
	_record("session_started", {})
	_record("new_game_started", {"phase": _last_phase})
	if not _latest_snapshot.is_empty():
		_on_projection_changed(_latest_snapshot)


func _record_rejection(reason: String) -> void:
	_record("action_submission_rejected", {"public_reason_code": reason})
	if "asset" in reason or "reservation" in reason:
		_record("asset_reservation_failed", {"public_reason_code": reason})


func _record(event_type: String, payload: Dictionary) -> bool:
	if _session_id.is_empty() and event_type not in [
		"session_started", "new_game_started"
	]:
		return false
	_event_sequence += 1
	var viewport_size := Vector2i.ZERO
	if is_inside_tree():
		viewport_size = Vector2i(get_viewport().get_visible_rect().size)
	var common := {
		"session_id": _session_id,
		"build_sha": _build_sha,
		"ruleset_id": _product_version(),
		"balance_profile_id": _profile_id(),
		"balance_profile_fingerprint": _profile_fingerprint(),
		"seed": _seed,
		"player_count": _player_count,
		"local_player_index": 0,
		"screen_resolution": "%dx%d" % [viewport_size.x, viewport_size.y],
		"locale": TranslationServer.get_locale(),
		"event_sequence": _event_sequence,
		"monotonic_elapsed_ms": _elapsed_ms(),
		"batch_id": _public_batch_id(),
	}
	var event := EventV1.build(common, event_type, payload)
	if event.is_empty() or EventV1.has_hidden_info(event):
		_event_sequence -= 1
		return false
	_events.append(event)
	event_recorded.emit(event.duplicate(true))
	return true


func _observe_deck_counts(snapshot: Dictionary) -> void:
	var current := _projection_counts(snapshot)
	if _previous_projection.is_empty():
		return
	var hand_delta := int(current.get("hand_count", 0)) - int(
		_previous_projection.get("hand_count", 0)
	)
	var discard_delta := int(current.get("discard_count", 0)) - int(
		_previous_projection.get("discard_count", 0)
	)
	if hand_delta > 0:
		_record("deck_draw", {
			"draw_count": hand_delta,
			"hand_count": int(current.get("hand_count", 0)),
		})
	if discard_delta > 0:
		_record("deck_discard", {"count": discard_delta})


func _observe_solar(snapshot: Dictionary) -> void:
	var previous := _previous_projection.get("solar", {}) as Dictionary
	var current := {}
	for row_variant in snapshot.get("region_solar", []) as Array:
		var row := row_variant as Dictionary
		var region_id := str(row.get("region_id", ""))
		var sunlit := bool(row.get("sunlit", false))
		current[region_id] = sunlit
		if previous.has(region_id) and bool(previous.get(region_id)) != sunlit:
			_record("solar_efficiency_changed", {
				"region_id": region_id,
				"sunlit": sunlit,
			})


func _projection_counts(snapshot: Dictionary) -> Dictionary:
	var facts := (
		(snapshot.get("personal_dbg", {}) as Dictionary).get("facts", {})
		as Dictionary
	)
	var solar := {}
	for row_variant in snapshot.get("region_solar", []) as Array:
		var row := row_variant as Dictionary
		solar[str(row.get("region_id", ""))] = bool(row.get("sunlit", false))
	return {
		"hand_count": int(facts.get("hand_count", 0)),
		"draw_count": int(facts.get("draw_pile_count", 0)),
		"discard_count": int(facts.get("discard_count", 0)),
		"solar": solar,
	}


func _build_summary() -> Dictionary:
	var elapsed_values := {}
	var counts := {}
	var fizzle_by_reason := {}
	var overflow_by_color := {}
	var ai_latencies: Array[int] = []
	var batch_latencies: Array[int] = []
	var action_total := 0
	var batch_count := 0
	for event in _events:
		var event_type := str(event.get("event_type", ""))
		var payload := event.get("payload", {}) as Dictionary
		counts[event_type] = int(counts.get(event_type, 0)) + 1
		if not elapsed_values.has(event_type):
			elapsed_values[event_type] = int(event.get("monotonic_elapsed_ms", 0))
		if event_type == "action_submitted":
			action_total += 1
		elif event_type == "batch_resolution_completed":
			batch_count += 1
			batch_latencies.append(int(payload.get("batch_duration_ms", 0)))
		elif event_type == "ai_action_submitted":
			ai_latencies.append(int(payload.get("latency_ms", 0)))
		elif event_type == "action_fizzled":
			var reason := str(payload.get("public_reason_code", "unknown"))
			fizzle_by_reason[reason] = int(fizzle_by_reason.get(reason, 0)) + 1
		elif event_type == "asset_cap_overflow":
			for color in (payload.get("overflow_by_color", {}) as Dictionary).keys():
				overflow_by_color[color] = int(overflow_by_color.get(color, 0)) \
					+ int((payload.get("overflow_by_color", {}) as Dictionary).get(color, 0))
	var duration_seconds := float(_elapsed_ms()) / 1000.0
	var fizzle_count := int(counts.get("action_fizzled", 0))
	var local_submissions := maxi(1, action_total)
	return {
		"schema_version": 1,
		"session_id": _session_id,
		"build_sha": _build_sha,
		"ruleset_id": _product_version(),
		"runtime_ruleset_id": _runtime_ruleset_id(),
		"balance_profile_id": _profile_id(),
		"balance_profile_fingerprint": _profile_fingerprint(),
		"human_executed": false,
		"human_confirmed": false,
		"production_green": false,
		"human_green": false,
		"MATCH_DURATION_SECONDS": duration_seconds,
		"TIME_TO_FIRST_CARD_SELECT_SECONDS": _first_seconds(elapsed_values, "card_selected"),
		"TIME_TO_FIRST_VALID_SUBMISSION_SECONDS": _first_seconds(elapsed_values, "action_submitted"),
		"TIME_TO_FIRST_FACILITY_SECONDS": _first_seconds(elapsed_values, "batch_resolution_completed"),
		"TIME_TO_FIRST_ASSET_REFRESH_SECONDS": _first_seconds(elapsed_values, "asset_refresh"),
		"TIME_TO_FIRST_PAID_L1_PLAY_SECONDS": _first_paid_l1_seconds(),
		"BATCH_COUNT": batch_count,
		"AVERAGE_PLANNING_TIME_SECONDS": _average_planning_seconds(),
		"SUBMISSION_TIMEOUT_COUNT": _payload_true_count("action_submission_rejected", "submission_timeout"),
		"ZERO_ACTION_BATCH_COUNT": _payload_true_count("batch_locked", "zero_action_batch"),
		"ACTIONS_SUBMITTED_TOTAL": action_total,
		"ACTIONS_SUBMITTED_PER_BATCH": float(action_total) / float(maxi(1, batch_count)),
		"TARGET_RESELECT_COUNT": int(counts.get("target_changed", 0)),
		"TARGET_CANCEL_COUNT": int(counts.get("target_cancelled", 0)),
		"ASSET_RESERVATION_FAILURE_COUNT": int(counts.get("asset_reservation_failed", 0)),
		"ASSET_STARVATION_BATCH_COUNT": _asset_starvation_count(),
		"ASSET_OVERFLOW_COUNT_BY_COLOR": overflow_by_color,
		"TRACK_COMMODITY_CLAIM_COUNT": int(counts.get("track_commodity_claimed", 0)),
		"TRACK_NORMAL_PURCHASE_COUNT": int(counts.get("track_normal_card_purchased", 0)),
		"RESHUFFLE_COUNT": int(counts.get("deck_reshuffle", 0)),
		"OPTIONAL_MERGE_COMPLETED_COUNT": int(counts.get("optional_merge_completed", 0)),
		"FACILITY_CONTENTION_COUNT": int(counts.get("facility_contention", 0)),
		"FIZZLE_COUNT": fizzle_count,
		"FIZZLE_COUNT_BY_REASON": fizzle_by_reason,
		"FIZZLE_RATE": float(fizzle_count) / float(local_submissions),
		"LOCAL_PLAYER_FIZZLE_RATE": float(fizzle_count) / float(local_submissions),
		"AI_THINK_LATENCY_P50_MS": _percentile(ai_latencies, 0.50),
		"AI_THINK_LATENCY_P95_MS": _percentile(ai_latencies, 0.95),
		"BATCH_RESOLUTION_P50_MS": _percentile(batch_latencies, 0.50),
		"BATCH_RESOLUTION_P95_MS": _percentile(batch_latencies, 0.95),
		"VICTORY_PENDING_DURATION_SECONDS": _victory_pending_duration_seconds(),
		"FINAL_SETTLEMENT_COUNT": int(counts.get("final_settlement_presented", 0)),
		"UI_BACKTRACK_COUNT": int(counts.get("ui_backtracked", 0)),
		"REGION_POPUP_OPEN_COUNT": int(counts.get("region_popup_opened", 0)),
		"HAND_DOCK_HOVER_COUNT": _surface_event_count("card_hover_summary", "hand_dock"),
		"TRACK_HOVER_COUNT": _surface_event_count("card_hover_summary", "unified_track"),
		"event_count": _events.size(),
	}


func _build_report(summary: Dictionary, feedback_document: Dictionary) -> String:
	var lines := [
		"# %s" % _report_title(),
		"",
		"- Session: `%s`" % _session_id,
		"- Build: `%s`" % _build_sha,
		"- Product: `%s`" % _product_version(),
		"- Runtime ruleset: `%s`" % _runtime_ruleset_id(),
		"- Baseline: `%s`" % _profile_id(),
		"- Seed: `%d`" % _seed,
		"- Players: `%d`" % _player_count,
		"",
		"## Summary",
		"",
		"- Match duration: %.1f seconds" % float(summary.get("MATCH_DURATION_SECONDS", 0.0)),
		"- Batches: %d" % int(summary.get("BATCH_COUNT", 0)),
		"- Actions submitted: %d" % int(summary.get("ACTIONS_SUBMITTED_TOTAL", 0)),
		"- Fizzles: %d" % int(summary.get("FIZZLE_COUNT", 0)),
		"- Final settlements: %d" % int(summary.get("FINAL_SETTLEMENT_COUNT", 0)),
		"",
		"## Feedback",
		"",
		"Feedback submitted: `%s`" % str(feedback_document.get("submitted", false)).to_lower(),
		"",
		"This report is local-only and contains no opponent hidden information.",
	]
	return "\n".join(lines) + "\n"


func _candidate_profile_valid(profile: Dictionary) -> bool:
	var fingerprint_input := str(profile.get("profile_fingerprint_input", ""))
	var fingerprint := str(profile.get("profile_fingerprint", ""))
	var export_root := str(profile.get("export_root", ""))
	var session_prefix := str(profile.get("session_prefix", ""))
	return (
		str(profile.get("schema", ""))
			== "V076Alpha07HumanGoldenCandidateProfileV1"
		and str(profile.get("product_version", "")) == "v0.7.6"
		and str(profile.get("runtime_ruleset_id", "")) == "v0.7.5"
		and not str(profile.get("profile_id", "")).is_empty()
		and fingerprint.length() == 64
		and fingerprint_input.sha256_text().to_lower() == fingerprint
		and str(profile.get("golden_scenario_id", ""))
			== "v076-alpha07-golden-playtest-scenario-01"
		and int(profile.get("golden_step_count", 0)) == 15
		and str(profile.get("production_scene_path", ""))
			== "res://scenes/main.tscn"
		and export_root.begins_with("user://")
		and not ".." in export_root
		and not session_prefix.is_empty()
		and not "/" in session_prefix
		and not "\\" in session_prefix
		and str(profile.get("evidence_source_type", ""))
			== "OBSERVATION_ONLY"
		and profile.get("human_executed", true) == false
		and profile.get("human_confirmed", true) == false
		and profile.get("human_evidence_claim_allowed", true) == false
		and profile.get("production_green", true) == false
		and profile.get("human_green", true) == false
		and int(profile.get("production_balance_value_change_count", -1)) == 0
		and profile.get("source_authorities", {}) is Dictionary
	)


func _effective_candidate_profile() -> Dictionary:
	if not _candidate_profile.is_empty():
		return _candidate_profile.duplicate(true)
	return {
		"schema": "V073PlaytestCandidateProfileV1",
		"product_version": RULESET_ID,
		"runtime_ruleset_id": RULESET_ID,
		"profile_id": Baseline.PROFILE_ID,
		"profile_fingerprint": Baseline.PROFILE_FINGERPRINT,
		"golden_scenario_id": "",
		"production_scene_path": "res://scenes/main.tscn",
		"export_root": EXPORT_ROOT,
		"session_prefix": DEFAULT_SESSION_PREFIX,
		"report_title": DEFAULT_REPORT_TITLE,
		"evidence_source_type": "OBSERVATION_ONLY",
		"human_executed": false,
		"human_confirmed": false,
		"human_evidence_claim_allowed": false,
		"production_green": false,
		"human_green": false,
	}


func _product_version() -> String:
	return str(_effective_candidate_profile().get("product_version", RULESET_ID))


func _runtime_ruleset_id() -> String:
	return str(
		_effective_candidate_profile().get("runtime_ruleset_id", RULESET_ID)
	)


func _profile_id() -> String:
	return str(
		_effective_candidate_profile().get("profile_id", Baseline.PROFILE_ID)
	)


func _profile_fingerprint() -> String:
	return str(_effective_candidate_profile().get(
		"profile_fingerprint",
		Baseline.PROFILE_FINGERPRINT
	))


func _session_prefix() -> String:
	return str(
		_effective_candidate_profile().get(
			"session_prefix",
			DEFAULT_SESSION_PREFIX
		)
	)


func _report_title() -> String:
	return str(
		_effective_candidate_profile().get("report_title", DEFAULT_REPORT_TITLE)
	)


func _sanitize_feedback(feedback: Dictionary) -> Dictionary:
	var result := {}
	if bool(feedback.get("skipped", false)):
		result["skipped"] = true
		if feedback.has("reason"):
			result["reason"] = _clean_feedback_text(str(feedback.get("reason", "")), 80)
		return result
	for id in FEEDBACK_SCALE_IDS:
		if feedback.has(id):
			result[id] = clampi(int(feedback.get(id, 4)), 1, 7)
	for id in FEEDBACK_TEXT_IDS:
		if feedback.has(id):
			result[id] = _clean_feedback_text(str(feedback.get(id, "")), 500)
	return result


func _clean_feedback_text(value: String, limit: int) -> String:
	var clean := ""
	for character in value:
		var code := character.unicode_at(0)
		if code >= 32 and code != 127:
			clean += character
	return clean.left(limit)


func _atomic_write(path: String, content: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	var temporary_path := "%s.%d.tmp" % [absolute_path, OS.get_process_id()]
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(temporary_path) != content:
		DirAccess.remove_absolute(temporary_path)
		return false
	if FileAccess.file_exists(absolute_path):
		if DirAccess.remove_absolute(absolute_path) != OK:
			DirAccess.remove_absolute(temporary_path)
			return false
	if DirAccess.rename_absolute(temporary_path, absolute_path) != OK:
		DirAccess.remove_absolute(temporary_path)
		return false
	return true


func _export_failed(reason: String) -> bool:
	_last_export_error = reason
	_export_succeeded = false
	export_status_changed.emit(false, reason)
	return false


func _hidden_info_field_count() -> int:
	var count := 0
	for event in _events:
		if EventV1.has_hidden_info(event):
			count += 1
	return count


func _public_batch_id() -> String:
	var batch_number := int(_latest_snapshot.get("batch_number", 0))
	return "none" if batch_number <= 0 else "batch.%04d" % batch_number


func _elapsed_ms() -> int:
	if _session_started_ticks <= 0:
		return 0
	return maxi(0, Time.get_ticks_msec() - _session_started_ticks)


func _safe_session_id(value: String) -> String:
	var result := ""
	for character in value:
		if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			result += character
	return result.left(96)


func _first_seconds(index: Dictionary, event_type: String) -> float:
	if not index.has(event_type):
		return 0.0
	return float(index.get(event_type, 0)) / 1000.0


func _first_paid_l1_seconds() -> float:
	for event in _events:
		var event_type := str(event.get("event_type", ""))
		var payload := event.get("payload", {}) as Dictionary
		if event_type in ["target_bound", "action_submitted"] \
				and int(payload.get("asset_cost", 0)) > 0:
			return float(event.get("monotonic_elapsed_ms", 0)) / 1000.0
	return 0.0


func _average_planning_seconds() -> float:
	var total := 0
	var count := 0
	for event in _events:
		if str(event.get("event_type", "")) == "batch_locked":
			total += int(
				(event.get("payload", {}) as Dictionary).get(
					"planning_duration_ms",
					0
				)
			)
			count += 1
	return 0.0 if count == 0 else float(total) / float(count) / 1000.0


func _payload_true_count(event_type: String, field: String) -> int:
	var count := 0
	for event in _events:
		if str(event.get("event_type", "")) == event_type \
				and bool((event.get("payload", {}) as Dictionary).get(field, false)):
			count += 1
	return count


func _asset_starvation_count() -> int:
	var result := 0
	for event in _events:
		if str(event.get("event_type", "")) == "asset_reservation_failed":
			result += 1
	return result


func _percentile(values: Array[int], percentile: float) -> int:
	if values.is_empty():
		return 0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(percentile * sorted.size())) - 1, 0, sorted.size() - 1)
	return int(sorted[index])


func _victory_pending_duration_seconds() -> float:
	var pending := -1
	for event in _events:
		var event_type := str(event.get("event_type", ""))
		if event_type == "victory_pending":
			pending = int(event.get("monotonic_elapsed_ms", 0))
		elif event_type == "victory_resolved" and pending >= 0:
			return float(int(event.get("monotonic_elapsed_ms", 0)) - pending) / 1000.0
	return 0.0


func _surface_event_count(event_type: String, surface: String) -> int:
	var count := 0
	for event in _events:
		var payload := event.get("payload", {}) as Dictionary
		if str(event.get("event_type", "")) == event_type \
				and str(payload.get("source_surface", "")) == surface:
			count += 1
	return count
