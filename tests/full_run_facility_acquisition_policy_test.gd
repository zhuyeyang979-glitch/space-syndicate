extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")
const GameActionReceiptScript := preload("res://scripts/semantic/game_action_receipt_v1.gd")
const PRODUCT_INDUSTRY_CATALOG: ProductIndustryCatalogResource = preload("res://resources/content/product_industry_catalog_v05.tres")


class FakeInfrastructureController extends Node:
	var revision := 1
	var regions: Array = []
	var facilities: Array = []

	func regions_snapshot() -> Array:
		return regions.duplicate(true)

	func region_snapshot(region_id: String) -> Dictionary:
		for region_variant in regions:
			if region_variant is Dictionary \
					and str((region_variant as Dictionary).get("region_id", "")) == region_id:
				return (region_variant as Dictionary).duplicate(true)
		return {}

	func public_economy_snapshot() -> Dictionary:
		var public_regions: Array = []
		for region_variant in regions:
			if region_variant is Dictionary:
				var region := region_variant as Dictionary
				public_regions.append({
					"region_id": str(region.get("region_id", "")),
					"lifecycle_state": str(region.get("lifecycle_state", "")),
				})
		return {
			"available": true,
			"revision": revision,
			"visibility_scope": "public",
			"regions": public_regions,
			"facilities": facilities.duplicate(true),
		}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var factory_energy_plan := _continuation_plan("factory", "energy", "commodity.energy", 41)
	var market_energy_plan := _continuation_plan("market", "energy", "commodity.energy", 42)
	var military_snapshot := _snapshot(
		"unit.military.submarine_fleet.rank_1",
		"unit_v06",
		"district_supply_purchase_card",
		[{
			"card_name": "unit.military.submarine_fleet.rank_1",
			"kind": "unit_v06",
			"actionable": true,
		}]
	)
	var opening_without_facility := DriverScript.district_supply_action_from_snapshot(
		military_snapshot,
		factory_energy_plan
	)
	_expect(str(opening_without_facility.get("id", "")) == "district_supply_wait", "opening strategy does not buy an unrelated visible unit")
	_expect(str(opening_without_facility.get("phase", "")).contains("facility_not_visible"), "opening strategy reports the public facility-visibility wait")

	var mixed_snapshot := military_snapshot.duplicate(true)
	(mixed_snapshot["cards"] as Array).append({
		"card_id": "facility.factory.energy.rank_1",
		"card_name": "facility.factory.energy.rank_1",
		"kind": "facility",
		"facility_kind": "factory",
		"industry_id": "energy",
		"new_target_available": true,
		"continuation_target_available": true,
		"actionable": true,
	})
	var opening_with_facility := DriverScript.district_supply_action_from_snapshot(
		mixed_snapshot,
		factory_energy_plan
	)
	_expect(str(opening_with_facility.get("id", "")) == "district_supply_preview_card", "opening strategy selects the visible facility through the Drawer action")
	_expect(str((opening_with_facility.get("payload", {}) as Dictionary).get("card_name", "")) == "facility.factory.energy.rank_1", "facility selection uses only the visible card identity")
	var no_target_snapshot := mixed_snapshot.duplicate(true)
	(no_target_snapshot["cards"] as Array)[1]["new_target_available"] = false
	(no_target_snapshot["cards"] as Array)[1]["continuation_target_available"] = false
	var opening_without_target := DriverScript.district_supply_action_from_snapshot(
		no_target_snapshot,
		factory_energy_plan
	)
	_expect(str(opening_without_target.get("id", "")) == "district_supply_wait", "opening strategy does not buy a factory before the typed query proves a new public target")
	var dark_facility := mixed_snapshot.duplicate(true)
	(dark_facility["cards"] as Array)[1]["actionable"] = false
	var dark_facility_select := DriverScript.district_supply_action_from_snapshot(
		dark_facility,
		factory_energy_plan
	)
	_expect(str(dark_facility_select.get("id", "")) == "district_supply_preview_card" and str((dark_facility_select.get("payload", {}) as Dictionary).get("card_name", "")) == "facility.factory.energy.rank_1", "a visible dark-side facility is selected for its typed public reason without submitting an invalid quote")
	var dark_selected := _snapshot(
		"facility.factory.energy.rank_1",
		"facility",
		"",
		[{"card_name": "facility.factory.energy.rank_1", "kind": "facility", "facility_kind": "factory", "industry_id": "energy", "actionable": false}]
	)
	(dark_selected["preview"] as Dictionary)["buy_enabled"] = false
	(dark_selected["preview"] as Dictionary)["action_reason_code"] = "source_region_dark"
	var dark_facility_wait := DriverScript.district_supply_action_from_snapshot(
		dark_selected,
		factory_energy_plan
	)
	_expect(str(dark_facility_wait.get("id", "")) == "district_supply_wait" and str(dark_facility_wait.get("phase", "")).contains("reason_source_region_dark"), "a selected dark-side facility waits with its qualitative typed reason")

	var quoted_facility := _snapshot(
		"facility.factory.energy.rank_1",
		"facility",
		"district_supply_purchase_card",
		[{
			"card_name": "facility.factory.energy.rank_1",
			"kind": "facility",
			"facility_kind": "factory",
			"industry_id": "energy",
			"actionable": true,
		}]
	)
	var facility_purchase := DriverScript.district_supply_action_from_snapshot(
		quoted_facility,
		factory_energy_plan
	)
	_expect(str(facility_purchase.get("id", "")) == "district_supply_purchase_card", "a quote-backed visible facility remains purchasable during opening")

	var unquoted_facility := quoted_facility.duplicate(true)
	(unquoted_facility["preview"] as Dictionary)["primary_action_id"] = "district_supply_preview_card"
	var facility_quote := DriverScript.district_supply_action_from_snapshot(
		unquoted_facility,
		factory_energy_plan
	)
	_expect(str(facility_quote.get("id", "")) == "district_supply_preview_card", "an unquoted visible facility requests its normal production quote")
	var hand_alias := quoted_facility.duplicate(true)
	(hand_alias["cards"] as Array)[0]["kind"] = "facility_v06"
	var alias_purchase := DriverScript.district_supply_action_from_snapshot(
		hand_alias,
		factory_energy_plan
	)
	_expect(str(alias_purchase.get("id", "")) == "district_supply_purchase_card", "the private hand-style facility alias remains compatible without name inference")

	var unrelated_mature_strategy := DriverScript.district_supply_action_from_snapshot(
		military_snapshot,
		market_energy_plan
	)
	_expect(str(unrelated_mature_strategy.get("id", "")) == "district_supply_wait", "a mature economy never purchases an unrelated ordinary card as continuation")
	var advancement_snapshot := {
		"visibility_scope": "viewer_private",
		"cards": [
			_advancement_card(
				"facility.market.energy.rank_1",
				"facility",
				4,
				"district_supply_preview_card",
				true,
				"market"
			),
			_advancement_card(
				"unit.military.submarine_fleet.rank_1",
				"unit_v06",
				18,
				"district_supply_preview_card",
				true
			),
			_advancement_card(
				"action.economy.public_works.rank_1",
				"action_v06",
				7,
				"district_supply_preview_card",
				true
			),
		],
	}
	var advancement_before := JSON.stringify(advancement_snapshot)
	var advancement_quote := DriverScript.district_supply_advancement_action_from_snapshot(
		advancement_snapshot
	)
	_expect(
		str(advancement_quote.get("id", "")) == "district_supply_preview_card" \
			and str(advancement_quote.get("rack_advancement_card_id", "")) \
				== "action.economy.public_works.rank_1",
		"an exhausted search quotes the cheapest legal typed non-facility without consuming the off-plan facility"
	)
	_expect(
		JSON.stringify(advancement_snapshot) == advancement_before,
		"rack advancement planning never mutates the viewer snapshot"
	)
	var localized_advancement := advancement_snapshot.duplicate(true)
	(localized_advancement["cards"] as Array).reverse()
	for card_variant in localized_advancement["cards"] as Array:
		if card_variant is Dictionary:
			(card_variant as Dictionary)["display_name"] = "本地化变化"
			(card_variant as Dictionary)["tooltip"] = "changed"
			(card_variant as Dictionary)["theme_color"] = "#ffffffff"
	_expect(
		str(DriverScript.district_supply_advancement_action_from_snapshot(
			localized_advancement
		).get("rack_advancement_card_id", "")) == "action.economy.public_works.rank_1",
		"rack advancement identity and ordering ignore row order, localization, tooltip, and color"
	)
	var quoted_advancement := advancement_snapshot.duplicate(true)
	var quoted_cards := quoted_advancement["cards"] as Array
	(quoted_cards[1] as Dictionary)["price"] = 2
	(quoted_cards[2] as Dictionary)["preview"] = {
		"primary_action_id": "district_supply_purchase_card",
		"buy_enabled": true,
		"action_reason_code": "facility_purchase_ready",
	}
	var advancement_purchase := DriverScript.district_supply_advancement_action_from_snapshot(
		quoted_advancement
	)
	_expect(
		str(advancement_purchase.get("id", "")) == "district_supply_purchase_card" \
			and str(advancement_purchase.get("rack_advancement_card_id", "")) \
				== "action.economy.public_works.rank_1",
		"a locked quote completes through purchase before a cheaper unquoted listing can replace it"
	)
	var no_legal_advancement := {
		"visibility_scope": "viewer_private",
		"cards": [
			_advancement_card(
				"facility.factory.energy.rank_1",
				"facility_v06",
				1,
				"district_supply_preview_card",
				true,
				"factory"
			),
			_advancement_card("unknown.row", "", 0, "district_supply_preview_card", true),
			_advancement_card("dark.action", "action_v06", 0, "", false),
		],
	}
	_expect(
		DriverScript.district_supply_advancement_action_from_snapshot(
			no_legal_advancement
		).is_empty() \
			and DriverScript.district_supply_advancement_action_from_snapshot({
				"visibility_scope": "public",
				"cards": (advancement_snapshot.get("cards", []) as Array).duplicate(true),
			}).is_empty(),
		"facility aliases, malformed kinds, blocked listings, and public-only snapshots fail closed"
	)
	_expect(
		not DriverScript.rack_advancement_allowed({}, 0) \
			and not DriverScript.rack_advancement_allowed({"phase": "open"}, 0) \
			and DriverScript.rack_advancement_allowed({"phase": "exhausted"}, 0) \
			and DriverScript.rack_advancement_allowed({
				"phase": "advancement_recheck",
				"advancement_epoch_active": true,
			}, 1) \
			and not DriverScript.rack_advancement_allowed({
				"phase": "advancement_recheck",
				"advancement_epoch_active": false,
			}, 1) \
			and DriverScript.rack_advancement_allowed({"phase": "exhausted"}, 7) \
			and not DriverScript.rack_advancement_allowed({"phase": "exhausted"}, 8),
		"rack advancement requires complete-search lineage, permits replacement-slot rechecks, and stops at the existing eight-rack search bound"
	)
	_expect(
		DriverScript.exhausted_matching_facility_wait_required({
			"phase": "exhausted",
			"matching_facility_seen": true,
			"matching_target_seen": true,
		}) \
			and not DriverScript.exhausted_matching_facility_wait_required({
				"phase": "exhausted",
				"matching_facility_seen": true,
				"matching_target_seen": false,
			}) \
			and not DriverScript.exhausted_matching_facility_wait_required({
				"phase": "open",
				"matching_facility_seen": true,
				"matching_target_seen": true,
			}),
		"an exhausted scan waits on world-effective availability only after both a matching facility and legal target were publicly observed"
	)
	var visible_factory_plan := _continuation_plan(
		"factory",
		"industry",
		"commodity.industry",
		43
	)
	var visible_market_plan := _continuation_plan(
		"market",
		"technology",
		"commodity.technology",
		44
	)
	var visible_alternative := DriverScript.first_visible_alternative_plan(
		[market_energy_plan, visible_factory_plan, visible_market_plan],
		market_energy_plan,
		{},
		{"factory|industry": true}
	)
	_expect(
		str(visible_alternative.get("desired_facility_kind", "")) == "factory" \
			and str(visible_alternative.get("industry_id", "")) == "industry" \
			and DriverScript.first_visible_alternative_plan(
				[market_energy_plan, visible_factory_plan],
				market_energy_plan,
				{
					DriverScript.continuation_plan_signature(visible_factory_plan): true,
				},
				{"factory|industry": true}
			).is_empty(),
		"a fully scanned rack set selects the first visible ranked alternative and never repeats an exhausted semantic plan"
	)
	var first_public_hint := {
		"schema_version": 1,
		"district_index": 5,
		"region_id": "region.five",
		"rack_source_revision": "rack-five",
		"card_id": "facility.factory.industry.rank_1.b",
		"facility_kind": "factory",
		"industry_id": "industry",
	}
	var second_public_hint := first_public_hint.merged({
		"district_index": 1,
		"region_id": "region.one",
		"rack_source_revision": "rack-one",
		"card_id": "facility.factory.industry.rank_1.a",
	}, true)
	var public_hints := {
		"hint-five": first_public_hint,
		"hint-one": second_public_hint,
	}
	var selected_public_hint := DriverScript.first_public_facility_rack_hint_for_plan(
		public_hints,
		visible_factory_plan
	)
	_expect(
		int(selected_public_hint.get("district_index", -1)) == 1 \
			and str(selected_public_hint.get("card_id", "")) \
				== "facility.factory.industry.rank_1.a",
		"revision-bound public facility hints select deterministically without display-name or future-rack inference"
	)
	var generic_factory_floor_plan := _continuation_plan(
		"factory",
		"",
		"",
		45
	)
	_expect(
		int(DriverScript.first_public_facility_rack_hint_for_plan(
			public_hints,
			generic_factory_floor_plan
		).get("district_index", -1)) == 1,
		"the generic three-production-facility floor reuses any typed factory hint without inventing an industry requirement"
	)
	selected_public_hint["active_plan_signature"] = DriverScript.continuation_plan_signature(
		visible_factory_plan
	)
	var hinted_snapshot := {
		"visibility_scope": "viewer_private",
		"district_index": 1,
		"region_id": "region.one",
		"rack_source_revision": "rack-one",
		"cards": [{
			"card_id": "facility.factory.industry.rank_1.a",
			"kind": "facility",
			"facility_kind": "factory",
			"industry_id": "industry",
			"continuation_target_available": true,
		}],
	}
	_expect(
		DriverScript.facility_rack_hint_matches_snapshot(
			selected_public_hint,
			hinted_snapshot,
			visible_factory_plan
		) \
			and not DriverScript.facility_rack_hint_matches_snapshot(
				selected_public_hint,
				hinted_snapshot.merged({"rack_source_revision": "rack-stale"}, true),
				visible_factory_plan
			) \
			and not DriverScript.facility_rack_hint_matches_snapshot(
				selected_public_hint,
				hinted_snapshot,
				visible_market_plan
			) \
			and not DriverScript.facility_rack_hint_matches_snapshot(
				selected_public_hint,
				hinted_snapshot.merged({"cards": [(hinted_snapshot["cards"][0] as Dictionary).merged({"continuation_target_available": false}, true)]}, true),
				visible_factory_plan
			),
		"facility hint navigation re-queries exact rack revision, card identity, target availability, and semantic plan before any quote"
	)
	var hint_rotation := DriverScript._new_supply_rotation_state(
		{},
		DriverScript.continuation_plan_signature(visible_factory_plan),
		public_hints
	)
	hint_rotation["pending_facility_rack_hint"] = selected_public_hint
	DriverScript._discard_pending_facility_rack_hint(
		hint_rotation,
		selected_public_hint,
		true
	)
	DriverScript._promote_next_facility_rack_hint(
		hint_rotation,
		visible_factory_plan
	)
	_expect(
		int((hint_rotation.get("pending_facility_rack_hint", {}) as Dictionary).get(
			"district_index",
			-1
		)) == 5 \
			and str(hint_rotation.get("phase", "")) == "facility_hint_pending",
		"a stale first facility hint promotes the next fresh observed rack instead of restarting a full scan"
	)
	var advancement_binding := {
		"district_index": 1,
		"rack_source_revision": "rack-one",
		"active_plan_signature": DriverScript.continuation_plan_signature(
			visible_factory_plan
		),
		"card_id": "action.economy.public_works.rank_1",
	}
	var advancement_binding_snapshot := advancement_snapshot.duplicate(true)
	advancement_binding_snapshot["district_index"] = 1
	advancement_binding_snapshot["rack_source_revision"] = "rack-one"
	_expect(
		DriverScript.rack_advancement_candidate_matches_snapshot(
			advancement_binding,
			advancement_binding_snapshot,
			DriverScript.continuation_plan_signature(visible_factory_plan)
		) \
			and not DriverScript.rack_advancement_candidate_matches_snapshot(
				advancement_binding,
				advancement_binding_snapshot.merged({"rack_source_revision": "rack-two"}, true),
				DriverScript.continuation_plan_signature(visible_factory_plan)
			) \
			and not DriverScript.rack_advancement_candidate_matches_snapshot(
				advancement_binding,
				advancement_binding_snapshot,
				DriverScript.continuation_plan_signature(visible_market_plan)
			),
		"rack advancement revalidates its observed card, rack revision, and active plan before purchase"
	)
	var complementary_market_snapshot := mixed_snapshot.duplicate(true)
	(complementary_market_snapshot["cards"] as Array).append({
		"card_id": "facility.market.energy.rank_1",
		"card_name": "facility.market.energy.rank_1",
		"kind": "facility",
		"facility_kind": "market",
		"industry_id": "energy",
		"new_target_available": true,
		"continuation_target_available": true,
		"actionable": true,
	})
	var complementary_market := DriverScript.district_supply_action_from_snapshot(
		complementary_market_snapshot,
		market_energy_plan
	)
	_expect(
		str((complementary_market.get("payload", {}) as Dictionary).get("card_name", "")) \
			== "facility.market.energy.rank_1",
		"a matching market is selected while an unrelated factory remains visible"
	)
	var maturity_checkpoint := {
		"installation_count": 3,
		"sale_receipt_count": 1,
		"sale_receipt_revision": 10,
		"observed_world_seconds": 20.0,
	}
	_expect(
		DriverScript.production_growth_required({
			"production_installation_count": 2,
			"top_k_gdp_per_minute": 32,
			"required_top_k_gdp_per_minute": 108,
		}, {"observed": true}),
		"fewer than three production installations always keep the legal growth path open"
	)
	_expect(
		not DriverScript.production_growth_required({
			"production_installation_count": 3,
			"top_k_gdp_per_minute": 32,
			"required_top_k_gdp_per_minute": 108,
		}, {"observed": false}),
		"three installations wait for the first authoritative Sale Receipt before diagnosing GDP capacity"
	)
	_expect(
		DriverScript.production_growth_required({
			"production_installation_count": 3,
			"top_k_gdp_per_minute": 32,
			"required_top_k_gdp_per_minute": 108,
		}, {"observed": true, "public_event_count": 3}, "idle", 25.0, maturity_checkpoint),
		"a live but sub-threshold three-facility economy continues through typed production actions"
	)
	_expect(
		not DriverScript.production_growth_required({
			"production_installation_count": 3,
			"top_k_gdp_per_minute": 32,
			"required_top_k_gdp_per_minute": 108,
		}, {"observed": true, "public_event_count": 2}, "idle", 49.9, maturity_checkpoint) \
			and DriverScript.production_growth_required({
				"production_installation_count": 3,
				"top_k_gdp_per_minute": 32,
				"required_top_k_gdp_per_minute": 108,
			}, {"observed": true, "public_event_count": 2}, "idle", 50.0, maturity_checkpoint),
		"a new facility receives a bounded 30-second or two-receipt maturation window before further expansion"
	)
	_expect(
		not DriverScript.production_growth_required({
			"production_installation_count": 3,
			"top_k_gdp_per_minute": 108,
			"required_top_k_gdp_per_minute": 108,
		}, {"observed": true}),
		"meeting the public Victory GDP threshold closes additional production search"
	)
	_expect(
		not DriverScript.production_growth_required({
			"production_installation_count": 3,
			"top_k_gdp_per_minute": 32,
			"required_top_k_gdp_per_minute": 108,
		}, {"observed": true}, "qualification") \
			and not DriverScript.production_growth_required({
				"production_installation_count": 3,
				"top_k_gdp_per_minute": 32,
				"required_top_k_gdp_per_minute": 108,
			}, {"observed": true}, "audit"),
		"qualification and audit freeze further scripted growth even when the rolling GDP sample dips"
	)
	_expect(
		not DriverScript.production_growth_required({
			"production_installation_count": 3,
			"top_k_gdp_per_minute": 32,
			"required_top_k_gdp_per_minute": 108,
			"eligible": true,
		}, {"observed": true, "public_event_count": 3}, "idle", 60.0, maturity_checkpoint),
		"the eligible transition frame freezes growth before the public Victory state changes"
	)
	_expect(
		DriverScript.production_growth_required({
			"production_installation_count": 3,
			"top_k_gdp_per_minute": 32,
			"required_top_k_gdp_per_minute": 108,
		}, {"observed": true, "public_event_count": 3}, "cooldown", 60.0, maturity_checkpoint),
		"a failed qualification cooldown may resume legal typed growth"
	)
	_expect(DriverScript.recoverable_supply_receipt_reason("locked_quote_changed") and DriverScript.recoverable_supply_receipt_reason("source_region_dark") and DriverScript.recoverable_supply_receipt_reason("card_not_in_supply") and DriverScript.recoverable_supply_receipt_reason("forced_decision_blocks_district_supply"), "volatile quote, illumination, stale listing, and forced-decision preflight receipts remain retryable human interactions")
	_expect(not DriverScript.recoverable_supply_receipt_reason("purchase_target_invalid"), "structural purchase rejection is never hidden as a retryable quote race")
	_expect(
		DriverScript.recoverable_selection_receipt_reason("forced_decision_blocks_selection") \
			and DriverScript.recoverable_selection_receipt_reason("selection_revision_stale") \
			and not DriverScript.recoverable_selection_receipt_reason("target_district_missing"),
		"transient selection races retry without exhausting a public district while stable target failures remain bounded"
	)
	_expect(not JSON.stringify(opening_without_facility).contains("future") and not JSON.stringify(opening_with_facility).contains("future"), "facility search exposes no future supply-bag data")
	var exhausted_districts := {0: true}
	_expect(DriverScript.next_unexhausted_map_district(0, 4, exhausted_districts) == 1, "facility retargeting selects the next untested public district")
	for district_index in range(4):
		exhausted_districts[district_index] = true
	_expect(DriverScript.next_unexhausted_map_district(3, 4, exhausted_districts) == -1, "facility retargeting stops after every public district was tested once")
	var discovery_state := DriverScript._new_supply_rotation_state()
	_expect(
		DriverScript.begin_supply_rack_discovery(discovery_state, 2, 7, 19) \
			and str(discovery_state.get("phase", "")) == "open" \
			and int(discovery_state.get("target_district", -1)) == 2 \
			and int(discovery_state.get("source_selection_revision", -1)) == 19 \
			and int(discovery_state.get("rotation_count", 0)) == 1,
		"economy continuation opens the currently selected public rack before rotating districts"
	)
	_expect(
		not DriverScript.begin_supply_rack_discovery(discovery_state, 3, 7, 20) \
			and int(discovery_state.get("target_district", -1)) == 2,
		"an in-flight rack discovery cannot be replaced by another navigation target"
	)
	var advancement_reposition_state := DriverScript._new_supply_rotation_state()
	advancement_reposition_state["phase"] = "exhausted"
	advancement_reposition_state["advancement_candidate_districts"] = {
		5: {"card_id": "unit.five"},
		1: {"card_id": "unit.one"},
	}
	_expect(
		DriverScript.begin_supply_advancement_reposition(
			advancement_reposition_state,
			3,
			7,
			21
		) \
			and str(advancement_reposition_state.get("phase", "")) == "close" \
			and int(advancement_reposition_state.get("target_district", -1)) == 1 \
			and bool(advancement_reposition_state.get("advancement_reposition", false)) \
			and not (advancement_reposition_state.get(
				"advancement_candidate_districts",
				{}
			) as Dictionary).has(1),
		"an exhausted scan repositions deterministically to another already-observed legal public rack"
	)
	var retryable_advancement_state := {
		"phase": "advancement_recheck",
		"target_district": 5,
		"advancement_epoch_active": true,
		"advancement_reposition": false,
		"advancement_candidate_districts": {2: {"card_id": "unit.two"}},
	}
	DriverScript.advance_rack_advancement_after_retryable_failure(
		retryable_advancement_state
	)
	_expect(
		str(retryable_advancement_state.get("phase", "")) == "advancement_recheck" \
			and int(retryable_advancement_state.get("target_district", 99)) == -1 \
			and bool(retryable_advancement_state.get("advancement_epoch_active", false)),
		"a retryable advancement quote race moves to another observed candidate without counting progress"
	)
	retryable_advancement_state["advancement_candidate_districts"] = {}
	DriverScript.advance_rack_advancement_after_retryable_failure(
		retryable_advancement_state
	)
	_expect(
		str(retryable_advancement_state.get("phase", "missing")).is_empty() \
			and not bool(retryable_advancement_state.get("advancement_epoch_active", true)),
		"a retryable failure with no remaining observed candidate ends the carried exhaustion proof"
	)
	var blocked_card := {
		"card_instance_ref": "hand.instance.0",
		"card_id": "facility.factory.energy.rank_1",
		"slot": 0,
		"display_name": "本地化名称甲",
		"kind": "facility_v06",
		"facility_kind": "factory",
		"industry_id": "energy",
	}
	var first_target := {"region_id": "region.alpha", "public_index": 0, "region_revision": 1}
	var revised_target := {"region_id": "region.alpha", "public_index": 0, "region_revision": 2}
	var retry_plan := factory_energy_plan.duplicate(true)
	retry_plan["target_source_revision"] = 9
	var first_signature := DriverScript.facility_card_retry_signature(
		blocked_card,
		retry_plan,
		first_target,
		"facility_region_already_has_facility"
	)
	var localized_card := blocked_card.duplicate(true)
	localized_card["display_name"] = "Localized name B"
	localized_card["tooltip"] = "changed"
	_expect(
		first_signature == DriverScript.facility_card_retry_signature(
			localized_card,
			retry_plan,
			first_target,
			"facility_region_already_has_facility"
		),
		"facility retry identity ignores display text and tooltips"
	)
	_expect(
		first_signature != DriverScript.facility_card_retry_signature(
			blocked_card,
			retry_plan,
			revised_target,
			"facility_region_already_has_facility"
		),
		"a changed public target revision re-enables the same card instance"
	)
	_expect(
		DriverScript.action_records_economic_success(
			{"id": "district_supply_purchase_card", "origin": "district_supply"},
			true,
			{"committed_effect_refs": ["district.supply.purchase.facility.market.energy.rank_1"]}
		) \
			and DriverScript.action_records_economic_success(
				{"id": "facility_play", "origin": "game_action"},
				true,
				{"committed_effect_refs": ["card.play.hand.instance.0"]}
			) \
			and not DriverScript.action_records_economic_success(
				{"id": "district_supply_purchase_card", "origin": "district_supply"},
				true,
				{"committed_effect_refs": ["district.supply.purchase.pending-discard.0123456789abcdef01234567"]}
			) \
			and not DriverScript.action_records_economic_success({"id": "facility_play", "origin": "game_action"}, false) \
			and not DriverScript.action_records_economic_success({"id": "district_supply_preview_card", "origin": "district_supply"}, true) \
			and not DriverScript.action_records_economic_success({"id": "map_select_1", "origin": "planet_map"}, false) \
			and not DriverScript.action_records_economic_success({"id": "district_supply_rotation_open", "origin": "district_supply_rotation"}, true) \
			and not DriverScript.action_records_economic_success(
				{
					"id": "district_supply_purchase_card",
					"origin": "district_supply",
					"rack_advancement": true,
				},
				true,
				{"committed_effect_refs": ["district.supply.purchase.action.economy.public_works.rank_1"]}
			),
		"only committed purchase and hand-play effects update economic-success evidence"
	)
	var committed_advancement_pending := {
		"id": "district_supply_purchase_card",
		"origin": "district_supply",
		"rack_advancement": true,
		"rack_advancement_card_id": "action.economy.public_works.rank_1",
	}
	_expect(
		DriverScript.rack_advancement_purchase_committed(
			committed_advancement_pending,
			true,
			{"committed_effect_refs": ["district.supply.purchase.action.economy.public_works.rank_1"]}
		) \
			and not DriverScript.rack_advancement_purchase_committed(
				committed_advancement_pending,
				true,
				{"committed_effect_refs": ["district.supply.purchase.pending-discard.0123456789abcdef01234567"]}
			) \
			and not DriverScript.rack_advancement_purchase_committed(
				committed_advancement_pending,
				false,
				{"committed_effect_refs": ["district.supply.purchase.action.economy.public_works.rank_1"]}
			),
		"quote, pending discard, rejection, and UI change do not count as a rack advancement purchase"
	)
	var advancement_discard_binding := {
		"actor_player_index": 0,
		"card_id": "action.economy.public_works.rank_1",
		"quote_id": "quote.advance.1",
	}
	var advancement_discard_receipt := {
		"action_kind": str(DistrictSupplyActionIntent.KIND_PURCHASE),
		"accepted": true,
		"applied": true,
		"requires_discard": false,
		"actor_player_index": 0,
		"card_id": "action.economy.public_works.rank_1",
		"quote_id": "quote.advance.1",
	}
	_expect(
		DriverScript.rack_advancement_discard_receipt_committed(
			advancement_discard_binding,
			advancement_discard_receipt
		) \
			and not DriverScript.rack_advancement_discard_receipt_committed(
				advancement_discard_binding,
				advancement_discard_receipt.merged({"quote_id": "quote.other"}, true)
			) \
			and not DriverScript.rack_advancement_discard_receipt_committed(
				advancement_discard_binding,
				advancement_discard_receipt.merged({"requires_discard": true}, true)
			),
		"full-hand advancement counts only the final matching card-and-quote purchase receipt"
	)
	_expect(
		DriverScript.economy_growth_action({"id": "district_supply_preview_card", "origin": "district_supply"}) \
			and DriverScript.economy_growth_action({"id": "district_supply_rotation_open", "origin": "district_supply_rotation"}) \
			and DriverScript.economy_growth_action({"id": "map_select_1", "origin": "planet_map"}) \
			and DriverScript.economy_growth_action({"id": "strategy_expand_gdp", "origin": "board_primary"}) \
			and DriverScript.economy_growth_action({"id": "facility_play", "origin": "game_action", "phase": "play.hand.facility_v06.ready"}) \
			and not DriverScript.economy_growth_action({"id": "gdp_accumulation_wait", "origin": "economic_wait"}),
		"fresh Victory state gates rack search, navigation, quote, purchase, and hand installation rather than only the final mutation"
	)
	var request_fingerprint := "a".repeat(64)
	var pending_game_action := {
		"game_action_required": true,
		"game_action_receipt_sequence": 4,
		"game_action_revision_before": 11,
		"game_action_request_id": "game-action.0.7",
		"game_action_request_fingerprint": request_fingerprint,
		"game_action_semantic_action_id": GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
	}
	var committed_game_action := GameActionReceiptScript.build({
		"schema_version": GameActionReceiptScript.SCHEMA_VERSION,
		"semantic_action_id": GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
		"accepted": true,
		"reason_id": "purchase-committed",
		"request_id": "game-action.0.7",
		"request_fingerprint": request_fingerprint,
		"authoritative_revision": 12,
		"committed_effect_refs": ["district.supply.purchase.facility.market.energy.rank_1"],
		"public_projection_ref": "none",
		"viewer_private_projection_ref": "viewer.feedback.game-action.0.7",
		"idempotent_replay": false,
		"request_id_collision": false,
		"refresh_scope": "full",
	})
	_expect(
		DriverScript.game_action_receipt_confirms_progress(
			pending_game_action,
			5,
			committed_game_action
		),
		"accepted GameAction commit evidence with an advanced authoritative revision confirms progress"
	)
	var duplicate_game_action := committed_game_action.duplicate(true)
	duplicate_game_action["authoritative_revision"] = 11
	var empty_effect_game_action := committed_game_action.duplicate(true)
	empty_effect_game_action["committed_effect_refs"] = []
	var replay_game_action := committed_game_action.duplicate(true)
	replay_game_action["idempotent_replay"] = true
	var wrong_fingerprint_game_action := committed_game_action.duplicate(true)
	wrong_fingerprint_game_action["request_fingerprint"] = "b".repeat(64)
	_expect(
		not DriverScript.game_action_receipt_confirms_progress(
			pending_game_action,
			4,
			committed_game_action
		) \
			and not DriverScript.game_action_receipt_confirms_progress(
				pending_game_action,
				5,
				duplicate_game_action
			) \
			and not DriverScript.game_action_receipt_confirms_progress(
				pending_game_action,
				5,
				empty_effect_game_action
			) \
			and not DriverScript.game_action_receipt_confirms_progress(
				pending_game_action,
				5,
				replay_game_action
			) \
			and not DriverScript.game_action_receipt_confirms_progress(
				pending_game_action,
				5,
				wrong_fingerprint_game_action
			),
		"duplicate sequence, stale revision, replay, fingerprint mismatch, and empty effect evidence never confirm progress"
	)
	_expect(
		DriverScript.economy_growth_action({"id": "district_supply_purchase_card", "origin": "district_supply"}) \
			and DriverScript.economy_growth_action({"id": "play_2", "origin": "game_action", "phase": "play.hand.facility_v06.ready"}) \
			and DriverScript.economy_growth_action({"id": "district_supply_preview_card", "origin": "district_supply"}) \
			and DriverScript.economy_growth_submission_allowed({"state": "idle"}, {"valid": true, "eligible": false}) \
			and DriverScript.economy_growth_submission_allowed({"state": "cooldown"}, {"valid": true, "eligible": false}) \
			and not DriverScript.economy_growth_submission_allowed({"state": "qualification"}, {"valid": true, "eligible": true}) \
			and not DriverScript.economy_growth_submission_allowed({"state": "audit"}, {"valid": true, "eligible": false}) \
			and not DriverScript.economy_growth_submission_allowed({"state": "idle"}, {"valid": false, "eligible": false}),
		"fresh public Victory state gates every final facility submission and fails closed when unavailable"
	)
	var preserved_signatures := {}
	for index in range(DriverScript.SUPPLY_EVALUATED_RACK_SIGNATURE_LIMIT + 7):
		preserved_signatures["rack-%03d" % index] = true
	var rescanned_rotation := DriverScript._new_supply_rotation_state(preserved_signatures, "plan-a")
	_expect(
		(rescanned_rotation.get("evaluated_rack_plan_signatures", {}) as Dictionary).size() \
			== DriverScript.SUPPLY_EVALUATED_RACK_SIGNATURE_LIMIT \
			and str(rescanned_rotation.get("active_plan_signature", "")) == "plan-a",
		"cross-epoch rack dedupe preserves a bounded stable-signature set"
	)
	rescanned_rotation["phase"] = "exhausted"
	rescanned_rotation["rotation_count"] = 8
	rescanned_rotation["visited_districts"] = {0: true, 1: true}
	rescanned_rotation["current_district"] = 1
	rescanned_rotation["advancement_candidate_districts"] = {
		1: {"card_id": "unit.current"},
		4: {"card_id": "unit.other"},
	}
	var advancement_reset := DriverScript.reset_supply_rotation_after_advancement(
		rescanned_rotation
	)
	_expect(
		str(advancement_reset.get("phase", "missing")) == "advancement_recheck" \
			and bool(advancement_reset.get("advancement_epoch_active", false)) \
			and int(advancement_reset.get("rotation_count", -1)) == 0 \
			and (advancement_reset.get("visited_districts", {}) as Dictionary).is_empty() \
			and str(advancement_reset.get("active_plan_signature", "")) == "plan-a" \
			and not (advancement_reset.get("advancement_candidate_districts", {}) as Dictionary).has(1) \
			and (advancement_reset.get("advancement_candidate_districts", {}) as Dictionary).has(4) \
			and (advancement_reset.get("evaluated_rack_plan_signatures", {}) as Dictionary).size() \
				== DriverScript.SUPPLY_EVALUATED_RACK_SIGNATURE_LIMIT,
		"a committed advancement resets rotation counters, retains bounded history, and carries only a replacement-slot exhaustion proof"
	)
	_exercise_public_facility_target_query()
	_finish()


