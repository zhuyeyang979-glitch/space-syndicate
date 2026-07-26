extends SceneTree

const CARD_SCHEMA := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)
const AUTHORIZED_LOCALIZATION := preload(
	"res://scripts/presentation/authorized_card_player_face_localization_source_v1.gd"
)
const CODEX_DTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)
const CATALOG_SERVICE_SCRIPT := preload(
	"res://scripts/runtime/card_semantic_catalog_service.gd"
)
const ADAPTER_SCRIPT := preload(
	"res://scripts/runtime/card_codex_public_source_adapter.gd"
)
const CATALOG_SERVICE_SCENE := preload(
	"res://scenes/runtime/CardSemanticCatalogService.tscn"
)
const PLAYER_FACE_PROJECTION_SCENE := preload(
	"res://scenes/runtime/CardPlayerFaceProjectionService.tscn"
)
const LOCALIZATION_SERVICE_SCENE := preload(
	"res://scenes/runtime/CardPlayerFacePublicLocalizationSourceService.tscn"
)
const SNAPSHOT_SERVICE_SCENE := preload(
	"res://scenes/runtime/CardCodexPublicSnapshotService.tscn"
)

const CATALOG_PATH := \
	"res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const REPRESENTATIVE_CARD_ID := "commodity.star_dew_berry.rank_1"
const FORBIDDEN_OUTPUT_KEYS := [
	"owner",
	"hidden_owner",
	"true_owner",
	"player_index",
	"hand",
	"rival_hand",
	"opponent_hand",
	"exact_cash",
	"private_plan",
	"ai_score",
	"ai_value",
	"route_plan",
	"future_bag",
	"rng_state",
	"save_payload",
	"machine",
	"player",
	"developer",
	"effect_payload",
	"skill",
	"method_name",
	"script_path",
]

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var catalog_service := CATALOG_SERVICE_SCENE.instantiate()
	var localization_service := LOCALIZATION_SERVICE_SCENE.instantiate()
	var projection_service := PLAYER_FACE_PROJECTION_SCENE.instantiate()
	var snapshot_service := SNAPSHOT_SERVICE_SCENE.instantiate()
	root.add_child(catalog_service)
	root.add_child(localization_service)
	root.add_child(projection_service)
	root.add_child(snapshot_service)
	await process_frame

	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(catalog != null, "authoritative v0.6 Card catalog loads")
	if catalog == null:
		await _cleanup_nodes([
			catalog_service,
			localization_service,
			projection_service,
			snapshot_service,
		])
		_finish()
		return
	var catalog_report := catalog.reload()
	var catalog_snapshot := catalog.catalog_snapshot()
	var cards := catalog_snapshot.get("cards", []) as Array
	_expect(
		bool(catalog_report.get("valid", false)) and cards.size() == 348,
		"privacy fixture uses the complete authoritative catalog"
	)

	var record: Dictionary = {}
	var ordinal := -1
	for index in range(cards.size()):
		var candidate := cards[index] as Dictionary
		var machine := candidate.get("machine", {}) as Dictionary
		if str(machine.get("card_id", "")) == REPRESENTATIVE_CARD_ID:
			record = candidate.duplicate(true)
			ordinal = index
			break
	_expect(
		not record.is_empty() and ordinal >= 0,
		"representative public card is selected by stable card_id"
	)

	var catalog_validation: Dictionary = catalog_service.validation_snapshot()
	var authorization: Dictionary = catalog_service.authorize_public_codex_record(
		_public_authorization_request(
			catalog_snapshot,
			catalog_validation,
			ordinal,
			record
		)
	)
	var semantic_spec := authorization.get("semantic_spec", {}) as Dictionary
	_expect(
		bool(authorization.get("accepted", false)) \
			and bool(authorization.get("cache_hit", false)) \
			and not semantic_spec.is_empty(),
		"exact public record yields a catalog-owned semantic spec"
	)

	localization_service.public_catalog_v06 = catalog
	var localization_config: Dictionary = localization_service.configure(
		catalog_service
	)
	_expect(
		bool(localization_config.get("configured", false)) \
			and int(localization_config.get("sealed_bundle_count", 0)) == 348,
		"public localization owner seals all catalog bindings"
	)
	var localization_bundle: Dictionary = localization_service.issue_for_exact_record(
		record.duplicate(true),
		semantic_spec.duplicate(true)
	)
	_expect(
		bool(localization_bundle.get("accepted", false)),
		"exact record and catalog-owned semantic obtain localization attestation"
	)
	var verified: Dictionary = localization_service.verify_bundle(
		localization_bundle.duplicate(true),
		semantic_spec.duplicate(true)
	)
	_expect(
		bool(verified.get("accepted", false)),
		"owner-issued localization bundle verifies"
	)

	var projection: Dictionary = projection_service.project_authorized_public_detail(
		semantic_spec.duplicate(true),
		record.duplicate(true),
		localization_service
	)
	_expect(
		bool(projection.get("accepted", false)),
		"authorized public localization projects one detail PlayerFace"
	)
	var dto := _codex_dto(semantic_spec, projection)
	_expect(
		not dto.is_empty() \
			and bool(CODEX_DTO.validate(dto).get("valid", false)),
		"authorized projection seals one closed PlayerCardCodexDTO"
	)

	_test_record_and_semantic_mutations(
		localization_service,
		record,
		semantic_spec,
		cards
	)
	_test_bundle_forgery(
		localization_service,
		projection_service,
		localization_bundle,
		semantic_spec,
		record
	)
	_test_runtime_value_injections(
		localization_service,
		record,
		semantic_spec
	)
	_test_dto_and_adapter_value_channels(dto)
	_test_projection_outputs(
		dto,
		localization_bundle,
		verified,
		snapshot_service
	)

	catalog_snapshot.clear()
	await _cleanup_nodes([
		catalog_service,
		localization_service,
		projection_service,
		snapshot_service,
	])
	_finish()


