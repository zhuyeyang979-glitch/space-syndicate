extends Control

const OUTPUT_DIR := "res://reports/art/card_style_lock_batch_v01"
const MANIFEST_PATH := "res://data/art/card_illustration_manifest_v06.json"
const CARD_SCENE_PATH := "res://scenes/CardUI.tscn"
const CAPTURE_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 960),
	Vector2i(1920, 1080),
]
const STATE_CAPTURE_SIZE := Vector2i(1600, 960)
const TARGET_STATES: Array[StringName] = [
	&"hovered",
	&"disabled",
	&"drop_valid",
]
const STATE_CARD_IDS := {
	"hovered": "supply_demand.remote_sea_order.rank_1",
	"disabled": "supply_demand.near_land_supply.rank_1",
	"drop_valid": "unit.monster.spore_tide_emperor.rank_1",
}
const SETTLEMENT_CARD_ID := "interaction.phase_veto.rank_1"
const SETTLE_SECONDS := 1.0

@onready var _lab: Control = %CardUISkinLab

var _manifest: Dictionary = {}
var _failure_count := 0
var _capture_count := 0


func _ready() -> void:
	call_deferred("_run_capture_suite")


func _run_capture_suite() -> void:
	_log_event("suite_start", "OK", {
		"scene": "res://scenes/tools/CardStyleLockBatchCapture.tscn",
		"output_dir": OUTPUT_DIR,
		"successful_generated_assets": 3,
	})
	if not _prepare_output_dir() or not _load_manifest():
		_finish_suite()
		return

	await _set_capture_size(STATE_CAPTURE_SIZE)
	_lab.call("set_lab_state", "normal")
	await _settle_layout()
	_validate_target_manifest()
	_validate_hand_sources()
	_validate_settlement_source()
	await _validate_fallbacks()

	for capture_size in CAPTURE_SIZES:
		_lab.call("set_lab_state", "normal")
		await _set_capture_size(capture_size)
		await _capture_viewport(
			"resolution_%dx%d" % [capture_size.x, capture_size.y],
			"card_style_lock_batch_%dx%d.png" % [capture_size.x, capture_size.y],
			capture_size
		)

	await _set_capture_size(STATE_CAPTURE_SIZE)
	for state_name in TARGET_STATES:
		_lab.call("set_lab_state", state_name)
		await _settle_layout()
		_validate_inspector_source(str(state_name))
		await _capture_viewport(
			"state_%s" % state_name,
			"card_style_lock_%s_1600x960.png" % str(state_name),
			STATE_CAPTURE_SIZE
		)

	_validate_player_text_separation()
	_finish_suite()


func _load_manifest() -> bool:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_record_failure("manifest_load", "E_MANIFEST_OPEN", {"path": MANIFEST_PATH})
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_record_failure("manifest_load", "E_MANIFEST_JSON", {"path": MANIFEST_PATH})
		return false
	var styles_variant: Variant = (parsed as Dictionary).get("style_keys", {})
	if not (styles_variant is Dictionary):
		_record_failure("manifest_load", "E_MANIFEST_STYLE_KEYS", {})
		return false
	_manifest = (styles_variant as Dictionary).duplicate(true)
	var code := "OK" if _manifest.size() == 6 else "E_MANIFEST_COUNT"
	if _manifest.size() != 6:
		_failure_count += 1
	_log_event("manifest_load", code, {"entries": _manifest.size()})
	return true


