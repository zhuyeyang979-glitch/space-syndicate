# PR Checklist

Use this checklist before asking for review or merging.

## Ownership

- [ ] Codex owner is declared: A / B / human / mixed.
- [ ] Allowed files are listed.
- [ ] Forbidden files were not modified, or the exception is explained.
- [ ] Shared files touched are listed with function names.

## Change classification and proof scope

- [ ] `CHANGE_CLASS` is one of `DOCS_ONLY`, `TOOLING_ONLY`,
  `TEST_ORACLE_ONLY`, `DOMAIN_CORE`, `CROSS_DOMAIN_INTEGRATION`,
  `PRODUCTION_COMPOSITION`, `RULESET_CONSTITUTION`, or `RELEASE_CANDIDATE`.
- [ ] Affected domains, affected Owners, focused tests, and inherited sentinels
  are listed.
- [ ] `full_reproof_required` is declared. If true, the exact trigger, affected
  Owner set, and reason focused tests are insufficient are recorded.
- [ ] The requested test scope follows the declared change class. A
  `TOOLING_ONLY` or `DOCS_ONLY` delta does not run a full product reproof without
  a qualifying trigger.

## V0.7.6 reuse and point inertia

- [ ] Every new or modified production-reachable V0.7.6 component is classified
  in the one Historical Reuse Registry `component_inventory`.
- [ ] Every non-Owner component binds the exact existing Owner; every active
  domain retains exactly one production Owner.
- [ ] A new Owner includes the required reuse searches and non-empty reasons;
  an Owner replacement includes atomic Supersession and retirement with zero
  dual write, fallback, and old production reachability.
- [ ] Inherited Green, Golden Scenario, and Card Certification records are
  monotonic, or a regression retains the old record with complete evidence.
- [ ] The PR body contains exactly the output of
  `python tools/v076/v076_reuse_point_inertia_gate.py render-status` between the
  canonical V076 status markers.
- [ ] The newest exact-name check on the live current PR Head is completed
  `SUCCESS` and no newer exact-name run is pending or failed; older duplicate
  runs do not override the newest result.
- [ ] PR #93 remains Draft until all independent release gates are satisfied;
  no Ready transition, merge, release tag, or production cutover occurred before
  the mandatory Gate succeeded.

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

Select tests from `CHANGE_CLASS`. For the V0.7.6 Gate's exact
`TOOLING_ONLY` plus `DOCS_ONLY` delta, run only its Python self-test, reused
static scanner, JSON/schema checks, PR-body comparison, and CI definition
validation; do not run Godot, MCP, gameplay, or the full product suite.

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
