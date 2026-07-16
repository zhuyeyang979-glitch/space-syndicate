@tool
extends Node
class_name CityDevelopmentRuntimeController

# Historical v0.5 fixture only. Production v0.6 uses RegionInfrastructureRuntimeController.

const PROJECT_STATE := preload("res://tests/legacy_v05/economy/city_product_project_state_v05.gd")
const PROJECT_BRIDGE := preload("res://tests/legacy_v05/economy/city_product_project_bridge_v05.gd")

const LEGACY_DIRECT_BUILD_REASON := "v0.4 城市发展必须通过真实城市发展卡绑定商品项目，不能直接建城。"
const LEGAL_SOURCE_KINDS := ["city_development_card", "product_project"]
const LEGACY_SOURCE_KINDS := ["direct_city_build", "legacy_direct_city_build", "ai_auto_build_city"]
const CITY_HP_BONUS := 8
const CITY_DAMAGE_REPAIR := 2
const CITY_BUILD_ANIMATION_SECONDS := 1.2
const ECONOMY_LEVEL_MIN := 1
const ECONOMY_LEVEL_MAX := 5

var _ruleset_id := ""
var _capabilities: Dictionary = {}
var _configured := false
var _accepted_request_count := 0
var _rejected_request_count := 0
var _legacy_rejection_count := 0
var _last_evaluation: Dictionary = {}
var _project_lifecycle_by_id: Dictionary = {}
var _planned_settlement_count := 0
var _committed_settlement_count := 0
var _failed_settlement_count := 0
var _last_settlement: Dictionary = {}


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	var capability_variant: Variant = ruleset_snapshot.get("capabilities", ruleset_snapshot)
	_capabilities = (capability_variant as Dictionary).duplicate(true) if capability_variant is Dictionary else {}
	_configured = _ruleset_id == "v0.4" and not _capabilities.is_empty()


func evaluate_development_request(request: Dictionary) -> Dictionary:
	var source_kind := str(request.get("source_kind", "")).strip_edges()
	var result := {
		"allowed": false,
		"disabled_reason": "",
		"source_kind": source_kind,
		"action_id": str(request.get("action_id", "")),
		"district_index": int(request.get("district_index", -1)),
		"product_id": str(request.get("product_id", "")).strip_edges(),
		"project_direction": str(request.get("project_direction", "")).strip_edges(),
		"project_id": str(request.get("project_id", "")).strip_edges(),
		"ruleset_id": _ruleset_id,
		"project_binding_required": project_binding_required(),
		"direct_build_allowed": direct_build_allowed(),
	}
	if not _configured:
		result["disabled_reason"] = "CityDevelopmentRuntimeController 尚未绑定 v0.4 Ruleset。"
	elif LEGACY_SOURCE_KINDS.has(source_kind) or (source_kind == "" and str(request.get("action_id", "")) in legacy_action_ids()):
		if direct_build_allowed():
			result["allowed"] = true
		else:
			result["disabled_reason"] = legacy_direct_build_reason()
			_legacy_rejection_count += 1
	elif not LEGAL_SOURCE_KINDS.has(source_kind):
		result["disabled_reason"] = "城市发展请求没有合法的卡牌或商品项目来源。"
	elif int(result["district_index"]) < 0:
		result["disabled_reason"] = "城市发展请求没有目标区域。"
	elif str(result["product_id"]) == "":
		result["disabled_reason"] = "城市发展请求没有绑定商品。"
	elif str(result["project_direction"]) == "":
		result["disabled_reason"] = "城市发展请求没有项目方向。"
	elif str(result["project_id"]) == "":
		result["disabled_reason"] = "城市发展请求没有项目 identity。"
	else:
		result["allowed"] = true
	if bool(result["allowed"]):
		_accepted_request_count += 1
	else:
		_rejected_request_count += 1
	_last_evaluation = result.duplicate(true)
	return result