func _validate_target_manifest() -> void:
	for state_name in TARGET_STATES:
		var card_id := str(STATE_CARD_IDS.get(str(state_name), ""))
		var profile_variant: Variant = _manifest.get(card_id, {})
		var profile: Dictionary = profile_variant if profile_variant is Dictionary else {}
		var superseded_variant: Variant = profile.get("superseded_placeholder", {})
		var valid := (
			not profile.is_empty()
			and str(profile.get("source_type", "")) == "authored"
			and str(profile.get("status", "")) == "style_lock_candidate_v01"
			and str(profile.get("illustration_path", "")).begins_with("res://assets/art/cards/")
			and str(profile.get("fit_mode", "")) == "cover"
			and str(profile.get("tint_mode", "")) == "preserve"
			and str(profile.get("texture_filter", "")) == "linear"
			and str(profile.get("sha256", "")).length() == 64
			and superseded_variant is Dictionary
			and not (superseded_variant as Dictionary).is_empty()
		)
		if not valid:
			_failure_count += 1
		_log_event("target_manifest", "OK" if valid else "E_TARGET_MANIFEST", {
			"card": card_id,
			"source_type": profile.get("source_type", ""),
			"status": profile.get("status", ""),
			"visual_source": profile.get("visual_source_id", ""),
		})


func _validate_hand_sources() -> void:
	var hand_rack := _lab.find_child("HandRack", true, false) as Control
	if hand_rack == null:
		_record_failure("hand_source_audit", "E_HAND_RACK_MISSING", {})
		return
	var seen_ids: Dictionary = {}
	var seen_sources: Dictionary = {}
	var external_count := 0
	var authored_count := 0
	var open_source_count := 0
	for child in hand_rack.get_children():
		if not (child is Control) or not child.has_method("get_card_data"):
			continue
		var card := child as Control
		var data_variant: Variant = card.call("get_card_data")
		var card_data: Dictionary = data_variant if data_variant is Dictionary else {}
		var card_id := str(card_data.get("id", ""))
		var source_id := str(card.get_meta("illustration_visual_source_id", ""))
		var source_type := str(card.get_meta("illustration_source_type", ""))
		var expected_variant: Variant = _manifest.get(card_id, {})
		var expected: Dictionary = expected_variant if expected_variant is Dictionary else {}
		var active := bool(card.get_meta("external_illustration_active", false))
		var valid := active and source_id == str(expected.get("visual_source_id", "")) and source_id != ""
		if valid:
			external_count += 1
		else:
			_failure_count += 1
		seen_ids[card_id] = true
		if source_id != "":
			seen_sources[source_id] = true
		if source_type == "authored":
			authored_count += 1
		elif source_type == "open_source_placeholder":
			open_source_count += 1
		_log_event("hand_card_source", "OK" if valid else "E_SOURCE_MISMATCH", {
			"card": card_id,
			"active": active,
			"source_type": source_type,
			"visual_source": source_id,
		})
	var summary_valid := (
		seen_ids.size() == 6
		and seen_sources.size() == 6
		and external_count == 6
		and authored_count == 4
		and open_source_count == 2
	)
	if not summary_valid:
		_failure_count += 1
	_log_event("hand_source_audit", "OK" if summary_valid else "E_HAND_SOURCE_AUDIT", {
		"cards": seen_ids.size(),
		"unique_sources": seen_sources.size(),
		"external": external_count,
		"authored": authored_count,
		"open_source": open_source_count,
	})


func _validate_inspector_source(state_id: String) -> void:
	var inspector := _lab.find_child("InspectorCardFace", true, false) as Control
	if inspector == null or not inspector.has_method("get_card_data"):
		_record_failure("inspector_source", "E_INSPECTOR_CARD_MISSING", {"state": state_id})
		return
	var data_variant: Variant = inspector.call("get_card_data")
	var card_data: Dictionary = data_variant if data_variant is Dictionary else {}
	var card_id := str(card_data.get("id", ""))
	var expected_card_id := str(STATE_CARD_IDS.get(state_id, ""))
	var expected_variant: Variant = _manifest.get(expected_card_id, {})
	var expected: Dictionary = expected_variant if expected_variant is Dictionary else {}
	var source_id := str(inspector.get_meta("illustration_visual_source_id", ""))
	var inspector_layer := inspector.find_child("IllustrationLayer", true, false) as Control
	var snapshot: Dictionary = {}
	if inspector_layer != null and inspector_layer.has_method("get_debug_snapshot"):
		var snapshot_variant: Variant = inspector_layer.call("get_debug_snapshot")
		snapshot = snapshot_variant if snapshot_variant is Dictionary else {}
	var valid := (
		card_id == expected_card_id
		and bool(inspector.get_meta("external_illustration_active", false))
		and source_id == str(expected.get("visual_source_id", ""))
		and source_id != ""
		and str(snapshot.get("source_type", "")) == "authored"
		and str(snapshot.get("fit_mode", "")) == "cover"
		and str(snapshot.get("tint_mode", "")) == "preserve"
	)
	if not valid:
		_failure_count += 1
	_log_event("inspector_source", "OK" if valid else "E_INSPECTOR_SOURCE", {
		"state": state_id,
		"card": card_id,
		"visual_source": source_id,
		"source_type": snapshot.get("source_type", ""),
		"fit_mode": snapshot.get("fit_mode", ""),
		"tint_mode": snapshot.get("tint_mode", ""),
	})


