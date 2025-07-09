defmodule Pipeline.Reader.TopicReader do
  @moduledoc """
  Implementation of `Pipeline.Reader` for Kafka topics.
  """

  use Retry
  @behaviour Pipeline.Reader
  @behaviour Pipeline.Reader.TopicReader.Behaviour

  @type init_args() :: [
          instance: atom(),
          connection: atom(),
          endpoints: Elsa.endpoints(),
          topic: String.t(),
          handler: module()
        ]

  @impl Pipeline.Reader
  @spec init(init_args()) :: :ok | {:error, term()}
  @doc """
  Sets up infrastructure to consume messages off a Kafka topic. Ensures the topic is created.

  Optional arguments:
  * `handler_init_args` - Initial state passed to handler. Defaults to `[]`.
  * `topic_subscriber_config` - Subscriber configuration passed to Elsa. Defaults to `[]`.
  * `retry_count` - Times to retry topic creation. Defaults to 10.
  * `retry_delay` - Milliseconds to initially wait before retry. Defaults to 100.
  """
  def init(args) do
    with name <- parse_name(args),
         config <- parse_args(args),
         consumer <- consumer_spec(name, config),
         :ok <- create_topic(config) do
      case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, consumer) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
        error -> {:error, error}
      end
    end
  end

  @impl Pipeline.Reader
  @spec terminate(instance: atom(), topic: String.t()) :: :ok | {:error, term()}
  @doc """
  Destroys topic consumer infrastructure.
  """
  def terminate(args) do
    with name <- parse_name(args),
         [{pid, _}] <- Registry.lookup(Pipeline.Registry, name),
         :ok <- DynamicSupervisor.terminate_child(Pipeline.DynamicSupervisor, pid) do
      Registry.unregister(Pipeline.Registry, name)
    else
      lookup when is_list(lookup) ->
        {:error, "Cannot find pid to terminate: #{inspect(lookup)}"}

      error ->
        {:error, error}
    end
  end

  defp parse_args(args) do
    %{
      instance: Keyword.fetch!(args, :instance),
      connection: Keyword.fetch!(args, :connection),
      endpoints: Keyword.fetch!(args, :endpoints),
      topic: Keyword.fetch!(args, :topic),
      handler: Keyword.fetch!(args, :handler),
      handler_init_args: Keyword.get(args, :handler_init_args, []),
      topic_subscriber_config: Keyword.get(args, :topic_subscriber_config, []),
      retry_count: Keyword.get(args, :retry_count, 10),
      retry_delay: Keyword.get(args, :retry_delay, 100)
    }
  end

  defp parse_name(args) do
    instance = Keyword.fetch!(args, :instance)
    topic = Keyword.fetch!(args, :topic)

    :"#{instance}-#{topic}-pipeline-supervisor"
  end

  defp create_topic(config) do
    Elsa.create_topic(config.endpoints, config.topic)
    wait_for_topic(config)
  end

  defp wait_for_topic(config) do
    wait exponential_backoff(config.retry_delay) |> Stream.take(config.retry_count) do
      Elsa.topic?(config.endpoints, config.topic)
    after
      _ -> :ok
    else
      _ -> {:error, "Timed out waiting for #{config.topic} to be available"}
    end
  end

  defp consumer_spec(name, config) do
    start_options = [
      name: via(name),
      endpoints: config.endpoints,
      connection: config.connection,
      group_consumer: [
        group: "#{config.instance}-#{config.topic}",
        topics: [config.topic],
        handler: config.handler,
        handler_init_args: config.handler_init_args,
        config: config.topic_subscriber_config,
        direct_ack: true
      ]
    ]

    {Elsa.Supervisor, start_options}
  end

  defp via(name) do
    {:via, Registry, {Pipeline.Registry, name}}
  end
end
