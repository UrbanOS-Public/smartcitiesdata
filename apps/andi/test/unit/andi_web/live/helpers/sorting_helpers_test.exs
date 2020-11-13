defmodule AndiWeb.Helpers.SortingHelpersTest do
  use ExUnit.Case

  alias AndiWeb.Helpers.SortingHelpers

  describe "sort_list_by_field/3" do
    test "ascending sort uses <=" do
      list = [
        %{"name" => "A", "age" => 1},
        %{"name" => "B", "age" => 2},
        %{"name" => "A", "age" => 3}
      ]

      assert [1, 3, 2] ==
               SortingHelpers.sort_list_by_field(list, "name")
               |> Enum.map(&Map.get(&1, "age"))
    end

    test "descending sort uses >=" do
      list = [
        %{"name" => "A", "age" => 1},
        %{"name" => "B", "age" => 2},
        %{"name" => "A", "age" => 3}
      ]

      assert [2, 1, 3] ==
               SortingHelpers.sort_list_by_field(list, "name", "desc")
               |> Enum.map(&Map.get(&1, "age"))
    end

    test "handles mixed datetimes and other values asc" do
      {:ok, bday_one, _} = DateTime.from_iso8601("2020-10-01T00:00:00Z")
      {:ok, bday_two, _} = DateTime.from_iso8601("2020-11-01T00:00:00Z")

      list = [
        %{"name" => "A", "birthday" => bday_one},
        %{"name" => "B", "birthday" => "Not Provided"},
        %{"name" => "C", "birthday" => bday_two},
        %{"name" => "D", "birthday" => :acceptable}
      ]

      assert ["A", "C", "D", "B"] ==
               SortingHelpers.sort_list_by_field(list, "birthday")
               |> Enum.map(&Map.get(&1, "name"))
    end

    test "handles mixed datetimes and other values desc" do
      {:ok, bday_one, _} = DateTime.from_iso8601("2020-10-01T00:00:00Z")
      {:ok, bday_two, _} = DateTime.from_iso8601("2020-11-01T00:00:00Z")

      list = [
        %{"name" => "A", "birthday" => bday_one},
        %{"name" => "B", "birthday" => "Not Provided"},
        %{"name" => "C", "birthday" => bday_two},
        %{"name" => "D", "birthday" => :acceptable}
      ]

      assert ["B", "D", "C", "A"] ==
               SortingHelpers.sort_list_by_field(list, "birthday", "desc")
               |> Enum.map(&Map.get(&1, "name"))
    end
  end
end
