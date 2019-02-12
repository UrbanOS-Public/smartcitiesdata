defmodule DatasetTest do
  use ExUnit.Case

  test "New dataset struct created" do
    result = Dataset.new(%{"id" => "abcd", "operational" => 2, "business" => 3})
    assert result == {:ok, %Dataset{business: 3, id: "abcd", operational: 2}}
  end

  test "Missing key in dataset returns error tuple" do
    {error_code, _} = Dataset.new(%{"id" => 1, "business" => 3})
    assert error_code == :error
  end

  test "New dataset converts Id to strings" do
    result = Dataset.new(%{"id" => 2, "operational" => 2, "business" => 3})
    assert result == {:ok, %Dataset{business: 3, id: "2", operational: 2}}
  end

  test "Dataset passed as atoms works successfully" do
    result = Dataset.new(%{:id => 1, :operational => 2, :business => 3})
    assert result == {:ok, %Dataset{business: 3, id: "1", operational: 2}}
  end
end
