extends SceneTree

const BANNED_MAIN_SYMBOLS := [
	"func _refresh_live_ui", "func _refresh_board", "func _refresh_ui",
	"func _refresh_developer_balance_greybox", "func _runtime_table_snapshot_source",
	"func _runtime_table_viewmodel_source", "func _set_map_view_data", "func _log(",
]

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	for symbol in BANNED_MAIN_SYMBOLS:
		_check(not main_source.contains(symbol), "Main removed presentation symbol: %s" % symbol)
	_check(main_source.contains("advance_table_presentation(delta)"), "Main delegates one high-level presentation frame")
	_check(not main_source.contains("advance_presentation_refresh_cadence"), "Main does not consume cadence receipts")
	_check(not main_source.contains("for refresh_kind"), "Main does not iterate refresh receipt kinds")
	var port_source := FileAccess.get_file_as_string("res://scripts/presentation/table_presentation_refresh_port.gd")
	var source_owner := FileAccess.get_file_as_string("res://scripts/presentation/table_presentation_source_owner.gd")
	var root_main_token := "/root/" + "Main"
	_check(not port_source.contains(root_main_token) and not port_source.contains("current_scene"), "refresh port has no Main discovery")
	_check(not source_owner.contains(root_main_token) and not source_owner.contains("current_scene") and not source_owner.contains("WorldSessionState"), "source owner uses narrow query ports only")
	_check(port_source.contains("authorization_revision") and port_source.contains("presentation_viewer_unauthorized"), "refresh port validates viewer authorization revisions")
	_check(not FileAccess.get_file_as_string("res://scripts/presentation/public_log_producer_port.gd").contains("legacy_public"), "public log accepts typed receipts only")
	_check(not main_source.contains("record_legacy_public_log_message") and main_source.contains("record_legacy_viewer_feedback"), "Main legacy feedback no longer enters the public log")
	_check(not FileAccess.file_exists("res://scripts/runtime/runtime_loop.gd") and not FileAccess.file_exists("res://scenes/runtime/RuntimeLoop.tscn"), "RuntimeLoop is not created by this cutover")
	_check(_production_instance_count("TablePresentationRefreshScheduler") == 1, "one production cadence owner is composed")
	_check(_production_instance_count("TablePresentationSourceOwner") == 1, "one production source owner is composed")
	_check(_production_instance_count("TablePresentationRefreshPort") == 1, "one production refresh port is composed")
	print("table_presentation_source_target_cutover_test: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _production_instance_count(node_name: String) -> int:
	var source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	return source.count("[node name=\"%s\"" % node_name)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
