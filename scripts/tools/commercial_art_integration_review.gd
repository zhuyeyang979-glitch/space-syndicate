@tool
extends Control
class_name CommercialArtIntegrationReview

const ASSET_BADGE_SCRIPT := preload("res://scripts/tools/commercial_art_review_asset_badge.gd")
const PLANET_REVIEW_SCENE := preload("res://scenes/tools/commercial_art/components/planet/CommercialPlanetReviewComponent.tscn")
const CATALOG_RESOURCE_PATH := "res://resources/presentation/alpha01_card_illustration_catalog.tres"
const CREDITS_DATA_PATH := "res://docs/third_party/credits_data.json"
const HOVER_SCALE := 1.08
const HOVER_LIFT_PIXELS := 28.0
const HOVER_DURATION_SECONDS := 0.120
const DRAG_DEADZONE_PIXELS := 8.0
const DRAG_LIFT_DURATION_SECONDS := 0.110
const DRAG_MAX_TILT_DEGREES := 4.0

const SIX_COLOR_SPECS: Array[Dictionary] = [
	{"id":"life", "name":"Life", "key":"icon.asset.life", "color":"#59c878", "shape":"circle_with_leaf_notch", "letter":"L"},
	{"id":"energy", "name":"Energy", "key":"icon.asset.energy", "color":"#ff9f43", "shape":"diamond", "letter":"E"},
	{"id":"industry", "name":"Industry", "key":"icon.asset.industry", "color":"#98a3b3", "shape":"hexagon", "letter":"I"},
	{"id":"technology", "name":"Technology", "key":"icon.asset.technology", "color":"#4ea1ff", "shape":"clipped_square", "letter":"T"},
	{"id":"commerce", "name":"Commerce", "key":"icon.asset.commerce", "color":"#b66cff", "shape":"octagon", "letter":"C"},
	{"id":"shipping", "name":"Shipping", "key":"icon.asset.shipping", "color":"#35d0c5", "shape":"horizontal_capsule_with_chevrons", "letter":"S"},
]
const CARD_SPECS: Array[Dictionary] = [
	{"id":"normal", "name":"Normal card", "key":"card.frame.normal", "art_card_id":"supply_demand.remote_sea_order.rank_1", "accent":"#4ea1ff", "subtitle":"Level II | asset cost"},
	{"id":"commodity", "name":"Commodity card", "key":"card.frame.commodity", "art_card_id":"commodity.ring_crystal_battery.rank_1", "accent":"#d8e5f0", "subtitle":"Level III | direct claim"},
	{"id":"bound_action", "name":"Bound action", "key":"card.frame.bound_action", "art_card_id":"unit.monster.spore_tide_emperor.rank_1", "accent":"#35d0c5", "subtitle":"Does not occupy normal hand"},
	{"id":"card_back", "name":"Normal card back", "key":"card.back.normal", "art_card_id":"", "accent":"#617184", "subtitle":"Geometric pattern | no vendor logo"},
]
const INTERACTION_SPECS: Array[Dictionary] = [
	{"id":"hover", "name":"Hover", "detail":"1.08 scale | 28 px lift | 120 ms", "accent":"#4ea1ff"},
	{"id":"selected", "name":"Selected", "detail":"2 px outline", "accent":"#d8e5f0"},
	{"id":"drag", "name":"Drag", "detail":"8 px deadzone | 4 deg max", "accent":"#35d0c5"},
	{"id":"legal_target", "name":"Legal target", "detail":"3 px glow", "accent":"#59c878"},
	{"id":"locked", "name":"Locked", "detail":"Immutable presentation state", "accent":"#98a3b3"},
	{"id":"insufficient", "name":"Insufficient", "detail":"Readable cost warning", "accent":"#ff9f43"},
]
const MODEL_GROUPS: Array[Dictionary] = [
	{"id":"facility", "title":"Facilities", "host":"FacilityGrid", "keys":[
		"model.facility.factory.base", "model.facility.market.base",
		"model.facility.warehouse.base", "model.facility.starport.base"]},
	{"id":"monster", "title":"Monsters", "host":"MonsterGrid", "keys":[
		"model.monster.life", "model.monster.energy", "model.monster.industry",
		"model.monster.technology", "model.monster.commerce", "model.monster.shipping"]},
	{"id":"military", "title":"Military tiers", "host":"MilitaryGrid", "keys":[
		"model.military.tier1", "model.military.tier2",
		"model.military.tier3", "model.military.tier4"]},
	{"id":"shipping", "title":"Shipping models", "host":"ShippingGrid", "keys":[
		"model.shipping.route_marker", "model.shipping.convoy",
		"model.shipping.starport_showcase"]},
]
const FONT_SPECS: Array[Dictionary] = [
	{"key":"font.body.zh", "sample":"Space Syndicate | SC body | 123456", "role":"Chinese body default"},
	{"key":"font.body.ja", "sample":"Space Syndicate | JP body | 123456", "role":"Japanese locale body"},
	{"key":"font.display", "sample":"GDP 12,480 | ASSET 6/6 | 45%", "role":"Latin display and numbers"},
]
const AUDIO_SPECS: Array[Dictionary] = [
	{"key":"audio.ui.hover", "label":"UI Hover", "bus":"SFX"},
	{"key":"audio.ui.confirm", "label":"UI Confirm", "bus":"SFX"},
	{"key":"audio.card.lock", "label":"Card Lock", "bus":"SFX"},
	{"key":"audio.card.merge", "label":"Card Merge", "bus":"SFX"},
	{"key":"audio.asset.refresh", "label":"Asset Refresh", "bus":"SFX"},
]
const MUSIC_SPECS: Array[Dictionary] = [
	{"key":"music.menu", "label":"Menu"},
	{"key":"music.gameplay", "label":"Gameplay"},
	{"key":"music.crisis", "label":"Crisis"},
	{"key":"music.military", "label":"Military"},
]
const UI_ASSET_KEYS: Array[String] = [
	"ui.panel.primary", "ui.panel.popup", "ui.button.primary",
]
const CREDIT_SECTION_SPECS: Array[Dictionary] = [
	{"id":"third_party_assets", "title":"Third-Party Assets"},
	{"id":"licenses", "title":"Licenses"},
	{"id":"music", "title":"Music"},
	{"id":"fonts", "title":"Fonts"},
]

