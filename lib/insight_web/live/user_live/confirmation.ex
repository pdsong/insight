defmodule InsightWeb.UserLive.Confirmation do
  @moduledoc """
  用户确认页面 LiveView。

  当用户通过邮箱中的魔法链接访问此页面时：
  - 如果是新用户（未确认），显示"确认账号"按钮
  - 如果是已确认用户，直接显示"登录"按钮

  支持"保持登录"和"仅本次登录"两种模式。
  """
  use InsightWeb, :live_view

  alias Insight.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            <p class="text-2xl font-bold">欢迎，{@user.email}</p>
          </.header>
        </div>

        <%!-- 新用户确认表单：首次通过邮件链接访问时显示 --%>
        <.form
          :if={!@user.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={~p"/users/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <.button
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="确认中..."
            class="btn btn-primary w-full"
          >
            确认并保持登录
          </.button>
          <.button phx-disable-with="确认中..." class="btn btn-primary btn-soft w-full mt-2">
            确认并仅本次登录
          </.button>
        </.form>

        <%!-- 已确认用户的登录表单 --%>
        <.form
          :if={@user.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"/users/log-in"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <%= if @current_scope do %>
            <.button phx-disable-with="登录中..." class="btn btn-primary w-full">
              登录
            </.button>
          <% else %>
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="登录中..."
              class="btn btn-primary w-full"
            >
              保持登录
            </.button>
            <.button phx-disable-with="登录中..." class="btn btn-primary btn-soft w-full mt-2">
              仅本次登录
            </.button>
          <% end %>
        </.form>

        <p :if={!@user.confirmed_at} class="alert alert-outline mt-8">
          提示：如果您更偏好使用密码登录，可以在用户设置中启用密码功能。
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # 通过 token 查找用户，验证魔法链接是否有效
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "链接无效或已过期。")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    # 用户点击确认/登录按钮后，触发表单提交到服务端
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
