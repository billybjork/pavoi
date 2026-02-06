defmodule Mix.Tasks.PromoteAdmin do
  @moduledoc """
  Promotes a user to platform admin by email.

  ## Usage

      mix promote_admin user@example.com

  ## Examples

      # Make a user an admin
      mix promote_admin billy@example.com

      # Demote an admin (remove admin status)
      mix promote_admin billy@example.com --demote
  """
  use Mix.Task

  @shortdoc "Promotes a user to platform admin"

  @switches [demote: :boolean]

  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: @switches)

    case args do
      [email] ->
        Mix.Task.run("app.start")
        promote_or_demote(email, opts[:demote] || false)

      _ ->
        Mix.shell().error("Usage: mix promote_admin user@example.com [--demote]")
    end
  end

  defp promote_or_demote(email, demote) do
    case Pavoi.Accounts.get_user_by_email(email) do
      nil ->
        Mix.shell().error("User not found: #{email}")

      user ->
        update_admin_status(user, email, !demote)
    end
  end

  defp update_admin_status(user, email, new_status) do
    case Pavoi.Accounts.set_admin_status(user, new_status) do
      {:ok, _user} ->
        message = admin_status_message(email, new_status)
        Mix.shell().info(message)

      {:error, _changeset} ->
        Mix.shell().error("Failed to update admin status for #{email}")
    end
  end

  defp admin_status_message(email, true), do: "#{email} is now a platform admin"
  defp admin_status_message(email, false), do: "#{email} is no longer a platform admin"
end
