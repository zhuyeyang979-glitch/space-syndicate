extends SceneTree

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const IDENTITY := preload("res://scripts/semantic/semantic_identity.gd")
const CONDITION := preload("res://scripts/semantic/semantic_condition.gd")
const TARGET := preload("res://scripts/semantic/semantic_target_spec.gd")
const OPERATION := preload("res://scripts/semantic/semantic_operation.gd")
const VISIBILITY := preload("res://scripts/semantic/semantic_visibility_policy.gd")
const RANDOMNESS := preload("res://scripts/semantic/semantic_randomness_policy.gd")
const VALIDATION_REPORT := preload("res://scripts/semantic/semantic_validation_report.gd")
const RULE_PLAN := preload("res://scripts/semantic/rule_execution_plan.gd")
const PLAYER_DTO := preload("res://scripts/semantic/player_presentation_dto.gd")
const AI_OBSERVATION := preload("res://scripts/semantic/ai_observation_snapshot.gd")
const AI_CANDIDATE := preload("res://scripts/semantic/ai_action_candidate.gd")
const AI_OUTCOME := preload("res://scripts/semantic/ai_outcome_vector.gd")
const HANDLER_DESCRIPTOR := preload("res://scripts/semantic/operation_handler_descriptor.gd")
const HANDLER_REGISTRY := preload("res://scripts/semantic/operation_handler_registry.gd")

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	_test_wire_profile_and_identity()
	var contracts := _test_condition_target_and_policies()
	_test_operation_and_rule_plan(contracts)
	_test_validation_report()
	_test_player_presentation()
	_test_ai_projection_values()
	_test_registry()
	_test_rng_is_not_consumed()
	_finish()


func _test_wire_profile_and_identity() -> void:
	_expect(WIRE.is_stable_id("card.install_rate-v1"), "stable ASCII ID accepted")
	for rejected_id in ["Card.install", "1card", "card..install", "card._install", "卡牌.install"]:
		_expect(not WIRE.is_stable_id(rejected_id), "invalid stable ID rejected: %s" % rejected_id)
	_expect(WIRE.is_closed_data({"a": [1, true, "id"]}), "closed data accepted")
	_expect(not WIRE.is_closed_data(null), "null rejected")
	_expect(not WIRE.is_closed_data(1.25), "float rejected")
	var runtime_node := Node.new()
	_expect(not WIRE.is_closed_data({"node": runtime_node}), "Node rejected")
	_expect(not WIRE.is_closed_data({"object": RefCounted.new()}), "Object rejected")
	_expect(not WIRE.is_closed_data({"scene": PackedScene.new()}), "PackedScene rejected")
	_expect(not WIRE.is_closed_data({"callback": Callable(self, "_run")}), "Callable rejected")
	runtime_node.free()

	var source := _identity_input()
	var identity := IDENTITY.build(source)
	_expect(not identity.is_empty(), "SemanticIdentity builds")
	_expect(bool(IDENTITY.validate(identity).get("valid", false)), "SemanticIdentity validates")
	source["definition_id"] = "card.mutated"
	_expect(str(identity.get("definition_id", "")) == "card.example", "identity is detached from input")
	var bad_version := identity.duplicate(true)
	bad_version["schema_version"] = 2
	_expect(
		str(IDENTITY.validate(bad_version).get("reason_id", ""))
			== "semantic_identity.schema_version_invalid",
		"schema version fails closed"
	)
	var bad_domain := _identity_input()
	bad_domain["domain_id"] = "unknown_domain"
	_expect(IDENTITY.build(bad_domain).is_empty(), "unknown domain fails closed")
	var extra_field := _identity_input()
	extra_field["name"] = "localized"
	_expect(IDENTITY.build(extra_field).is_empty(), "closed identity rejects localized alias")


