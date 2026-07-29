extends SceneTree

## Contract-only A/B process driver skeleton. Production execution remains
## deliberately disabled until the 19-owner gateway and restore barrier land.

const FORMAL_FULL_RUN := false
const EXECUTION_READY := false
const SCHEMA_VERSION := 1
const PROCESS_ROLES := ["producer", "consumer"]
const PUBLIC_MANIFEST_FIELDS := [
	"schema_version",
	"visibility_scope",
	"run_id",
	"process_role",
	"process_id",
	"head_sha",
	"slot_id",
	"slot_state",
	"viewer_safe_state_digest",
	"rng_draw_count",
	"action_receipt_count",
	"duplicate_settlement_count",
	"elapsed_ms",
	"success",
	"failure_code",
]


func _init() -> void:
	call_deferred("_run_contract_entry")


func _run_contract_entry() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--cold-restore-contract-only"):
		print(JSON.stringify(contract_snapshot()))
		quit(0)
		return
	push_error("Cold restore vertical slice is a contract skeleton; production execution is not wired.")
	quit(2)


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"driver_id": "alpha04c_cold_restore_vertical_slice_v1",
		"formal_full_run": FORMAL_FULL_RUN,
		"execution_ready": EXECUTION_READY,
		"process_sequence": ["producer_exit", "consumer_start", "orchestrator_compare"],
		"process_roles": PROCESS_ROLES.duplicate(),
		"qa_save_root": SaveSlotPolicyV06.QA_ROOT,
		"production_slot_id": String(SaveSlotPolicyV06.PRODUCTION_SLOT_ID),
		"shares_gameplay_process_memory": false,
		"raw_envelope_in_evidence": false,
		"runtime_loop_frozen_until_restore_commit": true,
		"minimum_post_restore_ticks": 1,
	}


static func validate_options(options: Dictionary) -> Dictionary:
	var run_id := str(options.get("run_id", ""))
	var process_role := str(options.get("process_role", ""))
	if process_role not in PROCESS_ROLES:
		return {"valid": false, "reason_code": "process_role_invalid"}
	var qa_path := SaveSlotPolicyV06.qa_path(run_id, "current_run")
	if qa_path.is_empty():
		return {"valid": false, "reason_code": "run_id_invalid"}
	return {
		"valid": true,
		"reason_code": "ok",
		"process_role": process_role,
		"qa_path": qa_path,
	}


static func sanitize_public_manifest(source: Dictionary) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"visibility_scope": "qa_allowlisted",
		"run_id": str(source.get("run_id", "")),
		"process_role": str(source.get("process_role", "")),
		"process_id": maxi(0, int(source.get("process_id", 0))),
		"head_sha": str(source.get("head_sha", "")),
		"slot_id": String(SaveSlotPolicyV06.PRODUCTION_SLOT_ID),
		"slot_state": str(source.get("slot_state", "unavailable")),
		"viewer_safe_state_digest": str(source.get("viewer_safe_state_digest", "")),
		"rng_draw_count": maxi(0, int(source.get("rng_draw_count", 0))),
		"action_receipt_count": maxi(0, int(source.get("action_receipt_count", 0))),
		"duplicate_settlement_count": maxi(0, int(source.get("duplicate_settlement_count", 0))),
		"elapsed_ms": maxi(0, int(source.get("elapsed_ms", 0))),
		"success": bool(source.get("success", false)),
		"failure_code": str(source.get("failure_code", "")),
	}
	return result if _manifest_shape_valid(result) else {}


static func _manifest_shape_valid(manifest: Dictionary) -> bool:
	if manifest.size() != PUBLIC_MANIFEST_FIELDS.size():
		return false
	for field_variant in PUBLIC_MANIFEST_FIELDS:
		if not manifest.has(str(field_variant)):
			return false
	if str(manifest.get("visibility_scope", "")) != "qa_allowlisted":
		return false
	if str(manifest.get("process_role", "")) not in PROCESS_ROLES:
		return false
	if str(manifest.get("slot_state", "")) not in ["ready", "unavailable", "failed"]:
		return false
	return str(manifest.get("run_id", "")).length() <= 96 \
		and str(manifest.get("head_sha", "")).length() <= 64 \
		and str(manifest.get("viewer_safe_state_digest", "")).length() <= 128 \
		and str(manifest.get("failure_code", "")).length() <= 128
