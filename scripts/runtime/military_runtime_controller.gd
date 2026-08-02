@tool
extends Node
class_name MilitaryRuntimeController

const StrictState := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")

var _table_presentation_refresh_port: TablePresentationRefreshPort
var _public_log_producer_port: PublicLogProducerPort
var _presentation_world_clock: WorldEffectiveClockRuntimeController
var _runtime_command_pipeline: RuntimeCommandPipeline

const RuntimeBalanceModelScript := preload("res://scripts/balance/runtime_balance_model.gd")

const UNIT_DEFAULT_DURATION_SECONDS := 28.0
const UNIT_DEFAULT_COOLDOWN_SECONDS := 7.5
const UNIT_HISTORY_LIMIT := 16
const UNIT_COMMAND_COOLDOWN_SECONDS := 5.0
const WEATHER_MOVEMENT_FLOOR := 0.40
const WEATHER_RANGED_EFFECT_FLOOR := 0.70
const SAVE_RULESET_ID := "v0.6"
const SAVE_STATE_VERSION := 2
const SAVE_KEYS := [
	"schema_version",
	"ruleset_id",
	"military_units",
	"next_military_unit_uid",
	"bankruptcy_estate_journal",
]
const REQUIRED_UNIT_KEYS := [
	"uid", "owner", "position", "world_position", "cooldown_left", "public_owner_revealed",
	"rank", "name", "source_card", "military_type", "military_domain", "movement_traits",
	"terrain_move_multiplier", "military_gdp_penalty", "military_gdp_pressure_seconds",
	"military_strike_gdp_penalty", "military_strike_route_damage", "hp", "max_hp", "damage",
	"range", "move", "duration", "remaining_time",
]
const LINEAR_MOTION_REQUIRED_KEYS := [
	"linear_move_target_position", "linear_move_target_district", "linear_move_speed_mps",
	"linear_move_source", "linear_move_mode", "linear_move_damaged_districts",
	"linear_move_started_at", "linear_move_arrival_action",
]
const BANKRUPTCY_RECORD_BASE_KEYS := ["state", "player_indices", "expected_hash", "estate_counts"]
const BANKRUPTCY_RECORD_OPEN_KEYS := ["state", "player_indices", "expected_hash", "preimage", "postimage", "estate_counts"]

var _world_bridge: MilitaryRuntimeWorldBridge
var _region_infrastructure_world_bridge: Node
var _route_network_runtime_controller: RouteNetworkRuntimeController
var _monster_runtime_controller: MonsterRuntimeController
var _weather_runtime_controller: WeatherRuntimeController
var _product_market_runtime_controller: ProductMarketRuntimeController
var _inventory_service: CardInventoryRuntimeService
var _card_runtime_catalog_service: CardRuntimeCatalogService
var _visual_cue_runtime_owner: VisualCueRuntimeOwner
var _ruleset_snapshot: Dictionary = {}
var _configured := false

var military_units: Array = []
var next_military_unit_uid := 1
var _bankruptcy_estate_journal: Dictionary = {}


func set_world_bridge(bridge: MilitaryRuntimeWorldBridge) -> void:
	_world_bridge = bridge


func set_region_infrastructure_world_bridge(bridge: Node) -> void:
	_region_infrastructure_world_bridge = bridge


func set_route_network_runtime_controller(controller: RouteNetworkRuntimeController) -> void:
	_route_network_runtime_controller = controller


func set_monster_runtime_controller(controller: MonsterRuntimeController) -> void:
	_monster_runtime_controller = controller


func set_weather_runtime_controller(controller: WeatherRuntimeController) -> void:
	_weather_runtime_controller = controller


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_inventory_service(service: CardInventoryRuntimeService) -> void:
	_inventory_service = service


func set_card_runtime_catalog_service(service: CardRuntimeCatalogService) -> void:
	_card_runtime_catalog_service = service


func set_visual_cue_runtime_owner(cue_owner: VisualCueRuntimeOwner) -> void:
	_visual_cue_runtime_owner = cue_owner


func set_runtime_command_pipeline(pipeline: RuntimeCommandPipeline) -> void:
	_runtime_command_pipeline = pipeline


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_snapshot = ruleset_snapshot.duplicate(true)
	_configured = str(_ruleset_snapshot.get("ruleset_id", "")) == "v0.4" and _world_bridge != null and _inventory_service != null and _monster_runtime_controller != null and _card_runtime_catalog_service != null


func set_table_presentation_ports(refresh_port: TablePresentationRefreshPort, log_port: PublicLogProducerPort, clock: WorldEffectiveClockRuntimeController) -> void:
	_table_presentation_refresh_port = refresh_port
	_public_log_producer_port = log_port
	_presentation_world_clock = clock


func reset_state() -> void:
	military_units.clear()
	next_military_unit_uid = 1
	_bankruptcy_estate_journal.clear()


func bankruptcy_estate_stage(stage: String, request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var player_indices: Array = request.get("player_indices", []) if request.get("player_indices", []) is Array else []
	if transaction_id.is_empty() or player_indices.is_empty() or not (["prepare", "commit", "rollback", "finalize"].has(stage)):
		return _bankruptcy_estate_failure(stage, "military_bankruptcy_request_invalid")
	var record: Dictionary = _bankruptcy_estate_journal.get(transaction_id, {}) if _bankruptcy_estate_journal.get(transaction_id, {}) is Dictionary else {}
	if not record.is_empty() and record.get("player_indices", []) != player_indices:
		return _bankruptcy_estate_failure(stage, "military_bankruptcy_transaction_collision")
	match stage:
		"prepare":
			if not record.is_empty():
				return _bankruptcy_estate_result(stage, record, true)
			var targets: Dictionary = {}
			for value in player_indices:
				targets[str(int(value))] = true
			var postimage: Array = []
			var removed := 0
			for unit_variant in military_units:
				var unit: Dictionary = unit_variant if unit_variant is Dictionary else {}
				if targets.has(str(int(unit.get("owner", -1)))):
					removed += 1
				else:
					postimage.append(unit.duplicate(true))
			record = {
				"state": "prepared", "player_indices": player_indices.duplicate(),
				"expected_hash": var_to_str(military_units).sha256_text(),
				"preimage": military_units.duplicate(true), "postimage": postimage,
				"estate_counts": {"military_units_removed": removed},
			}
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, false)
		"commit":
			if record.is_empty(): return _bankruptcy_estate_failure(stage, "military_bankruptcy_prepare_missing")
			if str(record.get("state", "")) in ["committed", "finalized"]: return _bankruptcy_estate_result(stage, record, true)
			if str(record.get("state", "")) != "prepared" or var_to_str(military_units).sha256_text() != str(record.get("expected_hash", "")):
				return _bankruptcy_estate_failure(stage, "military_bankruptcy_revision_changed")
			military_units = (record.get("postimage", []) as Array).duplicate(true)
			record["state"] = "committed"
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, false)
		"rollback":
			if record.is_empty(): return _bankruptcy_estate_failure(stage, "military_bankruptcy_prepare_missing")
			if str(record.get("state", "")) == "rolled_back": return _bankruptcy_estate_result(stage, record, true)
			if str(record.get("state", "")) == "finalized": return _bankruptcy_estate_failure(stage, "military_bankruptcy_already_finalized")
			if str(record.get("state", "")) == "committed": military_units = (record.get("preimage", []) as Array).duplicate(true)
			record["state"] = "rolled_back"
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, false)
		"finalize":
			if record.is_empty() or not (str(record.get("state", "")) in ["committed", "finalized"]): return _bankruptcy_estate_failure(stage, "military_bankruptcy_commit_missing")
			var duplicate := str(record.get("state", "")) == "finalized"
			record["state"] = "finalized"
			record.erase("preimage"); record.erase("postimage")
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, duplicate)
	return _bankruptcy_estate_failure(stage, "military_bankruptcy_stage_invalid")


func _bankruptcy_estate_result(stage: String, record: Dictionary, duplicate: bool) -> Dictionary:
	return {"prepared": stage == "prepare", "committed": stage == "commit", "rolled_back": stage == "rollback", "finalized": stage == "finalize", "duplicate": duplicate, "reason_code": "military_bankruptcy_%s" % stage, "estate_counts": (record.get("estate_counts", {}) as Dictionary).duplicate(true) if record.get("estate_counts", {}) is Dictionary else {}}


func _bankruptcy_estate_failure(stage: String, reason_code: String) -> Dictionary:
	return {"prepared": false, "committed": false, "rolled_back": false, "finalized": false, "stage": stage, "reason_code": reason_code, "estate_counts": {}}


func tick(delta: float) -> void:
	if not _configured or delta <= 0.0:
		return
	_update_units(delta)


func roster_snapshot(include_private: bool = true) -> Array:
	var result := military_units.duplicate(true)
	if include_private:
		return result
	for unit_variant in result:
		if unit_variant is Dictionary:
			var unit := unit_variant as Dictionary
			unit.erase("owner")
			unit.erase("private_target")
	return result


func replace_runtime_state(units: Array, next_uid: int = 1) -> void:
	military_units = units.duplicate(true)
	next_military_unit_uid = maxi(1, next_uid)


func unit_type_label(unit_or_skill: Dictionary) -> String:
	match str(unit_or_skill.get("military_type", "defense")):
		"fighter": return "制空战斗机"
		"bomber": return "轨道轰炸机"
		"tank": return "重装坦克"
		"missile": return "导弹阵地"
		"submarine": return "潜航舰队"
		"warship": return "星海战舰"
	return "行星防卫军"


