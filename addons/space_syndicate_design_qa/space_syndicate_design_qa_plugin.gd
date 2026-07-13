@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/space_syndicate_design_qa/SpaceSyndicateDesignQADock.tscn"
const DOCK_TITLE := "Space QA"
const CARD_AUTHORING_INSPECTOR_PLUGIN_SCRIPT := preload("res://addons/space_syndicate_design_qa/card_runtime_authoring_inspector_plugin.gd")

var _dock: Control = null
var _card_authoring_inspector_plugin: EditorInspectorPlugin = null


func _enter_tree() -> void:
	_card_authoring_inspector_plugin = CARD_AUTHORING_INSPECTOR_PLUGIN_SCRIPT.new()
	_card_authoring_inspector_plugin.call("set_host_plugin", self)
	add_inspector_plugin(_card_authoring_inspector_plugin)
	var packed := load(DOCK_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("Space Syndicate Design QA dock scene could not be loaded.")
		return
	_dock = packed.instantiate() as Control
	if _dock == null:
		push_warning("Space Syndicate Design QA dock root is not a Control.")
		return
	_dock.name = DOCK_TITLE
	if _dock.has_method("set_editor_plugin"):
		_dock.call("set_editor_plugin", self)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)


func _exit_tree() -> void:
	if _card_authoring_inspector_plugin != null:
		remove_inspector_plugin(_card_authoring_inspector_plugin)
		_card_authoring_inspector_plugin = null
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func open_scene(scene_path: String) -> void:
	var editor_interface := get_editor_interface()
	if editor_interface == null:
		return
	if editor_interface.has_method("open_scene_from_path"):
		editor_interface.call("open_scene_from_path", scene_path)


func open_resource(resource_path: String) -> void:
	var editor_interface := get_editor_interface()
	var resource := load(resource_path)
	if editor_interface != null and resource != null and editor_interface.has_method("edit_resource"):
		editor_interface.call("edit_resource", resource)


func run_scene(scene_path: String) -> void:
	var editor_interface := get_editor_interface()
	if editor_interface == null:
		return
	if editor_interface.has_method("play_custom_scene"):
		editor_interface.call("play_custom_scene", scene_path)
	elif editor_interface.has_method("open_scene_from_path"):
		editor_interface.call("open_scene_from_path", scene_path)
