defmodule Pipeline.Reader.DatasetTopicReader.InitTask do
  @moduledoc false

  use Task, restart: :transient
  use Retry

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(args) do
    config = parse_config(args)
    consumer_spec = consumer(config)

    Elsa.create_topic(config.endpoints, config.topic)
    wait_for_topic!(config)

    case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, consumer_spec) do
      {:ok, pid} -> Registry.put_meta(Pipeline.Registry, connection(config), pid)
      {:error, {:already_started, _}} -> :ok
      {:error, {_, {_, _, {:already_started, _}}}} -> :ok
      error -> raise "Failed to supervise #{config.topic} consumer: #{inspect(error)}"
    end
  end

  defp parse_config(args) do
    prefix = Keyword.fetch!(args, :input_topic_prefix)
    dataset = Keyword.fetch!(args, :dataset)

    %{
      instance: Keyword.fetch!(args, :instance),
      endpoints: Keyword.fetch!(args, :brokers),
      dataset: dataset,
      handler: Keyword.fetch!(args, :handler),
      topic: "#{prefix}-#{dataset.id}",
      retry_count: Keyword.get(args, :retry_count, 10),
      retry_delay: Keyword.get(args, :retry_delay, 100),
      topic_subscriber_config: Keyword.get(args, :topic_subscriber_config, [])
    }
  end

  defp consumer(config) do
    start_options = [
      endpoints: config.endpoints,
      connection: connection(config),
      group_consumer: [
        group: "#{config.instance}-#{config.topic}",
        topics: [config.topic],
        handler: config.handler,
        handler_init_args: [dataset: config.dataset],
        config: config.topic_subscriber_config
      ]
    ]

    {Elsa.Supervisor, start_options}
  end

  defp wait_for_topic!(config) do
    retry with: config.retry_delay |> exponential_backoff() |> Stream.take(config.retry_count), atoms: [false] do
      Elsa.topic?(config.endpoints, config.topic)
    after
      true -> config.topic
    else
      _ -> raise "Timed out waiting for #{config.topic} to be available"
    end
  end

  defp connection(config) do
    :"#{config.instance}-#{config.topic}-consumer"
  end
end
