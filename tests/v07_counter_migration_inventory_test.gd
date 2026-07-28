extends SceneTree

const INVENTORY_PATH := "res://docs/migration/v07_legacy_counter_card_migration_inventory.json"
const INVENTORY_MD_PATH := "res://docs/migration/v07_legacy_counter_card_migration_inventory.md"
const CATALOG_PATH := "res://data/cards/card_runtime_catalog_v06.json"
const FAMILY_PATH := "res://resources/cards/runtime/families/054_相位否决.tres"
const EXPECTED_IDS := [
	"interaction.phase_veto.rank_1",
	"interaction.phase_veto.rank_2",
	"interaction.phase_veto.rank_3",
	"interaction.phase_veto.rank_4",
]
const EXPECTED_REFUNDS := [0, 40, 90, 160]
const EXPECTED_TRACES := [0, 0, 1, 2]
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY_PATH))
	_expect(parsed is Dictionary, "legacy Counter migration inventory parses")
	if not (parsed is Dictionary):
		_finish()
		return
	var inventory := parsed as Dictionary
	_test_classification_contract(inventory)
	_test_card_inventory(inventory)
	_test_v06_catalog_parity(inventory)
	_test_family_resource()
	_test_exclusions_and_related_capability(inventory)
	_test_surface_scan(inventory)
	_test_readiness_truth(inventory)
	_test_human_readable_inventory()
	_finish()


func _test_classification_contract(inventory: Dictionary) -> void:
	var allowed := inventory.get("allowed_primary_classifications", []) as Array
	_expect(allowed == [
		"MIGRATE_TO_PROACTIVE_DEFENSE",
		"MIGRATE_TO_INSURANCE",
		"MIGRATE_TO_BATCH_INTERFERENCE",
		"MIGRATE_TO_PASSIVE_SOURCE_ABILITY",
		"RETIRE_FROM_V07",
		"BLOCKED_NEEDS_USER_RULE_DECISION",
	], "exactly six allowed primary classifications are frozen")
	var counts := inventory.get("classification_counts", {}) as Dictionary
	var total := 0
	for classification in allowed:
		_expect(counts.has(classification), "classification count exists: %s" % str(classification))
		total += int(counts.get(classification, 0))
	_expect(total == int(inventory.get("former_counter_card_count", -1)), "classification counts sum to former Counter card count")
	_expect(int(counts.get("MIGRATE_TO_PROACTIVE_DEFENSE", 0)) == 4, "all four formal Counter cards migrate to proactive defense")
	for classification in allowed:
		if str(classification) != "MIGRATE_TO_PROACTIVE_DEFENSE":
			_expect(int(counts.get(classification, -1)) == 0, "formal card count is zero for %s" % str(classification))


func _test_card_inventory(inventory: Dictionary) -> void:
	var cards := inventory.get("cards", []) as Array
	_expect(cards.size() == 4 and int(inventory.get("former_counter_card_count", -1)) == 4, "inventory contains exactly four formal Counter cards")
	var seen := {}
	for index in range(cards.size()):
		var card := cards[index] as Dictionary
		var card_id := str(card.get("stable_card_id", ""))
		_expect(card_id == EXPECTED_IDS[index], "stable card identity is frozen for rank %d" % (index + 1))
		_expect(not seen.has(card_id), "stable card identity appears exactly once: %s" % card_id)
		seen[card_id] = true
		_expect(int(card.get("rank", 0)) == index + 1, "rank matches stable identity: %s" % card_id)
		_expect(str(card.get("v06_effect_kind", "")) == "card_counter", "V0.6 source kind is card_counter: %s" % card_id)
		_expect(str(card.get("primary_classification", "")) == "MIGRATE_TO_PROACTIVE_DEFENSE", "card has one proactive-defense primary classification: %s" % card_id)
		_expect(str(card.get("v07_action_class", "")) == "PROACTIVE_DEFENSE", "V0.7 action is proactive rather than reactive: %s" % card_id)
		_expect(int(card.get("v07_prevention_count", 0)) == 1 and str(card.get("v07_expiry", "")) == "CREATING_BATCH_ONLY", "defense is one-use and creating-batch scoped: %s" % card_id)
		_expect(str(card.get("v07_target_invalidation_policy", "")) == "FIZZLE_NO_EFFECT", "invalid prebound target fizzles: %s" % card_id)
		_expect(int(card.get("v06_refund_cash", -1)) == EXPECTED_REFUNDS[index], "V0.6 refund amount is preserved in migration evidence: %s" % card_id)
		_expect(int(card.get("v06_private_trace_count", -1)) == EXPECTED_TRACES[index], "V0.6 trace count is preserved in migration evidence: %s" % card_id)
		if EXPECTED_TRACES[index] > 0:
			_expect(str(card.get("v07_trace_policy", "")).begins_with("DEFENDER_ONLY_ALLOWLISTED_PRIVATE_RECEIPT"), "trace becomes defender-only allowlisted receipt: %s" % card_id)
	_expect(seen.size() == EXPECTED_IDS.size(), "all expected stable IDs occur once")


