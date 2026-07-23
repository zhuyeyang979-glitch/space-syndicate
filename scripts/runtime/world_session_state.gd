@tool
extends Node
class_name WorldSessionState

const EnvelopeCodec := preload("res://scripts/runtime/world_session_envelope_codec.gd")

signal players_replaced(player_count: int)
signal districts_replaced(district_count: int)
signal game_time_changed(game_time: float)
signal world_geometry_changed(width_m: float, height_m: float, revision: int)
signal session_restored(summary: Dictionary)
signal city_inference_changed(viewer_index: int, region_id: String, owner_revision: String)

const DEFAULT_MAP_WIDTH_M := 1400.0
const DEFAULT_MAP_HEIGHT_M := 950.0
const CASH_CENTS_PER_UNIT := 100
const CITY_GUESS_CONFIDENCE_LOW := 1
const CITY_GUESS_CONFIDENCE_MEDIUM := 2
const CITY_GUESS_CONFIDENCE_HIGH := 3
const CITY_GUESS_AUTHORIZED_REVEAL := 100
const CITY_GUESS_REASON_IDS := ["product", "route", "card", "monster", "role", "intuition"]
const PUBLIC_REGION_CLUE_HISTORY_LIMIT := 6
const COMMODITY_POSTCOMMIT_CITY_HISTORY_LIMIT := 8
const COMMODITY_POSTCOMMIT_CASH_HISTORY_LIMIT := 24
const COMMODITY_POSTCOMMIT_CITY_BREAKDOWN_KEYS := [
	"net",
	"net_cents",
	"receipt_count",
	"observation_window_seconds",
	"competition_matches",
	"product_lines",
	"route_lines",
	"transit_lines",
]

@export var role_catalog_path: NodePath

var _players: Array = []
var _districts: Array = []
var _game_time := 0.0
var _map_width_m := DEFAULT_MAP_WIDTH_M
var _map_height_m := DEFAULT_MAP_HEIGHT_M
var _world_geometry_revision := 0
var _city_inference_mutation_count := 0
var _commodity_postcommit_city_lineage_by_district: Dictionary = {}
var _commodity_postcommit_cash_lineage_by_player: Dictionary = {}
var _commodity_postcommit_city_mutation_count := 0
var _commodity_postcommit_cash_snapshot_count := 0

var players: Array:
	get:
		return _players
	set(value):
		replace_players(value)

var districts: Array:
	get:
		return _districts
	set(value):
		replace_districts(value)

var game_time: float:
	get:
		return _game_time
	set(value):
		set_game_time(value)

var map_width_m: float:
	get:
		return _map_width_m

var map_height_m: float:
	get:
		return _map_height_m


func reset() -> Dictionary:
	_players = []
	_districts = []
	_game_time = 0.0
	_map_width_m = DEFAULT_MAP_WIDTH_M
	_map_height_m = DEFAULT_MAP_HEIGHT_M
	_world_geometry_revision += 1
	_city_inference_mutation_count = 0
	_commodity_postcommit_city_lineage_by_district.clear()
	_commodity_postcommit_cash_lineage_by_player.clear()
	_commodity_postcommit_city_mutation_count = 0
	_commodity_postcommit_cash_snapshot_count = 0
	var summary := debug_snapshot()
	players_replaced.emit(0)
	districts_replaced.emit(0)
	game_time_changed.emit(0.0)
	world_geometry_changed.emit(_map_width_m, _map_height_m, _world_geometry_revision)
	session_restored.emit(summary)
	return summary


func replace_players(value: Array, duplicate := false) -> Array:
	_players = value.duplicate(true) if duplicate else value
	players_replaced.emit(_players.size())
	return _players


func replace_districts(value: Array, duplicate := false) -> Array:
	_districts = value.duplicate(true) if duplicate else value
	districts_replaced.emit(_districts.size())
	return _districts


func set_game_time(value: float) -> float:
	var normalized := maxf(0.0, value)
	if not is_equal_approx(normalized, _game_time):
		_game_time = normalized
		game_time_changed.emit(_game_time)
	else:
		_game_time = normalized
	return _game_time


func advance_game_time(delta: float) -> float:
	if delta <= 0.0:
		return _game_time
	return set_game_time(_game_time + delta)


func apply_commodity_postcommit_city_gdp_snapshot(
	batch_sequence: int,
	batch_id: String,
	batch_fingerprint: String,
	city_breakdown_fingerprint: String,
	district_index: int,
	breakdown: Dictionary
) -> Dictionary:
	## Narrow authoritative mutation used only after a committed CommodityFlow
	## batch. The private sequence ledger makes a target retry idempotent without
	## placing internal batch IDs inside player-facing city dictionaries.
	var binding := _commodity_postcommit_binding(batch_sequence, batch_id, batch_fingerprint)
	if binding.is_empty() \
			or not _valid_commodity_postcommit_sha256(city_breakdown_fingerprint) \
			or not _commodity_postcommit_city_breakdown_valid(breakdown):
		return {"applied": false, "reason_code": "commodity_postcommit_city_snapshot_invalid"}
	binding["city_breakdown_fingerprint"] = city_breakdown_fingerprint
	if binding.is_empty() or district_index < 0 or district_index >= _districts.size() \
			or not (_districts[district_index] is Dictionary):
		return {"applied": false, "reason_code": "commodity_postcommit_city_snapshot_invalid"}
	var sequence_key := str(district_index)
	var previous_binding: Dictionary = _commodity_postcommit_city_lineage_by_district.get(sequence_key, {}) \
		if _commodity_postcommit_city_lineage_by_district.get(sequence_key, {}) is Dictionary else {}
	var last_sequence := maxi(0, int(previous_binding.get("batch_sequence", 0)))
	if last_sequence > batch_sequence:
		return {
			"applied": false,
			"reason_code": "commodity_postcommit_city_lineage_ahead",
			"district_index": district_index,
			"batch_sequence": batch_sequence,
			"last_sequence": last_sequence,
		}
	if last_sequence == batch_sequence:
		if not _same_commodity_postcommit_binding(previous_binding, binding):
			return {
				"applied": false,
				"idempotent": false,
				"reason_code": "commodity_postcommit_city_lineage_collision",
				"district_index": district_index,
				"batch_sequence": batch_sequence,
			}
		return {
			"applied": true,
			"idempotent": true,
			"reason_code": "commodity_postcommit_city_snapshot_already_applied",
			"district_index": district_index,
			"batch_sequence": batch_sequence,
		}
	var district := (_districts[district_index] as Dictionary).duplicate(true)
	var city: Dictionary = (district.get("city", {}) as Dictionary).duplicate(true) if district.get("city", {}) is Dictionary else {}
	var income := int(breakdown.get("net", 0))
	var history: Array = (city.get("gdp_history", []) as Array).duplicate() if city.get("gdp_history", []) is Array else []
	var previous := income
	if not history.is_empty():
		previous = int(history.back())
	elif int(city.get("last_gdp", 0)) > 0:
		previous = int(city.get("last_gdp", income))
	history.append(income)
	while history.size() > COMMODITY_POSTCOMMIT_CITY_HISTORY_LIMIT:
		history.pop_front()
	city["last_income"] = income
	city["last_gdp"] = income
	city["last_gdp_delta"] = income - previous
	city["last_gdp_source"] = "商品成交回执"
	city["last_gdp_reason"] = "只统计观察窗口内已成交商品；生产、需求、入库与浪费本身不直接产生GDP。" \
		if int(breakdown.get("receipt_count", 0)) > 0 else "尚无完成销售的商品回执。"
	city["last_gdp_breakdown"] = breakdown.duplicate(true)
	city["gdp_history"] = history
	district["city"] = city
	_districts[district_index] = district
	_commodity_postcommit_city_lineage_by_district[sequence_key] = binding
	_commodity_postcommit_city_mutation_count += 1
	return {
		"applied": true,
		"idempotent": false,
		"reason_code": "commodity_postcommit_city_snapshot_applied",
		"district_index": district_index,
		"batch_sequence": batch_sequence,
		"gdp": income,
	}


