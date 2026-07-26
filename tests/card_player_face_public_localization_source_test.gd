extends SceneTree

const AUTHORIZED_SOURCE := preload(
	"res://scripts/presentation/authorized_card_player_face_localization_source_v1.gd"
)
const CARD_SEMANTIC_SCHEMA := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)
const PLAYER_FACE_DTO := preload(
	"res://scripts/presentation/player_face_dto_v1.gd"
)
const PLAYER_CARD_CODEX_DTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SEMANTIC_SERVICE_SCENE := preload(
	"res://scenes/runtime/CardSemanticCatalogService.tscn"
)
const LOCALIZATION_SERVICE_SCENE := preload(
	"res://scenes/runtime/CardPlayerFacePublicLocalizationSourceService.tscn"
)
const PROJECTION_SERVICE_SCENE := preload(
	"res://scenes/runtime/CardPlayerFaceProjectionService.tscn"
)
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var semantic_service := (
		SEMANTIC_SERVICE_SCENE.instantiate() as CardSemanticCatalogService
	)
	var localization_service: Node = LOCALIZATION_SERVICE_SCENE.instantiate()
	var projection_service := (
		PROJECTION_SERVICE_SCENE.instantiate()
		as CardPlayerFaceProjectionService
	)
	root.add_child(semantic_service)
	root.add_child(localization_service)
	root.add_child(projection_service)
	await process_frame
	_expect(
		semantic_service != null
			and localization_service != null
			and projection_service != null,
		"services_instantiate"
	)
	if semantic_service == null \
			or localization_service == null \
			or projection_service == null:
		_finish()
		return

	var configuration: Dictionary = localization_service.configure(semantic_service)
	_expect(bool(configuration.get("configured", false)), "owner_configures")
	_expect(
		int(configuration.get("sealed_record_fingerprint_count", 0)) == 348
			and int(configuration.get("sealed_bundle_count", 0)) == 348
			and int(configuration.get("sanitized_authored_presentation_count", 0)) == 348,
		"owner_seals_348_hashes_bundles_and_sanitized_payloads"
	)
	_expect(
		not bool(configuration.get("retains_full_card_records", true))
			and not bool(configuration.get("retains_full_record_canonical_json", true))
			and not bool(configuration.get("retains_machine_blocks", true))
			and not bool(configuration.get("retains_developer_blocks", true)),
		"owner_attests_no_full_catalog_or_private_block_retention"
	)
	_expect(
		not bool(configuration.get("owns_save_state", true))
			and not bool(configuration.get("uses_rng", true))
			and not bool(configuration.get("owns_rules", true))
			and not bool(configuration.get("owns_world_state", true))
			and not bool(configuration.get("depends_on_main", true)),
		"owner_has_no_save_rng_rules_world_or_main_responsibility"
	)
	_expect(
		not bool(configuration.get("supports_arbitrary_card_id_lookup", true))
			and not bool(configuration.get("supports_catalog_enumeration", true))
			and not localization_service.has_method("issue_for_card_id")
			and not localization_service.has_method("card_ids")
			and not localization_service.has_method("catalog_snapshot"),
		"owner_exposes_no_id_lookup_or_enumeration_api"
	)

	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(catalog != null, "catalog_loads")
	if catalog == null:
		_finish_nodes(semantic_service, localization_service, projection_service)
		return
	var catalog_report := catalog.reload()
	var catalog_snapshot := catalog.catalog_snapshot()
	var cards := catalog_snapshot.get("cards", []) as Array
	_expect(
		bool(catalog_report.get("valid", false)) and cards.size() == 348,
		"catalog_has_348_valid_records"
	)

	var metrics_before := semantic_service.validation_snapshot()
	var accepted_count := 0
	var codex_dto_count := 0
	var family_ids: Dictionary = {}
	var representative_record: Dictionary = {}
	var representative_spec: Dictionary = {}
	var representative_bundle: Dictionary = {}
	var representative_verified: Dictionary = {}
	var representative_detail: Dictionary = {}
	for index in range(cards.size()):
		var record := cards[index] as Dictionary
		var machine := record.get("machine", {}) as Dictionary
		var card_id := str(machine.get("card_id", ""))
		var family_id := str(machine.get("family_id", ""))
		family_ids[family_id] = true
		var compiled := semantic_service.compile_authorized(
			_compiler_envelope(record, index + 1)
		)
		var spec := compiled.get("spec", {}) as Dictionary
		var bundle: Dictionary = localization_service.issue_for_exact_record(record, spec)
		var verified: Dictionary = localization_service.verify_bundle(bundle, spec)
		var projection_source := verified.get("projection_source", {}) as Dictionary
		var detail := projection_service.project(spec, projection_source, "detail")
		var codex_dto := PLAYER_CARD_CODEX_DTO.seal({
			"schema_version": PLAYER_CARD_CODEX_DTO.SCHEMA_VERSION,
			"projection_id": PLAYER_CARD_CODEX_DTO.PROJECTION_ID,
			"semantic_binding": {
				"source_catalog_id": str(spec.get("source_catalog_id", "")),
				"source_definition_fingerprint": str(spec.get("source_definition_fingerprint", "")),
				"semantic_fingerprint": str(spec.get("semantic_fingerprint", "")),
			},
			"localization_binding": (verified.get("localization_binding", {}) as Dictionary).duplicate(true),
			"detail_face": detail,
			"taxonomy": (verified.get("taxonomy", {}) as Dictionary).duplicate(true),
			"presentation_tokens": (verified.get("presentation_tokens", {}) as Dictionary).duplicate(true),
			"presentation_copy": (verified.get("presentation_copy", {}) as Dictionary).duplicate(true),
		})
		if bool(compiled.get("ok", false)) \
				and bool(compiled.get("cache_hit", false)) \
				and bool(bundle.get("accepted", false)) \
				and bool(AUTHORIZED_SOURCE.validate_issue_result(bundle).get("valid", false)) \
				and bool(verified.get("accepted", false)) \
				and bool(AUTHORIZED_SOURCE.validate_verified_report(verified).get("valid", false)) \
				and bool(PLAYER_FACE_DTO.validate(detail).get("valid", false)):
			accepted_count += 1
		if not codex_dto.is_empty() \
				and bool(PLAYER_CARD_CODEX_DTO.validate(codex_dto).get("valid", false)):
			codex_dto_count += 1
		if representative_record.is_empty() \
				and (spec.get("effect_ops", []) as Array).size() > 1:
			representative_record = record.duplicate(true)
			representative_spec = spec.duplicate(true)
			representative_bundle = bundle.duplicate(true)
			representative_verified = verified.duplicate(true)
			representative_detail = detail.duplicate(true)
	_expect(accepted_count == 348, "all_348_records_issue_verify_and_project")
	_expect(codex_dto_count == 348, "all_348_outputs_seal_as_frozen_codex_dto")
	_expect(family_ids.size() == 87, "all_87_families_are_covered")
	var metrics_after := semantic_service.validation_snapshot()
	_expect(
		int(metrics_after.get("compile_count", -1))
			== int(metrics_before.get("compile_count", -2)),
		"issue_verify_projection_compile_delta_zero"
	)
	_expect(
		not _contains_non_ascii_string(representative_bundle)
			and not _contains_key_recursive(
				representative_bundle,
				["text", "raw_text", "localized_text", "rules_text", "tooltip"]
			),
		"issued_bundle_contains_only_ids_tokens_and_fingerprints"
	)

	_test_closed_dto_shape(representative_verified, representative_detail)
	_test_record_and_semantic_attestation(
		localization_service,
		representative_record,
		representative_spec
	)
	_test_bundle_attestation(
		localization_service,
		representative_bundle,
		representative_spec
	)
	_test_rule_copy_is_semantic(
		localization_service,
		representative_record,
		representative_spec,
		representative_bundle,
		representative_verified
	)
	_test_token_resolution(localization_service, representative_verified)
	_test_final_message_resolution(
		localization_service,
		representative_bundle,
		representative_spec,
		representative_detail
	)
	_test_source_hygiene(localization_service)

	_finish_nodes(semantic_service, localization_service, projection_service)


