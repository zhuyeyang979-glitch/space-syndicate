extends Node
class_name NewGameSetupViewerQueryPort

const MonsterCatalog := preload("res://scripts/runtime/monster_catalog_v06.gd")
const MovementModel := preload("res://scripts/balance/movement_balance_model.gd")
const AlphaContentLoader := preload("res://scripts/runtime/alpha01_content_manifest_loader.gd")

@export var draft_service_path: NodePath
@export var role_catalog_path: NodePath
@export var world_session_state_path: NodePath
@export var game_session_path: NodePath

var _query_count := 0


func page_snapshot(available_width: float = 900.0) -> Dictionary:
	_query_count += 1
	var draft_owner := _draft_service()
	var role_catalog := _role_catalog()
	var content := AlphaContentLoader.load_active_selection()
	if draft_owner == null or role_catalog == null or not content.is_valid():
		return {"valid": false, "reason_code": "setup_query_dependency_missing"}
	var draft := draft_owner.draft_snapshot()
	var player_count := int(draft.get("player_count", 0))
	var ai_count := int(draft.get("ai_player_count", 0))
	var human_count := maxi(1, player_count - ai_count)
	var depth := int(draft.get("challenge_depth", 1))
	var movement := MovementModel.new()
	var count_range := movement.region_count_range_for_depth(depth)
	var planet_size := movement.planet_size_for_depth(depth)
	var role_indices: Array = draft.get("role_indices", [])
	var monster_indices: Array = draft.get("starter_monster_indices", [])
	var seats: Array = []
	for player_index in range(player_count):
		var is_ai := player_index >= human_count
		var role_index := int(role_indices[player_index]) if player_index < role_indices.size() else player_index
		var monster_index := int(monster_indices[player_index]) if player_index < monster_indices.size() else player_index
		seats.append(_seat_snapshot(player_index, is_ai, role_index, monster_index, role_catalog))
	return {
		"valid": true,
		"reason_code": "setup_page_ready",
		"draft_revision": int(draft.get("draft_revision", 0)),
		"accent": Color("#38bdf8"),
		"tooltip": "确认席位、电脑对手、挑战层级、公开角色和独立起始怪兽牌。",
		"summary_chips": [
			{"text": "席位 %d" % player_count, "accent": Color("#bfdbfe"), "fill": Color("#0f172a")},
			{"text": "真人 %d" % human_count, "accent": Color("#bbf7d0"), "fill": Color("#064e3b")},
			{"text": "电脑对手%d" % ai_count, "accent": Color("#d8b4fe"), "fill": Color("#2e1065")},
			{"text": "深度%s" % _roman(depth), "accent": Color("#fde68a"), "fill": Color("#713f12")},
			{"text": "角色不重复", "accent": Color("#93c5fd"), "fill": Color("#1e3a8a")},
			{"text": "召唤可选", "accent": Color("#fecaca"), "fill": Color("#7f1d1d")},
			{"text": "Alpha清单 8/40/8", "accent": Color("#a7f3d0"), "fill": Color("#064e3b")},
		],
		"lobby": _lobby_snapshot(player_count, ai_count, human_count, depth, count_range, planet_size),
		"options": _option_snapshot(player_count, ai_count, depth, count_range, planet_size),
		"seat_title": "座位卡｜公开角色 + 起始怪兽牌",
		"seat_columns": clampi(int(floor(available_width / 520.0)), 1, 2),
		"seat_scroll_height": 360.0,
		"seats": seats,
		"hint": "角色公开；起始怪兽牌由各席持有并可随时自愿召唤。",
		"can_return_table": _can_return_table(),
		"start_disabled": seats.size() != player_count,
		"start_tooltip": "按当前%d席、AI%d和深度%s配置开始本局。" % [player_count, ai_count, _roman(depth)],
	}


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "new_game_setup_viewer_query_port_v1",
		"query_count": _query_count,
		"mutates_draft": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
	}


