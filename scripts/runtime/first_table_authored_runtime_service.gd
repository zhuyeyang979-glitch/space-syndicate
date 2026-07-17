@tool
extends Node
class_name FirstTableAuthoredRuntimeService

const PUBLIC_FORBIDDEN_KEYS := [
	"true_owner",
	"hidden_owner",
	"owner_truth",
	"private_target",
	"private_discard",
	"ai_score",
	"ai_reason",
]

const LEGACY_FIXED_FIXTURE_KEYS := [
	"facility_market_source_district_index",
	"teaching_card_ids",
	"teaching_card_kind",
	"followup_card_ids",
	"featured_card_ids",
	"starter_monster_ids",
	"preferred_product_ids",
	"city_development_guarantee_card",
	"monster_guarantee_card",
]

const PUBLIC_RACK_FORBIDDEN_KEYS := [
	"player_cash",
	"cash",
	"cash_cents",
	"counted_hand_size",
	"hand_limit",
	"hand_cards",
	"player_hand",
	"purchase_window",
	"can_buy",
	"subject_player_index",
	"viewer_player_index",
	"owner_player_index",
	"hidden_owner",
	"true_owner",
	"owner_truth",
	"private_plan",
	"private_target",
	"private_discard",
	"ai_plan",
	"ai_score",
	"ai_reason",
	"bag",
	"bag_order",
	"bag_epoch",
	"rng",
	"rng_seed",
	"rng_state",
	"draw_cursor",
	"next_card_id",
	"future_card_ids",
	"unlisted_unique_card_ids",
]

const GENERIC_RACK_HINT := "浏览当前牌架"
const RECOMMENDATION_SOURCE := "public_region_supply_rack"

@export var scenario_id := "first_table"

var _configured := false
var _scenario_definition: Dictionary = {}
var _fixture: Dictionary = {}
var _ignored_legacy_fixture_fields: Array[String] = []
var _catalog_resolution_count := 0
var _content_composition_count := 0
var _context_composition_count := 0
var _score_count := 0
var _pacing_evaluation_count := 0
var _supply_plan_count := 0
var _rack_recommendation_count := 0


func configure(config: Dictionary = {}) -> void:
	_configured = false
	_scenario_definition.clear()
	_fixture.clear()
	_ignored_legacy_fixture_fields.clear()
	if not _is_data_only(config):
		return
	var definition_variant: Variant = config.get("scenario_definition", {})
	if not (definition_variant is Dictionary):
		return
	var definition: Dictionary = (definition_variant as Dictionary).duplicate(true)
	var fixture_variant: Variant = definition.get("fixture", {})
	if str(definition.get("id", "")).strip_edges() != scenario_id or not (fixture_variant is Dictionary):
		return
	_scenario_definition = definition
	_fixture = (fixture_variant as Dictionary).duplicate(true)
	for field_variant in LEGACY_FIXED_FIXTURE_KEYS:
		var field := str(field_variant)
		if _fixture.has(field):
			_fixture.erase(field)
			_ignored_legacy_fixture_fields.append(field)
	_scenario_definition["fixture"] = _fixture.duplicate(true)
	_configured = not _fixture.is_empty()


func fixture_snapshot() -> Dictionary:
	return _fixture.duplicate(true) if _configured else {}


func market_listing_plan() -> Dictionary:
	if not _configured:
		return {}
	return {
		"scenario_id": scenario_id,
		"ready": false,
		"reason_code": "public_region_supply_rack_snapshot_required",
		"operation": "read_only_recommendation",
		"recommendation_source": RECOMMENDATION_SOURCE,
		"mutates_rack": false,
		"reserves_slot": false,
		"refreshes_rack": false,
	}


