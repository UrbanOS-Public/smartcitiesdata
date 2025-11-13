
defmodule Destination.ContextTest do
  use ExUnit.Case, async: true
  alias Destination.Context
  doctest Destination.Context

  defmodule MockDictionary do
    defstruct [:name]
  end

  defmodule MockSchema do
    use Definition.Schema

    def s do
      schema(%{
        dictionary: spec(fn
          nil -> false
          %Destination.ContextTest.MockDictionary{} -> true
          _ -> false
        end),
        app_name: spec(is_atom() or is_binary()),
        dataset_id: required_string(),
        subset_id: required_string()
      })
    end
  end

  test "new/2 with valid params" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }

    assert {:ok, %Context{
      dictionary: ^dictionary,
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }} = Context.new(params, MockSchema)
  end

  test "new/2 with missing dictionary" do
    params = %{
      dictionary: nil,
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }

    assert {:error, errors} = Context.new(params, MockSchema)
    assert Enum.any?(errors, fn error -> error.path == [:dictionary] end)
  end

  test "new/2 with invalid app_name" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: 123,
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }

    assert {:error, errors} = Context.new(params, MockSchema)
    assert Enum.any?(errors, fn error -> error.path == [:app_name] end)
  end

  test "new/2 with missing dataset_id" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: "test_app",
      dataset_id: nil,
      subset_id: "test_subset"
    }

    assert {:error, errors} = Context.new(params, MockSchema)
    assert Enum.any?(errors, fn error -> error.path == [:dataset_id] end)
  end

  test "new/2 with missing subset_id" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: nil
    }

    assert {:error, errors} = Context.new(params, MockSchema)
    assert Enum.any?(errors, fn error -> error.path == [:subset_id] end)
  end

  test "new/2 with atom app_name" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: :test_app,
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }

    assert {:ok, %Context{app_name: :test_app}} = Context.new(params, MockSchema)
  end

  test "new/2 with empty string dataset_id" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: "test_app",
      dataset_id: "",
      subset_id: "test_subset"
    }

    assert {:error, errors} = Context.new(params, MockSchema)
    assert Enum.any?(errors, fn error -> error.path == [:dataset_id] end)
  end

  test "new/2 with empty string subset_id" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: ""
    }

    assert {:error, errors} = Context.new(params, MockSchema)
    assert Enum.any?(errors, fn error -> error.path == [:subset_id] end)
  end

  test "module struct definition" do
    assert %Destination.Context{} == %Destination.Context{
             dictionary: nil,
             app_name: nil,
             dataset_id: nil,
             subset_id: nil
           }
  end
end

defmodule Destination.Context.V1Test do
  use ExUnit.Case, async: true
  alias Destination.Context.V1

  test "schema validation with valid Dictionary.Impl struct" do
    dictionary = %Dictionary.Impl{}
    params = %Destination.Context{
      dictionary: dictionary,
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }

    assert {:ok, validated} = Norm.conform(params, V1.s())
    assert validated.dictionary == dictionary
    assert validated.app_name == "test_app"
    assert validated.dataset_id == "test_dataset"
    assert validated.subset_id == "test_subset"
  end

  test "schema validation with invalid dictionary type" do
    params = %Destination.Context{
      dictionary: "invalid",
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }

    assert {:error, _} = Norm.conform(params, V1.s())
  end

  test "schema validation with atom app_name" do
    dictionary = %Dictionary.Impl{}
    params = %Destination.Context{
      dictionary: dictionary,
      app_name: :test_app,
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }

    assert {:ok, validated} = Norm.conform(params, V1.s())
    assert validated.app_name == :test_app
  end

  test "schema validation with missing required fields" do
    params = %Destination.Context{}
    assert {:error, errors} = Norm.conform(params, V1.s())
    assert Enum.any?(errors, fn error -> error.path == [:dictionary] end)
    assert Enum.any?(errors, fn error -> error.path == [:dataset_id] end)
    assert Enum.any?(errors, fn error -> error.path == [:subset_id] end)
  end
end

defmodule DestinationTest do
  use ExUnit.Case, async: true
  doctest Destination

  test "protocol implementation start_link" do
    context = %Destination.Context{
      dictionary: %{},
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }
    assert {:ok, {_t, ^context}} = Destination.start_link(%MockDestination{}, context)
  end

  test "protocol implementation write" do
    context = %Destination.Context{
      dictionary: %{},
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }
    {:ok, {server, _context}} = Destination.start_link(%MockDestination{}, context)
    messages = ["message1", "message2"]
    assert {:ok, {_t, ^messages}} = Destination.write(%MockDestination{}, server, messages)
  end

  test "protocol implementation stop" do
    context = %Destination.Context{
      dictionary: %{},
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }
    {:ok, {server, _context}} = Destination.start_link(%MockDestination{}, context)
    assert {:ok, _t} = Destination.stop(%MockDestination{}, server)
  end

  test "protocol implementation delete" do
    assert {:ok, _t} = Destination.delete(%MockDestination{})
  end

  test "protocol functions exist" do
    assert function_exported?(Destination, :__protocol__, 1)
    # __impl__/2 is deprecated in OTP 25+ and no longer exists
    # Instead verify protocol consolidation worked by checking __protocol__/1
    assert is_list(Destination.__protocol__(:functions))
  end

  test "protocol callbacks specifications" do
    # Code.get_docs/2 is deprecated in OTP 25+
    # Use Code.fetch_docs/1 instead which returns {:docs_v1, ...} tuple
    assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(Destination)
  end
end
