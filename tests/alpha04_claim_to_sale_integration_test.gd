extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const CLAIM_REQUEST := preload("res://scripts/runtime/commodity_sushi_track_claim_request.gd")
const GAME_ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const GAME_ACTION_OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")

const QA_SAVE_PATH := "user://test_runs/alpha04_claim_to_sale_integration.save"
const REGION_SUPPLY_SEED := 904_062_611
const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const FILLER_CARD_IDS := [
	"interaction.phase_veto.rank_1",
	"interaction.shadow_warehouse_traction.rank_1",
	"unit.military.planetary_defense_force.rank_1",
	"unit.military.air_superiority_fighter.rank_1",
	"supply_demand.near_land_supply.rank_1",
	"supply_demand.remote_sea_order.rank_1",
]
const MAX_SALE_SECONDS := 90

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 960)
	var start: Dictionary = await SESSION_DRIVER.start_configured_session(
		self,
		{
			"run_seed": REGION_SUPPLY_SEED,
			"player_count": 3,
			"ai_player_count": 2,
			"challenge_depth": 1,
			# This role set avoids the product-triggered bonus-card path while the
			# test isolates the shared hand-limit purchase transaction.
			"role_indices": [3, 0, 1],
			"starter_monster_indices": [0, 1, 2],
		},
		QA_SAVE_PATH,
		"alpha04-claim-to-sale-integration"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(
		bool(start.get("started", false)) and app_root != null and coordinator != null,
		"real production session starts: %s" % JSON.stringify({
			"started": start.get("started", false),
			"reason_code": start.get("reason_code", "missing"),
		})
	)
	if app_root == null or coordinator == null:
		_finish()
		return

	coordinator.pause_session()
	await process_frame
	var world := coordinator.world_session_state()
	var screen := app_root.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer if screen != null else null
	var region_popup := screen.get_region_supply_popup() as SpaceSyndicateRegionSupplyPopup if screen != null else null
	var viewmodel_query := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var district_port := coordinator.district_supply_action_port()
	var sushi_service := coordinator.get_node_or_null("CommoditySushiTrackRuntimeService")
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	var flow := coordinator.get_node_or_null("CommodityFlowRuntimeController")
	_expect(
		world != null and screen != null and overlay != null and region_popup != null \
			and viewmodel_query != null and query_ports != null \
			and district_port != null and sushi_service != null and inventory != null \
			and infrastructure != null and flow != null,
		"production claim, SHARED_V06 inventory, typed RegionSupplyPopup, facility, and CommodityFlow services are composed"
	)
	if world == null or screen == null or overlay == null or region_popup == null \
			or viewmodel_query == null or query_ports == null \
			or district_port == null or sushi_service == null or inventory == null \
			or infrastructure == null or flow == null:
		await _cleanup(app_root)
		_finish()
		return

	var actor_binding := coordinator.actor_id_for_player_index(0)
	var actor_id := str(actor_binding.get("actor_id", ""))
	var context := query_ports.viewer_context()
	var identity := coordinator.get_node_or_null("PlayerIdentityAuthorizationBoundary") as PlayerIdentityAuthorizationBoundary
	var actor_context := identity.current_actor_context(&"district_supply") if identity != null else null
	screen.bind_presentation_viewer(0, context.authorization_revision)
	screen.bind_gameplay_actor_authorization_context(actor_context)
	_expect(
		bool(actor_binding.get("available", false)) and not actor_id.is_empty() \
			and actor_context != null and actor_context.is_valid() \
			and actor_context.authorization_revision == context.authorization_revision,
		"human viewer and authoritative card actor share one current session authorization"
	)
	if actor_id.is_empty() or actor_context == null or not actor_context.is_valid():
		await _cleanup(app_root)
		_finish()
		return

	# Keep quote affordability deterministic in the real production player owner.
	var human := (world.players[0] as Dictionary).duplicate(true)
	human["cash"] = 100_000
	human["cash_cents"] = 10_000_000
	human["action_cooldown"] = 0.0
	world.players[0] = human

	var track_snapshot: CommoditySushiTrackSnapshot = sushi_service.public_snapshot(0)
	var claim_candidate := _claim_candidate_with_facility_chain(
		coordinator,
		query_ports,
		infrastructure,
		flow,
		track_snapshot
	)
	_expect(
		track_snapshot != null and track_snapshot.is_valid() and not claim_candidate.is_empty(),
		"real commodity track contains a claim whose product has bounded factory and market targets"
	)
	if claim_candidate.is_empty():
		await _cleanup(app_root)
		_finish()
		return

	var item: CommoditySushiTrackItemSnapshot = claim_candidate.get("item") as CommoditySushiTrackItemSnapshot
	var chain: Dictionary = claim_candidate.get("chain", {}) if claim_candidate.get("chain", {}) is Dictionary else {}
	var commodity_card_id := str(item.commodity_card_id)
	var product_id := str(chain.get("product_id", ""))
	var industry_id := str(chain.get("industry_id", ""))
	var factory_card_id := str(chain.get("factory_card_id", ""))
	var market_card_id := str(chain.get("market_card_id", ""))
	var factory_target: Dictionary = chain.get("factory_target", {}) if chain.get("factory_target", {}) is Dictionary else {}
	var market_target: Dictionary = chain.get("market_target", {}) if chain.get("market_target", {}) is Dictionary else {}
	_expect(
		INDUSTRY_IDS.has(industry_id) and not product_id.is_empty() \
			and str(factory_target.get("region_id", "")) != str(market_target.get("region_id", "")),
		"claim product resolves to distinct exact-production and unambiguous market facility targets: %s" % JSON.stringify(chain)
	)

	# Claim through the typed real sushi-track service, then replay the exact same
	# request. The second result must be a receipt replay with no owner mutation.
	var before_claim := coordinator.v06_card_player_snapshot(actor_id)
	var claim_request: CLAIM_REQUEST = CLAIM_REQUEST.new()
	claim_request.viewer_index = 0
	claim_request.commodity_slot_id = item.commodity_slot_id
	claim_request.commodity_card_id = item.commodity_card_id
	claim_request.snapshot_revision = track_snapshot.snapshot_revision
	claim_request.belt_revision = track_snapshot.belt_revision
	claim_request.visibility_revision = track_snapshot.visibility_revision
	claim_request.request_revision = 1
	var claim: Dictionary = sushi_service.claim(claim_request)
	var after_claim := coordinator.v06_card_player_snapshot(actor_id)
	var claim_slot := _inventory_slot_for_card(after_claim, commodity_card_id)
	_expect(
		bool(claim.get("success", false)) \
			and _inventory_card_count(after_claim) == _inventory_card_count(before_claim) + 1 \
			and claim_slot >= 0,
		"typed commodity claim adds exactly one authoritative SHARED_V06 hand card: %s" % JSON.stringify(claim)
	)
	var replay: Dictionary = sushi_service.claim(claim_request)
	var after_replay := coordinator.v06_card_player_snapshot(actor_id)
	_expect(
		bool(replay.get("success", false)) and bool(replay.get("idempotent_replay", false)) \
			and str(replay.get("request_status_code", "")) == "request_duplicate" \
			and JSON.stringify(after_replay) == JSON.stringify(after_claim),
		"duplicate typed claim is an exact-once replay with a byte-stable player snapshot: %s" % JSON.stringify(replay)
	)

	# Fill only through the production inventory owner until the shared V0.6 hand
	# is exactly full. The later DistrictSupply purchase must own the discard.
	var granted_card_ids: Array[String] = []
	for filler_card_id in FILLER_CARD_IDS:
		var before_grant := coordinator.v06_card_player_snapshot(actor_id)
		if _inventory_card_count(before_grant) >= CardFlowPolicyV06.HAND_LIMIT:
			break
		var grant_variant: Variant = inventory.call(
			"grant_card",
			actor_id,
			filler_card_id,
			int(before_grant.get("revision", -1)),
			"alpha04-claim-sale-fill:%d" % granted_card_ids.size(),
			"alpha04_claim_to_sale_capacity_setup"
		)
		var grant: Dictionary = grant_variant if grant_variant is Dictionary else {}
		var after_grant := coordinator.v06_card_player_snapshot(actor_id)
		if bool(grant.get("committed", false)) \
				and _inventory_card_count(after_grant) == _inventory_card_count(before_grant) + 1:
			granted_card_ids.append(filler_card_id)
	var full_hand := coordinator.v06_card_player_snapshot(actor_id)
	var discard_card_id := granted_card_ids[0] if not granted_card_ids.is_empty() else ""
	var discard_slot := _inventory_slot_for_card(full_hand, discard_card_id)
	var receive_preview_variant: Variant = inventory.call(
		"region_supply_receive_preview",
		actor_id,
		factory_card_id,
		-1
	)
	var receive_preview: Dictionary = receive_preview_variant if receive_preview_variant is Dictionary else {}
	_expect(
		_inventory_card_count(full_hand) == CardFlowPolicyV06.HAND_LIMIT \
			and discard_slot >= 0 and discard_slot != claim_slot \
			and _inventory_has_card(full_hand, commodity_card_id),
		"bounded setup reaches the real five-card SHARED_V06 limit while preserving the claimed commodity"
	)
	_expect(
		bool(receive_preview.get("requires_discard", false)) \
			and str(receive_preview.get("reason_code", "")) == "hand_full_discard_required" \
			and (receive_preview.get("discardable_slots", []) as Array).has(discard_slot),
		"real inventory preview requires a legal private discard before the facility purchase: %s" % JSON.stringify(receive_preview)
	)
	if discard_slot < 0 or not bool(receive_preview.get("requires_discard", false)):
		await _cleanup(app_root)
		_finish()
		return

	var configured := coordinator.configure_region_supply_from_world(
		REGION_SUPPLY_SEED,
		world.districts,
		[factory_card_id, market_card_id],
		2
	)
	_expect(
		bool(configured.get("configured", false)) and int(configured.get("legal_card_count", 0)) == 2,
		"real RegionSupply configures only the claimed product's factory/market pair: %s" % JSON.stringify(configured)
	)
	if not bool(configured.get("configured", false)):
		await _cleanup(app_root)
		_finish()
		return

	var district_receipts: Array[DistrictSupplyActionReceipt] = []
	district_port.receipt_ready.connect(func(receipt: DistrictSupplyActionReceipt) -> void:
		district_receipts.append(receipt)
	)
	var first_purchase: Dictionary = await _purchase_from_region_supply_popup(
		coordinator,
		world,
		screen,
		overlay,
		region_popup,
		viewmodel_query,
		district_port,
		district_receipts,
		factory_card_id,
		discard_slot,
		-1
	)
	var first_receipts: Array = first_purchase.get("receipts", []) if first_purchase.get("receipts", []) is Array else []
	var pending_receipt := _dictionary_at(first_receipts, 1)
	var committed_receipt := _dictionary_at(first_receipts, 2)
	var after_factory_purchase := coordinator.v06_card_player_snapshot(actor_id)
	_expect(
		bool(first_purchase.get("completed", false)) and first_receipts.size() == 3 \
			and bool(pending_receipt.get("accepted", false)) \
			and bool(pending_receipt.get("requires_discard", false)) \
			and str(pending_receipt.get("reason_code", "")) == "hand_limit_requires_discard" \
			and bool(committed_receipt.get("accepted", false)) \
			and bool(committed_receipt.get("applied", false)) \
			and str(committed_receipt.get("reason_code", "")) == "purchase_committed",
		"Drawer→typed purchase enters pending discard and commits only after the temporary-decision response: %s" % JSON.stringify(first_purchase)
	)
	_expect(
		int(first_purchase.get("commit_after", -1)) == int(first_purchase.get("commit_before", -2)) + 1 \
			and _inventory_card_count(after_factory_purchase) == CardFlowPolicyV06.HAND_LIMIT \
			and _inventory_has_card(after_factory_purchase, factory_card_id) \
			and _inventory_has_card(after_factory_purchase, commodity_card_id) \
			and not _inventory_has_card(after_factory_purchase, discard_card_id) \
			and coordinator.district_purchase_pending_discard_private_snapshot(0).is_empty(),
		"discard+receive keeps capacity at five, preserves the claim, removes only the chosen filler, and commits purchase exactly once"
	)

	var factory_play := await _play_facility_through_formal_submission(
		coordinator,
		screen,
		actor_id,
		factory_card_id,
		str(factory_target.get("region_id", ""))
	)
	var after_factory_play := coordinator.v06_card_player_snapshot(actor_id)
	var production := _matching_installation(
		flow,
		"production",
		product_id,
		str(factory_target.get("region_id", "")),
		0
	)
	_expect(
		bool(factory_play.get("success", false)) \
			and _inventory_card_count(after_factory_play) == CardFlowPolicyV06.HAND_LIMIT - 1 \
			and not production.is_empty(),
		"formally submitted factory play consumes one purchased card and installs exact claimed-product production: %s" % JSON.stringify({
			"play": factory_play,
			"production": production,
		})
	)

	var market_preview_variant: Variant = inventory.call(
		"region_supply_receive_preview",
		actor_id,
		market_card_id,
		-1
	)
	var market_preview: Dictionary = market_preview_variant if market_preview_variant is Dictionary else {}
	_expect(
		bool(market_preview.get("ready", false)) and not bool(market_preview.get("requires_discard", false)),
		"playing the factory reopens one shared hand slot for the complementary market purchase"
	)
	var second_purchase: Dictionary = await _purchase_from_region_supply_popup(
		coordinator,
		world,
		screen,
		overlay,
		region_popup,
		viewmodel_query,
		district_port,
		district_receipts,
		market_card_id,
		-1,
		int(first_purchase.get("source_district", -1))
	)
	var second_receipts: Array = second_purchase.get("receipts", []) if second_purchase.get("receipts", []) is Array else []
	var second_commit_receipt := _dictionary_at(second_receipts, 1)
	var after_market_purchase := coordinator.v06_card_player_snapshot(actor_id)
	_expect(
		bool(second_purchase.get("completed", false)) and second_receipts.size() == 2 \
			and bool(second_commit_receipt.get("accepted", false)) \
			and bool(second_commit_receipt.get("applied", false)) \
			and not bool(second_commit_receipt.get("requires_discard", true)) \
			and int(second_purchase.get("commit_after", -1)) == int(second_purchase.get("commit_before", -2)) + 1 \
			and _inventory_card_count(after_market_purchase) == CardFlowPolicyV06.HAND_LIMIT,
		"complementary market uses the same real quote/purchase path without a second discard: %s" % JSON.stringify(second_purchase)
	)

	var market_play := await _play_facility_through_formal_submission(
		coordinator,
		screen,
		actor_id,
		market_card_id,
		str(market_target.get("region_id", ""))
	)
	var market_facility := _facility_for_slot(
		infrastructure,
		str(market_target.get("region_id", "")),
		"market",
		industry_id,
		0
	)
	_expect(
		bool(market_play.get("success", false)) and not market_facility.is_empty(),
		"formally submitted market play creates the complementary owned market facility: %s" % JSON.stringify({
			"play": market_play,
			"facility": market_facility,
		})
	)

	# Submit the originally claimed commodity through the shared CardPlay
	# submission owner, targeting the just-purchased market. This turns the
	# retained claim into exact-product demand rather than inventing test demand.
	var before_commodity_play := coordinator.v06_card_player_snapshot(actor_id)
	claim_slot = _inventory_slot_for_card(before_commodity_play, commodity_card_id)
	var commodity_submission := coordinator.card_play_submission_controller().request_hand_play({
		"player_index": 0,
		"slot_index": claim_slot,
		"selected_district": int(market_target.get("public_index", -1)),
		"submission_source": "alpha04_claim_to_sale",
	})
	var after_commodity_play := coordinator.v06_card_player_snapshot(actor_id)
	var demand := _matching_installation(
		flow,
		"demand",
		product_id,
		str(market_target.get("region_id", "")),
		0
	)
	_expect(
		claim_slot >= 0 and bool(commodity_submission.get("accepted", false)) \
			and not bool(commodity_submission.get("queued", true)) \
			and _inventory_card_count(after_commodity_play) == _inventory_card_count(before_commodity_play) - 1 \
			and not demand.is_empty(),
		"the preserved claimed commodity is formally consumed into matching market demand: %s" % JSON.stringify({
			"submission": commodity_submission,
			"demand": demand,
		})
	)
	_expect(
		str(production.get("commodity_id", "")) == str(demand.get("commodity_id", "")) \
			and str(production.get("color", "")) == industry_id \
			and str(demand.get("color", "")) == industry_id,
		"real facility and commodity owners expose one exact-product production/demand pair"
	)

	# Advance only the real CommodityFlow owner in one-second bounded steps. This
	# is a focused integration oracle, not a Formal FullRun driver.
	var receipts_before: Array = flow.call("recent_sale_receipts_snapshot", 0)
	var cash_before := _player_cash_cents(world, 0)
	var ticks: Array = []
	var matching_sale: Dictionary = {}
	for _second in range(MAX_SALE_SECONDS):
		world.game_time += 1.0
		var tick_variant: Variant = flow.call("advance_world", 1.0, {})
		var tick: Dictionary = tick_variant if tick_variant is Dictionary else {}
		ticks.append({
			"advanced": tick.get("advanced", false),
			"reason": tick.get("reason", tick.get("reason_code", "")),
			"receipt_count": tick.get("receipt_count", 0),
		})
		var current_receipts: Array = flow.call("recent_sale_receipts_snapshot", 0)
		matching_sale = _new_matching_sale(current_receipts, receipts_before.size(), product_id, 0)
		if not matching_sale.is_empty():
			break
	var receipts_after: Array = flow.call("recent_sale_receipts_snapshot", 0)
	var cash_after := _player_cash_cents(world, 0)
	var gdp_variant: Variant = flow.call("region_gdp_snapshot", str(matching_sale.get("market_region_id", ""))) if not matching_sale.is_empty() else {}
	var gdp: Dictionary = gdp_variant if gdp_variant is Dictionary else {}
	_expect(
		not matching_sale.is_empty() and receipts_after.size() > receipts_before.size() \
			and float(matching_sale.get("units", 0.0)) > 0.0 \
			and int(matching_sale.get("owner_net_cash", 0)) > 0,
		"bounded real CommodityFlow advance commits at least one positive Sale Receipt: %s" % JSON.stringify({
			"sale": matching_sale,
			"ticks": ticks,
		})
	)
	_expect(
		cash_after > cash_before \
			and int(gdp.get("region_gdp_per_minute_cents", 0)) > 0,
		"Sale Receipt produces positive owner cash and receipt-derived market-region GDP: %s" % JSON.stringify({
			"cash_before": cash_before,
			"cash_after": cash_after,
			"gdp": gdp,
		})
	)

	await _cleanup(app_root)
	_finish()


func _claim_candidate_with_facility_chain(
	coordinator: GameRuntimeCoordinator,
	query_ports: TablePresentationQueryPorts,
	infrastructure: RegionInfrastructureRuntimeController,
	flow: Object,
	track_snapshot: CommoditySushiTrackSnapshot
) -> Dictionary:
	if coordinator == null or query_ports == null or infrastructure == null or flow == null \
			or track_snapshot == null or query_ports.region_infrastructure_public_query == null:
		return {}
	var facts_variant: Variant = query_ports.region_infrastructure_public_query.call("public_commodity_region_facts")
	var facts: Array = facts_variant if facts_variant is Array else []
	for item_variant in track_snapshot.items:
		var item := item_variant as CommoditySushiTrackItemSnapshot
		if item == null:
			continue
		var definition := coordinator.v06_card_definition(item.commodity_card_id)
		var machine: Dictionary = definition.get("machine", {}) if definition.get("machine", {}) is Dictionary else {}
		var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
		var product_id := str(payload.get("product_id", ""))
		var industry_id := str(payload.get("industry_id", machine.get("industry_id", "")))
		var chain := _facility_chain_for_product(
			coordinator,
			query_ports,
			infrastructure,
			flow,
			facts,
			product_id,
			industry_id
		)
		if not chain.is_empty():
			return {"item": item, "chain": chain}
	return {}


func _facility_chain_for_product(
	coordinator: GameRuntimeCoordinator,
	query_ports: TablePresentationQueryPorts,
	infrastructure: RegionInfrastructureRuntimeController,
	flow: Object,
	facts: Array,
	product_id: String,
	industry_id: String
) -> Dictionary:
	if product_id.is_empty() or not INDUSTRY_IDS.has(industry_id):
		return {}
	var factory_card_id := "facility.factory.%s.rank_1" % industry_id
	var market_card_id := "facility.market.%s.rank_1" % industry_id
	var factory_allowed := _facility_allowed_states(coordinator.v06_card_definition(factory_card_id))
	var market_allowed := _facility_allowed_states(coordinator.v06_card_definition(market_card_id))
	if factory_allowed.is_empty() or market_allowed.is_empty():
		return {}
	var public_factory := query_ports.public_new_facility_target_candidates(&"factory", StringName(industry_id)).to_dictionary()
	var public_market := query_ports.public_new_facility_target_candidates(&"market", StringName(industry_id)).to_dictionary()
	var public_factory_regions := _candidate_region_set(public_factory.get("candidates", []) as Array)
	var public_market_regions := _candidate_region_set(public_market.get("candidates", []) as Array)
	var factory_targets: Array[Dictionary] = []
	var market_targets: Array[Dictionary] = []
	for facts_variant in facts:
		if not (facts_variant is Dictionary):
			continue
		var region_facts := facts_variant as Dictionary
		var region_id := str(region_facts.get("region_id", ""))
		var public_index := int(region_facts.get("legacy_index", -1))
		if region_id.is_empty() or public_index < 0:
			continue
		if _region_hosts_facility(infrastructure, region_id, "factory", industry_id, factory_allowed) \
				and _predicted_factory_product(region_facts, industry_id, flow) == product_id:
			factory_targets.append({
				"region_id": region_id,
				"public_index": public_index,
				"region_revision": int(region_facts.get("region_revision", 0)),
				"public_candidate": bool(public_factory_regions.get(region_id, false)),
			})
		if _region_hosts_facility(infrastructure, region_id, "market", industry_id, market_allowed) \
				and not _region_has_colored_flow_facility(infrastructure, region_id, industry_id):
			market_targets.append({
				"region_id": region_id,
				"public_index": public_index,
				"region_revision": int(region_facts.get("region_revision", 0)),
				"public_candidate": bool(public_market_regions.get(region_id, false)),
				"exact_public_demand_product": _facts_have_product(region_facts, "demand_products", product_id, industry_id),
			})
	_sort_targets(factory_targets)
	_sort_targets(market_targets)
	for factory_target in factory_targets:
		for market_target in market_targets:
			if str(factory_target.get("region_id", "")) == str(market_target.get("region_id", "")):
				continue
			return {
				"product_id": product_id,
				"industry_id": industry_id,
				"factory_card_id": factory_card_id,
				"market_card_id": market_card_id,
				"factory_target": factory_target.duplicate(true),
				"market_target": market_target.duplicate(true),
			}
	return {}


func _facility_allowed_states(definition: Dictionary) -> Array:
	var machine: Dictionary = definition.get("machine", {}) if definition.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	return (payload.get("allowed_region_states", []) as Array).duplicate() if payload.get("allowed_region_states", []) is Array else []


func _candidate_region_set(candidates: Array) -> Dictionary:
	var result := {}
	for candidate_variant in candidates:
		if candidate_variant is Dictionary:
			result[str((candidate_variant as Dictionary).get("region_id", ""))] = true
	return result


func _region_hosts_facility(
	infrastructure: RegionInfrastructureRuntimeController,
	region_id: String,
	facility_kind: String,
	industry_id: String,
	allowed_states: Array
) -> bool:
	var region := infrastructure.region_snapshot(region_id)
	var slot_id := infrastructure.slot_id(region_id, facility_kind, industry_id)
	if region.is_empty() or slot_id.is_empty() \
			or not allowed_states.has(str(region.get("lifecycle_state", ""))) \
			or not (region.get("facility_slot_ids", []) as Array).has(slot_id):
		return false
	for facility_variant in region.get("facilities", []) as Array:
		if facility_variant is Dictionary and bool((facility_variant as Dictionary).get("active", false)) \
				and str((facility_variant as Dictionary).get("slot_id", "")) == slot_id:
			return false
	return true


func _region_has_colored_flow_facility(
	infrastructure: RegionInfrastructureRuntimeController,
	region_id: String,
	industry_id: String
) -> bool:
	for facility_variant in infrastructure.facilities_snapshot(false):
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		if bool(facility.get("active", false)) \
				and str(facility.get("region_id", "")) == region_id \
				and str(facility.get("industry_id", "")) == industry_id \
				and str(facility.get("facility_type", "")) in ["factory", "market"]:
			return true
	return false


func _predicted_factory_product(region_facts: Dictionary, industry_id: String, flow: Object) -> String:
	var fallback := ""
	for product_variant in region_facts.get("production_products", []) as Array:
		if not (product_variant is Dictionary):
			continue
		var product := product_variant as Dictionary
		if str(product.get("industry_id", "")) != industry_id:
			continue
		var product_id := str(product.get("product_id", ""))
		if product_id.is_empty():
			continue
		if fallback.is_empty():
			fallback = product_id
		if _active_public_demand_exists(flow, product_id):
			return product_id
	return fallback


func _active_public_demand_exists(flow: Object, product_id: String) -> bool:
	var installations_variant: Variant = flow.call("installations_snapshot", false)
	var installations: Array = installations_variant if installations_variant is Array else []
	for installation_variant in installations:
		if installation_variant is Dictionary:
			var installation := installation_variant as Dictionary
			if bool(installation.get("active", false)) \
					and str(installation.get("owner_kind", "")) == "public" \
					and str(installation.get("direction", "")) == "demand" \
					and str(installation.get("commodity_id", "")) == product_id:
				return true
	return false


func _facts_have_product(
	region_facts: Dictionary,
	rows_key: String,
	product_id: String,
	industry_id: String
) -> bool:
	for product_variant in region_facts.get(rows_key, []) as Array:
		if product_variant is Dictionary \
				and str((product_variant as Dictionary).get("product_id", "")) == product_id \
				and str((product_variant as Dictionary).get("industry_id", "")) == industry_id:
			return true
	return false


func _sort_targets(targets: Array[Dictionary]) -> void:
	targets.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := (4 if bool(left.get("public_candidate", false)) else 0) \
			+ (2 if bool(left.get("exact_public_demand_product", false)) else 0)
		var right_score := (4 if bool(right.get("public_candidate", false)) else 0) \
			+ (2 if bool(right.get("exact_public_demand_product", false)) else 0)
		if left_score != right_score:
			return left_score > right_score
		var left_index := int(left.get("public_index", -1))
		var right_index := int(right.get("public_index", -1))
		return left_index < right_index if left_index != right_index \
			else str(left.get("region_id", "")) < str(right.get("region_id", ""))
	)


