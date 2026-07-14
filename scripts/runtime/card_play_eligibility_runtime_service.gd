@tool
extends Node
class_name CardPlayEligibilityRuntimeService

const CARD_PLAY_REQUIREMENT_POLICY := preload("res://scripts/cards/card_play_requirement_policy.gd")

const DIRECT_MONSTER_KINDS := [
	"move", "fly", "burrow", "attack", "charge_attack", "armor_gain", "guard",
	"area_damage", "miasma_shot", "miasma_bloom", "miasma_reclaim",
	"corrosive_breath", "roar", "roll_attack",
]
const EXTRA_MONSTER_TARGET_KINDS := ["monster_lure", "special_monster_delay", "mudslide", "monster_takeover"]
const PLAYER_TARGET_KINDS := ["player_hand_disrupt", "player_hand_steal"]
const COUNTERABLE_PLAYER_INTERACTION_KINDS := [
	"player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage",
]

var _configured := false
var _ruleset_id := ""
var _evaluation_count := 0
var _hand_evaluation_count := 0
var _product_market_runtime_controller: ProductMarketRuntimeController
var _city_gdp_derivative_runtime_controller: CityGdpDerivativeRuntimeController


func configure(ruleset_snapshot: Dictionary = {}) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	_configured = _ruleset_id == "v0.5"


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_city_gdp_derivative_runtime_controller(controller: CityGdpDerivativeRuntimeController) -> void:
	_city_gdp_derivative_runtime_controller = controller


func evaluate_play(request: Dictionary, facts: Dictionary) -> Dictionary:
	_evaluation_count += 1
	if not _is_data_only(request) or not _is_data_only(facts):
		return _result(false, false, "invalid_payload", {}, {}, {}, "rule")
	var skill := _dictionary(request.get("skill", {}))
	if str(skill.get("kind", "")) == "product_futures" and _dictionary(skill.get("futures_terms", {})).is_empty() and _product_market_runtime_controller != null:
		skill = _product_market_runtime_controller.skill_with_terms(str(skill.get("name", request.get("card_id", ""))), skill)
		request = request.duplicate(true)
		request["skill"] = skill
	if str(skill.get("kind", "")) == "city_gdp_derivative" and _dictionary(skill.get("gdp_derivative_terms", {})).is_empty() and _city_gdp_derivative_runtime_controller != null:
		skill = _city_gdp_derivative_runtime_controller.skill_with_terms(str(skill.get("name", request.get("card_id", ""))), skill)
		request = request.duplicate(true)
		request["skill"] = skill
	var mode := str(request.get("evaluation_mode", "rule"))
	var requirement := requirement_status(request, facts)
	var target := target_status(request, facts)
	var cash_cost := _cash_cost(skill, facts)
	var financial_terms := _financial_terms(skill)
	var financial_margin_cash := maxi(0, int(financial_terms.get("margin_cash", 0)))
	var common := {
		"cash_cost": cash_cost,
		"financial_margin_cash": financial_margin_cash,
		"financial_cash_required": cash_cost + financial_margin_cash,
		"financial_terms_version": str(financial_terms.get("terms_version", "")),
		"requirement_status": requirement,
		"industry_capacity_status": _dictionary(requirement.get("industry_capacity_status", {})),
		"capacity_reservation": _dictionary(requirement.get("capacity_reservation", {})),
		"target_status": target,
		"target_kind": str(target.get("target_kind", "none")),
		"target_required": bool(target.get("target_required", false)),
		"target_ready": bool(target.get("target_ready", true)),
		"targets_monster": bool(target.get("targets_monster", false)),
		"targets_player": bool(target.get("targets_player", false)),
		"requires_target_monster": bool(target.get("requires_target_monster", false)),
		"requires_target_player": bool(target.get("requires_target_player", false)),
		"queue_preflight": _dictionary(facts.get("queue_preflight", {})),
	}
	if mode == "catalog":
		return _result(true, false, "catalog_only", {}, requirement, target, mode, common)
	if mode == "hand":
		_hand_evaluation_count += 1
		return _evaluate_hand(request, facts, common)
	return _evaluate_rule(request, facts, common, mode)


