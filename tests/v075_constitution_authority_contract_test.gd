extends SceneTree

const CONSTITUTION_PATH := "res://docs/rules/v075_game_constitution.json"
const AMENDMENT_PATH := "res://docs/rules/v075_amendment_from_v074.json"
const BALANCE_PATH := "res://docs/rules/v075_combat_balance_defaults.json"
const AUTHORITY_PATH := "res://docs/rules/v075_combat_authority_manifest.json"
const MONSTER_INVENTORY_PATH := "res://docs/rules/v075_monster_semantic_inventory.json"
const MILITARY_INVENTORY_PATH := "res://docs/rules/v075_military_semantic_inventory.json"
const CATALOG_PATH := "res://data/v075/v075_combat_active_catalog.json"

const REQUIRED_RULE_IDS := [
	"v075.monster.control_capacity",
	"v075.monster.card_modes",
	"v075.monster.preferred_industry_color",
	"v075.monster.autonomous_targeting",
	"v075.monster.autonomous_movement",
	"v075.monster.ground_trample",
	"v075.monster.rank_skill_unlock",
	"v075.monster.private_instant_skill_zone",
	"v075.monster.instant_safe_boundary",
	"v075.monster.cooldown_and_reuse",
	"v075.monster.public_private_projection",
	"v075.military.normal_dbg_membership",
	"v075.military.assault_region",
	"v075.military.assault_monster",
	"v075.military.one_shot_withdrawal",
	"v075.military.no_bound_actions",
	"v075.military.no_guard_task",
	"v075.combat.facility_damage_bridge",
	"v075.combat.exact_once",
	"v075.combat.dynamic_map_integration",
	"v075.combat.ai_projection",
	"v075.combat.presentation_authority_independence",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var constitution := _load_json(CONSTITUTION_PATH)
	var amendment := _load_json(AMENDMENT_PATH)
	var balance := _load_json(BALANCE_PATH)
	var authority := _load_json(AUTHORITY_PATH)
	var monster_inventory := _load_json(MONSTER_INVENTORY_PATH)
	var military_inventory := _load_json(MILITARY_INVENTORY_PATH)
	var catalog := _load_json(CATALOG_PATH)
	_test_constitution(constitution)
	_test_amendment(amendment, constitution)
	_test_balance(balance)
	_test_authority(authority, constitution)
	_test_inventories(monster_inventory, military_inventory)
	_test_catalog(catalog)
	_finish()


func _test_constitution(constitution: Dictionary) -> void:
	_expect(
		str(constitution.get("constitution_id", ""))
			== "space_syndicate.v075.complete"
		and str(constitution.get("ruleset_id", "")) == "v0.7.5",
		"constitution identity is V0.7.5"
	)
	_expect(
		str(constitution.get("status", ""))
			== "approved_and_frozen_for_atomic_production_cutover"
		and str((constitution.get("authority", {}) as Dictionary).get(
			"inherits_from_constitution_id",
			""
		)) == "space_syndicate.v074.complete",
		"constitution is frozen and inherits V0.7.4"
	)
	var contract := constitution.get("closed_world_contract", {}) as Dictionary
	var rule_ids := contract.get("combat_rule_ids", []) as Array
	for rule_id_variant in REQUIRED_RULE_IDS:
		_expect(
			str(rule_id_variant) in rule_ids,
			"constitution contains required rule %s" % str(rule_id_variant)
		)
	var superseded := constitution.get("superseded_contracts", {}) as Dictionary
	_expect(
		(superseded.get("bound_action_source_kinds_before", []) as Array)
			== ["monster", "military"]
		and (superseded.get("bound_action_source_kinds_after", []) as Array)
			== ["monster"]
		and not bool(superseded.get("military_bound_action_enabled", true))
		and not bool(superseded.get(
			"monster_skill_public_batch_queue_member",
			true
		)),
		"superseded bound-action and public-skill contracts are explicit"
	)
	var transition := constitution.get("runtime_transition", {}) as Dictionary
	_expect(
		bool(transition.get("atomic_cutover_required", false))
		and not bool(transition.get("dual_write_allowed", true))
		and not bool(transition.get("legacy_fallback_allowed", true))
		and not bool(transition.get("mixed_ruleset_allowed", true)),
		"runtime transition forbids mixed and legacy fallback paths"
	)


func _test_amendment(amendment: Dictionary, constitution: Dictionary) -> void:
	_expect(
		str(amendment.get("from_constitution_id", ""))
			== "space_syndicate.v074.complete"
		and str(amendment.get("to_constitution_id", ""))
			== str(constitution.get("constitution_id", ""))
		and str(amendment.get("status", "")) == "approved_and_frozen",
		"amendment is a frozen V0.7.4 to V0.7.5 combat delta"
	)
	var domains := amendment.get("atomic_cutover_domains", []) as Array
	_expect(
		int(amendment.get("atomic_cutover_domain_count", -1)) == 14
		and domains.size() == 14
		and domains == (constitution.get("amended_domains", []) as Array),
		"amendment and constitution share the same fourteen cutover domains"
	)
	var bound_contract := amendment.get("bound_action_contract", {}) as Dictionary
	_expect(
		(bound_contract.get("source_kinds_before", []) as Array)
			== ["monster", "military"]
		and (bound_contract.get("source_kinds_after", []) as Array)
			== ["monster"]
		and not bool(bound_contract.get("military_bound_action_enabled", true)),
		"amendment closes military bound actions"
	)


func _test_balance(balance: Dictionary) -> void:
	_expect(
		str(balance.get("constitution_id", ""))
			== "space_syndicate.v075.complete"
		and str(balance.get("ruleset_id", "")) == "v0.7.5"
		and bool(balance.get("human_test_required", false)),
		"balance defaults are V0.7.5 first-human tunables"
	)
	var subtype_weights := balance.get(
		"unified_track_normal_subtype_weights_basis_points",
		{}
	) as Dictionary
	_expect(
		int(subtype_weights.get("facility", 0)) == 7000
		and int(subtype_weights.get("monster", 0)) == 1500
		and int(subtype_weights.get("military", 0)) == 1500
		and int(subtype_weights.get("sum", 0)) == 10000,
		"normal subtype weights preserve a seventy percent facility core"
	)
	var outer_weights := balance.get(
		"inherited_track_kind_ratio_basis_points",
		{}
	) as Dictionary
	_expect(
		int(outer_weights.get("normal_card", 0)) == 6000
		and int(outer_weights.get("commodity_card", 0)) == 4000
		and not bool(outer_weights.get("changed_by_v075", true)),
		"outer normal and commodity ratio remains 6000/4000"
	)


func _test_authority(authority: Dictionary, constitution: Dictionary) -> void:
	_expect(
		str(authority.get("constitution_id", ""))
			== str(constitution.get("constitution_id", ""))
		and str(authority.get("ruleset_id", "")) == "v0.7.5"
		and str(authority.get("status", ""))
			== "frozen_target_authority_manifest_not_runtime_evidence",
		"authority manifest is explicitly a target manifest"
	)
	var cutover := authority.get("atomic_cutover", {}) as Dictionary
	_expect(
		int(cutover.get("domain_count", -1)) == 14
		and (cutover.get("domains", []) as Array)
			== (constitution.get("amended_domains", []) as Array),
		"authority manifest names all fourteen domains"
	)
	var claims := authority.get("runtime_claims", {}) as Dictionary
	_expect(
		int(claims.get("connected_domain_count", -1)) == 0
		and bool(claims.get(
			"coordinator_must_replace_with_same_sha_mcp_evidence",
			false
		)),
		"manifest cannot masquerade as same-SHA runtime evidence"
	)


func _test_inventories(monster_inventory: Dictionary, military_inventory: Dictionary) -> void:
	_expect(
		str(monster_inventory.get("status", "")) == "frozen_migration_inventory"
		and str(military_inventory.get("status", ""))
			== "frozen_migration_inventory",
		"legacy semantic inventories are frozen"
	)
	_expect(
		_disposition(monster_inventory, "monster.wager") == "retired"
		and _disposition(monster_inventory, "monster.public_bid") == "retired"
		and _disposition(military_inventory, "military.guard_command") == "retired"
		and _disposition(military_inventory, "military.bound_commands") == "retired",
		"retired wager, bid, guard, and military bound-action semantics are recorded"
	)


func _test_catalog(catalog: Dictionary) -> void:
	_expect(
		str(catalog.get("constitution_id", ""))
			== "space_syndicate.v075.complete"
		and str(catalog.get("ruleset_id", "")) == "v0.7.5",
		"active catalog carries the frozen V0.7.5 identity"
	)
	var families := catalog.get("monster_families", []) as Array
	var colors: Array[String] = []
	var skill_count := 0
	var ultimate_count := 0
	for family_variant in families:
		var family := family_variant as Dictionary
		var color := str(family.get("preferred_industry_color", ""))
		if color not in colors:
			colors.append(color)
		var skills := family.get("skill_definitions", []) as Array
		skill_count += skills.size()
		for skill_variant in skills:
			if bool((skill_variant as Dictionary).get("ultimate", false)):
				ultimate_count += 1
	var military := catalog.get("military_definitions", []) as Array
	_expect(
		families.size() == 6
		and colors.size() == 6
		and skill_count == 24
		and ultimate_count == 6
		and military.size() <= 4
		and military.size() > 0,
		"active catalog covers six colors, twenty-four skills, and bounded military definitions"
	)


func _disposition(document: Dictionary, item_id: String) -> String:
	for item_variant in document.get("semantic_items", []) as Array:
		var item := item_variant as Dictionary
		if str(item.get("item_id", "")) == item_id:
			return str(item.get("disposition", ""))
	return ""


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_failures.append("missing:%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_failures.append("invalid_json:%s" % path)
		return {}
	return parsed as Dictionary


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_CONSTITUTION_AUTHORITY_CONTRACT_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