func _seat_snapshot(player_index: int, is_ai: bool, role_index: int, monster_index: int, catalog: RoleCatalogRuntimeService) -> Dictionary:
	var random_role := role_index == NewGameSetupDraftService.ROLE_RANDOM_INDEX
	var role := _random_role() if random_role else catalog.public_definition_at(role_index)
	var monster := MonsterCatalog.catalog_entry(monster_index)
	var role_name := str(role.get("name", "随机角色" if random_role else "外星辛迪加"))
	var monster_name := str(monster.get("name", "怪兽"))
	var accent := _player_color(player_index)
	var public_monster := "匿名待公开" if is_ai else monster_name
	return {
		"player_index": player_index,
		"seat_type": "ai" if is_ai else "human",
		"accent": accent,
		"tooltip": "公开角色与独立起始怪兽牌；怪兽召唤者保持匿名。",
		"chips": [
			{"text": "P%d" % (player_index + 1), "accent": Color("#f8fafc"), "fill": Color("#0f172a").lerp(accent, 0.28)},
			{"text": "电脑对手" if is_ai else "真人/本地", "accent": Color("#bfdbfe"), "fill": Color("#0f172a")},
			{"text": "角色:%s" % role_name, "accent": Color("#e0f2fe"), "fill": Color("#0c4a6e")},
			{"text": "◆ %s" % public_monster, "accent": Color("#fecaca"), "fill": Color("#7f1d1d")},
		],
		"identity": {
			"accent": accent,
			"columns": 2,
			"chips": [
				{"text": "公开角色:%s" % role_name, "accent": Color("#e0f2fe"), "fill": Color("#0c4a6e")},
				{"text": "起始牌:%s" % public_monster, "accent": Color("#fecaca"), "fill": Color("#7f1d1d")},
				{"text": "怪兽归属匿名", "accent": Color("#fde68a"), "fill": Color("#713f12")},
			],
			"cards": [
				{"title": "公开身份", "body": "开局公开；角色与怪兽独立。", "accent": Color("#93c5fd")},
				{"title": "起始怪兽牌", "body": "由该席持有；召唤完全自愿。", "accent": Color("#fb7185")},
				{"title": "第一步", "body": "选区域 → 看牌架 → 建立收入", "accent": Color("#22c55e")},
				{"title": "信息边界", "body": "现金、手牌和内部策略不在此公开。", "accent": Color("#c4b5fd")},
			],
		},
		"passive_text": "角色被动：%s" % str(role.get("passive", "开局时公开")),
		"passive_tooltip": str(role.get("passive", "开局时公开")),
		"role_label": role_name,
		"role_random": random_role,
		"show_random_role": is_ai,
		"monster_label": monster_name,
		"starter_note": "起始牌：%s｜召唤可选" % str(monster.get("summon_access", "不限区")),
		"card_faces": [_role_card_face(role, random_role), _monster_card_face(monster)] if not is_ai else [_role_card_face(role, random_role)],
	}


func _lobby_snapshot(player_count: int, ai_count: int, human_count: int, depth: int, count_range: Dictionary, planet_size: Dictionary) -> Dictionary:
	return {
		"accent": Color("#38bdf8"), "title": "开桌流程", "columns": 5,
		"chips": [
			{"text": "PVE %d席" % player_count, "accent": Color("#bfdbfe")},
			{"text": "AI %d" % ai_count, "accent": Color("#d8b4fe")},
			{"text": "区域 %d-%d" % [int(count_range.get("region_min", 0)), int(count_range.get("region_max", 0))], "accent": Color("#fef3c7")},
		],
		"steps": [
			{"title": "1｜席位", "body": "%d席｜真人%d｜AI%d" % [player_count, human_count, ai_count], "accent": Color("#38bdf8")},
			{"title": "2｜挑战", "body": "深度%s｜%.0fm×%.0fm" % [_roman(depth), float(planet_size.get("width_m", 0.0)), float(planet_size.get("height_m", 0.0))], "accent": Color("#facc15")},
			{"title": "3｜角色", "body": "公开身份｜同局不重复", "accent": Color("#c084fc")},
			{"title": "4｜怪兽牌", "body": "各席持有｜召唤可选", "accent": Color("#fb7185")},
			{"title": "5｜开局", "body": "牌架 → 发展 → 商品", "accent": Color("#22c55e")},
		],
	}