func commodity_postcommit_city_gdp(district_index: int) -> int:
	if district_index < 0 or district_index >= _districts.size() or not (_districts[district_index] is Dictionary):
		return 0
	var district := _districts[district_index] as Dictionary
	var city: Dictionary = district.get("city", {}) as Dictionary if district.get("city", {}) is Dictionary else {}
	return int(city.get("last_gdp", city.get("last_income", 0)))


func commodity_postcommit_city_sequence(district_index: int) -> int:
	if district_index < 0 or district_index >= _districts.size():
		return -1
	return int(commodity_postcommit_city_binding(district_index).get("batch_sequence", 0))


func commodity_postcommit_city_binding(district_index: int) -> Dictionary:
	if district_index < 0 or district_index >= _districts.size():
		return {}
	var binding_variant: Variant = _commodity_postcommit_city_lineage_by_district.get(str(district_index), {})
	return (binding_variant as Dictionary).duplicate(true) if binding_variant is Dictionary else {}


func commodity_postcommit_player_observation_sequence(player_index: int) -> int:
	if player_index < 0 or player_index >= _players.size():
		return -1
	return int(commodity_postcommit_player_observation_binding(player_index).get("batch_sequence", 0))


func commodity_postcommit_player_observation_binding(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= _players.size():
		return {}
	var binding_variant: Variant = _commodity_postcommit_cash_lineage_by_player.get(str(player_index), {})
	return (binding_variant as Dictionary).duplicate(true) if binding_variant is Dictionary else {}


func record_commodity_postcommit_cash_snapshot(
	batch_sequence: int,
	batch_id: String,
	batch_fingerprint: String,
	player_index: int
) -> Dictionary:
	var binding := _commodity_postcommit_binding(batch_sequence, batch_id, batch_fingerprint)
	if binding.is_empty() or player_index < 0 or player_index >= _players.size() \
			or not (_players[player_index] is Dictionary):
		return {"applied": false, "reason_code": "commodity_postcommit_cash_snapshot_invalid"}
	var sequence_key := str(player_index)
	var previous_binding: Dictionary = _commodity_postcommit_cash_lineage_by_player.get(sequence_key, {}) \
		if _commodity_postcommit_cash_lineage_by_player.get(sequence_key, {}) is Dictionary else {}
	var last_sequence := maxi(0, int(previous_binding.get("batch_sequence", 0)))
	if last_sequence > batch_sequence:
		return {
			"applied": false,
			"reason_code": "commodity_postcommit_cash_lineage_ahead",
			"player_index": player_index,
			"batch_sequence": batch_sequence,
			"last_sequence": last_sequence,
		}
	if last_sequence == batch_sequence:
		if not _same_commodity_postcommit_binding(previous_binding, binding):
			return {
				"applied": false,
				"idempotent": false,
				"reason_code": "commodity_postcommit_cash_lineage_collision",
				"player_index": player_index,
				"batch_sequence": batch_sequence,
			}
		return {
			"applied": true,
			"idempotent": true,
			"reason_code": "commodity_postcommit_cash_snapshot_already_applied",
			"player_index": player_index,
			"batch_sequence": batch_sequence,
		}
	var player := (_players[player_index] as Dictionary).duplicate(true)
	if not player.has("economic_ledger"):
		player["economic_ledger"] = []
	var history: Array = (player.get("cash_history", []) as Array).duplicate() if player.get("cash_history", []) is Array else []
	var current_cash := int(player.get("cash", 0))
	var changed := history.is_empty() or int(history.back()) != current_cash
	if changed:
		history.append(current_cash)
	while history.size() > COMMODITY_POSTCOMMIT_CASH_HISTORY_LIMIT:
		history.pop_front()
	player["cash_history"] = history
	_players[player_index] = player
	_commodity_postcommit_cash_lineage_by_player[sequence_key] = binding
	_commodity_postcommit_cash_snapshot_count += 1
	return {
		"applied": true,
		"idempotent": false,
		"changed": changed,
		"reason_code": "commodity_postcommit_cash_snapshot_applied",
		"player_index": player_index,
		"batch_sequence": batch_sequence,
	}


func _commodity_postcommit_binding(
	batch_sequence: int,
	batch_id: String,
	batch_fingerprint: String
) -> Dictionary:
	if batch_sequence <= 0 \
			or batch_id != "commodity-flow-batch-%010d" % batch_sequence \
			or batch_fingerprint.length() != 64:
		return {}
	for character_index in range(batch_fingerprint.length()):
		if not "0123456789abcdef".contains(batch_fingerprint.substr(character_index, 1)):
			return {}
	return {
		"batch_sequence": batch_sequence,
		"batch_id": batch_id,
		"batch_fingerprint": batch_fingerprint,
	}


func _same_commodity_postcommit_binding(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("batch_sequence", -1)) == int(right.get("batch_sequence", -2)) \
		and str(left.get("batch_id", "")) == str(right.get("batch_id", "")) \
		and str(left.get("batch_fingerprint", "")) == str(right.get("batch_fingerprint", "")) \
		and str(left.get("city_breakdown_fingerprint", "")) \
			== str(right.get("city_breakdown_fingerprint", ""))


func _valid_commodity_postcommit_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character_index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(character_index, 1)):
			return false
	return true


