extends RefCounted
class_name V075CombatTelemetryBridge

signal telemetry_event_ready(event: Dictionary)

const TelemetryContract := preload(
	"res://scripts/v075/telemetry/v075_combat_telemetry_contract.gd"
)

const RULESET_ID := "v0.7.5"
const SOURCE_RECEIPT := "receipt"
const SOURCE_CUE := "cue"
const RECEIPT_ID_KEYS := [
	"combat_receipt_id",
	"receipt_id",
	"public_receipt_id",
]
const CUE_ID_KEYS := [
	"observer_correlation_id",
	"source_receipt_id",
	"presentation_receipt_id",
	"combat_receipt_id",
	"receipt_id",
]
const HIDDEN_FIELD_FRAGMENTS := [
	"skill_definition",
	"skill_card",
	"skill_target",
	"future_skill_target",
	"cooldown_remaining",
	"cooldown_batches",
	"private",
	"instant_sequence",
	"authority_receive_sequence",
	"request_sequence",
	"internal_order",
	"warehouse_stock",
	"private_stock",
	"logistics_plan",
	"ai_plan",
	"ai_private",
	"private_plan",
	"pressure_bucket",
	"hidden",
	"rng_state",
	"owner_player_id",
	"player_id",
	"source_instance_id",
	"card_instance_id",
]
const SKILL_DEFINITION_FRAGMENTS := [
	"skill_definition",
	"skill_card",
]
const SKILL_TARGET_FRAGMENTS := [
	"skill_target",
	"future_skill_target",
]
const SKILL_COOLDOWN_FRAGMENTS := [
	"cooldown_remaining",
	"cooldown_batches",
]
const INSTANT_SEQUENCE_FRAGMENTS := [
	"instant_sequence",
	"authority_receive_sequence",
	"request_sequence",
	"internal_order",
]
const WAREHOUSE_PRIVATE_FRAGMENTS := [
	"warehouse_stock",
	"private_stock",
	"logistics_plan",
]
const AI_PRIVATE_PLAN_FRAGMENTS := [
	"ai_plan",
	"ai_private",
	"private_plan",
	"pressure_bucket",
]

var _contract: RefCounted = TelemetryContract.new()
var _source_bindings: Dictionary = {}
var _receipt_input_count := 0
var _cue_input_count := 0
var _emitted_event_count := 0
var _duplicate_source_count := 0
var _collision_source_count := 0
var _rejected_input_count := 0
var _stripped_non_scalar_count := 0
var _hidden_input_field_count := 0
var _skill_definition_input_count := 0
var _skill_target_input_count := 0
var _skill_cooldown_input_count := 0
var _instant_sequence_input_count := 0
var _warehouse_private_input_count := 0
var _ai_private_plan_input_count := 0
var _last_reason_code := "none"
var _last_event: Dictionary = {}


func consume_public_receipt(
	receipt: Dictionary,
	batch_id := ""
) -> Dictionary:
	_receipt_input_count += 1
	return _consume_public_source(
		SOURCE_RECEIPT,
		receipt,
		batch_id
	)


func consume_public_cue(
	cue: Dictionary,
	batch_id := ""
) -> Dictionary:
	_cue_input_count += 1
	return _consume_public_source(
		SOURCE_CUE,
		cue,
		batch_id
	)


func recent_events(limit := 40) -> Array:
	return _contract.call("recent_events", limit) as Array


func reset_for_new_match() -> void:
	_contract = TelemetryContract.new()
	_source_bindings.clear()
	_receipt_input_count = 0
	_cue_input_count = 0
	_emitted_event_count = 0
	_duplicate_source_count = 0
	_collision_source_count = 0
	_rejected_input_count = 0
	_stripped_non_scalar_count = 0
	_hidden_input_field_count = 0
	_skill_definition_input_count = 0
	_skill_target_input_count = 0
	_skill_cooldown_input_count = 0
	_instant_sequence_input_count = 0
	_warehouse_private_input_count = 0
	_ai_private_plan_input_count = 0
	_last_reason_code = "none"
	_last_event = {}


