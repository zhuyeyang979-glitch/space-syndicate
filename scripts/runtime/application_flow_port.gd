extends Node
class_name ApplicationFlowPort

## Narrow application-flow boundary between scene-owned runtime compositions and
## the application bootstrap. It carries only allow-listed navigation intents;
## it never owns gameplay state, timing, or presentation snapshots.

signal action_requested(action_id: StringName)
signal rules_requested()
signal standings_requested()
signal economy_requested()
signal compendium_requested()
signal intel_requested()
signal setup_requested()
signal intel_application_intent_requested(intent: IntelApplicationIntent)
signal menu_requested(title: String, summary: String, can_continue: bool)

const ALLOWED_ACTIONS := [&"setup", &"standings", &"economy", &"intel", &"rules", &"compendium"]

var _action_emission_count := 0
var _standings_emission_count := 0
var _economy_emission_count := 0
var _compendium_emission_count := 0
var _intel_emission_count := 0
var _setup_emission_count := 0
var _intel_application_intent_emission_count := 0
var _intel_application_intent_rejection_count := 0
var _menu_emission_count := 0


func submit_action(action_id: String) -> bool:
	var normalized := StringName(action_id)
	if not ALLOWED_ACTIONS.has(normalized):
		return false
	if normalized == &"rules":
		rules_requested.emit()
	elif normalized == &"standings":
		_standings_emission_count += 1
		standings_requested.emit()
	elif normalized == &"economy":
		_economy_emission_count += 1
		economy_requested.emit()
	elif normalized == &"compendium":
		_compendium_emission_count += 1
		compendium_requested.emit()
	elif normalized == &"intel":
		_intel_emission_count += 1
		intel_requested.emit()
	elif normalized == &"setup":
		_setup_emission_count += 1
		setup_requested.emit()
	else:
		_action_emission_count += 1
		action_requested.emit(normalized)
	return true


func submit_intel_application_intent(intent: IntelApplicationIntent) -> bool:
	if intent == null or not intent.is_valid():
		_intel_application_intent_rejection_count += 1
		return false
	var detached_intent := IntelApplicationIntent.from_dictionary(intent.to_dictionary())
	if detached_intent == null:
		_intel_application_intent_rejection_count += 1
		return false
	_intel_application_intent_emission_count += 1
	intel_application_intent_requested.emit(detached_intent)
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
		"standings_emission_count": _standings_emission_count,
		"standings_uses_dedicated_signal": true,
		"standings_uses_generic_action_signal": false,
		"economy_emission_count": _economy_emission_count,
		"economy_signal_boundary": true,
		"economy_to_main": false,
		"compendium_emission_count": _compendium_emission_count,
		"compendium_signal_boundary": true,
		"compendium_uses_generic_action_signal": false,
		"compendium_to_main": false,
		"intel_emission_count": _intel_emission_count,
		"intel_signal_boundary": true,
		"intel_uses_dedicated_signal": true,
		"intel_uses_generic_action_signal": false,
		"intel_application_intent_emission_count": _intel_application_intent_emission_count,
		"intel_application_intent_rejection_count": _intel_application_intent_rejection_count,
		"intel_application_intent_uses_dedicated_signal": true,
		"intel_application_intent_uses_generic_action_signal": false,
		"stores_intel_navigation_state": false,
		"intel_to_main": false,
		"setup_emission_count": _setup_emission_count,
		"setup_signal_boundary": true,
		"setup_uses_generic_action_signal": false,
		"setup_to_main": false,
		"rules_signal_boundary": true,
		"menu_emission_count": _menu_emission_count,
		"owns_gameplay_state": false,
		"owns_world_clock": false,
		"owns_presentation_snapshot": false,
		"holds_main_reference": false,
	}
