defmodule DiscoveryApi.Search.DataModelSearchinatorTest do
  use ExUnit.Case
  use Placebo
  import Checkov

  alias DiscoveryApi.Search.DataModelSearchinator
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Model

  describe "search/1" do
    data_test "search #{field} for #{search_term} - #{description}" do
      models = [
        Helper.sample_model(%{
          id: 1,
          title: "A B C findme",
          description: "D E F",
          organization: "G H I",
          keywords: ["one"]
        }),
        Helper.sample_model(%{
          id: 2,
          title: "C D E",
          description: "F G H findme",
          organization: "I J K",
          keywords: ["two", "foo bar", "abc xyz"]
        }),
        Helper.sample_model(%{
          id: 3,
          title: "Blah blah blah",
          description: nil,
          organization: "K L M findme",
          keywords: ["foo bar", "K", "three"]
        }),
        Helper.sample_model(%{
          id: 4,
          title: "Hey hey",
          description: "",
          organization: nil,
          keywords: ["findme"]
        })
      ]

      allow(Model.get_all(), return: models)

      results =
        search_term
        |> DataModelSearchinator.search()
        |> Enum.map(&Map.get(&1, :id))

      assert expected == results, error_diff(description, field, expected, results)

      where([
        [:search_term, :field, :expected, :description],
        ["A C", "title", [1], "spaces use AND logic"],
        ["A D", "title", [], "no match"],
        ["a C", "title", [1], "case insensitive"],
        ["c a", "title", [1], "order insensitive"],
        ["c", "title", [1, 2], "multiple matches"],
        ["f H", "description", [2], "spaces use AND logic"],
        ["f H q", "description", [], "no match"],
        ["m L", "organization", [3], "spaces use AND logic"],
        ["m L q", "organization", [], "no match"],
        ["one three", "keywords", [1, 3], "spaces use OR logic"],
        ["foo bar", "keywords", [2, 3], "exact query match"],
        ["abc", "keywords", [], "no match"],
        ["findme", "all", [1, 2, 3, 4], "search across all fields"],
        ["M", "organization/keywords", [3], "one result per dataset"]
      ])
    end
  end

  defp error_diff(description, field, expected, actual) do
    "failed for case: #{description} (#{field}) - #{inspect(expected)} v #{inspect(actual)}"
  end
end
