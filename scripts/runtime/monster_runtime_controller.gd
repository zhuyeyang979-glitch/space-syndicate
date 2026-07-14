@tool
extends Node
class_name MonsterRuntimeController

const UNIT_CARD_SCHEMA_V06 := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const CARD_RUNTIME_CATALOG_V06 := preload("res://resources/cards/runtime/card_runtime_catalog_v06.tres")

const MONSTER_CARD_LIFECYCLE_SCHEMA_V06 := "monster_deploy_atomic_lifecycle_v06"
const MONSTER_CARD_CONTRACT_VERSION_V06 := "v0.6"
const MONSTER_CARD_EFFECT_V06 := "deploy_or_upgrade_monster"
const MONSTER_CARD_ACTION_V06 := "deploy_or_upgrade_monster"
const MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06 := "monster_cross_owner_atomicity_unavailable"
const MONSTER_BINDING_CAPABILITY_KIND_V06 := "monster_caps"
const MONSTER_BASE_COUNT_LIMIT_V06 := 1
const MONSTER_BASE_PRIMARY_RANK_CAP_V06 := 2
const MONSTER_BASE_SECONDARY_RANK_CAP_V06 := 0
const MONSTER_UPGRADE_DEFAULT_EXTEND_SECONDS_V06 := 60.0
const MONSTER_FAMILY_BY_NAME_V06 := {
	"孢雾海皇": "spore_tide_emperor",
	"砂铠陆行兽": "sand_armor_rover",
	"流星哨兵": "meteor_sentinel",
	"棱刃重甲": "prism_blade_colossus",
	"绿洲修复体": "oasis_repairer",
	"焰环幼星": "flame_ring_proto_star",
	"蓝锋骑士": "blue_edge_knight",
	"镜像猎兵": "mirror_hunter",
}
const MONSTER_CARD_REQUIRED_ATOMIC_PARTICIPANTS_V06 := [
	"bound_skill_inventory",
	"product_market_rng",
	"role_cash_ledger",
]
const MONSTER_CARD_REQUIRED_FACT_PORTS_V06 := [
	"region_facts",
	"monster_profile",
	"binding_rule",
]

const MONSTER_COMMAND_MOVE_METERS := 220.0
const NEARBY_RADIUS_METERS := 240.0
const DEFAULT_AOE_RADIUS_METERS := 180.0

var _world_bridge: MonsterRuntimeWorldBridge
var _monster_binding_capability_provider_v06: Object
var _region_infrastructure_world_bridge: Node
var _route_network_runtime_controller: RouteNetworkRuntimeController
var _product_market_runtime_controller: ProductMarketRuntimeController
var _card_runtime_catalog_service: CardRuntimeCatalogService
var _ruleset_snapshot: Dictionary = {}
var _configured := false

var auto_monsters: Array = []
var next_auto_monster_uid := 1
var next_special_monster_slot := 0
var selected_auto_monster_slot := 0
var active_monster_wagers: Array = []
var resolved_monster_wager_history: Array = []
var monster_wager_sequence := 0
var public_card_bid_monster_wager_pool := 0
var monster_timer := 4.0
var special_monster_timer := 5.0

var _monster_card_revision_v06 := 0
var _monster_starter_state_v06: Dictionary = {}
var _monster_card_reservations_v06: Dictionary = {}
var _monster_card_terminal_journal_v06: Dictionary = {}
var _monster_card_presentation_journal_v06: Dictionary = {}
var _bankruptcy_estate_journal: Dictionary = {}
var _monster_card_lifecycle_call_counts_v06 := {
	"prepare": 0,
	"commit": 0,
	"rollback": 0,
	"finalize": 0,
	"roster_swaps": 0,
}


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_region_infrastructure_world_bridge(bridge: Node) -> void:
	_region_infrastructure_world_bridge = bridge


func set_route_network_runtime_controller(controller: RouteNetworkRuntimeController) -> void:
	_route_network_runtime_controller = controller


func set_card_runtime_catalog_service(service: CardRuntimeCatalogService) -> void:
	_card_runtime_catalog_service = service

var players: Array:
	get:
		var value: Variant = _world_value(&"players", [])
		return value if value is Array else []
	set(value):
		_write_world_value(&"players", value)

var districts: Array:
	get:
		var value: Variant = _world_value(&"districts", [])
		return value if value is Array else []
	set(value):
		_write_world_value(&"districts", value)

var game_time: float:
	get:
		return float(_world_value(&"game_time", 0.0))
	set(value):
		_write_world_value(&"game_time", value)

var selected_player: int:
	get:
		return int(_world_value(&"selected_player", -1))
	set(value):
		_write_world_value(&"selected_player", value)

var selected_district: int:
	get:
		return int(_world_value(&"selected_district", -1))
	set(value):
		_write_world_value(&"selected_district", value)

var rng: RandomNumberGenerator:
	get:
		return _world_bridge.shared_rng() if _world_bridge != null else null

const MONSTER_RAMPAGE_MOVE_METERS := 190.0

const MELEE_RANGE_METERS := 110.0

const VISUAL_TRAIL_DURATION := 1.8

const ACTION_CALLOUT_DURATION := 4.5

const MAP_EVENT_EFFECT_DURATION := 1.35

const CARD_INGRESS_CALLOUT_DURATION := 6.5

const AUTO_MONSTER_MIN_SPECIAL_DAMAGE := 1

const AUTO_MONSTER_ENCOUNTER_RANGE_METERS := 170.0

const AUTO_MONSTER_PATH_DAMAGE_STEP_METERS := 190.0

const AUTO_MONSTER_PATH_DAMAGE_MAX_REGIONS := 4

const AUTO_MONSTER_KNOCKBACK_DAMAGE_MAX_REGIONS := 3

const AUTO_MONSTER_DEFAULT_MOVE_DAMAGE := 1

const AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE := 1

const EMBER_RING_ENERGY_THRESHOLD := 15

const EMBER_RING_ENERGY_FLAME_DAMAGE := 1

const BLUE_LANCER_REACTIVE_ARMOR_THRESHOLD := 20

const BLUE_LANCER_REACTIVE_DAMAGE_REDUCTION := 1

const BLUE_LANCER_REACTIVE_DAMAGE_BONUS := 1

const MONSTER_WAGER_MIN_BASE_PERCENT := 5

const MONSTER_WAGER_MAX_BASE_PERCENT := 10

const MONSTER_WAGER_MAX_STAKE_PERCENT := 30

const MONSTER_WAGER_PERCENT_STEP := 1

const MONSTER_WAGER_VISIBLE_RAISE_STEPS := 5

const MONSTER_WAGER_HISTORY_LIMIT := 12

const MONSTER_OWNER_DAMAGE_CASH_POOL := 700

const MONSTER_CARD_DURATION_BASE_SECONDS := 95.0

const MONSTER_CARD_DURATION_RANK_STEP_SECONDS := 28.0

const MONSTER_TARGET_BASE_WEIGHT := 10

const MONSTER_TARGET_DISTANCE_BASE := 48.0

const MONSTER_TARGET_DISTANCE_STEP := 0.045

const MONSTER_TARGET_MIASMA_BONUS := 18

const MONSTER_TARGET_RIVAL_BONUS := 10

const MONSTER_TARGET_CITY_BONUS := 38

const MONSTER_TARGET_PRODUCT_WEIGHT := 3

const MONSTER_TARGET_COMPETITION_WEIGHT := 5

const MONSTER_TARGET_RESOURCE_WEIGHT := 12

const JACK_BRACELET_ACTION_TABLE := [
	{"name": "腕环拳击", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米腕环拳击，2伤害，并击退怪兽约120米。"},
	{"name": "腕环回旋踢", "range": 125.0, "damage": 2, "move_override": -1.0, "knockback": 150.0, "text": "125米回旋踢，2伤害，并击退怪兽约150米。"},
	{"name": "手镯炸弹", "range": 420.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "text": "420米手镯炸弹，3伤害，并直线击退怪兽约320米。"},
	{"name": "延迟手镯炸弹", "range": 460.0, "damage": 3, "move_override": -1.0, "knockback": 360.0, "text": "460米延迟爆弹，3伤害，并直线击退怪兽约360米。"},
	{"name": "星弧火花", "range": 520.0, "damage": 4, "move_override": -1.0, "text": "520米星弧火花，4伤害。"},
	{"name": "星弧连闪", "range": 560.0, "damage": 4, "move_override": -1.0, "paralyze": 1, "text": "560米星弧连闪，4伤害，并短暂麻痹目标。"},
]

const MONSTER_SKILL_WEIGHT_TABLES := {
	"孢雾海皇": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 1, 2, 1]},
	"砂铠陆行兽": {"early": [3, 2, 1, 0, 0, 0], "escalated": [3, 2, 1, 2, 2, 1]},
	"流星哨兵": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 1, 2, 1]},
	"棱刃重甲": {"early": [2, 2, 2, 0, 0, 0], "escalated": [2, 2, 2, 2, 1, 1]},
	"绿洲修复体": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 2, 1, 1]},
	"焰环幼星": {"early": [2, 2, 2, 0, 0, 0], "escalated": [2, 2, 2, 1, 2, 1]},
	"蓝锋骑士": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 1, 2, 1]},
	"镜像猎兵": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 2, 1, 1]},
	"腕环哨兵": {"early": [2, 2, 1, 1, 0, 0], "escalated": [2, 2, 2, 2, 1, 1]},
}

func set_world_bridge(bridge: MonsterRuntimeWorldBridge) -> void:
	_world_bridge = bridge


func configure_monster_binding_capability_provider_v06(provider: Object) -> Dictionary:
	_monster_binding_capability_provider_v06 = null
	var required_methods := [
		"current_monster_binding_window_snapshot_v06",
		"monster_binding_caps",
		"monster_binding_caps_for_target_owner",
	]
	var method_matrix: Dictionary = {}
	var provider_ready := provider != null and is_instance_valid(provider)
	for method_name in required_methods:
		var present := provider_ready and provider.has_method(method_name)
		method_matrix[method_name] = present
		provider_ready = provider_ready and present
	method_matrix["validate_monster_binding_caps_v06"] = provider != null and is_instance_valid(provider) and provider.has_method("validate_monster_binding_caps_v06")
	if provider_ready:
		_monster_binding_capability_provider_v06 = provider
	return {
		"configured": provider_ready,
		"reason_code": "monster_binding_capability_provider_ready" if provider_ready else "monster_binding_capability_provider_unavailable",
		"method_matrix": method_matrix,
		"fallback": {
			"controlled_monster_count_limit": MONSTER_BASE_COUNT_LIMIT_V06,
			"primary_monster_rank_limit": MONSTER_BASE_PRIMARY_RANK_CAP_V06,
			"secondary_monster_rank_limit": MONSTER_BASE_SECONDARY_RANK_CAP_V06,
		},
	}


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_snapshot = ruleset_snapshot.duplicate(true)
	_configured = str(_ruleset_snapshot.get("ruleset_id", "")) == "v0.4" and _world_bridge != null and _card_runtime_catalog_service != null


func reset_state() -> void:
	auto_monsters.clear()
	next_auto_monster_uid = 1
	next_special_monster_slot = 0
	selected_auto_monster_slot = 0
	active_monster_wagers.clear()
	resolved_monster_wager_history.clear()
	monster_wager_sequence = 0
	public_card_bid_monster_wager_pool = 0
	monster_timer = 4.0
	special_monster_timer = 5.0
	_monster_card_revision_v06 = 0
	_monster_starter_state_v06.clear()
	_monster_card_reservations_v06.clear()
	_monster_card_terminal_journal_v06.clear()
	_monster_card_presentation_journal_v06.clear()
	_bankruptcy_estate_journal.clear()
	for key_variant in _monster_card_lifecycle_call_counts_v06.keys():
		_monster_card_lifecycle_call_counts_v06[key_variant] = 0


func bankruptcy_estate_stage(stage: String, request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var player_indices: Array = request.get("player_indices", []) if request.get("player_indices", []) is Array else []
	if transaction_id.is_empty() or player_indices.is_empty() or not (["prepare", "commit", "rollback", "finalize"].has(stage)):
		return _bankruptcy_estate_failure(stage, "monster_bankruptcy_request_invalid")
	var record: Dictionary = _bankruptcy_estate_journal.get(transaction_id, {}) if _bankruptcy_estate_journal.get(transaction_id, {}) is Dictionary else {}
	if not record.is_empty() and record.get("player_indices", []) != player_indices:
		return _bankruptcy_estate_failure(stage, "monster_bankruptcy_transaction_collision")
	match stage:
		"prepare":
			if not record.is_empty():
				return _bankruptcy_estate_result(stage, record, true)
			if not _monster_card_reservations_v06.is_empty():
				return _bankruptcy_estate_failure(stage, "monster_bankruptcy_transaction_inflight")
			var targets: Dictionary = {}
			for value in player_indices:
				targets[str(int(value))] = true
			var postimage := auto_monsters.duplicate(true)
			var post_starter_state := _monster_starter_state_v06.duplicate(true)
			var orphan_actor_ids: Dictionary = {}
			var orphan_unit_uids: Dictionary = {}
			var orphaned := 0
			for index in range(postimage.size()):
				if not (postimage[index] is Dictionary):
					continue
				var actor: Dictionary = (postimage[index] as Dictionary).duplicate(true)
				if not targets.has(str(int(actor.get("owner", -1)))):
					continue
				var owner_actor_id := str(actor.get("owner_actor_id_v06", ""))
				if not owner_actor_id.is_empty():
					orphan_actor_ids[owner_actor_id] = true
				orphan_unit_uids[str(int(actor.get("uid", 0)))] = true
				actor["owner"] = -1
				actor["owner_revealed"] = false
				for private_key in ["bound_actor_id", "bound_owner_actor_id", "owner_actor_id", "owner_actor_id_v06", "private_owner_clue", "owner_clue"]:
					actor.erase(private_key)
				postimage[index] = actor
				orphaned += 1
			for actor_id_variant in post_starter_state.keys():
				var starter: Dictionary = post_starter_state[actor_id_variant] if post_starter_state[actor_id_variant] is Dictionary else {}
				if orphan_actor_ids.has(str(actor_id_variant)) or orphan_unit_uids.has(str(int(starter.get("unit_uid", 0)))):
					post_starter_state.erase(actor_id_variant)
			record = {
				"state": "prepared", "player_indices": player_indices.duplicate(),
				"expected_revision": _monster_card_revision_v06,
				"expected_hash": var_to_str({"roster": auto_monsters, "starter": _monster_starter_state_v06}).sha256_text(),
				"preimage": auto_monsters.duplicate(true), "postimage": postimage,
				"preimage_starter_state": _monster_starter_state_v06.duplicate(true), "postimage_starter_state": post_starter_state,
				"estate_counts": {"monsters_orphaned": orphaned},
			}
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, false)
		"commit":
			if record.is_empty(): return _bankruptcy_estate_failure(stage, "monster_bankruptcy_prepare_missing")
			if str(record.get("state", "")) in ["committed", "finalized"]: return _bankruptcy_estate_result(stage, record, true)
			if str(record.get("state", "")) != "prepared" or _monster_card_revision_v06 != int(record.get("expected_revision", -1)) or var_to_str({"roster": auto_monsters, "starter": _monster_starter_state_v06}).sha256_text() != str(record.get("expected_hash", "")):
				return _bankruptcy_estate_failure(stage, "monster_bankruptcy_revision_changed")
			auto_monsters = (record.get("postimage", []) as Array).duplicate(true)
			_monster_starter_state_v06 = (record.get("postimage_starter_state", {}) as Dictionary).duplicate(true)
			_monster_card_revision_v06 += 1
			record["state"] = "committed"
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, false)
		"rollback":
			if record.is_empty(): return _bankruptcy_estate_failure(stage, "monster_bankruptcy_prepare_missing")
			if str(record.get("state", "")) == "rolled_back": return _bankruptcy_estate_result(stage, record, true)
			if str(record.get("state", "")) == "finalized": return _bankruptcy_estate_failure(stage, "monster_bankruptcy_already_finalized")
			if str(record.get("state", "")) == "committed":
				auto_monsters = (record.get("preimage", []) as Array).duplicate(true)
				_monster_starter_state_v06 = (record.get("preimage_starter_state", {}) as Dictionary).duplicate(true)
				_monster_card_revision_v06 = int(record.get("expected_revision", _monster_card_revision_v06))
			record["state"] = "rolled_back"
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, false)
		"finalize":
			if record.is_empty() or not (str(record.get("state", "")) in ["committed", "finalized"]): return _bankruptcy_estate_failure(stage, "monster_bankruptcy_commit_missing")
			var duplicate := str(record.get("state", "")) == "finalized"
			record["state"] = "finalized"
			for key in ["preimage", "postimage", "preimage_starter_state", "postimage_starter_state"]:
				record.erase(key)
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, duplicate)
	return _bankruptcy_estate_failure(stage, "monster_bankruptcy_stage_invalid")


func _bankruptcy_estate_result(stage: String, record: Dictionary, duplicate: bool) -> Dictionary:
	return {"prepared": stage == "prepare", "committed": stage == "commit", "rolled_back": stage == "rollback", "finalized": stage == "finalize", "duplicate": duplicate, "reason_code": "monster_bankruptcy_%s" % stage, "estate_counts": (record.get("estate_counts", {}) as Dictionary).duplicate(true) if record.get("estate_counts", {}) is Dictionary else {}}


func _bankruptcy_estate_failure(stage: String, reason_code: String) -> Dictionary:
	return {"prepared": false, "committed": false, "rolled_back": false, "finalized": false, "stage": stage, "reason_code": reason_code, "estate_counts": {}}


func tick_wagers(delta: float) -> void:
	_update_monster_wagers(delta)


func tick_motion(delta: float) -> void:
	_update_auto_monster_linear_movement(delta)


func tick_lifecycle(delta: float) -> void:
	_update_auto_monster_durations(delta)
	_update_auto_monster_revivals(delta)


func tick_durations(delta: float) -> void:
	_update_auto_monster_durations(delta)


func tick_revivals(delta: float) -> void:
	_update_auto_monster_revivals(delta)


func tick_action_timers(delta: float) -> void:
	if _active_auto_monster_count() > 0:
		special_monster_timer -= delta
	monster_timer -= delta
	if monster_timer <= 0.0:
		_monster_tick()
		monster_timer = float(_world_call(&"_roll_timer", ["monster"]))
	if _active_auto_monster_count() > 0 and special_monster_timer <= 0.0:
		_special_monster_tick()
		special_monster_timer = float(_world_call(&"_roll_timer", ["special_monster"]))


func add_public_wager_pool(amount: int) -> int:
	public_card_bid_monster_wager_pool += maxi(0, amount)
	return public_card_bid_monster_wager_pool


func resolve_targeted_skill(skill: Dictionary, player: Dictionary, target_slot: int, acting_player_index: int = -1, target_district: int = -1) -> bool:
	if target_slot < 0 or target_slot >= auto_monsters.size():
		return false
	var kind := String(skill.get("kind", ""))
	var target_snapshot_variant: Variant = _world_call(&"_card_play_target_snapshot", [skill])
	var target_snapshot: Dictionary = target_snapshot_variant if target_snapshot_variant is Dictionary else {}
	if bool(target_snapshot.get("direct_monster_skill", false)):
		return _trigger_auto_monster_card_command(skill, player, target_slot)
	if kind == "monster_lure":
		var actor: Dictionary = auto_monsters[target_slot]
		selected_auto_monster_slot = target_slot
		next_special_monster_slot = target_slot
		var speedup: float = float(skill.get("lure_speedup", 0.0))
		monster_timer = max(0.2, monster_timer - speedup)
		actor["lure_target_district"] = target_district
		actor["lure_moves_left"] = 1
		actor["lure_source"] = String(skill.get("name", "怪兽诱导"))
		auto_monsters[target_slot] = actor
		var district_label := String(districts[target_district].get("name", "当前选区")) if target_district >= 0 and target_district < districts.size() else "当前选区"
		_log("%s匿名诱导怪%d·%s：下一次自动移动优先朝%s推进，并提前%.1fs；诱导结算后失效。" % [String(skill.get("name", "怪兽诱导")), target_slot + 1, String(actor.get("name", "怪兽")), district_label, speedup])
		_add_action_callout("自动怪兽%d·%s" % [target_slot + 1, String(actor.get("name", "怪兽"))], "匿名诱导", "%s让这只怪兽下一次自动移动优先朝%s推进。" % [String(skill.get("name", "怪兽诱导")), district_label], _auto_monster_color(target_slot), _entity_world_position(actor))
		return true
	if kind == "special_monster_delay":
		var delayed_actor: Dictionary = auto_monsters[target_slot]
		var delay: float = float(skill.get("delay", 1.0))
		special_monster_timer += delay
		_log("%s干扰怪%d·%s，怪兽特殊行动节奏延后%.1fs。" % [String(skill.get("name", "行动干扰")), target_slot + 1, String(delayed_actor.get("name", "怪兽")), delay])
		_add_action_callout("自动怪兽%d·%s" % [target_slot + 1, String(delayed_actor.get("name", "怪兽"))], "行动干扰", "%s使特殊行动延后%.1fs。" % [String(skill.get("name", "行动干扰")), delay], _auto_monster_color(target_slot), _entity_world_position(delayed_actor))
		return true
	if kind == "monster_takeover":
		var takeover_player := acting_player_index if acting_player_index >= 0 else selected_player
		return _apply_monster_takeover(skill, target_slot, takeover_player)
	if kind == "mudslide":
		var mud_actor: Dictionary = auto_monsters[target_slot]
		var range_limit: float = float(skill.get("range", DEFAULT_AOE_RADIUS_METERS))
		if _entity_distance_to_district(mud_actor, target_district) > range_limit:
			_log("%s目标区域距离怪%d·%s为%s，超过%s。" % [String(skill.get("name", "泥石流")), target_slot + 1, String(mud_actor.get("name", "怪兽")), _entity_distance_to_district_label(mud_actor, target_district), _meters_text(range_limit)])
			return false
		_damage_district(target_district, int(skill.get("damage", 1)), String(skill.get("name", "泥石流")))
		special_monster_timer += float(skill.get("delay", 0.0))
		_log("%s以怪%d·%s为目标触发，%s受影响。" % [String(skill.get("name", "泥石流")), target_slot + 1, String(mud_actor.get("name", "怪兽")), String(districts[target_district].get("name", "区域"))])
		return true
	return false


func prime_action_timers(special_seconds: float, regular_seconds: float) -> void:
	special_monster_timer = maxf(0.0, special_seconds)
	monster_timer = maxf(0.0, regular_seconds)


func select_slot(slot: int) -> int:
	selected_auto_monster_slot = _valid_auto_monster_slot(slot)
	return selected_auto_monster_slot


func take_external_damage(target_slot: int, damage: int, source: String) -> bool:
	if target_slot < 0 or target_slot >= auto_monsters.size() or bool((auto_monsters[target_slot] as Dictionary).get("down", false)):
		return false
	_auto_monster_take_damage(target_slot, maxi(0, damage), source, -1)
	return true


func roster_snapshot(include_private: bool = true) -> Array:
	var result := auto_monsters.duplicate(true)
	if include_private:
		return result
	var public_result: Array = []
	for actor_variant in result:
		if actor_variant is Dictionary:
			public_result.append(_monster_public_actor_v06(actor_variant as Dictionary))
	return public_result


func summon_zone_available(district_index: int, required_terrain: String = "") -> bool:
	var districts_variant: Variant = _world_value(&"districts", [])
	if not (districts_variant is Array):
		return false
	var districts := districts_variant as Array
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return false
	var target := districts[district_index] as Dictionary
	if bool(target.get("destroyed", false)):
		return false
	var terrain := str(target.get("terrain", "land"))
	if not required_terrain.is_empty() and terrain != required_terrain:
		return false
	var valid_origins: Dictionary = {}
	for actor_variant: Variant in auto_monsters:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)) or (actor.has("remaining_time") and float(actor.get("remaining_time", 0.0)) <= 0.0):
			continue
		var origin := int(actor.get("position", -1))
		if origin >= 0:
			valid_origins[origin] = true
	if valid_origins.has(district_index):
		return true
	for neighbor_variant: Variant in target.get("neighbors", []):
		if valid_origins.has(int(neighbor_variant)):
			return true
	return false


func selected_actor_snapshot(include_private: bool = true) -> Dictionary:
	var actor := _selected_auto_monster_actor().duplicate(true)
	if actor.is_empty() or include_private:
		return actor
	return _monster_public_actor_v06(actor)


func active_wagers_snapshot() -> Array:
	return active_monster_wagers.duplicate(true)


func resolved_wagers_snapshot() -> Array:
	return resolved_monster_wager_history.duplicate(true)


func replace_runtime_state(data: Dictionary) -> void:
	apply_save_data(data)


