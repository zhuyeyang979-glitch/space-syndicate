extends SceneTree

const FLOW_SCENE := preload("res://scenes/runtime/TablePlayerActionApplicationFlowController.tscn")
const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const GROUP_PORT_SCENE := preload("res://scenes/runtime/CardGroupActionPort.tscn")

const SESSION_ID := "session.action-spine"
const SESSION_REVISION := 17
const AUTHORIZATION_REVISION := 9
const HUMAN_SOURCE_REVISION := 41

var _checks := 0
var _failures: Array[String] = []


class FakeIdentity:
	extends PlayerIdentityAuthorizationBoundary

	func current_actor_context(source_surface: StringName = &"game_screen") -> GameplayActorAuthorizationContext:
		return _context(source_surface)

	func authorize_actor_index(requested_actor_player_index: int, source_surface: StringName = &"game_screen") -> GameplayActorAuthorizationContext:
		return _context(source_surface) if requested_actor_player_index == 0 \
			else GameplayActorAuthorizationContext.denied("actor_authority_mismatch", 1, source_surface)

	func _context(source_surface: StringName) -> GameplayActorAuthorizationContext:
		var context := GameplayActorAuthorizationContext.new()
		context.request_id = "actor-context.action-spine"
		context.authorized = true
		context.reason_code = "authorized"
		context.viewer_index = 0
		context.authorized_actor_player_index = 0
		context.authorization_revision = AUTHORIZATION_REVISION
		context.session_id = SESSION_ID
		context.session_revision = SESSION_REVISION
		context.source_surface = source_surface
		context.issued_at_operation_revision = 1
		return context


class FakeSession:
	extends GameSessionRuntimeController

	func session_summary() -> Dictionary:
		return {
			"session_state": STATE_RUNNING,
			"session_id": SESSION_ID,
			"scenario_id": "action-spine",
			"ruleset_id": "v0.6",
			"seed": 20260728,
		}

	func session_start_revision() -> int:
		return SESSION_REVISION


class FakeOfferSource:
	extends Node
	var revision := HUMAN_SOURCE_REVISION

	func current_action_offer_revision(_actor_index: int) -> int:
		return revision


class FakeCardPlay:
	extends CardPlaySubmissionRuntimeController
	var submit_count := 0
	var requests: Array[Dictionary] = []
	var accept := true

	func request_hand_play(request: Dictionary) -> Dictionary:
		submit_count += 1
		requests.append(request.duplicate(true))
		return {
			"accepted": accept,
			"queued": accept,
			"reason": "card_play_accepted" if accept else "card_play_rejected",
		}


class FakeCardGroup:
	extends CardGroupActionPort
	var submission_count := 0
	var ready_count := 0
	var reorder_count := 0
	var last_actor := -1
	var last_resolution := -1
	var last_direction := 0

	func submit_ready(actor_index: int, resolution_id: int) -> Dictionary:
		submission_count += 1
		ready_count += 1
		last_actor = actor_index
		last_resolution = resolution_id
		return {"accepted": true, "reason_id": "card_group_ready_committed", "effect_ref": "card.group.ready.card.resolution.%d" % resolution_id, "authoritative_revision": submission_count}

	func submit_reorder(actor_index: int, resolution_id: int, direction: int) -> Dictionary:
		submission_count += 1
		reorder_count += 1
		last_actor = actor_index
		last_resolution = resolution_id
		last_direction = direction
		return {"accepted": true, "reason_id": "card_group_reorder_committed", "effect_ref": "card.group.reorder.card.resolution.%d" % resolution_id, "authoritative_revision": submission_count}

	func debug_snapshot() -> Dictionary:
		return {"submission_count": submission_count, "ready_apply_count": ready_count, "reorder_apply_count": reorder_count}


