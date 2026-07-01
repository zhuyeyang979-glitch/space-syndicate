extends PanelContainer
class_name SpaceSyndicatePlayerBoard

const CARD_FACE_SCENE := preload("res://scenes/ui/CardFace.tscn")

signal card_selected(card_data: Dictionary)

@onready var title_label: Label = %PlayerBoardTitle
@onready var hand_rack: Control = %HandRack
@onready var action_hint_label: Label = %PlayerActionHint

func set_player_state(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "玩家板｜手牌"))
	action_hint_label.text = str(data.get("hint", "选择一张手牌后，右侧详情会显示主操作。"))
	var cards_variant: Variant = data.get("hand_cards", [])
	set_hand_cards(cards_variant if cards_variant is Array else [])


func set_hand_cards(cards: Array) -> void:
	for child in hand_rack.get_children():
		hand_rack.remove_child(child)
		child.queue_free()
	if cards.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无手牌｜双击区域查看牌架"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hand_rack.add_child(empty_label)
	else:
		for card_variant in cards:
			var card_data: Dictionary = card_variant if card_variant is Dictionary else {}
			var card := CARD_FACE_SCENE.instantiate() as Control
			if card.has_method("set_card_data"):
				card.call("set_card_data", card_data)
			if card.has_signal("card_double_clicked"):
				card.connect("card_double_clicked", Callable(self, "_on_card_double_clicked"))
			hand_rack.add_child(card)
	if hand_rack.has_method("relayout"):
		hand_rack.call_deferred("relayout")


func _on_card_double_clicked(card_data: Dictionary) -> void:
	card_selected.emit(card_data)
