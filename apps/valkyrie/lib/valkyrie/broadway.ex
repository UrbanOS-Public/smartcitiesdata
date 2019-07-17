defmodule Valkyrie.Broadway do
  @moduledoc """
  Broadway implementation for Valkyrie
  """
  @producer_module Application.get_env(:valkyrie, :broadway_producer_module, OffBroadway.Kafka.Producer)
  use Broadway

  alias Broadway.Message
  @app_name "Valkyrie"

  def start_link(opts) do
    Broadway.start_link(__MODULE__, broadway_config(opts))
  end

  defp broadway_config(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    producer = Keyword.fetch!(opts, :producer)

    [
      name: :"#{dataset.id}_broadway",
      producers: [
        default: [
          module: {@producer_module, opts},
          stages: 1
        ]
      ],
      processors: [
        default: [
          stages: processor_stages()
        ]
      ],
      batchers: [
        default: [
          stages: batch_stages(),
          batch_size: batch_size(),
          batch_timeout: batch_timeout()
        ]
      ],
      context: %{
        dataset: dataset,
        outgoing_topic: outgoing_topic(dataset.id),
        producer: producer
      }
    ]
  end

  def handle_message(_processor, %Message{data: data} = message, %{dataset: dataset}) do
    with {:ok, parsed_value} <- SmartCity.Data.new(data.value),
         {:ok, standardized_payload} <- standardize_data(dataset, parsed_value.payload) do
      %{message | data: %{message.data | value: update_payload(parsed_value, standardized_payload)}}
    else
      {:failed_schema_validation, reason} ->
        Yeet.process_dead_letter(dataset.id, data.value, @app_name, error: :failed_schema_validation, reason: reason)
        Message.failed(message, reason)

      {:error, reason} ->
        Yeet.process_dead_letter(dataset.id, data.value, @app_name, reason: reason)
        Message.failed(message, reason)
    end
  end

  def handle_batch(_batch, messages, _batch_info, context) do
    data_messages = messages |> Enum.map(fn message -> message.data.value end)
    Elsa.produce_sync(context.outgoing_topic, data_messages, partition: 0, name: context.producer)
    messages
  end

  defp standardize_data(dataset, payload) do
    case Valkyrie.standardize_data(dataset, payload) do
      {:ok, new_payload} -> {:ok, new_payload}
      {:error, reason} -> {:failed_schema_validation, reason}
    end
  end

  defp update_payload(smart_city_data, new_payload) do
    %{smart_city_data | payload: new_payload}
    |> Jason.encode!()
  end

  defp processor_stages(), do: Application.get_env(:valkyrie, :processor_stages, 1)
  defp batch_stages(), do: Application.get_env(:valkyrie, :batch_stages, 1)
  defp batch_size(), do: Application.get_env(:valkyrie, :batch_size, 1_000)
  defp batch_timeout(), do: Application.get_env(:valkyrie, :batch_timeout, 2_000)

  defp outgoing_topic_prefix(), do: Application.get_env(:valkyrie, :output_topic_prefix)
  defp outgoing_topic(dataset_id), do: "#{outgoing_topic_prefix()}-#{dataset_id}"
end
