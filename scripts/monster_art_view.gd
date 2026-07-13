extends Control

const STAR_COUNT_FULL := 34
const STAR_COUNT_COMPACT := 20
const MONSTER_ART_EXTERNAL_THEME := "multi-source-open-monster-sprites-v2"
const MOTH_KAIJUICE_KAIJU_PATH := "res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc.png"
const MOTH_KAIJUICE_ATFIELD_PATH := "res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_atfield.png"
const MOTH_KAIJUICE_LASER_PATH := "res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_laser.png"
const MOTH_KAIJUICE_MECH_PATH := "res://assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_mech.png"
const MOTH_KAIJUICE_TANK_PATH := "res://assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_tank.png"
const MOTH_KAIJUICE_CELL_SIZE := Vector2(93.0, 93.0)
const MONSTER_BATTLER_DINO_PATH := "res://assets/third_party/monster_battler/monsters/dino.png"
const MONSTER_BATTLER_ROCK_PATH := "res://assets/third_party/monster_battler/monsters/rock.png"
const MONSTER_BATTLER_RODENT_PATH := "res://assets/third_party/monster_battler/monsters/rodent.png"
const MONSTER_BATTLER_SALAMANDER_PATH := "res://assets/third_party/monster_battler/monsters/salamander.png"
const MONSTER_BATTLER_TURTLE_PATH := "res://assets/third_party/monster_battler/monsters/turtle.png"
const KENNEY_FISH_PATH := "res://assets/third_party/kenney_cc0/platformer/enemies/fishSwim1.png"
const KENNEY_SLIME_PATH := "res://assets/third_party/kenney_cc0/platformer/enemies/slimeWalk1.png"
const KENNEY_ALIEN_BLUE_PATH := "res://assets/third_party/kenney_cc0/hexagon/alienBlue.png"
const KENNEY_ENEMY_UFO_PATH := "res://assets/third_party/kenney_cc0/space/enemyUFO.png"
const PIXELMOB_SLIME_PATH := "res://assets/third_party/pixelmob_cc0/sprites/SlimeA.png"
const PIXELMOB_SLIME_SQUARE_PATH := "res://assets/third_party/pixelmob_cc0/sprites/SlimeSquareA.png"
const PIXELMOB_FRAME_COUNT := 5
const SUPERPOWERS_DRAGON_PATH := "res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/dragon.png"
const SUPERPOWERS_CYCLOP_PATH := "res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/cyclop.png"
const SUPERPOWERS_SNAKE_PATH := "res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/snake.png"
const SUPERPOWERS_SLIM_PATH := "res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/slim.png"

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
var moth_kaijuice_textures := {}
var source_sprite_key := ""
var source_sprite_cell := ""
var source_visual_id := ""
var source_upstream_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("monster_art_external_asset_theme", MONSTER_ART_EXTERNAL_THEME)
	moth_kaijuice_textures = {
		"moth_kaijuice_kaiju": _load_optional_texture(MOTH_KAIJUICE_KAIJU_PATH),
		"moth_kaijuice_atfield": _load_optional_texture(MOTH_KAIJUICE_ATFIELD_PATH),
		"moth_kaijuice_laser": _load_optional_texture(MOTH_KAIJUICE_LASER_PATH),
		"moth_kaijuice_mech": _load_optional_texture(MOTH_KAIJUICE_MECH_PATH),
		"moth_kaijuice_tank": _load_optional_texture(MOTH_KAIJUICE_TANK_PATH),
		"monster_battler_dino": _load_optional_texture(MONSTER_BATTLER_DINO_PATH),
		"monster_battler_rock": _load_optional_texture(MONSTER_BATTLER_ROCK_PATH),
		"monster_battler_rodent": _load_optional_texture(MONSTER_BATTLER_RODENT_PATH),
		"monster_battler_salamander": _load_optional_texture(MONSTER_BATTLER_SALAMANDER_PATH),
		"monster_battler_turtle": _load_optional_texture(MONSTER_BATTLER_TURTLE_PATH),
		"kenney_fish": _load_optional_texture(KENNEY_FISH_PATH),
		"kenney_slime": _load_optional_texture(KENNEY_SLIME_PATH),
		"kenney_alien_blue": _load_optional_texture(KENNEY_ALIEN_BLUE_PATH),
		"kenney_enemy_ufo": _load_optional_texture(KENNEY_ENEMY_UFO_PATH),
		"pixelmob_slime": _load_optional_texture(PIXELMOB_SLIME_PATH),
		"pixelmob_slime_square": _load_optional_texture(PIXELMOB_SLIME_SQUARE_PATH),
		"superpowers_dragon": _load_optional_texture(SUPERPOWERS_DRAGON_PATH),
		"superpowers_cyclop": _load_optional_texture(SUPERPOWERS_CYCLOP_PATH),
		"superpowers_snake": _load_optional_texture(SUPERPOWERS_SNAKE_PATH),
		"superpowers_slim": _load_optional_texture(SUPERPOWERS_SLIM_PATH),
	}


