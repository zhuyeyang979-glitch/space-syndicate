# VS06-C acceptance specification

Execution owner: coordination thread. Agent C authors the harness and performs parse-only self-checks.

The runtime manifest has ten mandatory red/green records. Each record is produced from real `main.tscn` actions plus authoritative before/after snapshots or receipts; there are no skip-to-green placeholders:

1. root `new_run` -> `NewGameSetupPage`, including the idle-close guard;
2. real `setup_start` creates 1 human + 2 AI and refreshes CoreEconomic actor bindings;
3. human first summon adds exactly one monster and one finalized v0.6 lifecycle receipt;
4. a production-catalog rank-I `public_facility` is bought from the regional rack and committed/finalized exactly once through CoreEconomic CardFlow;
5. CommodityFlow seconds produce a Sale Receipt, GDP, and cash-ledger delta;
6. both AI first-summon and at least one AI gains an income source plus a buy/play action without queue deadlock;
7. VictoryControl traverses configured qualification and audit timers before producing its outcome receipt;
8. the outcome opens one settlement/recap and receipt replay does not duplicate it;
9. independent recursive snapshot and rendered-control scans report zero privacy leaks, including AI setup starters and AI-seat rack cash/hand facts;
10. save write/read stays under the QA path and the default player-save SHA-256 fingerprint remains unchanged.

Current runtime evidence status: `pending_coordinator_execution`.