func _commodity_postcommit_city_breakdown_valid(breakdown: Dictionary) -> bool:
	if not TablePresentationPureDataPolicy.is_pure_data(breakdown) \
			or breakdown.size() != COMMODITY_POSTCOMMIT_CITY_BREAKDOWN_KEYS.size():
		return false
	for key in COMMODITY_POSTCOMMIT_CITY_BREAKDOWN_KEYS:
		if not breakdown.has(key):
			return false
	if not (breakdown.get("net") is int) or int(breakdown.get("net", -1)) < 0 \
			or not (breakdown.get("net_cents") is int) or int(breakdown.get("net_cents", -1)) < 0 \
			or not (breakdown.get("receipt_count") is int) or int(breakdown.get("receipt_count", -1)) < 0 \
			or not (breakdown.get("observation_window_seconds") is float) \
			or not is_finite(float(breakdown.get("observation_window_seconds", -1.0))) \
			or float(breakdown.get("observation_window_seconds", -1.0)) < 0.0 \
			or not (breakdown.get("competition_matches") is int) \
			or int(breakdown.get("competition_matches", -1)) < 0:
		return false
	for key in ["product_lines", "route_lines", "transit_lines"]:
		if not (breakdown.get(key) is Array):
			return false
		for line_variant in breakdown.get(key) as Array:
			if not (line_variant is String or line_variant is StringName):
				return false
	return true


func can_append_ai_business_market_pressure_public_clue(
	public_event_id: String,
	region_id: String,
	product_id: String,
	pressure_units: int,
	market_revision: int
) -> Dictionary:
	var normalized_event_id := public_event_id.strip_edges()
	var normalized_region_id := region_id.strip_edges()
	var normalized_product_id := product_id.strip_edges()
	if not normalized_event_id.begins_with("ai-business-market:") \
			or normalized_event_id.length() > 96 or normalized_region_id.is_empty() \
			or normalized_product_id.is_empty() or pressure_units <= 0 or market_revision < 0:
		return {"ready": false, "reason_code": "ai_business_public_clue_terms_invalid"}
	var district_index := district_index_for_region_id(normalized_region_id)
	if district_index < 0 or not (_districts[district_index] is Dictionary):
		return {"ready": false, "reason_code": "ai_business_public_clue_region_missing"}
	var district := _districts[district_index] as Dictionary
	var city: Dictionary = district.get("city", {}) as Dictionary if district.get("city", {}) is Dictionary else {}
	if city.is_empty() or not bool(city.get("active", true)):
		return {"ready": false, "reason_code": "ai_business_public_clue_city_inactive"}
	return {
		"ready": true,
		"reason_code": "ai_business_public_clue_ready",
		"district_index": district_index,
	}


func append_ai_business_market_pressure_public_clue(
	public_event_id: String,
	region_id: String,
	product_id: String,
	pressure_units: int,
	price_before: int,
	price_after: int,
	market_revision: int,
	world_time: float
) -> Dictionary:
	## Purpose-built public mutation. Callers provide only typed public facts;
	## WorldSessionState owns formatting and idempotence, so free-form text cannot
	## smuggle cash, owner identity, hands, or AI plans into the table snapshot.
	var preflight := can_append_ai_business_market_pressure_public_clue(
		public_event_id,
		region_id,
		product_id,
		pressure_units,
		market_revision
	)
	if not bool(preflight.get("ready", false)) or price_before < 0 or price_after < 0 or not is_finite(world_time):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "ai_business_public_clue_terms_invalid"))}
	var normalized_event_id := public_event_id.strip_edges()
	var normalized_region_id := region_id.strip_edges()
	var normalized_product_id := product_id.strip_edges()
	var district_index := int(preflight.get("district_index", -1))
	var district := (_districts[district_index] as Dictionary).duplicate(true)
	var city: Dictionary = (district.get("city", {}) as Dictionary).duplicate(true)
	var clues: Array = city.get("public_clues", []) as Array if city.get("public_clues", []) is Array else []
	clues = clues.duplicate(true)
	for clue_variant in clues:
		if clue_variant is Dictionary and str((clue_variant as Dictionary).get("public_event_id", "")) == normalized_event_id:
			return {
				"applied": true,
				"idempotent": true,
				"reason_code": "ai_business_public_clue_already_applied",
				"region_id": normalized_region_id,
				"district_index": district_index,
				"clue_count": clues.size(),
			}
	var text := "刷新%d：匿名财团制造%s需求压力%d，市场按供需重算¥%d→¥%d；疑似有生产该商品的城市受益。" % [
		market_revision,
		normalized_product_id,
		pressure_units,
		price_before,
		price_after,
	]
	var clean := {
		"public_event_id": normalized_event_id,
		"time": maxf(0.0, world_time),
		"cycle": market_revision,
		"kind": "市场",
		"products": [normalized_product_id],
		"text": text,
	}
	city["last_public_clue"] = text
	clues.append(clean)
	while clues.size() > PUBLIC_REGION_CLUE_HISTORY_LIMIT:
		clues.pop_front()
	city["public_clues"] = clues
	district["city"] = city
	_districts[district_index] = district
	return {
		"applied": true,
		"idempotent": false,
		"reason_code": "ai_business_public_clue_appended",
		"region_id": normalized_region_id,
		"district_index": district_index,
		"clue_count": clues.size(),
	}


func private_player_cash_snapshot(player_index: int) -> Dictionary:
	## Actor-scoped runtime query. Never expose this result through a public
	## presentation source: ordinary-play cash and wager availability are private.
	if player_index < 0 or player_index >= _players.size() or not (_players[player_index] is Dictionary):
		return {
			"valid": false,
			"reason_code": "player_cash_unavailable",
			"player_index": player_index,
			"cash_cents": 0,
			"currency_fields_consistent": false,
		}
	var normalized := canonical_private_cash_record(_players[player_index] as Dictionary)
	normalized["valid"] = true
	normalized["reason_code"] = "player_cash_ready"
	normalized["player_index"] = player_index
	return normalized


