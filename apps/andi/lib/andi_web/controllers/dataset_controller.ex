defmodule AndiWeb.DatasetController do
  use AndiWeb, :controller

  require Logger
  alias SmartCity.Dataset

  def create(conn, _params) do
    with message <- add_uuid(conn.body_params),
         {:ok, parsed_message} <- parse_message(message),
         {:ok, dataset} <- Dataset.new(parsed_message),
         :valid <- is_valid(dataset),
         {:ok, _id} <- Dataset.write(dataset) do
      respond(conn, :created, dataset)
    else
      {:invalid, reason} ->
        respond(conn, :bad_request, %{reason: reason})

      error ->
        Logger.error("Failed to create dataset: #{inspect(error)}")
        respond(conn, :internal_server_error, "Unable to process your request")
    end
  end

  def get_all(conn, _params) do
    with {:ok, datasets} <- Dataset.get_all() do
      respond(conn, :ok, datasets)
    else
      error ->
        Logger.error("Failed to retrieve datasets: #{inspect(error)}")
        respond(conn, :not_found, "Unable to process your request")
    end
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

  defp is_valid(dataset) do
    found_match =
      Dataset.get_all!()
      |> Enum.any?(fn existing_dataset ->
        dataset.id != existing_dataset.id && dataset.technical.systemName == existing_dataset.technical.systemName
      end)

    case found_match do
      true -> {:invalid, "Existing dataset has the same orgName and dataName"}
      false -> :valid
    end
  end

  defp respond(conn, status, body) do
    conn
    |> put_status(status)
    |> json(body)
  end

  defp add_uuid(message) do
    uuid = UUID.uuid4()

    Map.merge(message, %{"id" => uuid}, fn _k, v1, _v2 -> v1 end)
  end
end
