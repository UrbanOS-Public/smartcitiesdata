
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
        dictionary: of_struct(Destination.ContextTest.MockDictionary),
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
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }

    assert {:error, [dictionary: ["is required"]]} = Context.new(params, MockSchema)
  end

  test "new/2 with invalid app_name" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: 123,
      dataset_id: "test_dataset",
      subset_id: "test_subset"
    }

    assert {:error, [app_name: ["is invalid"]]} = Context.new(params, MockSchema)
  end

  test "new/2 with missing dataset_id" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: "test_app",
      subset_id: "test_subset"
    }

    assert {:error, [dataset_id: ["is required"]]} = Context.new(params, MockSchema)
  end

  test "new/2 with missing subset_id" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: "test_app",
      dataset_id: "test_dataset"
    }

    assert {:error, [subset_id: ["is required"]]} = Context.new(params, MockSchema)
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

    assert {:error, [dataset_id: ["is required"]]} = Context.new(params, MockSchema)
  end

  test "new/2 with empty string subset_id" do
    dictionary = %MockDictionary{name: "test_dictionary"}
    params = %{
      dictionary: dictionary,
      app_name: "test_app",
      dataset_id: "test_dataset",
      subset_id: ""
    }

    assert {:error, [subset_id: ["is required"]]} = Context.new(params, MockSchema)
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
    dictionary = %Dictionary.Impl{name: "test"}
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
    dictionary = %Dictionary.Impl{name: "test"}
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
    assert Keyword.has_key?(errors, :dictionary)
    assert Keyword.has_key?(errors, :dataset_id)
    assert Keyword.has_key?(errors, :subset_id)
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
    assert function_exported?(Destination, :__impl__, 2)
  end

  test "protocol callbacks specifications" do
    assert {:callback_specs, true} <- {:callback_specs, Code.get_docs(Destination, :callback_specs) != nil}
  end
end
