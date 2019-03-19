defmodule Forklift.PersistenceClient do
  @moduledoc false
  require Logger
  alias Forklift.{DatasetRegistryServer, Statement}

  def upload_data(dataset_id, messages) do
    dataset_id
    |> DatasetRegistryServer.get_schema()
    |> Statement.build(messages)
    |> execute_statement()

    Logger.info("Persisting #{inspect(Enum.count(messages))} records for #{dataset_id}")

    :ok
  rescue
    e -> Logger.error("Error uploading data: #{inspect(e)}")
  end

  defp execute_statement(statement) do
    statement
    |> Prestige.execute()
    |> Prestige.prefetch()
  end
end
