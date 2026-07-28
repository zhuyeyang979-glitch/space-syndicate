extends SceneTree

const POPUP_SCENE := preload("res://scenes/ui/table/RegionSupplyPopup.tscn")
const SNAPSHOT_SERVICE_SCENE := preload("res://scenes/runtime/DistrictSupplySnapshotService.tscn")
const REGION_SUPPLY_SCENE := preload("res://scenes/runtime/RegionSupplyRuntimeController.tscn")
const VIEWER_QUERY_SCENE := preload("res://scenes/runtime/presentation/DistrictSupplyViewerQueryPort.tscn")
const ENVELOPE := preload("res://scripts/presentation/district_supply_presentation_envelope_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rack_owner := REGION_SUPPLY_SCENE.instantiate() as RegionSupplyRuntimeController
	var viewer_query := VIEWER_QUERY_SCENE.instantiate() as DistrictSupplyViewerQueryPort
	root.add_child(rack_owner)
	root.add_child(viewer_query)
	var rack_configure := rack_owner.configure(7331, [{
		"region_id": "region.fixture",
		"region_index": 0,
		"display_name": "测试区",
		"terrain": "land",
	}], [{
		"card_id": "facility.fixture.rank-1",
		"family_id": "facility.fixture",
		"card_type": "facility",
		"rank": 1,
		"name": "facility.fixture.rank-1",
		"display_name": "测试设施",
		"price_cash": 120,
		"target_type": "district",
		"effect_text": "测试效果",
		"requirement_text": "测试条件",
		"facility_kind": "factory",
		"industry_id": "life",
		"route_tags": [],
		"art_key": "",
	}], 1)
	viewer_query.set("_region_supply", rack_owner)
	var owner_snapshot := rack_owner.public_rack_snapshot("region.fixture")
	var rack_row := viewer_query.call("_rack_row", "region.fixture") as Dictionary
	_expect(bool(rack_configure.get("configured", false)), "authoritative rack owner fixture configures")
	_expect(
		int(rack_row.get("rack_source_version", 0)) \
			== int(owner_snapshot.get("state_revision", -1))
			and int(rack_row.get("rack_source_version", 0)) > 0,
		"viewer query copies the owner's monotonic numeric state revision without parsing rack identity text"
	)
	var snapshot_service := SNAPSHOT_SERVICE_SCENE.instantiate() as DistrictSupplySnapshotService
	root.add_child(snapshot_service)
	var projected_quote := _projected_market_entry(snapshot_service, "quote")
	var projected_purchase := _projected_market_entry(snapshot_service, "purchase")
	var projected_blocked := _projected_market_entry(snapshot_service, "blocked")
	_expect(str((projected_quote.get("purchase_state", {}) as Dictionary).get("interaction_state", "")) == "quote", "snapshot service projects the quote lifecycle state")
	_expect(str((projected_purchase.get("purchase_state", {}) as Dictionary).get("interaction_state", "")) == "purchase", "snapshot service projects the purchase lifecycle state")
	_expect(str((projected_blocked.get("purchase_state", {}) as Dictionary).get("interaction_state", "")) == "blocked", "snapshot service projects unavailable listings as blocked")
	var popup := POPUP_SCENE.instantiate() as SpaceSyndicateRegionSupplyPopup
	root.add_child(popup)
	popup.bind_viewer(0, 3)
	await process_frame
	var emitted_action_ids: Array[String] = []
	popup.game_action_offer_requested.connect(func(offer: Dictionary, _submission: String, _parameters: Dictionary, _targets: Dictionary) -> void:
		emitted_action_ids.append(str(offer.get("semantic_action_id", "")))
	)

	var quote_surface := _surface(10, "a".repeat(64), "quote")
	_expect(bool(ENVELOPE.validation_report(quote_surface).get("valid", false)), "typed quote surface validates")
	_expect(popup.apply_presentation(quote_surface, 0, 3), "quote surface applies")
	_expect(popup.request_selected_purchase(), "explicit confirm emits quote in quote state")
	_expect(emitted_action_ids == [INTENT.ACTION_DISTRICT_SUPPLY_QUOTE], "quote state emits only the typed quote offer")

	var after_quote := popup.presentation_target_snapshot()
	_expect(popup.apply_presentation(quote_surface, 0, 3), "exact duplicate is accepted idempotently")
	var after_duplicate := popup.presentation_target_snapshot()
	_expect(
		int(after_duplicate.get("apply_count", -1)) == int(after_quote.get("apply_count", -2))
			and int(after_duplicate.get("duplicate_count", 0)) == 1,
		"exact duplicate increments duplicate count without reapplying"
	)

	var purchase_surface := _surface(10, "a".repeat(64), "purchase")
	_expect(popup.apply_presentation(purchase_surface, 0, 3), "same rack version accepts a changed quote lifecycle snapshot")
	_expect(popup.request_selected_purchase(), "explicit confirm emits purchase in purchase state")
	_expect(
		emitted_action_ids == [
			INTENT.ACTION_DISTRICT_SUPPLY_QUOTE,
			INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE,
		],
		"purchase state emits only the typed purchase offer"
	)

	var blocked_surface := _surface(10, "a".repeat(64), "blocked")
	_expect(popup.apply_presentation(blocked_surface, 0, 3), "same rack version accepts a blocked lifecycle update")
	var emitted_before_blocked := emitted_action_ids.size()
	_expect(not popup.request_card_quote("fixture-card") and not popup.request_selected_purchase(), "blocked listing exposes no quote or purchase request")
	popup.call("_on_card_preview_requested", "fixture-card", "click_or_keyboard")
	popup.call("_on_card_purchase_requested", "fixture-card", "preview_button")
	_expect(emitted_action_ids.size() == emitted_before_blocked, "unavailable listing produces zero intent from every popup entrypoint")

	var next_surface := _surface(11, "b".repeat(64), "quote")
	_expect(popup.apply_presentation(next_surface, 0, 3), "newer ordered rack source version applies")
	_expect(not popup.apply_presentation(quote_surface, 0, 3), "older ordered rack source version fails closed")
	var conflict_surface := _surface(11, "c".repeat(64), "quote")
	_expect(not popup.apply_presentation(conflict_surface, 0, 3), "same district and version cannot carry a conflicting rack identity")
	var final_debug := popup.presentation_target_snapshot()
	_expect(
		int(final_debug.get("apply_count", -1)) == 4
			and int(final_debug.get("duplicate_count", -1)) == 1
			and int(final_debug.get("stale_count", -1)) == 1
			and int(final_debug.get("reject_count", -1)) == 1
			and int(final_debug.get("typed_offer_emit_count", -1)) == 2
			and int(final_debug.get("rack_source_version", -1)) == 11,
		"popup reports exact apply, duplicate, stale, reject and typed-offer counts"
	)
	popup.queue_free()
	snapshot_service.queue_free()
	viewer_query.queue_free()
	rack_owner.queue_free()
	await process_frame
	_finish()


func _projected_market_entry(
	service: DistrictSupplySnapshotService,
	interaction_state: String
) -> Dictionary:
	var source := {
		"visibility_scope": "viewer_private",
		"availability_kind": "dark" if interaction_state == "blocked" else "sunlit",
	}
	var state := {
		"label": "选择以报价" if interaction_state != "purchase" else "可购买",
		"detail": interaction_state,
		"actionable": interaction_state == "purchase",
		"requires_discard": false,
		"price": 120,
		"accent": "#22c55eff",
		"reason_code": "facility_purchase_ready" if interaction_state == "purchase" else ("source_region_dark" if interaction_state == "blocked" else "market_quote_unavailable"),
	}
	return service.call("_market_card_snapshot", {
		"card_id": "fixture-card",
		"card_name": "fixture-card",
		"display_name": "测试挂牌",
		"price": 120,
		"rank": 1,
		"rank_label": "I",
		"kind": "facility",
		"purchase_state": state,
	}, source) as Dictionary


func _surface(version: int, rack_revision: String, interaction_state: String) -> Dictionary:
	var quote_offer := _offer(INTENT.ACTION_DISTRICT_SUPPLY_QUOTE, {
		"card_id": "fixture-card",
		"region_id": "region.fixture",
	})
	var purchase_offer := _offer(INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE, {
		"card_id": "fixture-card",
		"quote_id": "quote.fixture",
		"region_id": "region.fixture",
	})
	var entry := {
		"card_id": "fixture-card",
		"card_name": "fixture-card",
		"display_name": "测试挂牌",
		"illustration_key": "",
		"selected": true,
		"actionable": interaction_state == "purchase",
		"price": 120,
		"title": "测试挂牌",
		"rank": "I",
		"rank_number": 1,
		"kind": "facility",
		"state_text": interaction_state,
		"state_tooltip": interaction_state,
		"purchase_state": {
			"interaction_state": interaction_state,
			"reason_code": "facility_purchase_ready" if interaction_state == "purchase" else ("market_quote_unavailable" if interaction_state == "quote" else "source_region_dark"),
			"actionable": interaction_state == "purchase",
			"requires_discard": false,
			"price": 120,
		},
		"quote_offer": quote_offer,
		"purchase_offer": purchase_offer,
	}
	entry["preview"] = {
		"card_id": "fixture-card",
		"card_name": "fixture-card",
		"title": "测试挂牌",
		"status_text": interaction_state,
		"action_reason_code": str((entry.get("purchase_state", {}) as Dictionary).get("reason_code", "purchase_unavailable")),
		"primary_action_id": "district_supply_preview_card" if interaction_state == "quote" else ("district_supply_purchase_card" if interaction_state == "purchase" else ""),
		"buy_text": interaction_state,
		"buy_enabled": interaction_state != "blocked",
		"purchase_state": (entry.get("purchase_state", {}) as Dictionary).duplicate(true),
		"quote_offer": quote_offer,
		"purchase_offer": purchase_offer,
	}
	return {
		"schema_version": 1,
		"visible": true,
		"reason_code": "district_supply_surface_ready",
		"district_index": 0,
		"rack_source_revision": rack_revision,
		"rack_source_version": version,
		"viewer_index": 0,
		"subject_player_index": 0,
		"authorization_revision": 3,
		"visibility_scope": "viewer_private",
		"snapshot": {
			"visibility_scope": "viewer_private",
			"title": "区域牌架",
			"cards": [entry],
			"preview": (entry.get("preview", {}) as Dictionary).duplicate(true),
			"close_offer": _offer(INTENT.ACTION_DISTRICT_SUPPLY_CLOSE, {}),
		},
	}


func _offer(action_id: String, target_ids: Dictionary) -> Dictionary:
	var bindings: Array = []
	for role_variant in target_ids.keys():
		bindings.append({"target_role_id": str(role_variant), "target_id": str(target_ids.get(role_variant, ""))})
	return OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": action_id,
		"action_family_id": INTENT.action_family_id(action_id),
		"source_revision": 7,
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "viewer_private",
			"target_kind_id": "stable-ids",
			"target_bindings": bindings,
			"requires_target": not bindings.is_empty(),
		},
		"legality_state": "available",
		"disabled_reason_id": "none",
		"cost_spec": {"cost_kind_id": "domain-owned", "amount_units": 0, "resource_id": "none"},
		"requirement_spec": {"requirement_ids": ["domain-legality"], "source_revision_required": true},
		"consequence_spec": {"committed_effect_refs": [], "refresh_scope": "full"},
		"presentation_token_ids": ["action.district-supply", "feedback.district-supply"],
	})


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04_REGION_SUPPLY_POPUP_TARGET_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("ALPHA04_REGION_SUPPLY_POPUP_TARGET_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
