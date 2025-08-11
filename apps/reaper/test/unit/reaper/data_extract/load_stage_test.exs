defmodule Reaper.DataExtract.LoadStageTest do
  use ExUnit.Case, async: false
  use Properties, otp_app: :reaper
  import Mox

  alias Reaper.DataExtract.LoadStage
  alias Reaper.{Cache, Persistence}
  alias SmartCity.TestDataGenerator, as: TDG

  @message_size 306
  @iso_output DateTime.utc_now() |> DateTime.to_iso8601()
  @cache __MODULE__

  use TempEnv, reaper: [batch_size_in_bytes: 10 * @message_size, output_topic_prefix: "test"]

  getter(:profiling_enabled, generic: true)

  setup do
    # Setup meck for external modules (don't mock Cache since we use real cache in tests)
    modules_to_mock = [Elsa, Persistence]
    
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      rescue
        ErlangError -> :ok
      end
      :meck.new(module, [:non_strict])
    end)
    
    # Mock DateTime with passthrough to only override specific functions
    try do
      :meck.unload(DateTime)
    rescue
      ErlangError -> :ok
    end
    :meck.new(DateTime, [:passthrough])
    
    on_exit(fn ->
      Enum.each([DateTime | modules_to_mock], fn module ->
        try do
          :meck.unload(module)
        rescue
          ErlangError -> :ok
        end
      end)
    end)
    {:ok, registry} = Horde.Registry.start_link(keys: :unique, name: Reaper.Cache.Registry)
    {:ok, horde_sup} = Horde.DynamicSupervisor.start_link(strategy: :one_for_one, name: Reaper.Horde.Supervisor)
    Horde.DynamicSupervisor.start_child(Reaper.Horde.Supervisor, {Reaper.Cache, name: @cache})

    on_exit(fn ->
      kill(horde_sup)
      kill(registry)
    end)

    # Mock DateTime.to_iso8601 to return consistent output
    :meck.expect(DateTime, :to_iso8601, fn _datetime -> @iso_output end)
    
    # Set up Jason mock for Cache operations
    stub(JasonMock, :encode, fn value -> {:ok, Jason.encode!(value)} end)
    
    :ok
  end

  describe "handle_events/3 check duplicates" do
    setup do
      Application.put_env(:reaper, :profiling_enabled, true)
      :meck.expect(Elsa, :produce, fn _producer, _topic, _batch, _opts -> :ok end)
      :meck.expect(Persistence, :record_last_processed_index, fn _ingestion_id, _index -> :ok end)

      state = %{
        cache: @cache,
        ingestion: TDG.create_ingestion(%{id: "ingest1", targetDatasets: ["ds1", "ds2"], allow_duplicates: false}),
        batch: [],
        bytes: 0,
        originals: [],
        start_time: DateTime.utc_now(),
        last_message: false
      }

      [_message | _] = create_data_messages(?a..?a, ["ds1", "ds2"], state.ingestion, state.start_time)
      incoming_events = ?a..?z |> create_messages() |> Enum.with_index()

      {:noreply, [], new_state} = LoadStage.handle_events(incoming_events, self(), state)
      [new_state: new_state]
    end

    test "2 batches are sent to kafka", %{new_state: new_state} do
      expected_batch1 = create_data_messages(?a..?j, ["ds1", "ds2"], new_state.ingestion, new_state.start_time)
      expected_batch2 = create_data_messages(?k..?t, ["ds1", "ds2"], new_state.ingestion, new_state.start_time)
      
      assert :meck.called(Elsa, :produce, [:"test-ingest1_producer", "test-ingest1", expected_batch1, [partition: 0]])
      assert :meck.called(Elsa, :produce, [:"test-ingest1_producer", "test-ingest1", expected_batch2, [partition: 0]])
    end

    test "remaining partial batch in sitting in state", %{new_state: new_state} do
      assert new_state.batch == create_data_messages(?z..?u, ["ds1", "ds2"], new_state.ingestion, new_state.start_time)
      assert new_state.bytes == 6 * @message_size
    end

    test "the last processed index is recorded when batch is sent to kafka" do
      assert :meck.called(Persistence, :record_last_processed_index, ["ingest1", 9])
      assert :meck.called(Persistence, :record_last_processed_index, ["ingest1", 19])
    end

    test "all messages sent to kafka are cached" do
      ?a..?r
      |> create_messages()
      |> Enum.each(fn msg ->
        assert {:duplicate, msg} == Cache.mark_duplicates(@cache, msg)
      end)
    end
  end

  describe "handle_events/3 skip duplicate cache" do
    setup do
      :meck.expect(Elsa, :produce, fn _producer, _topic, _batch, _opts -> :ok end)
      :meck.expect(Persistence, :record_last_processed_index, fn _ingestion_id, _index -> :ok end)

      state = %{
        cache: @cache,
        ingestion: TDG.create_ingestion(%{id: "ds2"}),
        batch: [],
        bytes: 0,
        originals: [],
        start_time: DateTime.utc_now(),
        last_message: false
      }

      incoming_events = ?a..?z |> create_messages() |> Enum.with_index()

      {:noreply, [], new_state} = LoadStage.handle_events(incoming_events, self(), state)
      [new_state: new_state]
    end

    test "messages are not cached" do
      # Since allow_duplicates is true by default for TDG.create_ingestion(%{id: "ds2"}), 
      # cache should not be called. We verify this by checking the cache is empty
      ?a..?z
      |> create_messages()
      |> Enum.each(fn msg ->
        assert {:ok, msg} == Cache.mark_duplicates(@cache, msg)
      end)
    end
  end

  test "should return empty list of timing when profiling enabled is set to false" do
    Application.put_env(:reaper, :profiling_enabled, false)
    :meck.expect(Elsa, :produce, fn _producer, _topic, _batch, _opts -> :ok end)
    :meck.expect(Persistence, :record_last_processed_index, fn _ingestion_id, _index -> :ok end)

    state = %{
      cache: @cache,
      ingestion: TDG.create_ingestion(%{id: "ds1", targetDatasets: ["ds1", "ds2"], allow_duplicates: false}),
      batch: [],
      bytes: 0,
      originals: [],
      start_time: DateTime.utc_now(),
      last_message: false
    }

    incoming_events = ?a..?c |> create_messages() |> Enum.with_index()

    {:noreply, [], new_state} = LoadStage.handle_events(incoming_events, self(), state)
    assert new_state.batch == create_data_messages(?c..?a, ["ds1", "ds2"], new_state.ingestion, new_state.start_time)
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

  defp create_data_messages(range, dataset_ids, ingestion, start_time) do
    range
    |> create_messages()
    |> Enum.map(fn payload ->
      %{
        dataset_ids: dataset_ids,
        ingestion_id: ingestion.id,
        extraction_start_time: start_time,
        payload: payload,
        operational: %{timing: add_timing()},
        _metadata: %{}
      }
    end)
    |> Enum.map(&SmartCity.Data.new/1)
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(&Jason.encode!/1)
  end

  defp add_timing() do
    case profiling_enabled() do
      true -> [%{app: "reaper", label: "Ingested", start_time: @iso_output, end_time: @iso_output}]
      _ -> []
    end
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
