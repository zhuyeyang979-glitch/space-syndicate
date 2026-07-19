extends SceneTree

const SESSION_START_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const SOURCE_SERVICE_SCENE := "res://scenes/runtime/ProductCodexPublicSourceService.tscn"
const QA_SAVE_PATH := "user://test_runs/product_codex_public_source_service.save"
const DELETED_MAIN_HELPERS := [
	"_product_codex_grid_text",
	"_product_codex_browser_snapshot",
	"_product_codex_public_source_snapshot",
	"_product_codex_public_snapshot",
	"_product_warehouse_public_facts",
	"_product_related_card_name_facts",
	"_product_monster_focus_name_facts",
	"_product_related_district_name_facts",
	"_product_public_clue_facts",
	"_sort_product_warehouse_entry",
]

var failures: Array[String] = []
var _main: Control
var _coordinator_node: GameRuntimeCoordinator
var _world_session: WorldSessionState
var _selection: TableSelectionState


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_qa_save()
	_test_unconfigured_service_fails_closed()
	var start_result := await SESSION_START_DRIVER.start_default_session(self, QA_SAVE_PATH, "product-codex-public-source")
	_main = start_result.get("main_root") as Control
	_coordinator_node = start_result.get("coordinator") as GameRuntimeCoordinator
	_world_session = start_result.get("world_session") as WorldSessionState
	_assert_formal_session_start(start_result, 4)
	if _main == null or not bool(start_result.get("started", false)):
		await _cleanup()
		_finish()
		return
	var coordinator := _coordinator()
	_expect(coordinator != null, "coordinator is present")
	_selection = coordinator.table_selection_state() if coordinator != null else null
	var service := coordinator.get_node_or_null("ProductCodexPublicSourceService") if coordinator != null else null
	_expect(service != null and service.scene_file_path == SOURCE_SERVICE_SCENE, "ProductCodexPublicSourceService is the unique scene-owned source")
	_expect(service != null and service.has_method("compose_detail_source") and service.has_method("compose_browser_snapshot") and service.has_method("public_field_schema") and service.has_method("debug_snapshot"), "Product source service exposes public source APIs")
	var debug: Dictionary = service.call("debug_snapshot") if service != null else {}
	_expect(bool(debug.get("service_ready", false)) and bool(debug.get("service_authoritative", false)), "Product source service is configured through Coordinator")
	_expect(not bool(debug.get("owns_rules", true)) and not bool(debug.get("owns_save_state", true)) and not bool(debug.get("reads_player_state", true)) and not bool(debug.get("reads_private_inventory", true)) and not bool(debug.get("reads_ai_plan", true)) and not bool(debug.get("reads_market_quote", true)) and not bool(debug.get("reads_camera", true)) and not bool(debug.get("reads_solar", true)), "Product source service owns no rules/save/private/quote/camera/solar state")
	var product_name := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	var market_controller := coordinator.get_node_or_null("ProductMarketRuntimeController") if coordinator != null else null
	var rng_service := coordinator.get_node_or_null("RunRngService") if coordinator != null else null
	var route_controller := coordinator.get_node_or_null("RouteNetworkRuntimeController") if coordinator != null else null
	var session_controller := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var market_before_read := JSON.stringify(market_controller.call("runtime_state_snapshot"))
	var rng_before_read := JSON.stringify(rng_service.call("debug_snapshot"))
	var route_before_read := JSON.stringify(route_controller.call("debug_snapshot"))
	var session_before_read := JSON.stringify(session_controller.call("debug_snapshot"))
	var source: Dictionary = service.call("compose_detail_source", product_name, 0, true)
	var detail: Dictionary = coordinator.call("product_codex_public_detail_snapshot", product_name, 0, true)
	var browser: Dictionary = coordinator.call("product_codex_public_browser_snapshot", {
		"start_index": 0,
		"end_index": mini(6, ProductMarketRuntimeController.PRODUCT_CATALOG.size()),
		"selected_index": 0,
		"columns": 3,
		"can_page": ProductMarketRuntimeController.PRODUCT_CATALOG.size() > 6,
		"page_label": "测试商品目录",
	})
	_expect(bool(source.get("valid", false)) and not source.has("cash") and not source.has("hand") and not source.has("owner") and not source.has("quote"), "detail source is public and excludes private keys")
	_expect(_is_pure_data(source) and _is_pure_data(detail) and _is_pure_data(browser), "Product source/detail/browser snapshots are pure data")
	_expect(not _contains_private_key(source) and not _contains_private_key(detail) and not _contains_private_key(browser), "Product public outputs recursively exclude private keys")
	_expect(not (browser.get("entries", []) as Array).is_empty() and browser.get("preview", {}) is Dictionary, "browser snapshot has entries and preview")
	_expect(market_before_read == JSON.stringify(market_controller.call("runtime_state_snapshot")), "opening Product Codex does not initialize or mutate ProductMarket")
	_expect(rng_before_read == JSON.stringify(rng_service.call("debug_snapshot")), "opening Product Codex consumes no RNG")
	_expect(route_before_read == JSON.stringify(route_controller.call("debug_snapshot")), "opening Product Codex rebuilds no route topology")
	_expect(session_before_read == JSON.stringify(session_controller.call("debug_snapshot")), "opening Product Codex does not dirty save/session state")
	_expect(not _contains_private_market_position(source) and not _contains_private_market_position(detail) and not _contains_private_market_position(browser), "futures and warehouse positions never enter Product Codex output")
	var source_script := FileAccess.get_file_as_string("res://scripts/runtime/product_codex_public_source_service.gd")
	_expect(not source_script.contains("ensure_catalog") and not source_script.contains("market_entry(") and not source_script.contains("product_price("), "Product Codex uses a read-only market projection only")
	var before := JSON.stringify(detail)
	_mutate_private_viewer_state()
	var after: Dictionary = coordinator.call("product_codex_public_detail_snapshot", product_name, 0, true)
	_expect(before == JSON.stringify(after), "cash/hand/discard/hidden owner/city guesses/AI plan/selected state do not change public Product Codex detail")
	var before_market: Dictionary = coordinator.call("product_codex_public_detail_snapshot", product_name, 0, true)
	if market_controller != null and market_controller.has_method("apply_product_market_boon"):
		market_controller.call("apply_product_market_boon", product_name, 1.25, 1.0, 5, "product_codex_public_test", false, 30.0)
	var after_market: Dictionary = coordinator.call("product_codex_public_detail_snapshot", product_name, 0, true)
	_expect(JSON.stringify(before_market) != JSON.stringify(after_market) and str(after_market.get("summary_text", "")).contains(product_name), "public ProductMarket owner changes can alter Product Codex public fields")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var deleted := true
	for helper in DELETED_MAIN_HELPERS:
		deleted = deleted and not main_source.contains("func %s(" % helper)
	_expect(deleted and coordinator.has_method("product_codex_public_browser_snapshot") and coordinator.has_method("product_codex_public_detail_snapshot") and not coordinator.has_method("compose_product_codex_snapshot"), "legacy Main Product Codex helpers and generic source proxy are absent")
	await _cleanup()
	_finish()


