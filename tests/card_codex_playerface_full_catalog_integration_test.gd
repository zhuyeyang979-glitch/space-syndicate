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
const PLAYER_FACE_DTO := preload(
	"res://scripts/presentation/player_face_dto_v1.gd"
)
const PLAYER_CARD_CODEX_DTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)

const EXPECTED_CATEGORIES := [
	"commodity",
	"facility",
	"interaction",
	"military",
	"monster",
	"organization",
	"supply_demand",
]
const FORBIDDEN_PUBLIC_KEYS := [
	"developer",
	"effect_payload",
	"exact_cash",
	"future_bag",
	"hand",
	"hidden_owner",
	"machine",
	"method_name",
	"opponent_hand",
	"owner",
	"player",
	"player_index",
	"private_plan",
	"rng_state",
	"route_plan",
	"save_payload",
	"script_path",
	"skill",
	"true_owner",
]

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var semantic := SEMANTIC_SCENE.instantiate() as CardSemanticCatalogService
	var localization: Node = LOCALIZATION_SCENE.instantiate()
	var projection: Node = PROJECTION_SCENE.instantiate()
	var snapshot := SNAPSHOT_SCENE.instantiate() as CardCodexPublicSnapshotService
	var source := SOURCE_SCENE.instantiate() as CardCodexPublicSourceService
	_expect(
		semantic != null and localization != null and projection != null
			and snapshot != null and source != null,
		"real services instantiate"
	)
	if semantic == null or localization == null or projection == null \
			or snapshot == null or source == null:
		_finish()
		return

	semantic.configure_on_ready = false
	root.add_child(semantic)
	root.add_child(localization)
	root.add_child(projection)
	root.add_child(snapshot)
	root.add_child(source)
	await process_frame

	snapshot.configure({})
	var semantic_configuration := semantic.configure()
	var localization_configuration: Dictionary = localization.call(
		"configure", semantic
	)
	var source_configuration := source.configure({
		"player_face_projection": projection,
		"public_localization_source": localization,
		"semantic_catalog": semantic,
		"snapshot": snapshot,
	})
	_expect(
		bool(semantic_configuration.get("configured", false))
			and bool(localization_configuration.get("configured", false))
			and bool(source_configuration.get("service_ready", false)),
		"real public semantic, localization, projection, source, and snapshot chain configures"
	)
	if not bool(source_configuration.get("service_ready", false)):
		_finish()
		return

	var ids: Array[String] = source.ordered_card_ids("all")
	var dto_cache_value: Variant = source.get("_dto_by_card_id")
	var dto_cache: Dictionary = dto_cache_value as Dictionary \
		if dto_cache_value is Dictionary else {}
	var family_ranks: Dictionary = {}
	var categories: Dictionary = {}
	var invalid_dto_ids: Array[String] = []
	var invalid_fact_ids: Array[String] = []
	var invalid_structure_ids: Array[String] = []
	var internal_semantic_text_ids: Array[String] = []
	var private_value_ids: Array[String] = []
	var free_commodity_count := 0
	var zero_activation_count := 0
	var dto_fact_count := 0

	for index in range(ids.size()):
		var card_id := ids[index]
		var dto_value: Variant = dto_cache.get(card_id)
		var dto: Dictionary = dto_value as Dictionary \
			if dto_value is Dictionary else {}
		var facts := source.compose_card_facts(card_id, index)
		var dto_valid := bool(PLAYER_CARD_CODEX_DTO.validate(dto).get(
			"valid", false
		))
		var face_value: Variant = dto.get("detail_face")
		var face: Dictionary = face_value as Dictionary \
			if face_value is Dictionary else {}
		if not dto_valid \
				or not bool(PLAYER_FACE_DTO.validate(face).get("valid", false)):
			_append_sample(invalid_dto_ids, card_id)
		if not bool(facts.get("valid", false)) \
				or str(facts.get("card_name", "")) != card_id \
				or str(face.get("card_id", "")) != card_id:
			_append_sample(invalid_fact_ids, card_id)
		else:
			dto_fact_count += 1

		var family_id := str(face.get("family_id", ""))
		var rank := int(face.get("rank", 0))
		var taxonomy_value: Variant = dto.get("taxonomy")
		var taxonomy: Dictionary = taxonomy_value as Dictionary \
			if taxonomy_value is Dictionary else {}
		var category_id := str(taxonomy.get("category_id", ""))
		categories[category_id] = true
		if not family_ranks.has(family_id):
			family_ranks[family_id] = []
		(family_ranks[family_id] as Array).append(rank)

		var acquisition_value: Variant = face.get("acquisition_cost")
		var acquisition: Dictionary = acquisition_value as Dictionary \
			if acquisition_value is Dictionary else {}
		var activation_value: Variant = face.get("activation_cost")
		var activation: Dictionary = activation_value as Dictionary \
			if activation_value is Dictionary else {}
		var asset_value: Variant = activation.get("asset_cost")
		var asset_cost: Dictionary = asset_value as Dictionary \
			if asset_value is Dictionary else {}
		if category_id == "commodity" \
				and int(acquisition.get("purchase_cash", -1)) == 0:
			free_commodity_count += 1
		if _integer_sum(asset_cost) == 0:
			zero_activation_count += 1

		var structure_valid := _structured_face_is_complete(face) \
			and acquisition.has("purchase_cash") \
			and not acquisition.has("asset_cost") \
			and activation.has("asset_cost") \
			and not activation.has("purchase_cash") \
			and str(facts.get("acquisition_cost_text", "")).length() > 0 \
			and str(facts.get("activation_cost_text", "")).length() > 0 \
			and (facts.get("effect_step_texts") is Array) \
			and not (facts.get("effect_step_texts") as Array).is_empty() \
			and (facts.get("family_ladder") is Array) \
			and _fact_ladder_is_complete(
				facts.get("family_ladder") as Array, family_id
			)
		if not structure_valid:
			_append_sample(invalid_structure_ids, card_id)
		for effect_text_variant in facts.get("effect_step_texts", []) as Array:
			if _contains_internal_semantic_marker(str(effect_text_variant)):
				_append_sample(internal_semantic_text_ids, card_id)
				break
		if not PLAYER_FACE_DTO.is_detached_pure_data(dto) \
				or _first_forbidden_key(dto) != "" \
				or _first_forbidden_key(facts) != "" \
				or not _is_detached_ui_data(facts):
			_append_sample(private_value_ids, card_id)

	_expect(ids.size() == 348, "public source exposes exactly 348 stable card IDs")
	_expect(
		dto_cache.size() == 348 and dto_fact_count == 348
			and invalid_dto_ids.is_empty() and invalid_fact_ids.is_empty(),
		"348/348 facts are backed by valid PlayerCardCodexDTOv1 detail faces: %s / %s"
			% [str(invalid_dto_ids), str(invalid_fact_ids)]
	)
	_expect(
		invalid_structure_ids.is_empty(),
		"348/348 DTOs preserve separated costs and structured timing, targets, conditions, ordered effects, duration, counterability, and information: %s"
			% str(invalid_structure_ids)
	)
	_expect(
		internal_semantic_text_ids.is_empty(),
		"348/348 player effect steps hide internal parameter keys and stable values: %s"
			% str(internal_semantic_text_ids)
	)
	_expect(
		private_value_ids.is_empty(),
		"DTOs and compatibility facts are detached and expose no private or raw value channel: %s"
			% str(private_value_ids)
	)
	_expect(
		free_commodity_count > 0 and zero_activation_count > 0,
		"free commodity acquisition and zero-asset activation remain distinct"
	)
	_expect(
		_family_set_is_complete(family_ranks),
		"87/87 families contain authoritative ranks 1 through 4"
	)
	var category_ids: Array = categories.keys()
	category_ids.sort()
	_expect(
		category_ids == EXPECTED_CATEGORIES,
		"all seven semantic categories are represented"
	)

	var catalog_debug := semantic.validation_snapshot()
	var source_debug := source.debug_snapshot()
	var adapter_debug_value: Variant = source_debug.get("adapter")
	var adapter_debug: Dictionary = adapter_debug_value as Dictionary \
		if adapter_debug_value is Dictionary else {}
	_expect(
		int(catalog_debug.get("active_count", 0)) == 256
			and int(catalog_debug.get("projection_only_count", 0)) == 92
			and int(source_debug.get("cached_dto_count", 0)) == 348
			and int(source_debug.get("cached_family_ladder_count", 0)) == 87
			and bool(adapter_debug.get("dto_only_semantic_input", false)),
		"256 active and 92 projection-only specs all remain displayable through the DTO-only adapter"
	)
	_expect(
		_count_key(dto_cache, "runtime_readiness_id") == 0
			and not bool(source_debug.get("owns_rules", true)),
		"Player projection does not promote or export executable readiness"
	)

	var first_facts := source.compose_card_facts(ids[0], 0)
	_expect(
		source.resolve_card_id(ids[0]) == ids[0]
			and source.resolve_card_id(str(first_facts.get("display_name", ""))) == ""
			and source.resolve_card_id(
				"%s IV" % str(first_facts.get("display_name", ""))
			) == ""
			and source.resolve_card_id(
				"%s4" % str(first_facts.get("display_name", ""))
			) == "",
		"new Codex path accepts stable card_id only and rejects localized, Roman, and numeric identity recovery"
	)

	var before_read_debug := source.debug_snapshot()
	var before_semantic_debug := semantic.validation_snapshot()
	var before_localization_debug: Dictionary = localization.call(
		"debug_snapshot"
	)
	var request := {
		"names": ids,
		"columns": 5,
		"rows": 8,
		"page_index": 0,
		"filter_id": "all",
		"selected_card": ids[0],
		"run_pool_count": 0,
		"district_supply_count": 0,
	}
	var browser := source.compose_browser(request)
	var repeated_browser := source.compose_browser(request)
	var representative_details: Array = []
	for category_id in EXPECTED_CATEGORIES:
		var category_cards: Array[String] = source.ordered_card_ids(category_id)
		if not category_cards.is_empty():
			representative_details.append(source.compose_detail(
				category_cards[0], ids.find(category_cards[0]), ids.size()
			))
	var after_read_debug := source.debug_snapshot()
	var after_semantic_debug := semantic.validation_snapshot()
	var after_localization_debug: Dictionary = localization.call(
		"debug_snapshot"
	)
	_expect(
		(browser.get("cards") is Array)
			and (browser.get("cards") as Array).size() == 40
			and not repeated_browser.is_empty()
			and representative_details.size() == 7
			and _all_nonempty_dictionaries(representative_details),
		"browser, repeated page, hover facts, and seven-category details compose through the production chain"
	)
	_expect(
		_first_forbidden_key(browser) == ""
			and _first_forbidden_key(repeated_browser) == ""
			and _first_forbidden_key(representative_details) == ""
			and _is_detached_ui_data(browser)
			and _is_detached_ui_data(representative_details),
		"browser and detail snapshots contain only detached public UI data"
	)
	_expect(
		int(after_read_debug.get("catalog_snapshot_count", -1))
				== int(before_read_debug.get("catalog_snapshot_count", -2))
			and int(after_read_debug.get("catalog_record_authorization_count", -1))
				== int(before_read_debug.get("catalog_record_authorization_count", -2))
			and int(after_read_debug.get("localization_issue_count", -1))
				== int(before_read_debug.get("localization_issue_count", -2))
			and int(after_read_debug.get("dto_projection_count", -1))
				== int(before_read_debug.get("dto_projection_count", -2))
			and int(after_read_debug.get("catalog_reload_count", -1)) == 0,
		"browser, hover, and detail reads do not reload or reproject the 348-card catalog"
	)
	_expect(
		int(after_semantic_debug.get("compile_count", -1))
				== int(before_semantic_debug.get("compile_count", -2))
			and int(after_read_debug.get("semantic_compile_delta", -1)) == 0
			and int(after_localization_debug.get("configuration_attempt_count", -1))
				== int(before_localization_debug.get("configuration_attempt_count", -2)),
		"render, hover, and detail compile delta is zero and localization is not rebound"
	)
	_expect(
		int(after_read_debug.get("dto_cache_hit_count", 0))
				> int(before_read_debug.get("dto_cache_hit_count", 0))
			and int(after_read_debug.get("family_ladder_cache_hit_count", 0))
				> int(before_read_debug.get("family_ladder_cache_hit_count", 0)),
		"interactive reads hit the prebuilt DTO and family ladder caches"
	)
	_finish()


