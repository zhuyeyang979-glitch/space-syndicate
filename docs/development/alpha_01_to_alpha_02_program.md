# Alpha 0.1 → Alpha 0.2 Complete Productization Program

This is the live milestone map for the productization program. It does not
claim that Alpha 0.1 or Alpha 0.2 is complete. The authoritative machine state
is in `current_program_state.json`; task dependencies and write leases are in
`current_task_graph.json` and `current_file_ownership.json`.

## Current baseline

- Initial program baseline: `ce6853cb75c10fdfed457431d638af9009a01083`
- Current `origin/main`: `cb9194a32e86c20287572b20b92acc0064fcd858`
- Open pull requests: 0
- Current-head Windows build: none
- GitHub draft prereleases: none
- Full-run resume claim: false
- Public release published: false

## Milestone map

| Phase | State | Evidence or blocker |
|---|---|---|
| Repository/program reconciliation | Merge ready | State, task graph, ownership and this program map are regenerated from `cb9194a`. |
| P0 AI typed cash | Merged | PR #45; AI business costs use typed cash authority. |
| P0 CommodityFlow post-commit exact-once | Merged / green | PR #46; ordered lineage, forward recovery, save preflight and Main path deletion are proven. |
| P0 AI world typed ports | Active preflight | CommodityFlow dependency is cleared; actor-scoped capability and privacy inventory is next. |
| Alpha 0.1 first economic engine | Active, unproven | Typed rack/purchase/facility play is proven; first Sale Receipt and positive GDP are not. |
| Alpha 0.1 terminal path | Blocked | Requires the first economic engine on current main. |
| Alpha 0.1 RC build | Blocked | The latest startable build is 30 commits behind current main and is not an RC zip. |
| Alpha 0.1 external playtest | External evidence required | Requires at least 5 testers, 10 matches and 5 completed matches. |
| Alpha 0.2 save/resume | Blocked | 12 of 19 required owners are transactional; cold restore is not proven. |
| Alpha 0.2 content Wave 2 | Blocked | Starts only after Alpha 0.1 feedback and safe owner coverage. |
| Alpha 0.2 art/audio/UX | Partial pipelines open | 8 role pairs, 5 production card illustrations and 8 monster identities are available; product icons and TableAudioHost remain open. |
| Alpha 0.2 RC | Blocked | Requires save/resume, content, art/audio/UX and current-head export evidence. |

## What PR #46 changed

`P0-COMMODITY-FLOW-POSTCOMMIT-EXACT-ONCE` is now merged. Every authoritative
CommodityFlow batch has one stable identity and fingerprint-bound lineage for
GDP/history, derivatives, pulse, cash snapshots, bankruptcy, PlayerMana,
public log and presentation invalidation. Interrupted work resumes before the
next simulation frame with zero world delta. The old Main callback and bridge
fallback are physically gone.

The broad full smoke is still not green: both `origin/main@ce6853c` and the PR
candidate stop at the same retired Main/old monster fixture after reporting the
same 32 script errors. `--check-only`, focused suites, production composition,
architecture gates and the Godot MCP Bench are green. No compatibility wrapper
was restored.

## Immediate dependency graph

```text
P0 Commodity post-commit exact-once (MERGED)
  -> P0 AI world typed ports (ACTIVE PREFLIGHT)
     -> TableAudioHost and later Main extinction work

P1 first economic engine (ACTIVE / UNPROVEN)
  -> P1 four-seat terminal path
     -> Alpha 0.1 current-head Windows RC
        -> external closed playtest
           -> Alpha 0.2 save/content/productization gates
```

## Parallel work that is safe now

- AI capability and privacy mapping in the dedicated typed-ports worktree.
- Current-main review of the first-economic-engine evidence branch without
  touching production owners.
- Save Owner coverage inventory and owner-specific child-task split, without
  changing the save format.
- Card-art Wave 1 new asset files, with production manifests reserved for the
  integration writer.
- One stale full-smoke fixture family at a time, without restoring Main.

## Claims deliberately not made

- No complete Alpha 0.1 match has been proven.
- No Alpha 0.1 RC zip or draft prerelease exists.
- No external playtest sample exists.
- Full-run save/resume remains false.
- Alpha 0.2 content, art/audio and RC gates are not complete.
- The overall program status remains `ACTIVE`, not green.
