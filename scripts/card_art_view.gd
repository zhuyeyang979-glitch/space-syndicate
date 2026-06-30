extends Control

const STAR_COUNT_FULL := 30
const STAR_COUNT_COMPACT := 18

var card_name := ""
var card_kind := ""
var card_tags := ""
var accent := Color("#94a3b8")
var card_rank := 1
var compact := false
var card_stats := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_card(name: String, kind: String, tags: String, color: Color, rank: int, is_compact: bool, stats: String = "") -> void:
	card_name = name
	card_kind = kind
	card_tags = tags
	accent = color
	card_rank = max(1, rank)
	compact = is_compact
	card_stats = stats
	queue_redraw()


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var base := Color("#020617").lerp(accent, 0.18)
	draw_rect(rect, base, true)
	_draw_energy_wash(rect)
	_draw_starfield(rect)
	_draw_motif(rect)
	_draw_rank_marks(rect)
	_draw_border(rect)
	_draw_glyph(rect)
	_draw_caption(rect)


func _draw_energy_wash(rect: Rect2) -> void:
	var band_count := 8
	for i in range(band_count):
		var t := float(i) / float(max(1, band_count - 1))
		var band_color := accent.lightened(0.12)
		band_color.a = 0.035 + t * 0.025
		var band_rect := Rect2(rect.position.x, rect.position.y + rect.size.y * t, rect.size.x, rect.size.y / float(band_count) + 1.0)
		draw_rect(band_rect, band_color, true)
	var flare := accent.lightened(0.25)
	flare.a = 0.18
	draw_circle(Vector2(rect.size.x * 0.22, rect.size.y * 0.16), rect.size.y * 0.34, flare)
	flare.a = 0.10
	draw_circle(Vector2(rect.size.x * 0.82, rect.size.y * 0.72), rect.size.y * 0.42, flare)


func _draw_starfield(rect: Rect2) -> void:
	var seed := _name_seed()
	var star_count := STAR_COUNT_COMPACT if compact else STAR_COUNT_FULL
	for i in range(star_count):
		var x := fposmod(float(seed + i * 73 + i * i * 11), max(1.0, rect.size.x))
		var y := fposmod(float(seed / max(1, i + 1) + i * 47 + card_rank * 31), max(1.0, rect.size.y))
		var radius := 0.8 + float((seed + i * 5) % 4) * 0.22
		var star_color := Color("#ffffff").lerp(accent, 0.28)
		star_color.a = 0.22 + float((seed + i) % 5) * 0.05
		draw_circle(Vector2(x, y), radius, star_color)


func _draw_motif(rect: Rect2) -> void:
	var center := Vector2(rect.size.x * 0.5, rect.size.y * 0.46)
	var radius: float = min(float(rect.size.x), float(rect.size.y)) * (0.23 if compact else 0.26)
	var motif := accent.lightened(0.10)
	motif.a = 0.42
	draw_arc(center, radius, 0.0, TAU, 80, motif, 2.0, true)
	motif.a = 0.18
	draw_arc(center, radius * 1.28, -PI * 0.15, PI * 1.15, 72, motif, 4.0, true)

	match card_kind:
		"player_role":
			_draw_role_motif(center, radius)
		"monster_card":
			_draw_monster_card_motif(center, radius)
		"monster_bound_action":
			_draw_wave_motif(center, radius)
		"monster_takeover":
			_draw_signal_motif(center, radius)
		"military_force", "military_command":
			_draw_military_motif(center, radius)
		"cash_gain":
			_draw_coin_motif(center, radius)
		"city_revenue_boost":
			_draw_city_motif(center, radius)
		"product_speculation", "market_stabilize":
			_draw_market_chart_motif(center, radius)
		"route_insurance":
			_draw_route_motif(center, radius, false)
		"route_sabotage":
			_draw_route_motif(center, radius, true)
		"city_product_upgrade", "city_product_shift", "city_demand_shift":
			_draw_product_crate_motif(center, radius)
		"panic_shift":
			_draw_signal_motif(center, radius)
		"move", "fly", "burrow":
			_draw_motion_motif(center, radius)
		"attack", "charge_attack", "roll_attack":
			_draw_claw_motif(center, radius)
		"area_damage", "mudslide":
			_draw_crack_motif(center, radius)
		"miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath":
			_draw_miasma_motif(center, radius)
		"armor_gain", "guard":
			_draw_shield_motif(center, radius)
		"control_gain", "special_monster_delay", "roar":
			_draw_wave_motif(center, radius)
		"supply_draw":
			_draw_supply_motif(center, radius)
		_:
			_draw_wave_motif(center, radius)


