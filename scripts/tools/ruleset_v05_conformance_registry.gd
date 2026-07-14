extends RefCounted
class_name RulesetV05ConformanceRegistry

const STATUS_FOUNDATION_READY := "foundation_ready"
const STATUS_RUNTIME_INACTIVE := "runtime_inactive"
const STATUS_CUTOVER_COMPLETE := "cutover_complete"
const STATUS_BLOCKED := "blocked"

const RECORDS := [
	{
		"rule_id": "v05_profile_source",
		"expected_behavior": "Stable v0.5 parameters are Inspector-authored and pure data.",
		"current_owner": "space_syndicate_ruleset_v05.tres",
		"current_status": STATUS_FOUNDATION_READY,
		"runtime_evidence": ["RulesetV05FoundationBench 56-case gate"],
		"next_step": "Keep inactive until the production ruleset hard cutover.",
	},
	{
		"rule_id": "product_industry_catalog",
		"expected_behavior": "Every runtime product belongs to exactly one of six authored industries.",
		"current_owner": "product_industry_catalog_v05.tres",
		"current_status": STATUS_FOUNDATION_READY,
		"runtime_evidence": ["46/46 product IDs mapped exactly once"],
		"next_step": "Consume only after structured project GDP exists.",
	},
	{
		"rule_id": "card_requirement_schema",
		"expected_behavior": "v0.5 supports colorless, single, dual, either, and named-product requirements with at most two main conditions.",
		"current_owner": "card_runtime_catalog_v05_validator.gd",
		"current_status": STATUS_FOUNDATION_READY,
		"runtime_evidence": ["Illegal combinations rejected", "Unreviewed cards blocked from release"],
		"next_step": "Author fees only after content review; current runtime catalog remains v0.4.",
	},
	{
		"rule_id": "currency_amount_wire",
		"expected_behavior": "New v0.5 money uses integer cents, conservation, and exact-once transaction IDs.",
		"current_owner": "CurrencyAmountWireV05",
		"current_status": STATUS_RUNTIME_INACTIVE,
		"runtime_evidence": ["Mixed units and floats fail closed"],
		"next_step": "Adopt per-domain during later hard cutovers; do not convert v0.4 cash here.",
	},
	{
		"rule_id": "clock_domain_registry",
		"expected_behavior": "All approved v0.5 timers declare duration, clock domain, pause, pre-emption, wager-freeze, and save behavior.",
		"current_owner": "clock_domain_registry_v05.tres",
		"current_status": STATUS_FOUNDATION_READY,
		"runtime_evidence": ["14 timers validated"],
		"next_step": "Controllers consume entries only in their own hard-cutover commit.",
	},
	{
		"rule_id": "save_envelope_handshake",
		"expected_behavior": "v1 is recognized as legacy v0.4; v0.5 uses version 2 and neither ruleset overwrites the other.",
		"current_owner": "RulesetSaveHandshakeService",
		"current_status": STATUS_RUNTIME_INACTIVE,
		"runtime_evidence": ["QA-only round trip", "No production file IO"],
		"next_step": "Connect only when the v0.5 production save owner is cut over.",
	},
	{
		"rule_id": "player_facing_text_foundation",
		"expected_behavior": "Player copy uses stable ASCII message IDs, visibility-filtered PlayerTextSpec payloads, typed placeholders, authored units, safe fallback, assistive text, and locale resources.",
		"current_owner": "player_text_schema_v05.tres",
		"current_status": STATUS_RUNTIME_INACTIVE,
		"runtime_evidence": ["PlayerTextV05FoundationBench 48/48", "239 legacy card rules_text records inventoried", "Production v0.4 UI unchanged"],
		"next_step": "Keep the shared resolver inactive; project snapshots may publish authorized message keys, while locale resolution remains outside the runtime rule owner.",
	},
	{
		"rule_id": "city_project_identity_runtime",
		"expected_behavior": "Each buildable region has five stable project slots; each project produces structured GDP receipts whose project/player/neutral attribution conserves regional GDP and permits zero GDP.",
		"current_owner": "CityTradeNetworkRuntimeController",
		"current_status": STATUS_CUTOVER_COMPLETE,
		"runtime_evidence": ["GdpFormulaRuntimeCutoverBench 40/40", "CityTradeNetworkRuntimeCharacterizationBench 108/108 observed and aligned", "CityDevelopmentSettlementRuntimeCharacterizationBench 64/64", "No whole-city allocation or city-owner payout fallback"],
		"next_step": "Keep the 108-case structured GDP gate green for all later consumers.",
	},
	{
		"rule_id": "victory_control_runtime",
		"expected_behavior": "Unique 3000bp control, depth Top-N GDP, 10-second qualification, sticky 120-second public audit, 30-second cooldown, ordered endpoint receipt, and authorized audit privacy have one owner.",
		"current_owner": "VictoryControlRuntimeController",
		"current_status": STATUS_CUTOVER_COMPLETE,
		"runtime_evidence": ["VictoryControlRuntimeBench 56/56", "Standings consumes public snapshot", "Final Settlement and GameSession consume one outcome receipt", "Legacy cash goal and countdown absent"],
		"next_step": "Use the same public/private victory snapshots in SS05-05 through SS05-14 without duplicating GDP, control, or endpoint comparisons.",
	},
	{
		"rule_id": "industry_capacity_card_group_runtime",
		"expected_behavior": "Six authored industries drive card requirements and cumulative per-group capacity reservations; one 8-second window has 6 seconds organize, 2 seconds lock, a tutorial 1-card limit, a standard 2-card limit, fixed 0/50/100 bids, and one public monster-wager-pool receipt.",
		"current_owner": "IndustryCapacityRuntimeService + CardResolutionQueueRuntimeService + CardResolutionRuntimeController",
		"current_status": STATUS_CUTOVER_COMPLETE,
		"runtime_evidence": ["IndustryCapacityCardGroupRuntimeBench 64/64", "CardResolutionQueueRuntimeCharacterizationBench 56/56", "RuntimeCardResolutionTrackFlowBench 14/14", "Shared card group runtime test passed"],
		"next_step": "Keep production global Ruleset v0.4 until the migration release gate, while later v0.5 card and wager domains consume these explicit contracts without fallback.",
	},
	{
		"rule_id": "emergency_sale_cost_basis",
		"expected_behavior": "Merged/upgraded card emergency-sale basis must be explicitly approved.",
		"current_owner": "product decision",
		"current_status": STATUS_BLOCKED,
		"runtime_evidence": [],
		"next_step": "Do not implement valuation until a basis is selected.",
	},
]


static func records() -> Array:
	return RECORDS.duplicate(true)


func record_for_id(rule_id: String) -> Dictionary:
	for record in RECORDS:
		if str(record.get("rule_id", "")) == rule_id:
			return (record as Dictionary).duplicate(true)
	return {}
