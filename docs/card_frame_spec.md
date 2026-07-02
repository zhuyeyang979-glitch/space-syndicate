# Card Frame Spec

## MiniHandCard

- Size: target 140x158 in `HandRack.tscn`, responsive down to 96x128.
- Font sizes: 10-11 for hand scan text.
- Color token: type accent plus state border for hovered, selected, dragging, invalid.
- Layout zones: cost badge, short name, route/type band, rank, one-line effect, status lamp.
- Max text length: short name 12 CJK-ish characters; effect one line with ellipsis.
- Tooltip/detail policy: no long rules in hand; right inspector owns full detail.

## InspectorCard

- Size: flexible right-panel/card-drawer body.
- Font sizes: 12+ for full detail.
- Color token: same type accent with calmer fill.
- Layout zones: name, cost, rank, type/route, target, play condition, full effect, primary action, disabled reason.
- Max text length: may wrap; inspector/drawer scroll owns overflow.
- Tooltip/detail policy: complete explanation and reason text allowed.

## TrackCard

- Size: compact slot, not a full card face.
- Font sizes: 10-12 scan labels.
- Color token: public state color, selected/hover marker, anonymous-owner neutral fill.
- Layout zones: anonymous state, public bid, queue marker, owner hint if publicly known, aftermath clue badge.
- Max text length: slot labels trim; detail moves to RightInspector/IntelDossier.
- Tooltip/detail policy: public info only; never true owner unless already publicly revealed.
