# Bestiary Formal Product Path QA

Status: PASS

The focused driver instantiates the real `res://scenes/main.tscn`, starts a formal four-player session through the setup page's public start-button signal, and then uses viewport mouse input for every Compendium click and double-click. It consumes the production ApplicationFlow, Compendium flow, navigation owner, public query services, and Codex surface.

## Results

- Scenario A passed: Hub -> Monster Browser -> preview -> Monster Detail -> Card Detail -> Monster Detail -> Monster Browser -> second Monster Detail -> Browser -> Hub.
- Scenario B passed: Intel -> Hub -> Monster Browser -> Hub -> Intel.
- Checks: 29/29.
- Runtime: 6.504 seconds in the final headed 1600x960 run.
- Internal history: 4 pushes, 4 pops, 0 duplicate frames, 0 invalid frames, empty on exit.
- External return target: consumed exactly once in Scenario B.
- Preview: one request, zero full-page rebuilds.
- Double-click: one detail request and zero second-click previews.
- Monster-to-card deep link: one request using the public canonical card resolver.
- Duplicate page applies: 0.
- Gameplay, selection, persisted QA save file, and private Intel state mutations: 0.
- Main Compendium fallback: 0.
- Final headed console errors and warnings: 0.

Machine-readable evidence: [bestiary_formal_product_path_result.json](bestiary_formal_product_path_result.json)

## Screenshots

- [Monster browser](bestiary_formal_browser.png)
- [Monster detail](bestiary_formal_monster_detail.png)
- [Canonical card detail](bestiary_formal_card_detail.png)
- [Restored monster browser](bestiary_formal_browser_restored.png)

The four images were visually inspected. They are complete frames from the real main scene and contain no QA controls, machine paths, hidden monster ownership, player-private values, AI scores, or placeholder debug text.

## Fix Boundaries

- Thumbnail input distinguishes hover preview from click preview, so a real hover-plus-click emits preview exactly once while direct click-only input remains supported.
- `CodexNavigationRuntimeController` owns internal history separately from the external application return target.
- Preview never enters history; browser/detail and cross-domain detail transitions do.
- No `main.gd`, gameplay, save schema, AI, economy, Intel mutation, or public-source semantics were changed.
