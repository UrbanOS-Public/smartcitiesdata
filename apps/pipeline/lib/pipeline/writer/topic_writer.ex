defmodule Pipeline.Writer.TopicWriter do
  @moduledoc "TODO"

  @behaviour Pipeline.Writer
  alias Pipeline.Writer.TopicWriter.InitTask

  @impl Pipeline.Writer
  def init(args) do
    case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, {InitTask, args}) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  @impl Pipeline.Writer
  def write(content, opts) when is_list(content) do
    instance_producer = producer(opts)

    {:ok, topic} = Registry.meta(Pipeline.Registry, instance_producer)
    Elsa.produce(instance_producer, topic, content)
  end

  @impl Pipeline.Writer
  def terminate(_), do: :ok

  defp producer(config) do
    instance = Keyword.fetch!(config, :instance)
    producer_name = Keyword.fetch!(config, :producer_name)

    :"#{instance}-#{producer_name}"
  end
end

defmodule Pipeline.Writer.TopicWriter.InitTask do
  @moduledoc "TODO"

  use Task, restart: :transient
  use Retry

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(args) do
    config = parse_config(args)
    producer_spec = producer(config)

    Elsa.create_topic(config.endpoints, config.topic)
    wait_for_topic!(config)

    case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, producer_spec) do
      {:ok, _pid} ->
        :ok = Registry.put_meta(Pipeline.Registry, config.name, config.topic)

      {:error, {:already_started, _pid}} ->
        :ok = Registry.put_meta(Pipeline.Registry, config.name, config.topic)

      error ->
        raise "TODO: #{inspect(error)}"
    end
  end

  defp parse_config(args) do
    instance = Keyword.fetch!(args, :instance)
    producer = Keyword.fetch!(args, :producer_name)

    %{
      instance: instance,
      endpoints: Keyword.fetch!(args, :endpoints),
      topic: Keyword.fetch!(args, :topic),
      name: :"#{instance}-#{producer}",
      retry_count: Keyword.get(args, :retry_count, 10),
      retry_delay: Keyword.get(args, :retry_delay, 100)
    }
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

  defp producer(config) do
    {
      Elsa.Supervisor,
      [endpoints: config.endpoints, connection: config.name, producer: [topic: config.topic]]
    }
  end
end