func unit_type_glyph(unit_or_skill: Dictionary) -> String:
	match str(unit_or_skill.get("military_type", "defense")):
		"fighter": return "空"
		"bomber": return "轰"
		"tank": return "坦"
		"missile": return "弹"
		"submarine": return "潜"
		"warship": return "舰"
	return "军"


func unit_motif(unit_or_skill: Dictionary) -> String:
	match str(unit_or_skill.get("military_type", "defense")):
		"fighter": return "fighter"
		"bomber": return "bomber"
		"tank": return "tank"
		"missile": return "missile"
		"submarine": return "submarine"
		"warship": return "warship"
	return "force"


func unit_color(unit: Dictionary = {}) -> Color:
	match str(unit.get("military_type", "defense")):
		"fighter": return Color("#38bdf8")
		"bomber": return Color("#fb923c")
		"tank": return Color("#94a3b8")
		"missile": return Color("#a78bfa")
		"submarine": return Color("#0ea5e9")
		"warship": return Color("#22d3ee")
	return Color("#67e8f9")


func domain_label(unit_or_skill: Dictionary) -> String:
	match str(unit_or_skill.get("military_domain", "mixed")):
		"air": return "空中"
		"land": return "陆地"
		"sea": return "海上"
	return "通用"


func deploy_terrain_label(unit_or_skill: Dictionary) -> String:
	match str(unit_or_skill.get("military_deploy_terrain", "any")):
		"land": return "陆地"
		"ocean": return "海洋"
	return "任意未毁区域"


func can_deploy_at_district(skill: Dictionary, district_index: int) -> bool:
	var districts := _districts()
	if district_index < 0 or district_index >= districts.size():
		return false
	if bool((districts[district_index] as Dictionary).get("destroyed", false)):
		return false
	var required := str(skill.get("military_deploy_terrain", "any"))
	return required == "any" or required == "" or str((districts[district_index] as Dictionary).get("terrain", "land")) == required


func terrain_move_multiplier(unit_or_skill: Dictionary, district_index: int) -> float:
	var districts := _districts()
	if district_index < 0 or district_index >= districts.size():
		return 1.0
	var terrain := str((districts[district_index] as Dictionary).get("terrain", "land"))
	var multipliers: Dictionary = unit_or_skill.get("terrain_move_multiplier", {}) if unit_or_skill.get("terrain_move_multiplier", {}) is Dictionary else {}
	return maxf(0.05, float(multipliers.get(terrain, 1.0)))


func mobility_summary(unit_or_skill: Dictionary) -> String:
	var multipliers: Dictionary = unit_or_skill.get("terrain_move_multiplier", {}) if unit_or_skill.get("terrain_move_multiplier", {}) is Dictionary else {}
	return "%s｜部署:%s｜陆×%.2f 海×%.2f" % [
		domain_label(unit_or_skill),
		deploy_terrain_label(unit_or_skill),
		float(multipliers.get("land", 1.0)),
		float(multipliers.get("ocean", 1.0)),
	]


func unit_gdp_pressure(skill_or_unit: Dictionary, command: String = "") -> int:
	var base := int(skill_or_unit.get("military_gdp_penalty", 0))
	if command == "strike_district":
		base += int(skill_or_unit.get("military_strike_gdp_penalty", 0))
	return maxi(0, base)


func unit_gdp_pressure_seconds(skill_or_unit: Dictionary) -> float:
	return maxf(0.0, float(skill_or_unit.get("military_gdp_pressure_seconds", 0.0)))


func unit_duration(skill: Dictionary) -> float:
	return maxf(8.0, float(skill.get("military_duration_seconds", UNIT_DEFAULT_DURATION_SECONDS)))


func unit_range(skill: Dictionary) -> float:
	return maxf(80.0, float(skill.get("military_range", skill.get("range", 260.0))))


func unit_move(skill: Dictionary) -> float:
	return maxf(60.0, float(skill.get("military_move", 260.0)))


func unit_damage(skill: Dictionary) -> int:
	return maxi(1, int(skill.get("military_damage", skill.get("damage", 1))))


func unit_hp(skill: Dictionary) -> int:
	return maxi(1, int(skill.get("military_hp", 8)))


func unit_movement_speed_mps(unit: Dictionary, target_index: int, command_speed_mps: float = -1.0) -> float:
	var base_speed := _unit_base_movement_speed_mps(unit, target_index, command_speed_mps)
	var weather_region_index := _unit_region_index(unit)
	if weather_region_index < 0:
		weather_region_index = target_index
	var weather := military_weather_effect_snapshot(unit, weather_region_index)
	return maxf(0.5, base_speed * float(weather.get("movement_multiplier", 1.0)))


func military_weather_effect_snapshot(unit_or_skill: Dictionary, region_index: int) -> Dictionary:
	var identity := _military_weather_identity(region_index)
	if _weather_runtime_controller == null or region_index < 0:
		return identity
	var context := {
		"movement_domain": _weather_movement_domain(unit_or_skill),
		"unit_tags": _weather_traits(unit_or_skill),
		"weather_resistance": clampf(float(unit_or_skill.get("weather_resistance", 0.0)), 0.0, 1.0),
		"weather_exploitation_multiplier": maxf(1.0, float(unit_or_skill.get("weather_exploitation_multiplier", 1.0))),
	}
	var source_variant: Variant = _weather_runtime_controller.region_effect_snapshot(region_index, context)
	if not (source_variant is Dictionary):
		return identity
	var source := source_variant as Dictionary
	var effects: Array = source.get("effects", []) if source.get("effects", []) is Array else []
	var land := 1.0
	var ocean := 1.0
	var air := 1.0
	var ranged := 1.0
	var orbital := 1.0
	var knockback := 1.0
	var flying_risk := 1.0
	var explanation_codes: Array = []
	var effect_count := 0
	for effect_variant in effects:
		if not (effect_variant is Dictionary):
			continue
		var effect := effect_variant as Dictionary
		var military: Dictionary = effect.get("military", {}) if effect.get("military", {}) is Dictionary else {}
		if military.is_empty():
			continue
		effect_count += 1
		land *= maxf(WEATHER_MOVEMENT_FLOOR, float(military.get("land_multiplier", 1.0)))
		ocean *= maxf(WEATHER_MOVEMENT_FLOOR, float(military.get("ocean_multiplier", 1.0)))
		air *= maxf(WEATHER_MOVEMENT_FLOOR, float(military.get("air_multiplier", 1.0)))
		ranged *= maxf(WEATHER_RANGED_EFFECT_FLOOR, float(military.get("ranged_multiplier", 1.0)))
		orbital *= maxf(0.0, float(military.get("orbital_multiplier", 1.0)))
		knockback *= maxf(0.0, float(military.get("knockback_multiplier", 1.0)))
		flying_risk *= maxf(0.0, float(military.get("flying_risk_multiplier", 1.0)))
		var codes: Array = effect.get("explanations", effect.get("explanation", [])) if effect.get("explanations", effect.get("explanation", [])) is Array else []
		for code_variant in codes:
			var code := str(code_variant)
			if not code.is_empty() and not explanation_codes.has(code):
				explanation_codes.append(code)
	land = maxf(WEATHER_MOVEMENT_FLOOR, land)
	ocean = maxf(WEATHER_MOVEMENT_FLOOR, ocean)
	air = maxf(WEATHER_MOVEMENT_FLOOR, air)
	ranged = maxf(WEATHER_RANGED_EFFECT_FLOOR, ranged)
	var domain := _weather_movement_domain(unit_or_skill)
	var movement := 1.0
	match domain:
		"land": movement = land
		"ocean": movement = ocean
		"air": movement = air
	return {
		"available": bool(source.get("available", true)),
		"affected": effect_count > 0,
		"region_index": region_index,
		"effect_count": effect_count,
		"movement_multiplier": movement,
		"land_movement_multiplier": land,
		"ocean_movement_multiplier": ocean,
		"air_movement_multiplier": air,
		"ranged_effect_multiplier": ranged,
		"orbital_effect_multiplier": orbital,
		"command_range_multiplier": maxf(WEATHER_RANGED_EFFECT_FLOOR, ranged * orbital),
		"knockback_multiplier": knockback,
		"flying_risk_multiplier": flying_risk,
		"explanation_codes": explanation_codes,
	}


func effective_command_range(unit_or_skill: Dictionary, region_index: int, base_range: float) -> float:
	var weather := military_weather_effect_snapshot(unit_or_skill, region_index)
	return maxf(1.0, base_range * float(weather.get("command_range_multiplier", 1.0)))


func effective_knockback(unit_or_skill: Dictionary, region_index: int, base_knockback: float) -> float:
	var weather := military_weather_effect_snapshot(unit_or_skill, region_index)
	return maxf(0.0, base_knockback * float(weather.get("knockback_multiplier", 1.0)))


func _unit_base_movement_speed_mps(unit: Dictionary, target_index: int, command_speed_mps: float = -1.0) -> float:
	var model := RuntimeBalanceModelScript.new().call(
		"military_movement_speed_model",
		unit,
		terrain_move_multiplier(unit, target_index),
		command_speed_mps,
		float(_world_call(&"_current_balance_region_radius_m"))
	) as Dictionary
	return maxf(0.5, float(model.get("speed_mps", 18.0)))


