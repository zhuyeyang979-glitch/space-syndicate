extends CanvasLayer
class_name V073PlaytestQuestionnaire
# MCP_FINALIZE

signal questionnaire_presented(settlement_id: String)
signal questionnaire_submitted(values: Dictionary)
signal questionnaire_skipped

const SCALE_QUESTIONS := [
	["rules_easy_to_understand", "规则是否容易理解"],
	["first_round_direction_clear", "第一回合是否知道该做什么"],
	["six_color_assets_clear", "六色资产是否容易理解"],
	["unified_track_clear", "统一轨是否容易理解"],
	["target_selection_clear", "出牌目标是否容易选择"],
	["action_order_strategic", "行动排序是否有策略感"],
	["fizzle_fair", "Fizzle 是否公平"],
	["hidden_lead_fair", "隐藏首位是否公平"],
	["submission_window_sufficient", "30 秒是否足够"],
	["resolution_wait_acceptable", "结算等待是否过长"],
	["ai_behavior_reasonable", "AI 是否看起来合理"],
	["ui_readable", "UI 是否容易读取"],
	["match_fun", "整局是否有趣"],
	["would_play_again", "是否愿意再玩一局"],
]

@onready var _root: Control = %QuestionnaireRoot
@onready var _questions: VBoxContainer = %ScaleQuestions
@onready var _scroll: ScrollContainer = %QuestionScroll

var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _presented_settlements: Dictionary = {}
var _active_settlement_id := ""
var _submitted := false


func _ready() -> void:
	_build_scale_questions()
	%QuestionnaireSubmit.pressed.connect(_submit)
	%QuestionnaireSkip.pressed.connect(_skip)
	_root.visible = false


func present_after_final_settlement(settlement_id: String) -> bool:
	if settlement_id.is_empty() or _presented_settlements.has(settlement_id):
		return false
	_presented_settlements[settlement_id] = true
	_active_settlement_id = settlement_id
	_submitted = false
	_root.visible = true
	_scroll.scroll_vertical = 0
	var first_slider := _sliders.get(str(SCALE_QUESTIONS[0][0])) as HSlider
	if first_slider != null:
		first_slider.grab_focus()
	questionnaire_presented.emit(settlement_id)
	return true


func is_presented() -> bool:
	return _root.visible


func debug_snapshot() -> Dictionary:
	return {
		"visible": _root.visible,
		"scale_question_count": SCALE_QUESTIONS.size(),
		"scrollable": true,
		"submitted": _submitted,
	}


func _build_scale_questions() -> void:
	for question in SCALE_QUESTIONS:
		var question_id := str(question[0])
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = str(question[1])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var scale_row := HBoxContainer.new()
		var low := Label.new()
		low.text = "1"
		scale_row.add_child(low)
		var slider := HSlider.new()
		slider.min_value = 1
		slider.max_value = 7
		slider.step = 1
		slider.value = 4
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scale_row.add_child(slider)
		var high := Label.new()
		high.text = "7"
		scale_row.add_child(high)
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 24
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.text = "4"
		scale_row.add_child(value_label)
		slider.value_changed.connect(func(value: float) -> void:
			value_label.text = str(int(value))
		)
		row.add_child(scale_row)
		_questions.add_child(row)
		_sliders[question_id] = slider
		_value_labels[question_id] = value_label


func _submit() -> void:
	if _submitted:
		return
	_submitted = true
	var values := {}
	for question in SCALE_QUESTIONS:
		var question_id := str(question[0])
		values[question_id] = int((_sliders.get(question_id) as HSlider).value)
	values["most_fun_moment"] = _clean(%MostFun.text)
	values["most_confusing_part"] = _clean(%MostConfusing.text)
	values["most_frustrating_part"] = _clean(%MostFrustrating.text)
	values["one_rule_to_change"] = _clean(%RuleChange.text)
	values["expected_match_length"] = _clean(%ExpectedLength.text)
	_root.visible = false
	questionnaire_submitted.emit(values)


func _skip() -> void:
	if _submitted:
		return
	_submitted = true
	_root.visible = false
	questionnaire_skipped.emit()


func _clean(value: String) -> String:
	var clean := ""
	for character in value:
		var code := character.unicode_at(0)
		if code >= 32 and code != 127:
			clean += character
	return clean.left(500)
