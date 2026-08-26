extends SceneTree

const SHOWCASE_SCENE := (
	"res://scenes/tools/CommercialPresentationShowcase.tscn"
)
const EPISODE_PLAN_PATH := (
	"res://data/presentation/v076_commercial_showcase_episode_plan.json"
)
const DEFAULT_EVIDENCE_ROOT := (
	"res://reports/presentation/commercial_m1"
)
const FIXTURE_CLASS := "PRESENTATION_FIXTURE"
const FIXTURE_BRIDGE_SCHEMA := "V076CommercialPresentationFixtureBridgeV1"
const FIXTURE_BRIDGE_METHOD := (
	"VerticalSliceShowcase.submit_presentation_fixture"
)
const FIXTURE_BANNER_TEXT := (
	"PRESENTATION_FIXTURE — NOT NATURAL GAMEPLAY / NOT HUMAN GREEN"
)
const CAPTURE_SIZE := Vector2i(1600, 960)
const FRAME_PHASES := ["start", "mid", "end"]

var _checks := 0
var _failures: Array[String] = []
var _captured_frame_count := 0
var _capture_records: Array[Dictionary] = []
var _episode_records: Array[Dictionary] = []
var _exact_once_rows: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plan := _load_json(EPISODE_PLAN_PATH)
	var evidence_root := _absolute_path(_argument_value(
		"--evidence-root", DEFAULT_EVIDENCE_ROOT
	))
	var expected_size_label := _argument_value(
		"--expected-client-size", "1600x960"
	)
	var ready_path := _argument_value("--window-probe-ready", "")
	var ack_path := _argument_value("--window-probe-ack", "")
	var probe_nonce := _argument_value("--window-probe-nonce", "")
	var headed_capture_path := _absolute_path(_argument_value(
		"--headed-capture-output",
		"%s/showcase_headed_client_final.png" % evidence_root
	))

	_expect(not plan.is_empty(), "commercial showcase episode plan loads")
	_expect(
		int(plan.get("schema_version", 0)) == 1
		and str(plan.get("contract_id", ""))
		== "space_syndicate.v076.commercial_showcase_episode_plan.v1",
		"episode plan schema is exact"
	)
	var episodes := plan.get("episodes", []) as Array
	_expect(episodes.size() == 13, "episode plan contains exactly 13 episodes")
	_expect(ResourceLoader.exists(SHOWCASE_SCENE), "canonical Showcase scene exists")
	_prepare_capture_window()
	DirAccess.make_dir_recursive_absolute(evidence_root)

	var packed := load(SHOWCASE_SCENE) as PackedScene
	_expect(packed != null, "canonical Showcase scene loads")
	if packed == null:
		_finish()
		return
	var showcase := packed.instantiate() as Control
	root.add_child(showcase)
	await _pump_frames(12)
	var contract := showcase.call("get_showcase_contract") as Dictionary
	_expect(
		str(contract.get("fixture_class", "")) == FIXTURE_CLASS,
		"Showcase contract is explicitly a presentation fixture"
	)
	_expect(
		str(contract.get("fixture_banner_text", "")) == FIXTURE_BANNER_TEXT
		and bool(contract.get("fixture_banner_visible", false)),
		"fixture banner is permanently visible"
	)
	_expect(
		int(contract.get("episode_count", 0)) == 13
		and int(contract.get("frame_count", 0)) == 39,
		"Showcase contract exposes 13 episodes and 39 evidence frames"
	)
	_expect(
		int(contract.get("fixture_bridge_instance_count", 0)) == 1
		and str(contract.get("fixture_bridge_schema", ""))
			== FIXTURE_BRIDGE_SCHEMA
		and str(contract.get("fixture_bridge_method", ""))
			== FIXTURE_BRIDGE_METHOD,
		"Showcase exposes one canonical fixture bridge"
	)

	for episode_variant in episodes:
		if not (episode_variant is Dictionary):
			_failures.append("episode plan row is not a dictionary")
			continue
		var episode := episode_variant as Dictionary
		await _capture_episode(showcase, episode, evidence_root)

	var performance := showcase.call("performance_snapshot") as Dictionary
	var director_debug := showcase.call("animation_debug_snapshot") as Dictionary
	var final_contract := showcase.call("get_showcase_contract") as Dictionary
	var fixture_bridge := final_contract.get("fixture_bridge", {}) as Dictionary
	_expect(
		int(director_debug.get("receipt_collision_count", -1)) == 0
		and int(director_debug.get("receipt_rejection_count", -1)) == 0
		and int(director_debug.get("queued_cue_count", -1)) == 0,
		"capture leaves the unique Director collision-free and drained"
	)
	_expect(_write_json("%s/performance_report.json" % evidence_root, {
		"schema": "V076CommercialPresentationPerformanceReportV1",
		"status": "AUTOMATION_GREEN_PENDING_VISUAL_REVIEW" if _failures.is_empty() else "FAIL",
		"measurement_class": "CAPTURE_IO_INCLUDED_INFORMATIONAL",
		"milestone_performance_claim_allowed": false,
		"threshold_evaluation": "DELEGATED_TO_V076_PHASE7_SOUND_MOTION_PERFORMANCE_GATE",
		"fixture_class": FIXTURE_CLASS,
		"natural_gameplay": false,
		"gameplay_green": false,
		"human_green": false,
		"production_green": false,
		"human_retest_deferred": true,
		"step13_status": "PENDING",
		"capture_size": _size_data(CAPTURE_SIZE),
		"capture_io_included_in_live_samples": true,
		"milestone_threshold_source": "V076_PHASE7_SOUND_MOTION_PERFORMANCE_GATE",
		"director_performance": performance,
		"episode_count": _episode_records.size(),
		"frame_count": _captured_frame_count,
		"fixture_bridge": fixture_bridge,
	}), "performance report writes atomically")
	_expect(_write_json("%s/animation_exact_once_report.json" % evidence_root, {
		"schema": "V076CommercialPresentationExactOnceReportV1",
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"fixture_class": FIXTURE_CLASS,
		"natural_gameplay": false,
		"human_green": false,
		"production_green": false,
		"episode_count": _exact_once_rows.size(),
		"rows": _exact_once_rows,
		"receipt_collision_count": int(director_debug.get(
			"receipt_collision_count", -1
		)),
		"animation_gameplay_mutation_count": int(director_debug.get(
			"animation_gameplay_mutation_count", -1
		)),
		"animation_rng_draw_delta": int(director_debug.get(
			"animation_rng_draw_delta", -1
		)),
		"animation_authority_sequence_delta": int(director_debug.get(
			"animation_authority_sequence_delta", -1
		)),
		"fixture_bridge": fixture_bridge,
	}), "animation exact-once report writes atomically")
	_expect(_write_json("%s/fixture_bridge_report.json" % evidence_root, {
		"schema": "V076CommercialPresentationFixtureBridgeReportV1",
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"fixture_class": FIXTURE_CLASS,
		"natural_gameplay": false,
		"human_green": false,
		"production_green": false,
		"bridge": fixture_bridge,
	}), "fixture bridge report writes atomically")
	_expect(_write_json("%s/showcase_capture_manifest.json" % evidence_root, {
		"schema": "V076CommercialPresentationCaptureManifestV1",
		"status": "AUTOMATION_GREEN_PENDING_VISUAL_REVIEW" if _failures.is_empty() else "FAIL",
		"captured_at_utc": Time.get_datetime_string_from_system(true, true),
		"fixture_class": FIXTURE_CLASS,
		"fixture_banner_text": FIXTURE_BANNER_TEXT,
		"natural_gameplay": false,
		"gameplay_green": false,
		"human_green": false,
		"production_green": false,
		"human_retest_deferred": true,
		"step13_status": "PENDING",
		"canonical_showcase_scene": SHOWCASE_SCENE,
		"production_main_scene": str(contract.get(
			"production_main_scene_path", ""
		)),
		"capture_size": _size_data(CAPTURE_SIZE),
		"episode_count": _episode_records.size(),
		"frame_count": _captured_frame_count,
		"episodes": _episode_records,
		"frames": _capture_records,
		"fixture_bridge": fixture_bridge,
		"headed_client_capture_path": headed_capture_path,
		"headed_client_probe_requested": not ready_path.is_empty(),
	}), "showcase capture manifest writes atomically")
	if not ready_path.is_empty():
		await _complete_headed_probe(
			ready_path,
			ack_path,
			probe_nonce,
			expected_size_label,
			headed_capture_path
		)

	root.remove_child(showcase)
	showcase.queue_free()
	await process_frame
	_finish()


