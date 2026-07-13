# City Development Runtime Cutover

## Runtime rule

Ruleset v0.4 does not allow a standalone direct-build action. A city surface can be created or strengthened only when a real `city_development` card opens a product project with all of these identities:

- target district
- product id
- project direction
- stable project id

`CityDevelopmentRuntimeController` owns this legality boundary and public-safe lifecycle evidence. It is instanced at:

`Main/RuntimeServices/RuntimeControllerHost/CityDevelopmentRuntimeController`

## Ownership

The controller reads capability data from `RulesetRuntimeBridge` and exposes:

- `configure(ruleset_snapshot)`
- `evaluate_development_request(request)`
- `record_project_opened(project_data)`
- `record_project_resolved(result_data)`
- `direct_build_allowed()`
- `project_binding_required()`
- `legacy_direct_build_reason()`
- `debug_snapshot()`

It does not calculate price, purchase cost, GDP, cashflow, product value, project contribution, project control, or urbanization share. Existing city-product-project and economy functions remain authoritative for settlement.

## Compatibility boundary

The legacy action ids `build`, `build_city`, `coach_build_city`, `keyboard_b`, and `ai_auto_build_city` retain their identity for old saves and callers. They are not reused for a new behavior. Under v0.4 they return the shared disabled reason and do not settle a city.

PlayerBoard quick actions, Coach progression, keyboard shortcuts, map controls, and ActionDock no longer expose an executable direct-build action. The disabled ActionDock compatibility row remains visible only to explain the ruleset change.

Map double-click continues to open the real district supply. First Table creates its first city surface by buying and resolving a real development card through the existing product-project settlement path.

## Privacy

Controller snapshots contain project identity, public project direction, public GDP evidence, and the current player's own share only when explicitly supplied for QA. They never include an owner index, contribution table, hidden controller identity, Callable, Node, Object, or Resource.

## Verification

Run these gates after changing the city-development entry path:

```text
godot --headless --path . --script res://tests/city_product_project_runtime_test.gd
godot --headless --path . --script res://tests/main_runtime_composition_test.gd
godot --headless --path . --script res://tests/layout_scene_smoke_test.gd
```

Then run `RulesetV04ConformanceBench`, `RuntimeCardResolutionTrackFlowBench`, and `FirstMissionRuntimeMainBench` through the project-internal Godot MCP addon.
