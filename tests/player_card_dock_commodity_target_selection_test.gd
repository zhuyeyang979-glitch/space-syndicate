extends SceneTree

const DOCK_SCENE := preload("res://scenes/ui/table/PlayerCardDock.tscn")
const PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

const CARD_INSTANCE_ID := "card.instance.commodity-alpha04"
const TARGET_KIND := "same_industry_factory_or_market"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dock := DOCK_SCENE.instantiate() as SpaceSyndicatePlayerCardDock
	root.add_child(dock)
	dock.bind_viewer(0, 9)
	await process_frame
	var emitted: Array[Dictionary] = []
	dock.game_action_offer_requested.connect(func(
		offer: Dictionary,
		submission_kind: String,
		_parameters: Dictionary,
		_target_overrides: Dictionary
	) -> void:
		emitted.append({
			"offer": offer.duplicate(true),
			"submission_kind": submission_kind,
		})
	)

	var untargeted := _projection(1, "", false)
	_expect(dock.apply_projection(untargeted), "typed commodity projection applies before a region is selected")
	_expect(dock.begin_target_selection(CARD_INSTANCE_ID, TARGET_KIND), "commodity card enters scene-owned target-selection mode")
	_expect(dock.target_selection_active(), "target-selection mode is visible in the production target")
	_expect(dock.submit_target_selection("region.alpha") == "waiting", "Dock waits for an authoritative offer bound to the selected region")
	_expect(emitted.is_empty(), "waiting projection emits no gameplay action")

	var targeted := _projection(2, "region.alpha", true)
	_expect(dock.apply_projection(targeted), "newer projection carries the authoritative legal target")
	_expect(dock.submit_target_selection("region.alpha") == "submitted", "matching authoritative offer submits through the typed action signal")
	_expect(emitted.size() == 1 \
		and str(emitted[0].get("submission_kind", "")) == "human_click" \
		and str(OFFER.target_ids(emitted[0].get("offer", {}) as Dictionary).get("region_id", "")) == "region.alpha", "submission preserves the authoritative region binding")
	_expect(not dock.target_selection_active(), "successful submission closes target-selection mode")
	_expect(dock.submit_target_selection("region.alpha") == "invalid" and emitted.size() == 1, "completed mode cannot submit twice")

	_expect(dock.begin_target_selection(CARD_INSTANCE_ID, TARGET_KIND), "commodity card can start a later target selection")
	var blocked := _projection(3, "region.beta", false)
	_expect(dock.apply_projection(blocked), "blocked authoritative target projection applies")
	_expect(dock.submit_target_selection("region.beta") == "blocked", "unavailable authoritative offer blocks without UI legality calculation")
	_expect(emitted.size() == 1 and dock.target_selection_active(), "blocked target emits nothing and lets the player choose another region")

	var stale := _projection(2, "region.alpha", true)
	_expect(not dock.apply_projection(stale), "stale target projection is rejected")
	var conflicting := _projection(3, "region.gamma", true)
	_expect(not dock.apply_projection(conflicting), "same revision with a conflicting target is rejected")
	var debug := dock.debug_snapshot()
	_expect(int(debug.get("stale_count", 0)) == 1 \
		and int(debug.get("conflict_count", 0)) == 1 \
		and not bool(debug.get("mutates_gameplay", true)) \
		and not bool(debug.get("reads_world_state", true)), "target remains a read-only exact-once presentation component")

	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(screen_source.contains("request_district_selection(district_index, source_surface)") \
		and screen_source.contains("submit_target_selection(_pending_card_target_region_id)") \
		and screen_source.contains("region_supply_popup.close_popup()") \
		and not screen_source.contains("/root/Main") \
		and not screen_source.contains("current_scene"), "production GameScreen coordinates typed district selection, popup close, and offer submit without Main")

	dock.queue_free()
	await process_frame
	_finish()


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


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("PLAYER_CARD_DOCK_COMMODITY_TARGET_SELECTION_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("PLAYER_CARD_DOCK_COMMODITY_TARGET_SELECTION_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