class FakeDistrictSupply:
	extends DistrictSupplyActionPort
	var submit_count := 0
	var last_intent: DistrictSupplyActionIntent
	var pending_discard_next := false
	var quote_failure_next := false
	var active_quote_id := ""

	func submit_intent(intent: DistrictSupplyActionIntent) -> DistrictSupplyActionReceipt:
		submit_count += 1
		last_intent = intent
		var receipt := DistrictSupplyActionReceipt.new()
		receipt.request_id = intent.request_id
		receipt.action_kind = intent.action_kind
		receipt.accepted = true
		receipt.applied = true
		receipt.reason_code = "district_supply_opened"
		receipt.actor_player_index = intent.actor_player_index
		receipt.district_index = intent.district_index
		receipt.focus_district_index = intent.district_index
		if intent.action_kind == DistrictSupplyActionIntent.KIND_QUOTE \
				and quote_failure_next:
			quote_failure_next = false
			active_quote_id = ""
			receipt.accepted = false
			receipt.applied = false
			receipt.reason_code = "quote_unavailable"
			return receipt
		if intent.action_kind == DistrictSupplyActionIntent.KIND_PURCHASE \
				and pending_discard_next:
			pending_discard_next = false
			receipt.accepted = true
			receipt.applied = true
			receipt.reason_code = "hand_limit_requires_discard"
			receipt.requires_discard = true
			receipt.quote_id = intent.locked_quote_id
		if intent.action_kind == DistrictSupplyActionIntent.KIND_QUOTE:
			receipt.quote_id = "quote.action-spine.%d" % submit_count
			active_quote_id = receipt.quote_id
		elif intent.action_kind in [
			DistrictSupplyActionIntent.KIND_OPEN,
			DistrictSupplyActionIntent.KIND_CLOSE,
			DistrictSupplyActionIntent.KIND_PURCHASE,
		]:
			active_quote_id = ""
		receipt.presentation_refresh_requested = true
		return receipt

	func quote_is_confirmable(
		_player_index: int,
		_district_index: int,
		_card_id: String,
		quote_id: String
	) -> bool:
		return not active_quote_id.is_empty() and quote_id == active_quote_id


class FakeSelectionPort:
	extends TableSelectionIntentPort
	var submit_count := 0
	var last_intent: TableSelectionIntent

	func submit_intent(intent: TableSelectionIntent) -> TableSelectionReceipt:
		submit_count += 1
		last_intent = intent
		var receipt := TableSelectionReceipt.new()
		receipt.request_id = intent.request_id
		receipt.selection_kind = intent.selection_kind
		receipt.viewer_index = intent.viewer_index
		receipt.authorization_revision = intent.authorization_revision
		receipt.session_revision = intent.session_revision
		receipt.accepted = true
		receipt.applied = true
		receipt.changed = true
		receipt.reason_code = "selection_applied"
		receipt.district_index = intent.target_district_index
		receipt.selection_revision_before = submit_count - 1
		receipt.selection_revision_after = submit_count
		receipt.presentation_refresh_requested = true
		return receipt


class FakeRefresh:
	extends TablePresentationRefreshPort
	var request_count := 0
	var kinds: Array[StringName] = []

	func request_immediate(kind: StringName, _reason: StringName = &"state_changed") -> TablePresentationApplyReceipt:
		request_count += 1
		kinds.append(kind)
		var receipt := TablePresentationApplyReceipt.new()
		receipt.kind = kind
		receipt.applied = true
		return receipt


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_game_screen_human_paths()
	_test_ai_shared_path_and_private_receipt_firewall()
	_test_authorization_journal_and_exact_once()
	_test_stale_collision_and_invalid_target()
	_test_group_district_and_refresh_routing()
	_test_economy_surface_action_spine()
	_test_current_lane_visibility_and_drag_override()
	_test_source_negative_gates()
	_finish()


