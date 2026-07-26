# Player Face Projection Audit

Status: Wave-1 presentation audit/design complete. No production UI, code, tests,
catalogs, scenes, rules, or balance files were changed.

Baseline:

- Branch: `codex/card-semantic-wave1-f-face-59756a2`
- Commit: `59756a291f811a064726f59aed27efecc3590c9a`
- Machine-readable companion:
  `reports/cards/player_face_projection_audit.json`

## Verdict

The baseline does not have one player-face contract. It has several permissive
dictionaries, two catalog eras, and repeated semantic interpretation in
presentation and UI code. `CardViewSnapshot` is an alias normalizer, not an
ownership or privacy boundary.

Codex already distinguishes purchase cash from play assets through the v0.6
catalog. The table, hand, and market do not consistently consume that same
semantic source. A safe migration therefore starts with one strict, read-only
`PlayerFaceDTO`; direct alias renaming would preserve the current ambiguity.

No active hidden/private leak was found in the audited output boundaries at
this baseline. District supply's public downgrade and recursive private-field
checks are meaningful strengths. The DTO must preserve them rather than assume
that a generic card dictionary is public.

## Principal Findings

### PF-001 High: split static authority

`CardCodexPublicSourceService` reads all 348 cards from the v0.6
`machine`/`player` catalog. `TablePresentationViewModelQuery` prefers the
legacy `CardRuntimeCatalogService`; its v0.6 normalization is explicitly
facility-only, and other categories fall back. Region supply copies a selected
v0.6 public subset, then market presentation merges that subset into a legacy
definition.

Evidence:

- `scripts/runtime/card_codex_public_source_service.gd:195-317`
- `scripts/presentation/table_presentation_viewmodel_query.gd:632-683`
- `scripts/presentation/district_supply_viewer_query_port.gd:165-228`
- `scripts/runtime/game_runtime_coordinator.gd:5597-5646`
- `scripts/runtime/region_supply_runtime_controller.gd:11-24,469-510`

Result: the same card identity can receive different costs, target semantics,
effect copy, category, duration, or keywords by surface.

### PF-002 High: cost meanings collide

The fallback `cost -> price -> play_cost` represents at least three meanings:

- legacy authored `cost`: acquisition price;
- hand `cost`: activation/play payment;
- market preview `cost`: current public or locked acquisition offer.

Codex is the only audited path that consistently emits separately labeled
`purchase_cost_text` and `play_cost_text`.

Evidence:

- `scripts/viewmodels/card_view_snapshot.gd:14-23`
- `scripts/CardUI.gd:65-72`
- `scripts/runtime/card_presentation_runtime_service.gd:205-253`
- `scripts/runtime/card_codex_public_source_service.gd:209-229`
- `scripts/runtime/district_supply_snapshot_service.gd:552-570`

Required boundary: static `acquisition_cost`, static `activation_cost`, and an
optional dynamic `instance_state.acquisition_offer` must be separate typed
fields. A bare `cost` or `price` is invalid at the new boundary.

### PF-003 High: presentation interprets rules

`CardPresentationRuntimeService` derives route, use case, category, type,
target wording, rule facts, and duration from effect `kind`, numeric fields,
and legacy turn values. It also asks financial runtime controllers to supply
missing terms. That makes presentation a second rule oracle.

Evidence:

- `scripts/runtime/card_presentation_runtime_service.gd:27-87`
- `scripts/runtime/card_presentation_runtime_service.gd:451-525`
- `scripts/runtime/card_presentation_runtime_service.gd:551-643`
- `scripts/runtime/card_presentation_runtime_service.gd:668-718`
- `scripts/runtime/card_presentation_runtime_service.gd:897-899`

The projection owner may format authoritative typed values. It may not classify
effect kinds, fill financial terms, derive target rules, or convert retired
turn fields.

### PF-004 High: renderers invent missing semantics

