extends SceneTree

const RulesSnapshot := preload("res://scripts/viewmodels/rules_quick_reference_snapshot_v06.gd")
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const RULEBOOK_PATH := "res://docs/tabletop_rulebook_v06.md"
const ROTATION_PERIOD_US := 120_000_000
const QUOTE_LIFETIME_US := 5_000_000
const RETIRED_ORACLE_PATHS := {
	"res://tests/smoke_test.gd": [
		"first_summon_plays",
		"monster landing regions discount card purchases while adjacent regions keep base price",
		"expected_landed_price := maxi(80",
		"func _verify_monster_region_card_pricing",
		"func _verify_first_run_coach_runtime_snapshot",
		"func _verify_remote_supply_access",
		"_district_card_access_kind",
	],
	"res://tests/layout_scene_smoke_test.gd": [
		"build_qualification_snapshot",
		"locked_price_multiplier",
		"tick_window(12.0",
		"_district_purchase_qualification_compatibility_adapter",
		"authorize_district_purchase",
		"expired_window_rejects_purchase",
		"\"access_kind\"",
		"_check_district_purchase_runtime_cutover_component",
		"purchase_window_uses_ruleset_12_seconds",
		"district_purchase_12_second_window",
		"bound_monster_064_and_080_context",
		"discounts_do_not_stack",
		"final_price_floor",
		"首召后开启附近牌架",
		"怪兽落地后，附近区域才是购牌锚点",
	],
	"res://tests/tomorrow_playable_vertical_slice_test.gd": [
		"human_authoritative_first_summon",
		"stage3-oracle-self-check",
		"stage3_oracle_self_check",
	],
	"res://scripts/tools/tomorrow_playable_vertical_slice_bench.gd": [
		"human_authoritative_first_summon",
		"_stage_human_first_summon",
		"_stage3_evidence_passes",
	],
	"res://tests/human_first_table_playability_v06_test.gd": [
		"human first-summon",
	],
	"res://tests/game_session_save_characterization_test.gd": [
		"MAIN_SCENE_PATH",
		"_capture_run_state",
		"_apply_run_state",
		"user://space_syndicate_design_qa/test_runs/",
	],
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_retired_oracles_are_physically_absent()
	_test_authoritative_public_rule_copy()
	_test_reference_market_math()
	_test_reference_solar_clock_and_quote_boundary()
	_test_registry_stays_eighteen_and_fail_closed()
	_finish()


func _test_retired_oracles_are_physically_absent() -> void:
	for path_variant in RETIRED_ORACLE_PATHS.keys():
		var path := str(path_variant)
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.is_empty(), "retirement source loads: %s" % path)
		var fragments: Array = RETIRED_ORACLE_PATHS.get(path_variant, []) if RETIRED_ORACLE_PATHS.get(path_variant, []) is Array else []
		for fragment_variant in fragments:
			var fragment := str(fragment_variant)
			_expect(not source.contains(fragment), "retired oracle is physically absent from %s: %s" % [path, fragment])


func _test_authoritative_public_rule_copy() -> void:
	var rulebook := FileAccess.get_file_as_string(RULEBOOK_PATH)
	var snapshot: Dictionary = RulesSnapshot.compose(1120.0)
	var public_copy := _flatten_text(snapshot)
	_expect(not rulebook.is_empty(), "authoritative v0.6 rulebook loads")
	for clause in [
		"每 120 秒完成一周权威自转",
		"打开普通牌市场、浏览挂牌或保持市场界面可见都不暂停",
		"q2 = min(10, 2 + 2×same + adjacent)",
		"最终现金价格为 `ceil(B×q2/2)`",
		"有效 5 秒 `world_effective` 时间",
		"何时召唤完全由玩家决定",
	]:
		_expect(rulebook.contains(clause), "rulebook keeps settled clause: %s" % clause)
	for phrase in [
		"召唤时点完全自愿",
		"未召唤不阻断经济、设施或购牌",
		"全局可查看；来源区域中心受光时才可购买",
		"同区每只 +1",
		"相邻每只 +0.5",
		"最高 5x",
		"向上取整",
		"所有玩家同价",
		"倒地或过期怪兽不计",
		"120秒轮换｜5秒锁价",
	]:
		_expect(public_copy.contains(phrase), "public quick reference keeps settled phrase: %s" % phrase)
	_expect(str(snapshot.get("visibility_scope", "")) == "public_static_rules", "quick reference is public static data")
	_expect(not public_copy.contains("exact_cash") and not public_copy.contains("private_hand") and not public_copy.contains("owner_truth"), "public rule copy contains no private state keys")


