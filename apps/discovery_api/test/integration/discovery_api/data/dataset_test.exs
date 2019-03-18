defmodule DiscoveryApi.Data.DatasetTest do
  use ExUnit.Case
  use Divo
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Dataset

  setup do
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  test "Dataset saves data to Redis" do
    dataset = Helper.sample_dataset()
    Dataset.save(dataset)

    actual =
      Redix.command!(:redix, ["GET", "discovery-api:dataset:#{dataset.id}"])
      |> Jason.decode!()

    assert actual["id"] == dataset.id
    assert actual["title"] == dataset.title
    assert actual["keywords"] == dataset.keywords
    assert actual["organization"] == dataset.organization
    assert actual["modified"] == dataset.modified
    assert actual["fileTypes"] == dataset.fileTypes
    assert actual["description"] == dataset.description
  end

  test "get should return a single dataset" do
    dataset = Helper.sample_dataset()
    dataset_json_string = to_json(dataset)

    Redix.command!(:redix, ["SET", "discovery-api:dataset:#{dataset.id}", dataset_json_string])

    actual_dataset = Dataset.get(dataset.id)

    assert actual_dataset == dataset
  end

  test "get should return nil when dataset does not exist" do
    actual_dataset = Dataset.get("123456")

    assert nil == actual_dataset
  end

  test "should return all of the datasets" do
    dataset_id_1 = Faker.UUID.v4()
    dataset_id_2 = Faker.UUID.v4()

    Enum.each(
      [Helper.sample_dataset(%{id: dataset_id_1}), Helper.sample_dataset(%{id: dataset_id_2})],
      fn dataset ->
        Redix.command!(:redix, ["SET", "discovery-api:dataset:#{dataset.id}", to_json(dataset)])
      end
    )

    expected = [dataset_id_1, dataset_id_2] |> Enum.sort()
    actual = Dataset.get_all() |> Enum.map(fn dataset -> dataset.id end) |> Enum.sort()

    assert expected == actual
  end

  test "get all returns empty list if no keys exist" do
    assert [] == Dataset.get_all()
  end

  defp to_json(dataset) do
    dataset
    |> Map.from_struct()
    |> Jason.encode!()
  end
end
