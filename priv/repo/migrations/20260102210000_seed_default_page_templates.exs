defmodule Pavoi.Repo.Migrations.SeedDefaultPageTemplates do
  use Ecto.Migration

  @default_html """
  <div class="join-page">
    <div class="join-container">
      <div class="join-header">
        <span class="join-logo">PAVOI</span>
      </div>

      <div class="join-content">
        <h1>Join the Pavoi Creator Program</h1>

        <div class="join-benefits">
          <p>Get access to:</p>
          <ul>
            <li><strong>Free product samples</strong> shipped directly to you</li>
            <li><strong>Competitive commissions</strong> on every sale from your content</li>
            <li><strong>Early access</strong> to new drops before anyone else</li>
            <li><strong>Direct support</strong> from our team for collabs and questions</li>
          </ul>
        </div>

        <div class="join-lark-info">
          <p>
            We use <strong>Lark</strong>
            (a free messaging app by ByteDance, TikTok's parent company)
            for our creator community. After submitting this form, you'll be redirected to join our Lark group.
          </p>
        </div>

        <div data-form-type="consent" data-button-text="JOIN THE PROGRAM" data-email-label="Email" data-phone-label="Phone Number" data-phone-placeholder="(555) 123-4567" class="consent-form-placeholder">
          <p style="padding: 20px; background: #f0f0f0; text-align: center; border-radius: 8px;">
            [Consent Form - Edit traits in the right panel]
          </p>
        </div>
      </div>
    </div>
  </div>
  """

  @default_form_config %{
    "button_text" => "JOIN THE PROGRAM",
    "email_label" => "Email",
    "phone_label" => "Phone Number",
    "phone_placeholder" => "(555) 123-4567"
  }

  def up do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Insert default page templates for each lark preset
    templates = [
      %{
        name: "Default Join Page - Jewelry",
        lark_preset: "jewelry",
        type: "page",
        subject: "(page template)",
        html_body: @default_html,
        form_config: @default_form_config,
        is_default: true,
        is_active: true,
        inserted_at: now,
        updated_at: now
      },
      %{
        name: "Default Join Page - Active",
        lark_preset: "active",
        type: "page",
        subject: "(page template)",
        html_body: @default_html,
        form_config: @default_form_config,
        is_default: true,
        is_active: true,
        inserted_at: now,
        updated_at: now
      },
      %{
        name: "Default Join Page - Top Creators",
        lark_preset: "top_creators",
        type: "page",
        subject: "(page template)",
        html_body: @default_html,
        form_config: @default_form_config,
        is_default: true,
        is_active: true,
        inserted_at: now,
        updated_at: now
      }
    ]

    for template <- templates do
      execute("""
      INSERT INTO email_templates (name, lark_preset, type, subject, html_body, form_config, is_default, is_active, inserted_at, updated_at)
      VALUES (
        '#{template.name}',
        '#{template.lark_preset}',
        '#{template.type}',
        '#{template.subject}',
        '#{String.replace(template.html_body, "'", "''")}',
        '#{Jason.encode!(template.form_config)}',
        #{template.is_default},
        #{template.is_active},
        '#{template.inserted_at}',
        '#{template.updated_at}'
      )
      """)
    end
  end

  def down do
    execute("DELETE FROM email_templates WHERE type = 'page' AND name LIKE 'Default Join Page%'")
  end
end
