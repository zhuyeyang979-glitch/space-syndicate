extends Node
class_name AiBusinessActionTransactionBoundaryBench

const RuntimeBalanceModelScript := preload("res://scripts/balance/runtime_balance_model.gd")

@export var auto_run := true

@onready var rng: RunRngService = $RunRngService
@onready var world: WorldSessionState = $WorldSessionState
@onready var formula: CardEconomyProductRouteFormulaRuntimeService = $CardEconomyProductRouteFormulaRuntimeService
@onready var bridge: ProductMarketRuntimeWorldBridge = $ProductMarketRuntimeWorldBridge
@onready var market: ProductMarketRuntimeController = $ProductMarketRuntimeController
@onready var weather: WeatherRuntimeController = $QaWeatherRuntimeController

var _balance := RuntimeBalanceModelScript.new()
var _checks := 0
var _failures: Array[String] = []
var _telemetry_rows: Array[Dictionary] = []
var _rng_plan_signal_count := 0
var _reentrant_finalize_receipt: Dictionary = {}
var _reentrant_finalize_attempts := 0
var _reentrant_finalize_result: Dictionary = {}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> Dictionary:
	_checks = 0
	_failures.clear()
	_telemetry_rows.clear()
	_rng_plan_signal_count = 0
	_reentrant_finalize_receipt.clear()
	_reentrant_finalize_attempts = 0
	_reentrant_finalize_result.clear()
	_setup_runtime()
	_case_prepare_commit_cash_failure_and_formula_parity()
	_case_finalize_exact_once_and_privacy()
	_case_replay_collision_stale_and_unsupported()
	_case_rollback_cas_failure_blocks_new_work()
	_case_save_boundary_is_not_owned()
	var report := debug_snapshot()
	print("AI_BUSINESS_ACTION_TRANSACTION_BOUNDARY_BENCH|status=%s|checks=%d|failures=%d|details=%s" % [
		str(report.get("status", "FAIL")),
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	return report


func debug_snapshot() -> Dictionary:
	return {
		"bench_complete": _checks > 0,
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"check_count": _checks,
		"failure_count": _failures.size(),
		"failures": _failures.duplicate(),
		"telemetry_row_count": _telemetry_rows.size(),
		"market_transaction": market.ai_business_market_pressure_debug_snapshot() if market != null else {},
	}


func observe_public_metric(event_id: int, metric_key: String, value: float) -> void:
	_telemetry_rows.append({"event_id": event_id, "metric_key": metric_key, "value": value})
	if not _reentrant_finalize_receipt.is_empty() and _reentrant_finalize_attempts == 0:
		_reentrant_finalize_attempts += 1
		_reentrant_finalize_result = market.finalize_ai_business_market_pressure(_reentrant_finalize_receipt)


func _on_rng_plan_state_committed(_state: int, _draw_count_delta: int) -> void:
	_rng_plan_signal_count += 1


func _balance_product_price_model(base_price: int, supply: int, demand: int, disrupted: int, monster_pressure: int, weather_modifier: int, volatility: int, noise: float, growth_multiplier: float) -> Dictionary:
	return _balance.product_price_model(base_price, supply, demand, disrupted, monster_pressure, weather_modifier, volatility, noise, growth_multiplier)


func _balance_product_price_step_cap(volatility: int, base_price: int) -> int:
	return int(_balance.product_price_step_cap(volatility, base_price))


func _setup_runtime() -> void:
	if not rng.plan_state_committed.is_connected(_on_rng_plan_state_committed):
		rng.plan_state_committed.connect(_on_rng_plan_state_committed)
	rng.set_seed(20260722)
	world.replace_players([{"cash": 9999, "cash_cents": 999900, "hand": ["PRIVATE_CARD"], "ai_plan": "PRIVATE_PLAN"}], true)
	world.replace_districts([{
		"region_id": "region-public-0",
		"destroyed": false,
		"products": [str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])],
		"demands": [str(ProductMarketRuntimeController.PRODUCT_CATALOG[1])],
		"city": {},
	}], true)
	formula.configure({"ruleset_id": "v0.4"})
	bridge.bind_world(self)
	bridge.set_rng_service(rng)
	bridge.set_world_session_state(world)
	market.set_world_bridge(bridge)
	market.set_weather_runtime_controller(weather)
	market.set_weather_telemetry_runtime_service(self)
	market.configure({"ruleset_id": "v0.4"}, formula)
	market.reset_state()
	_expect(bool(market.debug_snapshot().get("controller_ready", false)), "real ProductMarketRuntimeController is configured")
	_expect(bool(market.ai_business_market_pressure_authority_snapshot().get("available", false)), "transaction participant sees the authoritative market and shared RNG")


