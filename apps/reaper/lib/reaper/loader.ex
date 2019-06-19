defmodule Reaper.Loader do
  @moduledoc """
  This module loads data to the output topic
  """
  alias Elsa.Producer
  alias SmartCity.Data
  alias Reaper.ReaperConfig

  use Retry
  @initial_delay Application.get_env(:reaper, :produce_timeout)
  @retries Application.get_env(:reaper, :produce_retries)

  @doc """
  Loads a data row to the output topic
  """
  @spec load(map(), ReaperConfig.t(), String.t()) :: :ok | {:error, String.t()}
  def load(payload, reaper_config, start_time) do
    partitioner_module = determine_partitioner_module(reaper_config)
    key = partitioner_module.partition(payload, reaper_config.partitioner.query)
    send_to_kafka(payload, key, reaper_config, start_time)
  end

  defp send_to_kafka(payload, key, reaper_config, start_time) do
    payload
    |> convert_to_message(reaper_config.dataset_id, start_time)
    |> produce(reaper_config.dataset_id, key)
  end

  defp produce({:ok, message}, dataset_id, key) do
    topic = "#{topic_prefix()}-#{dataset_id}"

    retry with: produce_backoff(), atoms: [false] do
      Elsa.topic?(endpoints(), topic)
    after
      true -> Producer.produce_sync(endpoints(), topic, 0, key, message)
    else
      _ -> {:error, "topic #{topic} unavailable to produce to"}
    end
  end

  defp produce({:error, _} = error, _dataset_id, _key), do: error

  defp produce_backoff() do
    @initial_delay |> exponential_backoff() |> Stream.take(@retries)
  end

  defp determine_partitioner_module(reaper_config) do
    type = reaper_config.partitioner.type || "Hash"

    "Elixir.Reaper.Partitioners.#{type}Partitioner"
    |> String.to_existing_atom()
  end

  defp endpoints(), do: Application.get_env(:reaper, :elsa_brokers)

  defp topic_prefix(), do: Application.get_env(:reaper, :output_topic_prefix)

  defp convert_to_message(payload, dataset_id, start) do
    payload
    |> create_data_struct(dataset_id, start)
    |> encode()
  end

  defp create_data_struct(payload, dataset_id, start) do
    start = format_date(start)
    stop = format_date(DateTime.utc_now())
    timing = %{app: "reaper", label: "Ingested", start_time: start, end_time: stop}

    data = %{
      dataset_id: dataset_id,
      operational: %{timing: [timing]},
      payload: payload,
      _metadata: %{}
    }

    case Data.new(data) do
      {:error, reason} -> {:error, {:smart_city_data, reason}}
      result -> result
    end
  end

  defp encode({:ok, data}) do
    case Jason.encode(data) do
      {:error, reason} -> {:error, {:json, reason}}
      result -> result
    end
  end

  defp encode({:error, _} = error), do: error

  defp format_date(some_date) do
    DateTime.to_iso8601(some_date)
  end
end
