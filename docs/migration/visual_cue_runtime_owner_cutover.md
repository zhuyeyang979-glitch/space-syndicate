# Visual cue runtime owner cutover

`VisualCueRuntimeOwner` is the unique transient presentation-state owner for map movement trails, action callouts, map event effects and district pulses. It is a child of the production `GameRuntimeCoordinator` and is consumed through explicit typed APIs.

## Time semantics

- active world frames advance cues with world delta;
- globally blocking forced decisions advance cues with real delta, preserving the existing table feedback;
- ordinary pause advances neither branch;
- the owner does not advance the world clock.

## State and save boundary

Transient cues are deliberately not part of the current save schema. New-session reset clears them. A one-way legacy importer accepts historical visual arrays and moves historical district `pulse` / `pulse_color` fields out of authoritative district records. Presentation snapshots reapply pulses only to a duplicate map-view input.

## Producers and consumers

Monster, military, weather and AI controllers receive the typed visual owner. Their visual helper paths no longer invoke Main through world bridges. Main's remaining economy/card presentation producers call explicit coordinator APIs, and PlanetMapView consumes the owner's public snapshot.

Callout sound effects remain behaviorally preserved: Main injects the existing scene-owned `AudioStreamPlayer` nodes into the owner, which owns cue classification and rate limiting without retaining a Main callback.

## Negative guarantees

- no gameplay mutation or world-clock ownership;
- no player cash, hand, hidden owner or AI plan data;
- no second save writer;
- no transient pulse fields in newly generated districts;
- one production owner;
- no controller visual callbacks into Main.
