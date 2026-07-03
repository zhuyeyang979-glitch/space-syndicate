extends Control

const STAR_COUNT_FULL := 30
const STAR_COUNT_COMPACT := 18
const CARD_ART_EXTERNAL_THEME := "night-patrol-frame-panel-sigil-v2"
const NIGHT_PATROL_SIGIL_PATH := "res://assets/third_party/night_patrol/ui/card-sigil.svg"
const NIGHT_PATROL_PANEL_PATH := "res://assets/third_party/night_patrol/ui/panel-talisman.png"
const NIGHT_PATROL_BUTTON_RED_PATH := "res://assets/third_party/night_patrol/ui/button-red.png"
const NIGHT_PATROL_BUTTON_BLUE_PATH := "res://assets/third_party/night_patrol/ui/button-blue.png"
const MOTH_KAIJUICE_SPRITE_THEME := "multi-source-open-card-illustrations-v2"
const MOTH_KAIJUICE_KAIJU_PATH := "res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc.png"
const MOTH_KAIJUICE_ATFIELD_PATH := "res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_atfield.png"
const MOTH_KAIJUICE_LASER_PATH := "res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_laser.png"
const MOTH_KAIJUICE_MECH_PATH := "res://assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_mech.png"
const MOTH_KAIJUICE_TANK_PATH := "res://assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_tank.png"
const MOTH_KAIJUICE_SOLDIER_PATH := "res://assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_soldier.png"
const MOTH_KAIJUICE_BUILDING_M_PATH := "res://assets/third_party/moth_kaijuice/city/buildings/mothkaiju_bldg_m.png"
const MOTH_KAIJUICE_BUILDING_S_PATH := "res://assets/third_party/moth_kaijuice/city/buildings/mothkaiju_bldg_s.png"
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
const GAME_ICON_BANK_PATH := "res://assets/third_party/game_icons_ccby/bank.svg"
const GAME_ICON_PROFIT_PATH := "res://assets/third_party/game_icons_ccby/profit.svg"
const GAME_ICON_FALL_DOWN_PATH := "res://assets/third_party/game_icons_ccby/fall_down.svg"
const GAME_ICON_CONTRACT_PATH := "res://assets/third_party/game_icons_ccby/contract.svg"
const GAME_ICON_BREAKING_CHAIN_PATH := "res://assets/third_party/game_icons_ccby/breaking_chain.svg"
const GAME_ICON_ROBBER_HAND_PATH := "res://assets/third_party/game_icons_ccby/robber_hand.svg"
const GAME_ICON_CANCEL_PATH := "res://assets/third_party/game_icons_ccby/cancel.svg"
const GAME_ICON_WAREHOUSE_PATH := "res://assets/third_party/game_icons_ccby/warehouse.svg"
const GAME_ICON_SHAKING_HANDS_PATH := "res://assets/third_party/game_icons_ccby/shaking_hands.svg"
const GAME_ICON_COINS_PILE_PATH := "res://assets/third_party/game_icons_ccby/coins_pile.svg"
const NIGHT_PATROL_FRAME_PATHS := {
	"monster_card": "res://assets/third_party/night_patrol/ui/card-frame-attack.png",
	"military_force": "res://assets/third_party/night_patrol/ui/card-frame-attack.png",
	"military_command": "res://assets/third_party/night_patrol/ui/card-frame-attack.png",
	"card_counter": "res://assets/third_party/night_patrol/ui/card-frame-skill.png",
	"area_trade_contract": "res://assets/third_party/night_patrol/ui/card-frame-power.png",
	"city_contract_boon": "res://assets/third_party/night_patrol/ui/card-frame-power.png",
	"product_contract_boon": "res://assets/third_party/night_patrol/ui/card-frame-power.png",
	"city_gdp_derivative": "res://assets/third_party/night_patrol/ui/card-frame-status.png",
	"product_futures": "res://assets/third_party/night_patrol/ui/card-frame-status.png",
}
const NIGHT_PATROL_DEFAULT_FRAME_PATH := "res://assets/third_party/night_patrol/ui/card-frame-skill.png"

var card_name := ""
var card_kind := ""
var card_tags := ""
var accent := Color("#94a3b8")
var card_rank := 1
var compact := false
var card_stats := ""
var night_patrol_sigil_texture: Texture2D
var night_patrol_panel_texture: Texture2D
var night_patrol_button_red_texture: Texture2D
var night_patrol_button_blue_texture: Texture2D
var night_patrol_frame_textures := {}
var night_patrol_default_frame_texture: Texture2D
var moth_kaijuice_textures := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("card_art_external_asset_theme", CARD_ART_EXTERNAL_THEME)
	set_meta("card_art_open_source_sprite_theme", MOTH_KAIJUICE_SPRITE_THEME)
	night_patrol_sigil_texture = _load_optional_texture(NIGHT_PATROL_SIGIL_PATH)
	night_patrol_panel_texture = _load_optional_texture(NIGHT_PATROL_PANEL_PATH)
	night_patrol_button_red_texture = _load_optional_texture(NIGHT_PATROL_BUTTON_RED_PATH)
	night_patrol_button_blue_texture = _load_optional_texture(NIGHT_PATROL_BUTTON_BLUE_PATH)
	night_patrol_default_frame_texture = _load_optional_texture(NIGHT_PATROL_DEFAULT_FRAME_PATH)
	for kind_variant in NIGHT_PATROL_FRAME_PATHS.keys():
		var kind := String(kind_variant)
		night_patrol_frame_textures[kind] = _load_optional_texture(String(NIGHT_PATROL_FRAME_PATHS[kind]))
	moth_kaijuice_textures = {
		"kaiju": _load_optional_texture(MOTH_KAIJUICE_KAIJU_PATH),
		"atfield": _load_optional_texture(MOTH_KAIJUICE_ATFIELD_PATH),
		"laser": _load_optional_texture(MOTH_KAIJUICE_LASER_PATH),
		"mech": _load_optional_texture(MOTH_KAIJUICE_MECH_PATH),
		"tank": _load_optional_texture(MOTH_KAIJUICE_TANK_PATH),
		"soldier": _load_optional_texture(MOTH_KAIJUICE_SOLDIER_PATH),
		"building_m": _load_optional_texture(MOTH_KAIJUICE_BUILDING_M_PATH),
		"building_s": _load_optional_texture(MOTH_KAIJUICE_BUILDING_S_PATH),
		"moth_kaijuice_kaiju": _load_optional_texture(MOTH_KAIJUICE_KAIJU_PATH),
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
		"game_icon_bank": _load_optional_texture(GAME_ICON_BANK_PATH),
		"game_icon_profit": _load_optional_texture(GAME_ICON_PROFIT_PATH),
		"game_icon_fall_down": _load_optional_texture(GAME_ICON_FALL_DOWN_PATH),
		"game_icon_contract": _load_optional_texture(GAME_ICON_CONTRACT_PATH),
		"game_icon_breaking_chain": _load_optional_texture(GAME_ICON_BREAKING_CHAIN_PATH),
		"game_icon_robber_hand": _load_optional_texture(GAME_ICON_ROBBER_HAND_PATH),
		"game_icon_cancel": _load_optional_texture(GAME_ICON_CANCEL_PATH),
		"game_icon_warehouse": _load_optional_texture(GAME_ICON_WAREHOUSE_PATH),
		"game_icon_shaking_hands": _load_optional_texture(GAME_ICON_SHAKING_HANDS_PATH),
		"game_icon_coins_pile": _load_optional_texture(GAME_ICON_COINS_PILE_PATH),
	}


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
	_draw_night_patrol_reference_backplate(rect)
	_draw_energy_wash(rect)
	_draw_starfield(rect)
	_draw_night_patrol_reference_frame(rect)
	_draw_night_patrol_reference_strips(rect)
	_draw_moth_kaijuice_reference_illustration(rect)
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
		"card_counter", "player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage":
			_draw_signal_motif(center, radius)
		"cash_gain":
			_draw_coin_motif(center, radius)
		"city_revenue_boost":
			_draw_city_motif(center, radius)
		"city_gdp_derivative", "product_futures", "product_speculation", "market_stabilize":
			_draw_market_chart_motif(center, radius)
		"area_trade_contract", "city_contract_boon", "product_contract_boon", "route_insurance":
			_draw_route_motif(center, radius, false)
		"route_sabotage":
			_draw_route_motif(center, radius, true)
		"city_product_upgrade", "city_product_shift", "city_demand_shift", "product_growth_boon", "region_economy_shift":
			_draw_product_crate_motif(center, radius)
		"route_flow_boon":
			_draw_motion_motif(center, radius)
			_draw_route_motif(center, radius * 0.74, false)
		"intel_city_reveal", "intel_card_trace", "intel_contract_trace", "card_access_boon":
			_draw_signal_motif(center, radius)
			_draw_supply_motif(center + Vector2(radius * 0.08, radius * 0.10), radius * 0.62)
		"news_event", "weather_control":
			_draw_signal_motif(center, radius)
			_draw_wave_motif(center + Vector2(0.0, radius * 0.12), radius * 0.72)
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
	_draw_night_patrol_sigil(center, radius)


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


