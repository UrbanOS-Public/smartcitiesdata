defmodule Reaper.FeedSupervisor do
  @moduledoc """
  Supervises feed ETL processes (`Reaper.DataFeed`) and their caches.
  """

  use Supervisor
  require Keyword
  require Logger
  require Cachex.Spec
  alias Cachex.{Policy, Spec}

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(state) do
    children = create_child_spec(state[:dataset])

    Logger.debug(fn -> "Starting #{__MODULE__} with children: #{inspect(children, pretty: true)}" end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def create_child_spec(%{id: id} = dataset) do
    feed_name = String.to_atom("#{id}_feed")
    cache_name = String.to_atom("#{id}_cache")
    cache_limit = Spec.limit(size: 2000, policy: Policy.LRW, reclaim: 0.2)

    [
      %{
        id: cache_name,
        start: {Cachex, :start_link, [cache_name, [limit: cache_limit]]}
      },
      %{
        id: feed_name,
        start: {
          Reaper.DataFeed,
          :start_link,
          [
            %{
              dataset: dataset,
              pids: %{
                name: feed_name,
                cache: cache_name
              }
            }
          ]
        }
      }
    ]
  end
end
