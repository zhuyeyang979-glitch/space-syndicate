extends PanelContainer
class_name SpaceSyndicateRightInspector

signal action_requested(action_id: String)

@onready var title_label: Label = %InspectorTitle
@onready var district_info_panel: Node = %DistrictInfoPanel
@onready var current_action_panel: Node = %CurrentActionPanel
@onready var event_log_label: Label = %EventLogLabel


func _ready() -> void:
	if current_action_panel.has_signal("action_requested"):
		current_action_panel.connect("action_requested", Callable(self, "_on_action_requested"))


func set_context(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "右侧说明书"))
	var district: Dictionary = data.get("district", {}) if data.get("district", {}) is Dictionary else {}
	if district_info_panel.has_method("set_info"):
		district_info_panel.call(
			"set_info",
			str(district.get("title", "当前区域")),
			str(district.get("detail", "选择地图区域后显示短详情。")),
			district.get("chips", [])
		)
	if current_action_panel.has_method("set_actions"):
		var actions: Variant = data.get("actions", [])
		current_action_panel.call("set_actions", actions if actions is Array else [])
	_set_event_log(data.get("logs", []))


func show_card(card_data: Dictionary) -> void:
	var chips: Array = []
	for key in ["rank", "type", "cost", "target"]:
		if card_data.has(key) and str(card_data[key]) != "":
			chips.append({"text": "%s %s" % [str(key).capitalize(), str(card_data[key])]})
	set_context({
		"title": "卡牌详情",
		"district": {
			"title": str(card_data.get("name", "未命名卡牌")),
			"detail": str(card_data.get("effect", card_data.get("description", "选择目标后执行。"))),
			"chips": chips,
		},
		"actions": card_data.get("actions", []),
		"logs": [],
	})


func _set_event_log(logs_variant: Variant) -> void:
	var logs: Array = logs_variant if logs_variant is Array else []
	if logs.is_empty():
		event_log_label.text = "公开日志\n- 暂无公开事件"
		return
	var lines: Array[String] = ["公开日志"]
	var start_index := maxi(0, logs.size() - 6)
	for i in range(start_index, logs.size()):
		lines.append("- %s" % str(logs[i]))
	event_log_label.text = "\n".join(lines)


func _on_action_requested(action_id: String) -> void:
	action_requested.emit(action_id)
