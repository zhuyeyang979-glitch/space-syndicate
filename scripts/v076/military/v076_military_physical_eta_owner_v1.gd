@tool
extends Node
class_name V076MilitaryPhysicalEtaOwnerV1

## Unique authority for one closed operation:
## canonical physical distance + authored Profile speed -> integer ETA ticks.
## Route geometry remains owned by V076SharedHalfEdgePartitionV1 through the
## existing integer geodesic adapter; speed remains owned by the Profile
## Authority. This Owner owns neither dependency and stores no gameplay state.

const StateCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
)
const GeodesicMetric := preload(
	"res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd"
)
const ProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)

const SCHEMA_VERSION := 1
const DOMAIN_ID := "v076.military_physical_eta"
const OWNER_ID := "component.v076.military_physical_eta"
const FORMULA_ID := "ceil_canonical_geodesic_distance_mu_by_authored_speed_v1"
const DISTANCE_OWNER := "V076SharedHalfEdgePartitionV1"
const SPEED_OWNER := "V076MilitaryUnitProfileAuthority"
const REQUEST_FIELDS := [
	"schema_version",
	"profile_id",
	"expected_profile_fingerprint_sha256",
	"route",
	"route_sha256",
]
const RECEIPT_FIELDS := [
	"schema_version",
	"domain_id",
	"owner_id",
	"formula_id",
	"profile_authority_id",
	"profile_id",
	"profile_fingerprint_sha256",
	"distance_owner",
	"metric_id",
	"topology_sha256",
	"arc_class_table_sha256",
	"route_sha256",
	"source_face_id",
	"target_face_id",
	"canonical_geodesic_distance_mu",
	"authored_speed_distance_mu_per_tick",
	"eta_ticks",
	"teleport_allowed",
	"receipt_fingerprint",
]

var _profile_authority: Variant
var _configured := false
var _calculation_count := 0
var _rejection_count := 0


func configure(profile_authority: Variant) -> Dictionary:
	if _configured:
		return _reject("military_eta_owner_already_configured")
	if profile_authority == null \
			or not profile_authority.has_method("profile_by_id") \
			or not profile_authority.has_method("record_validation_report"):
		return _reject("military_eta_profile_authority_missing")
	_profile_authority = profile_authority
	_configured = true
	return {
		"accepted": true,
		"reason": "",
		"domain_id": DOMAIN_ID,
		"owner_id": OWNER_ID,
		"distance_owner": DISTANCE_OWNER,
		"speed_owner": SPEED_OWNER,
	}