func _validate_settlement_source() -> void:
	var settlement := _lab.find_child("SettlementCardFace", true, false) as Control
	if settlement == null or not settlement.has_method("get_card_data"):
		_record_failure("settlement_source", "E_SETTLEMENT_CARD_MISSING", {})
		return
	var data_variant: Variant = settlement.call("get_card_data")
	var card_data: Dictionary = data_variant if data_variant is Dictionary else {}
	var expected_variant: Variant = _manifest.get(SETTLEMENT_CARD_ID, {})
	var expected: Dictionary = expected_variant if expected_variant is Dictionary else {}
	var card_id := str(card_data.get("id", ""))
	var source_id := str(settlement.get_meta("illustration_visual_source_id", ""))
	var valid := (
		card_id == SETTLEMENT_CARD_ID
		and bool(settlement.get_meta("external_illustration_active", false))
		and source_id == str(expected.get("visual_source_id", ""))
		and str(settlement.get_meta("illustration_source_type", "")) == "open_source_placeholder"
	)
	if not valid:
		_failure_count += 1
	_log_event("settlement_source", "OK" if valid else "E_SETTLEMENT_SOURCE", {
		"card": card_id,
		"visual_source": source_id,
	})


func _validate_fallbacks() -> void:
	var card_scene := load(CARD_SCENE_PATH) as PackedScene
	if card_scene == null:
		_record_failure("fallback_probe", "E_CARD_SCENE_LOAD", {"path": CARD_SCENE_PATH})
		return
	var probes := [
		{
			"case": "path_not_allowed",
			"path": "res://docs/not_an_illustration.png",
			"profile": {"source_type": "authored", "visual_source_id": "qa_disallowed"},
		},
		{
			"case": "missing_texture",
			"path": "res://assets/art/cards/v06/missing_style_lock_candidate.png",
			"profile": {"source_type": "authored", "visual_source_id": "qa_missing"},
		},
	]
	for probe_variant in probes:
		var probe: Dictionary = probe_variant
		var card := card_scene.instantiate() as Control
		card.visible = false
		card.position = Vector2(-4096.0, -4096.0)
		card.size = Vector2(180.0, 246.0)
		add_child(card)
		await get_tree().process_frame
		card.call("set_card_data", {
			"id": "qa.%s" % str(probe.get("case", "fallback")),
			"name": "验证卡",
			"type": "商品牌",
			"industry": "科技",
			"tier": "I",
			"short_effect": "仅用于回退验证。",
			"illustration_path": str(probe.get("path", "")),
			"illustration_profile": probe.get("profile", {}),
			"illustration_silent_fallback": true,
		})
		await get_tree().process_frame
		var expected_reason := str(probe.get("case", ""))
		var reason := str(card.get_meta("illustration_fallback_reason", ""))
		var art_view := card.find_child("ArtView", true, false) as Control
		var valid := (
			not bool(card.get_meta("external_illustration_active", false))
			and reason == expected_reason
			and art_view != null
			and art_view.visible
		)
		if not valid:
			_failure_count += 1
		_log_event("fallback_probe", "OK" if valid else "E_FALLBACK", {
			"case": expected_reason,
			"reason": reason,
			"procedural_visible": art_view != null and art_view.visible,
		})
		card.queue_free()
		await get_tree().process_frame