func private_player_city_economy_snapshot(player_index: int) -> Dictionary:
	## Narrow internal projection for an actor-scoped economy QueryPort. It
	## exposes only cities whose authoritative owner is the requested player.
	if player_index < 0 or player_index >= _players.size() or not (_players[player_index] is Dictionary):
		return {
			"valid": false,
			"reason_code": "player_city_economy_unavailable",
			"player_index": player_index,
			"cities": [],
			"summary": {},
			"state_revision": "",
		}
	var cities: Array = []
	var total_income := 0
	var warehouse_count := 0
	var warehouse_units := 0
	var warehouse_products: Array[String] = []
	for district_index in range(_districts.size()):
		if not (_districts[district_index] is Dictionary):
			continue
		var district := _districts[district_index] as Dictionary
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		if city.is_empty() or not bool(city.get("active", true)) or int(city.get("owner", -1)) != player_index:
			continue
		var city_products := _private_city_product_names(city.get("products", []))
		var city_demands := _canonical_string_array(city.get("demands", []))
		var stockpile_products := _canonical_string_array(city.get("warehouse_stockpile_products", []))
		var city_income := int(city.get("last_income", city.get("last_cycle_income", 0)))
		var city_warehouse_count := maxi(0, int(city.get("warehouse_stockpile_count", 0)))
		var city_warehouse_units := maxi(0, int(city.get("warehouse_stockpile_units", 0)))
		total_income += city_income
		warehouse_count += city_warehouse_count
		warehouse_units += city_warehouse_units
		for product_id in stockpile_products:
			if not warehouse_products.has(product_id):
				warehouse_products.append(product_id)
		cities.append({
			"district_index": district_index,
			"region_id": _region_id_for_district(district_index),
			"public_name": str(district.get("name", "区域%d" % (district_index + 1))),
			"terrain": str(district.get("terrain", "land")),
			"active": true,
			"level": maxi(0, int(city.get("level", 0))),
			"product_names": city_products,
			"demand_names": city_demands,
			"last_income": city_income,
			"competition_matches": maxi(0, int(city.get("competition_matches", 0))),
			"trade_disrupted_routes": maxi(0, int(city.get("trade_disrupted_routes", 0))),
			"trade_route_damage": maxi(0, int(city.get("trade_route_damage", 0))),
			"warehouse_stockpile_count": city_warehouse_count,
			"warehouse_stockpile_units": city_warehouse_units,
			"warehouse_stockpile_products": stockpile_products,
		})
	warehouse_products.sort()
	var summary := {
		"active_city_count": cities.size(),
		"last_income_total": total_income,
		"warehouse_stockpile_count": warehouse_count,
		"warehouse_stockpile_units": warehouse_units,
		"warehouse_stockpile_products": warehouse_products,
	}
	return {
		"valid": true,
		"reason_code": "player_city_economy_ready",
		"player_index": player_index,
		"cities": cities.duplicate(true),
		"summary": summary.duplicate(true),
		"state_revision": _stable_hash(["player_city_economy_v1", player_index, cities]),
	}


func reconcile_private_player_cash_after_unit_mutation(
	player_index: int,
	before_snapshot: Dictionary
) -> Dictionary:
	## Temporary typed migration hook for already-existing whole-unit cash writers.
	## It keeps the v0.6 cents ledger and the legacy mirror coherent without moving
	## cash ownership into a bridge or into the wager query port.
	if player_index < 0 or player_index >= _players.size() or not (_players[player_index] is Dictionary):
		return {"reconciled": false, "reason_code": "player_cash_unavailable"}
	var player := (_players[player_index] as Dictionary).duplicate(true)
	var current_units := int(player.get("cash", 0))
	var canonical_cents := 0
	if bool(before_snapshot.get("valid", false)) and int(before_snapshot.get("player_index", -1)) == player_index:
		var before_units := int(before_snapshot.get("cash_units", 0))
		var before_cents := int(before_snapshot.get("cash_cents", before_units * CASH_CENTS_PER_UNIT))
		var delta_units := current_units - before_units
		if delta_units > 92233720368547758 or delta_units < -92233720368547758:
			return {"reconciled": false, "reason_code": "player_cash_overflow"}
		var delta_cents := delta_units * CASH_CENTS_PER_UNIT
		if (delta_cents > 0 and before_cents > 9223372036854775807 - delta_cents) \
				or (delta_cents < 0 and before_cents < -9223372036854775808 - delta_cents):
			return {"reconciled": false, "reason_code": "player_cash_overflow"}
		canonical_cents = before_cents + delta_cents
	else:
		canonical_cents = int(canonical_private_cash_record(player).get("cash_cents", 0))
	player["cash_cents"] = canonical_cents
	player["cash"] = floori(float(canonical_cents) / float(CASH_CENTS_PER_UNIT))
	_players[player_index] = player
	return {
		"reconciled": true,
		"reason_code": "player_cash_reconciled",
		"player_index": player_index,
		"cash_units": int(player.get("cash", 0)),
		"cash_cents": canonical_cents,
	}


static func canonical_private_cash_record(player: Dictionary) -> Dictionary:
	## v0.6 cents are exact when the legacy whole-unit mirror agrees with them.
	## A few not-yet-retired unit-based owners still update only `cash`; when the
	## mirrors drift by at least one whole unit, trusting stale `cash_cents` could
	## resurrect already-spent money during wager settlement.  In that explicit
	## migration state, the changed whole-unit value is the fail-safe truth and
	## fractional cents are discarded until the next canonical mutation rewrites
	## both fields.
	var has_units := player.has("cash")
	var has_cents := player.has("cash_cents")
	var unit_cash := int(player.get("cash", 0))
	var unit_cash_cents := unit_cash * CASH_CENTS_PER_UNIT
	var stored_cents := int(player.get("cash_cents", unit_cash_cents))
	var fields_consistent := has_units and has_cents and floori(float(stored_cents) / float(CASH_CENTS_PER_UNIT)) == unit_cash
	var canonical_cents := stored_cents if (has_cents and (not has_units or fields_consistent)) else unit_cash_cents
	return {
		"cash_cents": canonical_cents,
		"cash_units": floori(float(canonical_cents) / float(CASH_CENTS_PER_UNIT)),
		"currency_fields_consistent": fields_consistent or not (has_units and has_cents),
		"used_legacy_unit_reconciliation": has_units and has_cents and not fields_consistent,
	}


func configure_world_geometry(width_m: float, height_m: float) -> Dictionary:
	var normalized_width := maxf(1.0, width_m)
	var normalized_height := maxf(1.0, height_m)
	if not is_equal_approx(normalized_width, _map_width_m) or not is_equal_approx(normalized_height, _map_height_m):
		_map_width_m = normalized_width
		_map_height_m = normalized_height
		_world_geometry_revision += 1
		world_geometry_changed.emit(_map_width_m, _map_height_m, _world_geometry_revision)
	else:
		_map_width_m = normalized_width
		_map_height_m = normalized_height
	return public_world_geometry_snapshot()


func public_world_geometry_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"revision": _world_geometry_revision,
		"width_m": _map_width_m,
		"height_m": _map_height_m,
		"world_rect": Rect2(Vector2.ZERO, Vector2(_map_width_m, _map_height_m)),
		"visibility_scope": "public",
	}


func public_lifecycle_snapshot() -> Dictionary:
	return {
		"available": not _players.is_empty(),
		"session_revision": _world_geometry_revision,
		"world_time": _game_time,
		"session_state": "empty" if _players.is_empty() else "active",
		"session_finished": false,
		"visibility_scope": "public",
	}


