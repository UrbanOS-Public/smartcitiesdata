defmodule AndiWeb.DatasetController do
  use AndiWeb, :controller

  alias SCOS.RegistryMessage

  def create(conn, _params) do
    with message <- conn.body_params,
         {:ok, dataset} <- RegistryMessage.new(message),
         :ok <- Andi.Kafka.send_to_kafka(dataset) do
      conn
      |> put_status(:created)
      |> json(dataset)
    else
      _ ->
        conn
        |> put_status(:internal_server_error)
        |> json("Unable to process your request")
    end
  end
end