func _test_v06_catalog_parity(inventory: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_expect(parsed is Dictionary, "V0.6 runtime catalog parses")
	if not (parsed is Dictionary):
		return
	var counter_cards: Array[Dictionary] = []
	for card_variant in (parsed as Dictionary).get("cards", []) as Array:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var machine := card.get("machine", {}) as Dictionary
		if str(machine.get("effect_kind", "")) == "card_counter":
			counter_cards.append(card)
	_expect(counter_cards.size() == 4, "active V0.6 catalog dynamically contains exactly four card_counter entries")
	var dynamic_ids: Array[String] = []
	for card in counter_cards:
		var machine := card.get("machine", {}) as Dictionary
		var payload := machine.get("effect_payload", {}) as Dictionary
		var rank := int(machine.get("rank", 0))
		var card_id := str(machine.get("card_id", ""))
		dynamic_ids.append(card_id)
		_expect(rank >= 1 and rank <= 4, "catalog Counter rank is within I-IV")
		if rank >= 1 and rank <= 4:
			_expect(card_id == EXPECTED_IDS[rank - 1], "catalog and inventory stable ID match for rank %d" % rank)
			_expect(int(payload.get("counter_strength", 0)) == rank, "catalog strength matches rank %d" % rank)
			_expect(int(payload.get("refund_cash", -1)) == EXPECTED_REFUNDS[rank - 1], "catalog refund matches inventory for rank %d" % rank)
			_expect(int(payload.get("private_trace_count", -1)) == EXPECTED_TRACES[rank - 1], "catalog trace matches inventory for rank %d" % rank)
			_expect(is_equal_approx(float(payload.get("counter_window_seconds", 0.0)), 5.0), "V0.6 evidence records a five-second response window for rank %d" % rank)
	dynamic_ids.sort()
	var expected_sorted: Array[String] = []
	for card_id in EXPECTED_IDS:
		expected_sorted.append(card_id)
	expected_sorted.sort()
	_expect(dynamic_ids == expected_sorted, "dynamic V0.6 Counter identities exactly match the migration inventory")
	_expect((inventory.get("cards", []) as Array).size() == dynamic_ids.size(), "no catalog Counter is omitted from the inventory")


func _test_family_resource() -> void:
	var source := FileAccess.get_file_as_string(FAMILY_PATH)
	_expect(source.count('kind = &"card_counter"') == 4, "formal V0.6 family resource contains exactly four card_counter ranks")
	_expect(source.contains('"counter_refund": 40') and source.contains('"counter_refund": 90') and source.contains('"counter_refund": 160'), "family resource refund evidence covers ranks II-IV")
	_expect(source.contains('"counter_trace": 1') and source.contains('"counter_trace": 2'), "family resource trace evidence covers ranks III-IV")


func _test_exclusions_and_related_capability(inventory: Dictionary) -> void:
	var exclusions := inventory.get("explicit_exclusions", []) as Array
	var exclusion_text := JSON.stringify(exclusions)
	_expect(exclusion_text.contains("starlink_dismantle") and exclusion_text.contains("shadow_warehouse_traction"), "Counterable attacks are excluded from Counter card count")
	_expect(exclusion_text.contains("099_火花反制.tres") and exclusion_text.contains("special_monster_delay"), "name-only 火花反制 collision is explicitly excluded")
	_expect(exclusion_text.contains("guard.rank_1_to_3"), "existing guard statuses are explicitly excluded")
	var capabilities := inventory.get("non_catalog_counter_capabilities", []) as Array
	_expect(capabilities.size() == 1, "one non-catalog Counter capability is tracked separately")
	if capabilities.size() == 1:
		var capability := capabilities[0] as Dictionary
		_expect(str(capability.get("v07_status", "")) == "BLOCKED_NEEDS_USER_RULE_DECISION", "role-based monster conversion requires a separate V0.7 rule decision")
		_expect(not bool(capability.get("counted_as_former_counter_card", true)), "role capability is not double-counted as a card")


func _test_surface_scan(inventory: Dictionary) -> void:
	var scan := inventory.get("surface_scan", {}) as Dictionary
	var pattern := "card_counter|counter_window|counter_stack|pending_counter|response_window|counter_strength|counter_refund|counter_trace|response_cards_ignore|counterability|合法响应窗口|反制窗口|反制牌|反制栈"
	var baseline_sha := str(scan.get("baseline_sha", ""))
	_expect(baseline_sha.length() == 40, "semantic surface scan is pinned to an exact baseline SHA")
	var output: Array = []
	var exit_code := OS.execute("git", ["-c", "core.quotePath=false", "grep", "-l", "-I", "-i", "-E", pattern, baseline_sha, "--", "."], output, true)
	_expect(exit_code == 0, "semantic Counter surface scan executes")
	if exit_code != 0:
		return
	var paths: Array[String] = []
	for raw_line in "\n".join(output).split("\n", false):
		var path := str(raw_line).strip_edges().replace("\\", "/")
		var prefix := "%s:" % baseline_sha
		if path.begins_with(prefix):
			path = path.substr(prefix.length())
		if path.begins_with("./"):
			path = path.substr(2)
		if path.is_empty() or path.ends_with(".uid") or path.begins_with("addons/") or path.begins_with("third_party/") or path.begins_with("tools/"):
			continue
		if not paths.has(path):
			paths.append(path)
	paths.sort()
	_expect(paths.size() == int(scan.get("baseline_file_count", -1)), "semantic Counter surface baseline remains exactly 148 files")
	var actual_by_root := {}
	for path in paths:
		var root := path.get_slice("/", 0)
		actual_by_root[root] = int(actual_by_root.get(root, 0)) + 1
	var expected_by_root := scan.get("files_by_root", {}) as Dictionary
	for root in expected_by_root.keys():
		_expect(int(actual_by_root.get(root, -1)) == int(expected_by_root.get(root, -2)), "surface count matches for %s" % str(root))
	_expect(actual_by_root.size() == expected_by_root.size(), "surface scan contains no unexpected root")


func _test_readiness_truth(inventory: Dictionary) -> void:
	var authority := inventory.get("authority", {}) as Dictionary
	_expect(bool(authority.get("v06_counter_runtime_preserved", false)), "inventory preserves V0.6 production Counter")
	_expect(not bool(authority.get("full_v0_7_runtime_cutover", true)), "inventory does not claim runtime cutover")
	var readiness := inventory.get("readiness", {}) as Dictionary
	_expect(bool(readiness.get("legacy_catalog_audited", false)), "legacy catalog audit is complete")
	_expect(bool(readiness.get("every_former_counter_card_has_exactly_one_primary_classification", false)), "every former Counter card has exactly one classification")
	_expect(bool(readiness.get("v07_rule_contract_ready", false)), "V0.7 rule contract is ready")
	for key in ["v07_production_catalog_migrated", "v07_core_runtime_ready", "v07_ai_runtime_ready", "v07_player_ui_ready", "old_v06_counter_authority_disabled", "full_v0_7_runtime_cutover"]:
		_expect(not bool(readiness.get(key, true)), "unimplemented production readiness remains false: %s" % key)


func _test_human_readable_inventory() -> void:
	var source := FileAccess.get_file_as_string(INVENTORY_MD_PATH)
	_expect(source.contains("FORMER_COUNTER_CARD_COUNT=4"), "human-readable inventory reports four cards")
	_expect(source.contains("MIGRATE_TO_PROACTIVE_DEFENSE=4"), "human-readable inventory reports four proactive-defense migrations")
	_expect(source.contains("FULL_V0_7_RUNTIME_CUTOVER=false"), "human-readable inventory does not overclaim cutover")
	_expect(source.contains("role.paradox_beast_contract.temporary_monster_counter_conversion"), "human-readable inventory records the separate role capability decision")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("V07_COUNTER_MIGRATION_INVENTORY_PASS (%d checks)" % _checks)
		quit(0)
	else:
		print("V07_COUNTER_MIGRATION_INVENTORY_FAIL (%d/%d failed)" % [_failures.size(), _checks])
		quit(1)
