defmodule Valkyrie.Broadway do
  @moduledoc """
  Broadway implementation for Valkyrie
  """
  @producer_module Application.get_env(:valkyrie, :broadway_producer_module, OffBroadway.Kafka.Producer)
  use Broadway

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_standardization_end: 0]

  alias Broadway.Message
  alias SmartCity.Data
  @app_name "Valkyrie"
  @instance Valkyrie.Application.instance()

  def start_link(opts) do
    Broadway.start_link(__MODULE__, broadway_config(opts))
  end

  defp broadway_config(opts) do
    output = Keyword.fetch!(opts, :output)
    dataset = Keyword.fetch!(opts, :dataset)
    input = Keyword.fetch!(opts, :input)

    [
      name: :"#{dataset.id}_broadway",
      producer: [
          module: {@producer_module, input},
          concurrency: 1
      ],
      processors: [
        default: [
          concurrency: processor_stages()
        ]
      ],
      batchers: [
        default: [
          concurrency: batch_stages(),
          batch_size: batch_size(),
          batch_timeout: batch_timeout()
        ]
      ],
      context: %{
        dataset: dataset,
        output_topic: Keyword.fetch!(output, :topic),
        producer: Keyword.fetch!(output, :connection)
      }
    ]
  end

  def handle_message(_processor, %Message{data: %{value: end_of_data()}} = message, %{dataset: dataset}) do
    Brook.Event.send(@instance, data_standardization_end(), :valkyrie, %{"dataset_id" => dataset.id})
    message
  end

  def handle_message(_processor, %Message{data: message_data} = message, %{dataset: dataset}) do
    start_time = Data.Timing.current_time()

    with {:ok, smart_city_data} <- SmartCity.Data.new(message_data.value),
         {:ok, standardized_payload} <- standardize_data(dataset, smart_city_data.payload),
         smart_city_data <- %{smart_city_data | payload: standardized_payload},
         smart_city_data <- add_timing(smart_city_data, start_time),
         {:ok, json_data} <- Jason.encode(smart_city_data) do
      %{message | data: %{message.data | value: json_data}}
    else
      {:failed_schema_validation, reason} ->
        DeadLetter.process(dataset.id, message_data.value, @app_name,
          error: :failed_schema_validation,
          reason: reason
        )

        Message.failed(message, reason)

      {:error, reason} ->
        DeadLetter.process(dataset.id, message_data.value, @app_name, reason: reason)
        Message.failed(message, reason)
    end
  end

  def handle_batch(_batch, messages, _batch_info, context) do
    data_messages = messages |> Enum.map(fn message -> message.data.value end)
    Elsa.produce(context.producer, context.output_topic, data_messages, partition: 0)
    messages
  end

  defp standardize_data(dataset, payload) do
    case Valkyrie.standardize_data(dataset, payload) do
      {:ok, new_payload} -> {:ok, new_payload}
      {:error, reason} -> {:failed_schema_validation, reason}
    end
  end

  defp add_timing(smart_city_data, start_time) do
    case Application.get_env(:valkyrie, :profiling_enabled) do
      true -> Data.add_timing(smart_city_data, create_timing(start_time))
      _ -> smart_city_data
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
