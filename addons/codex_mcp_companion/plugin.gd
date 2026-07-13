@tool
extends EditorPlugin

const DOCK_TITLE := "Codex MCP"

var dock: VBoxContainer
var project_name_label: Label
var project_path_label: Label
var mcp_config_label: Label
var godot_version_label: Label


func _enter_tree() -> void:
	_build_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	_refresh_status()


func _exit_tree() -> void:
	if dock != null:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null


func _build_dock() -> void:
	dock = VBoxContainer.new()
	dock.name = DOCK_TITLE
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = DOCK_TITLE
	title.add_theme_font_size_override("font_size", 18)
	dock.add_child(title)

	project_name_label = Label.new()
	project_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(project_name_label)

	project_path_label = Label.new()
	project_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(project_path_label)

	mcp_config_label = Label.new()
	mcp_config_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(mcp_config_label)

	godot_version_label = Label.new()
	godot_version_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(godot_version_label)

	var button_row := HBoxContainer.new()
	dock.add_child(button_row)

	var copy_path_button := Button.new()
	copy_path_button.text = "Copy Path"
	copy_path_button.pressed.connect(_copy_project_path)
	button_row.add_child(copy_path_button)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_status)
	button_row.add_child(refresh_button)

	var open_folder_button := Button.new()
	open_folder_button.text = "Open Folder"
	open_folder_button.pressed.connect(_open_project_folder)
	dock.add_child(open_folder_button)

	var open_mcp_button := Button.new()
	open_mcp_button.text = "Open .mcp.json"
	open_mcp_button.pressed.connect(_open_mcp_config)
	dock.add_child(open_mcp_button)


func _refresh_status() -> void:
	var project_path := _project_path()
	var mcp_path := project_path.path_join(".mcp.json")
	var project_name := str(ProjectSettings.get_setting("application/config/name", "Unnamed"))
	var version_info := Engine.get_version_info()
	var godot_version := str(version_info.get("string", "unknown"))

	project_name_label.text = "Project: " + project_name
	project_path_label.text = "Path: " + project_path
	mcp_config_label.text = "MCP config: " + ("present" if FileAccess.file_exists(mcp_path) else "missing")
	godot_version_label.text = "Godot: " + godot_version


func _copy_project_path() -> void:
	DisplayServer.clipboard_set(_project_path())


func _open_project_folder() -> void:
	OS.shell_open(_project_path())


func _open_mcp_config() -> void:
	var mcp_path := _project_path().path_join(".mcp.json")
	if FileAccess.file_exists(mcp_path):
		OS.shell_open(mcp_path)


func _project_path() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")
