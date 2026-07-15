extends PanelContainer
class_name SpaceSyndicateDistrictInfoPanel

const INDUSTRY_LABELS := {
	"life": "生命",
	"energy": "能源",
	"industry": "工业",
	"technology": "科技",
	"commerce": "商贸",
	"shipping": "航运",
}
const FACILITY_LABELS := {
	"factory": "工厂",
	"market": "市场",
	"road": "道路",
	"port": "港口",
	"spaceport": "星港",
	"warehouse": "仓库",
}

@onready var title_label: Label = %DistrictTitle
@onready var detail_label: Label = %DistrictDetail
@onready var full_detail_label: Label = %DistrictFullDetail
@onready var chip_row: HFlowContainer = %DistrictChipRow

var chips_signature: String = ""


func set_info(title_text: String, detail_text: String, chips: Array = [], full_detail_text: String = "") -> void:
	var full_detail := _player_facing_detail(full_detail_text.strip_edges() if full_detail_text.strip_edges() != "" else detail_text)
	var player_facing_detail := _player_facing_detail(detail_text)
	title_label.text = title_text
	title_label.tooltip_text = full_detail
	detail_label.text = _short_detail(player_facing_detail, 72)
	detail_label.tooltip_text = full_detail
	if full_detail_label != null:
		full_detail_label.text = full_detail
		full_detail_label.tooltip_text = full_detail
	var next_signature := var_to_str(chips)
	if next_signature == chips_signature:
		return
	chips_signature = next_signature
	for child in chip_row.get_children():
		chip_row.remove_child(child)
		child.queue_free()
	for chip_variant in chips.slice(0, 3):
		var chip: Dictionary = chip_variant if chip_variant is Dictionary else {}
		var chip_text := _player_facing_detail(str(chip.get("text", "状态")))
		var label := Label.new()
		label.text = _short_detail(chip_text, 8)
		label.tooltip_text = _player_facing_detail(str(chip.get("tooltip", chip_text)))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_color_override("font_color", chip.get("color", Color("#dbeafe")) as Color)
		chip_row.add_child(label)


func _player_facing_detail(value: String) -> String:
	var result := value
	for industry_id_variant in INDUSTRY_LABELS:
		var industry_id := str(industry_id_variant)
		var industry_label := str(INDUSTRY_LABELS[industry_id])
		for facility_id_variant in FACILITY_LABELS:
			var facility_id := str(facility_id_variant)
			var public_label := "%s%s" % [industry_label, str(FACILITY_LABELS[facility_id])]
			result = result.replace("%s %s" % [industry_id, facility_id], public_label)
			result = result.replace("%s%s" % [industry_id.to_upper(), facility_id], public_label)
	result = result.replace("active 公共设施", "运作中公共设施")
	result = result.replace("developing 公共设施", "发展中公共设施")
	result = result.replace("undeveloped 公共设施", "未开发公共设施")
	result = result.replace("ruined 公共设施", "废墟公共设施")
	return result


func _short_detail(value: String, max_chars: int) -> String:
	var clean := value.replace("\n", " ").strip_edges()
	if clean.length() <= max_chars:
		return clean
	return "%s..." % clean.substr(0, maxi(0, max_chars - 3))
