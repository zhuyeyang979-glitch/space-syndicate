@tool
extends Node
class_name TablePresentationViewModelQuery

const HAND_LIMIT := 5
const COMMODITY_SUSHI_TRACK_SERVICE_SCRIPT := preload("res://scripts/runtime/commodity_sushi_track_runtime_service.gd")

var _ports: TablePresentationQueryPorts
var _selection: TableSelectionState
var _table_viewmodel: GameTableViewModelRuntimeService
var _card_catalog: CardRuntimeCatalogService
var _eligibility_facts: CardPlayEligibilityWorldBridge
var _eligibility: CardPlayEligibilityRuntimeService
var _region_supply: RegionSupplyRuntimeController
var _infrastructure: RegionInfrastructureRuntimeController
var _weather: WeatherPresentationRuntimeService
var _victory: VictoryControlRuntimeController
var _contract: ContractRuntimeController
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
var _player_seat_sources: PlayerSeatPublicSourceService
var _commodity_sushi_track: COMMODITY_SUSHI_TRACK_SERVICE_SCRIPT
var _revision := 0
var _compose_count := 0
var _last_visual_event_revision := 0


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
	contract: ContractRuntimeController,
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
	player_seat_sources: PlayerSeatPublicSourceService = null,
	commodity_sushi_track: COMMODITY_SUSHI_TRACK_SERVICE_SCRIPT = null
) -> void:
	_ports = ports
	_selection = selection
	_table_viewmodel = table_viewmodel
	_card_catalog = card_catalog
	_eligibility_facts = eligibility_facts
	_eligibility = eligibility
	_region_supply = region_supply
	_infrastructure = infrastructure
	_weather = weather
	_victory = victory
	_contract = contract
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
	_player_seat_sources = player_seat_sources
	_commodity_sushi_track = commodity_sushi_track


func compose_table_state(viewer_index: int, include_full: bool) -> Dictionary:
	if not _viewer_is_authorized(viewer_index) or _table_viewmodel == null:
		return {}
	var public_projection := _ports.public_world_projection()
	var public_world := public_projection.to_dictionary()
	var private_world := _ports.private_world_projection(viewer_index, viewer_index).to_dictionary()
	var action := _ports.action_projection(viewer_index).to_dictionary()
	if public_world.is_empty() or private_world.is_empty() or action.is_empty():
		return {}
	var district := _selected_district_source(viewer_index, public_world, action)
	var actions := _action_entries(viewer_index, public_world, action, district)
	var logs := _ports.recent_public_log_messages(6)
	var visual_surface := _next_card_resolution_visual_surface(public_world)
	var table_source := {
		"selection_context": {
			"revision": int(_selection.snapshot().get("revision", 0)) if _selection != null else 0,
		},
		"top_bar": _top_bar_source(viewer_index, public_world, private_world, action, district),
		"planet": _planet_source(public_world, action, district, public_projection, viewer_index),
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
		"hand_cards": _hand_card_sources(viewer_index, private_world),
		"track": _card_track_source(viewer_index, action),
		"selected_hand_slot": _selection.selected_hand_slot if _selection != null else -1,
		"selected_resolution_id": _selection.selected_card_resolution_id if _selection != null else -1,
		"district": district,
		"fallback_why": str(district.get("detail", "先选择区域或卡牌。")),
		"fallback_requirements": _district_requirement_chips(action),
		"fallback_actions": actions,
		"fallback_deep_links": [
			{"id": "detail_region", "label": "区域详情"},
			{"id": "detail_cards", "label": "卡牌/牌架"},
			{"id": "intel", "label": "情报详情", "application_intent": IntelApplicationIntent.open("", str(district.get("region_id", ""))).to_dictionary()},
		],
		"logs": logs,
	}
	var composed := _table_viewmodel.compose_table_source({
		"table_source": table_source,
		"card_surfaces": card_surfaces,
	})
	if include_full:
		composed["viewer_private_feedback"] = _ports.recent_viewer_private_feedback(viewer_index, 6)
	_revision += 1
	_compose_count += 1
	return TablePresentationPureDataPolicy.detached_copy(composed) as Dictionary


