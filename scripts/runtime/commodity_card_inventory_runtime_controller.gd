@tool
extends Node
class_name CommodityCardInventoryRuntimeController

const RULESET_ID := "v0.6"
const STATE_VERSION := 1
const CATALOG := preload("res://resources/cards/runtime/card_runtime_catalog_v06.tres")
const TRANSACTION_SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")

@onready var effect_bridge: CommodityCardEffectRuntimeBridge = %CommodityCardEffectRuntimeBridge

var _configured := false
var _world: Node
var _state_port: Node
var _market_quote_authority: Object
var _flow_controller: Node
var _infrastructure_controller: Node
var _transaction_service: Object
var _terminal_operations: Dictionary = {}
var _restored_transaction_journal: Dictionary = {}
var _operation_count := 0
var _last_reason := ""


func set_market_quote_authority(authority: Object) -> void:
	_market_quote_authority = authority


class EffectTransactionBoundary:
	extends RefCounted
	var _delegate: Object
	var _flow_owner: Object
	var _infrastructure_owner: Object
	var _last_commit_result: Dictionary = {}

	func _init(delegate: Object, flow_owner: Object, infrastructure_owner: Object) -> void:
		_delegate = delegate
		_flow_owner = flow_owner
		_infrastructure_owner = infrastructure_owner

	func prepare_effect(intent: Dictionary) -> Dictionary:
		if _delegate == null or not _delegate.has_method("prepare_effect"):
			return {"prepared": false, "committed": false, "reason_code": "effect_handler_unavailable"}
		var value_variant: Variant = _delegate.call("prepare_effect", intent.duplicate(true))
		return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"prepared": false, "committed": false, "reason_code": "effect_prepare_invalid"}

	func commit_effect(prepared: Dictionary) -> Dictionary:
		if _delegate == null or not _delegate.has_method("commit_effect"):
			_last_commit_result = {"prepared": false, "committed": false, "reason_code": "effect_handler_unavailable"}
			return _last_commit_result.duplicate(true)
		var value_variant: Variant = _delegate.call("commit_effect", prepared.duplicate(true))
		_last_commit_result = (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"prepared": false, "committed": false, "reason_code": "effect_commit_invalid"}
		return _last_commit_result.duplicate(true)

	func last_commit_result() -> Dictionary:
		return _last_commit_result.duplicate(true)

	func abort_prepared_effect(prepared: Dictionary) -> void:
		if _delegate != null and _delegate.has_method("abort_prepared_effect"):
			_delegate.call("abort_prepared_effect", prepared.duplicate(true))

	func rollback_effect(receipt: Dictionary) -> Dictionary:
		var delegate_result: Dictionary = {}
		if _delegate != null and _delegate.has_method("rollback_effect"):
			var delegate_variant: Variant = _delegate.call("rollback_effect", receipt.duplicate(true))
			if delegate_variant is Dictionary:
				delegate_result = (delegate_variant as Dictionary).duplicate(true)
				if bool(delegate_result.get("rolled_back", false)):
					return delegate_result
		if not _find_receipt_kind(receipt, "facility_commodity_composite").is_empty():
			if delegate_result.is_empty():
				delegate_result = {"rolled_back": false, "committed": true, "reason_code": "composite_effect_rollback_failed"}
			delegate_result["composite_receipt_preserved"] = true
			return delegate_result
		var owner_receipt := _find_authoritative_owner_receipt(receipt)
		var owner_result := _rollback_owner_receipt(owner_receipt)
		owner_result["delegate_result"] = delegate_result
		return owner_result

	func finalize_effect(receipt: Dictionary) -> Dictionary:
		var delegate_result: Dictionary = {}
		if _delegate != null and _delegate.has_method("finalize_effect"):
			var delegate_variant: Variant = _delegate.call("finalize_effect", receipt.duplicate(true))
			if delegate_variant is Dictionary:
				delegate_result = (delegate_variant as Dictionary).duplicate(true)
				if bool(delegate_result.get("finalized", false)):
					return delegate_result
		if not _find_receipt_kind(receipt, "facility_commodity_composite").is_empty():
			if delegate_result.is_empty():
				delegate_result = {"finalized": false, "reason_code": "composite_effect_finalize_failed"}
			delegate_result["composite_receipt_preserved"] = true
			return delegate_result
		var owner_receipt := _find_authoritative_owner_receipt(receipt)
		var owner_result := _finalize_owner_receipt(owner_receipt)
		if bool(owner_result.get("finalized", false)):
			_close_delegate_association(receipt)
		owner_result["delegate_result"] = delegate_result
		return owner_result

	func _close_delegate_association(receipt: Dictionary) -> void:
		if _delegate != null and _delegate.has_method("abort_prepared_effect"):
			_delegate.call("abort_prepared_effect", receipt.duplicate(true))

	func _rollback_owner_receipt(owner_receipt: Dictionary) -> Dictionary:
		if owner_receipt.is_empty():
			return {"rolled_back": false, "committed": true, "reason_code": "effect_rollback_owner_receipt_missing"}
		match str(owner_receipt.get("receipt_kind", "")):
			"commodity_installation":
				if _flow_owner != null and _flow_owner.has_method("rollback_commodity_installation"):
					var value_variant: Variant = _flow_owner.call("rollback_commodity_installation", str(owner_receipt.get("transaction_id", "")))
					return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"rolled_back": false, "reason_code": "commodity_installation_rollback_invalid"}
			"commodity_flow_card_effect_batch":
				if _flow_owner != null and _flow_owner.has_method("rollback_card_effect_batch"):
					var value_variant: Variant = _flow_owner.call("rollback_card_effect_batch", owner_receipt.duplicate(true))
					return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"rolled_back": false, "reason_code": "commodity_batch_rollback_invalid"}
			"facility_action":
				if _infrastructure_owner != null and _infrastructure_owner.has_method("rollback_facility_action"):
					var value_variant: Variant = _infrastructure_owner.call("rollback_facility_action", owner_receipt.duplicate(true))
					return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"rolled_back": false, "reason_code": "facility_action_rollback_invalid"}
		return {"rolled_back": false, "committed": true, "reason_code": "effect_rollback_owner_unavailable"}

	func _finalize_owner_receipt(owner_receipt: Dictionary) -> Dictionary:
		if owner_receipt.is_empty():
			return {"finalized": false, "reason_code": "effect_finalize_owner_receipt_missing"}
		match str(owner_receipt.get("receipt_kind", "")):
			"commodity_installation":
				if _flow_owner != null and _flow_owner.has_method("finalize_commodity_installation"):
					var value_variant: Variant = _flow_owner.call("finalize_commodity_installation", owner_receipt.duplicate(true))
					return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"finalized": false, "reason_code": "commodity_installation_finalize_invalid"}
			"commodity_flow_card_effect_batch":
				if _flow_owner != null and _flow_owner.has_method("finalize_card_effect_batch"):
					var value_variant: Variant = _flow_owner.call("finalize_card_effect_batch", owner_receipt.duplicate(true))
					return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"finalized": false, "reason_code": "commodity_batch_finalize_invalid"}
			"facility_action":
				if _infrastructure_owner != null and _infrastructure_owner.has_method("finalize_facility_action"):
					var value_variant: Variant = _infrastructure_owner.call("finalize_facility_action", owner_receipt.duplicate(true))
					return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"finalized": false, "reason_code": "facility_action_finalize_invalid"}
		return {"finalized": false, "reason_code": "effect_finalize_owner_unavailable"}

	func _find_authoritative_owner_receipt(value: Variant) -> Dictionary:
		if value is Dictionary:
			var source: Dictionary = value
			if ["commodity_installation", "commodity_flow_card_effect_batch", "facility_action"].has(str(source.get("receipt_kind", ""))):
				return source.duplicate(true)
			for nested_value in source.values():
				var nested := _find_authoritative_owner_receipt(nested_value)
				if not nested.is_empty():
					return nested
		elif value is Array:
			for nested_value in value:
				var nested := _find_authoritative_owner_receipt(nested_value)
				if not nested.is_empty():
					return nested
		return {}

	func _find_receipt_kind(value: Variant, receipt_kind: String) -> Dictionary:
		if value is Dictionary:
			var source: Dictionary = value
			if str(source.get("receipt_kind", "")) == receipt_kind:
				return source.duplicate(true)
			for nested_value in source.values():
				var nested := _find_receipt_kind(nested_value, receipt_kind)
				if not nested.is_empty():
					return nested
		elif value is Array:
			for nested_value in value:
				var nested := _find_receipt_kind(nested_value, receipt_kind)
				if not nested.is_empty():
					return nested
		return {}


