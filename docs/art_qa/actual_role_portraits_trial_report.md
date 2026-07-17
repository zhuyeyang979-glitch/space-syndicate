# 四角色实际美术试制报告

## 结论

本轮完成四个指定角色、每个角色两种视角的透明运行时 PNG，并将围桌
QA 从“漂亮渐变可冒充素材”改为严格的实际素材门禁。干净截图只要检测
到任一 placeholder 就会失败；缺图调试状态显示红色 `MISSING PORTRAIT`。

本轮未接入正式 `GameScreen`，未修改正式玩家席位宿主，也没有提交或推送。

## 原 placeholder 来源与修正

原渐变占位来自：

- `scripts/presentation/role_portrait_catalog.gd`
- 旧函数：`_procedural_fallback()`

旧逻辑根据角色名哈希生成蓝绿色 `GradientTexture2D`，因此缺失素材在 QA
截图里看起来像成功资产。现在安全回退改为有显式
`role_portrait_is_placeholder=true` 元数据的红色缺图纹理；QA 组件同时显示
`MISSING PORTRAIT`。正式 `PlayerSeatPortraitSkin` 仍使用
`portrait_texture_or_null()`，缺图时隐藏 Skin 并把显示权交还宿主 fallback。

## 固定模型来源

来源仓库：

`https://github.com/beep2bleep/FreeAssetsByKenneyNLandQuaternius`

固定提交：

`dea756baf3b3a4889d8c245e456a4791f961578a`

实际模型：

- Alien：
  `FreeModels by Quaternius[Patreon]/Characters and Animals/Alien Animated - April 2019/FBX/Alien.fbx`
  - 3,482,204 bytes
  - SHA-256 `ce50bb2da6b94f43bf5867abee152bf7afbf7ca93c1e1d0e4c5bc92f323da269`
- Robot：
  `FreeModels by Quaternius[Patreon]/Characters and Animals/Animated Robot - Oct 2018/FBX/Robot.fbx`
  - 3,297,804 bytes
  - SHA-256 `38afb56db7fb17a74d30f0afc8adb5f00441a94e65d6b8ac1958732480f79eb8`

两者都不是 Git LFS pointer。各自目录中的 `License.txt` 内容一致，明确声明
CC0 1.0 Universal。许可证证据：

`docs/licenses/third_party_art/free_assets_kenney_quaternius_CC0.txt`

## 四角色处理

### 环港走私议会

- 底模：Alien
- 深炭黑/海军蓝高粗糙度材质
- 两根短触角
- 两块收拢翼鞘
- 淡青色胸部电池核心

### 重力矿联董事会

- 底模：Robot
- 玄武岩黑与铁灰高粗糙度材质
- 小型加宽肩壳
- 暗紫色圆形重力核心

### 光合修复会

- 底模：Alien
- 深绿与炭黑材质
- 六片收拢叶冠
- 两片短肩叶
- 绿色凝胶核心

### 幽幕播报社

- 底模：Robot
- 深紫与炭黑材质
- 黑色面部屏幕
- 单条冷白扫描线
- 收敛的紫色广播领圈
- 三段广播波形核心

附件只使用 Godot 的 `SphereMesh`、`BoxMesh`、`CylinderMesh`、
`TorusMesh` 和 `PrismMesh`。

## 运行时 PNG

所有 PNG 均为 512×768 RGBA，四角 Alpha 为 0：

- `assets/art/role_portraits/temporary/ringport_smuggler_council/front.png`
- `assets/art/role_portraits/temporary/ringport_smuggler_council/side_inward.png`
- `assets/art/role_portraits/temporary/gravity_mining_board/front.png`
- `assets/art/role_portraits/temporary/gravity_mining_board/side_inward.png`
- `assets/art/role_portraits/temporary/photosynthetic_restoration_society/front.png`
- `assets/art/role_portraits/temporary/photosynthetic_restoration_society/side_inward.png`
- `assets/art/role_portraits/temporary/shadowcast_broadcast/front.png`
- `assets/art/role_portraits/temporary/shadowcast_broadcast/side_inward.png`

## QA 输出

- 四角色联系表：
  `docs/art_qa/actual_portraits_contact_sheet.png`
- 四席干净截图：
  `docs/art_qa/planet_table_4_players_actual_art.png`
- 八席干净截图：
  `docs/art_qa/planet_table_8_players_actual_art.png`
- MCP Skin Bench：
  `docs/art_qa/current_seat_audit/player_seat_portrait_skin_bench_mcp.png`

八席 QA 使用四个已完成角色循环验证布局，不伪造另外二十个角色已完成。

## 布局与图层

- `BackSeatLayer` 保持顶部和远端角色位于星球后方。
- `FrontSeatLayer` 保持底部及近端角色位于星球前方。
- PNG 使用 `KEEP_ASPECT_CENTERED`，不再为了填满头像框裁掉头部或肩部。
- 头像矩形底板被移除，仅保留透明角色与下部轨道座舱。
- 右侧角色使用 `side_inward` 后由 Godot 水平翻转。
- 所有透明装饰控件继续使用 `MOUSE_FILTER_IGNORE`。
- 干净截图会在 `placeholder_count > 0` 时立即失败。

## 隐私

QA 公开快照只包含座次、公开角色、公开状态、公开行动状态与玩家色。对手
现金、手牌、隐藏 owner、匿名真实出牌者和 AI 计划均不进入组件调试快照。
匿名出牌状态继续压制真实行动者高亮。

## 验证

- `python tools/art_pipeline/validate_role_portraits.py`
  - 24 unique
  - rendered=8
  - pending=16
- `art_pipeline_scene_test.gd`
  - PASS 178/178
- `player_seat_portrait_component_test.gd`
  - PASS 153/153
- `player_seat_portrait_skin_test.gd`
  - PASS 17/17
- Godot 4.7 MCP
  - project root 与本独立 worktree 一致
  - `get_script_errors`: 186 scripts / 0 errors
  - `PlayerSeatPortraitSkinBench.tscn` 运行并完成 1600×960 runtime capture
  - runtime bridge capture success

## 边界

本轮没有修改：

- `scenes/ui/GameScreen.tscn`
- `scenes/ui/PlanetBoard.tscn`
- `scenes/ui/PlanetMapView.tscn`
- `scripts/ui/game_screen.gd`
- `scripts/ui/planet_board.gd`
- `scripts/ui/planet_map_view.gd`
- `scripts/main.gd`
- table snapshot / viewmodel
- 正式玩家席位宿主

`scripts/ui/planet_seat_layout.gd` 是本轮开始前已经存在的未跟踪文件，本轮未
修改，也不会提交。
