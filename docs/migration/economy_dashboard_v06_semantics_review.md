# Economy dashboard v0.6 semantics review

Status: `ECONOMY_DASHBOARD_V06_SEMANTICS_GREEN`

The production dashboard now states that a commodity sale receipt records both net cash and commodity GDP. It does not describe GDP as a second cash conversion.

Removed from the viewer contract and player text: city ownership as a single truth, urbanization/project shares, investment units, old project GDP, contract sign/reject language, trade-route cards, abstract route life, broken-route repair language, cash-target victory, ambiguous `private` flags, role income and opponent economic paths.

Current terms are: public facilities with facility-level ownership, mixed-owner regions, production and demand, sale receipts, commodity GDP, facility rent, actual transport throughput and bottlenecks, warehouse capacity, regional integrity, weather, monster pressure, six-color own assets, and surviving/ruined regions.

Tooltip and visible lane text consume the same filtered presentation snapshot. Important privacy and interpretation rules are visible without hover.
