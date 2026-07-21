extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/district_supply_action_port_cutover.save"

var _passed := 0
var _failed := 0


func _init() -> void:
	var coordinator_scene := load("res://scenes/runtime/GameRuntimeCoordinator.tscn") as PackedScene
	var root := coordinator_scene.instantiate() as GameRuntimeCoordinator
	get_root().add_child(root)
	await process_frame
	var port := root.get_node_or_null("DistrictSupplyActionPort") as DistrictSupplyActionPort
	_expect(port != null, "production coordinator contains one DistrictSupplyActionPort")
	_expect(root.find_children("DistrictSupplyActionPort", "DistrictSupplyActionPort", true, false).size() == 1, "production composition has one action port")
	_expect(port != null and bool(port.debug_snapshot().get("scene_owned", false)), "action port is scene owned")
	_expect(port != null and not bool(port.debug_snapshot().get("owns_region_supply", true)), "action port does not own the rack")
	_expect(port != null and not bool(port.debug_snapshot().get("owns_inventory", true)), "action port does not own inventory")
	_expect(port != null and not bool(port.debug_snapshot().get("owns_cash", true)), "action port does not own cash")
	if port != null:
		for request_index in range(42):
			port.call("_remember_request", "bounded-journal-%d" % request_index, "fingerprint-%d" % request_index)
		var bounded_debug := port.debug_snapshot()
		_expect(
			int(bounded_debug.get("journal_size", -1)) <= int(bounded_debug.get("journal_limit", -2))
			and int(bounded_debug.get("journal_limit", -1)) == 14,
			"action exact-once journal is a bounded FIFO instead of unbounded session state"
		)
	var world := root.get_node_or_null("WorldSessionState") as WorldSessionState
	if world != null and port != null:
		world.districts = [{"region_id": "region.042", "name": "QA区域", "destroyed": false, "products": [], "demands": []}]
		_expect(str(port.call("_region_id", 0)) == "region.042", "district index resolves through the authoritative region_id instead of its numeric string")
		var configured: Dictionary = root.configure_region_supply(
			4242,
			[{"region_id": "region.042", "region_index": 0, "display_name": "QA区域", "terrain": "land", "active": true}],
			[{"card_id": "qa.region.card", "family_id": "qa.region.card", "card_type": "strategy", "rank": "I", "price_cash": 37, "valid": true}],
			1
		)
		var listing: Dictionary = root.region_supply_listing("region.042", "qa.region.card")
		_expect(bool(configured.get("configured", false)) and not listing.is_empty(), "typed port resolves a real authoritative rack listing through region_id")
		_expect(int(listing.get("price_cash", -1)) == 37, "authoritative listing preserves the quoted cash price")
		_expect(bool(port.call("_listing_exists", 0, "qa.region.card")), "numeric district action reaches the authoritative region listing")
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	for retired in [
		"func _open_district_supply_from_map", "func _close_district_supply_overlay", "func _preview_district_card",
		"func _select_district_card_for_quote", "func _on_district_supply_action_requested",
		"func _open_district_card_purchase_window", "func _buy_card_for_player_from_district",
		"func _claim_district_card", "func _cancel_discard_purchase", "func _confirm_discard_purchase",
		"func _grant_role_bonus_card_on_purchase", "func _preview_v06_facility_card",
	]:
		_expect(not main_source.contains(retired), "Main retired %s" % retired)
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(not ai_source.contains("_call_world(&\"_buy_card_for_player_from_district\""), "AI purchase no longer calls Main world bridge")
	_expect(ai_source.contains("_district_supply_action_port.submit_ai_purchase"), "AI and human purchase share the typed port")
	_expect(not ai_source.contains("_call_world(&\"_district_or_city_has_product\""), "AI role-product evaluation no longer depends on the retired Main helper")
	for retired_side_market in [
		"AiV06EconomyActionPort", "ai_v06_economy_action_port", "execute_v06_facility_bootstrap_cycle",
		"v06_facility_market_snapshot", "purchase_v06_facility_card", "execute_v06_facility_purchase_action",
	]:
		_expect(
			not ai_source.contains(retired_side_market) and not coordinator_source.contains(retired_side_market),
			"facility side-market path is physically retired: %s" % retired_side_market
		)
	_expect(not FileAccess.file_exists("res://scripts/runtime/ai_v06_economy_action_port.gd"), "retired AI facility side-market port is deleted")
	var port_source := FileAccess.get_file_as_string("res://scripts/runtime/district_supply_action_port.gd")
	_expect(not port_source.contains("refresh_v06_facility_quote") and not port_source.contains("execute_v06_facility_purchase_action"), "all regional purchases require the unified authoritative rack instead of a facility side market")
	_expect(port_source.contains("purchase_region_supply_card") and port_source.contains("CommodityCardInventoryRuntimeController"), "district purchases use the production CommodityCardInventory/CardFlow owner")
	_expect(not port_source.contains("CardInventoryRuntimeService") and not port_source.contains("commit_district_purchase_with_region_supply"), "district action port cannot use the retired duplicate inventory settlement path")
	_expect(port_source.contains("_grant_role_bonus_card"), "role bonus receive remains on the typed inventory owner path")
	_expect(port_source.contains("listing.get(\"price_cash\""), "quotes use the authoritative rack price")
	_expect(port_source.contains("locked_quote_required") and port_source.contains("locked_quote_changed"), "human purchase consumes the previously locked quote without silently renewing it")
	_expect(port_source.contains("session_is_finished") and port_source.contains("get(\"is_ai\""), "terminal sessions and non-AI seats cannot use the AI purchase entry")
	_expect(not FileAccess.get_file_as_string("res://scripts/runtime/district_supply_action_intent.gd").contains("var anonymous"), "human intents cannot forge the trusted AI purchase path")
	_expect(port_source.contains("lock_quote and _coordinator().session_is_finished()"), "finished sessions cannot create a fresh purchase quote")
	_expect(port_source.contains("current_runtime_simulation_step_index") and port_source.contains("_remember_request(normalized_request_id, fingerprint)"), "trusted AI purchases use a stable simulation-step request identity and bounded exact-once journal")
	var receipt_source := FileAccess.get_file_as_string("res://scripts/runtime/district_supply_action_receipt.gd")
	_expect(receipt_source.contains("viewer_private") and receipt_source.contains("public_summary"), "private action receipt exposes an explicitly redacted public projection")
	var private_receipt := DistrictSupplyActionReceipt.new()
	private_receipt.reason_code = "hand_limit_requires_discard"
	private_receipt.requires_discard = true
	private_receipt.actor_player_index = 2
	private_receipt.card_id = "PRIVATE_CARD"
	private_receipt.quote_id = "PRIVATE_QUOTE"
	var public_receipt_text := JSON.stringify(private_receipt.public_summary())
	_expect(not public_receipt_text.contains("hand_limit") and not public_receipt_text.contains("requires_discard") and not public_receipt_text.contains("PRIVATE_"), "public receipt hides hand pressure, card, actor and quote details")
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(screen_source.contains("signal district_supply_action_intent_requested"), "GameScreen exposes typed district intent signal")
	_expect(screen_source.contains("district_double_clicked"), "double click is bound by GameScreen")
	root.queue_free()
	await process_frame
	await _check_ai_purchase_exact_once()
	print("DISTRICT_SUPPLY_ACTION_PORT_CUTOVER %d/%d" % [_passed, _passed + _failed])
	quit(0 if _failed == 0 else 1)


