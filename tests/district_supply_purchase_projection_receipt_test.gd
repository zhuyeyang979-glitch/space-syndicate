extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const GAME_ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const GAME_ACTION_OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const QA_SAVE_PATH := "user://test_runs/district_supply_purchase_projection_receipt.save"
const TARGET_CARD_ID := "facility.market.technology.rank_1"
const FIXED_SEED := 900626424

var _checks := 0
var _failures: Array[String] = []


class FailOnceFinalizeCardStateProxy:
	extends CardPlayerStateProductionAdapterV06

	var delegate: CardPlayerStateProductionAdapterV06
	var remaining_failures := 1
	var finalize_call_count := 0

	func facility_card_escrow_snapshot(escrow_id: String) -> Dictionary:
		return delegate.facility_card_escrow_snapshot(escrow_id)

	func consume_facility_card_escrow(
		escrow_id: String,
		expected_fingerprint: String
	) -> Dictionary:
		return delegate.consume_facility_card_escrow(escrow_id, expected_fingerprint)

	func preflight_finalize_facility_card_escrow(
		escrow_id: String,
		expected_fingerprint: String
	) -> Dictionary:
		return delegate.preflight_finalize_facility_card_escrow(
			escrow_id,
			expected_fingerprint
		)

	func finalize_facility_card_escrow(
		escrow_id: String,
		expected_fingerprint: String
	) -> Dictionary:
		finalize_call_count += 1
		if remaining_failures > 0:
			remaining_failures -= 1
			return {
				"finalized": false,
				"idempotent_replay": false,
				"reason_code": "qa_fail_once_facility_card_escrow_finalize",
			}
		return delegate.finalize_facility_card_escrow(
			escrow_id,
			expected_fingerprint
		)

	func release_facility_card_escrow(
		escrow_id: String,
		expected_fingerprint: String,
		reason_code: String
	) -> Dictionary:
		return delegate.release_facility_card_escrow(
			escrow_id,
			expected_fingerprint,
			reason_code
		)


class FailOnceFacilityFinalizeCoreProxy:
	extends CoreEconomicCardRuntimeAdapterV06

	var delegate: CoreEconomicCardRuntimeAdapterV06
	var remaining_failures := 1
	var finalize_call_count := 0

	func facility_target_context(
		actor_id: String,
		slot_index: int,
		card_id: String,
		region_id: String,
		game_time: float
	) -> Dictionary:
		return delegate.facility_target_context(
			actor_id,
			slot_index,
			card_id,
			region_id,
			game_time
		)

	func prepare_queued_facility_card(
		actor_id: String,
		card: Dictionary,
		target_context: Dictionary,
		transaction_id: String
	) -> Dictionary:
		return delegate.prepare_queued_facility_card(
			actor_id,
			card,
			target_context,
			transaction_id
		)

	func commit_queued_facility_card(preparation: Dictionary) -> Dictionary:
		return delegate.commit_queued_facility_card(preparation)

	func abort_queued_facility_card(preparation: Dictionary) -> Dictionary:
		return delegate.abort_queued_facility_card(preparation)

	func rollback_queued_facility_card(effect_receipt: Dictionary) -> Dictionary:
		return delegate.rollback_queued_facility_card(effect_receipt)

	func preflight_finalize_queued_facility_card(effect_receipt: Dictionary) -> Dictionary:
		return delegate.preflight_finalize_queued_facility_card(effect_receipt)

	func finalize_queued_facility_card(effect_receipt: Dictionary) -> Dictionary:
		finalize_call_count += 1
		if remaining_failures > 0:
			remaining_failures -= 1
			return {
				"finalized": false,
				"reason_code": "qa_fail_once_facility_effect_finalize",
			}
		return delegate.finalize_queued_facility_card(effect_receipt)


class SubmissionManaFaultProxy:
	extends PlayerManaRuntimeController

	var delegate: PlayerManaRuntimeController
	var fail_commit_receipt := false
	var fail_release_receipt := false
	var commit_call_count := 0
	var release_call_count := 0
	var last_transaction_id := ""

	func plan_reservation(request: Dictionary) -> Dictionary:
		return delegate.plan_reservation(request)

	func commit_reservation(plan: Dictionary) -> Dictionary:
		commit_call_count += 1
		var receipt := delegate.commit_reservation(plan)
		last_transaction_id = str(plan.get("transaction_id", "")) \
			if bool(plan.get("required", false)) else ""
		if fail_commit_receipt:
			receipt["committed"] = false
			receipt["authorized"] = false
			receipt["reason"] = "qa_mana_commit_receipt_failed"
		return receipt

	func reservation_snapshot(transaction_id: String) -> Dictionary:
		return delegate.reservation_snapshot(transaction_id)

	func reservation_settlement_snapshot(transaction_id: String) -> Dictionary:
		return delegate.reservation_settlement_snapshot(transaction_id)

	func release_reservation(transaction_id: String, reason: String = "released") -> Dictionary:
		release_call_count += 1
		if fail_release_receipt:
			return {
				"committed": true,
				"authorized": true,
				"settled": true,
				"transaction_id": transaction_id,
				"outcome": "released",
				"reason": reason,
			}
		return delegate.release_reservation(transaction_id, reason)


class SubmissionCardReleaseFaultProxy:
	extends CardPlayerStateProductionAdapterV06

	var delegate: CardPlayerStateProductionAdapterV06
	var fail_commit_receipt := false
	var fail_release_receipt := false
	var commit_call_count := 0
	var release_call_count := 0
	var last_escrow_id := ""
	var last_escrow_fingerprint := ""

	func actor_player_indices() -> Dictionary:
		return delegate.actor_player_indices()

	func plan_facility_card_escrow(request: Dictionary) -> Dictionary:
		return delegate.plan_facility_card_escrow(request)

	func commit_facility_card_escrow(plan: Dictionary) -> Dictionary:
		commit_call_count += 1
		var receipt := delegate.commit_facility_card_escrow(plan)
		last_escrow_id = str(receipt.get("escrow_id", ""))
		last_escrow_fingerprint = str(receipt.get("escrow_fingerprint", ""))
		if fail_commit_receipt:
			receipt["committed"] = false
			receipt["reason_code"] = "qa_card_escrow_commit_receipt_failed"
		return receipt

	func facility_card_escrow_snapshot(escrow_id: String) -> Dictionary:
		return delegate.facility_card_escrow_snapshot(escrow_id)

	func release_facility_card_escrow(
		escrow_id: String,
		expected_fingerprint: String,
		reason_code: String
	) -> Dictionary:
		release_call_count += 1
		if not fail_release_receipt:
			return delegate.release_facility_card_escrow(
				escrow_id,
				expected_fingerprint,
				reason_code
			)
		return {
			"committed": false,
			"consumed": false,
			"finalized": false,
			"released": true,
			"terminal": true,
			"reason_code": reason_code,
			"escrow_id": escrow_id,
			"state_id": "released",
			"escrow_fingerprint": expected_fingerprint,
			"receipt_fingerprint": "a".repeat(64),
			"idempotent_replay": false,
		}


