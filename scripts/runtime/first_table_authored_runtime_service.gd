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

@export var scenario_id := "first_table"

var _configured := false
var _scenario_definition: Dictionary = {}
var _fixture: Dictionary = {}
var _catalog_resolution_count := 0
var _content_composition_count := 0
var _context_composition_count := 0
var _score_count := 0
var _pacing_evaluation_count := 0
var _supply_plan_count := 0


func configure(config: Dictionary = {}) -> void:
	_configured = false
	_scenario_definition.clear()
	_fixture.clear()
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
	_configured = not _fixture.is_empty()


func fixture_snapshot() -> Dictionary:
	return _fixture.duplicate(true) if _configured else {}


func market_listing_plan() -> Dictionary:
	if not _configured:
		return {}
	var source_district_index := int(_fixture.get("facility_market_source_district_index", -1))
	return {
		"scenario_id": scenario_id,
		"source_district_index": source_district_index,
		"ready": source_district_index >= 0,
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


func supply_plan(resolved_catalog: Dictionary) -> Dictionary:
	_supply_plan_count += 1
	if not _configured or not _is_data_only(resolved_catalog):
		return {}
	var followup_card_id := str(resolved_catalog.get("followup_card_id", "")).strip_edges()
	return {
		"scenario_id": scenario_id,
		"ready": followup_card_id != "",
		"followup_card_id": followup_card_id,
		"inject_after_signal": "public_facility_committed",
		"supply_source_id": "first_table_pacing_guarantee",
		"preserve_monster_guarantee": true,
	}


func resolve_content_catalog(catalog_snapshot: Dictionary) -> Dictionary:
	_catalog_resolution_count += 1
	if not _configured or not _is_data_only(catalog_snapshot):
		return _empty_catalog()
	var available_cards := _string_set(catalog_snapshot.get("card_ids", []))
	var available_monsters := _string_set(catalog_snapshot.get("monster_ids", []))
	var available_products := _string_set(catalog_snapshot.get("product_ids", []))
	var preferred_products := _filtered_fixture_ids("preferred_product_ids", available_products)
	var public_facility_ids: Array = []
	var runtime_card_ids: Array = []
	var facility_cards_variant: Variant = catalog_snapshot.get("public_facility_cards", [])
	var facility_cards: Array = facility_cards_variant if facility_cards_variant is Array else []
	for card_variant in facility_cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		var card_id := str(card.get("card_id", card.get("id", ""))).strip_edges()
		if card_id == "" or int(card.get("rank", 1)) != 1 or not bool(available_cards.get(card_id, false)):
			continue
		_append_unique_string(public_facility_ids, card_id)
		_append_unique_string(runtime_card_ids, card_id)
	var followup_ids := _filtered_fixture_ids("followup_card_ids", available_cards)
	for card_id_variant in followup_ids:
		_append_unique_string(runtime_card_ids, str(card_id_variant))
	var featured_ids := _filtered_fixture_ids("featured_card_ids", available_cards)
	var starter_ids := _filtered_fixture_ids("starter_monster_ids", available_monsters)
	var followup_card_id := str(followup_ids[0]) if not followup_ids.is_empty() else ""
	return {
		"scenario_id": scenario_id,
		"teaching_card_kind": "public_facility",
		"runtime_card_ids": runtime_card_ids,
		"public_facility_card_ids": public_facility_ids,
		"followup_card_ids": followup_ids,
		"followup_card_id": followup_card_id,
		"featured_card_ids": featured_ids,
		"starter_monster_ids": starter_ids,
		"preferred_product_ids": preferred_products,
	}


func select_teaching_product(district_snapshot: Dictionary, resolved_catalog: Dictionary = {}) -> String:
	if not _configured or not _is_data_only(district_snapshot) or not _is_data_only(resolved_catalog):
		return ""
	var products: Array = []
	for key in ["city_product_ids", "public_project_product_ids", "district_product_ids", "district_demand_ids"]:
		for value_variant in _string_array(district_snapshot.get(key, [])):
			var value := str(value_variant)
			if value != "公共通商":
				_append_unique_string(products, value)
	var preferred_products := _string_array(resolved_catalog.get("preferred_product_ids", []))
	for preferred_variant in preferred_products:
		var preferred_product := str(preferred_variant)
		if products.has(preferred_product):
			return preferred_product
	var remote_demands := _string_set(district_snapshot.get("remote_demand_product_ids", []))
	for product_variant in products:
		var product_id := str(product_variant)
		if bool(remote_demands.get(product_id, false)):
			return product_id
	return str(products[0]) if not products.is_empty() else ""


func compose_runtime_content(world_snapshot: Dictionary, resolved_catalog: Dictionary) -> Dictionary:
	_content_composition_count += 1
	if not _configured or not _is_data_only(world_snapshot) or not _is_data_only(resolved_catalog):
		return {}
	var teaching_card_ids := _string_array(resolved_catalog.get("runtime_card_ids", []))
	var teaching_card_id := str(world_snapshot.get("teaching_card_id", "")).strip_edges()
	if teaching_card_id == "":
		teaching_card_id = str(world_snapshot.get("fallback_teaching_card_id", "")).strip_edges()
	if teaching_card_id == "":
		var facility_ids := _string_array(resolved_catalog.get("public_facility_card_ids", []))
		teaching_card_id = str(facility_ids[0]) if not facility_ids.is_empty() else ""
	if teaching_card_id != "":
		_append_unique_string(teaching_card_ids, teaching_card_id)
	var owned_facilities := _data_array(world_snapshot.get("owned_facilities", []))
	var city_present := bool(world_snapshot.get("city_present", false)) or not owned_facilities.is_empty()
	var share_text := "尚未建立公共设施"
	if city_present:
		var facility_labels: Array = []
		for facility_variant in owned_facilities:
			if not (facility_variant is Dictionary):
				continue
			var facility: Dictionary = facility_variant
			facility_labels.append("%s%s %d级" % [str(facility.get("industry_id", "通用")), str(facility.get("facility_type", "设施")), int(facility.get("rank", 1))])
		if not facility_labels.is_empty():
			share_text = "、".join(facility_labels)
	var gdp_per_minute := maxi(0, int(world_snapshot.get("gdp_per_minute", 0))) if city_present else 0
	var cashflow_paid_total := maxi(0, int(world_snapshot.get("cashflow_paid_total", 0))) if city_present else 0
	var starter_monster_id := str(world_snapshot.get("starter_monster_id", "")).strip_edges()
	var starter_ids := _string_array(resolved_catalog.get("starter_monster_ids", []))
	if starter_monster_id == "" and not starter_ids.is_empty():
		starter_monster_id = str(starter_ids[0])
	if starter_monster_id == "":
		starter_monster_id = "起始怪兽"
	var visible_monster_name := str(world_snapshot.get("visible_monster_name", "")).strip_edges()
	if visible_monster_name == "":
		visible_monster_name = starter_monster_id
	return {
		"scenario_id": scenario_id,
		"district_index": int(world_snapshot.get("district_index", -1)),
		"district_name": str(world_snapshot.get("district_name", "推荐区域")),
		"teaching_product_id": str(world_snapshot.get("teaching_product_id", "")),
		"teaching_card_id": teaching_card_id,
		"teaching_card_ids": teaching_card_ids,
		"teaching_card_kind": str(resolved_catalog.get("teaching_card_kind", "public_facility")),
		"followup_card_id": str(resolved_catalog.get("followup_card_id", "")),
		"featured_card_ids": _string_array(resolved_catalog.get("featured_card_ids", [])),
		"starter_monster_id": starter_monster_id,
		"starter_monster_ids": starter_ids,
		"preferred_product_ids": _string_array(resolved_catalog.get("preferred_product_ids", [])),
		"city_present": city_present,
		"city_product_ids": _string_array(world_snapshot.get("city_product_ids", [])) if city_present else [],
		"city_demand_ids": _string_array(world_snapshot.get("city_demand_ids", [])) if city_present else [],
		"public_projects": _sanitize_public_array(world_snapshot.get("public_projects", [])),
		"owned_facilities": owned_facilities,
		"urbanization_share_text": share_text,
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
	var product_id := str(content_snapshot.get("teaching_product_id", "真实商品"))
	var card_id := str(content_snapshot.get("teaching_card_id", "城市发展牌"))
	var followup_card_id := str(content_snapshot.get("followup_card_id", "经营牌"))
	var monster_id := str(content_snapshot.get("visible_monster_name", content_snapshot.get("starter_monster_id", "怪兽")))
	match str(contextual.get("id", "")):
		"select_district":
			contextual["detail"] = "推荐：%s｜商品链：%s。推荐只改变镜头与提示，不改变建城规则。" % [district_name, product_id]
		"buy_development", "play_development":
			contextual["detail"] = "发展牌：%s｜商品线：%s。RightInspector 会显示方向、目标、效果与 disabled reason。" % [card_id, product_id]
		"establish_project":
			contextual["detail"] = "当前我的份额：%s｜我的项目 GDP/min %d。其他玩家的贡献与控制者保持隐藏。" % [str(content_snapshot.get("urbanization_share_text", "待建立")), int(content_snapshot.get("gdp_per_minute", 0))]
		"check_economy":
			contextual["detail"] = "%s 我的项目 GDP/min %d｜已结算项目分红 %d。" % [district_name, int(content_snapshot.get("gdp_per_minute", 0)), int(content_snapshot.get("cashflow_paid_total", 0))]
		"buy_followup", "play_followup":
			contextual["detail"] = "第二张经营牌：%s｜项目落成时已放入项目所在区牌架，商品流动与目标城市仍按真实规则检查。" % followup_card_id
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
	return "首局任务完成：%s已建立%s，当前 GDP/min %d；你已读过匿名牌轨、AI公开线索和%s的怪兽压力。整局仍继续。" % [
		str(content_snapshot.get("district_name", "推荐区域")),
		str(content_snapshot.get("urbanization_share_text", "城市化份额")),
		int(content_snapshot.get("gdp_per_minute", 0)),
		str(content_snapshot.get("visible_monster_name", "怪兽")),
	]


func completion_label(content_snapshot: Dictionary) -> String:
	if not _configured or not _is_data_only(content_snapshot):
		return ""
	return "首局完成｜GDP %d/min｜整局继续" % int(content_snapshot.get("gdp_per_minute", 0))


func score_district(district_snapshot: Dictionary, resolved_catalog: Dictionary) -> int:
	_score_count += 1
	if not _configured or not _is_data_only(district_snapshot) or not _is_data_only(resolved_catalog) or not bool(district_snapshot.get("build_allowed", false)):
		return -1000000
	var products := _string_array(district_snapshot.get("product_ids", []))
	var demands := _string_array(district_snapshot.get("demand_ids", []))
	var score := products.size() * 30 + demands.size() * 12
	score += int(round(float(district_snapshot.get("transport_score", 1.0)) * 20.0))
	for preferred_variant in _string_array(resolved_catalog.get("preferred_product_ids", [])):
		var preferred_product := str(preferred_variant)
		if products.has(preferred_product):
			score += 80
		if demands.has(preferred_product):
			score += 24
	var remote_demands := _string_set(district_snapshot.get("remote_demand_product_ids", []))
	for product_variant in products:
		if bool(remote_demands.get(str(product_variant), false)):
			score += 18
	return score


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
		"pacing_milestone_count": (pacing_profile().get("milestones", []) as Array).size(),
		"legacy_authored_fallback_used": false,
	}


func _empty_catalog() -> Dictionary:
	return {"scenario_id": scenario_id, "teaching_card_kind": "public_facility", "runtime_card_ids": [], "public_facility_card_ids": [], "followup_card_ids": [], "followup_card_id": "", "featured_card_ids": [], "starter_monster_ids": [], "preferred_product_ids": []}


func _filtered_fixture_ids(key: String, available: Dictionary) -> Array:
	var values: Array = []
	for value_variant in _string_array(_fixture.get(key, [])):
		var value := str(value_variant)
		if bool(available.get(value, false)):
			values.append(value)
	return values


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
