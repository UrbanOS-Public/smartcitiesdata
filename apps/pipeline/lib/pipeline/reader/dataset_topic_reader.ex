defmodule Pipeline.Reader.DatasetTopicReader do
  @moduledoc """
  Implementation of `Pipeline.Reader` for dataset Kafka topics.
  """

  @behaviour Pipeline.Reader

  # Allow the topic_reader module to be configured for testing
  @topic_reader Application.compile_env(:pipeline, :topic_reader, Pipeline.Reader.TopicReader)

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
  Sets up infrastructure to consume messages off a Kafka topic. Creates the
  topic if necessary.
  """
  def init(args) do
    parse_init_args(args)
    |> @topic_reader.init()
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
      @topic_reader.terminate(instance: instance, topic: topic)
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