class SubmissionQueueCommitFaultProxy:
	extends CardResolutionQueueRuntimeService

	var delegate: CardResolutionQueueRuntimeService
	var commit_before_failure := false
	var forge_successful_rollback_without_delegate := false
	var commit_call_count := 0
	var rollback_call_count := 0
	var status_call_count := 0
	var last_resolution_id := -1

	func plan_submission(request: Dictionary, facts: Dictionary) -> Dictionary:
		return delegate.plan_submission(request, facts)

	func commit_submission(plan: Dictionary, commit_receipt: Dictionary) -> Dictionary:
		commit_call_count += 1
		if commit_before_failure:
			var committed := delegate.commit_submission(plan, commit_receipt)
			last_resolution_id = int((committed.get("entry", {}) as Dictionary).get(
				"resolution_id",
				-1
			)) if committed.get("entry", {}) is Dictionary else -1
		return {
			"committed": false,
			"reason": "qa_queue_commit_failed",
		}

	func rollback_facility_submission(
		capability: RefCounted,
		request: Dictionary
	) -> Dictionary:
		rollback_call_count += 1
		if forge_successful_rollback_without_delegate:
			return {
				"schema_version": 1,
				"settlement_kind_id": "facility_queue_submission_rollback",
				"settled": true,
				"commitment_found": true,
				"rolled_back": true,
				"state_verified": true,
				"resolution_id": last_resolution_id,
				"outcome_id": "rolled_back",
				"reason_code": "facility_queue_submission_rolled_back",
				"idempotent_replay": false,
			}
		return delegate.rollback_facility_submission(capability, request)

	func facility_submission_status(
		capability: RefCounted,
		request: Dictionary
	) -> Dictionary:
		status_call_count += 1
		return delegate.facility_submission_status(capability, request)


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
			# Keep this target-binding fixture independent from product-triggered bonus draws.
			"role_indices": [3, 0, 1],
			"starter_monster_indices": [0, 1, 2],
		},
		QA_SAVE_PATH,
		"district-supply-purchase-projection-receipt"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start.get("started", false)) and app_root != null and coordinator != null, "real production session starts: reason=%s" % str(start.get("reason_code", "missing")))
	if app_root == null or coordinator == null:
		_finish()
		return

	var world := coordinator.world_session_state()
	coordinator.pause_session()
	await process_frame
	var query := coordinator.get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort
	var table_query := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var presentation := coordinator.card_supply_presentation_state()
	var port := coordinator.district_supply_action_port()
	var action_flow := coordinator.get_node_or_null("TablePlayerActionApplicationFlowController") \
		as TablePlayerActionApplicationFlowController
	var screen := app_root.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer if screen != null else null
	var infrastructure_owner := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	var configured := coordinator.configure_region_supply_from_world(
		FIXED_SEED,
		world.districts if world != null else [],
		[TARGET_CARD_ID],
		1
	)
	_expect(bool(configured.get("configured", false)), "fixed seed configures the target facility listing")
	var district_index := _first_purchasable_target_district(coordinator, world, infrastructure_owner)
	_expect(district_index >= 0, "fixed seed exposes the target facility in a currently purchasable district with an empty technology-market slot")
	_expect(query != null and table_query != null and query_ports != null and presentation != null and port != null and action_flow != null and screen != null and overlay != null, "typed rack query, hand query, privacy ports, GameScreen and action flow are composed")
	if district_index < 0 or query == null or table_query == null or query_ports == null or presentation == null or port == null or action_flow == null or screen == null or overlay == null:
		_stop_audio(app_root)
		app_root.queue_free()
		await process_frame
		_finish()
		return

	var human := (world.players[0] as Dictionary).duplicate(true)
	human["cash"] = 100_000
	human["action_cooldown"] = 0.0
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

	var intents: Array[Dictionary] = []
	var action_receipts: Array[Dictionary] = []
	var receipts: Array[DistrictSupplyActionReceipt] = []
	screen.game_action_intent_requested.connect(func(intent: Dictionary) -> void:
		intents.append(intent.duplicate(true))
	)
	action_flow.receipt_ready.connect(func(receipt: Dictionary) -> void:
		action_receipts.append(receipt.duplicate(true))
	)
	port.receipt_ready.connect(func(receipt: DistrictSupplyActionReceipt) -> void:
		receipts.append(receipt)
	)

	var first_table_state := table_query.compose_table_state(0, true)
	var first_surface: Dictionary = first_table_state.get("region_supply_popup", {}) \
		if first_table_state.get("region_supply_popup", {}) is Dictionary else {}
	_expect(overlay.apply_region_supply_popup_projection(first_surface, 0, context.authorization_revision), "viewer-private target facility drawer applies")
	var region_supply_popup := screen.get_region_supply_popup() as SpaceSyndicateRegionSupplyPopup
	var drawer := region_supply_popup.drawer if region_supply_popup != null else null
	var first_preview := _drawer_preview(drawer)
	_expect(_rack_projection_has_card(first_surface, TARGET_CARD_ID) \
			and not str(first_preview.get("card_name", "")).is_empty(), "fixed facility is present and the production drawer renders one stable rack preview")
	_expect(str(first_preview.get("primary_action_id", "")) == "district_supply_preview_card", "no-quote projection explicitly requests a quote")
	_expect(bool(first_preview.get("buy_enabled", false)) and str(first_preview.get("buy_text", "")).contains("获取报价"), "enabled button copy and action both describe quote acquisition")

	var quote_offer := region_supply_popup.action_offer_for_card(
		TARGET_CARD_ID,
		GAME_ACTION_INTENT.ACTION_DISTRICT_SUPPLY_QUOTE
	)
	_expect(not quote_offer.is_empty() \
			and screen.submit_game_action_offer(quote_offer, "human_click", {}, {}), "human Popup-to-GameScreen path submits the sealed quote offer")
	_expect(intents.size() == 1 \
			and str(intents[0].get("semantic_action_id", "")) == GAME_ACTION_INTENT.ACTION_DISTRICT_SUPPLY_QUOTE \
			and action_receipts.size() == 1 and bool(action_receipts[0].get("accepted", false)), "human Popup-to-GameScreen path emits and accepts one typed quote intent first")
	_expect(receipts.size() == 1 and receipts[0].accepted and receipts[0].reason_code == "quote_locked", "authoritative port accepts and reports the locked quote: %s" % _receipt_debug(receipts))
	_expect(receipts.size() == 1 and not receipts[0].quote_id.is_empty(), "private quote receipt carries the locked quote credential")

	var second_table_state := table_query.compose_table_state(0, true)
	var second_surface: Dictionary = second_table_state.get("region_supply_popup", {}) \
		if second_table_state.get("region_supply_popup", {}) is Dictionary else {}
	_expect(overlay.apply_region_supply_popup_projection(second_surface, 0, context.authorization_revision), "post-quote viewer-private projection reapplies")
	var second_preview := _drawer_preview(drawer)
	_expect(str(second_preview.get("primary_action_id", "")) == "district_supply_purchase_card", "active quote projection advances to purchase: %s" % JSON.stringify(second_preview))
	_expect(bool(second_preview.get("buy_enabled", false)) \
			and str(second_preview.get("buy_text", "")) == "购买", "buy-enabled projection exposes the closed purchase command")

	var before_purchase := port.debug_snapshot()
	var purchase_offer := region_supply_popup.action_offer_for_card(
		TARGET_CARD_ID,
		GAME_ACTION_INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE
	)
	_expect(not purchase_offer.is_empty() \
			and screen.submit_game_action_offer(purchase_offer, "human_click", {}, {}), "same human surface submits the sealed purchase offer only after quote")
	_expect(intents.size() == 2 \
			and str(intents[1].get("semantic_action_id", "")) == GAME_ACTION_INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE \
			and action_receipts.size() == 2 and bool(action_receipts[1].get("accepted", false)), "same human surface emits and accepts one typed purchase only after quote")
	_expect(receipts.size() == 2 and receipts[1].accepted and receipts[1].applied, "authoritative purchase receipt commits the facility card: %s" % _receipt_debug(receipts))
	_expect(receipts.size() == 2 and receipts[1].reason_code != "locked_quote_required", "purchase no longer reaches the missing-quote rejection")
	var after_purchase := port.debug_snapshot()
	_expect(int(after_purchase.get("purchase_commit_count", 0)) == int(before_purchase.get("purchase_commit_count", 0)) + 1, "purchase mutation commits exactly once")
	var purchase_replay := action_flow.submit_intent(intents[1]) if intents.size() > 1 else {}
	var after_purchase_replay := port.debug_snapshot()
	_expect(bool(purchase_replay.get("idempotent_replay", false)) \
			and bool(purchase_replay.get("accepted", false)), "duplicate typed GameAction submit returns the exact idempotent receipt replay")
	_expect(int(after_purchase_replay.get("purchase_commit_count", 0)) \
			== int(after_purchase.get("purchase_commit_count", 0)), "duplicate submit cannot commit a second card or debit")

	var actor_binding := coordinator.actor_id_for_player_index(0)
	var actor_id := str(actor_binding.get("actor_id", ""))
	var economic_after_purchase := coordinator.economic_source_snapshot(actor_id)
	_expect(bool(actor_binding.get("available", false)) and not actor_id.is_empty(), "current human resolves to one authoritative v0.6 actor")
	_expect(int(economic_after_purchase.get("owned_facility_count", -1)) == 0 and int(economic_after_purchase.get("production_installation_count", -1)) == 0, "purchasing a facility card does not install a facility or production source")

	var private_projection := query_ports.private_world_projection(0, 0).to_dictionary()
	var private_projection_text := JSON.stringify(private_projection)
	var public_projection_text := JSON.stringify(query_ports.public_world_projection().to_dictionary())
	_expect(private_projection_text.contains(TARGET_CARD_ID), "authorized owner projection exposes only the stable v0.6 card identity needed for presentation")
	_expect(not private_projection_text.contains('"machine"') and not private_projection_text.contains("runtime_instance_id"), "authorized owner projection does not expose the machine envelope or runtime instance identity")
	_expect(not public_projection_text.contains(TARGET_CARD_ID) and not public_projection_text.contains('"machine"') and not public_projection_text.contains("runtime_instance_id"), "public table projection does not expose the bought card or its internal identities")
	var denied_projection := query_ports.private_world_projection(1, 0).to_dictionary()
	_expect(not bool(denied_projection.get("authorized", true)) and (denied_projection.get("player", {}) as Dictionary).is_empty() and str(denied_projection.get("visibility_scope", "")) == "denied", "another viewer receives only a denied envelope for the human player's private hand")

	coordinator.request_table_presentation_refresh(&"full", &"qa_facility_card_dock_after_purchase")
	await process_frame
	var table_state := screen.current_ui_data.duplicate(true)
	var player_card_dock: Dictionary = table_state.get("player_card_dock", {}) \
		if table_state.get("player_card_dock", {}) is Dictionary else {}
	var normal_cards: Array = player_card_dock.get("normal_cards", []) \
		if player_card_dock.get("normal_cards", []) is Array else []
	var facility_hand := _first_dock_card(normal_cards, TARGET_CARD_ID)
	var facility_slot := _dock_slot_index(facility_hand)
	var malformed_definition := coordinator.v06_card_definition(TARGET_CARD_ID)
	var malformed_machine: Dictionary = (malformed_definition.get("machine", {}) as Dictionary).duplicate(true) if malformed_definition.get("machine", {}) is Dictionary else {}
	var malformed_cost: Dictionary = (malformed_machine.get("asset_cost", {}) as Dictionary).duplicate(true) if malformed_machine.get("asset_cost", {}) is Dictionary else {}
	malformed_cost["life"] = 1.0000001
	malformed_machine["asset_cost"] = malformed_cost
	malformed_definition["machine"] = malformed_machine
	var malformed_skill_variant: Variant = table_query.call("_normalized_v06_skill", malformed_definition)
	var malformed_skill: Dictionary = malformed_skill_variant if malformed_skill_variant is Dictionary else {}
	var malformed_facts := coordinator.card_play_world_facts(0, malformed_skill, {"selected_district": district_index, "slot_index": facility_slot})
	var malformed_eligibility := coordinator.evaluate_card_play({"player_index": 0, "skill": malformed_skill, "evaluation_mode": "rule"}, malformed_facts)
	_expect(str(malformed_eligibility.get("reason_code", "")) == "asset_cost_invalid_amount" and str(malformed_skill.get("cost", "")) == "费用数据异常", "fractional JSON asset cost remains invalid instead of being rounded into a playable card")
	malformed_cost.erase("generic")
	malformed_machine["asset_cost"] = malformed_cost
	malformed_definition["machine"] = malformed_machine
	var missing_cost_skill_variant: Variant = table_query.call("_normalized_v06_skill", malformed_definition)
	var missing_cost_skill: Dictionary = missing_cost_skill_variant if missing_cost_skill_variant is Dictionary else {}
	_expect(str(missing_cost_skill.get("cost", "")) == "费用数据异常", "missing one authoritative asset key cannot be presented as a free play")
	var missing_cost_facts := coordinator.card_play_world_facts(0, missing_cost_skill, {"selected_district": district_index, "slot_index": facility_slot})
	var missing_cost_eligibility := coordinator.evaluate_card_play({"player_index": 0, "skill": missing_cost_skill, "evaluation_mode": "hand"}, missing_cost_facts)
	var missing_cost_state := coordinator.compose_card_play_eligibility(missing_cost_eligibility, {"display_name": "设施牌"})
	_expect(not bool(missing_cost_eligibility.get("actionable", true)) and str(missing_cost_eligibility.get("reason_code", "")) == "asset_cost_unavailable", "missing v0.6 asset key disables the formal hand action")
	_expect(str(missing_cost_state.get("detail", "")).contains("不会扣牌或资产") and not JSON.stringify(missing_cost_eligibility.get("reason_args", {})).contains("generic"), "missing asset schema exposes only a readable public-safe reason")
	var facility_action := _first_enabled_play_action(facility_hand)
	_expect(not facility_hand.is_empty() \
			and str(facility_hand.get("card_semantic_id", "")) == TARGET_CARD_ID \
			and not str(facility_hand.get("display_name", "")).is_empty(), "bought v0.6 facility is rendered from its stable authored card identity")
	_expect(str(facility_hand.get("facility_kind", "")) == "market" \
			and str(facility_hand.get("industry_id", "")) == "technology" \
			and int(facility_hand.get("rank", 0)) == 1, "facility Dock row carries closed structural facility metadata without raw machine or prose inference")
	_expect(not JSON.stringify(facility_hand).contains("machine") \
			and not JSON.stringify(facility_hand).contains("effect_payload"), "facility Dock row exposes no raw rule payload aliases")
	_expect(str(facility_hand.get("play_state", "")) == "available" \
			and not facility_action.is_empty(), "facility hand card exposes one enabled sealed GameAction offer")

	var inventory_before_play := coordinator.v06_card_player_snapshot(actor_id)
	var authoritative_inventory: Dictionary = inventory_before_play.get("inventory", {}) if inventory_before_play.get("inventory", {}) is Dictionary else {}
	var authoritative_slots: Array = authoritative_inventory.get("slots", []) if authoritative_inventory.get("slots", []) is Array else []
	var authoritative_card: Dictionary = authoritative_slots[facility_slot] if facility_slot >= 0 and facility_slot < authoritative_slots.size() and authoritative_slots[facility_slot] is Dictionary else {}
	var runtime_instance_id := str(authoritative_card.get("runtime_instance_id", ""))
	var region_id := str(district.get("region_id", ""))
	var play_transaction_id := "v06-play:%s:%s:%s" % [actor_id, runtime_instance_id, region_id]
	var inventory_owner := coordinator.get_node_or_null("CommodityCardInventoryRuntimeController")
	var journal_before: Dictionary = inventory_owner.call("transaction_journal_snapshot") if inventory_owner != null else {}
	var queue_owner := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var queue_before_text := JSON.stringify(queue_owner.public_snapshot()) if queue_owner != null else ""
	_expect(not runtime_instance_id.is_empty() and facility_slot >= 0, "formal hand slot resolves to one authoritative inventory instance before play")
	_expect(infrastructure_owner != null, "the unique region-infrastructure owner is composed for exact-once verification")
	var legacy_entry_before := JSON.stringify(infrastructure_owner.facilities_snapshot(true)) if infrastructure_owner != null else ""
	var legacy_entry_result := coordinator.submit_public_facility_card({
		"transaction_id": "qa-retired-public-facility-entry",
		"player_index": 0,
		"target_region_index": district_index,
		"skill": {"kind": "public_facility", "card_id": TARGET_CARD_ID},
	})
	_expect(not bool(legacy_entry_result.get("committed", true)) and str(legacy_entry_result.get("reason", "")) == "legacy_public_facility_entry_retired", "legacy public-facility queue entry is explicitly retired instead of owning a second facility mutation path")
	_expect((JSON.stringify(infrastructure_owner.facilities_snapshot(true)) if infrastructure_owner != null else "") == legacy_entry_before, "retired legacy public entry changes no authoritative facility state")
	var occupied_region_id := ""
	for district_variant in world.districts:
		if not (district_variant is Dictionary):
			continue
		var candidate_region_id := str((district_variant as Dictionary).get("region_id", ""))
		if candidate_region_id == region_id \
				or not _facility_for_slot(infrastructure_owner, candidate_region_id, "market", "technology").is_empty():
			continue
		occupied_region_id = candidate_region_id
		break
	var occupied_seed := infrastructure_owner.apply_facility_action({
		"transaction_id": "qa-public-action-occupied-target",
		"region_id": occupied_region_id,
		"owner_kind": "neutral",
		"owner_player_index": -1,
		"facility_type": "market",
		"industry_id": "technology",
		"rank": 1,
		"occurred_at": world.game_time,
	}) if infrastructure_owner != null and not occupied_region_id.is_empty() else {}
	var occupied_finalized := infrastructure_owner.finalize_facility_action(occupied_seed) if infrastructure_owner != null and bool(occupied_seed.get("committed", false)) else {}
	var exact_target_journal_before := JSON.stringify(inventory_owner.call("transaction_journal_snapshot")) if inventory_owner != null else ""
	var exact_target_reject := _submit_game_action(screen, facility_action, {"region_id": occupied_region_id})
	_expect(bool(occupied_finalized.get("finalized", false)) and not exact_target_reject, "the sealed production offer rejects an occupied target override instead of substituting another region: seed=%s" % JSON.stringify(occupied_finalized))
	_expect((JSON.stringify(inventory_owner.call("transaction_journal_snapshot")) if inventory_owner != null else "") == exact_target_journal_before and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) == _inventory_card_count(inventory_before_play), "invalid public target preserves the requested card and creates no formal play journal entry")
	var cooldown_arm := coordinator.arm_player_action_cooldown(0, 5.0)
	_expect(bool(cooldown_arm.get("armed", false)) and float((world.players[0] as Dictionary).get("action_cooldown", 0.0)) >= 5.0, "authoritative cooldown owner arms the deliberate rejection gate")
	var gate_journal_before := JSON.stringify(inventory_owner.call("transaction_journal_snapshot")) if inventory_owner != null else ""
	var gate_facilities_before := JSON.stringify(infrastructure_owner.facilities_snapshot(true)) if infrastructure_owner != null else ""
	var gate_flow_before := JSON.stringify(coordinator.commodity_flow_to_save_data())
	var gate_mana_before := JSON.stringify(coordinator.player_mana_to_save_data())
	var blocked_submission := coordinator.card_play_submission_controller().request_hand_play({"player_index": 0, "slot_index": facility_slot, "submission_source": "qa_manual_stale_action"})
	_expect(not bool(blocked_submission.get("accepted", true)) and str(blocked_submission.get("reason", "")) == "player_action_cooldown", "manual v0.6 facility submission passes the final CardPlayEligibility hard gate")
	_expect((JSON.stringify(inventory_owner.call("transaction_journal_snapshot")) if inventory_owner != null else "") == gate_journal_before \
			and (JSON.stringify(infrastructure_owner.facilities_snapshot(true)) if infrastructure_owner != null else "") == gate_facilities_before \
			and JSON.stringify(coordinator.commodity_flow_to_save_data()) == gate_flow_before \
			and JSON.stringify(coordinator.player_mana_to_save_data()) == gate_mana_before, "eligibility rejection occurs before every card, facility, flow, asset and journal mutation")
	var cooldown_clear := coordinator.advance_card_cooldowns(5.0)
	_expect(bool(cooldown_clear.get("advanced", false)) and float((world.players[0] as Dictionary).get("action_cooldown", -1.0)) <= 0.0, "authoritative cooldown owner clears the deliberately injected rejection gate")

	coordinator.request_table_presentation_refresh(&"full", &"qa_facility_card_dock_after_cooldown")
	await process_frame
	var refreshed_table_state := screen.current_ui_data.duplicate(true)
	var refreshed_dock: Dictionary = refreshed_table_state.get("player_card_dock", {}) \
		if refreshed_table_state.get("player_card_dock", {}) is Dictionary else {}
	var refreshed_normal_cards: Array = refreshed_dock.get("normal_cards", []) \
		if refreshed_dock.get("normal_cards", []) is Array else []
	var refreshed_facility_hand := _first_dock_card(refreshed_normal_cards, TARGET_CARD_ID)
	var refreshed_facility_action := _first_enabled_play_action(refreshed_facility_hand)
	_expect(_dock_slot_index(refreshed_facility_hand) == facility_slot \
			and not refreshed_facility_action.is_empty(), "fresh viewer projection re-enables the same authoritative facility slot after cooldown expiry")
	var direct_probe_before := {
		"inventory": coordinator.v06_card_player_snapshot(actor_id),
		"facilities": infrastructure_owner.facilities_snapshot(true),
		"mana": coordinator.player_mana_to_save_data(),
	}
	var direct_probe := coordinator.play_v06_runtime_card({
		"actor_id": actor_id,
		"slot_index": facility_slot,
		"transaction_id": play_transaction_id,
		"region_id": region_id,
		"game_time": world.game_time,
	})
	_expect(not bool(direct_probe.get("committed", true)) \
			and str(direct_probe.get("reason_code", "")) == "v06_facility_requires_game_action_spine", "direct v0.6 facility runtime calls fail closed at the production Action Spine boundary")
	_expect(JSON.stringify(coordinator.v06_card_player_snapshot(actor_id)) == JSON.stringify(direct_probe_before.get("inventory", {})) \
			and JSON.stringify(infrastructure_owner.facilities_snapshot(true)) == JSON.stringify(direct_probe_before.get("facilities", [])) \
			and JSON.stringify(coordinator.player_mana_to_save_data()) == JSON.stringify(direct_probe_before.get("mana", {})), "rejected direct calls mutate no card, facility, or asset owner")
	var adapter := coordinator.facility_card_queue_adapter_v06()
	var adapter_before := adapter.debug_snapshot() if adapter != null else {}
	var submission_before := coordinator.card_play_submission_controller().debug_snapshot()
	coordinator.resume_session()
	_expect(_submit_game_action(screen, refreshed_facility_action), "fresh facility projection submits through the public GameAction offer boundary")
	var submission_after := coordinator.card_play_submission_controller().debug_snapshot()
	var play_receipt: Dictionary = submission_after.get("last_receipt", {}) if submission_after.get("last_receipt", {}) is Dictionary else {}
	var v06_receipt: Dictionary = play_receipt.get("v06_receipt", {}) if play_receipt.get("v06_receipt", {}) is Dictionary else {}
	var queue_during := queue_owner.public_snapshot() if queue_owner != null else {}
	var economic_after_submission := coordinator.economic_source_snapshot(actor_id)
	_expect(int(submission_after.get("submission_count", 0)) == int(submission_before.get("submission_count", 0)) + 1 \
			and int(submission_after.get("accepted_count", 0)) == int(submission_before.get("accepted_count", 0)) + 1 \
			and bool(play_receipt.get("accepted", false)) and bool(play_receipt.get("queued", false)) \
			and bool(v06_receipt.get("accepted", false)) and bool(v06_receipt.get("queued", false)), "formal GameScreen action commits exactly one queue entry and returns queued feedback|before=%s after=%s receipt=%s" % [JSON.stringify(submission_before), JSON.stringify(submission_after), JSON.stringify(play_receipt)])
	_expect(_public_queue_count(queue_during) == 1 and int(economic_after_submission.get("owned_facility_count", 0)) == 0, "facility submission survives as one public anonymous Queue entry without applying the facility")
	_expect(not _contains_private_queue_value(queue_during), "public facility Queue projection omits actor, seat, owner, card instance, reservation, and escrow bindings")
	var queued_resolution_id := int(v06_receipt.get("resolution_id", -1))
	var queued_entry := queue_owner.entry_by_id(queued_resolution_id) if queue_owner != null else {}
	var queued_binding: Dictionary = queued_entry.get("v06_facility_action", {}) \
		if queued_entry.get("v06_facility_action", {}) is Dictionary else {}
	var reservation_ref: Dictionary = queued_binding.get("asset_reservation", {}) \
		if queued_binding.get("asset_reservation", {}) is Dictionary else {}
	var escrow_ref: Dictionary = queued_binding.get("card_escrow", {}) \
		if queued_binding.get("card_escrow", {}) is Dictionary else {}
	var adapter_capability := adapter.get("_submission_capability") as RefCounted \
		if adapter != null else null
	var adapter_request := _adapter_request_from_entry(queued_entry)
	var queued_replay := adapter.submit(adapter_capability, adapter_request) \
		if adapter != null and adapter_capability != null else {}
	_expect(bool(queued_replay.get("accepted", false)) \
			and bool(queued_replay.get("queued", false)) \
			and bool(queued_replay.get("idempotent_replay", false)) \
			and int(queued_replay.get("resolution_id", -1)) == queued_resolution_id \
			and _public_queue_count(queue_owner.public_snapshot()) == 1, "same successful request returns a queued replay without entering compensation or removing the live Queue entry")
	var queue_rollback_request_variant: Variant = adapter.call(
		"_queue_rollback_request",
		adapter_request,
		str(escrow_ref.get("escrow_id", "")),
		queued_resolution_id,
		"qa_forged_queue_rollback"
	) if adapter != null else {}
	var queue_rollback_request: Dictionary = queue_rollback_request_variant \
		if queue_rollback_request_variant is Dictionary else {}
	var forged_queue_rollback := queue_owner.rollback_facility_submission(
		RefCounted.new(),
		queue_rollback_request
	) if queue_owner != null else {}
	_expect(not bool(forged_queue_rollback.get("settled", true)) \
			and str(forged_queue_rollback.get("reason_code", "")) \
				== "facility_queue_submission_rollback_unauthorized" \
			and not queue_owner.entry_by_id(queued_resolution_id).is_empty(), "caller-forged Queue rollback capability cannot remove or inspect the committed facility entry")
	var forged_submission := adapter.submit(RefCounted.new(), adapter_request) \
		if adapter != null else {}
	_expect(not bool(forged_submission.get("accepted", true)) \
			and str(forged_submission.get("reason_code", "")) == "facility_queue_submission_unauthorized", "caller-forged capabilities cannot invoke the facility Queue source")
	var target_mismatch_request := adapter_request.duplicate(true)
	target_mismatch_request["region_id"] = "%s.changed" % str(adapter_request.get("region_id", ""))
	var target_mismatch := adapter.submit(adapter_capability, target_mismatch_request) \
		if adapter != null and adapter_capability != null else {}
	_expect(not bool(target_mismatch.get("accepted", true)) \
			and str(target_mismatch.get("reason_code", "")) == "facility_queue_stable_target_binding_mismatch", "authorized source rejects a request region that diverges from its sealed target envelope")
	var hostile_source := FacilityCardQueueAdapterV06.new()
	root.add_child(hostile_source)
	var hostile_bind := coordinator.card_play_submission_controller().bind_facility_queue_source(
		hostile_source,
		RefCounted.new()
	)
	_expect(not bool(hostile_bind.get("bound", true)) \
			and str(hostile_bind.get("reason_code", "")) == "facility_queue_source_rebind_rejected", "the production submission port rejects hostile source/capability rebinding")
	hostile_source.queue_free()
	var real_card_state := coordinator.card_player_state_production_adapter_v06()
	var real_core := coordinator.core_economic_card_runtime_adapter_v06()
	var mana_owner := coordinator.get_node_or_null("PlayerManaRuntimeController") \
		as PlayerManaRuntimeController
	var execution_owner := coordinator.get_node_or_null("CardResolutionExecutionRuntimeService") \
		as CardResolutionExecutionRuntimeService
	var history_count_before_finalize_fault := coordinator.card_resolution_history_snapshot().size()
	var facility_count_before_resolution := infrastructure_owner.facilities_snapshot(true).size() \
		if infrastructure_owner != null else -1
	var core_finalize_proxy := FailOnceFacilityFinalizeCoreProxy.new()
	core_finalize_proxy.delegate = real_core
	root.add_child(core_finalize_proxy)
	adapter.set("_core", core_finalize_proxy)
	var failed_finalize_step := coordinator.advance_card_resolution_frame(0.0)
	var execution_after_finalize_failure := execution_owner.immediate_facility_resolution_snapshot() \
		if execution_owner != null else {}
	var facility_after_finalize_failure := infrastructure_owner.facilities_snapshot(true) \
		if infrastructure_owner != null else []
	var reservation_after_finalize_failure := mana_owner.reservation_settlement_snapshot(
		str(reservation_ref.get("reservation_id", ""))
	) if mana_owner != null else {}
	var reservation_released := (
		str(reservation_after_finalize_failure.get("outcome_id", "")) == "released"
	) if bool(reservation_ref.get("required", false)) else (
		str(reservation_ref.get("reservation_id", "")).is_empty()
		and str(reservation_after_finalize_failure.get("outcome_id", "")) == "missing"
	)
	var escrow_after_finalize_failure := real_card_state.facility_card_escrow_snapshot(
		str(escrow_ref.get("escrow_id", ""))
	) if real_card_state != null else {}
	_expect(bool(failed_finalize_step.get("handled", false)) \
			and not bool(execution_after_finalize_failure.get("pending", false)) \
			and core_finalize_proxy.finalize_call_count == 1 \
			and core_finalize_proxy.remaining_failures == 0, "facility finalization failure completes one terminal rollback without leaving an execution retry")
	_expect(facility_after_finalize_failure.size() == facility_count_before_resolution \
			and reservation_released \
			and bool(escrow_after_finalize_failure.get("terminal", false)) \
			and str((escrow_after_finalize_failure.get("receipt", {}) as Dictionary).get("state_id", "")) == "released" \
			and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) == _inventory_card_count(inventory_before_play) \
			and coordinator.card_resolution_history_snapshot().size() == history_count_before_finalize_fault + 1, "facility finalization failure rolls back facility, assets and pending card before the terminal history receipt")
	adapter.set("_core", real_core)
	core_finalize_proxy.queue_free()
	coordinator.advance_card_cooldowns(60.0)
	coordinator.request_table_presentation_refresh(&"full", &"qa_facility_card_dock_after_finalize_rollback")
	await process_frame
	var retry_table := screen.current_ui_data.duplicate(true)
	var retry_dock: Dictionary = retry_table.get("player_card_dock", {}) \
		if retry_table.get("player_card_dock", {}) is Dictionary else {}
	var retry_hand := _first_dock_card(
		retry_dock.get("normal_cards", []) if retry_dock.get("normal_cards", []) is Array else [],
		TARGET_CARD_ID
	)
	var retry_action := _first_enabled_play_action(retry_hand)
	var parity_world_time_before := world.game_time
	var parity_safety_before := coordinator.save_restore_safety_observation()
	var parity_gdp_before := coordinator.commodity_flow_region_gdp_snapshot(region_id)
	var parity_victory_before := coordinator.victory_control_world_snapshot()
	var parity_cash_before := int((world.players[0] as Dictionary).get("cash", 0))
	var parity_mana_before := mana_owner.availability_snapshot(0) if mana_owner != null else {}
	var historical_direct_owner_fixture := _facility_for_slot(
		infrastructure_owner,
		occupied_region_id,
		"market",
		"technology"
	)
	_expect(not retry_action.is_empty() and _submit_game_action(screen, retry_action), "the fully rolled-back authoritative card can be resubmitted through a fresh GameAction offer")
	var retry_submission := coordinator.card_play_submission_controller().debug_snapshot()
	var retry_play_receipt: Dictionary = retry_submission.get("last_receipt", {}) \
		if retry_submission.get("last_receipt", {}) is Dictionary else {}
	var retry_v06_receipt: Dictionary = retry_play_receipt.get("v06_receipt", {}) \
		if retry_play_receipt.get("v06_receipt", {}) is Dictionary else {}
	var retry_entry := queue_owner.entry_by_id(int(retry_v06_receipt.get("resolution_id", -1))) \
		if queue_owner != null else {}
	var retry_adapter_request := _adapter_request_from_entry(retry_entry)
	var retry_binding: Dictionary = retry_entry.get("v06_facility_action", {}) \
		if retry_entry.get("v06_facility_action", {}) is Dictionary else {}
	reservation_ref = retry_binding.get("asset_reservation", {}) \
		if retry_binding.get("asset_reservation", {}) is Dictionary else {}
	escrow_ref = retry_binding.get("card_escrow", {}) \
		if retry_binding.get("card_escrow", {}) is Dictionary else {}
	var history_count_before_card_finalize_retry := coordinator.card_resolution_history_snapshot().size()
	var card_finalize_proxy := FailOnceFinalizeCardStateProxy.new()
	card_finalize_proxy.delegate = real_card_state
	root.add_child(card_finalize_proxy)
	adapter.set("_card_state", card_finalize_proxy)
	var retryable_step := coordinator.advance_card_resolution_frame(0.0)
	var execution_during_card_retry := execution_owner.immediate_facility_resolution_snapshot() \
		if execution_owner != null else {}
	var facility_during_card_retry := infrastructure_owner.facilities_snapshot(true) \
		if infrastructure_owner != null else []
	var reservation_during_card_retry := mana_owner.reservation_settlement_snapshot(
		str(reservation_ref.get("reservation_id", ""))
	) if mana_owner != null else {}
	var escrow_during_card_retry := real_card_state.facility_card_escrow_snapshot(
		str(escrow_ref.get("escrow_id", ""))
	) if real_card_state != null else {}
	_expect(not bool(retryable_step.get("handled", true)) \
			and bool(execution_during_card_retry.get("pending", false)) \
			and card_finalize_proxy.finalize_call_count == 1, "post-facility card finalization fault leaves one retryable commitment instead of compensating an already-finalized facility")
	_expect(facility_during_card_retry.size() == facility_count_before_resolution + 1 \
			and (str(reservation_during_card_retry.get("outcome_id", "")) == "consumed" \
				or not bool(reservation_ref.get("required", false))) \
			and bool(escrow_during_card_retry.get("found", false)) \
			and str((escrow_during_card_retry.get("escrow", {}) as Dictionary).get("state_id", "")) == "consumed_pending_finalization" \
			and coordinator.card_resolution_history_snapshot().size() == history_count_before_card_finalize_retry, "retryable commitment preserves finalized facility, consumed assets and full escrow without premature history")
	var successful_step := coordinator.advance_card_resolution_frame(0.0)
	var execution_after_success := execution_owner.immediate_facility_resolution_snapshot() \
		if execution_owner != null else {}
	adapter.set("_card_state", real_card_state)
	card_finalize_proxy.queue_free()
	_expect(bool(successful_step.get("handled", false)) \
			and not bool(execution_after_success.get("pending", false)) \
			and card_finalize_proxy.finalize_call_count == 2 \
			and coordinator.card_resolution_history_snapshot().size() == history_count_before_card_finalize_retry + 1, "the next authorized logical step settles the pending card exactly once without replaying the finalized facility")
	coordinator.pause_session()
	var adapter_after := adapter.debug_snapshot() if adapter != null else {}
	var economic_after_play := coordinator.economic_source_snapshot(actor_id)
	var inventory_after_play := coordinator.v06_card_player_snapshot(actor_id)
	var journal_after: Dictionary = inventory_owner.call("transaction_journal_snapshot") if inventory_owner != null else {}
	var infrastructure_after_play := infrastructure_owner.region_snapshot(region_id) if infrastructure_owner != null else {}
	var world_player_after_play: Dictionary = (world.players[0] as Dictionary).duplicate(true) if world.players[0] is Dictionary else {}
	var parity_safety_after := coordinator.save_restore_safety_observation()
	var parity_gdp_after := coordinator.commodity_flow_region_gdp_snapshot(region_id)
	var parity_victory_after := coordinator.victory_control_world_snapshot()
	var parity_mana_after := mana_owner.availability_snapshot(0) if mana_owner != null else {}
	var queued_facility := _facility_for_slot(infrastructure_owner, region_id, "market", "technology")
	var terminal_reservation := mana_owner.reservation_settlement_snapshot(
		str(reservation_ref.get("reservation_id", ""))
	) if mana_owner != null else {}
	var terminal_escrow := real_card_state.facility_card_escrow_snapshot(
		str(escrow_ref.get("escrow_id", ""))
	) if real_card_state != null else {}
	_expect(adapter != null and int(adapter_after.get("resolution_count", 0)) == int(adapter_before.get("resolution_count", 0)) + 1 \
			and _public_queue_count(queue_owner.public_snapshot()) == 0, "the next authorized command-only card resolution settles the Queue exactly once")
	_expect(int(economic_after_play.get("owned_facility_count", 0)) == 1 and int(economic_after_play.get("production_installation_count", 0)) == 0, "technology market play creates exactly one market facility and no fake factory production installation")
	_expect(_inventory_card_count(inventory_after_play) == _inventory_card_count(inventory_before_play) - 1, "successful resolution consumes one escrowed authoritative hand instance")
	_expect(queue_owner != null and JSON.stringify(queue_owner.public_snapshot()) == queue_before_text, "resolved facility Queue returns to its exact empty public shape")
	_expect(_facility_rule_projection(queued_facility) == _facility_rule_projection(historical_direct_owner_fixture), "FACILITY_EFFECT_STATE_PARITY: queued Rank-I market matches the characterized direct RegionInfrastructure owner result")
	_expect(world.game_time == parity_world_time_before \
			and int(parity_safety_after.get("world_clock_advance_count", -1)) == int(parity_safety_before.get("world_clock_advance_count", -2)) \
			and int(parity_safety_after.get("rng_draw_invocation_count", -1)) == int(parity_safety_before.get("rng_draw_invocation_count", -2)) \
			and parity_gdp_after == parity_gdp_before \
			and _victory_parity_projection(parity_victory_after) \
				== _victory_parity_projection(parity_victory_before), "FACILITY_RNG_DELTA_PARITY: queued resolution advances no world time, RNG, GDP receipt window, or Victory state|time=%s/%s safety=%s/%s gdp=%s/%s victory=%s/%s" % [parity_world_time_before, world.game_time, JSON.stringify(parity_safety_before), JSON.stringify(parity_safety_after), JSON.stringify(parity_gdp_before), JSON.stringify(parity_gdp_after), JSON.stringify(_victory_parity_projection(parity_victory_before)), JSON.stringify(_victory_parity_projection(parity_victory_after))])
	_expect(int((world.players[0] as Dictionary).get("cash", -1)) == parity_cash_before \
			and parity_mana_after == parity_mana_before \
			and (str(terminal_reservation.get("outcome_id", "")) == "consumed" \
				or not bool(reservation_ref.get("required", false))), "FACILITY_COST_PARITY: Rank-I activation preserves cash and zero-cost asset pools while settling its reservation once")
	_expect(bool(terminal_escrow.get("terminal", false)) \
			and str((terminal_escrow.get("receipt", {}) as Dictionary).get("state_id", "")) == "consumed_finalized" \
			and _inventory_card_count(inventory_after_play) == _inventory_card_count(inventory_before_play) - 1, "FACILITY_CARD_LIFECYCLE_PARITY: one played card reaches one terminal consumed escrow state")

	coordinator.resume_session()
	var terminal_request_replay := adapter.submit(adapter_capability, retry_adapter_request)
	coordinator.pause_session()
	_expect(_has_exact_fields(terminal_request_replay, [
			"accepted",
			"queued",
			"committed",
			"terminal",
			"idempotent_replay",
			"reason_code",
		]) \
			and not bool(terminal_request_replay.get("accepted", true)) \
			and not bool(terminal_request_replay.get("queued", true)) \
			and bool(terminal_request_replay.get("committed", false)) \
			and bool(terminal_request_replay.get("terminal", false)) \
			and bool(terminal_request_replay.get("idempotent_replay", false)) \
			and not bool(terminal_request_replay.get("requires_recovery", false)), "same successful request replays the consumed-finalized Card Owner receipt without entering compensation|result=%s" % JSON.stringify(terminal_request_replay))

	var terminal_world_save: Dictionary = world.to_save_data().duplicate(true)
	var terminal_mana_save: Dictionary = mana_owner.to_save_data().duplicate(true) \
		if mana_owner != null else {}
	var terminal_queue_save: Dictionary = queue_owner.to_save_data().duplicate(true) \
		if queue_owner != null else {}
	var terminal_world_restore: Dictionary = world.apply_save_data(terminal_world_save)
	var terminal_mana_restore: Dictionary = mana_owner.apply_save_data(terminal_mana_save) \
		if mana_owner != null else {}
	var terminal_queue_restore: Dictionary = queue_owner.apply_save_data(terminal_queue_save) \
		if queue_owner != null else {}
	coordinator.resume_session()
	var cold_terminal_request_replay := adapter.submit(
		adapter_capability,
		retry_adapter_request
	)
	coordinator.pause_session()
	var cold_terminal_escrow := real_card_state.facility_card_escrow_snapshot(
		str(escrow_ref.get("escrow_id", ""))
	) if real_card_state != null else {}
	_expect(bool(terminal_world_restore.get("applied", false)) \
			and bool(terminal_mana_restore.get("applied", false)) \
			and bool(terminal_queue_restore.get("applied", false)) \
			and str((cold_terminal_escrow.get("receipt", {}) as Dictionary).get(
				"state_id",
				""
			)) == "consumed_finalized" \
			and _public_queue_count(queue_owner.public_snapshot()) == 0, "world, mana, and Queue terminal Save data reapply without adding a schema or reviving the settled commitment")
	_expect(_has_exact_fields(cold_terminal_request_replay, [
			"accepted",
			"queued",
			"committed",
			"terminal",
			"idempotent_replay",
			"reason_code",
		]) \
			and bool(cold_terminal_request_replay.get("committed", false)) \
			and bool(cold_terminal_request_replay.get("terminal", false)) \
			and bool(cold_terminal_request_replay.get("idempotent_replay", false)) \
			and not bool(cold_terminal_request_replay.get("requires_recovery", false)), "cold-restored consumed-finalized submission follows the terminal replay path instead of requires_recovery|result=%s" % JSON.stringify(cold_terminal_request_replay))

	coordinator.advance_card_resolution_frame(0.0)
	var economic_after_replay := coordinator.economic_source_snapshot(actor_id)
	var inventory_after_replay := coordinator.v06_card_player_snapshot(actor_id)
	var journal_after_replay: Dictionary = inventory_owner.call("transaction_journal_snapshot") if inventory_owner != null else {}
	var infrastructure_after_replay := infrastructure_owner.region_snapshot(region_id) if infrastructure_owner != null else {}
	var world_player_after_replay: Dictionary = (world.players[0] as Dictionary).duplicate(true) if world.players[0] is Dictionary else {}
	_expect(JSON.stringify(economic_after_replay) == JSON.stringify(economic_after_play) \
			and JSON.stringify(inventory_after_replay) == JSON.stringify(inventory_after_play) \
			and JSON.stringify(infrastructure_after_replay) == JSON.stringify(infrastructure_after_play) \
			and JSON.stringify(world_player_after_replay) == JSON.stringify(world_player_after_play) \
			and JSON.stringify(journal_after_replay) == JSON.stringify(journal_after), "an extra empty resolution step cannot duplicate facility HP, ownership, revisions, assets, inventory, or journals")

	var mana_save := coordinator.player_mana_to_save_data()
	var pools_by_player: Dictionary = (mana_save.get("pools_by_player", {}) as Dictionary).duplicate(true) if mana_save.get("pools_by_player", {}) is Dictionary else {}
	var human_pool: Dictionary = (pools_by_player.get("0", {}) as Dictionary).duplicate(true) if pools_by_player.get("0", {}) is Dictionary else {}
	human_pool["technology"] = maxi(int(human_pool.get("technology", 0)), 10 * PlayerManaRuntimeController.MILLIASSET_SCALE)
	pools_by_player["0"] = human_pool
	mana_save["pools_by_player"] = pools_by_player
	var mana_loaded := coordinator.apply_player_mana_save_data(mana_save)
	_expect(bool(mana_loaded.get("applied", false)), "upgrade/repair fixture funds the authoritative technology-asset owner")

	var rank_two_card_id := "facility.market.technology.rank_2"
	var before_upgrade_grant := coordinator.v06_card_player_snapshot(actor_id)
	var upgrade_grant_variant: Variant = inventory_owner.call("grant_card", actor_id, rank_two_card_id, int(before_upgrade_grant.get("revision", -1)), "qa-facility-upgrade-grant", "qa_upgrade") if inventory_owner != null else {}
	var upgrade_grant: Dictionary = (upgrade_grant_variant as Dictionary).duplicate(true) if upgrade_grant_variant is Dictionary else {}
	var after_upgrade_grant := coordinator.v06_card_player_snapshot(actor_id)
	var upgrade_slot := _inventory_slot_for_card(after_upgrade_grant, rank_two_card_id)
	var upgrade_inventory: Dictionary = after_upgrade_grant.get("inventory", {}) \
		if after_upgrade_grant.get("inventory", {}) is Dictionary else {}
	var upgrade_slots: Array = upgrade_inventory.get("slots", []) \
		if upgrade_inventory.get("slots", []) is Array else []
	var upgrade_card: Dictionary = upgrade_slots[upgrade_slot] \
		if upgrade_slot >= 0 and upgrade_slot < upgrade_slots.size() \
			and upgrade_slots[upgrade_slot] is Dictionary else {}
	var fault_inventory_count := _inventory_card_count(after_upgrade_grant)
	coordinator.resume_session()
	var escrow_commit_fault := SubmissionCardReleaseFaultProxy.new()
	escrow_commit_fault.delegate = real_card_state
	escrow_commit_fault.fail_commit_receipt = true
	root.add_child(escrow_commit_fault)
	adapter.set("_card_state", escrow_commit_fault)
	var escrow_commit_request := _submission_fault_request(
		adapter_request,
		upgrade_card,
		upgrade_slot,
		"escrow-commit"
	)
	var escrow_commit_fault_result := adapter.submit(
		adapter_capability,
		escrow_commit_request
	)
	adapter.set("_card_state", real_card_state)
	var escrow_commit_settlement: Dictionary = escrow_commit_fault_result.get(
		"submission_settlement",
		{}
	) if escrow_commit_fault_result.get("submission_settlement", {}) is Dictionary else {}
	var escrow_commit_compensation: Dictionary = escrow_commit_settlement.get(
		"escrow_compensation",
		{}
	) if escrow_commit_settlement.get("escrow_compensation", {}) is Dictionary else {}
	var escrow_commit_terminal := real_card_state.facility_card_escrow_snapshot(
		escrow_commit_fault.last_escrow_id
	) if real_card_state != null else {}
	_expect(_submission_failure_contract_valid(escrow_commit_fault_result) \
			and str(escrow_commit_fault_result.get("reason_code", "")) \
				== "qa_card_escrow_commit_receipt_failed" \
			and str(escrow_commit_fault_result.get("failure_reason_code", "")) \
				== "qa_card_escrow_commit_receipt_failed" \
			and str(escrow_commit_settlement.get("original_failure_reason_code", "")) \
				== "qa_card_escrow_commit_receipt_failed" \
			and bool(escrow_commit_fault_result.get("commitment_settled", false)), "post-mutation false escrow commit receipt probes and compensates the real Card Owner with the exact dependency reason|result=%s" % JSON.stringify(escrow_commit_fault_result))
	_expect(escrow_commit_fault.commit_call_count == 1 \
			and escrow_commit_fault.release_call_count == 1 \
			and not bool(escrow_commit_compensation.get("commit_expected", true)) \
			and bool(escrow_commit_compensation.get("attempted", false)) \
			and bool(escrow_commit_compensation.get("receipt_valid", false)) \
			and bool(escrow_commit_compensation.get("state_verified", false)) \
			and str((escrow_commit_terminal.get("receipt", {}) as Dictionary).get(
				"state_id",
				""
			)) == "released" \
			and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) \
				== fault_inventory_count \
			and _public_queue_count(queue_owner.public_snapshot()) == 0, "escrow post-mutation compensation restores the exact card without creating Queue or mana state")
	escrow_commit_fault.queue_free()

	var mana_commit_fault := SubmissionManaFaultProxy.new()
	mana_commit_fault.delegate = mana_owner
	mana_commit_fault.fail_commit_receipt = true
	root.add_child(mana_commit_fault)
	adapter.set("_mana", mana_commit_fault)
	var mana_commit_fault_result := adapter.submit(
		adapter_capability,
		_submission_fault_request(adapter_request, upgrade_card, upgrade_slot, "mana-commit")
	)
	adapter.set("_mana", mana_owner)
	var mana_commit_settlement: Dictionary = mana_commit_fault_result.get(
		"submission_settlement",
		{}
	) if mana_commit_fault_result.get("submission_settlement", {}) is Dictionary else {}
	var mana_commit_reservation: Dictionary = mana_commit_settlement.get(
		"reservation_compensation",
		{}
	) if mana_commit_settlement.get("reservation_compensation", {}) is Dictionary else {}
	var mana_commit_escrow: Dictionary = mana_commit_settlement.get(
		"escrow_compensation",
		{}
	) if mana_commit_settlement.get("escrow_compensation", {}) is Dictionary else {}
	var mana_commit_terminal := mana_owner.reservation_settlement_snapshot(
		mana_commit_fault.last_transaction_id
	) if mana_owner != null else {}
	_expect(_submission_failure_contract_valid(mana_commit_fault_result) \
			and str(mana_commit_fault_result.get("reason_code", "")) \
				== "qa_mana_commit_receipt_failed" \
			and bool(mana_commit_fault_result.get("commitment_settled", false)) \
			and not bool(mana_commit_fault_result.get("requires_recovery", true)), "mana commit post-mutation failure returns one closed, completely compensated submission settlement|result=%s" % JSON.stringify(mana_commit_fault_result))
	_expect(mana_commit_fault.commit_call_count == 1 \
			and mana_commit_fault.release_call_count == 1 \
			and not bool(mana_commit_reservation.get("commit_expected", true)) \
			and bool(mana_commit_reservation.get("attempted", false)) \
			and bool(mana_commit_reservation.get("receipt_valid", false)) \
			and bool(mana_commit_reservation.get("state_verified", false)) \
			and str(mana_commit_reservation.get("outcome_id", "")) == "released" \
			and bool(mana_commit_escrow.get("receipt_valid", false)) \
			and bool(mana_commit_escrow.get("state_verified", false)) \
			and str(mana_commit_terminal.get("outcome_id", "")) == "released", "mana commit failure validates both reservation and escrow compensation receipts plus terminal Owner states|settlement=%s terminal=%s" % [JSON.stringify(mana_commit_settlement), JSON.stringify(mana_commit_terminal)])
	_expect(_inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) == fault_inventory_count \
			and _public_queue_count(queue_owner.public_snapshot()) == 0, "fully compensated mana commit failure restores the exact card and leaves no Queue entry")
	mana_commit_fault.queue_free()

	var queue_commit_fault := SubmissionQueueCommitFaultProxy.new()
	queue_commit_fault.delegate = queue_owner
	queue_commit_fault.commit_before_failure = true
	root.add_child(queue_commit_fault)
	var queue_commit_request := _submission_fault_request(
		adapter_request,
		upgrade_card,
		upgrade_slot,
		"queue-post-mutation"
	)
	adapter.set("_queue", queue_commit_fault)
	var queue_commit_fault_result := adapter.submit(
		adapter_capability,
		queue_commit_request
	)
	adapter.set("_queue", queue_owner)
	var queue_commit_settlement: Dictionary = queue_commit_fault_result.get(
		"submission_settlement",
		{}
	) if queue_commit_fault_result.get("submission_settlement", {}) is Dictionary else {}
	var queue_commit_compensation: Dictionary = queue_commit_settlement.get(
		"queue_compensation",
		{}
	) if queue_commit_settlement.get("queue_compensation", {}) is Dictionary else {}
	_expect(_submission_failure_contract_valid(queue_commit_fault_result) \
			and str(queue_commit_fault_result.get("reason_code", "")) \
				== "qa_queue_commit_failed" \
			and str(queue_commit_fault_result.get("failure_reason_code", "")) \
				== "qa_queue_commit_failed" \
			and str(queue_commit_settlement.get("original_failure_reason_code", "")) \
				== "qa_queue_commit_failed" \
			and bool(queue_commit_fault_result.get("commitment_settled", false)), "post-mutation false Queue commit receipt preserves the exact dependency reason and closes all three Owner settlements|result=%s" % JSON.stringify(queue_commit_fault_result))
	_expect(queue_commit_fault.commit_call_count == 1 \
			and queue_commit_fault.rollback_call_count >= 1 \
			and queue_commit_fault.last_resolution_id > 0 \
			and bool(queue_commit_compensation.get("attempted", false)) \
			and bool(queue_commit_compensation.get("receipt_valid", false)) \
			and bool(queue_commit_compensation.get("state_verified", false)) \
			and str(queue_commit_compensation.get("outcome_id", "")) == "rolled_back" \
			and queue_owner.entry_by_id(queue_commit_fault.last_resolution_id).is_empty() \
			and _public_queue_count(queue_owner.public_snapshot()) == 0 \
			and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) \
				== fault_inventory_count, "Queue Owner rolls back its own exact resolution before card and reservation compensation")

	var mana_release_fault := SubmissionManaFaultProxy.new()
	mana_release_fault.delegate = mana_owner
	mana_release_fault.fail_release_receipt = true
	root.add_child(mana_release_fault)
	adapter.set("_queue", queue_commit_fault)
	adapter.set("_mana", mana_release_fault)
	var reservation_release_request := _submission_fault_request(
		adapter_request,
		upgrade_card,
		upgrade_slot,
		"reservation-release"
	)
	var queue_commits_before_reservation_fault := queue_commit_fault.commit_call_count
	var reservation_release_fault_result := adapter.submit(
		adapter_capability,
		reservation_release_request
	)
	var reservation_release_settlement: Dictionary = reservation_release_fault_result.get(
		"submission_settlement",
		{}
	) if reservation_release_fault_result.get("submission_settlement", {}) is Dictionary else {}
	var reservation_release_compensation: Dictionary = reservation_release_settlement.get(
		"reservation_compensation",
		{}
	) if reservation_release_settlement.get("reservation_compensation", {}) is Dictionary else {}
	var reservation_release_escrow: Dictionary = reservation_release_settlement.get(
		"escrow_compensation",
		{}
	) if reservation_release_settlement.get("escrow_compensation", {}) is Dictionary else {}
	var pending_reservation := mana_owner.reservation_settlement_snapshot(
		mana_release_fault.last_transaction_id
	) if mana_owner != null else {}
	_expect(_submission_failure_contract_valid(reservation_release_fault_result) \
			and str(reservation_release_fault_result.get("reason_code", "")) \
				== "facility_queue_submission_compensation_incomplete" \
			and str(reservation_release_fault_result.get("failure_reason_code", "")) \
				== "qa_queue_commit_failed" \
			and not bool(reservation_release_fault_result.get("commitment_settled", true)) \
			and bool(reservation_release_fault_result.get("requires_recovery", false)), "reservation release postcondition failure is an explicit fail-closed unsettled result rather than a clean Queue rejection|result=%s" % JSON.stringify(reservation_release_fault_result))
	_expect(queue_commit_fault.commit_call_count \
				== queue_commits_before_reservation_fault + 1 \
			and mana_release_fault.release_call_count == 1 \
			and bool(reservation_release_compensation.get("receipt_valid", false)) \
			and not bool(reservation_release_compensation.get("state_verified", true)) \
			and not bool(reservation_release_compensation.get("settled", true)) \
			and bool(reservation_release_escrow.get("settled", false)) \
			and str(pending_reservation.get("outcome_id", "")) == "pending" \
			and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) \
				== fault_inventory_count, "fake reservation release receipt is rejected by the terminal Owner-state check while escrow compensation remains exact|settlement=%s pending=%s" % [JSON.stringify(reservation_release_settlement), JSON.stringify(pending_reservation)])
	mana_release_fault.fail_release_receipt = false
	var reservation_recovery_result := adapter.submit(
		adapter_capability,
		reservation_release_request
	)
	adapter.set("_queue", queue_owner)
	adapter.set("_mana", mana_owner)
	var reservation_recovery_terminal := mana_owner.reservation_settlement_snapshot(
		mana_release_fault.last_transaction_id
	) if mana_owner != null else {}
	_expect(_submission_failure_contract_valid(reservation_recovery_result) \
			and str(reservation_recovery_result.get("reason_code", "")) \
				== "qa_queue_commit_failed" \
			and str(reservation_recovery_result.get("failure_reason_code", "")) \
				== "qa_queue_commit_failed" \
			and bool(reservation_recovery_result.get("commitment_settled", false)) \
			and not bool(reservation_recovery_result.get("requires_recovery", true)) \
			and str(reservation_recovery_terminal.get("outcome_id", "")) == "released" \
			and queue_commit_fault.commit_call_count \
				== queue_commits_before_reservation_fault + 1 \
			and _public_queue_count(queue_owner.public_snapshot()) == 0, "same request production replay completes pending reservation compensation without recommitting Queue or using test-only Owner cleanup|result=%s" % JSON.stringify(reservation_recovery_result))
	mana_release_fault.queue_free()

	var card_release_fault := SubmissionCardReleaseFaultProxy.new()
	card_release_fault.delegate = real_card_state
	card_release_fault.fail_release_receipt = true
	root.add_child(card_release_fault)
	adapter.set("_queue", queue_commit_fault)
	adapter.set("_card_state", card_release_fault)
	var escrow_release_request := _submission_fault_request(
		adapter_request,
		upgrade_card,
		upgrade_slot,
		"escrow-release"
	)
	var queue_commits_before_escrow_fault := queue_commit_fault.commit_call_count
	var escrow_release_fault_result := adapter.submit(
		adapter_capability,
		escrow_release_request
	)
	var escrow_release_settlement: Dictionary = escrow_release_fault_result.get(
		"submission_settlement",
		{}
	) if escrow_release_fault_result.get("submission_settlement", {}) is Dictionary else {}
	var escrow_release_reservation: Dictionary = escrow_release_settlement.get(
		"reservation_compensation",
		{}
	) if escrow_release_settlement.get("reservation_compensation", {}) is Dictionary else {}
	var escrow_release_compensation: Dictionary = escrow_release_settlement.get(
		"escrow_compensation",
		{}
	) if escrow_release_settlement.get("escrow_compensation", {}) is Dictionary else {}
	var pending_escrow := real_card_state.facility_card_escrow_snapshot(
		card_release_fault.last_escrow_id
	) if real_card_state != null else {}
	_expect(_submission_failure_contract_valid(escrow_release_fault_result) \
			and str(escrow_release_fault_result.get("reason_code", "")) \
				== "facility_queue_submission_compensation_incomplete" \
			and not bool(escrow_release_fault_result.get("commitment_settled", true)) \
			and bool(escrow_release_fault_result.get("requires_recovery", false)), "escrow release postcondition failure is an explicit fail-closed unsettled result rather than a clean Queue rejection|result=%s" % JSON.stringify(escrow_release_fault_result))
	_expect(queue_commit_fault.commit_call_count \
				== queue_commits_before_escrow_fault + 1 \
			and card_release_fault.release_call_count == 1 \
			and bool(escrow_release_compensation.get("receipt_valid", false)) \
			and not bool(escrow_release_compensation.get("state_verified", true)) \
			and not bool(escrow_release_compensation.get("settled", true)) \
			and bool(escrow_release_reservation.get("settled", false)) \
			and bool(pending_escrow.get("found", false)) \
			and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) \
				== fault_inventory_count - 1, "fake escrow release receipt is rejected by the terminal Owner-state check while reservation compensation remains exact|settlement=%s pending=%s" % [JSON.stringify(escrow_release_settlement), JSON.stringify(pending_escrow)])
	card_release_fault.fail_release_receipt = false
	var escrow_recovery_result := adapter.submit(
		adapter_capability,
		escrow_release_request
	)
	adapter.set("_queue", queue_owner)
	adapter.set("_card_state", real_card_state)
	var escrow_recovery_terminal := real_card_state.facility_card_escrow_snapshot(
		card_release_fault.last_escrow_id
	) if real_card_state != null else {}
	_expect(_submission_failure_contract_valid(escrow_recovery_result) \
			and str(escrow_recovery_result.get("reason_code", "")) \
				== "qa_queue_commit_failed" \
			and str(escrow_recovery_result.get("failure_reason_code", "")) \
				== "qa_queue_commit_failed" \
			and bool(escrow_recovery_result.get("commitment_settled", false)) \
			and not bool(escrow_recovery_result.get("requires_recovery", true)) \
			and bool(escrow_recovery_terminal.get("terminal", false)) \
			and str((escrow_recovery_terminal.get("receipt", {}) as Dictionary).get(
				"state_id",
				""
			)) == "released" \
			and queue_commit_fault.commit_call_count \
				== queue_commits_before_escrow_fault + 1 \
			and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) \
				== fault_inventory_count \
			and _public_queue_count(queue_owner.public_snapshot()) == 0, "same request production replay completes pending escrow compensation without recommitting Queue or using test-only Owner cleanup|result=%s" % JSON.stringify(escrow_recovery_result))
	card_release_fault.queue_free()
	queue_commit_fault.queue_free()
	coordinator.pause_session()
	coordinator.request_table_presentation_refresh(&"full", &"qa_facility_card_dock_upgrade")
	await process_frame
	var upgrade_table := screen.current_ui_data.duplicate(true)
	var upgrade_dock: Dictionary = upgrade_table.get("player_card_dock", {}) \
		if upgrade_table.get("player_card_dock", {}) is Dictionary else {}
	var upgrade_hand := _first_dock_card(
		upgrade_dock.get("normal_cards", []) if upgrade_dock.get("normal_cards", []) is Array else [],
		rank_two_card_id
	)
	var upgrade_action := _first_enabled_play_action(upgrade_hand)
	_expect(bool(upgrade_grant.get("committed", false)) and upgrade_slot >= 0 \
			and _dock_slot_index(upgrade_hand) == upgrade_slot \
			and str(upgrade_hand.get("play_state", "")) == "available" \
			and not upgrade_action.is_empty(), "owned Rank-II upgrade is actionable on the real GameScreen Dock projection")
	var application_recovery_queue_fault := SubmissionQueueCommitFaultProxy.new()
	application_recovery_queue_fault.delegate = queue_owner
	application_recovery_queue_fault.commit_before_failure = true
	var application_recovery_card_fault := SubmissionCardReleaseFaultProxy.new()
	application_recovery_card_fault.delegate = real_card_state
	application_recovery_card_fault.fail_release_receipt = true
	root.add_child(application_recovery_queue_fault)
	root.add_child(application_recovery_card_fault)
	adapter.set("_queue", application_recovery_queue_fault)
	adapter.set("_card_state", application_recovery_card_fault)
	var application_intent_index := intents.size()
	var application_receipt_index := action_receipts.size()
	var application_queue_commits_before := application_recovery_queue_fault.commit_call_count
	coordinator.resume_session()
	var application_fault_submitted := _submit_game_action(screen, upgrade_action)
	coordinator.pause_session()
	var application_fault_intent: Dictionary = intents[application_intent_index] \
		if application_intent_index < intents.size() else {}
	var application_fault_receipt: Dictionary = action_receipts[application_receipt_index] \
		if application_receipt_index < action_receipts.size() else {}
	var application_pending_escrow := real_card_state.facility_card_escrow_snapshot(
		application_recovery_card_fault.last_escrow_id
	) if real_card_state != null else {}
	var application_submission_pending := coordinator.card_play_submission_controller().debug_snapshot()
	_expect(application_fault_submitted \
			and not application_fault_intent.is_empty() \
			and not bool(application_fault_receipt.get("accepted", true)) \
			and str(application_fault_receipt.get("reason_id", "")) \
				== "facility-queue-submission-compensation-incomplete" \
			and int(application_submission_pending.get(
				"facility_recovery_request_count",
				0
			)) == 1, "real GameScreen submission records one recoverable production intent instead of terminally caching the failed receipt")
	_expect(bool(application_pending_escrow.get("found", false)) \
			and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) \
				== fault_inventory_count - 1, "the production recovery fixture proves the exact card has left its hand slot before identical-intent redelivery")
	application_recovery_card_fault.fail_release_receipt = false
	coordinator.resume_session()
	var application_recovery_receipt := action_flow.submit_intent(
		application_fault_intent
	)
	coordinator.pause_session()
	adapter.set("_queue", queue_owner)
	adapter.set("_card_state", real_card_state)
	var application_submission_recovered := coordinator.card_play_submission_controller().debug_snapshot()
	var application_flow_recovered := action_flow.debug_snapshot()
	var application_terminal_escrow := real_card_state.facility_card_escrow_snapshot(
		application_recovery_card_fault.last_escrow_id
	) if real_card_state != null else {}
	_expect(not bool(application_recovery_receipt.get("accepted", true)) \
			and str(application_recovery_receipt.get("reason_id", "")) \
				== "qa-queue-commit-failed" \
			and not bool(application_recovery_receipt.get("idempotent_replay", true)) \
			and application_recovery_queue_fault.commit_call_count \
				== application_queue_commits_before + 1 \
			and int(application_submission_recovered.get(
				"facility_recovery_request_count",
				-1
			)) == 0 \
			and int(application_flow_recovered.get("recovery_delivery_count", 0)) >= 1, "identical production submit_intent delivery reaches compensation recovery without recommitting Queue")
	_expect(bool(application_terminal_escrow.get("terminal", false)) \
			and str((application_terminal_escrow.get("receipt", {}) as Dictionary).get(
				"state_id",
				""
			)) == "released" \
			and _inventory_card_count(coordinator.v06_card_player_snapshot(actor_id)) \
				== fault_inventory_count \
			and _public_queue_count(queue_owner.public_snapshot()) == 0, "production Application Flow recovery restores the exact card and leaves no Queue commitment")
	application_recovery_queue_fault.queue_free()
	application_recovery_card_fault.queue_free()
	coordinator.request_table_presentation_refresh(&"full", &"qa_facility_card_dock_upgrade_recovered")
	await process_frame
	upgrade_table = screen.current_ui_data.duplicate(true)
	upgrade_dock = upgrade_table.get("player_card_dock", {}) \
		if upgrade_table.get("player_card_dock", {}) is Dictionary else {}
	upgrade_hand = _first_dock_card(
		upgrade_dock.get("normal_cards", []) if upgrade_dock.get("normal_cards", []) is Array else [],
		rank_two_card_id
	)
	upgrade_action = _first_enabled_play_action(upgrade_hand)
	var upgrade_submission_before := coordinator.card_play_submission_controller().debug_snapshot()
	coordinator.resume_session()
	_expect(_submit_game_action(screen, upgrade_action), "Rank-II upgrade submits through the same public GameAction offer boundary")
	var upgrade_submission_after := coordinator.card_play_submission_controller().debug_snapshot()
	_expect(_public_queue_count(queue_owner.public_snapshot()) == 1, "Rank-II upgrade remains queued until the next card-resolution command")
	coordinator.advance_card_resolution_frame(0.0)
	coordinator.pause_session()
	var upgraded_facility := _facility_for_slot(infrastructure_owner, region_id, "market", "technology")
	var occupied_after_upgrade := _facility_for_slot(infrastructure_owner, occupied_region_id, "market", "technology")
	_expect(int(upgrade_submission_after.get("accepted_count", 0)) == int(upgrade_submission_before.get("accepted_count", 0)) + 1 and int(upgraded_facility.get("rank", 0)) == 2, "GameScreen→submission→formal play upgrades the explicitly selected region to Rank II")
	_expect(int(occupied_after_upgrade.get("rank", 0)) == 1 and str(occupied_after_upgrade.get("owner_kind", "")) == "neutral", "Rank-II play does not redirect to or mutate the other occupied region")

	var repair_damage := infrastructure_owner.apply_unit_damage({
		"transaction_id": "qa-facility-repair-damage",
		"source_kind": "monster",
		"source_entity_id": "monster.qa",
		"region_id": region_id,
		"amount": 20,
		"occurred_at": world.game_time,
	})
	var damage_before_repair := int(infrastructure_owner.region_snapshot(region_id).get("damage_taken", 0))
	var before_repair_grant := coordinator.v06_card_player_snapshot(actor_id)
	var repair_grant_variant: Variant = inventory_owner.call("grant_card", actor_id, rank_two_card_id, int(before_repair_grant.get("revision", -1)), "qa-facility-repair-grant", "qa_repair") if inventory_owner != null else {}
	var repair_grant: Dictionary = (repair_grant_variant as Dictionary).duplicate(true) if repair_grant_variant is Dictionary else {}
	var after_repair_grant := coordinator.v06_card_player_snapshot(actor_id)
	var repair_slot := _inventory_slot_for_card(after_repair_grant, rank_two_card_id)
	coordinator.request_table_presentation_refresh(&"full", &"qa_facility_card_dock_repair")
	await process_frame
	var repair_table := screen.current_ui_data.duplicate(true)
	var repair_dock: Dictionary = repair_table.get("player_card_dock", {}) \
		if repair_table.get("player_card_dock", {}) is Dictionary else {}
	var repair_hand := _first_dock_card(
		repair_dock.get("normal_cards", []) if repair_dock.get("normal_cards", []) is Array else [],
		rank_two_card_id
	)
	var repair_action := _first_enabled_play_action(repair_hand)
	_expect(bool(repair_damage.get("committed", false)) and bool(repair_grant.get("committed", false)) \
			and repair_slot >= 0 and _dock_slot_index(repair_hand) == repair_slot \
			and str(repair_hand.get("play_state", "")) == "available" \
			and not repair_action.is_empty(), "damaged owned Rank-II facility exposes an actionable repair on the real Dock projection")
	var repair_submission_before := coordinator.card_play_submission_controller().debug_snapshot()
	coordinator.resume_session()
	_expect(_submit_game_action(screen, repair_action), "Rank-II repair submits through the same public GameAction offer boundary")
	var repair_submission_after := coordinator.card_play_submission_controller().debug_snapshot()
	_expect(_public_queue_count(queue_owner.public_snapshot()) == 1, "Rank-II repair remains queued until the next card-resolution command")
	coordinator.advance_card_resolution_frame(0.0)
	coordinator.pause_session()
	var repaired_facility := _facility_for_slot(infrastructure_owner, region_id, "market", "technology")
	var damage_after_repair := int(infrastructure_owner.region_snapshot(region_id).get("damage_taken", -1))
	_expect(int(repair_submission_after.get("accepted_count", 0)) == int(repair_submission_before.get("accepted_count", 0)) + 1 \
			and int(repaired_facility.get("rank", 0)) == 2 and damage_before_repair > 0 and damage_after_repair < damage_before_repair, "GameScreen→submission→formal play repairs the explicitly selected Rank-II region without changing rank")
	_expect(int(_facility_for_slot(infrastructure_owner, occupied_region_id, "market", "technology").get("rank", 0)) == 1, "repair does not mutate the other occupied region")

	var public_receipt_text := JSON.stringify(receipts[1].public_summary()) if receipts.size() > 1 else ""
	var private_quote_id := receipts[0].quote_id if not receipts.is_empty() else ""
	_expect(not public_receipt_text.is_empty() and not public_receipt_text.contains(TARGET_CARD_ID) and not public_receipt_text.contains(private_quote_id) and not public_receipt_text.contains("locked_quote"), "public receipt omits card, quote credential and private reason")

	var forged_rollback_damage := infrastructure_owner.apply_unit_damage({
		"transaction_id": "qa-facility-forged-rollback-damage",
		"source_kind": "monster",
		"source_entity_id": "monster.qa",
		"region_id": region_id,
		"amount": 1,
		"occurred_at": world.game_time,
	}) if infrastructure_owner != null else {}
	var before_forged_rollback_grant := coordinator.v06_card_player_snapshot(actor_id)
	var forged_rollback_grant_variant: Variant = inventory_owner.call(
		"grant_card",
		actor_id,
		rank_two_card_id,
		int(before_forged_rollback_grant.get("revision", -1)),
		"qa-facility-forged-rollback-grant",
		"qa_forged_rollback"
	) if inventory_owner != null else {}
	var forged_rollback_grant: Dictionary = forged_rollback_grant_variant \
		if forged_rollback_grant_variant is Dictionary else {}
	var after_forged_rollback_grant := coordinator.v06_card_player_snapshot(actor_id)
	var forged_rollback_slot := _inventory_slot_for_card(
		after_forged_rollback_grant,
		rank_two_card_id
	)
	var forged_rollback_inventory: Dictionary = after_forged_rollback_grant.get(
		"inventory",
		{}
	) if after_forged_rollback_grant.get("inventory", {}) is Dictionary else {}
	var forged_rollback_slots: Array = forged_rollback_inventory.get("slots", []) \
		if forged_rollback_inventory.get("slots", []) is Array else []
	var forged_rollback_card: Dictionary = forged_rollback_slots[forged_rollback_slot] \
		if forged_rollback_slot >= 0 \
		and forged_rollback_slot < forged_rollback_slots.size() \
		and forged_rollback_slots[forged_rollback_slot] is Dictionary else {}
	var forged_queue_rollback_fault := SubmissionQueueCommitFaultProxy.new()
	forged_queue_rollback_fault.delegate = queue_owner
	forged_queue_rollback_fault.commit_before_failure = true
	forged_queue_rollback_fault.forge_successful_rollback_without_delegate = true
	var forged_queue_mana_probe := SubmissionManaFaultProxy.new()
	forged_queue_mana_probe.delegate = mana_owner
	var forged_queue_card_probe := SubmissionCardReleaseFaultProxy.new()
	forged_queue_card_probe.delegate = real_card_state
	root.add_child(forged_queue_rollback_fault)
	root.add_child(forged_queue_mana_probe)
	root.add_child(forged_queue_card_probe)
	adapter.set("_queue", forged_queue_rollback_fault)
	adapter.set("_mana", forged_queue_mana_probe)
	adapter.set("_card_state", forged_queue_card_probe)
	var forged_queue_rollback_request := _submission_fault_request(
		adapter_request,
		forged_rollback_card,
		forged_rollback_slot,
		"queue-rollback-receipt-forged"
	)
	coordinator.resume_session()
	var forged_queue_rollback_result := adapter.submit(
		adapter_capability,
		forged_queue_rollback_request
	)
	coordinator.pause_session()
	adapter.set("_queue", queue_owner)
	adapter.set("_mana", mana_owner)
	adapter.set("_card_state", real_card_state)
	var forged_queue_settlement: Dictionary = forged_queue_rollback_result.get(
		"submission_settlement",
		{}
	) if forged_queue_rollback_result.get("submission_settlement", {}) is Dictionary else {}
	var forged_queue_compensation: Dictionary = forged_queue_settlement.get(
		"queue_compensation",
		{}
	) if forged_queue_settlement.get("queue_compensation", {}) is Dictionary else {}
	var forged_reservation_compensation: Dictionary = forged_queue_settlement.get(
		"reservation_compensation",
		{}
	) if forged_queue_settlement.get("reservation_compensation", {}) is Dictionary else {}
	var forged_escrow_compensation: Dictionary = forged_queue_settlement.get(
		"escrow_compensation",
		{}
	) if forged_queue_settlement.get("escrow_compensation", {}) is Dictionary else {}
	var forged_queue_reservation := mana_owner.reservation_settlement_snapshot(
		forged_queue_mana_probe.last_transaction_id
	) if mana_owner != null else {}
	var forged_queue_escrow := real_card_state.facility_card_escrow_snapshot(
		forged_queue_card_probe.last_escrow_id
	) if real_card_state != null else {}
	_expect(bool(forged_rollback_damage.get("committed", false)) \
			and bool(forged_rollback_grant.get("committed", false)) \
			and not forged_rollback_card.is_empty(), "forged Queue rollback fault fixture owns one legal damaged-facility repair card")
	_expect(_submission_failure_contract_valid(forged_queue_rollback_result) \
			and str(forged_queue_rollback_result.get("reason_code", "")) \
				== "facility_queue_submission_compensation_incomplete" \
			and str(forged_queue_rollback_result.get("failure_reason_code", "")) \
				== "qa_queue_commit_failed" \
			and bool(forged_queue_rollback_result.get("requires_recovery", false)) \
			and bool(forged_queue_compensation.get("receipt_valid", false)) \
			and not bool(forged_queue_compensation.get("state_verified", true)) \
			and not bool(forged_queue_compensation.get("settled", true)), "a forged successful Queue rollback receipt fails closed when the capability-bound status still finds its commitment|result=%s" % JSON.stringify(forged_queue_rollback_result))
	_expect(forged_queue_rollback_fault.rollback_call_count == 1 \
			and forged_queue_rollback_fault.status_call_count >= 1 \
			and forged_queue_rollback_fault.last_resolution_id > 0 \
			and not queue_owner.entry_by_id(
				forged_queue_rollback_fault.last_resolution_id
			).is_empty() \
			and str(forged_queue_reservation.get("outcome_id", "")) == "pending" \
			and bool(forged_queue_escrow.get("found", false)) \
			and not bool(forged_queue_escrow.get("terminal", true)) \
			and forged_queue_mana_probe.release_call_count == 0 \
			and forged_queue_card_probe.release_call_count == 0 \
			and str(forged_reservation_compensation.get("outcome_id", "")) \
				== "blocked_by_queue" \
			and str(forged_escrow_compensation.get("outcome_id", "")) \
				== "blocked_by_queue", "unverified Queue rollback leaves the Queue, reservation, and escrow intact and invokes neither dependent release")
	forged_queue_rollback_fault.queue_free()
	forged_queue_mana_probe.queue_free()
	forged_queue_card_probe.queue_free()

	_stop_audio(app_root)
	app_root.queue_free()
	await process_frame
	_finish()