func _case_prepare_commit_cash_failure_and_formula_parity() -> void:
	var product_id := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	var pre_state := market.runtime_state_snapshot()
	var pre_rng := rng.capture_plan_checkpoint()
	var pre_telemetry := _telemetry_rows.size()
	var bridge_calls_before := int(bridge.debug_snapshot().get("world_call_count", -1))
	var request := _request("qa:cash-reject", product_id)
	var prepared := market.prepare_ai_business_market_pressure(request)
	_expect(bool(prepared.get("prepared", false)) and int(prepared.get("draw_count_delta", 0)) == 47, "prepare creates one 8-18 action draw plus 46 product-noise draws")
	_expect(_same(market.runtime_state_snapshot(), pre_state), "prepare has zero live market mutation")
	_expect(_same(rng.capture_plan_checkpoint(), pre_rng), "prepare has zero live RNG mutation")
	_expect(_telemetry_rows.size() == pre_telemetry, "prepare emits no telemetry")
	_expect(int(bridge.debug_snapshot().get("world_call_count", -2)) == bridge_calls_before, "prepare uses the typed world snapshot and pure balance model without a dynamic Main bridge call")
	var committed := market.commit_ai_business_market_pressure(prepared)
	var transaction_state := market.runtime_state_snapshot()
	var transaction_rng := rng.capture_plan_checkpoint()
	_expect(bool(committed.get("committed", false)) and bool(committed.get("rollback_open", false)), "commit opens one rollback window")
	_expect(int(transaction_rng.get("draw_count", 0)) - int(pre_rng.get("draw_count", 0)) == 47, "commit advances the shared RNG by exactly 47 draws")
	_expect(_telemetry_rows.size() == pre_telemetry, "commit keeps weather telemetry buffered")
	var commit_replay := market.commit_ai_business_market_pressure(prepared)
	_expect(bool(commit_replay.get("committed", false)) and bool(commit_replay.get("duplicate", false)), "commit replay is idempotent")
	_expect(_same(market.runtime_state_snapshot(), transaction_state) and _same(rng.capture_plan_checkpoint(), transaction_rng), "commit replay has zero market or RNG side effects")
	var forged_commit := prepared.duplicate(true)
	forged_commit["prepared_token"] = "forged"
	var forged_commit_result := market.commit_ai_business_market_pressure(forged_commit)
	_expect(str(forged_commit_result.get("reason_code", "")) == "ai_business_market_pressure_prepared_token_invalid" and not forged_commit_result.has("prepared_token"), "committed replay requires the opaque prepared token and never discloses it")
	var rolled_back := market.rollback_ai_business_market_pressure(committed)
	_expect(bool(rolled_back.get("rolled_back", false)), "cash rejection can reverse the committed market effect")
	_expect(_same(market.runtime_state_snapshot(), pre_state), "cash rejection restores the complete market preimage")
	_expect(_same(rng.capture_plan_checkpoint(), pre_rng), "cash rejection restores RNG state and draw count")
	_expect(_telemetry_rows.size() == pre_telemetry, "cash rejection emits no telemetry")
	_expect(_rng_plan_signal_count == 0, "tentative RNG commit and cash-failure rollback publish no irreversible RNG observer signal")
	var rollback_replay := market.rollback_ai_business_market_pressure(committed)
	_expect(bool(rollback_replay.get("rolled_back", false)) and bool(rollback_replay.get("duplicate", false)), "cash-failure rollback replay is idempotent")
	var legacy_action_delta := rng.randi_range(8, 18)
	var legacy_draw_after_action := int(rng.debug_snapshot().get("draw_count", 0))
	market.apply_external_pressure(product_id, int(ceil(float(legacy_action_delta) / 10.0)), 0, 0, true)
	_expect(int(rng.debug_snapshot().get("draw_count", 0)) - legacy_draw_after_action == 46, "ordinary refresh keeps one noise draw per product")
	if not _same(market.runtime_state_snapshot(), transaction_state):
		print("AI_BUSINESS_PARITY_DIFF|%s" % _first_difference(transaction_state, market.runtime_state_snapshot()))
	_expect(_same(market.runtime_state_snapshot(), transaction_state), "transaction result matches the existing price-pump formula and refresh path")
	_expect(_same(rng.capture_plan_checkpoint(), transaction_rng), "transaction and existing path end on the same RNG cursor")
	_expect(_rng_plan_signal_count == 0, "ordinary market refresh preserves the existing no-plan-signal behavior")
	market.product_market = (pre_state.get("product_market", {}) as Dictionary).duplicate(true)
	market.business_cycle_count = int(pre_state.get("business_cycle_count", 0))
	market.market_timer = float(pre_state.get("market_timer", 0.0))
	market.futures_position_sequence = int(pre_state.get("futures_position_sequence", 0))
	rng.restore_plan_checkpoint(pre_rng)
	_telemetry_rows.clear()


