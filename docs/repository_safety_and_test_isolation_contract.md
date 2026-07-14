# Repository Safety And Test Isolation Contract

Status: active safety gate
Recorded: 2026-07-14

## Purpose

Large runtime cutovers are not allowed to depend on an unrecorded workspace or
to read/write the player's legacy current-run save from automated QA. This gate
records the active isolation boundary without changing gameplay or balance.

## Save Path Boundary

- The v0.6 `GameSaveRuntimeCoordinator` uses save version 3 and has no default
  save path; a caller must supply an explicit path.
- Automated real-main QA may select a path only below
  `user://test_runs/` and only for `.save` files.
- The override must be installed on `GameSaveRuntimeCoordinator` before Main
  enters the scene tree, so startup/menu save-status reads are isolated too.
- Paths outside that QA root, including the legacy player path, are rejected.
- Explicit non-save QA artifacts used by focused benches remain under their existing
  `user://space_syndicate_design_qa/` output directories.
- Tests must clean their own QA file but must never delete, rewrite, rename, or
  migrate the player's production save.

## Repository Baseline Boundary

Run `tools/repository_safety_baseline.ps1` before a destructive retirement or
root cutover. It writes a read-only status/hash manifest and report outside the
repository under the Godot user-data QA directory. It never stages or commits.

The manifest records:

- Git HEAD, branch, tracked changes, and expanded untracked paths;
- hashes for every changed/untracked file visible to Git;
- `main.gd` lines, function count, and SHA-256;
- metadata and SHA-256 for the existing player save without loading its payload;
- active third-party commercial-release blockers.

A clean-clone/export gate cannot be claimed while required runtime scenes,
scripts, Resources, UIDs, or assets remain untracked.

The intentional snapshot excludes local editor/runtime output rather than
deleting it. `addons/godot_mcp/cache/` and generated `reports/**/*.import`
sidecars are ignored; tracked report PNG evidence remains tracked. Source asset
import metadata under `assets/` may be included when it preserves a registered
asset UID or non-default import settings. Tracked `*.import` sidecars use LF via
`.gitattributes`, matching Godot's rewrite behavior and preventing Windows
line-ending-only dirty clones. All text files use LF so manifest hashes remain
byte-stable across Windows clones; binary assets remain binary. `.uid` files are
project source and must be included with their owning script or scene.

The annotated tag `v0.4-runtime-baseline` is valid only when a separate clone
from that tag imports with Godot 4.7 and passes focused composition/layout
checks. Future v0.5 work uses `rules/v05-runtime-integration`; runtime feature
flags are not a substitute for repository recovery.

## Third-Party Release Boundary

Night Patrol is CC BY-NC 4.0 and remains prototype-only. Its provenance files
must stay intact while referenced, but its audio/UI files must be replaced or
removed before a commercial build. Tests and reports must not describe it as a
commercially cleared production asset.

## Required Gates

1. Production default save path and v1 compatibility remain unchanged.
2. QA override accepts the dedicated test root and rejects the player path.
3. Legacy smoke runs its Main instance entirely against the QA override.
4. The player's pre-existing save hash and timestamp are unchanged after QA.
5. Repository baseline artifacts are written outside tracked project content.
6. The baseline clean-clone gate verifies Godot 4.7 import, UIDs, scene loading,
   composition, and layout after the current workspace has an intentional Git
   snapshot.

## Next Architecture Work

After this safety gate, continue Global UI Navigation characterization and hard
cutover. Public runtime ports and a shared Runtime Test Harness should then
replace direct Main private reflection before further root deletion.
