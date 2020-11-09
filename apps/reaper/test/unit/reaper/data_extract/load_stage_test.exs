defmodule Reaper.DataExtract.LoadStageTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :reaper

  alias Reaper.DataExtract.LoadStage
  alias Reaper.{Cache, Persistence}
  alias SmartCity.TestDataGenerator, as: TDG

  @message_size 218
  @iso_output DateTime.utc_now() |> DateTime.to_iso8601()
  @cache __MODULE__

  use TempEnv, reaper: [batch_size_in_bytes: 10 * @message_size, output_topic_prefix: "test"]

  getter(:profiling_enabled, generic: true)

  setup do
    {:ok, registry} = Horde.Registry.start_link(keys: :unique, name: Reaper.Cache.Registry)
    {:ok, horde_sup} = Horde.DynamicSupervisor.start_link(strategy: :one_for_one, name: Reaper.Horde.Supervisor)
    Horde.DynamicSupervisor.start_child(Reaper.Horde.Supervisor, {Reaper.Cache, name: @cache})

    on_exit(fn ->
      kill(horde_sup)
      kill(registry)
    end)

    allow DateTime.to_iso8601(any()), return: @iso_output, meck_options: [:passthrough]
    :ok
  end

  describe "handle_events/3 check duplicates" do
    setup do
      Application.put_env(:reaper, :profiling_enabled, true)
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.record_last_processed_index(any(), any()), return: :ok

      state = %{
        cache: @cache,
        dataset: TDG.create_dataset(id: "ds1", technical: %{allow_duplicates: false}),
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
      assert_called Elsa.produce(any(), "test-ds1", create_data_messages(?a..?j, "ds1"), any())
      assert_called Elsa.produce(any(), "test-ds1", create_data_messages(?k..?t, "ds1"), any())
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
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.record_last_processed_index(any(), any()), return: :ok
      allow Cache.cache(any(), any()), return: :ok

      state = %{
        cache: @cache,
        dataset: TDG.create_dataset(id: "ds2"),
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

  test "should return empty list of timing when profiling enabled is set to false" do
    Application.put_env(:reaper, :profiling_enabled, false)
    allow Elsa.produce(any(), any(), any(), any()), return: :ok
    allow Persistence.record_last_processed_index(any(), any()), return: :ok

    state = %{
      cache: @cache,
      dataset: TDG.create_dataset(id: "ds1", technical: %{allow_duplicates: false}),
      batch: [],
      bytes: 0,
      originals: [],
      start_time: DateTime.utc_now()
    }

    incoming_events = ?a..?c |> create_messages() |> Enum.with_index()

    {:noreply, [], new_state} = LoadStage.handle_events(incoming_events, self(), state)
    assert new_state.batch == create_data_messages(?c..?a, "ds1")
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
    range
    |> create_messages()
    |> Enum.map(fn payload ->
      %{
        dataset_id: dataset_id,
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
