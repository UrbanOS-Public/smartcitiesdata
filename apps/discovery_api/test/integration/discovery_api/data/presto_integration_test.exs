defmodule DiscoveryApi.Data.PrestoIngrationTest do
  use ExUnit.Case
  use Placebo
  use DiscoveryApi.DataCase
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper

  import SmartCity.Event, only: [dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 3]

  @instance_name DiscoveryApi.instance_name()

  setup do
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  @moduletag capture_log: true
  test "returns empty list when dataset has no data saved" do
    allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: %{access_groups: []})

    organization = Helper.create_persisted_organization()

    dataset = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    system_name = dataset.technical.systemName

    DiscoveryApi.prestige_opts()
    |> Keyword.merge(receive_timeout: 10_000)
    |> Prestige.new_session()
    |> Prestige.query!("create table if not exists #{system_name} (id integer, name varchar)")

    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

    eventually(
      fn ->
        assert get_dataset_preview(dataset.id) == []
      end,
      2000,
      20
    )
  end

  @moduletag capture_log: true
  test "returns results for datasets stored in presto" do
    allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: %{access_groups: []})
    organization = Helper.create_persisted_organization()

    dataset = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    system_name = dataset.technical.systemName

    DiscoveryApi.prestige_opts()
    |> Keyword.merge(receive_timeout: 10_000)
    |> Prestige.new_session()
    |> Prestige.query!("create table if not exists #{system_name} (id integer, name varchar)")

    DiscoveryApi.prestige_opts()
    |> Keyword.merge(receive_timeout: 10_000)
    |> Prestige.new_session()
    |> Prestige.query!(~s|insert into "#{system_name}" values (1, 'bob'), (2, 'mike')|)

    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

    expected = [%{"id" => 1, "name" => "bob"}, %{"id" => 2, "name" => "mike"}]

    eventually(
      fn ->
        assert get_dataset_preview(dataset.id) == expected
      end,
      2000,
      10
    )
  end

  defp get_dataset_preview(dataset_id) do
    body =
      "http://localhost:4000/api/v1/dataset/#{dataset_id}/preview"
      |> HTTPoison.get!()
      |> Map.get(:body)
      |> Jason.decode!()

    case body do
      %{"message" => message} -> message
      %{"data" => data} -> data
    end
  end
end
