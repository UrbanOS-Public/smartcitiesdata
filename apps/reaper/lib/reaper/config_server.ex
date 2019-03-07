defmodule Reaper.ConfigServer do
  @moduledoc """
  A control plane.

  Reaper.ConfigServer manages supervisors (`Reaper.FeedSupervisor`) for each dataset configured in dataset registry kafka topic.
  """

  use GenServer
  alias Reaper.DataFeed
  alias Reaper.Persistence
  alias SCOS.RegistryMessage

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(__MODULE__))
  end

  def init(state \\ []) do
    load_persisted_datasets()
    {:ok, state}
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

  defp load_persisted_datasets() do
    Persistence.get_all()
    |> Enum.map(&create_feed_supervisor/1)
  end

  def send_dataset(dataset) do
    create_feed_supervisor(dataset)
    update_feed_supervisor(dataset)
    Persistence.persist(dataset)
  end

  defp create_feed_supervisor(%RegistryMessage{id: id} = dataset) do
    Horde.Supervisor.start_child(
      Reaper.Horde.Supervisor,
      %{
        id: String.to_atom(id),
        start: {Reaper.FeedSupervisor, :start_link, [[dataset: dataset, name: via_tuple(String.to_atom(id))]]}
      }
    )
  end

  defp update_feed_supervisor(%RegistryMessage{id: id} = dataset) do
    feed_supervisor_pid = Horde.Registry.lookup(Reaper.Registry, String.to_atom(id))

    if feed_supervisor_pid != :undefined do
      Reaper.FeedSupervisor.update_data_feed(feed_supervisor_pid, dataset)
    end
  end

  defp via_tuple(id), do: {:via, Horde.Registry, {Reaper.Registry, id}}
end
