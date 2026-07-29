extends SceneTree

const SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

const CARD_INSTANCE_ID := "card.instance.commodity-screen"
const TARGET_KIND := "same_industry_factory_or_market"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	root.add_child(screen)
	await process_frame
	screen.bind_presentation_viewer(0, 9)
	screen.bind_gameplay_actor_authorization_context(_actor_context())
	var selection_intents: Array[TableSelectionIntent] = []
	var action_intents: Array[Dictionary] = []
	screen.table_selection_intent_requested.connect(func(intent: TableSelectionIntent) -> void:
		selection_intents.append(intent)
	)
	screen.game_action_intent_requested.connect(func(intent: Dictionary) -> void:
		action_intents.append(intent.duplicate(true))
	)

	screen.apply_state(_table_state(1, -1, "", false))
	await process_frame
	var dock := screen.get_node("SafeArea/MainRows/PlayerCardDock") as SpaceSyndicatePlayerCardDock
	var card := dock.find_child("CardFace", true, false) as Control
	_expect(card != null, "production GameScreen renders the real commodity CardFace in PlayerCardDock")
	dock.call("_on_card_clicked", {}, &"commodity_cards", card)
	_expect(not dock.target_selection_active(), "first commodity selection remains a read-only detail stage")
	var selected_row: Dictionary = dock.call("_row_for_card", card) as Dictionary
	dock.call("_request_scene_target_selection", &"commodity_cards", selected_row)
	_expect(dock.target_selection_active(), "explicit second activation enters target-selection mode")
	if not dock.target_selection_active():
		screen.queue_free()
		await process_frame
		_finish()
		return

	screen.call("_on_district_selection_requested", 0, &"planet_map")
	_expect(selection_intents.size() >= 2, "card selection and map target produce typed table-selection intents")
	var district_intent: TableSelectionIntent = selection_intents.back()
	_expect(district_intent.selection_kind == TableSelectionIntent.KIND_SELECT_DISTRICT \
		and district_intent.target_district_index == 0 \
		and district_intent.source_surface == &"planet_map", "map click selects the target district through the typed selection port")
	_expect(action_intents.is_empty(), "target click does not submit before an authoritative refreshed offer exists")

	var receipt := TableSelectionReceipt.new()
	receipt.request_id = district_intent.request_id
	receipt.accepted = true
	receipt.reason_code = "selection_applied"
	receipt.selection_kind = TableSelectionIntent.KIND_SELECT_DISTRICT
	receipt.viewer_index = 0
	receipt.authorization_revision = 9
	receipt.session_revision = 3
	receipt.district_index = 0
	receipt.hand_slot = 0
	receipt.changed = true
	receipt.applied = true
	receipt.selection_revision_before = 1
	receipt.selection_revision_after = 2
	receipt.presentation_refresh_requested = true
	screen.apply_table_selection_receipt(receipt)
	_expect(str(screen.card_target_selection_snapshot().get("pending_region_id", "")) == "region.alpha", "accepted selection receipt binds the public region id without choosing a facility in UI")

	screen.apply_state(_table_state(2, 0, "region.alpha", true))
	await process_frame
	_expect(action_intents.size() == 1, "authoritative refreshed offer submits exactly once through GameActionIntent")
	if action_intents.is_empty():
		screen.queue_free()
		await process_frame
		_finish()
		return
	var action_intent := action_intents[0]
	_expect(str(action_intent.get("semantic_action_id", "")) == INTENT.ACTION_CARD_PLAY \
		and str((action_intent.get("target_ids", {}) as Dictionary).get("region_id", "")) == "region.alpha" \
		and str(action_intent.get("submission_kind", "")) == "human_click", "submitted intent preserves the typed card and region target binding")
	var target_snapshot := screen.card_target_selection_snapshot()
	_expect(not bool(target_snapshot.get("active", true)) \
		and int(target_snapshot.get("submitted_count", 0)) == 1 \
		and not bool(target_snapshot.get("calculates_legality", true)) \
		and not bool(target_snapshot.get("references_main", true)), "scene-owned target mode closes after one submit and owns no rule logic")

	screen.apply_state(_table_state(2, 0, "region.alpha", true))
	await process_frame
	_expect(action_intents.size() == 1, "duplicate table refresh cannot resubmit the commodity action")

	screen.queue_free()
	await process_frame
	_finish()


