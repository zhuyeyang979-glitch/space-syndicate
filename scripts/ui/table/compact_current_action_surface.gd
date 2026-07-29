extends PanelContainer
class_name SpaceSyndicateCompactCurrentActionSurface

signal game_action_offer_requested(offer: Dictionary)
signal navigation_intent_requested(intent: Dictionary)

const PROJECTION := preload("res://scripts/presentation/current_action_context_projection_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const PERFORMANCE_SAMPLE_LIMIT := 128

@onready var title_label: Label = %CurrentActionTitle
@onready var summary_label: Label = %CurrentActionSummary
@onready var reason_label: Label = %CurrentActionReason
@onready var costs_label: Label = %CurrentActionCosts
@onready var requirements_label: Label = %CurrentActionRequirements
@onready var consequences_label: Label = %CurrentActionConsequences
@onready var action_dock: SpaceSyndicateActionDock = %CurrentActionDock

var _projection: Dictionary = {}
var _bound_viewer_index := -1
var _bound_authorization_revision := 0
var _source_revision := -1
var _last_signature := ""
var _apply_count := 0
var _reject_count := 0
var _duplicate_count := 0
var _stale_count := 0
var _conflict_count := 0
var _blocked_card_submission_count := 0
var _offer_by_ui_action: Dictionary = {}
var _navigation_by_ui_action: Dictionary = {}
var _render_usec_samples: Array[int] = []


func _ready() -> void:
	if action_dock != null:
		action_dock.set_dense_mode(true)
		if not action_dock.action_requested.is_connected(_on_action_requested):
			action_dock.action_requested.connect(_on_action_requested)
	clear_projection()


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
	var next_revision := int(value.get("source_revision", -1))
	var next_signature := str(value.get("projection_fingerprint", ""))
	if _source_revision >= 0 and next_revision < _source_revision:
		_stale_count += 1
		return false
	if next_signature == _last_signature:
		_duplicate_count += 1
		return true
	if _source_revision >= 0 and next_revision == _source_revision:
		_conflict_count += 1
		return false
	_projection = PROJECTION.detached_copy(value)
	_source_revision = next_revision
	_last_signature = next_signature
	_render_projection()
	_record_performance_sample(Time.get_ticks_usec() - render_started_usec)
	_apply_count += 1
	return true


func clear_projection() -> void:
	_projection = {}
	_source_revision = -1
	_last_signature = ""
	_offer_by_ui_action.clear()
	_navigation_by_ui_action.clear()
	if not is_node_ready():
		return
	title_label.text = "当前行动"
	summary_label.text = "等待 viewer-authorized 行动上下文。"
	reason_label.text = ""
	costs_label.text = "成本｜--"
	requirements_label.text = "要求｜--"
	consequences_label.text = "结果｜--"
	action_dock.set_dock({
		"quick_actions": [_disabled_placeholder("暂无当前行动")],
		"actions": [],
	})
	action_dock.set_dense_mode(true)


func debug_snapshot() -> Dictionary:
	return {
		"viewer_index": _bound_viewer_index,
		"authorization_revision": _bound_authorization_revision,
		"source_revision": _source_revision,
		"projection_fingerprint": _last_signature,
		"context_id": str(_projection.get("context_id", "")),
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"duplicate_count": _duplicate_count,
		"stale_count": _stale_count,
		"conflict_count": _conflict_count,
		"blocked_card_submission_count": _blocked_card_submission_count,
		"offer_count": _offer_by_ui_action.size(),
		"navigation_count": _navigation_by_ui_action.size(),
		"action_dock_instance_id": action_dock.get_instance_id() if action_dock != null else 0,
		"render_p95_ms": _p95_milliseconds(),
		"render_sample_count": _render_usec_samples.size(),
		"accepts_card_submission": false,
		"emits_card_action_offer": false,
		"owns_action_legality": false,
		"mutates_gameplay": false,
	}


func _render_projection() -> void:
	title_label.text = str(_projection.get("title", "当前行动"))
	summary_label.text = str(_projection.get("summary", ""))
	summary_label.tooltip_text = summary_label.text
	var reason_text := str(_projection.get("reason_text", ""))
	reason_label.text = "原因｜%s" % reason_text if not reason_text.is_empty() else ""
	reason_label.visible = not reason_text.is_empty()
	costs_label.text = "成本｜%s" % _costs_text(_projection.get("costs", []))
	requirements_label.text = "要求｜%s" % _requirements_text(_projection.get("requirements", []))
	consequences_label.text = "结果｜%s" % _consequences_text(_projection.get("consequences", []))
	_offer_by_ui_action.clear()
	_navigation_by_ui_action.clear()
	var offer_rows: Array = []
	for offer_variant in _projection.get("game_action_offers", []) as Array:
		var offer := offer_variant as Dictionary
		if _is_card_submission_offer(offer):
			_blocked_card_submission_count += 1
			continue
		var ui_action_id := "offer:%s" % str(offer.get("offer_fingerprint", ""))
		_offer_by_ui_action[ui_action_id] = offer.duplicate(true)
		offer_rows.append(_offer_row(ui_action_id, offer))
	var navigation_rows: Array = []
	var navigation_index := 0
	for intent_variant in _projection.get("navigation_intents", []) as Array:
		var intent := intent_variant as Dictionary
		var ui_action_id := "navigation:%d" % navigation_index
		navigation_index += 1
		_navigation_by_ui_action[ui_action_id] = intent.duplicate(true)
		navigation_rows.append({
			"id": ui_action_id,
			"label": _navigation_label(intent),
			"state": "browse",
			"active": true,
			"disabled": false,
			"tooltip": "只发出 typed navigation intent，不执行游戏行动。",
		})
	var dock_rows: Array = []
	dock_rows.append_array(offer_rows)
	dock_rows.append_array(navigation_rows)
	if dock_rows.is_empty():
		dock_rows.append(_disabled_placeholder("暂无可执行行动"))
	action_dock.set_dock({
		"quick_actions": [_disabled_placeholder("当前行动")],
		"actions": dock_rows,
	})
	action_dock.set_dense_mode(true)


func _offer_row(ui_action_id: String, offer: Dictionary) -> Dictionary:
	var available := str(offer.get("legality_state", "disabled")) == "available"
	var semantic_action_id := str(offer.get("semantic_action_id", ""))
	return {
		"id": ui_action_id,
		"label": _action_label(semantic_action_id),
		"state": "ready" if available else "blocked",
		"active": available,
		"disabled": not available,
		"tooltip": "typed offer %s｜%s" % [
			semantic_action_id,
			str(offer.get("disabled_reason_id", "none")),
		],
	}


func _disabled_placeholder(label_text: String) -> Dictionary:
	return {
		"id": "none",
		"label": label_text,
		"state": "waiting",
		"active": false,
		"disabled": true,
		"tooltip": "等待新的 typed current-action projection。",
	}


func _on_action_requested(ui_action_id: String) -> void:
	var offer_variant: Variant = _offer_by_ui_action.get(ui_action_id, {})
	if offer_variant is Dictionary and not (offer_variant as Dictionary).is_empty():
		var offer := offer_variant as Dictionary
		if _is_card_submission_offer(offer):
			_blocked_card_submission_count += 1
			return
		if bool(OFFER.validation_report(offer).get("valid", false)) \
				and str(offer.get("legality_state", "disabled")) == "available":
			game_action_offer_requested.emit(offer.duplicate(true))
		return
	var navigation_variant: Variant = _navigation_by_ui_action.get(ui_action_id, {})
	if navigation_variant is Dictionary and not (navigation_variant as Dictionary).is_empty():
		navigation_intent_requested.emit((navigation_variant as Dictionary).duplicate(true))


func _is_card_submission_offer(offer: Dictionary) -> bool:
	return str(offer.get("semantic_action_id", "")) == ACTION_INTENT.ACTION_CARD_PLAY


func _action_label(action_id: String) -> String:
	return {
		ACTION_INTENT.ACTION_DISTRICT_SELECT: "选择区域",
		ACTION_INTENT.ACTION_DISTRICT_SUPPLY_OPEN: "打开牌架",
		ACTION_INTENT.ACTION_DISTRICT_SUPPLY_CLOSE: "关闭牌架",
		ACTION_INTENT.ACTION_DISTRICT_SUPPLY_QUOTE: "获取报价",
		ACTION_INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE: "购买供牌",
		ACTION_INTENT.ACTION_PLAYER_STRATEGY_OPEN_SUPPLY: "前往区域牌架",
		ACTION_INTENT.ACTION_SESSION_END_TURN: "结束回合",
	}.get(action_id, action_id) as String


func _navigation_label(intent: Dictionary) -> String:
	var action_kind := str(intent.get("action_kind", ""))
	if not action_kind.is_empty():
		return "查看 %s" % action_kind
	var kind := str(intent.get("kind", ""))
	return "查看详情" if kind.is_empty() else "查看 %s" % kind


func _costs_text(costs_variant: Variant) -> String:
	var entries: Array = costs_variant if costs_variant is Array else []
	if entries.is_empty():
		return "无公开成本"
	var parts: Array[String] = []
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		parts.append("%s %d" % [
			str(entry.get("display_token", entry.get("resource_id", "cost"))),
			int(entry.get("amount_units", 0)),
		])
	return " · ".join(parts)


func _requirements_text(entries_variant: Variant) -> String:
	var entries: Array = entries_variant if entries_variant is Array else []
	if entries.is_empty():
		return "无额外要求"
	var parts: Array[String] = []
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		parts.append("%s %s" % [
			"✓" if bool(entry.get("satisfied", false)) else "×",
			str(entry.get("message_token", entry.get("requirement_id", "requirement"))),
		])
	return " · ".join(parts)


func _consequences_text(entries_variant: Variant) -> String:
	var entries: Array = entries_variant if entries_variant is Array else []
	if entries.is_empty():
		return "等待行动结果"
	var parts: Array[String] = []
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		parts.append(str(entry.get("message_token", entry.get("consequence_id", "consequence"))))
	return " · ".join(parts)


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
