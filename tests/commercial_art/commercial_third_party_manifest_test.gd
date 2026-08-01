extends SceneTree

const MANIFEST_PATH := "res://docs/third_party/selected_commercial_asset_manifest.json"
const NOTICES_PATH := "res://THIRD_PARTY_NOTICES.md"
const CREDITS_PATH := "res://docs/third_party/credits_data.json"
const SOURCE_VERIFICATION_PATH := "res://reports/asset_intake/selected_source_verification_agent1.json"
const BASE_SHA := "2e38764791cb37cdc45b2eb0836957f550822dd5"
const MAX_FILE_BYTES := 25 * 1024 * 1024
const MAX_REPOSITORY_GROWTH_BYTES := 250 * 1024 * 1024

const EXPECTED_ASSETS := {
	"kenney.ui.scifi": {"source_url": "https://kenney.nl/assets/ui-pack-sci-fi", "license": "CC0-1.0"},
	"kenney.board_game_icons": {"source_url": "https://kenney.nl/assets/board-game-icons", "license": "CC0-1.0"},
	"kenney.input_prompts": {"source_url": "https://kenney.nl/assets/input-prompts", "license": "CC0-1.0"},
	"kenney.pattern_pack": {"source_url": "https://kenney.nl/assets/pattern-pack", "license": "CC0-1.0"},
	"kenney.particle_pack": {"source_url": "https://kenney.nl/assets/particle-pack", "license": "CC0-1.0"},
	"kenney.smoke_particles": {"source_url": "https://kenney.nl/assets/smoke-particles", "license": "CC0-1.0"},
	"icon.asset.life": {"source_url": "https://game-icons.net/1x1/lorc/leaf-swirl.html", "license": "CC-BY-3.0"},
	"icon.asset.energy": {"source_url": "https://game-icons.net/1x1/lorc/lightning-electron.html", "license": "CC-BY-3.0"},
	"icon.asset.industry": {"source_url": "https://game-icons.net/1x1/lorc/cog.html", "license": "CC-BY-3.0"},
	"icon.asset.technology": {"source_url": "https://game-icons.net/1x1/lorc/circuitry.html", "license": "CC-BY-3.0"},
	"icon.asset.commerce": {"source_url": "https://game-icons.net/1x1/delapouite/receive-money.html", "license": "CC-BY-3.0"},
	"icon.asset.shipping": {"source_url": "https://game-icons.net/1x1/delapouite/spaceship.html", "license": "CC-BY-3.0"},
	"quaternius.modular_scifi_megakit": {"source_url": "https://quaternius.com/packs/modularscifimegakit.html", "license": "CC0-1.0"},
	"quaternius.scifi_essentials": {"source_url": "https://quaternius.com/packs/scifiessentialskit.html", "license": "CC0-1.0"},
	"quaternius.ultimate_monsters": {"source_url": "https://quaternius.com/packs/ultimatemonsters.html", "license": "CC0-1.0"},
	"quaternius.animated_mech": {"source_url": "https://quaternius.com/packs/animatedmech.html", "license": "CC0-1.0"},
	"quaternius.ultimate_spaceships": {"source_url": "https://quaternius.com/packs/ultimatespaceships.html", "license": "CC0-1.0"},
	"naejimer.godot_3d_planet_generator": {"source_url": "https://godotengine.org/asset-library/asset/1615", "license": "MIT"},
	"ambientcg.metal_plates_013": {"source_url": "https://ambientcg.com/view?id=MetalPlates013", "license": "CC0-1.0"},
	"ambientcg.painted_metal_007": {"source_url": "https://ambientcg.com/view?id=PaintedMetal007", "license": "CC0-1.0"},
	"ambientcg.sheet_metal_003": {"source_url": "https://ambientcg.com/view?id=SheetMetal003", "license": "CC0-1.0"},
	"ambientcg.night_sky_hdri_001": {"source_url": "https://ambientcg.com/a/NightSkyHDRI001", "license": "CC0-1.0"},
	"kenney.interface_sounds": {"source_url": "https://kenney.nl/assets/interface-sounds", "license": "CC0-1.0"},
	"kenney.scifi_sounds": {"source_url": "https://kenney.nl/assets/sci-fi-sounds", "license": "CC0-1.0"},
	"music.menu.pondering_the_cosmos": {"source_url": "https://opengameart.org/content/pondering-the-cosmos", "license": "CC0-1.0"},
	"music.gameplay.robotic_city": {"source_url": "https://lpc.opengameart.org/content/robotic-city", "license": "CC0-1.0"},
	"music.crisis.space_graveyard": {"source_url": "https://opengameart.org/content/space-graveyard-ambient-track", "license": "CC0-1.0"},
	"music.military.interstellar_fleet_1": {"source_url": "https://opengameart.org/content/interstellar-fleet-1", "license": "CC0-1.0"},
	"font.noto_sans_cjk": {"source_url": "https://github.com/notofonts/noto-cjk", "license": "OFL-1.1"},
	"font.oxanium": {"source_url": "https://github.com/sevmeyer/oxanium", "license": "OFL-1.1"},
}

