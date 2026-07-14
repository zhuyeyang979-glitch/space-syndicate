# Final Settlement Public Cash Visibility (v0.6)

## Frozen boundary

`FinalSettlementPublicSnapshotService` uses a state-aware, fail-closed allowlist for exact cash.

An exact per-seat cash ledger may appear on the public settlement board only when both conditions are true in the source supplied by the Victory-owned boundary:

1. `cash_visibility == "public_audit"`;
2. that entry's integer `player_index` is present in the authoritative `audit_revealed_player_indices` array.

The service never infers disclosure from the existence of a cash field, winner status, `game_over`, outcome completion, rank, or viewer identity. Missing, malformed, contradictory, or partial authority hides the value.

For an authorized audit-revealed seat, only the integer `cash_ledger_cents` from the canonical `rank_entries` record is rendered. The service does not calculate a ledger from `cash`, available cash, or escrow, and does not reconcile a second money-source value. Duplicate canonical records with conflicting ledgers fail closed for that seat.

All other seats use the privacy copy:

> 现金为最终并列判定项，数值保密

The public board continues to show receipt-owned rank order and winners, Top-K personally attributed GDP, controlled-region counts, the public comparison order, and already-public postgame facts.

## Recursive enforcement

The service accepts a `Dictionary` but does not copy it into the board. It builds an allowlisted presentation and recursively sanitizes the complete valid, empty, or error snapshot.

The sanitizer removes exact-cash keys and aliases, redacts cash-labelled numeric text, and redacts private cash tokens discovered under internal cash fields. Authorized audit cash is introduced only after that recursive pass through an internal structured marker generated for a roster-approved `player_index`; arbitrary source text cannot create that marker.

The output contains no raw `cash`, `cash_cents`, `cash_ledger_cents`, `available`, `available_cents`, `escrow`, or `escrow_cents` keys. Available and escrow components are never rendered by this service. `compose()` does not mutate or reorder its source, and repeated calls with the same source return equal presentation data.

The service still owns no winner calculation, sorting, Top-K score calculation, region-control calculation, cash calculation, audit roster, or cash-visibility state.

## Current owner gap

The current `FinalSettlementPublicSourceAdapter` produces a cash-free source and does not yet forward a Victory-owned `cash_visibility` or `audit_revealed_player_indices` capability. Therefore the current production path correctly fails closed and hides every exact cash value. Enabling the rulebook's audit disclosure requires the Victory owner and source adapter to publish those authority fields; the presentation service must not invent the roster.

## Focused oracle

`res://tests/final_settlement_public_privacy_v06_test.gd` instantiates the production service scene and calls the real `compose()` path. It covers:

- one roster-authorized audit seat whose exact ledger is visible in KPI, money-source, and rank output;
- one non-audit seat whose ledger, available cash, and escrow sentinels remain absent;
- cash fields plus `winner`/`game_over` without `cash_visibility`;
- `cash_visibility="public_audit"` without an authoritative roster;
- summary and public comparison order;
- empty and malformed receipt paths;
- recursive key/text/value scanning, source immutability, and repeated-compose purity.

The test does not use a hand-written already-sanitized board fixture. Console runs must isolate `APPDATA` and `LOCALAPPDATA`; final acceptance additionally requires an exclusive Godot MCP run of the real service scene, debug-output inspection, and an explicit stop.
