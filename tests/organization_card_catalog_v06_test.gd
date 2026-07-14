extends SceneTree

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const RANK_LABELS := ["", "I", "II", "III", "IV"]
const COMMON_PAYLOAD_FIELDS := [
	"organization_axis", "organization_family_id", "organization_rank", "organization_slot_cost",
	"organization_slot_limit", "install_policy", "stack_policy", "replacement_requires_higher_rank",
	"equal_or_lower_rank_resolution", "activation_window_offset", "activation_snapshot_timing", "persistence",
	"required_own_gdp_min", "required_positive_gdp_color_count", "public_clue_kind", "counterplay_tags",
	"anti_snowball_cap", "direct_player_interaction", "counterable", "phase_veto_eligible",
	"ordinary_submission_cost", "counts_as_normal_card_submission", "ai_effect_tags",
]

const FAMILY_SPECS := {
	"organization.starport_clearinghouse": {
		"name": "星港清算所", "axis": "asset_conversion", "industry": "generic",
		"cash": [6, 10, 15, 21], "assets": [3, 5, 8, 12], "gdp": [0, 30, 60, 100], "colors": [1, 2, 2, 3],
		"bonus": [500, 1000, 1500, 2000], "cap": [50, 100, 150, 200],
	},
	"organization.quantum_agenda_network": {
		"name": "量子议程网", "axis": "action_bandwidth", "industry": "generic",
		"cash": [7, 11, 16, 22], "assets": [4, 7, 11, 16], "gdp": [0, 36, 72, 108], "colors": [1, 2, 2, 3],
		"surcharge": [4, 3, 2, 1],
	},
	"organization.deep_space_archive": {
		"name": "深空档案库", "axis": "hand_capacity", "industry": "technology",
		"cash": [5, 8, 12, 17], "assets": [2, 4, 6, 9], "gdp": [0, 24, 54, 90], "colors": [1, 1, 2, 3],
		"hand": [6, 7, 8, 9],
	},
	"organization.monster_liaison_charter": {
		"name": "巨兽联络章程", "axis": "monster_binding", "industry": "life",
		"cash": [6, 10, 15, 21], "assets": [3, 5, 8, 12], "gdp": [0, 42, 84, 132], "colors": [1, 2, 3, 3],
		"count": [1, 1, 2, 2], "primary": [3, 4, 4, 4], "secondary": [0, 0, 2, 4],
	},
	"organization.stellar_command_directorate": {
		"name": "星环统帅部", "axis": "military_command", "industry": "industry",
		"cash": [6, 10, 15, 21], "assets": [3, 5, 8, 12], "gdp": [0, 42, 84, 132], "colors": [1, 2, 3, 3],
		"count": [1, 1, 2, 2], "primary": [3, 4, 4, 4], "secondary": [0, 0, 2, 4],
	},
}

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(catalog != null, "v0.6 catalog resource loads for organization audit")
	if catalog == null:
		_finish()
		return
	var report := catalog.reload()
	_expect(bool(report.get("valid", false)), "catalog remains structurally valid: %s" % JSON.stringify(report.get("errors", [])))
	var categories: Dictionary = report.get("category_counts", {}) if report.get("category_counts", {}) is Dictionary else {}
	_expect(int(categories.get("organization", 0)) == 20, "organization category contains exactly 20 ranked cards")
	var organization_ids: Array[String] = []
	for card_id in catalog.card_ids():
		var card := catalog.card_snapshot(card_id)
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("category_id", "")) == "organization":
			organization_ids.append(card_id)
	_expect(organization_ids.size() == 20, "organization audit sees only the five complete I-IV ladders")
	_expect(FAMILY_SPECS.size() == 5, "organization spec declares five strategic families")

	for family_variant in FAMILY_SPECS.keys():
		_verify_family(catalog, str(family_variant), FAMILY_SPECS[family_variant] as Dictionary)
	_verify_global_monster_upgrade_contract(catalog)
	_verify_metadata(catalog)
	_finish()


