extends SceneTree

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := PublicLogPresentationOwner.new()
	root.add_child(owner)
	var receipt := _receipt()
	var applied := owner.append_receipt(receipt)
	_expect(bool(applied.get("applied", false)) and owner.recent_public_entries(8).size() == 1, "typed receipt seeds one public entry")
	var save := owner.to_save_data()
	_expect(int(save.get("schema_version", -1)) == 2 and (save.get("legacy_unverified_receipt_ids", []) as Array).is_empty(), "new public-log saves use fingerprint-bound schema v2")

	var restored := PublicLogPresentationOwner.new()
	root.add_child(restored)
	var restored_apply := restored.apply_save_data(save)
	var restored_duplicate := restored.append_receipt(receipt)
	_expect(bool(restored_apply.get("applied", false)) and bool(restored_duplicate.get("duplicate", false)) and restored.recent_public_entries(8).size() == 1, "schema v2 restores one binding and duplicate-no-ops")
	var collision := restored.append_receipt(_receipt("collision"))
	_expect(bool(collision.get("collision", false)) and restored.recent_public_entries(8).size() == 1, "same receipt identity with another fingerprint is rejected")

	var message_injection := save.duplicate(true)
	var injected_entries: Array = (message_injection.get("entries", []) as Array).duplicate(true)
	var injected_row: Dictionary = (injected_entries[0] as Dictionary).duplicate(true)
	injected_row["message"] = "PRIVATE_CASH_987654321 PRIVATE_HAND OWNER_TRUTH"
	injected_entries[0] = injected_row
	message_injection["entries"] = injected_entries
	var sanitized := PublicLogPresentationOwner.new()
	root.add_child(sanitized)
	var sanitized_apply := sanitized.apply_save_data(message_injection)
	var sanitized_text := JSON.stringify(sanitized.recent_public_entries(8)).to_lower()
	_expect(bool(sanitized_apply.get("applied", false)) and not sanitized_text.contains("987654321") and not sanitized_text.contains("private_hand") and not sanitized_text.contains("owner_truth"), "saved free text is discarded and re-rendered from the typed localization contract")

	var private_injection := save.duplicate(true)
	var private_entries: Array = (private_injection.get("entries", []) as Array).duplicate(true)
	var private_row: Dictionary = (private_entries[0] as Dictionary).duplicate(true)
	private_row["public_values"] = {"cash": 987654321}
	private_entries[0] = private_row
	private_injection["entries"] = private_entries
	var before_private_reject := sanitized.to_save_data()
	var private_reject := sanitized.apply_save_data(private_injection)
	_expect(not bool(private_reject.get("applied", true)) and sanitized.to_save_data() == before_private_reject, "private public_values injection fails with zero owner mutation")

	var binding_collision := save.duplicate(true)
	var collision_bindings: Dictionary = (binding_collision.get("applied_receipt_ids", {}) as Dictionary).duplicate(true)
	var collision_binding: Dictionary = (collision_bindings.get(receipt.receipt_id, {}) as Dictionary).duplicate(true)
	collision_binding["receipt_fingerprint"] = "saved-binding-collision".sha256_text()
	collision_bindings[receipt.receipt_id] = collision_binding
	binding_collision["applied_receipt_ids"] = collision_bindings
	var binding_reject := sanitized.apply_save_data(binding_collision)
	_expect(not bool(binding_reject.get("applied", true)) and sanitized.to_save_data() == before_private_reject, "saved entry/binding collision fails before live mutation")

	var incomplete_order := save.duplicate(true)
	incomplete_order["tombstone_order"] = []
	_expect(not bool(sanitized.apply_save_data(incomplete_order).get("applied", true)) and sanitized.to_save_data() == before_private_reject, "tombstone map/order must be one-to-one")

	var oversized := save.duplicate(true)
	var oversized_bindings: Dictionary = {}
	var oversized_order: Array = []
	for index in range(PublicLogPresentationOwner.MAX_TOMBSTONES + 1):
		var receipt_id := "oversized-%05d" % index
		oversized_order.append(receipt_id)
		oversized_bindings[receipt_id] = {
			"event_kind": "commodity_flow_sale_batch_committed",
			"source_revision": index,
			"receipt_fingerprint": ("oversized-%d" % index).sha256_text(),
		}
	oversized["entries"] = []
	oversized["applied_receipt_ids"] = oversized_bindings
	oversized["tombstone_order"] = oversized_order
	var capacity_reject := sanitized.apply_save_data(oversized)
	_expect(not bool(capacity_reject.get("applied", true)) and sanitized.to_save_data() == before_private_reject, "oversized tombstone saves fail closed instead of retaining an unbounded map")

	var legacy := save.duplicate(true)
	legacy["schema_version"] = 1
	legacy.erase("legacy_unverified_receipt_ids")
	var legacy_bindings: Dictionary = (legacy.get("applied_receipt_ids", {}) as Dictionary).duplicate(true)
	var legacy_binding: Dictionary = (legacy_bindings.get(receipt.receipt_id, {}) as Dictionary).duplicate(true)
	legacy_binding.erase("receipt_fingerprint")
	legacy_bindings[receipt.receipt_id] = legacy_binding
	legacy["applied_receipt_ids"] = legacy_bindings
	var legacy_owner := PublicLogPresentationOwner.new()
	root.add_child(legacy_owner)
	var legacy_apply := legacy_owner.apply_save_data(legacy)
	var legacy_duplicate := legacy_owner.append_receipt(receipt)
	var legacy_collision := legacy_owner.append_receipt(_receipt("collision"))
	_expect(bool(legacy_apply.get("applied", false)) and bool(legacy_duplicate.get("duplicate", false)), "schema v1 retained entry reconstructs its deterministic fingerprint")
	_expect(bool(legacy_collision.get("collision", false)) and legacy_owner.recent_public_entries(8).size() == 1, "migrated schema v1 binding still rejects a payload collision")

	var opaque_legacy := legacy.duplicate(true)
	opaque_legacy["entries"] = []
	var opaque_owner := PublicLogPresentationOwner.new()
	root.add_child(opaque_owner)
	var opaque_apply := opaque_owner.apply_save_data(opaque_legacy)
	var opaque_duplicate := opaque_owner.append_receipt(receipt)
	_expect(bool(opaque_apply.get("applied", false)) and opaque_owner.receipt_binding(receipt.receipt_id).is_empty() and bool(opaque_duplicate.get("duplicate", false)) and bool(opaque_duplicate.get("legacy_unverified", false)) and opaque_owner.recent_public_entries(8).is_empty(), "opaque schema v1 tombstone remains a safe duplicate-no-op and never reapplies an unknown payload")
	var opaque_roundtrip := PublicLogPresentationOwner.new()
	root.add_child(opaque_roundtrip)
	var opaque_roundtrip_apply := opaque_roundtrip.apply_save_data(opaque_owner.to_save_data())
	var opaque_roundtrip_duplicate := opaque_roundtrip.append_receipt(receipt)
	_expect(bool(opaque_roundtrip_apply.get("applied", false)) and bool(opaque_roundtrip_duplicate.get("legacy_unverified", false)), "opaque legacy marker round-trips explicitly in schema v2")

	var object_injection := save.duplicate(true)
	object_injection["entries"] = [Node.new()]
	var object_reject := sanitized.apply_save_data(object_injection)
	(object_injection.get("entries") as Array)[0].free()
	_expect(not bool(object_reject.get("applied", true)) and sanitized.to_save_data() == before_private_reject, "Object-bearing save data fails closed with zero owner mutation")
	_expect(not JSON.stringify(sanitized.recent_public_entries(8)).contains("receipt_id") and not bool(sanitized.debug_snapshot().get("private_payload_exposed", true)), "player-facing projection hides receipt lineage and private payloads")

	for node in [opaque_roundtrip, opaque_owner, legacy_owner, sanitized, restored, owner]:
		node.queue_free()
	await process_frame
	if _failures == 0:
		print("PUBLIC LOG PRESENTATION OWNER SAVE PASS: %d/%d" % [_checks, _checks])
		quit(0)
		return
	push_error("PUBLIC LOG PRESENTATION OWNER SAVE FAIL: %d/%d" % [_failures, _checks])
	quit(1)


func _receipt(result := "committed") -> PublicLogReceipt:
	return PublicLogReceipt.create(
		"commodity-postcommit-public:commodity-flow-batch-0000000001:test",
		&"commodity_flow_sale_batch_committed",
		&"public.commodity_flow.sale_batch_committed",
		{"result": result, "public_status": "sale_receipt", "value_band": "single"},
		1,
		12.0
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("PUBLIC LOG PRESENTATION OWNER SAVE: %s" % message)
