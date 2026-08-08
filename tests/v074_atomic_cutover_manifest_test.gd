extends SceneTree

const MANIFEST_PATH := "res://docs/migration/v074_atomic_cutover_manifest.json"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const V074_COMPOSITION_PATH := "res://scenes/runtime/V074RuntimeComposition.tscn"
const V074_BOOTSTRAP_PATH := "res://scripts/v074_runtime/v074_application_bootstrap.gd"
const V074_SCREEN_PATH := "res://scenes/ui/v074/V074SampleGameScreen.tscn"
const LEGACY_MAIN_PATH := "res://scripts/main.gd"

const EXPECTED_TOP_LEVEL_FIELDS := [
	"schema",
	"task_id",
	"base_main_sha",
	"constitution_id",
	"ruleset_id",
	"current_production_runtime_ruleset",
	"production_main_scene",
	"production_bootstrap",
	"new_game_only",
	"save_resume_enabled",
	"domain_count",
	"connected_domain_count",
	"legacy_disconnected_domain_count",
	"domains",
	"required_final_counts",
]
const EXPECTED_DOMAIN_FIELDS := [
	"domain",
	"target_owner",
	"status",
	"connected",
	"legacy_disconnected",
	"save_owner_declared",
	"rng_owner_declared",
	"rollback_boundary_declared",
]
const EXPECTED_DOMAIN_OWNERS := {
	"map_genesis": "V074MapGenesisCore",
	"region_registry": "V074MapGenesisCore",
	"terrain_registry": "V074MapGenesisCore",
	"facility_type_registry": "V074FacilityTypeRegistry",
	"facility_slot_registry": "V074MapGenesisCore",
	"warehouse_runtime": (
		"V074FacilityRuntimeCore + V074WarehouseRuntimePolicy"
	),
	"warehouse_card_catalog": (
		"V074CardDefinitionRegistry + V074WarehouseCardCatalog"
		+ " + V07UnifiedCardTrackCore"
	),
	"warehouse_ai_projection": "V074DynamicMapAiObservationAdapter",
	"warehouse_player_projection": "V074PlayerMapProjectionAdapter",
	"solar_geometry": "V074MapGenesisCore",
	"planet_presentation": (
		"V074PlanetPresentationAdapterV1 + PlanetMapView"
	),
	"map_target_selection": (
		"V074MapTargetBindingV1 + V074PlayerMapProjectionAdapter"
		+ " + V074SampleGameScreen"
	),
	"unified_track_local_projection": (
		"V074SharedSushiTrackCore + V074SampleGameScreen"
	),
	"unified_track_shared_scroll_timing": "V074SharedSushiTrackCore",
	"asset_pool_presentation": (
		"V074AssetPipPresenter + V074AssetPipGroup"
		+ " + V074SampleGameScreen"
	),
}
const EXPECTED_DOMAIN_ORDER := [
	"map_genesis",
	"region_registry",
	"terrain_registry",
	"facility_type_registry",
	"facility_slot_registry",
	"warehouse_runtime",
	"warehouse_card_catalog",
	"warehouse_ai_projection",
	"warehouse_player_projection",
	"solar_geometry",
	"planet_presentation",
	"map_target_selection",
	"unified_track_local_projection",
	"unified_track_shared_scroll_timing",
	"asset_pool_presentation",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _load_json(MANIFEST_PATH)
	_expect(not manifest.is_empty(), "manifest parses")
	_expect(
		_same_string_set(manifest.keys(), EXPECTED_TOP_LEVEL_FIELDS),
		"top-level field set is frozen"
	)
	_expect(
		str(manifest.get("schema", "")) == "V074AtomicCutoverManifestV1",
		"manifest schema is V074"
	)
	_expect(
		str(manifest.get("task_id", "")) == (
			"ALPHA_0_5_C1_V074_ROGUELIKE_GEOGRAPHY_WAREHOUSE_"
			+ "COMPLETE_FACILITY_CUTOVER_INTERACTIVE_GLOBE_RESPONSIVE_UI_"
			+ "AND_LEGACY_MAIN_RETIREMENT"
		),
		"task identity is frozen"
	)
	_expect(
		str(manifest.get("base_main_sha", "")) == (
			"05c2415014187e902592bf3a8d1291222f738694"
		),
		"base main SHA is frozen"
	)
	_expect(
		str(manifest.get("constitution_id", "")) == (
			"space_syndicate.v074.complete"
		),
		"constitution identity is V074 complete"
	)
	_expect(
		str(manifest.get("ruleset_id", "")) == "v0.7.4",
		"manifest ruleset is V074"
	)
	_expect(
		str(manifest.get("current_production_runtime_ruleset", "")) == (
			"v0.7.4"
		),
		"production runtime ruleset is V074"
	)
	_expect(
		str(manifest.get("production_main_scene", "")) == MAIN_SCENE_PATH,
		"production main scene is connected"
	)
	_expect(
		str(manifest.get("production_bootstrap", "")) == (
			"V074ApplicationBootstrap"
		),
		"V074 bootstrap owns composition"
	)
	_expect(bool(manifest.get("new_game_only", false)), "sample is new-game only")
	_expect(
		not bool(manifest.get("save_resume_enabled", true)),
		"save/resume remains disabled"
	)
	var domains := manifest.get("domains", []) as Array
	_expect(domains.size() == 15, "manifest has 15 cutover domains")
	_expect(
		int(manifest.get("domain_count", 0)) == 15,
		"domain count matches"
	)
	_expect(
		int(manifest.get("connected_domain_count", 0)) == 15,
		"connected domain count matches"
	)
	_expect(
		int(manifest.get("legacy_disconnected_domain_count", 0)) == 15,
		"legacy-disconnected count matches"
	)
	var seen_domains: Array[String] = []
	var connected_count := 0
	var legacy_disconnected_count := 0
	for index in range(domains.size()):
		var domain := domains[index] as Dictionary
		var domain_id := str(domain.get("domain", ""))
		seen_domains.append(domain_id)
		_expect(
			_same_string_set(domain.keys(), EXPECTED_DOMAIN_FIELDS),
			"%s field set is exact" % domain_id
		)
		_expect(
			index < EXPECTED_DOMAIN_ORDER.size()
			and domain_id == EXPECTED_DOMAIN_ORDER[index],
			"%s retains ordered identity" % domain_id
		)
		_expect(
			EXPECTED_DOMAIN_OWNERS.has(domain_id)
			and str(domain.get("target_owner", "")) == str(
				EXPECTED_DOMAIN_OWNERS.get(domain_id, "")
			),
			"%s target owner is exact" % domain_id
		)
		_expect(
			str(domain.get("status", "")) == "connected",
			"%s is connected" % domain_id
		)
		_expect(bool(domain.get("connected", false)), "%s connected flag" % domain_id)
		_expect(
			bool(domain.get("legacy_disconnected", false)),
			"%s legacy path is disconnected" % domain_id
		)
		_expect(
			not str(domain.get("save_owner_declared", "")).is_empty(),
			"%s declares Save ownership" % domain_id
		)
		_expect(
			not str(domain.get("rng_owner_declared", "")).is_empty(),
			"%s declares RNG ownership" % domain_id
		)
		_expect(
			not str(domain.get("rollback_boundary_declared", "")).is_empty(),
			"%s declares rollback boundary" % domain_id
		)
		if bool(domain.get("connected", false)):
			connected_count += 1
		if bool(domain.get("legacy_disconnected", false)):
			legacy_disconnected_count += 1
	_expect(
		_same_string_set(seen_domains, EXPECTED_DOMAIN_ORDER),
		"all domain identities are unique and complete"
	)
	var final_counts := manifest.get("required_final_counts", {}) as Dictionary
	var expected_final_counts := {
		"connected_domain_count": 15,
		"map_dual_write_count": 0,
		"warehouse_dual_write_count": 0,
		"fixed_six_region_fallback_count": 0,
		"factory_market_only_fallback_count": 0,
		"mixed_map_ruleset_count": 0,
	}
	_expect(
		_same_string_set(final_counts.keys(), expected_final_counts.keys()),
		"required final count field set is exact"
	)
	for key_variant in expected_final_counts.keys():
		var key := str(key_variant)
		_expect(
			int(final_counts.get(key, -1)) == int(expected_final_counts.get(key, -2)),
			"%s final count is exact" % key
		)
	var main_text := _read_text(MAIN_SCENE_PATH)
	_expect(
		FileAccess.file_exists(V074_BOOTSTRAP_PATH),
		"frozen V074 bootstrap remains available"
	)
	_expect(
		FileAccess.file_exists(V074_COMPOSITION_PATH),
		"frozen V074 composition remains available"
	)
	_expect(
		FileAccess.file_exists(V074_SCREEN_PATH),
		"frozen V074 screen remains available"
	)
	_expect(not main_text.contains("scripts/main.gd"), "main has no legacy script path")
	_expect(not FileAccess.file_exists(LEGACY_MAIN_PATH), "legacy scripts/main.gd is absent")
	_finish(
		domains.size(),
		connected_count,
		legacy_disconnected_count,
		final_counts
	)


func _load_json(path: String) -> Dictionary:
	var text := _read_text(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _same_string_set(left: Array, right: Array) -> bool:
	var normalized_left: Array[String] = []
	var normalized_right: Array[String] = []
	for value in left:
		normalized_left.append(str(value))
	for value in right:
		normalized_right.append(str(value))
	normalized_left.sort()
	normalized_right.sort()
	return normalized_left == normalized_right


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish(
	domains: int,
	connected: int,
	legacy_disconnected: int,
	final_counts: Dictionary
) -> void:
	print(
		(
			"V074_ATOMIC_CUTOVER_MANIFEST|status=%s|checks=%d"
			+ "|failures=%d|domains=%d|connected=%d"
			+ "|legacy_disconnected=%d|map_dual_write=%d"
			+ "|warehouse_dual_write=%d|fixed_six=%d"
			+ "|factory_market_only=%d|mixed_ruleset=%d|details=%s"
		)
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
			domains,
			connected,
			legacy_disconnected,
			int(final_counts.get("map_dual_write_count", -1)),
			int(final_counts.get("warehouse_dual_write_count", -1)),
			int(final_counts.get("fixed_six_region_fallback_count", -1)),
			int(final_counts.get("factory_market_only_fallback_count", -1)),
			int(final_counts.get("mixed_map_ruleset_count", -1)),
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
