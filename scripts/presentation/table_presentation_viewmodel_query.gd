@tool
extends Node
class_name TablePresentationViewModelQuery

const HAND_LIMIT := 5
const COMMODITY_SUSHI_TRACK_SERVICE_SCRIPT := preload("res://scripts/runtime/commodity_sushi_track_runtime_service.gd")
const V06_ASSET_COST_KEYS := ["life", "energy", "industry", "technology", "commerce", "shipping", "generic"]
const MAX_EXACT_JSON_INTEGER := 9007199254740991.0
const PLAYER_CARD_DOCK_HAND_VIEWMODELS_KEY := "__player_card_dock_hand_viewmodels"
const CURRENT_ACTION_CONTEXT_PROJECTION := preload("res://scripts/presentation/current_action_context_projection_v1.gd")
const PUBLIC_FEEDBACK_PROJECTION := preload("res://scripts/presentation/public_feedback_projection_v1.gd")
const CONTEXT_DETAIL_PROJECTION := preload("res://scripts/presentation/context_detail_projection_v1.gd")
const REGION_SUPPLY_POPUP_PROJECTION := preload("res://scripts/presentation/region_supply_popup_projection_v1.gd")
const PLAYER_ROSTER_PROJECTION_SERVICE := preload("res://scripts/presentation/public_player_roster_projection_service.gd")

var _ports: TablePresentationQueryPorts
var _selection: TableSelectionState
var _table_viewmodel: GameTableViewModelRuntimeService
var _card_catalog: CardRuntimeCatalogService
var _v06_card_catalog: CardRuntimeCatalogV06Resource
var _eligibility_facts: CardPlayEligibilityWorldBridge
var _eligibility: CardPlayEligibilityRuntimeService
var _region_supply: RegionSupplyRuntimeController
var _infrastructure: RegionInfrastructureRuntimeController
var _weather: WeatherPresentationRuntimeService
var _victory: VictoryControlRuntimeController
var _purchase: DistrictPurchaseRuntimeController
var _target_choice: CardTargetChoiceRuntimeController
var _monster: MonsterRuntimeController
var _military: MilitaryRuntimeController
var _commodity_flow: CommodityFlowRuntimeController
var _player_mana: PlayerManaRuntimeController
var _card_resolution: CardResolutionRuntimeController
var _queue: CardResolutionQueueRuntimeService
var _history: CardResolutionHistoryRuntimeService
var _card_resolution_presentation: CardResolutionPresentationPort
var _commodity_sushi_track: COMMODITY_SUSHI_TRACK_SERVICE_SCRIPT
var _district_supply_query: DistrictSupplyViewerQueryPort
var _player_roster_projection_service := PLAYER_ROSTER_PROJECTION_SERVICE.new()
var _revision := 0
var _compose_count := 0
var _last_visual_event_revision := 0
var _action_offer_revision := 0
var _action_offer_revision_by_viewer: Dictionary = {}
var _region_supply_offer_revision_by_viewer: Dictionary = {}


func configure(
	ports: TablePresentationQueryPorts,
	selection: TableSelectionState,
	table_viewmodel: GameTableViewModelRuntimeService,
	card_catalog: CardRuntimeCatalogService,
	eligibility_facts: CardPlayEligibilityWorldBridge,
	eligibility: CardPlayEligibilityRuntimeService,
	region_supply: RegionSupplyRuntimeController,
	infrastructure: RegionInfrastructureRuntimeController,
	weather: WeatherPresentationRuntimeService,
	victory: VictoryControlRuntimeController,
	purchase: DistrictPurchaseRuntimeController,
	target_choice: CardTargetChoiceRuntimeController,
	monster: MonsterRuntimeController,
	military: MilitaryRuntimeController,
	commodity_flow: CommodityFlowRuntimeController,
	player_mana: PlayerManaRuntimeController,
	card_resolution: CardResolutionRuntimeController,
	queue: CardResolutionQueueRuntimeService,
	history: CardResolutionHistoryRuntimeService,
	card_resolution_presentation: CardResolutionPresentationPort,
	commodity_sushi_track: COMMODITY_SUSHI_TRACK_SERVICE_SCRIPT = null,
	district_supply_query: DistrictSupplyViewerQueryPort = null,
	v06_card_catalog: CardRuntimeCatalogV06Resource = null
) -> void:
	_ports = ports
	_selection = selection
	_table_viewmodel = table_viewmodel
	_card_catalog = card_catalog
	_v06_card_catalog = v06_card_catalog
	_eligibility_facts = eligibility_facts
	_eligibility = eligibility
	_region_supply = region_supply
	_infrastructure = infrastructure
	_weather = weather
	_victory = victory
	_purchase = purchase
	_target_choice = target_choice
	_monster = monster
	_military = military
	_commodity_flow = commodity_flow
	_player_mana = player_mana
	_card_resolution = card_resolution
	_queue = queue
	_history = history
	_card_resolution_presentation = card_resolution_presentation
	_commodity_sushi_track = commodity_sushi_track
	_district_supply_query = district_supply_query


func compose_table_state(viewer_index: int, include_full: bool) -> Dictionary:
	var bundle := compose_table_state_bundle(viewer_index, include_full)
	return TablePresentationPureDataPolicy.detached_copy(
		bundle.get("table_state", {}) if bundle.get("table_state", {}) is Dictionary else {}
	) as Dictionary


func compose_table_state_bundle(viewer_index: int, include_full: bool) -> Dictionary:
	if not _viewer_is_authorized(viewer_index) or _table_viewmodel == null:
		return {}
	_action_offer_revision += 1
	_action_offer_revision_by_viewer[viewer_index] = _action_offer_revision
	var public_projection := _ports.public_world_projection()
	var public_world := public_projection.to_dictionary()
	var private_world := _ports.private_world_projection(viewer_index, viewer_index).to_dictionary()
	var action := _ports.action_projection(viewer_index).to_dictionary()
	if public_world.is_empty() or private_world.is_empty() or action.is_empty():
		return {}
	var supply_surface := _district_supply_query.snapshot_for_viewer(viewer_index) \
		if include_full and _district_supply_query != null else {}
	var source_revision := _ensure_action_offer_revision(viewer_index)
	var district := _selected_district_source(viewer_index, public_world, action)
	var actions := _action_entries(viewer_index, public_world, action, district)
	var logs := _ports.recent_public_log_messages(6)
	var visual_surface := _next_card_resolution_visual_surface(public_world)
	var hand_cards := _hand_card_sources(viewer_index, private_world)
	var authorization_revision := _ports.viewer_context().authorization_revision
	var public_players := _array(public_world.get("players", []))
	var inspected_player_index := _selection.inspected_player_index() if _selection != null else viewer_index
	var roster_projection := _player_roster_projection_service.compose_roster(
		public_players,
		viewer_index,
		authorization_revision,
		source_revision,
		inspected_player_index,
		"unlocked" if bool(_dictionary(action.get("availability", {})).get("card_submissions_open", false)) else "locked"
	)
	var inspection_projection := _player_roster_projection_service.compose_inspection_for_player(
		public_players,
		inspected_player_index,
		viewer_index,
		authorization_revision,
		source_revision,
		{},
		[],
		[IntelApplicationIntent.open().to_dictionary()]
	)
	var table_source := {
		"selection_context": {
			"revision": int(_selection.snapshot().get("revision", 0)) if _selection != null else 0,
			"selected_district": _selection.selected_district if _selection != null else -1,
			"district_count": _array(public_world.get("districts", [])).size(),
			"district_region_ids": _district_region_ids(public_world),
			"selected_trade_product": _selection.selected_trade_product if _selection != null else "",
			"trade_product_ids": ProductMarketRuntimeController.PRODUCT_CATALOG.duplicate(),
			"default_trade_product_id": _default_trade_product_id(district),
			"selected_hand_slot": _selection.selected_hand_slot if _selection != null else -1,
			"hand_slot_count": hand_cards.size(),
			"selected_card_resolution_id": _selection.selected_card_resolution_id if _selection != null else -1,
		},
		"top_bar": _top_bar_source(viewer_index, public_world, private_world, action, district),
		"planet": _planet_source(public_world, action, district),
		"player_roster": roster_projection,
		"player_inspection": inspection_projection,
		"district": district,
		"actions": actions,
		"player_board": _player_board_source(viewer_index, public_world, private_world, action, district, actions),
		"temporary_decision": _temporary_decision_source(viewer_index, public_world, private_world, action),
		"active_forced_decision": _dictionary(action.get("forced_decision", {})),
		"visual_events": visual_surface.get("events", []),
		"visual_event_key": str(visual_surface.get("key", "")),
		"logs": logs,
		"commodity_sushi_track": _commodity_sushi_track.public_snapshot(viewer_index).to_dictionary() \
			if _commodity_sushi_track != null else {},
	}
	var card_surfaces := {
		"hand_cards": hand_cards,
		"track": _card_track_source(viewer_index, action),
		"selected_hand_slot": _selection.selected_hand_slot if _selection != null else -1,
		"selected_resolution_id": _selection.selected_card_resolution_id if _selection != null else -1,
	}
	var composed := _table_viewmodel.compose_table_source({
		"table_source": table_source,
		"card_surfaces": card_surfaces,
		"include_player_card_dock_bundle": true,
	})
	var hand_viewmodels: Array = composed.get(PLAYER_CARD_DOCK_HAND_VIEWMODELS_KEY, []) \
		if composed.get(PLAYER_CARD_DOCK_HAND_VIEWMODELS_KEY, []) is Array else []
	composed.erase(PLAYER_CARD_DOCK_HAND_VIEWMODELS_KEY)
	composed["current_action_context"] = _current_action_context_projection(
		viewer_index,
		authorization_revision,
		source_revision,
		district,
		action
	)
	composed["context_detail"] = _selected_context_detail_projection(
		viewer_index,
		authorization_revision,
		source_revision,
		hand_cards,
		hand_viewmodels,
		_array(composed.get("card_track", []))
	)
	var public_feedback := _public_feedback_projections(
		_ports.recent_public_log_entries(6),
		viewer_index,
		authorization_revision,
		"public"
	)
	if include_full:
		public_feedback.append_array(_public_feedback_projections(
			_ports.recent_viewer_private_feedback_entries(viewer_index, 6),
			viewer_index,
			authorization_revision,
			"viewer_private"
		))
		var region_projection := _region_supply_popup_projection(
			supply_surface,
			district,
			viewer_index,
			authorization_revision,
			source_revision
		)
		composed["region_supply_popup"] = region_projection
		if region_projection.is_empty():
			_region_supply_offer_revision_by_viewer.erase(viewer_index)
		else:
			_region_supply_offer_revision_by_viewer[viewer_index] = int(
				region_projection.get("source_revision", 0)
			)
	composed["public_feedback"] = public_feedback
	composed.erase("district")
	composed.erase("actions")
	composed.erase("logs")
	_revision += 1
	_compose_count += 1
	return {
		"table_state": TablePresentationPureDataPolicy.detached_copy(composed) as Dictionary,
		"hand_sources": TablePresentationPureDataPolicy.detached_copy(hand_cards) as Array,
		"hand_viewmodels": TablePresentationPureDataPolicy.detached_copy(hand_viewmodels) as Array,
	}


