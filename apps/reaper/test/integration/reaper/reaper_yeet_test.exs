defmodule Reaper.YeetTest do
  use ExUnit.Case
  use Divo
  use Tesla
  require Logger
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [dataset_update: 0]

  @dataset_id "12345-6789"
  @endpoints Application.get_env(:reaper, :elsa_brokers)
  @success_topic Application.get_env(:reaper, :output_topic_prefix) <> "-" <> @dataset_id
  @dlq_topic Application.get_env(:yeet, :topic)

  @invalid_json_file "includes_invalid.json"

  @moduletag capture_log: true

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

    Elsa.create_topic(@endpoints, @success_topic)

    json_dataset =
      TDG.create_dataset(%{
        id: @dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "http://localhost:#{bypass.port}/#{@invalid_json_file}",
          sourceFormat: "json"
        }
      })

    Brook.Event.send(dataset_update(), :reaper, json_dataset)

    :ok
  end

  describe "invalid data" do
    test "send failed messages to the DLQ topic" do
      eventually(fn ->
        messages = TestUtils.get_dlq_messages_from_kafka(@dlq_topic, @endpoints)

        assert [%{app: "Reaper", dataset_id: @dataset_id} | _] = messages
      end)
    end

    test "no messages go on to the output topic" do
      eventually(fn ->
        result = TestUtils.get_data_messages_from_kafka(@success_topic, @endpoints)

        assert result == []
      end)
    end
  end
end
