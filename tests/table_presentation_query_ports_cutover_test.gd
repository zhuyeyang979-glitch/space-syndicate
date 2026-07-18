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

	var published := coordinator.record_public_log_event(&"table_public_update", &"public.table.updated", {"action_kind": "table", "public_status": "updated"}, 1, 75.0, "test-log-1")
	_expect(bool(published.get("applied", false)), "typed public log receipt is accepted once")
	var duplicate := coordinator.append_public_log_receipt(PublicLogReceipt.create("test-log-1", &"table_public_update", &"public.table.updated", {"action_kind": "table", "public_status": "updated"}, 1, 75.0))
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
	var private_feedback := coordinator.record_legacy_viewer_feedback("当前只有¥123，私人目标已取消。")
	_expect(bool(private_feedback.get("applied", false)), "legacy local feedback is stored only for the authorized viewer")
	_expect(coordinator.presentation_recent_public_log_messages(3).size() == 1, "viewer-private feedback never enters public history")
	var production_log_cases := [
		["contract-log", &"contract_public_update", &"public.contract.updated", {"action_kind": "contract", "public_status": "updated"}],
		["military-log", &"military_public_update", &"public.military.updated", {"action_kind": "military", "public_status": "updated"}],
		["monster-log", &"monster_public_update", &"public.monster.updated", {"action_kind": "monster", "public_status": "updated"}],
		["market-log", &"market_public_update", &"public.market.updated", {"action_kind": "market", "public_status": "updated"}],
		["weather-log", &"weather_public_update", &"public.weather.updated", {"action_kind": "weather", "public_status": "updated"}],
		["victory-log", &"victory_state_changed", &"victory.public.state_changed", {"previous_state": "idle", "state": "qualification"}],
	]
	for index in range(production_log_cases.size()):
		var log_case: Array = production_log_cases[index]
		var receipt := PublicLogReceipt.create(str(log_case[0]), log_case[1] as StringName, log_case[2] as StringName, log_case[3] as Dictionary, 10 + index, 80.0 + index)
		_expect(bool(coordinator.append_public_log_receipt(receipt).get("applied", false)), "production public log key is accepted by typed owner")
	var player_messages := coordinator.presentation_recent_public_log_messages(16)
	var player_messages_json := JSON.stringify(player_messages)
	_expect(not player_messages_json.contains("public.") and not player_messages_json.contains("victory."), "player-facing public log messages never expose localization keys")
	for raw_enum in ["updated", "idle", "qualification", "resolving"]:
		_expect(not player_messages_json.contains(raw_enum), "player-facing public log messages never expose raw enum: %s" % raw_enum)
	for localized_copy in ["合约局势已更新", "军事部署已更新", "怪兽局势已更新", "商品市场已更新", "天气局势已更新", "胜利进程：等待 → 资格确认"]:
		_expect(player_messages_json.contains(localized_copy), "production localization key renders closed player copy: %s" % localized_copy)
	var sensitive_feedback_samples := [
		"资金不足：购买需要¥900，当前只有¥123。",
		"你的手牌有5张，必须选择一张弃牌。",
		"已私下弃置秘密牌。",
		"把乙城私人标注为玩家2。",
		"乙城标注置信度调整为高。",
		"乙城私人标注理由：牌序线索。",
		"匿名牌轨#3的真实出牌者已写入私人情报。",
		"合约真实签署者已写入私人情报。",
		"追加私有悬赏线索：城市2条。",
		"已取消怪兽目标选择，卡牌未消耗。",
		"已取消玩家目标选择，卡牌未消耗。",
		"目标玩家无效，请重新选择。",
		"当前操作冷却还需2.5秒。",
		"你购买了秘密卡牌，报价¥300。",
		"下次开局角色设置为黑潮风险基金。",
		"卡牌履历私人标注已更新；不产生现金或GDP。",
	]
	var public_count_before_sensitive := coordinator.presentation_recent_public_log_entries(64).size()
	for sample in sensitive_feedback_samples:
		_expect(bool(coordinator.record_legacy_viewer_feedback(sample).get("applied", false)), "sensitive local feedback is accepted only for the viewer")
	_expect(coordinator.presentation_recent_public_log_entries(64).size() == public_count_before_sensitive, "sixteen sensitive local feedback samples never enter PublicLog")
	_expect(coordinator.table_presentation_query_ports().recent_viewer_private_feedback(0, 32).size() >= 16, "authorized viewer can recover the sixteen private feedback samples")

	var victory_receipt := ports.capture_victory_advance({"public_snapshot": {"state": "qualification", "remaining_seconds": 5.0, "victory_rule": {"required_region_count": 2}}})
	_expect(victory_receipt != null and victory_receipt.is_valid(), "victory state change produces a typed public receipt")
	var redacted_victory := ports.capture_victory_advance({"public_snapshot": {"state": "audit", "players": [{"cash": 999}]}})
	_expect(redacted_victory != null and redacted_victory.is_valid() and not redacted_victory.to_dictionary().has("players") and not JSON.stringify(redacted_victory.to_dictionary()).contains("999"), "victory presentation redacts private world payloads")

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
