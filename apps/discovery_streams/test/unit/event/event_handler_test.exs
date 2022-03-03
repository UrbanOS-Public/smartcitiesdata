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
    test "should start a stream supervisor child" do
      ingestion =
        TDG.create_ingestion(%{
          id: Faker.UUID.v4()
        })

      event = Brook.Event.new(type: data_ingest_start(), data: ingestion, author: :author)
      response = EventHandler.handle_event(event)

      assert_called DiscoveryStreams.Stream.Supervisor.start_child(ingestion.targetDataset), once()
      assert :ok == response
    end
  end

  describe "dataset:update event" do
    setup do
      allow Brook.ViewState.delete(any(), any()), return: :does_not_matter
      allow Brook.ViewState.create(any(), any(), any()), return: :does_not_matter
      :ok
    end

    test "should store dataset.id by dataset.technical.systemName and vice versa when the dataset has a sourceType of stream" do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: "stream", systemName: "fake_system_name"}
        )

      event = Brook.Event.new(type: dataset_update(), data: dataset, author: :author)

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

    data_test "when sourceType is '#{source_type}' discovery_streams event handler discards non-streaming datasets" do
      system_name = Faker.UUID.v4()

      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: source_type, systemName: system_name}
        )

      event = Brook.Event.new(type: dataset_update(), data: dataset, author: :author)

      response = EventHandler.handle_event(event)

      response == :discard

      where([
        [:source_type],
        ["ingest"],
        ["remote"]
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
