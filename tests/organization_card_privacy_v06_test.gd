extends SceneTree

const CONTROLLER_SCRIPT := preload("res://scripts/runtime/player_organization_runtime_controller.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const HUMAN := "PRIVATE-HUMAN-ACTOR"
const RIVAL := "PRIVATE-RIVAL-ACTOR"
const FORBIDDEN_KEYS := [
	"actor_id", "owner_id", "owner", "true_owner", "hidden_owner", "owner_truth",
	"hand_limit", "ordinary_hand_limit", "asset_conversion_bonus_bp",
	"asset_conversion_bonus_cap_milli_per_second", "controlled_monster_count_limit",
	"primary_monster_rank_limit", "secondary_monster_rank_limit",
	"controlled_military_count_limit", "primary_military_rank_limit", "secondary_military_rank_limit",
	"ai_reason", "ai_utility_score", "route_plan_score", "decision_samples", "learning_bonus",
]

var _checks := 0
var _failures: Array[String] = []
var _catalog: CardRuntimeCatalogV06Resource
var _sequence := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_catalog = load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_catalog.reload()
	var owner := CONTROLLER_SCRIPT.new() as PlayerOrganizationRuntimeController
	owner.configure([HUMAN, RIVAL])
	_install(owner, HUMAN, "organization.starport_clearinghouse.rank_4")
	_install(owner, RIVAL, "organization.monster_liaison_charter.rank_4")
	var public: Dictionary = owner.public_snapshot()
	var key_paths: Array[String] = []
	_collect_forbidden_key_paths(public, "public", key_paths)
	_expect(key_paths.is_empty(), "public organization snapshot contains no private capability keys: %s" % JSON.stringify(key_paths))
	var public_text := JSON.stringify(public)
	_expect(not public_text.contains(HUMAN) and not public_text.contains(RIVAL), "public organization snapshot contains no actor identity")
	_expect(not public_text.contains("500") and not public_text.contains("2000"), "public organization snapshot contains no exact conversion multiplier")

	var own_private: Dictionary = owner.private_snapshot(HUMAN, 1)
	var rival_private: Dictionary = owner.private_snapshot(RIVAL, 1)
	_expect(str(own_private.get("actor_id", "")) == HUMAN and not JSON.stringify(own_private).contains(RIVAL), "own private snapshot identifies only its requesting actor")
	_expect(str(rival_private.get("actor_id", "")) == RIVAL and not JSON.stringify(rival_private).contains(HUMAN), "rival private snapshot remains isolated from the human actor")
	var capability: Dictionary = own_private.get("card_window_submission_capability", {}) as Dictionary
	_expect(str(capability.get("actor_id", "")) == HUMAN and not str(capability.get("capability_id", "")).is_empty(), "submission capability is private and actor-bound")
	var forged := capability.duplicate(true)
	forged["effective_submission_limit"] = 3
	_expect(not bool(owner.validate_card_window_submission_capability(forged).get("valid", true)), "a caller cannot forge an elevated submission limit")

	var debug_text := JSON.stringify(owner.debug_snapshot())
	_expect(debug_text.contains(HUMAN) and debug_text.contains(RIVAL), "owner identities remain available only in developer/private state")
	owner.free()
	_catalog = null
	_finish()


func _install(owner: PlayerOrganizationRuntimeController, actor_id: String, card_id: String) -> void:
	_sequence += 1
	var card := _catalog.card_snapshot(card_id)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var tx := "privacy-%d" % _sequence
	var intent := {
		"transaction_id": tx,
		"actor_id": actor_id,
		"card_id": card_id,
		"card_instance_id": "%s-instance" % tx,
		"effect_kind": str(machine.get("effect_kind", "")),
		"target_hash": "target-%d" % _sequence,
		"payload_hash": "payload-%d" % _sequence,
		"intent_hash": "intent-%d" % _sequence,
		"target_context": {"target_kind": "self_organization_slot", "target_actor_id": actor_id, "window_sequence": 0},
		"effect_payload": (machine.get("effect_payload", {}) as Dictionary).duplicate(true),
	}
	var prepared: Dictionary = owner.prepare_organization_upgrade(intent)
	var committed: Dictionary = owner.commit_organization_upgrade(prepared)
	owner.finalize_organization_upgrade(committed)


func _collect_forbidden_key_paths(value: Variant, path: String, output: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var next_path := "%s.%s" % [path, key]
			if key in FORBIDDEN_KEYS:
				output.append(next_path)
			_collect_forbidden_key_paths((value as Dictionary)[key_variant], next_path, output)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_forbidden_key_paths((value as Array)[index], "%s[%d]" % [path, index], output)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ORGANIZATION_CARD_PRIVACY_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("ORGANIZATION_CARD_PRIVACY_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