@onready var review_status_label: Label = %ReviewStatusLabel
@onready var catalog_status_label: Label = %CatalogStatusLabel
@onready var missing_asset_label: Label = %MissingAssetLabel
@onready var six_color_grid: GridContainer = %SixColorGrid
@onready var card_frame_grid: GridContainer = %CardFrameGrid
@onready var interaction_grid: GridContainer = %InteractionGrid
@onready var facility_grid: GridContainer = %FacilityGrid
@onready var monster_grid: GridContainer = %MonsterGrid
@onready var military_grid: GridContainer = %MilitaryGrid
@onready var shipping_grid: GridContainer = %ShippingGrid
@onready var typography_grid: GridContainer = %TypographyGrid
@onready var audio_grid: GridContainer = %AudioGrid
@onready var audio_status_label: Label = %AudioStatusLabel
@onready var credits_grid: GridContainer = %CreditsGrid
@onready var planet_review_component: Control = %PlanetReviewComponent
@onready var sfx_preview_player: AudioStreamPlayer = %SfxPreviewPlayer
@onready var music_preview_player: AudioStreamPlayer = %MusicPreviewPlayer
@onready var review_scroll: ScrollContainer = $SafeMargin/ReviewRows/ReviewScroll
@onready var sections: VBoxContainer = $SafeMargin/ReviewRows/ReviewScroll/Sections
@onready var overview_surface: PanelContainer = %OverviewSurface

var _catalog: Resource
var _resolved_resources: Dictionary = {}
var _missing_asset_keys: Array[String] = []
var _asset_tiles: Dictionary = {}
var _interaction_tiles: Dictionary = {}
var _interaction_demo: Control
var _interaction_tween: Tween
var _drag_pressed := false
var _drag_origin := Vector2.ZERO
var _active_interaction_state := "idle"
var _build_count := 0
var _audio_preview_count := 0
var _instantiated_model_preview_count := 0
var _capture_focus_id := ""
var _credits_placeholder_count := 0
var _credits_entry_count := 0
var _credits_data_ready := false
var _overview_grid: GridContainer


func _ready() -> void:
	set_meta("commercial_art_review", true)
	set_meta("presentation_only", true)
	_catalog = load(CATALOG_RESOURCE_PATH) as Resource
	_build_review()

func refresh_catalog_bindings() -> void:
	_catalog = load(CATALOG_RESOURCE_PATH) as Resource
	_build_review()


func required_asset_keys() -> Array[String]:
	var result: Array[String] = []
	result.append_array(UI_ASSET_KEYS)
	for spec in SIX_COLOR_SPECS:
		result.append(str(spec.get("key", "")))
	for spec in CARD_SPECS:
		result.append(str(spec.get("key", "")))
	for group in MODEL_GROUPS:
		for key_variant in group.get("keys", []) as Array:
			result.append(str(key_variant))
	for spec in AUDIO_SPECS:
		result.append(str(spec.get("key", "")))
	for spec in MUSIC_SPECS:
		result.append(str(spec.get("key", "")))
	for spec in FONT_SPECS:
		result.append(str(spec.get("key", "")))
	return result


func set_interaction_preview_state(state: String) -> bool:
	if state not in ["idle", "hover", "selected", "drag", "legal_target", "locked", "insufficient"]:
		return false
	_active_interaction_state = state
	if _interaction_demo == null:
		return false
	if _interaction_tween != null and _interaction_tween.is_valid():
		_interaction_tween.kill()
	var target_scale := Vector2.ONE
	var target_rotation := 0.0
	var target_position := Vector2.ZERO
	var duration := HOVER_DURATION_SECONDS
	match state:
		"hover":
			target_scale = Vector2.ONE * HOVER_SCALE
			target_position = Vector2(0.0, -HOVER_LIFT_PIXELS)
		"drag":
			target_scale = Vector2.ONE * 1.05
			target_position = Vector2(0.0, -18.0)
			target_rotation = deg_to_rad(DRAG_MAX_TILT_DEGREES)
			duration = DRAG_LIFT_DURATION_SECONDS
		"selected":
			target_scale = Vector2.ONE * 1.03
		"legal_target":
			target_scale = Vector2.ONE * 1.02
		"locked", "insufficient":
			target_scale = Vector2.ONE * 0.98
	_interaction_demo.set_meta("preview_state", state)
	_interaction_tween = create_tween().set_parallel(true)
	_interaction_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_interaction_tween.tween_property(_interaction_demo, "scale", target_scale, duration)
	_interaction_tween.tween_property(_interaction_demo, "rotation", target_rotation, duration)
	_interaction_tween.tween_property(_interaction_demo, "position", target_position, duration)
	return true


func preview_audio_asset(asset_key: String) -> bool:
	if not _resolved_resources.has(asset_key):
		audio_status_label.text = "MISSING_CATALOG_BINDING | %s" % asset_key
		return false
	var resource := _resolved_resources[asset_key] as Resource
	if not (resource is AudioStream):
		audio_status_label.text = "WRONG_RESOURCE_TYPE | %s" % asset_key
		return false
	if asset_key.begins_with("music."):
		music_preview_player.stream = resource as AudioStream
		music_preview_player.play()
	else:
		sfx_preview_player.stream = resource as AudioStream
		sfx_preview_player.play()
	_audio_preview_count += 1
	audio_status_label.text = "PREVIEWING | %s" % asset_key
	return true