func _capture_episode(
	showcase: Control,
	episode: Dictionary,
	evidence_root: String
) -> void:
	var episode_id := str(episode.get("episode_id", ""))
	var output_dir := str(episode.get("capture_directory", ""))
	var expected_cue_id := str(episode.get("expected_cue_id", ""))
	var director_applicable := bool(episode.get(
		"director_applicable", true
	))
	_expect(not episode_id.is_empty(), "episode id is non-empty")
	_expect(not output_dir.is_empty(), "%s has an output directory" % episode_id)
	var episode_root := "%s/%s" % [evidence_root, output_dir]
	DirAccess.make_dir_recursive_absolute(episode_root)
	var prepared := bool(showcase.call("prepare_episode", episode_id))
	_expect(prepared, "%s prepares against the production main" % episode_id)
	if not prepared:
		return
	await _pump_frames(4)
	var frame_records: Array[Dictionary] = []
	for phase_variant in FRAME_PHASES:
		var phase := str(phase_variant)
		_expect(
			bool(showcase.call("set_episode_frame", episode_id, phase)),
			"%s applies %s frame" % [episode_id, phase]
		)
		await _pump_frames(5)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		var png_path := "%s/%s.png" % [episode_root, phase]
		var image := root.get_texture().get_image()
		var save_error := image.save_png(png_path) if image != null else ERR_CANT_CREATE
		_expect(save_error == OK, "%s %s PNG saves" % [episode_id, phase])
		var evidence := showcase.call("get_episode_evidence") as Dictionary
		var png_record := _png_record(png_path, image)
		png_record["episode_id"] = episode_id
		png_record["frame_phase"] = phase
		png_record["fixture_banner_visible"] = bool(
			(evidence.get("surface_state", {}) as Dictionary).get(
				"fixture_banner_visible", false
			)
		)
		_capture_records.append(png_record.duplicate(true))
		frame_records.append({
			"phase": phase,
			"png": png_record,
			"evidence": evidence,
		})
		_captured_frame_count += 1
		_expect(
			int(png_record.get("width", 0)) == CAPTURE_SIZE.x
			and int(png_record.get("height", 0)) == CAPTURE_SIZE.y,
			"%s %s PNG is exact 1600x960" % [episode_id, phase]
		)
		_expect(
			bool(png_record.get("fixture_banner_visible", false)),
			"%s %s keeps the fixture banner visible" % [episode_id, phase]
		)
		var authority_before := str(evidence.get(
			"authority_boundary_hash_before", ""
		))
		var authority_after := str(evidence.get(
			"authority_boundary_hash_after", ""
		))
		var authority_guard := evidence.get("authority_guard", {}) as Dictionary
		_expect(
			authority_before.length() == 64
			and authority_before == authority_after
			and bool(evidence.get("authority_projection_consistent", false))
			and bool(authority_guard.get("valid", false))
			and int(authority_guard.get("missing_component_count", -1)) == 0,
			"%s %s leaves authority unchanged" % [episode_id, phase]
		)
		_expect(
			bool(evidence.get("anchor_resolution_valid", false))
			and int(evidence.get("source_anchor_resolution_count", 0)) == 1
			and int(evidence.get("target_anchor_resolution_count", 0)) == 1
			and int(evidence.get("anchor_fallback_count", -1)) == 0,
			"%s %s uses two exact production anchors without fallback"
				% [episode_id, phase]
		)
		_expect(
			_zero_mutation_evidence(evidence),
			"%s %s has zero presentation mutation deltas" % [episode_id, phase]
		)
		var fixture_bridge := evidence.get("fixture_bridge", {}) as Dictionary
		_expect(
			str(fixture_bridge.get("schema", "")) == FIXTURE_BRIDGE_SCHEMA
			and int(fixture_bridge.get("bridge_instance_count", 0)) == 1
			and str(fixture_bridge.get("bridge_method", ""))
				== FIXTURE_BRIDGE_METHOD
			and bool(fixture_bridge.get("host_lifecycle_unchanged", false))
			and int(fixture_bridge.get("fixture_created_session_count", -1)) == 0
			and int(fixture_bridge.get("fixture_save_request_count", -1)) == 0
			and int(fixture_bridge.get("fixture_rng_draw_count", -1)) == 0
			and int(fixture_bridge.get("fixture_tick_advance_count", -1)) == 0,
			"%s %s uses one read-only fixture bridge" % [episode_id, phase]
		)
	var replay := showcase.call("replay_active_receipt") as Dictionary
	var finished := bool(showcase.call("finish_episode"))
	var final_evidence := showcase.call("get_episode_evidence") as Dictionary
	var actual_cue := final_evidence.get("animation_cue", {}) as Dictionary
	_expect(
		str(actual_cue.get("cue_id", "")) == expected_cue_id,
		"%s expected cue equals actual queued/surface cue" % episode_id
	)
	_expect(
		bool(replay.get("suppressed", false)),
		"%s byte-equivalent receipt replay is suppressed" % episode_id
	)
	_expect(finished, "%s finishes exactly once" % episode_id)
	_expect(
		int(final_evidence.get("enqueue_count", 0)) == 1
		and int(final_evidence.get("finish_count", 0)) == 1,
		"%s has one enqueue and one finish" % episode_id
	)
	var episode_director_debug := showcase.call(
		"animation_debug_snapshot"
	) as Dictionary
	_expect(
		int(episode_director_debug.get("queued_cue_count", -1)) == 0
		and int(episode_director_debug.get("receipt_collision_count", -1)) == 0
		and int(episode_director_debug.get("receipt_rejection_count", -1)) == 0,
		"%s drains the Director without collision or rejection" % episode_id
	)
	_expect(
		bool(final_evidence.get("final_rect_matches_target", false)),
		"%s end Rect matches the target Rect" % episode_id
	)
	var evidence_document := {
		"schema": "V076CommercialPresentationEpisodeCaptureV1",
		"status": "PASS" if _failures.is_empty() else "IN_PROGRESS",
		"episode_id": episode_id,
		"fixture_class": FIXTURE_CLASS,
		"natural_gameplay": false,
		"gameplay_green": false,
		"human_green": false,
		"production_green": false,
		"receipt_source_class": FIXTURE_CLASS,
		"authority_receipt": false,
		"director_exact_once_applicable": director_applicable,
		"exact_once_mode": (
			"DIRECTOR_RECEIPT"
			if director_applicable
			else "SHOWCASE_EPISODE_APPLICATION"
		),
		"expected_cue_id": expected_cue_id,
		"actual_cue_id": str(actual_cue.get("cue_id", "")),
		"frames": frame_records,
		"replay": replay,
		"finished": finished,
		"fixture_bridge": final_evidence.get("fixture_bridge", {}),
		"final_evidence": final_evidence,
	}
	var evidence_path := "%s/evidence.json" % episode_root
	_expect(
		_write_json(evidence_path, evidence_document),
		"%s evidence JSON writes atomically" % episode_id
	)
	var evidence_hash := (
		FileAccess.get_sha256(evidence_path)
		if FileAccess.file_exists(evidence_path)
		else ""
	)
	_episode_records.append({
		"episode_id": episode_id,
		"output_dir": output_dir,
		"expected_cue_id": expected_cue_id,
		"actual_cue_id": str(actual_cue.get("cue_id", "")),
		"evidence_path": _project_relative_path(evidence_path),
		"evidence_sha256": evidence_hash,
		"frame_count": frame_records.size(),
		"status": "PASS",
	})
	_exact_once_rows.append({
		"episode_id": episode_id,
		"receipt_id": str((final_evidence.get("receipt", {}) as Dictionary).get(
			"receipt_id", ""
		)),
		"cue_id": str(actual_cue.get("cue_id", "")),
		"director_exact_once_applicable": director_applicable,
		"enqueue_count": int(final_evidence.get("enqueue_count", 0)),
		"finish_count": int(final_evidence.get("finish_count", 0)),
		"duplicate_suppressed": bool(replay.get("suppressed", false)),
		"authority_unchanged": bool(final_evidence.get(
			"authority_projection_consistent", false
		)),
		"zero_mutation": _zero_mutation_evidence(final_evidence),
		"fixture_bridge": final_evidence.get("fixture_bridge", {}),
		"remaining_active_count": int((showcase.call(
			"animation_debug_snapshot"
		) as Dictionary).get("queued_cue_count", -1)),
	})


