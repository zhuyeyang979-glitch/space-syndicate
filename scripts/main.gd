extends Control
const MonsterArtViewScript := preload("res://scripts/monster_art_view.gd")
const MonsterCatalogV06 := preload("res://scripts/runtime/monster_catalog_v06.gd")
const RuntimeBalanceModelScript := preload("res://scripts/balance/runtime_balance_model.gd")
const CardPlayRequirementPolicyScript := preload("res://scripts/cards/card_play_requirement_policy.gd")
const SharedCardGroupWindowScript := preload("res://scripts/cards/shared_card_group_window.gd")
const RoguelikeEconomicViabilityPolicyScript := preload("res://scripts/runtime/roguelike_economic_viability_policy.gd")
const TABLE_SFX_KEYS := ["card", "impact", "storm"]
const MONSTER_COMMAND_MOVE_METERS := 220.0
const NEARBY_RADIUS_METERS := 240.0
const DEFAULT_AOE_RADIUS_METERS := 180.0
const ACTION_CALLOUT_DURATION := 4.5
const CITY_PUBLIC_CLUE_HISTORY_LIMIT := 6
const DISTRICT_CARD_CHOICE_MIN := 4
const DISTRICT_CARD_CHOICE_MAX := 5
const CARD_INGRESS_CALLOUT_DURATION := 6.5
const AUTO_MONSTER_MOVE_RATIO := 0.72
const EMBER_RING_BOMB_SELF_DAMAGE := 3
const STARTING_CASH := 2000
const CITY_PRODUCT_LEVEL_MAX := 5
const ECONOMY_LEGACY_TURN_SECONDS := 30.0
const INTEL_CORRECT_GUESS_CASH := 120
const INTEL_WRONG_GUESS_COST := 60
const RIVAL_AUTO_BUILD_CHANCE_PERCENT := 72
const RIVAL_AUTO_BUILD_MAX_PER_CYCLE := 2
const RIVAL_AUTO_BUILD_BASE_CITY_CAP := 2
const RIVAL_AUTO_BUILD_MAX_CITY_CAP := 5
const RIVAL_AUTO_BUILD_MIN_CASH_RESERVE := 180
const ECONOMY_HISTORY_LIMIT := 24
const ECONOMY_LEDGER_LIMIT := 14
const PLAYER_HAND_LIMIT := 5
const CARD_RESOLUTION_DISPLAY_SECONDS := 5.0
const CARD_RESOLUTION_AFTERMATH_SECONDS := 8.0
const CARD_RESOLUTION_HISTORY_LIMIT := 24
const TEMP_DECISION_DISCARD := "discard_purchase"
const MONSTER_CARD_PLAY_CASH_PER_EXISTING := 100
const MONSTER_OWNER_DAMAGE_CASH_RANK_STEP := 170
const COMMAND_COOLDOWN := 1.0
const DEFAULT_SKILL_COOLDOWN := 3.0

const PLAYER_COLORS := [
	Color("#38bdf8"),
	Color("#f472b6"),
	Color("#facc15"),
	Color("#4ade80"),
	Color("#c084fc"),
	Color("#fb7185"),
	Color("#2dd4bf"),
	Color("#fb923c"),
]


const WAREHOUSE_STOCKPILE_COUNT_PRESSURE := 34
const WAREHOUSE_STOCKPILE_UNIT_PRESSURE := 8
const WAREHOUSE_STOCKPILE_PRODUCT_PRESSURE := 10


const DISTRICT_PALETTE := [
	Color("#1e3a8a"),
	Color("#166534"),
	Color("#7c2d12"),
	Color("#581c87"),
	Color("#0f766e"),
	Color("#9f1239"),
	Color("#854d0e"),
	Color("#1d4ed8"),
	Color("#047857"),
	Color("#7e22ce"),
	Color("#be123c"),
	Color("#0369a1"),
]

const REALTIME_BALANCE := {
	"monster_min": 3.5,
	"monster_max": 5.5,
	"special_monster_min": 4.5,
	"special_monster_max": 7.0,
	"market_min": 30.0,
	"market_max": 60.0,
	"monster_damage": 1,
	"special_monster_damage_bonus": 0,
	"special_monster_move_bonus": 0,
}

var _roguelike_economic_viability_dev_audit: Dictionary = {}

var runtime_game_screen: Control
var ruleset_runtime_bridge: Node
var ruleset_runtime_bridge_bound := false
var ruleset_runtime_bridge_missing := false
var ruleset_runtime_bridge_missing_reported := false
var game_runtime_coordinator: Node
var game_runtime_coordinator_bound := false
var game_runtime_coordinator_missing := false
var game_runtime_coordinator_missing_reported := false
var monster_runtime_controller: MonsterRuntimeController
var military_runtime_controller: MilitaryRuntimeController
var weather_runtime_controller: WeatherRuntimeController
var card_resolution_runtime_controller: Node
var card_resolution_runtime_controller_bound := false
var card_resolution_controller_missing := false
var card_resolution_controller_missing_context := ""
var card_resolution_controller_missing_reported := false
var map_view: Control
var full_map_overlay: Control
var full_map_view: Control
var fullscreen_map_hud_labels := {}
var card_resolution_timer: float:
	get:
		return float(_card_resolution_controller_value(&"active_display_timer", 0.0))
	set(value):
		_set_card_resolution_controller_value(&"active_display_timer", maxf(0.0, float(value)))
var card_resolution_counter_window_active: bool:
	get:
		return bool(_card_resolution_controller_value(&"counter_window_active", false))
	set(value):
		_set_card_resolution_controller_value(&"counter_window_active", bool(value))
var card_resolution_counter_timer: float:
	get:
		return float(_card_resolution_controller_value(&"counter_timer", 0.0))
	set(value):
		_set_card_resolution_controller_value(&"counter_timer", maxf(0.0, float(value)))
var card_resolution_force_duration := -1.0
var card_resolution_simultaneous_timer: float:
	get:
		return float(_card_resolution_controller_value(&"simultaneous_timer", 0.0))
	set(value):
		_set_card_resolution_controller_value(&"simultaneous_timer", maxf(0.0, float(value)))
var card_resolution_auction_timer: float:
	get:
		return float(_card_resolution_controller_value(&"auction_timer", 0.0))
	set(value):
		_set_card_resolution_controller_value(&"auction_timer", maxf(0.0, float(value)))
var card_resolution_force_simultaneous_window := -1.0
var card_resolution_auction_open: bool:
	get:
		return bool(_card_resolution_controller_value(&"auction_open", false))
	set(value):
		_set_card_resolution_controller_value(&"auction_open", bool(value))
var card_resolution_batch_locked: bool:
	get:
		return bool(_card_resolution_controller_value(&"batch_locked", false))
	set(value):
		_set_card_resolution_controller_value(&"batch_locked", bool(value))
var card_resolution_batch_reference_player: int:
	get:
		return int(_card_resolution_controller_value(&"batch_reference_player", -1))
	set(value):
		_set_card_resolution_controller_value(&"batch_reference_player", int(value))
var card_group_window_sequence: int:
	get:
		return int(_card_resolution_controller_value(&"window_sequence", 0))
	set(value):
		_set_card_resolution_controller_value(&"window_sequence", int(value))
var last_card_resolution_player_index: int:
	get:
		return int(_card_resolution_controller_value(&"last_resolution_player_index", -1))
	set(value):
		_set_card_resolution_controller_value(&"last_resolution_player_index", int(value))
var table_bgm_player: AudioStreamPlayer
var table_sfx_players := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_game_runtime_coordinator_node().run_rng_service().randomize()
	_build_layout()
	_build_table_audio()
	_game_runtime_coordinator_node().record_legacy_viewer_feedback("点击开局准备后确认玩家角色与起始怪兽牌；怪兽由怪兽卡匿名召唤，场上数量没有硬上限。")
	_start_table_bgm()


func _build_table_audio() -> void:
	_bind_runtime_audio_nodes()
	if table_bgm_player == null:
		push_error("Static TableAudioHost must provide NightPatrolTableBgm.")
	for key_variant in TABLE_SFX_KEYS:
		var key := String(key_variant)
		if not table_sfx_players.has(key) or not is_instance_valid(table_sfx_players[key]):
			push_error("Static TableAudioHost must provide NightPatrolSfx_%s." % key)


func _runtime_audio_host() -> Node:
	return get_node_or_null("RuntimeServices/TableAudioHost")


func _bind_runtime_audio_nodes() -> void:
	var host := _runtime_audio_host()
	if host == null:
		table_bgm_player = null
		table_sfx_players = {}
		push_error("Static RuntimeServices/TableAudioHost is required.")
		return
	table_bgm_player = host.get_node_or_null("NightPatrolTableBgm") as AudioStreamPlayer
	table_sfx_players = {}
	for key_variant in TABLE_SFX_KEYS:
		var key := String(key_variant)
		var player := host.get_node_or_null("NightPatrolSfx_%s" % key) as AudioStreamPlayer
		if player != null:
			table_sfx_players[key] = player
	_game_runtime_coordinator_node().bind_visual_cue_sfx_players(table_sfx_players)
	if table_bgm_player != null and table_bgm_player.stream != null and table_bgm_player.stream.get("loop") != null:
		table_bgm_player.stream.set("loop", true)


func _start_table_bgm() -> void:
	if DisplayServer.get_name() == "headless" or table_bgm_player == null or table_bgm_player.stream == null or table_bgm_player.playing:
		return
	table_bgm_player.play()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		if full_map_overlay != null and full_map_overlay.visible:
			_close_fullscreen_map()
			return
	var menu_lifecycle := get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController") as MenuLifecycleApplicationFlowController
	if menu_lifecycle != null and menu_lifecycle.handle_key_request(key_event.keycode):
		return

func _build_runtime_game_screen() -> void:
	if runtime_game_screen == null:
		runtime_game_screen = get_node_or_null("RuntimeGameScreen") as Control
	if runtime_game_screen == null:
		push_error("Static RuntimeGameScreen scene is required.")
		return
	_bind_runtime_game_screen(runtime_game_screen)


func _bind_sceneized_runtime_composition() -> void:
	_bind_ruleset_runtime_bridge()
	_bind_game_runtime_coordinator()
	_bind_card_resolution_runtime_controller()
	if runtime_game_screen == null:
		runtime_game_screen = get_node_or_null("RuntimeGameScreen") as Control
	if runtime_game_screen != null:
		_bind_runtime_game_screen(runtime_game_screen)


func _ruleset_runtime_bridge_node() -> Node:
	if ruleset_runtime_bridge != null and is_instance_valid(ruleset_runtime_bridge):
		return ruleset_runtime_bridge
	ruleset_runtime_bridge = get_node_or_null("RuntimeServices/RulesetRuntimeBridge")
	ruleset_runtime_bridge_bound = false
	return ruleset_runtime_bridge


func _mark_ruleset_runtime_bridge_missing(report_error: bool = false) -> void:
	ruleset_runtime_bridge_missing = true
	if report_error and not ruleset_runtime_bridge_missing_reported:
		ruleset_runtime_bridge_missing_reported = true
		push_error("RulesetRuntimeBridge is required; no duplicate v0.3/v0.4 timing fallback is available.")


