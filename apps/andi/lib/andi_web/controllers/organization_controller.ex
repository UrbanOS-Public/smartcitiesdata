defmodule AndiWeb.OrganizationController do
  @moduledoc """
  Creates new organizations and retrieves existing ones through LDAP.
  """
  use AndiWeb, :controller

  require Logger
  alias SmartCity.Registry.Organization, as: RegOrganization
  alias SmartCity.Organization
  import Andi
  import SmartCity.Event, only: [organization_update: 0]

  @doc """
  Parse a data message to create and authenticate a new organization to store in LDAP
  """
  @spec create(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def create(conn, _params) do
    message =
      conn.body_params
      |> remove_blank_keys()
      |> add_uuid()

    with :ok <- ensure_new_org(message["id"]),
         {:ok, old_organization} <- RegOrganization.new(message),
         {:ok, organization} <- Organization.new(message),
         :ok <- authenticate(),
         {:ok, ldap_org} <- write_to_ldap(organization),
         {:ok, _id} <- write_old_organization(old_organization),
         :ok <- write_organization(ldap_org) do
      conn
      |> put_status(:created)
      |> json(ldap_org)
    else
      error ->
        Logger.error("Failed to create organization: #{inspect(error)}")

        conn
        |> put_status(:internal_server_error)
        |> json("Unable to process your request: #{inspect(error)}")
    end
  end

  defp ensure_new_org(id) do
    case Brook.get(instance_name(), :org, id) do
      {:ok, %Organization{}} ->
        Logger.error("ID #{id} already exists")
        %RuntimeError{message: "ID #{id} already exists"}

      {:ok, nil} ->
        :ok

      _ ->
        %RuntimeError{message: "Unknown error for #{id}"}
    end
  end

  defp remove_blank_keys(message) do
    message
    |> Enum.filter(fn {_, v} -> v != "" end)
    |> Map.new()
  end

  defp add_uuid(message) do
    uuid = UUID.uuid4()

    Map.merge(message, %{"id" => uuid}, fn _k, v1, _v2 -> v1 end)
  end

  defp authenticate do
    user = Application.get_env(:andi, :ldap_user)
    pass = Application.get_env(:andi, :ldap_pass)
    Paddle.authenticate(user, pass)
  end

  defp write_to_ldap(org) do
    attrs = group_attrs(org.orgName)

    org.orgName
    |> keyword_dn()
    |> Paddle.add(attrs)
    |> handle_ldap(org)
  end

  defp group_attrs(orgName) do
    admin =
      :andi
      |> Application.get_env(:ldap_user)
      |> Andi.LdapUtils.encode_dn!()

    [objectClass: ["top", "groupofnames"], cn: orgName, member: admin]
  end

  defp handle_ldap(:ok, org) do
    base = Application.get_env(:paddle, Paddle)[:base]

    cn_ou =
      org.orgName
      |> keyword_dn()
      |> Andi.LdapUtils.encode_dn!()

    org
    |> Map.from_struct()
    |> Map.merge(%{dn: "#{cn_ou},#{base}"})
    |> Organization.new()
  end

  defp handle_ldap(error, _), do: error

  defp keyword_dn(name) do
    [cn: name, ou: Application.get_env(:andi, :ldap_env_ou)]
  end

  defp write_organization(org) do
    case Brook.Event.send(instance_name(), organization_update(), :andi, org) do
      :ok ->
        :ok

      error ->
        delete_from_ldap(org.orgName)
        error
    end
  end

  defp write_old_organization(org), do: RegOrganization.write(org)

  defp delete_from_ldap(orgName) do
    orgName
    |> keyword_dn()
    |> Paddle.delete()
  end

  @doc """
  Retrieve all existing organizations stored in LDAP
  """
  @spec get_all(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get_all(conn, _params) do
    case Brook.get_all_values(instance_name(), :org) do
      {:ok, orgs} ->
        conn
        |> put_status(:ok)
        |> json(orgs)

      {_, error} ->
        Logger.error("Failed to retrieve organizations: #{inspect(error)}")

        conn
        |> put_status(:not_found)
        |> json("Unable to process your request")
    end
  end

  @doc """
  Reposts all of the existing organizations as organization:udpate events on the event stream
  """
  def repost_org_updates(conn, _params) do
    case Andi.Services.OrganizationReposter.repost_all_orgs() do
      :ok ->
        conn
        |> put_status(:ok)
        |> json("Orgs successfully reposted")

      {:error, _} ->
        conn
        |> put_status(500)
        |> json("Failed to repost organizations")
    end
  end

  @doc """
  Sends a user:organization:associate event
  """
  def add_users_to_organization(conn, %{"org_id" => org_id, "users" => users}) do
    case Brook.get(instance_name(), :org, org_id) do
      {:ok, %Organization{}} ->
        Andi.Services.OrganizationAssociateService.associate(org_id, users)

        conn
        |> put_status(200)
        |> json(conn.body_params)

      {:ok, nil} ->
        conn
        |> put_status(400)
        |> json("The organization #{org_id} does not exist")
    end
  end
end
