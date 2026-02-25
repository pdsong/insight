# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Insight.Repo
alias Insight.News.Tag

# 系统默认标签列表
# 这些标签由系统自带，用户不可修改，用于 AI 自动分类
system_tags = [
  "科技",
  "AI",
  "开源",
  "编程",
  "前端",
  "后端",
  "数据库",
  "云计算",
  "安全",
  "区块链",
  "创业",
  "融资",
  "商业",
  "产品",
  "科普",
  "人文",
  "教育",
  "设计",
  "游戏",
  "硬件",
  "移动端",
  "DevOps",
  "机器学习",
  "自然语言处理",
  "计算机视觉"
]

for name <- system_tags do
  Repo.insert!(
    %Tag{name: name, type: "system"},
    on_conflict: :nothing,
    conflict_target: [:name, :type]
  )
end

IO.puts("✅ 已创建 #{length(system_tags)} 个系统默认标签")
