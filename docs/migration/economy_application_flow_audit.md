# Economy application-flow audit

Status: `ECONOMY_APPLICATION_FLOW_AUDIT_COMPLETE`
Baseline: `c274af87faa1aeb5ea85af9d28849ff5f7e16270`

Before cutover, normal navigation and final-settlement navigation emitted the generic application action and entered `Main._on_menu_quick_nav_action_requested`. Intel's `intel_open_economy` and the catalog return target also called Main's economy opener directly.

The former source adapter called `ensure_catalog` and refreshed the route network while opening a read-only page. Those calls could normalize catalog state, consume RNG, rebuild route caches and change revisions. It also treated `TableSelectionState.selected_player` as the viewer and allowed `game_over` to expose every seat's exact economy.

The cutover uses these authoritative read APIs only:

- `TablePresentationQueryPorts`: viewer authorization, public world, own private world, public log.
- `ProductMarketRuntimeController.public_market_snapshot`: initialized public catalog and market facts.
- `CommodityFlowRuntimeController`: public regional GDP, backlog, waste, actual flow and authorized own receipts/warehouse facts.
- `RouteNetworkRuntimeController.public_cached_route_snapshot`: cached-only public routes.
- `RegionInfrastructureRuntimeController`: public facilities/integrity and authorized own facilities.
- `WeatherRuntimeController.public_snapshot`, public monster roster and `WorldSessionState.public_lifecycle_snapshot`.

Main-only shared helpers used by intel, AI, topbar or gameplay remain in place and are not copied into the new query port. The new path contains no `current_scene`, `/root/Main`, dynamic method probing, catalog initialization, route refresh or mutation fallback.
