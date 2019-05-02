defmodule DiscoveryApi.Search.DatasetSearchinatorTest do
  use ExUnit.Case
  use Placebo
  import Checkov

  alias DiscoveryApi.Search.DatasetSearchinator
  alias DiscoveryApi.Test.Helper

  describe "search/1" do
    setup do
      mock_dataset_summaries = [
        Helper.sample_dataset(%{
          id: 1,
          title: "Jarred love pdf",
          description: "Something super cool, sometimes",
          organization: "Paul Co.",
          keywords: ["stuff", "thIngs"]
        }),
        Helper.sample_dataset(%{
          id: 2,
          title: "Jessie hates/loves paperwork",
          description: "Cool beans",
          organization: "Mia Co.",
          keywords: ["stuff town"]
        }),
        Helper.sample_dataset(%{
          id: 3,
          title: "This one has no description, sometimes",
          organization: "Ben Co."
        }),
        Helper.sample_dataset(%{id: 4, organization: "testOrg"}),
        Helper.sample_dataset(%{id: 5, organization: "Bogus"})
      ]

      allow(DiscoveryApi.Data.Dataset.get_all(), return: mock_dataset_summaries)
      :ok
    end

    data_test("partial matches #{description}") do
      results = DatasetSearchinator.search(search_term)

      actual_ids = Enum.map(results, &Map.get(&1, :id))

      assert expected_ids == actual_ids, error_diff(description, expected_ids, actual_ids)

      where([
        [:search_term, :expected_ids, :description],
        ["love", [1, 2], "based on same field (title)"],
        ["jarred sometimes", [1, 3], "based on different field (title and description)"],
        ["love Jarred", [1, 2], "with OR regardless of order"],
        ["jaRreD", [1], "based on a field, case insensitive"],
        ["description", [3], "based on title"],
        ["super", [1], "based on description"],
        ["testor", [4], "based on organization"],
        ["stuff town", [1, 2], "based on keywords"],
        ["Ben", [3], "when dataset is missing a field (description)"],
        ["asdfasdfasdf", [], "are not returned when no matches are found"]
      ])
    end
  end

  defp error_diff(description, expected, actual) do
    "failed for case: #{description} - #{inspect(expected)} v #{inspect(actual)}"
  end
end
