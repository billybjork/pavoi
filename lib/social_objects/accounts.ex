defmodule SocialObjects.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias SocialObjects.Repo

  alias SocialObjects.Accounts.{User, UserBrand, UserToken}
  alias SocialObjects.Catalog.Brand

  ## Platform Admin

  @doc """
  Returns true if the user is a platform admin.
  """
  def platform_admin?(%User{is_admin: true}), do: true
  def platform_admin?(_), do: false

  @doc """
  Lists all users with their brand memberships preloaded.
  """
  def list_all_users do
    User
    |> preload(user_brands: :brand)
    |> order_by([u], asc: u.email)
    |> Repo.all()
  end

  @doc """
  Gets a user with their brand memberships preloaded.
  """
  def get_user_with_brands!(id) do
    User
    |> preload(user_brands: :brand)
    |> Repo.get!(id)
  end

  @doc """
  Gets the most recent session timestamp for a user.
  """
  def get_last_session_at(%User{id: user_id}) do
    from(t in UserToken,
      where: t.user_id == ^user_id and t.context == "session",
      select: max(t.inserted_at)
    )
    |> Repo.one()
  end

  @doc """
  Updates a user's admin status.
  """
  def set_admin_status(%User{} = user, is_admin) when is_boolean(is_admin) do
    user
    |> Ecto.Changeset.change(is_admin: is_admin)
    |> Repo.update()
  end

  @doc """
  Removes a user from a brand.
  """
  def remove_user_from_brand(%User{} = user, %Brand{} = brand) do
    from(ub in UserBrand,
      where: ub.user_id == ^user.id and ub.brand_id == ^brand.id
    )
    |> Repo.delete_all()
  end

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Returns true if any user exists.
  """
  def any_users? do
    Repo.exists?(from(u in User, select: 1, limit: 1))
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Registers a user and assigns them to a brand with a role.
  """
  def register_user_for_brand(attrs, %Brand{} = brand, role \\ :viewer) do
    Repo.transaction(fn ->
      with {:ok, user} <- register_user(attrs),
           {:ok, _} <- create_user_brand(user, brand, role) do
        user
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Creates a user with a temporary password.

  The user will be required to change their password on first login.
  Returns {:ok, user, temp_password} on success.
  """
  def create_user_with_temp_password(email) when is_binary(email) do
    temp_password = generate_temp_password()

    changeset =
      %User{}
      |> User.email_changeset(%{email: email})
      |> User.password_changeset(%{password: temp_password}, hash_password: true)
      |> Ecto.Changeset.put_change(:must_change_password, true)

    case Repo.insert(changeset) do
      {:ok, user} -> {:ok, user, temp_password}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp generate_temp_password do
    :crypto.strong_rand_bytes(12)
    |> Base.url_encode64()
    |> binary_part(0, 16)
  end

  ## User brands

  @doc """
  Lists brand memberships for a user with brand preloaded.
  For admin users, returns all brands in the system.
  """
  def list_user_brands(%User{is_admin: true}) do
    # Admins have access to all brands
    SocialObjects.Catalog.list_brands()
    |> Enum.map(fn brand -> %{brand: brand} end)
  end

  def list_user_brands(%User{} = user) do
    from(ub in UserBrand,
      where: ub.user_id == ^user.id,
      preload: [:brand],
      order_by: [asc: ub.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns true if the user has access to the brand.
  Admin users have access to all brands.
  """
  def user_has_brand_access?(%User{is_admin: true}, %Brand{}), do: true

  def user_has_brand_access?(%User{} = user, %Brand{} = brand) do
    Repo.exists?(
      from(ub in UserBrand,
        where: ub.user_id == ^user.id and ub.brand_id == ^brand.id,
        select: 1,
        limit: 1
      )
    )
  end

  @doc """
  Gets the user's role for a brand.
  Platform admins are treated as owners for all brands.
  Returns :owner, :admin, :viewer, or nil if no access.
  """
  def get_user_brand_role(%User{is_admin: true}, %Brand{}), do: :owner

  def get_user_brand_role(%User{} = user, %Brand{} = brand) do
    from(ub in UserBrand,
      where: ub.user_id == ^user.id and ub.brand_id == ^brand.id,
      select: ub.role
    )
    |> Repo.one()
  end

  @doc """
  Checks if a user has at least the specified role for a brand.
  Platform admins always return true.
  """
  def user_has_role?(%User{is_admin: true}, %Brand{}, _min_role), do: true

  def user_has_role?(%User{} = user, %Brand{} = brand, min_role) do
    case get_user_brand_role(user, brand) do
      nil -> false
      role -> role_at_least?(role, min_role)
    end
  end

  defp role_at_least?(role, min_role), do: role_level(role) >= role_level(min_role)

  defp role_level(:owner), do: 3
  defp role_level(:admin), do: 2
  defp role_level(:viewer), do: 1
  defp role_level(_), do: 0

  @doc """
  Gets the default brand for a user.
  """
  def get_default_brand_for_user(%User{} = user) do
    from(ub in UserBrand,
      where: ub.user_id == ^user.id,
      join: b in assoc(ub, :brand),
      order_by: [asc: ub.inserted_at],
      select: b,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Creates a user-brand relationship.
  """
  def create_user_brand(%User{} = user, %Brand{} = brand, role \\ :viewer) do
    %UserBrand{user_id: user.id, brand_id: brand.id}
    |> UserBrand.changeset(%{role: role})
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `SocialObjects.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email directly.
  """
  def update_user_email(user, attrs) do
    user
    |> User.email_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `SocialObjects.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Ecto.Changeset.put_change(:must_change_password, false)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
