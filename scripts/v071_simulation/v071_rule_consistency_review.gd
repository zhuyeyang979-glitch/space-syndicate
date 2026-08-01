extends Control

const SIMULATOR := preload(
	"res://scripts/v071_simulation/v071_deterministic_simulator.gd"
)
const CATALOG_RESOURCE_PATH := (
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)

const REVIEW_ID := "v071.rule_consistency.review.v2"
const CONSTITUTION_ID := "space_syndicate.v071.complete"
const RULESET_ID := "v0.7.1"
const APPROVED_PROFILE_ID := "V071_CANDIDATE_A_FAST"
const APPROVED_PROFILE_FINGERPRINT := (
	"8d8de8d406ca2f7d5123ecc951a606a0a08b56282bc3d6a40e0cd4d5ff50f19a"
)
const REQUIRED_ASSET_KEYS := [
	"ui.panel.primary",
	"ui.panel.popup",
	"ui.button.primary",
	"icon.asset.life",
	"icon.asset.energy",
	"icon.asset.industry",
	"icon.asset.technology",
	"icon.asset.commerce",
	"icon.asset.shipping",
	"card.frame.normal",
	"card.frame.commodity",
	"card.frame.bound_action",
	"card.back.normal",
	"icon.board.draw_pile",
	"icon.board.discard_pile",
	"icon.board.shuffle",
	"icon.board.merge",
	"icon.board.lock",
	"icon.board.turn",
	"icon.board.target",
	"icon.board.card_count",
	"icon.board.settlement",
	"icon.board.player_order",
	"font.body.zh",
	"font.display",
]
const REQUIRED_STATE_IDS := [
	"unified_track",
	"locked_replacement",
	"lead_batch_timer",
	"color_cycle_batch_timer",
	"player_private_lead_notice",
	"ai_private_lead_notice",
	"personal_dbg_zones",
	"minimum_five_merge_rejection",
	"commodity_batch_availability",
	"invalid_target_refund_receipt",
	"six_color_refresh_cap",
	"maintenance_timeout",
	"anonymous_resolution",
	"victory_pending_tail",
]

const COLOR_SPECS := [
	{"id": "life", "label": "Life", "key": "icon.asset.life", "color": "#59c878"},
	{"id": "energy", "label": "Energy", "key": "icon.asset.energy", "color": "#ff9f43"},
	{"id": "industry", "label": "Industry", "key": "icon.asset.industry", "color": "#98a3b3"},
	{"id": "technology", "label": "Technology", "key": "icon.asset.technology", "color": "#4ea1ff"},
	{"id": "commerce", "label": "Commerce", "key": "icon.asset.commerce", "color": "#b66cff"},
	{"id": "shipping", "label": "Shipping", "key": "icon.asset.shipping", "color": "#35d0c5"},
]

@onready var profile_selector: OptionButton = %ProfileSelector
@onready var player_count_selector: OptionButton = %PlayerCountSelector
@onready var catalog_status: Label = %CatalogStatus
@onready var profile_status: Label = %ProfileStatus
@onready var track_grid: GridContainer = %TrackGrid
@onready var asset_grid: GridContainer = %AssetGrid
@onready var state_grid: GridContainer = %StateGrid
@onready var footer_status: Label = %FooterStatus

var _catalog: Resource
var _catalog_key_registry_ready := false
var _registered_asset_keys: Array[String] = []
var _catalog_resource_paths: Dictionary = {}
var _resolved_assets: Dictionary = {}
var _missing_asset_keys: Array[String] = []
var _unresolved_resource_keys: Array[String] = []
var _profiles: Array[Dictionary] = []
var _selected_profile: Dictionary = {}
var _selected_player_count := 4
var _completed_batch_count := 7
var _state_value_labels: Dictionary = {}
var _displayed_state_ids: Array[String] = []


