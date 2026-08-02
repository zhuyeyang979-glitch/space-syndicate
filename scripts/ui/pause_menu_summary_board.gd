extends VBoxContainer
class_name SpaceSyndicatePauseMenuSummaryBoard

signal save_game_requested(destructive_confirmed: bool)

@onready var save_game_button: Button = %SaveGameButton
@onready var save_game_status_label: Label = %SaveGameStatusLabel
@onready var cancel_save_confirmation_button: Button = %CancelSaveConfirmationButton

var _save_request_count := 0
var _confirmation_pending := false
var _slot_requires_confirmation := false
var _last_summary := "存档：正在检查…"


func _ready() -> void:
	if not save_game_button.pressed.is_connected(_on_save_game_pressed):
		save_game_button.pressed.connect(_on_save_game_pressed)
	if not cancel_save_confirmation_button.pressed.is_connected(cancel_save_confirmation):
		cancel_save_confirmation_button.pressed.connect(cancel_save_confirmation)


func set_save_resume_state(snapshot: Dictionary) -> void:
	var busy := bool(snapshot.get("busy", false))
	var can_save := bool(snapshot.get("can_save", false))
	var active_operation := str(snapshot.get("active_operation", ""))
	_slot_requires_confirmation = str(snapshot.get("slot_state", "unavailable")) != "empty"
	_last_summary = str(snapshot.get("summary", "存档：恢复服务尚未就绪。"))
	if busy or bool(snapshot.get("last_succeeded", false)):
		_confirmation_pending = false
	save_game_button.disabled = busy or not can_save
	save_game_button.text = "保存中…" if busy and active_operation == "save" else ("确认覆盖存档" if _confirmation_pending else "保存游戏")
	save_game_button.tooltip_text = "正在写入本机固定存档位。" if busy else (
		"保存当前牌桌。现有不兼容文件会先保留备份。" if can_save else "当前暂时无法保存。"
	)
	save_game_status_label.text = "存档：再次点击确认覆盖；取消不会改动现有文件。" if _confirmation_pending else _last_summary
	cancel_save_confirmation_button.visible = _confirmation_pending and not busy


func debug_snapshot() -> Dictionary:
	return {
		"save_request_count": _save_request_count,
		"save_button_disabled": save_game_button.disabled,
		"save_button_text": save_game_button.text,
		"save_summary": save_game_status_label.text,
		"confirmation_pending": _confirmation_pending,
		"owns_save_data": false,
		"owns_gameplay_state": false,
	}


func _on_save_game_pressed() -> void:
	if save_game_button.disabled:
		return
	if _slot_requires_confirmation and not _confirmation_pending:
		_confirmation_pending = true
		save_game_button.text = "确认覆盖存档"
		save_game_status_label.text = "存档：再次点击确认覆盖；取消不会改动现有文件。"
		cancel_save_confirmation_button.visible = true
		return
	_save_request_count += 1
	var confirmed := _slot_requires_confirmation and _confirmation_pending
	_confirmation_pending = false
	cancel_save_confirmation_button.visible = false
	save_game_requested.emit(confirmed)


func cancel_save_confirmation() -> void:
	_confirmation_pending = false
	cancel_save_confirmation_button.visible = false
	save_game_button.text = "保存游戏"
	save_game_status_label.text = _last_summary