func _default_trade_product_id(district: Dictionary) -> String:
	for key in ["demands", "city_demands", "products", "city_products"]:
		var values := _string_array(district.get(key, []))
		if not values.is_empty():
			return values[0]
	return ""


func hand_presentation_sources_for_viewer(viewer_index: int) -> Array:
	if _ports == null:
		return []
	var private_world := _ports.private_world_projection(viewer_index, viewer_index).to_dictionary()
	return TablePresentationPureDataPolicy.detached_copy(_hand_card_sources(viewer_index, private_world)) as Array


func current_action_offer_revision(viewer_index: int) -> int:
	return int(_action_offer_revision_by_viewer.get(viewer_index, 0))


func district_supply_offer_revision_is_current(viewer_index: int, revision: int) -> bool:
	return viewer_index >= 0 and revision > 0 \
		and int(_region_supply_offer_revision_by_viewer.get(viewer_index, 0)) == revision


func card_track_presentation_source_for_viewer(viewer_index: int) -> Dictionary:
	if _ports == null or not _viewer_is_authorized(viewer_index):
		return {}
	return TablePresentationPureDataPolicy.detached_copy(
		_card_track_source(viewer_index, _ports.action_projection(viewer_index).to_dictionary())
	) as Dictionary


func temporary_decision_presentation_source_for_viewer(viewer_index: int) -> Dictionary:
	if _ports == null or not _viewer_is_authorized(viewer_index):
		return {}
	return TablePresentationPureDataPolicy.detached_copy(_temporary_decision_source(
		viewer_index,
		_ports.public_world_projection().to_dictionary(),
		_ports.private_world_projection(viewer_index, viewer_index).to_dictionary(),
		_ports.action_projection(viewer_index).to_dictionary()
	)) as Dictionary


func debug_snapshot() -> Dictionary:
	return {
		"configured": _ports != null and _selection != null and _table_viewmodel != null,
		"revision": _revision,
		"compose_count": _compose_count,
		"uses_card_presentation_viewmodels": true,
		"uses_card_play_eligibility_facts": true,
		"uses_public_queue_and_history": true,
		"card_visual_event_revision": _last_visual_event_revision,
		"uses_public_player_roster_projection": _player_roster_projection_service != null,
		"uses_public_commodity_sushi_track_projection": _commodity_sushi_track != null,
		"uses_viewer_safe_district_supply_projection": _district_supply_query != null,
		"supports_decision_kinds": ["monster_wager", "counter_response", "discard_purchase", "monster_target_choice", "player_target_choice"],
		"references_main": false,
		"mutates_gameplay": false,
	}


func _hand_card_sources(viewer_index: int, private_world: Dictionary) -> Array:
	var result: Array = []
	if not _viewer_is_authorized(viewer_index):
		return result
	var player := _dictionary(private_world.get("player", {}))
	for card_variant in _array(player.get("hand", [])):
		if not (card_variant is Dictionary):
			continue
		var private_card := _dictionary(card_variant)
		var slot_index := int(private_card.get("slot_index", -1))
		var card_name := str(private_card.get("card_id", private_card.get("name", "")))
		if slot_index < 0 or card_name.is_empty():
			continue
		var skill := _catalog_skill(card_name, private_card)
		var eligibility := _card_eligibility(viewer_index, skill, slot_index)
		var offer := _human_card_play_offer(viewer_index, slot_index, skill, eligibility)
		result.append({
			"slot": slot_index,
			"card": _card_source(skill),
			"eligibility": eligibility,
			"game_action_offer": offer,
		})
	return result


func _card_track_source(viewer_index: int, action: Dictionary) -> Dictionary:
	var queue_public: Dictionary = _queue.public_snapshot() if _queue != null else {}
	var facts: Dictionary = _card_resolution.card_play_fact_snapshot() if _card_resolution != null else {}
	var queue_empty := int(queue_public.get("current_count", 0)) <= 0 and not bool(queue_public.get("active_present", false))
	facts["queue_empty"] = queue_empty
	facts["active_present"] = bool(queue_public.get("active_present", false))
	var forced: Dictionary = action.get("forced_decision", {}) if action.get("forced_decision", {}) is Dictionary else {}
	var history_rows: Array = _history.private_viewer_snapshot(viewer_index) if _history != null else []
	var events: Array = []
	for message in _ports.recent_public_log_messages(2):
		events.append({"text": str(message), "tooltip": str(message)})
	return {
		"history": _enriched_track_entries(history_rows, viewer_index, "history"),
		"active": _enriched_track_entry(_dictionary(queue_public.get("active", {})), viewer_index, "active"),
		"queue": _enriched_track_entries(_array(queue_public.get("current", [])), viewer_index, "current"),
		"next_queue": _enriched_track_entries(_array(queue_public.get("next", [])), viewer_index, "next"),
		"events": events,
		"selected_resolution_id": _selection.selected_card_resolution_id if _selection != null else -1,
		"selected_player": viewer_index,
		"auction_open": bool(facts.get("auction_open", false)),
		"batch_locked": bool(facts.get("batch_locked", false)),
		"counter_window_active": bool(facts.get("counter_window_active", false)),
		"group_phase": _card_resolution.current_phase(facts) if _card_resolution != null else "idle",
		"group_phase_remaining_seconds": float(facts.get("simultaneous_timer", 0.0)),
		"group_cadence": {
			"window_sequence": int(facts.get("window_sequence", 0)),
			"simultaneous_timer": float(facts.get("simultaneous_timer", 0.0)),
			"auction_timer": float(facts.get("auction_timer", 0.0)),
			"counter_timer": float(facts.get("counter_timer", 0.0)),
		},
		"group_count": _group_count(_array(queue_public.get("current", []))),
		"pending_decision": not forced.is_empty(),
		"status_text": _track_status_text(facts, queue_public),
		"history_window": 10,
	}


func _enriched_track_entries(entries: Array, viewer_index: int, queue_scope := "history") -> Array:
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result.append(_enriched_track_entry(entry_variant as Dictionary, viewer_index, queue_scope))
	return result


func _enriched_track_entry(entry: Dictionary, viewer_index: int, queue_scope := "history") -> Dictionary:
	if entry.is_empty():
		return {}
	var card_name := str(entry.get("card_name", _dictionary(entry.get("skill", {})).get("name", "")))
	var skill := _catalog_skill(card_name, _dictionary(entry.get("skill", {})))
	var public_entry := TablePresentationPureDataPolicy.detached_copy(entry) as Dictionary
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var is_viewer_card := _viewer_owns_resolution_in_scope(resolution_id, viewer_index, queue_scope) \
		if queue_scope in ["active", "current", "next"] \
		else str(entry.get("visibility_scope", "")) == "owner_private"
	public_entry["is_viewer_card"] = is_viewer_card
	var can_reorder := queue_scope == "current" and is_viewer_card \
		and _card_resolution != null and _card_resolution.submissions_open()
	var group_size := maxi(1, int(entry.get("group_size", 1)))
	var group_order := clampi(int(entry.get("group_order", 1)), 1, group_size)
	return {
		"entry": public_entry,
		"card": _card_source(skill),
		"card_label": str(skill.get("display_name", skill.get("name", "公开牌"))),
		"effect_text": str(skill.get("text", skill.get("display_text", ""))),
		"requirement_text": str(skill.get("play_requirement_text", "条件：见卡面")),
		"target_text": _track_target_text(entry),
		"animation_text": str(entry.get("aftermath_clue", "")),
		"order_clue": _track_order_text(entry),
		"facility_label": "%s%s" % [str(skill.get("industry_id", "")), str(skill.get("facility_type", ""))],
		"can_reorder": can_reorder,
		"reorder_up_offer": _card_group_offer(GameActionIntentV1.ACTION_CARD_GROUP_REORDER, resolution_id, can_reorder and group_order > 1, "group-boundary", -1) if viewer_index >= 0 else {},
		"reorder_down_offer": _card_group_offer(GameActionIntentV1.ACTION_CARD_GROUP_REORDER, resolution_id, can_reorder and group_order < group_size, "group-boundary", 1) if viewer_index >= 0 else {},
	}


