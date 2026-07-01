extends PanelContainer
class_name SpaceSyndicateDistrictInfoPanel

@onready var title_label: Label = %DistrictTitle
@onready var detail_label: Label = %DistrictDetail
@onready var chip_row: HFlowContainer = %DistrictChipRow

func set_info(title_text: String, detail_text: String, chips: Array = []) -> void:
	title_label.text = title_text
	detail_label.text = detail_text
	for child in chip_row.get_children():
		chip_row.remove_child(child)
		child.queue_free()
	for chip_variant in chips:
		var chip: Dictionary = chip_variant if chip_variant is Dictionary else {}
		var label := Label.new()
		label.text = str(chip.get("text", "状态"))
		label.tooltip_text = str(chip.get("tooltip", ""))
		label.add_theme_color_override("font_color", chip.get("color", Color("#dbeafe")) as Color)
		chip_row.add_child(label)
