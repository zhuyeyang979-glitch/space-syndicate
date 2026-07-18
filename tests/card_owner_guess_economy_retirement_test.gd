extends SceneTree

const ROLE_CATALOG_SCENE := preload("res://scenes/runtime/RoleCatalogRuntimeService.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var queue_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_queue_runtime_service.gd")
	var dossier_source := FileAccess.get_file_as_string("res://scripts/runtime/intel_dossier_public_snapshot_service.gd")
	_expect(not main_source.contains("CARD_OWNER_GUESS_STAKE"), "Main owns no card-owner guess stake")
	_expect(not main_source.contains("_card_owner_guess_stake_for_player"), "Main owns no card-owner guess pricing")
	_expect(not main_source.contains("_card_owner_guess_payout_for_player"), "Main owns no card-owner guess payout")
	_expect(not main_source.contains("_guess_card_resolution_owner_for_player"), "Main owns no card-owner guess settlement")
	_expect(not main_source.contains("track_" + "guess_"), "Main routes no card-owner guess UI action")
	_expect(not main_source.contains("归属竞猜"), "Main contains no player-facing card-owner guess economy")
	_expect(not ai_source.contains("_ai_card_" + "guess_candidates"), "AI produces no card-owner guess candidates")
	_expect(not ai_source.contains("policy_kind\": \"card_owner_" + "guess"), "AI records no card-owner guess policy")
	_expect(not ai_source.contains("卡牌归属押注"), "AI exposes no card-owner wager reason")
	_expect(not queue_source.contains("\"guessers\":" ) and queue_source.contains("entry.erase(\"guessers\")"), "new card-resolution entries own no guesser list while legacy restore strips the retired field")
	_expect(not dossier_source.contains("track_" + "guess_"), "Intel dossier offers no card-owner guess action")
	var catalog := ROLE_CATALOG_SCENE.instantiate() as RoleCatalogRuntimeService
	_expect(catalog != null and catalog.role_count() == 24, "role catalog remains the unique 24-role owner")
	if catalog != null:
		for role_name in ["静电蜂巢银行", "幽幕播报社", "碎光私探行会", "黑潮风险基金", "白噪安保公司"]:
			var role := catalog.definition_by_name(role_name)
			_expect(not role.has("card_owner_guess_discount") and not role.has("card_owner_guess_bonus") and not role.has("intel_card_trace_charges"), "%s has no retired card-owner guess fields" % role_name)
		var static_hive := catalog.definition_by_name("静电蜂巢银行")
		_expect(str(static_hive.get("bonus_card_product", "")) == "静电蜂蜜", "Static Hive keeps only its existing bonus-card product rule")
		var ghost := catalog.definition_by_name("幽幕播报社")
		_expect(int(ghost.get("card_history_residual_catalog_charges", 0)) == 2, "Ghost Broadcast receives exactly two public-evidence catalog charges")
		var shard := catalog.definition_by_name("碎光私探行会")
		_expect(int(shard.get("card_history_public_exclusion_charges", 0)) == 3, "Shardlight receives exactly three public-evidence exclusion charges")
		var black_tide := catalog.definition_by_name("黑潮风险基金")
		_expect(int(black_tide.get("starting_cash_bonus", 0)) == 70 and int(black_tide.get("high_volatility_sale_threshold", 0)) == 12 and int(black_tide.get("high_volatility_first_sale_bonus", 0)) == 40 and bool(black_tide.get("high_volatility_bonus_once_per_market_cycle", false)), "Black Tide replacement terms are exact")
		var white_noise := catalog.definition_by_name("白噪安保公司")
		_expect(int(white_noise.get("starting_cash_bonus", 0)) == 40 and str(white_noise.get("resource_cash_product", "")) == "轨迹墨水" and int(white_noise.get("resource_cash_amount", 0)) == 40, "White Noise preserves its independent economy effects")
		catalog.free()
	print("CARD_OWNER_GUESS_ECONOMY_RETIREMENT_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	for failure in _failures:
		print("FAIL|%s" % failure)
	quit(_failures.size())


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("CARD_OWNER_GUESS_ECONOMY_RETIREMENT_TEST: %s" % label)
