defmodule Pipeline.Reader.DatasetTopicReader do
  @moduledoc """
  Implementation of `Pipeline.Reader` for dataset Kafka topics.
  """

  alias Pipeline.Reader.TopicReader
  @behaviour Pipeline.Reader

  @type init_args() :: [
          instance: atom(),
          dataset: SmartCity.Dataset.t(),
          endpoints: Elsa.endpoints(),
          input_topic_prefix: String.t(),
          handler: module()
        ]

  @type term_args() :: [
          instance: atom(),
          dataset: SmartCity.Dataset.t(),
          input_topic_prefix: String.t()
        ]

  @impl Pipeline.Reader
  @spec init(init_args()) :: :ok | {:error, term()}
  @doc """
  Sets up infrastructure to consume messages off a dataset Kafka topic. Includes creating the
  topic if necessary.

  Optional arguments:
  * `handler_init_args` - Initial state passed to handler. Defaults to `[]`.
  * `topic_subscriber_config` - Subscriber configuration passed to underlying libraries. Defaults to `[]`
  * `retry_count` - Times to retry topic creation. Defaults to 10
  * `retry_delay` - Milliseconds to initially wait before retrying. Defaults to 100
  """
  def init(args) do
    parse_init_args(args)
    |> TopicReader.init()
  end

  @impl Pipeline.Reader
  @spec terminate(term_args()) :: :ok | {:error, term()}
  @doc """
  Destroys topic consumer infrastructure.
  """
  def terminate(args) do
    with instance <- Keyword.fetch!(args, :instance),
         dataset <- Keyword.fetch!(args, :dataset),
         topic <- "#{Keyword.fetch!(args, :input_topic_prefix)}-#{dataset.id}" do
      TopicReader.terminate(instance: instance, topic: topic)
    end
  end

  defp parse_init_args(args) do
    instance = Keyword.fetch!(args, :instance)
    dataset = Keyword.fetch!(args, :dataset)
    topic = "#{Keyword.fetch!(args, :input_topic_prefix)}-#{dataset.id}"

    [
      instance: instance,
      connection: :"#{instance}-#{topic}-#{dataset.id}-consumer",
      endpoints: Keyword.fetch!(args, :endpoints),
      topic: topic,
      handler: Keyword.fetch!(args, :handler),
      handler_init_args: Keyword.get(args, :handler_init_args, []),
      topic_subscriber_config: Keyword.get(args, :topic_subscriber_config, []),
      retry_count: Keyword.get(args, :retry_count, 10),
      retry_delay: Keyword.get(args, :retry_delay, 100)
    ]
  end
end