func evaluate_development_site(facts: Dictionary) -> Dictionary:
	var player_index := int(facts.get("player_index", -1))
	var district_index := int(facts.get("district_index", -1))
	var result := {
		"allowed": false,
		"reason": "",
		"reason_code": "",
		"player_index": player_index,
		"district_index": district_index,
	}
	if not _configured:
		result["reason"] = "城市发展运行时控制器不可用。"
	elif bool(facts.get("game_over", false)):
		result["reason"] = "本局已结束"
	elif int(facts.get("player_count", 0)) <= 0:
		result["reason"] = "没有玩家"
	elif player_index < 0 or player_index >= int(facts.get("player_count", 0)):
		result["reason"] = "没有有效玩家"
	elif bool(facts.get("player_eliminated", false)):
		result["reason"] = "该玩家已经破产出局"
	elif district_index < 0 or district_index >= int(facts.get("district_count", 0)):
		result["reason"] = "没有选中区域"
	elif bool(facts.get("district_destroyed", false)):
		result["reason"] = "区域已毁"
	elif str(facts.get("terrain", "land")) == "ocean":
		result["reason"] = "海洋区只能运输，不能城市化"
	elif bool(facts.get("require_empty_city", false)) and bool(facts.get("city_active", false)):
		result["reason"] = "已有城市群"
	elif bool(facts.get("require_cooldown", false)) and float(facts.get("action_cooldown", 0.0)) > 0.0:
		result["reason"] = "行动冷却中"
	else:
		result["allowed"] = true
	result["reason_code"] = _reason_code_for(str(result.get("reason", "")))
	return result


