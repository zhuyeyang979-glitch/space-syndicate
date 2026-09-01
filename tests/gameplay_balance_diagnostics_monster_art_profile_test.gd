extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MonsterCatalogV06 := preload("res://scripts/runtime/monster_catalog_v06.gd")
const MonsterArtViewScript := preload("res://scripts/monster_art_view.gd")
const DYNAMIC_REFERENCE_MANIFEST_PATH := "res://docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json"
const MONSTER_DYNAMIC_REFERENCE_IDS := [
	"dynamic.current.monster_art.optional_texture.exists",
	"dynamic.current.monster_art.optional_texture.load",
]
const EXPECTED_MONSTER_DYNAMIC_TARGET_SET_SHA256 := "06fcadb6e363cc49da61463a1b42da4138d4050fb48a8ee1ec9b9a050c65a43a"
const EXPECTED_MONSTER_DYNAMIC_TARGETS := [
	"res://assets/third_party/kenney_cc0/hexagon/alienBlue.png",
	"res://assets/third_party/kenney_cc0/platformer/enemies/fishSwim1.png",
	"res://assets/third_party/kenney_cc0/platformer/enemies/slimeWalk1.png",
	"res://assets/third_party/kenney_cc0/space/enemyUFO.png",
	"res://assets/third_party/monster_battler/monsters/dino.png",
	"res://assets/third_party/monster_battler/monsters/rock.png",
	"res://assets/third_party/monster_battler/monsters/rodent.png",
	"res://assets/third_party/monster_battler/monsters/salamander.png",
	"res://assets/third_party/monster_battler/monsters/turtle.png",
	"res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc.png",
	"res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_atfield.png",
	"res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_laser.png",
	"res://assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_mech.png",
	"res://assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_tank.png",
	"res://assets/third_party/pixelmob_cc0/sprites/SlimeA.png",
	"res://assets/third_party/pixelmob_cc0/sprites/SlimeSquareA.png",
	"res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/cyclop.png",
	"res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/dragon.png",
	"res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/slim.png",
	"res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/snake.png",
]
const EXPECTED_MONSTER_ART_VIEW_TARGET_BY_KEY := {
	"moth_kaijuice_kaiju": "res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc.png",
	"moth_kaijuice_atfield": "res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_atfield.png",
	"moth_kaijuice_laser": "res://assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_laser.png",
	"moth_kaijuice_mech": "res://assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_mech.png",
	"moth_kaijuice_tank": "res://assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_tank.png",
	"monster_battler_dino": "res://assets/third_party/monster_battler/monsters/dino.png",
	"monster_battler_rock": "res://assets/third_party/monster_battler/monsters/rock.png",
	"monster_battler_rodent": "res://assets/third_party/monster_battler/monsters/rodent.png",
	"monster_battler_salamander": "res://assets/third_party/monster_battler/monsters/salamander.png",
	"monster_battler_turtle": "res://assets/third_party/monster_battler/monsters/turtle.png",
	"kenney_fish": "res://assets/third_party/kenney_cc0/platformer/enemies/fishSwim1.png",
	"kenney_slime": "res://assets/third_party/kenney_cc0/platformer/enemies/slimeWalk1.png",
	"kenney_alien_blue": "res://assets/third_party/kenney_cc0/hexagon/alienBlue.png",
	"kenney_enemy_ufo": "res://assets/third_party/kenney_cc0/space/enemyUFO.png",
	"pixelmob_slime": "res://assets/third_party/pixelmob_cc0/sprites/SlimeA.png",
	"pixelmob_slime_square": "res://assets/third_party/pixelmob_cc0/sprites/SlimeSquareA.png",
	"superpowers_dragon": "res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/dragon.png",
	"superpowers_cyclop": "res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/cyclop.png",
	"superpowers_snake": "res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/snake.png",
	"superpowers_slim": "res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/slim.png",
}
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_product_related_card_count_semantics()
	await _verify_monster_dynamic_reference_contract()
	await _verify_current_production_monster_art_contract()
	_expect(_production_symbol_absent("_monster_art_profile"), "production scripts have zero executable _monster_art_profile references")
	_expect(_production_symbol_absent("_product_related_card_count"), "production scripts have zero dynamic dependencies on the retired Main product-card helper")
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