func debug_snapshot() -> Dictionary:
	var contract_debug := _contract.call("debug_snapshot") as Dictionary
	return {
		"schema": "V075CombatTelemetryBridgeDebugV1",
		"ruleset_id": RULESET_ID,
		"receipt_input_count": _receipt_input_count,
		"cue_input_count": _cue_input_count,
		"emitted_event_count": _emitted_event_count,
		"duplicate_source_count": _duplicate_source_count,
		"collision_source_count": _collision_source_count,
		"rejected_input_count": _rejected_input_count,
		"source_binding_count": _source_bindings.size(),
		"stripped_non_scalar_count": _stripped_non_scalar_count,
		"hidden_input_field_count": _hidden_input_field_count,
		"opponent_skill_definition_input_count": (
			_skill_definition_input_count
		),
		"opponent_skill_target_input_count": _skill_target_input_count,
		"opponent_skill_cooldown_input_count": (
			_skill_cooldown_input_count
		),
		"instant_sequence_input_count": _instant_sequence_input_count,
		"warehouse_private_stock_input_count": (
			_warehouse_private_input_count
		),
		"ai_private_plan_input_count": _ai_private_plan_input_count,
		"stored_hidden_field_count": int(
			contract_debug.get("stored_hidden_field_count", 0)
		),
		"gameplay_owner_count": 0,
		"rng_owner_count": 0,
		"world_mutation_count": 0,
		"last_reason_code": _last_reason_code,
		"last_event": _last_event.duplicate(true),
		"contract": contract_debug,
	}


func _consume_public_source(
	source_kind: String,
	source: Dictionary,
	explicit_batch_id: String
) -> Dictionary:
	_accumulate_hidden_input(source)
	var source_ruleset := str(source.get("ruleset_id", ""))
	if (
		not source_ruleset.is_empty()
		and source_ruleset != RULESET_ID
	):
		return _reject("combat_telemetry_ruleset_mismatch")

	var source_id := _source_id(source_kind, source)
	if source_id.is_empty():
		return _reject("combat_telemetry_source_id_missing")
	var event_type := _event_type(source)
	if event_type not in TelemetryContract.EVENT_TYPES:
		return _reject("combat_telemetry_event_unsupported")

	if _source_bindings.has(source_id):
		var binding := _source_bindings.get(source_id, {}) as Dictionary
		if str(binding.get("event_type", "")) != event_type:
			_collision_source_count += 1
			return _reject("combat_telemetry_source_collision")
		_duplicate_source_count += 1
		_last_reason_code = "combat_telemetry_source_duplicate"
		return {}

	var public_payload := _public_payload(source, event_type)
	var resolved_batch_id := _resolved_batch_id(
		source,
		explicit_batch_id
	)
	var event := _contract.call(
		"record_event",
		event_type,
		public_payload,
		resolved_batch_id
	) as Dictionary
	if event.is_empty():
		return _reject("combat_telemetry_contract_rejected")

	_source_bindings[source_id] = {
		"event_type": event_type,
		"source_kind": source_kind,
	}
	_emitted_event_count += 1
	_last_reason_code = "none"
	_last_event = event.duplicate(true)
	telemetry_event_ready.emit(event.duplicate(true))
	return event


func _source_id(source_kind: String, source: Dictionary) -> String:
	var keys := (
		CUE_ID_KEYS if source_kind == SOURCE_CUE else RECEIPT_ID_KEYS
	)
	for key_variant in keys:
		var value := str(source.get(str(key_variant), ""))
		if not value.is_empty():
			return value.left(160)
	return ""


func _event_type(source: Dictionary) -> String:
	return str(source.get(
		"event_kind",
		source.get("event_type", source.get("kind", ""))
	))