func _purchase_from_region_supply_popup(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	screen: SpaceSyndicateGameScreen,
	overlay: SpaceSyndicateOverlayLayer,
	region_popup: SpaceSyndicateRegionSupplyPopup,
	viewmodel_query: TablePresentationViewModelQuery,
	port: DistrictSupplyActionPort,
	receipts: Array[DistrictSupplyActionReceipt],
	card_id: String,
	discard_slot: int,
	preferred_district: int
) -> Dictionary:
	var result := {
		"completed": false,
		"source_district": -1,
		"commit_before": int(port.debug_snapshot().get("purchase_commit_count", 0)),
		"commit_after": int(port.debug_snapshot().get("purchase_commit_count", 0)),
		"receipts": [],
		"failure": "purchase_not_started",
	}
	var district_index := _purchasable_listing_district(coordinator, world, card_id, preferred_district)
	result["source_district"] = district_index
	# Direct facility-play helpers advance authoritative state without going
	# through GameScreen selection. Refresh first so the production open intent
	# carries the current typed selection revision instead of a stale UI copy.
	coordinator.request_table_presentation_refresh(&"full", &"alpha04_claim_sale_open_sync")
	await process_frame
	var open_receipt_start := receipts.size()
	if district_index < 0 or not screen.request_district_supply_open(district_index, &"qa_driver"):
		result["failure"] = "purchasable_listing_or_selection_missing"
		return result
	await process_frame
	if receipts.size() <= open_receipt_start or not receipts[open_receipt_start].accepted:
		result["failure"] = "typed_region_supply_open_rejected"
		result["receipts"] = _receipt_slice(receipts, open_receipt_start)
		result["popup"] = region_popup.debug_snapshot()
		return result
	var receipt_start := receipts.size()
	var quote_state := viewmodel_query.compose_table_state(0, true)
	var quote_projection: Dictionary = quote_state.get("region_supply_popup", {}) \
		if quote_state.get("region_supply_popup", {}) is Dictionary else {}
	if quote_projection.is_empty() or not region_popup.apply_projection(quote_projection):
		result["failure"] = "quote_surface_unavailable"
		result["popup"] = region_popup.debug_snapshot()
		return result
	var quote_offer := region_popup.action_offer_for_card(
		card_id,
		GAME_ACTION_INTENT.ACTION_DISTRICT_SUPPLY_QUOTE
	)
	if quote_offer.is_empty() or not screen.submit_game_action_offer(
		quote_offer,
		"human_click",
		{},
		{}
	):
		result["failure"] = "quote_surface_unavailable"
		result["popup"] = region_popup.debug_snapshot()
		return result
	await process_frame
	if receipts.size() <= receipt_start or not receipts[receipt_start].accepted \
			or receipts[receipt_start].reason_code != "quote_locked":
		result["receipts"] = _receipt_slice(receipts, receipt_start)
		result["failure"] = "quote_rejected"
		return result
	var purchase_state := viewmodel_query.compose_table_state(0, true)
	var purchase_projection: Dictionary = purchase_state.get("region_supply_popup", {}) \
		if purchase_state.get("region_supply_popup", {}) is Dictionary else {}
	if purchase_projection.is_empty() or not region_popup.apply_projection(purchase_projection):
		result["receipts"] = _receipt_slice(receipts, receipt_start)
		result["failure"] = "purchase_surface_unavailable"
		result["popup"] = region_popup.debug_snapshot()
		return result
	var purchase_offer := region_popup.action_offer_for_card(
		card_id,
		GAME_ACTION_INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE
	)
	if purchase_offer.is_empty() or not screen.submit_game_action_offer(
		purchase_offer,
		"human_click",
		{},
		{}
	):
		result["receipts"] = _receipt_slice(receipts, receipt_start)
		result["failure"] = "purchase_surface_unavailable"
		result["popup"] = region_popup.debug_snapshot()
		return result
	await process_frame
	if receipts.size() <= receipt_start + 1:
		result["receipts"] = _receipt_slice(receipts, receipt_start)
		result["failure"] = "purchase_receipt_missing"
		return result
	var purchase_receipt := receipts[receipt_start + 1]
	if purchase_receipt.requires_discard:
		if discard_slot < 0:
			result["receipts"] = _receipt_slice(receipts, receipt_start)
			result["failure"] = "discard_slot_missing"
			return result
		overlay.temporary_decision_action_requested.emit("discard_purchase_%d" % discard_slot)
		await process_frame
	if receipts.size() <= receipt_start + (2 if purchase_receipt.requires_discard else 1):
		result["receipts"] = _receipt_slice(receipts, receipt_start)
		result["failure"] = "terminal_purchase_receipt_missing"
		return result
	var terminal_receipt := receipts[-1]
	result["receipts"] = _receipt_slice(receipts, receipt_start)
	result["commit_after"] = int(port.debug_snapshot().get("purchase_commit_count", 0))
	result["completed"] = terminal_receipt.accepted and terminal_receipt.applied \
		and terminal_receipt.reason_code == "purchase_committed"
	result["failure"] = "" if bool(result["completed"]) else terminal_receipt.reason_code
	return result


