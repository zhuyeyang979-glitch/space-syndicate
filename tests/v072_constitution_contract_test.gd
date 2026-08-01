extends SceneTree

const CONSTITUTION_PATH := "res://docs/rules/v072_game_constitution.json"
const CONSTITUTION_MD_PATH := "res://docs/rules/v072_game_constitution.md"
const PROGRAM_STATE_PATH := "res://docs/development/current_program_state.json"
const AGENTS_PATH := "res://AGENTS.md"

const HISTORICAL_FILES := {
	"res://docs/rules/v07_game_constitution.json": "81c8ae27eba50f4d68c8a379913baf0592a819412bca0109f7e5fc9ef9a5a5fc",
	"res://docs/rules/v07_game_constitution.md": "a0d2e4324898134bdc3a58cc232ce05e5ca39b8787549b8a55a6ab50f28abb72",
	"res://docs/rules/v07_balance_defaults.json": "8678cfa88eeff53f60b2e209598e670e2748189c3bb3bd0ebd21bf5c5e20c6f8",
	"res://docs/rules/v071_game_constitution.json": "a5a52a88bc5a139dc56accc46897c82ddc7c3ea1aacdcaa6f72a412815429473",
	"res://docs/rules/v071_game_constitution.md": "2b4822b915d46f575ad9f1ff4675bc3741c91a70cf19b4f56fc8f37ac9bed930",
	"res://docs/rules/v071_balance_defaults.json": "4ef853a914dafc4919848e2f28da824cb4b710058556c2013fd4cdcddc5d555a",
}

const AUTHORITY_PRECEDENCE := [
	"latest_explicit_user_rule_decision",
	"docs/rules/v072_game_constitution.json",
	"docs/rules/v072_game_constitution.md",
	"docs/rules/v071_game_constitution.json",
	"docs/rules/v071_game_constitution.md",
	"docs/rules/v07_game_constitution.json",
	"docs/rules/v07_game_constitution.md",
	"docs/tabletop_rulebook_v06.md_current_production_only",
	"older_rule_documents",
	"older_test_oracles",
	"older_code_behavior",
]

const AMENDMENT_RULE_IDS := [
	"v072.assets.zero_genesis_balances",
	"v072.starter.closed_definition_registry",
	"v072.starter.persistent_zero_asset_cost",
	"v072.standard.level_one_asset_cost",
	"v072.starter.standard_merge_consumes_privilege",
	"v072.starter.zero_deadlock_bootstrap",
	"v072.starter.private_observation_and_projection",
	"v072.starter.save_identity_and_migration",
]

