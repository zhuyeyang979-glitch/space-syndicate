# 下一步任务 Prompt：卡牌插画风格钥匙 v0.6

## 给 Codex 的执行指令

在 `space-syndicate-sync` 中完成一张可直接由 Godot 卡牌组件消费的正式“风格钥匙”插画，目标牌为《环晶电池 I》。这一步只建立单张牌的插画语言和接入骨架，不批量生产，不修改规则、经济数值、存档协议或运行时所有权。

必须做到：

1. 生成一张原创、无文字、无卡框、无品牌标识的科幻商品插画；保存进项目资产目录，并建立机器可读插画清单。
2. 通过可选机器字段把插画交给共享 `CardArtView`；玩家界面不得显示资源路径、内部 ID 或生成备注；没有插画时继续使用现有程序美术回退。
3. 在真实 `CardUI` 中同时检查手牌小卡、标准卡与右侧详情卡，不能另做静态 mockup。
4. 新增独立的 Godot 验证场景/捕获脚本，避免侵入规则与游戏运行时文件。
5. 必须使用项目安装的 Godot add-on MCP 识别版本、导入/打开/运行场景、读取 debug output、保存三种分辨率截图，最后停止项目。
6. 输出资产路径、准确生成 Prompt、插画清单、Godot MCP 调用记录、截图和仍需改进项。

## 图像生成 Prompt（准确执行稿）

Create an original premium sci-fi board-game card illustration for a commodity named “Ring-Crystal Battery”. Landscape composition, designed to remain readable when center-cropped into a very shallow card-art window and when reduced to 96 pixels wide.

Subject: one unmistakable ring-shaped alien crystal battery secured inside a rugged orbital cargo cradle. The battery is a faceted translucent mineral torus with a tiny contained dawn glowing inside its hollow center. Heavy industrial clamps, ceramic insulators, braided conduits, and small heat fins make it feel like a valuable manufactured energy commodity, not a magic portal or a spaceship. A few restrained scale cues—cargo latch, inspection light, numbered-looking blank plates without actual writing—suggest tabletop-world logistics.

Composition: a single dominant object occupies roughly 60–70% of the image; centered silhouette with generous safe margins; the bright hollow center is the first-read focal point. Three-quarter product view, low horizon, shallow depth, subtle orbital dock shapes behind it. Preserve the complete circular silhouette in the central 70% so 2:1 and 4:1 horizontal crops still read clearly. No characters.

Art direction: “orbital industrial printmaking”; graphic-painterly 2.5D concept art with crisp silhouette, restrained screen-print and gouache texture, premium tabletop illustration, believable hard-surface materials, physical wear on the cradle, elegant rather than photoreal. Deep navy and charcoal foundation; restrained energy-orange core; cool cyan rim reflections; very small warm ivory highlights. Strong value separation, controlled local glow, no excessive bloom.

Background: dark orbital freight bay fading into near-black space, layered but quiet, with only subtle mechanical rails and atmospheric particles. Keep the object readable independently of the background.

Constraints: illustration only; no words, letters, numerals, UI, card frame, borders, icons, logos, watermarks, trademarks, real-world brands, franchise visual language, or imitation of any named artist. Avoid generic blue hologram circles, fantasy runes, weapon shapes, humanoid figures, clutter, symmetrical mandala ornament, and tiny illegible pseudo-text.

## 验收门

- 96 px 宽时仍能一眼认出“环形晶体电池”，不能只剩一团橙光。
- 橙色表示能源产业，但不覆盖材质层次；青色只作冷反光。
- 完整插画可在横向插图区中心裁切，主体不被切断。
- 同一 PNG 在手牌、标准卡和详情卡中使用；不是三个独立替身。
- 插画资源路径只存在于机器/开发层，玩家文本保持中文且不泄露内部字段。
- Godot MCP 运行无脚本错误，三种分辨率均有真实场景截图，项目在验证后停止。
