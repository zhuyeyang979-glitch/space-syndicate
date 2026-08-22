extends RefCounted
class_name V076MilitaryUnitProfileCatalogV1

## Unique read-only adapter for V0.7.6 Alpha 0.7 military Profile authoring.
## It combines the sealed card identity/cost source with frozen V075 combat
## values and new reversible V076 movement/combat authoring. It is not a card
## catalog, runtime military Owner, pathfinder, asset Owner, or ETA Owner.

const StateCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
)

const PROFILE_PATH := "res://data/v076/v076_military_unit_profiles_v1.json"
const PROFILE_AUTHORITY_ID := "V076MilitaryUnitProfileAuthority"
const CATALOG_ADAPTER_ID := "V076MilitaryUnitProfileCatalogV1"
const AUTHORING_DECISION_ID := "V076_ALPHA07_MILITARY_PROFILE_V1"
const NEW_AUTHORING_STATUS := "NEW_V076_ALPHA07_PLAYTEST_AUTHORITY"
const INHERITED_AUTHORING_STATUS := (
	"INHERITED_V075_COMBAT_WITH_NEW_V076_ALPHA07_MOVEMENT_AUTHORITY"
)
const NEW_SOURCE_STATUS := "NOT_INHERITED"
const INHERITED_SOURCE_STATUS := "MIXED_INHERITED_COMBAT_AND_NEW_MOVEMENT"
const BALANCE_MATURITY := "FIRST_PLAYTEST_DEFAULT"
const LIFECYCLE := "ARRIVE_EXECUTE_ONCE_WITHDRAW"
const LEGAL_MISSIONS := ["ASSAULT_REGION", "ASSAULT_MONSTER"]
const LEGAL_TARGET_KINDS := ["REGION", "MONSTER"]
const FORBIDDEN_MISSIONS := [
	"GUARD", "PROTECT", "DEFEND_REGION", "HOLD_POSITION",
	"PERMANENT_GARRISON",
]
const MOVEMENT_CLASSES := ["GROUND", "FLYING"]
const FAMILY_IDS := [
	"planetary_defense_force",
	"air_superiority_fighter",
	"orbital_bomber",
	"heavy_tank",
	"missile_emplacement",
	"submarine_fleet",
	"star_ocean_battleship",
]
const INHERITED_FAMILY_IDS := [
	"planetary_defense_force", "air_superiority_fighter", "submarine_fleet",
]
const NEW_FAMILY_IDS := [
	"orbital_bomber", "heavy_tank", "missile_emplacement",
	"star_ocean_battleship",
]
const EXPECTED_PROFILE_COUNT := 28
const EXPECTED_NEW_PROFILE_COUNT := 16
const EXACT_RECORD_FIELDS := [
	"profile_id",
	"family_id",
	"rank",
	"movement_class",
	"speed_distance_mu_per_tick",
	"allowed_missions",
	"allowed_target_kinds",
	"assault_region_profile",
	"assault_monster_profile",
	"asset_cost_binding",
	"lifecycle",
	"withdraw_after_resolution",
	"persistent_unit",
	"auto_retarget",
	"auto_repeat_task",
	"mission_fallback",
	"name_based_runtime_inference",
	"text_based_runtime_parse",
	"source_provenance",
	"authoring_status",
	"authoring_decision_id",
	"source_status",
	"balance_maturity",
	"reversible",
	"canonical_fingerprint",
]


func load_document() -> Dictionary:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	return normalize_json_value(parsed) as Dictionary


func normalize_json_value(value: Variant) -> Variant:
	if value is float:
		var number := float(value)
		return int(number) if number == floor(number) else number
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(normalize_json_value(item))
		return items
	if value is Dictionary:
		var result := {}
		for key_variant in (value as Dictionary).keys():
			result[str(key_variant)] = normalize_json_value(
				(value as Dictionary)[key_variant]
			)
		return result
	return value


func validate(
	catalog_snapshot: Dictionary,
	balance_defaults: Dictionary
) -> Dictionary:
	return validate_document(load_document(), catalog_snapshot, balance_defaults)


