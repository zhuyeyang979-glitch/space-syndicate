extends RefCounted
class_name V075MonsterTrampleCore

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.5"
const MOVEMENT_RECEIPT_CONTRACT_ID := "MonsterMovementReceiptV1"
const TRAMPLE_RESULT_CONTRACT_ID := "MonsterTrampleResolutionV1"
const TRAMPLE_REGION_RECEIPT_CONTRACT_ID := "MonsterTrampleRegionReceiptV1"
const FACILITY_DAMAGE_INTENT_CONTRACT_ID := "FacilityCombatDamageIntentV1"
const CORE_AUTHORITY_ID := "v075.monster.trample.pure_core.v1"
const MAX_SAFE_INTEGER := 9007199254740991
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const INDUSTRY_COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const MOVEMENT_PROFILES := [
	"ground_trample",
	"flying_no_trample",
	"teleport_no_trample",
]


static func resolve_movement(
	movement_receipt: Dictionary,
	monster_source: Dictionary,
	public_facility_projection: Variant,
	balance_defaults: Dictionary,
	processed_movement_ids: Variant = []
) -> Dictionary:
	var movement_error := _movement_receipt_error(movement_receipt)
	if movement_error != "":
		return _failure(movement_error)
	var monster_result := _normalize_monster(monster_source)
	if not bool(monster_result.get("accepted", false)):
		return monster_result
	var monster := monster_result.get("monster", {}) as Dictionary
	if not _monster_matches_receipt(monster, movement_receipt):
		return _failure("trample_monster_movement_binding_invalid")
	var movement_id := str(movement_receipt.get("movement_id", ""))
	if _processed_has(processed_movement_ids, movement_id):
		return _failure("duplicate_movement_receipt")
	var balance_error := _balance_error(
		balance_defaults,
		int(monster.get("rank", 0))
	)
	if balance_error != "":
		return _failure(balance_error)
	var facility_result := _normalize_facilities(public_facility_projection)
	if not bool(facility_result.get("accepted", false)):
		return facility_result
	var facilities := facility_result.get("facilities", []) as Array

	var movement_profile := str(movement_receipt.get("movement_profile", ""))
	var forced_without_trample := (
		bool(movement_receipt.get("forced_movement", false))
		and not bool(movement_receipt.get("forced_movement_trample", false))
	)
	if movement_profile != "ground_trample" or forced_without_trample:
		return _no_effect_result(
			movement_receipt,
			"movement_profile_has_no_trample"
			if movement_profile != "ground_trample"
			else "forced_movement_trample_not_authored"
		)

	var aggregate := _aggregate_region_segments(
		movement_receipt.get("region_path_segments", []) as Array
	)
	var region_order := aggregate.get("region_order", []) as Array
	var distance_by_region := aggregate.get(
		"distance_by_region",
		{}
	) as Dictionary
	var rank := int(monster.get("rank", 0))
	var step_distance := int(balance_defaults.get(
		"trample_distance_step_milli_arc",
		0
	))
	var damage_per_step := _rank_value(
		balance_defaults.get("trample_damage_per_step_by_rank", {}),
		rank
	)
	var damage_cap := _rank_value(
		balance_defaults.get("trample_damage_cap_per_region_by_rank", {}),
		rank
	)
	var region_receipts: Array = []
	var damage_intents: Array = []
	for region_variant in region_order:
		var region_id := str(region_variant)
		var region_distance := int(distance_by_region.get(region_id, 0))
		@warning_ignore("integer_division")
		var step_count: int = region_distance / step_distance
		step_count = maxi(1, step_count)
		if step_count > MAX_SAFE_INTEGER / damage_per_step:
			return _failure("trample_raw_damage_overflow")
		var raw_damage := step_count * damage_per_step
		var region_damage := mini(raw_damage, damage_cap)
		var candidates := _ordered_region_facilities(
			monster,
			facilities,
			region_id
		)
		var allocation := _allocate_budget(region_damage, candidates)
		var allocations := allocation.get("allocations", []) as Array
		var region_receipt_id := _stable_prefixed_id(
			"combat.trample",
			"%s|%s" % [movement_id, region_id]
		)
		var intent_ids: Array[String] = []
		for allocation_variant in allocations:
			var row := allocation_variant as Dictionary
			var amount := int(row.get("damage_amount", 0))
			if amount <= 0:
				continue
			var facility := row.get("facility", {}) as Dictionary
			var combat_receipt_id := _stable_prefixed_id(
				"combat.receipt",
				"%s|%s" % [
					region_receipt_id,
					str(facility.get("facility_id", "")),
				]
			)
			intent_ids.append(combat_receipt_id)
			damage_intents.append({
				"schema_version": SCHEMA_VERSION,
				"contract_id": FACILITY_DAMAGE_INTENT_CONTRACT_ID,
				"ruleset_id": RULESET_ID,
				"source_effect_id": region_receipt_id,
				"target_facility_id": facility.get("facility_id"),
				"expected_generation": facility.get("facility_generation"),
				"damage_amount": amount,
				"damage_kind": "monster_ground_trample",
				"combat_receipt_id": combat_receipt_id,
			})
		var candidate_ids: Array[String] = []
		for candidate_variant in candidates:
			candidate_ids.append(
				str((candidate_variant as Dictionary).get("facility_id", ""))
			)
		region_receipts.append({
			"schema_version": SCHEMA_VERSION,
			"contract_id": TRAMPLE_REGION_RECEIPT_CONTRACT_ID,
			"ruleset_id": RULESET_ID,
			"trample_region_receipt_id": region_receipt_id,
			"movement_id": movement_id,
			"source_instance_id": monster.get("source_instance_id"),
			"source_generation": monster.get("source_generation"),
			"region_id": region_id,
			"distance_milli_arc": region_distance,
			"step_count": step_count,
			"raw_damage": raw_damage,
			"damage_cap": damage_cap,
			"region_damage_budget": region_damage,
			"allocated_damage": int(allocation.get("allocated_damage", 0)),
			"unallocated_damage": int(allocation.get("unallocated_damage", 0)),
			"candidate_facility_ids": candidate_ids,
			"facility_damage_intent_receipt_ids": intent_ids,
			"exact_once": true,
		})
	var result := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": TRAMPLE_RESULT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"authority_id": CORE_AUTHORITY_ID,
		"accepted": true,
		"reason_code": "monster_ground_trample_resolved",
		"movement_id": movement_id,
		"exact_once_journal_key": movement_id,
		"exact_once_journal_consumed": true,
		"movement_profile": movement_profile,
		"ground_trample_applied": true,
		"region_receipts": region_receipts,
		"facility_damage_intents": damage_intents,
		"duplicate_trample_damage_count": 0,
		"unit_damage_count": 0,
		"region_hp_mutation_count": 0,
		"direct_facility_write_count": 0,
		"gameplay_rng_draw_count": 0,
		"trample_result_fingerprint": "",
	}
	return _seal(result, "trample_result_fingerprint")