func _draw_military_motif(center: Vector2, radius: float) -> void:
	var label_source := "%s｜%s｜%s" % [card_name, card_tags, card_stats]
	if label_source.contains("战斗机") or label_source.contains("空军") or label_source.contains("前进"):
		var wing := PackedVector2Array([
			center + Vector2(0.0, -radius * 0.78),
			center + Vector2(radius * 0.18, radius * 0.04),
			center + Vector2(radius * 0.82, radius * 0.34),
			center + Vector2(radius * 0.14, radius * 0.30),
			center + Vector2(0.0, radius * 0.78),
			center + Vector2(-radius * 0.14, radius * 0.30),
			center + Vector2(-radius * 0.82, radius * 0.34),
			center + Vector2(-radius * 0.18, radius * 0.04),
		])
		draw_colored_polygon(wing, accent.darkened(0.10))
		draw_polyline(wing, Color("#e0f2fe"), 1.8, true)
		return
	if label_source.contains("轰炸"):
		draw_circle(center + Vector2(0.0, -radius * 0.18), radius * 0.34, accent.darkened(0.08))
		for i in range(3):
			var x := (float(i) - 1.0) * radius * 0.34
			draw_line(center + Vector2(x, radius * 0.02), center + Vector2(x * 0.55, radius * 0.70), Color("#fed7aa"), 2.4, true)
		_draw_crack_motif(center + Vector2(0.0, radius * 0.32), radius * 0.58)
		return
	if label_source.contains("坦克"):
		var body := Rect2(center - Vector2(radius * 0.62, radius * 0.18), Vector2(radius * 1.24, radius * 0.46))
		draw_rect(body, accent.darkened(0.12), true)
		draw_rect(body, Color("#e2e8f0"), false, 1.8)
		draw_line(center + Vector2(radius * 0.08, -radius * 0.12), center + Vector2(radius * 0.78, -radius * 0.42), Color("#e2e8f0"), 3.0, true)
		for i in range(4):
			draw_circle(center + Vector2((float(i) - 1.5) * radius * 0.34, radius * 0.30), radius * 0.10, Color("#0f172a"))
		return
	if label_source.contains("导弹"):
		for i in range(3):
			var x := (float(i) - 1.0) * radius * 0.28
			var tip := center + Vector2(x, -radius * 0.76)
			var tail := center + Vector2(x, radius * 0.58)
			draw_line(tail, tip, Color("#ddd6fe"), 3.0, true)
			draw_circle(tip, radius * 0.08, Color("#fef3c7"))
		draw_arc(center, radius * 0.72, PI * 0.10, PI * 0.90, 36, accent.lightened(0.20), 2.0, true)
		return
	if label_source.contains("潜"):
		_draw_wave_motif(center, radius)
		draw_arc(center + Vector2(0.0, radius * 0.05), radius * 0.58, PI * 0.05, PI * 0.95, 32, Color("#bae6fd"), 3.0, true)
		draw_line(center + Vector2(0.0, -radius * 0.48), center + Vector2(0.0, -radius * 0.78), Color("#bae6fd"), 2.4, true)
		return
	if label_source.contains("舰") or label_source.contains("战舰"):
		_draw_wave_motif(center + Vector2(0.0, radius * 0.26), radius * 0.70)
		var hull := PackedVector2Array([
			center + Vector2(-radius * 0.78, radius * 0.12),
			center + Vector2(radius * 0.78, radius * 0.12),
			center + Vector2(radius * 0.46, radius * 0.52),
			center + Vector2(-radius * 0.48, radius * 0.52),
		])
		draw_colored_polygon(hull, accent.darkened(0.12))
		draw_polyline(hull, Color("#cffafe"), 1.8, true)
		draw_line(center + Vector2(0.0, radius * 0.10), center + Vector2(0.0, -radius * 0.56), Color("#cffafe"), 2.4, true)
		return
	_draw_shield_motif(center, radius)


