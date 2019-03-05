defmodule Reaper.ConfigServerTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.ConfigServer
  alias Reaper.DataFeed

  setup do
    TestHelper.start_horde(Reaper.Registry, Reaper.Horde.Supervisor)

    :ok
  end

  describe "on registry event received with no previous datasets" do
    test "the config server spins up several new supervisors" do
      ConfigServer.start_link([])

      ConfigServer.send_dataset(FixtureHelper.new_dataset(%{id: "12345-6789"}))
      ConfigServer.send_dataset(FixtureHelper.new_dataset(%{id: "23456-7891"}))
      ConfigServer.send_dataset(FixtureHelper.new_dataset(%{id: "34567-8912"}))

      assert feed_supervisor_count() == 3
      assert feed_cache_count() == 3
    end
  end

  describe "on registry event received with previous datasets" do
    test "the config server updates an existing data feed" do
      ConfigServer.start_link([])

      new_url = "https://first-url-part-deux.com"

      ConfigServer.send_dataset(FixtureHelper.new_dataset(%{id: "12345-6789"}))

      assert feed_supervisor_count() == 1
      assert feed_cache_count() == 1

      initial_pids = get_child_pids_for_feed_supervisor(:"12345-6789")
      assert initial_pids != :undefined

      ConfigServer.send_dataset(FixtureHelper.new_dataset(%{id: "12345-6789", technical: %{sourceUrl: new_url}}))

      assert feed_supervisor_count() == 1
      assert feed_cache_count() == 1

      eventual_pids = get_child_pids_for_feed_supervisor(:"12345-6789")
      assert eventual_pids != :undefined
      assert eventual_pids == initial_pids

      %{
        dataset: %{
          technical: %{
            sourceUrl: source_url
          }
        }
      } = get_state(:"12345-6789_feed")

      assert source_url == new_url
    end

    test "when feed supervisor is not found update does not blow up" do
      ConfigServer.start_link([])
      ConfigServer.send_dataset(FixtureHelper.new_dataset(%{id: "12345-6789"}))

      assert feed_supervisor_count() == 1
      assert feed_cache_count() == 1

      allow Horde.Registry.lookup(any(), any()), return: :undefined, meck_options: [:passthrough]

      ConfigServer.send_dataset(FixtureHelper.new_dataset(%{id: "12345-6789", technical: %{sourceUrl: "whatever"}}))

      assert feed_supervisor_count() == 1
      assert feed_cache_count() == 1
    end
  end

  defp get_state(name) do
    DataFeed.get({:via, Horde.Registry, {Reaper.Registry, name}})
  end

  defp get_child_pids_for_feed_supervisor(name) do
    Reaper.Registry
    |> Horde.Registry.lookup(name)
    |> Horde.Supervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.sort()
  end

  defp feed_supervisor_count do
    Reaper.Horde.Supervisor
    |> Horde.Supervisor.which_children()
    |> Enum.filter(fn [{_, _, _, [mod]}] -> mod == Reaper.FeedSupervisor end)
    |> Enum.count()
  end

  defp feed_cache_count do
    Reaper.Horde.Supervisor
    |> Horde.Supervisor.which_children()
    |> Enum.filter(fn [{_, _, _, [mod]}] -> mod == Reaper.FeedSupervisor end)
    |> Enum.flat_map(fn [{_, pid, _, _}] -> Supervisor.which_children(pid) end)
    |> Enum.filter(fn {_, _, _, [mod]} -> mod == Cachex end)
    |> Enum.count()
  end
end