static func _no_effect_result(
	movement_receipt: Dictionary,
	reason_code: String
) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": TRAMPLE_RESULT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"authority_id": CORE_AUTHORITY_ID,
		"accepted": true,
		"reason_code": reason_code,
		"movement_id": movement_receipt.get("movement_id"),
		"exact_once_journal_key": movement_receipt.get("movement_id"),
		"exact_once_journal_consumed": true,
		"movement_profile": movement_receipt.get("movement_profile"),
		"ground_trample_applied": false,
		"region_receipts": [],
		"facility_damage_intents": [],
		"duplicate_trample_damage_count": 0,
		"unit_damage_count": 0,
		"region_hp_mutation_count": 0,
		"direct_facility_write_count": 0,
		"gameplay_rng_draw_count": 0,
		"trample_result_fingerprint": "",
	}
	return _seal(result, "trample_result_fingerprint")


static func _aggregate_region_segments(segments: Array) -> Dictionary:
	var region_order: Array[String] = []
	var distance_by_region := {}
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		var region_id := str(segment.get("region_id", ""))
		var distance := int(segment.get("distance_milli_arc", 0))
		if not distance_by_region.has(region_id):
			region_order.append(region_id)
			distance_by_region[region_id] = 0
		distance_by_region[region_id] = (
			int(distance_by_region.get(region_id, 0)) + distance
		)
	return {
		"region_order": region_order,
		"distance_by_region": distance_by_region,
	}


