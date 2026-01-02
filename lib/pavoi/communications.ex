defmodule Pavoi.Communications do
  @moduledoc """
  The Communications context manages email templates and related functionality.
  """

  import Ecto.Query, warn: false

  alias Pavoi.Communications.EmailTemplate
  alias Pavoi.Repo

  ## Email Templates

  @doc """
  Lists all active email templates, ordered by name.
  """
  def list_email_templates do
    list_templates_by_type("email")
  end

  @doc """
  Lists all email templates including inactive ones.
  """
  def list_all_email_templates do
    list_all_templates_by_type("email")
  end

  @doc """
  Lists active templates of a specific type, ordered by name.
  """
  def list_templates_by_type(type) when type in ["email", "page"] do
    from(t in EmailTemplate,
      where: t.type == ^type and t.is_active == true,
      order_by: [asc: t.name]
    )
    |> Repo.all()
  end

  @doc """
  Lists all templates of a specific type including inactive ones, ordered by name.
  """
  def list_all_templates_by_type(type) when type in ["email", "page"] do
    from(t in EmailTemplate,
      where: t.type == ^type,
      order_by: [asc: t.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single email template by ID.

  Raises `Ecto.NoResultsError` if the template does not exist.
  """
  def get_email_template!(id), do: Repo.get!(EmailTemplate, id)

  @doc """
  Gets a single email template by name.

  Returns nil if not found or inactive.
  """
  def get_email_template_by_name(name) do
    Repo.get_by(EmailTemplate, name: name, is_active: true)
  end

  @doc """
  Gets the default email template.

  Returns nil if no default is set.
  """
  def get_default_email_template do
    Repo.get_by(EmailTemplate, type: "email", is_default: true, is_active: true)
  end

  @doc """
  Gets the default page template for a specific lark preset.

  Returns nil if no default is set for that preset.
  """
  def get_default_page_template(lark_preset) do
    Repo.get_by(EmailTemplate,
      type: "page",
      lark_preset: lark_preset,
      is_default: true,
      is_active: true
    )
  end

  @doc """
  Creates an email template.
  """
  def create_email_template(attrs \\ %{}) do
    %EmailTemplate{}
    |> EmailTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an email template.
  """
  def update_email_template(%EmailTemplate{} = template, attrs) do
    template
    |> EmailTemplate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Sets a template as the default, clearing any existing default.

  For page templates, only clears default within the same type+lark_preset combo.
  For email templates, clears all email defaults (backwards compatible).
  """
  def set_default_template(%EmailTemplate{} = template) do
    Repo.transaction(fn ->
      # Clear existing default for same type (and lark_preset for page templates)
      query =
        if template.type == "page" do
          from(t in EmailTemplate,
            where:
              t.type == ^template.type and
                t.lark_preset == ^template.lark_preset and
                t.is_default == true
          )
        else
          from(t in EmailTemplate,
            where: t.type == ^template.type and t.is_default == true
          )
        end

      Repo.update_all(query, set: [is_default: false])

      # Set new default
      template
      |> EmailTemplate.changeset(%{is_default: true})
      |> Repo.update!()
    end)
  end

  @doc """
  Soft-deletes an email template by marking it inactive.
  """
  def delete_email_template(%EmailTemplate{} = template) do
    template
    |> EmailTemplate.changeset(%{is_active: false, is_default: false})
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking template changes.
  """
  def change_email_template(%EmailTemplate{} = template, attrs \\ %{}) do
    EmailTemplate.changeset(template, attrs)
  end
end
