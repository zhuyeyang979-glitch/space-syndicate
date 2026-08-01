extends SceneTree

const CATALOG_RESOURCE_PATH := "res://resources/presentation/alpha01_card_illustration_catalog.tres"
const CATALOG_SCENE_PATH := "res://scenes/runtime/CardIllustrationCatalog.tscn"
const EXPECTED_STABLE_ASSET_COUNT := 97

const EXPECTED_KEYS_BY_KIND := {
	"Texture2D": [
		"ui.panel.primary", "ui.panel.popup", "ui.button.primary",
		"icon.asset.life", "icon.asset.energy", "icon.asset.industry",
		"icon.asset.technology", "icon.asset.commerce", "icon.asset.shipping",
		"card.frame.normal", "card.frame.commodity", "card.frame.bound_action",
		"card.back.normal",
		"icon.board.draw_pile", "icon.board.discard_pile", "icon.board.shuffle",
		"icon.board.merge", "icon.board.lock", "icon.board.turn", "icon.board.target",
		"icon.board.card_count", "icon.board.gdp", "icon.board.cash",
		"icon.board.settlement", "icon.board.player_order",
		"icon.input.mouse_click", "icon.input.mouse_drag", "icon.input.mouse_wheel",
		"icon.input.keyboard_confirm", "icon.input.keyboard_cancel",
		"icon.input.keyboard_navigate", "icon.input.gamepad_confirm",
		"icon.input.gamepad_back", "icon.input.gamepad_navigate",
		"vfx.commodity.claim", "vfx.normal_card.purchase", "vfx.card.lock",
		"vfx.card.merge", "vfx.asset.refresh", "vfx.settlement.complete",
		"vfx.facility.damaged_smoke", "vfx.facility.factory_smoke",
		"vfx.monster.attack_smoke", "vfx.military.attack_smoke",
		"vfx.facility.destroyed_smoke",
	],
	"AudioStream": [
		"audio.ui.hover", "audio.ui.confirm", "audio.ui.cancel", "audio.card.select",
		"audio.card.drag_start", "audio.card.drop", "audio.card.lock",
		"audio.card.merge", "audio.asset.refresh", "audio.commodity.claim",
		"audio.normal_card.purchase", "audio.facility.factory_build",
		"audio.facility.market_build", "audio.facility.warehouse_build",
		"audio.monster.attack", "audio.military.action", "audio.settlement.complete",
		"music.menu", "music.gameplay", "music.crisis", "music.military",
	],
	"Font": [
		"font.body.zh", "font.body.ja", "font.display", "font.body.zh.bold",
		"font.body.ja.bold", "font.display.medium", "font.display.bold",
	],
	"Shader": [
		"shader.planet.body", "shader.planet.cloud", "shader.planet.atmosphere",
	],
	"Material": [
		"material.metal_plates_013", "material.painted_metal_007",
		"material.sheet_metal_003",
	],
	"Sky": ["environment.night_sky_hdri_001"],
	"PackedScene": [
		"model.facility.factory.base", "model.facility.market.base",
		"model.facility.warehouse.base", "model.facility.starport.base",
		"model.monster.life", "model.monster.energy", "model.monster.industry",
		"model.monster.technology", "model.monster.commerce", "model.monster.shipping",
		"model.military.tier1", "model.military.tier2", "model.military.tier3",
		"model.military.tier4", "model.shipping.route_marker",
		"model.shipping.convoy", "model.shipping.starport_showcase",
	],
}