func _test_record_and_semantic_mutations(
	localization_service: Node,
	record: Dictionary,
	semantic_spec: Dictionary,
	cards: Array
) -> void:
	var same_id_mutations: Array[Dictionary] = []
	var machine_mutation := record.duplicate(true)
	var machine := machine_mutation.get("machine", {}) as Dictionary
	machine["purchase_cash"] = int(machine.get("purchase_cash", 0)) + 1
	same_id_mutations.append(machine_mutation)

	var player_mutation := record.duplicate(true)
	var player := player_mutation.get("player", {}) as Dictionary
	player["effect"] = "%s forged" % str(player.get("effect", ""))
	same_id_mutations.append(player_mutation)

	var developer_mutation := record.duplicate(true)
	var developer := developer_mutation.get("developer", {}) as Dictionary
	developer["privacy_test_injection"] = true
	same_id_mutations.append(developer_mutation)

	var wrong_family := record.duplicate(true)
	(wrong_family.get("machine", {}) as Dictionary)["family_id"] = \
		"commodity.forged_family"
	same_id_mutations.append(wrong_family)

	var wrong_rank := record.duplicate(true)
	(wrong_rank.get("machine", {}) as Dictionary)["rank"] = 4
	same_id_mutations.append(wrong_rank)

	var all_same_id_mutations_rejected := true
	for mutated_record in same_id_mutations:
		var result: Dictionary = localization_service.issue_for_exact_record(
			mutated_record,
			semantic_spec.duplicate(true)
		)
		if not _closed_issue_rejection(result):
			all_same_id_mutations_rejected = false
	_expect(
		all_same_id_mutations_rejected,
		"same-ID machine/player/developer and family/rank mutations fail closed"
	)

	var foreign_record: Dictionary = {}
	for candidate_variant in cards:
		var candidate := candidate_variant as Dictionary
		var candidate_id := str(
			(candidate.get("machine", {}) as Dictionary).get("card_id", "")
		)
		if candidate_id != REPRESENTATIVE_CARD_ID:
			foreign_record = candidate.duplicate(true)
			break
	var foreign_result: Dictionary = localization_service.issue_for_exact_record(
		foreign_record,
		semantic_spec.duplicate(true)
	)
	_expect(
		_closed_issue_rejection(foreign_result),
		"foreign exact record cannot borrow another card's semantic binding"
	)

	var wrong_semantic_family := semantic_spec.duplicate(true)
	(wrong_semantic_family.get("identity", {}) as Dictionary)["family_id"] = \
		"commodity.forged_family"
	var wrong_semantic_rank := semantic_spec.duplicate(true)
	(wrong_semantic_rank.get("identity", {}) as Dictionary)["rank"] = 4
	for mutated_semantic in [wrong_semantic_family, wrong_semantic_rank]:
		_expect(
			_closed_issue_rejection(
				localization_service.issue_for_exact_record(
					record.duplicate(true),
					mutated_semantic
				)
			),
			"wrong semantic family/rank fails closed"
		)


