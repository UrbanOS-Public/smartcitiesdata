defmodule Dlq.Server do
  @moduledoc false
  use GenServer
  use Annotated.Retry
  use Properties, otp_app: :dlq

  getter(:endpoints, required: true)
  getter(:topic, required: true)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)

    state = %{
      endpoints: endpoints(),
      connection: :elsa_dlq,
      topic: topic()
    }

    {:ok, state, {:continue, :init}}
  end

  def handle_continue(:init, state) do
    ensure_topic(state)
    {:ok, elsa} = start_producer(state)

    {:noreply, Map.put(state, :elsa, elsa)}
  end

  def handle_cast({:write, dead_letters}, state) do
    messages = Enum.map(dead_letters, &Jason.encode!/1)

    Elsa.produce(state.connection, state.topic, messages)

    {:noreply, state}
  end

  @retry with: constant_backoff(500) |> take(10)
  defp ensure_topic(state) do
    unless Elsa.topic?(state.endpoints, state.topic) do
      Elsa.create_topic(state.endpoints, state.topic)
    end
  end

  @retry with: constant_backoff(500) |> take(10)
  defp start_producer(state) do
    Elsa.Supervisor.start_link(
      endpoints: state.endpoints,
      connection: state.connection,
      producer: [
        topic: state.topic
      ]
    )
  end
end
