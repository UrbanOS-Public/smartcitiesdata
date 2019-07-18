defmodule Valkyrie.Broadway do
  @moduledoc """
  Broadway implementation for Valkyrie
  """
  @producer_module Application.get_env(:valkyrie, :broadway_producer_module, OffBroadway.Kafka.Producer)
  use Broadway

  alias Broadway.Message
  alias SmartCity.Data
  @app_name "Valkyrie"

  def start_link(opts) do
    Broadway.start_link(__MODULE__, broadway_config(opts))
  end

  defp broadway_config(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    producer = Keyword.fetch!(opts, :producer)
    output_topic = Keyword.fetch!(opts, :output_topic)

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
        output_topic: output_topic,
        producer: producer
      }
    ]
  end

  def handle_message(_processor, %Message{data: message_data} = message, %{dataset: dataset}) do
    start_time = Data.Timing.current_time()

    with {:ok, smart_city_data} <- SmartCity.Data.new(message_data.value),
         {:ok, standardized_payload} <- standardize_data(dataset, smart_city_data.payload),
         smart_city_data <- %{smart_city_data | payload: standardized_payload},
         smart_city_data <- Data.add_timing(smart_city_data, create_timing(start_time)),
         {:ok, json_data} <- Jason.encode(smart_city_data) do
      %{message | data: %{message.data | value: json_data}}
    else
      {:failed_schema_validation, reason} ->
        Yeet.process_dead_letter(dataset.id, message_data.value, @app_name,
          error: :failed_schema_validation,
          reason: reason
        )

        Message.failed(message, reason)

      {:error, reason} ->
        Yeet.process_dead_letter(dataset.id, message_data.value, @app_name, reason: reason)
        Message.failed(message, reason)
    end
  end

  def handle_batch(_batch, messages, _batch_info, context) do
    data_messages = messages |> Enum.map(fn message -> message.data.value end)
    Elsa.produce_sync(context.output_topic, data_messages, partition: 0, name: context.producer)
    messages
  end

  defp standardize_data(dataset, payload) do
    case Valkyrie.standardize_data(dataset, payload) do
      {:ok, new_payload} -> {:ok, new_payload}
      {:error, reason} -> {:failed_schema_validation, reason}
    end
  end

  defp create_timing(start_time) do
    Data.Timing.new("valkyrie", "timing", start_time, Data.Timing.current_time())
  end

  defp processor_stages(), do: Application.get_env(:valkyrie, :processor_stages, 1)
  defp batch_stages(), do: Application.get_env(:valkyrie, :batch_stages, 1)
  defp batch_size(), do: Application.get_env(:valkyrie, :batch_size, 1_000)
  defp batch_timeout(), do: Application.get_env(:valkyrie, :batch_timeout, 2_000)
end
