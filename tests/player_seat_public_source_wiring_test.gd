extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const PUBLIC_ROLE_NAMES := [
	"环港走私议会", "重力矿联董事会", "光合修复会", "星鲸餐饮垄断",
	"幽幕播报社", "赤环航运托拉斯", "黑潮风险基金", "暗礁公证黑市",
]
const STABLE_SEAT_POSITIONS := [
	&"left_low", &"right_low", &"left_mid_low", &"right_mid_low",
	&"left_mid_high", &"right_mid_high", &"left_high", &"right_high",
]
const FORBIDDEN_TOKENS := [
	"cash", "discard", "hand", "hand_count", "hidden_owner", "private_intel",
	"private_plan", "real_actor", "true_owner",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var screen := GAME_SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	screen.name = "GameScreen"
	host.add_child(screen)
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	coordinator.name = "GameRuntimeCoordinator"
	coordinator.presentation_game_screen_path = NodePath("../GameScreen")
	host.add_child(coordinator)
	_configure_presentation_dependencies(coordinator)
	await process_frame
	await process_frame

	var state := coordinator.world_session_state()
	var query := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	var service := coordinator.get_node_or_null("PlayerSeatPublicSourceService") as PlayerSeatPublicSourceService
	var seat_host := screen.find_child("RoleSeatLayerHost", true, false)
	_expect(query != null and service != null and seat_host != null, "production composition provides query, public seat source and seat host")
	_expect(state.players.is_empty() and _seat_descriptors(seat_host).is_empty(), "pre-session production table contains zero seats")
	if query == null or service == null or seat_host == null:
		await _finish(host)
		return

	for seat_count in [3, 4, 5, 6, 7, 8]:
		var players := _players(seat_count)
		if seat_count == 4:
			(players[3] as Dictionary)["eliminated"] = true
		state.replace_players(players, true)
		var raw_table := query.compose_table_state(2, false)
		var raw_sources := _planet_sources(raw_table)
		_expect(raw_sources.size() == seat_count, "%d-player real presentation query injects all public seats" % seat_count)
		var receipt := coordinator.request_table_presentation_refresh(&"live", &"player_seat_roster_changed")
		_expect(receipt.applied, "%d-player live refresh reaches the production GameScreen" % seat_count)
		await process_frame
		var descriptors := _seat_descriptors(seat_host)
		_expect(descriptors.size() == seat_count, "%d-player production refresh creates exactly %d seats" % [seat_count, seat_count])
		_expect(_unique_indices(descriptors) == seat_count and _local_count(descriptors) == 1, "%d-player seats have unique indices and exactly one local player" % seat_count)
		_expect(_stable_slot_mapping(descriptors, seat_count), "%d-player seats use the stable alternating side-slot mapping" % seat_count)
		_expect(StringName(_seat(descriptors, 2).get("seat_position", &"")) == &"left_low" and int(_seat(descriptors, 2).get("seat_index", -1)) == 0, "%d-player local viewer occupies stable left_low seat zero" % seat_count)
		_expect(_public_identity_is_complete(descriptors), "%d-player seats expose public name, assigned role, color and status" % seat_count)
		_expect(_anonymous_activity_is_safe(descriptors), "%d-player anonymous activity does not reveal a real actor" % seat_count)
		_expect(not _contains_forbidden_token(descriptors), "%d-player seat descriptors contain no private facts" % seat_count)
		var local_skin := screen.find_child("PlayerSeat_2", true, false)
		var local_skin_debug: Dictionary = local_skin.call("public_debug_snapshot") if local_skin != null and local_skin.has_method("public_debug_snapshot") else {}
		_expect(bool(local_skin_debug.get("local_marker_visible", false)), "%d-player local portrait displays the public 你 marker" % seat_count)
		if seat_count == 4:
			_expect(str(_seat(descriptors, 3).get("public_status", "")) == "eliminated", "eliminated public session fact reaches the seat status")

	var before_cache := service.debug_snapshot()
	var before_ids := _seat_node_ids(screen, 8)
	coordinator.request_table_presentation_refresh(&"live", &"unchanged_frame")
	coordinator.request_table_presentation_refresh(&"full", &"unchanged_frame")
	await process_frame
	var after_cache := service.debug_snapshot()
	_expect(int(after_cache.get("compose_count", 0)) > int(before_cache.get("compose_count", 0)), "unchanged presentation frames still query the cached public source")
	_expect(int(after_cache.get("rebuild_count", -1)) == int(before_cache.get("rebuild_count", -2)), "unchanged presentation frames do not rebuild the seat source")
	_expect(_seat_node_ids(screen, 8) == before_ids, "unchanged presentation frames preserve seat node identity")

	var revised_players := _players(8)
	(revised_players[1] as Dictionary)["role_card"] = {"name": "修订后的公开角色"}
	state.replace_players(revised_players, true)
	var revised_receipt := coordinator.request_table_presentation_refresh(&"live", &"public_revision_changed")
	await process_frame
	_expect(revised_receipt.applied and str(_seat(_seat_descriptors(seat_host), 1).get("role_name", "")) == "修订后的公开角色", "public roster revision refreshes the assigned role through the real path")
	_expect(int(service.debug_snapshot().get("rebuild_count", 0)) == int(after_cache.get("rebuild_count", 0)) + 1, "public roster revision rebuilds the cached source once")

	var loaded_players := _players(6)
	(loaded_players[2] as Dictionary)["name"] = "载入后的本地玩家"
	state.restore({"players": loaded_players, "districts": [], "game_time": 12.0}, true)
	var load_receipt := coordinator.request_table_presentation_refresh(&"full", &"session_loaded")
	await process_frame
	_expect(load_receipt.applied and _seat_descriptors(seat_host).size() == 6, "load restoration refreshes the production seat count")
	_expect(str(_seat(_seat_descriptors(seat_host), 2).get("public_player_name", "")) == "载入后的本地玩家", "load restoration refreshes public seat identity")

	state.reset()
	_expect(coordinator.presentation_authorized_viewer_index() == -1, "reset removes the authorized local viewer")
	host.queue_free()
	await process_frame
	_finish_result()


func _configure_presentation_dependencies(coordinator: GameRuntimeCoordinator) -> void:
	var card_presentation := coordinator.get_node_or_null("CardPresentationRuntimeService") as CardPresentationRuntimeService
	var table_viewmodel := coordinator.get_node_or_null("GameTableViewModelRuntimeService") as GameTableViewModelRuntimeService
	var eligibility := coordinator.get_node_or_null("CardPlayEligibilityRuntimeService") as CardPlayEligibilityRuntimeService
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var resolution := coordinator.get_node_or_null("CardResolutionRuntimeController") as CardResolutionRuntimeController
	var scheduler := coordinator.get_node_or_null("ForcedDecisionRuntimeScheduler") as ForcedDecisionRuntimeScheduler
	card_presentation.configure({})
	table_viewmodel.configure(card_presentation)
	eligibility.configure({"ruleset_id": "v0.6"})
	queue.configure({"ruleset_id": "v0.6", "card_group": RULESET.card_group_rules()})
	history.configure({"history_limit": 24})
	resolution.configure(RULESET.card_group_rules())
	scheduler.configure(["monster_wager", "counter_response", "contract_response", "other_choice"])


func _players(count: int) -> Array:
	var result: Array = []
	for player_index in range(count):
		result.append({
			"name": "玩家%d" % (player_index + 1),
			"is_ai": player_index != 2,
			"role_card": {"name": PUBLIC_ROLE_NAMES[player_index], "private_intel": "ROLE_SECRET"},
			"eliminated": false,
			"cash": 900000 + player_index,
			"slots": [{"name": "秘密手牌"}],
			"discard": [{"name": "秘密弃牌"}],
			"hidden_owner": player_index,
			"private_plan": "SECRET_PLAN_%d" % player_index,
			"real_actor": player_index,
			"is_publicly_active": true,
		})
	return result


func _planet_sources(table: Dictionary) -> Array:
	var planet: Dictionary = table.get("planet", {}) if table.get("planet", {}) is Dictionary else {}
	return (planet.get("public_player_seat_sources", []) as Array).duplicate(true) if planet.get("public_player_seat_sources", []) is Array else []


func _seat_descriptors(seat_host: Node) -> Array:
	var value: Variant = seat_host.call("seat_descriptors") if seat_host != null and seat_host.has_method("seat_descriptors") else []
	return value as Array if value is Array else []


func _seat(entries: Array, player_index: int) -> Dictionary:
	for entry_variant in entries:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			return entry_variant as Dictionary
	return {}


func _unique_indices(entries: Array) -> int:
	var seen := {}
	for entry_variant in entries:
		seen[int((entry_variant as Dictionary).get("player_index", -1))] = true
	return seen.size()


func _local_count(entries: Array) -> int:
	var count := 0
	for entry_variant in entries:
		if bool((entry_variant as Dictionary).get("is_local_player", false)):
			count += 1
	return count


func _stable_slot_mapping(entries: Array, seat_count: int) -> bool:
	if entries.size() != seat_count:
		return false
	for seat_index in range(seat_count):
		var entry: Dictionary = entries[seat_index] if entries[seat_index] is Dictionary else {}
		if int(entry.get("seat_index", -1)) != seat_index \
				or StringName(entry.get("seat_position", &"")) != STABLE_SEAT_POSITIONS[seat_index]:
			return false
	return true


func _public_identity_is_complete(entries: Array) -> bool:
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if str(entry.get("public_player_name", "")).is_empty() \
				or str(entry.get("role_name", "")).is_empty() \
				or not (entry.get("player_color") is Color) \
				or str(entry.get("public_status", "")).is_empty():
			return false
	return true


func _anonymous_activity_is_safe(entries: Array) -> bool:
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if bool(entry.get("is_publicly_active", true)):
			return false
	return true


func _contains_forbidden_token(value: Variant) -> bool:
	var encoded := JSON.stringify(value).to_lower()
	for token in FORBIDDEN_TOKENS:
		if encoded.contains(token):
			return true
	return false


func _seat_node_ids(screen: Node, count: int) -> Array[int]:
	var result: Array[int] = []
	for player_index in range(count):
		var node := screen.find_child("PlayerSeat_%d" % player_index, true, false)
		result.append(node.get_instance_id() if node != null else 0)
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish(host: Node) -> void:
	if host != null:
		host.queue_free()
	await process_frame
	_finish_result()


func _finish_result() -> void:
	print("PLAYER_SEAT_PUBLIC_SOURCE_WIRING_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
