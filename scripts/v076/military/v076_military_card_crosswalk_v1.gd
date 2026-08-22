extends RefCounted
class_name V076MilitaryCardCrosswalkV1

## Read-only adapter from the sealed V0.6 semantic card catalog to the V0.7.6
## private Direct Action contract. This class owns no card definitions, unit
## state, assets, movement, tick, replay, RNG, map, or presentation state.

const AuthorityCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
)
const ProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)

const CROSSWALK_PATH := "res://data/diagnostics/v076_military_card_crosswalk_v1.json"

const EXPECTED_SOURCE_CARD_COUNT := 28
const EXPECTED_SOURCE_FAMILY_COUNT := 7
const RANK_SET := [1, 2, 3, 4]
const LEGAL_MISSIONS := ["ASSAULT_REGION", "ASSAULT_MONSTER"]
const LEGAL_TARGET_KINDS := ["REGION", "MONSTER"]
const FORBIDDEN_MISSIONS := ["GUARD", "PROTECT", "DEFEND_REGION"]
const EXPECTED_PRIOR_EXACT_PROJECTION_SHA256 := (
	"98d1a65fdcc7dde5712dc19cc14006ae2796946062385118196aeabfdd855078"
)
const MAPPING_STATUSES := [
	"EXACT_MAPPED",
	"REAUTHOR_REQUIRED",
	"RETIRED_FROM_ALPHA07_POOL",
	"UNRESOLVED_SOURCE_CONFLICT",
]
const EXACT_RECORD_FIELDS := [
	"source_card_id",
	"source_machine_fingerprint_sha256",
	"source_family_id",
	"source_rank",
	"unit_profile_id",
	"direct_action_command_kind",
	"allowed_missions",
	"allowed_target_kinds",
	"asset_cost_binding",
	"movement_speed_binding",
	"combat_profile_binding",
	"lifecycle",
	"input_projection",
	"result_projection",
	"public_batch_entry",
	"shared_sushi_track_resolution",
	"public_card_text_disclosure",
	"exact_once_card_instance_binding",
	"stale_hand_membership_revalidation",
	"source_collision_rejection",
	"name_based_mission_inference",
	"text_parse_runtime_rule",
	"mission_fallback",
	"mapping_status",
	"authoring_gap_codes",
]


