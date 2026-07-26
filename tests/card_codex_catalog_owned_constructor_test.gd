extends SceneTree

const SEMANTIC_SCENE := preload(
	"res://scenes/runtime/CardSemanticCatalogService.tscn"
)
const LOCALIZATION_SCENE := preload(
	"res://scenes/runtime/CardPlayerFacePublicLocalizationSourceService.tscn"
)
const PROJECTION_SCENE := preload(
	"res://scenes/runtime/CardPlayerFaceProjectionService.tscn"
)
const SNAPSHOT_SCENE := preload(
	"res://scenes/runtime/CardCodexPublicSnapshotService.tscn"
)
const SOURCE_SCENE := preload(
	"res://scenes/runtime/CardCodexPublicSourceService.tscn"
)
const CODEX_DTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)
const LADDER_DTO := preload(
	"res://scripts/presentation/player_card_codex_family_ladder_dto_v1.gd"
)

const EXPECTED_FAST_CONSTRUCTOR_OWNER := \
	"res://scripts/runtime/card_codex_public_source_service.gd"
const FORBIDDEN_OR_PRIVATE_KEYS := [
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
var _owned_nodes: Array[Node] = []
var _catalog_dto: Dictionary = {}
var _catalog_ladder: Dictionary = {}


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	await _load_catalog_owned_samples()
	if not _catalog_dto.is_empty() and not _catalog_ladder.is_empty():
		_test_codex_fast_constructor_positive_contract()
		_test_codex_closed_and_bound_contract()
		_test_codex_detail_face_contract()
		_test_codex_presentation_contract()
		_test_codex_detached_value_contract()
		_test_ladder_fast_constructor_positive_contract()
		_test_ladder_nested_entry_contract()
		_test_ordinary_contract_unchanged()
	_test_production_call_sites_are_narrow()
	await _cleanup()
	_finish()


func _load_catalog_owned_samples() -> void:
	var semantic: Node = SEMANTIC_SCENE.instantiate()
	var localization: Node = LOCALIZATION_SCENE.instantiate()
	var projection: Node = PROJECTION_SCENE.instantiate()
	var snapshot: Node = SNAPSHOT_SCENE.instantiate()
	var source: Node = SOURCE_SCENE.instantiate()
	for node in [semantic, localization, projection, snapshot, source]:
		if node != null:
			_owned_nodes.append(node)
	_expect(
		semantic != null and localization != null and projection != null
			and snapshot != null and source != null,
		"production Codex services instantiate for catalog-owned samples"
	)
	if semantic == null or localization == null or projection == null \
			or snapshot == null or source == null:
		return

	semantic.set("configure_on_ready", false)
	for node in _owned_nodes:
		root.add_child(node)
	await process_frame

	snapshot.call("configure", {})
	var semantic_configuration := semantic.call("configure") as Dictionary
	var localization_configuration := localization.call(
		"configure",
		semantic
	) as Dictionary
	var source_configuration := source.call("configure", {
		"player_face_projection": projection,
		"public_localization_source": localization,
		"semantic_catalog": semantic,
		"snapshot": snapshot,
	}) as Dictionary
	_expect(
		bool(semantic_configuration.get("configured", false))
			and bool(localization_configuration.get("configured", false))
			and bool(source_configuration.get("service_ready", false)),
		"production chain yields catalog-owned DTO and ladder caches"
	)
	if not bool(source_configuration.get("service_ready", false)):
		return

	var ordered_ids_value: Variant = source.call("ordered_card_ids", "all")
	var ordered_ids: Array = ordered_ids_value as Array \
		if ordered_ids_value is Array else []
	var dto_cache_value: Variant = source.get("_dto_by_card_id")
	var dto_cache: Dictionary = dto_cache_value as Dictionary \
		if dto_cache_value is Dictionary else {}
	var ladder_cache_value: Variant = source.get("_ladder_by_family_id")
	var ladder_cache: Dictionary = ladder_cache_value as Dictionary \
		if ladder_cache_value is Dictionary else {}
	_expect(
		ordered_ids.size() == 348 and dto_cache.size() == 348
			and ladder_cache.size() == 87,
		"production source exposes the expected 348 DTO and 87 ladder caches"
	)
	if ordered_ids.is_empty():
		return

	var card_id := str(ordered_ids[0])
	var dto_value: Variant = dto_cache.get(card_id)
	if not (dto_value is Dictionary):
		_expect(false, "first catalog-owned DTO exists")
		return
	_catalog_dto = (dto_value as Dictionary).duplicate(true)
	var detail_value: Variant = _catalog_dto.get("detail_face")
	var detail_face: Dictionary = detail_value as Dictionary \
		if detail_value is Dictionary else {}
	var family_id := str(detail_face.get("family_id", ""))
	var ladder_value: Variant = ladder_cache.get(family_id)
	if ladder_value is Dictionary:
		_catalog_ladder = (ladder_value as Dictionary).duplicate(true)
	_expect(
		bool(CODEX_DTO.validate(_catalog_dto).get("valid", false))
			and bool(LADDER_DTO.validate(_catalog_ladder).get("valid", false)),
		"production samples pass the full standard validators"
	)


func _test_codex_fast_constructor_positive_contract() -> void:
	var unsealed := _unsealed_dto()
	var first := CODEX_DTO.seal_catalog_owned(unsealed)
	var second := CODEX_DTO.seal_catalog_owned(_unsealed_dto())
	var ordinary := CODEX_DTO.seal(_unsealed_dto())
	_expect(not first.is_empty(), "catalog-owned DTO fast constructor accepts valid input")
	_expect(
		bool(CODEX_DTO.validate(first).get("valid", false)),
		"catalog-owned DTO fast output passes the full standard validator"
	)
	_expect(
		str(first.get("dto_fingerprint", ""))
			== str(second.get("dto_fingerprint", "")),
		"catalog-owned DTO fast fingerprint is deterministic"
	)
	_expect(
		str(first.get("dto_fingerprint", ""))
			== str(ordinary.get("dto_fingerprint", "")),
		"fast and ordinary DTO constructors seal identical bytes"
	)
	unsealed["presentation_copy"]["name"] = "caller mutation"
	_expect(
		str(first["presentation_copy"]["name"]) != "caller mutation",
		"catalog-owned DTO fast output is deeply detached"
	)


func _test_codex_closed_and_bound_contract() -> void:
	var unknown_root := _unsealed_dto()
	unknown_root["unknown_root"] = true
	_expect_dto_rejected(unknown_root, "unknown DTO root key")

	var unknown_binding := _unsealed_dto()
	unknown_binding["semantic_binding"]["unknown_binding"] = true
	_expect_dto_rejected(unknown_binding, "unknown semantic binding key")

	var semantic_malformed := _unsealed_dto()
	semantic_malformed["semantic_binding"]["semantic_fingerprint"] = "not-a-fingerprint"
	_expect_dto_rejected(semantic_malformed, "malformed semantic fingerprint")

	var localization_malformed := _unsealed_dto()
	localization_malformed["localization_binding"]["source_fingerprint"] = \
		"not-a-fingerprint"
	_expect_dto_rejected(localization_malformed, "malformed localization fingerprint")

	var binding_mismatch := _unsealed_dto()
	binding_mismatch["localization_binding"]["semantic_fingerprint"] = \
		_different_fingerprint(str(
			binding_mismatch["semantic_binding"]["semantic_fingerprint"]
		))
	_expect_dto_rejected(binding_mismatch, "semantic/localization fingerprint mismatch")

	for forbidden_key_variant in FORBIDDEN_OR_PRIVATE_KEYS:
		var forbidden_key := str(forbidden_key_variant)
		var injected := _unsealed_dto()
		injected["detail_face"][forbidden_key] = "injected"
		_expect_dto_rejected(
			injected,
			"forbidden or private nested key %s" % forbidden_key
		)


func _test_codex_detail_face_contract() -> void:
	var unknown_detail_key := _unsealed_dto()
	unknown_detail_key["detail_face"]["catalog_note"] = "not schema"
	_expect_dto_rejected(unknown_detail_key, "unknown detail-face key")

	var wrong_surface := _unsealed_dto()
	wrong_surface["detail_face"]["surface_id"] = "market"
	_expect_dto_rejected(wrong_surface, "non-detail PlayerFace surface")

	var invalid_card_id := _unsealed_dto()
	invalid_card_id["detail_face"]["card_id"] = "localized card name"
	_expect_dto_rejected(invalid_card_id, "localized or unstable detail card identity")

	var invalid_family_id := _unsealed_dto()
	invalid_family_id["detail_face"]["family_id"] = ""
	_expect_dto_rejected(invalid_family_id, "empty detail family identity")

	for invalid_rank in [0, 5, "1", 1.5]:
		var wrong_rank := _unsealed_dto()
		wrong_rank["detail_face"]["rank"] = invalid_rank
		_expect_dto_rejected(
			wrong_rank,
			"invalid detail rank %s (%s)" % [str(invalid_rank), type_string(typeof(invalid_rank))]
		)

	var missing_nested_fingerprint := _unsealed_dto()
	missing_nested_fingerprint["detail_face"].erase("dto_fingerprint")
	_expect_dto_rejected(
		missing_nested_fingerprint,
		"missing nested PlayerFace fingerprint"
	)

	var forged_nested_fingerprint := _unsealed_dto()
	forged_nested_fingerprint["detail_face"]["dto_fingerprint"] = \
		_different_fingerprint(str(
			forged_nested_fingerprint["detail_face"]["dto_fingerprint"]
		))
	_expect_dto_rejected(
		forged_nested_fingerprint,
		"forged nested PlayerFace fingerprint"
	)

	var stale_nested_fingerprint := _unsealed_dto()
	stale_nested_fingerprint["detail_face"]["card_id"] = "card.forged.rank_1"
	_expect_dto_rejected(
		stale_nested_fingerprint,
		"detail identity mutation with stale nested fingerprint"
	)


func _test_codex_presentation_contract() -> void:
	var taxonomy_extra := _unsealed_dto()
	taxonomy_extra["taxonomy"]["category_alias"] = "legacy"
	_expect_dto_rejected(taxonomy_extra, "unknown taxonomy key")

	var taxonomy_invalid := _unsealed_dto()
	taxonomy_invalid["taxonomy"]["category_id"] = "Localized Category"
	_expect_dto_rejected(taxonomy_invalid, "unstable taxonomy identity")

	var token_extra := _unsealed_dto()
	token_extra["presentation_tokens"]["raw_color"] = "#ffffff"
	_expect_dto_rejected(token_extra, "unknown presentation token key")

	var token_invalid := _unsealed_dto()
	token_invalid["presentation_tokens"]["illustration_key"] = "res://card.png"
	_expect_dto_rejected(token_invalid, "resource path as illustration token")

	var copy_extra := _unsealed_dto()
	copy_extra["presentation_copy"]["strategy_route"] = "guess"
	_expect_dto_rejected(copy_extra, "unknown presentation-copy key")

	var copy_missing := _unsealed_dto()
	copy_missing["presentation_copy"].erase("full_effect")
	_expect_dto_rejected(copy_missing, "missing presentation-copy field")

	var copy_blank := _unsealed_dto()
	copy_blank["presentation_copy"]["name"] = "   "
	_expect_dto_rejected(copy_blank, "blank presentation text")

	var copy_non_string := _unsealed_dto()
	copy_non_string["presentation_copy"]["effect_steps"] = [7]
	_expect_dto_rejected(copy_non_string, "non-string presentation array item")

	var copy_count_mismatch := _unsealed_dto()
	copy_count_mismatch["presentation_copy"]["effect_steps"].append("extra step")
	_expect_dto_rejected(copy_count_mismatch, "presentation/detail effect count mismatch")


func _test_codex_detached_value_contract() -> void:
	var object_value := Node.new()
	var object_injected := _unsealed_dto()
	object_injected["presentation_copy"]["name"] = object_value
	_expect_dto_rejected(object_injected, "Object value")
	object_value.free()

	var callable_injected := _unsealed_dto()
	callable_injected["presentation_copy"]["name"] = Callable(self, "_run")
	_expect_dto_rejected(callable_injected, "Callable value")

	for nonfinite_value in [INF, -INF, NAN]:
		var nonfinite_injected := _unsealed_dto()
		nonfinite_injected["presentation_copy"]["name"] = nonfinite_value
		_expect_dto_rejected(
			nonfinite_injected,
			"nonfinite value %s" % str(nonfinite_value)
		)


func _test_ladder_fast_constructor_positive_contract() -> void:
	var unsealed := _unsealed_ladder()
	var first := LADDER_DTO.seal_catalog_owned(unsealed)
	var second := LADDER_DTO.seal_catalog_owned(_unsealed_ladder())
	var ordinary := LADDER_DTO.seal(_unsealed_ladder())
	_expect(not first.is_empty(), "catalog-owned ladder fast constructor accepts valid input")
	_expect(
		bool(LADDER_DTO.validate(first).get("valid", false)),
		"catalog-owned ladder fast output passes the full standard validator"
	)
	_expect(
		str(first.get("ladder_fingerprint", ""))
			== str(second.get("ladder_fingerprint", "")),
		"catalog-owned ladder fast fingerprint is deterministic"
	)
	_expect(
		str(first.get("ladder_fingerprint", ""))
			== str(ordinary.get("ladder_fingerprint", "")),
		"fast and ordinary ladder constructors seal identical bytes"
	)
	unsealed["entries"][0]["presentation_copy"]["name"] = "caller mutation"
	_expect(
		str(first["entries"][0]["presentation_copy"]["name"])
			!= "caller mutation",
		"catalog-owned ladder fast output is deeply detached"
	)


func _test_ladder_nested_entry_contract() -> void:
	var unknown_root := _unsealed_ladder()
	unknown_root["unknown_root"] = true
	_expect_ladder_rejected(unknown_root, "unknown ladder root key")

	var wrong_size := _unsealed_ladder()
	wrong_size["entries"].pop_back()
	_expect_ladder_rejected(wrong_size, "ladder without exactly four ranks")

	var wrong_family := _unsealed_ladder()
	wrong_family["family_id"] = "other.family"
	_expect_ladder_rejected(wrong_family, "ladder family mismatch")

	var wrong_order := _unsealed_ladder()
	var ordered_entries := wrong_order["entries"] as Array
	var first_entry: Variant = ordered_entries[0]
	ordered_entries[0] = ordered_entries[1]
	ordered_entries[1] = first_entry
	_expect_ladder_rejected(wrong_order, "ladder rank order mutation")

	var duplicate := _unsealed_ladder()
	var duplicate_entries := duplicate["entries"] as Array
	var duplicated_entry := (duplicate_entries[0] as Dictionary).duplicate(true)
	duplicated_entry["detail_face"]["rank"] = 2
	duplicate_entries[1] = duplicated_entry
	_expect_ladder_rejected(duplicate, "duplicate card identity across ladder ranks")

	var rank_wrong_type := _unsealed_ladder()
	rank_wrong_type["entries"][0]["detail_face"]["rank"] = "1"
	_expect_ladder_rejected(rank_wrong_type, "non-integer nested ladder rank")

	var entry_unknown_key := _unsealed_ladder()
	entry_unknown_key["entries"][0]["catalog_note"] = "not schema"
	_expect_ladder_rejected(entry_unknown_key, "unknown nested Codex DTO key")

	var missing_entry_fingerprint := _unsealed_ladder()
	missing_entry_fingerprint["entries"][0].erase("dto_fingerprint")
	_expect_ladder_rejected(missing_entry_fingerprint, "missing nested Codex DTO fingerprint")

	var forged_entry_fingerprint := _unsealed_ladder()
	forged_entry_fingerprint["entries"][0]["dto_fingerprint"] = \
		_different_fingerprint(str(
			forged_entry_fingerprint["entries"][0]["dto_fingerprint"]
		))
	_expect_ladder_rejected(forged_entry_fingerprint, "forged nested Codex DTO fingerprint")

	var stale_entry_fingerprint := _unsealed_ladder()
	stale_entry_fingerprint["entries"][0]["presentation_copy"]["name"] = \
		"mutated after sealing"
	_expect_ladder_rejected(
		stale_entry_fingerprint,
		"nested Codex DTO content mutation with stale fingerprint"
	)

	var missing_detail_fingerprint := _unsealed_ladder()
	missing_detail_fingerprint["entries"][0]["detail_face"].erase("dto_fingerprint")
	_expect_ladder_rejected(
		missing_detail_fingerprint,
		"missing nested PlayerFace fingerprint inside ladder entry"
	)

	var wrong_nested_binding := _unsealed_ladder()
	wrong_nested_binding["entries"][0]["localization_binding"]["semantic_fingerprint"] = \
		_different_fingerprint(str(
			wrong_nested_binding["entries"][0]["semantic_binding"]["semantic_fingerprint"]
		))
	_expect_ladder_rejected(wrong_nested_binding, "wrong nested semantic/localization binding")

	var object_value := Resource.new()
	var object_injected := _unsealed_ladder()
	object_injected["entries"][0]["presentation_copy"]["name"] = object_value
	_expect_ladder_rejected(object_injected, "Object inside ladder entry")

	var callable_injected := _unsealed_ladder()
	callable_injected["entries"][0]["presentation_copy"]["name"] = \
		Callable(self, "_run")
	_expect_ladder_rejected(callable_injected, "Callable inside ladder entry")

	var nonfinite_injected := _unsealed_ladder()
	nonfinite_injected["entries"][0]["presentation_copy"]["name"] = INF
	_expect_ladder_rejected(nonfinite_injected, "nonfinite value inside ladder entry")


func _test_ordinary_contract_unchanged() -> void:
	var ordinary_dto := CODEX_DTO.seal(_unsealed_dto())
	var ordinary_ladder := LADDER_DTO.seal(_unsealed_ladder())
	_expect(
		not ordinary_dto.is_empty()
			and bool(CODEX_DTO.validate(ordinary_dto).get("valid", false)),
		"ordinary DTO seal and validate behavior remains valid"
	)
	_expect(
		not ordinary_ladder.is_empty()
			and bool(LADDER_DTO.validate(ordinary_ladder).get("valid", false)),
		"ordinary ladder seal and validate behavior remains valid"
	)

	var tampered_dto := ordinary_dto.duplicate(true)
	tampered_dto["presentation_copy"]["name"] = "tampered"
	_expect(
		not bool(CODEX_DTO.validate(tampered_dto).get("valid", false)),
		"ordinary DTO validator still detects a stale outer fingerprint"
	)
	var malformed_unsealed_dto := _unsealed_dto()
	malformed_unsealed_dto["detail_face"]["catalog_note"] = "not schema"
	_expect(
		CODEX_DTO.seal(malformed_unsealed_dto).is_empty(),
		"ordinary DTO seal still rejects malformed nested detail data"
	)

	var tampered_ladder := ordinary_ladder.duplicate(true)
	tampered_ladder["entries"][0]["presentation_copy"]["name"] = "tampered"
	_expect(
		not bool(LADDER_DTO.validate(tampered_ladder).get("valid", false)),
		"ordinary ladder validator still detects a stale nested fingerprint"
	)
	var malformed_unsealed_ladder := _unsealed_ladder()
	malformed_unsealed_ladder["entries"][0]["catalog_note"] = "not schema"
	_expect(
		LADDER_DTO.seal(malformed_unsealed_ladder).is_empty(),
		"ordinary ladder seal still rejects malformed nested DTO data"
	)


func _test_production_call_sites_are_narrow() -> void:
	var all_fast_call_sites: Array[String] = []
	_collect_fast_constructor_call_sites("res://scripts", all_fast_call_sites)
	all_fast_call_sites.sort()
	var call_sites: Array[String] = []
	for call_site in all_fast_call_sites:
		if call_site.contains("PLAYER_CARD_CODEX_DTO.seal_catalog_owned(") \
				or call_site.contains(
					"PLAYER_CARD_CODEX_FAMILY_LADDER_DTO.seal_catalog_owned("
				):
			call_sites.append(call_site)
			continue
		_expect(
			call_site.begins_with(
				"res://scripts/runtime/card_player_face_projection_service.gd:"
			) and call_site.contains("PlayerFaceDTO.seal_catalog_owned("),
			"non-Codex fast-constructor call remains the reviewed PlayerFace owner: %s"
				% call_site
		)
	_expect(
		call_sites.size() == 2,
		"production has exactly two fast-constructor calls: %s" % str(call_sites)
	)
	for call_site in call_sites:
		_expect(
			call_site.begins_with(EXPECTED_FAST_CONSTRUCTOR_OWNER + ":"),
			"fast constructor is owned only by CardCodexPublicSourceService: %s"
				% call_site
		)
	var joined := "\n".join(call_sites)
	_expect(
		joined.contains("PLAYER_CARD_CODEX_DTO.seal_catalog_owned("),
		"production source owns the DTO fast-constructor call"
	)
	_expect(
		joined.contains("PLAYER_CARD_CODEX_FAMILY_LADDER_DTO.seal_catalog_owned("),
		"production source owns the ladder fast-constructor call"
	)


func _collect_fast_constructor_call_sites(path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		_expect(false, "production scan can open %s" % path)
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path := path.path_join(entry_name)
			if directory.current_is_dir():
				_collect_fast_constructor_call_sites(entry_path, output)
			elif entry_name.ends_with(".gd"):
				var source := FileAccess.get_file_as_string(entry_path)
				var lines := source.split("\n")
				for line_index in range(lines.size()):
					var line := str(lines[line_index]).strip_edges()
					if line.contains(".seal_catalog_owned("):
						output.append(
							"%s:%d:%s" % [entry_path, line_index + 1, line]
						)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _expect_dto_rejected(unsealed: Dictionary, description: String) -> void:
	var result := CODEX_DTO.seal_catalog_owned(unsealed)
	if result.is_empty():
		_expect(true, "DTO fast constructor rejects %s" % description)
		return
	var report := CODEX_DTO.validate(result)
	_expect(
		false,
		"DTO fast constructor accepted %s (full_valid=%s reason=%s)" % [
			description,
			str(report.get("valid", false)),
			str(report.get("reason_id", "missing")),
		]
	)


func _expect_ladder_rejected(unsealed: Dictionary, description: String) -> void:
	var result := LADDER_DTO.seal_catalog_owned(unsealed)
	if result.is_empty():
		_expect(true, "ladder fast constructor rejects %s" % description)
		return
	var report := LADDER_DTO.validate(result)
	_expect(
		false,
		"ladder fast constructor accepted %s (full_valid=%s reason=%s)" % [
			description,
			str(report.get("valid", false)),
			str(report.get("reason_id", "missing")),
		]
	)


func _unsealed_dto() -> Dictionary:
	var unsealed := _catalog_dto.duplicate(true)
	unsealed.erase("dto_fingerprint")
	return unsealed


func _unsealed_ladder() -> Dictionary:
	var unsealed := _catalog_ladder.duplicate(true)
	unsealed.erase("ladder_fingerprint")
	return unsealed


func _different_fingerprint(current: String) -> String:
	var replacement := "0".repeat(64)
	return "1".repeat(64) if current == replacement else replacement


func _cleanup() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame
	_owned_nodes.clear()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: %s" % description)


func _finish() -> void:
	var elapsed_msec := float(Time.get_ticks_usec() - _started_usec) / 1000.0
	if _failures.is_empty():
		print(
			"CARD_CODEX_CATALOG_OWNED_CONSTRUCTOR_TEST|status=PASS|checks=%d|elapsed_ms=%.3f"
				% [_checks, elapsed_msec]
		)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print(
		"CARD_CODEX_CATALOG_OWNED_CONSTRUCTOR_TEST|status=FAIL|checks=%d|failures=%d|elapsed_ms=%.3f"
			% [_checks, _failures.size(), elapsed_msec]
	)
	quit(1)
