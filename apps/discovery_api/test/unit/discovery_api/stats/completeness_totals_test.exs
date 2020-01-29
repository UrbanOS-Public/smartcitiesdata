defmodule DiscoveryApi.Stats.CompletenessTotalsTest do
  use ExUnit.Case
  alias DiscoveryApi.Stats.CompletenessTotals

  describe "calculate_dataset_total/1" do
    test "reduces the fields to a single average" do
      input = calculate_total_input()
      assert 0.5 == CompletenessTotals.calculate_dataset_total(input)
    end

    test "uses all fields when no fields are required" do
      input = calculate_optional_only_input()
      assert 0.46 == CompletenessTotals.calculate_dataset_total(input)
    end
  end

  defp calculate_total_input() do
    %{
      :id => "abc123",
      :record_count => 10,
      :fields => %{
        "id" => %{required: true, count: 10},
        "name" => %{required: true, count: 2},
        "super" => %{required: false, count: 3},
        "happy" => %{required: true, count: 3},
        "fun time" => %{required: false, count: 5}
      }
    }
  end

  defp calculate_optional_only_input() do
    %{
      :id => "xyz234",
      :record_count => 10,
      :fields => %{
        "id" => %{required: false, count: 10},
        "name" => %{required: false, count: 2},
        "super" => %{required: false, count: 3},
        "happy" => %{required: false, count: 3},
        "fun time" => %{required: false, count: 5}
      }
    }
  end
end
