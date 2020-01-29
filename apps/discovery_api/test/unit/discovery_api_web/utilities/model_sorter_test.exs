defmodule DiscoveryApiWeb.Utilities.ModelSorterTest do
  use ExUnit.Case

  alias DiscoveryApi.Test.Helper

  alias DiscoveryApiWeb.Utilities.ModelSorter

  describe "sort_models/2" do
    test "sorts valid timestamps in descending order" do
      models =
        create_models([
          "2020-12-27T19:20:22.141769Z",
          "2020-12-27T20:20:22.141769Z"
        ])

      actual_sorted_dates = ModelSorter.sort_models(models, "last_mod") |> Enum.map(&Map.get(&1, :modifiedDate))
      assert actual_sorted_dates == ["2020-12-27T20:20:22.141769Z", "2020-12-27T19:20:22.141769Z"]
    end

    test "sorts valid dates in descending order" do
      models =
        create_models([
          "2020-12-27",
          "2020-12-28"
        ])

      actual_sorted_dates = ModelSorter.sort_models(models, "last_mod") |> Enum.map(&Map.get(&1, :modifiedDate))
      assert actual_sorted_dates == ["2020-12-28", "2020-12-27"]
    end

    test "sorts mixed valid dates and timestamps in descending order" do
      models =
        create_models([
          "2020-12-26",
          "2020-12-27T19:20:22.141769Z",
          "2020-12-28"
        ])

      actual_sorted_dates = ModelSorter.sort_models(models, "last_mod") |> Enum.map(&Map.get(&1, :modifiedDate))
      assert actual_sorted_dates == ["2020-12-28", "2020-12-27T19:20:22.141769Z", "2020-12-26"]
    end
  end

  defp create_models(dates) do
    Enum.map(dates, fn date ->
      Helper.sample_model(%{
        name: "model_name",
        sourceType: "ingest",
        modifiedDate: date
      })
    end)
  end
end
