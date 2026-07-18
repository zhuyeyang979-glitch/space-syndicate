@tool
extends Node
class_name CommodityFlowRuntimeController

signal installation_committed(receipt: Dictionary)
signal sale_receipt_batch_committed(receipt: Dictionary)
signal flow_loss_batch_committed(events: Array)

const RULESET_ID := "v0.6"
const STATE_VERSION := 2
const LEGACY_STATE_VERSION := 1
const FIXED_POINT_SCALE := 1000
const MILLISECONDS_PER_MINUTE := 60000
const BASIS_POINTS := 10000
const COMMODITY_FLOW_TERMS_VERSION := 2
const LEGACY_BACKPRESSURE_MIGRATION_VERSION := 1
const REMOTE_ROUTE_VALUE_BASIS_POINTS := BASIS_POINTS
const PRODUCT_INDUSTRY_CATALOG := preload("res://resources/content/product_industry_catalog_v05.tres")
const CARD_EFFECT_SUPPORT := preload("res://scripts/cards/v06/effects/card_effect_adapter_support_v06.gd")
const VALID_DIRECTIONS := ["production", "demand"]
const WEATHER_ECONOMY_MULTIPLIER_MIN := 0.70
const WEATHER_ECONOMY_MULTIPLIER_MAX := 1.30
const WEATHER_PUBLIC_CONTRIBUTION_KEYS := [
	"kind",
	"weather_id",
	"weather_label",
	"event_id",
	"region_index",
	"phase",
	"intensity",
	"product_id",
	"direction",
	"multiplier",
	"price_growth_multiplier",
	"production_multiplier",
	"demand_multiplier",
	"reason_codes",
]

var _configured := false
var _world_bridge: Node
var _weather_runtime_controller: WeatherRuntimeController
var _weather_telemetry_runtime_service: Node
var _currency_scale := 100
var _observation_window_seconds := 30.0
var _commodity_rates_by_rank: Dictionary = {}
var _factory_market_capacity_by_rank: Dictionary = {}
var _warehouse_capacity_by_rank: Dictionary = {}
var _warehouse_throughput_by_rank: Dictionary = {}
var _warehouse_storage_rent_bp_per_minute_by_rank: Dictionary = {}
var _distance_premium_per_unit_bp := 0
var _distance_premium_maximum_bp := 0
var _non_storage_rent_cap_bp := 0
var _ambient_consumption_default_units_per_minute := 0
var _ambient_consumption_units_per_minute_by_commodity: Dictionary = {}
var _ambient_consumption_value_basis_points := 0
var _market_backlog_horizon_seconds := 0
var _market_backlog_recovery_extra_basis_points := 0

var _installations: Dictionary = {}
var _installation_sequence := 0
var _installation_generation_by_key: Dictionary = {}
var _installation_transaction_receipts: Dictionary = {}
var _installation_rollback_receipts: Dictionary = {}
var _rate_remainders: Dictionary = {}
var _pair_remainders: Dictionary = {}
var _ambient_rate_remainders: Dictionary = {}
var _ambient_fairness_cursor_by_region_commodity: Dictionary = {}
var _ambient_revision := 0
var _market_backlog_by_key: Dictionary = {}
var _wasted_continuous_milliunits_by_source: Dictionary = {}
var _wasted_continuous_milliunits_per_minute_by_source: Dictionary = {}
var _cumulative_wasted_milliunits_by_source: Dictionary = {}
var _cumulative_wasted_milliunits_by_commodity: Dictionary = {}
var _cumulative_wasted_milliunits_by_region: Dictionary = {}
var _waste_revision := 0
var _recent_flow_loss_events: Array = []
var _recent_flow_events: Array = []
var _legacy_backpressure_migration_version := 0
var _recent_sale_receipts: Array = []
var _warehouse_inventory: Dictionary = {}
var _pending_one_shot_supplies: Dictionary = {}
var _one_shot_transaction_receipts: Dictionary = {}
var _pending_one_shot_demands: Dictionary = {}
var _one_shot_demand_transaction_receipts: Dictionary = {}
var _card_effect_batch_journal: Dictionary = {}
var _card_effect_batch_rollback_receipts: Dictionary = {}
var _card_effect_candidate_snapshot_revision := 0
var _card_effect_candidate_snapshot_fingerprint := ""
var _receipt_sequence := 0
var _batch_sequence := 0
var _flow_revision := 0
var _current_game_time := 0.0
var _last_flow_metrics: Dictionary = {}
var _bankruptcy_estate_journal: Dictionary = {}


func set_world_bridge(bridge: Node) -> void:
	_world_bridge = bridge


func set_weather_runtime_controller(controller: WeatherRuntimeController) -> void:
	_weather_runtime_controller = controller


func set_weather_telemetry_runtime_service(service: Node) -> void:
	_weather_telemetry_runtime_service = service


func configure(profile_snapshot: Dictionary) -> Dictionary:
	var identity: Dictionary = _dictionary(profile_snapshot.get("identity", {}))
	var infrastructure: Dictionary = _dictionary(profile_snapshot.get("infrastructure", {}))
	var commodity: Dictionary = _dictionary(profile_snapshot.get("commodity", {}))
	var victory: Dictionary = _dictionary(profile_snapshot.get("victory", {}))
	var capabilities: Dictionary = _dictionary(profile_snapshot.get("capabilities", {}))
	_currency_scale = maxi(1, int(identity.get("currency_scale", 100)))
	_observation_window_seconds = maxf(1.0, float(victory.get("gdp_observation_window_seconds", 30)))
	_commodity_rates_by_rank = _rank_table(commodity.get("commodity_rate_by_rank", {}))
	_factory_market_capacity_by_rank = _rank_table(infrastructure.get("factory_market_capacity_by_rank", {}))
	_warehouse_capacity_by_rank = _rank_table(infrastructure.get("warehouse_capacity_by_rank", {}))
	_warehouse_throughput_by_rank = _rank_table(infrastructure.get("warehouse_throughput_by_rank", {}))
	_warehouse_storage_rent_bp_per_minute_by_rank = _rank_table(infrastructure.get("warehouse_storage_rent_bp_per_minute_by_rank", {}))
	_distance_premium_per_unit_bp = maxi(0, int(commodity.get("distance_premium_per_unit_bp", 0)))
	_distance_premium_maximum_bp = maxi(0, int(commodity.get("distance_premium_maximum_bp", 0)))
	_non_storage_rent_cap_bp = clampi(int(commodity.get("non_storage_rent_cap_bp", 0)), 0, BASIS_POINTS)
	var terms_version := int(commodity.get("commodity_flow_terms_version", 0))
	_ambient_consumption_default_units_per_minute = maxi(0, int(commodity.get("ambient_consumption_default_units_per_minute", 0)))
	_ambient_consumption_units_per_minute_by_commodity = _commodity_rate_map(commodity.get("ambient_consumption_units_per_minute_by_commodity", {}))
	_ambient_consumption_value_basis_points = clampi(int(commodity.get("ambient_consumption_value_basis_points", 0)), 0, BASIS_POINTS)
	_market_backlog_horizon_seconds = maxi(0, int(commodity.get("market_backlog_horizon_seconds", 0)))
	_market_backlog_recovery_extra_basis_points = maxi(0, int(commodity.get("market_backlog_recovery_extra_basis_points", 0)))
	_configured = str(identity.get("ruleset_id", "")) == RULESET_ID \
		and bool(capabilities.get("continuous_commodity_flow_enabled", false)) \
		and not bool(capabilities.get("legacy_project_slots_enabled", true)) \
		and not _commodity_rates_by_rank.is_empty() \
		and not _factory_market_capacity_by_rank.is_empty() \
		and not _warehouse_capacity_by_rank.is_empty() \
		and not _warehouse_throughput_by_rank.is_empty() \
		and not _warehouse_storage_rent_bp_per_minute_by_rank.is_empty() \
		and terms_version == COMMODITY_FLOW_TERMS_VERSION \
		and _ambient_consumption_default_units_per_minute > 0 \
		and _ambient_consumption_value_basis_points > 0 \
		and _market_backlog_horizon_seconds > 0 \
		and _market_backlog_recovery_extra_basis_points >= 0 \
		and PRODUCT_INDUSTRY_CATALOG != null
	if not _configured:
		push_error("CommodityFlowRuntimeController requires the v0.6 continuous-flow profile and product catalog.")
	return {
		"configured": _configured,
		"ruleset_id": RULESET_ID,
		"currency_scale": _currency_scale,
		"observation_window_seconds": _observation_window_seconds,
		"commodity_flow_terms_version": terms_version,
		"ambient_consumption_default_units_per_minute": _ambient_consumption_default_units_per_minute,
		"ambient_consumption_units_per_minute_by_commodity": _ambient_consumption_units_per_minute_by_commodity.duplicate(true),
		"ambient_consumption_value_basis_points": _ambient_consumption_value_basis_points,
		"market_backlog_horizon_seconds": _market_backlog_horizon_seconds,
		"market_backlog_recovery_extra_basis_points": _market_backlog_recovery_extra_basis_points,
	}


func reset_state() -> void:
	_installations.clear()
	_installation_sequence = 0
	_installation_generation_by_key.clear()
	_installation_transaction_receipts.clear()
	_installation_rollback_receipts.clear()
	_rate_remainders.clear()
	_pair_remainders.clear()
	_ambient_rate_remainders.clear()
	_ambient_fairness_cursor_by_region_commodity.clear()
	_ambient_revision = 0
	_market_backlog_by_key.clear()
	_wasted_continuous_milliunits_by_source.clear()
	_wasted_continuous_milliunits_per_minute_by_source.clear()
	_cumulative_wasted_milliunits_by_source.clear()
	_cumulative_wasted_milliunits_by_commodity.clear()
	_cumulative_wasted_milliunits_by_region.clear()
	_waste_revision = 0
	_recent_flow_loss_events.clear()
	_recent_flow_events.clear()
	_legacy_backpressure_migration_version = 0
	_recent_sale_receipts.clear()
	_warehouse_inventory.clear()
	_pending_one_shot_supplies.clear()
	_one_shot_transaction_receipts.clear()
	_pending_one_shot_demands.clear()
	_one_shot_demand_transaction_receipts.clear()
	_card_effect_batch_journal.clear()
	_card_effect_batch_rollback_receipts.clear()
	_card_effect_candidate_snapshot_revision = 0
	_card_effect_candidate_snapshot_fingerprint = ""
	_receipt_sequence = 0
	_batch_sequence = 0
	_flow_revision = 0
	_current_game_time = 0.0
	_last_flow_metrics = {}
	_bankruptcy_estate_journal.clear()