func _case_finalize_exact_once_and_privacy() -> void:
	var product_id := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	var prepared := market.prepare_ai_business_market_pressure(_request("qa:finalize", product_id))
	var committed := market.commit_ai_business_market_pressure(prepared)
	_expect(not bool(market.ai_business_market_pressure_save_preflight().get("accepted", true)), "save preflight fails closed while cash may still reject")
	_expect(_telemetry_rows.is_empty(), "telemetry remains empty before finalization")
	var committed_market := market.runtime_state_snapshot()
	var committed_rng := rng.capture_plan_checkpoint()
	var blocked_load := market.apply_save_data({"product_market": {}})
	var blocked_checkpoint := market.restore_new_session_checkpoint(committed_market)
	_expect(not bool(blocked_load.get("applied", true)) and str(blocked_load.get("reason_code", "")) == "ai_business_market_pressure_rollback_window_open", "save restore cannot erase an open market rollback window")
	_expect(not bool(blocked_checkpoint.get("restored", true)) and str(blocked_checkpoint.get("reason_code", "")) == "ai_business_market_pressure_rollback_window_open", "new-session checkpoint restore cannot erase an open market rollback window")
	_expect(_same(market.runtime_state_snapshot(), committed_market) and _same(rng.capture_plan_checkpoint(), committed_rng), "blocked restore paths preserve committed market and RNG state")
	var forged_finalize := committed.duplicate(true)
	forged_finalize["prepared_token"] = "forged"
	var forged_finalize_result := market.finalize_ai_business_market_pressure(forged_finalize)
	_expect(str(forged_finalize_result.get("reason_code", "")) == "ai_business_market_pressure_commit_receipt_invalid" and _telemetry_rows.is_empty(), "finalize rejects a forged token before telemetry or public receipt publication")
	_reentrant_finalize_receipt = committed.duplicate(true)
	var finalized := market.finalize_ai_business_market_pressure(committed)
	_reentrant_finalize_receipt.clear()
	var telemetry_after := _telemetry_rows.size()
	_expect(bool(finalized.get("finalized", false)) and telemetry_after > 0, "finalize publishes buffered weather telemetry")
	_expect(_reentrant_finalize_attempts == 1 and str(_reentrant_finalize_result.get("reason_code", "")) == "ai_business_market_pressure_finalization_in_progress", "synchronous telemetry reentry is rejected before a duplicate batch can publish")
	var replay := market.finalize_ai_business_market_pressure(committed)
	_expect(bool(replay.get("finalized", false)) and bool(replay.get("duplicate", false)), "finalize replay is idempotent")
	var forged_finalized_replay := market.finalize_ai_business_market_pressure(forged_finalize)
	_expect(str(forged_finalized_replay.get("reason_code", "")) == "ai_business_market_pressure_commit_receipt_invalid" and not forged_finalized_replay.has("prepared_token"), "finalized replay remains token-bound and never leaks the real token")
	_expect(_telemetry_rows.size() == telemetry_after, "finalize replay never duplicates telemetry")
	_expect(int(market.ai_business_market_pressure_debug_snapshot().get("telemetry_metric_count", -1)) == telemetry_after, "transaction diagnostics count only metrics actually emitted to the telemetry target")
	_expect(_rng_plan_signal_count == 0, "successful transaction preserves the legacy no-plan-signal RNG observer contract")
	_expect(bool(market.ai_business_market_pressure_save_preflight().get("accepted", false)), "save preflight is safe after finalization closes rollback")
	var public_receipt: Dictionary = finalized.get("public_receipt", {}) as Dictionary
	_expect(not public_receipt.is_empty() and str(public_receipt.get("visibility_scope", "")) == "public", "finalize returns a visibility-tagged public receipt")
	_expect(_keys_equal(public_receipt.keys(), ProductMarketRuntimeController.AI_BUSINESS_MARKET_PRESSURE_PUBLIC_RECEIPT_KEYS), "public receipt uses the strict allowlist")
	var public_text := JSON.stringify(public_receipt).to_lower()
	_expect(_forbidden_terms_absent(public_text), "public receipt excludes actor, cash, RNG, AI plan and private state")
	_expect(_is_pure_data(public_receipt), "public receipt is stable pure data")
	_expect(int(market.ai_business_market_pressure_debug_snapshot().get("terminal_heavy_record_count", -1)) == 0, "finalized journal records release market preimages, RNG cursors and telemetry batches")


