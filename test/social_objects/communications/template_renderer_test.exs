defmodule SocialObjects.Communications.TemplateRendererTest do
  use ExUnit.Case, async: true

  alias SocialObjects.Catalog.Brand
  alias SocialObjects.Communications.EmailTemplate
  alias SocialObjects.Communications.TemplateRenderer
  alias SocialObjects.Creators.Creator

  test "render/3 keeps template logo path and keeps links in current environment" do
    endpoint_url = SocialObjectsWeb.Endpoint.url()

    template = %EmailTemplate{
      subject: "Hi {{creator_name}}",
      html_body: """
      <img src="/images/pavoi-logo-email.png" alt="Logo" width="200" height="40">
      <a href="/readme">Readme</a>
      """,
      lark_preset: :jewelry
    }

    creator = %Creator{id: 42, first_name: "Casey"}
    brand = %Brand{id: 10, slug: "acme", primary_domain: "brand.example.com"}

    {subject, html, _text} = TemplateRenderer.render(template, creator, brand)

    assert subject == "Hi Casey"
    assert html =~ "src=\"#{endpoint_url}/images/pavoi-logo-email.png\""
    assert html =~ ~s(height="40")
    assert html =~ "href=\"#{endpoint_url}/b/acme/readme\""
  end

  test "render_page_html/2 supports brand_logo_url variable and absolutizes relative URLs" do
    endpoint_url = SocialObjectsWeb.Endpoint.url()

    brand = %Brand{
      id: 7,
      slug: "active",
      primary_domain: "community.example.com",
      logo_url: "https://cdn.example.com/logos/active.png"
    }

    html =
      TemplateRenderer.render_page_html(
        """
        <img src="{{brand_logo_url}}" alt="Brand">
        <img src="/images/secondary.png" alt="Secondary">
        <a href="/join">Join</a>
        """,
        brand
      )

    assert html =~ "src=\"https://cdn.example.com/logos/active.png\""
    assert html =~ "src=\"#{endpoint_url}/images/secondary.png\""
    assert html =~ "href=\"#{endpoint_url}/b/active/join\""
  end

  test "render_page_html/2 normalizes legacy app.pavoi.com image host" do
    endpoint_url = SocialObjectsWeb.Endpoint.url()
    brand = %Brand{id: 9, slug: "pavoi"}

    html =
      TemplateRenderer.render_page_html(
        """
        <img src="https://app.pavoi.com/images/pavoi-logo-email.png" alt="Legacy">
        """,
        brand
      )

    assert html =~ "src=\"#{endpoint_url}/images/pavoi-logo-email.png\""
  end
end
