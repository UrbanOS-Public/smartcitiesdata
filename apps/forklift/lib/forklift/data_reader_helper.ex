defmodule Forklift.DataReaderHelper do
  @moduledoc """
  Simple wrapper around the reader init and terminate behaviors
  """
  @reader Application.get_env(:forklift, :data_reader)

  def init(dataset) do
    dataset
    |> reader_args()
    |> @reader.init()
  end

  def terminate(dataset) do
    dataset
    |> reader_args()
    |> @reader.terminate()
  end

  defp reader_args(dataset) do
    [
      instance: Forklift.instance_name(),
      endpoints: Application.get_env(:forklift, :elsa_brokers),
      dataset: dataset,
      handler: Forklift.MessageHandler,
      input_topic_prefix: Application.get_env(:forklift, :input_topic_prefix),
      retry_count: Application.get_env(:forklift, :retry_count),
      retry_delay: Application.get_env(:forklift, :retry_initial_delay),
      topic_subscriber_config: Application.get_env(:forklift, :topic_subscriber_config, []),
      handler_init_args: [dataset: dataset]
    ]
  end
end