func _test_condition_target_and_policies() -> Dictionary:
	var parameter_schemas := _parameter_schemas()
	var condition := {
		"schema_version": 1,
		"condition_binding_id": "condition.target_hand",
		"condition_id": "condition.target_has_hand",
		"condition_version": 1,
		"subject_binding_id": "target.player",
		"parameter_schema_id": "params.minimum_count.v1",
		"parameters": {"minimum_count": 1},
	}
	_expect(
		not CONDITION.build(condition, ["condition.target_has_hand"], parameter_schemas).is_empty(),
		"known SemanticCondition builds"
	)
	_expect(
		CONDITION.build(condition, ["condition.other"], parameter_schemas).is_empty(),
		"unknown condition fails closed"
	)
	var unknown_parameter_schema := condition.duplicate(true)
	unknown_parameter_schema["parameter_schema_id"] = "params.unknown.v1"
	_expect(
		CONDITION.build(unknown_parameter_schema, ["condition.target_has_hand"], parameter_schemas).is_empty(),
		"unknown condition parameter schema fails closed"
	)

	var target := {
		"schema_version": 1,
		"target_binding_id": "target.player",
		"target_id": "target.player_opponent",
		"target_version": 1,
		"selection_mode_id": "actor_choice",
		"minimum_count": 1,
		"maximum_count": 1,
		"allowed_entity_type_ids": ["player"],
		"filter_condition_binding_ids": ["condition.target_hand"],
		"revalidation_policy_id": "revalidate.before_apply",
		"target_visibility_policy_id": "visibility.actor_choice",
	}
	_expect(
		not TARGET.build(target, ["target.player_opponent"]).is_empty(),
		"known SemanticTargetSpec builds"
	)
	_expect(
		TARGET.build(target, ["target.district"]).is_empty(),
		"unknown target fails closed"
	)

	var visibility := _visibility_policy()
	_expect(
		not VISIBILITY.build(visibility, ["visibility.public_result"]).is_empty(),
		"registered visibility policy builds"
	)
	_expect(
		VISIBILITY.build(visibility, ["visibility.other"]).is_empty(),
		"unknown visibility policy fails closed"
	)
	var none_policy := _none_randomness_policy()
	var random_policy := _randomness_policy()
	_expect(
		not RANDOMNESS.build(none_policy, ["randomness.none.v1"], ["none"]).is_empty(),
		"explicit none randomness policy builds"
	)
	_expect(
		not RANDOMNESS.build(
			random_policy, ["randomness.card_discard.v1"], ["authoritative_rng"]
		).is_empty(),
		"registered random policy builds"
	)
	var incomplete_random := random_policy.duplicate(true)
	incomplete_random["stream_id"] = "none"
	_expect(
		RANDOMNESS.build(
			incomplete_random, ["randomness.card_discard.v1"], ["authoritative_rng"]
		).is_empty(),
		"random policy requires complete declared RNG evidence"
	)
	return {
		"parameter_schemas": parameter_schemas,
		"operation_contracts": _operation_contracts(),
		"randomness_policies": {
			"randomness.none.v1": none_policy,
			"randomness.card_discard.v1": random_policy,
		},
		"visibility_policies": {"visibility.public_result": visibility},
	}


