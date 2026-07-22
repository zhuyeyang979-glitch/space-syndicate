@tool
extends Node
class_name CardPlayEligibilityRuntimeService

const CARD_PLAY_REQUIREMENT_POLICY := preload("res://scripts/cards/card_play_requirement_policy.gd")
const ASSET_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const V06_ASSET_COST_KEYS := ["life", "energy", "industry", "technology", "commerce", "shipping", "generic"]

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
const PUBLIC_FACILITY_PREFLIGHT_REJECTIONS := [
	"public_facility_target_unavailable",
	"public_facility_slot_occupied",
	"public_facility_slot_incompatible",
	"public_facility_product_unavailable",
	"public_facility_card_unavailable",
	"public_facility_preflight_unavailable",
]

var _configured := false
var _ruleset_id := ""
var _evaluation_count := 0
var _hand_evaluation_count := 0
var _product_market_runtime_controller: ProductMarketRuntimeController
var _city_gdp_derivative_runtime_controller: CityGdpDerivativeRuntimeController


func configure(ruleset_snapshot: Dictionary = {}) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	_configured = _ruleset_id == "v0.6"


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_city_gdp_derivative_runtime_controller(controller: CityGdpDerivativeRuntimeController) -> void:
	_city_gdp_derivative_runtime_controller = controller


func evaluate_play(request: Dictionary, facts: Dictionary) -> Dictionary:
	_evaluation_count += 1
	if not _is_data_only(request) or not _is_data_only(facts):
		return _result(false, false, "invalid_payload", {}, {}, {}, "rule")
	var skill := _dictionary(request.get("skill", {}))
	if str(skill.get("kind", "")) == "city_development":
		return _result(false, false, "legacy_card_kind_retired", {"replacement_kind": "public_facility"}, {}, {}, str(request.get("evaluation_mode", "rule")))
	if str(skill.get("kind", "")) == "card_access_boon":
		return _result(false, false, "legacy_card_kind_retired", {"replacement_kind": "pending_card_data_migration"}, {}, {}, str(request.get("evaluation_mode", "rule")))
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
		"asset_status": _dictionary(requirement.get("asset_status", {})),
		"asset_cost": _dictionary(requirement.get("asset_cost", {})),
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
	if str(skill.get("schema_version", "")) in ["v0.5", "v0.6"] or str(skill.get("kind", "")) == "public_facility":
		required_percent = 0
	var scope := str(profile.get("scope", CARD_PLAY_REQUIREMENT_POLICY.SCOPE_OWN_BEST_REGION))
	var district_index := int(skill.get("play_requirement_district", -1))
	if district_index < 0:
		match scope:
			CARD_PLAY_REQUIREMENT_POLICY.SCOPE_TARGET_REGION:
				district_index = int(facts.get("selected_district", -1))
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
	var asset_status := _asset_requirement_status(request, facts)
	profile["asset_status"] = asset_status
	profile["asset_cost"] = _dictionary(asset_status.get("asset_cost", {}))
	profile["asset_requirement_satisfied"] = bool(asset_status.get("satisfied", false))
	return profile