func load_document() -> Dictionary:
	var file := FileAccess.open(CROSSWALK_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func validate(
	catalog_snapshot: Dictionary,
	active_catalog: Dictionary,
	balance_defaults: Dictionary
) -> Dictionary:
	return validate_document(
		load_document(), catalog_snapshot, active_catalog, balance_defaults
	)


func validate_document(
	document: Dictionary,
	catalog_snapshot: Dictionary,
	_active_catalog: Dictionary,
	balance_defaults: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	if catalog_snapshot.is_empty():
		errors.append("source_catalog_snapshot_missing")
	var source_cards := _source_military_cards(catalog_snapshot)
	var source_index := _index_source_cards(source_cards)
	var family_ranks := _family_rank_index(source_cards)
	var profiles: Dictionary = balance_defaults.get(
		"military_definition_rank_profiles", {}
	) as Dictionary
	var profile_catalog := ProfileCatalog.new()
	var profile_document := profile_catalog.load_document()
	var profile_report := profile_catalog.validate_document(
		profile_document, catalog_snapshot, balance_defaults
	)
	var profile_index := _profile_index(profile_document)
	var records: Array = document.get("records", []) \
		if document.get("records", []) is Array else []
	var seen: Dictionary = {}
	var duplicate_count := 0
	var unknown_source_count := 0
	var fingerprint_match_count := 0
	var exact_count := 0
	var reauthor_count := 0
	var retired_count := 0
	var conflict_count := 0
	var forbidden_mission_count := 0
	var name_inference_count := 0
	var text_parse_count := 0
	var fallback_count := 0
	var positive_cost_count := 0
	var profile_binding_count := 0
	var exact_profile_binding_count := 0
	var unit_profile_id_count := 0
	var public_batch_count := 0
	var sushi_count := 0
	var public_card_text_count := 0
	var production_green_count := 0
	var human_green_count := 0
	var exact_once_count := 0
	var stale_revalidation_count := 0
	var collision_rejection_count := 0

	if str(document.get("component_role", "")) != "ADAPTER":
		errors.append("component_role_not_adapter")
	if str(document.get("mapping_status", "")) != "ISOLATED_GREEN_28_OF_28":
		errors.append("mapping_status_not_exact_green")
	if str(document.get("profile_authority_id", "")) \
			!= ProfileCatalog.PROFILE_AUTHORITY_ID:
		errors.append("profile_authority_binding_invalid")
	if int(document.get("exact_mapping_preserved_count", 0)) != 12:
		errors.append("prior_exact_mapping_preservation_invalid")
	if canonical_prior_exact_projection_fingerprint(document) \
			!= EXPECTED_PRIOR_EXACT_PROJECTION_SHA256:
		errors.append("prior_exact_mapping_projection_regressed")
	var correction_evidence := document.get(
		"ownership_binding_correction_evidence", {}
	) as Dictionary
	if str(correction_evidence.get("status", "")) \
			!= "REGRESSED_WITH_EVIDENCE" \
			or int(correction_evidence.get("affected_record_count", 0)) != 12 \
			or str(correction_evidence.get("scope", "")) \
			!= "movement_speed_binding_only":
		errors.append("movement_owner_regression_evidence_invalid")
	if not bool(profile_report.get("valid", false)):
		errors.append("profile_authority_invalid")
	if bool(document.get("owns_card_catalog", true)):
		errors.append("crosswalk_claims_card_catalog_ownership")
	if bool(document.get("production_green", true)):
		production_green_count += 1
		errors.append("production_false_green")
	if bool(document.get("human_green", true)):
		human_green_count += 1
		errors.append("human_false_green")

	for record_variant in records:
		if not (record_variant is Dictionary):
			errors.append("mapping_record_not_dictionary")
			continue
		var record := record_variant as Dictionary
		var card_id := str(record.get("source_card_id", ""))
		if not _exact_fields(record, EXACT_RECORD_FIELDS):
			errors.append("mapping_fields_invalid:%s" % card_id)
		if seen.has(card_id):
			duplicate_count += 1
			errors.append("duplicate_mapping:%s" % card_id)
		seen[card_id] = true
		if not source_index.has(card_id):
			unknown_source_count += 1
			errors.append("unknown_source_card:%s" % card_id)
			continue
		var machine := source_index[card_id] as Dictionary
		if str(machine.get("category_id", "")) != "military":
			unknown_source_count += 1
			errors.append("non_military_source_card:%s" % card_id)
			continue
		if str(record.get("source_family_id", "")) != str(machine.get("family_id", "")) \
		or int(record.get("source_rank", 0)) != int(machine.get("rank", 0)):
			errors.append("source_identity_mismatch:%s" % card_id)
		var expected_fingerprint := AuthorityCodec.fingerprint(
			_canonical_source_machine(machine)
		)
		if str(record.get("source_machine_fingerprint_sha256", "")) \
		== expected_fingerprint:
			fingerprint_match_count += 1
		else:
			errors.append("source_fingerprint_mismatch:%s" % card_id)

		var unit_profile_id := str(record.get("unit_profile_id", ""))
		if not unit_profile_id.is_empty():
			unit_profile_id_count += 1
		else:
			errors.append("unit_profile_id_empty:%s" % card_id)
		var status := str(record.get("mapping_status", ""))
		if status not in MAPPING_STATUSES:
			errors.append("mapping_status_invalid:%s" % card_id)
		match status:
			"EXACT_MAPPED": exact_count += 1
			"REAUTHOR_REQUIRED": reauthor_count += 1
			"RETIRED_FROM_ALPHA07_POOL": retired_count += 1
			"UNRESOLVED_SOURCE_CONFLICT": conflict_count += 1

		var missions: Array = record.get("allowed_missions", []) as Array
		for mission_variant in missions:
			var mission := str(mission_variant)
			if mission in FORBIDDEN_MISSIONS:
				forbidden_mission_count += 1
			if mission not in LEGAL_MISSIONS:
				errors.append("mission_invalid:%s:%s" % [card_id, mission])
		var targets: Array = record.get("allowed_target_kinds", []) as Array
		for target_variant in targets:
			if str(target_variant) not in LEGAL_TARGET_KINDS:
				errors.append("target_kind_invalid:%s" % card_id)
		if forbidden_mission_count > 0:
			errors.append("forbidden_mission_present:%s" % card_id)

		if bool(record.get("name_based_mission_inference", true)):
			name_inference_count += 1
			errors.append("name_based_mission_inference:%s" % card_id)
		if bool(record.get("text_parse_runtime_rule", true)):
			text_parse_count += 1
			errors.append("text_parse_runtime_rule:%s" % card_id)
		if str(record.get("mission_fallback", "")) != "NONE":
			fallback_count += 1
			errors.append("mission_fallback_present:%s" % card_id)
		if bool(record.get("public_batch_entry", true)):
			public_batch_count += 1
			errors.append("public_batch_entry_present:%s" % card_id)
		if bool(record.get("shared_sushi_track_resolution", true)):
			sushi_count += 1
			errors.append("shared_sushi_track_resolution_present:%s" % card_id)
		if bool(record.get("public_card_text_disclosure", true)):
			public_card_text_count += 1
			errors.append("public_card_text_disclosure_present:%s" % card_id)
		if bool(record.get("exact_once_card_instance_binding", false)):
			exact_once_count += 1
		else:
			errors.append("exact_once_binding_missing:%s" % card_id)
		if bool(record.get("stale_hand_membership_revalidation", false)):
			stale_revalidation_count += 1
		else:
			errors.append("stale_revalidation_missing:%s" % card_id)
		if bool(record.get("source_collision_rejection", false)):
			collision_rejection_count += 1
		else:
			errors.append("collision_rejection_missing:%s" % card_id)

		var asset_binding: Dictionary = record.get(
			"asset_cost_binding", {}
		) as Dictionary
		if _validate_asset_binding(asset_binding, machine):
			positive_cost_count += 1
		else:
			errors.append("asset_cost_binding_invalid:%s" % card_id)
		if not _validate_movement_binding(
			record.get("movement_speed_binding", {}) as Dictionary,
			unit_profile_id
		):
			errors.append("movement_speed_binding_invalid:%s" % card_id)

		var family_id := str(record.get("source_family_id", ""))
		var short_family := family_id.trim_prefix("unit.military.")
		var gap_codes: Array = record.get("authoring_gap_codes", []) as Array
		if status == "EXACT_MAPPED":
			if not profile_index.has(unit_profile_id):
				errors.append("exact_mapping_profile_missing:%s" % card_id)
			else:
				exact_profile_binding_count += 1
			if missions != LEGAL_MISSIONS or targets != LEGAL_TARGET_KINDS:
				errors.append("exact_mapping_action_surface_invalid:%s" % card_id)
			if not gap_codes.is_empty():
				errors.append("exact_mapping_has_gap:%s" % card_id)
			if _validate_combat_profile_binding(
				record.get("combat_profile_binding", {}) as Dictionary,
				short_family,
				int(record.get("source_rank", 0)),
				profiles,
				profile_index,
				unit_profile_id
			):
				profile_binding_count += 1
			else:
				errors.append("combat_profile_binding_invalid:%s" % card_id)
		elif status == "REAUTHOR_REQUIRED":
			if not missions.is_empty() or not targets.is_empty():
				errors.append("reauthor_record_claims_action_surface:%s" % card_id)
			if gap_codes.is_empty():
				errors.append("reauthor_gap_codes_missing:%s" % card_id)

	var unmapped_count := 0
	for card_id_variant in source_index.keys():
		if not seen.has(str(card_id_variant)):
			unmapped_count += 1
			errors.append("source_card_unmapped:%s" % str(card_id_variant))
	var coverage_count := 0
	for ranks_variant in family_ranks.values():
		var ranks: Array = (ranks_variant as Array).duplicate()
		ranks.sort()
		if ranks == RANK_SET:
			coverage_count += 1
		else:
			errors.append("source_family_rank_incomplete")
	if source_cards.size() != EXPECTED_SOURCE_CARD_COUNT:
		errors.append("source_military_card_count_drift")
	if family_ranks.size() != EXPECTED_SOURCE_FAMILY_COUNT:
		errors.append("source_military_family_count_drift")
	if records.size() != source_cards.size():
		errors.append("mapping_record_count_mismatch")

	return {
		"valid": errors.is_empty(),
		"status": "PARTIAL" if errors.is_empty() and reauthor_count > 0 else (
			"GREEN" if errors.is_empty() else "INVALID"
		),
		"errors": errors,
		"source_military_card_count": source_cards.size(),
		"source_military_family_count": family_ranks.size(),
		"source_family_rank_coverage": "%d/%d" % [
			coverage_count, family_ranks.size()
		],
		"source_card_fingerprint_coverage": "%d/%d" % [
			fingerprint_match_count, source_cards.size()
		],
		"mapping_record_count": records.size(),
		"exact_mapped_count": exact_count,
		"reauthor_required_count": reauthor_count,
		"retired_from_alpha07_count": retired_count,
		"unresolved_source_conflict_count": conflict_count,
		"unmapped_card_count": unmapped_count,
		"duplicate_mapping_count": duplicate_count,
		"unknown_source_card_count": unknown_source_count,
		"missing_family_rank_record_count": (
			family_ranks.size() - coverage_count
		),
		"unit_profile_id_coverage": "%d/%d" % [
			unit_profile_id_count, records.size()
		],
		"positive_asset_cost_binding_count": positive_cost_count,
		"exact_combat_profile_binding_count": profile_binding_count,
		"profile_binding_coverage": "%d/%d" % [
			exact_profile_binding_count, records.size(),
		],
		"exact_mapping_preserved_count": int(document.get(
			"exact_mapping_preserved_count", 0
		)),
		"regressed_with_evidence_count": int(correction_evidence.get(
			"affected_record_count", 0
		)),
		"prior_exact_mapping_projection_sha256": (
			canonical_prior_exact_projection_fingerprint(document)
		),
		"forbidden_mission_token_count": forbidden_mission_count,
		"name_based_mission_inference_count": name_inference_count,
		"text_parse_runtime_rule_count": text_parse_count,
		"mission_fallback_count": fallback_count,
		"public_batch_entry_count": public_batch_count,
		"shared_sushi_track_resolution_count": sushi_count,
		"public_card_text_disclosure_count": public_card_text_count,
		"exact_once_binding_count": exact_once_count,
		"stale_hand_membership_revalidation_count": stale_revalidation_count,
		"source_collision_rejection_count": collision_rejection_count,
		"production_green_count": production_green_count,
		"human_green_count": human_green_count,
		"crosswalk_fingerprint_sha256": canonical_fingerprint(document),
	}


func record_for_card_id(card_id: String) -> Dictionary:
	for record_variant in load_document().get("records", []):
		if record_variant is Dictionary \
		and str((record_variant as Dictionary).get("source_card_id", "")) == card_id:
			return (record_variant as Dictionary).duplicate(true)
	return {}


func canonical_fingerprint(document: Dictionary) -> String:
	var records: Array = (document.get("records", []) as Array).duplicate(true) \
		if document.get("records", []) is Array else []
	records.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary).get("source_card_id", "")) \
		< str((right as Dictionary).get("source_card_id", ""))
	)
	var fingerprint_payload := {
		"schema_version": str(document.get("schema_version", "")),
		"crosswalk_id": str(document.get("crosswalk_id", "")),
		"mapping_status": str(document.get("mapping_status", "")),
		"records": records,
	}
	return AuthorityCodec.fingerprint(
		_canonical_source_machine(fingerprint_payload)
	)