func _viewer_owns_resolution_in_scope(resolution_id: int, viewer_index: int, queue_scope: String) -> bool:
	if _queue == null or resolution_id < 0 or viewer_index < 0:
		return false
	var entries: Array = []
	match queue_scope:
		"active":
			entries = [_queue.active_entry()]
		"current":
			entries = _queue.current_queue()
		"next":
			entries = _queue.next_queue()
		_:
			return false
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var authoritative_entry := entry_variant as Dictionary
		if int(authoritative_entry.get("resolution_id", authoritative_entry.get("queued_order", -1))) == resolution_id:
			return int(authoritative_entry.get("player_index", -1)) == viewer_index
	return false


func _card_source(skill: Dictionary) -> Dictionary:
	var card_name := str(skill.get("name", skill.get("card_id", "")))
	var definition := _catalog_skill(card_name, skill)
	var machine := _dictionary(definition.get("machine", {}))
	var player := _dictionary(definition.get("player", {}))
	return {
		"card_name": card_name,
		"skill": definition,
		"display_name": str(definition.get("display_name", player.get("name", card_name))),
		"display_text": str(definition.get("text", definition.get("display_text", player.get("effect", "")))),
		"tag_text": str(definition.get("tag_text", "")),
		"rank": maxi(1, int(definition.get("rank", machine.get("rank", _card_catalog.rank(card_name) if _card_catalog != null else 1)))),
		"price": maxi(0, int(definition.get("price", definition.get("purchase_cost", machine.get("purchase_cash", 0))))),
		"category_id": str(definition.get("category_id", machine.get("category_id", ""))),
		"type_label": str(definition.get("type_label", player.get("type", ""))),
		"subtype_label": str(definition.get("subtype_label", player.get("industry", ""))),
		"use_case": str(definition.get("use_case", player.get("next_step", ""))),
		"play_requirement_text": str(definition.get("play_requirement_text", player.get("cost", "条件：见卡面"))),
	}


func _card_eligibility(viewer_index: int, skill: Dictionary, slot_index: int = -1) -> Dictionary:
	if _eligibility_facts == null or _eligibility == null:
		return {"allowed": false, "actionable": false, "reason_code": "service_missing"}
	var facts := _eligibility_facts.build_facts(viewer_index, skill, {
		"selected_district": _selection.selected_district if _selection != null else -1,
		"slot_index": slot_index,
	})
	if _commodity_flow != null:
		facts["commodity_color_flow"] = _commodity_flow.player_color_flow_snapshot(viewer_index)
	if _player_mana != null:
		facts["player_mana"] = _player_mana.availability_snapshot(viewer_index)
	return _eligibility.evaluate_play({"player_index": viewer_index, "skill": skill, "evaluation_mode": "hand"}, facts)


func _selected_district_source(viewer_index: int, public_world: Dictionary, action: Dictionary) -> Dictionary:
	var districts := _array(public_world.get("districts", []))
	var selected := _selection.selected_district if _selection != null else -1
	if selected < 0 or selected >= districts.size():
		return {"id": "", "title": "未选区", "summary": "先点星球区域。", "detail": "先点星球区域。", "full_detail": "点星球区域，查看牌架与公共设施。", "chips": [{"text": "未选择"}], "actions": []}
	var district := _dictionary(districts[selected])
	var region_id := str(district.get("region_id", ""))
	var infrastructure := _infrastructure.region_snapshot(region_id) if _infrastructure != null and not region_id.is_empty() else {}
	var rack := _region_supply.public_rack_snapshot(region_id) if _region_supply != null and not region_id.is_empty() else {}
	var slots := _rack_slots(rack)
	var weather_detail := _weather.region_detail_snapshot(selected) if _weather != null else {}
	var chips: Array = [
		{"text": "区域 %d" % (selected + 1)},
		{"text": "%d张牌" % slots.size(), "tooltip": "当前区域公开牌架。"},
	]
	if not weather_detail.is_empty() and str(weather_detail.get("phase", "clear")) != "clear":
		chips.append({"text": str(weather_detail.get("display_name", "区域天气")), "tooltip": str(weather_detail.get("accessible_text", ""))})
	for facility_variant in _array(infrastructure.get("facilities", [])):
		var facility := _dictionary(facility_variant)
		chips.append({"text": "%s%s I%d" % [str(facility.get("industry_id", "")), str(facility.get("facility_type", "设施")), int(facility.get("rank", 1))]})
		if chips.size() >= 7:
			break
	var details := [
		"地形：%s" % str(district.get("terrain_label", district.get("terrain", "陆地"))),
		"生产：%s" % "、".join(_string_array(district.get("products", []))),
		"需求：%s" % "、".join(_string_array(district.get("demands", []))),
		"区域牌架：%d张" % slots.size(),
	]
	if not infrastructure.is_empty():
		details.append("区域完整度：%d/%d" % [int(infrastructure.get("derived_current_hp", 0)), int(infrastructure.get("derived_max_hp", 0))])
	return {
		"id": str(selected),
		"region_id": region_id,
		"title": str(district.get("name", "区域")),
		"summary": "%s｜牌架%d张" % [str(district.get("terrain_label", district.get("terrain", "陆地"))), slots.size()],
		"detail": "｜".join(details.slice(0, 3)),
		"full_detail": "\n".join(details),
		"chips": chips,
		"region_infrastructure": infrastructure,
		"rack": slots,
		"actions": _district_actions(action, slots),
		"viewer_index": viewer_index,
	}


func _action_entries(_viewer_index: int, _public_world: Dictionary, action: Dictionary, district: Dictionary) -> Array:
	var actions := _district_actions(action, _array(district.get("rack", [])))
	if actions.is_empty():
		actions.append({"id": "inspect", "label": "看星球", "state": "可看", "kind": "inspect", "disabled": false, "tooltip": "选择区域，查看公开局势。"})
	return actions.slice(0, 6)


func _district_actions(action: Dictionary, rack_slots: Array) -> Array:
	var availability := _dictionary(action.get("availability", {}))
	var district_exists := bool(availability.get("selected_district_exists", false))
	var actions: Array = [{
		"id": "rack", "label": "查看牌架", "state": "%d张" % rack_slots.size(), "kind": "inspect",
		"disabled": not district_exists, "tooltip": "查看当前区域公开挂牌。",
	}]
	actions.append({
		"id": "buy", "label": "购买", "state": "可选" if not rack_slots.is_empty() else "空",
		"kind": "purchase", "disabled": not bool(availability.get("can_request_region_purchase", false)) or rack_slots.is_empty(),
		"tooltip": "打开区域牌架并选择挂牌。",
	})
	return actions


func _top_bar_source(viewer_index: int, public_world: Dictionary, private_world: Dictionary, action: Dictionary, district: Dictionary) -> Dictionary:
	var player := _dictionary(private_world.get("player", {}))
	var victory_public := _victory.public_snapshot(viewer_index) if _victory != null else {}
	var victory_private := _victory.private_snapshot(viewer_index) if _victory != null else {}
	var candidate := _dictionary(victory_private.get("own_candidate", {}))
	var victory_rule := _dictionary(victory_public.get("victory_rule", {}))
	var progress := int(candidate.get("top_k_gdp_per_minute", candidate.get("top_n_gdp_per_minute", 0)))
	var goal := int(victory_rule.get("required_top_k_gdp_per_minute", victory_rule.get("required_top_n_gdp_per_minute", victory_rule.get("required_gdp_per_minute", 0))))
	var flow := _game_action_flow()
	var end_turn_offer := flow.human_action_offer(
		GameActionIntentV1.ACTION_SESSION_END_TURN,
		_ensure_action_offer_revision(viewer_index),
		true,
		"none",
		{},
		"full",
		["action.session.end-turn", "feedback.session.end-turn"]
	) if flow != null else {}
	return {
		"table_state": _table_state_text(action, victory_public),
		"tempo": _format_time(float(public_world.get("game_time", 0.0))),
		"phase": _table_state_text(action, victory_public),
		"turn": _format_time(float(public_world.get("game_time", 0.0))),
		"identity": str(player.get("public_player_name", "玩家")),
		"cash_text": "¥ %d" % int(player.get("cash", player.get("cash_cents", 0))),
		"gdp_text": "%d/min" % progress,
		"goal_text": "Top-N %d/%d" % [progress, goal],
		"selected_district": str(district.get("title", "未选区")),
		"primary_action": _primary_action_label(action),
		"weather_status": _weather_status_text(),
		"end_turn_offer": end_turn_offer,
	}