const EXPECTED_LICENSE_COUNTS := {
	"CC0-1.0": 21,
	"CC-BY-3.0": 6,
	"MIT": 1,
	"OFL-1.1": 2,
}

const GAME_ICON_IDS := [
	"icon.asset.life",
	"icon.asset.energy",
	"icon.asset.industry",
	"icon.asset.technology",
	"icon.asset.commerce",
	"icon.asset.shipping",
]

const REQUIRED_CREDIT_SECTIONS := [
	"third_party_assets",
	"licenses",
	"music",
	"fonts",
]

const REQUIRED_LICENSE_EVIDENCE := {
	"kenney.ui.scifi": ["res://assets/third_party/commercial/ui/kenney_ui_scifi/LICENSE-CC0.txt"],
	"kenney.board_game_icons": ["res://assets/third_party/commercial/ui/kenney_board_game_icons/LICENSE-CC0.txt"],
	"kenney.input_prompts": ["res://assets/third_party/commercial/ui/kenney_input_prompts/LICENSE-CC0.txt"],
	"kenney.pattern_pack": ["res://assets/third_party/commercial/ui/kenney_pattern_pack/LICENSE-CC0.txt"],
	"kenney.particle_pack": ["res://assets/third_party/commercial/vfx/kenney_particle_pack/LICENSE.txt"],
	"kenney.smoke_particles": ["res://assets/third_party/commercial/vfx/kenney_smoke_particles/LICENSE.txt"],
	"icon.asset.life": ["res://assets/third_party/commercial/icons/game_icons/LICENSE-CC-BY-3.0.txt"],
	"icon.asset.energy": ["res://assets/third_party/commercial/icons/game_icons/LICENSE-CC-BY-3.0.txt"],
	"icon.asset.industry": ["res://assets/third_party/commercial/icons/game_icons/LICENSE-CC-BY-3.0.txt"],
	"icon.asset.technology": ["res://assets/third_party/commercial/icons/game_icons/LICENSE-CC-BY-3.0.txt"],
	"icon.asset.commerce": ["res://assets/third_party/commercial/icons/game_icons/LICENSE-CC-BY-3.0.txt"],
	"icon.asset.shipping": ["res://assets/third_party/commercial/icons/game_icons/LICENSE-CC-BY-3.0.txt"],
	"quaternius.modular_scifi_megakit": ["res://assets/third_party/commercial/models/quaternius/modular_scifi_megakit/LICENSE_CC0.txt"],
	"quaternius.scifi_essentials": ["res://assets/third_party/commercial/models/quaternius/scifi_essentials/LICENSE_CC0.txt"],
	"quaternius.ultimate_monsters": ["res://assets/third_party/commercial/models/quaternius/ultimate_monsters/LICENSE_CC0.txt"],
	"quaternius.animated_mech": ["res://assets/third_party/commercial/models/quaternius/animated_mech/LICENSE_CC0.txt"],
	"quaternius.ultimate_spaceships": ["res://assets/third_party/commercial/models/quaternius/ultimate_spaceships/LICENSE_CC0.txt"],
	"naejimer.godot_3d_planet_generator": ["res://assets/third_party/commercial/planet/naejimer_planet_generator/LICENSE"],
	"ambientcg.metal_plates_013": ["res://assets/third_party/commercial/materials/ambientcg/LICENSE.md"],
	"ambientcg.painted_metal_007": ["res://assets/third_party/commercial/materials/ambientcg/LICENSE.md"],
	"ambientcg.sheet_metal_003": ["res://assets/third_party/commercial/materials/ambientcg/LICENSE.md"],
	"ambientcg.night_sky_hdri_001": ["res://assets/third_party/commercial/materials/ambientcg/LICENSE.md"],
	"kenney.interface_sounds": ["res://assets/third_party/commercial/audio/kenney_interface_sounds/LICENSE.txt"],
	"kenney.scifi_sounds": ["res://assets/third_party/commercial/audio/kenney_scifi_sounds/LICENSE.txt"],
	"music.menu.pondering_the_cosmos": [NOTICES_PATH],
	"music.gameplay.robotic_city": [NOTICES_PATH],
	"music.crisis.space_graveyard": [NOTICES_PATH],
	"music.military.interstellar_fleet_1": [NOTICES_PATH],
	"font.noto_sans_cjk": ["res://assets/third_party/commercial/fonts/noto_sans_cjk/OFL-1.1.txt"],
	"font.oxanium": ["res://assets/third_party/commercial/fonts/oxanium/OFL-1.1.txt"],
}