func _verify_current_production_monster_art_contract() -> void:
	var main_source := FileAccess.get_file_as_string(MAIN_SCENE_PATH)
	_expect(
		main_source.contains("res://scenes/runtime/V075RuntimeComposition.tscn")
			and main_source.contains("V075RuntimeComposition"),
		"production main binds the current V075RuntimeComposition"
	)
	_expect(
		not main_source.contains("RuntimeServices/RuntimeControllerHost"),
		"production main no longer exposes the retired V0.6 runtime fixture path"
	)
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "current production main scene loads")
	if packed == null:
		return
	var application := packed.instantiate() as Control
	_expect(application != null, "current production main scene instantiates")
	if application == null:
		return
	application.visible = false
	root.add_child(application)
	await process_frame
	await process_frame
	var composition := application.get_node_or_null("V075RuntimeComposition")
	var screen := application.get_node_or_null("V075GameScreen")
	_expect(composition != null, "current production main exposes V075RuntimeComposition")
	_expect(screen != null, "current production main exposes V075GameScreen")
	application.queue_free()
	await process_frame

	var roster: Array = MonsterCatalogV06.roster()
	_expect(
		roster.size() == MonsterCatalogV06.catalog_size()
			and not roster.is_empty(),
		"MonsterCatalogV06 exposes its complete non-empty roster"
	)
	var profile_count := 0
	var sprite_key_count := 0
	for monster_variant in roster:
		_expect(monster_variant is Dictionary, "every MonsterCatalogV06 roster row is a dictionary")
		if not (monster_variant is Dictionary):
			continue
		var monster := monster_variant as Dictionary
		var monster_name := str(monster.get("name", ""))
		var profile := MonsterCatalogV06.art_profile(monster_name)
		_expect(not monster_name.is_empty(), "every MonsterCatalogV06 roster row has an identity")
		_expect(not profile.is_empty(), "%s has a catalog-backed art profile" % monster_name)
		if profile.is_empty():
			continue
		profile_count += 1
		var sprite_key := str(profile.get("sprite_key", ""))
		_expect(
			EXPECTED_MONSTER_ART_VIEW_TARGET_BY_KEY.has(sprite_key),
			"%s art profile binds a known MonsterArtView sprite key" % monster_name
		)
		if EXPECTED_MONSTER_ART_VIEW_TARGET_BY_KEY.has(sprite_key):
			sprite_key_count += 1
	_expect(profile_count == roster.size(), "all production monster roster rows have art profiles")
	_expect(sprite_key_count == roster.size(), "all production monster art profiles bind loaded sprite keys")
	print("MONSTER_CURRENT_CUTOVER_ORACLE|composition=V075RuntimeComposition|roster=%d|art_profiles=%d|sprite_keys=%d" % [
		roster.size(),
		profile_count,
		sprite_key_count,
	])


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


