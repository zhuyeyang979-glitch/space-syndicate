extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/district_supply_purchase_projection_receipt.save"
const TARGET_CARD_ID := "facility.market.technology.rank_1"
const FIXED_SEED := 900626424

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
		"district-supply-purchase-projection-receipt"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start.get("started", false)) and app_root != null and coordinator != null, "real production session starts")
	if app_root == null or coordinator == null:
		_finish()
		return

	var world := coordinator.world_session_state()
	coordinator.pause_session()
	await process_frame
	var query := coordinator.get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort
	var table_query := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var presentation := coordinator.card_supply_presentation_state()
	var port := coordinator.district_supply_action_port()
	var screen := app_root.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer if screen != null else null
	var configured := coordinator.configure_region_supply_from_world(
		FIXED_SEED,
		world.districts if world != null else [],
		[TARGET_CARD_ID],
		1
	)
	_expect(bool(configured.get("configured", false)), "fixed seed configures the target facility listing")
	var district_index := _first_purchasable_target_district(coordinator, world)
	_expect(district_index >= 0, "fixed seed exposes the target facility in a currently purchasable district")
	_expect(query != null and table_query != null and query_ports != null and presentation != null and port != null and screen != null and overlay != null, "typed rack query, hand query, privacy ports, GameScreen and action port are composed")
	if district_index < 0 or query == null or table_query == null or query_ports == null or presentation == null or port == null or screen == null or overlay == null:
		_stop_audio(app_root)
		app_root.queue_free()
		await process_frame
		_finish()
		return

	var human := (world.players[0] as Dictionary).duplicate(true)
	human["cash"] = 100_000
	world.players[0] = human
	var context := coordinator.get_node("TablePresentationQueryPorts").viewer_context() as TablePresentationViewerContext
	screen.bind_presentation_viewer(0, context.authorization_revision)
	var identity := coordinator.get_node("PlayerIdentityAuthorizationBoundary") as PlayerIdentityAuthorizationBoundary
	var actor_context := identity.current_actor_context(&"district_supply") if identity != null else null
	screen.bind_gameplay_actor_authorization_context(actor_context)
	_expect(actor_context != null and actor_context.is_valid() and actor_context.authorization_revision == context.authorization_revision, "human surface binds the same typed actor and viewer authorization")
	_expect(screen.request_district_selection(district_index, &"qa_driver"), "human table selection is aligned with the open rack")
	presentation.open_district = district_index
	presentation.open_player = 0
	presentation.previewed_district_card = TARGET_CARD_ID
	presentation.selected_market_skill = TARGET_CARD_ID
	var district := world.districts[district_index] as Dictionary
	var rack_revision := coordinator.region_supply_rack_revision(str(district.get("region_id", "")))
	coordinator.open_district_purchase_window(0, district_index, {"supply_revision": rack_revision})
	coordinator.mark_district_supply_revision(0, district_index, rack_revision)

	var intents: Array[DistrictSupplyActionIntent] = []
	var receipts: Array[DistrictSupplyActionReceipt] = []
	screen.district_supply_action_intent_requested.connect(func(intent: DistrictSupplyActionIntent) -> void:
		intents.append(intent)
	)
	port.receipt_ready.connect(func(receipt: DistrictSupplyActionReceipt) -> void:
		receipts.append(receipt)
	)

	var first_surface := query.snapshot_for_viewer(0)
	_expect(overlay.apply_district_supply_presentation(first_surface, 0, context.authorization_revision), "viewer-private target facility drawer applies")
	var drawer := screen.get_district_supply_drawer() as SpaceSyndicateDistrictSupplyDrawer
	var first_preview := _drawer_preview(drawer)
	_expect(str(first_preview.get("card_name", "")) == TARGET_CARD_ID, "fixed facility is the rendered preview")
	_expect(str(first_preview.get("primary_action_id", "")) == "district_supply_preview_card", "no-quote projection explicitly requests a quote")
	_expect(bool(first_preview.get("buy_enabled", false)) and str(first_preview.get("buy_text", "")).contains("获取报价"), "enabled button copy and action both describe quote acquisition")

	drawer.call("_on_card_purchase_requested", TARGET_CARD_ID, "focused_human_double_click")
	_expect(intents.size() == 1 and intents[0].action_kind == DistrictSupplyActionIntent.KIND_QUOTE, "human Drawer-to-GameScreen path emits a typed quote intent first")
	_expect(receipts.size() == 1 and receipts[0].accepted and receipts[0].reason_code == "quote_locked", "authoritative port accepts and reports the locked quote: %s" % _receipt_debug(receipts))
	_expect(not receipts[0].quote_id.is_empty(), "private quote receipt carries the locked quote credential")

	var second_surface := query.snapshot_for_viewer(0)
	_expect(overlay.apply_district_supply_presentation(second_surface, 0, context.authorization_revision), "post-quote viewer-private projection reapplies")
	var second_preview := _drawer_preview(drawer)
	_expect(str(second_preview.get("primary_action_id", "")) == "district_supply_purchase_card", "active quote projection advances to purchase: %s" % JSON.stringify(second_preview))
	_expect(str(second_preview.get("action_reason_code", "")) == "facility_purchase_ready", "buy-enabled projection exposes the allowlisted ready reason")

	var before_purchase := port.debug_snapshot()
	drawer.call("_on_card_purchase_requested", TARGET_CARD_ID, "focused_human_confirm")
	_expect(intents.size() == 2 and intents[1].action_kind == DistrictSupplyActionIntent.KIND_PURCHASE, "same human surface emits typed purchase only after quote")
	_expect(receipts.size() == 2 and receipts[1].accepted and receipts[1].applied, "authoritative purchase receipt commits the facility card: %s" % _receipt_debug(receipts))
	_expect(receipts[1].reason_code != "locked_quote_required", "purchase no longer reaches the missing-quote rejection")
	var after_purchase := port.debug_snapshot()
	_expect(int(after_purchase.get("purchase_commit_count", 0)) == int(before_purchase.get("purchase_commit_count", 0)) + 1, "purchase mutation commits exactly once")

	var actor_binding := coordinator.actor_id_for_player_index(0)
	var actor_id := str(actor_binding.get("actor_id", ""))
	var economic_after_purchase := coordinator.economic_source_snapshot(actor_id)
	_expect(bool(actor_binding.get("available", false)) and not actor_id.is_empty(), "current human resolves to one authoritative v0.6 actor")
	_expect(int(economic_after_purchase.get("owned_facility_count", -1)) == 0 and int(economic_after_purchase.get("production_installation_count", -1)) == 0, "purchasing a facility card does not install a facility or production source")

	var private_projection := query_ports.private_world_projection(0, 0).to_dictionary()
	var private_projection_text := JSON.stringify(private_projection)
	var public_projection_text := JSON.stringify(query_ports.public_world_projection().to_dictionary())
	_expect(private_projection_text.contains(TARGET_CARD_ID), "authorized owner projection exposes only the stable v0.6 card identity needed for presentation")
	_expect(not private_projection_text.contains('"machine"') and not private_projection_text.contains("runtime_instance_id"), "authorized owner projection does not expose the machine envelope or runtime instance identity")
	_expect(not public_projection_text.contains(TARGET_CARD_ID) and not public_projection_text.contains('"machine"') and not public_projection_text.contains("runtime_instance_id"), "public table projection does not expose the bought card or its internal identities")
	var denied_projection := query_ports.private_world_projection(1, 0).to_dictionary()
	_expect(not bool(denied_projection.get("authorized", true)) and (denied_projection.get("player", {}) as Dictionary).is_empty() and str(denied_projection.get("visibility_scope", "")) == "denied", "another viewer receives only a denied envelope for the human player's private hand")

	var table_state := table_query.compose_table_state(0, true)
	var player_board: Dictionary = table_state.get("player_board", {}) if table_state.get("player_board", {}) is Dictionary else {}
	var hand_cards: Array = player_board.get("hand_cards", []) if player_board.get("hand_cards", []) is Array else []
	var facility_hand := _first_card_of_kind(hand_cards, "facility_v06")
	var facility_slot := int(facility_hand.get("slot", -1))
	var malformed_definition := coordinator.v06_card_definition(TARGET_CARD_ID)
	var malformed_machine: Dictionary = (malformed_definition.get("machine", {}) as Dictionary).duplicate(true) if malformed_definition.get("machine", {}) is Dictionary else {}
	var malformed_cost: Dictionary = (malformed_machine.get("asset_cost", {}) as Dictionary).duplicate(true) if malformed_machine.get("asset_cost", {}) is Dictionary else {}
	malformed_cost["life"] = 1.0000001
	malformed_machine["asset_cost"] = malformed_cost
	malformed_definition["machine"] = malformed_machine
	var malformed_skill_variant: Variant = table_query.call("_normalized_v06_skill", malformed_definition)
	var malformed_skill: Dictionary = malformed_skill_variant if malformed_skill_variant is Dictionary else {}
	var malformed_facts := coordinator.card_play_world_facts(0, malformed_skill, {"selected_district": district_index, "slot_index": facility_slot})
	var malformed_eligibility := coordinator.evaluate_card_play({"player_index": 0, "skill": malformed_skill, "evaluation_mode": "rule"}, malformed_facts)
	_expect(str(malformed_eligibility.get("reason_code", "")) == "asset_cost_invalid_amount" and str(malformed_skill.get("cost", "")) == "费用数据异常", "fractional JSON asset cost remains invalid instead of being rounded into a playable card")
	malformed_cost.erase("generic")
	malformed_machine["asset_cost"] = malformed_cost
	malformed_definition["machine"] = malformed_machine
	var missing_cost_skill_variant: Variant = table_query.call("_normalized_v06_skill", malformed_definition)
	var missing_cost_skill: Dictionary = missing_cost_skill_variant if missing_cost_skill_variant is Dictionary else {}
	_expect(str(missing_cost_skill.get("cost", "")) == "费用数据异常", "missing one authoritative asset key cannot be presented as a free play")
	var missing_cost_facts := coordinator.card_play_world_facts(0, missing_cost_skill, {"selected_district": district_index, "slot_index": facility_slot})
	var missing_cost_eligibility := coordinator.evaluate_card_play({"player_index": 0, "skill": missing_cost_skill, "evaluation_mode": "hand"}, missing_cost_facts)
	var missing_cost_state := coordinator.compose_card_play_eligibility(missing_cost_eligibility, {"display_name": "设施牌"})
	_expect(not bool(missing_cost_eligibility.get("actionable", true)) and str(missing_cost_eligibility.get("reason_code", "")) == "asset_cost_unavailable", "missing v0.6 asset key disables the formal hand action")
	_expect(str(missing_cost_state.get("detail", "")).contains("不会扣牌或资产") and not JSON.stringify(missing_cost_eligibility.get("reason_args", {})).contains("generic"), "missing asset schema exposes only a readable public-safe reason")
	var facility_action := _first_enabled_play_action(facility_hand)
	_expect(not facility_hand.is_empty() and str(facility_hand.get("name", "")) == "科技市场", "bought v0.6 facility is rendered as the authored technology-market hand card")
	_expect(str(facility_hand.get("effect", "")).strip_edges() != "" and str(facility_hand.get("use_case", "")).strip_edges() != "", "facility hand card carries authored effect and use-case copy")
	_expect(str(facility_hand.get("type", "")) == "城市成长" and str(facility_hand.get("cost", "")) == "打出免费", "facility hand card exposes a human-readable route and play cost instead of generic placeholders")
	_expect(bool(facility_hand.get("actionable", false)) and str(facility_action.get("id", "")).begins_with("play_"), "facility hand card exposes one enabled formal play action")

	var inventory_before_play := coordinator.v06_card_player_snapshot(actor_id)
	var authoritative_inventory: Dictionary = inventory_before_play.get("inventory", {}) if inventory_before_play.get("inventory", {}) is Dictionary else {}
	var authoritative_slots: Array = authoritative_inventory.get("slots", []) if authoritative_inventory.get("slots", []) is Array else []
	var authoritative_card: Dictionary = authoritative_slots[facility_slot] if facility_slot >= 0 and facility_slot < authoritative_slots.size() and authoritative_slots[facility_slot] is Dictionary else {}
	var runtime_instance_id := str(authoritative_card.get("runtime_instance_id", ""))
	var region_id := str(district.get("region_id", ""))
	var play_transaction_id := "v06-play:%s:%s:%s" % [actor_id, runtime_instance_id, region_id]
	var inventory_owner := coordinator.get_node_or_null("CommodityCardInventoryRuntimeController")
	var journal_before: Dictionary = inventory_owner.call("transaction_journal_snapshot") if inventory_owner != null else {}
	var queue_owner := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var queue_before_text := JSON.stringify(queue_owner.public_snapshot()) if queue_owner != null else ""
	var infrastructure_owner := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	_expect(not runtime_instance_id.is_empty() and facility_slot >= 0, "formal hand slot resolves to one authoritative inventory instance before play")
	_expect(infrastructure_owner != null, "the unique region-infrastructure owner is composed for exact-once verification")
	var legacy_entry_before := JSON.stringify(infrastructure_owner.facilities_snapshot(true)) if infrastructure_owner != null else ""
	var legacy_entry_result := coordinator.submit_public_facility_card({
		"transaction_id": "qa-retired-public-facility-entry",
		"player_index": 0,
		"target_region_index": district_index,
		"skill": {"kind": "public_facility", "card_id": TARGET_CARD_ID},
	})
	_expect(not bool(legacy_entry_result.get("committed", true)) and str(legacy_entry_result.get("reason", "")) == "legacy_public_facility_entry_retired", "legacy public-facility queue entry is explicitly retired instead of owning a second facility mutation path")
	_expect((JSON.stringify(infrastructure_owner.facilities_snapshot(true)) if infrastructure_owner != null else "") == legacy_entry_before, "retired legacy public entry changes no authoritative facility state")
	var occupied_region_id := ""
	for district_variant in world.districts:
		if district_variant is Dictionary and str((district_variant as Dictionary).get("region_id", "")) != region_id:
			occupied_region_id = str((district_variant as Dictionary).get("region_id", ""))
			break
	var occupied_seed := infrastructure_owner.apply_facility_action({
		"transaction_id": "qa-public-action-occupied-target",
		"region_id": occupied_region_id,
		"owner_kind": "neutral",
		"owner_player_index": -1,
		"facility_type": "market",
		"industry_id": "technology",
		"rank": 1,
		"occurred_at": world.game_time,
	}) if infrastructure_owner != null and not occupied_region_id.is_empty() else {}
	var occupied_finalized := infrastructure_owner.finalize_facility_action(occupied_seed) if infrastructure_owner != null and bool(occupied_seed.get("committed", false)) else {}
	var exact_target_journal_before := JSON.stringify(inventory_owner.call("transaction_journal_snapshot")) if inventory_owner != null else ""
	var exact_target_reject := coordinator.execute_v06_facility_play_action(actor_id, TARGET_CARD_ID, occupied_region_id)
	_expect(bool(occupied_finalized.get("finalized", false)) and not bool(exact_target_reject.get("success", true)) and str(exact_target_reject.get("failure_code", "")) == "facility_play_target_unavailable", "public facility action rejects the exact occupied region instead of substituting the economic-source target")
	_expect((JSON.stringify(inventory_owner.call("transaction_journal_snapshot")) if inventory_owner != null else "") == exact_target_journal_before and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) == _inventory_card_count(inventory_before_play), "invalid public target preserves the requested card and creates no formal play journal entry")
	var blocked_player := (world.players[0] as Dictionary).duplicate(true)
	blocked_player["action_cooldown"] = 5.0
	world.players[0] = blocked_player
	var gate_journal_before := JSON.stringify(inventory_owner.call("transaction_journal_snapshot")) if inventory_owner != null else ""
	var gate_facilities_before := JSON.stringify(infrastructure_owner.facilities_snapshot(true)) if infrastructure_owner != null else ""
	var gate_flow_before := JSON.stringify(coordinator.commodity_flow_to_save_data())
	var gate_mana_before := JSON.stringify(coordinator.player_mana_to_save_data())
	var blocked_submission := coordinator.card_play_submission_controller().request_hand_play({"player_index": 0, "slot_index": facility_slot, "submission_source": "qa_manual_stale_action"})
	_expect(not bool(blocked_submission.get("accepted", true)) and str(blocked_submission.get("reason", "")) == "player_action_cooldown", "manual v0.6 facility submission passes the final CardPlayEligibility hard gate")
	_expect((JSON.stringify(inventory_owner.call("transaction_journal_snapshot")) if inventory_owner != null else "") == gate_journal_before \
			and (JSON.stringify(infrastructure_owner.facilities_snapshot(true)) if infrastructure_owner != null else "") == gate_facilities_before \
			and JSON.stringify(coordinator.commodity_flow_to_save_data()) == gate_flow_before \
			and JSON.stringify(coordinator.player_mana_to_save_data()) == gate_mana_before, "eligibility rejection occurs before every card, facility, flow, asset and journal mutation")
	blocked_player["action_cooldown"] = 0.0
	world.players[0] = blocked_player

	var submission_before := coordinator.card_play_submission_controller().debug_snapshot()
	screen.emit_signal("action_requested", str(facility_action.get("id", "")))
	var submission_after := submission_before
	for _frame in range(30):
		await process_frame
		submission_after = coordinator.card_play_submission_controller().debug_snapshot()
		if int(submission_after.get("accepted_count", 0)) + int(submission_after.get("rejected_count", 0)) \
				> int(submission_before.get("accepted_count", 0)) + int(submission_before.get("rejected_count", 0)):
			break
	var play_receipt: Dictionary = submission_after.get("last_receipt", {}) if submission_after.get("last_receipt", {}) is Dictionary else {}
	var v06_receipt: Dictionary = play_receipt.get("v06_receipt", {}) if play_receipt.get("v06_receipt", {}) is Dictionary else {}
	var effect_finalization: Dictionary = v06_receipt.get("effect_finalization", {}) if v06_receipt.get("effect_finalization", {}) is Dictionary else {}
	var economic_after_play := coordinator.economic_source_snapshot(actor_id)
	var inventory_after_play := coordinator.v06_card_player_snapshot(actor_id)
	var journal_after: Dictionary = inventory_owner.call("transaction_journal_snapshot") if inventory_owner != null else {}
	var infrastructure_after_play := infrastructure_owner.region_snapshot(region_id) if infrastructure_owner != null else {}
	var world_player_after_play: Dictionary = (world.players[0] as Dictionary).duplicate(true) if world.players[0] is Dictionary else {}
	var journal_entry_after_play: Dictionary = (journal_after.get(play_transaction_id, {}) as Dictionary).duplicate(true) if journal_after.get(play_transaction_id, {}) is Dictionary else {}
	var journal_result_after_play: Dictionary = (journal_entry_after_play.get("result", {}) as Dictionary).duplicate(true) if journal_entry_after_play.get("result", {}) is Dictionary else {}
	_expect(int(submission_after.get("accepted_count", 0)) == int(submission_before.get("accepted_count", 0)) + 1 and bool(play_receipt.get("accepted", false)) and not bool(play_receipt.get("queued", true)), "formal GameScreen hand action reaches the shared typed submission entry and commits without entering the shared card queue|receipt=%s" % JSON.stringify(play_receipt))
	_expect(bool(v06_receipt.get("committed", false)) and bool(effect_finalization.get("finalized", v06_receipt.get("finalized", false))) and str(v06_receipt.get("route_id", "")) == "core_economic_card_runtime", "internal receipt proves one finalized core-economic card transaction|v06=%s" % JSON.stringify(v06_receipt))
	_expect(int(economic_after_play.get("owned_facility_count", 0)) == 1 and int(economic_after_play.get("production_installation_count", 0)) == 0, "technology market play creates exactly one market facility and no fake factory production installation")
	_expect(_inventory_card_count(inventory_after_play) == _inventory_card_count(inventory_before_play) - 1 and journal_after.size() == journal_before.size() + 1, "successful play removes one authoritative hand instance and writes one inventory transaction")
	_expect(journal_after.has(play_transaction_id) and not str(journal_entry_after_play.get("intent_hash", "")).is_empty() \
			and str(journal_result_after_play.get("transaction_id", "")) == play_transaction_id \
			and str(journal_result_after_play.get("actor_id", "")) == actor_id \
			and str(journal_result_after_play.get("card_id", "")) == TARGET_CARD_ID \
			and str(journal_result_after_play.get("card_instance_id", "")) == runtime_instance_id \
			and str(journal_result_after_play.get("effect_kind", "")) == "build_upgrade_or_repair_facility" \
			and bool((journal_result_after_play.get("effect_finalization", {}) as Dictionary).get("finalized", false)), "journal entry binds the exact actor, card instance, target transaction and finalized effect")
	_expect(queue_owner != null and JSON.stringify(queue_owner.public_snapshot()) == queue_before_text, "direct facility play leaves the shared queue and card-window state unchanged")

	var play_replay := coordinator.play_v06_runtime_card({
		"actor_id": actor_id,
		"slot_index": facility_slot,
		"transaction_id": play_transaction_id,
		"region_id": region_id,
		"game_time": world.game_time,
	})
	var economic_after_replay := coordinator.economic_source_snapshot(actor_id)
	var inventory_after_replay := coordinator.v06_card_player_snapshot(actor_id)
	var journal_after_replay: Dictionary = inventory_owner.call("transaction_journal_snapshot") if inventory_owner != null else {}
	var infrastructure_after_replay := infrastructure_owner.region_snapshot(region_id) if infrastructure_owner != null else {}
	var world_player_after_replay: Dictionary = (world.players[0] as Dictionary).duplicate(true) if world.players[0] is Dictionary else {}
	_expect(bool(play_replay.get("idempotent_replay", false)) and bool(play_replay.get("committed", false)), "same authoritative transaction replays idempotently|receipt=%s" % JSON.stringify(play_replay))
	_expect(JSON.stringify(economic_after_replay) == JSON.stringify(economic_after_play) \
			and JSON.stringify(inventory_after_replay) == JSON.stringify(inventory_after_play) \
			and JSON.stringify(infrastructure_after_replay) == JSON.stringify(infrastructure_after_play) \
			and JSON.stringify(world_player_after_replay) == JSON.stringify(world_player_after_play) \
			and JSON.stringify(journal_after_replay) == JSON.stringify(journal_after), "idempotent replay leaves facility HP, ownership, revisions, cash, assets, inventory and the full transaction journal unchanged")

	var mana_save := coordinator.player_mana_to_save_data()
	var pools_by_player: Dictionary = (mana_save.get("pools_by_player", {}) as Dictionary).duplicate(true) if mana_save.get("pools_by_player", {}) is Dictionary else {}
	var human_pool: Dictionary = (pools_by_player.get("0", {}) as Dictionary).duplicate(true) if pools_by_player.get("0", {}) is Dictionary else {}
	human_pool["technology"] = maxi(int(human_pool.get("technology", 0)), 10 * PlayerManaRuntimeController.MILLIASSET_SCALE)
	pools_by_player["0"] = human_pool
	mana_save["pools_by_player"] = pools_by_player
	var mana_loaded := coordinator.apply_player_mana_save_data(mana_save)
	_expect(bool(mana_loaded.get("applied", false)), "upgrade/repair fixture funds the authoritative technology-asset owner")

	var rank_two_card_id := "facility.market.technology.rank_2"
	var before_upgrade_grant := coordinator.v06_card_player_snapshot(actor_id)
	var upgrade_grant_variant: Variant = inventory_owner.call("grant_card", actor_id, rank_two_card_id, int(before_upgrade_grant.get("revision", -1)), "qa-facility-upgrade-grant", "qa_upgrade") if inventory_owner != null else {}
	var upgrade_grant: Dictionary = (upgrade_grant_variant as Dictionary).duplicate(true) if upgrade_grant_variant is Dictionary else {}
	var after_upgrade_grant := coordinator.v06_card_player_snapshot(actor_id)
	var upgrade_slot := _inventory_slot_for_card(after_upgrade_grant, rank_two_card_id)
	var upgrade_table := table_query.compose_table_state(0, true)
	var upgrade_board: Dictionary = upgrade_table.get("player_board", {}) if upgrade_table.get("player_board", {}) is Dictionary else {}
	var upgrade_hand := _first_card_named(upgrade_board.get("hand_cards", []) if upgrade_board.get("hand_cards", []) is Array else [], "科技市场")
	var upgrade_action := _first_enabled_play_action(upgrade_hand)
	_expect(bool(upgrade_grant.get("committed", false)) and upgrade_slot >= 0 and bool(upgrade_hand.get("actionable", false)) and not upgrade_action.is_empty(), "owned Rank-II upgrade is actionable on the real GameScreen hand projection")
	var upgrade_submission_before := coordinator.card_play_submission_controller().debug_snapshot()
	screen.emit_signal("action_requested", str(upgrade_action.get("id", "")))
	var upgrade_submission_after := upgrade_submission_before
	for _frame in range(30):
		await process_frame
		upgrade_submission_after = coordinator.card_play_submission_controller().debug_snapshot()
		if int(upgrade_submission_after.get("accepted_count", 0)) > int(upgrade_submission_before.get("accepted_count", 0)):
			break
	var upgraded_facility := _facility_for_slot(infrastructure_owner, region_id, "market", "technology")
	var occupied_after_upgrade := _facility_for_slot(infrastructure_owner, occupied_region_id, "market", "technology")
	_expect(int(upgrade_submission_after.get("accepted_count", 0)) == int(upgrade_submission_before.get("accepted_count", 0)) + 1 and int(upgraded_facility.get("rank", 0)) == 2, "GameScreen→submission→formal play upgrades the explicitly selected region to Rank II")
	_expect(int(occupied_after_upgrade.get("rank", 0)) == 1 and str(occupied_after_upgrade.get("owner_kind", "")) == "neutral", "Rank-II play does not redirect to or mutate the other occupied region")

	var repair_damage := infrastructure_owner.apply_unit_damage({
		"transaction_id": "qa-facility-repair-damage",
		"source_kind": "monster",
		"source_entity_id": "monster.qa",
		"region_id": region_id,
		"amount": 20,
		"occurred_at": world.game_time,
	})
	var damage_before_repair := int(infrastructure_owner.region_snapshot(region_id).get("damage_taken", 0))
	var before_repair_grant := coordinator.v06_card_player_snapshot(actor_id)
	var repair_grant_variant: Variant = inventory_owner.call("grant_card", actor_id, rank_two_card_id, int(before_repair_grant.get("revision", -1)), "qa-facility-repair-grant", "qa_repair") if inventory_owner != null else {}
	var repair_grant: Dictionary = (repair_grant_variant as Dictionary).duplicate(true) if repair_grant_variant is Dictionary else {}
	var after_repair_grant := coordinator.v06_card_player_snapshot(actor_id)
	var repair_slot := _inventory_slot_for_card(after_repair_grant, rank_two_card_id)
	var repair_table := table_query.compose_table_state(0, true)
	var repair_board: Dictionary = repair_table.get("player_board", {}) if repair_table.get("player_board", {}) is Dictionary else {}
	var repair_hand := _first_card_named(repair_board.get("hand_cards", []) if repair_board.get("hand_cards", []) is Array else [], "科技市场")
	var repair_action := _first_enabled_play_action(repair_hand)
	_expect(bool(repair_damage.get("committed", false)) and bool(repair_grant.get("committed", false)) and repair_slot >= 0 and bool(repair_hand.get("actionable", false)) and not repair_action.is_empty(), "damaged owned Rank-II facility exposes an actionable repair on the real hand projection")
	var repair_submission_before := coordinator.card_play_submission_controller().debug_snapshot()
	screen.emit_signal("action_requested", str(repair_action.get("id", "")))
	var repair_submission_after := repair_submission_before
	for _frame in range(30):
		await process_frame
		repair_submission_after = coordinator.card_play_submission_controller().debug_snapshot()
		if int(repair_submission_after.get("accepted_count", 0)) > int(repair_submission_before.get("accepted_count", 0)):
			break
	var repaired_facility := _facility_for_slot(infrastructure_owner, region_id, "market", "technology")
	var damage_after_repair := int(infrastructure_owner.region_snapshot(region_id).get("damage_taken", -1))
	_expect(int(repair_submission_after.get("accepted_count", 0)) == int(repair_submission_before.get("accepted_count", 0)) + 1 \
			and int(repaired_facility.get("rank", 0)) == 2 and damage_before_repair > 0 and damage_after_repair < damage_before_repair, "GameScreen→submission→formal play repairs the explicitly selected Rank-II region without changing rank")
	_expect(int(_facility_for_slot(infrastructure_owner, occupied_region_id, "market", "technology").get("rank", 0)) == 1, "repair does not mutate the other occupied region")

	var replay := port.submit_intent(intents[1])
	var after_replay := port.debug_snapshot()
	_expect(replay.idempotent_replay and replay.reason_code == "request_replay", "duplicate typed submit is rejected as an idempotent replay")
	_expect(int(after_replay.get("purchase_commit_count", 0)) == int(after_purchase.get("purchase_commit_count", 0)), "duplicate submit cannot commit a second card or debit")
	var public_receipt_text := JSON.stringify(receipts[1].public_summary())
	_expect(not public_receipt_text.contains(TARGET_CARD_ID) and not public_receipt_text.contains(receipts[0].quote_id) and not public_receipt_text.contains("locked_quote"), "public receipt omits card, quote credential and private reason")

	_stop_audio(app_root)
	app_root.queue_free()
	await process_frame
	_finish()


