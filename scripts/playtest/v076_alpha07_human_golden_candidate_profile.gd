extends RefCounted
class_name V076Alpha07HumanGoldenCandidateProfile

const SCHEMA := "V076Alpha07HumanGoldenCandidateProfileV1"
const PRODUCT_VERSION := "v0.7.6"
const RUNTIME_RULESET_ID := "v0.7.5"
const PROFILE_ID := "v076_alpha07_human_golden_candidate_01"
const GOLDEN_SCENARIO_ID := "v076-alpha07-golden-playtest-scenario-01"
const PRODUCTION_SCENE_PATH := "res://scenes/main.tscn"
const EXPORT_ROOT := "user://playtests/v076_alpha07"
const SESSION_PREFIX := "v076-alpha07"
const REPORT_TITLE := "V0.7.6 Alpha 0.7 Human Golden Observation Report"
const ECONOMY_PROFILE_ID := "V072_STARTER_FREE_FAST"
const ECONOMY_PROFILE_FINGERPRINT := (
	"b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
)
const COMBAT_PROFILE_ID := "V075_COMBAT_CANDIDATE_DEFAULTS"
const COMBAT_PROFILE_FINGERPRINT := (
	"26aa0f83b24f96b0c5ff2e78dbd6ee523a53afe9e2cc3f63bd4b2d9c1ec981f5"
)
const MILITARY_PROFILE_CATALOG_FINGERPRINT := (
	"b444752da78cd215606b40957260c3447f8394809eeafdbc165e7b4d5eae88fe"
)


static func profile_fingerprint_input() -> String:
	return (
		PROFILE_ID
		+ "|product_version=" + PRODUCT_VERSION
		+ "|runtime_ruleset_id=" + RUNTIME_RULESET_ID
		+ "|golden_scenario_id=" + GOLDEN_SCENARIO_ID
		+ "|economy_profile_id=" + ECONOMY_PROFILE_ID
		+ "|economy_profile_fingerprint="
		+ ECONOMY_PROFILE_FINGERPRINT
		+ "|combat_profile_id=" + COMBAT_PROFILE_ID
		+ "|combat_profile_fingerprint="
		+ COMBAT_PROFILE_FINGERPRINT
		+ "|military_profile_catalog_fingerprint="
		+ MILITARY_PROFILE_CATALOG_FINGERPRINT
		+ "|production_scene_path=" + PRODUCTION_SCENE_PATH
	)


static func profile_fingerprint() -> String:
	return profile_fingerprint_input().sha256_text().to_lower()


static func snapshot() -> Dictionary:
	return {
		"schema": SCHEMA,
		"product_version": PRODUCT_VERSION,
		"runtime_ruleset_id": RUNTIME_RULESET_ID,
		"profile_id": PROFILE_ID,
		"profile_fingerprint": profile_fingerprint(),
		"profile_fingerprint_input": profile_fingerprint_input(),
		"golden_scenario_id": GOLDEN_SCENARIO_ID,
		"golden_step_count": 15,
		"production_scene_path": PRODUCTION_SCENE_PATH,
		"export_root": EXPORT_ROOT,
		"session_prefix": SESSION_PREFIX,
		"report_title": REPORT_TITLE,
		"evidence_source_type": "OBSERVATION_ONLY",
		"human_executed": false,
		"human_confirmed": false,
		"human_evidence_claim_allowed": false,
		"production_green": false,
		"human_green": false,
		"production_balance_value_change_count": 0,
		"source_authorities": {
			"economy_profile_id": ECONOMY_PROFILE_ID,
			"economy_profile_fingerprint": (
				ECONOMY_PROFILE_FINGERPRINT
			),
			"combat_profile_id": COMBAT_PROFILE_ID,
			"combat_profile_fingerprint": (
				COMBAT_PROFILE_FINGERPRINT
			),
			"military_profile_catalog_fingerprint": (
				MILITARY_PROFILE_CATALOG_FINGERPRINT
			),
		},
	}
