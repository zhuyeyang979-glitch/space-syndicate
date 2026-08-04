# V0.7.3 Responsive UI and Globe Validation

The production table now gives the planet the remaining-space priority at all supported desktop sizes. `V073ResponsiveTableLayoutV2` chooses Compact, Regular, or Wide from viewport width, viewport height, and player count. The old 104 px compact stage is gone; the reserved interactive heights are 220, 340, and 460 px.

`V073PlanetPresentationAdapterV1` is the single read-only presentation connection between the V0.7.3 public/player snapshot and `PlanetMapView`. It derives six deterministic Voronoi regions from `match_seed` in a presentation namespace, projects public facilities/units/routes and solar facts, and never owns gameplay, Save, or RNG. Seed `900626424` produces geometry fingerprint `5fc92a44b273a4ee66f67b52d52a253fea971ceb3ebafc1d2782b672d8e107d3`.

The globe keeps the existing camera/projection math and uses a CanvasItem shader for radial normals, limb attenuation, atmosphere, camera-relative surface sampling, and the public solar terminator. District projection and hit testing use the same camera state. Drag rotation, wheel zoom, focus, overview reset, fullscreen roundtrip, backside rejection, Region Popup, typed legal target binding, and typed illegal-target rejection are green.

The final headed matrix contains 22 production screenshots under `reports/ui/v073c1/after`. The two frozen-time same-seed PNGs are byte-identical (`626429da...`), while seed `900626425` differs (`a05c34b0...`). Freezing time is limited to the screenshot driver so the 30-second progress bar cannot add irrelevant pixel noise.

The real MCP fixed-seed sanity match used one local player and three production AI players. The local path rotated and zoomed the globe, opened Region Popup from a district, bound two Starter cards through map regions, reordered and locked the queue, legally accelerated the running ruleset, reached FinalSettlement exactly once, showed the questionnaire, and exported the local playtest files. Runtime, duplicate-settlement, and hidden-information violation counts were zero.

Performance is reported honestly. The embedded MCP editor/runtime measured interaction P95 `71.883 ms` and idle P95 `66.368 ms`. Controlled runs measured `62.360 ms` with the full map, `62.233 ms` with the shader hidden, and `66.556 ms` with the entire map hidden, so this environment's roughly 13-16 FPS ceiling is not caused by globe rendering. The requested 16.7 ms target is not claimed on this machine. A 10-second rotation rebuilt no region geometry and consumed no gameplay RNG draws.

No production rule, balance value, Save boundary, AI policy, or telemetry semantics changed. The V0.7.3 baseline fingerprint remains `d696623d8cb3371d08c8870189927a53e48212ca30e9f276bc81b6491b01fbd2`.
