@tool
extends Node
class_name CardMarketPricingRuntimeController

const QUOTE_LIFETIME_US := 5_000_000
const BASE_MULTIPLIER_Q2 := 2
const SAME_REGION_Q2_STEP := 2
const ADJACENT_Q2_STEP := 1
const MAX_MULTIPLIER_Q2 := 10

var _clock: Node
var _solar: Node
var _world_bridge: Node
var _configured := false
var _next_quote_sequence := 1
var _quotes_by_key: Dictionary = {}
var _quotes_by_id: Dictionary = {}
var _quote_count := 0
var _authorization_count := 0


func set_dependencies(clock: Node, solar: Node, world_bridge: Node) -> void:
	_clock = clock
	_solar = solar
	_world_bridge = world_bridge


func configure(_config: Dictionary = {}) -> void:
	_configured = _clock != null and _clock.has_method("world_effective_micros") \
		and _solar != null and _solar.has_method("availability") \
		and _world_bridge != null and _world_bridge.has_method("capture_market_facts")
	reset_state()


func reset_state() -> void:
	_next_quote_sequence = 1
	_quotes_by_key.clear()
	_quotes_by_id.clear()
	_quote_count = 0
	_authorization_count = 0


func capture_runtime_checkpoint() -> Dictionary:
	return {"schema_version": 1, "next_quote_sequence": _next_quote_sequence, "quotes_by_key": _quotes_by_key.duplicate(true), "quotes_by_id": _quotes_by_id.duplicate(true), "quote_count": _quote_count, "authorization_count": _authorization_count}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1 or not (checkpoint.get("quotes_by_key") is Dictionary) or not (checkpoint.get("quotes_by_id") is Dictionary):
		return {"restored": false, "reason_code": "card_market_checkpoint_invalid"}
	_next_quote_sequence = int(checkpoint.get("next_quote_sequence", 1))
	_quotes_by_key = (checkpoint.get("quotes_by_key", {}) as Dictionary).duplicate(true)
	_quotes_by_id = (checkpoint.get("quotes_by_id", {}) as Dictionary).duplicate(true)
	_quote_count = int(checkpoint.get("quote_count", 0))
	_authorization_count = int(checkpoint.get("authorization_count", 0))
	return {"restored": true, "reason_code": "card_market_checkpoint_restored"}


