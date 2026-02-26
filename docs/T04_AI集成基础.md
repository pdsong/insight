# T04 — AI 集成基础（通义千问 Qwen）

## 完成时间
2026-02-26

## 做了什么

### 1. 创建 `Insight.AI` 核心模块
封装了通义千问的 OpenAI 兼容 API 调用：

| 函数 | 用途 |
|------|------|
| `chat/2` | 发送多轮对话请求 |
| `ask/2` | 单轮对话快捷调用 |
| `ask_json/2` | 请求 JSON 格式回复并自动解析 |

### 2. 内置容错机制
- **自动重试**：网络错误和限流（429）最多重试 2 次，指数退避
- **思考标签过滤**：自动去除 Qwen 模型的 `<think>...</think>` 推理过程标签
- **JSON 解析兜底**：自动处理 markdown 代码块包裹的 JSON 输出

### 3. 配置设计
- API Key 通过环境变量 `QWEN_API_KEY` 注入（`config/runtime.exs`）
- 支持 `QWEN_BASE_URL` 和 `QWEN_MODEL` 环境变量自定义

## 测试结果
- `curl` 和 Elixir 集成测试均成功调用 Qwen API
- 113 tests, 0 failures（全量回归）

## 碰到了什么困难

### Req 0.5.x 的 `connect_timeout` 参数不存在
**原因**：Req 0.5 版本中连接超时的选项名是 `pool_timeout`，不是 `connect_timeout`。
**解决**：替换为 `pool_timeout: 15_000`。