func _test_game_screen_human_paths() -> void:
	var fixture := _fixture()
	var controller := fixture.controller as TablePlayerActionApplicationFlowController
	var card_play := fixture.card_play as FakeCardPlay
	var refresh := fixture.refresh as FakeRefresh
	var identity := fixture.identity as FakeIdentity
	var screen := GAME_SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	(fixture.host as Node).add_child(screen)
	screen.bind_presentation_viewer(0, AUTHORIZATION_REVISION)
	screen.bind_gameplay_actor_authorization_context(identity.current_actor_context(&"game_screen"))
	var receipts: Array[Dictionary] = []
	var player_receipts: Array[Dictionary] = []
	screen.game_action_intent_requested.connect(func(intent: Dictionary) -> void:
		receipts.append(controller.submit_intent(intent))
	)
	controller.receipt_ready.connect(func(receipt: Dictionary) -> void: player_receipts.append(receipt))
	var offer := controller.human_card_play_offer(0, 0, HUMAN_SOURCE_REVISION, true, "none")
	_expect(bool(GameActionOfferV1.validation_report(offer).get("valid", false)), "human card offer is a valid closed GameActionOfferV1")
	for submission_kind in ["human_click", "human_quick_action"]:
		_expect(screen.submit_game_action_offer(offer, submission_kind, {}, {}), "%s adapter emits one typed intent" % submission_kind)
	_expect(screen.submit_game_action_offer(offer, "human_drag", {}, {"region_id": "region.beta"}), "human drag emits the same typed intent with a stable public region target")
	_expect(
		not screen.submit_game_action_offer(
			offer,
			"human_click",
			{},
			{"card_instance_id": "card.instance.retargeted"}
		),
		"human adapter cannot rewrite an offer-bound required card target"
	)
	_expect(receipts.size() == 3 and receipts.all(func(receipt: Dictionary) -> bool: return bool(receipt.get("accepted", false))), "click, quick action, and drag all reach the same accepted application flow")
	_expect(card_play.submit_count == 3 and str(card_play.requests[0].get("submission_source", "")) == "human_click" and str(card_play.requests[1].get("submission_source", "")) == "human_quick_action" and str(card_play.requests[2].get("submission_source", "")) == "human_drag", "all three human adapters reach the same typed card-play target exactly once")
	_expect(int(card_play.requests[2].get("selected_district", -1)) == 1 and not card_play.requests[2].has("screen_position"), "drag converts Vector2 hit testing to a stable authoritative district index before core submission")
	_expect(player_receipts.size() == 3 and refresh.request_count == 3, "each accepted human intent emits one private receipt and one refresh request")
	_dispose(fixture)


func _test_ai_shared_path_and_private_receipt_firewall() -> void:
	var fixture := _fixture()
	var controller := fixture.controller as TablePlayerActionApplicationFlowController
	var capability := fixture.capability as GameActionAiSubmissionCapability
	var card_play := fixture.card_play as FakeCardPlay
	var refresh := fixture.refresh as FakeRefresh
	var emitted: Array[Dictionary] = []
	controller.receipt_ready.connect(func(receipt: Dictionary) -> void: emitted.append(receipt))
	var ai_offer := controller.ai_card_play_offer(capability, 1, 0)
	var ai_authorization := controller.ai_actor_authorization(capability, 1)
	var ai_intent := _intent(ai_offer, ai_authorization, "request.ai.card-play", "ai_decision")
	var ai_receipt := controller.submit_intent(ai_intent, capability)
	_expect(bool(ai_receipt.get("accepted", false)) and str(ai_receipt.get("semantic_action_id", "")) == GameActionIntentV1.ACTION_CARD_PLAY, "AI submits the same semantic card-play action through the shared application flow")
	_expect(card_play.submit_count == 1 and int(card_play.requests[0].get("player_index", -1)) == 1, "AI reaches the same card-play command target with its authorized actor")
	_expect(str(ai_receipt.get("viewer_private_projection_ref", "")) == "none" and emitted.is_empty(), "AI receipt never crosses the player-facing receipt signal")
	_expect(refresh.request_count == 1, "accepted AI action still requests exactly one public table refresh")
	var human_offer := controller.human_card_play_offer(0, 0, HUMAN_SOURCE_REVISION, true, "none")
	var human_receipt := controller.submit_intent(_intent(human_offer, controller.human_actor_authorization(), "request.human.card-play", "human_click"))
	_expect(bool(human_receipt.get("accepted", false)) and _same_string_set(ai_receipt.keys(), human_receipt.keys()), "human and AI receive the same authoritative receipt shape")
	_expect(card_play.submit_count == 2 and emitted.size() == 1, "human and AI share one command target while only human private feedback reaches GameScreen")
	_dispose(fixture)


