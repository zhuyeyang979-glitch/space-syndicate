extends Control
class_name SpaceSyndicateMcpEditabilityHub

signal open_scene_requested(scene_path: String)
signal run_scene_requested(scene_path: String)
signal capture_screenshot_requested(scene_path: String, screenshot_path: String)

const RegistryScript = preload("res://scripts/tools/space_syndicate_mcp_scene_registry.gd")
const DEFAULT_SCREENSHOT_PATH := "user://space_syndicate_design_qa/mcp_editability_hub_sprint_1.png"

@onready var category_list: ItemList = %McpCategoryList
@onready var scene_list: ItemList = %McpSceneList
@onready var display_name_label: Label = %McpSceneDisplayNameLabel
@onready var path_label: Label = %McpScenePathLabel
@onready var category_label: Label = %McpSceneCategoryLabel
@onready var root_type_label: Label = %McpExpectedRootTypeLabel
@onready var purpose_label: Label = %McpScenePurposeLabel
@onready var notes_label: Label = %McpSceneNotesLabel
@onready var smoke_label: Label = %McpSceneSmokeLabel
@onready var status_label: Label = %McpHubStatusLabel
@onready var open_button: Button = %OpenSceneButton
@onready var run_button: Button = %RunSceneButton
@onready var capture_button: Button = %CaptureScreenshotButton
@onready var print_path_button: Button = %PrintScenePathButton
@onready var refresh_button: Button = %RefreshRegistryButton

var _registry: RefCounted
var _categories: Array[String] = []
var _records: Array = []
var _visible_records: Array = []
var _selected_record: Dictionary = {}


func _ready() -> void:
	_registry = RegistryScript.new()
	_connect_buttons()
	refresh_registry()


func registry_records() -> Array:
	if _registry == null:
		return []
	return _registry.call("records")


func registry_categories() -> Array[String]:
	if _registry == null:
		return []
	return _registry.call("categories")


func selected_record() -> Dictionary:
	return _selected_record.duplicate(true)


func selected_scene_path() -> String:
	return str(_selected_record.get("scene_path", ""))


func screenshot_path() -> String:
	return DEFAULT_SCREENSHOT_PATH


func select_scene_by_path(scene_path: String) -> bool:
	for record in _records:
		var entry: Dictionary = record if record is Dictionary else {}
		if str(entry.get("scene_path", "")) != scene_path:
			continue
		var category := str(entry.get("category", ""))
		var category_index := _categories.find(category)
		if category_index >= 0 and category_list != null:
			category_list.select(category_index)
			_show_category(category)
		for i in range(_visible_records.size()):
			var visible_record: Dictionary = _visible_records[i] if _visible_records[i] is Dictionary else {}
			if str(visible_record.get("scene_path", "")) == scene_path:
				if scene_list != null:
					scene_list.select(i)
				_select_record(visible_record)
				return true
	return false


func refresh_registry() -> void:
	if _registry == null:
		_set_status("Registry missing.")
		return
	_categories = _registry.call("categories")
	_records = _registry.call("records")
	_populate_categories()
	if not _categories.is_empty():
		if category_list != null:
			category_list.select(0)
		_show_category(_categories[0])
	_set_status("Registry refreshed: %d scenes" % _records.size())


func open_selected_scene() -> void:
	var path := selected_scene_path()
	if path.is_empty():
		_set_status("No scene selected.")
		return
	print("MCP_HUB_OPEN_SCENE: %s" % path)
	open_scene_requested.emit(path)
	_set_status("Open requested: %s" % path)


func run_selected_scene() -> void:
	var path := selected_scene_path()
	if path.is_empty():
		_set_status("No scene selected.")
		return
	print("MCP_HUB_RUN_SCENE: %s" % path)
	run_scene_requested.emit(path)
	_set_status("Run requested: %s" % path)


func capture_selected_scene() -> void:
	var path := selected_scene_path()
	if path.is_empty():
		_set_status("No scene selected.")
		return
	print("MCP_HUB_CAPTURE_SCREENSHOT: %s -> %s" % [path, DEFAULT_SCREENSHOT_PATH])
	capture_screenshot_requested.emit(path, DEFAULT_SCREENSHOT_PATH)
	_set_status("Capture path: %s" % DEFAULT_SCREENSHOT_PATH)


func print_selected_scene_path() -> void:
	var path := selected_scene_path()
	if path.is_empty():
		_set_status("No scene selected.")
		return
	DisplayServer.clipboard_set(path)
	print("MCP_HUB_SCENE_PATH: %s" % path)
	_set_status("Scene path copied/printed: %s" % path)


func _connect_buttons() -> void:
	_connect_item_signal(category_list, "_on_category_selected")
	_connect_item_signal(scene_list, "_on_scene_selected")
	_connect_button(open_button, "open_selected_scene")
	_connect_button(run_button, "run_selected_scene")
	_connect_button(capture_button, "capture_selected_scene")
	_connect_button(print_path_button, "print_selected_scene_path")
	_connect_button(refresh_button, "refresh_registry")


func _connect_button(button: Button, method_name: String) -> void:
	if button == null:
		return
	var callback := Callable(self, method_name)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _connect_item_signal(list: ItemList, method_name: String) -> void:
	if list == null:
		return
	var callback := Callable(self, method_name)
	if not list.item_selected.is_connected(callback):
		list.item_selected.connect(callback)


func _populate_categories() -> void:
	if category_list == null:
		return
	category_list.clear()
	for category in _categories:
		category_list.add_item(category)


func _show_category(category: String) -> void:
	_visible_records.clear()
	if scene_list != null:
		scene_list.clear()
	for record in _records:
		var entry: Dictionary = record if record is Dictionary else {}
		if str(entry.get("category", "")) != category:
			continue
		_visible_records.append(entry.duplicate(true))
		if scene_list != null:
			scene_list.add_item(str(entry.get("display_name", entry.get("id", ""))))
	if not _visible_records.is_empty():
		if scene_list != null:
			scene_list.select(0)
		_select_record(_visible_records[0])
	else:
		_select_record({})


func _select_record(record: Dictionary) -> void:
	_selected_record = record.duplicate(true)
	var has_record := not _selected_record.is_empty()
	if display_name_label != null:
		display_name_label.text = str(_selected_record.get("display_name", "No scene selected")) if has_record else "No scene selected"
	if path_label != null:
		path_label.text = "Path: %s" % str(_selected_record.get("scene_path", "-"))
	if category_label != null:
		category_label.text = "Category: %s" % str(_selected_record.get("category", "-"))
	if root_type_label != null:
		root_type_label.text = "Expected root: %s" % str(_selected_record.get("expected_root_type", "-"))
	if purpose_label != null:
		purpose_label.text = str(_selected_record.get("purpose", ""))
	if notes_label != null:
		notes_label.text = str(_selected_record.get("mcp_notes", ""))
	if smoke_label != null:
		var smoke_text := "enabled" if bool(_selected_record.get("smoke_check_enabled", false)) else "manual"
		var preview_text := "previewable" if bool(_selected_record.get("previewable", false)) else "not previewable"
		smoke_label.text = "Smoke: %s | %s" % [smoke_text, preview_text]


func _on_category_selected(index: int) -> void:
	if index < 0 or index >= _categories.size():
		return
	_show_category(_categories[index])
	_set_status("Category selected: %s" % _categories[index])


func _on_scene_selected(index: int) -> void:
	if index < 0 or index >= _visible_records.size():
		return
	_select_record(_visible_records[index])
	_set_status("Scene selected: %s" % selected_scene_path())


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
