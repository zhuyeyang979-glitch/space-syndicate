extends SceneTree

const PRODUCTION_BENCH := preload("res://scenes/tools/DistrictPurchaseRuntimeCutoverBench.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := PRODUCTION_BENCH.instantiate()
	bench.set("auto_run", false)
	root.add_child(bench)
	await process_frame
	bench.call("_prepare_runtime")
	bench.call("_reset_policy")

	var coordinator := bench.get_node_or_null("%GameRuntimeCoordinator")
	var pricing := coordinator.get_node_or_null("CardMarketPricingRuntimeController") if coordinator != null else null
	var world: Node = bench.get("_world") as Node
	var monsters: Node = world.get("monster_runtime_controller") as Node if world != null else null
	if coordinator == null or pricing == null or monsters == null:
		_expect(false, "production pricing composition is available")
	else:
		monsters.set("entries", [{"district_index": 0, "down": false, "remaining_time": 10.0, "owner": "PRIVATE_OWNER"}])
		coordinator.call("restore_world_effective_seconds", 0.0)
		var seat_zero_request := _listing(0)
		var seat_one_request := _listing(1)
		var seat_zero: Dictionary = pricing.call("quote_listing", seat_zero_request)
		var seat_one: Dictionary = pricing.call("quote_listing", seat_one_request)
		_expect(not seat_zero.is_empty() and not seat_one.is_empty(), "two seats receive quotes for one public listing at the same world-effective time")
		_expect(int(seat_zero.get("final_price", -1)) == 202 and int(seat_one.get("final_price", -1)) == 202, "identical public world facts give every seat the same price")
		_expect(_quote_without_transport_tokens(seat_zero) == _quote_without_transport_tokens(seat_one), "all non-transport public quote facts are seat-neutral")
		var seat_zero_authorization: Dictionary = pricing.call("authorize_purchase", _authorization_request(seat_zero_request, seat_zero))
		var seat_one_authorization: Dictionary = pricing.call("authorize_purchase", _authorization_request(seat_one_request, seat_one))
		var crossed_request := _authorization_request(seat_one_request, seat_zero)
		var crossed_authorization: Dictionary = pricing.call("authorize_purchase", crossed_request)
		_expect(bool(seat_zero_authorization.get("authorized", false)) and bool(seat_one_authorization.get("authorized", false)) and not bool(crossed_authorization.get("authorized", true)), "private authorization remains separately bound to each player")
		var fingerprint_hidden := not seat_zero.has("quote_fingerprint") and not seat_one.has("quote_fingerprint")
		var fingerprint_public_but_seat_neutral := seat_zero.has("quote_fingerprint") and seat_one.has("quote_fingerprint") \
			and str(seat_zero.get("quote_fingerprint", "")) == str(seat_one.get("quote_fingerprint", ""))
		_expect(fingerprint_hidden or fingerprint_public_but_seat_neutral, "public quote exposes no fingerprint that distinguishes player 0 from player 1 under identical public facts")

	bench.queue_free()
	await process_frame
	_finish()


func _listing(player_index: int) -> Dictionary:
	return {
		"player_index": player_index,
		"district_index": 0,
		"card_id": "card.qa.public-privacy",
		"supply_revision": "qa-public-privacy",
		"base_price": 101,
	}


func _authorization_request(listing: Dictionary, quote: Dictionary) -> Dictionary:
	return {
		"quote_id": str(quote.get("quote_id", "")),
		"quote_fingerprint": str(quote.get("quote_fingerprint", "")),
		"player_index": int(listing.get("player_index", -1)),
		"district_index": int(listing.get("district_index", -1)),
		"card_id": str(listing.get("card_id", "")),
		"supply_revision": str(listing.get("supply_revision", "")),
	}


func _quote_without_transport_tokens(quote: Dictionary) -> Dictionary:
	var facts := quote.duplicate(true)
	facts.erase("quote_id")
	facts.erase("quote_fingerprint")
	return facts


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("CARD MARKET PUBLIC QUOTE PLAYER PRIVACY: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("CARD_MARKET_PUBLIC_QUOTE_PLAYER_PRIVACY_TEST|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
