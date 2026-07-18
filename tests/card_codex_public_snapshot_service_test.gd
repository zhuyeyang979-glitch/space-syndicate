extends SceneTree

const SOURCE_SCENE := preload("res://scenes/runtime/CardCodexPublicSourceService.tscn")
const SNAPSHOT_SCENE := preload("res://scenes/runtime/CardCodexPublicSnapshotService.tscn")
const FORBIDDEN_KEYS := [
	"owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan",
	"hand", "cash", "private_discard", "city_share", "project_share", "route_damage", "repair_routes",
	"direct_cash", "direct_gdp", "direct_region_damage", "play_cash_cost",
]
const RETIRED_TEXT := ["城市产权份额", "项目份额", "项目GDP", "签/拒", "路线HP", "商路伤害", "商路修复"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var snapshot := SNAPSHOT_SCENE.instantiate()
	var source := SOURCE_SCENE.instantiate()
	root.add_child(snapshot)
	root.add_child(source)
	snapshot.call("configure", {})
	var configured := source.call("configure", {"snapshot": snapshot}) as Dictionary
	_expect(bool(configured.get("service_ready", false)), "source service configures with v0.6 catalog")
	var debug := source.call("debug_snapshot") as Dictionary
	_expect(int(debug.get("public_catalog_card_count", 0)) == 348, "v0.6 public catalog exposes 348 cards")
	_expect(not bool(debug.get("reads_legacy_v04_catalog", true)), "legacy v0.4 catalog is absent from public source")
	var all_ids := source.call("ordered_card_ids", "all") as Array[String]
	_expect(all_ids.size() == 348, "all 348 public card ids retain catalog order")
	var commodity_ids := source.call("ordered_card_ids", "commodity") as Array[String]
	var ordinary_id := _first_non_commodity_with_asset_cost(source, all_ids)
	_expect(not commodity_ids.is_empty() and ordinary_id != "", "commodity and ordinary public cards both exist")
	var commodity := source.call("compose_card_facts", commodity_ids[0], 0) as Dictionary
	var ordinary := source.call("compose_card_facts", ordinary_id, 1) as Dictionary
	_expect(str(commodity.get("purchase_cost_text", "")) == "免费领取" and str(commodity.get("play_cost_text", "")) == "打出免费", "commodity cards are free to acquire and play")
	_expect(str(ordinary.get("purchase_cost_text", "")).begins_with("购买现金 ¥") and str(ordinary.get("play_cost_text", "")).begins_with("打出 "), "ordinary cards separate purchase cash from play assets")
	var browser := source.call("compose_browser", {
		"names": all_ids.slice(0, 8), "columns": 4, "rows": 2, "page_index": 0, "filter_id": "all",
		"selected_card": all_ids[0], "run_pool_count": 8, "district_supply_count": 0,
	}) as Dictionary
	var detail := source.call("compose_detail", ordinary_id, 1, all_ids.size()) as Dictionary
	_expect((browser.get("cards", []) as Array).size() == 8 and not (detail.get("detail", {}) as Dictionary).is_empty(), "real browser and detail snapshots compose")
	_expect(_is_pure_data(browser) and _is_pure_data(detail), "card public snapshots contain pure data only")
	_expect(not _contains_forbidden_key(browser) and not _contains_forbidden_key(detail), "card public snapshots exclude private and retired fields")
	_expect(not _contains_retired_text(browser) and not _contains_retired_text(detail), "card public UI excludes retired v0.4 wording")
	var rejected := source.call("compose_browser", {"filter_id": "all", "hidden_owner": "DO_NOT_LEAK"}) as Dictionary
	_expect(rejected.is_empty(), "private browser request fails closed before rendering")
	source.queue_free()
	snapshot.queue_free()
	await process_frame
	_finish()


func _first_non_commodity_with_asset_cost(source: Node, ids: Array[String]) -> String:
	for card_id: String in ids:
		var facts := source.call("compose_card_facts", card_id, -1) as Dictionary
		if bool(facts.get("valid", false)) and str(facts.get("category_id", "")) != "commodity" and str(facts.get("play_cost_text", "")) != "打出免费":
			return card_id
	return ""


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


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if FORBIDDEN_KEYS.has(str(key_variant).to_lower()) or _contains_forbidden_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _contains_retired_text(value: Variant) -> bool:
	if value is String or value is StringName:
		for token: String in RETIRED_TEXT:
			if str(value).contains(token):
				return true
	elif value is Dictionary:
		for key_variant: Variant in value:
			if _contains_retired_text(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_retired_text(item_variant):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CARD CODEX PUBLIC SNAPSHOT SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("CARD CODEX PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	print("CARD CODEX PUBLIC SNAPSHOT SERVICE FAIL: %d | %s" % [failures.size(), JSON.stringify(failures)])
	quit(1)
