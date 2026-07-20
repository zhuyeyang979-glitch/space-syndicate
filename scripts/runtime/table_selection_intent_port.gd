@tool
extends Node
class_name TableSelectionIntentPort

signal receipt_ready(receipt: TableSelectionReceipt)
signal presentation_refresh_requested(kind: StringName, reason: StringName)

@export var identity_boundary_path: NodePath
@export var selection_state_path: NodePath
@export var forced_decision_response_port_path: NodePath
@export var card_resolution_queue_path: NodePath
@export var card_resolution_history_path: NodePath

var _journal: Dictionary = {}
var _journal_session_key := ""
var _submission_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _changed_count := 0
var _refresh_emission_count := 0
var _replay_count := 0
var _collision_count := 0


func submit_intent(intent: TableSelectionIntent) -> TableSelectionReceipt:
	_submission_count += 1
	if intent == null:
		return _complete(_receipt(null, false, "intent_missing"))
	var validation := intent.validation_report()
	if not bool(validation.get("valid", false)):
		return _complete(_receipt(intent, false, str(validation.get("reason_code", "intent_invalid"))))
	if _identity_boundary() == null or _selection_state() == null:
		return _complete(_receipt(intent, false, "selection_dependency_missing"))
	var request := _request_from_intent(intent)
	var request_validation := request.validation_report()
	if not bool(request_validation.get("valid", false)):
		return _complete(_receipt(intent, false, str(request_validation.get("reason_code", "request_invalid"))))
	var request_session_key := "%s:%d" % [request.session_id, request.session_revision]
	var fingerprint := request.fingerprint()
	if _journal_session_key == request_session_key and _journal.has(request.request_id):
		if str(_journal.get(request.request_id, "")) != fingerprint:
			_collision_count += 1
			var collision := _receipt(intent, false, "request_id_collision")
			collision.request_id_collision = true
			return _complete(collision)
		_replay_count += 1
		var replay := _receipt(intent, false, "request_replay")
		replay.idempotent_replay = true
		return _complete(replay)
	if _forced_response_port() != null and _forced_response_port().blocks_ordinary_gameplay(intent.viewer_index):
		return _complete(_receipt(intent, false, "forced_decision_blocks_selection"))
	var before := _selection_state().snapshot()
	if intent.expected_selection_revision != int(before.get("revision", -1)):
		var stale := _receipt(intent, false, "selection_revision_stale")
		stale.selection_revision_before = int(before.get("revision", -1))
		stale.selection_revision_after = stale.selection_revision_before
		return _complete(stale)
	var identity_receipt := _identity_boundary().authorize_request(request)
	if not identity_receipt.authorized:
		return _complete(_receipt(intent, false, "identity_%s" % identity_receipt.reason_code))
	var target_rejection := _target_rejection_reason(intent)
	if not target_rejection.is_empty():
		return _complete(_receipt(intent, false, target_rejection))
	_sync_journal_session(request.session_id, request.session_revision)
	_journal[request.request_id] = fingerprint
	var selection_result := {}
	match intent.selection_kind:
		TableSelectionIntent.KIND_INSPECT_PLAYER:
			selection_result = _selection_state().select_inspected_player(intent.target_player_index, intent.expected_selection_revision)
		TableSelectionIntent.KIND_SELECT_DISTRICT:
			selection_result = _selection_state().select_district_target(intent.target_district_index, intent.expected_selection_revision, true)
		TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT:
			selection_result = _selection_state().select_trade_product_target(intent.target_trade_product_id, intent.expected_selection_revision)
		TableSelectionIntent.KIND_SELECT_HAND_SLOT:
			selection_result = _selection_state().select_hand_target(intent.target_hand_slot, intent.expected_selection_revision)
		TableSelectionIntent.KIND_SELECT_CARD_RESOLUTION:
			selection_result = _selection_state().select_card_resolution_target(
				intent.target_card_resolution_id,
				_public_target_district(_public_card_resolution_entry(intent.target_card_resolution_id)),
				intent.expected_selection_revision
			)
		_:
			_selection_state().selected_map_layer_focus = str(request.map_layer_id)
	if not selection_result.is_empty() and not bool(selection_result.get("applied", false)):
		_journal.erase(request.request_id)
		return _complete(_receipt(intent, false, str(selection_result.get("reason_code", "selection_rejected"))))
	var after := _selection_state().snapshot()
	var receipt := _receipt(intent, true, "selection_applied")
	receipt.applied = true
	receipt.selection_revision_before = int(before.get("revision", -1))
	receipt.selection_revision_after = int(after.get("revision", -1))
	receipt.changed = receipt.selection_revision_after != receipt.selection_revision_before
	if intent.selection_kind == TableSelectionIntent.KIND_INSPECT_PLAYER:
		receipt.previous_inspected_player_index = int(selection_result.get("previous_inspected_player_index", -1))
		receipt.inspected_player_index = int(selection_result.get("inspected_player_index", -1))
	elif intent.selection_kind == TableSelectionIntent.KIND_SELECT_DISTRICT:
		receipt.previous_district_index = int(selection_result.get("previous_district_index", -1))
		receipt.district_index = int(selection_result.get("district_index", -1))
		receipt.previous_hand_slot = int(selection_result.get("previous_hand_slot", -1))
		receipt.hand_slot = int(selection_result.get("hand_slot", -1))
	elif intent.selection_kind == TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT:
		receipt.previous_trade_product_id = str(selection_result.get("previous_trade_product_id", ""))
		receipt.trade_product_id = str(selection_result.get("trade_product_id", ""))
	elif intent.selection_kind == TableSelectionIntent.KIND_SELECT_HAND_SLOT:
		receipt.previous_hand_slot = int(selection_result.get("previous_hand_slot", -1))
		receipt.hand_slot = int(selection_result.get("hand_slot", -1))
	elif intent.selection_kind == TableSelectionIntent.KIND_SELECT_CARD_RESOLUTION:
		receipt.previous_card_resolution_id = int(selection_result.get("previous_card_resolution_id", -1))
		receipt.card_resolution_id = int(selection_result.get("card_resolution_id", -1))
		receipt.previous_district_index = int(selection_result.get("previous_district_index", -1))
		receipt.district_index = int(selection_result.get("district_index", -1))
		receipt.focus_district_index = int(selection_result.get("focus_district_index", -1))
	if receipt.changed:
		_changed_count += 1
		receipt.presentation_refresh_requested = true
		_refresh_emission_count += 1
		var refresh_kind := _refresh_kind(intent.selection_kind)
		receipt.presentation_refresh_mask = [refresh_kind]
		presentation_refresh_requested.emit(refresh_kind, _refresh_reason(intent.selection_kind))
	else:
		receipt.reason_code = "selection_unchanged"
	return _complete(receipt)


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "table_selection_intent_port_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"changed_count": _changed_count,
		"refresh_emission_count": _refresh_emission_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"journal_size": _journal.size(),
		"journal_session_key": _journal_session_key,
		"journal_eviction_enabled": false,
		"supported_selection_kinds": [TableSelectionIntent.KIND_MAP_LAYER, TableSelectionIntent.KIND_INSPECT_PLAYER, TableSelectionIntent.KIND_SELECT_DISTRICT, TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT, TableSelectionIntent.KIND_SELECT_HAND_SLOT, TableSelectionIntent.KIND_SELECT_CARD_RESOLUTION],
		"typed_identity_envelope_required": true,
		"exact_once": true,
		"owns_selection_state": false,
		"gameplay_mutation_count": 0,
		"references_main": false,
	}


