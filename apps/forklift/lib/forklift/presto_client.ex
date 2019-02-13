defmodule Forklift.PrestoClient do
  alias Forklift.Statement

  def upload_data(dataset_id, messages) do
    RegistryStore.get_schema(dataset_id)
    |> Statement.build(messages)
    |> execute_statement()

    :ok
  rescue
    e -> IO.inspect(e, label: "Unhandled Presto Client error")
  end

  defp execute_statement(statement) do
    Prestige.execute(statement, catalog: "hive", schema: "default")
    |> Prestige.prefetch() |> IO.inspect(label: "prestige return")
  end
end
