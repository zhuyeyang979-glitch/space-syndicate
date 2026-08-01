extends SceneTree

const EVENT_MAP_PATH := "res://resources/audio/commercial/commercial_audio_event_map.json"
const MUSIC_MAP_PATH := "res://resources/audio/commercial/commercial_music_playlist.json"
const MAX_FILE_BYTES := 25 * 1024 * 1024

const EXPECTED_EVENTS := {
	"ui.hover": ["audio.ui.hover", "select_001.ogg", "aec0c31ea934a35936ae0d2ab8fac8123c93aa5647f935853a58dbaf90278b7a", "kenney.interface_sounds"],
	"ui.confirm": ["audio.ui.confirm", "confirmation_001.ogg", "063564703b6094d70718a3e787a55cc9141611e4ecd6b6637f8828f79b4a8c3a", "kenney.interface_sounds"],
	"ui.cancel": ["audio.ui.cancel", "back_001.ogg", "07db973f79f6ae0f2edc34561e7592e24d0577455919fb602cb8ecc0da991dcf", "kenney.interface_sounds"],
	"card.select": ["audio.card.select", "click_001.ogg", "ccfb7fa0cccdd9faec0eb16033c732b1e308d139d80f799161495d58f7adcdb9", "kenney.interface_sounds"],
	"card.drag_start": ["audio.card.drag_start", "scratch_003.ogg", "2d80371b55ebe2e8b916b84093a8ae7717d09a80c6b617079ade5bd0dacba7b7", "kenney.interface_sounds"],
	"card.drop": ["audio.card.drop", "drop_001.ogg", "692ee3a6f1821402ca649ff735bee9591dc4846c8098fc7d6a90fd15fa57c1af", "kenney.interface_sounds"],
	"card.lock": ["audio.card.lock", "toggle_004.ogg", "d7bf2236fc95a0fe1e3b278259392bcb062644e2d4ec5f9c96f7c09a9928262f", "kenney.interface_sounds"],
	"card.merge": ["audio.card.merge", "glass_003.ogg", "9a6f16e3c2eff6fe5d017a4755a28306b14555728831cd00d70308e8f9689566", "kenney.interface_sounds"],
	"asset.refresh": ["audio.asset.refresh", "maximize_007.ogg", "3400931f3f3a1e9cf253efef9069bcdf053edd2234e4ee9bf88977c389943484", "kenney.interface_sounds"],
	"commodity.claim": ["audio.commodity.claim", "laserSmall_000.ogg", "72b589eadd41781257ac859e4f4d030222e623390e4a1a83f6d05329a6e026f1", "kenney.scifi_sounds"],
	"normal_card.purchase": ["audio.normal_card.purchase", "laserSmall_001.ogg", "ab87913aba9790a0c5fa173d086267ba521ad522fcad2252271db49988313cf5", "kenney.scifi_sounds"],
	"facility.factory_build": ["audio.facility.factory_build", "impactMetal_004.ogg", "0032710d1fc88c217946cd54492f275eb4363bb8025a4bc1b7ce08df7b3c60de", "kenney.scifi_sounds"],
	"facility.market_build": ["audio.facility.market_build", "doorOpen_001.ogg", "8c204ca94eb722d3af95f29221f4551938ca3c217fda32c14dabe2cf6a9c782b", "kenney.scifi_sounds"],
	"facility.warehouse_build": ["audio.facility.warehouse_build", "doorClose_001.ogg", "2153e83ff9880c78f9539aa5dcce80fc9e3b39c6fa0f8dec9325ec6d7ea2c9d5", "kenney.scifi_sounds"],
	"monster.attack": ["audio.monster.attack", "explosionCrunch_000.ogg", "4b597d658d0ae101f0a030fbeea5fc3a4292ab85f017470a8254a8e7959cbd69", "kenney.scifi_sounds"],
	"military.action": ["audio.military.action", "laserLarge_000.ogg", "a56d95794cd732d6c2d66ce488c14cf557fe526c282897c9a77675c2bd9b77e6", "kenney.scifi_sounds"],
	"settlement.complete": ["audio.settlement.complete", "forceField_001.ogg", "5574e69dd04e5f59322c5ddffde5978f077b09170ae5e29cec0bd9901828cd90", "kenney.scifi_sounds"],
}