func _first_purchasable_target_district(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	infrastructure: RegionInfrastructureRuntimeController
) -> int:
	if coordinator == null or world == null or infrastructure == null:
		return -1
	for district_index in range(world.districts.size()):
		var district: Dictionary = world.districts[district_index] if world.districts[district_index] is Dictionary else {}
		var region_id := str(district.get("region_id", ""))
		if coordinator.region_supply_listing(region_id, TARGET_CARD_ID).is_empty() \
				or not _facility_for_slot(infrastructure, region_id, "market", "technology").is_empty():
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


func _submit_game_action(
	screen: SpaceSyndicateGameScreen,
	action: Dictionary,
	target_overrides: Dictionary = {}
) -> bool:
	if screen == null:
		return false
	var offer: Dictionary = action.get("game_action_offer", {}) \
		if action.get("game_action_offer", {}) is Dictionary else {}
	var parameters: Dictionary = action.get("game_action_parameters", {}) \
		if action.get("game_action_parameters", {}) is Dictionary else {}
	return not offer.is_empty() \
		and screen.submit_game_action_offer(offer, "human_click", parameters, target_overrides)


func _public_queue_count(snapshot: Dictionary) -> int:
	return int(snapshot.get("current_count", 0)) \
		+ (1 if bool(snapshot.get("active_present", false)) else 0) \
		+ int(snapshot.get("next_count", 0))


