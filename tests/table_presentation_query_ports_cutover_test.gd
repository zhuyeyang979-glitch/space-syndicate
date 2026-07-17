extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const FORBIDDEN_KEYS := [
	"ai_plan", "ai_reason", "cash", "decision_samples", "hand", "hand_count",
	"hidden_owner", "learning_bonus", "owner", "owner_truth", "private_route_plan",
	"route_plan_score", "true_owner",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	var state := coordinator.world_session_state()
	state.replace_players(_fixture_players(), true)
	state.replace_districts(_fixture_districts(), true)
	state.set_game_time(75.0)
	coordinator.table_selection_state().set_active_context(0, 0, "crystal")
	var ports := coordinator.table_presentation_query_ports()
	_expect(ports != null, "production coordinator composes query ports")
	_expect(coordinator.find_children("TablePresentationQueryPorts", "", true, false).size() == 1, "query ports have one production instance")
	_expect(coordinator.presentation_authorized_viewer_index() == 0, "exactly one local human is authorized")
	_expect(coordinator.presentation_can_view_private_subject(0), "local viewer can read own private projection")
	_expect(not coordinator.presentation_can_view_private_subject(1), "local viewer cannot read opponent private projection")

	var public_world := coordinator.presentation_public_world_projection()
	_expect(public_world.players.size() == 3 and public_world.districts.size() == 2, "public world query exposes public participants and districts")
	_expect(not _contains_forbidden_key(public_world.to_dictionary()), "public world projection contains no private keys")
	_expect(not (public_world.districts[0] as Dictionary).get("city", {}).has("owner"), "public district city omits true owner")
	var own_private := coordinator.presentation_private_world_projection(0, 0)
	_expect(own_private.authorized and int(own_private.player.get("cash", -1)) == 900, "authorized viewer receives own cash")
	_expect((own_private.player.get("hand", []) as Array).size() == 1, "authorized viewer receives own allowlisted hand")
	_expect(not _contains_key_recursive(own_private.to_dictionary(), "hidden_owner"), "private projection strips hidden owner metadata")
	var opponent_private := coordinator.presentation_private_world_projection(0, 1)
	_expect(not opponent_private.authorized and opponent_private.player.is_empty(), "opponent private query fails closed")

	var map_projection := coordinator.presentation_public_map_projection(0, "crystal")
	_expect(map_projection.city_markers.size() == 2, "map projection contains public city markers")
	_expect(str((map_projection.city_markers[0] as Dictionary).get("owner_relation", "")) == "own", "own city is represented only as viewer relation")
	_expect(str((map_projection.city_markers[1] as Dictionary).get("owner_relation", "")) == "guessed", "opponent city uses the viewer's guess rather than owner truth")
	_expect(not _contains_forbidden_key(map_projection.to_dictionary()), "map projection is owner-truth redacted")

	var published := coordinator.record_public_log_event(&"test_public", &"test.public", {"message": "公开事件"}, 1, 75.0, "test-log-1")
	_expect(bool(published.get("applied", false)), "typed public log receipt is accepted once")
	var duplicate := coordinator.append_public_log_receipt(PublicLogReceipt.create("test-log-1", &"test_public", &"test.public", {"message": "重复"}, 1, 75.0))
	_expect(bool(duplicate.get("duplicate", false)), "duplicate public log receipt is rejected idempotently")
	var private_log := PublicLogReceipt.create("private-log", &"bad", &"bad", {"ai_plan": "SECRET"}, 1, 75.0)
	_expect(not private_log.is_valid(), "public log receipt rejects AI-private fields")
	var cash_log := PublicLogReceipt.create("cash-log", &"bad", &"bad", {"cash": 777}, 1, 75.0)
	_expect(not cash_log.is_valid(), "public log receipt rejects exact cash fields")
	var hand_log := PublicLogReceipt.create("hand-log", &"bad", &"bad", {"hand_count": 4}, 1, 75.0)
	_expect(not hand_log.is_valid(), "public log receipt rejects private hand fields")
	var owner_log := PublicLogReceipt.create("owner-log", &"bad", &"bad", {"owner_truth": 1}, 1, 75.0)
	_expect(not owner_log.is_valid(), "public log receipt rejects hidden owner truth")
	var arbitrary_log := PublicLogReceipt.create("arbitrary-log", &"bad", &"bad", {"internal_debug_payload": "SECRET"}, 1, 75.0)
	_expect(not arbitrary_log.is_valid(), "public log receipt rejects fields outside the public allowlist")
	_expect(coordinator.presentation_recent_public_log_messages(3).size() == 1, "public log owner is the only stored public history")

	var victory_receipt := ports.capture_victory_advance({"public_snapshot": {"state": "qualification", "remaining_seconds": 5.0, "victory_rule": {"required_region_count": 2}}})
	_expect(victory_receipt != null and victory_receipt.is_valid(), "victory state change produces a typed public receipt")
	var rejected_victory := ports.capture_victory_advance({"public_snapshot": {"state": "audit", "players": [{"cash": 999}]}})
	_expect(rejected_victory == null, "victory presentation rejects private world payloads")

	state.replace_players([_fixture_players()[0], {"name": "真人二", "is_ai": false}], true)
	_expect(coordinator.presentation_authorized_viewer_index() == -1, "multiple local humans fail closed until a viewer is explicitly modeled")
	_expect(not coordinator.presentation_can_view_private_subject(0), "ambiguous viewer cannot read private state")
	coordinator.queue_free()
	await process_frame
	_finish()


func _fixture_players() -> Array:
	return [
		{"name": "本地玩家", "is_ai": false, "cash": 900, "slots": [{"name": "城市发展", "rank": 1, "hidden_owner": "SECRET"}], "city_guesses": {1: 2}, "ai_plan": "SECRET"},
		{"name": "AI一", "is_ai": true, "cash": 777, "slots": [{"name": "秘密牌"}], "ai_plan": "SECRET"},
		{"name": "AI二", "is_ai": true, "cash": 666, "slots": [{"name": "秘密牌"}], "decision_samples": [1]},
	]


func _fixture_districts() -> Array:
	return [
		{"region_id": "r0", "name": "甲区", "center": Vector2(100, 100), "terrain": "land", "city": {"owner": 0, "active": true, "level": 1, "products": ["crystal"]}},
		{"region_id": "r1", "name": "乙区", "center": Vector2(300, 100), "terrain": "land", "city": {"owner": 1, "active": true, "level": 2, "demands": ["crystal"]}},
	]


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant).to_lower()
			if FORBIDDEN_KEYS.has(key) or _contains_forbidden_key(value[key_variant]):
				return true
	elif value is Array:
		for child in value:
			if _contains_forbidden_key(child):
				return true
	return false


func _contains_key_recursive(value: Variant, needle: String) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			if str(key_variant).to_lower() == needle or _contains_key_recursive(value[key_variant], needle):
				return true
	elif value is Array:
		for child in value:
			if _contains_key_recursive(child, needle):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("table_presentation_query_ports_cutover_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
	quit(_failures.size())