func _verify_family(catalog: CardRuntimeCatalogV06Resource, family_id: String, spec: Dictionary) -> void:
	var previous_cash := -1
	var previous_assets := -1
	var previous_gdp := -1
	var previous_colors := -1
	for rank in range(1, 5):
		var card_id := "%s.rank_%d" % [family_id, rank]
		var card := catalog.card_snapshot(card_id)
		_expect(not card.is_empty(), "%s exists" % card_id)
		if card.is_empty():
			continue
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var player: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
		var developer: Dictionary = card.get("developer", {}) if card.get("developer", {}) is Dictionary else {}
		var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
		var rank_index := rank - 1

		_expect(str(machine.get("family_id", "")) == family_id, "%s preserves its stable family ID" % card_id)
		_expect(int(machine.get("rank", 0)) == rank, "%s preserves its numeric rank" % card_id)
		_expect(str(machine.get("category_id", "")) == "organization", "%s uses the organization category" % card_id)
		_expect(str(machine.get("effect_kind", "")) == "install_organization_upgrade", "%s uses the unified install effect" % card_id)
		_expect(str(machine.get("target_kind", "")) == "self_organization_slot", "%s only targets self" % card_id)
		_expect(str(machine.get("acquisition_kind", "")) == "dynamic_market_cash", "%s is purchased from the cash market" % card_id)
		_expect(bool(machine.get("counts_toward_hand_limit", false)), "%s occupies the ordinary hand before installation" % card_id)
		_expect(int(machine.get("purchase_cash", -1)) == int((spec.cash as Array)[rank_index]), "%s uses its exact purchase ladder" % card_id)
		_expect(_asset_total(machine.get("asset_cost", {})) == int((spec.assets as Array)[rank_index]), "%s uses its exact asset ladder" % card_id)
		_expect(str(machine.get("industry_id", "")) == str(spec.industry), "%s uses the intended asset color" % card_id)

		for field_name in COMMON_PAYLOAD_FIELDS:
			_expect(payload.has(field_name), "%s exposes AI-readable %s" % [card_id, field_name])
		_expect(str(payload.get("organization_family_id", "")) == family_id, "%s payload preserves family identity" % card_id)
		_expect(str(payload.get("organization_axis", "")) == str(spec.axis), "%s payload preserves strategic axis" % card_id)
		_expect(int(payload.get("organization_rank", 0)) == rank, "%s payload preserves organization rank" % card_id)
		_expect(int(payload.get("organization_slot_cost", 0)) == 1 and int(payload.get("organization_slot_limit", 0)) == 3, "%s consumes one of three organization slots" % card_id)
		_expect(str(payload.get("install_policy", "")) == "upgrade_highest_rank_only", "%s only upgrades its family" % card_id)
		_expect(str(payload.get("stack_policy", "")) == "highest_rank_nonstacking", "%s cannot stack same-family ranks" % card_id)
		_expect(bool(payload.get("replacement_requires_higher_rank", false)), "%s only replaces with a higher rank" % card_id)
		_expect(str(payload.get("equal_or_lower_rank_resolution", "")) == "reject_before_consume", "%s rejects non-upgrades before consumption" % card_id)
		_expect(int(payload.get("activation_window_offset", 0)) == 1 and str(payload.get("activation_snapshot_timing", "")) == "next_window_start", "%s activates from the next window snapshot" % card_id)
		_expect(str(payload.get("persistence", "")) == "run", "%s persists for the current run" % card_id)
		_expect(int(payload.get("ordinary_submission_cost", 0)) == 1 and bool(payload.get("counts_as_normal_card_submission", false)), "%s consumes one ordinary submission" % card_id)
		_expect(not bool(payload.get("direct_player_interaction", true)), "%s is not direct player interaction" % card_id)
		_expect(not bool(payload.get("counterable", true)) and not bool(payload.get("phase_veto_eligible", true)), "%s cannot be targeted by phase veto" % card_id)
		_expect((payload.get("counterplay_tags", []) as Array).size() >= 2, "%s exposes at least two public counterplay axes" % card_id)
		_expect(payload.get("anti_snowball_cap", {}) is Dictionary and not (payload.get("anti_snowball_cap", {}) as Dictionary).is_empty(), "%s exposes an anti-snowball cap" % card_id)
		_expect(str(payload.get("public_clue_kind", "")) == "installed_organization_axis_aura", "%s leaves the standard public installation clue" % card_id)
		_expect((payload.get("ai_effect_tags", []) as Array).has(str(spec.axis)), "%s exposes its axis to generic AI scoring" % card_id)
		_expect(int(payload.get("required_own_gdp_min", -1)) == int((spec.gdp as Array)[rank_index]), "%s uses its exact own-GDP gate" % card_id)
		_expect(int(payload.get("required_positive_gdp_color_count", -1)) == int((spec.colors as Array)[rank_index]), "%s uses its exact GDP-color gate" % card_id)

		_expect(str(player.get("name", "")) == str(spec.name), "%s keeps concise player-facing name" % card_id)
		_expect(str(player.get("rank", "")) == RANK_LABELS[rank], "%s displays Roman rank" % card_id)
		_expect(str(player.get("type", "")) == "组织牌", "%s displays the organization type" % card_id)
		_expect(str(player.get("target", "")) == "你的一个组织槽", "%s explains the self target" % card_id)
		_expect(str(player.get("timing", "")).contains("次窗生效"), "%s explains delayed activation" % card_id)
		_expect(_keyword_texts(player).has("组织") and _keyword_texts(player).has("常驻") and _keyword_texts(player).has("次窗生效") and _keyword_texts(player).has(_axis_label(str(spec.axis))), "%s exposes shared and axis-specific organization keywords" % card_id)
		_expect(str(developer.get("implementation_status", "")) == "catalog_ready_runtime_wiring_pending", "%s does not claim runtime wiring" % card_id)
		_expect(str(developer.get("runtime_owner", "")) == "organization_runtime_owner_pending", "%s names its unresolved runtime owner honestly" % card_id)

		var cash := int(machine.get("purchase_cash", 0))
		var assets := _asset_total(machine.get("asset_cost", {}))
		var gdp := int(payload.get("required_own_gdp_min", 0))
		var colors := int(payload.get("required_positive_gdp_color_count", 0))
		if rank > 1:
			_expect(cash > previous_cash, "%s cash cost strictly increases" % family_id)
			_expect(assets > previous_assets, "%s asset cost strictly increases" % family_id)
			_expect(gdp >= previous_gdp and colors >= previous_colors, "%s eligibility gates never regress" % family_id)
		previous_cash = cash
		previous_assets = assets
		previous_gdp = gdp
		previous_colors = colors
		_verify_axis_fields(card_id, rank, spec, payload)