func public_intel_projection() -> Dictionary:
	var public_players: Array = []
	for player_index in range(_players.size()):
		var player: Dictionary = _players[player_index] if _players[player_index] is Dictionary else {}
		var role: Dictionary = player.get("role_card", {}) if player.get("role_card", {}) is Dictionary else {}
		public_players.append({
			"player_index": player_index,
			"public_player_name": str(player.get("name", "玩家%d" % (player_index + 1))),
			"role_index": int(player.get("role_index", role.get("role_index", -1))),
			"role_name": str(role.get("name", "")),
			"eliminated": bool(player.get("eliminated", false)),
			"visibility_scope": "public",
		})
	var public_regions: Array = []
	for district_index in range(_districts.size()):
		if not (_districts[district_index] is Dictionary):
			continue
		var district := _districts[district_index] as Dictionary
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		public_regions.append({
			"district_index": district_index,
			"region_id": _region_id_for_district(district_index),
			"name": str(district.get("name", "区域%d" % (district_index + 1))),
			"destroyed": bool(district.get("destroyed", false)),
			"terrain": str(district.get("terrain", "land")),
			"products": _canonical_string_array(district.get("products", [])),
			"demands": _canonical_string_array(district.get("demands", [])),
			"damage": maxi(0, int(district.get("damage", 0))),
			"city_present": not city.is_empty(),
			"city_active": not city.is_empty() and bool(city.get("active", true)),
			"city_level": maxi(0, int(city.get("level", 0))),
			"city_products": _canonical_string_array(city.get("products", [])),
			"city_demands": _canonical_string_array(city.get("demands", [])),
			"city_last_income": int(city.get("last_income", 0)),
			"city_competition_matches": maxi(0, int(city.get("competition_matches", 0))),
			"visibility_scope": "public",
		})
	return {
		"schema_version": 1,
		"visibility_scope": "public",
		"players": public_players,
		"regions": public_regions,
		"world_time": _game_time,
	}


func city_inference_projection(viewer_index: int) -> Dictionary:
	if viewer_index < 0 or viewer_index >= _players.size():
		return {}
	var player: Dictionary = _players[viewer_index] if _players[viewer_index] is Dictionary else {}
	return {
		"schema_version": 1,
		"visibility_scope": "viewer_private",
		"viewer_index": viewer_index,
		"viewer_name": str(player.get("name", "玩家%d" % (viewer_index + 1))),
		"owner_revision": city_inference_owner_revision(viewer_index),
		"records": _city_inference_records(viewer_index),
		"foreign_active_region_ids": _foreign_active_region_ids(viewer_index),
	}


func city_inference_owner_revision(viewer_index: int) -> String:
	if viewer_index < 0 or viewer_index >= _players.size():
		return ""
	var region_state: Array = []
	for district_index in range(_districts.size()):
		if not (_districts[district_index] is Dictionary):
			continue
		var district := _districts[district_index] as Dictionary
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		region_state.append([
			_region_id_for_district(district_index),
			bool(district.get("destroyed", false)),
			not city.is_empty() and bool(city.get("active", true)),
		])
	return _stable_hash({
		"viewer_index": viewer_index,
		"player_count": _players.size(),
		"regions": region_state,
		"records": _city_inference_records(viewer_index),
	})


func region_id_for_district(district_index: int) -> String:
	return _region_id_for_district(district_index)


func district_index_for_region_id(region_id: String) -> int:
	var normalized := region_id.strip_edges()
	if normalized.is_empty() or normalized != region_id:
		return -1
	for district_index in range(_districts.size()):
		if _region_id_for_district(district_index) == normalized:
			return district_index
	return -1


func public_region_selection_catalog_source() -> Dictionary:
	if _players.is_empty() or _districts.is_empty():
		return _public_region_catalog_unavailable("pre_session")
	var entries: Array = []
	var seen_ids: Dictionary = {}
	for public_index in range(_districts.size()):
		if not (_districts[public_index] is Dictionary) \
				or not TablePresentationPureDataPolicy.is_pure_data(_districts[public_index]):
			return _public_region_catalog_unavailable("region_source_not_pure_data")
		var district := _districts[public_index] as Dictionary
		if not district.has("region_id") or typeof(district["region_id"]) != TYPE_STRING:
			return _public_region_catalog_unavailable("region_id_type_invalid")
		if not district.has("name") or typeof(district["name"]) != TYPE_STRING:
			return _public_region_catalog_unavailable("region_name_type_invalid")
		if district.has("terrain") and not (district["terrain"] is String or district["terrain"] is StringName):
			return _public_region_catalog_unavailable("region_terrain_type_invalid")
		if district.has("destroyed") and typeof(district["destroyed"]) != TYPE_BOOL:
			return _public_region_catalog_unavailable("region_destroyed_type_invalid")
		var region_id: String = district["region_id"]
		var public_name: String = (district["name"] as String).strip_edges()
		var public_terrain := str(district.get("terrain", "")).strip_edges()
		var destroyed := district.get("destroyed", false) as bool
		if region_id.is_empty() or region_id != region_id.strip_edges() or seen_ids.has(region_id):
			return _public_region_catalog_unavailable("region_id_invalid")
		if public_name.is_empty():
			return _public_region_catalog_unavailable("region_name_missing")
		seen_ids[region_id] = true
		var entry := {
			"region_id": region_id,
			"public_index": public_index,
			"public_name": public_name,
			"public_status": "ruins" if destroyed else "active",
			"selectable": true,
			"disabled_reason": "",
			"public_terrain": public_terrain,
		}
		if not TablePresentationPureDataPolicy.is_pure_data(entry):
			return _public_region_catalog_unavailable("region_entry_not_pure_data")
		entries.append(entry)
	return {
		"schema_version": 1,
		"available": true,
		"unavailable_reason": "",
		"entries": entries,
	}


