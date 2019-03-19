defmodule AndiWeb.OrganizationController do
  use AndiWeb, :controller

  require Logger
  alias SmartCity.Organization

  def create(conn, _params) do
    with {:ok, organization} <- Organization.new(conn.body_params),
         :ok <- Andi.Kafka.send_to_kafka(organization) do
      conn
      |> put_status(:created)
      |> json(organization)
    else
      error ->
        Logger.error("Failed to create organization: #{inspect(error)}")

        conn
        |> put_status(:internal_server_error)
        |> json("Unable to process your request")
    end
  end
end
