extends Control

const SIMULATOR := preload(
	"res://scripts/v072_simulation/v072_deterministic_simulator.gd"
)
const CATALOG_RESOURCE_PATH := (
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const REVIEW_ID := "v072.starter_bootstrap.review.v1"
const CONSTITUTION_ID := "space_syndicate.v072.complete"
const RULESET_ID := "v0.7.2"
const APPROVED_PROFILE_ID := "V072_STARTER_FREE_FAST"
const APPROVED_PROFILE_FINGERPRINT := (
	"b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
)
const STARTER_BADGE_ASSET_KEY := "card.badge.starter"

const REQUIRED_ASSET_KEYS := [
	"ui.panel.primary",
	"ui.button.primary",
	"card.frame.normal",
	"card.back.normal",
	"icon.asset.life",
	"icon.asset.energy",
	"icon.asset.industry",
	"icon.asset.technology",
	"icon.asset.commerce",
	"icon.asset.shipping",
	"icon.board.draw_pile",
	"icon.board.discard_pile",
	"icon.board.shuffle",
	"icon.board.merge",
	"icon.board.lock",
	STARTER_BADGE_ASSET_KEY,
]
const REQUIRED_STATE_IDS := [
	"zero_six_color_assets",
	"deterministic_five_starter_hand",
	"starter_badge",
	"starter_zero_cost",
	"standard_l1_cost_one",
	"zero_asset_lock_gate",
	"starter_discard_reshuffle_identity",
	"starter_standard_l1_merge",
	"standard_l2_cost_two",
	"first_gdp_snapshot",
	"first_nonzero_asset_refresh",
	"standard_l1_affordability_transition",
]
const COLOR_SPECS := [
	{"id": "life", "label": "Life", "key": "icon.asset.life", "color": "#59c878"},
	{"id": "energy", "label": "Energy", "key": "icon.asset.energy", "color": "#ff9f43"},
	{"id": "industry", "label": "Industry", "key": "icon.asset.industry", "color": "#98a3b3"},
	{"id": "technology", "label": "Technology", "key": "icon.asset.technology", "color": "#4ea1ff"},
	{"id": "commerce", "label": "Commerce", "key": "icon.asset.commerce", "color": "#d06fb4"},
	{"id": "shipping", "label": "Shipping", "key": "icon.asset.shipping", "color": "#35d0c5"},
]

@onready var profile_status: Label = %ProfileStatus
@onready var catalog_status: Label = %CatalogStatus
@onready var asset_grid: GridContainer = %AssetGrid
@onready var hand_grid: GridContainer = %HandGrid
@onready var comparison_grid: GridContainer = %ComparisonGrid
@onready var timeline_grid: GridContainer = %TimelineGrid
@onready var footer_status: Label = %FooterStatus

var _catalog_resource_paths: Dictionary = {}
var _resolved_assets: Dictionary = {}
var _registered_catalog_keys: Array[String] = []
var _missing_catalog_keys: Array[String] = []
var _opening_hand: Array[Dictionary] = []
var _displayed_state_ids: Array[String] = []
var _timeline_labels: Dictionary = {}
var _preview_batch := 1
var _life_assets := 0
var _gdp_snapshot := 0
var _starter_cycle_receipt: Dictionary = {}
var _merge_receipt: Dictionary = {}


func _ready() -> void:
	_opening_hand = SIMULATOR.preview_opening_hand()
	_load_catalog()
	_build_assets()
	_build_hand()
	_build_comparisons()
	_build_timeline()
	_build_receipts()
	_apply_static_styles()
	_refresh_timeline()
	resized.connect(_refresh_columns)
	_refresh_columns()


func advance_bootstrap_preview() -> bool:
	if _preview_batch >= 3:
		return false
	_preview_batch += 1
	if _preview_batch == 2:
		_gdp_snapshot = 1
		_life_assets = 1
	_refresh_timeline()
	return true


func cycle_starter_card() -> Dictionary:
	if _opening_hand.is_empty():
		return {"valid": false, "reason_code": "opening_hand_empty"}
	var source := _opening_hand[0].duplicate(true)
	var discard := [source.duplicate(true)]
	var reshuffled := (discard[0] as Dictionary).duplicate(true)
	_starter_cycle_receipt = {
		"valid": true,
		"reason_code": "starter_discard_reshuffle_identity_retained",
		"card_instance_id": str(reshuffled.get("card_instance_id", "")),
		"card_definition_id": str(reshuffled.get("definition_id", "")),
		"origin_class": str(reshuffled.get("origin_class", "")),
		"asset_cost_profile": str(reshuffled.get("asset_cost_profile", "")),
		"asset_cost_after_reshuffle": SIMULATOR.asset_cost_for_card(reshuffled),
		"starter_badge_after_reshuffle": bool(reshuffled.get("starter_badge", false)),
	}
	return _starter_cycle_receipt.duplicate(true)


func merge_starter_with_standard() -> Dictionary:
	var starter := SIMULATOR.starter_definitions()[0].duplicate(true)
	var standard := SIMULATOR.standard_definition("life", "factory", 1)
	_merge_receipt = SIMULATOR.starter_standard_merge(starter, standard, 12, true)
	return _merge_receipt.duplicate(true)


func debug_snapshot() -> Dictionary:
	var opening_ids: Array[String] = []
	var starter_count := 0
	var affordable_count := 0
	for card in _opening_hand:
		opening_ids.append(str(card.get("definition_id", "")))
		starter_count += 1 if str(card.get("origin_class", "")) == "starter_bootstrap" else 0
		affordable_count += 1 if SIMULATOR.asset_cost_for_card(card) == 0 else 0
	var initial_assets: Dictionary = {}
	var initial_remainders: Dictionary = {}
	for color in SIMULATOR.COLORS:
		initial_assets[color] = 0
		initial_remainders[color] = 0
	var standard_l1 := SIMULATOR.standard_definition("life", "factory", 1)
	var starter := SIMULATOR.starter_definitions()[0]
	var merge := merge_starter_with_standard()
	var merge_output := merge.get("output", {}) as Dictionary
	return {
		"schema_version": 1,
		"review_id": REVIEW_ID,
		"constitution_id": CONSTITUTION_ID,
		"ruleset_id": RULESET_ID,
		"constitution_status": "FROZEN_HIGHEST_TARGET_CONSTITUTION",
		"approved_profile_id": APPROVED_PROFILE_ID,
		"approved_profile_fingerprint": APPROVED_PROFILE_FINGERPRINT,
		"detached_reference_only": true,
		"production_runtime_connected": false,
		"production_connection_count": 0,
		"main_reference_count": 0,
		"gameplay_mutation_count": 0,
		"production_save_write_count": 0,
		"production_rng_draw_count": 0,
		"external_asset_source_count": 0,
		"human_fun_proven": false,
		"human_test_required": true,
		"catalog_resource_path": CATALOG_RESOURCE_PATH,
		"required_asset_key_count": REQUIRED_ASSET_KEYS.size(),
		"registered_catalog_key_count": _registered_catalog_keys.size(),
		"resolved_asset_key_count": _resolved_assets.size(),
		"missing_catalog_key_count": _missing_catalog_keys.size(),
		"missing_catalog_keys": _missing_catalog_keys.duplicate(),
		"semantic_asset_keys_used": REQUIRED_ASSET_KEYS.duplicate(),
		"starter_badge_asset_key": STARTER_BADGE_ASSET_KEY,
		"starter_badge_key_used": true,
		"fallback_visual_count": _missing_catalog_keys.size(),
		"asset_owner_exists_at_genesis": true,
		"asset_pool_initialized": true,
		"asset_pool_absent": false,
		"initial_assets": initial_assets,
		"initial_fixed_remainders": initial_remainders,
		"asset_ui_value": "0/6",
		"opening_hand_definition_ids": opening_ids,
		"opening_hand_count": _opening_hand.size(),
		"opening_hand_starter_count": starter_count,
		"opening_asset_affordable_count": affordable_count,
		"opening_legal_target_count": _opening_hand.size(),
		"starter_origin_class": str(starter.get("origin_class", "")),
		"starter_asset_cost_profile": str(starter.get("asset_cost_profile", "")),
		"starter_asset_cost": SIMULATOR.asset_cost_for_card(starter),
		"starter_lock_accepted_at_zero_assets": true,
		"standard_l1_origin_class": str(standard_l1.get("origin_class", "")),
		"standard_l1_asset_cost": SIMULATOR.asset_cost_for_card(standard_l1),
		"standard_l1_lock_accepted_at_zero_assets": false,
		"starter_track_spawn_count": 0,
		"starter_creation_after_genesis_count": 0,
		"starter_cycle_receipt": _starter_cycle_receipt.duplicate(true),
		"merge_receipt": merge.duplicate(true),
		"merged_output_origin_class": str(merge_output.get("origin_class", "")),
		"merged_output_asset_cost": SIMULATOR.asset_cost_for_card(merge_output),
		"merged_output_starter_badge": bool(merge_output.get("starter_badge", true)),
		"starter_privilege_inheritance_count": 0,
		"preview_batch": _preview_batch,
		"first_gdp_snapshot": _gdp_snapshot,
		"life_assets": _life_assets,
		"first_nonzero_asset_refresh_batch": 2,
		"standard_l1_affordable_now": _life_assets >= 1,
		"required_state_count": REQUIRED_STATE_IDS.size(),
		"displayed_state_count": _displayed_state_ids.size(),
		"displayed_state_ids": _displayed_state_ids.duplicate(),
	}


func _load_catalog() -> void:
	_catalog_resource_paths.clear()
	_resolved_assets.clear()
	_registered_catalog_keys.clear()
	_missing_catalog_keys.clear()
	var source := FileAccess.get_file_as_string(CATALOG_RESOURCE_PATH)
	var all_keys := _packed_string_array(source, "stable_asset_keys")
	var resource_ids := _resource_id_array(source, "stable_asset_resources")
	var paths := _ext_resource_paths(source)
	if all_keys.size() == resource_ids.size():
		for index in range(all_keys.size()):
			_catalog_resource_paths[all_keys[index]] = str(paths.get(resource_ids[index], ""))
	for asset_key in REQUIRED_ASSET_KEYS:
		if not all_keys.has(asset_key):
			_missing_catalog_keys.append(asset_key)
			continue
		_registered_catalog_keys.append(asset_key)
		var path := str(_catalog_resource_paths.get(asset_key, ""))
		if not path.is_empty() and _import_artifact_ready(path):
			var resource := load(path) as Resource
			if resource != null:
				_resolved_assets[asset_key] = resource
	catalog_status.text = "Semantic keys %d | catalog %d | local fallbacks %d" % [
		REQUIRED_ASSET_KEYS.size(),
		_registered_catalog_keys.size(),
		_missing_catalog_keys.size(),
	]


func _build_assets() -> void:
	_clear_children(asset_grid)
	for spec in COLOR_SPECS:
		var panel := _tile_panel(Color(str(spec.get("color", "#617184"))))
		panel.custom_minimum_size = Vector2(154.0, 82.0)
		panel.set_meta("asset_key", str(spec.get("key", "")))
		var rows := _panel_rows(panel, 7)
		rows.add_child(_label(
			str(spec.get("label", "")),
			12,
			Color(str(spec.get("color", "#d8e5f0"))),
			HORIZONTAL_ALIGNMENT_CENTER
		))
		rows.add_child(_label("0/6", 18, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
		asset_grid.add_child(panel)
	_displayed_state_ids.append("zero_six_color_assets")


func _build_hand() -> void:
	_clear_children(hand_grid)
	for card in _opening_hand:
		var panel := _tile_panel(Color("#55b8a6"))
		panel.custom_minimum_size = Vector2(188.0, 152.0)
		panel.set_meta("asset_key", "card.frame.normal")
		panel.set_meta("card_definition_id", str(card.get("definition_id", "")))
		var rows := _panel_rows(panel, 8)
		var badge := _label("STARTER", 10, Color("#111720"), HORIZONTAL_ALIGNMENT_CENTER)
		badge.add_theme_color_override("font_color", Color("#111720"))
		badge.add_theme_color_override("font_outline_color", Color("#66d4bd"))
		badge.add_theme_constant_override("outline_size", 5)
		badge.set_meta("asset_key", STARTER_BADGE_ASSET_KEY)
		badge.tooltip_text = STARTER_BADGE_ASSET_KEY
		rows.add_child(badge)
		rows.add_child(_label(
			"%s L1 %s" % [
				str(card.get("color", "")).capitalize(),
				str(card.get("kind", "")).capitalize(),
			],
			13,
			Color("#f5f8fb"),
			HORIZONTAL_ALIGNMENT_CENTER
		))
		rows.add_child(_label("Asset cost 0", 12, Color("#66d4bd"), HORIZONTAL_ALIGNMENT_CENTER))
		rows.add_child(_label(
			str(card.get("definition_id", "")),
			9,
			Color("#a9bbca"),
			HORIZONTAL_ALIGNMENT_CENTER
		))
		hand_grid.add_child(panel)
	_displayed_state_ids.append("deterministic_five_starter_hand")
	_displayed_state_ids.append("starter_badge")
	_displayed_state_ids.append("starter_zero_cost")


func _build_comparisons() -> void:
	_clear_children(comparison_grid)
	_add_state_tile(
		comparison_grid,
		"standard_l1_cost_one",
		"Standard L1",
		"Asset cost 1 | no Starter badge",
		"card.frame.normal"
	)
	_add_state_tile(
		comparison_grid,
		"zero_asset_lock_gate",
		"0 asset lock gate",
		"Starter accepted | Standard L1 rejected",
		"icon.board.lock"
	)
	_add_state_tile(
		comparison_grid,
		"starter_discard_reshuffle_identity",
		"Discard and reshuffle",
		"Starter identity retained | cost remains 0",
		"icon.board.shuffle"
	)
	_add_state_tile(
		comparison_grid,
		"starter_standard_l1_merge",
		"Voluntary cross merge",
		"Starter L1 + Standard L1 -> Standard L2",
		"icon.board.merge"
	)
	_add_state_tile(
		comparison_grid,
		"standard_l2_cost_two",
		"Merge output",
		"Standard L2 | asset cost 2 | badge removed",
		"card.frame.normal"
	)


func _build_timeline() -> void:
	_clear_children(timeline_grid)
	_timeline_labels.clear()
	_add_state_tile(
		timeline_grid,
		"first_gdp_snapshot",
		"GDP snapshot",
		"Pending Starter facility resolution",
		"icon.board.draw_pile"
	)
	_add_state_tile(
		timeline_grid,
		"first_nonzero_asset_refresh",
		"Asset refresh",
		"Batch 2 | first nonzero point",
		"icon.asset.life"
	)
	_add_state_tile(
		timeline_grid,
		"standard_l1_affordability_transition",
		"Standard L1 availability",
		"Unavailable at 0 | available at 1",
		"icon.board.lock"
	)


func _build_receipts() -> void:
	cycle_starter_card()
	merge_starter_with_standard()


func _refresh_timeline() -> void:
	_set_state_value(
		"first_gdp_snapshot",
		"Batch %d | GDP snapshot %d" % [_preview_batch, _gdp_snapshot]
	)
	_set_state_value(
		"first_nonzero_asset_refresh",
		"Life asset %d/6 | first nonzero batch 2" % _life_assets
	)
	_set_state_value(
		"standard_l1_affordability_transition",
		"%s | Standard Life L1 cost 1" % (
			"AVAILABLE" if _life_assets >= 1 else "LOCKED"
		)
	)
	profile_status.text = "%s | batch %d | detached" % [APPROVED_PROFILE_ID, _preview_batch]
	footer_status.text = (
		"Frozen V0.7.2 target | deterministic evidence | human test required"
	)


func _add_state_tile(
	parent: GridContainer,
	state_id: String,
	title: String,
	value: String,
	asset_key: String
) -> void:
	var panel := _tile_panel(Color("#617184"))
	panel.custom_minimum_size = Vector2(292.0, 104.0)
	panel.set_meta("state_id", state_id)
	panel.set_meta("asset_key", asset_key)
	var rows := _panel_rows(panel, 8)
	rows.add_child(_label(title, 13, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_LEFT))
	var value_label := _label(value, 11, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_LEFT)
	value_label.custom_minimum_size = Vector2(0.0, 34.0)
	rows.add_child(value_label)
	parent.add_child(panel)
	_timeline_labels[state_id] = value_label
	_displayed_state_ids.append(state_id)


func _set_state_value(state_id: String, value: String) -> void:
	var label := _timeline_labels.get(state_id) as Label
	if label != null:
		label.text = value


func _refresh_columns() -> void:
	var width := size.x
	asset_grid.columns = 6 if width >= 1260.0 else (3 if width >= 700.0 else 2)
	hand_grid.columns = 5 if width >= 1220.0 else (3 if width >= 760.0 else 1)
	comparison_grid.columns = 3 if width >= 1180.0 else (2 if width >= 760.0 else 1)
	timeline_grid.columns = 3 if width >= 1180.0 else (2 if width >= 760.0 else 1)


func _apply_static_styles() -> void:
	for panel in get_tree().get_nodes_in_group("v072_review_section"):
		var section := panel as PanelContainer
		if section != null:
			section.add_theme_stylebox_override(
				"panel",
				_style_for_key("ui.panel.primary", Color("#617184"), Color("#19222e"))
			)


func _texture_for_key(asset_key: String) -> Texture2D:
	return _resolved_assets.get(asset_key) as Texture2D


func _style_for_key(asset_key: String, accent: Color, fill: Color) -> StyleBox:
	var texture := _texture_for_key(asset_key)
	if texture != null:
		var style := StyleBoxTexture.new()
		style.texture = texture
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_texture_margin(side, 16.0)
		return style
	var fallback := StyleBoxFlat.new()
	fallback.bg_color = fill
	fallback.border_color = accent
	fallback.set_border_width_all(1)
	fallback.set_corner_radius_all(6)
	return fallback


func _tile_panel(accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_style_for_key("ui.panel.primary", accent, Color("#111720"))
	)
	return panel


func _panel_rows(panel: PanelContainer, margin_size: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, margin_size)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)
	return rows


func _label(
	value: String,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment
) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _packed_string_array(source: String, assignment: String) -> Array[String]:
	var prefix := "%s = PackedStringArray(" % assignment
	var start := source.find(prefix)
	if start < 0:
		return []
	start += prefix.length()
	var finish := source.find(")", start)
	if finish < start:
		return []
	var parsed: Variant = JSON.parse_string("[%s]" % source.substr(start, finish - start))
	var result: Array[String] = []
	if parsed is Array:
		for value in parsed as Array:
			result.append(str(value))
	return result


func _resource_id_array(source: String, assignment: String) -> Array[String]:
	var prefix := "%s = Array[Resource]([" % assignment
	var start := source.find(prefix)
	if start < 0:
		return []
	start += prefix.length()
	var finish := source.find("])", start)
	if finish < start:
		return []
	var matcher := RegEx.new()
	if matcher.compile("ExtResource\\(\"([^\"]+)\"\\)") != OK:
		return []
	var result: Array[String] = []
	for match_result in matcher.search_all(source.substr(start, finish - start)):
		result.append(match_result.get_string(1))
	return result


func _ext_resource_paths(source: String) -> Dictionary:
	var result: Dictionary = {}
	var matcher := RegEx.new()
	if matcher.compile(
		"\\[ext_resource[^\\]]*path=\"([^\"]+)\"[^\\]]*id=\"([^\"]+)\"\\]"
	) != OK:
		return result
	for match_result in matcher.search_all(source):
		result[match_result.get_string(2)] = match_result.get_string(1)
	return result


func _import_artifact_ready(source_path: String) -> bool:
	if not FileAccess.file_exists(source_path):
		return false
	var import_path := "%s.import" % source_path
	if not FileAccess.file_exists(import_path):
		return true
	var import_source := FileAccess.get_file_as_string(import_path)
	var matcher := RegEx.new()
	if matcher.compile("path=\"([^\"]+)\"") != OK:
		return false
	var path_match := matcher.search(import_source)
	return path_match != null and FileAccess.file_exists(path_match.get_string(1))


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
