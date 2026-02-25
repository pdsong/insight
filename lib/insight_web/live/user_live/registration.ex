defmodule InsightWeb.UserLive.Registration do
  @moduledoc """
  用户注册页面 LiveView。

  用户填写邮箱后，系统会创建账号并发送确认邮件。
  注册成功后跳转到登录页面，提示用户去邮箱确认。
  已登录用户访问此页面会被自动重定向到首页。
  """
  use InsightWeb, :live_view

  alias Insight.Accounts
  alias Insight.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <%!-- 页面标题 --%>
        <div class="text-center">
          <.header>
            <p class="text-2xl font-bold">创建账号</p>
            <:subtitle>
              已有账号？
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                立即登录
              </.link>
            </:subtitle>
          </.header>
        </div>

        <%!-- 注册表单：支持实时验证 --%>
        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label="邮箱地址"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.button phx-disable-with="正在创建账号..." class="btn btn-primary w-full">
            创建账号
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    # 已登录用户直接重定向到首页
    {:ok, redirect(socket, to: InsightWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    # 初始化空的注册表单
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # 注册成功后发送确认邮件
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "确认邮件已发送至 #{user.email}，请查收并点击链接确认您的账号。"
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    # 实时验证：用户输入时即时反馈表单错误
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  # 将 changeset 转换为表单 assign
  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