func pacing_profile() -> Dictionary:
	if not _configured:
		return {}
	var pacing_variant: Variant = _fixture.get("pacing", {})
	if not (pacing_variant is Dictionary) or not _is_data_only(pacing_variant):
		return {}
	var pacing: Dictionary = pacing_variant
	var recommended_min_seconds := maxf(0.0, float(pacing.get("recommended_min_seconds", 900.0)))
	var target_duration_seconds := maxf(recommended_min_seconds, float(pacing.get("target_duration_seconds", 1200.0)))
	var recommended_max_seconds := maxf(target_duration_seconds, float(pacing.get("recommended_max_seconds", 1800.0)))
	var milestones: Array = []
	var seen_ids := {}
	var milestones_variant: Variant = pacing.get("milestones", [])
	if milestones_variant is Array:
		for milestone_variant in milestones_variant:
			if not (milestone_variant is Dictionary):
				continue
			var milestone: Dictionary = milestone_variant
			var milestone_id := str(milestone.get("id", "")).strip_edges()
			var signal_id := str(milestone.get("signal_id", "")).strip_edges()
			if milestone_id == "" or signal_id == "" or seen_ids.has(milestone_id):
				continue
			seen_ids[milestone_id] = true
			var target_seconds := maxf(0.0, float(milestone.get("target_seconds", 0.0)))
			milestones.append({
				"id": milestone_id,
				"label": str(milestone.get("label", milestone_id)),
				"signal_id": signal_id,
				"target_seconds": target_seconds,
				"warning_seconds": maxf(target_seconds, float(milestone.get("warning_seconds", target_seconds))),
			})
	return {
		"scenario_id": scenario_id,
		"measurement_kind": str(pacing.get("measurement_kind", "scenario_game_time")),
		"recommended_min_seconds": recommended_min_seconds,
		"target_duration_seconds": target_duration_seconds,
		"recommended_max_seconds": recommended_max_seconds,
		"milestones": milestones,
	}


func evaluate_pacing(runtime_snapshot: Dictionary) -> Dictionary:
	_pacing_evaluation_count += 1
	if not _configured or not _is_data_only(runtime_snapshot):
		return {}
	var profile := pacing_profile()
	if profile.is_empty():
		return {}
	var completed_times_variant: Variant = runtime_snapshot.get("completed_signal_times", {})
	var completed_times: Dictionary = completed_times_variant if completed_times_variant is Dictionary else {}
	var started_at := maxf(0.0, float(runtime_snapshot.get("scenario_started_at", 0.0)))
	var elapsed_seconds := maxf(0.0, float(runtime_snapshot.get("elapsed_seconds", 0.0)))
	var records: Array = []
	var reached_count := 0
	var late_count := 0
	var next_milestone_id := ""
	var completion_elapsed_seconds := -1.0
	for milestone_variant in profile.get("milestones", []):
		var milestone: Dictionary = milestone_variant if milestone_variant is Dictionary else {}
		var signal_id := str(milestone.get("signal_id", ""))
		var reached := completed_times.has(signal_id)
		var observed_seconds := maxf(0.0, float(completed_times.get(signal_id, started_at)) - started_at) if reached else -1.0
		var target_seconds := float(milestone.get("target_seconds", 0.0))
		var warning_seconds := float(milestone.get("warning_seconds", target_seconds))
		var status := "pending"
		if reached:
			reached_count += 1
			if observed_seconds <= target_seconds:
				status = "on_target"
			elif observed_seconds <= warning_seconds:
				status = "within_warning"
			else:
				status = "late"
				late_count += 1
			if str(milestone.get("id", "")) == "mission_complete":
				completion_elapsed_seconds = observed_seconds
		elif next_milestone_id == "":
			next_milestone_id = str(milestone.get("id", ""))
		records.append({
			"id": str(milestone.get("id", "")),
			"label": str(milestone.get("label", "")),
			"signal_id": signal_id,
			"reached": reached,
			"observed_seconds": observed_seconds,
			"target_seconds": target_seconds,
			"warning_seconds": warning_seconds,
			"status": status,
			"upper_bound_met": reached and observed_seconds <= warning_seconds,
		})
	var window_status := "pending"
	if completion_elapsed_seconds >= 0.0:
		if completion_elapsed_seconds < float(profile.get("recommended_min_seconds", 0.0)):
			window_status = "fast"
		elif completion_elapsed_seconds <= float(profile.get("recommended_max_seconds", 0.0)):
			window_status = "within_window"
		else:
			window_status = "over_budget"
	return {
		"scenario_id": scenario_id,
		"measurement_kind": str(profile.get("measurement_kind", "scenario_game_time")),
		"scenario_started_at": started_at,
		"elapsed_seconds": elapsed_seconds,
		"recommended_min_seconds": float(profile.get("recommended_min_seconds", 0.0)),
		"target_duration_seconds": float(profile.get("target_duration_seconds", 0.0)),
		"recommended_max_seconds": float(profile.get("recommended_max_seconds", 0.0)),
		"milestone_count": records.size(),
		"reached_count": reached_count,
		"late_count": late_count,
		"next_milestone_id": next_milestone_id,
		"completion_elapsed_seconds": completion_elapsed_seconds,
		"recommended_window_status": window_status,
		"pacing_gate_passed": records.size() > 0 and reached_count == records.size() and late_count == 0,
		"records": records,
	}


