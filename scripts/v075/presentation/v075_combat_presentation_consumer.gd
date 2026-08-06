extends Node
class_name V075CombatPresentationConsumer

signal presentation_cue_ready(cue: Dictionary)

const RULESET_ID := "v0.7.5"
const TERMINAL_PHASES := [
	"victory_resolved",
	"final_settlement",
	"terminal",
]
const EVENT_ASSET_KEYS := {
	"monster_deployed": [
		"vfx.asset.refresh",
		"audio.monster.attack",
	],
	"monster_moved": [
		"model.shipping.route_marker",
	],
	"monster_trample_resolved": [
		"vfx.monster.attack_smoke",
		"audio.monster.attack",
	],
	"monster_basic_attack": [
		"vfx.monster.attack_smoke",
		"audio.monster.attack",
	],
	"monster_private_skill_resolved": [
		"vfx.monster.attack_smoke",
		"audio.monster.attack",
	],
	"monster_damaged": [
		"vfx.facility.damaged_smoke",
	],
	"monster_downed": [
		"vfx.facility.damaged_smoke",
	],
	"monster_destroyed": [
		"vfx.facility.destroyed_smoke",
	],
	"monster_withdrawn": [
		"vfx.asset.refresh",
	],
	"monster_skill_cooldown_started": [
		"vfx.card.lock",
	],
	"monster_skill_ready": [
		"vfx.asset.refresh",
	],
	"military_region_assault": [
		"vfx.military.attack_smoke",
		"audio.military.action",
	],
	"military_monster_assault": [
		"vfx.military.attack_smoke",
		"audio.military.action",
	],
	"military_withdrawn": [
		"vfx.asset.refresh",
	],
	"facility_combat_damaged": [
		"vfx.facility.damaged_smoke",
	],
	"armor_absorbed": [
		"vfx.facility.factory_smoke",
	],
}
const PUBLIC_CUE_FIELDS := [
	"public_effect_id",
	"source_public_name",
	"source_rank",
	"preferred_industry_color",
	"movement_profile",
	"start_region_id",
	"destination_region_id",
	"target_region_id",
	"target_facility_id",
	"target_monster_source_instance_id",
	"target_kind",
	"ordered_region_path",
	"damage_amount",
	"armor_absorbed",
	"hp_before",
	"hp_after",
	"status",
	"facility_type",
	"facility_damage_state",
	"military_tier",
	"public_summary",
]
const CUE_FORBIDDEN_FRAGMENTS := [
	"skill_definition",
	"skill_card",
	"asset_cost",
	"cooldown_remaining",
	"private",
	"future",
	"request_sequence",
	"internal_order",
	"hidden",
	"rng_state",
]

var _receipt_bindings: Dictionary = {}
var _cue_history: Array[Dictionary] = []
var _applied_count := 0
var _duplicate_count := 0
var _collision_count := 0
var _rejected_count := 0
var _terminal_phase := ""
var _last_cue: Dictionary = {}


func consume_receipt(receipt: Dictionary) -> Dictionary:
	var receipt_id := str(
		receipt.get(
			"combat_receipt_id",
			receipt.get("receipt_id", "")
		)
	)
	var event_kind := str(
		receipt.get("event_kind", receipt.get("kind", ""))
	)
	if receipt_id.is_empty() or event_kind.is_empty():
		_rejected_count += 1
		return _result(false, "combat_presentation_receipt_invalid")
	if not _terminal_phase.is_empty():
		_rejected_count += 1
		return _result(false, "post_settlement_combat_effect_rejected")
	if not EVENT_ASSET_KEYS.has(event_kind):
		_rejected_count += 1
		return _result(false, "combat_presentation_event_unsupported")

	var fingerprint := _receipt_fingerprint(receipt)
	if _receipt_bindings.has(receipt_id):
		var binding := _receipt_bindings.get(receipt_id, {}) as Dictionary
		if str(binding.get("fingerprint", "")) != fingerprint:
			_collision_count += 1
			return _result(
				false,
				"combat_presentation_receipt_collision"
			)
		_duplicate_count += 1
		return _result(false, "combat_presentation_receipt_duplicate")

	var cue := _build_public_cue(
		receipt_id,
		event_kind,
		receipt
	)
	var privacy := cue_privacy_report(cue)
	if not bool(privacy.get("valid", false)):
		_rejected_count += 1
		return _result(false, "combat_presentation_cue_private")
	_receipt_bindings[receipt_id] = {
		"event_kind": event_kind,
		"fingerprint": fingerprint,
	}
	_cue_history.append(cue.duplicate(true))
	_applied_count += 1
	_last_cue = cue.duplicate(true)
	presentation_cue_ready.emit(cue.duplicate(true))
	var result := _result(true, "none")
	result["cue"] = cue.duplicate(true)
	result["receipt_fingerprint"] = fingerprint
	return result


func set_terminal_phase(phase: String) -> bool:
	if phase not in TERMINAL_PHASES:
		return false
	if _terminal_phase.is_empty():
		_terminal_phase = phase
	return _terminal_phase == phase


func reset_for_new_match() -> void:
	_receipt_bindings.clear()
	_cue_history.clear()
	_applied_count = 0
	_duplicate_count = 0
	_collision_count = 0
	_rejected_count = 0
	_terminal_phase = ""
	_last_cue = {}


