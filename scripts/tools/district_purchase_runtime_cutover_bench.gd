@tool
extends Control
class_name DistrictPurchaseRuntimeCutoverBench

const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLANET_MAP_SCENE := preload("res://scenes/ui/PlanetMapView.tscn")

@export var auto_run := true

@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var status_label: Label = %StatusLabel
@onready var detail_label: RichTextLabel = %DetailLabel

var _checks := 0
var _failures: Array[String] = []
var _world: MarketWorld
var _diagnostics: Dictionary = {}


class MonsterRoster:
	extends Node

	var entries: Array = []

	func roster_snapshot(_include_private := false) -> Array:
		return entries.duplicate(true)


class MarketWorld:
	extends Node

	var map_width_m := 1000.0
	var map_height_m := 500.0
	var selected_district := 0
	var view_center := Vector2(500.0, 250.0)
	var view_zoom := 0.48
	var projection := "globe"
	var players: Array = [
		{"cash": 999999, "slots": ["PRIVATE_HAND_A"], "ai_plan": "PRIVATE_AI_A"},
		{"cash": 123456, "slots": ["PRIVATE_HAND_B"], "ai_plan": "PRIVATE_AI_B"},
	]
	var districts: Array = [
		{"name": "Sunlit Source", "center": Vector2(0.0, 250.0), "neighbors": [1], "destroyed": false},
		{"name": "Direct Neighbor", "center": Vector2(250.0, 250.0), "neighbors": [0, 2], "destroyed": false},
		{"name": "Dark Source", "center": Vector2(500.0, 250.0), "neighbors": [1, 3], "destroyed": false},
		{"name": "Dusk Source", "center": Vector2(760.0, 250.0), "neighbors": [2], "destroyed": false},
	]
	var monster_runtime_controller: Node

	func _init() -> void:
		monster_runtime_controller = MonsterRoster.new()
		add_child(monster_runtime_controller)

	func focus_district(index: int, _keep_zoom := true) -> void:
		selected_district = index
		view_center = (districts[index] as Dictionary).get("center", view_center)
		view_zoom = 0.91
		projection = "local"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if auto_run:
		call_deferred("_run_and_render")


func _run_and_render() -> void:
	var report := await run_suite()
	status_label.text = "%s — %d checks" % ["PASS" if _failures.is_empty() else "FAIL", _checks]
	detail_label.text = JSON.stringify(report, "  ")
	print("CARD_MARKET_POLICY_RUNTIME_BENCH|%s" % JSON.stringify(report))


func run_suite() -> Dictionary:
	_checks = 0
	_failures.clear()
	_diagnostics.clear()
	_prepare_runtime()
	status_label.text = "Checking clock and solar derivation…"
	_test_clock_and_solar()
	status_label.text = "Checking preview, pricing, camera and privacy…"
	await _test_preview_pricing_camera_and_privacy()
	status_label.text = "Checking quote expiry and restore…"
	_test_locked_quote_expiry_and_restore()
	status_label.text = "Checking purchase-session bindings…"
	_test_purchase_session_binding()
	status_label.text = "Checking real first-table flow…"
	return result_snapshot()


func result_snapshot() -> Dictionary:
	return {
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"checks": _checks,
		"failures": _failures.duplicate(),
		"production_owner": "CardMarketPricingRuntimeController",
		"world_clock_owner": "WorldEffectiveClockRuntimeController",
		"quote_lifetime_us": 5_000_000,
		"rotation_period_us": 120_000_000,
	}


func _prepare_runtime() -> void:
	_world = MarketWorld.new()
	add_child(_world)
	coordinator.configure(RULESET_PROFILE.debug_snapshot())
	coordinator.bind_runtime_world(_world)
	coordinator.restore_world_effective_seconds(0.0)


func _reset_policy() -> void:
	var clock := coordinator.get_node_or_null("WorldEffectiveClockRuntimeController")
	var pricing := coordinator.get_node_or_null("CardMarketPricingRuntimeController")
	var purchase := coordinator.get_node_or_null("DistrictPurchaseRuntimeController")
	if clock != null:
		clock.call("reset_state")
	if pricing != null:
		pricing.call("reset_state")
	if purchase != null:
		purchase.call("reset_state")
	(_world.monster_runtime_controller as MonsterRoster).entries = []