func _draw_role_motif(center: Vector2, radius: float) -> void:
	var core := accent.lightened(0.30)
	core.a = 0.54
	var trim := Color("#fef3c7")
	trim.a = 0.70
	var shadow := accent.darkened(0.12)
	shadow.a = 0.32
	var badge := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.86),
		center + Vector2(radius * 0.56, -radius * 0.50),
		center + Vector2(radius * 0.68, radius * 0.20),
		center + Vector2(0.0, radius * 0.78),
		center + Vector2(-radius * 0.68, radius * 0.20),
		center + Vector2(-radius * 0.56, -radius * 0.50),
	])
	draw_colored_polygon(badge, shadow)
	draw_polyline(badge, trim, 1.6, true)
	draw_circle(center, radius * 0.34, core)
	draw_arc(center, radius * 0.48, -PI * 0.20, PI * 1.20, 64, trim, 2.0, true)
	for i in range(5):
		var angle := -PI * 0.78 + float(i) * PI * 0.39
		var outer := center + Vector2(cos(angle), sin(angle)) * radius * 0.78
		var inner := center + Vector2(cos(angle), sin(angle)) * radius * 0.42
		draw_line(inner, outer, core, 2.0, true)
		draw_circle(outer, radius * 0.075, trim)
	var visor := Rect2(center + Vector2(-radius * 0.32, -radius * 0.10), Vector2(radius * 0.64, radius * 0.20))
	draw_rect(visor, Color("#0f172a"), true)
	draw_rect(visor, trim, false, 1.2)
	_draw_role_variant_marks(center, radius, _name_seed() % 8)


func _draw_role_variant_marks(center: Vector2, radius: float, variant: int) -> void:
	var color := accent.lightened(0.42)
	color.a = 0.72
	var soft := accent.lightened(0.22)
	soft.a = 0.34
	match variant:
		0:
			for i in range(3):
				var y := center.y - radius * 0.44 + float(i) * radius * 0.24
				draw_line(center + Vector2(-radius * 0.72, y), center + Vector2(radius * 0.72, y + radius * 0.12), color, 1.5, true)
		1:
			for i in range(3):
				draw_arc(center, radius * (0.48 + float(i) * 0.12), -PI * 0.12, PI * 1.12, 48, color, 1.4, true)
		2:
			for i in range(4):
				var angle := float(i) * TAU / 4.0 + PI * 0.25
				var p := center + Vector2(cos(angle), sin(angle)) * radius * 0.58
				draw_circle(p, radius * 0.09, soft)
				draw_line(center, p, color, 1.2, true)
		3:
			var crown := PackedVector2Array([
				center + Vector2(-radius * 0.52, -radius * 0.36),
				center + Vector2(-radius * 0.22, -radius * 0.68),
				center + Vector2(0.0, -radius * 0.36),
				center + Vector2(radius * 0.22, -radius * 0.68),
				center + Vector2(radius * 0.52, -radius * 0.36),
			])
			draw_polyline(crown, color, 2.0, false)
		4:
			for i in range(5):
				var x := center.x - radius * 0.52 + float(i) * radius * 0.26
				draw_rect(Rect2(Vector2(x, center.y + radius * 0.34), Vector2(radius * 0.10, radius * 0.28 + float(i % 2) * radius * 0.10)), soft, true)
		5:
			for i in range(3):
				var p := center + Vector2(float(i - 1) * radius * 0.34, -radius * 0.52)
				draw_circle(p, radius * 0.075, color)
				draw_line(p, p + Vector2(radius * 0.18, radius * 0.30), color, 1.4, true)
		6:
			draw_arc(center + Vector2(0.0, radius * 0.18), radius * 0.62, PI * 1.04, PI * 1.96, 42, color, 2.0, true)
			draw_arc(center + Vector2(0.0, radius * 0.18), radius * 0.42, PI * 1.08, PI * 1.92, 42, color, 1.5, true)
		_:
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -radius * 0.62),
				center + Vector2(radius * 0.34, -radius * 0.20),
				center + Vector2(0.0, radius * 0.22),
				center + Vector2(-radius * 0.34, -radius * 0.20),
			])
			draw_polyline(diamond, color, 1.8, true)


