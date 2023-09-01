defmodule Valkyrie.Broadway do
  @moduledoc """
  Broadway implementation for Valkyrie
  """
  @producer_module Application.get_env(
                     :valkyrie,
                     :broadway_producer_module,
                     OffBroadway.Kafka.Producer
                   )
  use Broadway
  use Properties, otp_app: :valkyrie

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [event_log_published: 0]

  alias Broadway.Message
  alias SmartCity.Data
  require Logger

  @instance_name Valkyrie.instance_name()
  @app_name "Valkyrie"

  getter(:profiling_enabled, generic: true)
  getter(:processor_stages, generic: true, default: 1)
  getter(:batch_stages, generic: true, default: 1)
  getter(:batch_size, generic: true, default: 1_000)
  getter(:batch_timeout, generic: true, default: 2_000)

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

  def handle_message(_processor, %Message{data: message_data} = message, %{dataset: dataset}) do
    start_time = Data.Timing.current_time()

    with {:ok, %{payload: payload} = smart_city_data} when payload != end_of_data() <-
           SmartCity.Data.new(message_data.value),
         {:ok, standardized_payload} <- standardize_data(dataset, smart_city_data.payload),
         smart_city_data <- %{smart_city_data | payload: standardized_payload},
         smart_city_data <- add_timing(smart_city_data, start_time),
         {:ok, json_data} <- Jason.encode(smart_city_data) do
      %{message | data: %{message.data | value: json_data}}
    else
      {:ok, %{payload: end_of_data()} = smart_city_data} ->
        decoded_message_data = Jason.decode!(message_data.value)
        ingestion_id = decoded_message_data["ingestion_id"]
        target_datasets = decoded_message_data["dataset_ids"]

        Enum.each(target_datasets, fn dataset_id ->
          event_data = create_event_log(dataset_id, ingestion_id)
          Brook.Event.send(@instance_name, event_log_published(), :valkyrie, event_data)
        end)

        %{message | data: %{message.data | value: Jason.encode!(smart_city_data)}}

      {:failed_schema_validation, reason} ->
        decoded_message_data = Jason.decode!(message_data.value)
        ingestion_id = decoded_message_data["ingestion_id"]
        payload = decoded_message_data["payload"]

        DeadLetter.process(
          [dataset.id],
          ingestion_id,
          message_data.value,
          @app_name,
          error: :failed_schema_validation,
          reason: inspect(reason)
        )

        Logger.error(
          "ingestion_id: #{ingestion_id}; payload: #{inspect(payload)}; Failed Schema Validation: #{inspect(reason)}"
        )

        Message.failed(message, reason)

      {:error, reason} ->
        decoded_message_data = Jason.decode!(message_data.value)
        ingestion_id = decoded_message_data["ingestion_id"]
        payload = decoded_message_data["payload"]

        DeadLetter.process([dataset.id], ingestion_id, message_data.value, @app_name, reason: inspect(reason))

        Logger.error(
          "ingestion_id: #{ingestion_id}; payload: #{inspect(payload)}; Unknown Valkyrie Error: #{inspect(reason)}"
        )

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
    case profiling_enabled() do
      true -> Data.add_timing(smart_city_data, create_timing(start_time))
      _ -> smart_city_data
    end
  end

  defp create_timing(start_time) do
    Data.Timing.new("valkyrie", "timing", start_time, Data.Timing.current_time())
  end

  defp create_event_log(dataset_id, ingestion_id) do
    %SmartCity.EventLog{
      title: "Validations Complete",
      timestamp: DateTime.utc_now() |> DateTime.to_string(),
      source: "Valkyrie",
      description: "Validations have been completed.",
      ingestion_id: ingestion_id,
      dataset_id: dataset_id
    }
  end
end