func _advancement_card(
	card_id: String,
	kind: String,
	price: int,
	primary_action_id: String,
	buy_enabled: bool,
	facility_kind := ""
) -> Dictionary:
	return {
		"card_id": card_id,
		"card_name": card_id,
		"kind": kind,
		"facility_kind": facility_kind,
		"price": price,
		"display_name": "display.%s" % card_id,
		"preview": {
			"primary_action_id": primary_action_id,
			"buy_enabled": buy_enabled,
			"action_reason_code": "market_quote_unavailable" \
				if primary_action_id == "district_supply_preview_card" \
				else "facility_purchase_ready",
		},
	}


func _snapshot(preview_card: String, preview_kind: String, primary_action_id: String, cards: Array) -> Dictionary:
	var normalized_cards := cards.duplicate(true)
	for card_variant in normalized_cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		card["card_id"] = str(card.get("card_id", card.get("card_name", "")))
		if not str(card.get("facility_kind", "")).is_empty() \
				and not card.has("new_target_available"):
			card["new_target_available"] = true
		if not str(card.get("facility_kind", "")).is_empty() \
				and not card.has("continuation_target_available"):
			card["continuation_target_available"] = bool(card.get("new_target_available", false))
	return {
		"preview": {
			"card_id": preview_card,
			"card_name": preview_card,
			"kind": preview_kind,
			"buy_enabled": true,
			"primary_action_id": primary_action_id,
			"action_reason_code": "",
		},
		"cards": normalized_cards,
	}


