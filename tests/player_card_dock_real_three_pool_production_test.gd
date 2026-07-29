extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const CLAIM_REQUEST := preload("res://scripts/runtime/commodity_sushi_track_claim_request.gd")

const QA_SAVE_PATH := "user://test_runs/player_card_dock_real_three_pool_production.save"
const REAL_MILITARY_CARD_ID := "unit.military.planetary_defense_force.rank_1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 960)
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
		"player-card-dock-real-three-pool-production"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start.get("started", false)) and app_root != null and coordinator != null, "real production session starts")
	if app_root == null or coordinator == null:
		_finish()
		return
	coordinator.pause_session()
	await process_frame

	var screen := app_root.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var dock := screen.find_child("PlayerCardDock", true, false) as SpaceSyndicatePlayerCardDock if screen != null else null
	var dock_query := coordinator.get_node_or_null("PlayerCardDockViewerQueryPort") as PlayerCardDockViewerQueryPort
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var sushi_service := coordinator.get_node_or_null("CommoditySushiTrackRuntimeService")
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var rng := coordinator.run_rng_service()
	_expect(screen != null and dock != null and dock_query != null and query_ports != null \
		and sushi_service != null and inventory != null and rng != null, "production three-pool source, query and target composition exists")
	if screen == null or dock == null or dock_query == null or query_ports == null \
			or sushi_service == null or inventory == null or rng == null:
		await _cleanup(app_root)
		_finish()
		return

	var context := query_ports.viewer_context()
	var actor_binding := coordinator.actor_id_for_player_index(0)
	var actor_id := str(actor_binding.get("actor_id", ""))
	var before := dock_query.snapshot_for_viewer(0, context.authorization_revision)
	var before_normal := (before.get("normal_cards", []) as Array).size()
	_expect(bool(actor_binding.get("available", false)) and not actor_id.is_empty(), "human player resolves to one authoritative card actor")
	_expect(before_normal >= 1, "real production authority projects at least one normal starting card")
	var query_debug_before_refresh := dock_query.debug_snapshot()
	coordinator.request_table_presentation_refresh(&"full", &"alpha04_normal_pool_proof")
	await process_frame
	await process_frame
	var query_debug_after_refresh := dock_query.debug_snapshot()
	_expect(
		int(query_debug_after_refresh.get("composed_bundle_count", 0)) \
			== int(query_debug_before_refresh.get("composed_bundle_count", 0)) + 1 \
			and int(query_debug_after_refresh.get("standalone_compose_count", 0)) \
			== int(query_debug_before_refresh.get("standalone_compose_count", 0)),
		"one production refresh reuses its composed hand bundle without a second CardPresentation pass"
	)
	var initial_normal_visible := _pool_visible_count(dock, "NormalHandCards")
	_expect(initial_normal_visible >= 1, "real normal card is visible in the production Dock before it is played")

	var bound_gate: Dictionary = await _characterize_real_bound_action_blocker(
		coordinator,
		screen,
		dock_query,
		context.authorization_revision
	)
	var before_commodity := (bound_gate.get("commodity_cards", []) as Array).size()
	var before_bound := (bound_gate.get("bound_actions", []) as Array).size()
	var before_normal_after_bound := (bound_gate.get("normal_cards", []) as Array).size()
	_expect(before_bound == 0, "production bound-action pool remains honestly empty while no supported acquisition route exists")
	_expect(str(bound_gate.get("capacity_mode", "")) == PlayerCardDockProjectionV1.CAPACITY_MODE_SHARED_V06 \
		and int(bound_gate.get("shared_capacity_count", -1)) == before_normal_after_bound + before_commodity, "production Dock truthfully reports V0.6 shared capacity while bound actions cost zero")

	var public_snapshot: CommoditySushiTrackSnapshot = sushi_service.public_snapshot(0)
	_expect(public_snapshot != null and public_snapshot.is_valid() and not public_snapshot.items.is_empty(), "real shared commodity track exposes one legal local claim candidate")
	if public_snapshot == null or public_snapshot.items.is_empty():
		await _cleanup(app_root)
		_finish()
		return
	var item: CommoditySushiTrackItemSnapshot = public_snapshot.items[0]
	_expect(not item.illustration_key.is_empty(), "real source commodity carries its catalog illustration key")
	var request: CLAIM_REQUEST = CLAIM_REQUEST.new()
	request.viewer_index = 0
	request.commodity_slot_id = item.commodity_slot_id
	request.commodity_card_id = item.commodity_card_id
	request.snapshot_revision = public_snapshot.snapshot_revision
	request.belt_revision = public_snapshot.belt_revision
	request.visibility_revision = public_snapshot.visibility_revision
	request.request_revision = 1
	var rng_before := JSON.stringify(rng.debug_snapshot())
	var owner_before := inventory.player_snapshot(actor_id)
	var claim: Dictionary = sushi_service.claim(request)
	_expect(bool(claim.get("success", false)), "typed real-track claim commits through the authoritative commodity inventory")
	var owner_after := inventory.player_snapshot(actor_id)
	var after := dock_query.snapshot_for_viewer(0, context.authorization_revision)
	_expect((after.get("commodity_cards", []) as Array).size() == before_commodity + 1, "claimed commodity enters the typed commodity pool exactly once")
	_expect((after.get("normal_cards", []) as Array).size() == before_normal_after_bound \
		and (after.get("bound_actions", []) as Array).size() == before_bound, "commodity claim changes neither normal cards nor bound actions")
	_expect(JSON.stringify(rng.debug_snapshot()) == rng_before, "presentation and free commodity claim consume no new RNG")
	_expect(int(owner_after.get("cash", -1)) == int(owner_before.get("cash", -2)), "free commodity claim changes no authoritative cash")

	coordinator.request_table_presentation_refresh(&"full", &"alpha04_three_pool_proof")
	await process_frame
	await process_frame
	var ui_dock: Dictionary = screen.current_ui_data.get("player_card_dock", {}) \
		if screen.current_ui_data.get("player_card_dock", {}) is Dictionary else {}
	var target_debug := dock.debug_snapshot()
	_expect(PlayerCardDockProjectionV1.matches_viewer_authorization(ui_dock, 0, context.authorization_revision), "production GameScreen receives the same viewer-authorized typed Dock projection")
	_expect(int(target_debug.get("normal_card_count", -1)) == (after.get("normal_cards", []) as Array).size() \
		and int(target_debug.get("commodity_card_count", -1)) == (after.get("commodity_cards", []) as Array).size() \
		and int(target_debug.get("bound_action_count", -1)) == (after.get("bound_actions", []) as Array).size(), "one production target renders all three authoritative pool counts")
	_expect(_pool_visible_count(dock, "NormalHandCards") >= 1 \
		and _pool_visible_count(dock, "CommodityCards") >= 1 \
		and _pool_visible_count(dock, "BoundActionCards") == 0, "the two reachable real pools are visible while the blocked bound pool renders no fabricated card")
	_expect(
		_pool_authored_art_count(dock, "CommodityCards") >= 1,
		"owned commodity renders the same authored catalog art through CardFace"
	)

	var replay: Dictionary = sushi_service.claim(request)
	var after_replay := dock_query.snapshot_for_viewer(0, context.authorization_revision)
	_expect(bool(replay.get("success", false)) and bool(replay.get("idempotent_replay", false)) \
		and str(replay.get("request_status_code", "")) == "request_duplicate" \
		and (after_replay.get("commodity_cards", []) as Array).size() == (after.get("commodity_cards", []) as Array).size(), "duplicate claim replays without a second commodity or target apply")
	_expect(dock_query.snapshot_for_viewer(1, context.authorization_revision).is_empty(), "another viewer cannot query the human player's three private pools")
	_expect(not JSON.stringify(after).contains("future_track_sequence") \
		and not JSON.stringify(after).contains("rival_cash") \
		and not JSON.stringify(after).contains("hidden_owner"), "three-pool projection contains no future track, rival cash, or hidden owner data")

	await _cleanup(app_root)
	_finish()


