# ADR 0001: Parallel Codex Boundaries

## Status

Accepted.

## Context

The prototype has grown quickly. `scripts/main.gd` still contains much of the runtime, UI wiring, and legacy prototype logic, while new UI work is increasingly split into `scenes/ui/*`, `scripts/ui/*`, and `scripts/viewmodels/*`.

Two Codex workstreams now need to proceed in parallel:

- Codex A: anonymous card track, BidBoard, IntelDossier evidence chain.
- Codex B: playable scenario lab, scenario coach, action logs, replay fixtures, playability verification.

Without explicit ownership, both agents will naturally touch `main.gd`, shared snapshots, and broad tests, creating unnecessary conflicts.

## Decision

We will keep `main.gd` as a runtime facade for now, but new work must live in owned modules where possible.

Codex A owns PublicTrack/CardTrack/BidBoard/IntelDossier behavior.

Codex B owns ScenarioBrowser/ScenarioCoach/ScenarioActionLog/ScenarioReplayPanel and scenario fixtures/tests.

Shared files require explicit PR notes listing touched functions and why the change could not remain in an owned module.

## Consequences

- Parallel work can proceed with fewer merge conflicts.
- Scenario fixtures can prepare BidBoard/PublicTrack states without changing Codex A behavior.
- New UI should not be constructed directly in `main.gd`.
- Tests will increasingly verify player playability, privacy, and screenshot review rather than only source-string presence.