func _test_bundle_forgery(
	localization_service: Node,
	projection_service: Node,
	bundle: Dictionary,
	semantic_spec: Dictionary,
	record: Dictionary
) -> void:
	var forged_authorized := bundle.duplicate(true)
	forged_authorized["authorized"] = true
	_expect(
		_closed_verification_rejection(
			localization_service.verify_bundle(
				forged_authorized,
				semantic_spec.duplicate(true)
			)
		),
		"caller-forged authorized=true is rejected"
	)
	_expect(
		not bool(projection_service.project_authorized_public_detail(
			semantic_spec.duplicate(true),
			forged_authorized,
			localization_service
		).get("accepted", false)),
		"production projection cannot consume caller-forged authorization"
	)
	var resigned_semantic := semantic_spec.duplicate(true)
	resigned_semantic["runtime_readiness_id"] = "projection_only" \
		if str(semantic_spec.get("runtime_readiness_id", "")) != "projection_only" \
		else "active"
	resigned_semantic["semantic_fingerprint"] = CARD_SCHEMA.fingerprint(
		resigned_semantic,
		"semantic_fingerprint"
	)
	_expect(
		not bool(projection_service.project_authorized_public_detail(
			resigned_semantic,
			record.duplicate(true),
			localization_service
		).get("accepted", false)),
		"production projection revalidates caller-resigned semantic through the owner"
	)
	_expect(
		not bool(projection_service.project_authorized_public_detail(
			semantic_spec.duplicate(true),
			record.duplicate(true),
			null
		).get("accepted", false)),
		"production projection rejects a missing localization owner"
	)

	var mutation_cases: Array[Dictionary] = []
	var stale_revision := bundle.duplicate(true)
	var stale_source := stale_revision.get("localization_source", {}) as Dictionary
	(stale_source.get("source_binding", {}) as Dictionary)["source_revision"] = 2
	mutation_cases.append(_resign_bundle(stale_revision))

	var wrong_semantic_fingerprint := bundle.duplicate(true)
	var wrong_semantic_source := wrong_semantic_fingerprint.get(
		"localization_source",
		{}
	) as Dictionary
	(wrong_semantic_source.get("semantic_binding", {}) as Dictionary)[
		"semantic_fingerprint"
	] = "a".repeat(64)
	mutation_cases.append(_resign_bundle(wrong_semantic_fingerprint))

	var wrong_family := bundle.duplicate(true)
	var wrong_family_source := wrong_family.get("localization_source", {}) as Dictionary
	(wrong_family_source.get("source_binding", {}) as Dictionary)["family_id"] = \
		"commodity.forged_family"
	mutation_cases.append(_resign_bundle(wrong_family))

	var wrong_rank := bundle.duplicate(true)
	var wrong_rank_source := wrong_rank.get("localization_source", {}) as Dictionary
	(wrong_rank_source.get("source_binding", {}) as Dictionary)["rank"] = 4
	mutation_cases.append(_resign_bundle(wrong_rank))

	var wrong_scope := bundle.duplicate(true)
	var wrong_scope_source := wrong_scope.get("localization_source", {}) as Dictionary
	(wrong_scope_source.get("source_binding", {}) as Dictionary)[
		"visibility_scope_id"
	] = "actor_private"
	mutation_cases.append(_resign_bundle(wrong_scope))

	var raw_text_id := bundle.duplicate(true)
	var raw_text_source := raw_text_id.get("localization_source", {}) as Dictionary
	(raw_text_source.get("structural_message_ids", {}) as Dictionary)["name"] = \
		"Localized Card Name"
	mutation_cases.append(_resign_bundle(raw_text_id))

	var duplicate_keyword := bundle.duplicate(true)
	var duplicate_source := duplicate_keyword.get(
		"localization_source",
		{}
	) as Dictionary
	var keyword_rows := duplicate_source.get("keyword_rows", []) as Array
	if keyword_rows.size() >= 2:
		(keyword_rows[1] as Dictionary)["keyword_id"] = str(
			(keyword_rows[0] as Dictionary).get("keyword_id", "")
		)
	mutation_cases.append(_resign_bundle(duplicate_keyword))

	var all_resigned_forgery_rejected := true
	for forged_bundle in mutation_cases:
		var result: Dictionary = localization_service.verify_bundle(
			forged_bundle,
			semantic_spec.duplicate(true)
		)
		if not _closed_verification_rejection(result):
			all_resigned_forgery_rejected = false
	_expect(
		all_resigned_forgery_rejected,
		"stale/wrong binding, raw text ID, duplicate keyword, and re-signed forgery fail closed"
	)

	for fingerprint_path in [
		"source_manifest_fingerprint",
		"receipt_fingerprint",
		"bundle_fingerprint",
	]:
		var stale := bundle.duplicate(true)
		if fingerprint_path == "source_manifest_fingerprint":
			(stale.get("localization_source", {}) as Dictionary)[fingerprint_path] = \
				"b".repeat(64)
		elif fingerprint_path == "receipt_fingerprint":
			(stale.get("authorization_receipt", {}) as Dictionary)[fingerprint_path] = \
				"b".repeat(64)
		else:
			stale[fingerprint_path] = "b".repeat(64)
		_expect(
			_closed_verification_rejection(
				localization_service.verify_bundle(
					stale,
					semantic_spec.duplicate(true)
				)
			),
			"stale fingerprint fails closed: %s" % fingerprint_path
		)

	var raw_message_result: Dictionary = localization_service.resolve_at_presentation(
		bundle.duplicate(true),
		semantic_spec.duplicate(true),
		{"message_id": "Localized Card Name", "args": []}
	)
	_expect(
		not bool(raw_message_result.get("accepted", false)) \
			and str(raw_message_result.get("text", "")).is_empty(),
		"raw localized text cannot act as a message ID"
	)

	var localization_source := bundle.get("localization_source", {}) as Dictionary
	var structural_ids := localization_source.get("structural_message_ids", {}) \
		as Dictionary
	var issued_name_id := str(structural_ids.get("name", ""))
	var all_value_channel_args_rejected := true
	for forbidden_key in FORBIDDEN_OUTPUT_KEYS:
		var injected_result: Dictionary = localization_service.resolve_at_presentation(
			bundle.duplicate(true),
			semantic_spec.duplicate(true),
			{
				"message_id": issued_name_id,
				"args": [{
					"arg_id": forbidden_key,
					"type_id": "stable_id",
					"value": "private.value",
				}],
			}
		)
		if bool(injected_result.get("accepted", false)):
			all_value_channel_args_rejected = false
	_expect(
		all_value_channel_args_rejected,
		"issued message IDs reject hidden and private value-channel args"
	)
	var runtime_arg_node := Node.new()
	var runtime_arg_result: Dictionary = localization_service.resolve_at_presentation(
		bundle.duplicate(true),
		semantic_spec.duplicate(true),
		{
			"message_id": issued_name_id,
			"args": [{
				"arg_id": "card_id",
				"type_id": "stable_id",
				"value": runtime_arg_node,
			}],
		}
	)
	_expect(
		not bool(runtime_arg_result.get("accepted", false)),
		"issued message IDs reject runtime-object args"
	)
	runtime_arg_node.free()


