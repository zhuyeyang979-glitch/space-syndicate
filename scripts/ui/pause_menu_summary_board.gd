extends VBoxContainer
class_name SpaceSyndicatePauseMenuSummaryBoard

signal save_game_requested

@onready var save_game_button: Button = %SaveGameButton
@onready var save_game_status_label: Label = %SaveGameStatusLabel

var _save_request_count := 0


func _ready() -> void:
	if not save_game_button.pressed.is_connected(_on_save_game_pressed):
		save_game_button.pressed.connect(_on_save_game_pressed)


func set_save_resume_state(snapshot: Dictionary) -> void:
	var busy := bool(snapshot.get("busy", false))
	var can_save := bool(snapshot.get("can_save", false))
	var active_operation := str(snapshot.get("active_operation", ""))
	save_game_button.disabled = busy or not can_save
	save_game_button.text = "保存中…" if busy and active_operation == "save" else "保存游戏"
	save_game_button.tooltip_text = "正在写入本机固定存档位。" if busy else (
		"保存当前牌桌。现有不兼容文件会先保留备份。" if can_save else "当前暂时无法保存。"
	)
	save_game_status_label.text = str(snapshot.get("summary", "存档：恢复服务尚未就绪。"))


func debug_snapshot() -> Dictionary:
	return {
		"save_request_count": _save_request_count,
		"save_button_disabled": save_game_button.disabled,
		"save_button_text": save_game_button.text,
		"save_summary": save_game_status_label.text,
		"owns_save_data": false,
		"owns_gameplay_state": false,
	}


func _on_save_game_pressed() -> void:
	if save_game_button.disabled:
		return
	_save_request_count += 1
	save_game_requested.emit()
