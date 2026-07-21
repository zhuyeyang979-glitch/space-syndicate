extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/district_supply_purchase_projection_receipt.save"
const TARGET_CARD_ID := "facility.market.technology.rank_1"
const FIXED_SEED := 900626424

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
		"district-supply-purchase-projection-receipt"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start.get("started", false)) and app_root != null and coordinator != null, "real production session starts")
	if app_root == null or coordinator == null:
		_finish()
		return

	var world := coordinator.world_session_state()
	coordinator.pause_session()
	await process_frame
	var query := coordinator.get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort
	var presentation := coordinator.card_supply_presentation_state()
	var port := coordinator.district_supply_action_port()
	var screen := app_root.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer if screen != null else null
	var configured := coordinator.configure_region_supply_from_world(
		FIXED_SEED,
		world.districts if world != null else [],
		[TARGET_CARD_ID],
		1
	)
	_expect(bool(configured.get("configured", false)), "fixed seed configures the target facility listing")
	var district_index := _first_purchasable_target_district(coordinator, world)
	_expect(district_index >= 0, "fixed seed exposes the target facility in a currently purchasable district")
	_expect(query != null and presentation != null and port != null and screen != null and overlay != null, "typed query, drawer target, GameScreen and action port are composed")
	if district_index < 0 or query == null or presentation == null or port == null or screen == null or overlay == null:
		_stop_audio(app_root)
		app_root.queue_free()
		await process_frame
		_finish()
		return

	var human := (world.players[0] as Dictionary).duplicate(true)
	human["cash"] = 100_000
	world.players[0] = human
	var context := coordinator.get_node("TablePresentationQueryPorts").viewer_context() as TablePresentationViewerContext
	screen.bind_presentation_viewer(0, context.authorization_revision)
	var identity := coordinator.get_node("PlayerIdentityAuthorizationBoundary") as PlayerIdentityAuthorizationBoundary
	var actor_context := identity.current_actor_context(&"district_supply") if identity != null else null
	screen.bind_gameplay_actor_authorization_context(actor_context)
	_expect(actor_context != null and actor_context.is_valid() and actor_context.authorization_revision == context.authorization_revision, "human surface binds the same typed actor and viewer authorization")
	_expect(screen.request_district_selection(district_index, &"qa_driver"), "human table selection is aligned with the open rack")
	presentation.open_district = district_index
	presentation.open_player = 0
	presentation.previewed_district_card = TARGET_CARD_ID
	presentation.selected_market_skill = TARGET_CARD_ID
	var district := world.districts[district_index] as Dictionary
	var rack_revision := coordinator.region_supply_rack_revision(str(district.get("region_id", "")))
	coordinator.open_district_purchase_window(0, district_index, {"supply_revision": rack_revision})
	coordinator.mark_district_supply_revision(0, district_index, rack_revision)

	var intents: Array[DistrictSupplyActionIntent] = []
	var receipts: Array[DistrictSupplyActionReceipt] = []
	screen.district_supply_action_intent_requested.connect(func(intent: DistrictSupplyActionIntent) -> void:
		intents.append(intent)
	)
	port.receipt_ready.connect(func(receipt: DistrictSupplyActionReceipt) -> void:
		receipts.append(receipt)
	)

	var first_surface := query.snapshot_for_viewer(0)
	_expect(overlay.apply_district_supply_presentation(first_surface, 0, context.authorization_revision), "viewer-private target facility drawer applies")
	var drawer := screen.get_district_supply_drawer() as SpaceSyndicateDistrictSupplyDrawer
	var first_preview := _drawer_preview(drawer)
	_expect(str(first_preview.get("card_name", "")) == TARGET_CARD_ID, "fixed facility is the rendered preview")
	_expect(str(first_preview.get("primary_action_id", "")) == "district_supply_preview_card", "no-quote projection explicitly requests a quote")
	_expect(bool(first_preview.get("buy_enabled", false)) and str(first_preview.get("buy_text", "")).contains("获取报价"), "enabled button copy and action both describe quote acquisition")

	drawer.call("_on_card_purchase_requested", TARGET_CARD_ID, "focused_human_double_click")
	_expect(intents.size() == 1 and intents[0].action_kind == DistrictSupplyActionIntent.KIND_QUOTE, "human Drawer-to-GameScreen path emits a typed quote intent first")
	_expect(receipts.size() == 1 and receipts[0].accepted and receipts[0].reason_code == "quote_locked", "authoritative port accepts and reports the locked quote: %s" % _receipt_debug(receipts))
	_expect(not receipts[0].quote_id.is_empty(), "private quote receipt carries the locked quote credential")

	var second_surface := query.snapshot_for_viewer(0)
	_expect(overlay.apply_district_supply_presentation(second_surface, 0, context.authorization_revision), "post-quote viewer-private projection reapplies")
	var second_preview := _drawer_preview(drawer)
	_expect(str(second_preview.get("primary_action_id", "")) == "district_supply_purchase_card", "active quote projection advances to purchase: %s" % JSON.stringify(second_preview))
	_expect(str(second_preview.get("action_reason_code", "")) == "facility_purchase_ready", "buy-enabled projection exposes the allowlisted ready reason")

	var before_purchase := port.debug_snapshot()
	drawer.call("_on_card_purchase_requested", TARGET_CARD_ID, "focused_human_confirm")
	_expect(intents.size() == 2 and intents[1].action_kind == DistrictSupplyActionIntent.KIND_PURCHASE, "same human surface emits typed purchase only after quote")
	_expect(receipts.size() == 2 and receipts[1].accepted and receipts[1].applied, "authoritative purchase receipt commits the facility card: %s" % _receipt_debug(receipts))
	_expect(receipts[1].reason_code != "locked_quote_required", "purchase no longer reaches the missing-quote rejection")
	var after_purchase := port.debug_snapshot()
	_expect(int(after_purchase.get("purchase_commit_count", 0)) == int(before_purchase.get("purchase_commit_count", 0)) + 1, "purchase mutation commits exactly once")

	var replay := port.submit_intent(intents[1])
	var after_replay := port.debug_snapshot()
	_expect(replay.idempotent_replay and replay.reason_code == "request_replay", "duplicate typed submit is rejected as an idempotent replay")
	_expect(int(after_replay.get("purchase_commit_count", 0)) == int(after_purchase.get("purchase_commit_count", 0)), "duplicate submit cannot commit a second card or debit")
	var public_receipt_text := JSON.stringify(receipts[1].public_summary())
	_expect(not public_receipt_text.contains(TARGET_CARD_ID) and not public_receipt_text.contains(receipts[0].quote_id) and not public_receipt_text.contains("locked_quote"), "public receipt omits card, quote credential and private reason")

	_stop_audio(app_root)
	app_root.queue_free()
	await process_frame
	_finish()