func _draw_monster_card_motif(center: Vector2, radius: float) -> void:
	var identity := "%s %s" % [card_name, card_tags]
	if _contains_any(identity, ["飞", "空", "翼", "流星", "蓝锋", "星焰"]):
		_draw_motion_motif(center, radius)
		_draw_wing_marks(center, radius)
		return
	if _contains_any(identity, ["海", "水", "深", "潮", "菌", "尸套", "瘴", "腐"]):
		_draw_wave_motif(center, radius)
		_draw_miasma_motif(center + Vector2(radius * 0.10, -radius * 0.08), radius * 0.70)
		return
	if _contains_any(identity, ["甲", "铠", "盾", "壳", "机甲", "哨兵", "装甲"]):
		_draw_shield_motif(center, radius)
		_draw_claw_motif(center + Vector2(radius * 0.06, 0.0), radius * 0.78)
		return
	if _contains_any(identity, ["火", "焰", "热", "熔", "光线"]):
		_draw_flare_motif(center, radius)
		_draw_claw_motif(center, radius * 0.72)
		return
	if _contains_any(identity, ["地", "钻", "潜", "砂", "岩"]):
		_draw_crack_motif(center, radius)
		_draw_motion_motif(center + Vector2(0.0, radius * 0.12), radius * 0.66)
		return
	_draw_claw_motif(center, radius)


func _draw_wing_marks(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.34)
	color.a = 0.48
	for side in [-1, 1]:
		var inner := center + Vector2(float(side) * radius * 0.10, -radius * 0.06)
		var outer := center + Vector2(float(side) * radius * 0.78, -radius * 0.48)
		var tip := center + Vector2(float(side) * radius * 0.52, radius * 0.24)
		draw_polyline(PackedVector2Array([inner, outer, tip, inner]), color, 2.0, true)


func _draw_flare_motif(center: Vector2, radius: float) -> void:
	var flame := accent.lightened(0.30)
	flame.a = 0.46
	for i in range(8):
		var angle := float(i) * TAU / 8.0
		var inner := center + Vector2(cos(angle), sin(angle)) * radius * 0.22
		var outer := center + Vector2(cos(angle), sin(angle)) * radius * (0.58 + float(i % 2) * 0.18)
		draw_line(inner, outer, flame, 2.4, true)
	draw_circle(center, radius * 0.28, flame)


func _draw_coin_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.25)
	color.a = 0.50
	for i in range(3):
		draw_circle(center + Vector2(float(i - 1) * radius * 0.34, radius * 0.18), radius * 0.34, color)
		draw_arc(center + Vector2(float(i - 1) * radius * 0.34, radius * 0.18), radius * 0.34, 0.0, TAU, 48, Color("#fff7ed"), 1.0, true)


func _draw_city_motif(center: Vector2, radius: float) -> void:
	var body := accent.lightened(0.08)
	body.a = 0.48
	var light := Color("#a5f3fc")
	light.a = 0.72
	var widths := [radius * 0.34, radius * 0.42, radius * 0.30]
	var heights := [radius * 0.82, radius * 1.18, radius * 0.96]
	var offsets := [-radius * 0.48, -radius * 0.12, radius * 0.34]
	for i in range(widths.size()):
		var rect := Rect2(
			center + Vector2(float(offsets[i]), radius * 0.58 - float(heights[i])),
			Vector2(float(widths[i]), float(heights[i]))
		)
		draw_rect(rect, body.lightened(float(i) * 0.05), true)
		for row in range(3):
			draw_rect(Rect2(rect.position + Vector2(4.0, 7.0 + row * 8.0), Vector2(max(2.0, rect.size.x - 8.0), 2.0)), light, true)
	draw_line(center + Vector2(-radius * 0.75, radius * 0.60), center + Vector2(radius * 0.75, radius * 0.60), light, 2.0, true)


