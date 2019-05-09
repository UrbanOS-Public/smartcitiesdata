defmodule Reaper.DataFeedTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.{Cache, DataFeed, Persistence}

  @dataset_id "12345-6789"
  @cache_name String.to_atom("#{@dataset_id}_feed")

  @csv """
  one,two,three
  four,five,six
  """

  setup do
    bypass = Bypass.open()
    Cachex.start_link(@cache_name)

    Bypass.expect(bypass, "HEAD", "/api/csv", fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    Bypass.expect(bypass, "GET", "/api/csv", fn conn ->
      Plug.Conn.resp(conn, 200, @csv)
    end)

    config =
      FixtureHelper.new_reaper_config(%{
        dataset_id: @dataset_id,
        sourceType: "batch",
        sourceFormat: "csv",
        sourceUrl: "http://localhost:#{bypass.port}/api/csv",
        cadence: 100,
        schema: [
          %{name: "a", type: "string"},
          %{name: "b", type: "string"},
          %{name: "c", type: "string"}
        ]
      })

    [bypass: bypass, config: config]
  end

  describe "process/2 happy path" do
    setup do
      allow Kaffe.Producer.produce_sync(any(), any()), return: :ok
      allow Persistence.record_last_fetched_timestamp(any(), any()), return: :ok

      :ok
    end

    test "parses turns csv into data messages and sends to kafka", %{config: config} do
      DataFeed.process(config, @cache_name)

      {:ok, data1} = SmartCity.Data.new(capture(1, Kaffe.Producer.produce_sync(any(), any()), 2))
      assert %{a: "one", b: "two", c: "three"} == data1.payload
      {:ok, data2} = SmartCity.Data.new(capture(2, Kaffe.Producer.produce_sync(any(), any()), 2))
      assert %{a: "four", b: "five", c: "six"} == data2.payload
    end

    test "eliminates duplicates before sending to kafka", %{config: config} do
      Cache.cache(@cache_name, %{a: "one", b: "two", c: "three"})

      DataFeed.process(config, @cache_name)

      {:ok, data} = SmartCity.Data.new(capture(1, Kaffe.Producer.produce_sync(any(), any()), 2))
      assert %{a: "four", b: "five", c: "six"} == data.payload
      assert_called Kaffe.Producer.produce_sync(any(), any()), once()
    end
  end

  test "process/2 should remove file for dataset regardless of error being raised", %{config: config} do
    allow Reaper.Cache.mark_duplicates(any(), any()), exec: fn _, _ -> raise "some error" end

    assert_raise RuntimeError, fn ->
      DataFeed.process(config, @cache_name)
    end

    assert false == File.exists?(config.dataset_id)
  end

  test "process/2 should not record last fetched time if all records are errors", %{config: config} do
    allow Kaffe.Producer.produce_sync(any(), any()), return: {:error, :some_kafka_error}
    allow Persistence.record_last_fetched_timestamp(any(), any()), return: :ok
    allow Yeet.process_dead_letter(any(), any(), any(), any()), return: :yeet

    DataFeed.process(config, @cache_name)

    refute_called Persistence.record_last_fetched_timestamp(any(), any())
  end

  test "process/2 yeets errors", %{config: config} do
    allow Kaffe.Producer.produce_sync(any(), any()), seq: [:ok, {:error, :kafka_test_error}]
    allow Persistence.record_last_fetched_timestamp(any(), any()), return: :ok
    allow Yeet.process_dead_letter(any(), any(), any(), any()), return: :yeet

    DataFeed.process(config, @cache_name)

    assert_called Yeet.process_dead_letter(@dataset_id, any(), "reaper", any())
  end
end