When keywords are not marked authoritative, `CardUI` synthesizes use-case,
target, `free/no threshold`, duration, and persistence chips. It classifies
use cases from Chinese/English substrings. `RightInspector` repeats similar
effect, target, duration, and use-case fallback logic.

Evidence:

- `scripts/CardUI.gd:546-582,691-750`
- `scripts/ui/right_inspector.gd:193-331`

Missing semantic data must fail closed as unavailable. Localized copy must
never be parsed to decide player-facing rule meaning.

### PF-005 High: definition, instance, and action ownership are flattened

Hand output combines static definition fields, slot identity, eligibility,
disabled reason, drag state, and action commands. Market output combines
copied definition fields, listing price, quote state, inventory feasibility,
and purchase actions. `CardViewSnapshot.id` can mean `hand_<slot>` rather than
the stable card ID.

Evidence:

- `scripts/runtime/card_presentation_runtime_service.gd:205-253`
- `scripts/viewmodels/card_view_snapshot.gd:6-35`
- `scripts/presentation/table_presentation_viewmodel_query.gd:211-331`
- `scripts/runtime/game_table_viewmodel_runtime_service.gd:287-307`
- `scripts/presentation/district_supply_viewer_query_port.gd:198-228`
- `scripts/runtime/district_supply_snapshot_service.gd:368-623`

The DTO needs strict `definition`, `instance_state`, `legal_actions`, and
`presentation` namespaces with independent scope and revision metadata.

### PF-006 High: v0.6 player data is readable but structurally incomplete

The v0.6 catalog correctly separates `machine.purchase_cash` and
`machine.asset_cost`, but timing, target, effect, duration, visibility, and
keywords are player prose. Across 348 cards / 87 families / 7 categories:

- 1,084 keyword records have no `keyword_id`;
- no player record has a localization reference;
- no card has top-level ordered effect steps or typed conditions;
- only 28 payloads declare `counterable`;
- 248 payloads have some duration-like field, but no uniform duration contract.

Evidence:

- `scripts/cards/card_runtime_catalog_v06_resource.gd:16-17,103-168`
- `data/cards/card_runtime_catalog_v06.json`

The rule/card-definition owner must establish these semantics. The projection
must return `RULE_AUTHORITY_NOT_ESTABLISHED` rather than parse prose or raw
`effect_payload` when a required fact is absent.

### PF-007 Medium: fallbacks hide bad producers

Identity, cost, effect, type, rank, status, and display mode accept long alias
chains and generic defaults. `HandRack` can synthesize node identity from
name/cost/type/rank/index. This makes malformed data look valid and allows
localized or dynamic values to become identity.

Evidence:

- `scripts/viewmodels/card_view_snapshot.gd:14-23`
- `scripts/CardUI.gd:65-72`
- `scripts/ui/hand_rack.gd:130-142`
- `scripts/viewmodels/card_codex_detail_snapshot.gd:29-47`

Require stable `card_id` and an opaque `instance_id`. Keep aliases, if needed,
inside one temporary migration adapter with telemetry and a deletion gate.

### PF-008 Medium: presentation identifiers are not stable

Keywords are identified by localized text, and category glyphs/type labels/
colors are hardcoded in multiple services. This prevents locale-independent
joins and lets visual metadata become an accidental classifier.

The repository already has a useful localization pattern in
`PlayerTextSpecV05`: stable ASCII `message_key`, typed pure-data arguments,
visibility authorization before resolution, and assistive text keys. The DTO
should reuse that shape.

### PF-009 Medium: privacy is safe at outer boundaries, not in card adapters

At baseline:

- district supply downgrades unauthorized subjects to public browse;
- public market cards are non-actionable;
- quote credentials and future bag order are stripped;
- codex rejects private/retired fields;
- hand sources come from an authorized self private projection.

However, `CardViewSnapshot` and `CardPresentationRuntimeService` carry no scope
contract themselves. A shared adapter that flattens a hand or quote dictionary
could bypass the outer protections.