func configure(
	profile_snapshot: Dictionary,
	state_port: Node,
	flow_controller: Node,
	infrastructure_controller: Node
) -> Dictionary:
	_state_port = state_port
	_flow_controller = flow_controller
	_infrastructure_controller = infrastructure_controller
	var identity_variant: Variant = profile_snapshot.get("identity", {})
	var identity: Dictionary = identity_variant if identity_variant is Dictionary else {}
	var profile_ruleset_id := str(profile_snapshot.get("ruleset_id", identity.get("ruleset_id", "")))
	var catalog_valid := CATALOG != null and CATALOG.has_method("validation_report") and bool(CATALOG.call("validation_report").get("valid", false))
	_configured = (
		profile_ruleset_id == RULESET_ID
		and catalog_valid
		and _state_port_api_ready()
		and _flow_api_ready()
		and _infrastructure_controller != null
		and _infrastructure_controller.has_method("facilities_snapshot")
		and _infrastructure_controller.has_method("region_snapshot")
	)
	_transaction_service = TRANSACTION_SERVICE_SCRIPT.new(CATALOG, _state_port, _market_quote_authority) if _configured else null
	_refresh_effect_bridge()
	return {
		"configured": _configured,
		"reason": "" if _configured else "commodity_card_inventory_dependencies_invalid",
		"catalog_card_count": int(CATALOG.call("validation_report").get("card_count", 0)) if catalog_valid else 0,
	}