func bankruptcy_estate_stage(stage: String, request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var player_indices: Array = request.get("player_indices", []) if request.get("player_indices", []) is Array else []
	if transaction_id.is_empty() or player_indices.is_empty() or not ["prepare", "commit", "rollback", "finalize"].has(stage):
		return _bankruptcy_estate_failure(stage, "commodity_flow_bankruptcy_request_invalid")
	var existing: Dictionary = _bankruptcy_estate_journal.get(transaction_id, {}) if _bankruptcy_estate_journal.get(transaction_id, {}) is Dictionary else {}
	if not existing.is_empty() and existing.get("player_indices", []) != player_indices:
		return _bankruptcy_estate_failure(stage, "commodity_flow_bankruptcy_transaction_collision")
	match stage:
		"prepare":
			if not existing.is_empty():
				return _bankruptcy_estate_result(stage, existing, true)
			var targets: Dictionary = {}
			for player_index_variant in player_indices:
				targets[str(int(player_index_variant))] = true
			var next_inventory := _warehouse_inventory.duplicate(true)
			var next_supplies := _pending_one_shot_supplies.duplicate(true)
			var removed := 0
			for bucket_id_variant in _warehouse_inventory.keys():
				var bucket: Dictionary = _warehouse_inventory[bucket_id_variant] if _warehouse_inventory[bucket_id_variant] is Dictionary else {}
				if targets.has(str(int(bucket.get("owner_player_index", -1)))):
					next_inventory.erase(bucket_id_variant)
					removed += 1
			for supply_id_variant in _pending_one_shot_supplies.keys():
				var supply: Dictionary = _pending_one_shot_supplies[supply_id_variant] if _pending_one_shot_supplies[supply_id_variant] is Dictionary else {}
				if targets.has(str(int(supply.get("player_index", -1)))):
					next_supplies.erase(supply_id_variant)
					removed += 1
			existing = {
				"state": "prepared",
				"player_indices": player_indices.duplicate(),
				"expected_flow_revision": _flow_revision,
				"preimage_inventory": _warehouse_inventory.duplicate(true),
				"preimage_supplies": _pending_one_shot_supplies.duplicate(true),
				"postimage_inventory": next_inventory,
				"postimage_supplies": next_supplies,
				"estate_counts": {"goods_removed": removed},
			}
			_bankruptcy_estate_journal[transaction_id] = existing
			return _bankruptcy_estate_result(stage, existing, false)
		"commit":
			if existing.is_empty():
				return _bankruptcy_estate_failure(stage, "commodity_flow_bankruptcy_prepare_missing")
			if str(existing.get("state", "")) in ["committed", "finalized"]:
				return _bankruptcy_estate_result(stage, existing, true)
			if str(existing.get("state", "")) != "prepared" or _flow_revision != int(existing.get("expected_flow_revision", -1)):
				return _bankruptcy_estate_failure(stage, "commodity_flow_bankruptcy_revision_changed")
			_warehouse_inventory = (existing.get("postimage_inventory", {}) as Dictionary).duplicate(true)
			_pending_one_shot_supplies = (existing.get("postimage_supplies", {}) as Dictionary).duplicate(true)
			_flow_revision += 1
			existing["state"] = "committed"
			_bankruptcy_estate_journal[transaction_id] = existing
			return _bankruptcy_estate_result(stage, existing, false)
		"rollback":
			if existing.is_empty():
				return _bankruptcy_estate_failure(stage, "commodity_flow_bankruptcy_prepare_missing")
			if str(existing.get("state", "")) == "rolled_back":
				return _bankruptcy_estate_result(stage, existing, true)
			if str(existing.get("state", "")) == "finalized":
				return _bankruptcy_estate_failure(stage, "commodity_flow_bankruptcy_already_finalized")
			if str(existing.get("state", "")) == "committed":
				_warehouse_inventory = (existing.get("preimage_inventory", {}) as Dictionary).duplicate(true)
				_pending_one_shot_supplies = (existing.get("preimage_supplies", {}) as Dictionary).duplicate(true)
				_flow_revision = int(existing.get("expected_flow_revision", _flow_revision))
			existing["state"] = "rolled_back"
			_bankruptcy_estate_journal[transaction_id] = existing
			return _bankruptcy_estate_result(stage, existing, false)
		"finalize":
			if existing.is_empty() or not (str(existing.get("state", "")) in ["committed", "finalized"]):
				return _bankruptcy_estate_failure(stage, "commodity_flow_bankruptcy_commit_missing")
			var duplicate := str(existing.get("state", "")) == "finalized"
			existing["state"] = "finalized"
			for key in ["preimage_inventory", "preimage_supplies", "postimage_inventory", "postimage_supplies"]:
				existing.erase(key)
			_bankruptcy_estate_journal[transaction_id] = existing
			return _bankruptcy_estate_result(stage, existing, duplicate)
	return _bankruptcy_estate_failure(stage, "commodity_flow_bankruptcy_stage_invalid")


func _bankruptcy_estate_result(stage: String, record: Dictionary, duplicate: bool) -> Dictionary:
	return {
		"prepared": stage == "prepare",
		"committed": stage == "commit",
		"rolled_back": stage == "rollback",
		"finalized": stage == "finalize",
		"duplicate": duplicate,
		"reason_code": "commodity_flow_bankruptcy_%s" % stage,
		"estate_counts": (record.get("estate_counts", {}) as Dictionary).duplicate(true) if record.get("estate_counts", {}) is Dictionary else {},
	}


func _bankruptcy_estate_failure(stage: String, reason_code: String) -> Dictionary:
	return {"prepared": false, "committed": false, "rolled_back": false, "finalized": false, "stage": stage, "reason_code": reason_code, "estate_counts": {}}


func install_commodity(request: Dictionary) -> Dictionary:
	return _install_commodity(request, false)


func install_public_demand(request: Dictionary) -> Dictionary:
	var normalized := request.duplicate(true)
	normalized["owner_kind"] = "public"
	normalized["installer_player_index"] = -1
	normalized["direction"] = "demand"
	return _install_commodity(normalized, true)


func _install_commodity(request: Dictionary, allow_public_demand: bool) -> Dictionary:
	if not _configured:
		return _installation_failure(request, "controller_not_ready")
	if not _is_pure_data(request):
		return _installation_failure(request, "request_not_pure_data")
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	if transaction_id.is_empty():
		return _installation_failure(request, "transaction_id_missing")
	var request_fingerprint := _installation_request_fingerprint(request)
	if _installation_rollback_receipts.has(transaction_id):
		var rolled_back_replay: Dictionary = (_installation_rollback_receipts.get(transaction_id, {}) as Dictionary).duplicate(true)
		if allow_public_demand and str(rolled_back_replay.get("request_fingerprint", "")) != request_fingerprint:
			return _installation_failure(request, "installation_transaction_binding_collision")
		rolled_back_replay["duplicate"] = true
		rolled_back_replay["committed"] = false
		return rolled_back_replay
	if _installation_transaction_receipts.has(transaction_id):
		var duplicate_receipt: Dictionary = (_installation_transaction_receipts[transaction_id] as Dictionary).duplicate(true)
		if allow_public_demand and str(duplicate_receipt.get("request_fingerprint", "")) != request_fingerprint:
			return _installation_failure(request, "installation_transaction_binding_collision")
		duplicate_receipt["duplicate"] = true
		return duplicate_receipt
	var facility: Dictionary = _dictionary(request.get("facility", {}))
	var facility_id := str(request.get("facility_id", facility.get("facility_id", ""))).strip_edges()
	var region_id := str(request.get("region_id", facility.get("region_id", ""))).strip_edges()
	var commodity_id := str(request.get("commodity_id", request.get("product_id", ""))).strip_edges()
	var direction := str(request.get("direction", "")).strip_edges()
	var player_index := int(request.get("installer_player_index", request.get("player_index", -1)))
	var owner_kind := str(request.get("owner_kind", "player")).strip_edges()
	var is_public_demand := allow_public_demand and owner_kind == "public" and direction == "demand" and player_index == -1
	var rank := _rank_number(request.get("source_card_rank", request.get("rank", 0)))
	var industry_id := str(PRODUCT_INDUSTRY_CATALOG.call("industry_for_product", commodity_id)) if PRODUCT_INDUSTRY_CATALOG.has_method("industry_for_product") else ""
	if facility_id.is_empty() or region_id.is_empty() or commodity_id.is_empty() or industry_id.is_empty():
		return _remember_installation_receipt(transaction_id, _installation_failure(request, "installation_identity_invalid"))
	if not VALID_DIRECTIONS.has(direction) or (player_index < 0 and not is_public_demand) or rank < 1 or not _commodity_rates_by_rank.has(rank):
		return _remember_installation_receipt(transaction_id, _installation_failure(request, "installation_terms_invalid"))
	if allow_public_demand and not is_public_demand:
		return _remember_installation_receipt(transaction_id, _installation_failure(request, "public_demand_terms_invalid"))
	if not bool(facility.get("active", false)) or str(facility.get("facility_id", "")) != facility_id or str(facility.get("region_id", "")) != region_id:
		return _remember_installation_receipt(transaction_id, _installation_failure(request, "facility_not_active"))
	var expected_type := "factory" if direction == "production" else "market"
	if str(facility.get("facility_type", "")) != expected_type or str(facility.get("industry_id", "")) != industry_id:
		return _remember_installation_receipt(transaction_id, _installation_failure(request, "facility_industry_or_direction_mismatch"))
	if is_public_demand and (str(facility.get("owner_kind", "")) != "neutral" or int(facility.get("owner_player_index", -1)) != -1):
		return _remember_installation_receipt(transaction_id, _installation_failure(request, "public_demand_market_not_neutral"))
	var supplied_color := str(request.get("color", industry_id))
	if supplied_color != industry_id:
		return _remember_installation_receipt(transaction_id, _installation_failure(request, "commodity_color_mismatch"))
	_installation_sequence += 1
	var generation_key := "%s|%s|%s|%d" % [facility_id, commodity_id, direction, player_index]
	var generation := int(_installation_generation_by_key.get(generation_key, 0)) + 1
	_installation_generation_by_key[generation_key] = generation
	var installation_id := str(request.get("installation_id", "")).strip_edges()
	if installation_id.is_empty():
		installation_id = "commodity-installation-%08d" % _installation_sequence
	if _installations.has(installation_id):
		return _remember_installation_receipt(transaction_id, _installation_failure(request, "installation_id_conflict"))
	var installation := {
		"installation_id": installation_id,
		"commodity_id": commodity_id,
		"color": industry_id,
		"installer_player_index": player_index,
		"owner_kind": "public" if is_public_demand else "player",
		"direction": direction,
		"base_units_per_minute": int(_commodity_rates_by_rank.get(rank, 0)),
		"source_card_rank": rank,
		"facility_id": facility_id,
		"region_id": region_id,
		"region_revision": maxi(0, int(request.get("region_revision", 0))),
		"generation": generation,
		"active": true,
		"installed_at": float(request.get("installed_at", request.get("game_time", 0.0))),
	}
	_installations[installation_id] = installation
	_rate_remainders[installation_id] = 0
	_flow_revision += 1
	var receipt := {
		"receipt_kind": "commodity_installation",
		"transaction_id": transaction_id,
		"committed": true,
		"duplicate": false,
		"finalized": false,
		"rollback_open": true,
		"request_fingerprint": request_fingerprint,
		"reason": "",
		"installation": installation.duplicate(true),
		"flow_revision": _flow_revision,
	}
	_remember_installation_receipt(transaction_id, receipt)
	installation_committed.emit(receipt.duplicate(true))
	return receipt


func commodity_installation_finalize_preflight(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", "")).strip_edges()
	if transaction_id.is_empty() or str(receipt.get("receipt_kind", "")) != "commodity_installation":
		return {"ready": false, "reason_code": "installation_receipt_binding_invalid", "transaction_id": transaction_id}
	if not _installation_transaction_receipts.has(transaction_id):
		return {"ready": false, "reason_code": "installation_transaction_missing", "transaction_id": transaction_id}
	var stored: Dictionary = (_installation_transaction_receipts.get(transaction_id, {}) as Dictionary).duplicate(true)
	var stored_installation: Dictionary = stored.get("installation", {}) if stored.get("installation", {}) is Dictionary else {}
	var receipt_installation: Dictionary = receipt.get("installation", {}) if receipt.get("installation", {}) is Dictionary else {}
	if not bool(stored.get("committed", false)) \
		or str(stored_installation.get("installation_id", "")) != str(receipt_installation.get("installation_id", "")) \
		or str(stored.get("request_fingerprint", "")) != str(receipt.get("request_fingerprint", "")):
		return {"ready": false, "reason_code": "installation_receipt_binding_invalid", "transaction_id": transaction_id}
	var installation_id := str(stored_installation.get("installation_id", ""))
	if installation_id.is_empty() or not _installations.has(installation_id):
		return {"ready": false, "reason_code": "installation_state_missing", "transaction_id": transaction_id}
	if not bool(stored.get("finalized", false)) and not bool(stored.get("rollback_open", false)):
		return {"ready": false, "reason_code": "installation_lifecycle_invalid", "transaction_id": transaction_id}
	return {
		"ready": true,
		"reason_code": "installation_finalize_ready",
		"transaction_id": transaction_id,
		"installation_id": installation_id,
		"already_finalized": bool(stored.get("finalized", false)),
		"stored_receipt": stored,
	}


func finalize_commodity_installation(receipt: Dictionary) -> Dictionary:
	var preflight := commodity_installation_finalize_preflight(receipt)
	var transaction_id := str(preflight.get("transaction_id", ""))
	if not bool(preflight.get("ready", false)):
		return {
			"finalized": false,
			"reason_code": str(preflight.get("reason_code", "installation_finalize_preflight_failed")),
			"transaction_id": transaction_id,
		}
	var stored: Dictionary = (preflight.get("stored_receipt", {}) as Dictionary).duplicate(true)
	if bool(stored.get("finalized", false)):
		stored["duplicate"] = true
		stored["idempotent_replay"] = true
		return stored
	stored["finalized"] = true
	stored["rollback_open"] = false
	stored["duplicate"] = false
	stored["reason_code"] = "finalized"
	_installation_transaction_receipts[transaction_id] = stored.duplicate(true)
	return stored


func rollback_commodity_installation(transaction_id: String) -> Dictionary:
	var normalized_id := transaction_id.strip_edges()
	if normalized_id.is_empty():
		return {"rolled_back": false, "duplicate": false, "reason": "transaction_id_missing"}
	if _installation_rollback_receipts.has(normalized_id):
		var replay: Dictionary = (_installation_rollback_receipts.get(normalized_id, {}) as Dictionary).duplicate(true)
		replay["duplicate"] = true
		return replay
	if not _installation_transaction_receipts.has(normalized_id):
		return {"rolled_back": false, "duplicate": false, "reason": "installation_transaction_missing", "transaction_id": normalized_id}
	var installation_receipt: Dictionary = _installation_transaction_receipts.get(normalized_id, {}) as Dictionary
	if not bool(installation_receipt.get("committed", false)):
		return {"rolled_back": false, "duplicate": false, "reason": "installation_not_committed", "transaction_id": normalized_id}
	if not bool(installation_receipt.get("rollback_open", true)):
		return {"rolled_back": false, "committed": true, "duplicate": false, "reason": "installation_rollback_closed", "reason_code": "installation_rollback_closed", "transaction_id": normalized_id}
	var installation: Dictionary = installation_receipt.get("installation", {}) if installation_receipt.get("installation", {}) is Dictionary else {}
	var installation_id := str(installation.get("installation_id", ""))
	if installation_id.is_empty() or not _installations.has(installation_id):
		return {"rolled_back": false, "duplicate": false, "reason": "installation_missing", "transaction_id": normalized_id}
	_installations.erase(installation_id)
	_rate_remainders.erase(installation_id)
	_installation_transaction_receipts.erase(normalized_id)
	_flow_revision += 1
	var receipt := {
		"rolled_back": true,
		"duplicate": false,
		"reason": "",
		"transaction_id": normalized_id,
		"installation_id": installation_id,
		"request_fingerprint": str(installation_receipt.get("request_fingerprint", "")),
		"flow_revision": _flow_revision,
	}
	_installation_rollback_receipts[normalized_id] = receipt.duplicate(true)
	return receipt


func inject_one_shot_supply(request: Dictionary) -> Dictionary:
	if not _configured:
		return {"accepted": false, "reason": "controller_not_ready"}
	if not _is_pure_data(request):
		return {"accepted": false, "reason": "request_not_pure_data"}
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	if transaction_id.is_empty():
		return {"accepted": false, "reason": "transaction_id_missing"}
	if _one_shot_transaction_receipts.has(transaction_id):
		var replay_receipt: Dictionary = (_one_shot_transaction_receipts[transaction_id] as Dictionary).duplicate(true)
		replay_receipt["duplicate"] = true
		return replay_receipt
	var commodity_id := str(request.get("commodity_id", request.get("product_id", ""))).strip_edges()
	var region_id := str(request.get("region_id", "")).strip_edges()
	var owner_index := int(request.get("owner_player_index", request.get("player_index", -1)))
	var milliunits := maxi(0, int(request.get("milliunits", int(request.get("units", 0)) * FIXED_POINT_SCALE)))
	if commodity_id.is_empty() or region_id.is_empty() or owner_index < 0 or milliunits <= 0:
		return {"accepted": false, "reason": "supply_identity_invalid", "transaction_id": transaction_id}
	var industry_id := str(PRODUCT_INDUSTRY_CATALOG.call("industry_for_product", commodity_id)) if PRODUCT_INDUSTRY_CATALOG.has_method("industry_for_product") else ""
	if industry_id.is_empty():
		return {"accepted": false, "reason": "commodity_unknown", "transaction_id": transaction_id}
	var supply := {
		"transaction_id": transaction_id,
		"installation_id": "one-shot:%s" % transaction_id,
		"source_kind": "one_shot",
		"commodity_id": commodity_id,
		"color": industry_id,
		"player_index": owner_index,
		"region_id": region_id,
		"milliunits": milliunits,
		"storage_liability_kind": "passive_forced",
	}
	_pending_one_shot_supplies[transaction_id] = supply
	var receipt := {
		"transaction_id": transaction_id,
		"accepted": true,
		"duplicate": false,
		"settled": false,
		"stored_milliunits": 0,
		"lost_milliunits": 0,
	}
	_one_shot_transaction_receipts[transaction_id] = receipt
	return receipt.duplicate(true)


func prepare_card_effect_batch(plan: Dictionary) -> Dictionary:
	var binding := _card_effect_batch_binding(plan)
	if not _configured:
		return _card_effect_batch_failure(binding, "controller_not_ready", "prepare")
	if not _is_pure_data(plan):
		return _card_effect_batch_failure(binding, "request_not_pure_data", "prepare")
	if not _card_effect_batch_binding_complete(binding):
		return _card_effect_batch_failure(binding, "transaction_binding_missing", "prepare")
	var transaction_id := str(binding.get("transaction_id", ""))
	if _card_effect_batch_journal.has(transaction_id):
		var existing: Dictionary = _dictionary(_card_effect_batch_journal.get(transaction_id, {}))
		if not _card_effect_batch_binding_matches(existing, binding):
			return _card_effect_batch_failure(binding, "transaction_intent_collision", "prepare")
		var replay := binding.duplicate(true)
		replay["prepared"] = true
		replay["duplicate"] = true
		replay["replay_only"] = true
		replay["reason_code"] = "prepared_replay"
		replay["prepared_token"] = str(existing.get("prepared_token", ""))
		return replay
	if _world_bridge == null or not _world_bridge.has_method("capture_flow_facts"):
		return _card_effect_batch_failure(binding, "world_facts_unavailable", "prepare")
	var facts_variant: Variant = _world_bridge.call("capture_flow_facts")
	if not (facts_variant is Dictionary) or not _is_pure_data(facts_variant) or (facts_variant as Dictionary).is_empty():
		return _card_effect_batch_failure(binding, "world_facts_invalid", "prepare")
	var normalized := _normalize_card_effect_batch(plan, facts_variant as Dictionary)
	if not bool(normalized.get("valid", false)):
		return _card_effect_batch_failure(binding, str(normalized.get("reason_code", "batch_child_invalid")), "prepare")
	var prepared := binding.duplicate(true)
	prepared["prepared"] = true
	prepared["duplicate"] = false
	prepared["reason_code"] = "prepared"
	prepared["expected_flow_revision"] = _flow_revision
	prepared["one_time_effect_kind"] = str(plan.get("one_time_effect_kind", ""))
	prepared["prepared_children"] = (normalized.get("children", []) as Array).duplicate(true)
	prepared["prepared_token"] = _card_effect_prepared_token(prepared)
	return prepared


func commit_card_effect_batch(prepared: Dictionary) -> Dictionary:
	var binding := _card_effect_batch_binding(prepared)
	if not _configured:
		return _card_effect_batch_failure(binding, "controller_not_ready", "commit")
	if not _is_pure_data(prepared) or not _card_effect_batch_binding_complete(binding):
		return _card_effect_batch_failure(binding, "prepared_batch_invalid", "commit")
	var transaction_id := str(binding.get("transaction_id", ""))
	if _card_effect_batch_journal.has(transaction_id):
		var existing: Dictionary = _dictionary(_card_effect_batch_journal.get(transaction_id, {}))
		if not _card_effect_batch_binding_matches(existing, binding):
			return _card_effect_batch_failure(binding, "transaction_intent_collision", "commit")
		var replay: Dictionary = _dictionary(existing.get("receipt", {}))
		replay["duplicate"] = true
		return replay
	if not bool(prepared.get("prepared", false)) or bool(prepared.get("replay_only", false)):
		return _card_effect_batch_failure(binding, "prepared_batch_invalid", "commit")
	if int(prepared.get("expected_flow_revision", -1)) != _flow_revision:
		return _card_effect_batch_failure(binding, "flow_revision_changed", "commit")
	if str(prepared.get("prepared_token", "")) != _card_effect_prepared_token(prepared):
		return _card_effect_batch_failure(binding, "prepared_token_invalid", "commit")
	var children: Array = prepared.get("prepared_children", []) if prepared.get("prepared_children", []) is Array else []
	var next_supplies := _pending_one_shot_supplies.duplicate(true)
	var next_supply_receipts := _one_shot_transaction_receipts.duplicate(true)
	var next_demands := _pending_one_shot_demands.duplicate(true)
	var next_demand_receipts := _one_shot_demand_transaction_receipts.duplicate(true)
	var child_receipts: Array = []
	for child_variant in children:
		if not (child_variant is Dictionary):
			return _card_effect_batch_failure(binding, "prepared_child_invalid", "commit")
		var child: Dictionary = child_variant
		var child_id := str(child.get("child_transaction_id", ""))
		var effect_kind := str(child.get("one_time_effect_kind", ""))
		if child_id.is_empty() or next_supplies.has(child_id) or next_demands.has(child_id) or next_supply_receipts.has(child_id) or next_demand_receipts.has(child_id):
			return _card_effect_batch_failure(binding, "child_transaction_conflict", "commit")
		var claim := {
			"transaction_id": child_id,
			"batch_transaction_id": transaction_id,
			"commodity_id": str(child.get("commodity_id", "")),
			"color": str(child.get("color", "")),
			"player_index": int(child.get("commodity_owner_player_index", -1)),
			"milliunits": int(child.get("milliunits", 0)),
			"planned_route_id": str(child.get("route_id", "")),
			"planned_source_factory_id": str(child.get("source_factory_id", "")),
			"planned_market_facility_id": str(child.get("market_facility_id", "")),
			"planned_route_mode_tags": (child.get("route_mode_tags", []) as Array).duplicate(true) if child.get("route_mode_tags", []) is Array else [],
			"planned_shortest_legal_distance": int(child.get("shortest_legal_distance", -1)),
			"planned_topology_revision": str(child.get("topology_revision", "")),
			"capacity_resource_ids": (child.get("capacity_resource_ids", []) as Array).duplicate(true) if child.get("capacity_resource_ids", []) is Array else [],
			"allocated_units": int(child.get("allocated_units", 0)),
		}
		var child_receipt := {
			"transaction_id": child_id,
			"batch_transaction_id": transaction_id,
			"accepted": true,
			"duplicate": false,
			"settled": false,
			"one_time_effect_kind": effect_kind,
			"commodity_id": str(child.get("commodity_id", "")),
			"allocated_milliunits": int(child.get("milliunits", 0)),
		}
		if effect_kind == "physical_supply":
			claim["installation_id"] = "one-shot:%s" % child_id
			claim["source_kind"] = "one_shot"
			claim["facility_id"] = str(child.get("source_factory_id", ""))
			claim["source_factory_id"] = str(child.get("source_factory_id", ""))
			claim["region_id"] = str(child.get("source_region_id", ""))
			child_receipt["sold_milliunits"] = 0
			child_receipt["stored_milliunits"] = 0
			child_receipt["lost_milliunits"] = 0
			next_supplies[child_id] = claim
			next_supply_receipts[child_id] = child_receipt
		elif effect_kind == "extra_demand":
			claim["installation_id"] = "one-shot-demand:%s" % child_id
			claim["source_kind"] = "one_shot_demand"
			claim["facility_id"] = str(child.get("market_facility_id", ""))
			claim["market_facility_id"] = str(child.get("market_facility_id", ""))
			claim["region_id"] = str(child.get("market_region_id", ""))
			child_receipt["consumed_milliunits"] = 0
			child_receipt["unfilled_milliunits"] = int(child.get("milliunits", 0))
			next_demands[child_id] = claim
			next_demand_receipts[child_id] = child_receipt
		else:
			return _card_effect_batch_failure(binding, "one_time_effect_kind_invalid", "commit")
		child_receipts.append(child_receipt.duplicate(true))
	_pending_one_shot_supplies = next_supplies
	_one_shot_transaction_receipts = next_supply_receipts
	_pending_one_shot_demands = next_demands
	_one_shot_demand_transaction_receipts = next_demand_receipts
	_flow_revision += 1
	var receipt := binding.duplicate(true)
	receipt["receipt_kind"] = "commodity_flow_card_effect_batch"
	receipt["committed"] = true
	receipt["duplicate"] = false
	receipt["rolled_back"] = false
	receipt["settled"] = false
	receipt["state"] = "pending_flow"
	receipt["finalized"] = false
	receipt["rollback_open"] = true
	receipt["reason_code"] = "committed"
	receipt["one_time_effect_kind"] = str(prepared.get("one_time_effect_kind", ""))
	receipt["child_receipts"] = child_receipts
	receipt["flow_revision"] = _flow_revision
	_card_effect_batch_journal[transaction_id] = {
		"transaction_id": transaction_id,
		"intent_hash": str(binding.get("intent_hash", "")),
		"plan_hash": str(binding.get("plan_hash", "")),
		"prepared_token": str(prepared.get("prepared_token", "")),
		"state": "pending_flow",
		"finalized": false,
		"rollback_open": true,
		"child_ids": _card_effect_child_ids(children),
		"children": children.duplicate(true),
		"receipt": receipt.duplicate(true),
	}
	return receipt


func finalize_card_effect_batch(receipt: Dictionary) -> Dictionary:
	var binding := _card_effect_batch_binding(receipt)
	var transaction_id := str(binding.get("transaction_id", ""))
	if not _card_effect_batch_binding_complete(binding):
		return _card_effect_batch_failure(binding, "batch_receipt_binding_invalid", "finalize")
	if not _card_effect_batch_journal.has(transaction_id):
		return _card_effect_batch_failure(binding, "batch_transaction_missing", "finalize")
	var journal: Dictionary = _dictionary(_card_effect_batch_journal.get(transaction_id, {}))
	if not _card_effect_batch_binding_matches(journal, binding):
		return _card_effect_batch_failure(binding, "batch_receipt_binding_invalid", "finalize")
	if str(journal.get("state", "")) == "rolled_back":
		return _card_effect_batch_failure(binding, "batch_already_rolled_back", "finalize")
	var stored_receipt: Dictionary = _dictionary(journal.get("receipt", {}))
	if bool(journal.get("finalized", false)):
		stored_receipt["duplicate"] = true
		stored_receipt["idempotent_replay"] = true
		return stored_receipt
	journal["finalized"] = true
	journal["rollback_open"] = false
	stored_receipt["finalized"] = true
	stored_receipt["rollback_open"] = false
	stored_receipt["duplicate"] = false
	stored_receipt["reason_code"] = "finalized" if str(journal.get("state", "")) == "pending_flow" else str(stored_receipt.get("reason_code", "settled"))
	journal["receipt"] = stored_receipt
	_card_effect_batch_journal[transaction_id] = journal
	return stored_receipt.duplicate(true)


func rollback_card_effect_batch(receipt: Dictionary) -> Dictionary:
	var binding := _card_effect_batch_binding(receipt)
	var transaction_id := str(binding.get("transaction_id", ""))
	if not _card_effect_batch_binding_complete(binding):
		return {"rolled_back": false, "committed": false, "reason_code": "batch_receipt_binding_invalid", "transaction_id": transaction_id}
	if not _card_effect_batch_journal.has(transaction_id):
		return {"rolled_back": false, "committed": false, "reason_code": "batch_transaction_missing", "transaction_id": transaction_id}
	var journal: Dictionary = _dictionary(_card_effect_batch_journal.get(transaction_id, {}))
	if not _card_effect_batch_binding_matches(journal, binding):
		return {"rolled_back": false, "committed": false, "reason_code": "batch_receipt_binding_invalid", "transaction_id": transaction_id}
	if _card_effect_batch_rollback_receipts.has(transaction_id):
		var replay: Dictionary = _dictionary(_card_effect_batch_rollback_receipts.get(transaction_id, {}))
		if not _card_effect_batch_binding_matches(replay, binding):
			return {"rolled_back": false, "committed": false, "reason_code": "batch_receipt_binding_invalid", "transaction_id": transaction_id}
		replay["duplicate"] = true
		return replay
	if not bool(journal.get("rollback_open", false)):
		return {
			"rolled_back": false,
			"committed": true,
			"reason_code": "batch_rollback_closed",
			"transaction_id": transaction_id,
		}
	if str(journal.get("state", "")) != "pending_flow":
		return {
			"rolled_back": false,
			"committed": str(journal.get("state", "")) == "settled",
			"reason_code": "batch_already_settled" if str(journal.get("state", "")) == "settled" else "batch_not_rollbackable",
			"transaction_id": transaction_id,
		}
	var next_supplies := _pending_one_shot_supplies.duplicate(true)
	var next_supply_receipts := _one_shot_transaction_receipts.duplicate(true)
	var next_demands := _pending_one_shot_demands.duplicate(true)
	var next_demand_receipts := _one_shot_demand_transaction_receipts.duplicate(true)
	for child_id_variant in journal.get("child_ids", []):
		var child_id := str(child_id_variant)
		if not next_supplies.has(child_id) and not next_demands.has(child_id):
			return {"rolled_back": false, "committed": true, "reason_code": "batch_no_longer_pending", "transaction_id": transaction_id}
		next_supplies.erase(child_id)
		next_supply_receipts.erase(child_id)
		next_demands.erase(child_id)
		next_demand_receipts.erase(child_id)
	_pending_one_shot_supplies = next_supplies
	_one_shot_transaction_receipts = next_supply_receipts
	_pending_one_shot_demands = next_demands
	_one_shot_demand_transaction_receipts = next_demand_receipts
	_flow_revision += 1
	var stored_receipt: Dictionary = _dictionary(journal.get("receipt", {}))
	stored_receipt["committed"] = false
	stored_receipt["rolled_back"] = true
	stored_receipt["settled"] = false
	stored_receipt["state"] = "rolled_back"
	stored_receipt["finalized"] = false
	stored_receipt["rollback_open"] = false
	stored_receipt["reason_code"] = "rolled_back"
	stored_receipt["flow_revision"] = _flow_revision
	journal["state"] = "rolled_back"
	journal["finalized"] = false
	journal["rollback_open"] = false
	journal["receipt"] = stored_receipt
	_card_effect_batch_journal[transaction_id] = journal
	var rollback_receipt := binding.duplicate(true)
	rollback_receipt["rolled_back"] = true
	rollback_receipt["committed"] = false
	rollback_receipt["duplicate"] = false
	rollback_receipt["reason_code"] = "rolled_back"
	rollback_receipt["flow_revision"] = _flow_revision
	_card_effect_batch_rollback_receipts[transaction_id] = rollback_receipt.duplicate(true)
	return rollback_receipt


func card_effect_batch_snapshot(transaction_id: String) -> Dictionary:
	var journal: Dictionary = _dictionary(_card_effect_batch_journal.get(transaction_id.strip_edges(), {}))
	return _dictionary(journal.get("receipt", {}))


func advance_world(delta_seconds: float, clock_pause: Dictionary = {}) -> Dictionary:
	if not _configured or _world_bridge == null:
		return {"advanced": false, "reason": "controller_or_bridge_not_ready", "receipt_count": 0}
	if delta_seconds <= 0.0:
		return {"advanced": false, "reason": "delta_not_positive", "receipt_count": 0}
	if bool(clock_pause.get("game_over", false)) or bool(clock_pause.get("time_paused", false)) or bool(clock_pause.get("global_blocked", false)):
		return {"advanced": false, "reason": "clock_paused", "receipt_count": 0}
	if not _world_bridge.has_method("capture_flow_facts") or not _world_bridge.has_method("apply_sale_receipt_batch"):
		return {"advanced": false, "reason": "world_bridge_api_missing", "receipt_count": 0}
	var facts_variant: Variant = _world_bridge.call("capture_flow_facts")
	var facts: Dictionary = _dictionary(facts_variant)
	if facts.is_empty() or not _is_pure_data(facts):
		return {"advanced": false, "reason": "world_facts_invalid", "receipt_count": 0}
	var delta_milliseconds := maxi(1, int(round(delta_seconds * 1000.0)))
	var plan := _build_flow_plan(delta_milliseconds, facts)
	if not bool(plan.get("valid", false)):
		return {"advanced": false, "reason": str(plan.get("reason", "flow_plan_invalid")), "receipt_count": 0}
	var batch := {
		"batch_id": str(plan.get("batch_id", "")),
		"ruleset_id": RULESET_ID,
		"flow_revision_before": _flow_revision,
		"settled_at": float(facts.get("game_time", 0.0)),
		"receipts": (plan.get("receipts", []) as Array).duplicate(true),
	}
	var apply_variant: Variant = _world_bridge.call("apply_sale_receipt_batch", batch)
	var apply_result: Dictionary = _dictionary(apply_variant)
	if not bool(apply_result.get("applied", false)):
		return {
			"advanced": false,
			"reason": str(apply_result.get("reason", "sale_receipt_batch_rejected")),
			"batch_id": str(batch.get("batch_id", "")),
			"receipt_count": 0,
		}
	_commit_flow_plan(plan)
	_record_weather_economic_telemetry(plan.get("receipts", []) as Array)
	var loss_events: Array = (plan.get("flow_loss_events", []) as Array).duplicate(true)
	if not loss_events.is_empty():
		flow_loss_batch_committed.emit(loss_events)
	if _world_bridge.has_method("notify_sale_receipt_batch_committed"):
		_world_bridge.call("notify_sale_receipt_batch_committed", batch)
	var committed := {
		"advanced": true,
		"reason": "",
		"batch_id": str(batch.get("batch_id", "")),
		"receipt_count": (plan.get("receipts", []) as Array).size(),
		"gross_value": int(plan.get("gross_value", 0)),
		"rent_value": int(plan.get("rent_value", 0)),
		"owner_net_cash": int(plan.get("owner_net_cash", 0)),
		"gdp_value": int(plan.get("gdp_value", 0)),
		"market_sold_milliunits": int(plan.get("market_sold_milliunits", 0)),
		"ambient_consumed_milliunits": int(plan.get("ambient_consumed_milliunits", 0)),
		"stored_milliunits": int(plan.get("stored_milliunits", 0)),
		"wasted_milliunits": int(plan.get("wasted_milliunits", 0)),
		"market_backlog_milliunits": _market_backlog_total(_market_backlog_by_key),
		"warehouse_destroyed_loss_milliunits": int(plan.get("warehouse_destroyed_loss_milliunits", 0)),
		"flow_revision": _flow_revision,
	}
	sale_receipt_batch_committed.emit(committed.duplicate(true))
	return committed


func _record_weather_economic_telemetry(receipts: Array) -> void:
	if _weather_telemetry_runtime_service == null or not is_instance_valid(_weather_telemetry_runtime_service) \
		or not _weather_telemetry_runtime_service.has_method("observe_public_metric"):
		return
	for receipt_variant in receipts:
		if not (receipt_variant is Dictionary):
			continue
		var receipt := receipt_variant as Dictionary
		var gdp_value := maxf(0.0, float(receipt.get("gdp_value", 0.0)))
		if gdp_value <= 0.0:
			continue
		var multiplier_by_event: Dictionary = {}
		for row_variant in _sanitize_weather_contributions(receipt.get("weather_contributions", [])):
			var row := row_variant as Dictionary
			var event_id := int(row.get("event_id", 0))
			if event_id <= 0:
				continue
			var multiplier := clampf(float(row.get("multiplier", 1.0)), WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX)
			multiplier_by_event[event_id] = float(multiplier_by_event.get(event_id, 1.0)) * multiplier
		for event_id_variant in multiplier_by_event.keys():
			var event_id := int(event_id_variant)
			var composite_multiplier := maxf(0.01, float(multiplier_by_event[event_id_variant]))
			var estimated_delta := gdp_value * (1.0 - 1.0 / composite_multiplier)
			if not is_zero_approx(estimated_delta):
				_weather_telemetry_runtime_service.call("observe_public_metric", event_id, "estimated_economic_delta", estimated_delta)


func installation_snapshot(installation_id: String) -> Dictionary:
	return (_installations[installation_id] as Dictionary).duplicate(true) if _installations.has(installation_id) else {}


func installations_snapshot(include_inactive := false) -> Array:
	var result: Array = []
	var installation_ids: Array = _installations.keys()
	installation_ids.sort()
	for installation_id_variant in installation_ids:
		var installation: Dictionary = _installations[installation_id_variant]
		if include_inactive or bool(installation.get("active", false)):
			result.append(installation.duplicate(true))
	return result


func public_installations_snapshot() -> Array:
	var result := installations_snapshot(false)
	for index in range(result.size()):
		var installation: Dictionary = result[index]
		installation.erase("installer_player_index")
		result[index] = installation
	return result


func warehouse_inventory_snapshot(viewer_index := -1) -> Array:
	var result: Array = []
	var bucket_ids: Array = _warehouse_inventory.keys()
	bucket_ids.sort()
	for bucket_id_variant in bucket_ids:
		var row: Dictionary = (_warehouse_inventory[bucket_id_variant] as Dictionary).duplicate(true)
		if viewer_index < 0 or int(row.get("owner_player_index", -1)) != viewer_index:
			row.erase("bucket_id")
			row.erase("owner_player_index")
			row.erase("source_installation_id")
			row.erase("source_factory_id")
			row.erase("batch_transaction_id")
			row.erase("storage_rent_debt_cents")
			row.erase("storage_rent_remainder")
			row.erase("storage_liability_kind")
		result.append(row)
	return result


func recent_sale_receipts_snapshot(viewer_index := -1) -> Array:
	var result: Array = []
	for receipt_variant in _recent_sale_receipts:
		var receipt: Dictionary = (receipt_variant as Dictionary).duplicate(true)
		receipt.erase("supply_batch_transaction_id")
		receipt.erase("demand_batch_transaction_id")
		receipt["weather_contributions"] = _sanitize_weather_contributions(receipt.get("weather_contributions", []))
		if viewer_index < 0:
			receipt.erase("commodity_owner")
			receipt.erase("economic_owner_kind")
			receipt.erase("owner_net_cash")
			receipt.erase("source_installation_id")
			receipt.erase("demand_installation_id")
			receipt.erase("source_factory_id")
			receipt.erase("observer_intents")
			receipt.erase("bankruptcy_causality")
			var public_rents: Array = []
			for rent_variant in receipt.get("rent_rows", []):
				var rent: Dictionary = (rent_variant as Dictionary).duplicate(true)
				rent.erase("recipient_player_index")
				public_rents.append(rent)
			receipt["rent_rows"] = public_rents
		elif int(receipt.get("commodity_owner", -1)) != viewer_index:
			receipt.erase("commodity_owner")
			receipt.erase("economic_owner_kind")
			receipt.erase("owner_net_cash")
			receipt.erase("source_installation_id")
			receipt.erase("demand_installation_id")
			receipt.erase("source_factory_id")
			receipt.erase("observer_intents")
			receipt.erase("bankruptcy_causality")
		result.append(receipt)
	return result


func public_market_backlog_snapshot() -> Dictionary:
	var rows: Array = []
	var keys: Array = _market_backlog_by_key.keys()
	keys.sort()
	for key_variant in keys:
		var record: Dictionary = _dictionary(_market_backlog_by_key.get(key_variant, {}))
		rows.append({
			"market_facility_id": str(record.get("market_facility_id", "")),
			"region_id": str(record.get("region_id", "")),
			"commodity_id": str(record.get("commodity_id", "")),
			"steady_demand_units_per_minute": _rounded_units_per_minute(int(record.get("steady_demand_rate_milliunits_per_minute", 0))),
			"unmet_backlog_units": _rounded_units(int(record.get("unmet_backlog_milliunits", 0))),
			"backlog_cap_units": _rounded_units(int(record.get("backlog_cap_milliunits", 0))),
			"maximum_recovery_units": _rounded_units(int(record.get("backlog_recovery_budget_milliunits", 0))),
			"public_revision": int(record.get("backlog_revision", 0)),
		})
	return {
		"available": _configured,
		"flow_revision": _flow_revision,
		"summary_label": "市场待满足需求",
		"rows": rows,
	}


func public_waste_summary_snapshot() -> Dictionary:
	var commodity_rows: Array = []
	var commodity_ids: Array = _cumulative_wasted_milliunits_by_commodity.keys()
	commodity_ids.sort()
	for commodity_id_variant in commodity_ids:
		commodity_rows.append({
			"commodity_id": str(commodity_id_variant),
			"cumulative_wasted_units": _rounded_units(int(_cumulative_wasted_milliunits_by_commodity.get(commodity_id_variant, 0))),
		})
	var region_rows: Array = []
	var region_ids: Array = _cumulative_wasted_milliunits_by_region.keys()
	region_ids.sort()
	for region_id_variant in region_ids:
		region_rows.append({
			"region_id": str(region_id_variant),
			"cumulative_wasted_units": _rounded_units(int(_cumulative_wasted_milliunits_by_region.get(region_id_variant, 0))),
		})
	return {
		"available": _configured,
		"flow_revision": _flow_revision,
		"waste_revision": _waste_revision,
		"summary_label": "浪费产能",
		"commodity_rows": commodity_rows,
		"region_rows": region_rows,
	}


func recent_actual_flow_snapshot(commodity_id := "") -> Dictionary:
	var rows: Array = []
	for event_variant in _recent_flow_events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		if not commodity_id.is_empty() and str(event.get("commodity_id", "")) != commodity_id:
			continue
		var projected := _public_actual_flow_event(event)
		if not projected.is_empty():
			rows.append(projected)
	return {
		"available": _configured,
		"public_revision": _flow_revision,
		"selected_commodity_id": commodity_id,
		"rows": rows,
	}


func public_actual_flow_snapshot(commodity_id := "") -> Dictionary:
	return recent_actual_flow_snapshot(commodity_id)


func _public_actual_flow_event(event: Dictionary) -> Dictionary:
	var internal_kind := str(event.get("internal_flow_kind", ""))
	var source_kind := str(event.get("source_kind", ""))
	var public_kind := ""
	var display_label := ""
	var from_region_id := str(event.get("source_region_id", ""))
	var to_region_id := ""
	match internal_kind:
		"market":
			public_kind = "warehouse_outbound" if source_kind == "warehouse" else "market_sale"
			display_label = "仓库出库" if source_kind == "warehouse" else "已售出"
			to_region_id = str(event.get("market_region_id", ""))
		"warehouse_inbound":
			public_kind = "warehouse_inbound"
			display_label = "已入库"
			to_region_id = str(event.get("warehouse_region_id", ""))
		"ambient":
			public_kind = "ambient_consumption"
			display_label = "区域基础消费"
			to_region_id = str(event.get("consuming_region_id", ""))
	if public_kind.is_empty():
		return {}
	var settled_at := maxf(0.0, float(event.get("settled_at", 0.0)))
	var transport_modes := _unique_sorted_strings(event.get("transport_modes", []))
	var is_ambient := public_kind == "ambient_consumption"
	return {
		"flow_event_id": str(event.get("flow_event_id", "")),
		"public_revision": maxi(0, int(event.get("public_revision", 0))),
		"commodity_id": str(event.get("commodity_id", "")),
		"from_region_id": from_region_id,
		"to_region_id": to_region_id,
		"flow_kind": public_kind,
		"display_label": display_label,
		"route_id": "" if is_ambient else str(event.get("route_id", "")),
		"transport_modes": [] if is_ambient else transport_modes,
		"delivered_units_band": _delivered_units_band(float(event.get("quantity_units", 0.0))),
		"capacity_limited": bool(event.get("capacity_limited", false)),
		"congested": bool(event.get("capacity_limited", false)),
		"last_active_world_effective": settled_at,
		"activity_state": "current_tick" if is_equal_approx(settled_at, _current_game_time) else "recent",
		"ambient_one_hop": is_ambient and str(event.get("ambient_kind", "")) == "ambient_adjacent_land_consumption",
		"low_emphasis": is_ambient,
	}


func _delivered_units_band(units: float) -> String:
	if units < 1.0:
		return "trace"
	if units <= 5.0:
		return "low"
	if units <= 20.0:
		return "medium"
	if units <= 50.0:
		return "high"
	return "bulk"


func recent_flow_loss_events_snapshot() -> Array:
	return _recent_flow_loss_events.duplicate(true)


func public_weather_contribution_snapshot() -> Dictionary:
	var rows: Array = _last_flow_metrics.get("weather_contributions", []) if _last_flow_metrics.get("weather_contributions", []) is Array else []
	return {
		"available": _configured and _weather_runtime_controller != null,
		"flow_revision": _flow_revision,
		"contributions": _sanitize_weather_contributions(rows),
		"owns_weather_state": false,
	}


func region_gdp_snapshot(region_id: String) -> Dictionary:
	var cutoff := _current_game_time - _observation_window_seconds
	var total_cents := 0
	var player_cents: Dictionary = {}
	var receipt_ids: Array = []
	for receipt_variant in _recent_sale_receipts:
		var receipt: Dictionary = receipt_variant
		if float(receipt.get("settled_at", 0.0)) < cutoff or str(receipt.get("market_region_id", "")) != region_id:
			continue
		var gdp_cents := maxi(0, int(receipt.get("gdp_value", 0)))
		total_cents += gdp_cents
		var player_key := str(int(receipt.get("commodity_owner", -1)))
		player_cents[player_key] = int(player_cents.get(player_key, 0)) + gdp_cents
		receipt_ids.append(str(receipt.get("receipt_id", "")))
	var scale_to_minute := 60.0 / _observation_window_seconds
	var player_per_minute_cents: Dictionary = {}
	for player_key_variant in player_cents.keys():
		player_per_minute_cents[str(player_key_variant)] = int(round(float(player_cents[player_key_variant]) * scale_to_minute))
	var per_minute_cents := int(round(float(total_cents) * scale_to_minute))
	return {
		"region_id": region_id,
		"observation_window_seconds": _observation_window_seconds,
		"region_gdp_per_minute_cents": per_minute_cents,
		"region_gdp_per_minute": int(round(float(per_minute_cents) / float(_currency_scale))),
		"player_gdp_per_minute_cents_by_index": player_per_minute_cents,
		"receipt_ids": receipt_ids,
	}


func public_regional_gdp_snapshot() -> Dictionary:
	var region_ids: Dictionary = {}
	for receipt_variant in _recent_sale_receipts:
		if receipt_variant is Dictionary:
			var region_id := str((receipt_variant as Dictionary).get("market_region_id", ""))
			if not region_id.is_empty():
				region_ids[region_id] = true
	var rows: Array = []
	var ordered_ids: Array = region_ids.keys()
	ordered_ids.sort()
	for region_id_variant in ordered_ids:
		var snapshot := region_gdp_snapshot(str(region_id_variant))
		rows.append({
			"region_id": str(region_id_variant),
			"observation_window_seconds": float(snapshot.get("observation_window_seconds", 0.0)),
			"commodity_gdp_per_minute": maxi(0, int(snapshot.get("region_gdp_per_minute", 0))),
		})
	return {"available": _configured, "visibility_scope": "public", "flow_revision": _flow_revision, "rows": rows}


func player_region_gdp_share_basis_points(player_index: int, region_id: String) -> int:
	var snapshot := region_gdp_snapshot(region_id)
	var total_cents := int(snapshot.get("region_gdp_per_minute_cents", 0))
	if total_cents <= 0:
		return 0
	var by_player: Dictionary = snapshot.get("player_gdp_per_minute_cents_by_index", {})
	return clampi(int(floor(float(int(by_player.get(str(player_index), 0))) * float(BASIS_POINTS) / float(total_cents))), 0, BASIS_POINTS)


func player_color_flow_snapshot(player_index: int) -> Dictionary:
	var color_ids: Array = PRODUCT_INDUSTRY_CATALOG.call("industry_ids") if PRODUCT_INDUSTRY_CATALOG != null and PRODUCT_INDUSTRY_CATALOG.has_method("industry_ids") else []
	var gdp_cents_by_color: Dictionary = {}
	for color_id_variant in color_ids:
		gdp_cents_by_color[str(color_id_variant)] = 0
	var cutoff := _current_game_time - _observation_window_seconds
	for receipt_variant in _recent_sale_receipts:
		var receipt: Dictionary = receipt_variant
		if float(receipt.get("settled_at", 0.0)) < cutoff or int(receipt.get("commodity_owner", -1)) != player_index:
			continue
		var color_id := str(receipt.get("color", ""))
		if gdp_cents_by_color.has(color_id):
			gdp_cents_by_color[color_id] = int(gdp_cents_by_color[color_id]) + maxi(0, int(receipt.get("gdp_value", 0)))
	var colors: Dictionary = {}
	var scale_to_minute := 60.0 / _observation_window_seconds
	for color_id_variant in color_ids:
		var color_id := str(color_id_variant)
		var per_minute_cents := int(round(float(int(gdp_cents_by_color.get(color_id, 0))) * scale_to_minute))
		var per_minute := int(round(float(per_minute_cents) / float(_currency_scale)))
		colors[color_id] = {
			"color": color_id,
			"gdp_per_minute_cents": per_minute_cents,
			"gdp_per_minute": per_minute,
		}
	return {
		"valid": true,
		"ruleset_id": RULESET_ID,
		"player_index": player_index,
		"observation_window_seconds": _observation_window_seconds,
		"colors": colors,
		"asset_recovery_observation_only": true,
	}


func card_effect_candidates_snapshot() -> Dictionary:
	if not _configured or _world_bridge == null or not _world_bridge.has_method("capture_flow_facts"):
		return {
			"valid": false,
			"reason_code": "world_facts_unavailable",
			"revision": _card_effect_candidate_snapshot_revision,
			"candidates": [],
		}
	var facts_variant: Variant = _world_bridge.call("capture_flow_facts")
	if not (facts_variant is Dictionary) or not _is_pure_data(facts_variant) or (facts_variant as Dictionary).is_empty():
		return {
			"valid": false,
			"reason_code": "world_facts_invalid",
			"revision": _card_effect_candidate_snapshot_revision,
			"candidates": [],
		}
	var build := _build_card_effect_candidates(facts_variant as Dictionary)
	if not bool(build.get("valid", false)):
		return {
			"valid": false,
			"reason_code": str(build.get("reason_code", "candidate_snapshot_invalid")),
			"revision": _card_effect_candidate_snapshot_revision,
			"candidates": [],
		}
	var candidates: Array = build.get("candidates", []) if build.get("candidates", []) is Array else []
	var fingerprint := _card_effect_candidates_fingerprint(candidates)
	if fingerprint != _card_effect_candidate_snapshot_fingerprint:
		_card_effect_candidate_snapshot_fingerprint = fingerprint
		_card_effect_candidate_snapshot_revision += 1
	return {
		"valid": true,
		"reason_code": "ready",
		"ruleset_id": RULESET_ID,
		"revision": _card_effect_candidate_snapshot_revision,
		"fingerprint": _card_effect_candidate_snapshot_fingerprint,
		"candidates": candidates.duplicate(true),
		"observation_window_seconds": _observation_window_seconds,
		"derived_from_authoritative_flow_state": true,
		"owns_candidate_state": false,
	}


func to_save_data() -> Dictionary:
	var installation_transaction_ids: Array = _installation_transaction_receipts.keys()
	installation_transaction_ids.sort()
	return {
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"commodity_flow_terms_version": COMMODITY_FLOW_TERMS_VERSION,
		"ambient_consumption_default_units_per_minute": _ambient_consumption_default_units_per_minute,
		"ambient_consumption_units_per_minute_by_commodity": _ambient_consumption_units_per_minute_by_commodity.duplicate(true),
		"ambient_consumption_value_basis_points": _ambient_consumption_value_basis_points,
		"market_backlog_horizon_seconds": _market_backlog_horizon_seconds,
		"market_backlog_recovery_extra_basis_points": _market_backlog_recovery_extra_basis_points,
		"flow_revision": _flow_revision,
		"installation_sequence": _installation_sequence,
		"receipt_sequence": _receipt_sequence,
		"batch_sequence": _batch_sequence,
		"current_game_time": _current_game_time,
		"installations": installations_snapshot(true),
		"installation_generation_by_key": _installation_generation_by_key.duplicate(true),
		"processed_installation_transaction_ids": installation_transaction_ids,
		"installation_transaction_receipts": _installation_transaction_receipts.duplicate(true),
		"installation_rollback_receipts": _installation_rollback_receipts.duplicate(true),
		"rate_remainders": _rate_remainders.duplicate(true),
		"pair_remainders": _pair_remainders.duplicate(true),
		"ambient_rate_remainders": _ambient_rate_remainders.duplicate(true),
		"ambient_fairness_cursor_by_region_commodity": _ambient_fairness_cursor_by_region_commodity.duplicate(true),
		"ambient_revision": _ambient_revision,
		"market_backlog_by_key": _market_backlog_by_key.duplicate(true),
		"wasted_continuous_milliunits_by_source": _wasted_continuous_milliunits_by_source.duplicate(true),
		"wasted_continuous_milliunits_per_minute_by_source": _wasted_continuous_milliunits_per_minute_by_source.duplicate(true),
		"cumulative_wasted_milliunits_by_source": _cumulative_wasted_milliunits_by_source.duplicate(true),
		"cumulative_wasted_milliunits_by_commodity": _cumulative_wasted_milliunits_by_commodity.duplicate(true),
		"cumulative_wasted_milliunits_by_region": _cumulative_wasted_milliunits_by_region.duplicate(true),
		"waste_revision": _waste_revision,
		"recent_flow_loss_events": _recent_flow_loss_events.duplicate(true),
		"recent_flow_events": _recent_flow_events.duplicate(true),
		"legacy_backpressure_migration_version": _legacy_backpressure_migration_version,
		"recent_sale_receipts": _recent_sale_receipts.duplicate(true),
		"warehouse_inventory": _warehouse_inventory.duplicate(true),
		"pending_one_shot_supplies": _pending_one_shot_supplies.duplicate(true),
		"one_shot_transaction_receipts": _one_shot_transaction_receipts.duplicate(true),
		"pending_one_shot_demands": _pending_one_shot_demands.duplicate(true),
		"one_shot_demand_transaction_receipts": _one_shot_demand_transaction_receipts.duplicate(true),
		"card_effect_batch_journal": _card_effect_batch_journal.duplicate(true),
		"card_effect_batch_rollback_receipts": _card_effect_batch_rollback_receipts.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var source_state_version := int(data.get("state_version", -1))
	var legacy_state := source_state_version == LEGACY_STATE_VERSION
	if not _is_pure_data(data) or not [LEGACY_STATE_VERSION, STATE_VERSION].has(source_state_version) or str(data.get("ruleset_id", "")) != RULESET_ID:
		return {"applied": false, "reason": "save_header_invalid"}
	if legacy_state:
		if int(data.get("local_baseline_terms_version", -1)) != 1:
			return {"applied": false, "reason": "legacy_backpressure_migration_source_invalid"}
		for new_field in [
			"market_backlog_by_key",
			"wasted_continuous_milliunits_by_source",
			"cumulative_wasted_milliunits_by_source",
			"cumulative_wasted_milliunits_by_commodity",
			"cumulative_wasted_milliunits_by_region",
		]:
			if data.has(new_field):
				return {"applied": false, "reason": "legacy_backpressure_migration_ambiguous"}
	elif int(data.get("commodity_flow_terms_version", -1)) != COMMODITY_FLOW_TERMS_VERSION \
		or int(data.get("ambient_consumption_default_units_per_minute", -1)) != _ambient_consumption_default_units_per_minute \
		or _dictionary(data.get("ambient_consumption_units_per_minute_by_commodity", {})) != _ambient_consumption_units_per_minute_by_commodity \
		or int(data.get("ambient_consumption_value_basis_points", -1)) != _ambient_consumption_value_basis_points \
		or int(data.get("market_backlog_horizon_seconds", -1)) != _market_backlog_horizon_seconds \
		or int(data.get("market_backlog_recovery_extra_basis_points", -1)) != _market_backlog_recovery_extra_basis_points:
		return {"applied": false, "reason": "commodity_flow_terms_mismatch"}
	elif data.has("backpressured_milliunits_by_source"):
		return {"applied": false, "reason": "legacy_backpressure_field_forbidden"}
	for forbidden_key in ["project_slots", "project_sequence", "generation_by_slot_id", "project_tombstones", "player_gdp_attribution_rows", "gdp_cashflow_remainder_by_source_id", "trade_route_damage"]:
		if data.has(forbidden_key):
			return {"applied": false, "reason": "legacy_project_state_rejected"}
	var prepared_installations: Dictionary = {}
	for installation_variant in data.get("installations", []):
		if not (installation_variant is Dictionary):
			return {"applied": false, "reason": "installation_record_invalid"}
		var installation: Dictionary = (installation_variant as Dictionary).duplicate(true)
		var installation_id := str(installation.get("installation_id", ""))
		if installation_id.is_empty() \
			or prepared_installations.has(installation_id) \
			or not VALID_DIRECTIONS.has(str(installation.get("direction", ""))) \
			or not _installation_owner_record_valid(installation):
			return {"applied": false, "reason": "installation_record_invalid"}
		prepared_installations[installation_id] = installation
	var prepared_transaction_receipts: Dictionary = {}
	var saved_transaction_receipts: Variant = data.get("installation_transaction_receipts", {})
	if saved_transaction_receipts is Dictionary and not (saved_transaction_receipts as Dictionary).is_empty():
		for transaction_id_variant in (saved_transaction_receipts as Dictionary).keys():
			var transaction_id := str(transaction_id_variant)
			var receipt_variant: Variant = (saved_transaction_receipts as Dictionary)[transaction_id_variant]
			if transaction_id.is_empty() or not (receipt_variant is Dictionary):
				return {"applied": false, "reason": "installation_transaction_receipt_invalid"}
			var receipt: Dictionary = (receipt_variant as Dictionary).duplicate(true)
			var receipt_installation: Dictionary = receipt.get("installation", {}) if receipt.get("installation", {}) is Dictionary else {}
			var finalized := bool(receipt.get("finalized", false))
			var rollback_open := bool(receipt.get("rollback_open", not finalized))
			if str(receipt.get("transaction_id", "")) != transaction_id \
				or not bool(receipt.get("committed", false)) \
				or str(receipt.get("receipt_kind", "commodity_installation")) != "commodity_installation" \
				or receipt_installation.is_empty() \
				or not _installation_owner_record_valid(receipt_installation) \
				or (str(receipt_installation.get("owner_kind", "player")) == "public" and str(receipt.get("request_fingerprint", "")).is_empty()) \
				or (finalized and rollback_open):
				return {"applied": false, "reason": "installation_transaction_receipt_invalid"}
			receipt["finalized"] = finalized
			receipt["rollback_open"] = rollback_open
			prepared_transaction_receipts[transaction_id] = receipt
	else:
		for transaction_id_variant in data.get("processed_installation_transaction_ids", []):
			var transaction_id := str(transaction_id_variant)
			if transaction_id.is_empty():
				return {"applied": false, "reason": "installation_transaction_id_invalid"}
			prepared_transaction_receipts[transaction_id] = {"transaction_id": transaction_id, "committed": true, "duplicate": false, "reason": "restored_exact_once_guard"}
	var prepared_rate_remainders := _dictionary(data.get("rate_remainders", {}))
	var prepared_pair_remainders := _dictionary(data.get("pair_remainders", {}))
	var prepared_ambient_remainders := _dictionary(data.get("ambient_rate_remainders", {}))
	var prepared_ambient_cursors := _dictionary(data.get("ambient_fairness_cursor_by_region_commodity", {}))
	if not _nonnegative_integer_dictionary(prepared_rate_remainders) \
		or not _nonnegative_integer_dictionary(prepared_pair_remainders) \
		or not _nonnegative_integer_dictionary(prepared_ambient_remainders) \
		or not _nonnegative_integer_dictionary(prepared_ambient_cursors):
		return {"applied": false, "reason": "fixed_point_remainder_invalid"}
	var prepared_market_backlog := _dictionary(data.get("market_backlog_by_key", {}))
	if not _market_backlog_state_valid(prepared_market_backlog):
		return {"applied": false, "reason": "market_backlog_state_invalid"}
	var prepared_wasted_current := _dictionary(data.get("wasted_continuous_milliunits_by_source", {}))
	var prepared_wasted_rates := _dictionary(data.get("wasted_continuous_milliunits_per_minute_by_source", {}))
	var prepared_cumulative_waste_by_source := _dictionary(data.get("cumulative_wasted_milliunits_by_source", {}))
	var prepared_cumulative_waste_by_commodity := _dictionary(data.get("cumulative_wasted_milliunits_by_commodity", {}))
	var prepared_cumulative_waste_by_region := _dictionary(data.get("cumulative_wasted_milliunits_by_region", {}))
	var legacy_backpressure := _dictionary(data.get("backpressured_milliunits_by_source", {})) if legacy_state else {}
	for waste_map in [
		prepared_wasted_current,
		prepared_wasted_rates,
		prepared_cumulative_waste_by_source,
		prepared_cumulative_waste_by_commodity,
		prepared_cumulative_waste_by_region,
		legacy_backpressure,
	]:
		if not _nonnegative_integer_dictionary(waste_map):
			return {"applied": false, "reason": "waste_state_invalid"}
	var prepared_recent_loss_events: Array = (data.get("recent_flow_loss_events", []) as Array).duplicate(true) if data.get("recent_flow_loss_events", []) is Array else []
	var prepared_recent_flow_events: Array = (data.get("recent_flow_events", []) as Array).duplicate(true) if data.get("recent_flow_events", []) is Array else []
	if not _is_pure_data(prepared_recent_loss_events) or not _is_pure_data(prepared_recent_flow_events):
		return {"applied": false, "reason": "recent_flow_event_state_invalid"}
	var prepared_recent_receipts: Array = []
	var recent_receipt_ids: Dictionary = {}
	for receipt_variant in data.get("recent_sale_receipts", []):
		if not (receipt_variant is Dictionary) or not _sale_receipt_save_record_valid(receipt_variant as Dictionary):
			return {"applied": false, "reason": "sale_receipt_record_invalid"}
		var receipt_id := str((receipt_variant as Dictionary).get("receipt_id", ""))
		if recent_receipt_ids.has(receipt_id):
			return {"applied": false, "reason": "sale_receipt_duplicate"}
		recent_receipt_ids[receipt_id] = true
		prepared_recent_receipts.append((receipt_variant as Dictionary).duplicate(true))
	var prepared_warehouse_inventory := _dictionary(data.get("warehouse_inventory", {}))
	for bucket_id_variant in prepared_warehouse_inventory.keys():
		var bucket_id := str(bucket_id_variant)
		var bucket_variant: Variant = prepared_warehouse_inventory[bucket_id_variant]
		if bucket_id.is_empty() or not (bucket_variant is Dictionary) or int((bucket_variant as Dictionary).get("milliunits", -1)) < 0 or str((bucket_variant as Dictionary).get("warehouse_industry_id", "")) != str((bucket_variant as Dictionary).get("color", "")):
			return {"applied": false, "reason": "warehouse_inventory_record_invalid"}
	var prepared_pending_one_shot := _dictionary(data.get("pending_one_shot_supplies", {}))
	var prepared_one_shot_receipts := _dictionary(data.get("one_shot_transaction_receipts", {}))
	var prepared_pending_one_shot_demands := _dictionary(data.get("pending_one_shot_demands", {}))
	var prepared_one_shot_demand_receipts := _dictionary(data.get("one_shot_demand_transaction_receipts", {}))
	var prepared_card_effect_batch_journal := _dictionary(data.get("card_effect_batch_journal", {}))
	var prepared_card_effect_batch_rollbacks := _dictionary(data.get("card_effect_batch_rollback_receipts", {}))
	var prepared_rollback_receipts := _dictionary(data.get("installation_rollback_receipts", {}))
	if not _is_pure_data(prepared_warehouse_inventory) \
		or not _is_pure_data(prepared_pending_one_shot) \
		or not _is_pure_data(prepared_one_shot_receipts) \
		or not _is_pure_data(prepared_pending_one_shot_demands) \
		or not _is_pure_data(prepared_one_shot_demand_receipts) \
		or not _is_pure_data(prepared_card_effect_batch_journal) \
		or not _is_pure_data(prepared_card_effect_batch_rollbacks) \
		or not _is_pure_data(prepared_rollback_receipts):
		return {"applied": false, "reason": "warehouse_or_one_shot_state_invalid"}
	var batch_state_validation := _validate_saved_card_effect_batch_state(
		prepared_pending_one_shot,
		prepared_one_shot_receipts,
		prepared_pending_one_shot_demands,
		prepared_one_shot_demand_receipts,
		prepared_card_effect_batch_journal,
		prepared_card_effect_batch_rollbacks
	)
	if not bool(batch_state_validation.get("valid", false)):
		return {"applied": false, "reason": str(batch_state_validation.get("reason", "card_effect_batch_state_invalid"))}
	var prepared_migration_version := maxi(0, int(data.get("legacy_backpressure_migration_version", 0)))
	if legacy_state:
		prepared_cumulative_waste_by_source = legacy_backpressure.duplicate(true)
		for source_id_variant in legacy_backpressure.keys():
			var source_id := str(source_id_variant)
			var amount := maxi(0, int(legacy_backpressure.get(source_id_variant, 0)))
			var installation: Dictionary = _dictionary(prepared_installations.get(source_id, {}))
			var commodity_id := str(installation.get("commodity_id", "legacy_unknown"))
			var region_id := str(installation.get("region_id", "legacy_unknown"))
			prepared_cumulative_waste_by_commodity[commodity_id] = int(prepared_cumulative_waste_by_commodity.get(commodity_id, 0)) + amount
			prepared_cumulative_waste_by_region[region_id] = int(prepared_cumulative_waste_by_region.get(region_id, 0)) + amount
		prepared_migration_version = LEGACY_BACKPRESSURE_MIGRATION_VERSION
	_installations = prepared_installations
	_installation_sequence = maxi(0, int(data.get("installation_sequence", 0)))
	_receipt_sequence = maxi(0, int(data.get("receipt_sequence", 0)))
	_batch_sequence = maxi(0, int(data.get("batch_sequence", 0)))
	_current_game_time = maxf(0.0, float(data.get("current_game_time", 0.0)))
	_flow_revision = maxi(0, int(data.get("flow_revision", 0)))
	_installation_generation_by_key = _dictionary(data.get("installation_generation_by_key", {}))
	_rate_remainders = prepared_rate_remainders
	_pair_remainders = prepared_pair_remainders
	_ambient_rate_remainders = prepared_ambient_remainders
	_ambient_fairness_cursor_by_region_commodity = prepared_ambient_cursors
	_ambient_revision = maxi(0, int(data.get("ambient_revision", 0)))
	_market_backlog_by_key = prepared_market_backlog
	_wasted_continuous_milliunits_by_source = prepared_wasted_current
	_wasted_continuous_milliunits_per_minute_by_source = prepared_wasted_rates
	_cumulative_wasted_milliunits_by_source = prepared_cumulative_waste_by_source
	_cumulative_wasted_milliunits_by_commodity = prepared_cumulative_waste_by_commodity
	_cumulative_wasted_milliunits_by_region = prepared_cumulative_waste_by_region
	_waste_revision = maxi(0, int(data.get("waste_revision", 0)))
	_recent_flow_loss_events = prepared_recent_loss_events
	_recent_flow_events = prepared_recent_flow_events
	_legacy_backpressure_migration_version = prepared_migration_version
	_recent_sale_receipts = prepared_recent_receipts
	_installation_transaction_receipts = prepared_transaction_receipts
	_installation_rollback_receipts = prepared_rollback_receipts
	_warehouse_inventory = prepared_warehouse_inventory
	_pending_one_shot_supplies = prepared_pending_one_shot
	_one_shot_transaction_receipts = prepared_one_shot_receipts
	_pending_one_shot_demands = prepared_pending_one_shot_demands
	_one_shot_demand_transaction_receipts = prepared_one_shot_demand_receipts
	_card_effect_batch_journal = prepared_card_effect_batch_journal
	_card_effect_batch_rollback_receipts = prepared_card_effect_batch_rollbacks
	return {
		"applied": true,
		"installation_count": _installations.size(),
		"warehouse_bucket_count": _warehouse_inventory.size(),
		"receipt_count": _recent_sale_receipts.size(),
		"flow_revision": _flow_revision,
		"migrated_legacy_backpressure": legacy_state,
		"legacy_backpressure_migration_version": _legacy_backpressure_migration_version,
	}


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"runtime_owner": "CommodityFlowRuntimeController",
		"ruleset_id": RULESET_ID,
		"state_version": STATE_VERSION,
		"commodity_flow_terms_version": COMMODITY_FLOW_TERMS_VERSION,
		"remote_route_value_basis_points": REMOTE_ROUTE_VALUE_BASIS_POINTS,
		"ambient_consumption_default_units_per_minute": _ambient_consumption_default_units_per_minute,
		"ambient_consumption_value_basis_points": _ambient_consumption_value_basis_points,
		"market_backlog_horizon_seconds": _market_backlog_horizon_seconds,
		"market_backlog_recovery_extra_basis_points": _market_backlog_recovery_extra_basis_points,
		"fixed_point_scale": FIXED_POINT_SCALE,
		"installation_count": installations_snapshot(false).size(),
		"inactive_installation_count": installations_snapshot(true).size() - installations_snapshot(false).size(),
		"installation_rollback_count": _installation_rollback_receipts.size(),
		"recent_sale_receipt_count": _recent_sale_receipts.size(),
		"warehouse_bucket_count": _warehouse_inventory.size(),
		"warehouse_stored_milliunits": _warehouse_inventory_total(_warehouse_inventory),
		"market_backlog_record_count": _market_backlog_by_key.size(),
		"market_backlog_milliunits": _market_backlog_total(_market_backlog_by_key),
		"wasted_continuous_milliunits": _dictionary_total(_wasted_continuous_milliunits_by_source),
		"cumulative_wasted_milliunits": _dictionary_total(_cumulative_wasted_milliunits_by_source),
		"ambient_revision": _ambient_revision,
		"waste_revision": _waste_revision,
		"pending_one_shot_count": _pending_one_shot_supplies.size(),
		"pending_one_shot_demand_count": _pending_one_shot_demands.size(),
		"card_effect_batch_transaction_count": _card_effect_batch_journal.size(),
		"card_effect_batch_pending_count": _card_effect_batch_state_count("pending_flow"),
		"card_effect_batch_settled_count": _card_effect_batch_state_count("settled"),
		"card_effect_batch_rollback_count": _card_effect_batch_state_count("rolled_back"),
		"flow_revision": _flow_revision,
		"current_game_time": _current_game_time,
		"distance_price_model": "base_x_1_plus_12pct_per_distance_after_adjacent_capped",
		"last_flow_metrics": _last_flow_metrics.duplicate(true),
		"weather_runtime_ready": _weather_runtime_controller != null,
		"owns_weather_state": false,
		"owns_installed_commodity_roster": true,
		"owns_fixed_point_flow": true,
		"owns_capacity_allocation": true,
		"owns_many_source_many_sink_allocation": true,
		"owns_market_backlog": true,
		"owns_ambient_consumption": true,
		"owns_waste_accounting": true,
		"owns_warehouse_inventory": true,
		"owns_warehouse_capacity_allocation": true,
		"owns_one_shot_overflow_loss": true,
		"owns_sale_receipt_ledger": true,
		"owns_cash_state": false,
		"owns_route_topology": false,
		"route_runtime_owner": "RouteNetworkRuntimeController",
		"ss06_03_route_transition_pending": false,
		"pure_data": _is_pure_data(to_save_data()),
	}


func _installation_weather_effect(installation: Dictionary, facility: Dictionary, region: Dictionary, direction: String) -> Dictionary:
	var region_index := _weather_region_index(region)
	var identity := {
		"region_index": region_index,
		"multiplier": 1.0,
		"contributions": [],
	}
	if _weather_runtime_controller == null or region_index < 0 or PRODUCT_INDUSTRY_CATALOG == null:
		return identity
	var product_id := str(installation.get("commodity_id", ""))
	var product_tags: Array = PRODUCT_INDUSTRY_CATALOG.tags_for_product(product_id)
	if product_tags.is_empty():
		return identity
	var resistance := clampf(maxf(
		float(region.get("weather_resistance", 0.0)),
		maxf(float(facility.get("weather_resistance", 0.0)), float(installation.get("weather_resistance", 0.0)))
	), 0.0, 1.0)
	var exploitation := maxf(1.0, maxf(
		float(region.get("weather_exploitation_multiplier", 1.0)),
		maxf(float(facility.get("weather_exploitation_multiplier", 1.0)), float(installation.get("weather_exploitation_multiplier", 1.0)))
	))
	var snapshot := _weather_runtime_controller.region_effect_snapshot(region_index, {
		"product_tags": product_tags,
		"weather_resistance": resistance,
		"weather_exploitation_multiplier": exploitation,
	})
	var multiplier := 1.0
	var rows: Array = []
	for effect_variant in snapshot.get("effects", []):
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		var economy: Dictionary = effect.get("economy", {}) as Dictionary
		var production_multiplier := clampf(float(economy.get("production_multiplier", 1.0)), WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX)
		var demand_multiplier := clampf(float(economy.get("demand_multiplier", 1.0)), WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX)
		var direction_multiplier := production_multiplier if direction == "production" else demand_multiplier
		if is_equal_approx(direction_multiplier, 1.0):
			continue
		multiplier *= direction_multiplier
		rows.append({
			"kind": "weather_economy",
			"weather_id": str(effect.get("definition_id", "")),
			"weather_label": _weather_runtime_controller.label(str(effect.get("definition_id", ""))),
			"event_id": int(effect.get("event_id", 0)),
			"region_index": region_index,
			"phase": str(effect.get("phase", "")),
			"intensity": clampf(float(effect.get("intensity", 0.0)), 0.0, 1.0),
			"product_id": product_id,
			"direction": direction,
			"multiplier": direction_multiplier,
			"price_growth_multiplier": clampf(float(economy.get("price_growth_multiplier", 1.0)), WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX),
			"production_multiplier": production_multiplier,
			"demand_multiplier": demand_multiplier,
			"reason_codes": _string_array(effect.get("explanations", [])),
		})
	identity["multiplier"] = clampf(multiplier, WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX)
	identity["contributions"] = _sanitize_weather_contributions(rows)
	return identity


func _weather_region_index(region: Dictionary) -> int:
	for key in ["legacy_index", "district_index", "region_index", "index"]:
		if region.has(key):
			return int(region.get(key, -1))
	return -1


func _weather_contributions_from_rate_rows(rate_rows: Array) -> Array:
	var groups: Array = []
	for rate_variant in rate_rows:
		if rate_variant is Dictionary:
			groups.append((rate_variant as Dictionary).get("weather_contributions", []))
	return _merge_weather_contributions(groups)


func _merge_weather_contributions(groups: Array) -> Array:
	var rows: Array = []
	var seen: Dictionary = {}
	for group_variant in groups:
		for row_variant in _sanitize_weather_contributions(group_variant):
			var row: Dictionary = row_variant
			var key := "%s|%d|%d|%s|%s" % [
				str(row.get("weather_id", "")),
				int(row.get("event_id", 0)),
				int(row.get("region_index", -1)),
				str(row.get("product_id", "")),
				str(row.get("direction", "")),
			]
			if seen.has(key):
				continue
			seen[key] = true
			rows.append(row)
	return rows


func _sanitize_weather_contributions(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for row_variant in value:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		var clean: Dictionary = {}
		for key_variant in WEATHER_PUBLIC_CONTRIBUTION_KEYS:
			var key := str(key_variant)
			if row.has(key):
				clean[key] = row[key] if key != "reason_codes" else _string_array(row[key])
		result.append(clean)
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array or value is PackedStringArray:
		for item_variant in value:
			var item := str(item_variant).strip_edges()
			if not item.is_empty() and not result.has(item):
				result.append(item)
	return result


func _commodity_rate_map(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	for commodity_id_variant in (value as Dictionary).keys():
		var commodity_id := str(commodity_id_variant).strip_edges()
		var rate := maxi(0, int((value as Dictionary).get(commodity_id_variant, 0)))
		if not commodity_id.is_empty() and rate > 0:
			result[commodity_id] = rate
	return result


func _rounded_units(milliunits: int) -> float:
	return snappedf(float(maxi(0, milliunits)) / float(FIXED_POINT_SCALE), 0.001)


func _rounded_units_per_minute(milliunits_per_minute: int) -> float:
	return snappedf(float(maxi(0, milliunits_per_minute)) / float(FIXED_POINT_SCALE), 0.001)


func _market_backlog_key(market_facility_id: String, commodity_id: String) -> String:
	return "%s|%s" % [market_facility_id, commodity_id]


func _market_backlog_total(records: Dictionary) -> int:
	var total := 0
	for record_variant in records.values():
		if record_variant is Dictionary:
			total += maxi(0, int((record_variant as Dictionary).get("unmet_backlog_milliunits", 0)))
	return total


func _market_backlog_state_valid(records: Dictionary) -> bool:
	for key_variant in records.keys():
		var key := str(key_variant)
		var record_variant: Variant = records.get(key_variant, {})
		if key.is_empty() or not (record_variant is Dictionary):
			return false
		var record: Dictionary = record_variant
		var market_facility_id := str(record.get("market_facility_id", ""))
		var commodity_id := str(record.get("commodity_id", ""))
		if market_facility_id.is_empty() or commodity_id.is_empty() or key != _market_backlog_key(market_facility_id, commodity_id):
			return false
		for field_name in [
			"steady_demand_rate_milliunits_per_minute",
			"unmet_backlog_milliunits",
			"backlog_cap_milliunits",
			"backlog_recovery_budget_milliunits",
			"steady_due_remainder",
			"recovery_budget_remainder",
			"backlog_revision",
		]:
			if int(record.get(field_name, -1)) < 0:
				return false
		if int(record.get("unmet_backlog_milliunits", 0)) > int(record.get("backlog_cap_milliunits", 0)):
			return false
	return true


func _prune_market_backlog(records: Dictionary, facility_by_id: Dictionary, destroyed_facility_ids: Array) -> void:
	var keys: Array = records.keys()
	for key_variant in keys:
		var record: Dictionary = _dictionary(records.get(key_variant, {}))
		var market_facility_id := str(record.get("market_facility_id", ""))
		var facility: Dictionary = _dictionary(facility_by_id.get(market_facility_id, {}))
		if destroyed_facility_ids.has(market_facility_id) \
			or facility.is_empty() \
			or not bool(facility.get("active", false)) \
			or str(facility.get("facility_type", "")) != "market":
			records.erase(key_variant)


func _region_is_live(region: Dictionary) -> bool:
	if region.is_empty():
		return false
	if region.has("active") and not bool(region.get("active", false)):
		return false
	return not ["destroyed", "ruined", "retired"].has(str(region.get("lifecycle_state", "active")))


func _region_is_land(region: Dictionary) -> bool:
	var terrain_id := str(region.get("terrain_id", "")).to_lower()
	return not (terrain_id.contains("water") or terrain_id.contains("ocean") or terrain_id.contains("sea"))


func _proportional_cap_by_key(requested_by_key: Dictionary, capacity: int) -> Dictionary:
	var result: Dictionary = {}
	var keys: Array = requested_by_key.keys()
	keys.sort()
	var total_requested := 0
	for key_variant in keys:
		total_requested += maxi(0, int(requested_by_key.get(key_variant, 0)))
	if capacity <= 0 or total_requested <= 0:
		return result
	if total_requested <= capacity:
		for key_variant in keys:
			result[key_variant] = maxi(0, int(requested_by_key.get(key_variant, 0)))
		return result
	var assigned := 0
	var residual_rows: Array = []
	for key_variant in keys:
		var requested := maxi(0, int(requested_by_key.get(key_variant, 0)))
		var numerator := requested * capacity
		var granted := int(floor(float(numerator) / float(total_requested)))
		result[key_variant] = granted
		assigned += granted
		residual_rows.append({"key": str(key_variant), "remainder": numerator % total_requested})
	residual_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_remainder := int(left.get("remainder", 0))
		var right_remainder := int(right.get("remainder", 0))
		return left_remainder > right_remainder if left_remainder != right_remainder else str(left.get("key", "")) < str(right.get("key", ""))
	)
	var residual := capacity - assigned
	for row_variant in residual_rows:
		if residual <= 0:
			break
		var key := str((row_variant as Dictionary).get("key", ""))
		if int(result.get(key, 0)) >= int(requested_by_key.get(key, 0)):
			continue
		result[key] = int(result.get(key, 0)) + 1
		residual -= 1
	return result


func _remaining_production_claims(production_claims: Array, used_by_source: Dictionary) -> Array:
	var result: Array = []
	for claim_variant in production_claims:
		if not (claim_variant is Dictionary):
			continue
		var claim: Dictionary = (claim_variant as Dictionary).duplicate(true)
		var source_id := str(claim.get("installation_id", ""))
		var remaining := maxi(0, int(claim.get("milliunits", 0)) - int(used_by_source.get(source_id, 0)))
		if remaining <= 0:
			continue
		claim["milliunits"] = remaining
		result.append(claim)
	return result


func _claim_by_id(claims: Array, claim_id: String) -> Dictionary:
	for claim_variant in claims:
		if claim_variant is Dictionary and str((claim_variant as Dictionary).get("installation_id", "")) == claim_id:
			return (claim_variant as Dictionary).duplicate(true)
	return {}


func _prune_recent_events(events: Array, cutoff: float) -> void:
	for event_index in range(events.size() - 1, -1, -1):
		if not (events[event_index] is Dictionary) or float((events[event_index] as Dictionary).get("settled_at", 0.0)) < cutoff:
			events.remove_at(event_index)


func _stamp_flow_events(events: Array, public_revision: int) -> void:
	for event_index in range(events.size()):
		if not (events[event_index] is Dictionary):
			continue
		var event: Dictionary = (events[event_index] as Dictionary).duplicate(true)
		event["flow_event_id"] = "commodity-flow-event-%010d-%04d" % [public_revision, event_index + 1]
		event["public_revision"] = public_revision
		events[event_index] = event


func _route_available_milliunits(route: Dictionary, route_remaining_by_id: Dictionary, resource_remaining_by_id: Dictionary) -> int:
	var route_id := str(route.get("route_id", ""))
	if route_id.is_empty() or not route_remaining_by_id.has(route_id):
		return 0
	var available := mini(
		maxi(0, int(route.get("capacity_milliunits", 0))),
		maxi(0, int(route_remaining_by_id.get(route_id, 0)))
	)
	return mini(available, _route_capacity_resource_limit(route, resource_remaining_by_id, available))


func _consume_route_capacity(route: Dictionary, route_remaining_by_id: Dictionary, resource_remaining_by_id: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	var route_id := str(route.get("route_id", ""))
	if not route_id.is_empty():
		route_remaining_by_id[route_id] = maxi(0, int(route_remaining_by_id.get(route_id, 0)) - amount)
	_consume_route_capacity_resources(route, resource_remaining_by_id, amount)


func _scale_market_rate_groups_to_facility_capacity(groups: Dictionary, facility_by_id: Dictionary, region_by_id: Dictionary) -> void:
	var keys_by_facility: Dictionary = {}
	for key_variant in groups.keys():
		var group: Dictionary = _dictionary(groups.get(key_variant, {}))
		var facility_id := str(group.get("market_facility_id", ""))
		if not keys_by_facility.has(facility_id):
			keys_by_facility[facility_id] = []
		(keys_by_facility[facility_id] as Array).append(str(key_variant))
	var facility_ids: Array = keys_by_facility.keys()
	facility_ids.sort()
	for facility_id_variant in facility_ids:
		var facility_id := str(facility_id_variant)
		var facility: Dictionary = _dictionary(facility_by_id.get(facility_id, {}))
		var region: Dictionary = _dictionary(region_by_id.get(str(facility.get("region_id", "")), {}))
		if facility.is_empty() or not _region_is_live(region):
			continue
		var rank := clampi(int(facility.get("rank", 1)), 1, 4)
		var integrity_bp := clampi(int(region.get("integrity_basis_points", BASIS_POINTS)), 0, BASIS_POINTS)
		var capacity_rate := int(floor(
			float(int(_factory_market_capacity_by_rank.get(rank, 0)) * FIXED_POINT_SCALE)
			* float(integrity_bp)
			/ float(BASIS_POINTS)
		))
		var requested: Dictionary = {}
		for key_variant in keys_by_facility.get(facility_id, []):
			var group: Dictionary = _dictionary(groups.get(key_variant, {}))
			requested[str(key_variant)] = maxi(0, int(group.get("current_rate_milliunits_per_minute", 0)))
		var capped := _proportional_cap_by_key(requested, capacity_rate)
		for key_variant in keys_by_facility.get(facility_id, []):
			var key := str(key_variant)
			var group: Dictionary = _dictionary(groups.get(key, {}))
			group["current_rate_milliunits_per_minute"] = maxi(0, int(capped.get(key, 0)))
			groups[key] = group


func _market_processing_capacity_milliunits(
	facility: Dictionary,
	region: Dictionary,
	delta_milliseconds: int,
	rate_remainders: Dictionary
) -> int:
	if facility.is_empty() or not _region_is_live(region):
		return 0
	var rank := clampi(int(facility.get("rank", 1)), 1, 4)
	var integrity_bp := clampi(int(region.get("integrity_basis_points", BASIS_POINTS)), 0, BASIS_POINTS)
	var rate_milliunits_per_minute := int(floor(
		float(int(_factory_market_capacity_by_rank.get(rank, 0)) * FIXED_POINT_SCALE)
		* float(integrity_bp)
		/ float(BASIS_POINTS)
	))
	var remainder_key := "market-processing:%s" % str(facility.get("facility_id", ""))
	var numerator := int(rate_remainders.get(remainder_key, 0)) + rate_milliunits_per_minute * delta_milliseconds
	var capacity := int(floor(float(numerator) / float(MILLISECONDS_PER_MINUTE)))
	rate_remainders[remainder_key] = numerator % MILLISECONDS_PER_MINUTE
	return capacity


func _build_market_requests(
	delta_milliseconds: int,
	facts: Dictionary,
	market_rate_groups: Dictionary,
	market_backlog: Dictionary,
	rate_remainders: Dictionary,
	pending_one_shot_demands: Dictionary
) -> Dictionary:
	var steady_by_commodity: Dictionary = {}
	var recovery_by_commodity: Dictionary = {}
	var one_shot_by_commodity: Dictionary = {}
	var facility_by_id := _index_by_id(facts.get("facilities", []), "facility_id")
	var region_by_id := _index_by_id(facts.get("regions", []), "region_id")
	var valid_keys: Dictionary = {}
	var keys_by_facility: Dictionary = {}
	var group_keys: Array = market_rate_groups.keys()
	group_keys.sort()
	for key_variant in group_keys:
		var key := str(key_variant)
		var group: Dictionary = _dictionary(market_rate_groups.get(key, {}))
		var market_facility_id := str(group.get("market_facility_id", ""))
		var commodity_id := str(group.get("commodity_id", ""))
		if market_facility_id.is_empty() or commodity_id.is_empty():
			continue
		valid_keys[key] = true
		if not keys_by_facility.has(market_facility_id):
			keys_by_facility[market_facility_id] = []
		(keys_by_facility[market_facility_id] as Array).append(key)
		var old_record: Dictionary = _dictionary(market_backlog.get(key, {}))
		var old_backlog := maxi(0, int(old_record.get("unmet_backlog_milliunits", 0)))
		var current_rate := maxi(0, int(group.get("current_rate_milliunits_per_minute", 0)))
		var normal_rate := maxi(0, int(group.get("normal_rate_milliunits_per_minute", 0)))
		var calculated_cap := int(floor(float(normal_rate) * float(_market_backlog_horizon_seconds) / 60.0))
		var backlog_cap := maxi(calculated_cap, old_backlog)
		var steady_numerator := maxi(0, int(old_record.get("steady_due_remainder", 0))) + current_rate * delta_milliseconds
		var steady_due := int(floor(float(steady_numerator) / float(MILLISECONDS_PER_MINUTE)))
		var recovery_denominator := MILLISECONDS_PER_MINUTE * BASIS_POINTS
		var recovery_numerator := maxi(0, int(old_record.get("recovery_budget_remainder", 0))) \
			+ current_rate * _market_backlog_recovery_extra_basis_points * delta_milliseconds
		var recovery_rate_budget := int(floor(float(recovery_numerator) / float(recovery_denominator)))
		market_backlog[key] = {
			"market_facility_id": market_facility_id,
			"region_id": str(group.get("region_id", "")),
			"commodity_id": commodity_id,
			"color": str(group.get("color", "")),
			"installation_ids": (group.get("installation_ids", []) as Array).duplicate(true),
			"steady_demand_rate_milliunits_per_minute": current_rate,
			"normal_demand_rate_milliunits_per_minute": normal_rate,
			"unmet_backlog_milliunits": old_backlog,
			"backlog_cap_milliunits": backlog_cap,
			"backlog_recovery_budget_milliunits": 0,
			"steady_due_remainder": steady_numerator % MILLISECONDS_PER_MINUTE,
			"recovery_budget_remainder": recovery_numerator % recovery_denominator,
			"backlog_revision": maxi(0, int(old_record.get("backlog_revision", 0))),
			"steady_due_milliunits": steady_due,
			"backlog_before_tick_milliunits": old_backlog,
			"recovery_rate_budget_milliunits": recovery_rate_budget,
			"weather_contributions": _sanitize_weather_contributions(group.get("weather_contributions", [])),
		}
	var saved_keys: Array = market_backlog.keys()
	for key_variant in saved_keys:
		if not valid_keys.has(str(key_variant)):
			market_backlog.erase(key_variant)
	var pending_by_facility: Dictionary = {}
	var pending_ids: Array = pending_one_shot_demands.keys()
	pending_ids.sort()
	for transaction_id_variant in pending_ids:
		var claim: Dictionary = _dictionary(pending_one_shot_demands.get(transaction_id_variant, {}))
		var market_facility_id := str(claim.get("market_facility_id", claim.get("facility_id", "")))
		if market_facility_id.is_empty():
			continue
		if not pending_by_facility.has(market_facility_id):
			pending_by_facility[market_facility_id] = []
		(pending_by_facility[market_facility_id] as Array).append(claim)
	var facility_ids: Array = keys_by_facility.keys()
	for facility_id_variant in pending_by_facility.keys():
		if not facility_ids.has(facility_id_variant):
			facility_ids.append(facility_id_variant)
	facility_ids.sort()
	for facility_id_variant in facility_ids:
		var facility_id := str(facility_id_variant)
		var facility: Dictionary = _dictionary(facility_by_id.get(facility_id, {}))
		var region: Dictionary = _dictionary(region_by_id.get(str(facility.get("region_id", "")), {}))
		if facility.is_empty() \
			or not bool(facility.get("active", false)) \
			or str(facility.get("facility_type", "")) != "market" \
			or not _region_is_live(region):
			continue
		var processing_capacity := _market_processing_capacity_milliunits(facility, region, delta_milliseconds, rate_remainders)
		var steady_requested: Dictionary = {}
		for key_variant in keys_by_facility.get(facility_id, []):
			var key := str(key_variant)
			var record: Dictionary = _dictionary(market_backlog.get(key, {}))
			steady_requested[key] = maxi(0, int(record.get("steady_due_milliunits", 0)))
		var steady_reserved := _proportional_cap_by_key(steady_requested, processing_capacity)
		var remaining_capacity := maxi(0, processing_capacity - _dictionary_total(steady_reserved))
		for key_variant in keys_by_facility.get(facility_id, []):
			var key := str(key_variant)
			var record: Dictionary = _dictionary(market_backlog.get(key, {}))
			var amount := maxi(0, int(steady_reserved.get(key, 0)))
			if amount <= 0:
				continue
			var commodity_id := str(record.get("commodity_id", ""))
			if not steady_by_commodity.has(commodity_id):
				steady_by_commodity[commodity_id] = []
			(steady_by_commodity[commodity_id] as Array).append(_market_demand_claim(record, key, "steady", amount))
		for one_shot_variant in pending_by_facility.get(facility_id, []):
			if remaining_capacity <= 0:
				break
			var one_shot: Dictionary = (one_shot_variant as Dictionary).duplicate(true)
			var amount := mini(maxi(0, int(one_shot.get("milliunits", 0))), remaining_capacity)
			if amount <= 0:
				continue
			one_shot["milliunits"] = amount
			one_shot["market_phase"] = "one_shot"
			var commodity_id := str(one_shot.get("commodity_id", ""))
			if not one_shot_by_commodity.has(commodity_id):
				one_shot_by_commodity[commodity_id] = []
			(one_shot_by_commodity[commodity_id] as Array).append(one_shot)
			remaining_capacity -= amount
		var recovery_requested: Dictionary = {}
		for key_variant in keys_by_facility.get(facility_id, []):
			var key := str(key_variant)
			var record: Dictionary = _dictionary(market_backlog.get(key, {}))
			recovery_requested[key] = mini(
				maxi(0, int(record.get("backlog_before_tick_milliunits", 0))),
				maxi(0, int(record.get("recovery_rate_budget_milliunits", 0)))
			)
		var recovery_reserved := _proportional_cap_by_key(recovery_requested, remaining_capacity)
		for key_variant in keys_by_facility.get(facility_id, []):
			var key := str(key_variant)
			var record: Dictionary = _dictionary(market_backlog.get(key, {}))
			var amount := maxi(0, int(recovery_reserved.get(key, 0)))
			record["backlog_recovery_budget_milliunits"] = amount
			market_backlog[key] = record
			if amount <= 0:
				continue
			var commodity_id := str(record.get("commodity_id", ""))
			if not recovery_by_commodity.has(commodity_id):
				recovery_by_commodity[commodity_id] = []
			(recovery_by_commodity[commodity_id] as Array).append(_market_demand_claim(record, key, "recovery", amount))
	return {
		"steady_by_commodity": steady_by_commodity,
		"recovery_by_commodity": recovery_by_commodity,
		"one_shot_by_commodity": one_shot_by_commodity,
	}


func _market_demand_claim(record: Dictionary, backlog_key: String, phase: String, amount: int) -> Dictionary:
	return {
		"installation_id": "market-%s:%s" % [phase, backlog_key],
		"source_kind": "demand",
		"commodity_id": str(record.get("commodity_id", "")),
		"color": str(record.get("color", "")),
		"player_index": -1,
		"facility_id": str(record.get("market_facility_id", "")),
		"market_facility_id": str(record.get("market_facility_id", "")),
		"region_id": str(record.get("region_id", "")),
		"milliunits": maxi(0, amount),
		"market_phase": phase,
		"backlog_key": backlog_key,
		"weather_contributions": _sanitize_weather_contributions(record.get("weather_contributions", [])),
	}


func _apply_market_fulfillment(
	market_backlog: Dictionary,
	commodity_id: String,
	steady_demand_claims: Array,
	recovery_demand_claims: Array,
	used_by_demand: Dictionary
) -> void:
	var steady_id_by_key: Dictionary = {}
	for claim_variant in steady_demand_claims:
		if claim_variant is Dictionary and not str((claim_variant as Dictionary).get("backlog_key", "")).is_empty():
			steady_id_by_key[str((claim_variant as Dictionary).get("backlog_key", ""))] = str((claim_variant as Dictionary).get("installation_id", ""))
	var recovery_id_by_key: Dictionary = {}
	for claim_variant in recovery_demand_claims:
		if claim_variant is Dictionary and not str((claim_variant as Dictionary).get("backlog_key", "")).is_empty():
			recovery_id_by_key[str((claim_variant as Dictionary).get("backlog_key", ""))] = str((claim_variant as Dictionary).get("installation_id", ""))
	var keys: Array = market_backlog.keys()
	keys.sort()
	for key_variant in keys:
		var key := str(key_variant)
		var record: Dictionary = _dictionary(market_backlog.get(key, {}))
		if str(record.get("commodity_id", "")) != commodity_id:
			continue
		var old_backlog := maxi(0, int(record.get("backlog_before_tick_milliunits", record.get("unmet_backlog_milliunits", 0))))
		var steady_due := maxi(0, int(record.get("steady_due_milliunits", 0)))
		var steady_id := str(steady_id_by_key.get(key, ""))
		var recovery_id := str(recovery_id_by_key.get(key, ""))
		var fulfilled_steady := mini(steady_due, maxi(0, int(used_by_demand.get(steady_id, 0))))
		var fulfilled_recovery := mini(old_backlog, maxi(0, int(used_by_demand.get(recovery_id, 0))))
		var cap := maxi(0, int(record.get("backlog_cap_milliunits", 0)))
		record["unmet_backlog_milliunits"] = clampi(
			old_backlog - fulfilled_recovery + (steady_due - fulfilled_steady),
			0,
			cap
		)
		record["fulfilled_steady_milliunits"] = fulfilled_steady
		record["fulfilled_recovery_milliunits"] = fulfilled_recovery
		record["backlog_revision"] = maxi(0, int(record.get("backlog_revision", 0))) + 1
		record.erase("backlog_before_tick_milliunits")
		record.erase("recovery_rate_budget_milliunits")
		market_backlog[key] = record


func _initial_route_capacity_budgets(delta_milliseconds: int, facts: Dictionary) -> Dictionary:
	var route_remaining_by_id: Dictionary = {}
	var resource_remaining_by_id: Dictionary = {}
	for route_variant in facts.get("route_candidates", []):
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = route_variant
		var route_id := str(route.get("route_id", ""))
		if route_id.is_empty():
			continue
		var route_capacity := int(floor(
			float(maxi(0, int(route.get("bottleneck_units_per_minute", 0))) * FIXED_POINT_SCALE * delta_milliseconds)
			/ float(MILLISECONDS_PER_MINUTE)
		))
		if not route_remaining_by_id.has(route_id):
			route_remaining_by_id[route_id] = route_capacity
		else:
			route_remaining_by_id[route_id] = mini(int(route_remaining_by_id.get(route_id, 0)), route_capacity)
		for resource_variant in route.get("capacity_resources", []):
			if not (resource_variant is Dictionary):
				continue
			var resource: Dictionary = resource_variant
			var resource_id := str(resource.get("resource_id", ""))
			if resource_id.is_empty():
				continue
			var capacity := int(floor(
				float(maxi(0, int(resource.get("capacity_units_per_minute", 0))) * FIXED_POINT_SCALE * delta_milliseconds)
				/ float(MILLISECONDS_PER_MINUTE)
			))
			if not resource_remaining_by_id.has(resource_id):
				resource_remaining_by_id[resource_id] = capacity
			else:
				resource_remaining_by_id[resource_id] = mini(int(resource_remaining_by_id.get(resource_id, 0)), capacity)
	return {
		"route_remaining_by_id": route_remaining_by_id,
		"resource_remaining_by_id": resource_remaining_by_id,
	}


func _build_ambient_claims(delta_milliseconds: int, facts: Dictionary, ambient_remainders: Dictionary) -> Dictionary:
	var claims_by_commodity: Dictionary = {}
	var product_ids: Array = PRODUCT_INDUSTRY_CATALOG.call("product_ids") if PRODUCT_INDUSTRY_CATALOG.has_method("product_ids") else []
	product_ids.sort()
	var regions: Array = facts.get("regions", []) if facts.get("regions", []) is Array else []
	regions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("region_id", "")) < str(right.get("region_id", ""))
	)
	for region_variant in regions:
		if not (region_variant is Dictionary):
			continue
		var region: Dictionary = region_variant
		if not _region_is_live(region):
			continue
		var region_id := str(region.get("region_id", ""))
		for commodity_id_variant in product_ids:
			var commodity_id := str(commodity_id_variant)
			var rate_units_per_minute := maxi(
				0,
				int(_ambient_consumption_units_per_minute_by_commodity.get(
					commodity_id,
					_ambient_consumption_default_units_per_minute
				))
			)
			if rate_units_per_minute <= 0:
				continue
			var remainder_key := "%s|%s" % [region_id, commodity_id]
			var numerator := int(ambient_remainders.get(remainder_key, 0)) \
				+ rate_units_per_minute * FIXED_POINT_SCALE * delta_milliseconds
			var due := int(floor(float(numerator) / float(MILLISECONDS_PER_MINUTE)))
			ambient_remainders[remainder_key] = numerator % MILLISECONDS_PER_MINUTE
			if not claims_by_commodity.has(commodity_id):
				claims_by_commodity[commodity_id] = []
			(claims_by_commodity[commodity_id] as Array).append({
				"installation_id": "ambient:%s" % remainder_key,
				"commodity_id": commodity_id,
				"region_id": region_id,
				"milliunits": due,
			})
	return {"claims_by_commodity": claims_by_commodity}


func _ambient_source_eligible(source: Dictionary, ambient_claim: Dictionary, facts: Dictionary) -> bool:
	var source_region_id := str(source.get("region_id", ""))
	var consuming_region_id := str(ambient_claim.get("region_id", ""))
	if source_region_id.is_empty() or consuming_region_id.is_empty():
		return false
	var region_by_id := _index_by_id(facts.get("regions", []), "region_id")
	var source_region: Dictionary = _dictionary(region_by_id.get(source_region_id, {}))
	var consuming_region: Dictionary = _dictionary(region_by_id.get(consuming_region_id, {}))
	if not _region_is_live(source_region) or not _region_is_live(consuming_region):
		return false
	if source_region_id == consuming_region_id:
		return true
	if not _region_is_land(consuming_region):
		return false
	var consumer_neighbors: Array = consuming_region.get("neighbor_region_ids", []) if consuming_region.get("neighbor_region_ids", []) is Array else []
	var source_neighbors: Array = source_region.get("neighbor_region_ids", []) if source_region.get("neighbor_region_ids", []) is Array else []
	return consumer_neighbors.has(source_region_id) or source_neighbors.has(consuming_region_id)


func _build_flow_plan(delta_milliseconds: int, facts: Dictionary) -> Dictionary:
	var facility_by_id := _index_by_id(facts.get("facilities", []), "facility_id")
	var region_by_id := _index_by_id(facts.get("regions", []), "region_id")
	var destroyed_facility_ids: Array = facts.get("destroyed_facility_ids", []) if facts.get("destroyed_facility_ids", []) is Array else []
	var next_installations := _installations.duplicate(true)
	var next_rate_remainders := _rate_remainders.duplicate(true)
	var next_pair_remainders := _pair_remainders.duplicate(true)
	var next_ambient_rate_remainders := _ambient_rate_remainders.duplicate(true)
	var next_ambient_fairness_cursors := _ambient_fairness_cursor_by_region_commodity.duplicate(true)
	var next_market_backlog := _market_backlog_by_key.duplicate(true)
	var next_cumulative_waste_by_source := _cumulative_wasted_milliunits_by_source.duplicate(true)
	var next_cumulative_waste_by_commodity := _cumulative_wasted_milliunits_by_commodity.duplicate(true)
	var next_cumulative_waste_by_region := _cumulative_wasted_milliunits_by_region.duplicate(true)
	var next_warehouse_inventory := _warehouse_inventory.duplicate(true)
	var next_one_shot_receipts := _one_shot_transaction_receipts.duplicate(true)
	var next_pending_one_shot := _pending_one_shot_supplies.duplicate(true)
	var next_one_shot_demand_receipts := _one_shot_demand_transaction_receipts.duplicate(true)
	var next_pending_one_shot_demands := _pending_one_shot_demands.duplicate(true)
	var next_card_effect_batch_journal := _card_effect_batch_journal.duplicate(true)
	var destroyed_warehouse_loss := _prune_warehouse_inventory(next_warehouse_inventory, facility_by_id, destroyed_facility_ids)
	_prune_market_backlog(next_market_backlog, facility_by_id, destroyed_facility_ids)
	var accrued_warehouse_rent_cents := _accrue_warehouse_rent(delta_milliseconds, facts, next_warehouse_inventory)
	var total_base_by_facility: Dictionary = {}
	var installation_ids: Array = next_installations.keys()
	installation_ids.sort()
	for installation_id_variant in installation_ids:
		var installation: Dictionary = next_installations[installation_id_variant]
		if not bool(installation.get("active", false)):
			continue
		var facility_id := str(installation.get("facility_id", ""))
		if destroyed_facility_ids.has(facility_id):
			installation["active"] = false
			installation["removed_reason"] = "facility_destroyed"
			installation["removed_at"] = float(facts.get("game_time", 0.0))
			next_installations[installation_id_variant] = installation
			continue
		total_base_by_facility[facility_id] = int(total_base_by_facility.get(facility_id, 0)) + int(installation.get("base_units_per_minute", 0))
	var production_claims_by_commodity: Dictionary = {}
	var market_rate_groups: Dictionary = {}
	var effective_rate_rows: Array = []
	for installation_id_variant in installation_ids:
		var installation_id := str(installation_id_variant)
		var installation: Dictionary = next_installations[installation_id]
		if not bool(installation.get("active", false)):
			continue
		var facility_id := str(installation.get("facility_id", ""))
		if not facility_by_id.has(facility_id):
			continue
		var facility: Dictionary = facility_by_id[facility_id]
		var region_id := str(installation.get("region_id", facility.get("region_id", "")))
		var region: Dictionary = _dictionary(region_by_id.get(region_id, {}))
		if not _region_is_live(region) or not bool(facility.get("active", false)):
			continue
		var rank := clampi(int(facility.get("rank", 1)), 1, 4)
		var facility_capacity := int(_factory_market_capacity_by_rank.get(rank, 0))
		var facility_total_base := maxi(1, int(total_base_by_facility.get(facility_id, 0)))
		var capacity_bp := mini(BASIS_POINTS, int(floor(float(facility_capacity) * float(BASIS_POINTS) / float(facility_total_base))))
		var integrity_bp := clampi(int(region.get("integrity_basis_points", 0)), 0, BASIS_POINTS)
		var base_rate := maxi(0, int(installation.get("base_units_per_minute", 0)))
		var normal_rate_milli_per_minute := int(floor(float(base_rate * FIXED_POINT_SCALE) * float(capacity_bp) / float(BASIS_POINTS)))
		var baseline_rate_milli_per_minute := int(floor(float(normal_rate_milli_per_minute) * float(integrity_bp) / float(BASIS_POINTS)))
		var direction := str(installation.get("direction", ""))
		var weather_effect := _installation_weather_effect(installation, facility, region, direction)
		var weather_multiplier := clampf(float(weather_effect.get("multiplier", 1.0)), WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX)
		var weather_multiplier_bp := clampi(int(round(weather_multiplier * float(BASIS_POINTS))), int(WEATHER_ECONOMY_MULTIPLIER_MIN * BASIS_POINTS), int(WEATHER_ECONOMY_MULTIPLIER_MAX * BASIS_POINTS))
		var effective_rate_milli_per_minute := int(floor(float(baseline_rate_milli_per_minute) * float(weather_multiplier_bp) / float(BASIS_POINTS)))
		var commodity_id := str(installation.get("commodity_id", ""))
		if direction == "production":
			var numerator := int(next_rate_remainders.get(installation_id, 0)) + effective_rate_milli_per_minute * delta_milliseconds
			var emitted_milliunits := int(floor(float(numerator) / float(MILLISECONDS_PER_MINUTE)))
			next_rate_remainders[installation_id] = numerator % MILLISECONDS_PER_MINUTE
			if not production_claims_by_commodity.has(commodity_id):
				production_claims_by_commodity[commodity_id] = []
			(production_claims_by_commodity[commodity_id] as Array).append({
				"installation_id": installation_id,
				"source_kind": "continuous",
				"commodity_id": commodity_id,
				"color": str(installation.get("color", "")),
				"player_index": int(installation.get("installer_player_index", -1)),
				"facility_id": facility_id,
				"source_factory_id": facility_id,
				"region_id": region_id,
				"milliunits": emitted_milliunits,
				"weather_multiplier": weather_multiplier,
				"weather_contributions": _sanitize_weather_contributions(weather_effect.get("contributions", [])),
			})
		else:
			var backlog_key := _market_backlog_key(facility_id, commodity_id)
			var group: Dictionary = _dictionary(market_rate_groups.get(backlog_key, {}))
			if group.is_empty():
				group = {
					"market_facility_id": facility_id,
					"region_id": region_id,
					"commodity_id": commodity_id,
					"color": str(installation.get("color", "")),
					"current_rate_milliunits_per_minute": 0,
					"normal_rate_milliunits_per_minute": 0,
					"installation_ids": [],
					"weather_contributions": [],
				}
			group["current_rate_milliunits_per_minute"] = int(group.get("current_rate_milliunits_per_minute", 0)) + effective_rate_milli_per_minute
			group["normal_rate_milliunits_per_minute"] = int(group.get("normal_rate_milliunits_per_minute", 0)) + normal_rate_milli_per_minute
			(group["installation_ids"] as Array).append(installation_id)
			group["weather_contributions"] = _merge_weather_contributions([
				group.get("weather_contributions", []),
				weather_effect.get("contributions", []),
			])
			market_rate_groups[backlog_key] = group
		effective_rate_rows.append({
			"installation_id": installation_id,
			"region_index": int(weather_effect.get("region_index", -1)),
			"commodity_id": commodity_id,
			"direction": direction,
			"base_units_per_minute": base_rate,
			"capacity_basis_points": capacity_bp,
			"integrity_basis_points": integrity_bp,
			"baseline_milliunits_per_minute": baseline_rate_milli_per_minute,
			"weather_multiplier": weather_multiplier,
			"weather_contributions": _sanitize_weather_contributions(weather_effect.get("contributions", [])),
			"effective_milliunits_per_minute": effective_rate_milli_per_minute,
		})
	_scale_market_rate_groups_to_facility_capacity(market_rate_groups, facility_by_id, region_by_id)
	var market_requests := _build_market_requests(
		delta_milliseconds,
		facts,
		market_rate_groups,
		next_market_backlog,
		next_rate_remainders,
		next_pending_one_shot_demands
	)
	var steady_demand_by_commodity: Dictionary = market_requests.get("steady_by_commodity", {})
	var recovery_demand_by_commodity: Dictionary = market_requests.get("recovery_by_commodity", {})
	var one_shot_demand_by_commodity: Dictionary = market_requests.get("one_shot_by_commodity", {})
	var ambient_build := _build_ambient_claims(delta_milliseconds, facts, next_ambient_rate_remainders)
	var ambient_claims_by_commodity: Dictionary = ambient_build.get("claims_by_commodity", {})
	var warehouse_outflow := _warehouse_outflow_claims(delta_milliseconds, facts, next_warehouse_inventory)
	for commodity_id_variant in (warehouse_outflow.get("claims_by_commodity", {}) as Dictionary).keys():
		var commodity_id := str(commodity_id_variant)
		if not production_claims_by_commodity.has(commodity_id):
			production_claims_by_commodity[commodity_id] = []
		for claim_variant in (warehouse_outflow.get("claims_by_commodity", {}) as Dictionary)[commodity_id_variant]:
			(production_claims_by_commodity[commodity_id] as Array).append((claim_variant as Dictionary).duplicate(true))
	var pending_ids: Array = next_pending_one_shot.keys()
	pending_ids.sort()
	for transaction_id_variant in pending_ids:
		var one_shot: Dictionary = next_pending_one_shot[transaction_id_variant]
		var commodity_id := str(one_shot.get("commodity_id", ""))
		if commodity_id.is_empty():
			continue
		if not production_claims_by_commodity.has(commodity_id):
			production_claims_by_commodity[commodity_id] = []
		(production_claims_by_commodity[commodity_id] as Array).append(one_shot.duplicate(true))
	var receipts: Array = []
	var flow_events: Array = []
	var flow_loss_events: Array = []
	var wasted_current_by_source: Dictionary = {}
	var wasted_rate_by_source: Dictionary = {}
	var total_market_sold := 0
	var total_ambient_consumed := 0
	var total_wasted := 0
	var total_stored := 0
	var commodity_metrics: Array = []
	var warehouse_inbound_remaining := _warehouse_throughput_budget(delta_milliseconds, facts)
	var warehouse_outbound_remaining := _warehouse_throughput_budget(delta_milliseconds, facts)
	var route_budgets := _initial_route_capacity_budgets(delta_milliseconds, facts)
	var route_remaining_by_id: Dictionary = route_budgets.get("route_remaining_by_id", {})
	var route_remaining_by_resource: Dictionary = route_budgets.get("resource_remaining_by_id", {})
	for warehouse_id_variant in warehouse_outbound_remaining.keys():
		var warehouse_id := str(warehouse_id_variant)
		route_remaining_by_resource["warehouse-out:%s" % warehouse_id] = int(warehouse_outbound_remaining.get(warehouse_id_variant, 0))
	var commodity_ids: Array = production_claims_by_commodity.keys()
	for demand_map in [steady_demand_by_commodity, recovery_demand_by_commodity, one_shot_demand_by_commodity, ambient_claims_by_commodity]:
		for commodity_id_variant in (demand_map as Dictionary).keys():
			if not commodity_ids.has(commodity_id_variant):
				commodity_ids.append(commodity_id_variant)
	commodity_ids.sort()
	var next_receipt_sequence := _receipt_sequence
	for commodity_id_variant in commodity_ids:
		var commodity_id := str(commodity_id_variant)
		var production_claims: Array = (production_claims_by_commodity.get(commodity_id, []) as Array).duplicate(true)
		var steady_demand_claims: Array = (steady_demand_by_commodity.get(commodity_id, []) as Array).duplicate(true)
		for one_shot_variant in (one_shot_demand_by_commodity.get(commodity_id, []) as Array):
			steady_demand_claims.append((one_shot_variant as Dictionary).duplicate(true))
		var recovery_demand_claims: Array = (recovery_demand_by_commodity.get(commodity_id, []) as Array).duplicate(true)
		production_claims.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("installation_id", "")) < str(right.get("installation_id", "")))
		steady_demand_claims.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("installation_id", "")) < str(right.get("installation_id", "")))
		recovery_demand_claims.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("installation_id", "")) < str(right.get("installation_id", "")))
		var steady_plan := _allocate_commodity(
			commodity_id,
			production_claims,
			steady_demand_claims,
			delta_milliseconds,
			facts,
			next_pair_remainders,
			next_receipt_sequence,
			route_remaining_by_id,
			route_remaining_by_resource
		)
		next_receipt_sequence = int(steady_plan.get("next_receipt_sequence", next_receipt_sequence))
		for receipt_variant in steady_plan.get("receipts", []):
			receipts.append((receipt_variant as Dictionary).duplicate(true))
		for event_variant in steady_plan.get("flow_events", []):
			flow_events.append((event_variant as Dictionary).duplicate(true))
		var used_by_source: Dictionary = _dictionary(steady_plan.get("used_milliunits_by_source_id", {}))
		var used_by_demand: Dictionary = _dictionary(steady_plan.get("used_milliunits_by_demand_id", {}))
		var remaining_for_recovery := _remaining_production_claims(production_claims, used_by_source)
		var recovery_plan := _allocate_commodity(
			commodity_id,
			remaining_for_recovery,
			recovery_demand_claims,
			delta_milliseconds,
			facts,
			next_pair_remainders,
			next_receipt_sequence,
			route_remaining_by_id,
			route_remaining_by_resource
		)
		next_receipt_sequence = int(recovery_plan.get("next_receipt_sequence", next_receipt_sequence))
		for receipt_variant in recovery_plan.get("receipts", []):
			receipts.append((receipt_variant as Dictionary).duplicate(true))
		for event_variant in recovery_plan.get("flow_events", []):
			flow_events.append((event_variant as Dictionary).duplicate(true))
		_merge_claim_usage(used_by_source, recovery_plan.get("used_milliunits_by_source_id", {}))
		_merge_claim_usage(used_by_demand, recovery_plan.get("used_milliunits_by_demand_id", {}))
		var storage_rent_settled: Dictionary = _dictionary(steady_plan.get("storage_rent_settled_by_source_id", {}))
		_merge_claim_usage(storage_rent_settled, recovery_plan.get("storage_rent_settled_by_source_id", {}))
		_apply_market_fulfillment(
			next_market_backlog,
			commodity_id,
			steady_demand_claims,
			recovery_demand_claims,
			used_by_demand
		)
		var ambient_plan := _allocate_ambient(
			commodity_id,
			production_claims,
			used_by_source,
			(ambient_claims_by_commodity.get(commodity_id, []) as Array).duplicate(true),
			facts,
			next_pair_remainders,
			next_ambient_fairness_cursors,
			next_receipt_sequence
		)
		next_receipt_sequence = int(ambient_plan.get("next_receipt_sequence", next_receipt_sequence))
		for receipt_variant in ambient_plan.get("receipts", []):
			receipts.append((receipt_variant as Dictionary).duplicate(true))
		for event_variant in ambient_plan.get("flow_events", []):
			flow_events.append((event_variant as Dictionary).duplicate(true))
		_merge_claim_usage(used_by_source, ambient_plan.get("used_milliunits_by_source_id", {}))
		_consume_warehouse_outflow(
			next_warehouse_inventory,
			production_claims,
			used_by_source,
			storage_rent_settled
		)
		var storage := _store_unmatched_claims(
			commodity_id,
			production_claims,
			used_by_source,
			delta_milliseconds,
			facts,
			next_warehouse_inventory,
			warehouse_inbound_remaining,
			route_remaining_by_id,
			route_remaining_by_resource
		)
		for event_variant in storage.get("flow_events", []):
			flow_events.append((event_variant as Dictionary).duplicate(true))
		for loss_variant in storage.get("flow_loss_events", []):
			flow_loss_events.append((loss_variant as Dictionary).duplicate(true))
		var wasted_by_source: Dictionary = _dictionary(storage.get("wasted_by_source_id", {}))
		for source_id_variant in wasted_by_source.keys():
			var source_id := str(source_id_variant)
			var amount := maxi(0, int(wasted_by_source.get(source_id_variant, 0)))
			var claim := _claim_by_id(production_claims, source_id)
			var source_kind := str(claim.get("source_kind", ""))
			if source_kind == "continuous":
				wasted_current_by_source[source_id] = int(wasted_current_by_source.get(source_id, 0)) + amount
				wasted_rate_by_source[source_id] = int(round(float(amount) * float(MILLISECONDS_PER_MINUTE) / float(delta_milliseconds)))
			next_cumulative_waste_by_source[source_id] = int(next_cumulative_waste_by_source.get(source_id, 0)) + amount
			next_cumulative_waste_by_commodity[commodity_id] = int(next_cumulative_waste_by_commodity.get(commodity_id, 0)) + amount
			var source_region_id := str(claim.get("region_id", ""))
			next_cumulative_waste_by_region[source_region_id] = int(next_cumulative_waste_by_region.get(source_region_id, 0)) + amount
		total_stored += int(storage.get("stored_milliunits", 0))
		total_wasted += int(storage.get("wasted_milliunits", 0))
		total_market_sold += int((steady_plan.get("metrics", {}) as Dictionary).get("allocated_milliunits", 0))
		total_market_sold += int((recovery_plan.get("metrics", {}) as Dictionary).get("allocated_milliunits", 0))
		total_ambient_consumed += int(ambient_plan.get("allocated_milliunits", 0))
		_settle_one_shot_receipts(production_claims, used_by_source, storage, next_one_shot_receipts)
		_settle_one_shot_demand_receipts(steady_demand_claims, used_by_demand, next_one_shot_demand_receipts)
		var metric_row: Dictionary = (steady_plan.get("metrics", {}) as Dictionary).duplicate(true)
		metric_row["recovery_allocated_milliunits"] = int((recovery_plan.get("metrics", {}) as Dictionary).get("allocated_milliunits", 0))
		metric_row["ambient_consumed_milliunits"] = int(ambient_plan.get("allocated_milliunits", 0))
		metric_row["stored_milliunits"] = int(storage.get("stored_milliunits", 0))
		metric_row["wasted_milliunits"] = int(storage.get("wasted_milliunits", 0))
		commodity_metrics.append(metric_row)
	next_pending_one_shot.clear()
	next_pending_one_shot_demands.clear()
	_settle_card_effect_batch_journal(
		next_card_effect_batch_journal,
		next_one_shot_receipts,
		next_one_shot_demand_receipts
	)
	var next_recent_receipts := _recent_sale_receipts.duplicate(true)
	for receipt_variant in receipts:
		next_recent_receipts.append((receipt_variant as Dictionary).duplicate(true))
	var settled_at := float(facts.get("game_time", 0.0))
	var receipt_cutoff := settled_at - _observation_window_seconds
	for receipt_index in range(next_recent_receipts.size() - 1, -1, -1):
		if float((next_recent_receipts[receipt_index] as Dictionary).get("settled_at", 0.0)) < receipt_cutoff:
			next_recent_receipts.remove_at(receipt_index)
	_stamp_flow_events(flow_events, _flow_revision + 1)
	var next_recent_flow_events := _recent_flow_events.duplicate(true)
	for event_variant in flow_events:
		next_recent_flow_events.append((event_variant as Dictionary).duplicate(true))
	_prune_recent_events(next_recent_flow_events, receipt_cutoff)
	var next_recent_loss_events := _recent_flow_loss_events.duplicate(true)
	for loss_variant in flow_loss_events:
		next_recent_loss_events.append((loss_variant as Dictionary).duplicate(true))
	_prune_recent_events(next_recent_loss_events, receipt_cutoff)
	var totals := _receipt_totals(receipts)
	return {
		"valid": true,
		"batch_id": "commodity-flow-batch-%010d" % (_batch_sequence + 1),
		"next_batch_sequence": _batch_sequence + 1,
		"next_receipt_sequence": next_receipt_sequence,
		"next_installations": next_installations,
		"next_rate_remainders": next_rate_remainders,
		"next_pair_remainders": next_pair_remainders,
		"next_ambient_rate_remainders": next_ambient_rate_remainders,
		"next_ambient_fairness_cursor_by_region_commodity": next_ambient_fairness_cursors,
		"next_ambient_revision": _ambient_revision + 1,
		"next_market_backlog_by_key": next_market_backlog,
		"next_wasted_continuous_milliunits_by_source": wasted_current_by_source,
		"next_wasted_continuous_milliunits_per_minute_by_source": wasted_rate_by_source,
		"next_cumulative_wasted_milliunits_by_source": next_cumulative_waste_by_source,
		"next_cumulative_wasted_milliunits_by_commodity": next_cumulative_waste_by_commodity,
		"next_cumulative_wasted_milliunits_by_region": next_cumulative_waste_by_region,
		"next_waste_revision": _waste_revision + 1,
		"next_warehouse_inventory": next_warehouse_inventory,
		"next_pending_one_shot_supplies": next_pending_one_shot,
		"next_one_shot_transaction_receipts": next_one_shot_receipts,
		"next_pending_one_shot_demands": next_pending_one_shot_demands,
		"next_one_shot_demand_transaction_receipts": next_one_shot_demand_receipts,
		"next_card_effect_batch_journal": next_card_effect_batch_journal,
		"next_recent_sale_receipts": next_recent_receipts,
		"next_recent_flow_events": next_recent_flow_events,
		"next_recent_flow_loss_events": next_recent_loss_events,
		"settled_at": settled_at,
		"receipts": receipts,
		"flow_events": flow_events,
		"flow_loss_events": flow_loss_events,
		"gross_value": int(totals.get("gross_value", 0)),
		"rent_value": int(totals.get("rent_value", 0)),
		"owner_net_cash": int(totals.get("owner_net_cash", 0)),
		"gdp_value": int(totals.get("gdp_value", 0)),
		"market_sold_milliunits": total_market_sold,
		"ambient_consumed_milliunits": total_ambient_consumed,
		"stored_milliunits": total_stored,
		"wasted_milliunits": total_wasted,
		"warehouse_destroyed_loss_milliunits": destroyed_warehouse_loss,
		"accrued_warehouse_rent_cents": accrued_warehouse_rent_cents,
		"metrics": {
			"delta_milliseconds": delta_milliseconds,
			"effective_rate_rows": effective_rate_rows,
			"weather_contributions": _weather_contributions_from_rate_rows(effective_rate_rows),
			"commodity_rows": commodity_metrics,
			"sale_receipt_count": receipts.size(),
			"market_sold_milliunits": total_market_sold,
			"ambient_consumed_milliunits": total_ambient_consumed,
			"market_backlog_milliunits": _market_backlog_total(next_market_backlog),
			"warehouse_stored_milliunits": _warehouse_inventory_total(next_warehouse_inventory),
			"stored_this_tick_milliunits": total_stored,
			"wasted_milliunits": total_wasted,
			"warehouse_destroyed_loss_milliunits": destroyed_warehouse_loss,
			"accrued_warehouse_rent_cents": accrued_warehouse_rent_cents,
			"warehouse_transition_pending": false,
		},
	}