func _test_clock_and_solar() -> void:
	_reset_policy()
	var standalone_packed := load("res://scenes/runtime/GameSessionRuntimeController.tscn") as PackedScene
	var standalone_session := standalone_packed.instantiate() if standalone_packed != null else null
	if standalone_session != null:
		standalone_session.call("configure", {"ruleset_id": "v0.6"})
	_expect(standalone_session != null and (standalone_session.call("to_save_data") as Dictionary).is_empty(), "standalone GameSession capture fails closed instead of inventing world_effective_us=0 without a clock owner")
	if standalone_session != null:
		standalone_session.free()
	coordinator.advance_world_effective_clock(0.0000004)
	coordinator.advance_world_effective_clock(0.0000004)
	coordinator.advance_world_effective_clock(0.0000004)
	_expect(int(coordinator.world_effective_clock_snapshot().get("world_effective_us", -1)) == 1, "fractional frame deltas accumulate at the integer clock owner")
	coordinator.restore_world_effective_seconds(0.0)
	var dawn: Dictionary = coordinator.card_market_listing_availability(0)
	var dark: Dictionary = coordinator.card_market_listing_availability(2)
	_expect(str(dawn.get("availability_kind", "")) == "sunlit" and bool(dawn.get("purchasable", false)), "source center on the lit hemisphere is purchasable")
	_expect(str(dark.get("availability_kind", "")) == "dark" and bool(dark.get("viewable", false)) and not bool(dark.get("purchasable", true)), "dark source remains viewable but not purchasable")
	coordinator.restore_world_effective_seconds(60.0)
	_expect(str(coordinator.card_market_listing_availability(0).get("availability_kind", "")) == "dark", "half a rotation moves the source onto the dark hemisphere")
	coordinator.restore_world_effective_seconds(120.0)
	_expect(str(coordinator.card_market_listing_availability(0).get("availability_kind", "")) == "sunlit", "the pure solar derivation returns after exactly 120 world seconds")
	coordinator.restore_world_effective_seconds(0.0)
	var session := coordinator.get_node_or_null("GameSessionRuntimeController")
	var composed_session_save: Dictionary = session.call("to_save_data") if session != null else {}
	var composed_session_payload: Dictionary = composed_session_save.get("game_session_runtime", {}) if composed_session_save.get("game_session_runtime", {}) is Dictionary else {}
	_expect(composed_session_payload.get("world_effective_us") is int and int(composed_session_payload.get("world_effective_us", -1)) == 0, "Coordinator composition injects the clock and captures an authoritative integer world_effective_us")
	coordinator.restore_world_effective_seconds(9.5)
	var applied: Dictionary = session.call("apply_save_data", {"game_session_runtime": {"schema_version": 1, "session_state": "running", "ruleset_id": "v0.4", "session_id": "clock-restore", "scenario_id": "", "seed": 7, "setup": {}, "outcome_receipt": {}, "world_effective_us": 1234567}}) if session != null else {}
	_expect(bool(applied.get("applied", false)) and int(coordinator.world_effective_clock_snapshot().get("world_effective_us", -1)) == 1234567, "game-session integer clock overrides a legacy float migration seed")
	var before_invalid: Dictionary = coordinator.world_effective_clock_snapshot()
	var invalid: Dictionary = session.call("apply_save_data", {"game_session_runtime": {"schema_version": 1, "session_state": "bogus", "world_effective_us": -1}}) if session != null else {}
	_expect(not bool(invalid.get("applied", true)) and coordinator.world_effective_clock_snapshot() == before_invalid, "invalid session payload fails before mutating the authoritative clock")