func bind_world(world: Node) -> void:
	_world = world
	if _state_port != null and _state_port.has_method("bind_world"):
		_state_port.call("bind_world", world)
	_refresh_effect_bridge()


func reset_state() -> void:
	_terminal_operations.clear()
	_restored_transaction_journal.clear()
	_operation_count = 0
	_last_reason = ""
	if _state_port != null and _state_port.has_method("reset_state"):
		_state_port.call("reset_state")
	_transaction_service = TRANSACTION_SERVICE_SCRIPT.new(CATALOG, _state_port, _market_quote_authority) if _configured else null
	_refresh_effect_bridge()


func catalog() -> Resource:
	return CATALOG


func configure_belt(revision: int, entries: Array) -> Dictionary:
	if not _service_ready():
		return _failure("controller_not_ready")
	var value_variant: Variant = _transaction_service.call("configure_belt", revision, entries.duplicate(true))
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else _failure("belt_configuration_invalid")


func belt_snapshot() -> Dictionary:
	if not _service_ready():
		return {"revision": 0, "items": {}}
	var value_variant: Variant = _transaction_service.call("belt_snapshot")
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"revision": 0, "items": {}}


func configure_market(revision: int, listing: Dictionary) -> Dictionary:
	if not _service_ready():
		return _failure("controller_not_ready")
	var value_variant: Variant = _transaction_service.call("configure_market", revision, listing.duplicate(true))
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else _failure("market_configuration_invalid")


func market_snapshot() -> Dictionary:
	if not _service_ready():
		return {"revision": 0, "listing": {}}
	var value_variant: Variant = _transaction_service.call("market_snapshot")
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"revision": 0, "listing": {}}


func transaction_journal_snapshot() -> Dictionary:
	var journal := _restored_transaction_journal.duplicate(true)
	if _transaction_service != null and _transaction_service.has_method("journal_snapshot"):
		var runtime_variant: Variant = _transaction_service.call("journal_snapshot")
		if runtime_variant is Dictionary:
			for transaction_id_variant in (runtime_variant as Dictionary).keys():
				journal[str(transaction_id_variant)] = ((runtime_variant as Dictionary).get(transaction_id_variant, {}) as Dictionary).duplicate(true)
	return journal


