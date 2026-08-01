# Commercial Art Presentation Capture: GREEN

This report supersedes the first-round visual QA result in `presentation_capture_final_agent.*`. The first-round files remain as immutable evidence of the defects that were repaired.

## Result

- Status: `GREEN`
- Real Godot captures: `15/15`
- Automated PNG validation: `15/15`
- Human visual QA: `15/15`
- Unique SHA-256 values: `15/15`
- Total PNG bytes: `6,167,271`
- Godot stderr errors: `0`
- Godot processes after capture: `0`

Both full-table images now use a dedicated complete overview: three columns at 1920x1080 and two columns at 1366x768. The overview includes six-color assets, card language, opaque planet, representative map entities, typography/audio, and Credits.

The focused images prove final card-back content, nonwrapping six-color values, unobstructed hover/drag transforms, opaque day/night/zoom planet states, inspectable facilities, six distinct monsters, four deterministic mech tiers, three deterministic ship roles, and visible canonical Credits.

## Repaired Findings

- Removed visible card-back placeholder copy and used the Catalog-bound geometric pattern.
- Added interaction transform headroom without changing the fixed hover or drag values.
- Replaced fixed-distance model previews with local-hierarchy AABB fitting and orthographic framing.
- Isolated facility, monster, and military/shipping captures.
- Finalized Credits scrolling after container layout, preventing capture-state leakage.

## Boundaries

The Review scene creates no game Session, writes no Save, consumes no RNG, mutates no gameplay state, and has no production or Main authority. No Formal run or full Smoke was performed.

Exact dimensions, byte counts, and SHA-256 values for all 15 files are recorded in `presentation_capture_green_owner.json`.
