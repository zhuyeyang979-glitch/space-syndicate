extends SceneTree

const ApplicationFlow := preload(
	"res://scripts/v075_runtime/v075_application_flow.gd"
)


class SuccessfulRuntimeOwner extends Node:
	func local_player_id() -> String:
		return "player.owner"

	func request_private_monster_skill(
		actor_id: String,
		_parameters: Dictionary
	) -> Dictionary:
		return {
			"accepted": true,
			"reason_code": "private_skill_safe_boundary_drained",
			"event_kind": "monster_private_skill_requested",
			"owner_player_id": actor_id,
			"source_instance_id": "monster.owner.application",
			"skill_definition_id": "skill.owner.application",
			"receipt": {
				"request_id": "request.private.internal.7",
				"asset_settlement_action": "commit",
				"cooldown_started": true,
				"batch_use_consumed": true,
			},
			"resolution_receipts": [{
				"internal_sequence": 71,
				"future_target": "facility.rival.future",
			}],
			"asset_state": {
				"players": {
					"player.rival": {
						"assets": {"technology": 987654321},
					},
				},
			},
		}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := SuccessfulRuntimeOwner.new()
	var flow := ApplicationFlow.new()
	flow.set("_runtime_owner", runtime)
	flow.set("_composition_ready", true)
	var generic_receipts: Array[Dictionary] = []
	var owner_receipts: Array[Dictionary] = []
	flow.receipt_ready.connect(func(receipt: Dictionary) -> void:
		generic_receipts.append(receipt.duplicate(true))
	)
	flow.owner_private_receipt_ready.connect(func(receipt: Dictionary) -> void:
		owner_receipts.append(receipt.duplicate(true))
	)
	var result := flow.submit_intent({
		"schema": "V075ApplicationIntentV1",
		"intent_id": "intent.private.application.001",
		"intent_kind": "combat.monster_private_skill.request",
		"ruleset_id": "v0.7.5",
		"parameters": {
			"source_instance_id": "monster.owner.application",
			"skill_definition_id": "skill.owner.application",
			"target_facility_id": "facility.rival.future",
		},
	})
	_expect(
		bool(result.get("accepted", false))
		and str(result.get("receipt_scope", "")) == "owner_private"
		and str(result.get("owner_player_id", "")) == "player.owner"
		and str(result.get("source_instance_id", ""))
			== "monster.owner.application"
		and str(result.get("skill_definition_id", ""))
			== "skill.owner.application",
		"the submitting owner receives one typed owner-private acknowledgement"
	)
	_expect(
		owner_receipts.size() == 1 and generic_receipts.is_empty(),
		"a private request never crosses the generic pre-resolution receipt signal"
	)
	var owner_text := JSON.stringify(owner_receipts[0])
	_expect(
		not owner_text.contains("resolution_receipts")
		and not owner_text.contains("request.private.internal.7")
		and not owner_text.contains("asset_settlement_action")
		and not owner_text.contains("cooldown_started")
		and not owner_text.contains("batch_use_consumed")
		and not owner_text.contains("internal_sequence")
		and not owner_text.contains("facility.rival.future")
		and not owner_text.contains("player.rival")
		and not owner_text.contains("987654321"),
		"the owner receipt is allowlisted and excludes authority, target, and rival state"
	)
	var redacted_debug := flow.get("_last_receipt") as Dictionary
	var debug_text := JSON.stringify(redacted_debug)
	_expect(
		str(redacted_debug.get("receipt_scope", ""))
			== "owner_private_redacted"
		and not debug_text.contains("monster.owner.application")
		and not debug_text.contains("skill.owner.application")
		and not debug_text.contains("combat.monster_private_skill.request"),
		"the generic application debug snapshot retains only a redaction marker"
	)
	var preflight_rejection := flow.submit_intent({
		"schema": "V075ApplicationIntentV1",
		"intent_id": "",
		"intent_kind": "combat.monster_private_skill.request",
		"ruleset_id": "v0.7.5",
		"parameters": {
			"source_instance_id": "monster.owner.application",
			"skill_definition_id": "skill.owner.application",
		},
	})
	_expect(
		not bool(preflight_rejection.get("accepted", true))
		and str(preflight_rejection.get("reason_code", ""))
			== "typed_intent_identity_invalid"
		and owner_receipts.size() == 2
		and generic_receipts.is_empty(),
		"a private preflight rejection remains on the owner-only signal"
	)
	flow.free()
	runtime.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("V075_APPLICATION_PRIVATE_SKILL_RECEIPT_PRIVACY_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
