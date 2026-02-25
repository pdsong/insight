defmodule Insight.Scraper.HNTest do
  use ExUnit.Case, async: true
  alias Insight.Scraper.HN

  @sample_html """
  <html op="news">
    <body>
      <table id="hnmain">
        <tr>
          <td>
            <table class="itemlist">
              <tr class='athing' id='47149151'>
                <td align="right" valign="top" class="title"><span class="rank">1.</span></td>
                <td valign="top" class="votelinks"><center><a id='up_47149151' href='vote?id=47149151&amp;how=up&amp;goto=news'><div class='votearrow' title='upvote'></div></a></center></td>
                <td class="title"><span class="titleline"><a href="https://blog.codemine.be/posts/2026/20260222-be-quiet/">LLM=True</a><span class="sitebit comhead"> (<a href="from?site=blog.codemine.be"><span class="sitestr">blog.codemine.be</span></a>)</span></span></td>
              </tr>
              <tr>
                <td colspan="2"></td>
                <td class="subtext">
                  <span class="subline">
                    <span class="score" id="score_47149151">25 points</span> by <a href="user?id=avh3" class="hnuser">avh3</a> <span class="age" title="2026-02-25T03:32:00"><a href="item?id=47149151">5 hours ago</a></span> <span id="unv_47149151"></span> | <a href="hide?id=47149151&amp;goto=news">hide</a> | <a href="item?id=47149151">15 comments</a>
                  </span>
                </td>
              </tr>
              <tr class="spacer" style="height:5px"></tr>
              <tr class="morespace" style="height:10px"></tr>
              <tr>
                <td colspan="2"></td>
                <td class="title"><a href="news?p=2" class="morelink" rel="next">More</a></td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
  </html>
  """

  describe "parse_html/1" do
    test "correctly extracts news items and pagination link from HTML" do
      {items, next_url} = HN.parse_html(@sample_html)

      assert length(items) == 1
      assert next_url == "https://news.ycombinator.com/news?p=2"

      item = hd(items)
      assert item.up_id == 47_149_151
      assert item.title == "LLM=True"
      assert item.url == "https://blog.codemine.be/posts/2026/20260222-be-quiet/"
      assert item.domain == "blog.codemine.be"
      assert item.score == 25
      assert item.hn_user == "avh3"
      assert item.comments_count == 15
      assert item.posted_at == ~U[2026-02-25 03:32:00Z]
    end

    test "handles missing elements gracefully" do
      bad_html = """
      <tr class='athing' id='not_a_number'>
        <td class="title"><span class="titleline">No Link</span></td>
      </tr>
      """

      {items, _} = HN.parse_html(bad_html)
      assert items == []
    end
  end
end
