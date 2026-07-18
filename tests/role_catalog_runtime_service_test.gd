extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const ROLE_CATALOG_SCENE := "res://scenes/runtime/RoleCatalogRuntimeService.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const QA_SAVE_PATH := "user://test_runs/role_catalog_runtime_service.save"
const EXPECTED_LEGACY_AUDIT_SHA256 := "7609b20741bec0e835e7768f2301f587c1848180a49aad8ca7c767e6c8d1cbe0"
const EXPECTED_CATALOG_SHA256 := "30dfb73511bc4e9b6ef76bf28d96250d65afbcb1db1529ba772143dc45046968"
const EXPECTED_NAMES := [
	"环港走私议会",
	"深海菌毯使团",
	"重力矿联董事会",
	"离子军购局",
	"光合修复会",
	"虹膜数据券商",
	"星鲸餐饮垄断",
	"静电蜂巢银行",
	"星图审计庭",
	"幽幕播报社",
	"双边密约公证团",
	"碎光私探行会",
	"星门补给商会",
	"赤环航运托拉斯",
	"霓虹需求剧院",
	"极昼农业云",
	"黑潮风险基金",
	"白噪安保公司",
	"钛壳互助清算所",
	"暗礁公证黑市",
	"太阳鳞片王朝",
	"孪星兽栏同盟",
	"蜂巢防务议会",
	"悖论兽契社",
]
const EXPECTED_FIELD_UNION := [
	"bonus_card_product",
	"card_owner_guess_bonus",
	"card_owner_guess_discount",
	"city_guess_reward_bonus",
	"contract_flow_discount",
	"flavor",
	"intel_card_trace_charges",
	"intel_city_reveal_charges",
	"intel_contract_trace_charges",
	"military_control_limit_bonus",
	"monster_cards_as_counter",
	"monster_control_limit_bonus",
	"monster_upgrade_cash",
	"name",
	"passive",
	"resource_cash_amount",
	"resource_cash_product",
	"species",
	"starting_cash_bonus",
	"trait",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_standalone_owner()
	await _test_production_composition_and_runtime_parity()
	_finish()


func _test_standalone_owner() -> void:
	var packed := load(ROLE_CATALOG_SCENE) as PackedScene
	_expect(packed != null, "role_catalog_scene_loads")
	if packed == null:
		return
	var catalog := packed.instantiate() as RoleCatalogRuntimeService
	_expect(catalog != null, "role_catalog_scene_has_typed_owner")
	if catalog == null:
		return
	var validation := catalog.validate_catalog()
	var actual_hash := catalog.catalog_sha256()
	_expect(bool(validation.get("valid", false)), "catalog_validation_green|validation=%s" % validation)
	_expect(catalog.role_count() == 24, "catalog_has_exactly_24_roles")
	_expect(catalog.ordered_role_names() == EXPECTED_NAMES, "catalog_preserves_exact_legacy_order_and_names")
	_expect(str(validation.get("legacy_catalog_audit_sha256", "")) == EXPECTED_LEGACY_AUDIT_SHA256, "catalog_records_reviewed_legacy_audit_hash")
	_expect(actual_hash == EXPECTED_CATALOG_SHA256, "catalog_full_field_hash_locked|actual=%s" % actual_hash)
	_expect((validation.get("duplicate_names", []) as Array).is_empty(), "catalog_has_no_duplicate_names")
	_expect(_field_union(catalog) == EXPECTED_FIELD_UNION, "catalog_preserves_exact_legacy_field_union|actual=%s" % [_field_union(catalog)])
	for index in range(catalog.role_count()):
		var definition := catalog.definition_at(index)
		_expect(int(catalog.index_by_name(str(definition.get("name", "")))) == index, "role_%02d_name_round_trips_to_original_index" % index)
		_expect(catalog.definition_by_name(str(definition.get("name", ""))) == definition, "role_%02d_name_lookup_preserves_full_definition" % index)
		_expect(catalog.public_definition_at(index) == definition, "role_%02d_public_projection_preserves_all_public_fields" % index)
	var mutable_copy := catalog.definition_at(0)
	mutable_copy["name"] = "篡改目录"
	mutable_copy["starting_cash_bonus"] = 999999
	_expect(str(catalog.definition_at(0).get("name", "")) == EXPECTED_NAMES[0] and int(catalog.definition_at(0).get("starting_cash_bonus", 0)) == 80, "external_dictionary_mutation_cannot_change_owner")
	_test_portrait_manifest_parity(catalog)
	catalog.free()


func _test_production_composition_and_runtime_parity() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not source.contains("PLAYER_ROLE_CATALOG"), "main_has_zero_role_catalog_copy")
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "main_scene_loads")
	if packed == null:
		return
	var main := packed.instantiate()
	_cleanup_test_save()
	var save := main.get_node_or_null("%s/GameSessionRuntimeController/GameSaveRuntimeCoordinator" % COORDINATOR_PATH)
	_expect(save != null and save.has_method("set_qa_default_save_path_override"), "qa_save_override_available")
	if save == null or not save.has_method("set_qa_default_save_path_override"):
		main.free()
		return
	_expect(bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "qa_save_isolated")
	root.add_child(main)
	await process_frame
	var coordinator := main.get_node_or_null(COORDINATOR_PATH) as GameRuntimeCoordinator
	var catalog := coordinator.role_catalog_runtime_service() if coordinator != null else null
	_expect(coordinator != null and catalog != null, "production_coordinator_owns_unique_role_catalog")
	var owner_count := main.find_children("RoleCatalogRuntimeService", "RoleCatalogRuntimeService", true, false).size()
	_expect(owner_count == 1, "production_scene_has_exactly_one_role_catalog_owner|count=%d" % owner_count)
	if coordinator != null and catalog != null:
		_expect(catalog.role_count() == 24, "coordinator_exposes_exact_role_owner")
		for index in range(catalog.role_count()):
			var main_definition := main.call("_player_role_template", index, index) as Dictionary
			_expect(main_definition == catalog.definition_at(index), "main_role_helper_%02d_is_owner_query_only" % index)
		main.set("configured_player_count", 4)
		main.set("configured_ai_player_count", 3)
		main.set("configured_role_indices", [0, 1, 2, 3])
		main.call("_ensure_configured_role_indices")
		main.call("_new_game")
		await process_frame
		var players := coordinator.world_session_state().players
		_expect(players.size() == 4, "four_player_setup_still_builds_four_roles")
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			var role := player.get("role_card", {}) as Dictionary
			var role_index := int(role.get("role_index", -1))
			_expect(role_index == player_index and str(role.get("name", "")) == EXPECTED_NAMES[player_index], "setup_keeps_role_index_name_parity_%d" % player_index)
		var world_save := coordinator.world_session_state().to_save_data()
		var saved_players := world_save.get("players", []) as Array
		_expect(saved_players.size() == players.size(), "world_session_save_keeps_player_count")
		for player_index in range(saved_players.size()):
			var saved_player := saved_players[player_index] as Dictionary
			var saved_role := saved_player.get("role_card", {}) as Dictionary
			_expect(int(saved_role.get("role_index", -1)) == player_index and str(saved_role.get("name", "")) == EXPECTED_NAMES[player_index], "world_session_save_keeps_legacy_role_index_name_%d" % player_index)
		var public_projection := coordinator.presentation_public_world_projection()
		var public_players := public_projection.players if public_projection != null else []
		_expect(public_players.size() == players.size(), "world_public_projection_preserves_role_seat_count")
		for player_index in range(public_players.size()):
			var public_player := public_players[player_index] as Dictionary
			_expect(str(public_player.get("role_name", "")) == EXPECTED_NAMES[player_index], "world_public_projection_role_name_matches_catalog_%d" % player_index)
	main.queue_free()
	await process_frame
	await process_frame
	_cleanup_test_save()


