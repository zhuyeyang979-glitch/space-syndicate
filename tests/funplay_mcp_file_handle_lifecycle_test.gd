extends SceneTree

const CORE_TOOLS_PATH := "res://addons/funplay_mcp/core/funplay_core_tools.gd"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var file := FileAccess.open(CORE_TOOLS_PATH, FileAccess.READ)
	_expect(file != null, "Funplay core tools source is readable")
	if file == null:
		_finish()
		return
	var source := file.get_as_text()
	file.close()

	var write_block := _function_block(source, "func write_file(")
	var preflight_index := write_block.find("_scene_write_preflight_error(path)")
	var write_open_index := write_block.find("FileAccess.open(path, FileAccess.WRITE)")
	var store_index := write_block.find("file.store_string(content)")
	var flush_index := write_block.find("file.flush()")
	var close_index := write_block.find("file.close()")
	var sync_index := write_block.find("_synchronize_editor_after_file_write(path)")
	var refresh_index := write_block.find("_refresh_filesystem()")
	_expect(preflight_index >= 0 and write_open_index > preflight_index, "write_file rejects unsafe open-scene writes before opening the disk file")
	_expect(store_index > write_open_index and flush_index > store_index and close_index > flush_index, "write_file flushes and closes its write handle")
	_expect(sync_index > close_index and refresh_index > sync_index, "write_file synchronizes an open scene before filesystem refresh")

	var preflight_block := _function_block(source, "func _scene_write_preflight_error(")
	_expect(preflight_block.contains("get_unsaved_scenes().has(path)"), "scene write preflight refuses to overwrite unsaved editor state")
	var sync_block := _function_block(source, "func _synchronize_editor_after_file_write(")
	_expect(sync_block.contains("reload_scene_from_path(path)"), "clean open scenes reload automatically after MCP disk writes")

	var patch_block := _function_block(source, "func patch_script(")
	var read_index := patch_block.find("var content = file.get_as_text()")
	var patch_close_index := patch_block.find("file.close()")
	var nested_write_index := patch_block.find("return write_file(")
	_expect(read_index >= 0 and patch_close_index > read_index and nested_write_index > patch_close_index, "patch_script closes its read handle before nested write")
	_finish()


func _function_block(source: String, marker: String) -> String:
	var start := source.find(marker)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + marker.length())
	if finish < 0:
		finish = source.length()
	return source.substr(start, finish - start)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Funplay MCP file handle lifecycle passed: %d/%d" % [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("Funplay MCP file handle lifecycle failed: %d issue(s) across %d checks" % [_failures.size(), _checks])
	quit(1)