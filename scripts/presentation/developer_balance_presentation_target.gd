@tool
extends Node
class_name DeveloperBalancePresentationTarget

@export var enabled := false
const DEVELOPER_PRESENTATION_ENV := "SPACE_SYNDICATE_DEVELOPER_PRESENTATION"
var _panel: DeveloperBalancePanel
var _target_revision := 0
var _apply_count := 0


func bind_panel(panel: DeveloperBalancePanel) -> void:
	_panel = panel


func apply_developer_presentation(snapshot: DeveloperBalancePresentationSnapshot) -> int:
	if snapshot == null or not snapshot.is_valid() or not is_available() or not snapshot.enabled:
		return _target_revision
	if _panel != null:
		_panel.set_report(snapshot.report)
	_target_revision += 1
	_apply_count += 1
	return _target_revision


func debug_snapshot() -> Dictionary:
	return {
		"enabled": enabled,
		"debug_build": OS.is_debug_build(),
		"environment_gate": OS.get_environment(DEVELOPER_PRESENTATION_ENV) == "1",
		"available": is_available(),
		"target_revision": _target_revision,
		"apply_count": _apply_count,
		"production_dependency": false,
	}


func is_available() -> bool:
	return enabled and OS.is_debug_build() and OS.get_environment(DEVELOPER_PRESENTATION_ENV) == "1"