func _test_preview_pricing_camera_and_privacy() -> void:
	_reset_policy()
	var pricing := coordinator.get_node_or_null("CardMarketPricingRuntimeController")
	var bridge := coordinator.get_node_or_null("CardMarketPolicyWorldBridge")
	for _index in range(4):
		coordinator.card_market_preview(_listing(0, "card.hover.a", "supply-a", 101))
	_expect(int(pricing.call("debug_snapshot").get("quote_count", -1)) == 0, "repeated hover-style preview and refresh create zero quotes")
	var no_monster: Dictionary = coordinator.card_market_preview(_listing(0, "card.price", "supply-price", 101))
	_expect(int(no_monster.get("multiplier_q2", -1)) == 2 and int(no_monster.get("final_price", -1)) == 101, "no monster influence preserves the base price")
	(_world.monster_runtime_controller as MonsterRoster).entries = [
		{"district_index": 0, "down": false, "remaining_time": 10.0, "owner": 91, "true_owner": "PRIVATE_OWNER_A"},
	]
	var one_same: Dictionary = coordinator.card_market_preview(_listing(0, "card.price", "supply-price", 101))
	_expect(int(one_same.get("multiplier_q2", -1)) == 4 and int(one_same.get("final_price", -1)) == 202, "one same-region living monster produces 2x")
	(_world.monster_runtime_controller as MonsterRoster).entries = [
		{"district_index": 1, "down": false, "remaining_time": 10.0, "owner": -1},
	]
	var one_adjacent: Dictionary = coordinator.card_market_preview(_listing(0, "card.price", "supply-price", 101))
	_expect(int(one_adjacent.get("multiplier_q2", -1)) == 3 and int(one_adjacent.get("final_price", -1)) == 152, "one directly adjacent living monster produces 1.5x with ceiling")
	(_world.monster_runtime_controller as MonsterRoster).entries = [
		{"district_index": 0, "down": false, "remaining_time": 10.0, "owner": 0},
		{"district_index": 1, "down": false, "remaining_time": 10.0, "owner": 1},
		{"district_index": 1, "down": false, "remaining_time": 10.0, "owner": 99},
	]
	var additive: Dictionary = coordinator.card_market_preview(_listing(0, "card.price", "supply-price", 101))
	_expect(int(additive.get("multiplier_q2", -1)) == 6 and int(additive.get("final_price", -1)) == 303, "same one plus adjacent two adds to 3x")
	(_world.monster_runtime_controller as MonsterRoster).entries = [
		{"district_index": 0, "down": false, "remaining_time": 10.0},
		{"district_index": 0, "down": false, "remaining_time": 10.0},
		{"district_index": 0, "down": false, "remaining_time": 10.0},
		{"district_index": 0, "down": false, "remaining_time": 10.0},
		{"district_index": 1, "down": false, "remaining_time": 10.0},
	]
	var capped: Dictionary = coordinator.card_market_preview(_listing(0, "card.price", "supply-price", 101))
	_expect(int(capped.get("multiplier_q2", -1)) == 10 and int(capped.get("final_price", -1)) == 505, "additive monster surcharge caps at 5x")
	(_world.monster_runtime_controller as MonsterRoster).entries = [
		{"district_index": 0, "down": true, "remaining_time": 10.0},
		{"district_index": 0, "down": false, "remaining_time": 0.0},
		{"district_index": 1, "down": false, "remaining_time": -1.0},
	]
	var excluded: Dictionary = coordinator.card_market_preview(_listing(0, "card.price", "supply-price", 101))
	_expect(int(excluded.get("final_price", -1)) == 101 and int(excluded.get("same_region_alive_count", -1)) == 0 and int(excluded.get("directly_adjacent_alive_count", -1)) == 0, "downed and expired monsters do not affect price")

	(_world.monster_runtime_controller as MonsterRoster).entries = [{"district_index": 0, "down": false, "remaining_time": 10.0, "owner": 777}]
	coordinator.open_district_purchase_window(0, 0, {"supply_revision": "supply-camera"})
	coordinator.acknowledge_district_purchase_selection(0, 0, "card.camera", "supply-camera")
	var before_facts: Dictionary = bridge.call("capture_market_facts", 0)
	var before_quote: Dictionary = coordinator.card_market_quote(_listing(0, "card.camera", "supply-camera", 101, 0))
	var map_view := PLANET_MAP_SCENE.instantiate()
	add_child(map_view)
	map_view.call("set_map", _world.districts, _world.map_width_m, _world.map_height_m, 0, [])
	map_view.call("zoom_to_local_projection")
	map_view.call("focus_district", 2, false)
	_world.focus_district(3, false)
	_world.view_zoom = 3.25
	_world.projection = "flat"
	await get_tree().process_frame
	var after_facts: Dictionary = bridge.call("capture_market_facts", 0)
	var after_quote: Dictionary = coordinator.card_market_quote(_listing(0, "card.camera", "supply-camera", 101, 0))
	_expect(before_facts == after_facts and str(before_quote.get("quote_id", "")) == str(after_quote.get("quote_id", "")) and str(before_quote.get("quote_fingerprint", "")) == str(after_quote.get("quote_fingerprint", "")), "wheel/zoom/projection/selection and focus_district do not change market facts or renew a quote")
	map_view.queue_free()
	var public_json := JSON.stringify(after_quote)
	_expect(not after_quote.has("player_index") and not public_json.contains("cash") and not public_json.contains("hand") and not public_json.contains("owner") and not public_json.contains("ai_plan"), "public quote excludes player binding and private cash, hand, ownership and AI facts")
	var bridge_debug: Dictionary = bridge.call("debug_snapshot")
	_expect(not bool(bridge_debug.get("camera_fields_read", true)) and not bool(bridge_debug.get("private_player_fields_read", true)) and not bool(bridge_debug.get("monster_owner_fields_read", true)), "world bridge declares camera/private/monster-owner independence")
	var player_one_quote := pricing.call("quote_listing", _listing(0, "card.same-price", "supply-player", 101, 1)) as Dictionary
	_expect(int(player_one_quote.get("final_price", -1)) == int(after_quote.get("final_price", -2)), "all buyers receive the same world-derived price")


