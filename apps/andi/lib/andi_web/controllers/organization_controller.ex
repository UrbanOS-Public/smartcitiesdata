defmodule AndiWeb.OrganizationController do
  use AndiWeb, :controller

  require Logger
  alias SmartCity.Organization

  def create(conn, _params) do
    message = add_uuid(conn.body_params)

    with {:ok, organization} <- Organization.new(message),
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
        |> json("Unable to process your request")
    end
  end

  defp write_to_redis(org) do
    case Organization.write(org) do
      {:ok, _} ->
        :ok

      error ->
        Paddle.delete(cn: org.orgName)
        error
    end
  end

  defp write_to_ldap(org) do
    admin =
      :andi
      |> Application.get_env(:ldap_user)
      |> Andi.LdapUtils.encode_dn!()

    attrs = [objectClass: ["top", "groupofnames"], cn: org.orgName, member: admin]

    [cn: org.orgName]
    |> Paddle.add(attrs)
    |> handle_ldap(org)
  end

  defp handle_ldap(:ok, org) do
    base = Application.get_env(:paddle, Paddle)[:base]

    org
    |> Map.from_struct()
    |> Map.merge(%{dn: "cn=#{org.orgName},#{base}"})
    |> Organization.new()
  end

  defp handle_ldap(error, _), do: error

  defp add_uuid(message) do
    uuid = UUID.uuid4()

    message
    |> Map.merge(%{"id" => uuid})
  end

  defp authenticate do
    user = Application.get_env(:andi, :ldap_user)
    pass = Application.get_env(:andi, :ldap_pass)
    Paddle.authenticate(user, pass)
  end
end