func _complete_headed_probe(
	ready_path: String,
	ack_path: String,
	probe_nonce: String,
	expected_size_label: String,
	capture_path: String
) -> void:
	_expect(DisplayServer.get_name() != "headless", "capture uses a headed display server")
	_expect(root.size == CAPTURE_SIZE, "headed root viewport is exact 1600x960")
	var native_hwnd := 0
	if DisplayServer.get_name() != "headless":
		native_hwnd = int(DisplayServer.window_get_native_handle(
			DisplayServer.WINDOW_HANDLE
		))
	var ready_payload := {
		"schema": "space_syndicate.v076.commercial_showcase_ready.v1",
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"process_id": OS.get_process_id(),
		"expected_client_size": expected_size_label,
		"probe_nonce": probe_nonce,
		"capture_path": capture_path,
		"native_hwnd_decimal": native_hwnd,
		"fixture_class": FIXTURE_CLASS,
		"natural_gameplay": false,
		"human_green": false,
		"episode_count": _episode_records.size(),
		"frame_count": _captured_frame_count,
	}
	_expect(_write_json(ready_path, ready_payload), "headed ready payload writes")
	var ack := await _wait_for_ack(ack_path, probe_nonce, 30000)
	_expect(not ack.is_empty(), "external headed client probe acknowledgement arrives")
	if not ack.is_empty():
		_expect(str(ack.get("status", "")) == "PASS", "external headed probe passes")
		_expect(
			int(ack.get("process_id", 0)) == OS.get_process_id(),
			"external headed probe binds this Godot PID"
		)
		_expect(
			int(ack.get("client_width", 0)) == CAPTURE_SIZE.x
			and int(ack.get("client_height", 0)) == CAPTURE_SIZE.y,
			"external headed client capture is exact 1600x960"
		)


