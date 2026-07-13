# Godot MCP Addon Source

Vendored from: https://github.com/tomyud1/godot-mcp

Reason for selection:
- GDScript Godot 4.x editor plugin, suitable for this standard Godot 4.7 project.
- Companion MCP server is published as `godot-mcp-server` on npm and can be run with `npx`.
- Uses localhost WebSocket communication (`ws://127.0.0.1:6505`) between the MCP server and the Godot editor plugin.
- Does not require the Godot .NET/mono editor.

Local project note:
- This addon is an editor tool for AI-assisted development.
- It should not be treated as a player-facing gameplay dependency.
