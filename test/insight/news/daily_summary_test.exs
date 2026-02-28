defmodule Insight.News.DailySummaryTest do
  @moduledoc """
  DailySummary 查询和写入测试
  """
  use Insight.DataCase

  alias Insight.News
  import Insight.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "daily_summaries" do
    test "upsert_daily_summary/1 creates and updates", %{user: user} do
      date = Date.utc_today()

      # Create
      assert {:ok, summary} =
               News.upsert_daily_summary(%{
                 user_id: user.id,
                 date: date,
                 status: "generating"
               })

      assert summary.user_id == user.id
      assert summary.date == date
      assert summary.status == "generating"

      # Update
      assert {:ok, updated_summary} =
               News.upsert_daily_summary(%{
                 user_id: user.id,
                 date: date,
                 status: "completed",
                 content: "# 简报内容"
               })

      assert updated_summary.id == summary.id
      assert updated_summary.status == "completed"
      assert updated_summary.content == "# 简报内容"
    end

    test "list_daily_summaries/1 returns ordered list by date", %{user: user} do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      News.upsert_daily_summary(%{
        user_id: user.id,
        date: yesterday,
        status: "completed",
        content: "Yesterday"
      })

      News.upsert_daily_summary(%{
        user_id: user.id,
        date: today,
        status: "completed",
        content: "Today"
      })

      summaries = News.list_daily_summaries(user.id)
      assert length(summaries) == 2
      # 降序，所以今天在前，昨天在后
      assert hd(summaries).date == today
      assert List.last(summaries).date == yesterday
    end

    test "get_daily_summary/2 returns specifically for user and date", %{user: user} do
      date = Date.utc_today()
      News.upsert_daily_summary(%{user_id: user.id, date: date, status: "pending"})

      # Correct user and date
      assert %Insight.News.DailySummary{} = News.get_daily_summary(user.id, date)

      # Wrong user
      other_user = user_fixture()
      assert is_nil(News.get_daily_summary(other_user.id, date))

      # Wrong date
      assert is_nil(News.get_daily_summary(user.id, Date.add(date, -1)))
    end
  end
end