func _test_operation_and_rule_plan(contracts: Dictionary) -> void:
	var operation := _random_operation()
	var built := OPERATION.build(
		operation,
		contracts.get("operation_contracts", {}),
		contracts.get("parameter_schemas", {}),
		contracts.get("randomness_policies", {}),
		contracts.get("visibility_policies", {})
	)
	_expect(not built.is_empty(), "known SemanticOperation builds")
	operation["parameters"]["count"] = 99
	_expect(int((built.get("parameters", {}) as Dictionary).get("count", 0)) == 1, "operation is deeply detached")
	var unknown_op := _random_operation()
	unknown_op["operation_id"] = "operation.unknown"
	_expect(
		OPERATION.build(
			unknown_op,
			contracts.get("operation_contracts", {}),
			contracts.get("parameter_schemas", {}),
			contracts.get("randomness_policies", {}),
			contracts.get("visibility_policies", {})
		).is_empty(),
		"unknown operation fails closed"
	)
	var wrong_randomness := _random_operation()
	wrong_randomness["randomness_policy_id"] = "randomness.none.v1"
	_expect(
		OPERATION.build(
			wrong_randomness,
			contracts.get("operation_contracts", {}),
			contracts.get("parameter_schemas", {}),
			contracts.get("randomness_policies", {}),
			contracts.get("visibility_policies", {})
		).is_empty(),
		"random operation rejects explicit-none policy"
	)

	var plan_input := _rule_plan_input()
	var plan := RULE_PLAN.build(
		plan_input,
		contracts.get("operation_contracts", {}),
		contracts.get("parameter_schemas", {}),
		contracts.get("randomness_policies", {}),
		contracts.get("visibility_policies", {})
	)
	_expect(not plan.is_empty(), "RuleExecutionPlan builds from authorized pure refs")
	plan_input["steps"][0]["parameters"]["count"] = 7
	_expect(
		int((plan.get("steps") as Array)[0]["parameters"]["count"]) == 1,
		"RuleExecutionPlan is deeply detached"
	)
	var unknown_step := _rule_plan_input()
	unknown_step["steps"][0]["operation_id"] = "operation.unknown"
	_expect(
		RULE_PLAN.build(
			unknown_step,
			contracts.get("operation_contracts", {}),
			contracts.get("parameter_schemas", {}),
			contracts.get("randomness_policies", {}),
			contracts.get("visibility_policies", {})
		).is_empty(),
		"RuleExecutionPlan cannot carry an unknown operation"
	)


func _test_validation_report() -> void:
	var input := {
		"schema_version": 1,
		"report_id": "semantic.kernel.test",
		"phase_id": "source_validation",
		"valid": true,
		"source_manifest_fingerprint": WIRE.fingerprint(["source"]),
		"issues": [],
		"domain_summaries": [],
		"unknown_condition_ids": [],
		"unknown_target_ids": [],
		"unknown_operation_ids": [],
		"unknown_randomness_policy_ids": [],
		"unknown_visibility_policy_ids": [],
		"unknown_mechanic_ids": [],
		"retired_identifier_hits": [],
		"active_operation_ids": [],
		"projection_only_operation_ids": [],
	}
	var report := VALIDATION_REPORT.build(input)
	_expect(not report.is_empty(), "SemanticValidationReport builds")
	_expect(bool(VALIDATION_REPORT.validate(report).get("valid", false)), "validation report self-validates")
	var wrong_validity := input.duplicate(true)
	wrong_validity["valid"] = false
	_expect(VALIDATION_REPORT.build(wrong_validity).is_empty(), "report validity cannot contradict issues")


func _test_player_presentation() -> void:
	var message_schemas := _message_schemas()
	var cost_schemas := {
		"cost.activation": _schema_descriptor(
			["asset_units"], [], {"asset_units": "nonnegative_integer"}
		),
	}
	var input := _player_dto_input()
	var dto := PLAYER_DTO.build(input, message_schemas, cost_schemas)
	_expect(not dto.is_empty(), "PlayerPresentationDTO builds")
	_expect(bool(PLAYER_DTO.validate(dto, message_schemas, cost_schemas).get("valid", false)), "Player DTO validates")
	input["sections"][0]["keyword_ids"].append("keyword.mutated")
	_expect(
		not ((dto.get("sections") as Array)[0]["keyword_ids"] as Array).has("keyword.mutated"),
		"PlayerPresentationDTO is deeply detached"
	)
	var alias_input := _player_dto_input()
	alias_input["sections"][0]["price"] = 5
	_expect(PLAYER_DTO.build(alias_input, message_schemas, cost_schemas).is_empty(), "legacy UI alias fails closed")
	var runtime_input := _player_dto_input()
	runtime_input["sections"][0]["node"] = Node.new()
	_expect(PLAYER_DTO.build(runtime_input, message_schemas, cost_schemas).is_empty(), "Player DTO rejects runtime object")
	(runtime_input["sections"][0]["node"] as Node).free()


