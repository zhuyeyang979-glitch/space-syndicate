# V0.7.3 First Human Playtest Guide

This candidate is the responsive-globe revision of the first observation-only human baseline for the fully connected V0.7.3 production ruleset. It supports New Game only. Save and Continue remain visible but disabled, and V0.6 save files are neither loaded nor modified.

## Candidate identity

- Ruleset: `v0.7.3`
- Balance profile: `v073_human_baseline_01`
- Profile fingerprint: `d696623d8cb3371d08c8870189927a53e48212ca30e9f276bc81b6491b01fbd2`
- Release tag: `alpha-0.5c1-v073-human-playtest-ui-globe-2`
- Superseded historical candidate: `alpha-0.5c-v073-human-playtest-1` (preserved, do not use for Run A/B)
- Human-fun status before these runs: unproven
- Production balance changes in this task: 0

Start the candidate from the repository root:

```powershell
pwsh -File .\tools\launch_space_syndicate.ps1
```

The launcher selects Godot 4.7 or newer and records the current Git commit as `build_sha`. Do not start Run A or Run B from a dirty gameplay worktree.

Before starting, verify that the checkout is the new candidate:

```powershell
git describe --tags --exact-match
```

The command must print `alpha-0.5c1-v073-human-playtest-ui-globe-2`.

## Planet controls

- Drag the planet with the left mouse button to rotate it.
- Use the mouse wheel or supported touchpad gesture to zoom.
- Double-click a visible region to focus it.
- Use `Overview` to return to the full globe and `Fullscreen` to enter or leave the expanded map.
- Click a region with no card selected to open its public Region Popup.
- Select a card, then click a legal front-side region to bind its target. The lower TargetRail remains a keyboard and accessibility fallback.
- Backside regions cannot be selected. Camera movement does not alter gameplay, RNG, solar rules, or the submission window.

## Run A: reproducible baseline

1. Use a 1600 x 960 window.
2. On the New Game panel, keep seed `900626424`.
3. Start the 4-player option: 1 local human and 3 production AI players.
4. Play naturally to FinalSettlement. Do not use developer shortcuts or the sanity-only acceleration control.
5. Use the contextual Coach Marks as needed, or choose `Skip all` and continue unaided. Confirm that the Coach never covers the current card, TargetRail, or map center.
6. During play, use `Confused`, `Frustrated`, or `Fun` whenever the feeling occurs. A short note is optional.
7. Close FinalSettlement, complete or deliberately skip the questionnaire, and wait for the non-blocking export confirmation.

Run A is valid only when the manifest records seed `900626424`, four players, ruleset `v0.7.3`, profile `v073_human_baseline_01`, and a `build_sha` reached by `alpha-0.5c1-v073-human-playtest-ui-globe-2`.

## Run B: natural experience

1. Use 1366 x 768 or the resolution you normally play at.
2. Choose `Random seed` on the New Game panel.
3. Start 1 local human plus 3 production AI players.
4. Play to FinalSettlement without trying to reproduce Run A decisions.
5. Use markers in the moment, then complete the same end-of-match questionnaire.

Run B must use the same frozen balance profile and responsive-globe candidate as Run A. The random seed is written to `manifest.json`.

## Optional Run C: roster pressure

Start 1 local human plus 5 or 7 AI players. This run is for observing two-column Roster readability, resolution wait, and repeated Fizzle fatigue. It does not replace Run A or Run B.

## What the build records

The observer records public receipts, the local player's own interactions, public presentation events, timing, Coach/Marker actions, and the final questionnaire. It does not record opponent hands, unannounced targets, AI private plans, the complete hidden lead order, private card instance IDs, account names, or machine paths. No report is sent over the network.

Each completed or intentionally closed session is written under:

```text
%APPDATA%\Godot\app_userdata\太空辛迪加\playtests\v073\<session_id>\
```

Return these four files from both required runs:

- `events.jsonl`
- `summary.json`
- `feedback.json`
- `report.md`

Keep `manifest.json` beside them; it contains the build SHA, seed, profile fingerprint, and file hashes used to verify the package.

## Baseline values to leave untouched

- Initial assets: 0 per color, cap 6 per color
- Starter cost: 0; standard L1 cost: 1 matching asset
- Unified Track ratio: 60% normal / 40% commodity
- Normal hand limit: 5; commodity inventory limit: 5
- Submission window: 30 seconds
- Sunlit efficiency: 2.0; dark efficiency: 1.0
- Fixed hidden round-robin resolution
- Facility contention: later action Fizzles, reservation releases, card discards, action slot is not refunded

Do not interpret discomfort during these two runs as permission to adjust values mid-run. The first balance pass begins only after both human reports have been returned.

## If export reports a failure

Finish the match normally. The export warning is non-blocking and must not change gameplay. Preserve the session directory and launcher log at `%LOCALAPPDATA%\SpaceSyndicate\launcher.log`; do not overwrite a V0.6 save or repeatedly retry the same export.
