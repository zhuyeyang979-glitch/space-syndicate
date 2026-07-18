extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const TRACK_SCENE := preload("res://scenes/ui/table/TopCommoditySushiTrack.tscn")
const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")
const REQUEST_SCRIPT := preload("res://scripts/runtime/commodity_sushi_track_claim_request.gd")
const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_snapshot.gd")

const PRIVATE_TOKENS := [
	"private_rival_cash_987654",
	"private_rival_hand_canary",
	"private_ai_plan_canary",
	"hidden_owner_canary",
]

class RuntimeWorld:
	extends Node
	var players: Array = [
		{
			"id": 0,
			"name": "Current Player",
			"seat_type": "human",
			"is_ai": false,
			"cash": 1000,
			"cash_cents": 100000,
			"slots": [],
		},
		{
			"id": 1,
			"name": "Private Rival",
			"seat_type": "ai",
			"is_ai": true,
			"cash": 987654,
			"cash_cents": 98765400,
			"slots": [{"name": "private_rival_hand_canary"}],
			"ai_plan": "private_ai_plan_canary",
			"hidden_owner": "hidden_owner_canary",
		},
	]
	var game_time := 0.0
	var map_width_m := 1000.0
	var districts: Array = [
		{
			"name": "Alpha",
			"region_id": "region.alpha",
			"center": Vector2.ZERO,
			"neighbors": [],
			"destroyed": false,
		},
	]
	var monster_runtime_controller: Node = null


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	coordinator.configure(RULESET_V04.debug_snapshot())
	var world := RuntimeWorld.new()
	root.add_child(world)
	coordinator.bind_ai_world(world)
	coordinator.world_session_state().replace_players(world.players, true)
	coordinator.world_session_state().replace_districts(world.districts, true)
	coordinator.refresh_v06_production_player_bindings(world)
	await process_frame

	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var service := coordinator.get_node_or_null("CommoditySushiTrackRuntimeService")
	var product_market := coordinator.get_node_or_null("ProductMarketRuntimeController")
	var rng := coordinator.run_rng_service()
	_expect(inventory != null and service != null and product_market != null and rng != null, "production commodity track dependencies exist")
	_expect(coordinator.find_children("CommoditySushiTrackRuntimeService", "Node", true, false).size() == 1, "production composition has one commodity track projection service")
	if inventory == null or service == null or product_market == null or rng == null:
		await _finish(coordinator, world, null)
		return

	var owner_before: Dictionary = inventory.belt_snapshot()
	var owner_items_before: Dictionary = owner_before.get("items", {}) if owner_before.get("items", {}) is Dictionary else {}
	_expect(int(owner_before.get("revision", 0)) == 1 and owner_items_before.size() == 8, "default shared belt deterministically seeds eight real commodity cards")
	var snapshot_zero: SNAPSHOT_SCRIPT = service.public_snapshot(0)
	var snapshot_one: SNAPSHOT_SCRIPT = service.public_snapshot(1)
	print("COMMODITY_SUSHI_TRACK_DIAG|actors=%s|viewer0=%s|viewer1=%s" % [
		JSON.stringify(coordinator.card_player_state_production_adapter_v06().actor_player_indices()),
		JSON.stringify(snapshot_zero.to_dictionary()),
		JSON.stringify(snapshot_one.to_dictionary()),
	])
	_expect(snapshot_zero != null and snapshot_zero.is_valid() and snapshot_zero.available and snapshot_zero.items.size() == 8, "viewer zero receives a valid eight-item public snapshot")
	_expect(snapshot_one != null and snapshot_one.is_valid() and snapshot_one.items.size() == 8, "viewer one receives the same shared public belt")
	if snapshot_zero == null or snapshot_zero.items.is_empty():
		await _finish(coordinator, world, null)
		return
	_expect(_public_items(snapshot_zero) == _public_items(snapshot_one), "shared commodity facts are viewer invariant")
	_expect(not _contains_private_token(snapshot_zero.to_dictionary()), "public commodity projection contains no rival cash, hand, hidden owner, or AI plan")
	var service_debug: Dictionary = service.debug_snapshot()
	_expect(not bool(service_debug.get("owns_belt_state", true)) and not bool(service_debug.get("owns_market_state", true)) and not service.has_method("to_save_data"), "projection service owns no belt, market, or save state")

	var track := TRACK_SCENE.instantiate()
	root.add_child(track)
	track.size = Vector2(1200.0, 170.0)
	await process_frame
	var empty_snapshot := _snapshot_dictionary(10, 1, [])
	_expect(track.set_snapshot_dictionary(empty_snapshot), "empty public snapshot renders an explicit empty state")
	_expect(int(track.debug_snapshot().get("rendered_item_count", -1)) == 0, "empty state renders no commodity item nodes")
	var display_snapshot := snapshot_zero.to_dictionary()
	display_snapshot["snapshot_revision"] = 11
	_expect(track.set_snapshot_dictionary(display_snapshot), "many-item snapshot renders on the production track scene")
	var rendered_once: Dictionary = track.debug_snapshot()
	_expect(int(rendered_once.get("rendered_item_count", -1)) == 8 and int(rendered_once.get("created_node_count", -1)) == 8, "eight stable commodity nodes are created once")
	var first_item := snapshot_zero.items[0]
	var item_node := track.find_child("CommoditySlot_%s" % _safe_node_name(first_item.commodity_slot_id), true, false)
	_expect(item_node != null, "stable commodity slot id maps to one production item node")
	var focused_items: Array = []
	var claim_items: Array = []
	track.item_focused.connect(func(item): focused_items.append(item.to_dictionary()))
	track.claim_requested.connect(func(item): claim_items.append(item.to_dictionary()))
	if item_node != null:
		item_node.call("_emit_focus")
		var claim_button := item_node.get_node_or_null("ItemRows/CommodityClaimButton") as Button
		if claim_button != null:
			claim_button.pressed.emit()
	_expect(focused_items.size() >= 1 and str((focused_items[0] as Dictionary).get("commodity_slot_id", "")) == first_item.commodity_slot_id, "hover or focus emits the typed public item")
	_expect(claim_items.size() == 1 and str((claim_items[0] as Dictionary).get("commodity_slot_id", "")) == first_item.commodity_slot_id, "claim button emits one typed request intent without mutating the owner")
	_expect(JSON.stringify(inventory.belt_snapshot()) == JSON.stringify(owner_before), "rendering, hover, and UI claim intent do not mutate gameplay")

	var updated_display := display_snapshot.duplicate(true)
	updated_display["snapshot_revision"] = 12
	var updated_items: Array = (updated_display.get("items", []) as Array).duplicate(true)
	var updated_first: Dictionary = (updated_items[0] as Dictionary).duplicate(true)
	updated_first["public_demand_pressure"] = int(updated_first.get("public_demand_pressure", 0)) + 3
	updated_items[0] = updated_first
	updated_display["items"] = updated_items
	_expect(track.set_snapshot_dictionary(updated_display), "newer public values update the track")
	var rendered_twice: Dictionary = track.debug_snapshot()
	_expect(int(rendered_twice.get("created_node_count", -1)) == 8 and int(rendered_twice.get("reused_node_count", 0)) >= 8, "value refresh reuses every same-id item node")
	var stale_display := display_snapshot.duplicate(true)
	var state_before_stale: Dictionary = track.debug_snapshot()
	_expect(not track.set_snapshot_dictionary(stale_display) and track.debug_snapshot().get("rendered_slot_ids", []) == state_before_stale.get("rendered_slot_ids", []), "stale revision fails closed without changing rendered slots")
	var duplicate_display := updated_display.duplicate(true)
	duplicate_display["snapshot_revision"] = 13
	var duplicate_items: Array = (duplicate_display.get("items", []) as Array).duplicate(true)
	duplicate_items.append((duplicate_items[0] as Dictionary).duplicate(true))
	duplicate_display["items"] = duplicate_items
	_expect(not track.set_snapshot_dictionary(duplicate_display) and int(track.debug_snapshot().get("rendered_item_count", -1)) == 8, "duplicate stable ids fail closed without rebuilding the track")

	var rng_before := JSON.stringify(rng.debug_snapshot())
	var market_before := JSON.stringify(product_market.public_market_snapshot())
	var player_before: Dictionary = inventory.player_snapshot("player.0")
	var card_count_before := _card_count(player_before)
	var request: REQUEST_SCRIPT = _request_for(snapshot_zero, first_item, 1)
	var claim_result: Dictionary = service.claim(request)
	_expect(bool(claim_result.get("success", false)), "typed claim commits through the authoritative inventory owner")
	var player_after: Dictionary = inventory.player_snapshot("player.0")
	_expect(int(player_after.get("cash", -1)) == int(player_before.get("cash", -2)) and _card_count(player_after) == card_count_before + 1, "free claim adds one card and changes no cash")
	_expect(JSON.stringify(product_market.public_market_snapshot()) == market_before and JSON.stringify(rng.debug_snapshot()) == rng_before, "claim does not refresh the market or consume RNG")
	var snapshot_after: SNAPSHOT_SCRIPT = service.public_snapshot(0)
	_expect(snapshot_after.is_valid() and snapshot_after.items.size() == 7 and snapshot_after.snapshot_revision > snapshot_zero.snapshot_revision, "owner commit advances the authoritative public snapshot")
	var replay: Dictionary = service.claim(request)
	_expect(bool(replay.get("success", false)) and bool(replay.get("idempotent_replay", false)) and _card_count(inventory.player_snapshot("player.0")) == card_count_before + 1, "duplicate typed request replays without a second card")
	var stale_request: REQUEST_SCRIPT = _request_for(snapshot_zero, snapshot_zero.items[1], 2)
	var belt_before_stale := JSON.stringify(inventory.belt_snapshot())
	var stale_result: Dictionary = service.claim(stale_request)
	_expect(not bool(stale_result.get("success", true)) and str(stale_result.get("failure_code", "")) == "snapshot_stale", "claim bound to an old public snapshot fails closed")
	_expect(JSON.stringify(inventory.belt_snapshot()) == belt_before_stale, "failed stale claim leaves the owner belt unchanged")

	await _finish(coordinator, world, track)