func _test_ai_projection_values() -> void:
	var slice_schemas := _slice_schemas()
	var public_slice := AI_OBSERVATION.build_slice({
		"schema_version": 1,
		"domain_id": "product",
		"schema_id": "observation.product_public.v1",
		"slice_schema_version": 1,
		"source_revision": 5,
		"facts": {"product_id": "product.test", "supply_units": 4},
	}, slice_schemas)
	var private_slice := AI_OBSERVATION.build_slice({
		"schema_version": 1,
		"domain_id": "card",
		"schema_id": "observation.actor_hand_count.v1",
		"slice_schema_version": 1,
		"source_revision": 5,
		"facts": {"ordinary_card_count": 3},
	}, slice_schemas)
	_expect(not public_slice.is_empty() and not private_slice.is_empty(), "typed AI slices build")
	var observation_input := _observation_input(public_slice, private_slice)
	var observation := AI_OBSERVATION.build(observation_input, slice_schemas)
	_expect(not observation.is_empty(), "AiObservationSnapshot builds after clipping")
	observation_input["public_slices"][0]["facts"]["supply_units"] = 99
	_expect(
		int((observation["public_slices"][0]["facts"] as Dictionary).get("supply_units", 0)) == 4,
		"AiObservationSnapshot is deeply detached"
	)
	var unknown_slice := public_slice.duplicate(true)
	unknown_slice["schema_id"] = "observation.unknown.v1"
	unknown_slice["slice_fingerprint"] = WIRE.fingerprint(unknown_slice, "slice_fingerprint")
	var unknown_snapshot := observation.duplicate(true)
	unknown_snapshot["public_slices"] = [unknown_slice]
	unknown_snapshot["snapshot_fingerprint"] = WIRE.fingerprint(unknown_snapshot, "snapshot_fingerprint")
	_expect(
		str(AI_OBSERVATION.validate(unknown_snapshot, slice_schemas).get("reason_id", ""))
			== "ai_observation.slice_schema_unknown",
		"unknown observation slice schema fails closed"
	)
	var privacy_violation := observation.duplicate(true)
	privacy_violation["schema_version"] = 99
	privacy_violation["public_slices"][0]["facts"]["save_payload"] = {"secret": 1}
	_expect(
		str(AI_OBSERVATION.validate(privacy_violation, slice_schemas).get("reason_id", ""))
			== "ai_observation.forbidden_information_before_projection",
		"visibility clipping is checked before projection schema work"
	)

	var outcome := AI_OUTCOME.zero()
	outcome["hand_advantage"] = 1
	outcome["variance"] = 1
	outcome["counter_risk"] = 3
	_expect(bool(AI_OUTCOME.validate(outcome).get("valid", false)), "AiOutcomeVector validates all eleven dimensions")
	var candidate_input := _candidate_input(outcome)
	var activation_schemas := {
		"action.card_play": _schema_descriptor(
			["asset_units"], [], {"asset_units": "nonnegative_integer"}
		),
	}
	var candidate := AI_CANDIDATE.build(candidate_input, activation_schemas)
	_expect(not candidate.is_empty(), "AiActionCandidate builds")
	_expect(not candidate.has("ai_value"), "candidate has no fixed AI value")
	candidate_input["target_identities"][0]["entity_id"] = "player.mutated"
	_expect(
		str((candidate["target_identities"] as Array)[0]["entity_id"]) == "player.two",
		"AiActionCandidate is deeply detached"
	)
	var hidden_candidate := _candidate_input(outcome)
	hidden_candidate["activation_requirements"]["hidden_owner"] = "player.two"
	_expect(AI_CANDIDATE.build(hidden_candidate, activation_schemas).is_empty(), "candidate rejects hidden owner data")


