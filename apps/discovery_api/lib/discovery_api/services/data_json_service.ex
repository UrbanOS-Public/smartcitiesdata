defmodule DiscoveryApi.Services.DataJsonService do
  @moduledoc false
  alias DiscoveryApi.Data.DataJson

  def delete_data_json() do
    File.rm_rf(file_path())
  end

  def ensure_data_json_file() do
    case File.stat(file_path()) do
      {:ok, _} -> {:local, file_path()}
      {:error, _} -> create_data_json()
    end
  end

  defp create_data_json() do
    with results <- DataJson.translate_to_open_data_schema(),
         {:ok, json} <- Jason.encode(results),
         :ok <- File.write(file_path(), json) do
      {:local, file_path()}
    else
      _err -> {:error, "Unable to create file"}
    end
  end

  defp file_path() do
    "data.json"
  end
end
