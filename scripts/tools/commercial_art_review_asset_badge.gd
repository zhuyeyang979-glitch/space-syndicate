@tool
extends Control
class_name CommercialArtReviewAssetBadge

var asset_key := ""
var base_shape := "circle_with_leaf_notch"
var asset_color := Color("#59c878")
var icon_texture: Texture2D
var fallback_letter := "?"


func _ready() -> void:
	custom_minimum_size = Vector2(76.0, 76.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(
	key: String,
	shape: String,
	color: Color,
	texture: Texture2D,
	letter: String
) -> void:
	asset_key = key
	base_shape = shape
	asset_color = color
	icon_texture = texture
	fallback_letter = letter.left(1).to_upper() if not letter.is_empty() else "?"
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"asset_key": asset_key,
		"base_shape": base_shape,
		"color": asset_color.to_html(false),
		"texture_resolved": icon_texture != null,
		"presentation_only": true,
	}


func _draw() -> void:
	var rect := Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0))
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.46
	var fill := asset_color.darkened(0.48)
	var outline := asset_color.lightened(0.16)
	match base_shape:
		"diamond":
			_draw_polygon_shape(PackedVector2Array([
				center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
			]), fill, outline)
		"hexagon":
			_draw_regular_polygon(center, radius, 6, 0.0, fill, outline)
		"clipped_square":
			var cut := radius * 0.42
			_draw_polygon_shape(PackedVector2Array([
				center + Vector2(-radius + cut, -radius), center + Vector2(radius - cut, -radius),
				center + Vector2(radius, -radius + cut), center + Vector2(radius, radius - cut),
				center + Vector2(radius - cut, radius), center + Vector2(-radius + cut, radius),
				center + Vector2(-radius, radius - cut), center + Vector2(-radius, -radius + cut),
			]), fill, outline)
		"octagon":
			_draw_regular_polygon(center, radius, 8, PI / 8.0, fill, outline)
		"horizontal_capsule_with_chevrons":
			_draw_capsule(center, radius, fill, outline)
		_:
			draw_circle(center, radius, fill)
			draw_arc(center, radius, 0.0, TAU, 48, outline, 2.0, true)
			var notch := PackedVector2Array([
				center + Vector2(radius * 0.48, -radius),
				center + Vector2(radius, -radius * 0.48),
				center + Vector2(radius * 0.42, -radius * 0.38),
			])
			draw_colored_polygon(notch, Color("#111720"))
	if icon_texture != null:
		var icon_side := radius * 1.26
		draw_texture_rect(
			icon_texture,
			Rect2(center - Vector2.ONE * icon_side * 0.5, Vector2.ONE * icon_side),
			false,
			Color.WHITE
		)
	else:
		var font := get_theme_default_font()
		var font_size := maxi(18, int(radius * 0.72))
		var text_size := font.get_string_size(fallback_letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		draw_string(
			font,
			center - Vector2(text_size.x * 0.5, -text_size.y * 0.30),
			fallback_letter,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Color("#f5f8fb")
		)


func _draw_regular_polygon(
	center: Vector2,
	radius: float,
	sides: int,
	rotation_offset: float,
	fill: Color,
	outline: Color
) -> void:
	var points := PackedVector2Array()
	for index in range(sides):
		var angle := rotation_offset + TAU * float(index) / float(sides) - PI * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_draw_polygon_shape(points, fill, outline)


func _draw_polygon_shape(points: PackedVector2Array, fill: Color, outline: Color) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	draw_polyline(closed, outline, 2.0, true)


func _draw_capsule(center: Vector2, radius: float, fill: Color, outline: Color) -> void:
	var capsule := Rect2(
		center - Vector2(radius * 1.14, radius * 0.66),
		Vector2(radius * 2.28, radius * 1.32)
	)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(radius * 0.66))
	draw_style_box(style, capsule)
	for offset: float in [-0.22, 0.22]:
		var x: float = center.x + radius * offset
		var chevron := PackedVector2Array([
			Vector2(x - radius * 0.14, center.y - radius * 0.20),
			Vector2(x + radius * 0.08, center.y),
			Vector2(x - radius * 0.14, center.y + radius * 0.20),
		])
		draw_polyline(chevron, outline, 2.0, true)
