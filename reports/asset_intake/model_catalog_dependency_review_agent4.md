# Model and Catalog dependency review - Agent 4

Status: **PARTIAL**. The model dependency closure and all 17 model Catalog bindings are proven. The existing generic Catalog contract has a separate hard-coded count drift after four font variant keys were added by another lane.

## Snapshot and boundaries

- HEAD: `664a89407bfc411cd6ab7ce86a19f02a70ffbaa6`
- Growth base: `2e38764791cb37cdc45b2eb0836957f550822dd5`
- Catalog SHA-256: `e3e980665a09d71bef50b047c18c566dc0b6b149deaf2041939cc57ef273f3f2`
- Network/search: **0**
- Formal/full Smoke: **0 / 0**
- Model, Catalog, production map, final manifest, notices, and credits edits by Agent 4: **0**
- Only this JSON/Markdown report pair is authorized as repository output.

## Recursive dependency closure

The audit starts from the 17 `model.*` PackedScene components, recursively follows the shared pedestal scene, follows every model glTF ext-resource, then parses each glTF's `buffers[].uri` and `images[].uri` with a JSON parser.

| Measure | Result |
| --- | ---: |
| Stable component scenes | 17 |
| Recursive PackedScene files | 18 |
| Reachable glTF files | 31 |
| Unique runtime model files | 78 |
| Import sidecars for reachable sources | 60 |
| License evidence files | 5 |
| Closure/evidence files | 143 |
| Tracked model files classified | 169/169 |
| Missing dependencies | 0 |
| Files outside closure | 26 |

The classification ledger SHA-256 is `817ce530d2e29bc31b3e27a80803a45f0abcfda5ab1894844146469da34cee0f`. The JSON report lists all 169 paths exactly once by classification and records all 31 glTF dependency rows.

## Safe deletion candidates

The 13 affected animated-mech, monster, and ship glTF files each contain an embedded buffer and embedded image. Their parallel exported PNG is not a glTF URI, scene ext-resource, Catalog resource, or non-self repository text reference. The matching PNG `.import` sidecar is therefore also outside the closure.

Potential recovery: **16,350,211 bytes**. No deletion was performed.

- `assets/third_party/commercial/models/quaternius/animated_mech/gltf/George_George_Texture.png`
- `assets/third_party/commercial/models/quaternius/animated_mech/gltf/George_George_Texture.png.import`
- `assets/third_party/commercial/models/quaternius/animated_mech/gltf/Leela_Leela_Texture.png`
- `assets/third_party/commercial/models/quaternius/animated_mech/gltf/Leela_Leela_Texture.png.import`
- `assets/third_party/commercial/models/quaternius/animated_mech/gltf/Mike_Mike_Texture.png`
- `assets/third_party/commercial/models/quaternius/animated_mech/gltf/Mike_Mike_Texture.png.import`
- `assets/third_party/commercial/models/quaternius/animated_mech/gltf/Stan_Stan_Texture.png`
- `assets/third_party/commercial/models/quaternius/animated_mech/gltf/Stan_Stan_Texture.png.import`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Armabee_Evolved_Atlas_Monsters.png`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Armabee_Evolved_Atlas_Monsters.png.import`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Dragon_Evolved_Atlas_Monsters.png`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Dragon_Evolved_Atlas_Monsters.png.import`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Ghost_Skull_Atlas_Monsters.png`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Ghost_Skull_Atlas_Monsters.png.import`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Monkroose_Atlas_Monsters.png`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Monkroose_Atlas_Monsters.png.import`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Orc_Skull_Atlas_Monsters.png`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Orc_Skull_Atlas_Monsters.png.import`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Squidle_Atlas_Monsters.png`
- `assets/third_party/commercial/models/quaternius/ultimate_monsters/gltf/Squidle_Atlas_Monsters.png.import`
- `assets/third_party/commercial/models/quaternius/ultimate_spaceships/gltf/Omen_Omen_Orange.png`
- `assets/third_party/commercial/models/quaternius/ultimate_spaceships/gltf/Omen_Omen_Orange.png.import`
- `assets/third_party/commercial/models/quaternius/ultimate_spaceships/gltf/Pancake_Pancake_Orange.png`
- `assets/third_party/commercial/models/quaternius/ultimate_spaceships/gltf/Pancake_Pancake_Orange.png.import`
- `assets/third_party/commercial/models/quaternius/ultimate_spaceships/gltf/Striker_Striker_Orange.png`
- `assets/third_party/commercial/models/quaternius/ultimate_spaceships/gltf/Striker_Striker_Orange.png.import`

## Catalog verification

The production Catalog resource validates, contains exactly 17 `model.*` keys, and the read-only Godot audit passed **105/105** checks:

- PackedScene resolution: **17/17**
- Instantiation: **17/17**
- `presentation_only=true`: **17/17**
- Root asset-key parity: **17/17**
- True authoritative route owners: **0**

The generic `commercial_presentation_catalog_contract_test.gd` result is **8/11**, with three count-only failures. The Catalog now has **97** stable keys after `font.body.zh.bold`, `font.body.ja.bold`, `font.display.medium`, and `font.display.bold` were added, while the test still expects production/fixture/service counts of 93/94/94. Legacy validation, lookup, kind/scope behavior, fail-closed checks, and single-owner behavior pass.

Recommended action for the Catalog single writer: replace the stale hard-coded cardinalities with the current contract count or a data-derived fixture delta. This Agent did not edit the test or Catalog.

## Repository growth and screenshots

The exact net working-tree growth versus `2e38764791cb37cdc45b2eb0836957f550822dd5` is **226,706,538 bytes (226.707 MB; 216.204 MiB)**. This includes committed changes and all nonignored untracked files and excludes this self-referential report pair.

- Largest current file: `assets/third_party/commercial/fonts/noto_sans_cjk/NotoSansCJKjp-Bold.otf` at **17,032,620 bytes**
- Remaining decimal 250 MB budget before screenshots: **23,293,462 bytes**
- Required average ceiling for 15 screenshots: **1,552,897 bytes each**
- Existing QA basis: **116** 16:9 PNGs, mean **392,940 bytes**, observed maximum **724,084 bytes**
- 15 at observed mean: **5,894,096 bytes**, projected total **232.601 MB**
- 15 at observed maximum each: **10,861,260 bytes**, projected total **237.568 MB**

The measured PNG estimate remains below 250 MB in both cases. The uncompressed framebuffer reference would exceed the cap, so this is not a substitute for byte-gating the actual 15 PNGs after capture. Applying the reported model cleanup later would recover another **16,350,211 bytes**, but that recovery is not counted here.
