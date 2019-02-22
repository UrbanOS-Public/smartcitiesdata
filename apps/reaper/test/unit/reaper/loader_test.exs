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

    expected_key_one = "26DDC0356F84C1BFDA3C56A6663ABB04"
    expected_key_two = "719D16D9A5C2C3B99761527D6E72D143"

    expected_value_one =
      Jason.encode!(%{
        metadata: %{
          dataset_id: test_dataset_id
        },
        payload: test_payload_one
      })

    expected_value_two =
      Jason.encode!(%{
        metadata: %{
          dataset_id: test_dataset_id
        },
        payload: test_payload_two
      })

    expect(Producer.produce_sync(expected_key_one, expected_value_one), return: :ok)
    expect(Producer.produce_sync(expected_key_two, expected_value_two), return: :error)

    assert Loader.load(test_payloads, test_dataset_id) == [
             {:ok, test_payload_one},
             {:error, test_payload_two}
           ]
  end
end
