extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

const TOP_BAR_FIELDS := ["table_state", "tempo", "phase", "turn", "identity", "cash_text", "gdp_text", "goal_text", "selected_district", "primary_action", "weather_status"]
const PLAYER_BOARD_FIELDS := ["actions", "quick_actions", "region_infrastructure", "table_state_lamps", "readiness_chips", "progress_path", "bid_board", "goal_text", "goal_ratio", "primary_action", "hand_cards"]
const TRACK_SOURCE_FIELDS := ["history", "active", "queue", "next_queue", "events", "selected_resolution_id", "selected_player", "auction_open", "batch_locked", "counter_window_active", "group_phase", "group_phase_remaining_seconds", "group_cadence", "group_count", "pending_decision", "status_text"]
const DECISION_KINDS := ["monster_wager", "contract_response", "discard_purchase", "monster_target_choice", "player_target_choice"]

var checks := 0
var failures: Array[String] = []


class PrivateViewerWorldStub:
	extends Node

	func _can_view_player_private_hand(player_index: int) -> bool:
		return player_index == 0


class QuoteAuthorityStub:
	extends Node

	func export_quote_for_session(_quote: Dictionary) -> Dictionary:
		return {}

	func restore_quote_from_session(_snapshot: Dictionary) -> Dictionary:
		return {}

	func quote_snapshot(_quote_id: String) -> Dictionary:
		return {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var game_screen := GAME_SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	game_screen.name = "GameScreen"
	host.add_child(game_screen)
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	coordinator.name = "GameRuntimeCoordinator"
	coordinator.presentation_game_screen_path = NodePath("../GameScreen")
	host.add_child(coordinator)
	_configure_presentation_dependencies(coordinator)
	await process_frame
	await process_frame

	var catalog := coordinator.card_runtime_catalog_service()
	var ordered_ids := catalog.ordered_card_ids()
	_expect(not ordered_ids.is_empty(), "production card catalog has a card for the parity fixture")
	var card_id := str(ordered_ids[0]) if not ordered_ids.is_empty() else ""
	var skill := catalog.definition(card_id) if not card_id.is_empty() else {}
	coordinator.world_session_state().replace_players([
		{"name": "本地玩家", "is_ai": false, "cash": 1400, "slots": [skill], "city_guesses": {1: 1}},
		{"name": "AI一", "is_ai": true, "cash": 987654, "slots": [{"name": "秘密手牌"}], "ai_plan": "SECRET_PLAN"},
		{"name": "AI二", "is_ai": true, "cash": 876543, "slots": [{"name": "另一秘密牌"}]},
	], true)
	coordinator.world_session_state().replace_districts([
		{"region_id": "r0", "name": "甲区", "center": Vector2(100, 100), "terrain": "land", "terrain_label": "陆地", "products": ["crystal"], "demands": ["food"], "city": {"owner": 0, "active": true, "level": 1}},
		{"region_id": "r1", "name": "乙区", "center": Vector2(300, 100), "terrain": "land", "terrain_label": "陆地", "products": ["food"], "demands": ["crystal"], "city": {"owner": 1, "active": true, "level": 1}},
	], true)
	coordinator.world_session_state().configure_world_geometry(800.0, 400.0)
	coordinator.table_selection_state().restore({
		"selected_player": 0,
		"inspected_player": 0,
		"selected_district": 0,
		"selected_trade_product": "crystal",
		"selected_card_resolution_id": 41,
		"selected_hand_slot": 0,
		"selected_map_layer_focus": "route",
	})
	_configure_rack(coordinator, card_id, skill)
	_configure_track(coordinator, card_id, skill)
	await process_frame
	await process_frame

	var query := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	var source := coordinator.get_node_or_null("TablePresentationSourceOwner") as TablePresentationSourceOwner
	var scheduler := coordinator.get_node_or_null("TablePresentationRefreshScheduler") as TablePresentationRefreshScheduler
	_expect(query != null and source != null and scheduler != null, "production composition provides query, source and scheduler")
	if query == null or source == null or scheduler == null:
		_finish(host)
		return

	var raw_hand := query.hand_presentation_sources_for_viewer(0)
	var raw_track := query.card_track_presentation_source_for_viewer(0)
	var full_snapshot := source.build_full_snapshot(scheduler.immediate_typed(&"full"))
	var table := full_snapshot.to_dictionary()
	var top := _dictionary(table.get("top_bar", {}))
	var player_board := _dictionary(table.get("player_board", {}))
	var district := _dictionary(_dictionary(table.get("right_inspector", {})).get("district", {}))
	for field in TOP_BAR_FIELDS:
		_expect(top.has(field), "top bar preserves BASE field: %s" % field)
	for field in PLAYER_BOARD_FIELDS:
		_expect(player_board.has(field), "player board preserves BASE field: %s" % field)
	for field in TRACK_SOURCE_FIELDS:
		_expect(raw_track.has(field), "card track source preserves BASE field: %s" % field)

	_expect(raw_hand.size() == 1, "authorized hand projection produces one CardPresentation source")
	var hand_cards := _array(player_board.get("hand_cards", []))
	_expect(hand_cards.size() == 1, "full table contains the real CardPresentation hand")
	if not hand_cards.is_empty():
		var hand_card := _dictionary(hand_cards[0])
		_expect(str(hand_card.get("id", "")) == "hand_0", "hand card keeps its scene-owned selected slot identity")
		_expect(not str(hand_card.get("effect", "")).is_empty(), "hand card has a non-empty CardPresentation effect")
		_expect(not _array(hand_card.get("actions", [])).is_empty() and str(_dictionary(_array(hand_card.get("actions", []))[0]).get("id", "")) == "play_0", "hand card exposes the typed play action")
	_expect(not _array(player_board.get("actions", [])).is_empty(), "player board exposes non-empty primary actions")
	_expect(_array(player_board.get("quick_actions", [])).size() >= 3, "player board exposes rack, buy and play quick actions")
	_expect(not _array(player_board.get("readiness_chips", [])).is_empty(), "player board exposes readiness chips")
	_expect(not _dictionary(player_board.get("bid_board", {})).is_empty(), "player board exposes the public bid board")
	var table_lamps_json := JSON.stringify(player_board.get("table_state_lamps", []))
	_expect(table_lamps_json.contains("结算") and not table_lamps_json.contains("resolving"), "player table state lamp localizes the raw resolving phase")
	_expect(not str(district.get("title", "")).is_empty(), "right inspector receives selected district details")
	_expect(not _array(_dictionary(table.get("right_inspector", {})).get("actions", [])).is_empty(), "right inspector preserves actionable entries")
	_expect(_array(raw_track.get("history", [])).size() == 1, "track has a real public history entry")
	_expect(not _dictionary(raw_track.get("active", {})).is_empty(), "track has a real active entry")
	_expect(_array(raw_track.get("queue", [])).size() == 1, "track has a real current queue entry")
	_expect(_array(raw_track.get("next_queue", [])).size() == 1, "track has a real next queue entry")
	_expect(not _dictionary(raw_track.get("group_cadence", {})).is_empty(), "track carries current group cadence")
	_expect(not _array(table.get("card_track", [])).is_empty(), "full table carries composed public track cards")
	_expect(not _dictionary(table.get("card_resolution_track", {})).is_empty(), "full table carries the resolution track view model")
	_expect(str(_dictionary(table.get("planet", {})).get("selected_map_layer_focus", "route")) in ["route", ""], "planet table source is compatible with selected map focus")

	var applied := coordinator.request_table_presentation_refresh(&"map", &"parity")
	_expect(applied.applied, "typed map refresh applies")
	var planet_target := game_screen.presentation_planet_target()
	var embedded := planet_target.get_embedded_map_view() as SpaceSyndicatePlanetMapView
	var overlay := game_screen.overlay_layer as SpaceSyndicateOverlayLayer
	var fullscreen := overlay.presentation_fullscreen_planet_target() if overlay != null else null
	_expect(bool(planet_target.map_presentation_target_debug_snapshot().get("fullscreen_target_bound", false)), "production PlanetBoard binds the fullscreen map target")
	_expect(embedded != null and fullscreen != null, "embedded and fullscreen typed map targets both exist")
	if embedded != null and fullscreen != null:
		_expect(embedded.districts.size() == 2 and fullscreen.districts.size() == 2, "same typed map snapshot reaches embedded and fullscreen targets")
		_expect(embedded.selected_district == 0 and fullscreen.selected_district == 0, "embedded and fullscreen maps share selected district")
		_expect(embedded.visual_layer_focus == "route" and fullscreen.visual_layer_focus == "route", "embedded and fullscreen maps share selected layer focus")

	var card_presentation_port := coordinator.get_node_or_null("CardResolutionPresentationPort") as CardResolutionPresentationPort
	_expect(card_presentation_port != null, "typed card-resolution presentation port is production-composed")
	if card_presentation_port != null:
		var published := card_presentation_port.publish_public_event({
			"event_id": "parity-visual-1",
			"event_kind": "card_aftermath",
			"resolution_id": 91,
			"card_name": card_id,
			"status": "resolved",
			"summary": "公开卡牌结算完成。",
			"district_index": 0,
		})
		_expect(bool(published.get("published", false)), "typed card presentation port publishes one public visual event")
		var visual_snapshot := source.build_live_snapshot(scheduler.immediate_typed(&"live")).to_dictionary()
		_expect(_array(visual_snapshot.get("visual_events", [])).size() == 1 and not str(visual_snapshot.get("visual_event_key", "")).is_empty(), "SourceOwner consumes the typed public card event once")
		var no_replay_snapshot := source.build_full_snapshot(scheduler.immediate_typed(&"full")).to_dictionary()
		_expect(_array(no_replay_snapshot.get("visual_events", [])).is_empty(), "a later snapshot does not replay an already-consumed visual event")
		card_presentation_port.publish_public_event({
			"event_id": "parity-visual-2",
			"event_kind": "card_target_check",
			"resolution_id": 92,
			"card_name": card_id,
			"status": "valid",
			"summary": "公开目标有效。",
			"district_index": 1,
		})
		var live_apply := coordinator.request_table_presentation_refresh(&"live", &"parity_visual")
		_expect(live_apply.applied, "typed refresh port applies the new card visual event")
		var visual_layer_snapshot: Dictionary = game_screen.visual_event_layer.get_visual_event_snapshot() if game_screen.visual_event_layer != null else {}
		_expect(_array(visual_layer_snapshot.get("events", [])).size() == 1, "VisualEventLayer receives the public card event exactly once")
		coordinator.request_table_presentation_refresh(&"full", &"parity_visual_followup")
		var followup_layer_snapshot: Dictionary = game_screen.visual_event_layer.get_visual_event_snapshot() if game_screen.visual_event_layer != null else {}
		_expect(_array(followup_layer_snapshot.get("events", [])).size() == 1, "unrelated follow-up refresh does not replay card visuals")
		var owner_sentinel := "PRIVATE_OWNER_SENTINEL_91"
		var target_sentinel := "PRIVATE_TARGET_SENTINEL_92"
		var cash_sentinel := "PRIVATE_CASH_SENTINEL_93"
		var injected := card_presentation_port.publish_public_event({
			"event_id": "parity-visual-malicious",
			"event_kind": "card_aftermath",
			"resolution_id": 93,
			"card_name": card_id,
			"status": "resolved",
			"summary": cash_sentinel,
			"aftermath_clue": target_sentinel,
			"public_owner_revealed": false,
			"public_owner_label": owner_sentinel,
			"public_target_revealed": false,
			"target_label": target_sentinel,
			"localization_key": cash_sentinel,
			"public_values": {"cash": cash_sentinel, "private_target": target_sentinel},
			"district_index": 0,
		})
		var injected_event := _dictionary(injected.get("event", {}))
		var injected_json := JSON.stringify(injected_event)
		_expect(bool(injected.get("published", false)), "malicious public event is normalized through the typed visibility gate")
		_expect(not injected_event.has("summary") and not injected_event.has("aftermath_clue"), "free-text summary and aftermath fields are absent from the public event")
		_expect(not injected_event.has("public_owner_label") and not injected_event.has("target_label"), "retired actor labels are discarded and target labels require an explicit public reveal gate")
		_expect(str(injected_event.get("localization_key", "")) == "card_resolution.aftermath.resolved", "localization key is derived from the allowlisted event kind and status")
		for sentinel in [owner_sentinel, target_sentinel, cash_sentinel]:
			_expect(not injected_json.contains(sentinel), "malicious sentinel cannot enter the public event: %s" % sentinel)
		coordinator.request_table_presentation_refresh(&"live", &"parity_visual_malicious")
		var sanitized_visual_json := JSON.stringify(game_screen.visual_event_layer.get_visual_event_snapshot()) if game_screen.visual_event_layer != null else ""
		_expect(sanitized_visual_json.contains("公开卡牌完成结算。"), "VisualEvent uses the fixed localization copy")
		for sentinel in [owner_sentinel, target_sentinel, cash_sentinel]:
			_expect(not sanitized_visual_json.contains(sentinel), "malicious sentinel cannot enter VisualEvent: %s" % sentinel)
		var revealed := card_presentation_port.publish_public_event({
			"event_id": "parity-visual-revealed-labels",
			"event_kind": "card_target_check",
			"status": "valid",
			"public_owner_revealed": true,
			"public_owner_label": "已公开席位",
			"public_target_revealed": true,
			"target_label": "已公开区域",
		})
		var revealed_event := _dictionary(revealed.get("event", {}))
		_expect(not revealed_event.has("public_owner_label") and str(revealed_event.get("target_label", "")) == "已公开区域", "card-history presentation retires actor labels while preserving explicitly public target labels")

	var contract_bridge := coordinator.get_node_or_null("ContractRuntimeWorldBridge") as ContractRuntimeWorldBridge
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	_expect(contract_bridge != null and history != null, "contract and history typed owners are production-composed")
	if contract_bridge != null and history != null:
		var contract_stored := contract_bridge.store_contract_result({
			"resolution_id": 501,
			"skill": {"name": "合约测试牌", "display_name": "合约测试牌", "kind": "area_trade_contract"},
			"contract_source_district": 0,
			"contract_target_district": 1,
			"contract_products": ["crystal"],
			"contract_response": "accepted",
			"aftermath_clue": "合约已公开接受。",
		})
		var stored_contract := _history_entry(history, 501)
		_expect(contract_stored and not str(stored_contract.get("aftermath_style", "")).is_empty(), "contract history derives presentation style through the typed card service")

	var query_source := FileAccess.get_file_as_string("res://scripts/presentation/table_presentation_viewmodel_query.gd")
	_expect(not query_source.contains("WorldSessionState") and not query_source.contains("_world.players") and not query_source.contains("_world.districts"), "ViewModel query has no raw WorldSessionState collection dependency")
	_expect(query_source.contains("private_world_projection") and query_source.contains("CardPlayEligibility"), "hand projection uses viewer-private allowlist and eligibility facts")
	var contract_bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/contract_runtime_world_bridge.gd")
	_expect(not contract_bridge_source.contains("_card_resolution_presentation_snapshot") and contract_bridge_source.contains("CardPresentationRuntimeService"), "contract result presentation uses a typed scene-owned service without a Main callback")
	_expect(not contract_bridge_source.contains("_pulse_district") and not contract_bridge_source.contains("_add_action_callout"), "contract bridge has no dead presentation callback to Main")
	for decision_kind in DECISION_KINDS:
		_expect(query_source.contains('"%s"' % decision_kind), "query supports temporary decision kind: %s" % decision_kind)
	_assert_temporary_decision_parity(host, coordinator, query)

	var table_json := JSON.stringify(table)
	_expect(not table_json.contains("987654") and not table_json.contains("876543"), "table snapshot omits opponent exact cash")
	_expect(not table_json.contains("秘密手牌") and not table_json.contains("另一秘密牌") and not table_json.contains("SECRET_PLAN"), "table snapshot omits opponent hand and AI plan")
	_finish(host)


func _configure_rack(coordinator: GameRuntimeCoordinator, card_id: String, skill: Dictionary) -> void:
	var supply := coordinator.get_node_or_null("RegionSupplyRuntimeController") as RegionSupplyRuntimeController
	if supply == null:
		return
	supply.configure(7331, [
		{"region_id": "r0", "region_index": 0, "display_name": "甲区", "terrain": "land"},
		{"region_id": "r1", "region_index": 1, "display_name": "乙区", "terrain": "land"},
	], [{
		"card_id": card_id,
		"family_id": str(skill.get("family_id", card_id)),
		"card_type": str(skill.get("kind", "ordinary")),
		"rank": 1,
		"name": card_id,
		"display_name": str(skill.get("display_name", card_id)),
		"price_cash": 120,
		"effect_text": str(skill.get("text", "发展区域")),
		"requirement_text": str(skill.get("play_requirement_text", "条件：当前选区")),
		"region_supply_weight": 1,
		"potential_target_exists": true,
	}], 1)


func _configure_presentation_dependencies(coordinator: GameRuntimeCoordinator) -> void:
	var card_presentation := coordinator.get_node_or_null("CardPresentationRuntimeService") as CardPresentationRuntimeService
	var table_viewmodel := coordinator.get_node_or_null("GameTableViewModelRuntimeService") as GameTableViewModelRuntimeService
	var eligibility := coordinator.get_node_or_null("CardPlayEligibilityRuntimeService") as CardPlayEligibilityRuntimeService
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var resolution := coordinator.get_node_or_null("CardResolutionRuntimeController") as CardResolutionRuntimeController
	var scheduler := coordinator.get_node_or_null("ForcedDecisionRuntimeScheduler") as ForcedDecisionRuntimeScheduler
	var monster := coordinator.get_node_or_null("MonsterRuntimeController") as MonsterRuntimeController
	var monster_bridge := coordinator.get_node_or_null("MonsterRuntimeWorldBridge") as MonsterRuntimeWorldBridge
	if card_presentation != null:
		card_presentation.configure({})
	if table_viewmodel != null:
		table_viewmodel.configure(card_presentation)
	if eligibility != null:
		eligibility.configure({"ruleset_id": "v0.6"})
	if queue != null:
		queue.configure({"ruleset_id": "v0.6", "card_group": RULESET.card_group_rules()})
	if history != null:
		history.configure({"history_limit": 24})
	if resolution != null:
		resolution.configure(RULESET.card_group_rules())
	if scheduler != null:
		scheduler.configure(["monster_wager", "counter_response", "contract_response", "other_choice"])
	if monster != null and monster_bridge != null:
		monster_bridge.set_world_session_state(coordinator.world_session_state())
		monster.set_world_bridge(monster_bridge)


func _configure_track(coordinator: GameRuntimeCoordinator, card_id: String, skill: Dictionary) -> void:
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	if queue != null:
		queue.replace_state({
			"current_queue": [_track_entry(42, card_id, skill, 1)],
			"active_entry": _track_entry(43, card_id, skill, 1),
			"next_queue": [_track_entry(44, card_id, skill, 2)],
			"resolution_sequence": 44,
			"last_group_window_sequence": 1,
		})
	if history != null:
		history.configure({"history_limit": 24})
		history.append_resolved(_track_entry(41, card_id, skill, 0).merged({"resolved": true, "resolution_outcome": "resolved"}, true))


func _assert_temporary_decision_parity(host: Node, coordinator: GameRuntimeCoordinator, query: TablePresentationViewModelQuery) -> void:
	var scheduler := coordinator.get_node_or_null("ForcedDecisionRuntimeScheduler") as ForcedDecisionRuntimeScheduler
	var monster := coordinator.get_node_or_null("MonsterRuntimeController") as MonsterRuntimeController
	var contract := coordinator.get_node_or_null("ContractRuntimeController") as ContractRuntimeController
	var contract_bridge := coordinator.get_node_or_null("ContractRuntimeWorldBridge") as ContractRuntimeWorldBridge
	var purchase := coordinator.get_node_or_null("DistrictPurchaseRuntimeController") as DistrictPurchaseRuntimeController
	var target := coordinator.get_node_or_null("CardTargetChoiceRuntimeController") as CardTargetChoiceRuntimeController
	_expect(scheduler != null and monster != null and contract != null and contract_bridge != null and purchase != null and target != null, "five temporary decision owners are production-composed")
	if scheduler == null or monster == null or contract == null or contract_bridge == null or purchase == null or target == null:
		return

	monster.auto_monsters = [
		{"uid": 101, "name": "潮汐巨兽", "position": 0, "down": false},
		{"uid": 102, "name": "轨道巨兽", "position": 0, "down": false},
	]
	monster.active_monster_wagers = [{
		"wager_id": 17,
		"resolved": false,
		"base_percent": 5,
		"competitors": [
			{"side": "a", "slot": 0, "uid": 101, "name": "潮汐巨兽", "damage": 0},
			{"side": "b", "slot": 1, "uid": 102, "name": "轨道巨兽", "damage": 0},
		],
		"bets": {},
		"public_bets": [],
		"historical_public_pool": 0,
		"eligible_player_indices": [0],
		"opening_cash_units_by_player": {"0": 1400},
		"public_player_ids_by_index": {"0": "player.0"},
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": 12.0,
		"battle_limit_seconds": 60.0,
		"battle_remaining_seconds": 60.0,
		"locked_competitor_uids": [101, 102],
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint([
			{"side": "a", "slot": 0, "uid": 101, "name": "潮汐巨兽", "damage": 0},
			{"side": "b", "slot": 1, "uid": 102, "name": "轨道巨兽", "damage": 0},
		]),
		"opening_attack_applied": true,
		"decision_open": true,
	}]
	scheduler.sync_candidates(monster.forced_decision_candidates())
	var wager_decision := query.temporary_decision_presentation_source_for_viewer(0)
	_expect(_decision_matches(wager_decision, "monster_wager"), "monster wager active descriptor and owner snapshot produce actionable wager decision")
	monster.active_monster_wagers.clear()
	scheduler.sync_candidates([])

	var private_world := PrivateViewerWorldStub.new()
	host.add_child(private_world)
	contract_bridge.bind_world(private_world)
	contract.set_world_bridge(contract_bridge)
	contract.pending_offers = [{
		"contract_offer_id": 27,
		"contract_target_owner": 0,
		"contract_response": ContractRuntimeController.RESPONSE_PENDING,
		"contract_decision_timer": 5.0,
		"contract_source_district": 0,
		"contract_target_district": 1,
		"contract_products": ["crystal"],
		"skill": {"name": "星际供需协议", "kind": "area_trade_contract"},
	}]
	scheduler.sync_candidates(contract.forced_decision_candidates())
	_expect(_decision_matches(query.temporary_decision_presentation_source_for_viewer(0), "contract_response"), "contract active descriptor and owner snapshot produce actionable response decision")
	contract.pending_offers.clear()
	scheduler.sync_candidates([])

	var quote_authority := QuoteAuthorityStub.new()
	host.add_child(quote_authority)
	purchase.set_quote_authority(quote_authority)
	purchase.configure({})
	purchase.open_window(0, 0, {"supply_revision": "rack-1"})
	purchase.acknowledge_card_selection(0, 0, "fixture-card", "rack-1")
	purchase.attach_quote(0, 0, {"quote_id": "quote-1", "district_index": 0, "supply_revision": "rack-1", "card_id": "fixture-card"})
	purchase.reserve_pending_discard({"player_index": 0, "district_index": 0, "card_id": "fixture-card", "skill_name": "fixture-card", "price": 120})
	scheduler.sync_candidates(purchase.forced_decision_candidates())
	_expect(_decision_matches(query.temporary_decision_presentation_source_for_viewer(0), "discard_purchase"), "discard active descriptor and owner snapshot produce actionable discard decision")
	purchase.reset_state()
	scheduler.sync_candidates([])

	target.begin_choice(CardTargetChoiceRuntimeController.KIND_MONSTER, 0, 0)
	scheduler.sync_candidates(target.forced_decision_candidates())
	_expect(_decision_matches(query.temporary_decision_presentation_source_for_viewer(0), "monster_target_choice"), "monster-target active descriptor and owner snapshot produce actionable target decision")
	target.clear_choice(CardTargetChoiceRuntimeController.KIND_MONSTER)
	scheduler.sync_candidates([])

	target.begin_choice(CardTargetChoiceRuntimeController.KIND_PLAYER, 0, 0)
	scheduler.sync_candidates(target.forced_decision_candidates())
	_expect(_decision_matches(query.temporary_decision_presentation_source_for_viewer(0), "player_target_choice"), "player-target active descriptor and owner snapshot produce actionable target decision")
	_expect(query.temporary_decision_presentation_source_for_viewer(1).is_empty(), "wrong viewer cannot obtain another player's temporary decision")
	target.clear_choice(CardTargetChoiceRuntimeController.KIND_PLAYER)
	scheduler.sync_candidates([])
	_expect(query.temporary_decision_presentation_source_for_viewer(0).is_empty(), "no active descriptor produces no temporary decision")


func _decision_matches(decision: Dictionary, kind: String) -> bool:
	return str(decision.get("kind", "")) == kind and not _array(decision.get("actions", [])).is_empty()


func _track_entry(resolution_id: int, card_id: String, skill: Dictionary, group_position: int) -> Dictionary:
	return {
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"player_index": 0,
		"slot_index": 0,
		"skill": skill.merged({"name": card_id}, true),
		"selected_district": 0,
		"group_id": "parity-group",
		"group_order": 1,
		"group_size": 1,
		"group_position": group_position,
		"aftermath_clue": "区域产能出现变化",
	}


func _history_entry(history: CardResolutionHistoryRuntimeService, resolution_id: int) -> Dictionary:
	for entry_variant in history.history_snapshot():
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("resolution_id", -1)) == resolution_id:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _finish(host: Node) -> void:
	if host != null:
		host.queue_free()
	await process_frame
	print("table_presentation_viewmodel_parity_test: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []
