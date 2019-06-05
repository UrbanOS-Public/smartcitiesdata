defmodule DiscoveryApi.Data.DataJsonTest do
  use ExUnit.Case
  use Divo, services: [:redis]
  alias SmartCity.{Dataset, Organization}
  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  test "Properly formatted metadata is returned after consuming registry messages" do
    organization = TDG.create_organization(%{})
    Organization.write(organization)

    dataset_one = TDG.create_dataset(%{technical: %{orgId: organization.id, private: true}})
    Dataset.write(dataset_one)

    dataset_two = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    Dataset.write(dataset_two)

    dataset_three = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    Dataset.write(dataset_three)

    Patiently.wait_for!(
      fn -> public_datasets_available?(2) end,
      dwell: 1000,
      max_tries: 20
    )

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

  defp public_datasets_available?(count) do
    datasets =
      "http://localhost:4000/api/v1/data_json"
      |> get_map_from_url()
      |> Map.get("dataset")

    if Enum.count(datasets) == count do
      Enum.all?(datasets, fn dataset -> dataset["accessLevel"] == "public" end)
    else
      false
    end
  end

  defp get_map_from_url(url) do
    url
    |> HTTPoison.get!()
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
