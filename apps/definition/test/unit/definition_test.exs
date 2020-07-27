defmodule DefinitionTest do
  use ExUnit.Case
  use Placebo

  defmodule Foo do
    use Definition, schema: Foo.V2
    defstruct [:version, :id, :bar, :baz]

    def on_new(foo) do
      new_baz =
        case foo.baz do
          nil -> nil
          x -> String.upcase(x)
        end

      %{foo | baz: new_baz}
      |> Ok.ok()
    end

    def migrate(%__MODULE__{version: 1} = old) do
      new_id = if Map.has_key?(old, :id), do: old.id, else: "fake_id"

      struct(__MODULE__, %{version: 2, id: new_id, bar: String.to_integer(old.bar)})
      |> Ok.ok()
    end

    defmodule V1 do
      use Definition.Schema

      def s do
        schema(%Foo{
          version: spec(fn v -> v == 1 end),
          bar: spec(is_binary())
        })
      end
    end

    defmodule V2 do
      use Definition.Schema

      def s do
        schema(%Foo{
          version: spec(fn v -> v == 2 end),
          id: required_string(),
          bar: spec(is_integer())
        })
      end
    end
  end

  describe "__using__/1" do
    setup do
      fake_uuid = "fake_uuid"
      allow(UUID.uuid4(), return: fake_uuid)
      {:ok, [fake_uuid: fake_uuid]}
    end

    test "generates an id if not present on input", %{fake_uuid: fake_uuid} do
      input = %{version: 2, bar: 9001}
      assert {:ok, %Foo{version: 2, id: ^fake_uuid, bar: 9001, baz: nil}} = Foo.new(input)
    end

    test "preserves an id if one is given" do
      input = %{version: 2, id: "my id", bar: 9001}
      assert {:ok, %Foo{version: 2, id: "my id", bar: 9001, baz: nil}} = Foo.new(input)
    end

    test "makes new/1 available to create struct" do
      input = %{version: 2, bar: 9001}
      assert {:ok, %Foo{}} = Foo.new(input)
    end

    test "makes migrate/1 overridable to migrate schema versions" do
      input = %{version: 1, bar: "42"}
      assert {:ok, %Foo{version: 2, bar: 42}} = Foo.new(input)
    end

    test "makes schema/0 available to get current version schema" do
      assert Foo.schema() == Foo.V2.s()
    end
  end

  describe "new/1" do
    test "handles input with string keys" do
      input = %{"version" => 2, "bar" => 33}
      assert {:ok, %Foo{version: 2, bar: 33}} = Foo.new(input)
    end

    test "accepts a Keyword list input" do
      assert {:ok, %Foo{bar: 42}} = Foo.new(version: 2, bar: 42)
    end

    test "calls on_new to allow custom transformation" do
      input = %{"version" => 2, "bar" => 34, "baz" => "mike"}
      assert {:ok, %Foo{baz: "MIKE"}} = Foo.new(input)
    end

    test "returns exception for other list input" do
      assert {:error, %Foo.InputError{} = ex} = Foo.new([:foo])
      assert ex.message == [:foo]
    end
  end

  describe "from_json/1" do
    test "turns JSON into new struct" do
      input = ~s/{"version": 2, "bar": 9001}/
      assert {:ok, %Foo{bar: 9001}} = Foo.from_json(input)
    end

    test "returns error tuple for invalid JSON" do
      assert {:error, %Jason.DecodeError{}} = Foo.from_json("{a, b}")
    end

    test "returns exception for invalid new/1 input" do
      input = ~s/[{"version": 2, "bar": 0}]/
      assert {:error, %Foo.InputError{}} = Foo.from_json(input)
    end
  end
end
