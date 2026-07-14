extends RefCounted
class_name CardMarketQuoteAuthorityFixture

var now_world_us := 0
var _next_sequence := 1
var _records: Dictionary = {}


func issue_quote(player_index: int, district_index: int, card_id: String, supply_revision: String, final_price: int, lifetime_us: int = 5_000_000) -> Dictionary:
	if player_index < 0 or district_index < 0 or card_id.is_empty() or supply_revision.is_empty() or final_price < 0 or lifetime_us <= 0:
		return {}
	var quote_id := "fixture-quote-%d" % _next_sequence
	_next_sequence += 1
	var record := {
		"quote_id": quote_id,
		"player_index": player_index,
		"district_index": district_index,
		"card_id": card_id,
		"supply_revision": supply_revision,
		"final_price": final_price,
		"opened_at_world_us": now_world_us,
		"expires_at_world_us": now_world_us + lifetime_us,
	}
	record["quote_fingerprint"] = _fingerprint(record)
	_records[quote_id] = record.duplicate(true)
	return _request(record)


func authorize_purchase(request: Dictionary) -> Dictionary:
	var quote_id := str(request.get("quote_id", ""))
	var record: Dictionary = _records.get(quote_id, {}) if _records.get(quote_id, {}) is Dictionary else {}
	if record.is_empty() or now_world_us >= int(record.get("expires_at_world_us", -1)):
		return {"authorized": false, "reason": "quote_missing_or_expired"}
	for key in ["player_index", "district_index", "card_id", "supply_revision", "quote_fingerprint"]:
		if request.get(key) != record.get(key):
			return {"authorized": false, "reason": "quote_binding_mismatch"}
	if str(record.get("quote_fingerprint", "")) != _fingerprint(record):
		return {"authorized": false, "reason": "quote_fingerprint_invalid"}
	var result := record.duplicate(true)
	result["authorized"] = true
	result["reason"] = "quote_authorized"
	return result


func _request(record: Dictionary) -> Dictionary:
	return {
		"quote_id": str(record.get("quote_id", "")),
		"quote_fingerprint": str(record.get("quote_fingerprint", "")),
		"player_index": int(record.get("player_index", -1)),
		"district_index": int(record.get("district_index", -1)),
		"card_id": str(record.get("card_id", "")),
		"supply_revision": str(record.get("supply_revision", "")),
	}


func _fingerprint(record: Dictionary) -> String:
	return JSON.stringify([
		int(record.get("player_index", -1)),
		int(record.get("district_index", -1)),
		str(record.get("card_id", "")),
		str(record.get("supply_revision", "")),
		int(record.get("final_price", -1)),
		int(record.get("opened_at_world_us", -1)),
		int(record.get("expires_at_world_us", -1)),
	]).sha256_text()
