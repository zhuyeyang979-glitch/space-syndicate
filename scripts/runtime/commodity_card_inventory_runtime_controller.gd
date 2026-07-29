@tool
extends Node
class_name CommodityCardInventoryRuntimeController

const RULESET_ID := "v0.6"
const STATE_VERSION := 1
const CATALOG := preload("res://resources/cards/runtime/card_runtime_catalog_v06.tres")
const TRANSACTION_SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const AlphaContentLoader := preload("res://scripts/runtime/alpha01_content_manifest_loader.gd")
const SAVE_FIELDS := [
	"state_version",
	"ruleset_id",
	"belt",
	"market",
	"transaction_journal",
	"terminal_operations",
	"state_port",
]
const JOURNAL_RECORD_FIELDS := ["intent_hash", "result"]
const FORBIDDEN_JOURNAL_STATE_FIELDS := [
	"player_state",
	"player_states",
	"player_snapshot",
	"previous_player_state",
	"inventory",
	"slots",
	"cash",
	"cash_cents",
	"runtime_instance_id",
	"result_instance_id",
]

@onready var effect_bridge: CommodityCardEffectRuntimeBridge = %CommodityCardEffectRuntimeBridge

var _configured := false
var _world_session_state: WorldSessionState
var _state_port: Node
var _market_quote_authority: Object
var _region_supply_source_port: Object
var _flow_controller: Node
var _infrastructure_controller: Node
var _transaction_service: Object
var _terminal_operations: Dictionary = {}
var _restored_transaction_journal: Dictionary = {}
var _operation_count := 0
var _last_reason := ""


func set_market_quote_authority(authority: Object) -> void:
	_market_quote_authority = authority


func set_region_supply_source_port(source_port: Object) -> Dictionary:
	_region_supply_source_port = source_port
	if _transaction_service != null \
			and _transaction_service.has_method("set_region_supply_source_port"):
		var value_variant: Variant = _transaction_service.call(
			"set_region_supply_source_port",
			source_port
		)
		return (value_variant as Dictionary).duplicate(true) \
			if value_variant is Dictionary \
			else _failure("region_supply_source_unavailable")
	return {
		"configured": _region_supply_source_api_ready(),
		"reason_code": "region_supply_source_staged" \
			if _region_supply_source_api_ready() \
			else "region_supply_source_unavailable",
	}


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
	_attach_region_supply_source_port()
	_refresh_effect_bridge()
	return {
		"configured": _configured,
		"reason": "" if _configured else "commodity_card_inventory_dependencies_invalid",
		"catalog_card_count": int(CATALOG.call("validation_report").get("card_count", 0)) if catalog_valid else 0,
	}


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state
	if _state_port is CardPlayerStateProductionAdapterV06:
		(_state_port as CardPlayerStateProductionAdapterV06).set_world_session_state(state)
	_refresh_effect_bridge()


func reset_state() -> void:
	_terminal_operations.clear()
	_restored_transaction_journal.clear()
	_operation_count = 0
	_last_reason = ""
	if _state_port != null and _state_port.has_method("reset_state"):
		_state_port.call("reset_state")
	_transaction_service = TRANSACTION_SERVICE_SCRIPT.new(CATALOG, _state_port, _market_quote_authority) if _configured else null
	_attach_region_supply_source_port()
	_refresh_effect_bridge()


func catalog() -> Resource:
	return CATALOG


func configure_belt(revision: int, entries: Array) -> Dictionary:
	if not _service_ready():
		return _failure("controller_not_ready")
	var value_variant: Variant = _transaction_service.call("configure_belt", revision, entries.duplicate(true))
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else _failure("belt_configuration_invalid")