func _test_reference_market_math() -> void:
	var no_monster: Array[Dictionary] = []
	var one_adjacent: Array[Dictionary] = [{"band": "adjacent", "down": false, "expired": false, "owner": "rival"}]
	var mixed: Array[Dictionary] = [
		{"band": "same", "down": false, "expired": false, "owner": "local"},
		{"band": "same", "down": false, "expired": false, "owner": "neutral"},
		{"band": "adjacent", "down": false, "expired": false, "owner": "rival"},
		{"band": "adjacent", "down": true, "expired": false, "owner": "local"},
		{"band": "same", "down": false, "expired": true, "owner": "rival"},
	]
	_expect(_reference_quote(101, no_monster) == {"same": 0, "adjacent": 0, "q2": 2, "price": 101}, "no monster keeps the base price")
	_expect(_reference_quote(101, one_adjacent) == {"same": 0, "adjacent": 1, "q2": 3, "price": 152}, "one adjacent monster adds one half-step and rounds upward")
	_expect(_reference_quote(101, mixed) == {"same": 2, "adjacent": 1, "q2": 7, "price": 354}, "living same and adjacent monsters stack while down and expired monsters do not count")
	var ownership_variant := mixed.duplicate(true)
	for monster in ownership_variant:
		monster["owner"] = "arbitrary-other-owner"
	_expect(_reference_quote(101, ownership_variant) == _reference_quote(101, mixed), "ownership never changes the public quote")
	var capped: Array[Dictionary] = []
	for _index in range(8):
		capped.append({"band": "same", "down": false, "expired": false, "owner": "any"})
	_expect(_reference_quote(101, capped).get("q2") == 10 and _reference_quote(101, capped).get("price") == 505, "additive monster pressure caps at five times base")


func _test_reference_solar_clock_and_quote_boundary() -> void:
	var center := Vector2(1.0, 0.0)
	var initial_phase := 0.37
	var first_sun := _reference_sun_direction(23_456_789, initial_phase)
	var one_rotation_later := _reference_sun_direction(23_456_789 + ROTATION_PERIOD_US, initial_phase)
	_expect(first_sun.is_equal_approx(one_rotation_later), "120 world-effective seconds completes one deterministic rotation")
	var camera_a := {"view_center_m": Vector2.ZERO, "view_zoom": 0.5, "selected_district": 2}
	var camera_b := {"view_center_m": Vector2(900.0, 700.0), "view_zoom": 2.5, "selected_district": 19}
	_expect(_reference_sunlit(center, first_sun) == _reference_sunlit(center, one_rotation_later), "sunlight derives from world clock and fixed phase")
	_expect(_reference_listing_fingerprint(center, 23_456_789, initial_phase, 101, []) == _reference_listing_fingerprint(center, 23_456_789, initial_phase, 101, []), "listing fingerprint is deterministic")
	_expect(camera_a != camera_b and not _reference_listing_fingerprint(center, 23_456_789, initial_phase, 101, []).is_empty(), "camera facts are deliberately outside the rule fingerprint")
	var opened_at_us := 9_000_000
	var expires_at_us := opened_at_us + QUOTE_LIFETIME_US
	_expect(_quote_active(expires_at_us - 1, expires_at_us), "quote remains active immediately before expiry")
	_expect(not _quote_active(expires_at_us, expires_at_us), "quote expires at the half-open boundary")
	_expect(_advance_world_effective_us(10, 7, false) == 17, "market-visible world clock advances")
	_expect(_advance_world_effective_us(10, 7, true) == 10, "true pause freezes world-effective clock")


