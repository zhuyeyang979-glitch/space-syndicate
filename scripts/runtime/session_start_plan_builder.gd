extends Node
class_name SessionStartPlanBuilder

const MonsterCatalog := preload("res://scripts/runtime/monster_catalog_v06.gd")
const WorldPlanBuilder := preload("res://scripts/runtime/session_start_world_plan_builder.gd")
const AlphaContentLoader := preload("res://scripts/runtime/alpha01_content_manifest_loader.gd")

const STARTING_CASH := 2000

@export var role_catalog_path: NodePath
@export var coordinator_path: NodePath
@export var ai_runtime_path: NodePath

var _build_count := 0
var _failure_count := 0


func build_plan(request: SessionStartRequest, rng_checkpoint: Dictionary) -> Dictionary:
	_build_count += 1
	if request == null or not request.is_valid() or int(rng_checkpoint.get("schema_version", 0)) != 1:
		_failure_count += 1
		return {"ok": false, "reason_code": "session_start_plan_request_invalid"}
	var catalog := _role_catalog()
	var coordinator := _coordinator()
	var ai_runtime := _ai_runtime()
	var content := AlphaContentLoader.load_active_selection()
	if not content.is_valid():
		_failure_count += 1
		return {"ok": false, "reason_code": "session_start_alpha_content_invalid", "errors": content.errors.duplicate()}
	if catalog == null or coordinator == null or ai_runtime == null or not bool(catalog.validate_catalog().get("valid", false)):
		_failure_count += 1
		return {"ok": false, "reason_code": "session_start_catalog_dependency_missing"}
	var draft := request.setup_draft.duplicate(true)
	var player_count := int(draft.get("player_count", 0))
	var ai_count := int(draft.get("ai_player_count", 0))
	if player_count < 3 or player_count > 8 or ai_count < 2 or ai_count >= player_count:
		_failure_count += 1
		return {"ok": false, "reason_code": "session_start_draft_bounds_invalid"}
	if int(draft.get("challenge_depth", 0)) != content.active_challenge_depth():
		_failure_count += 1
		return {"ok": false, "reason_code": "session_start_alpha_map_not_selected"}
	var market_result := ProductMarketRuntimeController.build_new_session_plan(rng_checkpoint, 30.0, 60.0)
	if not bool(market_result.get("ok", false)):
		_failure_count += 1
		return market_result
	var cursor: Dictionary = (market_result.get("cursor", {}) as Dictionary).duplicate(true)
	var roles_result := _resolve_roles(draft, cursor, content.role_source_indices())
	if not bool(roles_result.get("ok", false)):
		_failure_count += 1
		return roles_result
	cursor = (roles_result.get("cursor", {}) as Dictionary).duplicate(true)
	var resolved_roles: Array = roles_result.get("roles", [])
	var player_result := _build_players(draft, resolved_roles, catalog, coordinator, ai_runtime, content.monster_source_indices())
	if not bool(player_result.get("ok", false)):
		_failure_count += 1
		return player_result
	var world_result := WorldPlanBuilder.new().build_world(int(draft.get("challenge_depth", 1)), cursor)
	if not bool(world_result.get("ok", false)):
		_failure_count += 1
		return world_result
	cursor = (world_result.get("cursor", {}) as Dictionary).duplicate(true)
	var supply_draw := RunRngService.detached_randi_range(cursor, 1, 0x7fffffff)
	if not bool(supply_draw.get("ok", false)):
		_failure_count += 1
		return supply_draw
	cursor = _cursor_from_draw(supply_draw)
	var first_market_refresh := ProductMarketRuntimeController.build_new_session_refresh_plan(
		market_result.get("state", {}),
		world_result.get("districts", []),
		cursor
	)
	if not bool(first_market_refresh.get("ok", false)):
		_failure_count += 1
		return first_market_refresh
	cursor = (first_market_refresh.get("cursor", {}) as Dictionary).duplicate(true)
	var weather_result := WeatherRuntimeController.build_new_session_plan(cursor, world_result.get("districts", []), 0)
	if not bool(weather_result.get("ok", false)):
		_failure_count += 1
		return weather_result
	cursor = (weather_result.get("cursor", {}) as Dictionary).duplicate(true)
	var second_market_refresh := ProductMarketRuntimeController.build_new_session_refresh_plan(
		first_market_refresh.get("state", {}),
		world_result.get("districts", []),
		cursor
	)
	if not bool(second_market_refresh.get("ok", false)):
		_failure_count += 1
		return second_market_refresh
	cursor = (second_market_refresh.get("cursor", {}) as Dictionary).duplicate(true)
	var card_pool := _build_run_card_pool((world_result.get("districts", []) as Array), coordinator, content.region_supply_card_ids)
	if card_pool.size() != Alpha01RuntimeContentSelection.EXPECTED_REGION_CARD_COUNT:
		_failure_count += 1
		return {"ok": false, "reason_code": "session_start_card_pool_empty"}
	var plan := SessionStartPlan.new()
	plan.request_id = request.request_id
	plan.draft_revision = request.expected_draft_revision
	plan.player_count = player_count
	plan.ai_player_count = ai_count
	plan.challenge_depth = int(draft.get("challenge_depth", 1))
	plan.players = (player_result.get("players", []) as Array).duplicate(true)
	plan.districts = (world_result.get("districts", []) as Array).duplicate(true)
	plan.map_width_m = float(world_result.get("map_width_m", 0.0))
	plan.map_height_m = float(world_result.get("map_height_m", 0.0))
	plan.selected_district = int(world_result.get("selected_district", 0))
	plan.region_supply_seed = int(supply_draw.get("value", 1))
	plan.product_market_state = (second_market_refresh.get("state", {}) as Dictionary).duplicate(true)
	plan.weather_state = (weather_result.get("state", {}) as Dictionary).duplicate(true)
	plan.initial_market_refresh_draw_count = int(first_market_refresh.get("draw_count_delta", 0)) + int(second_market_refresh.get("draw_count_delta", 0))
	plan.initial_weather_draw_count = int(weather_result.get("draw_count_delta", 0))
	plan.card_pool = card_pool.duplicate(true)
	plan.rng_checkpoint = rng_checkpoint.duplicate(true)
	plan.rng_terminal_cursor = cursor.duplicate(true)
	plan.session_summary = {
		"session_id": "session:%s" % request.request_id,
		"scenario_id": "",
		"ruleset_id": "v0.4",
		"seed": int(cursor.get("rng_state", 1)),
		"player_count": player_count,
		"ai_player_count": ai_count,
		"difficulty": "深度%s" % _roman(plan.challenge_depth),
		"mission_title": "自由牌局",
	}
	var fingerprint_payload := plan.to_dictionary()
	fingerprint_payload.erase("plan_fingerprint")
	plan.plan_fingerprint = _sha256(JSON.stringify(fingerprint_payload))
	if not plan.is_valid():
		_failure_count += 1
		return {"ok": false, "reason_code": "session_start_plan_invalid"}
	return {"ok": true, "reason_code": "session_start_plan_ready", "plan": plan}