func _first_purchasable_target_district(coordinator: GameRuntimeCoordinator, world: WorldSessionState) -> int:
	if coordinator == null or world == null:
		return -1
	for district_index in range(world.districts.size()):
		var district: Dictionary = world.districts[district_index] if world.districts[district_index] is Dictionary else {}
		if coordinator.region_supply_listing(str(district.get("region_id", "")), TARGET_CARD_ID).is_empty():
			continue
		if bool(coordinator.card_market_listing_availability(district_index).get("purchasable", false)):
			return district_index
	return -1


func _drawer_preview(drawer: SpaceSyndicateDistrictSupplyDrawer) -> Dictionary:
	if drawer == null:
		return {}
	var snapshot_variant: Variant = drawer.debug_snapshot()
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	return (snapshot.get("preview", {}) as Dictionary).duplicate(true) if snapshot.get("preview", {}) is Dictionary else {}


func _receipt_debug(receipts: Array[DistrictSupplyActionReceipt]) -> String:
	var rows: Array = []
	for receipt in receipts:
		rows.append(receipt.to_dictionary())
	return JSON.stringify(rows)


func _first_card_of_kind(cards: Array, kind: String) -> Dictionary:
	for card_variant in cards:
		if card_variant is Dictionary and str((card_variant as Dictionary).get("kind", "")) == kind:
			return (card_variant as Dictionary).duplicate(true)
	return {}


