defmodule DiscoveryApi.Search.DatasetSearchinatorTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApi.Search.DatasetSearchinator
  alias DiscoveryApi.Test.Helper

  describe "search" do
    setup do
      mock_dataset_summaries = [
        Helper.sample_dataset(%{
          id: 1,
          title: "Jarred loves pdf",
          description: "Something super cool",
          organization: "hi"
        }),
        Helper.sample_dataset(%{
          id: 2,
          title: "Jessie hates useless paperwork",
          description: "Cool beans",
          organization: "hi"
        }),
        Helper.sample_dataset(%{id: 3, title: "This one has no description", organization: "hi"}),
        Helper.sample_dataset(%{id: 4, organization: "testOrg"}),
        Helper.sample_dataset(%{id: 5, organization: "Bogus"})
      ]

      allow(DiscoveryApi.Data.Dataset.get_all(), return: mock_dataset_summaries)
      :ok
    end

    test "matches based on title" do
      results = DatasetSearchinator.search("love")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0).id == 1
    end

    test "matches based on title with multiple words" do
      results = DatasetSearchinator.search("loves Jarred")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0).id == 1
    end

    test "matches based on title case insensitive" do
      results = DatasetSearchinator.search("jaRreD")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0).id == 1
    end

    test "matches based on description" do
      results = DatasetSearchinator.search("super")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0).id == 1
    end

    test "matches based on multiple" do
      results = DatasetSearchinator.search("loves paperwork")

      assert Enum.count(results) == 2
      assert Enum.at(results, 0).id == 1
      assert Enum.at(results, 1).id == 2
    end

    test "matches when dataset has no description" do
      results = DatasetSearchinator.search("description")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0).id == 3
    end

    test "matches based on organization" do
      results = DatasetSearchinator.search("testorg")

      assert Enum.count(results) == 1
      assert Enum.at(results, 0).id == 4
    end
  end
end
