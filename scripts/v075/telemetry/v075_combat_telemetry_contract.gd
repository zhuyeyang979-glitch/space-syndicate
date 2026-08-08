extends RefCounted
class_name V075CombatTelemetryContract

const RULESET_ID := "v0.7.5"
const EVENT_TYPES := [
	"monster_card_purchased",
	"monster_deployed",
	"monster_refreshed",
	"monster_upgraded",
	"monster_replaced",
	"monster_target_selected",
	"monster_moved",
	"monster_trample_resolved",
	"monster_basic_attack",
	"monster_private_skill_requested",
	"monster_private_skill_resolved",
	"monster_skill_fizzled",
	"monster_skill_cooldown_started",
	"monster_skill_ready",
	"military_card_purchased",
	"military_region_assault",
	"military_monster_assault",
	"military_withdrawn",
	"facility_combat_damaged",
]
const COMMON_PAYLOAD_FIELDS := [
	"card_kind",
	"card_rank",
	"monster_card_mode",
	"source_rank",
	"preferred_industry_color",
	"movement_profile",
	"start_region_id",
	"destination_region_id",
	"region_id",
	"target_region_id",
	"path_hops",
	"distance_milli_arc",
	"damage_amount",
	"armor_absorbed",
	"facility_type",
	"result",
	"public_reason_code",
	"request_result",
	"public_effect_id",
	"task_kind",
	"withdrawal_reason",
	"target_kind",
	"target_status",
	"facility_damage_state",
	"count",
]
const EVENT_PAYLOAD_FIELDS := {
	"monster_card_purchased": [
		"card_kind",
		"card_rank",
	],
	"monster_deployed": [
		"source_rank",
		"preferred_industry_color",
		"region_id",
		"movement_profile",
	],
	"monster_refreshed": [
		"source_rank",
		"result",
	],
	"monster_upgraded": [
		"card_rank",
		"source_rank",
		"result",
	],
	"monster_replaced": [
		"card_rank",
		"source_rank",
		"preferred_industry_color",
	],
	"monster_target_selected": [
		"preferred_industry_color",
		"target_region_id",
		"target_kind",
		"facility_type",
	],
	"monster_moved": [
		"source_rank",
		"movement_profile",
		"start_region_id",
		"destination_region_id",
		"path_hops",
		"distance_milli_arc",
	],
	"monster_trample_resolved": [
		"source_rank",
		"region_id",
		"distance_milli_arc",
		"damage_amount",
		"facility_type",
	],
	"monster_basic_attack": [
		"source_rank",
		"target_kind",
		"damage_amount",
		"armor_absorbed",
	],
	"monster_private_skill_requested": [
		"source_rank",
		"request_result",
		"public_reason_code",
	],
	"monster_private_skill_resolved": [
		"source_rank",
		"public_effect_id",
		"target_kind",
		"damage_amount",
	],
	"monster_skill_fizzled": [
		"source_rank",
		"public_reason_code",
	],
	"monster_skill_cooldown_started": [
		"source_rank",
	],
	"monster_skill_ready": [
		"source_rank",
	],
	"military_card_purchased": [
		"card_kind",
		"card_rank",
	],
	"military_region_assault": [
		"card_rank",
		"task_kind",
		"target_region_id",
		"damage_amount",
		"result",
	],
	"military_monster_assault": [
		"card_rank",
		"task_kind",
		"target_kind",
		"damage_amount",
		"armor_absorbed",
		"result",
	],
	"military_withdrawn": [
		"card_rank",
		"withdrawal_reason",
	],
	"facility_combat_damaged": [
		"facility_type",
		"region_id",
		"damage_amount",
		"facility_damage_state",
	],
}
const FORBIDDEN_FIELD_FRAGMENTS := [
	"skill_definition",
	"skill_card",
	"skill_target",
	"cooldown_remaining",
	"cooldown_batches",
	"private",
	"future",
	"instant_sequence",
	"internal_order",
	"warehouse_stock",
	"logistics_plan",
	"ai_plan",
	"hidden",
	"rng_state",
	"owner_player_id",
	"player_id",
	"source_instance_id",
	"card_instance_id",
]

var _event_sequence := 0
var _events: Array[Dictionary] = []
var _rejected_event_count := 0
var _stripped_field_count := 0
var _hidden_input_field_count := 0


