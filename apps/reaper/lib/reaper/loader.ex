defmodule Reaper.Loader do
  @moduledoc false
  alias Kaffe.Producer
  alias SCOS.DataMessage

  def load(payloads, reaper_config) do
    payloads
    |> Enum.map(
      &send_to_kafka(
        &1,
        partition_key(
          &1,
          "Elixir.Reaper.Partitioners." <>
            ((reaper_config.partitioner.type == nil && "Hash") || reaper_config.partitioner.type) <> "Partitioner",
          reaper_config.partitioner.query
        ),
        reaper_config
      )
    )
  end

  defp send_to_kafka(payload, key, reaper_config) do
    message = convert_to_message(payload, reaper_config.dataset_id)
    {Producer.produce_sync(key, message), payload}
  end

  defp partition_key(payload, partitioner, query) do
    apply(String.to_existing_atom(partitioner), :partition, [payload, query])
  end

  defp convert_to_message(payload, dataset_id) do
    with {:ok, message} <-
           DataMessage.new(%{
             dataset_id: dataset_id,
             operational: %{timing: [%{app: "reaper", label: "sus", start_time: 5, end_time: 10}]},
             payload: payload,
             _metadata: %{}
           }),
         {:ok, value_part} <- DataMessage.encode(message) do
      value_part
    end
  end
end