func canonical_prior_exact_projection_fingerprint(document: Dictionary) -> String:
	var projection: Array = []
	for record_variant in document.get("records", []):
		if not (record_variant is Dictionary):
			continue
		var record := record_variant as Dictionary
		if not str(record.get("unit_profile_id", "")).begins_with("v075.military."):
			continue
		var row := record.duplicate(true)
		row.erase("movement_speed_binding")
		projection.append(row)
	projection.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary).get("source_card_id", "")) \
			< str((right as Dictionary).get("source_card_id", ""))
	)
	return AuthorityCodec.fingerprint(_canonical_source_machine(projection))


func _source_military_cards(catalog: Dictionary) -> Array:
	var result: Array = []
	for card_variant in catalog.get("cards", []):
		if not (card_variant is Dictionary):
			continue
		var machine: Dictionary = (card_variant as Dictionary).get(
			"machine", {}
		) as Dictionary
		if str(machine.get("category_id", "")) == "military":
			result.append(machine.duplicate(true))
	return result


func _index_source_cards(cards: Array) -> Dictionary:
	var result: Dictionary = {}
	for machine_variant in cards:
		var machine := machine_variant as Dictionary
		result[str(machine.get("card_id", ""))] = machine
	return result


func _family_rank_index(cards: Array) -> Dictionary:
	var result: Dictionary = {}
	for machine_variant in cards:
		var machine := machine_variant as Dictionary
		var family_id := str(machine.get("family_id", ""))
		if not result.has(family_id):
			result[family_id] = []
		(result[family_id] as Array).append(int(machine.get("rank", 0)))
	return result