func _test_authorization_journal_and_exact_once() -> void:
	var fixture := _fixture()
	var controller := fixture.controller as TablePlayerActionApplicationFlowController
	var refresh := fixture.refresh as FakeRefresh
	var offer := controller.human_action_offer(GameActionIntentV1.ACTION_SESSION_END_TURN, HUMAN_SOURCE_REVISION, true, "none")
	var authorization := controller.human_actor_authorization()
	var forged := authorization.duplicate(true)
	forged["actor_revision"] = AUTHORIZATION_REVISION + 1
	forged["authorization_proof_ref"] = "authorization.%d.%d" % [AUTHORIZATION_REVISION + 1, SESSION_REVISION]
	var forged_receipt := controller.submit_intent(_intent(offer, forged, "request.auth-journal", "human_click"))
	_expect(not bool(forged_receipt.get("accepted", true)) and str(forged_receipt.get("reason_id", "")) == "actor-authorization-rejected", "forged actor authorization fails closed")
	_expect(int(controller.debug_snapshot().get("journal_size", -1)) == 0, "unauthorized request cannot reserve a request ID in the exact-once journal")
	var valid := _intent(offer, authorization, "request.auth-journal", "human_click")
	var committed := controller.submit_intent(valid)
	_expect(bool(committed.get("accepted", false)) and not bool(committed.get("request_id_collision", true)), "authorized request may reuse an ID previously attempted by an unauthorized caller")
	var wrong_session := authorization.duplicate(true)
	wrong_session["session_id"] = "session.forged"
	var wrong_session_receipt := controller.submit_intent(_intent(offer, wrong_session, "request.wrong-session", "human_click"))
	_expect(not bool(wrong_session_receipt.get("accepted", true)) and int(controller.debug_snapshot().get("journal_size", -1)) == 1, "wrong-session input cannot clear or extend the trusted session journal")
	var replay := controller.submit_intent(valid)
	_expect(bool(replay.get("accepted", false)) and bool(replay.get("idempotent_replay", false)), "duplicate authorized request returns the committed idempotent receipt")
	_expect(refresh.request_count == 1 and int(controller.debug_snapshot().get("replay_count", 0)) == 1, "duplicate replay performs zero additional refresh or mutation")
	_dispose(fixture)


func _test_stale_collision_and_invalid_target() -> void:
	var fixture := _fixture()
	var controller := fixture.controller as TablePlayerActionApplicationFlowController
	var card_play := fixture.card_play as FakeCardPlay
	var refresh := fixture.refresh as FakeRefresh
	var authorization := controller.human_actor_authorization()
	var offer := controller.human_card_play_offer(0, 0, HUMAN_SOURCE_REVISION, true, "none")
	var stale_offer := offer.duplicate(true)
	stale_offer["source_revision"] = HUMAN_SOURCE_REVISION - 1
	stale_offer = GameActionOfferV1.build(_unsealed_offer(stale_offer))
	var stale := controller.submit_intent(_intent(stale_offer, authorization, "request.stale", "human_click"))
	var stale_replay := controller.submit_intent(_intent(stale_offer, authorization, "request.stale", "human_click"))
	_expect(str(stale.get("reason_id", "")) == "source-revision-stale" and bool(stale_replay.get("idempotent_replay", false)), "stale source revision rejects once and replays deterministically")
	_expect(card_play.submit_count == 0 and refresh.request_count == 0, "stale request and replay have zero command-target and refresh effects")
	var valid := _intent(offer, authorization, "request.collision", "human_click")
	var first := controller.submit_intent(valid)
	var other_offer := controller.human_card_play_offer(0, 1, HUMAN_SOURCE_REVISION, true, "none")
	var collision := controller.submit_intent(_intent(other_offer, authorization, "request.collision", "human_click"))
	_expect(bool(first.get("accepted", false)) and bool(collision.get("request_id_collision", false)) and not bool(collision.get("idempotent_replay", true)), "same request ID with another fingerprint is a collision, never a replay")
	var invalid_targets := GameActionOfferV1.target_ids(offer)
	invalid_targets["card_instance_id"] = "card.instance.invalid"
	var invalid := controller.submit_intent(_intent(offer, authorization, "request.invalid-target", "human_click", {}, invalid_targets))
	_expect(str(invalid.get("reason_id", "")) == "card-binding-stale", "invalid private card binding fails closed at the command boundary")
	_expect(card_play.submit_count == 1 and refresh.request_count == 1, "collision and invalid target apply neither command nor refresh")
	_dispose(fixture)