func _purchasable_listing_district(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	card_id: String,
	preferred_district: int
) -> int:
	var ordered: Array[int] = []
	if preferred_district >= 0:
		ordered.append(preferred_district)
	for district_index in range(world.districts.size()):
		if not ordered.has(district_index):
			ordered.append(district_index)
	for district_index in ordered:
		if district_index < 0 or district_index >= world.districts.size() \
				or not (world.districts[district_index] is Dictionary):
			continue
		var region_id := str((world.districts[district_index] as Dictionary).get("region_id", ""))
		if not coordinator.region_supply_listing(region_id, card_id).is_empty() \
				and bool(coordinator.card_market_listing_availability(district_index).get("purchasable", false)):
			return district_index
	return -1


func _receipt_slice(receipts: Array[DistrictSupplyActionReceipt], start: int) -> Array:
	var rows: Array = []
	for index in range(maxi(0, start), receipts.size()):
		rows.append(receipts[index].to_dictionary())
	return rows


func _play_facility_through_formal_submission(
	coordinator: GameRuntimeCoordinator,
	screen: SpaceSyndicateGameScreen,
	actor_id: String,
	card_id: String,
	region_id: String
) -> Dictionary:
	var flow := coordinator.get_node_or_null("TablePlayerActionApplicationFlowController") \
		as TablePlayerActionApplicationFlowController
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") \
		as CardResolutionQueueRuntimeService
	var adapter := coordinator.facility_card_queue_adapter_v06()
	var actor_binding := coordinator.actor_id_for_player_index(0)
	if screen == null or flow == null or queue == null or adapter == null \
			or str(actor_binding.get("actor_id", "")) != actor_id:
		return {"success": false, "reason_code": "facility_formal_dependency_missing"}
	coordinator.resume_session()
	var world := coordinator.world_session_state()
	var target_district := -1
	if world != null:
		for district_index in range(world.districts.size()):
			if world.districts[district_index] is Dictionary \
					and str((world.districts[district_index] as Dictionary).get("region_id", "")) == region_id:
				target_district = district_index
				break
	if target_district < 0 \
			or not screen.request_district_selection(target_district, &"qa_driver"):
		coordinator.pause_session()
		return {"success": false, "reason_code": "facility_formal_target_selection_failed"}
	coordinator.request_table_presentation_refresh(&"full", &"claim_sale_facility_offer_sync")
	await process_frame
	await process_frame
	var dock: Dictionary = screen.current_ui_data.get("player_card_dock", {}) \
		if screen.current_ui_data.get("player_card_dock", {}) is Dictionary else {}
	var offer: Dictionary = {}
	var target_overrides: Dictionary = {}
	for row_variant in dock.get("normal_cards", []) if dock.get("normal_cards", []) is Array else []:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var candidate: Dictionary = row.get("game_action_offer", {}) \
			if row.get("game_action_offer", {}) is Dictionary else {}
		var targets := GAME_ACTION_OFFER.target_ids(candidate)
		if str(row.get("card_semantic_id", "")) == card_id \
				and (str(targets.get("region_id", "")).is_empty() \
					or str(targets.get("region_id", "")) == region_id) \
				and str(candidate.get("legality_state", "")) == "available":
			offer = candidate.duplicate(true)
			if str(targets.get("region_id", "")).is_empty():
				target_overrides["region_id"] = region_id
			break
	if offer.is_empty() or _public_queue_count(queue) != 0:
		return {"success": false, "reason_code": "facility_formal_offer_missing"}
	var receipts: Array[Dictionary] = []
	var capture := func(receipt: Dictionary) -> void:
		receipts.append(receipt.duplicate(true))
	flow.receipt_ready.connect(capture)
	var adapter_before := adapter.debug_snapshot()
	var submitted := screen.submit_game_action_offer(
		offer,
		"human_click",
		{},
		target_overrides
	)
	coordinator.pause_session()
	if flow.receipt_ready.is_connected(capture):
		flow.receipt_ready.disconnect(capture)
	var receipt: Dictionary = receipts[0] if receipts.size() == 1 else {}
	var queued := submitted and receipts.size() == 1 \
		and bool(receipt.get("accepted", false)) \
		and str(receipt.get("reason_id", "")) == "facility-card-queued" \
		and _public_queue_count(queue) == 1
	if queued:
		coordinator.advance_card_resolution_frame(0.0)
	var adapter_after := adapter.debug_snapshot()
	var resolved_once := int(adapter_after.get("resolution_count", 0)) \
		== int(adapter_before.get("resolution_count", 0)) + 1
	return {
		"success": queued and resolved_once and _public_queue_count(queue) == 0,
		"reason_code": "facility_formal_queue_resolved" if queued and resolved_once \
			else str(receipt.get("reason_id", "facility_formal_queue_failed")),
		"receipt": receipt.duplicate(true),
		"resolution_delta": int(adapter_after.get("resolution_count", 0)) \
			- int(adapter_before.get("resolution_count", 0)),
	}


