extends RefCounted
class_name CardPlayRequirementPolicy

## Field-driven play requirement policy.
##
## Purchase price and target legality remain separate concerns.  This policy
## only answers whether a card needs economic standing before it can be
## committed to the public resolution track.

const KIND_NONE := "none"
const KIND_REGION_GDP_SHARE := "region_gdp_share"

const SCOPE_TARGET_REGION := "target_region"
const SCOPE_OWN_BEST_REGION := "own_best_region"
const SCOPE_CONTRACT_SOURCE_REGION := "contract_source_region"

const BASE_SHARE_BY_RANK := {
	1: 0,
	2: 15,
	3: 25,
	4: 35,
}

const HIGH_IMPACT_SHARE_BY_RANK := {
	1: 10,
	2: 20,
	3: 30,
	4: 40,
}

const ALWAYS_FREE_KINDS := [
	"monster_bound_action",
	"military_command",
]

const HIGH_IMPACT_KINDS := [
	"monster_takeover",
	"player_hand_disrupt",
	"player_hand_steal",
	"city_control_dispute",
	"global_barrage",
	"card_counter",
]

const TARGET_REGION_KINDS := [
	"city_revenue_boost",
	"route_insurance",
	"city_product_upgrade",
	"city_product_shift",
	"city_demand_shift",
	"market_stabilize",
	"product_growth_boon",
	"route_flow_boon",
	"city_contract_boon",
	"region_economy_shift",
]


static func requirement_for(card_name: String, skill: Dictionary) -> Dictionary:
	var rank := card_rank(card_name, skill)
	var scope := _scope_for(skill)
	var required_percent := _required_share_percent(rank, skill)
	var requirement_kind := KIND_REGION_GDP_SHARE if required_percent > 0 else KIND_NONE
	if skill.has("play_requirement_kind"):
		requirement_kind = String(skill.get("play_requirement_kind", requirement_kind))
	if skill.has("play_region_scope"):
		scope = String(skill.get("play_region_scope", scope))
	if skill.has("play_region_gdp_share_required"):
		required_percent = clampi(int(skill.get("play_region_gdp_share_required", required_percent)), 0, 100)
		requirement_kind = KIND_REGION_GDP_SHARE if required_percent > 0 else KIND_NONE
	if requirement_kind == KIND_NONE:
		required_percent = 0
	return {
		"kind": requirement_kind,
		"scope": scope,
		"required_share_percent": required_percent,
		"rank": rank,
		"legacy_product_affinity": String(skill.get("supply_product", skill.get("play_product", ""))),
	}


static func apply_to_card(card_name: String, skill: Dictionary) -> Dictionary:
	var result := skill.duplicate(true)
	var requirement := requirement_for(card_name, result)
	result["play_requirement_kind"] = String(requirement.get("kind", KIND_NONE))
	result["play_region_scope"] = String(requirement.get("scope", SCOPE_OWN_BEST_REGION))
	result["play_region_gdp_share_required"] = int(requirement.get("required_share_percent", 0))
	# Fixed products now describe regional supply affinity, not a consumable play gate.
	if String(result.get("supply_product", "")) == "" and String(result.get("play_product", "")) != "":
		result["supply_product"] = String(result.get("play_product", ""))
	result["play_flow_required"] = 0
	return result


static func card_rank(card_name: String, skill: Dictionary) -> int:
	var explicit_rank := int(skill.get("rank", 0))
	if explicit_rank > 0:
		return clampi(explicit_rank, 1, 4)
	var digits := ""
	var index := card_name.length() - 1
	while index >= 0:
		var character := card_name.substr(index, 1)
		if not "0123456789".contains(character):
			break
		digits = character + digits
		index -= 1
	return clampi(int(digits) if digits != "" else 1, 1, 4)


static func scope_label(scope: String) -> String:
	match scope:
		SCOPE_TARGET_REGION:
			return "目标区域"
		SCOPE_CONTRACT_SOURCE_REGION:
			return "合约发起区"
	return "任一经营区"


static func _required_share_percent(rank: int, skill: Dictionary) -> int:
	if bool(skill.get("starter_play_free", false)):
		return 0
	var kind := String(skill.get("kind", ""))
	if ALWAYS_FREE_KINDS.has(kind):
		return 0
	var high_impact := HIGH_IMPACT_KINDS.has(kind) or bool(skill.get("card_access_global", false))
	var table := HIGH_IMPACT_SHARE_BY_RANK if high_impact else BASE_SHARE_BY_RANK
	var result := int(table.get(clampi(rank, 1, 4), 0))
	return clampi(result, 0, 100)


static func _scope_for(skill: Dictionary) -> String:
	var kind := String(skill.get("kind", ""))
	if kind == "area_trade_contract":
		return SCOPE_CONTRACT_SOURCE_REGION
	if TARGET_REGION_KINDS.has(kind) and not _has_hostile_region_effect(skill):
		return SCOPE_TARGET_REGION
	return SCOPE_OWN_BEST_REGION


static func _has_hostile_region_effect(skill: Dictionary) -> bool:
	if int(skill.get("route_damage", 0)) > 0 or int(skill.get("damage", 0)) > 0:
		return true
	for field_name in ["production_delta", "transport_delta", "consumption_delta", "price_delta"]:
		if int(skill.get(field_name, 0)) < 0:
			return true
	return false
