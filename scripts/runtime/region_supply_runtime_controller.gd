@tool
extends Node
class_name RegionSupplyRuntimeController

signal rack_changed(region_id: String, slot_index: int, snapshot: Dictionary)

const StrictState := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")

const STATE_VERSION := 1
const DEFAULT_SLOT_COUNT := 4
const MAX_SLOT_COUNT := 12
const MAX_WEIGHT := 1000
const PUBLIC_CARD_FIELDS := [
	"card_id",
	"family_id",
	"card_type",
	"rank",
	"name",
	"display_name",
	"price_cash",
	"target_type",
	"effect_text",
	"requirement_text",
	"facility_kind",
	"industry_id",
	"route_tags",
	"art_key",
]
const SAVE_KEYS := [
	"state_version",
	"configured",
	"gameplay_seed",
	"state_revision",
	"refill_sequence",
	"regions_by_id",
	"region_order",
	"cards_by_id",
	"card_order",
	"racks_by_region",
	"slot_revisions_by_region",
	"bags_by_region",
	"rng_state_by_region",
	"claimed_unique_keys",
	"pending_transactions",
	"terminal_transactions",
]
const REGION_SAVE_KEYS := ["region_id", "region_index", "display_name", "terrain", "mode_tags"]
const CARD_SAVE_KEYS := [
	"card_id",
	"family_id",
	"card_type",
	"region_supply_weight",
	"global_unique",
	"unique_key",
	"legal_region_ids",
	"disabled_region_ids",
	"allowed_terrain",
	"required_mode_tags",
	"public_card",
]
const LISTING_SAVE_KEYS := [
	"item_id",
	"card_id",
	"card",
	"source_region_id",
	"source_district_index",
	"slot_index",
	"price_cash",
	"supply_revision",
]
const PENDING_TRANSACTION_SAVE_KEYS := [
	"transaction_id",
	"intent_fingerprint",
	"stage",
	"region_id",
	"slot_index",
	"expected_state_revision",
	"expected_item_id",
	"expected_supply_revision",
	"pre_listing",
	"pre_bag",
	"pre_rng_state",
	"pre_claimed_unique_keys",
	"pre_slot_revision",
	"pre_refill_sequence",
	"post_listing",
	"post_bag",
	"post_rng_state",
	"post_claimed_unique_keys",
	"post_slot_revision",
	"post_refill_sequence",
]
const TERMINAL_TRANSACTION_SAVE_KEYS := [
	"ok",
	"prepared",
	"committed",
	"rolled_back",
	"finalized",
	"stage",
	"reason_code",
	"transaction_id",
	"intent_fingerprint",
	"region_id",
	"slot_index",
	"source_item_id",
	"next_listing",
	"state_revision",
	"replayed",
]

@export_range(1, MAX_SLOT_COUNT, 1) var default_slots_per_region := DEFAULT_SLOT_COUNT

var _configured := false
var _gameplay_seed := 0
var _state_revision := 0
var _refill_sequence := 0
var _regions_by_id: Dictionary = {}
var _region_order: Array[String] = []
var _cards_by_id: Dictionary = {}
var _card_order: Array[String] = []
var _racks_by_region: Dictionary = {}
var _slot_revisions_by_region: Dictionary = {}
var _bags_by_region: Dictionary = {}
var _rng_state_by_region: Dictionary = {}
var _claimed_unique_keys: Dictionary = {}
var _pending_transactions: Dictionary = {}
var _terminal_transactions: Dictionary = {}


func configure(
	gameplay_seed: int,
	region_descriptors: Array,
	legal_card_descriptors: Array,
	slots_per_region := DEFAULT_SLOT_COUNT
) -> Dictionary:
	var preflight := preflight_new_session_configuration(region_descriptors, legal_card_descriptors, slots_per_region)
	if not bool(preflight.get("accepted", false)):
		return _result(false, str(preflight.get("reason_code", "region_supply_configuration_invalid")))
	var normalized_regions: Dictionary = preflight.get("normalized_regions", {})
	var normalized_cards: Dictionary = preflight.get("normalized_cards", {})
	var normalized_slot_count := int(preflight.get("slot_count", DEFAULT_SLOT_COUNT))

	_gameplay_seed = gameplay_seed
	_state_revision = 0
	_refill_sequence = 0
	_regions_by_id = normalized_regions.by_id
	_region_order = normalized_regions.order
	_cards_by_id = normalized_cards.by_id
	_card_order = normalized_cards.order
	_racks_by_region.clear()
	_slot_revisions_by_region.clear()
	_bags_by_region.clear()
	_rng_state_by_region.clear()
	_claimed_unique_keys.clear()
	_pending_transactions.clear()
	_terminal_transactions.clear()

	for region_id in _region_order:
		_rng_state_by_region[region_id] = _initial_region_rng_state(gameplay_seed, region_id)
		_bags_by_region[region_id] = []
		var rack: Array = []
		var slot_revisions: Array = []
		for slot_index in range(normalized_slot_count):
			slot_revisions.append(0)
			var draw := _draw_from_region_state(
				region_id,
				(_bags_by_region.get(region_id, []) as Array).duplicate(),
				int(_rng_state_by_region.get(region_id, 1)),
				_claimed_unique_keys.duplicate(true)
			)
			_bags_by_region[region_id] = (draw.get("bag", []) as Array).duplicate()
			_rng_state_by_region[region_id] = int(draw.get("rng_state", 1))
			_claimed_unique_keys = (draw.get("claimed_unique_keys", {}) as Dictionary).duplicate(true)
			var drawn_card_id := str(draw.get("card_id", ""))
			var listing_sequence := _refill_sequence
			if not drawn_card_id.is_empty():
				listing_sequence += 1
				_refill_sequence = listing_sequence
			rack.append(_listing_for_card(region_id, slot_index, drawn_card_id, 0, listing_sequence))
		_racks_by_region[region_id] = rack
		_slot_revisions_by_region[region_id] = slot_revisions

	_configured = true
	_state_revision = 1
	return {
		"configured": true,
		"reason_code": "region_supply_configured",
		"region_count": _region_order.size(),
		"legal_card_count": _card_order.size(),
		"slots_per_region": normalized_slot_count,
		"state_revision": _state_revision,
	}