func _test_registry() -> void:
	var descriptor := HANDLER_DESCRIPTOR.build(_handler_descriptor_input())
	_expect(not descriptor.is_empty(), "metadata-only handler descriptor builds")
	var registry := HANDLER_REGISTRY.new()
	var first := registry.register_handler(descriptor)
	var repeated := registry.register_handler(descriptor.duplicate(true))
	_expect(bool(first.get("ok", false)) and bool(first.get("applied", false)), "first registration applies once")
	_expect(
		bool(repeated.get("ok", false))
			and not bool(repeated.get("applied", true))
			and str(repeated.get("status_id", "")) == "already_registered",
		"identical retry is idempotent"
	)
	var conflicting_input := _handler_descriptor_input()
	conflicting_input["handler_owner_id"] = "owner.other_inventory"
	var conflicting := HANDLER_DESCRIPTOR.build(conflicting_input)
	var conflict_receipt := registry.register_handler(conflicting)
	_expect(
		not bool(conflict_receipt.get("ok", true))
			and str(conflict_receipt.get("status_id", "")) == "registration_conflict",
		"same operation key with different descriptor fails closed"
	)
	_expect(registry.descriptor_for("operation.discard_random", 1).is_empty(), "unsealed registry cannot dispatch")
	var manifests: Array[Dictionary] = [{
		"schema_version": 1,
		"domain_id": "card",
		"operation_id": "operation.discard_random",
		"operation_version": 1,
		"execution_readiness_id": "active",
		"semantic_fingerprint": "d".repeat(64),
	}]
	var seal_report := registry.seal(manifests)
	_expect(bool(seal_report.get("valid", false)), "registry seals with one complete active descriptor")
	_expect(WIRE.is_fingerprint(registry.registry_fingerprint()), "sealed registry publishes deterministic fingerprint")
	var lookup := registry.descriptor_for("operation.discard_random", 1)
	_expect(not lookup.is_empty(), "known stable operation lookup succeeds after seal")
	lookup["handler_owner_id"] = "owner.mutated"
	_expect(
		str(registry.descriptor_for("operation.discard_random", 1).get("handler_owner_id", ""))
			== "owner.card_inventory",
		"registry lookup is deeply detached"
	)
	_expect(registry.descriptor_for("operation.unknown", 1).is_empty(), "unknown registry lookup fails closed")
	var post_seal := registry.register_handler(descriptor)
	_expect(
		not bool(post_seal.get("ok", true))
			and str(post_seal.get("status_id", "")) == "registry_sealed",
		"post-seal registration fails closed"
	)
	var debug := registry.debug_snapshot()
	_expect(
		int(debug.get("applied_registration_count", 0)) == 1
			and bool(debug.get("metadata_only", false))
			and not bool(debug.get("stores_callable", true))
			and not bool(debug.get("owns_gameplay_state", true))
			and not bool(debug.get("owns_rng", true)),
		"registry stores metadata only and owns no gameplay state"
	)
	_expect(
		not registry.has_method("build_rule_plan")
			and not registry.has_method("apply")
			and not registry.has_method("rollback"),
		"owner-bound executable dispatch remains outside this PR"
	)
	registry.free()

	var missing_registry := HANDLER_REGISTRY.new()
	var missing_report := missing_registry.seal(manifests)
	_expect(not bool(missing_report.get("valid", true)), "active operation without descriptor blocks seal")
	_expect(
		bool(missing_registry.register_handler(descriptor).get("ok", false)),
		"failed seal leaves registry repairable rather than partially sealed"
	)
	missing_registry.free()


func _test_rng_is_not_consumed() -> void:
	seed(77123)
	var expected_first := randi()
	var expected_second := randi()
	seed(77123)
	var actual_first := randi()
	IDENTITY.build(_identity_input())
	HANDLER_DESCRIPTOR.build(_handler_descriptor_input())
	AI_OUTCOME.build(AI_OUTCOME.zero())
	var actual_second := randi()
	_expect(actual_first == expected_first and actual_second == expected_second, "kernel construction consumes zero RNG draws")


