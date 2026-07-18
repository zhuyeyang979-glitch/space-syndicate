# Main v3 Load Envelope Cutover

## Production Path

The formal v3 path is now:

```text
Main menu intent
-> GameRuntimeCoordinator.request_run_load
-> GameSessionRuntimeController.request_load
-> GameSaveRuntimeCoordinator.read_and_validate
-> V06SaveOwnerRegistry.apply_envelope (exactly once)
-> high-level load receipt
-> Main UI status
```

`Main` consumes only `ok`, `applied`, `error_code`, `reason_code`, `summary`,
and the existing operation metadata. It does not receive or inspect an
envelope, section map, handshake fingerprint, or legacy payload.

The following Main methods were removed because they had no remaining formal
consumer:

- `_load_run`
- `_run_save_summary_text`
- `_extract_legacy_city_gdp_derivative_positions`
- `_apply_run_domain_state_compatibility_adapter`

`_load_run_from_menu` and `_refresh_run_save_menu_state` remain UI-only entry
points and call the high-level runtime APIs.

## Fail-Closed Inspection

`inspect_save` distinguishes transport validity from registry applicability.
The load menu may show a safe summary for a readable v3 envelope, but the load
button remains disabled while any registry section is unsupported. No envelope
content is returned to Main.

The current production registry still reports seven unsupported sections:
`ruleset`, `routes`, `commodity_belt_visibility`, `card_inventory`, `military`,
`card_resolution_queue`, and `ai`. Consequently, this cutover makes no
full-run-resume claim.

## Main Budget

Before: 11,180 physical lines, 9,681 nonblank lines, 706 methods.

After: 10,971 physical lines, 9,481 nonblank lines, 702 methods.

Constants (103), top-level preloads (10), and fields (66) did not increase.
The architecture scanner still reports its pre-existing external-caller
baseline drift; this task adds no production Main caller.
