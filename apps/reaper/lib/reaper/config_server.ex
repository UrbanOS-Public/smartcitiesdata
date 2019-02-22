defmodule Reaper.ConfigServer do
  @moduledoc """
  A control plane.

  Reaper.ConfigServer manages supervisors (`Reaper.FeedSupervisor`) for each dataset configured in dataset registry kafka topic.
  """

  use GenServer
  alias Reaper.DataFeed

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(__MODULE__))
  end

  def init(state \\ []) do
    {:ok, state}
  end

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient
    }
  end

  def send_dataset(dataset) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:dataset, dataset}
    )
  end

  def handle_call({:dataset, dataset}, from, previous_datasets) do
    create_feed_supervisor(dataset)
    update_feed_supervisor(dataset)

    {:reply, from, previous_datasets}
  end

  defp create_feed_supervisor(%Dataset{id: id} = dataset) do
    Horde.Supervisor.start_child(
      Reaper.Horde.Supervisor,
      %{
        id: id,
        start: {Reaper.FeedSupervisor, :start_link, [[dataset: dataset, name: via_tuple(String.to_atom(id))]]}
      }
    )
  end

  defp update_feed_supervisor(%Dataset{id: id} = dataset) do
    [{_feed_name, pid, _type, _modules} | _] =
      Reaper.Registry
      |> Horde.Registry.lookup(String.to_atom(id))
      |> Horde.Supervisor.which_children()

    DataFeed.update(pid, %{dataset: dataset})
  end

  defp via_tuple(id), do: {:via, Horde.Registry, {Reaper.Registry, id}}
end