func _identity_input() -> Dictionary:
	return {
		"schema_version": 1,
		"domain_id": "card",
		"definition_id": "card.example",
		"definition_revision": 1,
		"ruleset_id": "ruleset.v06",
		"source_catalog_id": "catalog.cards.v06",
		"source_definition_fingerprint": "a".repeat(64),
	}


func _semantic_ref() -> Dictionary:
	return {
		"schema_version": 1,
		"domain_id": "card",
		"definition_id": "card.example",
		"definition_revision": 1,
		"semantic_schema_version": 1,
		"semantic_fingerprint": "b".repeat(64),
	}


func _entity_ref(entity_type_id: String, entity_id: String, revision := 1) -> Dictionary:
	return {
		"schema_version": 1,
		"entity_type_id": entity_type_id,
		"entity_id": entity_id,
		"revision": revision,
	}


func _schema_descriptor(required: Array, optional: Array, field_kinds: Dictionary) -> Dictionary:
	return {
		"required_fields": required.duplicate(),
		"optional_fields": optional.duplicate(),
		"field_kinds": field_kinds.duplicate(true),
	}


func _parameter_schemas() -> Dictionary:
	return {
		"params.minimum_count.v1": _schema_descriptor(
			["minimum_count"], [], {"minimum_count": "positive_integer"}
		),
		"params.discard_count.v1": _schema_descriptor(
			["count"], [], {"count": "positive_integer"}
		),
	}


func _visibility_policy() -> Dictionary:
	return {
		"schema_version": 1,
		"visibility_policy_id": "visibility.public_result",
		"definition_visibility_id": "public",
		"source_identity_visibility_id": "actor_private",
		"actor_visibility_id": "public",
		"target_choice_visibility_id": "actor_private",
		"outcome_visibility_id": "public",
		"private_value_visibility_id": "actor_private",
		"ai_analysis_visibility_id": "actor_private",
		"redaction_policy_id": "redact.private_values",
	}


func _none_randomness_policy() -> Dictionary:
	return {
		"schema_version": 1,
		"randomness_policy_id": "randomness.none.v1",
		"mode_id": "none",
		"rng_owner_id": "none",
		"stream_id": "none",
		"draw_schedule_id": "none",
		"draw_count_policy_id": "none",
		"selection_order_id": "none",
		"commit_policy_id": "none",
		"failure_consumption_policy_id": "none",
		"rollback_policy_id": "none",
		"replay_policy_id": "none",
		"result_visibility_policy_id": "visibility.public_result",
	}


func _randomness_policy() -> Dictionary:
	return {
		"schema_version": 1,
		"randomness_policy_id": "randomness.card_discard.v1",
		"mode_id": "authoritative_rng",
		"rng_owner_id": "run_rng",
		"stream_id": "card_effect",
		"draw_schedule_id": "on_apply",
		"draw_count_policy_id": "exactly_one",
		"selection_order_id": "stable_candidate_order",
		"commit_policy_id": "transaction_commit",
		"failure_consumption_policy_id": "restore_checkpoint",
		"rollback_policy_id": "restore_checkpoint",
		"replay_policy_id": "record_draw",
		"result_visibility_policy_id": "visibility.public_result",
	}


func _operation_contracts() -> Dictionary:
	return {
		"operation.discard_random": {
			"operation_version": 1,
			"domain_id": "card",
			"parameter_schema_id": "params.discard_count.v1",
			"randomness_mode_id": "authoritative_rng",
		},
	}


func _random_operation() -> Dictionary:
	return {
		"schema_version": 1,
		"operation_instance_id": "operation.instance.one",
		"operation_id": "operation.discard_random",
		"operation_version": 1,
		"domain_id": "card",
		"target_binding_ids": ["target.player"],
		"condition_binding_ids": ["condition.target_hand"],
		"parameter_schema_id": "params.discard_count.v1",
		"parameters": {"count": 1},
		"randomness_policy_id": "randomness.card_discard.v1",
		"result_visibility_policy_id": "visibility.public_result",
		"atomic_group_id": "atomic.card_play",
		"sequence_index": 0,
	}