func player_snapshot(actor_id: String) -> Dictionary:
	if not _service_ready():
		return {}
	var value_variant: Variant = _transaction_service.call("player_snapshot", actor_id)
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}


func claim_belt_card(
	actor_id: String,
	source_item_id: String,
	expected_player_revision: int,
	expected_belt_revision: int,
	transaction_id: String
) -> Dictionary:
	var intent := {
		"operation": "belt_claim",
		"actor_id": actor_id,
		"source_item_id": source_item_id,
		"expected_player_revision": expected_player_revision,
		"expected_belt_revision": expected_belt_revision,
	}
	return _run_terminal_operation(transaction_id, intent, func() -> Dictionary:
		var value_variant: Variant = _transaction_service.call(
			"claim_belt_card",
			actor_id,
			source_item_id,
			expected_player_revision,
			expected_belt_revision,
			transaction_id
		)
		return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else _failure("belt_claim_invalid")
	)


func purchase_market_card(
	actor_id: String,
	source_item_id: String,
	next_listing: Dictionary,
	expected_player_revision: int,
	expected_market_revision: int,
	transaction_id: String,
	quote_request: Dictionary
) -> Dictionary:
	var intent := {
		"operation": "market_purchase",
		"actor_id": actor_id,
		"source_item_id": source_item_id,
		"next_listing": next_listing.duplicate(true),
		"expected_player_revision": expected_player_revision,
		"expected_market_revision": expected_market_revision,
		"quote_id": str(quote_request.get("quote_id", "")),
		"quote_fingerprint": str(quote_request.get("quote_fingerprint", "")),
	}
	return _run_terminal_operation(transaction_id, intent, func() -> Dictionary:
		var value_variant: Variant = _transaction_service.call(
			"purchase_market_card",
			actor_id,
			source_item_id,
			next_listing.duplicate(true),
			expected_player_revision,
			expected_market_revision,
			transaction_id,
			quote_request.duplicate(true)
		)
		return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else _failure("market_purchase_invalid")
	)


func manual_merge(
	actor_id: String,
	first_slot: int,
	second_slot: int,
	expected_player_revision: int,
	transaction_id: String
) -> Dictionary:
	var intent := {
		"operation": "manual_merge",
		"actor_id": actor_id,
		"first_slot": first_slot,
		"second_slot": second_slot,
		"expected_player_revision": expected_player_revision,
	}
	return _run_terminal_operation(transaction_id, intent, func() -> Dictionary:
		var value_variant: Variant = _transaction_service.call(
			"manual_merge",
			actor_id,
			first_slot,
			second_slot,
			expected_player_revision,
			transaction_id
		)
		return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else _failure("manual_merge_invalid")
	)


func play_commodity_card(
	actor_id: String,
	slot_index: int,
	target_context: Dictionary,
	expected_player_revision: int,
	transaction_id: String
) -> Dictionary:
	_refresh_effect_bridge()
	return _play_core_card(
		actor_id,
		slot_index,
		target_context,
		effect_bridge,
		expected_player_revision,
		transaction_id,
		"commodity_play",
		true
	)


func play_core_card(
	actor_id: String,
	slot_index: int,
	target_context: Dictionary,
	effect_handler: Object,
	expected_player_revision: int,
	transaction_id: String
) -> Dictionary:
	return _play_core_card(
		actor_id,
		slot_index,
		target_context,
		effect_handler,
		expected_player_revision,
		transaction_id,
		"core_card_play",
		false
	)


