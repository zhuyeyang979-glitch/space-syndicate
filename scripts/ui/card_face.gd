extends "res://scripts/CardUI.gd"
class_name SpaceSyndicateCardFace

# Thin UI-scene wrapper around the existing prototype card data adapter.
# Keep rules and settlement logic outside this component.

var card_kind: String = ""
var card_stats: String = ""


func set_card(data: Dictionary) -> void:
	set_card_data(data)


func set_card_data(data: Dictionary) -> void:
	card_kind = str(data.get("card_kind", data.get("kind", ""))).strip_edges()
	card_stats = str(data.get("card_stats", data.get("stats", data.get("rank", "")))).strip_edges()
	set_meta("card_kind", card_kind)
	set_meta("card_stats", card_stats)
	super.set_card_data(data)
