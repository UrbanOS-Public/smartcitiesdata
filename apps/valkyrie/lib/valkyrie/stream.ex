defmodule Valkyrie.Stream do
  @moduledoc """
  Process to wrap the processes that push messages through `valkyrie`.
  This `GenServer` links processes for reading messages from a `Source.t()` impl
  """

  alias Valkyrie.TopicHelper

  use GenServer, shutdown: 30_000
  use Annotated.Retry
  use Properties, otp_app: :valkyrie
  require Logger

  @max_retries get_config_value(:max_retries, default: 50)

  @type init_opts :: [
          dataset_id: String.t(),
          schema: String.t(),
          profiling_enabled: boolean()
        ]

  def start_link(init_opts) do
    server_opts = Keyword.take(init_opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl GenServer
  def init(init_opts) do
    Process.flag(:trap_exit, true)
    Logger.debug(fn -> "#{__MODULE__}: init with #{inspect(init_opts)}" end)

    state = %{
      dataset_id: Keyword.fetch!(init_opts, :dataset_id),
      schema: Keyword.fetch!(init_opts, :schema),
      profiling_enabled: Keyword.get(init_opts, :profiling_enabled, false),
    }

    {:ok, state, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    input_topic = Kafka.Topic.new!(endpoints: TopicHelper.get_endpoints(), name: TopicHelper.input_topic_name(state.dataset_id))
    output_topic = Kafka.Topic.new!(endpoints: TopicHelper.get_endpoints(), name: TopicHelper.output_topic_name(state.dataset_id))

    with {:ok, source_pid} <- start_source(input_topic, state),
      {:ok, destination_pid} <- start_destination(output_topic, state) do
        new_state =
          state
          |> Map.put(:source_pid, source_pid)
          |> Map.put(:source, input_topic)
          |> Map.put(:destination_pid, destination_pid)
          |> Map.put(:destination, output_topic)

        {:noreply, new_state}

    else
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  @retry with: exponential_backoff(100) |> take(@max_retries)
  defp start_source(input_topic, state) do
    context =
      Source.Context.new!(
        handler: Valkyrie.Stream.SourceHandler,
        app_name: :valkyrie,
        dataset_id: state.dataset_id,
        assigns: %{
          kafka: Application.get_env(:valkyrie, :topic_subscriber_config),
          schema: state.schema,
          profiling_enabled: state.profiling_enabled
        }
      )

    Source.start_link(input_topic, context)
  end

  @retry with: exponential_backoff(100) |> take(@max_retries)
  defp start_destination(output_topic, state) do
    context =
      Destination.Context.new!(
        app_name: :valkyrie,
        dataset_id: state.dataset_id
      )

    Destination.start_link(output_topic, context)
  end

  @impl GenServer
  def terminate(reason, state) do
    if Map.has_key?(state, :source) do
      pid = Map.get(state, :source_pid)
      Source.stop(state.source, pid)
    end

    if Map.has_key?(state, :destination) do
      pid = Map.get(state, :destination_pid)
      Destination.stop(state.destination, pid)
    end

    reason
  end
end
