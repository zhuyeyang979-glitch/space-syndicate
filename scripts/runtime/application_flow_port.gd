extends Node
class_name ApplicationFlowPort

## Narrow application-flow boundary between scene-owned runtime compositions and
## the application bootstrap. It carries only allow-listed navigation intents;
## it never owns gameplay state, timing, or presentation snapshots.

signal action_requested(action_id: StringName)
signal rules_requested()
signal menu_requested(title: String, summary: String, can_continue: bool)

const ALLOWED_ACTIONS := [&"setup", &"standings", &"economy", &"intel", &"rules", &"compendium"]

var _action_emission_count := 0
var _menu_emission_count := 0


func submit_action(action_id: String) -> bool:
	var normalized := StringName(action_id)
	if not ALLOWED_ACTIONS.has(normalized):
		return false
	_action_emission_count += 1
	if normalized == &"rules":
		rules_requested.emit()
	else:
		action_requested.emit(normalized)
	return true


func request_menu(title: String, summary: String, can_continue: bool) -> bool:
	if title.strip_edges().is_empty() or summary.strip_edges().is_empty():
		return false
	_menu_emission_count += 1
	menu_requested.emit(title, summary, can_continue)
	return true


func debug_snapshot() -> Dictionary:
	return {
		"boundary_id": "application_flow_port_v06",
		"allowed_action_count": ALLOWED_ACTIONS.size(),
		"action_emission_count": _action_emission_count,
		"rules_signal_boundary": true,
		"menu_emission_count": _menu_emission_count,
		"owns_gameplay_state": false,
		"owns_world_clock": false,
		"owns_presentation_snapshot": false,
		"holds_main_reference": false,
	}
