# Planet, Material, and VFX Intake

Status: GREEN

## Fixed sources

All seven selected asset packages were downloaded from the exact official
pages named by the task. No web search, mirror, alternative source, or asset
comparison was used. The observed licenses match the requested contracts:

| Asset | Resolution / retained scope | License | Original SHA-256 |
| --- | --- | --- | --- |
| Naejimer 3D Planet Generator | body, clouds, atmosphere, license only | MIT | 21be38c25cc8aa9ff2f1259d67962ed2bc8ca4942318206347fee1d606f66be9 |
| MetalPlates013 | 1K-JPG PBR maps | CC0-1.0 | fa2e438b7512470264ebd98c872ca2ea321a0cce4c0ac43264891beec6a21b7d |
| PaintedMetal007 | 1K-JPG PBR maps | CC0-1.0 | 1434c914dbbd7d88afa8acda4977b6180cfa2281f0cbec7900ca2ec49b22a35a |
| SheetMetal003 | 1K-JPG PBR maps | CC0-1.0 | 4c128dd028733b0bbced7050b78dfff4e575047c811c2eadb244a9a89d6b2e92 |
| NightSkyHDRI001 | 2K EXR only | CC0-1.0 | 9c2c7cd4a15b9a7bd9119fce94a5b7b6d5d422aaa1be38ff8ecf11fcdf155b7d |
| Kenney Particle Pack | six deterministic event textures | CC0-1.0 | b631d4b07f7002549fdcf155f01141ad482f79f3440e4e301eed49ce5f1d8958 |
| Kenney Smoke Particles | four sparse nine-frame families | CC0-1.0 | 97a1d09c66e4fd6c247c8ea87f84c0cc59caaeceae19414c995afb1616a1e1c9 |

The full archives and page snapshots remain outside the repository in the
isolated agent3 cache. No Demo scene, high-resolution material, Blender, USD,
MaterialX, displacement, preview, or unused particle file was copied.

## Planet component

CommercialPlanetReviewComponent.tscn is an isolated presentation bench
component. It has an opaque ALPHA=1.0 body, opaque depth writes, back-face
culling, depth-tested cloud/atmosphere shells, a 1.0 day side and 0.50 night
side, and explicit front/back surface-marker culling. It introduces no orbit
ring or seat-like radial decoration.

The camera supports wheel, keyboard, gamepad, and magnify-gesture zoom. The
fixed range is 0.72..1.85, wheel step is 0.08, and reset returns to 1.0.
Camera rotation and zoom are local presentation state with no Save API.
set_solar_turn_normalized() is a presentation input only; it does not read
the production runtime.

## Materials and VFX

The three ambientCG materials load as StandardMaterial3D resources using
Color, NormalGL, Roughness, Metalness, and the available AO maps. The 2K EXR
loads through a local PanoramaSkyMaterial; runtime network dependency count
is zero.

The VFX map binds one fixed texture to each of six events and four fixed frame
families to facility/combat effects. It declares rules_rng_consumed=false and
caps concurrent transparent emitters at 12.

## Verification

- Godot: 4.7.stable.official.5b4e0cb0f
- Focused contract: 59/59
- Broken resource references: 0
- Script/runtime errors: 0/0
- 960x640 and 640x420 real Godot captures: nonblank
- Day/night sampled luminance ratio: 1.365
- Processed lane tree: 78 authored/source files, 22,005,933 bytes
- Processed lane SHA-256: 63cf807d6bf3bc2ec1cece3a841a563428f8ecb0518886d592085d85f94823ba
- Largest file: NightSkyHDRI001_2K_HDR.exr, 7,101,153 bytes

Production PlanetBoard, PlanetMapView, main.gd, main.tscn, rules, Save owners,
RNG owners, and AI policy were not changed.
