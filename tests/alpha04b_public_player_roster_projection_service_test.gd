extends SceneTree

const SERVICE := preload(
	"res://scripts/presentation/public_player_roster_projection_service.gd"
)
const ROSTER := preload("res://scripts/presentation/public_player_roster_projection_v1.gd")
const INSPECTION := preload(
	"res://scripts/presentation/player_inspection_projection_v1.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := SERVICE.new() as PublicPlayerRosterProjectionService
	var public_players := _public_players(5)
	var roster := service.compose_roster(
		public_players,
		2,
		7,
		10,
		4,
		{
			"player.0": "unlocked",
			"player.1": "submitted",
			"player.2": "locked",
			"player.3": "waiting",
			"player.4": "unlocked",
		}
	)
	_expect(
		bool(ROSTER.validation_report(roster).get("valid", false)),
		"service builds the exact sealed public roster schema"
	)
	var rows: Array = roster.get("players", []) as Array
	_expect(
		_player_ids(rows) == ["player.0", "player.1", "player.2", "player.3", "player.4"]
			and _order_indices(rows) == [0, 1, 2, 3, 4],
		"source array order becomes public_order_index without local-player rotation"
	)
	_expect(
		bool((rows[2] as Dictionary).get("is_local_player", false))
			and bool((rows[4] as Dictionary).get("is_inspected", false))
			and str((rows[2] as Dictionary).get("submission_lock_public_state", "")) == "locked",
		"local, inspected, and public submission-lock markers remain separate allowlisted facts"
	)
	var roster_json := JSON.stringify(roster)
	_expect(
		not roster_json.contains("PRIVATE")
			and not roster_json.contains("cash")
			and not roster_json.contains("hand")
			and not roster_json.contains("ai_plan"),
		"roster assembly ignores private source fields"
	)

	var history_intent := {
		"kind": &"open_intel",
		"focused_history_entry_id": "card-history:7",
		"focused_region_id": "",
	}
	var table_intent := {
		"request_id": "player-inspection-audit",
		"action_kind": &"compendium_hub",
		"source_surface": &"player_roster",
		"target_card_name": "",
	}
	var inspection := service.compose_inspection(
		public_players[1] as Dictionary,
		2,
		7,
		10,
		{
			"public_assets_summary": "公开资产 3",
			"public_facilities_summary": "公开设施 2",
			"public_military_summary": "公开军力 1",
			"public_monster_summary": "暂无公开怪兽",
			"private_cash_summary": "PRIVATE_CASH",
		},
		[{
			"history_entry_id": "card-history:7",
			"label": "查看公开记录",
			"navigation_intent": history_intent,
			"private_note": "PRIVATE_HISTORY",
		}],
		[table_intent]
	)
	_expect(
		bool(INSPECTION.validation_report(inspection).get("valid", false)),
		"service builds the exact sealed public inspection schema"
	)
	var inspection_json := JSON.stringify(inspection)
	_expect(
		not inspection_json.contains("PRIVATE")
			and not inspection_json.contains("private_cash_summary")
			and not inspection_json.contains("private_note"),
		"inspection assembly copies only explicit public summary, history, and navigation fields"
	)
	_expect(
		str(inspection.get("player_id", "")) == "player.1"
			and str(inspection.get("public_assets_summary", "")) == "公开资产 3"
			and (inspection.get("public_history_links", []) as Array).size() == 1
			and (inspection.get("allowed_navigation_intents", []) as Array).size() == 1,
		"inspection identity and public navigation facts survive assembly"
	)

	_expect(service.bind_viewer(2, 7), "presentation cache binds an authorized viewer")
	_expect(service.apply_roster_projection(roster), "first roster projection applies")
	_expect(service.apply_roster_projection(roster), "identical roster projection is idempotent")
	var stale := service.compose_roster(public_players, 2, 7, 9)
	_expect(not service.apply_roster_projection(stale), "stale roster revision fails closed")
	var changed_players := public_players.duplicate(true)
	(changed_players[0] as Dictionary)["public_status"] = "waiting"
	var conflict := service.compose_roster(changed_players, 2, 7, 10)
	_expect(
		not service.apply_roster_projection(conflict),
		"same roster revision with another signature is rejected as a conflict"
	)

	_expect(service.apply_inspection_projection(inspection), "first inspection applies")
	var switched := service.compose_inspection(
		public_players[3] as Dictionary,
		2,
		7,
		10,
		{},
		[],
		[table_intent]
	)
	_expect(
		service.apply_inspection_projection(switched)
			and str(service.inspection_projection().get("player_id", "")) == "player.3",
		"a different public player can replace the popup at the same world revision"
	)

	var debug := service.debug_snapshot()
	_expect(
		int(debug.get("projection_assembler_count", 0)) == 1
			and not bool(debug.get("rotates_for_local_viewer", true))
			and int(debug.get("direct_gameplay_mutation_count", -1)) == 0
			and int(debug.get("rng_draw_count", -1)) == 0
			and int(debug.get("private_fact_read_count", -1)) == 0,
		"single projection assembler owns no gameplay mutation, RNG, or private reads"
	)
	_finish()


func _public_players(count: int) -> Array:
	var result: Array = []
	for player_index in range(count):
		result.append({
			"player_index": player_index,
			"public_player_name": "玩家%d" % (player_index + 1),
			"role_name": "公开角色%d" % (player_index + 1),
			"public_status": "ready",
			"eliminated": false,
			"cash": 999999,
			"hand": ["PRIVATE_CARD"],
			"ai_plan": "PRIVATE_PLAN",
		})
	return result


func _player_ids(rows: Array) -> Array[String]:
	var result: Array[String] = []
	for row_variant in rows:
		result.append(str((row_variant as Dictionary).get("player_id", "")))
	return result


func _order_indices(rows: Array) -> Array[int]:
	var result: Array[int] = []
	for row_variant in rows:
		result.append(int((row_variant as Dictionary).get("public_order_index", -1)))
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ALPHA04B_ROSTER_PROJECTION_SERVICE_PASS checks=%d" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("ALPHA04B_ROSTER_PROJECTION_SERVICE_FAIL: %s" % failure)
	quit(1)
