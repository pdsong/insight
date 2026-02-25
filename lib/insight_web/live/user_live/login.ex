defmodule InsightWeb.UserLive.Login do
  use InsightWeb, :live_view

  alias Insight.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-12">
        <div class="text-center">
          <h1 class="text-4xl font-black tracking-tight mb-4">Log in</h1>
          <p class="text-base-content/70">
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Don't have an account? <.link
                navigate={~p"/users/register"}
                class="font-semibold text-brand hover:text-brand-light transition-soft hover:underline"
                phx-no-format
              >Sign up</.link> for an account now.
            <% end %>
          </p>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info shadow-soft rounded-2xl">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline hover:text-brand-light transition-colors">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
          class="space-y-6"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="email"
            required
            phx-mounted={JS.focus()}
            class="input-bordered border-transparent bg-base-200 focus:bg-base-100 focus:border-brand shadow-none rounded-xl"
          />
          <.button class="btn btn-primary w-full rounded-full shadow-soft hover:shadow-soft-hover transition-soft">
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="divider text-base-content/50 uppercase text-xs font-bold tracking-widest">or</div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
          class="space-y-6"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="email"
            required
            class="input-bordered border-transparent bg-base-200 focus:bg-base-100 focus:border-brand shadow-none rounded-xl"
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            class="input-bordered border-transparent bg-base-200 focus:bg-base-100 focus:border-brand shadow-none rounded-xl"
          />

          <div class="flex flex-col gap-3 pt-4">
            <.button class="btn btn-primary w-full rounded-full shadow-soft hover:shadow-soft-hover transition-soft" name={@form[:remember_me].name} value="true">
              Log in and stay logged in <span aria-hidden="true">→</span>
            </.button>
            <.button class="btn btn-ghost w-full rounded-full hover:bg-base-200 text-base-content/70 transition-soft">
              Log in only this time
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:insight, Insight.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
