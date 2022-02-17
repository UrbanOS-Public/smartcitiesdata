defmodule Reaper.Collections.ExtractionsTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :reaper

  require Logger

  @instance_name Reaper.instance_name()

  alias Reaper.Collections.Extractions
  alias SmartCity.TestDataGenerator, as: TDG

  getter(:brook, generic: true)

  setup do
    {:ok, brook} = Brook.start_link(brook() |> Keyword.put(:instance, @instance_name))

    Brook.Test.register(@instance_name)

    on_exit(fn ->
      kill(brook)
    end)

    :ok
  end

  describe "should_send_data_ingest_start?/1" do
    test "returns true when cadence of ingestion is less frequent than once per minute" do
      ingestion =
        TDG.create_ingestion(%{
          id: "ds9",
          cadence: "2 4 6 * * *"
        })

      assert true == Extractions.should_send_data_ingest_start?(ingestion)
    end

    test "returns false when last fetched timestamp exists and cadence of ingestion is every second" do
      ingestion =
        TDG.create_ingestion(%{
          id: "ds9",
          cadence: "* 4 6 * * *"
        })

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_last_fetched_timestamp(ingestion.id)
      end)

      assert false == Extractions.should_send_data_ingest_start?(ingestion)
    end

    test "returns true when cadence of ingestion is every second but last fetched timestamp is nil" do
      ingestion =
        TDG.create_ingestion(%{
          id: "ds9",
          cadence: "* 4 6 * * *"
        })

      assert true == Extractions.should_send_data_ingest_start?(ingestion)
    end

    test "returns false when last fetched timestamp exists and cadence of ingestion is every minute" do
      ingestion =
        TDG.create_ingestion(%{
          id: "ds9",
          cadence: "4 * 6 * * *"
        })

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_last_fetched_timestamp(ingestion.id)
      end)

      assert false == Extractions.should_send_data_ingest_start?(ingestion)
    end

    test "returns true when cadence of ingestion is every minute but last fetched timestamp is nil" do
      ingestion =
        TDG.create_ingestion(%{
          id: "ds9",
          cadence: "4 * 6 * * *"
        })

      assert true == Extractions.should_send_data_ingest_start?(ingestion)
    end

    test "returns false when last fetched timestamp exists and cadence of ingestion is every second of every minute" do
      ingestion =
        TDG.create_ingestion(%{
          id: "ds9",
          cadence: "* * 6 * * *"
        })

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_last_fetched_timestamp(ingestion.id)
      end)

      assert false == Extractions.should_send_data_ingest_start?(ingestion)
    end

    test "returns true when cadence of ingestion is every second of every minute but last fetched timestamp is nil" do
      ingestion =
        TDG.create_ingestion(%{
          id: "ds9",
          cadence: "* * 6 * * *"
        })

      assert true == Extractions.should_send_data_ingest_start?(ingestion)
    end
  end

  describe "is_streaming_source_type?/1" do
    test "returns false when cadence format is atypical, but sourceType would not be streaming: '0-10 0-20/2 6 * * *'" do
      assert false == Extractions.is_streaming_source_type?("0-10 0-20/2 6 * * *")
    end

    test "returns true when cadence format is atypical with asterisk in seconds: '*/10 0-20/2 6 * * *'" do
      assert true == Extractions.is_streaming_source_type?("*/10 0-20/2 6 * * *")
    end

    test "returns true when cadence format is atypical with asterisk in minutes: '10 0-20/* 6 * * *'" do
      assert true == Extractions.is_streaming_source_type?("10 0-20/* 6 * * *")
    end

    test "returns true when cadence format is atypical with asterisk in seconds and minutes: '*/10 0-20/* 6 * * *'" do
      assert true == Extractions.is_streaming_source_type?("*/10 0-20/* 6 * * *")
    end
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