Evidence:

- `scripts/runtime/district_supply_snapshot_service.gd:5-99,171-213`
- `scripts/runtime/card_codex_public_source_adapter.gd:5-37,117-131`
- `scripts/presentation/table_presentation_viewmodel_query.gd:91-156`

### PF-010 Medium: surface decision hierarchy is inconsistent

Market puts a live acquisition offer in generic card `cost`; hand uses the
same slot for activation; detail and codex assemble more summaries from
different aliases. Players cannot rely on one visual position to have one
economic meaning.

## Proposed PlayerFaceDTO

`PlayerFaceDTO` is a detached, pure-data, read-only projection. It owns no
rules, state, quote, eligibility, localization catalog, or game mutation.

```text
PlayerFaceDTO
  schema_version
  projection
    surface_id
    emphasis_profile_id
    scope_id
    definition_revision
    state_revision?
    authorization_revision?
  definition
    identity
      card_id, family_id, rank_value, rank_roman
      name_ref, family_name_ref
    taxonomy
      category_id/ref, type_id/ref, industry_id/ref, route_id/ref
    acquisition_cost
      acquisition_kind_id, base_components[], label_ref
    activation_cost
      components[], payment_timing_id, label_ref
    timing
      window_id, delay_seconds?, timing_ref
    targets[]
      target_id, kind_id, selection_mode_id, cardinality
      filter_id, target_ref, public_on_commit
    conditions[]
      condition_id, kind_id, operator_id, value, unit_id
      condition_ref, authority_id
    effect_steps[]
      order, step_id, effect_kind_id, target_id
      summary_ref, detail_ref, public_parameters
    duration
      kind_id, seconds?, termination_event_ids[], duration_ref
    counterability
      mode_id, response_window_id, window_seconds?
      response_keyword_ids[], counterability_ref
    information_scope
      definition_scope_id, target_commit_scope_id
      resolution_scope_ids[], owner_identity_policy_id, information_ref
    keywords[]
      keyword_id, label_ref, tooltip_ref
    decision_hint_ref
  instance_state?
    instance_id, zone_id, scope_id, revision
    acquisition_offer?, cooldown?, lock_state?, queue_state?
  legal_actions[]
    action_id, action_kind_id, enabled, reason_code
    label_ref, detail_ref, authority_revision, expires_in_seconds?, scope_id
  presentation
    category_icon_id, route_icon_id, industry_color_token_id
    keyword_token_ids, illustration_key
```

### Contract Invariants

1. `definition` comes only from the active Ruleset/card definition owner.
2. A surface changes emphasis, never definition semantics.
3. `acquisition_cost` is obtain-card cost; `activation_cost` is owned-card
   play/install/activate cost. Spend and refundable reserve are typed per
   component.
4. A market price or locked quote is `instance_state.acquisition_offer`, never
   a rewrite of static acquisition cost.
5. Effect step order starts at 1 and is contiguous. UI never builds steps from
   prose or `effect_payload`.
6. `legal_actions[].enabled` comes only from an authoritative action or
   eligibility query. UI never computes legality from visible facts.
7. `LocalizedTextRef` uses stable ASCII `message_key`, validated typed `args`,
   and optional `assistive_message_key`; privacy filtering precedes resolution.
8. Icon, color, and illustration tokens are presentation-only. Rules and AI
   ignore the entire `presentation` object.
9. Hover and selection remain local UI state, not card instance semantics.
10. Unknown fields, missing required semantics, and scope mismatches fail
    closed.

The JSON companion contains the exact field types, enums, nullable rules, and
per-field invariants.

## Surface Emphasis

