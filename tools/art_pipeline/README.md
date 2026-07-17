# Role portrait art pipeline

This pipeline converts approved Quaternius CC0 source models into consistent,
pre-rendered transparent role portraits. Runtime code consumes PNG files only;
it never loads third-party 3D models.

## Workflow

1. Put official archives/folder downloads in `art_sources/inbox/`.
2. Run `unpack_official_sources.py`.
3. Run `build_source_asset_index.py`.
4. Open `scenes/tools/RolePortraitRenderRig.tscn` through the Godot MCP editor.
5. Render uniform candidate previews and build the source contact sheet.
6. Freeze real `source_path` selections in
   `assets/art/role_portraits/temporary/manifest.json`.
7. Render `front.png` and `side_inward.png` at 1024×1536, then downsample
   to 512×768 RGBA.
8. Run `validate_role_portraits.py`.

The renderer can hide weapon/leg nodes, apply restrained material overrides,
and attach simple geometry under `ProceduralAttachmentRoot`. It cannot invent
model paths or silently accept another author/license.

## Godot scene requirement

The scene is an editable 3D art workstation with a transparent SubViewport,
real cameras, three-point lighting, a WorldEnvironment, model/attachment roots,
and the common orbital collar. Run it with Godot MCP and inspect the scene tree
and debug output before treating any portrait as validated.