func _request_from_intent(intent: TableSelectionIntent) -> TableSelectionRequest:
	var request := TableSelectionRequest.new()
	var identity := _identity_boundary().build_request(intent.request_id, intent.source_surface, intent.request_revision)
	request.schema_version = identity.schema_version
	request.request_id = identity.request_id
	request.viewer_index = intent.viewer_index
	request.authorized_player_index = intent.viewer_index
	request.authorization_revision = intent.authorization_revision
	request.session_id = identity.session_id
	request.session_revision = identity.session_revision
	request.source_surface = intent.source_surface
	request.request_revision = intent.request_revision
	if intent.session_id != "":
		request.session_id = intent.session_id
	if intent.session_revision > 0:
		request.session_revision = intent.session_revision
	request.selection_kind = intent.selection_kind
	request.expected_selection_revision = intent.expected_selection_revision
	request.map_layer_id = intent.map_layer_id
	request.target_player_index = intent.target_player_index
	request.target_district_index = intent.target_district_index
	request.target_trade_product_id = intent.target_trade_product_id
	request.target_hand_slot = intent.target_hand_slot
	request.target_card_resolution_id = intent.target_card_resolution_id
	return request


func _sync_journal_session(session_id: String, session_revision: int) -> void:
	var session_key := "%s:%d" % [session_id, session_revision]
	if _journal_session_key == session_key:
		return
	_journal.clear()
	_journal_session_key = session_key


func _receipt(intent: TableSelectionIntent, accepted: bool, reason_code: String) -> TableSelectionReceipt:
	var receipt := TableSelectionReceipt.new()
	if intent != null:
		receipt.request_id = intent.request_id
		receipt.selection_kind = intent.selection_kind
		receipt.viewer_index = intent.viewer_index
		receipt.authorization_revision = intent.authorization_revision
		receipt.session_revision = intent.session_revision
		receipt.map_layer_id = intent.map_layer_id
		receipt.inspected_player_index = intent.target_player_index
		receipt.district_index = intent.target_district_index
		receipt.trade_product_id = intent.target_trade_product_id
		receipt.hand_slot = intent.target_hand_slot
		receipt.card_resolution_id = intent.target_card_resolution_id
	receipt.accepted = accepted
	receipt.reason_code = reason_code
	return receipt


