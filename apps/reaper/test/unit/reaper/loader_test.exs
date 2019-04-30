defmodule Reaper.LoaderTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo

  import Checkov

  alias Kaffe.Producer
  alias Reaper.Loader

  setup do
    on_exit(fn -> unstub() end)
  end

  data_test "wraps payload and sends to kafka" do
    payload = %{
      payload: "as",
      a: "map"
    }

    start_time = DateTime.utc_now()
    start_time_iso8601 = DateTime.to_iso8601(start_time)
    allow DateTime.to_iso8601(any()), return: start_time_iso8601, meck_options: [:passthrough]

    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: "abcdef-12345"})

    key = "AAAE509C7162BBE7D948D141AD2EF0F5"

    expect(Producer.produce_sync(key, any()), return: expected)

    result = Loader.load(payload, reaper_config, start_time)

    assert result == expected

    where([
      [:expected],
      [:ok],
      [{:error, :some_reason}]
    ])
  end

  test "load returns error tuple when it cannot create a Data struct" do
    allow(SmartCity.Data.new(any()), return: {:error, "Bad stuff happened"})

    test_payload = %{
      payload: "as",
      a: "map"
    }

    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: "123"})

    result = Loader.load(test_payload, reaper_config, DateTime.utc_now())

    assert {:error, {:smart_city_data, "Bad stuff happened"}} == result
  end

  test "load returns error tuple when it cannot encode json" do
    allow Jason.encode(any()), return: {:error, :bad_json}

    test_payload = %{
      payload: "as",
      a: "map"
    }

    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: "123"})

    result = Loader.load(test_payload, reaper_config, DateTime.utc_now())

    assert {:error, {:json, :bad_json}} == result
  end
end