func _ready() -> void:
	_profiles = SIMULATOR.profiles()
	_load_catalog()
	_populate_selectors()
	_build_track_preview()
	_build_asset_preview()
	_build_state_preview()
	_apply_static_styles()
	if not _profiles.is_empty():
		select_profile(str(_profiles[1].get("profile_id", "")))
	select_player_count(4)
	resized.connect(_refresh_columns)
	_refresh_columns()


func select_profile(profile_id: String) -> bool:
	for index in range(_profiles.size()):
		var profile := _profiles[index]
		if str(profile.get("profile_id", "")) != profile_id:
			continue
		_selected_profile = profile.duplicate(true)
		profile_selector.select(index)
		_refresh_profile_state()
		return true
	return false


func select_player_count(player_count: int) -> bool:
	if player_count not in SIMULATOR.PLAYER_COUNTS:
		return false
	_selected_player_count = player_count
	player_count_selector.select(SIMULATOR.PLAYER_COUNTS.find(player_count))
	_refresh_profile_state()
	return true


func advance_preview_batch() -> bool:
	_completed_batch_count += 1
	_refresh_profile_state()
	return true


func debug_snapshot() -> Dictionary:
	var closure := SIMULATOR.candidate_closure_contract()
	return {
		"schema_version": 2,
		"review_id": REVIEW_ID,
		"constitution_id": CONSTITUTION_ID,
		"ruleset_id": RULESET_ID,
		"constitution_status": "FROZEN_HIGHEST_TARGET_CONSTITUTION",
		"candidate_status": "APPROVED_FIRST_HUMAN_TEST_SAMPLE",
		"v071_candidate_not_highest_authority": false,
		"v071_highest_constitution_frozen": true,
		"approved_profile_id": APPROVED_PROFILE_ID,
		"approved_profile_fingerprint": APPROVED_PROFILE_FINGERPRINT,
		"detached_reference_only": true,
		"production_runtime_connected": false,
		"production_connection_count": 0,
		"main_reference_count": 0,
		"gameplay_mutation_count": 0,
		"save_write_count": 0,
		"production_rng_draw_count": 0,
		"external_asset_source_count": 0,
		"human_fun_proven": false,
		"human_test_still_required": true,
		"selected_profile_id": str(_selected_profile.get("profile_id", "")),
		"selected_profile_fingerprint": str(
			_selected_profile.get("profile_fingerprint", "")
		),
		"selected_player_count": _selected_player_count,
		"completed_batch_count": _completed_batch_count,
		"simulation_agent_policy_id": SIMULATOR.SIMULATION_AGENT_POLICY_ID,
		"catalog_resource_path": CATALOG_RESOURCE_PATH,
		"catalog_loaded": _catalog != null,
		"catalog_key_registry_ready": _catalog_key_registry_ready,
		"required_asset_key_count": REQUIRED_ASSET_KEYS.size(),
		"registered_asset_key_count": _registered_asset_keys.size(),
		"resolved_asset_key_count": _resolved_assets.size(),
		"missing_asset_key_count": _missing_asset_keys.size(),
		"missing_asset_keys": _missing_asset_keys.duplicate(),
		"unresolved_resource_count": _unresolved_resource_keys.size(),
		"unresolved_resource_keys": _unresolved_resource_keys.duplicate(),
		"fallback_visual_count": _unresolved_resource_keys.size(),
		"required_state_count": REQUIRED_STATE_IDS.size(),
		"displayed_state_count": _displayed_state_ids.size(),
		"displayed_state_ids": _displayed_state_ids.duplicate(),
		"track_replacement_claimable_same_tick": false,
		"normal_deck_minimum_total_card_count": int(
			closure.get("normal_deck_minimum_total_card_count", 0)
		),
		"normal_track_spawn_level": int(closure.get("normal_track_spawn_level", 0)),
		"commodity_track_spawn_level": int(
			closure.get("commodity_track_spawn_level", 0)
		),
		"player_self_is_current_lead": true,
		"player_self_influence_class": "double",
		"ai_self_is_current_lead": true,
		"ai_self_influence_class": "double",
		"ai_other_lead_identity_exposure_count": 0,
		"hidden_order_exposure_count": 0,
		"anonymous_resolution_owner_identity_exposure_count": 0,
		"solar_render_is_core_owner": false,
	}


