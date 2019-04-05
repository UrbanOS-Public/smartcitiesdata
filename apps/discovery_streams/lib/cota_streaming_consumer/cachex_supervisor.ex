defmodule CotaStreamingConsumer.CachexSupervisor do
  @moduledoc """
  Supervisor that manages dyanmic caches
  """
  use DynamicSupervisor
  require Cachex.Spec

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def create_cache(name) when is_atom(name) do
    ttl = Application.get_env(:cota_streaming_consumer, :ttl)
    expiration = Cachex.Spec.expiration(default: ttl)

    child_spec = %{
      id: :"dyn_cachex_#{name}",
      start: {Cachex, :start_link, [name, [expiration: expiration]]}
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