func _verify_monster_dynamic_reference_contract() -> void:
	var manifest_text := FileAccess.get_file_as_string(DYNAMIC_REFERENCE_MANIFEST_PATH)
	var manifest_variant: Variant = JSON.parse_string(manifest_text)
	_expect(manifest_variant is Dictionary, "dynamic reference manifest parses")
	if not (manifest_variant is Dictionary):
		return
	var manifest := manifest_variant as Dictionary
	var entries_variant: Variant = manifest.get("entries", [])
	_expect(entries_variant is Array, "dynamic reference manifest exposes entries")
	if not (entries_variant is Array):
		return
	var entries_by_id: Dictionary = {}
	for entry_variant in entries_variant as Array:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		entries_by_id[str(entry.get("dynamic_reference_id", ""))] = entry
	for dynamic_reference_id in MONSTER_DYNAMIC_REFERENCE_IDS:
		_expect(
			entries_by_id.has(dynamic_reference_id),
			"manifest contains %s" % dynamic_reference_id
		)
		if not entries_by_id.has(dynamic_reference_id):
			continue
		var entry := entries_by_id[dynamic_reference_id] as Dictionary
		var targets_variant: Variant = entry.get("resolved_targets", [])
		_expect(targets_variant is Array, "%s exposes a target array" % dynamic_reference_id)
		if not (targets_variant is Array):
			continue
		var targets := targets_variant as Array
		_expect(
			targets == EXPECTED_MONSTER_DYNAMIC_TARGETS,
			"%s binds the exact sorted 20-target set" % dynamic_reference_id
		)
		var normalized_targets := PackedStringArray()
		for target_variant in targets:
			normalized_targets.append(str(target_variant))
		var computed_target_set_sha256 := _sha256_text("\n".join(normalized_targets))
		_expect(
			computed_target_set_sha256 == EXPECTED_MONSTER_DYNAMIC_TARGET_SET_SHA256,
			"%s target-set SHA-256 matches the exact paths" % dynamic_reference_id
		)
		_expect(
			str(entry.get("target_set_sha256", "")) == computed_target_set_sha256,
			"%s manifest hash matches the runtime target set" % dynamic_reference_id
		)
		var runtime_probe := entry.get("runtime_probe", {}) as Dictionary
		_expect(
			str(runtime_probe.get("test_path", "")) == "tests/gameplay_balance_diagnostics_monster_art_profile_test.gd"
				and int(runtime_probe.get("expected_target_count", -1)) == 20
				and bool(runtime_probe.get("required_before_production_claim", false)),
			"%s binds this required 20-target runtime probe" % dynamic_reference_id
		)
	var exists_count := 0
	var load_count := 0
	var texture2d_count := 0
	for target_variant in EXPECTED_MONSTER_DYNAMIC_TARGETS:
		var target_path := str(target_variant)
		if ResourceLoader.exists(target_path):
			exists_count += 1
		var resource := ResourceLoader.load(target_path)
		if resource != null:
			load_count += 1
		if resource is Texture2D:
			texture2d_count += 1
		_expect(resource != null, "%s loads as a non-null resource" % target_path)
		_expect(resource is Texture2D, "%s loads as Texture2D" % target_path)
	_expect(exists_count == 20, "all 20 monster-art targets exist through ResourceLoader")
	_expect(load_count == 20, "all 20 monster-art targets load as non-null resources")
	_expect(texture2d_count == 20, "all 20 monster-art targets load as Texture2D")
	var monster_art := MonsterArtViewScript.new() as Control
	_expect(monster_art != null, "real MonsterArtView instantiates")
	if monster_art == null:
		return
	root.add_child(monster_art)
	await process_frame
	var texture_map_variant: Variant = monster_art.get("moth_kaijuice_textures")
	_expect(texture_map_variant is Dictionary, "MonsterArtView exposes its loaded texture map")
	var texture_map: Dictionary = texture_map_variant if texture_map_variant is Dictionary else {}
	_expect(texture_map.size() == 20, "MonsterArtView _ready creates exactly 20 texture entries")
	var view_map_exact_count := 0
	for key_variant in EXPECTED_MONSTER_ART_VIEW_TARGET_BY_KEY:
		var sprite_key := str(key_variant)
		var expected_resource_path := str(EXPECTED_MONSTER_ART_VIEW_TARGET_BY_KEY[key_variant])
		_expect(texture_map.has(sprite_key), "MonsterArtView map contains %s" % sprite_key)
		if not texture_map.has(sprite_key):
			continue
		var texture_variant: Variant = texture_map[sprite_key]
		_expect(texture_variant is Texture2D, "MonsterArtView %s maps to Texture2D" % sprite_key)
		if not (texture_variant is Texture2D):
			continue
		var actual_resource_path := (texture_variant as Texture2D).resource_path
		_expect(
			actual_resource_path == expected_resource_path,
			"MonsterArtView %s binds exact resource path %s" % [sprite_key, expected_resource_path]
		)
		if actual_resource_path == expected_resource_path:
			view_map_exact_count += 1
	_expect(view_map_exact_count == 20, "MonsterArtView binds all 20 exact key-to-resource paths")
	print("MONSTER_DYNAMIC_REFERENCE_RUNTIME|target_count=20|exists=%d/20|load=%d/20|texture2d=%d/20|view_map_exact=%d/20" % [
		exists_count,
		load_count,
		texture2d_count,
		view_map_exact_count,
	])
	monster_art.queue_free()
	await process_frame


func _sha256_text(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()
