defmodule Reaper.LoaderTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo
  alias Kaffe.Producer
  alias Reaper.Loader
  alias SCOS.RegistryMessage

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

    test_dataset_id = "abcdef-12345"

    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: test_dataset_id})

    expected_key_one = "AAAE509C7162BBE7D948D141AD2EF0F5"
    expected_key_two = "2420D9AF43588C11175506A917A81567"

    data_message_1 =
      test_payload_one
      |> create_message(test_dataset_id)

    data_message_2 =
      test_payload_two
      |> create_message(test_dataset_id)

    expect(Producer.produce_sync(expected_key_one, data_message_1), return: :ok)
    expect(Producer.produce_sync(expected_key_two, data_message_2), return: :error)

    assert Loader.load(test_payloads, reaper_config) ==
             [
               {:ok, test_payload_one},
               {:error, test_payload_two}
             ]
  end

  defp create_message(payload, dataset_id) do
    SCOS.DataMessage.new(%{
      dataset_id: dataset_id,
      operational: %{timing: [%{app: "reaper", label: "sus", start_time: 5, end_time: 10}]},
      payload: payload,
      _metadata: %{}
    })
  end
end
