defmodule PavoiWeb.Redirector do
  @moduledoc """
  Simple controller for redirecting routes.
  """
  use PavoiWeb, :controller

  def redirect_to_readme(conn, _params) do
    redirect(conn, to: ~p"/readme")
  end

  def redirect_to_product_sets(conn, _params) do
    redirect(conn, to: ~p"/product-sets")
  end

  def redirect_to_product_sets_products(conn, _params) do
    redirect(conn, to: ~p"/product-sets?tab=products")
  end
end