func set_monster(monster_display_name: String, style: String, hp_value: int, armor_value: int, move_value_text: String, profile: Dictionary, is_compact: bool = false) -> void:
	monster_name = monster_display_name
	style_text = style
	hp = hp_value
	armor = armor_value
	move_text = move_value_text
	accent = profile.get("accent", Color("#94a3b8")) as Color
	secondary = profile.get("secondary", Color("#e2e8f0")) as Color
	glyph = String(profile.get("glyph", "怪"))
	motif = String(profile.get("motif", "beast"))
	subtitle = String(profile.get("subtitle", "星兽档案"))
	source_sprite_key = String(profile.get("sprite_key", ""))
	source_sprite_cell = String(profile.get("sprite_cell", ""))
	source_visual_id = String(profile.get("visual_source_id", ""))
	source_upstream_id = String(profile.get("upstream_source_id", ""))
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
	_draw_moth_kaijuice_reference_sprite(rect)
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
	var name_seed := _name_seed()
	var star_count := STAR_COUNT_COMPACT if compact else STAR_COUNT_FULL
	for i in range(star_count):
		var x := fposmod(float(name_seed + i * 83 + i * i * 7), max(1.0, rect.size.x))
		var y := fposmod(float(int(float(name_seed) / float(max(1, i + 1))) + i * 41 + hp * 3), max(1.0, rect.size.y))
		var radius := 0.7 + float((name_seed + i * 13) % 4) * 0.22
		var color := Color("#ffffff").lerp(secondary, 0.30)
		color.a = 0.18 + float((name_seed + i) % 6) * 0.045
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


func monster_visual_profile_snapshot() -> Dictionary:
	var name_seed := _name_seed()
	var sprite_key := _monster_reference_sprite_key()
	return {
		"theme": MONSTER_ART_EXTERNAL_THEME,
		"upstream_source_id": _monster_upstream_source_id(sprite_key),
		"visual_source_id": _monster_visual_source_id(sprite_key),
		"sprite_key": sprite_key,
		"sprite_cell": _monster_reference_sprite_cell(sprite_key),
		"silhouette": motif,
		"layout_variant": name_seed % 11,
		"palette_variant": int(float(name_seed) / 7.0) % 13,
		"effect_layer": _monster_reference_effect_layer(),
		"composition_variant": int(float(name_seed) / 17.0) % 17,
	}


func monster_visual_profile_key() -> String:
	var profile := monster_visual_profile_snapshot()
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(profile.get("visual_source_id", "")),
		str(profile.get("sprite_key", "")),
		str(profile.get("sprite_cell", "")),
		str(profile.get("silhouette", "")),
		str(profile.get("layout_variant", "")),
		str(profile.get("palette_variant", "")),
		str(profile.get("effect_layer", "")),
		str(profile.get("composition_variant", "")),
	]