func initialize_default_belt_if_empty(gameplay_seed: int = 1, selected_card_ids: Array = []) -> Dictionary:
	if not _service_ready():
		return _failure("controller_not_ready")
	var current := belt_snapshot()
	var current_items: Dictionary = current.get("items", {}) if current.get("items", {}) is Dictionary else {}
	if int(current.get("revision", 0)) > 0 or not current_items.is_empty():
		return {
			"configured": true,
			"reason_code": "commodity_belt_preserved",
			"belt": current,
		}
	var content := AlphaContentLoader.load_active_selection()
	if not content.is_valid():
		return _failure("alpha01_content_selection_invalid")
	var requested_ids: Array = selected_card_ids.duplicate() if not selected_card_ids.is_empty() else content.commodity_track_card_ids.duplicate()
	if requested_ids.size() != Alpha01RuntimeContentSelection.EXPECTED_COMMODITY_CARD_COUNT:
		return _failure("commodity_belt_selection_count_invalid")
	var order_result := selected_belt_card_order(gameplay_seed, requested_ids)
	if not bool(order_result.get("valid", false)):
		return _failure(str(order_result.get("reason_code", "commodity_belt_selection_invalid")))
	var selected_order: Array = order_result.get("card_ids", []) if order_result.get("card_ids", []) is Array else []
	var entries: Array = []
	for slot_index in range(selected_order.size()):
		var card_id := str(selected_order[slot_index])
		var card: Dictionary = CATALOG.call("card_snapshot", card_id)
		entries.append({
			"item_id": "commodity_slot:%02d:%s" % [slot_index, card_id],
			"card": card,
			"claimable": true,
			"visible_actor_ids": [],
		})
	if entries.size() != Alpha01RuntimeContentSelection.EXPECTED_COMMODITY_CARD_COUNT:
		return _failure("commodity_belt_seed_incomplete")
	var result := configure_belt(1, entries)
	result["deterministic_seed"] = maxi(1, gameplay_seed)
	result["seed_item_count"] = entries.size()
	result["selected_card_ids"] = selected_order.duplicate()
	return result


func selected_belt_card_order(gameplay_seed: int, selected_card_ids: Array = []) -> Dictionary:
	var content := AlphaContentLoader.load_active_selection()
	if not content.is_valid():
		return {"valid": false, "reason_code": "alpha01_content_selection_invalid", "card_ids": []}
	var requested_ids: Array = selected_card_ids.duplicate() if not selected_card_ids.is_empty() else content.commodity_track_card_ids.duplicate()
	if requested_ids.size() != Alpha01RuntimeContentSelection.EXPECTED_COMMODITY_CARD_COUNT:
		return {"valid": false, "reason_code": "commodity_belt_selection_count_invalid", "card_ids": []}
	var seen: Dictionary = {}
	var weighted_rows: Array[Dictionary] = []
	for card_id_variant in requested_ids:
		var card_id := str(card_id_variant).strip_edges()
		var card: Dictionary = CATALOG.call("card_snapshot", card_id)
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var rank_is_one := int(machine.get("rank", 0)) == 1
		if card.is_empty() or not rank_is_one or str(machine.get("category_id", "")) != "commodity" or str(machine.get("acquisition_kind", "")) != "commodity_belt_free" or seen.has(card_id):
			return {"valid": false, "reason_code": "commodity_belt_selection_invalid", "card_ids": []}
		seen[card_id] = true
		weighted_rows.append({"item_id": card_id, "weight": 1})
	var shuffled := RunRngService.deterministic_weighted_shuffle(weighted_rows, maxi(1, gameplay_seed))
	return {
		"valid": true,
		"reason_code": "commodity_belt_order_ready",
		"gameplay_seed": maxi(1, gameplay_seed),
		"card_ids": (shuffled.get("items", []) as Array).duplicate(),
	}


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
	for transaction_id_variant in _terminal_operations.keys():
		var terminal_variant: Variant = _terminal_operations.get(transaction_id_variant, {})
		if terminal_variant is Dictionary:
			journal[str(transaction_id_variant)] = (terminal_variant as Dictionary).duplicate(true)
	return journal


func player_snapshot(actor_id: String) -> Dictionary:
	if not _service_ready():
		return {}
	var value_variant: Variant = _transaction_service.call("player_snapshot", actor_id)
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}