const NETWORK_SCAN_ROOTS := [
	"res://assets/third_party/commercial",
	"res://resources/audio",
	"res://resources/presentation",
	"res://scenes/tools/commercial_art",
	"res://scripts/presentation",
	"res://scripts/ui",
]

const NETWORK_REFERENCE_PATTERNS := [
	"load(\"http://",
	"load(\"https://",
	"preload(\"http://",
	"preload(\"https://",
	"path=\"http://",
	"path=\"https://",
	"path = \"http://",
	"path = \"https://",
]

var _checks := 0
var _failures: Array[String] = []
var _processed_path_count := 0
var _runtime_network_reference_count := 0
var _unlisted_asset_count := 0
var _repository_growth_bytes := -1
var _repository_current_bytes := -1
var _repository_baseline_bytes := -1
var _largest_repository_file_bytes := -1
var _largest_repository_file_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var required_files := [MANIFEST_PATH, NOTICES_PATH, CREDITS_PATH, SOURCE_VERIFICATION_PATH]
	var missing: Array[String] = []
	for path in required_files:
		if not FileAccess.file_exists(path):
			missing.append(path)
	if not missing.is_empty():
		print("COMMERCIAL_THIRD_PARTY_MANIFEST|status=WAITING_FINAL_MANIFEST|missing=%s" % ",".join(missing))
		quit(2)
		return

	var manifest := _load_json(MANIFEST_PATH)
	var source_verification := _load_json(SOURCE_VERIFICATION_PATH)
	var credits := _load_json(CREDITS_PATH)
	var notices := FileAccess.get_file_as_string(NOTICES_PATH)
	_expect(not manifest.is_empty(), "final selected-asset manifest parses as a dictionary")
	_expect(not source_verification.is_empty(), "selected-source verification parses as a dictionary")
	_expect(not credits.is_empty(), "credits data parses as a dictionary")
	_expect(not notices.strip_edges().is_empty(), "third-party notices are nonempty")
	if manifest.is_empty() or source_verification.is_empty() or credits.is_empty() or notices.strip_edges().is_empty():
		_finish()
		return

	var source_rows := _rows_by_id(source_verification.get("assets", []), "source verification")
	var manifest_rows := _rows_by_id(manifest.get("assets", []), "final manifest")
	_test_source_verification(source_verification, source_rows)
	_test_manifest(manifest, manifest_rows)
	_test_notices(notices, manifest_rows)
	_test_credits(credits)
	_test_license_evidence(source_rows, manifest_rows)
	_test_runtime_network_boundary(manifest, manifest_rows)
	_test_repository_budget()
	_finish()


