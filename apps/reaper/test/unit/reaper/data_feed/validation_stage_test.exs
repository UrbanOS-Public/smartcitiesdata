defmodule Reaper.DataFeed.ValidationStageTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.DataFeed.ValidationStage
  alias Reaper.Cache

  @cache :validation_stage_test

  setup do
    Cachex.start_link(@cache)
    :ok
  end

  describe "handle_events/3" do
    test "will remove duplicates from events" do
      Cache.cache(@cache, %{one: 1, two: 2})

      incoming_events = [
        {%{one: 1, two: 2}, 1},
        {%{three: 3, four: 4}, 2}
      ]

      state = %{
        cache: @cache,
        config: FixtureHelper.new_reaper_config(%{dataset_id: "ds1", sourceType: "batch"}),
        last_processed_index: -1
      }

      {:noreply, outgoing_events, _new_state} = ValidationStage.handle_events(incoming_events, self(), state)
      assert outgoing_events == [{%{three: 3, four: 4}, 2}]
    end

    test "will remove any events that have already been processed" do
      state = %{
        cache: @cache,
        config: FixtureHelper.new_reaper_config(%{dataset_id: "ds2", sourceType: "batch"}),
        last_processed_index: 5
      }

      incoming_events = [
        {%{one: 1, two: 2}, 4},
        {%{three: 3, four: 4}, 5},
        {%{five: 5, six: 6}, 6}
      ]

      {:noreply, outgoing_events, _new_state} = ValidationStage.handle_events(incoming_events, self(), state)
      assert outgoing_events == [{%{five: 5, six: 6}, 6}]
    end

    test "will yeet any errors marked during cache call" do
      allow Cache.mark_duplicates(@cache, %{three: 3, four: 4}), return: {:error, "bad stuff"}
      allow Cache.mark_duplicates(@cache, any()), exec: fn _, msg -> {:ok, msg} end
      allow Yeet.process_dead_letter(any(), any(), any(), any()), return: :ok

      state = %{
        cache: @cache,
        config: FixtureHelper.new_reaper_config(%{dataset_id: "ds2", sourceType: "batch"}),
        last_processed_index: -1
      }

      incoming_events = [
        {%{one: 1, two: 2}, 1},
        {%{three: 3, four: 4}, 2}
      ]

      {:noreply, outgoing_events, _new_state} = ValidationStage.handle_events(incoming_events, self(), state)
      assert outgoing_events == [{%{one: 1, two: 2}, 1}]
      assert_called Yeet.process_dead_letter("ds2", {%{three: 3, four: 4}, 2}, "reaper", reason: "bad stuff")
    end
  end
end