func _verify_axis_fields(card_id: String, rank: int, spec: Dictionary, payload: Dictionary) -> void:
	var rank_index := rank - 1
	match str(spec.axis):
		"asset_conversion":
			_expect(int(payload.get("asset_conversion_bonus_bp", 0)) == int((spec.bonus as Array)[rank_index]), "%s uses exact conversion bonus" % card_id)
			_expect(int(payload.get("asset_conversion_bonus_cap_milli_per_second", 0)) == int((spec.cap as Array)[rank_index]), "%s uses exact conversion cap" % card_id)
			_expect(str(payload.get("scope", "")) == "same_color_gdp_only", "%s only converts same-color GDP" % card_id)
		"action_bandwidth":
			_expect(int(payload.get("ordinary_submission_bonus", 0)) == 1, "%s grants exactly one regular extra submission" % card_id)
			_expect(int(payload.get("extra_submission_asset_surcharge", 0)) == int((spec.surcharge as Array)[rank_index]), "%s uses exact extra-submission surcharge" % card_id)
			_expect(int(payload.get("ordinary_submission_hard_cap", 0)) == 3, "%s preserves the three-card hard cap" % card_id)
			_expect(int(payload.get("burst_window_period", -1)) == (3 if rank == 4 else 0), "%s reserves burst only for rank IV" % card_id)
			_expect(int(payload.get("burst_submission_bonus", -1)) == (1 if rank == 4 else 0), "%s uses exact rank-IV burst bonus" % card_id)
			_expect(bool(payload.get("response_cards_ignore_ordinary_submission_limit", false)), "%s does not consume response-card capacity" % card_id)
		"hand_capacity":
			_expect(int(payload.get("base_ordinary_hand_limit", 0)) == 5, "%s preserves the five-card baseline" % card_id)
			_expect(int(payload.get("ordinary_hand_limit", 0)) == int((spec.hand as Array)[rank_index]), "%s uses exact hand-cap ladder" % card_id)
			_expect(int(payload.get("absolute_hand_limit_cap", 0)) == 9, "%s preserves the absolute nine-card cap" % card_id)
		"monster_binding":
			_expect(int(payload.get("controlled_monster_count_limit", 0)) == int((spec.count as Array)[rank_index]), "%s uses exact monster count limit" % card_id)
			_expect(int(payload.get("primary_monster_rank_limit", 0)) == int((spec.primary as Array)[rank_index]), "%s uses exact primary-monster rank" % card_id)
			_expect(int(payload.get("secondary_monster_rank_limit", -1)) == int((spec.secondary as Array)[rank_index]), "%s uses exact secondary-monster rank" % card_id)
			_expect(bool(payload.get("foreign_same_name_upgrade_must_respect_target_owner_limits", false)), "%s caps supportive upgrades by the target owner's charter" % card_id)
			_expect(bool(payload.get("foreign_upgrade_does_not_transfer_control", false)), "%s never transfers control during a supportive upgrade" % card_id)
		"military_command":
			_expect(int(payload.get("controlled_military_count_limit", 0)) == int((spec.count as Array)[rank_index]), "%s uses exact military count limit" % card_id)
			_expect(int(payload.get("primary_military_rank_limit", 0)) == int((spec.primary as Array)[rank_index]), "%s uses exact primary-military rank" % card_id)
			_expect(int(payload.get("secondary_military_rank_limit", -1)) == int((spec.secondary as Array)[rank_index]), "%s uses exact secondary-military rank" % card_id)