func set_preview_volume(linear_value: float) -> void:
	var value := clampf(linear_value, 0.0, 1.0)
	var db := linear_to_db(value) if value > 0.0 else -80.0
	sfx_preview_player.volume_db = db
	music_preview_player.volume_db = db


func prepare_capture_state(capture_id: String) -> bool:
	var target: Control
	var asset_key := ""
	var interaction_state := "idle"
	var planet_mode := ""
	var entity_mode := ""
	_reset_capture_layout()
	match capture_id:
		"full_table_1920", "full_table_1366":
			target = sections
		"six_color_assets":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/SixColorSection") as Control
		"normal_cards":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/CardSection") as Control
			asset_key = "card.frame.normal"
		"commodity_cards":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/CardSection") as Control
			asset_key = "card.frame.commodity"
		"bound_actions":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/CardSection") as Control
			asset_key = "card.frame.bound_action"
		"hand_hover":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/InteractionSection") as Control
			interaction_state = "hover"
		"hand_drag":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/InteractionSection") as Control
			interaction_state = "drag"
		"planet_day":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/PlanetSection") as Control
			planet_mode = "day"
		"planet_night":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/PlanetSection") as Control
			planet_mode = "night"
		"planet_zoom":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/PlanetSection") as Control
			planet_mode = "zoom"
		"facilities":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/EntitySection") as Control
			entity_mode = "facilities"
		"monsters":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/EntitySection") as Control
			entity_mode = "monsters"
		"military":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/EntitySection") as Control
			entity_mode = "military_shipping"
		"credits":
			target = get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/CreditsSection") as Control
		_:
			return false
	_capture_focus_id = capture_id
	_reset_capture_highlights()
	if not asset_key.is_empty():
		_highlight_asset_key(asset_key)
	set_interaction_preview_state(interaction_state)
	if not planet_mode.is_empty():
		_prepare_planet_capture_mode(planet_mode)
	if not entity_mode.is_empty():
		_prepare_entity_capture_mode(entity_mode)
	if capture_id.begins_with("full_table_"):
		_prepare_overview_capture()
	else:
		_scroll_capture_target_into_view(target)
		call_deferred("_scroll_capture_target_into_view", target)
	review_status_label.text = "CAPTURE FOCUS | %s | REFERENCE ONLY" % capture_id.to_upper()
	return target != null


func finalize_capture_layout(capture_id: String) -> void:
	if review_scroll == null or capture_id != "credits":
		return
	review_scroll.scroll_vertical = 1_000_000


func debug_snapshot() -> Dictionary:
	var planet_snapshot: Dictionary = {}
	if planet_review_component != null and planet_review_component.has_method("debug_snapshot"):
		var value: Variant = planet_review_component.call("debug_snapshot")
		planet_snapshot = value if value is Dictionary else {}
	return {
		"review_id": "commercial_art.integration.review.v1",
		"presentation_only": true,
		"catalog_resource_path": CATALOG_RESOURCE_PATH,
		"catalog_loaded": _catalog != null,
		"catalog_generic_api_ready": _catalog != null and _catalog.has_method("resource_for_asset_key"),
		"required_asset_key_count": required_asset_keys().size(),
		"resolved_asset_key_count": _resolved_resources.size(),
		"missing_asset_key_count": _missing_asset_keys.size(),
		"missing_asset_keys": _missing_asset_keys.duplicate(),
		"resolved_resource_type_counts": _resolved_resource_type_counts(),
		"six_color_icon_count": six_color_grid.get_child_count(),
		"card_frame_and_back_count": card_frame_grid.get_child_count(),
		"interaction_state_count": interaction_grid.get_child_count(),
		"facility_slot_count": facility_grid.get_child_count(),
		"monster_slot_count": monster_grid.get_child_count(),
		"military_slot_count": military_grid.get_child_count(),
		"shipping_slot_count": shipping_grid.get_child_count(),
		"instantiated_model_preview_count": _instantiated_model_preview_count,
		"font_sample_count": typography_grid.get_child_count(),
		"audio_control_count": audio_grid.get_child_count(),
		"credits_section_count": credits_grid.get_child_count(),
		"credits_placeholder_count": _credits_placeholder_count,
		"credits_entry_count": _credits_entry_count,
		"credits_data_ready": _credits_data_ready,
		"active_interaction_state": _active_interaction_state,
		"capture_focus_id": _capture_focus_id,
		"audio_preview_count": _audio_preview_count,
		"planet": planet_snapshot,
		"build_count": _build_count,
		"creates_session": false,
		"writes_save": false,
		"rng_draw_count": 0,
		"gameplay_mutation_count": 0,
		"production_connection_count": 0,
		"main_reference_count": 0,
	}


func _build_review() -> void:
	_resolved_resources.clear()
	_missing_asset_keys.clear()
	_asset_tiles.clear()
	_instantiated_model_preview_count = 0
	_clear_children(six_color_grid)
	_clear_children(card_frame_grid)
	_clear_children(interaction_grid)
	_clear_children(facility_grid)
	_clear_children(monster_grid)
	_clear_children(military_grid)
	_clear_children(shipping_grid)
	_clear_children(typography_grid)
	_clear_children(audio_grid)
	_clear_children(credits_grid)
	for key in required_asset_keys():
		var resource := _resolve_catalog_resource(key)
		if resource != null:
			_resolved_resources[key] = resource
		else:
			_missing_asset_keys.append(key)
	_build_six_color_assets()
	_build_card_frames()
	_build_interactions()
	_build_model_groups()
	_build_typography()
	_build_audio_controls()
	_build_credits()
	_build_overview_surface()
	_style_static_surfaces()
	_build_count += 1
	var generic_ready := _catalog != null and _catalog.has_method("resource_for_asset_key")
	review_status_label.text = "REFERENCE PRESENTATION | NO SESSION | NO SAVE | NO RNG"
	catalog_status_label.text = "Catalog: %s" % ("GENERIC API READY" if generic_ready else "LEGACY CARD API ONLY")
	missing_asset_label.text = "Resolved %d / %d | Missing gates %d" % [
		_resolved_resources.size(), required_asset_keys().size(), _missing_asset_keys.size(),
	]