func _test_closed_dto_shape(verified: Dictionary, detail: Dictionary) -> void:
	var copy := verified.get("presentation_copy", {}) as Dictionary
	var tokens := verified.get("presentation_tokens", {}) as Dictionary
	_expect(
		_exact_fields(copy, PLAYER_CARD_CODEX_DTO.PRESENTATION_COPY_FIELDS),
		"verified_presentation_copy_matches_frozen_dto_fields"
	)
	_expect(
		_exact_fields(tokens, PLAYER_CARD_CODEX_DTO.PRESENTATION_TOKEN_FIELDS),
		"verified_presentation_tokens_match_frozen_dto_fields"
	)
	for field_id in PLAYER_CARD_CODEX_DTO.PRESENTATION_ARRAY_FIELDS:
		var texts := copy.get(field_id, []) as Array
		var detail_rows := detail.get(field_id, []) as Array
		_expect(
			texts.size() == detail_rows.size() and _ordered_nonempty_strings(texts),
			"verified_%s_matches_detail_order_and_count" % field_id
		)
	_expect(
		str(tokens.get("illustration_key", "")).is_empty()
			and PLAYER_FACE_DTO.is_stable_id(str(tokens.get("fallback_illustration_token_id", ""))),
		"empty_optional_illustration_uses_stable_fallback_token"
	)
	_expect(
		not _contains_key_recursive(
			verified,
			[
				"machine",
				"player",
				"developer",
				"effect_payload",
				"owner",
				"hidden_owner",
				"ai_score",
				"save_payload",
			]
		),
		"verified_report_has_no_static_record_or_private_value_channel"
	)