func discardable_slots(actor_id: String) -> Array:
	if not _service_ready() \
			or not _transaction_service.has_method("discardable_slots"):
		return []
	var value_variant: Variant = _transaction_service.call(
		"discardable_slots",
		actor_id
	)
	return (value_variant as Array).duplicate() if value_variant is Array else []


func region_supply_receive_preview(
	actor_id: String,
	card_id: String,
	discard_slot: int = -1
) -> Dictionary:
	if not _service_ready() \
			or not _transaction_service.has_method(
				"region_supply_receive_preview"
			):
		return {
			"ready": false,
			"requires_discard": false,
			"reason_code": "controller_not_ready",
			"discardable_slots": [],
		}
	var value_variant: Variant = _transaction_service.call(
		"region_supply_receive_preview",
		actor_id,
		card_id,
		discard_slot
	)
	return (
		(value_variant as Dictionary).duplicate(true)
		if value_variant is Dictionary
		else {
			"ready": false,
			"requires_discard": false,
			"reason_code": "region_supply_receive_preview_invalid",
			"discardable_slots": [],
		}
	)


func region_supply_receive_previews(
	actor_id: String,
	card_ids: Array,
	discard_slot: int = -1
) -> Dictionary:
	if not _service_ready() \
			or not _transaction_service.has_method(
				"region_supply_receive_previews"
			):
		return {
			"accepted": false,
			"reason_code": "controller_not_ready",
			"player_revision": -1,
			"card_ids": [],
			"plans_by_card_id": {},
		}
	var value_variant: Variant = _transaction_service.call(
		"region_supply_receive_previews",
		actor_id,
		card_ids.duplicate(),
		discard_slot
	)
	return (
		(value_variant as Dictionary).duplicate(true)
		if value_variant is Dictionary
		else {
			"accepted": false,
			"reason_code": "region_supply_receive_previews_invalid",
			"player_revision": -1,
			"card_ids": [],
			"plans_by_card_id": {},
		}
	)


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


func purchase_region_supply_card(
	actor_id: String,
	region_id: String,
	slot_index: int,
	source_item_id: String,
	card_id: String,
	expected_player_revision: int,
	expected_supply_revision: String,
	transaction_id: String,
	quote_request: Dictionary,
	discard_slot: int = -1
) -> Dictionary:
	var intent := {
		"operation": "region_supply_purchase",
		"actor_id": actor_id,
		"region_id": region_id,
		"slot_index": slot_index,
		"source_item_id": source_item_id,
		"card_id": card_id,
		"expected_player_revision": expected_player_revision,
		"expected_supply_revision": expected_supply_revision,
		"quote_id": str(quote_request.get("quote_id", "")),
		"quote_fingerprint": str(quote_request.get("quote_fingerprint", "")),
		"discard_slot": discard_slot,
	}
	return _run_terminal_operation(transaction_id, intent, func() -> Dictionary:
		var value_variant: Variant = _transaction_service.call(
			"purchase_region_supply_card",
			actor_id,
			region_id,
			slot_index,
			source_item_id,
			card_id,
			expected_player_revision,
			expected_supply_revision,
			transaction_id,
			quote_request.duplicate(true),
			discard_slot
		)
		return (value_variant as Dictionary).duplicate(true) \
			if value_variant is Dictionary \
			else _failure("region_supply_purchase_invalid")
	, func(previous_result: Dictionary) -> Dictionary:
		return _retry_terminal_region_supply_finalization(previous_result)
	)