func _test_runtime_value_injections(
	localization_service: Node,
	record: Dictionary,
	semantic_spec: Dictionary
) -> void:
	var runtime_node := Node.new()
	var runtime_values: Array = [
		runtime_node,
		Resource.new(),
		Callable(self, "_run"),
	]
	var all_rejected := true
	for runtime_value in runtime_values:
		var impure_record := record.duplicate(true)
		(impure_record.get("player", {}) as Dictionary)["runtime_value"] = \
			runtime_value
		var result: Dictionary = localization_service.issue_for_exact_record(
			impure_record,
			semantic_spec.duplicate(true)
		)
		if not _closed_issue_rejection(result):
			all_rejected = false
	_expect(
		all_rejected,
		"Node, Resource, and Callable source injections fail closed"
	)
	runtime_node.free()


func _test_dto_and_adapter_value_channels(dto: Dictionary) -> void:
	var adapter := ADAPTER_SCRIPT.new()
	var all_dto_rejected := true
	var all_adapter_rejected := true
	for forbidden_key in FORBIDDEN_OUTPUT_KEYS:
		var unsealed := dto.duplicate(true)
		unsealed.erase("dto_fingerprint")
		(unsealed.get("presentation_copy", {}) as Dictionary)[forbidden_key] = \
			"injected"
		if not CODEX_DTO.seal(unsealed).is_empty():
			all_dto_rejected = false
		if bool(adapter.accepts_public_input({forbidden_key: "injected"})):
			all_adapter_rejected = false
	_expect(
		all_dto_rejected,
		"PlayerCardCodexDTO rejects every hidden/value-channel field"
	)
	_expect(
		all_adapter_rejected,
		"Codex compatibility adapter rejects every hidden/value-channel field"
	)

	for runtime_value in [Resource.new(), Callable(self, "_run")]:
		var unsealed := dto.duplicate(true)
		unsealed.erase("dto_fingerprint")
		(unsealed.get("presentation_copy", {}) as Dictionary)["name"] = \
			runtime_value
		_expect(
			CODEX_DTO.seal(unsealed).is_empty() \
				and not bool(adapter.accepts_public_input({"value": runtime_value})),
			"DTO and adapter reject runtime object values"
		)


