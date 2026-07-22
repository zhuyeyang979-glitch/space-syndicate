extends Node

const HOST_SCENE := preload("res://scenes/runtime/presentation/DeveloperBalanceApplicationHost.tscn")

@export var auto_run := true
@export var auto_quit_after_bench := false

var _checks := 0
var _failures: Array[String] = []
var _run_started := false
var _last_result: Dictionary = {}
var _original_mount_env := ""
var _original_presentation_env := ""


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("_run_auto_bench")


func _run_auto_bench() -> void:
	var result := run_bench()
	if auto_quit_after_bench:
		get_tree().quit(0 if bool(result.get("passed", false)) else 1)


func run_bench() -> Dictionary:
	if _run_started:
		return _last_result.duplicate(true)
	_run_started = true
	_original_mount_env = OS.get_environment(DeveloperBalanceApplicationHost.PANEL_MOUNT_ENV)
	_original_presentation_env = OS.get_environment(DeveloperBalancePresentationTarget.DEVELOPER_PRESENTATION_ENV)
	OS.set_environment(DeveloperBalanceApplicationHost.PANEL_MOUNT_ENV, "")
	OS.set_environment(DeveloperBalancePresentationTarget.DEVELOPER_PRESENTATION_ENV, "")
	var host := get_node_or_null("DeveloperBalanceApplicationHost") as DeveloperBalanceApplicationHost
	var panel_parent := get_node_or_null("PanelHost") as Control
	var target := get_node_or_null("DeveloperBalancePresentationTarget") as DeveloperBalancePresentationTarget
	_check(host != null and panel_parent != null and target != null, "real Host scene, panel parent, and existing target load")
	if host == null or panel_parent == null or target == null:
		return _finish()

	var disabled := host.mount_if_requested()
	_check(not bool(disabled.get("mounted", true)), "disabled developer environment mounts no panel")
	_check(panel_parent.get_node_or_null("DeveloperBalancePanel") == null, "disabled environment leaves the overlay host empty")
	_check(not target.enabled, "disabled environment leaves the developer target disabled")

	OS.set_environment(DeveloperBalanceApplicationHost.PANEL_MOUNT_ENV, "1")
	var mounted := host.mount_if_requested()
	var panel := panel_parent.get_node_or_null("DeveloperBalancePanel") as DeveloperBalancePanel
	_check(bool(mounted.get("mounted", false)) and panel != null, "mount gate creates the real DeveloperBalancePanel")
	_check(panel != null and panel.visible, "mounted panel is visible")
	_check(target.enabled and not target.is_available(), "mount enables the target while the independent release-safety gate remains closed")
	_check(panel_parent.get_child_count() == 1, "mount creates exactly one panel")

	var mounted_again := host.mount_if_requested()
	_check(bool(mounted_again.get("mounted", false)) and str(mounted_again.get("reason", "")) == "already_mounted", "repeated mount is idempotent")
	_check(panel_parent.get_child_count() == 1, "repeated mount does not duplicate the panel")
	var host_debug := host.debug_snapshot()
	_check(int(host_debug.get("mount_count", 0)) == 1 and int(host_debug.get("bind_count", 0)) == 1, "mount and target binding occur exactly once")
	_check(not bool(host_debug.get("owns_gameplay_state", true)) and not bool(host_debug.get("owns_diagnostics_report", true)), "Host owns neither gameplay nor diagnostics data")

	OS.set_environment(DeveloperBalancePresentationTarget.DEVELOPER_PRESENTATION_ENV, "1")
	_check(target.is_available(), "debug target becomes available only after its explicit presentation gate")
	var snapshot := DeveloperBalancePresentationSnapshot.new()
	snapshot.revision = 1
	snapshot.enabled = true
	snapshot.report = {
		"version": "host-bench-v1",
		"summary": {
			"target_min_minutes": 30.0,
			"target_max_minutes": 60.0,
			"card_vector_count": 12,
			"product_count": 8,
			"monster_family_count": 6,
			"ai_route_count": 4,
			"environment_depth_count": 3,
		},
		"constraints": {"issue_count": 0, "issues": []},
	}
	var target_revision := target.apply_developer_presentation(snapshot)
	var title := panel.get_node_or_null("DeveloperBalanceMargin/DeveloperBalanceRows/DeveloperBalanceTitle") as Label if panel != null else null
	_check(target_revision == 1, "existing developer target applies one typed snapshot")
	_check(title != null and title.text.contains("host-bench-v1"), "typed target updates the mounted real panel")
	_check(int(target.debug_snapshot().get("apply_count", 0)) == 1, "typed target apply remains exact once")

	var missing_parent := HOST_SCENE.instantiate() as DeveloperBalanceApplicationHost
	missing_parent.auto_mount = false
	missing_parent.name = "MissingParentHost"
	add_child(missing_parent)
	var missing_parent_result := missing_parent.mount_if_requested()
	_check(not bool(missing_parent_result.get("mounted", true)) and str(missing_parent_result.get("reason", "")) == "developer_balance_panel_parent_missing", "missing panel parent fails closed")
	_check(int(missing_parent.debug_snapshot().get("failure_count", 0)) == 1, "missing dependency records one bounded failure")

	var missing_target := HOST_SCENE.instantiate() as DeveloperBalanceApplicationHost
	missing_target.auto_mount = false
	missing_target.name = "MissingTargetHost"
	missing_target.panel_parent_path = NodePath("../PanelHost")
	add_child(missing_target)
	var child_count_before := panel_parent.get_child_count()
	var missing_target_result := missing_target.mount_if_requested()
	_check(not bool(missing_target_result.get("mounted", true)) and str(missing_target_result.get("reason", "")) == "developer_balance_presentation_target_missing", "missing presentation target fails closed")
	_check(panel_parent.get_child_count() == child_count_before, "failed target validation creates no partial panel")

	var host_source := FileAccess.get_file_as_string("res://scripts/presentation/developer_balance_application_host.gd")
	_check(not host_source.contains("scripts/" + "main.gd") and not host_source.contains("/root/" + "Main") and not host_source.contains("current_scene"), "Host has no Main or service-locator fallback")
	_check(not host_source.contains("build_developer_panel_snapshot") and not host_source.contains("set_diagnostics_service"), "Host cannot build or own a diagnostics report")
	_check(host_source.contains("DeveloperBalancePresentationTarget") and host_source.contains("target.bind_panel(panel)"), "Host binds only the existing typed target")
	_check(_is_pure_data(host.debug_snapshot()), "Host diagnostics remain detached pure data")
	return _finish()


func _is_pure_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for item in value as Array:
				if not _is_pure_data(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in (value as Dictionary).keys():
				if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
					return false
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _restore_environment() -> void:
	OS.set_environment(DeveloperBalanceApplicationHost.PANEL_MOUNT_ENV, _original_mount_env)
	OS.set_environment(DeveloperBalancePresentationTarget.DEVELOPER_PRESENTATION_ENV, _original_presentation_env)


func _finish() -> Dictionary:
	_restore_environment()
	_last_result = {
		"passed": _failures.is_empty(),
		"checks": _checks,
		"failures": _failures.duplicate(),
		"mcp_scene": "res://scenes/tools/DeveloperBalanceApplicationHostBench.tscn",
	}
	print("DeveloperBalanceApplicationHostBench: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("DeveloperBalanceApplicationHostBench failures:\n- " + "\n- ".join(_failures))
	return _last_result.duplicate(true)
