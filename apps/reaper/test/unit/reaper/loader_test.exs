defmodule Reaper.LoaderTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo
  alias Kaffe.Producer
  alias Reaper.Loader

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

    expected_key_one = "FC8AF9F2179E98FDC5406928D9D72963"
    expected_key_two = "5E79EABCAD910766A02B39092FB6C860"

    data_message_1 =
      test_payload_one
      |> create_message(test_dataset_id)
      |> SCOS.DataMessage.encode_message()

    data_message_2 =
      test_payload_two
      |> create_message(test_dataset_id)
      |> SCOS.DataMessage.encode_message()

    expect(Producer.produce_sync(expected_key_one, data_message_1), return: :ok)
    expect(Producer.produce_sync(expected_key_two, data_message_2), return: :error)

    assert Loader.load(test_payloads, test_dataset_id) == [
             {:ok, test_payload_one},
             {:error, test_payload_two}
           ]
  end

  defp create_message(payload, dataset_id) do
    SCOS.DataMessage.new(%{dataset_id: dataset_id, payload: payload, _metadata: %{}, operational: %{}})
  end
end
