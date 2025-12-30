defmodule Pavoi.Communications.TemplateRenderer do
  @moduledoc """
  Renders email templates for sending.

  Templates are stored as complete HTML. At send time, any Lark URLs
  are replaced with join URLs that capture SMS consent before redirect.
  Plain text version is auto-generated from HTML if not provided.
  """

  alias Pavoi.Communications.EmailTemplate
  alias Pavoi.Outreach

  # Known Lark invite URL patterns to replace with join URLs
  @lark_url_pattern ~r{https://applink\.larksuite\.com/[^"'\s<>]+}

  @doc """
  Renders a template for sending to a specific creator.

  Replaces any Lark URLs with join URLs that capture SMS consent.
  Returns {subject, html_body, text_body}
  """
  def render(%EmailTemplate{} = template, creator) do
    join_url = generate_join_url(creator.id, template.lark_preset)

    html_body = replace_lark_urls(template.html_body, join_url)

    text_body =
      if template.text_body && template.text_body != "" do
        replace_lark_urls(template.text_body, join_url)
      else
        html_to_text(html_body)
      end

    {template.subject, html_body, text_body}
  end

  @doc """
  Renders a template for preview (no URL replacement).

  Returns {subject, html_body}
  """
  def render_preview(%EmailTemplate{} = template) do
    {template.subject, template.html_body}
  end

  defp generate_join_url(creator_id, lark_preset) do
    token = Outreach.generate_join_token(creator_id, lark_preset)
    "#{PavoiWeb.Endpoint.url()}/join/#{token}"
  end

  defp replace_lark_urls(content, join_url) when is_binary(content) do
    Regex.replace(@lark_url_pattern, content, join_url)
  end

  defp replace_lark_urls(nil, _join_url), do: nil

  # Convert HTML to plain text by stripping tags
  defp html_to_text(html) when is_binary(html) do
    html
    |> String.replace(~r/<br\s*\/?>/, "\n")
    |> String.replace(~r/<\/p>/, "\n\n")
    |> String.replace(~r/<\/div>/, "\n")
    |> String.replace(~r/<\/li>/, "\n")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/&nbsp;/, " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  defp html_to_text(nil), do: ""
end
