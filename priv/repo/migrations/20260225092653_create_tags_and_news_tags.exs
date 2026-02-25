defmodule Insight.Repo.Migrations.CreateTagsAndNewsTags do
  use Ecto.Migration

  @moduledoc """
  标签系统：
  - tags: 标签表，type 区分系统标签和用户自定义标签
  - news_tags: 新闻-标签多对多关联表
  """

  def change do
    create table(:tags) do
      add :name, :string, null: false
      # system = 系统自带标签（不可修改），user = 用户自定义标签
      add :type, :string, null: false, default: "system"
      # 用户自定义标签关联到用户，系统标签此字段为 nil
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    # 同名同类型标签唯一
    create unique_index(:tags, [:name, :type])
    create index(:tags, [:user_id])

    # 新闻-标签关联表
    create table(:news_tags) do
      add :news_item_id, references(:news_items, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:news_tags, [:news_item_id, :tag_id])
    create index(:news_tags, [:tag_id])
  end
end
