defmodule Pipeline.Writer.SingleTopicWriter do
  @moduledoc "TODO"

  @behaviour Pipeline.Writer
  alias Pipeline.Writer.SingleTopicWriter.InitTask

  @impl Pipeline.Writer
  def init(args) do
    case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, {InitTask, args}) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  @impl Pipeline.Writer
  def write(content, opts) when is_list(content) do
    app = Keyword.fetch!(opts, :app)
    producer_name = Application.get_env(app, :producer_name)
    name = :"#{app}-#{producer_name}"

    {:ok, topic} = Registry.meta(Pipeline.Registry, name)
    Elsa.produce_sync(topic, content, name: name)
  end
end

defmodule Pipeline.Writer.SingleTopicWriter.InitTask do
  @moduledoc "TODO"

  use Task, restart: :transient
  use Retry

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(args) do
    app = Keyword.fetch!(args, :app)
    topic = Application.get_env(app, :output_topic)

    endpoints(app)
    |> Elsa.create_topic(topic)

    wait_for_topic!(app, topic)
    producer_spec = producer(app, topic)

    case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, producer_spec) do
      {:ok, _pid} ->
        :ok = Registry.put_meta(Pipeline.Registry, producer_name(app), topic)

      {:error, {:already_started, _pid}} ->
        :ok = Registry.put_meta(Pipeline.Registry, producer_name(app), topic)

      error ->
        raise "TODO: #{inspect(error)}"
    end
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

  defp producer(app, topic) do
    {
      Elsa.Producer.Supervisor,
      name: producer_name(app), endpoints: endpoints(app), topic: topic
    }
  end

  defp producer_name(app), do: :"#{app}-#{Application.get_env(app, :producer_name)}"
  defp endpoints(app), do: Application.get_env(app, :elsa_brokers)
end
