extends SceneTree

const VICTORY_SCRIPT := preload("res://scripts/runtime/victory_control_runtime_controller.gd")
const PRODUCTION_ROOTS := [
	"res://scripts/runtime",
	"res://scripts/ui",
	"res://scripts/viewmodels",
	"res://scenes/runtime",
	"res://scenes/ui",
	"res://data/scenarios",
	"res://data/campaigns",
	"res://resources",
	"res://localization",
]
const FORBIDDEN_TOKENS := [
	"city_share_changed",
	"project_share_changed",
	"urbanization_share",
	"city_development_resolved",
	"own_project_shares",
	"contract_target_project_ids",
	"城市份额",
	"项目份额",
]
const PRODUCTION_LEGACY_PATHS := [
	"res://scripts/runtime/city_development_runtime_controller.gd",
	"res://scripts/runtime/city_development_world_bridge.gd",
	"res://scenes/runtime/CityDevelopmentRuntimeController.tscn",
	"res://scenes/runtime/CityDevelopmentWorldBridge.tscn",
	"res://scripts/economy/city_product_project_state.gd",
	"res://scripts/economy/city_product_project_bridge.gd",
	"res://scripts/economy/city_project_state_migration_v04_to_v05.gd",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_check_production_source_surface()
	_check_region_control_semantics()
	_finish()


func _check_production_source_surface() -> void:
	for path in PRODUCTION_LEGACY_PATHS:
		_expect(not ResourceLoader.exists(path) and not FileAccess.file_exists(path), "legacy production path is absent: %s" % path)
	var hits: Array[String] = []
	for root in PRODUCTION_ROOTS:
		_scan_directory(root, hits)
	_expect(hits.is_empty(), "production source contains no legacy city/project-share signal surface: %s" % ", ".join(hits))


func _check_region_control_semantics() -> void:
	var controller := VICTORY_SCRIPT.new()
	_expect(controller != null, "VictoryControlRuntimeController script instantiates")
	if controller == null:
		return
	root.add_child(controller)
	var below: Dictionary = controller.call("region_control_snapshot", _region(10000, {0: 2999, 1: 2000}))
	var threshold: Dictionary = controller.call("region_control_snapshot", _region(10000, {0: 3000, 1: 2999}))
	var tie: Dictionary = controller.call("region_control_snapshot", _region(6000, {0: 3000, 1: 3000}))
	_expect(str(threshold.get("snapshot_kind", "")) == "commodity_gdp_region_control" and not str(threshold.get("revision", "")).is_empty(), "region control snapshot is typed and revisioned")
	_expect(int(below.get("controller_player_index", -1)) == -1, "a unique 29.99 percent commodity GDP leader does not control")
	_expect(int(threshold.get("controller_player_index", -1)) == 0, "a unique 30 percent commodity GDP leader controls")
	_expect(int(tie.get("controller_player_index", -1)) == -1, "an exact highest commodity GDP tie has no controller")
	var encoded := JSON.stringify(threshold)
	_expect(encoded.contains("commodity_gdp_share_basis_points") and not encoded.contains("\"city_share\"") and not encoded.contains("\"project_share\""), "typed control snapshot uses commodity GDP terminology only")
	controller.queue_free()


func _region(total_cents: int, by_player: Dictionary) -> Dictionary:
	return {
		"region_id": "region.audit",
		"district_index": 0,
		"region_revision": 7,
		"lifecycle_state": "active",
		"region_gdp_per_minute_cents": total_cents,
		"player_gdp_by_index": by_player,
	}


func _scan_directory(root_path: String, hits: Array[String]) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var path := root_path.path_join(name)
		if directory.current_is_dir():
			_scan_directory(path, hits)
			continue
		if path.get_extension().to_lower() not in ["gd", "tscn", "tres", "json", "csv", "translation"]:
			continue
		var source := FileAccess.get_file_as_string(path)
		for token in FORBIDDEN_TOKENS:
			if source.contains(token):
				hits.append("%s:%s" % [path, token])
	directory.list_dir_end()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("LEGACY_CITY_SHARE_SURFACE_NEGATIVE_V06_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	for failure in _failures:
		push_error(failure)
	quit(_failures.size())
