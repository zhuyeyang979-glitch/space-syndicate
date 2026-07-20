@tool
extends Node
class_name TableNavigationActionRouter

signal receipt_ready(receipt: Dictionary)

@export var selection_state_path: NodePath
@export var compendium_navigation_port_path: NodePath
@export var application_flow_port_path: NodePath

var _journal: Dictionary = {}
var _submission_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _duplicate_count := 0


func submit_intent(intent: TableNavigationActionIntent) -> Dictionary:
	_submission_count += 1
	if intent == null:
		return _complete(_receipt("", &"", false, "intent_missing"))
	var detached := TableNavigationActionIntent.from_dictionary(intent.to_dictionary())
	var validation := detached.validation_report()
	if not bool(validation.get("valid", false)):
		return _complete(_receipt(detached.request_id, detached.action_kind, false, str(validation.get("reason_code", "intent_invalid"))))
	var fingerprint := detached.fingerprint()
	if _journal.has(detached.request_id):
		_duplicate_count += 1
		var reason := "request_replay" if str(_journal.get(detached.request_id, "")) == fingerprint else "request_id_collision"
		return _complete(_receipt(detached.request_id, detached.action_kind, false, reason))
	var rejection := _dependency_rejection(detached.action_kind)
	if not rejection.is_empty():
		return _complete(_receipt(detached.request_id, detached.action_kind, false, rejection))
	var handled := false
	var target_id := ""
	match detached.action_kind:
		TableNavigationActionIntent.KIND_REGION_DETAIL:
			var district_index := _selection_state().selected_district
			if district_index < 0:
				return _complete(_receipt(detached.request_id, detached.action_kind, false, "selected_district_missing"))
			target_id = "region:%d" % district_index
			handled = _navigation_port().request_open("region", "detail", target_id, district_index, "", 0, "game", {"origin": "game"})
		TableNavigationActionIntent.KIND_CARD_BROWSER:
			target_id = "catalog"
			handled = _navigation_port().request_open("card", "browser", target_id, -1, "all", 0, "game", {"origin": "game"})
		TableNavigationActionIntent.KIND_COMPENDIUM_HUB:
			target_id = "compendium"
			handled = _application_flow_port().submit_action("compendium")
		TableNavigationActionIntent.KIND_CARD_DETAIL:
			target_id = detached.target_card_name
			handled = _navigation_port().request_open("card", "detail", target_id, -1, "all", 0, "game", {"origin": "game"})
		TableNavigationActionIntent.KIND_PAUSE_MENU:
			target_id = "pause_menu"
			handled = _application_flow_port().request_pause_menu()
	if not handled:
		return _complete(_receipt(detached.request_id, detached.action_kind, false, "target_rejected"))
	_journal[detached.request_id] = fingerprint
	var receipt := _receipt(detached.request_id, detached.action_kind, true, "navigation_routed")
	receipt["target_id"] = target_id
	return _complete(receipt)


func debug_snapshot() -> Dictionary:
	return {
		"router_id": "table_navigation_action_router_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"duplicate_count": _duplicate_count,
		"journal_size": _journal.size(),
		"supported_kinds": TableNavigationActionIntent.ALLOWED_KINDS.duplicate(),
		"owns_gameplay_state": false,
		"owns_navigation_state": false,
		"references_main": false,
		"uses_callable_dispatch": false,
	}


func _dependency_rejection(kind: StringName) -> String:
	if kind in [TableNavigationActionIntent.KIND_COMPENDIUM_HUB, TableNavigationActionIntent.KIND_PAUSE_MENU]:
		return "application_flow_port_missing" if _application_flow_port() == null else ""
	if _navigation_port() == null:
		return "compendium_navigation_port_missing"
	if kind == TableNavigationActionIntent.KIND_REGION_DETAIL and _selection_state() == null:
		return "selection_state_missing"
	return ""


func _receipt(request_id: String, kind: StringName, accepted: bool, reason_code: String) -> Dictionary:
	return {
		"request_id": request_id,
		"action_kind": String(kind),
		"accepted": accepted,
		"reason_code": reason_code,
		"target_id": "",
	}


func _complete(receipt: Dictionary) -> Dictionary:
	if bool(receipt.get("accepted", false)):
		_accepted_count += 1
	else:
		_rejected_count += 1
	receipt_ready.emit(receipt.duplicate(true))
	return receipt


func _selection_state() -> TableSelectionState:
	if selection_state_path.is_empty():
		return null
	return get_node_or_null(selection_state_path) as TableSelectionState


func _navigation_port() -> CompendiumNavigationPort:
	if compendium_navigation_port_path.is_empty():
		return null
	return get_node_or_null(compendium_navigation_port_path) as CompendiumNavigationPort


func _application_flow_port() -> ApplicationFlowPort:
	if application_flow_port_path.is_empty():
		return null
	return get_node_or_null(application_flow_port_path) as ApplicationFlowPort