func _player_board_source(viewer_index: int, public_world: Dictionary, private_world: Dictionary, action: Dictionary, district: Dictionary, actions: Array) -> Dictionary:
	var player := _dictionary(private_world.get("player", {}))
	var top := _top_bar_source(viewer_index, public_world, private_world, action, district)
	var hand_count := _array(player.get("hand", [])).size()
	var availability := _dictionary(action.get("availability", {}))
	var rack_count := _array(district.get("rack", [])).size()
	return {
		"title": "玩家状态条",
		"hint": "卡牌操作只在下方玩家卡牌坞中进行。",
		"identity": top.get("identity", "玩家"),
		"cash_text": top.get("cash_text", "--"),
		"gdp_text": top.get("gdp_text", "--/min"),
		"goal_text": top.get("goal_text", ""),
		"goal_ratio": _goal_ratio(str(top.get("goal_text", ""))),
		"selected_district_summary": str(district.get("summary", "未选区")),
		"region_infrastructure": _dictionary(district.get("region_infrastructure", {})),
		"primary_action": _primary_action_label(action),
		"quick_actions": [
			{"id": "rack", "label": "区域牌架", "active": rack_count > 0, "state": "%d张" % rack_count, "tooltip": "当前选区公开挂牌。"},
			{"id": "buy", "label": "买牌", "active": bool(availability.get("can_request_region_purchase", false)) and rack_count > 0, "state": "ready" if rack_count > 0 else "locked", "tooltip": "选择挂牌后锁定报价。"},
		],
		"table_state_lamps": _table_state_lamps(action, district),
		"readiness_chips": [
			{"label": "选区", "state": "就绪" if bool(availability.get("selected_district_exists", false)) else "未选", "active": bool(availability.get("selected_district_exists", false))},
			{"label": "手牌", "state": "%d/%d" % [hand_count, HAND_LIMIT], "active": hand_count > 0},
			{"label": "买牌", "state": "就绪" if bool(availability.get("can_request_region_purchase", false)) else "--", "active": bool(availability.get("can_request_region_purchase", false))},
			{"label": "出牌", "state": "就绪" if bool(availability.get("card_submissions_open", false)) else "--", "active": bool(availability.get("card_submissions_open", false))},
		],
		"progress_path": _progress_path(viewer_index),
		"bid_board": _bid_board(viewer_index, action),
		"actions": actions.slice(0, 4),
	}


func _temporary_decision_source(viewer_index: int, public_world: Dictionary, private_world: Dictionary, action: Dictionary) -> Dictionary:
	var forced := _dictionary(action.get("forced_decision", {}))
	if forced.is_empty() or not bool(forced.get("visible_to_viewer", true)) or str(forced.get("presentation_surface", "overlay")) != "overlay":
		return {}
	match str(forced.get("source_ref", forced.get("kind", ""))):
		"monster_wager":
			return _monster_wager_decision(viewer_index)
		"discard_purchase":
			return _discard_decision(viewer_index, private_world)
		"monster_target_choice":
			return _monster_target_decision(viewer_index, private_world)
		"player_target_choice":
			return _player_target_decision(viewer_index, public_world, private_world)
	return {}


func _monster_wager_decision(viewer_index: int) -> Dictionary:
	var wager := _ports.monster_wager_presentation_for_viewer(viewer_index)
	if wager.is_empty():
		return {}
	var actions: Array = []
	for action_variant in _array(wager.get("actions", [])):
		var source := _dictionary(action_variant)
		actions.append({"id": str(source.get("id", "")), "label": "押%s %d%%" % [str(source.get("label", "怪兽")), int(source.get("stake_percent", 0))], "tooltip": "公开下注约¥%d" % int(source.get("stake", 0)), "disabled": bool(source.get("disabled", false))})
	return {"id": "monster_wager_%d" % int(wager.get("wager_id", -1)), "kind": "monster_wager", "title": "怪兽赌局", "body": "底注%d%%｜已决定%d/%d｜奖池¥%d" % [int(wager.get("base_percent", 0)), int(wager.get("decision_count", 0)), int(wager.get("seat_count", 0)), int(wager.get("pool", 0))], "actions": actions, "wager": wager}


func _discard_decision(viewer_index: int, private_world: Dictionary) -> Dictionary:
	var pending := _purchase.pending_discard_private_snapshot(viewer_index) if _purchase != null else {}
	if pending.is_empty():
		return {}
	var player := _dictionary(private_world.get("player", {}))
	var actions: Array = []
	for card_variant in _array(player.get("hand", [])):
		var card := _dictionary(card_variant)
		var slot := int(card.get("slot_index", -1))
		if slot >= 0:
			actions.append({"id": "discard_purchase_%d" % slot, "label": "弃掉 %s" % str(card.get("name", "旧牌")), "tooltip": "私密弃掉这张旧牌，再完成换购。"})
	actions.append({"id": "discard_purchase_cancel", "label": "取消换购", "tooltip": "取消本次购牌。"})
	return {"id": "discard_purchase", "kind": "discard_purchase", "title": "私密弃牌确认", "body": "手牌已满。弃1张旧牌后接收新牌。", "actions": actions, "choice": {"mode": "discard", "option_count": maxi(0, actions.size() - 1), "privacy": "弃牌选择仅当前玩家可见。"}}


func _monster_target_decision(viewer_index: int, private_world: Dictionary) -> Dictionary:
	var choices := _dictionary(action_choices(viewer_index))
	var choice := _dictionary(choices.get("monster_target_choice", {}))
	if choice.is_empty():
		return {}
	var card_name := _choice_card_name(choice, private_world)
	var actions: Array = []
	var roster := _monster.roster_snapshot(false) if _monster != null else []
	for index in range(roster.size()):
		var actor := _dictionary(roster[index])
		var monster_uid := int(actor.get("uid", -1))
		actions.append({"id": "target_monster_uid_%d" % monster_uid, "label": "怪%d %s" % [index + 1, str(actor.get("name", "怪兽"))], "disabled": monster_uid <= 0 or bool(actor.get("down", false)), "tooltip": "指定目标；目标会公开，出牌者仍隐藏。"})
	actions.append({"id": "target_monster_cancel", "label": "取消"})
	return {"id": str(choice.get("choice_id", "")), "kind": "monster_target_choice", "title": "请选择目标怪兽", "body": "%s需要先指定目标怪兽。" % card_name, "actions": actions, "choice": {"mode": "monster_target", "target_count": roster.size()}}


func _player_target_decision(viewer_index: int, public_world: Dictionary, private_world: Dictionary) -> Dictionary:
	var choices := _dictionary(action_choices(viewer_index))
	var choice := _dictionary(choices.get("player_target_choice", {}))
	if choice.is_empty():
		return {}
	var card_name := _choice_card_name(choice, private_world)
	var actions: Array = []
	var players := _array(public_world.get("players", []))
	for index in range(players.size()):
		if index == viewer_index:
			continue
		var player := _dictionary(players[index])
		actions.append({"id": "target_player_%d" % index, "label": str(player.get("public_player_name", "玩家%d" % (index + 1))), "disabled": bool(player.get("eliminated", false)), "tooltip": "目标会公开，出牌者仍隐藏。"})
	actions.append({"id": "target_player_cancel", "label": "取消"})
	return {"id": str(choice.get("choice_id", "")), "kind": "player_target_choice", "title": "请选择目标玩家", "body": "%s会影响一名玩家。" % card_name, "actions": actions, "choice": {"mode": "player_target", "target_count": maxi(0, players.size() - 1)}}


func action_choices(viewer_index: int) -> Dictionary:
	if _target_choice == null:
		return {}
	var snapshot := _target_choice.private_snapshot(viewer_index)
	return _dictionary(snapshot.get("choices", {}))


func _planet_source(
	public_world: Dictionary,
	_action: Dictionary,
	district: Dictionary
) -> Dictionary:
	var districts := _array(public_world.get("districts", []))
	var queue_public := _queue.public_snapshot() if _queue != null else {}
	var card_facts := _card_resolution.card_play_fact_snapshot() if _card_resolution != null else {}
	var monster_count := _monster.roster_snapshot(false).size() if _monster != null else 0
	var military_count := _military.roster_snapshot(false).size() if _military != null else 0
	var victory_public := _victory.public_snapshot(-1) if _victory != null else {}
	return {
		"title": "星球牌桌",
		"hint": "区域 %d｜怪兽 %d｜军队 %d｜选区 %s" % [districts.size(), monster_count, military_count, str(district.get("title", "未选区"))],
		"left_rail": {"title": "地表情报", "entries": [
			{"label": "星区", "value": "%d区" % districts.size(), "active": not districts.is_empty(), "tooltip": "公开星区数量。"},
			{"label": "选区", "value": str(district.get("title", "未选")), "active": not str(district.get("id", "")).is_empty(), "tooltip": "当前选区。"},
			{"label": "牌架", "value": "%d张" % _array(district.get("rack", [])).size(), "active": not _array(district.get("rack", [])).is_empty(), "tooltip": "当前选区公开牌架。"},
		]},
		"right_rail": {"title": "外围压力", "entries": [
			{"label": "怪兽", "value": "%d只" % monster_count, "active": monster_count > 0},
			{"label": "天气", "value": _weather_status_text(), "active": true},
			{"label": "牌轨", "value": "%d张" % (int(queue_public.get("current_count", 0)) + int(queue_public.get("next_count", 0))), "active": int(queue_public.get("current_count", 0)) > 0},
			{"label": "终局", "value": str(victory_public.get("state", "idle")), "active": str(victory_public.get("state", "idle")) != "idle"},
		], "hidden": bool(card_facts.get("counter_window_active", false)) \
			or bool(card_facts.get("auction_open", false)) \
			or bool(queue_public.get("active_present", false))},
		"weather": {"active": _weather_status_text(), "forecast": _weather_forecast_text(), "impact": _weather_impact_text(), "tooltip": _weather_status_text()},
		"flow_compass": {},
		"selected_map_layer_focus": _selection.selected_map_layer_focus if _selection != null else "all",
	}