func evaluate_hand(requests: Array, facts: Dictionary) -> Array:
	var results: Array = []
	for request_variant in requests:
		if not (request_variant is Dictionary):
			results.append(_result(false, false, "invalid_payload", {}, {}, {}, "hand"))
			continue
		var request := (request_variant as Dictionary).duplicate(true)
		request["evaluation_mode"] = "hand"
		results.append(evaluate_play(request, facts))
	return results


func requirement_status(request: Dictionary, facts: Dictionary) -> Dictionary:
	var skill := _dictionary(request.get("skill", {}))
	var profile := CARD_PLAY_REQUIREMENT_POLICY.requirement_for(str(skill.get("name", "")), skill)
	var required_percent := clampi(int(profile.get("required_share_percent", 0)), 0, 100)
	if str(skill.get("schema_version", "")) == "v0.5":
		required_percent = 0
	if str(skill.get("kind", "")) == "area_trade_contract":
		required_percent = maxi(0, required_percent - maxi(0, int(facts.get("contract_share_discount_percent", 0))))
	var scope := str(profile.get("scope", CARD_PLAY_REQUIREMENT_POLICY.SCOPE_OWN_BEST_REGION))
	var district_index := int(skill.get("play_requirement_district", -1))
	if district_index < 0:
		match scope:
			CARD_PLAY_REQUIREMENT_POLICY.SCOPE_TARGET_REGION:
				district_index = int(facts.get("selected_district", -1))
			CARD_PLAY_REQUIREMENT_POLICY.SCOPE_CONTRACT_SOURCE_REGION:
				district_index = int(facts.get("contract_source_district", -1))
			_:
				district_index = int(facts.get("best_share_district", -1))
	var share_by_district := _dictionary(facts.get("share_basis_points_by_district", {}))
	var current_basis_points := int(share_by_district.get(str(district_index), 0))
	var cash_cost := _cash_cost(skill, facts)
	var financial_margin_cash := maxi(0, int(_financial_terms(skill).get("margin_cash", 0)))
	profile["required_share_percent"] = required_percent
	profile["qualifying_district"] = district_index
	profile["current_share_basis_points"] = current_basis_points
	profile["current_share_percent"] = float(current_basis_points) / 100.0
	profile["requirement_satisfied"] = required_percent <= 0 or current_basis_points >= required_percent * 100
	profile["scope_label"] = CARD_PLAY_REQUIREMENT_POLICY.scope_label(scope)
	profile["cash_cost"] = cash_cost
	profile["financial_margin_cash"] = financial_margin_cash
	profile["requirement_text"] = _requirement_text(profile, cash_cost, financial_margin_cash)
	profile["chip_text"] = "免门槛" if required_percent <= 0 else "GDP≥%d%%" % required_percent
	var industry_capacity_status := _industry_requirement_status(request, facts)
	profile["industry_capacity_status"] = industry_capacity_status
	profile["capacity_reservation"] = _dictionary(industry_capacity_status.get("capacity_reservation", {}))
	profile["industry_capacity_satisfied"] = bool(industry_capacity_status.get("satisfied", false))
	return profile


func target_status(request: Dictionary, facts: Dictionary) -> Dictionary:
	var skill := _dictionary(request.get("skill", {}))
	var kind := str(skill.get("kind", ""))
	var targets_monster := DIRECT_MONSTER_KINDS.has(kind) \
		or EXTRA_MONSTER_TARGET_KINDS.has(kind) \
		or (kind == "military_command" and str(skill.get("military_command", "")) == "attack_monster")
	var targets_player := PLAYER_TARGET_KINDS.has(kind) or bool(skill.get("target_player_required", false))
	var monster_count := maxi(0, int(facts.get("monster_count", 0)))
	var player_count := maxi(0, int(facts.get("player_count", 0)))
	var requires_monster := monster_count > 0 and targets_monster
	var requires_player := player_count > 1 and targets_player
	var target_kind := "monster" if targets_monster else ("player" if targets_player else "none")
	var target_ready := true
	if targets_monster:
		target_ready = monster_count > 0
	elif targets_player:
		target_ready = player_count > 1
	return {
		"target_kind": target_kind,
		"is_counter": _is_counter(skill),
		"counterable_player_interaction": is_counterable_player_interaction(skill),
		"direct_monster_skill": DIRECT_MONSTER_KINDS.has(kind),
		"targets_monster": targets_monster,
		"targets_player": targets_player,
		"target_required": requires_monster or requires_player,
		"target_ready": target_ready,
		"requires_target_monster": requires_monster,
		"requires_target_player": requires_player,
	}


