extends SceneTree

const Owner := preload(
	"res://scripts/v075_runtime/v075_ruleset_runtime_owner.gd"
)
const OWNER_PATH := (
	"res://scripts/v075_runtime/v075_ruleset_runtime_owner.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := run_focused()
	print((
		"V075_RULESET_RUNTIME_OWNER_TEST"
		+ "|status=%s|passed=%d|total=%d|failures=%s"
	) % [
		"PASS" if bool(result.get("success", false)) else "FAIL",
		int(result.get("passed", 0)),
		int(result.get("total", 0)),
		JSON.stringify(result.get("failures", [])),
	])
	quit(0 if bool(result.get("success", false)) else 1)


static func run_focused() -> Dictionary:
	var state := {
		"checks": 0,
		"failures": [],
	}
	var owner := Owner.new()
	var identity := owner.identity_snapshot()
	_expect(
		state,
		str(identity.get("ruleset_id", "")) == "v0.7.5",
		"ruleset identity is v0.7.5"
	)
	_expect(
		state,
		str(identity.get("constitution_id", ""))
		== "space_syndicate.v075.complete",
		"constitution identity is V0.7.5 complete"
	)
	_expect(
		state,
		str(identity.get("sample_mode_id", "")) == "NEW_V075_GAME",
		"sample mode accepts only NEW_V075_GAME"
	)
	_expect(
		state,
		str(identity.get("sample_build_id", ""))
		== "alpha_0_5_c2.v075.monster_military.v1",
		"sample build identity is frozen"
	)
	_expect(
		state,
		str(identity.get("inherited_noncombat_ruleset_id", ""))
		== "v0.7.4",
		"noncombat inheritance source is V0.7.4"
	)
	_expect(
		state,
		bool(identity.get("new_game_only", false)),
		"identity is new-game-only"
	)
	_expect(
		state,
		not bool(identity.get("save_enabled", true))
		and not bool(identity.get("continue_enabled", true)),
		"identity disables Save and Continue"
	)
	_expect(
		state,
		int(identity.get("minimum_player_count", 0)) == 3
		and int(identity.get("maximum_player_count", 0)) == 8
		and int(identity.get("required_local_human_count", 0)) == 1,
		"identity freezes 3-8 players and one local human"
	)
	_expect(
		state,
		int(identity.get("current_supported_region_count_min", 0)) == 6
		and int(identity.get("current_supported_region_count_max", 0)) == 30
		and not bool(identity.get("region_count_fixed", true)),
		"identity inherits dynamic 6-30 regions"
	)

	var capabilities := owner.capability_snapshot()
	var new_game := capabilities.get("new_game", {}) as Dictionary
	var player_count := new_game.get("player_count", {}) as Dictionary
	var human_count := (
		new_game.get("local_human_count", {}) as Dictionary
	)
	var ai_count := new_game.get("ai_player_count", {}) as Dictionary
	var map_settings := new_game.get("map_settings", {}) as Dictionary
	var region_count := map_settings.get("region_count", {}) as Dictionary
	_expect(
		state,
		bool(new_game.get("enabled", false))
		and str(new_game.get("mode_id", "")) == "NEW_V075_GAME",
		"new-game capability exposes the V0.7.5 mode"
	)
	_expect(
		state,
		int(player_count.get("minimum", 0)) == 3
		and int(player_count.get("maximum", 0)) == 8,
		"capability preserves player limits"
	)
	_expect(
		state,
		int(human_count.get("minimum", 0)) == 1
		and int(human_count.get("maximum", 0)) == 1
		and int(ai_count.get("minimum", 0)) == 2
		and int(ai_count.get("maximum", 0)) == 7,
		"capability preserves one human and derived AI range"
	)
	_expect(
		state,
		int(region_count.get("minimum", 0)) == 6
		and int(region_count.get("maximum", 0)) == 30,
		"capability preserves the V0.7.4 region range"
	)
	_expect(
		state,
		(map_settings.get("geography_complexities", []) as Array)
		== ["SIMPLE", "STANDARD", "COMPLEX"],
		"capability preserves all geography complexities"
	)
	_expect(
		state,
		(map_settings.get("land_ocean_profiles", []) as Array)
		== ["CONTINENTAL", "BALANCED", "ARCHIPELAGO"],
		"capability preserves all land-ocean profiles"
	)
	_expect(
		state,
		not bool((
			capabilities.get("save_to_disk", {}) as Dictionary
		).get("enabled", true))
		and not bool((
			capabilities.get("continue_from_disk", {}) as Dictionary
		).get("enabled", true)),
		"capability disables disk Save and Continue"
	)

	var default_map := owner.normalize_map_request({})
	_expect(
		state,
		bool(default_map.get("accepted", false)),
		"default map request is legal"
	)
	var default_request := default_map.get("request", {}) as Dictionary
	_expect(
		state,
		int(default_request.get("schema_version", 0)) == 1
		and str(default_request.get("ruleset_id", "")) == "v0.7.5",
		"default map request carries V0.7.5 identity"
	)
	_expect(
		state,
		int(default_request.get("map_seed", 0)) == 900626424
		and int(default_request.get("region_count", 0)) == 16
		and str(default_request.get("geography_complexity", ""))
		== "STANDARD"
		and str(default_request.get("land_ocean_profile", ""))
		== "BALANCED",
		"default map values inherit the V0.7.4 sample"
	)

	for boundary_region_count in [6, 30]:
		var boundary := owner.normalize_map_request({
			"region_count": boundary_region_count,
		})
		_expect(
			state,
			bool(boundary.get("accepted", false)),
			"region boundary %d is accepted" % boundary_region_count
		)
	for complexity in ["SIMPLE", "STANDARD", "COMPLEX"]:
		var complexity_result := owner.normalize_map_request({
			"geography_complexity": complexity,
		})
		_expect(
			state,
			bool(complexity_result.get("accepted", false)),
			"geography complexity %s is accepted" % complexity
		)
	for profile in ["CONTINENTAL", "BALANCED", "ARCHIPELAGO"]:
		var profile_result := owner.normalize_map_request({
			"land_ocean_profile": profile,
		})
		_expect(
			state,
			bool(profile_result.get("accepted", false)),
			"land-ocean profile %s is accepted" % profile
		)

	_expect_rejection(
		state,
		owner.normalize_map_request({"region_count": 5}),
		"region_count_out_of_supported_range",
		"region count below six is rejected"
	)
	_expect_rejection(
		state,
		owner.normalize_map_request({"region_count": 31}),
		"region_count_out_of_supported_range",
		"region count above thirty is rejected"
	)
	_expect_rejection(
		state,
		owner.normalize_map_request({"geography_complexity": "EXTREME"}),
		"geography_complexity_invalid",
		"unknown geography complexity is rejected"
	)
	_expect_rejection(
		state,
		owner.normalize_map_request({"land_ocean_profile": "ALL_LAND"}),
		"land_ocean_profile_invalid",
		"unknown land-ocean profile is rejected"
	)

	var maximum_request := _valid_request({
		"player_count": 8,
		"ai_player_count": 7,
		"map_request": {
			"region_count": 30,
			"geography_complexity": "complex",
			"land_ocean_profile": "archipelago",
			"map_seed": 17,
		},
	})
	var maximum_valid := owner.validate_new_game_request(maximum_request)
	_expect(
		state,
		bool(maximum_valid.get("accepted", false)),
		"eight-player complex archipelago request is accepted"
	)
	var maximum_map := maximum_valid.get("map_request", {}) as Dictionary
	_expect(
		state,
		int(maximum_map.get("region_count", 0)) == 30
		and str(maximum_map.get("geography_complexity", ""))
		== "COMPLEX"
		and str(maximum_map.get("land_ocean_profile", ""))
		== "ARCHIPELAGO",
		"valid request normalizes inherited map enums"
	)

	_expect_rejection(
		state,
		owner.validate_new_game_request(_valid_request({
			"mode_id": "NEW_V074_GAME",
		})),
		"v075_new_game_only",
		"V0.7.4 mode is not accepted by the independent owner"
	)
	_expect_rejection(
		state,
		owner.validate_new_game_request(_valid_request({
			"session_id": "   ",
		})),
		"session_id_required",
		"blank session identity is rejected"
	)
	_expect_rejection(
		state,
		owner.validate_new_game_request(_valid_request({
			"player_count": 2,
			"ai_player_count": 1,
		})),
		"player_count_out_of_range",
		"two-player request is rejected"
	)
	_expect_rejection(
		state,
		owner.validate_new_game_request(_valid_request({
			"player_count": 9,
			"ai_player_count": 8,
		})),
		"player_count_out_of_range",
		"nine-player request is rejected"
	)
	_expect_rejection(
		state,
		owner.validate_new_game_request(_valid_request({
			"local_human_count": 2,
			"ai_player_count": 2,
		})),
		"exactly_one_local_human_required",
		"two local humans are rejected"
	)
	_expect_rejection(
		state,
		owner.validate_new_game_request(_valid_request({
			"ai_player_count": 1,
		})),
		"ai_player_count_mismatch",
		"AI count mismatch is rejected"
	)
	_expect_rejection(
		state,
		owner.validate_new_game_request(_valid_request({
			"map_request": "not_a_dictionary",
		})),
		"map_genesis_request_invalid",
		"non-dictionary map request is rejected"
	)

	var activation := owner.activate_for_new_game(
		"  session.v075.owner.1  ",
		4,
		1,
		{
			"region_count": 24,
			"geography_complexity": "simple",
			"land_ocean_profile": "continental",
			"map_seed": 99,
		}
	)
	_expect(
		state,
		bool(activation.get("accepted", false))
		and str(activation.get("reason_code", ""))
		== "v075_new_game_ruleset_activated",
		"valid new game activates the V0.7.5 owner"
	)
	var activation_identity := activation.get("identity", {}) as Dictionary
	var activation_map := activation.get("map_request", {}) as Dictionary
	_expect(
		state,
		str(activation_identity.get("ruleset_id", "")) == "v0.7.5"
		and int(activation_identity.get("activation_count", 0)) == 1
		and str(activation_identity.get("last_session_id", ""))
		== "session.v075.owner.1",
		"activation receipt carries stable identity and trimmed session"
	)
	_expect(
		state,
		int(activation_map.get("region_count", 0)) == 24
		and str(activation_map.get("geography_complexity", ""))
		== "SIMPLE"
		and str(activation_map.get("land_ocean_profile", ""))
		== "CONTINENTAL",
		"activation returns the normalized inherited map request"
	)
	owner.activate_for_new_game("", 4)
	_expect(
		state,
		int(owner.identity_snapshot().get("activation_count", 0)) == 1,
		"rejected activation does not mutate activation count"
	)

	var save_receipt := owner.request_save("save.request.1")
	var load_receipt := owner.request_load("load.request.1")
	_expect_rejection(
		state,
		save_receipt,
		"v075_sample_save_disabled",
		"Save request is rejected"
	)
	_expect_rejection(
		state,
		load_receipt,
		"v075_sample_continue_disabled",
		"Continue request is rejected"
	)
	_expect(
		state,
		int(save_receipt.get("file_access_count", -1)) == 0
		and int(load_receipt.get("file_access_count", -1)) == 0
		and int(save_receipt.get(
			"production_save_slot_write_count",
			-1
		)) == 0
		and int(load_receipt.get(
			"production_save_slot_write_count",
			-1
		)) == 0,
		"persistence rejection performs zero file or Save-slot writes"
	)

	var debug := owner.debug_snapshot()
	_expect(
		state,
		int(debug.get("save_request_count", 0)) == 1
		and int(debug.get("load_request_count", 0)) == 1,
		"debug snapshot counts rejected persistence requests"
	)
	_expect(
		state,
		int(debug.get("v074_map_contract_inheritance_count", 0)) == 1
		and int(debug.get("v074_save_apply_count", -1)) == 0
		and int(debug.get("v074_save_write_count", -1)) == 0,
		"V0.7.4 map contract is inherited without Save reuse"
	)
	_expect(
		state,
		int(debug.get("production_save_slot_write_count", -1)) == 0
		and int(debug.get("save_dual_write_count", -1)) == 0
		and int(debug.get("gameplay_mutation_count", -1)) == 0
		and int(debug.get("save_owner_count", -1)) == 0
		and int(debug.get("rng_owner_count", -1)) == 0,
		"ruleset owner owns no Save slot, RNG, or gameplay mutation"
	)

	var owner_source := FileAccess.get_file_as_string(OWNER_PATH)
	_expect(
		state,
		not owner_source.contains("V074RulesetRuntimeOwner")
		and not owner_source.contains(
			"res://scripts/v074_runtime/v074_ruleset_runtime_owner.gd"
		),
		"V0.7.5 owner has no V0.7.4 runtime class dependency"
	)
	_expect(
		state,
		not owner_source.contains("main.gd")
		and not owner_source.contains("RuntimeComposition")
		and not owner_source.contains("ApplicationFlow"),
		"ruleset owner has no Main, Composition, or Flow dependency"
	)

	owner.free()
	var failures := state.get("failures", []) as Array
	return {
		"success": failures.is_empty(),
		"passed": int(state.get("checks", 0)) - failures.size(),
		"total": int(state.get("checks", 0)),
		"failures": failures.duplicate(true),
	}


static func _valid_request(overrides: Dictionary = {}) -> Dictionary:
	var request := {
		"mode_id": "NEW_V075_GAME",
		"session_id": "session.v075.test",
		"player_count": 4,
		"local_human_count": 1,
		"ai_player_count": 3,
		"map_request": {},
	}
	request.merge(overrides, true)
	return request


static func _expect_rejection(
	state: Dictionary,
	result: Dictionary,
	reason_code: String,
	message: String
) -> void:
	_expect(
		state,
		not bool(result.get("accepted", true))
		and str(result.get("reason_code", "")) == reason_code,
		message + ": " + JSON.stringify(result)
	)


static func _expect(
	state: Dictionary,
	condition: bool,
	message: String
) -> void:
	state["checks"] = int(state.get("checks", 0)) + 1
	if condition:
		return
	var failures := state.get("failures", []) as Array
	failures.append(message)
	state["failures"] = failures
	push_error(message)