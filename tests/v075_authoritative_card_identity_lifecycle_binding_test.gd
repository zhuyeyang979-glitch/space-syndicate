extends SceneTree

const DbgCore := preload(
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd"
)
const TrackCore := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const OWNER_ID := "player.binding.owner"
const RIVAL_ID := "player.binding.rival"
const THIRD_ID := "player.binding.third"
const LIFECYCLE_ID := "v075.combat.queue_resolve_personal_discard"
const FIXED_SEED := 75075401

var _checks := 0
var _failures: Array[String] = []
var _request_sequence := 0
var _forged_accept_count := 0
var _stale_accept_count := 0
var _rival_leak_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dbg := DbgCore.new()
	var initialized := dbg.initialize(OWNER_ID, FIXED_SEED)
	_expect(
		bool(initialized.get("initialized", false)),
		"DBG authority initializes without a Save-schema extension"
	)
	if not bool(initialized.get("initialized", false)):
		_finish()
		return
	var track := _track_authority("match.v075.binding.primary")
	var track_binding := dbg.bind_unified_track_receipt_authority(track)
	_expect(
		bool(track_binding.get("bound", false)),
		"DBG action identity is pinned to the real shared-track match lineage"
	)
	if not bool(track_binding.get("bound", false)):
		_finish()
		return

	var opening_hand := _state(dbg).get("hand", []) as Array
	var source_card := (opening_hand[0] as Dictionary).duplicate(true)
	var card_instance_id := str(source_card.get("instance_id", ""))
	var original := dbg.authoritative_card_action_binding_v1(
		OWNER_ID,
		card_instance_id,
		LIFECYCLE_ID
	)
	_expect(
		not original.is_empty()
		and str(original.get("owner_player_id", "")) == OWNER_ID
		and str(original.get("card_instance_id", "")) == card_instance_id
		and str(original.get("card_definition_id", ""))
			== str(source_card.get("definition_id", ""))
		and original.get("authoritative_zone") == "hand"
		and str(original.get("binding_fingerprint", "")).length() == 64,
		"owner receives the canonical current-hand identity and lifecycle binding"
	)
	var rival_binding := dbg.authoritative_card_action_binding_v1(
			RIVAL_ID,
			card_instance_id,
			LIFECYCLE_ID
		)
	_rival_leak_count += int(not rival_binding.is_empty())
	_expect(
		rival_binding.is_empty(),
		"rival viewer receives no owner-private card identity or binding"
	)
	_expect(
		bool(dbg.validate_card_action_binding_v1(
			OWNER_ID,
			original,
			LIFECYCLE_ID
		).get("accepted", false)),
		"DBG re-derives and accepts the exact owner binding"
	)

	var next_match_dbg := DbgCore.new()
	var next_match_initialized := next_match_dbg.initialize(OWNER_ID, FIXED_SEED)
	var next_match_track := _track_authority("match.v075.binding.next")
	var next_match_bound := next_match_dbg.bind_unified_track_receipt_authority(
		next_match_track
	)
	var next_match_hand := _state(next_match_dbg).get("hand", []) as Array
	var same_opening_card_id := str((next_match_hand[0] as Dictionary).get(
		"instance_id",
		""
	))
	var next_match_binding := next_match_dbg.authoritative_card_action_binding_v1(
		OWNER_ID,
		same_opening_card_id,
		LIFECYCLE_ID
	)
	var cross_match_replay_accepted := bool(
		next_match_dbg.validate_card_action_binding_v1(
			OWNER_ID,
			original,
			LIFECYCLE_ID
		).get("accepted", false)
	)
	_stale_accept_count += int(cross_match_replay_accepted)
	_expect(
		bool(next_match_initialized.get("initialized", false))
		and bool(next_match_bound.get("bound", false))
		and same_opening_card_id == card_instance_id
		and not next_match_binding.is_empty()
		and next_match_binding.get("immutable_identity_fingerprint")
			!= original.get("immutable_identity_fingerprint")
		and next_match_binding.get("binding_fingerprint")
			!= original.get("binding_fingerprint")
		and not cross_match_replay_accepted,
		"same owner and seed cannot replay a previous match binding"
	)

	var forged_cases := [
		{"field": "owner_player_id", "value": RIVAL_ID},
		{"field": "card_instance_id", "value": "dbg.forged.instance"},
		{"field": "card_definition_id", "value": "dbg.forged.definition"},
		{"field": "authoritative_zone", "value": "discard"},
		{"field": "zone_revision", "value": int(original.get("zone_revision", 0)) + 1},
		{"field": "immutable_identity_fingerprint", "value": "0".repeat(64)},
		{"field": "lifecycle_evidence_fingerprint", "value": "1".repeat(64)},
		{"field": "binding_fingerprint", "value": "2".repeat(64)},
	]
	for case_variant in forged_cases:
		var case := case_variant as Dictionary
		var forged := original.duplicate(true)
		forged[str(case.get("field", ""))] = case.get("value")
		if bool(dbg.validate_card_action_binding_v1(
			OWNER_ID,
			forged,
			LIFECYCLE_ID
		).get("accepted", false)):
			_forged_accept_count += 1
	var extra_field := original.duplicate(true)
	extra_field["caller_override"] = true
	if bool(dbg.validate_card_action_binding_v1(
		OWNER_ID,
		extra_field,
		LIFECYCLE_ID
	).get("accepted", false)):
		_forged_accept_count += 1
	_expect(
		_forged_accept_count == 0,
		"all forged identity, lifecycle, fingerprint, and override payloads fail closed"
	)

	var first_play := _play_card(dbg, card_instance_id, "initial")
	_expect(
		bool(first_play.get("success", false))
		and _zone_has(_state(dbg).get("discard", []) as Array, card_instance_id),
		"normal DBG play moves the exact card from hand to personal discard"
	)
	var post_play_replay_accepted := bool(
		dbg.validate_card_action_binding_v1(
			OWNER_ID,
			original,
			LIFECYCLE_ID
		).get("accepted", false)
	)
	_stale_accept_count += int(post_play_replay_accepted)
	_expect(
		not post_play_replay_accepted,
		"the old binding is invalid immediately after the card leaves hand"
	)

	var rebound: Dictionary = {}
	var reshuffle_count := 0
	for batch_index in range(1, 25):
		for card_variant in (_state(dbg).get("hand", []) as Array).duplicate(true):
			var card := card_variant as Dictionary
			var play := _play_card(
				dbg,
				str(card.get("instance_id", "")),
				"cycle.%02d" % batch_index
			)
			if not bool(play.get("success", false)):
				_fail("natural cycle card play failed")
		var complete := dbg.apply_intent(dbg.create_authority_intent(
			_next_request("complete.%02d" % batch_index),
			DbgCore.ACTION_COMPLETE_BATCH,
			{}
		))
		reshuffle_count += int(complete.get("reshuffle_count", 0))
		var maintenance := dbg.apply_intent(dbg.create_intent(
			_next_request("maintenance.%02d" % batch_index),
			OWNER_ID,
			DbgCore.ACTION_END_MAINTENANCE,
			{},
			DbgCore.DECISION_PLAYER_EXPLICIT
		))
		if not bool(complete.get("success", false)) or not bool(
			maintenance.get("success", false)
		):
			_fail("natural complete/maintenance lifecycle failed")
			break
		if _zone_has(_state(dbg).get("hand", []) as Array, card_instance_id):
			rebound = dbg.authoritative_card_action_binding_v1(
				OWNER_ID,
				card_instance_id,
				LIFECYCLE_ID
			)
			break

	_expect(reshuffle_count > 0, "normal personal discard reshuffle occurs")
	_expect(
		not rebound.is_empty()
		and rebound.get("immutable_identity_fingerprint")
			== original.get("immutable_identity_fingerprint")
		and rebound.get("binding_fingerprint")
			!= original.get("binding_fingerprint")
		and int(rebound.get("zone_revision", 0))
			> int(original.get("zone_revision", 0)),
		"same immutable card receives a new binding after natural reshuffle and draw"
	)
	var redraw_old_binding_accepted := bool(
		dbg.validate_card_action_binding_v1(
			OWNER_ID,
			original,
			LIFECYCLE_ID
		).get("accepted", false)
	)
	_stale_accept_count += int(redraw_old_binding_accepted)
	_expect(
		not redraw_old_binding_accepted
		and bool(dbg.validate_card_action_binding_v1(
			OWNER_ID,
			rebound,
			LIFECYCLE_ID
		).get("accepted", false)),
		"old lifecycle replay is rejected while the new lifecycle is accepted"
	)
	var replay_play := _play_card(dbg, card_instance_id, "rebound")
	_expect(
		bool(replay_play.get("success", false))
		and _zone_has(_state(dbg).get("discard", []) as Array, card_instance_id)
		and not bool(dbg.validate_card_action_binding_v1(
			OWNER_ID,
			rebound,
			LIFECYCLE_ID
		).get("accepted", false)),
		"new lifecycle can execute once and becomes stale after exact discard"
	)
	_expect(
		not JSON.stringify(dbg.to_save_state()).contains(
			DbgCore.CARD_ACTION_BINDING_SCHEMA_ID
		),
		"transient binding is absent from the production Save document"
	)
	_finish()


