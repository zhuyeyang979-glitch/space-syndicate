# Standings public snapshot v0.6 asset migration

`StandingsPublicSnapshotService` no longer consumes the retired
`economic_assets.project_positions` envelope and no longer renders project-share
counts.

The current privacy boundary is:

- `VictoryControlRuntimeController.public_snapshot()` may publish authorized
  audit progress and exact `cash_ledger_cents` for seats in the authoritative
  audit roster.
- Public audit rows do not publish facilities, installations, commodity
  inventory, color GDP, units, contracts, financial positions, hands, or AI
  plans.
- A viewer-owned seat may receive `own_economic_assets` through a
  viewer-private standings source. The presentation reduces those current v0.6
  fields to counts only:
  `facilities`, `installations`, `commodity_inventory`, `color_gdp`, `units`,
  `contracts`, and `financial_positions`.
- Rival `own_economic_assets`, caller-forged public asset envelopes, and legacy
  project-position fields are ignored.

This preserves the v0.6 distinction between single-owner facilities and
commodity-GDP-based region control. The standings presentation does not
recalculate control, infer ownership, or revive transferable city/project
shares.
