defmodule Dictionary.AccessTest do
  use ExUnit.Case
  import Checkov

  import Dictionary.Access, only: [key: 1, key: 3]

  setup do
    dictionary =
      Dictionary.from_list([
        Dictionary.Type.String.new!(name: "name"),
        Dictionary.Type.Integer.new!(name: "age"),
        Dictionary.Type.Date.new!(name: "birthdate", format: "%Y-%m-%d"),
        Dictionary.Type.Map.new!(
          name: "spouse",
          dictionary: [
            Dictionary.Type.String.new!(name: "name"),
            Dictionary.Type.Integer.new!(name: "age"),
            Dictionary.Type.String.new!(name: "nickname")
          ]
        ),
        Dictionary.Type.List.new!(
          name: "friends",
          item_type:
            Dictionary.Type.Map.new!(
              name: "in_list",
              dictionary: [
                Dictionary.Type.String.new!(name: "name"),
                Dictionary.Type.Integer.new!(name: "age"),
                Dictionary.Type.Integer.new!(name: "since")
              ]
            )
        )
      ])

    data = %{
      "name" => "Gary",
      "age" => 34,
      "birthdate" => Date.new(2001, 01, 10) |> elem(1) |> Date.to_iso8601(),
      "spouse" => %{
        "name" => "Jennifer",
        "age" => 32,
        "nickname" => "Jenny"
      },
      "friends" => [
        %{"name" => "Fred", "age" => 40},
        %{"name" => "John", "age" => 30}
      ]
    }

    [dictionary: dictionary, data: data]
  end

  describe "put_in" do
    data_test "can add fields to dictionary", %{dictionary: dictionary} do
      keyed_path = Enum.map(path, &key/1)
      result = put_in(dictionary, keyed_path, value)
      assert value == get_in(result, keyed_path)

      where [
        [:path, :value],
        [["hair"], Dictionary.Type.String.new!(name: "hair")],
        [["spouse", "hair"], Dictionary.Type.String.new!(name: "hair")],
        [["friends", "hair"], Dictionary.Type.String.new!(name: "hair")]
      ]
    end

    data_test "can add fields to raw datastructures", %{data: data} do
      keyed_path = Enum.map(path, &key(&1, nil, opts))
      result = put_in(data, keyed_path, value)
      assert expected == get_in(result, keyed_path)

      where [
        [:path, :value, :expected, :opts],
        [["hair"], "red", "red", []],
        [["spouse", "hair"], "gray", "gray", []],
        [["friends", "hair"], "blue", ["blue", "blue"], []],
        [["friends", "hair"], ["red", "green"], [["red", "green"], ["red", "green"]], []],
        [["friends", "hair"], ["red", "green"], ["red", "green"], [spread: true]]
      ]
    end
  end

  describe "pop_in" do
    data_test "can remove field from dictionary", %{dictionary: dictionary} do
      keyed_path = Enum.map(path, &key/1)
      {popped, result} = pop_in(dictionary, keyed_path)
      assert popped == Dictionary.Type.Integer.new!(name: "age")
      assert nil == get_in(result, keyed_path)

      where [
        [:path],
        [["age"]],
        [["spouse", "age"]],
        [["friends", "age"]]
      ]
    end

    data_test "can remove fields from raw datastructures", %{data: data} do
      keyed_path = Enum.map(path, &key/1)
      {popped, result} = pop_in(data, keyed_path)
      assert popped == expected_popped
      assert get_in(result, keyed_path) == expected

      where [
        [:path, :expected_popped, :expected],
        [["age"], 34, nil],
        [["spouse", "age"], 32, nil],
        [["friends", "age"], [40, 30], [nil, nil]]
      ]
    end
  end

  describe "get_and_update_in" do
    data_test "can retrieve and update fields in dictionary", %{dictionary: dictionary} do
      keyed_path = Enum.map(path, &key/1)
      {get, update} = get_and_update_in(dictionary, keyed_path, function)
      assert expected_get == get
      assert expected_update == get_in(update, keyed_path)

      where [
        [:path, :function, :expected_get, :expected_update],
        [
          ["age"],
          fn a -> {a, Dictionary.Type.String.new!(name: "age")} end,
          Dictionary.Type.Integer.new!(name: "age"),
          Dictionary.Type.String.new!(name: "age")
        ],
        [
          ["spouse", "age"],
          fn a -> {a, Dictionary.Type.String.new!(name: "age")} end,
          Dictionary.Type.Integer.new!(name: "age"),
          Dictionary.Type.String.new!(name: "age")
        ],
        [
          ["friends", "age"],
          fn a -> {a, Dictionary.Type.String.new!(name: "age")} end,
          Dictionary.Type.Integer.new!(name: "age"),
          Dictionary.Type.String.new!(name: "age")
        ]
      ]
    end

    data_test "can retrieve and update raw datastructures", %{data: data} do
      keyed_path = Enum.map(path, &key/1)
      {get, update} = get_and_update_in(data, keyed_path, function)
      assert expected_get == get
      assert expected_update == get_in(update, keyed_path)

      where [
        [:path, :function, :expected_get, :expected_update],
        [["age"], fn a -> {a - 10, a + 10} end, 24, 44],
        [["spouse", "age"], fn a -> {a - 10, a + 10} end, 22, 42],
        [["friends", "age"], fn a -> {a - 10, a + 10} end, [30, 20], [50, 40]]
      ]
    end
  end

  describe "udpate_in" do
    data_test "can update fields in dictionary", %{dictionary: dictionary} do
      keyed_path = Enum.map(path, &key/1)
      keyed_updated_path = Enum.map(updated_path, &key/1)
      result = update_in(dictionary, keyed_path, update_function)
      assert expected == get_in(result, keyed_updated_path)

      where [
        [:path, :updated_path, :update_function, :expected],
        [
          ["age"],
          ["years_alive"],
          fn v -> Map.put(v, :name, "years_alive") end,
          Dictionary.Type.Integer.new!(name: "years_alive")
        ],
        [
          ["spouse", "nickname"],
          ["spouse", "goofy name"],
          fn v -> Map.put(v, :name, "goofy name") end,
          Dictionary.Type.String.new!(name: "goofy name")
        ],
        [
          ["friends", "since"],
          ["friends", "year"],
          fn v -> Map.put(v, :name, "year") end,
          Dictionary.Type.Integer.new!(name: "year")
        ]
      ]
    end

    data_test "can update values in raw datastructures", %{data: data} do
      keyed_path = Enum.map(path, &key/1)
      result = update_in(data, keyed_path, update_function)
      assert expected == get_in(result, keyed_path)

      where [
        [:path, :update_function, :expected],
        [["age"], fn _ -> 13 end, 13],
        [["spouse", "nickname"], &String.upcase/1, "JENNY"],
        [["friends", "name"], &String.upcase/1, ["FRED", "JOHN"]]
      ]
    end
  end

  describe "get_in" do
    data_test "can access fields in dictionary", %{dictionary: dictionary} do
      keyed_path = Enum.map(path, &key/1)
      result = get_in(dictionary, keyed_path)
      assert result == expected

      where [
        [:path, :expected],
        [["age"], Dictionary.Type.Integer.new!(name: "age")],
        [["spouse", "nickname"], Dictionary.Type.String.new!(name: "nickname")],
        [["friends", "since"], Dictionary.Type.Integer.new!(name: "since")]
      ]
    end

    data_test "can access values in raw datastructures", %{data: data} do
      keyed_path = Enum.map(path, &key/1)
      result = get_in(data, keyed_path)
      assert result == expected

      where [
        [:path, :expected],
        [["age"], 34],
        [["spouse", "nickname"], "Jenny"],
        [["friends", "name"], ["Fred", "John"]]
      ]
    end
  end
end
