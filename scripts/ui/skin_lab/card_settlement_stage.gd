extends PanelContainer
class_name SpaceSyndicateCardSettlementStage

@onready var card_face: Control = %SettlementCardFace
@onready var title_label: Label = %SettlementTitle
@onready var status_label: Label = %SettlementStatus
@onready var progress_bar: ProgressBar = %SettlementProgress

var _phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_card_view_model(view_model: Dictionary) -> void:
	var display := view_model.duplicate(true)
	display["presentation"] = "mini_hand"
	display["skin_variant"] = "orbital_table_premium"
	if card_face.has_method("set_card_data"):
		card_face.call("set_card_data", display)
	if card_face.has_method("set_interaction_state"):
		card_face.call("set_interaction_state", {"resolving": true, "selected": true})
	title_label.text = str(view_model.get("name", "正在结算"))
	status_label.text = "公开结算 · 已锁定目标"


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.8, 1.0)
	progress_bar.value = _phase * 100.0
	var pulse := 0.93 + 0.07 * sin(_phase * TAU)
	card_face.modulate = Color(pulse, pulse, 1.0, 1.0)
