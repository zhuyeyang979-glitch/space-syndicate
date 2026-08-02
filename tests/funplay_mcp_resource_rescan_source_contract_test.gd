extends SceneTree

const SCRIPT_PATHS := [
	"res://addons/funplay_mcp/plugin.gd",
	"res://addons/funplay_mcp/core/funplay_filesystem_reload_state.gd",
	"res://addons/funplay_mcp/core/funplay_core_tools.gd",
	"res://addons/funplay_mcp/core/funplay_http_transport.gd",
	"res://addons/funplay_mcp/core/funplay_mcp_request_handler.gd",
	"res://addons/funplay_mcp/core/funplay_mcp_server.gd",
	"res://addons/funplay_mcp/core/funplay_tool_registry.gd",
	"res://addons/funplay_mcp/core/funplay_resource_provider.gd",
	"res://addons/funplay_mcp/core/funplay_prompt_provider.gd",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	for path in SCRIPT_PATHS:
		var script = load(path)
		_expect(
			script != null and script is Script and script.can_instantiate(),
			"MCP script compiles and can instantiate: %s" % path
		)

	var core_source := _read("res://addons/funplay_mcp/core/funplay_core_tools.gd")
	var request_block := _function_block(core_source, "func request_script_reload(")
	var refresh_block := _function_block(core_source, "func _refresh_filesystem(")
	var execute_block := _function_block(core_source, "func _execute_filesystem_reload(")
	_expect(request_block.contains("_filesystem_reload_state.request_reload("), "reload handler only registers an operation")
	_expect(request_block.contains('"mcp_request_id_required"'), "reload handler rejects a missing mutation request id")
	_expect(not request_block.contains('arguments.get("_mcp_http_request_id"'), "reload handler never substitutes an HTTP request id")
	_expect(not request_block.contains("resource_filesystem.scan()"), "reload handler never scans synchronously")
	_expect(not refresh_block.contains("resource_filesystem.scan()"), "legacy refresh helper delegates to state owner")
	_expect(execute_block.contains("resource_filesystem.scan()"), "single execution function owns EditorFileSystem.scan")
	_expect(execute_block.contains("_filesystem_execution_active = true"), "scan execution raises the nested-frame guard")
	_expect(core_source.contains("func _publish_filesystem_readiness("), "state owner publishes out-of-band initial readiness")
	_expect(core_source.contains("FunplayMcpFilesystemReadinessV1"), "readiness sentinel has a typed schema")
	var validate_block := _function_block(core_source, "func validate_gdscript_file(")
	_expect(not validate_block.contains("script.resource_path = path"), "validation never replaces an already cached production resource path")
	_expect(validate_block.contains('"resource_path": path'), "validation reports the requested production path without registering it")
	var state_source := _read("res://addons/funplay_mcp/core/funplay_filesystem_reload_state.gd")
	_expect(state_source.contains("DEFAULT_INITIAL_SCAN_TIMEOUT_MSEC := 300000"), "state owner allows the bounded full-project import window")

	var plugin_source := _read("res://addons/funplay_mcp/plugin.gd")
	var process_block := _function_block(plugin_source, "func _process(")
	_expect(
		process_block.find("process_pending_filesystem_reload()") >= 0
			and process_block.find("process_pending_filesystem_reload()") < process_block.find("_server.poll()"),
		"queued reload executes on a later top-level plugin tick"
	)
	_expect(process_block.contains("is_filesystem_reload_execution_active()"), "nested editor frames skip HTTP polling during scan")
	_expect(plugin_source.count("FunplayCoreTools.new(") == 1, "plugin constructs one shared filesystem state owner")
	_expect(plugin_source.contains("FunplayResourceProvider.new(self, _settings, _core_tools)"), "resource provider shares the state owner")
	_expect(plugin_source.contains("FunplayPromptProvider.new(self, _settings, _core_tools)"), "prompt provider shares the state owner")

	var transport_source := _read("res://addons/funplay_mcp/core/funplay_http_transport.gd")
	var poll_once_block := _function_block(transport_source, "func _poll_once(")
	_expect(
		poll_once_block.find("_connections.remove_at(index)") >= 0
			and poll_once_block.find("_connections.remove_at(index)") < poll_once_block.find("request_callback.call("),
		"transport claims and removes a connection before dispatch"
	)
	_expect(transport_source.contains("if _poll_active:"), "transport suppresses nested poll")
	_expect(transport_source.contains('"max_handler_depth"'), "transport exposes handler depth evidence")

	var launcher_source := _read("res://tools/launch_role_godot_mcp.ps1")
	_expect(launcher_source.contains('name = "filesystem_scan_status"'), "launcher queries filesystem readiness")
	_expect(launcher_source.contains("initial_scan_completed"), "launcher waits for initial scan completion")
	_expect(launcher_source.contains('"opengl3"'), "launcher defaults compatibility validation to native OpenGL")
	_expect(launcher_source.contains("StartupTimeoutSeconds = 300"), "launcher uses a bounded full-project startup timeout")
	_expect(launcher_source.contains("active-session.json"), "launcher isolates and records one session instance")
	_expect(launcher_source.contains("funplay_mcp_filesystem_readiness.json"), "launcher watches the isolated readiness sentinel")
	_expect(
		launcher_source.find("initial_scan_completed") < launcher_source.find("Invoke-RestMethod"),
		"launcher sends no HTTP request before out-of-band initial readiness"
	)
	_expect(launcher_source.contains("http_request_count_before_readiness = 0"), "connection evidence attests zero pre-readiness HTTP requests")
	_expect(launcher_source.contains("InitialReadyStabilitySeconds = 15"), "launcher holds a bounded post-import stability window")
	_expect(launcher_source.contains('"TEMP" = $tempRoot'), "launcher isolates editor temporary files per session")
	_expect(launcher_source.contains("[System.IO.Path]::GetTempPath()"), "launcher uses a short machine-local runtime-data base")
	_expect(launcher_source.contains("MCP_RUNTIME_DATA_PATH_TOO_LONG"), "launcher rejects runtime-data paths without shader-cache headroom")
	_expect(launcher_source.contains("runtime_data_root = $runtimeDataRoot"), "connection evidence records the isolated runtime-data root")
	var common_source := _read("res://tools/role_godot_mcp_common.ps1")
	_expect(common_source.contains("[System.IO.FileShare]::ReadWrite"), "native exit evidence tolerates a writer-held Godot log")
	_expect(common_source.contains("$ExitCode -eq -1073741819"), "native exit evidence maps Windows access violations to signal 11")

	var invoke_source := _read("res://tools/invoke_role_godot_mcp.ps1")
	_expect(invoke_source.contains('[guid]::NewGuid().ToString("N")'), "wrapper assigns unique JSON-RPC IDs")
	_expect(invoke_source.contains("MCP_EDITOR_PROCESS_EXITED"), "wrapper reports typed editor exit")
	_expect(not invoke_source.contains("id = 1"), "wrapper no longer reuses JSON-RPC id 1")
	_expect(invoke_source.contains("MCP_REQUEST_ID_REQUIRED"), "wrapper requires caller-owned mutation request ids")
	_expect(not invoke_source.contains('$arguments["request_id"] = $jsonRpcRequestId'), "wrapper never invents mutation request ids")

	var handler_source := _read("res://addons/funplay_mcp/core/funplay_mcp_request_handler.gd")
	for tool_name in ["request_script_reload", "request_project_reload", "request_filesystem_scan", "stop_editor"]:
		_expect(handler_source.contains('"%s"' % tool_name), "request-id protocol covers %s" % tool_name)

	var registry_source := _read("res://addons/funplay_mcp/core/funplay_tool_registry.gd")
	_expect(registry_source.contains('"required": ["request_id"]'), "reload JSON schema requires request_id")

	var stop_source := _read("res://tools/stop_role_godot_mcp.ps1")
	_expect(stop_source.contains("[string]$RequestId"), "stop wrapper requires an explicit request id")
	_expect(stop_source.contains("Test-McpProcessIdentity"), "stop wrapper validates process identity before closing")
	_finish()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


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
	print("MCP_RESCAN_SOURCE_CONTRACT_TESTS|passed=%d|total=%d" % [
		_checks - _failures.size(),
		_checks,
	])
	if not _failures.is_empty():
		for failure in _failures:
			push_error("Funplay MCP rescan source contract failed: %s" % failure)
		quit(1)
		return
	quit(0)