func _allocate_commodity(
	commodity_id: String,
	production_claims: Array,
	demand_claims: Array,
	delta_milliseconds: int,
	facts: Dictionary,
	pair_remainders: Dictionary,
	receipt_sequence_start: int,
	route_remaining_by_id: Dictionary,
	route_remaining_by_resource: Dictionary
) -> Dictionary:
	var total_production := _sum_claims(production_claims)
	var total_demand := _sum_claims(demand_claims)
	if total_production <= 0 or total_demand <= 0:
		return {
			"receipts": [],
			"flow_events": [],
			"next_receipt_sequence": receipt_sequence_start,
			"used_milliunits_by_source_id": {},
			"used_milliunits_by_demand_id": {},
			"storage_rent_settled_by_source_id": {},
			"metrics": {"commodity_id": commodity_id, "production_milliunits": total_production, "demand_milliunits": total_demand, "allocated_milliunits": 0},
		}
	var pair_rows: Array = []
	for production_variant in production_claims:
		var production: Dictionary = production_variant
		for demand_variant in demand_claims:
			var demand: Dictionary = demand_variant
			var route := _best_route(
				commodity_id,
				production,
				demand,
				delta_milliseconds,
				facts,
				route_remaining_by_id,
				route_remaining_by_resource
			)
			if route.is_empty():
				continue
			pair_rows.append({
				"pair_id": "%s>%s" % [str(production.get("installation_id", "")), str(demand.get("installation_id", ""))],
				"production": production,
				"demand": demand,
				"route": route,
				"weight": int(production.get("milliunits", 0)) * int(demand.get("milliunits", 0)),
			})
	pair_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("pair_id", "")) < str(right.get("pair_id", ""))
	)
	var target_milliunits := mini(total_production, total_demand)
	var allocations := _proportional_pair_allocations(
		pair_rows,
		target_milliunits,
		route_remaining_by_id,
		route_remaining_by_resource
	)
	var receipts: Array = []
	var flow_events: Array = []
	var used_production: Dictionary = {}
	var used_demand: Dictionary = {}
	var storage_rent_remaining_by_source: Dictionary = {}
	var storage_rent_settled_by_source: Dictionary = {}
	var allocated_total := 0
	var receipt_sequence := receipt_sequence_start
	for pair_index in range(pair_rows.size()):
		var allocated_milliunits := int(allocations.get(pair_index, 0))
		if allocated_milliunits <= 0:
			continue
		var pair: Dictionary = pair_rows[pair_index]
		var production: Dictionary = pair.get("production", {})
		var demand: Dictionary = pair.get("demand", {})
		var route: Dictionary = pair.get("route", {})
		var production_id := str(production.get("installation_id", ""))
		var demand_id := str(demand.get("installation_id", ""))
		used_production[production_id] = int(used_production.get(production_id, 0)) + allocated_milliunits
		used_demand[demand_id] = int(used_demand.get(demand_id, 0)) + allocated_milliunits
		allocated_total += allocated_milliunits
		var demand_phase := str(demand.get("market_phase", "one_shot"))
		flow_events.append({
			"internal_flow_kind": "market",
			"source_kind": str(production.get("source_kind", "")),
			"commodity_id": commodity_id,
			"source_region_id": str(production.get("region_id", "")),
			"market_region_id": str(demand.get("region_id", "")),
			"market_facility_id": str(demand.get("market_facility_id", demand.get("facility_id", ""))),
			"route_id": str(route.get("route_id", "")),
			"transport_modes": _unique_sorted_strings(route.get("mode_tags", [])),
			"quantity_units": float(allocated_milliunits) / float(FIXED_POINT_SCALE),
			"capacity_limited": allocated_milliunits < mini(
				maxi(0, int(production.get("milliunits", 0))),
				maxi(0, int(demand.get("milliunits", 0)))
			),
			"settled_at": float(facts.get("game_time", 0.0)),
		})
		var pair_id := str(pair.get("pair_id", ""))
		var sale_milliunits := int(pair_remainders.get(pair_id, 0)) + allocated_milliunits
		var whole_units := int(floor(float(sale_milliunits) / float(FIXED_POINT_SCALE)))
		pair_remainders[pair_id] = sale_milliunits % FIXED_POINT_SCALE
		if str(production.get("source_kind", "")) == "warehouse" and not storage_rent_remaining_by_source.has(production_id):
			storage_rent_remaining_by_source[production_id] = maxi(0, int(production.get("storage_rent_debt_cents", 0)))
			storage_rent_settled_by_source[production_id] = 0
		for _unit_index in range(whole_units):
			receipt_sequence += 1
			var requested_storage_rent_cents := 0
			if str(production.get("source_kind", "")) == "warehouse":
				requested_storage_rent_cents = mini(
					maxi(0, int(production.get("storage_rent_per_unit_cents", 0))),
					maxi(0, int(storage_rent_remaining_by_source.get(production_id, 0)))
				)
			var sale_receipt := _sale_receipt(receipt_sequence, commodity_id, production, demand, route, facts, requested_storage_rent_cents)
			sale_receipt["market_demand_phase"] = demand_phase
			if str(production.get("source_kind", "")) == "warehouse":
				var actual_storage_rent_cents := _storage_rent_in_receipt(sale_receipt, str(production.get("warehouse_id", "")))
				storage_rent_remaining_by_source[production_id] = int(storage_rent_remaining_by_source.get(production_id, 0)) - actual_storage_rent_cents
				storage_rent_settled_by_source[production_id] = int(storage_rent_settled_by_source.get(production_id, 0)) + actual_storage_rent_cents
			receipts.append(sale_receipt)
	return {
		"receipts": receipts,
		"flow_events": flow_events,
		"next_receipt_sequence": receipt_sequence,
		"used_milliunits_by_source_id": used_production,
		"used_milliunits_by_demand_id": used_demand,
		"storage_rent_settled_by_source_id": storage_rent_settled_by_source,
		"metrics": {
			"commodity_id": commodity_id,
			"production_milliunits": total_production,
			"demand_milliunits": total_demand,
			"allocated_milliunits": allocated_total,
			"pair_count": pair_rows.size(),
			"receipt_count": receipts.size(),
		},
	}