func _play_card(
	dbg: RefCounted,
	card_instance_id: String,
	label: String
) -> Dictionary:
	return dbg.apply_intent(dbg.create_intent(
		_next_request("play.%s" % label),
		OWNER_ID,
		DbgCore.ACTION_PLAY_CARD,
		{"instance_id": card_instance_id},
		DbgCore.DECISION_PLAYER_EXPLICIT
	))


func _next_request(label: String) -> String:
	_request_sequence += 1
	return "request.v075.binding.%04d.%s" % [_request_sequence, label]


func _state(dbg: RefCounted) -> Dictionary:
	return (
		(dbg.core_authority_snapshot() as Dictionary).get("state", {}) as Dictionary
	).duplicate(true)


func _track_authority(match_instance_id: String) -> RefCounted:
	var track := TrackCore.new()
	var started := track.start_match(
		[OWNER_ID, RIVAL_ID, THIRD_ID],
		FIXED_SEED,
		{
			"balance_profile_id": TrackCore.BALANCE_PROFILE_ID,
			"balance_profile_fingerprint": (
				TrackCore.BALANCE_PROFILE_FINGERPRINT
			),
			"normal_card_ratio_basis_points": 6000,
			"commodity_card_ratio_basis_points": 4000,
			"local_visible_slot_count": 10,
			"match_instance_id": match_instance_id,
		}
	)
	if not bool(started.get("accepted", false)):
		_fail("shared-track authority failed to start: %s" % match_instance_id)
	return track


func _zone_has(zone: Array, card_instance_id: String) -> bool:
	for card_variant in zone:
		if str((card_variant as Dictionary).get(
			"instance_id",
			""
		)) == card_instance_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("V075_AUTHORITATIVE_CARD_IDENTITY_TEST|FAIL|%s" % message)


func _finish() -> void:
	print(
		"V075_AUTHORITATIVE_CARD_IDENTITY_TEST|status=%s|checks=%d|failures=%d|forged_accepts=%d|stale_accepts=%d|rival_leaks=%d|save_schema_changes=0"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
			_forged_accept_count,
			_stale_accept_count,
			_rival_leak_count,
		]
	)
	if not _failures.is_empty():
		print(
			"V075_AUTHORITATIVE_CARD_IDENTITY_TEST_FAILURES|%s"
			% JSON.stringify(_failures)
		)
	quit(0 if _failures.is_empty() else 1)
