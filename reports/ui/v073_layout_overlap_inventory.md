# V0.7.3 Layout Overlap Inventory

Base: `f5990809cd59d3aad7d2d5f726363c76f8788094`

The baseline had nine distinct layout faults. The most damaging combination was structural: a height-only compact rule reduced the planet stage to 104 px, the map and stage disagreed about minimum size, and unclipped absolute overlays were allowed to draw and receive input outside that space. The old `LAYOUT_GREEN` claim checked viewport containment and a few individual controls; it did not compare sibling global rectangles, z-order, mouse filters, rendered map bounds, text minimums, or clickable centers.

| ID | Classification | Root cause | Result |
| --- | --- | --- | --- |
| UI073C1-001 | map overflow | `height <= 820` forced a 104 px planet stage | 220/340/460 px responsive stage profiles |
| UI073C1-002 | map overflow/input | map minimums disagreed and clipping was disabled | drawing and input contained by the stage |
| UI073C1-003 | panel overlap | permanent left map rail | hidden in production |
| UI073C1-004 | panel overlap | permanent right map rail | hidden in production |
| UI073C1-005 | panel overlap | absolute Playtest Flow Compass | moved out of the map surface |
| UI073C1-006 | Coach occlusion | fixed/under-specified placement candidates | safe-area scoring across all 14 marks |
| UI073C1-007 | Header overflow | 216 px Marker Panel lived in the Header HBox | floating, collapsed Marker; zero Header width |
| UI073C1-008 | Header/text overflow | every utility was forced into one row | primary and utility rows |
| UI073C1-009 | input occlusion | transient toast occupied Hand Dock space | layout-owned ActionStatus line |

The after-state is enforced by `V073ResponsiveTableLayoutV2` and `V073UILayoutCollisionAuditV1`. The audit checks sibling intersections, parent containment, text minimum size, clickable controls, map draw/input bounds, Coach and Marker debug counters, and popup state. Focused tests are green at 1366x768, 1600x960, and 1920x1080; the final unintended overlap count is zero.

Visual evidence is in `reports/ui/v073c1/before` and `reports/ui/v073c1/after`. The JSON companion records node paths, size/rectangle evidence, z-order, mouse filtering, clipping, and the resolution for every item.
