extends Control
class_name SpaceSyndicateRegionSupplyPopup

signal close_requested(reason_id: String)
signal supply_action_requested(action_id: String, payload: Dictionary)
signal navigation_intent_requested(intent: Dictionary)

const PROJECTION := preload("res://scripts/presentation/region_supply_popup_projection_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const PERFORMANCE_SAMPLE_LIMIT := 128

@onready var backdrop: ColorRect = %RegionSupplyPopupBackdrop
@onready var drawer: SpaceSyndicateDistrictSupplyDrawer = %ProductionDistrictSupplyDrawer

var _projection: Dictionary = {}
var _bound_viewer_index := -1
var _bound_authorization_revision := 0
var _source_revision := -1
var _rack_revision := -1
var _last_signature := ""
var _apply_count := 0
var _reject_count := 0
var _duplicate_count := 0
var _stale_count := 0
var _conflict_count := 0
var _close_count := 0
var _offer_by_card_and_action: Dictionary = {}
var _render_usec_samples: Array[int] = []


func _ready() -> void:
	if backdrop != null and not backdrop.gui_input.is_connected(_on_backdrop_gui_input):
		backdrop.gui_input.connect(_on_backdrop_gui_input)
	if drawer != null:
		drawer.visible = true
		if not drawer.supply_action_requested.is_connected(_on_supply_action_requested):
			drawer.supply_action_requested.connect(_on_supply_action_requested)
	set_process_unhandled_key_input(visible)


func bind_viewer(viewer_index: int, authorization_revision: int) -> void:
	if viewer_index == _bound_viewer_index \
			and authorization_revision == _bound_authorization_revision:
		return
	_bound_viewer_index = viewer_index
	_bound_authorization_revision = authorization_revision
	clear_projection()


func apply_projection(value: Dictionary) -> bool:
	var render_started_usec := Time.get_ticks_usec()
	if not bool(PROJECTION.validation_report(value).get("valid", false)) \
			or not PROJECTION.matches_viewer_authorization(
				value,
				_bound_viewer_index,
				_bound_authorization_revision
			):
		_reject_count += 1
		return false
	var next_source_revision := int(value.get("source_revision", -1))
	var next_rack_revision := int(value.get("rack_revision", -1))
	var next_signature := str(value.get("projection_fingerprint", ""))
	if _source_revision >= 0 and next_source_revision < _source_revision:
		_stale_count += 1
		return false
	if next_signature == _last_signature:
		_duplicate_count += 1
		return true
	if _source_revision >= 0 and next_source_revision == _source_revision \
			and next_rack_revision == _rack_revision:
		_conflict_count += 1
		return false
	_projection = PROJECTION.detached_copy(value)
	_source_revision = next_source_revision
	_rack_revision = next_rack_revision
	_last_signature = next_signature
	_render_projection()
	_record_performance_sample(Time.get_ticks_usec() - render_started_usec)
	_apply_count += 1
	show_popup()
	return true


func clear_projection() -> void:
	_projection = {}
	_source_revision = -1
	_rack_revision = -1
	_last_signature = ""
	_offer_by_card_and_action.clear()
	if drawer != null and drawer.has_method("clear_supply"):
		drawer.clear_supply()
	hide_popup()


func show_popup() -> bool:
	if _projection.is_empty():
		return false
	visible = true
	set_process_unhandled_key_input(true)
	if drawer != null and drawer.close_button != null:
		drawer.close_button.grab_focus.call_deferred()
	return true


func hide_popup() -> void:
	visible = false
	set_process_unhandled_key_input(false)


func close_popup(reason_id: String = "close_button", notify_supply_port := true) -> void:
	if not visible:
		return
	_close_count += 1
	hide_popup()
	if notify_supply_port:
		supply_action_requested.emit("district_supply_close", {"source": reason_id})
	close_requested.emit(reason_id)


func debug_snapshot() -> Dictionary:
	var drawer_debug: Dictionary = {}
	if drawer != null and drawer.has_method("debug_snapshot"):
		drawer_debug = drawer.debug_snapshot()
	return {
		"viewer_index": _bound_viewer_index,
		"authorization_revision": _bound_authorization_revision,
		"source_revision": _source_revision,
		"rack_revision": _rack_revision,
		"projection_fingerprint": _last_signature,
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"duplicate_count": _duplicate_count,
		"stale_count": _stale_count,
		"conflict_count": _conflict_count,
		"close_count": _close_count,
		"visible": visible,
		"production_drawer_instance_id": drawer.get_instance_id() if drawer != null else 0,
		"production_drawer_instance_count": 1 if drawer != null else 0,
		"render_p95_ms": _p95_milliseconds(),
		"render_sample_count": _render_usec_samples.size(),
		"reuses_production_district_supply_drawer": true,
		"owns_rack": false,
		"owns_purchase_window": false,
		"owns_rng": false,
		"uses_production_supply_action_port": true,
		"emits_game_action_offer": false,
		"mutates_gameplay": false,
		"drawer": drawer_debug,
	}


func action_offer_for_card(card_id: String, semantic_action_id: String) -> Dictionary:
	var offer_variant: Variant = _offer_by_card_and_action.get(
		_offer_key(card_id, semantic_action_id),
		{}
	)
	if not (offer_variant is Dictionary):
		return {}
	return OFFER.detached_copy(offer_variant)


func _render_projection() -> void:
	_offer_by_card_and_action.clear()
	for offer_variant in _projection.get("allowed_actions", []) as Array:
		var offer := offer_variant as Dictionary
		var action_id := str(offer.get("semantic_action_id", ""))
		var targets := OFFER.target_ids(offer)
		var card_id := str(targets.get("card_id", ""))
		_offer_by_card_and_action[_offer_key(card_id, action_id)] = offer.duplicate(true)
	var cards: Array = []
	for card_variant in _projection.get("rack_cards", []) as Array:
		var card := card_variant as Dictionary
		cards.append(_drawer_card(card))
	var availability := _projection.get("availability", {}) as Dictionary
	var requirements: Array = _projection.get("requirements", []) as Array
	var facility_slots: Array = _projection.get("facility_slots", []) as Array
	var drawer_snapshot := {
		"title": "%s · 区域牌架" % str(_projection.get("display_name", "区域")),
		"visibility_scope": "viewer_private",
		"rule_strip": "单击预览｜双击或购买按钮提交权威报价/购买请求",
		"rule_tooltip": "该弹层复用生产区域牌架；报价、购买合法性与牌架刷新仍由原运行时所有者负责。",
		"privacy_hint": "仅渲染 viewer-authorized typed projection；不读取现金、手牌、未来牌架或 RNG。",
		"header_chips": [
			{"text": "%d 张供牌" % cards.size(), "accent": "#38bdf8ff"},
			{"text": "%d / %d 设施位" % [_occupied_slot_count(facility_slots), facility_slots.size()], "accent": "#a78bfaff"},
		],
		"market_status": _market_status(availability, requirements),
		"purchase_window": {},
		"cards": cards,
		"preview": (cards[0] as Dictionary).get("preview", {}).duplicate(true) if not cards.is_empty() else {},
		"empty_state": {
			"market_text": "当前区域暂无可见供牌。",
			"preview_text": "选择一张区域供牌查看公开详情。",
		},
	}
	drawer.set_supply(drawer_snapshot)


func _drawer_card(card: Dictionary) -> Dictionary:
	var card_id := str(card.get("rack_card_id", ""))
	var display_name := str(card.get("display_name", "区域供牌"))
	var availability := card.get("availability", {}) as Dictionary
	var available := str(availability.get("state_id", "disabled")) == "available"
	var primary_action := _primary_action_for_card(card_id)
	var cost_text := _cost_text(card.get("costs", []))
	var reason_text := str(availability.get("reason_text", ""))
	var status_text := "可请求" if available else (reason_text if not reason_text.is_empty() else "暂不可用")
	var action_id := str(primary_action.get("semantic_action_id", ""))
	var legacy_action_id := "district_supply_purchase_card" \
		if action_id == ACTION_INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE \
		else "district_supply_preview_card"
	var preview := {
		"card_name": card_id,
		"title": display_name,
		"body": "公开卡牌 %s｜详情上下文 %s" % [
			str(card.get("card_semantic_id", "")),
			str(card.get("detail_context_id", "")),
		],
		"facts": "%s｜%s" % [cost_text, status_text],
		"status_text": status_text,
		"buy_text": "购买" if action_id == ACTION_INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE else "获取报价",
		"buy_enabled": available and not primary_action.is_empty() \
			and str(primary_action.get("legality_state", "disabled")) == "available",
		"primary_action_id": legacy_action_id,
		"accent": "#34d399ff" if available else "#64748bff",
		"theme_color": "#38bdf8ff",
	}
	return {
		"card_name": card_id,
		"title": display_name,
		"rank": "",
		"route": str(card.get("card_semantic_id", "")),
		"facts": cost_text,
		"state_text": status_text,
		"accent": "#34d399ff" if available else "#64748bff",
		"theme_color": "#38bdf8ff",
		"actionable": bool(preview.get("buy_enabled", false)),
		"preview": preview,
	}


func _primary_action_for_card(card_id: String) -> Dictionary:
	for action_id in [
		ACTION_INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE,
		ACTION_INTENT.ACTION_DISTRICT_SUPPLY_QUOTE,
	]:
		var offer_variant: Variant = _offer_by_card_and_action.get(_offer_key(card_id, action_id), {})
		if offer_variant is Dictionary and not (offer_variant as Dictionary).is_empty():
			return (offer_variant as Dictionary).duplicate(true)
	return {}


func _market_status(availability: Dictionary, requirements: Array) -> Array:
	var result: Array = []
	var state_id := str(availability.get("state_id", "disabled"))
	var reason_text := str(availability.get("reason_text", ""))
	result.append({
		"text": "牌架可用" if state_id == "available" else (reason_text if not reason_text.is_empty() else "牌架暂不可用"),
		"accent": "#34d399ff" if state_id == "available" else "#f59e0bff",
	})
	result.append({
		"text": "怪兽价格压力 %+d" % int(_projection.get("monster_price_pressure", 0)),
		"accent": "#f59e0bff",
	})
	var blocked := 0
	for requirement_variant in requirements:
		if requirement_variant is Dictionary and not bool((requirement_variant as Dictionary).get("satisfied", false)):
			blocked += 1
	result.append({
		"text": "要求 %d 未满足" % blocked if blocked > 0 else "要求已满足",
		"accent": "#f87171ff" if blocked > 0 else "#60a5faff",
	})
	return result


func _occupied_slot_count(slots: Array) -> int:
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and bool((slot_variant as Dictionary).get("is_occupied", false)):
			count += 1
	return count


func _cost_text(costs_variant: Variant) -> String:
	var costs: Array = costs_variant if costs_variant is Array else []
	if costs.is_empty():
		return "无公开成本"
	var parts: Array[String] = []
	for cost_variant in costs:
		if not (cost_variant is Dictionary):
			continue
		var cost := cost_variant as Dictionary
		parts.append("%s %d" % [
			str(cost.get("display_token", cost.get("resource_id", "cost"))),
			int(cost.get("amount_units", 0)),
		])
	return " · ".join(parts)


func _on_supply_action_requested(action_id: String, payload: Dictionary) -> void:
	supply_action_requested.emit(action_id, payload.duplicate(true))
	if action_id == "district_supply_close":
		close_popup("close_button", false)
		return
	var card_id := str(payload.get("card_name", ""))
	if action_id == "district_supply_preview_card":
		_emit_navigation_for_card(card_id)


func _emit_navigation_for_card(card_id: String) -> bool:
	var display_name := ""
	for card_variant in _projection.get("rack_cards", []) as Array:
		var card := card_variant as Dictionary
		if str(card.get("rack_card_id", "")) == card_id:
			display_name = str(card.get("display_name", ""))
			break
	for intent_variant in _projection.get("allowed_navigation_intents", []) as Array:
		var intent := intent_variant as Dictionary
		if str(intent.get("target_card_name", "")) in [card_id, display_name]:
			navigation_intent_requested.emit(intent.duplicate(true))
			return true
	return false


func _offer_key(card_id: String, action_id: String) -> String:
	return "%s|%s" % [card_id, action_id]


func _on_backdrop_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	close_popup("outside_pointer")
	backdrop.accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or event == null or not event.is_action_pressed("ui_cancel"):
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	close_popup("escape")
	get_viewport().set_input_as_handled()


func _record_performance_sample(elapsed_usec: int) -> void:
	_render_usec_samples.append(maxi(0, elapsed_usec))
	if _render_usec_samples.size() > PERFORMANCE_SAMPLE_LIMIT:
		_render_usec_samples.pop_front()


func _p95_milliseconds() -> float:
	if _render_usec_samples.is_empty():
		return 0.0
	var ordered: Array[int] = _render_usec_samples.duplicate()
	ordered.sort()
	var index := mini(ordered.size() - 1, ceili(float(ordered.size()) * 0.95) - 1)
	return float(ordered[index]) / 1000.0
