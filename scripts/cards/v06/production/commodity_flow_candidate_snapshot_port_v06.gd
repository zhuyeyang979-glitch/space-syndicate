extends RefCounted
class_name CommodityFlowCandidateSnapshotPortV06

const RULESET_ID := "v0.6"

var _commodity_flow_owner: Object


func configure(commodity_flow_owner: Object) -> Dictionary:
	_commodity_flow_owner = commodity_flow_owner
	var configured := _commodity_flow_owner != null and _commodity_flow_owner.has_method("card_effect_candidates_snapshot")
	if not configured:
		_commodity_flow_owner = null
	return {
		"configured": configured,
		"reason_code": "configured" if configured else "candidate_snapshot_api_missing",
	}


func authoritative_snapshot() -> Dictionary:
	if _commodity_flow_owner == null:
		return _failure("candidate_snapshot_owner_unavailable")
	var snapshot_variant: Variant = _commodity_flow_owner.call("card_effect_candidates_snapshot")
	if not (snapshot_variant is Dictionary):
		return _failure("candidate_snapshot_invalid")
	var snapshot: Dictionary = (snapshot_variant as Dictionary).duplicate(true)
	if not bool(snapshot.get("valid", false)):
		return _failure(str(snapshot.get("reason_code", "candidate_snapshot_unavailable")))
	if int(snapshot.get("revision", -1)) < 0 or not (snapshot.get("candidates", null) is Array):
		return _failure("candidate_snapshot_contract_invalid")
	return snapshot


func refresh_planner(planner: Object) -> Dictionary:
	if planner == null or not planner.has_method("replace_authoritative_candidates"):
		return _failure("candidate_planner_api_missing")
	var snapshot := authoritative_snapshot()
	if not bool(snapshot.get("valid", false)):
		return snapshot
	var result_variant: Variant = planner.call(
		"replace_authoritative_candidates",
		int(snapshot.get("revision", -1)),
		(snapshot.get("candidates", []) as Array).duplicate(true)
	)
	if not (result_variant is Dictionary):
		return _failure("candidate_planner_refresh_invalid")
	var result: Dictionary = (result_variant as Dictionary).duplicate(true)
	if not bool(result.get("configured", false)):
		return _failure(str(result.get("reason_code", "candidate_planner_refresh_rejected")))
	return {
		"valid": true,
		"reason_code": "refreshed",
		"revision": int(snapshot.get("revision", -1)),
		"candidate_count": (snapshot.get("candidates", []) as Array).size(),
		"planner_result": result,
	}


func debug_snapshot() -> Dictionary:
	return {
		"ruleset_id": RULESET_ID,
		"configured": _commodity_flow_owner != null,
		"adapter_role": "authoritative_candidate_snapshot_port",
		"owns_candidate_state": false,
		"fallback_candidates_allowed": false,
	}


func _failure(reason_code: String) -> Dictionary:
	return {
		"valid": false,
		"reason_code": reason_code,
		"revision": -1,
		"candidates": [],
	}
