# Commercial Menu Shell Spec

目标：主菜单像商业桌游/卡牌游戏入口，而不是调试面板。

## 主菜单入口

主入口：

1. 新手战役
2. 快速开局
3. 资料库

辅助入口：

- 设置
- 读档
- 制作人员
- 退出

## 设置项

- 教学提示：开 / 关
- 自动暂停教学弹窗：开 / 关
- 动画强度：完整 / 简化 / 关闭
- 字体缩放：小 / 中 / 大
- 色盲辅助：开 / 关
- UI 音效：0-100
- 背景音乐：0-100
- 快捷键
- 重置教程进度

## 多分辨率

CampaignMenu、CampaignBriefing、CampaignRewardPanel、CampaignProgressMap、MatchRecapPanel 必须在 1280x720、1600x960、1920x1080 下根节点为 Control，最小尺寸不超过屏幕。