func _pool_visible_count(dock: Node, host_name: String) -> int:
	var host := dock.find_child(host_name, true, false)
	if host == null:
		return 0
	var count := 0
	for child in host.get_children():
		if child is Control and (child as Control).visible:
			count += 1
	return count


func _pool_authored_art_count(dock: Node, host_name: String) -> int:
	var host := dock.find_child(host_name, true, false) if dock != null else null
	if host == null:
		return 0
	var count := 0
	for child in host.get_children():
		if child is Control and bool(child.get_meta("external_illustration_active", false)) \
				and bool(child.get_meta("authored_illustration_active", false)):
			count += 1
	return count


func _characterize_real_bound_action_blocker(
	coordinator: GameRuntimeCoordinator,
	screen: SpaceSyndicateGameScreen,
	dock_query: PlayerCardDockViewerQueryPort,
	authorization_revision: int
) -> Dictionary:
	var mana_save := coordinator.player_mana_to_save_data()
	var pools_by_player: Dictionary = (mana_save.get("pools_by_player", {}) as Dictionary).duplicate(true) \
		if mana_save.get("pools_by_player", {}) is Dictionary else {}
	var human_pool: Dictionary = (pools_by_player.get("0", {}) as Dictionary).duplicate(true) \
		if pools_by_player.get("0", {}) is Dictionary else {}
	for asset_id in PlayerManaRuntimeController.ASSET_IDS:
		human_pool[str(asset_id)] = 100 * PlayerManaRuntimeController.MILLIASSET_SCALE
	pools_by_player["0"] = human_pool
	mana_save["pools_by_player"] = pools_by_player
	var funded := coordinator.apply_player_mana_save_data(mana_save)
	_expect(bool(funded.get("applied", false)), "production asset owner accepts deterministic test funding for the real starter card")
	if not bool(funded.get("applied", false)):
		return dock_query.snapshot_for_viewer(0, authorization_revision)

	coordinator.request_table_presentation_refresh(&"full", &"alpha04_real_monster_offer")
	await process_frame
	await process_frame
	var funded_projection := dock_query.snapshot_for_viewer(0, authorization_revision)
	var monster_offer := _first_available_monster_offer(funded_projection)
	_expect(not monster_offer.is_empty(), "funded real starter monster exposes one available typed GameActionOffer")
	if monster_offer.is_empty():
		return funded_projection

	var submitted := screen.submit_game_action_offer(monster_offer, "human_click", {}, {})
	_expect(submitted, "real starter monster submits through GameScreen and the typed Action Spine")
	if not submitted:
		return funded_projection

	await process_frame
	var monster_receipt: Dictionary = coordinator.card_play_submission_controller().debug_snapshot().get("last_receipt", {}) \
		if coordinator.card_play_submission_controller().debug_snapshot().get("last_receipt", {}) is Dictionary else {}
	_expect(bool(monster_receipt.get("accepted", false)) \
		and int(coordinator.monster_runtime_controller().debug_snapshot().get("active_monster_count", 0)) == 1, "real starter monster completes through its authoritative atomic owner")

	var military_bought := await _purchase_real_rack_card(
		coordinator,
		screen,
		REAL_MILITARY_CARD_ID,
		authorization_revision,
		904_041
	)
	_expect(military_bought, "real regional rack purchase acquires one shipped military card through typed quote and purchase intents")
	var military_projection := dock_query.snapshot_for_viewer(0, authorization_revision)
	var military_offer := _first_available_offer_for_card(military_projection, REAL_MILITARY_CARD_ID)
	_expect(not military_offer.is_empty(), "current projection exposes the shipped military card offer for route characterization")
	var military_submitted := not military_offer.is_empty() \
		and screen.submit_game_action_offer(military_offer, "human_click", {}, {})
	await process_frame
	await process_frame
	var submission_debug := coordinator.card_play_submission_controller().debug_snapshot()
	var receipt: Dictionary = submission_debug.get("last_receipt", {}) \
		if submission_debug.get("last_receipt", {}) is Dictionary else {}
	var v06_receipt: Dictionary = receipt.get("v06_receipt", {}) if receipt.get("v06_receipt", {}) is Dictionary else {}
	_expect(military_submitted and not bool(receipt.get("accepted", true)) \
		and str(v06_receipt.get("reason_code", "")) == "v06_card_effect_route_unavailable", "production military card fails closed at the missing typed V0.6 effect route")
	coordinator.request_table_presentation_refresh(&"full", &"alpha04_bound_action_route_blocked")
	await process_frame
	await process_frame
	var latest := dock_query.snapshot_for_viewer(0, authorization_revision)
	_expect((latest.get("bound_actions", []) as Array).is_empty() \
		and _inventory_contains_card(coordinator.v06_card_player_snapshot("player.0"), REAL_MILITARY_CARD_ID), "rejected route creates no bound action and preserves the real military card")
	return latest


