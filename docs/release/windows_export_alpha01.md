# Windows Alpha 0.1 export contract

The repository defines one Godot 4.7 preset named `Windows Alpha 0.1`. It uses
the `space_syndicate_release` and `alpha_0_1` feature tags, embeds the PCK in one
Windows x86-64 executable, and never treats an earlier executable as evidence
for the current commit.

## Canonical build

Run from a clean, committed worktree:

```powershell
pwsh -File tools/release/build_windows_alpha01.ps1 -RunHeadedVerification
```

The default package is written outside the repository:

```text
C:\Users\Administrator\Documents\New project\space-syndicate-builds\playtest-alpha-0.1\
```

All editor-scan, export, headless-smoke, headed-runtime, isolated AppData and
screenshot evidence remains under `%TEMP%\space-syndicate-codex\`. No log,
executable, PCK, ZIP, AppData or `.godot` directory belongs in Git.

The build refuses a dirty worktree. It archives `HEAD` into a temporary clean
source snapshot, performs the Godot editor scan there, and exports that exact
commit. Existing canonical output is not replaced unless the caller explicitly
passes `-ReplaceOutput`.

## Fail-closed checks

Before export, `tools/release/check_release_safety.py` verifies:

- Godot Windows x86-64 and the external preset path;
- the release feature and the runtime bridge's fail-closed feature guard;
- exclusion of editor, MCP, QA, test, report and tool resources;
- the real playtest checklist, third-party register, Godot license and every
  redistributed prototype-asset license required by the current package.

The exported executable is first launched headlessly in isolated AppData. A
passing smoke has exit code 0, no parser/resource errors and no
`funplay_mcp_runtime_*` command, response, state or screenshot file. With
`-RunHeadedVerification`, the same executable is then launched directly in a
window, captured after the main window appears, and allowed to exit through
Godot's `--quit-after` path; the caller must visually inspect the temporary PNG
before claiming that the main menu is visible.

The external package contains:

- `SpaceSyndicate-Alpha-0.1-Windows-x86_64.exe`;
- `PLAYTEST.md`, copied from the tracked human-playtest checklist;
- `LICENSES/`, including the Godot engine license, third-party asset register,
  and the applicable upstream license/notice files;
- `build_manifest.json`, bound to the current Git commit and template hashes;
- `SHA256SUMS`, covering every packaged file except itself.

The repository does not currently declare a project-level license. The package
records that fact and does not invent one. This foundation also does not claim
that the Alpha 0.1 RC is accepted: final RC status still requires completed
`PLAYTEST.md` evidence, including the full exported playthrough, settlement,
restart, privacy-zero and duplicate-apply-zero gates.

## Manual visual close-out

Open the screenshot path printed by the build and verify all of the following:

1. The Space Syndicate main menu is visible and readable.
2. No missing-resource placeholder or error dialog is present.
3. The headed receipt reports exit code 0 and an empty bridge-file list.
4. The executable hash in `SHA256SUMS` matches the manifest.

If any item fails, label the candidate `BLOCKED`; do not rename or describe an
older executable as the current build.