func preflight_new_session_configuration(region_descriptors: Array, legal_card_descriptors: Array, slots_per_region := DEFAULT_SLOT_COUNT) -> Dictionary:
	var normalized_regions := _normalize_regions(region_descriptors)
	var normalized_cards := _normalize_cards(legal_card_descriptors)
	if normalized_regions.is_empty():
		return {"accepted": false, "reason_code": "region_supply_regions_missing"}
	if normalized_cards.is_empty():
		return {"accepted": false, "reason_code": "region_supply_cards_missing"}
	var slot_count := int(slots_per_region)
	if slot_count < 1 or slot_count > MAX_SLOT_COUNT:
		return {"accepted": false, "reason_code": "region_supply_slot_count_invalid"}
	return {
		"accepted": true,
		"reason_code": "region_supply_configuration_valid",
		"normalized_regions": normalized_regions,
		"normalized_cards": normalized_cards,
		"slot_count": slot_count,
	}


func public_rack_snapshot(region_id := "") -> Dictionary:
	if not _configured:
		return {
			"available": false,
			"reason_code": "region_supply_unconfigured",
			"state_revision": _state_revision,
			"regions": [],
		}
	var requested_region := region_id.strip_edges()
	var rows: Array = []
	for current_region_id in _region_order:
		if not requested_region.is_empty() and current_region_id != requested_region:
			continue
		var region: Dictionary = _regions_by_id.get(current_region_id, {})
		rows.append({
			"region_id": current_region_id,
			"region_index": int(region.get("region_index", -1)),
			"display_name": str(region.get("display_name", current_region_id)),
			"rack_revision": _region_public_revision(current_region_id),
			"slots": _public_slots(current_region_id),
		})
	return {
		"available": requested_region.is_empty() or _regions_by_id.has(requested_region),
		"reason_code": "region_supply_public_snapshot",
		"state_revision": _state_revision,
		"regions": rows,
	}


func prepare_slot_refill(
	region_id: String,
	slot_index: int,
	expected_item_id: String,
	expected_supply_revision: String,
	transaction_id: String
) -> Dictionary:
	var tx := transaction_id.strip_edges()
	var normalized_region_id := region_id.strip_edges()
	if tx.is_empty():
		return _result(false, "region_supply_transaction_id_missing")
	if _terminal_transactions.has(tx):
		var replay: Dictionary = (_terminal_transactions.get(tx, {}) as Dictionary).duplicate(true)
		replay["replayed"] = true
		return replay
	if _pending_transactions.has(tx):
		var pending_replay: Dictionary = (_pending_transactions.get(tx, {}) as Dictionary).duplicate(true)
		if str(pending_replay.get("intent_fingerprint", "")) != _intent_fingerprint(
			normalized_region_id,
			slot_index,
			expected_item_id,
			expected_supply_revision
		):
			return _result(false, "region_supply_transaction_collision")
		return _stage_receipt(pending_replay, true)
	if not _configured or not _regions_by_id.has(normalized_region_id):
		return _result(false, "region_supply_region_missing")
	var rack: Array = _racks_by_region.get(normalized_region_id, [])
	if slot_index < 0 or slot_index >= rack.size():
		return _result(false, "region_supply_slot_invalid")
	var current_listing: Dictionary = rack[slot_index] if rack[slot_index] is Dictionary else {}
	if current_listing.is_empty():
		return _result(false, "region_supply_slot_empty")
	if str(current_listing.get("item_id", "")) != expected_item_id.strip_edges() \
			or str(current_listing.get("supply_revision", "")) != expected_supply_revision.strip_edges():
		return _result(false, "region_supply_listing_changed")

	var pre_bag: Array = (_bags_by_region.get(normalized_region_id, []) as Array).duplicate()
	var pre_rng_state := int(_rng_state_by_region.get(normalized_region_id, 1))
	var pre_claimed := _claimed_unique_keys.duplicate(true)
	var draw := _draw_from_region_state(
		normalized_region_id,
		pre_bag.duplicate(),
		pre_rng_state,
		pre_claimed.duplicate(true)
	)
	var slot_revisions: Array = _slot_revisions_by_region.get(normalized_region_id, [])
	var next_slot_revision := int(slot_revisions[slot_index]) + 1
	var next_refill_sequence := _refill_sequence
	var drawn_card_id := str(draw.get("card_id", ""))
	if not drawn_card_id.is_empty():
		next_refill_sequence += 1
	var next_listing := _listing_for_card(
		normalized_region_id,
		slot_index,
		drawn_card_id,
		next_slot_revision,
		next_refill_sequence
	)
	var intent_fingerprint := _intent_fingerprint(
		normalized_region_id,
		slot_index,
		expected_item_id,
		expected_supply_revision
	)
	var pending := {
		"transaction_id": tx,
		"intent_fingerprint": intent_fingerprint,
		"stage": "prepared",
		"region_id": normalized_region_id,
		"slot_index": slot_index,
		"expected_state_revision": _state_revision,
		"expected_item_id": expected_item_id.strip_edges(),
		"expected_supply_revision": expected_supply_revision.strip_edges(),
		"pre_listing": current_listing.duplicate(true),
		"pre_bag": pre_bag,
		"pre_rng_state": pre_rng_state,
		"pre_claimed_unique_keys": pre_claimed,
		"pre_slot_revision": int(slot_revisions[slot_index]),
		"pre_refill_sequence": _refill_sequence,
		"post_listing": next_listing,
		"post_bag": (draw.get("bag", []) as Array).duplicate(),
		"post_rng_state": int(draw.get("rng_state", pre_rng_state)),
		"post_claimed_unique_keys": (draw.get("claimed_unique_keys", {}) as Dictionary).duplicate(true),
		"post_slot_revision": next_slot_revision,
		"post_refill_sequence": next_refill_sequence,
	}
	_pending_transactions[tx] = pending
	return _stage_receipt(pending, false)