func _bind_ruleset_runtime_bridge() -> void:
	var bridge := _ruleset_runtime_bridge_node()
	if bridge == null or not bridge.has_method("debug_snapshot"):
		_mark_ruleset_runtime_bridge_missing(true)
		return
	var snapshot_variant: Variant = bridge.call("debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	if str(snapshot.get("ruleset_id", "")) != "v0.4" or not bool(snapshot.get("bridge_ready", false)):
		_mark_ruleset_runtime_bridge_missing(true)
		return
	ruleset_runtime_bridge_bound = true
	ruleset_runtime_bridge_missing = false
	ruleset_runtime_bridge_missing_reported = false


func _ruleset_timing_rules() -> Dictionary:
	var bridge := _ruleset_runtime_bridge_node()
	if bridge == null or not bridge.has_method("timing_rules"):
		_mark_ruleset_runtime_bridge_missing(true)
		return {}
	var timing_variant: Variant = bridge.call("timing_rules")
	return (timing_variant as Dictionary).duplicate(true) if timing_variant is Dictionary else {}


func _ruleset_timing_seconds(rule_id: StringName) -> float:
	return maxf(0.0, float(_ruleset_timing_rules().get(String(rule_id), 0.0)))


func _ruleset_runtime_debug_snapshot() -> Dictionary:
	var bridge := _ruleset_runtime_bridge_node()
	if bridge != null and bridge.has_method("debug_snapshot"):
		var snapshot_variant: Variant = bridge.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			var snapshot := (snapshot_variant as Dictionary).duplicate(true)
			snapshot["bridge_bound"] = ruleset_runtime_bridge_bound
			snapshot["bridge_missing"] = ruleset_runtime_bridge_missing
			return snapshot
	return {
		"ruleset_id": "",
		"bridge_ready": false,
		"bridge_bound": false,
		"bridge_missing": true,
		"timing": {},
		"card_group": {},
		"forced_decision_priority": [],
		"capabilities": {},
	}


func _game_runtime_coordinator_node() -> GameRuntimeCoordinator:
	if game_runtime_coordinator != null and is_instance_valid(game_runtime_coordinator):
		return game_runtime_coordinator as GameRuntimeCoordinator
	game_runtime_coordinator = get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	game_runtime_coordinator_bound = false
	return game_runtime_coordinator as GameRuntimeCoordinator


func _ai_runtime_controller_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("AiRuntimeController") if coordinator != null else null


func _product_market_runtime_controller_node() -> ProductMarketRuntimeController:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.call("product_market_runtime_controller") as ProductMarketRuntimeController if coordinator != null and coordinator.has_method("product_market_runtime_controller") else null


func _product_market_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("product_market_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("product_market_runtime_call", method_name, arguments)


func _city_gdp_derivative_runtime_controller_node() -> CityGdpDerivativeRuntimeController:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.call("city_gdp_derivative_runtime_controller") as CityGdpDerivativeRuntimeController if coordinator != null and coordinator.has_method("city_gdp_derivative_runtime_controller") else null


func _city_gdp_derivative_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("city_gdp_derivative_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("city_gdp_derivative_runtime_call", method_name, arguments)


func _route_network_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("route_network_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("route_network_runtime_call", method_name, arguments)


func _commodity_flow_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("commodity_flow_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("commodity_flow_runtime_call", method_name, arguments)


func _region_infrastructure_runtime_controller_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.call("region_infrastructure_runtime_controller") as Node if coordinator != null and coordinator.has_method("region_infrastructure_runtime_controller") else null


func _region_infrastructure_world_bridge_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.call("region_infrastructure_world_bridge") as Node if coordinator != null and coordinator.has_method("region_infrastructure_world_bridge") else null


func _region_infrastructure_snapshot_for_district(district_index: int) -> Dictionary:
	var bridge := _region_infrastructure_world_bridge_node()
	if bridge == null or district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return {}
	var value: Variant = bridge.call("region_snapshot_for_legacy_index", district_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _region_infrastructure_owned_facilities(district_index: int, player_index: int) -> Array:
	var result: Array = []
	for facility_variant in _region_infrastructure_snapshot_for_district(district_index).get("facilities", []):
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("owner_kind", "")) == "player" and int((facility_variant as Dictionary).get("owner_player_index", -1)) == player_index:
			result.append((facility_variant as Dictionary).duplicate(true))
	return result


func _initialize_region_infrastructure_runtime() -> Dictionary:
	var bridge := _region_infrastructure_world_bridge_node()
	if bridge == null:
		return {"initialized": false, "reason": "region_infrastructure_bridge_missing"}
	var definitions: Array = []
	for district_index in range(_game_runtime_coordinator_node().world_session_state().districts.size()):
		var district: Dictionary = _game_runtime_coordinator_node().world_session_state().districts[district_index]
		var neighbor_ids: Array = []
		for neighbor_variant in district.get("neighbors", []):
			var neighbor_index := int(neighbor_variant)
			if neighbor_index >= 0 and neighbor_index < _game_runtime_coordinator_node().world_session_state().districts.size():
				neighbor_ids.append(str((_game_runtime_coordinator_node().world_session_state().districts[neighbor_index] as Dictionary).get("region_id", "region.%03d" % neighbor_index)))
		definitions.append({
			"region_id": str(district.get("region_id", "region.%03d" % district_index)),
			"terrain_id": str(district.get("terrain", "unknown")),
			"neighbor_region_ids": neighbor_ids,
			"legacy_index": district_index,
		})
	var result_variant: Variant = bridge.call("initialize_from_legacy_map", definitions)
	var result: Dictionary = result_variant if result_variant is Dictionary else {"initialized": false, "reason": "region_infrastructure_result_invalid"}
	_sync_region_infrastructure_view_cache()
	return result


func _sync_region_infrastructure_view_cache(region_index: int = -1) -> void:
	var bridge := _region_infrastructure_world_bridge_node()
	if bridge == null:
		return
	var indices: Array = [region_index] if region_index >= 0 else range(_game_runtime_coordinator_node().world_session_state().districts.size())
	for index_variant in indices:
		var index := int(index_variant)
		if index < 0 or index >= _game_runtime_coordinator_node().world_session_state().districts.size():
			continue
		var snapshot_variant: Variant = bridge.call("region_snapshot_for_legacy_index", index)
		var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
		if snapshot.is_empty():
			continue
		var district: Dictionary = _game_runtime_coordinator_node().world_session_state().districts[index]
		# Temporary read projection for scene/UI consumers. Mutation belongs only to the controller.
		district["hp"] = int(snapshot.get("derived_max_hp", 0))
		district["damage"] = maxi(0, int(snapshot.get("derived_max_hp", 0)) - int(snapshot.get("derived_current_hp", 0)))
		district["destroyed"] = str(snapshot.get("lifecycle_state", "")) == "ruined"
		_game_runtime_coordinator_node().world_session_state().districts[index] = district


func _on_region_infrastructure_receipt(receipt: Dictionary) -> void:
	var controller := _region_infrastructure_runtime_controller_node()
	if controller == null:
		return
	var region_id := str(receipt.get("region_id", ""))
	var region_variant: Variant = controller.call("region_snapshot", region_id)
	var region_snapshot: Dictionary = region_variant if region_variant is Dictionary else {}
	var district_index := int(region_snapshot.get("legacy_index", -1))
	_sync_region_infrastructure_view_cache(district_index)
	if not bool(receipt.get("committed", false)) or district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return
	if bool(receipt.get("region_ruined", false)):
		_product_market_settle_destroyed_warehouse(district_index, str(receipt.get("source_entity_id", "unit")), receipt)
		_game_runtime_coordinator_node().add_visual_district_damage(district_index, _district_center(district_index), float((_game_runtime_coordinator_node().world_session_state().districts[district_index] as Dictionary).get("radius_m", 70.0)), str(receipt.get("source_entity_id", "unit")), Color("#ef4444"))
		_game_runtime_coordinator_node().record_legacy_viewer_feedback("%s的公共设施共享生命归零，区域进入废墟。" % str((_game_runtime_coordinator_node().world_session_state().districts[district_index] as Dictionary).get("name", "区域")))
	elif str(receipt.get("receipt_kind", "")) == "unit_damage":
		_game_runtime_coordinator_node().add_visual_district_damage(district_index, _district_center(district_index), float((_game_runtime_coordinator_node().world_session_state().districts[district_index] as Dictionary).get("radius_m", 70.0)), str(receipt.get("source_entity_id", "unit")), Color("#fb7185"))
		_game_runtime_coordinator_node().record_legacy_viewer_feedback("%s的共享生命-%d。" % [str((_game_runtime_coordinator_node().world_session_state().districts[district_index] as Dictionary).get("name", "区域")), int(receipt.get("applied_damage", 0))])
	elif str(receipt.get("receipt_kind", "")) == "region_repair":
		_game_runtime_coordinator_node().pulse_visual_district(district_index, Color("#22c55e"))
		_game_runtime_coordinator_node().record_legacy_viewer_feedback("%s的共享生命修复%d。" % [str((_game_runtime_coordinator_node().world_session_state().districts[district_index] as Dictionary).get("name", "区域")), int(receipt.get("applied_repair", 0))])
	elif str(receipt.get("receipt_kind", "")) == "facility_action":
		_game_runtime_coordinator_node().pulse_visual_district(district_index, Color("#38bdf8"))


func monster_deploy_cross_owner_capabilities_v06() -> Dictionary:
	var noop_participant := {
		"owner_id": "vs06.p0.no_side_effects",
		"reason_code": "p0_profile_has_no_cross_owner_patch",
		"prepare": true,
		"commit": true,
		"rollback": true,
		"finalize": true,
		"exact_once": true,
		"checkpoint": true,
		"save_load": true,
	}
	return {
		"contract_version": "v0.6",
		"region_facts": {"revisioned_snapshot": true, "owner_id": "RegionInfrastructureRuntimeController"},
		"monster_profile": {"revisioned_snapshot": true, "owner_id": "CardRuntimeCatalogV06+MonsterRosterProfile"},
		"binding_rule": {"revisioned_snapshot": true, "owner_id": "CardPlayerStateProductionAdapterV06"},
		"bound_skill_inventory": noop_participant.duplicate(true),
		"product_market_rng": noop_participant.duplicate(true),
		"role_cash_ledger": noop_participant.duplicate(true),
	}


func monster_deploy_rule_snapshot_v06(actor_id: String) -> Dictionary:
	var player_index := -1
	for candidate_index in range(_game_runtime_coordinator_node().world_session_state().players.size()):
		if _v06_actor_id(candidate_index) == actor_id:
			player_index = candidate_index
			break
	if player_index < 0:
		return {"available": false, "authoritative": false, "reason_code": "monster_binding_actor_missing"}
	var player: Dictionary = _game_runtime_coordinator_node().world_session_state().players[player_index]
	var starter_card_id := ""
	var starter_card_instance_id := ""
	for slot_variant in player.get("slots", []) as Array:
		if not (slot_variant is Dictionary):
			continue
		var card: Dictionary = slot_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("effect_kind", "")) != "deploy_or_upgrade_monster" or int(machine.get("rank", 0)) != 1:
			continue
		starter_card_id = str(machine.get("card_id", ""))
		starter_card_instance_id = str(card.get("runtime_instance_id", ""))
		break
	var monster_owner := _monster_runtime_controller_node()
	if monster_owner == null or not monster_owner.has_method(&"monster_starter_state_snapshot_v06"):
		return {
			"available": false,
			"authoritative": false,
			"reason_code": "monster_starter_state_owner_unavailable",
			"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
			"player_index": player_index,
		}
	var starter_variant: Variant = monster_owner.call(&"monster_starter_state_snapshot_v06", actor_id)
	if not (starter_variant is Dictionary):
		return {
			"available": false,
			"authoritative": false,
			"reason_code": "monster_starter_state_snapshot_invalid",
			"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
			"player_index": player_index,
		}
	var starter_snapshot := starter_variant as Dictionary
	var starter_state := str(starter_snapshot.get("state", "legacy_unknown"))
	if not bool(starter_snapshot.get("available", false)) or starter_state == "legacy_unknown":
		return {
			"available": false,
			"authoritative": false,
			"reason_code": str(starter_snapshot.get("reason_code", "monster_starter_state_unavailable")),
			"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
			"player_index": player_index,
		}
	if not ["not_summoned", "summoned"].has(starter_state):
		return {
			"available": false,
			"authoritative": false,
			"reason_code": "monster_starter_state_snapshot_invalid",
			"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
			"player_index": player_index,
		}
	return {
		"available": true,
		"authoritative": true,
		"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
		"player_index": player_index,
		"monster_binding_limit": 1,
		"starter_entitled": not starter_card_id.is_empty(),
		"starter_consumed": starter_state == "summoned",
		"starter_card_id": starter_card_id,
		"starter_card_instance_id": starter_card_instance_id,
	}


func monster_deploy_region_snapshot_v06(region_id: String) -> Dictionary:
	var infrastructure := _region_infrastructure_runtime_controller_node()
	if infrastructure == null or not infrastructure.has_method("region_snapshot"):
		return {"available": false, "authoritative": false, "reason_code": "monster_region_owner_unavailable", "region_id": region_id}
	var region_variant: Variant = infrastructure.call("region_snapshot", region_id)
	var region: Dictionary = region_variant if region_variant is Dictionary else {}
	var district_index := int(region.get("legacy_index", -1))
	if district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return {"available": false, "authoritative": false, "reason_code": "monster_region_missing", "region_id": region_id}
	var district: Dictionary = _game_runtime_coordinator_node().world_session_state().districts[district_index]
	var center := _district_center(district_index)
	var destroyed := bool(district.get("destroyed", false)) or str(region.get("lifecycle_state", "")) == "ruined"
	return {
		"available": true,
		"authoritative": true,
		"revision": maxi(0, int(region.get("revision", 0))),
		"region_id": region_id,
		"region_index": district_index,
		"destroyed": destroyed,
		"starter_summon_allowed": not destroyed,
		"world_position": {"x": center.x, "y": center.y},
		"display_name": str(district.get("name", "区域")),
	}


func monster_deploy_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
	if rank != 1:
		return {"available": false, "authoritative": false, "reason_code": "monster_non_starter_deploy_deferred", "family_id": family_id, "rank": rank}
	var coordinator := _game_runtime_coordinator_node()
	var card_id := "unit.monster.%s.rank_%d" % [family_id, rank]
	var card_variant: Variant = coordinator.call("v06_card_definition", card_id) if coordinator != null and coordinator.has_method("v06_card_definition") else {}
	var card: Dictionary = card_variant if card_variant is Dictionary else {}
	var player_text: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
	var monster_name := str(player_text.get("name", ""))
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	if card.is_empty() or catalog_index < 0:
		return {"available": false, "authoritative": false, "reason_code": "monster_profile_missing", "family_id": family_id, "rank": rank}
	var roster: Dictionary = _catalog_entry(catalog_index)
	return {
		"available": true,
		"authoritative": true,
		"revision": 1,
		"family_id": family_id,
		"rank": rank,
		"name": monster_name,
		"catalog_index": catalog_index,
		"hp": int(roster.get("hp", 1)),
		"armor": int(roster.get("armor", 0)),
		"move_mps": float(roster.get("move", 0.0)),
		"move_damage": int(roster.get("move_damage", 0)),
		"collision_damage": int(roster.get("collision_damage", 0)),
		"resource_drain": int(roster.get("resource_drain", 0)),
		"movement_traits": (roster.get("movement_traits", []) as Array).duplicate(true) if roster.get("movement_traits", []) is Array else [],
		"terrain_move_multiplier": (roster.get("terrain_move_multiplier", {}) as Dictionary).duplicate(true) if roster.get("terrain_move_multiplier", {}) is Dictionary else {},
		"initial_duration_seconds": MonsterRuntimeController.MONSTER_CARD_DURATION_BASE_SECONDS,
		"bound_skill_patch": {},
		"economic_patch": {},
		"role_cash_patch": {},
	}


func prepare_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _monster_deploy_no_patch_stage_v06("prepare", "prepared", request)


func commit_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _monster_deploy_no_patch_stage_v06("commit", "committed", request)


func rollback_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _monster_deploy_no_patch_stage_v06("rollback", "rolled_back", request)


func finalize_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _monster_deploy_no_patch_stage_v06("finalize", "finalized", request)


func _monster_deploy_no_patch_stage_v06(stage: String, success_key: String, request: Dictionary) -> Dictionary:
	var required: Array = request.get("required_participants", []) if request.get("required_participants", []) is Array else []
	if not required.is_empty() \
		or not (request.get("bound_skill_patch", {}) as Dictionary).is_empty() \
		or not (request.get("economic_patch", {}) as Dictionary).is_empty() \
		or not (request.get("role_cash_patch", {}) as Dictionary).is_empty():
		return {success_key: false, "stage": stage, "reason_code": "monster_cross_owner_atomicity_unavailable"}
	return {
		success_key: true,
		"stage": stage,
		"reason_code": "p0_profile_has_no_cross_owner_patch",
		"transaction_id": str(request.get("transaction_id", "")),
		"participant_binding_fingerprint": str(request.get("participant_binding_fingerprint", "")),
	}


func _city_gdp_derivative_terms(skill: Dictionary) -> Dictionary:
	var value: Variant = _city_gdp_derivative_runtime_call("derivative_terms", [skill])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _city_gdp_derivative_duration_seconds(skill: Dictionary) -> float:
	return float(_city_gdp_derivative_runtime_call("duration_seconds", [skill]))


func _product_market_runtime_state() -> Dictionary:
	var value: Variant = _product_market_runtime_call("runtime_state_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _product_market_cycle() -> int:
	return int(_product_market_runtime_state().get("business_cycle_count", 0))


func _product_market_price(product_name: String) -> int:
	return int(_product_market_runtime_call("product_price", [product_name]))


func _product_market_tier(product_name: String) -> String:
	return str(_product_market_runtime_call("product_tier", [product_name]))


func _product_market_entry_snapshot(product_name: String) -> Dictionary:
	var value: Variant = _product_market_runtime_call("market_entry", [product_name])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _product_market_futures_public_counts(product_name: String) -> Dictionary:
	var value: Variant = _product_market_runtime_call("futures_public_counts", [product_name])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _product_market_futures_public_text(product_name: String, compact := false) -> String:
	return str(_product_market_runtime_call("futures_public_text", [product_name, compact]))


func _product_market_futures_duration_seconds(skill: Dictionary) -> float:
	return float(_product_market_runtime_call("futures_duration_seconds", [skill]))


func _product_market_route_flow_multiplier(product_name: String) -> float:
	return float(_product_market_runtime_call("product_route_flow_multiplier", [product_name]))


func _product_market_settle_destroyed_warehouse(district_index: int, source: String, damage_receipt: Dictionary) -> Dictionary:
	var value: Variant = _product_market_runtime_call("settle_futures_for_destroyed_warehouse", [district_index, source, damage_receipt.duplicate(true)])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {
		"committed": false,
		"reason": "product_market_runtime_missing",
		"settled_count": 0,
	}


func _monster_runtime_controller_node() -> MonsterRuntimeController:
	if monster_runtime_controller != null and is_instance_valid(monster_runtime_controller):
		return monster_runtime_controller
	var coordinator := _game_runtime_coordinator_node()
	monster_runtime_controller = coordinator.call("monster_runtime_controller") as MonsterRuntimeController if coordinator != null and coordinator.has_method("monster_runtime_controller") else null
	return monster_runtime_controller


func _military_runtime_controller_node() -> MilitaryRuntimeController:
	if military_runtime_controller != null and is_instance_valid(military_runtime_controller):
		return military_runtime_controller
	var coordinator := _game_runtime_coordinator_node()
	military_runtime_controller = coordinator.call("military_runtime_controller") as MilitaryRuntimeController if coordinator != null and coordinator.has_method("military_runtime_controller") else null
	return military_runtime_controller


func _on_military_runtime_event(event: Dictionary) -> void:
	if bool(event.get("public", false)) and str(event.get("summary", "")) != "":
		_game_runtime_coordinator_node().record_legacy_viewer_feedback(str(event.get("summary", "")))


func _on_monster_runtime_event(event: Dictionary) -> void:
	if bool(event.get("public", false)) and str(event.get("summary", "")) != "":
		_game_runtime_coordinator_node().record_legacy_viewer_feedback(str(event.get("summary", "")))


func _on_product_market_runtime_event(event: Dictionary) -> void:
	if bool(event.get("public", false)) and str(event.get("summary", "")) != "":
		_game_runtime_coordinator_node().record_legacy_viewer_feedback(str(event.get("summary", "")))


func _append_city_gdp_derivative_public_clue(district_index: int, clue: String) -> bool:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return false
	city = _append_city_public_clue(city, clue)
	_game_runtime_coordinator_node().world_session_state().districts[district_index]["city"] = city
	return true


func _present_city_gdp_derivative_opened(derivative_position: Dictionary) -> void:
	var district_index := int(derivative_position.get("district_index", -1))
	var district_label := str(_game_runtime_coordinator_node().world_session_state().districts[district_index].get("name", "城市")) if district_index >= 0 and district_index < _game_runtime_coordinator_node().world_session_state().districts.size() else "城市"
	var direction_label := "保单" if bool(derivative_position.get("insurance", false)) else ("买涨" if str(derivative_position.get("direction", "up")) == "up" else "做空")
	var detail := "%s｜%s｜基准GDP %d｜%s｜收益≤¥%d｜损失≤¥%d" % [
		district_label,
		direction_label,
		int(derivative_position.get("baseline_gdp", 0)),
		_duration_short_text(float(derivative_position.get("duration_seconds", 0.0))),
		int(derivative_position.get("maximum_gain", 0)),
		int(derivative_position.get("maximum_loss", 0)),
	]
	_game_runtime_coordinator_node().add_visual_action_callout("匿名GDP衍生品", str(derivative_position.get("card_id", "城市GDP衍生品")), detail, Color("#38bdf8"), _district_center(district_index) if district_index >= 0 else _economy_effect_callout_position())
	_game_runtime_coordinator_node().record_legacy_viewer_feedback("匿名GDP衍生品建仓：%s；出资方保持私密。" % detail)


func _present_city_gdp_derivative_settlement(district_index: int, reason: String, public_receipts: Array) -> void:
	if public_receipts.is_empty():
		return
	var district_label := str(_game_runtime_coordinator_node().world_session_state().districts[district_index].get("name", "城市")) if district_index >= 0 and district_index < _game_runtime_coordinator_node().world_session_state().districts.size() else "城市"
	var gain_total := 0
	var loss_total := 0
	for receipt_variant in public_receipts:
		if receipt_variant is Dictionary:
			gain_total += maxi(0, int((receipt_variant as Dictionary).get("gain", 0)))
			loss_total += maxi(0, int((receipt_variant as Dictionary).get("loss", 0)))
	var summary := "%s｜结算%d笔｜公开收益¥%d｜公开损失¥%d｜持有人不公开" % [district_label, public_receipts.size(), gain_total, loss_total]
	_game_runtime_coordinator_node().add_visual_action_callout("GDP衍生品结算", reason, summary, Color("#22d3ee"), _district_center(district_index) if district_index >= 0 else _economy_effect_callout_position())
	_game_runtime_coordinator_node().record_legacy_viewer_feedback("%s：%s。" % [reason, summary])


func _append_product_futures_warehouse_clue(district_index: int, source: String, direction: String, product_name: String, units: int, duration_seconds: float) -> bool:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return false
	city = _append_city_public_clue(city, "%s在本城建立%s匿名仓储：%s%d单位，%s后结算；仓储方不公开，仓库毁灭时按城市剩余生命比例结算保证金损失。" % [
		source, "看涨" if direction == "up" else "看跌", product_name, units, _duration_short_text(duration_seconds),
	])
	_game_runtime_coordinator_node().world_session_state().districts[district_index]["city"] = city
	return true


func _present_product_futures_opened(source: String, product_name: String, direction: String, before_price: int, duration_seconds: float, warehouse_district: int) -> void:
	var terms := _product_market_runtime_controller_node().terms_for_card_id(source) if _product_market_runtime_controller_node() != null else {}
	var warehouse_text := "｜仓库:%s" % str(_game_runtime_coordinator_node().world_session_state().districts[warehouse_district].get("name", "城市")) if warehouse_district >= 0 and warehouse_district < _game_runtime_coordinator_node().world_session_state().districts.size() else ""
	var risk_text := "保证金¥%d｜收益≤¥%d｜损失≤¥%d" % [
		int(terms.get("margin_cash", 0)),
		int(terms.get("maximum_gain", 0)),
		int(terms.get("maximum_loss", 0)),
	]
	_game_runtime_coordinator_node().add_visual_action_callout("匿名商品期货", source, "%s%s｜%s｜基准¥%d｜%s｜%s" % [product_name, warehouse_text, "看涨" if direction == "up" else "看跌", before_price, _duration_short_text(duration_seconds), risk_text], Color("#22d3ee"), _district_center(_game_runtime_coordinator_node().table_selection_state().selected_district))
	_game_runtime_coordinator_node().record_legacy_viewer_feedback("匿名商品期货建仓：%s围绕%s%s建立%s头寸，基准价¥%d，持仓%s，%s；价格仍由供需、商路、天气和合约决定。" % [source, product_name, warehouse_text, "看涨" if direction == "up" else "看跌", before_price, _duration_short_text(duration_seconds), risk_text])


func _present_product_growth_boon(source: String, product_name: String) -> void:
	if _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size():
		_game_runtime_coordinator_node().pulse_visual_district(_game_runtime_coordinator_node().table_selection_state().selected_district, Color("#f59e0b"))
	_game_runtime_coordinator_node().add_visual_action_callout("商品经济", source, "%s：%s" % [product_name, _product_market_boon_text(product_name)], Color("#f59e0b"), _economy_effect_callout_position())
	_game_runtime_coordinator_node().record_legacy_viewer_feedback("%s催化%s：%s。" % [source, product_name, _product_market_boon_text(product_name)])


func _present_product_contract_boon(source: String, product_name: String, before_price: int, after_price: int, before_volatility: int, after_volatility: int, cash_gain: int) -> void:
	if _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size():
		_game_runtime_coordinator_node().pulse_visual_district(_game_runtime_coordinator_node().table_selection_state().selected_district, Color("#f59e0b"))
	_game_runtime_coordinator_node().add_visual_action_callout("商品合约", source, "%s：%s，¥%d→¥%d。" % [product_name, _product_market_boon_text(product_name), before_price, after_price], Color("#f59e0b"), _economy_effect_callout_position())
	_game_runtime_coordinator_node().record_legacy_viewer_feedback("%s签下%s商品合约：%s，价格¥%d→¥%d，波动%d→%d，获得¥%d。" % [source, product_name, _product_market_boon_text(product_name), before_price, after_price, before_volatility, after_volatility, maxi(0, cash_gain)])


func _age_product_market_world_boons(delta_seconds: float) -> bool:
	var changed := false
	for index_variant in _active_city_district_indices():
		var district_index := int(index_variant)
		var city := _district_city(district_index).duplicate(true)
		if _age_remaining_effect_seconds(city, "route_flow_seconds", "route_flow_turns", delta_seconds):
			city["route_flow_multiplier"] = 1.0
			city["route_flow_source"] = ""
			changed = true
		if _age_remaining_effect_seconds(city, "contract_seconds", "contract_turns", delta_seconds):
			city["contract_income_bonus"] = 0
			city["contract_source"] = ""
			changed = true
		if int(city.get("military_gdp_penalty", 0)) > 0 and float(city.get("military_pressure_until", 0.0)) <= _game_runtime_coordinator_node().world_session_state().game_time:
			city["military_gdp_penalty"] = 0
			city["military_pressure_source"] = ""
			changed = true
		_game_runtime_coordinator_node().world_session_state().districts[district_index]["city"] = city
	if changed:
		_refresh_route_network()
	return changed


func _on_product_market_cycle_completed(cycle_count: int) -> void:
	_game_runtime_coordinator_node().record_legacy_viewer_feedback("全局市场刷新%d：商品公开基础价格已更新；现金与GDP只由实际成交回执产生。" % cycle_count)
	_ai_runtime_call("_auto_rival_business_actions", [false])
	_ai_runtime_call("_finalize_ai_decision_rewards")
	for player_index in range(_game_runtime_coordinator_node().world_session_state().players.size()):
		_record_player_cash_snapshot(player_index)


func _ai_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("ai_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("ai_runtime_call", method_name, arguments)


func _ai_runtime_world_snapshot(player_index: int) -> Dictionary:
	return {
		"context_revision": int(_game_runtime_coordinator_node().world_session_state().game_time * 1000.0),
		"player_index": player_index,
		"player_count": _game_runtime_coordinator_node().world_session_state().players.size(),
		"district_count": _game_runtime_coordinator_node().world_session_state().districts.size(),
		"business_cycle_count": _product_market_cycle(),
		"session_finished": _runtime_session_finished(),
		"victory_control": _victory_control_private_snapshot(player_index),
		"active_resolution_present": not _card_resolution_active_entry().is_empty(),
	}


func _apply_ai_runtime_intent(intent: Dictionary) -> Dictionary:
	var intent_id := str(intent.get("intent_id", ""))
	var action_id := str(intent.get("action_id", ""))
	if action_id == "ai_runtime_noop":
		return {"applied": true, "reason": "noop", "intent_id": intent_id, "action_id": action_id}
	return {"applied": false, "reason": "unsupported_intent", "intent_id": intent_id, "action_id": action_id}


func _on_ai_runtime_event(event: Dictionary) -> void:
	if bool(event.get("public", false)) and str(event.get("summary", "")) != "":
		_game_runtime_coordinator_node().record_legacy_viewer_feedback(str(event.get("summary", "")))


func _ai_runtime_world_constant_snapshot() -> Dictionary:
	return {
		"ACTION_CALLOUT_DURATION": ACTION_CALLOUT_DURATION,
		"AUTO_MONSTER_ENCOUNTER_RANGE_METERS": MonsterRuntimeController.AUTO_MONSTER_ENCOUNTER_RANGE_METERS,
		"DEFAULT_AOE_RADIUS_METERS": DEFAULT_AOE_RADIUS_METERS,
		"ECONOMY_LEGACY_TURN_SECONDS": ECONOMY_LEGACY_TURN_SECONDS,
		"NEARBY_RADIUS_METERS": NEARBY_RADIUS_METERS,
		"PLAYER_HAND_LIMIT": PLAYER_HAND_LIMIT,
		"ProductMarketRuntimeController.PRODUCT_CATALOG": ProductMarketRuntimeController.PRODUCT_CATALOG,
		"RIVAL_AUTO_BUILD_BASE_CITY_CAP": RIVAL_AUTO_BUILD_BASE_CITY_CAP,
		"RIVAL_AUTO_BUILD_CHANCE_PERCENT": RIVAL_AUTO_BUILD_CHANCE_PERCENT,
		"RIVAL_AUTO_BUILD_MAX_CITY_CAP": RIVAL_AUTO_BUILD_MAX_CITY_CAP,
		"RIVAL_AUTO_BUILD_MAX_PER_CYCLE": RIVAL_AUTO_BUILD_MAX_PER_CYCLE,
		"RIVAL_AUTO_BUILD_MIN_CASH_RESERVE": RIVAL_AUTO_BUILD_MIN_CASH_RESERVE,
	}


func _card_resolution_queue_service_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("CardResolutionQueueRuntimeService") if coordinator != null else null


func _card_resolution_execution_world_bridge_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("CardResolutionExecutionWorldBridge") if coordinator != null else null


func _card_economy_product_route_effect_world_bridge_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("CardEconomyProductRouteEffectWorldBridge") if coordinator != null else null


func _card_economy_product_route_formula_result(formula_id: String, input_snapshot: Dictionary) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("calculate_card_economy_product_route_formula"):
		_mark_game_runtime_coordinator_missing(true)
		return {}
	var value: Variant = coordinator.call("calculate_card_economy_product_route_formula", formula_id, input_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_resolution_current_queue() -> Array:
	var service := _card_resolution_queue_service_node()
	var value: Variant = service.call("current_queue") if service != null and service.has_method("current_queue") else []
	return (value as Array).duplicate(true) if value is Array else []


func _card_resolution_next_queue() -> Array:
	var service := _card_resolution_queue_service_node()
	var value: Variant = service.call("next_queue") if service != null and service.has_method("next_queue") else []
	return (value as Array).duplicate(true) if value is Array else []


func _card_resolution_active_entry() -> Dictionary:
	var service := _card_resolution_queue_service_node()
	var value: Variant = service.call("active_entry") if service != null and service.has_method("active_entry") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_resolution_sequence_value() -> int:
	var service := _card_resolution_queue_service_node()
	return int(service.call("resolution_sequence")) if service != null and service.has_method("resolution_sequence") else 0


func _get(property: StringName) -> Variant:
	var monster_controller := _monster_runtime_controller_node()
	var military_controller := _military_runtime_controller_node()
	match property:
		&"military_units":
			return military_controller.roster_snapshot(true) if military_controller != null else []
		&"next_military_unit_uid":
			return military_controller.next_military_unit_uid if military_controller != null else 1
		&"auto_monsters":
			return monster_controller.roster_snapshot(true) if monster_controller != null else []
		&"next_auto_monster_uid":
			return monster_controller.next_auto_monster_uid if monster_controller != null else 1
		&"next_special_monster_slot":
			return monster_controller.next_special_monster_slot if monster_controller != null else 0
		&"selected_auto_monster_slot":
			return monster_controller.selected_auto_monster_slot if monster_controller != null else 0
		&"monster_timer":
			return monster_controller.monster_timer if monster_controller != null else 4.0
		&"special_monster_timer":
			return monster_controller.special_monster_timer if monster_controller != null else 5.0
		&"card_resolution_queue":
			return _card_resolution_current_queue()
		&"next_card_resolution_queue":
			return _card_resolution_next_queue()
		&"active_card_resolution":
			return _card_resolution_active_entry()
		&"card_resolution_sequence":
			return _card_resolution_sequence_value()
	return null


func _set(property: StringName, value: Variant) -> bool:
	var service := _card_resolution_queue_service_node()
	var monster_controller := _monster_runtime_controller_node()
	var military_controller := _military_runtime_controller_node()
	match property:
		&"military_units":
			if value is Array and military_controller != null:
				military_controller.military_units = (value as Array).duplicate(true)
				return true
		&"next_military_unit_uid":
			if (value is int or value is float) and military_controller != null:
				military_controller.next_military_unit_uid = maxi(1, int(value))
				return true
		&"auto_monsters":
			if value is Array and monster_controller != null:
				monster_controller.auto_monsters = (value as Array).duplicate(true)
				for index in range(monster_controller.auto_monsters.size()):
					if monster_controller.auto_monsters[index] is Dictionary:
						(monster_controller.auto_monsters[index] as Dictionary)["slot"] = index
				return true
		&"next_auto_monster_uid":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.next_auto_monster_uid = maxi(1, int(value))
				return true
		&"next_special_monster_slot":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.next_special_monster_slot = int(value)
				return true
		&"selected_auto_monster_slot":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.selected_auto_monster_slot = int(value)
				return true
		&"monster_timer":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.monster_timer = maxf(0.0, float(value))
				return true
		&"special_monster_timer":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.special_monster_timer = maxf(0.0, float(value))
				return true
		&"card_resolution_queue":
			if value is Array and service != null and service.has_method("replace_current_queue"):
				service.call("replace_current_queue", (value as Array).duplicate(true))
				return true
		&"next_card_resolution_queue":
			if value is Array and service != null and service.has_method("replace_next_queue"):
				service.call("replace_next_queue", (value as Array).duplicate(true))
				return true
		&"active_card_resolution":
			if value is Dictionary and service != null and service.has_method("replace_active_entry"):
				service.call("replace_active_entry", (value as Dictionary).duplicate(true))
				return true
		&"card_resolution_sequence":
			if (value is int or value is float) and service != null and service.has_method("replace_resolution_sequence"):
				service.call("replace_resolution_sequence", int(value))
				return true
	return false


func _codex_navigation_controller_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("CodexNavigationRuntimeController") if coordinator != null else null


func _mark_game_runtime_coordinator_missing(report_error: bool = false) -> void:
	game_runtime_coordinator_missing = true
	if report_error and not game_runtime_coordinator_missing_reported:
		game_runtime_coordinator_missing_reported = true
		push_error("GameRuntimeCoordinator is required; forced-decision priority has no legacy fallback.")


func _bind_game_runtime_coordinator() -> void:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("configure") or not coordinator.has_method("debug_snapshot"):
		_mark_game_runtime_coordinator_missing(true)
		return
	if coordinator.has_method("bind_ai_world"):
		coordinator.call("bind_ai_world", self)
	coordinator.call("configure", _ruleset_runtime_debug_snapshot())
	monster_runtime_controller = coordinator.call("monster_runtime_controller") as MonsterRuntimeController if coordinator.has_method("monster_runtime_controller") else null
	military_runtime_controller = coordinator.call("military_runtime_controller") as MilitaryRuntimeController if coordinator.has_method("military_runtime_controller") else null
	weather_runtime_controller = coordinator.call("weather_runtime_controller") as WeatherRuntimeController if coordinator.has_method("weather_runtime_controller") else null
	if monster_runtime_controller == null or military_runtime_controller == null or weather_runtime_controller == null:
		_mark_game_runtime_coordinator_missing(true)
		return
	var snapshot_variant: Variant = coordinator.call("debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var required_ready := bool(snapshot.get("coordinator_ready", false)) if not _game_runtime_coordinator_node().world_session_state().players.is_empty() else bool(snapshot.get("coordinator_composition_ready", false))
	if not required_ready:
		_mark_game_runtime_coordinator_missing(true)
		return
	game_runtime_coordinator_bound = true
	game_runtime_coordinator_missing = false
	game_runtime_coordinator_missing_reported = false


func _card_resolution_controller_node() -> Node:
	if card_resolution_runtime_controller != null and is_instance_valid(card_resolution_runtime_controller):
		return card_resolution_runtime_controller
	card_resolution_runtime_controller = null
	card_resolution_runtime_controller_bound = false
	var found := _game_runtime_coordinator_node().get_node_or_null("CardResolutionRuntimeController")
	if found != null:
		card_resolution_runtime_controller = found
	return card_resolution_runtime_controller


func _mark_card_resolution_controller_missing(context: String, report_error: bool = false) -> void:
	card_resolution_controller_missing = true
	card_resolution_controller_missing_context = context
	if report_error and not card_resolution_controller_missing_reported:
		card_resolution_controller_missing_reported = true
		push_error("CardResolutionRuntimeController is required for %s; no legacy timing fallback is available." % context)


func _card_resolution_controller_value(property_name: StringName, default_value: Variant) -> Variant:
	var controller := _card_resolution_controller_node()
	if controller == null:
		_mark_card_resolution_controller_missing("read %s" % property_name)
		return default_value
	return controller.get(property_name)


func _set_card_resolution_controller_value(property_name: StringName, value: Variant) -> void:
	var controller := _card_resolution_controller_node()
	if controller == null:
		_mark_card_resolution_controller_missing("write %s" % property_name, true)
		return
	controller.set(property_name, value)


func _bind_card_resolution_runtime_controller() -> void:
	var controller := _card_resolution_controller_node()
	if controller == null:
		_mark_card_resolution_controller_missing("runtime binding", true)
		return
	var card_group_rules := _card_group_runtime_rules()
	if card_group_rules.is_empty():
		_mark_game_runtime_coordinator_missing(true)
		return
	if controller.has_method("configure"):
		controller.call("configure", {
			"total_window_seconds": float(card_group_rules.get("group_seconds", controller.get("total_window_seconds"))),
			"planning_seconds": float(card_group_rules.get("planning_seconds", card_group_rules.get("organize_seconds", controller.get("planning_seconds")))),
			"public_bid_seconds": float(card_group_rules.get("public_bid_seconds", controller.get("public_bid_seconds"))),
			"lock_seconds": float(card_group_rules.get("lock_seconds", controller.get("lock_seconds"))),
			"opening_extended_windows": int(card_group_rules.get("opening_extended_windows", controller.get("opening_extended_windows"))),
			"opening_total_window_seconds": float(card_group_rules.get("opening_group_seconds", controller.get("opening_total_window_seconds"))),
			"opening_planning_seconds": float(card_group_rules.get("opening_planning_seconds", controller.get("opening_planning_seconds"))),
			"display_seconds": CARD_RESOLUTION_DISPLAY_SECONDS,
			"counter_seconds": _card_counter_response_duration(),
		})
	card_resolution_runtime_controller_bound = true
	card_resolution_controller_missing = false
	card_resolution_controller_missing_context = ""
	card_resolution_controller_missing_reported = false


func _bind_runtime_game_screen(screen: Control) -> void:
	if screen == null:
		return
	runtime_game_screen = screen
	runtime_game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	runtime_game_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	runtime_game_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _runtime_overlay_parent() -> Node:
	if runtime_game_screen != null and runtime_game_screen.has_method("get_overlay_host"):
		var host: Variant = runtime_game_screen.call("get_overlay_host")
		if host is Node:
			var runtime_surface := (host as Node).get_node_or_null("RuntimeSurfaceLayer")
			return runtime_surface if runtime_surface != null else host
	return self


func _runtime_composition_control(node_name: String) -> Control:
	if runtime_game_screen != null:
		var screen_match := runtime_game_screen.find_child(node_name, true, false) as Control
		if screen_match != null:
			return screen_match
	return find_child(node_name, true, false) as Control


func _build_runtime_map_view() -> void:
	if map_view == null:
		map_view = _embedded_runtime_planet_map_view()
	if map_view == null:
		_report_required_ui_scene_missing("PlanetMapView", "district_selected/district_double_clicked")
		return
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if runtime_game_screen != null and runtime_game_screen.has_method("attach_runtime_map"):
		runtime_game_screen.call("attach_runtime_map", map_view)
	else:
		_report_required_ui_scene_missing("RuntimeGameScreen", "attach_runtime_map")
	map_view.custom_minimum_size = Vector2(560, 430)


func _embedded_runtime_planet_map_view() -> Control:
	if runtime_game_screen != null and runtime_game_screen.has_method("get_embedded_map_view"):
		var embedded_variant: Variant = runtime_game_screen.call("get_embedded_map_view")
		if embedded_variant is Control:
			return embedded_variant as Control
	if runtime_game_screen != null:
		var found := runtime_game_screen.find_child("PlanetMapView", true, false) as Control
		if found != null:
			return found
	return null


func _build_layout() -> void:
	_bind_sceneized_runtime_composition()
	_build_runtime_game_screen()
	if runtime_game_screen == null:
		push_error("RuntimeGameScreen scene is required; legacy runtime table construction has been retired.")
		return
	_build_runtime_map_view()
	_build_full_map_overlay()
	_game_runtime_coordinator_node().request_table_presentation_refresh(&"full", &"main_state_changed")


func _card_resolution_entry_by_id(resolution_id: int) -> Dictionary:
	var service := _card_resolution_queue_service_node()
	if service != null and service.has_method("entry_by_id"):
		var queued_variant: Variant = service.call("entry_by_id", resolution_id)
		if queued_variant is Dictionary and not (queued_variant as Dictionary).is_empty():
			return (queued_variant as Dictionary).duplicate(true)
	return _game_runtime_coordinator_node().card_resolution_history_entry(resolution_id)


func _store_card_resolution_entry(entry: Dictionary) -> bool:
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	if resolution_id < 0:
		return false
	var service := _card_resolution_queue_service_node()
	if service != null and service.has_method("store_entry") and bool(service.call("store_entry", entry.duplicate(true))):
		return true
	return bool(_game_runtime_coordinator_node().patch_card_resolution_history_entry(resolution_id, entry).get("patched", false))


func _build_full_map_overlay() -> void:
	if full_map_overlay != null and is_instance_valid(full_map_overlay):
		return
	var overlay := _runtime_composition_control("FullscreenMapOverlay")
	if overlay == null:
		_report_required_ui_scene_missing("FullscreenMapOverlay", "static OverlayLayer composition")
		return
	full_map_overlay = overlay

	var map_control_toolbar := overlay.find_child("PlanetMapControlToolbar", true, false) as Control
	if map_control_toolbar == null or not map_control_toolbar.has_method("set_controls"):
		_report_required_ui_scene_missing("PlanetMapControlToolbar", "set_controls")
	var close_button := overlay.find_child("FullscreenMapCloseButton", true, false) as Button
	var close_callable := Callable(self, "_close_fullscreen_map")
	if close_button != null and not close_button.pressed.is_connected(close_callable):
		close_button.pressed.connect(close_callable)

	fullscreen_map_hud_labels = {
		"layer": overlay.find_child("FullscreenMapLayerHudLabel", true, false) as Label,
		"product": overlay.find_child("FullscreenMapProductHudLabel", true, false) as Label,
		"district": overlay.find_child("FullscreenMapDistrictHudLabel", true, false) as Label,
		"hint": overlay.find_child("FullscreenMapHintHudLabel", true, false) as Label,
	}

	full_map_view = overlay.find_child("FullscreenPlanetMapView", true, false) as Control
	if full_map_view == null:
		_report_required_ui_scene_missing("FullscreenPlanetMapView", "district_selected/district_double_clicked")
		return
	full_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _map_layer_focus_entries() -> Array:
	return [
		{"id": "all", "label": "全", "text": "全图", "accent": "#fef3c7", "tip": "显示全部公开地图信息。"},
		{"id": "product", "label": "◇", "text": "商品", "accent": "#4ade80", "tip": "商品/供需读图：看区域产需、牌架和当前商品线索。"},
		{"id": "route", "label": "⇄", "text": "商路", "accent": "#f59e0b", "tip": "商路读图：突出当前商品的运输路径和路线节点。"},
		{"id": "intel", "label": "?", "text": "情报", "accent": "#60a5fa", "tip": "情报读图：突出城市归属猜测和公开线索，不显示隐藏真相。"},
		{"id": "weather", "label": "☄", "text": "天气", "accent": "#38bdf8", "tip": "天气读图：突出预报/天气/区域效果，便于提前决策。"},
		{"id": "monster", "label": "◆", "text": "怪兽", "accent": "#fb7185", "tip": "怪兽读图：突出怪兽、移动轨迹、战斗和破坏演出。"},
		{"id": "city", "label": "▣", "text": "城市", "accent": "#c084fc", "tip": "城市读图：突出城市、GDP风险和建设/破坏状态。"},
	]


func _map_layer_entry(layer_id: String) -> Dictionary:
	for entry_variant in _map_layer_focus_entries():
		var entry := entry_variant as Dictionary
		if String(entry.get("id", "")) == layer_id:
			return entry
	return (_map_layer_focus_entries()[0] as Dictionary).duplicate(true)


func _map_layer_focus_label(layer_id: String) -> String:
	return String(_map_layer_entry(layer_id).get("text", "全图"))


func _map_control_toolbar_snapshot() -> Dictionary:
	var district_status := _selected_district_status_text(_runtime_snapshot_player_index()) if _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size() else "当前未选择区域。"
	var product_options: Array = [{"id": "", "label": "商路关闭", "disabled": false}]
	for product_variant: Variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var product_id := str(product_variant)
		product_options.append({"id": product_id, "label": product_id, "disabled": false})
	var trade_text := "⇄ 商路关"
	var trade_tooltip := "当前地图不显示商品运输路径。"
	if _game_runtime_coordinator_node().table_selection_state().selected_trade_product != "":
		var route_count := _route_network_routes_for_product(_game_runtime_coordinator_node().table_selection_state().selected_trade_product).size()
		trade_text = "⇄ %s｜%d" % [_short_card_text(_game_runtime_coordinator_node().table_selection_state().selected_trade_product, 6), route_count]
		trade_tooltip = "当前显示%s的运输路径，共%d条。" % [_game_runtime_coordinator_node().table_selection_state().selected_trade_product, route_count]
	var selected_layer := _map_layer_entry(_game_runtime_coordinator_node().table_selection_state().selected_map_layer_focus)
	return {
		"reading_hints": [
			{"text": "◎ 赌桌中央", "tooltip": "星球保持主视野；信息尽量收进筹码、牌架和侧栏。"},
			{"text": "滚轮缩放", "tooltip": "滚轮拉近看局部地表，拉远看星球。"},
			{"text": "拖拽地图", "tooltip": "拖拽平移地表或调整星球视角。"},
			{"text": "双击看牌", "tooltip": "双击区域打开牌架；查看始终允许，显式选择后才锁定5秒日照资格与价格。"},
		],
		"district_status": {"text": "⌖ %s" % _short_card_text(district_status, 18), "tooltip": district_status},
		"layers": _map_layer_focus_entries(),
		"selected_layer_id": _game_runtime_coordinator_node().table_selection_state().selected_map_layer_focus,
		"layer_status": {"text": "图层:%s" % _map_layer_focus_label(_game_runtime_coordinator_node().table_selection_state().selected_map_layer_focus), "tooltip": str(selected_layer.get("tip", "当前地图图层焦点。"))},
		"trade": {
			"options": product_options,
			"selected_product_id": _game_runtime_coordinator_node().table_selection_state().selected_trade_product,
			"disabled": false,
			"tooltip": "选择要在地图上显示运输路径的商品。",
			"status": {"text": trade_text, "tooltip": trade_tooltip},
		},
	}


func _menu_card_style(accent: Color, fill: Color = Color("#0b1220"), border_width: int = 1, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _report_required_ui_scene_missing(component_name: String, required_method: String) -> void:
	push_error("%s is a required scenes/ui component and must expose %s; refusing to rebuild this player-facing page through legacy main.gd controls." % [component_name, required_method])


func _final_settlement_runtime_composition_node() -> Node:
	return get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition")


func _first_entries(entries: Array, limit: int) -> Array:
	var result := []
	for i in range(min(limit, entries.size())):
		result.append(entries[i])
	return result


func _latest_city_public_clue_text(city: Dictionary) -> String:
	var public_clues := city.get("public_clues", []) as Array
	if not public_clues.is_empty():
		for i in range(public_clues.size() - 1, -1, -1):
			var clue_text := _city_public_clue_display_text(public_clues[i])
			if clue_text != "":
				return clue_text
	var last_clue := String(city.get("last_public_clue", ""))
	return last_clue if last_clue != "" else "暂无公开线索"


func _product_public_status_tags(product_name: String) -> Array:
	var entry := _product_market_entry_snapshot(product_name)
	if entry.is_empty():
		return []
	var tags := []
	var growth_multiplier := float(entry.get("growth_multiplier", 1.0))
	if growth_multiplier > 1.001:
		tags.append("增速×%.2f/%s" % [
			growth_multiplier,
			_boon_duration_text(_remaining_effect_seconds(entry, "growth_seconds", "growth_turns")),
		])
	var route_multiplier := float(entry.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		tags.append("商路×%.2f/%s" % [
			route_multiplier,
			_boon_duration_text(_remaining_effect_seconds(entry, "route_flow_seconds", "route_flow_turns")),
		])
	var contract_seconds := _remaining_effect_seconds(entry, "market_contract_seconds", "market_contract_turns")
	var contract_demand := int(entry.get("market_contract_demand", 0))
	var contract_supply := int(entry.get("market_contract_supply", 0))
	if contract_seconds > 0.0 and (contract_demand > 0 or contract_supply > 0):
		var pressure_parts := []
		if contract_demand > 0:
			pressure_parts.append("需+%d" % contract_demand)
		if contract_supply > 0:
			pressure_parts.append("供+%d" % contract_supply)
		tags.append("商品合约%s/%s" % [
			"/".join(pressure_parts),
			_boon_duration_text(contract_seconds),
		])
	var volatility := int(entry.get("volatility", 0))
	if volatility >= 12:
		tags.append("高波动%d" % volatility)
	var futures_text := _product_market_futures_public_text(product_name, true)
	if futures_text != "":
		tags.append(futures_text)
	return tags


func _city_public_status_tags(city: Dictionary) -> Array:
	var tags := []
	var contract_income := int(city.get("contract_income_bonus", 0))
	if contract_income > 0:
		tags.append("城市合约+%d/%s" % [
			contract_income,
			_boon_duration_text(_remaining_effect_seconds(city, "contract_seconds", "contract_turns")),
		])
	var route_multiplier := float(city.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		tags.append("流通×%.2f/%s" % [
			route_multiplier,
			_boon_duration_text(_remaining_effect_seconds(city, "route_flow_seconds", "route_flow_turns")),
		])
	var disrupted := int(city.get("trade_disrupted_routes", 0))
	if disrupted > 0:
		tags.append("断路%d" % disrupted)
	var competition := int(city.get("competition_matches", 0))
	if competition > 0:
		tags.append("竞争%d" % competition)
	var revenue_bonus := int(city.get("revenue_bonus", 0))
	if revenue_bonus > 0:
		tags.append("永久收入+%d" % revenue_bonus)
	var warehouse_text := _city_warehouse_stockpile_status_text(city)
	if warehouse_text != "":
		tags.append(warehouse_text)
	return tags


func _menu_action_accent_for_text(button_text: String) -> Color:
	if button_text.contains("经济"):
		return Color("#4ade80")
	if button_text.contains("情报") or button_text.contains("角色"):
		return Color("#c084fc")
	if button_text.contains("卡牌"):
		return Color("#f472b6")
	if button_text.contains("怪兽"):
		return Color("#fb7185")
	if button_text.contains("商品"):
		return Color("#facc15")
	if button_text.contains("区域") or button_text.contains("地图"):
		return Color("#38bdf8")
	if button_text.contains("开局"):
		return Color("#67e8f9")
	return Color("#93c5fd")


func _order_entries_by_victory_rank(entries: Array) -> Array:
	var by_player := {}
	for entry_variant in entries:
		if entry_variant is Dictionary:
			by_player[str(int((entry_variant as Dictionary).get("player_index", -1)))] = (entry_variant as Dictionary).duplicate(true)
	var ordered: Array = []
	for ranking_variant in _victory_control_rankings():
		if not (ranking_variant is Dictionary):
			continue
		var key := str(int((ranking_variant as Dictionary).get("player_index", -1)))
		if by_player.has(key):
			ordered.append(by_player[key])
			by_player.erase(key)
	for entry_variant in entries:
		var key := str(int((entry_variant as Dictionary).get("player_index", -1))) if entry_variant is Dictionary else ""
		if by_player.has(key):
			ordered.append(by_player[key])
			by_player.erase(key)
	return ordered


func _player_gdp_per_minute(player_index: int) -> int:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return 0
	var total := 0
	for district_index in range(_game_runtime_coordinator_node().world_session_state().districts.size()):
		var region_id := str((_game_runtime_coordinator_node().world_session_state().districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
		var region_snapshot_variant: Variant = _commodity_flow_runtime_call("region_gdp_snapshot", [region_id])
		if not (region_snapshot_variant is Dictionary):
			continue
		var by_player: Dictionary = (region_snapshot_variant as Dictionary).get("player_gdp_per_minute_cents_by_index", {}) if (region_snapshot_variant as Dictionary).get("player_gdp_per_minute_cents_by_index", {}) is Dictionary else {}
		total += int(round(float(int(by_player.get(str(player_index), 0))) / 100.0))
	return total


func _player_commodity_sale_income(player_index: int) -> int:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size() or not (_game_runtime_coordinator_node().world_session_state().players[player_index] is Dictionary):
		return 0
	var total_cents := 0
	for row_variant in (_game_runtime_coordinator_node().world_session_state().players[player_index] as Dictionary).get("v06_transaction_ledger", []):
		if row_variant is Dictionary and str((row_variant as Dictionary).get("category", "")) == "commodity_sale":
			total_cents += maxi(0, int((row_variant as Dictionary).get("ledger_delta_cents", 0)))
	return int(floor(float(total_cents) / 100.0))


func _player_intel_stats(player_index: int) -> Dictionary:
	var stats := {
		"total_foreign": 0,
		"guessed": 0,
		"correct": 0,
		"wrong": 0,
		"unmarked": 0,
		"cash": 0,
	}
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return stats
	var player: Dictionary = _game_runtime_coordinator_node().world_session_state().players[player_index]
	var guesses: Dictionary = player.get("city_guesses", {})
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var city_owner := int(city.get("owner", -1))
		if city_owner < 0 or city_owner == player_index:
			continue
		stats["total_foreign"] = int(stats["total_foreign"]) + 1
		if not guesses.has(city_index):
			stats["unmarked"] = int(stats["unmarked"]) + 1
			continue
		var guessed_owner := int(guesses.get(city_index, -1))
		if guessed_owner < 0:
			stats["unmarked"] = int(stats["unmarked"]) + 1
			continue
		stats["guessed"] = int(stats["guessed"]) + 1
		if guessed_owner == city_owner:
			stats["correct"] = int(stats["correct"]) + 1
		else:
			stats["wrong"] = int(stats["wrong"]) + 1
	var role := _player_role_card_for_index(player_index)
	var correct_reward := INTEL_CORRECT_GUESS_CASH + maxi(0, int(role.get("city_guess_reward_bonus", 0)))
	stats["correct_reward"] = correct_reward
	stats["cash"] = int(stats["correct"]) * correct_reward - int(stats["wrong"]) * INTEL_WRONG_GUESS_COST
	return stats


func _player_intel_summary(player_index: int) -> String:
	var stats := _player_intel_stats(player_index)
	return "情报现金%s = 猜对%d×¥%d - 猜错%d×¥%d｜已标%d/%d" % [
		_signed_int_text(int(stats.get("cash", 0))),
		int(stats.get("correct", 0)),
		int(stats.get("correct_reward", INTEL_CORRECT_GUESS_CASH)),
		int(stats.get("wrong", 0)),
		INTEL_WRONG_GUESS_COST,
		int(stats.get("guessed", 0)),
		int(stats.get("total_foreign", 0)),
	]


func _player_intel_exposure_stats(player_index: int) -> Dictionary:
	var stats := {
		"total_foreign": 0,
		"guessed": 0,
		"unmarked": 0,
		"best_cash": 0,
		"worst_cash": 0,
	}
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return stats
	var player: Dictionary = _game_runtime_coordinator_node().world_session_state().players[player_index]
	var guesses: Dictionary = player.get("city_guesses", {})
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var city_owner := int(city.get("owner", -1))
		if city_owner < 0 or city_owner == player_index:
			continue
		stats["total_foreign"] = int(stats["total_foreign"]) + 1
		var guessed_owner := int(guesses.get(city_index, -1))
		if guessed_owner >= 0:
			stats["guessed"] = int(stats["guessed"]) + 1
		else:
			stats["unmarked"] = int(stats["unmarked"]) + 1
	stats["best_cash"] = int(stats["guessed"]) * INTEL_CORRECT_GUESS_CASH
	stats["worst_cash"] = -int(stats["guessed"]) * INTEL_WRONG_GUESS_COST
	return stats


func _player_intel_pending_summary(player_index: int) -> String:
	var stats := _player_intel_exposure_stats(player_index)
	return "情报待结算：已标%d/%d｜全对%s / 全错%s｜终局揭晓" % [
		int(stats.get("guessed", 0)),
		int(stats.get("total_foreign", 0)),
		_signed_int_text(int(stats.get("best_cash", 0))),
		_signed_int_text(int(stats.get("worst_cash", 0))),
	]


func _player_intel_display_summary(player_index: int) -> String:
	return _player_intel_summary(player_index) if _runtime_session_finished() else _player_intel_pending_summary(player_index)


func _player_name(player_index: int) -> String:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return "未知玩家"
	return String((_game_runtime_coordinator_node().world_session_state().players[player_index] as Dictionary).get("name", "玩家%d" % (player_index + 1)))


func _player_is_eliminated(player_index: int) -> bool:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return true
	return bool((_game_runtime_coordinator_node().world_session_state().players[player_index] as Dictionary).get("eliminated", false))


func _runtime_session_finished() -> bool:
	var coordinator := _game_runtime_coordinator_node()
	return bool(coordinator.call("session_is_finished")) if coordinator != null and coordinator.has_method("session_is_finished") else false


func _victory_control_public_snapshot() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var value: Variant = coordinator.call("victory_control_public_snapshot", _runtime_snapshot_player_index()) if coordinator != null and coordinator.has_method("victory_control_public_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _victory_control_private_snapshot(player_index: int) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var value: Variant = coordinator.call("victory_control_private_snapshot", player_index) if coordinator != null and coordinator.has_method("victory_control_private_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _victory_control_is_active() -> bool:
	return str(_victory_control_public_snapshot().get("state", "idle")) in ["qualification", "audit"]


func _victory_control_timer_visible() -> bool:
	return str(_victory_control_public_snapshot().get("state", "idle")) in ["qualification", "audit"]


func _victory_control_remaining_seconds() -> float:
	var snapshot := _victory_control_public_snapshot()
	match str(snapshot.get("state", "idle")):
		"qualification":
			return maxf(0.0, float(snapshot.get("qualification_remaining_seconds", 0.0)))
		"audit":
			return maxf(0.0, float(snapshot.get("audit_remaining_seconds", 0.0)))
	return 0.0


func _victory_control_total_seconds() -> float:
	var coordinator := _game_runtime_coordinator_node()
	var controller: Node = coordinator.call("victory_control_runtime_controller") if coordinator != null and coordinator.has_method("victory_control_runtime_controller") else null
	if controller == null or not controller.has_method("timer_duration"):
		return 1.0
	var state := str(_victory_control_public_snapshot().get("state", "idle"))
	var timer_id := "public_audit" if state == "audit" else "victory_qualification"
	return maxf(1.0, float(controller.call("timer_duration", timer_id)))


func _victory_dynamic_rule() -> Dictionary:
	var public_rule_variant: Variant = _victory_control_public_snapshot().get("victory_rule", {})
	if public_rule_variant is Dictionary and not (public_rule_variant as Dictionary).is_empty():
		return (public_rule_variant as Dictionary).duplicate(true)
	var coordinator := _game_runtime_coordinator_node()
	var controller: Node = coordinator.call("victory_control_runtime_controller") if coordinator != null and coordinator.has_method("victory_control_runtime_controller") else null
	var world_snapshot: Dictionary = coordinator.call("victory_control_world_snapshot") if coordinator != null and coordinator.has_method("victory_control_world_snapshot") else {}
	var value: Variant = controller.call("victory_rule_for_world", world_snapshot) if controller != null and controller.has_method("victory_rule_for_world") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _victory_required_gdp() -> int:
	return int(_victory_dynamic_rule().get("required_top_k_gdp_per_minute", 0))


func _victory_required_regions() -> int:
	return int(_victory_dynamic_rule().get("required_region_count", 0))


func _victory_player_candidate(player_index: int) -> Dictionary:
	var snapshot := _victory_control_private_snapshot(player_index)
	var candidate_variant: Variant = snapshot.get("own_candidate", {})
	return (candidate_variant as Dictionary).duplicate(true) if candidate_variant is Dictionary else {}


func _victory_player_progress_metric(player_index: int) -> int:
	return int(_victory_player_candidate(player_index).get("top_n_gdp_per_minute", 0))


func _victory_control_rankings() -> Array:
	var coordinator := _game_runtime_coordinator_node()
	var receipt: Dictionary = coordinator.call("victory_control_outcome_receipt") if coordinator != null and coordinator.has_method("victory_control_outcome_receipt") else {}
	if receipt.get("rankings", []) is Array and not (receipt.get("rankings", []) as Array).is_empty():
		return (receipt.get("rankings", []) as Array).duplicate(true)
	var value: Variant = coordinator.call("victory_control_rankings", false) if coordinator != null and coordinator.has_method("victory_control_rankings") else []
	return (value as Array).duplicate(true) if value is Array else []


func _victory_control_status_text() -> String:
	var snapshot := _victory_control_public_snapshot()
	var rule: Dictionary = snapshot.get("victory_rule", {}) if snapshot.get("victory_rule", {}) is Dictionary else _victory_dynamic_rule()
	if bool(rule.get("ordinary_victory_paused", false)):
		return "胜利资格：全部区域为废墟，等待复兴"
	var target := "控制%d区且前K区商品GDP/min达到%d" % [int(rule.get("required_region_count", 0)), int(rule.get("required_top_k_gdp_per_minute", 0))]
	match str(snapshot.get("state", "idle")):
		"qualification":
			return "胜利资格：确认中 %.1fs｜%s" % [_victory_control_remaining_seconds(), target]
		"audit":
			return "公开审计：%.1fs｜经济资产公开核验" % _victory_control_remaining_seconds()
		"resolved":
			return "胜利审计：已完成"
	return "胜利资格：%s" % target


func _open_fullscreen_map() -> void:
	if full_map_overlay == null:
		return
	full_map_overlay.visible = true
	_refresh_map_controls()
	_game_runtime_coordinator_node().request_table_presentation_refresh(&"map", &"main_state_changed")


func _close_fullscreen_map() -> void:
	if full_map_overlay == null:
		return
	full_map_overlay.visible = false
	_game_runtime_coordinator_node().request_table_presentation_refresh(&"map", &"main_state_changed")


func _codex_role_route_label(role_card: Dictionary) -> String:
	var coordinator := _game_runtime_coordinator_node()
	return str(coordinator.call("codex_role_route_label", role_card.duplicate(true), _role_starting_cash_delta(role_card))) if coordinator != null and coordinator.has_method("codex_role_route_label") else "通用经营"


func _product_count_summary(counts: Dictionary, limit: int = 4, empty_text: String = "暂无") -> String:
	var entries := []
	for key_variant in counts.keys():
		var key := String(key_variant)
		entries.append({"label": key, "count": int(counts.get(key, 0))})
	entries.sort_custom(Callable(self, "_sort_product_count_entry_desc"))
	var pieces := []
	for i in range(mini(limit, entries.size())):
		var entry := entries[i] as Dictionary
		pieces.append("%s×%d" % [String(entry.get("label", "")), int(entry.get("count", 0))])
	return " / ".join(pieces) if not pieces.is_empty() else empty_text


func _sort_product_count_entry_desc(a: Dictionary, b: Dictionary) -> bool:
	var count_a := int(a.get("count", 0))
	var count_b := int(b.get("count", 0))
	if count_a != count_b:
		return count_a > count_b
	return String(a.get("label", "")) < String(b.get("label", ""))


func _product_strategy_scores(product_name: String) -> Dictionary:
	_product_market_runtime_call("ensure_catalog")
	var entry := _product_market_entry_snapshot(product_name)
	var supply := int(entry.get("supply", 0))
	var demand := int(entry.get("demand", 0))
	var disrupted := int(entry.get("disrupted", 0))
	var volatility := int(entry.get("volatility", 0))
	var temporary_demand := int(entry.get("temporary_demand_pressure", 0))
	var temporary_supply := int(entry.get("temporary_supply_pressure", 0))
	var contract_seconds := _remaining_effect_seconds(entry, "market_contract_seconds", "market_contract_turns")
	var contract_demand := int(entry.get("market_contract_demand", 0)) if contract_seconds > 0.0 else 0
	var contract_supply := int(entry.get("market_contract_supply", 0)) if contract_seconds > 0.0 else 0
	var futures := _product_market_futures_public_counts(product_name)
	var warehouse_units := int(futures.get("warehouse_units", 0))
	var monster_focus_count := _product_monster_focus_count(product_name)
	var growth_bonus := int(round(maxf(0.0, float(entry.get("growth_multiplier", 1.0)) - 1.0) * 40.0))
	var route_bonus := int(round(maxf(0.0, float(entry.get("route_flow_multiplier", 1.0)) - 1.0) * 32.0))
	var long_score := maxi(0, demand - supply) * 14 + demand * 3 + disrupted * 10 + temporary_demand * 8 + contract_demand * 9 + growth_bonus + int(futures.get("up", 0)) * 3
	var short_score := maxi(0, supply - demand) * 14 + supply * 3 + temporary_supply * 8 + contract_supply * 9 + volatility * 2 + int(futures.get("down", 0)) * 3
	var stockpile_score := long_score + volatility * 4 + warehouse_units * 5 + route_bonus
	var route_score := (supply + demand) * 6 + route_bonus + disrupted * 4 + contract_demand * 3 + contract_supply * 3
	var monster_risk_score := monster_focus_count * 18 + warehouse_units * 7 + disrupted * 3
	return {
		"long": maxi(0, long_score),
		"short": maxi(0, short_score),
		"stockpile": maxi(0, stockpile_score),
		"route": maxi(0, route_score),
		"monster": maxi(0, monster_risk_score),
		"supply": supply,
		"demand": demand,
		"disrupted": disrupted,
		"volatility": volatility,
	}


func _product_strategy_rankings(product_name: String) -> Array:
	var scores := _product_strategy_scores(product_name)
	var ranked := [
		{"label": "看涨", "score": int(scores.get("long", 0)), "hint": "需求、断路、合约或成长天气正在支撑价格。"},
		{"label": "看跌", "score": int(scores.get("short", 0)), "hint": "供给、套保或供给压力较强，适合压价。"},
		{"label": "囤货", "score": int(scores.get("stockpile", 0)), "hint": "波动和看涨空间适合港仓囤货，但仓库会变成公开靶标。"},
		{"label": "商路", "score": int(scores.get("route", 0)), "hint": "供需两端和流通速度适合合约、交通和城市GDP路线。"},
		{"label": "怪兽风险", "score": int(scores.get("monster", 0)), "hint": "偏好该商品的怪兽或仓储压力会增加被引怪概率。"},
	]
	ranked.sort_custom(Callable(self, "_sort_product_strategy_score_desc"))
	return ranked


func _product_primary_strategy_entry(product_name: String) -> Dictionary:
	var ranked := _product_strategy_rankings(product_name)
	if ranked.is_empty():
		return {"label": "观察", "score": 0, "hint": "观察供需变化。"}
	return ranked[0] as Dictionary


func _sort_product_strategy_score_desc(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("score", 0))
	var score_b := int(b.get("score", 0))
	if score_a != score_b:
		return score_a > score_b
	return String(a.get("label", "")) < String(b.get("label", ""))


func _product_monster_focus_count(product_name: String) -> int:
	var count := 0
	for monster_variant in MonsterCatalogV06.roster():
		var monster: Dictionary = monster_variant
		var focus: Array = monster.get("resource_focus", [])
		if focus.has(product_name):
			count += 1
	return count


func _product_profile(product_name: String) -> Dictionary:
	var profile: Dictionary = ProductMarketRuntimeController.PRODUCT_PROFILES.get(product_name, {})
	if not profile.is_empty():
		return profile
	return {
		"category": "未分类商品",
		"route": "通用商业线",
		"terrain": "随机区域",
		"use": "参与供需、商路、GDP和出牌门槛。",
		"hook": "等待后续平衡时补充专属机制。",
		"flavor": "一件还没有被星际商会充分命名的货物。",
		"glyph": "◇",
		"accent": Color("#22c55e"),
		"secondary": Color("#f8fafc"),
	}


func _product_profile_has_required_fields(product_name: String) -> bool:
	var profile := _product_profile(product_name)
	for key in ["category", "route", "terrain", "use", "hook", "flavor", "glyph", "accent", "secondary"]:
		if not profile.has(String(key)):
			return false
		if ["category", "route", "terrain", "use", "hook", "flavor", "glyph"].has(String(key)) and String(profile.get(String(key), "")) == "":
			return false
	return true


func _product_market_price_path_text(entry: Dictionary, limit: int = 7) -> String:
	var history: Array = entry.get("price_history", [])
	if history.is_empty():
		return str(int(entry.get("price", entry.get("base_price", 0))))
	var pieces := []
	var start_index: int = maxi(0, history.size() - maxi(2, limit))
	for i in range(start_index, history.size()):
		pieces.append(str(int(history[i])))
	return "→".join(pieces)


func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
	if names.is_empty():
		return empty_text
	var pieces := []
	for i in range(min(limit, names.size())):
		pieces.append(String(names[i]))
	if names.size() > limit:
		pieces.append("+%d" % (names.size() - limit))
	return "、".join(pieces)


func _record_player_cash_snapshot(player_index: int) -> void:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return
	var player: Dictionary = _game_runtime_coordinator_node().world_session_state().players[player_index]
	if not player.has("economic_ledger"):
		player["economic_ledger"] = []
	var history: Array = player.get("cash_history", [])
	var current_cash := int(player.get("cash", 0))
	if history.is_empty() or int(history[history.size() - 1]) != current_cash:
		history.append(current_cash)
	while history.size() > ECONOMY_HISTORY_LIMIT:
		history.pop_front()
	player["cash_history"] = history
	_game_runtime_coordinator_node().world_session_state().players[player_index] = player


func _record_player_economic_event(player_index: int, kind: String, label: String, amount: int, detail: String = "") -> void:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return
	var player: Dictionary = _game_runtime_coordinator_node().world_session_state().players[player_index]
	var ledger: Array = player.get("economic_ledger", [])
	ledger.append({
		"cycle": _product_market_cycle(),
		"time": _game_runtime_coordinator_node().world_session_state().game_time,
		"kind": kind,
		"label": label,
		"amount": amount,
		"cash_after": int(player.get("cash", 0)),
		"detail": detail,
	})
	while ledger.size() > ECONOMY_LEDGER_LIMIT:
		ledger.pop_front()
	player["economic_ledger"] = ledger
	_game_runtime_coordinator_node().world_session_state().players[player_index] = player


func _record_player_card_spend(player_index: int, amount: int, label: String = "卡牌支出", detail: String = "") -> void:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size() or amount <= 0:
		return
	_game_runtime_coordinator_node().world_session_state().players[player_index]["total_card_spend"] = int(_game_runtime_coordinator_node().world_session_state().players[player_index].get("total_card_spend", 0)) + amount
	_record_player_economic_event(player_index, "卡牌支出", label, -amount, detail)
	_record_player_cash_snapshot(player_index)


func _record_player_card_income(player_index: int, amount: int, label: String = "卡牌收入", detail: String = "") -> void:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size() or amount <= 0:
		return
	_game_runtime_coordinator_node().world_session_state().players[player_index]["total_card_income"] = int(_game_runtime_coordinator_node().world_session_state().players[player_index].get("total_card_income", 0)) + amount
	_record_player_economic_event(player_index, "卡牌收入", label, amount, detail)
	_record_player_cash_snapshot(player_index)


func _player_product_flow(player_index: int, product_name: String) -> int:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size() or product_name == "":
		return 0
	var flow := 0
	for city_index_variant in _ai_runtime_call("_active_city_indices_for_player", [player_index]):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		for product_variant in city.get("products", []):
			var product: Dictionary = product_variant
			if String(product.get("name", "")) == product_name:
				flow += maxi(1, int(product.get("level", 1)))
		for route_variant in city.get("trade_routes", []):
			var route: Dictionary = route_variant
			if bool(route.get("disrupted", false)):
				continue
			if String(route.get("product", "")) == product_name:
				flow += 1
		for demand_variant in city.get("demands", []):
			if String(demand_variant) == product_name:
				flow += 1
	return flow


func _first_player_flow_product(player_index: int) -> String:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return ""
	for city_index_variant in _ai_runtime_call("_active_city_indices_for_player", [player_index]):
		var city := _district_city(int(city_index_variant))
		var products := _city_product_names(city)
		if not products.is_empty():
			return String(products[0])
		var demands := _city_demand_names(city)
		if not demands.is_empty():
			return String(demands[0])
	return _game_runtime_coordinator_node().table_selection_state().selected_trade_product if _game_runtime_coordinator_node().table_selection_state().selected_trade_product != "" else (String(ProductMarketRuntimeController.PRODUCT_CATALOG[0]) if not ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty() else "")


func _best_player_flow_product(player_index: int, required: int = 1, preferred_products: Array = []) -> String:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return ""
	var safe_required: int = maxi(1, required)
	var seen := {}
	var preferred := []
	for product_variant in preferred_products:
		var product_name := String(product_variant)
		if product_name == "" or seen.has(product_name):
			continue
		seen[product_name] = true
		preferred.append(product_name)
	for product_variant in preferred:
		if _player_product_flow(player_index, String(product_variant)) >= safe_required:
			return String(product_variant)
	var best_product := ""
	var best_flow := -1
	for city_index_variant in _ai_runtime_call("_active_city_indices_for_player", [player_index]):
		var city := _district_city(int(city_index_variant))
		var products := _city_product_names(city)
		for product_variant in products:
			var product_name := String(product_variant)
			if product_name == "" or seen.has(product_name):
				continue
			seen[product_name] = true
			var flow := _player_product_flow(player_index, product_name)
			if flow >= safe_required and flow > best_flow:
				best_product = product_name
				best_flow = flow
		var demands := _city_demand_names(city)
		for demand_variant in demands:
			var demand_name := String(demand_variant)
			if demand_name == "" or seen.has(demand_name):
				continue
			seen[demand_name] = true
			var demand_flow := _player_product_flow(player_index, demand_name)
			if demand_flow >= safe_required and demand_flow > best_flow:
				best_product = demand_name
				best_flow = demand_flow
		for route_variant in city.get("trade_routes", []):
			var route: Dictionary = route_variant
			if bool(route.get("disrupted", false)):
				continue
			var route_product := String(route.get("product", ""))
			if route_product == "" or seen.has(route_product):
				continue
			seen[route_product] = true
			var route_flow := _player_product_flow(player_index, route_product)
			if route_flow >= safe_required and route_flow > best_flow:
				best_product = route_product
				best_flow = route_flow
	return best_product


func _card_play_eligibility_snapshot(player_index: int, skill: Dictionary, evaluation_mode: String = "rule", context: Dictionary = {}) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("card_play_world_facts") or not coordinator.has_method("evaluate_card_play"):
		_mark_game_runtime_coordinator_missing(true)
		return {"allowed": false, "actionable": false, "reason_code": "service_missing"}
	var facts_variant: Variant = coordinator.call("card_play_world_facts", player_index, skill, context)
	var facts: Dictionary = facts_variant if facts_variant is Dictionary else {}
	var value: Variant = coordinator.call("evaluate_card_play", {"player_index": player_index, "skill": skill, "evaluation_mode": evaluation_mode}, facts)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"allowed": false, "actionable": false, "reason_code": "service_missing"}


func _card_play_requirement_snapshot(player_index: int, skill: Dictionary, context: Dictionary = {}) -> Dictionary:
	var evaluation := _card_play_eligibility_snapshot(player_index, skill, "catalog", context)
	var value: Variant = evaluation.get("requirement_status", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_play_target_snapshot(skill: Dictionary) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("card_play_target_status"):
		return {}
	var value: Variant = coordinator.call("card_play_target_status", {"skill": skill}, {
		"player_count": _game_runtime_coordinator_node().world_session_state().players.size(),
		"monster_count": monster_runtime_controller.auto_monsters.size(),
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_play_presentation_snapshot(eligibility: Dictionary, skill: Dictionary = {}) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("compose_card_play_eligibility"):
		return {}
	var card_name := String(skill.get("name", "卡牌"))
	var value: Variant = coordinator.call("compose_card_play_eligibility", eligibility, {"card_name": card_name, "display_name": _card_display_name(card_name)})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _authorize_card_play(player_index: int, skill: Dictionary, show_log: bool = true, evaluation_mode: String = "rule") -> bool:
	var eligibility := _card_play_eligibility_snapshot(player_index, skill, evaluation_mode)
	if bool(eligibility.get("allowed", false)):
		return true
	if show_log:
		_log_card_play_rejection(eligibility, skill)
	return false


func _log_card_play_rejection(eligibility: Dictionary, skill: Dictionary) -> void:
	var presentation := _card_play_presentation_snapshot(eligibility, skill)
	var log_message := String(presentation.get("log_message", ""))
	if log_message != "":
		_game_runtime_coordinator_node().record_legacy_viewer_feedback(log_message)


func _skill_play_product(skill: Dictionary, player_index: int) -> String:
	# Compatibility/content-affinity helper. Products decide which planet/region
	# can offer a card; they are no longer the default cost paid to play it.
	var explicit := String(skill.get("play_product", ""))
	if explicit != "":
		return explicit
	if _game_runtime_coordinator_node().table_selection_state().selected_trade_product != "":
		return _game_runtime_coordinator_node().table_selection_state().selected_trade_product
	return _first_player_flow_product(player_index)


func _skill_play_flow_required(skill: Dictionary, _player_index: int = -1) -> int:
	# Deprecated compatibility hook. The live gate is regional GDP share; an
	# old fixed-product field may still be kept as supply affinity.
	return maxi(0, int(skill.get("play_flow_required", 0))) if bool(skill.get("legacy_flow_gate_enabled", false)) else 0
func _player_region_gdp_share_basis_points(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return 0
	var region_id := str((_game_runtime_coordinator_node().world_session_state().districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
	return int(_commodity_flow_runtime_call("player_region_gdp_share_basis_points", [player_index, region_id]))


func _best_player_gdp_share_district(player_index: int) -> int:
	var best_district := -1
	var best_share := -1
	var best_gdp := -1
	for district_index in range(_game_runtime_coordinator_node().world_session_state().districts.size()):
		var share := _player_region_gdp_share_basis_points(player_index, district_index)
		if share <= 0:
			continue
		var city := _district_city(district_index)
		var city_gdp := _city_gdp_per_minute(district_index, int(city.get("competition_matches", _city_competition_matches(district_index))))
		if share > best_share or (share == best_share and city_gdp > best_gdp):
			best_district = district_index
			best_share = share
			best_gdp = city_gdp
	return best_district


func _signed_int_text(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return "%d" % value


func _player_recent_cash_delta(player: Dictionary) -> int:
	var history: Array = player.get("cash_history", [])
	if history.size() < 2:
		return 0
	return int(history[history.size() - 1]) - int(history[history.size() - 2])


func _player_cash_path_text(player: Dictionary, limit: int = 7) -> String:
	var history: Array = player.get("cash_history", [])
	if history.is_empty():
		return str(int(player.get("cash", 0)))
	var pieces := []
	var start_index: int = maxi(0, history.size() - maxi(2, limit))
	for i in range(start_index, history.size()):
		pieces.append(str(int(history[i])))
	return "→".join(pieces)


func _player_cash_window_delta(player: Dictionary) -> int:
	var history: Array = player.get("cash_history", [])
	if history.size() < 2:
		return 0
	return int(history[history.size() - 1]) - int(history[0])


func _player_economic_ledger_text(player: Dictionary, limit: int = 4) -> String:
	var ledger: Array = player.get("economic_ledger", [])
	if ledger.is_empty():
		return "暂无"
	var pieces := []
	var start_index: int = maxi(0, ledger.size() - maxi(1, limit))
	for i in range(start_index, ledger.size()):
		var entry: Dictionary = ledger[i]
		var detail := String(entry.get("detail", ""))
		var detail_suffix := "｜%s" % detail if detail != "" else ""
		pieces.append("C%d %s%s：%s%s→%d" % [
			int(entry.get("cycle", 0)),
			String(entry.get("kind", "经济")),
			detail_suffix,
			_signed_int_text(int(entry.get("amount", 0))),
			" " + String(entry.get("label", "")) if String(entry.get("label", "")) != "" else "",
			int(entry.get("cash_after", 0)),
		])
	return "；".join(pieces)


func _card_price(skill_name: String, district_index: int = -1, player_index: int = -1) -> int:
	if skill_name.is_empty():
		return 0
	var price_name := "%s1" % _game_runtime_coordinator_node().card_family_id(skill_name)
	if not _game_runtime_coordinator_node().card_exists(price_name):
		price_name = skill_name
	var skill: Dictionary = _game_runtime_coordinator_node().card_definition(price_name)
	var base_price := int(_runtime_balance_model().call("card_price_for_skill", skill))
	if district_index < 0:
		return base_price
	var query := _game_runtime_coordinator_node().district_supply_runtime_query_port()
	var preview := query.public_price_preview(district_index, skill_name) if query != null else {}
	return int(preview.get("final_price", base_price))


func _runtime_balance_model() -> RefCounted:
	return RuntimeBalanceModelScript.new()


func _balance_product_price_step_cap(volatility: int, base_price: int = 100) -> int:
	return int(_runtime_balance_model().call("product_price_step_cap", volatility, base_price))


func _balance_product_price_model(base_price: int, supply_score: int, demand_score: int, route_damage_score: int, monster_pressure: int = 0, weather_modifier: int = 0, volatility: int = 4, random_noise: float = 0.0, growth_multiplier: float = 1.0) -> Dictionary:
	return _runtime_balance_model().call("product_price_model", base_price, supply_score, demand_score, route_damage_score, monster_pressure, weather_modifier, volatility, random_noise, growth_multiplier) as Dictionary


func _balance_monster_movement_speed_model(actor: Dictionary, target_index: int = -1, action_speed_mps: float = -1.0) -> Dictionary:
	return _runtime_balance_model().call("monster_movement_speed_model", actor, monster_runtime_controller._monster_terrain_move_multiplier(actor, target_index), action_speed_mps, _current_balance_region_radius_m(), 10.0) as Dictionary


func _current_balance_region_radius_m() -> float:
	var world := _game_runtime_coordinator_node().world_session_state()
	var region_count := maxi(1, world.districts.size())
	var world_area := maxf(1.0, world.map_width_m * world.map_height_m)
	return maxf(1.0, sqrt(world_area / float(region_count) / PI))


func _auto_monster_movement_speed_mps(actor: Dictionary, target_index: int, action_speed_mps: float = -1.0) -> float:
	var model := _balance_monster_movement_speed_model(actor, target_index, action_speed_mps)
	return maxf(1.0, float(model.get("speed_mps", 18.0)))


func _monster_knockback_model(action_or_skill: Dictionary, actor: Dictionary = {}) -> Dictionary:
	return _runtime_balance_model().call("monster_knockback_speed_model", action_or_skill, actor, _current_balance_region_radius_m(), 0.5) as Dictionary


func _nearest_district_to(point: Vector2) -> int:
	var best_index := -1
	var best_distance := INF
	point = _wrap_world_position(point)
	for i in range(_game_runtime_coordinator_node().world_session_state().districts.size()):
		var dist := _wrapped_distance(point, _district_center(i))
		if dist < best_distance:
			best_distance = dist
			best_index = i
	return best_index


func _start_card_ingress_animation() -> void:
	if _game_runtime_coordinator_node().world_session_state().districts.is_empty():
		return
	var planet_center := Vector2(_game_runtime_coordinator_node().world_session_state().map_width_m * 0.5, _game_runtime_coordinator_node().world_session_state().map_height_m * 0.5)
	_game_runtime_coordinator_node().add_visual_action_callout(
		"区域补给网",
		"卡池生成",
		"%d个区域各生成%d个随机挂牌；购买一张只补该空槽，查看牌架不会重抽。" % [
			_game_runtime_coordinator_node().world_session_state().districts.size(),
			DISTRICT_CARD_CHOICE_MAX,
		],
		Color("#fde68a"),
		planet_center,
		CARD_INGRESS_CALLOUT_DURATION
	)
	_game_runtime_coordinator_node().record_legacy_viewer_feedback("区域补给网完成：%d张合法I级牌进入确定性牌袋；每个区域生成%d个随机挂牌。" % [
		_current_run_card_pool().size(),
		DISTRICT_CARD_CHOICE_MAX,
	])


func _owner_damage_cash_total_for_rank(rank: int) -> int:
	return int(_runtime_balance_model().call("owner_damage_cash_total_for_rank", rank))


func _make_skill(skill_name: String) -> Dictionary:
	var base: Dictionary = _game_runtime_coordinator_node().card_definition(skill_name)
	var skill := base.duplicate(true)
	skill["name"] = skill_name
	skill = CardPlayRequirementPolicyScript.apply_to_card(skill_name, skill)
	if String(skill.get("use_case", "")).strip_edges() == "":
		skill["use_case"] = _card_presentation_text(skill, "use_case", skill_name)
	skill["cooldown"] = float(skill.get("cooldown", 0.0))
	skill["cooldown_left"] = 0.0
	skill["lock_left"] = 0.0
	return skill


func _is_v06_runtime_card(card: Dictionary) -> bool:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return not str(machine.get("card_id", "")).is_empty() and not str(machine.get("effect_kind", "")).is_empty()


func _v06_world_card_from_definition(card: Dictionary) -> Dictionary:
	if card.is_empty():
		return {}
	var result := card.duplicate(true)
	var machine: Dictionary = result.get("machine", {}) if result.get("machine", {}) is Dictionary else {}
	var player_text: Dictionary = result.get("player", {}) if result.get("player", {}) is Dictionary else {}
	result["card_id"] = str(machine.get("card_id", ""))
	result["name"] = str(machine.get("card_id", ""))
	result["display_name"] = str(player_text.get("name", result.get("name", "卡牌")))
	result["family_id"] = str(machine.get("family_id", ""))
	result["rank"] = int(machine.get("rank", 1))
	result["kind"] = "monster_card" if str(machine.get("category_id", "")) == "monster" else str(machine.get("category_id", "card_v06"))
	result["counts_toward_hand_limit"] = bool(machine.get("counts_toward_hand_limit", true))
	result["persistent"] = false
	result["queued_for_resolution"] = false
	result["lock_left"] = 0.0
	result["text"] = str(player_text.get("effect", player_text.get("short_effect", "")))
	return result


func _v06_actor_id(player_index: int) -> String:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return ""
	return str((_game_runtime_coordinator_node().world_session_state().players[player_index] as Dictionary).get("actor_id", "player.%d" % player_index)).strip_edges()




func _district_index_for_region_id(region_id: String) -> int:
	var normalized := region_id.strip_edges()
	if normalized.is_empty():
		return -1
	for district_index in range(_game_runtime_coordinator_node().world_session_state().districts.size()):
		if _game_runtime_coordinator_node().world_session_state().districts[district_index] is Dictionary \
				and str((_game_runtime_coordinator_node().world_session_state().districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index)) == normalized:
			return district_index
	return -1


func _player_role_template_index(player_index: int) -> int:
	var role_count := _player_role_catalog_size()
	if role_count <= 0:
		return 0
	return wrapi(player_index, 0, role_count)


func _player_role_catalog_size() -> int:
	var catalog := _game_runtime_coordinator_node().role_catalog_runtime_service()
	return catalog.role_count() if catalog != null else 0


func _clamp_role_index(index: int) -> int:
	var role_count := _player_role_catalog_size()
	if role_count <= 0:
		return 0
	return wrapi(index, 0, role_count)


func _player_role_template(player_index: int, role_index: int = -1) -> Dictionary:
	if _player_role_catalog_size() <= 0:
		return {}
	var template_index := _player_role_template_index(player_index)
	if role_index >= 0:
		template_index = _clamp_role_index(role_index)
	var catalog := _game_runtime_coordinator_node().role_catalog_runtime_service()
	return catalog.definition_at(template_index) if catalog != null else {}


func _role_starting_cash_delta(role_card: Dictionary) -> int:
	# All seats share STARTING_CASH as the general rule; public alien roles may
	# then apply a visible opening-cash modifier. `starting_cash_delta` is kept
	# as the future-proof field for positive or negative role drawbacks, while
	# existing role cards still use `starting_cash_bonus`.
	if role_card.has("starting_cash_delta"):
		return int(role_card.get("starting_cash_delta", 0))
	return int(role_card.get("starting_cash_bonus", 0))


func _player_starting_cash_for_role(role_card: Dictionary) -> int:
	return maxi(1, STARTING_CASH + _role_starting_cash_delta(role_card))


func _strip_role_starter_fields(role: Dictionary) -> Dictionary:
	for key in [
		"starter_monster_index",
		"starter_monster_name",
		"starter_monster_card",
		"starter_hp_bonus",
		"starter_duration_bonus",
		"starter_move_multiplier",
		"starter_fixed_skill_bonus",
	]:
		role.erase(key)
	return role


func _make_player_role_card(player_index: int, role_index: int = -1) -> Dictionary:
	var template_index := _player_role_template_index(player_index)
	if role_index >= 0:
		template_index = _clamp_role_index(role_index)
	var role := _player_role_template(player_index, template_index)
	role["kind"] = "player_role"
	role["role_index"] = template_index
	_strip_role_starter_fields(role)
	role = _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().apply_role_balance_metadata(role)
	role["text"] = "%s｜特征：%s｜被动：%s" % [
		String(role.get("species", "未知外星人")),
		String(role.get("trait", "暂无特征")),
		_role_passive_text(role),
	]
	return role


func _normalize_player_role_card(role_card: Dictionary, player_index: int) -> Dictionary:
	var role := role_card.duplicate(true) if not role_card.is_empty() else _make_player_role_card(player_index)
	if not role.has("role_index"):
		role["role_index"] = _player_role_template_index(player_index)
	role["role_index"] = _clamp_role_index(int(role.get("role_index", _player_role_template_index(player_index))))
	var template := _player_role_template(player_index, int(role.get("role_index", _player_role_template_index(player_index))))
	if String(role.get("name", "")) == "":
		role["name"] = String(template.get("name", "外星辛迪加"))
	if String(role.get("species", "")) == "":
		role["species"] = String(template.get("species", "未知外星人"))
	if String(role.get("trait", "")) == "":
		role["trait"] = String(template.get("trait", "起始怪兽牌持有人。"))
	for field_name in _role_runtime_copy_fields():
		if not role.has(field_name) and template.has(field_name):
			role[field_name] = template[field_name]
	role["kind"] = "player_role"
	_strip_role_starter_fields(role)
	role = _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().apply_role_balance_metadata(role)
	return role


func _ensure_player_role_cards() -> void:
	for i in range(_game_runtime_coordinator_node().world_session_state().players.size()):
		var player: Dictionary = _game_runtime_coordinator_node().world_session_state().players[i]
		var role_variant: Variant = player.get("role_card", {})
		var role := role_variant as Dictionary if role_variant is Dictionary else {}
		role = _normalize_player_role_card(role, i)
		player["role_card"] = role
		player["role_index"] = int(role.get("role_index", _player_role_template_index(i)))
		_game_runtime_coordinator_node().world_session_state().players[i] = player
	_ensure_player_private_intel_state()


func _ensure_player_private_intel_state() -> void:
	for i in range(_game_runtime_coordinator_node().world_session_state().players.size()):
		var player: Dictionary = _game_runtime_coordinator_node().world_session_state().players[i]
		player.erase("known_card_owners")
		if not (player.get("city_guesses", {}) is Dictionary):
			player["city_guesses"] = {}
		if not (player.get("city_guess_confidence", {}) is Dictionary):
			player["city_guess_confidence"] = {}
		if not (player.get("city_guess_reasons", {}) is Dictionary):
			player["city_guess_reasons"] = {}
		_game_runtime_coordinator_node().world_session_state().players[i] = player


func _role_passive_text(role_card: Dictionary) -> String:
	return _realtime_rule_text(String(role_card.get("passive", "暂无被动")))


func _player_role_card_for_index(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return {}
	var role_variant: Variant = (_game_runtime_coordinator_node().world_session_state().players[player_index] as Dictionary).get("role_card", {})
	return role_variant as Dictionary if role_variant is Dictionary else {}


func _role_runtime_copy_fields() -> Array:
	return [
		"passive",
		"starting_cash_delta",
		"starting_cash_bonus",
		"resource_cash_product",
		"resource_cash_amount",
		"bonus_card_product",
		"monster_upgrade_cash",
		"intel_city_reveal_charges",
		"card_history_residual_catalog_charges",
		"card_history_public_exclusion_charges",
		"city_guess_reward_bonus",
		"high_volatility_sale_threshold",
		"high_volatility_first_sale_bonus",
		"high_volatility_bonus_once_per_market_cycle",
		"monster_cards_as_counter",
		"monster_control_limit_bonus",
		"military_control_limit_bonus",
		"flavor",
	]


func _runtime_snapshot_player_index() -> int:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null:
		return -1
	var context := coordinator.gameplay_actor_authorization_context(&"game_screen")
	return context.authorized_actor_player_index if context != null and context.is_valid() else -1




















func _card_presentation_source(card_name: String, supplied_skill: Dictionary = {}, player_index: int = -1, district_index: int = -1) -> Dictionary:
	var skill := supplied_skill.duplicate(true)
	if skill.is_empty() and card_name != "":
		skill = _game_runtime_coordinator_node().card_definition(card_name)
	if skill.is_empty():
		return {}
	var player_facing_display_name := String(skill.get("display_name", "")).strip_edges()
	var kind := String(skill.get("kind", ""))
	var requirement := _card_play_requirement_snapshot(player_index, skill, {"selected_district": district_index})
	var target := _card_play_target_snapshot(skill)
	return {
		"card_name": card_name,
		"skill": skill,
		"display_name": player_facing_display_name if player_facing_display_name != "" else _card_display_name(card_name),
		"display_text": _skill_display_text(skill),
		"tag_text": _skill_tag_text(skill),
		"rank": _game_runtime_coordinator_node().card_rank(card_name),
		"price": _card_price(card_name, district_index, player_index),
		"play_requirement_text": String(requirement.get("requirement_text", "条件：无")),
		"required_share_percent": int(requirement.get("required_share_percent", 0)),
		"play_cash_cost": int(requirement.get("cash_cost", 0)),
		"targets_monster": bool(target.get("targets_monster", false)),
		"targets_player": bool(target.get("targets_player", false)),
		"requires_target_monster": bool(target.get("requires_target_monster", false)),
		"requires_target_player": bool(target.get("requires_target_player", false)),
		"is_monster_card": _is_monster_card_name(card_name),
		"is_direct_monster_skill": bool(target.get("targets_monster", false)) and not ["monster_lure", "special_monster_delay", "mudslide", "monster_takeover", "military_command"].has(kind),
		"city_gdp_derivative_duration_seconds": _city_gdp_derivative_duration_seconds(skill) if kind == "city_gdp_derivative" else 0.0,
		"product_futures_duration_seconds": _product_market_futures_duration_seconds(skill) if kind == "product_futures" else 0.0,
		"counter_window_default_seconds": _ruleset_timing_seconds(&"counter_window_seconds"),
		"weather_label": weather_runtime_controller.label(String(skill.get("weather_type", ""))) if String(skill.get("weather_type", "")) != "" else "",
		"weather_forecast_lead_min_seconds": WeatherRuntimeController.FORECAST_LEAD_MIN_SECONDS,
		"economy_legacy_turn_seconds": ECONOMY_LEGACY_TURN_SECONDS,
		"military_type_label": military_runtime_controller.unit_type_label(skill),
		"military_domain_label": military_runtime_controller.domain_label(skill),
		"military_mobility_summary": military_runtime_controller.mobility_summary(skill),
		"military_hp": military_runtime_controller.unit_hp(skill),
		"military_damage": military_runtime_controller.unit_damage(skill),
		"military_duration": military_runtime_controller.unit_duration(skill),
		"military_command_label": military_runtime_controller.command_label(String(skill.get("military_command", ""))),
	}


func _card_presentation_snapshot(card_name: String, supplied_skill: Dictionary = {}, player_index: int = -1, district_index: int = -1) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("compose_card_presentation"):
		return {}
	var value: Variant = coordinator.call("compose_card_presentation", _card_presentation_source(card_name, supplied_skill, player_index, district_index))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_presentation_text(skill: Dictionary, field: String, card_name: String = "", player_index: int = -1, district_index: int = -1) -> String:
	var resolved_name := card_name if card_name != "" else String(skill.get("name", ""))
	return str(_card_presentation_snapshot(resolved_name, skill, player_index, district_index).get(field, ""))


func _card_presentation_color(skill: Dictionary, card_name: String = "") -> Color:
	var resolved_name := card_name if card_name != "" else String(skill.get("name", ""))
	return _card_presentation_snapshot(resolved_name, skill).get("accent", Color("#94a3b8")) as Color


func _card_presentation_array(skill: Dictionary, field: String, card_name: String = "", player_index: int = -1, district_index: int = -1) -> Array:
	var resolved_name := card_name if card_name != "" else String(skill.get("name", ""))
	var value: Variant = _card_presentation_snapshot(resolved_name, skill, player_index, district_index).get(field, [])
	return (value as Array).duplicate(true) if value is Array else []


func _card_presentation_detail_tooltip(card_name: String, district_index: int = -1) -> String:
	if card_name == "" or not _game_runtime_coordinator_node().card_exists(card_name):
		return ""
	return _card_presentation_text(_game_runtime_coordinator_node().card_definition(card_name), "detail_tooltip", card_name, _runtime_snapshot_player_index(), district_index)


func _runtime_planet_flow_compass_source() -> Dictionary:
	return {}


func _card_resolution_side_lane_focus_active() -> bool:
	if not _card_resolution_active_entry().is_empty() or card_resolution_counter_window_active or card_resolution_auction_open:
		return true
	if not _card_resolution_current_queue().is_empty() and not card_resolution_batch_locked:
		return true
	if card_resolution_simultaneous_timer > 0.0 and not _card_resolution_current_queue().is_empty():
		return true
	return false


func _runtime_planet_surface_rail_entries(player_index: int) -> Array:
	var selected_ok := _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size()
	var choices_count := 0
	var supply_text := "补给：未选区"
	if selected_ok:
		var query := _game_runtime_coordinator_node().district_supply_runtime_query_port()
		choices_count = query.public_card_ids_for_district(_game_runtime_coordinator_node().table_selection_state().selected_district).size() if query != null else 0
		supply_text = _selected_district_supply_text(player_index)
	return [
		{
			"label": "星区",
			"value": "%d区" % _game_runtime_coordinator_node().world_session_state().districts.size(),
			"active": _game_runtime_coordinator_node().world_session_state().districts.size() > 0,
			"accent": Color("#38bdf8"),
			"tooltip": "公开星区数量；完整区域事实进入区域图鉴。",
		},
		{
			"label": "选区",
			"value": _short_card_text(_runtime_selected_district_title(), 12),
			"active": selected_ok,
			"accent": Color("#facc15"),
			"tooltip": "当前选中的星球区域。",
		},
		{
			"label": "牌架",
			"value": "%d张" % choices_count if selected_ok else "未选",
			"active": selected_ok and choices_count > 0,
			"accent": Color("#c084fc"),
			"tooltip": "当前选区可查看的公开牌架数量。",
		},
		{
			"label": "补给",
			"value": _short_card_text(supply_text.replace("补给 ", ""), 12),
			"active": selected_ok,
			"accent": Color("#4ade80"),
			"tooltip": supply_text,
		},
	]


func _runtime_planet_outer_rail_entries() -> Array:
	var queue_count := _card_resolution_current_queue().size() + _card_resolution_next_queue().size()
	return [
		{
			"label": "怪兽",
			"value": "%d只" % monster_runtime_controller.auto_monsters.size(),
			"active": monster_runtime_controller.auto_monsters.size() > 0,
			"accent": Color("#fb7185"),
			"tooltip": "公开怪兽数量；完整怪兽档案进入图鉴。",
		},
		{
			"label": "天气",
			"value": weather_runtime_controller.planet_short_text(),
			"active": weather_runtime_controller.active_zone_count() > 0 or weather_runtime_controller.has_forecast(),
			"accent": Color("#38bdf8"),
			"tooltip": weather_runtime_controller.status_text(),
		},
		{
			"label": "牌轨",
			"value": _runtime_planet_card_track_short_text(queue_count),
			"active": queue_count > 0 or card_resolution_auction_open or not _card_resolution_active_entry().is_empty(),
			"accent": Color("#f59e0b"),
			"tooltip": _card_resolution_status_text(),
		},
		{
			"label": "终局",
			"value": str(_victory_control_public_snapshot().get("state", "idle")),
			"active": _victory_control_timer_visible(),
			"accent": Color("#facc15"),
			"tooltip": _victory_control_status_text(),
		},
	]


func _runtime_planet_card_track_short_text(queue_count: int) -> String:
	if card_resolution_auction_open:
		return "锁牌%d" % queue_count
	if not _card_resolution_active_entry().is_empty():
		return "展示"
	if queue_count > 0:
		return "队列%d" % queue_count
	return "空闲"


func _runtime_requirement_chip_snapshots(player_index: int) -> Array:
	var chips: Array = []
	for entry_variant in _selected_district_action_lamp_entries(player_index):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		chips.append({
			"text": "%s:%s" % [String(entry.get("text", "")), String(entry.get("state", ""))],
			"tooltip": String(entry.get("tip", "")),
		})
	if chips.is_empty():
		chips.append({"text": "暂无条件"})
	return chips




func _runtime_player_economic_source_snapshot(player_index: int) -> Dictionary:
	if not _can_view_player_private_hand(player_index):
		return {}
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("actor_id_for_player_index") or not coordinator.has_method("economic_source_snapshot"):
		return {}
	var binding_variant: Variant = coordinator.call("actor_id_for_player_index", player_index)
	var binding: Dictionary = binding_variant if binding_variant is Dictionary else {}
	var actor_id := str(binding.get("actor_id", ""))
	if not bool(binding.get("available", false)) or actor_id.is_empty():
		return {}
	var source_variant: Variant = coordinator.call("economic_source_snapshot", actor_id)
	var source: Dictionary = source_variant if source_variant is Dictionary else {}
	return {
		"available": bool(source.get("available", false)),
		"revision": int(source.get("revision", 0)),
		"has_source": bool(source.get("has_source", false)),
		"bootstrap_finalized": bool(source.get("bootstrap_finalized", false)),
		"owned_facility_count": int(source.get("owned_facility_count", 0)),
		"legal_region_count": int(source.get("legal_region_count", 0)),
		"expansion_available": bool(source.get("expansion_available", false)),
		"target_region_id": str(source.get("target_region_id", "")),
	}










func _runtime_selected_context_why(player_index: int) -> String:
	if _game_runtime_coordinator_node().world_session_state().players.is_empty():
		return "开桌后显示下一步。"
	if _game_runtime_coordinator_node().table_selection_state().selected_district < 0 or _game_runtime_coordinator_node().table_selection_state().selected_district >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return "先点星球区域。"
	var active_labels: Array[String] = []
	for entry_variant in _selected_district_action_lamp_entries(player_index):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if bool(entry.get("active", false)):
			active_labels.append("%s:%s" % [String(entry.get("text", "")), String(entry.get("state", ""))])
	if not active_labels.is_empty():
		return "现在可做：%s。" % "、".join(active_labels)
	return "选择目标区域，再从真实卡牌目录打出完整定义的公共设施牌。"


func _runtime_player_board_hint(player_index: int) -> String:
	if not _runtime_player_is_valid(player_index):
		return "还没有可行动席位。"
	if _can_view_player_private_hand(player_index):
		return "私密手牌和当前行动都固定在底部玩家板。"
	return "只看公开席位：私密现金和手牌保持隐藏。"


func _runtime_selected_district_summary(player_index: int) -> String:
	if _game_runtime_coordinator_node().table_selection_state().selected_district < 0 or _game_runtime_coordinator_node().table_selection_state().selected_district >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return "未选区"
	var summary := _selected_district_status_text(player_index)
	if not _can_view_player_private_hand(player_index):
		return summary
	var own_facilities := []
	for facility_variant in _region_infrastructure_owned_facilities(_game_runtime_coordinator_node().table_selection_state().selected_district, player_index):
		var facility: Dictionary = facility_variant as Dictionary
		own_facilities.append("%s%s %s" % [
			String(facility.get("industry_id", "通用")),
			String(facility.get("facility_type", "facility")),
			_level_text(int(facility.get("rank", 1))),
		])
	if not own_facilities.is_empty():
		summary += "｜我的公共设施：%s" % "、".join(own_facilities)
	return summary


func _runtime_selected_district_title() -> String:
	if _game_runtime_coordinator_node().table_selection_state().selected_district < 0 or _game_runtime_coordinator_node().table_selection_state().selected_district >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return "未选区"
	return String(_game_runtime_coordinator_node().world_session_state().districts[_game_runtime_coordinator_node().table_selection_state().selected_district].get("name", "区域"))


func _runtime_player_cash_text(player_index: int) -> String:
	if not _runtime_player_is_valid(player_index):
		return "--"
	if _can_view_player_private_hand(player_index):
		return "¥ %d" % int((_game_runtime_coordinator_node().world_session_state().players[player_index] as Dictionary).get("cash", 0))
	return "公开估算 %d" % _victory_player_progress_metric(player_index)


func _runtime_player_gdp_text(player_index: int) -> String:
	if not _runtime_player_is_valid(player_index):
		return "--/min"
	if _can_view_player_private_hand(player_index):
		return "%d/min" % _player_gdp_per_minute(player_index)
	return "公开"


func _runtime_player_is_valid(player_index: int) -> bool:
	return player_index >= 0 and player_index < _game_runtime_coordinator_node().world_session_state().players.size()


func _focus_runtime_map_on_district(district_index: int) -> void:
	if district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return
	if map_view != null and map_view.has_method("focus_district"):
		_game_runtime_coordinator_node().request_table_presentation_refresh(&"map", &"main_state_changed")
		map_view.call("focus_district", district_index)
	if full_map_view != null and full_map_view.has_method("focus_district"):
		_game_runtime_coordinator_node().request_table_presentation_refresh(&"map", &"main_state_changed")
		full_map_view.call("focus_district", district_index)


func _jump_to_district_on_table(district_index: int, clear_card_selection: bool = true) -> bool:
	if district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return false
	var selection := _game_runtime_coordinator_node().table_selection_state()
	var result := selection.select_district_target(district_index, int(selection.snapshot().get("revision", -1)), clear_card_selection)
	if not bool(result.get("applied", false)):
		return false
	_focus_runtime_map_on_district(district_index)
	return true


func _player_color(player_index: int) -> Color:
	if PLAYER_COLORS.is_empty():
		return Color("#38bdf8")
	return PLAYER_COLORS[wrapi(player_index, 0, PLAYER_COLORS.size())] as Color


func _district_city(index: int) -> Dictionary:
	if index < 0 or index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return {}
	return _game_runtime_coordinator_node().world_session_state().districts[index].get("city", {}) as Dictionary


func _city_is_active(city: Dictionary) -> bool:
	return not city.is_empty() and bool(city.get("active", true))


func _city_product_names(city: Dictionary) -> Array:
	var result := []
	for product_variant in city.get("products", []):
		var product: Dictionary = product_variant
		result.append(String(product.get("name", "未知商品")))
	return result


func _city_demand_names(city: Dictionary) -> Array:
	var result := []
	for product_variant in city.get("demands", []):
		result.append(String(product_variant))
	return result


func _city_public_clue_products_from_text(clue: String) -> Array:
	var products := []
	for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_name != "" and clue.contains(product_name):
			products.append(product_name)
	return products


func _city_public_clue_kind_from_text(clue: String) -> String:
	if clue.contains("合约"):
		return "合约"
	if clue.contains("商路") or clue.contains("断路") or clue.contains("黑客"):
		return "商路"
	if clue.contains("需求压力") or clue.contains("市场") or clue.contains("价格"):
		return "市场"
	if clue.contains("GDP") or clue.contains("生产") or clue.contains("交通") or clue.contains("消费"):
		return "经营"
	return "公开"


func _normalize_city_public_clue_entry(value: Variant) -> Dictionary:
	if value is Dictionary:
		var entry := (value as Dictionary).duplicate(true)
		var text := String(entry.get("text", entry.get("clue", ""))).strip_edges()
		if text == "":
			return {}
		entry["text"] = text
		if not entry.has("time"):
			entry["time"] = float(entry.get("game_time", -1.0))
		if not entry.has("cycle"):
			entry["cycle"] = 0
		if String(entry.get("kind", "")) == "":
			entry["kind"] = _city_public_clue_kind_from_text(text)
		if not (entry.get("products", []) is Array) or (entry.get("products", []) as Array).is_empty():
			entry["products"] = _city_public_clue_products_from_text(text)
		return entry
	var clue_text := String(value).strip_edges()
	if clue_text == "":
		return {}
	var time_value := -1.0
	var text_value := clue_text
	if clue_text.begins_with("t") and clue_text.contains("s｜"):
		var split_parts := clue_text.split("｜", false, 1)
		if split_parts.size() >= 2:
			var stamp := String(split_parts[0]).trim_prefix("t").trim_suffix("s")
			time_value = stamp.to_float()
			text_value = String(split_parts[1]).strip_edges()
	return {
		"time": time_value,
		"cycle": 0,
		"kind": _city_public_clue_kind_from_text(text_value),
		"products": _city_public_clue_products_from_text(text_value),
		"text": text_value,
	}


func _city_public_clue_display_text(value: Variant) -> String:
	var entry := _normalize_city_public_clue_entry(value)
	if entry.is_empty():
		return ""
	var time_text := "T+%.0fs" % float(entry.get("time", 0.0)) if float(entry.get("time", -1.0)) >= 0.0 else "时间未知"
	return "%s｜%s｜商品:%s｜%s" % [
		time_text,
		String(entry.get("kind", "公开")),
		_limited_name_list(entry.get("products", []) as Array, 3, "无"),
		String(entry.get("text", "")),
	]


func _append_city_public_clue(city: Dictionary, clue: String) -> Dictionary:
	var clean_clue := clue.strip_edges()
	if clean_clue == "":
		return city
	city["last_public_clue"] = clean_clue
	var clues := []
	for clue_variant in city.get("public_clues", []):
		var clue_entry := _normalize_city_public_clue_entry(clue_variant)
		if not clue_entry.is_empty():
			clues.append(clue_entry)
	clues.append({
		"time": _game_runtime_coordinator_node().world_session_state().game_time,
		"cycle": _product_market_cycle(),
		"kind": _city_public_clue_kind_from_text(clean_clue),
		"products": _city_public_clue_products_from_text(clean_clue),
		"text": clean_clue,
	})
	while clues.size() > CITY_PUBLIC_CLUE_HISTORY_LIMIT:
		clues.pop_front()
	city["public_clues"] = clues
	return city


func _toggle_selected_trade_route() -> void:
	var selected_product := _game_runtime_coordinator_node().table_selection_state().selected_trade_product
	var next_product := ""
	if selected_product.is_empty():
		next_product = _default_trade_product_for_selected_district()
		if next_product.is_empty() and not ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
			next_product = String(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	if runtime_game_screen != null and runtime_game_screen.has_method("request_trade_product_selection"):
		runtime_game_screen.call("request_trade_product_selection", next_product, &"player_board")


func _default_trade_product_for_selected_district() -> String:
	if _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size():
		var city := _district_city(_game_runtime_coordinator_node().table_selection_state().selected_district)
		if _city_is_active(city):
			var demands := _city_demand_names(city)
			if not demands.is_empty():
				return String(demands[0])
			var city_products := _city_product_names(city)
			if not city_products.is_empty():
				return String(city_products[0])
		var products: Array = _game_runtime_coordinator_node().world_session_state().districts[_game_runtime_coordinator_node().table_selection_state().selected_district].get("products", [])
		if not products.is_empty():
			return String(products[0])
		var district_demands: Array = _game_runtime_coordinator_node().world_session_state().districts[_game_runtime_coordinator_node().table_selection_state().selected_district].get("demands", [])
		if not district_demands.is_empty():
			return String(district_demands[0])
	for index_variant in _active_city_district_indices():
		var city := _district_city(int(index_variant))
		var demands := _city_demand_names(city)
		if not demands.is_empty():
			return String(demands[0])
	return ""


func _selected_city_owner_view_text() -> String:
	var city := _district_city(_game_runtime_coordinator_node().table_selection_state().selected_district)
	if city.is_empty():
		return "未城市化"
	if not _city_is_active(city):
		return "城市废墟"
	var actor_index := _runtime_snapshot_player_index()
	var city_owner := int(city.get("owner", -1))
	if city_owner == actor_index:
		return "己方城市"
	var guesses: Dictionary = _game_runtime_coordinator_node().world_session_state().players[actor_index].get("city_guesses", {}) if actor_index >= 0 and actor_index < _game_runtime_coordinator_node().world_session_state().players.size() else {}
	var guess := int(guesses.get(_game_runtime_coordinator_node().table_selection_state().selected_district, -1))
	return "归属待猜" if guess < 0 else "我的推测：玩家%d" % (guess + 1)


func _refresh_map_controls() -> void:
	var toolbar := full_map_overlay.find_child("PlanetMapControlToolbar", true, false) as Control if full_map_overlay != null and is_instance_valid(full_map_overlay) else null
	if toolbar != null and toolbar.has_method("set_controls"):
		toolbar.call("set_controls", _map_control_toolbar_snapshot())
	_refresh_fullscreen_map_hud()


func _refresh_fullscreen_map_hud() -> void:
	if fullscreen_map_hud_labels.is_empty():
		return
	var layer_label := fullscreen_map_hud_labels.get("layer", null) as Label
	if layer_label != null:
		var entry := _map_layer_entry(_game_runtime_coordinator_node().table_selection_state().selected_map_layer_focus)
		layer_label.text = "图层:%s" % _map_layer_focus_label(_game_runtime_coordinator_node().table_selection_state().selected_map_layer_focus)
		layer_label.tooltip_text = String(entry.get("tip", "当前全屏地图图层。"))
	var product_label := fullscreen_map_hud_labels.get("product", null) as Label
	if product_label != null:
		var product_text := _game_runtime_coordinator_node().table_selection_state().selected_trade_product if _game_runtime_coordinator_node().table_selection_state().selected_trade_product != "" else _default_trade_product_for_selected_district()
		product_label.text = "商品:%s" % (_short_card_text(product_text, 8) if product_text != "" else "未选")
		product_label.tooltip_text = "当前用于商路/商品读图的商品。"
	var district_label := fullscreen_map_hud_labels.get("district", null) as Label
	if district_label != null:
		district_label.text = "选区:%s" % _short_card_text(String(_game_runtime_coordinator_node().world_session_state().districts[_game_runtime_coordinator_node().table_selection_state().selected_district].get("name", "未选")) if _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size() else "未选", 10)
		district_label.tooltip_text = _selected_district_status_text(_runtime_snapshot_player_index()) if _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size() else "当前未选择区域。"


func _first_actionable_hand_slot(player_index: int) -> int:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return -1
	var player: Dictionary = _game_runtime_coordinator_node().world_session_state().players[player_index]
	var slots: Array = player.get("slots", [])
	for i in range(slots.size()):
		if not (slots[i] is Dictionary):
			continue
		var skill: Dictionary = slots[i]
		var state := _card_play_eligibility_snapshot(player_index, skill, "hand")
		if bool(state.get("actionable", false)):
			return i
	return -1




func _selected_district_status_text(player_index: int) -> String:
	if _game_runtime_coordinator_node().table_selection_state().selected_district < 0 or _game_runtime_coordinator_node().table_selection_state().selected_district >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return "未选择区域"
	var district: Dictionary = _game_runtime_coordinator_node().world_session_state().districts[_game_runtime_coordinator_node().table_selection_state().selected_district]
	var terrain := String(district.get("terrain_label", "海洋" if String(district.get("terrain", "land")) == "ocean" else "陆地"))
	if bool(district.get("destroyed", false)):
		return "%s｜%s｜区域已毁" % [String(district.get("name", "区域")), terrain]
	var city := _district_city(_game_runtime_coordinator_node().table_selection_state().selected_district)
	if _city_is_active(city):
		var gdp := _city_gdp_per_minute(_game_runtime_coordinator_node().table_selection_state().selected_district, int(city.get("competition_matches", 0)))
		var owner_text := _selected_city_owner_view_text()
		if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
			owner_text = "归属待猜"
		return "%s｜%s｜%s｜GDP %d/min" % [
			String(district.get("name", "区域")),
			terrain,
			owner_text,
			gdp,
		]
	if not city.is_empty():
		return "%s｜%s｜城市废墟" % [String(district.get("name", "区域")), terrain]
	var settle_text := "可城市化" if String(district.get("terrain", "land")) != "ocean" else "运输海域"
	return "%s｜%s｜%s" % [String(district.get("name", "区域")), terrain, settle_text]


func _selected_district_supply_text(player_index: int) -> String:
	if _game_runtime_coordinator_node().table_selection_state().selected_district < 0 or _game_runtime_coordinator_node().table_selection_state().selected_district >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return "补给：未选区"
	var query := _game_runtime_coordinator_node().district_supply_runtime_query_port()
	var choices := query.public_card_ids_for_district(_game_runtime_coordinator_node().table_selection_state().selected_district) if query != null else []
	var availability_text := query.public_market_availability_text(_game_runtime_coordinator_node().table_selection_state().selected_district) if query != null else "市场资格暂不可用。"
	return "补给 %d张｜%s" % [choices.size(), availability_text]


func _selected_district_action_lamp_entries(player_index: int) -> Array:
	var entries := []
	var has_selection := _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size()
	if not has_selection:
		return [{
			"text": "先点地块",
			"state": "未选",
			"accent": Color("#94a3b8"),
			"active": false,
			"tip": "在中央星球上点一个区域后，地块行动灯会显示可做动作。",
		}]
	var query := _game_runtime_coordinator_node().district_supply_runtime_query_port()
	var choices := query.public_card_ids_for_district(_game_runtime_coordinator_node().table_selection_state().selected_district) if query != null else []
	var can_buy := query != null and query.public_market_purchasable(_game_runtime_coordinator_node().table_selection_state().selected_district)
	var trade_product := _game_runtime_coordinator_node().table_selection_state().selected_trade_product if _game_runtime_coordinator_node().table_selection_state().selected_trade_product != "" else _default_trade_product_for_selected_district()
	var city := _district_city(_game_runtime_coordinator_node().table_selection_state().selected_district)
	entries.append({
		"text": "牌架",
		"state": "可买" if can_buy else ("可看" if not choices.is_empty() else "空"),
		"accent": Color("#facc15") if can_buy else Color("#38bdf8"),
		"active": not choices.is_empty(),
		"tip": "区域牌架：查看始终允许；来源受光时可报价，显式选择后锁定5秒。",
	})
	entries.append({
		"text": "商路",
		"state": _short_card_text(trade_product if _game_runtime_coordinator_node().table_selection_state().selected_trade_product != "" else "未开", 5),
		"accent": Color("#f59e0b") if _game_runtime_coordinator_node().table_selection_state().selected_trade_product != "" else Color("#64748b"),
		"active": _game_runtime_coordinator_node().table_selection_state().selected_trade_product != "",
		"tip": "商路显示：点击商路按钮会切换当前商品运输路径。",
	})
	if _city_is_active(city) and int(city.get("owner", -1)) != player_index:
		entries.append({
			"text": "标注",
			"state": "可猜",
			"accent": Color("#c084fc"),
			"active": true,
			"tip": "陌生城市可进入情报档案，记录你猜测的业主。",
		})
	return entries




func _player_visible_city_text(player_index: int, viewer_index: int) -> String:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return "城?"
	if player_index == viewer_index:
		return "己城%d" % _player_active_city_count(player_index)
	if viewer_index < 0 or viewer_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return "城?"
	var guesses: Dictionary = (_game_runtime_coordinator_node().world_session_state().players[viewer_index] as Dictionary).get("city_guesses", {})
	var suspected_count := 0
	for key_variant in guesses.keys():
		if int(guesses.get(key_variant, -1)) == player_index:
			suspected_count += 1
	return "疑城%d" % suspected_count if suspected_count > 0 else "城?"


func _player_visible_monster_count(player_index: int, viewer_index: int) -> int:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return 0
	var count := 0
	for actor_variant in monster_runtime_controller.auto_monsters:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)) or int(actor.get("owner", -1)) != player_index:
			continue
		if bool(actor.get("owner_revealed", false)) or player_index == viewer_index:
			count += 1
	return count


func _first_starter_monster_slot(player: Dictionary) -> int:
	var slots: Array = player.get("slots", [])
	for i in range(slots.size()):
		var slot_variant: Variant = slots[i]
		if not (slot_variant is Dictionary):
			continue
		var skill := slot_variant as Dictionary
		var machine: Dictionary = skill.get("machine", {}) if skill.get("machine", {}) is Dictionary else {}
		if str(machine.get("effect_kind", "")) == "deploy_or_upgrade_monster" and int(machine.get("rank", 0)) == 1:
			return i
		if String(skill.get("kind", "")) == "monster_card" and bool(skill.get("starter_play_free", false)):
			return i
	return -1


func _role_card_presentation_color(role_card: Dictionary) -> Color:
	if PLAYER_COLORS.is_empty():
		return Color("#38bdf8")
	var index := wrapi(int(role_card.get("role_index", _codex_navigation_controller_node().role_codex_index)), 0, PLAYER_COLORS.size())
	return (PLAYER_COLORS[index] as Color).lerp(Color("#f59e0b"), 0.18)


func _role_card_tag_text(role_card: Dictionary) -> String:
	return "角色卡 / %s" % String(role_card.get("species", "未知外星人"))


func _role_card_face_text(role_card: Dictionary, compact: bool = false) -> String:
	var role_trait := String(role_card.get("trait", "暂无特征"))
	if compact:
		return "特征:%s\n被动:%s\n公开角色" % [
			_short_card_text(role_trait, 34),
			_short_card_text(_role_passive_text(role_card), 26),
		]
	return "特征：%s\n被动：%s\n角色资料：公开身份；开局怪兽独立选择。" % [
		role_trait,
		_role_passive_text(role_card),
	]


func _monster_card_duration_text(skill: Dictionary, compact: bool = false) -> String:
	var duration := float(skill.get("duration", -1.0))
	if duration < 0.0:
		return "常驻" if compact else "不限时（不会自然离场）"
	return "%.0fs" % duration if compact else "%.0f秒后自然离场" % duration


func _duration_short_text(seconds: float) -> String:
	var total := maxi(1, int(round(seconds)))
	if total < 60:
		return "%d秒" % total
	var minutes := int(float(total) / 60.0)
	var rest := total % 60
	if rest == 0:
		return "%d分钟" % minutes
	return "%d分%d秒" % [minutes, rest]


func _legacy_turns_to_seconds(turns: int) -> float:
	return float(maxi(0, turns)) * ECONOMY_LEGACY_TURN_SECONDS


func _skill_duration_seconds(skill: Dictionary, seconds_key: String, turns_key: String, default_turns: int = 0) -> float:
	if skill.has(seconds_key):
		return maxf(0.0, float(skill.get(seconds_key, 0.0)))
	return _legacy_turns_to_seconds(maxi(0, int(skill.get(turns_key, default_turns))))


func _remaining_effect_seconds(source: Dictionary, seconds_key: String, turns_key: String) -> float:
	if source.has(seconds_key):
		return maxf(0.0, float(source.get(seconds_key, 0.0)))
	return _legacy_turns_to_seconds(maxi(0, int(source.get(turns_key, 0))))


func _set_remaining_effect_seconds(source: Dictionary, seconds_key: String, turns_key: String, seconds: float) -> void:
	var safe_seconds := maxf(0.0, seconds)
	source[seconds_key] = safe_seconds
	source[turns_key] = int(ceil(safe_seconds / ECONOMY_LEGACY_TURN_SECONDS)) if safe_seconds > 0.0 else 0


func _age_remaining_effect_seconds(source: Dictionary, seconds_key: String, turns_key: String, delta_seconds: float) -> bool:
	var before := _remaining_effect_seconds(source, seconds_key, turns_key)
	if before <= 0.0:
		_set_remaining_effect_seconds(source, seconds_key, turns_key, 0.0)
		return false
	var after := maxf(0.0, before - maxf(0.0, delta_seconds))
	_set_remaining_effect_seconds(source, seconds_key, turns_key, after)
	return before > 0.0 and after <= 0.0


func _boon_duration_text(seconds: float) -> String:
	if seconds > 0.0:
		return _duration_short_text(seconds)
	return "本局持续"


func _monster_card_region_text(skill: Dictionary, compact: bool = false) -> String:
	if bool(skill.get("starter_play_free", false)):
		return "不限区" if compact else "无（起始怪兽牌）"
	match String(skill.get("summon_access", "any")):
		"monster_zone":
			return "怪区邻接" if compact else "怪兽落地区或相邻区域"
		"land_monster_zone":
			return "陆地怪区" if compact else "陆地区域，且必须是怪兽落地区或相邻区域"
		"ocean_monster_zone":
			return "海洋怪区" if compact else "海洋区域，且必须是怪兽落地区或相邻区域"
		"land":
			return "仅陆地" if compact else "仅限陆地区域"
		"ocean":
			return "仅海洋" if compact else "仅限海洋区域"
		"any", "":
			return "不限区" if compact else "无"
	return String(skill.get("summon_access", "无"))


func _can_summon_monster_card_at_district(skill: Dictionary, district_index: int) -> bool:
	if bool(skill.get("starter_play_free", false)):
		return district_index >= 0 and district_index < _game_runtime_coordinator_node().world_session_state().districts.size() and not bool(_game_runtime_coordinator_node().world_session_state().districts[district_index].get("destroyed", false))
	if district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return false
	if bool(_game_runtime_coordinator_node().world_session_state().districts[district_index].get("destroyed", false)):
		return false
	var terrain := String(_game_runtime_coordinator_node().world_session_state().districts[district_index].get("terrain", "land"))
	match String(skill.get("summon_access", "any")):
		"monster_zone":
			return monster_runtime_controller.summon_zone_available(district_index)
		"land_monster_zone":
			return monster_runtime_controller.summon_zone_available(district_index, "land")
		"ocean_monster_zone":
			return monster_runtime_controller.summon_zone_available(district_index, "ocean")
		"land":
			return terrain == "land"
		"ocean":
			return terrain == "ocean"
		"any", "":
			return true
	return true






func _short_card_text(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.left(max(1, max_len - 1)) + "…"


func _has_pending_blocking_decision() -> bool:
	_game_runtime_coordinator_node().synchronize_forced_decisions()
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null:
		return false
	var global_blocked := coordinator.has_method("blocks_global_time") and bool(coordinator.call("blocks_global_time"))
	var player_blocked := coordinator.has_method("blocks_player_actions") and bool(coordinator.call("blocks_player_actions", _runtime_snapshot_player_index()))
	return global_blocked or player_blocked


func _queue_monster_card_as_counter(player_index: int, slot_index: int, source_skill: Dictionary) -> bool:
	var world_session := _game_runtime_coordinator_node().world_session_state()
	if player_index < 0 or player_index >= world_session.players.size():
		return false
	var players := world_session.players.duplicate(true)
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return false
	var counter_rank := clampi(_game_runtime_coordinator_node().card_rank(String(source_skill.get("name", ""))), 1, 4)
	var counter_skill := _make_skill("相位否决%d" % counter_rank)
	if counter_skill.is_empty():
		return false
	counter_skill["source_card_name"] = String(source_skill.get("name", "怪兽牌"))
	counter_skill["text"] = "%s（由%s临时改写；会消耗该怪兽牌。）" % [
		String(counter_skill.get("text", "")),
		_card_display_name(String(source_skill.get("name", "怪兽牌"))),
	]
	var original_skill := (slots[slot_index] as Dictionary).duplicate(true)
	slots[slot_index] = counter_skill
	player["slots"] = slots
	players[player_index] = player
	world_session.replace_players(players)
	var counter_receipt := _game_runtime_coordinator_node().submit_card_play({
		"player_index": player_index,
		"slot_index": slot_index,
		"target_slot": -1,
		"target_player": -1,
		"selected_card_resolution_id": _game_runtime_coordinator_node().table_selection_state().selected_card_resolution_id,
		"submission_source": "role_counter_conversion",
	})
	_game_runtime_coordinator_node().record_legacy_viewer_feedback(str(counter_receipt.get("player_message", "卡牌提交已处理。")))
	var queued := bool(counter_receipt.get("accepted", false))
	if queued:
		_game_runtime_coordinator_node().record_legacy_viewer_feedback("%s触发角色被动：一张怪兽牌被临时改写为相位否决并进入匿名反制等待。" % _player_name(player_index))
		return true
	players = world_session.players.duplicate(true)
	player = players[player_index]
	slots = player.get("slots", [])
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index] = original_skill
		player["slots"] = slots
		players[player_index] = player
		world_session.replace_players(players)
	return false



func _player_facing_text_snapshot() -> Array:
	var result := []
	_collect_player_facing_text(self, result)
	return result


func _collect_player_facing_text(node: Node, result: Array) -> void:
	if node == null:
		return
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		result.append(String((node as Label).text))
	elif node is RichTextLabel:
		result.append(String((node as RichTextLabel).text))
	elif node is Button:
		result.append(String((node as Button).text))
	elif node is LineEdit:
		result.append(String((node as LineEdit).text))
	if node is Control:
		var tooltip := String((node as Control).tooltip_text)
		if tooltip != "":
			result.append(tooltip)
	for child in node.get_children():
		_collect_player_facing_text(child, result)


func _catalog_size() -> int:
	return MonsterCatalogV06.catalog_size()


func _catalog_entry(index: int) -> Dictionary:
	return MonsterCatalogV06.catalog_entry(index)


func _catalog_move_speed(index: int) -> float:
	return MonsterCatalogV06.catalog_move_speed(index)


func _monster_mobility_summary_from_fields(traits: Array, terrain_multiplier: Dictionary) -> String:
	var pieces := []
	if traits.has("flying"):
		pieces.append("飞行免碾压")
	if traits.has("aquatic"):
		pieces.append("水栖")
	var ocean := float(terrain_multiplier.get("ocean", 1.0))
	var land := float(terrain_multiplier.get("land", 1.0))
	if absf(ocean - 1.0) > 0.01 or absf(land - 1.0) > 0.01:
		pieces.append("海×%.2f/陆×%.2f" % [ocean, land])
	if pieces.is_empty():
		return "普通步行"
	return "、".join(pieces)


func _monster_catalog_index_by_name(monster_name: String) -> int:
	return MonsterCatalogV06.monster_catalog_index_by_name(monster_name)


func _monster_card_name(index: int, rank: int = 1) -> String:
	return MonsterCatalogV06.monster_card_name(index, rank)


func _monster_card_names(rank: int = 1) -> Array:
	return MonsterCatalogV06.monster_card_names(rank)


func _monster_name_from_card_name(card_name: String) -> String:
	var family := _game_runtime_coordinator_node().card_family_id(card_name)
	var prefix := "怪兽·"
	if not family.begins_with(prefix):
		return ""
	return family.substr(prefix.length())


func _is_monster_card_name(card_name: String) -> bool:
	return _monster_catalog_index_by_name(_monster_name_from_card_name(card_name)) >= 0


func _monster_card_definition(card_name: String) -> Dictionary:
	var monster_name := _monster_name_from_card_name(card_name)
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	if catalog_index < 0:
		return {}
	var rank := clampi(_game_runtime_coordinator_node().card_rank(card_name), 1, 4)
	var entry := _catalog_entry(catalog_index)
	var resource_focus: Array = entry.get("resource_focus", [])
	var supply_product := String(resource_focus[0]) if not resource_focus.is_empty() else "活体芯片"
	var hp_bonus := int(round(float(entry.get("hp", 40)) * (1.0 + float(rank - 1) * 0.22)))
	var move_bonus := float(entry.get("move", MonsterRuntimeController.MONSTER_RAMPAGE_MOVE_METERS)) * (1.0 + float(rank - 1) * 0.10)
	var duration := float(entry.get("duration", MonsterRuntimeController.MONSTER_CARD_DURATION_BASE_SECONDS + float(rank - 1) * MonsterRuntimeController.MONSTER_CARD_DURATION_RANK_STEP_SECONDS))
	var duration_text := "不限时" if duration < 0.0 else "%.0fs" % duration
	var summon_access := String(entry.get("summon_access", "monster_zone"))
	var summon_access_text := _monster_card_region_text({"summon_access": summon_access})
	var movement_traits: Array = (entry.get("movement_traits", []) as Array).duplicate(true)
	var terrain_move_multiplier: Dictionary = (entry.get("terrain_move_multiplier", {}) as Dictionary).duplicate(true)
	var mobility_text := _monster_mobility_summary_from_fields(movement_traits, terrain_move_multiplier)
	return {
		"kind": "monster_card",
		"monster_name": monster_name,
		"catalog_index": catalog_index,
		"cost": 5 + rank,
		"rank": rank,
		"supply_product": supply_product,
		"play_cash_per_monster": MONSTER_CARD_PLAY_CASH_PER_EXISTING,
		"summon_access": summon_access,
		"fixed_skill_count": rank,
		"hp": hp_bonus,
		"duration": duration,
		"move": move_bonus,
		"movement_traits": movement_traits,
		"terrain_move_multiplier": terrain_move_multiplier,
		"damage": 0,
		"range": 0.0,
		"tags": ["怪兽卡", "召唤", _level_text(rank)],
		"text": "召唤%s入场，或升级同名己方怪兽并刷新生命/在场时间。生命%d｜在场%s｜移动%s｜机动:%s｜区域:%s。I级免GDP门槛；II/III/IV级要求任一经营区GDP份额达到15%%/25%%/35%%。获得或刷新%d张固定技能；怪兽仍自动行动。场上每只已有怪兽使费用+¥%d。" % [
			monster_name,
			hp_bonus,
			duration_text,
			_meters_text(move_bonus),
			mobility_text,
			summon_access_text,
			rank,
			MONSTER_CARD_PLAY_CASH_PER_EXISTING,
		],
	}


func _monster_technique_card_name(monster_name: String, action_index: int, rank: int = 1) -> String:
	return MonsterCatalogV06.monster_technique_card_name(monster_name, action_index, rank)


func _is_monster_technique_card_name(card_name: String) -> bool:
	return _game_runtime_coordinator_node().card_family_id(card_name).begins_with("兽技·")


func _monster_technique_definition(card_name: String) -> Dictionary:
	var family := _game_runtime_coordinator_node().card_family_id(card_name)
	var prefix := "兽技·"
	if not family.begins_with(prefix):
		return {}
	var body := family.substr(prefix.length())
	var pieces := body.split("·")
	if pieces.size() < 2:
		return {}
	var monster_name := String(pieces[0])
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	if catalog_index < 0:
		return {}
	var index_text := String(pieces[1]).left(2)
	var action_index := maxi(0, int(index_text) - 1)
	var actions := _catalog_actions(catalog_index)
	if action_index < 0 or action_index >= actions.size():
		return {}
	var rank := clampi(_game_runtime_coordinator_node().card_rank(card_name), 1, 4)
	var action: Dictionary = (actions[action_index] as Dictionary).duplicate(true)
	var resource_focus: Array = _catalog_entry(catalog_index).get("resource_focus", [])
	var supply_product := String(resource_focus[0]) if not resource_focus.is_empty() else "活体芯片"
	var scaled_action := action.duplicate(true)
	if scaled_action.has("damage"):
		scaled_action["damage"] = maxi(1, int(round(float(scaled_action.get("damage", 1)) * (1.0 + float(rank - 1) * 0.20))))
	if scaled_action.has("move_override") and float(scaled_action.get("move_override", -1.0)) > 0.0:
		scaled_action["move_override"] = float(scaled_action.get("move_override", 0.0)) * (1.0 + float(rank - 1) * 0.08)
	return {
		"kind": "monster_bound_action",
		"monster_name": monster_name,
		"catalog_index": catalog_index,
		"action_index": action_index,
		"action": scaled_action,
		"cost": 2 + rank,
		"rank": rank,
		"persistent": true,
		"cooldown": maxf(2.0, DEFAULT_SKILL_COOLDOWN - float(rank - 1) * 0.25),
		"supply_product": supply_product,
		"damage": int(scaled_action.get("damage", 0)),
		"move": float(scaled_action.get("move_override", 0.0)),
		"range": float(scaled_action.get("range", 0.0)),
		"tags": ["固定技能", monster_name],
		"text": "%s的绑定固定技能：%s。使用后不会消失，但会进入冷却；怪兽本身仍会随机自动行动。" % [
			monster_name,
			String(scaled_action.get("text", "释放怪兽招式。")),
		],
	}


func _catalog_actions(index: int) -> Array:
	return MonsterCatalogV06.catalog_actions(index)


func _catalog_special_cards(index: int) -> Array:
	return MonsterCatalogV06.catalog_special_cards(index)


func _catalog_action_weights(actions: Array, any_destroyed: bool) -> Array:
	return MonsterCatalogV06.catalog_action_weights(actions, any_destroyed)


func _catalog_action_weights_for_index(index: int, any_destroyed: bool) -> Array:
	return MonsterCatalogV06.catalog_action_weights_for_index(index, any_destroyed, MonsterRuntimeController.MONSTER_SKILL_WEIGHT_TABLES)


func _ranked_action_weights(source_weights: Array, rank: int) -> Array:
	var weights := source_weights.duplicate()
	var bonus_rank: int = clampi(rank, 1, 4) - 1
	if bonus_rank <= 0:
		return weights
	for i in range(weights.size()):
		var weight := int(weights[i])
		if i >= 3:
			weight += bonus_rank * (i - 1)
		elif i >= 1:
			weight += max(0, bonus_rank - 1)
		weights[i] = weight
	return weights


func _catalog_ranked_action_weights_for_index(index: int, any_destroyed: bool, rank: int) -> Array:
	return _ranked_action_weights(_catalog_action_weights_for_index(index, any_destroyed), rank)


func _ranked_probability_delta_text(base_weight: int, base_total: int, ranked_weight: int, ranked_total: int) -> String:
	var base_probability := 0.0 if base_total <= 0 else float(base_weight) * 100.0 / float(base_total)
	var ranked_probability := 0.0 if ranked_total <= 0 else float(ranked_weight) * 100.0 / float(ranked_total)
	var delta := ranked_probability - base_probability
	if abs(delta) < 0.5:
		return "±0%"
	var rounded_delta := int(round(delta))
	if rounded_delta > 0:
		return "+%d%%" % rounded_delta
	return "%d%%" % rounded_delta


func _auto_monster_action_probability_text(actor: Dictionary, action_index: int, weights: Array, total: int, any_destroyed: bool) -> String:
	var probability := _probability_text(int(weights[action_index]), total)
	var rank := clampi(int(actor.get("rank", 1)), 1, 4)
	if rank <= 1:
		return probability
	var base_weights := _catalog_action_weights_for_index(int(actor.get("catalog_index", 0)), any_destroyed)
	var base_total := _weight_total(base_weights)
	var delta := _ranked_probability_delta_text(
		int(base_weights[action_index]) if action_index < base_weights.size() else 0,
		base_total,
		int(weights[action_index]),
		total
	)
	return "%s，%s修正%s" % [probability, _level_text(rank), delta]


func _compact_card_list(cards: Array, limit: int) -> String:
	if cards.is_empty():
		return "无专属卡"
	var names := []
	for i in range(min(limit, cards.size())):
		names.append(String(cards[i]))
	var suffix := ""
	if cards.size() > names.size():
		suffix = " 等%d张" % cards.size()
	return "%s%s" % [" / ".join(names), suffix]


func _append_unique_cards(result: Array, names: Array) -> void:
	for name_variant in names:
		var skill_name := _canonical_card_supply_name(String(name_variant))
		if skill_name == "" or result.has(skill_name):
			continue
		if not _game_runtime_coordinator_node().card_exists(skill_name):
			push_warning("卡牌目录缺少：%s" % skill_name)
			continue
		result.append(skill_name)


func _canonical_card_supply_name(skill_name: String) -> String:
	if skill_name == "":
		return ""
	var rank := _game_runtime_coordinator_node().card_rank(skill_name)
	if rank <= 0:
		return skill_name if _game_runtime_coordinator_node().card_exists(skill_name) else ""
	var base_name := "%s1" % _game_runtime_coordinator_node().card_family_id(skill_name)
	return base_name if _game_runtime_coordinator_node().card_exists(base_name) else ""


func _current_run_product_names() -> Array:
	var result := []
	for i in range(_game_runtime_coordinator_node().world_session_state().districts.size()):
		var district_variant: Variant = _game_runtime_coordinator_node().world_session_state().districts[i]
		if not (district_variant is Dictionary):
			continue
		var district: Dictionary = district_variant
		for product_variant in district.get("products", []):
			monster_runtime_controller._append_unique_string(result, String(product_variant))
		for demand_variant in district.get("demands", []):
			monster_runtime_controller._append_unique_string(result, String(demand_variant))
		var city := _district_city(i)
		if _city_is_active(city):
			for product_name_variant in _city_product_names(city):
				monster_runtime_controller._append_unique_string(result, String(product_name_variant))
			for demand_name_variant in _city_demand_names(city):
				monster_runtime_controller._append_unique_string(result, String(demand_name_variant))
	return result


func _district_local_product_names(district_index: int) -> Array:
	var result := []
	if district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return result
	var district: Dictionary = _game_runtime_coordinator_node().world_session_state().districts[district_index]
	for product_variant in district.get("products", []):
		monster_runtime_controller._append_unique_string(result, String(product_variant))
	for demand_variant in district.get("demands", []):
		monster_runtime_controller._append_unique_string(result, String(demand_variant))
	var city := _district_city(district_index)
	if _city_is_active(city):
		for product_name_variant in _city_product_names(city):
			monster_runtime_controller._append_unique_string(result, String(product_name_variant))
		for demand_name_variant in _city_demand_names(city):
			monster_runtime_controller._append_unique_string(result, String(demand_name_variant))
	return result


func _skill_fixed_product_requirements(skill: Dictionary) -> Array:
	var result := []
	var supply_product := String(skill.get("supply_product", skill.get("play_product", "")))
	if supply_product != "":
		monster_runtime_controller._append_unique_string(result, supply_product)
	return result


func _product_requirements_available(required_products: Array, run_products: Array) -> bool:
	if required_products.is_empty():
		return true
	if run_products.is_empty():
		return true
	for product_variant in required_products:
		if not run_products.has(String(product_variant)):
			return false
	return true


func _card_allowed_by_run_products(skill_name: String) -> bool:
	var canonical_name := _canonical_card_supply_name(skill_name)
	if canonical_name == "":
		return false
	var skill := _game_runtime_coordinator_node().card_definition(canonical_name)
	if skill.is_empty():
		return false
	if String(skill.get("kind", "")) == "monster_card":
		return _monster_card_allowed_by_run_products(canonical_name)
	var required_products := _skill_fixed_product_requirements(skill)
	return _product_requirements_available(required_products, _current_run_product_names())


func _monster_card_allowed_by_run_products(skill_name: String) -> bool:
	# Every region reserves a stable monster-card slot. Product and terrain
	# affinity decide *where* each monster is offered, not whether the family is
	# deleted from the run entirely.
	return _is_monster_card_name(skill_name)


func _run_allowed_monster_card_names(rank: int = 1) -> Array:
	var matched := []
	var all_cards := _monster_card_names(rank)
	for card_variant in all_cards:
		var card_name := String(card_variant)
		if _monster_card_allowed_by_run_products(card_name):
			matched.append(card_name)
	if matched.is_empty():
		return all_cards
	return matched


func _current_run_card_pool() -> Array:
	var result := []
	for skill_name_variant in _game_runtime_coordinator_node().card_catalog_public_pool():
		var skill_name := String(skill_name_variant)
		if _card_allowed_by_run_products(skill_name):
			_append_unique_cards(result, [skill_name])
	_append_unique_cards(result, _run_allowed_monster_card_names(1))
	return result


func _monster_action_animation_profile(_monster_name: String, action: Dictionary, _action_index: int = -1) -> Dictionary:
	var action_name := String(action.get("name", "行动"))
	var range_meters := float(action.get("range", 0.0))
	var move_override_mps := float(action.get("move_override", -1.0))
	var knockback_meters := float(action.get("knockback", 0.0))
	var throw_meters := float(action.get("throw_radius", 0.0))
	var damage := int(action.get("damage", 0))
	var motion_family := _monster_action_motion_family(action)
	var profile := {
		"motion_family": motion_family,
		"pose_key": _monster_action_pose_key(action_name),
		"effect_layer": _monster_action_effect_layer(action),
		"range_meters": range_meters,
		"move_override_mps": move_override_mps,
		"knockback_meters": knockback_meters,
		"throw_meters": throw_meters,
		"damage": damage,
		"anticipation_seconds": _monster_action_anticipation_seconds(motion_family, range_meters, move_override_mps),
		"active_seconds": _monster_action_active_seconds(motion_family, range_meters, knockback_meters, throw_meters),
		"recovery_seconds": _monster_action_recovery_seconds(motion_family, damage),
		"impact_seconds": 0.45 if knockback_meters > 0.0 or throw_meters > 0.0 else 0.18,
		"scale_contract": _monster_action_scale_contract(action),
	}
	profile["profile_key"] = _monster_action_animation_profile_key(profile)
	return profile


func _monster_action_animation_profile_key(profile: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(profile.get("motion_family", "")),
		str(profile.get("pose_key", "")),
		str(profile.get("effect_layer", "")),
		str(profile.get("range_meters", "")),
		str(profile.get("move_override_mps", "")),
		str(profile.get("knockback_meters", "")),
		str(profile.get("throw_meters", "")),
		str(profile.get("damage", "")),
	]


func _monster_action_motion_family(action: Dictionary) -> String:
	var action_name := String(action.get("name", ""))
	var range_meters := float(action.get("range", 0.0))
	var move_override_mps := float(action.get("move_override", -1.0))
	if action.has("throw_radius"):
		return "throw_grapple"
	if action.has("miasma_count"):
		return "miasma_zone"
	if action.has("repair") or action.has("repair_radius") or action.has("repair_path"):
		return "repair_beam"
	if action_name.contains("咆哮"):
		return "roar_wave"
	if action_name.contains("潜"):
		return "burrow_dash"
	if action_name.contains("打滚") or action_name.contains("滚"):
		return "roll_crush"
	if action_name.contains("炸弹") or action_name.contains("爆裂") or action_name.contains("爆弹"):
		return "blast_projectile"
	if action_name.contains("光线") or action_name.contains("射线") or action_name.contains("火花") or action_name.contains("连闪") or range_meters >= 420.0:
		return "beam_line"
	if move_override_mps > 0.0 and int(action.get("damage", 0)) > 0:
		return "dash_melee"
	if float(action.get("knockback", 0.0)) > 0.0:
		return "impact_melee"
	if int(action.get("damage", 0)) > 0:
		return "close_melee"
	return "utility_pose"


func _monster_action_effect_layer(action: Dictionary) -> String:
	var action_name := String(action.get("name", ""))
	if action.has("miasma_count") or action_name.contains("瘴"):
		return "miasma_cloud"
	if action.has("repair") or action.has("repair_radius") or action.has("repair_path"):
		return "repair_green"
	if action.has("paralyze") or action_name.contains("电") or action_name.contains("闪"):
		return "electric_arc"
	if action.has("cripple") or action_name.contains("刃") or action_name.contains("斩"):
		return "blade_arc"
	if action.has("stun") or action.has("knockback") or action.has("throw_radius"):
		return "impact_burst"
	if action_name.contains("火") or action_name.contains("焰") or action_name.contains("爆"):
		return "flame_burst"
	if action_name.contains("泥") or action_name.contains("地"):
		return "ground_crack"
	if action_name.contains("咆哮") or action_name.contains("潮") or action_name.contains("波"):
		return "shock_wave"
	return "body_motion"


func _monster_action_pose_key(action_name: String) -> String:
	var pose_seed := _art_identity_text_seed(action_name)
	return "%s_%03d" % [_monster_action_pose_family(action_name), pose_seed % 997]


func _monster_action_pose_family(action_name: String) -> String:
	if action_name.contains("翼") or action_name.contains("俯冲"):
		return "air_sweep"
	if action_name.contains("冲锋") or action_name.contains("肩撞") or action_name.contains("狂奔"):
		return "charge"
	if action_name.contains("光线") or action_name.contains("射线") or action_name.contains("火花") or action_name.contains("连闪"):
		return "beam"
	if action_name.contains("炸弹") or action_name.contains("爆"):
		return "bomb"
	if action_name.contains("修复") or action_name.contains("藤") or action_name.contains("绿洲"):
		return "support"
	if action_name.contains("瘴") or action_name.contains("腐蚀"):
		return "miasma"
	if action_name.contains("斩") or action_name.contains("刃") or action_name.contains("手刀"):
		return "blade"
	if action_name.contains("泥") or action_name.contains("潜") or action_name.contains("滚"):
		return "earth"
	if action_name.contains("咆哮") or action_name.contains("闪光"):
		return "wave"
	if action_name.contains("拳") or action_name.contains("踢") or action_name.contains("尾") or action_name.contains("掌"):
		return "melee"
	return "pose"


func _monster_action_anticipation_seconds(motion_family: String, range_meters: float, move_override_mps: float) -> float:
	if motion_family == "beam_line" or motion_family == "blast_projectile":
		return 0.32
	if motion_family == "dash_melee" or move_override_mps > 0.0:
		return 0.22
	if motion_family == "throw_grapple":
		return 0.28
	if range_meters <= 140.0:
		return 0.18
	return 0.24


func _monster_action_active_seconds(motion_family: String, range_meters: float, knockback_meters: float, throw_meters: float) -> float:
	if motion_family == "beam_line":
		return clampf(0.28 + range_meters / 2000.0, 0.32, 0.62)
	if motion_family == "throw_grapple":
		return 0.46
	if knockback_meters > 0.0 or throw_meters > 0.0:
		return 0.42
	return 0.30


func _monster_action_recovery_seconds(motion_family: String, damage: int) -> float:
	if motion_family == "blast_projectile" or damage >= 5:
		return 0.58
	if motion_family == "beam_line":
		return 0.42
	return 0.30


func _monster_action_scale_contract(action: Dictionary) -> String:
	var range_meters := float(action.get("range", 0.0))
	var move_override_mps := float(action.get("move_override", -1.0))
	var knockback_meters := float(action.get("knockback", 0.0))
	var throw_meters := float(action.get("throw_radius", 0.0))
	return "range:%sm｜move:%sm/s｜knock:%sm｜throw:%sm｜linear-meter-stage" % [
		_meters_number_text(range_meters),
		_meters_number_text(move_override_mps),
		_meters_number_text(knockback_meters),
		_meters_number_text(throw_meters),
	]


func _meters_number_text(value: float) -> String:
	if value < 0.0:
		return "-"
	return str(int(round(value)))


func _art_identity_text_seed(text: String) -> int:
	var text_seed := 193
	for i in range(text.length()):
		text_seed = (text_seed * 37 + text.unicode_at(i)) % 1000003
	return max(1, text_seed)


func _monster_market_skills() -> Array:
	return _current_run_card_pool()


func _skill_tag_text(skill: Dictionary) -> String:
	var tags: Array = skill.get("tags", [])
	if tags.is_empty():
		tags = _derived_skill_tags(String(skill.get("kind", "")))
	return " / ".join(tags)


func _skill_display_text(skill: Dictionary) -> String:
	var text := _player_card_effect_text(skill)
	if monster_runtime_controller.auto_monsters.is_empty():
		return text
	text = text.replace("除自身外，所有已装备卡牌立即+1补给。", "从当前区域额外获取1张候选卡。")
	text = text.replace("除自身外，所有已装备卡牌立即+2补给", "从当前区域额外获取2张候选卡")
	text = text.replace("补给连锁", "补给连锁")
	text = text.replace("补给", "补给")
	text = text.replace("其他怪兽概率行动", "怪兽特殊行动")
	text = text.replace("其他怪兽行动", "怪兽特殊行动")
	return text


func _player_card_effect_text(skill: Dictionary) -> String:
	var kind := String(skill.get("kind", ""))
	match kind:
		"monster_card":
			return "召唤%s：HP%d｜在场%s｜移速%s｜%s。升级同名在场怪兽会刷新生命和时间。" % [
				String(skill.get("monster_name", "怪兽")),
				int(skill.get("hp", 0)),
				_monster_card_duration_text(skill, true),
				_meters_text(float(skill.get("move", 0.0))),
				_monster_card_region_text(skill, true),
			]
		"city_gdp_derivative":
			var terms := _city_gdp_derivative_terms(skill)
			var side := "保单" if bool(terms.get("insurance", false)) else ("买涨" if String(terms.get("direction", "up")) == "up" else "做空")
			return "押目标城市%s：%s｜保证金¥%d｜收益≤¥%d｜损失≤¥%d。" % [
				side,
				_duration_short_text(float(terms.get("duration_seconds", _city_gdp_derivative_duration_seconds(skill)))),
				int(terms.get("margin_cash", 0)),
				int(terms.get("maximum_gain", 0)),
				int(terms.get("maximum_loss", 0)),
			]
		"product_futures":
			var futures_terms: Dictionary = skill.get("futures_terms", {}) if skill.get("futures_terms", {}) is Dictionary else {}
			if futures_terms.is_empty():
				var market_controller := _product_market_runtime_controller_node()
				futures_terms = market_controller.terms_for_card_id(String(skill.get("name", ""))) if market_controller != null else {}
			var side := "看涨" if String(futures_terms.get("direction", "up")) == "up" else "看跌"
			var warehouse := "｜需要仓储城市" if bool(futures_terms.get("requires_warehouse", false)) else ""
			return "押当前商品%s：%s｜保证金¥%d｜收益≤¥%d｜损失≤¥%d%s。" % [
				side,
				_duration_short_text(float(futures_terms.get("duration_seconds", _product_market_futures_duration_seconds(skill)))),
				int(futures_terms.get("margin_cash", 0)),
				int(futures_terms.get("maximum_gain", 0)),
				int(futures_terms.get("maximum_loss", 0)),
				warehouse,
			]
		"weather_control":
			return "改写下一条天气预报：%s｜约%s后影响%d区，持续%s。" % [
				weather_runtime_controller.label(String(skill.get("weather_type", "solar_flare"))),
				_duration_short_text(float(skill.get("weather_forecast_lead_seconds", WeatherRuntimeController.FORECAST_LEAD_MIN_SECONDS))),
				maxi(1, int(skill.get("weather_zone_count", 1))),
				_duration_short_text(float(skill.get("weather_duration_seconds", WeatherRuntimeController.DURATION_MIN_SECONDS))),
			]
		"military_force":
			return "部署%s：HP%d｜伤害%d｜移速%s｜存续%s。" % [
				military_runtime_controller.unit_type_label(skill),
				military_runtime_controller.unit_hp(skill),
				military_runtime_controller.unit_damage(skill),
				_meters_text(float(skill.get("military_move", 0.0))),
				_duration_short_text(military_runtime_controller.unit_duration(skill)),
			]
		"military_command":
			return "军令：%s｜范围%s。军队按指令行动，不会像怪兽一样自动踩城。" % [
				military_runtime_controller.command_label(String(skill.get("military_command", ""))),
				_meters_text(float(skill.get("range", 0.0))),
			]
		"player_hand_disrupt":
			return "指定玩家弃%d张普通手牌%s。" % [
				maxi(1, int(skill.get("hand_discard_count", 1))),
				"｜封锁%s" % _duration_short_text(float(skill.get("hand_lock_seconds", 0.0))) if float(skill.get("hand_lock_seconds", 0.0)) > 0.0 else "",
			]
		"player_hand_steal":
			return "从指定玩家处牵走%d张普通手牌%s。" % [
				maxi(1, int(skill.get("hand_steal_count", 1))),
				"｜封锁%s" % _duration_short_text(float(skill.get("hand_lock_seconds", 0.0))) if float(skill.get("hand_lock_seconds", 0.0)) > 0.0 else "",
			]
		"city_control_dispute":
			return "扰乱目标城市归属：冻结%s｜GDP-%d。" % [
				_duration_short_text(float(skill.get("control_block_seconds", 0.0))),
				int(skill.get("control_gdp_penalty", 0)),
			]
		"global_barrage":
			return "全场齐射：选择%d座城市，各受%d区域伤害%s。" % [
				maxi(1, int(skill.get("global_barrage_target_count", 1))),
				maxi(1, int(skill.get("global_barrage_damage", 1))),
				"｜断路+%d" % int(skill.get("global_barrage_route_damage", 0)) if int(skill.get("global_barrage_route_damage", 0)) > 0 else "",
			]
		"card_counter":
			return "相位响应：%s内可取消一张直接互动牌｜强度%d%s。" % [
				_duration_short_text(float(skill.get("counter_window_seconds", _ruleset_timing_seconds(&"counter_window_seconds")))),
				maxi(1, int(skill.get("counter_strength", 1))),
				"｜返还¥%d" % int(skill.get("counter_refund", 0)) if int(skill.get("counter_refund", 0)) > 0 else "",
			]
	var text := _realtime_rule_text(String(skill.get("text", "即时改变局势。")))
	return _player_sanitize_rule_text(text)


func _player_sanitize_rule_text(text: String) -> String:
	var result := text
	result = result.replace("打出前必须先", "先")
	result = result.replace("必须先", "先")
	result = result.replace("前5秒只向全员公开", "公开")
	result = result.replace("前5秒向全员公开", "公开")
	result = result.replace("展示结束后，目标城市业主另有5秒签/拒窗口，其他玩家此时仍可继续出牌。", "展示后目标业主签/拒。")
	result = result.replace("展示结束后，目标业主另有5秒签/拒窗口。", "展示后目标业主签/拒。")
	result = result.replace("展示沙漏公开", "公开")
	result = result.replace("展示结束后，目标城市业主获得独立签/拒窗口，其他玩家此时仍可继续出牌。", "展示后目标业主签/拒。")
	result = result.replace("随后目标业主签/拒。", "目标业主签/拒。")
	result = result.replace("出牌者和真实城市业主仍按规则隐藏。", "")
	result = result.replace("按规则隐藏", "保持匿名")
	result = result.replace("新规则下", "")
	result = result.replace("旧", "")
	result = result.replace("不再", "")
	result = result.replace("不能", "不可")
	return result


func _realtime_rule_text(text: String) -> String:
	var result := text
	result = result.replace("每个经营周期收入", "GDP/min")
	result = result.replace("每个经营周期额外", "每分钟现金流额外")
	result = result.replace("每个经营周期", "每分钟")
	result = result.replace("周期收入", "GDP/min")
	result = result.replace("/周期", "/min")
	result = result.replace("下一次市场重算", "下一次全局市场刷新")
	result = result.replace("下一次供需重算", "下一次全局市场刷新")
	result = result.replace("价格由供需重算体现", "价格由全局供需刷新体现")
	result = result.replace("等待下一次市场重算兑现", "等待下一次全局市场刷新兑现")
	result = result.replace("等待下一次供需重算兑现", "等待下一次全局市场刷新兑现")
	for duration_units in range(1, 13):
		var duration_text := _duration_short_text(_legacy_turns_to_seconds(duration_units))
		result = result.replace("持续%d周期" % duration_units, "持续%s" % duration_text)
		result = result.replace("持续%d个经营周期" % duration_units, "持续%s" % duration_text)
		result = result.replace("接下来%d个经营周期" % duration_units, "接下来%s" % duration_text)
		result = result.replace("%d周期" % duration_units, duration_text)
	result = result.replace("经营周期", "实时窗口")
	return result


func _derived_skill_tags(kind: String) -> Array:
	match kind:
		"cash_gain":
			return ["经济"]
		"city_revenue_boost":
			return ["经营"]
		"city_contract_boon":
			return ["经营", "合约"]
		"product_speculation":
			return ["经济", "商品"]
		"product_contract_boon":
			return ["经济", "合约"]
		"player_hand_disrupt":
			return ["互动", "拆牌"]
		"player_hand_steal":
			return ["互动", "牵牌"]
		"city_control_dispute":
			return ["互动", "城市"]
		"global_barrage":
			return ["互动", "齐射"]
		"card_counter":
			return ["互动", "反制"]
		"military_force":
			return ["军队", "短时资产"]
		"military_command":
			return ["军令", "固定技能"]
		"route_insurance":
			return ["经营", "商路"]
		"city_product_upgrade":
			return ["经营", "升级"]
		"city_product_shift":
			return ["经营", "换线"]
		"city_demand_shift":
			return ["经营", "需求"]
		"market_stabilize":
			return ["经济", "稳定"]
		"product_growth_boon":
			return ["经济", "催化"]
		"route_flow_boon":
			return ["经营", "物流"]
		"region_economy_shift":
			return ["区域", "GDP"]
		"intel_city_reveal":
			return ["情报", "区域"]
		"card_history_public_review", "card_history_subscription":
			return ["情报", "卡牌"]
		"weather_control":
			return ["天气"]
		"monster_lure":
			return ["诱导"]
		"supply_draw":
			return ["构筑"]
		"special_monster_delay":
			return ["控场"]
		"move", "fly", "burrow":
			return ["机动"]
		"attack", "charge_attack", "roll_attack":
			return ["攻击"]
		"area_damage", "mudslide":
			return ["破坏"]
		"miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath":
			return ["瘴气"]
		"armor_gain":
			return ["防御"]
		"guard":
			return ["防御"]
		"roar":
			return ["控场"]
	return ["即时"]


func _preset_float(key: String) -> float:
	return float(REALTIME_BALANCE.get(key, 0.0))


func _preset_int(key: String) -> int:
	return int(REALTIME_BALANCE.get(key, 0))


func _roll_timer(prefix: String) -> float:
	var low: float = _preset_float("%s_min" % prefix)
	var high: float = _preset_float("%s_max" % prefix)
	return low + _game_runtime_coordinator_node().run_rng_service().randf_range(0.0, max(0.0, high - low))



func _weight_total(weights: Array) -> int:
	var total := 0
	for weight in weights:
		total += max(0, int(weight))
	return total


func _weighted_pick_index(weights: Array) -> int:
	var total := _weight_total(weights)
	if total <= 0:
		return -1
	var ticket := _game_runtime_coordinator_node().run_rng_service().randi_range(1, total)
	var running := 0
	for i in range(weights.size()):
		running += max(0, int(weights[i]))
		if ticket <= running:
			return i
	return weights.size() - 1


func _probability_text(weight: int, total: int) -> String:
	if total <= 0:
		return "0%"
	return "%.0f%%" % (float(weight) * 100.0 / float(total))


func _roman_level(rank: int) -> String:
	match clampi(rank, 1, 10):
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		6:
			return "VI"
		7:
			return "VII"
		8:
			return "VIII"
		9:
			return "IX"
		10:
			return "X"
	return "I"


func _level_text(rank: int) -> String:
	return "%s级" % _roman_level(rank)


func _card_display_name(card_name: String) -> String:
	if card_name == "":
		return ""
	var family := _game_runtime_coordinator_node().card_family_id(card_name)
	var rank := maxi(1, _game_runtime_coordinator_node().card_rank(card_name))
	return "%s %s" % [family, _level_text(rank)]


func _has_destroyed_district() -> bool:
	for d in _game_runtime_coordinator_node().world_session_state().districts:
		if bool(d["destroyed"]):
			return true
	return false


func _weight_part_total(parts: Dictionary) -> int:
	var total := 0
	for key in parts:
		total += max(0, int(parts[key]))
	return total






func _route_network_load_for_legacy_region(index: int) -> int:
	return int(_route_network_runtime_call("route_load_for_legacy_region", [index]))


func _is_upgrade_card(skill_name: String) -> bool:
	if skill_name == "" or not _game_runtime_coordinator_node().card_exists(skill_name):
		return false
	var family := _game_runtime_coordinator_node().card_family_id(skill_name)
	var rank := _game_runtime_coordinator_node().card_rank(skill_name)
	return rank > 1 and _game_runtime_coordinator_node().card_exists("%s%d" % [family, rank - 1])


func _card_group_control_status_text(player_index: int) -> String:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return "牌组状态：无当前玩家"
	var queued_index := _queued_card_entry_index_for_player(player_index)
	var next_queued_index := _next_batch_card_entry_index_for_player(player_index)
	if queued_index >= 0:
		var group_count := _card_group_count_for_player(player_index)
		var group_limit := _card_group_limit_for_player(player_index)
		var window_phase := _card_group_window_phase()
		var controller := _card_resolution_controller_node()
		var debug_variant: Variant = controller.call("debug_snapshot") if controller != null and controller.has_method("debug_snapshot") else {}
		var debug: Dictionary = debug_variant if debug_variant is Dictionary else {}
		var ready_players: Dictionary = debug.get("ready_players", {}) if debug.get("ready_players", {}) is Dictionary else {}
		var ready_text := "已确认" if bool(ready_players.get(str(player_index), false)) else "待确认"
		if window_phase == "public_bid":
			return "牌组状态：公开展示阶段｜本组%d/%d张｜%s｜不能再加牌" % [group_count, group_limit, ready_text]
		if window_phase == "planning":
			return "牌组状态：规划阶段｜本组%d/%d张｜%s｜可调整组内顺序" % [group_count, group_limit, ready_text]
		if window_phase == "lock":
			return "牌组状态：锁牌阶段｜本组%d/%d张｜%s｜不能加牌或改目标" % [group_count, group_limit, ready_text]
		var next_suffix := "｜另有响应牌等待" if next_queued_index >= 0 else ""
		return "牌组状态：卡牌组已封盘｜按轮换席位和组内顺序结算%s" % next_suffix
	if next_queued_index >= 0:
		return "牌组状态：相位响应牌已提交｜当前组结算后清理"
	if card_resolution_batch_locked or not _card_resolution_active_entry().is_empty():
		return "牌组状态：当前卡牌组连续结算中｜普通牌保留到下一共享窗"
	if not _card_resolution_current_queue().is_empty():
		var current_phase := _card_group_window_phase()
		if current_phase == "planning":
			return "牌组状态：规划阶段｜现在打牌会建立自己的公开牌组"
		return "牌组状态：%s阶段｜当前不能新建普通牌组" % _card_group_phase_label(current_phase)
	return "牌组状态：空闲｜下一张普通牌会开启%s" % _card_group_window_cadence_text(_card_group_next_window_sequence())


func _queued_card_entry_index_for_player(player_index: int) -> int:
	var service := _card_resolution_queue_service_node()
	return int(service.call("entry_index_for_player", player_index, false)) if service != null and service.has_method("entry_index_for_player") else -1


func _next_batch_card_entry_index_for_player(player_index: int) -> int:
	var service := _card_resolution_queue_service_node()
	return int(service.call("entry_index_for_player", player_index, true)) if service != null and service.has_method("entry_index_for_player") else -1






func _card_resolution_status_text() -> String:
	var phase_text := _card_resolution_phase_text()
	if phase_text != "":
		return phase_text
	return "阶段：空闲｜无卡牌结算"


func _card_resolution_phase_text(entry: Dictionary = {}, _seconds_left: float = -1.0) -> String:
	var queued := _card_resolution_current_queue().size()
	var window_phase := _card_group_window_phase()
	if window_phase == "public_bid":
		return "阶段：公开展示｜剩余%d秒｜匿名组%d｜新牌：保留手牌｜可确认准备" % [
			int(ceil(_card_group_phase_remaining_seconds())),
			_card_resolution_groups().size(),
		]
	if window_phase == "planning":
		return "阶段：规划｜剩余%d秒｜匿名组%d｜牌%d｜普通上限%d张｜可调顺序/准备" % [
			int(ceil(_card_group_phase_remaining_seconds())),
			_card_resolution_groups().size(),
			queued,
			_card_group_limit_for_player(_runtime_snapshot_player_index()),
		]
	if window_phase == "lock":
		return "阶段：锁牌｜剩余%d秒｜匿名组%d｜牌%d｜不能加牌或改目标" % [
			int(ceil(_card_group_phase_remaining_seconds())),
			_card_resolution_groups().size(),
			queued,
		]
	var active_entry := entry
	if active_entry.is_empty() and not _card_resolution_active_entry().is_empty():
		active_entry = _card_resolution_active_entry()
	if not active_entry.is_empty():
		if card_resolution_counter_window_active:
			return "阶段：相位响应｜可打反制｜原牌暂未结算｜匿名公开动作"
		return "阶段：组内连续结算｜锁定候补%d｜普通牌等待下一窗口｜匿名公开动作" % queued
	if queued > 0:
		return "阶段：卡牌组锁定｜锁定候补%d｜可加价：否｜普通牌等待下一窗口" % queued
	return ""


func _next_upgrade_name(skill_name: String) -> String:
	if skill_name == "" or not _game_runtime_coordinator_node().card_exists(skill_name):
		return ""
	var family := _game_runtime_coordinator_node().card_family_id(skill_name)
	var rank := _game_runtime_coordinator_node().card_rank(skill_name)
	if rank <= 0 or rank >= 4:
		return ""
	var next_name := "%s%d" % [family, rank + 1]
	return next_name if _game_runtime_coordinator_node().card_exists(next_name) else ""


func _find_highest_family_card_slot(player: Dictionary, skill_name: String) -> int:
	var family := _game_runtime_coordinator_node().card_family_id(skill_name)
	var best_slot := -1
	var best_rank := -1
	for i in range(player["slots"].size()):
		var skill = player["slots"][i]
		if skill == null:
			continue
		var current_name := String(skill.get("name", ""))
		if _game_runtime_coordinator_node().card_family_id(current_name) != family:
			continue
		var rank := maxi(1, _game_runtime_coordinator_node().card_rank(current_name))
		if rank > best_rank:
			best_rank = rank
			best_slot = i
	return best_slot


func _first_empty_or_new_slot(player: Dictionary) -> int:
	for i in range(player["slots"].size()):
		if player["slots"][i] == null:
			return i
	player["slots"].append(null)
	return player["slots"].size() - 1


func _is_hand_limit_exempt_skill(skill: Dictionary) -> bool:
	return ["monster_bound_action", "military_command"].has(String(skill.get("kind", ""))) and bool(skill.get("persistent", false))


func _counts_toward_hand_limit(skill: Dictionary) -> bool:
	return not _is_hand_limit_exempt_skill(skill)


func _player_counted_hand_size(player: Dictionary) -> int:
	var count := 0
	for skill_variant in player.get("slots", []):
		if not (skill_variant is Dictionary):
			continue
		if _counts_toward_hand_limit(skill_variant as Dictionary):
			count += 1
	return count


func _card_inventory_snapshot(player: Dictionary, incoming_card: Dictionary = {}, incoming_card_id: String = "", discard_slot: int = -1, allows_family_upgrade: bool = true) -> Dictionary:
	var slot_facts: Array = []
	var player_slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	for slot_index in range(player_slots.size()):
		var skill_variant: Variant = player_slots[slot_index]
		if not (skill_variant is Dictionary):
			slot_facts.append({"slot_index": slot_index, "occupied": false})
			continue
		var current_skill: Dictionary = skill_variant
		var current_card_id := str(current_skill.get("name", ""))
		var next_upgrade_id := _next_upgrade_name(current_card_id)
		var counts_toward_limit := _counts_toward_hand_limit(current_skill)
		slot_facts.append({
			"slot_index": slot_index,
			"occupied": true,
			"card_id": current_card_id,
			"family": _game_runtime_coordinator_node().card_family_id(current_card_id),
			"rank": maxi(1, _game_runtime_coordinator_node().card_rank(current_card_id)),
			"counts_toward_hand_limit": counts_toward_limit,
			"queued_for_resolution": bool(current_skill.get("queued_for_resolution", false)),
			"lock_left": float(current_skill.get("lock_left", 0.0)),
			"next_upgrade_id": next_upgrade_id,
			"next_upgrade_card": _make_skill(next_upgrade_id) if next_upgrade_id != "" else {},
		})
	return {
		"valid": incoming_card_id != "" and not incoming_card.is_empty(),
		"incoming_card_id": incoming_card_id,
		"incoming_card": incoming_card.duplicate(true),
		"incoming_family": _game_runtime_coordinator_node().card_family_id(incoming_card_id),
		"incoming_rank": maxi(1, int(incoming_card.get("rank", _game_runtime_coordinator_node().card_rank(incoming_card_id)))) if not incoming_card.is_empty() else 0,
		"incoming_counts_toward_hand_limit": _counts_toward_hand_limit(incoming_card) if not incoming_card.is_empty() else true,
		"incoming_allows_family_upgrade": allows_family_upgrade,
		"counted_hand_size": _player_counted_hand_size(player),
		"hand_limit": PLAYER_HAND_LIMIT,
		"discard_slot": discard_slot,
		"slots": slot_facts,
	}


func _can_view_player_private_hand(player_index: int) -> bool:
	return _game_runtime_coordinator_node().presentation_can_view_private_subject(player_index)


func _local_human_player_index() -> int:
	return _game_runtime_coordinator_node().presentation_authorized_viewer_index()


func _player_has_committed_or_resolved_card(player_index: int) -> bool:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return false
	if int(_card_resolution_active_entry().get("player_index", -1)) == player_index and _card_entry_counts_for_tableau(_card_resolution_active_entry()):
		return true
	for queue_variant in [_card_resolution_current_queue(), _card_resolution_next_queue(), _game_runtime_coordinator_node().card_resolution_history_snapshot()]:
		for entry_variant in queue_variant:
			if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index and _card_entry_counts_for_tableau(entry_variant as Dictionary):
				return true
	return false


func _card_entry_counts_for_tableau(entry: Dictionary) -> bool:
	var skill: Dictionary = entry.get("skill", {}) if entry.get("skill", {}) is Dictionary else {}
	return not bool(skill.get("starter_play_free", false))


func _player_tableau_progress_entries(player_index: int) -> Array:
	if player_index < 0 or player_index >= _game_runtime_coordinator_node().world_session_state().players.size():
		return []
	var can_view_private := _can_view_player_private_hand(player_index)
	var viewer_index := _local_human_player_index()
	if not can_view_private:
		return [
			{"text": "公开线索", "state": _player_visible_city_text(player_index, viewer_index), "accent": Color("#38bdf8"), "active": true, "tip": "对手城市业主仍靠标注和公开线索推理。"},
			{"text": "明怪", "state": "%d" % _player_visible_monster_count(player_index, viewer_index), "accent": Color("#fb7185"), "active": _player_visible_monster_count(player_index, viewer_index) > 0, "tip": "只统计已公开归属或本席可见的怪兽。"},
			{"text": "明军", "state": "%d" % military_runtime_controller.visible_unit_count(player_index, viewer_index), "accent": Color("#67e8f9"), "active": military_runtime_controller.visible_unit_count(player_index, viewer_index) > 0, "tip": "只显示公开归属的军队线索。"},
			{"text": "牌轨", "state": "看公开", "accent": Color("#c084fc"), "active": not _game_runtime_coordinator_node().card_resolution_history_snapshot().is_empty() or not _card_resolution_current_queue().is_empty(), "tip": "只能从匿名牌轨、公开展示、准备状态和结算结果推理。"},
			{"text": "资金/手牌", "state": "隐私", "accent": Color("#94a3b8"), "active": false, "tip": "对手现金、真实手牌数量、弃牌和AI内部计划不显示。"},
		]
	var player: Dictionary = _game_runtime_coordinator_node().world_session_state().players[player_index]
	var has_monster := int(_ai_runtime_call("_ai_owned_active_monster_count", [player_index])) > 0
	var city_count := _player_active_city_count(player_index)
	var bought_card := int(player.get("card_purchase_count", 0)) > 0
	var committed_card := _player_has_committed_or_resolved_card(player_index)
	var score := _victory_player_progress_metric(player_index)
	var goal := _victory_required_gdp()
	return [
		{"text": "怪兽牌", "state": "已召" if has_monster else "可选", "accent": Color("#fb7185"), "active": has_monster, "tip": "起始怪兽牌已持有；召唤完全自愿，不阻断经济或购牌。"},
		{"text": "建城", "state": "城%d" % city_count if city_count > 0 else "待建", "accent": Color("#22c55e"), "active": city_count > 0, "tip": "项目归属GDP决定收入、区域控制和审计资格。"},
		{"text": "买牌", "state": "已买" if bought_card else "看牌架", "accent": Color("#f59e0b"), "active": bought_card, "tip": "双击区域查看全局挂牌；来源区域受光时可锁定5秒报价。"},
		{"text": "匿名牌", "state": "已入轨" if committed_card else "待出牌", "accent": Color("#c084fc"), "active": committed_card, "tip": "打出的牌进入公开匿名牌轨；条件和结果会给其他玩家推理线索。"},
		{"text": "审计", "state": _victory_control_status_text(), "accent": Color("#f97316"), "active": _victory_control_is_active() or score >= goal, "tip": "控制当前存续区域的40%并达到前K区商品GDP门槛后，先保持10秒，再进入120秒公开审计。"},
	]


func _acquire_inventory_skill_for_player(player: Dictionary, incoming_skill: Dictionary, allows_family_upgrade: bool = true) -> bool:
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("plan_card_inventory_receive") or not runtime_coordinator.has_method("commit_card_inventory_receive"):
		_mark_game_runtime_coordinator_missing(true)
		return false
	var incoming_card_id := str(incoming_skill.get("name", ""))
	var inventory_snapshot := _card_inventory_snapshot(player, incoming_skill, incoming_card_id, -1, allows_family_upgrade)
	var plan_variant: Variant = runtime_coordinator.call("plan_card_inventory_receive", inventory_snapshot)
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	if str(plan.get("status", "")) != "ready":
		return false
	var result_variant: Variant = runtime_coordinator.call("commit_card_inventory_receive", player, inventory_snapshot, plan)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	return bool(result.get("committed", false))


func _acquire_card_for_player(player: Dictionary, skill_name: String, _district_index: int, _source: String, _anonymous: bool = false) -> bool:
	var canonical_card_id := _canonical_card_supply_name(skill_name)
	if canonical_card_id == "" or not _game_runtime_coordinator_node().card_exists(canonical_card_id):
		return false
	return _acquire_inventory_skill_for_player(player, _make_skill(canonical_card_id), true)






func _default_economy_product() -> String:
	if _game_runtime_coordinator_node().table_selection_state().selected_trade_product != "" and ProductMarketRuntimeController.PRODUCT_CATALOG.has(_game_runtime_coordinator_node().table_selection_state().selected_trade_product):
		return _game_runtime_coordinator_node().table_selection_state().selected_trade_product
	if _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size():
		var district: Dictionary = _game_runtime_coordinator_node().world_session_state().districts[_game_runtime_coordinator_node().table_selection_state().selected_district]
		var products: Array = district.get("products", [])
		if not products.is_empty():
			return String(products[0])
		var demands: Array = district.get("demands", [])
		if not demands.is_empty():
			return String(demands[0])
		var city := _district_city(_game_runtime_coordinator_node().table_selection_state().selected_district)
		if _city_is_active(city):
			var city_products := _city_product_names(city)
			if not city_products.is_empty():
				return String(city_products[0])
			var city_demands := _city_demand_names(city)
			if not city_demands.is_empty():
				return String(city_demands[0])
	if ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
		return ""
	return String(ProductMarketRuntimeController.PRODUCT_CATALOG[0])


func _merge_boon_source(existing: String, source: String) -> String:
	var result := _card_economy_product_route_formula_result("merge_boon_source", {
		"existing": existing,
		"source": source,
	})
	return str(result.get("value", existing))


func _product_market_boon_text(product_name: String) -> String:
	var entry := _product_market_entry_snapshot(product_name)
	if entry.is_empty():
		return "无"
	var pieces := []
	var weather_driver := String(entry.get("weather_driver_summary", "无天气因素"))
	if weather_driver != "无天气因素":
		pieces.append(weather_driver)
	var growth_multiplier: float = float(entry.get("growth_multiplier", 1.0))
	if growth_multiplier > 1.001:
		var growth_source := String(entry.get("growth_source", entry.get("base_growth_source", "")))
		var growth_source_suffix := "｜%s" % growth_source if growth_source != "" else ""
		pieces.append("增速×%.2f（%s%s）" % [
			growth_multiplier,
			_boon_duration_text(_remaining_effect_seconds(entry, "growth_seconds", "growth_turns")),
			growth_source_suffix,
		])
	var route_multiplier: float = float(entry.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		var route_source := String(entry.get("route_flow_source", entry.get("base_route_flow_source", "")))
		var route_source_suffix := "｜%s" % route_source if route_source != "" else ""
		pieces.append("流通×%.2f（%s%s）" % [
			route_multiplier,
			_boon_duration_text(_remaining_effect_seconds(entry, "route_flow_seconds", "route_flow_turns")),
			route_source_suffix,
		])
	var contract_seconds := _remaining_effect_seconds(entry, "market_contract_seconds", "market_contract_turns")
	var _contract_turns := int(entry.get("market_contract_turns", 0))
	var contract_demand := int(entry.get("market_contract_demand", 0))
	var contract_supply := int(entry.get("market_contract_supply", 0))
	if contract_seconds > 0.0 and (contract_demand > 0 or contract_supply > 0):
		var contract_source := String(entry.get("market_contract_source", ""))
		var contract_source_suffix := "｜%s" % contract_source if contract_source != "" else ""
		var pressure_parts := []
		if contract_demand > 0:
			pressure_parts.append("需+%d" % contract_demand)
		if contract_supply > 0:
			pressure_parts.append("供+%d" % contract_supply)
		pieces.append("商品合约%s（%s%s）" % [
			"/".join(pressure_parts),
			_boon_duration_text(contract_seconds),
			contract_source_suffix,
		])
	var futures_text := _product_market_futures_public_text(product_name)
	if futures_text != "":
		pieces.append(futures_text)
	if pieces.is_empty():
		return "无"
	return "；".join(pieces)


func _reset_city_warehouse_stockpile_marker(city: Dictionary) -> Dictionary:
	if city.is_empty():
		return city
	city["warehouse_stockpile_count"] = 0
	city["warehouse_stockpile_units"] = 0
	city["warehouse_stockpile_products"] = []
	city["warehouse_stockpile_expires_at"] = -1.0
	return city


func _normalize_city_warehouse_stockpile_fields(city: Dictionary) -> Dictionary:
	if city.is_empty():
		return city
	if not city.has("warehouse_stockpile_count"):
		city["warehouse_stockpile_count"] = 0
	if not city.has("warehouse_stockpile_units"):
		city["warehouse_stockpile_units"] = 0
	if not city.has("warehouse_stockpile_products"):
		city["warehouse_stockpile_products"] = []
	if not city.has("warehouse_stockpile_expires_at"):
		city["warehouse_stockpile_expires_at"] = -1.0
	return city


func _add_city_warehouse_stockpile_marker(district_index: int, product_name: String, units: int, expires_at: float) -> void:
	if district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return
	var city := _normalize_city_warehouse_stockpile_fields(_district_city(district_index))
	if not _city_is_active(city):
		return
	city["warehouse_stockpile_count"] = int(city.get("warehouse_stockpile_count", 0)) + 1
	city["warehouse_stockpile_units"] = int(city.get("warehouse_stockpile_units", 0)) + maxi(1, units)
	var products: Array = city.get("warehouse_stockpile_products", [])
	monster_runtime_controller._append_unique_string(products, product_name)
	city["warehouse_stockpile_products"] = products
	var current_expires := float(city.get("warehouse_stockpile_expires_at", -1.0))
	if current_expires < 0.0 or expires_at < current_expires:
		city["warehouse_stockpile_expires_at"] = expires_at
	_game_runtime_coordinator_node().world_session_state().districts[district_index]["city"] = city


func _refresh_warehouse_stockpile_city_markers() -> void:
	for district_index in range(_game_runtime_coordinator_node().world_session_state().districts.size()):
		var city := _district_city(district_index)
		if city.is_empty():
			continue
		_game_runtime_coordinator_node().world_session_state().districts[district_index]["city"] = _reset_city_warehouse_stockpile_marker(city)
	var market_snapshot: Dictionary = _product_market_runtime_state().get("product_market", {}) as Dictionary
	for product_variant in market_snapshot.keys():
		var product_name := String(product_variant)
		var entry := _product_market_entry_snapshot(product_name)
		if entry.is_empty():
			continue
		var futures: Array = entry.get("futures_positions", [])
		for futures_variant in futures:
			if not (futures_variant is Dictionary):
				continue
			var futures_position := futures_variant as Dictionary
			var warehouse_district := int(futures_position.get("warehouse_district", -1))
			if warehouse_district < 0:
				continue
			_add_city_warehouse_stockpile_marker(
				warehouse_district,
				product_name,
				maxi(1, int(futures_position.get("units", 1))),
				float(futures_position.get("expires_at", _game_runtime_coordinator_node().world_session_state().game_time))
			)


func _city_warehouse_stockpile_pressure(city: Dictionary) -> int:
	if not _city_is_active(city):
		return 0
	var count := maxi(0, int(city.get("warehouse_stockpile_count", 0)))
	var units := maxi(0, int(city.get("warehouse_stockpile_units", 0)))
	var products: Array = city.get("warehouse_stockpile_products", [])
	if count <= 0 and units <= 0 and products.is_empty():
		return 0
	return count * WAREHOUSE_STOCKPILE_COUNT_PRESSURE + units * WAREHOUSE_STOCKPILE_UNIT_PRESSURE + products.size() * WAREHOUSE_STOCKPILE_PRODUCT_PRESSURE


func _city_warehouse_stockpile_status_text(city: Dictionary) -> String:
	if not _city_is_active(city):
		return ""
	var count := maxi(0, int(city.get("warehouse_stockpile_count", 0)))
	if count <= 0:
		return ""
	var units := maxi(0, int(city.get("warehouse_stockpile_units", 0)))
	var products: Array = city.get("warehouse_stockpile_products", [])
	var product_text := _limited_name_list(products, 3)
	var expires_at := float(city.get("warehouse_stockpile_expires_at", -1.0))
	var duration_text := _duration_short_text(maxf(1.0, expires_at - _game_runtime_coordinator_node().world_session_state().game_time)) if expires_at >= 0.0 else "未知"
	return "匿名仓储%d笔/%d单位/%s/%s" % [
		count,
		units,
		product_text if product_text != "" else "未知商品",
		duration_text,
	]


func _city_route_flow_status_text(city: Dictionary) -> String:
	var multiplier: float = float(city.get("route_flow_multiplier", 1.0))
	if multiplier <= 1.001:
		return "无"
	var source := String(city.get("route_flow_source", ""))
	var source_suffix := "｜%s" % source if source != "" else ""
	return "×%.2f（%s%s）" % [multiplier, _boon_duration_text(_remaining_effect_seconds(city, "route_flow_seconds", "route_flow_turns")), source_suffix]


func _city_contract_status_text(city: Dictionary) -> String:
	var contract_income := int(city.get("contract_income_bonus", 0))
	if contract_income <= 0:
		return "无"
	var source := String(city.get("contract_source", ""))
	var source_suffix := "｜%s" % source if source != "" else ""
	return "+%d/min（%s%s）" % [
		contract_income,
		_boon_duration_text(_remaining_effect_seconds(city, "contract_seconds", "contract_turns")),
		source_suffix,
	]




































func _economy_effect_callout_position() -> Vector2:
	if _game_runtime_coordinator_node().table_selection_state().selected_district >= 0 and _game_runtime_coordinator_node().table_selection_state().selected_district < _game_runtime_coordinator_node().world_session_state().districts.size():
		return _district_center(_game_runtime_coordinator_node().table_selection_state().selected_district)
	return Vector2(_game_runtime_coordinator_node().world_session_state().map_width_m * 0.5, _game_runtime_coordinator_node().world_session_state().map_height_m * 0.5)
















func _card_resolution_duration(_skill: Dictionary) -> float:
	if card_resolution_force_duration >= 0.0:
		return card_resolution_force_duration
	if DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return CARD_RESOLUTION_DISPLAY_SECONDS


func _card_simultaneous_window_duration(sequence: int = -1) -> float:
	if card_resolution_force_simultaneous_window >= 0.0:
		return card_resolution_force_simultaneous_window
	if DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return float(_card_group_cadence_snapshot(sequence).get("total_seconds", 0.0))


func _card_group_lock_duration() -> float:
	var lock_seconds := float(_card_group_cadence_snapshot().get("lock_seconds", 0.0))
	if card_resolution_force_simultaneous_window >= lock_seconds:
		return lock_seconds
	if card_resolution_force_simultaneous_window >= 0.0 or DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return lock_seconds


func _card_group_public_bid_duration() -> float:
	var public_bid_seconds := float(_card_group_cadence_snapshot().get("public_bid_seconds", 0.0))
	if card_resolution_force_simultaneous_window >= 0.0 or DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return public_bid_seconds


func _card_group_cadence_snapshot(sequence: int = -1) -> Dictionary:
	var controller := _card_resolution_controller_node()
	if controller != null and controller.has_method("cadence_snapshot"):
		var resolved_sequence := card_group_window_sequence if sequence < 0 else sequence
		var value: Variant = controller.call("cadence_snapshot", resolved_sequence)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	_mark_card_resolution_controller_missing("cadence snapshot", true)
	return {}


func _card_group_phase_remaining_seconds() -> float:
	var remaining := maxf(0.0, card_resolution_simultaneous_timer)
	var cadence := _card_group_cadence_snapshot()
	match _card_group_window_phase():
		"planning":
			return maxf(0.0, remaining - float(cadence.get("public_bid_seconds", 0.0)) - float(cadence.get("lock_seconds", 0.0)))
		"public_bid":
			return maxf(0.0, remaining - float(cadence.get("lock_seconds", 0.0)))
		"lock":
			return remaining
	return 0.0


func _card_group_phase_label(phase: String = "") -> String:
	var resolved_phase := _card_group_window_phase() if phase.is_empty() else phase
	match resolved_phase:
		"planning": return "规划"
		"public_bid": return "公开展示"
		"lock": return "锁牌"
		"resolving": return "结算"
	return "空闲"


func _card_group_window_cadence_text(sequence: int = -1) -> String:
	var cadence := _card_group_cadence_snapshot(sequence)
	return "%d秒共享窗：规划%d秒、公开展示%d秒、锁牌%d秒" % [
		int(cadence.get("total_seconds", 0)),
		int(cadence.get("planning_seconds", 0)),
		int(cadence.get("public_bid_seconds", 0)),
		int(cadence.get("lock_seconds", 0)),
	]


func _card_group_next_window_sequence() -> int:
	var service := _card_resolution_queue_service_node()
	var snapshot_variant: Variant = service.call("debug_snapshot") if service != null and service.has_method("debug_snapshot") else {}
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	return maxi(0, int(snapshot.get("last_group_window_sequence", -1)) + 1)


func _begin_card_group_window(reference_player: int, sequence: int) -> bool:
	var controller := _card_resolution_controller_node()
	if controller == null or not controller.has_method("begin_group_window"):
		_mark_card_resolution_controller_missing("begin group window", true)
		return false
	controller.call("begin_group_window", _card_simultaneous_window_duration(sequence), reference_player, sequence)
	return true


func _card_group_window_phase() -> String:
	var controller := _card_resolution_controller_node()
	if controller != null and controller.has_method("current_phase"):
		return str(controller.call("current_phase", _game_runtime_coordinator_node().card_resolution_frame_facts()))
	_mark_card_resolution_controller_missing("window phase", true)
	return "controller_missing"


func _card_group_submissions_open() -> bool:
	var controller := _card_resolution_controller_node()
	if controller != null and controller.has_method("submissions_open"):
		return bool(controller.call("submissions_open", _game_runtime_coordinator_node().card_resolution_frame_facts()))
	_mark_card_resolution_controller_missing("submission gate", true)
	return false


func _card_group_limit_for_player(_player_index: int) -> int:
	var rules := _card_group_runtime_rules()
	var standard_limit := int(rules.get("standard_group_card_limit", SharedCardGroupWindowScript.STANDARD_MAX_CARDS))
	return SharedCardGroupWindowScript.card_limit(standard_limit)


func _card_group_runtime_rules() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and coordinator.has_method("card_group_runtime_rules"):
		var value: Variant = coordinator.call("card_group_runtime_rules")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _card_group_count_for_player(player_index: int) -> int:
	return SharedCardGroupWindowScript.group_card_count(_card_resolution_current_queue(), player_index)


func _card_counter_response_duration() -> float:
	if DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return _ruleset_timing_seconds(&"counter_window_seconds")


func _card_can_open_counter_window(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if skill.is_empty():
		return false
	var target_status := _card_play_target_snapshot(skill)
	if bool(target_status.get("is_counter", false)):
		return false
	if not bool(target_status.get("counterable_player_interaction", false)):
		return false
	if bool(entry.get("countered", false)):
		return false
	return true


func _queued_skill_from_entry(entry: Dictionary) -> Dictionary:
	var player_index := int(entry.get("player_index", -1))
	var slot_index := int(entry.get("slot_index", -1))
	if player_index >= 0 and player_index < _game_runtime_coordinator_node().world_session_state().players.size():
		var slots: Array = (_game_runtime_coordinator_node().world_session_state().players[player_index] as Dictionary).get("slots", [])
		if slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary:
			return (slots[slot_index] as Dictionary).duplicate(true)
	var snapshot: Variant = entry.get("skill", {})
	return (snapshot as Dictionary).duplicate(true) if snapshot is Dictionary else {}


func _card_resolution_groups() -> Array:
	var service := _card_resolution_queue_service_node()
	var value: Variant = service.call("groups", card_resolution_batch_reference_player, _game_runtime_coordinator_node().world_session_state().players.size()) if service != null and service.has_method("groups") else []
	return (value as Array).duplicate(true) if value is Array else []


func _draw_extra_district_cards(player: Dictionary, amount: int, source: String) -> void:
	_game_runtime_coordinator_node().record_legacy_viewer_feedback("%s的额外拿牌暂不可用：必须等待统一牌架批量事务接线，不能复制当前挂牌。" % source)




func _active_city_district_indices() -> Array:
	var value: Variant = _route_network_runtime_call("active_region_legacy_indices")
	return (value as Array).duplicate(true) if value is Array else []


func _player_active_city_count(player_index: int) -> int:
	var count := 0
	for index in _active_city_district_indices():
		if int(_district_city(index).get("owner", -1)) == player_index:
			count += 1
	return count


func _city_competition_matches(_district_index: int) -> int:
	return 0


func _city_gdp_per_minute(district_index: int, competition_matches: int) -> int:
	return int(_city_gdp_per_minute_breakdown(district_index, competition_matches).get("net", 0))


func _city_cycle_income(district_index: int, competition_matches: int) -> int:
	# Save/test compatibility wrapper. This value is not a payout cycle; it is current GDP/min.
	return _city_gdp_per_minute(district_index, competition_matches)


func _city_gdp_per_minute_breakdown(district_index: int, competition_matches: int) -> Dictionary:
	if district_index < 0 or district_index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return {"net": 0, "receipt_count": 0, "product_lines": [], "route_lines": [], "transit_lines": []}
	var region_id := str((_game_runtime_coordinator_node().world_session_state().districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
	var snapshot_variant: Variant = _commodity_flow_runtime_call("region_gdp_snapshot", [region_id])
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var receipts_variant: Variant = _commodity_flow_runtime_call("recent_sale_receipts_snapshot", [-1])
	var product_lines: Array = []
	var route_lines: Array = []
	if receipts_variant is Array:
		for receipt_variant in receipts_variant:
			if not (receipt_variant is Dictionary) or str((receipt_variant as Dictionary).get("market_region_id", "")) != region_id:
				continue
			var receipt: Dictionary = receipt_variant
			product_lines.append("%s ×%d" % [str(receipt.get("commodity_id", "")), int(receipt.get("units", 0))])
			route_lines.append("距离%d｜单价%.2f" % [int(receipt.get("shortest_legal_distance", 0)), float(int(receipt.get("unit_price_cents", 0))) / 100.0])
	return {
		"net": int(snapshot.get("region_gdp_per_minute", 0)),
		"net_cents": int(snapshot.get("region_gdp_per_minute_cents", 0)),
		"receipt_count": (snapshot.get("receipt_ids", []) as Array).size() if snapshot.get("receipt_ids", []) is Array else 0,
		"observation_window_seconds": float(snapshot.get("observation_window_seconds", 0.0)),
		"competition_matches": competition_matches,
		"product_lines": product_lines,
		"route_lines": route_lines,
		"transit_lines": route_lines.duplicate(),
	}


func _city_cycle_income_breakdown(district_index: int, competition_matches: int) -> Dictionary:
	# Save/test compatibility wrapper. The authoritative economy breakdown is per-minute GDP.
	return _city_gdp_per_minute_breakdown(district_index, competition_matches)


func _city_income_breakdown_summary(breakdown: Dictionary) -> String:
	return "成交GDP %.2f/min｜最近%d秒 %d笔唯一回执" % [float(int(breakdown.get("net_cents", 0))) / 100.0, int(breakdown.get("observation_window_seconds", 0)), int(breakdown.get("receipt_count", 0))]


func _city_gdp_history_path_text(city: Dictionary, limit: int = 5) -> String:
	var history: Array = city.get("gdp_history", [])
	if history.is_empty():
		var fallback := int(city.get("last_gdp", city.get("last_income", 0)))
		return str(fallback) if fallback > 0 else "暂无"
	var start := maxi(0, history.size() - limit)
	var pieces := []
	for i in range(start, history.size()):
		pieces.append(str(int(history[i])))
	return "→".join(pieces)


func _city_gdp_trend_text(city: Dictionary) -> String:
	var history: Array = city.get("gdp_history", [])
	if history.is_empty():
		var fallback := int(city.get("last_gdp", city.get("last_income", 0)))
		if fallback > 0:
			return "GDP趋势：当前快照%d｜上次快照暂无｜路径%s。" % [fallback, _city_gdp_history_path_text(city)]
		return "GDP趋势：暂无历史（下次全局市场刷新开始记录）。"
	var current := int(history[history.size() - 1])
	var delta := int(city.get("last_gdp_delta", 0))
	var source := String(city.get("last_gdp_source", "全局刷新"))
	if source == "":
		source = "全局刷新"
	var reason := String(city.get("last_gdp_reason", ""))
	if reason == "":
		reason = "等待收入拆解"
	var change_text := "持平" if delta == 0 else _signed_int_text(delta)
	return "GDP趋势：%s当前快照%d（较上次%s）｜路径%s｜%s。" % [
		source,
		current,
		change_text,
		_city_gdp_history_path_text(city),
		reason,
	]


func _refresh_route_network() -> void:
	_route_network_runtime_call("refresh_routes")


func _route_network_routes_for_product(product_name: String) -> Array:
	var value: Variant = _route_network_runtime_call("routes_for_product", [product_name])
	return (value as Array).duplicate(true) if value is Array else []


func _append_unique_district_index(result: Array, index: int) -> void:
	if index < 0:
		return
	if not result.has(index):
		result.append(index)






func _district_center(index: int) -> Vector2:
	if index < 0 or index >= _game_runtime_coordinator_node().world_session_state().districts.size():
		return Vector2.ZERO
	return _game_runtime_coordinator_node().world_session_state().districts[index].get("center", Vector2.ZERO)


func _entity_world_position(entity: Dictionary) -> Vector2:
	return entity.get("world_position", _district_center(int(entity.get("position", 0))))


func _wrap_world_position(world_position: Vector2) -> Vector2:
	var width: float = max(1.0, _game_runtime_coordinator_node().world_session_state().map_width_m)
	var height: float = max(1.0, _game_runtime_coordinator_node().world_session_state().map_height_m)
	var x := world_position.x
	var y := world_position.y
	var guard := 0
	while (y < 0.0 or y > height) and guard < 12:
		if y < 0.0:
			y = -y
			x += width * 0.5
		elif y > height:
			y = height - (y - height)
			x += width * 0.5
		guard += 1
	return Vector2(fposmod(x, width), clamp(y, 0.0, height))


func _wrapped_delta(from_position: Vector2, to_position: Vector2) -> Vector2:
	var delta := _wrap_world_position(to_position) - _wrap_world_position(from_position)
	if abs(delta.x) > _game_runtime_coordinator_node().world_session_state().map_width_m * 0.5:
		delta.x -= sign(delta.x) * _game_runtime_coordinator_node().world_session_state().map_width_m
	return delta


func _wrapped_distance(from_position: Vector2, to_position: Vector2) -> float:
	return _spherical_distance(from_position, to_position)


func _world_to_lon_lat(world_position: Vector2) -> Vector2:
	var wrapped := _wrap_world_position(world_position)
	return Vector2(
		fposmod(wrapped.x / max(1.0, _game_runtime_coordinator_node().world_session_state().map_width_m) * TAU, TAU),
		PI * 0.5 - wrapped.y / max(1.0, _game_runtime_coordinator_node().world_session_state().map_height_m) * PI
	)


func _lon_lat_to_world(lon: float, lat: float) -> Vector2:
	return _wrap_world_position(Vector2(
		fposmod(lon, TAU) / TAU * max(1.0, _game_runtime_coordinator_node().world_session_state().map_width_m),
		(PI * 0.5 - clamp(lat, -PI * 0.5, PI * 0.5)) / PI * max(1.0, _game_runtime_coordinator_node().world_session_state().map_height_m)
	))


func _sphere_unit(world_position: Vector2) -> Vector3:
	var lon_lat := _world_to_lon_lat(world_position)
	var lon := lon_lat.x
	var lat := lon_lat.y
	return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)).normalized()


func _sphere_radius_m() -> float:
	return max(1.0, _game_runtime_coordinator_node().world_session_state().map_width_m / TAU)


func _spherical_distance(from_position: Vector2, to_position: Vector2) -> float:
	var a := _sphere_unit(from_position)
	var b := _sphere_unit(to_position)
	var dot_value: float = clamp(a.dot(b), -1.0, 1.0)
	return acos(dot_value) * _sphere_radius_m()


func _sphere_unit_to_world(unit: Vector3) -> Vector2:
	var normalized := unit.normalized()
	var lon := atan2(normalized.z, normalized.x)
	var lat := asin(clamp(normalized.y, -1.0, 1.0))
	return _lon_lat_to_world(lon, lat)


func _spherical_lerp_world(from_position: Vector2, to_position: Vector2, weight: float) -> Vector2:
	var a := _sphere_unit(from_position)
	var b := _sphere_unit(to_position)
	var t: float = clamp(weight, 0.0, 1.0)
	var dot_value: float = clamp(a.dot(b), -1.0, 1.0)
	var angle := acos(dot_value)
	if angle <= 0.0001:
		return _wrap_world_position(to_position)
	var sin_angle := sin(angle)
	if abs(sin_angle) <= 0.0001:
		return _wrap_world_position(from_position + _wrapped_delta(from_position, to_position) * t)
	var blend := (a * (sin((1.0 - t) * angle) / sin_angle)) + (b * (sin(t * angle) / sin_angle))
	return _sphere_unit_to_world(blend)


func _set_entity_world_position(entity: Dictionary, world_position: Vector2) -> void:
	var wrapped_position := _wrap_world_position(world_position)
	entity["world_position"] = wrapped_position
	entity["position"] = _district_at_point(wrapped_position)
	if int(entity["position"]) < 0:
		entity["position"] = _nearest_district_to(wrapped_position)


func _move_entity_toward(entity: Dictionary, target_position: Vector2, max_distance_m: float) -> float:
	var current := _entity_world_position(entity)
	var wrapped_target := _wrap_world_position(target_position)
	var distance := _wrapped_distance(current, wrapped_target)
	if distance <= 0.01:
		_set_entity_world_position(entity, wrapped_target)
		return 0.0
	var moved: float = min(distance, max(0.0, max_distance_m))
	var next_position := _spherical_lerp_world(current, wrapped_target, moved / distance)
	_set_entity_world_position(entity, next_position)
	return moved


func _entity_has_linear_motion(entity: Dictionary) -> bool:
	return entity.has("linear_move_target_position") and float(entity.get("linear_move_speed_mps", 0.0)) > 0.0


func _clear_entity_linear_motion(entity: Dictionary) -> void:
	for key in [
		"linear_move_target_position",
		"linear_move_target_district",
		"linear_move_speed_mps",
		"linear_move_source",
		"linear_move_mode",
		"linear_move_damaged_districts",
		"linear_move_started_at",
		"linear_move_arrival_action",
		"linear_move_unit_label",
		"linear_move_arrival_damage",
		"linear_move_arrival_damage_source",
	]:
		entity.erase(key)


func _start_entity_linear_motion(entity: Dictionary, target_position: Vector2, speed_mps: float, source: String, movement_mode: String = "", max_distance_m: float = -1.0, arrival_action: String = "") -> float:
	var current := _entity_world_position(entity)
	var wrapped_target := _wrap_world_position(target_position)
	var distance := _wrapped_distance(current, wrapped_target)
	if max_distance_m > 0.0 and distance > max_distance_m:
		wrapped_target = _spherical_lerp_world(current, wrapped_target, max_distance_m / distance)
		distance = max_distance_m
	if distance <= 0.5 or speed_mps <= 0.0:
		_clear_entity_linear_motion(entity)
		return 0.0
	entity["linear_move_target_position"] = wrapped_target
	entity["linear_move_target_district"] = _nearest_district_to(wrapped_target)
	entity["linear_move_speed_mps"] = maxf(1.0, speed_mps)
	entity["linear_move_source"] = source
	entity["linear_move_mode"] = movement_mode
	entity["linear_move_damaged_districts"] = []
	entity["linear_move_started_at"] = _game_runtime_coordinator_node().world_session_state().game_time
	entity["linear_move_arrival_action"] = arrival_action
	return distance


func _advance_entity_linear_motion(entity: Dictionary, delta_seconds: float) -> Dictionary:
	if not _entity_has_linear_motion(entity):
		return {"moved": 0.0, "arrived": false}
	var before := _entity_world_position(entity)
	var target: Vector2 = entity.get("linear_move_target_position", before)
	var target_district := int(entity.get("linear_move_target_district", _nearest_district_to(target)))
	var source := String(entity.get("linear_move_source", "线性移动"))
	var mode := String(entity.get("linear_move_mode", ""))
	var arrival_action := String(entity.get("linear_move_arrival_action", ""))
	var speed := maxf(0.0, float(entity.get("linear_move_speed_mps", 0.0)))
	var moved := _move_entity_toward(entity, target, speed * maxf(0.0, delta_seconds))
	var after := _entity_world_position(entity)
	var arrived := _wrapped_distance(after, target) <= 0.75
	if arrived:
		_set_entity_world_position(entity, target)
	return {
		"moved": moved,
		"arrived": arrived,
		"before": before,
		"after": after,
		"target": target,
		"target_district": target_district,
		"source": source,
		"mode": mode,
		"arrival_action": arrival_action,
	}


func _entity_distance_to_district(entity: Dictionary, district_index: int) -> float:
	return _wrapped_distance(_entity_world_position(entity), _district_center(district_index))


func _district_at_point(point: Vector2) -> int:
	point = _wrap_world_position(point)
	for i in range(_game_runtime_coordinator_node().world_session_state().districts.size()):
		if _point_in_polygon(point, _game_runtime_coordinator_node().world_session_state().districts[i].get("polygon", [])):
			return i
	return -1


func _point_in_polygon(point: Vector2, polygon: Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	var j := polygon.size() - 1
	for i in range(polygon.size()):
		var pi: Vector2 = polygon[i]
		var pj: Vector2 = polygon[j]
		var crosses := (pi.y > point.y) != (pj.y > point.y)
		if crosses:
			var x_at_y: float = (pj.x - pi.x) * (point.y - pi.y) / max(0.001, pj.y - pi.y) + pi.x
			if point.x < x_at_y:
				inside = not inside
		j = i
	return inside


func _districts_in_radius(center: Vector2, radius_m: float, include_destroyed := false) -> Array:
	var entries := []
	for i in range(_game_runtime_coordinator_node().world_session_state().districts.size()):
		if not include_destroyed and _game_runtime_coordinator_node().world_session_state().districts[i]["destroyed"]:
			continue
		var dist := _wrapped_distance(center, _district_center(i))
		if dist <= radius_m:
			entries.append({"index": i, "distance": dist})
	entries.sort_custom(Callable(self, "_sort_distance_entry"))
	var result := []
	for entry in entries:
		result.append(int(entry["index"]))
	return result


func _sort_distance_entry(a: Dictionary, b: Dictionary) -> bool:
	return float(a["distance"]) < float(b["distance"])


func _entity_distance_to_district_label(entity: Dictionary, district_index: int) -> String:
	return _meters_text(_entity_distance_to_district(entity, district_index))


func _meters_text(value: float) -> String:
	if value >= 1000.0:
		return "%.1fkm" % (value / 1000.0)
	return "%.0fm" % value


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var minutes := int(float(total) / 60.0)
	var rest := total % 60
	return "%02d:%02d" % [minutes, rest]


func _plain_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
