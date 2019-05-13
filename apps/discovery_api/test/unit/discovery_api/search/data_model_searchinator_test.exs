defmodule DiscoveryApi.Search.DataModelSearchinatorTest do
  use ExUnit.Case
  use Placebo
  import Checkov

  alias DiscoveryApi.Search.DataModelSearchinator
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Model

  describe "search/1" do
    setup do
      mock_models = [
        Helper.sample_model(%{
          id: 1,
          title: "Jarred love pdf",
          description: "Something super cool, sometimes",
          organization: "Paul Co.",
          keywords: ["stuff", "thIngs", "town"]
        }),
        Helper.sample_model(%{
          id: 2,
          title: "Jessie hates/loves paperwork",
          description: "Cool beans",
          organization: "Mia Co.",
          keywords: ["stuff town"]
        }),
        Helper.sample_model(%{
          id: 3,
          title: "This one has no description, sometimes",
          organization: "Ben Co."
        }),
        Helper.sample_model(%{id: 4, organization: "testOrg"}),
        Helper.sample_model(%{id: 5, organization: "Bogus"})
      ]

      allow(Model.get_all(), return: mock_models)
      :ok
    end

    data_test("partial matches #{description}") do
      results = DataModelSearchinator.search(search_term)

      actual_ids = Enum.map(results, &Map.get(&1, :id))

      assert expected_ids == actual_ids, error_diff(description, expected_ids, actual_ids)

      where([
        [:search_term, :expected_ids, :description],
        ["love", [1, 2], "based on same field (title)"],
        ["super cool", [1], "spaces are ANDs"],
        ["jarred sometimes", [], "no total match"],
        ["jaRreD", [1], "based on a field, case insensitive"],
        ["description", [3], "based on title"],
        ["super", [1], "based on description"],
        ["testor", [4], "based on organization"],
        ["stuff town", [2], "based on keywords, exact match"],
        ["Ben", [3], "when model is missing a field (description)"],
        ["asdfasdfasdf", [], "are not returned when no matches are found"]
      ])
    end
  end

  defp error_diff(description, expected, actual) do
    "failed for case: #{description} - #{inspect(expected)} v #{inspect(actual)}"
  end
end
