extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MISSING_CURSOR_REASON := "allocator_cursor_missing_requires_backup"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame

	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService \
			if services != null else null
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator \
			if services != null else null
	var started := false
	if draft != null and transaction != null and session != null:
		draft.reset_to_defaults()
		var request := SessionStartRequest.create(
			"alpha04c-allocator-v2-requires-backup",
			draft.draft_snapshot(),
			session.session_start_revision(),
			"focused_test"
		)
		var start_receipt := transaction.start_session(request)
		started = start_receipt != null and start_receipt.applied
	_expect(started, "focused v2 fixture starts one production default session")
	main.process_mode = Node.PROCESS_MODE_DISABLED

	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var handshake := session.get_node_or_null("GameSaveRuntimeCoordinator/RulesetSaveHandshakeService") if session != null else null
	_expect(registry != null and handshake != null, "focused v2 fixture composes Registry and Save handshake")
	if not started or registry == null or handshake == null:
		main.queue_free()
		await process_frame
		_finish()
		return

	var capture: Dictionary = registry.call("capture_resume_envelope", {
		"envelope_id": "alpha04c-allocator-v2-source",
		"write_id": "alpha04c-allocator-v2-source-write",
	})
	var envelope: Dictionary = capture.get("envelope", {}) if capture.get("envelope") is Dictionary else {}
	_expect(bool(capture.get("ok", false)) and not envelope.is_empty(), "focused v2 fixture captures a production v3 envelope")
	var legacy := _legacy_card_inventory_v2(handshake, envelope)
	_expect(not legacy.is_empty(), "focused fixture converts only card-inventory section and payload to v2")

	var inspection: Dictionary = handshake.call("inspect_envelope", legacy)
	_expect(
		not bool(inspection.get("can_resume", true))
				and bool(inspection.get("requires_backup", false))
				and str(inspection.get("reason_code", "")) == MISSING_CURSOR_REASON,
		"v2 envelope inspection propagates typed allocator requires_backup"
	)
	var preflight: Dictionary = registry.call("preflight_envelope", legacy)
	var debug: Dictionary = registry.call("debug_snapshot")
	_expect(
		not bool(preflight.get("ok", true))
				and bool(preflight.get("requires_backup", false))
				and str(preflight.get("reason_code", "")) == MISSING_CURSOR_REASON
				and str(debug.get("last_internal_preflight_failure_section", "")) == "card_inventory"
				and str(debug.get("last_internal_preflight_failure_reason", "")) == MISSING_CURSOR_REASON,
		"Registry propagates v2 allocator backup reason without applying an Owner"
	)

	main.queue_free()
	await process_frame
	_finish()


func _legacy_card_inventory_v2(handshake: Node, envelope: Dictionary) -> Dictionary:
	var legacy := envelope.duplicate(true)
	var sections := (legacy.get("sections", {}) as Dictionary).duplicate(true)
	var wrapper := (sections.get("card_inventory", {}) as Dictionary).duplicate(true)
	var decoded: Dictionary = handshake.call("decode_codec_value", wrapper.get("owner_state"))
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return {}
	var owner_state := (decoded.get("value", {}) as Dictionary).duplicate(true)
	var district := (owner_state.get("district_purchase", {}) as Dictionary).duplicate(true)
	var district_payload := (district.get("district_purchase_runtime", {}) as Dictionary).duplicate(true)
	owner_state["schema_version"] = 2
	district_payload["schema_version"] = 2
	district_payload.erase("next_quote_sequence")
	district["district_purchase_runtime"] = district_payload
	owner_state["district_purchase"] = district
	var encoded: Dictionary = handshake.call("encode_codec_value", owner_state)
	if not bool(encoded.get("ok", false)):
		return {}
	wrapper["schema_version"] = 2
	wrapper["owner_state"] = encoded.get("value")
	sections["card_inventory"] = wrapper
	legacy["sections"] = sections

	var versions := (legacy.get("controller_state_versions", {}) as Dictionary).duplicate(true)
	versions["card_inventory"] = 2
	legacy["controller_state_versions"] = versions
	var manifest := (legacy.get("section_manifest", {}) as Dictionary).duplicate(true)
	var card_manifest := (manifest.get("card_inventory", {}) as Dictionary).duplicate(true)
	card_manifest["state_version"] = 2
	manifest["card_inventory"] = card_manifest
	legacy["section_manifest"] = manifest
	return legacy


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("ALPHA04C ALLOCATOR V2 ENVELOPE: %s" % message)


func _finish() -> void:
	print("ALPHA04C_ALLOCATOR_V2_ENVELOPE_REQUIRES_BACKUP_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
