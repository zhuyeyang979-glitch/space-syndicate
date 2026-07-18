# World Session Envelope Save Audit

Date: 2026-07-19

Baseline: `b2ddcf823bfb00ed9333757dd56f6ffb1889c6e8`

## Decision

The existing `session` section remains the only registry section for session
lifecycle and viewer-scoped world-session data. Its binding keeps
`section_id=session`, `owner_id=game_session`, and transactional restore, while
the section state version advances from 1 to 2.

`SessionEnvelopeSaveOwner` is a stateless section adapter. It composes three
existing authorities without copying their runtime state:

- `GameSessionRuntimeController`: lifecycle, setup receipt, and outcome.
- `WorldSessionState`: players, districts, game time, geometry, role identity,
  and city-guess data.
- `CardHistoryPrivateAnnotationService`: viewer annotations and bounded role
  usage.

The registry remains at 19 sections after the preceding card-resolution
history owner cutover. The existing transactional `card_resolution_history`
section is position 15 and the composite `session` section remains position 19.
This stage adds no section: no `intel`, `world_session`, or `card_annotations`
section exists.

## Transaction

Capture obtains validated, deep-copied, data-only snapshots from all three
owners. Structural preflight validates every child and the cross-owner viewer
count without reading live public history. Registry cross-section preflight
then validates private annotation references against the normalized history
section from the same envelope before any mutation. Apply order is
WorldSession, private annotations, then session lifecycle. A child failure
rolls back touched owners in reverse order.

One-shot test faults cover before and after each child apply. These controls are
not persisted and are not exposed to production UI.

## Compatibility

An idle v1 session with no session ID, setup, outcome, players, or gameplay
state may normalize to an empty v2 session. An active v1 session is rejected
with `session_v1_world_state_missing` and `requires_backup=true`; the loader
does not fabricate players, districts, guesses, or annotations.

## Scope Limit

This cutover does not claim full-run resume. Twelve sections are transactional
and seven registry sections remain
unsupported: `ruleset`, `routes`, `commodity_belt_visibility`,
`card_inventory`, `military`, `card_resolution_queue`, and `ai`. The production
loader therefore continues to fail closed until all registry sections are
applicable.

Focused evidence is provided by
`res://tests/session_envelope_save_owner_test.gd` and
`res://scenes/tools/SessionEnvelopeSaveOwnerBench.tscn`.
