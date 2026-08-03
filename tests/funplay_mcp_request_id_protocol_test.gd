extends SceneTree

const RequestHandler := preload("res://addons/funplay_mcp/core/funplay_mcp_request_handler.gd")

var _passed := 0
var _total := 0
var _failures: Array[String] = []


class FakeSettings:
	extends RefCounted
	var tool_profile := "core"


class FakeRegistry:
	extends RefCounted
	var call_count := 0
	var result_text := '{"ok":true,"operation_id":"filesystem-reload-1"}'

	func has_tool(name: String) -> bool:
		return name in ["request_script_reload", "validate_script", "open_scene"]

	func is_tool_allowed(_name: String, _profile: String) -> bool:
		return true

	func call_tool(_name: String, _arguments: Dictionary) -> String:
		call_count += 1
		return result_text

	func is_import_quiescent() -> bool:
		return false

	func is_tool_allowed_before_import_quiescence(name: String) -> bool:
		return name == "request_script_reload"


class FakeProvider:
	extends RefCounted


func _init() -> void:
	var registry = FakeRegistry.new()
	var handler = RequestHandler.new(
		FakeSettings.new(),
		registry,
		FakeProvider.new(),
		FakeProvider.new(),
		"Funplay MCP",
		"0.9.6+alpha04c.signal11.1",
		Callable()
	)

	var missing: Dictionary = handler.handle_request(_request({}))
	_expect(
		int((missing.get("error", {}) as Dictionary).get("code", 0)) == -32602,
		"missing mutation request id returns invalid params"
	)
	_expect(
		str((missing.get("error", {}) as Dictionary).get("message", "")) == "mcp_request_id_required",
		"missing mutation request id returns the typed reason"
	)
	_expect(registry.call_count == 0, "missing mutation request id never dispatches")

	var accepted: Dictionary = handler.handle_request(_request({"request_id": "protocol-one"}))
	_expect(registry.call_count == 1, "valid mutation request id dispatches exactly once")
	_expect(not bool((accepted.get("result", {}) as Dictionary).get("isError", true)), "accepted operation is not marked as an error")

	registry.result_text = '{"ok":false,"reason_code":"mcp_request_id_collision"}'
	var collision: Dictionary = handler.handle_request(_request({"request_id": "protocol-one"}))
	_expect(registry.call_count == 2, "collision response crosses one registry boundary")
	_expect(bool((collision.get("result", {}) as Dictionary).get("isError", false)), "collision is marked as an MCP tool error")
	var structured: Dictionary = (collision.get("result", {}) as Dictionary).get("structuredContent", {})
	_expect(structured.get("reason_code") == "mcp_request_id_collision", "collision reason is preserved")

	var validation_blocked: Dictionary = handler.handle_request(_request({}, "validate_script"))
	_expect(
		str((validation_blocked.get("error", {}) as Dictionary).get("message", "")) == "mcp_import_quiescence_required",
		"script validation is rejected before import quiescence"
	)
	var scene_blocked: Dictionary = handler.handle_request(_request({}, "open_scene"))
	_expect(
		str((scene_blocked.get("error", {}) as Dictionary).get("message", "")) == "mcp_import_quiescence_required",
		"scene load is rejected before import quiescence"
	)
	_expect(registry.call_count == 2, "quiescence-blocked tools never cross the registry boundary")
	var diagnostics: Dictionary = handler.get_diagnostics()
	_expect(int(diagnostics.get("import_quiescence_blocked_tool_count", 0)) == 2, "blocked pre-quiescence calls are counted")
	_expect(int(diagnostics.get("protected_tool_dispatch_before_quiescence_count", -1)) == 0, "protected tools never dispatch before quiescence")
	_finish()


func _request(arguments: Dictionary, tool_name: String = "request_script_reload") -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": "offline-request-id-protocol",
		"method": "tools/call",
		"params": {
			"name": tool_name,
			"arguments": arguments,
		},
	}


func _expect(condition: bool, message: String) -> void:
	_total += 1
	if condition:
		_passed += 1
	else:
		_failures.append(message)


func _finish() -> void:
	print("MCP_REQUEST_ID_PROTOCOL_TESTS|passed=%d|total=%d" % [_passed, _total])
	if not _failures.is_empty():
		for failure in _failures:
			push_error("Funplay MCP request-id protocol test failed: %s" % failure)
		quit(1)
		return
	quit(0)
