extends SceneTree

const MODEL_ROOT := "res://assets/third_party/commercial/models/quaternius"
const COMPONENT_ROOT := "res://scenes/tools/commercial_art/components/models"
const SOURCE_LEDGER_FILE_COUNT := 96
const SOURCE_LEDGER_SHA256 := "f2e03faa5de5d7117f1994fcdd6f91f2f09b9b320eb445b74ec19338e8341e1c"
const MAX_FILE_BYTES := 25 * 1024 * 1024
const MAX_MODEL_ROOT_BYTES := 150 * 1024 * 1024

const LICENSE_PATHS := [
	"res://assets/third_party/commercial/models/quaternius/modular_scifi_megakit/LICENSE_CC0.txt",
	"res://assets/third_party/commercial/models/quaternius/scifi_essentials/LICENSE_CC0.txt",
	"res://assets/third_party/commercial/models/quaternius/ultimate_monsters/LICENSE_CC0.txt",
	"res://assets/third_party/commercial/models/quaternius/animated_mech/LICENSE_CC0.txt",
	"res://assets/third_party/commercial/models/quaternius/ultimate_spaceships/LICENSE_CC0.txt",
]

const FACILITIES := [
	{
		"key": "model.facility.factory.base",
		"scene": "FacilityFactoryBase.tscn",
		"sources": ["Platform_DarkPlates.gltf", "Column_MetalSupport.gltf", "Column_Pipes.gltf", "Prop_Barrel_Large.gltf", "Enemy_EyeDrone.gltf"],
	},
	{
		"key": "model.facility.market.base",
		"scene": "FacilityMarketBase.tscn",
		"sources": ["Platform_Round1.gltf", "Prop_Computer.gltf", "Prop_AccessPoint.gltf", "Prop_Desk_Medium.gltf"],
	},
	{
		"key": "model.facility.warehouse.base",
		"scene": "FacilityWarehouseBase.tscn",
		"sources": ["Platform_Simple2.gltf", "Platform_Ramp_2Short.gltf", "Prop_Crate_Large.gltf", "Prop_Crate_Tarp_Large.gltf", "Prop_Shelves_WideShort.gltf"],
	},
	{
		"key": "model.facility.starport.base",
		"scene": "FacilityStarportBase.tscn",
		"sources": ["Platform_Metal2.gltf", "Prop_Rail_Round_Big.gltf", "Decal_XSign.gltf", "Prop_SatelliteDish.gltf", "Striker.gltf"],
	},
]

const MONSTERS := [
	{"key": "model.monster.life", "scene": "MonsterLife.tscn", "file": "Monkroose.gltf", "source": "Big/glTF/Monkroose.gltf", "category": "organic_mammalian"},
	{"key": "model.monster.energy", "scene": "MonsterEnergy.tscn", "file": "Ghost_Skull.gltf", "source": "Flying/glTF/Ghost_Skull.gltf", "category": "floating_spectral"},
	{"key": "model.monster.industry", "scene": "MonsterIndustry.tscn", "file": "Orc_Skull.gltf", "source": "Big/glTF/Orc_Skull.gltf", "category": "bulky_armored"},
	{"key": "model.monster.technology", "scene": "MonsterTechnology.tscn", "file": "Armabee_Evolved.gltf", "source": "Flying/glTF/Armabee_Evolved.gltf", "category": "insectoid_precision"},
	{"key": "model.monster.commerce", "scene": "MonsterCommerce.tscn", "file": "Squidle.gltf", "source": "Flying/glTF/Squidle.gltf", "category": "cephalopod_cunning"},
	{"key": "model.monster.shipping", "scene": "MonsterShipping.tscn", "file": "Dragon_Evolved.gltf", "source": "Flying/glTF/Dragon_Evolved.gltf", "category": "winged_aerial"},
]