func _test_record_and_semantic_attestation(
	service: Node,
	record: Dictionary,
	spec: Dictionary
) -> void:
	for block_id in ["machine", "player", "developer"]:
		var changed := record.duplicate(true)
		var block := changed.get(block_id, {}) as Dictionary
		block["same_id_mutation"] = "changed"
		_expect(
			not bool(service.issue_for_exact_record(changed, spec).get("accepted", true)),
			"same_id_%s_mutation_rejected" % block_id
		)
	var forged_authorization := record.duplicate(true)
	forged_authorization["authorized"] = true
	_expect(
		not bool(service.issue_for_exact_record(forged_authorization, spec).get("accepted", true)),
		"caller_authored_authorized_true_rejected"
	)
	var external := record.duplicate(true)
	var external_machine := external.get("machine", {}) as Dictionary
	external_machine["card_id"] = "external.card.rank_1"
	external_machine["family_id"] = "external.card"
	_expect(
		not bool(service.issue_for_exact_record(external, spec).get("accepted", true)),
		"external_record_rejected"
	)
	var stale_semantic := spec.duplicate(true)
	stale_semantic["semantic_fingerprint"] = "b".repeat(64)
	_expect(
		not bool(service.issue_for_exact_record(record, stale_semantic).get("accepted", true)),
		"stale_semantic_rejected"
	)
	var resigned_semantic := spec.duplicate(true)
	resigned_semantic["runtime_readiness_id"] = "projection_only" \
		if str(spec.get("runtime_readiness_id", "")) != "projection_only" else "active"
	resigned_semantic["semantic_fingerprint"] = CARD_SEMANTIC_SCHEMA.fingerprint(
		resigned_semantic,
		"semantic_fingerprint"
	)
	_expect(
		not bool(service.issue_for_exact_record(record, resigned_semantic).get("accepted", true)),
		"caller_resigned_semantic_rejected"
	)
	var runtime_node := Node.new()
	var object_record := record.duplicate(true)
	object_record["runtime_node"] = runtime_node
	_expect(
		not bool(service.issue_for_exact_record(object_record, spec).get("accepted", true)),
		"node_in_record_rejected"
	)
	runtime_node.free()
	var callable_record := record.duplicate(true)
	callable_record["callback"] = Callable(self, "_run")
	_expect(
		not bool(service.issue_for_exact_record(callable_record, spec).get("accepted", true)),
		"callable_in_record_rejected"
	)
	var resource_record := record.duplicate(true)
	resource_record["resource"] = Resource.new()
	_expect(
		not bool(service.issue_for_exact_record(resource_record, spec).get("accepted", true)),
		"resource_in_record_rejected"
	)


