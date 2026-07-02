extends PanelContainer
class_name SpaceSyndicateRightInspector

const WHY_TEXT_CHAR_LIMIT := 48
const SUMMARY_TEXT_CHAR_LIMIT := 44

signal action_requested(action_id: String)

@onready var title_label: Label = %InspectorTitle
@onready var reason_panel: Control = %InspectorReasonPanel
@onready var reason_label: Label = %InspectorReasonLabel
@onready var requirement_chip_row: HFlowContainer = %InspectorRequirementChipRow
@onready var district_info_panel: Node = %DistrictInfoPanel
@onready var current_action_panel: Node = %CurrentActionPanel
@onready var event_log_panel: Control = %EventLogPanel
@onready var event_log_label: Label = %EventLogLabel
@onready var deep_link_row: HFlowContainer = %InspectorDeepLinkRow

var requirements_signature: String = ""
var deep_links_signature: String = ""


func _ready() -> void:
	if current_action_panel.has_method("set_dense_mode"):
		current_action_panel.call("set_dense_mode", true)
	if current_action_panel.has_signal("action_requested"):
		current_action_panel.connect("action_requested", Callable(self, "_on_action_requested"))


func set_context(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "右侧详情"))
	var reason_text := str(data.get("why", data.get("explanation", ""))).strip_edges()
	var requirement_chips: Variant = data.get("requirements", data.get("requirement_chips", []))
	var has_requirements := _has_meaningful_requirement_chips(requirement_chips)
	var shows_reason_panel := reason_text != "" or has_requirements
	if reason_panel != null:
		reason_panel.visible = shows_reason_panel
		reason_panel.custom_minimum_size = Vector2(0, 46 if has_requirements else 34) if shows_reason_panel else Vector2.ZERO
	reason_label.text = _short_table_text(reason_text, WHY_TEXT_CHAR_LIMIT) if shows_reason_panel else ""
	reason_label.tooltip_text = reason_text
	if requirement_chip_row != null:
		requirement_chip_row.visible = has_requirements
	_set_chip_row(requirement_chip_row, requirement_chips if has_requirements else [], false)
	var district: Dictionary = data.get("district", {}) if data.get("district", {}) is Dictionary else {}
	if district_info_panel.has_method("set_info"):
		district_info_panel.call(
			"set_info",
			str(district.get("title", "当前选区")),
			_district_table_summary(district),
			district.get("chips", []),
			_district_full_detail(district)
		)
	if current_action_panel.has_method("set_actions"):
		var actions: Variant = data.get("actions", [])
		current_action_panel.call("set_actions", actions if actions is Array else [])
	_set_event_log(data.get("logs", []))
	_set_deep_links(data.get("deep_links", data.get("details", [])))


func _has_meaningful_requirement_chips(chips_variant: Variant) -> bool:
	var chips: Array = chips_variant if chips_variant is Array else []
	for chip_variant in chips:
		var text := ""
		if chip_variant is Dictionary:
			var chip := chip_variant as Dictionary
			text = str(chip.get("text", chip.get("label", chip.get("state", "")))).strip_edges()
		else:
			text = str(chip_variant).strip_edges()
		if text != "" and not (text in ["条件", "暂无条件", "待选择"]):
			return true
	return false


func show_card(card_data: Dictionary) -> void:
	var inspector_card := card_data.duplicate(true)
	inspector_card["presentation"] = "inspector_full"
	var chips: Array = []
	for key in ["rank", "type", "cost", "target", "play_state"]:
		if inspector_card.has(key) and str(inspector_card[key]) != "":
			chips.append({"text": "%s %s" % [_card_chip_label(key), str(inspector_card[key])]})
	var full_detail := _card_inspector_full_detail(inspector_card)
	var summary := str(inspector_card.get("summary", "")).strip_edges()
	if summary == "":
		summary = _short_table_text(full_detail, SUMMARY_TEXT_CHAR_LIMIT)
	set_context({
		"title": "卡牌详情",
		"district": {
			"title": str(inspector_card.get("name", "未命名卡牌")),
			"summary": summary,
			"detail": summary,
			"full_detail": full_detail,
			"chips": chips,
		},
		"actions": inspector_card.get("actions", []),
		"why": str(inspector_card.get("why", full_detail if full_detail.strip_edges() != "" else "看费用、目标、选区。")),
		"requirements": inspector_card.get("requirements", [
			{"text": "费用 %s" % str(inspector_card.get("cost", "--"))},
			{"text": "目标 %s" % str(inspector_card.get("target", "任意"))},
		]),
		"deep_links": inspector_card.get("deep_links", [
			{"id": "detail_card", "label": "卡牌详情"},
			{"id": "detail_region", "label": "区域详情"},
		]),
		"logs": [],
	})