func grant_card(
	actor_id: String,
	card_id: String,
	expected_player_revision: int,
	transaction_id: String,
	grant_reason: String = ""
) -> Dictionary:
	var intent := {
		"operation": "grant_card",
		"actor_id": actor_id,
		"card_id": card_id,
		"expected_player_revision": expected_player_revision,
		"grant_reason": grant_reason,
	}
	return _run_terminal_operation(transaction_id, intent, func() -> Dictionary:
		var value_variant: Variant = _transaction_service.call(
			"grant_card",
			actor_id,
			card_id,
			expected_player_revision,
			transaction_id,
			grant_reason
		)
		return (
			(value_variant as Dictionary).duplicate(true)
			if value_variant is Dictionary
			else _failure("grant_card_invalid")
		)
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
	var checkpoint := checkpoint_status()
	if not bool(checkpoint.get("can_checkpoint", false)):
		return {}
	if _state_port != null and _state_port.has_method("checkpoint_status"):
		var state_port_status_variant: Variant = _state_port.call("checkpoint_status")
		if not (state_port_status_variant is Dictionary) \
				or not bool((state_port_status_variant as Dictionary).get("can_checkpoint", false)):
			return {}
	var candidate := {
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"belt": belt_snapshot(),
		"market": market_snapshot(),
		"transaction_journal": _journal_save_snapshot(transaction_journal_snapshot()),
		"terminal_operations": _journal_save_snapshot(_terminal_operations),
		"state_port": _state_port.call("to_save_data") if _state_port != null and _state_port.has_method("to_save_data") else {},
	}
	var preflight := preflight_save_data(candidate)
	return (preflight.get("normalized_state", {}) as Dictionary).duplicate(true) \
			if bool(preflight.get("accepted", false)) else {}


func preflight_save_data(data: Dictionary) -> Dictionary:
	if not _service_ready() or not _has_exact_keys(data, SAVE_FIELDS) or not _is_pure_data(data) \
			or not (data.get("state_version") is int) or int(data.get("state_version", 0)) != STATE_VERSION \
			or not (data.get("ruleset_id") is String) or str(data.get("ruleset_id", "")) != RULESET_ID:
		return {"accepted": false, "reason_code": "commodity_card_inventory_save_invalid"}
	for field in ["belt", "market", "transaction_journal", "terminal_operations", "state_port"]:
		if not (data.get(field) is Dictionary):
			return {"accepted": false, "reason_code": "commodity_card_inventory_save_children_invalid", "failing_child": field}
	if _contains_forbidden_journal_state(data.get("transaction_journal", {})):
		return {"accepted": false, "reason_code": "transaction_journal_world_state_forbidden", "failing_child": "transaction_journal"}
	if not _transaction_service.has_method("preflight_restore_state"):
		return {"accepted": false, "reason_code": "card_flow_restore_contract_missing"}
	var flow_preflight_variant: Variant = _transaction_service.call("preflight_restore_state", {
		"belt": (data.get("belt", {}) as Dictionary).duplicate(true),
		"market": (data.get("market", {}) as Dictionary).duplicate(true),
		"journal": (data.get("transaction_journal", {}) as Dictionary).duplicate(true),
	})
	var flow_preflight: Dictionary = flow_preflight_variant if flow_preflight_variant is Dictionary else {}
	if not bool(flow_preflight.get("accepted", false)):
		return {"accepted": false, "reason_code": str(flow_preflight.get("reason_code", "card_flow_restore_preflight_failed")), "failing_child": "card_flow"}
	var normalized_flow := flow_preflight.get("normalized_state", {}) as Dictionary
	var terminal_preflight := _preflight_terminal_operations(data.get("terminal_operations", {}) as Dictionary)
	if not bool(terminal_preflight.get("accepted", false)):
		return terminal_preflight
	var normalized_terminals := terminal_preflight.get("normalized_state", {}) as Dictionary
	var normalized_journal := normalized_flow.get("journal", {}) as Dictionary
	for transaction_id_variant in normalized_terminals.keys():
		var transaction_id := str(transaction_id_variant)
		if not normalized_journal.has(transaction_id) \
				or normalized_journal.get(transaction_id) != normalized_terminals.get(transaction_id):
			return {"accepted": false, "reason_code": "terminal_operation_journal_mismatch", "failing_child": "terminal_operations"}
	var state_port_preflight: Dictionary = {}
	if _state_port.has_method("preflight_save_data"):
		var state_port_variant: Variant = _state_port.call("preflight_save_data", data.get("state_port", {}))
		state_port_preflight = state_port_variant if state_port_variant is Dictionary else {}
	else:
		var state_port_data := data.get("state_port", {}) as Dictionary
		state_port_preflight = {
			"accepted": int(state_port_data.get("state_version", 0)) == 1 \
					and str(state_port_data.get("ruleset_id", "")) == RULESET_ID \
					and state_port_data.get("journal", {}) is Dictionary,
			"normalized_state": state_port_data.duplicate(true),
			"reason_code": "production_state_port_save_valid",
		}
	if not bool(state_port_preflight.get("accepted", false)):
		return {"accepted": false, "reason_code": str(state_port_preflight.get("reason_code", "state_port_restore_preflight_failed")), "failing_child": "state_port"}
	return {
		"accepted": true,
		"reason_code": "commodity_card_inventory_save_valid",
		"normalized_state": {
			"state_version": STATE_VERSION,
			"ruleset_id": RULESET_ID,
			"belt": (normalized_flow.get("belt", {}) as Dictionary).duplicate(true),
			"market": (normalized_flow.get("market", {}) as Dictionary).duplicate(true),
			"transaction_journal": normalized_journal.duplicate(true),
			"terminal_operations": normalized_terminals.duplicate(true),
			"state_port": (state_port_preflight.get("normalized_state", {}) as Dictionary).duplicate(true),
		},
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "commodity_card_inventory_save_invalid")), "reason": str(preflight.get("reason_code", "commodity_card_inventory_save_invalid")), "rollback_attempted": false, "rollback_complete": true}
	var current_status := checkpoint_status()
	if not bool(current_status.get("can_checkpoint", false)):
		return {"applied": false, "reason_code": str(current_status.get("reason_code", "commodity_card_inventory_checkpoint_blocked")), "reason": str(current_status.get("reason_code", "commodity_card_inventory_checkpoint_blocked")), "rollback_attempted": false, "rollback_complete": true}
	if _state_port.has_method("checkpoint_status"):
		var state_port_status_variant: Variant = _state_port.call("checkpoint_status")
		if not (state_port_status_variant is Dictionary) \
				or not bool((state_port_status_variant as Dictionary).get("can_checkpoint", false)):
			return {"applied": false, "reason_code": "card_player_state_checkpoint_blocked", "reason": "card_player_state_checkpoint_blocked", "rollback_attempted": false, "rollback_complete": true}
	var normalized := preflight.get("normalized_state", {}) as Dictionary
	var checkpoint := capture_runtime_checkpoint()
	var flow_apply_variant: Variant = _transaction_service.call("apply_restore_state", {
		"belt": normalized.get("belt", {}),
		"market": normalized.get("market", {}),
		"journal": normalized.get("transaction_journal", {}),
	})
	var flow_apply: Dictionary = flow_apply_variant if flow_apply_variant is Dictionary else {}
	if not bool(flow_apply.get("applied", false)):
		return _apply_restore_failure("card_flow", str(flow_apply.get("reason_code", "card_flow_restore_failed")), checkpoint, false)
	var state_result_variant: Variant = _state_port.call("apply_save_data", normalized.get("state_port", {}) as Dictionary)
	var state_result: Dictionary = state_result_variant if state_result_variant is Dictionary else {}
	if not bool(state_result.get("applied", false)):
		return _apply_restore_failure("state_port", str(state_result.get("reason_code", "state_port_restore_failed")), checkpoint, true)
	_restored_transaction_journal = (normalized.get("transaction_journal", {}) as Dictionary).duplicate(true)
	_terminal_operations = (normalized.get("terminal_operations", {}) as Dictionary).duplicate(true)
	return {"applied": true, "reason_code": "commodity_card_inventory_restored", "reason": "", "terminal_operation_count": _terminal_operations.size(), "rollback_attempted": false, "rollback_complete": true}


