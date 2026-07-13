extends MarginContainer
class_name SpaceSyndicateProductCodexThumbnailCard

signal preview_requested(catalog_index: int)
signal detail_requested(catalog_index: int)

@onready var badge: Control = %ProductThumbnailBadge

var _catalog_index := -1


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	gui_input.connect(_on_gui_input)


func set_entry(data: Dictionary) -> void:
	_catalog_index = int(data.get("catalog_index", -1))
	tooltip_text = str(data.get("tooltip", "Product detail"))
	var badge_variant: Variant = data.get("badge", {})
	var badge_data := badge_variant as Dictionary if badge_variant is Dictionary else {}
	badge_data["selected"] = bool(data.get("selected", false))
	if badge != null and badge.has_method("set_badge"):
		badge.call("set_badge", badge_data)


func _on_mouse_entered() -> void:
	if _catalog_index >= 0:
		preview_requested.emit(_catalog_index)


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT or _catalog_index < 0:
		return
	if mouse_event.double_click:
		detail_requested.emit(_catalog_index)
	else:
		preview_requested.emit(_catalog_index)