func set_city_owner_guess(
	viewer_index: int,
	region_id: String,
	suspected_player_index: int,
	confidence: int,
	reason_id: String,
	expected_owner_revision: String
) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var validation := _validate_manual_city_mutation(viewer_index, region_id, expected_owner_revision, before)
	if not bool(validation.get("valid", false)):
		return _city_inference_result(false, false, str(validation.get("reason_code", "city_inference_invalid")), before, before)
	if suspected_player_index < 0 or suspected_player_index >= _players.size() or suspected_player_index == viewer_index:
		return _city_inference_result(false, false, "city_suspect_invalid", before, before)
	if confidence not in [CITY_GUESS_CONFIDENCE_LOW, CITY_GUESS_CONFIDENCE_MEDIUM, CITY_GUESS_CONFIDENCE_HIGH]:
		return _city_inference_result(false, false, "city_confidence_invalid", before, before)
	if not CITY_GUESS_REASON_IDS.has(reason_id):
		return _city_inference_result(false, false, "city_reason_invalid", before, before)
	var district_index := int(validation.get("district_index", -1))
	var current := _city_inference_record(viewer_index, district_index)
	if int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL:
		return _city_inference_result(false, false, "authorized_reveal_locked", before, before)
	if int(current.get("suspected_player_index", -1)) == suspected_player_index \
			and int(current.get("confidence", 0)) == confidence \
			and str(current.get("reason_id", "")) == reason_id:
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	var confidences: Dictionary = player.get("city_guess_confidence", {}) if player.get("city_guess_confidence", {}) is Dictionary else {}
	var reasons: Dictionary = player.get("city_guess_reasons", {}) if player.get("city_guess_reasons", {}) is Dictionary else {}
	guesses = guesses.duplicate(true)
	confidences = confidences.duplicate(true)
	reasons = reasons.duplicate(true)
	guesses[district_index] = suspected_player_index
	confidences[district_index] = confidence
	reasons[district_index] = reason_id
	player["city_guesses"] = guesses
	player["city_guess_confidence"] = confidences
	player["city_guess_reasons"] = reasons
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "city_owner_guess_set")


func clear_city_owner_guess(viewer_index: int, region_id: String, expected_owner_revision: String) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var validation := _validate_manual_city_mutation(viewer_index, region_id, expected_owner_revision, before)
	if not bool(validation.get("valid", false)):
		return _city_inference_result(false, false, str(validation.get("reason_code", "city_inference_invalid")), before, before)
	var district_index := int(validation.get("district_index", -1))
	var current := _city_inference_record(viewer_index, district_index)
	if int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL:
		return _city_inference_result(false, false, "authorized_reveal_locked", before, before)
	if current.is_empty():
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	for field in ["city_guesses", "city_guess_confidence", "city_guess_reasons"]:
		var values: Dictionary = player.get(field, {}) if player.get(field, {}) is Dictionary else {}
		values = values.duplicate(true)
		values.erase(district_index)
		player[field] = values
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "city_owner_guess_cleared")


func set_city_guess_confidence(viewer_index: int, region_id: String, confidence: int, expected_owner_revision: String) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var validation := _validate_manual_city_mutation(viewer_index, region_id, expected_owner_revision, before)
	if not bool(validation.get("valid", false)):
		return _city_inference_result(false, false, str(validation.get("reason_code", "city_inference_invalid")), before, before)
	if confidence not in [CITY_GUESS_CONFIDENCE_LOW, CITY_GUESS_CONFIDENCE_MEDIUM, CITY_GUESS_CONFIDENCE_HIGH]:
		return _city_inference_result(false, false, "city_confidence_invalid", before, before)
	var district_index := int(validation.get("district_index", -1))
	var current := _city_inference_record(viewer_index, district_index)
	if current.is_empty():
		return _city_inference_result(false, false, "city_guess_missing", before, before)
	if int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL:
		return _city_inference_result(false, false, "authorized_reveal_locked", before, before)
	if int(current.get("confidence", 0)) == confidence:
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	var confidences: Dictionary = (player.get("city_guess_confidence", {}) as Dictionary).duplicate(true)
	confidences[district_index] = confidence
	player["city_guess_confidence"] = confidences
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "city_guess_confidence_set")


func set_city_guess_reason(viewer_index: int, region_id: String, reason_id: String, expected_owner_revision: String) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var validation := _validate_manual_city_mutation(viewer_index, region_id, expected_owner_revision, before)
	if not bool(validation.get("valid", false)):
		return _city_inference_result(false, false, str(validation.get("reason_code", "city_inference_invalid")), before, before)
	if not CITY_GUESS_REASON_IDS.has(reason_id):
		return _city_inference_result(false, false, "city_reason_invalid", before, before)
	var district_index := int(validation.get("district_index", -1))
	var current := _city_inference_record(viewer_index, district_index)
	if current.is_empty():
		return _city_inference_result(false, false, "city_guess_missing", before, before)
	if int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL:
		return _city_inference_result(false, false, "authorized_reveal_locked", before, before)
	if str(current.get("reason_id", "")) == reason_id:
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	var reasons: Dictionary = (player.get("city_guess_reasons", {}) as Dictionary).duplicate(true)
	reasons[district_index] = reason_id
	player["city_guess_reasons"] = reasons
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "city_guess_reason_set")


func apply_authorized_city_reveal(viewer_index: int, region_id: String, owner_index: int, source_reason: String) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var district_index := district_index_for_region_id(region_id)
	var subject_validation := _validate_foreign_active_city(viewer_index, district_index)
	if not bool(subject_validation.get("valid", false)):
		return _city_inference_result(false, false, str(subject_validation.get("reason_code", "city_subject_invalid")), before, before)
	var normalized_reason := source_reason.strip_edges()
	if normalized_reason.is_empty() or normalized_reason != source_reason or normalized_reason.length() > 96:
		return _city_inference_result(false, false, "authorized_reveal_reason_invalid", before, before)
	if owner_index != int(subject_validation.get("owner_index", -1)):
		return _city_inference_result(false, false, "authorized_reveal_owner_mismatch", before, before)
	var current := _city_inference_record(viewer_index, district_index)
	if int(current.get("suspected_player_index", -1)) == owner_index \
			and int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL \
			and str(current.get("reason_id", "")) == normalized_reason:
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	var confidences: Dictionary = player.get("city_guess_confidence", {}) if player.get("city_guess_confidence", {}) is Dictionary else {}
	var reasons: Dictionary = player.get("city_guess_reasons", {}) if player.get("city_guess_reasons", {}) is Dictionary else {}
	guesses = guesses.duplicate(true)
	confidences = confidences.duplicate(true)
	reasons = reasons.duplicate(true)
	guesses[district_index] = owner_index
	confidences[district_index] = CITY_GUESS_AUTHORIZED_REVEAL
	reasons[district_index] = normalized_reason
	player["city_guesses"] = guesses
	player["city_guess_confidence"] = confidences
	player["city_guess_reasons"] = reasons
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "authorized_city_reveal_set")


