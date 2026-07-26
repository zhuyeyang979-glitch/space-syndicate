# Codex First PlayerFace Performance Review

## Review Status

`STATUS=FINAL_PASS`

The final uncontended main-review rerun passes every unchanged performance gate.
Initialization is below the absolute 8,000,000 us limit, startup authorization
and first open are below their 10x magnitude limits, and every steady-state path
is far below the 1.25x regression limit.

This report update did not start Godot. It records the supplied final rerun and
statically verifies the current production and test files.

## Final Candidate

The production Coordinator performs dependency binding only. Public PlayerFace
projection-cache construction remains lazy and occurs on the first Codex open.
The Localization Owner and adapter resolve icon/color tokens through the same
closed token manifest.

| Current file | SHA-256 |
|---|---|
| `card_player_face_public_token_manifest_v1.gd` | `fb7a900be8a60868806c92be25db60158b907ab79d7d3a8e45822937d7d55513` |
| `card_player_face_public_localization_source_service.gd` | `a6f6399d0d4d740cf098c280e5f7f1bc2819a94d802a1778ed1f2be6320bf7de` |
| `card_codex_public_source_adapter.gd` | `db93a206196f11c3868a53d2ee6d121cea5c9670296d66fe7e020becefdeb90a` |
| `card_codex_public_source_service.gd` | `135f3676c7cba05b83e0a2b85956520819e8ffb4e2b608cb8a73332a4971a6a8` |
| `card_codex_playerface_performance_test.gd` | `7ebc3253bdffcac100de05b82fcac0d4f83e36f2001c2408439197515a2f6ca7` |

Static review confirms that Localization `configure()` no longer performs the
redundant `authorize_semantic_spec()` canonicalization for all 348 cards. It uses
the existing `compile_authorized()` cache-hit result. The remaining
`authorize_semantic_spec()` call belongs to later registry verification and is
not part of configure-time canonicalization.

The performance-test thresholds remain unchanged:

- Absolute initialization: `8,000,000us`
- Startup and first-open magnitude: `10x`
- Steady-state regression multiplier: `1.25x`

Failure output now includes every measured phase and hot-path value. No threshold
was widened.

## Final Timings

All values are microseconds.

| Stage | Time (us) | Timing boundary |
|---|---:|---|
| Semantic catalog access | 19 | Existing compiled semantic catalog access. |
| Public localization setup | 2,609,678 | Shared localization/token authority setup. |
| Coordinator bind | 22,533 | Production dependency binding only. |
| Startup authorization | 2,632,211 | `localization + bind`; no eager DTO cache. |
| Projection cache | 5,123,413 | Deferred until first Codex open. |
| First open | 5,146,887 | `projection cache + first browser page`. |
| First browser page | 23,474 | Cached page composition. |
| Repeat browser page | 22,514 | Cached repeat composition. |
| Hover x100 | 2,807 | Cached single-card facts access. |
| Detail x20 | 13,123 | Cached detail and family-ladder access. |
| Full catalog x348 | 10,169 | Cached full-catalog facts traversal. |

The test's absolute initialization value is `localization + projection cache`,
or 7,733,091 us (approximately 7.73 seconds). Startup authorization plus the
projection cache is 7,755,624 us; including first-page composition gives
7,779,098 us.

## Gate Comparison

Ratios below 1.0 are faster than the old baseline.

| Gate comparison | Current | Baseline/limit | Ratio | Verdict |
|---|---:|---:|---:|---|
| Absolute initialization | 7,733,091 | 8,000,000 | 0.9666x | PASS |
| Startup: localization + bind vs configure | 2,632,211 | 276,953 | 9.5042x | PASS, below 10x |
| First Codex cache + page vs first browser | 5,146,887 | 685,780 | 7.5052x | PASS, below 10x |
| First browser page | 23,474 | 685,780 | 0.0342x | PASS, below 1.25x |
| Repeat browser page | 22,514 | 749,173 | 0.0301x | PASS, below 1.25x |
| Hover x100 | 2,807 | 57,699 | 0.0486x | PASS, below 1.25x |
| Detail x20 | 13,123 | 53,094 | 0.2472x | PASS, below 1.25x |
| Full catalog x348 | 10,169 | 159,751 | 0.0637x | PASS, below 1.25x |

The steady-state paths are approximately 4.05x to 33.28x faster than their old
baselines. Absolute initialization retains 266,909 us of headroom, startup
retains 137,319 us below its 10x gate, and first open retains 1,710,913 us.

## Runtime Counters

- DTO count: `348`
- Family ladder count: `87`
- Semantic compile delta: `0`
- Catalog snapshot count: `1`
- Eager production projection-cache build: `false`
- Per-hover semantic compilation: `0`
- Per-detail catalog reload: `0`

## Residual Risks

1. Absolute initialization is approximately 7.73 seconds and has 266,909 us of
   headroom below its fixed limit. Future initialization work must retain this
   benchmark as a ratchet.
2. Startup authorization is 9.50x the old configure baseline, with 137,319 us
   below the 10x gate. This is passing but deliberately visible.
3. First Codex open remains approximately 5.15 seconds. Incremental prewarming
   remains a possible later task, but is not required for this atomic cutover.
4. Startup, first-open, and steady-state timings must remain separately reported
   because they describe different user-visible boundaries.

## Conclusion

The final stable candidate passes all unchanged performance gates. Absolute
initialization is 7.73 seconds, startup authorization is 9.50x, first open is
7.51x, all hot paths are below 1.25x, DTO/family coverage is 348/87, semantic
compile delta is zero, and catalog snapshot count is one. There are no remaining
performance blockers for this PR.