func _draw_market_chart_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.26)
	color.a = 0.54
	var axis := Color("#fffbeb")
	axis.a = 0.62
	var origin := center + Vector2(-radius * 0.70, radius * 0.58)
	draw_line(origin, origin + Vector2(radius * 1.38, 0.0), axis, 1.8, true)
	draw_line(origin, origin + Vector2(0.0, -radius * 1.20), axis, 1.8, true)
	var points := [
		origin + Vector2(radius * 0.08, -radius * 0.22),
		origin + Vector2(radius * 0.34, -radius * 0.46),
		origin + Vector2(radius * 0.62, -radius * 0.32),
		origin + Vector2(radius * 0.88, -radius * 0.78),
		origin + Vector2(radius * 1.16, -radius * 0.66),
	]
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, 3.0, true)
	for point in points:
		draw_circle(point, radius * 0.055, Color("#fef3c7"))


func _draw_route_motif(center: Vector2, radius: float, broken: bool) -> void:
	var color := accent.lightened(0.24)
	color.a = 0.54
	var points := [
		center + Vector2(-radius * 0.72, radius * 0.34),
		center + Vector2(-radius * 0.32, -radius * 0.38),
		center + Vector2(radius * 0.18, radius * 0.08),
		center + Vector2(radius * 0.68, -radius * 0.50),
	]
	for i in range(points.size() - 1):
		if broken and i == 1:
			draw_line(points[i], points[i].lerp(points[i + 1], 0.38), color, 2.8, true)
			draw_line(points[i].lerp(points[i + 1], 0.66), points[i + 1], color, 2.8, true)
		else:
			draw_line(points[i], points[i + 1], color, 2.8, true)
	for point in points:
		draw_circle(point, radius * 0.10, Color("#e0f2fe"))
	if broken:
		var cut := center + Vector2(-radius * 0.02, -radius * 0.12)
		draw_line(cut + Vector2(-radius * 0.18, -radius * 0.18), cut + Vector2(radius * 0.18, radius * 0.18), Color("#fecaca"), 3.2, true)
		draw_line(cut + Vector2(-radius * 0.18, radius * 0.18), cut + Vector2(radius * 0.18, -radius * 0.18), Color("#fecaca"), 3.2, true)


func _draw_product_crate_motif(center: Vector2, radius: float) -> void:
	var body := accent.lightened(0.18)
	body.a = 0.48
	var edge := Color("#fef9c3")
	edge.a = 0.68
	var crate := Rect2(center - Vector2(radius * 0.54, radius * 0.30), Vector2(radius * 1.08, radius * 0.74))
	draw_rect(crate, body, true)
	draw_rect(crate, edge, false, 1.6)
	draw_line(crate.position + Vector2(crate.size.x * 0.5, 0.0), crate.position + Vector2(crate.size.x * 0.5, crate.size.y), edge, 1.4, true)
	draw_line(crate.position + Vector2(0.0, crate.size.y * 0.52), crate.position + Vector2(crate.size.x, crate.size.y * 0.52), edge, 1.4, true)
	var fruit := center + Vector2(0.0, -radius * 0.48)
	draw_circle(fruit, radius * 0.20, body.lightened(0.18))
	draw_line(fruit + Vector2(radius * 0.02, -radius * 0.18), fruit + Vector2(radius * 0.14, -radius * 0.34), edge, 1.8, true)
	draw_circle(fruit + Vector2(radius * 0.18, -radius * 0.30), radius * 0.055, edge)