const EXPECTED_MUSIC := {
	"music.menu": ["menu", "Pondering the Cosmos", "Ruskerdax", "https://opengameart.org/content/pondering-the-cosmos", "1fda7ea15579e60d8e6c02dc068c73819d72467027454229bc16d4d3dd56748e", 307.722438],
	"music.gameplay": ["gameplay", "Robotic City", "section31", "https://lpc.opengameart.org/content/robotic-city", "3d2ae95b9c59ae0716654fe4880b9986e5ac3df8e2e4d71aa70f107abbec3f87", 192.0],
	"music.crisis": ["crisis", "Space Graveyard", "TinyWorlds", "https://opengameart.org/content/space-graveyard-ambient-track", "52e2d54cc8ec6d627f7abe779a56926a8ca3c4a274e87b589d87ba5ae79941b0", 312.763979],
	"music.military": ["military", "Interstellar Fleet 1", "Zane Little Music", "https://opengameart.org/content/interstellar-fleet-1", "f8be29e21b4c15fca84160410c12deb8ed03fddc1aa706f2af6b60eabab3bd6d", 88.615396],
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var events := _parse_json(EVENT_MAP_PATH)
	var music := _parse_json(MUSIC_MAP_PATH)
	_test_source_contracts(events)
	_test_event_assets(events)
	_test_music_assets(music)
	_test_presentation_boundaries(events, music)
	_finish()


func _test_source_contracts(contract: Dictionary) -> void:
	_expect(str(contract.get("contract_id", "")) == "space_syndicate.commercial_audio.events.v1", "event contract id")
	var sources: Dictionary = contract.get("source_packages", {})
	_expect(sources.size() == 2, "exactly two selected Kenney source packages")
	var expected := {
		"kenney.interface_sounds": ["https://kenney.nl/assets/interface-sounds", "f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232"],
		"kenney.scifi_sounds": ["https://kenney.nl/assets/sci-fi-sounds", "119340f351a5098ad814f78719438c0da355a9ce8a4c8a3af6a8d48aa3d49e04"],
	}
	for source_id in expected:
		var row: Dictionary = sources.get(source_id, {})
		var pinned: Array = expected[source_id]
		_expect(str(row.get("source_url", "")) == str(pinned[0]), "%s exact source URL" % source_id)
		_expect(str(row.get("author", "")) == "Kenney", "%s author" % source_id)
		_expect(str(row.get("license", "")) == "CC0-1.0", "%s CC0 license" % source_id)
		_expect(str(row.get("original_sha256", "")) == str(pinned[1]), "%s package SHA" % source_id)
		var license_path := str(row.get("license_evidence_path", ""))
		var license_text := FileAccess.get_file_as_string(license_path)
		_expect(license_text.contains("Creative Commons Zero, CC0"), "%s retained package license" % source_id)


func _test_event_assets(contract: Dictionary) -> void:
	_expect(int(contract.get("schema_version", 0)) == 1, "event schema version")
	_expect(bool(contract.get("presentation_only", false)), "events are presentation-only")
	_expect(str(contract.get("selection_policy", "")) == "fixed_single_file", "fixed single-file selection")
	_expect(not bool(contract.get("randomize", true)), "event selection is not randomized")
	_expect(int(contract.get("rules_rng_draw_count", -1)) == 0, "event selection consumes no rules RNG")
	var rows: Array = contract.get("events", [])
	_expect(rows.size() == EXPECTED_EVENTS.size(), "exact 17-event coverage")
	var by_id := _index_by(rows, "event_id")
	_expect(by_id.size() == EXPECTED_EVENTS.size(), "event IDs are unique")
	var stream_paths: Dictionary = {}
	for event_id in EXPECTED_EVENTS:
		var row: Dictionary = by_id.get(event_id, {})
		var expected: Array = EXPECTED_EVENTS[event_id]
		var path := str(row.get("stream_path", ""))
		_expect(str(row.get("asset_key", "")) == str(expected[0]), "%s stable asset key" % event_id)
		_expect(str(row.get("original_filename", "")) == str(expected[1]), "%s exact selected source member" % event_id)
		_expect(str(row.get("source_asset_id", "")) == str(expected[3]), "%s selected package" % event_id)
		_expect(path.ends_with(".ogg") and FileAccess.file_exists(path), "%s local OGG exists" % event_id)
		_expect(FileAccess.get_sha256(path) == str(expected[2]), "%s pinned OGG SHA" % event_id)
		_expect(str(row.get("original_sha256", "")) == str(expected[2]) and str(row.get("processed_sha256", "")) == str(expected[2]), "%s rename-only fingerprint parity" % event_id)
		_expect(int(row.get("decoded_clipped_sample_count", -1)) == 0, "%s has no decoded clipping" % event_id)
		_expect(float(row.get("duration_seconds", 0.0)) > 0.0 and float(row.get("duration_seconds", 0.0)) < 2.0, "%s remains a short one-shot" % event_id)
		_expect(not bool(row.get("loop", true)), "%s is non-looping" % event_id)
		stream_paths[path] = true
		_test_ogg_load(path, float(row.get("duration_seconds", 0.0)), false, event_id)
	_expect(stream_paths.size() == EXPECTED_EVENTS.size(), "one deterministic file per event")
	for root_path in [
		"res://assets/third_party/commercial/audio/kenney_interface_sounds",
		"res://assets/third_party/commercial/audio/kenney_scifi_sounds",
	]:
		for filename in DirAccess.get_files_at(root_path):
			_expect(not filename.to_lower().ends_with(".zip") and not filename.to_lower().ends_with(".wav") and not filename.to_lower().ends_with(".mp3"), "%s excludes source archives and non-production audio" % root_path.get_file())


func _test_music_assets(contract: Dictionary) -> void:
	_expect(str(contract.get("contract_id", "")) == "space_syndicate.commercial_music.playlist.v1", "music contract id")
	_expect(is_equal_approx(float(contract.get("crossfade_seconds", 0.0)), 1.5), "exact 1.5-second crossfade")
	_expect(str(contract.get("crossfade_curve", "")) == "equal_power", "equal-power crossfade contract")
	_expect(str(contract.get("switch_input", "")) == "public_presentation_state_only", "music switches only from public presentation state")
	_expect(not bool(contract.get("hidden_information_dependency", true)), "music does not read hidden information")
	_expect(not bool(contract.get("gameplay_effect", true)) and not bool(contract.get("save_persisted", true)), "music cannot affect or persist gameplay")
	_expect(int(contract.get("rules_rng_draw_count", -1)) == 0, "music consumes no rules RNG")
	var rows: Array = contract.get("tracks", [])
	_expect(rows.size() == EXPECTED_MUSIC.size(), "exact four-track coverage")
	var by_key := _index_by(rows, "asset_key")
	_expect(by_key.size() == EXPECTED_MUSIC.size(), "music asset keys are unique")
	for asset_key in EXPECTED_MUSIC:
		var row: Dictionary = by_key.get(asset_key, {})
		var expected: Array = EXPECTED_MUSIC[asset_key]
		var path := str(row.get("stream_path", ""))
		_expect(str(row.get("state_id", "")) == str(expected[0]), "%s exact state mapping" % asset_key)
		_expect(str(row.get("title", "")) == str(expected[1]) and str(row.get("author", "")) == str(expected[2]), "%s exact title and author" % asset_key)
		_expect(str(row.get("source_url", "")) == str(expected[3]), "%s exact selected source page" % asset_key)
		_expect(str(row.get("license", "")) == "CC0-1.0", "%s CC0 license" % asset_key)
		_expect(path.ends_with(".ogg") and FileAccess.file_exists(path), "%s production OGG exists" % asset_key)
		_expect(FileAccess.get_sha256(path) == str(expected[4]) and str(row.get("processed_sha256", "")) == str(expected[4]), "%s pinned production SHA" % asset_key)
		_expect(bool(row.get("loop", false)), "%s loops" % asset_key)
		_expect(float(row.get("effective_peak_dbfs", 0.0)) <= -11.9, "%s playback trim preserves crossfade headroom" % asset_key)
		_expect(is_equal_approx(float(row.get("decoded_peak_dbfs", 0.0)) + float(row.get("gain_db", 0.0)), float(row.get("effective_peak_dbfs", 99.0))), "%s measured peak and gain agree" % asset_key)
		_test_ogg_load(path, float(expected[5]), true, asset_key)
	var music_root := "res://assets/third_party/commercial/music"
	for folder in DirAccess.get_directories_at(music_root):
		for filename in DirAccess.get_files_at("%s/%s" % [music_root, folder]):
			_expect(filename.to_lower().ends_with(".ogg") or filename.to_lower().ends_with(".import"), "%s packages production OGG only" % folder)


func _test_presentation_boundaries(events: Dictionary, music: Dictionary) -> void:
	for contract in [events, music]:
		_expect(bool(contract.get("production_registry_connected", false)), "contract records production presentation wiring")
		_expect(int(contract.get("runtime_network_dependency_count", -1)) == 0, "contract has no runtime network dependency")
	var combined := FileAccess.get_file_as_string(EVENT_MAP_PATH) + FileAccess.get_file_as_string(MUSIC_MAP_PATH)
	for forbidden in ["RandomNumberGenerator", "RunRngService", "V06SaveOwnerRegistry", "GameRuntimeCoordinator", "scripts/main.gd", "HTTPRequest", "HTTPClient"]:
		_expect(not combined.contains(forbidden), "audio contracts exclude authority token %s" % forbidden)
	_expect(FileAccess.file_exists("res://reports/asset_intake/audio_music_agent5.json"), "machine-readable intake report exists")
	_expect(FileAccess.file_exists("res://reports/asset_intake/audio_music_agent5.md"), "human-readable intake report exists")


func _test_ogg_load(path: String, expected_duration: float, expected_loop: bool, label: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	_expect(file != null and file.get_length() > 0 and file.get_length() <= MAX_FILE_BYTES, "%s file size is release-safe" % label)
	var stream := load(path) as AudioStreamOggVorbis
	_expect(stream != null, "%s loads as AudioStreamOggVorbis" % label)
	if stream != null:
		_expect(absf(stream.get_length() - expected_duration) <= 0.05, "%s decoded duration matches intake" % label)
		_expect(stream.loop == expected_loop, "%s imported loop flag matches contract" % label)


func _parse_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "%s parses as a JSON object" % path.get_file())
	return parsed as Dictionary if parsed is Dictionary else {}


func _index_by(rows: Array, key: String) -> Dictionary:
	var indexed: Dictionary = {}
	for row_variant in rows:
		if row_variant is Dictionary:
			var row: Dictionary = row_variant
			indexed[str(row.get(key, ""))] = row
	return indexed


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("COMMERCIAL_AUDIO_ASSET_CONTRACT_PASS %d/%d" % [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error("COMMERCIAL_AUDIO_ASSET_CONTRACT_FAIL %s" % failure)
	print("COMMERCIAL_AUDIO_ASSET_CONTRACT_FAIL %d/%d" % [_checks - _failures.size(), _checks])
	quit(1)