func validate_document(
	document: Dictionary,
	catalog_snapshot: Dictionary,
	balance_defaults: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	var records: Array = document.get("records", []) as Array \
		if document.get("records", []) is Array else []
	var source_index := _source_military_index(catalog_snapshot)
	var inherited_profiles: Dictionary = balance_defaults.get(
		"military_definition_rank_profiles", {}
	) as Dictionary
	var seen_profiles := {}
	var seen_family_ranks := {}
	var records_by_family := {}
	var duplicate_count := 0
	var unknown_family_count := 0
	var source_binding_count := 0
	var fingerprint_count := 0
	var positive_speed_count := 0
	var positive_cost_count := 0
	var new_authored_count := 0
	var inherited_count := 0
	var new_speed_authoring_count := 0
	var forbidden_mission_count := 0
	var persistent_count := 0
	var auto_retarget_count := 0
	var auto_repeat_count := 0
	var fallback_count := 0
	var name_inference_count := 0
	var text_parse_count := 0

	if str(document.get("schema_version", "")) \
			!= "space_syndicate.v076.military_unit_profile_authority.v1":
		errors.append("profile_document_schema_invalid")
	if str(document.get("profile_authority_id", "")) != PROFILE_AUTHORITY_ID:
		errors.append("profile_authority_id_invalid")
	if str(document.get("catalog_adapter_id", "")) != CATALOG_ADAPTER_ID:
		errors.append("profile_catalog_adapter_id_invalid")
	if str(document.get("component_role", "")) != "AUTHORING_RESOURCE":
		errors.append("profile_component_role_invalid")
	if str(document.get("authoring_decision_id", "")) != AUTHORING_DECISION_ID:
		errors.append("profile_authoring_decision_invalid")
	if str(document.get("balance_maturity", "")) != BALANCE_MATURITY \
			or not bool(document.get("reversible", false)):
		errors.append("profile_balance_posture_invalid")
	if bool(document.get("production_green", true)):
		errors.append("profile_production_false_green")
	if bool(document.get("human_green", true)):
		errors.append("profile_human_false_green")
	if int(document.get("profile_record_count", -1)) != EXPECTED_PROFILE_COUNT \
			or int(document.get("new_authored_profile_count", -1)) \
			!= EXPECTED_NEW_PROFILE_COUNT:
		errors.append("profile_declared_count_invalid")

	for record_variant in records:
		if not (record_variant is Dictionary):
			errors.append("profile_record_not_dictionary")
			continue
		var record := record_variant as Dictionary
		var profile_id := str(record.get("profile_id", ""))
		var family_id := str(record.get("family_id", ""))
		var rank := int(record.get("rank", 0))
		var family_rank_key := "%s:%d" % [family_id, rank]
		var shape_errors := _record_shape_errors(record)
		for shape_error in shape_errors:
			errors.append("%s:%s" % [shape_error, profile_id])
		if seen_profiles.has(profile_id) or seen_family_ranks.has(family_rank_key):
			duplicate_count += 1
			errors.append("profile_duplicate:%s" % profile_id)
		seen_profiles[profile_id] = true
		seen_family_ranks[family_rank_key] = true
		if family_id not in FAMILY_IDS:
			unknown_family_count += 1
			errors.append("profile_unknown_family:%s" % family_id)
			continue
		if not records_by_family.has(family_id):
			records_by_family[family_id] = []
		(records_by_family[family_id] as Array).append(record)
		var expected_profile_id := (
			"v075.military.%s.rank_%d" if family_id in INHERITED_FAMILY_IDS
			else "v076.military.%s.rank_%d"
		) % [family_id, rank]
		if profile_id != expected_profile_id:
			errors.append("profile_identity_invalid:%s" % profile_id)
		var source_key := "unit.military.%s:%d" % [family_id, rank]
		var source_machine: Dictionary = source_index.get(source_key, {}) as Dictionary
		if source_machine.is_empty():
			errors.append("profile_source_card_missing:%s" % profile_id)
		elif _validate_asset_binding(
			record.get("asset_cost_binding", {}) as Dictionary,
			source_machine
		):
			source_binding_count += 1
			positive_cost_count += 1
		else:
			errors.append("profile_asset_binding_invalid:%s" % profile_id)
		if canonical_record_fingerprint(record) \
				== str(record.get("canonical_fingerprint", "")):
			fingerprint_count += 1
		else:
			errors.append("profile_fingerprint_invalid:%s" % profile_id)
		if typeof(record.get("speed_distance_mu_per_tick")) == TYPE_INT \
				and int(record.get("speed_distance_mu_per_tick", 0)) > 0:
			positive_speed_count += 1
		var provenance := record.get("source_provenance", {}) as Dictionary
		if str(provenance.get("movement_authoring_status", "")) \
				== NEW_AUTHORING_STATUS \
				and str(provenance.get("movement_source_status", "")) \
				== NEW_SOURCE_STATUS:
			new_speed_authoring_count += 1
		else:
			errors.append("profile_speed_provenance_invalid:%s" % profile_id)
		if family_id in NEW_FAMILY_IDS:
			if str(record.get("authoring_status", "")) != NEW_AUTHORING_STATUS \
					or str(record.get("source_status", "")) != NEW_SOURCE_STATUS:
				errors.append("new_profile_authoring_marker_invalid:%s" % profile_id)
			else:
				new_authored_count += 1
			if not _validate_new_combat_owner(record):
				errors.append("new_profile_combat_owner_invalid:%s" % profile_id)
		else:
			if str(record.get("authoring_status", "")) \
					!= INHERITED_AUTHORING_STATUS \
					or str(record.get("source_status", "")) \
					!= INHERITED_SOURCE_STATUS:
				errors.append("inherited_profile_authoring_marker_invalid:%s" % profile_id)
			else:
				inherited_count += 1
			if not _validate_inherited_combat_profile(
				record, family_id, rank, inherited_profiles
			):
				errors.append("inherited_profile_combat_drift:%s" % profile_id)
		for mission_variant in record.get("allowed_missions", []) as Array:
			if str(mission_variant) in FORBIDDEN_MISSIONS:
				forbidden_mission_count += 1
		if bool(record.get("persistent_unit", true)):
			persistent_count += 1
		if bool(record.get("auto_retarget", true)):
			auto_retarget_count += 1
		if bool(record.get("auto_repeat_task", true)):
			auto_repeat_count += 1
		if str(record.get("mission_fallback", "")) != "NONE":
			fallback_count += 1
		if bool(record.get("name_based_runtime_inference", true)):
			name_inference_count += 1
		if bool(record.get("text_based_runtime_parse", true)):
			text_parse_count += 1

	var region_monotonic_family_count := 0
	var monster_monotonic_family_count := 0
	for family_id_variant in FAMILY_IDS:
		var family_id := str(family_id_variant)
		var family_records: Array = records_by_family.get(family_id, []) as Array
		family_records.sort_custom(func(left: Variant, right: Variant) -> bool:
			return int((left as Dictionary).get("rank", 0)) \
				< int((right as Dictionary).get("rank", 0))
		)
		if family_records.size() != 4:
			errors.append("profile_family_rank_coverage_invalid:%s" % family_id)
			continue
		if _power_monotonic(family_records, "assault_region_profile", "damage_budget"):
			region_monotonic_family_count += 1
		else:
			errors.append("profile_region_power_not_monotonic:%s" % family_id)
		if _power_monotonic(family_records, "assault_monster_profile", "damage"):
			monster_monotonic_family_count += 1
		else:
			errors.append("profile_monster_power_not_monotonic:%s" % family_id)

	if records.size() != EXPECTED_PROFILE_COUNT \
			or source_index.size() != EXPECTED_PROFILE_COUNT:
		errors.append("profile_record_count_invalid")
	if new_authored_count != EXPECTED_NEW_PROFILE_COUNT or inherited_count != 12:
		errors.append("profile_authoring_count_invalid")
	if canonical_document_fingerprint(document) \
			!= str(document.get("profile_catalog_fingerprint_sha256", "")):
		errors.append("profile_catalog_fingerprint_invalid")

	return {
		"valid": errors.is_empty(),
		"status": "GREEN" if errors.is_empty() else "INVALID",
		"errors": errors,
		"existing_military_profile_source_count": 4,
		"reused_profile_schema_count": 3,
		"new_profile_schema_required": true,
		"profile_authority_count": 1,
		"military_profile_record_count": records.size(),
		"new_authored_profile_count": new_authored_count,
		"inherited_profile_count": inherited_count,
		"new_authored_speed_field_count": new_speed_authoring_count,
		"profile_duplicate_count": duplicate_count,
		"profile_unknown_card_family_count": unknown_family_count,
		"source_profile_binding_coverage": "%d/%d" % [
			source_binding_count, records.size(),
		],
		"profile_fingerprint_coverage": "%d/%d" % [
			fingerprint_count, records.size(),
		],
		"speed_positive_count": positive_speed_count,
		"asset_cost_positive_count": positive_cost_count,
		"active_forbidden_mission_count": forbidden_mission_count,
		"active_persistent_unit_count": persistent_count,
		"auto_retarget_count": auto_retarget_count,
		"auto_repeat_task_count": auto_repeat_count,
		"profile_fallback_count": fallback_count,
		"name_based_runtime_inference_count": name_inference_count,
		"text_based_runtime_parse_count": text_parse_count,
		"assault_region_power_monotonic_family_count": region_monotonic_family_count,
		"assault_monster_power_monotonic_family_count": monster_monotonic_family_count,
		"float_authority_field_count": StateCodec.count_float_fields(document),
		"profile_catalog_fingerprint_sha256": canonical_document_fingerprint(document),
		"production_green": false,
		"human_green": false,
	}


func profile_by_id(profile_id: String) -> Dictionary:
	for record_variant in load_document().get("records", []):
		if record_variant is Dictionary:
			var record := record_variant as Dictionary
			if str(record.get("profile_id", "")) == profile_id \
					and _record_shape_errors(record).is_empty() \
					and canonical_record_fingerprint(record) \
					== str(record.get("canonical_fingerprint", "")):
				return record.duplicate(true)
	return {}


func profile_for_family_rank(family_id: String, rank: int) -> Dictionary:
	for record_variant in load_document().get("records", []):
		if record_variant is Dictionary:
			var record := record_variant as Dictionary
			if str(record.get("family_id", "")) == family_id \
					and int(record.get("rank", 0)) == rank:
				return profile_by_id(str(record.get("profile_id", "")))
	return {}


func record_validation_report(record: Dictionary) -> Dictionary:
	var errors := _record_shape_errors(record)
	if canonical_record_fingerprint(record) \
			!= str(record.get("canonical_fingerprint", "")):
		errors.append("profile_fingerprint_invalid")
	return {"valid": errors.is_empty(), "errors": errors}


func canonical_record_fingerprint(record: Dictionary) -> String:
	var value := record.duplicate(true)
	value.erase("canonical_fingerprint")
	return StateCodec.fingerprint(value)


func canonical_document_fingerprint(document: Dictionary) -> String:
	var value := document.duplicate(true)
	value.erase("profile_catalog_fingerprint_sha256")
	var records: Array = (value.get("records", []) as Array).duplicate(true) \
		if value.get("records", []) is Array else []
	records.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary).get("profile_id", "")) \
			< str((right as Dictionary).get("profile_id", ""))
	)
	value["records"] = records
	return StateCodec.fingerprint(value)


