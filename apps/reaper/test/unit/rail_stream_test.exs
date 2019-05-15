defmodule RailStreamTest do
  use ExUnit.Case
  doctest RailStream

  describe "map/2" do
    test "maps" do
      result =
        [1, 2, 3]
        |> RailStream.map(fn x -> {:ok, x * 2} end)
        |> Enum.to_list()

      assert result == [{:ok, 2}, {:ok, 4}, {:ok, 6}]
    end

    test "only passes {:ok, things} to maps" do
      result =
        [{:ok, 1}, {:error, :whatever}, {:ok, 3}]
        |> RailStream.map(&(&1 * 2))
        |> Enum.to_list()

      assert result == [{:ok, 2}, {:error, :whatever}, {:ok, 6}]
    end
  end

  describe "reject/2" do
    test "drops items where passed in function returns true" do
      require Integer

      result =
        [{:ok, 2}, {:ok, 4}, {:ok, 3}, {:error, :whatever}]
        |> RailStream.reject(&Integer.is_even/1)
        |> Enum.to_list()

      assert result == [{:ok, 3}, {:error, :whatever}]
    end
  end
end
