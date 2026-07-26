extends SceneTree

const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const CATALOG_SERVICE_SCENE := preload(
	"res://scenes/runtime/CardSemanticCatalogService.tscn"
)
const ACTIVE_CARD_ID := "commodity.star_dew_berry.rank_1"
const PROJECTION_ONLY_CARD_ID := "interaction.starlink_dismantle.rank_1"

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var service := CATALOG_SERVICE_SCENE.instantiate() as CardSemanticCatalogService
	root.add_child(service)
	await process_frame
	_expect(service != null, "catalog_service_instantiates")
	if service == null:
		_finish()
		return

	var validation := service.validation_snapshot()
	_expect(bool(validation.get("configured", false)), "catalog_service_configured")
	var membership_fingerprint := str(
		validation.get("public_catalog_membership_fingerprint", "")
	)
	_expect(_is_sha256(membership_fingerprint), "membership_fingerprint_available")

	var source_catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(source_catalog != null, "source_catalog_loads")
	if source_catalog == null:
		service.queue_free()
		await process_frame
		_finish()
		return
	var source_report := source_catalog.reload()
	var catalog_snapshot := source_catalog.catalog_snapshot()
	var catalog_id := str(catalog_snapshot.get("catalog_id", ""))
	var cards := catalog_snapshot.get("cards", []) as Array
	_expect(bool(source_report.get("valid", false)), "source_catalog_valid")
	_expect(cards.size() == 348, "single_snapshot_contains_348_cards")

	var active_record: Dictionary = {}
	var active_ordinal := -1
	var projection_record: Dictionary = {}
	var projection_ordinal := -1
	for ordinal in range(cards.size()):
		var record := cards[ordinal] as Dictionary
		var machine := record.get("machine", {}) as Dictionary
		var card_id := str(machine.get("card_id", ""))
		if card_id == ACTIVE_CARD_ID:
			active_record = record.duplicate(true)
			active_ordinal = ordinal
		elif card_id == PROJECTION_ONLY_CARD_ID:
			projection_record = record.duplicate(true)
			projection_ordinal = ordinal
	_expect(not active_record.is_empty(), "active_record_found_in_single_snapshot")
	_expect(
		not projection_record.is_empty(),
		"projection_record_found_in_single_snapshot"
	)

	var metrics_before_all := _cache_metrics(service.validation_snapshot())
	var all_authorized := 0
	var all_receipts_closed := true
	for ordinal in range(cards.size()):
		var record := cards[ordinal] as Dictionary
		var result := service.authorize_public_codex_record(
			_request(catalog_id, membership_fingerprint, ordinal, record)
		)
		if bool(result.get("accepted", false)) \
				and bool(result.get("cache_hit", false)):
			all_authorized += 1
		if not _exact_keys(
			result.get("authorization_receipt", {}) as Dictionary,
			CardSemanticCatalogService.PUBLIC_CODEX_RECEIPT_KEYS
		):
			all_receipts_closed = false
	var metrics_after_all := _cache_metrics(service.validation_snapshot())
	_expect(all_authorized == 348, "all_348_exact_records_authorized")
	_expect(all_receipts_closed, "all_348_receipts_are_closed")
	_expect(
		int(metrics_after_all.get("compile_count", -1))
			== int(metrics_before_all.get("compile_count", -2)),
		"full_catalog_compile_delta_zero"
	)
	_expect(
		int(metrics_after_all.get("cache_hit_count", -1))
			== int(metrics_before_all.get("cache_hit_count", -2)) + 348,
		"full_catalog_requires_348_cache_hits"
	)

	var active_request := _request(
		catalog_id,
		membership_fingerprint,
		active_ordinal,
		active_record
	)
	_expect(
		_exact_keys(
			active_request,
			CardSemanticCatalogService.PUBLIC_CODEX_REQUEST_KEYS
		),
		"request_schema_is_exact"
	)
	var before_active := _cache_metrics(service.validation_snapshot())
	var active_result := service.authorize_public_codex_record(active_request)
	var after_active := _cache_metrics(service.validation_snapshot())
	var active_spec := active_result.get("semantic_spec", {}) as Dictionary
	var active_receipt := active_result.get(
		"authorization_receipt",
		{}
	) as Dictionary
	_expect(
		_exact_keys(
			active_result,
			CardSemanticCatalogService.PUBLIC_CODEX_RESULT_KEYS
		),
		"success_result_schema_is_exact"
	)
	_expect(
		bool(active_result.get("accepted", false))
			and bool(active_result.get("cache_hit", false))
			and str(active_result.get("reason_id", "")) == "authorized",
		"exact_active_record_authorized"
	)
	_expect(
		bool(SCHEMA.validate_semantic_spec(active_spec).get("valid", false))
			and str((active_spec.get("identity", {}) as Dictionary).get(
				"card_id",
				""
			)) == ACTIVE_CARD_ID
			and str(active_spec.get("runtime_readiness_id", "")) == "active",
		"active_catalog_owned_spec_returned"
	)
	_expect(
		_exact_keys(
			active_receipt,
			CardSemanticCatalogService.PUBLIC_CODEX_RECEIPT_KEYS
		)
			and str(active_receipt.get("request_fingerprint", ""))
				== str(active_request.get("request_fingerprint", ""))
			and str(active_receipt.get("semantic_fingerprint", ""))
				== str(active_spec.get("semantic_fingerprint", ""))
			and str(active_receipt.get("runtime_readiness_id", "")) == "active"
			and str(active_receipt.get("receipt_fingerprint", ""))
				== SCHEMA.fingerprint(active_receipt, "receipt_fingerprint"),
		"receipt_binds_request_record_semantic_and_readiness"
	)
	_expect(
		not active_receipt.has("card_record")
			and not active_receipt.has("machine")
			and not active_receipt.has("player")
			and not active_receipt.has("developer"),
		"receipt_does_not_return_catalog_record"
	)
	_expect(
		int(after_active.get("compile_count", -1))
			== int(before_active.get("compile_count", -2))
			and int(after_active.get("cache_hit_count", -1))
				== int(before_active.get("cache_hit_count", -2)) + 1,
		"single_authorization_cache_hit_with_zero_compile_delta"
	)

	var projection_request := _request(
		catalog_id,
		membership_fingerprint,
		projection_ordinal,
		projection_record
	)
	var projection_result := service.authorize_public_codex_record(
		projection_request
	)
	var projection_spec := projection_result.get("semantic_spec", {}) as Dictionary
	_expect(
		bool(projection_result.get("accepted", false))
			and str(projection_spec.get("runtime_readiness_id", ""))
				== "projection_only"
			and str((projection_result.get(
				"authorization_receipt",
				{}
			) as Dictionary).get("runtime_readiness_id", "")) == "projection_only",
		"projection_only_readiness_is_preserved"
	)
	projection_spec["runtime_readiness_id"] = "active"
	var projection_again := service.authorize_public_codex_record(
		projection_request
	)
	_expect(
		str((projection_again.get("semantic_spec", {}) as Dictionary).get(
			"runtime_readiness_id",
			""
		)) == "projection_only",
		"returned_semantic_spec_is_detached"
	)

	_test_record_mutations(
		service,
		catalog_id,
		membership_fingerprint,
		active_ordinal,
		active_record
	)
	_test_stale_identity_and_shape(
		service,
		catalog_id,
		membership_fingerprint,
		active_ordinal,
		active_record
	)

	_expect(
		not service.has_method("authorize_public_codex_card_id")
			and not service.has_method("public_semantic_spec_for_card_id")
			and not service.has_method("public_semantic_catalog_snapshot"),
		"no_arbitrary_id_or_semantic_enumeration_api_added"
	)

	service.queue_free()
	await process_frame
	_finish()


