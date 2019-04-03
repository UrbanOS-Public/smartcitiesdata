defmodule DiscoveryApi.Data.DatasetEventsTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.{Dataset, Organization}
  alias SmartCity.TestDataGenerator, as: TDG

  @name_space "discovery-api:project-open-data:"

  test "Properly formatted metadata is returned after consuming registry messages" do
    organization = TDG.create_organization(%{})
    Organization.write(organization)

    dataset_one = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    Dataset.write(dataset_one)

    dataset_two = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    Dataset.write(dataset_two)

    Patiently.wait_for!(
      fn -> redix_populated?() end,
      dwell: 1000,
      max_tries: 20
    )

    actual =
      "http://localhost:4000/api/v1/data_json"
      |> HTTPoison.get!()
      |> Map.from_struct()
      |> Map.get(:body)
      |> Jason.decode!()

    schema =
      "./test/integration/schemas/catalog.json"
      |> File.read!()
      |> Jason.decode!()
      |> URLResolver.remove_urls()

    assert 2 ==
             actual
             |> Map.get("dataset")
             |> Enum.count()

    case ExJsonSchema.Validator.validate(schema, actual) do
      :ok ->
        assert true

      {:error, errors} ->
        IO.puts("Failed:" <> inspect(errors))
        flunk(errors)
    end
  end

  defp redix_populated?() do
    case Redix.command!(:redix, ["KEYS", @name_space <> "*"]) do
      [] ->
        false

      keys ->
        Enum.count(keys) == 2
    end
  end
end