const MECHS := [
	{"key": "model.military.tier1", "scene": "MilitaryTier1.tscn", "file": "Leela.gltf", "rank": 1, "volume": 41.752896644},
	{"key": "model.military.tier2", "scene": "MilitaryTier2.tscn", "file": "Mike.gltf", "rank": 2, "volume": 75.754419265},
	{"key": "model.military.tier3", "scene": "MilitaryTier3.tscn", "file": "Stan.gltf", "rank": 3, "volume": 86.626493402},
	{"key": "model.military.tier4", "scene": "MilitaryTier4.tscn", "file": "George.gltf", "rank": 4, "volume": 116.435224140},
]

const SHIPS := [
	{"key": "model.shipping.route_marker", "scene": "ShippingRouteMarker.tscn", "file": "Striker.gltf", "rank": 1, "volume": 113.866775381, "rule": "minimum_aabb_volume_of_11"},
	{"key": "model.shipping.convoy", "scene": "ShippingConvoy.tscn", "file": "Pancake.gltf", "rank": 6, "volume": 224.729249445, "rule": "median_aabb_volume_of_11"},
	{"key": "model.shipping.starport_showcase", "scene": "ShippingStarportShowcase.tscn", "file": "Omen.gltf", "rank": 11, "volume": 504.833458044, "rule": "maximum_aabb_volume_of_11"},
]

const SHIP_AABB_ORDER := [
	["Striker", 113.866775381],
	["Bob", 119.964840004],
	["Dispatcher", 155.331004938],
	["Executioner", 170.355206445],
	["Insurgent", 174.944601408],
	["Pancake", 224.729249445],
	["Spitfire", 242.209133127],
	["Challenger", 323.103418703],
	["Zenith", 368.806895614],
	["Imperial", 473.615224797],
	["Omen", 504.833458044],
]

var failures: Array[String] = []
var checks := 0
var loaded_model_count := 0
var loaded_component_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var probe_root := _option_value("--external-candidate-root=")
	if probe_root != "":
		await _run_external_aabb_probe(probe_root)
		quit(0)
		return

	_verify_licenses()
	_verify_local_source_ledger()
	await _verify_facilities()
	await _verify_monsters()
	await _verify_mechs()
	await _verify_ships()
	_verify_component_boundary()
	_finish()


func _verify_licenses() -> void:
	_expect(LICENSE_PATHS.size() == 5, "five selected Quaternius packs have one retained license each")
	for path in LICENSE_PATHS:
		_expect(FileAccess.file_exists(path), "%s exists" % path.get_file())
		var text := FileAccess.get_file_as_string(path)
		_expect(text.contains("CC0 1.0 Universal") and text.contains("creativecommons.org/publicdomain/zero/1.0"), "%s attests CC0 1.0" % path.get_base_dir().get_file())


func _verify_local_source_ledger() -> void:
	var files: Array[String] = []
	_collect_files(MODEL_ROOT, files)
	files = files.filter(func(path: String) -> bool:
		return path.get_extension().to_lower() in ["gltf", "bin", "png", "txt"]
	)
	files.sort()
	var ledger_lines: Array[String] = []
	var gltf_count := 0
	var source_bytes := 0
	for path in files:
		var length := FileAccess.get_file_as_bytes(path).size()
		source_bytes += length
		_expect(length > 0 and length <= MAX_FILE_BYTES, "%s is nonempty and within the 25 MB file ceiling" % path.get_file())
		ledger_lines.append("%s|%s" % [path.trim_prefix("res://"), FileAccess.get_sha256(path).to_lower()])
		if path.get_extension().to_lower() == "gltf":
			gltf_count += 1
			var source := FileAccess.get_file_as_string(path)
			_expect(not source.contains("http://") and not source.contains("https://"), "%s has no runtime network dependency" % path.get_file())
	var ledger := "\n".join(ledger_lines) + "\n"
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(ledger.to_utf8_buffer())
	var digest := hashing.finish().hex_encode()
	_expect(files.size() == SOURCE_LEDGER_FILE_COUNT, "selected and processed source ledger contains exactly %d files" % SOURCE_LEDGER_FILE_COUNT)
	_expect(gltf_count == 31, "only 31 selected facility, monster, mech, and ship glTF files are retained")
	_expect(source_bytes <= MAX_MODEL_ROOT_BYTES, "selected source footprint stays below 150 MB")
	_expect(digest == SOURCE_LEDGER_SHA256, "selected source ledger fingerprint is exact")


