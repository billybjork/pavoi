# Script to update existing templates with Pavoi brand styling
# Run with: mix run priv/repo/scripts/update_brand_templates.exs

alias SocialObjects.Repo
alias SocialObjects.Communications.EmailTemplate
import Ecto.Changeset

# Brand-aligned email template HTML
email_html = """
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

# Brand-aligned page template HTML
page_html = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Email</title>
</head>
<body style="margin: 0; padding: 0; background-color: #e6e7e5;">
<section style="min-height: 100vh; background: linear-gradient(180deg, #e6e7e5 0%, #d8dad8 100%); padding: 40px 20px; font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif;">
  <div style="max-width: 500px; margin: 0 auto; background: #ffffff; box-shadow: 0 4px 20px rgba(0,0,0,0.08); overflow: hidden;">
    <!-- Sage Header -->
    <div style="text-align: center; padding: 30px; background: #a9bdb6;">
      <img src="/images/pavoi-logo-email.png" alt="PAVOI" width="200" style="display: block; height: auto; margin: 0 auto;">
    </div>
    <!-- Content Area -->
    <div style="padding: 40px;">
      <h1 style="text-align: center; color: #2e4042; font-weight: normal; margin: 0 0 30px 0; font-size: 24px; letter-spacing: 2px; text-transform: uppercase;">
        Join the Creator Program
      </h1>
      <div style="margin-bottom: 30px; color: #282828; line-height: 1.7;">
        <p style="margin: 0 0 15px 0;">Get access to:</p>
        <ul style="margin: 0; padding-left: 20px; line-height: 1.8;">
          <li style="margin-bottom: 8px;"><strong>Free product samples</strong> shipped directly to you</li>
          <li style="margin-bottom: 8px;"><strong>Competitive commissions</strong> on every sale</li>
          <li style="margin-bottom: 8px;"><strong>Early access</strong> to new drops</li>
          <li style="margin-bottom: 8px;"><strong>Direct support</strong> from our team</li>
        </ul>
      </div>
      <div data-form-type="consent" data-button-text="JOIN THE PROGRAM" data-email-label="Email" data-phone-label="Phone Number" data-phone-placeholder="(555) 123-4567" style="padding: 30px; border: 3px dashed #a9bdb6; background: linear-gradient(135deg, #f8faf9 0%, #e8f0ec 100%); text-align: center; border-radius: 8px; margin: 20px 0;">
        <div style="color: #2e4042; margin-bottom: 10px;">
          <strong style="font-size: 18px;">📋 Consent Form</strong>
        </div>
        <p style="color: #666; margin: 0; font-size: 14px;">
          The SMS consent form will appear here.<br>
          <small>Edit properties in the right panel to customize button text and labels.</small>
        </p>
      </div>
    </div>
    <!-- Sage Footer -->
    <div style="text-align: center; padding: 25px; background: #a9bdb6;">
      <p style="margin: 0; color: #2e4042; font-size: 14px; letter-spacing: 1px;">Together, we're redefining luxury.</p>
    </div>
  </div>
</section>
</body>
</html>
"""

# Update email template (ID 1)
case Repo.get(EmailTemplate, 1) do
  nil ->
    IO.puts("Template 1 not found, skipping")

  template ->
    template
    |> change(%{html_body: email_html})
    |> Repo.update!()

    IO.puts("✓ Updated template 1: #{template.name}")
end

# Update page templates (IDs 2, 3, 4)
for id <- [2, 3, 4] do
  case Repo.get(EmailTemplate, id) do
    nil ->
      IO.puts("Template #{id} not found, skipping")

    template ->
      if template.type == :page do
        template
        |> change(%{html_body: page_html})
        |> Repo.update!()

        IO.puts("✓ Updated template #{id}: #{template.name}")
      else
        IO.puts("Template #{id} is not a page template, skipping")
      end
  end
end