func _coordinator() -> Node:
	return _coordinator_node


func _test_unconfigured_service_fails_closed() -> void:
	var packed := load(SOURCE_SERVICE_SCENE) as PackedScene
	_expect(packed != null, "standalone Product source scene loads")
	var service := packed.instantiate() if packed != null else null
	_expect(service != null, "standalone Product source service instantiates")
	if service == null:
		return
	var product_name := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	_expect((service.call("compose_detail_source", product_name, 0, true) as Dictionary).is_empty(), "unconfigured detail source fails closed")
	_expect((service.call("compose_browser_snapshot", {"start_index": 0, "end_index": 1, "selected_index": 0, "columns": 1, "can_page": false, "page_label": ""}) as Dictionary).is_empty(), "unconfigured browser source fails closed")
	var debug := service.call("debug_snapshot") as Dictionary
	_expect(not bool(debug.get("service_ready", true)) and str(debug.get("last_error", "")) != "", "unconfigured source reports unavailable without initializing runtime")
	service.free()


func _assert_formal_session_start(start_result: Dictionary, expected_players: int) -> void:
	_expect(bool(start_result.get("qa_save_override_ready", false)), "driver installs QA save override before tree entry")
	_expect(bool(start_result.get("started", false)), "formal session start succeeds|reason=%s" % start_result.get("reason_code", ""))
	var receipt := start_result.get("receipt") as SessionStartReceipt
	_expect(receipt != null and receipt.applied, "formal session receipt is applied")
	_expect(int(start_result.get("main_start_call_count", -1)) == 0, "formal fixture calls no Main start method")
	_expect(int(start_result.get("setup_fallback_count", -1)) == 0, "formal fixture uses no setup fallback")
	_expect(_world_session != null and _world_session.players.size() == expected_players, "formal world has expected player count")
	var operation: Dictionary = start_result.get("transaction_snapshot", {})
	_expect(str(operation.get("operation_state", "")) == "succeeded" and int(operation.get("terminal_request_count", 0)) == 1 and not bool(operation.get("references_main", true)), "formal session transaction commits exactly once without Main")
	var game_session := start_result.get("game_session") as GameSessionRuntimeController
	_expect(game_session != null and str(game_session.session_summary().get("session_state", "")) == "running", "formal game session is running")


