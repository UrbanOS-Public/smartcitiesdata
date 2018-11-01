defmodule Search.DatasetSearchinatorTest do
  use ExUnit.Case
  use Placebo

  describe "search" do

    setup do
      mock_dataset_summaries = [
        create_dataset(id: 1, title: "Jarred loves pdf", description: "Something super cool"),
        create_dataset(id: 2, title: "Jessie hates useless paperwork", description: "Cool beans")
      ]
      allow DiscoveryApi.Data.Retriever.get_datasets(), return: {:ok, mock_dataset_summaries}
      :ok
    end

    test "matches based on title" do
      results = Data.DatasetSearchinator.search(query: "love")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0)[:id] == 1
    end

    test "matches based on title with multiple words" do
      results = Data.DatasetSearchinator.search(query: "loves Jarred")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0)[:id] == 1
    end

    test "matches based on title case insensitive" do
      results = Data.DatasetSearchinator.search(query: "jaRreD")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0)[:id] == 1
    end

    test "matches based on description" do
      results = Data.DatasetSearchinator.search(query: "super")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0)[:id] == 1
    end

    test "matches based on multiple" do
      results = Data.DatasetSearchinator.search(query: "loves paperwork")

      assert Enum.count(results) == 2
      assert Enum.at(results, 0)[:id] == 1
      assert Enum.at(results, 1)[:id] == 2
    end
  end

  def create_dataset(options \\ []) do
    defaults = [id: 1, title: "Jarred", description: "Olson"]
    Keyword.merge(defaults, options) |> Enum.into(%{})
  end

end
