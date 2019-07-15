defmodule Reaper.ConfigServer do
  @moduledoc """
  A control plane.

  Reaper.ConfigServer manages supervisors (`Reaper.FeedSupervisor`) for each dataset
  """
  require Logger
  use GenServer
  alias Reaper.Persistence
  alias Reaper.ReaperConfig

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Reaper.Util.via_tuple(__MODULE__))
  end

  def init(state \\ []) do
    {:ok, state}
  end

  @doc """
  Returns a map containing the information required to start the child process
  """
  @spec child_spec(any()) :: map()
  def child_spec(args) do
    config_server_spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]}
    }

    %{
      id: :reaper_config_server_starter,
      restart: :transient,
      start:
        {Task, :start_link,
         [
           fn ->
             Horde.Supervisor.start_child(Reaper.Horde.Supervisor, config_server_spec)
           end
         ]}
    }
  end

  @doc """
  Starts a horde supervisor process for a dataset and persists it
  """
  @spec process_reaper_config(ReaperConfig.t()) ::
          {:ok, String.t()} | DynamicSupervisor.on_start_child() | nil
  def process_reaper_config(%ReaperConfig{cadence: "never", sourceType: "remote"}), do: nil

  def process_reaper_config(%ReaperConfig{cadence: "once", sourceType: "ingest"} = reaper_config) do
    create_feed_supervisor(reaper_config)
  end

  def process_reaper_config(%ReaperConfig{cadence: cadence, sourceType: "ingest"} = reaper_config)
      when is_integer(cadence) and cadence > 0 do
    do_process_reaper_config(reaper_config)
  end

  def process_reaper_config(%ReaperConfig{cadence: cadence, sourceType: "stream"} = reaper_config)
      when is_integer(cadence) do
    do_process_reaper_config(reaper_config)
  end

  def process_reaper_config(%ReaperConfig{cadence: cadence, sourceType: "host"} = reaper_config)
      when is_integer(cadence) and cadence > 0 do
    do_process_reaper_config(reaper_config)
  end

  def process_reaper_config(%ReaperConfig{cadence: "once", sourceType: "host"} = reaper_config) do
    create_feed_supervisor(reaper_config)
  end

  def process_reaper_config(reaper_config) do
    Logger.error("Inviable configuration error #{inspect(reaper_config)}")
    nil
  end

  defp do_process_reaper_config(reaper_config) do
    create_feed_supervisor(reaper_config)
    update_feed_supervisor(reaper_config)
    Persistence.persist(reaper_config)
  end

  defp create_feed_supervisor(reaper_config) do
    Horde.Supervisor.start_child(
      Reaper.Horde.Supervisor,
      Reaper.FeedSupervisor.child_spec(reaper_config)
    )
  end

  defp update_feed_supervisor(%ReaperConfig{dataset_id: id} = reaper_config) do
    feed_supervisor_pid = Horde.Registry.lookup(Reaper.Registry, String.to_atom(id))

    if feed_supervisor_pid != :undefined do
      Reaper.FeedSupervisor.update_data_feed(feed_supervisor_pid, reaper_config)
    end
  end
end
