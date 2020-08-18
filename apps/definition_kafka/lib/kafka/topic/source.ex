defmodule Kafka.Topic.Source do
  @moduledoc false
  use GenServer, shutdown: 30_000
  use Annotated.Retry
  require Logger

  def start_link(topic, %Source.Context{} = context) do
    GenServer.start_link(__MODULE__, {topic, context})
  end

  def stop(_topic, server) do
    GenServer.call(server, :stop, 30_000)
  end

  @retry with: constant_backoff(500) |> take(10)
  def delete(topic) do
    Elsa.delete_topic(topic.endpoints, topic.name)
  end

  @impl GenServer
  def init({topic, context}) do
    Process.flag(:trap_exit, true)

    state = %{
      topic: topic,
      context: context
    }

    {:ok, state, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    ensure_topic(state.topic)

    offset_reset_policy = get_in(state.context.assigns, [:kafka, :offset_reset_policy])

    {:ok, elsa_pid} =
      Elsa.Supervisor.start_link(
        endpoints: state.topic.endpoints,
        connection: :"connection_#{state.context.app_name}_#{state.topic.name}",
        group_consumer: [
          group: "group-#{state.context.app_name}-#{state.topic.name}",
          topics: [state.topic.name],
          handler: Kafka.Topic.Source.Handler,
          handler_init_args: state.context,
          config: [
            begin_offset: :earliest,
            offset_reset_policy: offset_reset_policy || :reset_to_earliest,
            prefetch_count: 0,
            prefetch_bytes: 2_097_152
          ]
        ]
      )

    {:noreply, Map.put(state, :elsa_pid, elsa_pid)}
  end

  @impl GenServer
  def handle_call(:stop, _from, state) do
    Logger.info(fn -> "#{__MODULE__}: Terminating by request" end)
    {:stop, :normal, :ok, state}
  end

  @impl GenServer
  def handle_info({:EXIT, pid, reason}, %{elsa_pid: pid} = state) do
    Logger.error(fn -> "#{__MODULE__}: Elsa(#{inspect(pid)}) died : #{inspect(reason)}" end)
    {:stop, reason, state}
  end

  def handle_info(message, state) do
    Logger.info(fn -> "#{__MODULE__}: received unknown message - #{inspect(message)}" end)
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, %{elsa_pid: pid}) do
    Process.exit(pid, reason)

    receive do
      {:EXIT, ^pid, _} -> reason
    after
      20_000 -> reason
    end
  end

  def terminate(reason, _) do
    reason
  end

  @retry with: constant_backoff(500) |> take(10)
  defp ensure_topic(topic) do
    unless Elsa.topic?(topic.endpoints, topic.name) do
      Elsa.create_topic(topic.endpoints, topic.name, partitions: topic.partitions)
    end
  end
end
