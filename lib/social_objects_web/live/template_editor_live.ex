defmodule SocialObjectsWeb.TemplateEditorLive do
  @moduledoc """
  Full-page LiveView for editing templates with GrapesJS.

  Supports two template types:
  - "email" - Email templates for outreach campaigns
  - "page" - Page templates for web pages like the SMS consent form

  Routes:
  - /templates/new          - Create new email template
  - /templates/new?type=page - Create new page template
  - /templates/:id/edit     - Edit existing template
  """
  use SocialObjectsWeb, :live_view

  on_mount {SocialObjectsWeb.NavHooks, :set_current_page}

  alias SocialObjects.Communications
  alias SocialObjects.Communications.EmailTemplate
  alias SocialObjectsWeb.BrandRoutes
  import SocialObjectsWeb.BrandPermissions

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    # Support ?type=page query param for page templates
    template_type = if params["type"] == "page", do: :page, else: :email
    brand_id = socket.assigns.current_brand.id
    template = %EmailTemplate{brand_id: brand_id, lark_preset: :jewelry, type: template_type}
    changeset = Communications.change_email_template(template)

    page_title =
      if template_type == :page, do: "New Page Template", else: "New Email Template"

    socket
    |> assign(:page_title, page_title)
    |> assign(:template, template)
    |> assign(:template_type, template_type)
    |> assign(:return_to, templates_return_path(template_type))
    |> assign(:form, to_form(changeset))
    |> assign(:is_new, true)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    brand_id = socket.assigns.current_brand.id
    template = Communications.get_email_template!(brand_id, id)
    changeset = Communications.change_email_template(template)

    page_title =
      if template.type == :page, do: "Edit Page Template", else: "Edit Email Template"

    socket
    |> assign(:page_title, page_title)
    |> assign(:template, template)
    |> assign(:template_type, template.type)
    |> assign(:return_to, templates_return_path(template.type))
    |> assign(:form, to_form(changeset))
    |> assign(:is_new, false)
  end

  @impl true
  def handle_event("validate", %{"email_template" => params}, socket) do
    params = normalize_form_config_param(params)

    changeset =
      socket.assigns.template
      |> Communications.change_email_template(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("template_html_updated", %{"html" => html} = params, socket)
      when is_binary(html) and html != "" do
    # Extract form_config if present (for page templates)
    form_config =
      params
      |> Map.get("form_config", socket.assigns.form[:form_config].value || %{})
      |> normalize_form_config_value()

    # Update the form with the HTML from the visual editor
    current_params = %{
      "name" => socket.assigns.form[:name].value || "",
      "subject" => socket.assigns.form[:subject].value || "",
      "lark_preset" => socket.assigns.form[:lark_preset].value || "jewelry",
      "type" => socket.assigns.template_type,
      "html_body" => html,
      "form_config" => form_config
    }

    changeset = Communications.change_email_template(socket.assigns.template, current_params)
    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  # Ignore empty or missing HTML updates (happens during editor initialization)
  def handle_event("template_html_updated", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"email_template" => params}, socket) do
    authorize socket, :admin do
      params =
        params
        |> with_fallback_html_body(socket)
        |> normalize_form_config_param()

      brand_id = socket.assigns.current_brand.id

      result =
        if socket.assigns.is_new do
          Communications.create_email_template(brand_id, params)
        else
          Communications.update_email_template(socket.assigns.template, params)
        end

      case result do
        {:ok, _template} ->
          socket =
            socket
            |> put_flash(:info, "Template saved successfully")
            |> push_navigate(
              to:
                BrandRoutes.brand_path(
                  socket.assigns.current_brand,
                  socket.assigns.return_to,
                  socket.assigns.current_host
                )
            )

          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}
      end
    end
  end

  def form_config_input_value(form_value) do
    form_value
    |> normalize_form_config_value()
    |> Jason.encode!()
  end

  defp normalize_form_config_param(params) do
    Map.update(params, "form_config", %{}, &normalize_form_config_value/1)
  end

  defp with_fallback_html_body(params, socket) do
    html_body = Map.get(params, "html_body")

    if is_binary(html_body) and String.trim(html_body) != "" do
      params
    else
      fallback_html =
        socket.assigns.form[:html_body].value
        |> case do
          value when is_binary(value) -> String.trim(value)
          _ -> ""
        end

      if fallback_html == "" do
        params
      else
        Map.put(params, "html_body", fallback_html)
      end
    end
  end

  defp templates_return_path(:page), do: "/creators?pt=templates&tt=page"
  defp templates_return_path(_), do: "/creators?pt=templates"

  # Handles both normal JSON (e.g. "{}") and repeatedly quoted JSON strings.
  defp normalize_form_config_value(value, depth \\ 0)

  defp normalize_form_config_value(_value, depth) when depth >= 5, do: %{}

  defp normalize_form_config_value(value, _depth) when is_map(value), do: value

  defp normalize_form_config_value(value, depth) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> normalize_form_config_value(decoded, depth + 1)
      _ -> %{}
    end
  end

  defp normalize_form_config_value(_value, _depth), do: %{}
end