func supply_plan(public_rack_snapshot: Dictionary) -> Dictionary:
	_supply_plan_count += 1
	if not _configured or not _is_data_only(public_rack_snapshot):
		return {}
	var recommendation := recommend_rack_item(public_rack_snapshot)
	return {
		"scenario_id": scenario_id,
		"ready": bool(recommendation.get("available", false)),
		"reason_code": str(recommendation.get("reason_code", "")),
		"operation": "read_only_recommendation",
		"recommendation": recommendation,
		"followup_card_id": "",
		"inject_after_signal": "",
		"supply_source_id": RECOMMENDATION_SOURCE,
		"mutates_rack": false,
		"reserves_slot": false,
		"refreshes_rack": false,
		"preserve_monster_guarantee": false,
		"preserve_city_development_guarantee": false,
	}


func resolve_content_catalog(catalog_snapshot: Dictionary) -> Dictionary:
	_catalog_resolution_count += 1
	if not _configured or not _is_data_only(catalog_snapshot):
		return _empty_catalog()
	return {
		"scenario_id": scenario_id,
		"recommendation_source": RECOMMENDATION_SOURCE,
		"available_card_count": 0,
		"catalog_card_ids": [],
		"catalog_input_ignored": true,
		"teaching_card_kind": "current_public_rack",
		"runtime_card_ids": [],
		"public_facility_card_ids": [],
		"followup_card_ids": [],
		"followup_card_id": "",
		"featured_card_ids": [],
		"starter_monster_ids": [],
		"preferred_product_ids": [],
		"legacy_fixed_catalog_selection_active": false,
	}


func select_teaching_product(district_snapshot: Dictionary, resolved_catalog: Dictionary = {}) -> String:
	if not _configured or not _is_data_only(district_snapshot) or not _is_data_only(resolved_catalog):
		return ""
	var recommendation := recommend_rack_item(_rack_snapshot_from_source(district_snapshot))
	return str(recommendation.get("product_id", "")) if bool(recommendation.get("available", false)) else ""