func _military_weather_identity(region_index: int) -> Dictionary:
	return {
		"available": _weather_runtime_controller != null,
		"affected": false,
		"region_index": region_index,
		"effect_count": 0,
		"movement_multiplier": 1.0,
		"land_movement_multiplier": 1.0,
		"ocean_movement_multiplier": 1.0,
		"air_movement_multiplier": 1.0,
		"ranged_effect_multiplier": 1.0,
		"orbital_effect_multiplier": 1.0,
		"command_range_multiplier": 1.0,
		"knockback_multiplier": 1.0,
		"flying_risk_multiplier": 1.0,
		"explanation_codes": [],
	}


func _weather_movement_domain(unit_or_skill: Dictionary) -> String:
	var domain := str(unit_or_skill.get("military_domain", "mixed")).strip_edges().to_lower()
	return "ocean" if domain == "sea" else domain


func _weather_traits(unit_or_skill: Dictionary) -> Array:
	var result: Array = []
	for field in ["movement_traits", "weather_traits"]:
		var source: Variant = unit_or_skill.get(field, [])
		if not (source is Array or source is PackedStringArray):
			continue
		for value in source:
			var tag := str(value).strip_edges().to_lower()
			if not tag.is_empty() and not result.has(tag):
				result.append(tag)
	return result


func unit_index_by_uid(uid: int) -> int:
	if uid <= 0:
		return -1
	for index in range(military_units.size()):
		if int((military_units[index] as Dictionary).get("uid", 0)) == uid:
			return index
	return -1


func owned_active_unit_index(player_index: int) -> int:
	if player_index < 0:
		return -1
	for index in range(military_units.size()):
		if int((military_units[index] as Dictionary).get("owner", -1)) == player_index:
			return index
	return -1


func owned_active_unit_count(player_index: int) -> int:
	if player_index < 0:
		return 0
	var count := 0
	for unit_variant in military_units:
		if unit_variant is Dictionary and int((unit_variant as Dictionary).get("owner", -1)) == player_index:
			count += 1
	return count


func oldest_owned_unit_index(player_index: int) -> int:
	var best_index := -1
	var best_remaining := INF
	for index in range(military_units.size()):
		var unit := military_units[index] as Dictionary
		if int(unit.get("owner", -1)) != player_index:
			continue
		var remaining := float(unit.get("remaining_time", 0.0))
		if remaining < best_remaining:
			best_remaining = remaining
			best_index = index
	return best_index


func player_control_limit(player_index: int) -> int:
	var role_variant: Variant = _world_call(&"_player_role_card_for_index", [player_index])
	var role: Dictionary = role_variant if role_variant is Dictionary else {}
	return maxi(1, 1 + int(role.get("military_control_limit_bonus", 0)))


func active_unit_for_player(player_index: int, bound_uid: int = 0) -> Dictionary:
	if bound_uid > 0:
		var bound_index := unit_index_by_uid(bound_uid)
		if bound_index >= 0:
			var bound_unit := military_units[bound_index] as Dictionary
			if int(bound_unit.get("owner", -1)) == player_index:
				return bound_unit.duplicate(true)
	var index := owned_active_unit_index(player_index)
	return (military_units[index] as Dictionary).duplicate(true) if index >= 0 else {}


func visible_unit_count(player_index: int, viewer_index: int) -> int:
	var count := 0
	for unit_variant in military_units:
		if not (unit_variant is Dictionary):
			continue
		var unit := unit_variant as Dictionary
		if int(unit.get("owner", -1)) == player_index and (bool(unit.get("public_owner_revealed", false)) or player_index == viewer_index):
			count += 1
	return count


func command_label(command: String) -> String:
	return str({
		"move": "前进",
		"guard": "保卫区域",
		"strike_district": "摧毁区域",
		"attack_monster": "攻击怪兽",
	}.get(command, "军令"))


func make_command_skill(command: String, rank: int, unit_uid: int, source_card: String = "") -> Dictionary:
	var safe_rank := clampi(rank, 1, 4)
	var descriptions := {
		"move": "命令绑定军队向当前选区前进；公开显示为匿名军队行动，不显示下令者。",
		"guard": "命令绑定军队保卫当前选区：修复区域共享生命；不公开下令者。",
		"strike_district": "命令绑定军队轰击当前选区，对区域共享生命造成伤害；不公开下令者。",
		"attack_monster": "指定目标怪兽，命令绑定军队开火；军队操控者不因受伤承担怪兽式资金损失。",
	}
	return {
		"name": "军令·%s%d" % [command_label(command), safe_rank],
		"kind": "military_command",
		"military_command": command,
		"bound_military_uid": unit_uid,
		"source_card": source_card,
		"rank": safe_rank,
		"cost": 0,
		"play_flow_required": 0,
		"cooldown": maxf(2.0, UNIT_COMMAND_COOLDOWN_SECONDS - float(safe_rank) * 0.35),
		"persistent": true,
		"damage": safe_rank,
		"move": 220.0 + float(safe_rank) * 55.0,
		"range": 220.0 + float(safe_rank) * 60.0,
		"repair_routes": 1 if command == "guard" else 0,
		"tags": ["军令", "固定技能", "军队"],
		"text": "%s（绑定一支短时防卫军；不占普通手牌上限，可冷却后重复使用。）" % str(descriptions.get(command, "命令己方唯一防卫军执行简单行动。")),
	}


func command_order() -> Array:
	return ["move", "guard", "strike_district", "attack_monster"]


func grant_bound_commands(player_index: int, unit_uid: int, rank: int, source_card: String, fixed_skill_count: int = -1) -> Array:
	var granted: Array = []
	var players := _players()
	if player_index < 0 or player_index >= players.size() or unit_uid <= 0:
		return granted
	var commands := command_order()
	var count := mini(maxi(1, fixed_skill_count if fixed_skill_count > 0 else rank), commands.size())
	var player := players[player_index] as Dictionary
	for index in range(count):
		var skill := make_command_skill(str(commands[index]), rank, unit_uid, source_card)
		if bool(_world_call(&"_acquire_inventory_skill_for_player", [player, skill, false])):
			granted.append(str(skill.get("name", "军令")))
	players[player_index] = player
	_write_world_value(&"players", players)
	return granted


func refresh_unit_from_skill(unit: Dictionary, skill: Dictionary, district_index: int = -1) -> Dictionary:
	var rank := clampi(int(skill.get("rank", _skill_rank(str(skill.get("name", ""))))), 1, 4)
	unit["rank"] = rank
	unit["name"] = unit_type_label(skill)
	unit["source_card"] = str(skill.get("name", unit["name"]))
	unit["military_type"] = str(skill.get("military_type", "defense"))
	unit["military_domain"] = str(skill.get("military_domain", "mixed"))
	unit["movement_traits"] = (skill.get("movement_traits", []) as Array).duplicate(true) if skill.get("movement_traits", []) is Array else []
	unit["terrain_move_multiplier"] = (skill.get("terrain_move_multiplier", {}) as Dictionary).duplicate(true) if skill.get("terrain_move_multiplier", {}) is Dictionary else {}
	unit["military_gdp_penalty"] = int(skill.get("military_gdp_penalty", 0))
	unit["military_gdp_pressure_seconds"] = float(skill.get("military_gdp_pressure_seconds", 0.0))
	unit["military_strike_gdp_penalty"] = int(skill.get("military_strike_gdp_penalty", 0))
	unit["military_strike_route_damage"] = int(skill.get("military_strike_route_damage", 0))
	unit["hp"] = unit_hp(skill)
	unit["max_hp"] = int(unit["hp"])
	unit["damage"] = unit_damage(skill)
	unit["range"] = unit_range(skill)
	unit["move"] = unit_move(skill)
	unit["duration"] = unit_duration(skill)
	unit["remaining_time"] = float(unit["duration"])
	if district_index >= 0 and district_index < _districts().size():
		unit["position"] = district_index
		unit["world_position"] = _district_center(district_index)
	return unit