func _test_bundle_attestation(
	service: Node,
	bundle: Dictionary,
	spec: Dictionary
) -> void:
	var forged_receipt := bundle.duplicate(true)
	var forged_receipt_body := forged_receipt.get("authorization_receipt", {}) as Dictionary
	forged_receipt_body["source_revision"] = 2
	forged_receipt_body["receipt_fingerprint"] = WIRE.fingerprint(
		forged_receipt_body,
		"receipt_fingerprint"
	)
	forged_receipt["bundle_fingerprint"] = WIRE.fingerprint(
		forged_receipt,
		"bundle_fingerprint"
	)
	_expect(
		not bool(service.verify_bundle(forged_receipt, spec).get("accepted", true)),
		"forged_resigned_receipt_rejected_by_owner_registry"
	)
	var stale_source := bundle.duplicate(true)
	var source := stale_source.get("localization_source", {}) as Dictionary
	var source_binding := source.get("source_binding", {}) as Dictionary
	source_binding["source_revision"] = 2
	source["source_manifest_fingerprint"] = WIRE.fingerprint(
		source,
		"source_manifest_fingerprint"
	)
	var receipt := stale_source.get("authorization_receipt", {}) as Dictionary
	receipt["source_revision"] = 2
	receipt["source_fingerprint"] = str(source.get("source_manifest_fingerprint", ""))
	receipt["receipt_fingerprint"] = WIRE.fingerprint(receipt, "receipt_fingerprint")
	stale_source["bundle_fingerprint"] = WIRE.fingerprint(
		stale_source,
		"bundle_fingerprint"
	)
	_expect(
		not bool(service.verify_bundle(stale_source, spec).get("accepted", true)),
		"stale_resigned_source_rejected_by_owner_registry"
	)
	var raw_message := bundle.duplicate(true)
	var raw_source := raw_message.get("localization_source", {}) as Dictionary
	var structural := raw_source.get("structural_message_ids", {}) as Dictionary
	structural["name"] = "伪造卡名"
	_expect(
		not bool(service.verify_bundle(raw_message, spec).get("accepted", true)),
		"raw_text_as_message_id_rejected"
	)
	var duplicate_keyword := bundle.duplicate(true)
	var duplicate_source := duplicate_keyword.get("localization_source", {}) as Dictionary
	var keyword_rows := duplicate_source.get("keyword_rows", []) as Array
	(keyword_rows[1] as Dictionary)["keyword_id"] = str(
		(keyword_rows[0] as Dictionary).get("keyword_id", "")
	)
	_expect(
		not bool(service.verify_bundle(duplicate_keyword, spec).get("accepted", true)),
		"duplicate_semantic_keyword_id_rejected"
	)
	for forbidden_key in [
		"owner",
		"hidden_owner",
		"true_owner",
		"player_index",
		"hand",
		"opponent_hand",
		"exact_cash",
		"private_plan",
		"ai_score",
		"ai_value",
		"route_plan",
		"future_bag",
		"rng_state",
		"save_payload",
		"developer",
		"effect_payload",
		"method_name",
		"script_path",
	]:
		var injected := bundle.duplicate(true)
		var injected_source := injected.get("localization_source", {}) as Dictionary
		injected_source[forbidden_key] = "injected"
		_expect(
			not bool(service.verify_bundle(injected, spec).get("accepted", true)),
			"value_channel_%s_rejected" % forbidden_key
		)


