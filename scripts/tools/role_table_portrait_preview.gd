@tool
extends Control

const PlayerSeatScene := preload("res://scenes/ui/PlayerSeatPortrait.tscn")
const PlanetSeatLayoutScript := preload("res://scripts/ui/planet_seat_layout.gd")
const RolePortraitCatalogScript := preload("res://scripts/presentation/role_portrait_catalog.gd")

const PREVIEW_ROLES := [
	"环港走私议会",
	"重力矿联董事会",
	"光合修复会",
	"幽幕播报社",
]

const PLAYER_COLORS := [
	Color("#38bdf8"),
	Color("#f97316"),
	Color("#a78bfa"),
	Color("#34d399"),
	Color("#f43f5e"),
	Color("#facc15"),
	Color("#22d3ee"),
	Color("#e879f9"),
]

@export_range(3, 8, 1) var preview_player_count := 4:
	set(value):
		preview_player_count = clampi(value, 3, 8)
		if is_node_ready():
			rebuild_layout()
@export var auto_capture_layouts := false
@export var capture_output_root := "res://docs/art_qa/"

var _catalog
var _seat_nodes: Array[Control] = []

@onready var back_seat_layer: Control = $BackSeatLayer
@onready var front_seat_layer: Control = $FrontSeatLayer
@onready var debug_label: Label = $TopChrome/ChromeMargin/ChromeRows/DebugLabel


func _ready() -> void:
	_catalog = RolePortraitCatalogScript.new()
	_connect_controls()
	rebuild_layout()
	if not Engine.is_editor_hint():
		if auto_capture_layouts:
			$TopChrome.visible = false
			$LayoutControls.visible = false
		print("ROLE_TABLE_PREVIEW_READY ", JSON.stringify(debug_snapshot()))
		if auto_capture_layouts:
			call_deferred("capture_required_layouts")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("rebuild_layout")


func set_player_count(value: int) -> void:
	preview_player_count = clampi(value, 3, 8)


func set_anonymous_action_preview(active: bool) -> void:
	for seat in _seat_nodes:
		if seat.has_method("set_public_action_state"):
			var snapshot: Dictionary = seat.call("get_public_debug_snapshot")
			var is_actor := int(snapshot.get("seat_number", 0)) == 2
			seat.call("set_public_action_state", is_actor, active)
	_update_debug_label(active)


func rebuild_layout() -> void:
	if not is_node_ready():
		return
	for seat in _seat_nodes:
		if is_instance_valid(seat):
			seat.queue_free()
	_seat_nodes.clear()
	var specs: Array[Dictionary] = PlanetSeatLayoutScript.resolve(preview_player_count, size)
	for spec in specs:
		var seat_index := int(spec.get("seat_index", 0))
		var seat := PlayerSeatScene.instantiate() as Control
		var role_name: String = str(PREVIEW_ROLES[seat_index % PREVIEW_ROLES.size()])
		var portrait_view := str(spec.get("portrait_view", "front"))
		var texture: Texture2D = _catalog.portrait_texture_or_null(role_name, portrait_view)
		var availability: Dictionary = _catalog.portrait_availability(role_name, portrait_view)
		var entry: Dictionary = _catalog.entry_for_role(role_name)
		var layer := front_seat_layer if str(spec.get("layer", "")) == "FrontSeatLayer" else back_seat_layer
		layer.add_child(seat)
		seat.apply_public_snapshot({
			"seat_number": seat_index + 1,
			"role_name": role_name,
			"public_passive_summary": "公开角色能力摘要；不显示手牌、现金或匿名行动来源。",
			"public_status": "waiting" if seat_index == 3 else "normal",
			"player_color": PLAYER_COLORS[seat_index % PLAYER_COLORS.size()],
			"is_public_actor": seat_index == 1,
			"anonymous_action_active": false,
		}, texture)
		seat.set_qa_portrait_metadata({
			"portrait_source": "manifest_png" if bool(availability.get("available", false)) else "missing",
			"actual_png_path": str(availability.get("path", "")),
			"is_placeholder": not bool(availability.get("available", false)),
			"source_model": str(entry.get("source_path", "")),
			"render_variant": portrait_view,
		})
		seat.apply_layout_spec(spec)
		_seat_nodes.append(seat)
	_update_debug_label(false)


