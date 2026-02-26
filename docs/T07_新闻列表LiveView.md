# T07 — 新闻列表 & 分类查询（LiveView）

## 完成时间
2026-02-26

## 做了什么

### 1. 创建 `NewsLive.Index` LiveView
替换默认 Phoenix 首页，作为应用的核心交互页面。

#### 功能列表
| 功能 | 说明 |
|------|------|
| 来源筛选 | 全部 / 🔥热门 / ⚡最新 三个按钮切换 |
| 标签筛选 | 25 个系统标签 badge，点击筛选/取消 |
| 标题搜索 | 支持中英文标题模糊搜索 |
| 分页 | 每页 20 条，上一页/下一页导航 |
| 中文展示 | 优先显示 `title_zh`，原文折叠展示 |
| 摘要 | 展示 AI 生成的中文摘要（`summary_zh`） |
| 标签 | 显示每条新闻关联的系统标签 |
| 空状态 | 无数据时提示运行 `mix insight.crawl` |

### 2. 扩展 News Context
新增 `list_news_paginated/1`，使用 Ecto 子查询（subquery）实现三维筛选：
- **标签筛选**：子查询 `news_tags` 表
- **来源筛选**：子查询 `crawl_snapshot_items` 最新快照
- **搜索**：`LIKE` 匹配 `title` 和 `title_zh`

> 使用子查询而非可选 `join` 是为了兼容 SQLite 的 binding 限制。

### 3. 路由和布局调整
- `/` 路由指向 `NewsLive.Index`，放在 `current_user` live_session 中
- 主容器从 `max-w-2xl` 拓宽至 `max-w-4xl`

## 测试结果
113 tests, 0 failures

## 碰到了什么困难

### Ecto `...` binding pattern 与 SQLite 不兼容
**现象**：`where([n, ...], ...)` 在无 join 时报错。
**解决**：改用 `from(n in query, where: n.id in subquery(...))` 子查询模式，每个筛选条件独立构建子查询。
