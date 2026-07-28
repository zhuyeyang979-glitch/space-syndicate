extends SceneTree

const DOCK_SCENE := preload("res://scenes/ui/table/PlayerCardDock.tscn")
const PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

const ILLUSTRATION_KEY := "alpha01_art_001"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dock := DOCK_SCENE.instantiate() as SpaceSyndicatePlayerCardDock
	root.add_child(dock)
	dock.bind_viewer(0, 3)
	await process_frame
	var projection := _projection()
	_expect(bool(PROJECTION.validation_report(projection).get("valid", false)), "fixture projection validates")
	_expect(dock.apply_projection(projection), "production PlayerCardDock accepts its typed projection")
	await process_frame
	var card := dock.find_child("CardFace", true, false) as SpaceSyndicateCardFace
	_expect(card != null, "normal pool renders one production CardFace")
	if card != null:
		var card_data := card.get_card_data()
		_expect(
			str(card_data.get("illustration_key", "")) == ILLUSTRATION_KEY,
			"PlayerCardDock forwards the authored illustration key without replacement"
		)
		_expect(
			bool(card.get_meta("authored_illustration_active", false))
				and str(card.get_meta("illustration_fallback_reason", "")).is_empty(),
			"CardFace activates the approved authored illustration"
		)
	dock.queue_free()
	await process_frame
	_finish()


func _projection() -> Dictionary:
	var offer := OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": INTENT.ACTION_CARD_PLAY,
		"action_family_id": INTENT.FAMILY_CARD_PLAY,
		"source_revision": 7,
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "viewer_private",
			"target_kind_id": "stable-ids",
			"target_bindings": [
				{"target_role_id": "card_instance_id", "target_id": "card.instance.alpha04-art"},
				{"target_role_id": "hand_slot_id", "target_id": "hand.slot.0"},
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
	return PROJECTION.build({
		"schema_version": PROJECTION.SCHEMA_VERSION,
		"viewer_index": 0,
		"actor_id": "player.0",
		"authorization_revision": 3,
		"source_revision": 7,
		"runtime_ruleset_id": PROJECTION.RUNTIME_RULESET_V06,
		"capacity_mode": PROJECTION.CAPACITY_MODE_SHARED_V06,
		"visibility_scope": "viewer_private",
		"normal_cards": [{
			"card_instance_id": "card.instance.alpha04-art",
			"card_semantic_id": "facility.factory.life.rank-1",
			"slot_id": "hand.slot.0",
			"display_name": "生命工厂",
			"illustration_key": ILLUSTRATION_KEY,
			"category_id": "facility",
			"facility_kind": "factory",
			"industry_id": "life",
			"rank": 1,
			"play_state": "available",
			"disabled_reason_id": "none",
			"disabled_reason_text": "可通过正式行动入口提交。",
			"game_action_offer": offer,
			"source_revision": 7,
		}],
		"commodity_cards": [],
		"bound_actions": [],
		"normal_count": 1,
		"normal_limit": PROJECTION.CARD_LIMIT,
		"commodity_count": 0,
		"commodity_limit": PROJECTION.CARD_LIMIT,
		"shared_capacity_count": 1,
		"shared_capacity_limit": PROJECTION.CARD_LIMIT,
	})


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04_PLAYER_CARD_DOCK_TARGET_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("ALPHA04_PLAYER_CARD_DOCK_TARGET_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