func _continuation_plan(
	facility_kind: String,
	industry_id: String,
	commodity_id: String,
	source_revision: int
) -> Dictionary:
	return {
		"schema_version": 1,
		"ready": true,
		"reason_id": "test_complementary_chain",
		"desired_facility_kind": facility_kind,
		"desired_direction": "production" if facility_kind == "factory" else "demand",
		"commodity_id": commodity_id,
		"industry_id": industry_id,
		"source_revision": source_revision,
		"target_source_revision": 0,
		"stop": false,
	}


func _exercise_public_facility_target_query() -> void:
	var energy_product := _first_product_for_industry("energy")
	var technology_product := _first_product_for_industry("technology")
	var state := WorldSessionState.new()
	state.replace_districts([
		{"region_id": "region.alpha", "products": [energy_product], "demands": [], "destroyed": false},
		{"region_id": "region.beta", "products": [energy_product], "demands": [], "destroyed": false},
		{"region_id": "region.gamma", "products": [technology_product], "demands": [], "destroyed": false},
		{"region_id": "region.delta", "products": [energy_product], "demands": [], "destroyed": true},
		{"region_id": "region.epsilon", "products": [energy_product], "demands": [], "destroyed": true},
	], true)
	var infrastructure := FakeInfrastructureController.new()
	for index in range(state.districts.size()):
		var district := state.districts[index] as Dictionary
		infrastructure.regions.append({
			"region_id": str(district.get("region_id", "")),
			"legacy_index": index,
			"revision": index + 1,
			"lifecycle_state": "ruined" if index == 4 else ("legacy_unmapped" if index == 3 else "active"),
		})
	infrastructure.facilities = [{
		"region_id": "region.beta",
		"facility_type": "factory",
		"industry_id": "energy",
		"rank": 1,
		"active": true,
		"owner_visibility": "public",
		"owner_kind": "player",
		"owner_player_index": 2,
	}]
	var bridge := RegionInfrastructureWorldBridge.new()
	bridge.set_controller(infrastructure)
	bridge.set_world_session_state(state)
	var ports := TablePresentationQueryPorts.new()
	ports.region_infrastructure_public_query = bridge
	var first := ports.public_new_facility_target_candidates(&"factory", &"energy")
	var first_data := first.to_dictionary()
	var expected_candidates := [
		{"region_id": "region.alpha", "public_index": 0, "region_revision": 1},
		{"region_id": "region.epsilon", "public_index": 4, "region_revision": 5},
	]
	_expect(first.is_valid() and bool(first_data.get("available", false)) and first_data.get("candidates", []) == expected_candidates, "typed target query excludes occupied, mismatched, and invalid-lifecycle regions while retaining a real ruined/destroyed projection")
	_expect(TablePresentationPureDataPolicy.is_pure_data(first_data) and not JSON.stringify(first_data).contains("owner") and not JSON.stringify(first_data).contains("facility_id") and not JSON.stringify(first_data).contains("slot_id"), "typed target snapshot is pure public data with no owner, facility, or slot identity")
	var repeated := ports.public_new_facility_target_candidates(&"factory", &"energy").to_dictionary()
	_expect(repeated == first_data, "unchanged public target inputs preserve deterministic ordering and source revision")
	var retry_card := {
		"card_instance_ref": "hand.instance.query",
		"card_id": "facility.factory.energy.rank_1",
		"facility_kind": "factory",
		"industry_id": "energy",
	}
	var retry_plan := _continuation_plan("factory", "energy", "commodity.energy", 17)
	retry_plan["target_source_revision"] = int(first_data.get("source_revision", 0))
	var first_attempt_signature := DriverScript.facility_card_retry_signature(
		retry_card,
		retry_plan,
		expected_candidates[0],
		"facility_region_already_has_facility"
	)
	_expect(
		DriverScript.next_public_facility_candidate(
			first_data.get("candidates", []),
			{first_attempt_signature: true},
			retry_card,
			retry_plan,
			"facility_region_already_has_facility"
		).get("public_index", -1) == 4,
		"driver consumes ordered typed candidates and skips an attempted stable region revision"
	)
	infrastructure.revision = 2
	infrastructure.facilities.append({
		"region_id": "region.alpha",
		"facility_type": "factory",
		"industry_id": "energy",
		"rank": 1,
		"active": true,
		"owner_visibility": "public",
		"owner_kind": "neutral",
		"owner_player_index": -1,
	})
	var changed := ports.public_new_facility_target_candidates(&"factory", &"energy").to_dictionary()
	_expect(changed.get("candidates", []) == [expected_candidates[1]] and int(changed.get("source_revision", -1)) != int(first_data.get("source_revision", -1)), "public occupancy revision removes the candidate and changes the source revision exactly once")
	var invalid := ports.public_new_facility_target_candidates(&"factory", &"unknown").to_dictionary()
	_expect(not bool(invalid.get("available", true)) and (invalid.get("candidates", []) as Array).is_empty(), "unknown typed industry fails closed without blind region fallback")
	ports.free()
	bridge.free()
	infrastructure.free()
	state.free()


func _first_product_for_industry(industry_id: String) -> String:
	for product_id_variant in PRODUCT_INDUSTRY_CATALOG.product_ids():
		var product_id := str(product_id_variant)
		if PRODUCT_INDUSTRY_CATALOG.industry_for_product(product_id) == industry_id:
			return product_id
	return ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	printerr("FAIL: %s" % message)


func _finish() -> void:
	print("Full-run facility acquisition policy checks: %d" % _checks)
	if _failures.is_empty():
		print("FULL_RUN_FACILITY_ACQUISITION_POLICY_TEST_COMPLETE")
		quit(0)
		return
	printerr("Full-run facility acquisition policy failures: %s" % ", ".join(_failures))
	quit(1)
