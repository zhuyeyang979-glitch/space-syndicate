# Future production integration patch

Status: blocked until the production table exposes an authoritative seat host and public seat view model.

The current eight gold arcs are custom-drawn decoration, not seat nodes. Do not attach portraits by guessing `player_index == arc_index`, and do not import the QA `PlanetSeatLayout` algorithm.

Once the production owner provides stable seat roots, the minimal patch is:

1. Add one `PortraitSkinHost` child to each existing seat root without changing its position, size, z-index or input rectangle.
2. Instantiate `res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn` below that host.
3. Pass only the fields returned by `accepted_public_fields()`.
4. Resolve the role PNG through `RolePortraitCatalog.portrait_texture_or_null()`.
5. If `apply_public_view_model()` returns `true`, show the Skin and hide that seat's old arc/placeholder.
6. If it returns `false`, hide the Skin and show the old placeholder.
7. Never show both implementations at once.
8. Keep all Skin descendants at `MOUSE_FILTER_IGNORE`; the existing seat root retains hover/click/tooltip.
9. Suppress public-actor highlighting while an action is anonymous.
10. Re-run 3–8 player mapping, MapHost click/drag/zoom and central-planet diameter checks.

Do not modify `PlanetMapView`, `PlanetBoard`, `GameScreen`, their viewmodels or layout tests until their concurrent owners freeze those paths.