func capture_runtime_checkpoint() -> Dictionary:
	var flow_checkpoint: Dictionary = _transaction_service.call("capture_runtime_checkpoint") \
			if _transaction_service != null and _transaction_service.has_method("capture_runtime_checkpoint") else {}
	var state_port_checkpoint: Dictionary = _state_port.call("capture_runtime_checkpoint") \
			if _state_port != null and _state_port.has_method("capture_runtime_checkpoint") else {
				"save_data": _state_port.call("to_save_data") if _state_port != null and _state_port.has_method("to_save_data") else {},
			}
	return {
		"schema_version": 1,
		"flow": flow_checkpoint.duplicate(true),
		"state_port": state_port_checkpoint.duplicate(true),
		"state_port_runtime_checkpoint": _state_port != null and _state_port.has_method("restore_runtime_checkpoint"),
		"terminal_operations": _terminal_operations.duplicate(true),
		"restored_transaction_journal": _restored_transaction_journal.duplicate(true),
		"operation_count": _operation_count,
		"last_reason": _last_reason,
	}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1 or not (checkpoint.get("flow") is Dictionary) \
			or not (checkpoint.get("state_port") is Dictionary) or not (checkpoint.get("terminal_operations") is Dictionary) \
			or not (checkpoint.get("restored_transaction_journal") is Dictionary):
		return {"applied": false, "reason_code": "commodity_card_inventory_checkpoint_invalid"}
	var failures: Array[String] = []
	if bool(checkpoint.get("state_port_runtime_checkpoint", false)) and _state_port.has_method("restore_runtime_checkpoint"):
		var state_restore_variant: Variant = _state_port.call("restore_runtime_checkpoint", checkpoint.get("state_port", {}))
		if not (state_restore_variant is Dictionary) or not bool((state_restore_variant as Dictionary).get("applied", false)):
			failures.append("state_port")
	elif _state_port.has_method("apply_save_data"):
		var state_port_checkpoint := checkpoint.get("state_port", {}) as Dictionary
		var fallback_state: Dictionary = state_port_checkpoint.get("save_data", {}) \
				if state_port_checkpoint.get("save_data", {}) is Dictionary else {}
		var fallback_variant: Variant = _state_port.call("apply_save_data", fallback_state)
		if not (fallback_variant is Dictionary) or not bool((fallback_variant as Dictionary).get("applied", false)):
			failures.append("state_port")
	if _transaction_service == null or not _transaction_service.has_method("restore_runtime_checkpoint"):
		failures.append("card_flow")
	else:
		var flow_restore_variant: Variant = _transaction_service.call("restore_runtime_checkpoint", checkpoint.get("flow", {}))
		if not (flow_restore_variant is Dictionary) or not bool((flow_restore_variant as Dictionary).get("applied", false)):
			failures.append("card_flow")
	_terminal_operations = (checkpoint.get("terminal_operations", {}) as Dictionary).duplicate(true)
	_restored_transaction_journal = (checkpoint.get("restored_transaction_journal", {}) as Dictionary).duplicate(true)
	_operation_count = int(checkpoint.get("operation_count", 0))
	_last_reason = str(checkpoint.get("last_reason", ""))
	return {"applied": failures.is_empty(), "reason_code": "commodity_card_inventory_checkpoint_restored" if failures.is_empty() else "commodity_card_inventory_checkpoint_restore_failed", "failures": failures}


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
		"region_supply_source_ready": _region_supply_source_api_ready(),
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
	var pending_effect_finalization_ids: Array = []
	var pending_region_supply_finalization_ids: Array = []
	var pending_other_recovery_ids: Array = []
	var transaction_ids: Array = _terminal_operations.keys()
	transaction_ids.sort()
	for transaction_id_variant in transaction_ids:
		var transaction_id := str(transaction_id_variant)
		var terminal_variant: Variant = _terminal_operations.get(transaction_id, {})
		if not (terminal_variant is Dictionary):
			pending_other_recovery_ids.append(transaction_id)
			continue
		var terminal: Dictionary = terminal_variant
		var result: Dictionary = terminal.get("result", {}) if terminal.get("result", {}) is Dictionary else {}
		if not bool(result.get("committed", false)):
			if bool(result.get("compensation_failed", false)) or bool(result.get("recovery_required", false)):
				if result.get("region_supply_receipt", {}) is Dictionary \
						and not (result.get("region_supply_receipt", {}) as Dictionary).is_empty():
					pending_region_supply_finalization_ids.append(transaction_id)
				elif result.get("effect_receipt", {}) is Dictionary \
						and not (result.get("effect_receipt", {}) as Dictionary).is_empty():
					pending_effect_finalization_ids.append(transaction_id)
				else:
					pending_other_recovery_ids.append(transaction_id)
			continue
		var effect_receipt: Dictionary = result.get("effect_receipt", {}) if result.get("effect_receipt", {}) is Dictionary else {}
		if not effect_receipt.is_empty():
			var finalization: Dictionary = result.get("effect_finalization", {}) if result.get("effect_finalization", {}) is Dictionary else {}
			if not bool(finalization.get("finalized", false)):
				pending_effect_finalization_ids.append(transaction_id)
				continue
		var region_supply_receipt: Dictionary = result.get("region_supply_receipt", {}) \
			if result.get("region_supply_receipt", {}) is Dictionary else {}
		if not region_supply_receipt.is_empty():
			var region_supply_finalization: Dictionary = result.get(
				"region_supply_finalization",
				{}
			) if result.get("region_supply_finalization", {}) is Dictionary else {}
			if not bool(region_supply_finalization.get("finalized", false)):
				pending_region_supply_finalization_ids.append(transaction_id)
	var pending_finalization_ids: Array = []
	for pending_id in (
		pending_effect_finalization_ids
		+ pending_region_supply_finalization_ids
		+ pending_other_recovery_ids
	):
		if not pending_finalization_ids.has(pending_id):
			pending_finalization_ids.append(pending_id)
	var reason_code := "commodity_card_inventory_checkpoint_ready"
	if not pending_finalization_ids.is_empty():
		if not pending_region_supply_finalization_ids.is_empty() \
				and pending_effect_finalization_ids.is_empty() \
				and pending_other_recovery_ids.is_empty():
			reason_code = "region_supply_purchase_finalization_pending"
		elif not pending_effect_finalization_ids.is_empty() \
				and pending_region_supply_finalization_ids.is_empty() \
				and pending_other_recovery_ids.is_empty():
			reason_code = "core_card_effect_finalization_pending"
		else:
			reason_code = "card_flow_multiple_finalizations_pending"
	return {
		"can_checkpoint": pending_finalization_ids.is_empty(),
		"reason_code": reason_code,
		"pending_finalization_count": pending_finalization_ids.size(),
		"pending_finalization_transaction_ids": pending_finalization_ids,
		"pending_effect_finalization_transaction_ids": pending_effect_finalization_ids,
		"pending_region_supply_finalization_transaction_ids": pending_region_supply_finalization_ids,
		"pending_other_recovery_transaction_ids": pending_other_recovery_ids,
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


func _retry_terminal_region_supply_finalization(previous_result: Dictionary) -> Dictionary:
	if not bool(previous_result.get("committed", false)):
		return previous_result
	var prior_finalization: Dictionary = previous_result.get(
		"region_supply_finalization",
		{}
	) if previous_result.get("region_supply_finalization", {}) is Dictionary else {}
	if bool(prior_finalization.get("finalized", false)):
		return previous_result
	var source_receipt: Dictionary = previous_result.get(
		"region_supply_receipt",
		{}
	) if previous_result.get("region_supply_receipt", {}) is Dictionary else {}
	if source_receipt.is_empty() or not _region_supply_source_api_ready():
		return previous_result
	var transaction_id := str(previous_result.get("transaction_id", ""))
	var value_variant: Variant = _region_supply_source_port.call(
		"finalize_slot_refill",
		transaction_id
	)
	var owner_result: Dictionary = (value_variant as Dictionary).duplicate(true) \
		if value_variant is Dictionary else {}
	var finalized := bool(owner_result.get("finalized", false))
	var next_result := previous_result.duplicate(true)
	next_result["region_supply_finalization"] = {
		"supported": true,
		"finalized": finalized,
		"finalization_failed": not finalized,
		"reason_code": "region_supply_finalized" if finalized else str(owner_result.get(
			"reason_code",
			"region_supply_finalize_failed"
		)),
		"owner_result": owner_result,
	}
	if finalized:
		next_result.erase("recovery_required")
		next_result["reason_code"] = "committed"
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


func _attach_region_supply_source_port() -> void:
	if _transaction_service == null \
			or not _transaction_service.has_method("set_region_supply_source_port"):
		return
	_transaction_service.call(
		"set_region_supply_source_port",
		_region_supply_source_port
	)


func _region_supply_source_api_ready() -> bool:
	if _region_supply_source_port == null:
		return false
	for method_name in [
		"public_rack_snapshot",
		"prepare_slot_refill",
		"commit_slot_refill",
		"rollback_slot_refill",
		"finalize_slot_refill",
	]:
		if not _region_supply_source_port.has_method(method_name):
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


func _preflight_terminal_operations(data: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	var transaction_ids: Array = data.keys()
	transaction_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for transaction_id_variant in transaction_ids:
		if not (transaction_id_variant is String or transaction_id_variant is StringName):
			return {"accepted": false, "reason_code": "terminal_operation_transaction_id_invalid", "failing_child": "terminal_operations"}
		var transaction_id := str(transaction_id_variant).strip_edges()
		var record_variant: Variant = data.get(transaction_id_variant)
		if transaction_id.is_empty() or not (record_variant is Dictionary):
			return {"accepted": false, "reason_code": "terminal_operation_invalid", "failing_child": "terminal_operations"}
		var record := record_variant as Dictionary
		if not _has_exact_keys(record, JOURNAL_RECORD_FIELDS) or not (record.get("intent_hash") is String) \
				or str(record.get("intent_hash", "")).is_empty() or not (record.get("result") is Dictionary) \
				or not _is_pure_data(record) or _contains_forbidden_journal_state(record.get("result", {})):
			return {"accepted": false, "reason_code": "terminal_operation_invalid", "failing_child": "terminal_operations"}
		normalized[transaction_id] = record.duplicate(true)
	return {"accepted": true, "reason_code": "terminal_operations_valid", "normalized_state": normalized}


func _apply_restore_failure(
	failing_child: String,
	reason_code: String,
	checkpoint: Dictionary,
	rollback_needed: bool
) -> Dictionary:
	var rollback := {"applied": true, "failures": []}
	if rollback_needed:
		rollback = restore_runtime_checkpoint(checkpoint)
	return {
		"applied": false,
		"reason_code": reason_code,
		"reason": reason_code,
		"failing_child": failing_child,
		"rollback_attempted": rollback_needed,
		"rollback_complete": bool(rollback.get("applied", false)),
		"rollback_failures": (rollback.get("failures", []) as Array).duplicate(),
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
	if value is float:
		return is_finite(value)
	if value == null or value is bool or value is int or value is String or value is StringName:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName) or not _is_pure_data((value as Dictionary).get(key_variant)):
				return false
		return true
	return false


func _has_exact_keys(dictionary: Dictionary, fields: Array) -> bool:
	if dictionary.size() != fields.size():
		return false
	for field_variant in fields:
		if not dictionary.has(str(field_variant)):
			return false
	return true


func _journal_save_snapshot(source: Dictionary) -> Dictionary:
	var sanitized: Variant = _sanitize_journal_value(source)
	return sanitized as Dictionary if sanitized is Dictionary else {}


func _sanitize_journal_value(value: Variant) -> Variant:
	if value is Dictionary:
		var sanitized: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key in FORBIDDEN_JOURNAL_STATE_FIELDS:
				continue
			sanitized[key] = _sanitize_journal_value((value as Dictionary).get(key_variant))
		return sanitized
	if value is Array:
		var sanitized_array: Array = []
		for item_variant in value as Array:
			sanitized_array.append(_sanitize_journal_value(item_variant))
		return sanitized_array
	return value


func _contains_forbidden_journal_state(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) in FORBIDDEN_JOURNAL_STATE_FIELDS \
					or _contains_forbidden_journal_state((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_journal_state(item_variant):
				return true
	return false