func _option_snapshot(player_count: int, ai_count: int, depth: int, count_range: Dictionary, planet_size: Dictionary) -> Dictionary:
	var player_entries: Array = []
	for value in range(3, 9):
		player_entries.append({"id": "player_count", "value": value, "text": "%d席" % value, "pressed": value == player_count})
	var ai_entries: Array = []
	for value in range(2, mini(7, player_count - 1) + 1):
		ai_entries.append({"id": "ai_count", "value": value, "text": "AI%d" % value, "pressed": value == ai_count})
	var depth_entries: Array = []
	var active_depth := AlphaContentLoader.load_active_selection().active_challenge_depth()
	depth_entries.append({"id": "challenge_depth", "value": active_depth, "text": _roman(active_depth), "pressed": active_depth == depth})
	return {
		"accent": Color("#facc15"), "title": "开局参数｜先定桌面规模", "columns": 3,
		"cards": [
			{"title": "席位", "detail": "%d席｜AI%d" % [player_count, ai_count], "accent": Color("#38bdf8"), "options": player_entries},
			{"title": "电脑对手", "detail": "本地PVE｜策略隐藏", "accent": Color("#c084fc"), "options": ai_entries},
			{"title": "挑战层级", "detail": "%.0fm×%.0fm｜区域%d-%d" % [float(planet_size.get("width_m", 0.0)), float(planet_size.get("height_m", 0.0)), int(count_range.get("region_min", 0)), int(count_range.get("region_max", 0))], "accent": Color("#facc15"), "options": depth_entries},
		],
	}


func _role_card_face(role: Dictionary, random_role: bool) -> Dictionary:
	return {"name": str(role.get("name", "随机角色")), "cost": "R", "effect": str(role.get("passive", "开局时从未占用角色中确定。")), "type": str(role.get("species", "公开角色")), "rank": "?" if random_role else "R", "card_kind": "player_role", "card_stats": "公开身份", "accent": Color("#c084fc"), "minimum_width": 142.0, "minimum_height": 140.0}


func _monster_card_face(monster: Dictionary) -> Dictionary:
	return {"name": str(monster.get("name", "怪兽")), "cost": "◆", "effect": "召唤可选｜%s" % str(monster.get("style", "匿名怪兽牌")), "type": "怪兽", "rank": "I", "card_kind": "monster_card", "card_stats": "起始持有｜归属匿名", "accent": Color("#fb7185"), "minimum_width": 142.0, "minimum_height": 140.0}


func _random_role() -> Dictionary:
	return {"name": "随机角色", "species": "未揭示外星人", "passive": "开局时从未占用角色中确定。"}


func _can_return_table() -> bool:
	var world := get_node_or_null(world_session_state_path) as WorldSessionState
	var session := get_node_or_null(game_session_path) as GameSessionRuntimeController
	return world != null and not world.players.is_empty() and session != null and session.session_state() in [GameSessionRuntimeController.STATE_RUNNING, GameSessionRuntimeController.STATE_PAUSED]


func _player_color(index: int) -> Color:
	var colors := [Color("#38bdf8"), Color("#f472b6"), Color("#22c55e"), Color("#facc15"), Color("#c084fc"), Color("#fb7185"), Color("#2dd4bf"), Color("#f97316")]
	return colors[wrapi(index, 0, colors.size())]


func _roman(value: int) -> String:
	var values := ["I", "II", "III", "IV", "V", "VI"]
	return values[clampi(value, 1, values.size()) - 1]


func _draft_service() -> NewGameSetupDraftService:
	return get_node_or_null(draft_service_path) as NewGameSetupDraftService


func _role_catalog() -> RoleCatalogRuntimeService:
	return get_node_or_null(role_catalog_path) as RoleCatalogRuntimeService
