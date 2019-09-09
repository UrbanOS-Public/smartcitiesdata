defmodule Forklift.Tables.TableCreator do
  @moduledoc """
  Executes a CREATE TABLE statement against PrestoDB based on a dataset definition's schema.
  """

  require Logger
  alias SmartCity.Dataset
  alias Forklift.Tables.StatementBuilder

  def create_table(%Dataset{id: dataset_id, technical: %{systemName: table_name, schema: schema}}) do
    with {:ok, statement} <- StatementBuilder.build_table_create_statement(table_name, schema) do
      result = execute(statement)

      log(result, dataset_id)

      result
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

  defp log(result, dataset_id) do
    case result do
      {:error, error} -> Logger.error("Error processing dataset #{dataset_id}: #{error}")
      _ -> Logger.info("Created table for #{dataset_id}")
    end
  end
end