func plan_settlement(request: Dictionary, current_facts: Dictionary) -> Dictionary:
	var normalized_request := request.duplicate(true)
	var district_index := int(normalized_request.get("district_index", -1))
	var product_id := str(normalized_request.get("product_id", "")).strip_edges()
	var direction := PROJECT_STATE.normalize_direction(str(normalized_request.get("project_direction", "production")))
	normalized_request["project_direction"] = direction
	var site_facts := current_facts.duplicate(true)
	site_facts["require_empty_city"] = false
	var site_status := evaluate_development_site(site_facts)
	var target_reason := _target_error(normalized_request, current_facts)
	var downstream_readiness: Dictionary = current_facts.get("downstream_owner_readiness", {}) as Dictionary if current_facts.get("downstream_owner_readiness", {}) is Dictionary else {}
	var downstream_ready := bool(downstream_readiness.get("network", false)) and bool(downstream_readiness.get("gdp", false)) and bool(downstream_readiness.get("market", false))
	if not bool(site_status.get("allowed", false)) or target_reason != "" or not downstream_ready:
		_failed_settlement_count += 1
		return _failed_plan(str(site_status.get("reason", "")) if not bool(site_status.get("allowed", false)) else (target_reason if target_reason != "" else "downstream_owner_unavailable"), normalized_request)
	var player: Dictionary = (current_facts.get("player", {}) as Dictionary).duplicate(true) if current_facts.get("player", {}) is Dictionary else {}
	var district: Dictionary = (current_facts.get("district", {}) as Dictionary).duplicate(true) if current_facts.get("district", {}) is Dictionary else {}
	if player.is_empty() or district.is_empty():
		_failed_settlement_count += 1
		return _failed_plan("城市发展世界事实不完整。", normalized_request)
	var city_variant: Variant = district.get("city", {})
	var city: Dictionary = normalize_city_runtime_fields_data((city_variant as Dictionary).duplicate(true), float(current_facts.get("legacy_turn_seconds", 30.0))) if city_variant is Dictionary else {}
	var created_city := not _city_is_active(city)
	if created_city:
		player["cities_built"] = int(player.get("cities_built", 0)) + 1
		district["hp"] = int(district.get("hp", 10)) + CITY_HP_BONUS
		district["damage"] = maxi(0, int(district.get("damage", 0)) - CITY_DAMAGE_REPAIR)
		city = _new_city_surface(int(normalized_request.get("player_index", -1)), district, current_facts)
	else:
		city = PROJECT_BRIDGE.normalize_city(city, district_index, int(current_facts.get("project_sequence", 1)))
	var contribution_order := int(current_facts.get("project_sequence", 1))
	var skill: Dictionary = (normalized_request.get("skill", {}) as Dictionary).duplicate(true) if normalized_request.get("skill", {}) is Dictionary else {}
	skill["product_id"] = product_id
	skill["project_direction"] = direction
	if normalized_request.has("slot_id"):
		skill["slot_id"] = str(normalized_request.get("slot_id", ""))
	if normalized_request.has("slot_index"):
		skill["slot_index"] = int(normalized_request.get("slot_index", -1))
	var slot_resolution := PROJECT_BRIDGE.resolve_development_slot(city, district_index, skill)
	if not bool(slot_resolution.get("valid", false)):
		_failed_settlement_count += 1
		return _failed_plan(str(slot_resolution.get("reason_code", "project_slot_unavailable")), normalized_request)
	normalized_request["slot_id"] = str(slot_resolution.get("slot_id", ""))
	normalized_request["slot_index"] = int(slot_resolution.get("slot_index", -1))
	normalized_request["generation"] = int(slot_resolution.get("generation", 1))
	normalized_request["project_id"] = str(slot_resolution.get("project_id", ""))
	var evaluation := evaluate_development_request(normalized_request)
	if not bool(evaluation.get("allowed", false)):
		_failed_settlement_count += 1
		return _failed_plan(str(evaluation.get("disabled_reason", "settlement_rejected")), normalized_request)
	var development := PROJECT_BRIDGE.apply_project_contribution(city, district_index, int(normalized_request.get("player_index", -1)), skill, contribution_order)
	if not bool(development.get("applied", false)):
		_failed_settlement_count += 1
		return _failed_plan(str(development.get("reason_code", "project_contribution_failed")), normalized_request)
	city = (development.get("city", {}) as Dictionary).duplicate(true)
	var project: Dictionary = (development.get("project", {}) as Dictionary).duplicate(true)
	var stable_project_id := str(project.get("project_id", normalized_request.get("project_id", "")))
	normalized_request["project_id"] = stable_project_id
	if direction == "commerce":
		district["transport_level"] = clampi(int(current_facts.get("next_transport_level", district.get("transport_level", 2))), ECONOMY_LEVEL_MIN, ECONOMY_LEVEL_MAX)
		district["transport_score"] = float(current_facts.get("next_transport_score", district.get("transport_score", 1.0)))
	district["city"] = city
	_planned_settlement_count += 1
	return {
		"valid": true,
		"reason": "",
		"reason_code": "",
		"request": normalized_request,
		"facts_fingerprint": str(current_facts.get("facts_fingerprint", "")),
		"expected_project_sequence": contribution_order,
		"player_index": int(normalized_request.get("player_index", -1)),
		"district_index": district_index,
		"product_id": product_id,
		"project_direction": direction,
		"project_id": stable_project_id,
		"slot_id": str(project.get("slot_id", normalized_request.get("slot_id", ""))),
		"slot_index": int(project.get("slot_index", normalized_request.get("slot_index", -1))),
		"generation": int(project.get("generation", normalized_request.get("generation", 1))),
		"project_rank": int(project.get("rank", project.get("level", 1))),
		"created_city_surface": created_city,
		"staged_player": player,
		"staged_district": district,
		"district_name": str(current_facts.get("district_name", "区域")),
		"district_center": (current_facts.get("district_center", {}) as Dictionary).duplicate(true) if current_facts.get("district_center", {}) is Dictionary else {},
		"district_radius": float(current_facts.get("district_radius", 70.0)),
		"player_accent": str(current_facts.get("player_accent", "#67e8f9")),
		"action_id": str(normalized_request.get("action_id", "")),
		"source_label": str(skill.get("name", "城市发展牌")),
	}