func _card_inspector_full_detail(card_data: Dictionary) -> String:
	var lines: Array[String] = []
	var target := str(card_data.get("target", card_data.get("target_type", ""))).strip_edges()
	var requirement := str(card_data.get("requirement", card_data.get("play_requirement", card_data.get("condition", "")))).strip_edges()
	var effect := str(card_data.get("effect", card_data.get("description", "选择卡牌查看效果。"))).strip_edges()
	var disabled_reason := str(card_data.get("disabled_reason", card_data.get("block_reason", ""))).strip_edges()
	var primary_action := _first_enabled_action_label(card_data)
	if target != "":
		lines.append("目标｜%s" % target)
	if requirement != "":
		lines.append("条件｜%s" % requirement)
	if effect != "":
		lines.append("效果｜%s" % effect)
	if primary_action != "":
		lines.append("主动作｜%s" % primary_action)
	if disabled_reason != "":
		lines.append("暂不可用｜%s" % disabled_reason)
	return "\n".join(lines) if not lines.is_empty() else "选择卡牌查看效果。"


func _first_enabled_action_label(card_data: Dictionary) -> String:
	var actions: Array = card_data.get("actions", []) if card_data.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if bool(action.get("disabled", false)):
			continue
		var label := str(action.get("label", action.get("id", ""))).strip_edges()
		if label != "":
			return label
	return ""


func _set_chip_row(row: HFlowContainer, chips_variant: Variant, fallback_when_empty: bool = false) -> void:
	var chips: Array = chips_variant if chips_variant is Array else []
	if chips.is_empty() and fallback_when_empty:
		chips = [{"text": "待选择"}]
	var next_signature := var_to_str(chips)
	if next_signature == requirements_signature:
		return
	requirements_signature = next_signature
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for chip_variant in chips:
		var chip: Dictionary = chip_variant if chip_variant is Dictionary else {"text": str(chip_variant)}
		var label := Label.new()
		label.text = _short_table_text(str(chip.get("text", "条件")), 14)
		label.tooltip_text = str(chip.get("tooltip", ""))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)


func _set_deep_links(links_variant: Variant) -> void:
	var links: Array = links_variant if links_variant is Array else []
	if links.is_empty():
		links = [{"id": "codex", "label": "打开图鉴"}]
	var next_signature := var_to_str(links)
	if next_signature == deep_links_signature:
		return
	deep_links_signature = next_signature
	for child in deep_link_row.get_children():
		deep_link_row.remove_child(child)
		child.queue_free()
	for link_variant in links:
		var link: Dictionary = link_variant if link_variant is Dictionary else {"id": str(link_variant), "label": str(link_variant)}
		var button := Button.new()
		button.text = _short_table_text(str(link.get("label", "详情")), 8)
		button.tooltip_text = str(link.get("tooltip", ""))
		button.custom_minimum_size = Vector2(0, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var action_id := str(link.get("id", button.text))
		button.pressed.connect(func() -> void:
			action_requested.emit(action_id)
		)
		deep_link_row.add_child(button)


func _set_event_log(logs_variant: Variant) -> void:
	var logs: Array = logs_variant if logs_variant is Array else []
	if logs.is_empty():
		if event_log_panel != null:
			event_log_panel.visible = false
			event_log_panel.custom_minimum_size = Vector2.ZERO
		event_log_label.text = ""
		return
	if event_log_panel != null:
		event_log_panel.visible = true
		event_log_panel.custom_minimum_size = Vector2(0, 36)
	var latest := _short_log_line(str(logs[logs.size() - 1]), 34)
	event_log_label.text = "公开｜%s" % latest


func _short_log_line(value: String, max_chars: int) -> String:
	var clean := value.replace("\n", " ").strip_edges()
	if clean.length() <= max_chars:
		return clean
	return "%s..." % clean.substr(0, maxi(0, max_chars - 3))


func _district_table_summary(district: Dictionary) -> String:
	var summary := str(district.get("summary", district.get("short_detail", ""))).strip_edges()
	if summary == "":
		summary = str(district.get("detail", "区域短说明会显示在这里。"))
	return _short_table_text(summary, SUMMARY_TEXT_CHAR_LIMIT)


func _district_full_detail(district: Dictionary) -> String:
	var full_detail := str(district.get("full_detail", district.get("detail", ""))).strip_edges()
	if full_detail == "":
		full_detail = _district_table_summary(district)
	return full_detail


func _short_table_text(value: String, max_chars: int) -> String:
	var clean := value.replace("\n", " ").strip_edges()
	if clean.length() <= max_chars:
		return clean
	return "%s..." % clean.substr(0, maxi(0, max_chars - 3))


func _card_chip_label(key: String) -> String:
	match key:
		"rank":
			return "等级"
		"type":
			return "类型"
		"cost":
			return "费用"
		"target":
			return "目标"
		"play_state":
			return "状态"
	return key


func _on_action_requested(action_id: String) -> void:
	action_requested.emit(action_id)
