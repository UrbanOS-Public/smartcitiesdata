defmodule Alchemist.Broadway do
  @moduledoc """
  Broadway implementation for Alchemist
  """
  @producer_module Application.get_env(:alchemist, :broadway_producer_module, OffBroadway.Kafka.Producer)
  use Broadway
  use Properties, otp_app: :alchemist

  alias Broadway.Message

  @app_name "Alchemist"

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
        output_topic: Keyword.fetch!(output, :topic),
        producer: Keyword.fetch!(output, :connection)
      }
    ]
  end

  # used by processor.
  # This is where we alter the message to be transformed
  #   on it's way out of alchemist.
  def handle_message(_processor, %Message{data: message_data} = message, %{ingestion: ingestion}) do
    with {:ok, %{payload: payload} = smart_city_data} <- SmartCity.Data.new(message_data.value),
         transformed_payload <- Transformers.NoOp.transform(payload, {}),
         transformed_smart_city_data <- %{smart_city_data | payload: transformed_payload},
         {:ok, json_data} <- Jason.encode(transformed_smart_city_data) do
      %{message | data: %{message.data | value: json_data}}
    else
      {:error, reason} ->
        DeadLetter.process(ingestion.targetDataset, message_data.value, @app_name, reason: reason)
        Message.failed(message, reason)
    end
  end

  # used by batcher
  def handle_batch(_batch, messages, _batch_info, context) do
    data_messages = messages |> Enum.map(fn message -> message.data.value end)
    Elsa.produce(context.producer, context.output_topic, data_messages, partition: 0)
    messages
  end
end
