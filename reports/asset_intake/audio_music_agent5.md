# Commercial Audio and Music Intake - Agent 5

## Result

All six fixed official source pages were reachable and each displayed the required CC0 license. No web search, source comparison, mirror, replacement, or unlisted asset source was used.

- Selected source pages: 6/6
- Fixed SFX events: 17/17
- Fixed music tracks: 4/4
- Web Audio decode checks: 177/177
- Selected SFX decoded clipping: 0 samples
- Runtime network dependencies: 0

The repository contains only selected OGG production files and the two Kenney package license texts. ZIP, MP3, WAV, previews not selected for production, and unused package members remain in the external `agent5` cache.

## Source and License Evidence

| Asset ID | Official source | Author | Observed license | Original download SHA-256 |
| --- | --- | --- | --- | --- |
| `kenney.interface_sounds` | `https://kenney.nl/assets/interface-sounds` | Kenney | CC0-1.0 | `f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232` |
| `kenney.scifi_sounds` | `https://kenney.nl/assets/sci-fi-sounds` | Kenney | CC0-1.0 | `119340f351a5098ad814f78719438c0da355a9ce8a4c8a3af6a8d48aa3d49e04` |
| `music.menu.pondering_the_cosmos` | `https://opengameart.org/content/pondering-the-cosmos` | Ruskerdax | CC0-1.0 | `a4aec454a7ad452e4e1e7945acdda771506eebdfb10477894d1ed9c54cca8e6a` |
| `music.gameplay.robotic_city` | `https://lpc.opengameart.org/content/robotic-city` | section31 | CC0-1.0 | `3d2ae95b9c59ae0716654fe4880b9986e5ac3df8e2e4d71aa70f107abbec3f87` |
| `music.crisis.space_graveyard` | `https://opengameart.org/content/space-graveyard-ambient-track` | TinyWorlds | CC0-1.0 | `21af1b4854e6ce4330a0fad51e4b68227b37182be4b4beede70f9906991d2c60` |
| `music.military.interstellar_fleet_1` | `https://opengameart.org/content/interstellar-fleet-1` | Zane Little Music | CC0-1.0 | `39f602b6bc0c95b2d3859d0c0c024f97063c788030cc9b14247bcef4165dad16` |

For Pondering the Cosmos and Space Graveyard, the exact official page's OGG preview transcode is the production OGG while the original MP3 SHA remains retained. Robotic City is an original OGG attachment. Interstellar Fleet 1 uses the exact `[LOOP].ogg` member from the official ZIP; its member SHA is `f8be29e21b4c15fca84160410c12deb8ed03fddc1aa706f2af6b60eabab3bd6d`.

## Fixed SFX Mapping

| Event | Stable key | Package member |
| --- | --- | --- |
| `ui.hover` | `audio.ui.hover` | `select_001.ogg` |
| `ui.confirm` | `audio.ui.confirm` | `confirmation_001.ogg` |
| `ui.cancel` | `audio.ui.cancel` | `back_001.ogg` |
| `card.select` | `audio.card.select` | `click_001.ogg` |
| `card.drag_start` | `audio.card.drag_start` | `scratch_003.ogg` |
| `card.drop` | `audio.card.drop` | `drop_001.ogg` |
| `card.lock` | `audio.card.lock` | `toggle_004.ogg` |
| `card.merge` | `audio.card.merge` | `glass_003.ogg` |
| `asset.refresh` | `audio.asset.refresh` | `maximize_007.ogg` |
| `commodity.claim` | `audio.commodity.claim` | `laserSmall_000.ogg` |
| `normal_card.purchase` | `audio.normal_card.purchase` | `laserSmall_001.ogg` |
| `facility.factory_build` | `audio.facility.factory_build` | `impactMetal_004.ogg` |
| `facility.market_build` | `audio.facility.market_build` | `doorOpen_001.ogg` |
| `facility.warehouse_build` | `audio.facility.warehouse_build` | `doorClose_001.ogg` |
| `monster.attack` | `audio.monster.attack` | `explosionCrunch_000.ogg` |
| `military.action` | `audio.military.action` | `laserLarge_000.ogg` |
| `settlement.complete` | `audio.settlement.complete` | `forceField_001.ogg` |

Each event has one deterministic file, `loop=false`, and no random selection. The machine contract pins member SHA, duration, decoded peak, zero selected clipping, stream path, and presentation gain.

## Fixed Music Mapping

| Public presentation state | Stable key | Track | Production OGG origin |
| --- | --- | --- | --- |
| Menu | `music.menu` | Pondering the Cosmos | Official page OGG preview transcode |
| Gameplay/economy | `music.gameplay` | Robotic City | Official OGG attachment |
| Crisis | `music.crisis` | Space Graveyard | Official page OGG preview transcode |
| Military/late tension | `music.military` | Interstellar Fleet 1 | Official ZIP loop OGG member |

The music contract fixes a 1.5-second equal-power crossfade and targets approximately -12 dBFS peak per track before overlap. Robotic City's source OGG decodes with 369 overs samples; the fixed -12.3 dB presentation trim gives an effective peak of -12.0232 dBFS. Music changes may read only public presentation state and have no gameplay, Save, hidden-information, or RNG effect.

## Integration Boundary

This lane did not edit `AudioEventRegistry`, the production audio bus, Presentation Asset Catalog, Credits, `THIRD_PARTY_NOTICES.md`, or the final selected-asset manifest. The contracts are ready for the Catalog and Review-scene owners to consume. No production connection is claimed by this lane.
