extends "res://scripts/tools/full_run_quality_driver.gd"

# This is deliberately not a terminal FullRun gate. It reuses the production
# action driver, stops at a fixed public world-time boundary, and emits one
# diagnostic record for Alpha 0.4-A continuation analysis.
const PROBE_ID := "alpha04_economy_world_time_probe_v1"
const DEFAULT_TARGET_WORLD_SECONDS := 15.0
const PRESENTATION_VISIBLE_DOCK := "visible_dock_observed"
const PRESENTATION_HIDDEN_NO_DOCK := "hidden_main_no_dock_observation"

var _probe_target_world_seconds := _environment_float(
	"ALPHA04_PROBE_TARGET_WORLD_SECONDS",
	DEFAULT_TARGET_WORLD_SECONDS,
	1.0,
	120.0
)
var _probe_claim_enabled := _environment_bool("ALPHA04_PROBE_CLAIM_ENABLED", false)
var _probe_presentation_mode := _environment_presentation_mode()
var _probe_run_label := OS.get_environment("ALPHA04_PROBE_RUN_LABEL").strip_edges()
var _probe_emitted := false
var _probe_quit_requested := false
var _probe_last_telemetry: Dictionary = {}
var _probe_phase_trace: Array[Dictionary] = []
var _probe_last_phase_signature := ""
var _probe_first_facility: Dictionary = {}
var _probe_first_sale: Dictionary = {}


func _start_fixed_seed_run(main_instance: Node, session: Node, run_seed: int) -> Dictionary:
	var result: Dictionary = await super._start_fixed_seed_run(main_instance, session, run_seed)
	if bool(result.get("started", false)) \
			and _probe_presentation_mode == PRESENTATION_HIDDEN_NO_DOCK \
			and main_instance is CanvasItem:
		(main_instance as CanvasItem).visible = false
	return result


func _request_first_public_commodity_claim(runtime_screen: Node) -> bool:
	if not _probe_claim_enabled:
		return false
	return super._request_first_public_commodity_claim(runtime_screen)


func _observe_player_card_dock(runtime_screen: Node) -> void:
	if _probe_presentation_mode == PRESENTATION_HIDDEN_NO_DOCK:
		return
	super._observe_player_card_dock(runtime_screen)


func _collect_telemetry(
	run_seed: int,
	coordinator: Node,
	session: Node,
	settlement_composition: Node,
	standings_query_port: StandingsPublicQueryPort,
	runtime_screen: Node,
	run_started_msec: int,
	last_event: String,
	ui_action_override: Variant = null
) -> Dictionary:
	var telemetry: Dictionary = super._collect_telemetry(
		run_seed,
		coordinator,
		session,
		settlement_composition,
		standings_query_port,
		runtime_screen,
		run_started_msec,
		last_event,
		ui_action_override
	)
	_probe_last_telemetry = telemetry.duplicate(true)
	_observe_probe_trace(telemetry)
	var elapsed: Dictionary = telemetry.get("elapsed", {}) \
		if telemetry.get("elapsed", {}) is Dictionary else {}
	var world_seconds := float(elapsed.get("world_seconds", 0.0))
	if not _probe_emitted and world_seconds >= _probe_target_world_seconds:
		_emit_probe_result(telemetry, "target_world_time_reached", true)
		_request_probe_quit()
	return telemetry


func _emit_heartbeat(_seed_index: int, _telemetry: Dictionary, _status: String) -> void:
	pass


func _emit_summary(_summary: Dictionary) -> void:
	if not _probe_emitted:
		_emit_probe_result(_probe_last_telemetry, "driver_exit_before_target", false)


func _emit_ndjson(_payload: Dictionary) -> void:
	# Suppress the inherited Formal FullRun stream. This probe emits exactly one
	# explicitly non-formal diagnostic record instead.
	pass


