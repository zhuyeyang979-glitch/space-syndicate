extends SceneTree

const MANIFEST_PATH := "res://resources/content/alpha01/alpha01_content_manifest.tres"
const EXPECTED_ROLES := [
	"环港走私议会",
	"深海菌毯使团",
	"重力矿联董事会",
	"离子军购局",
	"幽幕播报社",
	"黑潮风险基金",
	"孪星兽栏同盟",
	"蜂巢防务议会",
]
const EXPECTED_INDICES := [0, 1, 2, 3, 9, 16, 21, 22]
const EXPECTED_FIELDS_BY_ROLE := {
	"环港走私议会": ["bonus_card_product", "starting_cash_bonus"],
	"深海菌毯使团": ["resource_cash_amount", "resource_cash_product", "starting_cash_bonus"],
	"重力矿联董事会": ["resource_cash_amount", "resource_cash_product", "starting_cash_bonus"],
	"离子军购局": ["monster_upgrade_cash"],
	"幽幕播报社": ["card_history_residual_catalog_charges"],
	"黑潮风险基金": ["high_volatility_bonus_once_per_market_cycle", "high_volatility_first_sale_bonus", "high_volatility_sale_threshold", "starting_cash_bonus"],
	"孪星兽栏同盟": ["monster_control_limit_bonus", "starting_cash_bonus"],
	"蜂巢防务议会": ["military_control_limit_bonus", "starting_cash_bonus"],
}
const FORBIDDEN_CONSUMER_PATH_FRAGMENTS := [
	"/main.gd",
	"/presentation/",
	"/tools/",
	"/tests/",
	"codex",
	"diagnostic",
	"role_catalog_runtime_service.gd",
]

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest: Resource = load(MANIFEST_PATH)
	_expect(manifest != null, "Alpha manifest loads")
	if manifest == null:
		_finish()
		return
	var report: Dictionary = manifest.call("validation_report")
	_expect(bool(report.get("valid", false)), "curated manifest is valid: %s" % JSON.stringify(report.get("errors", [])))
	var roles: Array = Array(manifest.get("role_names"))
	_expect(roles == EXPECTED_ROLES, "Alpha role identities preserve the curated Chinese-name order")
	_expect(not roles.has("星图审计庭") and roles.has("幽幕播报社"), "unsupported Star Chart Audit is replaced by Ghost Broadcast")
	var role_audit: Dictionary = report.get("role_audit", {}) if report.get("role_audit", {}) is Dictionary else {}
	_expect(role_audit.get("selected_indices", []) == EXPECTED_INDICES, "selected source indices remain authoritative and are not Alpha-local remaps")
	_expect(bool(role_audit.get("all_passive_fields_have_non_main_gameplay_consumers", false)), "all selected role mechanics have non-Main gameplay consumers")
	_expect((role_audit.get("unsupported_passive_fields", []) as Array).is_empty(), "selected roles have zero unsupported passive fields")
	var records: Array = role_audit.get("passive_consumer_records", []) if role_audit.get("passive_consumer_records", []) is Array else []
	_expect(records.size() == 18, "all 18 role/passive-field occurrences carry consumer evidence")
	var actual_by_role: Dictionary = {}
	var all_records_valid := true
	var ghost_consumer_valid := false
	for record_variant in records:
		if not (record_variant is Dictionary):
			all_records_valid = false
			continue
		var record := record_variant as Dictionary
		var role_name := str(record.get("role_name", ""))
		var field_name := str(record.get("field_name", ""))
		var path := str(record.get("consumer_path", ""))
		var api := str(record.get("consumer_api", ""))
		if not actual_by_role.has(role_name):
			actual_by_role[role_name] = []
		(actual_by_role[role_name] as Array).append(field_name)
		var lower_path := path.to_lower()
		var forbidden := false
		for fragment in FORBIDDEN_CONSUMER_PATH_FRAGMENTS:
			if lower_path.contains(str(fragment).to_lower()):
				forbidden = true
				break
		var source := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		if str(record.get("consumer_kind", "")) != "non_main_gameplay" or forbidden or source.is_empty() or not source.contains(field_name) or not source.contains(api):
			all_records_valid = false
		if role_name == "幽幕播报社" and field_name == "card_history_residual_catalog_charges":
			ghost_consumer_valid = path == "res://scripts/runtime/intel_private_command_port.gd" and api == "use_residual_frame_catalog" and source.contains("use_residual_catalog_from_public_evidence")
	for role_name in actual_by_role.keys():
		(actual_by_role[role_name] as Array).sort()
	_expect(all_records_valid, "consumer evidence resolves to typed runtime gameplay sources, never Main, presentation, Codex, diagnostics, tools, or tests")
	_expect(actual_by_role == EXPECTED_FIELDS_BY_ROLE, "consumer evidence covers every mechanical field on every selected role without presentation-only substitutes")
	_expect(ghost_consumer_valid, "Ghost Broadcast charges are consumed by the typed private intel command path")
	var selection_snapshot: Dictionary = manifest.call("selection_snapshot")
	_expect(not selection_snapshot.has("passive_consumer_records") and not selection_snapshot.has("role_audit"), "developer consumer evidence stays out of the public content selection snapshot")

	var unsupported_manifest: Resource = manifest.duplicate(true)
	var unsupported_roles := PackedStringArray(manifest.get("role_names"))
	unsupported_roles[4] = "星图审计庭"
	unsupported_manifest.set("role_names", unsupported_roles)
	unsupported_manifest.set("expected_selection_sha256", unsupported_manifest.call("deterministic_sha256"))
	var unsupported_report: Dictionary = unsupported_manifest.call("validation_report")
	var unsupported_role_audit: Dictionary = unsupported_report.get("role_audit", {}) if unsupported_report.get("role_audit", {}) is Dictionary else {}
	var unsupported_fields: Array = unsupported_role_audit.get("unsupported_passive_fields", []) if unsupported_role_audit.get("unsupported_passive_fields", []) is Array else []
	_expect(not bool(unsupported_report.get("valid", true)), "reintroducing Star Chart Audit fails even when its selection hash is repinned")
	_expect(unsupported_fields.size() == 2 and _contains_fragment(unsupported_fields, "intel_city_reveal_charges") and _contains_fragment(unsupported_fields, "city_guess_reward_bonus"), "Main-only or presentation-only Star Chart fields are rejected as unsupported gameplay mechanics")
	_finish()


func _contains_fragment(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ALPHA01_SELECTED_ROLE_CONSUMER_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("ALPHA01_SELECTED_ROLE_CONSUMER_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
