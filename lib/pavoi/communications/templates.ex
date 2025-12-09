defmodule Pavoi.Communications.Templates do
  @moduledoc """
  Email and SMS templates for creator outreach.

  Templates are customizable via system settings or can be edited
  directly in this module for more control.
  """

  alias Pavoi.Creators.Creator

  @doc """
  Returns the welcome email subject line.
  """
  def welcome_email_subject do
    "Welcome to the Pavoi Creator Community!"
  end

  @doc """
  Returns the welcome email HTML body.
  """
  def welcome_email_html(creator, lark_invite_url) do
    name = get_display_name(creator)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Welcome to Pavoi</title>
    </head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 28px;">Welcome, #{html_escape(name)}!</h1>
      </div>

      <div style="background: #fff; padding: 30px; border: 1px solid #e1e1e1; border-top: none; border-radius: 0 0 10px 10px;">
        <p>Thank you for partnering with us on TikTok Shop! We're excited to have you as part of the Pavoi creator community.</p>

        <p>We've created an exclusive community on Lark where you can:</p>

        <ul style="padding-left: 20px;">
          <li>Get early access to new products and exclusive samples</li>
          <li>Connect with other creators and share tips</li>
          <li>Receive direct support from our team</li>
          <li>Stay updated on promotions and opportunities</li>
        </ul>

        <div style="text-align: center; margin: 30px 0;">
          <a href="#{html_escape(lark_invite_url)}"
             style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;">
            Join Our Lark Community
          </a>
        </div>

        <p style="color: #666; font-size: 14px;">
          <strong>New to Lark?</strong> Lark is a free collaboration app by ByteDance (TikTok's parent company).
          Clicking the button above will guide you through creating an account if you don't have one.
        </p>

        <hr style="border: none; border-top: 1px solid #e1e1e1; margin: 30px 0;">

        <p style="color: #666; font-size: 14px;">
          Questions? Reply to this email or reach out to us anytime.
        </p>

        <p style="margin-bottom: 0;">
          Best,<br>
          The Pavoi Team
        </p>
      </div>

      <div style="text-align: center; padding: 20px; color: #999; font-size: 12px;">
        <p style="margin: 0;">
          You're receiving this email because you received a product sample from us on TikTok Shop.
        </p>
      </div>
    </body>
    </html>
    """
  end

  @doc """
  Returns the welcome email plain text body.
  """
  def welcome_email_text(creator, lark_invite_url) do
    name = get_display_name(creator)

    """
    Welcome, #{name}!

    Thank you for partnering with us on TikTok Shop! We're excited to have you as part of the Pavoi creator community.

    We've created an exclusive community on Lark where you can:
    - Get early access to new products and exclusive samples
    - Connect with other creators and share tips
    - Receive direct support from our team
    - Stay updated on promotions and opportunities

    Join our Lark community here:
    #{lark_invite_url}

    New to Lark? Lark is a free collaboration app by ByteDance (TikTok's parent company). Clicking the link above will guide you through creating an account if you don't have one.

    Questions? Reply to this email or reach out to us anytime.

    Best,
    The Pavoi Team

    ---
    You're receiving this email because you received a product sample from us on TikTok Shop.
    """
  end

  @doc """
  Returns the welcome SMS body.

  Note: SMS has a 160 character limit for single messages.
  Longer messages are split and may cost more.
  """
  def welcome_sms_body(creator, lark_invite_url) do
    name = get_display_name(creator)

    # Keep it concise for SMS (under 160 chars if possible)
    "Hi #{name}! Thanks for joining Pavoi as a creator. Join our exclusive Lark community for tips, early access & support: #{lark_invite_url}"
  end

  # Private helpers

  defp get_display_name(creator) do
    Creator.full_name(creator) || creator.first_name || creator.tiktok_username || "Creator"
  end

  defp html_escape(nil), do: ""

  defp html_escape(string) when is_binary(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