func _night_patrol_frame_texture_for_kind() -> Texture2D:
	var texture := night_patrol_frame_textures.get(card_kind, null) as Texture2D
	if texture != null:
		return texture
	if card_kind.contains("attack") or card_kind.contains("damage") or card_tags.contains("战斗"):
		texture = night_patrol_frame_textures.get("monster_card", null) as Texture2D
		if texture != null:
			return texture
	if card_tags.contains("经济") or card_tags.contains("期货") or card_tags.contains("GDP"):
		texture = night_patrol_frame_textures.get("city_gdp_derivative", null) as Texture2D
		if texture != null:
			return texture
	return night_patrol_default_frame_texture


func _draw_night_patrol_reference_frame(rect: Rect2) -> void:
	var texture: Texture2D = _night_patrol_frame_texture_for_kind()
	if texture == null:
		return
	var tint := Color(1.0, 1.0, 1.0, 0.56 if compact else 0.68)
	draw_texture_rect(texture, rect.grow(-2.0), false, tint)


func _draw_night_patrol_reference_backplate(rect: Rect2) -> void:
	if night_patrol_panel_texture == null:
		return
	var inset_x: float = max(3.0, rect.size.x * 0.08)
	var inset_y: float = max(3.0, rect.size.y * 0.06)
	var panel_rect := Rect2(Vector2(inset_x, inset_y), Vector2(max(1.0, rect.size.x - inset_x * 2.0), max(1.0, rect.size.y - inset_y * 2.0)))
	var tint := Color(1.0, 1.0, 1.0, 0.30 if compact else 0.38)
	tint = tint.lerp(accent.lightened(0.12), 0.16)
	draw_texture_rect(night_patrol_panel_texture, panel_rect, false, tint)


func _draw_night_patrol_reference_strips(rect: Rect2) -> void:
	var texture: Texture2D = _night_patrol_strip_texture()
	if texture == null:
		return
	var strip_height: float = max(7.0, rect.size.y * (0.095 if compact else 0.085))
	var top_rect := Rect2(Vector2(rect.size.x * 0.08, rect.size.y * 0.055), Vector2(rect.size.x * 0.84, strip_height))
	var bottom_rect := Rect2(Vector2(rect.size.x * 0.08, rect.size.y - strip_height - rect.size.y * 0.055), Vector2(rect.size.x * 0.84, strip_height))
	var tint := Color(1.0, 1.0, 1.0, 0.24 if compact else 0.30)
	draw_texture_rect(texture, top_rect, false, tint)
	draw_texture_rect(texture, bottom_rect, false, tint)


func _night_patrol_strip_texture() -> Texture2D:
	var label_source := "%s｜%s｜%s" % [card_kind, card_tags, card_stats]
	if label_source.contains("怪兽") or label_source.contains("战斗") or label_source.contains("军队") or label_source.contains("attack") or label_source.contains("damage") or card_kind.contains("monster") or card_kind.contains("military"):
		return night_patrol_button_red_texture
	return night_patrol_button_blue_texture


func _draw_night_patrol_sigil(center: Vector2, radius: float) -> void:
	if night_patrol_sigil_texture == null:
		return
	var icon_size := radius * (1.12 if compact else 1.28)
	var tint := accent.lightened(0.38)
	tint.a = 0.26 if compact else 0.34
	draw_texture_rect(night_patrol_sigil_texture, Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), false, tint)


func card_visual_profile_snapshot() -> Dictionary:
	var seed := _name_seed()
	var sprite_key := _moth_kaijuice_card_sprite_key()
	return {
		"theme": MOTH_KAIJUICE_SPRITE_THEME,
		"visual_source_id": _card_visual_source_id(sprite_key),
		"sprite_key": sprite_key,
		"sprite_cell": _moth_kaijuice_card_sprite_cell(sprite_key),
		"layout_variant": seed % 9,
		"palette_variant": int(seed / 7) % 11,
		"effect_variant": int(seed / 13) % 9,
		"composition_variant": int(seed / 17) % 37,
		"motif_family": _card_motif_family_key(),
		"first_run_art_focus": _first_run_art_focus_key(),
		"illustration_anchor": _card_illustration_anchor_key(),
	}


func card_visual_profile_key() -> String:
	var profile := card_visual_profile_snapshot()
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(profile.get("visual_source_id", "")),
		str(profile.get("sprite_key", "")),
		str(profile.get("sprite_cell", "")),
		str(profile.get("layout_variant", "")),
		str(profile.get("palette_variant", "")),
		str(profile.get("effect_variant", "")),
		str(profile.get("composition_variant", "")),
		str(profile.get("motif_family", "")),
		str(profile.get("first_run_art_focus", "")),
		str(profile.get("illustration_anchor", "")),
	]


