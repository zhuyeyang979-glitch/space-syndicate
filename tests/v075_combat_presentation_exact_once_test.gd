extends SceneTree

const Consumer := preload(
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var consumer := Consumer.new()
	root.add_child(consumer)
	var receipt := {
		"combat_receipt_id": "receipt.monster.skill.001",
		"event_kind": "monster_private_skill_resolved",
		"public_effect_id": "effect.region.cataclysm",
		"source_public_name": "棱镜技术巨兽",
		"source_rank": 4,
		"preferred_industry_color": "technology",
		"target_kind": "region",
		"target_region_id": "region.14",
		"damage_amount": 8,
		"skill_definition_id": "hidden.skill.definition",
		"asset_cost_by_color": {"technology": 3},
		"cooldown_remaining_batches": 3,
		"future_skill_target": "hidden.future.target",
	}
	var first := consumer.consume_receipt(receipt)
	var duplicate := consumer.consume_receipt(receipt.duplicate(true))
	var reordered_receipt := {}
	var reversed_keys := receipt.keys()
	reversed_keys.reverse()
	for key_variant in reversed_keys:
		reordered_receipt[key_variant] = _deep_reverse_dictionaries(
			receipt.get(key_variant)
		)
	var reordered_duplicate := consumer.consume_receipt(reordered_receipt)
	var collision_receipt := receipt.duplicate(true)
	collision_receipt["damage_amount"] = 9
	var collision := consumer.consume_receipt(collision_receipt)
	_expect(bool(first.get("applied", false)), "first combat receipt is applied")
	_expect(
		str(duplicate.get("reason_code", "")) ==
			"combat_presentation_receipt_duplicate",
		"same receipt is consumed exactly once"
	)
	_expect(
		str(reordered_duplicate.get("reason_code", "")) ==
			"combat_presentation_receipt_duplicate",
		"receipt identity ignores dictionary insertion order"
	)
	_expect(
		str(collision.get("reason_code", "")) ==
			"combat_presentation_receipt_collision",
		"receipt identity collision is rejected"
	)
	var cue := first.get("cue", {}) as Dictionary
	var public_payload := cue.get("public_payload", {}) as Dictionary
	_expect(
		not _contains_key(cue, "skill_definition_id")
		and not _contains_key(cue, "asset_cost_by_color")
		and not _contains_key(cue, "cooldown_remaining_batches")
		and not _contains_key(cue, "future_skill_target"),
		"presentation cue strips all private skill fields"
	)
	_expect(
		str(public_payload.get("public_effect_id", "")) ==
			"effect.region.cataclysm",
		"public effect survives projection"
	)
	var asset_keys := cue.get("asset_keys", []) as Array
	_expect(
		"model.monster.technology" in asset_keys
		and "vfx.monster.attack_smoke" in asset_keys
		and "audio.monster.attack" in asset_keys,
		"cue uses existing stable commercial asset keys"
	)
	var debug := consumer.debug_snapshot()
	_expect(
		int(debug.get("applied_receipt_count", 0)) == 1
		and int(debug.get("duplicate_receipt_count", 0)) == 2
		and int(debug.get("collision_receipt_count", 0)) == 1,
		"presentation exact-once counters are stable"
	)
	_expect(
		int(debug.get("presentation_gameplay_mutation_count", -1)) == 0
		and int(debug.get("presentation_rng_draw_delta", -1)) == 0
		and int(debug.get("authority_receipt_delay_ms", -1)) == 0,
		"presentation never mutates gameplay or delays authority"
	)
	consumer.set_terminal_phase("final_settlement")
	var after_terminal := consumer.consume_receipt({
		"combat_receipt_id": "receipt.post.settlement",
		"event_kind": "monster_moved",
		"start_region_id": "region.01",
		"destination_region_id": "region.02",
	})
	_expect(
		not bool(after_terminal.get("applied", true))
		and str(after_terminal.get("reason_code", "")) ==
			"post_settlement_combat_effect_rejected",
		"post-settlement combat presentation is quiescent"
	)
	consumer.queue_free()
	_finish()


func _deep_reverse_dictionaries(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var result := {}
		var keys := source.keys()
		keys.reverse()
		for key_variant in keys:
			result[key_variant] = _deep_reverse_dictionaries(
				source.get(key_variant)
			)
		return result
	if value is Array:
		var result := []
		for item in value as Array:
			result.append(_deep_reverse_dictionaries(item))
		return result
	return value


func _contains_key(value: Variant, expected: String) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if str(key_variant) == expected:
				return true
			if _contains_key(dictionary.get(key_variant), expected):
				return true
	elif value is Array:
		for child_variant in value as Array:
			if _contains_key(child_variant, expected):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_COMBAT_PRESENTATION_EXACT_ONCE_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
