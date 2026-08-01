# Canonical Catalog final contract review

Status: **GREEN**

## Result

The focused Catalog test now defines the complete final set of **97 stable asset keys** instead of relying on count-only literals. The contract is order-independent and records the expected resource kind and Presentation scope for every key.

| Gate | Result |
| --- | ---: |
| Stable keys | 97/97 |
| Unique stable keys | 97/97 |
| Missing keys | 0 |
| Unexpected keys | 0 |
| Parallel resource/kind/scope rows | 97/97/97 |
| Resource resolution | 97/97 |
| Kind parity | 97/97 |
| Scope parity | 97/97 |
| Existing local resource paths | 97/97 |
| Reloaded resources with declared type | 97/97 |

The four keys that moved the earlier 93-key contract to its final cardinality are:

- `font.body.zh.bold`
- `font.body.ja.bold`
- `font.display.medium`
- `font.display.bold`

## Contract distribution

Resource kinds: 45 `Texture2D`, 21 `AudioStream`, 7 `Font`, 3 `Shader`, 3 `Material`, 1 `Sky`, and 17 `PackedScene` rows.

Scopes: 10 global Presentation, 7 V0.7 projection-only, 29 existing-fact-only, 6 Presentation-event, 6 V0.7 receipt-only, 6 receipt-driven, 2 public-event, 4 public-state, 9 supported-device, 8 receipt-or-public-event, 7 Presentation-only, and 3 decorative-only rows.

## Focused verification

Command:

```text
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/commercial_art/commercial_presentation_catalog_contract_test.gd
```

Godot `4.7.stable.official.5b4e0cb0f` exited with code `0`:

```text
COMMERCIAL_PRESENTATION_CATALOG_CONTRACT checks=988 failures=0 stable_keys=97
```

Legacy texture lookup, the shared Catalog service, typed-row validation, kind-mismatch fail-closed behavior, and rejection of resource paths as public keys all remain GREEN.

## Boundaries

Only the focused test and this report pair were edited. Catalog resources/scripts and production code were read-only. No network access, Smoke, Formal run, or commit was performed.

Catalog SHA-256: `e3e980665a09d71bef50b047c18c566dc0b6b149deaf2041939cc57ef273f3f2`

Test SHA-256: `7b824fc43184f0c516de302b1989a19446be47ca0851a6ba1b084df4e8fd56c2`