func quote_listing(request: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(request):
		return _rejected_quote("market_quote_unavailable")
	var player_index := int(request.get("player_index", -1))
	var district_index := int(request.get("district_index", -1))
	var card_id := str(request.get("card_id", "")).strip_edges()
	var supply_revision := str(request.get("supply_revision", ""))
	var base_price := int(request.get("base_price", -1))
	if player_index < 0 or district_index < 0 or card_id.is_empty() or supply_revision.is_empty() or base_price < 0:
		return _rejected_quote("invalid_listing_request")
	var now_us := _now_us()
	var quote_key := _quote_key(player_index, district_index, card_id, supply_revision)
	var existing: Dictionary = (_quotes_by_key.get(quote_key, {}) as Dictionary).duplicate(true) if _quotes_by_key.get(quote_key, {}) is Dictionary else {}
	if not existing.is_empty() and now_us < int(existing.get("expires_at_world_us", -1)) and int(existing.get("base_price", -1)) == base_price:
		return _public_quote(existing, now_us)
	var evaluation := _evaluate_listing(district_index, base_price)
	if evaluation.is_empty():
		return _rejected_quote("market_facts_unavailable")
	var quote_id := _next_available_quote_id(now_us)
	var record := {
		"schema_version": 1,
		"quote_id": quote_id,
		"quote_key": quote_key,
		"player_index": player_index,
		"district_index": district_index,
		"card_id": card_id,
		"supply_revision": supply_revision,
		"base_price": base_price,
		"final_price": int(evaluation.get("final_price", base_price)),
		"multiplier_q2": int(evaluation.get("multiplier_q2", BASE_MULTIPLIER_Q2)),
		"same_region_alive_count": int(evaluation.get("same_region_alive_count", 0)),
		"directly_adjacent_alive_count": int(evaluation.get("directly_adjacent_alive_count", 0)),
		"eligible": bool(evaluation.get("purchasable", false)),
		"viewable": bool(evaluation.get("viewable", false)),
		"availability_kind": str(evaluation.get("availability_kind", "invalid")),
		"opened_at_world_us": now_us,
		"expires_at_world_us": now_us + QUOTE_LIFETIME_US,
	}
	record["quote_fingerprint"] = _quote_fingerprint(record)
	record["quote_binding_fingerprint"] = _quote_binding_fingerprint(record)
	_quotes_by_key[quote_key] = record.duplicate(true)
	_quotes_by_id[quote_id] = record.duplicate(true)
	_quote_count += 1
	return _public_quote(record, now_us)


func refresh_quote_listing(request: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(request):
		return _rejected_quote("market_quote_unavailable")
	var player_index := int(request.get("player_index", -1))
	var district_index := int(request.get("district_index", -1))
	var card_id := str(request.get("card_id", "")).strip_edges()
	var supply_revision := str(request.get("supply_revision", ""))
	if player_index < 0 or district_index < 0 or card_id.is_empty() or supply_revision.is_empty():
		return _rejected_quote("invalid_listing_request")
	var quote_key := _quote_key(player_index, district_index, card_id, supply_revision)
	var existing: Dictionary = _quotes_by_key.get(quote_key, {}) if _quotes_by_key.get(quote_key, {}) is Dictionary else {}
	var existing_quote_id := str(existing.get("quote_id", ""))
	_quotes_by_key.erase(quote_key)
	if not existing_quote_id.is_empty():
		_quotes_by_id.erase(existing_quote_id)
	return quote_listing(request)


func preview_listing(request: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(request):
		return _rejected_preview("market_preview_unavailable")
	var district_index := int(request.get("district_index", -1))
	var card_id := str(request.get("card_id", "")).strip_edges()
	var supply_revision := str(request.get("supply_revision", ""))
	var base_price := int(request.get("base_price", -1))
	if district_index < 0 or card_id.is_empty() or supply_revision.is_empty() or base_price < 0:
		return _rejected_preview("invalid_listing_request")
	var result := _evaluate_listing(district_index, base_price)
	if result.is_empty():
		return _rejected_preview("market_facts_unavailable")
	result["district_index"] = district_index
	result["card_id"] = card_id
	result["supply_revision"] = supply_revision
	result["preview_only"] = true
	result["quote_active"] = false
	result["confirmable"] = false
	return result


func listing_availability(source_district_index: int) -> Dictionary:
	if not _configured or source_district_index < 0:
		return {"viewable": false, "purchasable": false, "availability_kind": "invalid", "reason_code": "market_unavailable"}
	var facts_variant: Variant = _world_bridge.call("capture_market_facts", source_district_index)
	var facts: Dictionary = facts_variant if facts_variant is Dictionary else {}
	if facts.is_empty():
		return {"viewable": false, "purchasable": false, "availability_kind": "invalid", "reason_code": "market_facts_unavailable"}
	var value: Variant = _solar.call(
		"availability",
		_now_us(),
		float(facts.get("source_center_x", 0.0)),
		float(facts.get("world_width", 0.0)),
		bool(facts.get("source_destroyed", false))
	)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func authorize_purchase(request: Dictionary) -> Dictionary:
	_authorization_count += 1
	if not _configured or not _is_data_only(request):
		return _authorization(false, "invalid_quote_request", {})
	var quote_id := str(request.get("quote_id", ""))
	var record: Dictionary = (_quotes_by_id.get(quote_id, {}) as Dictionary).duplicate(true) if _quotes_by_id.get(quote_id, {}) is Dictionary else {}
	if record.is_empty():
		return _authorization(false, "quote_missing", {})
	for key in ["player_index", "district_index", "card_id", "supply_revision"]:
		if record.get(key) != request.get(key):
			return _authorization(false, "quote_binding_mismatch", {})
	if str(request.get("quote_fingerprint", "")) != str(record.get("quote_fingerprint", "")):
		return _authorization(false, "quote_fingerprint_mismatch", {})
	var now_us := _now_us()
	if now_us >= int(record.get("expires_at_world_us", -1)):
		return _authorization(false, "quote_expired", {})
	if not bool(record.get("eligible", false)):
		return _authorization(false, "source_region_dark", record)
	return _authorization(true, "quote_authorized", record)


func quote_snapshot(quote_id: String) -> Dictionary:
	var record: Dictionary = (_quotes_by_id.get(quote_id, {}) as Dictionary).duplicate(true) if _quotes_by_id.get(quote_id, {}) is Dictionary else {}
	return _public_quote(record, _now_us()) if not record.is_empty() else {}


func export_quote_for_session(quote_id: String) -> Dictionary:
	var record: Dictionary = (_quotes_by_id.get(quote_id, {}) as Dictionary).duplicate(true) if _quotes_by_id.get(quote_id, {}) is Dictionary else {}
	return record if not record.is_empty() \
			and str(record.get("quote_fingerprint", "")) == _quote_fingerprint(record) \
			and str(record.get("quote_binding_fingerprint", "")) == _quote_binding_fingerprint(record) else {}


func restore_quote_from_session(snapshot: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(snapshot) or snapshot.is_empty():
		return {"restored": false, "reason": "quote_snapshot_invalid"}
	if int(snapshot.get("schema_version", 0)) != 1:
		return {"restored": false, "reason": "quote_schema_invalid"}
	var quote_id := str(snapshot.get("quote_id", ""))
	var quote_key := str(snapshot.get("quote_key", ""))
	var fingerprint := str(snapshot.get("quote_fingerprint", ""))
	if quote_id.is_empty() or quote_key.is_empty() or fingerprint.is_empty() or fingerprint != _quote_fingerprint(snapshot):
		return {"restored": false, "reason": "quote_fingerprint_invalid"}
	var binding_fingerprint := str(snapshot.get("quote_binding_fingerprint", ""))
	if binding_fingerprint.is_empty() or binding_fingerprint != _quote_binding_fingerprint(snapshot):
		return {"restored": false, "reason": "quote_binding_fingerprint_invalid"}
	var player_index := int(snapshot.get("player_index", -1))
	var district_index := int(snapshot.get("district_index", -1))
	var card_id := str(snapshot.get("card_id", ""))
	var supply_revision := str(snapshot.get("supply_revision", ""))
	if quote_key != _quote_key(player_index, district_index, card_id, supply_revision):
		return {"restored": false, "reason": "quote_key_invalid"}
	var now_us := _now_us()
	var opened_at_us := int(snapshot.get("opened_at_world_us", -1))
	var expires_at_us := int(snapshot.get("expires_at_world_us", -1))
	if opened_at_us < 0 or expires_at_us != opened_at_us + QUOTE_LIFETIME_US or opened_at_us > now_us or now_us >= expires_at_us:
		return {"restored": false, "reason": "quote_expired"}
	if player_index < 0 or district_index < 0 or card_id.is_empty() or supply_revision.is_empty():
		return {"restored": false, "reason": "quote_binding_invalid"}
	var base_price := int(snapshot.get("base_price", -1))
	var same_count := int(snapshot.get("same_region_alive_count", -1))
	var adjacent_count := int(snapshot.get("directly_adjacent_alive_count", -1))
	var multiplier_q2 := int(snapshot.get("multiplier_q2", -1))
	var expected_q2 := mini(MAX_MULTIPLIER_Q2, BASE_MULTIPLIER_Q2 + same_count * SAME_REGION_Q2_STEP + adjacent_count * ADJACENT_Q2_STEP)
	if base_price < 0 or same_count < 0 or adjacent_count < 0 or multiplier_q2 != expected_q2 or int(snapshot.get("final_price", -1)) != _ceil_scaled_price(base_price, expected_q2):
		return {"restored": false, "reason": "quote_price_snapshot_invalid"}
	var existing_by_id: Dictionary = _quotes_by_id.get(quote_id, {}) if _quotes_by_id.get(quote_id, {}) is Dictionary else {}
	var existing_by_key: Dictionary = _quotes_by_key.get(quote_key, {}) if _quotes_by_key.get(quote_key, {}) is Dictionary else {}
	if (not existing_by_id.is_empty() and str(existing_by_id.get("quote_binding_fingerprint", "")) != binding_fingerprint) \
			or (not existing_by_key.is_empty() and str(existing_by_key.get("quote_binding_fingerprint", "")) != binding_fingerprint):
		return {"restored": false, "reason": "quote_identity_conflict"}
	_quotes_by_key[quote_key] = snapshot.duplicate(true)
	_quotes_by_id[quote_id] = snapshot.duplicate(true)
	return {"restored": true, "reason": "quote_restored", "quote": _public_quote(snapshot, now_us)}


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _configured,
		"quote_lifetime_us": QUOTE_LIFETIME_US,
		"quote_count": _quote_count,
		"authorization_count": _authorization_count,
		"active_quote_count": _quotes_by_id.size(),
		"pricing_authority": true,
		"sunlight_authority": false,
		"clock_authority": false,
		"reads_camera_state": false,
		"reads_monster_ownership": false,
		"reads_private_player_state": false,
	}


func _live_monster_counts(facts: Dictionary) -> Dictionary:
	var source_district_index := int(facts.get("source_district_index", -1))
	var direct_neighbors: Array = facts.get("direct_neighbors", []) if facts.get("direct_neighbors", []) is Array else []
	var monsters: Array = facts.get("monsters", []) if facts.get("monsters", []) is Array else []
	var same := 0
	var adjacent := 0
	for monster_variant: Variant in monsters:
		if not (monster_variant is Dictionary):
			continue
		var monster := monster_variant as Dictionary
		if bool(monster.get("down", false)):
			continue
		if monster.has("remaining_time") and float(monster.get("remaining_time", 0.0)) <= 0.0:
			continue
		var district_index := int(monster.get("district_index", -1))
		if district_index == source_district_index:
			same += 1
		elif direct_neighbors.has(district_index):
			adjacent += 1
	return {"same": same, "adjacent": adjacent}


func _next_available_quote_id(now_us: int) -> String:
	while true:
		var candidate := "market-quote-%d-%d" % [now_us, _next_quote_sequence]
		_next_quote_sequence += 1
		if not _quotes_by_id.has(candidate):
			return candidate
	return ""


func _evaluate_listing(district_index: int, base_price: int) -> Dictionary:
	var facts_variant: Variant = _world_bridge.call("capture_market_facts", district_index)
	var facts: Dictionary = facts_variant if facts_variant is Dictionary else {}
	if facts.is_empty():
		return {}
	var availability_variant: Variant = _solar.call(
		"availability",
		_now_us(),
		float(facts.get("source_center_x", 0.0)),
		float(facts.get("world_width", 0.0)),
		bool(facts.get("source_destroyed", false))
	)
	var availability: Dictionary = availability_variant if availability_variant is Dictionary else {}
	var counts := _live_monster_counts(facts)
	var q2 := mini(MAX_MULTIPLIER_Q2, BASE_MULTIPLIER_Q2 + int(counts.get("same", 0)) * SAME_REGION_Q2_STEP + int(counts.get("adjacent", 0)) * ADJACENT_Q2_STEP)
	return {
		"base_price": base_price,
		"final_price": _ceil_scaled_price(base_price, q2),
		"multiplier_q2": q2,
		"same_region_alive_count": int(counts.get("same", 0)),
		"directly_adjacent_alive_count": int(counts.get("adjacent", 0)),
		"purchasable": bool(availability.get("purchasable", false)),
		"eligible": bool(availability.get("purchasable", false)),
		"viewable": bool(availability.get("viewable", false)),
		"availability_kind": str(availability.get("availability_kind", "invalid")),
	}


func _ceil_scaled_price(base_price: int, multiplier_q2: int) -> int:
	return int((base_price * multiplier_q2 + 1) / 2)


func _public_quote(record: Dictionary, now_us: int) -> Dictionary:
	if record.is_empty():
		return {}
	var quote_active := now_us < int(record.get("expires_at_world_us", 0))
	var locked_eligible := bool(record.get("eligible", false))
	return {
		"quote_id": str(record.get("quote_id", "")),
		"district_index": int(record.get("district_index", -1)),
		"card_id": str(record.get("card_id", "")),
		"supply_revision": str(record.get("supply_revision", "")),
		"base_price": int(record.get("base_price", 0)),
		"final_price": int(record.get("final_price", 0)),
		"multiplier_q2": int(record.get("multiplier_q2", BASE_MULTIPLIER_Q2)),
		"same_region_alive_count": int(record.get("same_region_alive_count", 0)),
		"directly_adjacent_alive_count": int(record.get("directly_adjacent_alive_count", 0)),
		"eligible": locked_eligible and quote_active,
		"locked_eligible": locked_eligible,
		"quote_active": quote_active,
		"confirmable": locked_eligible and quote_active,
		"viewable": bool(record.get("viewable", false)),
		"availability_kind": str(record.get("availability_kind", "invalid")),
		"opened_at_world_us": int(record.get("opened_at_world_us", 0)),
		"expires_at_world_us": int(record.get("expires_at_world_us", 0)),
		"remaining_world_us": maxi(0, int(record.get("expires_at_world_us", 0)) - now_us),
		"quote_fingerprint": str(record.get("quote_fingerprint", "")),
	}


func _authorization(authorized: bool, reason_code: String, record: Dictionary) -> Dictionary:
	return {
		"authorized": authorized,
		"reason": reason_code,
		"player_index": int(record.get("player_index", -1)),
		"quote_id": str(record.get("quote_id", "")),
		"final_price": int(record.get("final_price", 0)),
		"district_index": int(record.get("district_index", -1)),
		"card_id": str(record.get("card_id", "")),
		"supply_revision": str(record.get("supply_revision", "")),
		"expires_at_world_us": int(record.get("expires_at_world_us", 0)),
		"quote_fingerprint": str(record.get("quote_fingerprint", "")),
	}


func _rejected_quote(reason_code: String) -> Dictionary:
	return {
		"quote_id": "",
		"eligible": false,
		"viewable": false,
		"availability_kind": "invalid",
		"reason_code": reason_code,
		"final_price": 0,
	}


func _rejected_preview(reason_code: String) -> Dictionary:
	return {
		"eligible": false,
		"purchasable": false,
		"viewable": false,
		"availability_kind": "invalid",
		"reason_code": reason_code,
		"final_price": 0,
		"preview_only": true,
		"quote_active": false,
		"confirmable": false,
	}


func _quote_key(player_index: int, district_index: int, card_id: String, supply_revision: String) -> String:
	return JSON.stringify([player_index, district_index, card_id, supply_revision]).sha256_text()


func _quote_fingerprint(record: Dictionary) -> String:
	var canonical_fields := [
		int(record.get("schema_version", 0)),
		int(record.get("district_index", -1)),
		str(record.get("card_id", "")),
		str(record.get("supply_revision", "")),
		int(record.get("base_price", -1)),
		int(record.get("final_price", -1)),
		int(record.get("multiplier_q2", -1)),
		int(record.get("same_region_alive_count", -1)),
		int(record.get("directly_adjacent_alive_count", -1)),
		bool(record.get("eligible", false)),
		bool(record.get("viewable", false)),
		str(record.get("availability_kind", "")),
		int(record.get("opened_at_world_us", -1)),
		int(record.get("expires_at_world_us", -1)),
	]
	return JSON.stringify(canonical_fields).sha256_text()


func _quote_binding_fingerprint(record: Dictionary) -> String:
	return JSON.stringify([
		int(record.get("schema_version", 0)),
		str(record.get("quote_id", "")),
		int(record.get("player_index", -1)),
		str(record.get("quote_key", "")),
		_quote_fingerprint(record),
	]).sha256_text()


func _now_us() -> int:
	return int(_clock.call("world_effective_micros")) if _clock != null and _clock.has_method("world_effective_micros") else 0


func _is_data_only(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _is_data_only(key) or not _is_data_only((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in (value as Array):
			if not _is_data_only(item):
				return false
	return true