func _allocate_ambient(
	commodity_id: String,
	production_claims: Array,
	already_used_by_source: Dictionary,
	ambient_claims: Array,
	facts: Dictionary,
	pair_remainders: Dictionary,
	fairness_cursors: Dictionary,
	receipt_sequence_start: int
) -> Dictionary:
	var receipts: Array = []
	var flow_events: Array = []
	var used_by_source: Dictionary = {}
	var allocated_total := 0
	var receipt_sequence := receipt_sequence_start
	var remaining_by_source: Dictionary = {}
	var source_by_id: Dictionary = {}
	for source_variant in production_claims:
		if not (source_variant is Dictionary):
			continue
		var source: Dictionary = source_variant
		if str(source.get("source_kind", "")) == "warehouse":
			continue
		var source_id := str(source.get("installation_id", ""))
		var remaining := maxi(0, int(source.get("milliunits", 0)) - int(already_used_by_source.get(source_id, 0)))
		if source_id.is_empty() or remaining <= 0:
			continue
		remaining_by_source[source_id] = remaining
		source_by_id[source_id] = source
	ambient_claims.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("region_id", "")) < str(right.get("region_id", ""))
	)
	for claim_variant in ambient_claims:
		if not (claim_variant is Dictionary):
			continue
		var claim: Dictionary = claim_variant
		var due := maxi(0, int(claim.get("milliunits", 0)))
		if due <= 0:
			continue
		var eligible_source_ids: Array = []
		var eligible_total := 0
		var source_ids: Array = source_by_id.keys()
		source_ids.sort()
		for source_id_variant in source_ids:
			var source_id := str(source_id_variant)
			var source: Dictionary = source_by_id[source_id]
			var available := maxi(0, int(remaining_by_source.get(source_id, 0)))
			if available <= 0 or not _ambient_source_eligible(source, claim, facts):
				continue
			eligible_source_ids.append(source_id)
			eligible_total += available
		var target := mini(due, eligible_total)
		if target <= 0 or eligible_source_ids.is_empty():
			continue
		var allocations: Dictionary = {}
		var residual_rows: Array = []
		var assigned := 0
		for source_id_variant in eligible_source_ids:
			var source_id := str(source_id_variant)
			var available := maxi(0, int(remaining_by_source.get(source_id, 0)))
			var numerator := target * available
			var base := int(floor(float(numerator) / float(eligible_total)))
			allocations[source_id] = base
			assigned += base
			residual_rows.append({
				"source_id": source_id,
				"remainder": numerator % eligible_total,
			})
		residual_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_remainder := int(left.get("remainder", 0))
			var right_remainder := int(right.get("remainder", 0))
			return left_remainder > right_remainder if left_remainder != right_remainder else str(left.get("source_id", "")) < str(right.get("source_id", ""))
		)
		var cursor_key := "%s|%s" % [str(claim.get("region_id", "")), commodity_id]
		var residual := target - assigned
		var cursor := int(fairness_cursors.get(cursor_key, 0))
		if not residual_rows.is_empty() and residual > 0:
			for offset in range(residual_rows.size()):
				if residual <= 0:
					break
				var row_index := (cursor + offset) % residual_rows.size()
				var source_id := str((residual_rows[row_index] as Dictionary).get("source_id", ""))
				if int(allocations.get(source_id, 0)) >= int(remaining_by_source.get(source_id, 0)):
					continue
				allocations[source_id] = int(allocations.get(source_id, 0)) + 1
				residual -= 1
			fairness_cursors[cursor_key] = (cursor + (target - assigned)) % residual_rows.size()
		for source_id_variant in eligible_source_ids:
			var source_id := str(source_id_variant)
			var allocated := maxi(0, int(allocations.get(source_id, 0)))
			if allocated <= 0:
				continue
			var source: Dictionary = source_by_id[source_id]
			remaining_by_source[source_id] = maxi(0, int(remaining_by_source.get(source_id, 0)) - allocated)
			used_by_source[source_id] = int(used_by_source.get(source_id, 0)) + allocated
			allocated_total += allocated
			var trade_kind := "ambient_local_consumption" if str(source.get("region_id", "")) == str(claim.get("region_id", "")) else "ambient_adjacent_land_consumption"
			flow_events.append({
				"internal_flow_kind": "ambient",
				"ambient_kind": trade_kind,
				"commodity_id": commodity_id,
				"source_region_id": str(source.get("region_id", "")),
				"consuming_region_id": str(claim.get("region_id", "")),
				"quantity_units": float(allocated) / float(FIXED_POINT_SCALE),
				"capacity_limited": false,
				"settled_at": float(facts.get("game_time", 0.0)),
			})
			var remainder_key := "ambient:%s>%s|%s" % [source_id, str(claim.get("region_id", "")), commodity_id]
			var sale_milliunits := int(pair_remainders.get(remainder_key, 0)) + allocated
			var whole_units := int(floor(float(sale_milliunits) / float(FIXED_POINT_SCALE)))
			pair_remainders[remainder_key] = sale_milliunits % FIXED_POINT_SCALE
			for _unit_index in range(whole_units):
				receipt_sequence += 1
				receipts.append(_ambient_sale_receipt(receipt_sequence, trade_kind, commodity_id, source, claim, facts))
	return {
		"receipts": receipts,
		"flow_events": flow_events,
		"next_receipt_sequence": receipt_sequence,
		"used_milliunits_by_source_id": used_by_source,
		"allocated_milliunits": allocated_total,
	}


