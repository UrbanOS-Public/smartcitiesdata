defmodule AndiWeb.DatasetController do
  use AndiWeb, :controller

  alias SCOS.RegistryMessage

  def create(conn, _params) do
    with {:ok, message} <- parse_message(conn.body_params),
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

  defp parse_message(%{"technical" => %{"systemName" => _}} = msg) do
    {:ok, msg}
  end

  defp parse_message(%{"technical" => technical} = msg) do
    with org_name when not is_nil(org_name) <- Map.get(technical, "orgName"),
         data_name when not is_nil(data_name) <- Map.get(technical, "dataName"),
         system_name <- "#{org_name}__#{data_name}" do
      {:ok, put_in(msg, ["technical", "systemName"], system_name)}
    else
      _ -> {:error, "Cannot parse message: #{inspect(msg)}"}
    end
  end

  defp parse_message(msg), do: {:error, "Cannot parse message: #{inspect(msg)}"}
end