func _verify_facilities() -> void:
	for spec in FACILITIES:
		var scene_path := "%s/%s" % [COMPONENT_ROOT, spec.scene]
		var instance := await _instantiate_scene(scene_path)
		if instance == null:
			continue
		loaded_component_count += 1
		_expect(str(instance.get_meta("asset_key", "")) == spec.key, "%s exposes its stable asset key" % spec.scene)
		_expect(bool(instance.get_meta("presentation_only", false)), "%s remains presentation-only" % spec.scene)
		_expect(str(instance.get_meta("surface_normal_axis", "")) == "+Y", "%s orients to the planet surface normal through +Y" % spec.scene)
		var observed := _string_array(instance.get_meta("source_models", PackedStringArray()))
		_expect(observed == _string_array(spec.sources), "%s freezes the exact selected source file list" % spec.scene)
		var summary := _mesh_summary(instance)
		_expect(int(summary.mesh_count) >= 4 and bool(summary.nonzero), "%s instantiates a nonempty composed model" % spec.scene)
		instance.queue_free()
		await process_frame


func _verify_monsters() -> void:
	var seen_files: Dictionary = {}
	for spec in MONSTERS:
		var model_path := "%s/ultimate_monsters/gltf/%s" % [MODEL_ROOT, spec.file]
		var model := await _instantiate_scene(model_path)
		if model != null:
			loaded_model_count += 1
			var summary := _mesh_summary(model)
			_expect(int(summary.mesh_count) > 0 and int(summary.animation_count) >= 8, "%s preserves mesh and source animations" % spec.file)
			model.queue_free()
			await process_frame
		var wrapper := await _instantiate_scene("%s/%s" % [COMPONENT_ROOT, spec.scene])
		if wrapper == null:
			continue
		loaded_component_count += 1
		_expect(str(wrapper.get_meta("asset_key", "")) == spec.key, "%s exposes its stable asset key" % spec.scene)
		_expect(str(wrapper.get_meta("source_file", "")) == spec.source, "%s freezes its upstream source path" % spec.scene)
		_expect(str(wrapper.get_meta("silhouette_category", "")) == spec.category, "%s freezes its silhouette category" % spec.scene)
		_expect(bool(wrapper.get_meta("animation_preserved", false)) and bool(wrapper.get_meta("low_scale_billboard", false)), "%s preserves animation and includes a low-scale billboard" % spec.scene)
		seen_files[spec.file] = true
		wrapper.queue_free()
		await process_frame
	_expect(seen_files.size() == 6, "six distinct Ultimate Monsters source files cover six gameplay categories")


func _verify_mechs() -> void:
	var imported_volumes: Array[float] = []
	for spec in MECHS:
		var model_path := "%s/animated_mech/gltf/%s" % [MODEL_ROOT, spec.file]
		var model := await _instantiate_scene(model_path)
		if model != null:
			loaded_model_count += 1
			var summary := _mesh_summary(model)
			_expect(int(summary.mesh_count) > 0 and int(summary.animation_count) >= 18, "%s preserves textured mesh and source animations" % spec.file)
			imported_volumes.append(float(summary.volume))
			model.queue_free()
			await process_frame
		var wrapper := await _instantiate_scene("%s/%s" % [COMPONENT_ROOT, spec.scene])
		if wrapper == null:
			continue
		loaded_component_count += 1
		_expect(str(wrapper.get_meta("asset_key", "")) == spec.key and int(wrapper.get_meta("aabb_rank", 0)) == int(spec.rank), "%s freezes deterministic tier mapping" % spec.scene)
		_expect(is_equal_approx(float(wrapper.get_meta("aabb_volume", 0.0)), float(spec.volume)), "%s retains measured source AABB volume" % spec.scene)
		_expect(str(wrapper.get_meta("player_color_surfaces", "")) == "base_ring,shoulder_markers_only", "%s confines player color to the base and shoulder markers" % spec.scene)
		wrapper.queue_free()
		await process_frame
	_expect(_strictly_increasing(imported_volumes), "Godot-imported mech AABB volumes are strictly tier1 through tier4")


