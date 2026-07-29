extends SceneTree

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const ROSTER := preload("res://scripts/presentation/public_player_roster_projection_v1.gd")
const INSPECTION := preload("res://scripts/presentation/player_inspection_projection_v1.gd")
const REGION := preload("res://scripts/presentation/region_supply_popup_projection_v1.gd")
const ACTION_CONTEXT := preload("res://scripts/presentation/current_action_context_projection_v1.gd")
const FEEDBACK := preload("res://scripts/presentation/public_feedback_projection_v1.gd")
const DETAIL := preload("res://scripts/presentation/context_detail_projection_v1.gd")
const MODE := preload("res://scripts/presentation/table_interaction_mode_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_test_public_player_roster()
	_test_player_inspection()
	_test_region_supply_popup()
	_test_current_action_context()
	_test_public_feedback()
	_test_context_detail_closed_union()
	_test_table_interaction_modes()
	_finish()


func _test_public_player_roster() -> void:
	var source := _roster_source()
	var projection := ROSTER.build(source)
	_expect(_valid(ROSTER, projection), "roster exact typed projection validates")
	_expect(ROSTER.matches_viewer_authorization(projection, 0, 3), "roster accepts exact viewer authorization")
	_expect(not ROSTER.matches_viewer_authorization(projection, 1, 3), "roster rejects the wrong viewer")
	_expect(not ROSTER.matches_viewer_authorization(projection, 0, 4), "roster rejects stale authorization")
	var players := projection.get("players", []) as Array
	_expect(players.size() == 3 and int((players[0] as Dictionary).get("public_order_index", -1)) == 0 and int((players[2] as Dictionary).get("public_order_index", -1)) == 2, "roster preserves authored public order without local rotation")
	var detached := ROSTER.detached_copy(projection)
	((detached.get("players", []) as Array)[0] as Dictionary)["display_name"] = "changed"
	_expect(str(((projection.get("players", []) as Array)[0] as Dictionary).get("display_name", "")) == "你", "roster detached copy cannot mutate source")
	var unsorted := source.duplicate(true)
	var unsorted_players := unsorted.get("players") as Array
	var swap: Variant = unsorted_players[0]
	unsorted_players[0] = unsorted_players[1]
	unsorted_players[1] = swap
	_expect(ROSTER.build(unsorted).is_empty(), "roster rejects screen-driven order changes")
	var duplicate_inspection := source.duplicate(true)
	((duplicate_inspection.get("players") as Array)[1] as Dictionary)["is_inspected"] = true
	_expect(ROSTER.build(duplicate_inspection).is_empty(), "roster enforces one inspected player")
	var private_leak := source.duplicate(true)
	((private_leak.get("players") as Array)[1] as Dictionary)["cash"] = 999
	_expect(ROSTER.build(private_leak).is_empty(), "roster rejects rival cash")
	var node_value := Node.new()
	var node_source := source.duplicate(true)
	((node_source.get("players") as Array)[0] as Dictionary)["avatar_key"] = node_value
	_expect(ROSTER.build(node_source).is_empty(), "roster rejects Node values")
	node_value.free()


func _test_player_inspection() -> void:
	var source := {
		"schema_version": INSPECTION.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"source_revision": 7,
		"player_id": "player.1",
		"display_name": "对手",
		"role_display_name": "星港商人",
		"avatar_key": "avatar.player-1",
		"accent": "accent.amber",
		"public_status": "active",
		"public_assets_summary": "公开资产 2",
		"public_facilities_summary": "公开设施 1",
		"public_military_summary": "公开军力 0",
		"public_monster_summary": "公开怪兽 0",
		"public_history_links": [{
			"history_entry_id": "card-history:1",
			"label": "公开历史",
			"navigation_intent": _intel_navigation("card-history:1", ""),
		}],
		"allowed_navigation_intents": [_table_navigation("inspect.player.1")],
	}
	var projection := INSPECTION.build(source)
	_expect(_valid(INSPECTION, projection), "player inspection public projection validates")
	_expect(INSPECTION.matches_viewer_authorization(projection, 0, 3), "player inspection is viewer authorized")
	_expect(not JSON.stringify(projection).contains("999999"), "player inspection carries no injected rival value")
	var private_leak := source.duplicate(true)
	private_leak["normal_hand"] = ["secret"]
	_expect(INSPECTION.build(private_leak).is_empty(), "player inspection rejects rival hand")
	var invalid_navigation := source.duplicate(true)
	invalid_navigation["allowed_navigation_intents"] = [{"method_name": "open_secret"}]
	_expect(INSPECTION.build(invalid_navigation).is_empty(), "player inspection rejects method-name navigation")
	var malformed_history := source.duplicate(true)
	((malformed_history.get("public_history_links") as Array)[0] as Dictionary)["private_target"] = "player.0"
	_expect(INSPECTION.build(malformed_history).is_empty(), "player inspection history links are a closed public shape")


func _test_region_supply_popup() -> void:
	var source := _region_source()
	var projection := REGION.build(source)
	_expect(_valid(REGION, projection), "region supply popup exact projection validates")
	_expect(REGION.matches_viewer_authorization(projection, 0, 3), "region popup accepts exact viewer authorization")
	var rack_card := ((projection.get("rack_cards", []) as Array)[0] as Dictionary)
	_expect(int(projection.get("rack_revision", -1)) == 5 and int(rack_card.get("rack_revision", -2)) == 5, "region popup binds root and rack row to one rack revision")
	var detached := REGION.detached_copy(projection)
	((detached.get("rack_cards") as Array)[0] as Dictionary)["display_name"] = "changed"
	_expect(str(rack_card.get("display_name", "")) == "轨道工厂", "region popup detached copy cannot refresh or mutate rack data")
	var stale_rack := source.duplicate(true)
	((stale_rack.get("rack_cards") as Array)[0] as Dictionary)["rack_revision"] = 6
	_expect(REGION.build(stale_rack).is_empty(), "region popup rejects mixed rack revisions")
	var card_action := source.duplicate(true)
	card_action["allowed_actions"] = [_offer(ACTION_INTENT.ACTION_CARD_PLAY, 7)]
	_expect(REGION.build(card_action).is_empty(), "region popup rejects card-play offers")
	var future_rack := source.duplicate(true)
	future_rack["future_rack"] = ["secret"]
	_expect(REGION.build(future_rack).is_empty(), "region popup rejects future rack leakage")


func _test_current_action_context() -> void:
	var source := {
		"schema_version": ACTION_CONTEXT.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"context_id": "context.region-supply",
		"source_revision": 7,
		"title": "地区行动",
		"summary": "选择报价或购买。",
		"reason_id": "none",
		"reason_text": "",
		"costs": [_cost()],
		"requirements": [_requirement(true)],
		"consequences": [{
			"consequence_id": "consequence.purchase",
			"message_token": "feedback.purchase.preview",
			"arguments": {"count": 1},
		}],
		"game_action_offers": [_offer(ACTION_INTENT.ACTION_DISTRICT_SUPPLY_OPEN, 7)],
		"navigation_intents": [_table_navigation("action.region.detail")],
	}
	var projection := ACTION_CONTEXT.build(source)
	_expect(_valid(ACTION_CONTEXT, projection), "current action context exact projection validates")
	_expect(ACTION_CONTEXT.matches_viewer_authorization(projection, 0, 3), "current action context is viewer authorized")
	var card_action := source.duplicate(true)
	card_action["game_action_offers"] = [_offer(ACTION_INTENT.ACTION_CARD_PLAY, 7)]
	_expect(ACTION_CONTEXT.build(card_action).is_empty(), "compact action context cannot become a second card action surface")
	var stale_offer := source.duplicate(true)
	stale_offer["game_action_offers"] = [_offer(ACTION_INTENT.ACTION_DISTRICT_SUPPLY_OPEN, 8)]
	_expect(ACTION_CONTEXT.build(stale_offer).is_empty(), "current action context rejects stale offers")
	var callable_source := source.duplicate(true)
	callable_source["summary"] = Callable(self, "_run")
	_expect(ACTION_CONTEXT.build(callable_source).is_empty(), "current action context rejects Callable values")
	var node_path_source := source.duplicate(true)
	node_path_source["reason_text"] = NodePath("/root/Main")
	_expect(ACTION_CONTEXT.build(node_path_source).is_empty(), "current action context rejects NodePath values")
	var method_source := source.duplicate(true)
	((method_source.get("requirements") as Array)[0] as Dictionary)["arguments"] = {"method_name": "submit"}
	_expect(ACTION_CONTEXT.build(method_source).is_empty(), "current action context rejects method-name fields")


func _test_public_feedback() -> void:
	var source := {
		"schema_version": FEEDBACK.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"receipt_id": "receipt.purchase-1",
		"revision": 7,
		"severity": FEEDBACK.SEVERITY_FAILURE,
		"reason_id": "insufficient-funds",
		"message_token": "feedback.purchase.failed",
		"arguments": {"region_name": "北境", "amount": 3},
		"public_or_viewer_private": FEEDBACK.VISIBILITY_VIEWER_PRIVATE,
		"history_link": {
			"link_id": "history.purchase-1",
			"label": "查看详情",
			"navigation_intent": _intel_navigation("card-history:1", ""),
		},
	}
	var projection := FEEDBACK.build(source)
	_expect(_valid(FEEDBACK, projection), "public feedback typed receipt projection validates")
	_expect(str(projection.get("reason_id", "")) == "insufficient-funds", "feedback keeps typed failure reason id")
	var missing_reason := source.duplicate(true)
	missing_reason["reason_id"] = "none"
	_expect(FEEDBACK.build(missing_reason).is_empty(), "failure feedback requires a typed reason id")
	var invalid_severity := source.duplicate(true)
	invalid_severity["severity"] = "debug"
	_expect(FEEDBACK.build(invalid_severity).is_empty(), "feedback severity is closed")
	var private_leak := source.duplicate(true)
	private_leak["arguments"] = {"cash": 999}
	_expect(FEEDBACK.build(private_leak).is_empty(), "feedback arguments reject private cash")
	var object_argument := source.duplicate(true)
	object_argument["arguments"] = {"bad": RefCounted.new()}
	_expect(FEEDBACK.build(object_argument).is_empty(), "feedback rejects Object arguments")


func _test_context_detail_closed_union() -> void:
	for context_kind in DETAIL.CONTEXT_KINDS:
		var projection := DETAIL.build(_detail_source(str(context_kind)))
		_expect(_valid(DETAIL, projection), "context detail kind %s validates" % context_kind)
		_expect(str(projection.get("context_kind", "")) == str(context_kind), "context detail kind %s stays explicit" % context_kind)
		_expect(not WIRE.contains_key_recursive(projection, ["actions", "game_action_offers", "bound_actions"]), "context detail kind %s owns no action offer" % context_kind)
	var mismatched := _detail_source(DETAIL.KIND_NORMAL_CARD)
	mismatched["context_kind"] = DETAIL.KIND_PUBLIC_TRACK
	mismatched["visibility_scope"] = "public"
	_expect(DETAIL.build(mismatched).is_empty(), "context detail rejects content from another closed kind")
	var raw_payload := _detail_source(DETAIL.KIND_REGION_FACILITY)
	(raw_payload.get("content") as Dictionary)["raw_payload"] = {"anything": "forbidden"}
	_expect(DETAIL.build(raw_payload).is_empty(), "context detail rejects arbitrary raw payload")
	var callable_source := _detail_source(DETAIL.KIND_NORMAL_CARD)
	(callable_source.get("content") as Dictionary)["effect_text"] = Callable(self, "_run")
	_expect(DETAIL.build(callable_source).is_empty(), "context detail rejects Callable content")
	var node_path_source := _detail_source(DETAIL.KIND_NORMAL_CARD)
	(node_path_source.get("content") as Dictionary)["target_text"] = NodePath("/root/Main")
	_expect(DETAIL.build(node_path_source).is_empty(), "context detail rejects NodePath content")
	var tampered := DETAIL.build(_detail_source(DETAIL.KIND_PUBLIC_TRACK))
	(tampered.get("content") as Dictionary)["summary"] = "tampered"
	_expect(not _valid(DETAIL, tampered), "context detail fingerprint rejects post-build mutation")


func _test_table_interaction_modes() -> void:
	_expect(MODE.MODE_IDS.size() == 8, "interaction mode schema exposes exactly eight closed modes")
	var projections := {}
	for mode_id in MODE.MODE_IDS:
		var projection := MODE.build(_mode_source(str(mode_id)))
		projections[str(mode_id)] = projection
		_expect(_valid(MODE, projection), "interaction mode %s validates" % mode_id)
	_expect(MODE.region_click_disposition(projections[MODE.TABLE_MAP_MODE], "region.1") == MODE.REGION_CLICK_OPEN_POPUP, "table map region click opens supply popup")
	_expect(MODE.region_click_disposition(projections[MODE.REGION_SUPPLY_POPUP_MODE], "region.1", "region.0") == MODE.REGION_CLICK_SWITCH_POPUP, "popup mode switches directly to another region")
	_expect(MODE.region_click_disposition(projections[MODE.REGION_SUPPLY_POPUP_MODE], "region.0", "region.0") == MODE.REGION_CLICK_CLOSE_POPUP, "popup mode closes on current region")
	_expect(MODE.region_click_disposition(projections[MODE.CARD_TARGET_SELECTION_MODE], "region.1") == MODE.REGION_CLICK_SUBMIT_TARGET, "target-selection click submits only a target")
	_expect(MODE.region_click_disposition(projections[MODE.CARD_TARGET_SELECTION_MODE], "region.1") != MODE.REGION_CLICK_OPEN_POPUP, "target-selection never opens region popup")
	_expect(MODE.region_click_disposition(projections[MODE.REGION_SUPPLY_POPUP_MODE], "region.1", "region.0") != MODE.REGION_CLICK_SUBMIT_TARGET, "region popup never submits a card target")
	_expect(MODE.blocks_ordinary_popups(projections[MODE.FORCED_DECISION_MODE]) and MODE.blocks_ordinary_popups(projections[MODE.CARD_RESOLUTION_MODE]), "forced decision and resolution block ordinary popups")
	var missing_region := _mode_source(MODE.REGION_SUPPLY_POPUP_MODE)
	missing_region["active_region_id"] = ""
	_expect(MODE.build(missing_region).is_empty(), "region popup mode requires its typed region context")
	var invalid_mode := _mode_source(MODE.TABLE_MAP_MODE)
	invalid_mode["mode_id"] = "unknown_mode"
	_expect(MODE.build(invalid_mode).is_empty(), "interaction mode enum is closed")
	var node_path_mode := _mode_source(MODE.CONTEXT_DETAIL_MODE)
	node_path_mode["active_context_id"] = NodePath("/root/Main")
	_expect(MODE.build(node_path_mode).is_empty(), "interaction mode rejects NodePath")


func _roster_source() -> Dictionary:
	return {
		"schema_version": ROSTER.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"source_revision": 7,
		"players": [
			_player("player.0", 0, "你", true, false, true),
			_player("player.1", 1, "玩家二", false, false, false),
			_player("player.2", 2, "玩家三", false, true, false),
		],
	}


func _player(player_id: String, order_index: int, name: String, local: bool, eliminated: bool, inspected: bool) -> Dictionary:
	return {
		"player_id": player_id,
		"public_order_index": order_index,
		"display_name": name,
		"role_display_name": "星际角色",
		"avatar_key": "avatar.%d" % order_index,
		"accent": "accent.%d" % order_index,
		"public_status": "eliminated" if eliminated else "active",
		"is_local_player": local,
		"is_eliminated": eliminated,
		"is_inspected": inspected,
		"submission_lock_public_state": "unlocked",
	}


func _region_source() -> Dictionary:
	return {
		"schema_version": REGION.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"region_id": "region.0",
		"region_index": 0,
		"display_name": "北境",
		"source_revision": 7,
		"rack_revision": 5,
		"public_status": "active",
		"availability": _availability(true),
		"monster_price_pressure": 2,
		"facility_slots": [{
			"slot_id": "facility.slot.0",
			"display_name": "设施槽位",
			"public_status": "open",
			"is_occupied": false,
			"detail_context_id": "none",
		}],
		"rack_cards": [{
			"rack_card_id": "rack.card.0",
			"card_semantic_id": "facility.orbital-factory.rank-1",
			"display_name": "轨道工厂",
			"illustration_key": "facility.orbital-factory",
			"costs": [_cost()],
			"availability": _availability(true),
			"detail_context_id": "detail.rack-card-0",
			"source_revision": 7,
			"rack_revision": 5,
		}],
		"requirements": [_requirement(true)],
		"allowed_actions": [_offer(ACTION_INTENT.ACTION_DISTRICT_SUPPLY_OPEN, 7)],
		"allowed_navigation_intents": [_table_navigation("region.detail.0")],
	}


func _availability(available: bool) -> Dictionary:
	return {
		"state_id": "available" if available else "disabled",
		"reason_id": "none" if available else "insufficient-funds",
		"reason_text": "" if available else "资源不足",
	}


func _cost() -> Dictionary:
	return {
		"cost_id": "cost.purchase",
		"resource_id": "commerce",
		"amount_units": 3,
		"display_token": "cost.commerce",
	}


func _requirement(satisfied: bool) -> Dictionary:
	return {
		"requirement_id": "requirement.selected-region",
		"satisfied": satisfied,
		"reason_id": "none" if satisfied else "region-required",
		"message_token": "requirement.region.selected",
		"arguments": {"count": 1},
	}


func _detail_source(context_kind: String) -> Dictionary:
	var visibility := "viewer_private" if context_kind in [DETAIL.KIND_NORMAL_CARD, DETAIL.KIND_COMMODITY_CARD] else "public"
	return {
		"schema_version": DETAIL.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"source_revision": 7,
		"context_id": "detail.%s" % context_kind.replace("_", "-"),
		"context_kind": context_kind,
		"visibility_scope": visibility,
		"title": "详情",
		"subtitle": "",
		"content": _detail_content(context_kind),
		"navigation_intents": [_table_navigation("detail.%s" % context_kind.replace("_", "-"))],
	}


func _detail_content(context_kind: String) -> Dictionary:
	match context_kind:
		DETAIL.KIND_NORMAL_CARD:
			return {
				"card_instance_id": "card.instance.1", "card_semantic_id": "facility.orbital.rank-1",
				"display_name": "轨道设施", "illustration_key": "facility.orbital",
				"timing_text": "行动阶段", "target_text": "一个地区", "effect_text": "获得公开效果",
				"duration_text": "立即", "visibility_text": "仅当前玩家", "keyword_tokens": ["keyword.facility"],
				"disabled_reason_id": "none", "disabled_reason_text": "",
			}
		DETAIL.KIND_COMMODITY_CARD:
			return {
				"commodity_card_instance_id": "commodity.card.1", "card_semantic_id": "commodity.berry.rank-2",
				"commodity_id": "star-dew-berry", "display_name": "星露莓", "illustration_key": "commodity.star-dew-berry",
				"level": 2, "base_units": 2, "target_text": "同产业设施", "effect_text": "结算商品",
				"source_text": "公共商品轨", "disabled_reason_id": "none", "disabled_reason_text": "",
			}
		DETAIL.KIND_PUBLIC_TRACK:
			return {
				"resolution_id": "resolution.1", "card_semantic_id": "track.public-card",
				"display_name": "公共牌轨", "illustration_key": "track.public-card", "public_status": "available",
				"summary": "公开摘要", "detail": "公开详情", "keyword_tokens": ["keyword.public"],
			}
		DETAIL.KIND_REGION_FACILITY:
			return {
				"facility_id": "facility.1", "region_id": "region.0", "display_name": "公开设施",
				"illustration_key": "facility.public", "public_status": "active", "summary": "设施摘要", "detail": "设施详情",
			}
		DETAIL.KIND_COMMODITY_SOURCE:
			return {
				"source_id": "source.market.1", "commodity_id": "star-dew-berry", "display_name": "公开来源",
				"illustration_key": "commodity.source.market", "public_status": "active", "summary": "来源摘要", "detail": "来源详情",
			}
		DETAIL.KIND_PUBLIC_EVENT:
			return {
				"receipt_id": "receipt.event-1", "reason_id": "none", "message_token": "event.public.fixture",
				"arguments": {"count": 1}, "summary": "事件摘要", "detail": "事件详情", "history_link": {},
			}
	return {}


func _mode_source(mode_id: String) -> Dictionary:
	var region_id := ""
	var player_id := ""
	var context_id := ""
	match mode_id:
		MODE.REGION_SUPPLY_POPUP_MODE:
			region_id = "region.0"
		MODE.PLAYER_INSPECTION_MODE:
			player_id = "player.1"
		MODE.CARD_TARGET_SELECTION_MODE, MODE.CONTEXT_DETAIL_MODE, MODE.FORCED_DECISION_MODE, MODE.CARD_RESOLUTION_MODE:
			context_id = "context.%s" % mode_id.replace("_", "-")
	return {
		"schema_version": MODE.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"source_revision": 7,
		"mode_id": mode_id,
		"active_region_id": region_id,
		"active_player_id": player_id,
		"active_context_id": context_id,
	}


func _table_navigation(request_id: String) -> Dictionary:
	return {
		"request_id": request_id,
		"action_kind": "region_detail",
		"source_surface": "alpha04b_context",
		"target_card_name": "",
	}


func _intel_navigation(history_entry_id: String, region_id: String) -> Dictionary:
	return {
		"kind": "open_intel",
		"focused_history_entry_id": history_entry_id,
		"focused_region_id": region_id,
	}


func _offer(action_id: String, revision: int) -> Dictionary:
	var contract := ACTION_INTENT.action_contract(action_id)
	var bindings: Array = []
	match action_id:
		ACTION_INTENT.ACTION_CARD_PLAY:
			bindings = [
				{"target_role_id": "card_instance_id", "target_id": "card.instance.1"},
				{"target_role_id": "hand_slot_id", "target_id": "hand.slot.0"},
			]
		ACTION_INTENT.ACTION_DISTRICT_SUPPLY_OPEN:
			bindings = [{"target_role_id": "region_id", "target_id": "region.0"}]
	return OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": action_id,
		"action_family_id": str(contract.get("action_family_id", "")),
		"source_revision": revision,
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "viewer_private",
			"target_kind_id": "stable-ids",
			"target_bindings": bindings,
			"requires_target": not bindings.is_empty(),
		},
		"legality_state": "available",
		"disabled_reason_id": "none",
		"cost_spec": {"cost_kind_id": "domain-owned", "amount_units": 0, "resource_id": "none"},
		"requirement_spec": {"requirement_ids": ["domain-legality"], "source_revision_required": true},
		"consequence_spec": {"committed_effect_refs": [], "refresh_scope": "full"},
		"presentation_token_ids": ["action.fixture"],
	})


func _valid(schema: Script, projection: Variant) -> bool:
	return not (projection as Dictionary).is_empty() \
		and bool(schema.call("validation_report", projection).get("valid", false)) \
		and WIRE.is_closed_data(projection)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ALPHA04B_PRESENTATION_SHELL_SCHEMA_CONTRACT_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("ALPHA04B_PRESENTATION_SHELL_SCHEMA_CONTRACT_TEST: %s" % failure)
	print("ALPHA04B_PRESENTATION_SHELL_SCHEMA_CONTRACT_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
