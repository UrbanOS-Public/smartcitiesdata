defmodule Providers.DateTest do
  use ExUnit.Case

  @default_format "{ISO:Extended}"

  describe "v1" do
    test "provides a date in ISO:Extended by default" do
      result = Providers.Date.provide("1", %{})

      assert {:ok, _timestamp} = Timex.parse(result, @default_format)
    end

    test "provides a date in given timex format" do
      format = "{YYYY}-{0M}-{0D}"

      result = Providers.Date.provide("1", %{format: format})

      assert Timex.now() |> Timex.format!(format) == result
    end

    test "provides date with given offset" do
      offset_in_days = -1

      result = Providers.Date.provide("1", %{offset_in_days: offset_in_days})

      assert offset_in_days >=
               Timex.diff(Timex.parse!(result, @default_format), Timex.now(), :day)
    end

    test "provides a date with offset applied before formatting" do
      format = "{YYYY}-{0M}-{0D}"
      offset_in_days = -1

      result = Providers.Date.provide("1", %{format: format, offset_in_days: offset_in_days})

      assert Timex.now()
             |> Timex.add(Timex.Duration.from_days(offset_in_days))
             |> Timex.format!(format) == result
    end
  end
end