static func _ordered_region_facilities(
	monster: Dictionary,
	facilities: Array,
	region_id: String
) -> Array:
	var ordered: Array = []
	for facility_variant in facilities:
		var facility := facility_variant as Dictionary
		if (
			str(facility.get("region_id", "")) != region_id
			or str(facility.get("status", "")) == "destroyed"
			or str(facility.get("owner_player_id", ""))
				== str(monster.get("owner_player_id", ""))
		):
			continue
		var inserted := false
		for index in range(ordered.size()):
			if _facility_is_before(
				monster,
				facility,
				ordered[index] as Dictionary
			):
				ordered.insert(index, facility)
				inserted = true
				break
		if not inserted:
			ordered.append(facility)
	return ordered


static func _facility_is_before(
	monster: Dictionary,
	left: Dictionary,
	right: Dictionary
) -> bool:
	var preferred_color := str(monster.get("preferred_industry_color", ""))
	var left_preferred := str(left.get("industry_id", "")) == preferred_color
	var right_preferred := str(right.get("industry_id", "")) == preferred_color
	if left_preferred != right_preferred:
		return left_preferred
	return str(left.get("facility_id", "")) < str(
		right.get("facility_id", "")
	)


static func _allocate_budget(budget: int, candidates: Array) -> Dictionary:
	if budget <= 0 or candidates.is_empty():
		return {
			"allocations": [],
			"allocated_damage": 0,
			"unallocated_damage": maxi(0, budget),
		}
	@warning_ignore("integer_division")
	var per_facility: int = budget / candidates.size()
	var remainder := budget % candidates.size()
	var allocations: Array = []
	var allocated := 0
	for index in range(candidates.size()):
		var amount := per_facility + (1 if index < remainder else 0)
		if amount <= 0:
			continue
		allocations.append({
			"facility": (candidates[index] as Dictionary).duplicate(true),
			"damage_amount": amount,
		})
		allocated += amount
	return {
		"allocations": allocations,
		"allocated_damage": allocated,
		"unallocated_damage": budget - allocated,
	}


static func _normalize_monster(source: Dictionary) -> Dictionary:
	var source_id := str(source.get("source_instance_id", ""))
	var owner_id := _first_stable_id(
		source,
		["owner_player_id", "owner_id"]
	)
	var generation: Variant = source.get("source_generation", 0)
	var rank: Variant = source.get("rank", 0)
	var preferred_color := str(source.get("preferred_industry_color", ""))
	var movement_profile := str(source.get("movement_profile", ""))
	if (
		not _stable_id(source_id)
		or not _stable_id(owner_id)
		or not _nonnegative_integer(generation)
		or not _positive_integer(rank)
		or int(rank) > 4
		or not INDUSTRY_COLORS.has(preferred_color)
		or not MOVEMENT_PROFILES.has(movement_profile)
		or str(source.get("status", "active")) != "active"
	):
		return _failure("trample_monster_source_invalid")
	return {
		"accepted": true,
		"reason_code": "trample_monster_source_normalized",
		"monster": {
			"source_instance_id": source_id,
			"source_generation": int(generation),
			"owner_player_id": owner_id,
			"rank": int(rank),
			"preferred_industry_color": preferred_color,
			"movement_profile": movement_profile,
		},
	}