func requirement_profile(skill: Dictionary, facts: Dictionary = {}) -> Dictionary:
	return requirement_status({"skill": skill}, facts)


func audit_requirement_profiles(card_requests: Array) -> Dictionary:
	var issues: Array = []
	var rank_one_count := 0
	var rank_one_free_count := 0
	var rank_one_nonfree: Array = []
	var city_development_count := 0
	var family_values := {}
	for request_variant in card_requests:
		if not (request_variant is Dictionary):
			continue
		var request := request_variant as Dictionary
		var skill := _dictionary(request.get("skill", {}))
		var card_name := str(skill.get("name", request.get("card_name", "")))
		var profile := CARD_PLAY_REQUIREMENT_POLICY.requirement_for(card_name, skill)
		var rank := clampi(int(profile.get("rank", 1)), 1, 4)
		var required := int(profile.get("required_share_percent", 0))
		if rank == 1:
			rank_one_count += 1
			if required <= 0:
				rank_one_free_count += 1
			else:
				rank_one_nonfree.append(card_name)
		if str(skill.get("kind", "")) == "city_development":
			city_development_count += 1
			if required != 0:
				issues.append("%s城市发展牌不应有GDP门槛" % card_name)
		if int(skill.get("play_flow_required", 0)) > 0 and bool(skill.get("legacy_flow_gate_enabled", false)):
			issues.append("%s仍启用旧商品流动门槛" % card_name)
		var family := str(request.get("family", ""))
		if family != "":
			if not family_values.has(family):
				family_values[family] = []
			(family_values[family] as Array).append({"rank": rank, "required": required})
	for family_variant in family_values.keys():
		var values := family_values[family_variant] as Array
		values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("rank", 0)) < int(b.get("rank", 0)))
		for index in range(1, values.size()):
			if int((values[index] as Dictionary).get("required", 0)) < int((values[index - 1] as Dictionary).get("required", 0)):
				issues.append("%s GDP门槛梯度倒退" % str(family_variant))
				break
	if rank_one_count <= 0 or rank_one_free_count * 2 <= rank_one_count:
		issues.append("I级免门槛牌未超过半数")
	if city_development_count <= 0:
		issues.append("未生成城市发展牌")
	return {
		"ok": issues.is_empty(),
		"issues": issues,
		"rank_one_count": rank_one_count,
		"rank_one_free_count": rank_one_free_count,
		"rank_one_free_ratio": float(rank_one_free_count) / float(maxi(1, rank_one_count)),
		"rank_one_nonfree_cards": rank_one_nonfree,
		"city_development_card_count": city_development_count,
		"legacy_flow_gate_count": 0,
		"standard_gradient_percent": [0, 15, 25, 35],
		"high_impact_gradient_percent": [10, 20, 30, 40],
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"ruleset_id": _ruleset_id,
		"evaluation_count": _evaluation_count,
		"hand_evaluation_count": _hand_evaluation_count,
		"owns_play_eligibility": true,
		"owns_requirement_status": true,
		"owns_target_traits": true,
		"owns_rejection_precedence": true,
		"owns_industry_requirement_interpretation": true,
		"queue_authority": false,
		"execution_authority": false,
		"effect_authority": false,
		"presentation_authority": false,
		"world_mutation_authority": false,
		"legacy_main_fallback_active": false,
	}