func _case_replay_collision_stale_and_unsupported() -> void:
	var first_product := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	var second_product := str(ProductMarketRuntimeController.PRODUCT_CATALOG[1])
	var prepared := market.prepare_ai_business_market_pressure(_request("qa:collision", first_product))
	var replay := market.prepare_ai_business_market_pressure(_request("qa:collision", first_product))
	_expect(bool(replay.get("prepared", false)) and bool(replay.get("duplicate", false)), "same transaction and fingerprint replay without another RNG plan")
	var collision := market.prepare_ai_business_market_pressure(_request("qa:collision", second_product))
	_expect(str(collision.get("reason_code", "")) == "ai_business_market_pressure_transaction_collision", "same transaction with another fingerprint is rejected")
	var telemetry_before_cancel := _telemetry_rows.size()
	var cancelled := market.rollback_ai_business_market_pressure(prepared)
	_expect(bool(cancelled.get("rolled_back", false)) and _telemetry_rows.size() == telemetry_before_cancel, "prepared-only cancellation is terminal without touching prior telemetry")
	var stale_request := _request("qa:stale", first_product)
	stale_request["expected_market_fingerprint"] = "0".repeat(64)
	var rng_before_rejections := rng.capture_plan_checkpoint()
	var stale := market.prepare_ai_business_market_pressure(stale_request)
	_expect(str(stale.get("reason_code", "")) == "ai_business_market_pressure_request_stale", "stale market binding fails before RNG consumption")
	var stale_revision_request := _request("qa:stale-revision", first_product)
	stale_revision_request["source_revision"] = int(stale_revision_request.get("source_revision", 0)) + 1
	var stale_revision := market.prepare_ai_business_market_pressure(stale_revision_request)
	_expect(str(stale_revision.get("reason_code", "")) == "ai_business_market_pressure_request_stale", "stale business-cycle revision fails before RNG consumption")
	var missing_fingerprint_request := _request("qa:missing-fingerprint", first_product)
	missing_fingerprint_request["expected_market_fingerprint"] = ""
	var missing_fingerprint := market.prepare_ai_business_market_pressure(missing_fingerprint_request)
	_expect(str(missing_fingerprint.get("reason_code", "")) == "ai_business_market_pressure_expected_fingerprint_missing", "missing market fingerprint fails closed before RNG consumption")
	var malformed_fingerprint_request := _request("qa:malformed-fingerprint", first_product)
	malformed_fingerprint_request["expected_market_fingerprint"] = "not-a-sha256"
	var malformed_fingerprint := market.prepare_ai_business_market_pressure(malformed_fingerprint_request)
	_expect(str(malformed_fingerprint.get("reason_code", "")) == "ai_business_market_pressure_expected_fingerprint_invalid", "malformed market fingerprint fails closed before RNG consumption")
	var missing_revision_request := _request("qa:missing-revision", first_product)
	missing_revision_request.erase("source_revision")
	var missing_revision := market.prepare_ai_business_market_pressure(missing_revision_request)
	_expect(str(missing_revision.get("reason_code", "")) == "ai_business_market_pressure_source_revision_invalid", "cycle-zero requests still require an explicit source revision")
	var negative_revision_request := _request("qa:negative-revision", first_product)
	negative_revision_request["source_revision"] = -1
	var negative_revision := market.prepare_ai_business_market_pressure(negative_revision_request)
	_expect(str(negative_revision.get("reason_code", "")) == "ai_business_market_pressure_source_revision_invalid", "negative source revisions are rejected instead of clamped to cycle zero")
	var oversized_transaction_request := _request("x".repeat(161), first_product)
	var oversized_transaction := market.prepare_ai_business_market_pressure(oversized_transaction_request)
	_expect(str(oversized_transaction.get("reason_code", "")) == "ai_business_market_pressure_transaction_id_invalid", "oversized transaction identifiers cannot retain unbounded journal memory")
	var forged_region_request := _request("qa:forged-region", first_product)
	forged_region_request["public_region_id"] = "PRIVATE_AI_ROUTE"
	var forged_region := market.prepare_ai_business_market_pressure(forged_region_request)
	_expect(str(forged_region.get("reason_code", "")) == "ai_business_market_pressure_public_region_invalid", "unrecognized region text cannot enter a public market receipt")
	var route_request := _request("qa:route", first_product)
	route_request["action_kind"] = "route_sabotage"
	var route := market.prepare_ai_business_market_pressure(route_request)
	_expect(str(route.get("reason_code", "")) == "ai_business_route_sabotage_not_owned", "route sabotage remains explicitly fail-closed")
	var unknown_request := _request("qa:unknown-field", first_product)
	unknown_request["ai_reason"] = "PRIVATE"
	var unknown := market.prepare_ai_business_market_pressure(unknown_request)
	_expect(str(unknown.get("reason_code", "")) == "ai_business_market_pressure_request_field_not_allowed", "private or unknown request fields fail closed")
	_expect(_same(rng.capture_plan_checkpoint(), rng_before_rejections), "stale, malformed, unbound, unsupported, forged-region and private-field rejections consume zero RNG")
	var original_districts := world.districts.duplicate(true)
	var source_bound := market.prepare_ai_business_market_pressure(_request("qa:source-facts", first_product))
	var changed_districts := original_districts.duplicate(true)
	var changed_district := (changed_districts[0] as Dictionary).duplicate(true)
	changed_district["demands"] = [first_product, second_product]
	changed_districts[0] = changed_district
	world.replace_districts(changed_districts, true)
	var rng_before_source_reject := rng.capture_plan_checkpoint()
	var market_before_source_reject := market.runtime_state_snapshot()
	var source_stale := market.commit_ai_business_market_pressure(source_bound)
	_expect(str(source_stale.get("reason_code", "")) == "ai_business_market_pressure_source_facts_stale", "world supply-demand-weather drift invalidates a prepared market plan")
	_expect(_same(rng.capture_plan_checkpoint(), rng_before_source_reject) and _same(market.runtime_state_snapshot(), market_before_source_reject), "source-fact CAS rejection has zero RNG, market or telemetry side effect")
	world.replace_districts(original_districts, true)
	var source_cancelled := market.rollback_ai_business_market_pressure(source_bound)
	_expect(bool(source_cancelled.get("rolled_back", false)), "a source-stale prepared record can be cancelled after restoring the authoritative facts")
	_expect(int(market.ai_business_market_pressure_debug_snapshot().get("terminal_heavy_record_count", -1)) == 0, "rolled-back journal records release heavyweight rollback data")


