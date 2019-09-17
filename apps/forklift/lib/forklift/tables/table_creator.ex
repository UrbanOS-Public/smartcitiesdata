defmodule Forklift.Tables.TableCreator do
  @moduledoc """
  Executes a CREATE TABLE statement against PrestoDB based on a dataset definition's schema.
  """

  require Logger
  alias SmartCity.Dataset
  alias Forklift.Tables.StatementBuilder

  def create_table(%Dataset{id: dataset_id, technical: %{systemName: table_name, schema: schema}}) do
    with {:ok, statement} <- StatementBuilder.build_table_create_statement(table_name, schema),
         :ok <- execute(statement) do
      Logger.info("Created table for #{dataset_id}")
      :ok
    else
      {:error, reason} = error ->
        Logger.error("Error processing dataset #{dataset_id}: #{reason}")
        error
    end
  end

  defp execute(statement) do
    statement
    |> Prestige.execute()
    |> Prestige.prefetch()
    |> validate_result()
  end

  defp validate_result(result) do
    case result do
      [[true]] -> :ok
      _ -> {:error, "Write to Presto failed"}
    end
  end
end