func _test_record_mutations(
	service: CardSemanticCatalogService,
	catalog_id: String,
	membership_fingerprint: String,
	ordinal: int,
	record: Dictionary
) -> void:
	var mutated_records: Array[Dictionary] = []
	var machine_mutation := record.duplicate(true)
	var machine := machine_mutation.get("machine", {}) as Dictionary
	machine["purchase_cash"] = int(machine.get("purchase_cash", 0)) + 1
	mutated_records.append(machine_mutation)
	var player_mutation := record.duplicate(true)
	var player := player_mutation.get("player", {}) as Dictionary
	player["effect"] = str(player.get("effect", "")) + " forged"
	mutated_records.append(player_mutation)
	var developer_mutation := record.duplicate(true)
	var developer := developer_mutation.get("developer", {}) as Dictionary
	developer["effect_review_status"] = "forged"
	mutated_records.append(developer_mutation)

	var metrics_before := _cache_metrics(service.validation_snapshot())
	var all_rejected := true
	for mutated_record in mutated_records:
		var result := service.authorize_public_codex_record(
			_request(
				catalog_id,
				membership_fingerprint,
				ordinal,
				mutated_record
			)
		)
		if bool(result.get("accepted", true)) \
				or not (result.get("semantic_spec", {}) as Dictionary).is_empty() \
				or not (result.get(
					"authorization_receipt",
					{}
				) as Dictionary).is_empty():
			all_rejected = false
	var metrics_after := _cache_metrics(service.validation_snapshot())
	_expect(all_rejected, "machine_player_and_developer_mutations_fail_closed")
	_expect(metrics_before == metrics_after, "record_mutations_do_not_touch_compiler")