func _check_ai_purchase_exact_once() -> void:
	var start: Dictionary = await SESSION_DRIVER.start_configured_session(
		self,
		{
			"player_count": 3,
			"ai_player_count": 2,
			"challenge_depth": 1,
			"role_indices": [0, 1, 2],
			"starter_monster_indices": [0, 1, 2],
		},
		QA_SAVE_PATH,
		"district-supply-action-exact-once"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start.get("started", false)) and coordinator != null, "AI exact-once check starts a real production session")
	if coordinator == null:
		return
	var action := coordinator.district_supply_action_port()
	var query := coordinator.district_supply_runtime_query_port()
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var player_index := -1
	for seat_index in range(world.players.size() if world != null else 0):
		var seat := world.players[seat_index] as Dictionary
		if bool(seat.get("is_ai", false)):
			player_index = seat_index
			break
	var district_rows := world.districts if world != null and world.districts is Array else []
	var injected_cards: Array = []
	if coordinator != null and district_rows.size() > 0:
		for card_id_variant in coordinator.region_supply_catalog_card_ids():
			var card_id := str(card_id_variant).strip_edges()
			if card_id.is_empty():
				continue
			injected_cards.append(card_id)
			if injected_cards.size() >= 8:
				break
		var reroll := coordinator.configure_region_supply_from_world(4242, district_rows, injected_cards, 4)
		_expect(bool(reroll.get("configured", false)), "AI test injects deterministic rank-I rack candidates for exact-once scenario")
		_expect(_all_public_rack_cards_use_v06_ids(coordinator), "every public rack listing resolves in the production v0.6 inventory catalog")
		await process_frame
	coordinator.pause_session()
	await process_frame
	var public_rack_diagnostics := _public_rack_diagnostics(query, world)
	var candidate := _first_purchasable_listing(query, world, ai, player_index)
	_expect(action != null and query != null and world != null and ai != null and player_index >= 0 and not candidate.is_empty(), "real AI purchase candidate is available through public rack facts: %s" % JSON.stringify(public_rack_diagnostics))
	if action != null and world != null and ai != null and player_index >= 0 and not candidate.is_empty():
		var player: Dictionary = (world.players[player_index] as Dictionary).duplicate(true)
		player["cash"] = maxi(100000, int(player.get("cash", 0)))
		world.players[player_index] = player
		var district_index := int(candidate.get("district_index", -1))
		var card_id := str(candidate.get("card_id", ""))
		var discard_slot := int(candidate.get("discard_slot", -1))
		print("DISTRICT_SUPPLY_AI_CANDIDATE card=%s preview=%s" % [card_id, JSON.stringify((coordinator.get_node_or_null("CommodityCardInventoryRuntimeController") as CommodityCardInventoryRuntimeController).region_supply_receive_preview("player.1", card_id))])
		var request_id := "qa-ai-district-purchase-exact-once"
		var before := action.debug_snapshot()
		var first := action.submit_ai_purchase(player_index, district_index, card_id, discard_slot, request_id)
		var after_first := action.debug_snapshot()
		var cash_after_first := int((world.players[player_index] as Dictionary).get("cash", -1))
		var second := action.submit_ai_purchase(player_index, district_index, card_id, discard_slot, request_id)
		var after_second := action.debug_snapshot()
		var cash_after_second := int((world.players[player_index] as Dictionary).get("cash", -2))
		_expect(first and not second, "same AI request identity can commit only once (first=%s)" % str(after_first.get("last_reason_code", "")))
		_expect(
			int(after_first.get("purchase_commit_count", -1)) == int(before.get("purchase_commit_count", 0)) + 1
			and int(after_second.get("purchase_commit_count", -1)) == int(after_first.get("purchase_commit_count", -2)),
			"AI replay does not duplicate the purchase commit"
		)
		_expect(cash_after_second == cash_after_first and int(after_second.get("replay_count", 0)) == int(after_first.get("replay_count", 0)) + 1, "AI replay does not debit cash twice and is audited")
		var collision := action.submit_ai_purchase(player_index, district_index, "%s-collision" % card_id, discard_slot, request_id)
		var after_collision := action.debug_snapshot()
		_expect(not collision and int(after_collision.get("collision_count", 0)) == int(after_second.get("collision_count", 0)) + 1, "same request identity with a different fingerprint is rejected as a collision")
	if app_root != null:
		app_root.queue_free()
	await process_frame