func _test_source_verification(report: Dictionary, rows: Dictionary) -> void:
	_expect(rows.size() == EXPECTED_ASSETS.size(), "source verification contains exactly 30 asset IDs")
	var scope := _dictionary(report.get("scope"))
	_expect(int(scope.get("selected_source_count", -1)) == 30, "source verification declares exactly 30 selected sources")
	_expect(int(scope.get("web_asset_search_count", -1)) == 0, "source verification used no web asset search")
	_expect(int(scope.get("alternative_source_search_count", -1)) == 0, "source verification used no alternative-source search")
	_expect(int(scope.get("unlisted_asset_source_count", -1)) == 0, "source verification used zero unlisted sources")
	_expect(int(scope.get("primary_source_http_200_count", -1)) == 30, "all 30 selected primary pages returned HTTP 200")
	_expect(int(scope.get("license_match_count", -1)) == 30, "all 30 selected licenses match")
	var counts := _license_counts(rows, "observed_license")
	_expect(counts == EXPECTED_LICENSE_COUNTS, "source verification license classification is exactly 21/6/1/2")
	for asset_id in EXPECTED_ASSETS:
		var expected := _dictionary(EXPECTED_ASSETS[asset_id])
		var row := _dictionary(rows.get(asset_id))
		_expect(not row.is_empty(), "source verification contains %s" % asset_id)
		if row.is_empty():
			continue
		_expect(str(row.get("source_url", "")) == str(expected.get("source_url", "")), "%s source URL is exact in source verification" % asset_id)
		_expect(str(row.get("observed_license", "")) == str(expected.get("license", "")), "%s license is exact in source verification" % asset_id)
		_expect(bool(row.get("source_reachable", false)) and int(row.get("source_http_status", 0)) == 200, "%s source page is attested reachable" % asset_id)
		_expect(bool(row.get("license_matches_prompt", false)), "%s source license is attested matching" % asset_id)
		_expect(_is_sha256(str(row.get("original_sha256", ""))), "%s source original SHA-256 is present" % asset_id)
		_expect(not str(row.get("license_evidence", "")).strip_edges().is_empty(), "%s source license evidence description is present" % asset_id)


func _test_manifest(manifest: Dictionary, rows: Dictionary) -> void:
	_expect(rows.size() == EXPECTED_ASSETS.size(), "final manifest contains exactly 30 unique asset IDs")
	var license_counts := _license_counts(rows, "license")
	_expect(license_counts == EXPECTED_LICENSE_COUNTS, "final manifest license classification is exactly 21/6/1/2")
	_unlisted_asset_count = 0
	for asset_id in rows:
		if not EXPECTED_ASSETS.has(asset_id):
			_unlisted_asset_count += 1
	_expect(_unlisted_asset_count == 0, "final manifest contains zero unlisted asset IDs")
	for asset_id in EXPECTED_ASSETS:
		var expected := _dictionary(EXPECTED_ASSETS[asset_id])
		var row := _dictionary(rows.get(asset_id))
		_expect(not row.is_empty(), "final manifest contains %s" % asset_id)
		if row.is_empty():
			continue
		_expect(str(row.get("source_url", "")) == str(expected.get("source_url", "")), "%s final source URL is exact" % asset_id)
		_expect(str(row.get("license", "")) == str(expected.get("license", "")), "%s final license is exact" % asset_id)
		_expect(bool(row.get("official_source", false)), "%s is marked as an official source" % asset_id)
		_expect(not str(row.get("author", "")).strip_edges().is_empty(), "%s author is present" % asset_id)
		_expect(not str(row.get("license_url", "")).strip_edges().is_empty(), "%s license URL is present" % asset_id)
		_expect(not str(row.get("downloaded_at", row.get("downloaded_at_utc", ""))).strip_edges().is_empty(), "%s download time is present" % asset_id)
		_expect(not str(row.get("original_filename", "")).strip_edges().is_empty(), "%s original filename is present" % asset_id)
		_expect(_is_sha256(str(row.get("original_sha256", ""))), "%s original SHA-256 is present" % asset_id)
		_expect(row.has("modifications"), "%s modifications field is present" % asset_id)
		_expect(row.has("attribution_required"), "%s attribution-required field is present" % asset_id)
		_expect(row.has("attribution_text"), "%s attribution text field is present" % asset_id)
		if asset_id in GAME_ICON_IDS:
			_expect(bool(row.get("attribution_required", false)), "%s requires attribution" % asset_id)
		_test_processed_files(asset_id, row)
	_expect(_metric_int(manifest, "unlisted_asset_source_count", _unlisted_asset_count) == 0, "manifest reports zero unlisted sources")


