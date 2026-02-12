defmodule SocialObjects.Repo.Migrations.AddHowToJoinSectionToPageTemplates do
  use Ecto.Migration

  @styled_html """
  <section style="min-height: 100vh; background: linear-gradient(180deg, #e6e7e5 0%, #d8dad8 100%); padding: 40px 20px; font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif;">
    <div style="max-width: 500px; margin: 0 auto; background: #ffffff; box-shadow: 0 4px 20px rgba(0,0,0,0.08); overflow: hidden;">
      <div style="text-align: center; padding: 30px; background: #a9bdb6;">
        <img src="/images/pavoi-logo-email.png" alt="PAVOI" width="200" style="display: block; height: auto; margin: 0 auto;">
      </div>
      <div style="padding: 40px; color: #282828; line-height: 1.7;">
        <h1 style="text-align: center; color: #2e4042; font-weight: normal; margin: 0 0 30px 0; font-size: 24px; letter-spacing: 2px; text-transform: uppercase;">
          Join the Creator Program
        </h1>
        <div style="margin-bottom: 30px;">
          <p style="margin: 0 0 15px 0;">Get access to:</p>
          <ul style="margin: 0; padding-left: 20px; line-height: 1.8;">
            <li style="margin-bottom: 8px;"><strong>Free product samples</strong> shipped directly to you</li>
            <li style="margin-bottom: 8px;"><strong>Competitive commissions</strong> on every sale</li>
            <li style="margin-bottom: 8px;"><strong>Early access</strong> to new drops</li>
            <li style="margin-bottom: 8px;"><strong>Direct support</strong> from our team</li>
          </ul>
        </div>
        <div style="margin-bottom: 30px;">
          <p style="margin: 0 0 15px 0; font-weight: 700;">How to join:</p>
          <ol style="margin: 0; padding-left: 20px; line-height: 1.8;">
            <li>Complete the quick intake form</li>
            <li>Join through your existing Lark account or create an account to join.</li>
          </ol>
          <p style="margin: 15px 0 0 0; font-style: italic;">If creating an account, make sure to use your name &amp; handle!</p>
        </div>
        <div data-form-type="consent" data-button-text="JOIN THE PROGRAM" data-email-label="Email" data-phone-label="Phone Number" data-phone-placeholder="(555) 123-4567" style="padding: 30px; border: 3px dashed #a9bdb6; background: linear-gradient(135deg, #f8faf9 0%, #e8f0ec 100%); text-align: center; border-radius: 8px; margin: 20px 0;">
          <div style="color: #2e4042; margin-bottom: 10px;">
            <strong style="font-size: 18px;">Consent Form</strong>
          </div>
          <p style="color: #666; margin: 0; font-size: 14px;">
            The SMS consent form will appear here.<br>
            <small>Edit properties in the right panel to customize button text and labels.</small>
          </p>
        </div>
      </div>
      <div style="text-align: center; padding: 25px; background: #a9bdb6;">
        <p style="margin: 0; color: #2e4042; font-size: 14px; letter-spacing: 1px;">Together, we're redefining luxury.</p>
      </div>
    </div>
  </section>
  """

  def up do
    # Update all page templates to include the "How to join" section
    execute("""
    UPDATE email_templates
    SET html_body = '#{String.replace(@styled_html, "'", "''")}'
    WHERE type = 'page'
    """)
  end

  def down do
    # Revert to previous version without the "How to join" section
    old_html = """
    <section style="min-height: 100vh; background: linear-gradient(180deg, #e6e7e5 0%, #d8dad8 100%); padding: 40px 20px; font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif;">
      <div style="max-width: 500px; margin: 0 auto; background: #ffffff; box-shadow: 0 4px 20px rgba(0,0,0,0.08); overflow: hidden;">
        <div style="text-align: center; padding: 30px; background: #a9bdb6;">
          <img src="/images/pavoi-logo-email.png" alt="PAVOI" width="200" style="display: block; height: auto; margin: 0 auto;">
        </div>
        <div style="padding: 40px; color: #282828; line-height: 1.7;">
          <h1 style="text-align: center; color: #2e4042; font-weight: normal; margin: 0 0 30px 0; font-size: 24px; letter-spacing: 2px; text-transform: uppercase;">
            Join the Creator Program
          </h1>
          <div style="margin-bottom: 30px;">
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
              <strong style="font-size: 18px;">Consent Form</strong>
            </div>
            <p style="color: #666; margin: 0; font-size: 14px;">
              The SMS consent form will appear here.<br>
              <small>Edit properties in the right panel to customize button text and labels.</small>
            </p>
          </div>
        </div>
        <div style="text-align: center; padding: 25px; background: #a9bdb6;">
          <p style="margin: 0; color: #2e4042; font-size: 14px; letter-spacing: 1px;">Together, we're redefining luxury.</p>
        </div>
      </div>
    </section>
    """

    execute("""
    UPDATE email_templates
    SET html_body = '#{String.replace(old_html, "'", "''")}'
    WHERE type = 'page'
    """)
  end
end
