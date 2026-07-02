# Balance Pricing Model v1

The v1 analyzer is an advisory report, not a gameplay data rewrite. It is allowed to recommend overrides for the vertical slice, but it must not change card tables globally.

Formula:

```text
suggested_price =
base_by_type
+ rank_step
+ effect_power
+ targeting_premium
+ hidden_info_premium
+ economy_scaling_premium
+ interaction_premium
- setup_requirement_discount
- delayed_effect_discount
- self_risk_discount
```

Report outputs:

- card id
- name
- type
- rank
- current price
- suggested price
- delta
- power score
- complexity score
- hidden-info score
- economy impact score
- monster impact score
- interaction score
- onboarding difficulty
- scenario tags

The first tuning pass may recommend 10-20 vertical-slice cards only.