func _test_processed_files(asset_id: String, row: Dictionary) -> void:
	var paths := _string_array(row.get("processed_paths"))
	_expect(not paths.is_empty(), "%s has at least one processed path" % asset_id)
	var hashes := _processed_hashes(row.get("processed_sha256"), paths)
	_expect(hashes.size() == paths.size(), "%s has one processed hash per path" % asset_id)
	var seen: Dictionary = {}
	for path in paths:
		_processed_path_count += 1
		_expect(not seen.has(path), "%s processed paths are unique within the asset row: %s" % [asset_id, path])
		seen[path] = true
		_expect(path.begins_with("res://") and not path.contains("http://") and not path.contains("https://"), "%s processed path is local: %s" % [asset_id, path])
		_expect(FileAccess.file_exists(path), "%s processed file exists: %s" % [asset_id, path])
		var expected_hash := str(hashes.get(path, ""))
		_expect(_is_sha256(expected_hash), "%s processed SHA-256 is valid for %s" % [asset_id, path])
		if FileAccess.file_exists(path) and _is_sha256(expected_hash):
			_expect(FileAccess.get_sha256(path) == expected_hash, "%s processed SHA-256 matches bytes for %s" % [asset_id, path])


func _test_notices(notices: String, manifest_rows: Dictionary) -> void:
	var normalized := _normalized_text(notices)
	var required_phrases := [
		"leaf swirl",
		"lightning electron",
		"cog",
		"circuitry",
		"receive money",
		"spaceship",
		"by lorc",
		"by delapouite",
		"game-icons.net",
		"cc by 3.0",
		"icons were resized, normalized and recolored for space syndicate",
	]
	for phrase in required_phrases:
		_expect(normalized.contains(phrase), "notices contain mandatory Game-icons phrase: %s" % phrase)
	for phrase in ["kenney", "quaternius", "ambientcg", "naejimer", "ruskerdax", "section31", "tinyworlds", "zane little music"]:
		_expect(normalized.contains(phrase), "notices contain required acknowledgement: %s" % phrase)
	for phrase in ["cc0", "cc by 3.0", "mit license", "open font license"]:
		_expect(normalized.contains(phrase), "notices contain license class: %s" % phrase)
	var manifest_attribution := ""
	for asset_id in GAME_ICON_IDS:
		manifest_attribution += " " + str(_dictionary(manifest_rows.get(asset_id)).get("attribution_text", ""))
	var normalized_manifest_attribution := _normalized_text(manifest_attribution)
	for phrase in required_phrases:
		_expect(normalized_manifest_attribution.contains(phrase), "manifest Game-icons attribution contains: %s" % phrase)


func _test_credits(credits: Dictionary) -> void:
	var sections := _dictionary(credits.get("sections"))
	_expect(sections.size() == REQUIRED_CREDIT_SECTIONS.size(), "credits contain exactly four required sections")
	for section_id in REQUIRED_CREDIT_SECTIONS:
		_expect(sections.has(section_id), "credits contain %s section" % section_id)
		_expect(sections.get(section_id) is Array and not (sections.get(section_id) as Array).is_empty(), "credits %s section is nonempty" % section_id)
	var normalized := _normalized_text(JSON.stringify(credits))
	for phrase in ["leaf swirl", "lightning electron", "cog", "circuitry", "receive money", "spaceship", "lorc", "delapouite", "game-icons.net", "cc by 3.0"]:
		_expect(normalized.contains(phrase), "credits contain mandatory Game-icons attribution token: %s" % phrase)
	for phrase in ["pondering the cosmos", "robotic city", "space graveyard", "interstellar fleet 1", "ruskerdax", "section31", "tinyworlds", "zane little music"]:
		_expect(normalized.contains(phrase), "credits contain selected music token: %s" % phrase)
	for phrase in ["noto sans cjk", "oxanium", "ofl-1.1"]:
		_expect(normalized.contains(phrase), "credits contain selected font token: %s" % phrase)
	var game_icons_attribution := _normalized_text(str(credits.get("game_icons_attribution", "")))
	_expect(game_icons_attribution.contains("game-icons.net") and game_icons_attribution.contains("cc by 3.0"), "credits expose dedicated Game-icons attribution text")


