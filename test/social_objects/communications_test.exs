defmodule SocialObjects.CommunicationsTest do
  use SocialObjects.DataCase, async: true

  alias SocialObjects.Catalog
  alias SocialObjects.Communications

  describe "duplicate_email_template/2" do
    test "duplicates template content and resets active/default flags" do
      brand = unique_brand_fixture()

      {:ok, template} =
        Communications.create_email_template(brand.id, %{
          name: "Welcome Sequence",
          subject: "Welcome!",
          html_body: "<p>Hello creator</p>",
          text_body: "Hello creator",
          type: "email",
          is_active: false,
          is_default: true
        })

      {:ok, duplicate} = Communications.duplicate_email_template(brand.id, template.id)

      assert duplicate.name == "Copy of Welcome Sequence"
      assert duplicate.subject == template.subject
      assert duplicate.html_body == template.html_body
      assert duplicate.text_body == template.text_body
      assert duplicate.type == :email
      assert duplicate.is_active == true
      assert duplicate.is_default == false
    end

    test "increments duplicate names when copy names already exist" do
      brand = unique_brand_fixture()

      {:ok, template} =
        Communications.create_email_template(brand.id, %{
          name: "Follow Up",
          subject: "Checking in",
          html_body: "<p>Checking in</p>",
          type: "email"
        })

      {:ok, first_duplicate} = Communications.duplicate_email_template(brand.id, template.id)
      {:ok, second_duplicate} = Communications.duplicate_email_template(brand.id, template.id)

      assert first_duplicate.name == "Copy of Follow Up"
      assert second_duplicate.name == "Copy of Follow Up (2)"
    end

    test "duplicates page template fields including lark preset and form config" do
      brand = unique_brand_fixture()
      form_config = %{"button_text" => "JOIN NOW", "phone_label" => "Phone"}

      {:ok, page_template} =
        Communications.create_email_template(brand.id, %{
          name: "Default Join Page",
          subject: "Page Template",
          html_body: "<div>Join form</div>",
          type: "page",
          lark_preset: "active",
          is_default: true,
          form_config: form_config
        })

      {:ok, duplicate} = Communications.duplicate_email_template(brand.id, page_template.id)

      assert duplicate.name == "Copy of Default Join Page"
      assert duplicate.type == :page
      assert duplicate.lark_preset == :active
      assert duplicate.form_config == form_config
      assert duplicate.is_default == false
      assert duplicate.is_active == true
    end
  end

  defp unique_brand_fixture do
    unique = System.unique_integer([:positive])

    {:ok, brand} =
      Catalog.create_brand(%{
        name: "Brand #{unique}",
        slug: "brand-#{unique}"
      })

    brand
  end
end
