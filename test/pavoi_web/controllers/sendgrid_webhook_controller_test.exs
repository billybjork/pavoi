defmodule PavoiWeb.SendgridWebhookControllerTest do
  use PavoiWeb.ConnCase

  alias Pavoi.Catalog
  alias Pavoi.Creators
  alias Pavoi.Outreach

  @valid_event %{
    "event" => "delivered",
    "email" => "test@example.com",
    "timestamp" => 1_609_459_200,
    "sg_message_id" => "abc123.xyz789"
  }

  defp post_webhook(conn, events) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/webhooks/sendgrid", Jason.encode!(events))
  end

  setup %{conn: conn} do
    {:ok, brand} =
      Catalog.create_brand(%{name: "Webhook Brand", slug: unique_brand_slug("sendgrid")})

    {:ok, conn: conn, brand: brand}
  end

  describe "handle/2" do
    test "processes valid webhook events", %{conn: conn, brand: brand} do
      # Create a creator and outreach log
      {:ok, creator} =
        Creators.create_creator(%{
          tiktok_username: "webhook_test",
          email: "test@example.com"
        })

      {:ok, _log} =
        Outreach.log_outreach(brand.id, creator.id, "email", "sent", provider_id: "abc123.xyz789")

      conn = post_webhook(conn, [@valid_event])
      assert response(conn, 200) == "ok"
    end

    test "returns 200 for empty event array", %{conn: conn} do
      conn = post_webhook(conn, [])
      assert response(conn, 200) == "ok"
    end

    test "auto opts-out creator on spam report", %{conn: conn, brand: brand} do
      {:ok, creator} =
        Creators.create_creator(%{
          tiktok_username: "spam_reporter",
          email: "spammer@example.com",
          email_opted_out: false
        })

      {:ok, _log} =
        Outreach.log_outreach(brand.id, creator.id, "email", "sent", provider_id: "spam123")

      spam_event = %{
        "event" => "spamreport",
        "email" => "spammer@example.com",
        "timestamp" => 1_609_459_200,
        "sg_message_id" => "spam123"
      }

      conn = post_webhook(conn, [spam_event])
      assert response(conn, 200) == "ok"

      # Verify creator was opted out
      updated_creator = Creators.get_creator!(creator.id)
      assert updated_creator.email_opted_out == true
      assert updated_creator.email_opted_out_reason == "spam_report"
    end

    test "auto opts-out creator on hard bounce", %{conn: conn, brand: brand} do
      {:ok, creator} =
        Creators.create_creator(%{
          tiktok_username: "bouncer",
          email: "bounced@example.com",
          email_opted_out: false
        })

      {:ok, _log} =
        Outreach.log_outreach(brand.id, creator.id, "email", "sent", provider_id: "bounce123")

      bounce_event = %{
        "event" => "bounce",
        "email" => "bounced@example.com",
        "timestamp" => 1_609_459_200,
        "sg_message_id" => "bounce123",
        "type" => "5",
        "bounce_classification" => "Invalid Addresses"
      }

      conn = post_webhook(conn, [bounce_event])
      assert response(conn, 200) == "ok"

      # Verify creator was opted out
      updated_creator = Creators.get_creator!(creator.id)
      assert updated_creator.email_opted_out == true
      assert updated_creator.email_opted_out_reason == "hard_bounce"
    end

    test "does not opt-out on soft bounce", %{conn: conn, brand: brand} do
      {:ok, creator} =
        Creators.create_creator(%{
          tiktok_username: "soft_bouncer",
          email: "softbounce@example.com",
          email_opted_out: false
        })

      {:ok, _log} =
        Outreach.log_outreach(brand.id, creator.id, "email", "sent", provider_id: "softbounce123")

      bounce_event = %{
        "event" => "bounce",
        "email" => "softbounce@example.com",
        "timestamp" => 1_609_459_200,
        "sg_message_id" => "softbounce123",
        "type" => "1",
        "bounce_classification" => "Content related"
      }

      conn = post_webhook(conn, [bounce_event])
      assert response(conn, 200) == "ok"

      # Verify creator was NOT opted out
      updated_creator = Creators.get_creator!(creator.id)
      assert updated_creator.email_opted_out == false
    end

    test "auto opts-out creator on unsubscribe", %{conn: conn, brand: brand} do
      {:ok, creator} =
        Creators.create_creator(%{
          tiktok_username: "unsubscriber",
          email: "unsub@example.com",
          email_opted_out: false
        })

      {:ok, _log} =
        Outreach.log_outreach(brand.id, creator.id, "email", "sent", provider_id: "unsub123")

      unsub_event = %{
        "event" => "unsubscribe",
        "email" => "unsub@example.com",
        "timestamp" => 1_609_459_200,
        "sg_message_id" => "unsub123"
      }

      conn = post_webhook(conn, [unsub_event])
      assert response(conn, 200) == "ok"

      # Verify creator was opted out
      updated_creator = Creators.get_creator!(creator.id)
      assert updated_creator.email_opted_out == true
      assert updated_creator.email_opted_out_reason == "unsubscribe"
    end

    test "updates engagement timestamps on delivered event", %{conn: conn, brand: brand} do
      {:ok, creator} =
        Creators.create_creator(%{
          tiktok_username: "engagement_test",
          email: "engage@example.com"
        })

      {:ok, log} =
        Outreach.log_outreach(brand.id, creator.id, "email", "sent", provider_id: "engage123")

      assert log.delivered_at == nil

      delivered_event = %{
        "event" => "delivered",
        "email" => "engage@example.com",
        "timestamp" => 1_609_459_200,
        "sg_message_id" => "engage123"
      }

      conn = post_webhook(conn, [delivered_event])
      assert response(conn, 200) == "ok"

      # Verify delivered_at was set
      updated_log = Outreach.find_outreach_log_by_provider_id("engage123")
      assert updated_log.delivered_at != nil
      assert updated_log.status == "delivered"
    end
  end

  defp unique_brand_slug(prefix) do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end
end