func _test_license_evidence(source_rows: Dictionary, manifest_rows: Dictionary) -> void:
	_expect(REQUIRED_LICENSE_EVIDENCE.size() == EXPECTED_ASSETS.size(), "all 30 assets have a local license-evidence mapping")
	var unique_paths: Dictionary = {}
	for asset_id in EXPECTED_ASSETS:
		var paths := _string_array(REQUIRED_LICENSE_EVIDENCE.get(asset_id))
		_expect(not paths.is_empty(), "%s has mapped license evidence" % asset_id)
		for path in paths:
			unique_paths[path] = true
			_expect(FileAccess.file_exists(path), "%s license evidence exists: %s" % [asset_id, path])
			if FileAccess.file_exists(path):
				_expect(not FileAccess.get_file_as_string(path).strip_edges().is_empty(), "%s license evidence is nonempty: %s" % [asset_id, path])
		var source_row := _dictionary(source_rows.get(asset_id))
		var manifest_row := _dictionary(manifest_rows.get(asset_id))
		_expect(not str(source_row.get("license_evidence", "")).strip_edges().is_empty(), "%s source evidence description is retained" % asset_id)
		_expect(not str(manifest_row.get("license_url", "")).strip_edges().is_empty(), "%s final manifest retains a license URL" % asset_id)
	_expect(unique_paths.size() >= 18, "license evidence includes all provider/package-specific files")


func _test_runtime_network_boundary(manifest: Dictionary, manifest_rows: Dictionary) -> void:
	_expect(_metric_int(manifest, "runtime_network_asset_dependency_count", -1) == 0, "manifest declares zero runtime network asset dependencies")
	var remote_processed_paths := 0
	for asset_id in manifest_rows:
		for path in _string_array(_dictionary(manifest_rows[asset_id]).get("processed_paths")):
			if not path.begins_with("res://") or path.contains("http://") or path.contains("https://"):
				remote_processed_paths += 1
	_expect(remote_processed_paths == 0, "all processed asset paths are local res:// paths")
	_runtime_network_reference_count = 0
	for root_path in NETWORK_SCAN_ROOTS:
		for path in _files_under(root_path):
			if not _is_network_scannable(path):
				continue
			var source := FileAccess.get_file_as_string(path).to_lower()
			for pattern in NETWORK_REFERENCE_PATTERNS:
				_runtime_network_reference_count += source.count(pattern)
	_expect(_runtime_network_reference_count == 0, "runtime presentation resources contain no HTTP load/preload/path references")


func _test_repository_budget() -> void:
	var baseline_output: Array = []
	var baseline_exit := OS.execute("git", PackedStringArray(["ls-tree", "-r", "-l", BASE_SHA]), baseline_output, true)
	_expect(baseline_exit == 0, "repository-growth baseline SHA is available")
	_repository_baseline_bytes = _sum_ls_tree_bytes("\n".join(baseline_output)) if baseline_exit == 0 else -1
	_expect(_repository_baseline_bytes >= 0, "baseline repository byte total is measurable")
	var current_output: Array = []
	var current_exit := OS.execute("git", PackedStringArray(["-c", "core.quotepath=false", "ls-files", "--cached", "--others", "--exclude-standard"]), current_output, true)
	_expect(current_exit == 0, "current repository file list is available")
	_repository_current_bytes = 0
	_largest_repository_file_bytes = -1
	_largest_repository_file_path = ""
	var seen: Dictionary = {}
	if current_exit == 0:
		for line in "\n".join(current_output).split("\n", false):
			var git_path := line.strip_edges()
			if git_path.is_empty() or seen.has(git_path):
				continue
			seen[git_path] = true
			var file := FileAccess.open("res://%s" % git_path, FileAccess.READ)
			if file == null:
				continue
			var size := file.get_length()
			file.close()
			_repository_current_bytes += size
			if size > _largest_repository_file_bytes:
				_largest_repository_file_bytes = size
				_largest_repository_file_path = git_path
	_expect(_repository_current_bytes >= 0, "current repository byte total is measurable")
	_expect(_largest_repository_file_bytes < MAX_FILE_BYTES, "largest repository file is below 25 MiB: %s (%d bytes)" % [_largest_repository_file_path, _largest_repository_file_bytes])
	if _repository_baseline_bytes >= 0 and _repository_current_bytes >= 0:
		_repository_growth_bytes = _repository_current_bytes - _repository_baseline_bytes
	_expect(_repository_growth_bytes < MAX_REPOSITORY_GROWTH_BYTES, "repository growth is below 250 MiB: %d bytes" % _repository_growth_bytes)


