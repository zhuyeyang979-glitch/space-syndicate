extends RefCounted
class_name SessionStartPlan

const SCHEMA_VERSION := 1

var request_id := ""
var plan_fingerprint := ""
var draft_revision := -1
var player_count := 0
var ai_player_count := 0
var challenge_depth := 1
var players: Array = []
var districts: Array = []
var map_width_m := 0.0
var map_height_m := 0.0
var selected_district := -1
var region_supply_seed := 0
var product_market_state: Dictionary = {}
var weather_state: Dictionary = {}
var initial_market_refresh_draw_count := 0
var initial_weather_draw_count := 0
var card_pool: Array = []
var rng_checkpoint: Dictionary = {}
var rng_terminal_cursor: Dictionary = {}
var session_summary: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"plan_schema_version": SCHEMA_VERSION,
		"request_id": request_id,
		"plan_fingerprint": plan_fingerprint,
		"draft_revision": draft_revision,
		"player_count": player_count,
		"ai_player_count": ai_player_count,
		"challenge_depth": challenge_depth,
		"players": players.duplicate(true),
		"districts": districts.duplicate(true),
		"map_width_m": map_width_m,
		"map_height_m": map_height_m,
		"selected_district": selected_district,
		"region_supply_seed": region_supply_seed,
		"product_market_state": product_market_state.duplicate(true),
		"weather_state": weather_state.duplicate(true),
		"initial_market_refresh_draw_count": initial_market_refresh_draw_count,
		"initial_weather_draw_count": initial_weather_draw_count,
		"card_pool": card_pool.duplicate(true),
		"rng_checkpoint": rng_checkpoint.duplicate(true),
		"rng_terminal_cursor": rng_terminal_cursor.duplicate(true),
		"session_summary": session_summary.duplicate(true),
	}


func is_valid() -> bool:
	if request_id.is_empty() or plan_fingerprint.is_empty() or player_count < 3 or player_count > 8:
		return false
	if players.size() != player_count or districts.is_empty() or map_width_m <= 0.0 or map_height_m <= 0.0 or product_market_state.is_empty() or weather_state.is_empty() or card_pool.is_empty():
		return false
	if initial_market_refresh_draw_count <= 0 or initial_weather_draw_count <= 0:
		return false
	var ids := {}
	var roles := {}
	var local_count := 0
	for player_variant in players:
		if not (player_variant is Dictionary):
			return false
		var player: Dictionary = player_variant
		var player_id := int(player.get("id", -1))
		var role_index := int(player.get("role_index", -1))
		if player_id < 0 or ids.has(player_id) or role_index < 0 or roles.has(role_index):
			return false
		ids[player_id] = true
		roles[role_index] = true
		if not bool(player.get("is_ai", false)):
			local_count += 1
	return local_count >= 1 and int(rng_checkpoint.get("rng_state", 0)) != 0 and int(rng_terminal_cursor.get("rng_state", 0)) != 0