func to_save_data() -> Dictionary:
	return {
		"auto_monsters": auto_monsters.duplicate(true),
		"next_auto_monster_uid": next_auto_monster_uid,
		"next_special_monster_slot": next_special_monster_slot,
		"selected_auto_monster_slot": selected_auto_monster_slot,
		"active_monster_wagers": active_monster_wagers.duplicate(true),
		"resolved_monster_wager_history": resolved_monster_wager_history.duplicate(true),
		"monster_wager_sequence": monster_wager_sequence,
		"public_card_bid_monster_wager_pool": public_card_bid_monster_wager_pool,
		"monster_timer": monster_timer,
		"special_monster_timer": special_monster_timer,
		"monster_card_atomic_schema_version": MONSTER_CARD_LIFECYCLE_SCHEMA_V06,
		"monster_card_atomic_owner_revision": _monster_card_revision_v06,
		"monster_card_atomic_starter_state": _monster_starter_state_v06.duplicate(true),
		"monster_card_atomic_reservations": _monster_card_reservations_v06.duplicate(true),
		"monster_card_atomic_terminal_journal": _monster_card_terminal_journal_v06.duplicate(true),
		"monster_card_atomic_presentation_journal": _monster_card_presentation_journal_v06.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var normalized := _monster_save_envelope_v06(data)
	if not bool(normalized.get("valid", false)):
		return {"applied": false, "reason_code": str(normalized.get("reason_code", "monster_save_invalid"))}
	var next_state: Dictionary = normalized.get("state", {})
	auto_monsters = (next_state.get("auto_monsters", []) as Array).duplicate(true)
	next_auto_monster_uid = int(next_state.get("next_auto_monster_uid", 1))
	next_special_monster_slot = int(next_state.get("next_special_monster_slot", 0))
	selected_auto_monster_slot = int(next_state.get("selected_auto_monster_slot", 0))
	active_monster_wagers = (next_state.get("active_monster_wagers", []) as Array).duplicate(true)
	resolved_monster_wager_history = (next_state.get("resolved_monster_wager_history", []) as Array).duplicate(true)
	monster_wager_sequence = int(next_state.get("monster_wager_sequence", 0))
	public_card_bid_monster_wager_pool = int(next_state.get("public_card_bid_monster_wager_pool", 0))
	monster_timer = float(next_state.get("monster_timer", 4.0))
	special_monster_timer = float(next_state.get("special_monster_timer", 5.0))
	_monster_card_revision_v06 = int(next_state.get("monster_card_atomic_owner_revision", 0))
	_monster_starter_state_v06 = (next_state.get("monster_card_atomic_starter_state", {}) as Dictionary).duplicate(true)
	_monster_card_reservations_v06 = (next_state.get("monster_card_atomic_reservations", {}) as Dictionary).duplicate(true)
	_monster_card_terminal_journal_v06 = (next_state.get("monster_card_atomic_terminal_journal", {}) as Dictionary).duplicate(true)
	_monster_card_presentation_journal_v06 = (next_state.get("monster_card_atomic_presentation_journal", {}) as Dictionary).duplicate(true)
	return {"applied": true, "monster_count": auto_monsters.size(), "active_wager_count": active_monster_wagers.size()}


func debug_snapshot(viewer_index: int = -1) -> Dictionary:
	var public_roster: Array = []
	for actor_variant in auto_monsters:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		var world_position: Vector2 = actor.get("world_position", Vector2.ZERO)
		public_roster.append({
			"uid": int(actor.get("uid", 0)),
			"slot": int(actor.get("slot", -1)),
			"catalog_index": int(actor.get("catalog_index", -1)),
			"name": str(actor.get("name", "怪兽")),
			"rank": int(actor.get("rank", 1)),
			"hp": int(actor.get("hp", 0)),
			"max_hp": int(actor.get("max_hp", 0)),
			"position": int(actor.get("position", -1)),
			"world_position": {"x": world_position.x, "y": world_position.y},
			"down": bool(actor.get("down", false)),
			"owner_revealed": bool(actor.get("owner_revealed", false)),
		})
	return {
		"controller_ready": _configured and _world_bridge != null and _world_bridge.has_world(),
		"controller_authoritative": true,
		"runtime_owner": "MonsterRuntimeController",
		"parallel_legacy_owner": false,
		"card_catalog_bound": _card_runtime_catalog_service != null,
		"monster_count": auto_monsters.size(),
		"active_monster_count": _active_auto_monster_count(),
		"selected_slot": selected_auto_monster_slot,
		"next_uid": next_auto_monster_uid,
		"active_wager_count": active_monster_wagers.size(),
		"resolved_wager_count": resolved_monster_wager_history.size(),
		"public_wager_pool": public_card_bid_monster_wager_pool,
		"monster_timer": monster_timer,
		"special_monster_timer": special_monster_timer,
		"viewer_index": viewer_index,
		"public_roster": public_roster,
	}


func monster_runtime_capabilities_v06() -> Dictionary:
	return unit_card_runtime_capabilities_v06("monster")


func unit_card_runtime_capabilities_v06(domain: String) -> Dictionary:
	var dependency_matrix := _monster_card_dependency_matrix_v06()
	var method_matrix := {
		"prepare": has_method("prepare_unit_card_intent_v06"),
		"commit": has_method("commit_unit_card_intent_v06"),
		"rollback": has_method("rollback_unit_card_intent_v06"),
		"finalize": has_method("finalize_unit_card_intent_v06"),
		"checkpoint_gate": has_method("unit_card_checkpoint_status_v06"),
		"save_load": has_method("unit_card_save_data_v06") and has_method("apply_unit_card_save_data_v06"),
		"snapshot": has_method("unit_card_snapshot_v06"),
	}
	var methods_ready := true
	for ready_variant in method_matrix.values():
		methods_ready = methods_ready and bool(ready_variant)
	var domain_valid := domain == "monster"
	var dependency_ready := bool(dependency_matrix.get("atomic_ready", false))
	var atomic_ready := domain_valid and methods_ready and dependency_ready
	return {
		"contract_version": MONSTER_CARD_CONTRACT_VERSION_V06,
		"domain": "monster",
		"revision": true,
		"prepare": bool(method_matrix.get("prepare", false)),
		"commit": bool(method_matrix.get("commit", false)),
		"rollback": bool(method_matrix.get("rollback", false)),
		"finalize": bool(method_matrix.get("finalize", false)),
		"exact_once": true,
		"checkpoint_gate": bool(method_matrix.get("checkpoint_gate", false)),
		"save_load": bool(method_matrix.get("save_load", false)),
		"privacy_safe_snapshot": bool(method_matrix.get("snapshot", false)),
		"supported_effect_kinds": [MONSTER_CARD_EFFECT_V06],
		"supported_action_kinds": [MONSTER_CARD_ACTION_V06],
		"owner_revision": _monster_card_revision_v06,
		"atomic_mutation_ready": atomic_ready,
		"capability_reason": "monster_atomic_ready" if atomic_ready else MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06,
		"production_ready_scope": "starter_and_ordinary_summon_plus_same_family_upgrade_with_authoritative_binding_caps",
		"cross_owner_dependency_matrix": dependency_matrix,
		"upgrade_duration_policy_ready": true,
		"upgrade_duration_policy_reason": "monster_upgrade_adds_remaining_time",
		"method_matrix": method_matrix,
	}


func unit_card_snapshot_v06(domain: String) -> Dictionary:
	if domain != "monster":
		return {"available": false, "reason_code": "monster_owner_domain_mismatch", "domain": domain}
	var public_roster: Array = []
	for actor_variant in roster_snapshot(false):
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		var actor_position := _monster_card_world_position_v06(actor.get("world_position", Vector2.ZERO))
		public_roster.append({
			"unit_uid": int(actor.get("uid", 0)),
			"family_id": str(actor.get("monster_family_id", _monster_family_id_for_actor_v06(actor))),
			"name": str(actor.get("name", "怪兽")),
			"rank": int(actor.get("rank", 1)),
			"hp": int(actor.get("hp", 0)),
			"max_hp": int(actor.get("max_hp", 0)),
			"remaining_time": float(actor.get("remaining_time", 0.0)),
			"move_mps": float(actor.get("move", 0.0)),
			"region_index": int(actor.get("position", -1)),
			"world_position": {"x": actor_position.x, "y": actor_position.y},
			"down": bool(actor.get("down", false)),
			"owner_revealed": bool(actor.get("owner_revealed", false)),
			"actor_revision": int(actor.get("actor_revision_v06", 0)),
		})
	return {
		"available": true,
		"contract_version": MONSTER_CARD_CONTRACT_VERSION_V06,
		"domain": "monster",
		"owner_revision": _monster_card_revision_v06,
		"monster_count": public_roster.size(),
		"roster": public_roster,
		"inflight_count": _monster_card_reservations_v06.size(),
		"checkpoint_open": _monster_card_reservations_v06.is_empty(),
	}


func monster_private_snapshot_v06(actor_id: String) -> Dictionary:
	var starter_snapshot := monster_starter_state_snapshot_v06(actor_id)
	if not bool(starter_snapshot.get("available", false)):
		return {
			"available": false,
			"reason_code": str(starter_snapshot.get("reason_code", "monster_private_snapshot_actor_unavailable")),
			"starter_state": str(starter_snapshot.get("state", "legacy_unknown")),
			"owner_revision": _monster_card_revision_v06,
		}
	var starter_unit_uid := int(starter_snapshot.get("unit_uid", 0))
	var binding_caps := _monster_binding_caps_v06(actor_id, false)
	var owned_units: Array = []
	for actor_variant in auto_monsters:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		var bound_actor_id := str(actor.get("owner_actor_id_v06", ""))
		var actor_uid := int(actor.get("uid", 0))
		if bound_actor_id != actor_id and (not bound_actor_id.is_empty() or starter_unit_uid <= 0 or actor_uid != starter_unit_uid):
			continue
		var actor_position := _monster_card_world_position_v06(actor.get("world_position", Vector2.ZERO))
		var binding_status := _monster_binding_status_v06(actor, actor_id, int(actor.get("owner", -1)), binding_caps)
		owned_units.append({
			"unit_uid": actor_uid,
			"family_id": _monster_family_id_for_actor_v06(actor),
			"rank": int(actor.get("rank", 1)),
			"hp": int(actor.get("hp", 0)),
			"max_hp": int(actor.get("max_hp", 0)),
			"remaining_time": float(actor.get("remaining_time", 0.0)),
			"region_index": int(actor.get("position", -1)),
			"world_position": {"x": actor_position.x, "y": actor_position.y},
			"down": bool(actor.get("down", false)),
			"actor_revision": int(actor.get("actor_revision_v06", 0)),
			"suspended_for_new_upgrade": bool(binding_status.get("suspended_for_new_upgrade", false)),
			"binding_status": str(binding_status.get("reason_code", "monster_binding_cap_active")),
		})
	return {
		"available": true,
		"domain": "monster",
		"owner_revision": _monster_card_revision_v06,
		"starter_state": str(starter_snapshot.get("state", "legacy_unknown")),
		"starter_state_revision": int(starter_snapshot.get("revision", 0)),
		"owned_units": owned_units,
	}


func monster_starter_state_snapshot_v06(actor_id: String) -> Dictionary:
	var normalized_actor_id := actor_id.strip_edges()
	if normalized_actor_id.is_empty():
		return _monster_starter_state_unknown_snapshot_v06("monster_starter_actor_id_invalid")
	if _monster_starter_state_v06.has(normalized_actor_id):
		var row_variant: Variant = _monster_starter_state_v06.get(normalized_actor_id)
		if not (row_variant is Dictionary):
			return _monster_starter_state_unknown_snapshot_v06("monster_starter_state_invalid")
		var row := row_variant as Dictionary
		var state := str(row.get("state", "legacy_unknown"))
		var unit_uid := maxi(0, int(row.get("unit_uid", 0)))
		var transaction_id := str(row.get("transaction_id", ""))
		var revision := int(row.get("revision", 0))
		if not ["not_summoned", "summoned", "legacy_unknown"].has(state) or revision < 0:
			return _monster_starter_state_unknown_snapshot_v06("monster_starter_state_invalid")
		if state == "legacy_unknown" or (state == "summoned" and unit_uid <= 0):
			return _monster_starter_state_unknown_snapshot_v06("monster_starter_state_legacy_unknown", unit_uid, transaction_id, maxi(0, revision))
		return {
			"available": true,
			"state": state,
			"unit_uid": unit_uid if state == "summoned" else 0,
			"transaction_id": transaction_id if state == "summoned" else "",
			"revision": revision,
			"owner_revision": _monster_card_revision_v06,
			"reason_code": "monster_starter_state_%s" % state,
		}
	var ambiguous_legacy_owner := false
	for actor_variant in auto_monsters:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		var bound_actor_id := str(actor.get("owner_actor_id_v06", ""))
		if bound_actor_id == normalized_actor_id:
			return _monster_starter_state_unknown_snapshot_v06("monster_starter_marker_missing", int(actor.get("uid", 0)))
		if bound_actor_id.is_empty() and int(actor.get("owner", -1)) >= 0:
			ambiguous_legacy_owner = true
	if ambiguous_legacy_owner:
		return _monster_starter_state_unknown_snapshot_v06("monster_starter_state_legacy_unknown")
	return {
		"available": true,
		"state": "not_summoned",
		"unit_uid": 0,
		"transaction_id": "",
		"revision": 0,
		"owner_revision": _monster_card_revision_v06,
		"reason_code": "monster_starter_state_not_summoned",
	}


func _monster_starter_state_unknown_snapshot_v06(reason_code: String, unit_uid: int = 0, transaction_id: String = "", revision: int = 0) -> Dictionary:
	return {
		"available": false,
		"state": "legacy_unknown",
		"unit_uid": maxi(0, unit_uid),
		"transaction_id": transaction_id,
		"revision": maxi(0, revision),
		"owner_revision": _monster_card_revision_v06,
		"reason_code": reason_code,
	}


func monster_starter_first_summon_context_v06(actor_id: String, region_id: String, card_id: String) -> Dictionary:
	var card_variant: Variant = CARD_RUNTIME_CATALOG_V06.call("card_snapshot", card_id)
	if not (card_variant is Dictionary):
		return {"available": false, "reason_code": "monster_card_catalog_missing"}
	var card := card_variant as Dictionary
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var fields: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	if str(machine.get("effect_kind", "")) != MONSTER_CARD_EFFECT_V06 or int(machine.get("rank", 0)) != 1:
		return {"available": false, "reason_code": "monster_non_starter_deploy_deferred"}
	var family_id := str(fields.get("monster_family_id", ""))
	var rule := _monster_card_rule_snapshot_v06(actor_id)
	if not bool(rule.get("valid", false)):
		return {"available": false, "reason_code": str(rule.get("reason_code", "monster_binding_rule_unavailable"))}
	if not bool(rule.get("starter_entitled", false)) or bool(rule.get("starter_consumed", false)):
		return {"available": false, "reason_code": "monster_starter_entitlement_unavailable"}
	if not str(rule.get("starter_card_id", "")).is_empty() and str(rule.get("starter_card_id", "")) != card_id:
		return {"available": false, "reason_code": "monster_starter_card_binding_mismatch"}
	if _monster_starter_state_for_actor_v06(actor_id, int(rule.get("player_index", -1))) != "not_summoned":
		return {"available": false, "reason_code": "monster_starter_already_summoned"}
	var region := _monster_card_region_snapshot_v06(region_id, family_id)
	if not bool(region.get("valid", false)):
		return {"available": false, "reason_code": str(region.get("reason_code", "monster_deploy_region_invalid"))}
	var profile := _monster_card_profile_snapshot_v06(family_id, 1)
	if not bool(profile.get("valid", false)):
		return {"available": false, "reason_code": str(profile.get("reason_code", "monster_profile_unavailable"))}
	var dependencies := _monster_card_dependency_matrix_v06()
	var required_participants := _monster_card_required_participants_v06(profile)
	if not bool(dependencies.get("atomic_ready", false)) or not _monster_card_participants_ready_v06(dependencies, required_participants):
		return {"available": false, "reason_code": MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06}
	return {
		"available": true,
		"reason_code": "monster_starter_first_summon_context_ready",
		"contract_version": MONSTER_CARD_CONTRACT_VERSION_V06,
		"effect_kind": MONSTER_CARD_EFFECT_V06,
		"action_kind": MONSTER_CARD_ACTION_V06,
		"expected_owner_revision": _monster_card_revision_v06,
		"target_context": {
			"region_id": region_id,
			"expected_region_revision": int(region.get("revision", -1)),
			"expected_binding_rule_revision": int(rule.get("revision", -1)),
		},
		"effect_fields": fields.duplicate(true),
	}


func monster_card_developer_snapshot_v06() -> Dictionary:
	var reservation_stages: Dictionary = {}
	for transaction_variant in _monster_card_reservations_v06.keys():
		var transaction_id := str(transaction_variant)
		var reservation: Dictionary = _monster_card_reservations_v06.get(transaction_id, {})
		reservation_stages[transaction_id] = str(reservation.get("stage", "unknown"))
	var terminal_stages: Dictionary = {}
	for transaction_variant in _monster_card_terminal_journal_v06.keys():
		var transaction_id := str(transaction_variant)
		var entry: Dictionary = _monster_card_terminal_journal_v06.get(transaction_id, {})
		terminal_stages[transaction_id] = str(entry.get("stage", "unknown"))
	return {
		"contract_version": MONSTER_CARD_CONTRACT_VERSION_V06,
		"owner_revision": _monster_card_revision_v06,
		"core_state_fingerprint": _monster_card_core_state_fingerprint_v06(),
		"reservation_stages": reservation_stages,
		"terminal_stages": terminal_stages,
		"presentation_transactions": _monster_card_presentation_journal_v06.keys().duplicate(),
		"call_counts": _monster_card_lifecycle_call_counts_v06.duplicate(true),
		"capabilities": unit_card_runtime_capabilities_v06("monster"),
	}


func unit_card_checkpoint_status_v06(domain: String) -> Dictionary:
	if domain != "monster":
		return {"can_checkpoint": false, "reason_code": "monster_owner_domain_mismatch", "domain": domain, "inflight_count": -1}
	var inflight_count := _monster_card_reservations_v06.size()
	return {
		"can_checkpoint": inflight_count == 0,
		"reason_code": "monster_checkpoint_ready" if inflight_count == 0 else "monster_card_transaction_inflight",
		"domain": "monster",
		"inflight_count": inflight_count,
		"owner_revision": _monster_card_revision_v06,
	}


func prepare_unit_card_intent_v06(intent: Dictionary) -> Dictionary:
	_monster_card_lifecycle_call_counts_v06["prepare"] = int(_monster_card_lifecycle_call_counts_v06.get("prepare", 0)) + 1
	var validation: Dictionary = UNIT_CARD_SCHEMA_V06.validate_intent(intent)
	if not bool(validation.get("valid", false)):
		return _monster_card_failure_v06(
			intent,
			str(validation.get("reason_code", "monster_intent_invalid")),
			str((validation.get("player_feedback", {}) as Dictionary).get("reason", "怪兽牌结算信息无效。")),
			str((validation.get("player_feedback", {}) as Dictionary).get("next_step", "刷新牌面后重试。")),
			validation.get("developer_fields", {}) as Dictionary
		)
	if str(intent.get("effect_kind", "")) != MONSTER_CARD_EFFECT_V06 or str(intent.get("action_kind", "")) != MONSTER_CARD_ACTION_V06:
		return _monster_card_failure_v06(intent, "monster_action_unsupported", "当前只支持正式怪兽部署牌。", "请选择部署或升级怪兽牌。")
	var transaction_id := str(intent.get("transaction_id", ""))
	var replay := _monster_card_prepare_replay_v06(intent)
	if not replay.is_empty():
		return replay
	if int(intent.get("expected_owner_revision", -1)) != _monster_card_revision_v06:
		return _monster_card_failure_v06(intent, "monster_owner_revision_stale", "怪兽状态已经变化。", "刷新怪兽与目标后重试。", {"actual_owner_revision": _monster_card_revision_v06})
	var catalog_result := _monster_card_catalog_binding_v06(intent)
	if not bool(catalog_result.get("valid", false)):
		return _monster_card_failure_v06(intent, str(catalog_result.get("reason_code", "monster_card_catalog_binding_invalid")), "怪兽牌档案无法确认。", "刷新牌面后重试。", catalog_result)
	var dependency_matrix := _monster_card_dependency_matrix_v06()
	if not bool(dependency_matrix.get("atomic_ready", false)):
		return _monster_card_failure_v06(intent, MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06, "这张怪兽牌正在安全接线中，当前不会消耗卡牌或资产。", "请选择其他已可用的卡牌。", {"cross_owner_dependency_matrix": dependency_matrix})
	var target: Dictionary = intent.get("target_context", {})
	var actor_id := str(intent.get("actor_id", ""))
	var rule_snapshot := _monster_card_rule_snapshot_v06(actor_id)
	if not bool(rule_snapshot.get("valid", false)):
		return _monster_card_failure_v06(intent, str(rule_snapshot.get("reason_code", "monster_binding_rule_unavailable")), "怪兽归属规则无法确认。", "刷新玩家状态后重试。", rule_snapshot)
	var expected_rule_revision := int(target.get("expected_binding_rule_revision", -1))
	if expected_rule_revision < 0 or expected_rule_revision != int(rule_snapshot.get("revision", -1)):
		return _monster_card_failure_v06(intent, "monster_binding_rule_revision_stale", "怪兽归属上限已经变化。", "刷新玩家状态后重试。", {"expected_revision": expected_rule_revision, "actual_revision": int(rule_snapshot.get("revision", -1))})
	var family_id := str(catalog_result.get("monster_family_id", ""))
	var card_rank := int(catalog_result.get("card_rank", 0))
	var player_index := int(rule_snapshot.get("player_index", -1))
	var starter_state := _monster_starter_state_for_actor_v06(actor_id, player_index)
	if starter_state == "legacy_unknown":
		return _monster_card_failure_v06(intent, "monster_starter_state_legacy_unknown", "旧存档中的首召状态无法安全确认。", "重新开始对局或完成存档迁移。")
	var global_same_family := _monster_card_global_active_family_slots_v06(family_id)
	if global_same_family.size() > 1:
		return _monster_card_failure_v06(intent, "monster_same_family_roster_corrupt", "同族怪兽状态异常。", "重新载入场景后重试。", {"matching_count": global_same_family.size(), "family_id": family_id})
	if starter_state == "summoned":
		if global_same_family.is_empty():
			return _monster_card_prepare_ordinary_summon_v06(intent, catalog_result, rule_snapshot, dependency_matrix)
		return _monster_card_prepare_upgrade_v06(intent, catalog_result, rule_snapshot, dependency_matrix, int(global_same_family[0]))
	if card_rank != 1:
		return _monster_card_failure_v06(intent, "monster_non_starter_deploy_deferred", "首召只能使用 I 级起始怪兽牌。", "请选择本席的 I 级起始怪兽牌。")
	if not bool(rule_snapshot.get("starter_entitled", false)) or bool(rule_snapshot.get("starter_consumed", false)):
		return _monster_card_failure_v06(intent, "monster_starter_entitlement_unavailable", "本席没有可用的首召资格。", "检查起始怪兽牌或刷新席位状态。")
	var entitled_card_id := str(rule_snapshot.get("starter_card_id", ""))
	if not entitled_card_id.is_empty() and entitled_card_id != str(intent.get("card_id", "")):
		return _monster_card_failure_v06(intent, "monster_starter_card_binding_mismatch", "这不是本席选定的起始怪兽牌。", "使用本席的 I 级起始怪兽牌。")
	var entitled_instance_id := str(rule_snapshot.get("starter_card_instance_id", ""))
	if not entitled_instance_id.is_empty() and entitled_instance_id != str(intent.get("card_instance_id", "")):
		return _monster_card_failure_v06(intent, "monster_starter_card_instance_mismatch", "起始怪兽牌实例已经变化。", "刷新手牌后重试。")
	if not global_same_family.is_empty():
		return _monster_card_starter_reselect_failure_v06(intent, family_id)
	var owned_active_count := _monster_card_owned_active_count_v06(actor_id, player_index)
	if owned_active_count > 0 and int(target.get("unit_uid", 0)) <= 0:
		return _monster_card_failure_v06(intent, "monster_starter_already_summoned", "本席已经完成首召。", "继续建设或购买卡牌。", {"owned_count": owned_active_count})
	if int(target.get("unit_uid", 0)) > 0:
		return _monster_card_failure_v06(intent, "monster_upgrade_target_missing", "所选同族怪兽已经不在场。", "选择合法部署区域。")
	var binding_caps := _monster_binding_caps_v06(actor_id, false)
	var binding_slot := _monster_binding_slot_decision_v06(actor_id, player_index, 0, binding_caps, true)
	if not bool(binding_slot.get("within_count", false)) or card_rank > int(binding_slot.get("rank_limit", 0)):
		return _monster_card_failure_v06(intent, "monster_binding_cap_suspended_for_new_summon", "本席当前没有可用的怪兽绑定名额。", "等待绑定能力恢复或选择其他行动。", {"owned_count": owned_active_count, "slot_kind": str(binding_slot.get("slot_kind", "primary"))})
	var region_id := str(target.get("region_id", ""))
	var region_snapshot := _monster_card_region_snapshot_v06(region_id, family_id)
	if not bool(region_snapshot.get("valid", false)):
		return _monster_card_failure_v06(intent, str(region_snapshot.get("reason_code", "monster_deploy_region_invalid")), "所选区域当前不能部署这只怪兽。", "选择一个未毁且符合牌面限制的区域。", region_snapshot)
	var expected_region_revision := int(target.get("expected_region_revision", -1))
	if expected_region_revision < 0 or expected_region_revision != int(region_snapshot.get("revision", -1)):
		return _monster_card_failure_v06(intent, "monster_region_revision_stale", "部署区域已经变化。", "刷新区域后重新选择。", {"expected_revision": expected_region_revision, "actual_revision": int(region_snapshot.get("revision", -1))})
	var profile_snapshot := _monster_card_profile_snapshot_v06(family_id, card_rank)
	if not bool(profile_snapshot.get("valid", false)):
		return _monster_card_failure_v06(intent, str(profile_snapshot.get("reason_code", "monster_profile_unavailable")), "怪兽单位档案无法确认。", "刷新牌面后重试。", profile_snapshot)
	var required_participants := _monster_card_required_participants_v06(profile_snapshot)
	if not _monster_card_participants_ready_v06(dependency_matrix, required_participants):
		return _monster_card_failure_v06(intent, MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06, "怪兽的关联效果尚未完成原子接线。", "请选择其他已可用的起始怪兽，或稍后重试。", {"required_participants": required_participants, "cross_owner_dependency_matrix": dependency_matrix})
	var preimage := _monster_card_core_state_envelope_v06()
	var next_state_result := _monster_card_build_deploy_postimage_v06(preimage, actor_id, player_index, catalog_result, profile_snapshot, region_snapshot)
	if not bool(next_state_result.get("valid", false)):
		return _monster_card_failure_v06(intent, str(next_state_result.get("reason_code", "monster_deploy_postimage_invalid")), "怪兽部署状态无法安全构造。", "刷新场景后重试。", next_state_result)
	var postimage: Dictionary = next_state_result.get("postimage", {})
	var post_starter_state: Dictionary = (postimage.get("starter_state", {}) as Dictionary).duplicate(true) if postimage.get("starter_state", {}) is Dictionary else {}
	var post_starter_row: Dictionary = (post_starter_state.get(actor_id, {}) as Dictionary).duplicate(true) if post_starter_state.get(actor_id, {}) is Dictionary else {}
	post_starter_row["transaction_id"] = transaction_id
	post_starter_state[actor_id] = post_starter_row
	postimage["starter_state"] = post_starter_state
	next_state_result["postimage"] = postimage
	var participant_binding := UNIT_CARD_SCHEMA_V06.fingerprint({
		"transaction_binding": UNIT_CARD_SCHEMA_V06.binding_from(intent),
		"owner_revision_before": _monster_card_revision_v06,
		"preimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(preimage),
		"postimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(postimage),
		"region_fingerprint": str(region_snapshot.get("snapshot_fingerprint", "")),
		"profile_fingerprint": str(profile_snapshot.get("snapshot_fingerprint", "")),
		"rule_fingerprint": str(rule_snapshot.get("snapshot_fingerprint", "")),
		"binding_capability_fingerprint": str(binding_caps.get("binding_fingerprint", "")),
	})
	var side_effect_plan := {
		"contract_version": MONSTER_CARD_CONTRACT_VERSION_V06,
		"transaction_id": transaction_id,
		"participant_binding_fingerprint": participant_binding,
		"operation": "deploy",
		"actor_id": actor_id,
		"player_index": player_index,
		"unit_uid": int(next_state_result.get("unit_uid", 0)),
		"monster_family_id": family_id,
		"card_rank": card_rank,
		"region_id": region_id,
		"profile_snapshot": profile_snapshot.duplicate(true),
		"p0_scope": "rank_1_starter_first_summon",
		"required_participants": required_participants.duplicate(),
		"bound_skill_recipient_actor_id": actor_id,
		"bound_skill_patch": (profile_snapshot.get("bound_skill_patch", {}) as Dictionary).duplicate(true) if profile_snapshot.get("bound_skill_patch", {}) is Dictionary else {},
		"economic_patch": (profile_snapshot.get("economic_patch", {}) as Dictionary).duplicate(true) if profile_snapshot.get("economic_patch", {}) is Dictionary else {},
		"role_cash_patch": {},
	}
	var cross_owner_required := not required_participants.is_empty()
	var side_prepare := _monster_card_cross_owner_stage_v06("prepare", side_effect_plan) if cross_owner_required else _monster_card_local_stage_receipt_v06("prepare", transaction_id, participant_binding, "deploy")
	if not bool(side_prepare.get("prepared", false)):
		return _monster_card_failure_v06(intent, str(side_prepare.get("reason_code", MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06)), "怪兽的关联效果无法安全预留。", "请稍后重试或选择其他卡牌。", {"cross_owner_receipt": side_prepare})
	if not _monster_card_cross_owner_receipt_matches_v06(side_prepare, transaction_id, participant_binding):
		return _monster_card_failure_v06(intent, "monster_cross_owner_prepare_binding_mismatch", "怪兽关联效果状态已经变化。", "刷新场景后重试。", {"cross_owner_receipt": side_prepare})
	var reservation := {
		"schema_version": MONSTER_CARD_LIFECYCLE_SCHEMA_V06,
		"stage": "prepared",
		"transaction_id": transaction_id,
		"intent_binding": UNIT_CARD_SCHEMA_V06.binding_from(intent),
		"intent": intent.duplicate(true),
		"owner_revision_before": _monster_card_revision_v06,
		"owner_revision_after": -1,
		"operation": "deploy",
		"unit_uid": int(next_state_result.get("unit_uid", 0)),
		"actor_revision_before": 0,
		"actor_revision_after": 1,
		"preimage": preimage,
		"postimage": postimage,
		"preimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(preimage),
		"postimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(postimage),
		"region_id": region_id,
		"region_revision": int(region_snapshot.get("revision", -1)),
		"region_fingerprint": str(region_snapshot.get("snapshot_fingerprint", "")),
		"profile_family_id": family_id,
		"profile_rank": card_rank,
		"profile_fingerprint": str(profile_snapshot.get("snapshot_fingerprint", "")),
		"rule_actor_id": actor_id,
		"rule_fingerprint": str(rule_snapshot.get("snapshot_fingerprint", "")),
		"binding_capability_actor_id": actor_id,
		"binding_capability_target_owner_query": false,
		"binding_capability_fingerprint": str(binding_caps.get("binding_fingerprint", "")),
		"binding_capability_window_sequence": int(binding_caps.get("window_sequence", -1)),
		"binding_capability_owner_revision": int(binding_caps.get("owner_revision", -1)),
		"binding_slot_kind": str(binding_slot.get("slot_kind", "primary")),
		"participant_binding_fingerprint": participant_binding,
		"cross_owner_required": cross_owner_required,
		"required_participants": required_participants.duplicate(),
		"cross_owner_prepare_receipt": side_prepare.duplicate(true),
		"cross_owner_commit_receipt": {},
		"rollback_open": false,
		"presentation_event": _monster_card_deploy_presentation_event_v06(next_state_result, region_snapshot),
	}
	reservation["reservation_fingerprint"] = _monster_card_reservation_fingerprint_v06(reservation)
	var prepared_receipt := _monster_card_receipt_v06(intent, reservation, "prepared")
	reservation["latest_receipt"] = prepared_receipt.duplicate(true)
	_monster_card_reservations_v06[transaction_id] = reservation
	return prepared_receipt


func commit_unit_card_intent_v06(prepared: Dictionary) -> Dictionary:
	_monster_card_lifecycle_call_counts_v06["commit"] = int(_monster_card_lifecycle_call_counts_v06.get("commit", 0)) + 1
	var association := _monster_card_authoritative_association_v06(prepared, ["prepared", "committed"])
	if not bool(association.get("valid", false)):
		return association.get("receipt", {}) as Dictionary
	if bool(association.get("terminal_replay", false)) or bool(association.get("committed_replay", false)):
		return (association.get("receipt", {}) as Dictionary).duplicate(true)
	var transaction_id := str(prepared.get("transaction_id", ""))
	var reservation: Dictionary = _monster_card_reservations_v06.get(transaction_id, {})
	if _monster_card_revision_v06 != int(reservation.get("owner_revision_before", -1)) or _monster_card_core_state_fingerprint_v06() != str(reservation.get("preimage_fingerprint", "")):
		return _monster_card_failure_v06(prepared, "monster_commit_preimage_changed", "怪兽状态已经变化。", "刷新场景后重新打出卡牌。")
	var revalidation := _monster_card_revalidate_deploy_facts_v06(reservation)
	if not bool(revalidation.get("valid", false)):
		return _monster_card_failure_v06(prepared, str(revalidation.get("reason_code", "monster_commit_fact_binding_changed")), "部署条件已经变化。", "刷新区域和怪兽后重试。", revalidation)
	var side_commit_request := {
		"transaction_id": transaction_id,
		"participant_binding_fingerprint": str(reservation.get("participant_binding_fingerprint", "")),
		"prepared_receipt": (reservation.get("cross_owner_prepare_receipt", {}) as Dictionary).duplicate(true),
	}
	var side_commit := _monster_card_cross_owner_stage_v06("commit", side_commit_request) if bool(reservation.get("cross_owner_required", false)) else _monster_card_local_stage_receipt_v06("commit", transaction_id, str(reservation.get("participant_binding_fingerprint", "")), str(reservation.get("operation", "deploy")))
	if not bool(side_commit.get("committed", false)):
		return _monster_card_failure_v06(prepared, str(side_commit.get("reason_code", "monster_cross_owner_commit_failed")), "怪兽关联效果未能安全提交。", "请稍后重试。", {"cross_owner_receipt": side_commit})
	if not _monster_card_cross_owner_receipt_matches_v06(side_commit, transaction_id, str(reservation.get("participant_binding_fingerprint", ""))):
		return _monster_card_failure_v06(prepared, "monster_cross_owner_commit_binding_mismatch", "怪兽关联效果状态已经变化。", "刷新场景后重试。", {"cross_owner_receipt": side_commit})
	_monster_card_swap_core_state_v06(reservation.get("postimage", {}) as Dictionary)
	_monster_card_revision_v06 += 1
	reservation["owner_revision_after"] = _monster_card_revision_v06
	reservation["stage"] = "committed"
	reservation["rollback_open"] = true
	reservation["cross_owner_commit_receipt"] = side_commit.duplicate(true)
	var committed_receipt := _monster_card_receipt_v06(reservation.get("intent", {}) as Dictionary, reservation, "committed")
	reservation["latest_receipt"] = committed_receipt.duplicate(true)
	_monster_card_reservations_v06[transaction_id] = reservation
	return committed_receipt


func rollback_unit_card_intent_v06(source_receipt: Dictionary) -> Dictionary:
	_monster_card_lifecycle_call_counts_v06["rollback"] = int(_monster_card_lifecycle_call_counts_v06.get("rollback", 0)) + 1
	var association := _monster_card_authoritative_association_v06(source_receipt, ["prepared", "committed"])
	if not bool(association.get("valid", false)):
		return association.get("receipt", {}) as Dictionary
	if bool(association.get("terminal_replay", false)):
		return (association.get("receipt", {}) as Dictionary).duplicate(true)
	var transaction_id := str(source_receipt.get("transaction_id", ""))
	var reservation: Dictionary = _monster_card_reservations_v06.get(transaction_id, {})
	var was_committed := str(reservation.get("stage", "")) == "committed"
	if was_committed:
		if not bool(reservation.get("rollback_open", false)):
			return _monster_card_failure_v06(source_receipt, "monster_rollback_window_closed", "这次怪兽效果已经完成结算。", "无需再次撤销。")
		if _monster_card_revision_v06 != int(reservation.get("owner_revision_after", -1)) or _monster_card_core_state_fingerprint_v06() != str(reservation.get("postimage_fingerprint", "")):
			return _monster_card_failure_v06(source_receipt, "monster_rollback_postimage_changed", "怪兽状态已经继续推进，无法安全撤销。", "刷新场景并查看当前状态。")
	var side_rollback_request := {
		"transaction_id": transaction_id,
		"participant_binding_fingerprint": str(reservation.get("participant_binding_fingerprint", "")),
		"prepared_receipt": (reservation.get("cross_owner_prepare_receipt", {}) as Dictionary).duplicate(true),
		"committed_receipt": (reservation.get("cross_owner_commit_receipt", {}) as Dictionary).duplicate(true),
		"committed": was_committed,
	}
	var side_rollback := _monster_card_cross_owner_stage_v06("rollback", side_rollback_request) if bool(reservation.get("cross_owner_required", false)) else _monster_card_local_stage_receipt_v06("rollback", transaction_id, str(reservation.get("participant_binding_fingerprint", "")), str(reservation.get("operation", "deploy")))
	if not bool(side_rollback.get("rolled_back", false)):
		var failed := _monster_card_failure_v06(source_receipt, "monster_compensation_failed", "怪兽效果未能安全撤销。", "请保留当前场景并重试。", {"cross_owner_receipt": side_rollback})
		failed["compensation_failed"] = true
		failed["rolled_back"] = false
		return failed
	if not _monster_card_cross_owner_receipt_matches_v06(side_rollback, transaction_id, str(reservation.get("participant_binding_fingerprint", ""))):
		return _monster_card_failure_v06(source_receipt, "monster_cross_owner_rollback_binding_mismatch", "怪兽关联效果未能确认撤销。", "请保留当前场景并重试。", {"cross_owner_receipt": side_rollback})
	if was_committed:
		_monster_card_swap_core_state_v06(reservation.get("preimage", {}) as Dictionary)
		_monster_card_revision_v06 += 1
	var rolled_back_receipt := _monster_card_receipt_v06(reservation.get("intent", {}) as Dictionary, reservation, "rolled_back")
	rolled_back_receipt["owner_revision_terminal"] = _monster_card_revision_v06
	rolled_back_receipt["cross_owner_rollback_receipt"] = side_rollback.duplicate(true)
	_monster_card_terminal_journal_v06[transaction_id] = {
		"schema_version": MONSTER_CARD_LIFECYCLE_SCHEMA_V06,
		"stage": "rolled_back",
		"intent_binding": (reservation.get("intent_binding", {}) as Dictionary).duplicate(true),
		"reservation_fingerprint": str(reservation.get("reservation_fingerprint", "")),
		"receipt": rolled_back_receipt.duplicate(true),
	}
	_monster_card_reservations_v06.erase(transaction_id)
	return rolled_back_receipt


func finalize_unit_card_intent_v06(source_receipt: Dictionary) -> Dictionary:
	_monster_card_lifecycle_call_counts_v06["finalize"] = int(_monster_card_lifecycle_call_counts_v06.get("finalize", 0)) + 1
	var association := _monster_card_authoritative_association_v06(source_receipt, ["committed"])
	if not bool(association.get("valid", false)):
		return association.get("receipt", {}) as Dictionary
	if bool(association.get("terminal_replay", false)):
		return (association.get("receipt", {}) as Dictionary).duplicate(true)
	var transaction_id := str(source_receipt.get("transaction_id", ""))
	var reservation: Dictionary = _monster_card_reservations_v06.get(transaction_id, {})
	var side_finalize_request := {
		"transaction_id": transaction_id,
		"participant_binding_fingerprint": str(reservation.get("participant_binding_fingerprint", "")),
		"committed_receipt": (reservation.get("cross_owner_commit_receipt", {}) as Dictionary).duplicate(true),
	}
	var side_finalize := _monster_card_cross_owner_stage_v06("finalize", side_finalize_request) if bool(reservation.get("cross_owner_required", false)) else _monster_card_local_stage_receipt_v06("finalize", transaction_id, str(reservation.get("participant_binding_fingerprint", "")), str(reservation.get("operation", "deploy")))
	if not bool(side_finalize.get("finalized", false)):
		var failed := _monster_card_failure_v06(source_receipt, str(side_finalize.get("reason_code", "monster_cross_owner_finalize_failed")), "怪兽效果尚未完成收尾。", "请稍后重试。", {"cross_owner_receipt": side_finalize})
		failed["committed"] = true
		return failed
	if not _monster_card_cross_owner_receipt_matches_v06(side_finalize, transaction_id, str(reservation.get("participant_binding_fingerprint", ""))):
		var mismatch := _monster_card_failure_v06(source_receipt, "monster_cross_owner_finalize_binding_mismatch", "怪兽效果尚未完成收尾。", "请稍后重试。", {"cross_owner_receipt": side_finalize})
		mismatch["committed"] = true
		return mismatch
	reservation["rollback_open"] = false
	reservation["stage"] = "finalized"
	var finalized_receipt := _monster_card_receipt_v06(reservation.get("intent", {}) as Dictionary, reservation, "finalized")
	finalized_receipt["cross_owner_finalize_receipt"] = side_finalize.duplicate(true)
	_monster_card_terminal_journal_v06[transaction_id] = {
		"schema_version": MONSTER_CARD_LIFECYCLE_SCHEMA_V06,
		"stage": "finalized",
		"intent_binding": (reservation.get("intent_binding", {}) as Dictionary).duplicate(true),
		"reservation_fingerprint": str(reservation.get("reservation_fingerprint", "")),
		"receipt": finalized_receipt.duplicate(true),
	}
	_monster_card_reservations_v06.erase(transaction_id)
	if not _monster_card_presentation_journal_v06.has(transaction_id):
		_monster_card_presentation_journal_v06[transaction_id] = true
		if _world_bridge != null and _world_bridge.has_method("forward_runtime_event"):
			_world_bridge.call("forward_runtime_event", (reservation.get("presentation_event", {}) as Dictionary).duplicate(true))
	return finalized_receipt


func unit_card_save_data_v06(domain: String) -> Dictionary:
	if domain != "monster":
		return {"valid": false, "reason_code": "monster_owner_domain_mismatch", "domain": domain}
	var result := to_save_data()
	result["contract_version"] = MONSTER_CARD_CONTRACT_VERSION_V06
	result["domain"] = "monster"
	return result


func apply_unit_card_save_data_v06(data: Dictionary, domain: String = "monster") -> Dictionary:
	if domain != "monster" and str(data.get("domain", "monster")) != "monster":
		return {"applied": false, "reason_code": "monster_owner_domain_mismatch", "domain": domain}
	return apply_save_data(data)


func _monster_card_dependency_matrix_v06() -> Dictionary:
	var declared: Dictionary = {}
	if _world_bridge != null and _world_bridge.has_method("monster_deploy_cross_owner_capabilities_v06"):
		var value_variant: Variant = _world_bridge.call("monster_deploy_cross_owner_capabilities_v06")
		if value_variant is Dictionary:
			declared = (value_variant as Dictionary).duplicate(true)
	var fact_ports_ready := str(declared.get("contract_version", "")) == MONSTER_CARD_CONTRACT_VERSION_V06
	for fact_name in MONSTER_CARD_REQUIRED_FACT_PORTS_V06:
		var fact: Dictionary = declared.get(fact_name, {}) if declared.get(fact_name, {}) is Dictionary else {}
		fact_ports_ready = fact_ports_ready and bool(fact.get("revisioned_snapshot", false))
	var participants_ready := true
	for participant_name in MONSTER_CARD_REQUIRED_ATOMIC_PARTICIPANTS_V06:
		var participant: Dictionary = declared.get(participant_name, {}) if declared.get(participant_name, {}) is Dictionary else {}
		for capability_name in ["prepare", "commit", "rollback", "finalize", "exact_once", "checkpoint", "save_load"]:
			participants_ready = participants_ready and bool(participant.get(capability_name, false))
	var result := declared.duplicate(true)
	result["fact_ports_ready"] = fact_ports_ready
	result["participants_ready"] = participants_ready
	result["full_cross_owner_ready"] = participants_ready and bool(declared.get("methods_ready", false))
	# VS06-B only advertises rank-I starter deployment. Cross-owner participants
	# become mandatory per intent when the authoritative profile supplies a
	# non-empty side-effect patch; the roster lifecycle itself only needs the
	# three revisioned fact ports.
	result["atomic_ready"] = fact_ports_ready
	result["p0_scope"] = "rank_1_starter_first_summon_and_same_family_upgrade"
	result["reason_code"] = "monster_starter_and_same_family_upgrade_ready" if bool(result["atomic_ready"]) else MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06
	return result


func _monster_save_envelope_v06(data: Dictionary) -> Dictionary:
	for array_key in ["auto_monsters", "active_monster_wagers", "resolved_monster_wager_history"]:
		if data.has(array_key) and not (data.get(array_key) is Array):
			return {"valid": false, "reason_code": "monster_save_%s_invalid" % array_key}
	for dictionary_key in ["monster_card_atomic_starter_state", "monster_card_atomic_reservations", "monster_card_atomic_terminal_journal", "monster_card_atomic_presentation_journal"]:
		if data.has(dictionary_key) and not (data.get(dictionary_key) is Dictionary):
			return {"valid": false, "reason_code": "monster_save_%s_invalid" % dictionary_key}
	var roster: Array = (data.get("auto_monsters", []) as Array).duplicate(true)
	var seen_uids: Dictionary = {}
	var seen_v06_active_families: Dictionary = {}
	var maximum_uid := 0
	for index in range(roster.size()):
		if not (roster[index] is Dictionary):
			return {"valid": false, "reason_code": "monster_save_actor_invalid"}
		var actor := (roster[index] as Dictionary).duplicate(true)
		var uid := int(actor.get("uid", 0))
		if uid <= 0 or seen_uids.has(uid):
			return {"valid": false, "reason_code": "monster_save_actor_uid_invalid"}
		seen_uids[uid] = true
		var explicit_family_id := str(actor.get("monster_family_id", "")).strip_edges()
		if not explicit_family_id.is_empty() and not bool(actor.get("down", false)):
			if seen_v06_active_families.has(explicit_family_id):
				return {"valid": false, "reason_code": "monster_save_same_family_duplicate"}
			seen_v06_active_families[explicit_family_id] = uid
		maximum_uid = maxi(maximum_uid, uid)
		actor["slot"] = index
		roster[index] = actor
	var next_uid := maxi(1, int(data.get("next_auto_monster_uid", maximum_uid + 1)))
	if next_uid <= maximum_uid:
		return {"valid": false, "reason_code": "monster_save_uid_allocator_stale"}
	var roster_size := roster.size()
	var next_special := 0 if roster_size == 0 else clampi(int(data.get("next_special_monster_slot", 0)), 0, roster_size - 1)
	var selected_slot := 0 if roster_size == 0 else clampi(int(data.get("selected_auto_monster_slot", 0)), 0, roster_size - 1)
	var atomic_schema := str(data.get("monster_card_atomic_schema_version", ""))
	if not atomic_schema.is_empty() and atomic_schema != MONSTER_CARD_LIFECYCLE_SCHEMA_V06:
		return {"valid": false, "reason_code": "monster_save_atomic_schema_mismatch"}
	var owner_revision := int(data.get("monster_card_atomic_owner_revision", 0))
	if owner_revision < 0:
		return {"valid": false, "reason_code": "monster_save_owner_revision_invalid"}
	var starter_state: Dictionary = (data.get("monster_card_atomic_starter_state", {}) as Dictionary).duplicate(true)
	for actor_id_variant in starter_state.keys():
		var actor_id := str(actor_id_variant).strip_edges()
		var row_variant: Variant = starter_state.get(actor_id_variant)
		if actor_id.is_empty() or not (row_variant is Dictionary):
			return {"valid": false, "reason_code": "monster_save_starter_state_invalid"}
		var state := str((row_variant as Dictionary).get("state", ""))
		if not ["not_summoned", "summoned", "legacy_unknown"].has(state):
			return {"valid": false, "reason_code": "monster_save_starter_state_invalid"}
	var reservations: Dictionary = (data.get("monster_card_atomic_reservations", {}) as Dictionary).duplicate(true)
	var terminal_journal: Dictionary = (data.get("monster_card_atomic_terminal_journal", {}) as Dictionary).duplicate(true)
	var presentation_journal: Dictionary = (data.get("monster_card_atomic_presentation_journal", {}) as Dictionary).duplicate(true)
	var candidate_core := {
		"auto_monsters": roster,
		"next_auto_monster_uid": next_uid,
		"next_special_monster_slot": next_special,
		"selected_auto_monster_slot": selected_slot,
		"starter_state": starter_state,
	}
	var candidate_fingerprint := _monster_card_core_state_fingerprint_from_envelope_v06(candidate_core)
	for transaction_variant in reservations.keys():
		var transaction_id := str(transaction_variant)
		var reservation_variant: Variant = reservations.get(transaction_variant)
		if transaction_id.is_empty() or not (reservation_variant is Dictionary):
			return {"valid": false, "reason_code": "monster_save_reservation_invalid"}
		var reservation := reservation_variant as Dictionary
		if str(reservation.get("schema_version", "")) != MONSTER_CARD_LIFECYCLE_SCHEMA_V06 or str(reservation.get("transaction_id", "")) != transaction_id or not ["prepared", "committed"].has(str(reservation.get("stage", ""))):
			return {"valid": false, "reason_code": "monster_save_reservation_binding_invalid"}
		if str(reservation.get("reservation_fingerprint", "")) != _monster_card_reservation_fingerprint_v06(reservation):
			return {"valid": false, "reason_code": "monster_save_reservation_fingerprint_invalid"}
		var expected_core := str(reservation.get("postimage_fingerprint", "")) if str(reservation.get("stage", "")) == "committed" else str(reservation.get("preimage_fingerprint", ""))
		if expected_core != candidate_fingerprint:
			return {"valid": false, "reason_code": "monster_save_reservation_core_mismatch"}
	for transaction_variant in terminal_journal.keys():
		var transaction_id := str(transaction_variant)
		var terminal_variant: Variant = terminal_journal.get(transaction_variant)
		if transaction_id.is_empty() or not (terminal_variant is Dictionary):
			return {"valid": false, "reason_code": "monster_save_terminal_invalid"}
		var terminal := terminal_variant as Dictionary
		var intent_binding: Dictionary = terminal.get("intent_binding", {}) if terminal.get("intent_binding", {}) is Dictionary else {}
		var terminal_receipt: Dictionary = terminal.get("receipt", {}) if terminal.get("receipt", {}) is Dictionary else {}
		if (
			not ["rolled_back", "finalized"].has(str(terminal.get("stage", "")))
			or str(intent_binding.get("transaction_id", "")) != transaction_id
			or str(terminal_receipt.get("transaction_id", "")) != transaction_id
			or not _monster_card_binding_matches_v06(intent_binding, terminal_receipt)
		):
			return {"valid": false, "reason_code": "monster_save_terminal_invalid"}
	for transaction_variant in presentation_journal.keys():
		if not (presentation_journal.get(transaction_variant) is bool):
			return {"valid": false, "reason_code": "monster_save_presentation_journal_invalid"}
	return {
		"valid": true,
		"state": {
			"auto_monsters": roster,
			"next_auto_monster_uid": next_uid,
			"next_special_monster_slot": next_special,
			"selected_auto_monster_slot": selected_slot,
			"active_monster_wagers": (data.get("active_monster_wagers", []) as Array).duplicate(true),
			"resolved_monster_wager_history": (data.get("resolved_monster_wager_history", []) as Array).duplicate(true),
			"monster_wager_sequence": maxi(0, int(data.get("monster_wager_sequence", 0))),
			"public_card_bid_monster_wager_pool": maxi(0, int(data.get("public_card_bid_monster_wager_pool", 0))),
			"monster_timer": maxf(0.0, float(data.get("monster_timer", 4.0))),
			"special_monster_timer": maxf(0.0, float(data.get("special_monster_timer", 5.0))),
			"monster_card_atomic_owner_revision": owner_revision,
			"monster_card_atomic_starter_state": starter_state,
			"monster_card_atomic_reservations": reservations,
			"monster_card_atomic_terminal_journal": terminal_journal,
			"monster_card_atomic_presentation_journal": presentation_journal,
		},
	}


func _monster_card_failure_v06(source: Dictionary, reason_code: String, player_reason: String, next_step: String, developer_fields: Dictionary = {}) -> Dictionary:
	return UNIT_CARD_SCHEMA_V06.failure_receipt(source, reason_code, player_reason, next_step, developer_fields)


func _monster_card_starter_reselect_failure_v06(intent: Dictionary, family_id: String) -> Dictionary:
	var result := _monster_card_failure_v06(
		intent,
		"starter_monster_family_reserved",
		"这只起始怪兽已被本局占用，请私下重选。",
		"返回起始怪兽选择并改选另一族系。"
	)
	result["card_consumed"] = false
	result["private_reselect"] = true
	result["private_fields"] = {
		"private_target": {
			"reselect_required": true,
			"reselect_reason": "starter_monster_family_reserved",
			"monster_family_id": family_id,
		}
	}
	return result


func _monster_card_prepare_replay_v06(intent: Dictionary) -> Dictionary:
	var transaction_id := str(intent.get("transaction_id", ""))
	if _monster_card_reservations_v06.has(transaction_id):
		var reservation: Dictionary = _monster_card_reservations_v06.get(transaction_id, {})
		if not _monster_card_binding_matches_v06(reservation.get("intent_binding", {}) as Dictionary, intent):
			return _monster_card_failure_v06(intent, "monster_transaction_binding_conflict", "这次结算编号已经绑定到另一张牌。", "重新打出这张牌。")
		var replay: Dictionary = (reservation.get("latest_receipt", {}) as Dictionary).duplicate(true)
		replay["idempotent_replay"] = true
		return replay
	if _monster_card_terminal_journal_v06.has(transaction_id):
		var terminal: Dictionary = _monster_card_terminal_journal_v06.get(transaction_id, {})
		if not _monster_card_binding_matches_v06(terminal.get("intent_binding", {}) as Dictionary, intent):
			return _monster_card_failure_v06(intent, "monster_transaction_binding_conflict", "这次结算编号已经绑定到另一张牌。", "重新打出这张牌。")
		var terminal_receipt: Dictionary = (terminal.get("receipt", {}) as Dictionary).duplicate(true)
		terminal_receipt["idempotent_replay"] = true
		return terminal_receipt
	return {}


func _monster_card_catalog_binding_v06(intent: Dictionary) -> Dictionary:
	var card_id := str(intent.get("card_id", ""))
	var card_variant: Variant = CARD_RUNTIME_CATALOG_V06.call("card_snapshot", card_id)
	if not (card_variant is Dictionary):
		return {"valid": false, "reason_code": "monster_card_catalog_missing", "card_id": card_id}
	var card: Dictionary = card_variant as Dictionary
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var fields: Dictionary = intent.get("effect_fields", {}) if intent.get("effect_fields", {}) is Dictionary else {}
	if str(machine.get("card_id", "")) != card_id or str(machine.get("category_id", "")) != "monster" or str(machine.get("effect_kind", "")) != MONSTER_CARD_EFFECT_V06:
		return {"valid": false, "reason_code": "monster_card_catalog_kind_mismatch", "card_id": card_id}
	for key_variant in payload.keys():
		var key := str(key_variant)
		if not fields.has(key) or not _monster_card_catalog_value_matches_v06(fields.get(key), payload.get(key)):
			return {"valid": false, "reason_code": "monster_card_catalog_payload_mismatch", "field": key, "card_id": card_id}
	var rank := int(machine.get("rank", 0))
	var family_id := str(payload.get("monster_family_id", ""))
	if rank < 1 or rank > 4 or int(payload.get("card_rank", 0)) != rank or family_id.is_empty():
		return {"valid": false, "reason_code": "monster_card_catalog_profile_invalid", "card_id": card_id}
	return {
		"valid": true,
		"card_id": card_id,
		"family_id": str(machine.get("family_id", "")),
		"monster_family_id": family_id,
		"card_rank": rank,
		"effect_payload": payload.duplicate(true),
		"catalog_payload_fingerprint": UNIT_CARD_SCHEMA_V06.fingerprint(payload),
		"player_name": str((card.get("player", {}) as Dictionary).get("name", "")) if card.get("player", {}) is Dictionary else "",
	}


func _monster_card_catalog_value_matches_v06(actual: Variant, expected: Variant) -> bool:
	# JSON-backed Resource values may surface integral numbers as floats while
	# CardFlow intents use ints. Treat numerically equivalent payload fields as
	# the same authoritative catalog binding without weakening other types.
	if (actual is int or actual is float) and (expected is int or expected is float):
		return is_equal_approx(float(actual), float(expected))
	return UNIT_CARD_SCHEMA_V06.fingerprint(actual) == UNIT_CARD_SCHEMA_V06.fingerprint(expected)


func _monster_card_rule_snapshot_v06(actor_id: String) -> Dictionary:
	if _world_bridge == null or not _world_bridge.has_method("monster_deploy_rule_snapshot_v06"):
		return {"valid": false, "reason_code": "monster_binding_rule_unavailable"}
	var value_variant: Variant = _world_bridge.call("monster_deploy_rule_snapshot_v06", actor_id)
	if not (value_variant is Dictionary):
		return {"valid": false, "reason_code": "monster_binding_rule_invalid"}
	var snapshot: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not bool(snapshot.get("available", false)) or not bool(snapshot.get("authoritative", false)) or int(snapshot.get("revision", -1)) < 0 or int(snapshot.get("player_index", -1)) < 0 or str(snapshot.get("snapshot_fingerprint", "")).is_empty():
		snapshot["valid"] = false
		if str(snapshot.get("reason_code", "")).is_empty():
			snapshot["reason_code"] = "monster_binding_rule_invalid"
		return snapshot
	snapshot["valid"] = true
	return snapshot


func _monster_card_region_snapshot_v06(region_id: String, family_id: String) -> Dictionary:
	if region_id.strip_edges().is_empty() or _world_bridge == null or not _world_bridge.has_method("monster_deploy_region_snapshot_v06"):
		return {"valid": false, "reason_code": "monster_deploy_region_snapshot_unavailable", "region_id": region_id}
	var value_variant: Variant = _world_bridge.call("monster_deploy_region_snapshot_v06", region_id)
	if not (value_variant is Dictionary):
		return {"valid": false, "reason_code": "monster_deploy_region_snapshot_invalid", "region_id": region_id}
	var snapshot: Dictionary = (value_variant as Dictionary).duplicate(true)
	var region_index := int(snapshot.get("region_index", snapshot.get("district_index", -1)))
	var allowed := bool(snapshot.get("starter_summon_allowed", snapshot.get("summon_allowed", not bool(snapshot.get("destroyed", true)))))
	if not bool(snapshot.get("available", false)) or not bool(snapshot.get("authoritative", false)) or int(snapshot.get("revision", -1)) < 0 or region_index < 0 or bool(snapshot.get("destroyed", true)) or not allowed or str(snapshot.get("snapshot_fingerprint", "")).is_empty():
		snapshot["valid"] = false
		if str(snapshot.get("reason_code", "")).is_empty():
			snapshot["reason_code"] = "monster_deploy_region_invalid"
		return snapshot
	var allowed_families: Array = snapshot.get("allowed_monster_families", []) if snapshot.get("allowed_monster_families", []) is Array else []
	if not allowed_families.is_empty() and not allowed_families.has(family_id):
		snapshot["valid"] = false
		snapshot["reason_code"] = "monster_deploy_region_family_rejected"
		return snapshot
	snapshot["region_index"] = region_index
	snapshot["valid"] = true
	return snapshot


func _monster_card_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
	if _world_bridge == null or not _world_bridge.has_method("monster_deploy_profile_snapshot_v06"):
		return {"valid": false, "reason_code": "monster_profile_unavailable", "family_id": family_id, "rank": rank}
	var value_variant: Variant = _world_bridge.call("monster_deploy_profile_snapshot_v06", family_id, rank)
	if not (value_variant is Dictionary):
		return {"valid": false, "reason_code": "monster_profile_invalid", "family_id": family_id, "rank": rank}
	var snapshot: Dictionary = (value_variant as Dictionary).duplicate(true)
	var hp := int(snapshot.get("hp", snapshot.get("max_hp", 0)))
	var move_mps := float(snapshot.get("move_mps", snapshot.get("move", -1.0)))
	var duration_seconds := float(snapshot.get("initial_duration_seconds", snapshot.get("duration", 0.0)))
	if not bool(snapshot.get("available", false)) or not bool(snapshot.get("authoritative", false)) or str(snapshot.get("family_id", "")) != family_id or int(snapshot.get("rank", 0)) != rank or int(snapshot.get("revision", -1)) < 0 or hp <= 0 or move_mps < 0.0 or duration_seconds <= 0.0 or str(snapshot.get("snapshot_fingerprint", "")).is_empty():
		snapshot["valid"] = false
		if str(snapshot.get("reason_code", "")).is_empty():
			snapshot["reason_code"] = "monster_profile_invalid"
		return snapshot
	snapshot["hp"] = hp
	snapshot["move_mps"] = move_mps
	snapshot["initial_duration_seconds"] = duration_seconds
	snapshot["valid"] = true
	return snapshot


func _monster_card_owned_active_count_v06(actor_id: String, player_index: int) -> int:
	var count := 0
	for actor_variant in auto_monsters:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)):
			continue
		if _monster_card_actor_owned_by_v06(actor, actor_id, player_index):
			count += 1
	return count


