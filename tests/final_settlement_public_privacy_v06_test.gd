extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/FinalSettlementPublicSnapshotService.tscn"
const CASH_PRIVACY_COPY := "现金为最终并列判定项，数值保密"
const AUDIT_PUBLIC_CASH_CENTS := 98765432
const HIDDEN_CASH_CENTS := 87654321
const AUDIT_AVAILABLE_CENTS := 87654320
const HIDDEN_AVAILABLE_CENTS := 76543210
const AUDIT_ESCROW_CENTS := 11111112
const HIDDEN_ESCROW_CENTS := 11111111
const AUDIT_PUBLIC_CASH_TEXT := "987654.32"
const FORBIDDEN_PUBLIC_KEYS := [
	"cash",
	"cash_cents",
	"cash_ledger_cents",
	"available",
	"available_cents",
	"escrow",
	"escrow_cents",
]
const PRIVATE_TEXT_SENTINELS := [
	"876543.21",
	"765432.10",
	"876543.20",
	"111111.11",
	"111111.12",
	"87654321",
	"76543210",
	"87654320",
	"11111111",
	"11111112",
]
const PRIVATE_NUMBER_SENTINELS := [
	HIDDEN_CASH_CENTS,
	AUDIT_AVAILABLE_CENTS,
	HIDDEN_AVAILABLE_CENTS,
	AUDIT_ESCROW_CENTS,
	HIDDEN_ESCROW_CENTS,
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SERVICE_SCENE) as PackedScene
	_expect(packed != null, "production FinalSettlementPublicSnapshotService scene loads")
	var service := packed.instantiate() if packed != null else null
	_expect(service != null, "production FinalSettlementPublicSnapshotService scene instantiates")
	if service == null:
		_finish()
		return
	root.add_child(service)
	service.call("configure", {})

	var source := _internal_source_with_private_cash()
	var source_before := source.duplicate(true)
	var first: Dictionary = service.call("compose", source)
	_expect(source == source_before, "compose does not mutate the internal source")
	_assert_private_cash_absent(first, "full public snapshot")

	var summary := str(first.get("summary_text", ""))
	var board: Dictionary = first.get("board", {}) if first.get("board", {}) is Dictionary else {}
	var kpis: Array = board.get("kpis", []) if board.get("kpis", []) is Array else []
	var money_sources: Array = board.get("money_sources", []) if board.get("money_sources", []) is Array else []
	var ranks: Array = board.get("ranks", []) if board.get("ranks", []) is Array else []
	_expect(summary.contains("准确现金（仅权威审计名单公开）") and not summary.contains(AUDIT_PUBLIC_CASH_TEXT), "summary names the state-aware cash rule without rendering a per-seat value")
	_expect(_variant_text(kpis).contains(AUDIT_PUBLIC_CASH_TEXT), "KPI exposes exact cash for the authoritative audit-revealed first seat")
	_expect(money_sources.size() == 2 and ranks.size() == 2, "public comparison order keeps both ranked seats")
	if money_sources.size() >= 2 and ranks.size() >= 2:
		_expect(_variant_text(money_sources[0]).contains(AUDIT_PUBLIC_CASH_TEXT) and _variant_text(money_sources[1]).contains(CASH_PRIVACY_COPY), "money-source exposes only the authoritative audit-revealed seat")
		_expect(_variant_text(ranks[0]).contains(AUDIT_PUBLIC_CASH_TEXT) and _variant_text(ranks[1]).contains(CASH_PRIVACY_COPY), "rank surface exposes only the authoritative audit-revealed seat")
	var comparison_text := "%s\n%s" % [summary, str(board.get("rank_title", ""))]
	_expect(_text_appears_in_order(comparison_text, ["Top-K个人归属GDP", "控制区域总数", "准确现金（仅权威审计名单公开）"]), "summary and rank title preserve the public comparison order")
	_assert_private_cash_absent(summary, "summary")
	_assert_private_cash_absent(kpis, "KPI surface")
	_assert_private_cash_absent(money_sources, "money-source surface")
	_assert_private_cash_absent(ranks, "rank surface")

	var board_text := _variant_text(board)
	_expect(board_text.contains("胜者:测试玩家") and board_text.contains("#1 测试玩家｜胜者"), "winner remains public")
	_expect(board_text.contains("Top-K归属GDP 145/min") and board_text.contains("控制区域4"), "Top-K GDP and controlled regions remain public")
	if money_sources.size() >= 2 and ranks.size() >= 2:
		_expect(str((money_sources[0] as Dictionary).get("title", "")).contains("测试玩家") and str((money_sources[1] as Dictionary).get("title", "")).contains("对手"), "money-source order follows the supplied public ranking")
		_expect(str((ranks[0] as Dictionary).get("title", "")).contains("测试玩家") and str((ranks[1] as Dictionary).get("title", "")).contains("对手"), "rank order follows the supplied public ranking")

	var second: Dictionary = service.call("compose", source)
	_expect(first == second, "repeated compose is output-pure for the same source")
	_expect(source == source_before, "repeated compose still leaves the source unchanged")
	_assert_private_cash_absent(second, "repeated public snapshot")

	var invalid_source := {
		"valid": false,
		"reason": "没有胜利结果；非审计席准确现金876543.21",
		"cash_ledger_cents": HIDDEN_CASH_CENTS,
		"available_cents": HIDDEN_AVAILABLE_CENTS,
		"escrow_cents": HIDDEN_ESCROW_CENTS,
	}
	var invalid_snapshot: Dictionary = service.call("compose", invalid_source)
	_expect(((invalid_snapshot.get("board", {}) as Dictionary).get("actions", []) as Array).size() == 3, "invalid input keeps safe postgame actions")
	_assert_private_cash_absent(invalid_snapshot, "invalid-input snapshot")

	var malformed_source := {
		"valid": true,
		"reason": "错误输入；现金总账¥987654.32",
		"outcome_receipt": "not-a-dictionary",
		"cash_visibility": "public_audit",
		"audit_revealed_player_indices": [0],
		"money_source_entries": [null, "wrong", {"cash_ledger_cents": AUDIT_PUBLIC_CASH_CENTS}],
		"rank_entries": [{"player_index": 0, "cash_ledger_cents": AUDIT_PUBLIC_CASH_CENTS}],
	}
	var malformed_snapshot: Dictionary = service.call("compose", malformed_source)
	_expect(str(malformed_snapshot.get("summary_text", "")).contains("缺少版本化胜利结果"), "malformed receipt produces a stable public error")
	_assert_audit_public_cash_absent(malformed_snapshot, "malformed receipt")
	_assert_private_cash_absent(malformed_snapshot, "malformed-input snapshot")

	var forged_without_visibility := source.duplicate(true)
	forged_without_visibility.erase("cash_visibility")
	forged_without_visibility["winner"] = true
	forged_without_visibility["game_over"] = true
	var forged_without_visibility_snapshot: Dictionary = service.call("compose", forged_without_visibility)
	_assert_audit_public_cash_absent(forged_without_visibility_snapshot, "cash fields plus winner/game_over without cash_visibility")
	_expect(_variant_text(forged_without_visibility_snapshot).contains(CASH_PRIVACY_COPY), "cash fields without authoritative visibility fail closed")

	var forged_without_roster := source.duplicate(true)
	forged_without_roster.erase("audit_revealed_player_indices")
	var forged_without_roster_snapshot: Dictionary = service.call("compose", forged_without_roster)
	_assert_audit_public_cash_absent(forged_without_roster_snapshot, "public_audit visibility without authoritative roster")
	_expect(_variant_text(forged_without_roster_snapshot).contains(CASH_PRIVACY_COPY), "public_audit visibility without authoritative roster fails closed")

	var debug: Dictionary = service.call("debug_snapshot")
	_expect(bool(debug.get("protects_private_cash", false)) and bool(debug.get("recursively_sanitizes_public_output", false)) and str(debug.get("cash_visibility_policy", "")) == "authoritative_public_audit_allowlist" and bool(debug.get("cash_disclosure_fail_closed", false)), "debug contract advertises the state-aware v0.6 cash boundary")
	service.queue_free()
	await process_frame
	_finish()