func _test_group_district_and_refresh_routing() -> void:
	var fixture := _fixture()
	var controller := fixture.controller as TablePlayerActionApplicationFlowController
	var group := fixture.group as FakeCardGroup
	var district := fixture.district as FakeDistrictSupply
	var refresh := fixture.refresh as FakeRefresh
	var authorization := controller.human_actor_authorization()
	var ready_offer := controller.human_action_offer(GameActionIntentV1.ACTION_CARD_GROUP_READY, HUMAN_SOURCE_REVISION, true, "none", {"resolution_id": GameActionCardBindingV1.resolution_ref(71)})
	var ready_intent := _intent(ready_offer, authorization, "request.group-ready", "human_click")
	var ready := controller.submit_intent(ready_intent)
	var ready_replay := controller.submit_intent(ready_intent)
	_expect(bool(ready.get("accepted", false)) and bool(ready_replay.get("idempotent_replay", false)) and group.ready_count == 1, "card-group ready applies exactly once")
	var reorder_offer := controller.human_action_offer(GameActionIntentV1.ACTION_CARD_GROUP_REORDER, HUMAN_SOURCE_REVISION, true, "none", {"resolution_id": GameActionCardBindingV1.resolution_ref(71)})
	var reorder := controller.submit_intent(_intent(reorder_offer, authorization, "request.group-reorder", "human_click", {"direction": 1}))
	_expect(bool(reorder.get("accepted", false)) and group.reorder_count == 1 and group.last_direction == 1, "card-group reorder reaches its typed domain port once")
	var district_offer := controller.human_action_offer(GameActionIntentV1.ACTION_DISTRICT_SUPPLY_OPEN, HUMAN_SOURCE_REVISION, true, "none", {"region_id": "region.beta"})
	var district_receipt := controller.submit_intent(_intent(district_offer, authorization, "request.district-open", "human_click"))
	_expect(bool(district_receipt.get("accepted", false)) and district.submit_count == 1 and district.last_intent.district_index == 1, "district action resolves a stable region ID through the existing typed domain owner")
	var end_offer := controller.human_action_offer(GameActionIntentV1.ACTION_SESSION_END_TURN, HUMAN_SOURCE_REVISION, true, "none")
	var ended := controller.submit_intent(_intent(end_offer, authorization, "request.end-turn", "human_click"))
	_expect(bool(ended.get("accepted", false)), "end-turn compatibility request is represented by a closed semantic intent")
	_expect(refresh.request_count == 3, "ready, reorder, and end-turn each refresh once while the district owner keeps its existing refresh ownership")
	_dispose(fixture)