const STARTER_DEFINITION_IDS := [
	"starter.facility.factory.life.rank_1",
	"starter.facility.market.life.rank_1",
	"starter.facility.factory.energy.rank_1",
	"starter.facility.market.energy.rank_1",
	"starter.facility.factory.industry.rank_1",
	"starter.facility.market.industry.rank_1",
	"starter.facility.factory.technology.rank_1",
	"starter.facility.market.technology.rank_1",
	"starter.facility.factory.commerce.rank_1",
	"starter.facility.market.commerce.rank_1",
	"starter.facility.factory.shipping.rank_1",
	"starter.facility.market.shipping.rank_1",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var constitution := _read_json(CONSTITUTION_PATH)
	_expect(not constitution.is_empty(), "V0.7.2 constitution parses")
	_expect(str(constitution.get("constitution_id", "")) == "space_syndicate.v072.complete", "constitution ID is exact")
	_expect(str(constitution.get("ruleset_id", "")) == "v0.7.2", "ruleset ID is exact")
	_expect(str(constitution.get("status", "")) == "frozen_highest_target_constitution", "constitution is frozen highest target")
	_expect(str(constitution.get("current_production_ruleset", "")) == "v0.6", "production remains V0.6")
	_expect(constitution.get("authority_precedence", []) == AUTHORITY_PRECEDENCE, "authority precedence is exact")

	var approval: Dictionary = constitution.get("approval", {})
	_expect(bool(approval.get("approved", false)), "free Starter bootstrap approval is recorded")
	_expect(str(approval.get("approval_decision_id", "")) == "USER_APPROVES_V072_FREE_STARTER_BOOTSTRAP", "approval decision is exact")
	_expect(str(approval.get("approved_profile_id", "")) == "V072_STARTER_FREE_FAST", "approved profile is exact")
	_expect(not bool(approval.get("human_fun_proven", true)) and bool(approval.get("human_test_required", false)), "freeze does not claim human fun")

	var inheritance: Dictionary = constitution.get("inheritance", {})
	_expect(str(inheritance.get("source_constitution_id", "")) == "space_syndicate.v071.complete", "V0.7.2 inherits V0.7.1")
	_expect(int(inheritance.get("inherited_constitutional_rule_count", 0)) == 84, "all 84 V0.7.1 rules are inherited")
	_expect(int(inheritance.get("v072_amendment_rule_count", 0)) == 8, "eight V0.7.2 amendments are composed")
	_expect(int(inheritance.get("effective_constitutional_rule_count", 0)) == 92, "effective rule count is explicit")
	_expect(constitution.get("structural_amendment_rule_ids", []) == AMENDMENT_RULE_IDS, "amendment IDs are ordered and exact")

	var rules: Array = constitution.get("constitutional_rules", [])
	_expect(rules.size() == 8, "eight V0.7.2 rule objects are present")
	var by_id: Dictionary = {}
	for rule_variant in rules:
		_expect(rule_variant is Dictionary, "every amendment rule is an object")
		if not (rule_variant is Dictionary):
			continue
		var rule := rule_variant as Dictionary
		var rule_id := str(rule.get("rule_id", ""))
		_expect(not rule_id.is_empty() and not by_id.has(rule_id), "%s is unique" % rule_id)
		by_id[rule_id] = rule
		_expect(not str(rule.get("domain", "")).is_empty(), "%s has a domain" % rule_id)
		_expect(not str(rule.get("statement", "")).is_empty(), "%s has a statement" % rule_id)
	for rule_id in AMENDMENT_RULE_IDS:
		_expect(by_id.has(rule_id), "%s is frozen" % rule_id)

	_test_zero_asset_genesis(by_id)
	_test_starter_definitions(by_id)
	_test_cost_and_merge_contracts(by_id)
	_test_zero_deadlock_and_semantics(by_id)
	_test_save_rng_and_cutover(constitution, by_id)
	_test_history_and_program_state(constitution)
	_finish()


func _test_zero_asset_genesis(by_id: Dictionary) -> void:
	var rule: Dictionary = by_id.get("v072.assets.zero_genesis_balances", {})
	var value: Dictionary = rule.get("value", {})
	_expect(bool(value.get("asset_owner_created_at_genesis", false)), "asset Owner exists at genesis")
	_expect(int(value.get("initial_assets_per_color", -1)) == 0, "all colors begin at zero")
	_expect(int(value.get("initial_fixed_point_remainder_per_color", -1)) == 0, "all remainders begin at zero")
	_expect(value.get("colors", []) == ["life", "energy", "industry", "technology", "commerce", "shipping"], "the six colors are exact")
	_expect(str(value.get("player_display", "")) == "0/6", "player asset display starts at 0/6")
	_expect(not bool(value.get("uninitialized_state_allowed", true)) and not bool(value.get("absent_owner_state_allowed", true)), "zero is not an absent or uninitialized state")


func _test_starter_definitions(by_id: Dictionary) -> void:
	var rule: Dictionary = by_id.get("v072.starter.closed_definition_registry", {})
	var value: Dictionary = rule.get("value", {})
	_expect(int(value.get("definition_count", 0)) == 12 and int(value.get("instance_count_per_player_at_genesis", 0)) == 12, "genesis has exactly twelve Starter definitions and instances")
	_expect(int(value.get("factory_count", 0)) == 6 and int(value.get("market_count", 0)) == 6, "Starter deck has six factories and six markets")
	_expect(int(value.get("instances_per_definition", 0)) == 1, "each Starter definition has one genesis instance")
	_expect(str(value.get("origin_class", "")) == "starter_bootstrap" and str(value.get("asset_cost_profile", "")) == "starter_zero_asset", "Starter origin and cost profile are exact")
	_expect(int(value.get("level", 0)) == 1 and bool(value.get("starter_badge", false)), "all Starter definitions are badge-bearing L1 cards")
	_expect(not bool(value.get("track_spawn_allowed", true)) and not bool(value.get("purchase_allowed", true)), "Starter definitions cannot spawn or be purchased")
	_expect(not bool(value.get("creation_allowed_after_genesis", true)) and int(value.get("track_spawn_count", -1)) == 0, "Starter post-genesis creation and track count are zero")

	var definitions: Array = value.get("definitions", [])
	_expect(definitions.size() == 12, "twelve definition records are closed")
	var actual_ids: Array[String] = []
	var factories := 0
	var markets := 0
	var colors: Dictionary = {}
	for definition_variant in definitions:
		_expect(definition_variant is Dictionary, "every Starter definition is an object")
		if not (definition_variant is Dictionary):
			continue
		var definition := definition_variant as Dictionary
		actual_ids.append(str(definition.get("definition_id", "")))
		var facility_type := str(definition.get("facility_type", ""))
		factories += 1 if facility_type == "factory" else 0
		markets += 1 if facility_type == "market" else 0
		var color := str(definition.get("color", ""))
		colors[color] = int(colors.get(color, 0)) + 1
		_expect(str(definition.get("merge_family_id", "")) == "facility.%s.%s" % [facility_type, color], "%s has stable merge family" % str(definition.get("definition_id", "")))
		_expect(str(definition.get("origin_class", "")) == "starter_bootstrap", "%s has explicit Starter origin" % str(definition.get("definition_id", "")))
		_expect(int(definition.get("level", 0)) == 1 and str(definition.get("asset_cost_profile", "")) == "starter_zero_asset", "%s has explicit L1 zero-cost profile" % str(definition.get("definition_id", "")))
		_expect(bool(definition.get("starter_badge", false)), "%s carries the Starter badge" % str(definition.get("definition_id", "")))
		_expect(not bool(definition.get("track_spawn_allowed", true)) and not bool(definition.get("purchase_allowed", true)), "%s is excluded from track and purchase" % str(definition.get("definition_id", "")))
		_expect(int(definition.get("primary_asset_cost", -1)) == 0 and int(definition.get("secondary_asset_cost", -1)) == 0 and int(definition.get("any_asset_cost", -1)) == 0, "%s has zero cost in every asset channel" % str(definition.get("definition_id", "")))
	_expect(actual_ids == STARTER_DEFINITION_IDS, "the twelve stable definition IDs are exact and ordered")
	_expect(factories == 6 and markets == 6, "definition records contain six factories and six markets")
	for color in ["life", "energy", "industry", "technology", "commerce", "shipping"]:
		_expect(int(colors.get(color, 0)) == 2, "%s has one factory and one market" % color)


func _test_cost_and_merge_contracts(by_id: Dictionary) -> void:
	var starter: Dictionary = (by_id.get("v072.starter.persistent_zero_asset_cost", {}) as Dictionary).get("value", {})
	_expect(int(starter.get("primary_asset_cost", -1)) == 0, "Starter primary cost is zero")
	_expect(int(starter.get("secondary_asset_cost", -1)) == 0 and int(starter.get("any_asset_cost", -1)) == 0, "all Starter asset cost channels are zero")
	_expect(bool(starter.get("every_legal_play_is_zero_asset_cost", false)) and not bool(starter.get("first_play_only", true)), "Starter remains free on every play")
	_expect(str(starter.get("identity_source", "")) == "stable_card_definition" and not bool(starter.get("zone_inference_allowed", true)), "Starter identity is stable definition data")
	for phase in ["discard", "reshuffle_into_draw_pile", "save", "restore"]:
		_expect(phase in starter.get("persists_through", []), "Starter cost persists through %s" % phase)
	_expect(not bool(starter.get("non_asset_legality_bypassed", true)), "free cost does not bypass non-asset legality")

	var standard: Dictionary = (by_id.get("v072.standard.level_one_asset_cost", {}) as Dictionary).get("value", {})
	_expect(str(standard.get("origin_class", "")) == "standard", "standard cost is origin-scoped")
	_expect(int(standard.get("standard_level_1_primary_asset_cost", 0)) == 1, "standard L1 costs one matching asset")
	var level_costs: Dictionary = standard.get("level_costs", {})
	_expect(int(level_costs.get("1", 0)) == 1 and int(level_costs.get("2", 0)) == 2 and int(level_costs.get("3", 0)) == 3 and int(level_costs.get("4", 0)) == 4, "rank defaults are 1/2/3/4")
	_expect(str(standard.get("track_purchase_destination", "")) == "personal_discard" and not bool(standard.get("track_purchase_immediate_use", true)), "standard purchase enters discard without immediate use")

	var merge: Dictionary = (by_id.get("v072.starter.standard_merge_consumes_privilege", {}) as Dictionary).get("value", {})
	_expect(bool(merge.get("starter_standard_l1_merge_allowed", false)) and bool(merge.get("player_choice_required", false)), "Starter plus standard L1 merge is an explicit choice")
	_expect(not bool(merge.get("automatic_merge_allowed", true)), "cross-origin merge is never automatic")
	_expect(str(merge.get("output_origin_class", "")) == "standard" and int(merge.get("output_level", 0)) == 2, "merge output is standard L2")
	_expect(str(merge.get("output_asset_cost_profile", "")) == "standard_rank_2" and int(merge.get("output_primary_asset_cost", 0)) == 2, "merge output costs two")
	_expect(not bool(merge.get("starter_zero_cost_privilege_inherited", true)), "Starter free privilege is consumed")
	_expect(int(merge.get("minimum_total_normal_card_count_after_merge", 0)) == 5, "minimum five-card gate remains")
	for field in ["source_definition_ids", "source_origin_classes", "output_definition_id", "output_origin_class", "starter_privilege_consumed"]:
		_expect(field in merge.get("receipt_required_fields", []), "merge Receipt requires %s" % field)


func _test_zero_deadlock_and_semantics(by_id: Dictionary) -> void:
	var opening: Dictionary = (by_id.get("v072.starter.zero_deadlock_bootstrap", {}) as Dictionary).get("value", {})
	_expect(str(opening.get("zero_deadlock_mechanism", "")) == "zero_asset_cost_starter_cards", "zero deadlock uses stable Starter definitions")
	_expect(int(opening.get("opening_hand_size", 0)) == 5 and int(opening.get("opening_hand_starter_card_count", 0)) == 5, "opening hand contains five Starters")
	_expect(int(opening.get("opening_hand_asset_affordable_card_count", 0)) == 5, "all five opening cards are asset-affordable")
	_expect(int(opening.get("opening_legal_starter_facility_action_minimum", 0)) >= 1, "opening has at least one legal Starter action")
	_expect(not bool(opening.get("direct_asset_injection_allowed", true)) and not bool(opening.get("runtime_first_batch_cost_exception_allowed", true)), "bootstrap has no asset injection or Runtime exception")

	var semantics: Dictionary = (by_id.get("v072.starter.private_observation_and_projection", {}) as Dictionary).get("value", {})
	_expect(str(semantics.get("starter_badge_key", "")) == "card.badge.starter", "Starter badge key is stable")
	for field in ["definition_id", "origin_class", "asset_cost", "merge_family_id", "level", "starter_badge"]:
		_expect(field in semantics.get("player_projection_required_fields", []), "Player projection requires %s" % field)
	for field in ["definition_id", "origin_class", "asset_cost", "merge_family_id", "level", "legal_targets"]:
		_expect(field in semantics.get("ai_self_observation_required_fields", []), "AI self-observation requires %s" % field)
	_expect(bool(semantics.get("ai_must_distinguish_starter_from_standard_l1", false)), "AI must distinguish Starter from standard L1")
	for field in ["exact_hand", "starter_positions_in_draw_pile", "future_draw_order", "exact_assets"]:
		_expect(field in semantics.get("opponent_forbidden_fields", []), "opponent remains forbidden %s" % field)


func _test_save_rng_and_cutover(constitution: Dictionary, by_id: Dictionary) -> void:
	var save_rule: Dictionary = (by_id.get("v072.starter.save_identity_and_migration", {}) as Dictionary).get("value", {})
	for field in ["card_definition_id", "card_instance_id", "origin_class", "asset_cost_profile", "level", "merge_family_id"]:
		_expect(field in save_rule.get("required_card_fields", []), "Save rule requires %s" % field)
	_expect(not bool(save_rule.get("starter_identity_inferred_from_cost", true)), "Save never infers Starter from cost")
	_expect(not bool(save_rule.get("v071_save_to_v072_direct_resume", true)), "V0.7.1 Save fails closed")
	_expect(not bool(save_rule.get("v06_save_to_v072_direct_resume", true)) and bool(save_rule.get("v06_save_backup_required", false)), "V0.6 Save fails closed with backup")
	_expect(int(save_rule.get("restore_rng_draw_delta", -1)) == 0, "restore has zero RNG advance")

	var save: Dictionary = constitution.get("save_obligations", {})
	_expect(bool(save.get("versioned_v072_schema_required", false)), "V0.7.2 Save schema is versioned")
	for field in ["starter_definition_order", "normal_draw_pile_order", "normal_hand", "committed_escrow", "normal_discard"]:
		_expect(field in save.get("required_deck_state", []), "Save obligations preserve %s" % field)
	_expect(save.get("required_merge_state", []) == ["merge_lineage", "starter_privilege_consumed"], "Save obligations preserve merge lineage and privilege consumption")
	_expect((save.get("affected_domain_state_versions_must_increment", []) as Array).size() == 8, "eight affected domain state versions must increment")
	var rng: Dictionary = constitution.get("rng_obligations", {})
	_expect(int(rng.get("new_rng_stream_count", -1)) == 0 and str(rng.get("starter_shuffle_stream", "")) == "starter_deck_shuffle", "Starter bootstrap adds no RNG stream")
	var detached: Dictionary = constitution.get("detached_implementation_obligations", {})
	_expect(str(detached.get("target_ruleset_id", "")) == "v0.7.2", "detached target is V0.7.2")
	_expect(int(detached.get("production_connection_count", -1)) == 0 and int(detached.get("v06_mutation_count", -1)) == 0 and int(detached.get("dual_write_count", -1)) == 0, "detached target has no production connection, V0.6 mutation, or dual write")
	var cutover: Dictionary = constitution.get("cutover_obligations", {})
	_expect(not bool(cutover.get("production_cutover_allowed_by_this_task", true)), "docs freeze does not authorize cutover")
	_expect(not bool(cutover.get("v06_and_v072_dual_write_allowed", true)), "V0.6/V0.7.2 dual write is forbidden")


func _test_history_and_program_state(constitution: Dictionary) -> void:
	for path in HISTORICAL_FILES:
		_expect(_file_sha256(path) == str(HISTORICAL_FILES[path]), "%s remains byte-identical" % path)
	var baselines: Dictionary = constitution.get("historical_baselines", {})
	_expect(int((baselines.get("v07", {}) as Dictionary).get("content_change_count", -1)) == 0, "V0.7 historical change count is zero")
	_expect(int((baselines.get("v071", {}) as Dictionary).get("content_change_count", -1)) == 0, "V0.7.1 historical change count is zero")

	var program: Dictionary = _read_json(PROGRAM_STATE_PATH).get("program", {})
	_expect(str(program.get("current_production_runtime_ruleset", "")) == "v0.6", "program retains V0.6 production")
	_expect(str(program.get("highest_target_ruleset", "")) == "v0.7.2", "program records V0.7.2 highest target")
	_expect(bool(program.get("v072_highest_constitution_frozen", false)), "program records frozen V0.7.2")
	_expect(not bool(program.get("full_v0_7_2_runtime_cutover", true)), "program records no V0.7.2 cutover")
	_expect(int(program.get("v071_historical_constitution_content_change_count", -1)) == 0, "program records unchanged V0.7.1 history")

	var agents := FileAccess.get_file_as_string(AGENTS_PATH)
	_expect(agents.find("docs/rules/v072_game_constitution.json") < agents.find("docs/rules/v071_game_constitution.json"), "AGENTS places V0.7.2 before V0.7.1")
	_expect(agents.contains("HIGHEST_TARGET_RULE_AUTHORITY=V0.7.2_COMPLETE_CONSTITUTION"), "AGENTS names V0.7.2 highest authority")
	var human := FileAccess.get_file_as_string(CONSTITUTION_MD_PATH)
	_expect(human.contains("USER_APPROVES_V072_FREE_STARTER_BOOTSTRAP=true"), "human constitution records explicit approval")
	_expect(human.contains("HUMAN_FUN_PROVEN=false") and human.contains("FULL_V0_7_2_RUNTIME_CUTOVER=false"), "human constitution preserves approval boundaries")


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _file_sha256(path: String) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(FileAccess.get_file_as_bytes(path)) != OK:
		return ""
	return hashing.finish().hex_encode().to_lower()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("V072_CONSTITUTION_CONTRACT_TEST|status=%s|checks=%d|failures=%d|inherited_rule_count=84|amendment_rule_count=8|effective_rule_count=92|starter_definition_count=12|v07_historical_change_count=0|v071_historical_change_count=0|production_connection_count=0|human_fun_proven=false|details=%s" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(), JSON.stringify(_failures)
	])
	quit(0 if passed else 1)