func validate_settlement_plan(plan: Dictionary, current_facts: Dictionary) -> Dictionary:
	if not bool(plan.get("valid", false)):
		var plan_reason := str(plan.get("reason_code", plan.get("reason", "plan_invalid")))
		return {"valid": false, "reason": plan_reason, "reason_code": plan_reason}
	if str(plan.get("facts_fingerprint", "")) == "" or str(plan.get("facts_fingerprint", "")) != str(current_facts.get("facts_fingerprint", "")):
		return {"valid": false, "reason": "world_facts_changed", "reason_code": "world_facts_changed"}
	if int(plan.get("expected_project_sequence", -1)) != int(current_facts.get("project_sequence", -2)):
		return {"valid": false, "reason": "project_sequence_changed", "reason_code": "project_sequence_changed"}
	var downstream_readiness: Dictionary = current_facts.get("downstream_owner_readiness", {}) as Dictionary if current_facts.get("downstream_owner_readiness", {}) is Dictionary else {}
	if not bool(downstream_readiness.get("network", false)) or not bool(downstream_readiness.get("gdp", false)) or not bool(downstream_readiness.get("market", false)):
		return {"valid": false, "reason": "downstream_owner_unavailable", "reason_code": "downstream_owner_unavailable"}
	var request: Dictionary = plan.get("request", {}) as Dictionary if plan.get("request", {}) is Dictionary else {}
	var target_reason := _target_error(request, current_facts)
	if target_reason != "":
		var target_reason_code := _reason_code_for(target_reason)
		return {"valid": false, "reason": target_reason, "reason_code": target_reason_code}
	return {"valid": true, "reason": "", "reason_code": ""}


func finalize_settlement(receipt: Dictionary) -> Dictionary:
	var project_id := str(receipt.get("project_id", ""))
	if not bool(receipt.get("applied", false)):
		if project_id != "":
			_project_lifecycle_by_id.erase(project_id)
		_failed_settlement_count += 1
		_last_settlement = _sanitize_settlement_receipt(receipt)
		return {
			"resolved": false,
			"committed": false,
			"reason": str(receipt.get("reason", "settlement_failed")),
			"reason_code": str(receipt.get("reason_code", _reason_code_for(str(receipt.get("reason", "settlement_failed"))))),
			"project_id": project_id,
			"event_intents": {},
		}
	var resolved_lifecycle := record_project_resolved(receipt)
	_committed_settlement_count += 1
	_last_settlement = _sanitize_settlement_receipt(receipt)
	var district_name := str(receipt.get("district_name", "区域"))
	var product_id := str(receipt.get("product_id", "商品"))
	var direction := str(receipt.get("project_direction", "production"))
	var direction_label := PROJECT_STATE.direction_label(direction)
	var created_city := bool(receipt.get("created_city_surface", false))
	var own_share := float(receipt.get("own_share_percent", 0.0))
	var source_label := str(receipt.get("source_label", "城市发展牌"))
	var event_intents := {
		"private_economic_events": [{
			"player_index": int(receipt.get("player_index", -1)),
			"category": "项目贡献",
			"source": source_label,
			"amount": 0,
			"detail": "%s｜%s%s｜我的份额%.2f%%" % [district_name, product_id, direction_label, own_share],
		}],
		"map_effects": ([{
			"kind": "city_rise",
			"position": (receipt.get("district_center", {}) as Dictionary).duplicate(true) if receipt.get("district_center", {}) is Dictionary else {},
			"accent": str(receipt.get("player_accent", "#67e8f9")),
			"label": "项目落成",
			"duration": CITY_BUILD_ANIMATION_SECONDS + 0.55,
			"radius": float(receipt.get("district_radius", 70.0)),
		}] if created_city else []),
		"district_pulses": [{"district_index": int(receipt.get("district_index", -1)), "accent": str(receipt.get("player_accent", "#67e8f9"))}],
		"public_callouts": [{
			"title": "匿名财团",
			"badge": "商品项目%s" % ("建立" if created_city else "强化"),
			"detail": "%s的%s%s项目进入运营；贡献份额与控制者保持私密，公开GDP按项目显示。" % [district_name, product_id, direction_label],
			"accent": "#67e8f9",
			"position": (receipt.get("district_center", {}) as Dictionary).duplicate(true) if receipt.get("district_center", {}) is Dictionary else {},
		}],
		"first_table_followup": true,
		"scenario_signals": [
			{"signal_id": "city_development_resolved", "message": "城市发展牌完成结算：%s出现%s%s项目，份额保持私密。" % [district_name, product_id, direction_label], "step": "after_project", "surface": "player_board"},
			{"signal_id": "city_built", "message": "完成城市化：%s出现匿名商品项目。" % district_name, "step": "after_build", "surface": "scenario_coach"},
		],
	}
	return {
		"resolved": true,
		"committed": true,
		"reason": "",
		"reason_code": "",
		"event_receipt_id": str(receipt.get("event_receipt_id", "")),
		"player_index": int(receipt.get("player_index", -1)),
		"project_id": project_id,
		"district_index": int(receipt.get("district_index", -1)),
		"product_id": product_id,
		"project_direction": direction,
		"current_gdp": int(receipt.get("current_gdp", 0)),
		"own_share_percent": own_share,
		"created_city_surface": created_city,
		"lifecycle": resolved_lifecycle,
		"event_intents": event_intents,
	}


