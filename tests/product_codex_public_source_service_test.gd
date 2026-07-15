extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const SOURCE_SERVICE_SCENE := "res://scenes/runtime/ProductCodexPublicSourceService.tscn"
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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "main scene loads")
	_main = packed.instantiate() as Control if packed != null else null
	_expect(_main != null, "main scene instantiates")
	if _main == null:
		_finish()
		return
	root.add_child(_main)
	await process_frame
	await process_frame
	if _main.has_method("_new_game"):
		_main.call("_new_game")
	await process_frame
	await process_frame
	var coordinator := _coordinator()
	_expect(coordinator != null, "coordinator is present")
	var service := coordinator.get_node_or_null("ProductCodexPublicSourceService") if coordinator != null else null
	_expect(service != null and service.scene_file_path == SOURCE_SERVICE_SCENE, "ProductCodexPublicSourceService is the unique scene-owned source")
	_expect(service != null and service.has_method("compose_detail_source") and service.has_method("compose_browser_snapshot") and service.has_method("public_field_schema") and service.has_method("debug_snapshot"), "Product source service exposes public source APIs")
	var debug: Dictionary = service.call("debug_snapshot") if service != null else {}
	_expect(bool(debug.get("service_ready", false)) and bool(debug.get("service_authoritative", false)), "Product source service is configured through Coordinator")
	_expect(not bool(debug.get("owns_rules", true)) and not bool(debug.get("owns_save_state", true)) and not bool(debug.get("reads_player_state", true)) and not bool(debug.get("reads_private_inventory", true)) and not bool(debug.get("reads_ai_plan", true)) and not bool(debug.get("reads_market_quote", true)) and not bool(debug.get("reads_camera", true)) and not bool(debug.get("reads_solar", true)), "Product source service owns no rules/save/private/quote/camera/solar state")
	var product_name := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
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
	var before := JSON.stringify(detail)
	_mutate_private_viewer_state()
	var after: Dictionary = coordinator.call("product_codex_public_detail_snapshot", product_name, 0, true)
	_expect(before == JSON.stringify(after), "cash/hand/discard/hidden owner/city guesses/AI plan/selected state do not change public Product Codex detail")
	var market_controller := coordinator.get_node_or_null("ProductMarketRuntimeController") if coordinator != null else null
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
	_main.queue_free()
	_main = null
	await process_frame
	_finish()


func _coordinator() -> Node:
	return _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null


func _mutate_private_viewer_state() -> void:
	if _main == null:
		return
	var players_variant: Variant = _main.get("players")
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
		_main.set("players", players)
	_main.set("selected_player", 2)
	_main.set("selected_district", 3)


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
