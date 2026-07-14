extends Control

const OUTPUT_DIR := "res://reports/ui/card_visual_polish_v01"
const MANIFEST_PATH := "res://data/art/card_illustration_manifest_v06.json"
const CARD_SCENE_PATH := "res://scenes/CardUI.tscn"
const CAPTURE_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 960),
	Vector2i(1920, 1080),
]
const STATE_SIZE := Vector2i(1600, 960)
const SETTLE_SECONDS := 0.8
const STATE_CARDS := {
	"hovered": "supply_demand.remote_sea_order.rank_1",
	"disabled": "supply_demand.near_land_supply.rank_1",
	"drop_valid": "unit.monster.spore_tide_emperor.rank_1",
}

@onready var _lab: Control = %CardUISkinLab

var _manifest: Dictionary = {}
var _failures := 0
var _captures := 0
var _normal_1600: Image
var _disabled_1600: Image


func _ready() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_log("suite_start", "OK", {
		"scene": "res://scenes/tools/CardVisualPolishCapture.tscn",
		"output": OUTPUT_DIR,
	})
	if not _prepare_output_dir() or not _load_manifest():
		_finish()
		return

	_validate_manifest_calibration()
	for capture_size in CAPTURE_SIZES:
		_lab.call("set_lab_state", "normal")
		await _set_capture_size(capture_size)
		var image := await _capture(
			"card_visual_polish_%dx%d.png" % [capture_size.x, capture_size.y],
			"normal_%dx%d" % [capture_size.x, capture_size.y],
			capture_size
		)
		if capture_size == Vector2i(1280, 720):
			_validate_1280_layout()
		if capture_size == STATE_SIZE and image != null:
			_normal_1600 = image.duplicate()

	await _set_capture_size(STATE_SIZE)
	await _capture_state("disabled", "after_disabled_1600x960.png")
	await _capture_state("hovered", "remote_sea_order_hovered_1600x960.png")
	await _capture_state("drop_valid", "spore_tide_emperor_drop_valid_1600x960.png")
	_validate_disabled_pixel_gate()
	_validate_player_text_boundary()
	await _validate_fallbacks()
	_finish()


func _capture_state(state_id: String, file_name: String) -> void:
	_lab.call("set_lab_state", state_id)
	await _settle()
	_validate_state_source(state_id)
	if state_id == "drop_valid":
		_validate_target_feedback()
	var image := await _capture(file_name, state_id, STATE_SIZE)
	if state_id == "disabled" and image != null:
		_disabled_1600 = image.duplicate()


func _load_manifest() -> bool:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_fail("manifest", "E_OPEN", {"path": MANIFEST_PATH})
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("style_keys", {}) is Dictionary):
		_fail("manifest", "E_JSON", {"path": MANIFEST_PATH})
		return false
	_manifest = ((parsed as Dictionary).get("style_keys", {}) as Dictionary).duplicate(true)
	_log("manifest", "OK", {"entries": _manifest.size()})
	return true


func _validate_manifest_calibration() -> void:
	var authored_cards := [
		"commodity.ring_crystal_battery.rank_1",
		"supply_demand.remote_sea_order.rank_1",
		"supply_demand.near_land_supply.rank_1",
		"unit.monster.spore_tide_emperor.rank_1",
	]
	for card_id in authored_cards:
		var profile := _manifest.get(card_id, {}) as Dictionary
		var path := str(profile.get("illustration_path", ""))
		var valid := (
			str(profile.get("source_type", "")) == "authored"
			and path.begins_with("res://assets/art/cards/")
			and FileAccess.file_exists(path)
			and str(profile.get("fit_mode", "")) == "cover"
			and str(profile.get("tint_mode", "")) == "preserve"
			and str(profile.get("sha256", "")).length() == 64
		)
		if not valid:
			_failures += 1
		_log("authored_profile", "OK" if valid else "E_PROFILE", {
			"card": card_id,
			"path": path,
			"motif": profile.get("semantic_motif", ""),
			"overlay": profile.get("overlay_intensity", -1.0),
		})
	var remote := _manifest.get("supply_demand.remote_sea_order.rank_1", {}) as Dictionary
	var remote_valid := (
		str(remote.get("illustration_path", "")).ends_with("remote_sea_order_v02.png")
		and str(remote.get("visual_source_id", "")).ends_with("remote_sea_order_v02")
		and remote.get("superseded_candidate", {}) is Dictionary
	)
	if not remote_valid:
		_failures += 1
	_log("remote_v02_chain", "OK" if remote_valid else "E_PROVENANCE", {
		"visual_source": remote.get("visual_source_id", ""),
		"status": remote.get("status", ""),
	})