func _rows_by_id(value: Variant, label: String) -> Dictionary:
	var result: Dictionary = {}
	_expect(value is Array, "%s assets field is an array" % label)
	if not (value is Array):
		return result
	for row_variant in value as Array:
		_expect(row_variant is Dictionary, "%s row is a dictionary" % label)
		if not (row_variant is Dictionary):
			continue
		var row := (row_variant as Dictionary).duplicate(true)
		var asset_id := str(row.get("asset_id", ""))
		_expect(not asset_id.is_empty(), "%s asset ID is nonempty" % label)
		_expect(not result.has(asset_id), "%s asset ID is unique: %s" % [label, asset_id])
		if not asset_id.is_empty() and not result.has(asset_id):
			result[asset_id] = row
	return result


func _license_counts(rows: Dictionary, field: String) -> Dictionary:
	var counts := {"CC0-1.0": 0, "CC-BY-3.0": 0, "MIT": 0, "OFL-1.1": 0}
	for row_variant in rows.values():
		var license := str(_dictionary(row_variant).get(field, ""))
		if counts.has(license):
			counts[license] = int(counts[license]) + 1
	return counts


func _processed_hashes(value: Variant, paths: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for path in paths:
			result[path] = str((value as Dictionary).get(path, ""))
	elif value is Array:
		var values := value as Array
		if values.size() == paths.size() and (values.is_empty() or values[0] is String):
			for index in range(paths.size()):
				result[paths[index]] = str(values[index])
		else:
			for row_variant in values:
				if row_variant is Dictionary:
					var row := row_variant as Dictionary
					var path := str(row.get("path", row.get("processed_path", "")))
					if not path.is_empty():
						result[path] = str(row.get("sha256", row.get("processed_sha256", "")))
	elif value is String and paths.size() == 1:
		result[paths[0]] = str(value)
	return result


func _metric_int(root_value: Variant, key: String, fallback: int) -> int:
	if not (root_value is Dictionary):
		return fallback
	var root := root_value as Dictionary
	if root.has(key):
		return int(root.get(key, fallback))
	for container_key in ["summary", "invariants", "architecture_invariants", "boundaries", "metrics"]:
		var child: Variant = root.get(container_key)
		if child is Dictionary and (child as Dictionary).has(key):
			return int((child as Dictionary).get(key, fallback))
	return fallback


func _sum_ls_tree_bytes(output: String) -> int:
	var total := 0
	for line in output.split("\n", false):
		var tab_index := line.find("\t")
		if tab_index < 0:
			continue
		var header := line.substr(0, tab_index)
		var fields := header.split(" ", false)
		if fields.size() < 4:
			continue
		var size_text := fields[fields.size() - 1]
		if size_text.is_valid_int():
			total += int(size_text)
	return total


func _files_under(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var path := "%s/%s" % [root_path, name]
		if directory.current_is_dir():
			result.append_array(_files_under(path))
		else:
			result.append(path)
		name = directory.get_next()
	directory.list_dir_end()
	return result


func _is_network_scannable(path: String) -> bool:
	for extension in [".gd", ".tscn", ".tres", ".json", ".gltf", ".shader", ".gdshader"]:
		if path.ends_with(extension):
			return true
	return false


func _normalized_text(value: String) -> String:
	var normalized := value.to_lower()
	normalized = normalized.replace("“", "\"").replace("”", "\"")
	for separator in ["\r", "\n", "\t", "  "]:
		while normalized.contains(separator):
			normalized = normalized.replace(separator, " ")
	return normalized.strip_edges()


func _is_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	for index in range(value.length()):
		if "0123456789abcdef".find(value.substr(index, 1)) < 0:
			return false
	return true


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			if item is String and not str(item).is_empty():
				result.append(str(item))
	elif value is String and not str(value).is_empty():
		result.append(str(value))
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("COMMERCIAL_THIRD_PARTY_MANIFEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("COMMERCIAL_THIRD_PARTY_MANIFEST|status=%s|checks=%d|failures=%d|processed_paths=%d|unlisted_sources=%d|runtime_network_references=%d|repository_growth_bytes=%d|largest_file_bytes=%d|largest_file=%s" % [status, _checks, _failures.size(), _processed_path_count, _unlisted_asset_count, _runtime_network_reference_count, _repository_growth_bytes, _largest_repository_file_bytes, _largest_repository_file_path])
	if not _failures.is_empty():
		print("COMMERCIAL_THIRD_PARTY_MANIFEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