func _evaluate_rule(request: Dictionary, facts: Dictionary, common: Dictionary, mode: String) -> Dictionary:
	var skill := _dictionary(request.get("skill", {}))
	var requirement := _dictionary(common.get("requirement_status", {}))
	var target := _dictionary(common.get("target_status", {}))
	if not bool(facts.get("player_valid", false)):
		return _result(false, false, "invalid_player", {}, requirement, target, mode, common)
	if bool(facts.get("player_eliminated", false)):
		return _result(false, false, "player_eliminated", {"player_name": str(facts.get("player_name", "玩家"))}, requirement, target, mode, common)
	var development_error := str(facts.get("city_development_error", ""))
	if str(skill.get("kind", "")) == "city_development" and development_error != "":
		return _result(false, false, "city_development_invalid", {"error": development_error}, requirement, target, mode, common)
	var contract_error := str(facts.get("contract_error", ""))
	if str(skill.get("kind", "")) == "area_trade_contract" and contract_error != "":
		return _result(false, false, "contract_invalid", {"error": contract_error}, requirement, target, mode, common)
	if _is_counter(skill):
		if not bool(facts.get("counter_window_active", false)) or not bool(facts.get("active_resolution_present", false)):
			return _result(false, false, "counter_window_closed", {}, requirement, target, mode, common)
		if not bool(facts.get("active_skill_counterable", false)):
			return _result(false, false, "counter_target_invalid", {}, requirement, target, mode, common)
	if str(skill.get("kind", "")) == "military_command":
		if not bool(facts.get("military_unit_present", false)):
			return _result(false, false, "military_unit_missing", {}, requirement, target, mode, common)
		if float(facts.get("military_unit_cooldown", 0.0)) > 0.0:
			return _result(false, false, "military_unit_cooldown", {"seconds": float(facts.get("military_unit_cooldown", 0.0))}, requirement, target, mode, common)
	if str(skill.get("kind", "")) == "military_force" and not bool(facts.get("military_deployment_valid", false)):
		return _result(false, false, "military_deployment_invalid", {"terrain_label": str(facts.get("military_deploy_terrain_label", "有效地形"))}, requirement, target, mode, common)
	if not bool(requirement.get("requirement_satisfied", false)):
		return _result(false, false, "gdp_share_insufficient", {
			"scope_label": str(requirement.get("scope_label", "任一经营区")),
			"required_percent": int(requirement.get("required_share_percent", 0)),
		}, requirement, target, mode, common)
	var industry_status := _dictionary(requirement.get("industry_capacity_status", {}))
	if not bool(industry_status.get("satisfied", false)):
		return _result(false, false, str(industry_status.get("reason_code", "industry_capacity_insufficient")), _dictionary(industry_status.get("reason_args", {})), requirement, target, mode, common)
	var cash_cost := int(common.get("cash_cost", 0))
	var cash := int(facts.get("player_cash", 0))
	if cash_cost > 0 and cash < cash_cost:
		return _result(false, false, "cash_insufficient", {"cash_cost": cash_cost, "cash": cash}, requirement, target, mode, common)
	var financial_margin_cash := int(common.get("financial_margin_cash", 0))
	if financial_margin_cash > 0 and cash < cash_cost + financial_margin_cash:
		return _result(false, false, "financial_margin_insufficient", {"cash_cost": cash_cost, "margin_cash": financial_margin_cash, "cash": cash}, requirement, target, mode, common)
	return _result(true, true, "playable", _playable_args(requirement, cash_cost, financial_margin_cash), requirement, target, mode, common)


