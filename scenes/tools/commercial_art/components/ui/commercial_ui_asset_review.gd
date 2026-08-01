extends Control

const FONT_LOCALE_SELECTOR := preload("res://scenes/tools/commercial_art/components/ui/commercial_font_locale_selector.gd")

const REQUIRED_ASSET_KEYS := [
	"icon.asset.life",
	"icon.asset.energy",
	"icon.asset.industry",
	"icon.asset.technology",
	"icon.asset.commerce",
	"icon.asset.shipping",
]


func _ready() -> void:
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	if OS.get_cmdline_user_args().has("--print-layout"):
		call_deferred("_print_layout")


func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	var design_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1600)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 960))
	)
	if get_parent() is Control:
		design_size = (get_parent() as Control).size
	size = design_size


func _print_layout() -> void:
	print("COMMERCIAL_UI_RUNTIME_LAYOUT %s" % JSON.stringify(layout_snapshot()))


func debug_snapshot() -> Dictionary:
	var metadata_values: Dictionary = {}
	_collect_metadata(self, metadata_values)
	var icon_keys: Array = metadata_values.get("asset_key", [])
	var frame_keys: Array = metadata_values.get("card_frame_key", [])
	return {
		"review_only": true,
		"creates_session": false,
		"writes_save": false,
		"consumes_rng": false,
		"six_color_icon_keys": icon_keys,
		"six_color_icon_count": icon_keys.size(),
		"card_frame_keys": frame_keys,
		"card_frame_count": frame_keys.size(),
		"input_prompt_count": (metadata_values.get("prompt_id", []) as Array).size(),
		"board_icon_count": (metadata_values.get("board_semantic", []) as Array).size(),
		"font_contract": FONT_LOCALE_SELECTOR.contract_snapshot(),
	}


func layout_snapshot() -> Dictionary:
	var paths := {
		"root": NodePath("."),
		"safe_margin": NodePath("SafeMargin"),
		"rows": NodePath("SafeMargin/Rows"),
		"header": NodePath("SafeMargin/Rows/Header"),
		"title": NodePath("SafeMargin/Rows/Header/Title"),
		"metrics": NodePath("SafeMargin/Rows/Header/Metrics"),
		"cards_panel": NodePath("SafeMargin/Rows/Body/CardsPanel"),
		"side_panel": NodePath("SafeMargin/Rows/Body/SidePanel"),
	}
	var result: Dictionary = {}
	for key in paths:
		var control := get_node_or_null(paths[key]) as Control
		if control != null:
			result[key] = {
				"global_position": [control.global_position.x, control.global_position.y],
				"size": [control.size.x, control.size.y],
				"scale": [control.get_global_transform().get_scale().x, control.get_global_transform().get_scale().y],
				"combined_minimum_size": [control.get_combined_minimum_size().x, control.get_combined_minimum_size().y],
			}
			if control is Label:
				var label := control as Label
				result[key]["minimum_size"] = [label.get_combined_minimum_size().x, label.get_combined_minimum_size().y]
				result[key]["horizontal_alignment"] = label.horizontal_alignment
				result[key]["layout_direction"] = label.layout_direction
				result[key]["text_direction"] = label.text_direction
				result[key]["autowrap_mode"] = label.autowrap_mode
	return result


func _collect_metadata(node: Node, values: Dictionary) -> void:
	for key in ["asset_key", "card_frame_key", "prompt_id", "board_semantic"]:
		if node.has_meta(key):
			var rows: Array = values.get(key, [])
			rows.append(str(node.get_meta(key)))
			values[key] = rows
	for child in node.get_children():
		_collect_metadata(child, values)
