defmodule AndiWeb.DatasetController do
  use AndiWeb, :controller

  alias Andi.Services.DatasetRetrieval

  def index(conn, _params) do
    datasets = DatasetRetrieval.get_all!()

    render(conn, "index.html", datasets: datasets)
  end

  defp parse_message(msg), do: {:error, "Cannot parse message: #{inspect(msg)}"}

  defp trim_fields(%{"id" => id, "technical" => technical, "business" => business} = map) do
    %{
      map
      | "id" => String.trim(id),
        "technical" => trim_map(technical),
        "business" => trim_map(business)
    }
  end

  defp trim_map(data) do
    data
    |> Enum.map(fn
      {key, val} when is_binary(val) -> {key, String.trim(val)}
      {key, val} when is_list(val) -> {key, trim_list(val)}
      field -> field
    end)
    |> Enum.into(Map.new())
  end

  defp trim_list(data) do
    Enum.map(data, fn
      item when is_binary(item) -> String.trim(item)
      item -> item
    end)
  end

  defp downcase_schema(%{"technical" => technical} = msg) do
    downcased_schema =
      technical
      |> Map.get("schema")
      |> Andi.SchemaDowncaser.downcase_schema()

    put_in(msg, ["technical", "schema"], downcased_schema)
  end

  defp create_system_name(%{"technical" => technical} = msg) do
    with org_name when not is_nil(org_name) <- Map.get(technical, "orgName"),
         data_name when not is_nil(data_name) <- Map.get(technical, "dataName"),
         system_name <- "#{org_name}__#{data_name}" do
      {:ok, put_in(msg, ["technical", "systemName"], system_name)}
    else
      _ -> {:error, "Cannot parse message: #{inspect(msg)}"}
    end
  end
end
