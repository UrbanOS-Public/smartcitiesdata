defmodule Reaper.DataFeed.LoadStageTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.DataFeed.LoadStage
  alias Reaper.{Cache, Persistence}
  alias Elsa.Producer

  @message_size 218
  @iso_output DateTime.utc_now() |> DateTime.to_iso8601()
  @cache __MODULE__

  use TempEnv, reaper: [batch_size_in_bytes: 10 * @message_size, output_topic_prefix: "test"]

  setup do
    Cachex.start_link(@cache)
    allow DateTime.to_iso8601(any()), return: @iso_output, meck_options: [:passthrough]
    :ok
  end

  describe "handle_events/3 check duplicates" do
    setup do
      allow Producer.produce_sync(any(), any(), any()), return: :ok
      allow Persistence.record_last_processed_index(any(), any()), return: :ok

      state = %{
        cache: @cache,
        config: FixtureHelper.new_reaper_config(%{dataset_id: "ds1", allow_duplicates: false}),
        batch: [],
        bytes: 0,
        originals: [],
        start_time: DateTime.utc_now()
      }

      incoming_events = ?a..?z |> create_messages() |> Enum.with_index()

      {:noreply, [], new_state} = LoadStage.handle_events(incoming_events, self(), state)
      [new_state: new_state]
    end

    test "2 batches are sent to kafka" do
      assert_called Producer.produce_sync("test-ds1", create_data_messages(?a..?j, "ds1"), any())
      assert_called Producer.produce_sync("test-ds1", create_data_messages(?k..?t, "ds1"), any())
    end

    test "remaining partial batch in sitting in state", %{new_state: new_state} do
      assert new_state.batch == create_data_messages(?z..?u, "ds1")
      assert new_state.bytes == 6 * @message_size
    end

    test "the last processed index is recorded when batch is sent to kafka" do
      assert_called Persistence.record_last_processed_index("ds1", 9)
      assert_called Persistence.record_last_processed_index("ds1", 19)
    end

    test "all messages sent to kafka are cached" do
      ?a..?t
      |> create_messages()
      |> Enum.each(fn msg ->
        assert {:duplicate, msg} == Cache.mark_duplicates(@cache, msg)
      end)
    end
  end

  describe "handle_events/3 skip duplicate cache" do
    setup do
      allow Producer.produce_sync(any(), any(), any()), return: :ok
      allow Persistence.record_last_processed_index(any(), any()), return: :ok
      allow Cache.cache(any(), any()), return: :ok

      state = %{
        cache: @cache,
        config: FixtureHelper.new_reaper_config(%{dataset_id: "ds2"}),
        batch: [],
        bytes: 0,
        originals: [],
        start_time: DateTime.utc_now()
      }

      incoming_events = ?a..?z |> create_messages() |> Enum.with_index()

      {:noreply, [], new_state} = LoadStage.handle_events(incoming_events, self(), state)
      [new_state: new_state]
    end

    test "messages are not cached" do
      refute_called Cache.cache(@cache, any())
    end
  end

  defp create_messages(range, opts \\ []) do
    range
    |> Enum.map(&List.to_string([&1]))
    |> Enum.map(fn letter -> %{letter => letter} end)
    |> Enum.map(fn msg ->
      case Keyword.get(opts, :json, false) do
        true -> Jason.encode!(msg)
        false -> msg
      end
    end)
  end

  defp create_data_messages(range, dataset_id) do
    timing = %{app: "reaper", label: "Ingested", start_time: @iso_output, end_time: @iso_output}

    range
    |> create_messages()
    |> Enum.map(fn payload ->
      %{
        dataset_id: dataset_id,
        payload: payload,
        operational: %{timing: [timing]},
        _metadata: %{}
      }
    end)
    |> Enum.map(&SmartCity.Data.new/1)
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(&Jason.encode!/1)
  end
end
