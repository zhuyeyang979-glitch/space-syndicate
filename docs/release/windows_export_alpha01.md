# Windows Alpha 0.1 export contract

The repository now defines one Godot 4.7 Windows preset named `Windows Alpha 0.1`.
It adds the custom feature tags `space_syndicate_release` and `alpha_0_1`, embeds the
PCK in a single x86-64 executable, and writes local artifacts under ignored
`builds/alpha01/`.

Build from a clean worktree:

```powershell
pwsh -File tools/release/build_windows_alpha01.ps1
```

The build is fail-closed. Before Godot exports anything,
`tools/release/check_release_safety.py` verifies that the release feature exists and
that every runtime MCP autoload is disabled by that feature. Test scenes, tool scripts,
QA reports, repository instructions, MCP configuration, editor-only MCP implementations,
and design-QA plugins are excluded from the package; only the guarded Funplay runtime
bridge remains because it is still an autoload dependency in the project composition.
The build then launches the exported
executable against isolated user-data directories, checks that it exits cleanly,
rejects script/parser errors, and verifies that no Funplay MCP command, response,
screenshot, or state file was created. A SHA-256 build manifest is emitted beside the
executable.

This is release infrastructure, not Alpha RC evidence. An Alpha RC still requires a
complete exported four-seat playthrough, authoritative settlement, restart, privacy
zero, duplicate-apply zero, and the selected content/art parity gates.