func _adapter_request_from_entry(entry: Dictionary) -> Dictionary:
	var binding: Dictionary = entry.get("v06_facility_action", {}) \
		if entry.get("v06_facility_action", {}) is Dictionary else {}
	var target: Dictionary = binding.get("prebound_target", {}) \
		if binding.get("prebound_target", {}) is Dictionary else {}
	return {
		"schema_version": 1,
		"request_id": str(binding.get("request_id", "")),
		"intent_fingerprint": str(binding.get("intent_fingerprint", "")),
		"source_revision": int(binding.get("source_revision", -1)),
		"actor_kind_id": str(binding.get("actor_kind_id", "")),
		"actor_id": str(binding.get("actor_id", "")),
		"actor_player_index": int(binding.get("actor_player_index", -1)),
		"session_id": str(binding.get("session_id", "")),
		"session_revision": int(binding.get("session_revision", -1)),
		"hand_slot_id": str(binding.get("hand_slot_id", "")),
		"card_instance_id": str(binding.get("card_instance_id", "")),
		"source_slot_index": int(binding.get("source_slot_index", -1)),
		"card_semantic_id": str(binding.get("card_semantic_id", "")),
		"region_id": str(target.get("region_id", "")),
		"stable_target_envelope": (entry.get("stable_target_envelope", {}) as Dictionary).duplicate(true) \
			if entry.get("stable_target_envelope", {}) is Dictionary else {},
	}


