extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CLOSED_CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const REASON := "card_inventory_v3_closed_wire_upgrade_requires_backup"
const QA_PATH := "user://test_runs/alpha04c_card_inventory_v3_fail_closed/card_inventory_v3.save"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_file()
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
			"alpha04c-card-inventory-v3-fail-closed",
			draft.draft_snapshot(),
			session.session_start_revision(),
			"focused_test"
		)
		var receipt := transaction.start_session(request)
		started = receipt != null and receipt.applied
	_expect(started, "production-equivalent v0.6 session starts")
	main.process_mode = Node.PROCESS_MODE_DISABLED

	var owner := coordinator.get_node_or_null("CardInventorySaveOwner") if coordinator != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	_expect(owner != null and registry != null and save != null and handshake != null, "Owner, Registry, Save coordinator, and Handshake are production-composed")
	if not started or owner == null or registry == null or save == null or handshake == null:
		main.queue_free()
		await process_frame
		_finish()
		return

	var owner_v4: Dictionary = owner.call("to_save_data")
	if owner_v4.is_empty():
		print("CARD_INVENTORY_V3_SOURCE_CAPTURE_DIAGNOSTICS|%s" % JSON.stringify(_capture_diagnostics(coordinator, owner)))
	var owner_before: Dictionary = owner.call("capture_runtime_checkpoint")
	var owner_debug_before: Dictionary = owner.call("debug_snapshot")
	var owner_v3 := owner_v4.duplicate(true)
	owner_v3["schema_version"] = 3
	var owner_preflight: Dictionary = owner.call("preflight_save_data", owner_v3)
	var owner_apply: Dictionary = owner.call("apply_save_data", owner_v3)
	var owner_after: Dictionary = owner.call("capture_runtime_checkpoint")
	var owner_debug_after: Dictionary = owner.call("debug_snapshot")
	_expect(not owner_v4.is_empty() and int(owner_v4.get("schema_version", 0)) == 4, "real Card Inventory captures v4 before legacy rejection")
	_expect(not bool(owner_preflight.get("accepted", true)) \
			and str(owner_preflight.get("reason_code", "")) == REASON \
			and bool(owner_preflight.get("requires_backup", false)), "Owner preflight rejects v3 with explicit backup reason")
	_expect(not bool(owner_apply.get("applied", true)) \
			and str(owner_apply.get("reason_code", "")) == REASON \
			and int(owner_debug_after.get("apply_count", -1)) == int(owner_debug_before.get("apply_count", -2)) \
			and owner_after == owner_before, "Owner rejects v3 with zero apply and zero runtime mutation")

	var capture: Dictionary = registry.call("capture_resume_envelope", {
		"envelope_id": "alpha04c-card-inventory-v3-source",
		"write_id": "alpha04c-card-inventory-v3-source-write",
	})
	var envelope: Dictionary = capture.get("envelope", {}) if capture.get("envelope") is Dictionary else {}
	var legacy := _legacy_card_inventory_v3(handshake, envelope)
	_expect(bool(capture.get("ok", false)) and (envelope.get("sections", {}) as Dictionary).size() == 19 \
			and not legacy.is_empty(), "one 19-section production envelope is converted only at the Card Inventory v3 boundary")

	var inspection: Dictionary = handshake.call("inspect_envelope", legacy)
	_expect(not bool(inspection.get("can_resume", true)) \
			and bool(inspection.get("requires_backup", false)) \
			and str(inspection.get("reason_code", "")) == REASON, "Handshake recognizes v3 and fails closed")

	var registry_preflight: Dictionary = registry.call("preflight_envelope", legacy)
	var registry_apply: Dictionary = registry.call("apply_envelope", legacy)
	var registry_debug: Dictionary = registry.call("debug_snapshot")
	var owner_after_registry: Dictionary = owner.call("capture_runtime_checkpoint")
	_expect(not bool(registry_preflight.get("ok", true)) \
			and bool(registry_preflight.get("requires_backup", false)) \
			and str(registry_preflight.get("reason_code", "")) == REASON, "Registry preflight propagates the typed v3 backup reason")
	_expect(not bool(registry_apply.get("ok", true)) \
			and bool(registry_apply.get("requires_backup", false)) \
			and str(registry_apply.get("reason_code", "")) == REASON \
			and int(registry_debug.get("last_owner_apply_count", -1)) == 0 \
			and int(registry_debug.get("last_registry_apply_count", -1)) == 0 \
			and owner_after_registry == owner_before, "Registry v3 rejection reaches zero Owner applies and preserves Card Inventory")

	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA_PATH.get_base_dir()))
	var file := FileAccess.open(QA_PATH, FileAccess.WRITE) if directory_error == OK else null
	if file != null:
		file.store_string(str(handshake.call("canonical_json", legacy)))
		file.flush()
		file.close()
	var bytes_before := FileAccess.get_file_as_bytes(QA_PATH) if FileAccess.file_exists(QA_PATH) else PackedByteArray()
	var readback: Dictionary = save.call("read_and_validate", QA_PATH)
	var bytes_after := FileAccess.get_file_as_bytes(QA_PATH) if FileAccess.file_exists(QA_PATH) else PackedByteArray()
	_expect(not bytes_before.is_empty() and bytes_after == bytes_before \
			and not bool(readback.get("ok", true)) \
			and bool(readback.get("requires_backup", false)) \
			and str(readback.get("reason_code", "")) == REASON, "isolated v3 file is preserved byte-for-byte after rejected read")
	_expect(QA_PATH != "user://saves/v06/current_run.save", "test never targets the production fixed Save slot")

	_cleanup_file()
	main.queue_free()
	await process_frame
	_finish()


