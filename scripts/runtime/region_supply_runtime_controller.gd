@tool
extends Node
class_name RegionSupplyRuntimeController

signal rack_changed(region_id: String, slot_index: int, snapshot: Dictionary)

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
	"route_tags",
	"art_key",
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
	var normalized_regions := _normalize_regions(region_descriptors)
	var normalized_cards := _normalize_cards(legal_card_descriptors)
	var normalized_slot_count := clampi(int(slots_per_region), 1, MAX_SLOT_COUNT)
	if normalized_regions.is_empty():
		return _result(false, "region_supply_regions_missing")
	if normalized_cards.is_empty():
		return _result(false, "region_supply_cards_missing")

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


func apply_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("state_version", 0)) != STATE_VERSION or not _is_pure_data(data):
		return {"applied": false, "reason_code": "region_supply_save_invalid"}
	var prepared_region_order := _string_array(data.get("region_order", []))
	var prepared_card_order := _string_array(data.get("card_order", []))
	var prepared_regions := _dictionary(data.get("regions_by_id", {}))
	var prepared_cards := _dictionary(data.get("cards_by_id", {}))
	var prepared_racks := _dictionary(data.get("racks_by_region", {}))
	var prepared_slot_revisions := _dictionary(data.get("slot_revisions_by_region", {}))
	var prepared_bags := _dictionary(data.get("bags_by_region", {}))
	var prepared_rng_states := _dictionary(data.get("rng_state_by_region", {}))
	if bool(data.get("configured", false)) and (
			prepared_region_order.is_empty()
			or prepared_card_order.is_empty()
			or not _saved_region_state_valid(
				prepared_region_order,
				prepared_regions,
				prepared_racks,
				prepared_slot_revisions,
				prepared_bags,
				prepared_rng_states
			)
	):
		return {"applied": false, "reason_code": "region_supply_save_shape_invalid"}

	_configured = bool(data.get("configured", false))
	_gameplay_seed = int(data.get("gameplay_seed", 0))
	_state_revision = maxi(0, int(data.get("state_revision", 0)))
	_refill_sequence = maxi(0, int(data.get("refill_sequence", 0)))
	_regions_by_id = prepared_regions
	_region_order = prepared_region_order
	_cards_by_id = prepared_cards
	_card_order = prepared_card_order
	_racks_by_region = prepared_racks
	_slot_revisions_by_region = prepared_slot_revisions
	_bags_by_region = prepared_bags
	_rng_state_by_region = prepared_rng_states
	_claimed_unique_keys = _dictionary(data.get("claimed_unique_keys", {}))
	_pending_transactions = _dictionary(data.get("pending_transactions", {}))
	_terminal_transactions = _dictionary(data.get("terminal_transactions", {}))
	return {
		"applied": true,
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


func _saved_region_state_valid(
	region_order: Array[String],
	regions: Dictionary,
	racks: Dictionary,
	slot_revisions: Dictionary,
	bags: Dictionary,
	rng_states: Dictionary
) -> bool:
	for region_id in region_order:
		if not regions.has(region_id) \
				or not (racks.get(region_id) is Array) \
				or not (slot_revisions.get(region_id) is Array) \
				or not (bags.get(region_id) is Array) \
				or typeof(rng_states.get(region_id)) != TYPE_INT:
			return false
		if (racks.get(region_id) as Array).size() != (slot_revisions.get(region_id) as Array).size():
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


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item_variant in value:
		var item := str(item_variant).strip_edges()
		if not item.is_empty() and not result.has(item):
			result.append(item)
	return result


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Vector2 or value is Vector2i or value is Color:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName):
				return false
			if not _is_pure_data((value as Dictionary).get(key_variant)):
				return false
		return true
	return false


func _result(ok: bool, reason_code: String) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason_code,
		"state_revision": _state_revision,
	}
