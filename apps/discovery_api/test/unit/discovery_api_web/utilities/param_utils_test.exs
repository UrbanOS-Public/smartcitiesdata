defmodule DiscoveryApiWeb.Utilities.ParamUtilsTest do
  use ExUnit.Case
  alias DiscoveryApiWeb.Utilities.ParamUtils

  describe "safely_parse_int" do
    test "returns default when non-valid int passed as string" do
      assert 0 == ParamUtils.safely_parse_int("BAD")
    end

    test "returns passed in default value" do
      assert 23 == ParamUtils.safely_parse_int("BAAAAD", 23)
    end

    test "returns default when string is empty" do
      assert 0 == ParamUtils.safely_parse_int("")
    end

    test "returns valid int from int" do
      assert 70 == ParamUtils.safely_parse_int(70)
    end

    test "returns valid int from string" do
      assert 42 == ParamUtils.safely_parse_int("42")
    end
  end
end