func _merge_claim_usage(target: Dictionary, additional_variant: Variant) -> void:
	if not (additional_variant is Dictionary):
		return
	for claim_id_variant in (additional_variant as Dictionary).keys():
		var claim_id := str(claim_id_variant)
		target[claim_id] = int(target.get(claim_id, 0)) + maxi(0, int((additional_variant as Dictionary)[claim_id_variant]))


func _proportional_pair_allocations(
	pair_rows: Array,
	target_milliunits: int,
	route_remaining: Dictionary,
	capacity_resource_remaining: Dictionary
) -> Dictionary:
	var allocations: Dictionary = {}
	if pair_rows.is_empty() or target_milliunits <= 0:
		return allocations
	var total_weight := 0
	for pair_variant in pair_rows:
		total_weight += maxi(0, int((pair_variant as Dictionary).get("weight", 0)))
	if total_weight <= 0:
		return allocations
	var production_remaining: Dictionary = {}
	var demand_remaining: Dictionary = {}
	var remainders: Array = []
	for pair_index in range(pair_rows.size()):
		var pair: Dictionary = pair_rows[pair_index]
		var production: Dictionary = pair.get("production", {})
		var demand: Dictionary = pair.get("demand", {})
		var route: Dictionary = pair.get("route", {})
		var production_id := str(production.get("installation_id", ""))
		var demand_id := str(demand.get("installation_id", ""))
		var route_id := str(route.get("route_id", ""))
		production_remaining[production_id] = int(production.get("milliunits", 0))
		demand_remaining[demand_id] = int(demand.get("milliunits", 0))
		if route_id.is_empty() or not route_remaining.has(route_id):
			allocations[pair_index] = 0
			continue
		var numerator := target_milliunits * int(pair.get("weight", 0))
		var ideal := int(floor(float(numerator) / float(total_weight)))
		allocations[pair_index] = ideal
		remainders.append({"pair_index": pair_index, "remainder": numerator % total_weight, "pair_id": str(pair.get("pair_id", ""))})
	var used_total := 0
	for pair_index in range(pair_rows.size()):
		var pair: Dictionary = pair_rows[pair_index]
		var production: Dictionary = pair.get("production", {})
		var demand: Dictionary = pair.get("demand", {})
		var route: Dictionary = pair.get("route", {})
		var production_id := str(production.get("installation_id", ""))
		var demand_id := str(demand.get("installation_id", ""))
		var route_id := str(route.get("route_id", ""))
		var endpoint_limit := mini(int(production_remaining.get(production_id, 0)), int(demand_remaining.get(demand_id, 0)))
		var route_limit := mini(int(route_remaining.get(route_id, 0)), _route_capacity_resource_limit(route, capacity_resource_remaining, target_milliunits))
		var granted := mini(int(allocations.get(pair_index, 0)), mini(endpoint_limit, route_limit))
		allocations[pair_index] = granted
		production_remaining[production_id] = int(production_remaining.get(production_id, 0)) - granted
		demand_remaining[demand_id] = int(demand_remaining.get(demand_id, 0)) - granted
		route_remaining[route_id] = int(route_remaining.get(route_id, 0)) - granted
		_consume_route_capacity_resources(route, capacity_resource_remaining, granted)
		used_total += granted
	remainders.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_remainder := int(left.get("remainder", 0))
		var right_remainder := int(right.get("remainder", 0))
		return left_remainder > right_remainder if left_remainder != right_remainder else str(left.get("pair_id", "")) < str(right.get("pair_id", ""))
	)
	var remaining := target_milliunits - used_total
	var made_progress := true
	while remaining > 0 and made_progress:
		made_progress = false
		for remainder_variant in remainders:
			if remaining <= 0:
				break
			var pair_index := int((remainder_variant as Dictionary).get("pair_index", -1))
			var pair: Dictionary = pair_rows[pair_index]
			var production: Dictionary = pair.get("production", {})
			var demand: Dictionary = pair.get("demand", {})
			var route: Dictionary = pair.get("route", {})
			var production_id := str(production.get("installation_id", ""))
			var demand_id := str(demand.get("installation_id", ""))
			var route_id := str(route.get("route_id", ""))
			var endpoint_remaining := mini(int(production_remaining.get(production_id, 0)), int(demand_remaining.get(demand_id, 0)))
			var route_limit := mini(int(route_remaining.get(route_id, 0)), _route_capacity_resource_limit(route, capacity_resource_remaining, remaining))
			var grant := mini(remaining, mini(endpoint_remaining, route_limit))
			if grant <= 0:
				continue
			allocations[pair_index] = int(allocations.get(pair_index, 0)) + grant
			production_remaining[production_id] = int(production_remaining.get(production_id, 0)) - grant
			demand_remaining[demand_id] = int(demand_remaining.get(demand_id, 0)) - grant
			route_remaining[route_id] = int(route_remaining.get(route_id, 0)) - grant
			_consume_route_capacity_resources(route, capacity_resource_remaining, grant)
			remaining -= grant
			made_progress = true
	return allocations


