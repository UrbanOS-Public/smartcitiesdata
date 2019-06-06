defmodule DiscoveryApi.Stats.StatsCalculator do
  @moduledoc """
  Provides an interface for calculating statistics for all datasets in the Smart City Registry
  """
  require Logger
  alias DiscoveryApi.Stats.Completeness
  alias DiscoveryApi.Stats.CompletenessTotals
  alias DiscoveryApi.Data.Persistence
  alias SmartCity.Dataset

  @doc """
  Entry point for calculating completeness statistics.  This method will get all datasets from the SmartCity Registry and calculate their completeness stats, saving them to redis.
  """
  def produce_completeness_stats do
    Persistence.persist("discovery-api:stats:start_time", DateTime.utc_now())

    Dataset.get_all!()
    |> Enum.filter(&calculate_completeness?/1)
    |> Enum.each(&calculate_and_save_completeness/1)

    Persistence.persist("discovery-api:stats:end_time", DateTime.utc_now())
  end

  defp calculate_and_save_completeness(%Dataset{} = dataset) do
    dataset
    |> calculate_completeness_for_dataset()
    |> add_completeness_total()
    |> save_completeness()
  rescue
    e ->
      Logger.warn("#{inspect(e)}")
      :ok
  end

  defp calculate_completeness?(%Dataset{} = dataset), do: not Dataset.is_remote?(dataset) and inserted_since_last_calculation?(dataset)

  defp inserted_since_last_calculation?(%Dataset{} = dataset) do
    keys = ["forklift:last_insert_date:#{dataset.id}", "discovery_api:completion_calculated_date:#{dataset.id}"]
    [last_insert_date, completion_calculated_date] = Persistence.get_many(keys)
    last_insert_date > completion_calculated_date
  end

  defp calculate_completeness_for_dataset(%Dataset{} = dataset) do
    dataset
    |> get_dataset()
    |> Enum.reduce(%{}, fn x, acc -> Completeness.calculate_stats_for_row(dataset, x, acc) end)
    |> Map.put(:id, dataset.id)
  rescue
    _ -> %{id: dataset.id}
  end

  defp get_dataset(%Dataset{} = dataset) do
    ("select * from " <> dataset.technical.systemName)
    |> Prestige.execute(rows_as_maps: true)
  end

  defp add_completeness_total(dataset_stats) do
    score = CompletenessTotals.calculate_dataset_total(dataset_stats)
    Map.put(dataset_stats, :completeness, score)
  end

  defp save_completeness(%{id: dataset_id, fields: fields} = dataset_stats) when not is_nil(fields) do
    Persistence.persist("discovery-api:stats:#{dataset_id}", dataset_stats)
    Persistence.persist("discovery-api:completeness_calculated_date:#{dataset_id}", DateTime.to_iso8601(DateTime.utc_now()))
    :ok
  end

  defp save_completeness(_dataset_stats), do: :ok
end