func _draw_moth_kaijuice_reference_illustration(rect: Rect2) -> void:
	var profile := card_visual_profile_snapshot()
	var sprite_key := String(profile.get("sprite_key", ""))
	var texture := moth_kaijuice_textures.get(sprite_key, null) as Texture2D
	if texture == null:
		return
	var seed := _name_seed()
	var art_rect := Rect2(
		Vector2(rect.size.x * 0.18, rect.size.y * (0.22 if compact else 0.20)),
		Vector2(rect.size.x * 0.64, rect.size.y * (0.44 if compact else 0.48))
	)
	var plate := Color("#020617").lerp(accent, 0.22)
	plate.a = 0.48 if compact else 0.56
	draw_rect(art_rect.grow(2.0), plate, true)
	var rim := accent.lightened(0.26)
	rim.a = 0.34 if compact else 0.46
	draw_rect(art_rect.grow(2.0), rim, false, 1.4)

	var scale := 0.78 + float(seed % 5) * 0.045
	var offset := Vector2(float((seed % 7) - 3) * art_rect.size.x * 0.025, float((int(seed / 11) % 5) - 2) * art_rect.size.y * 0.025)
	var sprite_rect := Rect2(Vector2.ZERO, art_rect.size * scale)
	sprite_rect.position = art_rect.position + (art_rect.size - sprite_rect.size) * 0.5 + offset
	var tint := Color(1.0, 1.0, 1.0, 0.74 if compact else 0.86)
	tint = tint.lerp(accent.lightened(0.18), 0.08 + float(seed % 3) * 0.035)
	var src_rect := _moth_kaijuice_card_sprite_region(sprite_key)
	sprite_rect.size = _fit_size_inside(sprite_rect.size, src_rect.size)
	sprite_rect.position = art_rect.position + (art_rect.size - sprite_rect.size) * 0.5 + offset
	draw_texture_rect_region(texture, sprite_rect, src_rect, tint)
	_draw_card_illustration_anchor(art_rect, String(profile.get("illustration_anchor", "")), seed)
	_draw_first_run_focus_overlay(art_rect, String(profile.get("first_run_art_focus", "")), seed)

	if str(profile.get("effect_variant", "")) in ["2", "5", "8"] or _contains_any("%s｜%s" % [card_kind, card_tags], ["光线", "攻击", "破坏", "齐射"]):
		_draw_moth_kaijuice_laser_accent(art_rect, seed)
	if _contains_any("%s｜%s" % [card_kind, card_tags], ["格挡", "防御", "保险", "修复", "否决"]):
		_draw_moth_kaijuice_field_accent(art_rect, seed)


func _draw_moth_kaijuice_laser_accent(art_rect: Rect2, seed: int) -> void:
	var texture := moth_kaijuice_textures.get("laser", null) as Texture2D
	if texture == null:
		return
	var h: float = max(3.0, art_rect.size.y * 0.07)
	var y: float = art_rect.position.y + art_rect.size.y * (0.30 + float(seed % 5) * 0.09)
	var src := Rect2(Vector2.ZERO, texture.get_size())
	var tint := accent.lightened(0.34)
	tint.a = 0.52 if compact else 0.66
	draw_texture_rect_region(texture, Rect2(Vector2(art_rect.position.x, y), Vector2(art_rect.size.x, h)), src, tint)


func _draw_moth_kaijuice_field_accent(art_rect: Rect2, seed: int) -> void:
	var texture := moth_kaijuice_textures.get("atfield", null) as Texture2D
	if texture == null:
		return
	var size_factor: float = 0.46 + float(seed % 4) * 0.04
	var field_size := Vector2(art_rect.size.x * size_factor, art_rect.size.y * size_factor)
	var field_rect := Rect2(art_rect.position + (art_rect.size - field_size) * 0.5, field_size)
	var tint := Color(1.0, 1.0, 1.0, 0.30 if compact else 0.42)
	draw_texture_rect_region(texture, field_rect, Rect2(Vector2.ZERO, texture.get_size()), tint)


func _first_run_art_focus_key() -> String:
	var identity := "%s｜%s｜%s｜%s" % [card_name, card_kind, card_tags, card_stats]
	if card_kind == "monster_card":
		return "monster_anchor"
	if _contains_any(identity, ["城市融资", "轨道融资", "红利"]):
		return "city_money"
	if _contains_any(identity, ["产业升级", "生产", "商品+1", "产品线"]):
		return "factory_upgrade"
	if _contains_any(identity, ["交通升级", "流通", "航线", "运输", "路线"]):
		return "transit_route"
	if _contains_any(identity, ["星际广告", "舆论", "广告", "新闻"]):
		return "broadcast"
	if _contains_any(identity, ["诱导电波", "挑衅", "诱导"]):
		return "lure_beacon"
	if _contains_any(identity, ["过载补给", "补给", "抽牌", "牌架"]):
		return "supply_cache"
	if _contains_any(identity, ["移动", "飞行", "潜行", "前进"]):
		return "movement_arrow"
	if _contains_any(identity, ["普攻", "冲锋", "甩尾", "齐射", "攻击", "光线", "射线", "炮"]):
		return "impact_attack"
	if _contains_any(identity, ["格挡", "护", "保险", "修复", "否决", "稳定"]):
		return "shield_guard"
	if _contains_any(identity, ["区域破坏", "泥石流", "破坏", "拆解", "冻结"]):
		return "district_crack"
	if _contains_any(identity, ["合约", "契约"]):
		return "contract_link"
	if _contains_any(identity, ["情报", "追溯", "查", "线索", "锁定"]):
		return "intel_lens"
	if _contains_any(identity, ["期货", "买涨", "做空", "GDP", "套利"]):
		return "market_curve"
	return "route_mark"


func _card_illustration_anchor_key() -> String:
	var identity := "%s｜%s｜%s｜%s" % [card_name, card_kind, card_tags, card_stats]
	if card_kind == "monster_card":
		return "monster_body"
	if _contains_any(identity, ["城市融资", "轨道融资", "地下融资", "红利"]):
		return "finance_tower"
	if _contains_any(identity, ["产业升级", "产业", "生产扩张", "产能", "产品线"]):
		return "factory_core"
	if _contains_any(identity, ["交通升级", "星港快线", "航线", "运输", "流通", "航路"]):
		return "transit_grid"
	if _contains_any(identity, ["星际广告", "舆论", "广告", "新闻", "热搜", "快讯", "传闻", "播报"]):
		return "broadcast_array"
	if _contains_any(identity, ["诱导电波", "挑衅", "诱导"]):
		return "lure_beacon"
	if _contains_any(identity, ["过载补给", "连锁过载", "补给", "抽牌", "牌架"]):
		return "supply_cache"
	if _contains_any(identity, ["移动", "飞行", "潜行", "前进"]):
		return "motion_vector"
	if _contains_any(identity, ["普攻", "冲锋", "甩尾", "攻击", "光线", "射线", "炮", "齐射"]):
		return "impact_core"
	if _contains_any(identity, ["格挡", "护", "保险", "修复", "稳定"]):
		if _contains_any(identity, ["航线", "供应链", "商路", "路线"]):
			return "shield_route"
		return "shield_gate"
	if _contains_any(identity, ["区域破坏", "破碎地脉", "破坏", "泥石流"]):
		return "fracture_map"
	if _contains_any(identity, ["星链拆解", "拆解", "黑客"]):
		return "link_breaker"
	if _contains_any(identity, ["影仓牵引", "牵引", "牵牌"]):
		return "hand_pull"
	if _contains_any(identity, ["业主透镜", "出牌追帧", "回溯", "情报", "追溯", "查", "线索"]):
		return "intel_lens"
	if _contains_any(identity, ["商品看涨", "城市买涨", "买涨"]):
		return "market_up"
	if _contains_any(identity, ["商品看跌", "商品做空", "城市做空", "做空"]):
		return "market_down"
	if _contains_any(identity, ["港仓囤货", "仓", "囤货"]):
		return "warehouse_stack"
	if _contains_any(identity, ["合约", "契约", "专供", "撮合"]):
		return "contract_bridge"
	if _contains_any(identity, ["相位否决", "否决", "反制"]):
		return "phase_null"
	if _contains_any(identity, ["制空战斗机", "战斗机", "轰炸机", "空军"]):
		return "air_wing"
	if _contains_any(identity, ["星海战舰", "潜航舰队", "军舰", "舰队", "战舰", "潜航"]):
		return "naval_fleet"
	if _contains_any(identity, ["坦克", "导弹", "防卫军", "军队"]):
		return "ground_force"
	return _first_run_art_focus_key()


