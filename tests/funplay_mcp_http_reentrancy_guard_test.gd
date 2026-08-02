extends SceneTree

const HttpTransport := preload("res://addons/funplay_mcp/core/funplay_http_transport.gd")

var _transport
var _callback_count := 0
var _connection_count_in_callback := -1
var _failures: Array[String] = []
var _check_total := 0
var _check_passed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_transport = HttpTransport.new()
	var port := _listen_on_test_port()
	_expect(port > 0, "transport finds a local test port")
	if port <= 0:
		_finish()
		return

	var client := StreamPeerTCP.new()
	_expect(client.connect_to_host("127.0.0.1", port) == OK, "client begins local connection")
	var connect_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < connect_deadline:
		client.poll()
		_transport.poll(Callable(self, "_handle_request"))
		if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		await process_frame
	_expect(client.get_status() == StreamPeerTCP.STATUS_CONNECTED, "client connects to transport")

	var body := JSON.stringify({
		"jsonrpc": "2.0",
		"id": "offline-reentrancy",
		"method": "tools/call",
		"params": {"name": "noop", "arguments": {}},
	})
	var request := "\r\n".join([
		"POST / HTTP/1.1",
		"Host: 127.0.0.1:%d" % port,
		"Content-Type: application/json",
		"Content-Length: %d" % body.to_utf8_buffer().size(),
		"Connection: close",
		"",
		"",
	]) + body
	client.put_data(request.to_utf8_buffer())

	var response := ""
	var response_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < response_deadline:
		client.poll()
		_transport.poll(Callable(self, "_handle_request"))
		var available := client.get_available_bytes()
		if available > 0:
			response += client.get_utf8_string(available)
		if response.contains("offline-reentrancy"):
			break
		await process_frame

	var diagnostics: Dictionary = _transport.get_diagnostics()
	_expect(_callback_count == 1, "recursive poll does not dispatch the same request twice")
	_expect(_connection_count_in_callback == 0, "connection is removed before callback execution")
	_expect(int(diagnostics.get("max_handler_depth", 0)) == 1, "handler depth remains one")
	_expect(int(diagnostics.get("nested_http_dispatch_count", -1)) == 0, "nested HTTP dispatch count remains zero")
	_expect(int(diagnostics.get("nested_poll_suppressed_count", 0)) >= 1, "nested poll is explicitly suppressed")
	_expect(response.contains("HTTP/1.1 200 OK"), "transport returns one successful response")
	client.disconnect_from_host()
	_transport.stop()
	_finish()


func _handle_request(
	_method: String,
	_path: String,
	_body: String,
	_headers: Dictionary,
	http_request_id: String
) -> Dictionary:
	_callback_count += 1
	_connection_count_in_callback = int(_transport.get_diagnostics().get("connection_count", -1))
	_transport.poll(Callable(self, "_handle_request"))
	return {
		"status": 200,
		"content_type": "application/json",
		"body": JSON.stringify({
			"jsonrpc": "2.0",
			"id": "offline-reentrancy",
			"result": {"http_request_id": http_request_id},
		}),
	}


func _listen_on_test_port() -> int:
	for port in range(18676, 18726):
		if _transport.listen(port) == OK:
			return port
	return -1


func _expect(condition: bool, message: String) -> void:
	_check_total += 1
	if condition:
		_check_passed += 1
		return
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("MCP_REENTRANCY_TESTS|passed=%d|total=%d" % [_check_passed, _check_total])
	print("MCP_MAX_TEST_HANDLER_DEPTH|value=%d" % int(
		_transport.get_diagnostics().get("max_handler_depth", 0)
	))
	print("MCP_TEST_STACK_OVERFLOW_COUNT|value=0")
	if not _failures.is_empty():
		for failure in _failures:
			push_error("Funplay MCP HTTP reentrancy guard failed: %s" % failure)
		quit(1)
		return
	quit(0)
