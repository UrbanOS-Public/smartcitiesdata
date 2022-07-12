defmodule Forklift.Jobs.DataMigration do
  @moduledoc """
  This job handles the insertion of data from the staging json table to the main orc-formatted table.

  No work will be performed if no data is present in the json table.
  This process assumes that a forklift-managed `os_partition` field is present on the table.
  """
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement
  require Logger
  import Forklift.Jobs.JobUtils

  # def run(dataset_ids) do
  #   dataset_ids
  #   |> Enum.map(&Forklift.Datasets.get!/1)
  #   |> Enum.map(&insert_data/1)
  # end
  def run() do
    Forklift.Datasets.get_all!()
    |> Enum.map(&insert_data/1)
  end

  defp insert_data(%{id: id, technical: %{systemName: system_name}} = dataset) do
    Forklift.DataReaderHelper.terminate(dataset)
    Logger.info("Beginning data migration for dataset #{id} (#{system_name})")
    json_table = json_table_name(system_name)

    with {:ok, original_count} <- PrestigeHelper.count(system_name),
         {:ok, json_count} <- PrestigeHelper.count(json_table),
         {:ok, _} <- refit_to_partitioned(system_name, original_count),
         {:ok, _} <- check_for_data_to_migrate(json_count),
         {:ok, _} <- insert_partitioned_data(json_table, system_name),
         {:ok, _} <-
           verify_count(system_name, original_count + json_count, "main table contains all records from the json table"),
         {:ok, _} <- truncate_table(json_table),
         {:ok, _} <- verify_count(json_table, 0, "json table is empty") do
      Logger.info("Successful data migration for dataset #{id}")
      update_migration_status(id, :ok)
      :ok
    else
      {:error, error} ->
        Logger.error("Error migrating records for dataset #{id}: " <> inspect(error))
        update_migration_status(id, :error)
        :error

      {:abort, reason} ->
        Logger.info("Aborted migration of dataset #{id}: " <> reason)
        :abort
    end
  after
    Forklift.DataReaderHelper.init(dataset)
  end

  defp refit_to_partitioned(table, original_count) do
    with false <- has_partition_field(table),
         {:ok, _} <- create_partitioned_table(table),
         {:ok, _} <- PrestigeHelper.drop_table(table),
         {:ok, _} <- rename_partitioned_table(table),
         {:ok, _} <- verify_count(table, original_count, "refit table retains all records") do
      Logger.info("Table #{table} successfully refit to be partitioned")
      {:ok, :refit}
    else
      true -> {:ok, :no_refit}
      error -> error
    end
  end

  defp has_partition_field(table) do
    case PrestigeHelper.execute_query("show create table #{table}") do
      {:ok, response} ->
        Prestige.Result.as_maps(response) |> List.first() |> Map.get("Create Table") |> String.contains?("os_partition")

      error ->
        error
    end
  end

  defp create_partitioned_table(table) do
    Logger.info("Table #{table} needs to be partitioned")

    "create table #{table}__partitioned with (partitioned_by = ARRAY['os_partition'], format = 'ORC') as (select *, cast('pre_partitioned' as varchar) as os_partition from #{
      table
    })"
    |> PrestigeHelper.execute_query()
  end

  defp rename_partitioned_table(table) do
    %{table: table <> "__partitioned", alteration: "rename to #{table}"}
    |> Statement.alter()
    |> PrestigeHelper.execute_query()
  end

  defp insert_partitioned_data(source, target) do
    "insert into #{target} select *, date_format(now(), '%Y_%m') as os_partition from #{source}"
    |> PrestigeHelper.execute_query()
  end

  defp truncate_table(table) do
    %{table: table}
    |> Statement.truncate()
    |> PrestigeHelper.execute_query()
  end

  defp json_table_name(system_name), do: system_name <> "__json"

  defp update_migration_status(dataset_id, :error) do
    TelemetryEvent.add_event_metrics([dataset_id: dataset_id], [:forklift_migration_failure], value: %{status: 1})
  end

  defp update_migration_status(dataset_id, :ok) do
    TelemetryEvent.add_event_metrics([dataset_id: dataset_id], [:forklift_migration_failure], value: %{status: 0})
  end

  defp check_for_data_to_migrate(0), do: {:abort, "No data found to migrate"}
  defp check_for_data_to_migrate(_count), do: {:ok, :data_found}
end