func _monster_card_global_active_family_slots_v06(family_id: String) -> Array:
	var result: Array = []
	for slot in range(auto_monsters.size()):
		if not (auto_monsters[slot] is Dictionary):
			continue
		var actor := auto_monsters[slot] as Dictionary
		if bool(actor.get("down", false)):
			continue
		if _monster_family_id_for_actor_v06(actor) == family_id:
			result.append(slot)
	return result


func _monster_binding_base_caps_v06(actor_id: String, reason_code: String) -> Dictionary:
	var result := {
		"available": true,
		"authoritative": true,
		"provider_valid": false,
		"fallback": true,
		"reason_code": reason_code,
		"actor_id": actor_id,
		"window_sequence": -1,
		"window_revision": -1,
		"owner_revision": -1,
		"capability_kind": MONSTER_BINDING_CAPABILITY_KIND_V06,
		"controlled_monster_count_limit": MONSTER_BASE_COUNT_LIMIT_V06,
		"primary_monster_rank_limit": MONSTER_BASE_PRIMARY_RANK_CAP_V06,
		"secondary_monster_rank_limit": MONSTER_BASE_SECONDARY_RANK_CAP_V06,
		"validation_mode": "base_fail_closed",
	}
	result["binding_fingerprint"] = _monster_binding_caps_fingerprint_v06(result)
	return result


func _monster_binding_caps_v06(actor_id: String, for_target_owner: bool) -> Dictionary:
	var normalized_actor_id := actor_id.strip_edges()
	if normalized_actor_id.is_empty():
		return _monster_binding_base_caps_v06(normalized_actor_id, "monster_binding_capability_actor_invalid")
	var provider := _monster_binding_capability_provider_v06
	if provider == null or not is_instance_valid(provider):
		return _monster_binding_base_caps_v06(normalized_actor_id, "monster_binding_capability_provider_unavailable")
	var window_variant: Variant = provider.call("current_monster_binding_window_snapshot_v06")
	if not (window_variant is Dictionary):
		return _monster_binding_base_caps_v06(normalized_actor_id, "monster_binding_window_snapshot_invalid")
	var window := window_variant as Dictionary
	var window_sequence := int(window.get("window_sequence", -1))
	var window_revision := int(window.get("revision", -1))
	if not bool(window.get("available", false)) or not bool(window.get("authoritative", false)) or window_sequence < 0 or window_revision < 0:
		return _monster_binding_base_caps_v06(normalized_actor_id, "monster_binding_window_snapshot_invalid")
	var method_name := "monster_binding_caps_for_target_owner" if for_target_owner else "monster_binding_caps"
	var raw_variant: Variant = provider.call(method_name, normalized_actor_id, window_sequence)
	if not (raw_variant is Dictionary):
		return _monster_binding_base_caps_v06(normalized_actor_id, "monster_binding_capability_snapshot_invalid")
	var raw := (raw_variant as Dictionary).duplicate(true)
	var count_limit := int(raw.get("controlled_monster_count_limit", -1))
	var primary_limit := int(raw.get("primary_monster_rank_limit", -1))
	var secondary_limit := int(raw.get("secondary_monster_rank_limit", -1))
	var gradient_valid := _monster_binding_gradient_valid_v06(count_limit, primary_limit, secondary_limit)
	var identity_valid := (
		bool(raw.get("available", false))
		and bool(raw.get("authoritative", false))
		and str(raw.get("actor_id", "")) == normalized_actor_id
		and int(raw.get("window_sequence", -1)) == window_sequence
		and int(raw.get("owner_revision", -1)) >= 0
		and str(raw.get("capability_kind", "")) == MONSTER_BINDING_CAPABILITY_KIND_V06
	)
	if not identity_valid or not gradient_valid:
		return _monster_binding_base_caps_v06(normalized_actor_id, "monster_binding_capability_binding_invalid")
	var validation_mode := "direct_authoritative_provider"
	if provider.has_method("validate_monster_binding_caps_v06"):
		var validation_variant: Variant = provider.call("validate_monster_binding_caps_v06", raw.duplicate(true), for_target_owner)
		if not (validation_variant is Dictionary) or not bool((validation_variant as Dictionary).get("valid", false)):
			return _monster_binding_base_caps_v06(normalized_actor_id, "monster_binding_capability_validator_rejected")
		validation_mode = "provider_validator"
	var result := {
		"available": true,
		"authoritative": true,
		"provider_valid": true,
		"fallback": false,
		"reason_code": "monster_binding_capability_ready",
		"actor_id": normalized_actor_id,
		"window_sequence": window_sequence,
		"window_revision": window_revision,
		"owner_revision": int(raw.get("owner_revision", -1)),
		"capability_kind": MONSTER_BINDING_CAPABILITY_KIND_V06,
		"controlled_monster_count_limit": count_limit,
		"primary_monster_rank_limit": primary_limit,
		"secondary_monster_rank_limit": secondary_limit,
		"activation_window_sequence": int(raw.get("activation_window_sequence", -1)),
		"expiry_window_sequence": int(raw.get("expiry_window_sequence", -1)),
		"validation_mode": validation_mode,
		"target_owner_query": for_target_owner,
	}
	result["binding_fingerprint"] = _monster_binding_caps_fingerprint_v06(result)
	return result


func _monster_binding_gradient_valid_v06(count_limit: int, primary_limit: int, secondary_limit: int) -> bool:
	return [
		[1, 2, 0],
		[1, 3, 0],
		[1, 4, 0],
		[2, 4, 2],
		[2, 4, 4],
	].has([count_limit, primary_limit, secondary_limit])


func _monster_binding_caps_fingerprint_v06(caps: Dictionary) -> String:
	return UNIT_CARD_SCHEMA_V06.fingerprint({
		"actor_id": str(caps.get("actor_id", "")),
		"window_sequence": int(caps.get("window_sequence", -1)),
		"window_revision": int(caps.get("window_revision", -1)),
		"owner_revision": int(caps.get("owner_revision", -1)),
		"capability_kind": str(caps.get("capability_kind", "")),
		"controlled_monster_count_limit": int(caps.get("controlled_monster_count_limit", MONSTER_BASE_COUNT_LIMIT_V06)),
		"primary_monster_rank_limit": int(caps.get("primary_monster_rank_limit", MONSTER_BASE_PRIMARY_RANK_CAP_V06)),
		"secondary_monster_rank_limit": int(caps.get("secondary_monster_rank_limit", MONSTER_BASE_SECONDARY_RANK_CAP_V06)),
		"provider_valid": bool(caps.get("provider_valid", false)),
		"target_owner_query": bool(caps.get("target_owner_query", false)),
	})


func _monster_binding_owned_slots_v06(actor_id: String, player_index: int) -> Array:
	var rows: Array = []
	for slot in range(auto_monsters.size()):
		if not (auto_monsters[slot] is Dictionary):
			continue
		var actor := auto_monsters[slot] as Dictionary
		if bool(actor.get("down", false)) or not _monster_card_actor_owned_by_v06(actor, actor_id, player_index):
			continue
		rows.append({"slot": slot, "uid": int(actor.get("uid", 0))})
	rows.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_row := left as Dictionary
		var right_row := right as Dictionary
		return int(left_row.get("uid", 0)) < int(right_row.get("uid", 0))
	)
	var result: Array = []
	for row_variant in rows:
		result.append(int((row_variant as Dictionary).get("slot", -1)))
	return result


func _monster_binding_slot_decision_v06(actor_id: String, player_index: int, unit_uid: int, caps: Dictionary, for_new_unit: bool = false) -> Dictionary:
	var owned_slots := _monster_binding_owned_slots_v06(actor_id, player_index)
	var ordinal := owned_slots.size() if for_new_unit else -1
	if not for_new_unit:
		for index in range(owned_slots.size()):
			var slot := int(owned_slots[index])
			if slot >= 0 and slot < auto_monsters.size() and int((auto_monsters[slot] as Dictionary).get("uid", 0)) == unit_uid:
				ordinal = index
				break
	var count_limit := int(caps.get("controlled_monster_count_limit", MONSTER_BASE_COUNT_LIMIT_V06))
	var slot_kind := "primary" if ordinal == 0 else ("secondary" if ordinal == 1 else "overflow")
	var rank_limit := int(caps.get("primary_monster_rank_limit", MONSTER_BASE_PRIMARY_RANK_CAP_V06)) if ordinal == 0 else int(caps.get("secondary_monster_rank_limit", MONSTER_BASE_SECONDARY_RANK_CAP_V06))
	var within_count := ordinal >= 0 and ordinal < count_limit
	return {
		"valid": ordinal >= 0,
		"ordinal": ordinal,
		"slot_kind": slot_kind,
		"rank_limit": rank_limit,
		"within_count": within_count,
		"suspended_for_new_upgrade": not within_count or rank_limit <= 0,
	}


func _monster_binding_status_v06(actor: Dictionary, owner_actor_id: String, owner_player_index: int, caps: Dictionary) -> Dictionary:
	var decision := _monster_binding_slot_decision_v06(owner_actor_id, owner_player_index, int(actor.get("uid", 0)), caps)
	var rank := int(actor.get("rank", 1))
	var suspended := not bool(decision.get("valid", false)) or bool(decision.get("suspended_for_new_upgrade", true)) or rank > int(decision.get("rank_limit", 0))
	return {
		"suspended_for_new_upgrade": suspended,
		"binding_slot": str(decision.get("slot_kind", "overflow")),
		"reason_code": "monster_binding_cap_suspended_for_new_upgrade" if suspended else "monster_binding_cap_active",
	}


func _monster_card_prepare_ordinary_summon_v06(intent: Dictionary, catalog: Dictionary, rule_snapshot: Dictionary, dependency_matrix: Dictionary) -> Dictionary:
	var target: Dictionary = intent.get("target_context", {}) if intent.get("target_context", {}) is Dictionary else {}
	if int(target.get("unit_uid", 0)) > 0:
		return _monster_card_failure_v06(intent, "monster_upgrade_target_missing", "所选同族怪兽已经不在场。", "选择合法召唤区域。")
	var actor_id := str(intent.get("actor_id", ""))
	var player_index := int(rule_snapshot.get("player_index", -1))
	var family_id := str(catalog.get("monster_family_id", ""))
	var card_rank := int(catalog.get("card_rank", 0))
	var binding_caps := _monster_binding_caps_v06(actor_id, false)
	var binding_slot := _monster_binding_slot_decision_v06(actor_id, player_index, 0, binding_caps, true)
	if not bool(binding_slot.get("within_count", false)):
		return _monster_card_failure_v06(intent, "monster_binding_count_limit_reached", "你已达到当前怪兽绑定数量上限。", "强化已有怪兽，或等待绑定能力恢复。")
	if card_rank > int(binding_slot.get("rank_limit", 0)):
		return _monster_card_failure_v06(intent, "monster_binding_slot_rank_cap_exceeded", "新的怪兽超过该绑定槽等级上限。", "使用更低等级怪兽牌，或提高绑定能力。")
	var region_id := str(target.get("region_id", ""))
	var region := _monster_card_region_snapshot_v06(region_id, family_id)
	if not bool(region.get("valid", false)):
		return _monster_card_failure_v06(intent, str(region.get("reason_code", "monster_deploy_region_invalid")), "所选区域当前不能召唤这只怪兽。", "选择一个未毁且符合牌面限制的区域。")
	if int(target.get("expected_region_revision", -1)) != int(region.get("revision", -2)):
		return _monster_card_failure_v06(intent, "monster_region_revision_stale", "召唤区域已经变化。", "刷新区域后重试。")
	var profile := _monster_card_profile_snapshot_v06(family_id, card_rank)
	if not bool(profile.get("valid", false)):
		return _monster_card_failure_v06(intent, str(profile.get("reason_code", "monster_profile_unavailable")), "怪兽单位档案无法确认。", "刷新牌面后重试。", profile)
	var summon_side_effect_profile := profile.duplicate(true)
	summon_side_effect_profile["role_cash_patch"] = {}
	var required_participants := _monster_card_required_participants_v06(summon_side_effect_profile)
	if not _monster_card_participants_ready_v06(dependency_matrix, required_participants):
		return _monster_card_failure_v06(intent, MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06, "怪兽召唤的关联效果尚未完成原子接线。", "请选择其他卡牌或稍后重试。")
	var preimage := _monster_card_core_state_envelope_v06()
	var next_state_result := _monster_card_build_deploy_postimage_v06(preimage, actor_id, player_index, catalog, profile, region, false)
	if not bool(next_state_result.get("valid", false)):
		return _monster_card_failure_v06(intent, str(next_state_result.get("reason_code", "monster_summon_postimage_invalid")), "怪兽召唤状态无法安全构造。", "刷新场景后重试。")
	var postimage: Dictionary = next_state_result.get("postimage", {}) if next_state_result.get("postimage", {}) is Dictionary else {}
	var transaction_id := str(intent.get("transaction_id", ""))
	var participant_binding := UNIT_CARD_SCHEMA_V06.fingerprint({
		"transaction_binding": UNIT_CARD_SCHEMA_V06.binding_from(intent),
		"owner_revision_before": _monster_card_revision_v06,
		"preimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(preimage),
		"postimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(postimage),
		"region_fingerprint": str(region.get("snapshot_fingerprint", "")),
		"profile_fingerprint": str(profile.get("snapshot_fingerprint", "")),
		"rule_fingerprint": str(rule_snapshot.get("snapshot_fingerprint", "")),
		"binding_capability_fingerprint": str(binding_caps.get("binding_fingerprint", "")),
	})
	var side_effect_plan := {
		"contract_version": MONSTER_CARD_CONTRACT_VERSION_V06,
		"transaction_id": transaction_id,
		"participant_binding_fingerprint": participant_binding,
		"operation": "summon",
		"actor_id": actor_id,
		"player_index": player_index,
		"unit_uid": int(next_state_result.get("unit_uid", 0)),
		"monster_family_id": family_id,
		"card_rank": card_rank,
		"region_id": region_id,
		"profile_snapshot": profile.duplicate(true),
		"required_participants": required_participants.duplicate(),
		"bound_skill_recipient_actor_id": actor_id,
		"bound_skill_patch": (profile.get("bound_skill_patch", {}) as Dictionary).duplicate(true) if profile.get("bound_skill_patch", {}) is Dictionary else {},
		"economic_patch": (profile.get("economic_patch", {}) as Dictionary).duplicate(true) if profile.get("economic_patch", {}) is Dictionary else {},
		"role_cash_patch": {},
	}
	var cross_owner_required := not required_participants.is_empty()
	var side_prepare := _monster_card_cross_owner_stage_v06("prepare", side_effect_plan) if cross_owner_required else _monster_card_local_stage_receipt_v06("prepare", transaction_id, participant_binding, "summon")
	if not bool(side_prepare.get("prepared", false)) or not _monster_card_cross_owner_receipt_matches_v06(side_prepare, transaction_id, participant_binding):
		return _monster_card_failure_v06(intent, str(side_prepare.get("reason_code", "monster_cross_owner_prepare_failed")), "怪兽召唤的关联效果无法安全预留。", "请稍后重试或选择其他卡牌。")
	var reservation := {
		"schema_version": MONSTER_CARD_LIFECYCLE_SCHEMA_V06,
		"stage": "prepared",
		"transaction_id": transaction_id,
		"intent_binding": UNIT_CARD_SCHEMA_V06.binding_from(intent),
		"intent": intent.duplicate(true),
		"owner_revision_before": _monster_card_revision_v06,
		"owner_revision_after": -1,
		"operation": "summon",
		"unit_uid": int(next_state_result.get("unit_uid", 0)),
		"actor_revision_before": 0,
		"actor_revision_after": 1,
		"rank_before": 0,
		"rank_after": card_rank,
		"preimage": preimage,
		"postimage": postimage,
		"preimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(preimage),
		"postimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(postimage),
		"region_id": region_id,
		"region_revision": int(region.get("revision", -1)),
		"region_fingerprint": str(region.get("snapshot_fingerprint", "")),
		"profile_family_id": family_id,
		"profile_rank": card_rank,
		"profile_fingerprint": str(profile.get("snapshot_fingerprint", "")),
		"rule_actor_id": actor_id,
		"rule_fingerprint": str(rule_snapshot.get("snapshot_fingerprint", "")),
		"binding_capability_actor_id": actor_id,
		"binding_capability_target_owner_query": false,
		"binding_capability_fingerprint": str(binding_caps.get("binding_fingerprint", "")),
		"binding_capability_window_sequence": int(binding_caps.get("window_sequence", -1)),
		"binding_capability_owner_revision": int(binding_caps.get("owner_revision", -1)),
		"binding_slot_kind": str(binding_slot.get("slot_kind", "secondary")),
		"participant_binding_fingerprint": participant_binding,
		"cross_owner_required": cross_owner_required,
		"required_participants": required_participants.duplicate(),
		"cross_owner_prepare_receipt": side_prepare.duplicate(true),
		"cross_owner_commit_receipt": {},
		"rollback_open": false,
		"presentation_event": _monster_card_summon_presentation_event_v06(next_state_result, region),
	}
	reservation["reservation_fingerprint"] = _monster_card_reservation_fingerprint_v06(reservation)
	var prepared_receipt := _monster_card_receipt_v06(intent, reservation, "prepared")
	reservation["latest_receipt"] = prepared_receipt.duplicate(true)
	_monster_card_reservations_v06[transaction_id] = reservation
	return prepared_receipt