func _validate_player_text_separation() -> void:
	if not _lab.has_method("get_player_text_leak_report"):
		_record_failure("player_text_scan", "E_TEXT_SCAN_API", {})
		return
	var report_variant: Variant = _lab.call("get_player_text_leak_report")
	var report: Dictionary = report_variant if report_variant is Dictionary else {}
	var leak_count := int(report.get("leak_count", -1))
	if leak_count != 0:
		_failure_count += 1
	_log_event("player_text_scan", "OK" if leak_count == 0 else "E_PLAYER_TEXT_LEAK", {
		"clean": bool(report.get("clean", false)),
		"leaks": leak_count,
	})


func _prepare_output_dir() -> bool:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK:
		_record_failure("output_dir", "E_OUTPUT_DIR", {"path": OUTPUT_DIR, "error": error})
		return false
	_log_event("output_dir", "OK", {"path": OUTPUT_DIR})
	return true


func _set_capture_size(capture_size: Vector2i) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = capture_size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(capture_size)
	await _settle_layout()
	_log_event("window_ready", "OK", {
		"requested": _size_text(capture_size),
		"window": _size_text(get_window().size),
		"viewport": _size_text(Vector2i(get_viewport().get_visible_rect().size)),
	})


func _settle_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _capture_viewport(case_name: String, file_name: String, expected_size: Vector2i) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		_record_failure("capture", "E_VIEWPORT_TEXTURE", {"case": case_name})
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		_record_failure("capture", "E_VIEWPORT_IMAGE", {"case": case_name})
		return
	var actual_size := image.get_size()
	if actual_size != expected_size:
		_failure_count += 1
		_log_event("capture_size", "E_CAPTURE_SIZE_MISMATCH", {
			"case": case_name,
			"expected": _size_text(expected_size),
			"actual": _size_text(actual_size),
		})
	var resource_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var save_error := image.save_png(ProjectSettings.globalize_path(resource_path))
	if save_error != OK:
		_record_failure("capture", "E_PNG_SAVE", {"case": case_name, "file": resource_path, "error": save_error})
		return
	_capture_count += 1
	_log_event("capture_saved", "OK", {
		"case": case_name,
		"file": resource_path,
		"image": _size_text(actual_size),
	})


func _record_failure(event_name: String, code: String, fields: Dictionary) -> void:
	_failure_count += 1
	_log_event(event_name, code, fields)


func _finish_suite() -> void:
	var code := "OK" if _failure_count == 0 else "E_CAPTURE_SUITE"
	_log_event("suite_complete", code, {
		"captures": _capture_count,
		"failures": _failure_count,
		"successful_generated_assets": 3,
	})
	set_meta("capture_exit_code", 0 if _failure_count == 0 else 1)
	_log_event("awaiting_mcp_stop", code, {"detail": "验证完成，等待 Godot MCP 停止项目。"})


func _log_event(event_name: String, code: String, fields: Dictionary = {}) -> void:
	var parts: Array[String] = [
		"CARD_STYLE_LOCK_BATCH_CAPTURE",
		"event=%s" % _log_value(event_name),
		"code=%s" % _log_value(code),
	]
	var keys: Array = fields.keys()
	keys.sort()
	for key_variant in keys:
		parts.append("%s=%s" % [str(key_variant), _log_value(fields.get(key_variant))])
	print("|".join(parts))


func _log_value(value: Variant) -> String:
	return str(value).replace("|", "/").replace("\n", " ").replace("\r", " ")


func _size_text(dimensions: Vector2i) -> String:
	return "%dx%d" % [dimensions.x, dimensions.y]