func debug_snapshot() -> Dictionary:
	return {"builder_id": "session_start_plan_builder_v1", "build_count": _build_count, "failure_count": _failure_count, "mutates_live_state": false, "consumes_live_rng": false, "references_main": false}


func _resolve_roles(draft: Dictionary, cursor: Dictionary, allowed_role_indices: Array[int]) -> Dictionary:
	var configured: Array = draft.get("role_indices", [])
	var resolved: Array = []
	var used := {}
	var random_slots: Array = []
	for index in range(int(draft.get("player_count", 0))):
		var value := int(configured[index]) if index < configured.size() else index
		if value == NewGameSetupDraftService.ROLE_RANDOM_INDEX:
			resolved.append(value)
			random_slots.append(index)
			continue
		if not allowed_role_indices.has(value) or used.has(value):
			return {"ok": false, "reason_code": "session_start_role_selection_invalid"}
		resolved.append(value)
		used[value] = true
	var available: Array = []
	for role_index in allowed_role_indices:
		if not used.has(role_index):
			available.append(role_index)
	var next_cursor := cursor.duplicate(true)
	for slot in random_slots:
		if available.is_empty():
			return {"ok": false, "reason_code": "session_start_role_catalog_exhausted"}
		var draw := RunRngService.detached_randi_range(next_cursor, 0, available.size() - 1)
		if not bool(draw.get("ok", false)):
			return draw
		next_cursor = _cursor_from_draw(draw)
		var role_index := int(available[int(draw.get("value", 0))])
		available.erase(role_index)
		resolved[int(slot)] = role_index
	return {"ok": true, "roles": resolved, "cursor": next_cursor}


