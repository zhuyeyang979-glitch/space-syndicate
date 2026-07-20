extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/district_supply_surface_query_cutover.save"
const HUMAN_CASH_SENTINEL := 4317
const RIVAL_CASH_SENTINEL := 987654321
const RIVAL_HAND_SENTINEL := "DISTRICT_SUPPLY_RIVAL_PRIVATE_HAND"
const RIVAL_DISCARD_SENTINEL := "DISTRICT_SUPPLY_RIVAL_PRIVATE_DISCARD"
const RIVAL_PLAN_SENTINEL := "DISTRICT_SUPPLY_RIVAL_AI_PLAN"
const RIVAL_OWNER_SENTINEL := "DISTRICT_SUPPLY_RIVAL_OWNER_TRUTH"

const FORBIDDEN_PRESENTATION_KEYS := [
	"cash",
	"cash_cents",
	"hand",
	"hand_count",
	"hand_limit",
	"purchase_window",
	"true_owner",
	"owner_truth",
	"ai_plan",
	"ai_reason",
	"ai_utility_score",
	"route_plan_score",
	"pressure_bucket",
	"learning_bonus",
	"decision_samples",
	"quote_id",
	"quote_key",
	"quote_fingerprint",
	"quote_binding_fingerprint",
	"supply_revision",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 960)
	var start: Dictionary = await SESSION_DRIVER.start_configured_session(
		self,
		{
			"player_count": 3,
			"ai_player_count": 2,
			"challenge_depth": 1,
			"role_indices": [0, 1, 2],
			"starter_monster_indices": [0, 1, 2],
		},
		QA_SAVE_PATH,
		"district-supply-surface-query-cutover"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start.get("started", false)) and app_root != null and coordinator != null, "formal session transaction starts the production table")
	if app_root == null or coordinator == null or not bool(start.get("started", false)):
		if app_root != null:
			app_root.queue_free()
		_finish()
		return
	coordinator.pause_session()
	await _wait_frames(2)
	var query := coordinator.get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort if coordinator != null else null
	var viewmodel := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery if coordinator != null else null
	var presentation := coordinator.card_supply_presentation_state() if coordinator != null else null
	var region_supply := coordinator.get_node_or_null("RegionSupplyRuntimeController") as RegionSupplyRuntimeController if coordinator != null else null
	var pricing := coordinator.get_node_or_null("CardMarketPricingRuntimeController") as CardMarketPricingRuntimeController if coordinator != null else null
	var inventory := coordinator.get_node_or_null("CardInventoryRuntimeService") as CardInventoryRuntimeService if coordinator != null else null
	var screen := app_root.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer if screen != null else null
	_expect(query != null and viewmodel != null and presentation != null, "scene-owned query and presentation state are composed")
	_expect(region_supply != null and pricing != null and inventory != null, "query dependencies remain the unique production owners")
	_expect(screen != null and overlay != null, "typed GameScreen and Overlay targets are composed")
	if query == null or viewmodel == null or presentation == null or region_supply == null or pricing == null or inventory == null or screen == null or overlay == null:
		app_root.queue_free()
		await process_frame
		_finish()
		return

	var world := coordinator.world_session_state()
	_expect(world.players.size() == 3, "one human and two AI seats exist")
	var district_index := _first_rack_district(world, region_supply)
	_expect(district_index >= 0, "at least one authoritative public rack is available")
	if district_index < 0:
		app_root.queue_free()
		await process_frame
		_finish()
		return

	var human := (world.players[0] as Dictionary).duplicate(true)
	human["cash"] = HUMAN_CASH_SENTINEL
	world.players[0] = human
	presentation.open_district = district_index
	presentation.open_player = 0
	var district: Dictionary = world.districts[district_index] if world.districts[district_index] is Dictionary else {}
	var rack := region_supply.public_rack_snapshot(str(district.get("region_id", "")))
	var rack_rows: Array = rack.get("regions", []) if rack.get("regions", []) is Array else []
	var rack_revision := str((rack_rows[0] as Dictionary).get("rack_revision", "")) if not rack_rows.is_empty() and rack_rows[0] is Dictionary else ""
	coordinator.open_district_purchase_window(0, district_index, {"supply_revision": rack_revision})
	var context := coordinator.get_node("TablePresentationQueryPorts").viewer_context() as TablePresentationViewerContext
	var supply_before := region_supply.to_save_data()
	var pricing_before := pricing.debug_snapshot()
	var inventory_before := inventory.debug_snapshot()
	var presentation_before := presentation.snapshot()
	var private_surface := query.snapshot_for_viewer(0)
	var supply_after := region_supply.to_save_data()
	var pricing_after := pricing.debug_snapshot()
	var inventory_after := inventory.debug_snapshot()
	_expect(supply_before == supply_after, "query does not reshuffle, refill, or advance rack RNG")
	_expect(pricing_before == pricing_after, "query does not create or authorize a quote")
	_expect(inventory_before == inventory_after, "read-only inventory preview does not change diagnostics or inventory")
	_expect(presentation_before == presentation.snapshot(), "query does not mutate selected or previewed card state")
	_expect(bool(private_surface.get("visible", false)) and str(private_surface.get("visibility_scope", "")) == "viewer_private", "local human receives a visible private surface")
	_expect(int(private_surface.get("viewer_index", -1)) == 0 and int(private_surface.get("authorization_revision", 0)) == context.authorization_revision, "surface is bound to the current viewer authorization")
	var private_snapshot: Dictionary = private_surface.get("snapshot", {}) if private_surface.get("snapshot", {}) is Dictionary else {}
	var private_text := JSON.stringify(private_snapshot)
	_expect(str(private_snapshot.get("visibility_scope", "")) == "viewer_private", "formatted drawer retains viewer-private scope")
	_expect(private_text.contains("¥%d" % HUMAN_CASH_SENTINEL), "private drawer contains only the local human's exact cash summary")
	_expect(not private_text.contains("quote_fingerprint") and not private_text.contains("supply_revision"), "private drawer strips quote credentials and internal supply revisions")

	var rival := (world.players[1] as Dictionary).duplicate(true)
	rival["cash"] = RIVAL_CASH_SENTINEL
	rival["cash_cents"] = RIVAL_CASH_SENTINEL * 100
	rival["slots"] = [{"name": RIVAL_HAND_SENTINEL, "kind": "private_test"}]
	rival["private_discard"] = [RIVAL_DISCARD_SENTINEL]
	rival["ai_plan"] = RIVAL_PLAN_SENTINEL
	rival["true_owner"] = RIVAL_OWNER_SENTINEL
	world.players[1] = rival
	presentation.open_player = 1
	var public_surface := query.snapshot_for_viewer(0)
	var public_snapshot: Dictionary = public_surface.get("snapshot", {}) if public_surface.get("snapshot", {}) is Dictionary else {}
	_expect(str(public_surface.get("visibility_scope", "")) == "public" and str(public_snapshot.get("visibility_scope", "")) == "public", "opponent subject is downgraded to public browse scope")
	var leak_text := JSON.stringify(public_surface)
	for sentinel in [str(RIVAL_CASH_SENTINEL), RIVAL_HAND_SENTINEL, RIVAL_DISCARD_SENTINEL, RIVAL_PLAN_SENTINEL, RIVAL_OWNER_SENTINEL]:
		_expect(not leak_text.contains(sentinel), "public surface omits sentinel %s" % sentinel)
	var forbidden_paths: Array[String] = []
	_collect_forbidden_paths(public_snapshot, "snapshot", forbidden_paths)
	_expect(forbidden_paths.is_empty(), "public surface recursively omits private/internal keys: %s" % [forbidden_paths])
	var public_cards: Array = public_snapshot.get("cards", []) if public_snapshot.get("cards", []) is Array else []
	var browse_only := not public_cards.is_empty()
	for card_variant in public_cards:
		var card: Dictionary = card_variant if card_variant is Dictionary else {}
		var preview: Dictionary = card.get("preview", {}) if card.get("preview", {}) is Dictionary else {}
		browse_only = browse_only and not bool(card.get("actionable", true)) \
			and str(card.get("state_text", "")) == "仅浏览" \
			and not bool(preview.get("buy_enabled", true))
	_expect(browse_only, "all opponent/public cards are browse-only and non-actionable")

	var purchase_signal_count := [0]
	var drawer := screen.get_district_supply_drawer() as SpaceSyndicateDistrictSupplyDrawer
	if drawer != null:
		drawer.supply_action_requested.connect(func(action_id: String, _payload: Dictionary) -> void:
			if action_id == "district_supply_purchase_card":
				purchase_signal_count[0] += 1
		)
		_expect(overlay.apply_district_supply_presentation(public_surface, 0, context.authorization_revision), "public surface applies to the typed drawer target")
		if not public_cards.is_empty():
			drawer.call("_on_card_purchase_requested", str((public_cards[0] as Dictionary).get("card_name", "")), "test_double_click")
		_expect(purchase_signal_count[0] == 0, "public double-click/confirm cannot emit a purchase action")

	presentation.open_player = 0
	private_surface = query.snapshot_for_viewer(0)
	var full_state := viewmodel.compose_table_state(0, true)
	var live_state := viewmodel.compose_table_state(0, false)
	_expect(full_state.has("district_supply") and not live_state.has("district_supply"), "district supply is full-refresh only and absent from live cadence")
	var full_snapshot := TableFullPresentationSnapshot.new()
	full_snapshot.revision = 1
	full_snapshot.viewer_index = 0
	full_snapshot.authorization_revision = context.authorization_revision
	full_snapshot.table_state = full_state
	screen.bind_presentation_viewer(0, context.authorization_revision)
	screen.apply_full_presentation(full_snapshot)
	var target_after_full := overlay.district_supply_presentation_target_snapshot()
	_expect(bool(target_after_full.get("visible", false)) and str(target_after_full.get("last_visibility_scope", "")) == "viewer_private", "full target renders the authorized private drawer")
	var target_apply_count := int(target_after_full.get("apply_count", 0))
	var live_snapshot := TableLivePresentationSnapshot.new()
	live_snapshot.revision = 2
	live_snapshot.viewer_index = 0
	live_snapshot.authorization_revision = context.authorization_revision
	live_snapshot.table_state = live_state
	screen.apply_live_presentation(live_snapshot)
	var target_after_live := overlay.district_supply_presentation_target_snapshot()
	_expect(bool(target_after_live.get("visible", false)) and int(target_after_live.get("apply_count", -1)) == target_apply_count, "live refresh neither clears nor reapplies the district drawer")
	screen.bind_presentation_viewer(0, context.authorization_revision + 1)
	var target_after_rebind := overlay.district_supply_presentation_target_snapshot()
	_expect(not bool(target_after_rebind.get("visible", true)) and str(target_after_rebind.get("last_visibility_scope", "")) == "closed", "authorization revision change immediately clears stale private drawer content")

	var main_source_path := "/".join(["res://scripts", "main.gd"])
	var main_source := FileAccess.get_file_as_string(main_source_path)
	for retired_method in [
		"func _refresh_district_supply_overlay",
		"func _district_supply_snapshot_source",
		"func _district_supply_private_viewer_authorized",
		"func _district_supply_public_card_source",
		"func _district_supply_card_source",
		"func _district_supply_target_kind",
		"func _district_supply_purchase_state",
		"func _active_card_market_quote",
	]:
		_expect(not main_source.contains(retired_method), "Main retired %s" % retired_method)
	var query_source := FileAccess.get_file_as_string("res://scripts/presentation/district_supply_viewer_query_port.gd")
	var root_main_lookup := "/root/" + "Main"
	var callable_main_lookup := "Callable(" + "Main"
	_expect(not query_source.contains(root_main_lookup) and not query_source.contains("current_scene") and not query_source.contains(callable_main_lookup), "query has no Main lookup or callback")

	_stop_audio(app_root)
	app_root.queue_free()
	await _wait_frames(2)
	_finish()


func _first_rack_district(world: WorldSessionState, region_supply: RegionSupplyRuntimeController) -> int:
	for district_index in range(world.districts.size()):
		var district: Dictionary = world.districts[district_index] if world.districts[district_index] is Dictionary else {}
		var region_id := str(district.get("region_id", ""))
		var rack := region_supply.public_rack_snapshot(region_id)
		var rows: Array = rack.get("regions", []) if rack.get("regions", []) is Array else []
		if not rows.is_empty() and rows[0] is Dictionary and not ((rows[0] as Dictionary).get("slots", []) as Array).is_empty():
			return district_index
	return -1


func _collect_forbidden_paths(value: Variant, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			var child_path := "%s.%s" % [path, key]
			if FORBIDDEN_PRESENTATION_KEYS.has(key):
				result.append(child_path)
			_collect_forbidden_paths((value as Dictionary).get(key_variant), child_path, result)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_forbidden_paths((value as Array)[index], "%s[%d]" % [path, index], result)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _stop_audio(root_node: Node) -> void:
	for node in root_node.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("DISTRICT_SUPPLY_SURFACE_QUERY_CUTOVER_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("DISTRICT_SUPPLY_SURFACE_QUERY_CUTOVER_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