func _play_core_card(
	actor_id: String,
	slot_index: int,
	target_context: Dictionary,
	effect_handler: Object,
	expected_player_revision: int,
	transaction_id: String,
	operation: String,
	require_commodity: bool
) -> Dictionary:
	var intent := {
		"operation": operation,
		"actor_id": actor_id,
		"slot_index": slot_index,
		"target_context": target_context.duplicate(true),
		"expected_player_revision": expected_player_revision,
	}
	return _run_terminal_operation(transaction_id, intent, func() -> Dictionary:
		var snapshot := player_snapshot(actor_id)
		if require_commodity:
			if not _slots_are_commodities(snapshot, [slot_index]):
				return _failure("commodity_play_requires_commodity_card")
		var effect_kind := _slot_effect_kind(snapshot, slot_index)
		if effect_kind == "build_upgrade_or_repair_facility" and not _facility_effect_rollback_atomic_ready():
			return _failure("facility_rollback_atomicity_unavailable")
		var boundary := EffectTransactionBoundary.new(effect_handler, _flow_controller, _infrastructure_controller)
		var value_variant: Variant = _transaction_service.call(
			"play_card",
			actor_id,
			slot_index,
			target_context.duplicate(true),
			boundary,
			expected_player_revision,
			transaction_id
		)
		if not (value_variant is Dictionary):
			return _failure("card_play_invalid")
		var result := (value_variant as Dictionary).duplicate(true)
		var owner_commit := boundary.last_commit_result()
		if not bool(result.get("committed", false)) and bool(owner_commit.get("compensation_failed", false)):
			result["reason_code"] = "effect_compensation_failed"
			result["compensation_failed"] = true
			result["recovery_required"] = true
			result["effect_commit_receipt"] = owner_commit
		return result
	, func(previous_result: Dictionary) -> Dictionary:
		return _retry_terminal_effect_finalization(previous_result, effect_handler)
	)


func to_save_data() -> Dictionary:
	return {
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"belt": belt_snapshot(),
		"market": market_snapshot(),
		"transaction_journal": transaction_journal_snapshot(),
		"terminal_operations": _terminal_operations.duplicate(true),
		"state_port": _state_port.call("to_save_data") if _state_port != null and _state_port.has_method("to_save_data") else {},
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("state_version", 0)) != STATE_VERSION or str(data.get("ruleset_id", "")) != RULESET_ID:
		return {"applied": false, "reason": "commodity_card_inventory_save_invalid"}
	var belt: Dictionary = data.get("belt", {}) if data.get("belt", {}) is Dictionary else {}
	var entries: Array = []
	var items: Dictionary = belt.get("items", {}) if belt.get("items", {}) is Dictionary else {}
	for item_variant in items.values():
		if item_variant is Dictionary:
			entries.append((item_variant as Dictionary).duplicate(true))
	var belt_result := configure_belt(int(belt.get("revision", 0)), entries)
	if not bool(belt_result.get("configured", false)):
		return {"applied": false, "reason": str(belt_result.get("reason_code", "belt_restore_failed"))}
	var market: Dictionary = data.get("market", {}) if data.get("market", {}) is Dictionary else {}
	var market_listing: Dictionary = market.get("listing", {}) if market.get("listing", {}) is Dictionary else {}
	if not market_listing.is_empty():
		var market_result := configure_market(int(market.get("revision", 0)), market_listing)
		if not bool(market_result.get("configured", false)):
			return {"applied": false, "reason": str(market_result.get("reason_code", "market_restore_failed"))}
	var journal_variant: Variant = data.get("transaction_journal", {})
	if not (journal_variant is Dictionary) or not _is_pure_data(journal_variant):
		return {"applied": false, "reason": "transaction_journal_restore_invalid"}
	_restored_transaction_journal = (journal_variant as Dictionary).duplicate(true)
	_terminal_operations = (data.get("terminal_operations", {}) as Dictionary).duplicate(true) if data.get("terminal_operations", {}) is Dictionary else {}
	if _state_port != null and _state_port.has_method("apply_save_data"):
		var state_result_variant: Variant = _state_port.call("apply_save_data", data.get("state_port", {}) as Dictionary)
		if not (state_result_variant is Dictionary) or not bool((state_result_variant as Dictionary).get("applied", false)):
			return {"applied": false, "reason": "state_port_restore_failed"}
	return {"applied": true, "reason": "", "terminal_operation_count": _terminal_operations.size()}