func _draw_card_illustration_anchor(art_rect: Rect2, anchor_key: String, seed: int) -> void:
	if anchor_key == "":
		return
	var color := accent.lightened(0.48)
	color.a = 0.48 if compact else 0.64
	var soft := accent.lightened(0.18)
	soft.a = 0.12 if compact else 0.20
	var center := art_rect.get_center()
	var radius: float = min(art_rect.size.x, art_rect.size.y) * 0.34
	match anchor_key:
		"finance_tower":
			_draw_anchor_finance_tower(center, radius, color, soft)
		"factory_core":
			_draw_anchor_factory_core(center, radius, color, soft)
		"transit_grid":
			_draw_anchor_transit_grid(art_rect, color, soft)
		"broadcast_array":
			_draw_anchor_broadcast_array(center, radius, color, soft)
		"lure_beacon":
			_draw_anchor_lure_beacon(center, radius, color, soft, seed)
		"supply_cache":
			_draw_anchor_supply_cache(center, radius, color, soft)
		"motion_vector":
			_draw_anchor_motion_vector(art_rect, color, soft)
		"impact_core":
			_draw_anchor_impact_core(center, radius, color, soft, seed)
		"shield_gate", "shield_route":
			_draw_anchor_shield_gate(center, radius, color, soft)
			if anchor_key == "shield_route":
				_draw_anchor_transit_grid(art_rect, color, soft)
		"fracture_map":
			_draw_anchor_fracture_map(art_rect, color, soft, seed)
		"intel_lens":
			_draw_anchor_intel_lens(center, radius, color, soft)
		"market_up":
			_draw_anchor_market_curve(art_rect, color, soft, true)
		"market_down":
			_draw_anchor_market_curve(art_rect, color, soft, false)
		"warehouse_stack":
			_draw_anchor_warehouse_stack(center, radius, color, soft)
		"contract_bridge":
			_draw_anchor_contract_bridge(center, radius, color, soft)
		"link_breaker":
			_draw_anchor_link_breaker(center, radius, color, soft)
		"hand_pull":
			_draw_anchor_hand_pull(center, radius, color, soft)
		"phase_null":
			_draw_anchor_phase_null(center, radius, color, soft)
		"air_wing":
			_draw_anchor_air_wing(center, radius, color, soft)
		"naval_fleet":
			_draw_anchor_naval_fleet(center, radius, color, soft)
		"ground_force":
			_draw_anchor_ground_force(center, radius, color, soft)
		"monster_body":
			_draw_focus_monster_anchor(center, radius, color, soft)
		_:
			_draw_focus_route_mark(art_rect, color, soft)


func _draw_anchor_finance_tower(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	for i in range(4):
		var h := radius * (0.42 + float(i) * 0.18)
		var w := radius * 0.22
		var x := center.x - radius * 0.56 + float(i) * radius * 0.30
		var r := Rect2(Vector2(x, center.y + radius * 0.42 - h), Vector2(w, h))
		draw_rect(r, soft, true)
		draw_rect(r, color, false, 1.6)
	draw_circle(center + Vector2(radius * 0.62, -radius * 0.46), radius * 0.18, color)
	draw_string(get_theme_default_font(), center + Vector2(radius * 0.51, -radius * 0.36), "¥", HORIZONTAL_ALIGNMENT_CENTER, radius * 0.22, 12 if compact else 16, Color("#020617"))


func _draw_anchor_factory_core(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	var body := Rect2(center + Vector2(-radius * 0.70, -radius * 0.12), Vector2(radius * 1.40, radius * 0.64))
	draw_rect(body, soft, true)
	draw_rect(body, color, false, 1.8)
	for i in range(3):
		var x := body.position.x + radius * (0.18 + float(i) * 0.38)
		draw_line(Vector2(x, body.position.y), Vector2(x + radius * 0.18, body.position.y - radius * 0.38), color, 2.2, true)
	draw_arc(center + Vector2(radius * 0.42, -radius * 0.08), radius * 0.28, 0.0, TAU, 32, color, 2.0, true)
	draw_circle(center + Vector2(radius * 0.42, -radius * 0.08), radius * 0.08, color)


func _draw_anchor_transit_grid(art_rect: Rect2, color: Color, soft: Color) -> void:
	var points := [
		art_rect.position + Vector2(art_rect.size.x * 0.16, art_rect.size.y * 0.70),
		art_rect.position + Vector2(art_rect.size.x * 0.38, art_rect.size.y * 0.36),
		art_rect.position + Vector2(art_rect.size.x * 0.64, art_rect.size.y * 0.58),
		art_rect.position + Vector2(art_rect.size.x * 0.86, art_rect.size.y * 0.28),
	]
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], soft, 8.0, true)
		draw_line(points[i], points[i + 1], color, 2.4, true)
	for p in points:
		draw_circle(p, 4.4, color)


func _draw_anchor_broadcast_array(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	draw_line(center + Vector2(0.0, radius * 0.54), center + Vector2(0.0, -radius * 0.34), color, 2.6, true)
	draw_line(center + Vector2(-radius * 0.36, radius * 0.54), center + Vector2(radius * 0.36, radius * 0.54), color, 2.0, true)
	for i in range(4):
		draw_arc(center + Vector2(0.0, -radius * 0.34), radius * (0.20 + float(i) * 0.18), -PI * 0.82, -PI * 0.18, 28, color if i < 2 else soft, 2.0, true)


func _draw_anchor_lure_beacon(center: Vector2, radius: float, color: Color, soft: Color, seed: int) -> void:
	draw_circle(center, radius * 0.16, color)
	for i in range(4):
		draw_arc(center, radius * (0.28 + float(i) * 0.16), 0.0, TAU, 48, color if i == seed % 4 else soft, 1.8, true)


func _draw_anchor_supply_cache(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	for i in range(4):
		var x := center.x + (float(i % 2) - 0.5) * radius * 0.56
		var y := center.y + (float(int(i / 2)) - 0.5) * radius * 0.42
		var box := Rect2(Vector2(x - radius * 0.18, y - radius * 0.14), Vector2(radius * 0.36, radius * 0.28))
		draw_rect(box, soft, true)
		draw_rect(box, color, false, 1.4)
	draw_line(center + Vector2(-radius * 0.08, -radius * 0.54), center + Vector2(-radius * 0.08, radius * 0.54), color, 2.0, true)
	draw_line(center + Vector2(-radius * 0.34, 0.0), center + Vector2(radius * 0.18, 0.0), color, 2.0, true)


func _draw_anchor_motion_vector(art_rect: Rect2, color: Color, soft: Color) -> void:
	var start := art_rect.position + Vector2(art_rect.size.x * 0.18, art_rect.size.y * 0.74)
	var end := art_rect.position + Vector2(art_rect.size.x * 0.78, art_rect.size.y * 0.24)
	draw_line(start, end, soft, 10.0, true)
	draw_line(start, end, color, 3.2, true)
	draw_line(end, end + Vector2(-art_rect.size.x * 0.18, art_rect.size.y * 0.02), color, 3.2, true)
	draw_line(end, end + Vector2(-art_rect.size.x * 0.05, art_rect.size.y * 0.17), color, 3.2, true)


func _draw_anchor_impact_core(center: Vector2, radius: float, color: Color, soft: Color, seed: int) -> void:
	draw_circle(center, radius * 0.18, color)
	for i in range(8):
		var angle := float(i) / 8.0 * TAU + float(seed % 9) * 0.02
		draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.25, center + Vector2(cos(angle), sin(angle)) * radius * 0.76, color if i % 2 == 0 else soft, 2.4, true)


func _draw_anchor_shield_gate(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	var shield := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.72),
		center + Vector2(radius * 0.58, -radius * 0.42),
		center + Vector2(radius * 0.42, radius * 0.32),
		center + Vector2(0.0, radius * 0.74),
		center + Vector2(-radius * 0.42, radius * 0.32),
		center + Vector2(-radius * 0.58, -radius * 0.42),
	])
	draw_colored_polygon(shield, soft)
	draw_polyline(shield, color, 2.0, true)