func compose_runtime_content(world_snapshot: Dictionary, resolved_catalog: Dictionary) -> Dictionary:
	_content_composition_count += 1
	if not _configured or not _is_data_only(world_snapshot) or not _is_data_only(resolved_catalog):
		return {}
	var public_rack := _rack_snapshot_from_source(world_snapshot)
	var first_recommendation := recommend_rack_item(public_rack)
	var first_card_id := str(first_recommendation.get("card_id", ""))
	var first_item_id := str(first_recommendation.get("item_id", ""))
	var excluded_listing_ids: Array = [first_item_id] if first_item_id != "" else ([first_card_id] if first_card_id != "" else [])
	var followup_recommendation := recommend_rack_item(public_rack, excluded_listing_ids)
	var teaching_card_ids: Array = [first_card_id] if first_card_id != "" else []
	var owned_facilities := _data_array(world_snapshot.get("owned_facilities", []))
	var city_present := bool(world_snapshot.get("city_present", false)) or not owned_facilities.is_empty()
	var facility_summary_text := "尚未建立公共设施"
	if city_present:
		var facility_labels: Array = []
		for facility_variant in owned_facilities:
			if not (facility_variant is Dictionary):
				continue
			var facility: Dictionary = facility_variant
			facility_labels.append("%s%s %d级" % [str(facility.get("industry_id", "通用")), str(facility.get("facility_type", "设施")), int(facility.get("rank", 1))])
		if not facility_labels.is_empty():
			facility_summary_text = "、".join(facility_labels)
	var gdp_per_minute := maxi(0, int(world_snapshot.get("gdp_per_minute", 0))) if city_present else 0
	var cashflow_paid_total := maxi(0, int(world_snapshot.get("cashflow_paid_total", 0))) if city_present else 0
	var visible_monster_name := str(world_snapshot.get("visible_monster_name", "")).strip_edges()
	if visible_monster_name == "":
		visible_monster_name = "场上怪兽"
	return {
		"scenario_id": scenario_id,
		"district_index": int(world_snapshot.get("district_index", -1)),
		"district_name": str(world_snapshot.get("district_name", "推荐区域")),
		"teaching_product_id": str(first_recommendation.get("product_id", "")),
		"teaching_card_id": first_card_id,
		"teaching_card_ids": teaching_card_ids,
		"teaching_card_kind": str(first_recommendation.get("kind", "current_public_rack")) if bool(first_recommendation.get("available", false)) else "browse_current_rack",
		"followup_card_id": str(followup_recommendation.get("card_id", "")),
		"featured_card_ids": [],
		"starter_monster_id": "",
		"starter_monster_ids": [],
		"preferred_product_ids": [],
		"rack_recommendation": first_recommendation,
		"followup_rack_recommendation": followup_recommendation,
		"rack_guidance": str(first_recommendation.get("guidance", GENERIC_RACK_HINT)),
		"recommendation_source": RECOMMENDATION_SOURCE,
		"rack_public_revision": str(first_recommendation.get("rack_revision", "")),
		"rack_state_revision": int(first_recommendation.get("state_revision", 0)),
		"rack_mutation_requested": false,
		"city_present": city_present,
		"city_product_ids": _string_array(world_snapshot.get("city_product_ids", [])) if city_present else [],
		"city_demand_ids": _string_array(world_snapshot.get("city_demand_ids", [])) if city_present else [],
		"owned_facilities": owned_facilities,
		"facility_summary_text": facility_summary_text,
		"gdp_per_minute": gdp_per_minute,
		"cashflow_paid_total": cashflow_paid_total,
		"positive_income_observed": gdp_per_minute > 0 or cashflow_paid_total > 0,
		"public_clue_count": maxi(0, int(world_snapshot.get("public_clue_count", 0))),
		"ai_public_action_seen": bool(world_snapshot.get("ai_public_action_seen", false)),
		"monster_pressure_seen": bool(world_snapshot.get("monster_pressure_seen", false)),
		"monster_pressure_visible": bool(world_snapshot.get("monster_pressure_visible", false)),
		"visible_monster_name": visible_monster_name,
		"route_choice": str(world_snapshot.get("route_choice", "")),
	}