func _complete(receipt: TableSelectionReceipt) -> TableSelectionReceipt:
	if _selection_state() != null:
		receipt.effective_map_layer_id = StringName(_selection_state().selected_map_layer_focus)
		if receipt.inspected_player_index < 0 or not receipt.accepted:
			receipt.inspected_player_index = _selection_state().inspected_player_index()
		if receipt.district_index < 0 or not receipt.accepted:
			receipt.district_index = _selection_state().selected_district
		if receipt.trade_product_id.is_empty() and (receipt.selection_kind != TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT or not receipt.accepted):
			receipt.trade_product_id = _selection_state().selected_trade_product
		if receipt.hand_slot < -1 or not receipt.accepted:
			receipt.hand_slot = _selection_state().selected_hand_slot
		if receipt.card_resolution_id < -1 or not receipt.accepted:
			receipt.card_resolution_id = _selection_state().selected_card_resolution_id
	if receipt.accepted:
		_accepted_count += 1
	else:
		_rejected_count += 1
	receipt_ready.emit(receipt)
	return receipt


func _identity_boundary() -> PlayerIdentityAuthorizationBoundary:
	return get_node_or_null(identity_boundary_path) as PlayerIdentityAuthorizationBoundary


func _selection_state() -> TableSelectionState:
	return get_node_or_null(selection_state_path) as TableSelectionState


func _forced_response_port() -> ForcedDecisionResponsePort:
	return get_node_or_null(forced_decision_response_port_path) as ForcedDecisionResponsePort


func _target_rejection_reason(intent: TableSelectionIntent) -> String:
	match intent.selection_kind:
		TableSelectionIntent.KIND_INSPECT_PLAYER:
			return "" if _identity_boundary().public_player_exists(intent.target_player_index) else "target_player_missing"
		TableSelectionIntent.KIND_SELECT_DISTRICT:
			return "" if _identity_boundary().public_district_exists(intent.target_district_index) else "target_district_missing"
		TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT:
			return "" if intent.target_trade_product_id.is_empty() or ProductMarketRuntimeController.PRODUCT_CATALOG.has(intent.target_trade_product_id) else "target_trade_product_missing"
		TableSelectionIntent.KIND_SELECT_HAND_SLOT:
			return "" if intent.target_hand_slot == -1 or _identity_boundary().authorized_player_hand_slot_exists(intent.viewer_index, intent.target_hand_slot) else "target_hand_slot_missing"
		TableSelectionIntent.KIND_SELECT_CARD_RESOLUTION:
			return "" if intent.target_card_resolution_id == -1 or not _public_card_resolution_entry(intent.target_card_resolution_id).is_empty() else "target_card_resolution_missing"
	return ""


func _refresh_kind(selection_kind: StringName) -> StringName:
	return &"map" if selection_kind in [TableSelectionIntent.KIND_MAP_LAYER, TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT] else &"full"


func _refresh_reason(selection_kind: StringName) -> StringName:
	match selection_kind:
		TableSelectionIntent.KIND_INSPECT_PLAYER:
			return &"inspected_player_changed"
		TableSelectionIntent.KIND_SELECT_DISTRICT:
			return &"selected_district_changed"
		TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT:
			return &"selected_trade_product_changed"
		TableSelectionIntent.KIND_SELECT_HAND_SLOT:
			return &"selected_hand_slot_changed"
		TableSelectionIntent.KIND_SELECT_CARD_RESOLUTION:
			return &"selected_card_resolution_changed"
	return &"table_selection_changed"


func _public_card_resolution_entry(resolution_id: int) -> Dictionary:
	if resolution_id < 0:
		return {}
	var queue := get_node_or_null(card_resolution_queue_path) as CardResolutionQueueRuntimeService
	if queue != null:
		var queue_snapshot := queue.public_snapshot()
		for lane_name in ["current", "next"]:
			var lane: Array = queue_snapshot.get(lane_name, []) if queue_snapshot.get(lane_name, []) is Array else []
			for entry_variant in lane:
				if entry_variant is Dictionary and int((entry_variant as Dictionary).get("resolution_id", -1)) == resolution_id:
					return (entry_variant as Dictionary).duplicate(true)
		var active: Dictionary = queue_snapshot.get("active", {}) if queue_snapshot.get("active", {}) is Dictionary else {}
		if int(active.get("resolution_id", -1)) == resolution_id:
			return active.duplicate(true)
	var history := get_node_or_null(card_resolution_history_path) as CardResolutionHistoryRuntimeService
	if history != null:
		for entry_variant in history.public_history_snapshot():
			if entry_variant is Dictionary and int((entry_variant as Dictionary).get("resolution_id", -1)) == resolution_id:
				return (entry_variant as Dictionary).duplicate(true)
	return {}


func _public_target_district(entry: Dictionary) -> int:
	if entry.is_empty():
		return -1
	if str(entry.get("card_kind", "")) == "area_trade_contract":
		for key in ["contract_target_district", "contract_source_district"]:
			var contract_index := int(entry.get(key, -1))
			if _identity_boundary().public_district_exists(contract_index):
				return contract_index
	var selected_index := int(entry.get("selected_district", -1))
	if _identity_boundary().public_district_exists(selected_index):
		return selected_index
	for key in ["contract_target_district", "contract_source_district"]:
		var fallback_index := int(entry.get(key, -1))
		if _identity_boundary().public_district_exists(fallback_index):
			return fallback_index
	return -1