func _draw_signal_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.30)
	color.a = 0.46
	for i in range(4):
		draw_arc(center, radius * (0.45 + float(i) * 0.22), -PI * 0.82, -PI * 0.18, 32, color, 2.0, true)
		draw_arc(center, radius * (0.45 + float(i) * 0.22), PI * 0.18, PI * 0.82, 32, color, 2.0, true)


func _draw_motion_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.28)
	color.a = 0.52
	for i in range(3):
		var offset := float(i - 1) * radius * 0.24
		var from := center + Vector2(-radius * 0.78, radius * 0.44 + offset)
		var to := center + Vector2(radius * 0.72, -radius * 0.48 + offset)
		draw_line(from, to, color, 2.4, true)
		draw_line(to, to + Vector2(-radius * 0.24, -radius * 0.04), color, 2.4, true)
		draw_line(to, to + Vector2(-radius * 0.07, radius * 0.24), color, 2.4, true)


func _draw_claw_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.28)
	color.a = 0.55
	for i in range(4):
		var offset := float(i) * radius * 0.22
		draw_line(center + Vector2(-radius * 0.58 + offset, -radius * 0.58), center + Vector2(-radius * 0.18 + offset, radius * 0.62), color, 3.0, true)


func _draw_crack_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.24)
	color.a = 0.58
	var points := [
		center + Vector2(-radius * 0.65, -radius * 0.50),
		center + Vector2(-radius * 0.22, -radius * 0.08),
		center + Vector2(-radius * 0.40, radius * 0.28),
		center + Vector2(radius * 0.08, radius * 0.02),
		center + Vector2(radius * 0.44, radius * 0.54),
	]
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, 3.0, true)
	draw_line(points[1], center + Vector2(radius * 0.52, -radius * 0.40), color, 2.0, true)
	draw_line(points[3], center + Vector2(radius * 0.70, radius * 0.12), color, 2.0, true)


func _draw_miasma_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.22)
	color.a = 0.36
	for i in range(6):
		var angle := float(i) / 6.0 * TAU
		var pos := center + Vector2(cos(angle), sin(angle)) * radius * (0.24 + float(i % 3) * 0.14)
		draw_circle(pos, radius * (0.20 + float(i % 2) * 0.05), color)


func _draw_shield_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.28)
	color.a = 0.44
	var shield := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.76),
		center + Vector2(radius * 0.58, -radius * 0.40),
		center + Vector2(radius * 0.44, radius * 0.36),
		center + Vector2(0.0, radius * 0.76),
		center + Vector2(-radius * 0.44, radius * 0.36),
		center + Vector2(-radius * 0.58, -radius * 0.40),
	])
	draw_colored_polygon(shield, color)
	draw_polyline(shield, Color("#e0f2fe"), 1.2, true)


func _draw_wave_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.30)
	color.a = 0.50
	for i in range(4):
		var y := center.y - radius * 0.42 + float(i) * radius * 0.28
		var last := Vector2(center.x - radius * 0.70, y)
		for step in range(1, 16):
			var x := center.x - radius * 0.70 + radius * 1.40 * float(step) / 15.0
			var p := Vector2(x, y + sin(float(step) * 0.9 + float(i)) * radius * 0.08)
			draw_line(last, p, color, 2.0, true)
			last = p


func _draw_supply_motif(center: Vector2, radius: float) -> void:
	var color := accent.lightened(0.24)
	color.a = 0.46
	var box_size := Vector2(radius * 0.52, radius * 0.38)
	for i in range(3):
		var offset := Vector2(float(i - 1) * radius * 0.36, float(i % 2) * radius * 0.22)
		var rect := Rect2(center - box_size * 0.5 + offset, box_size)
		draw_rect(rect, color, true)
		draw_rect(rect, Color("#ccfbf1"), false, 1.2)