func _load_catalog() -> void:
	_catalog = null
	_catalog_key_registry_ready = false
	_registered_asset_keys.clear()
	_catalog_resource_paths.clear()
	_resolved_assets.clear()
	_missing_asset_keys.clear()
	_unresolved_resource_keys.clear()
	var source := FileAccess.get_file_as_string(CATALOG_RESOURCE_PATH)
	var all_keys := _packed_string_array(source, "stable_asset_keys")
	var resource_ids := _resource_id_array(source, "stable_asset_resources")
	var ext_resource_paths := _ext_resource_paths(source)
	if not all_keys.is_empty() and all_keys.size() == resource_ids.size():
		_catalog_key_registry_ready = true
		for index in range(all_keys.size()):
			var key := all_keys[index]
			var resource_id := resource_ids[index]
			_catalog_resource_paths[key] = str(ext_resource_paths.get(resource_id, ""))
	for asset_key in REQUIRED_ASSET_KEYS:
		if not all_keys.has(asset_key):
			_missing_asset_keys.append(asset_key)
			continue
		_registered_asset_keys.append(asset_key)
		var resource := _resource_for_asset_key(asset_key)
		if resource != null:
			_resolved_assets[asset_key] = resource
		else:
			_unresolved_resource_keys.append(asset_key)
	catalog_status.text = "Catalog keys %d/%d | resources %d" % [
		_registered_asset_keys.size(),
		REQUIRED_ASSET_KEYS.size(),
		_resolved_assets.size(),
	]
	catalog_status.add_theme_color_override(
		"font_color",
		Color("#59c878") if _missing_asset_keys.is_empty() else Color("#ff9f43")
	)


func _populate_selectors() -> void:
	profile_selector.clear()
	for profile in _profiles:
		profile_selector.add_item(str(profile.get("profile_id", "")))
	profile_selector.item_selected.connect(func(index: int) -> void:
		if index >= 0 and index < _profiles.size():
			select_profile(str(_profiles[index].get("profile_id", "")))
	)
	player_count_selector.clear()
	for player_count in SIMULATOR.PLAYER_COUNTS:
		player_count_selector.add_item("%d players" % player_count)
	player_count_selector.item_selected.connect(func(index: int) -> void:
		if index >= 0 and index < SIMULATOR.PLAYER_COUNTS.size():
			select_player_count(int(SIMULATOR.PLAYER_COUNTS[index]))
	)


func _build_track_preview() -> void:
	_clear_children(track_grid)
	_add_track_card(
		"L1 Factory",
		"Normal | Life | cash purchase",
		"card.frame.normal",
		"icon.asset.life"
	)
	_add_track_card(
		"L1 Commodity",
		"Commodity | Energy | direct claim",
		"card.frame.commodity",
		"icon.asset.energy"
	)
	_add_track_card(
		"Incoming",
		"LOCKED | claimable next scroll",
		"card.back.normal",
		"icon.board.lock"
	)
	_add_track_card(
		"L1 Market",
		"Normal | Commerce | level-one supply",
		"card.frame.normal",
		"icon.asset.commerce"
	)
	_add_track_card(
		"Bound Action",
		"Source-bound | not normal hand",
		"card.frame.bound_action",
		"icon.board.target"
	)
	_displayed_state_ids.append("unified_track")
	_displayed_state_ids.append("locked_replacement")


