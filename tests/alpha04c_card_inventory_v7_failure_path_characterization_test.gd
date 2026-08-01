extends SceneTree

const DISTRICT_SCENE := preload("res://scenes/runtime/DistrictPurchaseRuntimeController.tscn")
const INSPECTOR := preload("res://scripts/tools/card_inventory_checkpoint_purity_inspector_v1.gd")

class QuoteAuthorityFixture:
	extends Node

	var next_quote_sequence := 1

	func export_quote_for_session(_quote_id: String) -> Dictionary:
		return {}

	func restore_quote_from_session(_quote: Dictionary) -> Dictionary:
		return {"restored": true}

	func capture_allocator_cursor() -> Dictionary:
		return {"schema_version": 1, "next_quote_sequence": next_quote_sequence}

	func restore_allocator_cursor(cursor: Dictionary) -> Dictionary:
		next_quote_sequence = int(cursor.get("next_quote_sequence", 1))
		return {"restored": true}

	func capture_runtime_checkpoint() -> Dictionary:
		return {"schema_version": 1, "next_quote_sequence": next_quote_sequence}

	func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		next_quote_sequence = int(checkpoint.get("next_quote_sequence", 1))
		return {"restored": true}


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var district := DISTRICT_SCENE.instantiate() as DistrictPurchaseRuntimeController
	var quote_authority := QuoteAuthorityFixture.new()
	root.add_child(quote_authority)
	root.add_child(district)
	district.set_quote_authority(quote_authority)
	district.configure()
	var opened := district.open_window(0, 0, {"supply_revision": "v7-production-purchase"})
	if opened.is_empty():
		_failures.append("production district purchase window did not open")
	var checkpoint := {
		"captured": true,
		"schema_version": 1,
		"children": {
			"commodity_card_inventory": {"schema_version": 1},
			"product_market": {"schema_version": 1},
			"district_purchase": district.capture_runtime_checkpoint(),
		},
		"modes": {
			"commodity_card_inventory": "runtime",
			"product_market": "runtime",
			"district_purchase": "runtime",
		},
	}
	var report := INSPECTOR.inspect(checkpoint)
	_expect(not bool(report.get("payload_pure_data", true)), "V7 Owner codec rejects the real district checkpoint")
	_expect(int(report.get("non_pure_leaf_count", 0)) == 1, "exactly one V7-incompatible leaf is present in the focused fixture")
	_expect(str(report.get("first_non_pure_child_id", "")) == "district_purchase", "district_purchase is the first V7-incompatible child")
	_expect(str(report.get("first_non_pure_path", "")) == "$.children.district_purchase.windows_by_player.<non_string_key:int>", "first path is the integer player-index Dictionary key")
	_expect(str(report.get("first_non_pure_variant_type", "")) == "int", "first incompatible Variant type is int used as a Dictionary key")
	_expect(str(report.get("first_non_pure_reason", "")) == "dictionary_key_not_owner_codec_compatible", "typed reason identifies the key contract")
	var redaction_report := INSPECTOR.inspect({"children": {"district_purchase": {
		"windows_by_player": {"private_player_key": 1.5},
	}}})
	var strict_redacted := redaction_report.get("strict_non_closed_leaves", []) as Array
	var redacted_path := str((strict_redacted[0] as Dictionary).get("json_path", "")) \
		if not strict_redacted.is_empty() else ""
	_expect(redacted_path.contains("<redacted:") and not redacted_path.contains("private_player_key"), "dynamic string keys are fingerprint-redacted")
	print("CARD_INVENTORY_V7_FAILURE_PATH_CHARACTERIZATION|%s" % JSON.stringify({
		"checkpoint_leaf_count": int(report.get("checkpoint_leaf_count", 0)),
		"non_pure_leaf_count": int(report.get("non_pure_leaf_count", 0)),
		"first_non_pure_child_id": str(report.get("first_non_pure_child_id", "")),
		"first_non_pure_path": str(report.get("first_non_pure_path", "")),
		"first_non_pure_variant_type": str(report.get("first_non_pure_variant_type", "")),
		"first_non_pure_reason": str(report.get("first_non_pure_reason", "")),
		"non_pure_type_counts": report.get("non_pure_type_counts", {}),
	}))
	district.queue_free()
	quote_authority.queue_free()
	await process_frame
	print("ALPHA04C_CARD_INVENTORY_V7_FAILURE_PATH_CHARACTERIZATION_TEST|status=%s|checks=7|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("V7 failure-path characterization failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
