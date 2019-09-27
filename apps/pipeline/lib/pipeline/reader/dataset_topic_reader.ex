defmodule Pipeline.Reader.DatasetTopicReader do
  @moduledoc "TODO"

  @behaviour Pipeline.Reader
  alias Pipeline.Reader.DatasetTopicReader.InitTask

  @impl Pipeline.Reader
  def init(args) do
    case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, {InitTask, args}) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end
end

defmodule Pipeline.Reader.DatasetTopicReader.InitTask do
  @moduledoc "TODO"

  use Task, restart: :transient
  use Retry

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(args) do
    app = Keyword.fetch!(args, :app)
    dataset = Keyword.fetch!(args, :dataset)
    handler = Keyword.fetch!(args, :handler)
    topic = topic_name(app, dataset.id)

    endpoints(app)
    |> Elsa.create_topic(topic)

    wait_for_topic!(app, topic)

    consumer_spec = consumer(app, topic, handler, dataset)

    case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, consumer_spec) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> raise "Failed to supervise #{topic} consumer: #{inspect(error)}"
    end
  end

  defp consumer(app, topic, handler, dataset) do
    start_options = [
      brokers: endpoints(app),
      name: :"#{app}-#{topic}-consumer",
      group: "#{app}-#{topic}",
      topics: [topic],
      handler: handler,
      handler_init_args: [dataset: dataset],
      config: Application.get_env(app, :topic_subscriber_config, [])
    ]

    {Elsa.Group.Supervisor, start_options}
  end

  defp wait_for_topic!(app, topic) do
    delay = Application.get_env(app, :retry_initial_delay)
    count = Application.get_env(app, :retry_count)

    retry with: delay |> exponential_backoff() |> Stream.take(count), atoms: [false] do
      endpoints(app)
      |> Elsa.topic?(topic)
    after
      true -> topic
    else
      _ -> raise "Timed out waiting for #{topic} to be available"
    end
  end

  defp topic_name(app, id) do
    prefix = Application.get_env(app, :input_topic_prefix)
    "#{prefix}-#{id}"
  end

  defp endpoints(app), do: Application.get_env(app, :elsa_brokers)
end