func _public_queue_count(queue: CardResolutionQueueRuntimeService) -> int:
	if queue == null:
		return -1
	var snapshot := queue.public_snapshot()
	return int(snapshot.get("current_count", 0)) \
		+ (1 if bool(snapshot.get("active_present", false)) else 0) \
		+ int(snapshot.get("next_count", 0))


func _matching_installation(
	flow: Object,
	direction: String,
	product_id: String,
	region_id: String,
	player_index: int
) -> Dictionary:
	var installations_variant: Variant = flow.call("installations_snapshot", false)
	var installations: Array = installations_variant if installations_variant is Array else []
	for installation_variant in installations:
		if not (installation_variant is Dictionary):
			continue
		var installation := installation_variant as Dictionary
		if bool(installation.get("active", false)) \
				and str(installation.get("direction", "")) == direction \
				and str(installation.get("commodity_id", "")) == product_id \
				and str(installation.get("region_id", "")) == region_id \
				and str(installation.get("owner_kind", "")) == "player" \
				and int(installation.get("installer_player_index", -1)) == player_index:
			return installation.duplicate(true)
	return {}


func _facility_for_slot(
	infrastructure: RegionInfrastructureRuntimeController,
	region_id: String,
	facility_type: String,
	industry_id: String,
	player_index: int
) -> Dictionary:
	for facility_variant in infrastructure.facilities_snapshot(false):
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		if bool(facility.get("active", false)) \
				and str(facility.get("region_id", "")) == region_id \
				and str(facility.get("facility_type", "")) == facility_type \
				and str(facility.get("industry_id", "")) == industry_id \
				and str(facility.get("owner_kind", "")) == "player" \
				and int(facility.get("owner_player_index", -1)) == player_index:
			return facility.duplicate(true)
	return {}


