# v0.6 Multi-Worktree Godot MCP

## Authority

Space Syndicate uses Funplay MCP for Godot `v0.9.6` as its active editor bridge. The older vendored `addons/godot_mcp` tree remains inactive historical tooling until a later cleanup phase.

Every role has a separate Git worktree, Godot editor process, redirected `APPDATA`/`LOCALAPPDATA` (therefore a separate `user://` tree), HTTP endpoint, and auth token. Sharing an editor endpoint between roles is forbidden because it breaks worktree isolation and makes scene/import ownership ambiguous.

## Role endpoints

| Role | Port | Worktree-local state |
| --- | ---: | --- |
| Supervisor | 8765 | `.codex-godot/` in Supervisor worktree |
| Codex A | 8775 | `.codex-godot/` in A worktree |
| Codex B | 8785 | `.codex-godot/` in B worktree |
| Codex C | 8795 | `.codex-godot/` in C worktree |

The auth tokens live only in each role's Godot `user://funplay_mcp_settings.cfg` and the local Codex MCP configuration. They must never be committed or copied into handoff reports.

Launch a role editor from that role's worktree with:

```powershell
pwsh -File tools/launch_role_godot_mcp.ps1 -Role A -Port 8775
```

The launcher redirects `APPDATA` and `LOCALAPPDATA` into the ignored `.codex-godot/` directory, seeds the authenticated endpoint, verifies that the endpoint reports the exact worktree root, and records only local connection metadata. Redirecting the complete profile is intentional: editor and play-mode runtime must resolve the same role-local `user://` path for heartbeat, input, and screenshots. Stop the editor normally with `tools/stop_role_godot_mcp.ps1`.

The checked-in `.mcp.json` starts `tools/funplay_mcp_stdio.cmd`. That bridge reads the endpoint and token from the current worktree's ignored local files, so no shared or committed secret is required. For deterministic shell-side diagnostics, `tools/invoke_role_godot_mcp.ps1` calls the same authenticated embedded endpoint; it is still MCP traffic, not a direct editor shortcut.

`project.godot` replaces the retired MCP runtime autoload with Funplay's runtime bridge. The bridge provides play-mode heartbeat, input, scene-tree, and viewport capture through local `user://` command files; the authenticated network endpoint remains editor-only.

## Development and acceptance split

- A/B/C inspect, edit, and exercise their own production scene or bench through their own Funplay endpoint.
- A/B/C may run small focused checks for iteration, but those results are not acceptance verdicts.
- The Supervisor fetches and rebases each candidate SHA, runs all focused/full headless gates, performs headed MCP playthroughs, reviews screenshots/debug output, stops the game cleanly, and decides integration.
- A/B/C do not run the Supervisor's full acceptance matrix. Their required handoff evidence is the exact worktree, endpoint identity, MCP scene/runtime exercise, changed-file list, and candidate SHA.
- No role force-pushes. A/B/C push only their named branch. Only the Supervisor advances integration and `main` after the v0.6 checkpoint gates are green.
