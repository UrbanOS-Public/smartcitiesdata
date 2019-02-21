defmodule Forklift.PrestoClient do
  @moduledoc false
  require Logger
  alias Forklift.{DatasetRegistryServer, Statement}

  def upload_data(dataset_id, messages) do
    dataset_id
    |> DatasetRegistryServer.get_schema()
    |> Statement.build(messages)
    |> execute_statement()

    :ok
  rescue
    e -> Logger.error("Error uploading data, #{e}")
  end

  defp execute_statement(statement) do
    statement
    |> Prestige.execute(catalog: "hive", schema: "default", user: "forklift")
    |> Prestige.prefetch()
  end
end
