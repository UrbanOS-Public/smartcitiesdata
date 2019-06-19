defmodule Reaper.LoaderTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo

  import Checkov

  alias Elsa.Producer
  alias Reaper.Loader

  @endpoints Application.get_env(:reaper, :elsa_brokers)
  @output_topic_prefix Application.get_env(:reaper, :output_topic_prefix)

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

    dataset_id = "abcdef-12345"
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id})

    key = "AAAE509C7162BBE7D948D141AD2EF0F5"
    topic = "#{@output_topic_prefix}-#{dataset_id}"
    allow(Elsa.topic?(@endpoints, topic), return: true)

    expect(Producer.produce_sync(@endpoints, topic, 0, key, any()), return: expected)

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
    topic = "#{@output_topic_prefix}-#{dataset_id}"

    allow(Elsa.topic?(@endpoints, topic), return: true)
    allow(Producer.produce_sync(any(), any(), any(), any(), any()), return: :ok)

    result = Loader.load(payload, reaper_config, start_time)

    assert_called Producer.produce_sync(any(), any(), any(), any(), any())
    json_data = capture(Producer.produce_sync(any(), any(), any(), any(), any()), 5)
    {:ok, data} = SmartCity.Data.new(json_data)

    assert payload == data.payload
    assert result == :ok
  end

  test "error sending payload to kafka" do
    dataset_id = "12345"
    start_time = DateTime.utc_now()
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id})
    payload = %{one: 1}
    topic = "#{@output_topic_prefix}-#{dataset_id}"
    expected_error = "Error sending payload to kafka."

    allow(Redix.command!(:redix, ["GET", "reaper:#{dataset_id}:last_processed_index"]), return: "15")
    allow(Elsa.topic?(@endpoints, topic), return: true)
    allow(Producer.produce_sync(any(), any(), any(), any(), any()), return: {:error, expected_error})
    allow(Redix.command!(:redix, ["SET", any(), any()]), return: "OK")

    result = Loader.load(payload, reaper_config, start_time)

    assert_called Producer.produce_sync(any(), any(), any(), any(), any())
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

  test "retry logic works when topic eventually is created" do
    dataset_id = "12345"
    start_time = DateTime.utc_now()
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id})
    payload = %{one: 1}
    topic = "#{@output_topic_prefix}-#{dataset_id}"

    allow(Elsa.topic?(@endpoints, topic), seq: [false, true])
    allow(Producer.produce_sync(any(), any(), any(), any(), any()), return: :ok)

    result = Loader.load(payload, reaper_config, start_time)

    assert_called Producer.produce_sync(any(), any(), any(), any(), any()), once()
    json_data = capture(Producer.produce_sync(any(), any(), any(), any(), any()), 5)
    {:ok, data} = SmartCity.Data.new(json_data)

    assert payload == data.payload
    assert result == :ok
  end

  test "retry logic returns an error when topic never gets created" do
    dataset_id = "12345"
    start_time = DateTime.utc_now()
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id})
    payload = %{one: 1}

    allow(Elsa.topic?(@endpoints, any()), return: false)

    result = Loader.load(payload, reaper_config, start_time)

    assert {:error, _} = result
  end
end