func _prepare_capture_window() -> void:
	root.size = CAPTURE_SIZE
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(CAPTURE_SIZE)


func _png_record(path: String, image: Image) -> Dictionary:
	var image_size := image.get_size() if image != null else Vector2i.ZERO
	return {
		"path": _project_relative_path(path),
		"width": image_size.x,
		"height": image_size.y,
		"byte_length": (
			FileAccess.get_file_as_bytes(path).size()
			if FileAccess.file_exists(path)
			else 0
		),
		"sha256": (
			FileAccess.get_sha256(path)
			if FileAccess.file_exists(path)
			else ""
		),
	}


func _zero_mutation_evidence(evidence: Dictionary) -> bool:
	for key in [
		"animation_gameplay_mutation_count",
		"animation_rng_draw_delta",
		"animation_authority_sequence_delta",
		"animation_deck_order_mutation_count",
		"animation_card_zone_mutation_count",
		"animation_facility_state_mutation_count",
	]:
		if int(evidence.get(key, -1)) != 0:
			return false
	return true


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_json(path: String, payload: Dictionary) -> bool:
	if path.is_empty():
		return false
	var absolute_path := _absolute_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var temporary_path := "%s.%d.tmp" % [absolute_path, OS.get_process_id()]
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	return DirAccess.rename_absolute(temporary_path, absolute_path) == OK