func _build_six_color_assets() -> void:
	for spec in SIX_COLOR_SPECS:
		var key := str(spec.get("key", ""))
		var panel := _tile_panel(Vector2(164.0, 150.0), Color(str(spec.get("color", "#617184"))))
		var rows := _tile_rows(panel)
		var badge := ASSET_BADGE_SCRIPT.new()
		badge.configure(
			key,
			str(spec.get("shape", "circle_with_leaf_notch")),
			Color(str(spec.get("color", "#617184"))),
			_resolved_resources.get(key) as Texture2D,
			str(spec.get("letter", "?"))
		)
		rows.add_child(badge)
		rows.add_child(_label(str(spec.get("name", "Asset")), 14, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
		rows.add_child(_label("Current 4/6 | Reserved 2", 10, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_CENTER))
		rows.add_child(_gate_label(key))
		six_color_grid.add_child(panel)
		_asset_tiles[key] = panel


func _build_overview_surface() -> void:
	_clear_children(overview_surface)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	overview_surface.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)
	rows.add_child(_label(
		"Commercial art foundation | complete presentation overview",
		18,
		Color("#f5f8fb"),
		HORIZONTAL_ALIGNMENT_LEFT
	))
	_overview_grid = GridContainer.new()
	_overview_grid.columns = 3
	_overview_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overview_grid.add_theme_constant_override("h_separation", 10)
	_overview_grid.add_theme_constant_override("v_separation", 10)
	rows.add_child(_overview_grid)
	_overview_grid.add_child(_build_overview_assets_cell())
	_overview_grid.add_child(_build_overview_cards_cell())
	_overview_grid.add_child(_build_overview_planet_cell())
	_overview_grid.add_child(_build_overview_entities_cell())
	_overview_grid.add_child(_build_overview_type_audio_cell())
	_overview_grid.add_child(_build_overview_credits_cell())
	overview_surface.add_theme_stylebox_override(
		"panel",
		_catalog_style_box("ui.panel.primary", _panel_style(Color("#617184"), Color("#19222e"), 1, 6))
	)


func _build_overview_assets_cell() -> Control:
	var cell := _overview_cell("Six-color assets", Color("#59c878"))
	var rows := cell.get_meta("content_rows") as VBoxContainer
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 2)
	for spec in SIX_COLOR_SPECS:
		var item := VBoxContainer.new()
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		var badge := ASSET_BADGE_SCRIPT.new()
		var key := str(spec.get("key", ""))
		badge.configure(
			key,
			str(spec.get("shape", "circle_with_leaf_notch")),
			Color(str(spec.get("color", "#617184"))),
			_resolved_resources.get(key) as Texture2D,
			str(spec.get("letter", "?"))
		)
		item.add_child(badge)
		item.add_child(_label(str(spec.get("name", "")), 10, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_CENTER))
		strip.add_child(item)
	rows.add_child(strip)
	rows.add_child(_label("6/6 icons | 6/6 base shapes | current / reserved", 10, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_CENTER))
	return cell


func _build_overview_cards_cell() -> Control:
	var cell := _overview_cell("Card visual language", Color("#4ea1ff"))
	var rows := cell.get_meta("content_rows") as VBoxContainer
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 10)
	for spec in CARD_SPECS:
		var key := str(spec.get("key", ""))
		var texture := _existing_card_art(str(spec.get("art_card_id", "")))
		if texture == null:
			texture = _resolved_resources.get(key) as Texture2D
		var item := VBoxContainer.new()
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		var view := TextureRect.new()
		view.custom_minimum_size = Vector2(94.0, 104.0)
		view.texture = texture
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.add_child(view)
		item.add_child(_label(str(spec.get("name", "")), 10, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_CENTER))
		strip.add_child(item)
	rows.add_child(strip)
	rows.add_child(_label("Normal | Commodity | Bound action | Pattern back", 10, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_CENTER))
	return cell


func _build_overview_planet_cell() -> Control:
	var cell := _overview_cell("Opaque planet", Color("#35d0c5"))
	var rows := cell.get_meta("content_rows") as VBoxContainer
	var planet := PLANET_REVIEW_SCENE.instantiate() as Control
	planet.custom_minimum_size = Vector2(420.0, 190.0)
	planet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(planet)
	rows.add_child(_label("Day / night | backside occlusion | zoom 0.72-1.85", 10, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_CENTER))
	return cell