func record_project_opened(project_data: Dictionary) -> Dictionary:
	var lifecycle := _sanitize_project_lifecycle(project_data, "opened")
	var project_id := str(lifecycle.get("project_id", ""))
	if project_id == "":
		return {}
	_project_lifecycle_by_id[project_id] = lifecycle
	return lifecycle.duplicate(true)


func record_project_resolved(result_data: Dictionary) -> Dictionary:
	var lifecycle := _sanitize_project_lifecycle(result_data, "resolved")
	var project_id := str(lifecycle.get("project_id", ""))
	if project_id == "":
		return {}
	var previous: Dictionary = _project_lifecycle_by_id.get(project_id, {}) as Dictionary
	for key in previous.keys():
		var current_value: Variant = lifecycle.get(key, null)
		if not lifecycle.has(key) or (current_value is String and str(current_value) == ""):
			lifecycle[key] = previous[key]
	_project_lifecycle_by_id[project_id] = lifecycle
	return lifecycle.duplicate(true)


func direct_build_allowed() -> bool:
	return bool(_capabilities.get("direct_city_build_allowed", false))


func project_binding_required() -> bool:
	return bool(_capabilities.get("city_development_requires_product_project", true))


func legacy_direct_build_reason() -> String:
	return "" if direct_build_allowed() else LEGACY_DIRECT_BUILD_REASON


func legacy_action_ids() -> Array[String]:
	return ["build", "build_city", "coach_build_city", "keyboard_b", "ai_auto_build_city"]


func reset_state() -> void:
	_accepted_request_count = 0
	_rejected_request_count = 0
	_legacy_rejection_count = 0
	_last_evaluation = {}
	_project_lifecycle_by_id = {}
	_planned_settlement_count = 0
	_committed_settlement_count = 0
	_failed_settlement_count = 0
	_last_settlement = {}


func debug_snapshot() -> Dictionary:
	var projects: Array = []
	var project_ids: Array[String] = []
	for project_id_variant in _project_lifecycle_by_id.keys():
		project_ids.append(str(project_id_variant))
	project_ids.sort()
	for project_id in project_ids:
		projects.append((_project_lifecycle_by_id.get(project_id, {}) as Dictionary).duplicate(true))
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"ruleset_id": _ruleset_id,
		"direct_build_allowed": direct_build_allowed(),
		"project_binding_required": project_binding_required(),
		"legacy_action_ids": legacy_action_ids(),
		"accepted_request_count": _accepted_request_count,
		"rejected_request_count": _rejected_request_count,
		"legacy_rejection_count": _legacy_rejection_count,
		"last_evaluation": _last_evaluation.duplicate(true),
		"project_count": projects.size(),
		"projects": projects,
		"settlement_owner": true,
		"planned_settlement_count": _planned_settlement_count,
		"committed_settlement_count": _committed_settlement_count,
		"failed_settlement_count": _failed_settlement_count,
		"last_settlement": _last_settlement.duplicate(true),
	}


