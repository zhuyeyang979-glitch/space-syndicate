# Commercial Readiness Scorecard

Scale:

- 0 = 原型不可用
- 1 = 能显示但无手感
- 2 = 能操作但像工具
- 3 = 可试玩但不商业
- 4 = 接近商业垂直切片
- 5 = 可对外展示

| Area | Score | Evidence | Below-3 remedy |
| --- | ---: | --- | --- |
| 桌面格局 | 4 | `VerticalSliceShowcase` owns public track, planet stage, inspector, resource strip, hand rack, bid strip, and overlay. | none |
| 卡牌对象感 | 4 | HandRack v3 selected/hover/drag/invalid states are staged inside the showcase. | none |
| 出牌演出 | 3 | `card_play_flyout`, target arrow, reveal flash, cash/GDP floats, and frame capture exist. | Add easing curves, final audio, and stronger target-specific reactions. |
| 怪兽/战斗反馈 | 3 | Spawn/move/attack/city/route/military visual events and presenters exist. | Add richer token art and chained hit reactions after Scenario Lab fixtures land. |
| 城市/经济反馈 | 3 | City damage crack plus HP/GDP floats and balance-report preview are visible. | Add city-state before/after mini cards and route income deltas. |
| 音效 hook | 3 | Silent `AudioEventBus` and `audio_event_map.json` cover required hooks. | Replace silent entries with curated CC0 clips and mix timing. |
| 价格梯度 | 3 | Balance analyzer outputs Top 20 low/high, rank anomalies, and first-table recommendations. | Calibrate model against more real play data before changing card data. |
| 首局可读性 | 3 | first_table stages explain hover, drag, play, resource, track, and bid read order. | Connect Codex B ScenarioCoach copy when available. |
| 截图质量 | 4 | Showcase frame capture produces idle, hover, drag, play, monster, damage, public track, bid, and balance preview frames. | none |
| 性能稳定 | 3 | VisualEventQueue caps active events at 32 and supports reduced motion. | Add long-run pooled allocation telemetry. |
| 隐藏信息安全 | 4 | Showcase uses local fake data and public labels only; no opponent private state or true owner logic. | none |

Items below 3 must not be treated as complete in future readiness reviews. This v1 slice intentionally stops at visible, testable commercial structure rather than final art/audio quality.
