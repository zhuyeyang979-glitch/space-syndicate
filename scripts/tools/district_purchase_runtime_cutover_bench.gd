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
	await _test_real_main_hover_and_first_table()
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
	coordinator.bind_ai_world(_world)
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
	var applied: Dictionary = session.call("apply_save_data", {"game_session_runtime": {"schema_version": 1, "session_state": "running", "ruleset_id": "v0.4", "session_id": "clock-restore", "scenario_id": "first_table", "seed": 7, "setup": {}, "outcome_receipt": {}, "world_effective_us": 1234567}}) if session != null else {}
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


func _test_real_main_hover_and_first_table() -> void:
	var main := MAIN_SCENE.instantiate() as Control
	main.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	await _wait_frames(3)
	main.call("_start_scenario_from_menu", "first_table")
	await _wait_frames(4)
	var runtime_coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var fixture: Dictionary = runtime_coordinator.call("first_table_fixture_snapshot") if runtime_coordinator != null else {}
	var source_district := int(fixture.get("facility_market_source_district_index", -1))
	var availability: Dictionary = runtime_coordinator.call("card_market_listing_availability", source_district) if runtime_coordinator != null else {}
	var monsters: Object = runtime_coordinator.call("monster_runtime_controller") if runtime_coordinator != null and runtime_coordinator.has_method("monster_runtime_controller") else null
	var monster_snapshot: Dictionary = monsters.call("unit_card_snapshot_v06", "monster") if monsters != null and monsters.has_method("unit_card_snapshot_v06") else {}
	var district_rows: Array = main.get("districts") if main.get("districts") is Array else []
	var source_center: Variant = (district_rows[source_district] as Dictionary).get("center", Vector2.ZERO) if source_district >= 0 and source_district < district_rows.size() and district_rows[source_district] is Dictionary else Vector2.ZERO
	_diagnostics["first_table_source"] = {"map_seed": fixture.get("map_seed", -1), "source_district": source_district, "source_center": source_center, "availability": availability.duplicate(true)}
	_expect(int(fixture.get("map_seed", -1)) == 606120 and source_district == 5 and str(availability.get("availability_kind", "")) == "sunlit", "real first-table authored map seed and source district are deterministically sunlit at t=0")
	_expect(int(monster_snapshot.get("monster_count", -1)) == 0, "starting monster cards are held but summoning remains optional")
	main.call("_select_district", source_district)
	main.call("_open_district_supply_from_map", source_district)
	await _wait_frames(2)
	var choices: Array = (district_rows[source_district] as Dictionary).get("card_choices", []) if source_district >= 0 and source_district < district_rows.size() and district_rows[source_district] is Dictionary else []
	var ordinary_cards: Array[String] = []
	for value in choices:
		var card_id := str(value)
		if bool(main.call("_is_v06_facility_card_id", card_id)):
			continue
		ordinary_cards.append(card_id)
		if ordinary_cards.size() >= 2:
			break
	_expect(ordinary_cards.size() >= 2, "real district supply exposes two ordinary listings for hover/select routing")
	if ordinary_cards.size() >= 2:
		var first_card := ordinary_cards[0]
		var second_card := ordinary_cards[1]
		main.call("_on_district_supply_action_requested", "district_supply_preview_card", {"card_name": first_card, "source": "hover"})
		main.call("_on_district_supply_action_requested", "district_supply_preview_card", {"card_name": second_card, "source": "hover"})
		main.call("_refresh_district_supply_overlay")
		var after_hover := _market_debug(runtime_coordinator)
		_expect(int(after_hover.get("quote_count", -1)) == 0, "continuous real drawer hover and UI refresh create zero quotes")
		main.call("_on_district_supply_action_requested", "district_supply_preview_card", {"card_name": first_card, "source": "click_or_keyboard"})
		var first_active: Dictionary = runtime_coordinator.call("card_market_active_quote", 0, source_district)
		var after_select := _market_debug(runtime_coordinator)
		_expect(int(after_select.get("quote_count", -1)) == 1 and not str(first_active.get("quote_id", "")).is_empty(), "explicit real drawer selection creates exactly one quote")
		main.call("_on_district_supply_action_requested", "district_supply_preview_card", {"card_name": second_card, "source": "hover"})
		main.call("_refresh_district_supply_overlay")
		var after_other_hover := _market_debug(runtime_coordinator)
		var still_active: Dictionary = runtime_coordinator.call("card_market_active_quote", 0, source_district)
		_expect(int(after_other_hover.get("quote_count", -1)) == 1 and str(still_active.get("quote_id", "")) == str(first_active.get("quote_id", "")), "hovering another card never replaces or renews the stable selected quote")
		main.call("_on_district_supply_action_requested", "district_supply_preview_card", {"card_name": second_card, "source": "click_or_keyboard"})
		var second_active: Dictionary = runtime_coordinator.call("card_market_active_quote", 0, source_district)
		_expect(int(_market_debug(runtime_coordinator).get("quote_count", -1)) == 2 and str(second_active.get("quote_id", "")) != str(first_active.get("quote_id", "")), "explicitly selecting the other card replaces the session quote")
		var player_rows_before_purchase: Array = main.get("players") if main.get("players") is Array else []
		var player_before_purchase: Dictionary = (player_rows_before_purchase[0] as Dictionary).duplicate(true) if not player_rows_before_purchase.is_empty() and player_rows_before_purchase[0] is Dictionary else {}
		player_before_purchase["role_card"] = {}
		player_rows_before_purchase[0] = player_before_purchase
		main.set("players", player_rows_before_purchase)
		var cash_before_purchase := int(player_before_purchase.get("cash", 0))
		var purchase_count_before := int(player_before_purchase.get("card_purchase_count", 0))
		var ordinary_price := int(second_active.get("final_price", -1))
		var supply_revision_before := str((district_rows[source_district] as Dictionary).get("card_choices", []))
		var settlement_before: Dictionary = runtime_coordinator.call("district_purchase_settlement_debug")
		var inventory_before: Dictionary = runtime_coordinator.call("card_inventory_debug")
		var bought := bool(main.call("_buy_card_for_player_from_district", 0, source_district, second_card, true, true, -1, str(second_active.get("quote_id", ""))))
		var player_rows_after_purchase: Array = main.get("players") if main.get("players") is Array else []
		var player_after_purchase: Dictionary = (player_rows_after_purchase[0] as Dictionary).duplicate(true) if not player_rows_after_purchase.is_empty() and player_rows_after_purchase[0] is Dictionary else {}
		var settlement_after: Dictionary = runtime_coordinator.call("district_purchase_settlement_debug")
		var inventory_after: Dictionary = runtime_coordinator.call("card_inventory_debug")
		_diagnostics["ordinary_settlement"] = {
			"bought": bought,
			"quote_price": ordinary_price,
			"cash_before": cash_before_purchase,
			"cash_after": int(player_after_purchase.get("cash", 0)),
			"purchases_before": purchase_count_before,
			"purchases_after": int(player_after_purchase.get("card_purchase_count", 0)),
			"settlement_commits_before": int(settlement_before.get("committed_count", 0)),
			"settlement_commits_after": int(settlement_after.get("committed_count", 0)),
			"inventory_commits_before": int(inventory_before.get("committed_count", 0)),
			"inventory_commits_after": int(inventory_after.get("committed_count", 0)),
		}
		_expect(bought and cash_before_purchase - int(player_after_purchase.get("cash", 0)) == ordinary_price and int(player_after_purchase.get("card_purchase_count", 0)) == purchase_count_before + 1 and int(settlement_after.get("committed_count", 0)) == int(settlement_before.get("committed_count", 0)) + 1 and int(inventory_after.get("committed_count", 0)) == int(inventory_before.get("committed_count", 0)) + 1, "one real ordinary-card quote settles cash and inventory exactly once")
		var revised_district_rows: Array = (main.get("districts") as Array).duplicate(true)
		var revised_source: Dictionary = (revised_district_rows[source_district] as Dictionary).duplicate(true)
		var revised_choices: Array = (revised_source.get("card_choices", []) as Array).duplicate()
		revised_choices.reverse()
		revised_source["card_choices"] = revised_choices
		revised_district_rows[source_district] = revised_source
		main.set("districts", revised_district_rows)
		var supply_revision_after := str(revised_choices)
		runtime_coordinator.call("mark_district_supply_revision", 0, source_district, supply_revision_after)
		var player_before_replay: Dictionary = ((main.get("players") as Array)[0] as Dictionary).duplicate(true)
		var stale_replay := bool(main.call("_buy_card_for_player_from_district", 0, source_district, second_card, true, true, -1, str(second_active.get("quote_id", ""))))
		var player_after_replay: Dictionary = ((main.get("players") as Array)[0] as Dictionary).duplicate(true)
		_expect(supply_revision_before != supply_revision_after and not stale_replay and player_after_replay == player_before_replay and int((runtime_coordinator.call("district_purchase_settlement_debug") as Dictionary).get("committed_count", 0)) == int(settlement_after.get("committed_count", 0)), "a changed supply revision invalidates the locked quote with zero replay mutation")

	var before_pause := runtime_coordinator.call("world_effective_clock_snapshot") as Dictionary
	main.set("time_scale", 0.0)
	main.call("_process", 0.25)
	var after_pause := runtime_coordinator.call("world_effective_clock_snapshot") as Dictionary
	main.set("time_scale", 1.0)
	main.call("_process", 0.25)
	var after_market_tick := runtime_coordinator.call("world_effective_clock_snapshot") as Dictionary
	_expect(before_pause == after_pause, "true pause freezes world_effective time")
	_expect(int(after_market_tick.get("world_effective_us", 0)) > int(after_pause.get("world_effective_us", 0)), "an open market does not pause world_effective time")

	var market_surface: Dictionary = runtime_coordinator.call("v06_first_table_facility_market_snapshot", "player.0")
	var listing: Dictionary = market_surface.get("listing", {}) if market_surface.get("listing", {}) is Dictionary else {}
	var preview: Dictionary = market_surface.get("quote", {}) if market_surface.get("quote", {}) is Dictionary else {}
	_expect(bool(market_surface.get("ready", false)) and int(listing.get("source_district_index", -1)) == source_district and int(preview.get("multiplier_q2", -1)) == 2 and int(preview.get("final_price", -1)) == int(preview.get("base_price", -2)), "real first-table facility listing is explicit-source, sunlit and 1x with no summoned monster")
	var purchase: Dictionary = runtime_coordinator.call("purchase_v06_first_table_facility_card", "player.0", str(listing.get("item_id", "")), "card-market-policy:first-table-purchase")
	var player_after: Dictionary = runtime_coordinator.call("v06_card_player_snapshot", "player.0")
	var slot_index := _find_card_slot(player_after, str(purchase.get("card_id", "")))
	var region_id := str((district_rows[source_district] as Dictionary).get("region_id", "")) if source_district >= 0 and source_district < district_rows.size() and district_rows[source_district] is Dictionary else ""
	var infrastructure := runtime_coordinator.get_node_or_null("RegionInfrastructureRuntimeController")
	var facilities_before: Array = infrastructure.call("facilities_snapshot", false) if infrastructure != null else []
	var play: Dictionary = runtime_coordinator.call("play_v06_runtime_card", {"actor_id": "player.0", "slot_index": slot_index, "transaction_id": "card-market-policy:first-table-play", "region_id": region_id, "game_time": float(main.get("game_time"))}) if bool(purchase.get("committed", false)) and slot_index >= 0 and not region_id.is_empty() else {}
	var facilities_after: Array = infrastructure.call("facilities_snapshot", false) if infrastructure != null else []
	_expect(bool(purchase.get("committed", false)) and bool(play.get("committed", false)) and facilities_after.size() == facilities_before.size() + 1, "human can delay summoning, buy through the shared quote authority and progress the facility economy")
	var flow: Object = runtime_coordinator.call("commodity_flow_runtime_controller") if runtime_coordinator.has_method("commodity_flow_runtime_controller") else null
	var receipts_before: Array = flow.call("recent_sale_receipts_snapshot", 0) if flow != null else []
	var card_player_before_income: Dictionary = runtime_coordinator.call("v06_card_player_snapshot", "player.0")
	var cash_before_income := int(card_player_before_income.get("cash", 0))
	var produced_receipts := 0
	for _second in range(12):
		var tick_variant: Variant = flow.call("advance_world", 1.0, {}) if flow != null else {}
		var tick: Dictionary = tick_variant if tick_variant is Dictionary else {}
		produced_receipts += int(tick.get("receipt_count", 0))
		if produced_receipts > 0:
			break
	var receipts_after: Array = flow.call("recent_sale_receipts_snapshot", 0) if flow != null else []
	var card_player_after_income: Dictionary = runtime_coordinator.call("v06_card_player_snapshot", "player.0")
	var cash_after_income := int(card_player_after_income.get("cash", 0))
	_expect(produced_receipts == 1 and receipts_after.size() == receipts_before.size() + 1 and cash_after_income > cash_before_income, "the delayed-summon facility produces one real Sale Receipt and positive income")
	var followup_surface: Dictionary = runtime_coordinator.call("v06_first_table_facility_market_snapshot", "player.0")
	var followup_listing: Dictionary = followup_surface.get("listing", {}) if followup_surface.get("listing", {}) is Dictionary else {}
	var followup_purchase: Dictionary = runtime_coordinator.call("purchase_v06_first_table_facility_card", "player.0", str(followup_listing.get("item_id", "")), "card-market-policy:first-table-followup-purchase")
	_expect(bool(followup_purchase.get("committed", false)), "facility income can be followed by a second market purchase while the starter monster remains unsummoned")
	var card_player_before_summon: Dictionary = runtime_coordinator.call("v06_card_player_snapshot", "player.0")
	var starter_slot := _find_category_slot(card_player_before_summon, "monster")
	var monsters_before_summon: Dictionary = monsters.call("unit_card_snapshot_v06", "monster") if monsters != null else {}
	var summon: Dictionary = runtime_coordinator.call("play_v06_runtime_card", {"actor_id": "player.0", "slot_index": starter_slot, "transaction_id": "card-market-policy:voluntary-starter-summon", "region_id": region_id, "game_time": float(main.get("game_time"))}) if starter_slot >= 0 and not region_id.is_empty() else {}
	var monsters_after_summon: Dictionary = monsters.call("unit_card_snapshot_v06", "monster") if monsters != null else {}
	_expect(bool(summon.get("committed", false)) and int(monsters_after_summon.get("monster_count", 0)) == int(monsters_before_summon.get("monster_count", 0)) + 1, "the held starter monster remains legally summonable as a voluntary later action")
	_diagnostics["first_table_economy"] = {
		"source_district": source_district,
		"facility_purchase_committed": bool(purchase.get("committed", false)),
		"facility_play_committed": bool(play.get("committed", false)),
		"facilities_before": facilities_before.size(),
		"facilities_after": facilities_after.size(),
		"sale_receipt_delta": receipts_after.size() - receipts_before.size(),
		"income_cash_delta": cash_after_income - cash_before_income,
		"followup_purchase_committed": bool(followup_purchase.get("committed", false)),
		"starter_slot": starter_slot,
		"summon_reason": str(summon.get("reason_code", summon.get("reason", ""))),
		"summon_committed": bool(summon.get("committed", false)),
	}
	main.queue_free()
	await _wait_frames(3)


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