func calculate_eta(request: Dictionary) -> Dictionary:
	if not _configured:
		return _reject("military_eta_owner_not_configured")
	if not _exact_fields(request, REQUEST_FIELDS):
		return _reject("military_eta_request_shape_invalid")
	var closed_report := StateCodec.validate(request)
	if not bool(closed_report.get("valid", false)):
		return _reject(str(closed_report.get(
			"reason", "military_eta_request_not_closed"
		)))
	if int(request.get("schema_version", 0)) != SCHEMA_VERSION:
		return _reject("military_eta_request_schema_invalid")
	var profile_id := str(request.get("profile_id", ""))
	var expected_profile_fingerprint := str(request.get(
		"expected_profile_fingerprint_sha256", ""
	))
	if profile_id.is_empty() or expected_profile_fingerprint.length() != 64:
		return _reject("military_eta_profile_identity_invalid")
	var profile: Dictionary = _profile_authority.profile_by_id(profile_id)
	if profile.is_empty() \
			or not bool(_profile_authority.record_validation_report(
				profile
			).get("valid", false)):
		return _reject("military_eta_profile_invalid")
	if str(profile.get("canonical_fingerprint", "")) \
			!= expected_profile_fingerprint:
		return _reject("military_eta_profile_fingerprint_mismatch")
	var route := request.get("route", {}) as Dictionary
	var route_sha256 := str(request.get("route_sha256", ""))
	var route_report := GeodesicMetric.validate_route(route, route_sha256)
	if not bool(route_report.get("accepted", false)):
		return _reject(str(route_report.get(
			"reason", "military_eta_route_noncanonical"
		)))
	var eta_report := calculate_eta_ticks(
		route.get("total_distance_mu"),
		profile.get("speed_distance_mu_per_tick")
	)
	if not bool(eta_report.get("accepted", false)):
		return _reject(str(eta_report.get("reason", "military_eta_input_invalid")))
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"domain_id": DOMAIN_ID,
		"owner_id": OWNER_ID,
		"formula_id": FORMULA_ID,
		"profile_authority_id": ProfileCatalog.PROFILE_AUTHORITY_ID,
		"profile_id": profile_id,
		"profile_fingerprint_sha256": expected_profile_fingerprint,
		"distance_owner": DISTANCE_OWNER,
		"metric_id": str(route.get("metric_id", "")),
		"topology_sha256": str(route.get("topology_sha256", "")),
		"arc_class_table_sha256": str(route.get("arc_class_table_sha256", "")),
		"route_sha256": route_sha256,
		"source_face_id": int(route.get("start_face_id", -1)),
		"target_face_id": int(route.get("target_face_id", -1)),
		"canonical_geodesic_distance_mu": int(eta_report.get("distance_mu", -1)),
		"authored_speed_distance_mu_per_tick": int(eta_report.get("speed_mu_per_tick", 0)),
		"eta_ticks": int(eta_report.get("eta_ticks", -1)),
		"teleport_allowed": false,
		"receipt_fingerprint": "",
	}
	receipt["receipt_fingerprint"] = StateCodec.fingerprint(
		_without_fingerprint(receipt)
	)
	var receipt_report := receipt_validation_report(receipt, route)
	if not bool(receipt_report.get("valid", false)):
		return _reject(str(receipt_report.get(
			"reason", "military_eta_receipt_invalid"
		)))
	_calculation_count += 1
	return {
		"accepted": true,
		"reason": "",
		"profile_id": profile_id,
		"canonical_geodesic_distance_mu": int(receipt.get(
			"canonical_geodesic_distance_mu", 0
		)),
		"authored_speed_distance_mu_per_tick": int(receipt.get(
			"authored_speed_distance_mu_per_tick", 0
		)),
		"eta_ticks": int(receipt.get("eta_ticks", 0)),
		"receipt": receipt,
		"receipt_fingerprint": str(receipt.get("receipt_fingerprint", "")),
	}


static func calculate_eta_ticks(
	distance_mu: Variant,
	speed_mu_per_tick: Variant
) -> Dictionary:
	if typeof(distance_mu) != TYPE_INT:
		return {"accepted": false, "reason": "military_eta_distance_not_integer"}
	if typeof(speed_mu_per_tick) != TYPE_INT:
		return {"accepted": false, "reason": "military_eta_speed_not_integer"}
	var distance := int(distance_mu)
	var speed := int(speed_mu_per_tick)
	if distance < 0:
		return {"accepted": false, "reason": "military_eta_distance_negative"}
	if speed <= 0:
		return {"accepted": false, "reason": "military_eta_speed_nonpositive"}
	@warning_ignore("integer_division")
	var eta_ticks := 0 if distance == 0 else (distance + speed - 1) / speed
	return {
		"accepted": true,
		"reason": "",
		"distance_mu": distance,
		"speed_mu_per_tick": speed,
		"eta_ticks": eta_ticks,
	}