func _verify_ships() -> void:
	var source_volumes: Array[float] = []
	for row in SHIP_AABB_ORDER:
		source_volumes.append(float(row[1]))
	_expect(SHIP_AABB_ORDER.size() == 11 and _strictly_increasing(source_volumes), "eleven-source ship AABB evidence is strictly ordered")
	_expect(str(SHIP_AABB_ORDER[0][0]) == "Striker" and str(SHIP_AABB_ORDER[5][0]) == "Pancake" and str(SHIP_AABB_ORDER[10][0]) == "Omen", "minimum, median, and maximum ship selections are exact")
	for spec in SHIPS:
		var model := await _instantiate_scene("%s/ultimate_spaceships/gltf/%s" % [MODEL_ROOT, spec.file])
		if model != null:
			loaded_model_count += 1
			var summary := _mesh_summary(model)
			_expect(int(summary.mesh_count) > 0 and float(summary.volume) > 0.0, "%s imports as a nonempty ship" % spec.file)
			model.queue_free()
			await process_frame
		var wrapper := await _instantiate_scene("%s/%s" % [COMPONENT_ROOT, spec.scene])
		if wrapper == null:
			continue
		loaded_component_count += 1
		_expect(str(wrapper.get_meta("asset_key", "")) == spec.key, "%s exposes its stable asset key" % spec.scene)
		_expect(int(wrapper.get_meta("aabb_rank", 0)) == int(spec.rank) and str(wrapper.get_meta("selection_rule", "")) == spec.rule, "%s freezes its deterministic size selection" % spec.scene)
		_expect(not bool(wrapper.get_meta("authoritative_route_owner", true)), "%s is never an authoritative route Owner" % spec.scene)
		wrapper.queue_free()
		await process_frame


func _verify_component_boundary() -> void:
	var component_files: Array[String] = []
	_collect_files(COMPONENT_ROOT, component_files)
	var scene_count := 0
	for path in component_files:
		if path.get_extension().to_lower() != "tscn":
			continue
		scene_count += 1
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("scripts/runtime") and not source.contains("GameRuntimeCoordinator") and not source.contains("SaveOwner") and not source.contains("Rng") and not source.contains("AiRuntime"), "%s has no gameplay, Save, RNG, or AI Owner dependency" % path.get_file())
	_expect(scene_count == 18, "model component boundary contains one pedestal and exactly 17 stable-key scenes")
	_expect(loaded_component_count == 17, "all 17 stable-key model component scenes load")
	_expect(loaded_model_count == 13, "six monsters, four mechs, and three ships load through Godot")


func _instantiate_scene(path: String) -> Node:
	_expect(ResourceLoader.exists(path), "%s exists" % path.get_file())
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s imports as PackedScene" % path.get_file())
	if packed == null:
		return null
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	return instance