func _wait_for_ack(path: String, nonce: String, timeout_msec: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(path):
			var payload := _load_json(path)
			if str(payload.get("probe_nonce", "")) == nonce:
				return payload
		await create_timer(0.05).timeout
	return {}


func _absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _project_relative_path(path: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var normalized := path.replace("\\", "/")
	var normalized_root := project_root.replace("\\", "/")
	if normalized.begins_with(normalized_root + "/"):
		return normalized.trim_prefix(normalized_root + "/")
	return normalized


func _argument_value(prefix: String, fallback: String) -> String:
	for argument_variant in OS.get_cmdline_args():
		var argument := str(argument_variant)
		if argument.begins_with("%s=" % prefix):
			return argument.trim_prefix("%s=" % prefix)
	return fallback


func _size_data(value: Vector2i) -> Dictionary:
	return {"width": value.x, "height": value.y}


func _pump_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print((
		"V076_PHASE8_COMMERCIAL_PRESENTATION_CAPTURE"
		+ "|status=%s|fixture_class=%s|natural_gameplay=false"
		+ "|human_green=false|episodes=%d|frames=%d|checks=%d|failures=%d"
		) % [
			status,
			FIXTURE_CLASS,
			_episode_records.size(),
			_captured_frame_count,
			_checks,
			_failures.size(),
		]
	)
	if not _failures.is_empty():
		for failure in _failures:
			printerr("- %s" % failure)
	quit(0 if _failures.is_empty() else 1)