func _best_route(
	commodity_id: String,
	production: Dictionary,
	demand: Dictionary,
	delta_milliseconds: int,
	facts: Dictionary,
	route_remaining_by_id: Dictionary = {},
	route_remaining_by_resource: Dictionary = {}
) -> Dictionary:
	if not _card_effect_pair_binding_matches(production, demand):
		return {}
	var source_region_id := str(production.get("region_id", ""))
	var market_region_id := str(demand.get("region_id", ""))
	var price_cents := int((_dictionary(facts.get("price_cents_by_commodity", {}))).get(commodity_id, 0))
	if source_region_id.is_empty() or market_region_id.is_empty() or price_cents <= 0:
		return {}
	var candidates: Array = []
	for route_variant in facts.get("route_candidates", []):
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = route_variant
		if [commodity_id, "*"].has(str(route.get("commodity_id", ""))) and str(route.get("source_region_id", "")) == source_region_id and str(route.get("market_region_id", "")) == market_region_id:
			candidates.append(route.duplicate(true))
	var planned_route_id := str(_planned_card_effect_value(production, demand, "planned_route_id"))
	var planned_distance := int(_planned_card_effect_value(production, demand, "planned_shortest_legal_distance", -1))
	var planned_topology_revision := str(_planned_card_effect_value(production, demand, "planned_topology_revision"))
	var planned_modes := _unique_sorted_strings(_planned_card_effect_value(production, demand, "planned_route_mode_tags", []))
	if not planned_route_id.is_empty():
		for candidate_index in range(candidates.size() - 1, -1, -1):
			var candidate: Dictionary = candidates[candidate_index]
			var actual_topology := str(candidate.get("topology_revision", candidate.get("region_revision_fingerprint", "")))
			var actual_modes := _unique_sorted_strings(candidate.get("mode_tags", []))
			if str(candidate.get("route_id", "")) != planned_route_id \
				or int(candidate.get("shortest_legal_distance", -2)) != planned_distance \
				or actual_topology != planned_topology_revision \
				or actual_modes != planned_modes:
				candidates.remove_at(candidate_index)
	if candidates.is_empty():
		return {}
	var canonical_distance := 2147483647
	for candidate_variant in candidates:
		canonical_distance = mini(canonical_distance, maxi(0, int((candidate_variant as Dictionary).get("shortest_legal_distance", 0))))
	if canonical_distance == 2147483647:
		return {}
	for candidate_index in range(candidates.size()):
		var candidate: Dictionary = candidates[candidate_index]
		candidate["shortest_legal_distance"] = canonical_distance
		var distance := canonical_distance
		var premium_bp := _distance_premium_basis_points(distance)
		var gross_value := int(round(float(price_cents) * float(BASIS_POINTS + premium_bp) / float(BASIS_POINTS)))
		var rent_preview := _rent_rows(candidate.get("expected_rents", []), gross_value)
		candidate["expected_owner_net_cash"] = gross_value - int(rent_preview.get("total_rent", 0))
		var bottleneck_units_per_minute := maxi(0, int(candidate.get("bottleneck_units_per_minute", 0)))
		candidate["capacity_milliunits"] = int(floor(float(bottleneck_units_per_minute * FIXED_POINT_SCALE * delta_milliseconds) / float(MILLISECONDS_PER_MINUTE)))
		var resource_budgets: Array = []
		for resource_variant in candidate.get("capacity_resources", []):
			if not (resource_variant is Dictionary):
				continue
			var resource: Dictionary = resource_variant
			resource_budgets.append({
				"resource_id": str(resource.get("resource_id", "")),
				"capacity_milliunits": int(floor(float(maxi(0, int(resource.get("capacity_units_per_minute", 0))) * FIXED_POINT_SCALE * delta_milliseconds) / float(MILLISECONDS_PER_MINUTE))),
			})
		if str(production.get("source_kind", "")) == "warehouse":
			var outbound_resource_id := "warehouse-out:%s" % str(production.get("warehouse_id", ""))
			resource_budgets.append({
				"resource_id": outbound_resource_id,
				"capacity_milliunits": maxi(0, int(route_remaining_by_resource.get(outbound_resource_id, 0))),
			})
		candidate["capacity_resource_budgets"] = resource_budgets
		candidates[candidate_index] = candidate
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_net := int(left.get("expected_owner_net_cash", 0))
		var right_net := int(right.get("expected_owner_net_cash", 0))
		if left_net != right_net:
			return left_net > right_net
		var left_arrival := float(left.get("arrival_seconds", left.get("shortest_legal_distance", 0)))
		var right_arrival := float(right.get("arrival_seconds", right.get("shortest_legal_distance", 0)))
		if not is_equal_approx(left_arrival, right_arrival):
			return left_arrival < right_arrival
		var left_transfers := maxi(0, int(left.get("transfer_count", maxi(0, (left.get("ordered_legs", []) as Array).size() - 1))))
		var right_transfers := maxi(0, int(right.get("transfer_count", maxi(0, (right.get("ordered_legs", []) as Array).size() - 1))))
		if left_transfers != right_transfers:
			return left_transfers < right_transfers
		return str(left.get("route_id", "")) < str(right.get("route_id", ""))
	)
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		var route_id := str(candidate.get("route_id", ""))
		var route_available := maxi(0, int(candidate.get("capacity_milliunits", 0)))
		if not route_remaining_by_id.is_empty():
			route_available = mini(route_available, maxi(0, int(route_remaining_by_id.get(route_id, 0))))
		if not route_remaining_by_resource.is_empty():
			route_available = mini(route_available, _route_capacity_resource_limit(candidate, route_remaining_by_resource, route_available))
		if route_available > 0:
			return candidate.duplicate(true)
	return {}


func _card_effect_pair_binding_matches(production: Dictionary, demand: Dictionary) -> bool:
	if str(production.get("source_kind", "")) == "one_shot":
		if bool(demand.get("storage_sink", false)):
			return int(production.get("player_index", -1)) >= 0
		return int(production.get("player_index", -1)) >= 0 \
			and str(production.get("planned_source_factory_id", "")) == str(production.get("source_factory_id", production.get("facility_id", ""))) \
			and str(production.get("planned_market_facility_id", "")) == str(demand.get("market_facility_id", demand.get("facility_id", "")))
	if str(demand.get("source_kind", "")) == "one_shot_demand":
		return int(demand.get("player_index", -1)) == int(production.get("player_index", -2)) \
			and str(demand.get("planned_source_factory_id", "")) == str(production.get("source_factory_id", production.get("facility_id", ""))) \
			and str(demand.get("planned_market_facility_id", "")) == str(demand.get("market_facility_id", demand.get("facility_id", "")))
	return true


func _planned_card_effect_value(production: Dictionary, demand: Dictionary, field_name: String, default_value: Variant = "") -> Variant:
	if str(production.get("source_kind", "")) == "one_shot":
		return production.get(field_name, default_value)
	if str(demand.get("source_kind", "")) == "one_shot_demand":
		return demand.get(field_name, default_value)
	return default_value


func _sale_receipt(sequence: int, commodity_id: String, production: Dictionary, demand: Dictionary, route: Dictionary, facts: Dictionary, storage_rent_cents := 0) -> Dictionary:
	var price_cents := int((_dictionary(facts.get("price_cents_by_commodity", {}))).get(commodity_id, 0))
	var distance := maxi(0, int(route.get("shortest_legal_distance", 0)))
	var premium_bp := _distance_premium_basis_points(distance)
	var gross_value := int(round(float(price_cents) * float(BASIS_POINTS + premium_bp) / float(BASIS_POINTS)))
	var rent_inputs: Array = (route.get("expected_rents", []) as Array).duplicate(true)
	if storage_rent_cents > 0 and str(production.get("source_kind", "")) == "warehouse":
		rent_inputs.append({
			"facility_id": str(production.get("warehouse_id", "")),
			"facility_type": "warehouse",
			"recipient_player_index": int(production.get("warehouse_owner_player_index", -1)),
			"amount_per_unit_cents": storage_rent_cents,
			"rent_basis_points": 0,
		})
	var active_storage_debt := str(production.get("storage_liability_kind", "passive_forced")) == "active_production"
	var rent_result := _rent_rows(rent_inputs, gross_value, active_storage_debt)
	var rent_rows: Array = rent_result.get("rows", [])
	var total_rent := int(rent_result.get("total_rent", 0))
	var receipt_id := "commodity-sale-%010d" % sequence
	var weather_contributions := _merge_weather_contributions([
		production.get("weather_contributions", []),
		demand.get("weather_contributions", []),
	])
	var result := {
		"receipt_id": receipt_id,
		"trade_kind": "remote_route",
		"commodity_owner": int(production.get("player_index", -1)),
		"commodity_id": commodity_id,
		"color": str(production.get("color", "")),
		"units": 1,
		"source_region_id": str(production.get("region_id", "")),
		"market_region_id": str(demand.get("region_id", "")),
		"route_id": str(route.get("route_id", "")),
		"base_unit_price_cents": price_cents,
		"shortest_legal_distance": distance,
		"distance_premium_basis_points": premium_bp,
		"unit_price_cents": gross_value,
		"gross_value": gross_value,
		"rent_rows": rent_rows,
		"owner_net_cash": gross_value - total_rent,
		"gdp_value": gross_value,
		"market_cycle_revision": maxi(0, int(facts.get("market_cycle_revision", 0))),
		"public_volatility": maxi(0, int((facts.get("volatility_by_commodity", {}) as Dictionary).get(commodity_id, 0))),
		"settled_at": float(facts.get("game_time", 0.0)),
		"value_unit": "currency_cents",
		"weather_contributions": weather_contributions,
		"source_installation_id": str(production.get("installation_id", "")),
		"demand_installation_id": str(demand.get("installation_id", "")),
		"source_factory_id": str(production.get("source_factory_id", production.get("facility_id", ""))),
		"market_facility_id": str(demand.get("market_facility_id", demand.get("facility_id", ""))),
		"supply_batch_transaction_id": str(production.get("batch_transaction_id", "")),
		"demand_batch_transaction_id": str(demand.get("batch_transaction_id", "")),
		"observer_intents": [
			{"observer": "cash", "receipt_id": receipt_id},
			{"observer": "rent", "receipt_id": receipt_id},
			{"observer": "gdp", "receipt_id": receipt_id},
			{"observer": "mana", "receipt_id": receipt_id},
		],
	}
	if active_storage_debt and gross_value - total_rent < 0:
		result["bankruptcy_causality"] = "active_storage_debt"
	return result


func _ambient_sale_receipt(
	sequence: int,
	trade_kind: String,
	commodity_id: String,
	source: Dictionary,
	ambient_claim: Dictionary,
	facts: Dictionary
) -> Dictionary:
	var price_cents := maxi(0, int((_dictionary(facts.get("price_cents_by_commodity", {}))).get(commodity_id, 0)))
	var gross_value := int(round(float(price_cents) * float(_ambient_consumption_value_basis_points) / float(BASIS_POINTS)))
	if price_cents > 0 and _ambient_consumption_value_basis_points > 0:
		gross_value = maxi(1, gross_value)
	var consuming_region_id := str(ambient_claim.get("region_id", ""))
	var receipt_id := "commodity-sale-%010d" % sequence
	return {
		"receipt_id": receipt_id,
		"trade_kind": trade_kind,
		"commodity_owner": int(source.get("player_index", -1)),
		"economic_owner_kind": "production_owner",
		"commodity_id": commodity_id,
		"color": str(source.get("color", "")),
		"units": 1,
		"source_region_id": str(source.get("region_id", "")),
		"market_region_id": consuming_region_id,
		"consuming_region_id": consuming_region_id,
		"route_id": "",
		"base_unit_price_cents": price_cents,
		"shortest_legal_distance": 0,
		"distance_premium_basis_points": 0,
		"value_basis_points": _ambient_consumption_value_basis_points,
		"unit_price_cents": gross_value,
		"gross_value": gross_value,
		"rent_rows": [],
		"owner_net_cash": gross_value,
		"gdp_value": gross_value,
		"market_cycle_revision": maxi(0, int(facts.get("market_cycle_revision", 0))),
		"public_volatility": maxi(0, int((facts.get("volatility_by_commodity", {}) as Dictionary).get(commodity_id, 0))),
		"settled_at": float(facts.get("game_time", 0.0)),
		"value_unit": "currency_cents",
		"weather_contributions": _sanitize_weather_contributions(source.get("weather_contributions", [])),
		"source_installation_id": str(source.get("installation_id", "")),
		"demand_installation_id": "",
		"source_factory_id": str(source.get("source_factory_id", source.get("facility_id", ""))),
		"market_facility_id": "",
		"supply_kind": "fresh_output",
		"demand_kind": "ambient_regional_consumption",
		"observer_intents": [
			{"observer": "cash", "receipt_id": receipt_id},
			{"observer": "gdp", "receipt_id": receipt_id},
			{"observer": "mana", "receipt_id": receipt_id},
		],
	}


func _rent_rows(rows_variant: Variant, gross_value: int, allow_active_storage_debt := false) -> Dictionary:
	var rows: Array = []
	var non_storage_total := 0
	var storage_total := 0
	if rows_variant is Array:
		for row_variant in rows_variant:
			if not (row_variant is Dictionary):
				continue
			var source: Dictionary = row_variant
			var facility_type := str(source.get("facility_type", ""))
			var amount := maxi(0, int(source.get("amount_per_unit_cents", 0)))
			if amount <= 0:
				amount = int(round(float(gross_value) * float(maxi(0, int(source.get("rent_basis_points", 0)))) / float(BASIS_POINTS)))
			if amount <= 0:
				continue
			var row := {
				"facility_id": str(source.get("facility_id", "")),
				"facility_type": facility_type,
				"recipient_player_index": int(source.get("recipient_player_index", -1)),
				"amount": amount,
				"value_unit": "currency_cents",
			}
			if facility_type == "warehouse":
				storage_total += amount
			else:
				non_storage_total += amount
			rows.append(row)
	var non_storage_cap := int(floor(float(gross_value) * float(_non_storage_rent_cap_bp) / float(BASIS_POINTS)))
	if non_storage_total > non_storage_cap and non_storage_total > 0:
		var scale := float(non_storage_cap) / float(non_storage_total)
		non_storage_total = 0
		for row_index in range(rows.size()):
			var row: Dictionary = rows[row_index]
			if str(row.get("facility_type", "")) == "warehouse":
				continue
			var scaled_amount := int(floor(float(int(row.get("amount", 0))) * scale))
			row["amount"] = scaled_amount
			rows[row_index] = row
			non_storage_total += scaled_amount
	var storage_cap := maxi(0, gross_value - non_storage_total)
	if not allow_active_storage_debt and storage_total > storage_cap and storage_total > 0:
		var storage_scale := float(storage_cap) / float(storage_total)
		storage_total = 0
		for row_index in range(rows.size()):
			var row: Dictionary = rows[row_index]
			if str(row.get("facility_type", "")) != "warehouse":
				continue
			var scaled_amount := int(floor(float(int(row.get("amount", 0))) * storage_scale))
			row["amount"] = scaled_amount
			rows[row_index] = row
			storage_total += scaled_amount
	return {"rows": rows, "total_rent": non_storage_total + storage_total}


func _storage_rent_in_receipt(receipt: Dictionary, warehouse_id: String) -> int:
	var total := 0
	for row_variant in receipt.get("rent_rows", []):
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		if str(row.get("facility_type", "")) == "warehouse" and str(row.get("facility_id", "")) == warehouse_id:
			total += maxi(0, int(row.get("amount", 0)))
	return total


func _commit_flow_plan(plan: Dictionary) -> void:
	_installations = (plan.get("next_installations", {}) as Dictionary).duplicate(true)
	_rate_remainders = (plan.get("next_rate_remainders", {}) as Dictionary).duplicate(true)
	_pair_remainders = (plan.get("next_pair_remainders", {}) as Dictionary).duplicate(true)
	_ambient_rate_remainders = (plan.get("next_ambient_rate_remainders", {}) as Dictionary).duplicate(true)
	_ambient_fairness_cursor_by_region_commodity = (plan.get("next_ambient_fairness_cursor_by_region_commodity", {}) as Dictionary).duplicate(true)
	_ambient_revision = int(plan.get("next_ambient_revision", _ambient_revision))
	_market_backlog_by_key = (plan.get("next_market_backlog_by_key", {}) as Dictionary).duplicate(true)
	_wasted_continuous_milliunits_by_source = (plan.get("next_wasted_continuous_milliunits_by_source", {}) as Dictionary).duplicate(true)
	_wasted_continuous_milliunits_per_minute_by_source = (plan.get("next_wasted_continuous_milliunits_per_minute_by_source", {}) as Dictionary).duplicate(true)
	_cumulative_wasted_milliunits_by_source = (plan.get("next_cumulative_wasted_milliunits_by_source", {}) as Dictionary).duplicate(true)
	_cumulative_wasted_milliunits_by_commodity = (plan.get("next_cumulative_wasted_milliunits_by_commodity", {}) as Dictionary).duplicate(true)
	_cumulative_wasted_milliunits_by_region = (plan.get("next_cumulative_wasted_milliunits_by_region", {}) as Dictionary).duplicate(true)
	_waste_revision = int(plan.get("next_waste_revision", _waste_revision))
	_warehouse_inventory = (plan.get("next_warehouse_inventory", {}) as Dictionary).duplicate(true)
	_pending_one_shot_supplies = (plan.get("next_pending_one_shot_supplies", {}) as Dictionary).duplicate(true)
	_one_shot_transaction_receipts = (plan.get("next_one_shot_transaction_receipts", {}) as Dictionary).duplicate(true)
	_pending_one_shot_demands = (plan.get("next_pending_one_shot_demands", {}) as Dictionary).duplicate(true)
	_one_shot_demand_transaction_receipts = (plan.get("next_one_shot_demand_transaction_receipts", {}) as Dictionary).duplicate(true)
	_card_effect_batch_journal = (plan.get("next_card_effect_batch_journal", {}) as Dictionary).duplicate(true)
	_recent_sale_receipts = (plan.get("next_recent_sale_receipts", []) as Array).duplicate(true)
	_recent_flow_events = (plan.get("next_recent_flow_events", []) as Array).duplicate(true)
	_recent_flow_loss_events = (plan.get("next_recent_flow_loss_events", []) as Array).duplicate(true)
	_receipt_sequence = int(plan.get("next_receipt_sequence", _receipt_sequence))
	_batch_sequence = int(plan.get("next_batch_sequence", _batch_sequence))
	_current_game_time = maxf(_current_game_time, float(plan.get("settled_at", _current_game_time)))
	_flow_revision += 1
	_last_flow_metrics = (plan.get("metrics", {}) as Dictionary).duplicate(true)


func _warehouse_outflow_claims(_delta_milliseconds: int, _facts: Dictionary, inventory: Dictionary) -> Dictionary:
	var claims_by_commodity: Dictionary = {}
	var bucket_ids: Array = inventory.keys()
	bucket_ids.sort()
	for bucket_id_variant in bucket_ids:
		var bucket_id := str(bucket_id_variant)
		var bucket: Dictionary = inventory[bucket_id_variant]
		var warehouse_id := str(bucket.get("warehouse_id", ""))
		var available := maxi(0, int(bucket.get("milliunits", 0)))
		if available <= 0:
			continue
		var commodity_id := str(bucket.get("commodity_id", ""))
		var whole_units := maxi(1, int(ceil(float(available) / float(FIXED_POINT_SCALE))))
		var storage_rent_per_unit_cents := int(ceil(float(maxi(0, int(bucket.get("storage_rent_debt_cents", 0)))) / float(whole_units)))
		if not claims_by_commodity.has(commodity_id):
			claims_by_commodity[commodity_id] = []
		(claims_by_commodity[commodity_id] as Array).append({
			"installation_id": "warehouse-out:%s" % bucket_id,
			"source_kind": "warehouse",
			"warehouse_bucket_id": bucket_id,
			"warehouse_id": warehouse_id,
			"warehouse_owner_player_index": int(bucket.get("warehouse_owner_player_index", -1)),
			"storage_rent_debt_cents": maxi(0, int(bucket.get("storage_rent_debt_cents", 0))),
			"storage_liability_kind": str(bucket.get("storage_liability_kind", "passive_forced")),
			"storage_rent_per_unit_cents": storage_rent_per_unit_cents,
			"commodity_id": commodity_id,
			"color": str(bucket.get("color", "")),
			"player_index": int(bucket.get("owner_player_index", -1)),
			"facility_id": warehouse_id,
			"source_factory_id": str(bucket.get("source_factory_id", "")),
			"batch_transaction_id": str(bucket.get("batch_transaction_id", "")),
			"region_id": str(bucket.get("region_id", "")),
			"milliunits": available,
		})
	return {"claims_by_commodity": claims_by_commodity}