func _mutate_private_viewer_state() -> void:
	if _world_session == null:
		return
	var players_variant: Variant = _world_session.players
	if players_variant is Array and not (players_variant as Array).is_empty():
		var players := players_variant as Array
		var player := (players[0] as Dictionary).duplicate(true) if players[0] is Dictionary else {}
		player["cash"] = 999999
		player["hand"] = ["PRIVATE_SENTINEL_HAND"]
		player["discard"] = ["PRIVATE_SENTINEL_DISCARD"]
		player["city_guesses"] = {"PRIVATE_SENTINEL_CITY": 1}
		player["hidden_owner"] = "PRIVATE_SENTINEL_OWNER"
		player["ai_plan"] = "PRIVATE_SENTINEL_AI"
		players[0] = player
		_world_session.players = players
	if _selection != null:
		_selection.selected_player = 2
		_selection.selected_district = 3


func _cleanup() -> void:
	if _main != null:
		_main.queue_free()
	_main = null
	_coordinator_node = null
	_world_session = null
	_selection = null
	await process_frame
	await process_frame
	_cleanup_qa_save()


func _cleanup_qa_save() -> void:
	for path in [QA_SAVE_PATH, QA_SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant).to_lower()
			if key in ["viewer", "selected_player", "selected_district", "player", "players", "cash", "hand", "discard", "private_inventory", "owner", "owner_id", "owner_index", "owner_player_index", "hidden_owner", "hidden_owner_id", "city_guesses", "private_plan", "ai_plan", "ai_private_plan", "quote", "quote_id", "quote_fingerprint", "camera"]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant):
				return true
	elif value is String or value is StringName:
		return str(value).find("PRIVATE_SENTINEL") >= 0
	return false


func _contains_private_market_position(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant).to_lower()
			if key.contains("futures") or key.contains("warehouse") or key in ["units", "location", "expiry", "expires_at"]:
				return true
			if _contains_private_market_position(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_market_position(item_variant):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PRODUCT CODEX PUBLIC SOURCE SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCT CODEX PUBLIC SOURCE SERVICE PASS")
		quit(0)
		return
	print("PRODUCT CODEX PUBLIC SOURCE SERVICE FAIL: %d" % failures.size())
	quit(1)
