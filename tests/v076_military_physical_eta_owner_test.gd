extends SceneTree

const EtaOwner := preload(
	"res://scripts/v076/military/v076_military_physical_eta_owner_v1.gd"
)
const ProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)
const GeodesicMetric := preload(
	"res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd"
)

const SEED_COUNT := 1000
const FACE_COUNT := 320

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile_authority := ProfileCatalog.new()
	var document := profile_authority.load_document()
	var profiles: Array = document.get("records", []) as Array
	_expect(profiles.size() == 28, "all 28 Profiles are available to ETA")
	var owner := EtaOwner.new()
	var configured := owner.configure(profile_authority)
	_expect(bool(configured.get("accepted", false)), "the unique ETA Owner configures")
	var debug := owner.debug_snapshot()
	_expect(
		bool(debug.get("owns_eta_formula", false))
			and str(debug.get("distance_owner", ""))
				== "V076SharedHalfEdgePartitionV1"
			and str(debug.get("speed_owner", ""))
				== "V076MilitaryUnitProfileAuthority",
		"ETA owns only the distance-plus-speed formula"
	)
	_expect(
		not bool(debug.get("owns_tick", true))
			and not bool(debug.get("owns_authority_sequence", true))
			and not bool(debug.get("owns_rng", true))
			and not bool(debug.get("owns_replay", true))
			and not bool(debug.get("owns_map_topology", true))
			and not bool(debug.get("owns_route_geometry", true))
			and not bool(debug.get("owns_military_unit_state", true))
			and not bool(debug.get("owns_asset_quantity", true))
			and not bool(debug.get("owns_card_catalog", true))
			and not bool(debug.get("owns_private_direct_action_authorization", true))
			and not bool(debug.get("owns_attack_resolution", true))
			and not bool(debug.get("owns_presentation", true)),
		"ETA exposes no inherited authority surface"
	)
	_expect(int(debug.get("duplicate_pathfinder_count", -1)) == 0,
		"ETA contains no duplicate pathfinder")
	_expect(int(debug.get("duplicate_speed_table_count", -1)) == 0,
		"ETA contains no duplicate speed table")

	_expect(_eta(0, 7) == 0, "distance zero has ETA zero")
	_expect(_eta(1, 7) == 1, "distance one rounds to one tick")
	_expect(_eta(20, 5) == 4, "exact division is unchanged")
	_expect(_eta(21, 5) == 5, "non-divisible distance rounds up")
	_expect(_eta(9, 1) == 9, "speed one preserves distance")
	_expect(not bool(EtaOwner.calculate_eta_ticks(1, 0).get("accepted", true)),
		"zero speed fails closed")
	_expect(not bool(EtaOwner.calculate_eta_ticks(1, -1).get("accepted", true)),
		"negative speed fails closed")
	_expect(not bool(EtaOwner.calculate_eta_ticks(-1, 1).get("accepted", true)),
		"negative distance fails closed")
	_expect(not bool(EtaOwner.calculate_eta_ticks(1.0, 1).get("accepted", true)),
		"float distance fails closed")
	_expect(not bool(EtaOwner.calculate_eta_ticks(1, 1.0).get("accepted", true)),
		"float speed fails closed")
	_expect(_eta(9_007_199_254_740_991, 9_007_199_254_740_991) == 1,
		"maximum canonical integer remains deterministic")
	_expect(_eta(9_007_199_254_740_990, 3) == 3_002_399_751_580_330,
		"large integer ceiling division is exact")

	var base_route_result := _route(0, 137)
	_expect(bool(base_route_result.get("accepted", false)),
		"canonical geodesic distance port builds the route")
	var base_profile := profiles[0] as Dictionary
	var base_request := _request(base_profile, base_route_result)
	var base_result := owner.calculate_eta(base_request)
	_expect(bool(base_result.get("accepted", false)),
		"one canonical Profile and route produce ETA")
	var base_receipt := base_result.get("receipt", {}) as Dictionary
	_expect(bool(EtaOwner.receipt_validation_report(
		base_receipt,
		base_route_result.get("route", {}) as Dictionary
	).get("valid", false)), "the canonical ETA receipt validates")
	_expect(not str(base_result.get("receipt_fingerprint", "")).is_empty(),
		"ETA receipt has one canonical fingerprint")
	_expect(int(base_result.get("eta_ticks", 0)) >= 1,
		"positive canonical distance yields at least one tick")
	_expect(not bool(base_receipt.get("teleport_allowed", true)),
		"ETA never authorizes teleport")

	var profile_ids := {}
	var family_ids := {}
	var ranks := {}
	for profile_variant in profiles:
		var profile := profile_variant as Dictionary
		var calculated := owner.calculate_eta(_request(profile, base_route_result))
		if bool(calculated.get("accepted", false)):
			profile_ids[str(profile.get("profile_id", ""))] = true
			family_ids[str(profile.get("family_id", ""))] = true
			ranks[int(profile.get("rank", 0))] = true
	_expect(profile_ids.size() == 28, "all 28 Profiles calculate ETA")
	_expect(family_ids.size() == 7, "all seven families calculate ETA")
	_expect(ranks.size() == 4, "all four ranks calculate ETA")

	var slow_profile := profile_authority.profile_by_id(
		"v076.military.missile_emplacement.rank_1"
	)
	var fast_profile := profile_authority.profile_by_id(
		"v075.military.air_superiority_fighter.rank_4"
	)
	var slow_eta := int(owner.calculate_eta(_request(
		slow_profile, base_route_result
	)).get("eta_ticks", 0))
	var fast_eta := int(owner.calculate_eta(_request(
		fast_profile, base_route_result
	)).get("eta_ticks", 0))
	_expect(slow_eta > fast_eta, "different authored speeds produce different ETA")
	var short_route := _route(0, 1)
	var short_eta := int(owner.calculate_eta(_request(
		slow_profile, short_route
	)).get("eta_ticks", 0))
	_expect(short_eta < slow_eta, "same speed and shorter distance produce smaller ETA")

	var zero_route := _route(11, 11)
	var zero_result := owner.calculate_eta(_request(base_profile, zero_route))
	_expect(bool(zero_result.get("accepted", false))
		and int(zero_result.get("eta_ticks", -1)) == 0,
		"zero-length canonical route remains ETA zero")
	var region_result := owner.calculate_eta(_request(base_profile, base_route_result))
	var monster_result := owner.calculate_eta(_request(base_profile, base_route_result))
	_expect(region_result == monster_result,
		"region and monster labels do not alter physical ETA")

	var profile_tamper := base_request.duplicate(true)
	profile_tamper["expected_profile_fingerprint_sha256"] = "0".repeat(64)
	_expect(not bool(owner.calculate_eta(profile_tamper).get("accepted", true)),
		"Profile fingerprint tamper fails closed")
	var topology_tamper := base_request.duplicate(true)
	(topology_tamper.get("route", {}) as Dictionary)["topology_sha256"] = "0".repeat(64)
	_expect(not bool(owner.calculate_eta(topology_tamper).get("accepted", true)),
		"Topology SHA tamper fails closed")
	var route_sha_tamper := base_request.duplicate(true)
	route_sha_tamper["route_sha256"] = "0".repeat(64)
	_expect(not bool(owner.calculate_eta(route_sha_tamper).get("accepted", true)),
		"route fingerprint tamper fails closed")
	var unknown_profile := base_request.duplicate(true)
	unknown_profile["profile_id"] = "v076.military.unknown.rank_1"
	_expect(not bool(owner.calculate_eta(unknown_profile).get("accepted", true)),
		"unknown Profile fails closed")
	var camera_injection := base_request.duplicate(true)
	camera_injection["camera_rotation"] = 90
	_expect(not bool(owner.calculate_eta(camera_injection).get("accepted", true)),
		"camera state cannot enter ETA authority")
	var zoom_injection := base_request.duplicate(true)
	zoom_injection["zoom"] = 200
	_expect(not bool(owner.calculate_eta(zoom_injection).get("accepted", true)),
		"zoom cannot enter ETA authority")
	var presentation_injection := base_request.duplicate(true)
	presentation_injection["presentation_scale"] = 2
	_expect(not bool(owner.calculate_eta(presentation_injection).get("accepted", true)),
		"presentation cannot enter ETA authority")
	var receipt_tamper := base_receipt.duplicate(true)
	receipt_tamper["eta_ticks"] = int(receipt_tamper.get("eta_ticks", 0)) + 1
	_expect(not bool(EtaOwner.receipt_validation_report(
		receipt_tamper,
		base_route_result.get("route", {}) as Dictionary
	).get("valid", true)), "receipt formula tamper fails closed")

	var reversed_document := document.duplicate(true)
	(reversed_document.get("records", []) as Array).reverse()
	_expect(profile_authority.canonical_document_fingerprint(reversed_document)
		== profile_authority.canonical_document_fingerprint(document),
		"Profile record order cannot alter ETA speed authority")
	var owner_source := _read_text(
		"res://scripts/v076/military/v076_military_physical_eta_owner_v1.gd"
	)
	_expect(not owner_source.contains("_heap_push")
		and not owner_source.contains("_segment_distance_from_neighbors"),
		"ETA source contains no second pathfinder")
	_expect(not owner_source.contains("orbital_bomber")
		and not owner_source.contains("missile_emplacement"),
		"ETA source contains no duplicate speed table")

	var mismatch_count := 0
	var replay_count := 0
	var seed_profile_ids := {}
	var seed_family_ids := {}
	var seed_ranks := {}
	var zero_distance_seed_count := 0
	for seed in range(SEED_COUNT):
		var profile := profiles[seed % profiles.size()] as Dictionary
		var start_face := (seed * 37 + 11) % FACE_COUNT
		var target_face := start_face if seed % 20 == 0 else (
			(seed * 91 + 7) % FACE_COUNT
		)
		if target_face == start_face and seed % 20 != 0:
			target_face = (target_face + 1) % FACE_COUNT
		var first_route := _route(start_face, target_face)
		var second_route := _route(start_face, target_face)
		var first_owner := EtaOwner.new()
		var second_owner := EtaOwner.new()
		first_owner.configure(profile_authority)
		second_owner.configure(profile_authority)
		var first := first_owner.calculate_eta(_request(profile, first_route))
		var second := second_owner.calculate_eta(_request(profile, second_route))
		replay_count += 2
		if not bool(first.get("accepted", false)) \
				or not bool(second.get("accepted", false)) \
				or first.get("receipt", {}) != second.get("receipt", {}):
			mismatch_count += 1
		else:
			var receipt := first.get("receipt", {}) as Dictionary
			var distance := int(receipt.get("canonical_geodesic_distance_mu", -1))
			var speed := int(receipt.get("authored_speed_distance_mu_per_tick", 0))
			var eta_ticks := int(receipt.get("eta_ticks", -1))
			if distance == 0:
				zero_distance_seed_count += 1
				if eta_ticks != 0:
					mismatch_count += 1
			elif eta_ticks < 1 \
					or (eta_ticks - 1) * speed >= distance \
					or eta_ticks * speed < distance:
				mismatch_count += 1
		seed_profile_ids[str(profile.get("profile_id", ""))] = true
		seed_family_ids[str(profile.get("family_id", ""))] = true
		seed_ranks[int(profile.get("rank", 0))] = true
		first_owner.free()
		second_owner.free()

	_expect(replay_count == 2000, "1,000 seeds execute two fresh calculations")
	_expect(mismatch_count == 0, "all fresh ETA replays match")
	_expect(seed_profile_ids.size() == 28, "seed audit covers all Profiles")
	_expect(seed_family_ids.size() == 7, "seed audit covers all families")
	_expect(seed_ranks.size() == 4, "seed audit covers all ranks")
	_expect(zero_distance_seed_count == 50,
		"seed audit preserves fifty explicit zero-distance cases")

	print("V076_MILITARY_PHYSICAL_ETA_TEST|status=%s|checks=%d|failures=%d|seeds=%d|replays=%d|mismatches=%d|teleports=0" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		SEED_COUNT,
		replay_count,
		mismatch_count,
	])
	for failure in _failures:
		push_error(failure)
	owner.free()
	quit(0 if _failures.is_empty() else 1)


func _eta(distance: Variant, speed: Variant) -> int:
	var result := EtaOwner.calculate_eta_ticks(distance, speed)
	return int(result.get("eta_ticks", -1)) if bool(result.get("accepted", false)) else -1


func _route(start_face: int, target_face: int) -> Dictionary:
	var point := GeodesicMetric.canonical_target_point(target_face)
	if not bool(point.get("accepted", false)):
		return point
	return GeodesicMetric.build_route(
		start_face,
		target_face,
		point.get("target_point", {}) as Dictionary
	)


func _request(profile: Dictionary, route_result: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"profile_id": str(profile.get("profile_id", "")),
		"expected_profile_fingerprint_sha256": str(profile.get(
			"canonical_fingerprint", ""
		)),
		"route": (route_result.get("route", {}) as Dictionary).duplicate(true),
		"route_sha256": str(route_result.get("route_sha256", "")),
	}


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
