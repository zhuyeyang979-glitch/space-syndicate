@tool
extends EditorInspectorPlugin

const PANEL_SCENE := preload("res://addons/space_syndicate_design_qa/CardRuntimeAuthoringInspectorPanel.tscn")

var _host_plugin: EditorPlugin


func set_host_plugin(plugin: EditorPlugin) -> void:
	_host_plugin = plugin


func _can_handle(object: Object) -> bool:
	return object is CardRuntimeCatalogResource or object is CardRuntimePackResource or object is CardRuntimeFamilyResource or object is CardRuntimeRankResource


func _parse_begin(object: Object) -> void:
	if not (object is Resource):
		return
	var panel := PANEL_SCENE.instantiate()
	if panel == null:
		return
	if panel.has_method("configure"):
		panel.call("configure", object as Resource, _host_plugin)
	add_custom_control(panel)