func _test_locked_quote_expiry_and_restore() -> void:
	_reset_policy()
	var pricing := coordinator.get_node_or_null("CardMarketPricingRuntimeController")
	var clock := coordinator.get_node_or_null("WorldEffectiveClockRuntimeController")
	var dusk_request := _listing(3, "card.dusk", "supply-dusk", 101, 0)
	var dusk_quote: Dictionary = pricing.call("quote_listing", dusk_request)
	_expect(bool(dusk_quote.get("eligible", false)) and int(dusk_quote.get("expires_at_world_us", -1)) == 5_000_000, "explicit selection creates one fixed five-second quote")
	clock.call("restore_micros", 3_000_000)
	var live_after_turn: Dictionary = coordinator.card_market_listing_availability(3)
	var locked_authorization: Dictionary = pricing.call("authorize_purchase", _authorization_request(dusk_request, dusk_quote))
	_expect(str(live_after_turn.get("availability_kind", "")) == "dark" and bool(locked_authorization.get("authorized", false)) and int(locked_authorization.get("final_price", -1)) == 101, "quote keeps the opened eligibility and price across the terminator")
	clock.call("restore_micros", 4_999_999)
	_expect(bool((pricing.call("authorize_purchase", _authorization_request(dusk_request, dusk_quote)) as Dictionary).get("authorized", false)), "quote remains valid one microsecond before expiry")
	clock.call("restore_micros", 5_000_000)
	_expect(not bool((pricing.call("authorize_purchase", _authorization_request(dusk_request, dusk_quote)) as Dictionary).get("authorized", true)), "quote is invalid at the exact half-open expiry boundary")

	pricing.call("reset_state")
	clock.call("restore_micros", 2_000_000)
	var restored_request := _listing(0, "card.restore.a", "supply-restore-a", 101, 0)
	var original: Dictionary = pricing.call("quote_listing", restored_request)
	var session_snapshot: Dictionary = pricing.call("export_quote_for_session", str(original.get("quote_id", "")))
	pricing.call("reset_state")
	var restore_result: Dictionary = pricing.call("restore_quote_from_session", session_snapshot)
	var second_request := _listing(0, "card.restore.b", "supply-restore-b", 101, 1)
	var second: Dictionary = pricing.call("quote_listing", second_request)
	var original_authorized: Dictionary = pricing.call("authorize_purchase", _authorization_request(restored_request, original))
	var second_authorized: Dictionary = pricing.call("authorize_purchase", _authorization_request(second_request, second))
	_expect(bool(restore_result.get("restored", false)) and str(original.get("quote_id", "")) != str(second.get("quote_id", "")) and int(pricing.call("debug_snapshot").get("active_quote_count", -1)) == 2, "restored quote ID cannot collide with a new quote at the same world time")
	_expect(bool(original_authorized.get("authorized", false)) and bool(second_authorized.get("authorized", false)) and str(original.get("quote_fingerprint", "")) != str(second.get("quote_fingerprint", "")), "restored and newly issued bindings authorize independently")
	var tampered := session_snapshot.duplicate(true)
	tampered["card_id"] = "card.restore|ambiguous"
	_expect(not bool((pricing.call("restore_quote_from_session", tampered) as Dictionary).get("restored", true)), "canonical fingerprint rejects ambiguous or tampered session fields")
	var rebound := session_snapshot.duplicate(true)
	rebound["player_index"] = 7
	rebound["quote_key"] = JSON.stringify([
		7,
		int(rebound.get("district_index", -1)),
		str(rebound.get("card_id", "")),
		str(rebound.get("supply_revision", "")),
	]).sha256_text()
	_expect(not bool((pricing.call("restore_quote_from_session", rebound) as Dictionary).get("restored", true)), "private binding fingerprint rejects a session rebound to another player")
	var cloned := session_snapshot.duplicate(true)
	cloned["quote_id"] = "%s-clone" % str(cloned.get("quote_id", ""))
	_expect(not bool((pricing.call("restore_quote_from_session", cloned) as Dictionary).get("restored", true)), "private binding fingerprint rejects cloning a session under another quote ID")