func _structured_face_is_complete(face: Dictionary) -> bool:
	var timing: Variant = face.get("timing")
	var targets: Variant = face.get("targets")
	var conditions: Variant = face.get("conditions")
	var effects: Variant = face.get("effect_steps")
	var duration: Variant = face.get("duration")
	var counterability: Variant = face.get("counterability")
	var information: Variant = face.get("information_scope")
	if not (timing is Dictionary) \
			or not PLAYER_FACE_DTO.is_stable_id(str((timing as Dictionary).get(
				"timing_id", ""
			))) \
			or not (targets is Array) or (targets as Array).is_empty() \
			or not (conditions is Array) \
			or not (effects is Array) or (effects as Array).is_empty() \
			or not (duration is Dictionary) \
			or not (counterability is Dictionary) \
			or not (information is Dictionary):
		return false
	for index in range((effects as Array).size()):
		var step_value: Variant = (effects as Array)[index]
		if not (step_value is Dictionary) \
				or int((step_value as Dictionary).get("order", 0)) != index + 1:
			return false
	return true


func _fact_ladder_is_complete(rows: Array, family_id: String) -> bool:
	if rows.size() != 4:
		return false
	for index in range(rows.size()):
		var row_value: Variant = rows[index]
		if not (row_value is Dictionary):
			return false
		var row := row_value as Dictionary
		if int(row.get("rank", 0)) != index + 1 \
				or str(row.get("family_id", "")) != family_id:
			return false
	return true


