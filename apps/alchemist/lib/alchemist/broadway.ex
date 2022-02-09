defmodule Alchemist.Broadway do
  @moduledoc """
  Broadway implementation for Alchemist
  """
  @producer_module Application.get_env(:alchemist, :broadway_producer_module, OffBroadway.Kafka.Producer)
  use Broadway
  use Properties, otp_app: :alchemist

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

  # used by processor
  def handle_message(_processor, message, _dataset) do
    message
  end

  # used by batcher
  def handle_batch(_batch, messages, _batch_info, context) do
    data_messages = messages |> Enum.map(fn message -> message.data.value end)
    Elsa.produce(context.producer, context.output_topic, data_messages, partition: 0)
    messages
  end
end