| Surface | Primary decision order | Required separation |
| --- | --- | --- |
| Market | Name/family, Roman rank, current acquisition offer, quote/buy action, activation cost, target, one-line effect | Public price/availability may show; rival affordability, hand, discard feasibility, and private eligibility may not |
| Hand | Name, Roman rank, activation cost, target, one-line effect, legal play/activate state, cooldown/lock | Acquisition cost is omitted from mini face or relegated to reference detail |
| Detail | Identity, acquisition cost, activation cost, timing, targets, conditions, ordered effects, duration, counterability, information scope | Live actions appear only for an authorized instance; static detail has no private state |
| Codex | Complete public definition plus I-IV family ladder | No instance, action, quote, viewer cash/hand, or owner data; tactical advice must be authored |
| Public track | Name, public queue state, committed public target, short effect, public aftermath | Owner identity and precommit private target/discard remain omitted |

This preserves the card-face product requirement: concise name/family, Roman
rank, correctly labeled price/cost/requirement, target, one-line effect, and
route/category icon, with full rules in hover/detail.

## Alias Deprecation Map

| Legacy family | Replacement | Key rule |
| --- | --- | --- |
| `id`, `card_name`, `name`, `display_name` | `definition.identity` and optional `instance_state.instance_id` | Machine ID, instance ID, and localized name are distinct |
| `cost`, `price`, `price_cash`, `purchase_*` | `definition.acquisition_cost` or `instance_state.acquisition_offer` | Base terms and live offer cannot share an unqualified scalar |
| `play_cost`, `play_cash*`, `asset_cost` | `definition.activation_cost.components` | Spend/reserve/refund semantics are typed |
| `effect`, `text`, `description`, `display_text`, `quick_*`, `full_*`, `summary` | `definition.effect_steps[].summary_ref/detail_ref` | Ordered authored effects replace prose precedence |
| `type`, `category`, `card_type`, `kind`, `subtype_label` | `definition.taxonomy`; domain `effect_kind` stays internal | Category/type/route/effect kind are not interchangeable |
| `rank`, `level`, `tier`, `stats`, `card_stats`, `art_stats`, `speed` | `identity.rank_*` plus typed timing/effect values | Rank is not a generic stats slot |
| target strings/booleans | `definition.targets[]` | Kind, selection, cardinality, filter, and reveal are explicit |
| requirement/condition strings | `definition.conditions[]` and action reason | Static condition is separate from current eligibility failure |
| `duration`, `seconds`, `turns`, termination aliases | `definition.duration` or timed instance state | No presentation turn conversion |
| `family`, `route`, `lane`, `use_case`, `purpose` | `identity.family_id`, `taxonomy.route_id`, `decision_hint_ref` | Family, route, and guidance are distinct |
| `chips`, `keywords`, `keyword_chips` | stable `definition.keywords[]` and presentation tokens | Rendered chip text is not semantic identity |
| `actionable`, `actions`, `play_state`, `why`, `block_reason`, drag aliases | `instance_state` and `legal_actions[]` | Only action authority decides enabled/reason |
| visibility aliases | `projection.scope_id` and `definition.information_scope` | Authorization scope and authored reveal policy are distinct |
| `accent`, `fg`, `bg`, `icon`, `theme_color` | `presentation` token IDs | Raw visual values never classify rules |

Each full legacy field list and removal gate is present in the JSON artifact.

## Consumers And Migration Order

1. **Canonical definition owner**: add/validate structured v0.6 face semantics,
   localization refs, and keyword IDs. Keep `developer` metadata out of DTO.
2. **Projection owner**: implement strict `PlayerFaceProjectionService` and
   schema tests. Old/new comparison is test-only; do not install a dual
   production fallback.
3. **Codex source and renderers**: migrate definition-only public data first.
   Prove all 348 cards and the I-IV ladders before removing aliases.
4. **Region supply listing owner**: retain card identity and listing facts;
   stop storing copied effect/type/target presentation fields.
5. **District market query/snapshot/renderers**: attach public or viewer-private
   acquisition offers and legal actions to the shared definition. Preserve the
   current public downgrade, recursive forbidden keys, and credential stripping.