func _test_projection_outputs(
	dto: Dictionary,
	bundle: Dictionary,
	verified: Dictionary,
	snapshot_service: Node
) -> void:
	var adapter := ADAPTER_SCRIPT.new()
	var facts := adapter.compose_card_facts(dto.duplicate(true), 0, {})
	_expect(not facts.is_empty(), "DTO-only adapter produces public Card facts")

	var filter_row := {
		"id": "all",
		"label": "All",
		"short_label": "All",
		"icon": "",
		"count": 1,
		"active": true,
		"disabled": false,
		"accent": Color("#93c5fd"),
	}
	var browser_request := {
		"names": [REPRESENTATIVE_CARD_ID],
		"columns": 1,
		"rows": 1,
		"page_index": 0,
		"filter_id": "all",
		"filter_label": "All",
		"selected_card": REPRESENTATIVE_CARD_ID,
		"icon_legend": "Public Card taxonomy",
		"run_pool_count": 0,
		"district_supply_count": 0,
		"filters": [filter_row],
	}
	var browser_source := adapter.compose_browser_source(
		browser_request,
		[facts],
		facts,
		[filter_row]
	)
	var detail_source := adapter.compose_detail_source(facts, [], 1)
	snapshot_service.configure({})
	var browser_snapshot: Dictionary = snapshot_service.compose_browser(browser_source)
	var detail_snapshot: Dictionary = snapshot_service.compose_detail(detail_source)
	_expect(
		not browser_snapshot.is_empty() and not detail_snapshot.is_empty(),
		"DTO-only compatibility inputs compose browser and detail snapshots"
	)

	var public_outputs := {
		"localization_bundle": bundle,
		"verified_localization": verified,
		"codex_dto": dto,
		"adapter_facts": facts,
		"browser_snapshot": browser_snapshot,
		"detail_snapshot": detail_snapshot,
	}
	var forbidden_hits: Array[String] = []
	_collect_forbidden_keys(public_outputs, "output", forbidden_hits)
	_expect(
		forbidden_hits.is_empty(),
		"authorized DTO and public snapshots contain no raw/private blocks: %s"
			% [forbidden_hits]
	)
	_expect(
		not _contains_runtime_value(public_outputs),
		"authorized DTO and public snapshots contain no Object/Callable/Resource"
	)


func _public_authorization_request(
	catalog_snapshot: Dictionary,
	validation: Dictionary,
	ordinal: int,
	record: Dictionary
) -> Dictionary:
	var request := {
		"schema_version": CATALOG_SERVICE_SCRIPT.PUBLIC_CODEX_AUTHORIZATION_SCHEMA_VERSION,
		"source_kind": CATALOG_SERVICE_SCRIPT.PUBLIC_CODEX_SOURCE_KIND,
		"visibility_scope_id": CATALOG_SERVICE_SCRIPT.PUBLIC_CODEX_VISIBILITY_SCOPE_ID,
		"source_catalog_id": str(catalog_snapshot.get("catalog_id", "")),
		"catalog_membership_fingerprint": str(
			validation.get("public_catalog_membership_fingerprint", "")
		),
		"catalog_member_id": str(
			(record.get("machine", {}) as Dictionary).get("card_id", "")
		),
		"catalog_ordinal": ordinal,
		"source_record_fingerprint": CARD_SCHEMA.fingerprint(record),
		"card_record": record.duplicate(true),
		"request_fingerprint": "",
	}
	request["request_fingerprint"] = CARD_SCHEMA.fingerprint(
		request,
		"request_fingerprint"
	)
	return request