func summon_from_card(player_index: int, skill: Dictionary) -> bool:
	var players := _players()
	var districts := _districts()
	var selection: TableSelectionState = _world_bridge.table_selection_state() if _world_bridge != null else null
	var selected_district: int = selection.selected_district if selection != null else -1
	if player_index < 0 or player_index >= players.size():
		return false
	if selected_district < 0 or selected_district >= districts.size() or bool((districts[selected_district] as Dictionary).get("destroyed", false)):
		_log("%s需要选中一个未毁区域作为军队部署点。" % str(skill.get("name", "军队牌")))
		return false
	if not can_deploy_at_district(skill, selected_district):
		_log("%s只能部署在%s；当前区域是%s。" % [str(skill.get("name", "军队牌")), deploy_terrain_label(skill), "海洋" if str((districts[selected_district] as Dictionary).get("terrain", "land")) == "ocean" else "陆地"])
		return false
	var rank := clampi(int(skill.get("rank", _skill_rank(str(skill.get("name", ""))))), 1, 4)
	var existing_index := oldest_owned_unit_index(player_index) if owned_active_unit_count(player_index) >= player_control_limit(player_index) else -1
	var unit: Dictionary
	if existing_index >= 0:
		unit = military_units[existing_index] as Dictionary
		var old_uid := int(unit.get("uid", 0))
		unit = refresh_unit_from_skill(unit, skill, selected_district)
		military_units[existing_index] = unit
		_invalidate_bound_commands(old_uid, "防卫军已被新军队牌刷新，旧军令失效。")
	else:
		unit = {
			"uid": next_military_unit_uid,
			"owner": player_index,
			"position": selected_district,
			"world_position": _district_center(selected_district),
			"cooldown_left": 0.0,
			"public_owner_revealed": false,
		}
		next_military_unit_uid += 1
		unit = refresh_unit_from_skill(unit, skill, selected_district)
		military_units.append(unit)
	var label := unit_type_label(unit)
	var granted := grant_bound_commands(player_index, int(unit.get("uid", 0)), rank, str(skill.get("name", label)), int(skill.get("fixed_skill_count", rank)))
	if _visual_cue_runtime_owner != null:
		_visual_cue_runtime_owner.add_visual_trail(_district_center(selected_district) + Vector2(0, -70), _district_center(selected_district), unit_color(unit), label)
		_visual_cue_runtime_owner.add_action_callout(
		"匿名军队牌",
		("部署%s" % label) if existing_index < 0 else ("刷新%s" % label),
		"%s出现%s%s；%s，不会自主行动，只响应私有军令牌。" % [str((districts[selected_district] as Dictionary).get("name", "选区")), label, str(_world_call(&"_level_text", [rank])), mobility_summary(unit)],
		unit_color(unit),
		_entity_world_position(unit),
		)
	_log("匿名军队牌结算：%s在%s%s一支%s；该玩家军队上限%d；%s。新军令：%s。" % [
		str(skill.get("name", label)),
		str((districts[selected_district] as Dictionary).get("name", "区域")),
		"刷新" if existing_index >= 0 else "部署",
		label,
		player_control_limit(player_index),
		mobility_summary(unit),
		str(_world_call(&"_limited_name_list", [granted, 4, "无"])),
	])
	if _table_presentation_refresh_port != null:
		_table_presentation_refresh_port.request_immediate(&"full", &"military_state_changed")
	return true


func remove_unit(index: int, reason: String) -> bool:
	if index < 0 or index >= military_units.size():
		return false
	var unit := military_units[index] as Dictionary
	_invalidate_bound_commands(int(unit.get("uid", 0)))
	if _visual_cue_runtime_owner != null:
		_visual_cue_runtime_owner.add_action_callout("匿名%s" % unit_type_label(unit), "撤离", reason, Color("#94a3b8"), _entity_world_position(unit))
	_log("匿名%s撤离：%s" % [unit_type_label(unit), reason])
	military_units.remove_at(index)
	return true


func trigger_command(skill: Dictionary, target_slot: int = -1, acting_player_index: int = -1, command_context: Dictionary = {}) -> bool:
	var players := _players()
	var districts := _districts()
	var player_index := acting_player_index
	if player_index < 0 or player_index >= players.size():
		return false
	var unit_index := unit_index_by_uid(int(skill.get("bound_military_uid", 0)))
	if unit_index < 0:
		unit_index = owned_active_unit_index(player_index)
	if unit_index < 0:
		_log("%s没有可接收军令的防卫军。" % str(skill.get("name", "军令")))
		return false
	var unit := military_units[unit_index] as Dictionary
	var label := unit_type_label(unit)
	if int(unit.get("owner", -1)) != player_index:
		_log("%s绑定的军队已失效。" % str(skill.get("name", "军令")))
		return false
	if _entity_has_linear_motion(unit):
		_log("匿名%s正在按米/秒执行前一条移动军令，抵达后才能接收新军令。" % label)
		return false
	if float(unit.get("cooldown_left", 0.0)) > 0.0:
		_log("匿名%s仍在执行上一条军令，%.1fs后才能再次行动。" % [label, float(unit.get("cooldown_left", 0.0))])
		return false
	var command := str(skill.get("military_command", ""))
	var damage := maxi(1, int(unit.get("damage", skill.get("damage", 1))))
	var unit_region_index := _unit_region_index(unit)
	var base_command_range := maxf(80.0, float(unit.get("range", skill.get("range", 220.0))))
	var command_range := effective_command_range(unit, unit_region_index, base_command_range)
	var command_move := maxf(1.0, float(unit.get("move", skill.get("move", 220.0))))
	var source := "匿名%s·%s" % [label, _skill_family(str(skill.get("name", "军令")))]
	var before := _entity_world_position(unit)
	var table_selection: TableSelectionState = _world_bridge.table_selection_state() if _world_bridge != null else null
	var selected_district: int = table_selection.selected_district if table_selection != null else -1
	match command:
		"move":
			if not _valid_target_district(selected_district, districts):
				_log("%s需要选中一个未毁区域作为前进目标。" % str(skill.get("name", "军令")))
				return false
			var terrain_multiplier := terrain_move_multiplier(unit, selected_district)
			var base_move_speed_mps := _unit_base_movement_speed_mps(unit, selected_district, command_move)
			var move_speed_mps := unit_movement_speed_mps(unit, selected_district, command_move)
			var moved := float(_world_call(&"_start_entity_linear_motion", [unit, _district_center(selected_district), base_move_speed_mps, source, str(unit.get("military_domain", "")), -1.0, "military_move"]))
			if moved <= 0.5:
				_log("%s已经在目标附近。" % str(skill.get("name", "军令")))
				return false
			unit["linear_move_unit_label"] = label
			if _visual_cue_runtime_owner != null:
				_visual_cue_runtime_owner.add_visual_trail(before, _district_center(selected_district), unit_color(unit), "军令前进")
				_visual_cue_runtime_owner.add_action_callout("匿名%s" % label, "前进", "%s向%s推进%s（地形×%.2f）%s。" % [label, str((districts[selected_district] as Dictionary).get("name", "区域")), _meters_text(move_speed_mps) + "/秒", terrain_multiplier, "预计%s抵达" % _duration_short_text(moved / maxf(1.0, move_speed_mps))], unit_color(unit), _entity_world_position(unit))
		"guard":
			if not _valid_target_district(selected_district, districts):
				_log("%s需要选中一个未毁区域作为保卫目标。" % str(skill.get("name", "军令")))
				return false
			if _entity_distance_to_district(unit, selected_district) > command_range:
				_log("%s目标距离%s，超过军队支援半径%s。" % [str(skill.get("name", "军令")), _entity_distance_to_district_label(unit, selected_district), _meters_text(command_range)])
				return false
			var repair_variant: Variant = _region_infrastructure_world_bridge.call("submit_legacy_index_repair", selected_district, maxi(1, int(skill.get("rank", 1))), "military", source, float(_world_value(&"game_time", 0.0))) if _region_infrastructure_world_bridge != null and _region_infrastructure_world_bridge.has_method("submit_legacy_index_repair") else {"committed": false, "reason": "region_infrastructure_bridge_missing"}
			var repair_receipt: Dictionary = repair_variant if repair_variant is Dictionary else {"committed": false, "reason": "region_infrastructure_receipt_invalid"}
			var repaired := int(repair_receipt.get("applied_repair", 0))
			if _visual_cue_runtime_owner != null:
				_visual_cue_runtime_owner.add_action_callout("匿名%s" % label, "保卫区域", "%s获得%s支援：共享生命修复%d。" % [str((districts[selected_district] as Dictionary).get("name", "区域")), label, repaired], unit_color(unit), _district_center(selected_district))
		"strike_district":
			if not _valid_target_district(selected_district, districts):
				_log("%s需要选中一个未毁区域作为摧毁目标。" % str(skill.get("name", "军令")))
				return false
			if _entity_distance_to_district(unit, selected_district) > command_range:
				_log("%s目标距离%s，超过军队火力半径%s。" % [str(skill.get("name", "军令")), _entity_distance_to_district_label(unit, selected_district), _meters_text(command_range)])
				return false
			if _visual_cue_runtime_owner != null:
				_visual_cue_runtime_owner.add_monster_attack_effect(_entity_world_position(unit), _district_center(selected_district), source, command_range, unit_color(unit), true)
			var damage_variant: Variant = _region_infrastructure_world_bridge.call("submit_legacy_index_unit_damage", selected_district, damage, "military", source, float(_world_value(&"game_time", 0.0))) if _region_infrastructure_world_bridge != null and _region_infrastructure_world_bridge.has_method("submit_legacy_index_unit_damage") else {"committed": false, "reason": "region_infrastructure_bridge_missing"}
			var damage_receipt: Dictionary = damage_variant if damage_variant is Dictionary else {"committed": false, "reason": "region_infrastructure_receipt_invalid"}
			var applied_damage := int(damage_receipt.get("applied_damage", 0))
			if _visual_cue_runtime_owner != null:
				_visual_cue_runtime_owner.add_action_callout("匿名%s" % label, "摧毁区域", "%s轰击%s，共享生命-%d。" % [label, str((districts[selected_district] as Dictionary).get("name", "区域")), applied_damage], unit_color(unit), _district_center(selected_district))
		"attack_monster":
			var monsters := _monster_runtime_controller.roster_snapshot(true)
			if target_slot < 0 or target_slot >= monsters.size() or bool((monsters[target_slot] as Dictionary).get("down", false)):
				_log("%s需要指定一只有效怪兽。" % str(skill.get("name", "军令")))
				return false
			var target_actor := monsters[target_slot] as Dictionary
			var distance := float(_world_call(&"_wrapped_distance", [_entity_world_position(unit), _entity_world_position(target_actor)]))
			if distance > command_range:
				_log("%s目标怪%d·%s距离%s，超过军队火力半径%s。" % [str(skill.get("name", "军令")), target_slot + 1, str(target_actor.get("name", "怪兽")), _meters_text(distance), _meters_text(command_range)])
				return false
			if _runtime_command_pipeline == null:
				_log("%s未连接到权威模拟命令管线。" % str(skill.get("name", "军令")))
				return false
			var occurred_at_world_us := _presentation_world_clock.world_effective_micros() if _presentation_world_clock != null else maxi(1, int(round(float(_world_value(&"game_time", 0.0)) * 1000000.0)))
			var resolution_id := int(command_context.get("resolution_id", -1))
			var source_entity_id := "resolution:%d" % resolution_id if resolution_id >= 0 else source
			var damage_command := {
				"source": source,
				"source_kind": "military_command",
				"source_entity_id": source_entity_id,
				"unit_uid": int(unit.get("uid", 0)),
				"target_monster_uid": int(target_actor.get("uid", -1)),
				"damage": damage,
				"acting_player_index": player_index,
				"occurred_at_world_us": occurred_at_world_us,
			}
			var damage_command_receipt := _runtime_command_pipeline.dispatch_military_monster_damage(damage_command)
			if not bool(damage_command_receipt.get("handled", false)):
				_log("%s的攻击命令被权威模拟拒绝：%s。" % [str(skill.get("name", "军令")), str(damage_command_receipt.get("reason", "command_rejected"))])
				return false
			if _visual_cue_runtime_owner != null:
				_visual_cue_runtime_owner.add_monster_attack_effect(_entity_world_position(unit), _entity_world_position(target_actor), source, command_range, unit_color(unit), true)
			var applied_damage := int(damage_command_receipt.get("sink_receipt", {}).get("applied_damage", 0))
			if _visual_cue_runtime_owner != null:
				_visual_cue_runtime_owner.add_action_callout("匿名%s" % label, "攻击怪兽", "%s向怪%d·%s开火，造成%d点伤害。" % [label, target_slot + 1, str(target_actor.get("name", "怪兽")), applied_damage], unit_color(unit), _entity_world_position(target_actor))
		_:
			_log("%s尚未接入军令结算。" % str(skill.get("name", "军令")))
			return false
	unit["cooldown_left"] = maxf(float(unit.get("cooldown_left", 0.0)), maxf(1.0, float(skill.get("cooldown", UNIT_COMMAND_COOLDOWN_SECONDS))))
	military_units[unit_index] = unit
	_log("匿名%s执行%s；下令者不公开，军队不会自主行动。" % [label, _skill_family(str(skill.get("name", "军令")))])
	if _route_network_runtime_controller != null:
		_route_network_runtime_controller.refresh_routes()
	if _product_market_runtime_controller != null:
		_product_market_runtime_controller.refresh_prices()
	if _table_presentation_refresh_port != null:
		_table_presentation_refresh_port.request_immediate(&"full", &"military_state_changed")
	return true


