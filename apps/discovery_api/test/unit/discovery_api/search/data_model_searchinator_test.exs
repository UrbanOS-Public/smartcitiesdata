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
          title: "This is a testable title - FINDME",
          description: "An wrong description",
          organization: "My organization is a match",
          keywords: ["one"]
        }),
        Helper.sample_model(%{
          id: 2,
          title: "Test title should not be found",
          description: "A description to match - FINDME",
          organization: "My Organization",
          keywords: ["two", "foo bar", "abc xyz"]
        }),
        Helper.sample_model(%{
          id: 3,
          title: "This is a",
          description: "A description",
          organization: "Not the organization for me - FINDME",
          keywords: ["three", "abc 123", "not the organization"]
        }),
        Helper.sample_model(%{
          id: 4,
          title: "Blah blah blah",
          description: "",
          organization: "",
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
        ["this is a", "title", [1, 3], "spaces use AND logic"],
        ["this IS a tEst", "title", [1], "case insensitive"],
        ["a description", "description", [2, 3], "spaces use AND logic"],
        ["a description To MATCH", "description", [2], "case insensitive"],
        ["my organization", "organization", [1, 2], "spaces use AND logic"],
        ["my Organization IS a Match", "organization", [1], "case insensitive"],
        ["one three", "keywords", [1, 3], "spaces use OR logic"],
        ["foo bar", "keywords", [2], "exact query match"],
        ["abc", "keywords", [], "no match"],
        ["findme", "all", [1, 2, 3, 4], "search across all fields"],
        ["not the organization", "organization/keywords", [3], "one result per dataset"]
      ])
    end
  end

  defp error_diff(description, field, expected, actual) do
    "failed for case: #{description} (#{field}) - #{inspect(expected)} v #{inspect(actual)}"
  end
end