func _submission_fault_request(
	base_request: Dictionary,
	card: Dictionary,
	slot_index: int,
	suffix: String
) -> Dictionary:
	var machine: Dictionary = card.get("machine", {}) \
		if card.get("machine", {}) is Dictionary else {}
	var request := base_request.duplicate(true)
	request["request_id"] = "qa-facility-submission-%s" % suffix
	request["intent_fingerprint"] = JSON.stringify([
		request.get("request_id"),
		card.get("runtime_instance_id"),
		slot_index,
		machine.get("card_id"),
	]).sha256_text().to_lower()
	request["source_revision"] = maxi(1, int(base_request.get("source_revision", 1)) + 1)
	request["hand_slot_id"] = "hand.slot.%d" % slot_index
	request["card_instance_id"] = str(card.get("runtime_instance_id", ""))
	request["source_slot_index"] = slot_index
	request["card_semantic_id"] = str(machine.get("card_id", ""))
	return request


func _submission_failure_contract_valid(result: Dictionary) -> bool:
	var result_fields := [
		"accepted",
		"queued",
		"committed",
		"reason_code",
		"commitment_settled",
		"requires_recovery",
		"failure_reason_code",
		"submission_settlement",
	]
	var settlement_fields := [
		"schema_version",
		"settlement_kind_id",
		"settled",
		"original_failure_reason_code",
		"reason_code",
		"queue_compensation",
		"reservation_compensation",
		"escrow_compensation",
	]
	var compensation_fields := [
		"schema_version",
		"compensation_kind_id",
		"owner_id",
		"required",
		"commit_expected",
		"attempted",
		"receipt_valid",
		"state_verified",
		"settled",
		"outcome_id",
		"reason_code",
	]
	if not _has_exact_fields(result, result_fields) \
			or not (result.get("submission_settlement", {}) is Dictionary):
		return false
	var settlement := result.get("submission_settlement", {}) as Dictionary
	if not _has_exact_fields(settlement, settlement_fields) \
			or settlement.get("schema_version") != 2 \
			or str(settlement.get("settlement_kind_id", "")) \
				!= "facility_queue_submission_owner_compensation" \
			or str(settlement.get("original_failure_reason_code", "")) \
				!= str(result.get("failure_reason_code", "")):
		return false
	for field_id in [
		"queue_compensation",
		"reservation_compensation",
		"escrow_compensation",
	]:
		if not (settlement.get(field_id, {}) is Dictionary):
			return false
		var compensation := settlement.get(field_id, {}) as Dictionary
		if not _has_exact_fields(compensation, compensation_fields) \
				or compensation.get("schema_version") != 2:
			return false
	var serialized := JSON.stringify(settlement)
	return not serialized.contains("transaction_id") \
		and not serialized.contains("reservation_id") \
		and not serialized.contains("escrow_id") \
		and not serialized.contains("receipt_fingerprint")


