defmodule InsightWeb.UserLive.Settings do
  @moduledoc """
  用户设置页面 LiveView。

  提供两项核心设置功能：
  1. 修改邮箱 — 输入新邮箱后，系统会发送确认链接到新邮箱
  2. 修改密码 — 设置或更改密码

  此页面需要 sudo 模式（重新认证后才能访问），防止未授权的敏感操作。
  """
  use InsightWeb, :live_view

  # 要求 sudo 模式：用户必须在近期完成过认证才能访问此页面
  on_mount {InsightWeb.UserAuth, :require_sudo_mode}

  alias Insight.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          <p class="text-2xl font-bold">账号设置</p>
          <:subtitle>管理您的邮箱和密码</:subtitle>
        </.header>
      </div>

      <%!-- 邮箱修改表单 --%>
      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="邮箱地址"
          autocomplete="username"
          required
        />
        <.button variant="primary" phx-disable-with="修改中...">修改邮箱</.button>
      </.form>

      <div class="divider" />

      <%!-- 密码修改表单 --%>
      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <%!-- 隐藏字段：用于浏览器自动填充用户名 --%>
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_user_email"
          autocomplete="username"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="新密码"
          autocomplete="new-password"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="确认新密码"
          autocomplete="new-password"
        />
        <.button variant="primary" phx-disable-with="保存中...">
          保存密码
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # 通过 token 确认邮箱变更
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "邮箱修改成功。")

        {:error, _} ->
          put_flash(socket, :error, "邮箱确认链接无效或已过期。")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    # 初始化邮箱和密码表单
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    # 实时验证邮箱输入
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    # 提交邮箱修改：验证 sudo 模式后发送确认邮件到新邮箱
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "确认链接已发送至新邮箱，请查收。"
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    # 实时验证密码输入
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    # 提交密码修改：验证 sudo 模式后更新密码
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