func debug_snapshot() -> Dictionary:
	var seats: Array[Dictionary] = []
	for seat in _seat_nodes:
		if is_instance_valid(seat) and seat.has_method("get_public_debug_snapshot"):
			seats.append(seat.call("get_public_debug_snapshot"))
	return {
		"scene": "RoleTablePortraitPreview",
		"player_count": preview_player_count,
		"layout": PlanetSeatLayoutScript.debug_snapshot(preview_player_count, size),
		"seat_count": seats.size(),
		"placeholder_count": _placeholder_count(seats),
		"seats": seats,
		"catalog": _catalog.developer_snapshot() if _catalog != null else {"available": false},
		"privacy": {
			"anonymous_action_highlight_suppressed": true,
			"opponent_hand_count_visible": false,
			"opponent_cash_visible": false,
			"hidden_owner_visible": false,
			"ai_scoring_visible": false,
		},
	}


func capture_required_layouts() -> Dictionary:
	if not capture_output_root.begins_with("res://docs/art_qa/") or capture_output_root.contains(".."):
		return {"ok": false, "reason": "capture_output_root_rejected"}
	var outputs: Array[String] = []
	for player_count in [4, 8]:
		set_player_count(player_count)
		for frame_index in 5:
			await get_tree().process_frame
		var snapshot := debug_snapshot()
		if int(snapshot.get("placeholder_count", 0)) > 0:
			var failure := {
				"ok": false,
				"reason": "clean_capture_contains_placeholder",
				"player_count": player_count,
				"placeholder_count": int(snapshot.get("placeholder_count", 0)),
			}
			push_error("ROLE_TABLE_LAYOUT_CAPTURE %s" % JSON.stringify(failure))
			if DisplayServer.get_name() == "headless":
				get_tree().quit(1)
			return failure
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image.is_empty():
			return {"ok": false, "reason": "viewport_image_empty", "player_count": player_count}
		var output_path := "%splanet_table_%d_players_actual_art.png" % [capture_output_root, player_count]
		var absolute_path := ProjectSettings.globalize_path(output_path)
		DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
		var error := image.save_png(absolute_path)
		if error != OK:
			return {"ok": false, "reason": "png_save_failed", "error": error, "player_count": player_count}
		outputs.append(output_path)
	var result := {"ok": true, "outputs": outputs, "viewport_size": [get_viewport_rect().size.x, get_viewport_rect().size.y]}
	print("ROLE_TABLE_LAYOUT_CAPTURE ", JSON.stringify(result))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)
	return result


func _connect_controls() -> void:
	var controls := {
		$LayoutControls/Players3: 3,
		$LayoutControls/Players4: 4,
		$LayoutControls/Players6: 6,
		$LayoutControls/Players8: 8,
	}
	for button_variant in controls.keys():
		var button := button_variant as Button
		var count := int(controls[button_variant])
		if not button.pressed.is_connected(set_player_count.bind(count)):
			button.pressed.connect(set_player_count.bind(count))
	if not $LayoutControls/AnonymousToggle.toggled.is_connected(set_anonymous_action_preview):
		$LayoutControls/AnonymousToggle.toggled.connect(set_anonymous_action_preview)


func _update_debug_label(anonymous_active: bool) -> void:
	if debug_label == null:
		return
	var snapshot := debug_snapshot()
	debug_label.text = "%d席｜中央星球牌桌｜匿名行动:%s｜缺图:%d" % [
		preview_player_count,
		"不高亮出牌者" if anonymous_active else "公开行动者可高亮",
		int(snapshot.get("placeholder_count", 0)),
	]


func _placeholder_count(seats: Array[Dictionary]) -> int:
	var count := 0
	for seat in seats:
		if bool(seat.get("is_placeholder", true)):
			count += 1
	return count
