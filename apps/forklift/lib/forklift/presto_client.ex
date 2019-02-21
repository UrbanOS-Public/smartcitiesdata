defmodule Forklift.PrestoClient do
  @moduledoc false
  require Logger
  alias Forklift.{DatasetRegistryServer, Statement}
  @user Application.get_env(:forklift, :user)

  def upload_data(dataset_id, messages) do
    dataset_id
    |> DatasetRegistryServer.get_schema()
    |> Statement.build(messages)
    |> execute_statement()

    :ok
  rescue
    e -> Logger.error("Error uploading data")
  end

  defp execute_statement(statement) do
    statement
    |> Prestige.execute(catalog: "hive", schema: "default", user: @user)
    |> Prestige.prefetch()
  end
end
