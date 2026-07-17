# Optional Route Presentation v0.6

## Goal

商品物流始终自动运行；地图商路只是玩家按需打开的公开呈现。

新局的默认状态是：

```text
selected_trade_product_id = ""
route_view_enabled = false
```

玩家文案显示“商路已隐藏”。普通全图视角也不得自动打开商品流线。

## Ownership

- `CommodityFlowRuntimeController` is the only owner of actual allocation,
  Sale Receipts, warehouse transfers, ambient consumption and recent flow facts.
- `RouteNetworkRuntimeController` is the only owner of legal route identity,
  transport modes, capacity, congestion facts and arrival time.
- GameTable ViewModel / public snapshot services join those already-owned public facts into
  a viewer-safe presentation summary.
- `MapView` draws the summary.
- `OverlayLayer` presents the lightweight commodity selector.

Presentation does not own goods, demand, backlog, inventory, route legality, capacity,
receipts or AI state. `main.gd`, UI and WorldBridge must not calculate a second route.

## Local presentation state

The local client may keep:

- `route_view_enabled`
- `selected_trade_product_id`
- local panel open/closed state
- local line-opacity/accessibility preferences

This state:

- is not shared authoritative gameplay state;
- does not enter the v0.6 economic save result;
- does not affect AI;
- does not change route selection or allocation;
- does not reveal itself to other players;
- may remember the last product only for the current local session;
- resets to hidden for every new run.

## Open and close flow

1. Player clicks “查看商路” from the table, economy overview or region detail.
2. Overlay opens a lightweight, dismissible commodity selector.
3. No route line appears until one concrete active commodity is chosen.
4. Selection sets local `selected_trade_product_id` and enables the view.
5. Choosing another commodity only changes the filter.
6. “隐藏商路”, Back, Esc or controller cancel closes the view and removes all commodity lines.
7. Background production, demand, backlog, warehouse transfer and settlement continue unchanged.

Opening, closing and switching the view must not call route refresh, consume RNG, run an
economic tick, create a receipt or change any owner revision.

## Eligible visible flow

For the selected commodity, a line is visible only when one of these is true:

- the current fixed tick contains an actual delivered market flow;
- the current fixed tick contains an actual warehouse inbound/outbound transfer;
- the current fixed tick contains an actual adjacent-land “区域基础消费” flow;
- the route has one of those actual events inside a short, data-driven observation window.

Potential route candidates, legal-but-unused paths, speculative AI plans and zero-flow paths
are never shown by default.

The public summary minimally contains:

```text
flow_event_id
commodity_id
route_id
from_region_id
to_region_id
direction
delivered_units_band
transport_modes
capacity_limited
congested
last_active_world_effective
flow_kind
public_revision
```

`delivered_units_band` may be a normalized weak/medium/strong presentation value. UI must not
show internal milliunits or fixed-point remainder fields.

## Visual language

- “区域基础消费”的相邻陆地流使用短、低强调的一跳箭头。
- 市场销售使用更明确的有向路线。
- 仓库入库/出库使用可区分于市场销售的线型或节点标记。
- 线条表达方向、商品、流量强弱、运输方式和容量受限/拥堵。
- 同一商品存在多条真实流时按公开强度稳定排序，不能用 UI 遍历顺序制造闪烁。
- 关闭视图后所有商品线立即消失；区域边界、设施、怪兽和选择高亮保持正常。

玩家只看到“当前流量较低 / 当前流量较高 / 容量受限”等可读状态，不看到
`route candidate`、`source-to-demand pair`、`sink` 或 raw state enum。

## Privacy

路线公开摘要可以显示：

- 商品；
- 起点/终点区域；
- 方向；
- 运输方式；
- 公开设施与容量受限状态；
- 当前/最近真实流量强弱。

它不得显示：

- 商品供应者身份；
- 工厂或仓库的私人 owner binding；
- 对手现金、手牌或库存归属；
- AI 路线计划、评分或候选路径；
- 私人报价、合同参与者或 transaction fingerprint。

市场待满足需求可以是公开信息，但不能借路线摘要反推出具体供应者身份。
所有字段先经过领域 owner 的可见性过滤，再进入 ViewModel。

## Save and resume

经济存档保存最近公开流量摘要及其 revision，以便恢复短观察窗的一致画面。
它不保存本地 `route_view_enabled` 或 `selected_trade_product_id`。

读档后：

- 经济与物流从权威 owner 状态继续；
- 最近公开流量摘要可以继续自然过期；
- 本地路线视图保持关闭；
- 不因恢复摘要而重复 Sale Receipt 或仓库转运；
- 不重算候选路线来填充可见线条。

## Acceptance

`route_visibility_opt_in_v06_test.gd` and full layout/smoke must prove:

- new run defaults to no commodity lines;
- full-map mode also remains hidden;
- selecting a commodity is required before any line appears;
- only actual current/recent flows appear;
- adjacent ambient flow is one-hop and low emphasis;
- closing hides all lines immediately;
- switching products changes presentation only;
- hidden/visible runs have identical economic fingerprints;
- AI snapshots contain no local visibility state;
- public route snapshots contain no supplier identity or future route candidates.
