extends Control
class_name CodexNavigationRuntimeCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const SESSION_START_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/codex_navigation_runtime_cutover.save"
const CONTROLLER_SCENE := "res://scenes/runtime/CodexNavigationRuntimeController.tscn"
const CONTROLLER_SCRIPT := "res://scripts/runtime/codex_navigation_runtime_controller.gd"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/codex_navigation_runtime_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/codex_navigation_runtime_cutover_sprint_13.png"

const RETIRED_STATE_VARIABLES := [
	"menu_catalog_mode", "catalog_return_menu", "bestiary_index", "bestiary_grid_page",
	"bestiary_show_detail", "previewed_bestiary_index", "card_codex_index",
	"card_codex_filter", "card_codex_grid_page", "card_codex_show_detail",
	"previewed_card_codex_card", "product_codex_index", "product_codex_grid_page",
	"product_codex_show_detail", "previewed_product_codex_index", "region_codex_index",
	"role_codex_index",
]
const RETIRED_PAGINATION_FUNCTIONS := [
	"_bestiary_grid_page_count", "_bestiary_grid_page_for_index", "_bestiary_first_index_on_page",
	"_card_codex_grid_page_count", "_card_codex_grid_page_for_index", "_card_codex_first_index_on_page",
	"_product_codex_grid_page_count", "_product_codex_grid_page_for_index", "_product_codex_first_index_on_page",
]
const LEGACY_SAVE_KEYS := [
	"bestiary_index", "bestiary_grid_page", "bestiary_show_detail", "previewed_bestiary_index",
	"card_codex_index", "card_codex_filter", "product_codex_index", "product_codex_grid_page",
	"product_codex_show_detail", "previewed_product_codex_index", "region_codex_index", "role_codex_index",
]

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _controller: Node
var _main: Control
var _main_source := ""
var _records: Array = []
var _failures: Array[String] = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_state_variable_names() -> Array:
	return RETIRED_STATE_VARIABLES.duplicate()


func retired_pagination_function_names() -> Array:
	return RETIRED_PAGINATION_FUNCTIONS.duplicate()


