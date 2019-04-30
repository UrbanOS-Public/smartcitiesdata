defmodule Reaper.Loader do
  @moduledoc false
  alias Kaffe.Producer
  alias SmartCity.Data

  def load(payload, reaper_config, start_time) do
    partitioner_module = determine_partitioner_module(reaper_config)
    key = partitioner_module.partition(payload, reaper_config.partitioner.query)

    send_to_kafka(payload, key, reaper_config, start_time)
  end

  defp send_to_kafka(payload, key, reaper_config, start_time) do
    message = convert_to_message(payload, reaper_config.dataset_id, start_time)

    {Producer.produce_sync(key, message), payload}
  end

  defp determine_partitioner_module(reaper_config) do
    type = reaper_config.partitioner.type || "Hash"

    "Elixir.Reaper.Partitioners.#{type}Partitioner"
    |> String.to_existing_atom()
  end

  defp convert_to_message(payload, dataset_id, start) do
    start = format_date(start)
    stop = format_date(DateTime.utc_now())
    timing = %{app: "reaper", label: "Ingested", start_time: start, end_time: stop}

    data = %{
      dataset_id: dataset_id,
      operational: %{timing: [timing]},
      payload: payload,
      _metadata: %{}
    }

    with {:ok, message} <- Data.new(data),
         {:ok, value_part} <- Jason.encode(message) do
      value_part
    else
      error -> Yeet.process_dead_letter(dataset_id, payload, "Reaper", exit_code: error)
    end
  end

  defp format_date(some_date) do
    DateTime.to_iso8601(some_date)
  end
end