func _snapshot_dictionary(revision: int, belt_revision: int, items: Array) -> Dictionary:
	return {
		"schema_version": 1,
		"available": true,
		"snapshot_revision": revision,
		"belt_revision": belt_revision,
		"visibility_revision": 1,
		"market_revision": 0,
		"public_refresh_phase": "市场周期 0",
		"items": items.duplicate(true),
		"empty_text": "商品带已领空，等待权威补货。",
	}


func _request_for(snapshot: SNAPSHOT_SCRIPT, item, revision: int) -> REQUEST_SCRIPT:
	var request: REQUEST_SCRIPT = REQUEST_SCRIPT.new()
	request.viewer_index = 0
	request.commodity_slot_id = item.commodity_slot_id
	request.commodity_card_id = item.commodity_card_id
	request.snapshot_revision = snapshot.snapshot_revision
	request.belt_revision = snapshot.belt_revision
	request.visibility_revision = snapshot.visibility_revision
	request.request_revision = revision
	return request


func _public_items(snapshot: SNAPSHOT_SCRIPT) -> Array:
	var result: Array = []
	for item in snapshot.items:
		result.append(item.to_dictionary())
	return result


func _contains_private_token(value: Variant) -> bool:
	var text := JSON.stringify(value).to_lower()
	for token in PRIVATE_TOKENS:
		if text.contains(token.to_lower()):
			return true
	for forbidden_key in ["player_index", "cash", "cash_cents", "hand", "private", "hidden_owner", "ai_plan"]:
		if text.contains('"%s"' % forbidden_key):
			return true
	return false


func _card_count(player: Dictionary) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and not (slot_variant as Dictionary).is_empty():
			count += 1
	return count


func _safe_node_name(value: String) -> String:
	return value.replace(".", "_").replace(":", "_").replace("/", "_")


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("COMMODITY SUSHI TRACK: %s" % label)


func _finish(coordinator: Node, world: Node, track: Node) -> void:
	if track != null:
		track.queue_free()
	if coordinator != null:
		coordinator.queue_free()
	if world != null:
		world.queue_free()
	await process_frame
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("COMMODITY_SUSHI_TRACK_RUNTIME_TEST|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
