defmodule Reaper.ConfigServer do
  @moduledoc """
  A control plane.

  Reaper.ConfigServer manages supervisors (`Reaper.FeedSupervisor`) for each dataset configured in dataset registry kafka topic.
  """

  use GenServer
  alias Reaper.Persistence
  alias Reaper.ReaperConfig

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(__MODULE__))
  end

  def init(state \\ []) do
    {:ok, state, {:continue, :load_persisted_configs}}
  end

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

  def handle_continue(:load_persisted_configs, state) do
    Persistence.get_all()
    |> Enum.each(&create_feed_supervisor/1)

    {:noreply, state}
  end

  def process_reaper_config(%ReaperConfig{sourceType: "remote"}), do: nil

  def process_reaper_config(%ReaperConfig{} = reaper_config) do
    create_feed_supervisor(reaper_config)
    update_feed_supervisor(reaper_config)
    Persistence.persist(reaper_config)
  end

  defp create_feed_supervisor(%ReaperConfig{dataset_id: id} = reaper_config) do
    Horde.Supervisor.start_child(
      Reaper.Horde.Supervisor,
      %{
        id: String.to_atom(id),
        start:
          {Reaper.FeedSupervisor, :start_link, [[reaper_config: reaper_config, name: via_tuple(String.to_atom(id))]]}
      }
    )
  end

  defp update_feed_supervisor(%ReaperConfig{dataset_id: id} = reaper_config) do
    feed_supervisor_pid = Horde.Registry.lookup(Reaper.Registry, String.to_atom(id))

    if feed_supervisor_pid != :undefined do
      Reaper.FeedSupervisor.update_data_feed(feed_supervisor_pid, reaper_config)
    end
  end

  defp via_tuple(id), do: {:via, Horde.Registry, {Reaper.Registry, id}}
end
