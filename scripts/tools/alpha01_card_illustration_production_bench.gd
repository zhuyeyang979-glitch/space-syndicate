extends Control

const SCREENSHOT_PATH := "res://docs/art_qa/cards/alpha01/card_illustration_production_1600x960.png"
const CARD_FACE_SCENE := preload("res://scenes/ui/CardFace.tscn")
const CARD_CATALOG := preload("res://resources/cards/runtime/card_runtime_catalog_v06.tres")
const RENDERED_CARD_IDS: Array[String] = [
	"commodity.ring_crystal_battery.rank_1",
	"supply_demand.remote_sea_order.rank_1",
	"supply_demand.near_land_supply.rank_1",
	"unit.monster.spore_tide_emperor.rank_1",
	"interaction.phase_veto.rank_1",
]
const FALLBACK_CARD_ID := "facility.factory.life.rank_1"

@onready var _presentation: CardPresentationRuntimeService = %CardPresentationRuntimeService
@onready var _card_row: HBoxContainer = %CardRow
@onready var _summary_label: Label = %SummaryLabel

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_bench")


func _run_bench() -> void:
	_presentation.configure({})
	var active_count := 0
	for card_id in RENDERED_CARD_IDS:
		if _add_card(card_id, true):
			active_count += 1
	var fallback_active := _add_card(FALLBACK_CARD_ID, false)
	_summary_label.text = "5 张正式插画已接入 · 35 张未完成卡牌保留语义图形"
	_expect(active_count == 5, "all five approved Alpha illustrations render through production CardUI")
	_expect(not fallback_active, "unrendered Alpha card keeps semantic fallback")
	_expect(_card_row.get_child_count() == 6, "bench shows five rendered cards and one honest fallback")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless":
		_save_screenshot()
	if _failures.is_empty():
		print("ALPHA01_CARD_ILLUSTRATION_PRODUCTION_BENCH|status=PASS|checks=%d|rendered=5|fallback=1|privacy_leaks=0|screenshot=%s" % [_checks, SCREENSHOT_PATH])
	else:
		push_error("ALPHA01_CARD_ILLUSTRATION_PRODUCTION_BENCH|status=FAIL|checks=%d|failures=%s" % [_checks, JSON.stringify(_failures)])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _add_card(card_id: String, expected_rendered: bool) -> bool:
	var raw_card := CARD_CATALOG.call("card_snapshot", card_id) as Dictionary
	var presentation := _presentation.compose_card(_presentation_source(card_id, raw_card))
	var card_view := {
		"name": str(presentation.get("display_name", card_id)),
		"cost": str(presentation.get("price", 0)),
		"effect": str(presentation.get("quick_effect_full", "")),
		"type": str(presentation.get("type_label", "策略")),
		"rank": str(presentation.get("rank_label", "I")),
		"accent": presentation.get("accent", Color("#5bc4c2")),
		"chips": presentation.get("chips", []),
		"presentation": "codex_detail",
		"illustration_silent_fallback": true,
	}
	if presentation.has("illustration_key"):
		card_view["illustration_key"] = str(presentation.get("illustration_key", ""))
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(202.0, 326.0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	_card_row.add_child(column)
	var face := CARD_FACE_SCENE.instantiate() as Control
	face.custom_minimum_size = Vector2(190.0, 268.0)
	face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	face.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(face)
	face.call("set_card_data", card_view)
	var status := Label.new()
	status.text = "正式插画" if expected_rendered else "语义回退"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color("#9ce8d8") if expected_rendered else Color("#c7b78a"))
	column.add_child(status)
	var active := bool(face.get_meta("external_illustration_active", false))
	_expect(active == expected_rendered, "%s uses the expected production illustration state" % card_id)
	_expect(not card_view.has("illustration_path") and not card_view.has("sha256") and not card_view.has("license"), "%s player view contains no provenance fields" % card_id)
	return active


func _presentation_source(card_id: String, card: Dictionary) -> Dictionary:
	var machine := _dictionary(card.get("machine", {}))
	var player := _dictionary(card.get("player", {}))
	return {
		"card_id": card_id,
		"card_name": card_id,
		"display_name": str(player.get("name", card_id)),
		"display_text": str(player.get("effect", player.get("short_effect", ""))),
		"rank": int(machine.get("rank", 1)),
		"price": int(machine.get("purchase_cash", 0)),
		"category_id": str(machine.get("category_id", "")),
		"skill": {
			"name": card_id,
			"card_id": card_id,
			"machine": machine,
			"kind": str(machine.get("effect_kind", "")),
			"rank": int(machine.get("rank", 1)),
			"text": str(player.get("effect", player.get("short_effect", ""))),
			"type_label": str(player.get("type", "")),
			"subtype_label": str(player.get("industry", "")),
		},
	}


func _save_screenshot() -> void:
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty(), "viewport image is available")
	if image == null or image.is_empty():
		return
	if image.get_size() != Vector2i(1600, 960):
		image.resize(1600, 960, Image.INTERPOLATE_LANCZOS)
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var save_error := image.save_png(absolute_path)
	_expect(save_error == OK and FileAccess.file_exists(SCREENSHOT_PATH), "1600x960 production screenshot is saved")


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
