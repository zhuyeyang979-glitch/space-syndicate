# 三张卡牌自有插画风格锁定批次 v0.6：Godot 验证报告

## 结论

三张自有插画已接入真实 `CardUISkinLab`，可以取代原有占位图作为 **v0.6 风格锁定候选**。它们尚未被标记为量产批准稿：当前批次证明了资产接入、浅横裁、小卡可读性、状态复用和来源隔离均成立，但还需一次统一风格校准和两处视觉修正。

- Godot：`4.7.stable.official.5b4e0cb0f`
- 项目：`space-syndicate-sync`
- 真实运行场景：`res://scenes/tools/CardStyleLockBatchCapture.tscn`
- MCP 捕获：6 张，全部成功
- 捕获套件：`failures=0`
- Godot MCP 停止结果：`finalErrors=[]`
- 玩家文本泄漏：`0`
- 规则、经济数值、AI、存档和运行时所有权：未修改

任务 prompt：`res://docs/next_task_prompt_three_card_style_lock_batch_v06.md`

## 接入结果

| 卡牌 | 新来源 | 旧占位 | Godot 状态 | 判断 |
|---|---|---|---|---|
| 孢雾海皇 I | 自有候选 PNG | Superpowers CC0 dragon | 可投放 | 怪兽轮廓和区域级尺度清楚；卡牌图与地图身体引用已分离 |
| 远洋采购令 I | 自有候选 PNG | Game-icons contract | 悬停 | 远距海运、实体货流和向需求端汇聚可读 |
| 近地供货潮 I | 自有候选 PNG | Game-icons profit | 不可用 | 本地枢纽、陆路实体货物和向外分流可读 |

Manifest 仍保持六张代表牌，不新增玩法身份。当前来源统计为：

- `authored=4`：环晶电池 + 本批次三张；
- `open_source_placeholder=2`：轨道仓库 + 相位否决；
- 六张卡的 `visual_source_id` 与 `illustration_anchor` 均唯一；
- 三张新图均使用 `centered_crop_safe + cover + preserve + linear`；
- 三张均保存 `superseded_placeholder`，未抹去原素材许可与作者链；
- 孢雾海皇另存 `body_reference_*`，没有改写 `monster_body_art_manifest.json`。

## 真实截图

分辨率：

- [1280×720](card_style_lock_batch_1280x720.png)
- [1600×960](card_style_lock_batch_1600x960.png)
- [1920×1080](card_style_lock_batch_1920x1080.png)

重点状态：

- [远洋采购令／悬停](card_style_lock_hovered_1600x960.png)
- [近地供货潮／不可用](card_style_lock_disabled_1600x960.png)
- [孢雾海皇／可投放](card_style_lock_drop_valid_1600x960.png)

三种分辨率的实际 PNG 尺寸均与文件名一致。运行日志中的 `viewport` 在窗口切换瞬间会报告拉伸前的逻辑尺寸，但最终捕获图像分别为 `1280x720`、`1600x960`、`1920x1080`。

## 状态与来源验证

- 六张手牌均成功激活 `CardIllustrationLayer`。
- 三张目标牌的手牌和右侧详情使用同一 `visual_source_id`。
- 公共结算区仍正确使用相位否决的开源占位来源。
- 远洋采购令悬停：`source_type=authored`、`fit_mode=cover`、`tint_mode=preserve`。
- 近地供货潮不可用：同上，禁用原因和下一步仍由本地化玩家文本提供。
- 孢雾海皇可投放：同上，合法槽位和投放连线仍可见。
- 越界路径、含 `..` 的路径与缺失纹理继续回退到程序化卡面；内部路径或错误未进入玩家文本。

## 文本边界

玩家界面允许显示：

- 名称、等级、类型、产业、费用；
- 使用时机、目标、短效果、完整效果、持续/终止、公开范围；
- 关键词与解释；
- 状态、禁用原因和下一步。

机器字段只用于身份和结算：`card_id`、`effect_kind`、`visibility_scope`、`source_rule`、`reason_code`。

开发字段只用于 fixture、来源与诊断：`fixture_state`、`art_status`、`note`、资源路径、插画来源、许可、归属、哈希和 raw error。Manifest 的许可、归属、哈希、prompt 与 superseded/body reference 字段没有进入运行时插画 profile 白名单。

## 回归测试

- `godot --headless --path . --script tests/card_illustration_layer_test.gd`：通过；
- `godot --headless --path . --script tests/ui_text_smoke_test.gd`：通过；
- `godot --headless --path . --script tests/visual_snapshot.gd`：通过；
- `godot --headless --path . --check-only --script tests/smoke_test.gd`：通过。

## Godot MCP 调用记录

1. `get_godot_version`：识别 Godot 4.7；
2. `list_projects`：识别 `space-syndicate-sync`；
3. `get_project_info`：确认项目结构；
4. `launch_editor`：打开项目并触发导入；
5. `get_uid`：检查三张 PNG、新脚本和新场景；
6. `save_scene`：用 Godot 真实载入、实例化并保存验证场景；
7. `run_project`：运行 `CardStyleLockBatchCapture.tscn`；
8. `get_debug_output`：读取完整捕获与验证输出；
9. `stop_project`：停止运行，`finalErrors=[]`。

`save_scene` 使用的独立 dummy-renderer 辅助进程退出时报告 RID 回收警告；真实 Vulkan 项目运行的 `errors` 与停止时的 `finalErrors` 都为空。完整运行事件见 `godot_mcp_debug.log`。

## 尚未达到高端场景化标准的问题

1. **不可用状态黑遮罩溢出**：禁用状态会出现大面积黑色块遮挡桌面。这在旧占位图基线截图中已经存在，并非本批次 PNG 引入；后续应单独修复 CardUI 禁用层的裁切/阴影边界。
2. **远洋图源的微小伪字形**：紫色接收门上方存在极小、不可读的灯牌状细节。游戏裁切中基本不可辨认，但正式发布前应使用定向图像编辑去除，而不是手工涂改源图。
3. **风格仍需统一一次**：怪兽偏电影概念画、近地供货偏等距工业画、远洋采购偏极浅全景。色值和材质族相容，但水粉/丝印颗粒与概括程度还没有完全锁成同一画师语言。
4. **浅插画窗限制构图**：当前 CardUI 插画窗接近 4:1；本批次中心安全带成立，但量产前仍应把该裁切预览固化为每张图的自动验收项。
5. **仍有两张开源占位**：轨道仓库和相位否决尚未换成自有插画，不能把当前六张代表牌称为全自有套装。

因此本批次的推荐状态是：**保留为项目内可运行候选，先修禁用遮罩并做一次三图风格校准，再决定是否扩展到下一批卡牌。**
