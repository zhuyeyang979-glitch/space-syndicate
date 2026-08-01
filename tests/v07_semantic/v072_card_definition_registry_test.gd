extends SceneTree

const Registry := preload(
	"res://scripts/v07_semantic/v072_card_definition_registry.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_identity()
	_test_starter_definitions()
	_test_standard_definitions()
	_test_merge_contract()
	_test_detachment()
	_finish()


func _test_identity() -> void:
	var contract := Registry.registry_contract()
	_expect(Registry.RULESET_ID == "v0.7.2", "registry targets V0.7.2")
	_expect(
		Registry.BALANCE_PROFILE_ID == "V072_STARTER_FREE_FAST"
			and Registry.BALANCE_PROFILE_FINGERPRINT
				== "b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
			and Registry.PROFILE_FINGERPRINT_INPUT.sha256_text()
				== Registry.BALANCE_PROFILE_FINGERPRINT,
		"registry binds the canonical V0.7.2 profile fingerprint"
	)
	_expect(
		int(contract.get("starter_definition_count", 0)) == 12
			and int(contract.get("standard_definition_count", 0)) == 48,
		"registry owns 12 Starter and 48 rank-one-to-four standard definitions"
	)
	_expect(
		contract.get("starter_creation_allowed_after_genesis") == false
			and contract.get("starter_track_spawn_allowed") == false
			and contract.get("starter_standard_l1_merge_allowed") == true
			and contract.get("starter_zero_cost_privilege_inherited") == false,
		"registry closes Starter creation, spawn, and merge privilege semantics"
	)


func _test_starter_definitions() -> void:
	var expected_ids := [
		"starter.facility.factory.life.rank_1",
		"starter.facility.market.life.rank_1",
		"starter.facility.factory.energy.rank_1",
		"starter.facility.market.energy.rank_1",
		"starter.facility.factory.industry.rank_1",
		"starter.facility.market.industry.rank_1",
		"starter.facility.factory.technology.rank_1",
		"starter.facility.market.technology.rank_1",
		"starter.facility.factory.commerce.rank_1",
		"starter.facility.market.commerce.rank_1",
		"starter.facility.factory.shipping.rank_1",
		"starter.facility.market.shipping.rank_1",
	]
	_expect(Registry.starter_definition_ids() == expected_ids, "Starter IDs are exact and ordered")
	var seen := {}
	for definition_id in expected_ids:
		var definition := Registry.definition(definition_id)
		_expect(Registry.definition_error(definition).is_empty(), "%s validates" % definition_id)
		_expect(
			str(definition.get("origin_class", "")) == "starter_bootstrap"
				and int(definition.get("level", 0)) == 1
				and str(definition.get("asset_cost_profile", ""))
					== "starter_zero_asset",
			"%s has stable Starter identity" % definition_id
		)
		_expect(
			int(definition.get("primary_asset_cost", -1)) == 0
				and int(definition.get("secondary_asset_cost", -1)) == 0
				and int(definition.get("any_asset_cost", -1)) == 0,
			"%s has zero six-color asset cost" % definition_id
		)
		_expect(
			definition.get("starter_badge") == true
				and str(definition.get("starter_badge_asset_key", ""))
					== "card.badge.starter"
				and definition.get("track_spawn_allowed") == false
				and definition.get("purchase_allowed") == false,
			"%s is badged, genesis-only, and absent from Track" % definition_id
		)
		seen[definition_id] = true
	_expect(seen.size() == 12, "every Starter definition is unique")


func _test_standard_definitions() -> void:
	var track_ids := Registry.track_spawn_definition_ids()
	_expect(track_ids.size() == 12, "Track has exactly 12 standard L1 facility definitions")
	for definition_id in track_ids:
		var definition := Registry.definition(definition_id)
		_expect(
			Registry.definition_error(definition).is_empty()
				and str(definition.get("origin_class", "")) == "standard"
				and int(definition.get("level", 0)) == 1,
			"%s is a valid standard L1 definition" % definition_id
		)
		_expect(
			int(definition.get("primary_asset_cost", -1)) == 1
				and str(definition.get("asset_cost_profile", "")) == "standard_rank_1"
				and definition.get("starter_badge") == false
				and definition.get("track_spawn_allowed") == true
				and definition.get("purchase_allowed") == true,
			"%s is paid, purchasable standard Track supply" % definition_id
		)
	for level in range(2, 5):
		var definition_id := Registry.standard_definition_id("factory", "life", level)
		var definition := Registry.definition(definition_id)
		_expect(
			int(definition.get("primary_asset_cost", -1)) == level
				and str(definition.get("asset_cost_profile", ""))
					== "standard_rank_%d" % level
				and definition.get("track_spawn_allowed") == false,
			"standard rank %d costs %d and cannot spawn on Track" % [level, level]
		)
	for starter_id in Registry.starter_definition_ids():
		_expect(not track_ids.has(starter_id), "%s never enters Track supply" % starter_id)


func _test_merge_contract() -> void:
	var starter_id := "starter.facility.factory.life.rank_1"
	var standard_id := "facility.factory.life.rank_1"
	var merged := Registry.starter_standard_merge(starter_id, standard_id)
	var output := merged.get("output_definition", {}) as Dictionary
	_expect(
		merged.get("accepted") == true
			and str(merged.get("output_definition_id", ""))
				== "facility.factory.life.rank_2"
			and str(merged.get("output_origin_class", "")) == "standard",
		"Starter plus matching standard L1 produces standard L2"
	)
	_expect(
		merged.get("starter_privilege_consumed") == true
			and str(output.get("asset_cost_profile", "")) == "standard_rank_2"
			and int(output.get("primary_asset_cost", -1)) == 2
			and output.get("starter_badge") == false,
		"merge consumes the free privilege and outputs paid rank two"
	)
	_expect(
		Registry.starter_standard_merge(
			starter_id,
			"facility.factory.energy.rank_1"
		).get("accepted") == false,
		"different colors cannot merge"
	)
	_expect(
		Registry.starter_standard_merge(
			starter_id,
			"facility.market.life.rank_1"
		).get("accepted") == false,
		"different facility types cannot merge"
	)
	_expect(
		Registry.starter_standard_merge(
			standard_id,
			standard_id
		).get("accepted") == false,
		"the explicit Starter-standard path cannot merge two standard cards"
	)


func _test_detachment() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/v07_semantic/v072_card_definition_registry.gd"
	).to_lower()
	_expect(
		not source.contains("randomnumbergenerator")
			and not source.contains("res://scenes/")
			and not source.contains("scripts/main.gd")
			and not source.contains("v06saveownerregistry"),
		"definition registry has no RNG, scene, Main, or production Registry connection"
	)
	_expect(
		(Registry.registry_contract().get("rng_stream_ids", []) as Array).is_empty()
			and int(Registry.registry_contract().get(
				"production_runtime_connection_count", -1
			)) == 0,
		"definition registry adds no RNG stream or production connection"
	)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V072_CARD_DEFINITION_REGISTRY_TEST|status=PASS|checks=%d|failures=0|starter=12|standard=48"
				% _checks
		)
		quit(0)
		return
	for failure in _failures:
		push_error("V072_CARD_DEFINITION_REGISTRY_TEST|%s" % failure)
	push_error(
		"V072_CARD_DEFINITION_REGISTRY_TEST|status=FAIL|checks=%d|failures=%d"
			% [_checks, _failures.size()]
	)
	quit(1)
