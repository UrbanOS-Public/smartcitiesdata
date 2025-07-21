defmodule Destination.ProtocolTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Destination.Context

  describe "Destination protocol validation" do
    test "requires implementation of all protocol functions" do
      assert Destination.__protocol__(:functions) == [
               start_link: 2,
               write: 3,
               stop: 2,
               delete: 1
             ]
    end

    test "protocol implementation for MockDestination" do
      assert Destination.__impl__(MockDestination, :for) == MockDestination
    end
  end

  defmodule TestDictionary do
    defstruct [:name]
  end

  defmodule TestSchema do
    use Definition.Schema

    def s do
      schema(%{
        dictionary: of_struct(TestDictionary),
        app_name: spec(is_atom() or is_binary()),
        dataset_id: required_string(),
        subset_id: required_string()
      })
    end
  end

  describe "Context creation edge cases" do
    test "handles nil values in optional fields" do
      dictionary = %TestDictionary{name: "test"}
      params = %{
        dictionary: dictionary,
        app_name: nil,
        dataset_id: "test_dataset",
        subset_id: "test_subset"
      }

      assert {:ok, %Context{app_name: nil}} = Context.new(params, TestSchema)
    end

    test "handles empty string values" do
      dictionary = %TestDictionary{name: "test"}
      params = %{
        dictionary: dictionary,
        app_name: "",
        dataset_id: "test_dataset",
        subset_id: "test_subset"
      }

      assert {:ok, %Context{app_name: ""}} = Context.new(params, TestSchema)
    end

    test "rejects struct with wrong field types" do
      params = %{
        dictionary: "not a dictionary struct",
        app_name: "test_app",
        dataset_id: "test_dataset",
        subset_id: "test_subset"
      }

      assert {:error, _} = Context.new(params, TestSchema)
    end
  end

  describe "Context struct validation" do
    test "all fields in struct" do
      assert %Context{}.__struct__ == Context
      assert Map.keys(%Context{}) == [:__struct__, :dictionary, :app_name, :dataset_id, :subset_id]
    end

    test "type definitions" do
      assert Context.t() == %Context{
               dictionary: {:parameterized, {Destination.ContextTest.MockDictionary, %{}}},
               app_name: {:parameterized, {{:union, [:string, :atom]}, %{}}},
               dataset_id: :string,
               subset_id: :string
             }
    end
  end

 describe "property-based tests" do
    property "valid parameters always create valid contexts" do
      check all app_name <- one_of([string(:alphanumeric), atom(:alphanumeric)]),
                dataset_id <- string(:alphanumeric, min_length: 1),
                subset_id <- string(:alphanumeric, min_length: 1),
                name <- string(:alphanumeric, min_length: 1) do
        dictionary = %TestDictionary{name: name}
        params = %{
          dictionary: dictionary,
          app_name: app_name,
          dataset_id: dataset_id,
          subset_id: subset_id
        }

        assert {:ok, %Context{}} = Context.new(params, TestSchema)
      end
    end

    property "invalid parameters return error tuples" do
      check all invalid_param <- one_of([
                constant(:missing_dictionary),
                constant(:invalid_app_name),
                constant(:empty_dataset_id),
                constant(:empty_subset_id)
              ]) do
        params =
          case invalid_param do
            :missing_dictionary -> %{
              app_name: "test",
              dataset_id: "test",
              subset_id: "test"
            }
            :invalid_app_name -> %{
              dictionary: %TestDictionary{name: "test"},
              app_name: 123,
              dataset_id: "test",
              subset_id: "test"
            }
            :empty_dataset_id -> %{
              dictionary: %TestDictionary{name: "test"},
              app_name: "test",
              dataset_id: "",
              subset_id: "test"
            }
            :empty_subset_id -> %{
              dictionary: %TestDictionary{name: "test"},
              app_name: "test",
              dataset_id: "test",
              subset_id: ""
            }
          end

        assert {:error, _} = Context.new(params, TestSchema)
      end
    end
  end

  describe "Destination protocol consistency" do
    test "callback specs match protocol functions" do
      callbacks = Destination.__protocol__(:callbacks)
      assert length(callbacks) == 4
      
      Enum.each(callbacks, fn {fun, arity} ->
        assert fun in [:start_link, :write, :stop, :delete]
        assert arity in [1, 2, 3]
      end)
    end

    test "all functions are implemented in mock" do
      assert {:ok, _} = Destination.start_link(%MockDestination{}, %Context{})
      assert {:ok, _} = Destination.write(%MockDestination{}, nil, [])
      assert {:ok, _} = Destination.stop(%MockDestination{}, nil)
      assert {:ok, _} = Destination.delete(%MockDestination{})
    end
  end
end