func _warehouse_throughput_budget(delta_milliseconds: int, facts: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var region_by_id := _index_by_id(facts.get("regions", []), "region_id")
	for facility_variant in facts.get("facilities", []):
		if not (facility_variant is Dictionary):
			continue
		var facility: Dictionary = facility_variant
		if not bool(facility.get("active", false)) or str(facility.get("facility_type", "")) != "warehouse":
			continue
		var rank := clampi(int(facility.get("rank", 1)), 1, 4)
		var region: Dictionary = _dictionary(region_by_id.get(str(facility.get("region_id", "")), {}))
		var integrity_bp := clampi(int(region.get("integrity_basis_points", BASIS_POINTS)), 0, BASIS_POINTS)
		var per_minute := maxi(0, int(_warehouse_throughput_by_rank.get(rank, 0)))
		var milliunits := int(floor(float(per_minute * FIXED_POINT_SCALE * delta_milliseconds) / float(MILLISECONDS_PER_MINUTE) * float(integrity_bp) / float(BASIS_POINTS)))
		result[str(facility.get("facility_id", ""))] = milliunits
	return result


func _store_unmatched_claims(
	commodity_id: String,
	production_claims: Array,
	used_by_source: Dictionary,
	delta_milliseconds: int,
	facts: Dictionary,
	inventory: Dictionary,
	inbound_remaining: Dictionary,
	route_remaining_by_id: Dictionary,
	route_remaining_by_resource: Dictionary
) -> Dictionary:
	var warehouse_facilities: Array = []
	var commodity_industry_id := str(PRODUCT_INDUSTRY_CATALOG.call("industry_for_product", commodity_id)) if PRODUCT_INDUSTRY_CATALOG.has_method("industry_for_product") else ""
	var region_by_id := _index_by_id(facts.get("regions", []), "region_id")
	for facility_variant in facts.get("facilities", []):
		if facility_variant is Dictionary and bool((facility_variant as Dictionary).get("active", false)) and str((facility_variant as Dictionary).get("facility_type", "")) == "warehouse":
			var warehouse: Dictionary = (facility_variant as Dictionary).duplicate(true)
			if str(warehouse.get("industry_id", "")) == commodity_industry_id:
				warehouse_facilities.append(warehouse)
	warehouse_facilities.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("facility_id", "")) < str(right.get("facility_id", ""))
	)
	var stored_by_source_id: Dictionary = {}
	var lost_by_source_id: Dictionary = {}
	var wasted_by_source_id: Dictionary = {}
	var flow_events: Array = []
	var flow_loss_events: Array = []
	var total_stored := 0
	var total_wasted := 0
	for claim_variant in production_claims:
		var claim: Dictionary = claim_variant
		var source_kind := str(claim.get("source_kind", "continuous"))
		if source_kind == "warehouse":
			continue
		var source_id := str(claim.get("installation_id", ""))
		var remaining := maxi(0, int(claim.get("milliunits", 0)) - int(used_by_source.get(source_id, 0)))
		if remaining <= 0:
			continue
		var storage_candidates: Array = []
		for facility_variant in warehouse_facilities:
			var facility: Dictionary = facility_variant
			var warehouse_id := str(facility.get("facility_id", ""))
			var warehouse_region_id := str(facility.get("region_id", ""))
			var region: Dictionary = _dictionary(region_by_id.get(warehouse_region_id, {}))
			var rank := clampi(int(facility.get("rank", 1)), 1, 4)
			var capacity := int(_warehouse_capacity_by_rank.get(rank, 0)) * FIXED_POINT_SCALE
			var free_capacity := maxi(0, capacity - _warehouse_inventory_total(inventory, warehouse_id))
			var inbound_capacity := maxi(0, int(inbound_remaining.get(warehouse_id, 0)))
			if not _region_is_live(region) or free_capacity <= 0 or inbound_capacity <= 0:
				continue
			var warehouse_sink := {
				"installation_id": "warehouse-in:%s" % warehouse_id,
				"region_id": warehouse_region_id,
				"storage_sink": true,
			}
			var route := _best_route(
				commodity_id,
				claim,
				warehouse_sink,
				delta_milliseconds,
				facts,
				route_remaining_by_id,
				route_remaining_by_resource
			)
			if route.is_empty():
				continue
			storage_candidates.append({
				"facility": facility,
				"route": route,
			})
		storage_candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_route: Dictionary = left.get("route", {})
			var right_route: Dictionary = right.get("route", {})
			var left_net := int(left_route.get("expected_owner_net_cash", 0))
			var right_net := int(right_route.get("expected_owner_net_cash", 0))
			if left_net != right_net:
				return left_net > right_net
			var left_arrival := float(left_route.get("arrival_seconds", 0.0))
			var right_arrival := float(right_route.get("arrival_seconds", 0.0))
			if not is_equal_approx(left_arrival, right_arrival):
				return left_arrival < right_arrival
			var left_facility: Dictionary = left.get("facility", {})
			var right_facility: Dictionary = right.get("facility", {})
			var left_id := "%s|%s" % [str(left_facility.get("facility_id", "")), str(left_route.get("route_id", ""))]
			var right_id := "%s|%s" % [str(right_facility.get("facility_id", "")), str(right_route.get("route_id", ""))]
			return left_id < right_id
		)
		for candidate_variant in storage_candidates:
			if remaining <= 0:
				break
			var candidate: Dictionary = candidate_variant
			var facility: Dictionary = candidate.get("facility", {})
			var route: Dictionary = candidate.get("route", {})
			var warehouse_id := str(facility.get("facility_id", ""))
			var warehouse_region_id := str(facility.get("region_id", ""))
			var rank := clampi(int(facility.get("rank", 1)), 1, 4)
			var capacity := int(_warehouse_capacity_by_rank.get(rank, 0)) * FIXED_POINT_SCALE
			var free_capacity := maxi(0, capacity - _warehouse_inventory_total(inventory, warehouse_id))
			var inbound_capacity := maxi(0, int(inbound_remaining.get(warehouse_id, 0)))
			if free_capacity <= 0 or inbound_capacity <= 0:
				continue
			var route_capacity := _route_available_milliunits(route, route_remaining_by_id, route_remaining_by_resource)
			var remaining_before_storage := remaining
			var stored := mini(remaining, mini(free_capacity, mini(inbound_capacity, route_capacity)))
			if stored <= 0:
				continue
			var bucket_id := _warehouse_bucket_id(warehouse_id, commodity_id, int(claim.get("player_index", -1)), source_id)
			var bucket: Dictionary = _dictionary(inventory.get(bucket_id, {}))
			if bucket.is_empty():
				bucket = {
					"bucket_id": bucket_id,
					"warehouse_id": warehouse_id,
					"region_id": warehouse_region_id,
					"commodity_id": commodity_id,
					"color": str(claim.get("color", "")),
					"warehouse_industry_id": str(facility.get("industry_id", "")),
					"owner_player_index": int(claim.get("player_index", -1)),
					"source_installation_id": source_id,
					"source_factory_id": str(claim.get("source_factory_id", claim.get("facility_id", ""))),
					"batch_transaction_id": str(claim.get("batch_transaction_id", "")),
					"milliunits": 0,
					"storage_rent_rate_pending": false,
					"storage_rent_basis_points_per_minute": int(_warehouse_storage_rent_bp_per_minute_by_rank.get(rank, 0)),
					"warehouse_owner_player_index": int(facility.get("owner_player_index", -1)),
					"storage_rent_debt_cents": 0,
					"storage_liability_kind": "passive_forced" if source_kind == "one_shot" else "active_production",
					"storage_rent_remainder": 0,
				}
			bucket["milliunits"] = int(bucket.get("milliunits", 0)) + stored
			bucket["last_inbound_route_id"] = str(route.get("route_id", ""))
			inventory[bucket_id] = bucket
			inbound_remaining[warehouse_id] = inbound_capacity - stored
			_consume_route_capacity(route, route_remaining_by_id, route_remaining_by_resource, stored)
			remaining -= stored
			total_stored += stored
			stored_by_source_id[source_id] = int(stored_by_source_id.get(source_id, 0)) + stored
			flow_events.append({
				"internal_flow_kind": "warehouse_inbound",
				"source_kind": source_kind,
				"commodity_id": commodity_id,
				"source_region_id": str(claim.get("region_id", "")),
				"warehouse_region_id": warehouse_region_id,
				"warehouse_facility_id": warehouse_id,
				"route_id": str(route.get("route_id", "")),
				"transport_modes": _unique_sorted_strings(route.get("mode_tags", [])),
				"quantity_units": float(stored) / float(FIXED_POINT_SCALE),
				"capacity_limited": stored < remaining_before_storage,
				"settled_at": float(facts.get("game_time", 0.0)),
			})
		if remaining > 0:
			total_wasted += remaining
			wasted_by_source_id[source_id] = int(wasted_by_source_id.get(source_id, 0)) + remaining
			lost_by_source_id[source_id] = int(lost_by_source_id.get(source_id, 0)) + remaining
			flow_loss_events.append({
				"loss_kind": "浪费产能",
				"commodity_id": commodity_id,
				"source_region_id": str(claim.get("region_id", "")),
				"quantity_units": float(remaining) / float(FIXED_POINT_SCALE),
				"settled_at": float(facts.get("game_time", 0.0)),
			})
	return {
		"stored_milliunits": total_stored,
		"wasted_milliunits": total_wasted,
		"wasted_by_source_id": wasted_by_source_id,
		"stored_by_source_id": stored_by_source_id,
		"lost_by_source_id": lost_by_source_id,
		"flow_events": flow_events,
		"flow_loss_events": flow_loss_events,
	}


func _consume_warehouse_outflow(inventory: Dictionary, production_claims: Array, used_by_source: Dictionary, storage_rent_settled_by_source: Dictionary) -> void:
	for claim_variant in production_claims:
		var claim: Dictionary = claim_variant
		if str(claim.get("source_kind", "")) != "warehouse":
			continue
		var bucket_id := str(claim.get("warehouse_bucket_id", ""))
		var used := maxi(0, int(used_by_source.get(str(claim.get("installation_id", "")), 0)))
		if used <= 0 or not inventory.has(bucket_id):
			continue
		var bucket: Dictionary = inventory[bucket_id]
		bucket["storage_rent_debt_cents"] = maxi(
			0,
			int(bucket.get("storage_rent_debt_cents", 0)) - maxi(0, int(storage_rent_settled_by_source.get(str(claim.get("installation_id", "")), 0)))
		)
		var remaining := maxi(0, int(bucket.get("milliunits", 0)) - used)
		if remaining <= 0:
			inventory.erase(bucket_id)
		else:
			bucket["milliunits"] = remaining
			inventory[bucket_id] = bucket


func _settle_one_shot_receipts(production_claims: Array, used_by_source: Dictionary, storage: Dictionary, receipts: Dictionary) -> void:
	var stored_by_source: Dictionary = storage.get("stored_by_source_id", {})
	var lost_by_source: Dictionary = storage.get("lost_by_source_id", {})
	for claim_variant in production_claims:
		var claim: Dictionary = claim_variant
		if str(claim.get("source_kind", "")) != "one_shot":
			continue
		var transaction_id := str(claim.get("transaction_id", ""))
		var source_id := str(claim.get("installation_id", ""))
		var receipt: Dictionary = _dictionary(receipts.get(transaction_id, {}))
		receipt["transaction_id"] = transaction_id
		receipt["accepted"] = true
		receipt["duplicate"] = false
		receipt["settled"] = true
		receipt["sold_milliunits"] = maxi(0, int(used_by_source.get(source_id, 0)))
		receipt["stored_milliunits"] = maxi(0, int(stored_by_source.get(source_id, 0)))
		receipt["lost_milliunits"] = maxi(0, int(lost_by_source.get(source_id, 0)))
		receipts[transaction_id] = receipt


func _settle_one_shot_demand_receipts(demand_claims: Array, used_by_demand: Dictionary, receipts: Dictionary) -> void:
	for claim_variant in demand_claims:
		var claim: Dictionary = claim_variant
		if str(claim.get("source_kind", "")) != "one_shot_demand":
			continue
		var transaction_id := str(claim.get("transaction_id", ""))
		var demand_id := str(claim.get("installation_id", ""))
		var allocated := maxi(0, int(claim.get("milliunits", 0)))
		var consumed := clampi(int(used_by_demand.get(demand_id, 0)), 0, allocated)
		var receipt: Dictionary = _dictionary(receipts.get(transaction_id, {}))
		receipt["transaction_id"] = transaction_id
		receipt["accepted"] = true
		receipt["duplicate"] = false
		receipt["settled"] = true
		receipt["consumed_milliunits"] = consumed
		receipt["unfilled_milliunits"] = allocated - consumed
		receipts[transaction_id] = receipt


func _settle_card_effect_batch_journal(journal: Dictionary, supply_receipts: Dictionary, demand_receipts: Dictionary) -> void:
	var transaction_ids: Array = journal.keys()
	transaction_ids.sort()
	for transaction_id_variant in transaction_ids:
		var transaction_id := str(transaction_id_variant)
		var entry: Dictionary = _dictionary(journal.get(transaction_id, {}))
		if str(entry.get("state", "")) != "pending_flow":
			continue
		var child_receipts: Array = []
		var all_settled := true
		var sold_milliunits := 0
		var stored_milliunits := 0
		var lost_milliunits := 0
		var consumed_milliunits := 0
		var unfilled_milliunits := 0
		for child_id_variant in entry.get("child_ids", []):
			var child_id := str(child_id_variant)
			var child: Dictionary = _dictionary(supply_receipts.get(child_id, demand_receipts.get(child_id, {})))
			if child.is_empty() or not bool(child.get("settled", false)):
				all_settled = false
				break
			child_receipts.append(child.duplicate(true))
			sold_milliunits += maxi(0, int(child.get("sold_milliunits", 0)))
			stored_milliunits += maxi(0, int(child.get("stored_milliunits", 0)))
			lost_milliunits += maxi(0, int(child.get("lost_milliunits", 0)))
			consumed_milliunits += maxi(0, int(child.get("consumed_milliunits", 0)))
			unfilled_milliunits += maxi(0, int(child.get("unfilled_milliunits", 0)))
		if not all_settled:
			continue
		var receipt: Dictionary = _dictionary(entry.get("receipt", {}))
		receipt["committed"] = true
		receipt["rolled_back"] = false
		receipt["settled"] = true
		receipt["state"] = "settled"
		receipt["rollback_open"] = false
		receipt["reason_code"] = "settled"
		receipt["child_receipts"] = child_receipts
		receipt["sold_milliunits"] = sold_milliunits
		receipt["stored_milliunits"] = stored_milliunits
		receipt["lost_milliunits"] = lost_milliunits
		receipt["consumed_milliunits"] = consumed_milliunits
		receipt["unfilled_milliunits"] = unfilled_milliunits
		entry["state"] = "settled"
		entry["rollback_open"] = false
		entry["receipt"] = receipt
		journal[transaction_id] = entry


func _prune_warehouse_inventory(inventory: Dictionary, facility_by_id: Dictionary, destroyed_facility_ids: Array) -> int:
	var lost := 0
	var bucket_ids: Array = inventory.keys()
	for bucket_id_variant in bucket_ids:
		var bucket: Dictionary = inventory[bucket_id_variant]
		var warehouse_id := str(bucket.get("warehouse_id", ""))
		var facility: Dictionary = _dictionary(facility_by_id.get(warehouse_id, {}))
		if destroyed_facility_ids.has(warehouse_id) or facility.is_empty() or not bool(facility.get("active", false)) or str(facility.get("facility_type", "")) != "warehouse":
			lost += maxi(0, int(bucket.get("milliunits", 0)))
			inventory.erase(bucket_id_variant)
	return lost


func _accrue_warehouse_rent(delta_milliseconds: int, facts: Dictionary, inventory: Dictionary) -> int:
	var facility_by_id := _index_by_id(facts.get("facilities", []), "facility_id")
	var prices := _dictionary(facts.get("price_cents_by_commodity", {}))
	var total_accrued := 0
	var denominator := BASIS_POINTS * FIXED_POINT_SCALE * MILLISECONDS_PER_MINUTE
	for bucket_id_variant in inventory.keys():
		var bucket: Dictionary = inventory[bucket_id_variant]
		var facility: Dictionary = _dictionary(facility_by_id.get(str(bucket.get("warehouse_id", "")), {}))
		if facility.is_empty():
			continue
		var rank := clampi(int(facility.get("rank", 1)), 1, 4)
		var rate_bp := maxi(0, int(_warehouse_storage_rent_bp_per_minute_by_rank.get(rank, 0)))
		var price_cents := maxi(0, int(prices.get(str(bucket.get("commodity_id", "")), 0)))
		var numerator := int(bucket.get("storage_rent_remainder", 0)) \
			+ price_cents * rate_bp * maxi(0, int(bucket.get("milliunits", 0))) * delta_milliseconds
		var accrued := int(floor(float(numerator) / float(denominator)))
		bucket["storage_rent_remainder"] = numerator % denominator
		bucket["storage_rent_debt_cents"] = maxi(0, int(bucket.get("storage_rent_debt_cents", 0))) + accrued
		bucket["warehouse_owner_player_index"] = int(facility.get("owner_player_index", -1))
		bucket["storage_rent_basis_points_per_minute"] = rate_bp
		bucket["storage_rent_rate_pending"] = false
		inventory[bucket_id_variant] = bucket
		total_accrued += accrued
	return total_accrued


func _warehouse_inventory_total(inventory: Dictionary, warehouse_id := "") -> int:
	var total := 0
	for bucket_variant in inventory.values():
		if not (bucket_variant is Dictionary):
			continue
		var bucket: Dictionary = bucket_variant
		if warehouse_id.is_empty() or str(bucket.get("warehouse_id", "")) == warehouse_id:
			total += maxi(0, int(bucket.get("milliunits", 0)))
	return total


func _warehouse_bucket_id(warehouse_id: String, commodity_id: String, owner_index: int, source_id: String) -> String:
	var identity := "%s|%s|%d|%s" % [warehouse_id, commodity_id, owner_index, source_id]
	return "warehouse-bucket:%s" % identity.sha256_text().substr(0, 20)


func _route_capacity_resource_limit(route: Dictionary, remaining_by_resource: Dictionary, fallback: int) -> int:
	var result := fallback
	var has_resource := false
	for resource_variant in route.get("capacity_resource_budgets", []):
		if not (resource_variant is Dictionary):
			continue
		var resource_id := str((resource_variant as Dictionary).get("resource_id", ""))
		if resource_id.is_empty():
			continue
		has_resource = true
		result = mini(result, maxi(0, int(remaining_by_resource.get(resource_id, 0))))
	return result if has_resource else fallback


func _consume_route_capacity_resources(route: Dictionary, remaining_by_resource: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	for resource_variant in route.get("capacity_resource_budgets", []):
		if not (resource_variant is Dictionary):
			continue
		var resource_id := str((resource_variant as Dictionary).get("resource_id", ""))
		if not resource_id.is_empty():
			remaining_by_resource[resource_id] = maxi(0, int(remaining_by_resource.get(resource_id, 0)) - amount)


func _receipt_totals(receipts: Array) -> Dictionary:
	var totals := {"gross_value": 0, "rent_value": 0, "owner_net_cash": 0, "gdp_value": 0}
	for receipt_variant in receipts:
		var receipt: Dictionary = receipt_variant
		totals["gross_value"] = int(totals.get("gross_value", 0)) + int(receipt.get("gross_value", 0))
		totals["owner_net_cash"] = int(totals.get("owner_net_cash", 0)) + int(receipt.get("owner_net_cash", 0))
		totals["gdp_value"] = int(totals.get("gdp_value", 0)) + int(receipt.get("gdp_value", 0))
		for rent_variant in receipt.get("rent_rows", []):
			totals["rent_value"] = int(totals.get("rent_value", 0)) + int((rent_variant as Dictionary).get("amount", 0))
	return totals


func _build_card_effect_candidates(facts: Dictionary) -> Dictionary:
	var facility_by_id := _index_by_id(facts.get("facilities", []), "facility_id")
	var region_by_id := _index_by_id(facts.get("regions", []), "region_id")
	if facility_by_id.is_empty() or region_by_id.is_empty():
		return {"valid": false, "reason_code": "authoritative_flow_snapshot_incomplete"}
	var reserved_result := _pending_card_effect_capacity_units_by_resource()
	if not bool(reserved_result.get("valid", false)):
		return {"valid": false, "reason_code": str(reserved_result.get("reason_code", "pending_capacity_state_invalid"))}
	var reserved_by_resource: Dictionary = reserved_result.get("reserved_units_by_resource", {}) if reserved_result.get("reserved_units_by_resource", {}) is Dictionary else {}
	var facts_game_time := maxf(0.0, float(facts.get("game_time", _current_game_time)))
	var cutoff := facts_game_time - _observation_window_seconds
	var gdp_by_goods: Dictionary = {}
	for receipt_variant in _recent_sale_receipts:
		if not (receipt_variant is Dictionary):
			continue
		var receipt: Dictionary = receipt_variant
		if float(receipt.get("settled_at", 0.0)) < cutoff:
			continue
		var commodity_id := str(receipt.get("commodity_id", "")).strip_edges()
		var commodity_owner := int(receipt.get("commodity_owner", -1))
		if commodity_id.is_empty() or commodity_owner < 0:
			continue
		var goods_key := "%08d|%s" % [commodity_owner, commodity_id]
		gdp_by_goods[goods_key] = int(gdp_by_goods.get(goods_key, 0)) + maxi(0, int(receipt.get("gdp_value", 0)))
	var candidates: Array = []
	var production_rows: Array = []
	for installation_variant in _installations.values():
		if not (installation_variant is Dictionary):
			continue
		var installation: Dictionary = installation_variant
		if bool(installation.get("active", false)) and str(installation.get("direction", "")) == "production":
			production_rows.append(installation.duplicate(true))
	production_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("installation_id", "")) < str(right.get("installation_id", "")))
	var market_rows: Array = []
	for facility_variant in facility_by_id.values():
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_type", "")) == "market":
			market_rows.append((facility_variant as Dictionary).duplicate(true))
	market_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("facility_id", "")) < str(right.get("facility_id", "")))
	var seen_lineages: Dictionary = {}
	for installation_variant in production_rows:
		var installation: Dictionary = installation_variant
		var commodity_id := str(installation.get("commodity_id", "")).strip_edges()
		var commodity_owner := int(installation.get("installer_player_index", -1))
		var source_factory_id := str(installation.get("facility_id", "")).strip_edges()
		var goods_key := "%08d|%s" % [commodity_owner, commodity_id]
		var matching_gdp := int(gdp_by_goods.get(goods_key, 0))
		var industry_id := str(PRODUCT_INDUSTRY_CATALOG.call("industry_for_product", commodity_id)) if PRODUCT_INDUSTRY_CATALOG.has_method("industry_for_product") else ""
		var factory: Dictionary = _dictionary(facility_by_id.get(source_factory_id, {}))
		if matching_gdp <= 0 or industry_id.is_empty() or not _card_effect_endpoint_valid(factory, "factory", industry_id):
			continue
		var source_region_id := str(factory.get("region_id", ""))
		var source_region: Dictionary = _dictionary(region_by_id.get(source_region_id, {}))
		if not _card_effect_region_valid(source_region):
			continue
		for market_variant in market_rows:
			var market: Dictionary = market_variant
			if not _card_effect_endpoint_valid(market, "market", industry_id):
				continue
			var market_facility_id := str(market.get("facility_id", ""))
			var market_region_id := str(market.get("region_id", ""))
			var market_region: Dictionary = _dictionary(region_by_id.get(market_region_id, {}))
			if not _card_effect_region_valid(market_region):
				continue
			var routes := _card_effect_legal_routes_for_pair(commodity_id, source_region, market_region, facts)
			for route_variant in routes:
				var route: Dictionary = route_variant
				var route_id := str(route.get("route_id", ""))
				var lineage_key := "%s|%s|%s|%s" % [goods_key, source_factory_id, market_facility_id, route_id]
				if seen_lineages.has(lineage_key):
					continue
				seen_lineages[lineage_key] = true
				var capacity_result := _card_effect_capacity_snapshot(route, factory, market, source_region, market_region)
				if not bool(capacity_result.get("valid", false)):
					continue
				capacity_result = _card_effect_capacity_after_reservations(capacity_result, reserved_by_resource)
				if not bool(capacity_result.get("valid", false)) or int(capacity_result.get("available_units", 0)) <= 0:
					continue
				var route_snapshot := {
					"route_id": route_id,
					"source_facility_id": source_factory_id,
					"market_facility_id": market_facility_id,
					"mode_tags": _unique_sorted_strings(route.get("mode_tags", [])),
					"shortest_legal_distance": int(route.get("shortest_legal_distance", -1)),
					"topology_revision": str(route.get("topology_revision", route.get("region_revision_fingerprint", ""))),
					"capacity_resources": (capacity_result.get("resources", []) as Array).duplicate(true),
					"expected_owner_net_cash": _card_effect_expected_owner_net_cash(commodity_id, route, facts),
					"arrival_milliseconds": int(round(maxf(0.0, float(route.get("arrival_seconds", 0.0))) * 1000.0)),
					"transfer_count": maxi(0, int(route.get("transfer_count", 0))),
				}
				if (route_snapshot["mode_tags"] as Array).is_empty() or int(route_snapshot.get("shortest_legal_distance", -1)) < 0 or str(route_snapshot.get("topology_revision", "")).is_empty():
					continue
				var identity_hash := JSON.stringify({"commodity_id": commodity_id, "commodity_owner": commodity_owner, "source_factory_id": source_factory_id, "market_facility_id": market_facility_id, "route_id": route_id}).sha256_text().substr(0, 20)
				for endpoint_variant in [
					{"kind": "factory", "facility": factory, "region": source_region},
					{"kind": "market", "facility": market, "region": market_region},
				]:
					var endpoint: Dictionary = endpoint_variant
					var endpoint_kind := str(endpoint.get("kind", ""))
					var endpoint_facility: Dictionary = _dictionary(endpoint.get("facility", {}))
					var endpoint_region: Dictionary = _dictionary(endpoint.get("region", {}))
					candidates.append({
						"candidate_id": "flow:%s:%s" % [identity_hash, endpoint_kind],
						"facility": {"facility_id": str(endpoint_facility.get("facility_id", "")), "facility_type": endpoint_kind, "industry_id": industry_id, "region_id": str(endpoint_facility.get("region_id", "")), "owner_player_index": int(endpoint_facility.get("owner_player_index", -1)), "active": true},
						"region": {"region_id": str(endpoint_region.get("region_id", "")), "revision": int(endpoint_region.get("revision", -1)), "lifecycle_state": str(endpoint_region.get("lifecycle_state", "active"))},
						"product": {"product_id": commodity_id, "industry_id": industry_id},
						"commodity_owner_player_index": commodity_owner,
						"matching_product_gdp_30s": matching_gdp,
						"available_capacity_units": int(capacity_result.get("available_units", 0)),
						"route": route_snapshot.duplicate(true),
					})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("candidate_id", "")) < str(right.get("candidate_id", "")))
	var resource_limits: Dictionary = {}
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		var route: Dictionary = candidate.get("route", {}) if candidate.get("route", {}) is Dictionary else {}
		for resource_variant in route.get("capacity_resources", []):
			if not (resource_variant is Dictionary):
				return {"valid": false, "reason_code": "capacity_resource_invalid"}
			var resource_id := str((resource_variant as Dictionary).get("resource_id", ""))
			var available_units := int((resource_variant as Dictionary).get("available_units", -1))
			if resource_limits.has(resource_id) and int(resource_limits.get(resource_id, -2)) != available_units:
				return {"valid": false, "reason_code": "capacity_resource_snapshot_inconsistent"}
			resource_limits[resource_id] = available_units
	return {"valid": true, "candidates": candidates}


func _card_effect_endpoint_valid(facility: Dictionary, expected_type: String, industry_id: String) -> bool:
	return not facility.is_empty() \
		and bool(facility.get("active", false)) \
		and str(facility.get("facility_type", "")) == expected_type \
		and str(facility.get("industry_id", "")) == industry_id \
		and int(facility.get("owner_player_index", -1)) >= 0 \
		and not str(facility.get("facility_id", "")).is_empty()


func _card_effect_legal_routes_for_pair(commodity_id: String, source_region: Dictionary, market_region: Dictionary, facts: Dictionary) -> Array:
	var source_region_id := str(source_region.get("region_id", ""))
	var market_region_id := str(market_region.get("region_id", ""))
	var routes_by_id: Dictionary = {}
	for route_variant in facts.get("route_candidates", []):
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = (route_variant as Dictionary).duplicate(true)
		if not [commodity_id, "*"].has(str(route.get("commodity_id", ""))) \
			or str(route.get("source_region_id", "")) != source_region_id \
			or str(route.get("market_region_id", "")) != market_region_id:
			continue
		var route_id := str(route.get("route_id", "")).strip_edges()
		if route_id.is_empty():
			continue
		route["topology_revision"] = str(route.get("topology_revision", route.get("region_revision_fingerprint", "")))
		routes_by_id[route_id] = route
	var result: Array = []
	var route_ids: Array = routes_by_id.keys()
	route_ids.sort()
	for route_id_variant in route_ids:
		result.append((_dictionary(routes_by_id.get(route_id_variant, {}))).duplicate(true))
	return result


func _card_effect_expected_owner_net_cash(commodity_id: String, route: Dictionary, facts: Dictionary) -> int:
	var price_cents := int((_dictionary(facts.get("price_cents_by_commodity", {}))).get(commodity_id, 0))
	var premium_bp := _distance_premium_basis_points(maxi(0, int(route.get("shortest_legal_distance", 0))))
	var gross_value := int(round(float(price_cents) * float(BASIS_POINTS + premium_bp) / float(BASIS_POINTS)))
	var rent_preview := _rent_rows(route.get("expected_rents", []), gross_value)
	return gross_value - int(rent_preview.get("total_rent", 0))


func _card_effect_candidates_fingerprint(candidates: Array) -> String:
	var resource_limits: Dictionary = {}
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var route: Dictionary = (candidate_variant as Dictionary).get("route", {}) if (candidate_variant as Dictionary).get("route", {}) is Dictionary else {}
		for resource_variant in route.get("capacity_resources", []):
			if resource_variant is Dictionary:
				var resource_id := str((resource_variant as Dictionary).get("resource_id", ""))
				if not resource_id.is_empty():
					resource_limits[resource_id] = int((resource_variant as Dictionary).get("available_units", 0))
	return CARD_EFFECT_SUPPORT.fingerprint({"candidates": candidates.duplicate(true), "capacity_resources": resource_limits})


func _card_effect_region_valid(region: Dictionary) -> bool:
	return not region.is_empty() \
		and int(region.get("revision", -1)) >= 0 \
		and not ["destroyed", "ruined"].has(str(region.get("lifecycle_state", "active")))


func _card_effect_capacity_snapshot(
	route: Dictionary,
	factory: Dictionary,
	market: Dictionary,
	source_region: Dictionary,
	market_region: Dictionary
) -> Dictionary:
	var resources: Array = []
	for resource_variant in route.get("capacity_resources", []):
		if not (resource_variant is Dictionary):
			return {"valid": false, "reason_code": "capacity_resource_invalid"}
		var resource: Dictionary = resource_variant
		var resource_id := str(resource.get("resource_id", "")).strip_edges()
		var per_minute := maxi(0, int(resource.get("capacity_units_per_minute", -1)))
		if resource_id.is_empty() or per_minute < 0:
			return {"valid": false, "reason_code": "capacity_resource_invalid"}
		resources.append({
			"resource_id": resource_id,
			"available_units": int(floor(float(per_minute) * _observation_window_seconds / 60.0)),
		})
	for endpoint_variant in [
		{"facility": factory, "region": source_region},
		{"facility": market, "region": market_region},
	]:
		var endpoint: Dictionary = endpoint_variant
		var facility: Dictionary = _dictionary(endpoint.get("facility", {}))
		var region: Dictionary = _dictionary(endpoint.get("region", {}))
		var rank := clampi(int(facility.get("rank", 1)), 1, 4)
		var capacity_per_minute := int(_factory_market_capacity_by_rank.get(rank, 0))
		var integrity_bp := clampi(int(region.get("integrity_basis_points", BASIS_POINTS)), 0, BASIS_POINTS)
		var available := int(floor(float(capacity_per_minute) * float(integrity_bp) / float(BASIS_POINTS) * _observation_window_seconds / 60.0))
		resources.append({
			"resource_id": "facility:%s:card-effect-capacity" % str(facility.get("facility_id", "")),
			"available_units": maxi(0, available),
		})
	if resources.is_empty():
		return {"valid": false, "reason_code": "capacity_resources_missing"}
	resources.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("resource_id", "")) < str(right.get("resource_id", "")))
	var available_units := 2147483647
	var seen: Dictionary = {}
	for resource_variant in resources:
		var resource: Dictionary = resource_variant
		var resource_id := str(resource.get("resource_id", ""))
		if seen.has(resource_id):
			return {"valid": false, "reason_code": "capacity_resource_duplicate"}
		seen[resource_id] = true
		available_units = mini(available_units, maxi(0, int(resource.get("available_units", 0))))
	return {"valid": true, "available_units": maxi(0, available_units), "resources": resources}


