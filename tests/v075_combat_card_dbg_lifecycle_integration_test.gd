extends SceneTree

const OWNER_PLAYER_ID := "player.lifecycle"
const ROSTER := [
	"player.lifecycle",
	"player.rival.one",
	"player.rival.two",
]
const TRACK_SEEDS := [
	900626424,
	75075001,
	75075002,
	75075003,
	75075004,
	75075005,
]
const DEPENDENCY_PATHS := {
	"registry": "res://scripts/v075/cards/v075_card_definition_registry.gd",
	"combat_catalog": "res://scripts/v075/combat/v075_combat_catalog.gd",
	"track_core": "res://scripts/v07_semantic/v07_unified_card_track_core.gd",
	"shared_track": "res://scripts/v074/track/v074_shared_sushi_track_core.gd",
	"acquisition_port": (
		"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd"
	),
	"dbg_core": "res://scripts/v07_semantic/v07_dbg_deck_core.gd",
	"military_core": "res://scripts/v075/military/v075_military_mission_core.gd",
}

var _checks := 0
var _failures: Array[String] = []
var _scripts: Dictionary = {}
var _definitions: Dictionary = {}
var _request_sequence := 0


class AcquisitionParticipant extends RefCounted:
	var authority_id: String
	var authority_state: Dictionary
	var _track_script: Script

	func _init(value: String, track_script: Script) -> void:
		authority_id = value
		_track_script = track_script
		authority_state = {
			"reservations": {},
			"commits": {},
			"allocator_cursor": 0,
		}

	func acquisition_authority_id_v1() -> String:
		return authority_id

	func capture_checkpoint_v1() -> Dictionary:
		return authority_state.duplicate(true)

	func prepare_acquisition_v1(request: Dictionary) -> Dictionary:
		var reservation_id := "reservation.%s.%04d" % [
			str(request.get("participant_role", "")),
			int(authority_state.get("allocator_cursor", 0)),
		]
		authority_state["allocator_cursor"] = (
			int(authority_state.get("allocator_cursor", 0)) + 1
		)
		(authority_state.get("reservations", {}) as Dictionary)[
			reservation_id
		] = request.duplicate(true)
		return _receipt(
			request,
			reservation_id,
			{
				"accepted": true,
				"reason_code": "participant_prepared",
			}
		)

	func commit_prepared_acquisition_v1(
		reservation_id: String,
		track_receipt: Dictionary
	) -> Dictionary:
		var commits := authority_state.get("commits", {}) as Dictionary
		if commits.has(reservation_id):
			return (commits.get(reservation_id, {}) as Dictionary).duplicate(true)
		var request := (
			authority_state.get("reservations", {}) as Dictionary
		).get(reservation_id, {}) as Dictionary
		if request.is_empty():
			return {
				"accepted": false,
				"reason_code": "reservation_missing",
			}
		var receipt := _receipt(
			request,
			reservation_id,
			{
				"accepted": true,
				"reason_code": "participant_committed",
				"track_receipt_fingerprint": str(
					track_receipt.get("receipt_fingerprint", "")
				),
			}
		)
		commits[reservation_id] = receipt.duplicate(true)
		authority_state["commits"] = commits
		return receipt

	func abort_prepared_acquisition_v1(
		reservation_id: String,
		_reason_code: String
	) -> Dictionary:
		var request := (
			authority_state.get("reservations", {}) as Dictionary
		).get(reservation_id, {}) as Dictionary
		(authority_state.get("reservations", {}) as Dictionary).erase(
			reservation_id
		)
		return _receipt(
			request,
			reservation_id,
			{
				"accepted": true,
				"reason_code": "participant_aborted",
			}
		)

	func rollback_v1(checkpoint: Dictionary) -> Dictionary:
		authority_state = checkpoint.duplicate(true)
		return {
			"accepted": true,
			"reason_code": "participant_rolled_back",
		}

	func _receipt(
		request: Dictionary,
		reservation_id: String,
		fields: Dictionary
	) -> Dictionary:
		var unsealed := fields.duplicate(true)
		unsealed["transaction_id"] = str(request.get("transaction_id", ""))
		unsealed["reservation_id"] = reservation_id
		unsealed["authority_id"] = authority_id
		unsealed["participant_role"] = str(
			request.get("participant_role", "")
		)
		var sealed: Variant = _track_script.call(
			"sealed_copy",
			unsealed,
			"receipt_fingerprint"
		)
		return sealed as Dictionary if sealed is Dictionary else {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _load_dependencies():
		_finish()
		return
	_test_definition_and_forbidden_contracts()
	_test_shared_sushi_purchase_vacancies()
	var dbg_result := _test_dbg_purchase_reshuffle_and_draw()
	if not dbg_result.is_empty():
		_test_military_one_shot_lifecycle(dbg_result)
	_finish()


func _load_dependencies() -> bool:
	var ready := true
	for label_variant in DEPENDENCY_PATHS.keys():
		var label := str(label_variant)
		var path := str(DEPENDENCY_PATHS.get(label, ""))
		var resource: Resource = load(path)
		_expect(resource is Script, "%s dependency loads" % label)
		if resource is Script:
			_scripts[label] = resource
		else:
			ready = false
	return ready


func _test_definition_and_forbidden_contracts() -> void:
	var registry := _script("registry")
	var contract := registry.call("registry_contract") as Dictionary
	_expect(
		str(contract.get("monster_and_military_card_kind", ""))
			== "normal_card",
		"registry classifies monster and military cards as normal_card"
	)

	var monster_id := str(
		registry.call(
			"standard_definition_id",
			"monster.spore_tide_emperor",
			"technology",
			1
		)
	)
	var military_region_id := str(
		registry.call(
			"standard_definition_id",
			"military.planetary_defense_force",
			"industry",
			1
		)
	)
	var military_monster_id := str(
		registry.call(
			"standard_definition_id",
			"military.air_superiority_fighter",
			"shipping",
			1
		)
	)
	_definitions = {
		"monster": registry.call("definition", monster_id),
		"military_region": registry.call("definition", military_region_id),
		"military_monster": registry.call("definition", military_monster_id),
	}
	for label in ["monster", "military_region", "military_monster"]:
		var definition := _definitions.get(label, {}) as Dictionary
		var expected_domain := "monster" if label == "monster" else "military"
		_expect(not definition.is_empty(), "%s definition resolves" % label)
		_expect(
			str(
				registry.call(
					"card_domain",
					str(definition.get("card_type", ""))
				)
			) == expected_domain,
			"%s definition has the expected combat domain" % label
		)
		_expect(
			bool(definition.get("track_spawn_allowed", false))
				and bool(definition.get("purchase_allowed", false))
				and str(definition.get("origin_class", "")) == "standard",
			"%s is a purchasable normal-track definition" % label
		)

	var supply_ids := registry.call(
		"normal_track_supply_definition_ids"
	) as Array
	for definition_variant in _definitions.values():
		_expect(
			supply_ids.has(
				str((definition_variant as Dictionary).get("definition_id", ""))
			),
			"combat definition participates in the normal shared-track supply"
		)

	var catalog := _script("combat_catalog")
	var validation := catalog.call("validation_report") as Dictionary
	_expect(
		bool(validation.get("valid", false)),
		"active combat catalog validates"
	)
	var military_ids := catalog.call("military_definition_ids") as Array
	_expect(
		military_ids.size() > 0,
		"active combat catalog exposes military definitions"
	)
	for definition_id_variant in military_ids:
		var definition := catalog.call(
			"military_definition",
			str(definition_id_variant)
		) as Dictionary
		_expect(
			definition.get("mission_kinds")
				== ["assault_region", "assault_monster"],
			"military catalog exposes only the two assault missions"
		)
		_expect(
			not bool(definition.get("persistent_source", true))
				and int(definition.get("bound_action_count", -1)) == 0
				and int(definition.get("guard_task_count", -1)) == 0,
			"military catalog has no persistent source, bound action, or guard"
		)

	var mission_contract := _script("military_core").call(
		"contract_report"
	) as Dictionary
	_expect(
		mission_contract.get("military_task_kinds")
			== ["assault_region", "assault_monster"],
		"mission core publishes exactly assault_region and assault_monster"
	)
	_expect(
		int(mission_contract.get("military_guard_task_count", -1)) == 0
			and int(
				mission_contract.get("military_bound_action_count", -1)
			) == 0
			and int(
				mission_contract.get("military_persistent_source_count", -1)
			) == 0,
		"mission core publishes zero guard, bound-action, and persistent-source counts"
	)


func _test_shared_sushi_purchase_vacancies() -> void:
	var selected: Dictionary = {}
	for seed_variant in TRACK_SEEDS:
		var track := _new_shared_track(int(seed_variant))
		if track == null:
			continue
		var fixtures := _combat_track_fixtures(track)
		if (
			not (fixtures.get("monster", {}) as Dictionary).is_empty()
			and not (fixtures.get("military", {}) as Dictionary).is_empty()
		):
			selected = {
				"track": track,
				"fixtures": fixtures,
				"seed": int(seed_variant),
			}
			break
	_expect(
		not selected.is_empty(),
		"deterministic shared track exposes both combat card domains"
	)
	if selected.is_empty():
		return

	var track := selected.get("track") as RefCounted
	var track_script := _script("track_core")
	var cash := AcquisitionParticipant.new(
		"authority.cash.v075.lifecycle",
		track_script
	)
	var discard := AcquisitionParticipant.new(
		"authority.personal_discard.v075.lifecycle",
		track_script
	)
	var commodity := AcquisitionParticipant.new(
		"authority.commodity.v075.lifecycle",
		track_script
	)
	var port := _script("acquisition_port").new(
		track,
		{
			"cash": cash,
			"personal_discard": discard,
			"commodity_slot": commodity,
		}
	) as RefCounted
	_expect(
		port != null and bool(port.call("is_configured")),
		"typed acquisition port binds the shared track"
	)
	if port == null or not bool(port.call("is_configured")):
		return

	for domain in ["monster", "military"]:
		var fixture := (
			_combat_track_fixtures(track).get(domain, {}) as Dictionary
		)
		_expect(
			not fixture.is_empty(),
			"%s card remains available for purchase" % domain
		)
		if fixture.is_empty():
			continue
		var item := fixture.get("item", {}) as Dictionary
		_expect(
			str(item.get("card_kind", "")) == "normal_card",
			"%s shared-track instance is a normal_card" % domain
		)
		var before_state := _track_state(track)
		var before_track := before_state.get("track_state", {}) as Dictionary
		var before_items := before_track.get("items", []) as Array
		var before_supply := _supply_probe(before_state)
		var receipt := _transact_track_purchase(
			track,
			port,
			fixture,
			domain
		)
		_expect(
			bool(receipt.get("accepted", false))
				and str(receipt.get("destination_zone", ""))
					== "personal_discard",
			"%s shared-track purchase commits to personal discard" % domain
		)
		var track_receipt := receipt.get("track_receipt", {}) as Dictionary
		var public_facts := track_receipt.get("public_facts", {}) as Dictionary
		_expect(
			int(public_facts.get("replacement_count", -1)) == 0,
			"%s purchase creates no immediate authoritative refill" % domain
		)
		var after_state := _track_state(track)
		var after_track := after_state.get("track_state", {}) as Dictionary
		var after_items := after_track.get("items", []) as Array
		_expect(
			after_items.size() == before_items.size() - 1,
			"%s purchase leaves one moving shared-track vacancy" % domain
		)
		_expect(
			not _track_has_instance(
				after_items,
				str(item.get("instance_id", ""))
			),
			"%s purchased instance leaves the shared track" % domain
		)
		_expect(
			_supply_probe(after_state) == before_supply,
			"%s purchase advances no cursor, instance sequence, or supply RNG"
				% domain
		)

	var debug := track.call("debug_snapshot_v074") as Dictionary
	_expect(
		int(debug.get("acquisition_commit_count", -1)) == 2
			and int(debug.get("vacancy_count", -1)) == 2,
		"two combat purchases leave two authoritative shared-scroll vacancies"
	)
	_expect(
		int(debug.get("immediate_authoritative_refill_count", -1)) == 0
			and int(
				debug.get("supply_cursor_delta_on_acquisition", -1)
			) == 0
			and int(
				debug.get(
					"supply_instance_sequence_delta_on_acquisition",
					-1
				)
			) == 0
			and int(
				debug.get("supply_rng_draw_delta_on_acquisition", -1)
			) == 0,
		"shared sushi purchase metrics prove zero immediate refill and zero supply consumption"
	)


func _new_shared_track(seed_value: int) -> RefCounted:
	var track := _script("shared_track").new() as RefCounted
	if track == null:
		return null
	var registry_contract := _script("registry").call(
		"registry_contract"
	) as Dictionary
	var started := track.call(
		"start_match",
		ROSTER,
		seed_value,
		{
			"balance_profile_id": "V072_STARTER_FREE_FAST",
			"balance_profile_fingerprint": (
				"b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
			),
			"normal_card_ratio_basis_points": 6000,
			"commodity_card_ratio_basis_points": 4000,
			"local_visible_slot_count": 10,
			"match_instance_id": "match.v075.lifecycle.%d" % seed_value,
			"card_definition_registry_id": str(
				registry_contract.get("registry_id", "")
			),
		}
	) as Dictionary
	return track if bool(started.get("accepted", false)) else null


func _combat_track_fixtures(track: RefCounted) -> Dictionary:
	var result := {
		"monster": {},
		"military": {},
	}
	for actor_id in ROSTER:
		var projection := track.call(
			"player_projection_v1",
			actor_id
		) as Dictionary
		var private_facts := (
			projection.get("viewer_private_facts", {}) as Dictionary
		)
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			var item := item_variant as Dictionary
			if (
				not bool(item.get("claimable", false))
				or str(item.get("card_kind", "")) != "normal_card"
			):
				continue
			var definition_id := str(
				item.get("card_definition_id", "")
			)
			var domain := ""
			if definition_id.begins_with("monster."):
				domain = "monster"
			elif definition_id.begins_with("military."):
				domain = "military"
			if (
				not domain.is_empty()
				and (result.get(domain, {}) as Dictionary).is_empty()
			):
				result[domain] = {
					"actor_id": actor_id,
					"item": item.duplicate(true),
				}
	return result


func _transact_track_purchase(
	track: RefCounted,
	port: RefCounted,
	fixture: Dictionary,
	domain: String
) -> Dictionary:
	_request_sequence += 1
	var actor_id := str(fixture.get("actor_id", ""))
	var item := fixture.get("item", {}) as Dictionary
	var source := track.call(
		"visible_source_identity_v1",
		actor_id,
		str(item.get("instance_id", ""))
	) as Dictionary
	var authorization := _script("track_core").call(
		"seal_viewer_segment_authorization_v1",
		{
			"schema_version": 2,
			"capability_id": "capability.v075.lifecycle.%s.%d" % [
				domain,
				_request_sequence,
			],
			"authorization_id": "authorization.v075.lifecycle.%s.%d" % [
				domain,
				_request_sequence,
			],
			"authorization_authority_id": (
				"authority.v075.lifecycle.segment"
			),
			"authorized_actor_id": actor_id,
			"authorized_source_identity_id": str(
				source.get("source_identity_id", "")
			),
			"authorized_source_instance_id": str(
				source.get("source_instance_id", "")
			),
			"authorized_segment_owner_id": actor_id,
			"source_track_revision": int(
				source.get("source_track_revision", 0)
			),
			"inventory_authority_id": (
				"authority.personal_discard.v075.lifecycle"
			),
			"cash_authority_id": "authority.cash.v075.lifecycle",
		}
	) as Dictionary
	var intent := track.call(
		"build_visible_acquisition_intent_v1",
		"request.v075.lifecycle.track.%s.%d" % [
			domain,
			_request_sequence,
		],
		actor_id,
		"purchase_visible_normal_card",
		source,
		authorization
	) as Dictionary
	return port.call("transact_v1", intent) as Dictionary


func _track_state(track: RefCounted) -> Dictionary:
	return (
		(track.call("core_authority_v1") as Dictionary).get(
			"authority_state",
			{}
		) as Dictionary
	).duplicate(true)


func _supply_probe(state: Dictionary) -> Dictionary:
	var track := state.get("track_state", {}) as Dictionary
	var type_supply := state.get("type_supply_state", {}) as Dictionary
	var normal_supply := state.get("normal_supply_state", {}) as Dictionary
	var commodity_supply := (
		state.get("commodity_supply_state", {}) as Dictionary
	)
	var color_supply := (
		(state.get("color_cycle_state", {}) as Dictionary).get(
			"color_supply_state",
			{}
		) as Dictionary
	)
	return {
		"next_instance_sequence": int(
			track.get("next_instance_sequence", 0)
		),
		"type_cursor": int(type_supply.get("cursor", 0)),
		"type_rng_draw_count": int(
			type_supply.get("rng_draw_count", 0)
		),
		"normal_cursor": int(normal_supply.get("cursor", 0)),
		"normal_rng_draw_count": int(
			normal_supply.get("rng_draw_count", 0)
		),
		"commodity_cursor": int(commodity_supply.get("cursor", 0)),
		"commodity_rng_draw_count": int(
			commodity_supply.get("rng_draw_count", 0)
		),
		"color_cursor": int(color_supply.get("cursor", 0)),
		"color_rng_draw_count": int(
			color_supply.get("rng_draw_count", 0)
		),
	}


func _track_has_instance(items: Array, instance_id: String) -> bool:
	for item_variant in items:
		if str((item_variant as Dictionary).get("instance_id", "")) == instance_id:
			return true
	return false


func _test_dbg_purchase_reshuffle_and_draw() -> Dictionary:
	if _definitions.is_empty():
		return {}
	var dbg := _script("dbg_core").new() as RefCounted
	var initialized := dbg.call(
		"initialize",
		OWNER_PLAYER_ID,
		75075123
	) as Dictionary
	_expect(
		bool(initialized.get("initialized", false)),
		"personal DBG initializes"
	)
	if not bool(initialized.get("initialized", false)):
		return {}

	var purchased := {}
	for label in ["monster", "military_region", "military_monster"]:
		var spec := _definitions.get(label, {}) as Dictionary
		var receipt := dbg.call(
			"apply_intent",
			dbg.call(
				"create_authority_intent",
				"request.v075.lifecycle.dbg.purchase.%s" % label,
				"accept_purchase",
				{
					"purchase_receipt_id": (
						"receipt.v075.lifecycle.track.%s" % label
					),
					"card_spec": spec,
				}
			)
		) as Dictionary
		var instance_id := str(receipt.get("created_instance_id", ""))
		purchased[label] = instance_id
		_expect(
			bool(receipt.get("success", false))
				and str(receipt.get("destination_zone", "")) == "discard"
				and not instance_id.is_empty(),
			"%s purchase enters personal discard" % label
		)
		_expect(
			_zone_has_instance(
				(_dbg_state(dbg).get("discard", []) as Array),
				instance_id
			),
			"%s purchased instance exists in personal discard" % label
		)
	_expect(
		(_dbg_state(dbg).get("hand", []) as Array).size() == 5,
		"combat purchases do not enter the current hand immediately"
	)

	var wanted_ids: Array[String] = []
	for label in ["monster", "military_region", "military_monster"]:
		var instance_id := str(purchased.get(label, ""))
		if not instance_id.is_empty():
			wanted_ids.append(instance_id)
	var drawn := {}
	var reshuffle_count := 0
	_record_drawn_instances(_dbg_state(dbg), wanted_ids, drawn)
	for batch_index in range(1, 13):
		var current_hand := (
			_dbg_state(dbg).get("hand", []) as Array
		).duplicate(true)
		for card_index in range(current_hand.size()):
			var card := current_hand[card_index] as Dictionary
			var play_receipt := dbg.call(
				"apply_intent",
				dbg.call(
					"create_intent",
					"request.v075.lifecycle.dbg.play.%02d.%02d" % [
						batch_index,
						card_index,
					],
					OWNER_PLAYER_ID,
					"play_card",
					{
						"instance_id": str(
							card.get("instance_id", "")
						),
					},
					"player_explicit"
				)
			) as Dictionary
			_expect(
				bool(play_receipt.get("success", false)),
				"batch %d card %d plays through normal DBG" % [
					batch_index,
					card_index,
				]
			)
		var complete_receipt := dbg.call(
			"apply_intent",
			dbg.call(
				"create_authority_intent",
				"request.v075.lifecycle.dbg.complete.%02d" % batch_index,
				"complete_batch",
				{}
			)
		) as Dictionary
		_expect(
			bool(complete_receipt.get("success", false)),
			"batch %d completes through normal DBG" % batch_index
		)
		reshuffle_count += int(
			complete_receipt.get("reshuffle_count", 0)
		)
		_record_drawn_instances(_dbg_state(dbg), wanted_ids, drawn)
		var maintenance_receipt := dbg.call(
			"apply_intent",
			dbg.call(
				"create_intent",
				"request.v075.lifecycle.dbg.maintenance.%02d"
					% batch_index,
				OWNER_PLAYER_ID,
				"end_maintenance",
				{},
				"player_explicit"
			)
		) as Dictionary
		_expect(
			bool(maintenance_receipt.get("success", false)),
			"batch %d maintenance closes" % batch_index
		)
		if drawn.size() == wanted_ids.size():
			break

	_expect(
		reshuffle_count > 0,
		"normal DBG naturally reshuffles the personal discard"
	)
	for label in ["monster", "military_region", "military_monster"]:
		_expect(
			drawn.has(str(purchased.get(label, ""))),
			"%s purchased instance is naturally drawn after reshuffle" % label
		)
	return {
		"dbg": dbg,
		"monster_instance_id": str(purchased.get("monster", "")),
		"region_military_instance_id": str(
			purchased.get("military_region", "")
		),
		"monster_military_instance_id": str(
			purchased.get("military_monster", "")
		),
	}


func _dbg_state(dbg: RefCounted) -> Dictionary:
	return (
		(dbg.call("core_authority_snapshot") as Dictionary).get(
			"state",
			{}
		) as Dictionary
	).duplicate(true)


func _zone_has_instance(zone: Array, instance_id: String) -> bool:
	for card_variant in zone:
		if str((card_variant as Dictionary).get("instance_id", "")) == instance_id:
			return true
	return false


func _record_drawn_instances(
	state: Dictionary,
	wanted_ids: Array[String],
	drawn: Dictionary
) -> void:
	for card_variant in state.get("hand", []) as Array:
		var instance_id := str(
			(card_variant as Dictionary).get("instance_id", "")
		)
		if wanted_ids.has(instance_id):
			drawn[instance_id] = true


func _test_military_one_shot_lifecycle(dbg_result: Dictionary) -> void:
	var core := _script("military_core")
	var region_card_id := str(
		dbg_result.get("region_military_instance_id", "")
	)
	var monster_card_id := str(
		dbg_result.get("monster_military_instance_id", "")
	)
	var region_definition := (
		_definitions.get("military_region", {}) as Dictionary
	)
	var monster_definition := (
		_definitions.get("military_monster", {}) as Dictionary
	)

	var facilities := [
		_facility(
			"facility.warehouse.c",
			"warehouse",
			"shipping",
			"region.075"
		),
		_facility(
			"facility.factory.a",
			"factory",
			"industry",
			"region.075"
		),
		_facility(
			"facility.market.b",
			"market",
			"commerce",
			"region.075"
		),
	]
	(facilities[0] as Dictionary)["warehouse_stock"] = [
		"private.stock.must.not.leak",
	]
	var region_request := core.call(
		"build_region_request",
		"request.v075.lifecycle.region",
		"mission.v075.lifecycle.region",
		OWNER_PLAYER_ID,
		region_card_id,
		"slot.v075.lifecycle.region",
		"reservation.v075.lifecycle.region",
		"region.075"
	) as Dictionary
	var region_authority := core.call(
		"build_card_authority",
		str(region_definition.get("definition_id", "")),
		1,
		8,
		4,
		"effect.v075.lifecycle.region",
		31
	) as Dictionary
	var region_lock := core.call(
		"lock_region_assault",
		region_request,
		region_authority,
		12,
		facilities
	) as Dictionary
	var region_receipt := core.call(
		"resolve_region_assault",
		region_lock,
		facilities
	) as Dictionary
	_expect(
		bool(
			(core.call(
				"receipt_validation_report",
				region_receipt
			) as Dictionary).get("valid", false)
		),
		"assault_region receipt validates"
	)
	_expect(
		str(region_receipt.get("outcome", "")) == "resolved"
			and int(
				region_receipt.get("allocated_damage_total", -1)
			) == 8
			and (
				region_receipt.get("facility_damage_intents", []) as Array
			).size() == 3,
		"assault_region distributes one fixed total budget"
	)
	_expect(
		not JSON.stringify(region_lock).contains(
			"private.stock.must.not.leak"
		)
			and not JSON.stringify(region_receipt).contains(
				"private.stock.must.not.leak"
			),
		"region assault typed intents exclude private warehouse stock"
	)
	_assert_withdraw_to_discard(
		region_receipt,
		region_card_id,
		"assault_region"
	)

	var target_at_lock := _monster(
		"monster.rival.lifecycle",
		4,
		8,
		"region.021"
	)
	var target_at_resolution := _monster(
		"monster.rival.lifecycle",
		4,
		9,
		"region.028"
	)
	var monster_request := core.call(
		"build_monster_request",
		"request.v075.lifecycle.monster",
		"mission.v075.lifecycle.monster",
		OWNER_PLAYER_ID,
		monster_card_id,
		"slot.v075.lifecycle.monster",
		"reservation.v075.lifecycle.monster",
		"monster.rival.lifecycle"
	) as Dictionary
	var monster_authority := core.call(
		"build_card_authority",
		str(monster_definition.get("definition_id", "")),
		1,
		5,
		7,
		"effect.v075.lifecycle.monster",
		32
	) as Dictionary
	var monster_lock := core.call(
		"lock_monster_assault",
		monster_request,
		monster_authority,
		[target_at_lock]
	) as Dictionary
	var monster_receipt := core.call(
		"resolve_monster_assault",
		monster_lock,
		[target_at_resolution]
	) as Dictionary
	_expect(
		bool(
			(core.call(
				"receipt_validation_report",
				monster_receipt
			) as Dictionary).get("valid", false)
		),
		"assault_monster receipt validates"
	)
	var monster_intents := (
		monster_receipt.get("monster_damage_intents", []) as Array
	)
	var monster_intent := (
		monster_intents[0] as Dictionary
		if monster_intents.size() == 1
		else {}
	)
	_expect(
		monster_intents.size() == 1
			and str(
				monster_intent.get(
					"target_monster_source_instance_id",
					""
				)
			) == "monster.rival.lifecycle"
			and int(
				monster_intent.get("expected_source_generation", -1)
			) == 4
			and str(
				monster_intent.get("public_target_region_id", "")
			) == "region.028"
			and int(monster_receipt.get("retarget_count", -1)) == 0,
		"assault_monster follows the locked identity without retargeting"
	)
	_assert_withdraw_to_discard(
		monster_receipt,
		monster_card_id,
		"assault_monster"
	)


func _assert_withdraw_to_discard(
	receipt: Dictionary,
	card_instance_id: String,
	label: String
) -> void:
	var withdrawal := receipt.get(
		"military_withdrawal_intent",
		{}
	) as Dictionary
	var dbg_intent := receipt.get(
		"dbg_lifecycle_intent",
		{}
	) as Dictionary
	_expect(
		str(receipt.get("mission_state_after", "")) == "withdrawn"
			and str(withdrawal.get("state_before", ""))
				== "military_mission_resolving"
			and str(withdrawal.get("state_after", "")) == "withdrawn",
		"%s ends in withdrawn state" % label
	)
	_expect(
		str(dbg_intent.get("card_instance_id", ""))
				== card_instance_id
			and str(dbg_intent.get("expected_zone", ""))
				== "military_mission_resolving"
			and str(dbg_intent.get("destination_zone", ""))
				== "personal_discard"
			and bool(dbg_intent.get("normal_dbg_member", false))
			and bool(dbg_intent.get("reshuffle_eligible", false)),
		"%s returns the exact normal DBG card to personal discard" % label
	)
	_expect(
		not bool(withdrawal.get("persistent_source_created", true))
			and not bool(withdrawal.get("bound_action_created", true))
			and int(receipt.get("persistent_source_count", -1)) == 0
			and int(receipt.get("bound_action_count", -1)) == 0
			and int(receipt.get("direct_dbg_write_count", -1)) == 0
			and not bool(dbg_intent.get("direct_mutation_allowed", true)),
		"%s creates no persistent source or bound action and delegates DBG mutation"
			% label
	)


func _facility(
	facility_id: String,
	facility_type: String,
	industry_id: String,
	region_id: String
) -> Dictionary:
	return {
		"facility_id": facility_id,
		"facility_generation": 1,
		"owner_player_id": "player.rival.one",
		"region_id": region_id,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"status": "active",
	}


func _monster(
	source_instance_id: String,
	source_generation: int,
	source_revision: int,
	region_id: String
) -> Dictionary:
	return {
		"source_instance_id": source_instance_id,
		"source_generation": source_generation,
		"damage_revision": source_revision,
		"owner_player_id": "player.rival.two",
		"region_id": region_id,
		"status": "active",
	}


func _script(label: String) -> Script:
	return _scripts.get(label) as Script


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print(
		"V075_COMBAT_CARD_DBG_LIFECYCLE_INTEGRATION_TEST|"
		+ "status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