func restore(data: Dictionary, duplicate_collections := true) -> Dictionary:
	var next_players: Array = data.get("players", []) if data.get("players", []) is Array else []
	var next_districts: Array = data.get("districts", []) if data.get("districts", []) is Array else []
	_players = next_players.duplicate(true) if duplicate_collections else next_players
	_districts = next_districts.duplicate(true) if duplicate_collections else next_districts
	_game_time = maxf(0.0, float(data.get("game_time", 0.0)))
	_map_width_m = maxf(1.0, float(data.get("map_width_m", DEFAULT_MAP_WIDTH_M)))
	_map_height_m = maxf(1.0, float(data.get("map_height_m", DEFAULT_MAP_HEIGHT_M)))
	_world_geometry_revision = maxi(0, int(data.get("world_geometry_revision", _world_geometry_revision + 1)))
	_commodity_postcommit_city_lineage_by_district = (data.get("commodity_postcommit_city_lineage_by_district", {}) as Dictionary).duplicate(true) \
		if data.get("commodity_postcommit_city_lineage_by_district", {}) is Dictionary else {}
	_commodity_postcommit_cash_lineage_by_player = (data.get("commodity_postcommit_cash_lineage_by_player", {}) as Dictionary).duplicate(true) \
		if data.get("commodity_postcommit_cash_lineage_by_player", {}) is Dictionary else {}
	_commodity_postcommit_city_mutation_count = maxi(0, int(data.get("commodity_postcommit_city_mutation_count", 0)))
	_commodity_postcommit_cash_snapshot_count = maxi(0, int(data.get("commodity_postcommit_cash_snapshot_count", 0)))
	var summary := debug_snapshot()
	players_replaced.emit(_players.size())
	districts_replaced.emit(_districts.size())
	game_time_changed.emit(_game_time)
	world_geometry_changed.emit(_map_width_m, _map_height_m, _world_geometry_revision)
	session_restored.emit(summary)
	return summary


func internal_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"players": _players.duplicate(true),
		"districts": _districts.duplicate(true),
		"game_time": _game_time,
		"map_width_m": _map_width_m,
		"map_height_m": _map_height_m,
		"world_geometry_revision": _world_geometry_revision,
		"commodity_postcommit_city_lineage_by_district": _commodity_postcommit_city_lineage_by_district.duplicate(true),
		"commodity_postcommit_cash_lineage_by_player": _commodity_postcommit_cash_lineage_by_player.duplicate(true),
		"commodity_postcommit_city_mutation_count": _commodity_postcommit_city_mutation_count,
		"commodity_postcommit_cash_snapshot_count": _commodity_postcommit_cash_snapshot_count,
	}


func to_save_data() -> Dictionary:
	return internal_snapshot()


func capture_envelope_save_data() -> Dictionary:
	return EnvelopeCodec.capture(internal_snapshot(), _ordered_role_names())


func preflight_envelope_save_data(data: Dictionary) -> Dictionary:
	return EnvelopeCodec.normalize(data, _ordered_role_names())


func apply_envelope_save_data(data: Dictionary) -> Dictionary:
	var normalization := EnvelopeCodec.normalize(data, _ordered_role_names())
	if not bool(normalization.get("accepted", false)):
		return {
			"applied": false,
			"reason_code": str(normalization.get("reason_code", "world_session_envelope_invalid")),
		}
	var runtime_state: Dictionary = normalization.get("runtime_state", {})
	var summary := restore(runtime_state, true)
	return {
		"applied": true,
		"reason_code": "world_session_envelope_restored",
		"summary": summary,
	}


func capture_runtime_checkpoint() -> Dictionary:
	return internal_snapshot()


func preflight_new_session(plan: Dictionary) -> Dictionary:
	if int(plan.get("plan_schema_version", 0)) != 1 or not (plan.get("players") is Array) or not (plan.get("districts") is Array):
		return {"accepted": false, "reason_code": "world_session_start_plan_invalid"}
	var next_players: Array = plan.get("players", [])
	var next_districts: Array = plan.get("districts", [])
	if next_players.size() < 3 or next_players.size() > 8 or next_districts.is_empty() or float(plan.get("map_width_m", 0.0)) <= 0.0 or float(plan.get("map_height_m", 0.0)) <= 0.0:
		return {"accepted": false, "reason_code": "world_session_start_bounds_invalid"}
	var player_ids := {}
	for player_variant in next_players:
		if not (player_variant is Dictionary) or player_ids.has(int((player_variant as Dictionary).get("id", -1))):
			return {"accepted": false, "reason_code": "world_session_start_player_invalid"}
		player_ids[int((player_variant as Dictionary).get("id", -1))] = true
	var region_ids := {}
	for district_variant in next_districts:
		if not (district_variant is Dictionary):
			return {"accepted": false, "reason_code": "world_session_start_district_invalid"}
		var region_id := str((district_variant as Dictionary).get("region_id", ""))
		if region_id.is_empty() or region_ids.has(region_id):
			return {"accepted": false, "reason_code": "world_session_start_region_id_invalid"}
		region_ids[region_id] = true
	return {"accepted": true, "reason_code": "world_session_start_ready"}


func apply_new_session_plan(plan: Dictionary) -> Dictionary:
	var preflight := preflight_new_session(plan)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "world_session_start_invalid"))}
	_players = (plan.get("players", []) as Array).duplicate(true)
	_districts = (plan.get("districts", []) as Array).duplicate(true)
	_game_time = 0.0
	_map_width_m = float(plan.get("map_width_m", DEFAULT_MAP_WIDTH_M))
	_map_height_m = float(plan.get("map_height_m", DEFAULT_MAP_HEIGHT_M))
	_world_geometry_revision += 1
	_city_inference_mutation_count = 0
	_commodity_postcommit_city_lineage_by_district.clear()
	_commodity_postcommit_cash_lineage_by_player.clear()
	_commodity_postcommit_city_mutation_count = 0
	_commodity_postcommit_cash_snapshot_count = 0
	players_replaced.emit(_players.size())
	districts_replaced.emit(_districts.size())
	game_time_changed.emit(_game_time)
	world_geometry_changed.emit(_map_width_m, _map_height_m, _world_geometry_revision)
	return {"applied": true, "reason_code": "world_session_start_applied", "player_count": _players.size(), "district_count": _districts.size()}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", -1)) != 1 \
			or not (checkpoint.get("players", []) is Array) \
			or not (checkpoint.get("districts", []) is Array):
		return {"applied": false, "reason_code": "world_session_checkpoint_invalid"}
	restore(checkpoint, true)
	return {"applied": true, "reason_code": "world_session_checkpoint_restored"}


func apply_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", -1)) != 1:
		return {
			"applied": false,
			"reason_code": "world_session_save_invalid",
		}
	var summary := restore(data, true)
	return {
		"applied": true,
		"reason_code": "world_session_restored",
		"summary": summary,
	}


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"player_count": _players.size(),
		"district_count": _districts.size(),
		"game_time": _game_time,
		"map_width_m": _map_width_m,
		"map_height_m": _map_height_m,
		"world_geometry_revision": _world_geometry_revision,
		"city_inference_mutation_count": _city_inference_mutation_count,
		"commodity_postcommit_city_lineage_count": _commodity_postcommit_city_lineage_by_district.size(),
		"commodity_postcommit_player_observation_lineage_count": _commodity_postcommit_cash_lineage_by_player.size(),
		"commodity_postcommit_city_mutation_count": _commodity_postcommit_city_mutation_count,
		"commodity_postcommit_player_observation_count": _commodity_postcommit_cash_snapshot_count,
		"city_inference_projection_is_viewer_scoped": true,
		"authorized_reveal_confidence": CITY_GUESS_AUTHORIZED_REVEAL,
		"world_geometry_is_authoritative": true,
		"owns_world_session_state": true,
		"private_payload_exposed": false,
	}