func _build_players(draft: Dictionary, roles: Array, catalog: RoleCatalogRuntimeService, coordinator: GameRuntimeCoordinator, ai_runtime: AiRuntimeController, allowed_monster_indices: Array[int]) -> Dictionary:
	var players: Array = []
	var player_count := int(draft.get("player_count", 0))
	var human_count := maxi(1, player_count - int(draft.get("ai_player_count", 0)))
	var monster_indices: Array = draft.get("starter_monster_indices", [])
	for index in range(player_count):
		var role_index := int(roles[index])
		var role := catalog.definition_at(role_index)
		if role.is_empty():
			return {"ok": false, "reason_code": "session_start_role_definition_missing"}
		role["kind"] = "player_role"
		role["role_index"] = role_index
		role["text"] = "%s｜特征：%s｜被动：%s" % [str(role.get("species", "未知外星人")), str(role.get("trait", "暂无特征")), str(role.get("passive", "暂无被动"))]
		var monster_index := int(monster_indices[index]) if index < monster_indices.size() else index
		if not allowed_monster_indices.has(monster_index) or monster_index >= MonsterCatalog.catalog_size():
			return {"ok": false, "reason_code": "session_start_starter_monster_invalid"}
		var raw_card := coordinator.v06_starter_monster_card_by_name(str(MonsterCatalog.catalog_entry(monster_index).get("name", "")))
		var starter_card := _world_card(raw_card)
		if starter_card.is_empty():
			return {"ok": false, "reason_code": "session_start_starter_card_missing"}
		var identity := ai_runtime.new_session_identity_for_seat(index, human_count)
		var cash_delta := int(role.get("starting_cash_delta", role.get("starting_cash_bonus", 0)))
		var starting_cash := maxi(1, STARTING_CASH + cash_delta)
		players.append({
			"id": index, "actor_id": "player.%d" % index, "name": "玩家%d" % (index + 1),
			"seat_type": str(identity.get("seat_type", "human")), "is_ai": bool(identity.get("is_ai", false)),
			"ai_profile": (identity.get("ai_profile", {}) as Dictionary).duplicate(true), "ai_memory": (identity.get("ai_memory", {}) as Dictionary).duplicate(true),
			"role_index": role_index, "role_card": role.duplicate(true), "base_starting_cash": STARTING_CASH,
			"role_starting_cash_delta": cash_delta, "starting_cash_total": starting_cash,
			"cash": starting_cash, "cash_cents": starting_cash * 100, "cash_history": [starting_cash],
			"v06_transaction_ledger": [], "eliminated": false, "eliminated_at": -1.0, "elimination_reason": "",
			"economic_ledger": [], "city_guesses": {}, "city_guess_confidence": {}, "city_guess_reasons": {},
			"cities_built": 0, "total_card_spend": 0, "card_purchase_count": 0, "total_build_spend": 0,
			"total_card_income": 0, "total_role_income": 0, "total_business_spend": 0,
			"action_cooldown": 0.0, "queued_card_tip": 0, "slots": [starter_card],
		})
	return {"ok": true, "players": players}


func _build_run_card_pool(_districts: Array, coordinator: GameRuntimeCoordinator, selected_card_ids: Array[String]) -> Array:
	# The regional rack and the production inventory must share the same v0.6
	# canonical card identities. Region-specific playability remains a public
	# listing condition; it must not be encoded as a second legacy card pool.
	var available := coordinator.region_supply_catalog_card_ids()
	var result: Array = []
	for card_id in selected_card_ids:
		if available.has(card_id):
			result.append(card_id)
	return result


func _world_card(card: Dictionary) -> Dictionary:
	if card.is_empty():
		return {}
	var result := card.duplicate(true)
	var machine: Dictionary = result.get("machine", {})
	var player: Dictionary = result.get("player", {})
	machine["asset_cost"] = {}
	machine["starter_entitlement"] = true
	result["machine"] = machine
	result["card_id"] = str(machine.get("card_id", ""))
	result["name"] = str(machine.get("card_id", ""))
	result["display_name"] = str(player.get("name", result.get("name", "卡牌")))
	result["family_id"] = str(machine.get("family_id", ""))
	result["rank"] = int(machine.get("rank", 1))
	result["kind"] = "monster_card"
	result["counts_toward_hand_limit"] = bool(machine.get("counts_toward_hand_limit", true))
	result["persistent"] = false
	result["queued_for_resolution"] = false
	result["lock_left"] = 0.0
	result["starter_play_free"] = true
	result["summon_access"] = "any"
	result["text"] = "%s（起始怪兽牌：每席开局持有；召唤完全自愿。）" % str(player.get("effect", player.get("short_effect", "")))
	return result


func _cursor_from_draw(draw: Dictionary) -> Dictionary:
	return {"schema_version": 1, "rng_state": int(draw.get("rng_state", 1)), "draw_count": int(draw.get("draw_count", 0))}


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _roman(value: int) -> String:
	return ["I", "II", "III", "IV", "V", "VI"][clampi(value, 1, 6) - 1]


func _role_catalog() -> RoleCatalogRuntimeService:
	return get_node_or_null(role_catalog_path) as RoleCatalogRuntimeService


func _coordinator() -> GameRuntimeCoordinator:
	return get_node_or_null(coordinator_path) as GameRuntimeCoordinator


func _ai_runtime() -> AiRuntimeController:
	return get_node_or_null(ai_runtime_path) as AiRuntimeController