func _table_state(revision: int, selected_district: int, region_id: String, available: bool) -> Dictionary:
	return {
		"selection_context": {
			"revision": revision,
			"selected_district": selected_district,
			"district_count": 2,
			"district_region_ids": ["region.alpha", "region.beta"],
			"district_supply_open_offers": [],
			"selected_trade_product": "",
			"trade_product_ids": [],
			"default_trade_product_id": "",
			"selected_hand_slot": 0,
			"selected_card_resolution_id": -1,
		},
		"player_card_dock": _projection(revision, region_id, available),
	}


func _projection(revision: int, region_id: String, available: bool) -> Dictionary:
	var offer := _offer(revision, region_id, available)
	return PROJECTION.build({
		"schema_version": PROJECTION.SCHEMA_VERSION,
		"viewer_index": 0,
		"actor_id": "player.0",
		"authorization_revision": 9,
		"source_revision": revision,
		"runtime_ruleset_id": PROJECTION.RUNTIME_RULESET_V06,
		"capacity_mode": PROJECTION.CAPACITY_MODE_SHARED_V06,
		"visibility_scope": "viewer_private",
		"normal_cards": [],
		"commodity_cards": [{
			"commodity_card_instance_id": CARD_INSTANCE_ID,
			"card_semantic_id": "commodity.life.rank-1",
			"slot_id": "hand.slot.0",
			"commodity_id": "commodity.life",
			"color_id": "life",
			"level": 1,
			"base_units": 1,
			"display_name": "生命商品 I",
			"illustration_key": "",
			"play_state": "available" if available else "disabled",
			"disabled_reason_id": "none" if available else "facility-target-unavailable",
			"legal_target_summary": TARGET_KIND,
			"game_action_offer": offer,
			"source_revision": revision,
		}],
		"bound_actions": [],
		"normal_count": 0,
		"normal_limit": PROJECTION.CARD_LIMIT,
		"commodity_count": 1,
		"commodity_limit": PROJECTION.CARD_LIMIT,
		"shared_capacity_count": 1,
		"shared_capacity_limit": PROJECTION.CARD_LIMIT,
	})


func _offer(revision: int, region_id: String, available: bool) -> Dictionary:
	var bindings: Array = [
		{"target_role_id": "card_instance_id", "target_id": CARD_INSTANCE_ID},
		{"target_role_id": "hand_slot_id", "target_id": "hand.slot.0"},
	]
	if not region_id.is_empty():
		bindings.append({"target_role_id": "region_id", "target_id": region_id})
	return OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": INTENT.ACTION_CARD_PLAY,
		"action_family_id": INTENT.FAMILY_CARD_PLAY,
		"source_revision": revision,
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "viewer_private",
			"target_kind_id": "stable-ids",
			"target_bindings": bindings,
			"requires_target": true,
		},
		"legality_state": "available" if available else "disabled",
		"disabled_reason_id": "none" if available else "facility-target-unavailable",
		"cost_spec": {"cost_kind_id": "domain-owned", "amount_units": 0, "resource_id": "none"},
		"requirement_spec": {"requirement_ids": ["domain-legality"], "source_revision_required": true},
		"consequence_spec": {"committed_effect_refs": [], "refresh_scope": "full"},
		"presentation_token_ids": ["action.card.play", "feedback.card.play"],
	})


func _actor_context() -> GameplayActorAuthorizationContext:
	return GameplayActorAuthorizationContext.from_dictionary({
		"schema_version": GameplayActorAuthorizationContext.SCHEMA_VERSION,
		"request_id": "alpha04-target-context",
		"authorized": true,
		"reason_code": "authorized",
		"viewer_index": 0,
		"authorized_actor_player_index": 0,
		"authorization_revision": 9,
		"session_id": "alpha04-target-session",
		"session_revision": 3,
		"source_surface": &"game_screen",
		"issued_at_operation_revision": 1,
	})


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("PLAYER_CARD_DOCK_TARGET_MODE_GAME_SCREEN_INTEGRATION_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("PLAYER_CARD_DOCK_TARGET_MODE_GAME_SCREEN_INTEGRATION_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