static func receipt_validation_report(
	receipt: Dictionary,
	route: Dictionary
) -> Dictionary:
	if not _exact_fields(receipt, RECEIPT_FIELDS):
		return {"valid": false, "reason": "military_eta_receipt_shape_invalid"}
	var closed_report := StateCodec.validate(receipt)
	if not bool(closed_report.get("valid", false)):
		return {"valid": false, "reason": str(closed_report.get(
			"reason", "military_eta_receipt_not_closed"
		))}
	if int(receipt.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(receipt.get("domain_id", "")) != DOMAIN_ID \
			or str(receipt.get("owner_id", "")) != OWNER_ID \
			or str(receipt.get("formula_id", "")) != FORMULA_ID \
			or str(receipt.get("profile_authority_id", "")) \
			!= ProfileCatalog.PROFILE_AUTHORITY_ID \
			or str(receipt.get("distance_owner", "")) != DISTANCE_OWNER \
			or bool(receipt.get("teleport_allowed", true)):
		return {"valid": false, "reason": "military_eta_receipt_header_invalid"}
	if str(receipt.get("profile_id", "")).is_empty() \
			or str(receipt.get("profile_fingerprint_sha256", "")).length() != 64 \
			or str(receipt.get("route_sha256", "")).length() != 64 \
			or str(receipt.get("receipt_fingerprint", "")).length() != 64:
		return {"valid": false, "reason": "military_eta_receipt_identity_invalid"}
	var route_report := GeodesicMetric.validate_route(
		route, str(receipt.get("route_sha256", ""))
	)
	if not bool(route_report.get("accepted", false)):
		return {"valid": false, "reason": "military_eta_receipt_route_invalid"}
	if int(receipt.get("canonical_geodesic_distance_mu", -1)) \
			!= int(route.get("total_distance_mu", -2)) \
			or str(receipt.get("metric_id", "")) \
			!= str(route.get("metric_id", "")) \
			or str(receipt.get("topology_sha256", "")) \
			!= str(route.get("topology_sha256", "")) \
			or str(receipt.get("arc_class_table_sha256", "")) \
			!= str(route.get("arc_class_table_sha256", "")) \
			or int(receipt.get("source_face_id", -1)) \
			!= int(route.get("start_face_id", -2)) \
			or int(receipt.get("target_face_id", -1)) \
			!= int(route.get("target_face_id", -2)):
		return {"valid": false, "reason": "military_eta_receipt_distance_binding_invalid"}
	var formula_report := calculate_eta_ticks(
		receipt.get("canonical_geodesic_distance_mu"),
		receipt.get("authored_speed_distance_mu_per_tick")
	)
	if not bool(formula_report.get("accepted", false)) \
			or int(formula_report.get("eta_ticks", -1)) \
			!= int(receipt.get("eta_ticks", -2)):
		return {"valid": false, "reason": "military_eta_receipt_formula_invalid"}
	if str(receipt.get("receipt_fingerprint", "")) \
			!= StateCodec.fingerprint(_without_fingerprint(receipt)):
		return {"valid": false, "reason": "military_eta_receipt_fingerprint_invalid"}
	return {"valid": true, "reason": ""}


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"domain_id": DOMAIN_ID,
		"owner_id": OWNER_ID,
		"configured": _configured,
		"distance_owner": DISTANCE_OWNER,
		"speed_owner": SPEED_OWNER,
		"formula_id": FORMULA_ID,
		"owns_eta_formula": true,
		"owns_tick": false,
		"owns_authority_sequence": false,
		"owns_rng": false,
		"owns_replay": false,
		"owns_map_topology": false,
		"owns_route_geometry": false,
		"owns_military_unit_state": false,
		"owns_asset_quantity": false,
		"owns_card_catalog": false,
		"owns_private_direct_action_authorization": false,
		"owns_attack_resolution": false,
		"owns_presentation": false,
		"duplicate_pathfinder_count": 0,
		"duplicate_speed_table_count": 0,
		"teleport_count": 0,
		"calculation_count": _calculation_count,
		"rejection_count": _rejection_count,
	}


static func _without_fingerprint(receipt: Dictionary) -> Dictionary:
	var value := receipt.duplicate(true)
	value.erase("receipt_fingerprint")
	return value


static func _exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for field_variant in expected:
		if not value.has(str(field_variant)):
			return false
	return true


func _reject(reason: String) -> Dictionary:
	_rejection_count += 1
	return {"accepted": false, "reason": reason}
