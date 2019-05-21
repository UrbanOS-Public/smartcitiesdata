defmodule DiscoveryApi.Stats.StatsCalculator do
  @moduledoc """
  Provides an interface for calculating statistics for all datasets in the Smart City Registry
  """
  alias DiscoveryApi.Stats.Completeness
  alias DiscoveryApi.Stats.CompletenessTotals

  @doc """
  Entry point for calculating completeness statistics.  This method will get all datasets from the SmartCity Registry and calculate their completeness stats, saving them to redis.
  """
  def produce_completeness_stats do
    DiscoveryApi.Data.Persistence.persist("discovery-api:stats:start_time", DateTime.utc_now())

    SmartCity.Dataset.get_all!()
    |> Enum.filter(fn dataset -> dataset.technical.sourceType != "remote" end)
    |> Enum.map(fn dataset -> calculate_completeness_for_dataset(dataset) end)
    |> Enum.map(&add_completeness_total/1)
    |> Enum.each(&save_completeness/1)

    DiscoveryApi.Data.Persistence.persist("discovery-api:stats:end_time", DateTime.utc_now())
  end

  defp calculate_completeness_for_dataset(dataset) do
    dataset
    |> get_dataset()
    |> Enum.reduce(%{}, fn x, acc -> Completeness.calculate_stats_for_row(dataset, x, acc) end)
    |> Map.put(:id, dataset.id)
  end

  defp add_completeness_total(dataset_stats) do
    score = CompletenessTotals.calculate_dataset_total(dataset_stats)
    Map.put(dataset_stats, :completeness, score)
  end

  defp get_dataset(dataset) do
    try do
      ("select * from " <> dataset.technical.systemName)
      |> Prestige.execute(rows_as_maps: true)
    rescue
      _ -> []
    end
  end

  defp save_completeness(%{id: dataset_id} = dataset_stats) do
    if Map.get(dataset_stats, :fields, nil) != nil do
      DiscoveryApi.Data.Persistence.persist("discovery-api:stats:#{dataset_id}", dataset_stats)
    end
  end
end