func target_status(request: Dictionary, facts: Dictionary) -> Dictionary:
	var skill := _dictionary(request.get("skill", {}))
	var kind := str(skill.get("kind", ""))
	var targets_facility := kind == "public_facility"
	var targets_monster := DIRECT_MONSTER_KINDS.has(kind) \
		or EXTRA_MONSTER_TARGET_KINDS.has(kind) \
		or (kind == "military_command" and str(skill.get("military_command", "")) == "attack_monster")
	var targets_player := PLAYER_TARGET_KINDS.has(kind) or bool(skill.get("target_player_required", false))
	var monster_count := maxi(0, int(facts.get("monster_count", 0)))
	var player_count := maxi(0, int(facts.get("player_count", 0)))
	var requires_monster := monster_count > 0 and targets_monster
	var requires_player := player_count > 1 and targets_player
	var target_kind := "region_unique_facility_slot" if targets_facility else ("monster" if targets_monster else ("player" if targets_player else "none"))
	var target_ready := true
	if targets_facility:
		target_ready = bool(facts.get("selected_district_valid", false)) \
			and not bool(facts.get("selected_district_destroyed", false)) \
			and bool(_facility_target_preflight_status(facts).get("ready", false))
	elif targets_monster:
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
		"target_required": targets_facility or requires_monster or requires_player,
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
	var public_facility_count := 0
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
		if str(skill.get("kind", "")) == "public_facility":
			public_facility_count += 1
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
	return {
		"ok": issues.is_empty(),
		"issues": issues,
		"rank_one_count": rank_one_count,
		"rank_one_free_count": rank_one_free_count,
		"rank_one_free_ratio": float(rank_one_free_count) / float(maxi(1, rank_one_count)),
		"rank_one_nonfree_cards": rank_one_nonfree,
		"public_facility_card_count": public_facility_count,
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
		"owns_asset_requirement_interpretation": true,
		"industry_capacity_requirement_retired": true,
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
	if str(skill.get("kind", "")) == "public_facility":
		if int(facts.get("selected_district", -1)) < 0 or bool(facts.get("selected_district_destroyed", false)):
			return _result(false, false, "public_facility_target_unavailable", {}, requirement, target, mode, common)
		var facility_preflight := _facility_target_preflight_status(facts)
		if not bool(facility_preflight.get("ready", false)):
			return _result(false, false, str(facility_preflight.get("reason_code", "public_facility_preflight_unavailable")), {}, requirement, target, mode, common)
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
	var asset_status := _dictionary(requirement.get("asset_status", {}))
	if not bool(asset_status.get("satisfied", false)):
		return _result(false, false, str(asset_status.get("reason_code", "asset_insufficient")), _dictionary(asset_status.get("reason_args", {})), requirement, target, mode, common)
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
	if str(skill.get("kind", "")) == "public_facility":
		if int(facts.get("selected_district", -1)) < 0 or bool(facts.get("selected_district_destroyed", false)):
			return _result(false, false, "public_facility_target_unavailable", {}, requirement, target, "hand", common)
		var facility_preflight := _facility_target_preflight_status(facts)
		if not bool(facility_preflight.get("ready", false)):
			return _result(false, false, str(facility_preflight.get("reason_code", "public_facility_preflight_unavailable")), {}, requirement, target, "hand", common)
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
	var asset_status := _dictionary(requirement.get("asset_status", {}))
	if not bool(asset_status.get("satisfied", false)):
		return _result(false, false, str(asset_status.get("reason_code", "asset_insufficient")), _dictionary(asset_status.get("reason_args", {})), requirement, target, "hand", common)
	var playable_args := _playable_args(requirement, cash_cost, financial_margin_cash)
	if bool(target.get("requires_target_monster", false)):
		return _result(true, true, "needs_monster_target", playable_args, requirement, target, "hand", common)
	if bool(target.get("requires_target_player", false)):
		return _result(true, true, "needs_player_target", playable_args, requirement, target, "hand", common)
	return _result(true, true, "playable", playable_args, requirement, target, "hand", common)


func _asset_requirement_status(request: Dictionary, facts: Dictionary) -> Dictionary:
	var skill := _dictionary(request.get("skill", {}))
	var source_cost: Variant = request.get("asset_cost", skill.get("asset_cost", {}))
	if not (source_cost is Dictionary):
		return _asset_requirement_failure("asset_cost_invalid", {})
	if str(skill.get("schema_version", "")) == "v0.6":
		for required_key in V06_ASSET_COST_KEYS:
			if not (source_cost as Dictionary).has(required_key):
				# Do not disclose which authored machine key is absent. The public
				# eligibility surface only needs a safe, actionable fail-closed reason.
				return _asset_requirement_failure("asset_cost_unavailable", {})
	var asset_cost := {"generic": 0}
	for asset_id_variant in ASSET_IDS:
		asset_cost[str(asset_id_variant)] = 0
	for key_variant in (source_cost as Dictionary).keys():
		var asset_id := str(key_variant)
		if asset_id != "generic" and not ASSET_IDS.has(asset_id):
			return _asset_requirement_failure("asset_cost_unknown_color", {"asset_id": asset_id})
		var amount_variant: Variant = (source_cost as Dictionary).get(key_variant, 0)
		if not (amount_variant is int) or int(amount_variant) < 0:
			return _asset_requirement_failure("asset_cost_invalid_amount", {"asset_id": asset_id})
		asset_cost[asset_id] = int(amount_variant)
	var required_total := 0
	for amount_variant in asset_cost.values():
		required_total += maxi(0, int(amount_variant))
	if required_total <= 0:
		return {
			"satisfied": true,
			"reason_code": "",
			"reason_args": {},
			"asset_cost": asset_cost,
			"asset_revision": int(_dictionary(facts.get("player_mana", {})).get("revision", 0)),
			"authoritative_allocation_owner": "PlayerManaRuntimeController",
		}
	var availability := _dictionary(facts.get("player_mana", {}))
	if not bool(availability.get("valid", false)):
		return _asset_requirement_failure("player_mana_snapshot_missing", {}, asset_cost)
	var available := _dictionary(availability.get("assets", {}))
	var generic_available := 0
	for asset_id_variant in ASSET_IDS:
		var asset_id := str(asset_id_variant)
		var fixed_cost := maxi(0, int(asset_cost.get(asset_id, 0)))
		var color_available := maxi(0, int(available.get(asset_id, 0)))
		if fixed_cost > color_available:
			return _asset_requirement_failure("asset_insufficient", {
				"asset_id": asset_id,
				"required_assets": fixed_cost,
				"available_assets": color_available,
			}, asset_cost)
		generic_available += color_available - fixed_cost
	var generic_cost := maxi(0, int(asset_cost.get("generic", 0)))
	if generic_cost > generic_available:
		return _asset_requirement_failure("generic_asset_insufficient", {
			"required_assets": generic_cost,
			"available_assets": generic_available,
		}, asset_cost)
	return {
		"satisfied": true,
		"reason_code": "",
		"reason_args": {},
		"asset_cost": asset_cost,
		"asset_revision": int(availability.get("revision", 0)),
		"authoritative_allocation_owner": "PlayerManaRuntimeController",
	}


func _asset_requirement_failure(reason_code: String, reason_args: Dictionary, asset_cost: Dictionary = {}) -> Dictionary:
	return {
		"satisfied": false,
		"reason_code": reason_code,
		"reason_args": reason_args.duplicate(true),
		"asset_cost": asset_cost.duplicate(true),
		"authoritative_allocation_owner": "PlayerManaRuntimeController",
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
		"asset_status": _dictionary(extras.get("asset_status", requirement.get("asset_status", {}))),
		"asset_cost": _dictionary(extras.get("asset_cost", requirement.get("asset_cost", {}))),
	}
	return result


func _is_counter(skill: Dictionary) -> bool:
	return str(skill.get("kind", "")) == "card_counter"


func _facility_target_preflight_status(facts: Dictionary) -> Dictionary:
	var source := _dictionary(facts.get("facility_target_preflight", {}))
	if not bool(source.get("applicable", false)):
		return {"ready": false, "reason_code": "public_facility_preflight_unavailable"}
	if bool(source.get("ready", false)):
		return {"ready": true, "reason_code": "public_facility_target_ready"}
	var reason_code := str(source.get("reason_code", ""))
	if not PUBLIC_FACILITY_PREFLIGHT_REJECTIONS.has(reason_code):
		reason_code = "public_facility_preflight_unavailable"
	return {"ready": false, "reason_code": reason_code}


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