6. **Table hand query**: cut every category to the canonical v0.6 definition;
   remove facility-only normalization and legacy fallback. Attach authorized
   instance state and play actions.
7. **Card presentation and table inspector**: render DTO namespaces; remove
   kind classification, financial term enrichment, duration conversion,
   target inference, and text-based use cases.
8. **Hand/CardFace renderers**: use stable instance identity and the
   hand-activation profile. Remove semantic defaults and keyword synthesis.
9. **Public track**: consume public-track DTO plus separately sanitized public
   receipts. Keep owner-private reorder authority separate.
10. **Retirement**: remove production `CardViewSnapshot` use and all listed
    alias fallbacks. Historical parsing, if save migration needs it, stays
    outside production presentation.

The machine inventory assigns explicit migration order `0..13` to the source,
query, snapshot, renderer, and retirement groups.

## Privacy Requirements

Always forbidden in `PlayerFaceDTO`:

- rival exact cash or hand;
- private discard or precommit private target;
- hidden/true owner fields;
- AI plans, scores, reasons, pressure buckets, or route plans;
- quote IDs, keys, fingerprints, or supply revisions;
- future supply-bag order;
- raw world, raw `effect_payload`, and developer metadata.

Additional rules:

- public/codex output must remain byte-equivalent when rival private state
  changes;
- viewer-private state/actions require the local viewer relationship and an
  authorization revision;
- exact own cash and aggregate hand counters belong to a separate player
  resource projection, not a card face;
- public market may show public current price/source availability, but not
  whether a rival can afford or receive it;
- target identity appears only when the authoritative rule makes it public at
  commit/resolution;
- anonymous ownership remains omitted until an authoritative reveal receipt.

## Acceptance Gates

1. Exact DTO schema, enum, stable-ID, pure-data, scope, and effect-order
   validation; unknown fields fail closed.
2. 348/348 v0.6 cards produce a complete definition or explicit
   `RULE_AUTHORITY_NOT_ESTABLISHED`.
3. One card/revision has the same canonical definition hash across market,
   hand, detail, codex, and public track.
4. Acquisition base, public offer, locked quote, activation spend, and
   refundable reserve cannot overwrite one another.
5. Snapshot gates prove the market/hand/detail/codex emphasis matrix.
6. Privacy sentinel matrix covers public, viewer-private,
   spectator-sanitized, and endgame-revealed scopes.
7. Localization/keyword IDs resolve and pseudolocalization does not alter
   semantic IDs.
8. Negative source gates reject text/kind classification, target boolean
   cascades, absent-condition `free` defaults, and turn conversion in UI.
9. Stale revision, target change, quote expiry, cooldown, and forced-decision
   tests prove legal actions come only from the action owner.
10. Production has no deprecated fallback reads and zero
    `CardViewSnapshot` callers before deletion.
11. Projection/render paths mutate no catalog, player, quote, inventory,
    queue, clock, or rule term.

## Risks And Readiness

High risks:

- parsing v0.6 player prose would simply move rule authority into the new DTO
  service;
- a dual production fallback would preserve cross-surface drift;
- flattening market/hand state into definition could leak private data.

Medium risks:

- financial terms currently depend on runtime controller enrichment;
- text/glyph/color fixtures are brittle under localization;
- tools/tests may rely on permissive aliases after production migrates;
- catalog effect review/runtime wiring status is not uniformly complete.

Mitigation is structural: typed authoring, atomic consumer cutovers, test-only
parity comparison, privacy filtering before localization, and negative
dependency gates. Presentation completeness must remain separate from rule
authority, runtime implementation, and balance readiness.

Audit artifacts are merge-ready. Production implementation is not ready until
the canonical semantic owner establishes typed timing, targets, conditions,
ordered effects, duration, counterability, information scope, keyword IDs, and
localization references without presentation inference.