func contextualize_phase(phase_snapshot: Dictionary, content_snapshot: Dictionary) -> Dictionary:
	_context_composition_count += 1
	if not _configured or not _is_data_only(phase_snapshot) or not _is_data_only(content_snapshot):
		return {}
	var contextual := phase_snapshot.duplicate(true)
	var district_name := str(content_snapshot.get("district_name", "推荐区域"))
	var recommendation := _dictionary(content_snapshot.get("rack_recommendation", {}))
	var followup_recommendation := _dictionary(content_snapshot.get("followup_rack_recommendation", {}))
	var recommended_label := str(recommendation.get("display_name", recommendation.get("card_id", GENERIC_RACK_HINT))) if bool(recommendation.get("available", false)) else GENERIC_RACK_HINT
	var followup_label := str(followup_recommendation.get("display_name", followup_recommendation.get("card_id", GENERIC_RACK_HINT))) if bool(followup_recommendation.get("available", false)) else GENERIC_RACK_HINT
	var monster_id := str(content_snapshot.get("visible_monster_name", "场上怪兽"))
	match str(contextual.get("id", "")):
		"select_district":
			contextual["detail"] = "选择区域后打开该区当前公开随机牌架；推荐只读取公开挂牌，不改变牌位、刷新序号或下一张牌。"
		"buy_development", "play_development":
			contextual["detail"] = "当前牌架推荐：%s。先在 RightInspector 阅读公开条件；若它不适合当前计划，就%s。" % [recommended_label, GENERIC_RACK_HINT]
		"observe_facility":
			contextual["detail"] = "观察刚购买卡牌的真实公开结算。当前我的设施：%s｜当前商品 GDP/min %d；其他玩家的私有状态保持隐藏。" % [str(content_snapshot.get("facility_summary_text", "待建立")), int(content_snapshot.get("gdp_per_minute", 0))]
		"check_economy":
			contextual["detail"] = "%s 当前商品 GDP/min %d｜已结算商品现金流 %d。" % [district_name, int(content_snapshot.get("gdp_per_minute", 0)), int(content_snapshot.get("cashflow_paid_total", 0))]
		"buy_followup", "play_followup":
			contextual["detail"] = "当前牌架的下一项公开推荐：%s。服务不会注入、预留或刷新任何挂牌；没有合适牌时就%s。" % [followup_label, GENERIC_RACK_HINT]
		"observe_ai_public_action", "inspect_clues":
			contextual["detail"] = "当前公开线索 %d 条；只显示行动、目标与结果，不显示真实操作者。" % int(content_snapshot.get("public_clue_count", 0))
		"inspect_monster_pressure":
			contextual["detail"] = "%s 已在地图形成公开压力；查看移动、目标、商路或城市结果。" % monster_id
		"choose_route":
			contextual["detail"] = "收入：GDP/min %d｜线索 %d 条｜怪兽：%s。选择方向后任务总结出现，整局仍继续。" % [int(content_snapshot.get("gdp_per_minute", 0)), int(content_snapshot.get("public_clue_count", 0)), monster_id]
	return contextual


func completion_summary(content_snapshot: Dictionary) -> String:
	if not _configured or not _is_data_only(content_snapshot):
		return ""
	return "首局任务完成：你在%s读取了当前随机牌架并完成真实卡牌结算，当前 GDP/min %d；你已读过匿名牌轨、AI公开线索和%s的怪兽压力。整局仍继续。" % [
		str(content_snapshot.get("district_name", "推荐区域")),
		int(content_snapshot.get("gdp_per_minute", 0)),
		str(content_snapshot.get("visible_monster_name", "怪兽")),
	]


func completion_label(content_snapshot: Dictionary) -> String:
	if not _configured or not _is_data_only(content_snapshot):
		return ""
	return "首局完成｜当前牌架已读｜GDP %d/min｜整局继续" % int(content_snapshot.get("gdp_per_minute", 0))


func score_district(district_snapshot: Dictionary, resolved_catalog: Dictionary) -> int:
	_score_count += 1
	if not _configured or not _is_data_only(district_snapshot) or not _is_data_only(resolved_catalog):
		return -1000000
	var recommendation := recommend_rack_item(_rack_snapshot_from_source(district_snapshot))
	return 1 if bool(recommendation.get("available", false)) else -1000000


