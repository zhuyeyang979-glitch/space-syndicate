extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://test_runs/gameplay_balance_diagnostics_monster_art_profile.save"
const MonsterCatalogV06 := preload("res://scripts/runtime/monster_catalog_v06.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_product_related_card_count_semantics()
	_delete_qa_save_file()
	var main := _instantiate_main()
	if main == null:
		_finish()
		return
	root.add_child(main)
	await process_frame
	await process_frame
	if main.has_method("_new_game"):
		main.call("_new_game")
	await process_frame
	await process_frame
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var diagnostics: GameplayBalanceDiagnosticsRuntimeService = coordinator.gameplay_balance_diagnostics_service() if coordinator is GameRuntimeCoordinator else null
	_expect(diagnostics != null, "GameRuntimeCoordinator exposes GameplayBalanceDiagnosticsRuntimeService")
	var snapshot: Dictionary = diagnostics.refresh_world_snapshot(false) if diagnostics != null else {}
	_expect(_monster_art_profiles_present(snapshot), "diagnostics monster facts use catalog-backed art profiles for every catalog entry")
	_verify_production_product_related_card_counts(snapshot, coordinator)
	_expect(_production_symbol_absent("_monster_art_profile"), "production scripts have zero executable _monster_art_profile references")
	_expect(_production_symbol_absent("_product_related_card_count"), "production scripts have zero dynamic dependencies on the retired Main product-card helper")
	main.queue_free()
	await process_frame
	_delete_qa_save_file()
	_finish()


func _verify_product_related_card_count_semantics() -> void:
	var service := CardRuntimeCatalogService.new()
	service.catalog = _synthetic_catalog()
	_expect(service.product_related_card_count("测试商品") == 3, "catalog query counts play_product and supply_product matches, with a dual match counted once")
	_expect(service.product_related_card_count("其他商品") == 1, "catalog query ignores unrelated cards")
	_expect(service.product_related_card_count("退役商品") == 0, "catalog query does not restore retired contract_products semantics")
	_expect(service.product_related_card_count("") == 0, "catalog query rejects an empty product id")
	service.free()


func _synthetic_catalog() -> CardRuntimeCatalogResource:
	var definitions := [
		_card_rank("出牌关联1", "出牌关联", {"play_product": "测试商品"}),
		_card_rank("供应关联1", "供应关联", {"supply_product": "测试商品"}),
		_card_rank("双重关联1", "双重关联", {"play_product": "测试商品", "supply_product": "测试商品"}),
		_card_rank("其他关联1", "其他关联", {"play_product": "其他商品"}),
		_card_rank("退役合同1", "退役合同", {"contract_products": ["退役商品"]}),
	]
	var families: Array[Resource] = []
	var ordered_ids := PackedStringArray()
	for definition_variant in definitions:
		var definition := definition_variant as CardRuntimeRankResource
		var family := CardRuntimeFamilyResource.new()
		family.family_id = definition.family_id
		family.pack_id = &"diagnostics_test"
		family.authored_ranks = [definition]
		families.append(family)
		ordered_ids.append(definition.card_id)
	var pack := CardRuntimePackResource.new()
	pack.pack_id = &"diagnostics_test"
	pack.families = families
	var catalog := CardRuntimeCatalogResource.new()
	catalog.packs = [pack]
	catalog.authored_card_order = ordered_ids
	return catalog


func _card_rank(card_id: String, family_id: String, fields: Dictionary) -> CardRuntimeRankResource:
	var definition := CardRuntimeRankResource.new()
	definition.card_id = card_id
	definition.family_id = family_id
	definition.rank = 1
	definition.authored_keys = PackedStringArray(fields.keys())
	definition.play_product = str(fields.get("play_product", ""))
	definition.supply_product = str(fields.get("supply_product", ""))
	definition.effect_parameters = fields.duplicate(true)
	return definition


func _verify_production_product_related_card_counts(snapshot: Dictionary, coordinator: Node) -> void:
	var expected_by_product := {}
	for card_id_variant in coordinator.card_catalog_ordered_ids():
		var definition: Dictionary = coordinator.card_authored_catalog_definition(str(card_id_variant))
		for field_name in ["play_product", "supply_product"]:
			var product_name := str(definition.get(field_name, ""))
			if not product_name.is_empty():
				expected_by_product[product_name] = true
	var found_positive := false
	for product_variant in snapshot.get("products", []):
		if not (product_variant is Dictionary):
			continue
		var product := product_variant as Dictionary
		var product_name := str(product.get("name", ""))
		var expected := 0
		for card_id_variant in coordinator.card_catalog_ordered_ids():
			var definition: Dictionary = coordinator.card_authored_catalog_definition(str(card_id_variant))
			if str(definition.get("play_product", "")) == product_name \
					or str(definition.get("supply_product", "")) == product_name:
				expected += 1
		_expect(int(product.get("related_card_count", -1)) == expected, "diagnostics product %s uses the typed card catalog count" % product_name)
		found_positive = found_positive or expected > 0
	_expect(found_positive and not expected_by_product.is_empty(), "production diagnostics expose at least one catalog-backed product-card relationship")


func _instantiate_main() -> Control:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		return null
	var main := packed.instantiate() as Control
	_expect(main != null, "main scene instantiates")
	if main == null:
		return null
	main.visible = false
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and save.has_method("set_qa_default_save_path_override"), "QA save-path override exists before main enters the tree")
	if save == null or not save.has_method("set_qa_default_save_path_override"):
		main.queue_free()
		return null
	_expect(bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "focused gate uses only the isolated QA save path")
	return main


func _monster_art_profiles_present(snapshot: Dictionary) -> bool:
	var monsters: Array = snapshot.get("monsters", []) if snapshot.get("monsters", []) is Array else []
	if monsters.size() != MonsterCatalogV06.catalog_size():
		return false
	for monster_variant in monsters:
		if not (monster_variant is Dictionary):
			return false
		if not bool((monster_variant as Dictionary).get("has_art_profile", false)):
			return false
	return true


func _production_symbol_absent(symbol: String) -> bool:
	for path_variant in _production_script_files("res://scripts"):
		var source := FileAccess.get_file_as_string(str(path_variant))
		if source.contains(symbol):
			return false
	return true


func _production_script_files(root_path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	while true:
		var item := dir.get_next()
		if item == "":
			break
		if item.begins_with("."):
			continue
		var path := "%s/%s" % [root_path, item]
		if dir.current_is_dir():
			if path == "res://scripts/tools":
				continue
			result.append_array(_production_script_files(path))
		elif path.ends_with(".gd"):
			result.append(path)
	dir.list_dir_end()
	return result


func _delete_qa_save_file() -> void:
	if FileAccess.file_exists(QA_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE_PATH))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("GAMEPLAY BALANCE DIAGNOSTICS MONSTER ART PROFILE PASS")
		quit(0)
	else:
		print("GAMEPLAY BALANCE DIAGNOSTICS MONSTER ART PROFILE FAIL: %s" % ", ".join(_failures))
		quit(1)
