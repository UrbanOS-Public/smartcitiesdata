defmodule DiscoveryApi.Stats.StatsCalculator do
  @moduledoc """
  Provides an interface for calculating statistics for all datasets in the Smart City Registry
  """
  require Logger
  alias DiscoveryApi.Stats.Completeness
  alias DiscoveryApi.Stats.CompletenessTotals
  alias DiscoveryApi.Data.Persistence
  alias DiscoveryApi.Data.Model

  @completeness_key "discovery-api:completeness_calculated_date"
  @stats_key "discovery-api:stats"

  @doc """
  Entry point for calculating completeness statistics.  This method will get all datasets from the SmartCity Registry and calculate their completeness stats, saving them to redis.
  """
  def produce_completeness_stats do
    Persistence.persist("#{@stats_key}:start_time", DateTime.utc_now())

    Model.get_all()
    |> Enum.filter(&calculate_completeness?/1)
    |> Enum.each(&calculate_and_save_completeness/1)

    Persistence.persist("#{@stats_key}:end_time", DateTime.utc_now())
  end

  def delete_completeness(id) do
    Persistence.delete("#{@stats_key}:#{id}")
    Persistence.delete("#{@completeness_key}:#{id}")
  end

  defp calculate_and_save_completeness(%Model{} = model) do
    model
    |> calculate_completeness_for_dataset()
    |> add_total_score()
    |> save_completeness()
  rescue
    e ->
      Logger.warn("#{inspect(e)}")
      :ok
  end

  defp calculate_completeness?(%Model{} = model), do: not Model.remote?(model) and inserted_since_last_calculation?(model)

  defp inserted_since_last_calculation?(%Model{} = model) do
    last_insert_date = Persistence.get("forklift:last_insert_date:#{model.id}")
    completion_calculated_date = Persistence.get("#{@completeness_key}:#{model.id}")
    last_insert_date > completion_calculated_date
  end

  defp calculate_completeness_for_dataset(%Model{} = model) do
    model
    |> get_dataset()
    |> Enum.reduce(%{}, fn x, acc -> Completeness.calculate_stats_for_row(model, x, acc) end)
    |> Map.put(:id, model.id)
  rescue
    _ -> %{id: model.id}
  end

  defp get_dataset(%Model{} = model) do
    get_statement = "select * from " <> model.systemName

    DiscoveryApi.prestige_opts()
    |> Prestige.new_session()
    |> Prestige.query!(get_statement)
    |> Prestige.Result.as_maps()
  end

  defp add_total_score(dataset_stats) do
    score = CompletenessTotals.calculate_dataset_total(dataset_stats)
    Map.put(dataset_stats, :total_score, score)
  end

  defp save_completeness(%{id: dataset_id, fields: fields} = dataset_stats) when not is_nil(fields) do
    Persistence.persist("#{@stats_key}:#{dataset_id}", dataset_stats)
    Persistence.persist("#{@completeness_key}:#{dataset_id}", DateTime.to_iso8601(DateTime.utc_now()))
    :ok
  end

  defp save_completeness(_dataset_stats), do: :ok
end
