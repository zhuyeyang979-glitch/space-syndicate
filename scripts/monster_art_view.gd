extends Control

const STAR_COUNT_FULL := 34
const STAR_COUNT_COMPACT := 20

var monster_name := "怪兽"
var style_text := "自动怪兽"
var hp := 0
var armor := 0
var move_text := ""
var accent := Color("#94a3b8")
var secondary := Color("#e2e8f0")
var glyph := "怪"
var motif := "beast"
var subtitle := "星兽档案"
var compact := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_monster(name: String, style: String, hp_value: int, armor_value: int, move_value_text: String, profile: Dictionary, is_compact: bool = false) -> void:
	monster_name = name
	style_text = style
	hp = hp_value
	armor = armor_value
	move_text = move_value_text
	accent = profile.get("accent", Color("#94a3b8")) as Color
	secondary = profile.get("secondary", Color("#e2e8f0")) as Color
	glyph = String(profile.get("glyph", "怪"))
	motif = String(profile.get("motif", "beast"))
	subtitle = String(profile.get("subtitle", "星兽档案"))
	compact = is_compact
	queue_redraw()


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	_draw_backdrop(rect)
	_draw_starfield(rect)
	_draw_portrait_frame(rect)
	_draw_silhouette(rect)
	_draw_nameplate(rect)
	_draw_stat_strip(rect)


func _draw_backdrop(rect: Rect2) -> void:
	var base := Color("#020617").lerp(accent, 0.18)
	draw_rect(rect, base, true)
	var wash := accent.lightened(0.18)
	wash.a = 0.16
	draw_circle(Vector2(rect.size.x * 0.24, rect.size.y * 0.22), rect.size.y * 0.45, wash)
	wash = secondary.lightened(0.10)
	wash.a = 0.10
	draw_circle(Vector2(rect.size.x * 0.76, rect.size.y * 0.70), rect.size.y * 0.52, wash)
	for i in range(7):
		var t := float(i) / 6.0
		var band := accent.lerp(secondary, t)
		band.a = 0.032
		draw_rect(Rect2(0.0, rect.size.y * t, rect.size.x, rect.size.y * 0.16), band, true)


func _draw_starfield(rect: Rect2) -> void:
	var seed := _name_seed()
	var star_count := STAR_COUNT_COMPACT if compact else STAR_COUNT_FULL
	for i in range(star_count):
		var x := fposmod(float(seed + i * 83 + i * i * 7), max(1.0, rect.size.x))
		var y := fposmod(float(seed / max(1, i + 1) + i * 41 + hp * 3), max(1.0, rect.size.y))
		var radius := 0.7 + float((seed + i * 13) % 4) * 0.22
		var color := Color("#ffffff").lerp(secondary, 0.30)
		color.a = 0.18 + float((seed + i) % 6) * 0.045
		draw_circle(Vector2(x, y), radius, color)


func _draw_portrait_frame(rect: Rect2) -> void:
	var frame_rect := Rect2(Vector2(8, 8), rect.size - Vector2(16, 16))
	var border := accent.lightened(0.15)
	border.a = 0.92
	draw_rect(frame_rect, border, false, 2.0)
	var inner := secondary.lightened(0.08)
	inner.a = 0.28
	draw_rect(Rect2(Vector2(14, 14), rect.size - Vector2(28, 28)), inner, false, 1.0)
	for i in range(4):
		var corner := Vector2(14.0 if i < 2 else rect.size.x - 14.0, 14.0 if i % 2 == 0 else rect.size.y - 14.0)
		draw_circle(corner, 3.0, border)


