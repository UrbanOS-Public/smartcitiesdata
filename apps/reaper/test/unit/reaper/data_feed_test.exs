defmodule Reaper.DataFeedTest do
  use ExUnit.Case
  use Placebo
  import ExUnit.CaptureLog

  alias Reaper.{Cache, DataFeed, Persistence}
  alias Elsa.Producer

  @dataset_id "12345-6789"
  @cache_name String.to_atom("#{@dataset_id}_feed")

  @csv """
  one,two,three
  four,five,six
  """

  @download_dir System.get_env("TMPDIR") || "/tmp/"
  use TempEnv, reaper: [download_dir: @download_dir]

  setup do
    bypass = Bypass.open()
    Cachex.start_link(@cache_name)

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
        ],
        allow_duplicates: false
      })

    [bypass: bypass, config: config]
  end

  describe "process/2 happy path" do
    setup do
      allow Producer.produce_sync(any(), any(), any()), return: :ok
      allow Persistence.record_last_fetched_timestamp(any(), any()), return: :ok
      allow Persistence.remove_last_processed_index(@dataset_id), return: :ok

      :ok
    end

    test "parses turns csv into data messages and sends to kafka", %{config: config} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"

      DataFeed.process(config, @cache_name)

      messages = capture(1, Producer.produce_sync(any(), any(), any()), 2)

      expected = [
        %{a: "one", b: "two", c: "three"},
        %{a: "four", b: "five", c: "six"}
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@dataset_id), once()
    end

    test "eliminates duplicates before sending to kafka", %{config: config} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"
      Cache.cache(@cache_name, %{a: "one", b: "two", c: "three"})

      DataFeed.process(config, @cache_name)

      messages = capture(1, Producer.produce_sync(any(), any(), any()), 2)
      assert [%{a: "four", b: "five", c: "six"}] == get_payloads(messages)
      assert_called Producer.produce_sync(any(), any(), any()), once()

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@dataset_id), once()
    end
  end

  @tag capture_log: true
  test "process/2 should remove file for dataset regardless of error being raised", %{config: config} do
    allow Persistence.get_last_processed_index(any()), return: -1
    allow Reaper.Cache.mark_duplicates(any(), any()), exec: fn _, _ -> raise "some error" end

    assert_raise RuntimeError, fn ->
      DataFeed.process(config, @cache_name)
    end

    assert false == File.exists?(@download_dir <> config.dataset_id)
  end

  test "process/2 should catch log all exceptions and reraise", %{config: config} do
    allow Persistence.get_last_processed_index(any()), return: -1

    allow Producer.produce_sync(any(), any(), any()), exec: fn _, _, _ -> raise "some error" end

    allow Yeet.process_dead_letter(any(), any(), any(), any()), return: :yeet

    log =
      capture_log(fn ->
        assert_raise RuntimeError, fn ->
          DataFeed.process(config, @cache_name)
        end
      end)

    assert log =~ inspect(config)
    assert log =~ "some error"
  end

  defp get_payloads(list) do
    list
    |> Enum.map(&SmartCity.Data.new/1)
    |> Enum.map(fn {:ok, data} -> data.payload end)
  end
end
