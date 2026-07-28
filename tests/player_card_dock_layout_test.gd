extends SceneTree

const DOCK_SCENE := preload("res://scenes/ui/table/PlayerCardDock.tscn")
const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dock := DOCK_SCENE.instantiate() as SpaceSyndicatePlayerCardDock
	root.add_child(dock)
	dock.bind_viewer(0, 5)
	await process_frame

	var revision := 1
	for normal_count in [0, 1, 5]:
		var projection := _projection(revision, normal_count, 0, 0, PROJECTION.CAPACITY_MODE_SHARED_V06)
		_expect(dock.apply_projection(projection), "V0.6 normal-card layout applies for %d cards" % normal_count)
		await process_frame
		var debug := dock.debug_snapshot()
		_expect(int(debug.get("normal_card_count", -1)) == normal_count, "normal-card target count matches %d" % normal_count)
		_expect(int(debug.get("commodity_card_count", -1)) == 0 and int(debug.get("bound_action_count", -1)) == 0, "unrequested pools remain empty")
		revision += 1

	var mixed := _projection(revision, 2, 3, 0, PROJECTION.CAPACITY_MODE_SHARED_V06)
	_expect(dock.apply_projection(mixed), "mixed V0.6 normal and commodity pools apply at the shared limit")
	await process_frame
	var mixed_debug := dock.debug_snapshot()
	_expect(int(mixed_debug.get("normal_card_count", -1)) == 2 		and int(mixed_debug.get("commodity_card_count", -1)) == 3, "mixed pools render their exact typed counts")
	var capacity_label := dock.find_child("CardDockCapacitySummary", true, false) as Label
	_expect(capacity_label != null and capacity_label.text.contains("共享容量") 		and capacity_label.text.contains("5 / 5"), "V0.6 copy reports one truthful shared five-card capacity")

	revision += 1
	var with_bound := _projection(revision, 1, 1, 3, PROJECTION.CAPACITY_MODE_SHARED_V06)
	_expect(dock.apply_projection(with_bound), "bound-action contract rows render beside counted V0.6 cards")
	await process_frame
	var bound_debug := dock.debug_snapshot()
	_expect(int(bound_debug.get("bound_action_count", -1)) == 3 		and int((with_bound.get("shared_capacity_count", -1))) == 2, "bound actions render without consuming shared capacity")
	var bound_title := dock.find_child("BoundActionTitle", true, false) as Label
	_expect(bound_title != null and bound_title.text.contains("不占上限"), "bound-action lane explicitly states zero capacity cost")
	var normal_host := dock.find_child("NormalHandCards", true, false)
	var production_card := normal_host.get_child(0) as Control if normal_host != null and normal_host.get_child_count() > 0 else null
	var production_card_data: Dictionary = production_card.call("get_card_data") as Dictionary \
		if production_card != null and production_card.has_method("get_card_data") else {}
	_expect(str(production_card_data.get("presentation", "")) == "mini_hand", "production Dock CardFace uses the recognized compact MiniCard contract")
	_expect(production_card != null and production_card.get_combined_minimum_size().y <= 160.0, "production Dock MiniCard cannot expand back to the full-card height")

	for size in [Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = size
		dock.position = Vector2.ZERO
		dock.size = Vector2(size.x, 190)
		await process_frame
		_expect(dock.get_rect().size.x <= float(size.x) 			and dock.get_rect().size.y >= 180.0, "Dock fits the %dx%d production width without vertical collapse" % [size.x, size.y])
		_expect(_all_cards_focusable(dock), "all visible cards remain keyboard-focusable at %dx%d" % [size.x, size.y])

	revision += 1
	var independent := _projection(revision, 5, 5, 2, PROJECTION.CAPACITY_MODE_INDEPENDENT_V07)
	_expect(dock.apply_projection(independent), "same Dock accepts the future V0.7 independent-capacity projection")
	await process_frame
	_expect(capacity_label.text.contains("独立容量") 		and capacity_label.text.contains("普通 5 / 5") 		and capacity_label.text.contains("商品 5 / 5"), "future mode changes capacity copy without redesigning the Dock")
	_expect(int(dock.debug_snapshot().get("visible_card_count", -1)) == 12, "independent reference mode renders ten counted cards plus two zero-cost bound actions")

	var wrong_viewer := _projection(revision + 1, 1, 0, 0, PROJECTION.CAPACITY_MODE_SHARED_V06, 1)
	_expect(not dock.apply_projection(wrong_viewer), "wrong-viewer layout projection fails closed")
	dock.bind_viewer(0, 6)
	_expect(not dock.apply_projection(independent), "stale authorization revision fails closed immediately")
	_expect(dock.debug_snapshot().get("normal_card_count", -1) == 0, "viewer rebind clears previously visible private cards")

	dock.queue_free()
	await process_frame

	var screen := GAME_SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	root.add_child(screen)
	var production_dock := screen.find_child("PlayerCardDock", true, false) as SpaceSyndicatePlayerCardDock
	production_dock.bind_viewer(0, 5)
	_expect(production_dock.apply_projection(_projection(revision + 2, 1, 1, 0, PROJECTION.CAPACITY_MODE_SHARED_V06)), "production GameScreen accepts the compact mixed-card layout fixture")
	for physical_size in [Vector2i(1366, 768), Vector2i(1920, 1080)]:
		var effective_size := Vector2i(ceili(960.0 * float(physical_size.x) / float(physical_size.y)), 960)
		root.size = effective_size
		await process_frame
		await process_frame
		var dock_bottom := production_dock.global_position.y + production_dock.size.y
		_expect(dock_bottom <= float(effective_size.y) + 0.5, "production GameScreen keeps the complete Dock inside physical %dx%d / expanded viewport %dx%d (bottom=%.1f height=%.1f minimum=%.1f)" % [physical_size.x, physical_size.y, effective_size.x, effective_size.y, dock_bottom, production_dock.size.y, production_dock.get_combined_minimum_size().y])
		_expect(production_dock.size.y >= production_dock.get_combined_minimum_size().y, "production Dock receives its full compact minimum height at physical %dx%d" % [physical_size.x, physical_size.y])
	screen.queue_free()
	await process_frame
	_finish()


func _projection(
	revision: int,
	normal_count: int,
	commodity_count: int,
	bound_count: int,
	capacity_mode: String,
	viewer_index := 0
) -> Dictionary:
	var normal_cards: Array = []
	var commodity_cards: Array = []
	var bound_actions: Array = []
	for index in range(normal_count):
		var offer := _offer(index, revision, true)
		normal_cards.append({
			"card_instance_id": "card.instance.normal-%d-%d" % [revision, index],
			"card_semantic_id": "card.normal.%d" % index,
			"slot_id": "hand.slot.%d" % index,
			"display_name": ("超长可读正常牌名称 %d 运输与市场联动" % index) if index == 0 else "正常牌 %d" % index,
			"illustration_key": "",
			"category_id": "ordinary",
			"facility_kind": "none",
			"industry_id": "life",
			"rank": 1,
			"play_state": "available",
			"disabled_reason_id": "none",
			"disabled_reason_text": "可通过正式行动入口提交。",
			"game_action_offer": offer,
			"source_revision": revision,
		})
	for index in range(commodity_count):
		var slot := normal_count + index
		var offer := _offer(slot, revision, true)
		commodity_cards.append({
			"commodity_card_instance_id": "card.instance.commodity-%d-%d" % [revision, index],
			"card_semantic_id": "commodity.life.%d" % index,
			"slot_id": "hand.slot.%d" % slot,
			"commodity_id": "commodity.life",
			"color_id": "life",
			"level": (index % 4) + 1,
			"base_units": (index % 4) + 1,
			"display_name": "生命商品 %d" % (index + 1),
			"illustration_key": "",
			"play_state": "available",
			"disabled_reason_id": "none",
			"legal_target_summary": "same_industry_factory_or_market",
			"game_action_offer": offer,
			"source_revision": revision,
		})
	for index in range(bound_count):
		var offer := _offer(normal_count + commodity_count + index, revision, true)
		bound_actions.append({
			"bound_action_instance_id": "card.instance.bound-%d-%d" % [revision, index],
			"action_semantic_id": "bound.action.%d" % index,
			"source_entity_id": "monster.%d" % (index + 1),
			"source_entity_kind": "monster",
			"source_display_name": "怪兽 %d" % (index + 1),
			"display_name": "绑定行动 %d" % (index + 1),
			"illustration_key": "",
			"action_class": "monster-bound-action",
			"cooldown": 0,
			"charges": -1,
			"enabled": true,
			"disabled_reason_id": "none",
			"game_action_offer": offer,
			"source_revision": revision,
		})
	var shared_limit := PROJECTION.CARD_LIMIT if capacity_mode == PROJECTION.CAPACITY_MODE_SHARED_V06 		else PROJECTION.CARD_LIMIT * 2
	return PROJECTION.build({
		"schema_version": PROJECTION.SCHEMA_VERSION,
		"viewer_index": viewer_index,
		"actor_id": "player.%d" % viewer_index,
		"authorization_revision": 5,
		"source_revision": revision,
		"runtime_ruleset_id": PROJECTION.RUNTIME_RULESET_V06 			if capacity_mode == PROJECTION.CAPACITY_MODE_SHARED_V06 else PROJECTION.RUNTIME_RULESET_V07,
		"capacity_mode": capacity_mode,
		"visibility_scope": "viewer_private",
		"normal_cards": normal_cards,
		"commodity_cards": commodity_cards,
		"bound_actions": bound_actions,
		"normal_count": normal_count,
		"normal_limit": PROJECTION.CARD_LIMIT,
		"commodity_count": commodity_count,
		"commodity_limit": PROJECTION.CARD_LIMIT,
		"shared_capacity_count": normal_count + commodity_count,
		"shared_capacity_limit": shared_limit,
	})


func _offer(slot: int, revision: int, available: bool) -> Dictionary:
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
				{"target_role_id": "card_instance_id", "target_id": "card.instance.fixture-%d-%d" % [revision, slot]},
				{"target_role_id": "hand_slot_id", "target_id": "hand.slot.%d" % slot},
			],
			"requires_target": true,
		},
		"legality_state": "available" if available else "disabled",
		"disabled_reason_id": "none" if available else "blocked",
		"cost_spec": {"cost_kind_id": "domain-owned", "amount_units": 0, "resource_id": "none"},
		"requirement_spec": {"requirement_ids": ["domain-legality"], "source_revision_required": true},
		"consequence_spec": {"committed_effect_refs": [], "refresh_scope": "full"},
		"presentation_token_ids": ["action.card.play", "feedback.card.play"],
	})


func _all_cards_focusable(dock: Node) -> bool:
	var cards := dock.find_children("CardFace", "", true, false)
	if cards.is_empty():
		return false
	for card_variant in cards:
		var card := card_variant as Control
		if card == null or not card.visible or card.focus_mode != Control.FOCUS_ALL:
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("PLAYER_CARD_DOCK_LAYOUT_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("PLAYER_CARD_DOCK_LAYOUT_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
