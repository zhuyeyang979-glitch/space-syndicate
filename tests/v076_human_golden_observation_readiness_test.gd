extends SceneTree

const Profile := preload(
	"res://scripts/playtest/v076_alpha07_human_golden_candidate_profile.gd"
)
const EventV1 := preload("res://scripts/playtest/v073_playtest_event_v1.gd")
const TELEMETRY_SCENE := (
	"res://scenes/playtest/V073PlaytestTelemetryService.tscn"
)
const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_BUILD_SHA := "0123456789abcdef0123456789abcdef01234567"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_profile_adapter()
	await _test_fail_closed_configuration()
	await _test_production_observation_export()
	_finish()


func _test_profile_adapter() -> void:
	var profile := Profile.snapshot()
	_expect(
		str(profile.get("schema", ""))
			== "V076Alpha07HumanGoldenCandidateProfileV1",
		"candidate profile schema is exact"
	)
	_expect(
		str(profile.get("product_version", "")) == "v0.7.6"
			and str(profile.get("runtime_ruleset_id", "")) == "v0.7.5",
		"candidate distinguishes V076 product from reused V075 runtime"
	)
	_expect(
		str(profile.get("profile_fingerprint_input", "")).sha256_text().to_lower()
			== str(profile.get("profile_fingerprint", "")),
		"candidate fingerprint is deterministic"
	)
	_expect(
		int(profile.get("golden_step_count", 0)) == 15
			and str(profile.get("golden_scenario_id", ""))
				== "v076-alpha07-golden-playtest-scenario-01",
		"candidate binds the one 15-step Golden scenario"
	)
	_expect(
		profile.get("evidence_source_type", "") == "OBSERVATION_ONLY"
			and profile.get("human_executed", true) == false
			and profile.get("human_confirmed", true) == false
			and profile.get("human_evidence_claim_allowed", true) == false
			and profile.get("production_green", true) == false
			and profile.get("human_green", true) == false,
		"candidate profile cannot self-assert production or human evidence"
	)
	_expect(
		int(profile.get("production_balance_value_change_count", -1)) == 0
			and not profile.has("values"),
		"candidate profile references existing authorities without copying balance values"
	)
	var sources := profile.get("source_authorities", {}) as Dictionary
	_expect(
		str(sources.get("economy_profile_fingerprint", "")).length() == 64
			and str(sources.get("combat_profile_fingerprint", "")).length() == 64
			and str(sources.get(
				"military_profile_catalog_fingerprint", ""
			)).length() == 64,
		"all reused balance authorities are fingerprint-bound"
	)


func _test_fail_closed_configuration() -> void:
	var packed := load(TELEMETRY_SCENE) as PackedScene
	_expect(packed != null, "existing telemetry scene loads")
	if packed == null:
		return
	var telemetry := packed.instantiate()
	root.add_child(telemetry)
	await process_frame
	var profile := Profile.snapshot()
	for mutation in [
		["human_executed", true],
		["human_confirmed", true],
		["human_evidence_claim_allowed", true],
		["runtime_ruleset_id", "v0.7.6"],
		["profile_fingerprint", "0".repeat(64)],
		["export_root", "user://../escape"],
	]:
		var invalid := profile.duplicate(true)
		invalid[str(mutation[0])] = mutation[1]
		_expect(
			telemetry.call("configure_candidate_profile", invalid) == false,
			"invalid candidate field %s is rejected" % str(mutation[0])
		)
	_expect(
		bool(telemetry.call("configure_candidate_profile", profile)),
		"one valid V076 profile configures the existing telemetry Owner"
	)
	_expect(
		telemetry.call("configure_candidate_profile", profile) == false,
		"candidate identity cannot be replaced after configuration"
	)
	var identity := telemetry.call("candidate_identity_snapshot") as Dictionary
	_expect(
		bool(identity.get("configured", false))
			and str(identity.get("product_version", "")) == "v0.7.6"
			and str(identity.get("runtime_ruleset_id", "")) == "v0.7.5",
		"configured identity snapshot is V076 over the V075 runtime"
	)
	telemetry.queue_free()
	await process_frame