func _validate_state_source(state_id: String) -> void:
	var expected_card := str(STATE_CARDS.get(state_id, ""))
	var expected := _manifest.get(expected_card, {}) as Dictionary
	var inspector := _lab.find_child("InspectorCardFace", true, false) as Control
	if inspector == null or not inspector.has_method("get_card_data"):
		_fail("state_source", "E_INSPECTOR", {"state": state_id})
		return
	var card_data := inspector.call("get_card_data") as Dictionary
	var layer := inspector.find_child("IllustrationLayer", true, false) as Control
	var snapshot := layer.call("get_debug_snapshot") as Dictionary if layer != null and layer.has_method("get_debug_snapshot") else {}
	var valid := (
		str(card_data.get("id", "")) == expected_card
		and bool(inspector.get_meta("external_illustration_active", false))
		and str(inspector.get_meta("illustration_visual_source_id", "")) == str(expected.get("visual_source_id", ""))
		and str(snapshot.get("semantic_motif", "")) == str(expected.get("semantic_motif", ""))
	)
	var expected_resolved: String = {
		"hovered": "sea_route_arc",
		"disabled": "supply_stream",
		"drop_valid": "miasma_field",
	}.get(state_id, "")
	valid = valid and str(snapshot.get("resolved_motif", "")) == expected_resolved
	if not valid:
		_failures += 1
	_log("state_source", "OK" if valid else "E_SOURCE", {
		"state": state_id,
		"card": card_data.get("id", ""),
		"visual_source": inspector.get_meta("illustration_visual_source_id", ""),
		"resolved_motif": snapshot.get("resolved_motif", ""),
		"visual_state": inspector.get_meta("card_visual_state", ""),
	})
	if state_id == "disabled":
		var reason := str(card_data.get("disabled_reason", "")).strip_edges()
		var next_step := str(card_data.get("next_step", "")).strip_edges()
		var copy_valid := reason != "" and next_step != "" and reason.contains("无法") and reason.contains("先")
		if not copy_valid:
			_failures += 1
		_log("disabled_copy", "OK" if copy_valid else "E_COPY", {"reason_chars": reason.length(), "next_step_chars": next_step.length()})


func _validate_target_feedback() -> void:
	var drop_target := _lab.find_child("DropTarget", true, false) as Control
	var targeting := _lab.find_child("TargetingOverlay", true, false) as Control
	var valid := drop_target != null and drop_target.visible and targeting != null and targeting.visible
	if not valid:
		_failures += 1
	_log("target_feedback", "OK" if valid else "E_TARGET_FEEDBACK", {
		"drop_slot": drop_target != null and drop_target.visible,
		"connection": targeting != null and targeting.visible,
	})


func _validate_1280_layout() -> void:
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var names := ["HeaderBridge", "CommodityBelt", "HandShelf", "InspectorShell", "TargetDemoButton", "SettlementDemoButton"]
	for node_name in names:
		var control := _lab.find_child(node_name, true, false) as Control
		var valid := control != null and control.visible and viewport_rect.encloses(control.get_global_rect().grow(-0.5))
		if not valid:
			_failures += 1
		_log("layout_1280", "OK" if valid else "E_BOUNDS", {
			"node": node_name,
			"rect": str(control.get_global_rect()) if control != null else "missing",
		})


func _validate_disabled_pixel_gate() -> void:
	if _normal_1600 == null or _disabled_1600 == null:
		_fail("disabled_pixel_gate", "E_IMAGES", {})
		return
	var region := Rect2i(300, 300, 800, 400)
	var changed_dark := 0
	var total := region.size.x * region.size.y
	var abs_delta := 0.0
	var normal_dark := 0
	var disabled_dark := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var before := _normal_1600.get_pixel(x, y)
			var after := _disabled_1600.get_pixel(x, y)
			var delta := (absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b)) / 3.0
			abs_delta += delta
			if before.get_luminance() < 0.02:
				normal_dark += 1
			if after.get_luminance() < 0.02:
				disabled_dark += 1
			if before.get_luminance() - after.get_luminance() > 0.30:
				changed_dark += 1
	var mean_delta := abs_delta / float(total)
	var changed_ratio := float(changed_dark) / float(total)
	var dark_ratio_delta := absf(float(disabled_dark - normal_dark) / float(total))
	var valid := mean_delta < 0.02 and changed_ratio < 0.005 and dark_ratio_delta < 0.005
	if not valid:
		_failures += 1
	_log("disabled_pixel_gate", "OK" if valid else "E_OVERFLOW", {
		"region": "300,300,800,400",
		"mean_rgb_delta": "%.6f" % mean_delta,
		"large_darkening_ratio": "%.6f" % changed_ratio,
		"dark_ratio_delta": "%.6f" % dark_ratio_delta,
	})


