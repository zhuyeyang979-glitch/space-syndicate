extends SceneTree

const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const V06_ENVELOPE_GATE_PATH := "res://tests/v06_save_envelope_runtime_test.gd"
const EXPECTED_SECTION_COUNT := 19
const FORBIDDEN_SOLAR_SECTION_TOKENS := ["solar", "sunlight", "planet_rotation", "phase"]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(V06_ENVELOPE_GATE_PATH), "the dedicated v3 envelope transport gate exists")
	var packed := load(COORDINATOR_SCENE_PATH) as PackedScene
	_expect(packed != null, "GameRuntimeCoordinator production scene loads")
	if packed == null:
		_finish()
		return
	var coordinator := packed.instantiate()
	root.add_child(coordinator)
	var session := coordinator.get_node_or_null("GameSessionRuntimeController")
	_expect(session != null, "GameRuntimeCoordinator composes one GameSession")
	if session == null:
		root.remove_child(coordinator)
		coordinator.queue_free()
		_finish()
		return
	session.call("configure", {"ruleset_id": "v0.6"})
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator")
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry")
	_expect(save != null and handshake != null and registry != null, "one GameSession composes Save, Handshake, and owner registry")
	if save != null and handshake != null and registry != null:
		_test_v3_transport_identity(save)
		_test_exact_owner_manifest(handshake, registry)
		_test_resume_fails_closed(registry)
	root.remove_child(coordinator)
	coordinator.queue_free()
	_finish()


func _test_v3_transport_identity(save: Node) -> void:
	var operation: Dictionary = save.call("operation_snapshot")
	_expect(int(operation.get("save_version", 0)) == 3, "GameSave transport identity is v3")
	_expect(str(operation.get("ruleset_id", "")) == "v0.6" and int(operation.get("currency_scale", 0)) == 100, "GameSave transport identity is v0.6 with integer cents")
	_expect(str(operation.get("default_save_path", "not-empty")).is_empty() and bool(operation.get("explicit_path_required", false)), "production transport has no implicit player save path")
	_expect(str(operation.get("qa_save_root", "")) == "user://test_runs/", "QA writes are isolated under the authoritative test root")
	_expect(not bool(operation.get("captures_business_state", true)), "GameSave remains transport-only and does not capture business owners")


func _test_exact_owner_manifest(handshake: Node, registry: Node) -> void:
	var manifest: Dictionary = handshake.call("required_section_manifest")
	var order: Array = registry.call("fixed_section_order")
	var owner_ids: Dictionary = {}
	var forbidden_section := false
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		var contract: Dictionary = manifest.get(section_id, {}) if manifest.get(section_id, {}) is Dictionary else {}
		owner_ids[str(contract.get("owner_id", ""))] = true
		var lowered := section_id.to_lower()
		for token in FORBIDDEN_SOLAR_SECTION_TOKENS:
			forbidden_section = forbidden_section or lowered.contains(token)
	_expect(manifest.size() == EXPECTED_SECTION_COUNT and order.size() == EXPECTED_SECTION_COUNT, "v0.6 manifest and apply order contain exactly nineteen sections")
	_expect(owner_ids.size() == EXPECTED_SECTION_COUNT, "all nineteen sections have unique owners")
	_expect(manifest.has("session") and manifest.has("bankruptcy_neutral_estate"), "session and bankruptcy neutral estate remain explicit owners")
	_expect(not forbidden_section, "derived solar state is not serialized as a twentieth section")


func _test_resume_fails_closed(registry: Node) -> void:
	var snapshot: Dictionary = registry.call("registry_snapshot")
	_expect(bool(snapshot.get("valid", false)), "owner registry is structurally valid")
	_expect(not bool(snapshot.get("resume_ready", true)) and int(snapshot.get("unsupported_section_count", 0)) > 0, "incomplete owner capabilities remain explicitly non-resumable")
	_expect(not bool(snapshot.get("captures_business_state", true)) and not bool(snapshot.get("stores_parallel_owner_state", true)), "registry owns orchestration without parallel gameplay state")
	var capture: Dictionary = registry.call("capture_resume_envelope", {"envelope_id": "characterization", "write_id": "characterization"})
	_expect(not bool(capture.get("ok", true)) and str(capture.get("reason_code", "")) == "restore_capability_incomplete", "resume capture fails closed until every owner is transactional")
	var public_receipt: Dictionary = registry.call("public_operation_receipt", capture)
	_expect(not public_receipt.has("sections") and not public_receipt.has("envelope") and not public_receipt.has("unsupported_section_ids"), "public failure receipt omits envelope sections and internal owner detail")


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_SESSION_SAVE_CHARACTERIZATION|status=PASS|checks=%d|failures=0|owner_sections=%d|resume_ready=false" % [_checks, EXPECTED_SECTION_COUNT])
		quit(0)
		return
	for failure in _failures:
		push_error("GAME_SESSION_SAVE_CHARACTERIZATION: %s" % failure)
	print("GAME_SESSION_SAVE_CHARACTERIZATION|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