func _family_set_is_complete(family_ranks: Dictionary) -> bool:
	if family_ranks.size() != 87:
		return false
	for ranks_value: Variant in family_ranks.values():
		if not (ranks_value is Array):
			return false
		var ranks := (ranks_value as Array).duplicate()
		ranks.sort()
		if ranks != [1, 2, 3, 4]:
			return false
	return true


func _integer_sum(values: Dictionary) -> int:
	var total := 0
	for value: Variant in values.values():
		if not (value is int):
			return -1
		total += int(value)
	return total


func _all_nonempty_dictionaries(values: Array) -> bool:
	for value: Variant in values:
		if not (value is Dictionary) or (value as Dictionary).is_empty():
			return false
	return true


func _first_forbidden_key(value: Variant) -> String:
	if value is Dictionary:
		for key_value: Variant in (value as Dictionary).keys():
			var key := str(key_value).to_lower()
			if FORBIDDEN_PUBLIC_KEYS.has(key) \
					or key.begins_with("private_") \
					or key.begins_with("hidden_"):
				return key
			var nested := _first_forbidden_key((value as Dictionary).get(key_value))
			if not nested.is_empty():
				return nested
	elif value is Array:
		for item: Variant in value as Array:
			var nested := _first_forbidden_key(item)
			if not nested.is_empty():
				return nested
	return ""


