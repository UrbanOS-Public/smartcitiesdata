defmodule DiscoveryApi.Data.DatasetTest do
  use ExUnit.Case
  alias DiscoveryApi.Data.Dataset

  setup do
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  test "Dataset saves data to Redis" do
    dataset = sample_dataset("123")

    Dataset.save(dataset)

    actual =
      Redix.command!(:redix, ["GET", "discovery-api:dataset:123"])
      |> Jason.decode!()

    assert actual["id"] == "123"
    assert actual["title"] == "The title"
    assert actual["keywords"] == ["tag a", "tag b"]
    assert actual["organization"] == "SCOS"
    assert actual["modified"] == "timestamp"
    assert actual["fileTypes"] == ["csv", "json"]
    assert actual["description"] == "This is the description"
  end

  test "get should return a single dataset" do
    dataset = sample_dataset("123")
    dataset_json_string = to_json(dataset)

    Redix.command!(:redix, ["SET", "discovery-api:dataset:123", dataset_json_string])

    actual_dataset = Dataset.get("123")

    assert actual_dataset == dataset
  end

  test "should return all of the datasets" do
    Enum.each(
      [sample_dataset("123"), sample_dataset("456")],
      fn dataset ->
        Redix.command!(:redix, ["SET", "discovery-api:dataset:#{dataset.id}", to_json(dataset)])
      end
    )

    actual_datasets = Dataset.get_all()

    assert ["123", "456"] == Enum.map(actual_datasets, fn dataset -> dataset.id end) |> Enum.sort()
  end

  test "get all returns empty list if no keys exist" do
    assert [] == Dataset.get_all()
  end

  defp to_json(dataset) do
    dataset
    |> Map.from_struct()
    |> Jason.encode!()
  end

  defp sample_dataset(id) do
    %Dataset{
      id: id,
      title: "The title",
      keywords: ["tag a", "tag b"],
      organization: "SCOS",
      modified: "timestamp",
      fileTypes: ["csv", "json"],
      description: "This is the description"
    }
  end
end
