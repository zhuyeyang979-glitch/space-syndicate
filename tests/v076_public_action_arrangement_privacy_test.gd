extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)

const MATCH_SEED := 901626424
const MAP_SEED := 900626424

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var runtime := RuntimeOwner.new()
	var combat := CombatOwner.new()
	host.add_child(runtime)
	host.add_child(combat)
	var bound := runtime.bind_combat_owner(combat)
	_expect(bool(bound.get("accepted", false)), "combat owner binds")
	var started := runtime.start_new_game(
		4,
		MATCH_SEED,
		true,
		true,
		{
			"map_seed": MAP_SEED,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	)
	_expect(bool(started.get("accepted", false)), "production runtime starts")
	var player_ids := runtime.call("player_ids") as Array
	_expect(player_ids.size() == 4, "test runtime has one human and three AI seats")
	if player_ids.size() < 3:
		host.queue_free()
		await process_frame
		_finish()
		return

	# Keep the projection test focused on the receipt bridge.  No real queue or
	# card is injected; the synthetic rows model only the already-sanitized
	# presentation receipts emitted by the existing AI action path.
	var ai_one := str(player_ids[1])
	var ai_two := str(player_ids[2])
	var private_receipt: Dictionary = runtime.call(
		"_v075_record_ai_public_action",
		ai_one,
		"PRIVATE_DIRECT_ACTION_QUEUED",
		"queued",
		"military",
		true
	)
	runtime.call(
		"_v075_record_ai_public_action",
		ai_two,
		"PASS_NO_LEGAL_CARD",
		"no_legal_public_card",
		"facility",
		false
	)
	var projection := runtime.call(
		"_v075_public_action_arrangement_projection",
		str(player_ids[0])
	) as Dictionary
	var entries := projection.get("entries", []) as Array
	var private_receipt_id := str(
		(private_receipt as Dictionary).get("receipt_id", "")
	)
	var private_source_anchor := "ai_seat_%02d" % maxi(1, player_ids.find(ai_one))
	var private_entry_count := 0
	var pass_entry_count := 0
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if str(entry.get("source_anchor", "")) == private_source_anchor:
			private_entry_count += 1
		if str(entry.get("projection_role", "")) == "public_pass_receipt":
			pass_entry_count += 1
	_expect(
		private_entry_count == 0,
		"queued Private Direct Action does not become a public PASS row"
	)
	_expect(
		not JSON.stringify(entries).contains(private_receipt_id),
		"private queued receipt identity is absent from public arrangement"
	)
	_expect(
		pass_entry_count == 0,
		"explicit PASS remains in Action Feed and never enters the card arrangement"
	)
	_expect(
		int(projection.get("private_direct_action_entry_count", -1)) == 0,
		"production projection reports zero private card entries"
	)

	# Exercise the counting helper with one actual private projected row and one
	# PASS row carrying the same private domain.  PASS feedback is public-safe and
	# must not inflate the private-card count.
	var synthetic_entries := [
		{
			"action_domain": "military",
			"projection_role": "public_batch_card",
			"authority_zone": "public_batch",
		},
		{
			"action_domain": "military",
			"projection_role": "",
			"authority_zone": "public_receipt",
			"kind": "pass",
			"state": "PASS",
		},
		{
			"action_domain": "facility",
			"projection_role": "public_pending_card",
		},
	]
	_expect(
		int(runtime.call(
			"_v075_private_direct_action_entry_count",
			synthetic_entries
		)) == 1,
		"private-entry count derives from projected rows and excludes PASS feedback"
	)

	host.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V076_PUBLIC_ACTION_ARRANGEMENT_PRIVACY_TEST|status=PASS|checks=%d"
			% _checks
		)
	else:
		print(
			"V076_PUBLIC_ACTION_ARRANGEMENT_PRIVACY_TEST|status=FAIL|checks=%d|failures=%s"
			% [_checks, JSON.stringify(_failures)]
		)
	quit(0 if _failures.is_empty() else 1)