func recommend_rack_item(public_rack_snapshot: Dictionary, excluded_listing_ids: Array = []) -> Dictionary:
	_rack_recommendation_count += 1
	if not _configured or not _is_data_only(public_rack_snapshot) or not _is_data_only(excluded_listing_ids):
		return _generic_rack_recommendation("public_rack_invalid", public_rack_snapshot)
	var validation := _validate_public_rack_snapshot(public_rack_snapshot)
	if not bool(validation.get("valid", false)):
		return _generic_rack_recommendation(str(validation.get("reason_code", "public_rack_invalid")), public_rack_snapshot)
	var excluded := _string_set(excluded_listing_ids)
	var candidates := _public_rack_candidates(public_rack_snapshot, excluded)
	if candidates.is_empty():
		return _generic_rack_recommendation("no_suitable_public_rack_card", public_rack_snapshot)
	var selected: Dictionary = candidates[0]
	var display_name := str(selected.get("display_name", selected.get("card_id", "")))
	return {
		"available": true,
		"reason_code": "current_public_rack_recommendation",
		"source": RECOMMENDATION_SOURCE,
		"card_id": str(selected.get("card_id", "")),
		"display_name": display_name,
		"slot_id": str(selected.get("slot_id", "")),
		"rack_index": int(selected.get("rack_index", -1)),
		"kind": str(selected.get("kind", "")),
		"facility_type": str(selected.get("facility_type", "")),
		"product_id": str(selected.get("product_id", "")),
		"rank": int(selected.get("rank", 1)),
		"label": "当前牌架推荐｜%s" % display_name,
		"action_hint": "查看 %s" % display_name,
		"guidance": "当前公开随机牌架推荐先阅读：%s。该提示不会预留、刷新或改动牌架。" % display_name,
		"selection_reason": str(selected.get("selection_reason", "当前公开牌架中的可读挂牌")),
		"region_id": str(selected.get("region_id", "")),
		"rack_revision": str(selected.get("rack_revision", "")),
		"state_revision": maxi(0, int(public_rack_snapshot.get("state_revision", 0))),
		"item_id": str(selected.get("item_id", "")),
		"supply_revision": str(selected.get("supply_revision", "")),
		"slot_index": int(selected.get("slot_index", -1)),
		"rack_card_count": int(validation.get("card_count", 0)),
		"mutates_rack": false,
		"reserves_slot": false,
		"refreshes_rack": false,
	}


func debug_snapshot() -> Dictionary:
	var acts_variant: Variant = _fixture.get("acts", [])
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"scenario_id": scenario_id,
		"phase_count": (_scenario_definition.get("phases", []) as Array).size() if _scenario_definition.get("phases", []) is Array else 0,
		"act_count": (acts_variant as Array).size() if acts_variant is Array else 0,
		"catalog_resolution_count": _catalog_resolution_count,
		"content_composition_count": _content_composition_count,
		"context_composition_count": _context_composition_count,
		"score_count": _score_count,
		"pacing_evaluation_count": _pacing_evaluation_count,
		"supply_plan_count": _supply_plan_count,
		"rack_recommendation_count": _rack_recommendation_count,
		"pacing_milestone_count": (pacing_profile().get("milestones", []) as Array).size(),
		"recommendation_source": RECOMMENDATION_SOURCE,
		"ignored_legacy_fixture_fields": _ignored_legacy_fixture_fields.duplicate(),
		"legacy_fixed_fixture_field_count": _ignored_legacy_fixture_fields.size(),
		"selects_from_current_public_rack_only": true,
		"mutates_region_supply_rack": false,
		"reserves_region_supply_slot": false,
		"refreshes_region_supply_rack": false,
		"fixed_city_development_selection_active": false,
		"fixed_monster_selection_active": false,
		"followup_card_injection_active": false,
		"factory_before_market_assumption_active": false,
		"legacy_authored_fallback_used": false,
	}


func _empty_catalog() -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"recommendation_source": RECOMMENDATION_SOURCE,
		"available_card_count": 0,
		"catalog_card_ids": [],
		"catalog_input_ignored": true,
		"teaching_card_kind": "current_public_rack",
		"runtime_card_ids": [],
		"public_facility_card_ids": [],
		"followup_card_ids": [],
		"followup_card_id": "",
		"featured_card_ids": [],
		"starter_monster_ids": [],
		"preferred_product_ids": [],
		"legacy_fixed_catalog_selection_active": false,
	}


func _rack_snapshot_from_source(source: Dictionary) -> Dictionary:
	for key in [
		"public_region_supply_rack_snapshot",
		"region_supply_rack_snapshot",
		"public_rack_snapshot",
		"rack_snapshot",
	]:
		var value: Variant = source.get(key, {})
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	if source.has("regions") and source.get("regions", []) is Array:
		return source.duplicate(true)
	return {}


