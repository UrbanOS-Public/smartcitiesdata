defmodule Alchemist.Broadway do
  @moduledoc """
  Broadway implementation for Alchemist
  """
  @producer_module Application.get_env(
                     :alchemist,
                     :broadway_producer_module,
                     OffBroadway.Kafka.Producer
                   )
  use Broadway
  use Properties, otp_app: :alchemist

  import SmartCity.Event,
    only: [
      event_log_published: 0
    ]

  alias Broadway.Message

  require Logger

  @app_name "Alchemist"
  @instance_name Alchemist.instance_name()

  getter(:processor_stages, generic: true, default: 1)
  getter(:batch_stages, generic: true, default: 1)
  getter(:batch_size, generic: true, default: 1_000)
  getter(:batch_timeout, generic: true, default: 2_000)

  def start_link(opts) do
    Broadway.start_link(__MODULE__, broadway_config(opts))
  end

  defp broadway_config(opts) do
    output = Keyword.fetch!(opts, :output)
    ingestion = Keyword.fetch!(opts, :ingestion)
    input = Keyword.fetch!(opts, :input)
    transformations = Map.fetch!(ingestion, :transformations)

    [
      name: :"#{ingestion.id}_broadway",
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
        ingestion: ingestion,
        transformations: Transformers.construct(transformations),
        output_topics: Keyword.fetch!(output, :topics),
        producer: Keyword.fetch!(output, :connection)
      }
    ]
  end

  # used by processor.
  # This is where we alter the message to be transformed
  #   on it's way out of alchemist.
  def handle_message(_processor, %Message{data: message_data} = message, %{
        ingestion: ingestion,
        transformations: transformations
      }) do
    with {:ok, %{payload: payload} = smart_city_data} <- SmartCity.Data.new(message_data.value),
         {:ok, transformed_payload} <- Transformers.perform(transformations, payload),
         transformed_smart_city_data <- %{smart_city_data | payload: transformed_payload},
         {:ok, json_data} <- Jason.encode(transformed_smart_city_data) do
      Enum.each(ingestion.targetDatasets, fn dataset_id ->
        event_data = %SmartCity.EventLog{
          title: "Transformations Complete",
          timestamp: DateTime.utc_now() |> DateTime.to_string(),
          source: "Alchemist",
          description: "All transformations have been completed.",
          ingestion_id: ingestion.id,
          dataset_id: dataset_id
        }

        Brook.Event.send(@instance_name, event_log_published(), :alchemist, event_data)
      end)

      %{message | data: %{message.data | value: json_data}}
    else
      {:error, reason} ->
        Logger.error("Transformation error; INGESTION_ID: #{ingestion.id}; #{inspect(reason)}")

        DeadLetter.process(ingestion.targetDatasets, ingestion.id, message_data.value, @app_name,
          reason: inspect(reason)
        )

        Message.failed(message, reason)
    end
  end

  # used by batcher
  def handle_batch(_batch, messages, _batch_info, context) do
    data_messages = messages |> Enum.map(fn message -> message.data.value end)
    Enum.each(context.output_topics, fn topic -> Elsa.produce(context.producer, topic, data_messages, partition: 0) end)
    messages
  end
end