func _observe_probe_trace(telemetry: Dictionary) -> void:
	var elapsed: Dictionary = telemetry.get("elapsed", {}) \
		if telemetry.get("elapsed", {}) is Dictionary else {}
	var progress: Dictionary = telemetry.get("progress", {}) \
		if telemetry.get("progress", {}) is Dictionary else {}
	var sale: Dictionary = telemetry.get("sale_receipt", {}) \
		if telemetry.get("sale_receipt", {}) is Dictionary else {}
	var plan := _public_plan_snapshot(_latest_economy_continuation_plan)
	var sample := {
		"world_seconds": snappedf(float(elapsed.get("world_seconds", 0.0)), 0.000001),
		"phase": str(telemetry.get("phase", "")),
		"facility_count": int(progress.get("owned_facility_count", 0)),
		"sale_receipt_count": int(sale.get("public_event_count", 0)),
		"plan_reason_id": str(plan.get("reason_id", "")),
		"desired_facility_kind": str(plan.get("desired_facility_kind", "")),
		"commodity_id": str(plan.get("commodity_id", "")),
		"last_event": str(telemetry.get("last_event", "")),
	}
	var signature := JSON.stringify({
		"facility_count": sample.get("facility_count", 0),
		"sale_receipt_count": sample.get("sale_receipt_count", 0),
		"plan_reason_id": sample.get("plan_reason_id", ""),
		"desired_facility_kind": sample.get("desired_facility_kind", ""),
		"commodity_id": sample.get("commodity_id", ""),
	}).sha256_text()
	if signature != _probe_last_phase_signature:
		_probe_last_phase_signature = signature
		_probe_phase_trace.append(sample)
		if _probe_phase_trace.size() > 40:
			_probe_phase_trace.pop_front()
	if _probe_first_facility.is_empty() and int(progress.get("owned_facility_count", 0)) > 0:
		_probe_first_facility = {
			"world_seconds": sample.get("world_seconds", 0.0),
			"facility_count": int(progress.get("owned_facility_count", 0)),
			"public_facilities": _public_facility_rows(
				_latest_economy_continuation_observation.get("facility_rows", [])
			),
			"plan": plan,
		}
	if _probe_first_sale.is_empty() and bool(sale.get("observed", false)):
		_probe_first_sale = {
			"observed_at_world_seconds": sample.get("world_seconds", 0.0),
			"first_world_seconds": snappedf(
				float(sale.get("first_world_seconds", sample.get("world_seconds", 0.0))),
				0.000001
			),
			"public_event_count": int(sale.get("public_event_count", 0)),
			"public_fingerprint": str(sale.get("public_fingerprint", "")),
		}


