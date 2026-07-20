@tool
extends Node
class_name TableSelectionCatalogQueryPort

const REGION_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/public_region_selection_catalog_snapshot.gd")
const PRODUCT_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/public_product_selection_catalog_snapshot.gd")
const SOURCE_KEYS := ["schema_version", "available", "unavailable_reason", "entries"]
const SESSION_READY_STATES := [
	GameSessionRuntimeController.STATE_RUNNING,
	GameSessionRuntimeController.STATE_PAUSED,
	GameSessionRuntimeController.STATE_FINISHED,
]

@export var world_session_state_path: NodePath
@export var product_market_runtime_controller_path: NodePath
@export var game_session_runtime_controller_path: NodePath


func compose_region_catalog() -> REGION_SNAPSHOT_SCRIPT:
	var session_context := _active_session_context()
	if not bool(session_context.get("ready", false)):
		return _unavailable_region(str(session_context.get("reason_code", "pre_session")))
	var world_session := _world_session_state()
	if world_session == null:
		return _unavailable_region("world_session_unavailable", session_context)
	var source := world_session.public_region_selection_catalog_source()
	if not _source_contract_valid(source):
		return _unavailable_region("region_source_invalid", session_context)
	var source_available: bool = source["available"]
	var snapshot: REGION_SNAPSHOT_SCRIPT = REGION_SNAPSHOT_SCRIPT.new().build(
		source_available,
		str(source["unavailable_reason"]),
		source["entries"] as Array,
		str(session_context["session_id"]),
		int(session_context["session_revision"]),
		source_available
	)
	return snapshot if snapshot.is_valid() else _unavailable_region("region_source_invalid", session_context)


func compose_product_catalog() -> PRODUCT_SNAPSHOT_SCRIPT:
	var session_context := _active_session_context()
	if not bool(session_context.get("ready", false)):
		return _unavailable_product(str(session_context.get("reason_code", "pre_session")))
	var product_market := _product_market_runtime_controller()
	if product_market == null:
		return _unavailable_product("product_market_unavailable", session_context)
	var source := product_market.public_product_selection_catalog_source()
	if not _source_contract_valid(source) or (source["entries"] as Array).size() != ProductMarketRuntimeController.PRODUCT_CATALOG.size():
		return _unavailable_product("product_source_invalid", session_context)
	var source_available: bool = source["available"]
	var snapshot: PRODUCT_SNAPSHOT_SCRIPT = PRODUCT_SNAPSHOT_SCRIPT.new().build(
		source_available,
		str(source["unavailable_reason"]),
		source["entries"] as Array,
		str(session_context["session_id"]),
		int(session_context["session_revision"]),
		source_available
	)
	return snapshot if snapshot.is_valid() else _unavailable_product("product_source_invalid", session_context)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": _world_session_state() != null and _product_market_runtime_controller() != null and _game_session_runtime_controller() != null,
		"stateless": true,
		"read_only": true,
		"references_main": false,
		"owns_region_catalog": false,
		"owns_product_catalog": false,
		"owns_save_schema": false,
		"reads_table_selection": false,
		"reads_commodity_slots": false,
		"submits_commodity_claims": false,
		"region_authority": "WorldSessionState",
		"product_authority": "ProductMarketRuntimeController.PRODUCT_CATALOG",
		"session_authority": "GameSessionRuntimeController",
	}


func _world_session_state() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _product_market_runtime_controller() -> ProductMarketRuntimeController:
	return get_node_or_null(product_market_runtime_controller_path) as ProductMarketRuntimeController


func _game_session_runtime_controller() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController


func _active_session_context() -> Dictionary:
	var game_session := _game_session_runtime_controller()
	if game_session == null:
		return {"ready": false, "reason_code": "game_session_unavailable"}
	var summary := game_session.session_summary()
	if not TablePresentationPureDataPolicy.is_pure_data(summary) \
		or not summary.has("session_id") \
		or typeof(summary["session_id"]) != TYPE_STRING \
		or not summary.has("session_state") \
		or typeof(summary["session_state"]) != TYPE_STRING:
		return {"ready": false, "reason_code": "session_identity_invalid"}
	var session_id := str(summary["session_id"]).strip_edges()
	var session_state := str(summary["session_state"]).strip_edges()
	var session_revision := game_session.session_start_revision()
	if session_id.is_empty() or not SESSION_READY_STATES.has(session_state) or session_revision <= 0:
		return {"ready": false, "reason_code": "pre_session"}
	return {
		"ready": true,
		"reason_code": "",
		"session_id": session_id,
		"session_revision": session_revision,
	}


func _source_contract_valid(source: Dictionary) -> bool:
	if not TablePresentationPureDataPolicy.is_pure_data(source):
		return false
	for key_variant in source.keys():
		if not SOURCE_KEYS.has(str(key_variant)):
			return false
	return source.size() == SOURCE_KEYS.size() \
		and source.has("schema_version") and typeof(source["schema_version"]) == TYPE_INT and int(source["schema_version"]) == 1 \
		and source.has("available") and typeof(source["available"]) == TYPE_BOOL \
		and source.has("unavailable_reason") and typeof(source["unavailable_reason"]) == TYPE_STRING \
		and source.has("entries") and source["entries"] is Array


func _unavailable_region(reason_code: String, session_context: Dictionary = {}) -> REGION_SNAPSHOT_SCRIPT:
	return REGION_SNAPSHOT_SCRIPT.new().build(
		false,
		reason_code,
		[],
		str(session_context.get("session_id", "")),
		int(session_context.get("session_revision", 0)),
		false
	)


func _unavailable_product(reason_code: String, session_context: Dictionary = {}) -> PRODUCT_SNAPSHOT_SCRIPT:
	return PRODUCT_SNAPSHOT_SCRIPT.new().build(
		false,
		reason_code,
		[],
		str(session_context.get("session_id", "")),
		int(session_context.get("session_revision", 0)),
		false
	)