func _active_family_ids(active_catalog: Dictionary) -> Array:
	var result: Array = []
	for definition_variant in active_catalog.get("military_definitions", []):
		if definition_variant is Dictionary:
			result.append(str((definition_variant as Dictionary).get(
				"military_definition_id", ""
			)))
	return result


func _validate_asset_binding(binding: Dictionary, machine: Dictionary) -> bool:
	var color := str(machine.get("industry_id", ""))
	var source_amount := int((machine.get("asset_cost", {}) as Dictionary).get(
		color, 0
	))
	return str(binding.get("owner", "")) == "CardRuntimeCatalogV06Resource" \
		and str(binding.get("source_field", "")) == "machine.asset_cost" \
		and str(binding.get("expected_positive_color", "")) == color \
		and int(binding.get("expected_positive_amount", 0)) == source_amount \
		and bool(binding.get("validation_only_expected_value", false)) \
		and source_amount > 0


func _validate_movement_binding(
	binding: Dictionary,
	unit_profile_id: String
) -> bool:
	return binding == {
		"owner": ProfileCatalog.PROFILE_AUTHORITY_ID,
		"profile_id_source_field": "unit_profile_id",
		"source_field": "speed_distance_mu_per_tick",
		"crosswalk_owns_value": false,
	} and not unit_profile_id.is_empty()


