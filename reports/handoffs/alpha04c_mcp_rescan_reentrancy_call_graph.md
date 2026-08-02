# Alpha 0.4-C MCP Rescan Reentrancy Call Graph

## Verdict

The primary defect belongs to the vendored Funplay MCP for Godot v0.9.6 addon
inside the game repository. The Codex PowerShell wrapper issued one request and
did not recursively retry it. Its readiness contract was incomplete, however:
the launcher treated a successful `get_project_info` response as readiness
without waiting for the initial editor filesystem scan.

The repair scope is therefore mixed: the addon owns the crash fix and reload
state machine; the wrapper owns unique request IDs, readiness waiting, and the
typed `editor_process_exited` projection.

## Causal Chain

```text
FunplayMcpPlugin._process
-> FunplayMcpServer.poll
-> FunplayHttpTransport.poll
-> FunplayMcpServer._handle_http_request
-> FunplayMcpRequestHandler.handle_request
-> FunplayToolRegistry.call_tool
-> FunplayCoreTools.request_script_reload
-> FunplayCoreTools._refresh_filesystem
-> EditorFileSystem.scan
-> Godot progress UI pumps a nested editor frame
-> FunplayMcpPlugin._process
-> the same complete buffered HTTP connection is dispatched again
```

Before the repair, the transport removed the connection only after the callback
returned. `EditorFileSystem.scan()` entered a nested editor iteration while the
outer callback was still active, so the same connection, request body, and
JSON-RPC call entered the handler again. This was not an HTTP self-call,
`await`, wrapper retry, signal recursion, or 226 independent game failures.

The first directly evidenced collision occurs at log line 13. Each early
backtrace adds the same nine-frame Funplay cycle. The printed trace eventually
reaches indices `0..1023`; three explicit stack overflows follow. An eventual
connection-array removal error is unwind damage from nested handlers mutating
the same connection list.

## Initial Scan

The Funplay plugin is initialized while Godot's first editor filesystem scan is
still active. Godot's progress dialog pumps nested editor iterations during
that scan, so an endpoint can answer `get_project_info` before filesystem
readiness. The correct readiness predicate is:

```text
not EditorFileSystem.is_scanning()
and not EditorFileSystem.is_importing()
and EditorFileSystem.get_filesystem() != null
```

An early reload must therefore create or join one queued operation. It must not
call `scan()`, start a second scan, or wait recursively inside the HTTP
handler.

## Error Attribution

The 226 `first_scan_filesystem already exists` entries are cascading
observations of one reentrant request. They are not 226 game-code errors.

Seven `Unexpected NUL character` Unicode diagnostics occur before the first
collision. They contain no resource path, parser identity, or causal stack.
They remain preserved as unattributed initial-scan diagnostics and are not
classified as GDScript or gameplay failures.

## Repair Contract

The HTTP handler only registers an idempotent operation and returns. One
filesystem state owner advances:

```text
cold -> initial_scan_running -> ready
ready -> reload_queued -> reload_running -> ready
any active state -> failed
any state -> stopping
```

The actual script reload and filesystem scan run on a later top-level editor
tick. During that execution, nested editor frames skip MCP HTTP polling.
Transport independently removes a completed connection before callback
dispatch and suppresses recursive polling. A duplicate tool-level request ID
returns the existing operation; requests arriving during an active reload join
at most one follow-up operation.

The original 15,646,563-byte log is preserved in its prior isolated worktree.
Its SHA-256 is
`c9c5f670c21cd39d70674511ee312c9c7645ee32da3edcaa6bfeae5ff5485958`.
