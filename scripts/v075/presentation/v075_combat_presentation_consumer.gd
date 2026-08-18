extends Node
class_name V075CombatPresentationConsumer

signal presentation_cue_ready(cue: Dictionary)

const PresentationReceiptIdentity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)

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
	"monster_refreshed": [
		"vfx.asset.refresh",
	],
	"monster_upgraded": [
		"vfx.asset.refresh",
		"audio.monster.attack",
	],
	"monster_replaced": [
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
	var validation := PresentationReceiptIdentity.validate(receipt)
	if not bool(validation.get("valid", false)):
		_rejected_count += 1
		var invalid := _result(false, "combat_presentation_receipt_invalid")
		invalid["validation_reason_code"] = str(
			validation.get("reason_code", "presentation_receipt_v2_invalid")
		)
		return invalid
	var receipt_id := str(receipt.get("presentation_receipt_id", ""))
	var event_kind := str(receipt.get("presentation_kind", ""))
	if str(receipt.get("audience_scope", "")) != (
		PresentationReceiptIdentity.PUBLIC_AUDIENCE_SCOPE
	):
		_rejected_count += 1
		return _result(false, "combat_presentation_audience_unauthorized")
	if not _terminal_phase.is_empty():
		_rejected_count += 1
		return _result(false, "post_settlement_combat_effect_rejected")
	if not EVENT_ASSET_KEYS.has(event_kind):
		_rejected_count += 1
		return _result(false, "combat_presentation_event_unsupported")

	var fingerprint := str(
		receipt.get("canonical_payload_fingerprint", "")
	)
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

	var cue := _build_public_cue(receipt)
	var privacy := cue_privacy_report(cue)
	if not bool(privacy.get("valid", false)):
		_rejected_count += 1
		return _result(false, "combat_presentation_cue_private")
	_receipt_bindings[receipt_id] = {
		"event_kind": event_kind,
		"fingerprint": fingerprint,
		"source_receipt_id": str(receipt.get("source_receipt_id", "")),
		"source_authority_sequence": int(
			receipt.get("source_authority_sequence", -1)
		),
		"presentation_ordinal": int(receipt.get("presentation_ordinal", -1)),
		"audience_scope": str(receipt.get("audience_scope", "")),
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


func _build_public_cue(receipt: Dictionary) -> Dictionary:
	var receipt_id := str(receipt.get("presentation_receipt_id", ""))
	var event_kind := str(receipt.get("presentation_kind", ""))
	var public_payload := (
		receipt.get("canonical_payload", {}) as Dictionary
	).duplicate(true)
	var cue := {
		"schema": "V075CombatPresentationCueV1",
		"ruleset_id": RULESET_ID,
		"presentation_receipt_id": receipt_id,
		"source_receipt_id": str(receipt.get("source_receipt_id", "")),
		"source_receipt_fingerprint": str(
			receipt.get("source_receipt_fingerprint", "")
		),
		"observer_correlation_id": str(
			receipt.get("observer_correlation_id", "")
		),
		"observer_correlation_fingerprint": str(
			receipt.get("observer_correlation_fingerprint", "")
		),
		"source_authority_sequence": int(
			receipt.get("source_authority_sequence", -1)
		),
		"presentation_ordinal": int(receipt.get("presentation_ordinal", -1)),
		"audience_scope": str(receipt.get("audience_scope", "")),
		"audience_key_fingerprint": str(
			receipt.get("audience_key_fingerprint", "")
		),
		"canonical_payload_fingerprint": str(
			receipt.get("canonical_payload_fingerprint", "")
		),
		"event_kind": event_kind,
		"asset_keys": _asset_keys_for(event_kind, public_payload),
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


func _result(applied: bool, reason_code: String) -> Dictionary:
	return {
		"applied": applied,
		"reason_code": reason_code,
		"applied_receipt_count": _applied_count,
		"duplicate_receipt_count": _duplicate_count,
		"collision_receipt_count": _collision_count,
		"rejected_receipt_count": _rejected_count,
	}


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
