extends RefCounted
class_name V073HumanBaselineProfile
# MCP_FINALIZE

const RULESET_ID := "v0.7.3"
const PROFILE_ID := "v073_human_baseline_01"
const SOURCE_PROFILE_ID := "V073_STARTER_FREE_FIXED_ORDER_CONTENTION"
const SOURCE_PROFILE_FINGERPRINT := (
	"a413ad0ddd8a06b15ccee943d9cd93c6f7941fc66ce901a1f44934797f50231c"
)
const PROFILE_FINGERPRINT_INPUT := (
	"v073_human_baseline_01|ruleset_id=v0.7.3|"
	+ "source_profile_id=V073_STARTER_FREE_FIXED_ORDER_CONTENTION|"
	+ "source_profile_fingerprint="
	+ SOURCE_PROFILE_FINGERPRINT
	+ "|initial_assets_per_color=0|asset_cap_per_color=6|"
	+ "starter_asset_cost=0|standard_l1_asset_cost=1|"
	+ "normal_card_ratio_bps=6000|commodity_card_ratio_bps=4000|"
	+ "intervention_cap_enabled=true|intervention_cap_bps=1200|"
	+ "max_asset_refresh_per_color_per_batch=3|"
	+ "hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|"
	+ "color_cycle_batches=6|track_scroll_interval_seconds=5|"
	+ "track_local_visible_slot_count=5|normal_hand_limit=5|"
	+ "commodity_inventory_limit=5|submission_window_seconds=30|"
	+ "sunlit_multiplier=2.0|dark_multiplier=1.0|"
	+ "resolution_order_mode=fixed_hidden_round_robin|"
	+ "facility_action_mode_required=true|"
	+ "build_slot_contention_fizzle=true|initiative_bid_mode=retired"
)
const PROFILE_FINGERPRINT := (
	"d696623d8cb3371d08c8870189927a53e48212ca30e9f276bc81b6491b01fbd2"
)


static func snapshot() -> Dictionary:
	return {
		"ruleset_id": RULESET_ID,
		"profile_id": PROFILE_ID,
		"profile_fingerprint": PROFILE_FINGERPRINT,
		"profile_fingerprint_input": PROFILE_FINGERPRINT_INPUT,
		"source_profile_id": SOURCE_PROFILE_ID,
		"source_profile_fingerprint": SOURCE_PROFILE_FINGERPRINT,
		"human_fun_proven": false,
		"production_balance_value_change_count": 0,
		"values": {
			"initial_assets_per_color": 0,
			"asset_cap_per_color": 6,
			"starter_asset_cost": 0,
			"standard_l1_asset_cost": 1,
			"normal_card_ratio_bps": 6000,
			"commodity_card_ratio_bps": 4000,
			"intervention_cap_enabled": true,
			"intervention_cap_bps": 1200,
			"max_asset_refresh_per_color_per_batch": 3,
			"hand_maintenance_timeout_seconds": 8,
			"lead_tenure_batches": 1,
			"color_cycle_batches": 6,
			"track_scroll_interval_seconds": 5,
			"track_local_visible_slot_count": 5,
			"normal_hand_limit": 5,
			"commodity_inventory_limit": 5,
			"submission_window_seconds": 30,
			"sunlit_multiplier": 2.0,
			"dark_multiplier": 1.0,
			"resolution_order_mode": "fixed_hidden_round_robin",
			"facility_action_mode_required": true,
			"build_slot_contention_fizzle": true,
			"initiative_bid_mode": "retired",
		},
		"runtime_binding_status": {
			"intervention_cap_bps": "declared_default_not_consumed_at_804ed1f",
			"hand_maintenance_timeout_seconds": (
				"declared_default_not_consumed_at_804ed1f"
			),
			"track_scroll_interval_seconds": (
				"declared_default_not_consumed_at_804ed1f"
			),
		},
	}
