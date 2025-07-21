defmodule Destination.ContextComprehensiveTest do
  use ExUnit.Case, async: true

  alias Destination.Context

  defmodule SimpleDictionary do
    defstruct [:name, :version]
  end

  defmodule TestSchemaSimple do
    use Definition.Schema

    def s do
      schema(%{
        dictionary: spec(is_struct(SimpleDictionary)),
        app_name: spec(is_atom() or is_binary()),
        dataset_id: is_binary() |> not_empty() |> required(),
        subset_id: is_binary() |> not_empty() |> required()
      })
    end
  end

  defmodule ComplexDictionary do
    defstruct [:id, :name, :fields, :metadata]
  end

  describe "Context Creation Tests" do
    test "successful context creation with all required fields" do
      params = %{
        dictionary: %SimpleDictionary{name: "test_dict", version: "1.0"},
        app_name: "test_app",
        dataset_id: "test_dataset_123",
        subset_id: "test_subset_001"
      }

      assert {:ok, context} = Context.new(params, TestSchemaSimple)
      assert %Context{} = context
      assert context.dictionary.name == "test_dict"
      assert context.app_name == "test_app"
      assert context.dataset_id == "test_dataset_123"
      assert context.subset_id == "test_subset_001"
    end

    test "context creation with atom app_name" do
      params = %{
        dictionary: %SimpleDictionary{name: "test_dict"},
        app_name: :test_app_atom,
        dataset_id: "test_dataset",
        subset_id: "test_subset"
      }

      assert {:ok, context} = Context.new(params, TestSchemaSimple)
      assert context.app_name == :test_app_atom
    end

    test "context creation with string app_name" do
      params = %{
        dictionary: %SimpleDictionary{name: "test_dict"},
        app_name: "test_app_string",
        dataset_id: "test_dataset",
        subset_id: "test_subset"
      }

      assert {:ok, context} = Context.new(params, TestSchemaSimple)
      assert context.app_name == "test_app_string"
    end
  end

  describe "Context Validation Failure Tests" do
    test "missing dictionary field" do
      params = %{
        app_name: "test_app",
        dataset_id: "test_dataset",
        subset_id: "test_subset"
      }

      assert {:error, errors} = Context.new(params, TestSchemaSimple)
      assert Keyword.has_key?(errors, :dictionary)
    end

    test "missing dataset_id field" do
      params = %{
        dictionary: %SimpleDictionary{name: "test"},
        app_name: "test_app",
        subset_id: "test_subset"
      }

      assert {:error, errors} = Context.new(params, TestSchemaSimple)
      assert Keyword.has_key?(errors, :dataset_id)
    end

    test "missing subset_id field" do
      params = %{
        dictionary: %SimpleDictionary{name: "test"},
        app_name: "test_app",
        dataset_id: "test_dataset"
      }

      assert {:error, errors} = Context.new(params, TestSchemaSimple)
      assert Keyword.has_key?(errors, :subset_id)
    end

    test "invalid app_name type (neither atom nor string)" do
      params = %{
        dictionary: %SimpleDictionary{name: "test"},
        app_name: 123,
        dataset_id: "test_dataset",
        subset_id: "test_subset"
      }

      assert {:error, errors} = Context.new(params, TestSchemaSimple)
      assert Keyword.has_key?(errors, :app_name)
    end

    test "empty dataset_id string" do
      params = %{
        dictionary: %SimpleDictionary{name: "test"},
        app_name: "test_app",
        dataset_id: "",
        subset_id: "test_subset"
      }

      assert {:error, errors} = Context.new(params, TestSchemaSimple)
      assert Keyword.has_key?(errors, :dataset_id)
    end

    test "empty subset_id string" do
      params = %{
        dictionary: %SimpleDictionary{name: "test"},
        app_name: "test_app",
        dataset_id: "test_dataset",
        subset_id: ""
      }

      assert {:error, errors} = Context.new(params, TestSchemaSimple)
      assert Keyword.has_key?(errors, :subset_id)
    end
  end

  describe "Context Edge Cases" do
    test "nil values in optional fields are allowed" do
      params = %{
        dictionary: %SimpleDictionary{name: "test"},
        app_name: nil,
        dataset_id: "test_dataset",
        subset_id: "test_subset"
      }

      assert {:ok, context} = Context.new(params, TestSchemaSimple)
      assert context.app_name == nil
    end

    test "empty string in app_name is allowed" do
      params = %{
        dictionary: %SimpleDictionary{name: "test"},
        app_name: "",
        dataset_id: "test_dataset",
        subset_id: "test_subset"
      }

      assert {:ok, context} = Context.new(params, TestSchemaSimple)
      assert context.app_name == ""
    end

    test "struct with wrong field type is rejected" do
      params = %{
        dictionary: "not_a_dictionary_struct",
        app_name: "test_app",
        dictionary_id: "test_dict_id",
        subset_id: "test_subset"
      }

      assert {:error, _} = Context.new(params, TestSchemaSimple)
    end
  end

  describe "Context Struct Properties" do
    test "struct definition contains required fields" do
      struct = %Context{}
      keys = Map.keys(struct)
      required_keys = [:__struct__, :dictionary, :app_name, :dataset_id, :subset_id]
      
      for key <- required_keys do
        assert key in keys, "Key #{key} must be present in struct"
      end
    end

    test "struct default values are nil" do
      struct = %Context{}
      assert struct.dictionary == nil
      assert struct.app_name == nil
      assert struct.dataset_id == nil
      assert struct.subset_id == nil
    end

    test "struct type specification" do
      assert %Context{}.dictionary == nil
      assert %Context{}.app_name == nil
      assert %Context{}.dataset_id == nil
      assert %Context{}.subset_id == nil
    end
  end

  describe "Complex Context Creation" do
    test "large dictionary values work correctly" do
      complex_dict = %ComplexDictionary{
        id: "dict-#{System.unique_integer()}",
        name: "Complex Dict #{String.duplicate("data", 500)}",
        fields: Enum.map(1..100, fn i -> "field_#{i}" end),
        metadata: %{count: 1000, version: "2.1", tags: ["test", "dictionary"]}
      }

      params = %{
        dictionary: complex_dict,
        app_name: :test_large_app,
        dataset_id: "dataset-#{System.unique_integer()}",
        subset_id: "subset-#{System.unique_integer()}"
      }

      assert {:ok, context} = Context.new(params, TestSchemaSimple)
      assert context.dictionary == complex_dict
    end
  end
end