func _evaluate_hand(request: Dictionary, facts: Dictionary, common: Dictionary) -> Dictionary:
	var skill := _dictionary(request.get("skill", {}))
	var requirement := _dictionary(common.get("requirement_status", {}))
	var target := _dictionary(common.get("target_status", {}))
	if not bool(facts.get("player_valid", false)):
		return _result(false, false, "invalid_player", {}, requirement, target, "hand", common)
	if bool(facts.get("player_eliminated", false)):
		return _result(false, false, "player_eliminated", {"player_name": str(facts.get("player_name", "玩家"))}, requirement, target, "hand", common)
	if bool(facts.get("game_over", false)):
		return _result(false, false, "game_over", {}, requirement, target, "hand", common)
	if bool(skill.get("queued_for_resolution", false)):
		return _result(false, false, "already_queued", {}, requirement, target, "hand", common)
	if bool(facts.get("pending_target_choice", false)):
		return _result(false, false, "pending_target_choice", {}, requirement, target, "hand", common)
	if bool(facts.get("monster_wager_freeze", false)):
		return _result(false, false, "monster_wager_freeze", {}, requirement, target, "hand", common)
	if bool(facts.get("forced_decision_pending", false)):
		return _result(false, false, "forced_decision_pending", {}, requirement, target, "hand", common)
	if float(facts.get("player_action_cooldown", 0.0)) > 0.0:
		return _result(false, false, "player_action_cooldown", {"seconds": float(facts.get("player_action_cooldown", 0.0))}, requirement, target, "hand", common)
	if float(skill.get("lock_left", 0.0)) > 0.0:
		return _result(false, false, "card_locked", {"seconds": float(skill.get("lock_left", 0.0))}, requirement, target, "hand", common)
	if float(skill.get("cooldown_left", 0.0)) > 0.0:
		return _result(false, false, "card_cooldown", {"seconds": float(skill.get("cooldown_left", 0.0))}, requirement, target, "hand", common)
	if bool(skill.get("starter_play_free", false)):
		if not bool(facts.get("selected_district_valid", false)):
			return _result(false, false, "starter_district_missing", {}, requirement, target, "hand", common)
		if bool(facts.get("selected_district_destroyed", false)):
			return _result(false, false, "starter_district_destroyed", {}, requirement, target, "hand", common)
		return _result(true, true, "starter_ready", {"district_name": str(facts.get("selected_district_name", "区域"))}, requirement, target, "hand", common)
	if _can_convert_monster_to_counter(skill, facts):
		return _result(true, true, "counter_conversion_ready", {}, requirement, target, "hand", common)
	if _is_counter(skill):
		if not bool(facts.get("counter_window_active", false)) or not bool(facts.get("active_resolution_present", false)):
			return _result(false, false, "counter_window_closed", {}, requirement, target, "hand", common)
		if not bool(facts.get("active_skill_counterable", false)):
			return _result(false, false, "counter_target_invalid", {}, requirement, target, "hand", common)
	if bool(target.get("targets_monster", false)) and int(facts.get("monster_count", 0)) <= 0:
		return _result(false, false, "monster_target_unavailable", {}, requirement, target, "hand", common)
	var contract_error := str(facts.get("contract_error", ""))
	if str(skill.get("kind", "")) == "area_trade_contract" and contract_error != "":
		return _result(false, false, "contract_invalid", {"error": contract_error}, requirement, target, "hand", common)
	var development_error := str(facts.get("city_development_error", ""))
	if str(skill.get("kind", "")) == "city_development" and development_error != "":
		return _result(false, false, "city_development_invalid", {"error": development_error}, requirement, target, "hand", common)
	if str(skill.get("kind", "")) == "military_command":
		if not bool(facts.get("military_unit_present", false)):
			return _result(false, false, "military_unit_missing", {}, requirement, target, "hand", common)
		if float(facts.get("military_unit_cooldown", 0.0)) > 0.0:
			return _result(false, false, "military_unit_cooldown", {"seconds": float(facts.get("military_unit_cooldown", 0.0))}, requirement, target, "hand", common)
	if str(skill.get("kind", "")) == "military_force" and not bool(facts.get("military_deployment_valid", false)):
		return _result(false, false, "military_deployment_invalid", {"terrain_label": str(facts.get("military_deploy_terrain_label", "有效地形"))}, requirement, target, "hand", common)
	var cash_cost := int(common.get("cash_cost", 0))
	var cash := int(facts.get("player_cash", 0))
	if cash_cost > 0 and cash < cash_cost:
		return _result(false, false, "cash_insufficient", {"cash_cost": cash_cost, "cash": cash}, requirement, target, "hand", common)
	var financial_margin_cash := int(common.get("financial_margin_cash", 0))
	if financial_margin_cash > 0 and cash < cash_cost + financial_margin_cash:
		return _result(false, false, "financial_margin_insufficient", {"cash_cost": cash_cost, "margin_cash": financial_margin_cash, "cash": cash}, requirement, target, "hand", common)
	if not bool(requirement.get("requirement_satisfied", false)):
		return _result(false, false, "gdp_share_insufficient", {
			"scope_label": str(requirement.get("scope_label", "任一经营区")),
			"required_percent": int(requirement.get("required_share_percent", 0)),
		}, requirement, target, "hand", common)
	var industry_status := _dictionary(requirement.get("industry_capacity_status", {}))
	if not bool(industry_status.get("satisfied", false)):
		return _result(false, false, str(industry_status.get("reason_code", "industry_capacity_insufficient")), _dictionary(industry_status.get("reason_args", {})), requirement, target, "hand", common)
	var desired_bid_cents := int(facts.get("desired_bid_cents", 0))
	var player_cash_cents := int(facts.get("player_cash_cents", cash * 100))
	var card_commitment_cents := (cash_cost + financial_margin_cash) * 100 + desired_bid_cents
	if desired_bid_cents > 0 and player_cash_cents < card_commitment_cents:
		return _result(false, false, "bid_reserve_insufficient", {
			"cash_cost_cents": cash_cost * 100,
			"margin_cents": financial_margin_cash * 100,
			"bid_cents": desired_bid_cents,
			"available_cash_cents": player_cash_cents,
		}, requirement, target, "hand", common)
	var playable_args := _playable_args(requirement, cash_cost, financial_margin_cash)
	if bool(target.get("requires_target_monster", false)):
		return _result(true, true, "needs_monster_target", playable_args, requirement, target, "hand", common)
	if bool(target.get("requires_target_player", false)):
		return _result(true, true, "needs_player_target", playable_args, requirement, target, "hand", common)
	return _result(true, true, "playable", playable_args, requirement, target, "hand", common)