func _emit_probe_result(telemetry: Dictionary, reason_id: String, target_reached: bool) -> void:
	if _probe_emitted:
		return
	_probe_emitted = true
	var elapsed: Dictionary = telemetry.get("elapsed", {}) \
		if telemetry.get("elapsed", {}) is Dictionary else {}
	var progress: Dictionary = telemetry.get("progress", {}) \
		if telemetry.get("progress", {}) is Dictionary else {}
	var sale: Dictionary = telemetry.get("sale_receipt", {}) \
		if telemetry.get("sale_receipt", {}) is Dictionary else {}
	var wall_seconds := maxf(0.0, float(elapsed.get("wall_seconds", 0.0)))
	var world_seconds := maxf(0.0, float(elapsed.get("world_seconds", 0.0)))
	var reasons: Dictionary = _action_stats.get("reason_codes", {}) \
		if _action_stats.get("reason_codes", {}) is Dictionary else {}
	var result := {
		"schema_version": 1,
		"probe_id": PROBE_ID,
		"formal_full_run": false,
		"terminal_settlement_required": false,
		"run_label": _probe_run_label,
		"reason_id": reason_id,
		"target_reached": target_reached,
		"seed": int(telemetry.get("seed", 900626424)),
		"target_world_seconds": _probe_target_world_seconds,
		"early_commodity_claim_enabled": _probe_claim_enabled,
		"presentation_mode": _probe_presentation_mode,
		"wall_seconds": snappedf(wall_seconds, 0.001),
		"world_seconds": snappedf(world_seconds, 0.000001),
		"world_seconds_per_wall_second": snappedf(
			world_seconds / wall_seconds if wall_seconds > 0.0 else 0.0,
			0.000001
		),
		"first_facility": _probe_first_facility.duplicate(true),
		"first_sale": _probe_first_sale.duplicate(true),
		"final_facility_count": int(progress.get("owned_facility_count", 0)),
		"final_production_installation_count": int(
			progress.get("production_installation_count", 0)
		),
		"final_sale_receipt_count": int(sale.get("public_event_count", 0)),
		"final_top_k_gdp_per_minute": int(progress.get("top_k_gdp_per_minute", 0)),
		"final_plan": _public_plan_snapshot(_latest_economy_continuation_plan),
		"actions": {
			"attempted": int(_action_stats.get("attempted", 0)),
			"progressed": int(_action_stats.get("progressed", 0)),
			"rejected_invalid": int(_action_stats.get("rejected_invalid", 0)),
			"supply_rack_rotations": int(_action_stats.get("supply_rack_rotations", 0)),
			"supply_rack_advancement_purchases": int(
				_action_stats.get("supply_rack_advancement_purchases", 0)
			),
			"pending_discard_reason_count": int(reasons.get("district_supply_pending_discard", 0)),
			"reason_codes": reasons.duplicate(true),
		},
		"claim": {
			"request_count": int(_action_stats.get("commodity_claim_request_count", 0)),
			"succeeded": bool(_action_stats.get("direct_commodity_claim_succeeded", false)),
			"duplicate_count": int(_action_stats.get("duplicate_commodity_claim_count", 0)),
		},
		"dock_refresh_count": int(_action_stats.get("player_card_dock_refresh_count", 0)),
		"phase_trace": _probe_phase_trace.duplicate(true),
	}
	print("ALPHA04_ECONOMY_WORLD_TIME_PROBE|%s" % JSON.stringify(result))


func _request_probe_quit() -> void:
	if _probe_quit_requested:
		return
	_probe_quit_requested = true
	call_deferred("_quit_probe")


func _quit_probe() -> void:
	quit(0)


static func _public_plan_snapshot(plan_variant: Variant) -> Dictionary:
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	return {
		"ready": bool(plan.get("ready", false)),
		"stop": bool(plan.get("stop", true)),
		"reason_id": str(plan.get("reason_id", "")),
		"desired_facility_kind": str(plan.get("desired_facility_kind", "")),
		"desired_direction": str(plan.get("desired_direction", "")),
		"commodity_id": str(plan.get("commodity_id", "")),
		"industry_id": str(plan.get("industry_id", "")),
	}


static func _public_facility_rows(rows_variant: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (rows_variant is Array):
		return result
	for row_variant in rows_variant as Array:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		result.append({
			"facility_kind": str(row.get("facility_kind", "")),
			"direction": str(row.get("direction", "")),
			"commodity_id": str(row.get("commodity_id", "")),
			"industry_id": str(row.get("industry_id", "")),
			"region_id": str(row.get("region_id", "")),
		})
	return result


static func _environment_float(key: String, fallback: float, minimum: float, maximum: float) -> float:
	var text := OS.get_environment(key).strip_edges()
	if not text.is_valid_float():
		return fallback
	return clampf(text.to_float(), minimum, maximum)


static func _environment_bool(key: String, fallback: bool) -> bool:
	var text := OS.get_environment(key).strip_edges().to_lower()
	if text in ["1", "true", "yes", "on"]:
		return true
	if text in ["0", "false", "no", "off"]:
		return false
	return fallback


static func _environment_presentation_mode() -> String:
	var value := OS.get_environment("ALPHA04_PROBE_PRESENTATION_MODE").strip_edges()
	return value if value in [PRESENTATION_VISIBLE_DOCK, PRESENTATION_HIDDEN_NO_DOCK] \
		else PRESENTATION_VISIBLE_DOCK
