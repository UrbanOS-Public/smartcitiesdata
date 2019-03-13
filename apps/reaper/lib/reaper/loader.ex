defmodule Reaper.Loader do
  @moduledoc false
  alias Kaffe.Producer
  alias Reaper.Partitioners.JsonPartitioner
  alias SCOS.DataMessage

  def load(payloads, reaper_config) do
    payloads
    |> Enum.map(
      &send_to_kafka(
        &1,
        reaper_config.dataset_id,
        "Elixir.Reaper.Partitioners." <>
          ((reaper_config.partitioner.type == nil && "Hash") || reaper_config.partitioner.type) <>
          "Partitioner",
        reaper_config.partitioner.query
      )
    )
  end

  defp send_to_kafka(payload, dataset_id, dataset_partitioner, dataset_partitioner_location) do
    {key, message} = convert_to_message(payload, dataset_id, dataset_partitioner, dataset_partitioner_location)
    {Producer.produce_sync(key, message), payload}
  end

  defp convert_to_message(payload, dataset_id, dataset_partitioner, dataset_partitioner_location) do
    value_part =
      %{
        dataset_id: dataset_id,
        payload: payload,
        _metadata: %{},
        operational: %{timing: [%{app: "reaper", label: "sus", start_time: 5, end_time: 10}]}
      }
      |> DataMessage.new()

    # value_part --> calc_key(msg) --> key
    # Extract from registry schema what partitioner to use for computing the key value from the data
    # If dataset_paritioner is nil, then set key_part nil which means round-robin
    if dataset_partitioner == nil do
      {Reaper.Partitioners.HashPartitioner.partition(payload, nil), value_part}
    else
      {apply(String.to_existing_atom(dataset_partitioner), :partition, [payload, dataset_partitioner_location]),
       value_part}
    end
  end
end
