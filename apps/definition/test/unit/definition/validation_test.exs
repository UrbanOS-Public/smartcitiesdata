defmodule Definition.Schema.ValidationTest do
  use ExUnit.Case
  use ExUnitProperties
  doctest Definition.Schema.Validation

  import Definition.Schema.Validation

  describe "ts?/1" do
    test "returns true with valid ISO8601 timestamp" do
      valid = DateTime.utc_now() |> DateTime.to_iso8601()
      assert ts?(valid)
    end

    property "returns false for other inputs" do
      check all input <- term() do
        refute ts?(input)
      end
    end
  end

  describe "temporal_range?/1" do
    test "returns true with valid temporal range" do
      start = DateTime.utc_now() |> DateTime.to_iso8601()
      stop = DateTime.utc_now() |> DateTime.to_iso8601()

      assert temporal_range?([start, stop])
    end

    test "returns false for valid timestammps out of order" do
      start = DateTime.utc_now() |> DateTime.to_iso8601()
      stop = DateTime.utc_now() |> DateTime.to_iso8601()

      refute temporal_range?([stop, start])
    end

    property "returns false for other inputs" do
      check all input <- term() do
        refute temporal_range?(input)
      end
    end
  end

  describe "bbox?/1" do
    property "returns true for valid bounding box" do
      check all x <- resize(float(), 10),
                y <- resize(float(), 10) do
        assert bbox?([x, y, x, y])
        assert bbox?([x, y, x + 1, y + 1])
      end
    end

    property "returns false for invalid bounding box" do
      check all x <- resize(float(), 10),
                y <- resize(float(), 10) do
        refute bbox?([x, y, x - 1, y - 1])
      end
    end

    property "returns false for other inputs" do
      check all input <- term() do
        refute bbox?(input)
      end
    end
  end

  describe "email?/1" do
    test "returns true for valid email address" do
      assert email?("foo@bar.com")
      refute email?("@foobar.com")
    end

    property "returns false for any other input" do
      check all input <- term() do
        refute email?(input)
      end
    end
  end

  describe "empty?/1" do
    test "returns true for empty string/list/map" do
      assert empty?("")
      assert empty?([])
      assert empty?(%{})
    end

    test "returns true for string with only space characters" do
      assert empty?("    ")
      assert empty?("\t\n")
    end

    test "returns false for any other input" do
      check all input <- term(),
                input != [],
                input not in ["", "\n", "\t", " "],
                input != %{} do
        refute empty?(input)
      end
    end
  end

  describe "not_empty?/1" do
    test "returns true for non-empty strings/lists/maps" do
      assert not_empty?("foo")
      assert not_empty?(["a"])
      assert not_empty?(%{a: "foo"})
    end

    test "returns false for string with only space characters" do
      refute not_empty?("    ")
      refute not_empty?("\t\n")
    end

    property "returns true for any other input" do
      check all input <- term(),
                input != [],
                input not in ["", " ", "\t", "\n"],
                input != %{} do
        assert not_empty?(input)
      end
    end
  end

  describe "table_name?/1" do
    test "returns true for dataset and subset names separated by two underscores" do
      assert table_name?("a__b")
    end

    test "returns false for other strings" do
      refute table_name?("ab")
      refute table_name?("a__")
    end

    property "returns false for any other input" do
      check all input <- term() do
        refute table_name?(input)
      end
    end
  end

  describe "pos_integer?/1" do
    test "returns true for positive integers" do
      assert pos_integer?(1)
    end

    test "returns false for non-positive numbers" do
      refute pos_integer?(0)
      refute pos_integer?(-1)
    end

    property "returns false for any other input" do
      check all input <- term(),
                not is_integer(input) do
        refute pos_integer?(input)
      end
    end
  end

  describe "is_port?/1" do
    property "returns true for integers between 0 and 65535" do
      check all input <- integer(0..65535) do
        assert is_port?(input)
      end
    end

    property "returns false for any other input" do
      check all input <- term(),
                input not in 0..65535 do
        refute is_port?(input)
      end
    end
  end
end