func _bid_board(viewer_index: int, action: Dictionary) -> Dictionary:
	var track := _card_track_source(viewer_index, action)
	var phase := str(track.get("group_phase", "idle"))
	var remaining := int(ceil(float(track.get("group_phase_remaining_seconds", 0.0))))
	var viewer_resolution_id := _viewer_queue_resolution_id(track)
	var ready_available := phase in ["planning", "public_bid", "lock"] and viewer_resolution_id >= 0
	return {
		"title": "卡牌组确认",
		"phase": "%s %ds" % [_phase_label(phase), remaining] if remaining > 0 else _phase_label(phase),
		"status": str(track.get("status_text", "等待提交")),
		"active": phase in ["planning", "public_bid", "lock"],
		"chips": [{"label": "本阶段", "state": _phase_label(phase), "active": phase != "idle"}],
		"track_links": [],
		"actions": [{
			"id": "card_group_ready",
			"label": "完成本阶段",
			"disabled": not ready_available,
			"tooltip": "确认后等待其他席位。",
			"game_action_offer": _card_group_offer(
				GameActionIntentV1.ACTION_CARD_GROUP_READY,
				viewer_resolution_id,
				ready_available,
				"queued-entry-missing",
				0
			),
		}],
	}


func _table_state_lamps(action: Dictionary, district: Dictionary) -> Array:
	var track := _dictionary(action.get("card_track", {}))
	var queue_public := _dictionary(track.get("queue", {}))
	var table_phase := str(track.get("phase", "idle"))
	return [
		{"label": "桌态", "state": _phase_label(table_phase), "active": table_phase != "idle"},
		{"label": "选区", "state": str(district.get("title", "未选")), "active": not str(district.get("id", "")).is_empty()},
		{"label": "牌架", "state": "%d张" % _array(district.get("rack", [])).size(), "active": not _array(district.get("rack", [])).is_empty()},
		{"label": "队列", "state": "%d" % int(queue_public.get("current_count", 0)), "active": int(queue_public.get("current_count", 0)) > 0},
	]


func _progress_path(viewer_index: int) -> Array:
	var private_victory := _victory.private_snapshot(viewer_index) if _victory != null else {}
	var candidate := _dictionary(private_victory.get("own_candidate", {}))
	return [
		{"label": "控制区", "value": int(candidate.get("controlled_region_count", 0)), "active": int(candidate.get("controlled_region_count", 0)) > 0},
		{"label": "Top-N GDP", "value": int(candidate.get("top_k_gdp_per_minute", candidate.get("top_n_gdp_per_minute", 0))), "active": true},
	]


func _district_requirement_chips(action: Dictionary) -> Array:
	var availability := _dictionary(action.get("availability", {}))
	return [
		{"text": "选区:%s" % ("就绪" if bool(availability.get("selected_district_exists", false)) else "未选")},
		{"text": "买牌:%s" % ("可用" if bool(availability.get("can_request_region_purchase", false)) else "不可用")},
		{"text": "出牌:%s" % ("开放" if bool(availability.get("card_submissions_open", false)) else "关闭")},
	]


func _rack_slots(rack: Dictionary) -> Array:
	var regions := _array(rack.get("regions", []))
	if regions.is_empty():
		return []
	return _array(_dictionary(regions[0]).get("slots", []))


func _catalog_skill(card_name: String, fallback: Dictionary) -> Dictionary:
	if _card_catalog != null and not card_name.is_empty() and _card_catalog.has_card(card_name):
		return _card_catalog.definition(card_name)
	if _v06_card_catalog != null and not card_name.is_empty():
		var v06_card := _v06_card_catalog.card_snapshot(card_name)
		var v06_machine := _dictionary(v06_card.get("machine", {}))
		if not v06_machine.is_empty():
			return _normalized_v06_skill(v06_card)
	return fallback.duplicate(true)


func _normalized_v06_skill(card: Dictionary) -> Dictionary:
	var machine := _dictionary(card.get("machine", {}))
	var player := _dictionary(card.get("player", {}))
	var effect_payload := _dictionary(machine.get("effect_payload", {}))
	var card_id := str(machine.get("card_id", ""))
	var category_id := str(machine.get("category_id", ""))
	var asset_cost := _normalized_asset_cost(machine.get("asset_cost", {}))
	var keywords: Array = player.get("keywords", []) if player.get("keywords", []) is Array else []
	var keyword_texts: Array[String] = []
	for keyword_variant in keywords:
		if keyword_variant is Dictionary:
			var keyword_text := str((keyword_variant as Dictionary).get("text", "")).strip_edges()
			if not keyword_text.is_empty():
				keyword_texts.append(keyword_text)
	return {
		"name": card_id,
		"card_id": card_id,
		"family_id": str(machine.get("family_id", "")),
		"schema_version": "v0.6",
		"kind": "public_facility" if category_id == "facility" else str(machine.get("effect_kind", "")),
		"rank": maxi(1, int(machine.get("rank", 1))),
		"display_name": str(player.get("name", card_id)),
		"text": str(player.get("effect", player.get("short_effect", ""))),
		"display_text": str(player.get("effect", player.get("short_effect", ""))),
		"tag_text": " / ".join(keyword_texts),
		"tags": keyword_texts,
		"asset_cost": asset_cost,
		"play_cash": 0,
		"cost": _v06_play_cost_text(asset_cost, player),
		"purchase_cost": maxi(0, int(machine.get("purchase_cash", 0))),
		"category_id": category_id,
		"facility_kind": str(effect_payload.get("facility_kind", "")),
		"industry_id": str(effect_payload.get("industry_id", machine.get("industry_id", ""))),
		"type_label": str(player.get("type", "")),
		"subtype_label": str(player.get("industry", "")),
		"play_requirement_text": str(player.get("cost", "条件：见卡面")),
		"use_case": str(player.get("next_step", "")),
		"target": str(player.get("target", "")),
		"timing": str(player.get("timing", "")),
		"duration": str(player.get("duration", "")),
		"machine": {
			"card_id": card_id,
			"family_id": str(machine.get("family_id", "")),
			"category_id": category_id,
			"rank": maxi(1, int(machine.get("rank", 1))),
			"counts_toward_hand_limit": bool(machine.get("counts_toward_hand_limit", true)),
			"target_kind": str(machine.get("target_kind", "none")),
			"effect_kind": str(machine.get("effect_kind", "")),
			"effect_payload": effect_payload.duplicate(true),
		},
	}


func _normalized_asset_cost(value: Variant) -> Dictionary:
	var source := _dictionary(value)
	var normalized := {}
	for key_variant in source.keys():
		var key := str(key_variant)
		var amount_variant: Variant = source.get(key_variant, 0)
		if V06_ASSET_COST_KEYS.has(key) and amount_variant is float \
				and is_finite(float(amount_variant)) and float(amount_variant) >= 0.0 \
				and float(amount_variant) <= MAX_EXACT_JSON_INTEGER \
				and float(amount_variant) == floor(float(amount_variant)):
			# Godot's JSON parser represents authored integral numbers as floats.
			# Convert only a finite, non-negative mathematical integer; preserve every
			# malformed value so CardPlayEligibility can reject it fail-closed.
			normalized[key] = int(amount_variant)
		else:
			normalized[key] = amount_variant
	return normalized


func _asset_cost_total(asset_cost: Dictionary) -> int:
	var total := 0
	for amount_variant in asset_cost.values():
		total += maxi(0, int(amount_variant))
	return total


func _v06_play_cost_text(asset_cost: Dictionary, player: Dictionary) -> String:
	if asset_cost.size() != V06_ASSET_COST_KEYS.size():
		return "费用数据异常"
	for required_key in V06_ASSET_COST_KEYS:
		if not asset_cost.has(required_key):
			return "费用数据异常"
	for key_variant in asset_cost.keys():
		var key := str(key_variant)
		var amount_variant: Variant = asset_cost.get(key_variant, 0)
		if not V06_ASSET_COST_KEYS.has(key) or not (amount_variant is int) or int(amount_variant) < 0:
			return "费用数据异常"
	return "打出免费" if _asset_cost_total(asset_cost) <= 0 else str(player.get("cost", "条件：见卡面"))


func _choice_card_name(choice: Dictionary, private_world: Dictionary) -> String:
	var slot := int(choice.get("slot_index", -1))
	for card_variant in _array(_dictionary(private_world.get("player", {})).get("hand", [])):
		var card := _dictionary(card_variant)
		if int(card.get("slot_index", -1)) == slot:
			return str(card.get("name", "这张卡"))
	return "这张卡"


func _track_target_text(entry: Dictionary) -> String:
	if int(entry.get("selected_district", -1)) >= 0:
		return "区域%d" % (int(entry.get("selected_district", -1)) + 1)
	if int(entry.get("target_player", -1)) >= 0:
		return "玩家%d" % (int(entry.get("target_player", -1)) + 1)
	if int(entry.get("target_slot", -1)) >= 0:
		return "怪兽%d" % (int(entry.get("target_slot", -1)) + 1)
	return ""


func _track_order_text(entry: Dictionary) -> String:
	var group_size := maxi(1, int(entry.get("group_size", 1)))
	return "组%d·%d/%d" % [maxi(1, int(entry.get("group_position", 1))), maxi(1, int(entry.get("group_order", 1))), group_size]


func _group_count(entries: Array) -> int:
	var ids := {}
	for entry_variant in entries:
		var entry := _dictionary(entry_variant)
		ids[str(entry.get("group_id", entry.get("resolution_id", ids.size())))] = true
	return ids.size()


func _track_status_text(facts: Dictionary, queue_public: Dictionary) -> String:
	if bool(facts.get("counter_window_active", false)):
		return "相位响应中"
	if bool(queue_public.get("active_present", false)):
		return "当前卡牌正在展示"
	var count := int(queue_public.get("current_count", 0)) + int(queue_public.get("next_count", 0))
	return "等待玩家出牌" if count <= 0 else "公开牌轨等待%d张" % count


