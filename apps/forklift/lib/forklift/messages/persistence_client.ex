defmodule Forklift.Messages.PersistenceClient do
  @moduledoc """
  Client for persisting a dataset's messages to presto
  """
  require Logger
  alias Forklift.Datasets.DatasetRegistryServer
  alias Forklift.Messages.Statement
  alias SmartCity.Data

  @redis Forklift.Application.redis_client()

  @doc """
  Uploading no data does nothing
  """
  def upload_data(_dataset_id, []) do
    Logger.debug("No records to persist!")
    :ok
  end

  @doc """
  Uploads data for a dataset and returns the time taken for the upload.
  """
  def upload_data(dataset_id, messages) do
    start_time = Data.Timing.current_time()

    dataset_id
    |> DatasetRegistryServer.get_schema()
    |> Statement.build(messages)
    |> execute_statement()
    |> validate_result()

    end_time = Data.Timing.current_time()
    Redix.command(@redis, ["SET", "forklift:last_insert_date:" <> dataset_id, DateTime.to_iso8601(DateTime.utc_now())])

    Logger.debug("Persisting #{inspect(Enum.count(messages))} records for #{dataset_id}")

    {:ok, SmartCity.Data.Timing.new(:forklift, "presto_insert_time", start_time, end_time)}
  rescue
    e ->
      Logger.error("Error uploading data: #{inspect(e)}")
      {:error, e}
  end

  defp execute_statement(statement) do
    statement
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

  defp validate_result(result) do
    case result do
      [[_]] ->
        :ok

      error ->
        Logger.error(inspect(error))
        {:error, "Write to Presto failed"}
        raise "Presto write failed"
    end
  end
end
