defmodule InsightWeb.UserLive.Login do
  @moduledoc """
  用户登录页面 LiveView。

  支持两种登录方式：
  1. 邮箱魔法链接登录 — 输入邮箱后发送登录链接到邮箱
  2. 邮箱 + 密码登录 — 传统的密码登录方式

  页面还区分了"保持登录"和"仅本次登录"两种会话模式。
  """
  use InsightWeb, :live_view

  alias Insight.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-6">
        <%!-- 页面标题区域 --%>
        <div class="text-center">
          <.header>
            <p class="text-2xl font-bold">登录</p>
            <:subtitle>
              <%= if @current_scope do %>
                为了执行敏感操作，请重新验证您的身份。
              <% else %>
                还没有账号？
                <.link
                  navigate={~p"/users/register"}
                  class="font-semibold text-brand hover:underline"
                  phx-no-format
                >立即注册</.link>
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <%!-- 本地邮件适配器提示（仅开发环境显示） --%>
        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>当前使用本地邮件适配器。</p>
            <p>
              查看发送的邮件，请访问
              <.link href="/dev/mailbox" class="underline">邮箱预览页面</.link>。
            </p>
          </div>
        </div>

        <%!-- 邮箱魔法链接登录表单 --%>
        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="邮箱地址"
            autocomplete="email"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full">
            通过邮箱登录 <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="divider">或</div>

        <%!-- 邮箱 + 密码登录表单 --%>
        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="邮箱地址"
            autocomplete="email"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="密码"
            autocomplete="current-password"
          />
          <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
            登录并保持在线 <span aria-hidden="true">→</span>
          </.button>
          <.button class="btn btn-primary btn-soft w-full mt-2">
            仅本次登录
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # 从 flash 或当前登录用户中获取邮箱，用于预填表单
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    # 密码登录：触发表单提交到服务端（非 LiveView 处理）
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    # 魔法链接登录：如果用户存在，发送登录邮件
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    # 无论用户是否存在都显示同样的提示，防止邮箱枚举攻击
    info =
      "如果该邮箱已注册，您将很快收到登录链接。"

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  # 检查是否使用本地邮件适配器（开发环境）
  defp local_mail_adapter? do
    Application.get_env(:insight, Insight.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