func _build_asset_preview() -> void:
	_clear_children(asset_grid)
	for spec in COLOR_SPECS:
		var panel := _tile_panel(Color(str(spec.get("color", "#617184"))))
		panel.custom_minimum_size = Vector2(126.0, 88.0)
		panel.set_meta("asset_key", str(spec.get("key", "")))
		var rows := _panel_rows(panel, 6)
		var texture := _texture_for_key(str(spec.get("key", "")))
		if texture != null:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(30.0, 30.0)
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rows.add_child(icon)
		rows.add_child(_label(
			"%s 2/6 | +3 max" % str(spec.get("label", "")),
			11,
			Color(str(spec.get("color", "#d8e5f0"))),
			HORIZONTAL_ALIGNMENT_CENTER
		))
		asset_grid.add_child(panel)
	_displayed_state_ids.append("six_color_refresh_cap")


func _build_state_preview() -> void:
	_clear_children(state_grid)
	_state_value_labels.clear()
	_add_state_tile(
		"lead_batch_timer",
		"Lead boundary",
		"Completed batches: pending",
		"icon.board.turn"
	)
	_add_state_tile(
		"color_cycle_batch_timer",
		"Color cycle",
		"Outgoing lead weights before advance",
		"icon.board.turn"
	)
	_add_state_tile(
		"player_private_lead_notice",
		"Private player fact",
		"YOU ARE CURRENT LEAD | influence double",
		"icon.board.player_order"
	)
	_add_state_tile(
		"ai_private_lead_notice",
		"Private AI fact",
		"self_is_current_lead=true | class=double",
		"icon.board.player_order"
	)
	_add_state_tile(
		"personal_dbg_zones",
		"Personal DBG",
		"Draw 7 | Hand 5 | Discard 3",
		"icon.board.draw_pile"
	)
	_add_state_tile(
		"minimum_five_merge_rejection",
		"Merge admission",
		"6 -> 5 accepted | 5 -> 4 rejected",
		"icon.board.merge"
	)
	_add_state_tile(
		"commodity_batch_availability",
		"Commodity timing",
		"Before lock: current | after lock: next",
		"card.frame.commodity"
	)
	_add_state_tile(
		"invalid_target_refund_receipt",
		"Invalid target receipt",
		"FIZZLE | full asset refund | card to discard",
		"icon.board.target"
	)
	_add_state_tile(
		"maintenance_timeout",
		"Hand maintenance",
		"8 seconds | end without automatic merge",
		"icon.board.lock"
	)
	_add_state_tile(
		"anonymous_resolution",
		"Anonymous resolution",
		"Receipt order retained | owner not published",
		"icon.board.settlement"
	)
	_add_state_tile(
		"victory_pending_tail",
		"Victory pending",
		"Remaining macro-round windows: pending",
		"icon.board.card_count"
	)


func _add_track_card(
	title: String,
	detail: String,
	frame_key: String,
	icon_key: String
) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(210.0, 126.0)
	panel.add_theme_stylebox_override(
		"panel",
		_style_for_key(frame_key, Color("#617184"), Color("#111720"))
	)
	panel.set_meta("asset_key", frame_key)
	var rows := _panel_rows(panel, 8)
	var texture := _texture_for_key(icon_key)
	if texture != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(38.0, 38.0)
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = icon_key
		rows.add_child(icon)
	rows.add_child(_label(title, 14, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
	rows.add_child(_label(detail, 10, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_CENTER))
	track_grid.add_child(panel)


func _add_state_tile(
	state_id: String,
	title: String,
	value: String,
	asset_key: String
) -> void:
	var panel := _tile_panel(Color("#617184"))
	panel.custom_minimum_size = Vector2(294.0, 116.0)
	panel.set_meta("state_id", state_id)
	panel.set_meta("asset_key", asset_key)
	var rows := _panel_rows(panel, 7)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 7)
	var texture := _texture_for_key(asset_key)
	if texture != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24.0, 24.0)
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heading.add_child(icon)
	var title_label := _label(title, 13, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_LEFT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_label)
	rows.add_child(heading)
	var value_label := _label(value, 11, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_LEFT)
	value_label.custom_minimum_size = Vector2(0.0, 38.0)
	rows.add_child(value_label)
	state_grid.add_child(panel)
	_state_value_labels[state_id] = value_label
	_displayed_state_ids.append(state_id)


