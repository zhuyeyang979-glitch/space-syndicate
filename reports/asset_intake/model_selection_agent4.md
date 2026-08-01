# Quaternius model selection - Agent 4

Status: **GREEN**

This lane used only the five Quaternius pages fixed by the task. Every page returned HTTP 200 and displayed CC0. No asset search, mirror, alternate source, or paid Source/Pro package was used. Raw packages and unselected candidates remain outside the repository in the dedicated Agent 4 cache.

## Official intake

| Asset | Official page | Free artifact used | SHA-256 / evidence |
| --- | --- | --- | --- |
| Modular Sci-Fi MegaKit | `modularscifimegakit.html` | `Modular SciFi MegaKit[Standard].zip` | `6fae60cf...e03035e3` |
| Sci-Fi Essentials Kit | `scifiessentialskit.html` | `Sci-Fi Essentials Kit[Standard].zip` | `a08346d5...c6fca01` |
| Ultimate Monsters | `ultimatemonsters.html` | Official-page Drive folder | Folder evidence `2ad77c91...6e66dcd` |
| Animated Mech | `animatedmech.html` | Official-page Drive folder, Textured glTF | Folder evidence `ba914be3...84c22c1` |
| Ultimate Spaceships | `ultimatespaceships.html` | Official-page Drive folder | Folder evidence `8b97abf8...3b103` |

The Ultimate Monsters license file retains an old “Ultimate Platformer Pack” heading, but its actual terms explicitly say CC0 1.0 and match the official page. This was recorded, not rewritten.

## Facility source lock

**Factory**

- `glTF/Platforms/Platform_DarkPlates.gltf`
- `glTF/Columns/Column_MetalSupport.gltf`
- `glTF/Columns/Column_Pipes.gltf`
- `glTF/Props/Prop_Barrel_Large.gltf`
- `Sci-Fi Essentials/glTF/Enemy_EyeDrone.gltf`

The component is a heavy plate platform with paired supports, pipe banks, barrels, and a suspended machinery core. Emission is local; the model is not globally ownership-tinted.

**Market**

- `glTF/Platforms/Platform_Round1.gltf`
- `glTF/Props/Prop_Computer.gltf`
- `glTF/Props/Prop_AccessPoint.gltf`
- `Sci-Fi Essentials/glTF/Prop_Desk_Medium.gltf`

The component stays open and low, with a central terminal, paired computers/access points, and two presentation-only hologram planes.

**Warehouse**

- `glTF/Platforms/Platform_Simple2.gltf`
- `glTF/Platforms/Platform_Ramp_2Short.gltf`
- `Sci-Fi Essentials/glTF/Prop_Crate_Large.gltf`
- `Sci-Fi Essentials/glTF/Prop_Crate_Tarp_Large.gltf`
- `Sci-Fi Essentials/glTF/Prop_Shelves_WideShort.gltf`

The component uses a low rectangular silhouette, short loading ramp, short shelves, and cargo. No tower is introduced.

**Starport**

- `glTF/Platforms/Platform_Metal2.gltf`
- `glTF/Props/Prop_Rail_Round_Big.gltf`
- `glTF/Decals/Decal_XSign.gltf`
- `Sci-Fi Essentials/glTF/Prop_SatelliteDish.gltf`
- `Ultimate Spaceships/Striker/glTF/Striker.gltf`

The Striker is presentation-only and explicitly not a route Owner.

## Frozen monster mapping

| Asset key | Exact source | Frozen silhouette | Animations |
| --- | --- | --- | ---: |
| `model.monster.life` | `Big/glTF/Monkroose.gltf` | organic mammalian | 14 |
| `model.monster.energy` | `Flying/glTF/Ghost_Skull.gltf` | floating spectral | 8 |
| `model.monster.industry` | `Big/glTF/Orc_Skull.gltf` | bulky armored | 14 |
| `model.monster.technology` | `Flying/glTF/Armabee_Evolved.gltf` | insectoid precision | 8 |
| `model.monster.commerce` | `Flying/glTF/Squidle.gltf` | cephalopod cunning | 8 |
| `model.monster.shipping` | `Flying/glTF/Dragon_Evolved.gltf` | winged aerial | 8 |

The fixed pack has no literal four-legged full-body model. Monkroose is the closest full-body organic mammalian silhouette. No alternate source was searched. Each wrapper preserves animation, uses localized category emission on the base, and includes a low-scale billboard.

## Deterministic mech tiers

Godot 4.7 measured the imported AABB volumes, with no taste-based override:

1. `Leela`: 41.752896644 -> `military.tier1`
2. `Mike`: 75.754419265 -> `military.tier2`
3. `Stan`: 86.626493402 -> `military.tier3`
4. `George`: 116.435224140 -> `military.tier4`

All four retain 18-20 source animations. Player color is limited to the base ring and two shoulder marker meshes.

## Deterministic ship uses

Godot imported all 11 candidate glTF files from the external cache and measured them before unselected files were discarded:

- Minimum: `Striker`, 113.866775381 -> `model.shipping.route_marker`
- Median (rank 6): `Pancake`, 224.729249445 -> `model.shipping.convoy`
- Maximum: `Omen`, 504.833458044 -> `model.shipping.starport_showcase`

The complete 11-row order and dimensions are retained in the JSON report. Ships have no route authority and no rule ownership.

## Repository and validation

- Selected glTF files: **31**
- Stable-key component scenes: **17**, plus one shared pedestal
- Source ledger: **96 files**, SHA-256 `f2e03faa...e8341e1c`
- Source bytes: **125,137,620**
- Largest file: **12,047,004 bytes**
- Runtime network dependencies: **0**
- Focused Godot contract: **305/305**
- Five isolated first-import projects: **0 NUL warnings, 0 broken resources**
- Production scene edits: **0**
- Catalog edits: **0**
- Gameplay, Save, RNG, AI, and Main ownership changes: **0**

AmbientCG material assignment and final production/reference placement remain with the main integration lanes. These components preserve Quaternius source materials and expose stable presentation keys without claiming any gameplay authority.
