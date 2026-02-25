# T03 — Hacker News 爬虫实现

## 完成时间
2026-02-25

## 做了什么

### 1. 引入依赖
在 `mix.exs` 中引入了 `Req`（用于 HTTP 请求）和 `Floki`（用于 HTML 解析）。

### 2. 实现 HN HTML 解析器 (`Insight.Scraper.HN`)
- `crawl_all/2` 支持爬取首页热门（news）和最新（newest）模块。
- 自动处理分页，最多爬取指定数量（默认 300 条），并遵守 10 秒间隔反爬阈值。
- 通过结构化解析 DOM 提取：
  - `up_id` (原始 HN id)
  - `title` 标题，`url` 链接，`domain` 域名
  - `score` 分数，`comments_count` 评论数
  - `hn_user` 发布作者，`posted_at` 发布时间（兼容各种无时区 offset 格式）

### 3. 后台调度爬虫 Worker (`Insight.Scraper.Worker`)
- `GenServer` 实现每小时自动抓取热门（top）和最新（newest）。
- 取到数据后调用 `News.upsert_news_item` 去重插入数据库。
- 每次爬取结束将生成的快照写入 `crawl_snapshots` 及多对多关系表 `crawl_snapshot_items`。
- 在 `test` 环境中禁用自动 Worker 防止影响单元测试。

### 4. 单元测试保障
- 编写 `Insight.Scraper.HNTest`，使用真实格式的 HN HTML 模板验证 DOM 解析的准确性（2个测试，包括健壮性边界测试），覆盖各种异常提取。

## 结论
数据抓取功能闭环完成，系统现可通过计划任务源源不断地搜集和归档 Hacker News 的数据快照。

## 下一步 (T04)
将进入第三阶段（AI 智能层）：集成基于 Qwen 的 `req_llm` 以及为新闻标题、摘要提供 AI 赋能的基建工程。