func _record_shape_errors(record: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not _exact_fields(record, EXACT_RECORD_FIELDS):
		errors.append("profile_record_fields_invalid")
		return errors
	if str(record.get("family_id", "")) not in FAMILY_IDS \
			or typeof(record.get("rank")) != TYPE_INT \
			or int(record.get("rank", 0)) < 1 \
			or int(record.get("rank", 0)) > 4:
		errors.append("profile_family_rank_invalid")
	if str(record.get("movement_class", "")) not in MOVEMENT_CLASSES \
			or typeof(record.get("speed_distance_mu_per_tick")) != TYPE_INT \
			or int(record.get("speed_distance_mu_per_tick", 0)) <= 0:
		errors.append("profile_movement_invalid")
	var missions: Array = record.get("allowed_missions", []) as Array
	if missions.is_empty() or not _unique_strings(missions):
		errors.append("profile_missions_invalid")
	for mission_variant in missions:
		if str(mission_variant) not in LEGAL_MISSIONS:
			errors.append("profile_mission_forbidden")
	var targets: Array = record.get("allowed_target_kinds", []) as Array
	if targets.is_empty() or not _unique_strings(targets):
		errors.append("profile_targets_invalid")
	for target_variant in targets:
		if str(target_variant) not in LEGAL_TARGET_KINDS:
			errors.append("profile_target_invalid")
	var region_profile := record.get("assault_region_profile", {}) as Dictionary
	var monster_profile := record.get("assault_monster_profile", {}) as Dictionary
	if typeof(region_profile.get("damage_budget")) != TYPE_INT \
			or int(region_profile.get("damage_budget", 0)) <= 0 \
			or typeof(monster_profile.get("damage")) != TYPE_INT \
			or int(monster_profile.get("damage", 0)) <= 0:
		errors.append("profile_combat_power_invalid")
	if str(record.get("lifecycle", "")) != LIFECYCLE \
			or not bool(record.get("withdraw_after_resolution", false)) \
			or bool(record.get("persistent_unit", true)) \
			or bool(record.get("auto_retarget", true)) \
			or bool(record.get("auto_repeat_task", true)):
		errors.append("profile_lifecycle_invalid")
	if str(record.get("mission_fallback", "")) != "NONE" \
			or bool(record.get("name_based_runtime_inference", true)) \
			or bool(record.get("text_based_runtime_parse", true)):
		errors.append("profile_runtime_inference_invalid")
	if str(record.get("authoring_decision_id", "")) != AUTHORING_DECISION_ID \
			or str(record.get("balance_maturity", "")) != BALANCE_MATURITY \
			or not bool(record.get("reversible", false)):
		errors.append("profile_authoring_posture_invalid")
	if not (record.get("source_provenance") is Dictionary) \
			or StateCodec.count_float_fields(record) != 0:
		errors.append("profile_closed_authority_invalid")
	return errors


func _validate_asset_binding(binding: Dictionary, machine: Dictionary) -> bool:
	var color := str(machine.get("industry_id", ""))
	var amount := int((machine.get("asset_cost", {}) as Dictionary).get(color, 0))
	return binding == {
		"owner": "CardRuntimeCatalogV06Resource",
		"source_field": "machine.asset_cost",
		"expected_positive_color": color,
		"expected_positive_amount": amount,
		"validation_only_expected_value": true,
	} and amount > 0


func _validate_inherited_combat_profile(
	record: Dictionary,
	family_id: String,
	rank: int,
	profiles: Dictionary
) -> bool:
	var rows: Array = profiles.get(family_id, []) as Array \
		if profiles.get(family_id, []) is Array else []
	if rank < 1 or rank > rows.size():
		return false
	var inherited := rows[rank - 1] as Dictionary
	var region := record.get("assault_region_profile", {}) as Dictionary
	var monster := record.get("assault_monster_profile", {}) as Dictionary
	var provenance := record.get("source_provenance", {}) as Dictionary
	return str(region.get("owner", "")) == "V075_COMBAT_BALANCE_DEFAULTS" \
		and str(monster.get("owner", "")) == "V075_COMBAT_BALANCE_DEFAULTS" \
		and int(region.get("damage_budget", 0)) \
		== int(inherited.get("region_damage_budget", -1)) \
		and int(monster.get("damage", 0)) \
		== int(inherited.get("monster_damage", -1)) \
		and str(provenance.get("combat_profile_ref", "")) \
		== "/military_definition_rank_profiles/%s/%d" % [family_id, rank - 1]


func _validate_new_combat_owner(record: Dictionary) -> bool:
	var region := record.get("assault_region_profile", {}) as Dictionary
	var monster := record.get("assault_monster_profile", {}) as Dictionary
	return str(region.get("owner", "")) == PROFILE_AUTHORITY_ID \
		and str(monster.get("owner", "")) == PROFILE_AUTHORITY_ID


func _source_military_index(catalog: Dictionary) -> Dictionary:
	var result := {}
	for card_variant in catalog.get("cards", []):
		if not (card_variant is Dictionary):
			continue
		var machine := (card_variant as Dictionary).get("machine", {}) as Dictionary
		if str(machine.get("category_id", "")) != "military":
			continue
		result["%s:%d" % [
			str(machine.get("family_id", "")), int(machine.get("rank", 0)),
		]] = machine
	return result


func _power_monotonic(
	records: Array,
	profile_field: String,
	power_field: String
) -> bool:
	var previous := -1
	for record_variant in records:
		var power := int(((record_variant as Dictionary).get(
			profile_field, {}
		) as Dictionary).get(power_field, 0))
		if power <= previous:
			return false
		previous = power
	return true


func _unique_strings(values: Array) -> bool:
	var seen := {}
	for value_variant in values:
		if typeof(value_variant) != TYPE_STRING or seen.has(str(value_variant)):
			return false
		seen[str(value_variant)] = true
	return true


func _exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for field_variant in expected:
		if not value.has(str(field_variant)):
			return false
	return true
