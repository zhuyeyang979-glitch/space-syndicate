extends Node
class_name DeveloperBalanceApplicationHost

const PANEL_SCENE := preload("res://scenes/ui/DeveloperBalancePanel.tscn")
const PANEL_MOUNT_ENV := "SPACE_SYNDICATE_DEV_BALANCE"
const ENABLED_ENV_VALUES := ["1", "true", "yes", "on", "dev"]

@export var panel_parent_path: NodePath
@export var presentation_target_path: NodePath
@export var auto_mount := true

var _panel: DeveloperBalancePanel
var _mount_request_count := 0
var _mount_count := 0
var _bind_count := 0
var _failure_count := 0
var _last_reason := "not_started"


func _ready() -> void:
	if auto_mount and not Engine.is_editor_hint():
		mount_if_requested()


func mount_if_requested() -> Dictionary:
	_mount_request_count += 1
	if _panel != null and is_instance_valid(_panel):
		_last_reason = "already_mounted"
		return _receipt(true, _last_reason)
	if not _environment_requests_panel():
		_last_reason = "developer_balance_environment_disabled"
		return _receipt(false, _last_reason)
	var panel_parent := get_node_or_null(panel_parent_path) as Control
	if panel_parent == null:
		_failure_count += 1
		_last_reason = "developer_balance_panel_parent_missing"
		return _receipt(false, _last_reason)
	var target := get_node_or_null(presentation_target_path) as DeveloperBalancePresentationTarget
	if target == null:
		_failure_count += 1
		_last_reason = "developer_balance_presentation_target_missing"
		return _receipt(false, _last_reason)
	var panel := PANEL_SCENE.instantiate() as DeveloperBalancePanel
	if panel == null:
		_failure_count += 1
		_last_reason = "developer_balance_panel_scene_invalid"
		return _receipt(false, _last_reason)
	panel.name = "DeveloperBalancePanel"
	panel.visible = true
	panel_parent.add_child(panel)
	target.bind_panel(panel)
	target.enabled = true
	_panel = panel
	_mount_count += 1
	_bind_count += 1
	_last_reason = "mounted"
	return _receipt(true, _last_reason)


func debug_snapshot() -> Dictionary:
	return {
		"configured": get_node_or_null(panel_parent_path) is Control \
			and get_node_or_null(presentation_target_path) is DeveloperBalancePresentationTarget,
		"environment_requested": _environment_requests_panel(),
		"panel_mounted": _panel != null and is_instance_valid(_panel),
		"panel_path": str(_panel.get_path()) if _panel != null and is_instance_valid(_panel) else "",
		"mount_request_count": _mount_request_count,
		"mount_count": _mount_count,
		"bind_count": _bind_count,
		"failure_count": _failure_count,
		"last_reason": _last_reason,
		"references_main": false,
		"owns_gameplay_state": false,
		"owns_diagnostics_report": false,
		"owns_refresh_cadence": false,
		"owns_save_schema": false,
	}


func _environment_requests_panel() -> bool:
	return ENABLED_ENV_VALUES.has(OS.get_environment(PANEL_MOUNT_ENV).strip_edges().to_lower())


func _receipt(mounted: bool, reason: String) -> Dictionary:
	return {
		"mounted": mounted,
		"reason": reason,
		"mount_request_count": _mount_request_count,
		"mount_count": _mount_count,
		"bind_count": _bind_count,
		"failure_count": _failure_count,
	}