# Template 5: Top Jewelry Invite (VIP/Top Creators)
top_creators_html = """
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
                Welcome to the<br>Top Creators Community
              </h1>

              <p style="margin: 0 0 20px;">Hey!</p>

              <p style="margin: 0 0 20px;">Given your outstanding Shop performance, you've unlocked access to our <strong>VIP Creator Community</strong> for top earners.</p>

              <p style="margin: 0 0 15px;"><strong>What's in it for you:</strong></p>

              <ul style="padding-left: 20px; margin: 0 0 25px; line-height: 1.8;">
                <li style="margin-bottom: 8px;"><strong>First access</strong> to launches, drop peeks, and brand updates</li>
                <li style="margin-bottom: 8px;"><strong>Priority sampling</strong> &amp; collaboration opportunities</li>
                <li style="margin-bottom: 8px;"><strong>VIP commission structures</strong> &amp; cash bonuses available only to top earners</li>
                <li style="margin-bottom: 8px;"><strong>Direct line to the Pavoi team</strong> for insights &amp; support to guide your content strategy</li>
              </ul>

              <p style="margin: 0 0 20px;"><strong>Ready to earn more with Pavoi?</strong></p>

              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 30px 0;">
                <tr>
                  <td align="center">
                    <a href="{{join_url}}" style="display: inline-block; background-color: #2e4042; color: #ffffff; padding: 16px 40px; text-decoration: none; font-family: Consolas, Monaco, 'Courier New', monospace; font-size: 13px; letter-spacing: 2px; text-transform: uppercase;">
                      JOIN THE VIP COMMUNITY
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

# Template 6: Active Invite (Activewear)
active_html = """
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
                Welcome to the<br>Active Creator Program
              </h1>

              <p style="margin: 0 0 20px;">Hey!</p>

              <p style="margin: 0 0 20px;">You have been selected for the Pavoi Active Creator program, and yes - that means your <strong>activewear samples</strong> are on the way!</p>

              <p style="margin: 0 0 15px;"><strong>What's in it for you:</strong></p>

              <ul style="padding-left: 20px; margin: 0 0 25px; line-height: 1.8;">
                <li style="margin-bottom: 8px;"><strong>Exclusive 20% commission</strong> &amp; paid amplification</li>
                <li style="margin-bottom: 8px;"><strong>First access</strong> to launches, drop sneak peeks, and brand updates</li>
                <li style="margin-bottom: 8px;"><strong>Priority sampling</strong> &amp; collaboration opportunities (on and off Shop!)</li>
                <li style="margin-bottom: 8px;"><strong>Less competition</strong>, stronger conversion, and more earnings</li>
                <li style="margin-bottom: 8px;"><strong>Real time insights</strong> &amp; support from the Pavoi team to help guide your content strategy</li>
              </ul>

              <p style="margin: 0 0 20px;"><strong>Ready to join the movement with the next big name in activewear?</strong></p>

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
                    <p style="margin: 0 0 10px; color: #666; font-size: 13px; font-style: italic;">
                      Questions? Email us at affiliates@pavoi.com
                    </p>
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

# Update template 5: Top Jewelry Invite
case Repo.get(EmailTemplate, 5) do
  nil ->
    IO.puts("Template 5 not found, skipping")

  template ->
    if template.type == :email do
      template
      |> change(%{html_body: top_creators_html})
      |> Repo.update!()

      IO.puts("✓ Updated template 5: #{template.name}")
    else
      IO.puts("Template 5 is not an email template, skipping")
    end
end

# Update template 6: Active Invite
case Repo.get(EmailTemplate, 6) do
  nil ->
    IO.puts("Template 6 not found, skipping")

  template ->
    if template.type == :email do
      template
      |> change(%{html_body: active_html})
      |> Repo.update!()

      IO.puts("✓ Updated template 6: #{template.name}")
    else
      IO.puts("Template 6 is not an email template, skipping")
    end
end

IO.puts("\nDone! Brand styling applied to all templates.")
