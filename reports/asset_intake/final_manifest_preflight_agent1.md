# Commercial Third-Party Final Manifest Preflight

`STATUS=WAITING_FINAL_MANIFEST`

The strict QA gate is implemented at:

`res://tests/commercial_art/commercial_third_party_manifest_test.gd`

It compiles under Godot `4.7.stable.official.5b4e0cb0f` and currently exits with code `2`, reporting the expected waiting state rather than fabricating final evidence.

## Missing Single-Writer Inputs

- `res://docs/third_party/selected_commercial_asset_manifest.json`
- `res://THIRD_PARTY_NOTICES.md`
- `res://docs/third_party/credits_data.json`

`res://reports/asset_intake/selected_source_verification_agent1.json` is present and already proves 30/30 source reachability, 30/30 license agreement, exact `21 / 6 / 1 / 2` classification, zero unlisted sources, zero web searches, and nonempty SHA-256 evidence for all 30 selected assets.

## Implemented Gates

Once the final files appear, the same focused test will fail closed unless all of the following are true:

1. The final manifest contains exactly the 30 pinned asset IDs, with no duplicate or unlisted ID.
2. Every source URL and license matches the fixed contract.
3. License counts are exactly 21 CC0, 6 CC BY 3.0, 1 MIT, and 2 OFL.
4. Every original SHA-256 is nonempty and structurally valid.
5. Every processed path is local, exists, and has a matching recorded SHA-256.
6. Game-icons attribution contains all six titles, both authors, `game-icons.net`, CC BY 3.0, and the modification statement.
7. Provider/package license evidence exists and is nonempty for all 30 assets.
8. Credits contain `Third-Party Assets`, `Licenses`, `Music`, and `Fonts` sections.
9. Runtime network asset dependencies and remote processed paths are zero.
10. Every repository file is below 25 MiB.
11. Repository growth relative to `2e38764791cb37cdc45b2eb0836957f550822dd5` is below 250 MiB.

No network access, search, full Smoke, or Formal run was used. This lane has not edited the final manifest, notices, credits, or any production or asset file.