func _test_rule_copy_is_semantic(
	service: Node,
	record: Dictionary,
	spec: Dictionary,
	bundle: Dictionary,
	verified: Dictionary
) -> void:
	var original_copy := verified.get("presentation_copy", {}) as Dictionary
	var mutated_authored: Dictionary = service._sanitize_authored_presentation(record)
	mutated_authored["authored_timing_summary"] = "伪造时机"
	mutated_authored["authored_target_summary"] = "伪造目标"
	mutated_authored["authored_duration_summary"] = "伪造持续"
	mutated_authored["authored_information_scope_summary"] = "伪造可见性"
	var source := bundle.get("localization_source", {}) as Dictionary
	var reprojection: Dictionary = service._presentation_copy(
		mutated_authored,
		source,
		spec
	)
	for field_id in [
		"timing",
		"targets",
		"conditions",
		"effect_steps",
		"duration",
		"counterability",
		"information_scope",
	]:
		_expect(
			reprojection.get(field_id) == original_copy.get(field_id),
			"authored_rule_copy_cannot_drive_%s" % field_id
		)
	var op_ids: Array[String] = []
	for effect_variant in spec.get("effect_ops", []) as Array:
		op_ids.append(str((effect_variant as Dictionary).get("op_id", "")))
	var effect_texts := original_copy.get("effect_steps", []) as Array
	var order_preserved := effect_texts.size() == op_ids.size()
	for index in range(mini(effect_texts.size(), op_ids.size())):
		var expected_label := str(
			service.OPERATION_LABELS.get(op_ids[index], op_ids[index])
		)
		order_preserved = order_preserved \
			and str(effect_texts[index]).contains(expected_label) \
			and str(effect_texts[index]).begins_with("%d. " % (index + 1))
	_expect(order_preserved, "effect_step_strings_preserve_semantic_order")
	if effect_texts.size() > 1:
		_expect(
			str(effect_texts[0]) != str(effect_texts[1]),
			"multi_op_effect_steps_are_formatted_independently"
		)


func _test_token_resolution(
	service: Node,
	verified: Dictionary
) -> void:
	var tokens := verified.get("presentation_tokens", {}) as Dictionary
	var icon_token_id := str(tokens.get("category_icon_token_id", ""))
	var category_color_token_id := str(tokens.get("category_color_token_id", ""))
	var industry_color_token_id := str(tokens.get("industry_color_token_id", ""))
	_expect(not service.resolve_icon_token(icon_token_id).is_empty(), "issued_icon_token_resolves")
	_expect(service.resolve_color_token(category_color_token_id).a > 0.0, "issued_category_color_token_resolves")
	_expect(service.resolve_color_token(industry_color_token_id).a > 0.0, "issued_industry_color_token_resolves")
	_expect(service.resolve_icon_token("icon.card.unknown").is_empty(), "unknown_icon_token_fails_closed")
	_expect(service.resolve_color_token("color.card.unknown").a == 0.0, "unknown_color_token_fails_closed")
	_expect(service.resolve_icon_token("commodity.star_dew_berry.rank_1").is_empty(), "card_id_is_not_a_token_lookup")