static func normalize_city_runtime_fields_data(city_value: Dictionary, legacy_turn_seconds: float = 30.0) -> Dictionary:
	var city := city_value.duplicate(true)
	if city.is_empty():
		return city
	var safe_legacy_seconds := maxf(0.001, legacy_turn_seconds)
	if not city.has("contract_seconds"):
		city["contract_seconds"] = float(maxi(0, int(city.get("contract_turns", 0)))) * safe_legacy_seconds
	city["contract_seconds"] = maxf(0.0, float(city.get("contract_seconds", 0.0)))
	city["contract_turns"] = int(ceil(float(city["contract_seconds"]) / safe_legacy_seconds)) if float(city["contract_seconds"]) > 0.0 else 0
	if not city.has("route_flow_seconds"):
		city["route_flow_seconds"] = float(maxi(0, int(city.get("route_flow_turns", 0)))) * safe_legacy_seconds
	city["route_flow_seconds"] = maxf(0.0, float(city.get("route_flow_seconds", 0.0)))
	city["route_flow_turns"] = int(ceil(float(city["route_flow_seconds"]) / safe_legacy_seconds)) if float(city["route_flow_seconds"]) > 0.0 else 0
	city.erase("cashflow_remainder")
	city.erase("project_cashflow_remainder_by_player")
	var defaults := {
		"gdp_cashflow_remainder_by_source_id": {},
		"last_cashflow_rate": int(city.get("last_income", 0)),
		"cashflow_paid_total": 0,
		"military_gdp_penalty": 0,
		"military_pressure_until": 0.0,
		"military_pressure_source": "",
		"warehouse_stockpile_count": 0,
		"warehouse_stockpile_units": 0,
		"warehouse_stockpile_products": [],
		"warehouse_stockpile_expires_at": -1.0,
	}
	for key in defaults.keys():
		if not city.has(key):
			city[key] = defaults[key]
	return city


func _target_error(request: Dictionary, facts: Dictionary) -> String:
	var allowed_terrains: Array = request.get("allowed_terrains", []) if request.get("allowed_terrains", []) is Array else []
	var skill_variant: Variant = request.get("skill", {})
	if allowed_terrains.is_empty() and skill_variant is Dictionary:
		allowed_terrains = (skill_variant as Dictionary).get("allowed_terrains", []) if (skill_variant as Dictionary).get("allowed_terrains", []) is Array else []
	var terrain := str(facts.get("terrain", "land"))
	if not allowed_terrains.is_empty() and not allowed_terrains.has(terrain):
		return "这项城市发展不适配目标地形"
	var product_id := str(request.get("product_id", "")).strip_edges()
	var local_products: Array = facts.get("local_product_ids", []) if facts.get("local_product_ids", []) is Array else []
	if product_id == "" or not local_products.has(product_id):
		return "目标区域没有%s商品潜力" % (product_id if product_id != "" else "对应")
	return ""


func _new_city_surface(player_index: int, district: Dictionary, facts: Dictionary) -> Dictionary:
	var district_index := int(facts.get("district_index", -1))
	var stable_region_id := PROJECT_STATE.region_id(district_index, str(district.get("region_id", "")))
	return {
		"project_schema_version": PROJECT_STATE.PROJECT_SCHEMA_VERSION,
		"region_id": stable_region_id,
		"project_slots": PROJECT_STATE.create_project_slots(district_index, stable_region_id),
		"project_tombstones": [],
		"legacy_owner_is_project_authority": false,
		# Transitional display/legacy-domain projection. Project identity, GDP, and cashflow never read it.
		"owner": player_index,
		"active": true,
		"level": 1,
		"gdp_focus": str(district.get("economic_focus", "balanced")),
		"gdp_focus_label": str(facts.get("economic_focus_label", district.get("economic_focus_label", "均衡区"))),
		"products": [], "demands": [], "projects": [],
		"revenue_bonus": 0,
		"contract_income_bonus": 0, "contract_seconds": 0.0, "contract_turns": 0, "contract_source": "",
		"route_flow_multiplier": 1.0, "route_flow_seconds": 0.0, "route_flow_turns": 0, "route_flow_source": "",
		"last_income": 0, "last_cashflow_rate": 0,
		"gdp_cashflow_remainder_by_source_id": {}, "cashflow_paid_total": 0,
		"last_gdp": 0, "last_gdp_delta": 0, "last_gdp_cycle": -1, "last_gdp_source": "",
		"last_gdp_reason": "城市发展项目刚刚建立", "gdp_history": [],
		"competition_matches": 0, "trade_routes": [], "trade_disrupted_routes": 0, "trade_route_damage": 0,
		"military_gdp_penalty": 0, "military_pressure_until": 0.0, "military_pressure_source": "",
		"warehouse_stockpile_count": 0, "warehouse_stockpile_units": 0, "warehouse_stockpile_products": [], "warehouse_stockpile_expires_at": -1.0,
		"supplied_demands": 0,
		"built_at": float(facts.get("game_time", 0.0)),
		"last_public_clue": "", "public_clues": [],
	}