func _count_key(value: Variant, expected_key: String) -> int:
	var count := 0
	if value is Dictionary:
		for key_value: Variant in (value as Dictionary).keys():
			if str(key_value) == expected_key:
				count += 1
			count += _count_key((value as Dictionary).get(key_value), expected_key)
	elif value is Array:
		for item: Variant in value as Array:
			count += _count_key(item, expected_key)
	return count


func _is_detached_ui_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName \
			or value is bool or value is int or value is Color:
		return true
	if value is float:
		return is_finite(float(value))
	if value is Dictionary:
		for key_value: Variant in (value as Dictionary).keys():
			if not (key_value is String) \
					or not _is_detached_ui_data(
						(value as Dictionary).get(key_value)
					):
				return false
		return true
	if value is Array:
		for item: Variant in value as Array:
			if not _is_detached_ui_data(item):
				return false
		return true
	return false


func _contains_internal_semantic_marker(text: String) -> bool:
	for marker in [
		"_id=",
		"_ids=",
		"until_facility_destroyed",
		"production_or_demand_by_facility_kind",
		"card_family",
	]:
		if text.contains(marker):
			return true
	return false


func _append_sample(values: Array[String], value: String) -> void:
	if values.size() < 12:
		values.append(value)


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _finish() -> void:
	var elapsed_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	if _failures.is_empty() and elapsed_ms < 60000.0:
		print(
			"CARD_CODEX_PLAYERFACE_FULL_CATALOG_INTEGRATION_TEST|"
			+ "status=PASS|checks=%d|elapsed_ms=%.3f|cards=348|families=87|categories=7|compile_delta=0"
			% [_checks, elapsed_ms]
		)
		quit(0)
		return
	if elapsed_ms >= 60000.0:
		_failures.append("focused test exceeded 60000ms")
	push_error(
		"CARD_CODEX_PLAYERFACE_FULL_CATALOG_INTEGRATION_TEST|"
		+ "status=FAIL|checks=%d|failures=%d|elapsed_ms=%.3f|details=%s"
		% [_checks, _failures.size(), elapsed_ms, JSON.stringify(_failures)]
	)
	quit(1)