func _validate_public_rack_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty() or not _is_data_only(snapshot):
		return {"valid": false, "reason_code": "public_rack_invalid", "card_count": 0}
	var forbidden_paths: Array = []
	_collect_public_rack_forbidden_paths(snapshot, "rack", forbidden_paths)
	if not forbidden_paths.is_empty():
		return {
			"valid": false,
			"reason_code": "public_rack_private_field_rejected",
			"card_count": 0,
		}
	if snapshot.has("available") and not bool(snapshot.get("available", false)):
		return {"valid": false, "reason_code": str(snapshot.get("reason_code", "public_rack_unavailable")), "card_count": 0}
	var regions_variant: Variant = snapshot.get("regions", [])
	if not snapshot.has("regions") or not (regions_variant is Array):
		return {"valid": false, "reason_code": "public_rack_regions_invalid", "card_count": 0}
	var card_count := 0
	for region_variant in regions_variant:
		if not (region_variant is Dictionary):
			return {"valid": false, "reason_code": "public_rack_region_invalid", "card_count": 0}
		var region: Dictionary = region_variant
		if str(region.get("region_id", "")).strip_edges().is_empty() or not (region.get("slots", []) is Array):
			return {"valid": false, "reason_code": "public_rack_region_invalid", "card_count": 0}
		for listing_variant in region.get("slots", []):
			if listing_variant is Dictionary and not (listing_variant as Dictionary).is_empty():
				card_count += 1
	return {
		"valid": true,
		"reason_code": "ready",
		"card_count": card_count,
	}


func _collect_public_rack_forbidden_paths(value: Variant, path: String, result: Array) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).strip_edges().to_lower()
			var next_path := "%s.%s" % [path, key]
			if PUBLIC_RACK_FORBIDDEN_KEYS.has(key):
				result.append(next_path)
				continue
			_collect_public_rack_forbidden_paths((value as Dictionary)[key_variant], next_path, result)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_public_rack_forbidden_paths((value as Array)[index], "%s[%d]" % [path, index], result)


func _public_rack_candidates(snapshot: Dictionary, excluded: Dictionary) -> Array:
	var candidates: Array = []
	var regions: Array = snapshot.get("regions", []) if snapshot.get("regions", []) is Array else []
	for region_order in range(regions.size()):
		if not (regions[region_order] is Dictionary):
			continue
		var region: Dictionary = regions[region_order]
		var region_id := str(region.get("region_id", "")).strip_edges()
		var rack_revision := str(region.get("rack_revision", ""))
		var slots: Array = region.get("slots", []) if region.get("slots", []) is Array else []
		for slot_order in range(slots.size()):
			if not (slots[slot_order] is Dictionary):
				continue
			var listing: Dictionary = slots[slot_order]
			if listing.is_empty():
				continue
			var card_id := str(listing.get("card_id", "")).strip_edges()
			var item_id := str(listing.get("item_id", "")).strip_edges()
			if card_id.is_empty() or bool(excluded.get(item_id, false)) or bool(excluded.get(card_id, false)):
				continue
			var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
			if bool(card.get("retired", false)) \
			or str(listing.get("listing_state", listing.get("state", ""))) in ["empty", "sold", "removed", "retired"]:
				continue
			var rank := _rank_number(card.get("rank", 1))
			var card_type := str(card.get("card_type", "")).strip_edges()
			var is_public_facility := card_type in ["public_facility", "facility"]
			candidates.append({
				"card_id": card_id,
				"display_name": str(card.get("display_name", card.get("name", card_id))).strip_edges(),
				"item_id": item_id,
				"slot_id": str(item_id if item_id != "" else listing.get("slot_index", slot_order)),
				"slot_index": int(listing.get("slot_index", slot_order)),
				"rack_index": slot_order,
				"region_order": region_order,
				"kind": card_type,
				"facility_type": "",
				"product_id": "",
				"rank": rank,
				"selection_score": (10000 if is_public_facility else 0) + maxi(0, 5 - rank) * 100,
				"selection_reason": "当前牌架中的公共设施挂牌" if is_public_facility else ("当前牌架中的低等级挂牌" if rank == 1 else "当前公开牌架中的可读挂牌"),
				"region_id": region_id,
				"rack_revision": rack_revision,
				"supply_revision": str(listing.get("supply_revision", "")),
			})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := int(left.get("selection_score", 0))
		var right_score := int(right.get("selection_score", 0))
		if left_score != right_score:
			return left_score > right_score
		var left_region_order := int(left.get("region_order", 0))
		var right_region_order := int(right.get("region_order", 0))
		if left_region_order != right_region_order:
			return left_region_order < right_region_order
		var left_index := int(left.get("rack_index", 0))
		var right_index := int(right.get("rack_index", 0))
		return left_index < right_index
	)
	return candidates