func _resolved_batch_id(
	source: Dictionary,
	explicit_batch_id: String
) -> String:
	if not explicit_batch_id.is_empty():
		return explicit_batch_id
	var source_batch_id := str(source.get("batch_id", ""))
	if not source_batch_id.is_empty():
		return source_batch_id
	var public_variant: Variant = source.get("public_payload", {})
	if public_variant is Dictionary:
		var public_batch_id := str(
			(public_variant as Dictionary).get("batch_id", "")
		)
		if not public_batch_id.is_empty():
			return public_batch_id
	return "none"


func _public_payload(
	source: Dictionary,
	event_type: String
) -> Dictionary:
	var nested: Dictionary = {}
	var nested_variant: Variant = source.get("public_payload", {})
	if nested_variant is Dictionary:
		nested = nested_variant as Dictionary
	var payload := {}
	var allowed_fields := (
		TelemetryContract.EVENT_PAYLOAD_FIELDS.get(
			event_type,
			[]
		) as Array
	)
	for field_variant in allowed_fields:
		var field := str(field_variant)
		var found := false
		var value: Variant = null
		if nested.has(field):
			value = nested.get(field)
			found = true
		elif source.has(field):
			value = source.get(field)
			found = true
		if not found:
			continue
		if not _safe_scalar(value):
			_stripped_non_scalar_count += 1
			continue
		payload[field] = value
	return payload


func _safe_scalar(value: Variant) -> bool:
	return (
		value is bool
		or value is int
		or value is float
		or value is String
		or value is StringName
	)


func _accumulate_hidden_input(source: Dictionary) -> void:
	var report := {
		"total": 0,
		"skill_definition": 0,
		"skill_target": 0,
		"skill_cooldown": 0,
		"instant_sequence": 0,
		"warehouse_private": 0,
		"ai_private_plan": 0,
	}
	_scan_hidden_fields(source, report)
	_hidden_input_field_count += int(report.get("total", 0))
	_skill_definition_input_count += int(
		report.get("skill_definition", 0)
	)
	_skill_target_input_count += int(report.get("skill_target", 0))
	_skill_cooldown_input_count += int(
		report.get("skill_cooldown", 0)
	)
	_instant_sequence_input_count += int(
		report.get("instant_sequence", 0)
	)
	_warehouse_private_input_count += int(
		report.get("warehouse_private", 0)
	)
	_ai_private_plan_input_count += int(
		report.get("ai_private_plan", 0)
	)


func _scan_hidden_fields(value: Variant, report: Dictionary) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant).to_lower()
			if _key_matches(key, HIDDEN_FIELD_FRAGMENTS):
				report["total"] = int(report.get("total", 0)) + 1
			if _key_matches(key, SKILL_DEFINITION_FRAGMENTS):
				report["skill_definition"] = int(
					report.get("skill_definition", 0)
				) + 1
			if _key_matches(key, SKILL_TARGET_FRAGMENTS):
				report["skill_target"] = int(
					report.get("skill_target", 0)
				) + 1
			if _key_matches(key, SKILL_COOLDOWN_FRAGMENTS):
				report["skill_cooldown"] = int(
					report.get("skill_cooldown", 0)
				) + 1
			if _key_matches(key, INSTANT_SEQUENCE_FRAGMENTS):
				report["instant_sequence"] = int(
					report.get("instant_sequence", 0)
				) + 1
			if _key_matches(key, WAREHOUSE_PRIVATE_FRAGMENTS):
				report["warehouse_private"] = int(
					report.get("warehouse_private", 0)
				) + 1
			if _key_matches(key, AI_PRIVATE_PLAN_FRAGMENTS):
				report["ai_private_plan"] = int(
					report.get("ai_private_plan", 0)
				) + 1
			_scan_hidden_fields(dictionary.get(key_variant), report)
	elif value is Array:
		for child_variant in value as Array:
			_scan_hidden_fields(child_variant, report)


func _key_matches(key: String, fragments: Array) -> bool:
	for fragment_variant in fragments:
		if str(fragment_variant) in key:
			return true
	return false


func _reject(reason_code: String) -> Dictionary:
	_rejected_input_count += 1
	_last_reason_code = reason_code
	return {}
