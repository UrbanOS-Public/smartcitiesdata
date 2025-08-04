defmodule DiscoveryStreams.Stream do
  @moduledoc """
  Process to wrap the processes that push messages through `discovery_streams`.
  This `GenServer` links processes for reading messages from a `Source.t()` impl
  """

  alias DiscoveryStreams.TopicHelper

  use GenServer, shutdown: 30_000
  use Annotated.Retry
  use Properties, otp_app: :discovery_streams
  require Logger

  @instance_name DiscoveryStreams.instance_name()

  @max_retries get_config_value(:max_retries, default: 50)

  @type init_opts :: [
          dataset_id: String.t(),
          system_name: String.t()
        ]

  getter(:topic_subscriber_config, generic: true)

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
      system_name: Keyword.fetch!(init_opts, :system_name)
    }

    {:ok, state, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    case start_source(state) do
      {:ok, source_pid} ->
        new_state =
          state
          |> Map.put(:source_pid, source_pid)

        {:noreply, new_state}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  @retry with: exponential_backoff(100) |> take(@max_retries)
  defp start_source(state) do
    context =
      Source.Context.new!(
        handler: DiscoveryStreams.Stream.SourceHandler,
        app_name: @instance_name,
        dataset_id: state.dataset_id,
        assigns: %{
          kafka: topic_subscriber_config(),
          system_name: state.system_name
        }
      )

    Source.start_link(
      Kafka.Topic.new!(endpoints: TopicHelper.get_endpoints(), name: TopicHelper.topic_name(state.dataset_id)),
      context
    )
  end

  @impl GenServer
  def terminate(reason, state) do
    if Map.has_key?(state, :source) do
      pid = Map.get(state, :source_pid)
      Source.stop(state.load.source, pid)
    end

    reason
  end
end