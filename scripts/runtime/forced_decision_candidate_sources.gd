@tool
extends Node
class_name ForcedDecisionCandidateSources

var _monster_source: MonsterRuntimeController
var _card_resolution_source: CardResolutionRuntimeController
var _card_queue_source: Node
var _purchase_source: DistrictPurchaseRuntimeController
var _target_choice_source: CardTargetChoiceRuntimeController
var _scheduler: ForcedDecisionRuntimeScheduler
var _last_fingerprint := ""
var _last_kinds: Array[String] = []


func configure(
		monster_source: MonsterRuntimeController,
		card_resolution_source: CardResolutionRuntimeController,
		card_queue_source: Node,
		purchase_source: DistrictPurchaseRuntimeController,
		target_choice_source: CardTargetChoiceRuntimeController,
		scheduler: ForcedDecisionRuntimeScheduler
) -> void:
	_monster_source = monster_source
	_card_resolution_source = card_resolution_source
	_card_queue_source = card_queue_source
	_purchase_source = purchase_source
	_target_choice_source = target_choice_source
	_scheduler = scheduler


func synchronize() -> Dictionary:
	var candidates := collect_candidates()
	var fingerprint := JSON.stringify(candidates)
	var changed := fingerprint != _last_fingerprint
	_last_fingerprint = fingerprint
	_last_kinds = []
	for candidate_variant in candidates:
		var kind := str((candidate_variant as Dictionary).get("kind", ""))
		if not kind.is_empty():
			_last_kinds.append(kind)
	if _scheduler != null:
		_scheduler.sync_candidates(candidates)
	return {
		"synchronized": _scheduler != null,
		"changed": changed,
		"candidate_count": candidates.size(),
		"fingerprint": fingerprint.sha256_text(),
	}


func collect_candidates() -> Array:
	var result: Array = []
	if _monster_source != null:
		_append_candidates(result, _monster_source.forced_decision_candidates())
	if _card_resolution_source != null:
		var resolution_id := -1
		if _card_queue_source != null and _card_queue_source.has_method("public_snapshot"):
			var queue_variant: Variant = _card_queue_source.call("public_snapshot")
			var queue_snapshot: Dictionary = queue_variant if queue_variant is Dictionary else {}
			var active: Dictionary = queue_snapshot.get("active", {}) if queue_snapshot.get("active", {}) is Dictionary else {}
			resolution_id = int(active.get("resolution_id", -1))
		_append_candidates(result, _card_resolution_source.forced_decision_candidates(resolution_id))
	if _purchase_source != null:
		_append_candidates(result, _purchase_source.forced_decision_candidates())
	if _target_choice_source != null:
		_append_candidates(result, _target_choice_source.forced_decision_candidates())
	return result


func debug_snapshot() -> Dictionary:
	return {
		"service_authoritative": true,
		"candidate_count": _last_kinds.size(),
		"candidate_kinds": _last_kinds.duplicate(),
		"fingerprint": _last_fingerprint.sha256_text(),
		"owns_business_state": false,
	}


func _append_candidates(target: Array, source: Array) -> void:
	for candidate_variant in source:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if str(candidate.get("id", "")).is_empty() or str(candidate.get("kind", "")).is_empty():
			continue
		target.append(candidate.duplicate(true))