func _codex_dto(
	semantic_spec: Dictionary,
	projection: Dictionary
) -> Dictionary:
	return CODEX_DTO.seal({
		"schema_version": CODEX_DTO.SCHEMA_VERSION,
		"projection_id": CODEX_DTO.PROJECTION_ID,
		"semantic_binding": {
			"source_catalog_id": str(
				semantic_spec.get("source_catalog_id", "")
			),
			"source_definition_fingerprint": str(
				semantic_spec.get("source_definition_fingerprint", "")
			),
			"semantic_fingerprint": str(
				semantic_spec.get("semantic_fingerprint", "")
			),
		},
		"localization_binding": (
			projection.get("localization_binding", {}) as Dictionary
		).duplicate(true),
		"detail_face": (
			projection.get("detail_face", {}) as Dictionary
		).duplicate(true),
		"taxonomy": (
			projection.get("taxonomy", {}) as Dictionary
		).duplicate(true),
		"presentation_tokens": (
			projection.get("presentation_tokens", {}) as Dictionary
		).duplicate(true),
		"presentation_copy": (
			projection.get("presentation_copy", {}) as Dictionary
		).duplicate(true),
	})


func _resign_bundle(bundle: Dictionary) -> Dictionary:
	if bundle.is_empty():
		return {}
	var source := (bundle.get("localization_source", {}) as Dictionary).duplicate(true)
	source.erase("source_manifest_fingerprint")
	var sealed_source := AUTHORIZED_LOCALIZATION.seal_localization_source(source)
	if sealed_source.is_empty():
		return {}
	var source_binding := sealed_source.get("source_binding", {}) as Dictionary
	var semantic_binding := sealed_source.get("semantic_binding", {}) as Dictionary
	var receipt := (bundle.get("authorization_receipt", {}) as Dictionary).duplicate(true)
	receipt.erase("receipt_fingerprint")
	receipt["source_id"] = str(source_binding.get("source_id", ""))
	receipt["source_revision"] = int(source_binding.get("source_revision", 0))
	receipt["source_fingerprint"] = str(
		sealed_source.get("source_manifest_fingerprint", "")
	)
	receipt["semantic_fingerprint"] = str(
		semantic_binding.get("semantic_fingerprint", "")
	)
	var sealed_receipt := AUTHORIZED_LOCALIZATION.build_receipt(receipt)
	if sealed_receipt.is_empty():
		return {}
	return AUTHORIZED_LOCALIZATION.build_issue_result(
		sealed_source,
		sealed_receipt
	)


func _closed_issue_rejection(result: Dictionary) -> bool:
	return not bool(result.get("accepted", true)) \
		and (result.get("localization_source", {}) as Dictionary).is_empty() \
		and (result.get("authorization_receipt", {}) as Dictionary).is_empty() \
		and str(result.get("bundle_fingerprint", "")).is_empty()


func _closed_verification_rejection(result: Dictionary) -> bool:
	return not bool(result.get("accepted", true)) \
		and (result.get("projection_source", {}) as Dictionary).is_empty() \
		and (result.get("localization_binding", {}) as Dictionary).is_empty() \
		and (result.get("presentation_copy", {}) as Dictionary).is_empty() \
		and (result.get("authorization_receipt", {}) as Dictionary).is_empty() \
		and str(result.get("bundle_fingerprint", "")).is_empty()


func _collect_forbidden_keys(
	value: Variant,
	path: String,
	hits: Array[String]
) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			var child_path := "%s.%s" % [path, key]
			if FORBIDDEN_OUTPUT_KEYS.has(key):
				hits.append(child_path)
			_collect_forbidden_keys(
				(value as Dictionary).get(key_variant),
				child_path,
				hits
			)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_forbidden_keys(
				(value as Array)[index],
				"%s[%d]" % [path, index],
				hits
			)


func _contains_runtime_value(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return true
	if value is Dictionary:
		for child in (value as Dictionary).values():
			if _contains_runtime_value(child):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_runtime_value(child):
				return true
	return false


func _cleanup_nodes(nodes: Array) -> void:
	for node_variant in nodes:
		if node_variant is Node and is_instance_valid(node_variant):
			(node_variant as Node).free()
	await process_frame


func _expect(condition: bool, failure_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(failure_id)


func _finish() -> void:
	var duration_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"CARD_CODEX_PLAYERFACE_PRIVACY_TEST|status=%s|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [
			status,
			_checks,
			_failures.size(),
			duration_ms,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