func _test_economy_surface_action_spine() -> void:
	var fixture := _fixture()
	var controller := fixture.controller as TablePlayerActionApplicationFlowController
	var district := fixture.district as FakeDistrictSupply
	var selection_port := fixture.selection_port as FakeSelectionPort
	var authorization := controller.human_actor_authorization()
	var action_rows := [
		{
			"action_id": GameActionIntentV1.ACTION_DISTRICT_SELECT,
			"targets": {"region_id": "region.beta"},
			"request_id": "request.economy-select",
		},
		{
			"action_id": GameActionIntentV1.ACTION_DISTRICT_SUPPLY_CLOSE,
			"targets": {},
			"request_id": "request.economy-close",
		},
		{
			"action_id": GameActionIntentV1.ACTION_DISTRICT_SUPPLY_OPEN,
			"targets": {"region_id": "region.beta"},
			"request_id": "request.economy-open",
		},
		{
			"action_id": GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE,
			"targets": {
				"region_id": "region.beta",
				"card_id": "facility.market.energy.rank_1",
			},
			"request_id": "request.economy-quote",
		},
	]
	var receipts: Array[Dictionary] = []
	for row_variant in action_rows:
		var row := row_variant as Dictionary
		var offer := controller.human_surface_action_offer(
			str(row.get("action_id", "")),
			row.get("targets", {}) as Dictionary
		)
		var action_intent := _intent(
			offer,
			authorization,
			str(row.get("request_id", "")),
			"human_click"
		)
		receipts.append(controller.submit_intent(action_intent))
	var purchase_offer := controller.human_surface_action_offer(
		GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
		{
			"region_id": "region.beta",
			"card_id": "facility.market.energy.rank_1",
		}
	)
	var purchase_intent := _intent(
		purchase_offer,
		authorization,
		"request.economy-purchase",
		"human_click"
	)
	var purchase := controller.submit_intent(purchase_intent)
	var purchase_replay := controller.submit_intent(purchase_intent)
	receipts.append(purchase)
	var all_commits_valid := true
	for receipt_variant in receipts:
		var receipt := receipt_variant as Dictionary
		if not bool(receipt.get("accepted", false)) \
				or (receipt.get("committed_effect_refs", []) as Array).is_empty() \
				or int(receipt.get("authoritative_revision", 0)) <= 0:
			all_commits_valid = false
			break
	_expect(
		all_commits_valid,
		"district select, supply close/open/quote/purchase each return authoritative GameAction commit evidence"
	)
	_expect(
		selection_port.submit_count == 1 \
			and bool(selection_port.last_intent.validation_report().get("valid", false)) \
			and selection_port.last_intent.source_surface == &"planet_map" \
			and district.submit_count == 4 \
			and district.last_intent.action_kind == DistrictSupplyActionIntent.KIND_PURCHASE \
			and district.last_intent.locked_quote_id == "quote.action-spine.3",
		"the semantic adapters reach each typed owner once, preserve the typed planet-map source contract, and bind purchase to the accepted quote"
	)
	_expect(
		bool(purchase_replay.get("accepted", false)) \
			and bool(purchase_replay.get("idempotent_replay", false)) \
			and district.submit_count == 4,
		"duplicate purchase delivery replays the GameAction receipt with zero second domain apply"
	)
	var second_quote_offer := controller.human_surface_action_offer(
		GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE,
		{
			"region_id": "region.beta",
			"card_id": "facility.market.energy.rank_1",
		}
	)
	var second_quote := controller.submit_intent(_intent(
		second_quote_offer,
		authorization,
		"request.economy-quote.pending-discard",
		"human_click"
	))
	var pending_purchase_offer := controller.human_surface_action_offer(
		GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
		{
			"region_id": "region.beta",
			"card_id": "facility.market.energy.rank_1",
		}
	)
	var tampered_targets := GameActionOfferV1.target_ids(pending_purchase_offer)
	tampered_targets["quote_id"] = "quote.action-spine.forged"
	var tampered_purchase := controller.submit_intent(_intent(
		pending_purchase_offer,
		authorization,
		"request.economy-purchase.forged-quote",
		"human_click",
		{},
		tampered_targets
	))
	district.pending_discard_next = true
	var pending_purchase_intent := _intent(
		pending_purchase_offer,
		authorization,
		"request.economy-purchase.pending-discard",
		"human_click"
	)
	var pending_purchase := controller.submit_intent(pending_purchase_intent)
	var pending_purchase_replay := controller.submit_intent(pending_purchase_intent)
	var pending_effect_committed := false
	for effect_ref_variant in pending_purchase.get("committed_effect_refs", []) as Array:
		if str(effect_ref_variant).contains(".pending-discard."):
			pending_effect_committed = true
			break
	_expect(
		bool(second_quote.get("accepted", false)) \
			and str(tampered_purchase.get("reason_id", "")) == "district-quote-binding-stale" \
			and bool(pending_purchase.get("accepted", false)) \
			and pending_effect_committed \
			and bool(pending_purchase_replay.get("idempotent_replay", false)) \
			and district.submit_count == 6,
		"purchase quote identity is intent-bound and a full-hand pending discard is one replay-safe committed application transition"
	)
	var retained_quote := controller.submit_intent(_intent(
		controller.human_surface_action_offer(
			GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE,
			{
				"region_id": "region.beta",
				"card_id": "facility.market.energy.rank_1",
			}
		),
		authorization,
		"request.economy-quote.before-failure",
		"human_click"
	))
	district.quote_failure_next = true
	var failed_requote := controller.submit_intent(_intent(
		controller.human_surface_action_offer(
			GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE,
			{
				"region_id": "region.beta",
				"card_id": "facility.market.energy.rank_1",
			}
		),
		authorization,
		"request.economy-quote.failure",
		"human_click"
	))
	var stale_purchase_offer := controller.human_surface_action_offer(
		GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
		{
			"region_id": "region.beta",
			"card_id": "facility.market.energy.rank_1",
		}
	)
	_expect(
		bool(retained_quote.get("accepted", false)) \
			and not bool(failed_requote.get("accepted", true)) \
			and stale_purchase_offer.is_empty() \
			and district.submit_count == 8,
		"a failed replacement quote clears the facade credential instead of authorizing purchase with an invalidated prior quote"
	)
	var quote_before_reopen := controller.submit_intent(_intent(
		controller.human_surface_action_offer(
			GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE,
			{
				"region_id": "region.beta",
				"card_id": "facility.market.energy.rank_1",
			}
		),
		authorization,
		"request.economy-quote.before-reopen",
		"human_click"
	))
	var reopen := controller.submit_intent(_intent(
		controller.human_surface_action_offer(
			GameActionIntentV1.ACTION_DISTRICT_SUPPLY_OPEN,
			{"region_id": "region.beta"}
		),
		authorization,
		"request.economy-reopen",
		"human_click"
	))
	var purchase_after_reopen := controller.human_surface_action_offer(
		GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
		{
			"region_id": "region.beta",
			"card_id": "facility.market.energy.rank_1",
		}
	)
	_expect(
		bool(quote_before_reopen.get("accepted", false)) \
			and bool(reopen.get("accepted", false)) \
			and purchase_after_reopen.is_empty() \
			and district.submit_count == 10,
		"opening a fresh district window invalidates the prior quote before another purchase offer can be issued"
	)
	var debug := controller.debug_snapshot()
	_expect(
		int(debug.get("district_selection_apply_count", 0)) == 1 \
			and int(debug.get("district_adapter_apply_count", 0)) == 9,
		"flow diagnostics count one selection and nine accepted supply application transitions without owning gameplay state"
	)
	_dispose(fixture)


