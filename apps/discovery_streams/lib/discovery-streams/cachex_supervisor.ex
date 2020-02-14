defmodule DiscoveryStreams.CachexSupervisor do
  @moduledoc """
  Supervisor that manages dynamic caches
  """
  use DynamicSupervisor
  require Cachex.Spec

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # sobelow_skip ["DOS.BinToAtom"]
  @doc "Creates a supervised cache under CachexSupervisor"
  @spec create_cache(atom) :: DynamicSupervisor.on_start_child()
  def create_cache(name) when is_atom(name) do
    ttl = Application.get_env(:discovery_streams, :ttl)
    expiration = Cachex.Spec.expiration(default: ttl)

    child_spec = %{
      id: :"dyn_cachex_#{name}",
      start: {Cachex, :start_link, [name, [expiration: expiration]]}
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  # def stop_dataset_supervisor(dataset_id) do
  #   name = name(dataset_id)

  #   case Process.whereis(name) do
  #     nil -> :ok
  #     pid -> DynamicSupervisor.terminate_child(DiscoveryStreams.Dynamic.Supervisor, pid)
  #   end
  # end
end
