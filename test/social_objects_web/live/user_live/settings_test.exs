defmodule SocialObjectsWeb.UserLive.SettingsTest do
  use SocialObjectsWeb.ConnCase, async: true

  alias SocialObjects.Accounts
  import Phoenix.LiveViewTest
  import SocialObjects.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "Log in to see this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user email", %{conn: conn, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => new_email, "current_password" => valid_user_password()}
        })
        |> render_submit()

      assert result =~ "Email changed successfully"
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(new_email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => user.email, "current_password" => valid_user_password()}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
    end

    test "renders error with incorrect password", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => unique_user_email(), "current_password" => "wrong"}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "is incorrect"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user password", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#password_form", %{
          "user" => %{
            "current_password" => valid_user_password(),
            "password" => "new_password123",
            "password_confirmation" => "new_password123"
          }
        })
        |> render_submit()

      assert result =~ "Password changed successfully"
      assert Accounts.get_user_by_email_and_password(user.email, "new_password123")
    end

    test "renders errors with invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#password_form", %{
          "user" => %{
            "current_password" => valid_user_password(),
            "password" => "short",
            "password_confirmation" => "mismatch"
          }
        })
        |> render_submit()

      assert result =~ "should be at least 12 character"
      assert result =~ "does not match password"
    end

    test "renders error with incorrect current password", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#password_form", %{
          "user" => %{
            "current_password" => "wrong",
            "password" => "new_password123",
            "password_confirmation" => "new_password123"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "is incorrect"
    end
  end
end
