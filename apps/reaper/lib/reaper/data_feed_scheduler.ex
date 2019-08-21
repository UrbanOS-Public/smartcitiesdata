defmodule Reaper.DataFeedScheduler do
  @moduledoc """
  An ETL process configured by `Reaper.ConfigServer` and supervised by `Reaper.FeedSupervisor`.
  """

  use GenServer
  alias Reaper.{Persistence, Util, ReaperConfig}
  use Retry
  @initial_delay Application.get_env(:reaper, :produce_timeout)
  @retries Application.get_env(:reaper, :produce_retries)

  ## CLIENT

  @doc """
  Sends an update to the given `Reaper.DataFeed` config
  """
  @spec update(Reaper.DataFeed, term()) :: :ok
  def update(data_feed, state) do
    GenServer.cast(data_feed, {:update, state})
  end

  @doc """
  Retrieves GenServer state from the given `Reaper.DataFeed`
  """
  @spec get(Reaper.DataFeed) :: term()
  def get(data_feed) do
    GenServer.call(data_feed, :get)
  end

  ## SERVER

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(%{pids: %{name: name}, reaper_config: reaper_config} = args) do
    reaper_config
    |> calculate_next_run_time()
    |> schedule_work()

    Horde.Registry.register(Reaper.Registry, name)

    case reaper_config.sourceType do
      "host" -> {:ok, args}
      _ -> {:ok, args, {:continue, :check_topic}}
    end
  end

  def handle_continue(:check_topic, state) do
    topic = "#{topic_prefix()}-#{state.reaper_config.dataset_id}"

    with {:topic_check, true} <- {:topic_check, topic_exists?(topic)},
         {:ok, _pid} <- start_topic_producer(topic) do
      {:noreply, state}
    else
      {:topic_check, false} -> {:stop, "Topic #{topic} does not exist. Exiting"}
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_info(:work, %{pids: %{cache: cache}, reaper_config: reaper_config} = state) do
    task =
      case reaper_config.sourceType do
        "host" -> Task.async(Reaper.HostedFileProcessor, :process, [reaper_config])
        _ -> Task.async(Reaper.DataFeed, :process, [reaper_config, cache])
      end

    Task.await(task, :infinity)

    timer_ref = schedule_work(reaper_config.cadence)

    case reaper_config.cadence do
      "once" ->
        {:stop, {:shutdown, "transient process finished its work"}, state}

      _ ->
        {:noreply, Util.deep_merge(state, %{timer_ref: timer_ref})}
    end
  end

  defp schedule_work(nil), do: nil
  defp schedule_work("once"), do: nil

  defp schedule_work(cadence) do
    Process.send_after(self(), :work, cadence)
  end

  def handle_cast({:update, config}, state) do
    {:noreply, Map.put(state, :reaper_config, config)}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  @doc """
    Returns an integer value indicating how many milliseconds until the next run time
  """
  @spec calculate_next_run_time(Reaper.ReaperConfig.t()) :: pos_integer()
  def calculate_next_run_time(%ReaperConfig{dataset_id: id, cadence: "once"}) do
    case Persistence.get_last_fetched_timestamp(id) do
      nil -> 0
      _last -> nil
    end
  end

  def calculate_next_run_time(reaper_config) do
    last_run_time =
      case Persistence.get_last_fetched_timestamp(reaper_config.dataset_id) do
        nil -> DateTime.from_unix!(0)
        exists -> exists
      end

    expected_run_time = DateTime.add(last_run_time, reaper_config.cadence, :millisecond)
    remaining_wait_time = DateTime.diff(expected_run_time, DateTime.utc_now(), :millisecond)

    max(0, remaining_wait_time)
  end

  defp topic_exists?(topic) do
    retry with: @initial_delay |> exponential_backoff() |> Stream.take(@retries), atoms: [false] do
      Elsa.topic?(endpoints(), topic)
    after
      true ->
        true
    else
      _ -> false
    end
  end

  defp start_topic_producer(topic) do
    Elsa.Producer.Supervisor.start_link(name: :"#{topic}_producer", endpoints: endpoints(), topic: topic)
  end

  defp endpoints(), do: Application.get_env(:reaper, :elsa_brokers)

  defp topic_prefix(), do: Application.get_env(:reaper, :output_topic_prefix)
end