func hand_presentation_sources_for_viewer(viewer_index: int) -> Array:
	if _ports == null:
		return []
	var private_world := _ports.private_world_projection(viewer_index, viewer_index).to_dictionary()
	return TablePresentationPureDataPolicy.detached_copy(_hand_card_sources(viewer_index, private_world)) as Array


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
		"uses_public_player_seat_projection": _player_seat_sources != null,
		"uses_public_commodity_sushi_track_projection": _commodity_sushi_track != null,
		"supports_decision_kinds": ["monster_wager", "contract_response", "discard_purchase", "monster_target_choice", "player_target_choice"],
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
		var card_name := str(private_card.get("name", private_card.get("card_id", "")))
		if slot_index < 0 or card_name.is_empty():
			continue
		var skill := _catalog_skill(card_name, private_card)
		result.append({
			"slot": slot_index,
			"card": _card_source(skill),
			"eligibility": _card_eligibility(viewer_index, skill),
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
		"history": _enriched_track_entries(history_rows, viewer_index),
		"active": _enriched_track_entry(_dictionary(queue_public.get("active", {})), viewer_index),
		"queue": _enriched_track_entries(_array(queue_public.get("current", [])), viewer_index),
		"next_queue": _enriched_track_entries(_array(queue_public.get("next", [])), viewer_index),
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


func _enriched_track_entries(entries: Array, viewer_index: int) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result.append(_enriched_track_entry(entry_variant as Dictionary, viewer_index))
	return result


func _enriched_track_entry(entry: Dictionary, _viewer_index: int) -> Dictionary:
	if entry.is_empty():
		return {}
	var card_name := str(entry.get("card_name", _dictionary(entry.get("skill", {})).get("name", "")))
	var skill := _catalog_skill(card_name, _dictionary(entry.get("skill", {})))
	var public_entry := TablePresentationPureDataPolicy.detached_copy(entry) as Dictionary
	public_entry["is_viewer_card"] = str(entry.get("visibility_scope", "")) == "owner_private"
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
		"can_reorder": bool(public_entry.get("is_viewer_card", false)) and _card_resolution != null and _card_resolution.submissions_open(),
	}


func _card_source(skill: Dictionary) -> Dictionary:
	var card_name := str(skill.get("name", skill.get("card_id", "")))
	var definition := _catalog_skill(card_name, skill)
	return {
		"card_name": card_name,
		"skill": definition,
		"display_name": str(definition.get("display_name", card_name)),
		"display_text": str(definition.get("text", definition.get("display_text", ""))),
		"tag_text": str(definition.get("tag_text", "")),
		"rank": maxi(1, int(definition.get("rank", _card_catalog.rank(card_name) if _card_catalog != null else 1))),
		"price": maxi(0, int(definition.get("price", definition.get("purchase_cost", 0)))),
		"play_requirement_text": str(definition.get("play_requirement_text", "条件：见卡面")),
	}


func _card_eligibility(viewer_index: int, skill: Dictionary) -> Dictionary:
	if _eligibility_facts == null or _eligibility == null:
		return {"allowed": false, "actionable": false, "reason_code": "service_missing"}
	var facts := _eligibility_facts.build_facts(viewer_index, skill, {
		"selected_district": _selection.selected_district if _selection != null else -1,
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


func _action_entries(viewer_index: int, _public_world: Dictionary, action: Dictionary, district: Dictionary) -> Array:
	var actions := _district_actions(action, _array(district.get("rack", [])))
	var private_world := _ports.private_world_projection(viewer_index, viewer_index).to_dictionary()
	if not _hand_card_sources(viewer_index, private_world).is_empty():
		actions.append({"id": "play", "label": "出牌", "state": "选择手牌", "kind": "play_card", "disabled": false, "tooltip": "选择底部手牌查看合法目标。"})
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
	}


func _player_board_source(viewer_index: int, public_world: Dictionary, private_world: Dictionary, action: Dictionary, district: Dictionary, actions: Array) -> Dictionary:
	var player := _dictionary(private_world.get("player", {}))
	var top := _top_bar_source(viewer_index, public_world, private_world, action, district)
	var hand_count := _array(player.get("hand", [])).size()
	var availability := _dictionary(action.get("availability", {}))
	var rack_count := _array(district.get("rack", [])).size()
	return {
		"title": "玩家板｜手牌",
		"hint": "私密手牌和当前行动固定在底部玩家板。",
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
			{"id": "play", "label": "出牌", "active": hand_count > 0 and bool(availability.get("card_submissions_open", false)), "state": "ready" if hand_count > 0 else "waiting", "tooltip": "选择一张私密手牌。"},
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
		"contract_response":
			return _contract.decision_snapshot(viewer_index) if _contract != null else {}
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
		actions.append({"id": "target_monster_%d" % index, "label": "怪%d %s" % [index + 1, str(actor.get("name", "怪兽"))], "disabled": bool(actor.get("down", false)), "tooltip": "指定目标；目标会公开，出牌者仍隐藏。"})
	actions.append({"id": "target_monster_cancel", "label": "取消"})
	return {"id": "monster_target_choice", "kind": "monster_target_choice", "title": "请选择目标怪兽", "body": "%s需要先指定目标怪兽。" % card_name, "actions": actions, "choice": {"mode": "monster_target", "target_count": roster.size()}}


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
		actions.append({"id": "target_player_%d" % index, "label": str(player.get("public_player_name", "玩家%d" % (index + 1))), "tooltip": "目标会公开，出牌者仍隐藏。"})
	actions.append({"id": "target_player_cancel", "label": "取消"})
	return {"id": "player_target_choice", "kind": "player_target_choice", "title": "请选择目标玩家", "body": "%s会影响一名玩家。" % card_name, "actions": actions, "choice": {"mode": "player_target", "target_count": maxi(0, players.size() - 1)}}


func action_choices(viewer_index: int) -> Dictionary:
	if _target_choice == null:
		return {}
	var snapshot := _target_choice.private_snapshot(viewer_index)
	return _dictionary(snapshot.get("choices", {}))


func _planet_source(
	public_world: Dictionary,
	_action: Dictionary,
	district: Dictionary,
	public_projection: WorldSessionPublicProjection,
	viewer_index: int
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
		"public_player_seat_sources": _player_seat_sources.compose_sources(public_projection, viewer_index) if _player_seat_sources != null else [],
		"selected_map_layer_focus": _selection.selected_map_layer_focus if _selection != null else "all",
	}


func _bid_board(viewer_index: int, action: Dictionary) -> Dictionary:
	var track := _card_track_source(viewer_index, action)
	var phase := str(track.get("group_phase", "idle"))
	var remaining := int(ceil(float(track.get("group_phase_remaining_seconds", 0.0))))
	return {
		"title": "卡牌组确认",
		"phase": "%s %ds" % [_phase_label(phase), remaining] if remaining > 0 else _phase_label(phase),
		"status": str(track.get("status_text", "等待提交")),
		"active": phase in ["planning", "public_bid", "lock"],
		"chips": [{"label": "本阶段", "state": _phase_label(phase), "active": phase != "idle"}],
		"track_links": [],
		"actions": [{"id": "card_group_ready", "label": "完成本阶段", "disabled": phase not in ["planning", "public_bid", "lock"], "tooltip": "确认后等待其他席位。"}],
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
	return fallback.duplicate(true)


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