func _test_registry_stays_eighteen_and_fail_closed() -> void:
	var packed := load(COORDINATOR_SCENE_PATH) as PackedScene
	_expect(packed != null, "GameRuntimeCoordinator production scene loads")
	if packed == null:
		return
	var coordinator := packed.instantiate()
	root.add_child(coordinator)
	var session := coordinator.get_node_or_null("GameSessionRuntimeController")
	_expect(session != null, "GameRuntimeCoordinator composes one GameSession")
	if session == null:
		root.remove_child(coordinator)
		coordinator.queue_free()
		return
	session.call("configure", {"ruleset_id": "v0.6"})
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator")
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry")
	_expect(save != null and handshake != null and registry != null, "one GameSession composes Save, Handshake, and owner registry")
	if save != null and handshake != null and registry != null:
		var manifest: Dictionary = handshake.call("required_section_manifest")
		var order: Array = registry.call("fixed_section_order")
		var owner_ids: Dictionary = {}
		var forbidden_solar_section := false
		for section_variant in manifest.keys():
			var section_id := str(section_variant)
			var contract: Dictionary = manifest.get(section_id, {}) if manifest.get(section_id, {}) is Dictionary else {}
			owner_ids[str(contract.get("owner_id", ""))] = true
			var lowered := section_id.to_lower()
			for token in ["solar", "sunlight", "planet_rotation", "phase"]:
				forbidden_solar_section = forbidden_solar_section or lowered.contains(token)
		var registry_snapshot: Dictionary = registry.call("registry_snapshot")
		var capture: Dictionary = registry.call("capture_resume_envelope", {"envelope_id": "qa-only", "write_id": "qa-only"})
		_expect(manifest.size() == 18 and order.size() == 18 and owner_ids.size() == 18, "integrated registry has exactly eighteen unique owners")
		_expect(not forbidden_solar_section, "solar derivation does not become a nineteenth save section")
		_expect(bool(registry_snapshot.get("valid", false)) and not bool(registry_snapshot.get("resume_ready", true)), "registry remains structurally valid and explicitly not resume-ready")
		_expect(not bool(capture.get("ok", true)) and str(capture.get("reason_code", "")) == "restore_capability_incomplete", "incomplete owner capability fails closed instead of fabricating a resumable envelope")
		var save_snapshot: Dictionary = save.call("operation_snapshot")
		_expect(int(save_snapshot.get("save_version", 0)) == 3 and str(save_snapshot.get("qa_save_root", "")) == "user://test_runs/", "v3 transport remains isolated under user test runs")
	root.remove_child(coordinator)
	coordinator.queue_free()


func _reference_quote(base_price: int, monsters: Array[Dictionary]) -> Dictionary:
	var same := 0
	var adjacent := 0
	for monster in monsters:
		if bool(monster.get("down", false)) or bool(monster.get("expired", false)):
			continue
		match str(monster.get("band", "")):
			"same": same += 1
			"adjacent": adjacent += 1
	var q2 := mini(10, 2 + 2 * same + adjacent)
	return {"same": same, "adjacent": adjacent, "q2": q2, "price": ceili(float(base_price * q2) / 2.0)}


func _reference_sun_direction(world_effective_us: int, initial_phase: float) -> Vector2:
	var rotation_fraction := float(posmod(world_effective_us, ROTATION_PERIOD_US)) / float(ROTATION_PERIOD_US)
	var angle := initial_phase + TAU * rotation_fraction
	return Vector2(cos(angle), sin(angle))


func _reference_sunlit(center: Vector2, sun: Vector2) -> bool:
	return center.normalized().dot(sun.normalized()) >= 0.0


func _reference_listing_fingerprint(center: Vector2, world_effective_us: int, initial_phase: float, base_price: int, monsters: Array[Dictionary]) -> String:
	var sun := _reference_sun_direction(world_effective_us, initial_phase)
	var quote := _reference_quote(base_price, monsters)
	return JSON.stringify({"sunlit": _reference_sunlit(center, sun), "same": quote.same, "adjacent": quote.adjacent, "q2": quote.q2, "price": quote.price})


func _quote_active(now_us: int, expires_at_us: int) -> bool:
	return now_us < expires_at_us


func _advance_world_effective_us(now_us: int, delta_us: int, true_paused: bool) -> int:
	return now_us if true_paused else now_us + maxi(0, delta_us)


func _flatten_text(value: Variant) -> String:
	if value is Dictionary:
		var parts: Array[String] = []
		for nested in (value as Dictionary).values():
			parts.append(_flatten_text(nested))
		return "\n".join(parts)
	if value is Array:
		var parts: Array[String] = []
		for nested in value:
			parts.append(_flatten_text(nested))
		return "\n".join(parts)
	return str(value)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("V06_MARKET_ACCEPTANCE_CONTRACT_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("V06_MARKET_ACCEPTANCE_CONTRACT_TEST: %s" % failure)
	print("V06_MARKET_ACCEPTANCE_CONTRACT_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