func _rule_plan_input() -> Dictionary:
	return {
		"schema_version": 1,
		"plan_id": "plan.example",
		"request_id": "request.example",
		"ruleset_id": "ruleset.v06",
		"semantic_ref": _semantic_ref(),
		"actor_ref": _entity_ref("player", "player.one", 3),
		"source_instance_ref": _entity_ref("card_instance", "card.instance.one", 2),
		"source_revision": 2,
		"world_revision": 7,
		"legality_proof_ref": {
			"schema_version": 1,
			"status_id": "legal",
			"rules_revision": 4,
			"world_revision": 7,
			"source_revision": 2,
			"proof_fingerprint": "c".repeat(64),
		},
		"registry_fingerprint": "d".repeat(64),
		"resolved_target_bindings": [{
			"schema_version": 1,
			"target_binding_id": "target.player",
			"target_id": "target.player_opponent",
			"selection_revision": 7,
			"entity_refs": [_entity_ref("player", "player.two", 3)],
			"revalidation_policy_id": "revalidate.before_apply",
		}],
		"condition_proof_refs": [{
			"schema_version": 1,
			"condition_binding_id": "condition.target_hand",
			"condition_id": "condition.target_has_hand",
			"rules_revision": 4,
			"world_revision": 7,
			"proof_fingerprint": "e".repeat(64),
		}],
		"steps": [{
			"schema_version": 1,
			"operation_instance_id": "operation.instance.one",
			"operation_id": "operation.discard_random",
			"operation_version": 1,
			"domain_id": "card",
			"sequence_index": 0,
			"atomic_group_id": "atomic.card_play",
			"target_binding_refs": ["target.player"],
			"condition_proof_refs": ["condition.target_hand"],
			"parameter_schema_id": "params.discard_count.v1",
			"parameters": {"count": 1},
			"randomness_policy_id": "randomness.card_discard.v1",
			"result_visibility_policy_id": "visibility.public_result",
		}],
		"transaction_policy_id": "transaction.card_play",
		"rng_precondition_revision": 11,
		"visibility_policy_id": "visibility.public_result",
	}


func _message_schemas() -> Dictionary:
	var schemas := {}
	for message_id in [
		"message.card.title",
		"message.card.subtitle",
		"message.cost.activation",
		"message.effect.discard",
		"message.keyword.discard.name",
		"message.keyword.discard.tooltip",
	]:
		schemas[message_id] = _schema_descriptor([], [], {})
	return schemas


func _message_token(message_id: String) -> Dictionary:
	return {"schema_version": 1, "message_id": message_id, "arguments": {}}


func _player_dto_input() -> Dictionary:
	return {
		"schema_version": 1,
		"presentation_id": "presentation.card.example",
		"domain_id": "card",
		"semantic_ref": _semantic_ref(),
		"surface_id": "hand",
		"locale_id": "zh_hans",
		"viewer_scope_id": "actor_private",
		"title_message_token": _message_token("message.card.title"),
		"subtitle_message_token": _message_token("message.card.subtitle"),
		"cost_rows": [{
			"schema_version": 1,
			"cost_kind_id": "cost.activation",
			"emphasis_id": "primary",
			"amounts": {"asset_units": 2},
			"message_token": _message_token("message.cost.activation"),
		}],
		"sections": [{
			"schema_version": 1,
			"section_id": "effect",
			"sequence_index": 0,
			"message_tokens": [_message_token("message.effect.discard")],
			"keyword_ids": ["keyword.discard"],
			"icon_id": "icon.card_discard",
			"color_token_id": "color.card_interaction",
		}],
		"keywords": [{
			"schema_version": 1,
			"keyword_id": "keyword.discard",
			"name_message_id": "message.keyword.discard.name",
			"tooltip_message_id": "message.keyword.discard.tooltip",
			"icon_id": "icon.card_discard",
			"color_token_id": "color.card_interaction",
		}],
		"art_asset_id": "art.card_example",
		"icon_id": "icon.card_example",
		"color_token_id": "color.card_interaction",
		"visibility_receipt_ref": "visibility.receipt.player_one",
	}