func _new_matching_sale(
	receipts: Array,
	start_index: int,
	product_id: String,
	player_index: int
) -> Dictionary:
	for index in range(maxi(0, start_index), receipts.size()):
		if receipts[index] is Dictionary \
				and str((receipts[index] as Dictionary).get("commodity_id", "")) == product_id \
				and int((receipts[index] as Dictionary).get("commodity_owner", -1)) == player_index:
			return (receipts[index] as Dictionary).duplicate(true)
	return {}


func _inventory_card_count(player_snapshot: Dictionary) -> int:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and not (slot_variant as Dictionary).is_empty():
			count += 1
	return count


func _inventory_slot_for_card(player_snapshot: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) \
			if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _inventory_has_card(player_snapshot: Dictionary, card_id: String) -> bool:
	return _inventory_slot_for_card(player_snapshot, card_id) >= 0


func _dictionary_at(rows: Array, index: int) -> Dictionary:
	return (rows[index] as Dictionary).duplicate(true) \
		if index >= 0 and index < rows.size() and rows[index] is Dictionary else {}


func _player_cash_cents(world: WorldSessionState, player_index: int) -> int:
	if world == null or player_index < 0 or player_index >= world.players.size() \
			or not (world.players[player_index] is Dictionary):
		return -1
	var player := world.players[player_index] as Dictionary
	return int(player.get("cash_cents", int(player.get("cash", 0)) * 100))


func _cleanup(app_root: Node) -> void:
	if app_root == null:
		return
	for node in app_root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	app_root.queue_free()
	await process_frame


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04_CLAIM_TO_SALE_INTEGRATION_TEST|status=%s|checks=%d|failures=%d" % [
		status,
		_checks,
		_failures.size(),
	])
	for failure in _failures:
		push_error("ALPHA04_CLAIM_TO_SALE_INTEGRATION_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
