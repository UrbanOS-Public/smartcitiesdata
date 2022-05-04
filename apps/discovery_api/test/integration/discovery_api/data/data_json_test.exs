defmodule DiscoveryApi.Data.DataJsonTest do
  use ExUnit.Case
  use Placebo
  use DiscoveryApi.DataCase

  import SmartCity.Event, only: [dataset_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Services.DataJsonService

  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  @instance_name DiscoveryApi.instance_name()

  setup_all do
    allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: %{access_groups: []})
    Redix.command!(:redix, ["FLUSHALL"])

    on_exit(fn ->
      DataJsonService.delete_data_json()
    end)

    organization = Helper.create_persisted_organization()

    dataset_one = TDG.create_dataset(%{technical: %{orgId: organization.id, private: true}})
    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset_one)

    dataset_two = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset_two)

    dataset_three = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset_three)

    eventually(
      fn ->
        assert Enum.count(get_data_json_datasets()) == 2
      end,
      2_000,
      20
    )

    [organization_id: organization.id]
  end

  test "Properly formatted metadata is returned after consuming registry messages" do
    actual = get_map_from_url("http://localhost:4000/api/v1/data_json")
    schema = get_schema_from_path("./test/integration/schemas/catalog.json")

    case ExJsonSchema.Validator.validate(schema, actual) do
      :ok ->
        assert true

      {:error, errors} ->
        IO.puts("Failed:" <> inspect(errors))
        flunk(inspect(errors))
    end
  end

  test "Returns an additional dataset when we add one via an update", %{organization_id: organization_id} do
    additional_dataset = TDG.create_dataset(%{technical: %{orgId: organization_id}})
    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, additional_dataset)

    eventually(fn ->
      assert Enum.count(get_data_json_datasets()) == 3
    end)
  end

  defp get_data_json_datasets() do
    "http://localhost:4000/api/v1/data_json"
    |> get_map_from_url()
    |> Map.get("dataset", [])
  end

  defp get_map_from_url(url) do
    url
    |> HTTPoison.get!([], follow_redirect: true)
    |> Map.from_struct()
    |> Map.get(:body)
    |> Jason.decode!()
  end

  defp get_schema_from_path(path) do
    path
    |> File.read!()
    |> Jason.decode!()
    |> URLResolver.remove_urls()
  end
end
