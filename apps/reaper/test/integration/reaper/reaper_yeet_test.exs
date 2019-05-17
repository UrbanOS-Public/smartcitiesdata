defmodule Reaper.YeetTest do
  use ExUnit.Case
  use Divo
  use Tesla
  require Logger
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  @success_topic Application.get_env(:kaffe, :producer)[:topics] |> List.first()
  @dlq_topic Application.get_env(:kaffe, :producer)[:topics] |> List.last()

  @invalid_json_file "includes_invalid.json"

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

    {:ok, bypass: bypass}
  end

  describe "invalid data" do
    test "send failed messages to the DLQ topic", %{bypass: bypass} do
      dataset_id = "12345-6789"

      json_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: 1_000,
            sourceUrl: "http://localhost:#{bypass.port}/#{@invalid_json_file}",
            sourceFormat: "json"
          }
        })

      Dataset.write(json_dataset)

      Patiently.wait_for!(
        fn ->
          result =
            dataset_id
            |> fetch_dlq_messages()
            |> Enum.any?(fn message -> message["original_message"] =~ "\"vehicle_id\" 15537" end)

          result == true
        end,
        dwell: 1000,
        max_tries: 20
      )

      Patiently.wait_for!(
        fn ->
          result =
            dataset_id
            |> fetch_good_messages()

          result == []
        end,
        dwell: 1000,
        max_tries: 20
      )
    end
  end

  defp fetch_good_messages(dataset_id) do
    @success_topic
    |> TestUtils.fetch_all_feed_messages()
    |> Enum.filter(fn %{"dataset_id" => id} -> id == dataset_id end)
    |> Enum.map(fn %{"payload" => payload} -> payload end)
  end

  defp fetch_dlq_messages(_dataset_id) do
    @dlq_topic
    |> TestUtils.fetch_all_feed_messages()
  end
end