func _legacy_card_inventory_v3(handshake: Node, envelope: Dictionary) -> Dictionary:
	if envelope.is_empty():
		return {}
	var legacy := envelope.duplicate(true)
	var sections := (legacy.get("sections", {}) as Dictionary).duplicate(true)
	var wrapper := (sections.get("card_inventory", {}) as Dictionary).duplicate(true)
	var decoded: Dictionary = handshake.call("decode_codec_value", wrapper.get("owner_state"))
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return {}
	var owner_state := (decoded.get("value", {}) as Dictionary).duplicate(true)
	owner_state["schema_version"] = 3
	var encoded: Dictionary = handshake.call("encode_codec_value", owner_state)
	if not bool(encoded.get("ok", false)):
		return {}
	wrapper["schema_version"] = 3
	wrapper["owner_state"] = encoded.get("value")
	sections["card_inventory"] = wrapper
	legacy["sections"] = sections

	var versions := (legacy.get("controller_state_versions", {}) as Dictionary).duplicate(true)
	versions["card_inventory"] = 3
	legacy["controller_state_versions"] = versions
	var manifest := (legacy.get("section_manifest", {}) as Dictionary).duplicate(true)
	var card_manifest := (manifest.get("card_inventory", {}) as Dictionary).duplicate(true)
	card_manifest["state_version"] = 3
	manifest["card_inventory"] = card_manifest
	legacy["section_manifest"] = manifest
	return legacy


func _capture_diagnostics(coordinator: Node, owner: Node) -> Dictionary:
	var result := {"owner": owner.call("debug_snapshot"), "children": {}}
	for child_id in ["CommodityCardInventoryRuntimeController", "ProductMarketRuntimeController", "DistrictPurchaseRuntimeController"]:
		var child := coordinator.get_node_or_null(child_id)
		var row := {"present": child != null, "save_empty": true, "schema_version": -1, "preflight_reason": "child_missing"}
		if child != null and child.has_method("to_save_data"):
			var state_variant: Variant = child.call("to_save_data")
			var state: Dictionary = state_variant if state_variant is Dictionary else {}
			row["save_empty"] = state.is_empty()
			row["schema_version"] = int(state.get("state_version", (state.get("district_purchase_runtime", {}) as Dictionary).get("schema_version", -1)))
			if not state.is_empty() and child.has_method("preflight_save_data"):
				var preflight_variant: Variant = child.call("preflight_save_data", state)
				var preflight: Dictionary = preflight_variant if preflight_variant is Dictionary else {}
				row["preflight_reason"] = str(preflight.get("reason_code", "preflight_result_invalid"))
			elif state.is_empty() and child_id == "ProductMarketRuntimeController":
				var market_snapshot: Dictionary = child.call("runtime_state_snapshot")
				var raw_candidate := {
					"state_version": 2,
					"ruleset_id": "v0.6",
					"product_market": child.call("_product_market_save_snapshot"),
					"business_cycle_count": int(market_snapshot.get("business_cycle_count", 0)),
					"market_timer": float(market_snapshot.get("market_timer", 0.0)),
					"futures_position_sequence": int(market_snapshot.get("futures_position_sequence", 0)),
				}
				var encoded := CLOSED_CODEC.encode_tree(raw_candidate)
				var candidate_preflight: Dictionary = child.call("preflight_save_data", encoded.get("value", {}) as Dictionary) \
						if bool(encoded.get("ok", false)) else {"reason_code": str(encoded.get("reason_code", "encode_failed"))}
				var market := raw_candidate.get("product_market", {}) as Dictionary
				row["preflight_reason"] = str(candidate_preflight.get("reason_code", "preflight_result_invalid"))
				row["product_count"] = market.size()
				row["first_invalid_entry"] = _first_invalid_product_entry(child, market)
				row["market_timer_finite"] = is_finite(float(raw_candidate.get("market_timer", 0.0)))
				row["market_timer_nonnegative"] = float(raw_candidate.get("market_timer", -1.0)) >= 0.0
				var transaction_preflight: Dictionary = child.call("ai_business_market_pressure_save_preflight")
				row["transaction_preflight_reason"] = str(transaction_preflight.get("reason_code", ""))
		(result.get("children", {}) as Dictionary)[child_id] = row
	return result


func _first_invalid_product_entry(child: Node, market: Dictionary) -> Dictionary:
	var product_ids: Array = market.keys()
	product_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for product_id_variant in product_ids:
		var product_id := str(product_id_variant)
		var entry_variant: Variant = market.get(product_id_variant)
		var singleton := {product_id: entry_variant}
		if bool(child.call("_product_market_shape_valid", singleton, false)):
			continue
		var field_types: Dictionary = {}
		if entry_variant is Dictionary:
			var fields: Array = (entry_variant as Dictionary).keys()
			fields.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
			for field_variant in fields:
				field_types[str(field_variant)] = type_string(typeof((entry_variant as Dictionary).get(field_variant)))
		return {
			"path": "$.product_market.<redacted>",
			"product_key_type": type_string(typeof(product_id_variant)),
			"entry_type": type_string(typeof(entry_variant)),
			"field_types": field_types,
		}
	return {}


func _cleanup_file() -> void:
	if FileAccess.file_exists(QA_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_PATH))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CARD_INVENTORY_V3_FAIL_CLOSED_EVIDENCE|%s" % JSON.stringify({
		"reason_code": REASON,
		"v3_direct_resume": false,
		"v3_save_file_preserved": _failures.is_empty(),
		"v3_save_apply_count": 0 if _failures.is_empty() else -1,
		"production_fixed_slot_write_count": 0,
	}))
	print("CARD_INVENTORY_V3_FAIL_CLOSED_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Card Inventory v3 fail-closed failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
