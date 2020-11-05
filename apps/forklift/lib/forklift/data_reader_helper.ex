defmodule Forklift.DataReaderHelper do
  @moduledoc """
  Simple wrapper around the reader init and terminate behaviors
  """
  use Properties, otp_app: :forklift

  getter(:data_reader, generic: true)
  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:retry_count, generic: true)
  getter(:retry_initial_delay, generic: true)
  getter(:topic_subscriber_config, generic: true, default: [])

  def init(dataset) do
    dataset
    |> reader_args()
    |> data_reader().init()
  end

  def terminate(dataset) do
    dataset
    |> reader_args()
    |> data_reader().terminate()
  end

  defp reader_args(dataset) do
    [
      instance: Forklift.instance_name(),
      endpoints: elsa_brokers(),
      dataset: dataset,
      handler: Forklift.MessageHandler,
      input_topic_prefix: input_topic_prefix(),
      retry_count: retry_count(),
      retry_delay: retry_initial_delay(),
      topic_subscriber_config: topic_subscriber_config(),
      handler_init_args: [dataset: dataset]
    ]
  end
end
