defmodule Insight.News.TagTest do
  @moduledoc """
  标签管理测试：系统标签只读、用户标签 CRUD。
  """
  use Insight.DataCase

  alias Insight.News
  import Insight.AccountsFixtures
  import Insight.NewsFixtures

  setup do
    user = user_fixture()
    %{user: user}
  end

  # ============================================================
  # 系统标签
  # ============================================================

  describe "系统标签" do
    test "list_system_tags 返回所有系统标签" do
      _tag1 = system_tag_fixture(%{name: "测试系统标签A"})
      _tag2 = system_tag_fixture(%{name: "测试系统标签B"})

      tags = News.list_system_tags()
      tag_names = Enum.map(tags, & &1.name)
      assert "测试系统标签A" in tag_names
      assert "测试系统标签B" in tag_names
    end

    test "系统标签不可通过 changeset 改为 user 类型" do
      tag = system_tag_fixture(%{name: "系统标签"})
      changeset = News.change_tag(tag, %{type: "invalid"})
      refute changeset.valid?
    end
  end

  # ============================================================
  # 用户自定义标签 CRUD
  # ============================================================

  describe "用户标签 CRUD" do
    test "创建用户标签", %{user: user} do
      {:ok, tag} = News.create_tag(%{name: "我的标签", type: "user", user_id: user.id})
      assert tag.name == "我的标签"
      assert tag.type == "user"
      assert tag.user_id == user.id
    end

    test "list_user_tags 只返回该用户的标签", %{user: user} do
      user2 = user_fixture()
      user_tag_fixture(user.id, %{name: "标签A"})
      user_tag_fixture(user2.id, %{name: "标签B"})

      tags = News.list_user_tags(user.id)
      tag_names = Enum.map(tags, & &1.name)
      assert "标签A" in tag_names
      refute "标签B" in tag_names
    end

    test "更新用户标签", %{user: user} do
      tag = user_tag_fixture(user.id, %{name: "旧名称"})
      {:ok, updated} = News.update_tag(tag, %{name: "新名称"})
      assert updated.name == "新名称"
    end

    test "删除用户标签", %{user: user} do
      tag = user_tag_fixture(user.id)
      {:ok, _} = News.delete_tag(tag)
      assert_raise Ecto.NoResultsError, fn -> News.get_tag!(tag.id) end
    end

    test "list_all_tags 返回系统标签和用户标签", %{user: user} do
      system_tag_fixture(%{name: "系统"})
      user_tag_fixture(user.id, %{name: "用户"})

      tags = News.list_all_tags(user.id)
      tag_names = Enum.map(tags, & &1.name)
      assert "系统" in tag_names
      assert "用户" in tag_names
    end
  end

  # ============================================================
  # 标签关联新闻
  # ============================================================

  describe "标签和新闻关联" do
    test "add_tag_to_news 关联标签", %{user: user} do
      news = news_item_fixture()
      tag = user_tag_fixture(user.id)

      {1, _} = News.add_tag_to_news(news, tag)
      tags = News.get_news_tags(news)
      assert length(tags) == 1
      assert hd(tags).id == tag.id
    end

    test "重复关联不报错（on_conflict: :nothing）" do
      news = news_item_fixture()
      tag = system_tag_fixture()

      {1, _} = News.add_tag_to_news(news, tag)
      {0, _} = News.add_tag_to_news(news, tag)
      assert length(News.get_news_tags(news)) == 1
    end
  end
end
