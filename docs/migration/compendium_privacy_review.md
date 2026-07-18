# Compendium privacy review

Status: `GREEN`

All Compendium source adapters use explicit allowlists and all page dictionaries
are recursively checked before the surface accepts them. `CodexCompendiumSurface`
fails closed on `Node`, `Object` or `Callable` values.

Excluded data includes exact player cash, hand/discard, private warehouse and
futures positions, hidden facility/monster ownership, hidden targets, Intel
guesses, AI plans/scores, RNG values and internal monster weights. Tooltip and
accessibility strings pass the same recursive policy as visible labels.

The role source projects catalog fields through a public allowlist. Product
opening performs no market/RNG/route/save mutation. Region and Monster pages use
owner-provided non-numeric public facts rather than reconstructing private rules.

Evidence:

- `res://tests/compendium_v06_public_semantics_test.gd`
- `res://tests/region_codex_public_source_privacy_acceptance_test.gd`
- `res://tests/monster_codex_public_probability_contract_test.gd`
- `res://tests/role_codex_public_contract_test.gd`