func _industry_requirement_status(request: Dictionary, facts: Dictionary) -> Dictionary:
	var skill := _dictionary(request.get("skill", {}))
	if str(skill.get("schema_version", "")) == "v0.5" and str(skill.get("migration_status", "")) == "blocked":
		return {
			"satisfied": false,
			"reason_code": "v05_card_migration_blocked",
			"reason_args": {"card_id": str(skill.get("card_id", request.get("card_id", "")))},
			"requirements": [],
			"capacity_reservation": {},
		}
	var requirements_variant: Variant = skill.get("requirements", skill.get("requirements_v05", []))
	var requirements: Array = requirements_variant if requirements_variant is Array else []
	var availability: Dictionary = facts.get("industry_capacity_available", {}) if facts.get("industry_capacity_available", {}) is Dictionary else {}
	if requirements.is_empty():
		return {
			"satisfied": true,
			"reason_code": "",
			"reason_args": {},
			"requirements": [],
			"compatibility_mode": "v04_colorless",
			"capacity_reservation": {
				"capacity_revision": str(availability.get("capacity_revision", "")),
				"industries": {},
				"requirement_choices": [],
			},
		}
	if requirements.size() > 2:
		return {
			"satisfied": false,
			"reason_code": "too_many_primary_requirements",
			"reason_args": {"count": requirements.size()},
			"requirements": [],
			"capacity_reservation": {},
		}
	if not bool(availability.get("valid", false)):
		return {
			"satisfied": false,
			"reason_code": "industry_capacity_snapshot_missing",
			"reason_args": {},
			"requirements": [],
			"capacity_reservation": {},
		}
	var industries: Dictionary = availability.get("industries", {}) if availability.get("industries", {}) is Dictionary else {}
	var products: Dictionary = availability.get("products", {}) if availability.get("products", {}) is Dictionary else {}
	var product_industries: Dictionary = availability.get("product_industries", {}) if availability.get("product_industries", {}) is Dictionary else {}
	var remaining := {}
	for industry_id_variant in IndustryCapacityRuntimeService.REQUIRED_INDUSTRY_IDS:
		var industry_id := str(industry_id_variant)
		var industry_row: Dictionary = industries.get(industry_id, {}) if industries.get(industry_id, {}) is Dictionary else {}
		remaining[industry_id] = maxi(0, int(industry_row.get("available_capacity", 0)))
	var reservation := {}
	var normalized: Array = []
	var choices: Array = []
	for requirement_index in range(requirements.size()):
		if not (requirements[requirement_index] is Dictionary):
			return _industry_requirement_failure("invalid_industry_requirement", {"requirement_index": requirement_index}, normalized)
		var requirement := requirements[requirement_index] as Dictionary
		var kind := str(requirement.get("requirement_kind", ""))
		var required_capacity := maxi(0, int(requirement.get("required_capacity", 0)))
		var industry_ids_variant: Variant = requirement.get("industry_ids", [])
		var industry_ids: Array = industry_ids_variant if industry_ids_variant is Array else []
		var selected_industries: Array = []
		match kind:
			"colorless":
				if required_capacity != 0 or not industry_ids.is_empty() or str(requirement.get("product_id", "")) != "":
					return _industry_requirement_failure("invalid_colorless_requirement", {"requirement_index": requirement_index}, normalized)
			"single_industry":
				if industry_ids.size() != 1:
					return _industry_requirement_failure("invalid_single_industry_requirement", {"requirement_index": requirement_index}, normalized)
				selected_industries = [str(industry_ids[0])]
			"dual_industry":
				if industry_ids.size() != 2 or str(industry_ids[0]) == str(industry_ids[1]):
					return _industry_requirement_failure("invalid_dual_industry_requirement", {"requirement_index": requirement_index}, normalized)
				selected_industries = [str(industry_ids[0]), str(industry_ids[1])]
			"either_industry":
				if industry_ids.size() != 2 or str(industry_ids[0]) == str(industry_ids[1]):
					return _industry_requirement_failure("invalid_either_industry_requirement", {"requirement_index": requirement_index}, normalized)
				for candidate_variant in industry_ids:
					var candidate := str(candidate_variant)
					if int(remaining.get(candidate, -1)) >= required_capacity:
						selected_industries = [candidate]
						break
				if selected_industries.is_empty():
					return _industry_requirement_failure("industry_capacity_insufficient", {"industry_ids": industry_ids.duplicate(), "required_capacity": required_capacity}, normalized)
			"named_product":
				var product_id := str(requirement.get("product_id", ""))
				var required_product_gdp := maxi(0, int(requirement.get("required_product_gdp", 0)))
				if product_id.is_empty() or not products.has(product_id):
					return _industry_requirement_failure("unknown_named_product", {"product_id": product_id}, normalized)
				if int(products.get(product_id, 0)) < required_product_gdp:
					return _industry_requirement_failure("named_product_gdp_insufficient", {"product_id": product_id, "required_product_gdp": required_product_gdp, "current_product_gdp": int(products.get(product_id, 0))}, normalized)
				if required_capacity > 0:
					selected_industries = [str(product_industries.get(product_id, ""))]
			_:
				return _industry_requirement_failure("unknown_industry_requirement_kind", {"requirement_kind": kind}, normalized)
		for selected_variant in selected_industries:
			var selected_industry := str(selected_variant)
			if not remaining.has(selected_industry):
				return _industry_requirement_failure("unknown_industry", {"industry_id": selected_industry}, normalized)
			if int(remaining.get(selected_industry, 0)) < required_capacity:
				return _industry_requirement_failure("industry_capacity_insufficient", {"industry_id": selected_industry, "required_capacity": required_capacity, "available_capacity": int(remaining.get(selected_industry, 0))}, normalized)
			remaining[selected_industry] = int(remaining.get(selected_industry, 0)) - required_capacity
			reservation[selected_industry] = int(reservation.get(selected_industry, 0)) + required_capacity
		var influence_status := _requirement_influence_status(requirement, facts)
		if not bool(influence_status.get("satisfied", false)):
			return _industry_requirement_failure("influence_insufficient", influence_status, normalized)
		normalized.append({
			"requirement_index": requirement_index,
			"requirement_kind": kind,
			"required_capacity": required_capacity,
			"selected_industries": selected_industries.duplicate(),
			"product_id": str(requirement.get("product_id", "")),
			"required_product_gdp": maxi(0, int(requirement.get("required_product_gdp", 0))),
			"influence": influence_status,
		})
		choices.append({"requirement_index": requirement_index, "selected_industries": selected_industries.duplicate()})
	return {
		"satisfied": true,
		"reason_code": "",
		"reason_args": {},
		"requirements": normalized,
		"capacity_reservation": {
			"capacity_revision": str(availability.get("capacity_revision", "")),
			"industries": reservation,
			"requirement_choices": choices,
		},
	}


