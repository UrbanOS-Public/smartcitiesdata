defmodule DiscoveryApi.Data.ModelTest do
  use ExUnit.Case
  import Mox
  require Assertions
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

  @instance_name DiscoveryApi.instance_name()

  setup :verify_on_exit!

  setup do
    Brook.Test.clear_view_state(@instance_name, :models)
  end

  test "get_count_maps/1" do
    keys = ["smart_registry:queries:count:123", "smart_registry:downloads:count:123"]
    
    expect(PersistenceMock, :get_keys, fn "smart_registry:*:count:123" -> keys end)
    expect(PersistenceMock, :get_many, fn ^keys -> ["7", "9"] end)

    expected = %{:downloads => "9", :queries => "7"}
    actual_metrics = Model.get_count_maps("123")
    assert actual_metrics == expected
  end

  test "get/1" do
    cam_as_expected = generate_test_data("cam")

    Brook.Test.with_event(@instance_name, fn ->
      Brook.ViewState.merge(:models, cam_as_expected.id, cam_as_expected)
    end)

    expect(PersistenceMock, :get_many_with_keys, fn _keys -> get_many_with_keys_result(cam_as_expected) end)

    assert cam_as_expected == Model.get("cam")
  end

  test "get_all/1" do
    cam_as_expected = generate_test_data("cam")
    paul_as_expected = generate_test_data("paul")

    Brook.Test.with_event(@instance_name, fn ->
      Brook.ViewState.merge(:models, cam_as_expected.id, cam_as_expected)
      Brook.ViewState.merge(:models, paul_as_expected.id, paul_as_expected)
    end)

    expect(PersistenceMock, :get_many_with_keys, fn _keys -> 
      Map.merge(get_many_with_keys_result(cam_as_expected), get_many_with_keys_result(paul_as_expected))
    end)

    Assertions.assert_lists_equal([cam_as_expected, paul_as_expected], Model.get_all(["cam", "paul"]))
  end

  test "get_all/1 only returns given ids" do
    cam_as_expected = generate_test_data("cam")
    paul_as_expected = generate_test_data("paul")
    nate_as_expected = generate_test_data("nate")

    Brook.Test.with_event(@instance_name, fn ->
      Brook.ViewState.merge(:models, cam_as_expected.id, cam_as_expected)
      Brook.ViewState.merge(:models, paul_as_expected.id, paul_as_expected)
      Brook.ViewState.merge(:models, nate_as_expected.id, nate_as_expected)
    end)

    expect(PersistenceMock, :get_many_with_keys, fn _keys -> 
      Map.merge(get_many_with_keys_result(cam_as_expected), get_many_with_keys_result(paul_as_expected))
    end)

    Assertions.assert_lists_equal([cam_as_expected, paul_as_expected], Model.get_all(["cam", "paul"]))
  end

  test "get_all/1 does not throw error when model does not exist" do
    paul_as_expected = generate_test_data("paul")

    Brook.Test.with_event(@instance_name, fn ->
      Brook.ViewState.merge(:models, paul_as_expected.id, paul_as_expected)
    end)

    expect(PersistenceMock, :get_many_with_keys, fn _keys -> 
      Map.merge(get_many_with_keys_result(nil), get_many_with_keys_result(paul_as_expected))
    end)

    Assertions.assert_lists_equal([paul_as_expected], Model.get_all(["cam", "paul"]))
  end

  test "get_all/0" do
    cam_as_expected = generate_test_data("cam")
    paul_as_expected = generate_test_data("paul")

    Brook.Test.with_event(@instance_name, fn ->
      Brook.ViewState.merge(:models, cam_as_expected.id, cam_as_expected)
      Brook.ViewState.merge(:models, paul_as_expected.id, paul_as_expected)
    end)

    expect(PersistenceMock, :get_many_with_keys, fn _keys -> 
      Map.merge(get_many_with_keys_result(cam_as_expected), get_many_with_keys_result(paul_as_expected))
    end)

    Assertions.assert_lists_equal([cam_as_expected, paul_as_expected], Model.get_all())
  end

  test "remote?/0 returns true if remote" do
    subject = generate_test_data("cam", %{sourceType: "remote"})

    assert Model.remote?(subject) == true
  end

  test "remote?/0 returns false if not remote" do
    subject = generate_test_data("cam", %{sourceType: "ingest"})

    assert Model.remote?(subject) == false
  end

  describe "to_table_info/1" do
    test "creates table info object with id and description fields" do
      model =
        Helper.sample_model(%{
          id: "dataset-id-blah",
          title: "dataset-title-blah",
          schema: [
            %{
              name: "cam",
              type: "cam"
            }
          ]
        })

      expected_table_info = %{
        id: "dataset_id_blah",
        description: model.id,
        alias: model.title,
        columns: [
          %{id: "cam", description: "cam", dataType: "cam"}
        ]
      }

      assert Model.to_table_info(model) == expected_table_info
    end

    test "converts schema to list of column definitions" do
      model = Helper.sample_model()

      expected_columns = [
        %{
          dataType: "integer",
          description: "number",
          id: "number"
        },
        %{
          dataType: "string",
          description: "name",
          id: "name"
        }
      ]

      actual_columns = model |> Model.to_table_info() |> Map.get(:columns)
      assert actual_columns == expected_columns
    end

    test "converts mixed case schema fields by converting to a safe id and downcasing the description" do
      model =
        Helper.sample_model(%{
          schema: [
            %{
              name: "bob-Field",
              type: "string"
            }
          ]
        })

      expected_columns = [
        %{
          dataType: "string",
          description: "bob-field",
          id: "bob_field"
        }
      ]

      actual_columns = model |> Model.to_table_info() |> Map.get(:columns)
      assert actual_columns == expected_columns
    end
  end

  defp get_many_with_keys_result(nil) do
    id = "nil_id"

    %{
      "smart_registry:downloads:count:#{id}" => nil,
      "smart_registry:queries:count:#{id}" => nil,
      "discovery-api:stats:#{id}" => nil
    }
  end

  defp get_many_with_keys_result(expected_model) do
    id = expected_model.id

    %{
      "smart_registry:downloads:count:#{id}" => expected_model.downloads,
      "smart_registry:queries:count:#{id}" => expected_model.queries,
      "discovery-api:stats:#{id}" => expected_model.completeness
    }
  end

  defp generate_test_data(name, overrides \\ %{}) do
    [x, y, z] = Stream.repeatedly(&:rand.uniform/0) |> Enum.take(3)

    %{id: name}
    |> Map.merge(overrides)
    |> Helper.sample_model()
    |> Map.merge(%{completeness: %{completeness: x}, downloads: y, queries: z})
  end
end