func _table_state_text(action: Dictionary, victory_public: Dictionary) -> String:
	var phase := str(_dictionary(action.get("card_track", {})).get("phase", "idle"))
	if str(victory_public.get("state", "idle")) != "idle":
		return "终局"
	return {"planning": "规划中", "public_bid": "牌序竞价", "lock": "锁牌中", "counter": "响应中", "resolving": "揭示中", "idle": "经营中"}.get(phase, phase)


func _primary_action_label(action: Dictionary) -> String:
	var availability := _dictionary(action.get("availability", {}))
	if not bool(availability.get("selected_district_exists", false)):
		return "选择区域"
	if bool(availability.get("can_request_region_purchase", false)):
		return "查看牌架"
	if bool(availability.get("card_submissions_open", false)):
		return "选择手牌"
	return "查看局势"


func _weather_status_text() -> String:
	if _weather == null:
		return "天气平稳"
	var forecast := _weather.forecast_view_model()
	return str(forecast.get("status_text", forecast.get("title", "天气平稳")))


func _weather_forecast_text() -> String:
	var forecast := _weather.forecast_view_model() if _weather != null else {}
	return str(forecast.get("summary", forecast.get("status_text", "暂无预警")))


func _weather_impact_text() -> String:
	var overlay := _weather.map_overlay_view_model() if _weather != null else {}
	return str(overlay.get("summary", overlay.get("impact_text", "当前无显著影响")))


func _phase_label(phase: String) -> String:
	return {"planning": "规划", "public_bid": "公开竞价", "lock": "锁牌", "counter": "响应", "resolving": "结算", "idle": "等待提交"}.get(phase, phase)


func _next_card_resolution_visual_surface(public_world: Dictionary) -> Dictionary:
	if _card_resolution_presentation == null:
		return {"events": [], "key": ""}
	var public_events := _card_resolution_presentation.public_events_after(_last_visual_event_revision)
	if public_events.is_empty():
		return {"events": [], "key": ""}
	var events: Array = []
	var latest_revision := _last_visual_event_revision
	for event_variant in public_events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		latest_revision = maxi(latest_revision, int(event.get("presentation_revision", 0)))
		events.append(_card_resolution_visual_event(event, public_world))
	if events.is_empty() or latest_revision <= _last_visual_event_revision:
		return {"events": [], "key": ""}
	_last_visual_event_revision = latest_revision
	return {
		"events": events,
		"key": "card-resolution-public:%d" % latest_revision,
	}


func _card_resolution_visual_event(event: Dictionary, public_world: Dictionary) -> Dictionary:
	var event_kind := str(event.get("event_kind", ""))
	var event_type := "card_reveal"
	match event_kind:
		"card_resolution_phase":
			event_type = "card_play"
		"card_target_check", "player_interaction":
			event_type = "target_arrow"
		"card_aftermath", "card_counter", "card_counter_window":
			event_type = "card_reveal"
	var at := _card_resolution_event_position(event, public_world)
	var from := at + Vector2(0.0, -96.0)
	if event_type == "target_arrow":
		from = at + Vector2(-112.0, 64.0)
	return {
		"type": event_type,
		"from": from,
		"to": at,
		"at": at,
		"label": _card_resolution_visual_label(str(event.get("localization_key", ""))),
		"reason": event_kind,
		"valid": str(event.get("status", "")) != "invalid",
		"progress": 1.0,
		"intensity": 1.0,
		"duration": 0.9,
	}


func _card_resolution_visual_label(localization_key: String) -> String:
	return {
		"card_resolution.phase.public_bid": "共享卡牌窗进入公开展示阶段。",
		"card_resolution.phase.lock": "共享卡牌窗进入锁牌阶段。",
		"card_resolution.phase.all_ready_public_bid": "所有席位已经完成规划。",
		"card_resolution.phase.all_ready_lock": "所有席位已经完成公开展示。",
		"card_resolution.phase.all_ready_lock_batch": "所有席位已经确认锁牌。",
		"card_resolution.phase.updated": "卡牌结算阶段已更新。",
		"card_resolution.counter_window.opened": "玩家互动响应窗口已经打开。",
		"card_resolution.target.valid": "目标有效，效果开始结算。",
		"card_resolution.target.invalid": "目标已失效，本次不产生效果。",
		"card_resolution.aftermath.resolved": "公开卡牌完成结算。",
		"card_resolution.aftermath.not_resolved": "公开卡牌未能产生效果。",
		"card_resolution.counter.resolved": "目标卡牌被反制；反制者保持隐藏。",
		"card_resolution.player_interaction.resolved": "目标玩家受到公开互动效果；手牌细节保持私密。",
	}.get(localization_key, "卡牌公开")


func _card_resolution_event_position(event: Dictionary, public_world: Dictionary) -> Vector2:
	var explicit_position: Variant = event.get("world_position", null)
	if explicit_position is Vector2:
		var position: Vector2 = explicit_position
		return position
	if explicit_position is Vector2i:
		var position_i := explicit_position as Vector2i
		return Vector2(position_i.x, position_i.y)
	var district_index := int(event.get("district_index", -1))
	var districts := _array(public_world.get("districts", []))
	if district_index >= 0 and district_index < districts.size() and districts[district_index] is Dictionary:
		var center: Variant = (districts[district_index] as Dictionary).get("center", Vector2.ZERO)
		if center is Vector2:
			var center_position: Vector2 = center
			return center_position
		if center is Vector2i:
			var center_i := center as Vector2i
			return Vector2(center_i.x, center_i.y)
	return Vector2(640.0, 360.0)


func _goal_ratio(goal_text: String) -> float:
	var values := goal_text.replace("Top-N ", "").split("/")
	if values.size() != 2:
		return 0.0
	var goal := maxi(0, int(values[1]))
	return clampf(float(int(values[0])) / float(goal), 0.0, 1.0) if goal > 0 else 0.0


func _human_card_play_offer(
	viewer_index: int,
	slot_index: int,
	_skill: Dictionary,
	eligibility: Dictionary
) -> Dictionary:
	var flow := _game_action_flow()
	if flow == null:
		return {}
	var source_revision := _ensure_action_offer_revision(viewer_index)
	var available := bool(eligibility.get("allowed", false)) \
		and bool(eligibility.get("actionable", false))
	var reason_id := str(eligibility.get("reason_code", "card-play-disabled"))
	if available:
		reason_id = "none"
	return flow.human_card_play_offer(
		viewer_index,
		slot_index,
		source_revision,
		available,
		reason_id,
		_selected_region_id(),
		_selection.selected_card_resolution_id if _selection != null else -1
	)


func _card_group_offer(
	action_id: String,
	resolution_id: int,
	available: bool,
	disabled_reason_id: String,
	_direction: int
) -> Dictionary:
	var flow := _game_action_flow()
	var viewer_index := _ports.authorized_viewer_index() if _ports != null else -1
	if flow == null or viewer_index < 0 or resolution_id < 0:
		return {}
	return flow.human_action_offer(
		action_id,
		_ensure_action_offer_revision(viewer_index),
		available,
		"none" if available else disabled_reason_id,
		{"resolution_id": GameActionCardBindingV1.resolution_ref(resolution_id)},
		"full",
		["action.card-group", "feedback.card-group"]
	)


func _first_available_card_offer(hand_sources: Array) -> Dictionary:
	for source_variant in hand_sources:
		if not (source_variant is Dictionary):
			continue
		var offer: Dictionary = (source_variant as Dictionary).get("game_action_offer", {}) \
			if (source_variant as Dictionary).get("game_action_offer", {}) is Dictionary else {}
		if bool(GameActionOfferV1.validation_report(offer).get("valid", false)) \
				and str(offer.get("legality_state", "")) == "available":
			return GameActionOfferV1.detached_copy(offer)
	return {}


func _viewer_queue_resolution_id(track: Dictionary) -> int:
	for source_variant in _array(track.get("queue", [])):
		if not (source_variant is Dictionary):
			continue
		var entry := _dictionary((source_variant as Dictionary).get("entry", {}))
		if bool(entry.get("is_viewer_card", false)):
			return int(entry.get("resolution_id", entry.get("queued_order", -1)))
	return -1


func _selected_region_id() -> String:
	if _ports == null or _selection == null or _selection.selected_district < 0:
		return ""
	var public_world := _ports.public_world_projection().to_dictionary()
	var districts := _array(public_world.get("districts", []))
	if _selection.selected_district >= districts.size() \
			or not (districts[_selection.selected_district] is Dictionary):
		return ""
	return str((districts[_selection.selected_district] as Dictionary).get("region_id", ""))


