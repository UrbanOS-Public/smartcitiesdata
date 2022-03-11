defmodule Reaper.YeetTest do
  use ExUnit.Case
  use Divo
  use Tesla
  use Properties, otp_app: :reaper

  require Logger
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [ingestion_update: 0]

  @ingestion_id "12345-6789"
  @dlq_topic Application.get_env(:dead_letter, :driver) |> get_in([:init_args, :topic])
  @instance_name Reaper.instance_name()

  @invalid_json_file "includes_invalid.json"

  @moduletag capture_log: true

  getter(:elsa_brokers, generic: true)
  getter(:output_topic_prefix, generic: true)

  setup_all do
    bypass = Bypass.open()

    bypass
    |> TestUtils.bypass_file(@invalid_json_file)

    Patiently.wait_for!(
      fn ->
        {type, result} = get("http://localhost:#{bypass.port}/#{@invalid_json_file}")
        type == :ok and result.status == 200
      end,
      dwell: 1000,
      max_tries: 20
    )

    json_ingestion =
      TDG.create_ingestion(%{
        id: @ingestion_id,
        cadence: "once",
        sourceFormat: "json",
        targetDataset: "noodles",
        extractSteps: [
          %{
            assigns: %{},
            context: %{
              action: "GET",
              body: %{},
              headers: [],
              protocol: nil,
              queryParams: [],
              url: "http://localhost:#{bypass.port}/#{@invalid_json_file}"
            },
            type: "http"
          }
        ],
        topLevelSelector: nil
      })

    Brook.Event.send(@instance_name, ingestion_update(), :reaper, json_ingestion)

    :ok
  end

  describe "invalid data" do
    test "send failed messages to the DLQ topic" do
      eventually(fn ->
        messages = TestUtils.get_dlq_messages_from_kafka(@dlq_topic, elsa_brokers())

        assert [%{app: "reaper", dataset_id: "noodles"} | _] = messages
      end)
    end

    test "no messages go on to the output topic" do
      eventually(fn ->
        result =
          (output_topic_prefix() <> "-" <> @ingestion_id)
          |> TestUtils.get_data_messages_from_kafka(elsa_brokers())

        assert result == []
      end)
    end
  end
end