func record_event(
	event_type: String,
	source_payload: Dictionary,
	batch_id := "none"
) -> Dictionary:
	if event_type not in EVENT_TYPES:
		_rejected_event_count += 1
		return {}
	var allowed_fields := (
		EVENT_PAYLOAD_FIELDS.get(event_type, []) as Array
	)
	var payload := {}
	for key_variant in source_payload.keys():
		var key := str(key_variant)
		if key not in allowed_fields or key not in COMMON_PAYLOAD_FIELDS:
			_stripped_field_count += 1
			if _key_is_forbidden(key):
				_hidden_input_field_count += 1
			continue
		var value: Variant = source_payload.get(key_variant)
		if not _safe_scalar(value):
			_stripped_field_count += 1
			if _contains_hidden_value(value):
				_hidden_input_field_count += 1
			continue
		payload[key] = _sanitize_scalar(value)
	_event_sequence += 1
	var event := {
		"schema": "V075CombatTelemetryEventV1",
		"ruleset_id": RULESET_ID,
		"event_sequence": _event_sequence,
		"batch_id": _clean_text(batch_id, 80),
		"event_type": event_type,
		"payload": payload,
	}
	if event_hidden_info_report(event).get("hidden_field_count", 0) != 0:
		_event_sequence -= 1
		_rejected_event_count += 1
		return {}
	_events.append(event.duplicate(true))
	return event


func recent_events(limit := 40) -> Array[Dictionary]:
	var resolved_limit := clampi(limit, 0, _events.size())
	var start := maxi(0, _events.size() - resolved_limit)
	return _events.slice(start, _events.size()).duplicate(true)


func event_hidden_info_report(event: Dictionary) -> Dictionary:
	var hidden_field_count := _forbidden_field_count(event)
	return {
		"valid": hidden_field_count == 0,
		"hidden_field_count": hidden_field_count,
		"opponent_skill_definition_count": _count_exact_key(
			event,
			"skill_definition_id"
		),
		"opponent_skill_target_count": _count_exact_key(
			event,
			"skill_target"
		),
		"opponent_skill_cooldown_count": _count_exact_key(
			event,
			"cooldown_remaining_batches"
		),
		"internal_sequence_count": _count_exact_key(
			event,
			"monster_private_instant_sequence"
		),
	}


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V075CombatTelemetryContractDebugV1",
		"ruleset_id": RULESET_ID,
		"event_count": _events.size(),
		"event_sequence": _event_sequence,
		"rejected_event_count": _rejected_event_count,
		"stripped_field_count": _stripped_field_count,
		"hidden_input_field_count": _hidden_input_field_count,
		"stored_hidden_field_count": _stored_hidden_field_count(),
		"gameplay_owner_count": 0,
		"rng_owner_count": 0,
		"world_mutation_count": 0,
	}


func _stored_hidden_field_count() -> int:
	var count := 0
	for event in _events:
		count += int(
			event_hidden_info_report(event).get(
				"hidden_field_count",
				0
			)
		)
	return count


func _safe_scalar(value: Variant) -> bool:
	return (
		value is bool
		or value is int
		or value is float
		or value is String
		or value is StringName
	)


func _sanitize_scalar(value: Variant) -> Variant:
	if value is String or value is StringName:
		return _clean_text(str(value), 120)
	return value


func _clean_text(value: String, limit: int) -> String:
	var clean := ""
	for character in value:
		var code := character.unicode_at(0)
		if code >= 32 and code != 127:
			clean += character
	return clean.left(limit)


func _key_is_forbidden(key: String) -> bool:
	var normalized := key.to_lower()
	for fragment_variant in FORBIDDEN_FIELD_FRAGMENTS:
		if str(fragment_variant) in normalized:
			return true
	return false


func _forbidden_field_count(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if _key_is_forbidden(str(key_variant)):
				count += 1
			count += _forbidden_field_count(
				dictionary.get(key_variant)
			)
	elif value is Array:
		for child_variant in value as Array:
			count += _forbidden_field_count(child_variant)
	return count


func _contains_hidden_value(value: Variant) -> bool:
	if value is Dictionary or value is Array:
		return _forbidden_field_count(value) > 0
	return false


func _count_exact_key(value: Variant, expected_key: String) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if str(key_variant) == expected_key:
				count += 1
			count += _count_exact_key(
				dictionary.get(key_variant),
				expected_key
			)
	elif value is Array:
		for child_variant in value as Array:
			count += _count_exact_key(child_variant, expected_key)
	return count