func _first_purchasable_listing(query: DistrictSupplyRuntimeQueryPort, world: WorldSessionState, ai: AiRuntimeController, player_index: int) -> Dictionary:
	if query == null or world == null or ai == null:
		return {}

	# 1) 先按公开抽牌架快照检索（严格生产查询路径）。
	for district_index in range(world.districts.size()):
		if not query.public_market_purchasable(district_index):
			continue
		var ids := query.public_card_ids_for_district(district_index)
		for card_variant in ids:
			var card_id := str(card_variant).strip_edges()
			if card_id.is_empty():
				continue
			if not bool(ai.call("_player_can_receive_card_with_discard", player_index, card_id)):
				continue
			var discard_slot := -1
			if bool(ai.call("_purchase_requires_discard", player_index, card_id)):
				discard_slot = int(ai.call("_ai_discard_slot_for_purchase", player_index, card_id))
				if discard_slot < 0:
					continue
			return {"district_index": district_index, "card_id": card_id, "discard_slot": discard_slot}

	return {}


func _all_public_rack_cards_use_v06_ids(coordinator: GameRuntimeCoordinator) -> bool:
	var snapshot := coordinator.region_supply_public_rack()
	for row_variant in snapshot.get("regions", []) as Array:
		if not (row_variant is Dictionary):
			return false
		for listing_variant in (row_variant as Dictionary).get("slots", []) as Array:
			if not (listing_variant is Dictionary):
				return false
			var card_id := str((listing_variant as Dictionary).get("card_id", "")).strip_edges()
			if card_id.is_empty() or coordinator.v06_card_definition(card_id).is_empty():
				return false
	return true


func _public_rack_diagnostics(query: DistrictSupplyRuntimeQueryPort, world: WorldSessionState) -> Array:
	var rows: Array = []
	if query == null or world == null:
		return rows
	for district_index in range(world.districts.size()):
		var availability := query.public_market_availability(district_index)
		rows.append({
			"district_index": district_index,
			"availability_kind": str(availability.get("availability_kind", "")),
			"reason_code": str(availability.get("reason_code", "")),
			"purchasable": bool(availability.get("purchasable", false)),
			"card_ids": query.public_card_ids_for_district(district_index),
		})
	return rows


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		_failed += 1
		push_error("FAIL: %s" % label)
