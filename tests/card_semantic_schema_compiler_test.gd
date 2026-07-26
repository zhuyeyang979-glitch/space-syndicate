extends SceneTree

const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const COMPILER := preload("res://scripts/cards/semantic/card_semantic_compiler_v1.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const SERVICE_SCENE_PATH := "res://scenes/runtime/CardSemanticCatalogService.tscn"

const EXPECTED_OP_COUNTS := {
	"install_rate": 184,
	"build_facility": 64,
	"upgrade_facility": 64,
	"repair_facility": 64,
	"deploy_unit": 60,
	"upgrade_same_family_unit": 60,
	"extend_presence": 32,
	"heal_unit": 32,
	"modify_supply": 4,
	"modify_demand": 4,
	"discard_random": 4,
	"steal_random": 4,
	"lock_random": 6,
	"counter_action": 4,
	"install_organization_upgrade": 20,
}
const EXPECTED_TARGETS := {
	"install_commodity_rate": "facility.same_industry",
	"build_upgrade_or_repair_facility": "district.active",
	"deploy_or_upgrade_monster": "unit.same_family",
	"deploy_or_upgrade_military": "unit.same_family",
	"global_order_budget": "world.global",
	"global_supply_spawn": "world.global",
	"player_hand_disrupt": "player.opponent",
	"player_hand_steal": "player.opponent",
	"card_counter": "response.incoming_direct_interaction",
	"install_organization_upgrade": "organization.self_slot",
}
const FORBIDDEN_OUTPUT_KEYS := [
	"ai_value", "score", "weight", "owner_id", "player_index", "method",
	"script_path", "node", "callable", "localized_text", "product_id",
]

var _failures: Array[String] = []
var _checks := 0
var _suite_started_usec := 0
var _catalog_compile_usec := 0


func _init() -> void:
	_suite_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(catalog != null, "catalog_resource_loads")
	if catalog == null:
		_finish()
		return
	var catalog_report := catalog.reload()
	_expect(bool(catalog_report.get("valid", false)), "catalog_resource_valid")
	var snapshot := catalog.catalog_snapshot()
	var cards: Array = snapshot.get("cards", []) if snapshot.get("cards", []) is Array else []
	_expect(str(snapshot.get("catalog_id", "")) == "space_syndicate.card_runtime_catalog.v06", "catalog_id")
	_expect(cards.size() == 348, "catalog_record_count")

	var compiler = COMPILER.new()
	var compile_started := Time.get_ticks_usec()
	var report := compiler.compile_catalog_snapshot(snapshot)
	_catalog_compile_usec = Time.get_ticks_usec() - compile_started
	_expect(bool(report.get("ok", false)), "catalog_compile_succeeds:%s" % JSON.stringify(report.get("errors", [])))
	_expect(int(report.get("source_record_count", 0)) == 348, "source_record_count")
	_expect(int(report.get("compiled_count", 0)) == 348, "compiled_count")
	_expect(int(report.get("active_count", 0)) == 256, "active_count")
	_expect(int(report.get("projection_only_count", 0)) == 92, "projection_only_count")
	_expect(int(report.get("not_acquirable_count", -1)) == 0, "not_acquirable_count")
	_expect((report.get("op_counts", {}) as Dictionary) == EXPECTED_OP_COUNTS, "normalized_op_counts")
	_expect((report.get("errors", []) as Array).is_empty(), "catalog_compile_errors_empty")
	_expect(_is_sha256(str(report.get("source_catalog_fingerprint", ""))), "source_catalog_fingerprint")
	_expect(_is_sha256(str(report.get("semantic_catalog_fingerprint", ""))), "semantic_catalog_fingerprint")

	var first_metrics := compiler.cache_metrics()
	_expect(int(first_metrics.get("cache_entry_count", 0)) == 348, "cache_entry_count_after_first_compile")
	_expect(int(first_metrics.get("compile_count", 0)) == 348, "compile_count_after_first_compile")
	_expect(int(first_metrics.get("cache_hit_count", -1)) == 0, "cache_hits_after_first_compile")
	var repeated_report := compiler.compile_catalog_snapshot(snapshot)
	var repeated_metrics := compiler.cache_metrics()
	_expect(str(repeated_report.get("semantic_catalog_fingerprint", "")) == str(report.get("semantic_catalog_fingerprint", "")), "repeated_catalog_fingerprint")
	_expect(int(repeated_metrics.get("compile_count", 0)) == 348, "compile_once_per_definition")
	_expect(int(repeated_metrics.get("cache_hit_count", 0)) == 348, "second_catalog_compile_is_cache_only")

	var fresh_report := COMPILER.new().compile_catalog_snapshot(snapshot)
	_expect(str(fresh_report.get("source_catalog_fingerprint", "")) == str(report.get("source_catalog_fingerprint", "")), "fresh_source_fingerprint_deterministic")
	_expect(str(fresh_report.get("semantic_catalog_fingerprint", "")) == str(report.get("semantic_catalog_fingerprint", "")), "fresh_semantic_fingerprint_deterministic")

	var total_ops := 0
	var monster_projection_only_count := 0
	for card_value in cards:
		var card: Dictionary = card_value
		var machine: Dictionary = card.get("machine", {})
		var result := compiler.compile_card_record(card, str(snapshot.get("catalog_id", "")))
		_expect(bool(result.get("ok", false)), "record_compile:%s" % str(machine.get("card_id", "")))
		if not bool(result.get("ok", false)):
			continue
		var spec: Dictionary = result.get("spec", {})
		var schema_report := SCHEMA.validate_semantic_spec(spec)
		_expect(bool(schema_report.get("valid", false)), "record_schema:%s:%s" % [str(machine.get("card_id", "")), JSON.stringify(schema_report.get("errors", []))])
		_expect(SCHEMA.is_pure_data(spec), "record_pure_data:%s" % str(machine.get("card_id", "")))
		_expect(not _contains_forbidden_key(spec), "record_forbidden_key:%s" % str(machine.get("card_id", "")))
		_expect(not _contains_non_ascii(spec), "record_localized_value:%s" % str(machine.get("card_id", "")))
		_expect(str((spec.get("target", {}) as Dictionary).get("target_id", "")) == str(EXPECTED_TARGETS.get(machine.get("effect_kind", ""), "")), "record_target:%s" % str(machine.get("card_id", "")))
		_expect(bool((spec.get("identity", {}) as Dictionary).get("available_for_acquisition", false)) == bool(machine.get("available_for_acquisition", false)), "record_acquisition_preserved:%s" % str(machine.get("card_id", "")))
		var readiness_id := str(spec.get("runtime_readiness_id", ""))
		var category_id := str(machine.get("category_id", ""))
		if category_id == "monster":
			_expect(readiness_id == "projection_only", "monster_real_owner_atomic_route_not_ready:%s" % str(machine.get("card_id", "")))
			if readiness_id == "projection_only":
				monster_projection_only_count += 1
		elif ["military", "interaction", "organization"].has(category_id):
			_expect(readiness_id == "projection_only", "unwired_route_never_active:%s" % str(machine.get("card_id", "")))
		else:
			_expect(readiness_id == "active", "production_wired_record_active:%s" % str(machine.get("card_id", "")))
		for amount in ((spec.get("cost", {}) as Dictionary).get("activation", {}) as Dictionary).values():
			_expect(amount is int and int(amount) >= 0, "activation_cost_integer:%s" % str(machine.get("card_id", "")))
		total_ops += (spec.get("effect_ops", []) as Array).size()
	_expect(monster_projection_only_count == 32, "all_monster_records_remain_projection_only_until_atomic_real_owner_route")
	_expect(total_ops == 606, "total_normalized_op_count")

	_verify_closed_failures(cards[0], str(snapshot.get("catalog_id", "")))
	_verify_schema_and_canonicalization(compiler, cards[0], str(snapshot.get("catalog_id", "")))
	await _verify_service(cards[0])
	_verify_source_boundaries()
	_finish()


func _verify_closed_failures(card_value: Variant, catalog_id: String) -> void:
	var card: Dictionary = (card_value as Dictionary).duplicate(true)
	var unknown_effect := card.duplicate(true)
	(unknown_effect["machine"] as Dictionary)["effect_kind"] = "unknown_effect"
	_expect_closed_failure(COMPILER.new().compile_card_record(unknown_effect, catalog_id), "unknown_effect_fails_closed")
	var unknown_target := card.duplicate(true)
	(unknown_target["machine"] as Dictionary)["target_kind"] = "unknown_target"
	_expect_closed_failure(COMPILER.new().compile_card_record(unknown_target, catalog_id), "unknown_target_fails_closed")
	var missing_payload := card.duplicate(true)
	((missing_payload["machine"] as Dictionary)["effect_payload"] as Dictionary).erase("rate_per_minute")
	_expect(not bool(COMPILER.new().compile_card_record(missing_payload, catalog_id).get("ok", true)), "missing_payload_field_fails_closed")
	var extra_payload := card.duplicate(true)
	((extra_payload["machine"] as Dictionary)["effect_payload"] as Dictionary)["unsupported"] = 1
	_expect(not bool(COMPILER.new().compile_card_record(extra_payload, catalog_id).get("ok", true)), "extra_payload_field_fails_closed")
	var extra_machine := card.duplicate(true)
	(extra_machine["machine"] as Dictionary)["unsupported"] = true
	_expect(not bool(COMPILER.new().compile_card_record(extra_machine, catalog_id).get("ok", true)), "extra_machine_field_fails_closed")
	var fractional_source := card.duplicate(true)
	(fractional_source["machine"] as Dictionary)["purchase_cash"] = 0.5
	_expect(not bool(COMPILER.new().compile_card_record(fractional_source, catalog_id).get("ok", true)), "fractional_authored_integer_fails_closed")


func _verify_schema_and_canonicalization(compiler: CardSemanticCompilerV1, card_value: Variant, catalog_id: String) -> void:
	var result := compiler.compile_card_record(card_value, catalog_id)
	var spec: Dictionary = result.get("spec", {})
	var op: Dictionary = ((spec.get("effect_ops", []) as Array)[0] as Dictionary).duplicate(true)
	var extra_op := op.duplicate(true)
	extra_op["unsupported"] = true
	_expect(not bool(SCHEMA.validate_effect_op(extra_op).get("valid", true)), "extra_op_field_fails_closed")
	var missing_op := op.duplicate(true)
	missing_op.erase("rate_units_per_minute")
	_expect(not bool(SCHEMA.validate_effect_op(missing_op).get("valid", true)), "missing_op_field_fails_closed")
	_expect(not bool(SCHEMA.validate_effect_op({"op_id": "unknown_op"}).get("valid", true)), "unknown_op_fails_closed")
	for capability_id in ["military_move", "military_guard", "military_strike", "global_order", "global_supply_spawn"]:
		_expect(bool(SCHEMA.validate_effect_op({"op_id": capability_id}).get("valid", false)), "fixture_capability:%s" % capability_id)
	var mismatched := spec.duplicate(true)
	mismatched["semantic_fingerprint"] = "0".repeat(64)
	_expect(not bool(SCHEMA.validate_semantic_spec(mismatched).get("valid", true)), "semantic_fingerprint_mismatch_rejected")

	var canonical_a := SCHEMA.canonical_json({"z": [{"b": 2, "a": 1}], "a": true})
	var canonical_b := SCHEMA.canonical_json({"a": true, "z": [{"a": 1, "b": 2}]})
	_expect(canonical_a == canonical_b, "recursive_dictionary_key_order_canonical")
	_expect(canonical_a == "{\"a\":true,\"z\":[{\"a\":1,\"b\":2}]}", "canonical_json_profile")
	_expect(SCHEMA.fingerprint({"b": 2, "a": 1}) == SCHEMA.fingerprint({"a": 1, "b": 2}), "canonical_sha256_dictionary_order")
	_expect(SCHEMA.fingerprint([1, 2]) != SCHEMA.fingerprint([2, 1]), "canonical_sha256_array_order_preserved")

	var first_copy: Dictionary = result.get("spec", {})
	(first_copy["identity"] as Dictionary)["card_id"] = "mutated.copy.rank_1"
	var second_copy: Dictionary = compiler.compile_card_record(card_value, catalog_id).get("spec", {})
	_expect(str((second_copy.get("identity", {}) as Dictionary).get("card_id", "")) != "mutated.copy.rank_1", "compiler_cache_returns_detached_copy")


func _verify_service(card_value: Variant) -> void:
	var packed := load(SERVICE_SCENE_PATH) as PackedScene
	_expect(packed != null, "service_scene_loads")
	if packed == null:
		return
	var service := packed.instantiate() as CardSemanticCatalogService
	root.add_child(service)
	await process_frame
	var summary := service.validation_snapshot()
	_expect(bool(summary.get("configured", false)), "service_configures")
	_expect(int(summary.get("compiled_count", 0)) == 348, "service_compiles_complete_catalog")
	_expect(int(summary.get("active_count", 0)) == 256, "service_active_count")
	_expect(int(summary.get("projection_only_count", 0)) == 92, "service_projection_only_count")
	_expect(int(summary.get("compile_count", 0)) == 348, "service_compiles_once")
	_expect(int(summary.get("cache_entry_count", 0)) == 348, "service_cache_entry_count")
	_expect(not summary.has("card_ids") and not summary.has("specs") and not summary.has("cache"), "service_reports_aggregates_only")
	_expect(not service.has_method("semantic_for_card_id") and not service.has_method("card_ids") and not service.has_method("catalog_snapshot"), "service_has_no_arbitrary_lookup_or_enumeration")

	var envelope := {
		"schema_version": 1,
		"source_kind": "public_rack",
		"source_revision": 9,
		"visibility_scope_id": "public",
		"card_record": (card_value as Dictionary).duplicate(true),
	}
	var first := service.compile_authorized(envelope)
	var second := service.compile_authorized(envelope)
	_expect(bool(first.get("ok", false)) and bool(second.get("ok", false)), "service_authorized_read")
	_expect(bool(first.get("cache_hit", false)) and bool(second.get("cache_hit", false)), "service_authorized_reads_use_cache")
	var first_spec: Dictionary = first.get("spec", {})
	var expected_card_id := str((first_spec.get("identity", {}) as Dictionary).get("card_id", ""))
	(first_spec["identity"] as Dictionary)["card_id"] = "mutated.service.copy.rank_1"
	var third_spec: Dictionary = service.compile_authorized(envelope).get("spec", {})
	_expect(str((third_spec.get("identity", {}) as Dictionary).get("card_id", "")) == expected_card_id, "service_returns_detached_copy")
	var invalid_scope := envelope.duplicate(true)
	invalid_scope["visibility_scope_id"] = "actor_private"
	_expect(not bool(service.compile_authorized(invalid_scope).get("ok", true)), "envelope_scope_mismatch_rejected")
	var extra_envelope := envelope.duplicate(true)
	extra_envelope["card_id"] = expected_card_id
	_expect(not bool(service.compile_authorized(extra_envelope).get("ok", true)), "envelope_arbitrary_card_id_rejected")
	var missing_record := envelope.duplicate(true)
	missing_record.erase("card_record")
	_expect(not bool(service.compile_authorized(missing_record).get("ok", true)), "envelope_missing_record_rejected")
	_expect(int(service.validation_snapshot().get("cache_hit_count", 0)) >= 3, "service_cache_hit_counter")
	service.queue_free()
	await process_frame


func _verify_source_boundaries() -> void:
	var compiler_source := FileAccess.get_file_as_string("res://scripts/cards/semantic/card_semantic_compiler_v1.gd")
	var schema_source := FileAccess.get_file_as_string("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
	var service_source := FileAccess.get_file_as_string("res://scripts/runtime/card_semantic_catalog_service.gd")
	var combined := compiler_source + "\n" + schema_source + "\n" + service_source
	for forbidden in ["randf(", "randi(", "rand_from_seed(", "RunRngService", "scripts/main.gd", "current_scene", "ai_value"]:
		_expect(not combined.contains(forbidden), "source_boundary:%s" % forbidden)
	_expect(not service_source.contains("func _process"), "service_has_no_process_loop")
	_expect(not service_source.contains("to_save_data") and not service_source.contains("apply_save_data"), "service_has_no_save_surface")
	_expect(
		not compiler_source.contains("card_record[\"player\"]")
		and not compiler_source.contains("get(\"player\"")
		and not compiler_source.contains("short_effect")
		and not compiler_source.contains("rules_text"),
		"compiler_does_not_read_localized_player_block"
	)


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Array:
		for item in value:
			if _contains_forbidden_key(item):
				return true
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if FORBIDDEN_OUTPUT_KEYS.has(str(key)) or _contains_forbidden_key((value as Dictionary)[key]):
				return true
	return false


func _contains_non_ascii(value: Variant) -> bool:
	if value is String:
		for index in range(str(value).length()):
			if str(value).unicode_at(index) > 127:
				return true
		return false
	if value is Array:
		for item in value:
			if _contains_non_ascii(item):
				return true
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if _contains_non_ascii(str(key)) or _contains_non_ascii((value as Dictionary)[key]):
				return true
	return false


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


func _expect(condition: bool, failure_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(failure_id)


func _expect_closed_failure(result: Dictionary, failure_id: String) -> void:
	var spec: Dictionary = result.get("spec", {}) if result.get("spec", {}) is Dictionary else {}
	_expect(not bool(result.get("ok", true)) and spec.is_empty() and not spec.has("runtime_readiness_id"), failure_id)


func _finish() -> void:
	var duration_ms := snappedf(float(Time.get_ticks_usec() - _suite_started_usec) / 1000.0, 0.001)
	var compile_ms := snappedf(float(_catalog_compile_usec) / 1000.0, 0.001)
	if _failures.is_empty():
		print("CARD_SEMANTIC_SCHEMA_COMPILER_TEST|status=PASS|checks=%d|failures=0|duration_ms=%.3f|compile_ms=%.3f" % [_checks, duration_ms, compile_ms])
		quit(0)
		return
	print("CARD_SEMANTIC_SCHEMA_COMPILER_TEST|status=FAIL|checks=%d|failures=%d|duration_ms=%.3f|compile_ms=%.3f|details=%s" % [_checks, _failures.size(), duration_ms, compile_ms, JSON.stringify(_failures)])
	quit(1)