func _district_region_ids(public_world: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for district_variant in _array(public_world.get("districts", [])):
		var district := _dictionary(district_variant)
		var region_id := str(district.get("region_id", ""))
		if not region_id.is_empty():
			result.append(region_id)
	return result


func _current_action_context_projection(
	viewer_index: int,
	authorization_revision: int,
	source_revision: int,
	district: Dictionary,
	action: Dictionary
) -> Dictionary:
	var region_id := str(district.get("region_id", "")).strip_edges()
	var selected := not region_id.is_empty()
	var availability := _dictionary(action.get("availability", {}))
	var offers: Array = []
	var flow := _game_action_flow()
	if flow != null and selected:
		var offer := flow.human_action_offer(
			GameActionIntentV1.ACTION_DISTRICT_SUPPLY_OPEN,
			source_revision,
			true,
			"none",
			{"region_id": region_id},
			"full",
			["action.district-supply.open", "feedback.district-supply.open"]
		)
		if bool(GameActionOfferV1.validation_report(offer).get("valid", false)):
			offers.append(offer)
	var requirements: Array = [
		_typed_requirement(
			"selected-district",
			selected,
			"none" if selected else "district-required",
			"presentation.requirement.selected-district",
			{"status": "ready" if selected else "missing"}
		),
		_typed_requirement(
			"district-purchase-window",
			bool(availability.get("can_request_region_purchase", false)),
			"none" if bool(availability.get("can_request_region_purchase", false)) else "purchase-window-unavailable",
			"presentation.requirement.district-purchase-window",
			{"status": "ready" if bool(availability.get("can_request_region_purchase", false)) else "locked"}
		),
	]
	var navigation: Array = []
	if region_id.begins_with("region."):
		navigation.append(IntelApplicationIntent.open("", region_id).to_dictionary())
	return CURRENT_ACTION_CONTEXT_PROJECTION.build({
		"schema_version": 1,
		"viewer_index": viewer_index,
		"authorization_revision": authorization_revision,
		"context_id": "action-context-district-%d" % maxi(0, int(district.get("id", 0))) if selected else "action-context-table-map",
		"source_revision": source_revision,
		"title": str(district.get("title", "当前行动")) if selected else "选择星球区域",
		"summary": str(district.get("detail", district.get("summary", "点击区域查看公开状态和牌架。"))),
		"reason_id": "none" if selected else "district-required",
		"reason_text": "" if selected else "先在地图上选择一个区域。",
		"costs": [],
		"requirements": requirements,
		"consequences": [{
			"consequence_id": "open-region-supply" if selected else "select-region",
			"message_token": "presentation.consequence.open-region-supply" if selected else "presentation.consequence.select-region",
			"arguments": {"region": region_id if selected else "none"},
		}],
		"game_action_offers": offers,
		"navigation_intents": navigation,
	})


func _selected_context_detail_projection(
	viewer_index: int,
	authorization_revision: int,
	source_revision: int,
	hand_sources: Array,
	hand_viewmodels: Array,
	track_entries: Array
) -> Dictionary:
	var selected_slot := _selection.selected_hand_slot if _selection != null else -1
	if selected_slot >= 0:
		var source := _entry_with_int(hand_sources, "slot", selected_slot)
		var viewmodel := _entry_with_int(hand_viewmodels, "slot", selected_slot)
		if not source.is_empty() and not viewmodel.is_empty():
			return _hand_context_detail_projection(
				viewer_index,
				authorization_revision,
				source_revision,
				source,
				viewmodel
			)
	var selected_resolution := _selection.selected_card_resolution_id if _selection != null else -1
	if selected_resolution >= 0:
		var track_entry := _entry_with_int(track_entries, "resolution_id", selected_resolution)
		if not track_entry.is_empty():
			return _track_context_detail_projection(
				viewer_index,
				authorization_revision,
				source_revision,
				track_entry
			)
	return {}


func _hand_context_detail_projection(
	viewer_index: int,
	authorization_revision: int,
	source_revision: int,
	source: Dictionary,
	viewmodel: Dictionary
) -> Dictionary:
	var slot := maxi(0, int(viewmodel.get("slot", source.get("slot", 0))))
	var card_source := _dictionary(source.get("card", {}))
	var skill := _dictionary(card_source.get("skill", {}))
	var machine := _dictionary(skill.get("machine", card_source.get("machine", {})))
	var effect_payload := _dictionary(machine.get("effect_payload", {}))
	var offer := _first_game_action_offer(viewmodel.get("actions", []))
	var target_ids := GameActionOfferV1.target_ids(offer) if not offer.is_empty() else {}
	var semantic_id := GameActionCardBindingV1.semantic_card_id(skill, slot)
	semantic_id = _stable_id_or_fallback(semantic_id, "card-semantic-%d" % slot)
	var instance_id := _stable_id_or_fallback(
		str(target_ids.get("card_instance_id", viewmodel.get("card_instance_ref", ""))),
		"card-instance-%d" % slot
	)
	var display_name := str(viewmodel.get("name", skill.get("display_name", skill.get("name", "卡牌"))))
	var illustration_key := str(viewmodel.get("illustration_key", "card.generic")).strip_edges()
	if illustration_key.is_empty():
		illustration_key = "card.generic"
	var disabled_reason := _stable_id_or_fallback(str(viewmodel.get("play_reason_id", "none")), "unavailable")
	if bool(viewmodel.get("actionable", false)):
		disabled_reason = "none"
	var effect_text := str(skill.get("text", skill.get("display_text", viewmodel.get("effect", "")))).strip_edges()
	if effect_text.is_empty():
		effect_text = str(viewmodel.get("effect", "")).strip_edges()
	var kind := str(skill.get("kind", card_source.get("kind", "")))
	var acquisition_kind := str(machine.get("acquisition_kind", skill.get("acquisition_kind", "")))
	var context_kind := "commodity_card" \
		if kind == "commodity" \
			or acquisition_kind == "commodity_belt_free" \
			or semantic_id.begins_with("commodity-") \
		else "normal_card"
	var content: Dictionary
	if context_kind == "commodity_card":
		var commodity_id := str(effect_payload.get("product_id", machine.get("family_id", skill.get("family_id", "commodity"))))
		content = {
			"commodity_card_instance_id": instance_id,
			"card_semantic_id": semantic_id,
			"commodity_id": _stable_id_or_fallback(commodity_id, "commodity-unknown"),
			"display_name": display_name,
			"illustration_key": illustration_key,
			"level": maxi(1, int(skill.get("rank", machine.get("rank", 1)))),
			"base_units": maxi(1, int(effect_payload.get("base_units", skill.get("rank", 1)))),
			"target_text": str(skill.get("target", viewmodel.get("target", ""))),
			"effect_text": effect_text,
			"source_text": "Player Card Dock",
			"disabled_reason_id": disabled_reason,
			"disabled_reason_text": str(viewmodel.get("block_reason", "")),
		}
	else:
		content = {
			"card_instance_id": instance_id,
			"card_semantic_id": semantic_id,
			"display_name": display_name,
			"illustration_key": illustration_key,
			"timing_text": str(skill.get("timing", "")),
			"target_text": str(skill.get("target", viewmodel.get("target", ""))),
			"effect_text": effect_text,
			"duration_text": str(skill.get("duration", "")),
			"visibility_text": "仅当前玩家",
			"keyword_tokens": _stable_token_array(skill.get("tags", [])),
			"disabled_reason_id": disabled_reason,
			"disabled_reason_text": str(viewmodel.get("block_reason", "")),
		}
	return CONTEXT_DETAIL_PROJECTION.build({
		"schema_version": 1,
		"viewer_index": viewer_index,
		"authorization_revision": authorization_revision,
		"source_revision": source_revision,
		"context_id": "hand-card-detail-%d" % slot,
		"context_kind": context_kind,
		"visibility_scope": "viewer_private",
		"title": display_name,
		"subtitle": str(viewmodel.get("why", viewmodel.get("type", ""))),
		"content": content,
		"navigation_intents": [],
	})


func _track_context_detail_projection(
	viewer_index: int,
	authorization_revision: int,
	source_revision: int,
	entry: Dictionary
) -> Dictionary:
	var resolution_id := maxi(0, int(entry.get("resolution_id", 0)))
	var card_name := str(entry.get("card_name", entry.get("label", "公共牌"))).strip_edges()
	if card_name.is_empty():
		card_name = "公共牌"
	var navigation := _typed_navigation_intents(entry.get("deep_links", []))
	return CONTEXT_DETAIL_PROJECTION.build({
		"schema_version": 1,
		"viewer_index": viewer_index,
		"authorization_revision": authorization_revision,
		"source_revision": source_revision,
		"context_id": "public-track-detail-%d" % resolution_id,
		"context_kind": "public_track",
		"visibility_scope": "public",
		"title": card_name,
		"subtitle": str(entry.get("state", "公共牌轨")),
		"content": {
			"resolution_id": "resolution.%d" % resolution_id,
			"card_semantic_id": _stable_id_or_fallback(str(entry.get("card_semantic_id", entry.get("card_name", ""))), "public-track-card-%d" % resolution_id),
			"display_name": card_name,
			"illustration_key": str(entry.get("illustration_key", "card.public-track")),
			"public_status": _stable_id_or_fallback(str(entry.get("kind", "public")), "public"),
			"summary": str(entry.get("summary", "")),
			"detail": str(entry.get("full_detail", entry.get("detail", entry.get("tooltip", "")))),
			"keyword_tokens": _stable_token_array(entry.get("badges", [])),
		},
		"navigation_intents": navigation,
	})


func _public_feedback_projections(
	entries: Array,
	viewer_index: int,
	authorization_revision: int,
	visibility_scope: String
) -> Array:
	var result: Array = []
	for index in range(entries.size()):
		var entry := _dictionary(entries[index])
		var message := str(entries[index]) if entry.is_empty() else str(entry.get("message", entry.get("detail", "")))
		message = message.strip_edges()
		if message.is_empty():
			continue
		var revision := maxi(0, int(entry.get("source_revision", index)))
		var reason_id := _stable_id_or_fallback(str(_dictionary(entry.get("public_values", {})).get("reason_code", "none")), "none")
		var severity := _feedback_severity(message)
		if severity == "failure" and reason_id == "none":
			reason_id = "action-rejected"
		var message_token := _stable_id_or_fallback(
			str(entry.get("localization_key", "feedback.viewer-private" if visibility_scope == "viewer_private" else "feedback.public")),
			"feedback.public"
		)
		var public_identity := "%s|%d|%d|%s" % [visibility_scope, revision, index, message]
		var projection := PUBLIC_FEEDBACK_PROJECTION.build({
			"schema_version": 1,
			"viewer_index": viewer_index,
			"authorization_revision": authorization_revision,
			"receipt_id": "feedback-%s-%s" % [visibility_scope.replace("_", "-"), public_identity.sha256_text().left(16)],
			"revision": revision,
			"severity": severity,
			"reason_id": reason_id,
			"message_token": message_token,
			"arguments": {"message": message},
			"public_or_viewer_private": visibility_scope,
			"history_link": {},
		})
		if not projection.is_empty():
			result.append(projection)
	return result


func _region_supply_popup_projection(
	surface: Dictionary,
	district: Dictionary,
	viewer_index: int,
	authorization_revision: int,
	source_revision: int
) -> Dictionary:
	if not bool(surface.get("visible", false)) or not (surface.get("snapshot", {}) is Dictionary):
		return {}
	var snapshot := _dictionary(surface.get("snapshot", {}))
	var region_id := str(surface.get("region_id", "")).strip_edges()
	var selected_region_id := str(district.get("region_id", "")).strip_edges()
	var region_index := int(surface.get("district_index", district.get("id", -1)))
	if region_id.is_empty() or region_index < 0 or region_id != selected_region_id:
		return {}
	var rack_revision := _stable_revision_number(str(surface.get("rack_source_revision", "")), source_revision)
	var card_rows: Array = []
	var allowed_actions: Array = []
	var allowed_offer_fingerprints: Dictionary = {}
	var card_occurrence_by_semantic_id: Dictionary = {}
	var flow := _game_action_flow()
	for index in range(_array(snapshot.get("cards", [])).size()):
		var card := _dictionary(_array(snapshot.get("cards", []))[index])
		var card_id := str(card.get("card_id", card.get("card_name", ""))).strip_edges()
		if not SemanticWireV1.is_stable_id(card_id):
			continue
		var card_occurrence := int(card_occurrence_by_semantic_id.get(card_id, 0))
		card_occurrence_by_semantic_id[card_id] = card_occurrence + 1
		var preview := _dictionary(card.get("preview", {}))
		var primary_action_id := str(preview.get("primary_action_id", ""))
		var semantic_action_id := GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE \
			if primary_action_id == "district_supply_preview_card" \
			else GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE
		var offer: Dictionary = {}
		if flow != null and primary_action_id in [
			"district_supply_preview_card",
			"district_supply_purchase_card",
		]:
			offer = flow.human_surface_action_offer(
				semantic_action_id,
				{"region_id": region_id, "card_id": card_id},
				"full",
				["action.district-supply", "feedback.district-supply"]
			)
		if bool(GameActionOfferV1.validation_report(offer).get("valid", false)):
			var offer_revision := int(offer.get("source_revision", source_revision))
			if offer_revision == source_revision:
				var offer_fingerprint := str(offer.get("offer_fingerprint", ""))
				if not allowed_offer_fingerprints.has(offer_fingerprint):
					allowed_offer_fingerprints[offer_fingerprint] = true
					allowed_actions.append(offer)
			else:
				offer = {}
		var actionable := not offer.is_empty()
		var reason_id := _stable_id_or_fallback(
			str(preview.get("action_reason_code", "browse-only")),
			"browse-only"
		)
		if actionable:
			reason_id = "none"
		var illustration_key := str(card.get("illustration_key", "card.region-supply")).strip_edges()
		if illustration_key.is_empty():
			illustration_key = "card.region-supply"
		card_rows.append({
			"rack_card_id": _stable_id_or_fallback(
				"%s-%s-rack-copy-%d" % [region_id, card_id, card_occurrence],
				"rack-card-%d" % index
			),
			"card_semantic_id": card_id,
			"display_name": str(card.get("display_name", card_id)),
			"illustration_key": illustration_key,
			"costs": [{
				"cost_id": "purchase-cash",
				"resource_id": "cash",
				"amount_units": maxi(0, int(card.get("price", 0))),
				"display_token": "currency.cash",
			}],
			"availability": {
				"state_id": "available" if actionable else "disabled",
				"reason_id": reason_id,
				"reason_text": str(preview.get("status_text", preview.get("buy_tooltip", ""))),
			},
			"detail_context_id": "region-card-detail-%d" % index,
		})
	var rack_cards: Array = []
	for row_variant in card_rows:
		var row := _dictionary(row_variant)
		row["source_revision"] = source_revision
		row["rack_revision"] = rack_revision
		rack_cards.append(row)
	var facility_slots: Array = []
	var infrastructure := _dictionary(district.get("region_infrastructure", {}))
	for index in range(_array(infrastructure.get("facilities", [])).size()):
		var facility := _dictionary(_array(infrastructure.get("facilities", []))[index])
		facility_slots.append({
			"slot_id": "facility-slot-%d" % index,
			"display_name": str(facility.get("facility_type", facility.get("display_name", "设施位"))),
			"public_status": "occupied",
			"is_occupied": true,
			"detail_context_id": "region-facility-detail-%d" % index,
		})
	var navigation: Array = []
	if region_id.begins_with("region."):
		navigation.append(IntelApplicationIntent.open("", region_id).to_dictionary())
	return REGION_SUPPLY_POPUP_PROJECTION.build({
		"schema_version": 1,
		"viewer_index": viewer_index,
		"authorization_revision": authorization_revision,
		"region_id": region_id,
		"region_index": region_index,
		"display_name": str(snapshot.get("title", district.get("title", "区域牌架"))),
		"source_revision": source_revision,
		"rack_revision": rack_revision,
		"public_status": "open",
		"availability": {"state_id": "available", "reason_id": "none", "reason_text": ""},
		"monster_price_pressure": int(district.get("monster_price_pressure", district.get("monster_pressure", 0))),
		"facility_slots": facility_slots,
		"rack_cards": rack_cards,
		"requirements": [_typed_requirement("rack-revision-bound", true, "none", "presentation.requirement.rack-revision-bound", {"revision": rack_revision})],
		"allowed_actions": allowed_actions,
		"allowed_navigation_intents": navigation,
	})


func _typed_requirement(
	requirement_id: String,
	satisfied: bool,
	reason_id: String,
	message_token: String,
	arguments: Dictionary
) -> Dictionary:
	return {
		"requirement_id": requirement_id,
		"satisfied": satisfied,
		"reason_id": reason_id,
		"message_token": message_token,
		"arguments": arguments.duplicate(true),
	}


func _entry_with_int(entries: Array, key: String, expected: int) -> Dictionary:
	for entry_variant in entries:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get(key, -1)) == expected:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _first_game_action_offer(entries_variant: Variant) -> Dictionary:
	for entry_variant in _array(entries_variant):
		var entry := _dictionary(entry_variant)
		var offer := _dictionary(entry.get("game_action_offer", {}))
		if bool(GameActionOfferV1.validation_report(offer).get("valid", false)):
			return offer
	return {}


