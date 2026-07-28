@tool
extends PanelContainer
class_name SpaceSyndicateCardDockActionFeedback

const VALID_STATES := ["idle", "pending", "resolved", "blocked"]

@onready var state_label: Label = %FeedbackState
@onready var detail_label: Label = %FeedbackDetail

var _action_id := ""
var _state := "idle"
var _detail := "选择卡牌查看状态与合法目标。"
var _source_revision := -1
var _apply_count := 0
var _reject_count := 0


func _ready() -> void:
	_render()


func apply_feedback(action_id: String, state: String, detail: String, source_revision: int = 0) -> bool:
	var normalized_action := action_id.strip_edges()
	var normalized_state := state.strip_edges().to_lower()
	var normalized_detail := detail.replace("\n", " ").strip_edges()
	if normalized_action.is_empty() or normalized_action.length() > 120 \
			or normalized_state not in VALID_STATES \
			or normalized_detail.is_empty() or normalized_detail.length() > 360 \
			or source_revision < 0:
		_reject_count += 1
		return false
	if _source_revision >= 0 and source_revision < _source_revision:
		_reject_count += 1
		return false
	_action_id = normalized_action
	_state = normalized_state
	_detail = normalized_detail
	_source_revision = source_revision
	_apply_count += 1
	_render()
	return true


func show_card_snapshot(pool_id: StringName, card_snapshot: Dictionary) -> bool:
	if not PlayerVisibleSurfacePolicy.is_safe_closed_data(card_snapshot):
		_reject_count += 1
		return false
	var state := "resolved" if _card_available(pool_id, card_snapshot) else "blocked"
	var detail := _card_detail(pool_id, card_snapshot)
	var action_id := _card_identity(pool_id, card_snapshot)
	return apply_feedback(action_id, state, detail, int(card_snapshot.get("source_revision", 0)))


func clear_feedback() -> void:
	_action_id = ""
	_state = "idle"
	_detail = "选择卡牌查看状态与合法目标。"
	_source_revision = -1
	_render()


func debug_snapshot() -> Dictionary:
	return {
		"action_id": _action_id,
		"state": _state,
		"detail": _detail,
		"source_revision": _source_revision,
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"mutates_gameplay": false,
	}


func _render() -> void:
	if not is_node_ready():
		return
	state_label.text = str({
		"idle": "待选择",
		"pending": "处理中",
		"resolved": "可执行",
		"blocked": "暂不可用",
	}.get(_state, "待选择"))
	state_label.add_theme_color_override("font_color", _state_color(_state))
	detail_label.text = _detail
	detail_label.tooltip_text = _detail


func _card_available(pool_id: StringName, card: Dictionary) -> bool:
	if pool_id == &"bound_actions":
		return bool(card.get("enabled", false))
	return str(card.get("play_state", "disabled")) == "available"


func _card_detail(pool_id: StringName, card: Dictionary) -> String:
	var name := str(card.get("display_name", "卡牌"))
	if _card_available(pool_id, card):
		if pool_id == &"commodity_cards":
			return "%s｜%s" % [name, str(card.get("legal_target_summary", "选择合法设施或市场。"))]
		if pool_id == &"bound_actions":
			return "%s｜来源 %s｜冷却 %s｜次数 %s" % [
				name,
				str(card.get("source_entity_kind", "实体")),
				str(card.get("cooldown", 0)),
				"不限" if int(card.get("charges", -1)) < 0 else str(card.get("charges", 0)),
			]
		return "%s｜可通过正式行动入口提交。" % name
	return "%s｜%s" % [name, str(card.get("disabled_reason_id", "当前不可用"))]


func _card_identity(pool_id: StringName, card: Dictionary) -> String:
	match pool_id:
		&"normal_cards":
			return str(card.get("card_instance_id", "normal-card"))
		&"commodity_cards":
			return str(card.get("commodity_card_instance_id", "commodity-card"))
		&"bound_actions":
			return str(card.get("bound_action_instance_id", "bound-action"))
	return "card"


func _state_color(state: String) -> Color:
	return {
		"idle": Color("#94a3b8"),
		"pending": Color("#fde68a"),
		"resolved": Color("#86efac"),
		"blocked": Color("#fca5a5"),
	}.get(state, Color("#94a3b8")) as Color