func _draw_silhouette(rect: Rect2) -> void:
	var center := Vector2(rect.size.x * 0.50, rect.size.y * (0.52 if compact else 0.50))
	var radius: float = min(float(rect.size.x), float(rect.size.y)) * (0.24 if compact else 0.27)
	var body_color := accent.darkened(0.18)
	body_color.a = 0.86
	var glow := secondary.lightened(0.18)
	glow.a = 0.24
	draw_circle(center, radius * 1.22, glow)

	match motif:
		"miasma":
			_draw_miasma_silhouette(center, radius, body_color)
		"mud":
			_draw_mud_silhouette(center, radius, body_color)
		"meteor_sentinel":
			_draw_robot_silhouette(center, radius, body_color, false)
		"prism_armor":
			_draw_robot_silhouette(center, radius, body_color, true)
		"oasis_support":
			_draw_support_silhouette(center, radius, body_color)
		"ember_ring":
			_draw_flame_silhouette(center, radius, body_color)
		"blue_lancer":
			_draw_blade_silhouette(center, radius, body_color)
		"mirror_hunter":
			_draw_mirror_hunter_silhouette(center, radius, body_color)
		_:
			_draw_beast_silhouette(center, radius, body_color)
	_draw_glyph(center, radius)


func _draw_beast_silhouette(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius * 0.68, color)
	draw_circle(center + Vector2(-radius * 0.34, -radius * 0.20), radius * 0.23, color)
	draw_circle(center + Vector2(radius * 0.34, -radius * 0.20), radius * 0.23, color)
	_draw_horns(center, radius)


func _draw_miasma_silhouette(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius * 0.66, color)
	for i in range(7):
		var angle := float(i) / 7.0 * TAU
		var pos := center + Vector2(cos(angle), sin(angle)) * radius * (0.50 + float(i % 3) * 0.08)
		var cloud := secondary
		cloud.a = 0.28
		draw_circle(pos, radius * 0.18, cloud)
	_draw_horns(center + Vector2(0.0, -radius * 0.04), radius * 0.95)


func _draw_mud_silhouette(center: Vector2, radius: float, color: Color) -> void:
	var body := PackedVector2Array([
		center + Vector2(-radius * 0.80, radius * 0.35),
		center + Vector2(-radius * 0.46, -radius * 0.48),
		center + Vector2(radius * 0.08, -radius * 0.72),
		center + Vector2(radius * 0.70, -radius * 0.22),
		center + Vector2(radius * 0.62, radius * 0.46),
		center + Vector2(-radius * 0.22, radius * 0.70),
	])
	draw_colored_polygon(body, color)
	_draw_horns(center + Vector2(radius * 0.08, -radius * 0.18), radius)
	var mud := secondary
	mud.a = 0.38
	draw_line(center + Vector2(-radius * 0.65, radius * 0.56), center + Vector2(radius * 0.72, radius * 0.46), mud, 4.0, true)


func _draw_robot_silhouette(center: Vector2, radius: float, color: Color, prism_shape: bool) -> void:
	var head_size := Vector2(radius * (1.06 if prism_shape else 0.94), radius * 0.86)
	var head := Rect2(center - head_size * 0.5, head_size)
	draw_rect(head, color, true)
	var visor := secondary.lightened(0.18)
	visor.a = 0.92
	draw_rect(Rect2(head.position + Vector2(head_size.x * 0.16, head_size.y * 0.34), Vector2(head_size.x * 0.68, head_size.y * 0.16)), visor, true)
	if prism_shape:
		draw_line(center + Vector2(0.0, -radius * 0.75), center + Vector2(0.0, radius * 0.18), visor, 3.0, true)
		draw_line(center + Vector2(-radius * 0.48, -radius * 0.54), center + Vector2(radius * 0.48, -radius * 0.54), visor, 2.0, true)
	else:
		draw_circle(center + Vector2(-radius * 0.34, -radius * 0.46), radius * 0.16, color)
		draw_circle(center + Vector2(radius * 0.34, -radius * 0.46), radius * 0.16, color)


func _draw_support_silhouette(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius * 0.60, color)
	var cross := secondary.lightened(0.20)
	cross.a = 0.82
	draw_line(center + Vector2(-radius * 0.46, 0.0), center + Vector2(radius * 0.46, 0.0), cross, 5.0, true)
	draw_line(center + Vector2(0.0, -radius * 0.46), center + Vector2(0.0, radius * 0.46), cross, 5.0, true)
	draw_arc(center, radius * 0.82, -PI * 0.15, PI * 1.15, 36, cross, 2.0, true)