func _requirement_influence_status(requirement: Dictionary, facts: Dictionary) -> Dictionary:
	var required_influence_bp := maxi(0, int(requirement.get("required_influence_bp", 0)))
	var scope := str(requirement.get("region_scope", "none"))
	var district_index := int(facts.get("selected_district", -1))
	if scope in ["own_best_region", "best_region"]:
		district_index = int(facts.get("best_share_district", -1))
	var shares: Dictionary = facts.get("share_basis_points_by_district", {}) if facts.get("share_basis_points_by_district", {}) is Dictionary else {}
	var current_influence_bp := int(shares.get(str(district_index), 0))
	return {
		"satisfied": required_influence_bp <= 0 or current_influence_bp >= required_influence_bp,
		"region_scope": scope,
		"district_index": district_index,
		"required_influence_bp": required_influence_bp,
		"current_influence_bp": current_influence_bp,
	}


func _industry_requirement_failure(reason_code: String, reason_args: Dictionary, normalized: Array) -> Dictionary:
	return {
		"satisfied": false,
		"reason_code": reason_code,
		"reason_args": reason_args.duplicate(true),
		"requirements": normalized.duplicate(true),
		"capacity_reservation": {},
	}


func _playable_args(requirement: Dictionary, cash_cost: int, financial_margin_cash: int = 0) -> Dictionary:
	return {
		"scope_label": str(requirement.get("scope_label", "任一经营区")),
		"required_percent": int(requirement.get("required_share_percent", 0)),
		"cash_cost": cash_cost,
		"margin_cash": financial_margin_cash,
	}


