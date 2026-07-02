# PR Checklist

Use this checklist before asking for review or merging.

## Ownership

- [ ] Codex owner is declared: A / B / human / mixed.
- [ ] Allowed files are listed.
- [ ] Forbidden files were not modified, or the exception is explained.
- [ ] Shared files touched are listed with function names.

## Player-facing safety

- [ ] No opponent exact cash is exposed.
- [ ] No opponent hand or discard choice is exposed.
- [ ] No AI route plan, pressure bucket, utility score, or hidden candidate metadata is exposed.
- [ ] No true anonymous card owner is exposed unless game rules reveal it.
- [ ] Main table does not become a debug panel.

## Architecture

- [ ] New UI is in `scenes/ui/*` and `scripts/ui/*`, not constructed in `main.gd`.
- [ ] New UI consumes snapshots and emits signals.
- [ ] New runtime display data is in `scripts/viewmodels/*`, `scripts/runtime/*`, or `scripts/scenarios/*`.
- [ ] `main.gd` changes are thin wiring only, or justified.
- [ ] No economy/card/AI/monster formula changed unless this PR is explicitly about that rule.

## Scenario-specific

- [ ] Scenario data is in `data/scenarios/*`.
- [ ] Scenario logic is in `scripts/scenarios/*`.
- [ ] Scenario UI does not modify BidBoard/PublicTrack/CardTrack behavior.
- [ ] Scenario logs distinguish `public_text`, `private_text`, and `developer_text`.
- [ ] Player UI only shows public text and current-player private text.

## Tests

- [ ] `tests/ui_text_smoke_test.gd`
- [ ] `tests/visual_snapshot.gd`
- [ ] `tests/layout_scene_smoke_test.gd`
- [ ] `tests/scenario_smoke_test.gd` if scenarios changed
- [ ] `tests/scenario_progress_test.gd` if scenario goals changed
- [ ] `tests/scenario_privacy_test.gd` if logs/private data changed
- [ ] `tests/smoke_test.gd --check-only`
- [ ] full `tests/smoke_test.gd`, or known blocker documented

## Screenshots

- [ ] Main menu screenshot inspected.
- [ ] Play table screenshot inspected.
- [ ] Scenario browser screenshot inspected if scenario work changed.
- [ ] Relevant scenario screenshots inspected.