func _build_overview_entities_cell() -> Control:
	var cell := _overview_cell("Map entities", Color("#ff9f43"))
	var rows := cell.get_meta("content_rows") as VBoxContainer
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for key in [
		"model.facility.factory.base",
		"model.monster.life",
		"model.military.tier4",
		"model.shipping.convoy",
	]:
		var item := VBoxContainer.new()
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		var resource := _resolved_resources.get(key) as PackedScene
		if resource != null:
			item.add_child(_packed_scene_preview(resource, key, Vector2(190.0, 92.0)))
		item.add_child(_label(_model_display_label(key), 10, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(item)
	rows.add_child(grid)
	rows.add_child(_label("4 facilities | 6 monsters | 4 mechs | 3 ships", 10, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_CENTER))
	return cell


func _build_overview_type_audio_cell() -> Control:
	var cell := _overview_cell("Typography and audio", Color("#98a3b3"))
	var rows := cell.get_meta("content_rows") as VBoxContainer
	var display := _label("GDP 12,480 | ASSET 6/6 | 45%", 19, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER)
	var display_font := _resolved_resources.get("font.display") as Font
	if display_font != null:
		display.add_theme_font_override("font", display_font)
	rows.add_child(display)
	rows.add_child(_label("Noto Sans CJK SC / JP | Oxanium display", 12, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_CENTER))
	rows.add_child(_label("17 fixed SFX events | 4 music states | 1.5 s crossfade", 11, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_CENTER))
	rows.add_child(_label("Local resources only | presentation state only", 10, Color("#59c878"), HORIZONTAL_ALIGNMENT_CENTER))
	return cell


func _build_overview_credits_cell() -> Control:
	var cell := _overview_cell("Credits and licenses", Color("#b66cff"))
	var rows := cell.get_meta("content_rows") as VBoxContainer
	rows.add_child(_label("30 fixed official sources | notices packaged", 12, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_CENTER))
	rows.add_child(_label("CC0 21 | CC BY 3.0 6 | MIT 1 | OFL 2", 11, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
	rows.add_child(_label("Game-icons: Lorc and Delapouite | game-icons.net", 10, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_CENTER))
	rows.add_child(_label("Attribution, Music, Fonts, Third-Party Assets", 10, Color("#59c878"), HORIZONTAL_ALIGNMENT_CENTER))
	return cell


func _overview_cell(title: String, accent: Color) -> PanelContainer:
	var panel := _tile_panel(Vector2.ZERO, accent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows := _tile_rows(panel)
	rows.add_child(_label(title, 15, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
	panel.set_meta("content_rows", rows)
	return panel


func _build_card_frames() -> void:
	for spec in CARD_SPECS:
		var key := str(spec.get("key", ""))
		var accent := Color(str(spec.get("accent", "#617184")))
		var panel := _tile_panel(Vector2(196.0, 250.0), accent)
		var rows := _tile_rows(panel)
		rows.add_child(_label(str(spec.get("name", "Card")), 15, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
		var frame_resource := _resolved_resources.get(key) as Texture2D
		if frame_resource != null:
			var frame := NinePatchRect.new()
			frame.custom_minimum_size = Vector2(152.0, 52.0)
			frame.texture = frame_resource
			frame.set_patch_margin(SIDE_LEFT, 14)
			frame.set_patch_margin(SIDE_TOP, 14)
			frame.set_patch_margin(SIDE_RIGHT, 14)
			frame.set_patch_margin(SIDE_BOTTOM, 14)
			rows.add_child(frame)
		var art := _existing_card_art(str(spec.get("art_card_id", "")))
		if art != null:
			var art_view := TextureRect.new()
			art_view.custom_minimum_size = Vector2(152.0, 112.0)
			art_view.texture = art
			art_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			rows.add_child(art_view)
		elif key == "card.back.normal" and frame_resource != null:
			var back_view := TextureRect.new()
			back_view.custom_minimum_size = Vector2(152.0, 112.0)
			back_view.texture = frame_resource
			back_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			back_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			back_view.tooltip_text = "Vendor-neutral geometric card back"
			rows.add_child(back_view)
		else:
			var art_gate := _label("CATALOG ART UNAVAILABLE", 11, accent.lightened(0.18), HORIZONTAL_ALIGNMENT_CENTER)
			art_gate.custom_minimum_size = Vector2(152.0, 112.0)
			art_gate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			rows.add_child(art_gate)
		rows.add_child(_label(str(spec.get("subtitle", "")), 11, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_CENTER))
		rows.add_child(_gate_label(key))
		card_frame_grid.add_child(panel)
		_asset_tiles[key] = panel


func _build_interactions() -> void:
	for spec in INTERACTION_SPECS:
		var state := str(spec.get("id", "idle"))
		var accent := Color(str(spec.get("accent", "#617184")))
		var panel := _tile_panel(Vector2(144.0, 126.0), accent, 2 if state == "selected" else (3 if state == "legal_target" else 1))
		var rows := _tile_rows(panel)
		rows.add_child(_label(str(spec.get("name", "State")), 14, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
		rows.add_child(_label(str(spec.get("detail", "")), 10, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_CENTER))
		rows.add_child(_label("PRESENTATION ONLY", 9, accent.lightened(0.15), HORIZONTAL_ALIGNMENT_CENTER))
		panel.set_meta("interaction_state", state)
		panel.pivot_offset = Vector2(72.0, 63.0)
		interaction_grid.add_child(panel)
		_interaction_tiles[state] = panel
	if _interaction_tiles.has("hover"):
		_interaction_demo = _interaction_tiles["hover"] as Control
		_interaction_demo.mouse_filter = Control.MOUSE_FILTER_STOP
		_interaction_demo.mouse_entered.connect(set_interaction_preview_state.bind("hover"))
		_interaction_demo.mouse_exited.connect(set_interaction_preview_state.bind("idle"))
		_interaction_demo.gui_input.connect(_on_interaction_demo_gui_input)


func _build_model_groups() -> void:
	for group in MODEL_GROUPS:
		var group_id := str(group.get("id", ""))
		var host := get_node_or_null("%%%s" % str(group.get("host", ""))) as GridContainer
		if host == null:
			continue
		var tile_size := _model_tile_size(group_id)
		var preview_size := Vector2(tile_size.x - 20.0, tile_size.y - 64.0)
		for key_variant in group.get("keys", []) as Array:
			var key := str(key_variant)
			var resource := _resolved_resources.get(key) as Resource
			var panel := _tile_panel(tile_size, _model_accent(key))
			var rows := _tile_rows(panel)
			rows.add_child(_label(_model_display_label(key), 13, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
			if resource is PackedScene:
				rows.add_child(_packed_scene_preview(resource as PackedScene, key, preview_size))
				_instantiated_model_preview_count += 1
			else:
				var preview_slot := _label("MODEL PREVIEW SLOT", 10, _model_accent(key).lightened(0.16), HORIZONTAL_ALIGNMENT_CENTER)
				preview_slot.custom_minimum_size = Vector2(128.0, 48.0)
				preview_slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				rows.add_child(preview_slot)
			rows.add_child(_gate_label(key))
			host.add_child(panel)
			_asset_tiles[key] = panel


func _build_typography() -> void:
	for spec in FONT_SPECS:
		var key := str(spec.get("key", ""))
		var panel := _tile_panel(Vector2(282.0, 96.0), Color("#617184"))
		var rows := _tile_rows(panel)
		var sample := _label(str(spec.get("sample", "")), 18, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_LEFT)
		var resource := _resolved_resources.get(key) as Resource
		if resource is Font:
			sample.add_theme_font_override("font", resource as Font)
		rows.add_child(sample)
		rows.add_child(_label(str(spec.get("role", "")), 10, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_LEFT))
		rows.add_child(_gate_label(key, HORIZONTAL_ALIGNMENT_LEFT))
		typography_grid.add_child(panel)
		_asset_tiles[key] = panel


func _build_audio_controls() -> void:
	for spec in AUDIO_SPECS:
		_add_audio_button(str(spec.get("key", "")), str(spec.get("label", "SFX")), false)
	for spec in MUSIC_SPECS:
		_add_audio_button(str(spec.get("key", "")), str(spec.get("label", "Music")), true)
	var volume_panel := _tile_panel(Vector2(220.0, 78.0), Color("#617184"))
	var rows := _tile_rows(volume_panel)
	rows.add_child(_label("Preview volume", 12, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_LEFT))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 0.7
	slider.value_changed.connect(set_preview_volume)
	rows.add_child(slider)
	audio_grid.add_child(volume_panel)
	audio_status_label.text = "Audio preview idle | catalog resources only"


func _build_credits() -> void:
	_credits_placeholder_count = 0
	_credits_entry_count = 0
	_credits_data_ready = false
	var data := _load_json_dictionary(CREDITS_DATA_PATH)
	var sections: Dictionary = data.get("sections", {}) as Dictionary \
		if data.get("sections", {}) is Dictionary else {}
	var all_sections_ready := sections.size() == CREDIT_SECTION_SPECS.size()
	for spec in CREDIT_SECTION_SPECS:
		var entries: Variant = sections.get(str(spec.get("id", "")))
		if not (entries is Array) or (entries as Array).is_empty():
			all_sections_ready = false
	var attribution := str(data.get("game_icons_attribution", "")).to_lower()
	_credits_data_ready = all_sections_ready \
		and attribution.contains("game-icons.net") \
		and attribution.contains("cc by 3.0")
	if not _credits_data_ready:
		_build_credits_placeholders()
		return
	for spec in CREDIT_SECTION_SPECS:
		var section_id := str(spec.get("id", ""))
		var entries := sections.get(section_id, []) as Array
		var panel := _tile_panel(Vector2(248.0, 148.0), Color("#617184"))
		var rows := _tile_rows(panel)
		rows.add_child(_label(str(spec.get("title", section_id)), 13, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
		for index in range(mini(entries.size(), 3)):
			var entry: Dictionary = entries[index] as Dictionary if entries[index] is Dictionary else {}
			var title := str(entry.get("title", entry.get("asset_id", "Credit entry")))
			var detail := str(entry.get("detail", entry.get("attribution", entry.get("license", ""))))
			rows.add_child(_label(title, 10, Color("#d8e5f0"), HORIZONTAL_ALIGNMENT_LEFT))
			if not detail.is_empty():
				rows.add_child(_label(detail.left(96), 8, Color("#9fb0c2"), HORIZONTAL_ALIGNMENT_LEFT))
		if entries.size() > 3:
			rows.add_child(_label("+ %d more canonical entries" % (entries.size() - 3), 8, Color("#59c878"), HORIZONTAL_ALIGNMENT_LEFT))
		credits_grid.add_child(panel)
		_credits_entry_count += entries.size()


func _build_credits_placeholders() -> void:
	for spec in CREDIT_SECTION_SPECS:
		var panel := _tile_panel(Vector2(208.0, 86.0), Color("#617184"))
		var rows := _tile_rows(panel)
		rows.add_child(_label(str(spec.get("title", "Credits")), 13, Color("#f5f8fb"), HORIZONTAL_ALIGNMENT_CENTER))
		rows.add_child(_label("PLACEHOLDER | canonical credits data not ready", 9, Color("#b8c7d6"), HORIZONTAL_ALIGNMENT_CENTER))
		credits_grid.add_child(panel)
		_credits_placeholder_count += 1


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _add_audio_button(key: String, label_text: String, music: bool) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(164.0, 44.0)
	button.text = "%s | %s" % ["MUSIC" if music else "SFX", label_text]
	button.tooltip_text = key
	button.pressed.connect(preview_audio_asset.bind(key))
	button.set_meta("asset_key", key)
	button.set_meta("catalog_binding_ready", _resolved_resources.has(key))
	audio_grid.add_child(button)


func _resolve_catalog_resource(asset_key: String) -> Resource:
	if _catalog == null or asset_key.is_empty():
		return null
	var resolved: Variant = null
	if _catalog.has_method("resource_for_asset_key"):
		resolved = _catalog.call("resource_for_asset_key", StringName(asset_key))
	elif _catalog.has_method("texture_for_key"):
		resolved = _catalog.call("texture_for_key", StringName(asset_key))
	return resolved as Resource if resolved is Resource else null


func _existing_card_art(card_id: String) -> Texture2D:
	if _catalog == null or card_id.is_empty() \
			or not _catalog.has_method("presentation_key_for_card") \
			or not _catalog.has_method("texture_for_key"):
		return null
	var key_variant: Variant = _catalog.call("presentation_key_for_card", card_id)
	var key := StringName(str(key_variant))
	if key == StringName():
		return null
	var texture_variant: Variant = _catalog.call("texture_for_key", key)
	return texture_variant as Texture2D if texture_variant is Texture2D else null


func _on_interaction_demo_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		_drag_pressed = mouse.pressed
		_drag_origin = mouse.position
		if not mouse.pressed:
			set_interaction_preview_state("idle")
		accept_event()
	elif event is InputEventMouseMotion and _drag_pressed:
		var motion := event as InputEventMouseMotion
		if motion.position.distance_to(_drag_origin) >= DRAG_DEADZONE_PIXELS:
			set_interaction_preview_state("drag")
		accept_event()


func _resolved_resource_type_counts() -> Dictionary:
	var counts := {
		"Texture2D": 0,
		"PackedScene": 0,
		"AudioStream": 0,
		"Font": 0,
		"other": 0,
	}
	for resource_variant in _resolved_resources.values():
		var resource := resource_variant as Resource
		if resource is Texture2D:
			counts["Texture2D"] += 1
		elif resource is PackedScene:
			counts["PackedScene"] += 1
		elif resource is AudioStream:
			counts["AudioStream"] += 1
		elif resource is Font:
			counts["Font"] += 1
		else:
			counts["other"] += 1
	return counts


func _reset_capture_highlights() -> void:
	for tile_variant in _asset_tiles.values():
		var tile := tile_variant as Control
		if tile != null:
			tile.modulate = Color.WHITE
			tile.scale = Vector2.ONE
	for tile_variant in _interaction_tiles.values():
		var tile := tile_variant as Control
		if tile != null:
			tile.modulate = Color.WHITE


func _highlight_asset_key(asset_key: String) -> void:
	for key_variant in _asset_tiles.keys():
		var tile := _asset_tiles[key_variant] as Control
		if tile == null:
			continue
		tile.modulate = Color.WHITE if str(key_variant) == asset_key else Color(0.52, 0.58, 0.64, 0.68)
		if str(key_variant) == asset_key:
			tile.pivot_offset = tile.size * 0.5
			tile.scale = Vector2.ONE * 1.04


func _scroll_capture_target_into_view(target: Control) -> void:
	if review_scroll == null or sections == null or target == null:
		return
	var relative_y := target.global_position.y - sections.global_position.y
	var maximum := maxi(0, int(sections.get_combined_minimum_size().y - review_scroll.size.y))
	review_scroll.scroll_vertical = clampi(int(relative_y) - 8, 0, maximum)


func _reset_capture_layout() -> void:
	if sections != null:
		sections.scale = Vector2.ONE
		sections.position = Vector2.ZERO
	if review_scroll != null:
		review_scroll.visible = true
		review_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		review_scroll.scroll_vertical = 0
	if overview_surface != null:
		overview_surface.visible = false
	_reset_entity_capture_mode()


func _prepare_overview_capture() -> void:
	if review_scroll == null or overview_surface == null or _overview_grid == null:
		return
	_overview_grid.columns = 3 if size.x >= 1600.0 else 2
	review_scroll.visible = false
	overview_surface.visible = true


func _reset_entity_capture_mode() -> void:
	var entity_section := get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/EntitySection") as Control
	if entity_section != null:
		entity_section.custom_minimum_size = Vector2.ZERO
	for node_name in [
		"FacilityTitle", "FacilityGrid", "MonsterTitle", "MonsterGrid",
		"MilitaryTitle", "MilitaryGrid", "ShippingTitle", "ShippingGrid",
	]:
		var node := get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/EntitySection/Rows/%s" % node_name)
		if node != null:
			node.visible = true


func _prepare_entity_capture_mode(mode: String) -> void:
	var visibility := {
		"FacilityTitle": mode == "facilities",
		"FacilityGrid": mode == "facilities",
		"MonsterTitle": mode == "monsters",
		"MonsterGrid": mode == "monsters",
		"MilitaryTitle": mode == "military_shipping",
		"MilitaryGrid": mode == "military_shipping",
		"ShippingTitle": mode == "military_shipping",
		"ShippingGrid": mode == "military_shipping",
	}
	for node_name in visibility:
		var node := get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/EntitySection/Rows/%s" % node_name)
		if node != null:
			node.visible = bool(visibility[node_name])
	var entity_section := get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/EntitySection") as Control
	if entity_section != null and review_scroll != null:
		entity_section.custom_minimum_size = Vector2(0.0, maxf(620.0, review_scroll.size.y - 12.0))


func _prepare_planet_capture_mode(mode: String) -> void:
	if planet_review_component == null:
		return
	if planet_review_component.has_method("reset_view"):
		planet_review_component.call("reset_view")
	if planet_review_component.has_method("set_zoom_immediate"):
		planet_review_component.call("set_zoom_immediate", 1.0 if mode != "zoom" else 1.72)
	if mode != "night" or not planet_review_component.has_method("_gui_input"):
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(240.0, 210.0)
	planet_review_component.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(760.0, 210.0)
	planet_review_component.call("_gui_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	planet_review_component.call("_gui_input", release)


func _style_static_surfaces() -> void:
	var primary_style := _catalog_style_box(
		"ui.panel.primary",
		_panel_style(Color("#617184"), Color("#19222e"), 1, 6)
	)
	for node in get_tree().get_nodes_in_group("commercial_art_review_section"):
		var panel := node as PanelContainer
		if panel != null:
			panel.add_theme_stylebox_override("panel", primary_style)
	var credits_section := get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections/CreditsSection") as PanelContainer
	if credits_section != null:
		credits_section.add_theme_stylebox_override(
			"panel",
			_catalog_style_box(
				"ui.panel.popup",
				_panel_style(Color("#d8e5f0"), Color("#222f3d"), 1, 6)
			)
		)
	var button_style := _catalog_style_box(
		"ui.button.primary",
		_panel_style(Color("#617184"), Color("#19222e"), 1, 5)
	)
	for child in audio_grid.get_children():
		var button := child as Button
		if button != null:
			button.add_theme_stylebox_override("normal", button_style)
			button.add_theme_stylebox_override("hover", button_style)


func _tile_panel(minimum: Vector2, accent: Color, border_width := 1) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.add_theme_stylebox_override("panel", _panel_style(accent, Color("#111720"), border_width, 5))
	return panel


func _packed_scene_preview(packed: PackedScene, asset_key: String, preview_size: Vector2) -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = preview_size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.tooltip_text = asset_key
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#111720")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d8e5f0")
	environment.ambient_light_energy = 0.52
	environment_node.environment = environment
	viewport.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -32.0, 0.0)
	light.light_energy = 1.15
	viewport.add_child(light)
	var pivot := Node3D.new()
	pivot.name = "StableAssetPreviewRoot"
	pivot.rotation_degrees = Vector3(0.0, -24.0, 0.0)
	pivot.position = Vector3(0.0, -0.65, 0.0)
	viewport.add_child(pivot)
	var instance := packed.instantiate()
	if instance is Node3D:
		pivot.add_child(instance)
		_fit_model_preview(instance as Node3D)
	else:
		instance.queue_free()
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _model_camera_size(asset_key)
	camera.look_at_from_position(
		Vector3(3.1, 2.35, 4.2),
		Vector3.ZERO,
		Vector3.UP
	)
	camera.current = true
	return container


func _fit_model_preview(instance: Node3D) -> void:
	var bounds := AABB()
	var has_bounds := false
	var subject := instance.get_node_or_null("Model") as Node3D
	var search_root := subject if subject != null else instance
	var mesh_nodes: Array[Node] = []
	if search_root is MeshInstance3D:
		mesh_nodes.append(search_root)
	mesh_nodes.append_array(search_root.find_children("*", "MeshInstance3D", true, false))
	for child in mesh_nodes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.get_aabb()
		child_bounds = _relative_transform_3d(instance, mesh_instance) * child_bounds
		bounds = bounds.merge(child_bounds) if has_bounds else child_bounds
		has_bounds = true
	if not has_bounds:
		instance.scale = Vector3.ONE
		return
	var largest_extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest_extent <= 0.0001:
		return
	var fit_scale := 2.25 / largest_extent
	instance.scale = Vector3.ONE * fit_scale
	instance.position = -bounds.get_center() * fit_scale


func _relative_transform_3d(root_node: Node3D, descendant: Node3D) -> Transform3D:
	var chain: Array[Node3D] = []
	var cursor: Node = descendant
	while cursor != null and cursor != root_node:
		if cursor is Node3D:
			chain.push_front(cursor as Node3D)
		cursor = cursor.get_parent()
	var result := Transform3D.IDENTITY
	for node in chain:
		result = result * node.transform
	return result


func _tile_rows(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)
	return rows


func _gate_label(key: String, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var ready := _resolved_resources.has(key)
	var label := _label(
		"CATALOG READY" if ready else "MISSING_CATALOG_BINDING",
		8,
		Color("#59c878") if ready else Color("#ff9f43"),
		alignment
	)
	label.tooltip_text = key
	label.set_meta("asset_key", key)
	label.set_meta("binding_ready", ready)
	return label


func _label(text_value: String, size_value: int, color: Color, alignment: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment as HorizontalAlignment
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _catalog_style_box(asset_key: String, fallback: StyleBox) -> StyleBox:
	var texture := _resolved_resources.get(asset_key) as Texture2D
	if texture == null:
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 16.0)
	return style


func _model_accent(key: String) -> Color:
	if key.contains("monster"):
		return Color("#ff9f43")
	if key.contains("military"):
		return Color("#98a3b3")
	if key.contains("shipping") or key.contains("starport"):
		return Color("#35d0c5")
	if key.contains("market"):
		return Color("#b66cff")
	return Color("#4ea1ff")


func _model_camera_size(key: String) -> float:
	if key.contains("facility"):
		return 3.0
	if key.contains("monster"):
		return 2.45
	if key.contains("military"):
		return 2.45
	if key.contains("shipping"):
		return 2.45
	return 2.4


func _short_key_label(key: String) -> String:
	var parts := key.split(".")
	return str(parts[parts.size() - 1]).capitalize() if not parts.is_empty() else key


func _model_tile_size(group_id: String) -> Vector2:
	match group_id:
		"facility", "military":
			return Vector2(320.0, 270.0)
		"monster":
			return Vector2(280.0, 260.0)
		"shipping":
			return Vector2(400.0, 270.0)
	return Vector2(280.0, 260.0)


func _model_display_label(key: String) -> String:
	const LABELS := {
		"model.facility.factory.base": "Factory",
		"model.facility.market.base": "Market",
		"model.facility.warehouse.base": "Warehouse",
		"model.facility.starport.base": "Starport",
		"model.military.tier1": "Tier 1",
		"model.military.tier2": "Tier 2",
		"model.military.tier3": "Tier 3",
		"model.military.tier4": "Tier 4",
		"model.shipping.route_marker": "Route Marker",
		"model.shipping.convoy": "Convoy",
		"model.shipping.starport_showcase": "Starport Showcase",
	}
	return str(LABELS.get(key, _short_key_label(key)))


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