func force_balance_role(skill: Dictionary) -> String:
	match str(skill.get("military_type", "defense")):
		"fighter": return "高速截击/猎兽/补位防守"
		"bomber": return "城市GDP压制/做空配合"
		"tank": return "陆地耐久防守/近距推进"
		"missile": return "远程威慑/位置可读"
		"submarine": return "海路伏击/海运封锁"
		"warship": return "海域护航/岸线炮击"
	return "基础防卫/短时守城"


func force_balance_pressure_score(skill: Dictionary) -> int:
	return int(round(float(unit_gdp_pressure(skill, "strike_district")) * maxf(1.0, unit_gdp_pressure_seconds(skill)) / 10.0)) + int(skill.get("military_strike_route_damage", 0)) * 18


func force_balance_entry(card_name: String, skill: Dictionary) -> Dictionary:
	var multipliers: Dictionary = skill.get("terrain_move_multiplier", {}) if skill.get("terrain_move_multiplier", {}) is Dictionary else {}
	var move_value := unit_move(skill)
	var range_value := unit_range(skill)
	var hp_value := unit_hp(skill)
	var damage_value := unit_damage(skill)
	var duration_value := unit_duration(skill)
	return {
		"name": card_name,
		"family": _skill_family(card_name),
		"rank": clampi(_skill_rank(card_name), 1, 4),
		"type": str(skill.get("military_type", "defense")),
		"domain": str(skill.get("military_domain", "mixed")),
		"role": force_balance_role(skill),
		"hp": hp_value,
		"damage": damage_value,
		"move": move_value,
		"range": range_value,
		"duration": duration_value,
		"land_multiplier": float(multipliers.get("land", 1.0)),
		"ocean_multiplier": float(multipliers.get("ocean", 1.0)),
		"gdp_pressure": unit_gdp_pressure(skill, "strike_district"),
		"gdp_pressure_seconds": unit_gdp_pressure_seconds(skill),
		"route_damage": int(skill.get("military_strike_route_damage", 0)),
		"pressure_score": force_balance_pressure_score(skill),
		"mobility_score": int(round(move_value * maxf(float(multipliers.get("land", 1.0)), float(multipliers.get("ocean", 1.0))) / 10.0 + range_value / 20.0)),
		"durability_score": int(round(float(hp_value) * 3.0 + duration_value / 2.0)),
	}


func force_balance_report() -> Dictionary:
	var families := {}
	var family_names: Array = []
	var issues: Array = []
	var card_ids := _card_runtime_catalog_service.ordered_card_ids() if _card_runtime_catalog_service != null else []
	for card_name_variant in card_ids:
		var card_name := str(card_name_variant)
		var skill := _make_skill(card_name)
		if str(skill.get("kind", "")) != "military_force":
			continue
		var entry := force_balance_entry(card_name, skill)
		var type_key := str(entry.get("type", "defense"))
		var family_key := str(entry.get("family", card_name))
		if not families.has(type_key):
			families[type_key] = {"count": 0, "families": [], "cards": [], "role": str(entry.get("role", "")), "domain": str(entry.get("domain", "mixed")), "max_hp": 0, "max_damage": 0, "max_move": 0.0, "max_range": 0.0, "max_duration": 0.0, "max_gdp_pressure": 0, "max_pressure_score": 0, "max_route_damage": 0, "max_mobility_score": 0, "max_durability_score": 0, "min_land_multiplier": 999.0, "max_land_multiplier": 0.0, "min_ocean_multiplier": 999.0, "max_ocean_multiplier": 0.0}
		var summary := families[type_key] as Dictionary
		summary["count"] = int(summary.get("count", 0)) + 1
		var summary_families: Array = summary.get("families", [])
		if not summary_families.has(family_key): summary_families.append(family_key)
		summary["families"] = summary_families
		var cards: Array = summary.get("cards", [])
		cards.append(card_name)
		summary["cards"] = cards
		for field in ["hp", "damage", "move", "range", "duration", "gdp_pressure", "pressure_score", "route_damage", "mobility_score", "durability_score"]:
			var target_field := "max_%s" % field
			if entry.get(field, 0) is float:
				summary[target_field] = maxf(float(summary.get(target_field, 0.0)), float(entry.get(field, 0.0)))
			else:
				summary[target_field] = maxi(int(summary.get(target_field, 0)), int(entry.get(field, 0)))
		summary["min_land_multiplier"] = minf(float(summary.get("min_land_multiplier", 999.0)), float(entry.get("land_multiplier", 1.0)))
		summary["max_land_multiplier"] = maxf(float(summary.get("max_land_multiplier", 0.0)), float(entry.get("land_multiplier", 1.0)))
		summary["min_ocean_multiplier"] = minf(float(summary.get("min_ocean_multiplier", 999.0)), float(entry.get("ocean_multiplier", 1.0)))
		summary["max_ocean_multiplier"] = maxf(float(summary.get("max_ocean_multiplier", 0.0)), float(entry.get("ocean_multiplier", 1.0)))
		families[type_key] = summary
		if not family_names.has(family_key): family_names.append(family_key)
	for required_type in ["defense", "fighter", "bomber", "tank", "missile", "submarine", "warship"]:
		if not families.has(required_type): issues.append("缺少军种:%s" % required_type)
		elif int((families[required_type] as Dictionary).get("count", 0)) < 4: issues.append("%s军种少于I-IV四张" % required_type)
	for family_variant in family_names:
		var family_name := str(family_variant)
		var previous := {"hp": -1, "damage": -1, "duration": -1.0, "pressure_score": -1, "route_damage": -1}
		for rank in range(1, 5):
			var card_name := "%s%d" % [family_name, rank]
			if _card_runtime_catalog_service == null or not _card_runtime_catalog_service.has_card(card_name):
				issues.append("%s缺少%d级" % [family_name, rank])
				continue
			var entry := force_balance_entry(card_name, _make_skill(card_name))
			for field in previous.keys():
				if float(previous[field]) >= 0.0 and float(entry.get(field, 0)) < float(previous[field]): issues.append("%s %s梯度倒退" % [card_name, field])
				previous[field] = entry.get(field, 0)
	if families.has("fighter") and families.has("bomber") and float((families["fighter"] as Dictionary).get("max_move", 0.0)) <= float((families["bomber"] as Dictionary).get("max_move", 0.0)): issues.append("战斗机机动应高于轰炸机")
	if families.has("fighter") and families.has("missile") and float((families["fighter"] as Dictionary).get("max_move", 0.0)) <= float((families["missile"] as Dictionary).get("max_move", 0.0)): issues.append("战斗机机动应高于导弹阵地")
	if families.has("bomber") and families.has("fighter") and int((families["bomber"] as Dictionary).get("max_gdp_pressure", 0)) <= int((families["fighter"] as Dictionary).get("max_gdp_pressure", 0)): issues.append("轰炸机GDP压制应高于战斗机")
	if families.has("bomber") and families.has("warship") and int((families["bomber"] as Dictionary).get("max_gdp_pressure", 0)) <= int((families["warship"] as Dictionary).get("max_gdp_pressure", 0)): issues.append("轰炸机应是最高城市GDP压制军种")
	if families.has("missile") and families.has("bomber") and float((families["missile"] as Dictionary).get("max_range", 0.0)) <= float((families["bomber"] as Dictionary).get("max_range", 0.0)): issues.append("导弹阵地射程应高于轰炸机")
	if families.has("tank") and families.has("fighter") and int((families["tank"] as Dictionary).get("max_hp", 0)) <= int((families["fighter"] as Dictionary).get("max_hp", 0)): issues.append("坦克耐久应高于战斗机")
	if families.has("tank") and float((families["tank"] as Dictionary).get("max_ocean_multiplier", 1.0)) >= 0.5: issues.append("坦克跨海能力过高")
	if families.has("submarine") and float((families["submarine"] as Dictionary).get("max_ocean_multiplier", 0.0)) <= float((families["submarine"] as Dictionary).get("max_land_multiplier", 0.0)): issues.append("潜艇海域机动应高于陆地")
	if families.has("warship") and float((families["warship"] as Dictionary).get("max_ocean_multiplier", 0.0)) <= float((families["warship"] as Dictionary).get("max_land_multiplier", 0.0)): issues.append("战舰海域机动应高于陆地")
	for route_type in ["bomber", "missile", "submarine", "warship"]:
		if families.has(route_type) and int((families[route_type] as Dictionary).get("max_route_damage", 0)) <= 0: issues.append("%s缺少显式断路打击" % route_type)
	for low_route_type in ["defense", "fighter", "tank"]:
		if families.has(low_route_type) and int((families[low_route_type] as Dictionary).get("max_route_damage", 0)) > 0: issues.append("%s不应偷走断路专长" % low_route_type)
	return {"ok": issues.is_empty(), "issues": issues, "families": families, "summary": "军队身份：战斗机高机动，轰炸机主压GDP，坦克主耐久，导弹主射程，潜艇/战舰主海域路线。"}