func _typed_navigation_intents(entries_variant: Variant) -> Array:
	var result: Array = []
	for entry_variant in _array(entries_variant):
		var entry := _dictionary(entry_variant)
		var intent := _dictionary(entry.get("application_intent", entry.get("navigation_intent", {})))
		if IntelApplicationIntent.from_dictionary(intent) != null:
			result.append(intent)
	return result


func _stable_token_array(value: Variant) -> Array:
	var result: Array = []
	for index in range(_array(value).size()):
		var token := _stable_id_or_fallback(str(_array(value)[index]), "tag-%d" % index)
		if not result.has(token):
			result.append(token)
	return result


func _stable_id_or_fallback(value: String, fallback: String) -> String:
	var normalized := value.strip_edges().to_lower()
	var output := ""
	var previous_separator := false
	for index in range(normalized.length()):
		var code := normalized.unicode_at(index)
		var valid := (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if valid:
			output += normalized[index]
			previous_separator = false
		elif not output.is_empty() and not previous_separator:
			output += "-"
			previous_separator = true
	output = output.trim_suffix("-")
	if output.is_empty() or not (output.unicode_at(0) >= 97 and output.unicode_at(0) <= 122):
		output = fallback
	return output.left(160).trim_suffix("-")


func _stable_revision_number(value: String, fallback: int) -> int:
	var digest := value.sha256_text() if value.is_empty() or not value.is_valid_hex_number(false) else value
	var prefix := digest.left(12)
	return maxi(0, prefix.hex_to_int()) if not prefix.is_empty() else maxi(0, fallback)


func _feedback_severity(message: String) -> String:
	if message.contains("失败") or message.contains("无法") or message.contains("不能") or message.contains("未执行"):
		return "failure"
	if message.contains("警告") or message.contains("等待") or message.contains("请先"):
		return "warning"
	if message.contains("成功") or message.contains("完成") or message.begins_with("已"):
		return "success"
	return "informational"


func _ensure_action_offer_revision(viewer_index: int) -> int:
	var current := int(_action_offer_revision_by_viewer.get(viewer_index, 0))
	if current > 0:
		return current
	_action_offer_revision += 1
	_action_offer_revision_by_viewer[viewer_index] = _action_offer_revision
	return _action_offer_revision


func _game_action_flow() -> TablePlayerActionApplicationFlowController:
	return get_node_or_null("../TablePlayerActionApplicationFlowController") \
		as TablePlayerActionApplicationFlowController


func _viewer_is_authorized(viewer_index: int) -> bool:
	return _ports != null and viewer_index >= 0 and _ports.can_view_private_subject(viewer_index, viewer_index)


func _format_time(seconds_value: float) -> String:
	var total := maxi(0, int(floor(seconds_value)))
	return "%02d:%02d" % [int(total / 60.0), total % 60]


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in _array(value):
		var text := str(entry).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result