func _slice_schemas() -> Dictionary:
	return {
		"observation.product_public.v1": {
			"slice_schema_version": 1,
			"visibility_scope_id": "public",
			"required_fields": ["product_id", "supply_units"],
			"optional_fields": [],
			"field_kinds": {"product_id": "stable_id", "supply_units": "nonnegative_integer"},
		},
		"observation.actor_hand_count.v1": {
			"slice_schema_version": 1,
			"visibility_scope_id": "actor_private",
			"required_fields": ["ordinary_card_count"],
			"optional_fields": [],
			"field_kinds": {"ordinary_card_count": "nonnegative_integer"},
		},
	}


func _observation_input(public_slice: Dictionary, private_slice: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"observation_id": "observation.player_one.turn_one",
		"viewer_actor_ref": _entity_ref("player", "player.one", 3),
		"session_revision": 2,
		"world_revision": 7,
		"projection_manifest_fingerprint": "f".repeat(64),
		"public_slices": [public_slice.duplicate(true)],
		"actor_private_slices": [private_slice.duplicate(true)],
		"authorized_action_source_refs": [_entity_ref("card_instance", "card.instance.one", 2)],
		"visibility_receipt_ref": "visibility.receipt.player_one",
	}


func _candidate_input(outcome: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"candidate_id": "candidate.card_example.player_two",
		"action_id": "action.card_example.player_two",
		"action_kind_id": "action.card_play",
		"semantic_ref": _semantic_ref(),
		"actor_ref": _entity_ref("player", "player.one", 3),
		"source_instance_ref": _entity_ref("card_instance", "card.instance.one", 2),
		"target_identities": [_entity_ref("player", "player.two", 3)],
		"source_revision": 2,
		"world_revision": 7,
		"legality_revision": 4,
		"legal": true,
		"rejection_reason_id": "none",
		"activation_requirements": {"asset_units": 2},
		"outcome_vector": outcome.duplicate(true),
		"uncertainty": 4,
		"counter_risk": 3,
		"information_scope_id": "actor_private",
		"explanation_token_ids": ["semantic.operation.discard_random"],
		"plan_preview_fingerprint": "1".repeat(64),
	}


func _handler_descriptor_input() -> Dictionary:
	return {
		"schema_version": 1,
		"operation_id": "operation.discard_random",
		"operation_version": 1,
		"domain_id": "card",
		"handler_owner_id": "owner.card_inventory",
		"mechanic_ids": ["interaction.hand_discard"],
		"rule_source_refs": ["docs/rules/card.md#discard"],
		"parameter_schema_id": "params.discard_count.v1",
		"supported_condition_ids": ["condition.target_has_hand"],
		"supported_target_ids": ["target.player_opponent"],
		"supported_randomness_policy_ids": ["randomness.card_discard.v1"],
		"supported_transaction_policy_ids": ["transaction.card_play"],
		"supported_plan_schema_versions": [1],
		"supports_preflight": true,
		"supports_checkpoint": true,
		"supports_apply": true,
		"supports_rollback": true,
		"supports_rules_projection": true,
		"supports_player_projection": true,
		"supports_ai_projection": true,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var elapsed_ms := snappedf(float(Time.get_ticks_usec() - _started_usec) / 1000.0, 0.001)
	if _failures.is_empty():
		print(
			"SEMANTIC_KERNEL_V1_TEST|status=PASS|checks=%d|failures=0|duration_ms=%.3f"
			% [_checks, elapsed_ms]
		)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print(
		"SEMANTIC_KERNEL_V1_TEST|status=FAIL|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [_checks, _failures.size(), elapsed_ms, JSON.stringify(_failures)]
	)
	quit(1)
