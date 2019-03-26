defmodule AndiWeb.OrganizationController do
  use AndiWeb, :controller

  require Logger
  alias SmartCity.Organization

  def create(conn, _params) do
    with {:ok, organization} <- Organization.new(conn.body_params),
         :ok <- Paddle.authenticate([cn: "admin"], "admin"),
         {:ok, ldap_org} <- write_to_ldap(organization),
         {:ok, _id} <- Organization.write(ldap_org),
         :ok <- Andi.Kafka.send_to_kafka(ldap_org) do
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

  defp write_to_ldap(org) do
    admin = Application.get_env(:andi, :ldap_admin)
    group = [cn: org.orgName]
    attrs = [objectClass: ["top", "groupofnames"], cn: org.orgName, member: admin]
    base = Application.get_env(:paddle, Paddle)[:base]

    with :ok <- Paddle.add(group, attrs),
         map <- Map.from_struct(org),
         new_map <- Map.merge(map, %{dn: "cn=#{org.orgName},#{base}"}) do
      Organization.new(new_map)
    else
      error -> error
    end
  end
end
