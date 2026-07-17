# Main economy application-flow inventory

The five Main page methods and `EconomyDashboardScene` preload were economy-only and are deleted. The generic quick-navigation branch, Intel direct opener and catalog return branch are also deleted or redirected to the dedicated application intent.

Also deleted as economy-page-only helpers: `_economy_product_entries`, `_economy_city_income_entries`, `_economy_card_aftermath_entries`, `_economy_inference_board_lines`, `_economy_player_cash_entries` and their private inference-only subhelpers.

Retained shared helpers include warehouse risk, city clues, monster clues and owner-view helpers used by Intel; product names and market cycle used by gameplay; player GDP used by the topbar; and active-city/income helpers used by AI or Intel. They remain legacy debt with real non-economy-page consumers and are not called by `EconomyDashboardViewerQueryPort`.

Production path:

`MenuOverlay → ApplicationFlowPort.economy_requested → EconomyApplicationFlowController → EconomyDashboardViewerQueryPort → EconomyDashboardPublicSnapshotService → EconomyDashboard`
