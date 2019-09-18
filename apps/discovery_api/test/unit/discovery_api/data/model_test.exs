defmodule DiscoveryApi.Data.ModelTest do
  use ExUnit.Case
  use Placebo
  require Assertions
  alias DiscoveryApi.Data.{Model, Persistence}
  alias DiscoveryApi.Test.Helper

  test "save/1" do
    dataset = Helper.sample_model() |> Map.put(:keywords, nil)
    allow(Persistence.persist(any(), any()), return: {:ok, "good"})

    Model.save(dataset)

    %{keywords: actual_keywords} = capture(Persistence.persist(any(), any()), 2)

    assert [] == actual_keywords
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
    {_cam, cam_as_json, cam_as_expected} = generate_test_data("cam")

    allow Persistence.get("discovery-api:model:cam"), return: cam_as_json

    allow Persistence.get_many_with_keys(any()), return: get_many_with_keys_result(cam_as_expected)

    assert cam_as_expected == Model.get("cam")
  end

  test "get_all/1" do
    {_cam, cam_as_json, cam_as_expected} = generate_test_data("cam")
    {_paul, paul_as_json, paul_as_expected} = generate_test_data("paul")

    allow Persistence.get_many(["discovery-api:model:cam", "discovery-api:model:paul"], true), return: [cam_as_json, paul_as_json]

    allow Persistence.get_many_with_keys(any()),
      return: Map.merge(get_many_with_keys_result(cam_as_expected), get_many_with_keys_result(paul_as_expected))

    Assertions.assert_lists_equal([cam_as_expected, paul_as_expected], Model.get_all(["cam", "paul"]))
  end

  test "get_all/1 does not throw error when model has been deleted from redis" do
    {_paul, paul_as_json, paul_as_expected} = generate_test_data("paul")

    allow Persistence.get_many(any(), true), return: [paul_as_json]

    allow Persistence.get_many_with_keys(any()),
      return: Map.merge(get_many_with_keys_result(nil), get_many_with_keys_result(paul_as_expected))

    Assertions.assert_lists_equal([paul_as_expected], Model.get_all(["cam", "paul"]))
  end

  test "get_all/0" do
    {_cam, cam_as_json, cam_as_expected} = generate_test_data("cam")

    allow Persistence.get_all("discovery-api:model:*"), return: [cam_as_json]

    allow Persistence.get_many_with_keys(any()),
      return: get_many_with_keys_result(cam_as_expected)

    Assertions.assert_lists_equal([cam_as_expected], Model.get_all())
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
    model = Helper.sample_model(%{id: name})
    model_as_json = model |> Map.from_struct() |> Jason.encode!()

    [x, y, z] = Stream.repeatedly(&:rand.uniform/0) |> Enum.take(3)

    expected_model = Map.merge(model, %{completeness: %{completeness: x}, downloads: y, queries: z, lastUpdatedDate: DateTime.utc_now()})

    {model, model_as_json, expected_model}
  end
end
