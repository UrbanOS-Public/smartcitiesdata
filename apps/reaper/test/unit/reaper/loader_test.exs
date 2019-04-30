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

    start_time = DateTime.utc_now()
    start_time_iso8601 = DateTime.to_iso8601(start_time)
    allow DateTime.to_iso8601(any()), return: start_time_iso8601, meck_options: [:passthrough]

    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: "abcdef-12345"})

    expected_key_one = "AAAE509C7162BBE7D948D141AD2EF0F5"
    expected_key_two = "2420D9AF43588C11175506A917A81567"

    expect(Producer.produce_sync(expected_key_one, any()), return: :ok)
    expect(Producer.produce_sync(expected_key_two, any()), return: :error)

    result_one = Loader.load(test_payload_one, reaper_config, start_time)
    result_two = Loader.load(test_payload_two, reaper_config, start_time)

    assert result_one == {:ok, test_payload_one}
    assert result_two == {:error, test_payload_two}
  end

  test "load failures are yoted and raise an error" do
    allow(Yeet.process_dead_letter(any(), any(), any(), any()), return: nil, meck_options: [:passthrough])
    allow(Producer.produce_sync(any(), any()), return: :ok)
    allow(SmartCity.Data.new(any()), return: {:error, "Bad stuff happened"})

    test_payload = %{
      payload: "as",
      a: "map"
    }

    good_date = DateTime.utc_now()
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: "123"})

    Loader.load(test_payload, reaper_config, good_date)

    assert_called Yeet.process_dead_letter("123", test_payload, "Reaper", exit_code: {:error, "Bad stuff happened"})
  end
end
