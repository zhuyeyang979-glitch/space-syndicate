extends SceneTree

const DOCK_SCENE := preload("res://scenes/ui/table/PlayerCardDock.tscn")
const PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const SERVICE := preload("res://scripts/presentation/player_card_dock_projection_service.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_projection_revision_lock()
	_test_projection_service_slot_order_independence()
	await _test_three_pool_target_and_action_entry()
	_finish()


func _test_projection_revision_lock() -> void:
	for pool_id in [&"normal_cards", &"commodity_cards", &"bound_actions"]:
		var projection := _projection(10, pool_id, "card.instance.revision-%s" % pool_id)
		_expect(
			bool(PROJECTION.validation_report(projection).get("valid", false)),
			"%s fixture projection validates" % pool_id
		)
		var stale_rows := projection.duplicate(true)
		stale_rows.erase("projection_fingerprint")
		stale_rows["source_revision"] = 11
		_expect(
			PROJECTION.build(stale_rows).is_empty(),
			"%s rows cannot be relabeled as a newer root projection" % pool_id
		)


func _test_projection_service_slot_order_independence() -> void:
	var offer_zero := _offer(20, "card.instance.order-zero", 0)
	var offer_one := _offer(20, "card.instance.order-one", 1)
	var private_hand := [
		{"slot_index": 0, "card_id": "facility.audit.zero", "rank": 1, "kind": "facility"},
		{"slot_index": 1, "card_id": "facility.audit.one", "rank": 1, "kind": "facility"},
	]
	var sources := [
		_source(1, "facility.audit.one", offer_one),
		_source(0, "facility.audit.zero", offer_zero),
	]
	var viewmodels := [
		_viewmodel(0, "审计设施零", offer_zero),
		_viewmodel(1, "审计设施一", offer_one),
	]
	var projection := SERVICE.new().compose_shared_v06(
		0,
		"player.0",
		4,
		20,
		private_hand,
		sources,
		viewmodels
	)
	_expect(
		bool(PROJECTION.validation_report(projection).get("valid", false))
			and (projection.get("normal_cards", []) as Array).size() == 2,
		"typed slot joins do not depend on source-array insertion order"
	)


func _test_three_pool_target_and_action_entry() -> void:
	var dock := DOCK_SCENE.instantiate() as SpaceSyndicatePlayerCardDock
	root.add_child(dock)
	dock.bind_viewer(0, 4)
	await process_frame

	var three_pool := _three_pool_projection(30)
	_expect(dock.apply_projection(three_pool), "one authorized projection applies all three pools")
	await process_frame
	var debug := dock.debug_snapshot()
	var capacity_label := dock.find_child("CardDockCapacitySummary", true, false) as Label
	var bound_title := dock.find_child("BoundActionTitle", true, false) as Label
	_expect(
		int(debug.get("normal_card_count", -1)) == 1
			and int(debug.get("commodity_card_count", -1)) == 1
			and int(debug.get("bound_action_count", -1)) == 1,
		"normal, commodity and bound-action lanes render one card each"
	)
	_expect(
		capacity_label != null and capacity_label.text.contains("共享容量")
			and capacity_label.text.contains("2 / 5"),
		"V0.6 label counts normal plus commodity once against the shared limit"
	)
	_expect(
		bound_title != null and bound_title.text.contains("不占上限"),
		"bound-action lane states its zero capacity cost"
	)

	var movable_id := "card.instance.pool-move"
	_expect(dock.apply_projection(_projection(31, &"normal_cards", movable_id)), "movable card begins in the normal lane")
	await process_frame
	_expect(dock.apply_projection(_projection(32, &"bound_actions", movable_id)), "same instance can move to the bound-action lane")
	await process_frame
	_expect(dock.apply_projection(_projection(33, &"bound_actions", movable_id)), "later bound-action revision applies")
	await process_frame
	debug = dock.debug_snapshot()
	_expect(
		int(debug.get("normal_card_count", -1)) == 0
			and int(debug.get("bound_action_count", -1)) == 1,
		"cross-pool migration preserves one cached CardFace without duplication"
	)

	var keyboard_id := "card.instance.keyboard-action"
	_expect(dock.apply_projection(_projection(34, &"normal_cards", keyboard_id)), "keyboard action fixture applies")
	await process_frame
	var normal_host := dock.find_child("NormalHandCards", true, false)
	var card := normal_host.get_child(0) as Control if normal_host != null and normal_host.get_child_count() == 1 else null
	var submissions: Array[Dictionary] = []
	dock.game_action_offer_requested.connect(func(
		offer: Dictionary,
		submission_kind: String,
		parameters: Dictionary,
		target_overrides: Dictionary
	) -> void:
		submissions.append({
			"offer": offer.duplicate(true),
			"submission_kind": submission_kind,
			"parameters": parameters.duplicate(true),
			"target_overrides": target_overrides.duplicate(true),
		})
	)
	var echo := InputEventKey.new()
	echo.keycode = KEY_ENTER
	echo.pressed = true
	echo.echo = true
	dock.call("_on_card_gui_input", echo, &"normal_cards", card)
	_expect(submissions.is_empty() and str(dock.debug_snapshot().get("selected_identity", "")).is_empty(), "keyboard echo is inert")
	var confirm := InputEventAction.new()
	confirm.action = &"ui_accept"
	confirm.pressed = true
	dock.call("_on_card_gui_input", confirm, &"normal_cards", card)
	_expect(
		submissions.is_empty()
			and str(dock.debug_snapshot().get("selected_identity", "")) == keyboard_id,
		"first keyboard confirm selects without submitting"
	)
	dock.call("_on_card_gui_input", confirm, &"normal_cards", card)
	_expect(
		submissions.size() == 1
			and str(submissions[0].get("submission_kind", "")) == "human_click"
			and str(OFFER.target_ids(submissions[0].get("offer", {}) as Dictionary).get("card_instance_id", "")) == keyboard_id,
		"second keyboard confirm emits exactly one unchanged typed Action Spine offer"
	)
	debug = dock.debug_snapshot()
	_expect(
		int(debug.get("action_entry_count", 0)) == 1
			and not bool(debug.get("mutates_gameplay", true))
			and not bool(debug.get("reads_world_state", true)),
		"Dock exposes one signal entry and owns no gameplay or world state"
	)

	dock.queue_free()
	await process_frame


func _three_pool_projection(revision: int) -> Dictionary:
	var normal := _row_for_pool(&"normal_cards", revision, "card.instance.normal-a", 0)
	var commodity := _row_for_pool(&"commodity_cards", revision, "card.instance.commodity-a", 1)
	var bound := _row_for_pool(&"bound_actions", revision, "card.instance.bound-a", 2)
	return _build_projection(revision, [normal], [commodity], [bound])


func _projection(revision: int, pool_id: StringName, identity: String) -> Dictionary:
	var normal: Array = []
	var commodity: Array = []
	var bound: Array = []
	var row := _row_for_pool(pool_id, revision, identity, 0)
	match pool_id:
		&"normal_cards":
			normal.append(row)
		&"commodity_cards":
			commodity.append(row)
		&"bound_actions":
			bound.append(row)
	return _build_projection(revision, normal, commodity, bound)


func _build_projection(revision: int, normal: Array, commodity: Array, bound: Array) -> Dictionary:
	return PROJECTION.build({
		"schema_version": PROJECTION.SCHEMA_VERSION,
		"viewer_index": 0,
		"actor_id": "player.0",
		"authorization_revision": 4,
		"source_revision": revision,
		"runtime_ruleset_id": PROJECTION.RUNTIME_RULESET_V06,
		"capacity_mode": PROJECTION.CAPACITY_MODE_SHARED_V06,
		"visibility_scope": "viewer_private",
		"normal_cards": normal,
		"commodity_cards": commodity,
		"bound_actions": bound,
		"normal_count": normal.size(),
		"normal_limit": PROJECTION.CARD_LIMIT,
		"commodity_count": commodity.size(),
		"commodity_limit": PROJECTION.CARD_LIMIT,
		"shared_capacity_count": normal.size() + commodity.size(),
		"shared_capacity_limit": PROJECTION.CARD_LIMIT,
	})


func _row_for_pool(pool_id: StringName, revision: int, identity: String, slot: int) -> Dictionary:
	var offer := _offer(revision, identity, slot)
	match pool_id:
		&"normal_cards":
			return {
				"card_instance_id": identity,
				"card_semantic_id": "card.normal.audit",
				"slot_id": "hand.slot.%d" % slot,
				"display_name": "审计普通牌",
				"illustration_key": "",
				"category_id": "ordinary",
				"facility_kind": "none",
				"industry_id": "none",
				"rank": 1,
				"play_state": "available",
				"disabled_reason_id": "none",
				"disabled_reason_text": "可通过正式行动入口提交。",
				"game_action_offer": offer,
				"source_revision": revision,
			}
		&"commodity_cards":
			return {
				"commodity_card_instance_id": identity,
				"card_semantic_id": "commodity.life.audit",
				"slot_id": "hand.slot.%d" % slot,
				"commodity_id": "commodity.life",
				"color_id": "life",
				"level": 1,
				"base_units": 1,
				"display_name": "审计商品牌",
				"illustration_key": "",
				"play_state": "available",
				"disabled_reason_id": "none",
				"legal_target_summary": "same_industry_factory_or_market",
				"game_action_offer": offer,
				"source_revision": revision,
			}
		&"bound_actions":
			return {
				"bound_action_instance_id": identity,
				"action_semantic_id": "bound.action.audit",
				"source_entity_id": "monster.1",
				"source_entity_kind": "monster",
				"source_display_name": "审计怪兽",
				"display_name": "审计绑定行动",
				"illustration_key": "",
				"action_class": "monster-bound-action",
				"cooldown": 0,
				"charges": -1,
				"enabled": true,
				"disabled_reason_id": "none",
				"game_action_offer": offer,
				"source_revision": revision,
			}
	return {}


func _offer(revision: int, identity: String, slot: int) -> Dictionary:
	return OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": INTENT.ACTION_CARD_PLAY,
		"action_family_id": INTENT.FAMILY_CARD_PLAY,
		"source_revision": revision,
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "viewer_private",
			"target_kind_id": "stable-ids",
			"target_bindings": [
				{"target_role_id": "card_instance_id", "target_id": identity},
				{"target_role_id": "hand_slot_id", "target_id": "hand.slot.%d" % slot},
			],
			"requires_target": true,
		},
		"legality_state": "available",
		"disabled_reason_id": "none",
		"cost_spec": {"cost_kind_id": "domain-owned", "amount_units": 0, "resource_id": "none"},
		"requirement_spec": {"requirement_ids": ["domain-legality"], "source_revision_required": true},
		"consequence_spec": {"committed_effect_refs": [], "refresh_scope": "full"},
		"presentation_token_ids": ["action.card.play", "feedback.card.play"],
	})


func _source(slot: int, semantic_id: String, offer: Dictionary) -> Dictionary:
	return {
		"slot": slot,
		"card": {"skill": {
			"name": semantic_id,
			"card_id": semantic_id,
			"display_name": semantic_id,
			"kind": "facility",
			"rank": 1,
			"machine": {
				"card_id": semantic_id,
				"family_id": semantic_id,
				"category_id": "facility",
				"rank": 1,
				"counts_toward_hand_limit": true,
				"target_kind": "none",
				"effect_kind": "",
				"effect_payload": {},
			},
		}},
		"eligibility": {"allowed": true},
		"game_action_offer": offer.duplicate(true),
	}


func _viewmodel(slot: int, display_name: String, offer: Dictionary) -> Dictionary:
	return {
		"slot": slot,
		"name": display_name,
		"kind": "facility",
		"illustration_key": "",
		"actions": [{"game_action_offer": offer.duplicate(true)}],
	}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("PLAYER_CARD_DOCK_DOCK_AUDIT_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("PLAYER_CARD_DOCK_DOCK_AUDIT_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