func _verify_metadata(catalog: CardRuntimeCatalogV06Resource) -> void:
	var snapshot := catalog.catalog_snapshot()
	var metadata: Dictionary = snapshot.get("metadata", {}) if snapshot.get("metadata", {}) is Dictionary else {}
	_expect(int(metadata.get("named_family_count", 0)) == 87, "metadata records 87 named families")
	_expect(int(metadata.get("explicit_ranked_card_count", 0)) == 348, "metadata records 348 ranked cards")
	_expect(int(metadata.get("organization_family_count", 0)) == 5, "metadata records five organization families")
	_expect(int(metadata.get("organization_ranked_card_count", 0)) == 20, "metadata records 20 organization ranks")
	_expect(int(metadata.get("future_balanced_family_count", 0)) == 107 and int(metadata.get("future_balanced_ranked_card_count", 0)) == 428, "future target grows without consuming the remaining 20-family reserve")
	var blockers: Array = metadata.get("release_blockers", []) if metadata.get("release_blockers", []) is Array else []
	_expect(blockers.has("organization_installation_runtime_wiring_pending"), "metadata honestly blocks release until the organization owner is wired")


func _verify_global_monster_upgrade_contract(catalog: CardRuntimeCatalogV06Resource) -> void:
	var monster_count := 0
	for card_id in catalog.card_ids():
		var card := catalog.card_snapshot(card_id)
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("category_id", "")) != "monster":
			continue
		monster_count += 1
		var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
		var player: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
		_expect(str(machine.get("target_kind", "")) == "region_or_existing_same_family_monster", "%s targets the unique global same-family monster" % card_id)
		_expect(bool(payload.get("upgrade_target_same_family_any_owner", false)), "%s can reinforce any owner's same-family monster" % card_id)
		_expect(not bool(payload.get("ownership_transfer_on_upgrade", true)), "%s does not transfer ownership" % card_id)
		_expect(str(payload.get("bound_skill_recipient", "")) == "existing_monster_owner", "%s grants bound skills to the existing owner" % card_id)
		_expect(str(payload.get("starter_conflict_policy", "")) == "private_reselect", "%s privately resolves starter conflicts" % card_id)
		_expect(bool(payload.get("upgrade_respects_target_owner_rank_cap", false)), "%s respects the target owner's control charter" % card_id)
		_expect(not payload.has("upgrade_target_owned_same_family"), "%s removes the retired owner-only field" % card_id)
		_expect(str(player.get("short_effect", "")).contains("不改变归属") and str(player.get("effect", "")).contains("绑定技能仍归现有主人"), "%s tells players the ownership result concisely" % card_id)
	_expect(monster_count == 32, "global same-name reinforcement contract covers all 32 monster ranks")


func _keyword_texts(player: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var keywords: Array = player.get("keywords", []) if player.get("keywords", []) is Array else []
	for keyword_variant in keywords:
		if keyword_variant is Dictionary:
			result.append(str((keyword_variant as Dictionary).get("text", "")))
	return result


func _axis_label(axis: String) -> String:
	match axis:
		"asset_conversion": return "资产转化"
		"action_bandwidth": return "行动带宽"
		"hand_capacity": return "手牌容量"
		"monster_binding": return "怪兽联络"
		"military_command": return "军队统帅"
	return "组织强化"


func _asset_total(value: Variant) -> int:
	if not (value is Dictionary):
		return -1
	var total := 0
	for amount in (value as Dictionary).values():
		total += int(amount)
	return total


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ORGANIZATION_CARD_CATALOG_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("ORGANIZATION_CARD_CATALOG_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
