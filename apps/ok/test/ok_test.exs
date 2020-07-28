defmodule OkTest do
  use ExUnit.Case

  describe "map/2" do
    test "will can transformation function on value from ok tuple" do
      assert {:ok, 10} == Ok.map({:ok, 5}, fn x -> x * 2 end)
    end

    test "will unwrap ok tuple return from function" do
      assert {:ok, 10} == Ok.map({:ok, 5}, fn x -> {:ok, x * 2} end)
    end

    test "will return error tuple if returned from function" do
      assert {:error, "bad"} == Ok.map({:ok, 5}, fn _ -> {:error, "bad"} end)
    end

    test "will pass an error through" do
      assert {:error, "reason"} == Ok.map({:error, "reason"}, fn x -> x * 2 end)
    end
  end

  describe "reduce/3" do
    test "will reduce through ok_tuples" do
      assert {:ok, 10} == Ok.reduce([1, 2, 3, 4], 0, fn x, acc -> {:ok, x + acc} end)
    end

    test "will reduce until error is returned" do
      assert {:error, "3 is a failure"} ==
               Ok.reduce([1, 2, 3, 4], 0, fn x, acc ->
                 case x do
                   3 -> {:error, "3 is a failure"}
                   _ -> {:ok, x + acc}
                 end
               end)
    end
  end

  describe "all?/1" do
    test "returns true if all entries are an ok tuple" do
      assert Ok.all?([{:ok, 1}, {:ok, 2}, {:ok, 3}])
    end

    test "returns false if any entry is an error tuple" do
      refute Ok.all?([{:ok, 1}, {:error, 2}, {:ok, 3}])
    end
  end
end
