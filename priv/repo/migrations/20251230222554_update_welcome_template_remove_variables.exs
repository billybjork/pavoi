defmodule Pavoi.Repo.Migrations.UpdateWelcomeTemplateRemoveVariables do
  use Ecto.Migration

  def up do
    # Update the welcome_email template to remove variable placeholders
    # Replace {{creator_name}} with generic greeting
    # Replace {{join_url}} with default Lark jewelry group URL
    # Remove unsubscribe link section

    execute """
    UPDATE email_templates
    SET html_body = '<!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to Pavoi</title>
    </head>
    <body style="font-family: Georgia, ''Times New Roman'', serif; line-height: 1.7; color: #2E4042; max-width: 600px; margin: 0 auto; padding: 0; background-color: #f8f8f8;">
    <div style="background: #ffffff; margin: 20px;">
    <!-- Header -->
    <div style="text-align: center; padding: 40px 30px 20px;">
      <span style="font-family: Georgia, ''Times New Roman'', serif; font-size: 28px; letter-spacing: 4px; color: #2E4042;">PAVOI</span>
    </div>

    <!-- Main Content -->
    <div style="padding: 0 40px 40px;">
      <h1 style="font-family: Georgia, ''Times New Roman'', serif; color: #2E4042; margin: 0 0 30px; font-size: 26px; font-weight: normal; text-align: center; letter-spacing: 1px;">
        Welcome to the<br>Pavoi Creator Program
      </h1>

      <p style="margin: 0 0 20px;">Hey!</p>

      <p style="margin: 0 0 20px;">You''ve been selected for the Pavoi Creator Program - and yes, that means <strong>jewelry samples</strong> are coming your way.</p>

      <p style="margin: 0 0 15px;"><strong>Here''s what you get:</strong></p>

      <ul style="padding-left: 20px; margin: 0 0 25px;">
        <li style="margin-bottom: 8px;"><strong>Product samples</strong> shipped directly to you</li>
        <li style="margin-bottom: 8px;"><strong>Earn commissions</strong> on every sale from your content</li>
        <li style="margin-bottom: 8px;"><strong>First access</strong> to new drops before anyone else</li>
        <li style="margin-bottom: 8px;"><strong>Direct line</strong> to our team for collabs and support</li>
      </ul>

      <p style="margin: 0 0 20px;"><strong>Ready to join our exclusive creator community?</strong></p>

      <div style="text-align: center; margin: 30px 0;">
        <a href="https://applink.larksuite.com/client/chat/chatter/add_by_link?link_token=381ve559-aa4d-4a1d-9412-6bee35821e1i"
           style="display: inline-block; background: #2E4042; color: #ffffff; padding: 16px 40px; text-decoration: none; font-size: 15px; letter-spacing: 1px; font-family: Georgia, ''Times New Roman'', serif;">
          JOIN THE COMMUNITY
        </a>
      </div>

      <div style="border-top: 1px solid #A9BDB6; margin-top: 35px; padding-top: 25px;">
        <p style="margin: 0;">
          Talk soon,<br>
          <strong>The Pavoi Team</strong>
        </p>
      </div>
    </div>

    <!-- Footer -->
    <div style="text-align: center; padding: 20px 30px; background: #f9f9f9; border-top: 1px solid #eee;">
      <p style="margin: 0 0 10px; color: #888; font-size: 12px;">
        You''re receiving this email because you received a product sample from us on TikTok Shop.
      </p>
      <p style="margin: 0; color: #888; font-size: 12px;">
        Pavoi &bull; 11401 NW 12th Street, Miami, FL 33172
      </p>
    </div>
    </div>
    </body>
    </html>'
    WHERE name = 'welcome_email'
    """
  end

  def down do
    # No-op - we don't need to restore variables
    :ok
  end
end
