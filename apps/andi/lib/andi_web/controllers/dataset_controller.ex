defmodule AndiWeb.DatasetController do
  use AndiWeb, :controller

  require Logger
  alias SmartCity.Dataset

  def create(conn, _params) do
    with {:ok, message} <- parse_message(conn.body_params),
         {:ok, dataset} <- Dataset.new(message),
         {:ok, _id} <- Dataset.write(dataset) do
      conn
      |> put_status(:created)
      |> json(dataset)
    else
      error ->
        Logger.error("Failed to create dataset: #{inspect(error)}")

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