func debug_snapshot() -> Dictionary:
	var port_snapshot: Dictionary = _state_port.call("debug_snapshot") if _state_port != null and _state_port.has_method("debug_snapshot") else {}
	var effect_snapshot: Dictionary = effect_bridge.debug_snapshot() if effect_bridge != null else {}
	var checkpoint := checkpoint_status()
	return {
		"controller_ready": _service_ready(),
		"controller_authoritative": _service_ready(),
		"ruleset_id": RULESET_ID,
		"card_flow_api_script": "res://scripts/cards/v06/card_flow_transaction_service_v06.gd",
		"card_flow_policy_script": "res://scripts/cards/v06/card_flow_policy_v06.gd",
		"catalog_path": "res://resources/cards/runtime/card_runtime_catalog_v06.tres",
		"belt_revision": int(belt_snapshot().get("revision", 0)),
		"belt_item_count": (belt_snapshot().get("items", {}) as Dictionary).size() if belt_snapshot().get("items", {}) is Dictionary else 0,
		"market_revision": int(market_snapshot().get("revision", 0)),
		"market_listing_present": not (market_snapshot().get("listing", {}) as Dictionary).is_empty() if market_snapshot().get("listing", {}) is Dictionary else false,
		"transaction_journal_count": transaction_journal_snapshot().size(),
		"terminal_operation_count": _terminal_operations.size(),
		"checkpoint": checkpoint,
		"operation_count": _operation_count,
		"last_reason": _last_reason,
		"state_port": port_snapshot,
		"effect_bridge": effect_snapshot,
		"effect_transaction_boundary": "transaction_service_to_router_to_authoritative_owner",
		"viewer_belt_visibility_owner": false,
		"stores_player_inventory": false,
	}


func checkpoint_status() -> Dictionary:
	var pending_finalization_ids: Array = []
	var transaction_ids: Array = _terminal_operations.keys()
	transaction_ids.sort()
	for transaction_id_variant in transaction_ids:
		var transaction_id := str(transaction_id_variant)
		var terminal_variant: Variant = _terminal_operations.get(transaction_id, {})
		if not (terminal_variant is Dictionary):
			pending_finalization_ids.append(transaction_id)
			continue
		var terminal: Dictionary = terminal_variant
		var result: Dictionary = terminal.get("result", {}) if terminal.get("result", {}) is Dictionary else {}
		if not bool(result.get("committed", false)):
			if bool(result.get("compensation_failed", false)) or bool(result.get("recovery_required", false)):
				pending_finalization_ids.append(transaction_id)
			continue
		var effect_receipt: Dictionary = result.get("effect_receipt", {}) if result.get("effect_receipt", {}) is Dictionary else {}
		if effect_receipt.is_empty():
			continue
		var finalization: Dictionary = result.get("effect_finalization", {}) if result.get("effect_finalization", {}) is Dictionary else {}
		if not bool(finalization.get("finalized", false)):
			pending_finalization_ids.append(transaction_id)
	return {
		"can_checkpoint": pending_finalization_ids.is_empty(),
		"reason_code": "commodity_card_inventory_checkpoint_ready" if pending_finalization_ids.is_empty() else "core_card_effect_finalization_pending",
		"pending_finalization_count": pending_finalization_ids.size(),
		"pending_finalization_transaction_ids": pending_finalization_ids,
	}


func _refresh_effect_bridge() -> void:
	if effect_bridge == null:
		return
	var actor_map: Dictionary = _state_port.call("actor_player_indices") if _state_port != null and _state_port.has_method("actor_player_indices") else {}
	effect_bridge.configure(_flow_controller, _infrastructure_controller, actor_map)


func _slots_are_commodities(player_state: Dictionary, slot_indices: Array) -> bool:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index_variant in slot_indices:
		var slot_index := int(slot_index_variant)
		if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
			return false
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("category_id", "")) != "commodity" or str(machine.get("effect_kind", "")) != "install_commodity_rate":
			return false
	return true


func _slot_effect_kind(player_state: Dictionary, slot_index: int) -> String:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return ""
	var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
	return str(machine.get("effect_kind", ""))


