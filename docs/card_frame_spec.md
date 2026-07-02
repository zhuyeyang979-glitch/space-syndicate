# Card Frame Spec

## MiniHandCard

- Size: target 154x168 in the runtime hand rack, responsive down to 96x128.
- Hover read state: scale at least 1.40x with a visible upward lift so low-resolution players can read the card without opening a modal.
- Font sizes: 7-11 for hand scan text; hover is allowed to enlarge the whole card instead of adding always-visible prose.
- Color token: type accent plus state border for hovered, selected, dragging, invalid.
- Layout zones: cost badge, short name, route/type band, large art anchor, keyword chip rail, 2-3 line short effect, status lamp.
- Max text length: short name 12 CJK-ish characters; short effect wraps up to 3 lines and then ellipsizes.
- Keyword chips: use symbols for repeated rules (`¥`, `◇商品流`, `◆怪兽`, `◎玩家`, `⇄合约`, `一次/固定`) and explain them in the rules appendix.
- Art baseline: every card face must have a visible central art/motif area, distinct type accent, frame/border treatment, and at least one non-text visual cue from card type or route.
- Tooltip/detail policy: no long rules in hand; hover/selected/right inspector owns readable detail.

## DistrictSupplyMarketCell

- Size: target 168x174 inside the right-side district supply drawer.
- Purpose: fast browse, not full rules.
- Layout zones: short name, Roman rank, shared `CardArtView` art strip, price/status chips, route, short effect, state band.
- Interaction: hover or single-click updates the selected preview; double-click attempts purchase.
- Visual policy: must not become a text-only button list. It shares card art motifs with hand/codex cards while staying smaller than the selected preview.

## InspectorCard

- Size: flexible right-panel/card-drawer body.
- Font sizes: 12+ for full detail.
- Color token: same type accent with calmer fill.
- Layout zones: name, cost, rank, type/route, target, play condition, keyword chips, full effect, primary action, disabled reason.
- Max text length: may wrap; inspector/drawer scroll owns overflow.
- Tooltip/detail policy: complete explanation and reason text allowed.

## CodexDetailCard

- First screen should read like a board-game card page, not a development note.
- Left side: one large rendered card face.
- Right side: scan summary, keyword chips, three tactical-use cards, then facts.
- Upgrade ladder: I-IV appears as four comparable panels with the same fields in the same order.
- Hidden/internal fields, balance-budget jargon, and development history stay out of player-facing copy.
- Art benchmark: reuse permissive/open-source card-frame references only through documented, attributed assets; current prototype baseline is the Night Patrol UI frame/sigil set plus procedural motifs.
- Thumbnail atlas benchmark: card-codex thumbnails must render the same `CardArtView` visual language as hand/detail cards, then add scan chips and short effect text around it.

## TrackCard

- Size: compact slot, not a full card face.
- Font sizes: 10-12 scan labels.
- Color token: public state color, selected/hover marker, anonymous-owner neutral fill.
- Layout zones: anonymous state, public bid, queue marker, owner hint if publicly known, aftermath clue badge.
- Max text length: slot labels trim; detail moves to RightInspector/IntelDossier.
- Tooltip/detail policy: public info only; never true owner unless already publicly revealed.
