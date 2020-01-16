defmodule DiscoveryApi.Schemas.GeneratorsTest do
  use ExUnit.Case
  alias DiscoveryApi.Schemas.Generators

  describe "generate_public_id/1" do
    test "size can be overridden" do
      assert 2 |> Generators.generate_public_id() |> String.length() == 2
    end
  end
end