func _first_purchasable_target_district(coordinator: GameRuntimeCoordinator, world: WorldSessionState) -> int:
	if coordinator == null or world == null:
		return -1
	for district_index in range(world.districts.size()):
		var district: Dictionary = world.districts[district_index] if world.districts[district_index] is Dictionary else {}
		if coordinator.region_supply_listing(str(district.get("region_id", "")), TARGET_CARD_ID).is_empty():
			continue
		if bool(coordinator.card_market_listing_availability(district_index).get("purchasable", false)):
			return district_index
	return -1


func _drawer_preview(drawer: SpaceSyndicateDistrictSupplyDrawer) -> Dictionary:
	if drawer == null:
		return {}
	var snapshot_variant: Variant = drawer.debug_snapshot()
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	return (snapshot.get("preview", {}) as Dictionary).duplicate(true) if snapshot.get("preview", {}) is Dictionary else {}


func _receipt_debug(receipts: Array[DistrictSupplyActionReceipt]) -> String:
	var rows: Array = []
	for receipt in receipts:
		rows.append(receipt.to_dictionary())
	return JSON.stringify(rows)


func _stop_audio(root_node: Node) -> void:
	for node in root_node.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("DISTRICT_SUPPLY_PURCHASE_PROJECTION_RECEIPT_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("DISTRICT_SUPPLY_PURCHASE_PROJECTION_RECEIPT_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
