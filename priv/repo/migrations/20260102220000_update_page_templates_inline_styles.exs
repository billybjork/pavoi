defmodule Pavoi.Repo.Migrations.UpdatePageTemplatesInlineStyles do
  use Ecto.Migration

  @styled_html """
  <section style="min-height: 100vh; background: linear-gradient(180deg, #f8f8f8 0%, #e8e8e8 100%); padding: 40px 20px; font-family: Georgia, 'Times New Roman', serif;">
    <div style="max-width: 500px; margin: 0 auto; background: #fff; box-shadow: 0 4px 20px rgba(0,0,0,0.1); border-radius: 8px; overflow: hidden;">
      <div style="text-align: center; padding: 40px 30px 20px; background: #2E4042;">
        <span style="font-size: 28px; letter-spacing: 4px; color: #fff;">PAVOI</span>
      </div>
      <div style="padding: 30px 40px 40px;">
        <h1 style="text-align: center; color: #2E4042; font-weight: normal; margin: 0 0 30px 0; font-size: 24px;">
          Join the Pavoi Creator Program
        </h1>
        <div style="margin-bottom: 30px;">
          <p style="margin: 0 0 15px 0; color: #333;">Get access to:</p>
          <ul style="margin: 0; padding-left: 20px; color: #555; line-height: 1.8;">
            <li><strong>Free product samples</strong> shipped directly to you</li>
            <li><strong>Competitive commissions</strong> on every sale</li>
            <li><strong>Early access</strong> to new drops</li>
            <li><strong>Direct support</strong> from our team</li>
          </ul>
        </div>
        <div data-form-type="consent" data-button-text="JOIN THE PROGRAM" data-email-label="Email" data-phone-label="Phone Number" data-phone-placeholder="(555) 123-4567" style="padding: 30px; border: 3px dashed #A9BDB6; background: linear-gradient(135deg, #f8faf9 0%, #e8f0ec 100%); text-align: center; border-radius: 8px; margin: 20px 0;">
          <div style="color: #2E4042; margin-bottom: 10px;">
            <strong style="font-size: 18px;">📋 Consent Form</strong>
          </div>
          <p style="color: #666; margin: 0; font-size: 14px;">
            The SMS consent form will appear here.<br>
            <small>Edit properties in the right panel to customize button text and labels.</small>
          </p>
        </div>
      </div>
    </div>
  </section>
  """

  def up do
    # Update all page templates that have the old class-based HTML
    execute("""
    UPDATE email_templates
    SET html_body = '#{String.replace(@styled_html, "'", "''")}'
    WHERE type = 'page'
    AND html_body LIKE '%class="join-page"%'
    """)
  end

  def down do
    # No need to revert - the old HTML wasn't usable in GrapesJS anyway
    :ok
  end
end
