defmodule SocialObjectsWeb.BrandPermissions do
  @moduledoc """
  Permission checking helpers for brand-scoped operations.

  This module provides functions to check user permissions based on their
  brand role (:owner, :admin, :viewer).

  ## Role Hierarchy

  - **Owner**: Full access to all operations including user management
  - **Admin**: Can perform all operations except user management
  - **Viewer**: Read-only access, cannot modify data

  ## Usage in Event Handlers

  Use the `authorize` macro for clean permission checks:

      def handle_event("delete_item", params, socket) do
        authorize socket, :admin do
          # perform admin action
        end
      end
  """

  @doc """
  Returns true if the user has edit permissions (owner or admin role).
  For use in templates to conditionally show/hide edit controls.
  """
  def can_edit?(assigns) do
    assigns[:current_brand_role] in [:owner, :admin]
  end

  @doc """
  Returns true if the user is the brand owner.
  For use in templates to conditionally show owner-only controls.
  """
  def owner?(assigns) do
    assigns[:current_brand_role] == :owner
  end

  @doc """
  Checks if the socket has at least the specified role.
  Returns true if authorized, false otherwise.
  """
  def has_role?(_socket, :viewer), do: true

  def has_role?(socket, :admin) do
    socket.assigns.current_brand_role in [:owner, :admin]
  end

  def has_role?(socket, :owner) do
    socket.assigns.current_brand_role == :owner
  end

  @doc """
  Checks if the socket has at least the specified role.
  Returns :ok if authorized, {:error, :unauthorized} otherwise.
  """
  def require_role(_socket, :viewer), do: :ok

  def require_role(socket, :admin) do
    if socket.assigns.current_brand_role in [:owner, :admin] do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  def require_role(socket, :owner) do
    if socket.assigns.current_brand_role == :owner do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Returns a standard unauthorized response for use in handle_event callbacks.
  """
  def unauthorized_response(socket) do
    {:noreply,
     Phoenix.LiveView.put_flash(socket, :error, "You don't have permission to perform this action.")}
  end

  @doc """
  Macro for authorizing actions in event handlers.
  Executes the block if authorized, returns unauthorized_response otherwise.

  ## Examples

      def handle_event("delete", params, socket) do
        authorize socket, :admin do
          # delete logic here
          {:noreply, socket}
        end
      end
  """
  defmacro authorize(socket, role, do: block) do
    quote do
      if SocialObjectsWeb.BrandPermissions.has_role?(unquote(socket), unquote(role)) do
        unquote(block)
      else
        SocialObjectsWeb.BrandPermissions.unauthorized_response(unquote(socket))
      end
    end
  end
end