func _mesh_summary(node: Node) -> Dictionary:
	var aabb := AABB()
	var has_aabb := false
	var mesh_count := 0
	var animation_count := 0
	var root_3d := node as Node3D
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_count += 1
		var child_aabb := mesh_instance.get_aabb()
		if root_3d != null:
			child_aabb = (root_3d.global_transform.affine_inverse() * mesh_instance.global_transform) * child_aabb
		if has_aabb:
			aabb = aabb.merge(child_aabb)
		else:
			aabb = child_aabb
			has_aabb = true
	for child in node.find_children("*", "AnimationPlayer", true, false):
		animation_count += (child as AnimationPlayer).get_animation_list().size()
	var volume := 0.0
	if has_aabb:
		volume = aabb.size.x * aabb.size.y * aabb.size.z
	return {
		"mesh_count": mesh_count,
		"animation_count": animation_count,
		"nonzero": has_aabb and aabb.size.x > 0.0 and aabb.size.y > 0.0 and aabb.size.z > 0.0,
		"aabb": aabb,
		"volume": volume,
	}


func _run_external_aabb_probe(probe_root: String) -> void:
	var groups := {
		"mech": [
			"quaternius.animated_mech/Textured/glTF/Leela.gltf",
			"quaternius.animated_mech/Textured/glTF/Mike.gltf",
			"quaternius.animated_mech/Textured/glTF/Stan.gltf",
			"quaternius.animated_mech/Textured/glTF/George.gltf",
		],
		"ship": [
			"quaternius.ultimate_spaceships/Striker/glTF/Striker.gltf",
			"quaternius.ultimate_spaceships/Bob/glTF/Bob.gltf",
			"quaternius.ultimate_spaceships/Dispatcher/glTF/Dispatcher.gltf",
			"quaternius.ultimate_spaceships/Executioner/glTF/Executioner.gltf",
			"quaternius.ultimate_spaceships/Insurgent/glTF/Insurgent.gltf",
			"quaternius.ultimate_spaceships/Pancake/glTF/Pancake.gltf",
			"quaternius.ultimate_spaceships/Spitfire/glTF/Spitfire.gltf",
			"quaternius.ultimate_spaceships/Challenger/glTF/Challenger.gltf",
			"quaternius.ultimate_spaceships/Zenith/glTF/Zenith.gltf",
			"quaternius.ultimate_spaceships/Imperial/glTF/Imperial.gltf",
			"quaternius.ultimate_spaceships/Omen/glTF/Omen.gltf",
		],
	}
	for group in groups:
		var rows: Array[Dictionary] = []
		for relative_path in groups[group]:
			var path := probe_root.path_join(relative_path)
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			var error := document.append_from_file(path, state)
			if error != OK:
				push_error("External probe failed for %s: %s" % [path, error_string(error)])
				quit(1)
				return
			var scene := document.generate_scene(state)
			root.add_child(scene)
			await process_frame
			var summary := _mesh_summary(scene)
			rows.append({"name": relative_path.get_file().get_basename(), "volume": float(summary.volume), "size": (summary.aabb as AABB).size})
			scene.queue_free()
			await process_frame
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.volume) < float(b.volume))
		for index in rows.size():
			var row := rows[index]
			var size := row.size as Vector3
			print("COMMERCIAL_MODEL_AABB_PROBE|%s|rank=%d|name=%s|volume=%.9f|size=%.6f,%.6f,%.6f" % [group, index + 1, row.name, row.volume, size.x, size.y, size.z])


func _option_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _collect_files(path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := path.path_join(name)
			if directory.current_is_dir():
				_collect_files(child, output)
			else:
				output.append(child)
		name = directory.get_next()
	directory.list_dir_end()


func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			output.append(str(item))
	return output


func _strictly_increasing(values: Array[float]) -> bool:
	if values.size() < 2:
		return false
	for index in range(1, values.size()):
		if values[index] <= values[index - 1]:
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures.is_empty():
		print("COMMERCIAL_MODEL_ASSET_CONTRACT: PASS (%d checks)" % checks)
		quit(0)
		return
	print("COMMERCIAL_MODEL_ASSET_CONTRACT: FAIL (%d/%d failed)" % [failures.size(), checks])
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