func _cash_cost(skill: Dictionary, facts: Dictionary) -> int:
	var cost := maxi(0, int(skill.get("play_cash", 0)))
	cost += maxi(0, int(_financial_terms(skill).get("action_fee_cash", 0)))
	if str(skill.get("kind", "")) == "monster_card":
		cost += maxi(0, int(facts.get("monster_count", 0))) * int(skill.get("play_cash_per_monster", facts.get("default_monster_play_cash_per_existing", 0)))
	return cost


func _can_convert_monster_to_counter(skill: Dictionary, facts: Dictionary) -> bool:
	return bool(facts.get("role_can_convert_monster_to_counter", false)) \
		and str(skill.get("kind", "")) == "monster_card" \
		and bool(facts.get("counter_window_active", false)) \
		and bool(facts.get("active_resolution_present", false)) \
		and bool(facts.get("active_skill_counterable", false))


func _requirement_text(profile: Dictionary, cash_cost: int, financial_margin_cash: int = 0) -> String:
	var required_percent := int(profile.get("required_share_percent", 0))
	var text := "条件：无"
	if required_percent > 0:
		text = "条件：%sGDP份额≥%d%%" % [str(profile.get("scope_label", "任一经营区")), required_percent]
	if cash_cost > 0:
		text += "｜费用¥%d" % cash_cost
	if financial_margin_cash > 0:
		text += "｜保证金¥%d" % financial_margin_cash
	return text


func _result(allowed: bool, actionable: bool, reason_code: String, reason_args: Dictionary, requirement: Dictionary, target: Dictionary, mode: String, extras: Dictionary = {}) -> Dictionary:
	var result := {
		"allowed": allowed,
		"actionable": actionable,
		"reason_code": reason_code,
		"reason_args": reason_args.duplicate(true),
		"presentation_key": reason_code,
		"evaluation_mode": mode,
		"requirement_status": requirement.duplicate(true),
		"target_status": target.duplicate(true),
		"cash_cost": int(extras.get("cash_cost", requirement.get("cash_cost", 0))),
		"financial_margin_cash": int(extras.get("financial_margin_cash", requirement.get("financial_margin_cash", 0))),
		"financial_cash_required": int(extras.get("financial_cash_required", int(extras.get("cash_cost", requirement.get("cash_cost", 0))) + int(extras.get("financial_margin_cash", requirement.get("financial_margin_cash", 0))))),
		"financial_terms_version": str(extras.get("financial_terms_version", "")),
		"target_kind": str(extras.get("target_kind", target.get("target_kind", "none"))),
		"target_required": bool(extras.get("target_required", target.get("target_required", false))),
		"target_ready": bool(extras.get("target_ready", target.get("target_ready", true))),
		"targets_monster": bool(extras.get("targets_monster", target.get("targets_monster", false))),
		"targets_player": bool(extras.get("targets_player", target.get("targets_player", false))),
		"requires_target_monster": bool(extras.get("requires_target_monster", target.get("requires_target_monster", false))),
		"requires_target_player": bool(extras.get("requires_target_player", target.get("requires_target_player", false))),
		"queue_preflight": _dictionary(extras.get("queue_preflight", {})),
		"industry_capacity_status": _dictionary(extras.get("industry_capacity_status", requirement.get("industry_capacity_status", {}))),
		"capacity_reservation": _dictionary(extras.get("capacity_reservation", requirement.get("capacity_reservation", {}))),
	}
	return result


func _is_counter(skill: Dictionary) -> bool:
	return str(skill.get("kind", "")) == "card_counter"


func is_counterable_player_interaction(skill: Dictionary) -> bool:
	return COUNTERABLE_PLAYER_INTERACTION_KINDS.has(str(skill.get("kind", "")))


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _financial_terms(skill: Dictionary) -> Dictionary:
	var terms := _dictionary(skill.get("futures_terms", {}))
	if terms.is_empty():
		terms = _dictionary(skill.get("gdp_derivative_terms", {}))
	return terms


func _is_data_only(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
	elif value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
	return true