func _has_exact_fields(value: Dictionary, expected_fields: Array) -> bool:
	var actual: Array = value.keys()
	var expected := expected_fields.duplicate()
	actual.sort()
	expected.sort()
	return actual == expected


func _contains_private_queue_value(snapshot: Dictionary) -> bool:
	var text := JSON.stringify(snapshot).to_lower()
	for token in [
		"actor_id",
		"player_index",
		"owner_player",
		"card_instance_id",
		"runtime_instance_id",
		"reservation_id",
		"escrow_id",
		"hand_slot_id",
	]:
		if text.contains(token):
			return true
	return false


func _receipt_debug(receipts: Array[DistrictSupplyActionReceipt]) -> String:
	var rows: Array = []
	for receipt in receipts:
		rows.append(receipt.to_dictionary())
	return JSON.stringify(rows)


func _first_dock_card(cards: Array, card_semantic_id: String) -> Dictionary:
	for card_variant in cards:
		if card_variant is Dictionary \
				and str((card_variant as Dictionary).get("card_semantic_id", "")) \
					== card_semantic_id:
			return (card_variant as Dictionary).duplicate(true)
	return {}


func _dock_slot_index(card: Dictionary) -> int:
	var targets := GAME_ACTION_OFFER.target_ids(
		card.get("game_action_offer", {}) as Dictionary
	)
	var hand_slot_id := str(targets.get("hand_slot_id", ""))
	return int(hand_slot_id.trim_prefix("hand.slot.")) \
		if hand_slot_id.begins_with("hand.slot.") else -1