func _facility_effect_rollback_atomic_ready() -> bool:
	if _infrastructure_controller == null:
		return false
	for method_name in [
		"apply_facility_action",
		"rollback_facility_action",
		"finalize_facility_action",
		"facility_action_checkpoint_status",
		"facility_rollback_atomic_ready",
	]:
		if not _infrastructure_controller.has_method(method_name):
			return false
	return bool(_infrastructure_controller.call("facility_rollback_atomic_ready"))


func _run_terminal_operation(transaction_id: String, intent: Dictionary, callback: Callable, replay_handler: Callable = Callable()) -> Dictionary:
	if not _service_ready():
		return _failure("controller_not_ready")
	var tx := transaction_id.strip_edges()
	if tx.is_empty():
		return _failure("transaction_id_missing")
	var intent_hash := _stable_hash(intent)
	if _terminal_operations.has(tx):
		var terminal: Dictionary = _terminal_operations.get(tx, {}) as Dictionary
		if str(terminal.get("intent_hash", "")) != intent_hash:
			return _failure("transaction_intent_collision")
		var replay: Dictionary = (terminal.get("result", {}) as Dictionary).duplicate(true)
		if replay_handler.is_valid():
			var retry_variant: Variant = replay_handler.call(replay.duplicate(true))
			if retry_variant is Dictionary:
				replay = (retry_variant as Dictionary).duplicate(true)
				terminal["result"] = replay.duplicate(true)
				_terminal_operations[tx] = terminal
		replay["idempotent_replay"] = true
		replay["replayed"] = true
		return replay
	_operation_count += 1
	var result: Dictionary = callback.call()
	_last_reason = str(result.get("reason_code", result.get("reason", "")))
	_terminal_operations[tx] = {"intent_hash": intent_hash, "result": result.duplicate(true)}
	return result


func _retry_terminal_effect_finalization(previous_result: Dictionary, effect_handler: Object) -> Dictionary:
	if not bool(previous_result.get("committed", false)):
		return previous_result
	var prior_finalization: Dictionary = previous_result.get("effect_finalization", {}) if previous_result.get("effect_finalization", {}) is Dictionary else {}
	if bool(prior_finalization.get("finalized", false)):
		return previous_result
	var effect_receipt: Dictionary = previous_result.get("effect_receipt", {}) if previous_result.get("effect_receipt", {}) is Dictionary else {}
	if effect_receipt.is_empty():
		return previous_result
	var boundary := EffectTransactionBoundary.new(effect_handler, _flow_controller, _infrastructure_controller)
	var finalization := boundary.finalize_effect(effect_receipt)
	var next_result := previous_result.duplicate(true)
	next_result["effect_finalization"] = finalization.duplicate(true)
	return next_result


func _service_ready() -> bool:
	return _configured and _transaction_service != null and _state_port != null and effect_bridge != null


func _state_port_api_ready() -> bool:
	if _state_port == null:
		return false
	for method_name in [
		"actor_player_indices",
		"register_player",
		"read_player",
		"reserve_transaction",
		"prepare_reserved_mutations",
		"commit_reserved",
		"abort_reserved",
		"to_save_data",
		"apply_save_data",
	]:
		if not _state_port.has_method(method_name):
			return false
	return true


func _flow_api_ready() -> bool:
	if _flow_controller == null:
		return false
	for method_name in [
		"install_commodity",
		"finalize_commodity_installation",
		"rollback_commodity_installation",
		"card_effect_candidates_snapshot",
		"prepare_card_effect_batch",
		"commit_card_effect_batch",
		"rollback_card_effect_batch",
		"finalize_card_effect_batch",
	]:
		if not _flow_controller.has_method(method_name):
			return false
	return true


func _failure(reason_code: String) -> Dictionary:
	_last_reason = reason_code
	return {
		"committed": false,
		"reason_code": reason_code,
		"idempotent_replay": false,
	}


func _stable_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize(source.get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonicalize(item))
		return result
	return value


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is bool or value is int or value is float or value is String:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String) or not _is_pure_data((value as Dictionary).get(key_variant)):
				return false
		return true
	return false