func _internal_source_with_private_cash() -> Dictionary:
	return {
		"valid": true,
		"reason": "公开审计完成；非审计席准确现金876543.21不得公开",
		"winner_names": ["测试玩家"],
		"cash_visibility": "public_audit",
		"audit_revealed_player_indices": [0],
		"required_top_n_gdp_per_minute": 130,
		"required_controlled_region_count": 4,
		"outcome_receipt": {
			"outcome_id": "victory.v06.private-cash.1",
			"reason_code": "public_audit_complete",
			"winner_player_indices": [0],
			"co_victory": false,
			"comparison_order": ["top_n_gdp_per_minute", "controlled_region_count", "cash_ledger_cents"],
			"internal_cash": {"available_cents": AUDIT_AVAILABLE_CENTS, "escrow_cents": AUDIT_ESCROW_CENTS},
		},
		"top_card_impact": "关键卡牌已公开；非审计席现金总账¥876543.21仍属私有",
		"monster_impact": "怪兽结算完成",
		"resolved_card_count": 3,
		"map_facts": {"active_city_count": 3, "destroyed_district_count": 1, "active_monster_count": 1, "monster_count": 2},
		"money_source_entries": [
			{
				"rank": 0, "player_index": 0, "name": "测试玩家", "top_n_gdp_per_minute": 145, "controlled_region_count": 4, "winner": true,
				"cash": AUDIT_PUBLIC_CASH_CENTS, "cash_ledger_cents": AUDIT_PUBLIC_CASH_CENTS, "available_cents": AUDIT_AVAILABLE_CENTS, "escrow_cents": AUDIT_ESCROW_CENTS,
				"city_income": 260, "card_income": 80, "role_income": 90, "gdp_per_minute": 180, "eliminated": false,
			},
			{
				"rank": 1, "player_index": 1, "name": "对手", "top_n_gdp_per_minute": 120, "controlled_region_count": 3, "winner": false,
				"cash": HIDDEN_CASH_CENTS, "cash_ledger_cents": HIDDEN_CASH_CENTS, "available_cents": HIDDEN_AVAILABLE_CENTS, "escrow_cents": HIDDEN_ESCROW_CENTS,
				"city_income": 180, "card_income": 140, "role_income": 40, "gdp_per_minute": 150, "eliminated": false,
				"audit_assets": {"cash_ledger_cents": HIDDEN_CASH_CENTS, "available_cents": HIDDEN_AVAILABLE_CENTS, "escrow_cents": HIDDEN_ESCROW_CENTS},
			},
		],
		"rank_entries": [
			{"player_index": 0, "name": "测试玩家", "top_n_gdp_per_minute": 145, "controlled_region_count": 4, "winner": true, "cash": AUDIT_PUBLIC_CASH_CENTS, "cash_ledger_cents": AUDIT_PUBLIC_CASH_CENTS, "available_cents": AUDIT_AVAILABLE_CENTS, "escrow_cents": AUDIT_ESCROW_CENTS, "gdp_per_minute": 180, "identity": "城市经营"},
			{"player_index": 1, "name": "对手", "top_n_gdp_per_minute": 120, "controlled_region_count": 3, "winner": false, "cash": HIDDEN_CASH_CENTS, "cash_ledger_cents": HIDDEN_CASH_CENTS, "available_cents": HIDDEN_AVAILABLE_CENTS, "escrow_cents": HIDDEN_ESCROW_CENTS, "gdp_per_minute": 150, "identity": "卡牌控制"},
		],
		"kpi_columns": 4,
		"money_columns": 2,
		"rank_columns": 2,
	}


