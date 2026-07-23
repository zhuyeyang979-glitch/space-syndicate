# AI Card Hand Query Port

## Boundary

`AiCardHandQueryPort` is a scene-owned, read-only projection over the existing
`WorldSessionState` player record. It owns no hand, discard, cooldown, command
journal, or save state. The composition root issues a distinct opaque
`AiCardHandCapability` for every current AI seat and none for human seats.
Roster replacement revokes and reissues the set; a token issued to AI B cannot
query AI A.

The private snapshot contains only the requesting actor identity, a source
revision, action cooldown, detached own slots, own discard histories, counted
hand size, discardable slots, and hand limit. Counted/discardable semantics use
the existing CardFlow v0.6 policy. Cash, rival hands, whole players, Nodes,
Objects, Callables, Main, and RNG never cross the boundary.

## Migrated Consumers

- normal AI card-play candidate hand/cooldown reads;
- AI counter-response candidate hand/cooldown reads;
- counter execution source-card revalidation;
- purchase discard keep-value reads;
- route-plan hand inventory reads.

Card eligibility, queue admission, target capture, counter submission, purchase
mutation, and CardFlow remain with their existing owners. AI card submission
still depends on shared table selection and is not green yet. Actor cash and
the remaining whole-player consumers are also deferred.

## Evidence

- Hand query focused test: 15/15.
- Formal card/counter owner regression: 22/22.
- Main composition: PASS.
- Query mutation count: 0.
- Query RNG delta: 0.
- Rival/human/forged capability acceptance: 0.
- New save sections: 0.
- `FULL_RUN_RESUME_CLAIM=false`.