func commit_slot_refill(transaction_id: String) -> Dictionary:
	var tx := transaction_id.strip_edges()
	if _terminal_transactions.has(tx):
		var replay: Dictionary = (_terminal_transactions.get(tx, {}) as Dictionary).duplicate(true)
		replay["replayed"] = true
		return replay
	if not _pending_transactions.has(tx):
		return _result(false, "region_supply_transaction_missing")
	var pending: Dictionary = (_pending_transactions.get(tx, {}) as Dictionary).duplicate(true)
	if str(pending.get("stage", "")) == "committed":
		return _stage_receipt(pending, true)
	if str(pending.get("stage", "")) != "prepared":
		return _result(false, "region_supply_transaction_stage_invalid")
	var region_id := str(pending.get("region_id", ""))
	var slot_index := int(pending.get("slot_index", -1))
	var rack: Array = _racks_by_region.get(region_id, [])
	var slot_revisions: Array = _slot_revisions_by_region.get(region_id, [])
	if int(pending.get("expected_state_revision", -1)) != _state_revision \
			or slot_index < 0 or slot_index >= rack.size() \
			or slot_index >= slot_revisions.size() \
			or int(slot_revisions[slot_index]) != int(pending.get("pre_slot_revision", -1)) \
			or not _same_data(rack[slot_index], pending.get("pre_listing", {})) \
			or not _same_data(_bags_by_region.get(region_id, []), pending.get("pre_bag", [])) \
			or int(_rng_state_by_region.get(region_id, 0)) != int(pending.get("pre_rng_state", -1)) \
			or _refill_sequence != int(pending.get("pre_refill_sequence", -1)) \
			or not _same_data(_claimed_unique_keys, pending.get("pre_claimed_unique_keys", {})):
		return _result(false, "region_supply_preimage_changed")

	rack[slot_index] = (pending.get("post_listing", {}) as Dictionary).duplicate(true)
	slot_revisions[slot_index] = int(pending.get("post_slot_revision", 0))
	_racks_by_region[region_id] = rack
	_slot_revisions_by_region[region_id] = slot_revisions
	_bags_by_region[region_id] = (pending.get("post_bag", []) as Array).duplicate()
	_rng_state_by_region[region_id] = int(pending.get("post_rng_state", 1))
	_claimed_unique_keys = (pending.get("post_claimed_unique_keys", {}) as Dictionary).duplicate(true)
	_refill_sequence = int(pending.get("post_refill_sequence", _refill_sequence))
	_state_revision += 1
	pending["stage"] = "committed"
	pending["committed_state_revision"] = _state_revision
	_pending_transactions[tx] = pending
	var snapshot := public_rack_snapshot(region_id)
	rack_changed.emit(region_id, slot_index, snapshot)
	return _stage_receipt(pending, false)


func rollback_slot_refill(transaction_id: String) -> Dictionary:
	var tx := transaction_id.strip_edges()
	if _terminal_transactions.has(tx):
		var replay: Dictionary = (_terminal_transactions.get(tx, {}) as Dictionary).duplicate(true)
		replay["replayed"] = true
		return replay
	if not _pending_transactions.has(tx):
		return _result(false, "region_supply_transaction_missing")
	var pending: Dictionary = (_pending_transactions.get(tx, {}) as Dictionary).duplicate(true)
	var stage := str(pending.get("stage", ""))
	if stage == "rolled_back":
		return _stage_receipt(pending, true)
	if stage == "committed":
		var region_id := str(pending.get("region_id", ""))
		var slot_index := int(pending.get("slot_index", -1))
		var rack: Array = _racks_by_region.get(region_id, [])
		var slot_revisions: Array = _slot_revisions_by_region.get(region_id, [])
		if slot_index < 0 or slot_index >= rack.size() or slot_index >= slot_revisions.size():
			return _result(false, "region_supply_rollback_target_invalid")
		if not _same_data(rack[slot_index], pending.get("post_listing", {})) \
				or not _same_data(_bags_by_region.get(region_id, []), pending.get("post_bag", [])) \
				or int(_rng_state_by_region.get(region_id, 0)) != int(pending.get("post_rng_state", -1)) \
				or _refill_sequence != int(pending.get("post_refill_sequence", -1)):
			return _result(false, "region_supply_rollback_postimage_changed")
		rack[slot_index] = (pending.get("pre_listing", {}) as Dictionary).duplicate(true)
		slot_revisions[slot_index] = int(pending.get("pre_slot_revision", 0))
		_racks_by_region[region_id] = rack
		_slot_revisions_by_region[region_id] = slot_revisions
		_bags_by_region[region_id] = (pending.get("pre_bag", []) as Array).duplicate()
		_rng_state_by_region[region_id] = int(pending.get("pre_rng_state", 1))
		_claimed_unique_keys = (pending.get("pre_claimed_unique_keys", {}) as Dictionary).duplicate(true)
		_refill_sequence = int(pending.get("pre_refill_sequence", _refill_sequence))
		_state_revision = int(pending.get("expected_state_revision", _state_revision))
	pending["stage"] = "rolled_back"
	pending["rolled_back_state_revision"] = _state_revision
	var terminal := _stage_receipt(pending, false)
	_terminal_transactions[tx] = terminal.duplicate(true)
	_pending_transactions.erase(tx)
	return terminal


func finalize_slot_refill(transaction_id: String) -> Dictionary:
	var tx := transaction_id.strip_edges()
	if _terminal_transactions.has(tx):
		var replay: Dictionary = (_terminal_transactions.get(tx, {}) as Dictionary).duplicate(true)
		replay["replayed"] = true
		return replay
	if not _pending_transactions.has(tx):
		return _result(false, "region_supply_transaction_missing")
	var pending: Dictionary = (_pending_transactions.get(tx, {}) as Dictionary).duplicate(true)
	if str(pending.get("stage", "")) != "committed":
		return _result(false, "region_supply_finalize_requires_commit")
	pending["stage"] = "finalized"
	var terminal := _stage_receipt(pending, false)
	_terminal_transactions[tx] = terminal.duplicate(true)
	_pending_transactions.erase(tx)
	return terminal


func to_save_data() -> Dictionary:
	return {
		"state_version": STATE_VERSION,
		"configured": _configured,
		"gameplay_seed": _gameplay_seed,
		"state_revision": _state_revision,
		"refill_sequence": _refill_sequence,
		"regions_by_id": _regions_by_id.duplicate(true),
		"region_order": _region_order.duplicate(),
		"cards_by_id": _cards_by_id.duplicate(true),
		"card_order": _card_order.duplicate(),
		"racks_by_region": _racks_by_region.duplicate(true),
		"slot_revisions_by_region": _slot_revisions_by_region.duplicate(true),
		"bags_by_region": _bags_by_region.duplicate(true),
		"rng_state_by_region": _rng_state_by_region.duplicate(true),
		"claimed_unique_keys": _claimed_unique_keys.duplicate(true),
		"pending_transactions": _pending_transactions.duplicate(true),
		"terminal_transactions": _terminal_transactions.duplicate(true),
	}