func _first_enabled_play_action(card: Dictionary) -> Dictionary:
	var direct_offer: Dictionary = card.get("game_action_offer", {}) \
		if card.get("game_action_offer", {}) is Dictionary else {}
	if not direct_offer.is_empty() \
			and str(direct_offer.get("legality_state", "")) == "available":
		return {"game_action_offer": direct_offer.duplicate(true), "game_action_parameters": {}}
	var actions: Array = card.get("actions", []) if card.get("actions", []) is Array else []
	for action_variant in actions:
		if action_variant is Dictionary and str((action_variant as Dictionary).get("id", "")).begins_with("play_") \
				and not bool((action_variant as Dictionary).get("disabled", false)):
			return (action_variant as Dictionary).duplicate(true)
	return {}


func _rack_projection_has_card(projection: Dictionary, card_semantic_id: String) -> bool:
	for card_variant in projection.get("rack_cards", []) as Array:
		if card_variant is Dictionary \
				and str((card_variant as Dictionary).get("card_semantic_id", "")) \
					== card_semantic_id:
			return true
	return false


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
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _facility_for_slot(
	infrastructure: RegionInfrastructureRuntimeController,
	region_id: String,
	facility_type: String,
	industry_id: String
) -> Dictionary:
	if infrastructure == null:
		return {}
	for facility_variant in infrastructure.facilities_snapshot(false):
		if facility_variant is Dictionary \
				and str((facility_variant as Dictionary).get("region_id", "")) == region_id \
				and str((facility_variant as Dictionary).get("facility_type", "")) == facility_type \
				and str((facility_variant as Dictionary).get("industry_id", "")) == industry_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _facility_rule_projection(facility: Dictionary) -> Dictionary:
	if facility.is_empty():
		return {}
	return {
		"facility_type": str(facility.get("facility_type", "")),
		"industry_id": str(facility.get("industry_id", "")),
		"rank": int(facility.get("rank", 0)),
		"generation": int(facility.get("generation", 0)),
		"active": bool(facility.get("active", false)),
	}


func _victory_parity_projection(snapshot: Dictionary) -> Dictionary:
	return {
		"state": str(snapshot.get("state", "")),
		"qualification_active": bool(snapshot.get("qualification_active", false)),
		"audit_active": bool(snapshot.get("audit_active", false)),
		"resolved": bool(snapshot.get("resolved", false)),
		"final_settlement_count": int(snapshot.get("final_settlement_count", 0)),
	}


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