func _test_final_message_resolution(
	service: Node,
	bundle: Dictionary,
	spec: Dictionary,
	detail: Dictionary
) -> void:
	var name_result: Dictionary = service.resolve_at_presentation(
		bundle,
		spec,
		detail.get("name_ref", {}) as Dictionary
	)
	var acquisition := detail.get("acquisition_cost", {}) as Dictionary
	var acquisition_result: Dictionary = service.resolve_at_presentation(
		bundle,
		spec,
		acquisition.get("message_ref", {}) as Dictionary
	)
	_expect(
		bool(name_result.get("accepted", false))
			and not str(name_result.get("text", "")).is_empty(),
		"bundle_bound_name_message_resolves"
	)
	_expect(
		bool(acquisition_result.get("accepted", false))
			and (
				str(acquisition_result.get("text", "")).contains("领取")
				or str(acquisition_result.get("text", "")).contains("获取")
			),
		"bundle_bound_acquisition_message_resolves_separately"
	)
	_expect(
		not bool(service.resolve_at_presentation(
			bundle,
			spec,
			{"message_id": "card.unissued.message", "args": []}
		).get("accepted", true)),
		"unissued_message_id_fails_closed"
	)
	var duplicate_args := (detail.get("name_ref", {}) as Dictionary).duplicate(true)
	var original_args := duplicate_args.get("args", []) as Array
	if not original_args.is_empty():
		original_args.append((original_args[0] as Dictionary).duplicate(true))
	_expect(
		not bool(service.resolve_at_presentation(
			bundle,
			spec,
			duplicate_args
		).get("accepted", true)),
		"duplicate_typed_message_arg_fails_closed"
	)


func _test_source_hygiene(
	service: Node
) -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/runtime/card_player_face_public_localization_source_service.gd"
	)
	_expect(
		not source.contains("get_tree().current_scene")
			and not source.contains("/root/Main")
			and not source.contains("RandomNumberGenerator")
			and not source.contains("randf(")
			and not source.contains("randi(")
			and not source.contains("issue_for_card_id")
			and not source.contains("_sealed_record_by_card_id")
			and not source.contains("_sealed_record_canonical_by_card_id"),
		"production_source_has_no_main_rng_lookup_or_full_record_cache"
	)
	var debug: Dictionary = service.debug_snapshot()
	var debug_json := JSON.stringify(debug)
	_expect(
		not debug.has("cards")
			and not debug.has("card_records")
			and not debug.has("authored_presentation")
			and not debug_json.contains("星露莓")
			and not debug_json.contains("commodity.star_dew_berry.rank_1"),
		"debug_snapshot_leaks_no_record_or_authored_copy"
	)


func _compiler_envelope(record: Dictionary, revision: int) -> Dictionary:
	return {
		"schema_version": CARD_SEMANTIC_SCHEMA.SCHEMA_VERSION,
		"source_kind": "public_rack",
		"source_revision": revision,
		"visibility_scope_id": "public",
		"card_record": record.duplicate(true),
	}


func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


func _ordered_nonempty_strings(value: Array) -> bool:
	for item in value:
		if not (item is String) or str(item).strip_edges().is_empty():
			return false
	return true


func _contains_key_recursive(value: Variant, keys: Array) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if keys.has(key) \
					or _contains_key_recursive(
						(value as Dictionary).get(key_variant),
						keys
					):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_key_recursive(item, keys):
				return true
	return false


func _contains_non_ascii_string(value: Variant) -> bool:
	if value is String:
		for index in range(str(value).length()):
			if str(value).unicode_at(index) > 127:
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if _contains_non_ascii_string(key_variant) \
					or _contains_non_ascii_string(
						(value as Dictionary).get(key_variant)
					):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_non_ascii_string(item):
				return true
	return false


func _finish_nodes(
	semantic_service: Node,
	localization_service: Node,
	projection_service: Node
) -> void:
	semantic_service.queue_free()
	localization_service.queue_free()
	projection_service.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, failure_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(failure_id)


func _finish() -> void:
	var elapsed_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	if _failures.is_empty():
		print(
			"CARD_PLAYER_FACE_PUBLIC_LOCALIZATION_SOURCE_TEST|status=PASS|checks=%d|cards=348|families=87|duration_ms=%.3f"
			% [_checks, elapsed_ms]
		)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print(
		"CARD_PLAYER_FACE_PUBLIC_LOCALIZATION_SOURCE_TEST|status=FAIL|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [_checks, _failures.size(), elapsed_ms, JSON.stringify(_failures)]
	)
	quit(1)