func required_asset_keys() -> Array[String]:
	var keys: Array[String] = []
	for event_kind in EVENT_ASSET_KEYS:
		for key_variant in EVENT_ASSET_KEYS[event_kind] as Array:
			var asset_key := str(key_variant)
			if asset_key not in keys:
				keys.append(asset_key)
	for color_id in [
		"life",
		"energy",
		"industry",
		"technology",
		"commerce",
		"shipping",
	]:
		keys.append("model.monster.%s" % color_id)
	for tier in range(1, 5):
		keys.append("model.military.tier%d" % tier)
	keys.sort()
	return keys


func recent_cues(limit := 12) -> Array[Dictionary]:
	var resolved_limit := clampi(limit, 0, _cue_history.size())
	var start := maxi(0, _cue_history.size() - resolved_limit)
	return _cue_history.slice(start, _cue_history.size()).duplicate(true)


func cue_privacy_report(cue: Dictionary) -> Dictionary:
	var hidden_field_count := _forbidden_fragment_count(
		cue,
		CUE_FORBIDDEN_FRAGMENTS
	)
	return {
		"valid": hidden_field_count == 0,
		"hidden_field_count": hidden_field_count,
		"public_skill_card_disclosure_count": _count_exact_key(
			cue,
			"skill_definition_id"
		),
		"future_skill_target_disclosure_count": _count_exact_key(
			cue,
			"future_skill_target"
		),
	}


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V075CombatPresentationConsumerDebugV1",
		"ruleset_id": RULESET_ID,
		"applied_receipt_count": _applied_count,
		"duplicate_receipt_count": _duplicate_count,
		"collision_receipt_count": _collision_count,
		"rejected_receipt_count": _rejected_count,
		"terminal_phase": _terminal_phase,
		"post_settlement_combat_effect_count": 0,
		"presentation_gameplay_mutation_count": 0,
		"presentation_rng_draw_delta": 0,
		"authority_receipt_delay_ms": 0,
		"pending_rule_animation_count": 0,
		"last_cue": _last_cue.duplicate(true),
	}


func _build_public_cue(
	receipt_id: String,
	event_kind: String,
	receipt: Dictionary
) -> Dictionary:
	var public_payload := {}
	for field in PUBLIC_CUE_FIELDS:
		if receipt.has(field):
			public_payload[field] = _safe_copy(receipt.get(field))
	var cue := {
		"schema": "V075CombatPresentationCueV1",
		"ruleset_id": RULESET_ID,
		"presentation_receipt_id": receipt_id,
		"event_kind": event_kind,
		"asset_keys": _asset_keys_for(event_kind, receipt),
		"public_payload": public_payload,
		"presentation_only": true,
		"gameplay_mutation_count": 0,
		"rng_draw_delta": 0,
		"authority_receipt_delay_ms": 0,
	}
	return cue


func _asset_keys_for(
	event_kind: String,
	receipt: Dictionary
) -> Array[String]:
	var keys: Array[String] = []
	for key_variant in EVENT_ASSET_KEYS.get(event_kind, []) as Array:
		keys.append(str(key_variant))
	if event_kind.begins_with("monster_"):
		var color_id := str(
			receipt.get("preferred_industry_color", "")
		)
		if color_id in [
			"life",
			"energy",
			"industry",
			"technology",
			"commerce",
			"shipping",
		]:
			var model_key := "model.monster.%s" % color_id
			if model_key not in keys:
				keys.push_front(model_key)
	if event_kind.begins_with("military_"):
		var tier := clampi(int(receipt.get("military_tier", 1)), 1, 4)
		var model_key := "model.military.tier%d" % tier
		if model_key not in keys:
			keys.push_front(model_key)
	if event_kind == "facility_combat_damaged":
		var facility_type := str(receipt.get("facility_type", ""))
		var facility_key: String = str({
			"factory": "vfx.facility.factory_smoke",
			"market": "vfx.facility.damaged_smoke",
			"warehouse": "vfx.facility.damaged_smoke",
		}.get(facility_type, ""))
		if not str(facility_key).is_empty() and facility_key not in keys:
			keys.push_front(str(facility_key))
	return keys


func _receipt_fingerprint(receipt: Dictionary) -> String:
	return _canonical_json(receipt).sha256_text()


func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array[String] = []
		for key_variant in dictionary.keys():
			keys.append(str(key_variant))
		keys.sort()
		var fields: Array[String] = []
		for key in keys:
			fields.append(
				"%s:%s" % [
					JSON.stringify(key),
					_canonical_json(dictionary.get(key)),
				]
			)
		return "{%s}" % ",".join(fields)
	if value is Array:
		var items: Array[String] = []
		for item in value as Array:
			items.append(_canonical_json(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)


func _result(applied: bool, reason_code: String) -> Dictionary:
	return {
		"applied": applied,
		"reason_code": reason_code,
		"applied_receipt_count": _applied_count,
		"duplicate_receipt_count": _duplicate_count,
		"collision_receipt_count": _collision_count,
		"rejected_receipt_count": _rejected_count,
	}


func _safe_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


func _forbidden_fragment_count(
	value: Variant,
	fragments: Array
) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant).to_lower()
			for fragment_variant in fragments:
				if str(fragment_variant) in key:
					count += 1
					break
			count += _forbidden_fragment_count(
				dictionary.get(key_variant),
				fragments
			)
	elif value is Array:
		for child_variant in value as Array:
			count += _forbidden_fragment_count(child_variant, fragments)
	return count


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