func preflight_save_data(data: Dictionary) -> Dictionary:
	var validation := _validate_save_data(data)
	if not bool(validation.get("valid", false)):
		var reason_code := str(validation.get("reason_code", "region_supply_save_invalid"))
		return {"accepted": false, "reason": reason_code, "reason_code": reason_code}
	return {
		"accepted": true,
		"reason": "",
		"reason_code": "region_supply_save_valid",
		"normalized_state": data.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		var rejection := str(preflight.get("reason_code", "region_supply_save_invalid"))
		return {"applied": false, "reason": rejection, "reason_code": rejection}
	var normalized := (preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
	_configured = bool(normalized.get("configured"))
	_gameplay_seed = int(normalized.get("gameplay_seed"))
	_state_revision = int(normalized.get("state_revision"))
	_refill_sequence = int(normalized.get("refill_sequence"))
	_regions_by_id = (normalized.get("regions_by_id") as Dictionary).duplicate(true)
	_region_order = _string_array(normalized.get("region_order"))
	_cards_by_id = (normalized.get("cards_by_id") as Dictionary).duplicate(true)
	_card_order = _string_array(normalized.get("card_order"))
	_racks_by_region = (normalized.get("racks_by_region") as Dictionary).duplicate(true)
	_slot_revisions_by_region = (normalized.get("slot_revisions_by_region") as Dictionary).duplicate(true)
	_bags_by_region = (normalized.get("bags_by_region") as Dictionary).duplicate(true)
	_rng_state_by_region = (normalized.get("rng_state_by_region") as Dictionary).duplicate(true)
	_claimed_unique_keys = (normalized.get("claimed_unique_keys") as Dictionary).duplicate(true)
	_pending_transactions = (normalized.get("pending_transactions") as Dictionary).duplicate(true)
	_terminal_transactions = (normalized.get("terminal_transactions") as Dictionary).duplicate(true)
	return {
		"applied": true,
		"reason": "region_supply_save_applied",
		"reason_code": "region_supply_save_applied",
		"state_revision": _state_revision,
	}


func debug_snapshot() -> Dictionary:
	var bag_counts: Dictionary = {}
	for region_id in _region_order:
		bag_counts[region_id] = (_bags_by_region.get(region_id, []) as Array).size()
	return {
		"component": "RegionSupplyRuntimeController",
		"runtime_owner": "RegionSupplyRuntimeController",
		"sceneized": scene_file_path == "res://scenes/runtime/RegionSupplyRuntimeController.tscn",
		"configured": _configured,
		"state_revision": _state_revision,
		"region_count": _region_order.size(),
		"legal_card_count": _card_order.size(),
		"bag_counts": bag_counts,
		"pending_transaction_count": _pending_transactions.size(),
		"terminal_transaction_count": _terminal_transactions.size(),
		"owns_region_racks": true,
		"owns_deterministic_supply_bags": true,
		"owns_cash": false,
		"owns_player_inventory": false,
		"owns_quotes": false,
		"public_snapshot_exposes_future_bag": false,
	}


func _normalize_regions(value: Array) -> Dictionary:
	var by_id: Dictionary = {}
	var order: Array[String] = []
	for row_variant in value:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		var region_id := str(row.get("region_id", "")).strip_edges()
		if region_id.is_empty() or by_id.has(region_id):
			continue
		if not bool(row.get("active", true)) or bool(row.get("destroyed", false)):
			continue
		by_id[region_id] = {
			"region_id": region_id,
			"region_index": int(row.get("region_index", -1)),
			"display_name": str(row.get("display_name", row.get("name", region_id))),
			"terrain": str(row.get("terrain", "")),
			"mode_tags": _string_array(row.get("mode_tags", [])),
		}
		order.append(region_id)
	order.sort()
	return {"by_id": by_id, "order": order}


func _normalize_cards(value: Array) -> Dictionary:
	var by_id: Dictionary = {}
	var order: Array[String] = []
	for row_variant in value:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		var card_id := str(row.get("card_id", row.get("id", ""))).strip_edges()
		if card_id.is_empty() or by_id.has(card_id):
			continue
		if not bool(row.get("enabled", true)) \
				or bool(row.get("retired", false)) \
				or not bool(row.get("valid", true)) \
				or not bool(row.get("potential_target_exists", true)) \
				or bool(row.get("is_commodity", false)) \
				or str(row.get("card_type", "")).to_lower() == "commodity" \
				or not _rank_is_one(row.get("rank", row.get("card_rank", "I"))):
			continue
		var public_card: Dictionary = {}
		for field in PUBLIC_CARD_FIELDS:
			if row.has(field):
				public_card[field] = _public_value(row.get(field))
		public_card["card_id"] = card_id
		if not public_card.has("rank"):
			public_card["rank"] = "I"
		var normalized := {
			"card_id": card_id,
			"family_id": str(row.get("family_id", card_id)),
			"card_type": str(row.get("card_type", "ordinary")),
			"region_supply_weight": clampi(int(row.get("region_supply_weight", 1)), 1, MAX_WEIGHT),
			"global_unique": bool(row.get("global_unique", false)),
			"unique_key": str(row.get("unique_key", row.get("family_id", card_id))),
			"legal_region_ids": _string_array(row.get("legal_region_ids", [])),
			"disabled_region_ids": _string_array(row.get("disabled_region_ids", [])),
			"allowed_terrain": _string_array(row.get("allowed_terrain", [])),
			"required_mode_tags": _string_array(row.get("required_mode_tags", [])),
			"public_card": public_card,
		}
		by_id[card_id] = normalized
		order.append(card_id)
	order.sort()
	return {"by_id": by_id, "order": order}


func _draw_from_region_state(
	region_id: String,
	bag: Array,
	rng_state: int,
	claimed_unique_keys: Dictionary
) -> Dictionary:
	var working_bag := bag.duplicate()
	var working_rng_state := rng_state
	if working_bag.is_empty():
		var built := _build_region_bag(region_id, working_rng_state, claimed_unique_keys)
		working_bag = (built.get("bag", []) as Array).duplicate()
		working_rng_state = int(built.get("rng_state", working_rng_state))
	var selected_index := -1
	for index in range(working_bag.size()):
		var card_id := str(working_bag[index])
		if _card_legal_for_region(card_id, region_id, claimed_unique_keys):
			selected_index = index
			break
	if selected_index < 0:
		return {
			"card_id": "",
			"bag": working_bag,
			"rng_state": working_rng_state,
			"claimed_unique_keys": claimed_unique_keys.duplicate(true),
		}
	var selected_card_id := str(working_bag[selected_index])
	working_bag.remove_at(selected_index)
	var next_claimed := claimed_unique_keys.duplicate(true)
	var card: Dictionary = _cards_by_id.get(selected_card_id, {})
	if bool(card.get("global_unique", false)):
		next_claimed[str(card.get("unique_key", selected_card_id))] = true
	return {
		"card_id": selected_card_id,
		"bag": working_bag,
		"rng_state": working_rng_state,
		"claimed_unique_keys": next_claimed,
	}


func _build_region_bag(region_id: String, rng_state: int, claimed_unique_keys: Dictionary) -> Dictionary:
	var weighted_rows: Array[Dictionary] = []
	for card_id in _card_order:
		if not _card_legal_for_region(card_id, region_id, claimed_unique_keys):
			continue
		var card: Dictionary = _cards_by_id.get(card_id, {})
		weighted_rows.append({
			"item_id": card_id,
			"weight": maxi(1, int(card.get("region_supply_weight", 1))),
		})
	var draw := RunRngService.deterministic_weighted_shuffle(weighted_rows, rng_state)
	return {
		"bag": (draw.get("items", []) as Array).duplicate(),
		"rng_state": int(draw.get("rng_state", maxi(1, rng_state))),
	}


func _card_legal_for_region(card_id: String, region_id: String, claimed_unique_keys: Dictionary) -> bool:
	var card: Dictionary = _cards_by_id.get(card_id, {})
	var region: Dictionary = _regions_by_id.get(region_id, {})
	if card.is_empty() or region.is_empty():
		return false
	if bool(card.get("global_unique", false)) and claimed_unique_keys.has(str(card.get("unique_key", card_id))):
		return false
	var legal_region_ids: Array = card.get("legal_region_ids", [])
	if not legal_region_ids.is_empty() and not legal_region_ids.has(region_id):
		return false
	var disabled_region_ids: Array = card.get("disabled_region_ids", [])
	if disabled_region_ids.has(region_id):
		return false
	var allowed_terrain: Array = card.get("allowed_terrain", [])
	if not allowed_terrain.is_empty() and not allowed_terrain.has(str(region.get("terrain", ""))):
		return false
	var required_mode_tags: Array = card.get("required_mode_tags", [])
	var region_mode_tags: Array = region.get("mode_tags", [])
	for required_tag_variant in required_mode_tags:
		if not region_mode_tags.has(str(required_tag_variant)):
			return false
	return true


func _listing_for_card(
	region_id: String,
	slot_index: int,
	card_id: String,
	slot_revision: int,
	listing_sequence: int
) -> Dictionary:
	if card_id.is_empty() or not _cards_by_id.has(card_id):
		return {}
	var card: Dictionary = _cards_by_id.get(card_id, {})
	var public_card: Dictionary = (card.get("public_card", {}) as Dictionary).duplicate(true)
	var region: Dictionary = _regions_by_id.get(region_id, {})
	var item_id := "region-supply:%s:%d:%d:%s" % [region_id, slot_index, listing_sequence, card_id]
	return {
		"item_id": item_id,
		"card_id": card_id,
		"card": public_card,
		"source_region_id": region_id,
		"source_district_index": int(region.get("region_index", -1)),
		"slot_index": slot_index,
		"price_cash": int(public_card.get("price_cash", 0)),
		"supply_revision": _slot_supply_revision(region_id, slot_index, slot_revision),
	}


func _public_slots(region_id: String) -> Array:
	var result: Array = []
	for listing_variant in _racks_by_region.get(region_id, []) as Array:
		result.append((listing_variant as Dictionary).duplicate(true) if listing_variant is Dictionary else {})
	return result


func _region_public_revision(region_id: String) -> String:
	var revisions: Array = _slot_revisions_by_region.get(region_id, [])
	var text: Array[String] = []
	for value in revisions:
		text.append(str(int(value)))
	return "region:%s:%s" % [region_id, ",".join(text)]


func _slot_supply_revision(region_id: String, slot_index: int, slot_revision: int) -> String:
	return "region:%s:slot:%d:revision:%d" % [region_id, slot_index, slot_revision]


func _initial_region_rng_state(seed_value: int, region_id: String) -> int:
	var mixed := absi(seed_value) + 1
	for byte_value in region_id.to_utf8_buffer():
		mixed = int((mixed * 1103515245 + int(byte_value) + 12345) & 0x7fffffff)
	return maxi(1, mixed)


func _rank_is_one(value: Variant) -> bool:
	if value is int:
		return int(value) == 1
	var normalized := str(value).strip_edges().to_upper()
	return normalized in ["I", "1", "RANK_I", "RANK_1"]


func _intent_fingerprint(
	region_id: String,
	slot_index: int,
	item_id: String,
	supply_revision: String
) -> String:
	return "%s|%d|%s|%s" % [region_id, slot_index, item_id, supply_revision]


func _stage_receipt(pending: Dictionary, replayed: bool) -> Dictionary:
	var stage := str(pending.get("stage", ""))
	return {
		"ok": stage in ["prepared", "committed", "rolled_back", "finalized"],
		"prepared": stage == "prepared",
		"committed": stage in ["committed", "finalized"],
		"rolled_back": stage == "rolled_back",
		"finalized": stage == "finalized",
		"stage": stage,
		"reason_code": "region_supply_%s" % stage,
		"transaction_id": str(pending.get("transaction_id", "")),
		"intent_fingerprint": str(pending.get("intent_fingerprint", "")),
		"region_id": str(pending.get("region_id", "")),
		"slot_index": int(pending.get("slot_index", -1)),
		"source_item_id": str(pending.get("expected_item_id", "")),
		"next_listing": (pending.get("post_listing", {}) as Dictionary).duplicate(true),
		"state_revision": _state_revision,
		"replayed": replayed,
	}


func _validate_save_data(data: Dictionary) -> Dictionary:
	if not StrictState.is_codec_data(data):
		return {"valid": false, "reason_code": "region_supply_save_not_codec_data"}
	if not StrictState.has_exact_keys(data, SAVE_KEYS):
		return {"valid": false, "reason_code": "region_supply_save_shape_invalid"}
	if not (data.get("state_version") is int) or int(data.get("state_version")) != STATE_VERSION:
		return {"valid": false, "reason_code": "region_supply_save_header_invalid"}
	if not (data.get("configured") is bool) or not (data.get("gameplay_seed") is int) \
			or not (data.get("state_revision") is int) or int(data.get("state_revision")) < 0 \
			or not (data.get("refill_sequence") is int) or int(data.get("refill_sequence")) < 0:
		return {"valid": false, "reason_code": "region_supply_save_fields_invalid"}
	for array_key in ["region_order", "card_order"]:
		if not (data.get(array_key) is Array) or not _strict_string_array(data.get(array_key)):
			return {"valid": false, "reason_code": "region_supply_save_fields_invalid"}
	for dictionary_key in [
		"regions_by_id",
		"cards_by_id",
		"racks_by_region",
		"slot_revisions_by_region",
		"bags_by_region",
		"rng_state_by_region",
		"claimed_unique_keys",
		"pending_transactions",
		"terminal_transactions",
	]:
		if not (data.get(dictionary_key) is Dictionary):
			return {"valid": false, "reason_code": "region_supply_save_fields_invalid"}

	var region_order := data.get("region_order") as Array
	var card_order := data.get("card_order") as Array
	if not _string_array_is_sorted(region_order) or not _string_array_is_sorted(card_order):
		return {"valid": false, "reason_code": "region_supply_save_order_invalid"}
	if not bool(data.get("configured")):
		if int(data.get("state_revision")) != 0 or int(data.get("refill_sequence")) != 0 \
				or not region_order.is_empty() or not card_order.is_empty():
			return {"valid": false, "reason_code": "region_supply_unconfigured_state_invalid"}
		for dictionary_key in SAVE_KEYS.slice(5):
			if data.get(dictionary_key) is Dictionary and not (data.get(dictionary_key) as Dictionary).is_empty():
				return {"valid": false, "reason_code": "region_supply_unconfigured_state_invalid"}
		return {"valid": true, "reason_code": "region_supply_save_shape_valid"}
	if region_order.is_empty() or card_order.is_empty() or int(data.get("state_revision")) < 1:
		return {"valid": false, "reason_code": "region_supply_configured_state_invalid"}

	var regions := data.get("regions_by_id") as Dictionary
	var cards := data.get("cards_by_id") as Dictionary
	if not _dictionary_has_exact_ids(regions, region_order) or not _dictionary_has_exact_ids(cards, card_order):
		return {"valid": false, "reason_code": "region_supply_catalog_index_invalid"}
	for region_id_variant in region_order:
		var region_id := str(region_id_variant)
		var region_variant: Variant = regions.get(region_id)
		if not (region_variant is Dictionary):
			return {"valid": false, "reason_code": "region_supply_region_record_invalid"}
		var region := region_variant as Dictionary
		if not StrictState.has_exact_keys(region, REGION_SAVE_KEYS) \
				or not _strict_nonempty_string(region.get("region_id")) or str(region.get("region_id")) != region_id \
				or not (region.get("region_index") is int) \
				or not (region.get("display_name") is String) or not (region.get("terrain") is String) \
				or not _strict_string_array(region.get("mode_tags")):
			return {"valid": false, "reason_code": "region_supply_region_record_invalid"}
	for card_id_variant in card_order:
		var card_id := str(card_id_variant)
		var card_variant: Variant = cards.get(card_id)
		if not (card_variant is Dictionary) or not _card_record_valid(card_id, card_variant as Dictionary):
			return {"valid": false, "reason_code": "region_supply_card_record_invalid"}

	var racks := data.get("racks_by_region") as Dictionary
	var slot_revisions := data.get("slot_revisions_by_region") as Dictionary
	var bags := data.get("bags_by_region") as Dictionary
	var rng_states := data.get("rng_state_by_region") as Dictionary
	for region_map in [racks, slot_revisions, bags, rng_states]:
		if not _dictionary_has_exact_ids(region_map as Dictionary, region_order):
			return {"valid": false, "reason_code": "region_supply_region_state_index_invalid"}
	for region_id_variant in region_order:
		var region_id := str(region_id_variant)
		var rack_variant: Variant = racks.get(region_id)
		var revisions_variant: Variant = slot_revisions.get(region_id)
		var bag_variant: Variant = bags.get(region_id)
		var rng_variant: Variant = rng_states.get(region_id)
		if not (rack_variant is Array) or not (revisions_variant is Array) or not (bag_variant is Array) \
				or not (rng_variant is int):
			return {"valid": false, "reason_code": "region_supply_region_state_type_invalid"}
		var rack := rack_variant as Array
		var revisions := revisions_variant as Array
		if rack.is_empty() or rack.size() > MAX_SLOT_COUNT or revisions.size() != rack.size() \
				or not _card_id_array_valid(bag_variant as Array, cards):
			return {"valid": false, "reason_code": "region_supply_region_state_content_invalid"}
		for slot_index in range(rack.size()):
			if not (revisions[slot_index] is int) or int(revisions[slot_index]) < 0 \
					or not (rack[slot_index] is Dictionary) \
					or not _listing_record_valid(
						rack[slot_index] as Dictionary,
						region_id,
						slot_index,
						int(revisions[slot_index]),
						regions,
						cards,
						int(data.get("refill_sequence"))
					):
				return {"valid": false, "reason_code": "region_supply_rack_listing_invalid"}
	if not _claimed_unique_map_valid(data.get("claimed_unique_keys") as Dictionary, cards):
		return {"valid": false, "reason_code": "region_supply_claimed_unique_invalid"}
	if not _transaction_journals_valid(data, regions, cards):
		return {"valid": false, "reason_code": "region_supply_transaction_journal_invalid"}
	return {"valid": true, "reason_code": "region_supply_save_shape_valid"}


func _card_record_valid(card_id: String, card: Dictionary) -> bool:
	if not StrictState.has_exact_keys(card, CARD_SAVE_KEYS) \
			or not _strict_nonempty_string(card.get("card_id")) or str(card.get("card_id")) != card_id:
		return false
	for string_key in ["family_id", "card_type", "unique_key"]:
		if not (card.get(string_key) is String):
			return false
	if not (card.get("region_supply_weight") is int) \
			or int(card.get("region_supply_weight")) < 1 or int(card.get("region_supply_weight")) > MAX_WEIGHT \
			or not (card.get("global_unique") is bool):
		return false
	for array_key in ["legal_region_ids", "disabled_region_ids", "allowed_terrain", "required_mode_tags"]:
		if not _strict_string_array(card.get(array_key)):
			return false
	var public_variant: Variant = card.get("public_card")
	if not (public_variant is Dictionary):
		return false
	var public_card := public_variant as Dictionary
	for key_variant in public_card.keys():
		if not (key_variant is String) or not PUBLIC_CARD_FIELDS.has(str(key_variant)):
			return false
	if not _strict_nonempty_string(public_card.get("card_id")) or str(public_card.get("card_id")) != card_id \
			or not public_card.has("rank") or not ((public_card.get("rank") is String) or (public_card.get("rank") is int)) \
			or not _rank_is_one(public_card.get("rank")):
		return false
	return true


func _listing_record_valid(
	listing: Dictionary,
	region_id: String,
	slot_index: int,
	expected_slot_revision: int,
	regions: Dictionary,
	cards: Dictionary,
	maximum_listing_sequence: int
) -> bool:
	if listing.is_empty():
		return true
	if not StrictState.has_exact_keys(listing, LISTING_SAVE_KEYS):
		return false
	for string_key in ["item_id", "card_id", "source_region_id", "supply_revision"]:
		if not _strict_nonempty_string(listing.get(string_key)):
			return false
	var card_id := str(listing.get("card_id"))
	if not cards.has(card_id) or str(listing.get("source_region_id")) != region_id \
			or not (listing.get("source_district_index") is int) \
			or int(listing.get("source_district_index")) != int((regions.get(region_id) as Dictionary).get("region_index")) \
			or not (listing.get("slot_index") is int) or int(listing.get("slot_index")) != slot_index \
			or not (listing.get("price_cash") is int) or not (listing.get("card") is Dictionary):
		return false
	var card := cards.get(card_id) as Dictionary
	var public_card := card.get("public_card") as Dictionary
	if StrictState.fingerprint(listing.get("card")) != StrictState.fingerprint(public_card) \
			or int(listing.get("price_cash")) != int(public_card.get("price_cash", 0)):
		return false
	var revision_prefix := "region:%s:slot:%d:revision:" % [region_id, slot_index]
	var revision_text := str(listing.get("supply_revision"))
	if not revision_text.begins_with(revision_prefix):
		return false
	var revision_suffix := revision_text.substr(revision_prefix.length())
	if not revision_suffix.is_valid_int() or int(revision_suffix) < 0 \
			or (expected_slot_revision >= 0 and int(revision_suffix) != expected_slot_revision):
		return false
	var item_prefix := "region-supply:%s:%d:" % [region_id, slot_index]
	var item_suffix := ":%s" % card_id
	var item_id := str(listing.get("item_id"))
	if not item_id.begins_with(item_prefix) or not item_id.ends_with(item_suffix) \
			or item_id.length() <= item_prefix.length() + item_suffix.length():
		return false
	var sequence_text := item_id.substr(
		item_prefix.length(),
		item_id.length() - item_prefix.length() - item_suffix.length()
	)
	return sequence_text.is_valid_int() and int(sequence_text) > 0 and int(sequence_text) <= maximum_listing_sequence


func _transaction_journals_valid(data: Dictionary, regions: Dictionary, cards: Dictionary) -> bool:
	var pending := data.get("pending_transactions") as Dictionary
	var terminal := data.get("terminal_transactions") as Dictionary
	for transaction_id_variant in pending.keys():
		if not _strict_nonempty_string(transaction_id_variant) or terminal.has(transaction_id_variant) \
				or not (pending.get(transaction_id_variant) is Dictionary):
			return false
		var transaction_id := str(transaction_id_variant)
		var record := pending.get(transaction_id_variant) as Dictionary
		var stage_variant: Variant = record.get("stage")
		if not (stage_variant is String) or not ["prepared", "committed"].has(str(stage_variant)):
			return false
		var expected_keys := PENDING_TRANSACTION_SAVE_KEYS.duplicate()
		if str(stage_variant) == "committed":
			expected_keys.append("committed_state_revision")
		if not StrictState.has_exact_keys(record, expected_keys) \
				or not _strict_nonempty_string(record.get("transaction_id")) \
				or str(record.get("transaction_id")) != transaction_id:
			return false
		for string_key in ["intent_fingerprint", "region_id", "expected_item_id", "expected_supply_revision"]:
			if not _strict_nonempty_string(record.get(string_key)):
				return false
		var region_id := str(record.get("region_id"))
		if not regions.has(region_id) or not (record.get("slot_index") is int):
			return false
		var slot_index := int(record.get("slot_index"))
		var region_racks := (data.get("racks_by_region") as Dictionary).get(region_id) as Array
		if slot_index < 0 or slot_index >= region_racks.size():
			return false
		for int_key in [
			"expected_state_revision",
			"pre_rng_state",
			"pre_slot_revision",
			"pre_refill_sequence",
			"post_rng_state",
			"post_slot_revision",
			"post_refill_sequence",
		]:
			if not (record.get(int_key) is int) or int(record.get(int_key)) < 0:
				return false
		if int(record.get("expected_state_revision")) > int(data.get("state_revision")) \
				or int(record.get("post_slot_revision")) != int(record.get("pre_slot_revision")) + 1:
			return false
		if str(stage_variant) == "committed":
			if not (record.get("committed_state_revision") is int) \
					or int(record.get("committed_state_revision")) != int(record.get("expected_state_revision")) + 1 \
					or int(record.get("committed_state_revision")) > int(data.get("state_revision")):
				return false
		for listing_key in ["pre_listing", "post_listing"]:
			if not (record.get(listing_key) is Dictionary):
				return false
		var pre_listing := record.get("pre_listing") as Dictionary
		var post_listing := record.get("post_listing") as Dictionary
		if pre_listing.is_empty() \
				or not _listing_record_valid(pre_listing, region_id, slot_index, int(record.get("pre_slot_revision")), regions, cards, int(data.get("refill_sequence")) + 1) \
				or not _listing_record_valid(post_listing, region_id, slot_index, int(record.get("post_slot_revision")), regions, cards, int(data.get("refill_sequence")) + 1):
			return false
		if str(record.get("expected_item_id")) != str(pre_listing.get("item_id")) \
				or str(record.get("expected_supply_revision")) != str(pre_listing.get("supply_revision")) \
				or str(record.get("intent_fingerprint")) != _intent_fingerprint(
					region_id,
					slot_index,
					str(record.get("expected_item_id")),
					str(record.get("expected_supply_revision"))
				):
			return false
		if not (record.get("pre_bag") is Array) or not (record.get("post_bag") is Array) \
				or not _card_id_array_valid(record.get("pre_bag") as Array, cards) \
				or not _card_id_array_valid(record.get("post_bag") as Array, cards) \
				or not (record.get("pre_claimed_unique_keys") is Dictionary) \
				or not (record.get("post_claimed_unique_keys") is Dictionary) \
				or not _claimed_unique_map_valid(record.get("pre_claimed_unique_keys") as Dictionary, cards) \
				or not _claimed_unique_map_valid(record.get("post_claimed_unique_keys") as Dictionary, cards):
			return false
		var expected_refill_delta := 0 if post_listing.is_empty() else 1
		if int(record.get("post_refill_sequence")) != int(record.get("pre_refill_sequence")) + expected_refill_delta:
			return false

	for transaction_id_variant in terminal.keys():
		if not _strict_nonempty_string(transaction_id_variant) or not (terminal.get(transaction_id_variant) is Dictionary):
			return false
		var transaction_id := str(transaction_id_variant)
		var record := terminal.get(transaction_id_variant) as Dictionary
		if not StrictState.has_exact_keys(record, TERMINAL_TRANSACTION_SAVE_KEYS) \
				or not _strict_nonempty_string(record.get("transaction_id")) \
				or str(record.get("transaction_id")) != transaction_id:
			return false
		for bool_key in ["ok", "prepared", "committed", "rolled_back", "finalized", "replayed"]:
			if not (record.get(bool_key) is bool):
				return false
		for string_key in ["stage", "reason_code", "intent_fingerprint", "region_id", "source_item_id"]:
			if not _strict_nonempty_string(record.get(string_key)):
				return false
		var stage := str(record.get("stage"))
		if not ["rolled_back", "finalized"].has(stage) or not bool(record.get("ok")) \
				or bool(record.get("prepared")) or bool(record.get("replayed")) \
				or bool(record.get("rolled_back")) != (stage == "rolled_back") \
				or bool(record.get("finalized")) != (stage == "finalized") \
				or bool(record.get("committed")) != (stage == "finalized") \
				or str(record.get("reason_code")) != "region_supply_%s" % stage:
			return false
		var region_id := str(record.get("region_id"))
		if not regions.has(region_id) or not (record.get("slot_index") is int) \
				or not (record.get("state_revision") is int) or int(record.get("state_revision")) < 0 \
				or not (record.get("next_listing") is Dictionary):
			return false
		var slot_index := int(record.get("slot_index"))
		var region_racks := (data.get("racks_by_region") as Dictionary).get(region_id) as Array
		if slot_index < 0 or slot_index >= region_racks.size() \
				or not _terminal_intent_binding_valid(record, region_id, slot_index) \
				or not _listing_record_valid(record.get("next_listing") as Dictionary, region_id, slot_index, -1, regions, cards, int(data.get("refill_sequence")) + 1):
			return false
	return true


func _terminal_intent_binding_valid(record: Dictionary, region_id: String, slot_index: int) -> bool:
	var parts := str(record.get("intent_fingerprint")).split("|", true)
	if parts.size() != 4 or str(parts[0]) != region_id or not str(parts[1]).is_valid_int() \
			or int(parts[1]) != slot_index or str(parts[2]) != str(record.get("source_item_id")):
		return false
	var revision_prefix := "region:%s:slot:%d:revision:" % [region_id, slot_index]
	var revision := str(parts[3])
	return revision.begins_with(revision_prefix) \
		and revision.substr(revision_prefix.length()).is_valid_int() \
		and int(revision.substr(revision_prefix.length())) >= 0


func _claimed_unique_map_valid(claimed: Dictionary, cards: Dictionary) -> bool:
	var legal_keys: Dictionary = {}
	for card_variant in cards.values():
		var card := card_variant as Dictionary
		if bool(card.get("global_unique")):
			legal_keys[str(card.get("unique_key"))] = true
	for key_variant in claimed.keys():
		if not _strict_nonempty_string(key_variant) or not legal_keys.has(str(key_variant)) \
				or not (claimed.get(key_variant) is bool) or not bool(claimed.get(key_variant)):
			return false
	return true


func _card_id_array_valid(card_ids: Array, cards: Dictionary) -> bool:
	for card_id_variant in card_ids:
		if not _strict_nonempty_string(card_id_variant) or not cards.has(str(card_id_variant)):
			return false
	return true


func _dictionary_has_exact_ids(value: Dictionary, ids: Array) -> bool:
	if value.size() != ids.size():
		return false
	for key_variant in value.keys():
		if not _strict_nonempty_string(key_variant) or not ids.has(str(key_variant)):
			return false
	return true


func _strict_nonempty_string(value: Variant) -> bool:
	return value is String and not str(value).is_empty() and str(value) == str(value).strip_edges()


func _strict_string_array(value: Variant) -> bool:
	if not (value is Array):
		return false
	var seen: Dictionary = {}
	for item_variant in value as Array:
		if not _strict_nonempty_string(item_variant) or seen.has(str(item_variant)):
			return false
		seen[str(item_variant)] = true
	return true


func _string_array_is_sorted(value: Array) -> bool:
	for index in range(1, value.size()):
		if str(value[index - 1]) > str(value[index]):
			return false
	return true


func _same_data(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left, "", true) == JSON.stringify(right, "", true)


func _public_value(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item_variant in value:
		var item := str(item_variant).strip_edges()
		if not item.is_empty() and not result.has(item):
			result.append(item)
	return result

func _result(ok: bool, reason_code: String) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason_code,
		"state_revision": _state_revision,
	}
