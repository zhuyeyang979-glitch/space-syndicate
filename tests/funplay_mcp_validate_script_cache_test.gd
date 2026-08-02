extends SceneTree

const TARGET_PATHS := [
	"res://scripts/runtime/closed_save_scalar_codec_v1.gd",
	"res://scripts/runtime/card_inventory_save_owner.gd",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	for path in TARGET_PATHS:
		var first := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		_expect(first != null, "canonical script loads: %s" % path)
		if first == null:
			continue
		var live_instance = first.new()
		_expect(live_instance != null, "canonical script creates a live instance: %s" % path)
		var source := FileAccess.get_file_as_string(path)
		first.source_code = source
		_expect(first.reload(true) == OK, "canonical script reloads with live state: %s" % path)
		var second := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		_expect(second == first, "ResourceCache returns one script instance: %s" % path)
		if live_instance is Node:
			live_instance.free()

	print("MCP_VALIDATE_SCRIPT_CACHE_TESTS|passed=%d|total=%d" % [
		_checks - _failures.size(),
		_checks,
	])
	if not _failures.is_empty():
		for failure in _failures:
			push_error("Funplay MCP validate-script cache contract failed: %s" % failure)
		quit(1)
		return
	quit(0)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
