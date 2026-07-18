extends SceneTree

const HISTORY_SCENE := preload("res://scenes/runtime/CardResolutionHistoryRuntimeService.tscn")
const QUERY_SCENE := preload("res://scenes/runtime/presentation/CardHistoryPublicQueryPort.tscn")
const ANNOTATION_SCENE := preload("res://scenes/runtime/CardHistoryPrivateAnnotationService.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var history := HISTORY_SCENE.instantiate()
	var query := QUERY_SCENE.instantiate()
	var annotations := ANNOTATION_SCENE.instantiate()
	root.add_child(history)
	root.add_child(query)
	root.add_child(annotations)
	history.configure({"history_limit": 8})
	query.configure(history)
	annotations.configure(query)
	for index in range(3):
		_expect(bool(history.append_resolved(_entry(70 + index, index)).get("appended", false)), "history entry %d appends" % index)

	var public_snapshot: Dictionary = query.compose_history()
	var public_text := JSON.stringify(public_snapshot)
	_expect(int(public_snapshot.get("entry_count", 0)) == 3, "public query returns all resolved entries")
	_expect((public_snapshot.get("entries", []) as Array)[0].keys() == query.ENTRY_FIELDS, "public entry uses exact allowlist order")
	for forbidden in ["player_index", "slot_index", "cash", "hand", "hidden_actor", "true_owner", "guessers", "ai_plan"]:
		_expect(not public_text.contains(forbidden), "public query omits %s" % forbidden)
	_expect(str((public_snapshot.get("entries", []) as Array)[0].get("publicly_revealed_actor", "secret")) == "", "public query never reveals the hidden actor")

	var first_id := "card-history:70"
	var viewer_zero: Dictionary = annotations.apply_annotation(0, first_id, {
		"note_text": "公开目标靠近能源区",
		"private_tags": ["我的复盘"],
		"suspected_player_indices": [2],
		"private_confidence": 2,
	})
	_expect(bool(viewer_zero.get("applied", false)), "viewer zero can add a private annotation")
	_expect((annotations.viewer_snapshot(0).get("annotations", []) as Array).size() == 1, "viewer zero sees own annotation")
	_expect((annotations.viewer_snapshot(1).get("annotations", []) as Array).is_empty(), "viewer one cannot read viewer zero annotation")
	_expect(not public_text.contains("公开目标靠近能源区") and query.compose_history() == public_snapshot, "private annotation never changes the public projection")

	_expect(bool(annotations.subscribe_entries(0, ["card-history:70", "card-history:71"]).get("applied", false)), "viewer can subscribe to two history rows")
	var third_subscription: Dictionary = annotations.apply_annotation(0, "card-history:72", {"subscribed": true})
	_expect(not bool(third_subscription.get("applied", true)) and str(third_subscription.get("reason_code", "")) == "subscription_limit_reached", "third subscription fails closed")
	_expect(not bool(annotations.apply_annotation(0, first_id, {"cash_reward": 999}).get("applied", true)), "economic annotation patch fails closed")

	var ghost: Dictionary = annotations.use_residual_catalog_role(2, first_id, [0, 1, 2], 2)
	_expect(bool(ghost.get("applied", false)) and int(ghost.get("remaining", -1)) == 1, "Ghost residual review consumes one of two charges")
	var shard_seed: Dictionary = annotations.apply_annotation(3, first_id, {"suspected_player_indices": [0, 1, 2], "private_confidence": 1})
	var shard: Dictionary = annotations.use_public_exclusion_role(3, first_id, [1], 3)
	_expect(bool(shard_seed.get("applied", false)) and bool(shard.get("applied", false)) and int(shard.get("excluded_player_index", -1)) == 1, "Shardlight excludes one publicly impossible suspect")

	var debug_text := JSON.stringify(annotations.debug_snapshot())
	_expect(debug_text.contains("\"economic_reward_count\":0") and debug_text.contains("\"gdp_reward_count\":0"), "annotation service reports zero cash and GDP rewards")
	var checkpoint_receipt: Dictionary = annotations.capture_save_checkpoint(4)
	var checkpoint: Dictionary = checkpoint_receipt.get("checkpoint", {}) if checkpoint_receipt.get("checkpoint", {}) is Dictionary else {}
	history.reset_state()
	var structural_preflight: Dictionary = annotations.validate_save_checkpoint(checkpoint, 4)
	_expect(bool(structural_preflight.get("accepted", false)), "annotation structural preflight does not query live public history")
	var defensive_apply: Dictionary = annotations.apply_save_checkpoint(checkpoint, 4)
	_expect(not bool(defensive_apply.get("applied", true)) and str(defensive_apply.get("reason_code", "")) == "card_annotation_public_history_missing", "annotation apply retains a defensive live-history assertion")
	_expect(not bool(annotations.debug_snapshot().get("preflight_reads_live_history", true)), "annotation debug contract freezes structural-only preflight")
	var annotation_source := FileAccess.get_file_as_string("res://scripts/runtime/card_history_private_annotation_service.gd")
	_expect(not annotation_source.contains("func to_save_data") and not annotation_source.contains("func apply_save_data"), "session annotation service creates no nineteenth save owner")
	var role_source := FileAccess.get_file_as_string("res://scripts/runtime/role_catalog_runtime_service.gd")
	_expect(role_source.contains("card_history_residual_catalog_charges") and role_source.contains("card_history_public_exclusion_charges"), "final role replacement fields are present")
	for retired in ["intel_card_trace_charges", "card_owner_guess_discount", "card_owner_guess_bonus"]:
		_expect(not role_source.contains("\"%s\"" % retired), "role catalog omits retired field %s" % retired)
	var residual_text := FileAccess.get_file_as_string("res://resources/cards/runtime/families/009_出牌追帧.tres")
	var subscription_text := FileAccess.get_file_as_string("res://resources/cards/runtime/families/039_线索悬赏.tres")
	_expect(residual_text.contains("card_id = \"出牌追帧1\"") and residual_text.contains("display_name = \"残帧复盘 I\""), "residual review retains the stable card ID")
	_expect(subscription_text.contains("card_id = \"线索悬赏1\"") and subscription_text.contains("display_name = \"线索订阅 I\""), "subscription retains the compatibility card ID")

	history.queue_free()
	query.queue_free()
	annotations.queue_free()
	await process_frame
	_finish()


func _entry(resolution_id: int, player_index: int) -> Dictionary:
	return {
		"resolution_id": resolution_id,
		"player_index": player_index,
		"slot_index": 4,
		"resolved_time": 20.0 + resolution_id,
		"selected_district": resolution_id % 3,
		"resolved": true,
		"aftermath_clue": "公开余波%d" % resolution_id,
		"skill": {
			"name": "公开牌%d" % resolution_id,
			"display_name": "公开牌%d" % resolution_id,
			"kind": "card_counter",
			"hidden_actor": "SECRET_ACTOR_%d" % player_index,
		},
		"true_owner": player_index,
		"guessers": [0],
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_HISTORY_PUBLIC_ANNOTATION_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("CARD_HISTORY_PUBLIC_ANNOTATION_TEST failed:\n- " + "\n- ".join(_failures))
	quit(1)
