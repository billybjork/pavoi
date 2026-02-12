# Seed the welcome email template (converted from hardcoded template)
# Run with: mix run priv/repo/seeds/email_templates.exs

alias SocialObjects.Communications
alias SocialObjects.Communications.EmailTemplate
alias SocialObjects.Repo

welcome_html = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Welcome to Pavoi</title>
</head>
<body style="margin: 0; padding: 0; background-color: #e6e7e5;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #e6e7e5;">
    <tr>
      <td align="center" style="padding: 20px;">
        <table width="600" cellpadding="0" cellspacing="0" border="0" style="max-width: 600px; width: 100%;">
          <!-- Sage Header -->
          <tr>
            <td style="background-color: #a9bdb6; padding: 25px; text-align: center;">
              <img src="/images/pavoi-logo-email.png" alt="PAVOI" width="200" style="display: block; height: auto; margin: 0 auto;">
            </td>
          </tr>
          <!-- White Content Area -->
          <tr>
            <td style="background-color: #ffffff; padding: 40px; font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif; color: #282828; line-height: 1.7;">
              <h1 style="color: #2e4042; font-size: 26px; font-weight: normal; text-align: center; letter-spacing: 2px; text-transform: uppercase; margin: 0 0 30px 0;">
                Welcome to the<br>Creator Program
              </h1>

              <p style="margin: 0 0 20px;">Hey!</p>

              <p style="margin: 0 0 20px;">You've been selected for the Pavoi Creator Program - and yes, that means <strong>jewelry samples</strong> are coming your way.</p>

              <p style="margin: 0 0 15px;"><strong>Here's what you get:</strong></p>

              <ul style="padding-left: 20px; margin: 0 0 25px; line-height: 1.8;">
                <li style="margin-bottom: 8px;"><strong>Product samples</strong> shipped directly to you</li>
                <li style="margin-bottom: 8px;"><strong>Earn commissions</strong> on every sale from your content</li>
                <li style="margin-bottom: 8px;"><strong>First access</strong> to new drops before anyone else</li>
                <li style="margin-bottom: 8px;"><strong>Direct line</strong> to our team for collabs and support</li>
              </ul>

              <p style="margin: 0 0 20px;"><strong>Ready to join our exclusive creator community?</strong></p>

              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 30px 0;">
                <tr>
                  <td align="center">
                    <a href="{{join_url}}" style="display: inline-block; background-color: #2e4042; color: #ffffff; padding: 16px 40px; text-decoration: none; font-family: Consolas, Monaco, 'Courier New', monospace; font-size: 13px; letter-spacing: 2px; text-transform: uppercase;">
                      JOIN THE COMMUNITY
                    </a>
                  </td>
                </tr>
              </table>

              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border-top: 1px solid #a9bdb6; margin-top: 35px;">
                <tr>
                  <td style="padding-top: 25px;">
                    <p style="margin: 0; color: #282828;">
                      Talk soon,<br>
                      <strong>The Pavoi Team</strong>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Sage Footer -->
          <tr>
            <td style="background-color: #a9bdb6; padding: 25px; text-align: center; font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif;">
              <p style="margin: 0 0 15px; color: #2e4042; font-size: 14px; letter-spacing: 1px;">Together, we're redefining luxury.</p>
              <p style="margin: 0 0 10px; color: #2e4042; font-size: 12px;">
                You're receiving this email because you received a product sample from us on TikTok Shop.
              </p>
              <p style="margin: 0 0 10px; color: #2e4042; font-size: 12px;">
                Pavoi &bull; 11401 NW 12th Street, Miami, FL 33172
              </p>
              <p style="margin: 0; font-size: 12px;">
                <a href="{{unsubscribe_url}}" style="color: #2e4042; text-decoration: underline;">Unsubscribe</a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""

welcome_text = """
Welcome to the Pavoi Creator Program

Hey!

You've been selected for the Pavoi Creator Program - and yes, that means jewelry samples are coming your way.

Here's what you get:
- Product samples shipped directly to you
- Earn commissions on every sale from your content
- First access to new drops before anyone else
- Direct line to our team for collabs and support

Ready to join our exclusive creator community? Click here:
{{join_url}}

Talk soon,
The Pavoi Team

---
You're receiving this email because you received a product sample from us on TikTok Shop.
Pavoi - 11401 NW 12th Street, Miami, FL 33172
Unsubscribe: {{unsubscribe_url}}
"""

# Only create if it doesn't exist
unless Repo.get_by(EmailTemplate, name: "Welcome Email") do
  {:ok, template} =
    Communications.create_email_template(%{
      name: "Welcome Email",
      subject: "You're invited to the Pavoi Creator Program",
      html_body: welcome_html,
      text_body: welcome_text,
      is_default: true,
      is_active: true
    })

  IO.puts("Created Welcome Email template (ID: #{template.id})")
else
  IO.puts("Welcome Email template already exists, skipping")
end