func _test_production_observation_export() -> void:
	OS.set_environment("SPACE_SYNDICATE_BUILD_SHA", TEST_BUILD_SHA)
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main scene loads")
	if packed == null:
		return
	var application := packed.instantiate()
	root.add_child(application)
	for _frame in range(4):
		await process_frame
	var flow := application.get_node_or_null("V075RuntimeComposition")
	var telemetry := application.get_node_or_null(
		"V075RuntimeComposition/V073PlaytestTelemetryService"
	)
	_expect(flow != null, "production V075 composition is reachable")
	_expect(telemetry != null, "one existing telemetry Owner is production reachable")
	if flow == null or telemetry == null:
		application.queue_free()
		await process_frame
		return
	var identity := telemetry.call("candidate_identity_snapshot") as Dictionary
	_expect(
		bool(identity.get("configured", false))
			and str(identity.get("profile_id", ""))
				== "v076_alpha07_human_golden_candidate_01"
			and str(identity.get("build_sha", "")) == TEST_BUILD_SHA,
		"production bootstrap binds the exact V076 observation profile and build"
	)
	_expect(
		int(identity.get("gameplay_owner_count", -1)) == 0
			and int(identity.get("save_owner_count", -1)) == 0
			and int(identity.get("rng_owner_count", -1)) == 0
			and int(identity.get("tick_owner_count", -1)) == 0,
		"observation Owner owns no gameplay, Save, RNG, or Tick authority"
	)
	var export_root := "user://playtests/v076_readiness_test/%d" % OS.get_process_id()
	_expect(
		bool(telemetry.call("set_export_root_for_test", export_root)),
		"test export stays under isolated user data"
	)
	var started := flow.call("submit_intent", {
		"intent_id": "intent.v076.human-readiness.new-game",
		"intent_kind": "new_game.start",
		"parameters": {"player_count": 4, "seed": 900626424},
	}) as Dictionary
	_expect(bool(started.get("accepted", false)), "production new game starts once")
	for _frame in range(3):
		await process_frame
	var debug := telemetry.call("debug_snapshot") as Dictionary
	var started_identity := debug.get("candidate_identity", {}) as Dictionary
	_expect(
		str(started_identity.get("source_ruleset_id", "")) == "v0.7.5"
			and str(debug.get("session_id", "")).begins_with("v076-alpha07-"),
		"V075 source session is recorded under the V076 candidate identity"
	)
	_expect(
		bool(telemetry.call("finalize_session", {
			"skipped": true,
			"reason": "observation_readiness_test",
		})),
		"observation package exports without claiming a human pass"
	)
	var paths := telemetry.call("latest_export_paths") as Dictionary
	var manifest_path := str(paths.get("manifest.json", ""))
	var summary_path := str(paths.get("summary.json", ""))
	_expect(not manifest_path.is_empty(), "manifest export path is present")
	_expect(not summary_path.is_empty(), "summary export path is present")
	var manifest := _read_json(manifest_path)
	var summary := _read_json(summary_path)
	_expect(
		str(manifest.get("build_sha", "")) == TEST_BUILD_SHA
			and str(manifest.get("ruleset_id", "")) == "v0.7.6"
			and str(manifest.get("runtime_ruleset_id", "")) == "v0.7.5"
			and str(manifest.get("golden_scenario_id", ""))
				== "v076-alpha07-golden-playtest-scenario-01",
		"manifest binds build, product, runtime, and Golden scenario"
	)
	_expect(
		manifest.get("evidence_source_type", "") == "OBSERVATION_ONLY"
			and manifest.get("human_executed", true) == false
			and manifest.get("human_confirmed", true) == false
			and manifest.get("human_evidence_claim_allowed", true) == false
			and manifest.get("production_green", true) == false
			and manifest.get("human_green", true) == false
			and manifest.get("observer_attestation_required", false) == true,
		"manifest fails closed against self-asserted Human Golden evidence"
	)
	_expect(
		summary.get("human_executed", true) == false
			and summary.get("human_confirmed", true) == false
			and summary.get("production_green", true) == false
			and summary.get("human_green", true) == false,
		"summary remains observation-only"
	)
	for event in telemetry.call("events_snapshot") as Array:
		_expect(
			event is Dictionary
				and str((event as Dictionary).get("ruleset_id", "")) == "v0.7.6"
				and not EventV1.has_hidden_info(event as Dictionary),
			"every event is V076-labelled and privacy-safe"
		)
	application.queue_free()
	await process_frame


func _read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"V076_HUMAN_GOLDEN_OBSERVATION_READINESS|status=%s|checks=%d|failures=%d|human_executed=false|human_green=false|details=%s"
		% [status, _checks, _failures.size(), " || ".join(_failures)]
	)
	quit(0 if _failures.is_empty() else 1)
