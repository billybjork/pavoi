defmodule SocialObjectsWeb.UserLive.LoginTest do
  use SocialObjectsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(view, "#login_form")
      assert has_element?(view, "h1", "Log in")
      assert has_element?(view, "p", "Need access? Contact your admin for an invite.")
      assert has_element?(view, "button", "Log in")
    end

    test "shows email and password fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(view, ~s(#login_form input[name="user[email]"]))
      assert has_element?(view, ~s(#login_form input[name="user[password]"]))
      assert has_element?(view, ~s(#login_form input[name="user[remember_me]"]))
    end
  end
end