func _validate_player_text_boundary() -> void:
	if not _lab.has_method("get_player_text_leak_report"):
		_fail("player_text", "E_API", {})
		return
	var report := _lab.call("get_player_text_leak_report") as Dictionary
	var count := int(report.get("leak_count", -1))
	if count != 0:
		_failures += 1
	_log("player_text", "OK" if count == 0 else "E_LEAK", {"leaks": count, "clean": report.get("clean", false)})


func _validate_fallbacks() -> void:
	var packed := load(CARD_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("fallback", "E_SCENE", {})
		return
	var probes := [
		{"case": "path_not_allowed", "path": "res://docs/not_an_illustration.png"},
		{"case": "path_not_allowed", "path": "res://assets/art/cards/../third_party/traversal_probe.png"},
		{"case": "missing_texture", "path": "res://assets/art/cards/v06/__missing_visual_polish_probe__.png"},
	]
	for probe in probes:
		var card := packed.instantiate() as Control
		card.visible = false
		card.position = Vector2(-4096.0, -4096.0)
		add_child(card)
		await get_tree().process_frame
		card.call("set_card_data", {
			"id": "qa.fallback",
			"name": "回退验证",
			"type": "商品牌",
			"industry": "科技",
			"tier": "I",
			"short_effect": "仅用于回退验证。",
			"illustration_path": probe.path,
			"illustration_profile": {"source_type": "authored", "visual_source_id": "qa_probe"},
			"illustration_silent_fallback": true,
		})
		await get_tree().process_frame
		var reason := str(card.get_meta("illustration_fallback_reason", ""))
		var valid := not bool(card.get_meta("external_illustration_active", false)) and reason == str(probe.case)
		if not valid:
			_failures += 1
		_log("fallback", "OK" if valid else "E_FALLBACK", {"case": probe.case, "reason": reason})
		card.queue_free()
		await get_tree().process_frame


func _prepare_output_dir() -> bool:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if error != OK:
		_fail("output_dir", "E_CREATE", {"error": error})
		return false
	return true


func _set_capture_size(value: Vector2i) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = value
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(value)
	await _settle()
	_log("window", "OK", {"requested": _size_text(value), "actual": _size_text(get_window().size)})


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _capture(file_name: String, case_name: String, expected_size: Vector2i) -> Image:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("capture", "E_IMAGE", {"case": case_name})
		return null
	if image.get_size() != expected_size:
		_fail("capture", "E_SIZE", {"case": case_name, "actual": _size_text(image.get_size()), "expected": _size_text(expected_size)})
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_fail("capture", "E_SAVE", {"case": case_name, "error": error})
		return null
	_captures += 1
	_log("capture", "OK", {"case": case_name, "file": path, "size": _size_text(image.get_size())})
	return image


func _finish() -> void:
	var code := "OK" if _failures == 0 else "E_SUITE"
	_log("suite_complete", code, {"captures": _captures, "failures": _failures})
	set_meta("capture_exit_code", 0 if _failures == 0 else 1)
	_log("awaiting_mcp_stop", code, {"detail": "验证完成，等待 Godot MCP 停止项目。"})


func _fail(event_name: String, code: String, fields: Dictionary) -> void:
	_failures += 1
	_log(event_name, code, fields)


func _log(event_name: String, code: String, fields: Dictionary = {}) -> void:
	var parts: Array[String] = ["CARD_VISUAL_POLISH", "event=%s" % event_name, "code=%s" % code]
	var keys := fields.keys()
	keys.sort()
	for key in keys:
		parts.append("%s=%s" % [str(key), str(fields.get(key)).replace("|", "/").replace("\n", " ")])
	print("|".join(parts))


func _size_text(value: Vector2i) -> String:
	return "%dx%d" % [value.x, value.y]
