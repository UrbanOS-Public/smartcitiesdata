defmodule AndiWeb.DatasetController do
  use AndiWeb, :controller

  def create(conn, _params) do
    dataset = conn.body_params

    with {:ok, dataset_struct} <- Dataset.new(dataset),
         :ok <- Andi.Kafka.send_to_kafka(dataset_struct) do
      conn
      |> put_status(:created)
      |> json(dataset_struct)
    else
      _ ->
        conn
        |> put_status(:internal_server_error)
        |> json("Unable to process your request")
    end
  end
end
