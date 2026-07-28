@tool
extends PanelContainer
class_name SpaceSyndicatePlayerInspectionPopup

signal closed

const PUBLIC_FIELDS: Array[String] = [
	"player_index",
	"public_player_name",
	"role_name",
	"player_color",
	"public_status",
	"is_local_player",
]

@onready var title_label: Label = %InspectionTitle
@onready var role_label: Label = %InspectionRole
@onready var status_label: Label = %InspectionStatus
@onready var privacy_label: Label = %InspectionPrivacy
@onready var close_button: Button = %InspectionClose

var _descriptor: Dictionary = {}
var _apply_count := 0
var _reject_count := 0


func _ready() -> void:
	close_button.pressed.connect(close_popup)
	set_process_unhandled_key_input(true)
	visible = false


func show_public_player(descriptor: Dictionary) -> bool:
	if not PlayerVisibleSurfacePolicy.is_safe_closed_data(descriptor) \
			or not PlayerVisibleSurfacePolicy.exact_fields(descriptor, PUBLIC_FIELDS) \
			or int(descriptor.get("player_index", -1)) < 0:
		_reject_count += 1
		return false
	_descriptor = descriptor.duplicate(true)
	title_label.text = "%s%s" % [
		str(descriptor.get("public_player_name", "玩家")),
		"（你）" if bool(descriptor.get("is_local_player", false)) else "",
	]
	role_label.text = "公开角色｜%s" % str(descriptor.get("role_name", "外星辛迪加"))
	status_label.text = "公开状态｜%s" % _status_text(str(descriptor.get("public_status", "waiting")))
	var accent := _as_color(descriptor.get("player_color", Color("#94a3b8")))
	title_label.add_theme_color_override("font_color", accent.lightened(0.22))
	privacy_label.text = "仅展示公开身份与状态；现金、手牌和私人计划保持隐藏。"
	visible = true
	_apply_count += 1
	close_button.grab_focus()
	return true


func close_popup() -> void:
	visible = false
	closed.emit()


func debug_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"player_index": int(_descriptor.get("player_index", -1)),
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"public_only": true,
		"private_field_count": 0,
		"mutates_gameplay": false,
	}


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()


func _status_text(status: String) -> String:
	return str({
		"ready": "已就绪",
		"waiting": "等待",
		"active": "公开行动",
		"eliminated": "已离场",
		"disconnected": "暂离",
	}.get(status.strip_edges().to_lower(), "等待"))


func _as_color(value: Variant) -> Color:
	if value is Color:
		return value as Color
	if value is String and Color.html_is_valid(str(value)):
		return Color(str(value))
	return Color("#94a3b8")
