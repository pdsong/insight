# T14 — 动态兴趣画像 & AI 推荐理由

## 完成时间
2026-02-26

## 做了什么

### 1. 动态兴趣画像算法
- 在 `Interactions.calculate_all_user_interest_profiles/1` 中实现了隐式行为聚合算法：
  - 各类隐式行为对应不同权重（Like `+2.0`, Bookmark `+1.5`, Read `+1.0`, Dislike `-2.0`）。
  - 对用户的行为记录按涉及新闻的关联标签聚合加权计算出兴趣得分。
  - 防得分无限放大，进行了 `[-100.0, 100.0]` 截断。
  - 剔除分值低于 0.1 的弱标签或负向标签，确立正向 `user_interest_profiles`。
- 在 LiveView 中（点赞、收藏、已读）事件触发时，后台非阻塞 `Task.start` 启动画像重新计算，保证数据新鲜。

### 2. AI 单句推荐理由生成逻辑 (Insight.AI.Recommender)
- 基于大模型能力，实现了个性化 `generate_reason/2` 功能。
- 模型提示词强调：必须根据用户命中的兴趣 Tag （例如："AI"，"LLM"），并结合原新闻标题或简介生成 40 字以内的推荐理由口语短句。

### 3. LiveView UI 信息流内展示 (`NewsLive.Index`)
- **后台生成并响应刷新：** `mount` 阶段拉取用户的 Top 3 兴趣画像；如果新闻中击中这些关联标签，发起后台异步 `Task.async`。
- 解析完成后，`handle_info` 会匹配回传的 `{:ai_reason, news_id, reason}`。
- **视觉层面增强：** 新闻卡片的摘要下方将弹出醒目的浅绿色渐变和 `hero-sparkles` 标志性的推荐气泡框，告知用户系统自动推断的理由（如："因为你近期点赞了『开源』与『大语言模型』..."）。

## 测试情况
- 测试文件 `interest_profile_test.exs` 完成行为打分测试
- 全局单元集成测试通过：**170 tests, 0 failures**
