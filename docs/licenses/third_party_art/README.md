# Third-party role-art license gate

Only the five Quaternius packs listed in
`tools/art_pipeline/source_pack_registry.json` are approved for the temporary
role portrait pipeline. Each pack's official page explicitly applies CC0.

The repository currently contains the exact small `License.txt` files that can
be downloaded directly from the three official Quaternius Google Drive
folders. Their hashes are recorded in the registry. The two itch.io Standard
archives are not present because itch.io requires an interactive official
download session. For those packs, the registry records the official pack page
as the license association evidence and stores the canonical CC0 1.0 legal
code as `CC0-1.0-legalcode.txt`.

No model or derived PNG is licensed for use merely because its filename looks
right. The indexer requires:

- an approved `pack_id`;
- a local license file whose SHA-256 matches the registry;
- a model extension in `.blend`, `.fbx`, `.gltf`, `.glb`, or `.obj`;
- a SHA-256 for the model itself.

The two 374-byte Quaternius licenses for Ultimate Monsters and Ultimate Space
Kit contain an old title line saying “Ultimate Platformer Pack”. Their CC0
body is valid, but the official pack page URL must remain beside the license
to prove which download supplied it.

Do not commit downloaded archives or the complete extracted model cache.
Commit only approved derived PNGs, the index/manifest, license evidence, and
the reproducible tools.