func _case_rollback_cas_failure_blocks_new_work() -> void:
	var first_product := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	var second_product := str(ProductMarketRuntimeController.PRODUCT_CATALOG[1])
	var prepared := market.prepare_ai_business_market_pressure(_request("qa:cas", first_product))
	var committed := market.commit_ai_business_market_pressure(prepared)
	market.apply_external_pressure(second_product, 1, 0, 0, false)
	var failed := market.rollback_ai_business_market_pressure(committed)
	_expect(bool(failed.get("recovery_required", false)) and str(failed.get("reason_code", "")) == "ai_business_market_pressure_rollback_cas_failed", "rollback CAS failure enters explicit recovery-required state")
	var blocked := market.prepare_ai_business_market_pressure(_request("qa:blocked", first_product))
	_expect(bool(blocked.get("recovery_required", false)), "recovery-required state blocks subsequent market-pressure transactions")
	var debug := market.ai_business_market_pressure_debug_snapshot()
	_expect(int(debug.get("recovery_required_count", 0)) == 1 and bool(debug.get("recovery_required", false)), "bounded developer diagnostics report one recovery incident")


func _case_save_boundary_is_not_owned() -> void:
	var saved := market.to_save_data()
	var saved_text := JSON.stringify(saved).to_lower()
	_expect(not saved_text.contains("ai_business") and not saved_text.contains("transaction_id") and not saved_text.contains("rng_checkpoint"), "market-pressure journal and RNG cursor are not added to the save schema")
	_expect(not saved.has("journal") and not saved.has("telemetry_batches"), "existing ProductMarket save keys remain unchanged")
	var debug := market.ai_business_market_pressure_debug_snapshot()
	_expect(not bool(debug.get("transaction_owns_separate_market_state", true)) and not bool(debug.get("transaction_owns_cash_state", true)), "transaction diagnostics declare no second market or cash owner")
	_expect(not bool(debug.get("journal_persisted", true)), "transaction journal remains session-scoped and non-persistent")
	var source := FileAccess.get_file_as_string("res://scripts/runtime/product_market_runtime_controller.gd")
	var lifecycle_is_synchronous := true
	for method_name in [
		"prepare_ai_business_market_pressure",
		"commit_ai_business_market_pressure",
		"rollback_ai_business_market_pressure",
		"finalize_ai_business_market_pressure",
	]:
		var method_source := _method_source(source, method_name)
		if method_source.is_empty() or method_source.contains("await ") or method_source.contains("call_deferred"):
			lifecycle_is_synchronous = false
	_expect(lifecycle_is_synchronous, "market participant lifecycle is a same-call-stack contract with no await or deferred escape")