func _generic_rack_recommendation(reason_code: String, snapshot: Dictionary = {}) -> Dictionary:
	var first_region := _first_public_region(snapshot)
	return {
		"available": false,
		"reason_code": reason_code,
		"source": RECOMMENDATION_SOURCE,
		"card_id": "",
		"display_name": "",
		"slot_id": "",
		"rack_index": -1,
		"kind": "",
		"facility_type": "",
		"product_id": "",
		"rank": 0,
		"label": GENERIC_RACK_HINT,
		"action_hint": GENERIC_RACK_HINT,
		"guidance": "当前公开随机牌架暂无合适推荐；浏览当前牌架，按公开条件自行选择。",
		"selection_reason": "没有合适的当前公开挂牌",
		"region_id": str(first_region.get("region_id", "")),
		"rack_revision": str(first_region.get("rack_revision", "")),
		"state_revision": maxi(0, int(snapshot.get("state_revision", 0))),
		"rack_card_count": _native_rack_card_count(snapshot),
		"mutates_rack": false,
		"reserves_slot": false,
		"refreshes_rack": false,
	}


func _first_public_region(snapshot: Dictionary) -> Dictionary:
	var regions: Array = snapshot.get("regions", []) if snapshot.get("regions", []) is Array else []
	return (regions[0] as Dictionary).duplicate(true) if not regions.is_empty() and regions[0] is Dictionary else {}


func _native_rack_card_count(snapshot: Dictionary) -> int:
	var count := 0
	for region_variant in snapshot.get("regions", []):
		if not (region_variant is Dictionary):
			continue
		for listing_variant in (region_variant as Dictionary).get("slots", []):
			if listing_variant is Dictionary and not (listing_variant as Dictionary).is_empty():
				count += 1
	return count


func _rank_number(value: Variant) -> int:
	if value is int:
		return maxi(1, int(value))
	match str(value).strip_edges().to_upper():
		"II", "2", "RANK_II", "RANK_2":
			return 2
		"III", "3", "RANK_III", "RANK_3":
			return 3
		"IV", "4", "RANK_IV", "RANK_4":
			return 4
	return 1


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _string_set(value: Variant) -> Dictionary:
	var result := {}
	for item_variant in _string_array(value):
		result[str(item_variant)] = true
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item_variant in value:
		_append_unique_string(result, str(item_variant))
	return result


func _data_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array and _is_data_only(value) else []


func _append_unique_string(values: Array, value: String) -> void:
	var clean := value.strip_edges()
	if clean != "" and not values.has(clean):
		values.append(clean)


func _sanitize_public_array(value: Variant) -> Array:
	if not (value is Array):
		return []
	var result: Array = []
	for item_variant in value:
		if item_variant is Dictionary:
			result.append(_sanitize_public_dictionary(item_variant as Dictionary))
		elif _is_data_only(item_variant):
			result.append(item_variant)
	return result


func _sanitize_public_dictionary(value: Dictionary) -> Dictionary:
	var result := {}
	for key_variant in value.keys():
		var key_text := str(key_variant).strip_edges().to_lower()
		if PUBLIC_FORBIDDEN_KEYS.has(key_text):
			continue
		var nested: Variant = value[key_variant]
		if nested is Dictionary:
			result[key_variant] = _sanitize_public_dictionary(nested as Dictionary)
		elif nested is Array:
			result[key_variant] = _sanitize_public_array(nested)
		elif _is_data_only(nested):
			result[key_variant] = nested
	return result


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false
