# Windows Alpha 0.1 export contract

The repository defines one Godot 4.7 preset named `Windows Alpha 0.1`. It uses
the `space_syndicate_release` and `alpha_0_1` feature tags, embeds the PCK in one
Windows x86-64 executable, and never treats an earlier executable as evidence
for the current commit.

## V0.7.6 merge, tag, and cutover ratchet

This Alpha 0.1 export contract does not authorize a V0.7.6 release or production
cutover. For PR #93, no agent may mark the PR Ready, merge it, create a V0.7.6
release tag, or begin production cutover until the latest exact-current-Head
check named `V076 Reuse and Point-Inertia Gate` is completed `SUCCESS` with no
newer pending or failed run.

Run this read-only preflight from the exact clean candidate worktree. The JSON
file is temporary and remains outside the repository:

```powershell
$ErrorActionPreference = "Stop"
$guardedAction = [string]$env:V076_GUARDED_ACTION
if ($guardedAction -notin @("READY", "MERGE", "TAG", "CUTOVER")) {
  throw "Set V076_GUARDED_ACTION to READY, MERGE, TAG, or CUTOVER."
}
$expectedHead = (git rev-parse HEAD).Trim()
$liveJson = gh pr view 93 `
  --repo zhuyeyang979-glitch/space-syndicate `
  --json headRefOid,isDraft,state,statusCheckRollup
if ($LASTEXITCODE -ne 0) {
  throw "Could not read live PR #93 status."
}
$live = $liveJson | ConvertFrom-Json
if ($live.headRefOid -cne $expectedHead) {
  throw "PR #93 Head mismatch: expected=$expectedHead live=$($live.headRefOid)"
}
if ($guardedAction -eq "READY" -and ($live.state -cne "OPEN" -or $live.isDraft -ne $true)) {
  throw "READY requires PR #93 to be an open Draft."
}
if ($guardedAction -eq "MERGE" -and ($live.state -cne "OPEN" -or $live.isDraft -ne $false)) {
  throw "MERGE requires PR #93 to be open and already non-Draft."
}
if ($guardedAction -in @("TAG", "CUTOVER") -and $live.state -cne "MERGED") {
  throw "$guardedAction requires PR #93 to be merged."
}
$checksPath = Join-Path $env:TEMP "v076-pr93-current-head-checks.json"
[ordered]@{
  checks = @($live.statusCheckRollup | ForEach-Object {
    [ordered]@{
      name = $_.name
      status = $_.status
      conclusion = $_.conclusion
      head_sha = $live.headRefOid
    }
  })
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $checksPath -Encoding utf8
python tools/v076/v076_reuse_point_inertia_gate.py merge-ratchet `
  --checks-json $checksPath `
  --expected-head-sha $expectedHead
if ($LASTEXITCODE -ne 0) {
  throw "V0.7.6 merge ratchet is not green on the current PR Head."
}
```

The preflight is a verifier only. It must not call `gh pr ready`, `gh pr merge`,
create a tag or release, edit branch protection, or perform a cutover. Those
remain separate, explicitly authorized actions after all applicable product and
release gates are satisfied. A successful Gate does not convert isolated Stage
evidence into production or human-play evidence.

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
source snapshot, performs a terminating Godot import scan there, and exports
that exact commit. Import mode is used so Windows editor teardown cannot turn a
successful first import into a crash-only failure. Existing canonical output is
not replaced unless the caller explicitly passes `-ReplaceOutput`.

## Fail-closed checks

Before export, `tools/release/check_release_safety.py` verifies:

- Godot Windows x86-64 and the external preset path;
- clean-commit archive, external output, temporary runtime, terminating import
  scan and manifest-to-commit build guards;
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
