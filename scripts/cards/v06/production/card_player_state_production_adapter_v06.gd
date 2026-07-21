@tool
extends Node
class_name CardPlayerStateProductionAdapterV06

## Production CardPlayerStatePortV06 adapter.
##
## The world player's `slots`, `cash`, `card_purchase_count`, and
## `total_card_spend` fields and PlayerManaRuntimeController's six coloured pools
## remain authoritative.  This adapter stores only locks, idempotency receipts
## and per-player CAS metadata.  A commit is expressed as an exact delta from the
## reserved snapshot, so cash income, other public spending, and asset recovery
## that happen while a transaction is reserved are never overwritten.

const RULESET_ID := "v0.6"
const STATE_VERSION := 1
const HAND_LIMIT := 5
const ASSET_IDS: Array[String] = [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const META_REVISION := "card_player_state_v06_revision"
const META_FINGERPRINT := "card_player_state_v06_observed_fingerprint"
const ASSET_TRANSACTION_PREFIX := "card-player-state-v06"

var _catalog: Resource
var _asset_controller: Node
var _world_session_state: WorldSessionState
var _cash_commitment_query_port: MonsterWagerCashCommitmentQueryPort
var _configured := false
var _reservations: Dictionary = {}
var _prepared_mutations: Dictionary = {}
var _player_locks: Dictionary = {}
var _inflight_transactions: Dictionary = {}
var _journal: Dictionary = {}
var _reservation_results: Dictionary = {}
var _bankruptcy_estate_journal: Dictionary = {}
var _next_reservation_sequence := 1
var _reserve_count := 0
var _commit_count := 0
var _abort_count := 0
var _reject_count := 0
var _last_reason_code := ""


func configure(catalog: Resource, asset_controller: Node) -> Dictionary:
	_catalog = catalog
	_asset_controller = asset_controller
	_configured = _catalog != null and _asset_owner_ready()
	return {
		"configured": _configured,
		"reason_code": "configured" if _configured else "production_owner_missing",
		"stores_inventory": false,
		"stores_cash": false,
		"stores_assets": false,
		"monster_wager_cash_commitment_guard_bound": _cash_commitment_query_port != null,
	}


func set_world_session_state(state: WorldSessionState) -> Dictionary:
	_world_session_state = state
	return {
		"bound": _world_has_players(),
		"reason_code": "world_session_state_bound" if _world_has_players() else "production_world_missing",
	}


func set_cash_commitment_query_port(port: MonsterWagerCashCommitmentQueryPort) -> Dictionary:
	_cash_commitment_query_port = port
	return {
		"bound": _cash_commitment_query_port != null,
		"reason_code": "monster_wager_cash_commitment_query_bound" if _cash_commitment_query_port != null else "monster_wager_cash_commitment_query_missing",
	}


func reset_state() -> void:
	_reservations.clear()
	_prepared_mutations.clear()
	_player_locks.clear()
	_inflight_transactions.clear()
	_journal.clear()
	_reservation_results.clear()
	_bankruptcy_estate_journal.clear()
	_next_reservation_sequence = 1
	_reserve_count = 0
	_commit_count = 0
	_abort_count = 0
	_reject_count = 0
	_last_reason_code = ""


func bankruptcy_estate_stage(stage: String, request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var player_indices: Array = request.get("player_indices", []) if request.get("player_indices", []) is Array else []
	if transaction_id.is_empty() or player_indices.is_empty() or not ["prepare", "commit", "rollback", "finalize"].has(stage):
		return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_request_invalid")
	var existing: Dictionary = _bankruptcy_estate_journal.get(transaction_id, {}) if _bankruptcy_estate_journal.get(transaction_id, {}) is Dictionary else {}
	if not existing.is_empty():
		var existing_players: Array = existing.get("player_indices", []) if existing.get("player_indices", []) is Array else []
		if existing_players != player_indices:
			return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_transaction_collision")
	match stage:
		"prepare":
			if not existing.is_empty():
				return _bankruptcy_estate_result("prepare", existing, true)
			var players := _world_players()
			var preimage: Dictionary = {}
			var postimage: Dictionary = {}
			var removed := 0
			for player_index_variant in player_indices:
				var player_index := int(player_index_variant)
				if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
					return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_player_missing")
				var before: Dictionary = (players[player_index] as Dictionary).duplicate(true)
				var actor_id := _actor_id(player_index, before)
				if _player_locks.has(actor_id):
					return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_transaction_inflight")
				var after := before.duplicate(true)
				var slots: Array = before.get("slots", []) if before.get("slots", []) is Array else []
				for slot_variant in slots:
					if slot_variant is Dictionary:
						removed += 1
				after["slots"] = []
				after["eliminated"] = true
				after["eliminated_at"] = maxf(0.0, float(request.get("occurred_at", 0.0)))
				after["elimination_reason"] = str(request.get("reason_code", "atomic_settlement"))
				after["queued_card_tip"] = 0
				after["action_cooldown"] = 0.0
				after[META_REVISION] = maxi(0, int(before.get(META_REVISION, 0))) + 1
				after[META_FINGERPRINT] = ""
				preimage[str(player_index)] = before
				postimage[str(player_index)] = after
			existing = {
				"state": "prepared",
				"player_indices": player_indices.duplicate(),
				"preimage": preimage,
				"postimage": postimage,
				"estate_counts": {"hand_cards_removed": removed},
			}
			_bankruptcy_estate_journal[transaction_id] = existing
			return _bankruptcy_estate_result(stage, existing, false)
		"commit":
			if existing.is_empty():
				return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_prepare_missing")
			if str(existing.get("state", "")) in ["committed", "finalized"]:
				return _bankruptcy_estate_result(stage, existing, true)
			if str(existing.get("state", "")) != "prepared":
				return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_state_invalid")
			var players := _world_players()
			var preimage: Dictionary = existing.get("preimage", {}) if existing.get("preimage", {}) is Dictionary else {}
			var postimage: Dictionary = existing.get("postimage", {}) if existing.get("postimage", {}) is Dictionary else {}
			for player_index_variant in player_indices:
				var player_index := int(player_index_variant)
				if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
					return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_player_missing")
				if _stable_hash(players[player_index]) != _stable_hash(preimage.get(str(player_index), {})):
					return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_revision_changed")
				players[player_index] = (postimage.get(str(player_index), {}) as Dictionary).duplicate(true)
			_write_world_players(players)
			existing["state"] = "committed"
			_bankruptcy_estate_journal[transaction_id] = existing
			return _bankruptcy_estate_result(stage, existing, false)
		"rollback":
			if existing.is_empty():
				return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_prepare_missing")
			if str(existing.get("state", "")) == "rolled_back":
				return _bankruptcy_estate_result(stage, existing, true)
			if str(existing.get("state", "")) == "finalized":
				return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_already_finalized")
			if str(existing.get("state", "")) == "committed":
				var players := _world_players()
				var preimage: Dictionary = existing.get("preimage", {}) if existing.get("preimage", {}) is Dictionary else {}
				for player_index_variant in player_indices:
					var player_index := int(player_index_variant)
					if player_index >= 0 and player_index < players.size() and preimage.get(str(player_index), {}) is Dictionary:
						players[player_index] = (preimage[str(player_index)] as Dictionary).duplicate(true)
				_write_world_players(players)
			existing["state"] = "rolled_back"
			_bankruptcy_estate_journal[transaction_id] = existing
			return _bankruptcy_estate_result(stage, existing, false)
		"finalize":
			if existing.is_empty() or not (str(existing.get("state", "")) in ["committed", "finalized"]):
				return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_commit_missing")
			var duplicate := str(existing.get("state", "")) == "finalized"
			existing["state"] = "finalized"
			existing.erase("preimage")
			existing.erase("postimage")
			_bankruptcy_estate_journal[transaction_id] = existing
			return _bankruptcy_estate_result(stage, existing, duplicate)
	return _bankruptcy_estate_failure(stage, "card_player_bankruptcy_stage_invalid")


func _bankruptcy_estate_result(stage: String, record: Dictionary, duplicate: bool) -> Dictionary:
	return {
		"prepared": stage == "prepare",
		"committed": stage == "commit",
		"rolled_back": stage == "rollback",
		"finalized": stage == "finalize",
		"duplicate": duplicate,
		"reason_code": "card_player_bankruptcy_%s" % stage,
		"estate_counts": (record.get("estate_counts", {}) as Dictionary).duplicate(true) if record.get("estate_counts", {}) is Dictionary else {},
	}


func _bankruptcy_estate_failure(stage: String, reason_code: String) -> Dictionary:
	return {"prepared": false, "committed": false, "rolled_back": false, "finalized": false, "stage": stage, "reason_code": reason_code, "estate_counts": {}}


func actor_player_indices() -> Dictionary:
	var result: Dictionary = {}
	var players := _world_players()
	for player_index in range(players.size()):
		if players[player_index] is Dictionary:
			result[_actor_id(player_index, players[player_index] as Dictionary)] = player_index
	return result


func register_player(actor_id: String, _initial_state: Dictionary) -> Dictionary:
	var read := read_player(actor_id)
	if not bool(read.get("found", false)):
		var rejected := read.duplicate(true)
		rejected["configured"] = false
		return rejected
	return {
		"configured": true,
		"reason_code": "production_player_registered",
		"player_state": (read.get("player_state", {}) as Dictionary).duplicate(true),
	}


func read_player(actor_id: String) -> Dictionary:
	if not _service_ready():
		return _reject("production_owner_missing", {"found": false})
	var player_index := _player_index(actor_id)
	if player_index < 0:
		return _reject("actor_id_invalid", {"found": false})
	var players := _world_players()
	if player_index >= players.size() or not (players[player_index] is Dictionary):
		return _reject("player_missing", {"found": false})
	var player := (players[player_index] as Dictionary).duplicate(true)
	_ensure_world_instance_ids(player_index, player)
	var assets_result := _asset_snapshot(player_index)
	if not bool(assets_result.get("valid", false)):
		return _reject("asset_owner_unavailable", {"found": false})
	var assets: Dictionary = assets_result.get("assets", {}) as Dictionary
	var inventory := _canonical_inventory(player)
	var fingerprint := _resource_fingerprint(player, inventory, assets)
	var revision := maxi(0, int(player.get(META_REVISION, 0)))
	var observed := str(player.get(META_FINGERPRINT, ""))
	if observed.is_empty():
		player[META_FINGERPRINT] = fingerprint
	elif observed != fingerprint:
		revision += 1
		player[META_REVISION] = revision
		player[META_FINGERPRINT] = fingerprint
	players[player_index] = player
	_write_world_players(players)
	return {
		"found": true,
		"reason_code": "player_ready",
		"player_state": _state_snapshot(actor_id, player, inventory, assets, revision),
	}


func reserve_transaction(
	transaction_id: String,
	intent_hash: String,
	expected_revisions: Dictionary,
	actor_ids: Array
) -> Dictionary:
	_reserve_count += 1
	var tx := transaction_id.strip_edges()
	var intent := intent_hash.strip_edges()
	if tx.is_empty():
		return _reject("transaction_id_missing")
	if intent.is_empty():
		return _reject("intent_hash_missing", {"transaction_id": tx})
	if _journal.has(tx):
		return _journal_replay(tx, intent, true)
	var normalized := _normalize_reservation_request(expected_revisions, actor_ids)
	if not bool(normalized.get("valid", false)):
		return _remember_reserve_reject(tx, intent, str(normalized.get("reason_code", "reservation_request_invalid")))
	var normalized_actor_ids: Array = normalized.get("actor_ids", []) as Array
	var revisions: Dictionary = normalized.get("expected_revisions", {}) as Dictionary
	var signature := _stable_hash({"actor_ids": normalized_actor_ids, "expected_revisions": revisions})
	if _inflight_transactions.has(tx):
		var inflight: Dictionary = _inflight_transactions.get(tx, {}) as Dictionary
		if str(inflight.get("intent_hash", "")) != intent or str(inflight.get("request_signature", "")) != signature:
			return _reject("transaction_intent_collision", {"transaction_id": tx})
		var existing_id := str(inflight.get("reservation_id", ""))
		if _reservations.has(existing_id):
			return _reservation_result(_reservations.get(existing_id, {}) as Dictionary, true)
		return _reject("reservation_lost", {"transaction_id": tx})

	var before_snapshots: Dictionary = {}
	var before_inventory_fingerprints: Dictionary = {}
	for actor_variant in normalized_actor_ids:
		var actor_id := str(actor_variant)
		if _player_locks.has(actor_id):
			return _remember_reserve_reject(tx, intent, "player_busy", {"actor_id": actor_id})
		var read := read_player(actor_id)
		if not bool(read.get("found", false)):
			return _remember_reserve_reject(tx, intent, str(read.get("reason_code", "player_missing")), {"actor_id": actor_id})
		var state: Dictionary = read.get("player_state", {}) as Dictionary
		if int(state.get("revision", -1)) != int(revisions.get(actor_id, -2)):
			return _remember_reserve_reject(tx, intent, "player_revision_changed", {"actor_id": actor_id})
		before_snapshots[actor_id] = state.duplicate(true)
		before_inventory_fingerprints[actor_id] = _stable_hash(state.get("inventory", {}))

	var reservation_id := "production-player-state:%d:%s" % [_next_reservation_sequence, tx]
	_next_reservation_sequence += 1
	var reservation := {
		"reservation_id": reservation_id,
		"transaction_id": tx,
		"intent_hash": intent,
		"request_signature": signature,
		"actor_ids": normalized_actor_ids.duplicate(),
		"expected_revisions": revisions.duplicate(true),
		"before_snapshots": before_snapshots.duplicate(true),
		"before_inventory_fingerprints": before_inventory_fingerprints.duplicate(true),
	}
	_reservations[reservation_id] = reservation.duplicate(true)
	_inflight_transactions[tx] = {
		"intent_hash": intent,
		"request_signature": signature,
		"reservation_id": reservation_id,
	}
	for actor_variant in normalized_actor_ids:
		_player_locks[str(actor_variant)] = reservation_id
	return _reservation_result(reservation, false)


func prepare_reserved_mutations(reservation_id: String, next_states: Dictionary) -> Dictionary:
	var normalized_id := reservation_id.strip_edges()
	if normalized_id.is_empty():
		return _reject("reservation_id_missing")
	if not _reservations.has(normalized_id):
		return _reject("reservation_missing", {"reservation_id": normalized_id})
	var reservation: Dictionary = _reservations.get(normalized_id, {}) as Dictionary
	var next_hash := _stable_hash(next_states)
	if _prepared_mutations.has(normalized_id):
		var existing: Dictionary = _prepared_mutations.get(normalized_id, {}) as Dictionary
		if str(existing.get("next_states_hash", "")) != next_hash:
			return _commit_reject(reservation, "prepared_mutation_collision")
		var replay := _compact_prepared_result(existing)
		replay["idempotent_replay"] = true
		return replay

	var actor_ids: Array = reservation.get("actor_ids", []) as Array
	if next_states.size() != actor_ids.size():
		return _commit_reject(reservation, "next_states_mismatch")
	var normalized_next: Dictionary = {}
	for actor_variant in actor_ids:
		var actor_id := str(actor_variant)
		if not next_states.has(actor_id) or str(_player_locks.get(actor_id, "")) != normalized_id:
			return _commit_reject(reservation, "reservation_lost", {"actor_id": actor_id})
		var next_variant: Variant = next_states.get(actor_id)
		if not (next_variant is Dictionary):
			return _commit_reject(reservation, "next_state_invalid", {"actor_id": actor_id})
		var checked := _normalize_next_state(actor_id, next_variant as Dictionary)
		if not bool(checked.get("valid", false)):
			return _commit_reject(reservation, str(checked.get("reason_code", "next_state_invalid")), {"actor_id": actor_id})
		normalized_next[actor_id] = (checked.get("player_state", {}) as Dictionary).duplicate(true)

	var candidate_players := _world_players()
	_ensure_all_world_instance_ids(candidate_players)
	var global_cards := _world_cards_by_instance(candidate_players)
	var before_snapshots: Dictionary = reservation.get("before_snapshots", {}) as Dictionary
	var rows: Dictionary = {}
	var asset_plans: Array = []
	for actor_variant in actor_ids:
		var actor_id := str(actor_variant)
		var player_index := _player_index(actor_id)
		if player_index < 0 or player_index >= candidate_players.size() or not (candidate_players[player_index] is Dictionary):
			return _commit_reject(reservation, "player_missing", {"actor_id": actor_id})
		var current_player := (candidate_players[player_index] as Dictionary).duplicate(true)
		_ensure_world_instance_ids(player_index, current_player)
		var current_assets_result := _asset_snapshot(player_index)
		if not bool(current_assets_result.get("valid", false)):
			return _commit_reject(reservation, "asset_owner_unavailable", {"actor_id": actor_id})
		var current_inventory := _canonical_inventory(current_player)
		var before: Dictionary = before_snapshots.get(actor_id, {}) as Dictionary
		if _stable_hash(current_inventory) != _stable_hash(before.get("inventory", {})):
			return _commit_reject(reservation, "inventory_changed", {"actor_id": actor_id})
		var proposed: Dictionary = normalized_next.get(actor_id, {}) as Dictionary
		var cash_delta := int(proposed.get("cash", 0)) - int(before.get("cash", 0))
		if cash_delta < 0 and _cash_commitment_query_port != null:
			var authorization := _cash_commitment_query_port.authorize_debit_units(player_index, -cash_delta)
			if not bool(authorization.get("authorized", false)):
				return _commit_reject(reservation, str(authorization.get("reason_code", "cash_reserved_for_monster_wager")), {"actor_id": actor_id})
		if _cash_units(current_player) + cash_delta < 0:
			return _commit_reject(reservation, "cash_insufficient", {"actor_id": actor_id})
		var purchase_count_delta := int(proposed.get("card_purchase_count", 0)) - int(before.get("card_purchase_count", 0))
		var spend_delta := int(proposed.get("total_card_spend", 0)) - int(before.get("total_card_spend", 0))
		if purchase_count_delta < 0 or spend_delta < 0:
			return _commit_reject(reservation, "purchase_ledger_delta_invalid", {"actor_id": actor_id})
		var asset_delta := _asset_delta(before.get("assets", {}) as Dictionary, proposed.get("assets", {}) as Dictionary)
		if not bool(asset_delta.get("valid", false)):
			return _commit_reject(reservation, str(asset_delta.get("reason_code", "assets_invalid")), {"actor_id": actor_id})
		var credit: Dictionary = asset_delta.get("credit", {}) as Dictionary
		if _asset_total(credit) > 0:
			return _commit_reject(reservation, "asset_credit_owner_unavailable", {"actor_id": actor_id})
		var debit: Dictionary = asset_delta.get("debit", {}) as Dictionary
		var asset_transaction_id := ""
		if _asset_total(debit) > 0:
			asset_transaction_id = "%s:%s:%s" % [ASSET_TRANSACTION_PREFIX, str(reservation.get("transaction_id", "")), actor_id]
			var plan_variant: Variant = _asset_controller.call("plan_reservation", {
				"player_index": player_index,
				"asset_cost": debit.duplicate(true),
				"generic_asset_allocation": {},
				"transaction_id": asset_transaction_id,
			})
			if not (plan_variant is Dictionary) or not bool((plan_variant as Dictionary).get("accepted", false)):
				return _commit_reject(reservation, "assets_insufficient", {"actor_id": actor_id})
			asset_plans.append({"actor_id": actor_id, "transaction_id": asset_transaction_id, "plan": (plan_variant as Dictionary).duplicate(true)})
		var proposed_inventory: Dictionary = proposed.get("inventory", {}) as Dictionary
		var candidate := current_player.duplicate(true)
		candidate["cash"] = _cash_units(current_player) + cash_delta
		candidate["slots"] = _world_slots_from_inventory(proposed_inventory, global_cards)
		candidate["card_purchase_count"] = int(current_player.get("card_purchase_count", 0)) + purchase_count_delta
		candidate["total_card_spend"] = int(current_player.get("total_card_spend", 0)) + spend_delta
		candidate_players[player_index] = candidate
		rows[actor_id] = {
			"player_index": player_index,
			"cash_delta": cash_delta,
			"purchase_count_delta": purchase_count_delta,
			"spend_delta": spend_delta,
			"asset_debit": debit.duplicate(true),
			"asset_credit": credit.duplicate(true),
			"asset_transaction_id": asset_transaction_id,
			"before_inventory_hash": _stable_hash(current_inventory),
			"proposed_inventory": proposed_inventory.duplicate(true),
		}

	var identity_check := _validate_global_world_instances(candidate_players)
	if not bool(identity_check.get("valid", false)):
		return _commit_reject(reservation, str(identity_check.get("reason_code", "card_instance_duplicate_global")))
	if not asset_plans.is_empty() and not _asset_rollback_ready():
		return _commit_reject(reservation, "asset_atomic_owner_unavailable")
	var committed_asset_transactions: Array[String] = []
	for row_variant in asset_plans:
		var asset_row: Dictionary = row_variant as Dictionary
		var commit_variant: Variant = _asset_controller.call("commit_reservation", (asset_row.get("plan", {}) as Dictionary).duplicate(true))
		if not (commit_variant is Dictionary) or not bool((commit_variant as Dictionary).get("committed", false)):
			_release_asset_reservations(committed_asset_transactions, "player_state_prepare_rejected")
			return _commit_reject(reservation, "asset_reservation_commit_failed", {"actor_id": str(asset_row.get("actor_id", ""))})
		committed_asset_transactions.append(str(asset_row.get("transaction_id", "")))

	var stage := {
		"prepared": true,
		"reservation_id": normalized_id,
		"transaction_id": str(reservation.get("transaction_id", "")),
		"intent_hash": str(reservation.get("intent_hash", "")),
		"next_states_hash": next_hash,
		"actor_ids": actor_ids.duplicate(),
		"rows": rows.duplicate(true),
		"asset_transaction_ids": committed_asset_transactions.duplicate(),
	}
	_prepared_mutations[normalized_id] = stage.duplicate(true)
	return _compact_prepared_result(stage)


func commit_reserved(reservation_id: String, next_states: Dictionary, effect_receipt: Dictionary) -> Dictionary:
	_commit_count += 1
	var normalized_id := reservation_id.strip_edges()
	if normalized_id.is_empty():
		return _reject("reservation_id_missing")
	if _reservation_results.has(normalized_id):
		var terminal: Dictionary = (_reservation_results.get(normalized_id, {}) as Dictionary).duplicate(true)
		terminal["idempotent_replay"] = true
		terminal["replayed"] = true
		return terminal
	if not _reservations.has(normalized_id):
		return _reject("reservation_missing", {"reservation_id": normalized_id})
	var reservation: Dictionary = _reservations.get(normalized_id, {}) as Dictionary
	var tx := str(reservation.get("transaction_id", ""))
	var intent := str(reservation.get("intent_hash", ""))
	if not bool(effect_receipt.get("committed", false)):
		return _commit_reject(reservation, "effect_not_committed")
	if effect_receipt.has("transaction_id") and str(effect_receipt.get("transaction_id", "")) != tx:
		return _commit_reject(reservation, "effect_receipt_mismatch")
	if effect_receipt.has("intent_hash") and str(effect_receipt.get("intent_hash", "")) != intent:
		return _commit_reject(reservation, "effect_receipt_mismatch")
	if not _prepared_mutations.has(normalized_id):
		var lazy_prepare := prepare_reserved_mutations(normalized_id, next_states)
		if not bool(lazy_prepare.get("prepared", false)):
			return lazy_prepare
	var stage: Dictionary = _prepared_mutations.get(normalized_id, {}) as Dictionary
	if str(stage.get("next_states_hash", "")) != _stable_hash(next_states):
		return _commit_reject(reservation, "prepared_mutation_collision")

	var actor_ids: Array = stage.get("actor_ids", []) as Array
	var rows: Dictionary = stage.get("rows", {}) as Dictionary
	var expected_revisions: Dictionary = reservation.get("expected_revisions", {}) as Dictionary
	var candidate_players := _world_players()
	_ensure_all_world_instance_ids(candidate_players)
	var global_cards := _world_cards_by_instance(candidate_players)
	for actor_variant in actor_ids:
		var actor_id := str(actor_variant)
		var row: Dictionary = rows.get(actor_id, {}) as Dictionary
		var player_index := int(row.get("player_index", -1))
		if player_index < 0 or player_index >= candidate_players.size() or not (candidate_players[player_index] is Dictionary):
			return _commit_reject(reservation, "player_missing", {"actor_id": actor_id})
		var current_player := (candidate_players[player_index] as Dictionary).duplicate(true)
		_ensure_world_instance_ids(player_index, current_player)
		var current_inventory := _canonical_inventory(current_player)
		if _stable_hash(current_inventory) != str(row.get("before_inventory_hash", "")):
			return _commit_reject(reservation, "inventory_changed", {"actor_id": actor_id})
		var current_assets_result := _asset_snapshot(player_index)
		if not bool(current_assets_result.get("valid", false)):
			return _commit_reject(reservation, "asset_owner_unavailable", {"actor_id": actor_id})
		var available_assets: Dictionary = current_assets_result.get("assets", {}) as Dictionary
		var visible_assets := available_assets.duplicate(true)
		var debit: Dictionary = row.get("asset_debit", {}) as Dictionary
		# availability_snapshot excludes our reservation. Add it back only for
		# external-change detection; the final balance after consume is `available`.
		for asset_id in ASSET_IDS:
			visible_assets[asset_id] = int(visible_assets.get(asset_id, 0)) + int(debit.get(asset_id, 0))
		var cash_delta := int(row.get("cash_delta", 0))
		if cash_delta < 0 and _cash_commitment_query_port != null:
			var authorization := _cash_commitment_query_port.authorize_debit_units(player_index, -cash_delta)
			if not bool(authorization.get("authorized", false)):
				return _commit_reject(reservation, str(authorization.get("reason_code", "cash_reserved_for_monster_wager")), {"actor_id": actor_id})
		if _cash_units(current_player) + cash_delta < 0:
			return _commit_reject(reservation, "cash_insufficient", {"actor_id": actor_id})
		var purchase_count_delta := int(row.get("purchase_count_delta", 0))
		var spend_delta := int(row.get("spend_delta", 0))
		if purchase_count_delta < 0 or spend_delta < 0:
			return _commit_reject(reservation, "purchase_ledger_delta_invalid", {"actor_id": actor_id})
		var observed_fingerprint := _resource_fingerprint(current_player, current_inventory, visible_assets)
		var current_revision := maxi(0, int(current_player.get(META_REVISION, 0)))
		if str(current_player.get(META_FINGERPRINT, "")) != observed_fingerprint:
			current_revision += 1
		# The production economy settles in cents. Card prices are whole cash
		# units, so apply the exact integer delta in cents and preserve any
		# fractional remainder earned by commodity flow.
		var next_cash_cents := _cash_cents(current_player) + cash_delta * 100
		current_player["cash_cents"] = next_cash_cents
		current_player["cash"] = floori(float(next_cash_cents) / 100.0)
		current_player["slots"] = _world_slots_from_inventory(row.get("proposed_inventory", {}) as Dictionary, global_cards)
		current_player["card_purchase_count"] = int(current_player.get("card_purchase_count", 0)) + purchase_count_delta
		current_player["total_card_spend"] = int(current_player.get("total_card_spend", 0)) + spend_delta
		current_player[META_REVISION] = maxi(current_revision, int(expected_revisions.get(actor_id, 0))) + 1
		candidate_players[player_index] = current_player

	var identity_check := _validate_global_world_instances(candidate_players)
	if not bool(identity_check.get("valid", false)):
		return _commit_reject(reservation, str(identity_check.get("reason_code", "card_instance_duplicate_global")))
	var asset_transaction_ids: Array = stage.get("asset_transaction_ids", []) as Array
	var asset_before: Dictionary = {}
	if not asset_transaction_ids.is_empty():
		asset_before = (_asset_controller.call("to_save_data") as Dictionary).duplicate(true)
	for transaction_variant in asset_transaction_ids:
		var asset_transaction_id := str(transaction_variant)
		var consume_variant: Variant = _asset_controller.call("consume_reservation", asset_transaction_id, effect_receipt.duplicate(true))
		if not (consume_variant is Dictionary) or not bool((consume_variant as Dictionary).get("committed", false)):
			var rollback_variant: Variant = _asset_controller.call("apply_save_data", asset_before.duplicate(true))
			if not (rollback_variant is Dictionary) or not bool((rollback_variant as Dictionary).get("applied", false)):
				return _commit_reject(reservation, "asset_atomic_rollback_failed")
			_release_asset_reservations(_string_array(asset_transaction_ids), "player_state_consume_rejected")
			return _commit_reject(reservation, "asset_consume_failed")

	_write_world_players(candidate_players)
	var final_players := _world_players()
	var player_states: Dictionary = {}
	var revision_vector: Dictionary = {}
	var mutations: Dictionary = {}
	for actor_variant in actor_ids:
		var actor_id := str(actor_variant)
		var row: Dictionary = rows.get(actor_id, {}) as Dictionary
		var player_index := int(row.get("player_index", -1))
		var player := (final_players[player_index] as Dictionary).duplicate(true)
		var final_assets: Dictionary = (_asset_snapshot(player_index).get("assets", {}) as Dictionary).duplicate(true)
		var final_inventory := _canonical_inventory(player)
		var final_revision := int(player.get(META_REVISION, 0))
		player[META_FINGERPRINT] = _resource_fingerprint(player, final_inventory, final_assets)
		final_players[player_index] = player
		player_states[actor_id] = _state_snapshot(actor_id, player, final_inventory, final_assets, final_revision)
		revision_vector[actor_id] = final_revision
		mutations[actor_id] = {
			"cash_delta": int(row.get("cash_delta", 0)),
			"purchase_count_delta": int(row.get("purchase_count_delta", 0)),
			"spend_delta": int(row.get("spend_delta", 0)),
			"asset_debit": (row.get("asset_debit", {}) as Dictionary).duplicate(true),
			"asset_credit": (row.get("asset_credit", {}) as Dictionary).duplicate(true),
		}
	_write_world_players(final_players)

	var result := {
		"committed": true,
		"reserved": false,
		"reason_code": "committed",
		"reservation_id": normalized_id,
		"transaction_id": tx,
		"intent_hash": intent,
		"actor_ids": actor_ids.duplicate(),
		"previous_revision_vector": expected_revisions.duplicate(true),
		"revision_vector": revision_vector,
		"player_states": player_states,
		"mutations": mutations,
		"effect_receipt": effect_receipt.duplicate(true),
		"idempotent_replay": false,
	}
	_prepared_mutations.erase(normalized_id)
	_release_reservation(reservation)
	_store_terminal_result(reservation, result)
	_last_reason_code = "committed"
	return result.duplicate(true)


func abort_reserved(reservation_id: String, reason_code: String = "reservation_aborted") -> Dictionary:
	_abort_count += 1
	var normalized_id := reservation_id.strip_edges()
	if _reservation_results.has(normalized_id):
		var terminal: Dictionary = (_reservation_results.get(normalized_id, {}) as Dictionary).duplicate(true)
		terminal["idempotent_replay"] = true
		terminal["replayed"] = true
		return terminal
	if not _reservations.has(normalized_id):
		return _reject("reservation_missing", {"reservation_id": normalized_id})
	var reservation: Dictionary = _reservations.get(normalized_id, {}) as Dictionary
	var result := _reject(reason_code, {
		"aborted": true,
		"reservation_id": normalized_id,
		"transaction_id": str(reservation.get("transaction_id", "")),
		"intent_hash": str(reservation.get("intent_hash", "")),
	})
	_release_reservation(reservation)
	_store_terminal_result(reservation, result)
	return result


func remember_result(transaction_id: String, intent_hash: String, result: Dictionary) -> Dictionary:
	var tx := transaction_id.strip_edges()
	var intent := intent_hash.strip_edges()
	if tx.is_empty():
		return _reject("transaction_id_missing")
	if intent.is_empty():
		return _reject("intent_hash_missing")
	if _journal.has(tx):
		var replay := _journal_replay(tx, intent, false)
		if str(replay.get("reason_code", "")) == "transaction_intent_collision":
			return replay
		return {"remembered": true, "result": replay, "idempotent_replay": true}
	var saved := result.duplicate(true)
	saved["transaction_id"] = tx
	saved["intent_hash"] = intent
	_journal[tx] = {"intent_hash": intent, "result": saved}
	return {"remembered": true, "result": saved.duplicate(true), "idempotent_replay": false}


func replay_result(transaction_id: String, intent_hash: String) -> Dictionary:
	var tx := transaction_id.strip_edges()
	if not _journal.has(tx):
		return _reject("transaction_not_found", {"found": false, "transaction_id": tx})
	return _journal_replay(tx, intent_hash.strip_edges(), false)


func to_save_data() -> Dictionary:
	return {
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"journal": _journal.duplicate(true),
		"next_reservation_sequence": _next_reservation_sequence,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("state_version", 0)) != STATE_VERSION \
	or str(data.get("ruleset_id", "")) != RULESET_ID \
	or not (data.get("journal", {}) is Dictionary):
		return {"applied": false, "reason_code": "production_state_port_save_invalid"}
	_journal = (data.get("journal", {}) as Dictionary).duplicate(true)
	_next_reservation_sequence = maxi(1, int(data.get("next_reservation_sequence", 1)))
	_reservations.clear()
	_prepared_mutations.clear()
	_player_locks.clear()
	_inflight_transactions.clear()
	_reservation_results.clear()
	return {"applied": true, "reason_code": "", "journal_count": _journal.size()}


func player_feedback(reason_code: String) -> Dictionary:
	var messages := {
		"production_owner_missing": ["玩家状态尚未准备完成。", "等待手牌、现金和资产同步后再试。"],
		"production_world_missing": ["当前对局尚未载入。", "返回对局并等待场景加载完成。"],
		"asset_owner_unavailable": ["六色资产暂时无法结算。", "等待资产状态同步后重新确认。"],
		"asset_atomic_owner_unavailable": ["这项多人资产结算暂不可用。", "玩家状态不会被消耗，请稍后重试。"],
		"asset_credit_owner_unavailable": ["这项资产增加暂时无法安全结算。", "玩家状态不会被消耗，请稍后重试。"],
		"asset_reservation_commit_failed": ["资产预留没有完成。", "同步六色资产后重新确认。"],
		"asset_consume_failed": ["资产结算没有完成。", "本次变化已撤回，请重新操作。"],
		"asset_atomic_rollback_failed": ["资产状态需要重新同步。", "暂停操作并重新进入当前对局。"],
		"actor_id_invalid": ["玩家身份无效。", "返回对局并重新选择当前玩家。"],
		"player_missing": ["当前玩家尚未加入这局游戏。", "重新进入对局或等待玩家同步完成。"],
		"player_busy": ["相关玩家正在结算另一项操作。", "等待当前结算结束后再试。"],
		"player_revision_changed": ["你的手牌、现金或资产已经发生变化。", "使用最新状态重新确认。"],
		"inventory_changed": ["你的手牌已经发生变化。", "查看最新手牌后重新操作。"],
		"cash_insufficient": ["现金不足，无法完成这项操作。", "等待收入增长或选择更便宜的牌。"],
		"assets_insufficient": ["对应颜色的资产不足。", "让自己的该色商品产生更多 GDP 后再试。"],
		"generic_asset_pool_forbidden": ["通用费用不能保存为独立余额。", "从六种产业资产中选择支付组合。"],
		"card_instance_duplicate_global": ["卡牌状态需要重新同步。", "等待手牌同步完成后再操作。"],
		"effect_not_committed": ["卡牌效果尚未成功结算。", "修正目标后重新操作。"],
		"effect_receipt_mismatch": ["效果凭据与本次操作不一致。", "取消当前操作并重新发起。"],
		"transaction_intent_collision": ["同一操作编号对应了不同选择。", "取消旧操作并重新确认。"],
	}
	var pair: Array = messages.get(reason_code, ["当前操作没有完成。", "状态未被消耗，请同步后重试。"])
	return {"reason": str(pair[0]), "next_step": str(pair[1])}


func debug_snapshot() -> Dictionary:
	return {
		"adapter_ready": _service_ready(),
		"adapter_authoritative": false,
		"world_bound": _world_has_players(),
		"stores_inventory": false,
		"stores_cash": false,
		"stores_assets": false,
		"per_player_revision": true,
		"uses_global_asset_revision_as_player_revision": false,
		"exact_delta_commit": true,
		"multi_player_reservation": true,
		"pre_effect_mutation_staging": true,
		"reservation_count": _reservations.size(),
		"prepared_mutation_count": _prepared_mutations.size(),
		"journal_count": _journal.size(),
		"reserve_count": _reserve_count,
		"commit_count": _commit_count,
		"abort_count": _abort_count,
		"reject_count": _reject_count,
		"last_reason_code": _last_reason_code,
	}


func _service_ready() -> bool:
	return _configured and _world_has_players() and _asset_owner_ready()


func _asset_owner_ready() -> bool:
	if _asset_controller == null:
		return false
	for method_name in ["availability_snapshot", "plan_reservation", "commit_reservation", "consume_reservation", "release_reservation"]:
		if not _asset_controller.has_method(method_name):
			return false
	return true


func _asset_rollback_ready() -> bool:
	return _asset_controller != null \
		and _asset_controller.has_method("to_save_data") \
		and _asset_controller.has_method("apply_save_data")


func _asset_snapshot(player_index: int) -> Dictionary:
	if not _asset_owner_ready():
		return {"valid": false, "assets": {}}
	var value_variant: Variant = _asset_controller.call("availability_snapshot", player_index)
	if not (value_variant is Dictionary) or not bool((value_variant as Dictionary).get("valid", false)):
		return {"valid": false, "assets": {}}
	var source: Dictionary = (value_variant as Dictionary).get("assets", {}) as Dictionary
	var assets: Dictionary = {}
	for asset_id in ASSET_IDS:
		if not source.has(asset_id) or int(source.get(asset_id, -1)) < 0:
			return {"valid": false, "assets": {}}
		assets[asset_id] = int(source.get(asset_id, 0))
	return {"valid": true, "assets": assets}


func _normalize_reservation_request(expected_revisions: Dictionary, actor_ids: Array) -> Dictionary:
	if actor_ids.is_empty():
		return {"valid": false, "reason_code": "reservation_request_invalid"}
	var normalized_actor_ids: Array[String] = []
	for actor_variant in actor_ids:
		var actor_id := str(actor_variant).strip_edges()
		if actor_id.is_empty() or normalized_actor_ids.has(actor_id):
			return {"valid": false, "reason_code": "reservation_request_invalid"}
		normalized_actor_ids.append(actor_id)
	normalized_actor_ids.sort()
	var revisions: Dictionary = {}
	for actor_variant in expected_revisions.keys():
		var actor_id := str(actor_variant).strip_edges()
		var value: Variant = expected_revisions.get(actor_variant)
		if actor_id.is_empty() or revisions.has(actor_id) or not (value is int) or int(value) < 0:
			return {"valid": false, "reason_code": "expected_revisions_invalid"}
		revisions[actor_id] = int(value)
	if revisions.size() != normalized_actor_ids.size():
		return {"valid": false, "reason_code": "expected_revisions_invalid"}
	for actor_id in normalized_actor_ids:
		if not revisions.has(actor_id):
			return {"valid": false, "reason_code": "expected_revisions_invalid"}
	return {"valid": true, "actor_ids": normalized_actor_ids, "expected_revisions": revisions}


func _normalize_next_state(actor_id: String, input: Dictionary) -> Dictionary:
	if input.has("actor_id") and str(input.get("actor_id", "")) != actor_id:
		return {"valid": false, "reason_code": "next_state_actor_mismatch"}
	var cash_variant: Variant = input.get("cash", -1)
	if not (cash_variant is int) or int(cash_variant) < 0:
		return {"valid": false, "reason_code": "cash_invalid"}
	var purchase_count_variant: Variant = input.get("card_purchase_count", 0)
	var total_spend_variant: Variant = input.get("total_card_spend", 0)
	if not (purchase_count_variant is int) or int(purchase_count_variant) < 0 or not (total_spend_variant is int) or int(total_spend_variant) < 0:
		return {"valid": false, "reason_code": "purchase_ledger_invalid"}
	var assets_variant: Variant = input.get("assets", {})
	if not (assets_variant is Dictionary):
		return {"valid": false, "reason_code": "assets_invalid"}
	var assets_source: Dictionary = assets_variant as Dictionary
	if assets_source.has("generic"):
		return {"valid": false, "reason_code": "generic_asset_pool_forbidden"}
	if assets_source.size() != ASSET_IDS.size():
		return {"valid": false, "reason_code": "assets_invalid"}
	var assets: Dictionary = {}
	for asset_id in ASSET_IDS:
		var value: Variant = assets_source.get(asset_id)
		if not (value is int) or int(value) < 0:
			return {"valid": false, "reason_code": "assets_invalid"}
		assets[asset_id] = int(value)
	var inventory_check := _normalize_inventory(input.get("inventory", {}))
	if not bool(inventory_check.get("valid", false)):
		return inventory_check
	return {
		"valid": true,
		"player_state": {
			"actor_id": actor_id,
			"revision": maxi(0, int(input.get("revision", 0))),
			"cash": int(cash_variant),
			"card_purchase_count": int(purchase_count_variant),
			"total_card_spend": int(total_spend_variant),
			"assets": assets,
			"inventory": (inventory_check.get("inventory", {}) as Dictionary).duplicate(true),
		},
	}


func _normalize_inventory(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"valid": false, "reason_code": "inventory_invalid"}
	var source: Dictionary = value as Dictionary
	if int(source.get("hand_limit", HAND_LIMIT)) != HAND_LIMIT or not (source.get("slots", []) is Array):
		return {"valid": false, "reason_code": "inventory_invalid"}
	var slots: Array = []
	var instance_ids: Dictionary = {}
	var counted := 0
	for slot_variant in source.get("slots", []) as Array:
		if slot_variant == null:
			slots.append(null)
			continue
		if not (slot_variant is Dictionary):
			return {"valid": false, "reason_code": "inventory_invalid"}
		var card := (slot_variant as Dictionary).duplicate(true)
		var instance_id := str(card.get("runtime_instance_id", "")).strip_edges()
		if instance_id.is_empty():
			return {"valid": false, "reason_code": "card_instance_id_missing"}
		if instance_ids.has(instance_id):
			return {"valid": false, "reason_code": "card_instance_duplicate"}
		instance_ids[instance_id] = true
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if bool(machine.get("counts_toward_hand_limit", true)):
			counted += 1
		slots.append(card)
	if counted > HAND_LIMIT:
		return {"valid": false, "reason_code": "inventory_full"}
	return {"valid": true, "inventory": {"hand_limit": HAND_LIMIT, "slots": slots}}


func _asset_delta(before: Dictionary, proposed: Dictionary) -> Dictionary:
	var debit := _zero_assets()
	var credit := _zero_assets()
	if before.has("generic") or proposed.has("generic"):
		return {"valid": false, "reason_code": "generic_asset_pool_forbidden"}
	for asset_id in ASSET_IDS:
		if not before.has(asset_id) or not proposed.has(asset_id):
			return {"valid": false, "reason_code": "assets_invalid"}
		var previous := int(before.get(asset_id, -1))
		var next_value := int(proposed.get(asset_id, -1))
		if previous < 0 or next_value < 0:
			return {"valid": false, "reason_code": "assets_invalid"}
		if previous > next_value:
			debit[asset_id] = previous - next_value
		elif next_value > previous:
			credit[asset_id] = next_value - previous
	return {"valid": true, "debit": debit, "credit": credit}


func _state_snapshot(actor_id: String, player: Dictionary, inventory: Dictionary, assets: Dictionary, revision: int) -> Dictionary:
	return {
		"actor_id": actor_id,
		"revision": revision,
		"cash": _cash_units(player),
		"card_purchase_count": maxi(0, int(player.get("card_purchase_count", 0))),
		"total_card_spend": maxi(0, int(player.get("total_card_spend", 0))),
		"assets": assets.duplicate(true),
		"inventory": inventory.duplicate(true),
	}


func _canonical_inventory(player: Dictionary) -> Dictionary:
	var slots: Array = []
	var world_slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	for slot_index in range(world_slots.size()):
		var slot_variant: Variant = world_slots[slot_index]
		if slot_variant is Dictionary:
			slots.append(_canonical_card(slot_variant as Dictionary, slot_index))
		else:
			slots.append(null)
	return {"hand_limit": HAND_LIMIT, "slots": slots}


func _canonical_card(world_card: Dictionary, slot_index: int) -> Dictionary:
	var instance_id := str(world_card.get("runtime_instance_id", ""))
	var machine_variant: Variant = world_card.get("machine", {})
	if machine_variant is Dictionary and not (machine_variant as Dictionary).is_empty():
		return {
			"machine": (machine_variant as Dictionary).duplicate(true),
			"player": (world_card.get("player", {}) as Dictionary).duplicate(true) if world_card.get("player", {}) is Dictionary else {},
			"developer": (world_card.get("developer", {}) as Dictionary).duplicate(true) if world_card.get("developer", {}) is Dictionary else {},
			"runtime_instance_id": instance_id,
		}
	var source_id := str(world_card.get("card_id", world_card.get("name", ""))).strip_edges()
	var canonical: Dictionary = _catalog.call("card_snapshot", source_id) if _catalog != null and _catalog.has_method("card_snapshot") else {}
	if canonical.is_empty():
		canonical = {
			"machine": {
				"card_id": source_id if not source_id.is_empty() else "legacy.unknown.%d" % slot_index,
				"family_id": str(world_card.get("family_id", world_card.get("family", source_id))),
				"rank": maxi(1, int(world_card.get("rank", 1))),
				"category_id": "legacy_v04",
				"counts_toward_hand_limit": _world_card_counts_toward_limit(world_card),
				"asset_cost": _zero_assets(),
				"effect_kind": "legacy_effect_unavailable",
				"target_kind": "none",
			},
			"player": {"name": str(world_card.get("display_name", world_card.get("name", "旧版卡牌")))},
			"developer": {"runtime_bridge_opaque": true},
		}
	canonical["runtime_instance_id"] = instance_id
	return canonical


func _world_slots_from_inventory(inventory: Dictionary, original_cards: Dictionary) -> Array:
	var result: Array = []
	for slot_variant in inventory.get("slots", []) as Array:
		if not (slot_variant is Dictionary):
			result.append(null)
			continue
		var canonical: Dictionary = slot_variant
		var instance_id := str(canonical.get("runtime_instance_id", ""))
		var card_id := _canonical_card_id(canonical)
		if original_cards.has(instance_id):
			var original: Dictionary = original_cards.get(instance_id, {}) as Dictionary
			if _world_card_id(original) == card_id:
				result.append(original.duplicate(true))
				continue
		result.append(_world_card_from_canonical(canonical))
	return result


func _world_card_from_canonical(card: Dictionary) -> Dictionary:
	var result := card.duplicate(true)
	var machine: Dictionary = result.get("machine", {}) if result.get("machine", {}) is Dictionary else {}
	var player_text: Dictionary = result.get("player", {}) if result.get("player", {}) is Dictionary else {}
	result["card_id"] = str(machine.get("card_id", ""))
	result["name"] = str(machine.get("card_id", ""))
	result["display_name"] = str(player_text.get("name", result.get("name", "")))
	result["family_id"] = str(machine.get("family_id", ""))
	result["rank"] = int(machine.get("rank", 1))
	result["kind"] = str(machine.get("category_id", "card_v06"))
	result["counts_toward_hand_limit"] = bool(machine.get("counts_toward_hand_limit", true))
	result["persistent"] = false
	result["queued_for_resolution"] = false
	result["lock_left"] = 0.0
	result["text"] = str(player_text.get("effect", player_text.get("short_effect", "")))
	return result


func _world_cards_by_instance(players: Array) -> Dictionary:
	var result: Dictionary = {}
	for player_variant in players:
		if not (player_variant is Dictionary):
			continue
		var slots: Array = (player_variant as Dictionary).get("slots", []) if (player_variant as Dictionary).get("slots", []) is Array else []
		for slot_variant in slots:
			if slot_variant is Dictionary:
				var instance_id := str((slot_variant as Dictionary).get("runtime_instance_id", ""))
				if not instance_id.is_empty():
					result[instance_id] = (slot_variant as Dictionary).duplicate(true)
	return result


func _validate_global_world_instances(players: Array) -> Dictionary:
	var owners: Dictionary = {}
	for player_index in range(players.size()):
		if not (players[player_index] is Dictionary):
			continue
		var slots: Array = (players[player_index] as Dictionary).get("slots", []) if (players[player_index] as Dictionary).get("slots", []) is Array else []
		for slot_variant in slots:
			if not (slot_variant is Dictionary):
				continue
			var instance_id := str((slot_variant as Dictionary).get("runtime_instance_id", ""))
			if instance_id.is_empty():
				return {"valid": false, "reason_code": "card_instance_id_missing"}
			if owners.has(instance_id):
				return {"valid": false, "reason_code": "card_instance_duplicate_global"}
			owners[instance_id] = player_index
	return {"valid": true}


func _ensure_world_instance_ids(player_index: int, player: Dictionary) -> void:
	var slots: Array = (player.get("slots", []) as Array).duplicate(true) if player.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var card := (slots[slot_index] as Dictionary).duplicate(true)
		if str(card.get("runtime_instance_id", "")).is_empty():
			card["runtime_instance_id"] = "world:%d:%d:%s" % [player_index, slot_index, str(hash(_world_card_id(card)))]
			slots[slot_index] = card
	player["slots"] = slots


func _ensure_all_world_instance_ids(players: Array) -> void:
	for player_index in range(players.size()):
		if not (players[player_index] is Dictionary):
			continue
		var player := (players[player_index] as Dictionary).duplicate(true)
		_ensure_world_instance_ids(player_index, player)
		players[player_index] = player


func _resource_fingerprint(player: Dictionary, inventory: Dictionary, assets: Dictionary) -> String:
	# Deliberately excludes PlayerManaRuntimeController's global revision.  A tick
	# with no balance change therefore cannot invalidate a player's CAS revision.
	return _stable_hash({
		"cash_cents": _cash_cents(player),
		"card_purchase_count": maxi(0, int(player.get("card_purchase_count", 0))),
		"total_card_spend": maxi(0, int(player.get("total_card_spend", 0))),
		"assets": assets,
		"inventory": inventory,
	})


func _release_asset_reservations(transaction_ids: Array[String], reason: String) -> void:
	for transaction_id in transaction_ids:
		_asset_controller.call("release_reservation", transaction_id, reason)


func _compact_prepared_result(stage: Dictionary) -> Dictionary:
	return {
		"prepared": true,
		"committed": false,
		"reason_code": "mutations_prepared",
		"reservation_id": str(stage.get("reservation_id", "")),
		"transaction_id": str(stage.get("transaction_id", "")),
		"intent_hash": str(stage.get("intent_hash", "")),
		"actor_ids": (stage.get("actor_ids", []) as Array).duplicate(),
		"asset_reservation_count": (stage.get("asset_transaction_ids", []) as Array).size(),
		"idempotent_replay": false,
	}


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _reservation_result(reservation: Dictionary, replayed: bool) -> Dictionary:
	return {
		"reserved": true,
		"committed": false,
		"reason_code": "reserved",
		"reservation_id": str(reservation.get("reservation_id", "")),
		"transaction_id": str(reservation.get("transaction_id", "")),
		"intent_hash": str(reservation.get("intent_hash", "")),
		"actor_ids": (reservation.get("actor_ids", []) as Array).duplicate(),
		"expected_revisions": (reservation.get("expected_revisions", {}) as Dictionary).duplicate(true),
		"before_snapshots": (reservation.get("before_snapshots", {}) as Dictionary).duplicate(true),
		"idempotent_replay": replayed,
	}


func _commit_reject(reservation: Dictionary, reason_code: String, extra: Dictionary = {}) -> Dictionary:
	var details := {
		"reservation_id": str(reservation.get("reservation_id", "")),
		"transaction_id": str(reservation.get("transaction_id", "")),
		"intent_hash": str(reservation.get("intent_hash", "")),
	}
	details.merge(extra, true)
	return _reject(reason_code, details)


func _remember_reserve_reject(transaction_id: String, intent_hash: String, reason_code: String, extra: Dictionary = {}) -> Dictionary:
	var details := {"transaction_id": transaction_id, "intent_hash": intent_hash}
	details.merge(extra, true)
	var result := _reject(reason_code, details)
	_journal[transaction_id] = {"intent_hash": intent_hash, "result": result.duplicate(true)}
	return result


func _release_reservation(reservation: Dictionary) -> void:
	var reservation_id := str(reservation.get("reservation_id", ""))
	if _prepared_mutations.has(reservation_id):
		var stage: Dictionary = _prepared_mutations.get(reservation_id, {}) as Dictionary
		var asset_transaction_ids := _string_array(stage.get("asset_transaction_ids", []) as Array)
		if not asset_transaction_ids.is_empty():
			_release_asset_reservations(asset_transaction_ids, "player_state_reservation_released")
		_prepared_mutations.erase(reservation_id)
	for actor_variant in reservation.get("actor_ids", []) as Array:
		var actor_id := str(actor_variant)
		if str(_player_locks.get(actor_id, "")) == reservation_id:
			_player_locks.erase(actor_id)
	_inflight_transactions.erase(str(reservation.get("transaction_id", "")))
	_reservations.erase(reservation_id)


func _store_terminal_result(reservation: Dictionary, result: Dictionary) -> void:
	var saved := result.duplicate(true)
	_reservation_results[str(reservation.get("reservation_id", ""))] = saved
	_journal[str(reservation.get("transaction_id", ""))] = {
		"intent_hash": str(reservation.get("intent_hash", "")),
		"result": saved.duplicate(true),
	}


func _journal_replay(transaction_id: String, intent_hash: String, from_reserve: bool) -> Dictionary:
	var record: Dictionary = _journal.get(transaction_id, {}) as Dictionary
	if str(record.get("intent_hash", "")) != intent_hash:
		return _reject("transaction_intent_collision", {"transaction_id": transaction_id})
	var result: Dictionary = (record.get("result", {}) as Dictionary).duplicate(true)
	result["idempotent_replay"] = true
	result["replayed"] = true
	result["found"] = true
	if from_reserve:
		result["handled"] = true
	return result


func _reject(reason_code: String, extra: Dictionary = {}) -> Dictionary:
	_reject_count += 1
	_last_reason_code = reason_code
	var result := {
		"committed": false,
		"reserved": false,
		"reason_code": reason_code,
		"feedback": player_feedback(reason_code),
		"idempotent_replay": false,
	}
	result.merge(extra, true)
	return result


func _actor_id(player_index: int, player: Dictionary) -> String:
	var configured := str(player.get("actor_id", "")).strip_edges()
	return configured if not configured.is_empty() else "player.%d" % player_index


func _player_index(actor_id: String) -> int:
	var players := _world_players()
	for player_index in range(players.size()):
		if players[player_index] is Dictionary and _actor_id(player_index, players[player_index] as Dictionary) == actor_id:
			return player_index
	return -1


func _world_has_players() -> bool:
	return _world_session_state != null


func _world_players() -> Array:
	if not _world_has_players():
		return []
	var value: Variant = _world_session_state.players
	return (value as Array).duplicate(true) if value is Array else []


func _write_world_players(players: Array) -> void:
	if _world_has_players():
		_world_session_state.players = players.duplicate(true)


func _world_card_id(card: Dictionary) -> String:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return str(machine.get("card_id", card.get("card_id", card.get("name", ""))))


func _canonical_card_id(card: Dictionary) -> String:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return str(machine.get("card_id", ""))


func _world_card_counts_toward_limit(card: Dictionary) -> bool:
	if card.has("counts_toward_hand_limit"):
		return bool(card.get("counts_toward_hand_limit", true))
	return not (["monster_bound_action", "military_command"].has(str(card.get("kind", ""))) and bool(card.get("persistent", false)))


func _asset_total(values: Dictionary) -> int:
	var total := 0
	for asset_id in ASSET_IDS:
		total += maxi(0, int(values.get(asset_id, 0)))
	return total


func _cash_cents(player: Dictionary) -> int:
	if player.has("cash_cents"):
		return maxi(0, int(player.get("cash_cents", 0)))
	return maxi(0, int(player.get("cash", 0))) * 100


func _cash_units(player: Dictionary) -> int:
	return floori(float(_cash_cents(player)) / 100.0)


func _zero_assets() -> Dictionary:
	var result: Dictionary = {}
	for asset_id in ASSET_IDS:
		result[asset_id] = 0
	return result


func _stable_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize(source.get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonicalize(item))
		return result
	return value
