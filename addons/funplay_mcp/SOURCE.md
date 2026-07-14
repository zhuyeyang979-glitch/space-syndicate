# Funplay MCP Addon Source

Vendored release: `v0.9.6`

Upstream: https://github.com/FunplayAI/funplay-godot-mcp

Release artifact: `Funplay.GodotMcp.v0.9.6.zip`

Release date: 2026-07-13

SHA-256: `f610083a22b64401197a8e2d03cea743dd5ba4da3f3c41928e6aa828687a0619`

License: MIT; see `LICENSE` in this directory.

Local project policy:

- Funplay MCP is editor tooling, not a player-facing gameplay dependency.
- Each Git worktree redirects `APPDATA` and `LOCALAPPDATA`, yielding an isolated editor profile, `user://` tree, HTTP endpoint, and auth token.
- The runtime bridge replaces the repository's retired MCP runtime autoload so headed play-mode capture and input work in every isolated worktree. It exchanges commands through role-local `user://` files; the authenticated HTTP endpoint remains editor-only.
- Keep execute-code safety checks enabled. Only trusted local Codex tasks may connect.