func _monster_card_prepare_upgrade_v06(intent: Dictionary, catalog: Dictionary, acting_rule: Dictionary, dependency_matrix: Dictionary, actor_slot: int) -> Dictionary:
	if actor_slot < 0 or actor_slot >= auto_monsters.size() or not (auto_monsters[actor_slot] is Dictionary):
		return _monster_card_failure_v06(intent, "monster_upgrade_target_missing", "所选同族怪兽已经不在场。", "刷新怪兽后重试。")
	var actor := auto_monsters[actor_slot] as Dictionary
	var target: Dictionary = intent.get("target_context", {}) if intent.get("target_context", {}) is Dictionary else {}
	var target_uid := int(target.get("unit_uid", 0))
	if target_uid <= 0:
		return _monster_card_failure_v06(intent, "monster_upgrade_target_binding_required", "场上已有同族怪兽，必须指定它进行强化。", "选择该同族怪兽后重试。")
	if target_uid != int(actor.get("uid", 0)):
		return _monster_card_failure_v06(intent, "monster_upgrade_family_mismatch", "所选怪兽不是这张牌对应的同族怪兽。", "刷新目标后选择场上的同族怪兽。")
	var expected_actor_revision := int(target.get("expected_actor_revision", -1))
	var actor_revision_before := int(actor.get("actor_revision_v06", 0))
	if expected_actor_revision < 0 or expected_actor_revision != actor_revision_before:
		return _monster_card_failure_v06(intent, "monster_actor_revision_stale", "目标怪兽状态已经变化。", "刷新目标怪兽后重试。", {"actual_actor_revision": actor_revision_before})
	var family_id := str(catalog.get("monster_family_id", ""))
	if _monster_family_id_for_actor_v06(actor) != family_id:
		return _monster_card_failure_v06(intent, "monster_upgrade_family_mismatch", "所选怪兽与牌面族系不一致。", "刷新目标后重试。")
	var target_owner_actor_id := str(actor.get("owner_actor_id_v06", "")).strip_edges()
	if target_owner_actor_id.is_empty():
		return _monster_card_failure_v06(intent, "monster_upgrade_target_owner_unavailable", "目标怪兽的归属权限无法安全确认。", "刷新场景或完成旧存档迁移。")
	var target_owner_rule := acting_rule if target_owner_actor_id == str(intent.get("actor_id", "")) else _monster_card_rule_snapshot_v06(target_owner_actor_id)
	if not bool(target_owner_rule.get("valid", false)):
		return _monster_card_failure_v06(intent, "monster_target_owner_binding_rule_unavailable", "目标怪兽的强化权限无法确认。", "刷新场景后重试。")
	var target_owner_caps := _monster_binding_caps_v06(target_owner_actor_id, true)
	var target_binding_slot := _monster_binding_slot_decision_v06(target_owner_actor_id, int(target_owner_rule.get("player_index", -1)), target_uid, target_owner_caps)
	var current_rank := clampi(int(actor.get("rank", 1)), 1, 4)
	var card_rank := clampi(int(catalog.get("card_rank", 1)), 1, 4)
	var next_rank := clampi(maxi(current_rank + 1, card_rank), 1, 4)
	if not bool(target_binding_slot.get("valid", false)) or bool(target_binding_slot.get("suspended_for_new_upgrade", true)) or current_rank > int(target_binding_slot.get("rank_limit", 0)):
		return _monster_card_failure_v06(intent, "monster_binding_cap_suspended_for_new_upgrade", "这只怪兽当前被冻结，不能继续强化。", "等待其归属玩家恢复怪兽绑定能力。")
	var target_owner_rank_cap := int(target_binding_slot.get("rank_limit", MONSTER_BASE_PRIMARY_RANK_CAP_V06))
	if next_rank > target_owner_rank_cap:
		return _monster_card_failure_v06(
			intent,
			"monster_target_owner_rank_cap_exceeded",
			"这只怪兽当前不能强化到该等级。",
			"等待其归属玩家提高怪兽绑定权限，或选择其他卡牌。",
			{"current_rank": current_rank, "next_rank": next_rank, "binding_slot": str(target_binding_slot.get("slot_kind", "primary"))}
		)
	var payload: Dictionary = catalog.get("effect_payload", {}) if catalog.get("effect_payload", {}) is Dictionary else {}
	var duration_policy := str(payload.get("presence_time_policy", "add_to_remaining_time"))
	var extend_seconds := float(payload.get("same_name_upgrade_extend_seconds", MONSTER_UPGRADE_DEFAULT_EXTEND_SECONDS_V06))
	if duration_policy != "add_to_remaining_time" or extend_seconds <= 0.0 or bool(payload.get("refresh_total_presence_time", false)):
		return _monster_card_failure_v06(intent, "monster_upgrade_duration_policy_invalid", "怪兽强化的在场时间规则无法确认。", "刷新牌面后重试。")
	if bool(payload.get("ownership_transfer_on_upgrade", false)):
		return _monster_card_failure_v06(intent, "monster_upgrade_ownership_policy_invalid", "这张牌不能改变怪兽归属。", "刷新牌面后重试。")
	var profile := _monster_card_profile_snapshot_v06(family_id, next_rank)
	if not bool(profile.get("valid", false)):
		return _monster_card_failure_v06(intent, str(profile.get("reason_code", "monster_profile_unavailable")), "怪兽强化档案无法确认。", "刷新牌面后重试。", profile)
	var upgrade_side_effect_profile := profile.duplicate(true)
	# Cross-player reinforcement never re-routes role cash/discount effects to the
	# acting player. Only profile-owned skill/economic patches may participate.
	upgrade_side_effect_profile["role_cash_patch"] = {}
	var required_participants := _monster_card_required_participants_v06(upgrade_side_effect_profile)
	if not _monster_card_participants_ready_v06(dependency_matrix, required_participants):
		return _monster_card_failure_v06(intent, MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06, "怪兽强化的关联效果尚未完成原子接线。", "请选择其他卡牌或稍后重试。", {"required_participants": required_participants})
	var preimage := _monster_card_core_state_envelope_v06()
	var next_state_result := _monster_card_build_upgrade_postimage_v06(preimage, actor_slot, target_uid, actor_revision_before, catalog, profile, extend_seconds)
	if not bool(next_state_result.get("valid", false)):
		return _monster_card_failure_v06(intent, str(next_state_result.get("reason_code", "monster_upgrade_postimage_invalid")), "怪兽强化状态无法安全构造。", "刷新场景后重试。")
	var postimage: Dictionary = next_state_result.get("postimage", {}) if next_state_result.get("postimage", {}) is Dictionary else {}
	var transaction_id := str(intent.get("transaction_id", ""))
	var participant_binding := UNIT_CARD_SCHEMA_V06.fingerprint({
		"transaction_binding": UNIT_CARD_SCHEMA_V06.binding_from(intent),
		"owner_revision_before": _monster_card_revision_v06,
		"preimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(preimage),
		"postimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(postimage),
		"profile_fingerprint": str(profile.get("snapshot_fingerprint", "")),
		"acting_rule_fingerprint": str(acting_rule.get("snapshot_fingerprint", "")),
		"target_owner_rule_fingerprint": str(target_owner_rule.get("snapshot_fingerprint", "")),
		"binding_capability_fingerprint": str(target_owner_caps.get("binding_fingerprint", "")),
	})
	var side_effect_plan := {
		"contract_version": MONSTER_CARD_CONTRACT_VERSION_V06,
		"transaction_id": transaction_id,
		"participant_binding_fingerprint": participant_binding,
		"operation": "upgrade",
		"actor_id": str(intent.get("actor_id", "")),
		"unit_uid": target_uid,
		"monster_family_id": family_id,
		"rank_before": current_rank,
		"rank_after": next_rank,
		"profile_snapshot": profile.duplicate(true),
		"required_participants": required_participants.duplicate(),
		"bound_skill_recipient_actor_id": target_owner_actor_id,
		"bound_skill_patch": (profile.get("bound_skill_patch", {}) as Dictionary).duplicate(true) if profile.get("bound_skill_patch", {}) is Dictionary else {},
		"economic_patch": (profile.get("economic_patch", {}) as Dictionary).duplicate(true) if profile.get("economic_patch", {}) is Dictionary else {},
		"role_cash_patch": {},
	}
	var cross_owner_required := not required_participants.is_empty()
	var side_prepare := _monster_card_cross_owner_stage_v06("prepare", side_effect_plan) if cross_owner_required else _monster_card_local_stage_receipt_v06("prepare", transaction_id, participant_binding, "upgrade")
	if not bool(side_prepare.get("prepared", false)):
		return _monster_card_failure_v06(intent, str(side_prepare.get("reason_code", MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06)), "怪兽强化的关联效果无法安全预留。", "请稍后重试或选择其他卡牌。")
	if not _monster_card_cross_owner_receipt_matches_v06(side_prepare, transaction_id, participant_binding):
		return _monster_card_failure_v06(intent, "monster_cross_owner_prepare_binding_mismatch", "怪兽强化关联效果状态已经变化。", "刷新场景后重试。")
	var reservation := {
		"schema_version": MONSTER_CARD_LIFECYCLE_SCHEMA_V06,
		"stage": "prepared",
		"transaction_id": transaction_id,
		"intent_binding": UNIT_CARD_SCHEMA_V06.binding_from(intent),
		"intent": intent.duplicate(true),
		"owner_revision_before": _monster_card_revision_v06,
		"owner_revision_after": -1,
		"operation": "upgrade",
		"unit_uid": target_uid,
		"actor_revision_before": actor_revision_before,
		"actor_revision_after": actor_revision_before + 1,
		"rank_before": current_rank,
		"rank_after": next_rank,
		"upgrade_extend_seconds": extend_seconds,
		"preimage": preimage,
		"postimage": postimage,
		"preimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(preimage),
		"postimage_fingerprint": _monster_card_core_state_fingerprint_from_envelope_v06(postimage),
		"region_id": "",
		"region_revision": -1,
		"region_fingerprint": "",
		"profile_family_id": family_id,
		"profile_rank": next_rank,
		"profile_fingerprint": str(profile.get("snapshot_fingerprint", "")),
		"rule_actor_id": str(intent.get("actor_id", "")),
		"rule_fingerprint": str(acting_rule.get("snapshot_fingerprint", "")),
		"target_owner_rule_actor_id": target_owner_actor_id,
		"target_owner_rule_fingerprint": str(target_owner_rule.get("snapshot_fingerprint", "")),
		"binding_capability_actor_id": target_owner_actor_id,
		"binding_capability_target_owner_query": true,
		"binding_capability_fingerprint": str(target_owner_caps.get("binding_fingerprint", "")),
		"binding_capability_window_sequence": int(target_owner_caps.get("window_sequence", -1)),
		"binding_capability_owner_revision": int(target_owner_caps.get("owner_revision", -1)),
		"binding_slot_kind": str(target_binding_slot.get("slot_kind", "primary")),
		"participant_binding_fingerprint": participant_binding,
		"cross_owner_required": cross_owner_required,
		"required_participants": required_participants.duplicate(),
		"cross_owner_prepare_receipt": side_prepare.duplicate(true),
		"cross_owner_commit_receipt": {},
		"rollback_open": false,
		"presentation_event": _monster_card_upgrade_presentation_event_v06(next_state_result),
	}
	reservation["reservation_fingerprint"] = _monster_card_reservation_fingerprint_v06(reservation)
	var prepared_receipt := _monster_card_receipt_v06(intent, reservation, "prepared")
	reservation["latest_receipt"] = prepared_receipt.duplicate(true)
	_monster_card_reservations_v06[transaction_id] = reservation
	return prepared_receipt


func _monster_starter_state_for_actor_v06(actor_id: String, player_index: int) -> String:
	if _monster_starter_state_v06.has(actor_id):
		var row_variant: Variant = _monster_starter_state_v06.get(actor_id)
		if row_variant is Dictionary:
			var state := str((row_variant as Dictionary).get("state", "legacy_unknown"))
			return state if ["not_summoned", "summoned", "legacy_unknown"].has(state) else "legacy_unknown"
	for actor_variant in auto_monsters:
		if actor_variant is Dictionary and _monster_card_actor_owned_by_v06(actor_variant as Dictionary, actor_id, player_index):
			return "legacy_unknown"
	return "not_summoned"


func _monster_card_owned_family_slots_v06(actor_id: String, player_index: int, family_id: String) -> Array:
	var result: Array = []
	for slot in range(auto_monsters.size()):
		if not (auto_monsters[slot] is Dictionary):
			continue
		var actor := auto_monsters[slot] as Dictionary
		if bool(actor.get("down", false)) or not _monster_card_actor_owned_by_v06(actor, actor_id, player_index):
			continue
		if _monster_family_id_for_actor_v06(actor) == family_id:
			result.append(slot)
	return result


func _monster_card_actor_owned_by_v06(actor: Dictionary, actor_id: String, player_index: int) -> bool:
	var bound_actor_id := str(actor.get("owner_actor_id_v06", ""))
	return bound_actor_id == actor_id if not bound_actor_id.is_empty() else int(actor.get("owner", -1)) == player_index


func _monster_family_id_for_actor_v06(actor: Dictionary) -> String:
	var explicit := str(actor.get("monster_family_id", ""))
	if not explicit.is_empty():
		return explicit
	return str(MONSTER_FAMILY_BY_NAME_V06.get(str(actor.get("name", "")), ""))


func _monster_public_actor_v06(source: Dictionary) -> Dictionary:
	var actor := source.duplicate(true)
	var forbidden_fragments := ["owner", "lure", "private", "bound", "cash", "hand", "discard", "ai_", "target_plan", "formal_card_id", "profile_revision"]
	for key_variant in actor.keys():
		var key := str(key_variant)
		if key == "owner_revealed":
			continue
		var lowered := key.to_lower()
		for fragment in forbidden_fragments:
			if lowered.contains(fragment):
				actor.erase(key_variant)
				break
	return actor


func _monster_card_core_state_envelope_v06() -> Dictionary:
	return {
		"auto_monsters": auto_monsters.duplicate(true),
		"next_auto_monster_uid": next_auto_monster_uid,
		"next_special_monster_slot": next_special_monster_slot,
		"selected_auto_monster_slot": selected_auto_monster_slot,
		"starter_state": _monster_starter_state_v06.duplicate(true),
	}


func _monster_card_core_state_fingerprint_v06() -> String:
	return _monster_card_core_state_fingerprint_from_envelope_v06(_monster_card_core_state_envelope_v06())


func _monster_card_core_state_fingerprint_from_envelope_v06(envelope: Dictionary) -> String:
	return UNIT_CARD_SCHEMA_V06.fingerprint({
		"auto_monsters": (envelope.get("auto_monsters", []) as Array).duplicate(true) if envelope.get("auto_monsters", []) is Array else [],
		"next_auto_monster_uid": int(envelope.get("next_auto_monster_uid", 1)),
		"next_special_monster_slot": int(envelope.get("next_special_monster_slot", 0)),
		"selected_auto_monster_slot": int(envelope.get("selected_auto_monster_slot", 0)),
		"starter_state": (envelope.get("starter_state", {}) as Dictionary).duplicate(true) if envelope.get("starter_state", {}) is Dictionary else {},
	})


func _monster_card_build_deploy_postimage_v06(preimage: Dictionary, actor_id: String, player_index: int, catalog: Dictionary, profile: Dictionary, region: Dictionary, mark_starter: bool = true) -> Dictionary:
	var roster: Array = (preimage.get("auto_monsters", []) as Array).duplicate(true)
	var uid := int(preimage.get("next_auto_monster_uid", 1))
	if uid <= 0:
		return {"valid": false, "reason_code": "monster_uid_allocator_invalid"}
	var slot := roster.size()
	var region_index := int(region.get("region_index", -1))
	var hp := int(profile.get("hp", 0))
	var duration_seconds := float(profile.get("initial_duration_seconds", 0.0))
	var spawn_rank := int(profile.get("rank", catalog.get("card_rank", 0)))
	var owner_damage_cash_total := maxi(0, int(profile.get("owner_damage_cash_total", MONSTER_OWNER_DAMAGE_CASH_POOL)))
	if spawn_rank < 1 or spawn_rank > 4:
		return {"valid": false, "reason_code": "monster_deploy_rank_invalid"}
	var world_position := _monster_card_world_position_v06(region.get("world_position", region.get("center", {})))
	var actor := {
		"uid": uid,
		"catalog_index": int(profile.get("catalog_index", -1)),
		"slot": slot,
		"rank": spawn_rank,
		"name": str(profile.get("name", catalog.get("player_name", "怪兽"))),
		"monster_family_id": str(catalog.get("monster_family_id", "")),
		"formal_card_id_v06": str(catalog.get("card_id", "")),
		"actor_revision_v06": 1,
		"owner_actor_id_v06": actor_id,
		"profile_revision_v06": int(profile.get("revision", 0)),
		"hp": hp,
		"max_hp": hp,
		"duration": duration_seconds,
		"remaining_time": duration_seconds,
		"move": float(profile.get("move_mps", 0.0)),
		"move_damage": int(profile.get("move_damage", AUTO_MONSTER_DEFAULT_MOVE_DAMAGE)),
		"collision_damage": int(profile.get("collision_damage", AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE)),
		"movement_traits": (profile.get("movement_traits", []) as Array).duplicate(true) if profile.get("movement_traits", []) is Array else [],
		"terrain_move_multiplier": (profile.get("terrain_move_multiplier", {}) as Dictionary).duplicate(true) if profile.get("terrain_move_multiplier", {}) is Dictionary else {},
		"resource_drain": int(profile.get("resource_drain", 1)),
		"resource_focus": (profile.get("resource_focus", []) as Array).duplicate(true) if profile.get("resource_focus", []) is Array else [],
		"position": region_index,
		"world_position": world_position,
		"armor": int(profile.get("armor", 0)),
		"guard": 0,
		"ranged_guard": 0,
		"tether": 0,
		"down": false,
		"owner": player_index,
		"owner_revealed": false,
		"owner_clue": "",
		"owner_damage_cash_pool": owner_damage_cash_total,
		"owner_damage_cash_total": owner_damage_cash_total,
		"owner_damage_cash_lost": 0,
		"last_owner_damage_cash_loss": 0,
		"last_owner_damage_amount": 0,
		"last_owner_damage_source": "",
		"last_owner_damage_time": -1.0,
		"revive_available": bool(profile.get("revive_available", false)),
		"revive_timer": 0.0,
		"bracelet_active": false,
		"ember_ring_energy_announced": false,
		"blue_lancer_reactive_armor_active": false,
	}
	roster.append(actor)
	var starter_state: Dictionary = (preimage.get("starter_state", {}) as Dictionary).duplicate(true) if preimage.get("starter_state", {}) is Dictionary else {}
	if mark_starter:
		starter_state[actor_id] = {
			"state": "summoned",
			"unit_uid": uid,
			"transaction_id": "",
			"revision": int(starter_state.get(actor_id, {}).get("revision", 0)) + 1 if starter_state.get(actor_id, {}) is Dictionary else 1,
		}
	return {
		"valid": true,
		"unit_uid": uid,
		"actor": actor.duplicate(true),
		"postimage": {
			"auto_monsters": roster,
			"next_auto_monster_uid": uid + 1,
			"next_special_monster_slot": slot,
			"selected_auto_monster_slot": slot,
			"starter_state": starter_state,
		},
	}


func _monster_card_build_upgrade_postimage_v06(preimage: Dictionary, actor_slot: int, unit_uid: int, expected_actor_revision: int, catalog: Dictionary, profile: Dictionary, extend_seconds: float) -> Dictionary:
	var roster: Array = (preimage.get("auto_monsters", []) as Array).duplicate(true) if preimage.get("auto_monsters", []) is Array else []
	if actor_slot < 0 or actor_slot >= roster.size() or not (roster[actor_slot] is Dictionary):
		return {"valid": false, "reason_code": "monster_upgrade_target_missing"}
	var actor := (roster[actor_slot] as Dictionary).duplicate(true)
	if int(actor.get("uid", 0)) != unit_uid or bool(actor.get("down", false)):
		return {"valid": false, "reason_code": "monster_upgrade_target_changed"}
	if int(actor.get("actor_revision_v06", 0)) != expected_actor_revision:
		return {"valid": false, "reason_code": "monster_actor_revision_stale"}
	if _monster_family_id_for_actor_v06(actor) != str(catalog.get("monster_family_id", "")):
		return {"valid": false, "reason_code": "monster_upgrade_family_mismatch"}
	var rank_before := clampi(int(actor.get("rank", 1)), 1, 4)
	var rank_after := int(profile.get("rank", 0))
	var hp_after := int(profile.get("hp", 0))
	if rank_after < 1 or rank_after > 4 or hp_after <= 0 or extend_seconds <= 0.0:
		return {"valid": false, "reason_code": "monster_upgrade_profile_invalid"}
	actor["rank"] = rank_after
	actor["hp"] = hp_after
	actor["max_hp"] = hp_after
	actor["duration"] = maxf(0.0, float(actor.get("duration", actor.get("remaining_time", 0.0)))) + extend_seconds
	actor["remaining_time"] = maxf(0.0, float(actor.get("remaining_time", 0.0))) + extend_seconds
	actor["move"] = maxf(0.0, float(profile.get("move_mps", actor.get("move", 0.0))))
	actor["move_damage"] = int(profile.get("move_damage", actor.get("move_damage", AUTO_MONSTER_DEFAULT_MOVE_DAMAGE)))
	actor["collision_damage"] = int(profile.get("collision_damage", actor.get("collision_damage", AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE)))
	actor["movement_traits"] = (profile.get("movement_traits", actor.get("movement_traits", [])) as Array).duplicate(true) if profile.get("movement_traits", actor.get("movement_traits", [])) is Array else []
	actor["terrain_move_multiplier"] = (profile.get("terrain_move_multiplier", actor.get("terrain_move_multiplier", {})) as Dictionary).duplicate(true) if profile.get("terrain_move_multiplier", actor.get("terrain_move_multiplier", {})) is Dictionary else {}
	actor["resource_drain"] = int(profile.get("resource_drain", actor.get("resource_drain", 1)))
	actor["resource_focus"] = (profile.get("resource_focus", actor.get("resource_focus", [])) as Array).duplicate(true) if profile.get("resource_focus", actor.get("resource_focus", [])) is Array else []
	actor["armor"] = int(profile.get("armor", actor.get("armor", 0)))
	actor["revive_available"] = bool(profile.get("revive_available", actor.get("revive_available", false)))
	actor["profile_revision_v06"] = int(profile.get("revision", actor.get("profile_revision_v06", 0)))
	actor["actor_revision_v06"] = expected_actor_revision + 1
	actor["slot"] = actor_slot
	roster[actor_slot] = actor
	return {
		"valid": true,
		"unit_uid": unit_uid,
		"rank_before": rank_before,
		"rank_after": rank_after,
		"actor": actor.duplicate(true),
		"postimage": {
			"auto_monsters": roster,
			"next_auto_monster_uid": int(preimage.get("next_auto_monster_uid", 1)),
			"next_special_monster_slot": int(preimage.get("next_special_monster_slot", 0)),
			"selected_auto_monster_slot": int(preimage.get("selected_auto_monster_slot", 0)),
			"starter_state": (preimage.get("starter_state", {}) as Dictionary).duplicate(true) if preimage.get("starter_state", {}) is Dictionary else {},
		},
	}


func _monster_card_world_position_v06(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", 0.0)), float((value as Dictionary).get("y", 0.0)))
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO


func _monster_card_swap_core_state_v06(envelope: Dictionary) -> void:
	auto_monsters = (envelope.get("auto_monsters", []) as Array).duplicate(true)
	next_auto_monster_uid = int(envelope.get("next_auto_monster_uid", 1))
	next_special_monster_slot = int(envelope.get("next_special_monster_slot", 0))
	selected_auto_monster_slot = int(envelope.get("selected_auto_monster_slot", 0))
	_monster_starter_state_v06 = (envelope.get("starter_state", {}) as Dictionary).duplicate(true) if envelope.get("starter_state", {}) is Dictionary else {}
	_monster_card_lifecycle_call_counts_v06["roster_swaps"] = int(_monster_card_lifecycle_call_counts_v06.get("roster_swaps", 0)) + 1


func _monster_card_reservation_fingerprint_v06(reservation: Dictionary) -> String:
	return UNIT_CARD_SCHEMA_V06.fingerprint({
		"schema_version": str(reservation.get("schema_version", "")),
		"transaction_id": str(reservation.get("transaction_id", "")),
		"intent_binding": reservation.get("intent_binding", {}),
		"owner_revision_before": int(reservation.get("owner_revision_before", -1)),
		"operation": str(reservation.get("operation", "")),
		"unit_uid": int(reservation.get("unit_uid", 0)),
		"actor_revision_before": int(reservation.get("actor_revision_before", 0)),
		"actor_revision_after": int(reservation.get("actor_revision_after", 0)),
		"rank_before": int(reservation.get("rank_before", 0)),
		"rank_after": int(reservation.get("rank_after", 0)),
		"upgrade_extend_seconds": float(reservation.get("upgrade_extend_seconds", 0.0)),
		"preimage_fingerprint": str(reservation.get("preimage_fingerprint", "")),
		"postimage_fingerprint": str(reservation.get("postimage_fingerprint", "")),
		"region_fingerprint": str(reservation.get("region_fingerprint", "")),
		"profile_fingerprint": str(reservation.get("profile_fingerprint", "")),
		"rule_fingerprint": str(reservation.get("rule_fingerprint", "")),
		"target_owner_rule_fingerprint": str(reservation.get("target_owner_rule_fingerprint", "")),
		"binding_capability_actor_id": str(reservation.get("binding_capability_actor_id", "")),
		"binding_capability_target_owner_query": bool(reservation.get("binding_capability_target_owner_query", false)),
		"binding_capability_fingerprint": str(reservation.get("binding_capability_fingerprint", "")),
		"binding_capability_window_sequence": int(reservation.get("binding_capability_window_sequence", -1)),
		"binding_capability_owner_revision": int(reservation.get("binding_capability_owner_revision", -1)),
		"binding_slot_kind": str(reservation.get("binding_slot_kind", "")),
		"participant_binding_fingerprint": str(reservation.get("participant_binding_fingerprint", "")),
		"cross_owner_required": bool(reservation.get("cross_owner_required", false)),
		"required_participants": (reservation.get("required_participants", []) as Array).duplicate() if reservation.get("required_participants", []) is Array else [],
	})


func _monster_card_receipt_v06(intent: Dictionary, reservation: Dictionary, stage: String) -> Dictionary:
	var receipt: Dictionary = UNIT_CARD_SCHEMA_V06.binding_from(intent)
	var operation := str(reservation.get("operation", "deploy"))
	var is_upgrade := operation == "upgrade"
	var is_summon := operation == "summon"
	var rank_after := int(reservation.get("rank_after", 1))
	var stage_feedback := {
		"reason": "怪兽强化已预留。" if is_upgrade else ("怪兽召唤已预留。" if is_summon else "起始怪兽部署已预留。"),
		"next_step": "确认强化。" if is_upgrade else "确认部署。",
	}
	if stage in ["committed", "finalized"]:
		stage_feedback = {
			"reason": "同族怪兽已强化，归属保持不变。" if is_upgrade else ("怪兽已完成召唤。" if is_summon else "起始怪兽已部署。"),
			"next_step": "继续行动。" if is_upgrade or is_summon else "选择区域并继续建设。",
		}
	elif stage == "rolled_back":
		stage_feedback = {
			"reason": "怪兽强化已撤销。" if is_upgrade else "怪兽召唤已撤销。",
			"next_step": "重新选择卡牌与目标。" if is_upgrade or is_summon else "重新选择起始怪兽与区域。",
		}
	var resolved_action_kind := "upgrade_existing_same_family_monster" if is_upgrade else ("summon_monster" if is_summon else "deploy_monster_rank1_starter_first")
	var outcome := "monster_upgrade" if is_upgrade else ("monster_summon" if is_summon else "monster_starter_deploy")
	receipt.merge({
		"prepared": ["prepared", "committed", "finalized"].has(stage),
		"committed": ["committed", "finalized"].has(stage),
		"rolled_back": stage == "rolled_back",
		"finalized": stage == "finalized",
		"reason_code": "monster_%s" % stage,
		"stage": stage,
		"operation": operation,
		"resolved_action_kind": resolved_action_kind,
		"unit_uid": int(reservation.get("unit_uid", 0)),
		"actor_revision": int(reservation.get("actor_revision_after", 1)),
		"rank_before": int(reservation.get("rank_before", 0)),
		"rank_after": rank_after,
		"owner_revision_before": int(reservation.get("owner_revision_before", -1)),
		"owner_revision_after": int(reservation.get("owner_revision_after", -1)),
		"reservation_fingerprint": str(reservation.get("reservation_fingerprint", "")),
		"rollback_open": bool(reservation.get("rollback_open", false)) and stage == "committed",
		"outcome": outcome,
		"unit_public_id": "monster-%d" % int(reservation.get("unit_uid", 0)),
		"unit_rank": rank_after,
		"public_changes": {"rank": rank_after, "full_health": is_upgrade, "remaining_time_extended": is_upgrade},
		"player_feedback": stage_feedback,
	}, true)
	return receipt


func _monster_card_authoritative_association_v06(source: Dictionary, allowed_stages: Array) -> Dictionary:
	var transaction_id := str(source.get("transaction_id", ""))
	if _monster_card_terminal_journal_v06.has(transaction_id):
		var terminal: Dictionary = _monster_card_terminal_journal_v06.get(transaction_id, {})
		if not _monster_card_binding_matches_v06(terminal.get("intent_binding", {}) as Dictionary, source):
			return {"valid": false, "receipt": _monster_card_failure_v06(source, "monster_transaction_binding_conflict", "结算绑定不一致。", "刷新场景后重试。")}
		var replay: Dictionary = (terminal.get("receipt", {}) as Dictionary).duplicate(true)
		replay["idempotent_replay"] = true
		return {"valid": true, "terminal_replay": true, "receipt": replay}
	if not _monster_card_reservations_v06.has(transaction_id):
		return {"valid": false, "receipt": _monster_card_failure_v06(source, "monster_transaction_reservation_missing", "怪兽部署预留已经失效。", "重新打出起始怪兽牌。")}
	var reservation: Dictionary = _monster_card_reservations_v06.get(transaction_id, {})
	if not _monster_card_binding_matches_v06(reservation.get("intent_binding", {}) as Dictionary, source) or str(source.get("reservation_fingerprint", "")) != str(reservation.get("reservation_fingerprint", "")):
		return {"valid": false, "receipt": _monster_card_failure_v06(source, "monster_transaction_receipt_tampered", "怪兽部署凭据已经失效。", "刷新场景后重试。")}
	var stage := str(reservation.get("stage", ""))
	if stage == "committed" and allowed_stages.has("committed"):
		var committed_replay: Dictionary = (reservation.get("latest_receipt", {}) as Dictionary).duplicate(true)
		committed_replay["idempotent_replay"] = true
		return {"valid": true, "committed_replay": true, "receipt": committed_replay}
	if not allowed_stages.has(stage):
		return {"valid": false, "receipt": _monster_card_failure_v06(source, "monster_transaction_stage_invalid", "怪兽部署结算阶段不一致。", "刷新场景后重试。", {"actual_stage": stage})}
	return {"valid": true}


func _monster_card_binding_matches_v06(binding: Dictionary, source: Dictionary) -> bool:
	for key in UNIT_CARD_SCHEMA_V06.BINDING_KEYS:
		if str(binding.get(key, "")) != str(source.get(key, "")):
			return false
	return int(binding.get("expected_owner_revision", -1)) == int(source.get("expected_owner_revision", -1))


func _monster_card_revalidate_deploy_facts_v06(reservation: Dictionary) -> Dictionary:
	var rule := _monster_card_rule_snapshot_v06(str(reservation.get("rule_actor_id", "")))
	if not bool(rule.get("valid", false)) or str(rule.get("snapshot_fingerprint", "")) != str(reservation.get("rule_fingerprint", "")):
		return {"valid": false, "reason_code": "monster_binding_rule_changed"}
	if str(reservation.get("operation", "deploy")) == "upgrade":
		var target_owner_rule := _monster_card_rule_snapshot_v06(str(reservation.get("target_owner_rule_actor_id", "")))
		if not bool(target_owner_rule.get("valid", false)) or str(target_owner_rule.get("snapshot_fingerprint", "")) != str(reservation.get("target_owner_rule_fingerprint", "")):
			return {"valid": false, "reason_code": "monster_target_owner_binding_rule_changed"}
	else:
		var region := _monster_card_region_snapshot_v06(str(reservation.get("region_id", "")), str(reservation.get("profile_family_id", "")))
		if not bool(region.get("valid", false)) or str(region.get("snapshot_fingerprint", "")) != str(reservation.get("region_fingerprint", "")):
			return {"valid": false, "reason_code": "monster_region_binding_changed"}
	if not str(reservation.get("binding_capability_fingerprint", "")).is_empty():
		var current_caps := _monster_binding_caps_v06(
			str(reservation.get("binding_capability_actor_id", "")),
			bool(reservation.get("binding_capability_target_owner_query", false))
		)
		if str(current_caps.get("binding_fingerprint", "")) != str(reservation.get("binding_capability_fingerprint", "")):
			return {"valid": false, "reason_code": "monster_binding_capability_changed"}
	var profile := _monster_card_profile_snapshot_v06(str(reservation.get("profile_family_id", "")), int(reservation.get("profile_rank", 0)))
	if not bool(profile.get("valid", false)) or str(profile.get("snapshot_fingerprint", "")) != str(reservation.get("profile_fingerprint", "")):
		return {"valid": false, "reason_code": "monster_profile_binding_changed"}
	return {"valid": true}


func _monster_card_cross_owner_stage_v06(stage: String, request: Dictionary) -> Dictionary:
	var success_key: String = str({"prepare": "prepared", "commit": "committed", "rollback": "rolled_back", "finalize": "finalized"}.get(stage, "stage_succeeded"))
	if _world_bridge == null:
		return {"reason_code": MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06, success_key: false}
	var method_name := "%s_monster_deploy_side_effects_v06" % stage
	if not _world_bridge.has_method(method_name):
		return {"reason_code": MONSTER_CROSS_OWNER_UNAVAILABLE_REASON_V06, success_key: false}
	var value_variant: Variant = _world_bridge.call(method_name, request.duplicate(true))
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"reason_code": "monster_cross_owner_%s_receipt_invalid" % stage, success_key: false}


