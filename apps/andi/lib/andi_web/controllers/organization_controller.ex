defmodule AndiWeb.OrganizationController do
  use AndiWeb, :controller

  require Logger
  alias SmartCity.Organization

  def create(conn, _params) do
    message = add_uuid(conn.body_params)
    pre_id = message["id"]

    with :ok <- ensure_new_org(pre_id),
         {:ok, organization} <- Organization.new(message),
         :ok <- authenticate(),
         {:ok, ldap_org} <- write_to_ldap(organization),
         :ok <- write_to_redis(ldap_org) do
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
    case Organization.get(id) do
      {:ok, %Organization{}} ->
        Logger.error("ID #{id} already exists")
        %RuntimeError{message: "ID #{id} already exists"}

      {:error, %Organization.NotFound{}} ->
        :ok

      _ ->
        %RuntimeError{message: "Unknown error for #{id}"}
    end
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

  defp write_to_redis(org) do
    case Organization.write(org) do
      {:ok, _} ->
        :ok

      error ->
        delete_from_ldap(org.orgName)
        error
    end
  end

  defp delete_from_ldap(orgName) do
    orgName
    |> keyword_dn()
    |> Paddle.delete()
  end

  def get_all(conn, _params) do
    with {:ok, orgs} <- Organization.get_all() do
      conn
      |> put_status(:ok)
      |> json(orgs)
    else
      error ->
        Logger.error("Failed to retrieve organizations: #{inspect(error)}")

        conn
        |> put_status(:not_found)
        |> json("Unable to process your request")
    end
  end
end