func _assert_private_cash_absent(value: Variant, label: String) -> void:
	var leaks: Array[String] = []
	_collect_private_cash_leaks(value, label, leaks)
	_expect(leaks.is_empty(), "%s recursively excludes non-audit cash and cash components: %s" % [label, ", ".join(leaks)])


func _assert_audit_public_cash_absent(value: Variant, label: String) -> void:
	var text := _variant_text(value)
	_expect(not text.contains(AUDIT_PUBLIC_CASH_TEXT) and not text.contains(str(AUDIT_PUBLIC_CASH_CENTS)), "%s does not disclose audit cash without both authority fields" % label)


func _collect_private_cash_leaks(value: Variant, path: String, leaks: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if FORBIDDEN_PUBLIC_KEYS.has(key.to_lower()):
				leaks.append("forbidden-key:%s" % child_path)
			_collect_private_cash_leaks(value[key_variant], child_path, leaks)
	elif value is Array:
		for index in range(value.size()):
			_collect_private_cash_leaks(value[index], "%s[%d]" % [path, index], leaks)
	elif value is String or value is StringName:
		var text := str(value)
		for sentinel in PRIVATE_TEXT_SENTINELS:
			if text.contains(sentinel):
				leaks.append("text:%s:%s" % [path, sentinel])
	elif value is int:
		if PRIVATE_NUMBER_SENTINELS.has(int(value)):
			leaks.append("number:%s:%s" % [path, str(value)])
	elif value is float:
		if PRIVATE_NUMBER_SENTINELS.has(int(value)) and is_equal_approx(value, float(int(value))):
			leaks.append("number:%s:%s" % [path, str(value)])


func _variant_text(value: Variant) -> String:
	return JSON.stringify(value)


func _text_appears_in_order(value: String, needles: Array[String]) -> bool:
	var cursor := 0
	for needle in needles:
		var found_at := value.find(needle, cursor)
		if found_at < 0:
			return false
		cursor = found_at + needle.length()
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FINAL_SETTLEMENT_PUBLIC_PRIVACY_V06: %s" % message)


func _finish() -> void:
	print("FINAL_SETTLEMENT_PUBLIC_PRIVACY_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
