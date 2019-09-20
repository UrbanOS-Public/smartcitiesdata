defmodule Forklift.UtilTest do
  use ExUnit.Case

  describe "chunk_by_byte_size" do
    test "will create chunks that are less then suppliec chunk_byte_size" do
      chunks =
        ?a..?z
        |> Enum.map(&List.to_string([&1]))
        |> Forklift.Util.chunk_by_byte_size(10)

      assert length(chunks) == 3
      assert Enum.at(chunks, 0) == ?a..?i |> Enum.map(&List.to_string([&1]))
      assert Enum.at(chunks, 1) == ?j..?r |> Enum.map(&List.to_string([&1]))
      assert Enum.at(chunks, 2) == ?s..?z |> Enum.map(&List.to_string([&1]))
    end
  end
end