func _test_stale_identity_and_shape(
	service: CardSemanticCatalogService,
	catalog_id: String,
	membership_fingerprint: String,
	ordinal: int,
	record: Dictionary
) -> void:
	var base := _request(catalog_id, membership_fingerprint, ordinal, record)
	var cases: Array[Dictionary] = []

	var stale_membership := base.duplicate(true)
	stale_membership["catalog_membership_fingerprint"] = "a".repeat(64)
	_refingerprint(stale_membership)
	cases.append(stale_membership)

	var stale_catalog := base.duplicate(true)
	stale_catalog["source_catalog_id"] = "card.runtime.catalog.v0-6.stale"
	_refingerprint(stale_catalog)
	cases.append(stale_catalog)

	var wrong_ordinal := base.duplicate(true)
	wrong_ordinal["catalog_ordinal"] = ordinal + 1
	_refingerprint(wrong_ordinal)
	cases.append(wrong_ordinal)

	var wrong_id := base.duplicate(true)
	wrong_id["catalog_member_id"] = "commodity.forged.rank_1"
	_refingerprint(wrong_id)
	cases.append(wrong_id)

	var wrong_record_fingerprint := base.duplicate(true)
	wrong_record_fingerprint["source_record_fingerprint"] = "b".repeat(64)
	_refingerprint(wrong_record_fingerprint)
	cases.append(wrong_record_fingerprint)

	var wrong_source := base.duplicate(true)
	wrong_source["source_kind"] = "public_rack"
	_refingerprint(wrong_source)
	cases.append(wrong_source)

	var wrong_visibility := base.duplicate(true)
	wrong_visibility["visibility_scope_id"] = "actor_private"
	_refingerprint(wrong_visibility)
	cases.append(wrong_visibility)

	var forged_authorized := base.duplicate(true)
	forged_authorized["authorized"] = true
	_refingerprint(forged_authorized)
	cases.append(forged_authorized)

	var missing_record := base.duplicate(true)
	missing_record.erase("card_record")
	_refingerprint(missing_record)
	cases.append(missing_record)

	var stale_request_fingerprint := base.duplicate(true)
	stale_request_fingerprint["catalog_ordinal"] = ordinal + 1
	cases.append(stale_request_fingerprint)

	var impure_record := base.duplicate(true)
	var impure_player := (
		(impure_record.get("card_record", {}) as Dictionary).get("player", {})
		as Dictionary
	)
	impure_player["node"] = service
	impure_record["source_record_fingerprint"] = SCHEMA.fingerprint(
		impure_record.get("card_record", {})
	)
	_refingerprint(impure_record)
	cases.append(impure_record)

	var metrics_before := _cache_metrics(service.validation_snapshot())
	var all_closed := true
	for request in cases:
		var result := service.authorize_public_codex_record(request)
		if bool(result.get("accepted", true)) \
				or not _exact_keys(
					result,
					CardSemanticCatalogService.PUBLIC_CODEX_RESULT_KEYS
				) \
				or not (result.get("semantic_spec", {}) as Dictionary).is_empty() \
				or not (result.get(
					"authorization_receipt",
					{}
				) as Dictionary).is_empty():
			all_closed = false
	var metrics_after := _cache_metrics(service.validation_snapshot())
	_expect(all_closed, "stale_identity_shape_and_impure_requests_fail_closed")
	_expect(metrics_before == metrics_after, "invalid_requests_do_not_touch_compiler")


func _request(
	catalog_id: String,
	membership_fingerprint: String,
	ordinal: int,
	record: Dictionary
) -> Dictionary:
	var request := {
		"schema_version": CardSemanticCatalogService.PUBLIC_CODEX_AUTHORIZATION_SCHEMA_VERSION,
		"source_kind": CardSemanticCatalogService.PUBLIC_CODEX_SOURCE_KIND,
		"visibility_scope_id": CardSemanticCatalogService.PUBLIC_CODEX_VISIBILITY_SCOPE_ID,
		"source_catalog_id": catalog_id,
		"catalog_membership_fingerprint": membership_fingerprint,
		"catalog_member_id": str(
			(record.get("machine", {}) as Dictionary).get("card_id", "")
		),
		"catalog_ordinal": ordinal,
		"source_record_fingerprint": SCHEMA.fingerprint(record),
		"card_record": record.duplicate(true),
		"request_fingerprint": "",
	}
	_refingerprint(request)
	return request


func _refingerprint(request: Dictionary) -> void:
	request["request_fingerprint"] = SCHEMA.fingerprint(
		request,
		"request_fingerprint"
	)


func _cache_metrics(snapshot: Dictionary) -> Dictionary:
	return {
		"cache_entry_count": int(snapshot.get("cache_entry_count", -1)),
		"compile_count": int(snapshot.get("compile_count", -1)),
		"cache_hit_count": int(snapshot.get("cache_hit_count", -1)),
		"compile_failure_count": int(snapshot.get("compile_failure_count", -1)),
	}


func _exact_keys(value: Dictionary, expected: Array) -> bool:
	var actual_keys: Array[String] = []
	for key_variant in value.keys():
		actual_keys.append(str(key_variant))
	var expected_keys: Array[String] = []
	for key_variant in expected:
		expected_keys.append(str(key_variant))
	actual_keys.sort()
	expected_keys.sort()
	return actual_keys == expected_keys


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


func _finish() -> void:
	var duration_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	if _failures.is_empty():
		print(
			"CARD_SEMANTIC_CATALOG_PUBLIC_AUTHORIZATION_TEST|status=PASS|checks=%d|failures=0|duration_ms=%.3f"
			% [_checks, duration_ms]
		)
		quit(0)
		return
	print(
		"CARD_SEMANTIC_CATALOG_PUBLIC_AUTHORIZATION_TEST|status=FAIL|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [_checks, _failures.size(), duration_ms, JSON.stringify(_failures)]
	)
	quit(1)
