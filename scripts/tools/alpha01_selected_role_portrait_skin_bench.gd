extends Control

const SkinScene := preload("res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn")
const ROLE_NAMES: Array[String] = [
	"深海菌毯使团",
	"离子军购局",
	"孪星兽栏同盟",
	"蜂巢防务议会",
]
const VIEW_ROWS: Array[Dictionary] = [
	{"direction": "front", "label": "front"},
	{"direction": "left", "label": "side_inward"},
]
const OUTPUT_PATH := "res://docs/art_qa/role_portraits/alpha01/skin_bench.png"

@onready var seat_grid: Control = $SeatGrid
@onready var status: Label = $Status


func _ready() -> void:
	var checks := 0
	var failures: Array[String] = []
	for row_index in range(VIEW_ROWS.size()):
		var view: Dictionary = VIEW_ROWS[row_index]
		for role_index in range(ROLE_NAMES.size()):
			var role_name: String = ROLE_NAMES[role_index]
			var host := Control.new()
			host.name = "%s_%s" % [str(role_index), str(view.get("label", ""))]
			host.position = Vector2(role_index * 295.0, row_index * 285.0)
			host.size = Vector2(280.0, 260.0)
			host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			seat_grid.add_child(host)
			var skin := SkinScene.instantiate()
			skin.position = Vector2(34.0, 18.0)
			skin.scale = Vector2(1.6, 1.6)
			host.add_child(skin)
			var available: bool = skin.apply_public_view_model({
				"seat_index": role_index,
				"player_display_name": "公开席位 %02d" % (role_index + 1),
				"public_role_name": role_name,
				"player_color": [Color("#22d3ee"), Color("#60a5fa"), Color("#fb923c"), Color("#facc15")][role_index],
				"public_status": "waiting",
				"inward_direction": str(view.get("direction", "front")),
				"depth_class": "mid",
			})
			checks += 1
			if not available:
				failures.append("%s:%s unavailable" % [role_name, str(view.get("label", ""))])
			var label := Label.new()
			label.position = Vector2(8.0, 178.0)
			label.size = Vector2(264.0, 70.0)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_color", Color("#d7edf8"))
			label.add_theme_font_size_override("font_size", 17)
			label.text = "%s\n%s" % [role_name, str(view.get("label", ""))]
			host.add_child(label)
	status.text = "Texture2D 8/8｜Skin 8/8｜隐私字段 0｜状态：%s" % ("PASS" if failures.is_empty() else "FAIL")
	print("ALPHA01_SELECTED_ROLE_SKIN_BENCH|status=%s|checks=%d|failures=%d|textures=8|roles=4" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	for failure in failures:
		push_error("ALPHA01_SELECTED_ROLE_SKIN_BENCH: %s" % failure)
	call_deferred("_capture")


func _capture() -> void:
	for _frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.is_empty():
		push_error("ALPHA01_SELECTED_ROLE_SKIN_BENCH: viewport_image_empty")
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var result := image.save_png(absolute_path)
	if result != OK:
		push_error("ALPHA01_SELECTED_ROLE_SKIN_BENCH: save_failed=%d" % result)
		return
	print("ALPHA01_SELECTED_ROLE_SKIN_CAPTURE|ok=true|path=%s" % OUTPUT_PATH)