func _draw_anchor_fracture_map(art_rect: Rect2, color: Color, soft: Color, seed: int) -> void:
	var start := art_rect.position + Vector2(art_rect.size.x * 0.18, art_rect.size.y * 0.22)
	var p := start
	for i in range(6):
		var next := p + Vector2(art_rect.size.x * 0.10, art_rect.size.y * (0.08 + float((seed + i) % 3) * 0.04))
		draw_line(p, next, color if i % 2 == 0 else soft, 2.8, true)
		p = next + Vector2(art_rect.size.x * 0.02, -art_rect.size.y * 0.03)


func _draw_anchor_intel_lens(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	draw_circle(center + Vector2(-radius * 0.08, -radius * 0.10), radius * 0.34, soft)
	draw_arc(center + Vector2(-radius * 0.08, -radius * 0.10), radius * 0.34, 0.0, TAU, 48, color, 2.2, true)
	draw_line(center + Vector2(radius * 0.16, radius * 0.16), center + Vector2(radius * 0.62, radius * 0.62), color, 3.0, true)
	for i in range(3):
		draw_circle(center + Vector2(-radius * 0.28 + float(i) * radius * 0.20, -radius * 0.10), 2.2, color)


func _draw_anchor_market_curve(art_rect: Rect2, color: Color, soft: Color, upward: bool) -> void:
	var left := art_rect.position.x + art_rect.size.x * 0.14
	var bottom := art_rect.position.y + art_rect.size.y * (0.70 if upward else 0.36)
	var last := Vector2(left, bottom)
	for i in range(1, 7):
		var t := float(i) / 6.0
		var direction := -1.0 if upward else 1.0
		var y := bottom + direction * art_rect.size.y * (0.10 + 0.34 * t + 0.05 * sin(t * TAU))
		var p := Vector2(left + art_rect.size.x * 0.70 * t, y)
		draw_line(last, p, color if i % 2 == 1 else soft, 2.8, true)
		last = p
	var arrow_dir := -1.0 if upward else 1.0
	draw_line(last, last + Vector2(-art_rect.size.x * 0.10, art_rect.size.y * 0.03 * arrow_dir), color, 2.8, true)
	draw_line(last, last + Vector2(-art_rect.size.x * 0.03, art_rect.size.y * 0.12 * arrow_dir), color, 2.8, true)


func _draw_anchor_warehouse_stack(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	for i in range(3):
		var r := Rect2(center + Vector2(-radius * 0.54 + float(i) * radius * 0.28, radius * 0.22 - float(i) * radius * 0.22), Vector2(radius * 0.54, radius * 0.30))
		draw_rect(r, soft, true)
		draw_rect(r, color, false, 1.6)
	draw_line(center + Vector2(-radius * 0.62, radius * 0.58), center + Vector2(radius * 0.70, radius * 0.58), color, 2.0, true)


func _draw_anchor_contract_bridge(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	draw_circle(center + Vector2(-radius * 0.46, 0.0), radius * 0.22, soft)
	draw_circle(center + Vector2(radius * 0.46, 0.0), radius * 0.22, soft)
	draw_arc(center, radius * 0.42, -PI * 0.85, -PI * 0.15, 36, color, 2.4, true)
	draw_line(center + Vector2(-radius * 0.24, 0.0), center + Vector2(radius * 0.24, 0.0), color, 2.4, true)


func _draw_anchor_link_breaker(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	_draw_anchor_contract_bridge(center, radius, color, soft)
	draw_line(center + Vector2(-radius * 0.12, -radius * 0.36), center + Vector2(radius * 0.12, radius * 0.36), color, 3.0, true)
	draw_line(center + Vector2(radius * 0.12, -radius * 0.36), center + Vector2(-radius * 0.12, radius * 0.36), color, 3.0, true)


func _draw_anchor_hand_pull(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	var card := Rect2(center + Vector2(-radius * 0.18, -radius * 0.48), Vector2(radius * 0.46, radius * 0.66))
	draw_rect(card, soft, true)
	draw_rect(card, color, false, 1.8)
	draw_line(center + Vector2(-radius * 0.70, radius * 0.34), center + Vector2(-radius * 0.18, -radius * 0.10), color, 3.0, true)
	draw_line(center + Vector2(-radius * 0.36, -radius * 0.18), center + Vector2(-radius * 0.18, -radius * 0.10), color, 3.0, true)


func _draw_anchor_phase_null(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	draw_circle(center, radius * 0.48, soft)
	draw_arc(center, radius * 0.48, 0.0, TAU, 56, color, 2.2, true)
	draw_line(center + Vector2(-radius * 0.54, -radius * 0.54), center + Vector2(radius * 0.54, radius * 0.54), color, 3.0, true)


func _draw_anchor_air_wing(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	var wing := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.74),
		center + Vector2(radius * 0.18, radius * 0.08),
		center + Vector2(radius * 0.82, radius * 0.34),
		center + Vector2(radius * 0.12, radius * 0.28),
		center + Vector2(0.0, radius * 0.72),
		center + Vector2(-radius * 0.12, radius * 0.28),
		center + Vector2(-radius * 0.82, radius * 0.34),
		center + Vector2(-radius * 0.18, radius * 0.08),
	])
	draw_colored_polygon(wing, soft)
	draw_polyline(wing, color, 2.0, true)


func _draw_anchor_naval_fleet(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	var hull := PackedVector2Array([
		center + Vector2(-radius * 0.74, radius * 0.10),
		center + Vector2(radius * 0.64, radius * 0.10),
		center + Vector2(radius * 0.34, radius * 0.48),
		center + Vector2(-radius * 0.58, radius * 0.48),
	])
	draw_colored_polygon(hull, soft)
	draw_polyline(hull, color, 2.0, true)
	draw_line(center + Vector2(-radius * 0.22, radius * 0.10), center + Vector2(-radius * 0.02, -radius * 0.44), color, 2.2, true)
	draw_line(center + Vector2(-radius * 0.02, -radius * 0.44), center + Vector2(radius * 0.26, radius * 0.08), color, 2.2, true)
	for i in range(2):
		draw_arc(center + Vector2(0.0, radius * (0.54 + float(i) * 0.16)), radius * 0.72, -PI * 0.92, -PI * 0.08, 36, soft, 2.0, true)


func _draw_anchor_ground_force(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	var body := Rect2(center + Vector2(-radius * 0.54, -radius * 0.16), Vector2(radius * 1.08, radius * 0.38))
	draw_rect(body, soft, true)
	draw_rect(body, color, false, 1.8)
	draw_line(center + Vector2(radius * 0.06, -radius * 0.20), center + Vector2(radius * 0.74, -radius * 0.48), color, 3.0, true)
	draw_circle(center + Vector2(-radius * 0.34, radius * 0.30), radius * 0.12, color)
	draw_circle(center + Vector2(radius * 0.34, radius * 0.30), radius * 0.12, color)


func _draw_first_run_focus_overlay(art_rect: Rect2, focus_key: String, seed: int) -> void:
	if focus_key == "":
		return
	var c := accent.lightened(0.42)
	c.a = 0.62 if compact else 0.76
	var soft := c
	soft.a = 0.20 if compact else 0.28
	var center := art_rect.get_center()
	var radius: float = min(art_rect.size.x, art_rect.size.y) * 0.28
	match focus_key:
		"city_money":
			_draw_focus_city_money(center, radius, c, soft)
		"factory_upgrade":
			_draw_focus_factory_upgrade(center, radius, c, soft)
		"transit_route":
			_draw_focus_transit_route(art_rect, c, soft)
		"broadcast":
			_draw_focus_broadcast(center, radius, c, soft)
		"lure_beacon":
			_draw_focus_lure_beacon(center, radius, c, soft)
		"supply_cache":
			_draw_focus_supply_cache(center, radius, c, soft)
		"movement_arrow":
			_draw_focus_movement_arrow(art_rect, c, soft)
		"impact_attack":
			_draw_focus_impact_attack(center, radius, c, soft, seed)
		"shield_guard":
			_draw_focus_shield_guard(center, radius, c, soft)
		"district_crack":
			_draw_focus_district_crack(art_rect, c, soft)
		"contract_link":
			_draw_focus_contract_link(center, radius, c, soft)
		"intel_lens":
			_draw_focus_intel_lens(center, radius, c, soft)
		"market_curve":
			_draw_focus_market_curve(art_rect, c, soft)
		"monster_anchor":
			_draw_focus_monster_anchor(center, radius, c, soft)
		_:
			_draw_focus_route_mark(art_rect, c, soft)


func _draw_focus_city_money(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	var base_y := center.y + radius * 0.40
	for i in range(3):
		var w := radius * (0.34 + float(i) * 0.18)
		var h := radius * (0.34 + float(i) * 0.20)
		var x := center.x - radius * 0.58 + float(i) * radius * 0.42
		var r := Rect2(Vector2(x, base_y - h), Vector2(w, h))
		draw_rect(r, soft, true)
		draw_rect(r, color, false, 1.6)
	draw_circle(center + Vector2(radius * 0.62, -radius * 0.22), radius * 0.22, color)
	draw_line(center + Vector2(radius * 0.62, -radius * 0.36), center + Vector2(radius * 0.62, -radius * 0.08), Color("#020617"), 2.0, true)


func _draw_focus_factory_upgrade(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	var body := Rect2(center + Vector2(-radius * 0.72, -radius * 0.08), Vector2(radius * 1.42, radius * 0.58))
	draw_rect(body, soft, true)
	draw_rect(body, color, false, 1.8)
	for i in range(3):
		var x := body.position.x + radius * (0.18 + float(i) * 0.34)
		draw_line(Vector2(x, body.position.y), Vector2(x + radius * 0.16, body.position.y - radius * 0.40), color, 2.0, true)
	draw_line(center + Vector2(radius * 0.40, -radius * 0.56), center + Vector2(radius * 0.40, radius * 0.20), color, 2.4, true)
	draw_line(center + Vector2(radius * 0.16, -radius * 0.32), center + Vector2(radius * 0.40, -radius * 0.56), color, 2.4, true)
	draw_line(center + Vector2(radius * 0.64, -radius * 0.32), center + Vector2(radius * 0.40, -radius * 0.56), color, 2.4, true)


func _draw_focus_transit_route(art_rect: Rect2, color: Color, soft: Color) -> void:
	var y0 := art_rect.position.y + art_rect.size.y * 0.68
	var p0 := Vector2(art_rect.position.x + art_rect.size.x * 0.12, y0)
	var p1 := Vector2(art_rect.position.x + art_rect.size.x * 0.42, art_rect.position.y + art_rect.size.y * 0.36)
	var p2 := Vector2(art_rect.position.x + art_rect.size.x * 0.86, art_rect.position.y + art_rect.size.y * 0.46)
	draw_line(p0, p1, soft, 8.0, true)
	draw_line(p1, p2, soft, 8.0, true)
	draw_line(p0, p1, color, 2.4, true)
	draw_line(p1, p2, color, 2.4, true)
	for p in [p0, p1, p2]:
		draw_circle(p, 4.2, color)


func _draw_focus_broadcast(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	draw_circle(center, radius * 0.12, color)
	for i in range(3):
		draw_arc(center, radius * (0.30 + float(i) * 0.20), -PI * 0.35, PI * 0.35, 24, color if i == 0 else soft, 2.2, true)
	draw_line(center + Vector2(-radius * 0.54, radius * 0.46), center + Vector2(radius * 0.52, radius * 0.46), color, 2.0, true)


func _draw_focus_lure_beacon(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	draw_circle(center, radius * 0.18, color)
	for i in range(3):
		draw_arc(center, radius * (0.34 + float(i) * 0.20), 0.0, TAU, 48, soft if i > 0 else color, 2.0, true)
	draw_line(center + Vector2(0.0, radius * 0.16), center + Vector2(0.0, radius * 0.72), color, 2.2, true)


func _draw_focus_supply_cache(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	for i in range(3):
		var r := Rect2(center + Vector2((float(i) - 1.0) * radius * 0.36 - radius * 0.20, -radius * 0.16 + float(i % 2) * radius * 0.18), Vector2(radius * 0.40, radius * 0.34))
		draw_rect(r, soft, true)
		draw_rect(r, color, false, 1.6)
	draw_line(center + Vector2(-radius * 0.66, -radius * 0.48), center + Vector2(radius * 0.66, -radius * 0.48), color, 2.0, true)


func _draw_focus_movement_arrow(art_rect: Rect2, color: Color, soft: Color) -> void:
	var start := art_rect.position + Vector2(art_rect.size.x * 0.18, art_rect.size.y * 0.72)
	var end := art_rect.position + Vector2(art_rect.size.x * 0.78, art_rect.size.y * 0.26)
	draw_line(start, end, soft, 7.0, true)
	draw_line(start, end, color, 2.8, true)
	draw_line(end, end + Vector2(-art_rect.size.x * 0.18, art_rect.size.y * 0.02), color, 2.8, true)
	draw_line(end, end + Vector2(-art_rect.size.x * 0.04, art_rect.size.y * 0.16), color, 2.8, true)


func _draw_focus_impact_attack(center: Vector2, radius: float, color: Color, soft: Color, seed: int) -> void:
	draw_circle(center, radius * 0.16, color)
	for i in range(6):
		var a := float(i) / 6.0 * TAU + float(seed % 7) * 0.03
		var p0 := center + Vector2(cos(a), sin(a)) * radius * 0.24
		var p1 := center + Vector2(cos(a), sin(a)) * radius * (0.66 + float(i % 2) * 0.12)
		draw_line(p0, p1, color if i % 2 == 0 else soft, 2.4, true)


func _draw_focus_shield_guard(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	var shield := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.70),
		center + Vector2(radius * 0.56, -radius * 0.42),
		center + Vector2(radius * 0.44, radius * 0.28),
		center + Vector2(0.0, radius * 0.72),
		center + Vector2(-radius * 0.44, radius * 0.28),
		center + Vector2(-radius * 0.56, -radius * 0.42),
	])
	draw_colored_polygon(shield, soft)
	draw_polyline(shield, color, 2.0, true)


func _draw_focus_district_crack(art_rect: Rect2, color: Color, soft: Color) -> void:
	var base := art_rect.position + Vector2(art_rect.size.x * 0.14, art_rect.size.y * 0.70)
	var step := art_rect.size.x * 0.14
	for i in range(5):
		var p0 := base + Vector2(step * float(i), float((i % 2) - 1) * art_rect.size.y * 0.05)
		var p1 := p0 + Vector2(step * 0.72, float((1 - i % 2)) * art_rect.size.y * 0.10 - art_rect.size.y * 0.05)
		draw_line(p0, p1, color if i % 2 == 0 else soft, 2.4, true)


func _draw_focus_contract_link(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	draw_circle(center + Vector2(-radius * 0.36, 0.0), radius * 0.28, soft)
	draw_circle(center + Vector2(radius * 0.36, 0.0), radius * 0.28, soft)
	draw_arc(center + Vector2(-radius * 0.36, 0.0), radius * 0.28, -PI * 0.45, PI * 0.45, 20, color, 2.0, true)
	draw_arc(center + Vector2(radius * 0.36, 0.0), radius * 0.28, PI * 0.55, PI * 1.45, 20, color, 2.0, true)
	draw_line(center + Vector2(-radius * 0.12, 0.0), center + Vector2(radius * 0.12, 0.0), color, 2.2, true)


func _draw_focus_intel_lens(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	draw_circle(center + Vector2(-radius * 0.10, -radius * 0.08), radius * 0.36, soft)
	draw_arc(center + Vector2(-radius * 0.10, -radius * 0.08), radius * 0.36, 0.0, TAU, 48, color, 2.0, true)
	draw_line(center + Vector2(radius * 0.16, radius * 0.18), center + Vector2(radius * 0.58, radius * 0.58), color, 3.0, true)


func _draw_focus_market_curve(art_rect: Rect2, color: Color, soft: Color) -> void:
	var left := art_rect.position.x + art_rect.size.x * 0.16
	var bottom := art_rect.position.y + art_rect.size.y * 0.74
	var last := Vector2(left, bottom)
	for i in range(1, 7):
		var t := float(i) / 6.0
		var p := Vector2(left + art_rect.size.x * 0.66 * t, bottom - art_rect.size.y * (0.18 + 0.28 * sin(t * PI * 0.85)))
		draw_line(last, p, color if i % 2 == 0 else soft, 2.5, true)
		last = p


func _draw_focus_monster_anchor(center: Vector2, radius: float, color: Color, soft: Color) -> void:
	draw_circle(center, radius * 0.44, soft)
	draw_arc(center, radius * 0.58, -PI * 0.15, PI * 1.15, 36, color, 2.0, true)
	draw_line(center + Vector2(-radius * 0.22, -radius * 0.34), center + Vector2(-radius * 0.52, -radius * 0.68), color, 2.0, true)
	draw_line(center + Vector2(radius * 0.22, -radius * 0.34), center + Vector2(radius * 0.52, -radius * 0.68), color, 2.0, true)


func _draw_focus_route_mark(art_rect: Rect2, color: Color, soft: Color) -> void:
	var center := art_rect.get_center()
	draw_arc(center, min(art_rect.size.x, art_rect.size.y) * 0.24, -PI * 0.25, PI * 1.25, 36, soft, 2.0, true)


func _moth_kaijuice_card_sprite_key() -> String:
	var identity := "%s｜%s｜%s｜%s" % [card_name, card_kind, card_tags, card_stats]
	if card_kind == "monster_card":
		if identity.contains("孢雾"):
			return "superpowers_dragon"
		if identity.contains("砂铠"):
			return "monster_battler_rock"
		if identity.contains("流星"):
			return "kenney_enemy_ufo"
		if identity.contains("棱刃"):
			return "monster_battler_dino"
		if identity.contains("绿洲"):
			return "pixelmob_slime_square"
		if identity.contains("焰环"):
			return "moth_kaijuice_kaiju"
		if identity.contains("蓝锋"):
			return "superpowers_snake"
		if identity.contains("镜像"):
			return "kenney_alien_blue"
		return "kaiju"
	match _card_illustration_anchor_key():
		"finance_tower":
			return "game_icon_bank"
		"factory_core":
			return "mech"
		"transit_grid":
			return "kenney_enemy_ufo"
		"broadcast_array":
			return "laser"
		"lure_beacon":
			return "monster_battler_rodent"
		"supply_cache":
			return "tank"
		"motion_vector":
			return "kenney_fish"
		"impact_core":
			return "monster_battler_salamander"
		"shield_gate":
			return "atfield"
		"shield_route":
			return "atfield"
		"fracture_map":
			return "monster_battler_rock"
		"intel_lens":
			return "kenney_alien_blue"
		"market_up":
			return "kenney_fish" if identity.contains("商品") else "game_icon_profit"
		"market_down":
			return "kenney_slime" if identity.contains("商品") else "game_icon_fall_down"
		"warehouse_stack":
			return "game_icon_warehouse"
		"contract_bridge":
			return "game_icon_contract"
		"link_breaker":
			return "game_icon_breaking_chain"
		"hand_pull":
			return "game_icon_robber_hand"
		"phase_null":
			return "game_icon_cancel"
		"air_wing":
			return "kenney_enemy_ufo"
		"naval_fleet":
			return "tank"
		"ground_force":
			return "tank"
	if _contains_any(identity, ["产业升级", "生产扩张", "产能封锁", "产品线", "产业", "生产"]):
		return "mech"
	if _contains_any(identity, ["交通升级", "交通瘫痪", "星港快线", "航线", "运输", "流通", "航路"]):
		return "kenney_enemy_ufo"
	if _contains_any(identity, ["星际广告", "舆论", "广告", "新闻", "热搜", "快讯", "传闻", "播报"]):
		return "laser"
	if _contains_any(identity, ["怪兽", "星兽", "诱导", "夺取"]):
		return "monster_battler_turtle" if _name_seed() % 2 == 0 else "monster_battler_rodent"
	if _contains_any(identity, ["机甲", "战斗机", "轰炸", "防卫军"]):
		return "kenney_enemy_ufo" if _contains_any(identity, ["战斗机", "轰炸", "空军"]) else "mech"
	if _contains_any(identity, ["坦克", "导弹", "舰队", "战舰", "潜航"]):
		return "tank"
	if _contains_any(identity, ["士兵", "军队", "齐射", "拆解", "牵引", "冻结"]):
		return "soldier"
	if _contains_any(identity, ["光线", "炮", "射线", "远距", "黑客", "风暴"]):
		return "laser"
	if _contains_any(identity, ["格挡", "否决", "保险", "修复", "稳定", "护"]):
		return "atfield"
	if _contains_any(identity, ["城市", "融资", "合约", "商品", "需求", "生产", "交通", "GDP", "期货", "仓", "港"]):
		return "building_m" if _name_seed() % 2 == 0 else "building_s"
	return "building_s" if _name_seed() % 3 == 0 else "building_m"


func _card_visual_source_id(sprite_key: String) -> String:
	match sprite_key:
		"kaiju":
			return "moth_kaijuice_mit_kaiju_sheet"
		"moth_kaijuice_kaiju":
			return "moth_kaijuice_mit_kaiju_family"
		"atfield":
			return "moth_kaijuice_mit_field_effect"
		"laser":
			return "moth_kaijuice_mit_laser_effect"
		"mech":
			return "moth_kaijuice_mit_mech_sheet"
		"tank":
			return "moth_kaijuice_mit_tank_sprite"
		"soldier":
			return "moth_kaijuice_mit_soldier_sprite"
		"building_m":
			return "moth_kaijuice_mit_medium_city"
		"building_s":
			return "moth_kaijuice_mit_small_city"
		"monster_battler_dino":
			return "monster_battler_cc0_dino"
		"monster_battler_rock":
			return "monster_battler_cc0_rock"
		"monster_battler_rodent":
			return "monster_battler_cc0_rodent"
		"monster_battler_salamander":
			return "monster_battler_cc0_salamander"
		"monster_battler_turtle":
			return "monster_battler_cc0_turtle"
		"kenney_fish":
			return "kenney_cc0_fish"
		"kenney_slime":
			return "kenney_cc0_slime"
		"kenney_alien_blue":
			return "kenney_cc0_alien_blue"
		"kenney_enemy_ufo":
			return "kenney_cc0_enemy_ufo"
		"pixelmob_slime":
			return "pixelmob_cc0_slime"
		"pixelmob_slime_square":
			return "pixelmob_cc0_slime_square"
		"superpowers_dragon":
			return "superpowers_cc0_dragon_card"
		"superpowers_cyclop":
			return "superpowers_cc0_cyclop_card"
		"superpowers_snake":
			return "superpowers_cc0_snake_card"
		"superpowers_slim":
			return "superpowers_cc0_slim_card"
		"game_icon_bank":
			return "game_icons_ccby_bank_finance"
		"game_icon_profit":
			return "game_icons_ccby_profit_curve"
		"game_icon_fall_down":
			return "game_icons_ccby_fall_down_short"
		"game_icon_contract":
			return "game_icons_ccby_contract_scroll"
		"game_icon_breaking_chain":
			return "game_icons_ccby_breaking_chain"
		"game_icon_robber_hand":
			return "game_icons_ccby_robber_hand"
		"game_icon_cancel":
			return "game_icons_ccby_cancel_null"
		"game_icon_warehouse":
			return "game_icons_ccby_warehouse_stockpile"
		"game_icon_shaking_hands":
			return "game_icons_ccby_shaking_hands_deal"
		"game_icon_coins_pile":
			return "game_icons_ccby_coins_pile"
		_:
			return "procedural_card_art_fallback"


func _moth_kaijuice_card_sprite_cell(sprite_key: String) -> String:
	if sprite_key == "kaiju" or sprite_key == "moth_kaijuice_kaiju":
		var cell_index := _name_seed() % 32
		return "%d,%d" % [cell_index % 8, int(cell_index / 8)]
	if sprite_key == "mech":
		var cell_index := _name_seed() % 24
		return "%d,%d" % [cell_index % 8, int(cell_index / 8)]
	if sprite_key.begins_with("pixelmob"):
		return str(_name_seed() % PIXELMOB_FRAME_COUNT)
	return "full"


func _moth_kaijuice_card_sprite_region(sprite_key: String) -> Rect2:
	var texture := moth_kaijuice_textures.get(sprite_key, null) as Texture2D
	if texture == null:
		return Rect2()
	if sprite_key == "kaiju" or sprite_key == "moth_kaijuice_kaiju" or sprite_key == "mech":
		var cell_text := _moth_kaijuice_card_sprite_cell(sprite_key)
		var parts := cell_text.split(",")
		var cell_x := int(parts[0]) if parts.size() > 0 else 0
		var cell_y := int(parts[1]) if parts.size() > 1 else 0
		return Rect2(Vector2(float(cell_x) * MOTH_KAIJUICE_CELL_SIZE.x, float(cell_y) * MOTH_KAIJUICE_CELL_SIZE.y), MOTH_KAIJUICE_CELL_SIZE)
	if sprite_key.begins_with("pixelmob"):
		var frame_width := texture.get_size().x / float(PIXELMOB_FRAME_COUNT)
		var frame_index := clampi(int(_moth_kaijuice_card_sprite_cell(sprite_key)), 0, PIXELMOB_FRAME_COUNT - 1)
		return Rect2(Vector2(frame_width * float(frame_index), 0.0), Vector2(frame_width, texture.get_size().y))
	return Rect2(Vector2.ZERO, texture.get_size())


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


func _card_motif_family_key() -> String:
	if card_kind == "monster_card":
		return "monster"
	if card_kind.contains("military"):
		return "military"
	if card_kind.contains("contract"):
		return "contract"
	if card_kind.contains("intel"):
		return "intel"
	if card_kind.contains("futures") or card_kind.contains("gdp") or card_kind.contains("speculation"):
		return "finance"
	if card_kind.contains("route"):
		return "route"
	if card_kind.contains("weather") or card_kind.contains("news"):
		return "weather"
	if card_kind.contains("product") or card_kind.contains("demand") or card_kind.contains("economy"):
		return "product"
	return "utility"


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
	var tiny_compact := compact and rect.size.y <= 50.0
	var font_size := 12 if tiny_compact else (17 if compact else 21)
	var glyph := _glyph_for_kind()
	var badge_radius: float = min(rect.size.x, rect.size.y) * (0.105 if compact else 0.095)
	var badge_center := Vector2(rect.size.x * 0.74, rect.size.y * (0.33 if tiny_compact else 0.35))
	var badge := Color("#020617").lerp(accent, 0.24)
	badge.a = 0.74
	draw_circle(badge_center, badge_radius, badge)
	var ring := accent.lightened(0.36)
	ring.a = 0.70
	draw_arc(badge_center, badge_radius, 0.0, TAU, 36, ring, 1.4, true)
	var shadow := Color("#020617")
	shadow.a = 0.74
	var baseline_y: float = badge_center.y + badge_radius * 0.38
	var text_rect_x: float = badge_center.x - badge_radius
	var text_width: float = badge_radius * 2.0
	var ink := Color("#f8fafc")
	ink.a = 0.86
	draw_string(font, Vector2(text_rect_x + 1.0, baseline_y + 1.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, shadow)
	draw_string(font, Vector2(text_rect_x, baseline_y), glyph, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, ink)


func _draw_caption(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var tiny_compact := compact and rect.size.y <= 50.0
	if tiny_compact:
		var band := Color("#020617")
		band.a = 0.72
		draw_rect(Rect2(4.0, rect.size.y - 21.0, rect.size.x - 8.0, 17.0), band, true)
		var tiny_title := _short_text(card_name, 8)
		var tiny_tag := _short_text(card_tags, 10)
		draw_string(font, Vector2(0.0, rect.size.y - 10.0), tiny_title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color("#e0f2fe"))
		draw_string(font, Vector2(0.0, rect.size.y - 2.0), tiny_tag, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 6, accent.lightened(0.40))
		return
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
		"military_force":
			return "军"
		"military_command":
			return "令"
		"card_counter":
			return "消"
		"player_hand_disrupt":
			return "拆"
		"player_hand_steal":
			return "牵"
		"city_control_dispute":
			return "冻"
		"global_barrage":
			return "齐"
		"city_revenue_boost":
			return "城"
		"cash_gain":
			return "¥"
		"city_gdp_derivative":
			return "涨"
		"product_futures":
			return "期"
		"product_speculation":
			return "价"
		"product_contract_boon":
			return "订"
		"product_growth_boon":
			return "催"
		"area_trade_contract":
			return "约"
		"city_contract_boon":
			return "单"
		"route_flow_boon":
			return "速"
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
		"region_economy_shift":
			return "域"
		"intel_city_reveal":
			return "查"
		"intel_card_trace":
			return "溯"
		"intel_contract_trace":
			return "契"
		"card_access_boon":
			return "购"
		"news_event":
			return "闻"
		"weather_control":
			return "天"
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