func _first_card_named(cards: Array, display_name: String) -> Dictionary:
	for card_variant in cards:
		if card_variant is Dictionary and str((card_variant as Dictionary).get("name", "")) == display_name:
			return (card_variant as Dictionary).duplicate(true)
	return {}


func _first_enabled_play_action(card: Dictionary) -> Dictionary:
	var actions: Array = card.get("actions", []) if card.get("actions", []) is Array else []
	for action_variant in actions:
		if action_variant is Dictionary and str((action_variant as Dictionary).get("id", "")).begins_with("play_") \
				and not bool((action_variant as Dictionary).get("disabled", false)):
			return (action_variant as Dictionary).duplicate(true)
	return {}


func _inventory_card_count(player_snapshot: Dictionary) -> int:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and not (slot_variant as Dictionary).is_empty():
			count += 1
	return count


func _inventory_slot_for_card(player_snapshot: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _facility_for_slot(
	infrastructure: RegionInfrastructureRuntimeController,
	region_id: String,
	facility_type: String,
	industry_id: String
) -> Dictionary:
	if infrastructure == null:
		return {}
	for facility_variant in infrastructure.facilities_snapshot(false):
		if facility_variant is Dictionary \
				and str((facility_variant as Dictionary).get("region_id", "")) == region_id \
				and str((facility_variant as Dictionary).get("facility_type", "")) == facility_type \
				and str((facility_variant as Dictionary).get("industry_id", "")) == industry_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _stop_audio(root_node: Node) -> void:
	for node in root_node.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("DISTRICT_SUPPLY_PURCHASE_PROJECTION_RECEIPT_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("DISTRICT_SUPPLY_PURCHASE_PROJECTION_RECEIPT_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
