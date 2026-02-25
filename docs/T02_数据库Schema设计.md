# T02 — 数据库 Schema 设计

## 完成时间
2026-02-25

## 做了什么

### 1. 三表爬取快照设计
针对"每小时爬取 HN，大量新闻重复"的问题，采用三表设计：
- `news_items`：每条新闻唯一存储（up_id 唯一约束），不重复
- `crawl_snapshots`：每次爬取创建一条记录（时间、类型、数量）
- `crawl_snapshot_items`：关联快照和新闻，记录该时刻的排名、分数、评论数

这样查询"最近一次新闻列表"只需找到最新快照再 JOIN 即可，同时保留了完整的历史快照。

### 2. 创建了 9 张数据库表

| 表名 | 用途 |
|------|------|
| `news_items` | 新闻主表（up_id 唯一） |
| `crawl_snapshots` | 爬取快照 |
| `crawl_snapshot_items` | 快照-新闻关联 |
| `tags` | 标签（系统/用户） |
| `news_tags` | 新闻-标签多对多 |
| `user_interactions` | 用户交互记录 |
| `blocked_items` | 屏蔽规则 |
| `custom_feeds` | 自定义阅读流 |
| `user_interest_profiles` | 兴趣画像 |

### 3. 创建了 8 个 Ecto Schema 模块
每个模块都有 `@moduledoc` 和中文注释，分布在三个领域目录中：
- `lib/insight/news/` — NewsItem, CrawlSnapshot, CrawlSnapshotItem, Tag
- `lib/insight/interactions/` — UserInteraction, BlockedItem, UserInterestProfile
- `lib/insight/feeds/` — CustomFeed

### 4. 创建了 3 个 Context 模块
- `Insight.News` — 新闻/快照/标签的业务逻辑
- `Insight.Interactions` — 用户交互/屏蔽/画像
- `Insight.Feeds` — 自定义阅读流

### 5. 系统默认标签（25 个）
通过 `seeds.exs` 写入：科技、AI、开源、编程、前端、后端、数据库、云计算、安全、区块链、创业、融资、商业、产品、科普、人文、教育、设计、游戏、硬件、移动端、DevOps、机器学习、自然语言处理、计算机视觉。

## 碰到了什么困难

### 问题：Seeds 的 on_conflict 报错
`Repo.insert!` 使用 `on_conflict: :nothing, conflict_target: [:name, :type]` 时报错 `ON CONFLICT clause does not match any PRIMARY KEY or UNIQUE constraint`。

**原因**：`tags` 表上的 `[:name, :type]` 索引是普通索引（`create index`），不是唯一索引。
**解决**：将其改为 `create unique_index(:tags, [:name, :type])`。

### 初学者知识点：为什么用三表设计？
如果只用一张 `news_items` 表：
- **允许重复 up_id**：数据膨胀（每天 14000+ 条，大量重复 title/url）
- **up_id 唯一 + upsert**：丢失"每个时刻的列表快照"

三表设计把"不变的新闻数据"和"每次爬取时变化的排名/分数"分开存储，既节省空间又保留历史。

## 测试结果
```
111 tests, 0 failures
```