func cutover_cases() -> Array:
	return [
		"required_controller_assets_load",
		"controller_scene_contract",
		"default_navigation_state",
		"catalog_mode_validation",
		"return_target_validation",
		"monster_navigation_state",
		"card_navigation_state",
		"product_navigation_state",
		"region_role_navigation_state",
		"pagination_boundaries",
		"navigation_snapshot_pure_data",
		"legacy_save_key_parity",
		"legacy_save_roundtrip",
		"card_transient_nonpersistence_parity",
		"coordinator_scene_composition",
		"coordinator_pure_data_proxy",
		"real_main_controller_composition",
		"real_main_catalog_routes_delegate",
		"real_main_v1_save_adapter_parity",
		"legacy_authority_and_helpers_absent",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "codex-navigation-runtime-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"retired_state_variable_count": RETIRED_STATE_VARIABLES.size(),
		"retired_pagination_function_count": RETIRED_PAGINATION_FUNCTIONS.size(),
		"records": records,
	}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	if not await _prepare_runtime():
		_failures.append("formal_four_player_session_unavailable")
		await _dispose_runtime()
		push_error("CodexNavigationRuntimeCutoverBench failed: formal session startup")
		get_tree().quit(1)
		return
	for case_id_variant: Variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {
		"suite": "codex-navigation-runtime-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"retired_state_variable_count": RETIRED_STATE_VARIABLES.size(),
		"retired_pagination_function_count": RETIRED_PAGINATION_FUNCTIONS.size(),
		"main_metrics": _main_metrics(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_runtime()
	_save_screenshot()
	print("CodexNavigationRuntimeCutoverBench manifest: %s" % MANIFEST_PATH)
	print("CodexNavigationRuntimeCutoverBench report: %s" % REPORT_PATH)
	print("CodexNavigationRuntimeCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("CodexNavigationRuntimeCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("CodexNavigationRuntimeCutoverBench failed:\n- %s" % "\n- ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _prepare_runtime() -> bool:
	var controller_packed := load(CONTROLLER_SCENE) as PackedScene
	_controller = controller_packed.instantiate() if controller_packed != null else null
	if _controller != null:
		add_child(_controller)
		_controller.call("configure", {})
	var start_result := await SESSION_START_DRIVER.start_default_session(get_tree(), QA_SAVE_PATH, "codex-navigation-runtime-cutover")
	_main = start_result.get("main_root") as Control
	if _main == null or not bool(start_result.get("started", false)):
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	return _controller != null


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"required_controller_assets_load":
			passed = load(CONTROLLER_SCRIPT) is Script and load(CONTROLLER_SCENE) is PackedScene and load(COORDINATOR_SCENE) is PackedScene
			flags["controller_checked"] = true
			notes = "controller script, editable scene, and coordinator composition load"
		"controller_scene_contract":
			passed = _controller != null
			for method_name in ["configure", "reset_navigation", "set_catalog_mode", "set_return_target", "domain_state", "update_domain", "page_count", "page_for_index", "first_index_on_page", "navigation_snapshot", "to_legacy_save_snapshot", "apply_legacy_save_snapshot", "debug_snapshot"]:
				passed = passed and _controller.has_method(method_name)
			flags["controller_checked"] = true
			notes = "controller exposes navigation, pagination, persistence, and debug APIs"
		"default_navigation_state":
			_controller.call("reset_navigation")
			var snapshot: Dictionary = _controller.call("navigation_snapshot")
			passed = str(snapshot.get("catalog_mode", "invalid")) == "" and str(snapshot.get("return_target", "")) == "main" and int((snapshot.get("monster", {}) as Dictionary).get("selected_index", -1)) == 0
			flags["state_checked"] = true
			notes = "default navigation state matches the retired main.gd values"
		"catalog_mode_validation":
			passed = str(_controller.call("set_catalog_mode", "monster")) == "monster" and str(_controller.call("set_catalog_mode", "invalid")) == ""
			flags["state_checked"] = true
			notes = "catalog mode accepts known branches and rejects unknown ids"
		"return_target_validation":
			passed = str(_controller.call("set_return_target", "intel")) == "intel" and str(_controller.call("set_return_target", "invalid")) == "main"
			flags["routing_checked"] = true
			notes = "return targets remain constrained to existing menu routes"
		"monster_navigation_state":
			var state: Dictionary = _controller.call("update_domain", "monster", {"selected_index": 4, "page_index": 2, "show_detail": true, "preview_index": 3})
			passed = int(state.get("selected_index", -1)) == 4 and int(state.get("page_index", -1)) == 2 and bool(state.get("show_detail", false)) and int(state.get("preview_index", -1)) == 3
			flags["state_checked"] = true
			notes = "monster selected/page/detail/preview state is controller-owned"
		"card_navigation_state":
			var state: Dictionary = _controller.call("update_domain", "card", {"selected_index": 5, "filter_id": "finance", "page_index": 1, "show_detail": true, "preview_id": "轨道融资1"})
			passed = int(state.get("selected_index", -1)) == 5 and str(state.get("filter_id", "")) == "finance" and str(state.get("preview_id", "")) == "轨道融资1"
			flags["state_checked"] = true
			notes = "card filter/page/detail/preview state is controller-owned"
		"product_navigation_state":
			var state: Dictionary = _controller.call("update_domain", "product", {"selected_index": 2, "page_index": 1, "show_detail": true, "preview_index": 2})
			passed = int(state.get("selected_index", -1)) == 2 and bool(state.get("show_detail", false)) and int(state.get("preview_index", -1)) == 2
			flags["state_checked"] = true
			notes = "product selected/page/detail/preview state is controller-owned"
		"region_role_navigation_state":
			var region: Dictionary = _controller.call("update_domain", "region", {"selected_index": 6})
			var role: Dictionary = _controller.call("update_domain", "role", {"selected_index": 3})
			passed = int(region.get("selected_index", -1)) == 6 and int(role.get("selected_index", -1)) == 3
			flags["state_checked"] = true
			notes = "region and role indices share the same scene-owned authority"
		"pagination_boundaries":
			passed = int(_controller.call("page_count", 17, 6)) == 3 and int(_controller.call("page_for_index", 13, 17, 6)) == 2 and int(_controller.call("first_index_on_page", 2, 17, 6)) == 12 and int(_controller.call("first_index_on_page", 99, 17, 6)) == 16
			flags["pagination_checked"] = true
			notes = "shared pagination preserves page counts, selected-page lookup, and clamped starts"
		"navigation_snapshot_pure_data":
			passed = _is_pure_data(_controller.call("navigation_snapshot")) and _is_pure_data(_controller.call("debug_snapshot"))
			flags["pure_data_checked"] = true
			notes = "navigation and debug snapshots contain no Node, Resource, Object, or Callable"
		"legacy_save_key_parity":
			var snapshot: Dictionary = _controller.call("to_legacy_save_snapshot")
			passed = snapshot.keys().size() == LEGACY_SAVE_KEYS.size()
			for key in LEGACY_SAVE_KEYS:
				passed = passed and snapshot.has(key)
			flags["persistence_checked"] = true
			notes = "v1 save adapter preserves exactly the twelve historical navigation keys"
		"legacy_save_roundtrip":
			_controller.call("update_domain", "monster", {"selected_index": 3, "page_index": 1, "show_detail": true, "preview_index": 2})
			_controller.call("update_domain", "product", {"selected_index": 4, "page_index": 2, "show_detail": true, "preview_index": 3})
			var before: Dictionary = _controller.call("to_legacy_save_snapshot")
			_controller.call("reset_navigation")
			_controller.call("apply_legacy_save_snapshot", before)
			passed = _controller.call("to_legacy_save_snapshot") == before
			flags["persistence_checked"] = true
			notes = "legacy navigation state round-trips without changing save version or path"
		"card_transient_nonpersistence_parity":
			_controller.call("update_domain", "card", {"page_index": 4, "show_detail": true, "preview_id": "临时预览"})
			var legacy: Dictionary = _controller.call("to_legacy_save_snapshot")
			passed = not legacy.has("card_codex_grid_page") and not legacy.has("card_codex_show_detail") and not legacy.has("previewed_card_codex_card")
			flags["persistence_checked"] = true
			notes = "the current v1 omission of transient card page/detail/preview state remains unchanged"
		"coordinator_scene_composition":
			var node := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexNavigationRuntimeController") if _main != null else null
			passed = node != null and node.scene_file_path == CONTROLLER_SCENE
			flags["controller_checked"] = true
			flags["main_checked"] = true
			notes = "real main composition owns one editable CodexNavigationRuntimeController scene"
		"coordinator_pure_data_proxy":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Variant = coordinator.call("codex_navigation_state") if coordinator != null else {}
			passed = coordinator != null and coordinator.has_method("update_codex_navigation_domain") and coordinator.has_method("codex_navigation_legacy_save_snapshot") and snapshot is Dictionary and _is_pure_data(snapshot)
			flags["pure_data_checked"] = true
			notes = "GameRuntimeCoordinator exposes only duplicated pure-data navigation snapshots"
		"real_main_controller_composition":
			var main_controller := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexNavigationRuntimeController") if _main != null else null
			var navigation_snapshot: Dictionary = main_controller.call("debug_snapshot") if main_controller != null else {}
			passed = main_controller != null and main_controller.scene_file_path == CONTROLLER_SCENE and bool(navigation_snapshot.get("controller_authoritative", false)) and not bool(navigation_snapshot.get("legacy_main_authority_active", true))
			flags["main_checked"] = true
			notes = "real main reports the scene-owned navigation authority active"
		"real_main_catalog_routes_delegate":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			if coordinator != null:
				var navigation := coordinator.get_node_or_null("CodexNavigationRuntimeController")
				if navigation != null:
					navigation.call("set_catalog_mode", "card")
				coordinator.call("update_codex_navigation_domain", "monster", {"selected_index": 1, "show_detail": true})
				coordinator.call("update_codex_navigation_domain", "product", {"selected_index": 1, "show_detail": true})
				coordinator.call("update_codex_navigation_domain", "card", {"selected_index": 0, "filter_id": "all", "show_detail": true})
			var snapshot: Dictionary = coordinator.call("codex_navigation_state") if coordinator != null else {}
			passed = str(snapshot.get("catalog_mode", "")) == "card" and int((snapshot.get("monster", {}) as Dictionary).get("selected_index", -1)) == 1 and int((snapshot.get("product", {}) as Dictionary).get("selected_index", -1)) == 1 and bool((snapshot.get("card", {}) as Dictionary).get("show_detail", false))
			flags["routing_checked"] = true
			flags["main_checked"] = true
			notes = "typed scene-owned requests mutate only the navigation owner while retaining scene renderers"
		"real_main_v1_save_adapter_parity":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var legacy: Dictionary = coordinator.call("codex_navigation_legacy_save_snapshot") if coordinator != null else {}
			var main_controller := coordinator.get_node_or_null("CodexNavigationRuntimeController") if coordinator != null else null
			var owner_legacy: Dictionary = main_controller.call("to_legacy_save_snapshot") if main_controller != null else {}
			passed = not legacy.is_empty() and legacy == owner_legacy and not _main_source.contains("func _capture_run_domain_state_compatibility_adapter(")
			flags["persistence_checked"] = true
			flags["main_checked"] = true
			notes = "legacy navigation shape remains controller-owned without a Main capture adapter"
		"legacy_authority_and_helpers_absent":
			passed = true
			for variable_name in RETIRED_STATE_VARIABLES:
				passed = passed and not _main_source.contains("var %s" % variable_name)
			for function_name in RETIRED_PAGINATION_FUNCTIONS:
				passed = passed and not _main_source.contains("func %s(" % function_name)
			var metrics := _main_metrics()
			passed = passed and int(metrics.get("nonblank_lines", 999999)) <= 41263 and int(metrics.get("function_count", 999999)) <= 2036 and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) <= 320
			var snapshot: Dictionary = _controller.call("debug_snapshot")
			passed = passed and not _contains_private_key(snapshot)
			flags["deletion_checked"] = true
			flags["privacy_checked"] = true
			notes = "17 legacy state variables and nine duplicate pagination helpers stay absent at the Sprint 13 metrics"
	return _record(case_id, passed, notes, flags)


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "controller_checked": false, "main_checked": false, "state_checked": false, "pagination_checked": false, "persistence_checked": false, "routing_checked": false, "privacy_checked": false, "pure_data_checked": false, "deletion_checked": false, "passed": passed, "notes": notes}
	record.merge(flags, true)
	return record


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if str(key_variant).to_lower() in ["hidden_owner", "hidden_owner_id", "private_target", "private_discard", "private_plan", "ai_private_plan"]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant):
				return true
	return false


func _main_metrics() -> Dictionary:
	var nonblank_lines := 0
	var function_count := 0
	var variable_count := 0
	var constant_count := 0
	for line_variant: Variant in _main_source.split("\n"):
		var line := str(line_variant)
		if not line.strip_edges().is_empty():
			nonblank_lines += 1
		if line.begins_with("func "):
			function_count += 1
		elif line.begins_with("var "):
			variable_count += 1
		elif line.begins_with("const "):
			constant_count += 1
	return {"nonblank_lines": nonblank_lines, "function_count": function_count, "top_level_variable_count": variable_count, "constant_count": constant_count}


func _passed_count() -> int:
	var count := 0
	for record_variant: Variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.modulate = Color("#4ade80") if passed == total else Color("#fb7185")
	summary_label.text = "%d/%d ownership cases passed" % [passed, total]
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	ownership_text.text = "[b]Scene-owned Codex navigation[/b]\nCodexNavigationRuntimeController owns branch, return, selected, page, filter, detail, and preview state for five catalog domains.\n\n[b]Retired from main.gd[/b]\n17 state variables and nine duplicate pagination helpers.\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Codex Navigation Runtime Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired state variables: %d" % int(manifest.get("retired_state_variable_count", 0)), "- Retired pagination helpers: %d" % int(manifest.get("retired_pagination_function_count", 0)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
	for record_variant: Variant in manifest.get("records", []):
		var record := record_variant as Dictionary
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	for file_name in ["manifest.json", "report.md"]:
		var absolute_path := absolute_dir.path_join(file_name)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_failures.append("viewport image unavailable")
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		_failures.append("screenshot save failed: %s" % error_string(error))


func _dispose_runtime() -> void:
	if _main != null:
		for player_variant: Variant in _main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				player.stream = null
		_main.queue_free()
		_main = null
	if _controller != null:
		_controller.queue_free()
		_controller = null
	for _frame in range(4):
		await get_tree().process_frame