func _monster_card_cross_owner_receipt_matches_v06(receipt: Dictionary, transaction_id: String, participant_binding: String) -> bool:
	return str(receipt.get("transaction_id", "")) == transaction_id and str(receipt.get("participant_binding_fingerprint", "")) == participant_binding


func _monster_card_required_participants_v06(profile: Dictionary) -> Array:
	var required: Array = []
	if profile.get("bound_skill_patch", {}) is Dictionary and not (profile.get("bound_skill_patch", {}) as Dictionary).is_empty():
		required.append("bound_skill_inventory")
	if profile.get("economic_patch", {}) is Dictionary and not (profile.get("economic_patch", {}) as Dictionary).is_empty():
		required.append("product_market_rng")
	if profile.get("role_cash_patch", {}) is Dictionary and not (profile.get("role_cash_patch", {}) as Dictionary).is_empty():
		required.append("role_cash_ledger")
	return required


func _monster_card_participants_ready_v06(matrix: Dictionary, required: Array) -> bool:
	for participant_variant in required:
		var participant_name := str(participant_variant)
		var participant: Dictionary = matrix.get(participant_name, {}) if matrix.get(participant_name, {}) is Dictionary else {}
		for capability_name in ["prepare", "commit", "rollback", "finalize", "exact_once", "checkpoint", "save_load"]:
			if not bool(participant.get(capability_name, false)):
				return false
	return true


func _monster_card_local_stage_receipt_v06(stage: String, transaction_id: String, participant_binding: String, operation: String) -> Dictionary:
	var success_key: String = str({"prepare": "prepared", "commit": "committed", "rollback": "rolled_back", "finalize": "finalized"}.get(stage, "stage_succeeded"))
	return {
		"transaction_id": transaction_id,
		"participant_binding_fingerprint": participant_binding,
		success_key: true,
		"reason_code": "monster_%s_roster_%s" % [operation, stage],
		"operation": operation,
	}


func _monster_card_upgrade_presentation_event_v06(result: Dictionary) -> Dictionary:
	var actor: Dictionary = result.get("actor", {}) if result.get("actor", {}) is Dictionary else {}
	return {
		"event_id": "monster.same_family_upgrade.%d.%d" % [int(result.get("unit_uid", 0)), int(result.get("rank_after", 0))],
		"event_kind": "monster_same_family_upgrade",
		"unit_uid": int(result.get("unit_uid", 0)),
		"monster_family_id": str(actor.get("monster_family_id", "")),
		"rank_before": int(result.get("rank_before", 0)),
		"rank_after": int(result.get("rank_after", 0)),
		"public_text": "%s已被匿名同族怪兽牌强化至 Rank %d，归属保持不变。" % [str(actor.get("name", "怪兽")), int(result.get("rank_after", 0))],
	}


func _monster_card_summon_presentation_event_v06(result: Dictionary, region: Dictionary) -> Dictionary:
	var actor: Dictionary = result.get("actor", {}) if result.get("actor", {}) is Dictionary else {}
	return {
		"event_id": "monster.summon.%d" % int(result.get("unit_uid", 0)),
		"event_kind": "monster_summon",
		"unit_uid": int(result.get("unit_uid", 0)),
		"monster_family_id": str(actor.get("monster_family_id", "")),
		"rank": int(actor.get("rank", 1)),
		"region_id": str(region.get("region_id", "")),
		"public_text": "%s已在%s附近现身。" % [str(actor.get("name", "怪兽")), str(region.get("display_name", "目标区域"))],
	}


func _monster_card_deploy_presentation_event_v06(result: Dictionary, region: Dictionary) -> Dictionary:
	var actor: Dictionary = result.get("actor", {}) if result.get("actor", {}) is Dictionary else {}
	return {
		"event_id": "monster.starter_first_summon.%d" % int(result.get("unit_uid", 0)),
		"event_kind": "monster_starter_first_summon",
		"unit_uid": int(result.get("unit_uid", 0)),
		"monster_family_id": str(actor.get("monster_family_id", "")),
		"rank": 1,
		"region_id": str(region.get("region_id", "")),
		"public_text": "%s已在%s附近现身。" % [str(actor.get("name", "怪兽")), str(region.get("display_name", "目标区域"))],
	}


func _world_value(property_name: StringName, default_value: Variant = null) -> Variant:
	return _world_bridge.read_world_value(property_name, default_value) if _world_bridge != null else default_value


func _write_world_value(property_name: StringName, value: Variant) -> bool:
	return _world_bridge != null and _world_bridge.write_world_value(property_name, value)


func _world_call(method_name: StringName, arguments: Array = []) -> Variant:
	return _world_bridge.call_world(method_name, arguments) if _world_bridge != null else null

func _make_auto_monster(slot: int, catalog_index: int, start_district: int, owner_index: int = -1, rank: int = 1) -> Dictionary:
	var template: Dictionary = _catalog_entry(catalog_index)
	rank = clampi(rank, 1, 4)
	var hp := int(round(float(template.get("hp", 40)) * (1.0 + float(rank - 1) * 0.22)))
	var move_speed := _catalog_move_speed(catalog_index) * (1.0 + float(rank - 1) * 0.10)
	var start_index: int = max(0, min(start_district, districts.size() - 1))
	var uid := next_auto_monster_uid
	next_auto_monster_uid += 1
	return {
		"uid": uid,
		"catalog_index": catalog_index,
		"slot": slot,
		"rank": rank,
		"name": String(template.get("name", "怪兽")),
		"hp": hp,
		"max_hp": hp,
		"duration": float(template.get("duration", MONSTER_CARD_DURATION_BASE_SECONDS + float(rank - 1) * MONSTER_CARD_DURATION_RANK_STEP_SECONDS)),
		"remaining_time": float(template.get("duration", MONSTER_CARD_DURATION_BASE_SECONDS + float(rank - 1) * MONSTER_CARD_DURATION_RANK_STEP_SECONDS)),
		"move": move_speed,
		"move_damage": int(template.get("move_damage", AUTO_MONSTER_DEFAULT_MOVE_DAMAGE)),
		"collision_damage": int(template.get("collision_damage", AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE)),
		"movement_traits": (template.get("movement_traits", []) as Array).duplicate(true),
		"terrain_move_multiplier": (template.get("terrain_move_multiplier", {}) as Dictionary).duplicate(true),
		"resource_drain": int(template.get("resource_drain", 1)),
		"resource_focus": (template.get("resource_focus", []) as Array).duplicate(),
		"position": start_index,
		"world_position": _district_center(start_index),
		"armor": int(template.get("armor", 0)),
		"guard": 0,
		"ranged_guard": 0,
		"tether": 0,
		"down": false,
		"owner": owner_index,
		"owner_revealed": false,
		"owner_clue": "",
		"owner_damage_cash_pool": _owner_damage_cash_total_for_rank(rank),
		"owner_damage_cash_total": _owner_damage_cash_total_for_rank(rank),
		"owner_damage_cash_lost": 0,
		"last_owner_damage_cash_loss": 0,
		"last_owner_damage_amount": 0,
		"last_owner_damage_source": "",
		"last_owner_damage_time": -1.0,
		"revive_available": String(template.get("name", "")) == "流星哨兵",
		"revive_timer": 0.0,
		"bracelet_active": false,
		"ember_ring_energy_announced": false,
		"blue_lancer_reactive_armor_active": false,
	}

func _selected_auto_monster_actor() -> Dictionary:
	if auto_monsters.is_empty():
		return {}
	selected_auto_monster_slot = _valid_auto_monster_slot(selected_auto_monster_slot)
	return auto_monsters[selected_auto_monster_slot] as Dictionary

func _active_auto_monster_count() -> int:
	var count := 0
	for actor_variant in auto_monsters:
		var actor := actor_variant as Dictionary
		if not bool(actor.get("down", false)):
			count += 1
	return count

func _valid_auto_monster_slot(preferred_slot: int) -> int:
	if auto_monsters.is_empty():
		return 0
	if preferred_slot >= 0 and preferred_slot < auto_monsters.size() and not bool((auto_monsters[preferred_slot] as Dictionary).get("down", false)):
		return preferred_slot
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
		if not bool(actor.get("down", false)):
			return i
	return max(0, min(preferred_slot, auto_monsters.size() - 1))

func _auto_monster_slot_by_uid(uid: int) -> int:
	if uid <= 0:
		return -1
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
		if int(actor.get("uid", 0)) == uid:
			return i
	return -1

func _reset_owner_damage_cash_meter(actor: Dictionary, force_rank_total: bool = false) -> Dictionary:
	var rank := clampi(int(actor.get("rank", 1)), 1, 4)
	var default_total := _owner_damage_cash_total_for_rank(rank)
	var total_pool := default_total if force_rank_total else maxi(0, int(actor.get("owner_damage_cash_total", default_total)))
	if total_pool <= 0 or force_rank_total:
		total_pool = default_total
	actor["owner_damage_cash_total"] = total_pool
	actor["owner_damage_cash_lost"] = 0
	actor["owner_damage_cash_pool"] = total_pool
	actor["last_owner_damage_cash_loss"] = 0
	actor["last_owner_damage_amount"] = 0
	actor["last_owner_damage_source"] = ""
	actor["last_owner_damage_time"] = -1.0
	return actor

func _invalidate_bound_monster_skills(monster_uid: int, reason: String = "绑定怪兽已离场，此固定技能失效。") -> void:
	if monster_uid <= 0:
		return
	for player_index in range(players.size()):
		var player: Dictionary = players[player_index]
		var slots: Array = player.get("slots", [])
		for i in range(slots.size()):
			if slots[i] == null:
				continue
			var skill: Dictionary = slots[i]
			if int(skill.get("bound_monster_uid", 0)) != monster_uid:
				continue
			skill["bound_monster_uid"] = -1
			skill["lock_left"] = max(float(skill.get("lock_left", 0.0)), 9999.0)
			skill["text"] = "%s（%s）" % [String(skill.get("text", "")), reason]
			slots[i] = skill
		player["slots"] = slots
		players[player_index] = player

func _remove_auto_monster(slot: int, reason: String) -> void:
	if slot < 0 or slot >= auto_monsters.size():
		return
	var actor: Dictionary = auto_monsters[slot]
	var uid := int(actor.get("uid", 0))
	_invalidate_bound_monster_skills(uid)
	_add_action_callout(
		"怪%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
		"离场",
		reason,
		Color("#94a3b8"),
		_entity_world_position(actor)
	)
	_log("怪%d·%s离场：%s" % [slot + 1, String(actor.get("name", "怪兽")), reason])
	auto_monsters.remove_at(slot)
	for i in range(auto_monsters.size()):
		var updated: Dictionary = auto_monsters[i]
		updated["slot"] = i
		auto_monsters[i] = updated
	selected_auto_monster_slot = _valid_auto_monster_slot(selected_auto_monster_slot)
	next_special_monster_slot = wrapi(next_special_monster_slot, 0, max(1, auto_monsters.size()))

func _update_auto_monster_durations(delta: float) -> void:
	for slot in range(auto_monsters.size() - 1, -1, -1):
		var actor: Dictionary = auto_monsters[slot]
		var remaining := float(actor.get("remaining_time", -1.0))
		if remaining < 0.0:
			continue
		remaining = max(0.0, remaining - delta)
		actor["remaining_time"] = remaining
		auto_monsters[slot] = actor
		if remaining <= 0.0:
			_remove_auto_monster(slot, "怪兽卡在场时间结束；无论是否倒地，都会撤离星球。")

func _update_auto_monster_revivals(delta: float) -> void:
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if not bool(actor.get("down", false)):
			continue
		var revive_timer := float(actor.get("revive_timer", 0.0))
		if revive_timer <= 0.0:
			continue
		revive_timer = max(0.0, revive_timer - delta)
		actor["revive_timer"] = revive_timer
		if revive_timer <= 0.0:
			actor["down"] = false
			actor["hp"] = int(actor.get("max_hp", actor.get("hp", 1)))
			actor["bracelet_active"] = true
			_log("怪%d·%s手镯复活完成：满血回归，并启用低伤远程反射。" % [slot + 1, String(actor.get("name", "怪兽"))])
			_add_action_callout(
				"怪%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
				"手镯复活完成",
				"满血回归，V字屏障可反射低伤远程攻击。",
				_auto_monster_color(slot),
				_entity_world_position(actor)
			)
		auto_monsters[slot] = actor

func _try_start_auto_monster_revival(slot: int, source: String, actor: Dictionary) -> bool:
	if String(actor.get("name", "")) != "流星哨兵":
		return false
	if not bool(actor.get("revive_available", false)):
		return false
	actor["revive_available"] = false
	actor["down"] = true
	actor["hp"] = 0
	actor["revive_timer"] = float(rng.randi_range(1, 6)) * 4.0
	special_monster_timer = min(special_monster_timer, float(actor["revive_timer"]))
	auto_monsters[slot] = actor
	_log("%s击倒怪%d·流星哨兵，手镯复活启动：%.1fs后满血回归。" % [source, slot + 1, float(actor["revive_timer"])])
	_add_action_callout(
		"怪%d·流星哨兵" % (slot + 1),
		"手镯复活启动",
		"倒地等待%.1fs后满血回归。" % float(actor["revive_timer"]),
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	return true

func _is_auto_ember_ring_energy_active(slot: int) -> bool:
	if slot < 0 or slot >= auto_monsters.size():
		return false
	var actor: Dictionary = auto_monsters[slot]
	return String(actor.get("name", "")) == "焰环幼星" and not bool(actor.get("down", false)) and int(actor.get("hp", 0)) <= EMBER_RING_ENERGY_THRESHOLD

func _maybe_announce_auto_ember_ring_energy(slot: int) -> void:
	if not _is_auto_ember_ring_energy_active(slot):
		return
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("ember_ring_energy_announced", false)):
		return
	actor["ember_ring_energy_announced"] = true
	auto_monsters[slot] = actor
	_log("怪%d·焰环幼星HP降至%d以下，星焰能量启动：移动力提升，近战互伤会追加火焰。" % [slot + 1, EMBER_RING_ENERGY_THRESHOLD])
	_add_action_callout(
		"怪%d·焰环幼星" % (slot + 1),
		"星焰能量启动",
		"移动力提升，近战互伤追加火焰伤害。",
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)

func _is_auto_blue_lancer_reactive_armor_active(slot: int) -> bool:
	if slot < 0 or slot >= auto_monsters.size():
		return false
	var actor: Dictionary = auto_monsters[slot]
	return String(actor.get("name", "")) == "蓝锋骑士" and bool(actor.get("blue_lancer_reactive_armor_active", false))

func _maybe_announce_auto_blue_lancer_reactive_armor(slot: int) -> void:
	if slot < 0 or slot >= auto_monsters.size():
		return
	var actor: Dictionary = auto_monsters[slot]
	if String(actor.get("name", "")) != "蓝锋骑士":
		return
	if bool(actor.get("blue_lancer_reactive_armor_active", false)):
		return
	if int(actor.get("hp", 0)) > BLUE_LANCER_REACTIVE_ARMOR_THRESHOLD:
		return
	actor["blue_lancer_reactive_armor_active"] = true
	auto_monsters[slot] = actor
	_log("怪%d·蓝锋骑士HP降至%d以下，复仇之铠启动：受伤-1、造成伤害+1。" % [slot + 1, BLUE_LANCER_REACTIVE_ARMOR_THRESHOLD])
	_add_action_callout(
		"怪%d·蓝锋骑士" % (slot + 1),
		"复仇之铠启动",
		"受伤-1，造成伤害+1。",
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)

func _auto_monster_damage_bonus_from_passives(slot: int) -> int:
	if _is_auto_blue_lancer_reactive_armor_active(slot):
		_maybe_announce_auto_blue_lancer_reactive_armor(slot)
		return BLUE_LANCER_REACTIVE_DAMAGE_BONUS
	return 0

func _apply_owner_damage_cash_loss(slot: int, damage: int, source: String) -> void:
	if slot < 0 or slot >= auto_monsters.size() or damage <= 0:
		return
	var actor: Dictionary = auto_monsters[slot]
	var monster_owner := int(actor.get("owner", -1))
	if monster_owner < 0 or monster_owner >= players.size():
		return
	var max_hp := maxi(1, int(actor.get("max_hp", 1)))
	var total_pool := maxi(0, int(actor.get("owner_damage_cash_total", actor.get("owner_damage_cash_pool", MONSTER_OWNER_DAMAGE_CASH_POOL))))
	var paid_so_far := maxi(0, int(actor.get("owner_damage_cash_lost", total_pool - int(actor.get("owner_damage_cash_pool", total_pool)))))
	var remaining_pool := maxi(0, total_pool - paid_so_far)
	var loss := mini(remaining_pool, maxi(1, int(round(float(total_pool) * float(damage) / float(max_hp)))))
	if loss <= 0:
		return
	players[monster_owner]["cash"] = max(0, int(players[monster_owner].get("cash", 0)) - loss)
	_record_player_economic_event(monster_owner, "怪兽伤害暴露", String(actor.get("name", "怪兽")), -loss, "%s造成%d伤害" % [source, damage])
	_record_player_cash_snapshot(monster_owner)
	actor["owner_damage_cash_total"] = total_pool
	actor["owner_damage_cash_lost"] = paid_so_far + loss
	actor["owner_damage_cash_pool"] = max(0, total_pool - int(actor["owner_damage_cash_lost"]))
	actor["last_owner_damage_cash_loss"] = loss
	actor["last_owner_damage_amount"] = damage
	actor["last_owner_damage_source"] = source
	actor["last_owner_damage_time"] = game_time
	actor["owner_revealed"] = true
	actor["owner_clue"] = "%s因%s受伤损失¥%d，归属线索公开。" % [players[monster_owner]["name"], source, loss]
	auto_monsters[slot] = actor
	_add_action_callout(
		"归属线索",
		String(actor.get("name", "怪兽")),
		"%s资金-%d：这只怪兽的归属被公开指向。" % [players[monster_owner]["name"], loss],
		Color("#fde68a"),
		_entity_world_position(actor)
	)
	_log("公开情报：怪%d·%s受%s伤害%d，%s按生命比例损失¥%d；可推断其归属。" % [
		slot + 1,
		String(actor.get("name", "怪兽")),
		source,
		damage,
		players[monster_owner]["name"],
		loss,
	])

func _grant_bound_monster_skills(player_index: int, monster_uid: int, monster_name: String, rank: int, fixed_skill_count: int = -1) -> Array:
	var granted := []
	if player_index < 0 or player_index >= players.size():
		return granted
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	if catalog_index < 0:
		return granted
	var actions := _catalog_actions(catalog_index)
	var count: int = mini(maxi(1, fixed_skill_count if fixed_skill_count > 0 else clampi(rank, 1, 4)), actions.size())
	var player: Dictionary = players[player_index]
	for action_index in range(count):
		var skill_name := _monster_technique_card_name(monster_name, action_index, rank)
		var skill := _make_skill(skill_name)
		skill["bound_monster_uid"] = monster_uid
		skill["persistent"] = true
		var slot_index := _first_empty_or_new_slot(player)
		player["slots"][slot_index] = skill
		granted.append(skill_name)
	players[player_index] = player
	return granted

func _field_monster_upgrade_slot_for_card(player_index: int, skill: Dictionary) -> int:
	var monster_name := String(skill.get("monster_name", ""))
	if monster_name == "":
		return -1
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
		if bool(actor.get("down", false)):
			continue
		if int(actor.get("owner", -1)) != player_index:
			continue
		if String(actor.get("name", "")) != monster_name:
			continue
		return i
	return -1

func _owned_active_monster_slot(player_index: int) -> int:
	if player_index < 0:
		return -1
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
		if bool(actor.get("down", false)):
			continue
		if int(actor.get("owner", -1)) == player_index:
			return i
	return -1

func _owned_active_monster_count(player_index: int, exclude_slot: int = -1) -> int:
	if player_index < 0:
		return 0
	var count := 0
	for i in range(auto_monsters.size()):
		if i == exclude_slot:
			continue
		var actor: Dictionary = auto_monsters[i]
		if bool(actor.get("down", false)):
			continue
		if int(actor.get("owner", -1)) == player_index:
			count += 1
	return count