func _test_current_lane_visibility_and_drag_override() -> void:
	var host := Node.new()
	root.add_child(host)
	var world := WorldSessionState.new()
	world.name = "WorldSessionState"
	world.players = [{"eliminated": false}, {"eliminated": false}]
	host.add_child(world)
	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	queue.name = "CardResolutionQueueRuntimeService"
	host.add_child(queue)
	queue.replace_current_queue([{"resolution_id": 10, "player_index": 0}])
	queue.replace_next_queue([{"resolution_id": 20, "player_index": 0}])
	queue.replace_active_entry({"resolution_id": 30, "player_index": 0})
	var port := GROUP_PORT_SCENE.instantiate() as CardGroupActionPort
	host.add_child(port)
	var current_validation := port.call("_validate_actor_entry", 0, 10) as Dictionary
	var next_validation := port.call("_validate_actor_entry", 0, 20) as Dictionary
	var active_validation := port.call("_validate_actor_entry", 0, 30) as Dictionary
	_expect(bool(current_validation.get("valid", false)) and not bool(next_validation.get("valid", true)) and not bool(active_validation.get("valid", true)), "card-group actions authorize only actor-owned entries in the current queue lane")
	var query := TablePresentationViewModelQuery.new()
	host.add_child(query)
	query.set("_queue", queue)
	_expect(bool(query.call("_viewer_owns_resolution_in_scope", 10, 0, "current")) and not bool(query.call("_viewer_owns_resolution_in_scope", 20, 0, "current")) and bool(query.call("_viewer_owns_resolution_in_scope", 20, 0, "next")), "viewer ownership is derived from the trusted queue and projected only as a scoped boolean")
	var selection := TableSelectionState.new()
	selection.selected_district = 0
	host.add_child(selection)
	var submission := CardPlaySubmissionRuntimeController.new()
	host.add_child(submission)
	submission.set("_table_selection_state", selection)
	var overridden := submission.call("_selection_snapshot", {"selected_district": 1}) as Dictionary
	var rejected := submission.call("_selection_snapshot", {"selected_district": -1}) as Dictionary
	_expect(int(overridden.get("selected_district", -1)) == 1 and selection.selected_district == 0 and rejected.is_empty(), "typed drag target overrides the frozen submission snapshot without mutating UI selection")
	host.free()


func _test_source_negative_gates() -> void:
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/runtime/table_player_action_application_flow_controller.gd")
	var drag_body := _function_body(screen_source, "_on_card_drag_released")
	var submit_body := _function_body(flow_source, "submit_intent")
	for forbidden in ["action_id.begins_with", "play_\"", "district_\"", "group_order_", "screen_position", "Vector2"]:
		_expect(not flow_source.contains(forbidden), "application flow contains no legacy prefix or screen-coordinate dispatch: %s" % forbidden)
	_expect(not screen_source.contains("signal action_requested") and not screen_source.contains("signal end_turn_requested") and not screen_source.contains("signal card_drop_requested"), "RuntimeGameScreen exposes no retired raw outward action signal")
	_expect(drag_body == "MISSING" \
		and not screen_source.contains("func _on_card_drag_released(") \
		and screen_source.contains("func _on_game_action_offer_requested(") \
		and screen_source.contains("if not submit_game_action_offer("), "retired HandRack drag has no production callback and PlayerCardDock forwards one typed offer")
	_expect(submit_body.find("_authorization_reason") < submit_body.find("_sync_journal") and not submit_body.contains("_remember_and_complete(intent, _receipt_for(intent, false, authorization_reason"), "authorization precedes exact-once journal lookup and unauthorized requests are never remembered")
	_expect(not flow_source.contains("Callable(") and not flow_source.contains("current_scene") and not flow_source.contains("call(method_name"), "application flow contains no scene-root fallback or generic method dispatch")


