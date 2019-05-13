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
    allow Redix.command!(:redix, ["GET", "reaper:abcdef-12345:last_processed_index"]), return: nil
    allow Redix.command!(:redix, ["SET", "reaper:abcdef-12345:last_processed_index", 0]), return: "OK"

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

  test "payload sent to kafka" do
    dataset_id = "12345"
    start_time = DateTime.utc_now()
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id})
    payload = %{one: 1}

    # allow(Redix.command!(:redix, ["GET", "reaper:#{dataset_id}:last_processed_index"]), return: "15")
    allow(Kaffe.Producer.produce_sync(any(), any()), return: :ok)
    # allow(Redix.command!(:redix, ["SET", "reaper:#{dataset_id}:last_processed_index", 16]), return: "OK")

    result = Loader.load(payload, reaper_config, start_time)

    assert_called Kaffe.Producer.produce_sync(any(), any())
    json_data = capture(Kaffe.Producer.produce_sync(any(), any()), 2)
    {:ok, data} = SmartCity.Data.new(json_data)

    # assert_called Redix.command!(:redix, ["SET", "reaper:#{dataset_id}:last_processed_index", 16])

    assert payload == data.payload
    assert result == :ok
  end

  test "error sending payload to kafka" do
    dataset_id = "12345"
    start_time = DateTime.utc_now()
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id})
    payload = %{one: 1}
    expected_error = "Error sending payload to kafka."

    allow(Redix.command!(:redix, ["GET", "reaper:#{dataset_id}:last_processed_index"]), return: "15")
    allow(Kaffe.Producer.produce_sync(any(), any()), return: {:error, expected_error})
    allow(Redix.command!(:redix, ["SET", any(), any()]), return: "OK")

    result = Loader.load(payload, reaper_config, start_time)

    assert_called Kaffe.Producer.produce_sync(any(), any())
    assert result == {:error, expected_error}
  end

  test "load returns error tuple when it cannot create a Data struct" do
    allow(SmartCity.Data.new(any()), return: {:error, "Bad stuff happened"})
    allow Redix.command!(:redix, ["GET", "reaper:123:last_processed_index"]), return: nil

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
    allow Redix.command!(:redix, ["GET", "reaper:123:last_processed_index"]), return: nil

    test_payload = %{
      payload: "as",
      a: "map"
    }

    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: "123"})

    result = Loader.load(test_payload, reaper_config, DateTime.utc_now())

    assert {:error, {:json, :bad_json}} == result
  end
end
