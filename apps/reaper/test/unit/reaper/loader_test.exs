defmodule Reaper.LoaderTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo
  alias Kaffe.Producer
  alias Reaper.Loader
  alias SmartCity.Dataset

  setup do
    on_exit(fn -> unstub() end)
  end

  test "wraps payload and sends to kafka" do
    test_payload_one = %{
      payload: "as",
      a: "map"
    }

    test_payload_two = %{
      another: "payload"
    }

    test_payloads = [
      test_payload_one,
      test_payload_two
    ]

    good_date = DateTime.utc_now()
    iso8601_date = DateTime.to_iso8601(good_date)

    allow Loader.format_date(any()), return: iso8601_date, meck_options: [:passthrough]

    test_dataset_id = "abcdef-12345"

    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: test_dataset_id})

    start_time = good_date
    end_time = good_date

    expected_key_one = "AAAE509C7162BBE7D948D141AD2EF0F5"
    expected_key_two = "2420D9AF43588C11175506A917A81567"

    data_message_1 =
      test_payload_one
      |> create_message(test_dataset_id, good_date, good_date)
      |> SmartCity.Data.encode!()

    data_message_2 =
      test_payload_two
      |> create_message(test_dataset_id, good_date, good_date)
      |> SmartCity.Data.encode!()

    expect(Producer.produce_sync(expected_key_one, any()), return: :ok)
    expect(Producer.produce_sync(expected_key_two, any()), return: :error)

    assert Loader.load(test_payloads, reaper_config, good_date) ==
             [
               {:ok, test_payload_one},
               {:error, test_payload_two}
             ]
  end

  defp create_message(payload, dataset_id, start, stop) do
    start = Loader.format_date(start)
    stop = Loader.format_date(stop)

    {:ok, message} =
      SmartCity.Data.new(%{
        dataset_id: dataset_id,
        operational: %{timing: [%{app: "reaper", label: "sus", start_time: start, end_time: stop}]},
        payload: payload,
        _metadata: %{}
      })

    message
  end
end