func _test_portrait_manifest_parity(catalog: RoleCatalogRuntimeService) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/role_portraits/temporary/manifest.json"))
	_expect(parsed is Dictionary, "portrait_manifest_parses")
	if not (parsed is Dictionary):
		return
	var entries := (parsed as Dictionary).get("roles", []) as Array
	_expect(entries.size() == 24, "portrait_manifest_has_exactly_24_entries")
	var names: Array[String] = []
	var slugs := {}
	var rendered := 0
	var pending := 0
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		names.append(str(entry.get("role_name", "")))
		var slug := str(entry.get("slug", ""))
		if slug != "":
			slugs[slug] = int(slugs.get(slug, 0)) + 1
		if str(entry.get("status", "")) == "rendered":
			rendered += 1
		else:
			pending += 1
	_expect(names == catalog.ordered_role_names(), "portrait_manifest_preserves_catalog_name_order")
	_expect(slugs.size() == 24 and not _has_duplicate_count(slugs), "portrait_manifest_slugs_are_unique")
	_expect(rendered == 8 and pending == 16, "portrait_manifest_rendered_pending_parity")


func _field_union(catalog: RoleCatalogRuntimeService) -> Array[String]:
	var fields := {}
	for index in range(catalog.role_count()):
		for key_variant in catalog.definition_at(index).keys():
			fields[str(key_variant)] = true
	var result: Array[String] = []
	for key_variant in fields.keys():
		result.append(str(key_variant))
	result.sort()
	return result


func _has_duplicate_count(counts: Dictionary) -> bool:
	for count_variant in counts.values():
		if int(count_variant) != 1:
			return true
	return false


func _cleanup_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(QA_SAVE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("ROLE_CATALOG_RUNTIME_SERVICE_TEST: %s" % label)


func _finish() -> void:
	print("ROLE_CATALOG_RUNTIME_SERVICE_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	for failure in _failures:
		print("FAIL|%s" % failure)
	quit(_failures.size())