func _draw_rank_marks(rect: Rect2) -> void:
	if card_kind == "player_role":
		var role_color := accent.lightened(0.45)
		role_color.a = 0.86
		draw_string(get_theme_default_font(), Vector2(8.0, 17.0), "身份", HORIZONTAL_ALIGNMENT_LEFT, 52.0, 12, role_color)
		return
	var marks: int = clamp(card_rank, 1, 4)
	var color := accent.lightened(0.45)
	color.a = 0.86
	for i in range(marks):
		var x := rect.size.x - 14.0 - float(i) * 12.0
		draw_circle(Vector2(x, 13.0), 3.2, color)
	var font := get_theme_default_font()
	var roman := _roman_rank(card_rank)
	draw_string(font, Vector2(8.0, 17.0), roman, HORIZONTAL_ALIGNMENT_LEFT, 52.0, 12, color)


func _draw_border(rect: Rect2) -> void:
	var border := accent.lightened(0.10)
	border.a = 0.88
	draw_rect(Rect2(Vector2.ZERO, rect.size), border, false, 2.0)
	var inner := accent.darkened(0.20)
	inner.a = 0.52
	draw_rect(Rect2(Vector2(5, 5), rect.size - Vector2(10, 10)), inner, false, 1.0)


func _draw_glyph(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var font_size := 34 if compact else 46
	var glyph := _glyph_for_kind()
	var shadow := Color("#020617")
	shadow.a = 0.82
	var baseline_y := rect.size.y * (0.55 if compact else 0.57)
	draw_string(font, Vector2(2.0, baseline_y + 2.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, shadow)
	draw_string(font, Vector2(0.0, baseline_y), glyph, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color("#f8fafc"))


func _draw_caption(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var name_size := 11 if compact else 13
	var tag_size := 8 if compact else 10
	var title := _short_text(card_name, 9 if compact else 12)
	var tag_text := _short_text(card_tags, 12 if compact else 18)
	var name_color := Color("#e0f2fe")
	var tag_color := accent.lightened(0.38)
	if card_stats != "":
		var stats_color := Color("#fef3c7")
		stats_color.a = 0.94
		draw_string(
			font,
			Vector2(0.0, rect.size.y - (31.0 if compact else 38.0)),
			_short_text(card_stats, 23 if compact else 30),
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			8 if compact else 9,
			stats_color
		)
	draw_string(font, Vector2(0.0, rect.size.y - (18.0 if compact else 22.0)), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, name_size, name_color)
	draw_string(font, Vector2(0.0, rect.size.y - 7.0), tag_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, tag_size, tag_color)


func _glyph_for_kind() -> String:
	match card_kind:
		"player_role":
			return "角"
		"monster_card":
			return "兽"
		"monster_bound_action":
			return "技"
		"monster_takeover":
			return "夺"
		"city_revenue_boost":
			return "城"
		"cash_gain":
			return "¥"
		"product_speculation":
			return "价"
		"market_stabilize":
			return "稳"
		"route_insurance":
			return "航"
		"route_sabotage":
			return "断"
		"city_product_upgrade":
			return "升"
		"city_product_shift":
			return "换"
		"city_demand_shift":
			return "需"
		"panic_shift":
			return "热"
		"move":
			return "移"
		"fly":
			return "飞"
		"burrow":
			return "潜"
		"attack":
			return "爪"
		"charge_attack", "roll_attack":
			return "撞"
		"area_damage":
			return "裂"
		"mudslide":
			return "砂"
		"miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath":
			return "瘴"
		"armor_gain", "guard":
			return "盾"
		"control_gain":
			return "令"
		"special_monster_delay", "roar":
			return "扰"
		"supply_draw":
			return "补"
	return "卡"


func _roman_rank(rank: int) -> String:
	match clamp(rank, 1, 4):
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
	return "I"


func _short_text(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.left(max(1, max_len - 1)) + "…"


func _contains_any(text: String, needles: Array) -> bool:
	for needle_variant in needles:
		if text.find(String(needle_variant)) >= 0:
			return true
	return false


func _name_seed() -> int:
	var seed := 131 + card_rank * 97 + card_kind.length() * 53
	for i in range(card_name.length()):
		seed = (seed * 33 + card_name.unicode_at(i)) % 1000003
	return max(1, seed)
