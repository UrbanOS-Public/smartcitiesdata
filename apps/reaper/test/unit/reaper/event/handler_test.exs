defmodule Reaper.Event.HandlerTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event, only: [dataset_extract_complete: 0, dataset_extract_start: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    Brook.start_link(Application.get_env(:reaper, :brook))
    :ok
  end

  describe "#{dataset_extract_complete()}" do
    test "should persist last fetched timestamp" do
      date = NaiveDateTime.utc_now()
      allow NaiveDateTime.utc_now(), return: date, meck_options: [:passthrough]
      dataset = TDG.create_dataset(id: "ds1")
      Brook.Event.send(dataset_extract_complete(), "testing", dataset)

      eventually(fn ->
        assert Brook.get!(:last_fetched_timestamps, dataset.id) == date
      end)

    end
  end

  describe "#{dataset_extract_start()}" do
    test "should ask horde to start process and save view state"do

    end
  end
end
