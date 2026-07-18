# Main Compendium application-flow inventory

Status: `CUT_OVER`

## Physically removed Main routes

- `_open_compendium_menu`
- `_on_codex_surface_action_requested`
- `_cycle_menu_catalog`
- `_back_from_catalog_menu`
- `_open_card_codex_by_name`
- `_update_card_codex_menu`
- `_open_bestiary_menu`
- `_update_bestiary_menu`
- `_update_product_codex_menu`
- `_update_region_codex_menu`
- `_update_role_codex_menu`
- `_present_codex_page`
- domain-specific browser/preview/detail and Intel-link wrappers
- Main catalog signal connections and Compendium-only preload

No failure path returns to these methods. MenuOverlay catalog-step, catalog-back
and Codex surface actions connect directly to the scene-owned Compendium flow.

## Retained shared helpers

- `_codex_role_route_label`: setup and gameplay role-card presentation still use
  it; it queries the existing public snapshot owner.
- `_product_count_summary`, product profile/strategy helpers: AI and balance
  diagnostics still consume them; they are not Compendium navigation owners.
- `_product_catalog_names`: existing gameplay and diagnostics consumers remain.
- `_make_player_role_card` / `_player_role_catalog_size`: setup, AI, passive and
  save consumers remain; both query RoleCatalogRuntimeService and own no catalog.
- Intel guess mutation helpers remain viewer-private and outside this cutover.

## Explicit non-cutovers

Intel query/command split, setup, save/load, gameplay catalogs and PlayerSeat
remaining architecture debt are not marked migrated by this slice.
