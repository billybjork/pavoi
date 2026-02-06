defmodule Pavoi.Accounts.UserNotifier do
  @moduledoc """
  Email notifications for user authentication and invites.
  """

  import Swoosh.Email

  alias Pavoi.Accounts.User
  alias Pavoi.Catalog.Brand
  alias Pavoi.Mailer
  alias Pavoi.Settings

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body, opts \\ []) do
    brand = Keyword.get(opts, :brand)
    {from_name, from_email} = from_address(brand)

    email =
      new()
      |> to(recipient)
      |> from({from_name, from_email})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver a brand invite email.
  """
  def deliver_brand_invite(recipient, %Brand{} = brand, url) do
    deliver(
      recipient,
      "You're invited to #{brand.name || Settings.app_name()}",
      """

      ==============================

      You've been invited to join #{brand.name || Settings.app_name()}.

      Accept the invite by visiting the URL below:

      #{url}

      If you weren't expecting this invite, you can ignore this email.

      ==============================
      """,
      brand: brand
    )
  end

  defp from_address(%Brand{} = brand) do
    {
      Settings.get_sendgrid_from_name(brand.id) || brand.name || Settings.app_name(),
      Settings.get_sendgrid_from_email(brand.id)
    }
  end

  defp from_address(_brand) do
    {
      Settings.auth_from_name(),
      Settings.auth_from_email()
    }
  end
end