func _refresh_profile_state() -> void:
	if _selected_profile.is_empty():
		return
	var profile_id := str(_selected_profile.get("profile_id", ""))
	var lead_batches := int(_selected_profile.get("lead_tenure_batches", 1))
	var color_batches := int(_selected_profile.get("color_cycle_batches", 6))
	var lead_cursor := _completed_batch_count % lead_batches
	var color_cursor := _completed_batch_count % color_batches
	var macro_round_windows := maxi(
		0,
		_selected_player_count * lead_batches \
			- (_completed_batch_count % (_selected_player_count * lead_batches))
	)
	_set_state_value(
		"lead_batch_timer",
		"Completed batch cursor %d/%d | independent boundary" % [
			lead_cursor,
			lead_batches,
		]
	)
	_set_state_value(
		"color_cycle_batch_timer",
		"Color cursor %d/%d | commit then lead advance" % [
			color_cursor,
			color_batches,
		]
	)
	_set_state_value(
		"maintenance_timeout",
		"%d seconds | no automatic merge" % int(
			_selected_profile.get("hand_maintenance_timeout_seconds", 0)
		)
	)
	_set_state_value(
		"victory_pending_tail",
		"Remaining macro-round windows: %d" % macro_round_windows
	)
	profile_status.text = "%s | %dP | detached reference" % [
		profile_id,
		_selected_player_count,
	]
	footer_status.text = (
		"Frozen target | deterministic simulation does not prove human fun | "
		+ "no production connection"
	)


func _set_state_value(state_id: String, value: String) -> void:
	var label := _state_value_labels.get(state_id) as Label
	if label != null:
		label.text = value


func _refresh_columns() -> void:
	var width := size.x
	track_grid.columns = 5 if width >= 1560.0 else (3 if width >= 1040.0 else 1)
	asset_grid.columns = 6 if width >= 1320.0 else (3 if width >= 720.0 else 2)
	state_grid.columns = 3 if width >= 1500.0 else (2 if width >= 920.0 else 1)


func _apply_static_styles() -> void:
	for panel in get_tree().get_nodes_in_group("v071_review_section"):
		var section := panel as PanelContainer
		if section != null:
			section.add_theme_stylebox_override(
				"panel",
				_style_for_key("ui.panel.primary", Color("#617184"), Color("#19222e"))
			)
	var display_font := _resolved_assets.get("font.display") as Font
	var body_font := _resolved_assets.get("font.body.zh") as Font
	if display_font != null:
		%Title.add_theme_font_override("font", display_font)
	if body_font != null:
		for label in find_children("*", "Label", true, false):
			(label as Label).add_theme_font_override("font", body_font)
	if display_font != null:
		%Title.add_theme_font_override("font", display_font)


func _resource_for_asset_key(asset_key: String) -> Resource:
	var path := str(_catalog_resource_paths.get(asset_key, ""))
	if path.is_empty() or not _import_artifact_ready(path):
		return null
	return load(path) as Resource


func _packed_string_array(source: String, assignment: String) -> Array[String]:
	var prefix := "%s = PackedStringArray(" % assignment
	var start := source.find(prefix)
	if start < 0:
		return []
	start += prefix.length()
	var finish := source.find(")", start)
	if finish < start:
		return []
	var parsed: Variant = JSON.parse_string("[%s]" % source.substr(
		start,
		finish - start
	))
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
	var expression := source.substr(start, finish - start)
	var matcher := RegEx.new()
	if matcher.compile("ExtResource\\(\"([^\"]+)\"\\)") != OK:
		return []
	var result: Array[String] = []
	for match_result in matcher.search_all(expression):
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


func _texture_for_key(asset_key: String) -> Texture2D:
	return _resolved_assets.get(asset_key) as Texture2D


func _style_for_key(
	asset_key: String,
	accent: Color,
	fill: Color
) -> StyleBox:
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


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
