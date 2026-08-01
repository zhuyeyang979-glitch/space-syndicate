extends Control
class_name SpaceSyndicateCommercialCreditsSurface

const CREDITS_DATA_PATH := "res://docs/third_party/credits_data.json"
const SECTION_IDS := ["third_party_assets", "licenses", "music", "fonts"]

@onready var tabs: TabContainer = %CreditsTabs
@onready var section_hosts := {
	"third_party_assets": %ThirdPartyAssetsRows,
	"licenses": %LicensesRows,
	"music": %MusicRows,
	"fonts": %FontsRows,
}

var _data: Dictionary = {}
var _entry_count := 0


func _ready() -> void:
	_data = _load_json(CREDITS_DATA_PATH)
	_render()
	set_meta("presentation_only", true)


func debug_snapshot() -> Dictionary:
	return {
		"surface_id": "commercial_credits_surface_v1",
		"presentation_only": true,
		"section_ids": SECTION_IDS.duplicate(),
		"tab_count": tabs.get_tab_count() if tabs != null else 0,
		"entry_count": _entry_count,
		"game_icons_attribution_ready": str(_data.get("game_icons_attribution", "")).contains("game-icons.net") \
			and str(_data.get("game_icons_attribution", "")).contains("CC BY 3.0"),
		"creates_session": false,
		"reads_save": false,
		"writes_save": false,
		"consumes_rng": false,
	}


func _render() -> void:
	_entry_count = 0
	var sections: Dictionary = _data.get("sections", {}) as Dictionary \
		if _data.get("sections", {}) is Dictionary else {}
	for section_id in SECTION_IDS:
		var host := section_hosts.get(section_id) as VBoxContainer
		if host == null:
			continue
		_clear(host)
		var entries: Array = sections.get(section_id, []) as Array \
			if sections.get(section_id, []) is Array else []
		for entry_variant in entries:
			if entry_variant is Dictionary:
				_add_entry(host, entry_variant as Dictionary)
				_entry_count += 1
	if _entry_count == 0:
		_add_empty_state()


func _add_entry(host: VBoxContainer, entry: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	host.add_child(row)
	var title := Label.new()
	title.text = str(entry.get("title", entry.get("asset_id", "")))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#d8e5f0"))
	row.add_child(title)
	var detail := Label.new()
	detail.text = str(entry.get("detail", entry.get("attribution", entry.get("license", ""))))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", Color("#9fb0c2"))
	row.add_child(detail)
	var separator := HSeparator.new()
	separator.modulate = Color(0.38, 0.44, 0.52, 0.48)
	host.add_child(separator)


func _add_empty_state() -> void:
	var host := section_hosts.get("third_party_assets") as VBoxContainer
	if host == null:
		return
	var label := Label.new()
	label.text = "第三方素材清单尚未载入。"
	label.add_theme_color_override("font_color", Color("#9fb0c2"))
	host.add_child(label)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
