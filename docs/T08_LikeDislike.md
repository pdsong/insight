# T08 — Like / Dislike 功能

## 完成时间
2026-02-26

## 做了什么

### 1. Interactions Context 扩展

| 函数 | 说明 |
|------|------|
| `list_interactions_for_news_ids/2` | 批量查询用户对多条新闻的交互状态，返回 `%{id => MapSet}` |
| `toggle_like_dislike/3` | 互斥切换：点 like 时自动取消 dislike，反之亦然 |

### 2. NewsLive.Index 集成
- 每次加载新闻列表时，同时批量查询用户交互状态
- 每条新闻卡片左侧显示 👍/👎 按钮
- 点击后即时更新交互状态，无需刷新页面
- 视觉反馈：like 绿色高亮放大，dislike 红色高亮放大
- 未登录用户点击时提示"请先登录"

### 3. 交互逻辑
- Like 和 Dislike 互斥：不能同时存在
- 重复点击同一按钮取消交互（toggle）
- 数据库层唯一约束保证数据一致性

## 测试结果
113 tests, 0 failures