func _test_purchase_session_binding() -> void:
	_reset_policy()
	coordinator.open_district_purchase_window(0, 0, {"supply_revision": "supply-session-a"})
	coordinator.acknowledge_district_purchase_selection(0, 0, "card.session", "supply-session-a")
	var quote: Dictionary = coordinator.card_market_quote(_listing(0, "card.session", "supply-session-a", 101, 0))
	_expect(not quote.is_empty() and str(coordinator.card_market_active_quote(0, 0).get("quote_id", "")) == str(quote.get("quote_id", "")), "selected listing attaches exactly one bound quote to the purchase session")
	coordinator.mark_district_supply_revision(0, 0, "supply-session-b")
	_expect(coordinator.card_market_active_quote(0, 0).is_empty(), "supply revision change clears the old session quote instead of live-repricing it")
	var mismatched := coordinator.get_node("DistrictPurchaseRuntimeController").call("attach_quote", 0, 0, quote) as Dictionary
	_expect(mismatched.is_empty(), "old supply-bound quote cannot attach to the revised session")


func _listing(district_index: int, card_id: String, supply_revision: String, base_price: int, player_index := 0) -> Dictionary:
	return {
		"player_index": player_index,
		"district_index": district_index,
		"card_id": card_id,
		"supply_revision": supply_revision,
		"base_price": base_price,
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


func _market_debug(runtime_coordinator: Node) -> Dictionary:
	var snapshot: Dictionary = runtime_coordinator.call("debug_snapshot") if runtime_coordinator != null else {}
	return (snapshot.get("card_market_pricing", {}) as Dictionary).duplicate(true) if snapshot.get("card_market_pricing", {}) is Dictionary else {}


func _find_card_slot(player: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _find_category_slot(player: Dictionary, category_id: String) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("category_id", "")) == category_id:
			return slot_index
	return -1


func _wait_frames(count: int) -> void:
	for _index in range(maxi(0, count)):
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("CARD_MARKET_POLICY_RUNTIME_BENCH: %s" % message)