func to_save_data() -> Dictionary:
	return {
		"schema_version": SAVE_STATE_VERSION,
		"ruleset_id": SAVE_RULESET_ID,
		"military_units": military_units.duplicate(true),
		"next_military_unit_uid": next_military_unit_uid,
		"bankruptcy_estate_journal": _bankruptcy_estate_journal.duplicate(true),
	}


func preflight_save_data(data: Dictionary) -> Dictionary:
	var validation := _validate_save_data(data)
	if not bool(validation.get("valid", false)):
		var reason_code := str(validation.get("reason_code", "military_save_invalid"))
		return {"accepted": false, "reason": reason_code, "reason_code": reason_code}
	return {
		"accepted": true,
		"reason": "",
		"reason_code": "military_save_valid",
		"normalized_state": data.duplicate(true),
	}


## Candidate-only registry preflight. All roster and geography references are
## resolved from normalized save sections, never from a partially applied world.
func preflight_restore_dependencies(section_state: Dictionary, all_normalized_states: Dictionary) -> Dictionary:
	var section_preflight := preflight_save_data(section_state)
	if not bool(section_preflight.get("accepted", false)):
		return _restore_dependency_rejection("military_dependency_section_invalid")
	if not (all_normalized_states.get("session") is Dictionary) \
			or not (all_normalized_states.get("region_infrastructure") is Dictionary):
		return _restore_dependency_rejection("military_dependency_section_missing")
	var context := _military_restore_dependency_context(
		all_normalized_states.get("session") as Dictionary,
		all_normalized_states.get("region_infrastructure") as Dictionary
	)
	if not bool(context.get("valid", false)):
		return _restore_dependency_rejection(str(context.get("reason_code", "military_dependency_context_invalid")))
	var referenced_unit_count := 0
	for unit_variant in section_state.get("military_units") as Array:
		var unit_result := _validate_military_restore_unit(unit_variant as Dictionary, context)
		if not bool(unit_result.get("valid", false)):
			return _restore_dependency_rejection(str(unit_result.get("reason_code", "military_dependency_unit_invalid")))
		referenced_unit_count += 1
	var journal := section_state.get("bankruptcy_estate_journal") as Dictionary
	for record_variant in journal.values():
		var record := record_variant as Dictionary
		for player_variant in record.get("player_indices") as Array:
			if not (context.get("player_indices") as Dictionary).has(str(int(player_variant))):
				return _restore_dependency_rejection("military_dependency_bankruptcy_player_missing")
		for snapshot_field in ["preimage", "postimage"]:
			if not record.has(snapshot_field):
				continue
			for unit_variant in record.get(snapshot_field) as Array:
				var unit_result := _validate_military_restore_unit(unit_variant as Dictionary, context)
				if not bool(unit_result.get("valid", false)):
					return _restore_dependency_rejection(str(unit_result.get("reason_code", "military_dependency_journal_unit_invalid")))
				referenced_unit_count += 1
	return {
		"accepted": true,
		"reason": "",
		"reason_code": "military_restore_dependencies_valid",
		"referenced_unit_count": referenced_unit_count,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		var rejection := str(preflight.get("reason_code", "military_save_invalid"))
		return {"applied": false, "reason": rejection, "reason_code": rejection}
	var normalized := (preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
	military_units = (normalized.get("military_units") as Array).duplicate(true)
	next_military_unit_uid = int(normalized.get("next_military_unit_uid"))
	_bankruptcy_estate_journal = (normalized.get("bankruptcy_estate_journal") as Dictionary).duplicate(true)
	return {
		"applied": true,
		"reason": "military_state_restored",
		"reason_code": "military_state_restored",
		"unit_count": military_units.size(),
		"next_uid": next_military_unit_uid,
	}


func capture_runtime_checkpoint() -> Dictionary:
	return to_save_data()


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var receipt := apply_save_data(checkpoint)
	return {
		"restored": bool(receipt.get("applied", false)),
		"reason_code": str(receipt.get("reason_code", "military_save_invalid")),
	}


func rollback_save_data(checkpoint: Dictionary) -> Dictionary:
	return apply_save_data(checkpoint)


func _military_restore_dependency_context(session_state: Dictionary, infrastructure_state: Dictionary) -> Dictionary:
	if not (session_state.get("world_session_state") is Dictionary) \
			or not (infrastructure_state.get("regions") is Array):
		return {"valid": false, "reason_code": "military_dependency_context_shape_invalid"}
	var world_state := session_state.get("world_session_state") as Dictionary
	if not (world_state.get("players") is Array) or not (world_state.get("districts") is Array):
		return {"valid": false, "reason_code": "military_dependency_session_world_invalid"}
	var players := world_state.get("players") as Array
	var districts := world_state.get("districts") as Array
	var player_indices: Dictionary = {}
	for player_index in range(players.size()):
		var player_variant: Variant = players[player_index]
		if not (player_variant is Dictionary) \
				or not ((player_variant as Dictionary).get("id") is int) \
				or int((player_variant as Dictionary).get("id")) != player_index:
			return {"valid": false, "reason_code": "military_dependency_player_roster_invalid"}
		player_indices[str(player_index)] = true
	var district_region_by_index: Dictionary = {}
	for district_index in range(districts.size()):
		var district_variant: Variant = districts[district_index]
		if not (district_variant is Dictionary):
			return {"valid": false, "reason_code": "military_dependency_district_roster_invalid"}
		var region_id := str((district_variant as Dictionary).get("region_id", ""))
		if region_id.is_empty():
			return {"valid": false, "reason_code": "military_dependency_district_roster_invalid"}
		district_region_by_index[str(district_index)] = region_id
	var infrastructure_region_by_index: Dictionary = {}
	var infrastructure_region_ids: Dictionary = {}
	for region_variant in infrastructure_state.get("regions") as Array:
		if not (region_variant is Dictionary):
			return {"valid": false, "reason_code": "military_dependency_region_roster_invalid"}
		var region := region_variant as Dictionary
		var region_id := str(region.get("region_id", ""))
		var legacy_index := int(region.get("legacy_index", -1))
		if region_id.is_empty() or infrastructure_region_ids.has(region_id):
			return {"valid": false, "reason_code": "military_dependency_region_roster_invalid"}
		infrastructure_region_ids[region_id] = true
		if legacy_index < 0:
			continue
		var legacy_key := str(legacy_index)
		if infrastructure_region_by_index.has(legacy_key) \
				or not district_region_by_index.has(legacy_key) \
				or str(district_region_by_index.get(legacy_key)) != region_id:
			return {"valid": false, "reason_code": "military_dependency_region_district_mismatch"}
		infrastructure_region_by_index[legacy_key] = region_id
	return {
		"valid": true,
		"reason_code": "military_dependency_context_valid",
		"player_indices": player_indices,
		"district_region_by_index": district_region_by_index,
		"infrastructure_region_by_index": infrastructure_region_by_index,
		"infrastructure_region_ids": infrastructure_region_ids,
	}


func _validate_military_restore_unit(unit: Dictionary, context: Dictionary) -> Dictionary:
	var owner_key := str(int(unit.get("owner", -1)))
	if not (context.get("player_indices") as Dictionary).has(owner_key):
		return {"valid": false, "reason_code": "military_dependency_unit_owner_missing"}
	var position := int(unit.get("position", -1))
	if position >= 0 and not _military_restore_district_valid(position, context):
		return {"valid": false, "reason_code": "military_dependency_unit_district_missing"}
	if unit.has("region_id"):
		var region_id := str(unit.get("region_id", ""))
		if region_id.is_empty() or not (context.get("infrastructure_region_ids") as Dictionary).has(region_id) \
				or position >= 0 and str((context.get("district_region_by_index") as Dictionary).get(str(position), "")) != region_id:
			return {"valid": false, "reason_code": "military_dependency_unit_region_missing"}
	var motion_present := false
	for key_variant in unit.keys():
		if str(key_variant).begins_with("linear_move_"):
			motion_present = true
			break
	if motion_present:
		var target_district := int(unit.get("linear_move_target_district", -1))
		if not _military_restore_district_valid(target_district, context):
			return {"valid": false, "reason_code": "military_dependency_motion_target_missing"}
		for district_variant in unit.get("linear_move_damaged_districts", []) as Array:
			if not _military_restore_district_valid(int(district_variant), context):
				return {"valid": false, "reason_code": "military_dependency_motion_district_missing"}
	return {"valid": true, "reason_code": "military_dependency_unit_valid"}


func _military_restore_district_valid(district_index: int, context: Dictionary) -> bool:
	var key := str(district_index)
	return district_index >= 0 \
		and (context.get("district_region_by_index") as Dictionary).has(key) \
		and (context.get("infrastructure_region_by_index") as Dictionary).has(key) \
		and str((context.get("district_region_by_index") as Dictionary).get(key, "")) \
			== str((context.get("infrastructure_region_by_index") as Dictionary).get(key, ""))


func _restore_dependency_rejection(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason": reason_code, "reason_code": reason_code}


func _validate_save_data(data: Dictionary) -> Dictionary:
	if not StrictState.is_codec_data(data) or StrictState.contains_rng_continuation(data):
		return {"valid": false, "reason_code": "military_save_not_codec_data"}
	if not StrictState.has_exact_keys(data, SAVE_KEYS):
		return {"valid": false, "reason_code": "military_save_shape_invalid"}
	if not (data.get("schema_version") is int) or int(data.get("schema_version")) != SAVE_STATE_VERSION \
			or not (data.get("ruleset_id") is String) or str(data.get("ruleset_id")) != SAVE_RULESET_ID:
		return {"valid": false, "reason_code": "military_save_header_invalid"}
	if not (data.get("military_units") is Array) \
			or not (data.get("next_military_unit_uid") is int) \
			or not (data.get("bankruptcy_estate_journal") is Dictionary):
		return {"valid": false, "reason_code": "military_save_fields_invalid"}
	var unit_validation := _validate_unit_array(data.get("military_units") as Array)
	if not bool(unit_validation.get("valid", false)):
		return unit_validation
	if int(data.get("next_military_unit_uid")) <= int(unit_validation.get("maximum_uid", 0)):
		return {"valid": false, "reason_code": "military_next_uid_dangling"}
	var journal_validation := _validate_bankruptcy_journal(data.get("bankruptcy_estate_journal") as Dictionary)
	if not bool(journal_validation.get("valid", false)):
		return journal_validation
	return {"valid": true, "reason_code": "military_save_valid"}


func _validate_unit_array(units: Array) -> Dictionary:
	var seen_uids: Dictionary = {}
	var maximum_uid := 0
	for unit_variant in units:
		if not (unit_variant is Dictionary):
			return {"valid": false, "reason_code": "military_unit_not_dictionary"}
		var unit := unit_variant as Dictionary
		var validation := _validate_unit(unit)
		if not bool(validation.get("valid", false)):
			return validation
		var uid := int(unit.get("uid"))
		if seen_uids.has(str(uid)):
			return {"valid": false, "reason_code": "military_unit_uid_duplicate"}
		seen_uids[str(uid)] = true
		maximum_uid = maxi(maximum_uid, uid)
	return {"valid": true, "reason_code": "military_units_valid", "maximum_uid": maximum_uid}


func _validate_unit(unit: Dictionary) -> Dictionary:
	if not StrictState.is_codec_data(unit) or StrictState.contains_rng_continuation(unit):
		return {"valid": false, "reason_code": "military_unit_not_codec_data"}
	for key_variant in REQUIRED_UNIT_KEYS:
		if not unit.has(str(key_variant)):
			return {"valid": false, "reason_code": "military_unit_field_missing"}
	if not (unit.get("uid") is int) or int(unit.get("uid")) <= 0 \
			or not (unit.get("owner") is int) or int(unit.get("owner")) < 0 \
			or not (unit.get("position") is int) or int(unit.get("position")) < -1 \
			or not (unit.get("world_position") is Vector2) \
			or not (unit.get("public_owner_revealed") is bool) \
			or not (unit.get("rank") is int) or int(unit.get("rank")) < 1 or int(unit.get("rank")) > 4:
		return {"valid": false, "reason_code": "military_unit_identity_invalid"}
	for key in ["name", "source_card", "military_type", "military_domain"]:
		if not (unit.get(key) is String) or str(unit.get(key)).is_empty():
			return {"valid": false, "reason_code": "military_unit_identity_invalid"}
	if not (unit.get("movement_traits") is Array) or not (unit.get("terrain_move_multiplier") is Dictionary):
		return {"valid": false, "reason_code": "military_unit_mobility_invalid"}
	var seen_traits: Dictionary = {}
	for trait_variant in unit.get("movement_traits") as Array:
		if not (trait_variant is String) or str(trait_variant).is_empty() or seen_traits.has(str(trait_variant)):
			return {"valid": false, "reason_code": "military_unit_mobility_invalid"}
		seen_traits[str(trait_variant)] = true
	for multiplier_variant in (unit.get("terrain_move_multiplier") as Dictionary).values():
		if not _finite_number(multiplier_variant, 0.0, false):
			return {"valid": false, "reason_code": "military_unit_mobility_invalid"}
	for key in ["military_gdp_penalty", "military_strike_gdp_penalty", "military_strike_route_damage"]:
		if not (unit.get(key) is int) or int(unit.get(key)) < 0:
			return {"valid": false, "reason_code": "military_unit_stat_invalid"}
	for key in ["hp", "max_hp", "damage"]:
		if not (unit.get(key) is int) or int(unit.get(key)) <= 0:
			return {"valid": false, "reason_code": "military_unit_stat_invalid"}
	if int(unit.get("hp")) > int(unit.get("max_hp")):
		return {"valid": false, "reason_code": "military_unit_stat_invalid"}
	for key in ["cooldown_left", "military_gdp_pressure_seconds", "range", "move", "duration", "remaining_time"]:
		if not _finite_number(unit.get(key), 0.0, true):
			return {"valid": false, "reason_code": "military_unit_nonfinite"}
	if float(unit.get("range")) <= 0.0 or float(unit.get("move")) <= 0.0 or float(unit.get("duration")) <= 0.0 \
			or float(unit.get("remaining_time")) > float(unit.get("duration")):
		return {"valid": false, "reason_code": "military_unit_stat_invalid"}
	var motion_present := false
	for key_variant in unit.keys():
		if str(key_variant).begins_with("linear_move_"):
			motion_present = true
			break
	if motion_present:
		for key_variant in LINEAR_MOTION_REQUIRED_KEYS:
			if not unit.has(str(key_variant)):
				return {"valid": false, "reason_code": "military_motion_binding_dangling"}
		if not (unit.get("linear_move_target_position") is Vector2) \
				or not (unit.get("linear_move_target_district") is int) \
				or not _finite_number(unit.get("linear_move_speed_mps"), 0.0, false) \
				or not _finite_number(unit.get("linear_move_started_at"), 0.0, true) \
				or not (unit.get("linear_move_source") is String) \
				or not (unit.get("linear_move_mode") is String) \
				or not (unit.get("linear_move_arrival_action") is String) \
				or not (unit.get("linear_move_damaged_districts") is Array):
			return {"valid": false, "reason_code": "military_motion_binding_dangling"}
		var seen_districts: Dictionary = {}
		for district_variant in unit.get("linear_move_damaged_districts") as Array:
			if not (district_variant is int) or int(district_variant) < 0 or seen_districts.has(str(int(district_variant))):
				return {"valid": false, "reason_code": "military_motion_binding_dangling"}
			seen_districts[str(int(district_variant))] = true
	return {"valid": true, "reason_code": "military_unit_valid"}


func _validate_bankruptcy_journal(journal: Dictionary) -> Dictionary:
	if journal.size() > 512:
		return {"valid": false, "reason_code": "military_bankruptcy_journal_too_large"}
	for transaction_id_variant in journal.keys():
		if not (transaction_id_variant is String or transaction_id_variant is StringName):
			return {"valid": false, "reason_code": "military_bankruptcy_transaction_invalid"}
		var transaction_id := str(transaction_id_variant)
		var record_variant: Variant = journal.get(transaction_id_variant)
		if transaction_id.is_empty() or transaction_id.length() > 160 or not (record_variant is Dictionary):
			return {"valid": false, "reason_code": "military_bankruptcy_transaction_invalid"}
		var record := record_variant as Dictionary
		var state := str(record.get("state", ""))
		var expected_keys := BANKRUPTCY_RECORD_BASE_KEYS if state == "finalized" else BANKRUPTCY_RECORD_OPEN_KEYS
		if not ["prepared", "committed", "rolled_back", "finalized"].has(state) \
				or not StrictState.has_exact_keys(record, expected_keys) \
				or not _valid_fingerprint(str(record.get("expected_hash", ""))) \
				or not (record.get("player_indices") is Array) \
				or not (record.get("estate_counts") is Dictionary):
			return {"valid": false, "reason_code": "military_bankruptcy_record_invalid"}
		var seen_players: Dictionary = {}
		for player_variant in record.get("player_indices") as Array:
			if not (player_variant is int) or int(player_variant) < 0 or seen_players.has(str(int(player_variant))):
				return {"valid": false, "reason_code": "military_bankruptcy_record_invalid"}
			seen_players[str(int(player_variant))] = true
		var counts := record.get("estate_counts") as Dictionary
		if not StrictState.has_exact_keys(counts, ["military_units_removed"]) \
				or not (counts.get("military_units_removed") is int) or int(counts.get("military_units_removed")) < 0:
			return {"valid": false, "reason_code": "military_bankruptcy_record_invalid"}
		if state != "finalized":
			if not (record.get("preimage") is Array) or not (record.get("postimage") is Array) \
					or not bool(_validate_unit_array(record.get("preimage") as Array).get("valid", false)) \
					or not bool(_validate_unit_array(record.get("postimage") as Array).get("valid", false)):
				return {"valid": false, "reason_code": "military_bankruptcy_record_invalid"}
	return {"valid": true, "reason_code": "military_bankruptcy_journal_valid"}


func _finite_number(value: Variant, lower_bound: float, allow_equal: bool) -> bool:
	if not (value is int or value is float) or not is_finite(float(value)):
		return false
	return float(value) >= lower_bound if allow_equal else float(value) > lower_bound


func _valid_fingerprint(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


func debug_snapshot(viewer_index: int = -1) -> Dictionary:
	var public_roster: Array = []
	for unit_variant in military_units:
		if not (unit_variant is Dictionary):
			continue
		var unit := unit_variant as Dictionary
		var world_position: Vector2 = unit.get("world_position", Vector2.ZERO)
		var public_unit := {
			"uid": int(unit.get("uid", 0)),
			"name": str(unit.get("name", "军队")),
			"rank": int(unit.get("rank", 1)),
			"military_type": str(unit.get("military_type", "defense")),
			"position": int(unit.get("position", -1)),
			"world_position": {"x": world_position.x, "y": world_position.y},
			"hp": int(unit.get("hp", 0)),
			"remaining_time": float(unit.get("remaining_time", 0.0)),
			"cooldown_left": float(unit.get("cooldown_left", 0.0)),
		}
		if bool(unit.get("public_owner_revealed", false)) or int(unit.get("owner", -1)) == viewer_index:
			public_unit["owner"] = int(unit.get("owner", -1))
		public_roster.append(public_unit)
	return {
		"controller_ready": _configured and _world_bridge != null and _world_bridge.has_world(),
		"controller_authoritative": true,
		"runtime_owner": "MilitaryRuntimeController",
		"parallel_legacy_owner": false,
		"unit_count": military_units.size(),
		"next_uid": next_military_unit_uid,
		"schema_version": SAVE_STATE_VERSION,
		"bankruptcy_transaction_count": _bankruptcy_estate_journal.size(),
		"owns_rng_continuation": false,
		"roster": public_roster,
		"inventory_service_bound": _inventory_service != null,
		"monster_controller_bound": _monster_runtime_controller != null,
		"weather_controller_bound": _weather_runtime_controller != null,
		"default_duration_seconds": UNIT_DEFAULT_DURATION_SECONDS,
		"default_command_cooldown_seconds": UNIT_COMMAND_COOLDOWN_SECONDS,
	}


func _update_units(delta: float) -> void:
	var districts := _districts()
	for index in range(military_units.size() - 1, -1, -1):
		var unit := military_units[index] as Dictionary
		if _entity_has_linear_motion(unit):
			var base_motion_speed := maxf(0.0, float(unit.get("linear_move_speed_mps", 0.0)))
			var region_index := _unit_region_index(unit)
			var weather := military_weather_effect_snapshot(unit, region_index)
			unit["linear_move_speed_mps"] = base_motion_speed * float(weather.get("movement_multiplier", 1.0))
			var info_variant: Variant = _world_call(&"_advance_entity_linear_motion", [unit, delta])
			if unit.has("linear_move_speed_mps"):
				unit["linear_move_speed_mps"] = base_motion_speed
			var info: Dictionary = info_variant if info_variant is Dictionary else {}
			if bool(info.get("arrived", false)):
				var district_index := int(info.get("target_district", unit.get("position", -1)))
				if district_index < 0 or district_index >= districts.size():
					district_index = int(unit.get("position", _world_call(&"_nearest_district_to", [_entity_world_position(unit)])))
				var label := unit_type_label(unit)
				if _visual_cue_runtime_owner != null:
					_visual_cue_runtime_owner.add_action_callout("匿名%s" % label, "抵达", "%s抵达%s。" % [label, str((districts[district_index] as Dictionary).get("name", "区域"))], unit_color(unit), _entity_world_position(unit))
				_world_call(&"_clear_entity_linear_motion", [unit])
		unit["remaining_time"] = maxf(0.0, float(unit.get("remaining_time", 0.0)) - delta)
		unit["cooldown_left"] = maxf(0.0, float(unit.get("cooldown_left", 0.0)) - delta)
		if float(unit.get("remaining_time", 0.0)) <= 0.0 or int(unit.get("hp", 0)) <= 0:
			remove_unit(index, "在场时间结束或战力耗尽。")
			continue
		military_units[index] = unit


func _unit_region_index(unit: Dictionary) -> int:
	var region_index := int(unit.get("position", -1))
	if region_index >= 0:
		return region_index
	var nearest_variant: Variant = _world_call(&"_nearest_district_to", [_entity_world_position(unit)])
	return int(nearest_variant) if nearest_variant != null else -1


func _invalidate_bound_commands(unit_uid: int, reason: String = "绑定军队已离场，此军令失效。") -> void:
	if unit_uid <= 0 or _inventory_service == null:
		return
	var players := _players()
	for player_index in range(players.size()):
		var player := players[player_index] as Dictionary
		_inventory_service.invalidate_bound_military_commands(player, unit_uid, reason)
		players[player_index] = player
	_write_world_value(&"players", players)


func _valid_target_district(district_index: int, districts: Array) -> bool:
	return district_index >= 0 and district_index < districts.size() and not bool((districts[district_index] as Dictionary).get("destroyed", false))


func _players() -> Array:
	var value: Variant = _world_value(&"players", [])
	return value as Array if value is Array else []


func _districts() -> Array:
	var value: Variant = _world_value(&"districts", [])
	return value as Array if value is Array else []


func _district_center(index: int) -> Vector2:
	var value: Variant = _world_call(&"_district_center", [index])
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func _district_city(index: int) -> Dictionary:
	var value: Variant = _world_call(&"_district_city", [index])
	return value as Dictionary if value is Dictionary else {}


func _city_is_active(city: Dictionary) -> bool:
	return bool(_world_call(&"_city_is_active", [city]))


func _entity_world_position(entity: Dictionary) -> Vector2:
	var value: Variant = _world_call(&"_entity_world_position", [entity])
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func _entity_has_linear_motion(entity: Dictionary) -> bool:
	return bool(_world_call(&"_entity_has_linear_motion", [entity]))


func _entity_distance_to_district(entity: Dictionary, district_index: int) -> float:
	return float(_world_call(&"_entity_distance_to_district", [entity, district_index]))


func _entity_distance_to_district_label(entity: Dictionary, district_index: int) -> String:
	return str(_world_call(&"_entity_distance_to_district_label", [entity, district_index]))


func _duration_short_text(seconds: float) -> String:
	return str(_world_call(&"_duration_short_text", [seconds]))


func _meters_text(distance: float) -> String:
	return str(_world_call(&"_meters_text", [distance]))


func _skill_family(card_name: String) -> String:
	return _card_runtime_catalog_service.family_id(card_name) if _card_runtime_catalog_service != null else ""


func _skill_rank(card_name: String) -> int:
	return _card_runtime_catalog_service.rank(card_name) if _card_runtime_catalog_service != null else 0


func _make_skill(card_name: String) -> Dictionary:
	if _card_runtime_catalog_service == null:
		return {}
	var result := _card_runtime_catalog_service.definition(card_name)
	result["name"] = card_name
	return result


func _log(message: String) -> void:
	if _public_log_producer_port != null and not message.is_empty():
		_public_log_producer_port.publish(
			&"military_public_update", &"public.military.updated",
			{"action_kind": "military", "public_status": "updated"},
			_presentation_source_revision(), _presentation_world_time()
		)


func _presentation_source_revision() -> int:
	return _presentation_world_clock.world_effective_micros() if _presentation_world_clock != null else 0


func _presentation_world_time() -> float:
	return _presentation_world_clock.world_effective_seconds() if _presentation_world_clock != null else 0.0


func _world_value(property_name: StringName, default_value: Variant = null) -> Variant:
	return _world_bridge.read_world_value(property_name, default_value) if _world_bridge != null else default_value


func _write_world_value(property_name: StringName, value: Variant) -> bool:
	return _world_bridge.write_world_value(property_name, value) if _world_bridge != null else false


func _world_call(method_name: StringName, arguments: Array = []) -> Variant:
	return _world_bridge.call_world(method_name, arguments) if _world_bridge != null else null
