defmodule DiscoveryStreams.Event.EventHandlerTest do
  use ExUnit.Case

  alias DiscoveryStreams.Event.EventHandler
  alias SmartCity.TestDataGenerator, as: TDG
  import Checkov
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, dataset_delete: 0]
  use Placebo

  setup do
    allow DiscoveryStreams.Stream.Supervisor.start_child(any()), return: :does_not_matter
    allow DiscoveryStreams.Stream.Supervisor.terminate_child(any()), return: :does_not_matter
    :ok
  end

  describe "data:ingest:start event" do
    setup do
      allow Brook.ViewState.create(any(), any(), any()), return: :does_not_matter
      :ok
    end

    test "should store dataset.id by dataset.technical.systemName and vice versa" do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: "stream", systemName: "fake_system_name"}
        )

      event = Brook.Event.new(type: data_ingest_start(), data: dataset, author: :author)

      response = EventHandler.handle_event(event)

      assert_called Brook.ViewState.create(:streaming_datasets_by_id, dataset.id, dataset.technical.systemName), once()

      assert_called Brook.ViewState.create(
                      :streaming_datasets_by_system_name,
                      dataset.technical.systemName,
                      dataset.id
                    ),
                    once()

      assert :ok == response
    end

    test "should start a stream supervisor child" do
      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: "stream", systemName: "fake_system_name"}
        )

      event = Brook.Event.new(type: data_ingest_start(), data: dataset, author: :author)
      response = EventHandler.handle_event(event)

      assert_called DiscoveryStreams.Stream.Supervisor.start_child(dataset.id), once()
      assert :ok == response
    end
  end

  describe "dataset:update event" do
    setup do
      allow Brook.ViewState.delete(any(), any()), return: :does_not_matter

      :ok
    end

    data_test "when sourceType is '#{source_type}' and private is '#{private}' dataset_deleted == #{delete_called}" do
      system_name = Faker.UUID.v4()

      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: source_type, private: private, systemName: system_name}
        )

      event = Brook.Event.new(type: dataset_update(), data: dataset, author: :author)

      EventHandler.handle_event(event)

      assert delete_called == called?(Brook.ViewState.delete(:streaming_datasets_by_id, dataset.id))
      assert delete_called == called?(Brook.ViewState.delete(:streaming_datasets_by_system_name, system_name))
      assert delete_called == called?(DiscoveryStreams.Stream.Supervisor.terminate_child(dataset.id))

      where([
        [:source_type, :private, :delete_called],
        ["ingest", false, true],
        ["ingest", true, true],
        ["stream", false, false],
        ["stream", true, false]
      ])
    end

    test "should delete dataset when dataset:delete event fires" do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)
      system_name = Faker.UUID.v4()
      dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{systemName: system_name})
      allow(DiscoveryStreams.TopicHelper.delete_input_topic(any()), return: :ok)

      event = Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
      EventHandler.handle_event(event)

      assert_called(Brook.ViewState.delete(:streaming_datasets_by_id, dataset.id))
      assert_called(Brook.ViewState.delete(:streaming_datasets_by_system_name, system_name))
      assert_called(DiscoveryStreams.Stream.Supervisor.terminate_child(dataset.id))
    end
  end
end