func _draw_moth_kaijuice_reference_sprite(rect: Rect2) -> void:
	var profile := monster_visual_profile_snapshot()
	var sprite_key := String(profile.get("sprite_key", ""))
	var texture := moth_kaijuice_textures.get(sprite_key, null) as Texture2D
	if texture == null:
		return
	var name_seed := _name_seed()
	var portrait_rect := Rect2(
		Vector2(rect.size.x * 0.18, rect.size.y * (0.22 if compact else 0.20)),
		Vector2(rect.size.x * 0.64, rect.size.y * (0.44 if compact else 0.50))
	)
	var halo := accent.lightened(0.28)
	halo.a = 0.20 if compact else 0.28
	draw_circle(portrait_rect.get_center(), min(portrait_rect.size.x, portrait_rect.size.y) * 0.48, halo)
	var sprite_scale := 0.82 + float(name_seed % 4) * 0.045
	var source_region := _monster_reference_sprite_region(sprite_key)
	var sprite_rect := Rect2(Vector2.ZERO, _fit_size_inside(portrait_rect.size * sprite_scale, source_region.size))
	sprite_rect.position = portrait_rect.position + (portrait_rect.size - sprite_rect.size) * 0.5 + Vector2(float((name_seed % 5) - 2) * 2.2, float((int(float(name_seed) / 17.0) % 5) - 2) * 2.0)
	var tint := Color(1.0, 1.0, 1.0, 0.74 if compact else 0.88)
	tint = tint.lerp(accent.lightened(0.14), 0.10)
	draw_texture_rect_region(texture, sprite_rect, source_region, tint)

	var effect_layer := String(profile.get("effect_layer", ""))
	if effect_layer == "field":
		_draw_moth_kaijuice_monster_field(portrait_rect)
	elif effect_layer == "laser":
		_draw_moth_kaijuice_monster_laser(portrait_rect, name_seed)
	elif effect_layer == "impact":
		_draw_moth_kaijuice_monster_impact(portrait_rect, name_seed)


func _draw_moth_kaijuice_monster_field(portrait_rect: Rect2) -> void:
	var center := portrait_rect.get_center()
	var field := secondary.lightened(0.20)
	field.a = 0.34 if compact else 0.48
	for i in range(3):
		var radius: float = min(portrait_rect.size.x, portrait_rect.size.y) * (0.22 + float(i) * 0.095)
		draw_arc(center, radius, -PI * 0.15 + float(i) * 0.28, PI * 1.58 + float(i) * 0.18, 48, field, 2.0, true)
		field.a *= 0.76


func _draw_moth_kaijuice_monster_laser(portrait_rect: Rect2, art_seed: int) -> void:
	var y := portrait_rect.position.y + portrait_rect.size.y * (0.35 + float(art_seed % 4) * 0.08)
	var core := accent.lightened(0.45)
	var glow := secondary.lightened(0.35)
	glow.a = 0.26 if compact else 0.38
	core.a = 0.72 if compact else 0.88
	var start := Vector2(portrait_rect.position.x + portrait_rect.size.x * 0.10, y)
	var end := Vector2(portrait_rect.end.x - portrait_rect.size.x * 0.08, y + float((art_seed % 3) - 1) * 4.0)
	draw_line(start, end, glow, max(7.0, portrait_rect.size.y * 0.055), true)
	draw_line(start, end, core, max(2.0, portrait_rect.size.y * 0.022), true)


func _draw_moth_kaijuice_monster_impact(portrait_rect: Rect2, art_seed: int) -> void:
	var impact := secondary.lightened(0.16)
	impact.a = 0.40 if compact else 0.56
	for i in range(3):
		var t := float(i) / 2.0
		var p0 := portrait_rect.position + Vector2(portrait_rect.size.x * (0.18 + t * 0.28), portrait_rect.size.y * 0.82)
		var p1 := p0 + Vector2(float((art_seed + i) % 5 - 2) * 6.0, -portrait_rect.size.y * (0.24 + t * 0.08))
		draw_line(p0, p1, impact, 2.0 + t, true)


func _monster_reference_sprite_key() -> String:
	if source_sprite_key != "":
		return source_sprite_key
	match motif:
		"miasma":
			return "superpowers_dragon"
		"mud":
			return "monster_battler_rock"
		"meteor_sentinel":
			return "kenney_enemy_ufo"
		"prism_armor":
			return "monster_battler_dino"
		"oasis_support":
			return "pixelmob_slime_square"
		"ember_ring":
			return "moth_kaijuice_kaiju"
		"blue_lancer":
			return "superpowers_snake"
		"mirror_hunter":
			return "kenney_alien_blue"
		_:
			return "monster_battler_rodent"


func _monster_upstream_source_id(sprite_key: String) -> String:
	if source_upstream_id != "":
		return source_upstream_id
	if sprite_key.begins_with("moth_kaijuice"):
		return "moth_kaijuice_mit"
	if sprite_key.begins_with("monster_battler"):
		return "monster_battler_cc0"
	if sprite_key.begins_with("kenney"):
		return "kenney_cc0"
	if sprite_key.begins_with("pixelmob"):
		return "pixelmob_cc0"
	if sprite_key.begins_with("superpowers"):
		return "superpowers_asset_packs_cc0"
	return "procedural_fallback"


