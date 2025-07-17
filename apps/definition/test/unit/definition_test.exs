defmodule DefinitionTest do
  use ExUnit.Case
  import Mox
  require Foo

  setup :verify_on_exit!

  describe "__using__/1" do
    setup do
      fake_uuid = "fake_uuid"
      {:ok, [fake_uuid: fake_uuid]}
    end

    test "generates an id if not present on input", %{fake_uuid: fake_uuid} do
      Mox.expect(IdGeneratorMock, :uuid4, fn -> fake_uuid end)
      input = %{version: 2, bar: 9001}
      assert {:ok, %Foo{version: 2, id: ^fake_uuid, bar: 9001, baz: nil}} = Foo.new(input, IdGeneratorMock)
    end

    test "preserves an id if one is given" do
      input = %{version: 2, id: "my id", bar: 9001}
      assert {:ok, %Foo{version: 2, id: "my id", bar: 9001, baz: nil}} = Foo.new(input, IdGeneratorMock)
    end

    test "makes new/1 available to create struct" do
      expect(IdGeneratorMock, :uuid4, fn -> "generated_id" end)
      input = %{version: 2, bar: 9001}
      assert {:ok, %Foo{}} = Foo.new(input, IdGeneratorMock)
    end

    test "makes migrate/1 overridable to migrate schema versions" do
      input = %{version: 1, bar: "42"}
      expect(IdGeneratorMock, :uuid4, fn -> "generated_id" end)
      assert {:ok, %Foo{version: 2, bar: 42}} = Foo.new(input, IdGeneratorMock)
    end

    test "makes schema/0 available to get current version schema" do
      assert Foo.schema() == Foo.V2.s()
    end
  end

  describe "new/1" do
    test "handles input with string keys" do
      expect(IdGeneratorMock, :uuid4, fn -> "generated_id" end)
      input = %{"version" => 2, "bar" => 33}
      assert {:ok, %Foo{version: 2, bar: 33}} = Foo.new(input, IdGeneratorMock)
    end

    test "accepts a Keyword list input" do
      expect(IdGeneratorMock, :uuid4, fn -> "generated_id" end)
      assert {:ok, %Foo{bar: 42}} = Foo.new([version: 2, bar: 42], IdGeneratorMock)
    end

    test "calls on_new to allow custom transformation" do
      expect(IdGeneratorMock, :uuid4, fn -> "generated_id" end)
      input = %{"version" => 2, "bar" => 34, "baz" => "mike"}
      assert {:ok, %Foo{baz: "MIKE"}} = Foo.new(input, IdGeneratorMock)
    end

    test "returns exception for other list input" do
      assert {:error, %Foo.InputError{} = ex} = Foo.new([:foo], IdGeneratorMock)
      assert ex.message == [:foo]
    end
  end

  describe "from_json/1" do
    test "turns JSON into new struct" do
      expect(IdGeneratorMock, :uuid4, fn -> "generated_id" end)
      input = ~s/{"version": 2, "bar": 9001}/
      assert {:ok, %Foo{bar: 9001}} = Foo.from_json(input, IdGeneratorMock)
    end

    test "returns error tuple for invalid JSON" do
      assert {:error, %Jason.DecodeError{}} = Foo.from_json("{a, b}", IdGeneratorMock)
    end

    test "returns exception for invalid new/1 input" do
      input = ~s/[{"version": 2, "bar": 0}]/
      assert {:error, %Foo.InputError{}} = Foo.from_json(input, IdGeneratorMock)
    end
  end
end