func _card_effect_capacity_after_reservations(capacity_result: Dictionary, reserved_by_resource: Dictionary) -> Dictionary:
	var resources: Array = []
	var available_units := 2147483647
	for resource_variant in capacity_result.get("resources", []):
		if not (resource_variant is Dictionary):
			return {"valid": false, "reason_code": "capacity_resource_invalid"}
		var resource: Dictionary = resource_variant
		var resource_id := str(resource.get("resource_id", ""))
		var available := maxi(0, int(resource.get("available_units", 0)) - int(reserved_by_resource.get(resource_id, 0)))
		resources.append({"resource_id": resource_id, "available_units": available})
		available_units = mini(available_units, available)
	if resources.is_empty():
		return {"valid": false, "reason_code": "capacity_resources_missing"}
	return {"valid": true, "available_units": maxi(0, available_units), "resources": resources}


func _pending_card_effect_capacity_units_by_resource() -> Dictionary:
	var reserved: Dictionary = {}
	for journal_variant in _card_effect_batch_journal.values():
		if not (journal_variant is Dictionary):
			return {"valid": false, "reason_code": "pending_batch_journal_invalid"}
		var journal: Dictionary = journal_variant
		if str(journal.get("state", "")) != "pending_flow":
			continue
		var children: Array = journal.get("children", []) if journal.get("children", []) is Array else []
		if children.is_empty() and not (journal.get("child_ids", []) as Array).is_empty():
			return {"valid": false, "reason_code": "pending_batch_capacity_binding_missing"}
		for child_variant in children:
			if not (child_variant is Dictionary):
				return {"valid": false, "reason_code": "pending_batch_child_invalid"}
			var child: Dictionary = child_variant
			var allocated_units := int(child.get("allocated_units", -1))
			var resource_ids := _unique_sorted_strings(child.get("capacity_resource_ids", []))
			if allocated_units <= 0 or resource_ids.is_empty():
				return {"valid": false, "reason_code": "pending_batch_capacity_binding_missing"}
			for resource_id_variant in resource_ids:
				var resource_id := str(resource_id_variant)
				reserved[resource_id] = int(reserved.get(resource_id, 0)) + allocated_units
	return {"valid": true, "reserved_units_by_resource": reserved}


func _normalize_card_effect_batch(plan: Dictionary, facts: Dictionary) -> Dictionary:
	var effect_kind := str(plan.get("one_time_effect_kind", ""))
	if not ["extra_demand", "physical_supply"].has(effect_kind):
		return {"valid": false, "reason_code": "one_time_effect_kind_invalid"}
	var candidate_build := _build_card_effect_candidates(facts)
	if not bool(candidate_build.get("valid", false)):
		return {"valid": false, "reason_code": str(candidate_build.get("reason_code", "candidate_snapshot_invalid"))}
	var current_candidates: Array = candidate_build.get("candidates", []) if candidate_build.get("candidates", []) is Array else []
	var current_fingerprint := _card_effect_candidates_fingerprint(current_candidates)
	if current_fingerprint != _card_effect_candidate_snapshot_fingerprint:
		_card_effect_candidate_snapshot_fingerprint = current_fingerprint
		_card_effect_candidate_snapshot_revision += 1
	if int(plan.get("candidate_snapshot_revision", -1)) != _card_effect_candidate_snapshot_revision \
		or str(plan.get("candidate_snapshot_fingerprint", "")) != _card_effect_candidate_snapshot_fingerprint:
		return {"valid": false, "reason_code": "candidate_snapshot_revision_changed"}
	var current_candidate_by_id := _index_by_id(current_candidates, "candidate_id")
	if current_candidate_by_id.is_empty():
		return {"valid": false, "reason_code": "candidate_snapshot_empty"}
	var allocations: Array = plan.get("allocations", []) if plan.get("allocations", []) is Array else []
	var facility_by_id := _index_by_id(facts.get("facilities", []), "facility_id")
	var region_by_id := _index_by_id(facts.get("regions", []), "region_id")
	if facility_by_id.is_empty() or region_by_id.is_empty():
		return {"valid": false, "reason_code": "authoritative_flow_snapshot_incomplete"}
	var transaction_id := str(plan.get("transaction_id", ""))
	var children: Array = []
	var child_ids: Dictionary = {}
	var requested_by_resource: Dictionary = {}
	var resource_limits: Dictionary = {}
	for allocation_variant in allocations:
		if not (allocation_variant is Dictionary) or not _is_pure_data(allocation_variant):
			return {"valid": false, "reason_code": "batch_child_invalid"}
		var allocation: Dictionary = allocation_variant
		var allocated_units := int(allocation.get("allocated_units", -1))
		if allocated_units < 0:
			return {"valid": false, "reason_code": "batch_child_units_invalid"}
		if allocated_units == 0:
			continue
		var candidate_id := str(allocation.get("candidate_id", "")).strip_edges()
		var commodity_id := str(allocation.get("product_id", "")).strip_edges()
		var industry_id := str(allocation.get("industry_id", ""))
		var commodity_owner := int(allocation.get("commodity_owner_player_index", -1))
		var source_factory_id := str(allocation.get("source_facility_id", "")).strip_edges()
		var market_facility_id := str(allocation.get("market_facility_id", "")).strip_edges()
		var candidate_facility_id := str(allocation.get("facility_id", "")).strip_edges()
		if candidate_id.is_empty() or commodity_id.is_empty() or industry_id.is_empty() or commodity_owner < 0 or source_factory_id.is_empty() or market_facility_id.is_empty():
			return {"valid": false, "reason_code": "batch_child_identity_invalid"}
		if not current_candidate_by_id.has(candidate_id):
			return {"valid": false, "reason_code": "batch_child_candidate_missing"}
		var current_candidate: Dictionary = _dictionary(current_candidate_by_id.get(candidate_id, {}))
		var candidate_match := _card_effect_allocation_matches_candidate(allocation, current_candidate, effect_kind)
		if not bool(candidate_match.get("valid", false)):
			return candidate_match
		if allocated_units > int(current_candidate.get("available_capacity_units", 0)):
			return {"valid": false, "reason_code": "batch_child_capacity_exceeded"}
		var catalog_industry := str(PRODUCT_INDUSTRY_CATALOG.call("industry_for_product", commodity_id)) if PRODUCT_INDUSTRY_CATALOG.has_method("industry_for_product") else ""
		if catalog_industry.is_empty() or catalog_industry != industry_id:
			return {"valid": false, "reason_code": "batch_child_commodity_invalid"}
		var source_factory: Dictionary = _dictionary(facility_by_id.get(source_factory_id, {}))
		var market: Dictionary = _dictionary(facility_by_id.get(market_facility_id, {}))
		if source_factory.is_empty() or market.is_empty() \
			or not bool(source_factory.get("active", false)) or not bool(market.get("active", false)) \
			or str(source_factory.get("facility_type", "")) != "factory" or str(market.get("facility_type", "")) != "market" \
			or str(source_factory.get("industry_id", "")) != industry_id or str(market.get("industry_id", "")) != industry_id:
			return {"valid": false, "reason_code": "batch_child_endpoint_invalid"}
		if not _active_production_installation_exists(source_factory_id, commodity_id, commodity_owner):
			return {"valid": false, "reason_code": "batch_child_real_supply_unavailable"}
		var source_region_id := str(source_factory.get("region_id", ""))
		var market_region_id := str(market.get("region_id", ""))
		var source_region: Dictionary = _dictionary(region_by_id.get(source_region_id, {}))
		var market_region: Dictionary = _dictionary(region_by_id.get(market_region_id, {}))
		if source_region.is_empty() or market_region.is_empty() \
			or ["destroyed", "ruined"].has(str(source_region.get("lifecycle_state", "active"))) \
			or ["destroyed", "ruined"].has(str(market_region.get("lifecycle_state", "active"))):
			return {"valid": false, "reason_code": "batch_child_region_invalid"}
		var expected_candidate_facility := market_facility_id if effect_kind == "extra_demand" else source_factory_id
		var expected_candidate_region := market_region if effect_kind == "extra_demand" else source_region
		if candidate_facility_id != expected_candidate_facility \
			or str(allocation.get("facility_type", "")) != ("market" if effect_kind == "extra_demand" else "factory") \
			or str(allocation.get("region_id", "")) != str(expected_candidate_region.get("region_id", "")) \
			or int(allocation.get("region_revision", -1)) != int(expected_candidate_region.get("revision", -2)):
			return {"valid": false, "reason_code": "batch_child_candidate_revision_changed"}
		var route_id := str(allocation.get("route_id", "")).strip_edges()
		var legal_routes := _card_effect_legal_routes_for_pair(commodity_id, source_region, market_region, facts)
		var route_by_id := _index_by_id(legal_routes, "route_id")
		var route: Dictionary = _dictionary(route_by_id.get(route_id, {}))
		if route.is_empty() or str(route.get("source_region_id", "")) != source_region_id or str(route.get("market_region_id", "")) != market_region_id:
			return {"valid": false, "reason_code": "batch_child_route_changed"}
		var planned_distance := int(allocation.get("shortest_legal_distance", -1))
		if planned_distance < 0 or planned_distance != int(route.get("shortest_legal_distance", -2)):
			return {"valid": false, "reason_code": "batch_child_route_distance_changed"}
		var planned_topology_revision := str(allocation.get("topology_revision", ""))
		var actual_topology_revision := str(route.get("topology_revision", route.get("region_revision_fingerprint", "")))
		if planned_topology_revision.is_empty() or actual_topology_revision.is_empty() or planned_topology_revision != actual_topology_revision:
			return {"valid": false, "reason_code": "batch_child_topology_revision_changed"}
		var planned_modes := _unique_sorted_strings(allocation.get("route_mode_tags", []))
		var actual_modes := _unique_sorted_strings(route.get("mode_tags", []))
		if planned_modes.is_empty():
			return {"valid": false, "reason_code": "batch_child_route_mode_missing"}
		for mode_variant in planned_modes:
			if not actual_modes.has(mode_variant):
				return {"valid": false, "reason_code": "batch_child_route_mode_changed"}
		var planned_resource_ids := _unique_sorted_strings(allocation.get("capacity_resource_ids", []))
		var capacity_result := _card_effect_capacity_snapshot(route, source_factory, market, source_region, market_region)
		if not bool(capacity_result.get("valid", false)):
			return {"valid": false, "reason_code": str(capacity_result.get("reason_code", "batch_child_capacity_invalid"))}
		var actual_resource_ids: Array = []
		for resource_variant in capacity_result.get("resources", []):
			if resource_variant is Dictionary:
				actual_resource_ids.append(str((resource_variant as Dictionary).get("resource_id", "")))
		actual_resource_ids = _unique_sorted_strings(actual_resource_ids)
		if planned_resource_ids != actual_resource_ids:
			return {"valid": false, "reason_code": "batch_child_capacity_resource_changed"}
		var candidate_route: Dictionary = current_candidate.get("route", {}) if current_candidate.get("route", {}) is Dictionary else {}
		var candidate_resources: Array = candidate_route.get("capacity_resources", []) if candidate_route.get("capacity_resources", []) is Array else []
		for resource_variant in candidate_resources:
			if not (resource_variant is Dictionary):
				return {"valid": false, "reason_code": "batch_child_capacity_resource_changed"}
			var resource: Dictionary = resource_variant
			var resource_id := str(resource.get("resource_id", ""))
			var available_units := maxi(0, int(resource.get("available_units", 0)))
			if resource_id.is_empty():
				return {"valid": false, "reason_code": "batch_child_capacity_resource_changed"}
			resource_limits[resource_id] = mini(int(resource_limits.get(resource_id, available_units)), available_units)
			requested_by_resource[resource_id] = int(requested_by_resource.get(resource_id, 0)) + allocated_units
			if int(requested_by_resource.get(resource_id, 0)) > int(resource_limits.get(resource_id, 0)):
				return {"valid": false, "reason_code": "batch_shared_capacity_exceeded"}
		var child_id := "%s:%s" % [transaction_id, candidate_id.sha256_text().substr(0, 20)]
		if child_ids.has(child_id):
			return {"valid": false, "reason_code": "batch_child_duplicate"}
		child_ids[child_id] = true
		children.append({
			"child_transaction_id": child_id,
			"candidate_id": candidate_id,
			"one_time_effect_kind": effect_kind,
			"commodity_id": commodity_id,
			"color": industry_id,
			"commodity_owner_player_index": commodity_owner,
			"source_factory_id": source_factory_id,
			"market_facility_id": market_facility_id,
			"source_region_id": source_region_id,
			"market_region_id": market_region_id,
			"route_id": route_id,
			"route_mode_tags": planned_modes,
			"shortest_legal_distance": planned_distance,
			"topology_revision": planned_topology_revision,
			"capacity_resource_ids": planned_resource_ids,
			"allocated_units": allocated_units,
			"milliunits": allocated_units * FIXED_POINT_SCALE,
		})
	children.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("child_transaction_id", "")) < str(right.get("child_transaction_id", "")))
	return {"valid": true, "children": children}


func _card_effect_allocation_matches_candidate(allocation: Dictionary, candidate: Dictionary, effect_kind: String) -> Dictionary:
	var facility: Dictionary = candidate.get("facility", {}) if candidate.get("facility", {}) is Dictionary else {}
	var region: Dictionary = candidate.get("region", {}) if candidate.get("region", {}) is Dictionary else {}
	var product: Dictionary = candidate.get("product", {}) if candidate.get("product", {}) is Dictionary else {}
	var route: Dictionary = candidate.get("route", {}) if candidate.get("route", {}) is Dictionary else {}
	var expected_facility_type := "market" if effect_kind == "extra_demand" else "factory"
	var resource_ids: Array = []
	for resource_variant in route.get("capacity_resources", []):
		if resource_variant is Dictionary:
			resource_ids.append(str((resource_variant as Dictionary).get("resource_id", "")))
	resource_ids = _unique_sorted_strings(resource_ids)
	var allocation_resources := _unique_sorted_strings(allocation.get("capacity_resource_ids", []))
	var allocation_modes := _unique_sorted_strings(allocation.get("route_mode_tags", []))
	var candidate_modes := _unique_sorted_strings(route.get("mode_tags", []))
	var matches := (
		str(allocation.get("candidate_id", "")) == str(candidate.get("candidate_id", ""))
		and str(allocation.get("product_id", "")) == str(product.get("product_id", ""))
		and str(allocation.get("industry_id", "")) == str(product.get("industry_id", ""))
		and int(allocation.get("commodity_owner_player_index", -1)) == int(candidate.get("commodity_owner_player_index", -2))
		and int(allocation.get("beneficiary_player_index", -1)) == int(candidate.get("commodity_owner_player_index", -2))
		and str(allocation.get("facility_id", "")) == str(facility.get("facility_id", ""))
		and str(allocation.get("facility_type", "")) == expected_facility_type
		and str(facility.get("facility_type", "")) == expected_facility_type
		and str(allocation.get("region_id", "")) == str(region.get("region_id", ""))
		and int(allocation.get("region_revision", -1)) == int(region.get("revision", -2))
		and str(allocation.get("source_facility_id", "")) == str(route.get("source_facility_id", ""))
		and str(allocation.get("market_facility_id", "")) == str(route.get("market_facility_id", ""))
		and str(allocation.get("route_id", "")) == str(route.get("route_id", ""))
		and str(allocation.get("topology_revision", "")) == str(route.get("topology_revision", ""))
		and int(allocation.get("shortest_legal_distance", -1)) == int(route.get("shortest_legal_distance", -2))
		and int(allocation.get("matching_product_gdp_30s", -1)) == int(candidate.get("matching_product_gdp_30s", -2))
		and allocation_modes == candidate_modes
		and allocation_resources == resource_ids
	)
	return {"valid": matches, "reason_code": "ready" if matches else "batch_child_candidate_binding_changed"}


func _active_production_installation_exists(factory_id: String, commodity_id: String, owner_player_index: int) -> bool:
	for installation_variant in _installations.values():
		if not (installation_variant is Dictionary):
			continue
		var installation: Dictionary = installation_variant
		if bool(installation.get("active", false)) \
			and str(installation.get("direction", "")) == "production" \
			and str(installation.get("facility_id", "")) == factory_id \
			and str(installation.get("commodity_id", "")) == commodity_id \
			and int(installation.get("installer_player_index", -1)) == owner_player_index:
			return true
	return false


func _card_effect_batch_binding(source: Dictionary) -> Dictionary:
	return {
		"transaction_id": str(source.get("transaction_id", "")).strip_edges(),
		"intent_hash": str(source.get("intent_hash", "")).strip_edges(),
		"plan_hash": str(source.get("plan_hash", "")).strip_edges(),
	}


func _card_effect_batch_binding_complete(binding: Dictionary) -> bool:
	return not str(binding.get("transaction_id", "")).is_empty() \
		and not str(binding.get("intent_hash", "")).is_empty() \
		and not str(binding.get("plan_hash", "")).is_empty()


func _card_effect_batch_binding_matches(first: Dictionary, second: Dictionary) -> bool:
	return str(first.get("transaction_id", "")) == str(second.get("transaction_id", "")) \
		and str(first.get("intent_hash", "")) == str(second.get("intent_hash", "")) \
		and str(first.get("plan_hash", "")) == str(second.get("plan_hash", ""))


func _card_effect_batch_failure(binding: Dictionary, reason_code: String, stage: String) -> Dictionary:
	var receipt := binding.duplicate(true)
	receipt["receipt_kind"] = "commodity_flow_card_effect_batch"
	receipt["prepared"] = false
	receipt["committed"] = false
	receipt["rolled_back"] = false
	receipt["duplicate"] = false
	receipt["stage"] = stage
	receipt["reason_code"] = reason_code
	return receipt


func _card_effect_prepared_token(prepared: Dictionary) -> String:
	return JSON.stringify({
		"binding": _card_effect_batch_binding(prepared),
		"expected_flow_revision": int(prepared.get("expected_flow_revision", -1)),
		"one_time_effect_kind": str(prepared.get("one_time_effect_kind", "")),
		"prepared_children": (prepared.get("prepared_children", []) as Array).duplicate(true) if prepared.get("prepared_children", []) is Array else [],
	}).sha256_text()


func _card_effect_child_ids(children: Array) -> Array:
	var result: Array = []
	for child_variant in children:
		if child_variant is Dictionary:
			result.append(str((child_variant as Dictionary).get("child_transaction_id", "")))
	result.sort()
	return result


func _card_effect_batch_state_count(state: String) -> int:
	var count := 0
	for entry_variant in _card_effect_batch_journal.values():
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("state", "")) == state:
			count += 1
	return count


func _validate_saved_card_effect_batch_state(
	pending_supplies: Dictionary,
	supply_receipts: Dictionary,
	pending_demands: Dictionary,
	demand_receipts: Dictionary,
	journal: Dictionary,
	rollback_receipts: Dictionary
) -> Dictionary:
	for supply_id_variant in pending_supplies.keys():
		var supply_id := str(supply_id_variant)
		var supply: Dictionary = _dictionary(pending_supplies.get(supply_id_variant, {}))
		if supply_id.is_empty() or str(supply.get("transaction_id", "")) != supply_id \
			or str(supply.get("source_kind", "")) != "one_shot" \
			or int(supply.get("milliunits", 0)) <= 0 or not supply_receipts.has(supply_id):
			return {"valid": false, "reason": "pending_one_shot_supply_invalid"}
	for demand_id_variant in pending_demands.keys():
		var demand_id := str(demand_id_variant)
		var demand: Dictionary = _dictionary(pending_demands.get(demand_id_variant, {}))
		if demand_id.is_empty() or str(demand.get("transaction_id", "")) != demand_id \
			or str(demand.get("source_kind", "")) != "one_shot_demand" \
			or int(demand.get("milliunits", 0)) <= 0 or not demand_receipts.has(demand_id):
			return {"valid": false, "reason": "pending_one_shot_demand_invalid"}
	for transaction_id_variant in journal.keys():
		var transaction_id := str(transaction_id_variant)
		var entry: Dictionary = _dictionary(journal.get(transaction_id_variant, {}))
		var state := str(entry.get("state", ""))
		var receipt: Dictionary = _dictionary(entry.get("receipt", {}))
		var finalized := bool(entry.get("finalized", false))
		var rollback_open := bool(entry.get("rollback_open", false))
		if transaction_id.is_empty() or str(entry.get("transaction_id", "")) != transaction_id \
			or not ["pending_flow", "settled", "rolled_back"].has(state) \
			or not _card_effect_batch_binding_complete(entry) \
			or not _card_effect_batch_binding_matches(entry, receipt) \
			or (finalized and rollback_open) \
			or (state != "pending_flow" and rollback_open):
			return {"valid": false, "reason": "card_effect_batch_journal_invalid"}
		var child_ids: Array = entry.get("child_ids", []) if entry.get("child_ids", []) is Array else []
		var children: Array = entry.get("children", []) if entry.get("children", []) is Array else []
		if child_ids.is_empty() or children.size() != child_ids.size():
			return {"valid": false, "reason": "card_effect_batch_children_missing"}
		var child_by_id := _index_by_id(children, "child_transaction_id")
		if child_by_id.size() != child_ids.size():
			return {"valid": false, "reason": "card_effect_batch_children_invalid"}
		var seen: Dictionary = {}
		for child_id_variant in child_ids:
			var child_id := str(child_id_variant)
			var child: Dictionary = _dictionary(child_by_id.get(child_id, {}))
			if child_id.is_empty() or seen.has(child_id) or child.is_empty() \
				or int(child.get("allocated_units", 0)) <= 0 \
				or _unique_sorted_strings(child.get("capacity_resource_ids", [])).is_empty():
				return {"valid": false, "reason": "card_effect_batch_child_ids_invalid"}
			seen[child_id] = true
			var supply_pending := pending_supplies.has(child_id)
			var demand_pending := pending_demands.has(child_id)
			if state == "pending_flow":
				if supply_pending == demand_pending \
					or (supply_pending and not supply_receipts.has(child_id)) \
					or (demand_pending and not demand_receipts.has(child_id)):
					return {"valid": false, "reason": "card_effect_batch_pending_child_invalid"}
				var claim: Dictionary = _dictionary(pending_supplies.get(child_id, pending_demands.get(child_id, {})))
				var child_receipt: Dictionary = _dictionary(supply_receipts.get(child_id, demand_receipts.get(child_id, {})))
				if str(claim.get("batch_transaction_id", "")) != transaction_id \
					or str(child_receipt.get("batch_transaction_id", "")) != transaction_id \
					or str(claim.get("commodity_id", "")) != str(child.get("commodity_id", "")) \
					or int(claim.get("milliunits", 0)) != int(child.get("milliunits", -1)):
					return {"valid": false, "reason": "card_effect_batch_child_binding_invalid"}
			elif supply_pending or demand_pending:
				return {"valid": false, "reason": "card_effect_batch_terminal_child_still_pending"}
		if state == "settled" and (not bool(receipt.get("settled", false)) or bool(receipt.get("rolled_back", false))):
			return {"valid": false, "reason": "card_effect_batch_settled_receipt_invalid"}
		if state == "rolled_back":
			if not rollback_receipts.has(transaction_id) or not bool(receipt.get("rolled_back", false)):
				return {"valid": false, "reason": "card_effect_batch_rollback_receipt_missing"}
			var rollback: Dictionary = _dictionary(rollback_receipts.get(transaction_id, {}))
			if not _card_effect_batch_binding_matches(entry, rollback) or not bool(rollback.get("rolled_back", false)):
				return {"valid": false, "reason": "card_effect_batch_rollback_receipt_invalid"}
	for child_id_variant in pending_supplies.keys():
		var orphan_supply_claim: Dictionary = _dictionary(pending_supplies.get(child_id_variant, {}))
		var supply_batch_id := str(orphan_supply_claim.get("batch_transaction_id", ""))
		if not supply_batch_id.is_empty() and (not journal.has(supply_batch_id) or str((_dictionary(journal.get(supply_batch_id, {}))).get("state", "")) != "pending_flow"):
			return {"valid": false, "reason": "orphan_pending_supply_batch"}
	for child_id_variant in pending_demands.keys():
		var orphan_demand_claim: Dictionary = _dictionary(pending_demands.get(child_id_variant, {}))
		var demand_batch_id := str(orphan_demand_claim.get("batch_transaction_id", ""))
		if not demand_batch_id.is_empty() and (not journal.has(demand_batch_id) or str((_dictionary(journal.get(demand_batch_id, {}))).get("state", "")) != "pending_flow"):
			return {"valid": false, "reason": "orphan_pending_demand_batch"}
	return {"valid": true}


func _unique_sorted_strings(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item_variant in value:
			var item := str(item_variant)
			if not item.is_empty() and not result.has(item):
				result.append(item)
	result.sort()
	return result


func _installation_failure(request: Dictionary, reason: String) -> Dictionary:
	return {
		"receipt_kind": "commodity_installation",
		"transaction_id": str(request.get("transaction_id", "")),
		"committed": false,
		"duplicate": false,
		"reason": reason,
		"reason_code": reason,
		"request_fingerprint": _installation_request_fingerprint(request),
	}


func _remember_installation_receipt(transaction_id: String, receipt: Dictionary) -> Dictionary:
	if not transaction_id.is_empty():
		_installation_transaction_receipts[transaction_id] = receipt.duplicate(true)
	return receipt


func _installation_request_fingerprint(request: Dictionary) -> String:
	var facility: Dictionary = request.get("facility", {}) if request.get("facility", {}) is Dictionary else {}
	return CARD_EFFECT_SUPPORT.fingerprint({
		"transaction_id": str(request.get("transaction_id", "")).strip_edges(),
		"installation_id": str(request.get("installation_id", "")).strip_edges(),
		"facility_id": str(request.get("facility_id", facility.get("facility_id", ""))).strip_edges(),
		"region_id": str(request.get("region_id", facility.get("region_id", ""))).strip_edges(),
		"commodity_id": str(request.get("commodity_id", request.get("product_id", ""))).strip_edges(),
		"direction": str(request.get("direction", "")).strip_edges(),
		"owner_kind": str(request.get("owner_kind", "player")).strip_edges(),
		"installer_player_index": int(request.get("installer_player_index", request.get("player_index", -1))),
		"source_card_rank": _rank_number(request.get("source_card_rank", request.get("rank", 0))),
	})


func _installation_owner_record_valid(installation: Dictionary) -> bool:
	var owner_kind := str(installation.get("owner_kind", "player"))
	var direction := str(installation.get("direction", ""))
	var player_index := int(installation.get("installer_player_index", -1))
	if owner_kind == "public":
		return direction == "demand" and player_index == -1
	return owner_kind == "player" and player_index >= 0


func _sum_claims(claims: Array) -> int:
	var total := 0
	for claim_variant in claims:
		total += maxi(0, int((claim_variant as Dictionary).get("milliunits", 0)))
	return total


func _index_by_id(rows_variant: Variant, field_name: String) -> Dictionary:
	var result: Dictionary = {}
	if not (rows_variant is Array):
		return result
	for row_variant in rows_variant:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		var row_id := str(row.get(field_name, ""))
		if not row_id.is_empty():
			result[row_id] = row
	return result


func _rank_table(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	for key_variant in (value as Dictionary).keys():
		var rank := _rank_number(key_variant)
		var amount := int((value as Dictionary).get(key_variant, 0))
		if rank >= 1 and rank <= 4 and amount > 0:
			result[rank] = amount
	return result


func _rank_number(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	match str(value).to_upper():
		"I": return 1
		"II": return 2
		"III": return 3
		"IV": return 4
	return 0


func _distance_premium_basis_points(distance: int) -> int:
	return mini(_distance_premium_maximum_bp, maxi(0, distance - 1) * _distance_premium_per_unit_bp)


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
		return true
	if value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
		return true
	return false


func _nonnegative_integer_dictionary(values: Dictionary) -> bool:
	for key_variant in values.keys():
		if str(key_variant).is_empty() or not (values[key_variant] is int) or int(values[key_variant]) < 0:
			return false
	return true


func _dictionary_total(values: Dictionary) -> int:
	var total := 0
	for value_variant in values.values():
		total += maxi(0, int(value_variant))
	return total


func _sale_receipt_save_record_valid(receipt: Dictionary) -> bool:
	return not str(receipt.get("receipt_id", "")).is_empty() \
		and int(receipt.get("units", 0)) == 1 \
		and not str(receipt.get("commodity_id", "")).is_empty() \
		and not str(receipt.get("source_region_id", "")).is_empty() \
		and not str(receipt.get("market_region_id", "")).is_empty() \
		and int(receipt.get("base_unit_price_cents", -1)) >= 0 \
		and int(receipt.get("unit_price_cents", -1)) >= 0 \
		and int(receipt.get("distance_premium_basis_points", -1)) >= 0
