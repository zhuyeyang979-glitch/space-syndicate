extends VBoxContainer

@export var asset_key := "icon.asset.life"
@export var display_name := "生命资产"
@export var icon: Texture2D
@export var current_value := 4
@export var reserved_value := 1


func _ready() -> void:
	var icon_rect := get_node_or_null("Icon") as TextureRect
	if icon_rect != null:
		icon_rect.texture = icon
	var name_label := get_node_or_null("Name") as Label
	if name_label != null:
		name_label.text = display_name
	var value_label := get_node_or_null("Value") as Label
	if value_label != null:
		value_label.text = "%d/6" % current_value
	var reserved_label := get_node_or_null("Reserved") as Label
	if reserved_label != null:
		reserved_label.text = "预留 %d" % reserved_value
	set_meta("asset_key", asset_key)


func contract_snapshot() -> Dictionary:
	return {
		"asset_key": asset_key,
		"display_name": display_name,
		"current_value": current_value,
		"maximum_presentation_value": 6,
		"reserved_value": reserved_value,
		"owns_rules": false,
	}