func _validate_manual_city_mutation(viewer_index: int, region_id: String, expected_owner_revision: String, current_revision: String) -> Dictionary:
	if viewer_index < 0 or viewer_index >= _players.size():
		return {"valid": false, "reason_code": "viewer_invalid"}
	if expected_owner_revision.is_empty() or expected_owner_revision != current_revision:
		return {"valid": false, "reason_code": "owner_revision_stale"}
	var district_index := district_index_for_region_id(region_id)
	var subject_validation := _validate_foreign_active_city(viewer_index, district_index)
	if not bool(subject_validation.get("valid", false)):
		return subject_validation
	return {"valid": true, "district_index": district_index}


func _validate_foreign_active_city(viewer_index: int, district_index: int) -> Dictionary:
	if viewer_index < 0 or viewer_index >= _players.size():
		return {"valid": false, "reason_code": "viewer_invalid"}
	if district_index < 0 or district_index >= _districts.size() or not (_districts[district_index] is Dictionary):
		return {"valid": false, "reason_code": "city_subject_missing"}
	var district := _districts[district_index] as Dictionary
	var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
	if bool(district.get("destroyed", false)) or city.is_empty() or not bool(city.get("active", true)):
		return {"valid": false, "reason_code": "city_subject_inactive"}
	var owner_index := int(city.get("owner", -1))
	if owner_index < 0 or owner_index >= _players.size():
		return {"valid": false, "reason_code": "city_owner_invalid"}
	if owner_index == viewer_index:
		return {"valid": false, "reason_code": "own_city_subject"}
	return {"valid": true, "owner_index": owner_index}


func _city_inference_records(viewer_index: int) -> Array:
	var records: Array = []
	if viewer_index < 0 or viewer_index >= _players.size() or not (_players[viewer_index] is Dictionary):
		return records
	var player := _players[viewer_index] as Dictionary
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	var district_indices: Array[int] = []
	for key_variant in guesses.keys():
		var district_index := int(key_variant)
		if district_index >= 0 and district_index < _districts.size() and not district_indices.has(district_index):
			district_indices.append(district_index)
	district_indices.sort()
	for district_index in district_indices:
		var record := _city_inference_record(viewer_index, district_index)
		if not record.is_empty():
			records.append(record)
	return records


func _foreign_active_region_ids(viewer_index: int) -> Array:
	var result: Array[String] = []
	for district_index in range(_districts.size()):
		var validation := _validate_foreign_active_city(viewer_index, district_index)
		if bool(validation.get("valid", false)):
			result.append(_region_id_for_district(district_index))
	return result


func _city_inference_record(viewer_index: int, district_index: int) -> Dictionary:
	if viewer_index < 0 or viewer_index >= _players.size() or not (_players[viewer_index] is Dictionary):
		return {}
	var player := _players[viewer_index] as Dictionary
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	if not guesses.has(district_index) and not guesses.has(str(district_index)):
		return {}
	var suspected_player_index := int(_dictionary_index_value(guesses, district_index, -1))
	var confidences: Dictionary = player.get("city_guess_confidence", {}) if player.get("city_guess_confidence", {}) is Dictionary else {}
	var reasons: Dictionary = player.get("city_guess_reasons", {}) if player.get("city_guess_reasons", {}) is Dictionary else {}
	var confidence := int(_dictionary_index_value(confidences, district_index, CITY_GUESS_CONFIDENCE_MEDIUM))
	var reason_id := str(_dictionary_index_value(reasons, district_index, "intuition"))
	return {
		"district_index": district_index,
		"region_id": _region_id_for_district(district_index),
		"suspected_player_index": suspected_player_index,
		"confidence": confidence,
		"reason_id": reason_id,
		"reason_kind": "public_reveal" if confidence == CITY_GUESS_AUTHORIZED_REVEAL else "manual",
		"authorized_reveal": confidence == CITY_GUESS_AUTHORIZED_REVEAL,
	}


func _commit_city_inference(viewer_index: int, region_id: String, before_revision: String, reason_code: String) -> Dictionary:
	_city_inference_mutation_count += 1
	var after_revision := city_inference_owner_revision(viewer_index)
	city_inference_changed.emit(viewer_index, region_id, after_revision)
	return _city_inference_result(true, true, reason_code, before_revision, after_revision)


func _city_inference_result(applied: bool, changed: bool, reason_code: String, before_revision: String, after_revision: String) -> Dictionary:
	return {
		"applied": applied,
		"changed": changed,
		"reason_code": reason_code,
		"owner_revision_before": before_revision,
		"owner_revision_after": after_revision,
	}


func _dictionary_index_value(values: Dictionary, district_index: int, fallback: Variant) -> Variant:
	if values.has(district_index):
		return values[district_index]
	if values.has(str(district_index)):
		return values[str(district_index)]
	return fallback


func _region_id_for_district(district_index: int) -> String:
	if district_index < 0 or district_index >= _districts.size() or not (_districts[district_index] is Dictionary):
		return ""
	return str((_districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))


func _public_region_catalog_unavailable(reason_code: String) -> Dictionary:
	return {
		"schema_version": 1,
		"available": false,
		"unavailable_reason": reason_code,
		"entries": [],
	}


func _canonical_string_array(value: Variant) -> Array:
	var result: Array[String] = []
	if value is Array:
		for item_variant in value as Array:
			if not (item_variant is String or item_variant is StringName):
				continue
			var item := str(item_variant).strip_edges()
			if not item.is_empty() and not result.has(item):
				result.append(item)
	result.sort()
	return result


func _private_city_product_names(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for product_variant in value as Array:
			var product_id := ""
			if product_variant is Dictionary:
				product_id = str((product_variant as Dictionary).get("name", "")).strip_edges()
			elif product_variant is String or product_variant is StringName:
				product_id = str(product_variant).strip_edges()
			if not product_id.is_empty() and not result.has(product_id):
				result.append(product_id)
	result.sort()
	return result


func _stable_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(value).to_utf8_buffer())
	return context.finish().hex_encode()


func _ordered_role_names() -> Array[String]:
	var catalog := get_node_or_null(role_catalog_path)
	if catalog == null or not catalog.has_method("ordered_role_names"):
		return []
	var names_variant: Variant = catalog.call("ordered_role_names")
	if not (names_variant is Array):
		return []
	var names: Array[String] = []
	for name_variant in names_variant as Array:
		names.append(str(name_variant))
	return names