static func _normalize_facilities(value: Variant) -> Dictionary:
	var facility_rows: Variant = _extract_facility_rows(value)
	if facility_rows == null:
		return _failure("trample_public_facility_projection_invalid")
	var by_id := {}
	for source_variant in facility_rows as Array:
		if not (source_variant is Dictionary):
			return _failure("trample_public_facility_not_dictionary")
		var source := source_variant as Dictionary
		if str(source.get("occupancy", "occupied")) == "empty":
			continue
		var facility_id := str(source.get("facility_id", ""))
		var owner_id := _first_stable_id(
			source,
			["owner_player_id", "owner_id", "owner_public_id"]
		)
		var generation: Variant = source.get(
			"facility_generation",
			source.get("generation", 0)
		)
		var region_id := str(source.get("region_id", ""))
		var facility_type := str(source.get("facility_type", ""))
		var industry_id := str(source.get("industry_id", ""))
		var damage_points: Variant = source.get("damage_points", 0)
		var status := str(source.get("status", "active"))
		if bool(source.get("destroyed", false)):
			status = "destroyed"
		elif (
			status == "active"
			and _nonnegative_integer(damage_points)
			and int(damage_points) > 0
		):
			status = "damaged"
		if (
			not _stable_id(facility_id)
			or not _stable_id(owner_id)
			or not _stable_id(region_id)
			or not _nonnegative_integer(generation)
			or not FACILITY_TYPES.has(facility_type)
			or not INDUSTRY_COLORS.has(industry_id)
			or not ["active", "damaged", "destroyed"].has(status)
		):
			return _failure("trample_public_facility_invalid")
		if by_id.has(facility_id):
			return _failure("trample_duplicate_public_facility_id")
		by_id[facility_id] = {
			"facility_id": facility_id,
			"facility_generation": int(generation),
			"owner_player_id": owner_id,
			"region_id": region_id,
			"facility_type": facility_type,
			"industry_id": industry_id,
			"status": status,
		}
	var ids: Array[String] = []
	for id_variant in by_id.keys():
		ids.append(str(id_variant))
	ids.sort()
	var facilities: Array = []
	for facility_id in ids:
		facilities.append((by_id.get(facility_id) as Dictionary).duplicate(true))
	return {
		"accepted": true,
		"reason_code": "trample_public_facilities_normalized",
		"facilities": facilities,
	}


static func _extract_facility_rows(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if not (value is Dictionary):
		return null
	var source := value as Dictionary
	for field_name in [
		"public_facility_slots",
		"public_facilities",
		"facilities",
		"slots",
	]:
		if source.get(field_name) is Array:
			return (source.get(field_name) as Array).duplicate(true)
	return null


static func _movement_receipt_error(receipt: Dictionary) -> String:
	if (
		receipt.get("contract_id") != MOVEMENT_RECEIPT_CONTRACT_ID
		or receipt.get("ruleset_id") != RULESET_ID
		or not _stable_id(receipt.get("movement_id"))
		or not _stable_id(receipt.get("source_instance_id"))
		or not _nonnegative_integer(receipt.get("source_generation"))
		or not _positive_integer(receipt.get("source_rank"))
		or int(receipt.get("source_rank", 0)) > 4
		or not _stable_id(receipt.get("owner_player_id"))
		or not MOVEMENT_PROFILES.has(str(receipt.get("movement_profile", "")))
		or not (receipt.get("forced_movement") is bool)
		or not (receipt.get("forced_movement_trample") is bool)
		or not _stable_id(receipt.get("start_region_id"))
		or not _stable_id(receipt.get("destination_region_id"))
		or not (receipt.get("ordered_region_path") is Array)
		or not (receipt.get("region_path_segments") is Array)
		or not _positive_integer(receipt.get("distance_milli_arc"))
		or not _fingerprint_matches(
			receipt,
			"movement_receipt_fingerprint"
		)
		or not _is_pure_data(receipt)
	):
		return "monster_movement_receipt_invalid"
	var path := receipt.get("ordered_region_path") as Array
	if (
		path.size() < 2
		or str(path[0]) != str(receipt.get("start_region_id", ""))
		or str(path[-1]) != str(receipt.get("destination_region_id", ""))
	):
		return "monster_movement_path_binding_invalid"
	var seen_regions := {}
	for region_variant in path:
		if not _stable_id(region_variant) or seen_regions.has(str(region_variant)):
			return "monster_movement_path_loop_invalid"
		seen_regions[str(region_variant)] = true
	var segment_total := 0
	for segment_variant in receipt.get("region_path_segments") as Array:
		if not (segment_variant is Dictionary):
			return "monster_movement_segment_invalid"
		var segment := segment_variant as Dictionary
		if (
			not _stable_id(segment.get("region_id"))
			or not seen_regions.has(str(segment.get("region_id", "")))
			or not _positive_integer(segment.get("distance_milli_arc"))
		):
			return "monster_movement_segment_invalid"
		var distance := int(segment.get("distance_milli_arc", 0))
		if segment_total > MAX_SAFE_INTEGER - distance:
			return "monster_movement_segment_overflow"
		segment_total += distance
	if segment_total != int(receipt.get("distance_milli_arc", 0)):
		return "monster_movement_distance_parity_invalid"
	return ""


static func _monster_matches_receipt(
	monster: Dictionary,
	receipt: Dictionary
) -> bool:
	return (
		monster.get("source_instance_id") == receipt.get("source_instance_id")
		and monster.get("source_generation") == receipt.get("source_generation")
		and monster.get("owner_player_id") == receipt.get("owner_player_id")
		and monster.get("rank") == receipt.get("source_rank")
		and monster.get("movement_profile") == receipt.get("movement_profile")
	)


static func _balance_error(balance: Dictionary, rank: int) -> String:
	var step: Variant = balance.get("trample_distance_step_milli_arc")
	var per_step := _rank_value(
		balance.get("trample_damage_per_step_by_rank", {}),
		rank
	)
	var cap := _rank_value(
		balance.get("trample_damage_cap_per_region_by_rank", {}),
		rank
	)
	if (
		not _positive_integer(step)
		or per_step <= 0
		or cap <= 0
	):
		return "trample_balance_defaults_invalid"
	return ""


static func _rank_value(value: Variant, rank: int) -> int:
	if not (value is Dictionary):
		return -1
	var source := value as Dictionary
	for key_variant in [str(rank), "l%d" % rank, rank]:
		var candidate: Variant = source.get(key_variant)
		if _positive_integer(candidate):
			return int(candidate)
	return -1


static func _processed_has(value: Variant, movement_id: String) -> bool:
	if value is Array:
		return (value as Array).has(movement_id)
	if value is Dictionary:
		return bool((value as Dictionary).get(movement_id, false))
	return false


static func _first_stable_id(source: Dictionary, fields: Array) -> String:
	for field_variant in fields:
		var value: Variant = source.get(str(field_variant))
		if _stable_id(value):
			return str(value)
	return ""


static func _stable_prefixed_id(prefix: String, identity: String) -> String:
	return "%s.%s" % [prefix, identity.sha256_text().substr(0, 24)]


static func _failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
	}