func _draw_flame_silhouette(center: Vector2, radius: float, color: Color) -> void:
	var flame := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.92),
		center + Vector2(radius * 0.54, -radius * 0.18),
		center + Vector2(radius * 0.36, radius * 0.58),
		center + Vector2(0.0, radius * 0.82),
		center + Vector2(-radius * 0.48, radius * 0.34),
		center + Vector2(-radius * 0.34, -radius * 0.24),
	])
	draw_colored_polygon(flame, color)
	var inner := secondary
	inner.a = 0.42
	draw_circle(center + Vector2(0.0, radius * 0.14), radius * 0.34, inner)


func _draw_blade_silhouette(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius * 0.54, color)
	var blade := secondary.lightened(0.22)
	blade.a = 0.86
	draw_line(center + Vector2(-radius * 0.72, radius * 0.62), center + Vector2(radius * 0.78, -radius * 0.74), blade, 5.0, true)
	draw_line(center + Vector2(-radius * 0.30, -radius * 0.74), center + Vector2(radius * 0.34, radius * 0.70), blade, 2.0, true)


func _draw_mirror_hunter_silhouette(center: Vector2, radius: float, color: Color) -> void:
	var head := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.82),
		center + Vector2(radius * 0.72, -radius * 0.28),
		center + Vector2(radius * 0.46, radius * 0.68),
		center + Vector2(-radius * 0.46, radius * 0.68),
		center + Vector2(-radius * 0.72, -radius * 0.28),
	])
	draw_colored_polygon(head, color)
	var eye := secondary.lightened(0.20)
	eye.a = 0.94
	draw_line(center + Vector2(-radius * 0.45, -radius * 0.06), center + Vector2(radius * 0.45, -radius * 0.06), eye, 4.0, true)
	draw_line(center + Vector2(-radius * 0.58, -radius * 0.45), center + Vector2(-radius * 0.90, -radius * 0.88), eye, 2.0, true)
	draw_line(center + Vector2(radius * 0.58, -radius * 0.45), center + Vector2(radius * 0.90, -radius * 0.88), eye, 2.0, true)


func _draw_horns(center: Vector2, radius: float) -> void:
	var horn := secondary.lightened(0.14)
	horn.a = 0.84
	draw_line(center + Vector2(-radius * 0.28, -radius * 0.52), center + Vector2(-radius * 0.68, -radius * 0.92), horn, 3.0, true)
	draw_line(center + Vector2(radius * 0.28, -radius * 0.52), center + Vector2(radius * 0.68, -radius * 0.92), horn, 3.0, true)


func _draw_glyph(center: Vector2, radius: float) -> void:
	var font := get_theme_default_font()
	var font_size := 32 if compact else 44
	var y := center.y + radius * 0.18
	draw_string(font, Vector2(center.x - radius, y + 2.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color("#020617"))
	draw_string(font, Vector2(center.x - radius, y), glyph, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color("#f8fafc"))


func _draw_nameplate(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var name_size := 17 if compact else 22
	var sub_size := 9 if compact else 11
	var y_name := 30.0 if compact else 36.0
	draw_string(font, Vector2(0.0, y_name), monster_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, name_size, Color("#f8fafc"))
	var sub := _short_text(subtitle, 18 if compact else 24)
	draw_string(font, Vector2(0.0, y_name + 18.0), sub, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, sub_size, secondary.lightened(0.12))


func _draw_stat_strip(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var strip_h := 34.0 if compact else 42.0
	var y := rect.size.y - strip_h - 8.0
	var bg := Color("#020617")
	bg.a = 0.74
	draw_rect(Rect2(12.0, y, rect.size.x - 24.0, strip_h), bg, true)
	var stat := "HP%d  护%d  速%s" % [hp, armor, move_text]
	draw_string(font, Vector2(18.0, y + 17.0), stat, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36.0, 11 if compact else 13, Color("#e2e8f0"))
	if not compact:
		draw_string(font, Vector2(18.0, y + 34.0), _short_text(style_text, 25), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36.0, 10, Color("#cbd5e1"))


func _short_text(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.left(max(1, max_len - 1)) + "…"


func _name_seed() -> int:
	var seed := 197 + hp * 11 + armor * 31 + motif.length() * 43
	for i in range(monster_name.length()):
		seed = (seed * 37 + monster_name.unicode_at(i)) % 1000003
	return max(1, seed)