func _validate_combat_profile_binding(
	binding: Dictionary,
	family_id: String,
	rank: int,
	profiles: Dictionary,
	profile_index: Dictionary,
	unit_profile_id: String
) -> bool:
	if not profile_index.has(unit_profile_id) \
			or bool(binding.get("crosswalk_owns_values", true)):
		return false
	var authored := profile_index[unit_profile_id] as Dictionary
	if str(authored.get("family_id", "")) != family_id \
			or int(authored.get("rank", 0)) != rank:
		return false
	if family_id in ProfileCatalog.NEW_FAMILY_IDS:
		return binding.get("owner") == ProfileCatalog.PROFILE_AUTHORITY_ID \
			and binding.get("profile_ref") == "/%s" % unit_profile_id \
			and binding.get("required_fields") == [
				"assault_region_profile.damage_budget",
				"assault_monster_profile.damage",
			] \
			and int((authored.get(
				"assault_region_profile", {}
			) as Dictionary).get("damage_budget", 0)) > 0 \
			and int((authored.get(
				"assault_monster_profile", {}
			) as Dictionary).get("damage", 0)) > 0
	if binding.get("owner") != "V075_COMBAT_BALANCE_DEFAULTS" \
			or binding.get("profile_ref") \
			!= "/military_definition_rank_profiles/%s/%d" % [family_id, rank - 1] \
			or binding.get("required_fields") \
			!= ["primary_asset_cost", "region_damage_budget", "monster_damage"]:
		return false
	var family_profiles: Array = profiles.get(family_id, []) \
		if profiles.get(family_id, []) is Array else []
	if rank < 1 or rank > family_profiles.size():
		return false
	var profile: Dictionary = family_profiles[rank - 1] as Dictionary
	return int(profile.get("rank", 0)) == rank \
		and int(profile.get("primary_asset_cost", 0)) > 0 \
		and int(profile.get("region_damage_budget", 0)) > 0 \
		and int(profile.get("monster_damage", 0)) > 0


func _profile_index(document: Dictionary) -> Dictionary:
	var result := {}
	for record_variant in document.get("records", []):
		if record_variant is Dictionary:
			var record := record_variant as Dictionary
			result[str(record.get("profile_id", ""))] = record
	return result


func _string_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[str(value)] = true
	return result


func _canonical_source_machine(value: Variant) -> Variant:
	if value is float:
		var number := float(value)
		if number == floor(number):
			return int(number)
		return number
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_canonical_source_machine(item))
		return items
	if value is Dictionary:
		var result: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			result[key] = _canonical_source_machine((value as Dictionary)[key_variant])
		return result
	return value


func _exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true