static func _seal(unsealed: Dictionary, fingerprint_field: String) -> Dictionary:
	if not _is_pure_data(unsealed):
		return {}
	var sealed := unsealed.duplicate(true)
	sealed.erase(fingerprint_field)
	sealed[fingerprint_field] = _fingerprint(sealed)
	return sealed


static func _fingerprint_matches(
	value: Dictionary,
	fingerprint_field: String
) -> bool:
	var expected := str(value.get(fingerprint_field, ""))
	if expected.length() != 64:
		return false
	var unsealed := value.duplicate(true)
	unsealed.erase(fingerprint_field)
	return expected == _fingerprint(unsealed)


static func _fingerprint(value: Variant) -> String:
	var canonical := _canonical_json(value)
	return canonical.sha256_text().to_lower() if not canonical.is_empty() else ""


static func _canonical_json(value: Variant) -> String:
	if not _is_pure_data(value):
		return ""
	if value == null or value is String or value is bool or value is int:
		return JSON.stringify(value)
	if value is Array:
		var parts: Array[String] = []
		for item_variant in value as Array:
			parts.append(_canonical_json(item_variant))
		return "[" + ",".join(parts) + "]"
	var source := value as Dictionary
	var keys: Array[String] = []
	for key_variant in source.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(
			JSON.stringify(key) + ":" + _canonical_json(source.get(key))
		)
	return "{" + ",".join(members) + "}"


static func _is_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value == null or value is String or value is bool:
		return true
	if value is int:
		return _safe_integer(value)
	if value is Array:
		for item_variant in value as Array:
			if not _is_pure_data(item_variant, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if (
				not (key_variant is String)
				or not _is_pure_data(
					(value as Dictionary).get(key_variant),
					depth + 1
				)
			):
				return false
		return true
	return false


static func _safe_integer(value: Variant) -> bool:
	return (
		value is int
		and int(value) >= -MAX_SAFE_INTEGER
		and int(value) <= MAX_SAFE_INTEGER
	)


static func _nonnegative_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) >= 0


static func _positive_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) > 0


static func _stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160:
		return false
	var previous_separator := false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		var separator := code == 46 or code == 95 or code == 45
		if index == 0 and not lower:
			return false
		if not lower and not digit and not separator:
			return false
		if separator and previous_separator:
			return false
		previous_separator = separator
	return not previous_separator
