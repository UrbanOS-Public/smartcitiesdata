defmodule DiscoveryApi.Data.ModelTest do
  use ExUnit.Case
  use Placebo
  require Assertions
  alias DiscoveryApi.Data.{Model, Persistence}
  alias DiscoveryApi.Test.Helper

  @instance DiscoveryApi.instance()

  setup do
    Brook.Test.clear_view_state(@instance, :models)
  end

  test "get_last_updated_date/1" do
    expected_date = DateTime.utc_now()
    allow(Persistence.get(any()), return: {:last_updated_date, expected_date})

    actual_date = Model.get_last_updated_date("123")
    assert expected_date = actual_date
  end

  test "get_count_maps/1" do
    keys = ["smart_registry:queries:count:123", "smart_registry:downloads:count:123"]
    allow(Persistence.get_keys("smart_registry:*:count:123"), return: keys)
    allow(Persistence.get_many(keys), return: ["7", "9"])

    expected = %{:downloads => "9", :queries => "7"}
    actual_metrics = Model.get_count_maps("123")
    assert actual_metrics == expected
  end

  test "get/1" do
    cam_as_expected = generate_test_data("cam")

    Brook.Test.with_event(@instance, fn ->
      Brook.ViewState.merge(:models, cam_as_expected.id, cam_as_expected)
    end)

    allow(Persistence.get_many_with_keys(any()), return: get_many_with_keys_result(cam_as_expected))

    assert cam_as_expected == Model.get("cam")
  end

  test "get_all/1" do
    cam_as_expected = generate_test_data("cam")
    paul_as_expected = generate_test_data("paul")

    Brook.Test.with_event(@instance, fn ->
      Brook.ViewState.merge(:models, cam_as_expected.id, cam_as_expected)
      Brook.ViewState.merge(:models, paul_as_expected.id, paul_as_expected)
    end)

    allow(Persistence.get_many_with_keys(any()),
      return: Map.merge(get_many_with_keys_result(cam_as_expected), get_many_with_keys_result(paul_as_expected))
    )

    Assertions.assert_lists_equal([cam_as_expected, paul_as_expected], Model.get_all(["cam", "paul"]))
  end

  test "get_all/1 only returns given ids" do
    cam_as_expected = generate_test_data("cam")
    paul_as_expected = generate_test_data("paul")
    nate_as_expected = generate_test_data("nate")

    Brook.Test.with_event(@instance, fn ->
      Brook.ViewState.merge(:models, cam_as_expected.id, cam_as_expected)
      Brook.ViewState.merge(:models, paul_as_expected.id, paul_as_expected)
      Brook.ViewState.merge(:models, nate_as_expected.id, nate_as_expected)
    end)

    allow(Persistence.get_many_with_keys(any()),
      return: Map.merge(get_many_with_keys_result(cam_as_expected), get_many_with_keys_result(paul_as_expected))
    )

    Assertions.assert_lists_equal([cam_as_expected, paul_as_expected], Model.get_all(["cam", "paul"]))
  end

  test "get_all/1 does not throw error when model does not exist" do
    paul_as_expected = generate_test_data("paul")

    Brook.Test.with_event(@instance, fn ->
      Brook.ViewState.merge(:models, paul_as_expected.id, paul_as_expected)
    end)

    allow(Persistence.get_many_with_keys(any()),
      return: Map.merge(get_many_with_keys_result(nil), get_many_with_keys_result(paul_as_expected))
    )

    Assertions.assert_lists_equal([paul_as_expected], Model.get_all(["cam", "paul"]))
  end

  test "get_all/0" do
    cam_as_expected = generate_test_data("cam")
    paul_as_expected = generate_test_data("paul")

    Brook.Test.with_event(@instance, fn ->
      Brook.ViewState.merge(:models, cam_as_expected.id, cam_as_expected)
      Brook.ViewState.merge(:models, paul_as_expected.id, paul_as_expected)
    end)

    allow(Persistence.get_many_with_keys(any()),
      return: Map.merge(get_many_with_keys_result(cam_as_expected), get_many_with_keys_result(paul_as_expected))
    )

    Assertions.assert_lists_equal([cam_as_expected, paul_as_expected], Model.get_all())
  end

  defp get_many_with_keys_result(nil) do
    id = "nil_id"

    %{
      "forklift:last_insert_date:#{id}" => nil,
      "smart_registry:downloads:count:#{id}" => nil,
      "smart_registry:queries:count:#{id}" => nil,
      "discovery-api:stats:#{id}" => nil
    }
  end

  defp get_many_with_keys_result(expected_model) do
    id = expected_model.id

    %{
      "forklift:last_insert_date:#{id}" => expected_model.lastUpdatedDate,
      "smart_registry:downloads:count:#{id}" => expected_model.downloads,
      "smart_registry:queries:count:#{id}" => expected_model.queries,
      "discovery-api:stats:#{id}" => expected_model.completeness
    }
  end

  defp generate_test_data(name) do
    [x, y, z] = Stream.repeatedly(&:rand.uniform/0) |> Enum.take(3)

    %{id: name}
    |> Helper.sample_model()
    |> Map.merge(%{completeness: %{completeness: x}, downloads: y, queries: z, lastUpdatedDate: DateTime.utc_now()})
  end
end
