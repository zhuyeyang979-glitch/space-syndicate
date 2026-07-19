# Intel application-flow extraction handoff

## Cutover result

The production path is now:

```text
MenuOverlay / GameScreen / typed table intent
  -> ApplicationFlowPort
  -> IntelApplicationFlowController
  -> IntelDossierViewerQueryPort
  -> IntelDossierBoard
  -> IntelPrivateCommandPort
  -> WorldSessionState or CardHistoryPrivateAnnotationService
```

The query port is fixed at
`res://scenes/runtime/presentation/IntelDossierViewerQueryPort.tscn` and
`res://scripts/presentation/intel_dossier_viewer_query_port.gd`. The retired
runtime query path is absent.

## Privacy contract

The query consumes `LocalViewerAuthorization`, public WorldSession facts, the
single scene-owned `RegionCodexPublicSourceService`, public card history, the
current viewer's city inference and annotations, and role public definitions.
Facility ownership is retained because it is explicitly public in the Region
Codex contract; raw warehouse inventory and hidden city ownership remain
forbidden. Query results are detached pure data and perform zero owner mutation
or route refresh.

## Command contract

Commands bind `command_id`, viewer, kind, subject, payload and expected owner
revision. Stale or unauthorized requests fail before mutation; terminal
receipts are held in a bounded exact-once cache. Current UI exposes four city
families (set/clear owner guess, confidence, reason) and existing narrow card
annotation delegation. No second state/save owner is introduced.

Card annotation owner revisions are viewer-local hashes of schema, viewer
index, that viewer's annotations and role usage. One viewer's mutation does not
stale another viewer's command or alter another viewer's snapshot.

## QA handoff

`res://scenes/tools/IntelDossierPublicSnapshotCutoverBench.tscn` is the bounded
formal `main.tscn` driver. A single run records viewer-private guess, viewer
isolation, authorized reveal, card annotation, and real FinalSettlement receipt
evidence under `res://docs/ui_qa/intel_query_command_split/`. It does not invoke
retired Main Intel methods or fabricate settlement data.

The coordinator should run final MCP/visual QA. Setup/save overall, AI strategy,
and settlement parity are intentionally not declared complete by this handoff.