func _monster_visual_source_id(sprite_key: String) -> String:
	if source_visual_id != "":
		return source_visual_id
	match sprite_key:
		"moth_kaijuice_kaiju":
			return "moth_kaijuice_mit_kaiju_family"
		"monster_battler_dino":
			return "monster_battler_cc0_dino_family"
		"monster_battler_rock":
			return "monster_battler_cc0_rock_family"
		"monster_battler_rodent":
			return "monster_battler_cc0_rodent_family"
		"monster_battler_salamander":
			return "monster_battler_cc0_salamander_family"
		"monster_battler_turtle":
			return "monster_battler_cc0_turtle_family"
		"kenney_fish":
			return "kenney_cc0_fish_family"
		"kenney_slime":
			return "kenney_cc0_slime_family"
		"kenney_alien_blue":
			return "kenney_cc0_alien_blue_family"
		"kenney_enemy_ufo":
			return "kenney_cc0_enemy_ufo_family"
		"pixelmob_slime":
			return "pixelmob_cc0_slime_family"
		"pixelmob_slime_square":
			return "pixelmob_cc0_slime_square_family"
		"superpowers_dragon":
			return "superpowers_cc0_dragon_family"
		"superpowers_cyclop":
			return "superpowers_cc0_cyclop_family"
		"superpowers_snake":
			return "superpowers_cc0_snake_family"
		"superpowers_slim":
			return "superpowers_cc0_slim_family"
		_:
			return "procedural_fallback_family"


func _monster_reference_sprite_cell(sprite_key: String) -> String:
	if source_sprite_cell != "":
		return source_sprite_cell
	if sprite_key == "moth_kaijuice_kaiju":
		var cell_index := _name_seed() % 32
		return "%d,%d" % [cell_index % 8, int(float(cell_index) / 8.0)]
	if sprite_key == "moth_kaijuice_mech":
		var cell_index := _name_seed() % 24
		return "%d,%d" % [cell_index % 8, int(float(cell_index) / 8.0)]
	if sprite_key.begins_with("pixelmob"):
		return str(_name_seed() % PIXELMOB_FRAME_COUNT)
	return "full"


func _monster_reference_sprite_region(sprite_key: String) -> Rect2:
	var texture := moth_kaijuice_textures.get(sprite_key, null) as Texture2D
	if texture == null:
		return Rect2()
	if sprite_key == "moth_kaijuice_kaiju" or sprite_key == "moth_kaijuice_mech":
		var cell_text := _monster_reference_sprite_cell(sprite_key)
		var parts := cell_text.split(",")
		var cell_x := int(parts[0]) if parts.size() > 0 else 0
		var cell_y := int(parts[1]) if parts.size() > 1 else 0
		return Rect2(Vector2(float(cell_x) * MOTH_KAIJUICE_CELL_SIZE.x, float(cell_y) * MOTH_KAIJUICE_CELL_SIZE.y), MOTH_KAIJUICE_CELL_SIZE)
	if sprite_key.begins_with("pixelmob"):
		var frame_count := PIXELMOB_FRAME_COUNT
		var frame_width := texture.get_size().x / float(frame_count)
		var frame_index := clampi(int(_monster_reference_sprite_cell(sprite_key)), 0, frame_count - 1)
		return Rect2(Vector2(frame_width * float(frame_index), 0.0), Vector2(frame_width, texture.get_size().y))
	return Rect2(Vector2.ZERO, texture.get_size())


func _monster_reference_effect_layer() -> String:
	match motif:
		"miasma", "oasis_support":
			return "field"
		"ember_ring", "blue_lancer", "mirror_hunter":
			return "laser"
		"mud", "prism_armor":
			return "impact"
		_:
			return "none"


func _fit_size_inside(bounds: Vector2, source_size: Vector2) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return bounds
	var aspect := source_size.x / source_size.y
	var fitted := bounds
	if fitted.x / max(1.0, fitted.y) > aspect:
		fitted.x = fitted.y * aspect
	else:
		fitted.y = fitted.x / aspect
	return fitted


func _load_optional_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var resource := load(path)
		return resource as Texture2D
	var image := Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	return null


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
	var name_seed := 197 + hp * 11 + armor * 31 + motif.length() * 43
	for i in range(monster_name.length()):
		name_seed = (name_seed * 37 + monster_name.unicode_at(i)) % 1000003
	return max(1, name_seed)