func _failed_plan(reason: String, request: Dictionary) -> Dictionary:
	var stable_reason := reason if reason != "" else "settlement_rejected"
	return {
		"valid": false,
		"reason": stable_reason,
		"reason_code": _reason_code_for(stable_reason),
		"request": request.duplicate(true),
		"project_id": str(request.get("project_id", "")),
	}


func _city_is_active(city: Dictionary) -> bool:
	return not city.is_empty() and bool(city.get("active", true))


func _sanitize_settlement_receipt(source: Dictionary) -> Dictionary:
	return {
		"applied": bool(source.get("applied", false)),
		"reason": str(source.get("reason", "")),
		"reason_code": str(source.get("reason_code", _reason_code_for(str(source.get("reason", ""))))),
		"project_id": str(source.get("project_id", "")),
		"slot_id": str(source.get("slot_id", "")),
		"slot_index": int(source.get("slot_index", -1)),
		"generation": int(source.get("generation", 0)),
		"district_index": int(source.get("district_index", -1)),
		"product_id": str(source.get("product_id", "")),
		"project_direction": str(source.get("project_direction", "")),
		"created_city_surface": bool(source.get("created_city_surface", false)),
		"current_gdp": maxi(0, int(source.get("current_gdp", 0))),
		"own_share_percent": maxf(0.0, float(source.get("own_share_percent", 0.0))),
		"rollback_used": bool(source.get("rollback_used", false)),
	}


func _reason_code_for(reason: String) -> String:
	match reason:
		"": return ""
		"城市发展运行时控制器不可用。": return "runtime_unavailable"
		"本局已结束": return "game_over"
		"没有玩家", "没有有效玩家": return "invalid_player"
		"该玩家已经破产出局": return "player_eliminated"
		"没有选中区域": return "invalid_district"
		"区域已毁": return "district_destroyed"
		"海洋区只能运输，不能城市化": return "ocean_district"
		"已有城市群": return "city_already_active"
		"行动冷却中": return "action_cooldown"
		"该区域没有此商品，无法建立对应商品项目。": return "product_not_local"
		"该项目方向无效。": return "invalid_project_direction"
		"城市发展世界事实不完整。": return "world_facts_incomplete"
		_: return reason.to_snake_case()


func _sanitize_project_lifecycle(source: Dictionary, state: String) -> Dictionary:
	return {
		"project_id": str(source.get("project_id", "")).strip_edges(),
		"slot_id": str(source.get("slot_id", "")).strip_edges(),
		"slot_index": int(source.get("slot_index", -1)),
		"generation": int(source.get("generation", 0)),
		"district_index": int(source.get("district_index", -1)),
		"product_id": str(source.get("product_id", "")).strip_edges(),
		"project_direction": str(source.get("project_direction", source.get("direction", ""))).strip_edges(),
		"source_kind": str(source.get("source_kind", "city_development_card")),
		"action_id": str(source.get("action_id", "")),
		"state": state,
		"created_city_surface": bool(source.get("created_city_surface", false)),
		"current_gdp": maxi(0, int(source.get("current_gdp", 0))),
		"own_share_percent": maxf(0.0, float(source.get("own_share_percent", 0.0))),
	}