func _upgrade_field_monster_from_card(player_index: int, skill: Dictionary) -> bool:
	var slot := _field_monster_upgrade_slot_for_card(player_index, skill)
	if slot < 0:
		return false
	var actor: Dictionary = auto_monsters[slot]
	var catalog_index := int(actor.get("catalog_index", skill.get("catalog_index", 0)))
	var old_rank := clampi(int(actor.get("rank", 1)), 1, 4)
	var card_rank := clampi(int(skill.get("rank", _skill_rank(String(skill.get("name", ""))))), 1, 4)
	var new_rank := clampi(maxi(old_rank + 1, card_rank), 1, 4)
	var refresh_only := new_rank <= old_rank
	if refresh_only:
		new_rank = old_rank
	var upgraded_card := _make_skill(_monster_card_name(catalog_index, new_rank))
	var old_uid := int(actor.get("uid", 0))
	var old_owner_revealed := bool(actor.get("owner_revealed", false))
	var old_owner_clue := String(actor.get("owner_clue", ""))
	actor["rank"] = new_rank
	actor["hp"] = maxi(1, int(upgraded_card.get("hp", actor.get("hp", 1))))
	actor["max_hp"] = int(actor["hp"])
	actor["move"] = maxf(0.0, float(upgraded_card.get("move", actor.get("move", 0.0))))
	actor["duration"] = float(upgraded_card.get("duration", actor.get("duration", MONSTER_CARD_DURATION_BASE_SECONDS)))
	actor["remaining_time"] = float(actor["duration"])
	actor = _reset_owner_damage_cash_meter(actor, true)
	actor["owner_revealed"] = old_owner_revealed
	actor["owner_clue"] = old_owner_clue
	auto_monsters[slot] = actor
	_invalidate_bound_monster_skills(old_uid, "绑定怪兽已升级，旧固定技能失效。")
	var fixed_skill_count := int(upgraded_card.get("fixed_skill_count", new_rank))
	var granted := _grant_bound_monster_skills(player_index, old_uid, String(actor.get("name", "怪兽")), new_rank, fixed_skill_count)
	if not refresh_only:
		_apply_role_monster_upgrade_cash(player_index, String(actor.get("name", "怪兽")), old_rank, new_rank, _entity_world_position(actor))
	_apply_monster_economic_boons()
	_refresh_product_market_prices()
	_add_action_callout(
		"匿名怪兽卡",
		"%s%s" % [String(actor.get("name", "怪兽")), "刷新" if refresh_only else "升级"],
		"同名怪兽牌%s；HP和在场时间刷新，归属不额外公开。" % ("达到等级上限，改为刷新在场状态" if refresh_only else "使场上怪兽升至%s" % _level_text(new_rank)),
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	_log("匿名怪兽卡%s：怪%d·%s%s，HP刷新为%d、在场时间刷新为%s；固定技能刷新：%s。归属不额外公开。" % [
		"刷新" if refresh_only else "升级",
		slot + 1,
		String(actor.get("name", "怪兽")),
		"保持%s" % _level_text(old_rank) if refresh_only else "从%s升至%s" % [_level_text(old_rank), _level_text(new_rank)],
		int(actor.get("max_hp", 0)),
		_monster_card_duration_text(upgraded_card),
		_limited_name_list(granted, 4, "无"),
	])
	_refresh_ui()
	return true

func _summon_monster_from_card(_player: Dictionary, skill: Dictionary) -> bool:
	var catalog_index := int(skill.get("catalog_index", -1))
	if catalog_index < 0 or catalog_index >= _catalog_size():
		_log("%s没有有效的怪兽资料。" % String(skill.get("name", "怪兽卡")))
		return false
	if _upgrade_field_monster_from_card(selected_player, skill):
		return true
	var owned_count := _owned_active_monster_count(selected_player)
	var monster_limit := _player_monster_control_limit(selected_player)
	if owned_count >= monster_limit:
		var existing_owned_slot := _owned_active_monster_slot(selected_player)
		var owned_actor: Dictionary = auto_monsters[existing_owned_slot] if existing_owned_slot >= 0 else {}
		_log("%s无法新增怪兽：当前角色同时最多归属%d只怪兽；当前已拥有%d只%s。同名怪兽牌仍可用于升级或刷新同名怪兽。" % [
			String(skill.get("name", "怪兽卡")),
			monster_limit,
			owned_count,
			"（包括怪%d·%s）" % [existing_owned_slot + 1, String(owned_actor.get("name", "怪兽"))] if existing_owned_slot >= 0 else "",
		])
		return false
	if selected_district < 0 or selected_district >= districts.size() or bool(districts[selected_district].get("destroyed", false)):
		_log("%s需要选中一个未毁区域作为召唤落点。" % String(skill.get("name", "怪兽卡")))
		return false
	if not _can_summon_monster_card_at_district(skill, selected_district):
		_log("%s需要在%s打出；起始怪兽牌例外。" % [
			String(skill.get("name", "怪兽卡")),
			_monster_card_region_text(skill),
		])
		return false
	var fallback_rank := _skill_rank(String(skill.get("name", "")))
	var rank := clampi(int(skill.get("rank", fallback_rank)), 1, 4)
	var slot := auto_monsters.size()
	var actor := _make_auto_monster(slot, catalog_index, selected_district, selected_player, rank)
	var card_hp := maxi(1, int(skill.get("hp", actor.get("max_hp", 1))))
	actor["hp"] = card_hp
	actor["max_hp"] = card_hp
	actor["move"] = maxf(0.0, float(skill.get("move", actor.get("move", 0.0))))
	actor["duration"] = float(skill.get("duration", actor.get("duration", MONSTER_CARD_DURATION_BASE_SECONDS)))
	actor["remaining_time"] = float(actor["duration"])
	auto_monsters.append(actor)
	selected_auto_monster_slot = slot
	next_special_monster_slot = slot
	_apply_monster_economic_boons()
	_refresh_product_market_prices()
	var fixed_skill_count := int(skill.get("fixed_skill_count", rank))
	var granted := _grant_bound_monster_skills(selected_player, int(actor.get("uid", 0)), String(actor.get("name", "怪兽")), rank, fixed_skill_count)
	_add_visual_trail(_district_center(selected_district) + Vector2(0, -80), _district_center(selected_district), _auto_monster_color(slot), "召唤")
	_add_action_callout(
		"匿名怪兽卡",
		"召唤%s" % String(actor.get("name", "怪兽")),
		"%s降落在%s；HP%d｜在场%s｜区域限制%s；归属暂不公开，固定技能%d张进入召唤者手牌。" % [
			String(actor.get("name", "怪兽")),
			districts[selected_district]["name"],
			int(actor.get("max_hp", 0)),
			_monster_card_duration_text(skill),
			_monster_card_region_text(skill),
			granted.size(),
		],
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	_log("匿名怪兽卡召唤%s %s至%s；归属暂不公开。召唤者获得固定技能：%s。" % [
		String(actor.get("name", "怪兽")),
		_level_text(rank),
		districts[selected_district]["name"],
		_limited_name_list(granted, 4, "无"),
	])
	if selected_player >= 0 and selected_player < players.size():
		_complete_scenario_signal("monster_summoned", "首召怪兽：%s降落在%s。" % [String(actor.get("name", "怪兽")), String(districts[selected_district].get("name", "区域"))], "after_summon", "scenario_coach")
	_refresh_ui()
	return true

func _player_monster_control_limit(player_index: int) -> int:
	var role := _player_role_card_for_index(player_index)
	return maxi(1, 1 + int(role.get("monster_control_limit_bonus", 0)))

func _monster_wager_base_percent(entry: Dictionary) -> int:
	var fallback := MONSTER_WAGER_MIN_BASE_PERCENT
	return clampi(
		int(entry.get("base_percent", fallback)),
		MONSTER_WAGER_MIN_BASE_PERCENT,
		MONSTER_WAGER_MAX_BASE_PERCENT
	)

func _monster_wager_clamped_percent(entry: Dictionary, percent: int) -> int:
	var base_percent := _monster_wager_base_percent(entry)
	return clampi(percent, base_percent, MONSTER_WAGER_MAX_STAKE_PERCENT)

func _monster_wager_amount_for_percent(player_index: int, percent: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var player_cash := maxi(0, int((players[player_index] as Dictionary).get("cash", 0)))
	if player_cash <= 0:
		return 0
	var amount := int(ceil(float(player_cash) * float(percent) / 100.0))
	return clampi(maxi(1, amount), 1, player_cash)

func _monster_wager_percent_options(entry: Dictionary) -> Array:
	var base_percent := _monster_wager_base_percent(entry)
	var result := []
	for step in range(MONSTER_WAGER_VISIBLE_RAISE_STEPS + 1):
		var percent := base_percent + step * MONSTER_WAGER_PERCENT_STEP
		if percent > MONSTER_WAGER_MAX_STAKE_PERCENT:
			break
		result.append(percent)
	return result

func _monster_wager_bet_percent(bet: Dictionary) -> int:
	return int(bet.get("stake_percent", bet.get("percent", 0)))

func _monster_wager_total_stake(entry: Dictionary) -> int:
	var total := maxi(0, int(entry.get("public_card_bid_pool", 0)))
	var bets: Dictionary = entry.get("bets", {}) as Dictionary
	for bet_variant in bets.values():
		if bet_variant is Dictionary:
			total += maxi(0, int((bet_variant as Dictionary).get("stake", 0)))
	return total

func _monster_wager_player_bet(entry: Dictionary, player_index: int) -> Dictionary:
	var bets: Dictionary = entry.get("bets", {}) as Dictionary
	var key := str(player_index)
	if bets.has(key) and bets[key] is Dictionary:
		return (bets[key] as Dictionary).duplicate(true)
	return {}

func _auto_monster_actions(actor: Dictionary) -> Array:
	if String(actor.get("name", "")) == "流星哨兵" and bool(actor.get("bracelet_active", false)):
		return JACK_BRACELET_ACTION_TABLE
	return _catalog_actions(int(actor.get("catalog_index", 0)))

func _auto_monster_action_weights(actor: Dictionary, any_destroyed: bool) -> Array:
	var actions := _auto_monster_actions(actor)
	var monster_name := String(actor.get("name", ""))
	var table: Dictionary = MONSTER_SKILL_WEIGHT_TABLES.get(monster_name, {})
	var source_weights: Array = table.get("escalated" if any_destroyed else "early", [])
	var weights := []
	if source_weights.is_empty():
		weights = _catalog_action_weights(actions, any_destroyed)
	else:
		for i in range(actions.size()):
			weights.append(int(source_weights[i]) if i < source_weights.size() else 0)
	return _ranked_action_weights(weights, int(actor.get("rank", 1)))

func _monster_action_role_tags(action: Dictionary) -> Array:
	var tags := []
	var action_range := float(action.get("range", 0.0))
	var move_override := float(action.get("move_override", -1.0))
	var damage := maxi(int(action.get("damage", 0)), int(action.get("close_damage", 0)))
	if move_override > 0.0:
		tags.append("机动")
	if action_range >= 400.0:
		tags.append("远程")
	elif action_range > 0.0:
		tags.append("近身/区域")
	if damage >= 4:
		tags.append("高伤")
	elif damage > 0:
		tags.append("伤害")
	if float(action.get("knockback", 0.0)) > 0.0 or float(action.get("throw_radius", 0.0)) > 0.0:
		tags.append("位移/击退")
	if int(action.get("miasma_count", 0)) > 0 or int(action.get("reclaim_count", 0)) > 0 or bool(action.get("chaos_ray", false)):
		tags.append("路径/场地")
	if int(action.get("repair", 0)) > 0 or float(action.get("repair_radius", 0.0)) > 0.0 or int(action.get("repair_path", 0)) > 0:
		tags.append("修复")
	if int(action.get("armor", 0)) > 0 or int(action.get("self_heal", 0)) > 0:
		tags.append("续航")
	if int(action.get("tether", 0)) > 0 \
		or int(action.get("stun", 0)) > 0 \
		or int(action.get("paralyze", 0)) > 0 \
		or int(action.get("cripple", 0)) > 0 \
		or int(action.get("delay", 0)) > 0 \
		or int(action.get("stun_if_tethered", 0)) > 0:
		tags.append("控制")
	if int(action.get("self_damage", 0)) > 0:
		tags.append("自损爆发")
	if tags.is_empty():
		tags.append("基础")
	return tags

func _monster_resource_match_score(actor: Dictionary, index: int) -> int:
	if index < 0 or index >= districts.size():
		return 0
	var focus: Array = actor.get("resource_focus", [])
	if focus.is_empty():
		return 0
	var score := 0
	var district_products: Array = districts[index].get("products", [])
	var district_demands: Array = districts[index].get("demands", [])
	var city := _district_city(index)
	var city_products := _city_product_names(city) if _city_is_active(city) else []
	var city_demands := _city_demand_names(city) if _city_is_active(city) else []
	var warehouse_products: Array = city.get("warehouse_stockpile_products", []) if _city_is_active(city) else []
	for product_variant in focus:
		var product_name := String(product_variant)
		if district_products.has(product_name):
			score += 1
		if district_demands.has(product_name):
			score += 1
		if city_products.has(product_name):
			score += 2
		if city_demands.has(product_name):
			score += 1
		if warehouse_products.has(product_name):
			score += 2 + mini(3, int(float(int(city.get("warehouse_stockpile_units", 0))) / 2.0))
		for route_variant in _route_network_routes_for_product(product_name):
			var route: Dictionary = route_variant
			var path: Array = route.get("path", [])
			if path.has(index):
				score += 1
	return min(score, 8)

func _apply_monster_economic_boons() -> void:
	if auto_monsters.is_empty():
		return
	var summaries := []
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		var catalog_index := int(actor.get("catalog_index", 0))
		var entry := _catalog_entry(catalog_index)
		var boon: Dictionary = entry.get("economy_boon", {})
		if boon.is_empty():
			continue
		var resource_focus: Array = entry.get("resource_focus", [])
		if resource_focus.is_empty():
			continue
		var label := String(boon.get("label", String(entry.get("name", "怪兽"))))
		var growth_multiplier: float = float(boon.get("growth_multiplier", 1.0))
		var route_flow_multiplier: float = float(boon.get("route_flow_multiplier", 1.0))
		var applied_products := []
		for product_variant in resource_focus:
			var product_name := String(product_variant)
			if _apply_product_market_boon(product_name, growth_multiplier, route_flow_multiplier, 0, label, true):
				applied_products.append(product_name)
		if applied_products.is_empty():
			continue
		var summary := "%s→%s" % [String(entry.get("name", "怪兽")), _limited_name_list(applied_products, 3)]
		summaries.append(summary)
		_add_action_callout(
			String(entry.get("name", "怪兽")),
			"经济天气",
			"%s：%s" % [label, _compact_card_list(applied_products, 3)],
			_auto_monster_color(int(actor.get("slot", 0))),
			_entity_world_position(actor),
			CARD_INGRESS_CALLOUT_DURATION
		)
	if not summaries.is_empty():
		_log("怪兽经济天气启动：%s。" % "；".join(summaries))

func _auto_monster_lure_target(actor: Dictionary) -> int:
	var moves_left := int(actor.get("lure_moves_left", 0))
	var target := int(actor.get("lure_target_district", -1))
	if moves_left <= 0 or target < 0 or target >= districts.size():
		return -1
	if bool(districts[target].get("destroyed", false)):
		return -1
	return target

func _consume_auto_monster_lure(actor: Dictionary) -> Dictionary:
	if int(actor.get("lure_moves_left", 0)) <= 0:
		return actor
	actor["lure_moves_left"] = maxi(0, int(actor.get("lure_moves_left", 0)) - 1)
	if int(actor.get("lure_moves_left", 0)) <= 0:
		actor.erase("lure_target_district")
		actor.erase("lure_moves_left")
		actor.erase("lure_source")
	return actor

func _auto_monster_movement_tick() -> void:
	var acted := 0
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		if _entity_has_linear_motion(actor):
			auto_monsters[slot] = actor
			continue
		var target := _weighted_auto_monster_target(actor)
		var lure_target := _auto_monster_lure_target(actor)
		var lure_source := String(actor.get("lure_source", "匿名诱导"))
		var was_lured := lure_target >= 0
		if was_lured:
			target = lure_target
			actor = _consume_auto_monster_lure(actor)
		if target < 0:
			continue
		var before := _entity_world_position(actor)
		var started_linear_move := false
		var planned_distance := 0.0
		if target != int(actor.get("position", -1)):
			var movement_mode := _auto_monster_movement_mode(actor)
			var movement_label := "怪%d诱导" % (slot + 1) if was_lured else "怪%d自动" % (slot + 1)
			var movement_reason := "被%s诱导" % lure_source if was_lured else _auto_monster_target_factor_summary(actor, target)
			var speed_mps := _auto_monster_movement_speed_mps(actor, target)
			planned_distance = _start_entity_linear_motion(actor, _district_center(target), speed_mps, "诱导移动" if was_lured else "自动移动", movement_mode, -1.0, "auto_move")
			if planned_distance > 0.5:
				started_linear_move = true
				_add_visual_trail(before, _district_center(target), _auto_monster_color(slot), movement_label)
				_log("怪%d·%s%s锁定%s，开始以%s/秒线性移动，预计%s抵达（%s）。" % [
					slot + 1,
					String(actor.get("name", "怪兽")),
					"被%s诱导" % lure_source if was_lured else "按概率",
					districts[target]["name"],
					_meters_text(speed_mps),
					_duration_short_text(planned_distance / maxf(1.0, speed_mps)),
					movement_reason,
				])
				_add_action_callout(
					"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
					"诱导启程" if was_lured else "自动启程",
					"目标%s｜速度%s/秒｜预计%s；%s。" % [
						districts[target]["name"],
						_meters_text(speed_mps),
						_duration_short_text(planned_distance / maxf(1.0, speed_mps)),
						"诱导只生效一次" if was_lured else "主因:%s" % _auto_monster_target_factor_summary(actor, target),
					],
					_auto_monster_color(slot),
					before
				)
				auto_monsters[slot] = actor
				acted += 1
				continue
		if not started_linear_move:
			_log("怪%d·%s%s停留在%s并继续施压（%s）。" % [
				slot + 1,
				String(actor.get("name", "怪兽")),
				"被%s诱导后" % lure_source if was_lured else "",
				districts[int(actor["position"])]["name"],
				"诱导目标已在脚下" if was_lured else _auto_monster_target_factor_summary(actor, target),
			])
			_add_action_callout(
				"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
				"诱导停留" if was_lured else "自动停留",
				"停留在%s并继续施压；%s。" % [
					districts[int(actor["position"])]["name"],
					"诱导已消耗" if was_lured else "按当前概率表",
				],
				_auto_monster_color(slot),
				_entity_world_position(actor)
			)
		var landing_damage := _auto_monster_move_damage(actor, _auto_monster_movement_mode(actor))
		if landing_damage > 0:
			_damage_district(int(actor["position"]), landing_damage, "%s自动破坏" % String(actor.get("name", "怪兽")))
		_auto_monster_resource_drain(actor, int(actor["position"]), "自动移动")
		auto_monsters[slot] = actor
		_resolve_auto_monster_encounter(slot, "同区遭遇")
		acted += 1
	if acted <= 0:
		_log("当前没有可行动怪兽；城市经营继续，等待怪兽复活、到期离场或后续召唤。")
		return
	_refresh_ui()

func _next_active_auto_monster_slot() -> int:
	if auto_monsters.is_empty():
		return -1
	for offset in range(auto_monsters.size()):
		var slot: int = (next_special_monster_slot + offset) % auto_monsters.size()
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		if _entity_has_linear_motion(actor):
			continue
		next_special_monster_slot = (slot + 1) % auto_monsters.size()
		return slot
	return -1

func _auto_special_monster_tick() -> void:
	var slot := _next_active_auto_monster_slot()
	if slot < 0:
		_log("当前没有可执行特殊行动的怪兽；计时器等待下一只活跃怪兽。")
		return
	_auto_special_monster_tick_for_slot(slot)
	_refresh_ui()

func _auto_special_monster_tick_for_slot(slot: int) -> void:
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("down", false)):
		return
	if _entity_has_linear_motion(actor):
		_log("怪%d·%s仍在执行线性移动，特殊行动延后到抵达后再判定。" % [slot + 1, String(actor.get("name", "怪兽"))])
		return
	var actions := _auto_monster_actions(actor)
	var any_destroyed := _has_destroyed_district()
	var weights := _auto_monster_action_weights(actor, any_destroyed)
	var action_index := _weighted_pick_index(weights)
	if action_index < 0:
		return
	var action: Dictionary = actions[action_index]
	var total := _weight_total(weights)
	var target := _weighted_auto_monster_target(actor)
	if target < 0:
		return
	var before := _entity_world_position(actor)
	var required_range: float = float(action.get("range", 0.0))
	var move_budget: float = _auto_monster_movement_speed_mps(actor, target, float(action.get("move_override", -1.0)))
	if required_range <= 0.0 or _entity_distance_to_district(actor, target) > required_range:
		var planned_distance := _start_entity_linear_motion(actor, _district_center(target), move_budget, String(action.get("name", "行动")), _auto_monster_movement_mode(actor), -1.0, "special_action_move")
		if planned_distance > 0.5:
			_add_visual_trail(before, _district_center(target), _auto_monster_color(slot), String(action.get("name", "行动")))
			_log("怪%d·%s准备%s，先以%s/秒线性接近%s，预计%s后抵达射程。" % [
				slot + 1,
				String(actor.get("name", "怪兽")),
				String(action.get("name", "行动")),
				_meters_text(move_budget),
				districts[target]["name"],
				_duration_short_text(planned_distance / maxf(1.0, move_budget)),
			])
			_add_action_callout(
				"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
				"招式接近",
				"%s先向%s线性移动；抵达后再重新抽取/释放行动。" % [String(action.get("name", "行动")), districts[target]["name"]],
				_auto_monster_color(slot),
				before
			)
			auto_monsters[slot] = actor
			return
	var target_after_move: int = target
	if required_range <= 0.0:
		target_after_move = int(actor.get("position", target))
	var district_in_range: bool = required_range <= 0.0 or _entity_distance_to_district(actor, target_after_move) <= required_range
	var district_damage: int = max(AUTO_MONSTER_MIN_SPECIAL_DAMAGE, int(ceil(float(action.get("damage", 1)) * 0.5)))
	_log("怪%d·%s概率模拟选择：%s（%s），目标%s（%s）。%s" % [
		slot + 1,
		String(actor.get("name", "怪兽")),
		String(action.get("name", "行动")),
		_auto_monster_action_probability_text(actor, action_index, weights, total, any_destroyed),
		districts[target_after_move]["name"] if target_after_move >= 0 and target_after_move < districts.size() else "未知区域",
		_auto_monster_target_factor_summary(actor, target_after_move),
		String(action.get("text", "")),
	])
	_add_action_callout(
		"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
		String(action.get("name", "行动")),
		"目标%s；%s" % [
			districts[target_after_move]["name"] if target_after_move >= 0 and target_after_move < districts.size() else "未知区域",
			String(action.get("text", "")),
		],
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	if district_in_range:
		_add_monster_attack_effect(_entity_world_position(actor), _district_center(target_after_move), String(action.get("name", "行动")), required_range, _auto_monster_color(slot), required_range > MELEE_RANGE_METERS, _monster_action_animation_profile(String(actor.get("name", "怪兽")), action, action_index))
		_damage_district(target_after_move, district_damage, "%s·%s" % [String(actor.get("name", "怪兽")), String(action.get("name", "行动"))])
		_auto_monster_resource_drain(actor, target_after_move, String(action.get("name", "行动")))
		_place_auto_miasma(actor, target_after_move, int(action.get("miasma_count", 0)), String(action.get("name", "行动")))
	else:
		_log("%s距离%s过远，特殊行动只完成移动未命中城区。" % [
			String(actor.get("name", "怪兽")),
			districts[target_after_move]["name"],
		])
	var armor_gain := int(action.get("armor", 0))
	if armor_gain > 0:
		actor["armor"] = int(actor.get("armor", 0)) + armor_gain
		_log("%s通过%s获得%d点护甲。" % [String(actor.get("name", "怪兽")), String(action.get("name", "行动")), armor_gain])
	var self_heal := int(action.get("self_heal", 0))
	if self_heal > 0:
		actor["hp"] = min(int(actor.get("max_hp", 0)), int(actor.get("hp", 0)) + self_heal)
		_log("%s通过%s回复%d HP。" % [String(actor.get("name", "怪兽")), String(action.get("name", "行动")), self_heal])
	var self_damage := int(action.get("self_damage", 0))
	auto_monsters[slot] = actor
	var hit_other := false
	if int(action.get("damage", 0)) > 0:
		hit_other = _try_auto_monster_hit_other(slot, action)
	if not hit_other:
		_resolve_auto_monster_encounter(slot, "资源争夺")
	if self_damage > 0:
		_auto_monster_take_damage(slot, self_damage, "%s反冲" % String(action.get("name", "行动")), -1)

func _monster_has_trait(actor: Dictionary, trait_name: String) -> bool:
	var traits: Array = actor.get("movement_traits", []) as Array
	return traits.has(trait_name)

func _monster_movement_mode(actor: Dictionary) -> String:
	if _monster_has_trait(actor, "flying"):
		return "fly"
	if _monster_has_trait(actor, "aquatic"):
		return "aquatic"
	return "walk"

func _auto_monster_movement_mode(actor: Dictionary) -> String:
	return _monster_movement_mode(actor)

func _monster_terrain_move_multiplier(actor: Dictionary, district_index: int) -> float:
	var multipliers: Dictionary = actor.get("terrain_move_multiplier", {}) as Dictionary
	if district_index < 0 or district_index >= districts.size():
		return float(multipliers.get("default", 1.0))
	var terrain := String(districts[district_index].get("terrain", "land"))
	return maxf(0.2, float(multipliers.get(terrain, multipliers.get("default", 1.0))))

func _auto_monster_move_budget(actor: Dictionary, target_index: int) -> float:
	return float(actor.get("move", MONSTER_RAMPAGE_MOVE_METERS)) * _monster_terrain_move_multiplier(actor, target_index)

func _auto_monster_move_damage(actor: Dictionary, movement_mode: String = "") -> int:
	var mode := movement_mode if movement_mode != "" else _auto_monster_movement_mode(actor)
	if mode == "fly" or _monster_has_trait(actor, "flying"):
		return 0
	return max(_preset_int("monster_damage"), int(actor.get("move_damage", AUTO_MONSTER_DEFAULT_MOVE_DAMAGE)))

func _auto_monster_collision_damage(actor: Dictionary) -> int:
	return max(AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE, int(actor.get("collision_damage", AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE)))

func _path_district_indices_between(from_position: Vector2, to_position: Vector2, final_index: int = -1, max_regions: int = AUTO_MONSTER_PATH_DAMAGE_MAX_REGIONS) -> Array:
	var result := []
	_append_unique_district_index(result, _district_at_point(from_position))
	var distance := _wrapped_distance(from_position, to_position)
	var steps: int = max(1, int(ceil(distance / AUTO_MONSTER_PATH_DAMAGE_STEP_METERS)))
	for step in range(1, steps):
		var sample := _spherical_lerp_world(from_position, to_position, float(step) / float(steps))
		_append_unique_district_index(result, _district_at_point(sample))
	var end_index := final_index
	if end_index < 0:
		end_index = _district_at_point(to_position)
	if end_index < 0:
		end_index = _nearest_district_to(to_position)
	_append_unique_district_index(result, end_index)
	while result.size() > max_regions and result.size() > 2:
		result.remove_at(result.size() - 2)
	return result

func _damage_districts_on_monster_path(actor: Dictionary, from_position: Vector2, to_position: Vector2, amount: int, source: String, max_regions: int = AUTO_MONSTER_PATH_DAMAGE_MAX_REGIONS) -> int:
	if amount <= 0:
		return 0
	var applied := 0
	var indices := _path_district_indices_between(from_position, to_position, int(actor.get("position", -1)), max_regions)
	for index_variant in indices:
		var index := int(index_variant)
		if index < 0 or index >= districts.size() or bool(districts[index].get("destroyed", false)):
			continue
		_damage_district(index, amount, source)
		applied += amount
	return applied

func _apply_auto_monster_path_effects(actor: Dictionary, from_position: Vector2, to_position: Vector2, source: String, movement_mode: String = "") -> int:
	if movement_mode == "fly" or _monster_has_trait(actor, "flying"):
		_log("%s以飞行路线穿越区域，未造成路径碾压破坏。" % String(actor.get("name", "怪兽")))
		return 0
	var damage_source := "%s·%s移动碾压" % [String(actor.get("name", "怪兽")), source]
	var applied_damage := _damage_districts_on_monster_path(actor, from_position, to_position, _auto_monster_move_damage(actor, movement_mode), damage_source)
	if applied_damage > 0:
		_log("%s沿途造成合计%d点区域/城市破坏。" % [damage_source, applied_damage])
		_add_action_callout(
			String(actor.get("name", "怪兽")),
			"路径破坏",
			"%s沿移动路径造成合计%d点区域伤害。" % [source, applied_damage],
			Color("#fb7185"),
			_entity_world_position(actor)
		)
	if String(actor.get("name", "")) != "孢雾海皇":
		return applied_damage
	var candidates := []
	_append_unique_district_index(candidates, _district_at_point(from_position))
	_append_unique_district_index(candidates, _nearest_district_to((from_position + to_position) * 0.5))
	_append_unique_district_index(candidates, int(actor.get("position", -1)))
	for index in candidates:
		if index < 0 or index >= districts.size():
			continue
		if districts[index]["destroyed"] or districts[index]["miasma"]:
			continue
		districts[index]["miasma"] = true
		_pulse_district(index, Color("#a855f7"))
		_log("%s使孢雾海皇沿路径在%s留下瘴气。" % [source, districts[index]["name"]])
		return applied_damage
	return applied_damage

func _apply_auto_monster_linear_path_effects(actor: Dictionary, from_position: Vector2, to_position: Vector2, source: String, movement_mode: String = "", max_regions: int = AUTO_MONSTER_PATH_DAMAGE_MAX_REGIONS) -> int:
	if _wrapped_distance(from_position, to_position) <= 0.5:
		return 0
	if movement_mode == "fly" or _monster_has_trait(actor, "flying"):
		return 0
	var damage := _auto_monster_collision_damage(actor) if String(actor.get("linear_move_arrival_action", "")) == "knockback" else _auto_monster_move_damage(actor, movement_mode)
	if damage <= 0:
		return 0
	var already_damaged: Array = (actor.get("linear_move_damaged_districts", []) as Array).duplicate()
	var indices := _path_district_indices_between(from_position, to_position, int(actor.get("position", -1)), max_regions)
	var applied := 0
	for index_variant in indices:
		var index := int(index_variant)
		if index < 0 or index >= districts.size() or bool(districts[index].get("destroyed", false)):
			continue
		if already_damaged.has(index):
			continue
		_damage_district(index, damage, "%s·%s线性碾压" % [String(actor.get("name", "怪兽")), source])
		already_damaged.append(index)
		applied += damage
	actor["linear_move_damaged_districts"] = already_damaged
	if applied > 0:
		_log("%s沿线性移动路径造成合计%d点区域/城市破坏。" % [String(actor.get("name", "怪兽")), applied])
	return applied

func _update_auto_monster_linear_movement(delta: float) -> void:
	var any_changed := false
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			if _entity_has_linear_motion(actor):
				_clear_entity_linear_motion(actor)
				auto_monsters[slot] = actor
			continue
		if not _entity_has_linear_motion(actor):
			continue
		var info := _advance_entity_linear_motion(actor, delta)
		var moved := float(info.get("moved", 0.0))
		if moved > 0.5:
			_apply_auto_monster_linear_path_effects(
				actor,
				info.get("before", _entity_world_position(actor)),
				info.get("after", _entity_world_position(actor)),
				String(info.get("source", "线性移动")),
				String(info.get("mode", "")),
				AUTO_MONSTER_KNOCKBACK_DAMAGE_MAX_REGIONS if String(info.get("arrival_action", "")) == "knockback" else AUTO_MONSTER_PATH_DAMAGE_MAX_REGIONS
			)
			any_changed = true
		if bool(info.get("arrived", false)):
			var target_district := int(info.get("target_district", actor.get("position", -1)))
			if target_district < 0 or target_district >= districts.size():
				target_district = int(actor.get("position", _nearest_district_to(_entity_world_position(actor))))
			actor["world_position"] = info.get("target", actor.get("world_position", Vector2.ZERO))
			actor["position"] = target_district
			var source := String(info.get("source", "线性移动"))
			var arrival_action := String(info.get("arrival_action", ""))
			var mode := String(info.get("mode", ""))
			var landing_damage := _auto_monster_move_damage(actor, mode)
			if landing_damage > 0 and mode != "fly" and not _monster_has_trait(actor, "flying"):
				_damage_district(target_district, landing_damage, "%s·%s抵达冲击" % [String(actor.get("name", "怪兽")), source])
			var arrival_damage := maxi(0, int(actor.get("linear_move_arrival_damage", 0)))
			if arrival_damage > 0:
				_damage_district(target_district, arrival_damage, String(actor.get("linear_move_arrival_damage_source", source)))
			_auto_monster_resource_drain(actor, target_district, source)
			_add_action_callout(
				"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
				"击退落点" if arrival_action == "knockback" else "移动抵达",
				"%s抵达%s；移动按米/秒线性结算。" % [source, String(districts[target_district].get("name", "区域"))],
				_auto_monster_color(slot),
				_entity_world_position(actor)
			)
			_clear_entity_linear_motion(actor)
			auto_monsters[slot] = actor
			_resolve_auto_monster_encounter(slot, "线性移动抵达")
			any_changed = true
		else:
			auto_monsters[slot] = actor
	if any_changed:
		_refresh_ui()

func _place_auto_miasma(_actor: Dictionary, center_index: int, max_tokens: int, source: String) -> void:
	if max_tokens <= 0:
		return
	var candidates := _districts_in_radius(_district_center(center_index), 260.0, true)
	var placed := 0
	for index in candidates:
		if placed >= max_tokens:
			break
		if districts[index]["destroyed"] or districts[index]["miasma"]:
			continue
		districts[index]["miasma"] = true
		_pulse_district(index, Color("#a855f7"))
		placed += 1
		_log("%s在%s散布瘴气。" % [source, districts[index]["name"]])

func _try_auto_monster_hit_other(slot: int, action: Dictionary) -> bool:
	var target_slot := _nearest_other_auto_monster_slot(slot)
	if target_slot < 0:
		return false
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	var range_limit: float = float(action.get("range", MELEE_RANGE_METERS))
	if range_limit <= 0.0:
		range_limit = MELEE_RANGE_METERS
	if _wrapped_distance(_entity_world_position(actor), _entity_world_position(target)) > range_limit:
		return false
	return _auto_monster_use_action_on_other(slot, target_slot, action, "招式命中")

func _auto_monster_brawl_action(slot: int, target_slot: int) -> Dictionary:
	if slot < 0 or slot >= auto_monsters.size() or target_slot < 0 or target_slot >= auto_monsters.size():
		return {}
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	var distance := _wrapped_distance(_entity_world_position(actor), _entity_world_position(target))
	var actions := _auto_monster_actions(actor)
	var candidates := []
	var weights := []
	for action_variant in actions:
		var action: Dictionary = action_variant
		var damage := int(action.get("damage", 0))
		if damage <= 0:
			continue
		var range_limit: float = float(action.get("range", MELEE_RANGE_METERS))
		if range_limit <= 0.0:
			range_limit = MELEE_RANGE_METERS
		if distance > range_limit:
			continue
		candidates.append(action)
		weights.append(max(1, damage * 3 + int(round(float(action.get("knockback", 0.0)) / 80.0))))
	if candidates.is_empty():
		return {
			"name": "资源争夺撞击",
			"range": AUTO_MONSTER_ENCOUNTER_RANGE_METERS,
			"damage": _auto_monster_collision_damage(actor),
			"knockback": 100.0,
			"text": "怪兽在同一区域争夺资源，发生基础撞击。",
		}
	var picked := _weighted_pick_index(weights)
	return candidates[max(0, picked)] as Dictionary

func _monster_resource_matches(actor: Dictionary, index: int) -> Array:
	var result := []
	if index < 0 or index >= districts.size():
		return result
	var focus: Array = actor.get("resource_focus", [])
	if focus.is_empty():
		return result
	var resource_pool := []
	for product_variant in districts[index].get("products", []):
		_append_unique_string(resource_pool, String(product_variant))
	for demand_variant in districts[index].get("demands", []):
		_append_unique_string(resource_pool, String(demand_variant))
	var city := _district_city(index)
	if _city_is_active(city):
		for product_name in _city_product_names(city):
			_append_unique_string(resource_pool, String(product_name))
		for demand_name in _city_demand_names(city):
			_append_unique_string(resource_pool, String(demand_name))
	for focus_variant in focus:
		var product_name := String(focus_variant)
		if product_name == "":
			continue
		if resource_pool.has(product_name):
			_append_unique_string(result, product_name)
			continue
		for route_variant in _route_network_routes_for_product(product_name):
			var route: Dictionary = route_variant
			if (route.get("path", []) as Array).has(index):
				_append_unique_string(result, product_name)
				break
	return result

func _auto_monster_resource_drain(actor: Dictionary, index: int, source: String) -> int:
	if index < 0 or index >= districts.size() or bool(districts[index].get("destroyed", false)):
		return 0
	var drain_damage := int(actor.get("resource_drain", 0))
	if drain_damage <= 0:
		return 0
	var matches := _monster_resource_matches(actor, index)
	if matches.is_empty():
		return 0
	var match_text := _limited_name_list(matches, 4, "未知资源")
	_damage_district(index, drain_damage, "%s资源吸取" % String(actor.get("name", "怪兽")))
	_log("%s在%s吸取%s，额外造成%d点区域/城市伤害。" % [
		String(actor.get("name", "怪兽")),
		districts[index]["name"],
		match_text,
		drain_damage,
	])
	_add_action_callout(
		String(actor.get("name", "怪兽")),
		"资源吸取",
		"%s被%s吸引，额外造成%d点伤害。" % [match_text, source, drain_damage],
		Color("#f97316"),
		_district_center(index)
	)
	return drain_damage

func _append_unique_string(result: Array, value: String) -> void:
	if value == "":
		return
	if not result.has(value):
		result.append(value)

func _monster_wager_side_ids() -> Array:
	return ["a", "b", "c", "d", "e", "f", "g", "h"]

func _monster_wager_slot_key(slot: int) -> String:
	if slot < 0 or slot >= auto_monsters.size():
		return "slot:%d" % slot
	var actor: Dictionary = auto_monsters[slot]
	var uid := int(actor.get("uid", 0))
	return "uid:%d" % uid if uid > 0 else "slot:%d" % slot

func _monster_wager_key_for_competitors(competitors: Array) -> String:
	var keys := []
	for competitor_variant in competitors:
		if not (competitor_variant is Dictionary):
			continue
		var competitor := competitor_variant as Dictionary
		keys.append(_monster_wager_slot_key(int(competitor.get("slot", -1))))
	keys.sort()
	return "|".join(keys)

func _monster_wager_competitors_for_pair(slot_a: int, slot_b: int) -> Array:
	var result := []
	if slot_a < 0 or slot_a >= auto_monsters.size() or slot_b < 0 or slot_b >= auto_monsters.size():
		return result
	var side_ids := _monster_wager_side_ids()
	var used := {}
	for slot in [slot_a, slot_b]:
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		result.append({
			"side": String(side_ids[result.size()]),
			"slot": slot,
			"uid": int(actor.get("uid", 0)),
			"name": String(actor.get("name", "怪兽")),
			"damage": 0,
		})
		used[slot] = true
	if result.size() < 2:
		return []
	var anchor_positions := [
		int((auto_monsters[slot_a] as Dictionary).get("position", -1)),
		int((auto_monsters[slot_b] as Dictionary).get("position", -1)),
	]
	for i in range(auto_monsters.size()):
		if used.has(i) or result.size() >= side_ids.size():
			continue
		var actor: Dictionary = auto_monsters[i]
		if bool(actor.get("down", false)):
			continue
		var monster_position := int(actor.get("position", -1))
		if not anchor_positions.has(monster_position):
			continue
		result.append({
			"side": String(side_ids[result.size()]),
			"slot": i,
			"uid": int(actor.get("uid", 0)),
			"name": String(actor.get("name", "怪兽")),
			"damage": 0,
		})
	return result

func _active_monster_wager_index_for_pair(slot_a: int, slot_b: int) -> int:
	if slot_a < 0 or slot_a >= auto_monsters.size() or slot_b < 0 or slot_b >= auto_monsters.size():
		return -1
	for i in range(active_monster_wagers.size()):
		var entry: Dictionary = active_monster_wagers[i]
		if bool(entry.get("resolved", false)):
			continue
		if _monster_wager_side_for_slot(entry, slot_a) != "" and _monster_wager_side_for_slot(entry, slot_b) != "":
			return i
	return -1

func _monster_wager_entry_index_by_id(wager_id: int) -> int:
	for i in range(active_monster_wagers.size()):
		var entry: Dictionary = active_monster_wagers[i]
		if int(entry.get("wager_id", -1)) == wager_id:
			return i
	return -1

func _latest_active_monster_wager() -> Dictionary:
	for i in range(active_monster_wagers.size() - 1, -1, -1):
		var entry: Dictionary = active_monster_wagers[i]
		if not bool(entry.get("resolved", false)):
			return entry.duplicate(true)
	return {}

func _monster_wager_current_slot(entry: Dictionary, side: String) -> int:
	for competitor_variant in _monster_wager_competitors(entry):
		var competitor := competitor_variant as Dictionary
		if String(competitor.get("side", "")) != side:
			continue
		var competitor_uid := int(competitor.get("uid", 0))
		var competitor_slot := _auto_monster_slot_by_uid(competitor_uid) if competitor_uid > 0 else -1
		if competitor_slot >= 0:
			return competitor_slot
		competitor_slot = int(competitor.get("slot", -1))
		if competitor_slot >= 0 and competitor_slot < auto_monsters.size():
			return competitor_slot
	var key_prefix := "monster_%s" % side
	var entry_uid := int(entry.get("%s_uid" % key_prefix, 0))
	var entry_slot := _auto_monster_slot_by_uid(entry_uid) if entry_uid > 0 else -1
	if entry_slot >= 0:
		return entry_slot
	entry_slot = int(entry.get("%s_slot" % key_prefix, -1))
	if entry_slot >= 0 and entry_slot < auto_monsters.size():
		var actor: Dictionary = auto_monsters[entry_slot]
		if entry_uid <= 0 or int(actor.get("uid", 0)) == entry_uid:
			return entry_slot
	return -1

func _monster_wager_side_active(entry: Dictionary, side: String) -> bool:
	var slot := _monster_wager_current_slot(entry, side)
	if slot < 0 or slot >= auto_monsters.size():
		return false
	return not bool((auto_monsters[slot] as Dictionary).get("down", false))

func _monster_wager_side_for_slot(entry: Dictionary, slot: int) -> String:
	if slot < 0 or slot >= auto_monsters.size():
		return ""
	var actor: Dictionary = auto_monsters[slot]
	var uid := int(actor.get("uid", 0))
	for competitor_variant in _monster_wager_competitors(entry):
		var competitor := competitor_variant as Dictionary
		if uid > 0 and int(competitor.get("uid", 0)) == uid:
			return String(competitor.get("side", ""))
		if int(competitor.get("slot", -1)) == slot:
			return String(competitor.get("side", ""))
	if uid > 0:
		if int(entry.get("monster_a_uid", 0)) == uid:
			return "a"
		if int(entry.get("monster_b_uid", 0)) == uid:
			return "b"
	if int(entry.get("monster_a_slot", -1)) == slot:
		return "a"
	if int(entry.get("monster_b_slot", -1)) == slot:
		return "b"
	return ""

func _monster_wager_side_label(entry: Dictionary, side: String) -> String:
	for competitor_variant in _monster_wager_competitors(entry):
		var competitor := competitor_variant as Dictionary
		if String(competitor.get("side", "")) == side:
			return String(competitor.get("name", "怪兽"))
	if side == "a":
		return String(entry.get("monster_a_name", "怪兽A"))
	if side == "b":
		return String(entry.get("monster_b_name", "怪兽B"))
	return "平局"

func _monster_wager_competitors(entry: Dictionary) -> Array:
	var competitors: Array = entry.get("competitors", [])
	if not competitors.is_empty():
		return competitors
	var fallback := []
	if entry.has("monster_a_name"):
		fallback.append({
			"side": "a",
			"slot": int(entry.get("monster_a_slot", -1)),
			"uid": int(entry.get("monster_a_uid", 0)),
			"name": String(entry.get("monster_a_name", "怪兽A")),
			"damage": int(entry.get("damage_a", 0)),
		})
	if entry.has("monster_b_name"):
		fallback.append({
			"side": "b",
			"slot": int(entry.get("monster_b_slot", -1)),
			"uid": int(entry.get("monster_b_uid", 0)),
			"name": String(entry.get("monster_b_name", "怪兽B")),
			"damage": int(entry.get("damage_b", 0)),
		})
	return fallback

func _monster_wager_matchup_text(entry: Dictionary) -> String:
	var names := []
	for competitor_variant in _monster_wager_competitors(entry):
		var competitor := competitor_variant as Dictionary
		names.append(String(competitor.get("name", "怪兽")))
	return " vs ".join(names) if not names.is_empty() else "怪兽混战"

func _monster_wager_damage_for_side(entry: Dictionary, side: String) -> int:
	return int(entry.get("damage_%s" % side, 0))

func _monster_wager_damage_score_text(entry: Dictionary) -> String:
	var pieces := []
	for competitor_variant in _monster_wager_competitors(entry):
		var competitor := competitor_variant as Dictionary
		var side := String(competitor.get("side", ""))
		pieces.append("%s:%d" % [
			String(competitor.get("name", "怪兽")),
			_monster_wager_damage_for_side(entry, side),
		])
	return " / ".join(pieces) if not pieces.is_empty() else "暂无"

func _monster_wager_player_side(entry: Dictionary, player_index: int) -> String:
	var bets: Dictionary = entry.get("bets", {}) as Dictionary
	var key := str(player_index)
	if not bets.has(key) or not (bets[key] is Dictionary):
		return ""
	var bet: Dictionary = bets[key]
	return String(bet.get("side", ""))

func _monster_wager_player_decision(entry: Dictionary, player_index: int) -> String:
	return _monster_wager_player_side(entry, player_index)

func _monster_wager_decision_count(entry: Dictionary) -> int:
	var bets: Dictionary = entry.get("bets", {}) as Dictionary
	return bets.size()

func _monster_wager_all_players_decided(entry: Dictionary) -> bool:
	return _monster_wager_decision_count(entry) >= players.size()

func _monster_wager_public_decision_summary(entry: Dictionary) -> String:
	var bets: Dictionary = entry.get("bets", {}) as Dictionary
	if bets.is_empty():
		return "暂无公开下注"
	var pieces := []
	for key_variant in bets.keys():
		var bet_variant: Variant = bets[key_variant]
		if not (bet_variant is Dictionary):
			continue
		var bet := bet_variant as Dictionary
		var player_index := int(bet.get("player_index", int(String(key_variant))))
		var stake := int(bet.get("stake", 0))
		var percent := _monster_wager_bet_percent(bet)
		if stake < 0:
			continue
		pieces.append("%s %d%%/¥%d→%s" % [
			_player_name(player_index),
			percent,
			stake,
			_monster_wager_side_label(entry, String(bet.get("side", ""))),
		])
	if pieces.is_empty():
		return "暂无公开下注"
	return "；".join(pieces)

func _monster_wager_public_bet_summary(entry: Dictionary) -> String:
	return _monster_wager_public_decision_summary(entry)

func _monster_wager_freezes_game() -> bool:
	for entry_variant in active_monster_wagers:
		if entry_variant is Dictionary and not bool((entry_variant as Dictionary).get("resolved", false)):
			return true
	return false

func _monster_wager_forced_side(entry: Dictionary, player_index: int) -> String:
	var preferred := str(_ai_runtime_call("_ai_monster_wager_side", [player_index, entry]))
	if preferred != "":
		return preferred
	var best_side := ""
	var best_damage := -999
	for competitor_variant in _monster_wager_competitors(entry):
		var competitor := competitor_variant as Dictionary
		var side := String(competitor.get("side", ""))
		var damage := _monster_wager_damage_for_side(entry, side)
		if best_side == "" or damage > best_damage:
			best_side = side
			best_damage = damage
	return best_side

func _force_monster_wager_missing_bets(wager_id: int, reason: String) -> void:
	var index := _monster_wager_entry_index_by_id(wager_id)
	if index < 0:
		return
	for player_index in range(players.size()):
		index = _monster_wager_entry_index_by_id(wager_id)
		if index < 0:
			return
		var entry: Dictionary = active_monster_wagers[index]
		if _monster_wager_player_side(entry, player_index) != "":
			continue
		var side := _monster_wager_forced_side(entry, player_index)
		if side == "":
			continue
		var base_percent := _monster_wager_base_percent(entry)
		if _place_monster_wager_percent(wager_id, side, base_percent, player_index, true):
			_log("怪兽赌局#%d：%s未在窗口内手动下注，系统按%s强制押底注%d%%。" % [
				wager_id,
				_player_name(player_index),
				reason,
				base_percent,
			])

func _try_finish_monster_wager_if_ready(wager_id: int) -> bool:
	var index := _monster_wager_entry_index_by_id(wager_id)
	if index < 0:
		return false
	var entry: Dictionary = active_monster_wagers[index]
	if not _monster_wager_all_players_decided(entry):
		return false
	return _settle_monster_wager_at_index(index, "全员已下注")

func _open_monster_wager_for_pair(slot_a: int, slot_b: int, context: String = "怪兽遭遇", pending_attack: Dictionary = {}) -> int:
	if slot_a < 0 or slot_a >= auto_monsters.size() or slot_b < 0 or slot_b >= auto_monsters.size() or slot_a == slot_b:
		return -1
	if _first_run_should_defer_monster_wager():
		return -1
	var existing_index := _active_monster_wager_index_for_pair(slot_a, slot_b)
	if existing_index >= 0:
		var existing: Dictionary = active_monster_wagers[existing_index]
		return int(existing.get("wager_id", -1))
	var competitors := _monster_wager_competitors_for_pair(slot_a, slot_b)
	if competitors.size() < 2:
		return -1
	var actor_a: Dictionary = auto_monsters[slot_a]
	var actor_b: Dictionary = auto_monsters[slot_b]
	if bool(actor_a.get("down", false)) or bool(actor_b.get("down", false)):
		return -1
	monster_wager_sequence += 1
	var pair_key := _monster_wager_key_for_competitors(competitors)
	var base_percent := rng.randi_range(MONSTER_WAGER_MIN_BASE_PERCENT, MONSTER_WAGER_MAX_BASE_PERCENT)
	var entry := {
		"wager_id": monster_wager_sequence,
		"pair_key": pair_key,
		"base_percent": base_percent,
		"competitors": competitors.duplicate(true),
		"monster_a_uid": int(actor_a.get("uid", 0)),
		"monster_b_uid": int(actor_b.get("uid", 0)),
		"monster_a_slot": slot_a,
		"monster_b_slot": slot_b,
		"monster_a_name": String(actor_a.get("name", "怪兽A")),
		"monster_b_name": String(actor_b.get("name", "怪兽B")),
		"damage_a": 0,
		"damage_b": 0,
		"bets": {},
		"public_bets": [],
		"public_card_bid_pool": public_card_bid_monster_wager_pool,
		"started_at": game_time,
		"remaining_seconds": _ruleset_timing_seconds(&"monster_wager_default_seconds"),
		"seconds_total": _ruleset_timing_seconds(&"monster_wager_default_seconds"),
		"context": context,
		"pending_attack": pending_attack.duplicate(true),
		"battle_resolved": pending_attack.is_empty(),
		"resolved": false,
	}
	for competitor_variant in competitors:
		var competitor := competitor_variant as Dictionary
		entry["damage_%s" % String(competitor.get("side", ""))] = 0
	active_monster_wagers.append(entry)
	var carried_card_bid_pool := public_card_bid_monster_wager_pool
	public_card_bid_monster_wager_pool = 0
	_log("公开怪兽赌局#%d开启：%s，整局冻结%.0f秒内强制下注；本局统一底注%d%%，身份、方向、百分比和金额全部公开，押中者平分总奖池。" % [
		monster_wager_sequence,
		_monster_wager_matchup_text(entry),
		_ruleset_timing_seconds(&"monster_wager_default_seconds"),
		base_percent,
	])
	if carried_card_bid_pool > 0:
		_log("卡牌组竞价公共池¥%d已注入本场有效怪兽赌局；贡献组来源保持匿名。" % carried_card_bid_pool)
	_add_map_event_effect("wager", _entity_world_position(actor_a), Color("#fb923c"), "怪兽赌局", 2.8, 180.0, "monster")
	_add_action_callout(
		"怪兽赌局",
		"全场冻结",
		"%s：统一底注%d%%，金额公开，可反推资金线索。" % [_monster_wager_matchup_text(entry), base_percent],
		Color("#fb923c"),
		_entity_world_position(actor_a)
	)
	_ai_runtime_call("_auto_ai_monster_wagers_for_entry", [monster_wager_sequence])
	_try_finish_monster_wager_if_ready(monster_wager_sequence)
	_refresh_ui()
	return monster_wager_sequence

func _record_monster_wager_damage(attacker_slot: int, target_slot: int, damage: int) -> void:
	if damage <= 0:
		return
	var index := _active_monster_wager_index_for_pair(attacker_slot, target_slot)
	if index < 0:
		var opened_id := _open_monster_wager_for_pair(attacker_slot, target_slot, "怪兽交战")
		if opened_id < 0:
			return
		index = _monster_wager_entry_index_by_id(opened_id)
	if index < 0:
		return
	var entry: Dictionary = active_monster_wagers[index]
	var side := _monster_wager_side_for_slot(entry, attacker_slot)
	if side == "":
		return
	var damage_key := "damage_%s" % side
	entry[damage_key] = int(entry.get(damage_key, 0)) + damage
	var competitors := _monster_wager_competitors(entry)
	for i in range(competitors.size()):
		var competitor := competitors[i] as Dictionary
		if String(competitor.get("side", "")) == side:
			competitor["damage"] = int(competitor.get("damage", 0)) + damage
			competitors[i] = competitor
			break
	entry["competitors"] = competitors
	active_monster_wagers[index] = entry

func _place_monster_wager_percent(wager_id: int, side: String, stake_percent: int = 0, player_index: int = -1, forced: bool = false, metadata: Dictionary = {}) -> bool:
	if player_index < 0:
		player_index = selected_player
	if player_index < 0 or player_index >= players.size():
		return false
	var index := _monster_wager_entry_index_by_id(wager_id)
	if index < 0:
		return false
	var entry: Dictionary = active_monster_wagers[index]
	var percent := _monster_wager_clamped_percent(entry, stake_percent if stake_percent > 0 else _monster_wager_base_percent(entry))
	var stake := _monster_wager_amount_for_percent(player_index, percent)
	var enriched_metadata := metadata.duplicate(true)
	enriched_metadata["stake_percent"] = percent
	return _place_monster_wager(wager_id, side, stake, player_index, forced, enriched_metadata)

func _place_monster_wager(wager_id: int, side: String, stake: int = 0, player_index: int = -1, forced: bool = false, metadata: Dictionary = {}) -> bool:
	side = side.to_lower()
	if player_index < 0:
		player_index = selected_player
	if player_index < 0 or player_index >= players.size() or stake < 0:
		return false
	var index := _monster_wager_entry_index_by_id(wager_id)
	if index < 0:
		return false
	var entry: Dictionary = (active_monster_wagers[index] as Dictionary).duplicate(true)
	if _monster_wager_side_label(entry, side) == "平局":
		return false
	var player_cash := int((players[player_index] as Dictionary).get("cash", 0))
	var base_percent := _monster_wager_base_percent(entry)
	var stake_percent := int(metadata.get("stake_percent", metadata.get("percent", _monster_wager_percent_for_amount(player_index, stake))))
	stake_percent = _monster_wager_clamped_percent(entry, stake_percent if stake_percent > 0 else base_percent)
	stake = _monster_wager_amount_for_percent(player_index, stake_percent)
	var bets: Dictionary = (entry.get("bets", {}) as Dictionary).duplicate(true)
	var player_key := str(player_index)
	var bet := {}
	if bets.has(player_key) and bets[player_key] is Dictionary:
		bet = (bets[player_key] as Dictionary).duplicate(true)
	var previous_side := String(bet.get("side", ""))
	if previous_side != "":
		return false
	players[player_index]["cash"] = player_cash - stake
	bet["player_index"] = player_index
	bet["side"] = side
	bet["stake"] = stake
	bet["stake_percent"] = stake_percent
	bet["forced"] = forced
	bet["last_time"] = game_time
	for key_variant in metadata.keys():
		var key := String(key_variant)
		if key.begins_with("ai_wager_"):
			bet[key] = metadata[key_variant]
	bets[player_key] = bet
	var public_bets: Array = (entry.get("public_bets", []) as Array).duplicate(true)
	public_bets.append({
		"player_index": player_index,
		"side": side,
		"stake": stake,
		"stake_percent": stake_percent,
		"forced": forced,
		"time": game_time,
	})
	while public_bets.size() > MONSTER_WAGER_HISTORY_LIMIT:
		public_bets.pop_front()
	entry["bets"] = bets
	entry["public_bets"] = public_bets
	active_monster_wagers[index] = entry
	_record_player_economic_event(
		player_index,
		"怪兽赌局",
		"强制底注" if forced else "公开下注",
		-stake,
		"赌局#%d：%s%d%%（¥%d）支持%s；身份、方向、百分比和金额都公开。" % [wager_id, "强制底注" if forced else "公开下注", stake_percent, stake, _monster_wager_side_label(entry, side)]
	)
	_record_player_cash_snapshot(player_index)
	_log("公开下注：%s在怪兽赌局#%d%s%d%%（¥%d）支持%s。" % [
		_player_name(player_index),
		wager_id,
		"被系统强制押底注" if forced else "下注",
		stake_percent,
		stake,
		_monster_wager_side_label(entry, side),
	])
	_try_finish_monster_wager_if_ready(wager_id)
	_refresh_ui()
	return true

func _monster_wager_actor_expected_damage_score(actor: Dictionary) -> int:
	var actions := _auto_monster_actions(actor)
	var weights := _auto_monster_action_weights(actor, _has_destroyed_district())
	var total := _weight_total(weights)
	if actions.is_empty() or total <= 0:
		return maxi(1, int(actor.get("rank", 1)))
	var score := 0.0
	for i in range(actions.size()):
		var weight := int(weights[i]) if i < weights.size() else 0
		if weight <= 0:
			continue
		var action: Dictionary = actions[i]
		var action_damage := int(action.get("damage", action.get("area_damage", 0)))
		action_damage += int(round(float(action.get("knockback", 0.0)) / 160.0))
		action_damage += int(action.get("resource_damage", 0))
		score += float(maxi(0, action_damage)) * float(weight)
	return maxi(1, int(round(score / float(total))))

func _update_monster_wagers(delta: float) -> void:
	if active_monster_wagers.is_empty():
		return
	for i in range(active_monster_wagers.size() - 1, -1, -1):
		var entry: Dictionary = active_monster_wagers[i]
		if bool(entry.get("resolved", false)):
			active_monster_wagers.remove_at(i)
			continue
		var remaining := maxf(0.0, float(entry.get("remaining_seconds", _ruleset_timing_seconds(&"monster_wager_default_seconds"))) - delta)
		entry["remaining_seconds"] = remaining
		active_monster_wagers[i] = entry
		if remaining <= 0.0:
			_force_monster_wager_missing_bets(int(entry.get("wager_id", -1)), "倒计时结束")
			_settle_monster_wager(int(entry.get("wager_id", -1)), "倒计时结束")
			continue
		var active_sides := 0
		for competitor_variant in _monster_wager_competitors(entry):
			var competitor := competitor_variant as Dictionary
			if _monster_wager_side_active(entry, String(competitor.get("side", ""))):
				active_sides += 1
		if active_sides < 2:
			_force_monster_wager_missing_bets(int(entry.get("wager_id", -1)), "怪兽离场")
			_settle_monster_wager(int(entry.get("wager_id", -1)), "怪兽离场")

func _settle_monster_wager(wager_id: int, reason: String = "手动结算") -> bool:
	var index := _monster_wager_entry_index_by_id(wager_id)
	if index < 0:
		return false
	return _settle_monster_wager_at_index(index, reason)

func _resolve_monster_wager_pending_battle_at_index(index: int) -> void:
	if index < 0 or index >= active_monster_wagers.size():
		return
	var entry: Dictionary = (active_monster_wagers[index] as Dictionary).duplicate(true)
	if bool(entry.get("battle_resolved", false)):
		return
	entry["battle_resolved"] = true
	active_monster_wagers[index] = entry
	var pending: Dictionary = entry.get("pending_attack", {}) as Dictionary
	if pending.is_empty():
		return
	var attacker_slot := int(pending.get("attacker_slot", -1))
	var target_slot := int(pending.get("target_slot", -1))
	var action: Dictionary = pending.get("action", {}) as Dictionary
	var context := String(pending.get("context", "怪兽赌局开战"))
	if attacker_slot < 0 or target_slot < 0 or action.is_empty():
		return
	_auto_monster_use_action_on_other(attacker_slot, target_slot, action, context, false)

func _settle_monster_wager_at_index(index: int, reason: String) -> bool:
	if index < 0 or index >= active_monster_wagers.size():
		return false
	_resolve_monster_wager_pending_battle_at_index(index)
	if index < 0 or index >= active_monster_wagers.size():
		return false
	var entry: Dictionary = (active_monster_wagers[index] as Dictionary).duplicate(true)
	var competitors := _monster_wager_competitors(entry)
	var winner_sides := []
	var best_damage := -1
	for competitor_variant in competitors:
		var competitor := competitor_variant as Dictionary
		var side := String(competitor.get("side", ""))
		var damage := _monster_wager_damage_for_side(entry, side)
		if damage > best_damage:
			best_damage = damage
			winner_sides = [side]
		elif damage == best_damage:
			winner_sides.append(side)
	var bets: Dictionary = entry.get("bets", {}) as Dictionary
	var public_card_bid_pool := maxi(0, int(entry.get("public_card_bid_pool", 0)))
	var total_pot := public_card_bid_pool
	var valid_single_winner := best_damage > 0 and winner_sides.size() == 1
	var winning_bets := []
	for key_variant in bets.keys():
		var bet_variant: Variant = bets[key_variant]
		if not (bet_variant is Dictionary):
			continue
		var bet := bet_variant as Dictionary
		var stake := int(bet.get("stake", 0))
		if stake <= 0:
			continue
		total_pot += stake
		if valid_single_winner and winner_sides.has(String(bet.get("side", ""))):
			winning_bets.append(bet)
	var public_outcomes := []
	if not valid_single_winner:
		public_card_bid_monster_wager_pool += public_card_bid_pool
	var remaining_payout := total_pot
	var winning_paid := 0
	for key_variant in bets.keys():
		var bet_variant: Variant = bets[key_variant]
		if not (bet_variant is Dictionary):
			continue
		var bet := bet_variant as Dictionary
		var player_index := int(bet.get("player_index", int(String(key_variant))))
		if player_index < 0 or player_index >= players.size():
			continue
		var stake := int(bet.get("stake", 0))
		if stake <= 0:
			continue
		var side := String(bet.get("side", ""))
		if not valid_single_winner:
			players[player_index]["cash"] = int((players[player_index] as Dictionary).get("cash", 0)) + stake
			_record_player_economic_event(player_index, "怪兽赌局", "平局退款", stake, "赌局#%d没有唯一最高伤害方，玩家下注退回；卡牌竞价公共池保留。" % int(entry.get("wager_id", -1)))
			_record_player_cash_snapshot(player_index)
			public_outcomes.append("%s退款¥%d" % [_player_name(player_index), stake])
		elif winner_sides.has(side) and not winning_bets.is_empty():
			winning_paid += 1
			var payout := int(floor(float(total_pot) / float(winning_bets.size())))
			if winning_paid >= winning_bets.size():
				payout = remaining_payout
			remaining_payout -= payout
			players[player_index]["cash"] = int((players[player_index] as Dictionary).get("cash", 0)) + payout
			_record_player_economic_event(player_index, "怪兽赌局", "赌局命中", payout, "赌局#%d：%s进入最高伤害方，与其他命中玩家平分总奖池¥%d。" % [
				int(entry.get("wager_id", -1)),
				_monster_wager_side_label(entry, side),
				total_pot,
			])
			_record_player_cash_snapshot(player_index)
			public_outcomes.append("%s命中%s 分得¥%d" % [_player_name(player_index), _monster_wager_side_label(entry, side), payout])
		else:
			_record_player_economic_event(player_index, "怪兽赌局", "赌局落空", 0, "赌局#%d：%s未进入最高伤害方，下注进入总奖池。" % [
				int(entry.get("wager_id", -1)),
				_monster_wager_side_label(entry, side),
			])
			public_outcomes.append("%s落空" % _player_name(player_index))
	if valid_single_winner and winning_bets.is_empty() and total_pot > 0:
		public_card_bid_monster_wager_pool += total_pot
		public_outcomes.append("无人命中，奖池¥%d保留" % total_pot)
	entry["resolved"] = true
	entry["resolved_at"] = game_time
	entry["resolution_reason"] = reason
	entry["winner_sides"] = winner_sides if valid_single_winner else []
	entry["winner_side"] = String(winner_sides[0]) if valid_single_winner else ""
	var winner_labels := []
	for winner_side_variant in (winner_sides if valid_single_winner else []):
		winner_labels.append(_monster_wager_side_label(entry, String(winner_side_variant)))
	entry["winner_label"] = _limited_name_list(winner_labels, 4, "无胜方")
	entry["total_pot"] = total_pot
	entry["public_card_bid_pool_retained"] = public_card_bid_pool if not valid_single_winner else (total_pot if winning_bets.is_empty() else 0)
	entry["public_outcomes"] = public_outcomes
	resolved_monster_wager_history.append(entry)
	while resolved_monster_wager_history.size() > MONSTER_WAGER_HISTORY_LIMIT:
		resolved_monster_wager_history.pop_front()
	active_monster_wagers.remove_at(index)
	var result_text := "%s最高伤害" % String(entry.get("winner_label", "无胜方"))
	_log("怪兽赌局#%d结算：%s（%s，总奖池¥%d，%s）。%s" % [
		int(entry.get("wager_id", -1)),
		result_text,
		_monster_wager_damage_score_text(entry),
		total_pot,
		reason,
		"；".join(public_outcomes) if not public_outcomes.is_empty() else "无人下注",
	])
	var anchor_position := Vector2.ZERO
	for competitor_variant in _monster_wager_competitors(entry):
		var competitor := competitor_variant as Dictionary
		var slot := _monster_wager_current_slot(entry, String(competitor.get("side", "")))
		if slot >= 0 and slot < auto_monsters.size():
			anchor_position = _entity_world_position(auto_monsters[slot] as Dictionary)
			break
	_add_action_callout(
		"怪兽赌局",
		"结算",
		"%s｜%s" % [result_text, _monster_wager_damage_score_text(entry)],
		Color("#fde68a"),
		anchor_position
	)
	_refresh_ui()
	return true

func _auto_monster_use_action_on_other(slot: int, target_slot: int, action: Dictionary, context: String, allow_wager: bool = true) -> bool:
	if slot < 0 or slot >= auto_monsters.size() or target_slot < 0 or target_slot >= auto_monsters.size():
		return false
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	if bool(actor.get("down", false)) or bool(target.get("down", false)):
		return false
	var distance := _wrapped_distance(_entity_world_position(actor), _entity_world_position(target))
	var range_limit: float = float(action.get("range", MELEE_RANGE_METERS))
	if range_limit <= 0.0:
		range_limit = MELEE_RANGE_METERS
	if distance > range_limit:
		return false
	var action_name := String(action.get("name", "攻击"))
	var source := "%s·%s" % [String(actor.get("name", "怪兽")), action_name]
	var district_index := int(actor.get("position", -1))
	var resource_text := ""
	var matches := _monster_resource_matches(actor, district_index)
	if not matches.is_empty():
		resource_text = "，争夺资源：%s" % _limited_name_list(matches, 3, "未知资源")
	if allow_wager and _active_monster_wager_index_for_pair(slot, target_slot) < 0:
		var pending_attack := {
			"attacker_slot": slot,
			"target_slot": target_slot,
			"action": action.duplicate(true),
			"context": context,
		}
		return _open_monster_wager_for_pair(slot, target_slot, context, pending_attack) >= 0
	_log("怪%d·%s在%s与怪%d·%s相遇，%s使用%s%s。" % [
		slot + 1,
		String(actor.get("name", "怪兽")),
		districts[district_index]["name"] if district_index >= 0 and district_index < districts.size() else "未知区域",
		target_slot + 1,
		String(target.get("name", "怪兽")),
		context,
		action_name,
		resource_text,
	])
	_add_action_callout(
		"怪%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
		action_name,
		"遭遇怪%d·%s，造成%d伤害%s。" % [
			target_slot + 1,
			String(target.get("name", "怪兽")),
			int(action.get("damage", 0)),
			"，击退%s" % _meters_text(float(action.get("knockback", 0.0))) if float(action.get("knockback", 0.0)) > 0.5 else "",
		],
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	_add_monster_attack_effect(_entity_world_position(actor), _entity_world_position(target), action_name, range_limit, _auto_monster_color(slot), range_limit > MELEE_RANGE_METERS, _monster_action_animation_profile(String(actor.get("name", "怪兽")), action))
	var outgoing_damage := int(action.get("damage", 0)) + _auto_monster_damage_bonus_from_passives(slot)
	var dealt_damage := _auto_monster_take_damage(target_slot, outgoing_damage, source, slot)
	_record_monster_wager_damage(slot, target_slot, dealt_damage)
	if target_slot < auto_monsters.size() and _is_auto_ember_ring_energy_active(target_slot) and range_limit <= MELEE_RANGE_METERS:
		_maybe_announce_auto_ember_ring_energy(target_slot)
		var counter_damage := _auto_monster_take_damage(slot, EMBER_RING_ENERGY_FLAME_DAMAGE, "%s星焰反焰" % action_name, target_slot)
		_record_monster_wager_damage(target_slot, slot, counter_damage)
	var knockback_model := _monster_knockback_model(action, actor)
	var knockback := float(knockback_model.get("knockback_m", action.get("knockback", 0.0)))
	if knockback > 0.5 and target_slot < auto_monsters.size():
		_knockback_auto_monster_from_actor(target_slot, slot, knockback, action_name, float(knockback_model.get("knockback_duration_seconds", 0.5)))
	return true

func _resolve_auto_monster_encounter(slot: int, context: String) -> bool:
	var target_slot := _nearest_other_auto_monster_slot(slot)
	if target_slot < 0:
		return false
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	var distance := _wrapped_distance(_entity_world_position(actor), _entity_world_position(target))
	if distance > AUTO_MONSTER_ENCOUNTER_RANGE_METERS:
		return false
	var action := _auto_monster_brawl_action(slot, target_slot)
	if action.is_empty():
		return false
	return _auto_monster_use_action_on_other(slot, target_slot, action, context)

func _nearest_other_auto_monster_slot(slot: int) -> int:
	if slot < 0 or slot >= auto_monsters.size():
		return -1
	var actor: Dictionary = auto_monsters[slot]
	var best_slot := -1
	var best_distance := INF
	for i in range(auto_monsters.size()):
		if i == slot:
			continue
		var other: Dictionary = auto_monsters[i]
		if bool(other.get("down", false)):
			continue
		var distance := _wrapped_distance(_entity_world_position(actor), _entity_world_position(other))
		if distance < best_distance:
			best_distance = distance
			best_slot = i
	return best_slot

func _auto_monster_take_damage(slot: int, damage: int, source: String, _source_slot: int) -> int:
	if slot < 0 or slot >= auto_monsters.size() or damage <= 0:
		return 0
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("down", false)):
		return 0
	var remaining := damage
	var armor := int(actor.get("armor", 0))
	if armor > 0:
		var absorbed: int = min(armor, remaining)
		actor["armor"] = armor - absorbed
		remaining -= absorbed
		_log("%s护甲抵消%d点%s伤害。" % [String(actor.get("name", "怪兽")), absorbed, source])
	auto_monsters[slot] = actor
	_maybe_announce_auto_blue_lancer_reactive_armor(slot)
	actor = auto_monsters[slot]
	if remaining > 0 and _is_auto_blue_lancer_reactive_armor_active(slot):
		var armor_reduced: int = min(remaining, BLUE_LANCER_REACTIVE_DAMAGE_REDUCTION)
		remaining = max(0, remaining - armor_reduced)
		_log("复仇之铠抵消%d点%s伤害。" % [armor_reduced, source])
	var hp_before := maxi(0, int(actor.get("hp", 0)))
	var hp_damage: int = mini(remaining, hp_before)
	actor["hp"] = hp_before - hp_damage
	_log("%s对怪%d·%s造成%d伤害。" % [
		source,
		slot + 1,
		String(actor.get("name", "怪兽")),
		hp_damage,
	])
	auto_monsters[slot] = actor
	if hp_damage > 0:
		_apply_owner_damage_cash_loss(slot, hp_damage, source)
		actor = auto_monsters[slot]
	_maybe_announce_auto_ember_ring_energy(slot)
	actor = auto_monsters[slot]
	if int(actor.get("hp", 0)) <= 0:
		actor["hp"] = 0
		if _try_start_auto_monster_revival(slot, source, actor):
			return hp_damage
		actor["down"] = true
		_invalidate_bound_monster_skills(int(actor.get("uid", 0)))
		_log("怪%d·%s倒地，之后停止自动行动。" % [slot + 1, String(actor.get("name", "怪兽"))])
		_add_action_callout(
			"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
			"倒地",
			"%s造成致命伤害，停止自动行动。" % source,
			Color("#94a3b8"),
			_entity_world_position(actor)
		)
	auto_monsters[slot] = actor
	return hp_damage

func _knockback_auto_monster_from_actor(target_slot: int, source_slot: int, distance_m: float, source: String, duration_seconds: float = 0.5) -> void:
	if target_slot < 0 or target_slot >= auto_monsters.size() or source_slot < 0 or source_slot >= auto_monsters.size():
		return
	var target: Dictionary = auto_monsters[target_slot]
	var source_actor: Dictionary = auto_monsters[source_slot]
	var before := _entity_world_position(target)
	var offset := _wrapped_delta(_entity_world_position(source_actor), before)
	if offset.length() <= 0.01:
		offset = Vector2(1.0, 0.0).rotated(rng.randf_range(0.0, TAU))
	var target_position := before + offset.normalized() * distance_m
	var knockback_speed_mps := distance_m / maxf(0.05, duration_seconds)
	var moved := _start_entity_linear_motion(
		target,
		target_position,
		knockback_speed_mps,
		source,
		_auto_monster_movement_mode(target),
		distance_m,
		"knockback"
	)
	if moved > 0.5:
		_add_visual_trail(before, target.get("linear_move_target_position", target_position), _auto_monster_color(target_slot), "击退")
		_log("%s击退怪%d·%s %s；将以%s/秒线性位移。" % [
			source,
			target_slot + 1,
			String(target.get("name", "怪兽")),
			_meters_text(moved),
			_meters_text(knockback_speed_mps),
		])
		target["linear_move_arrival_damage"] = _auto_monster_collision_damage(target)
		target["linear_move_arrival_damage_source"] = "%s击退落点冲击" % source
		_add_action_callout(
			"击退冲击",
			source,
			"怪%d·%s被击飞%s；沿途和落点会按线性移动结算破坏。" % [
				target_slot + 1,
				String(target.get("name", "怪兽")),
				_meters_text(moved),
			],
			Color("#fb7185"),
			before
		)
	auto_monsters[target_slot] = target

func _monster_tick() -> void:
	_auto_monster_movement_tick()

func _special_monster_tick() -> void:
	_auto_special_monster_tick()

func _auto_monster_target_weight_parts(actor: Dictionary, index: int) -> Dictionary:
	var parts := {
		"base": 0,
		"city": 0,
		"competition": 0,
		"warehouse": 0,
		"resource": 0,
		"distance": 0,
		"miasma": 0,
		"monster": 0,
	}
	if index < 0 or index >= districts.size():
		return parts
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return parts
	parts["base"] = MONSTER_TARGET_BASE_WEIGHT
	var city := _district_city(index)
	if _city_is_active(city):
		parts["city"] = MONSTER_TARGET_CITY_BONUS + (city.get("products", []) as Array).size() * MONSTER_TARGET_PRODUCT_WEIGHT
		parts["competition"] = int(city.get("competition_matches", 0)) * MONSTER_TARGET_COMPETITION_WEIGHT
		parts["warehouse"] = _city_warehouse_stockpile_pressure(city)
	parts["resource"] = _monster_resource_match_score(actor, index) * MONSTER_TARGET_RESOURCE_WEIGHT
	parts["distance"] = max(0, MONSTER_TARGET_DISTANCE_BASE - _entity_distance_to_district(actor, index) * MONSTER_TARGET_DISTANCE_STEP)
	if d["miasma"]:
		parts["miasma"] = MONSTER_TARGET_MIASMA_BONUS
	for other_variant in auto_monsters:
		var other: Dictionary = other_variant
		if other == actor or bool(other.get("down", false)):
			continue
		if int(other.get("position", -1)) == index:
			parts["monster"] = MONSTER_TARGET_RIVAL_BONUS
			break
	return parts

func _auto_monster_target_weight(actor: Dictionary, index: int) -> int:
	if index < 0 or index >= districts.size():
		return 0
	if districts[index]["destroyed"]:
		return 0
	return max(1, _weight_part_total(_auto_monster_target_weight_parts(actor, index)))

func _auto_monster_target_candidates(actor: Dictionary) -> Array:
	var result := []
	for i in range(districts.size()):
		if districts[i]["destroyed"]:
			continue
		var weight := _auto_monster_target_weight(actor, i)
		if weight > 0:
			result.append({"index": i, "weight": weight})
	return result

func _weighted_auto_monster_target(actor: Dictionary) -> int:
	var weights := []
	var candidates := _auto_monster_target_candidates(actor)
	for entry in candidates:
		weights.append(int(entry["weight"]))
	var picked := _weighted_pick_index(weights)
	if picked < 0:
		return -1
	return int(candidates[picked]["index"])

func _auto_monster_target_probability_text(actor: Dictionary, index: int) -> String:
	if index < 0 or index >= districts.size():
		return "无"
	if districts[index]["destroyed"]:
		return "已排除"
	var candidates := _auto_monster_target_candidates(actor)
	var total := 0
	for entry in candidates:
		total += int(entry["weight"])
	if total <= 0:
		return "无可选目标"
	var weight := _auto_monster_target_weight(actor, index)
	return "%s（权重%d/%d）" % [_probability_text(weight, total), weight, total]

func _auto_monster_target_reason(actor: Dictionary, index: int) -> String:
	return "%s，主因:%s" % [
		_auto_monster_target_probability_text(actor, index),
		_auto_monster_target_factor_summary(actor, index),
	]

func _auto_monster_target_factor_summary(actor: Dictionary, index: int) -> String:
	if index < 0 or index >= districts.size():
		return "无"
	if districts[index]["destroyed"]:
		return "已破坏，已排除"
	var parts := _auto_monster_target_weight_parts(actor, index)
	var candidates := [
		{"name": "距离", "value": int(parts["distance"])},
		{"name": "城市经营", "value": int(parts["city"])},
		{"name": "商品竞争", "value": int(parts["competition"])},
		{"name": "匿名仓储", "value": int(parts["warehouse"])},
		{"name": "资源偏好", "value": int(parts["resource"])},
		{"name": "瘴气", "value": int(parts["miasma"])},
		{"name": "同场怪兽", "value": int(parts["monster"])},
	]
	var picked := []
	while picked.size() < 3 and not candidates.is_empty():
		var best_pos := -1
		var best_value := 0
		for i in range(candidates.size()):
			var value := int(candidates[i]["value"])
			if value > best_value:
				best_value = value
				best_pos = i
		if best_pos < 0:
			break
		var best: Dictionary = candidates[best_pos]
		picked.append("%s+%d" % [best["name"], best["value"]])
		candidates.remove_at(best_pos)
	if picked.is_empty():
		picked.append("基础+%d" % int(parts["base"]))
	return " / ".join(picked)

func _add_action_callout(actor: String, action: String, detail: String, color: Color, world_position: Vector2, duration: float = ACTION_CALLOUT_DURATION) -> void:
	_world_call(&"_add_action_callout", [actor, action, detail, color, world_position, duration])

func _add_map_event_effect(kind: String, world_position: Vector2, color: Color, label: String = "", duration: float = MAP_EVENT_EFFECT_DURATION, radius_m: float = 70.0, card_style: String = "") -> void:
	_world_call(&"_add_map_event_effect", [kind, world_position, color, label, duration, radius_m, card_style])

func _add_monster_attack_effect(from_position: Vector2, to_position: Vector2, source: String, range_limit_m: float, color: Color, is_ranged: bool = false, action_profile: Dictionary = {}) -> void:
	_world_call(&"_add_monster_attack_effect", [from_position, to_position, source, range_limit_m, color, is_ranged, action_profile])

func _add_visual_trail(from_position: Vector2, to_position: Vector2, color: Color, label: String, duration: float = VISUAL_TRAIL_DURATION, style: String = "movement") -> void:
	_world_call(&"_add_visual_trail", [from_position, to_position, color, label, duration, style])

func _advance_entity_linear_motion(entity: Dictionary, delta_seconds: float) -> Dictionary:
	return _world_call(&"_advance_entity_linear_motion", [entity, delta_seconds])

func _ai_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	return _world_call(&"_ai_runtime_call", [method_name, arguments])

func _append_unique_district_index(result: Array, index: int) -> void:
	_world_call(&"_append_unique_district_index", [result, index])

func _apply_product_market_boon(product_name: String, growth_multiplier: float, route_flow_multiplier: float, turns: int, source: String, persistent: bool = false, duration_seconds: float = -1.0) -> bool:
	return _product_market_runtime_controller.apply_product_market_boon(product_name, growth_multiplier, route_flow_multiplier, turns, source, persistent, duration_seconds) if _product_market_runtime_controller != null else false

func _apply_role_monster_upgrade_cash(player_index: int, monster_name: String, old_rank: int, new_rank: int, world_position: Vector2) -> int:
	return _world_call(&"_apply_role_monster_upgrade_cash", [player_index, monster_name, old_rank, new_rank, world_position])

func _auto_monster_action_probability_text(actor: Dictionary, action_index: int, weights: Array, total: int, any_destroyed: bool) -> String:
	return _world_call(&"_auto_monster_action_probability_text", [actor, action_index, weights, total, any_destroyed])

func _auto_monster_color(slot: int) -> Color:
	return _world_call(&"_auto_monster_color", [slot])

func _auto_monster_movement_speed_mps(actor: Dictionary, target_index: int, action_speed_mps: float = -1.0) -> float:
	return _world_call(&"_auto_monster_movement_speed_mps", [actor, target_index, action_speed_mps])

func _can_summon_monster_card_at_district(skill: Dictionary, district_index: int) -> bool:
	return _world_call(&"_can_summon_monster_card_at_district", [skill, district_index])

func _catalog_action_weights(actions: Array, any_destroyed: bool) -> Array:
	return _world_call(&"_catalog_action_weights", [actions, any_destroyed])

func _catalog_actions(index: int) -> Array:
	return _world_call(&"_catalog_actions", [index])

func _catalog_entry(index: int) -> Dictionary:
	return _world_call(&"_catalog_entry", [index])

func _catalog_move_speed(index: int) -> float:
	return _world_call(&"_catalog_move_speed", [index])

func _catalog_size() -> int:
	return _world_call(&"_catalog_size", [])

func _city_demand_names(city: Dictionary) -> Array:
	return _world_call(&"_city_demand_names", [city])

func _city_is_active(city: Dictionary) -> bool:
	return _world_call(&"_city_is_active", [city])

func _city_product_names(city: Dictionary) -> Array:
	return _world_call(&"_city_product_names", [city])

func _city_warehouse_stockpile_pressure(city: Dictionary) -> int:
	return _world_call(&"_city_warehouse_stockpile_pressure", [city])

func _clear_entity_linear_motion(entity: Dictionary) -> void:
	_world_call(&"_clear_entity_linear_motion", [entity])

func _compact_card_list(cards: Array, limit: int) -> String:
	return _world_call(&"_compact_card_list", [cards, limit])

func _complete_scenario_signal(signal_id: String, public_text: String, snapshot_key: String = "", focus_target: String = "") -> bool:
	return _world_call(&"_complete_scenario_signal", [signal_id, public_text, snapshot_key, focus_target])

func _damage_district(index: int, amount: int, source: String) -> void:
	if _region_infrastructure_world_bridge == null or not _region_infrastructure_world_bridge.has_method("submit_legacy_index_unit_damage"):
		push_error("Monster region damage rejected: RegionInfrastructureWorldBridge is missing.")
		return
	_region_infrastructure_world_bridge.call("submit_legacy_index_unit_damage", index, amount, "monster", source, game_time)

func _district_at_point(point: Vector2) -> int:
	return _world_call(&"_district_at_point", [point])

func _district_center(index: int) -> Vector2:
	return _world_call(&"_district_center", [index])

func _district_city(index: int) -> Dictionary:
	return _world_call(&"_district_city", [index])

func _districts_in_radius(center: Vector2, radius_m: float, include_destroyed := false) -> Array:
	return _world_call(&"_districts_in_radius", [center, radius_m, include_destroyed])

func _duration_short_text(seconds: float) -> String:
	return _world_call(&"_duration_short_text", [seconds])

func _entity_distance_to_district(entity: Dictionary, district_index: int) -> float:
	return _world_call(&"_entity_distance_to_district", [entity, district_index])

func _entity_has_linear_motion(entity: Dictionary) -> bool:
	return _world_call(&"_entity_has_linear_motion", [entity])

func _entity_world_position(entity: Dictionary) -> Vector2:
	return _world_call(&"_entity_world_position", [entity])

func _first_empty_or_new_slot(player: Dictionary) -> int:
	return _world_call(&"_first_empty_or_new_slot", [player])

func _first_run_should_defer_monster_wager() -> bool:
	return _world_call(&"_first_run_should_defer_monster_wager", [])

func _has_destroyed_district() -> bool:
	return _world_call(&"_has_destroyed_district", [])

func _level_text(rank: int) -> String:
	return _world_call(&"_level_text", [rank])

func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
	return _world_call(&"_limited_name_list", [names, limit, empty_text])

func _log(message: String) -> void:
	_world_call(&"_log", [message])

func _make_skill(skill_name: String) -> Dictionary:
	return _world_call(&"_make_skill", [skill_name])

func _meters_text(value: float) -> String:
	return _world_call(&"_meters_text", [value])

func _monster_action_animation_profile(_monster_name: String, action: Dictionary, _action_index: int = -1) -> Dictionary:
	return _world_call(&"_monster_action_animation_profile", [_monster_name, action, _action_index])

func _monster_card_duration_text(skill: Dictionary, compact: bool = false) -> String:
	return _world_call(&"_monster_card_duration_text", [skill, compact])

func _monster_card_name(index: int, rank: int = 1) -> String:
	return _world_call(&"_monster_card_name", [index, rank])

func _monster_card_region_text(skill: Dictionary, compact: bool = false) -> String:
	return _world_call(&"_monster_card_region_text", [skill, compact])

func _monster_catalog_index_by_name(monster_name: String) -> int:
	return _world_call(&"_monster_catalog_index_by_name", [monster_name])

func _monster_knockback_model(action_or_skill: Dictionary, actor: Dictionary = {}) -> Dictionary:
	return _world_call(&"_monster_knockback_model", [action_or_skill, actor])

func _monster_technique_card_name(monster_name: String, action_index: int, rank: int = 1) -> String:
	return _world_call(&"_monster_technique_card_name", [monster_name, action_index, rank])

func _monster_wager_percent_for_amount(player_index: int, amount: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var player_cash := maxi(0, int((players[player_index] as Dictionary).get("cash", 0)))
	if player_cash <= 0:
		return 0
	return clampi(int(round(float(maxi(0, amount)) * 100.0 / float(player_cash))), 0, 100)

func _nearest_district_to(point: Vector2) -> int:
	return _world_call(&"_nearest_district_to", [point])

func _owner_damage_cash_total_for_rank(rank: int) -> int:
	return _world_call(&"_owner_damage_cash_total_for_rank", [rank])

func _player_name(player_index: int) -> String:
	return _world_call(&"_player_name", [player_index])

func _player_role_card_for_index(player_index: int) -> Dictionary:
	return _world_call(&"_player_role_card_for_index", [player_index])

func _preset_int(key: String) -> int:
	return _world_call(&"_preset_int", [key])

func _probability_text(weight: int, total: int) -> String:
	return _world_call(&"_probability_text", [weight, total])

func _pulse_district(index: int, color: Color) -> void:
	_world_call(&"_pulse_district", [index, color])

func _ranked_action_weights(source_weights: Array, rank: int) -> Array:
	return _world_call(&"_ranked_action_weights", [source_weights, rank])

func _record_player_cash_snapshot(player_index: int) -> void:
	_world_call(&"_record_player_cash_snapshot", [player_index])

func _record_player_economic_event(player_index: int, kind: String, label: String, amount: int, detail: String = "") -> void:
	_world_call(&"_record_player_economic_event", [player_index, kind, label, amount, detail])

func _refresh_product_market_prices() -> void:
	if _product_market_runtime_controller != null:
		_product_market_runtime_controller.refresh_prices()

func _refresh_ui() -> void:
	_world_call(&"_refresh_ui", [])

func _ruleset_timing_seconds(rule_id: StringName) -> float:
	return _world_call(&"_ruleset_timing_seconds", [rule_id])

func _skill_rank(skill_name: String) -> int:
	return _card_runtime_catalog_service.rank(skill_name) if _card_runtime_catalog_service != null else 0

func _spherical_lerp_world(from_position: Vector2, to_position: Vector2, weight: float) -> Vector2:
	return _world_call(&"_spherical_lerp_world", [from_position, to_position, weight])

func _start_entity_linear_motion(entity: Dictionary, target_position: Vector2, speed_mps: float, source: String, movement_mode: String = "", max_distance_m: float = -1.0, arrival_action: String = "") -> float:
	return _world_call(&"_start_entity_linear_motion", [entity, target_position, speed_mps, source, movement_mode, max_distance_m, arrival_action])

func _route_network_routes_for_product(product_name: String) -> Array:
	return _route_network_runtime_controller.routes_for_product(product_name) if _route_network_runtime_controller != null else []

func _weight_part_total(parts: Dictionary) -> int:
	return _world_call(&"_weight_part_total", [parts])

func _weight_total(weights: Array) -> int:
	return _world_call(&"_weight_total", [weights])

func _weighted_pick_index(weights: Array) -> int:
	return _world_call(&"_weighted_pick_index", [weights])

func _wrapped_delta(from_position: Vector2, to_position: Vector2) -> Vector2:
	return _world_call(&"_wrapped_delta", [from_position, to_position])

func _wrapped_distance(from_position: Vector2, to_position: Vector2) -> float:
	return _world_call(&"_wrapped_distance", [from_position, to_position])


func _trigger_auto_monster_card_command(skill: Dictionary, _player: Dictionary, target_slot: int) -> bool:
	var slot := _valid_auto_monster_slot(target_slot)
	if slot < 0 or slot >= auto_monsters.size():
		_log("%s没有找到可指挥的怪兽。" % skill["name"])
		return false
	selected_auto_monster_slot = slot
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("down", false)):
		_log("怪%d·%s已倒地，不能执行%s。" % [slot + 1, String(actor.get("name", "怪兽")), String(skill["name"])])
		return false
	if _entity_has_linear_motion(actor):
		_log("怪%d·%s正在按米/秒移动，暂时不能接收新的直接指挥。" % [slot + 1, String(actor.get("name", "怪兽"))])
		return false
	var target: int = selected_district
	if target < 0 or target >= districts.size() or districts[target]["destroyed"]:
		_log("%s的目标区域无效或已破坏。" % skill["name"])
		return false
	var kind := String(skill.get("kind", ""))
	var before := _entity_world_position(actor)
	var moved := 0.0
	var resolved := false
	match kind:
		"move", "fly", "burrow":
			var movement_mode := "fly" if kind == "fly" else _auto_monster_movement_mode(actor)
			var movement_speed_mps := _auto_monster_movement_speed_mps(actor, target, float(skill.get("move", -1.0)))
			moved = _start_entity_linear_motion(actor, _district_center(target), movement_speed_mps, String(skill["name"]), movement_mode, -1.0, kind)
			if moved <= 0.5:
				_log("%s指挥怪%d·%s移动，但它没有完成有效位移。" % [String(skill["name"]), slot + 1, String(actor.get("name", "怪兽"))])
				return false
			_add_visual_trail(before, _district_center(target), _auto_monster_color(slot), String(skill["name"]))
			_add_action_callout(
				"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
				"卡牌指令启程",
				"%s向%s线性移动：速度%s/秒，预计%s。" % [
					String(skill["name"]),
					districts[target]["name"],
					_meters_text(movement_speed_mps),
					_duration_short_text(moved / maxf(1.0, movement_speed_mps)),
				],
				_auto_monster_color(slot),
				before
			)
			if kind == "burrow":
				var burrow_armor: int = int(skill.get("armor", 0))
				actor["armor"] = int(actor.get("armor", 0)) + burrow_armor
			resolved = true
		"attack":
			resolved = _command_auto_monster_attack(slot, skill)
		"charge_attack":
			var charge_target := _nearest_other_auto_monster_slot(slot)
			if charge_target < 0:
				_log("%s没有可攻击的其他怪兽目标。" % skill["name"])
				return false
			var target_actor: Dictionary = auto_monsters[charge_target]
			var charge_distance := _wrapped_distance(_entity_world_position(actor), _entity_world_position(target_actor))
			var charge_range := maxf(MELEE_RANGE_METERS, float(skill.get("range", MELEE_RANGE_METERS)))
			if charge_distance > charge_range:
				var charge_speed_mps := _auto_monster_movement_speed_mps(actor, int(target_actor.get("position", target)), float(skill.get("move", MONSTER_COMMAND_MOVE_METERS)))
				moved = _start_entity_linear_motion(actor, _entity_world_position(target_actor), charge_speed_mps, String(skill["name"]), _auto_monster_movement_mode(actor), -1.0, "charge_attack")
				if moved <= 0.5:
					return false
				_add_visual_trail(before, _entity_world_position(target_actor), _auto_monster_color(slot), String(skill["name"]))
				_add_action_callout(
					"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
					"冲锋启程",
					"%s向怪%d线性冲锋，预计%s进入攻击距离。" % [String(skill["name"]), charge_target + 1, _duration_short_text(moved / maxf(1.0, charge_speed_mps))],
					_auto_monster_color(slot),
					before
				)
				resolved = true
			else:
				auto_monsters[slot] = actor
				resolved = _command_auto_monster_attack(slot, skill)
		"armor_gain":
			var direct_armor: int = int(skill.get("armor", 0))
			actor["armor"] = int(actor.get("armor", 0)) + direct_armor
			resolved = direct_armor > 0
		"guard":
			var guard_armor: int = max(int(skill.get("guard", 0)), int(skill.get("ranged_guard", 0)))
			actor["armor"] = int(actor.get("armor", 0)) + guard_armor
			resolved = guard_armor > 0
		"area_damage":
			var area_range := float(skill.get("range", DEFAULT_AOE_RADIUS_METERS))
			if _entity_distance_to_district(actor, target) > area_range:
				_log("%s目标距离%s，超过范围%s。" % [String(skill["name"]), _entity_distance_to_district_label(actor, target), _meters_text(area_range)])
				return false
			_add_monster_attack_effect(_entity_world_position(actor), _district_center(target), String(skill["name"]), area_range, _auto_monster_color(slot), area_range > MELEE_RANGE_METERS, _monster_action_animation_profile(String(actor.get("name", "怪兽")), skill))
			_damage_district(target, max(1, int(skill.get("damage", 1))), String(skill["name"]))
			resolved = true
		"miasma_shot", "corrosive_breath":
			if _entity_distance_to_district(actor, target) > float(skill.get("range", 0.0)):
				_log("%s目标距离%s，超过射程%s。" % [String(skill["name"]), _entity_distance_to_district_label(actor, target), _meters_text(float(skill.get("range", 0.0)))])
				return false
			_add_monster_attack_effect(_entity_world_position(actor), _district_center(target), String(skill["name"]), float(skill.get("range", 0.0)), _auto_monster_color(slot), true, _monster_action_animation_profile(String(actor.get("name", "怪兽")), skill))
			_damage_district(target, max(1, int(skill.get("damage", 1))), String(skill["name"]))
			_place_auto_miasma(actor, target, int(skill.get("miasma_count", 0)), String(skill["name"]))
			resolved = true
		"miasma_bloom":
			if _entity_distance_to_district(actor, target) > float(skill.get("range", DEFAULT_AOE_RADIUS_METERS)):
				_log("%s目标距离%s，超过范围%s。" % [String(skill["name"]), _entity_distance_to_district_label(actor, target), _meters_text(float(skill.get("range", DEFAULT_AOE_RADIUS_METERS)))])
				return false
			_place_auto_miasma(actor, target, int(skill.get("miasma_count", 0)), String(skill["name"]))
			resolved = true
		"miasma_reclaim":
			resolved = _command_auto_monster_reclaim_miasma(slot, skill)
		"roar":
			if _entity_distance_to_district(actor, target) > float(skill.get("range", 0.0)):
				_log("%s目标距离%s，超过范围%s。" % [String(skill["name"]), _entity_distance_to_district_label(actor, target), _meters_text(float(skill.get("range", 0.0)))])
				return false
			special_monster_timer += float(skill.get("delay", 1.0))
			resolved = true
		"roll_attack":
			var roll_speed_mps := _auto_monster_movement_speed_mps(actor, target, float(skill.get("move", -1.0)))
			moved = _start_entity_linear_motion(actor, _district_center(target), roll_speed_mps, String(skill["name"]), _auto_monster_movement_mode(actor), -1.0, "roll_attack")
			if moved <= 0.5:
				_log("%s没有完成有效翻滚。" % skill["name"])
				return false
			actor["linear_move_arrival_damage"] = max(1, int(skill.get("damage", 1)))
			actor["linear_move_arrival_damage_source"] = String(skill["name"])
			_add_visual_trail(before, _district_center(target), _auto_monster_color(slot), String(skill["name"]))
			_add_action_callout(
				"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
				"翻滚启程",
				"%s向%s线性翻滚，抵达时造成技能破坏。" % [String(skill["name"]), districts[target]["name"]],
				_auto_monster_color(slot),
				before
			)
			resolved = true
	if not resolved:
		return false
	auto_monsters[slot] = actor
	if moved > 0.5 and ["move", "fly", "burrow"].has(kind) and not _entity_has_linear_motion(actor):
		_resolve_auto_monster_encounter(slot, "卡牌指挥后的遭遇")
	_log("匿名卡牌%s：一次性直接指挥怪%d·%s执行动作，位置%s%s；出牌者不公开。" % [
		String(skill["name"]),
		slot + 1,
		String(actor.get("name", "怪兽")),
		districts[int(actor.get("position", target))]["name"],
		"，开始线性移动%s" % _meters_text(moved) if _entity_has_linear_motion(actor) else ("，移动%s" % _meters_text(moved) if moved > 0.5 else ""),
	])
	_add_action_callout(
		"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
		"卡牌指令",
		"%s一次性直接指挥这只怪兽；出牌者不公开。" % String(skill["name"]),
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	return true

func _trigger_bound_monster_skill(skill: Dictionary, _player: Dictionary) -> bool:
	var uid := int(skill.get("bound_monster_uid", 0))
	var slot := _auto_monster_slot_by_uid(uid)
	if slot < 0:
		_log("%s绑定的怪兽已不在场上。" % String(skill.get("name", "固定技能")))
		return false
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("down", false)):
		_log("怪%d·%s已倒地，无法释放%s。" % [slot + 1, String(actor.get("name", "怪兽")), String(skill.get("name", "固定技能"))])
		return false
	if _entity_has_linear_motion(actor):
		_log("怪%d·%s正在移动中，固定技能会等它抵达后再释放。" % [slot + 1, String(actor.get("name", "怪兽"))])
		return false
	var action: Dictionary = (skill.get("action", {}) as Dictionary).duplicate(true)
	if action.is_empty():
		return false
	var target := selected_district
	if target < 0 or target >= districts.size() or bool(districts[target].get("destroyed", false)):
		target = _weighted_auto_monster_target(actor)
	if target < 0:
		return false
	var before := _entity_world_position(actor)
	var required_range: float = float(action.get("range", 0.0))
	var move_budget: float = _auto_monster_movement_speed_mps(actor, target, float(action.get("move_override", -1.0)))
	if required_range <= 0.0 or _entity_distance_to_district(actor, target) > required_range:
		var planned_distance := _start_entity_linear_motion(actor, _district_center(target), move_budget, String(action.get("name", "兽技")), _auto_monster_movement_mode(actor), -1.0, "bound_skill_move")
		if planned_distance > 0.5:
			_add_visual_trail(before, _district_center(target), _auto_monster_color(slot), String(action.get("name", "兽技")))
			_add_action_callout(
				"匿名固定技能",
				"接近目标",
				"怪%d·%s先向%s线性移动，预计%s后进入技能范围。" % [
					slot + 1,
					String(actor.get("name", "怪兽")),
					districts[target]["name"],
					_duration_short_text(planned_distance / maxf(1.0, move_budget)),
				],
				_auto_monster_color(slot),
				before
			)
			auto_monsters[slot] = actor
			return true
	var target_after_move := target
	if required_range <= 0.0:
		target_after_move = int(actor.get("position", target))
	var in_range := required_range <= 0.0 or _entity_distance_to_district(actor, target_after_move) <= required_range
	if in_range:
		var district_damage: int = max(AUTO_MONSTER_MIN_SPECIAL_DAMAGE, int(ceil(float(action.get("damage", 1)) * 0.5)))
		_add_monster_attack_effect(_entity_world_position(actor), _district_center(target_after_move), String(action.get("name", "兽技")), required_range, _auto_monster_color(slot), required_range > MELEE_RANGE_METERS, _monster_action_animation_profile(String(actor.get("name", "怪兽")), action))
		_damage_district(target_after_move, district_damage, "%s·%s" % [String(actor.get("name", "怪兽")), String(action.get("name", "兽技"))])
		_auto_monster_resource_drain(actor, target_after_move, String(action.get("name", "兽技")))
		_place_auto_miasma(actor, target_after_move, int(action.get("miasma_count", 0)), String(action.get("name", "兽技")))
	var armor_gain := int(action.get("armor", 0))
	if armor_gain > 0:
		actor["armor"] = int(actor.get("armor", 0)) + armor_gain
	var self_heal := int(action.get("self_heal", 0))
	if self_heal > 0:
		actor["hp"] = min(int(actor.get("max_hp", 0)), int(actor.get("hp", 0)) + self_heal)
	auto_monsters[slot] = actor
	if int(action.get("damage", 0)) > 0:
		_try_auto_monster_hit_other(slot, action)
	_add_action_callout(
		"匿名固定技能",
		String(action.get("name", "兽技")),
		"怪%d·%s主动释放绑定技能，目标%s。" % [slot + 1, String(actor.get("name", "怪兽")), districts[target_after_move]["name"]],
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	_log("匿名固定技能触发：怪%d·%s释放%s，目标%s；%s。" % [
		slot + 1,
		String(actor.get("name", "怪兽")),
		String(action.get("name", "兽技")),
		districts[target_after_move]["name"],
		String(action.get("text", "")),
	])
	return true

func _apply_monster_takeover(skill: Dictionary, target_slot: int, player_index: int) -> bool:
	if target_slot < 0 or target_slot >= auto_monsters.size():
		return false
	var actor: Dictionary = auto_monsters[target_slot]
	if bool(actor.get("down", false)):
		_log("%s无法夺取倒地怪兽。" % String(skill.get("name", "夺取怪兽")))
		return false
	var owned_count_excluding_target := _owned_active_monster_count(player_index, target_slot)
	var monster_limit := _player_monster_control_limit(player_index)
	if int(actor.get("owner", -1)) != player_index and owned_count_excluding_target >= monster_limit:
		_log("%s无法夺取怪%d·%s：当前角色同时最多归属%d只怪兽。" % [
			String(skill.get("name", "夺取怪兽")),
			target_slot + 1,
			String(actor.get("name", "怪兽")),
			monster_limit,
		])
		return false
	var old_owner := int(actor.get("owner", -1))
	var monster_uid := int(actor.get("uid", 0))
	actor["owner"] = player_index
	actor["owner_revealed"] = false
	actor["owner_clue"] = "归属刚被匿名夺取，等待下一次受伤资金线索。"
	actor = _reset_owner_damage_cash_meter(actor)
	auto_monsters[target_slot] = actor
	_invalidate_bound_monster_skills(monster_uid, "绑定怪兽归属被夺取，此固定技能失效。")
	var granted := _grant_bound_monster_skills(player_index, monster_uid, String(actor.get("name", "怪兽")), clampi(int(actor.get("rank", 1)), 1, 4))
	_add_action_callout(
		"匿名卡牌",
		"夺取怪兽",
		"怪%d·%s的归属被重写；出牌者不公开。" % [target_slot + 1, String(actor.get("name", "怪兽"))],
		_auto_monster_color(target_slot),
		_entity_world_position(actor)
	)
	_log("公开情报：怪%d·%s的归属被匿名夺取；原归属%s，新归属暂不公开。新归属者获得固定技能：%s。" % [
		target_slot + 1,
		String(actor.get("name", "怪兽")),
		("未知" if old_owner < 0 else "已被覆盖"),
		_limited_name_list(granted, 4, "无"),
	])
	_refresh_ui()
	return true

func _command_auto_monster_attack(slot: int, skill: Dictionary) -> bool:
	var target_slot := _nearest_other_auto_monster_slot(slot)
	if target_slot < 0:
		_log("%s没有可攻击的其他怪兽目标。" % String(skill.get("name", "攻击")))
		return false
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	var range_limit: float = float(skill.get("range", MELEE_RANGE_METERS))
	if range_limit <= 0.0:
		range_limit = MELEE_RANGE_METERS
	var distance: float = _wrapped_distance(_entity_world_position(actor), _entity_world_position(target))
	if distance > range_limit:
		_log("%s目标怪%d·%s距离%s，超过范围%s。" % [
			String(skill.get("name", "攻击")),
			target_slot + 1,
			String(target.get("name", "怪兽")),
			_meters_text(distance),
			_meters_text(range_limit),
		])
		return false
	_add_monster_attack_effect(_entity_world_position(actor), _entity_world_position(target), String(skill.get("name", "攻击")), range_limit, _auto_monster_color(slot), range_limit > MELEE_RANGE_METERS, _monster_action_animation_profile(String(actor.get("name", "怪兽")), skill))
	_auto_monster_take_damage(target_slot, int(skill.get("damage", 0)), "%s·%s" % [String(actor.get("name", "怪兽")), String(skill.get("name", "攻击"))], slot)
	var knockback_model := _monster_knockback_model(skill, actor)
	var knockback: float = float(knockback_model.get("knockback_m", skill.get("knockback", 0.0)))
	if knockback > 0.5:
		_knockback_auto_monster_from_actor(target_slot, slot, knockback, String(skill.get("name", "攻击")), float(knockback_model.get("knockback_duration_seconds", 0.5)))
	return true

func _command_auto_monster_reclaim_miasma(slot: int, skill: Dictionary) -> bool:
	var actor: Dictionary = auto_monsters[slot]
	var radius_m: float = float(skill.get("range", NEARBY_RADIUS_METERS))
	var max_tokens: int = int(skill.get("reclaim_count", 1))
	var candidates := _districts_in_radius(_entity_world_position(actor), radius_m, true)
	var reclaimed := 0
	for index in candidates:
		if reclaimed >= max_tokens:
			break
		if not districts[index]["miasma"]:
			continue
		districts[index]["miasma"] = false
		_pulse_district(index, Color("#22c55e"))
		reclaimed += 1
		_log("%s指挥怪%d·%s回收%s的瘴气。" % [
			String(skill.get("name", "瘴气回收")),
			slot + 1,
			String(actor.get("name", "怪兽")),
			districts[index]["name"],
		])
	if reclaimed <= 0:
		_log("%s范围内没有可回收的瘴气。" % String(skill.get("name", "瘴气回收")))
		return false
	actor["hp"] = min(int(actor.get("max_hp", 0)), int(actor.get("hp", 0)) + reclaimed)
	auto_monsters[slot] = actor
	return true
func _entity_distance_to_district_label(entity: Dictionary, district_index: int) -> String:
	return _world_call(&"_entity_distance_to_district_label", [entity, district_index])