func _first_available_monster_offer(projection: Dictionary) -> Dictionary:
	for card_variant in projection.get("normal_cards", []) as Array:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if not str(card.get("card_semantic_id", "")).begins_with("unit.monster.") \
				or str(card.get("play_state", "")) != "available":
			continue
		var offer: Variant = card.get("game_action_offer", {})
		if offer is Dictionary and bool(GameActionOfferV1.validation_report(offer).get("valid", false)):
			return (offer as Dictionary).duplicate(true)
	return {}


func _first_available_offer_for_card(projection: Dictionary, card_semantic_id: String) -> Dictionary:
	for card_variant in projection.get("normal_cards", []) as Array:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if str(card.get("card_semantic_id", "")) != card_semantic_id \
				or str(card.get("play_state", "")) != "available":
			continue
		var offer: Variant = card.get("game_action_offer", {})
		if offer is Dictionary and bool(GameActionOfferV1.validation_report(offer).get("valid", false)):
			return (offer as Dictionary).duplicate(true)
	return {}


func _purchase_real_rack_card(
	coordinator: GameRuntimeCoordinator,
	screen: SpaceSyndicateGameScreen,
	card_id: String,
	authorization_revision: int,
	seed_value: int
) -> bool:
	var world := coordinator.world_session_state()
	var viewmodel_query := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	var port := coordinator.district_supply_action_port()
	var popup := screen.get_region_supply_popup() as SpaceSyndicateRegionSupplyPopup
	if world == null or viewmodel_query == null or port == null or popup == null:
		return false
	var configured := coordinator.configure_region_supply_from_world(
		seed_value,
		world.districts,
		[card_id],
		1
	)
	if not bool(configured.get("configured", false)):
		return false
	var district_index := -1
	for index in range(world.districts.size()):
		var district: Dictionary = world.districts[index] if world.districts[index] is Dictionary else {}
		var region_id := str(district.get("region_id", ""))
		if not coordinator.region_supply_listing(region_id, card_id).is_empty() \
				and bool(coordinator.card_market_listing_availability(index).get("purchasable", false)):
			district_index = index
			break
	if district_index < 0:
		return false
	var human := (world.players[0] as Dictionary).duplicate(true)
	human["cash"] = maxi(100_000, int(human.get("cash", 0)))
	human["action_cooldown"] = 0.0
	world.players[0] = human
	var identity := coordinator.get_node_or_null("PlayerIdentityAuthorizationBoundary") as PlayerIdentityAuthorizationBoundary
	var actor_context := identity.current_actor_context(&"game_screen") if identity != null else null
	screen.bind_presentation_viewer(0, authorization_revision)
	screen.bind_gameplay_actor_authorization_context(actor_context)
	if actor_context == null or not actor_context.is_valid() \
			or not screen.request_district_selection(district_index, &"qa_driver"):
		return false
	var receipts: Array[DistrictSupplyActionReceipt] = []
	var capture_receipt := func(receipt: DistrictSupplyActionReceipt) -> void:
		receipts.append(receipt)
	port.receipt_ready.connect(capture_receipt)
	var before_inventory := coordinator.v06_card_player_snapshot("player.0")
	var before_count := _authoritative_inventory_count(before_inventory)
	coordinator.request_table_presentation_refresh(&"full", &"player_card_dock_real_three_pool_open_sync")
	await process_frame
	if not screen.request_district_supply_open(district_index, &"qa_driver"):
		if port.receipt_ready.is_connected(capture_receipt):
			port.receipt_ready.disconnect(capture_receipt)
		return false
	await process_frame
	var quote_state := viewmodel_query.compose_table_state(0, true)
	var quote_projection: Dictionary = quote_state.get("region_supply_popup", {}) \
		if quote_state.get("region_supply_popup", {}) is Dictionary else {}
	if quote_projection.is_empty() or not popup.apply_projection(quote_projection):
		if port.receipt_ready.is_connected(capture_receipt):
			port.receipt_ready.disconnect(capture_receipt)
		return false
	var quote_offer := popup.action_offer_for_card(
		card_id,
		GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE
	)
	if quote_offer.is_empty() or not screen.submit_game_action_offer(
		quote_offer,
		"human_click",
		{},
		{}
	):
		if port.receipt_ready.is_connected(capture_receipt):
			port.receipt_ready.disconnect(capture_receipt)
		return false
	await process_frame
	var purchase_state := viewmodel_query.compose_table_state(0, true)
	var purchase_projection: Dictionary = purchase_state.get("region_supply_popup", {}) \
		if purchase_state.get("region_supply_popup", {}) is Dictionary else {}
	if purchase_projection.is_empty() or not popup.apply_projection(purchase_projection):
		if port.receipt_ready.is_connected(capture_receipt):
			port.receipt_ready.disconnect(capture_receipt)
		return false
	var purchase_offer := popup.action_offer_for_card(
		card_id,
		GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE
	)
	if purchase_offer.is_empty() or not screen.submit_game_action_offer(
		purchase_offer,
		"human_click",
		{},
		{}
	):
		if port.receipt_ready.is_connected(capture_receipt):
			port.receipt_ready.disconnect(capture_receipt)
		return false
	await process_frame
	if port.receipt_ready.is_connected(capture_receipt):
		port.receipt_ready.disconnect(capture_receipt)
	var after_inventory := coordinator.v06_card_player_snapshot("player.0")
	var purchase_receipt_seen := false
	for receipt_variant in receipts:
		if not (receipt_variant is DistrictSupplyActionReceipt):
			continue
		var receipt := receipt_variant as DistrictSupplyActionReceipt
		if receipt.accepted and receipt.applied and receipt.reason_code == "purchase_committed":
			purchase_receipt_seen = true
			break
	var purchased := _authoritative_inventory_count(after_inventory) == before_count + 1 \
		and _inventory_contains_card(after_inventory, card_id) \
		and purchase_receipt_seen
	return purchased


func _authoritative_inventory_count(snapshot: Dictionary) -> int:
	var inventory: Dictionary = snapshot.get("inventory", {}) if snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and not (slot_variant as Dictionary).is_empty():
			count += 1
	return count


func _inventory_contains_card(snapshot: Dictionary, card_id: String) -> bool:
	var inventory: Dictionary = snapshot.get("inventory", {}) if snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var machine: Dictionary = (slot_variant as Dictionary).get("machine", {}) \
			if (slot_variant as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return true
	return false


func _cleanup(app_root: Node) -> void:
	for node in app_root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	app_root.queue_free()
	await process_frame


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("PLAYER_CARD_DOCK_REAL_THREE_POOL_PRODUCTION_GATE_TEST|status=%s|checks=%d|failures=%d|bound_route=BLOCKED" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("PLAYER_CARD_DOCK_REAL_THREE_POOL_PRODUCTION_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
