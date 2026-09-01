# Alpha 0.7 Living Planet — Human Candidate 3 card-table flow

This is a new append-only Candidate 3 record. Candidate 2 blocker evidence is
preserved and is not overwritten.

```text
STATUS=PRE_GOLDEN_READY_FOR_REAL_HUMAN_RETEST
READY_FOR_REAL_HUMAN_RETEST=true
HUMAN_GREEN=false
FULL_PRODUCT_PRODUCTION_GREEN=false
STEP13_STATUS=PENDING
FULL_WORLD_REPROOF_COUNT=0
PR93_IS_DRAFT=true
```

The real production scene is `res://scenes/main.tscn`, one human plus three AI
seats, with zero fixture card/track/AI injection. The final isolated production
probe passed `391/391`; it reported three AI public cards, fifteen central
arrangement entries, fifteen formation/card animations, 100% card-face and
hover coverage, zero transition failures, and no presentation gameplay or RNG
mutation. Three authority handoffs measured `1.385s`, `1.418s`, and `1.452s`;
the authority sequence advanced `1 -> 2 -> 3` with the recorded vacancy
lineage in the JSON manifest.

Focused gates also passed: privacy `8/8`, public arrangement `8/8`, requeue
identity `12/12`, AI privacy `57/57`, human playability `182/182`, pacing
`11/11`, loading feedback `19/19`, sushi-track authority `42/42`, and the
responsive matrix `7 cases / 144 checks`. UI text, visual snapshot, smoke
`--check-only`, runtime parse, and `git diff --check` passed.

The probe's headless shutdown still reports renderer/ObjectDB/resource residuals
(49 material, 7 shader, 73 mesh, 128 texture, 22 shaped-text, 9 font RIDs;
25 CanvasItems; 820 ObjectDB instances; 535 resources; paged allocator
residual). These are recorded as cleanup diagnostics, not silently discarded;
the isolated run had no hard product runtime error. The headed MCP run likewise
reported only existing GDScript reload warnings and no hard error.

The desktop shortcut now resolves to the Candidate 3 launcher and working
directory. The explicitly old `AppData/Local/SpaceSyndicate/launcher.log`
(2,696 bytes, SHA-256
`22FE9650AC2102ECE59D0BC91593E45B2FE70B8CD3D99498148D3E4D959236CA`) was
moved to the Recycle Bin. `.codex` backups/sessions, Godot userdata, and the
active worktree were retained.

The final headed window is intentionally left open. The next action is the
human's short nine-item retest, especially shared-track acquisition, dragging a
legal hand card into the central 30-second public arrangement, and observing
AI card faces/hover behavior. STEP13–15 remain blocked until the human confirms
the candidate.
