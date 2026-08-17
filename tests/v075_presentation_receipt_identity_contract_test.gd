extends SceneTree

const Identity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)
const Consumer := preload(
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var raw := {
		"damage_amount": 7,
		"target_region_id": "region.014",
		"source_instance_id": "monster.source.001",
		"wall_clock": "forbidden-ephemeral-input",
		"skill_definition_id": "private-and-not-projected",
	}
	var source_id := "source.receipt.identity.contract.001"
	var source_fingerprint := Identity.source_fingerprint(source_id, raw)
	var first := Identity.build_public(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		0,
		"v0.7.5",
		"session.identity.contract",
		raw
	)
	var replay := Identity.build_public(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		0,
		"v0.7.5",
		"session.identity.contract",
		_deep_reverse_dictionaries(raw) as Dictionary
	)
	_expect(
		bool(Identity.validate(first).get("valid", false)),
		"identity_contract_validates_every_required_field"
	)
	_expect(
		str(first.get("presentation_receipt_id", ""))
			== str(replay.get("presentation_receipt_id", ""))
			and str(first.get("canonical_payload_fingerprint", ""))
				== str(replay.get("canonical_payload_fingerprint", "")),
		"deterministic_replay_ignores_dictionary_insertion_order"
	)
	var public_payload := first.get("canonical_payload", {}) as Dictionary
	_expect(
		int(public_payload.get("damage_amount", -1)) == 7
			and not public_payload.has("wall_clock")
			and not public_payload.has("skill_definition_id"),
		"canonical_payload_includes_semantics_and_excludes_ephemeral_private_fields"
	)
	raw["damage_amount"] = 99
	_expect(
		int((first.get("canonical_payload", {}) as Dictionary).get(
			"damage_amount",
			-1
		)) == 7,
		"receipt_is_immutable_after_fingerprint_relative_to_source_alias"
	)
	var second_ordinal := Identity.build_public(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		1,
		"v0.7.5",
		"session.identity.contract",
		{"damage_amount": 7}
	)
	var second_kind := Identity.build_public(
		source_id,
		source_fingerprint,
		7,
		"monster_skill_cooldown_started",
		0,
		"v0.7.5",
		"session.identity.contract",
		{"status": "cooldown"}
	)
	_expect(
		str(second_ordinal.get("presentation_receipt_id", ""))
			!= str(first.get("presentation_receipt_id", ""))
			and str(second_kind.get("presentation_receipt_id", ""))
				!= str(first.get("presentation_receipt_id", "")),
		"multiple_events_per_source_use_kind_and_ordinal_identity"
	)
	var private_receipt := Identity.build_for_audience(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		0,
		"PLAYER_PRIVATE",
		"player.secret.identity",
		"v0.7.5",
		"session.identity.contract",
		{"damage_amount": 7}
	)
	_expect(
		bool(Identity.validate(private_receipt).get("valid", false))
			and str(private_receipt.get("presentation_receipt_id", ""))
				!= str(first.get("presentation_receipt_id", ""))
			and str(private_receipt.get("audience_scope", ""))
				== "PLAYER_PRIVATE"
			and str(private_receipt.get("audience_key_fingerprint", "")).length()
				== 64
			and not JSON.stringify(private_receipt).contains(
				"player.secret.identity"
			),
		"public_private_audience_identity_is_global_and_privacy_safe"
	)
	var private_other_session := Identity.build_for_audience(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		0,
		"PLAYER_PRIVATE",
		"player.secret.identity",
		"v0.7.5",
		"session.identity.contract.other",
		{"damage_amount": 7}
	)
	var private_other_player := Identity.build_for_audience(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		0,
		"PLAYER_PRIVATE",
		"player.secret.other",
		"v0.7.5",
		"session.identity.contract",
		{"damage_amount": 7}
	)
	var local_receipt := Identity.build_for_audience(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		0,
		"LOCAL_PRESENTATION_ONLY",
		"local.surface.fixture",
		"v0.7.5",
		"session.identity.contract",
		{"damage_amount": 7}
	)
	_expect(
		str(private_other_session.get("audience_key_fingerprint", ""))
			!= str(private_receipt.get("audience_key_fingerprint", ""))
			and str(private_other_player.get("presentation_receipt_id", ""))
				!= str(private_receipt.get("presentation_receipt_id", "")),
		"private_audience_keys_are_session_scoped_and_player_distinct"
	)
	var public_consumer := Consumer.new()
	root.add_child(public_consumer)
	var private_rejected := public_consumer.consume_receipt(private_receipt)
	var local_rejected := public_consumer.consume_receipt(local_receipt)
	_expect(
		str(private_rejected.get("reason_code", ""))
			== "combat_presentation_audience_unauthorized"
			and str(local_rejected.get("reason_code", ""))
				== "combat_presentation_audience_unauthorized"
			and int(public_consumer.debug_snapshot().get(
				"applied_receipt_count",
				-1
			)) == 0,
		"shared_public_consumer_fails_closed_private_and_local_scopes"
	)
	public_consumer.queue_free()
	var changed_session := Identity.build_public(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		0,
		"v0.7.5",
		"session.identity.contract.changed",
		{"damage_amount": 7}
	)
	_expect(
		str(changed_session.get("presentation_receipt_id", ""))
			!= str(first.get("presentation_receipt_id", "")),
		"session_identity_prevents_cross_match_collisions"
	)
	var observer_a := Identity.build_public(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		0,
		"v0.7.5",
		"session.identity.contract",
		{"damage_amount": 7},
		"observer.correlation.a"
	)
	var observer_b := Identity.build_public(
		source_id,
		source_fingerprint,
		7,
		"monster_private_skill_resolved",
		0,
		"v0.7.5",
		"session.identity.contract",
		{"damage_amount": 7},
		"observer.correlation.b"
	)
	_expect(
		str(observer_a.get("presentation_receipt_id", ""))
			== str(observer_b.get("presentation_receipt_id", ""))
			and str(observer_a.get("canonical_payload_fingerprint", ""))
				== str(observer_b.get("canonical_payload_fingerprint", ""))
			and str(observer_a.get("observer_correlation_fingerprint", ""))
				!= str(observer_b.get("observer_correlation_fingerprint", "")),
		"observer_correlation_is_sealed_but_not_presentation_identity"
	)
	var observer_forged := observer_a.duplicate(true)
	observer_forged["observer_correlation_id"] = "observer.correlation.forged"
	_expect(
		not bool(Identity.validate(observer_forged).get("valid", true)),
		"observer_correlation_mutation_fails_closed"
	)
	var forged := first.duplicate(true)
	(forged.get("canonical_payload", {}) as Dictionary)["damage_amount"] = 8
	_expect(
		not bool(Identity.validate(forged).get("valid", true)),
		"fingerprint_validation_fails_closed_on_payload_mutation"
	)
	var malformed_source_hash := first.duplicate(true)
	malformed_source_hash["source_receipt_fingerprint"] = "z".repeat(64)
	var extra_field := first.duplicate(true)
	extra_field["undeclared_transport_field"] = true
	_expect(
		Identity.build_public(
			source_id,
			"z".repeat(64),
			7,
			"monster_private_skill_resolved",
			0,
			"v0.7.5",
			"session.identity.contract",
			{"damage_amount": 7}
		).is_empty()
			and not bool(Identity.validate(malformed_source_hash).get(
				"valid",
				true
			))
			and not bool(Identity.validate(extra_field).get("valid", true)),
		"source_hash_and_exact_top_level_schema_fail_closed"
	)
	_expect(
		Identity.build_public(
			source_id,
			source_fingerprint,
			7,
			"monster_private_skill_resolved",
			0,
			"v0.7.5",
			"session.identity.contract",
			{"damage_amount": "7"}
		).is_empty(),
		"canonical_public_field_types_fail_closed"
	)
	var roundtrip_variant: Variant = JSON.parse_string(JSON.stringify(first))
	var roundtrip := Identity.normalize_serialized_receipt(
		roundtrip_variant as Dictionary
	) if roundtrip_variant is Dictionary else {}
	_expect(
		roundtrip_variant is Dictionary
			and bool(Identity.validate(roundtrip).get(
				"valid",
				false
			))
			and int(roundtrip.get(
				"source_authority_sequence",
				-1
			)) == 7
			and int(roundtrip.get(
				"presentation_ordinal",
				-1
			)) == 0,
		"json_roundtrip_preserves_integer_identity_and_fingerprint_parity"
	)
	_expect(
		str(first.get("presentation_receipt_id", "")).begins_with(
			"presentation.v2."
		)
			and str(first.get("presentation_receipt_id", "")).length() == 80
			and int(first.get("source_authority_sequence", -1)) == 7
			and int(first.get("presentation_ordinal", -1)) == 0,
		"identity_has_fixed_domain_sequence_and_ordinal_contract"
	)
	_finish()


func _deep_reverse_dictionaries(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var result := {}
		var keys := source.keys()
		keys.reverse()
		for key in keys:
			result[key] = _deep_reverse_dictionaries(source.get(key))
		return result
	if value is Array:
		var result := []
		for item in value as Array:
			result.append(_deep_reverse_dictionaries(item))
		return result
	return value


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_PRESENTATION_RECEIPT_IDENTITY_CONTRACT_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