func _request(transaction_id: String, product_id: String) -> Dictionary:
	var authority := market.ai_business_market_pressure_authority_snapshot()
	return {
		"schema_version": 1,
		"transaction_id": transaction_id,
		"action_kind": "price_pump",
		"product_id": product_id,
		"public_region_id": "region-public-0",
		"source_revision": int(authority.get("market_revision", -1)),
		"expected_market_fingerprint": str(authority.get("market_fingerprint", "")),
	}


func _same(left: Variant, right: Variant) -> bool:
	var identity := SimulationStateIdentity.new()
	var left_result := identity.stable_serialize(left)
	var right_result := identity.stable_serialize(right)
	identity.free()
	return bool(left_result.get("valid", false)) and str(left_result.get("fingerprint", "")) == str(right_result.get("fingerprint", ""))


func _keys_equal(actual: Array, expected: Array) -> bool:
	var left: Array[String] = []
	var right: Array[String] = []
	for key_variant in actual:
		left.append(str(key_variant))
	for key_variant in expected:
		right.append(str(key_variant))
	left.sort()
	right.sort()
	return left == right


func _first_difference(left: Variant, right: Variant, path := "root") -> String:
	if typeof(left) != typeof(right):
		return "%s type %d != %d" % [path, typeof(left), typeof(right)]
	if left is Dictionary:
		var left_dict := left as Dictionary
		var right_dict := right as Dictionary
		var keys: Array = left_dict.keys()
		for key_variant in right_dict.keys():
			if not keys.has(key_variant):
				keys.append(key_variant)
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_variant in keys:
			if not left_dict.has(key_variant) or not right_dict.has(key_variant):
				return "%s.%s missing left=%s right=%s" % [path, str(key_variant), left_dict.has(key_variant), right_dict.has(key_variant)]
			var nested := _first_difference(left_dict[key_variant], right_dict[key_variant], "%s.%s" % [path, str(key_variant)])
			if not nested.is_empty():
				return nested
		return ""
	if left is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			return "%s size %d != %d" % [path, left_array.size(), right_array.size()]
		for index in range(left_array.size()):
			var nested := _first_difference(left_array[index], right_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return ""
	return "" if left == right else "%s %s != %s" % [path, str(left), str(right)]


func _method_source(source: String, method_name: String) -> String:
	var start := source.find("func %s(" % method_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _forbidden_terms_absent(text: String) -> bool:
	for term in ["player_index", "actor_id", "cash", "hand", "discard", "owner", "ai_plan", "ai_reason", "ai_score", "decision_samples", "learning_bonus", "rng_state", "cursor", "checkpoint", "transaction_id", "fingerprint", "private"]:
		if text.contains(term):
			return false
	return true


func _is_pure_data(value: Variant) -> bool:
	return TablePresentationPureDataPolicy.is_pure_data(value)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("AI business action transaction bench failed: %s" % label)