const EXPECTED_KEYS_BY_SCOPE := {
	"production_safe_global_presentation": [
		"ui.panel.primary", "ui.panel.popup", "ui.button.primary", "font.body.zh",
		"font.body.ja", "font.display", "font.body.zh.bold", "font.body.ja.bold",
		"font.display.medium", "font.display.bold",
	],
	"reference_only_until_v07_projection": [
		"icon.asset.life", "icon.asset.energy", "icon.asset.industry",
		"icon.asset.technology", "icon.asset.commerce", "icon.asset.shipping",
		"card.back.normal",
	],
	"production_safe_existing_fact_only": [
		"card.frame.normal", "card.frame.commodity", "card.frame.bound_action",
		"icon.board.draw_pile", "icon.board.discard_pile", "icon.board.shuffle",
		"icon.board.merge", "icon.board.lock", "icon.board.turn", "icon.board.target",
		"icon.board.card_count", "icon.board.gdp", "icon.board.cash",
		"icon.board.settlement", "icon.board.player_order",
		"model.facility.factory.base", "model.facility.market.base",
		"model.facility.warehouse.base", "model.facility.starport.base",
		"model.monster.life", "model.monster.energy", "model.monster.industry",
		"model.monster.technology", "model.monster.commerce", "model.monster.shipping",
		"model.military.tier1", "model.military.tier2", "model.military.tier3",
		"model.military.tier4",
	],
	"production_safe_presentation_event": [
		"audio.ui.hover", "audio.ui.confirm", "audio.ui.cancel", "audio.card.select",
		"audio.card.drag_start", "audio.card.drop",
	],
	"reference_only_until_v07_receipt": [
		"audio.card.lock", "audio.card.merge", "audio.asset.refresh", "vfx.card.lock",
		"vfx.card.merge", "vfx.asset.refresh",
	],
	"production_safe_receipt_driven": [
		"audio.commodity.claim", "audio.normal_card.purchase",
		"audio.facility.factory_build", "audio.facility.market_build",
		"audio.facility.warehouse_build", "audio.settlement.complete",
	],
	"production_safe_public_event": ["audio.monster.attack", "audio.military.action"],
	"production_safe_public_state_only": [
		"music.menu", "music.gameplay", "music.crisis", "music.military",
	],
	"production_safe_supported_device_only": [
		"icon.input.mouse_click", "icon.input.mouse_drag", "icon.input.mouse_wheel",
		"icon.input.keyboard_confirm", "icon.input.keyboard_cancel",
		"icon.input.keyboard_navigate", "icon.input.gamepad_confirm",
		"icon.input.gamepad_back", "icon.input.gamepad_navigate",
	],
	"production_safe_receipt_or_public_event": [
		"vfx.commodity.claim", "vfx.normal_card.purchase", "vfx.settlement.complete",
		"vfx.facility.damaged_smoke", "vfx.facility.factory_smoke",
		"vfx.monster.attack_smoke", "vfx.military.attack_smoke",
		"vfx.facility.destroyed_smoke",
	],
	"production_safe_presentation_only": [
		"shader.planet.body", "shader.planet.cloud", "shader.planet.atmosphere",
		"material.metal_plates_013", "material.painted_metal_007",
		"material.sheet_metal_003", "environment.night_sky_hdri_001",
	],
	"production_safe_decorative_only": [
		"model.shipping.route_marker", "model.shipping.convoy",
		"model.shipping.starport_showcase",
	],
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var production_catalog := load(CATALOG_RESOURCE_PATH) as CardIllustrationCatalogResource
	_expect(production_catalog != null, "existing catalog resource loads")
	if production_catalog == null:
		_finish()
		return
	var original_report := production_catalog.validation_report()
	_expect(bool(original_report.get("valid", false)), "legacy illustration validation remains green")
	_expect(production_catalog.stable_asset_schema_version == "commercial.presentation_assets.v1", "stable asset schema version remains canonical")
	_expect(int(original_report.get("stable_asset_count", -1)) == EXPECTED_STABLE_ASSET_COUNT, "all final commercial presentation assets are registered")

	var expected_contract := _build_expected_contract()
	_expect(expected_contract.size() == EXPECTED_STABLE_ASSET_COUNT, "final test contract defines exactly 97 unique stable keys")
	_expect(production_catalog.stable_asset_keys.size() == EXPECTED_STABLE_ASSET_COUNT, "catalog exposes exactly 97 stable keys")
	_expect(production_catalog.stable_asset_resources.size() == EXPECTED_STABLE_ASSET_COUNT \
		and production_catalog.stable_asset_kinds.size() == EXPECTED_STABLE_ASSET_COUNT \
		and production_catalog.stable_asset_scopes.size() == EXPECTED_STABLE_ASSET_COUNT, "stable catalog arrays remain parallel at 97 rows")
	var actual_seen := {}
	for key_value in production_catalog.stable_asset_keys:
		var actual_key := str(key_value)
		_expect(not actual_seen.has(actual_key), "catalog stable key is unique: %s" % actual_key)
		actual_seen[actual_key] = true
	var missing_keys: Array[String] = []
	var unexpected_keys: Array[String] = []
	for expected_key in expected_contract:
		if not actual_seen.has(expected_key):
			missing_keys.append(expected_key)
	for actual_key in actual_seen:
		if not expected_contract.has(actual_key):
			unexpected_keys.append(actual_key)
	_expect(missing_keys.is_empty(), "final stable key contract has no missing keys: %s" % str(missing_keys))
	_expect(unexpected_keys.is_empty(), "final stable key contract has no unexpected keys: %s" % str(unexpected_keys))
	for expected_key in expected_contract:
		_verify_catalog_row(production_catalog, expected_key, expected_contract[expected_key] as Dictionary)

	var legacy_key := StringName(production_catalog.presentation_keys[0])
	_expect(production_catalog.resource_for_asset_key(legacy_key) == production_catalog.texture_for_key(legacy_key), "legacy texture lookup delegates to the canonical resource resolver")
	_expect(production_catalog.asset_kind_for_key(legacy_key) == &"Texture2D" \
		and production_catalog.asset_scope_for_key(legacy_key) == &"legacy_card_illustration", "legacy illustration keys retain typed compatibility metadata")

	var fixture := production_catalog.duplicate(true) as CardIllustrationCatalogResource
	var texture := GradientTexture1D.new()
	texture.gradient = Gradient.new()
	fixture.stable_asset_keys.append("qa.fixture.texture")
	fixture.stable_asset_resources.append(texture)
	fixture.stable_asset_kinds.append("Texture2D")
	fixture.stable_asset_scopes.append("reference_only_until_v07_projection")
	var fixture_report := fixture.validation_report()
	_expect(bool(fixture_report.get("valid", false)) \
		and int(fixture_report.get("stable_asset_count", 0)) == EXPECTED_STABLE_ASSET_COUNT + 1, "typed stable asset row validates")
	_expect(fixture.has_asset_key(&"qa.fixture.texture") \
		and fixture.resource_for_asset_key(&"qa.fixture.texture") == texture \
		and fixture.asset_kind_for_key(&"qa.fixture.texture") == &"Texture2D" \
		and fixture.asset_scope_for_key(&"qa.fixture.texture") == &"reference_only_until_v07_projection", "stable key resolves resource, kind, and scope without a vendor path")
	_expect(fixture.all_asset_keys().size() == production_catalog.all_asset_keys().size() + 1, "legacy and commercial keys share one owner")

	var invalid := fixture.duplicate(true) as CardIllustrationCatalogResource
	invalid.stable_asset_kinds[invalid.stable_asset_kinds.size() - 1] = "AudioStream"
	var invalid_report := invalid.validation_report()
	_expect(not bool(invalid_report.get("valid", true)) \
		and _has_error(invalid_report, "stable_asset_kind_mismatch:qa.fixture.texture:AudioStream"), "kind mismatch fails closed")
	invalid = fixture.duplicate(true) as CardIllustrationCatalogResource
	invalid.stable_asset_keys[invalid.stable_asset_keys.size() - 1] = "res://vendor/file.png"
	invalid_report = invalid.validation_report()
	_expect(not bool(invalid_report.get("valid", true)) \
		and _has_error_prefix(invalid_report, "stable_asset_key_invalid:"), "resource paths are rejected as public asset keys")

	var service := (load(CATALOG_SCENE_PATH) as PackedScene).instantiate() as CardIllustrationCatalog
	service.catalog = fixture
	root.add_child(service)
	_expect(service.has_asset_key(&"qa.fixture.texture") \
		and service.resource_for_asset_key(&"qa.fixture.texture") == texture \
		and int(service.debug_snapshot().get("stable_asset_count", 0)) == EXPECTED_STABLE_ASSET_COUNT + 1, "existing scene service exposes the generic catalog API")
	service.queue_free()
	await process_frame
	_finish()


func _build_expected_contract() -> Dictionary:
	var contract := {}
	for expected_kind in EXPECTED_KEYS_BY_KIND:
		for key_value in EXPECTED_KEYS_BY_KIND[expected_kind] as Array:
			var asset_key := str(key_value)
			_expect(not contract.has(asset_key), "final kind contract key is unique: %s" % asset_key)
			contract[asset_key] = {"kind": str(expected_kind), "scope": ""}
	var scoped_keys := {}
	for expected_scope in EXPECTED_KEYS_BY_SCOPE:
		for key_value in EXPECTED_KEYS_BY_SCOPE[expected_scope] as Array:
			var asset_key := str(key_value)
			_expect(contract.has(asset_key), "scope contract key exists in kind contract: %s" % asset_key)
			_expect(not scoped_keys.has(asset_key), "final scope contract key is unique: %s" % asset_key)
			scoped_keys[asset_key] = true
			if contract.has(asset_key):
				contract[asset_key]["scope"] = str(expected_scope)
	_expect(scoped_keys.size() == EXPECTED_STABLE_ASSET_COUNT, "scope contract covers exactly 97 stable keys")
	for asset_key in contract:
		_expect(not str(contract[asset_key].get("scope", "")).is_empty(), "stable key has an expected scope: %s" % asset_key)
	return contract


func _verify_catalog_row(catalog: CardIllustrationCatalogResource, asset_key: String, expected: Dictionary) -> void:
	var key_name := StringName(asset_key)
	var resource := catalog.resource_for_asset_key(key_name)
	var expected_kind := str(expected.get("kind", ""))
	var expected_scope := str(expected.get("scope", ""))
	_expect(resource != null, "stable key resolves a resource: %s" % asset_key)
	_expect(str(catalog.asset_kind_for_key(key_name)) == expected_kind, "stable key kind matches final contract: %s" % asset_key)
	_expect(str(catalog.asset_scope_for_key(key_name)) == expected_scope, "stable key scope matches final contract: %s" % asset_key)
	var resource_path := resource.resource_path if resource != null else ""
	_expect(resource_path.begins_with("res://") and ResourceLoader.exists(resource_path), "stable key points to an existing local resource: %s" % asset_key)
	var reloaded := ResourceLoader.load(resource_path) if not resource_path.is_empty() else null
	_expect(reloaded != null and _resource_matches_kind(reloaded, expected_kind), "stable key resource reloads with its declared type: %s" % asset_key)


func _resource_matches_kind(resource: Resource, kind: String) -> bool:
	match kind:
		"Texture2D":
			return resource is Texture2D
		"PackedScene":
			return resource is PackedScene
		"AudioStream":
			return resource is AudioStream
		"Font":
			return resource is Font
		"Shader":
			return resource is Shader
		"Material":
			return resource is Material
		"Sky":
			return resource is Sky
	return false


func _has_error(report: Dictionary, expected: String) -> bool:
	for value in report.get("errors", []) as Array:
		if str(value) == expected:
			return true
	return false


func _has_error_prefix(report: Dictionary, prefix: String) -> bool:
	for value in report.get("errors", []) as Array:
		if str(value).begins_with(prefix):
			return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures.append(label)
		push_error("[FAIL] %s" % label)


func _finish() -> void:
	print("COMMERCIAL_PRESENTATION_CATALOG_CONTRACT checks=%d failures=%d stable_keys=%d" % [_checks, _failures.size(), EXPECTED_STABLE_ASSET_COUNT])
	quit(0 if _failures.is_empty() else 1)