func _fixture() -> Dictionary:
	var host := Node.new()
	host.name = "ActionFlowFixture"
	root.add_child(host)
	var identity := FakeIdentity.new()
	identity.name = "PlayerIdentityAuthorizationBoundary"
	host.add_child(identity)
	var world := WorldSessionState.new()
	world.name = "WorldSessionState"
	host.add_child(world)
	world.players = [
		{"name": "Human", "is_ai": false, "eliminated": false, "slots": [_card("human-card-0", "qa.card.alpha"), _card("human-card-1", "qa.card.beta")]},
		{"name": "AI", "is_ai": true, "eliminated": false, "slots": [_card("ai-card-0", "qa.card.alpha")]},
	]
	world.districts = [{"region_id": "region.alpha"}, {"region_id": "region.beta"}]
	var session := FakeSession.new()
	session.name = "GameSessionRuntimeController"
	host.add_child(session)
	var offer_source := FakeOfferSource.new()
	offer_source.name = "TablePresentationViewModelQuery"
	host.add_child(offer_source)
	var card_play := FakeCardPlay.new()
	card_play.name = "CardPlaySubmissionRuntimeController"
	host.add_child(card_play)
	var group := FakeCardGroup.new()
	group.name = "CardGroupActionPort"
	host.add_child(group)
	var selection_state := TableSelectionState.new()
	selection_state.name = "TableSelectionState"
	host.add_child(selection_state)
	var selection_port := FakeSelectionPort.new()
	selection_port.name = "TableSelectionIntentPort"
	host.add_child(selection_port)
	var district := FakeDistrictSupply.new()
	district.name = "DistrictSupplyActionPort"
	host.add_child(district)
	var refresh := FakeRefresh.new()
	refresh.name = "TablePresentationRefreshPort"
	host.add_child(refresh)
	var controller := FLOW_SCENE.instantiate() as TablePlayerActionApplicationFlowController
	host.add_child(controller)
	var capability := GameActionAiSubmissionCapability.new()
	_expect(controller.bind_ai_submission_capability(capability), "fixture binds the opaque AI submission capability once")
	return {"host": host, "identity": identity, "world": world, "session": session, "offer_source": offer_source, "card_play": card_play, "group": group, "selection_state": selection_state, "selection_port": selection_port, "district": district, "refresh": refresh, "controller": controller, "capability": capability}


func _card(runtime_id: String, card_id: String) -> Dictionary:
	return {
		"runtime_instance_id": runtime_id,
		"machine": {"card_id": card_id, "family_id": "qa.family", "rank": 1},
		"name": card_id,
		"kind": "economic",
	}


func _intent(
	offer: Dictionary,
	authorization: Dictionary,
	request_id: String,
	submission_kind: String,
	parameters: Dictionary = {},
	target_override: Dictionary = {}
) -> Dictionary:
	var targets := GameActionOfferV1.target_ids(offer)
	for key_variant in target_override.keys():
		targets[str(key_variant)] = target_override.get(key_variant)
	return GameActionIntentV1.build({
		"schema_version": GameActionIntentV1.SCHEMA_VERSION,
		"request_id": request_id,
		"semantic_action_id": str(offer.get("semantic_action_id", "")),
		"source_revision": int(offer.get("source_revision", 0)),
		"actor_authorization": authorization.duplicate(true),
		"target_ids": targets,
		"parameters": parameters.duplicate(true),
		"submission_kind": submission_kind,
	})


func _unsealed_offer(offer: Dictionary) -> Dictionary:
	var result := offer.duplicate(true)
	result.erase("offer_fingerprint")
	return result


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return "MISSING"
	var next := source.find("\nfunc ", start + 5)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _same_string_set(left: Array, right: Array) -> bool:
	var left_copy := left.map(func(value: Variant) -> String: return str(value))
	var right_copy := right.map(func(value: Variant) -> String: return str(value))
	left_copy.sort()
	right_copy.sort()
	return left_copy == right_copy


func _dispose(fixture: Dictionary) -> void:
	var host := fixture.get("host") as Node
	if host != null:
		host.free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % message)
		return
	_failures.append(message)
	push_error("TABLE PLAYER ACTION FLOW: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("TABLE_PLAYER_ACTION_APPLICATION_FLOW_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("TABLE_PLAYER_ACTION_APPLICATION_FLOW_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
